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

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { sourcesEnPanne, messageRechercheCapas } from '../lib/coverSources.js';

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
