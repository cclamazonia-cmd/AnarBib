// Seconde phase : migration de données depuis resultats-loc.json (Library of Congress).
const fs = require('fs');
const [, , SORTIE] = process.argv;
const ICI = __dirname;
const res = JSON.parse(fs.readFileSync(ICI + '/resultats-loc.json', 'utf8')).filter((r) => r.decision === 'accepte');
const auteurs = new Map(JSON.parse(fs.readFileSync(ICI + '/authors.json', 'utf8')).map((a) => [a.id, a]));
const q = (s) => (s === null || s === undefined ? 'NULL' : `'${String(s).replace(/'/g, "''")}'`);
const lignes = [];
for (const r of res) {
  const a = auteurs.get(r.id); if (!a) continue;
  const lccn = r.lc.uri.split('/').pop();
  if (!/^n[a-z]?\d+$/.test(lccn)) continue;
  const f = r.remplir || {};
  lignes.push(`  (${a.id}, ${q(a.preferred_name)}, ${q(lccn)}, ${q(r.lc.preuve)}, ${f.naissance ?? 'NULL'}, ${f.mort ?? 'NULL'}, ${q(f.pays)}, ${q(f.langue)})`);
}
const n = lignes.length;
const sql = `-- =========================================================================
-- Autorités, seconde phase : Library of Congress (26/09/2026)
-- =========================================================================
-- Réf. : backlog v34 C4, C8 ; demande de Xavier du 26/09 (« lance la seconde phase ») ;
--        docs/journal/operations/enrichissement-autorites-2026-09-26/ (README, § Seconde phase).
--
-- ${n} fiches rapprochées du fichier d'autorités de la LC (id.loc.gov) : vedette
-- identique à la forme de tri (sans dates ni précisions), ET preuve — un titre de
-- l'auteur au catalogue AnarBib cité dans les sources de la notice LC (670), ou des
-- dates concordantes avec la fiche. Le nom seul ne suffit jamais.
--
-- Écrit : l'identifiant LC (external_ids.lccn) et la trace (external_ids.lc_releve) ;
-- et, seulement là où c'est encore vide après la phase Wikidata (20260926193111) :
-- années (champ 046 ou vedette), pays du LIEU DE NAISSANCE (la LC n'a pas de champ
-- nationalité — dit dans la trace), langue (seulement si la LC n'en donne qu'une ET
-- qu'elle est celle des livres de l'auteur au catalogue ou de son pays).
-- Garde : id ET forme retenue du relevé ; coalesce partout ; rien n'est écrasé.
-- =========================================================================

BEGIN;

CREATE TEMP TABLE enrichissement_lc (id bigint, nom text, lccn text, preuve text, naissance int, mort int, pays text, langue text) ON COMMIT DROP;
INSERT INTO enrichissement_lc VALUES
${lignes.join(',\n')};

WITH cible AS (
  SELECT e.*,
         a.birth_year IS NULL AND e.naissance IS NOT NULL AS f_naissance,
         a.death_year IS NULL AND e.mort IS NOT NULL      AS f_mort,
         a.country IS NULL AND e.pays IS NOT NULL         AS f_pays,
         a.writing_language IS NULL AND e.langue IS NOT NULL AS f_langue
    FROM public.authors a
    JOIN enrichissement_lc e ON e.id = a.id AND e.nom = a.preferred_name
)
UPDATE public.authors a
   SET birth_year       = coalesce(a.birth_year, c.naissance),
       death_year       = CASE WHEN a.death_year IS NULL AND c.mort >= coalesce(a.birth_year, c.naissance, c.mort) THEN c.mort ELSE a.death_year END,
       country          = coalesce(a.country, c.pays),
       writing_language = coalesce(a.writing_language, c.langue),
       external_ids     = coalesce(a.external_ids, '{}'::jsonb)
                          || CASE WHEN a.external_ids ? 'lccn' THEN '{}'::jsonb ELSE jsonb_build_object('lccn', c.lccn) END
                          || jsonb_build_object('lc_releve', jsonb_build_object(
                               'lccn', c.lccn, 'date', '2026-09-26', 'preuve', c.preuve,
                               'champs', to_jsonb(array_remove(ARRAY[
                                 CASE WHEN c.f_naissance THEN 'birth_year' END, CASE WHEN c.f_mort THEN 'death_year' END,
                                 CASE WHEN c.f_pays THEN 'country (lieu de naissance)' END, CASE WHEN c.f_langue THEN 'writing_language' END], NULL)))),
       updated_at       = now()
  FROM cible c
 WHERE a.id = c.id;

DO $$
DECLARE v_total int; v_presents int; v_ecarts text;
BEGIN
  SELECT count(*), count(a.id) INTO v_total, v_presents
    FROM enrichissement_lc e LEFT JOIN public.authors a ON a.id = e.id AND a.preferred_name = e.nom;
  IF v_presents = 0 THEN
    RAISE NOTICE 'Enrichissement LC : aucune des fiches relevées dans cette base (banc) — rien à appliquer.';
    RETURN;
  END IF;
  IF v_presents < v_total THEN
    RAISE EXCEPTION 'Enrichissement LC : % fiches sur % retrouvées (id + forme retenue) — on n''applique pas à moitié.', v_presents, v_total;
  END IF;
  SELECT string_agg(e.id::text, ', ') INTO v_ecarts
    FROM enrichissement_lc e JOIN public.authors a ON a.id = e.id
   WHERE NOT (a.external_ids ? 'lccn') OR NOT (a.external_ids ? 'lc_releve')
      OR (e.naissance IS NOT NULL AND a.birth_year IS NULL)
      OR (e.pays IS NOT NULL AND a.country IS NULL)
      OR (e.langue IS NOT NULL AND a.writing_language IS NULL);
  IF v_ecarts IS NOT NULL THEN
    RAISE EXCEPTION 'Enrichissement LC : fiches incomplètes après application : %', v_ecarts;
  END IF;
  RAISE NOTICE 'Enrichissement LC : % fiches liées à la Library of Congress.', v_total;
END $$;

COMMIT;
`;
fs.writeFileSync(SORTIE, sql);
console.log(n + ' fiches');
