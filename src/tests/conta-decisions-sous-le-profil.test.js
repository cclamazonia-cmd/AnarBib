// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/conta-decisions-sous-le-profil.test.js
//
// CE QUE CE TEST PROTÈGE (E19, 20/09/2026). L'onglet « Données personnelles » de
// Mon compte est le plus long de la page, et les trois blocs qui demandent une
// décision — exporter mes données, mes notifications, la lettre de la
// fédération — vivaient tout en bas, après l'adhésion et le compte de dépôt.
// Ils remontent juste sous le formulaire du profil, côte à côte ; la suppression
// du compte reste seule, dernière, en rouge.
//
// 21/09, décision de Xavier : l'adresse vivait dans le MÊME formulaire que le
// profil, et tenait les cartes sous la ligne de flottaison. Le formulaire est
// coupé : profil + Enregistrer, les trois cartes, puis adresse + Enregistrer.
// Les deux boutons font le même geste (handleSaveProfile écrit profil ET
// adresse) : cliquer l'un ne perd jamais ce qu'on a saisi dans l'autre.
//
// Rendre AccountPage entier ici (2 700 lignes, une session, une dizaine d'appels
// Supabase au montage) serait fragile pour ce qu'on veut prouver. Même patron
// que catalog-explore-replie.test.js : on lit la SOURCE et on garde le contrat.
//   1. l'ordre des blocs dans l'onglet : profil, les trois décisions, puis ce qui
//      se lit (déclaré, mot de passe, adhésion, dépôt, carte), puis la suppression ;
//   2. les trois cartes sont dans UNE grille, et la suppression n'y est pas ;
//   3. la grille est en minmax(0, 1fr) — jamais `1fr` nu, qui prend pour minimum
//      la largeur du contenu et fait déborder la page sur mobile — et passe à
//      une colonne sous 900 px (la fiche disait 640 : mesuré à 700 px, trois pistes
//      de 207 px tiennent mais la carte des notifications y fait 735 px de haut) ;
//   4. rien n'a été perdu en route : chaque geste garde son appel ;
//   5. l'adresse vient APRÈS les cartes, dans son propre formulaire, qui
//      enregistre comme celui du profil ; message et sablier suivent le bouton cliqué.
// Un test de source n'est pas un test de rendu : le rendu se vérifie à l'écran.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const lire = (rel) => readFileSync(path.resolve(here, '..', rel), 'utf8');

const page = lire('pages/account/AccountPage.jsx');
const css = lire('pages/account/AccountPage.css');

// L'onglet, et lui seul : de son ouverture à celle de l'onglet suivant.
const debut = page.indexOf("activeTab === 'perfil' && profile");
const fin = page.indexOf("activeTab === 'reservar'", debut);
const onglet = page.slice(debut, fin);

describe('Mon compte, « Données personnelles » — les décisions sous le profil (E19)', () => {
  it("l'onglet se laisse découper", () => {
    expect(debut).toBeGreaterThan(-1);
    expect(fin).toBeGreaterThan(debut);
  });

  it('ordre des blocs : profil, trois décisions, ce qui se lit, suppression en dernier', () => {
    const jalons = [
      'account.profile.title',
      'data-bloc="perfil"',
      'className="ab-conta-decisions"',
      'account.export.title',
      'account.notifPrefs.title',
      'account.lettre.title',
      'data-bloc="adresse"',
      '<AddressForm ',
      'account.declared.title',
      'handleChangePassword',
      '<ReaderCardSection />',
      'account.deleteAccount.title',
    ];
    const positions = jalons.map((j) => onglet.indexOf(j));
    positions.forEach((p, k) => expect(p, `jalon absent : ${jalons[k]}`).toBeGreaterThan(-1));
    for (let k = 1; k < positions.length; k++) {
      expect(positions[k], `« ${jalons[k]} » devrait suivre « ${jalons[k - 1]} »`).toBeGreaterThan(positions[k - 1]);
    }
  });

  it('une seule grille, trois cartes, et la suppression du compte hors de la grille', () => {
    expect(onglet.split('className="ab-conta-decisions"').length - 1).toBe(1);
    const ouverture = onglet.indexOf('<section className="ab-conta-decisions-bloc"');
    const fermeture = onglet.indexOf('</section>', ouverture);
    expect(ouverture).toBeGreaterThan(-1);
    expect(fermeture).toBeGreaterThan(ouverture);
    const rangee = onglet.slice(ouverture, fermeture);
    expect(rangee.match(/className="ab-conta-decision[ "]/g)).toHaveLength(3);
    for (const cle of ['account.export.title', 'account.notifPrefs.title', 'account.lettre.title']) {
      expect(rangee, cle).toContain(cle);
    }
    expect(rangee).not.toContain('account.deleteAccount');
    // La suppression est le dernier bloc : plus aucun titre de section après elle.
    const apres = onglet.slice(onglet.indexOf('account.deleteAccount.title'));
    expect(apres).not.toMatch(/<h[23][ >]/);
  });

  it('la grille : trois pistes minmax(0, 1fr), une colonne sous 900 px, jamais 1fr nu', () => {
    const regle = css.match(/\.ab-conta-decisions\s*\{[^}]*\}/);
    expect(regle, 'règle .ab-conta-decisions').not.toBeNull();
    expect(regle[0]).toMatch(/grid-template-columns:\s*repeat\(3,\s*minmax\(0,\s*1fr\)\)/);
    const mobile = css.match(/@media\s*\(max-width:\s*900px\)\s*\{\s*\.ab-conta-decisions\s*\{[^}]*\}/);
    expect(mobile, 'règle mobile de .ab-conta-decisions').not.toBeNull();
    expect(mobile[0]).toMatch(/grid-template-columns:\s*minmax\(0,\s*1fr\)/);
    // La carte elle-même accepte de rétrécir sous la largeur de son contenu.
    expect(css).toMatch(/\.ab-conta-decision\s*\{[^}]*min-width:\s*0/);
  });

  it("l'adresse a son propre formulaire, qui enregistre comme celui du profil", () => {
    for (const bloc of ['perfil', 'adresse']) {
      expect(onglet.split(`<form onSubmit={handleSaveProfile} data-bloc="${bloc}"`).length - 1, bloc).toBe(1);
    }
    expect(onglet.split('<AddressForm ').length - 1).toBe(1);
    // le formulaire du profil ne contient plus l'adresse
    const profil = onglet.slice(onglet.indexOf('data-bloc="perfil"'), onglet.indexOf('</form>', onglet.indexOf('data-bloc="perfil"')));
    expect(profil).not.toContain('<AddressForm');
    expect(profil).not.toContain('address.title');
    // chaque bouton porte son propre message et son propre sablier
    for (const bloc of ['perfil', 'adresse']) {
      expect(onglet, bloc).toContain(`loading={saving && saveBloc === '${bloc}'}`);
      expect(onglet, bloc).toContain(`{msg && saveBloc === '${bloc}' &&`);
    }
    // et le geste note quel bouton a été cliqué
    expect(page).toContain("setSaveBloc(e.currentTarget?.dataset?.bloc === 'adresse' ? 'adresse' : 'perfil')");
  });

  it("rien n'est perdu en route : chaque geste garde son appel, une seule fois", () => {
    for (const appel of ['<DataExportButton />', 'fn_set_my_notification_preferences', 'fn_lettre_request_optin', 'fn_lettre_cancel', 'fn_delete_my_account']) {
      expect(onglet.split(appel).length - 1, appel).toBe(1);
    }
  });
});
