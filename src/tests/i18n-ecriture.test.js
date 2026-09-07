// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — L'écriture des locales est celle de la langue (doctrine DOC-PS-1)
//
// CE QUE CE TEST EMPÊCHE DE REVENIR.
//
// `DOC-PS-1` dit depuis des mois : « i18n : scripts via Node .cjs ou UTF-8
// PowerShell explicite ; vérifier toute mojibake avant correction ». La règle
// était écrite au registre et nulle part ailleurs. L'audit du 07/09/2026
// (`docs/journal/audits/AUDIT_i18n_diacritiques_anglais_residuel_2026-09-07.md`)
// a mesuré ce qu'elle avait laissé passer :
//
//   — 71 valeurs aux diacritiques mangés dans sept locales : « ISBN deja au
//     catalogue », « La bibliotheque selectionnee n'est pas encore entierement
//     configuree sur le reseau », l'allemand en `fuer`/`muessen`, l'espéranto
//     en `Chu dauri` ;
//   — six valeurs laissées en anglais dans `el.json` ;
//   — cinq valeurs de `el.json` écrites en GREC TRANSLITTÉRÉ en caractères
//     latins — « Sfalma kata ti dimiourgia tou logariasmo » — qu'aucune
//     lectrice grecque ne lit comme du grec.
//
// Les commits d'origine s'étalent de mai à août 2026. Ce n'est pas un accident,
// c'est un mode de défaillance récurrent : une règle écrite là où elle n'oblige
// pas est un vœu (`DOC-GLB-1`). Ce fichier la rend mécanique.
//
// ─────────────────────────────────────────────────────────────────────────────
// D'OÙ VIENNENT LES LISTES, ET CE QU'ELLES NE VOIENT PAS
//
// Exigence de `DOC-RECENS-1` : un recensement porte sa méthode et son angle
// mort, sinon sa complétude est une croyance. Trois chemins indépendants :
//
//   (1) ÉGALITÉ À L'ANGLAIS — valeur identique à celle de `en.json`, en
//       écartant les clés identiques dans au moins sept locales (sigles, noms
//       propres, termes techniques légitimement non traduits).
//       ANGLE MORT : ne voit pas l'anglais retapé ou légèrement modifié, ni
//       aucune faute qui n'implique pas `en.json`.
//
//   (2) CRITÈRE D'ÉCRITURE — valeur de `el.json` ne contenant aucune lettre
//       grecque. Indépendant de (1) : c'est lui, et lui seul, qui a trouvé le
//       grec translittéré.
//       ANGLE MORT : ne vaut que pour le grec, seule locale à changer
//       d'alphabet. Les neuf autres partagent l'alphabet latin, aucun critère
//       structurel ne les sépare.
//
//   (4) REGISTRE D'ADRESSE — `DOC-ADDR-1`, amendé le 07/09/2026 : l'app tutoie
//       SANS EXCEPTION, politique de confidentialité et messages système
//       compris. 163 chaînes françaises et 52 espagnoles vouvoyaient ce jour-là,
//       alors que la doctrine était actée depuis le 04/06 — troisième doctrine
//       du §0 trouvée écrite et non tenue en deux jours. Le motif cherche le
//       pronom ou le possessif de politesse ; « rendez-vous » est exclu par
//       construction, et les adresses au PLURIEL (à une assemblée, à un
//       collectif) sont nommées une par une dans `PLURIEL_LEGITIME`.
//       ANGLE MORT : ne couvre que fr et es, seules locales relues ce jour ;
//       it, de, ca, nl, el ont aussi un vouvoiement et attendent leur passe.
//
//   (3) FORMES FAUTIVES CERTAINES — motifs dont l'absence de diacritique n'est
//       jamais un homographe.
//       ANGLE MORT, et c'est le plus important : ce chemin ne trouve QUE ce
//       qui est dans `FORMES_FAUTIVES`. Son chiffre est un PLANCHER, jamais un
//       total. Élargir la liste est un travail légitime et attendu.
//
// DEUX MESURES FAUSSES ONT PRÉCÉDÉ CELLES-CI, et le dire fait partie du relevé.
// Un premier essai comparait chaque valeur ASCII au lexique accentué de son
// propre fichier : 570 « fautes » en néerlandais, parce que *een*/*één* et
// *que*/*què* sont des homographes légitimes. Un second mettait `catalogo`
// dans les motifs italiens — mot qui, en italien, NE PORTE PAS d'accent : 123
// faux positifs. Les deux mesuraient ce qu'elles regardaient, pas ce qui était
// vrai. D'où la règle appliquée ici : un motif n'entre dans
// `FORMES_FAUTIVES` que si sa forme sans diacritique n'existe pas comme mot
// autonome dans la langue.
// ─────────────────────────────────────────────────────────────────────────────

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const ici = dirname(fileURLToPath(import.meta.url));
const DOSSIER = resolve(ici, '../i18n/locales');

const LOCALES = ['pt-BR', 'fr', 'en', 'de', 'it', 'es', 'ca', 'eo', 'nl', 'el'];

const brut = (l) => readFileSync(resolve(DOSSIER, `${l}.json`), 'utf8');
const charge = (l) => JSON.parse(brut(l));

const TOUT = Object.fromEntries(LOCALES.map((l) => [l, charge(l)]));
const EN = TOUT.en;

// ─────────────────────────────────────────────────────────────────────────────
// DETTE — le grec en attente d'une camarade hellénophone.
//
// Ces onze clés sont FAUTIVES et connues comme telles depuis l'audit du
// 07/09/2026. Elles ne sont pas corrigées ici parce qu'une retranslittération
// faite par quelqu'un qui ne lit pas le grec produirait une faute de plus.
//
// CETTE LISTE NE PEUT QUE RÉTRÉCIR. Le test `la dette grecque ne contient
// aucune entrée devenue sans objet` échoue si l'une d'elles a été corrigée
// sans être retirée d'ici — sans quoi la dette deviendrait un cimetière et le
// garde-fou une décoration.
// ─────────────────────────────────────────────────────────────────────────────
const DETTE_GREC = [
  // (1) anglais laissé tel quel — commit 7300502e, 07/06/2026
  'catalogacao.isbnDup.badge',
  'catalogacao.presave.isbnExists',
  'catalogacao.presave.titleAuthorExists',
  'catalogacao.authlink.autoLinked',
  'account.profile.org',
  'panel.reader.org',
  // (2) grec translittéré en caractères latins — commit a1ce13ae, 07/06/2026
  'auth.create.errorCreateFailed',
  'auth.create.errorGeneric',
  'auth.create.errorLibraryNotReady',
  'auth.create.errorProfileFailed',
  'auth.create.errorServerConfig',
];

// Clés dont la valeur est légitimement sans lettre grecque dans `el.json` :
// sigles, identifiants techniques, noms de langue dans leur propre langue,
// exemples d'URL ou d'adresse. Chacune est nommée, aucune n'est un motif.
const EL_SANS_GREC_LEGITIME = [
  'atelier.volet4.classif.cdd',
  'catalogacao.author.sourceKind.viaf',
  'catalogacao.author.sourceKind.wikidata',
  'catalogacao.field.marcJson',
  'catalogacao.guide.zine.title',
  'catalogacao.material.zine',
  'catalogacao.ph.audioFormatTech',
  'catalogacao.ocr.badgeOcr',
  'importacoes.fila.table',
  'importacoes.rss.exampleUrl',
  'importacoes.reception.libSlugPlaceholder',
  'rede.cooptation.propose.modal.targetPlaceholder',
  'rede.reports.col.authoritiesA',
  'language.fr', 'language.id', 'language.nb', 'language.sk',
];

// Clés légitimement identiques à l'anglais dans toutes les locales latines.
// Volontairement courte : toute entrée ici est une traduction qu'on renonce à
// faire, et doit pouvoir se défendre.
const IDENTIQUE_A_EN_LEGITIME = [
  'app.name',
  'book.isbn', 'book.meta.isbn', 'book.meta.issn', 'book.meta.cdd',
  'catalogacao.form.isbn', 'catalogacao.form.issn', 'catalogacao.form.cdd',
  'catalogacao.field.marcJson',
  'atelier.volet4.classif.cdd',
  'importacoes.fila.table',
  'importacoes.rss.exampleUrl',
  'rede.reports.col.authoritiesA',
  // Vérifiées une par une le 07/09/2026 : ces chaînes s'écrivent à l'identique
  // en anglais et dans la langue cible. Ce n'est pas une traduction oubliée.
  'biblioteca.leitores.exportCsv',            // « Export CSV » — fr
  'biblioteca.leitores.exportPdf',            // « Export PDF » — fr
  'book.isbd.zone4',                          // « Zone 4 — Publication » — fr
  'book.isbd.zone7',                          // « Zone 7 — Notes » — fr
  'catalogacao.isbd.zone4',                   // fr
  'catalogacao.exemplar.acquisitionStep',     // fr
  'catalogacao.exemplar.provenanceNote',      // « Provenance / note » — fr
  'catalogacao.exemplar.labelCdd',            // « CDD (label) » — nl
  'resource.meta.sourceAttribution',          // « Source / attribution » — fr
  'catalogacao.ocr.stage.ocrPage',            // « OCR page … » — fr
  'importacoes.oai.lotsPerCycle',             // « {n} lots/cycle » — fr
  'address.state.GB',                         // « Nation / Region » — de
  'catalogacao.subjectGov.editNotation',      // « Notation (DDC) » — de
  'rede.gazeta.sources.feed',                 // « Feed (URL) » — de, nl
  'catalogacao.batch.openBatchesCount',       // « Open batches » — nl
  'catalogacao.queue.selectedAllFilter',      // « ✓ {count} in filter » — nl
  'transitions.type.1',                       // « Type 1 — direct » — nl
  'importacoes.reception.libTerritoryPlaceholder', // « Bologna, IT » — exemple
  'importacoes.wizard.source.fileLabel',      // « File (CSV, RIS, MARCXML…) » — it
  'panel.history.itemsCount',                 // « {count} document(s) » — es
  'ficedl.count',                             // « # descriptor(s) » — ca
];

// ─────────────────────────────────────────────────────────────────────────────
// Chemin (3) — formes dont l'absence de diacritique est une faute certaine.
// Critère d'admission : la forme sans diacritique NE DOIT PAS exister comme
// mot autonome de la langue. `catalogo` entre en espagnol et en portugais
// (« catálogo »), et reste dehors en italien, où le mot s'écrit sans accent.
// ─────────────────────────────────────────────────────────────────────────────
const FORMES_FAUTIVES = {
  fr: ['deja', 'autorite', 'autorites', 'reseau', 'donnees', 'depot',
       'bibliotheque', 'selectionnee', 'entierement', 'configuree', 'configuree',
       'ete', 'cree', 'creee', 'moderation', 'signalees', 'masquees',
       'publiees', 'reservee', 'exposes', 'activee', 'validee', 'adhesion',
       'reference', 'utilisee', 'partagees'],
       // NB : « partages » est SORTI de cette liste — c'est le verbe conjugué
       // (« ce que tu partages »), donc un homographe légitime.
  'pt-BR': ['catalogo', 'codigo', 'coordenacao', 'configuracao', 'nao', 'ja',
            'titulo', 'referencia', 'bibliografica', 'voce', 'vinculo'],
  es: ['catalogo', 'codigo', 'pagina', 'coordinacion', 'configuracion',
       'accion', 'titulo', 'autoria', 'boton', 'publico', 'publicas',
       'tecnico', 'indice', 'aun'],
  it: ['gia', 'perche', 'piu', 'puo', 'citta', 'autorita', 'quantita'],
  de: ['fuer', 'muessen', 'gewaehlten', 'uebergabe', 'waehlen', 'erfuellen',
       'verfuegbarkeit', 'persoenliche'],
  ca: ['cataleg', 'titol', 'pagina'],
  eo: ['chu', 'dauri', 'gxi', 'cxu', 'auxtoro'],
  nl: [],
  en: [],
  el: [],
};

// Clés dont la valeur DOIT rester sans diacritique : slugs, identifiants
// techniques, exemples d'URL. Corriger l'orthographe y casserait la valeur.
const ASCII_VOULU = [
  'importacoes.reception.libSlugPlaceholder', // « bibliotheque-partenaire » : slug
];

// Chemin (4) — vouvoiement. Une entrée par locale relue ; le motif de chaque
// langue est le sien, pas une traduction du motif français.
const VOUVOIEMENT = {
  fr: /\b(?<!rendez-)(vous|votre|vos)\b/i,
  es: /\b(usted|ustedes|Desea|Consulte|Retome|Ponga|Haga|Indique|Seleccione|Verifique|Contacte)\b/,
};

// Adresses au PLURIEL, à un collectif — ce n'est pas du vouvoiement — et
// MENTIONS du registre lui-même : la phrase liminaire de la politique de
// confidentialité nomme le vouvoiement pour dire qu'elle s'en passe.
const PLURIEL_LEGITIME = [
  'atelier.doctrine.text',   // « Asseyez-vous à plusieurs devant l'écran »
  'banner.profile.body',     // « discutez-en en assemblée »
  'privacy.register',        // « …comme le ferait un texte rédigé au vouvoiement » / « …de usted »
];

const GREC = /[Ͱ-Ͽἀ-῿]/;

// Retire ce qui n'est pas de la prose : balises, URL, mails, et l'ARMATURE des
// messages ICU — mots-clés (`plural`, `select`, `offset`), noms de variables et
// sélecteurs (`one`, `other`, `=0`). Le TEXTE des branches, lui, est conservé :
// c'est de la prose traduisible, et c'est là que vivent les fautes.
//
// Un `replace(/\{[^{}]*\}/g)` ne suffit PAS : l'ICU est imbriqué, et un motif
// non imbriqué mange les accolades intérieures en laissant l'extérieur. C'est
// exactement l'erreur qui a fait sonner ce test sur `catalogacao.authlink.
// autoLinked` alors que la valeur était juste.
const ICU_ARMATURE = /\{\s*[A-Za-z_][\w]*\s*,\s*(?:plural|select|selectordinal)\s*,|\boffset:\s*\d+|\{\s*[A-Za-z_][\w]*\s*\}|(?:^|[{\s])(?:=\d+|one|other|few|many|zero|two)\s*(?=\{)/g;

function prose(v) {
  return v
    .replace(/<[^>]*>/g, ' ')
    .replace(/https?:\/\/\S+/g, ' ')
    .replace(/\S+@\S+/g, ' ')
    .replace(ICU_ARMATURE, ' ')
    .replace(/[{}]/g, ' ');
}

describe('i18n — écriture des locales (DOC-PS-1)', () => {
  // ── 0. Le support lui-même ────────────────────────────────────────────────
  describe('encodage des fichiers', () => {
    for (const l of LOCALES) {
      it(`${l}.json — UTF-8 sans BOM, sauts de ligne LF`, () => {
        const texte = brut(l);
        expect(texte.charCodeAt(0), `${l}.json commence par un BOM`).not.toBe(0xfeff);
        expect(texte.includes('\r\n'), `${l}.json contient des CRLF`).toBe(false);
      });

      // Découvert le 07/09/2026 en faisant tourner ce test pour la première
      // fois : 111 valeurs étaient en Unicode DÉCOMPOSÉ (fr 56, ca 25, de 19,
      // pt-BR 11). « Créer » y était stocké `C r e ◌́ e r` — un « e » suivi
      // d'un accent combinant. À l'écran c'est identique ; en mémoire ce sont
      // deux chaînes différentes. La recherche ne trouve pas, le tri se
      // trompe, `===` échoue contre la même chaîne venue du code, et un
      // `\b` d'expression régulière coupe au milieu du mot.
      it(`${l}.json — toutes les valeurs en forme NFC (composée)`, () => {
        const decomposees = Object.entries(JSON.parse(texte))
          .filter(([, v]) => typeof v === 'string' && v.normalize('NFC') !== v)
          .map(([k]) => k);
        expect(
          decomposees,
          `${l} : ${decomposees.length} valeur(s) en NFD — ${decomposees.slice(0, 8).join(', ')}`,
        ).toEqual([]);
      });
    }
  });

  // ── 1. Diacritiques mangés ────────────────────────────────────────────────
  describe('chemin (3) — diacritiques mangés', () => {
    for (const l of LOCALES) {
      const motifs = FORMES_FAUTIVES[l];
      if (!motifs.length) continue;

      it(`${l}.json — aucune forme sans diacritique`, () => {
        const rx = new RegExp(`\\b(${motifs.join('|')})\\b`, 'i');
        const fautes = [];
        for (const [k, v] of Object.entries(TOUT[l])) {
          if (DETTE_GREC.includes(k) && l === 'el') continue;
          if (ASCII_VOULU.includes(k)) continue;
          const m = prose(v).match(rx);
          if (m) fautes.push(`${k} → « ${m[1]} » dans « ${v.slice(0, 70)} »`);
        }
        expect(
          fautes,
          `${l} : ${fautes.length} valeur(s) aux diacritiques mangés\n  ${fautes.slice(0, 10).join('\n  ')}`,
        ).toEqual([]);
      });
    }
  });

  // ── 2. Le grec s'écrit en grec ────────────────────────────────────────────
  describe('chemin (2) — el.json s\'écrit en alphabet grec', () => {
    it('aucune valeur de prose sans une seule lettre grecque, hors liste nommée', () => {
      const fautes = [];
      for (const [k, v] of Object.entries(TOUT.el)) {
        if (EL_SANS_GREC_LEGITIME.includes(k) || DETTE_GREC.includes(k)) continue;
        const p = prose(v);
        const motsLatins = p.match(/[A-Za-z]{3,}/g) || [];
        if (motsLatins.length >= 2 && !GREC.test(p)) {
          fautes.push(`${k} → « ${v.slice(0, 70)} »`);
        }
      }
      expect(
        fautes,
        `el.json : ${fautes.length} valeur(s) sans grec\n  ${fautes.slice(0, 10).join('\n  ')}\n` +
          'Si la valeur est légitimement latine (sigle, URL), ajoute la clé à ' +
          'EL_SANS_GREC_LEGITIME en disant pourquoi.',
      ).toEqual([]);
    });
  });

  // ── 3. Anglais laissé tel quel ────────────────────────────────────────────
  describe('chemin (1) — pas d\'anglais laissé tel quel', () => {
    const cles = Object.keys(EN);
    // Une valeur identique dans ≥ 7 locales est un terme technique partagé,
    // pas une traduction oubliée.
    const partout = new Set(
      cles.filter(
        (k) => LOCALES.filter((l) => TOUT[l][k] === EN[k]).length >= 7,
      ),
    );

    for (const l of LOCALES) {
      if (l === 'en') continue;
      it(`${l}.json — aucune valeur identique à en.json hors liste nommée`, () => {
        const fautes = [];
        for (const k of cles) {
          if (partout.has(k)) continue;
          if (IDENTIQUE_A_EN_LEGITIME.includes(k)) continue;
          if (l === 'el' && DETTE_GREC.includes(k)) continue;
          if (TOUT[l][k] !== EN[k]) continue;
          if (TOUT[l][k] === TOUT['pt-BR'][k]) continue; // identique à la source aussi
          const mots = (prose(EN[k]).match(/[A-Za-z]{2,}/g) || []).length;
          if (mots >= 2) fautes.push(`${k} → « ${EN[k].slice(0, 70)} »`);
        }
        expect(
          fautes,
          `${l} : ${fautes.length} valeur(s) restée(s) en anglais\n  ${fautes.slice(0, 10).join('\n  ')}\n` +
            'Si la chaîne est identique par nature dans cette langue, ajoute la ' +
            'clé à IDENTIQUE_A_EN_LEGITIME en disant pourquoi.',
        ).toEqual([]);
      });
    }
  });

  // ── 4. Registre d'adresse ─────────────────────────────────────────────────
  describe('chemin (4) — tutoiement (DOC-ADDR-1)', () => {
    for (const [l, rx] of Object.entries(VOUVOIEMENT)) {
      it(`${l}.json — aucune valeur au vouvoiement hors adresse plurielle nommée`, () => {
        const fautes = [];
        for (const [k, v] of Object.entries(TOUT[l])) {
          if (PLURIEL_LEGITIME.includes(k)) continue;
          const m = prose(v).match(rx);
          if (m) fautes.push(`${k} → « ${m[1]} » dans « ${v.slice(0, 70)} »`);
        }
        expect(
          fautes,
          `${l} : ${fautes.length} valeur(s) au vouvoiement\n  ${fautes.slice(0, 10).join('\n  ')}\n` +
            'Si la phrase s\'adresse à un collectif au pluriel, ajoute la clé à ' +
            'PLURIEL_LEGITIME en citant le passage.',
        ).toEqual([]);
      });
    }
  });

  // ── 5. La dette ne peut que rétrécir ──────────────────────────────────────
  // Sans ce test, DETTE_GREC deviendrait un cimetière : des clés corrigées y
  // resteraient inscrites, et la liste cesserait de dire quoi que ce soit.
  describe('dette grecque', () => {
    it('toutes les clés de DETTE_GREC existent', () => {
      const fantomes = DETTE_GREC.filter((k) => !(k in TOUT.el));
      expect(fantomes, `clés inexistantes dans el.json : ${fantomes.join(', ')}`).toEqual([]);
    });

    it('aucune entrée de dette n\'est devenue sans objet', () => {
      const reglees = DETTE_GREC.filter((k) => {
        const v = TOUT.el[k];
        const p = prose(v);
        const enAnglais = v === EN[k];
        const sansGrec = (p.match(/[A-Za-z]{3,}/g) || []).length >= 2 && !GREC.test(p);
        return !enAnglais && !sansGrec; // ni anglais, ni latin : c'est corrigé
      });
      expect(
        reglees,
        `${reglees.length} clé(s) corrigée(s) mais toujours inscrite(s) en dette — ` +
          `retire-les de DETTE_GREC : ${reglees.join(', ')}`,
      ).toEqual([]);
    });
  });
});
