-- =============================================================================
-- Import de catalogues : voir les doublons QUE LE LOT PORTE EN LUI-MEME
-- =============================================================================
-- Date     : 2026-08-28
-- Chantier : importations (suite du lot Solidaires)
--
-- LE MANQUE, CONSTATE SUR UN LOT REEL.
--
-- fn_match_partner_catalog_row compare chaque ligne AU CATALOGUE EXISTANT. Rien,
-- nulle part, ne compare les lignes du lot ENTRE ELLES. Un fichier qui contient
-- deux fois le meme ouvrage sort donc avec deux lignes 'new_record', deux
-- decisions 'accept_new', et la promotion cree deux livres sans que personne
-- n'ait rien vu passer.
--
-- Ce n'est pas un cas d'ecole. Le listing de la Bibliotheque Solidaires (run 18,
-- 1674 notices, 27/08/2026) en portait NEUF paires : sept ouvrages ranges sous
-- deux rubriques a la fois — ce que fait un classement par etageres quand un
-- livre releve de deux sujets — plus deux cas particuliers. Les neuf sont
-- sorties 'new_record'. Elles n'ont ete trouvees qu'a la main, par un GROUP BY
-- ecrit apres coup ; le prochain lot n'aurait pas eu cette chance.
--
-- CE QUE CETTE MIGRATION FAIT, ET SURTOUT CE QU'ELLE NE FAIT PAS.
--
-- Elle SIGNALE, elle ne decide pas. Les lignes concernees passent en
-- match_status='possible_duplicate' — une valeur qui existait deja dans la CHECK
-- et que la page d'import sait afficher — et recoivent dans `warnings` la liste
-- de leurs jumelles. Aucune decision editoriale n'est touchee : c'est un humain
-- qui tranche, et il a de bonnes raisons de trancher differemment d'un cas a
-- l'autre.
--
-- Deux exemples du meme lot, qui commandent tout le reste :
--   - « Le talon de fer » de Jack London, deux fois SOUS LA MEME RUBRIQUE. Deux
--     exemplaires sur l'etagere, ou une fiche saisie deux fois ? La base ne peut
--     pas le savoir. La question est partie au collectif.
--   - « La cassure », deux fois aussi — mais l'une de Martina Cole, l'autre d'un
--     collectif. Deux livres homonymes. Les fusionner aurait detruit une notice.
--
-- D'ou le choix de la CLE : titre + mention de responsabilite, jamais le titre
-- seul. Le titre seul aurait signale « La cassure » ; il aurait fallu ensuite
-- apprendre aux gens a ignorer un signalement, ce qui est la meilleure facon de
-- leur faire ignorer le suivant.
--
-- La normalisation est volontairement grossiere (minuscules, ponctuation reduite
-- a l'espace) : on cherche la repetition d'une meme saisie dans un meme fichier,
-- pas une ressemblance bibliographique. Le rapprochement fin, c'est le travail de
-- fn_match_partner_catalog_row, contre le catalogue.
--
-- REJOUABLE : la fonction efface d'abord ses propres traces (le warning qu'elle
-- ecrit, et le statut qu'elle a pose) avant de re-signaler. Un lot corrige puis
-- re-analyse ne garde donc pas de signalement perime. Elle ne touche JAMAIS une
-- ligne appariee au catalogue ('matched_book', 'matched_draft') : cet appariement
-- en dit plus que le sien.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. La detection
-- -----------------------------------------------------------------------------
create or replace function ingest.fn_flag_intra_run_duplicates(p_run_id bigint)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'ingest', 'public', 'pg_temp'
as $function$
declare
  v_lignes  int := 0;
  v_groupes int := 0;
begin
  if not exists (select 1 from ingest.partner_catalog_import_runs where id = p_run_id) then
    raise exception 'import_run % introuvable', p_run_id;
  end if;

  -- 1a. Effacer nos propres traces, et seulement les notres. On ne rend son
  --     statut qu'a une ligne que NOUS avions signalee : le warning fait foi.
  update ingest.partner_catalog_staging_rows sr
     set match_status = 'new_record',
         warnings = coalesce((
           select jsonb_agg(w)
             from jsonb_array_elements(coalesce(sr.warnings, '[]'::jsonb)) w
            where w->>'kind' is distinct from 'intra_run_duplicate'
         ), '[]'::jsonb)
   where sr.run_id = p_run_id
     and sr.match_status = 'possible_duplicate'
     and exists (
       select 1 from jsonb_array_elements(coalesce(sr.warnings, '[]'::jsonb)) w
        where w->>'kind' = 'intra_run_duplicate'
     );

  -- 1b. Re-signaler.
  with norme as (
    select sr.id,
           coalesce(sr.external_key, sr.id::text) as cle,
           btrim(regexp_replace(lower(coalesce(sr.title, '')),
                                '[^[:alnum:]]+', ' ', 'g')) as t,
           btrim(regexp_replace(lower(coalesce(sr.responsibility_statement, '')),
                                '[^[:alnum:]]+', ' ', 'g')) as a
      from ingest.partner_catalog_staging_rows sr
     where sr.run_id = p_run_id
       and sr.match_status in ('unreviewed', 'new_record')
  ),
  groupes as (
    select t, a,
           array_agg(id order by id) as ids,
           array_agg(cle order by id) as cles
      from norme
     where t <> ''
     group by t, a
    having count(*) > 1
  ),
  aplati as (
    select g.t, g.a, g.cles, u.id
      from groupes g cross join lateral unnest(g.ids) as u(id)
  ),
  maj as (
    update ingest.partner_catalog_staging_rows sr
       set match_status = 'possible_duplicate',
           warnings = coalesce((
               select jsonb_agg(w)
                 from jsonb_array_elements(coalesce(sr.warnings, '[]'::jsonb)) w
                where w->>'kind' is distinct from 'intra_run_duplicate'
             ), '[]'::jsonb)
             || jsonb_build_array(jsonb_build_object(
                  'kind', 'intra_run_duplicate',
                  'jumelles', to_jsonb(array_remove(
                                f.cles, coalesce(sr.external_key, sr.id::text))),
                  'cle', 'titre+responsabilite'
                ))
      from aplati f
     where sr.id = f.id
    returning sr.id, f.t || '|' || f.a as groupe
  )
  select count(*), count(distinct groupe) into v_lignes, v_groupes from maj;

  return jsonb_build_object(
    'run_id',           p_run_id,
    'groupes',          coalesce(v_groupes, 0),
    'lignes_signalees', coalesce(v_lignes, 0)
  );
end;
$function$;

comment on function ingest.fn_flag_intra_run_duplicates(bigint) is
  'Signale les lignes d''un MEME lot d''import qui se repetent (cle : titre + mention '
  'de responsabilite normalises). Pose match_status=''possible_duplicate'' et un warning '
  '{kind:intra_run_duplicate, jumelles:[...]}. NE DECIDE RIEN : editorial_decision n''est '
  'pas touche, la fusion reste un geste humain. Ne touche pas une ligne appariee au '
  'catalogue. Rejouable : efface ses propres traces avant de re-signaler.';

-- -----------------------------------------------------------------------------
-- 2. La brancher sur le chemin qui tourne deja
-- -----------------------------------------------------------------------------
-- Corps repris a l'IDENTIQUE de l'existant, a un appel pres, place APRES le
-- calcul de confiance et AVANT le rafraichissement des compteurs — pour que les
-- compteurs voient les statuts qu'on vient d'ecrire. Aucun bouton nouveau : tout
-- import passe deja par ici, donc tout import futur en beneficie sans geste.
create or replace function ingest.fn_match_partner_catalog_run(p_run_id bigint, p_row_ids bigint[] default null::bigint[])
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'ingest', 'public', 'auth'
 set statement_timeout to '120s'
as $function$
declare
  v_row_count integer := 0;
  v_matched_count integer := 0;
  v_refresh jsonb;
  v_intra jsonb;
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

  -- ── Doublons internes au lot ──────────────────────────────────────────
  -- Le rapprochement ci-dessus regarde le CATALOGUE. Il ne voit pas qu'un lot
  -- porte deux fois le meme ouvrage. Toujours sur le lot entier, jamais sur le
  -- sous-ensemble p_row_ids : une jumelle hors du sous-ensemble reste une
  -- jumelle, et l'ignorer ferait dependre le resultat du decoupage de l'appel.
  v_intra := ingest.fn_flag_intra_run_duplicates(p_run_id);

  v_refresh := ingest.fn_refresh_partner_catalog_run_counters(p_run_id);

  return jsonb_build_object(
    'run_id', p_run_id,
    'requested_rows', v_row_count,
    'matched_rows', v_matched_count,
    'doublons_internes', v_intra,
    'run', v_refresh
  );
end;
$function$;

-- -----------------------------------------------------------------------------
-- 3. Droits
-- -----------------------------------------------------------------------------
-- Le schema ingest n'est pas expose par PostgREST, mais une fonction est grantee
-- a PUBLIC par defaut : on ferme, comme partout ailleurs dans ce depot.
revoke execute on function ingest.fn_flag_intra_run_duplicates(bigint) from public, anon;

-- -----------------------------------------------------------------------------
-- 4. Verification STRUCTURELLE
-- -----------------------------------------------------------------------------
-- Structure seulement : en CI les migrations tournent AVANT le seed, une
-- assertion qui aurait besoin de lignes d'import ne s'executerait jamais. Le
-- comportement est couvert par tests/sql/import_doublons_intra_lot_tests.sql.
do $verif$
declare
  v_n int;
begin
  if to_regprocedure('ingest.fn_flag_intra_run_duplicates(bigint)') is null then
    raise exception 'fn_flag_intra_run_duplicates absente';
  end if;

  -- 'possible_duplicate' doit rester dans la CHECK : la fonction l'ecrit.
  -- On confronte a la contrainte ELLE-MEME, pas a une liste recopiee ici.
  select count(*) into v_n
    from pg_constraint c
    join pg_class r on r.oid = c.conrelid
    join pg_namespace n on n.oid = r.relnamespace
   where n.nspname = 'ingest'
     and r.relname = 'partner_catalog_staging_rows'
     and c.conname = 'partner_catalog_staging_rows_match_status_check'
     and pg_get_constraintdef(c.oid) like '%possible_duplicate%';
  if v_n <> 1 then
    raise exception 'possible_duplicate n''est plus admis par la CHECK match_status';
  end if;

  -- Le rapprochement doit appeler la detection, sinon elle ne sert a rien.
  if pg_get_functiondef(to_regprocedure('ingest.fn_match_partner_catalog_run(bigint, bigint[])'))
       not like '%fn_flag_intra_run_duplicates%' then
    raise exception 'fn_match_partner_catalog_run n''appelle pas la detection intra-lot';
  end if;
end
$verif$;

commit;

-- =============================================================================
-- CONTROLE APRES DEPLOIEMENT
-- =============================================================================
--   select ingest.fn_flag_intra_run_duplicates(18);
--   -- Attendu sur le lot Solidaires : 2 groupes, 4 lignes. Les sept doublons
--   -- par double classement ont ete fusionnes le 28/08 (les absorbees sont en
--   -- editorial_decision='reject' mais gardent match_status='new_record', donc
--   -- elles restent visibles a la detection : c'est voulu, le signalement dit
--   -- ce que le fichier contient, pas ce qu'on en a decide).
--   -- Restent donc « Le talon de fer » (2) et les sept paires fusionnees si on
--   -- rejoue avant arbitrage.
--
--   select external_key, match_status, warnings
--     from ingest.partner_catalog_staging_rows
--    where run_id = 18 and match_status = 'possible_duplicate'
--    order by external_key;
-- =============================================================================
