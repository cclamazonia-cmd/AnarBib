-- =========================================================================
-- Une reprise jamais enregistrée s'oublie : elle ne reste pas en file
-- éditoriale, ne va pas à la corbeille, ne laisse pas d'entrée au journal.
-- =========================================================================
-- Date     : 2026-10-03
-- Chantier : catalogage — file éditoriale
-- Auteur   : Claude (Opus 5.5), pour Xavier
-- Session  : Reprises vierges & confirmation d'enregistrement
--
-- Xavier, 03/10/2026 : « Un brouillon de reprise d'une œuvre, d'une édition,
-- d'un exemplaire ou d'une autorité, s'il n'est pas suivi d'une modification
-- enregistrée (sauvegardée même sans être publiée) ne doit pas rester en file
-- éditoriale. Il doit passer directement aux oubliettes et ne plus apparaître. »
--
-- Cas vécu : 20260928114148 a dû écarter à la main les brouillons 6276 et 6277,
-- ouverts par « Éditer » pendant une vérification et jamais modifiés.
--
-- Mécanique :
--   (1) retake_untouched, sur les trois tables de brouillons : vrai à la
--       naissance d'une reprise, faux dès la première écriture. Une reprise naît
--       des seules RPC create_{book,author,exemplar}_draft_from_* (SECURITY
--       DEFINER : current_user n'y est pas « authenticated ») — vérifié dans
--       pg_proc le 03/10 : aucune autre fonction n'insère action = 'update'.
--       Un enregistrement depuis l'écran passe par PostgREST (« authenticated ») :
--       il ne peut ni naître vierge, ni le redevenir.
--   (2) Toute écriture ultérieure le remet à faux — sauf fn_touch_draft_opened
--       (garde anarbib.skip_touch_updated_at : ouvrir n'est pas modifier) et ce
--       que fait la transaction de création elle-même (created_at = now() :
--       sync_exemplar_draft_holdings_bridge, semis des contributeurs/sujets).
--       Les sujets, ressources numériques et contributeurs d'une notice
--       s'écrivent en direct, sans repasser par book_drafts : leurs triggers
--       remettent aussi le drapeau de la notice à faux.
--   (3) discard_untouched_retake : l'éditeur l'appelle quand on quitte une
--       reprise (autre brouillon, nouveau formulaire, fermeture). Suppression
--       définitive SANS entrée au journal des suppressions : rien n'a été saisi,
--       il n'y a rien à rejouer. Ne touche qu'à une reprise encore vierge, de
--       son autrice (ou de l'administration réseau), sans exemplaire attaché.
--   (4) Filet : un job cron horaire oublie les reprises vierges ouvertes depuis
--       plus de 24 h (onglet fermé, coupure réseau).
--
-- La file, les compteurs et les listes des éditeurs filtrent retake_untouched
-- (frontend, même livraison).
--
-- CHECKLIST DOCTRINE
--   [x] SECURITY DEFINER : SET search_path ; REVOKE FROM PUBLIC, anon,
--       authenticated ; GRANT ciblé (discard → authenticated ; purge → personne)
--   [x] Fonctions trigger : aucun GRANT (privilège vérifié à la création)
--   [x] DO block de garde final
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- (1) La colonne
-- -------------------------------------------------------------------------
ALTER TABLE public.book_drafts     ADD COLUMN IF NOT EXISTS retake_untouched boolean NOT NULL DEFAULT false;
ALTER TABLE public.author_drafts   ADD COLUMN IF NOT EXISTS retake_untouched boolean NOT NULL DEFAULT false;
ALTER TABLE public.exemplar_drafts ADD COLUMN IF NOT EXISTS retake_untouched boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.book_drafts.retake_untouched IS
  'Reprise d''une notice publiée encore jamais enregistrée : hors file éditoriale, oubliée à l''abandon (20261003202521).';
COMMENT ON COLUMN public.author_drafts.retake_untouched IS
  'Reprise d''une autorité publiée encore jamais enregistrée : hors file éditoriale, oubliée à l''abandon (20261003202521).';
COMMENT ON COLUMN public.exemplar_drafts.retake_untouched IS
  'Reprise d''un exemplaire publié encore jamais enregistrée : hors file éditoriale, oubliée à l''abandon (20261003202521).';

-- Les reprises en cours, jamais modifiées (updated_at = created_at : défauts
-- now() de la même transaction, aucune écriture depuis). Le marquage ne compte
-- pas comme une écriture : updated_at reste celui de la naissance.
SELECT set_config('anarbib.skip_touch_updated_at', 'on', true);
UPDATE public.book_drafts     SET retake_untouched = true
 WHERE action = 'update' AND status = 'draft' AND updated_at = created_at;
UPDATE public.author_drafts   SET retake_untouched = true
 WHERE action = 'update' AND status = 'draft' AND updated_at = created_at;
UPDATE public.exemplar_drafts SET retake_untouched = true
 WHERE action = 'update' AND status = 'draft' AND updated_at = created_at;
SELECT set_config('anarbib.skip_touch_updated_at', '', true);

-- -------------------------------------------------------------------------
-- (2) Le drapeau naît avec la reprise et meurt à la première écriture
-- -------------------------------------------------------------------------
-- SECURITY INVOKER, et c'est voulu : current_user doit rester celui de
-- l'appel (propriétaire de la RPC de reprise, ou « authenticated »).
CREATE OR REPLACE FUNCTION public.tg_drafts_retake_untouched()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog, pg_temp
AS $$
BEGIN
  IF tg_op = 'INSERT' THEN
    NEW.retake_untouched := NEW.action = 'update'
                            AND NEW.created_at = now()
                            AND current_user NOT IN ('authenticated', 'anon');
    RETURN NEW;
  END IF;

  IF NOT OLD.retake_untouched THEN
    NEW.retake_untouched := false;          -- ne se réarme jamais
  ELSIF coalesce(current_setting('anarbib.skip_touch_updated_at', true), '') = 'on'
        OR OLD.created_at = now() THEN
    NEW.retake_untouched := OLD.retake_untouched;   -- ouverture, ou naissance
  ELSE
    NEW.retake_untouched := false;          -- une écriture : la reprise vit
  END IF;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.tg_drafts_retake_untouched() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_book_drafts_retake_untouched ON public.book_drafts;
CREATE TRIGGER trg_book_drafts_retake_untouched
  BEFORE INSERT OR UPDATE ON public.book_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_drafts_retake_untouched();
DROP TRIGGER IF EXISTS trg_author_drafts_retake_untouched ON public.author_drafts;
CREATE TRIGGER trg_author_drafts_retake_untouched
  BEFORE INSERT OR UPDATE ON public.author_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_drafts_retake_untouched();
DROP TRIGGER IF EXISTS trg_exemplar_drafts_retake_untouched ON public.exemplar_drafts;
CREATE TRIGGER trg_exemplar_drafts_retake_untouched
  BEFORE INSERT OR UPDATE ON public.exemplar_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_drafts_retake_untouched();

-- Les enfants d'une notice écrits en direct (SubjectAuthorityPicker,
-- DigitalResourcesPanel ; contributeurs par sûreté). TG_ARGV[0] = la colonne
-- qui pointe la notice. SECURITY DEFINER : écrire un sujet ne suppose pas le
-- droit d'écrire book_drafts.
CREATE OR REPLACE FUNCTION public.tg_book_draft_child_touches_retake()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $$
DECLARE
  v_draft_id bigint;
BEGIN
  -- L'oubli d'une reprise emporte ses enfants en CASCADE : rien à marquer.
  IF coalesce(current_setting('anarbib.retake_oubli', true), '') = 'on' THEN
    RETURN NULL;
  END IF;
  v_draft_id := (CASE WHEN tg_op = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END ->> tg_argv[0])::bigint;
  IF v_draft_id IS NOT NULL THEN
    UPDATE public.book_drafts
       SET retake_untouched = false
     WHERE id = v_draft_id AND retake_untouched AND created_at <> now();
  END IF;
  RETURN NULL;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.tg_book_draft_child_touches_retake() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_book_draft_subjects_touch_retake ON public.book_draft_subjects;
CREATE TRIGGER trg_book_draft_subjects_touch_retake
  AFTER INSERT OR UPDATE OR DELETE ON public.book_draft_subjects
  FOR EACH ROW EXECUTE FUNCTION public.tg_book_draft_child_touches_retake('book_draft_id');
DROP TRIGGER IF EXISTS trg_book_draft_digital_resources_touch_retake ON public.book_draft_digital_resources;
CREATE TRIGGER trg_book_draft_digital_resources_touch_retake
  AFTER INSERT OR UPDATE OR DELETE ON public.book_draft_digital_resources
  FOR EACH ROW EXECUTE FUNCTION public.tg_book_draft_child_touches_retake('book_draft_id');
DROP TRIGGER IF EXISTS trg_book_draft_contributors_touch_retake ON public.book_draft_contributors;
CREATE TRIGGER trg_book_draft_contributors_touch_retake
  AFTER INSERT OR UPDATE OR DELETE ON public.book_draft_contributors
  FOR EACH ROW EXECUTE FUNCTION public.tg_book_draft_child_touches_retake('draft_id');

-- -------------------------------------------------------------------------
-- (3) Le journal des suppressions ne garde pas les reprises vierges
-- -------------------------------------------------------------------------
-- Réécriture depuis la définition RÉELLE (pg_get_functiondef, 03/10/2026) :
-- seul ajout, la garde anarbib.retake_oubli en tête.
CREATE OR REPLACE FUNCTION public.fn_audit_draft_deletion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog', 'pg_temp'
AS $function$
declare
  v_entity  text;
  v_label   text;
  v_library uuid;
  v_details jsonb;
begin
  -- 20261003202521 : une reprise jamais enregistrée s'oublie sans trace — il n'y
  -- a rien à rejouer. La garde n'est posée que par discard_untouched_retake et
  -- private.fn_purge_untouched_retakes, transaction-local.
  if coalesce(current_setting('anarbib.retake_oubli', true), '') = 'on' then
    return old;
  end if;

  v_details := jsonb_build_object('snapshot', to_jsonb(old));

  if tg_table_name = 'book_drafts' then
    v_entity  := 'book';
    v_label   := old.titulo;
    -- B29 : la bibliothèque RÉSOLUE (celle du créateur quand owner est nul),
    -- que lit la politique du journal.
    v_library := coalesce(old.owner_library_id, private.fn_book_draft_creator_library(old.id, old.created_by));
    -- Les enfants en CASCADE : sans eux, le rejeu rendrait une coquille.
    v_details := v_details || jsonb_build_object('children', jsonb_build_object(
      'book_draft_contributors', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.book_draft_contributors c where c.draft_id = old.id), '[]'::jsonb),
      'book_draft_subjects', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.book_draft_subjects c where c.book_draft_id = old.id), '[]'::jsonb),
      'book_draft_catalog_context', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.book_draft_catalog_context c where c.book_draft_id = old.id), '[]'::jsonb),
      'book_draft_digital_resources', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.book_draft_digital_resources c where c.book_draft_id = old.id), '[]'::jsonb),
      -- H19 : ses exemplaires importés (CASCADE sur book_draft_id) ; rejoués
      -- avec elle, sinon la notice revenait sans eux et publiait l'exemplaire
      -- automatique, codes et cotes perdus.
      'exemplar_drafts', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.exemplar_drafts c where c.book_draft_id = old.id), '[]'::jsonb)
    ));
  elsif tg_table_name = 'author_drafts' then
    v_entity := 'author';
    v_label  := old.preferred_name;
  else
    -- H19 (27/09) : supprimé par CASCADE avec sa notice, il est déjà dans
    -- l'instantané de celle-ci (children.exemplar_drafts) : pas d'entrée à part.
    if old.book_draft_id is not null
       and not exists (select 1 from public.book_drafts b where b.id = old.book_draft_id) then
      return old;
    end if;
    v_entity  := 'exemplar';
    v_label   := coalesce(old.tombo, old.target_bib_ref);
    v_library := coalesce(old.target_library_id,
                          private.fn_exemplar_draft_fallback_library(old.book_draft_id, old.import_staging_row_id, old.created_by));
  end if;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, library_id, label, details)
  values (auth.uid(), 'delete', v_entity, old.id, v_library, v_label,
          v_details || jsonb_build_object('batch_id', old.batch_id, 'source_table', tg_table_name));

  return old;
end;
$function$;

-- -------------------------------------------------------------------------
-- (4) L'oubli à l'abandon, depuis l'éditeur
-- -------------------------------------------------------------------------
-- Rend true si la reprise a été oubliée, false sinon (déjà enregistrée,
-- d'autrui, exemplaire attaché, introuvable) — jamais d'erreur : l'appel part
-- en « fire-and-forget » quand on quitte l'éditeur.
CREATE OR REPLACE FUNCTION public.discard_untouched_retake(p_type text, p_id bigint)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $$
DECLARE
  v_uid   uuid := auth.uid();
  v_admin boolean;
  v_n     integer := 0;
BEGIN
  IF v_uid IS NULL OR p_id IS NULL THEN
    RETURN false;
  END IF;
  v_admin := public.fn_caller_is_network_admin();
  PERFORM set_config('anarbib.retake_oubli', 'on', true);   -- transaction-local

  IF p_type = 'book' THEN
    DELETE FROM public.book_drafts d
     WHERE d.id = p_id AND d.retake_untouched AND d.status = 'draft'
       AND (d.created_by = v_uid OR v_admin)
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x WHERE x.book_draft_id = d.id);
  ELSIF p_type = 'author' THEN
    DELETE FROM public.author_drafts d
     WHERE d.id = p_id AND d.retake_untouched AND d.status = 'draft'
       AND (d.created_by = v_uid OR v_admin);
  ELSIF p_type = 'exemplar' THEN
    DELETE FROM public.exemplar_drafts d
     WHERE d.id = p_id AND d.retake_untouched AND d.status = 'draft'
       AND (d.created_by = v_uid OR v_admin);
  END IF;
  GET DIAGNOSTICS v_n = ROW_COUNT;

  PERFORM set_config('anarbib.retake_oubli', '', true);
  RETURN v_n > 0;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.discard_untouched_retake(text, bigint) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.discard_untouched_retake(text, bigint) TO authenticated;

-- -------------------------------------------------------------------------
-- (5) Le filet : reprises vierges abandonnées depuis plus de 24 h
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.fn_purge_untouched_retakes(p_age interval DEFAULT interval '24 hours')
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $$
DECLARE
  v_total integer := 0;
  v_n     integer;
BEGIN
  PERFORM set_config('anarbib.retake_oubli', 'on', true);

  DELETE FROM public.book_drafts d
   WHERE d.retake_untouched AND d.status = 'draft'
     AND greatest(d.created_at, coalesce(d.last_opened_at, d.created_at)) < now() - p_age
     AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x WHERE x.book_draft_id = d.id);
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;

  DELETE FROM public.author_drafts d
   WHERE d.retake_untouched AND d.status = 'draft'
     AND greatest(d.created_at, coalesce(d.last_opened_at, d.created_at)) < now() - p_age;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;

  DELETE FROM public.exemplar_drafts d
   WHERE d.retake_untouched AND d.status = 'draft'
     AND greatest(d.created_at, coalesce(d.last_opened_at, d.created_at)) < now() - p_age;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;

  PERFORM set_config('anarbib.retake_oubli', '', true);
  RETURN v_total;
END;
$$;

REVOKE EXECUTE ON FUNCTION private.fn_purge_untouched_retakes(interval) FROM PUBLIC, anon, authenticated;

DO $cron$
DECLARE v_jobid bigint;
BEGIN
  v_jobid := cron.schedule(
    'anarbib-purge-untouched-retakes',
    '23 * * * *',
    'SELECT private.fn_purge_untouched_retakes();'
  );
  RAISE NOTICE 'Job cron anarbib-purge-untouched-retakes créé/MAJ (ACTIF), jobid=%.', v_jobid;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Job cron NON créé (cron indisponible ici ?) : %. À créer/vérifier en prod.', SQLERRM;
END;
$cron$;

-- La liste des crons attendus (I26) apprend le nouveau job. Même procédé que
-- 20261001194818 (F1) : empreinte relevée en production le 03/10 (identique sur
-- la base reconstruite), ancre comptée, une ligne insérée.
DO $mig$
DECLARE
  v_def text;
  v_n   int;
  v_ancre text := $a$    ('anarbib-recompute-holdings-availability', '43 4 * * *', $a$;
  v_ligne text := $b$    ('anarbib-purge-untouched-retakes', '23 * * * *', $c$SELECT private.fn_purge_untouched_retakes();$c$, true),
$b$;
BEGIN
  IF (SELECT md5(replace(prosrc, E'\r', '')) FROM pg_proc
       WHERE oid = 'private.fn_crons_attendus()'::regprocedure)
     <> '5ff724a160bdf0a6548845be10e9d2e1' THEN
    RAISE EXCEPTION 'Reprises vierges : private.fn_crons_attendus a changé depuis le relevé du 03/10 — relire avant de réécrire';
  END IF;
  v_def := replace(pg_get_functiondef('private.fn_crons_attendus()'::regprocedure), E'\r', '');
  v_n := (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre);
  IF v_n <> 1 THEN RAISE EXCEPTION 'Reprises vierges : ancre de fn_crons_attendus trouvée % fois (1 attendue)', v_n; END IF;
  v_def := replace(v_def, v_ancre, v_ligne || v_ancre);
  EXECUTE v_def;
END
$mig$;

-- -------------------------------------------------------------------------
-- Garde
-- -------------------------------------------------------------------------
DO $garde$
BEGIN
  IF has_function_privilege('anon', 'public.discard_untouched_retake(text, bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'discard_untouched_retake ouverte à anon';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.discard_untouched_retake(text, bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'discard_untouched_retake fermée à authenticated';
  END IF;
  IF has_function_privilege('authenticated', 'private.fn_purge_untouched_retakes(interval)', 'EXECUTE')
     OR has_function_privilege('anon', 'private.fn_purge_untouched_retakes(interval)', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_purge_untouched_retakes ouverte au front';
  END IF;
  IF (SELECT count(*) FROM private.fn_crons_attendus()) <> 43 THEN
    RAISE EXCEPTION 'Reprises vierges : fn_crons_attendus doit porter 43 jobs';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM cron.job j JOIN private.fn_crons_attendus() a ON a.jobname = j.jobname::text
                  WHERE j.jobname = 'anarbib-purge-untouched-retakes' AND j.command = a.command AND j.schedule = a.schedule) THEN
    RAISE EXCEPTION 'Reprises vierges : le cron anarbib-purge-untouched-retakes ne correspond pas à fn_crons_attendus';
  END IF;
END;
$garde$;

COMMIT;
