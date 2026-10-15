-- =========================================================================
-- Paquet NUMDIF-D19 — un PDF restreint dont le livre n'a plus de
-- bibliothèque détentrice devient observable
-- =========================================================================
-- Date     : 2026-10-15
-- Chantier : documents numériques — garde-fou « restreint sans détenteur »
-- Auteur   : Claude (assistant·e), pour la coordination
-- Session  : File de candidats PDF
-- Ref      : backlog v34 D19 ; DECISION_profil_numerisation_2026-08-20.md
--            (« Poser le garde-fou restreint sans détenteur ») ; REGISTRE
--            DOC-SILENCE-1 ; CADRAGE_pdf-sous-droits-diffuses_2026-10-15 §7
--
-- POURQUOI
--   La lisibilité d'une ressource restreinte (access_scope <> 'publico')
--   dépend de book_holdings : fn_current_user_is_member_of_holding_library.
--   Quand la dernière ligne book_holdings d'un livre disparaît, son PDF
--   restreint devient illisible pour tout le monde (sauf l'administration du
--   réseau), sans erreur ni alerte : la ressource reste « active ». La file
--   de candidats (D13 à D16) en multipliera les cas. Décision du 20/08 : le
--   rendre OBSERVABLE plutôt que l'interdire — une bibliothèque peut retirer
--   un exemplaire abîmé sans vouloir fermer l'accès numérique.
--
-- OÙ L'OBSERVER. Retirer le dernier exemplaire ne supprime pas la détention
--   (le fonds reste, à zéro exemplaire) ; la ligne disparaît au ménage des
--   fonds vides (fn_fonds_vides_menage), à la fusion de notices, au transfert
--   entre bibliothèques, à la mise au rebut. Le seul point commun à tous ces
--   chemins est la suppression d'une ligne book_holdings : c'est là qu'on
--   regarde, par un déclencheur, quel que soit le chemin.
--
-- CE QUE FAIT LE PAQUET
--   1. public.tg_book_holdings_restreint_sans_detentrice() — AFTER DELETE sur
--      book_holdings : si le livre n'a plus aucune détentrice et porte au moins
--      une ressource restreinte active, une notification (cloche) va à la
--      coordination de la bibliothèque qui vient de perdre la détention et à
--      l'administration du réseau (DOC-SILENCE-1). Clés i18n
--      notif.restrictedOrphan.*, lien « restricted_without_holder » vers la
--      fiche. DEFINER : la personne qui supprime n'a pas à pouvoir écrire dans
--      user_notifications.
--   2. public.fn_restricted_resources_without_holder() — le CONTRÔLE : les
--      ressources restreintes actives dont le livre n'a aucune détentrice,
--      avec, pour chacune, ses fonds à zéro exemplaire éventuels. Réservé à
--      l'administration du réseau ; vide, sans erreur, pour tout autre compte.
--
-- CE QUE LE PAQUET NE FAIT PAS
--   - Il n'interdit rien et ne désactive aucune ressource (décision du 20/08).
--   - Mesure du 15/10 en production : 0 ressource restreinte active sans
--     détentrice (7 restreintes, toutes détenues, toutes avec exemplaire).
--
-- CHECKLIST DOCTRINE
--   [x] Fonctions DEFINER : SET search_path ; REVOKE EXECUTE ... FROM PUBLIC,
--       anon, authenticated (déclencheur : aucun grant) ; contrôle ouvert à
--       authenticated, fermé à anon
--   [x] DO block de vérification STRUCTUREL ; le fonctionnel vit dans
--       tests/sql/restreint_sans_detentrice_tests.sql
-- =========================================================================

BEGIN;

-- ── 1. Le signal, au moment où la dernière détention disparaît ──────────
CREATE OR REPLACE FUNCTION public.tg_book_holdings_restreint_sans_detentrice()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = OLD.book_id) THEN
    RETURN OLD;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.book_digital_resources r
                  WHERE r.book_id = OLD.book_id AND r.access_scope <> 'publico'
                    AND r.status = 'active' AND r.is_active) THEN
    RETURN OLD;
  END IF;
  INSERT INTO public.user_notifications (user_id, library_id, category, title, body, link_type, link_id, is_read)
  SELECT DISTINCT d.user_id, OLD.library_id, 'catalog',
         'notif.restrictedOrphan.title', 'notif.restrictedOrphan.body',
         'restricted_without_holder', OLD.book_id::text, false
    FROM (SELECT m.user_id FROM public.user_library_memberships m
           WHERE m.library_id = OLD.library_id AND m.status = 'active'
             AND m.role IN ('coordenador', 'administrador')
          UNION
          SELECT na.user_id FROM public.network_administrators na WHERE na.status = 'active') d;
  RETURN OLD;
END;
$function$;
COMMENT ON FUNCTION public.tg_book_holdings_restreint_sans_detentrice() IS
  'NUMDIF-D19 (15/10/2026, DOC-SILENCE-1) : quand la dernière détention d''un livre disparaît et qu''il porte une ressource '
  'restreinte active, notifie la coordination de la bibliothèque qui la perd et l''administration du réseau. N''interdit rien.';

REVOKE EXECUTE ON FUNCTION public.tg_book_holdings_restreint_sans_detentrice() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_book_holdings_restreint_sans_detentrice ON public.book_holdings;
CREATE TRIGGER trg_book_holdings_restreint_sans_detentrice
  AFTER DELETE ON public.book_holdings
  FOR EACH ROW EXECUTE FUNCTION public.tg_book_holdings_restreint_sans_detentrice();


-- ── 2. Le contrôle ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_restricted_resources_without_holder()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_res jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT coalesce(public.fn_caller_is_network_admin(), false) THEN
    RETURN jsonb_build_object('total', 0, 'resources', '[]'::jsonb);
  END IF;
  SELECT jsonb_build_object('total', count(*),
           'resources', coalesce(jsonb_agg(jsonb_build_object(
             'resource_id', r.id, 'book_id', r.book_id, 'titulo', b.titulo, 'bib_ref', b.bib_ref,
             'label', r.label, 'access_scope', r.access_scope, 'storage_bucket', r.storage_bucket,
             'activated_at', r.activated_at) ORDER BY r.id), '[]'::jsonb))
    INTO v_res
    FROM public.book_digital_resources r
    JOIN public.books b ON b.id = r.book_id
   WHERE r.access_scope <> 'publico' AND r.status = 'active' AND r.is_active
     AND NOT EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = r.book_id);
  RETURN v_res;
END;
$function$;
COMMENT ON FUNCTION public.fn_restricted_resources_without_holder() IS
  'NUMDIF-D19 (15/10/2026) : le contrôle « restreint sans détentrice » — les ressources restreintes actives dont le livre n''a '
  'plus aucune ligne book_holdings, illisibles pour toute personne hors administration du réseau. Administration du réseau ; '
  'vide, sans erreur, pour tout autre compte.';

REVOKE EXECUTE ON FUNCTION public.fn_restricted_resources_without_holder() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_restricted_resources_without_holder() TO authenticated, service_role;


-- ── 3. Vérification structurelle ───────────────────────────────────────
DO $numdif_d19_verif$
DECLARE v_e text := '';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.book_holdings'::regclass
                  AND t.tgname = 'trg_book_holdings_restreint_sans_detentrice' AND NOT t.tgisinternal
                  AND t.tgfoid = 'public.tg_book_holdings_restreint_sans_detentrice()'::regprocedure
                  AND (t.tgtype & 8) = 8) THEN
    v_e := v_e || ' declencheur';
  END IF;
  IF has_function_privilege('authenticated', 'public.tg_book_holdings_restreint_sans_detentrice()', 'EXECUTE')
     OR has_function_privilege('anon', 'public.tg_book_holdings_restreint_sans_detentrice()', 'EXECUTE') THEN
    v_e := v_e || ' droits-declencheur';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.fn_restricted_resources_without_holder()', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_restricted_resources_without_holder()', 'EXECUTE') THEN
    v_e := v_e || ' droits-controle';
  END IF;
  IF v_e <> '' THEN
    RAISE EXCEPTION 'NUMDIF-D19 : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'NUMDIF-D19 : vérifications OK';
END
$numdif_d19_verif$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =========================================================================
-- Rollback ciblé :
-- BEGIN;
--   DROP TRIGGER IF EXISTS trg_book_holdings_restreint_sans_detentrice ON public.book_holdings;
--   DROP FUNCTION IF EXISTS public.tg_book_holdings_restreint_sans_detentrice();
--   DROP FUNCTION IF EXISTS public.fn_restricted_resources_without_holder();
-- COMMIT;
-- =========================================================================
