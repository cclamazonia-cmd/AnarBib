// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/flux-et-digest-banc.test.js
//
// BANC DES TROIS DERNIÈRES FONCTIONS À ADRESSE EN DUR (21/09/2026) — dette app-url,
// lot 4c : `opds` (flux de la bibliothèque numérique publique), `rss-novidades`
// (nouveautés d'une bibliothèque) et `notify-rede-digest` (digest hebdomadaire du
// réseau). Vraies fonctions, par src/tests/helpers/monter-ef.js.
//   - `opds` et `notify-rede-digest` n'étaient exécutés par AUCUN test : le banc
//     épingle d'abord ce qu'ils rendent (garde publique, liens, désabonnement) ;
//   - `rss-novidades` a son banc (rss-novidades.test.js) ; ici, ses liens seuls.

import { describe, it, expect } from 'vitest';
import { monterEF, liens, mailA } from './helpers/monter-ef.js';

const href = (xml) => [...String(xml).matchAll(/href="([^"]+)"/g)].map((m) => m[1]);

function monterOpds(env = {}) {
  const lectures = [];
  const ef = monterEF({
    entree: 'opds/index.ts',
    env,
    repondre: (_s, table, a, chaine) => {
      lectures.push({ table, chaine });
      if (table === 'book_digital_resources') return { data: [{ id: 5, book_id: 12, mime_type: 'application/pdf', storage_bucket: 'digital-public', storage_path: "reclus/L'Homme et la Terre.pdf", language_code: 'fr', rights_status: 'public_domain', attribution_text: null, updated_at: '2026-09-02T10:00:00Z' }], error: null };
      if (table === 'books') return { data: [{ id: 12, titulo: "L'Homme & la Terre", subtitulo: null, volume: null, autor: 'RECLUS, Élisée', ano: '1905', idioma: 'fr', bib_ref: 'BLMF-0012', cover_object_path: null, editora: null }], error: null };
      return { data: null, error: null };
    },
  });
  return { ef, lectures };
}

function monterRss(env = {}) {
  return monterEF({
    entree: 'rss-novidades/index.ts',
    env,
    repondre: (_s, table) => {
      if (table === 'libraries_public_v1') return { data: { slug: 'blmf', name: 'Biblioteca', short_name: 'BLMF', city: 'Belém' }, error: null };
      if (table === 'v_books_public_catalog_v2') return { data: [{ book_id: 12, bib_ref: 'BLMF-0012', titulo: 'Titre', subtitulo: null, autor: 'A', author_display: null, editora: null, ano: null, created_at: '2026-09-02T10:00:00Z', tipo_material: 'livro' }], error: null };
      return { data: null, error: null };
    },
  });
}

const SECRET = 'secret-digest';
function monterDigest(env = {}, { resend } = {}) {
  return monterEF({
    entree: 'notify-rede-digest/index.ts',
    env: { WEBHOOK_SECRET_NOTIFY_REDE_DIGEST: SECRET, ...env },
    resend,
    repondre: (_s, table, a) => {
      if (table === 'gazette_issues') return { data: [{ id: 'g-1', number: 4, masthead_title: 'Fractale n° 04', published_at: '2026-09-15T00:00:00Z' }], error: null };
      if (table === 'circles') return { data: [{ id: 'c-1', name: 'Cercle du Sud', description: 'Entraide <locale>', created_at: '2026-09-16T00:00:00Z', is_open: true }], error: null };
      if (table === 'profiles') return { data: [{ id: 'u-1', email: 'une@exemplo.test', first_name: 'Une', preferred_language: 'fr' }, { id: 'u-2', email: 'pas-une-adresse', first_name: 'X', preferred_language: 'fr' }], error: null };
      if (table === 'lettre_consent_tokens') return a('insert') ? { data: [{ user_id: 'u-1', token: 'jeton-1' }], error: null } : { data: [], error: null };
      return { data: null, error: null };
    },
  });
}
const POST = (secret) => new Request('http://stub/functions/v1/notify-rede-digest', { method: 'POST', headers: { 'content-type': 'application/json', ...(secret ? { 'x-webhook-secret': secret } : {}) }, body: '{}' });

describe('opds — le flux de la bibliothèque numérique publique', () => {
  it('racine : un flux de navigation ; chemin inconnu : 404', async () => {
    const { ef } = monterOpds();
    const racine = await ef.appeler(new Request('http://stub/functions/v1/opds'));
    expect(racine.statut).toBe(200);
    expect(racine.texte).toContain('http://stub/functions/v1/opds/all');
    expect((await ef.appeler(new Request('http://stub/functions/v1/opds/autre'))).statut).toBe(404);
  });

  it('/all : la garde publique est appliquée telle quelle, le titre est échappé, le chemin de storage encodé, et la notice pointe vers l\'application', async () => {
    const { ef, lectures } = monterOpds();
    const r = await ef.appeler(new Request('http://stub/functions/v1/opds/all'));
    expect(r.statut).toBe(200);
    const garde = lectures.find((l) => l.table === 'book_digital_resources').chaine.find((c) => c.op === 'match').args[0];
    expect(garde).toEqual({ access_scope: 'publico', status: 'active', is_active: true });
    expect(r.texte).toContain('L&apos;Homme &amp; la Terre');
    // encodeURIComponent garde l'apostrophe ; c'est l'échappement XML qui la rend.
    expect(r.texte).toContain('http://stub/storage/v1/object/public/digital-public/reclus/L&apos;Homme%20et%20la%20Terre.pdf');
    expect(href(r.texte)).toContain('https://app.anarbib.org/livro/BLMF-0012');
    expect(r.texte).toContain('<uri>https://app.anarbib.org</uri>');
  });
});

describe('notify-rede-digest — le digest hebdomadaire du réseau', () => {
  it('sans le secret du webhook : 401, rien ne part', async () => {
    const ef = monterDigest();
    expect((await ef.appeler(POST(null))).statut).toBe(401);
    expect((await ef.appeler(POST('autre'))).statut).toBe(401);
    expect(ef.envois).toHaveLength(0);
  });

  it('les abonné·es à adresse valide reçoivent gazette et cercles, avec les liens vers l\'application et le désabonnement par jeton', async () => {
    const ef = monterDigest();
    const r = await ef.appeler(POST(SECRET));
    expect(r.corps).toMatchObject({ ok: true, sent: 1, errors_count: 0, items: { gazette: 1, circles: 1 } });
    expect(ef.envois.map((e) => e.to[0])).toEqual(['une@exemplo.test']);
    const m = mailA(ef.envois, 'une@exemplo.test');
    expect(liens(m.html)).toEqual(expect.arrayContaining(['https://app.anarbib.org/federacao/gazeta', 'https://app.anarbib.org/federacao/circulos', 'http://stub/functions/v1/lettre-unsubscribe?token=jeton-1']));
    expect(m.html).toContain('Entraide &lt;locale&gt;');
    expect(m.text).toContain('https://app.anarbib.org/federacao/gazeta');
  });

  it('transport en panne : le compte rendu le dit (sent 0, l\'adresse et la cause)', async () => {
    const ef = monterDigest({}, { resend: () => new Response('panne', { status: 500 }) });
    const r = await ef.appeler(POST(SECRET));
    expect(r.corps).toMatchObject({ ok: true, sent: 0, errors_count: 1 });
    expect(r.corps.errors[0].email).toBe('une@exemplo.test');
  });
});

// ── Les liens suivent APP_BASE_URL (21/09/2026) ────────────────────────────────
// ROUGES sur le code intact (constante APP_URL écrite en dur dans les trois
// fonctions), verts depuis qu'elles passent par _shared/core/app-url.ts.
describe('flux et digest — les liens vers l\'application suivent APP_BASE_URL', () => {
  const ENV = { APP_BASE_URL: 'https://app.anarbib.is/' };

  it('opds : la notice et l\'<uri> de l\'auteur du flux', async () => {
    const r = await monterOpds(ENV).ef.appeler(new Request('http://stub/functions/v1/opds/all'));
    expect(href(r.texte)).toContain('https://app.anarbib.is/livro/BLMF-0012');
    expect(r.texte).toContain('<uri>https://app.anarbib.is</uri>');
    expect(r.texte).not.toContain('https://app.anarbib.org');
  });

  it('rss-novidades : la notice et le catalogue', async () => {
    const r = await monterRss(ENV).appeler(new Request('http://stub/functions/v1/rss-novidades/blmf'));
    expect(r.texte).toContain('<link>https://app.anarbib.is/livro/BLMF-0012</link>');
    expect(r.texte).toContain('<link>https://app.anarbib.is/catalogo/blmf</link>');
    expect(r.texte).not.toContain('https://app.anarbib.org');
  });

  it('notify-rede-digest : gazette et cercles, en HTML comme en texte', async () => {
    const ef = monterDigest(ENV);
    await ef.appeler(POST(SECRET));
    const m = mailA(ef.envois, 'une@exemplo.test');
    expect(liens(m.html)).toEqual(expect.arrayContaining(['https://app.anarbib.is/federacao/gazeta', 'https://app.anarbib.is/federacao/circulos']));
    expect(m.html).not.toContain('https://app.anarbib.org');
    expect(m.text).not.toContain('https://app.anarbib.org');
  });
});

describe('rss-novidades — les liens', () => {
  it('la notice et le catalogue de la bibliothèque pointent vers l\'application', async () => {
    const r = await monterRss().appeler(new Request('http://stub/functions/v1/rss-novidades/blmf'));
    expect(r.texte).toContain('<link>https://app.anarbib.org/livro/BLMF-0012</link>');
    expect(r.texte).toContain('<link>https://app.anarbib.org/catalogo/blmf</link>');
  });
});
