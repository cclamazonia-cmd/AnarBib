-- =============================================================================
-- Supprimer un run d'import ne doit pas abandonner son lot de catalogage
-- =============================================================================
-- Date     : 2026-08-29
-- Chantier : catalogage / importations — suite du paquet « lots fermables »
--
-- CE QUI S'EST PASSE. `public.fn_import_delete_run` supprime le run et, par
-- CASCADE, toutes ses lignes du schema `ingest` (fichiers, lignes d'attente,
-- liens ligne->rascunho, journal de dispatch). Mais le LOT de catalogage
-- (`public.catalog_batches`) et les BROUILLONS qu'il a fait naitre vivent dans
-- `public`, et rien ne les emportait.
--
-- Vecu le 28/08/2026 : les runs #13 et #14 (CIRA Marseille) ont ete supprimes
-- depuis l'ecran d'import ; le lot 55 « Import parceiro #13 — CIRA Marseille »
-- et ses 237 brouillons sont restes, sans plus aucun ecran ou lire d'ou ils
-- venaient. La personne qui catalogue voit des brouillons dont la provenance
-- n'existe plus — et la provenance, elle, est irrecuperable : le run est parti.
--
-- LE CHOIX. Trois conduites possibles : orpheliner (l'actuelle), tout emporter,
-- ou refuser tant qu'il reste du travail. C'est la troisieme qui est retenue :
-- emporter detruirait sans decision un brouillon retravaille a la main apres
-- l'import, alors que refuser ne coute qu'un geste — traiter le lot d'abord,
-- puis supprimer le run.
--
-- CE QUI BLOQUE, EXACTEMENT. Les brouillons ACTIFS du/des lot(s) nes de ce run
-- (statut <> 'cancelled'). Ceux qui sont a la CORBEILLE ne bloquent pas : ils
-- ont deja ete ecartes, et depuis le meme jour l'onglet « Lots » sait supprimer
-- un lot avec sa corbeille en un geste. Refuser sur eux recreerait exactement
-- l'impasse qu'on vient de lever.
--
-- Le lien run -> lot se lit dans `ingest.partner_catalog_row_to_draft.batch_id`,
-- pose a la creation des brouillons — pas dans le NOM du lot, qui n'est qu'une
-- chaine et deriverait.
--
-- Corps repris VERBATIM de la fonction en place (pg_get_functiondef), avec le
-- seul bloc de garde ajoute : ne pas retaper une fonction pour la corriger.
-- =============================================================================

begin;

CREATE OR REPLACE FUNCTION public.fn_import_delete_run(p_run_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth'
AS $function$
DECLARE
  v_actor public.my_access%rowtype;
  v_run   ingest.partner_catalog_import_runs%rowtype;
  v_lots  bigint[];
  v_actifs bigint;
  v_noms  text;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  SELECT * INTO v_run FROM ingest.partner_catalog_import_runs WHERE id = p_run_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;
  IF v_run.library_id IS DISTINCT FROM v_actor.library_id
     AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Run % nao pertence a esta biblioteca', p_run_id;
  END IF;

  -- Le lot de catalogage ne CASCADE pas : il est dans public, le run dans
  -- ingest. Tant qu'il retient du travail vivant, on refuse plutot que de le
  -- laisser sans provenance. La corbeille du lot, elle, ne bloque pas.
  SELECT array_agg(DISTINCT m.batch_id) INTO v_lots
    FROM ingest.partner_catalog_row_to_draft m
   WHERE m.run_id = p_run_id AND m.batch_id IS NOT NULL;

  IF v_lots IS NOT NULL AND array_length(v_lots, 1) > 0 THEN
    SELECT (SELECT count(*) FROM public.book_drafts     d
             WHERE d.batch_id = ANY(v_lots) AND d.status <> 'cancelled')
         + (SELECT count(*) FROM public.author_drafts   d
             WHERE d.batch_id = ANY(v_lots) AND d.status <> 'cancelled')
         + (SELECT count(*) FROM public.exemplar_drafts d
             WHERE d.batch_id = ANY(v_lots) AND d.status <> 'cancelled')
      INTO v_actifs;

    IF v_actifs > 0 THEN
      SELECT string_agg(b.name, ' ; ' ORDER BY b.id) INTO v_noms
        FROM public.catalog_batches b WHERE b.id = ANY(v_lots);
      RAISE EXCEPTION
        'Run % : le lot de catalogage « % » retient encore % brouillon(s) actif(s). Traiter le lot avant de supprimer le run.',
        p_run_id, coalesce(v_noms, '?'), v_actifs
        USING HINT = 'error.import.run_has_drafts';
    END IF;
  END IF;

  -- Objet storage : la suppression DIRECTE de storage.objects est interdite par
  -- Supabase ('Direct deletion from storage tables is not allowed') -> best-effort,
  -- on ignore l'echec (fichier eventuellement orphelin, non bloquant).
  IF v_run.bucket_id IS NOT NULL AND v_run.storage_path IS NOT NULL THEN
    BEGIN
      DELETE FROM storage.objects
       WHERE bucket_id = v_run.bucket_id AND name = v_run.storage_path;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  -- Le run -> CASCADE sur import_files / staging_rows / row_to_draft / dispatch_log
  DELETE FROM ingest.partner_catalog_import_runs WHERE id = p_run_id;

  RETURN jsonb_build_object('ok', true, 'deleted_run', p_run_id);
END;
$function$;

COMMENT ON FUNCTION public.fn_import_delete_run(bigint) IS
  'Supprime un run d''import et ses lignes ingest.* (CASCADE). Refuse si le lot '
  'de catalogage issu du run retient encore des brouillons ACTIFS — la corbeille '
  'du lot ne bloque pas. Garde ajoutee le 29/08/2026 : jusque-la le lot et ses '
  'brouillons restaient sans provenance (lot 55, CIRA Marseille).';

-- -----------------------------------------------------------------------------
-- Verification structurelle
-- -----------------------------------------------------------------------------
-- Le comportement, lui, se verifie dans tests/sql/import_suppression_run_lot_tests.sql :
-- la fonction exige un JWT, elle n'est pas appelable ici.
do $verif$
begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'fn_import_delete_run'
       and p.prosecdef
       and exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c
                    where c like 'search_path=%')
  ) then
    raise exception 'fn_import_delete_run : SECURITY DEFINER ou search_path perdu au remplacement';
  end if;

  -- Le remplacement ne doit avoir ouvert la fonction ni a anon ni a PUBLIC.
  if exists (
    select 1 from information_schema.routine_privileges
     where routine_schema = 'public' and routine_name = 'fn_import_delete_run'
       and grantee in ('anon', 'PUBLIC')
  ) then
    raise exception 'fn_import_delete_run : droit de trop (anon ou PUBLIC)';
  end if;
end
$verif$;

commit;

-- =============================================================================
-- CONTROLE APRES DEPLOIEMENT
-- =============================================================================
-- Les lots nes d'un import dont le run n'existe plus (le cas a ne plus creer) :
--
--   select b.id, b.name,
--          (select count(*) from public.book_drafts d
--            where d.batch_id = b.id and d.status <> 'cancelled') as actifs
--     from public.catalog_batches b
--    where b.name like 'Import parceiro #%'
--      and not exists (select 1 from ingest.partner_catalog_row_to_draft m
--                       where m.batch_id = b.id);
-- =============================================================================
