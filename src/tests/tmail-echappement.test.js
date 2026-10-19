// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/tmail-echappement.test.js
//
// Les paramètres de tMail sont échappés pour le HTML, par défaut (19/10/2026).
// Les gabarits portent du HTML voulu (<b>…</b>) et finissent tels quels dans le
// corps des courriels ; leurs paramètres viennent de la base ou d'un formulaire
// (nom de lectrice, de bibliothèque, de proposant·e, titre). Interpolés bruts, un
// nom pouvait porter un lien ou une mise en page dans un courriel aux couleurs
// d'AnarBib. Ce que le banc garde :
//   1. tMail échappe chaque paramètre, une fois ; le gabarit reste intact ; un
//      paramètre « …Html » passe tel quel ; tMailTexte rend les paramètres bruts ;
//      « $& » dans une valeur n'est pas réinterprété ;
//   2. esc() n'échappe pas deux fois : esc(tMail(…)) = une seule couche ;
//      desechapper() en est l'inverse ;
//   3. un vrai courriel (renderEmail → sendEmail → Resend capturé) : le nom
//      piégé n'est plus une balise dans le HTML, et l'objet comme la version
//      texte se lisent en clair (« L'Insoumise », pas « L&#039;Insoumise ») ;
//   4. aucune fonction qui appelle tMail avec des paramètres ne garde son propre
//      échappeur (non idempotent, il échapperait deux fois).

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { monterEF, FONCTIONS } from './helpers/monter-ef.js';

const ef = monterEF();
const { tMail, tMailTexte } = ef.charger('_shared/i18n/mail-strings.ts');
const { esc, desechapper } = ef.charger('_shared/shared/format.ts');
const { renderEmail } = ef.charger('_shared/mail/layout.ts');
const { sendEmail } = ef.charger('_shared/transport/email.ts');

const PIEGE = '<a href="https://piege.test">Clique ici</a>';

describe('tMail — paramètres échappés, gabarit intact', () => {
  it('un nom piégé ne devient pas une balise ; le <b> du gabarit reste', () => {
    const t = tMail('fr', 'greeting.named', { name: PIEGE });
    expect(t).not.toContain('<a ');
    expect(t).toContain('&lt;a href=&quot;https://piege.test&quot;&gt;');
    const avecGras = tMail('fr', 'loan.note_invite.intro', { title: 'Ni Dieu <script>' });
    expect(avecGras).toMatch(/<b>Ni Dieu &lt;script&gt;<\/b>/);
  });
  it('échapper une fois : une valeur déjà échappée par l’appelant ne bouge pas', () => {
    const deja = 'L&#39;Insoumise &amp; Cie';
    expect(tMail('fr', 'greeting.named', { name: deja })).toBe(tMail('fr', 'greeting.named', { name: "L'Insoumise & Cie" }));
    expect(tMail('fr', 'greeting.named', { name: deja })).not.toContain('&amp;#');
  });
  it('tMailTexte rend les paramètres bruts', () => {
    expect(tMailTexte('fr', 'greeting.named', { name: PIEGE })).toContain(PIEGE);
  });
  it('un paramètre dont le nom finit par « Html » passe tel quel (fragment construit par le code)', () => {
    // Aucun gabarit n'en porte encore : on éprouve la règle sur le code de rendu lui-même.
    const src = readFileSync(path.join(FONCTIONS, '_shared/i18n/mail-strings.ts'), 'utf8');
    expect(src).toMatch(/html && !\/Html\$\/\.test\(k\) \? echapperUneFois\(v\) : String\(v\)/);
  });
  it('« $& » dans une valeur n’est pas réinterprété', () => {
    expect(tMailTexte('fr', 'greeting.named', { name: 'A$&B' })).toContain('A$&B');
    expect(tMail('fr', 'greeting.named', { name: 'A$&B' })).toContain('A$&amp;B');
  });
});

describe('esc — échapper une seule fois', () => {
  it('esc(esc(x)) = esc(x), et esc d’une phrase de tMail n’ajoute pas de couche', () => {
    for (const x of ["L'Insoumise & Cie", PIEGE, '"guillemets"', 'a < b > c']) {
      expect(esc(esc(x))).toBe(esc(x));
      expect(desechapper(esc(x))).toBe(x);
    }
    const phrase = tMail('fr', 'greeting.named', { name: "L'Insoumise" });
    expect(esc(phrase)).not.toContain('&amp;#');
  });
  it('une valeur brute est échappée comme avant', () => {
    expect(esc(`<b>"L'a" & b</b>`)).toBe('&lt;b&gt;&quot;L&#039;a&quot; &amp; b&lt;/b&gt;');
  });
});

describe('un vrai courriel : HTML sûr, objet et texte lisibles', () => {
  it('renderEmail puis sendEmail : pas de balise injectée, objet et texte en clair', async () => {
    ef.vider();
    const nom = `L'Insoumise ${PIEGE}`;
    const salutation = tMail('fr', 'greeting.named', { name: nom });
    const { html, text } = renderEmail({
      locale: 'fr', context: {}, title: tMail('fr', 'greeting.named', { name: "L'Insoumise" }),
      introHtml: `<p>${salutation}</p>`,
    });
    expect(html).not.toContain('<a href="https://piege.test"');
    expect(html).not.toMatch(/&amp;(#0*39|lt|quot);/);   // jamais deux couches
    expect(text).toContain("L'Insoumise");
    expect(text).not.toMatch(/&#0*39;|&lt;|&amp;/);
    await sendEmail({
      toEmail: 'personne@exemple.test', subject: tMail('fr', 'greeting.named', { name: "L'Insoumise & Cie" }),
      html, text, routing: { senderEmail: 'no-reply@exemple.test', senderName: 'AnarBib', noReplyTo: true }, label: 'banc',
    });
    const parti = ef.envois.at(-1);
    expect(parti.subject).toContain("L'Insoumise & Cie");
    expect(parti.subject).not.toMatch(/&#0*39;|&amp;/);
    expect(parti.text).toContain("L'Insoumise");
    expect(parti.html).not.toContain('<a href="https://piege.test"');
  });
});

describe('aucun échappeur local à côté de tMail', () => {
  const RACINE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
  const fichiers = [];
  (function marcher(d) {
    for (const n of readdirSync(d)) {
      const p = path.join(d, n);
      if (statSync(p).isDirectory()) marcher(p);
      else if (p.endsWith('.ts') && !p.endsWith('.test.ts')) fichiers.push(p);
    }
  })(FONCTIONS);
  it('un fichier qui appelle tMail avec des paramètres n’écrit pas lui-même « &amp; »', () => {
    const fautifs = fichiers.filter((f) => {
      const src = readFileSync(f, 'utf8');
      const rel = path.relative(RACINE, f).replace(/\\/g, '/');
      if (/_shared\/(i18n\/mail-strings|shared\/format)\.ts$/.test(rel)) return false;
      const avecParams = /tMail\([^()]*?,[^()]*?,\s*\{/s.test(src);
      return avecParams && /["']&amp;["']/.test(src);
    }).map((f) => path.relative(RACINE, f).replace(/\\/g, '/'));
    expect(fautifs).toEqual([]);
  });
});
