// Troisième phase : migration de données depuis resultats-idref.json (IdRef, ABES).
const fs = require('fs');
const [, , SORTIE] = process.argv;
const ICI = __dirname;
const res = JSON.parse(fs.readFileSync(ICI + '/resultats-idref.json', 'utf8')).filter((r) => r.decision === 'accepte');
const auteurs = new Map(JSON.parse(fs.readFileSync(ICI + '/authors-p3.json', 'utf8')).map((a) => [a.id, a]));
const q = (s) => (s === null || s === undefined ? 'NULL' : `'${String(s).replace(/'/g, "''")}'`);
const lignes = [];
for (const r of res) {
  const a = auteurs.get(r.id); if (!a) continue;
  if (!/^\d{8}[\dX]$/.test(r.idref.ppn)) continue;
  const f = r.remplir || {};
  lignes.push(`  (${a.id}, ${q(a.preferred_name)}, ${q(r.idref.ppn)}, ${q(r.idref.preuve)}, ${f.naissance ?? 'NULL'}, ${f.mort ?? 'NULL'}, ${q(f.pays)}, ${q(f.langue)})`);
}
const n = lignes.length;
const sql = `-- =========================================================================
-- Autorités, troisième phase : IdRef (27/09/2026)
-- =========================================================================
-- Réf. : backlog v34 C4 ; demande de Xavier du 26/09 (« une phase 3 avec une
--        bibliothèque brésilienne ou sud-américaine »), relevé validé le 27/09 ;
--        docs/journal/operations/enrichissement-autorites-2026-09-26/ (§ Troisième phase).
--
-- Les bibliothèques nationales du Brésil et d'Argentine ferment leur accès
-- automatisé (403, X-Services refusés) : non contourné. IdRef (autorités des
-- bibliothèques universitaires françaises, ABES) porte la nationalité (102), la
-- langue (101) et les dates (103), et de nombreux auteurs brésiliens et
-- hispano-américains traduits ou étudiés en France.
--
-- ${n} fiches : vedette IdRef (sans précisions) identique à la forme de tri, ET preuve —
-- un titre de l'auteur au catalogue AnarBib (deux mots significatifs au moins)
-- parmi les documents SUDOC liés à la notice, ou des dates concordantes.
-- Écrit : external_ids.idref + trace idref_releve ; et, seulement là où c'est
-- vide : années (si la vedette ne les contredit pas), pays (102, nationalité),
-- langue (101, si unique et confirmée par les livres au catalogue ou le pays).
-- Garde : id ET forme retenue du relevé ; coalesce partout ; rien n'est écrasé.
-- =========================================================================

BEGIN;

CREATE TEMP TABLE enrichissement_idref (id bigint, nom text, ppn text, preuve text, naissance int, mort int, pays text, langue text) ON COMMIT DROP;
INSERT INTO enrichissement_idref VALUES
${lignes.join(',\n')};

WITH cible AS (
  SELECT e.*,
         a.birth_year IS NULL AND e.naissance IS NOT NULL AS f_naissance,
         a.death_year IS NULL AND e.mort IS NOT NULL      AS f_mort,
         a.country IS NULL AND e.pays IS NOT NULL         AS f_pays,
         a.writing_language IS NULL AND e.langue IS NOT NULL AS f_langue
    FROM public.authors a
    JOIN enrichissement_idref e ON e.id = a.id AND e.nom = a.preferred_name
)
UPDATE public.authors a
   SET birth_year       = coalesce(a.birth_year, c.naissance),
       death_year       = CASE WHEN a.death_year IS NULL AND c.mort >= coalesce(a.birth_year, c.naissance, c.mort) THEN c.mort ELSE a.death_year END,
       country          = coalesce(a.country, c.pays),
       writing_language = coalesce(a.writing_language, c.langue),
       external_ids     = coalesce(a.external_ids, '{}'::jsonb)
                          || CASE WHEN a.external_ids ? 'idref' THEN '{}'::jsonb ELSE jsonb_build_object('idref', c.ppn) END
                          || jsonb_build_object('idref_releve', jsonb_build_object(
                               'ppn', c.ppn, 'date', '2026-09-27', 'preuve', c.preuve,
                               'champs', to_jsonb(array_remove(ARRAY[
                                 CASE WHEN c.f_naissance THEN 'birth_year' END, CASE WHEN c.f_mort THEN 'death_year' END,
                                 CASE WHEN c.f_pays THEN 'country' END, CASE WHEN c.f_langue THEN 'writing_language' END], NULL)))),
       updated_at       = now()
  FROM cible c
 WHERE a.id = c.id;

DO $$
DECLARE v_total int; v_presents int; v_ecarts text;
BEGIN
  SELECT count(*), count(a.id) INTO v_total, v_presents
    FROM enrichissement_idref e LEFT JOIN public.authors a ON a.id = e.id AND a.preferred_name = e.nom;
  IF v_presents = 0 THEN
    RAISE NOTICE 'Enrichissement IdRef : aucune des fiches relevées dans cette base (banc) — rien à appliquer.';
    RETURN;
  END IF;
  IF v_presents < v_total THEN
    RAISE EXCEPTION 'Enrichissement IdRef : % fiches sur % retrouvées (id + forme retenue) — on n''applique pas à moitié.', v_presents, v_total;
  END IF;
  SELECT string_agg(e.id::text, ', ') INTO v_ecarts
    FROM enrichissement_idref e JOIN public.authors a ON a.id = e.id
   WHERE NOT (a.external_ids ? 'idref') OR NOT (a.external_ids ? 'idref_releve')
      OR (e.naissance IS NOT NULL AND a.birth_year IS NULL)
      OR (e.pays IS NOT NULL AND a.country IS NULL)
      OR (e.langue IS NOT NULL AND a.writing_language IS NULL);
  IF v_ecarts IS NOT NULL THEN
    RAISE EXCEPTION 'Enrichissement IdRef : fiches incomplètes après application : %', v_ecarts;
  END IF;
  RAISE NOTICE 'Enrichissement IdRef : % fiches liées à IdRef.', v_total;
END $$;

COMMIT;
`;
fs.writeFileSync(SORTIE, sql);
console.log(n + ' fiches');
