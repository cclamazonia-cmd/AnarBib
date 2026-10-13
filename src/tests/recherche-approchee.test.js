// Recherche approchée et formulaire d'autorité (11/10/2026).
//
// (1) Le catalogue cherche aussi par les autres noms de l'autorité liée, puis,
//     si rien d'exact ne sort, à une ou deux lettres près (migration
//     20261011211012) ; la réponse le signale (approx_author / approx_search,
//     ou rangs négatifs de catalog_search_ids_v1) et l'écran doit le dire.
// (2) Le formulaire d'autorité n'a plus de liste de brouillons récents en tête,
//     et chaque champ de biographie porte le nom de sa langue.
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { LOCALE_CODES } from '../i18n/locales.js';

const racine = path.resolve(__dirname, '../..');
const lire = (f) => readFileSync(path.join(racine, f), 'utf8');
const LOCALES = LOCALE_CODES;
const locale = (l) => JSON.parse(lire(`src/i18n/locales/${l}.json`));

describe('le catalogue dit quand ses résultats sont approchés', () => {
  const src = lire('src/pages/public/CatalogPage.jsx');

  it('lit les deux drapeaux de catalog_works_v1 et les rangs négatifs de la liste plate', () => {
    expect(src).toContain('setApproxMatch(Boolean(data?.approx_author || data?.approx_search))');
    expect(src).toContain('sr.every(r => Number(r.rank) < 0)');
    // une nouvelle recherche efface la pastille ; une page suivante ne la touche pas
    expect(src).toContain('if (!append) { setDegradedSince(null); setApproxMatch(false); }');
  });

  it('affiche la pastille, traduite dans les dix langues', () => {
    expect(src).toMatch(/approxMatch && !loading && \(\s*<Pill variant="warn"><span role="status">\{t\(\{ id: 'catalog\.results\.approx' \}\)\}/);
    for (const l of LOCALES) expect(locale(l)['catalog.results.approx'], l).toBeTruthy();
    expect(locale('fr')['catalog.results.approx']).toMatch(/une ou deux lettres/);
  });

  it('la migration garde la règle : exact d\'abord, approché seulement si rien', () => {
    const mig = lire('supabase/migrations/20261011211012_la_recherche_lit_les_variantes_et_pardonne_les_fautes.sql');
    expect(mig).toContain('IF NOT v_trouve THEN');
    expect(mig).toContain('return query execute v_sql using p_q, false;\n  if not found then\n    return query execute v_sql using p_q, true;');
    expect(mig).toContain("CASE WHEN pg_catalog.length(p_mot) >= 8 THEN 2 ELSE 1 END");
  });
});

describe('le formulaire d\'autorité', () => {
  const src = lire('src/pages/catalogacao/AuthorDraftForm.jsx');

  it('n\'a plus de liste de brouillons récents ni de bouton pour la rafraîchir', () => {
    expect(src).not.toContain('loadDrafts');
    expect(src).not.toContain('drafts.map(');
    expect(src).not.toContain("catalogacao.ui.refreshList");
  });

  it('titre chaque champ de biographie par sa langue, dans les dix langues', () => {
    expect(src).toContain('{t({ id: BIO_TITLE_KEYS[lang] })}');
    expect(src).not.toContain("<span style={{ fontWeight: 700, fontSize: '.82rem' }}>{lang}</span>");
    const codes = LOCALE_CODES.map((c) => c.replace('-', ''));
    for (const l of LOCALES) for (const c of codes) expect(locale(l)[`catalogacao.bio.titleIn.${c}`], `${l}/${c}`).toBeTruthy();
    expect(locale('fr')['catalogacao.bio.titleIn.fr']).toBe('Biographie en français');
    expect(locale('fr')['catalogacao.bio.titleIn.nl']).toBe('Biographie en néerlandais');
  });

  it('ne garde le champ général que tant que l\'autorité n\'est pas publiée (ou une ancienne bio jamais traduite)', () => {
    expect(src).toContain("(!f('published_author_id') || (bioTranslations.length === 0 && f('biography').trim())) && inp('biography',");
    // les dix champs ne sont plus repliés sous « Traductions existantes »
    expect(src).not.toContain("catalogacao.bio.translations'");
  });
});
