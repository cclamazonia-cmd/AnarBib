-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — attacher un fichier reçu : pour l'administration du réseau aussi,
-- un livre inconnu est refusé AVANT la clé de service (14/10/2026).
--
-- LA FORME NOTÉE. Au verdict d'audit du 14/10
-- (AUDIT_execute_authenticated_2026-09-01.md, « la 437e ») : pour un·e admin
-- réseau, la règle (b) de public.fn_attach_received_asset_garde ne vérifiait
-- pas que le livre existe. La garde rendait true ; l'Edge Function
-- attach-received-asset téléversait la copie à la clé de service sous
-- attached/<book_id>/… ; fn_attach_received_asset_record échouait ensuite sur
-- la clé étrangère de digital_assets (un message brut, pas « introuvable ») ;
-- la copie était effacée. Un aller-retour inutile, réservé à l'administration.
--
-- LA CORRECTION, dans les deux fonctions, pour qu'elles restent d'accord cas
-- par cas (attach_recu_garde_tests T4) :
--   * la garde refuse un livre inconnu pour tout le monde, administration
--     comprise, avant la règle (b) — même refus que les autres (« Recurso
--     recebido introuvável. », HINT error.edge.received_asset_not_found) ;
--   * la RPC d'écriture fait de même juste après sa garde de détention, au
--     lieu de buter sur la clé étrangère.
-- Pour la coordination, rien ne change : un livre inconnu n'est détenu par
-- personne, la règle (b) le refusait déjà.
--
-- Corps repris de la définition RÉELLE de production (pg_get_functiondef),
-- une insertion chacun, devant une ancre comptée (exactement une) : jamais un
-- corps recopié (DOC-MSG-1). CREATE OR REPLACE garde les droits ; on les
-- redit, et le bloc final les vérifie.
-- ═══════════════════════════════════════════════════════════════════════════

DO $correction$
DECLARE
  v_def    text;
  v_ancre  text;
  v_ajout  text;
  v_n      int;
BEGIN
  -- ── La garde : avant la règle (b) ─────────────────────────────────────
  v_def := pg_get_functiondef('public.fn_attach_received_asset_garde(bigint, bigint)'::regprocedure);
  v_ancre := '  -- (b) le livre : détenu par une bibliothèque coordonnée.';
  v_n := (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'garde : ancre trouvée % fois (1 attendue)', v_n;
  END IF;
  v_ajout :=
    '  -- (b0) 14/10/2026 : le livre existe — pour l''administration aussi, sinon' || E'\n' ||
    '  -- l''Edge Function téléverserait une copie pour un livre que personne n''a.' || E'\n' ||
    '  IF p_book_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.books b WHERE b.id = p_book_id) THEN' || E'\n' ||
    '    RAISE EXCEPTION ''Recurso recebido introuvável.'' USING HINT = ''error.edge.received_asset_not_found'';' || E'\n' ||
    '  END IF;' || E'\n\n';
  EXECUTE replace(v_def, v_ancre, v_ajout || v_ancre);

  -- ── La RPC d'écriture : juste après sa garde de détention ─────────────
  v_def := pg_get_functiondef('public.fn_attach_received_asset_record(bigint, bigint, text, text, text)'::regprocedure);
  v_ancre := '  IF NOT v_authorized THEN RAISE EXCEPTION ''Recurso recebido introuvável.''; END IF;';
  v_n := (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'écriture : ancre trouvée % fois (1 attendue)', v_n;
  END IF;
  v_ajout := E'\n' ||
    '  -- 14/10/2026 : un livre inconnu est refusé comme le reste, administration' || E'\n' ||
    '  -- comprise, au lieu de buter plus bas sur la clé étrangère.' || E'\n' ||
    '  IF NOT EXISTS (SELECT 1 FROM public.books b WHERE b.id = p_book_id) THEN' || E'\n' ||
    '    RAISE EXCEPTION ''Recurso recebido introuvável.'';' || E'\n' ||
    '  END IF;';
  EXECUTE replace(v_def, v_ancre, v_ancre || v_ajout);
END
$correction$;

REVOKE ALL ON FUNCTION public.fn_attach_received_asset_garde(bigint, bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_attach_received_asset_garde(bigint, bigint) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text, text) TO authenticated, service_role;

DO $garde$
DECLARE
  v_g text := pg_get_functiondef('public.fn_attach_received_asset_garde(bigint, bigint)'::regprocedure);
  v_r text := pg_get_functiondef('public.fn_attach_received_asset_record(bigint, bigint, text, text, text)'::regprocedure);
BEGIN
  IF v_g !~ '\(b0\) 14/10/2026' OR v_g !~ 'FROM public\.books b WHERE b\.id = p_book_id' THEN
    RAISE EXCEPTION 'garde : le contrôle du livre manque';
  END IF;
  IF v_r !~ '14/10/2026 : un livre inconnu' THEN
    RAISE EXCEPTION 'écriture : le contrôle du livre manque';
  END IF;
  -- La garde reste ce qu'elle était : DEFINER, STABLE, search_path vide.
  IF NOT EXISTS (SELECT 1 FROM pg_proc p
                  WHERE p.oid = 'public.fn_attach_received_asset_garde(bigint, bigint)'::regprocedure
                    AND p.prosecdef AND p.provolatile = 's'
                    AND array_to_string(p.proconfig, ',') = 'search_path=""') THEN
    RAISE EXCEPTION 'garde : propriétés perdues (DEFINER, STABLE, search_path)';
  END IF;
  IF has_function_privilege('anon', 'public.fn_attach_received_asset_garde(bigint, bigint)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_attach_received_asset_record(bigint, bigint, text, text, text)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.fn_attach_received_asset_garde(bigint, bigint)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.fn_attach_received_asset_record(bigint, bigint, text, text, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'attache d''un fichier reçu : droits inattendus';
  END IF;
END
$garde$;
