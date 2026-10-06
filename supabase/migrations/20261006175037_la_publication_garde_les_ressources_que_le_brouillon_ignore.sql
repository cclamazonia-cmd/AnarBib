-- =====================================================================
-- D9 — La publication ne retire une ressource numérique que si le brouillon
-- dit de la retirer.
--
-- Relevé en livrant C24 (05/10, d1d72405) : publish_book_draft_digital_resources
-- supprimait du publié TOUT ce que le brouillon ne portait pas. Une ressource
-- posée sur la notice par la réception d'un fonds, après la création du
-- brouillon, disparaissait à sa publication suivante, sans un mot. Même effet,
-- plus large, pour un brouillon créé sans reprise des ressources (mise à jour
-- par import) : sa publication vidait la notice de ses ressources.
--
-- Décision de Xavier (06/10) : « garder ce qu'elle ignore ». La publication
-- retire une ressource publiée seulement
--   - si le brouillon la porte retirée ou inactive (ligne liée par
--     published_resource_id) — comportement inchangé ;
--   - ou si le brouillon l'a supprimée : la suppression d'une ligne liée
--     laisse désormais une trace dans book_drafts.digital_resources_removed.
-- Toute ressource publiée que le brouillon ne connaît pas reste publiée.
-- La reprise (copy_book_digital_resources_to_draft) repart de ce que la notice
-- porte et vide cette trace.
--
-- Réécritures depuis les définitions réelles (pg_get_functiondef), ancres
-- comptées, rien de retapé.
-- Suite : tests/sql/depot_numerique_droits_tests.sql, T8.
--
-- CHECKLIST DOCTRINE
--   [x] Fonction trigger SECURITY DEFINER (comme tg_book_draft_child_touches_retake :
--       elle écrit le brouillon parent), SET search_path, REVOKE FROM PUBLIC,
--       anon, authenticated, service_role (aucun GRANT)
--   [x] Pas de table neuve (bg2-known-tables inchangé), droits par table inchangés
--   [x] DO block de garde final
-- =====================================================================

-- (1) La trace des suppressions
ALTER TABLE public.book_drafts
  ADD COLUMN IF NOT EXISTS digital_resources_removed bigint[] NOT NULL DEFAULT '{}';
COMMENT ON COLUMN public.book_drafts.digital_resources_removed IS
  'D9 (06/10/2026) : ressources publiées (book_digital_resources.id) que ce brouillon a supprimées. La publication ne retire du publié que celles-ci et celles que le brouillon porte retirées ou inactives ; une ressource publiée que le brouillon ignore (posée par la réception d''un fonds, ou d''un brouillon créé sans reprise) reste publiée. Vidée par copy_book_digital_resources_to_draft.';

CREATE OR REPLACE FUNCTION public.tg_book_draft_digital_resource_removed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- Une ligne liée à une ressource publiée est supprimée : c'est un geste qui
  -- dit « retirer ». On le garde pour la publication (D9).
  update public.book_drafts
     set digital_resources_removed = array_append(digital_resources_removed, OLD.published_resource_id)
   where id = OLD.book_draft_id
     and not (OLD.published_resource_id = any (digital_resources_removed));
  return null;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.tg_book_draft_digital_resource_removed() FROM PUBLIC, anon, authenticated, service_role;

COMMENT ON FUNCTION public.tg_book_draft_digital_resource_removed() IS
  'D9 (06/10/2026) : garde dans book_drafts.digital_resources_removed la ressource publiée dont la ligne de brouillon est supprimée.';

DROP TRIGGER IF EXISTS trg_book_draft_digital_resource_removed ON public.book_draft_digital_resources;
CREATE TRIGGER trg_book_draft_digital_resource_removed
  AFTER DELETE ON public.book_draft_digital_resources
  FOR EACH ROW
  WHEN (OLD.published_resource_id IS NOT NULL)
  EXECUTE FUNCTION public.tg_book_draft_digital_resource_removed();

-- (2) et (3) Réécritures depuis les définitions réelles
DO $migration$
DECLARE
  v_def text;
  v_n int;
  -- copy_book_digital_resources_to_draft : la reprise vide la trace
  c1 constant text := E'  delete from public.book_draft_digital_resources\n  where book_draft_id = p_book_draft_id;\n';
  c1r constant text := E'  delete from public.book_draft_digital_resources\n  where book_draft_id = p_book_draft_id;\n\n'
    || E'  -- D9 : la reprise repart de ce que la notice porte, rien n''y est « retiré »\n'
    || E'  update public.book_drafts\n'
    || E'     set digital_resources_removed = ''{}''\n'
    || E'   where id = p_book_draft_id\n'
    || E'     and digital_resources_removed <> ''{}'';\n';
  -- publish_book_draft_digital_resources : ne retirer que ce que le brouillon dit
  p1 constant text := E'  -- Ce que le brouillon n''a plus quitte le publié.\n'
    || E'  delete from public.book_digital_resources\n'
    || E'   where book_id = p_book_id\n'
    || E'     and not (id = any (v_garder));\n';
  p1r constant text := E'  -- D9 (06/10/2026, décision de Xavier) : ne quitte le publié que ce que le\n'
    || E'  -- brouillon dit de retirer — une ressource qu''il a supprimée\n'
    || E'  -- (book_drafts.digital_resources_removed) ou qu''il porte retirée ou\n'
    || E'  -- inactive. Une ressource publiée qu''il ignore (posée par la réception\n'
    || E'  -- d''un fonds après sa création, ou brouillon créé sans reprise) reste.\n'
    || E'  delete from public.book_digital_resources r\n'
    || E'   where r.book_id = p_book_id\n'
    || E'     and not (r.id = any (v_garder))\n'
    || E'     and (r.id = any (coalesce((select bd.digital_resources_removed\n'
    || E'                                  from public.book_drafts bd\n'
    || E'                                 where bd.id = p_book_draft_id), ''{}''))\n'
    || E'          or exists (select 1 from public.book_draft_digital_resources dd\n'
    || E'                      where dd.book_draft_id = p_book_draft_id\n'
    || E'                        and dd.published_resource_id = r.id));\n';
BEGIN
  v_def := replace(pg_get_functiondef('public.copy_book_digital_resources_to_draft(bigint,bigint)'::regprocedure), E'\r', '');
  v_n := (length(v_def) - length(replace(v_def, c1, ''))) / length(c1);
  IF v_n <> 1 OR position('digital_resources_removed' in v_def) > 0 THEN
    RAISE EXCEPTION 'D9 : copy_book_digital_resources_to_draft n''est pas celle attendue (% ancre(s))', v_n;
  END IF;
  EXECUTE replace(v_def, c1, c1r);

  v_def := replace(pg_get_functiondef('public.publish_book_draft_digital_resources(bigint,bigint)'::regprocedure), E'\r', '');
  v_n := (length(v_def) - length(replace(v_def, p1, ''))) / length(p1);
  IF v_n <> 1 OR position('digital_resources_removed' in v_def) > 0 THEN
    RAISE EXCEPTION 'D9 : publish_book_draft_digital_resources n''est pas celle attendue (% ancre(s))', v_n;
  END IF;
  EXECUTE replace(v_def, p1, p1r);
END
$migration$;

-- Garde finale
DO $garde$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'public.publish_book_draft_digital_resources(bigint,bigint)'::regprocedure
                   AND prosrc ~ 'digital_resources_removed' AND prosrc ~ 'dd\.published_resource_id = r\.id')
     OR NOT EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'public.copy_book_digital_resources_to_draft(bigint,bigint)'::regprocedure
                   AND prosrc ~ 'digital_resources_removed')
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_book_draft_digital_resource_removed'
                   AND tgrelid = 'public.book_draft_digital_resources'::regclass)
     OR has_function_privilege('authenticated', 'public.tg_book_draft_digital_resource_removed()', 'EXECUTE')
     OR has_function_privilege('anon', 'public.tg_book_draft_digital_resource_removed()', 'EXECUTE') THEN
    RAISE EXCEPTION 'D9 : réécriture incomplète, déclencheur absent ou droits ouverts';
  END IF;
END
$garde$;
