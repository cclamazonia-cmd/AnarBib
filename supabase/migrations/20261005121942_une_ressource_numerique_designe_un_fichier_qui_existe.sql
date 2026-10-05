-- =========================================================================
-- Une ressource numérique désigne un fichier qui existe, à l'endroit
-- qu'elle déclare.
-- =========================================================================
-- Date     : 2026-10-05
-- Chantier : numérique — dépôt (complète C24, 20261005092916)
-- Auteur   : Claude (Opus 5.5), pour Xavier
-- Session  : Doublons SNI & forme autorisée des contributeurs
--
-- Constat de Xavier, 05/10/2026 (/livro/2287, « História da anarquia ») : le
-- PDF restreint ne s'affichait pas comme lisible pour un membre d'une
-- bibliothèque détentrice. Le fichier avait été versé dans le seau PUBLIC
-- (anarbib-pdf-public) quand la ressource était « PDF public », puis la
-- ressource repassée en « PDF restreint » : le champ seau était devenu
-- pdf-restrito, le fichier n'avait pas suivi. La ressource publiée désignait
-- donc un objet absent (fn_book_restricted_pdf_state : file_exists = faux,
-- pas de bouton « Lire ») — et une œuvre SOUS DROITS restait téléchargeable
-- dans un seau public. Réparé à la main le 05/10 (objet déplacé par la CLI,
-- copie publique supprimée).
--
-- Le trigger de cohérence de C24 vérifie le seau DÉCLARÉ contre l'accès
-- (« un document réservé se range dans un espace réservé »), jamais l'endroit
-- où le fichier se trouve : il n'aurait pas vu ce cas. L'écran de C24 ne laisse
-- plus saisir le seau et déplace le fichier à l'enregistrement ; la base, elle,
-- doit refuser une ressource qui désigne un fichier absent, quel que soit le
-- chemin d'écriture.
--
-- Règle ajoutée (écritures depuis l'écran seulement, comme les autres règles
-- du trigger) : si storage_bucket et storage_path sont posés, l'objet doit
-- exister dans storage.objects à ce (seau, chemin). Contrôlée EN DERNIER : les
-- refus plus parlants (espace, droits, justification) passent d'abord. Une
-- mise à jour qui change le chemin est rejugée (storage_path rejoint la liste
-- des colonnes qui déclenchent le contrôle).
--
-- private.fn_objet_stocke_existe : SECURITY DEFINER, parce que le trigger
-- tourne sous « authenticated » et que la RLS de storage.objects n'ouvre pas
-- tous les seaux au catalogage. Ne dit qu'oui ou non sur un (seau, chemin)
-- donné ; ouverte à authenticated seulement.
--
-- Fonction de trigger reprise de sa définition en production
-- (pg_get_functiondef, 05/10) ; seuls l'en-tête de comparaison et la règle
-- finale changent.
-- =========================================================================

CREATE OR REPLACE FUNCTION private.fn_objet_stocke_existe(p_bucket text, p_path text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog'
AS $function$
  select exists (select 1 from storage.objects so where so.bucket_id = p_bucket and so.name = p_path)
$function$;

COMMENT ON FUNCTION private.fn_objet_stocke_existe(text, text) IS
  'Vrai si un objet existe dans storage.objects à ce (seau, chemin). Appelée par tg_draft_digital_resource_coherence (05/10/2026).';

REVOKE EXECUTE ON FUNCTION private.fn_objet_stocke_existe(text, text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.fn_objet_stocke_existe(text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.tg_draft_digital_resource_coherence()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_catalog', 'pg_temp'
AS $function$
DECLARE
  v_public_buckets     constant text[] := ARRAY['anarbib-pdf-public', 'anarbib-media-public', 'anarbib-epub-public'];
  v_restricted_buckets constant text[] := ARRAY['pdf-restrito', 'anarbib-media-restricted', 'anarbib-epub-restricted'];
  v_permis boolean;
BEGIN
  -- Les copies système (reprise, réception d'un fonds) ne sont pas rejugées.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  -- Une ressource ancienne s'édite sans être bloquée par ce qu'elle était.
  IF TG_OP = 'UPDATE'
     AND NEW.rights_status IS NOT DISTINCT FROM OLD.rights_status
     AND NEW.access_scope IS NOT DISTINCT FROM OLD.access_scope
     AND NEW.storage_bucket IS NOT DISTINCT FROM OLD.storage_bucket
     AND NEW.storage_path IS NOT DISTINCT FROM OLD.storage_path
     AND NEW.rights_justification IS NOT DISTINCT FROM OLD.rights_justification THEN
    RETURN NEW;
  END IF;

  IF NEW.storage_bucket IS NOT NULL THEN
    IF NEW.access_scope = 'publico' AND NOT NEW.storage_bucket = ANY (v_public_buckets) THEN
      RAISE EXCEPTION 'Un document public se range dans un espace public.' USING hint = 'error.digital.bucket_scope';
    END IF;
    IF NEW.access_scope = 'conta_ativa' AND NOT NEW.storage_bucket = ANY (v_restricted_buckets) THEN
      RAISE EXCEPTION 'Un document réservé se range dans un espace réservé.' USING hint = 'error.digital.bucket_scope';
    END IF;
  END IF;

  IF NEW.rights_status IN ('cessao_autoral', 'licenca_livre', 'sob_direitos')
     AND (NEW.rights_status <> 'sob_direitos' OR NEW.access_scope = 'publico')
     AND btrim(coalesce(NEW.rights_justification, '')) = '' THEN
    RAISE EXCEPTION 'Justification des droits manquante.' USING hint = 'error.digital.justification_required';
  END IF;

  IF NEW.rights_status = 'sob_direitos' AND NEW.access_scope = 'publico' THEN
    SELECT coalesce(l.digital_public_under_rights, false) INTO v_permis
      FROM public.book_drafts d
      LEFT JOIN public.libraries l ON l.id = d.owner_library_id
     WHERE d.id = NEW.book_draft_id;
    IF NOT coalesce(v_permis, false) THEN
      RAISE EXCEPTION 'La bibliothèque n''a pas ouvert la lecture publique d''œuvres sous droits.'
        USING hint = 'error.digital.public_under_rights_not_allowed';
    END IF;
  END IF;

  -- 05/10 : le fichier déclaré existe à l'endroit déclaré (cf. en-tête).
  IF NEW.storage_bucket IS NOT NULL AND NEW.storage_path IS NOT NULL
     AND NOT private.fn_objet_stocke_existe(NEW.storage_bucket, NEW.storage_path) THEN
    RAISE EXCEPTION 'Le fichier n''est pas à l''endroit que la ressource déclare (%/%).', NEW.storage_bucket, NEW.storage_path
      USING hint = 'error.digital.file_not_in_bucket';
  END IF;
  RETURN NEW;
END;
$function$;
