-- Migration : confidence fiable = meilleur score candidat
-- Auteur  : Claude (Opus 4.8)
-- Session : Import/Export — fiabilisation matching & rapprochement
-- Date    : 2026-06-12 (UTC)
--
-- Pourquoi : la Fila de revisao affichait une confiance perimee/incoherente
-- (un match ISBN certain a score candidat 100 montrait confidence 0 ; les
-- possible_duplicate moyennaient conf 25 vs score candidat 87). La fonction
-- ingest.fn_match_partner_catalog_row CALCULE bien un score par candidat
-- (partner_catalog_match_candidates.match_score : ISBN=100, titre+auteur+
-- annee+editeur=90-92, titre+auteur=80-82, etc.) mais n'ecrivait PAS la
-- confiance sur la staging row -> partner_catalog_staging_rows.confidence
-- restait a sa valeur par defaut (0) ou a un residu d'experiences passees.
--
-- Fix : le wrapper ingest.fn_match_partner_catalog_run derive desormais
-- confidence = max(match_score des candidats de la ligne) apres le matching
-- (source de verite fiable, et = score du palier de concordance retenu).
-- On NE touche PAS la fonction-ligne de 27 Ko (refactor risque, hors scope).
-- Aucun candidat -> confidence 0 (new_record). Edition-aware : score eleve
-- = plus de champs concordants exactement = doublon d'edition plus probable.
--
-- + Backfill idempotent des lignes deja matchees (corrige l'historique sans
--   rejouer le matching).
--
-- Le band-aid SET statement_timeout TO '0' (cf. 20260611174540) est conserve
-- dans la definition ci-dessous (pas de regression de perf).

-- ──────────────────────────────────────────────────────────────────────────
-- 1) Wrapper de matching : persister la confiance apres le matching
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION ingest.fn_match_partner_catalog_run(
  p_run_id bigint,
  p_row_ids bigint[] DEFAULT NULL::bigint[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'ingest', 'public', 'auth'
SET statement_timeout TO '0'
AS $function$
declare
  v_row_count integer := 0;
  v_matched_count integer := 0;
  v_refresh jsonb;
  rec record;
begin
  if not exists (
    select 1
    from ingest.partner_catalog_import_runs
    where id = p_run_id
  ) then
    raise exception 'import_run % introuvable', p_run_id;
  end if;

  update ingest.partner_catalog_import_runs
     set run_status = case
       when run_status = 'drafts_created' then run_status
       else 'matching'
     end
   where id = p_run_id;

  for rec in
    select sr.id
    from ingest.partner_catalog_staging_rows sr
    where sr.run_id = p_run_id
      and (
        coalesce(array_length(p_row_ids, 1), 0) = 0
        or sr.id = any(p_row_ids)
      )
    order by sr.row_no, sr.id
  loop
    v_row_count := v_row_count + 1;
    perform ingest.fn_match_partner_catalog_row(rec.id);
    v_matched_count := v_matched_count + 1;
  end loop;

  -- ── Confiance fiable : meilleur score candidat ────────────────────────
  -- fn_match_partner_catalog_row n'ecrit pas la confiance sur la staging row.
  -- On la derive ici du meilleur score parmi ses candidats de matching.
  -- Aucun candidat (new_record) -> 0.
  update ingest.partner_catalog_staging_rows sr
     set confidence = coalesce((
           select max(mc.match_score)
           from ingest.partner_catalog_match_candidates mc
           where mc.staging_row_id = sr.id
         ), 0)
   where sr.run_id = p_run_id
     and (
       coalesce(array_length(p_row_ids, 1), 0) = 0
       or sr.id = any(p_row_ids)
     );

  v_refresh := ingest.fn_refresh_partner_catalog_run_counters(p_run_id);

  return jsonb_build_object(
    'run_id', p_run_id,
    'requested_rows', v_row_count,
    'matched_rows', v_matched_count,
    'run', v_refresh
  );
end;
$function$;

-- SECURITY DEFINER : verrouiller l'execution (doctrine .githooks).
REVOKE EXECUTE ON FUNCTION ingest.fn_match_partner_catalog_run(bigint, bigint[]) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION ingest.fn_match_partner_catalog_run(bigint, bigint[]) TO service_role;

-- ──────────────────────────────────────────────────────────────────────────
-- 2) Backfill idempotent : corriger la confiance des lignes deja matchees
-- ──────────────────────────────────────────────────────────────────────────
UPDATE ingest.partner_catalog_staging_rows sr
   SET confidence = coalesce((
         SELECT max(mc.match_score)
         FROM ingest.partner_catalog_match_candidates mc
         WHERE mc.staging_row_id = sr.id
       ), 0)
 WHERE sr.confidence IS DISTINCT FROM coalesce((
         SELECT max(mc.match_score)
         FROM ingest.partner_catalog_match_candidates mc
         WHERE mc.staging_row_id = sr.id
       ), 0);
