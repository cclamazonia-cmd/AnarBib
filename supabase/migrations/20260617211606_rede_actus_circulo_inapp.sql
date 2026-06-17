-- =========================================================================
-- Actus réseau — Phase 3 : un nouveau cercle crée un avis in-app CIBLÉ
-- (par affinité de sujets) au compte lecteur·rice
-- =========================================================================
-- Date     : 2026-06-17
-- Chantier : Feeding « avis & notifications » — surfacer les diffusions réseau
-- Auteur   : Claude (assistant·e)
-- Session  : Avis & notifications — feeding réseau (Phase 3 Cercles)
-- Branche  : rede-actus-notifs-inapp (hors worktree partagé)
--
-- Suite des Phases 1-2 (Lettre, Gazette). Décision produit (Xavier) : pour les
-- cercles, ciblage PAR AFFINITÉ — on n'inonde pas tout le monde. Un cercle
-- « afinitario » n'ayant qu'un nom/description libres, on lui attache des SUJETS
-- du thésaurus à la création ; on notifie seulement les lecteur·rices dont les
-- livres engagés (souhaits + réservations + emprunts) portent ces sujets.
--
-- Contenu :
--   1) Table de liaison public.circle_subjects (cercle <-> sujets du thésaurus).
--   2) api.fn_circle_create : nouvel argument p_subject_ids (DROP+CREATE, défaut
--      pour rétro-compat de l'appel front à 5 args). Stocke les tags ; si le
--      cercle est ouvert ET tagué, fan-out d'un avis in-app (category
--      'rede_circulo', lien -> /federacao/circulos) aux lecteur·rices actif·ves
--      non opt-out (toggle « actus réseau » partagé) dont les livres engagés
--      recoupent ces sujets — sauf le·la créateur·rice.
--
-- Le front (picker de sujets dans le formulaire de création) + les clés i18n
-- notif.rede.circulo.* arrivent dans le même lot de branche.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1) Liaison cercle <-> sujets
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.circle_subjects (
  circle_id  uuid   NOT NULL REFERENCES public.circles(id)  ON DELETE CASCADE,
  subject_id bigint NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (circle_id, subject_id)
);
CREATE INDEX IF NOT EXISTS circle_subjects_subject_idx ON public.circle_subjects (subject_id);

ALTER TABLE public.circle_subjects ENABLE ROW LEVEL SECURITY;
-- Lecture : les sujets d'un cercle s'affichent avec le cercle (donnée non sensible,
-- équivalente aux sujets d'un livre). Écriture : aucune en direct -> seulement via
-- fn_circle_create (SECURITY DEFINER, owner).
DROP POLICY IF EXISTS circle_subjects_read ON public.circle_subjects;
CREATE POLICY circle_subjects_read ON public.circle_subjects FOR SELECT USING (true);
GRANT SELECT ON public.circle_subjects TO authenticated;

-- -------------------------------------------------------------------------
-- 2) fn_circle_create : tags de sujets + fan-out avis in-app par affinité
-- -------------------------------------------------------------------------
-- Signature étendue (p_subject_ids) -> DROP + CREATE (défaut pour l'appel à 5 args).
DROP FUNCTION IF EXISTS api.fn_circle_create(text, text, text, uuid, boolean);
CREATE OR REPLACE FUNCTION api.fn_circle_create(
  p_nature text,
  p_name text,
  p_description text,
  p_library_id uuid,
  p_is_open boolean DEFAULT true,
  p_subject_ids bigint[] DEFAULT '{}'::bigint[]
)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_circle_id uuid;
  v_caller uuid := auth.uid();
BEGIN
  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'forbidden: only the coordenador of the library can create a circle' USING ERRCODE = '42501';
  END IF;
  IF p_nature NOT IN ('afinitario','geografico','linguistico','federacao') THEN
    RAISE EXCEPTION 'invalid_nature' USING ERRCODE = '22023';
  END IF;
  IF length(trim(coalesce(p_name,''))) = 0 THEN
    RAISE EXCEPTION 'name_required' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.circles (nature, name, description, is_open, last_activity_at, created_by)
    VALUES (p_nature, trim(p_name), nullif(trim(coalesce(p_description,'')),''), coalesce(p_is_open,true), now(), v_caller)
    RETURNING id INTO v_circle_id;

  INSERT INTO public.circle_memberships (circle_id, library_id, status, requested_by, joined_at)
    VALUES (v_circle_id, p_library_id, 'membro', v_caller, now());

  -- Tags de sujets (déduplication via la PK).
  IF coalesce(array_length(p_subject_ids, 1), 0) > 0 THEN
    INSERT INTO public.circle_subjects (circle_id, subject_id)
      SELECT v_circle_id, s.id
      FROM public.subjects s
      WHERE s.id = ANY(p_subject_ids)
      ON CONFLICT DO NOTHING;
  END IF;

  -- Fan-out AVIS IN-APP par affinité : seulement si le cercle est OUVERT et tagué.
  -- Cible = lecteur·rices actif·ves non opt-out dont un livre engagé (souhaits +
  -- réservations + emprunts) porte un des sujets du cercle. Sauf le·la créateur·rice.
  IF coalesce(p_is_open, true) AND coalesce(array_length(p_subject_ids, 1), 0) > 0 THEN
    INSERT INTO public.user_notifications (
      user_id, library_id, category, title, body, link_type, link_id, is_read
    )
    SELECT DISTINCT eng.uid, NULL::uuid, 'rede_circulo',
           'notif.rede.circulo.title', 'notif.rede.circulo.body',
           'rede_circulo', v_circle_id::text, false
    FROM (
      SELECT w.user_id AS uid, w.book_id FROM public.user_wishlist w
      UNION
      SELECT r.user_id, l.book_id FROM public.reserva_linhas_v2 l
        JOIN public.reservas_v2 r ON r.id = l.reserva_id
      UNION
      SELECT e.user_id, i.book_id FROM public.emprestimo_itens_v2 i
        JOIN public.emprestimos_v2 e ON e.id = i.emprestimo_id
    ) eng
    JOIN public.book_subjects bs ON bs.book_id = eng.book_id
    WHERE bs.subject_id = ANY(p_subject_ids)
      AND eng.uid IS NOT NULL
      AND eng.uid <> v_caller
      AND EXISTS (SELECT 1 FROM public.user_library_memberships m
                  WHERE m.user_id = eng.uid AND m.status = 'active')
      AND NOT EXISTS (SELECT 1 FROM public.user_notification_preferences np
                      WHERE np.user_id = eng.uid AND np.disable_rede_news);
  END IF;

  RETURN v_circle_id;
END;
$function$;
REVOKE EXECUTE ON FUNCTION api.fn_circle_create(text, text, text, uuid, boolean, bigint[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_circle_create(text, text, text, uuid, boolean, bigint[]) TO authenticated;

COMMIT;
