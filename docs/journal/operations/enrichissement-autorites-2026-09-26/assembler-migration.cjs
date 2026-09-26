// Assemble la migration de données : en-tête + VALUES engendrées + application + vérification.
const fs = require('fs');
const [, , VALEURS, SORTIE] = process.argv;
const valeurs = fs.readFileSync(VALEURS, 'utf8').trimEnd();
const n = valeurs.split('\n').length;
const sql = `-- =========================================================================
-- Autorités : dates, pays, langue d'écriture et identifiants depuis Wikidata (26/09/2026)
-- =========================================================================
-- Réf. : backlog v34 C4 (pays manquants) et C8 (dates, identifiants externes) ;
--        demande de Xavier du 26/09 (« compléter l'ensemble des fiches auteurs :
--        nationalité, année de naissance/mort, langue d'écriture principale »,
--        carte blanche sur la méthode, application validée le 26/09) ;
--        note docs/journal/operations/ENRICHISSEMENT_autorites_wikidata_2026-09-26.md
--        (méthode, règles, échantillons, listes à relire).
--
-- ${n} fiches. Chaque ligne vient d'un rapprochement nom → Wikidata (CC0) accepté
-- seulement si : nom identique (ordre des mots près), aucune contradiction avec la
-- fiche ni avec le catalogue (dates, pays, pas de naissance après les premières
-- publications), ET dates concordantes OU deux signaux indépendants (identifiant de
-- bibliothèque nationale, métier d'écriture, anarchisme déclaré). Justesse mesurée
-- sur un échantillon aléatoire de 60 : 60/60.
--
-- On ne REMPLIT que ce qui est vide : coalesce partout, rien n'est écrasé, les noms
-- (forme retenue, forme de tri, variantes, pseudonymes) ne sont pas touchés (C8).
-- Une fiche n'est touchée que si son id ET sa forme retenue sont ceux du relevé :
-- sur une autre base (banc de la CI), rien ne correspond, rien ne bouge.
-- Le type « personne » n'est posé que si la colonne ET structured_meta.authorityType
-- sont vides (le jsonb est la source d'écriture, trg_sync_authority_type).
-- Trace : external_ids.wikidata_releve = { qid, date, champs remplis } — la
-- publication d'un brouillon réécrit structured_meta, pas external_ids.
-- =========================================================================

BEGIN;

CREATE TEMP TABLE enrichissement (id bigint, nom text, qid text, naissance int, mort int, pays text, langue text, viaf text, isni text) ON COMMIT DROP;
INSERT INTO enrichissement VALUES
${valeurs};

-- 1) Les champs vides, seulement
WITH cible AS (
  SELECT e.*,
         a.birth_year IS NULL AND e.naissance IS NOT NULL AS f_naissance,
         a.death_year IS NULL AND e.mort IS NOT NULL      AS f_mort,
         a.country IS NULL AND e.pays IS NOT NULL         AS f_pays,
         a.writing_language IS NULL AND e.langue IS NOT NULL AS f_langue,
         a.wikidata_id IS NULL                            AS f_wikidata,
         a.viaf_id IS NULL AND e.viaf IS NOT NULL         AS f_viaf,
         a.isni IS NULL AND e.isni IS NOT NULL            AS f_isni,
         a.authority_type IS NULL AND coalesce(a.structured_meta->>'authorityType', '') = '' AS f_type
    FROM public.authors a
    JOIN enrichissement e ON e.id = a.id AND e.nom = a.preferred_name
)
UPDATE public.authors a
   SET birth_year       = coalesce(a.birth_year, c.naissance),
       death_year       = CASE WHEN a.death_year IS NULL AND c.mort >= coalesce(a.birth_year, c.naissance, c.mort) THEN c.mort ELSE a.death_year END,
       country          = coalesce(a.country, c.pays),
       writing_language = coalesce(a.writing_language, c.langue),
       wikidata_id      = coalesce(a.wikidata_id, c.qid),
       viaf_id          = coalesce(a.viaf_id, c.viaf),
       isni             = coalesce(a.isni, c.isni),
       authority_type   = CASE WHEN c.f_type THEN 'person' ELSE a.authority_type END,
       structured_meta  = CASE WHEN c.f_type THEN coalesce(a.structured_meta, '{}'::jsonb) || '{"authorityType":"person"}'::jsonb ELSE a.structured_meta END,
       external_ids     = coalesce(a.external_ids, '{}'::jsonb) || jsonb_build_object('wikidata_releve', jsonb_build_object(
                            'qid', c.qid, 'date', '2026-09-26',
                            'champs', to_jsonb(array_remove(ARRAY[
                              CASE WHEN c.f_naissance THEN 'birth_year' END, CASE WHEN c.f_mort THEN 'death_year' END,
                              CASE WHEN c.f_pays THEN 'country' END, CASE WHEN c.f_langue THEN 'writing_language' END,
                              CASE WHEN c.f_wikidata THEN 'wikidata_id' END, CASE WHEN c.f_viaf THEN 'viaf_id' END,
                              CASE WHEN c.f_isni THEN 'isni' END, CASE WHEN c.f_type THEN 'authority_type' END], NULL)))),
       updated_at       = now()
  FROM cible c
 WHERE a.id = c.id;

-- 2) Vérification
DO $$
DECLARE v_total int; v_presents int; v_ecarts text;
BEGIN
  SELECT count(*), count(a.id) INTO v_total, v_presents
    FROM enrichissement e LEFT JOIN public.authors a ON a.id = e.id AND a.preferred_name = e.nom;
  IF v_presents = 0 THEN
    RAISE NOTICE 'Enrichissement : aucune des fiches relevées dans cette base (banc) — rien à appliquer.';
    RETURN;
  END IF;
  IF v_presents < v_total THEN
    RAISE EXCEPTION 'Enrichissement : % fiches sur % retrouvées (id + forme retenue) — une fiche a changé depuis le relevé, on n''applique pas à moitié.', v_presents, v_total;
  END IF;
  -- Chaque valeur relevée est désormais en place (posée ici, ou déjà présente et laissée).
  SELECT string_agg(e.id::text, ', ') INTO v_ecarts
    FROM enrichissement e JOIN public.authors a ON a.id = e.id
   WHERE a.wikidata_id IS NULL
      OR (e.naissance IS NOT NULL AND a.birth_year IS NULL)
      OR (e.pays IS NOT NULL AND a.country IS NULL)
      OR (e.langue IS NOT NULL AND a.writing_language IS NULL)
      OR NOT (a.external_ids ? 'wikidata_releve');
  IF v_ecarts IS NOT NULL THEN
    RAISE EXCEPTION 'Enrichissement : fiches incomplètes après application : %', v_ecarts;
  END IF;
  RAISE NOTICE 'Enrichissement : % fiches enrichies depuis Wikidata.', v_total;
END $$;

COMMIT;
`;
fs.writeFileSync(SORTIE, sql);
console.log(n + ' lignes');
