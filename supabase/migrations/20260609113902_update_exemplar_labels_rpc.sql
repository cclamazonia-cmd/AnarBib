-- ════════════════════════════════════════════════════════════════════════════
-- RPC : edition inline des etiquettes d'exemplaires publies
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-09 (UTC)
--
-- OBJET : Permet au staff de modifier directement les 4 champs d'etiquette
-- (label_author_override, label_title_override, label_cdd_override, label_note)
-- sur un exemplaire DEJA PUBLIE, sans passer par un cycle brouillon complet.
-- Ceci rend l'edition en lot praticable dans l'onglet Etiquetas.
--
-- SECURITE : SECURITY DEFINER + search_path fige, garde staff via
-- user_has_library_staff_role. REVOKE PUBLIC, GRANT authenticated.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.update_exemplar_labels(
  p_exemplar_id  uuid,
  p_label_author text DEFAULT NULL,
  p_label_title  text DEFAULT NULL,
  p_label_cdd    text DEFAULT NULL,
  p_label_note   text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public', 'pg_catalog'
AS $function$
DECLARE
  v_library_id uuid;
BEGIN
  -- Recuperer la bibliotheque de l'exemplaire
  SELECT e.library_id INTO v_library_id
    FROM public.exemplares e
   WHERE e.id = p_exemplar_id;

  IF v_library_id IS NULL THEN
    RAISE EXCEPTION 'Exemplaire introuvable.'
      USING HINT = 'error.exemplar.not_found';
  END IF;

  -- Garde-fou staff
  IF NOT public.user_has_library_staff_role(auth.uid(), v_library_id) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff da biblioteca.'
      USING ERRCODE = '42501';
  END IF;

  -- Mise a jour SELECTIVE : seuls les parametres non-NULL sont ecrits.
  -- NULL = « ne pas toucher » ; '' = « effacer l'override → retour au
  -- libelle automatique » (la vue v_exemplar_labels fait NULLIF(override,'')
  -- → fallback sur la valeur de base du livre).
  UPDATE public.exemplares
     SET label_author_override = CASE WHEN p_label_author IS NOT NULL THEN p_label_author ELSE label_author_override END,
         label_title_override  = CASE WHEN p_label_title  IS NOT NULL THEN p_label_title  ELSE label_title_override  END,
         label_cdd_override    = CASE WHEN p_label_cdd    IS NOT NULL THEN p_label_cdd    ELSE label_cdd_override    END,
         label_note            = CASE WHEN p_label_note   IS NOT NULL THEN p_label_note   ELSE label_note            END,
         updated_at            = now()
   WHERE id = p_exemplar_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.update_exemplar_labels(uuid, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_exemplar_labels(uuid, text, text, text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
