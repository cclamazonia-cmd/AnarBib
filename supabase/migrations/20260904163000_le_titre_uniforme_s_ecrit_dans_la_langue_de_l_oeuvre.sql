-- =====================================================================
-- AnarBib -- Le titre uniforme s'ecrit dans la langue de l'oeuvre elle-meme
-- Date    : 2026-09-04  ·  Chantier OPAC par oeuvre  ·  decision 5 (Xavier, fin de journee)
-- Depend  : 20260904130100 (work_titles : l'affichage par locale rend cette regle tenable)
--
-- LA REGLE. Le titre uniforme d'une oeuvre est son titre dans sa langue
-- d'origine (convention bibliotheconomique), pas l'une de ses traductions.
-- Il ne s'affiche a l'OPAC qu'aux locales sans edition ni titre par langue ;
-- pour les autres, work_titles parle. Un recueil compose par un editeur n'a
-- pas d'autre langue que celle de ses editions : sa langue d'origine est la
-- leur (1867 reste « Desobediencia Civil e Outros Escritos »).
--
-- CE QUE CE PAQUET POSE : la RPC set_work_uniform_title (staff, recalcule
-- sort_title comme fn_books_ensure_work) -- l'app n'avait aucun champ pour
-- ce titre -- et l'application de la regle a l'oeuvre 97 de Thoreau, dont le
-- titre uniforme etait celui de son edition espagnole. Idempotent.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.set_work_uniform_title(p_work_id bigint, p_title text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE v_title text := btrim(COALESCE(p_title, ''));
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid() AND m.role = ANY(ARRAY['librarian','coordenador']) AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;
  IF v_title = '' THEN
    RAISE EXCEPTION 'O título uniforme não pode ficar vazio.' USING ERRCODE = 'P0001', HINT = 'error.catalog.work.emptyTitle';
  END IF;
  UPDATE public.works
     SET uniform_title = v_title, sort_title = public.fn_normalize_name(v_title), updated_at = now()
   WHERE id = p_work_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Obra inexistente.' USING ERRCODE = 'P0002', HINT = 'error.catalog.work.notFound'; END IF;
END;
$$;
COMMENT ON FUNCTION public.set_work_uniform_title(bigint, text) IS
  'Renomme le titre uniforme d''une oeuvre (langue d''origine de l''oeuvre, decision 5 du 04/09/2026) et recalcule sort_title. Staff seulement.';
REVOKE EXECUTE ON FUNCTION public.set_work_uniform_title(bigint, text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.set_work_uniform_title(bigint, text) TO authenticated;

-- Thoreau, texte seul : la regle appliquee (garde par l'etat constate, silencieux ailleurs).
UPDATE public.works
   SET uniform_title = 'Civil Disobedience', sort_title = public.fn_normalize_name('Civil Disobedience'), updated_at = now()
 WHERE id = 97 AND uniform_title = 'Desobediencia Civil';

DO $$
BEGIN
  IF has_function_privilege('anon', 'public.set_work_uniform_title(bigint,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Garde-fou : set_work_uniform_title reste executable par anon';
  END IF;
END $$;

COMMIT;
