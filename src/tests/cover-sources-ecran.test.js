// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/cover-sources-ecran.test.js
//
// Ce que l'écran de catalogage dit et enregistre autour de la recherche de
// couvertures (27/09/2026).
//
// 1. Une source en panne est NOMMÉE : la voie ISBN d'Open Library répondait 404
//    et l'écran disait « aucune couverture trouvée ».
// 2. La provenance et la licence de la capa partent au brouillon : le formulaire
//    les posait dans son état sans jamais les envoyer — 0 capa attribuée sur 250
//    en production, alors que la spec capas §4.3 en fait une exigence.
// 3. Un fichier choisi puis « Enregistrer » directement : la charge utile relisait
//    `cover_object_path` dans l'état React d'AVANT l'envoi du fichier.
// 4. Une candidate trouvée par ISBN n'est plus tenue pour certaine : l'édition que
//    l'ISBN désigne est confrontée à la notice. Cas réel du 27/09 : BTL-TL-002335
//    (Ramparts Press, 1971) portait l'ISBN de l'édition AK Press de 2004, et la
//    galerie a proposé la couverture de 2004 sans rien signaler.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { sourcesEnPanne, messageRechercheCapas, accordEdition, motsEditeur, anneeDe } from '../lib/coverSources.js';
import { volumesDifferents } from '../lib/volumes.js';

const FORM = readFileSync(new URL('../pages/catalogacao/BookDraftForm.jsx', import.meta.url), 'utf8');

describe('sourcesEnPanne — nommer ce qui a échoué, et seulement ça', () => {
  it('une source en échec est nommée avec son erreur', () => {
    expect(sourcesEnPanne([{ id: 'openlibrary', ok: false, error: 'HTTP 404' }])).toEqual(['Open Library (HTTP 404)']);
  });

  it('une source sautée ou muette n’est pas une panne', () => {
    expect(sourcesEnPanne([
      { id: 'openlibrary', ok: true, count: 0 },
      { id: 'inventaire', ok: true, count: 0, skipped: true },
      { id: 'og_image', ok: true, count: 0, skipped: true },
    ])).toEqual([]);
  });

  it('deux voies d’Open Library qui échouent pareil ne sont dites qu’une fois', () => {
    expect(sourcesEnPanne([
      { id: 'openlibrary', ok: false, error: 'HTTP 503' },
      { id: 'openlibrary_search', ok: false, error: 'HTTP 503' },
      { id: 'inventaire', ok: false, error: 'HTTP 502' },
    ])).toEqual(['Open Library (HTTP 503)', 'Inventaire (HTTP 502)']);
  });

  it('un bilan absent ou mal formé ne casse rien', () => {
    expect(sourcesEnPanne(undefined)).toEqual([]);
    expect(sourcesEnPanne([null, {}])).toEqual([]);
  });
});

describe('messageRechercheCapas', () => {
  const panne = [{ id: 'openlibrary', ok: false, error: 'HTTP 404' }];

  it('rien trouvé ET une source en panne : une erreur qui la nomme — plus « aucune couverture »', () => {
    expect(messageRechercheCapas({ candidates: [], sources: panne })).toEqual({
      id: 'catalogacao.ui.coverLookupSourcesDown', values: { sources: 'Open Library (HTTP 404)' }, kind: 'error',
    });
  });

  it('rien trouvé, tout a répondu : le message d’avant', () => {
    expect(messageRechercheCapas({ candidates: [], sources: [{ id: 'openlibrary', ok: true, count: 0 }] }))
      .toEqual({ id: 'catalogacao.ui.coverLookupEmpty', kind: 'info' });
  });

  it('des candidates mais une source muette : la galerie est dite incomplète', () => {
    expect(messageRechercheCapas({ candidates: [{}], sources: panne })).toMatchObject({
      id: 'catalogacao.ui.coverLookupPartial', kind: 'info',
    });
  });

  it('des candidates, tout a répondu : rien à dire', () => {
    expect(messageRechercheCapas({ candidates: [{}], sources: [] })).toBeNull();
  });
});

describe('accordEdition — l’édition que désigne l’ISBN, confrontée à la notice', () => {
  const ak2004 = { edition: { annee: '2004', editeurs: ['AK Press'] } };

  it('le cas réel : notice Ramparts Press 1971, ISBN de l’édition AK Press 2004 → écart, les deux nommées', () => {
    expect(accordEdition(ak2004, { ano: '1971', editora: 'Ramparts Press' })).toEqual({
      statut: 'ecart', ecartAnnee: true, ecartEditeur: true, volume: null,
      trouvee: 'AK Press, 2004', notice: 'Ramparts Press, 1971',
    });
  });

  it('même éditeur, années éloignées (réimpression sous le même ISBN ?) → écart d’année seul', () => {
    const a = accordEdition({ edition: { annee: '2002', editeurs: ['Cultrix'] } }, { ano: '2007', editora: 'Editora Cultrix' });
    expect(a).toMatchObject({ statut: 'ecart', ecartAnnee: true, ecartEditeur: false });
  });

  it('la bonne notice → concordant', () => {
    expect(accordEdition(ak2004, { ano: '2004', editora: 'AK Press' })).toMatchObject({ statut: 'concordant' });
  });

  it('un an d’écart est toléré (dépôt légal, fin d’année)', () => {
    expect(accordEdition({ edition: { annee: '1986', editeurs: [] } }, { ano: '1987', editora: '' }))
      .toMatchObject({ statut: 'concordant', ecartAnnee: false });
  });

  it('les mots génériques et les accents ne comptent pas', () => {
    const imaginario = { edition: { annee: '2010', editeurs: ['Imaginario'] } };
    expect(accordEdition(imaginario, { ano: '2010', editora: 'Editora Imaginário' })).toMatchObject({ statut: 'concordant' });
    const letras = { edition: { annee: '1998', editeurs: ['Companhia das Letras'] } };
    expect(accordEdition(letras, { ano: '1998', editora: 'Cia. das Letras' })).toMatchObject({ statut: 'concordant' });
  });

  it('rien à comparer → inconnu (ni certitude, ni alarme)', () => {
    expect(accordEdition(ak2004, { ano: '', editora: '' })).toMatchObject({ statut: 'inconnu' });
    expect(accordEdition({ edition: { annee: null, editeurs: [] } }, { ano: '1971', editora: 'Ramparts Press' }))
      .toMatchObject({ statut: 'inconnu' });
  });

  it('une candidate trouvée par titre n’a pas d’édition à confronter', () => {
    expect(accordEdition({ source: 'openlibrary', label: 'x' }, { ano: '1971' })).toBeNull();
  });

  it('outils : années libres et mots d’éditeur', () => {
    expect(anneeDe('[c1971]')).toBe(1971);
    expect(anneeDe('0200')).toBeNull();
    expect([...motsEditeur("Éditions L'Harmattan")]).toEqual(['harmattan']);
    expect([...motsEditeur('L&PM Editores')]).toEqual(['pm']);
  });
});

describe('volumes — l’ISBN d’un ensemble porté par chacun de ses volumes', () => {
  // BTL-TL-000447 et BTL-TL-000448 : volumes 2 et 3 de « La C.N.T. y la
  // Revolución Española », même ISBN, même éditeur, même année.
  const ensemble = { edition: { annee: '1988', editeurs: ['Associación Artística La Cuchilla'] } };

  it('notice d’un volume : jamais « concordant », même éditeur et même année', () => {
    expect(accordEdition(ensemble, { ano: '1988', editora: 'Associación Artística La Cuchilla', volume: '2' }))
      .toMatchObject({ statut: 'volume', volume: '2', ecartAnnee: false, ecartEditeur: false });
  });

  it('un écart d’édition garde la priorité sur le volume', () => {
    expect(accordEdition(ensemble, { ano: '1971', editora: 'Ramparts Press', volume: '2' }))
      .toMatchObject({ statut: 'ecart', volume: '2' });
  });

  it('sans volume, rien ne change', () => {
    expect(accordEdition(ensemble, { ano: '1988', editora: 'La Cuchilla', volume: '' })).toMatchObject({ statut: 'concordant', volume: null });
  });

  it('volumesDifferents : les deux renseignés et différents, casse et espaces ignorés', () => {
    expect(volumesDifferents('2', '3')).toBe(true);
    expect(volumesDifferents(' III ', 'iii')).toBe(false);
    expect(volumesDifferents('2', '')).toBe(false);
    expect(volumesDifferents(null, '3')).toBe(false);
  });

  it('l’avertissement de doublon écarte les autres VOLUMES d’un même ISBN', () => {
    const detect = FORM.slice(FORM.indexOf('async function detectDuplicate()'), FORM.indexOf('// Digital resources CRUD'));
    expect(detect).toMatch(/volumesDifferents\(b\.volume, f\('volume'\)\)/);
    expect(detect).toMatch(/s\.match_kind === 'isbn' && autres\.has\(s\.book_id\)/);
  });

  it('la galerie transmet le volume de la notice et dit pourquoi vérifier', () => {
    expect(FORM).toMatch(/accordEdition\(c, \{ ano: f\('ano'\), editora: f\('editora'\), volume: f\('volume'\) \}\)/);
    expect(FORM).toContain("t({ id: 'catalogacao.ui.coverIsbnVolume' }, { volume: volumeCapas.volume })");
  });
});

describe('BookDraftForm — capa « page 1 du PDF » : le navigateur ne contacte pas la source', () => {
  it('un PDF externe est demandé à cover_lookup (action pdf), plus jamais par fetch()', () => {
    const pdf = FORM.slice(FORM.indexOf('async function generateCoverFromPdf()'), FORM.indexOf('// Contributors management'));
    expect(pdf).not.toMatch(/fetch\(resource\.source_url\)/);
    expect(pdf).toMatch(/body: \{ action: 'pdf', url: resource\.source_url \}/);
  });
});

describe('BookDraftForm — galerie : l’écart d’édition est dit', () => {
  it('chaque candidate est confrontée à l’année et à l’éditeur de la notice', () => {
    expect(FORM).toMatch(/accordEdition\(c, \{ ano: f\('ano'\), editora: f\('editora'\)/);
  });

  it('un écart s’affiche au-dessus des vignettes, avec les deux éditions', () => {
    expect(FORM).toMatch(/t\(\{ id: 'catalogacao\.ui\.coverIsbnEcart' \}, \{ trouvee: ecartCapas\.trouvee/);
  });

  it('la vignette en écart porte « À vérifier », la concordante « ISBN concordant »', () => {
    expect(FORM).toContain("t({ id: 'catalogacao.ui.coverIsbnVerifier' })");
    expect(FORM).toContain("t({ id: 'catalogacao.ui.coverIsbnConcordant' })");
  });
});

describe('BookDraftForm — provenance et licence de la capa', () => {
  it('la recherche passe par messageRechercheCapas (le bilan des sources n’est plus ignoré)', () => {
    expect(FORM).toMatch(/messageRechercheCapas\(data\)/);
  });

  it('la charge utile du brouillon emporte cover_source et cover_license', () => {
    const payload = FORM.slice(FORM.indexOf('const payload = {'), FORM.indexOf('let result;'));
    expect(payload).toMatch(/cover_source:/);
    expect(payload).toMatch(/cover_license:/);
  });

  it('le rechargement d’un brouillon les relit (sinon le prochain enregistrement les effacerait)', () => {
    expect(FORM).toMatch(/cover_source: r\.cover_source \|\| ''/);
    expect(FORM).toMatch(/cover_license: r\.cover_license \|\| ''/);
  });

  it('un envoi manuel est attribué « manual »', () => {
    const debut = FORM.indexOf('async function uploadCover()');
    const upload = FORM.slice(debut, FORM.indexOf('async function runCoverLookup()', debut));
    expect(debut).toBeGreaterThan(-1);
    expect(upload).toMatch(/set\('cover_source', 'manual'\)/);
  });

  it('à l’enregistrement, le chemin d’un fichier juste envoyé vient du retour d’uploadCover, pas de l’état d’avant', () => {
    expect(FORM).toMatch(/const envoye = coverFile \? await uploadCover\(\) : null;/);
    expect(FORM).toMatch(/cover_object_path: envoye \|\| f\('cover_object_path'\) \|\| null/);
  });
});
