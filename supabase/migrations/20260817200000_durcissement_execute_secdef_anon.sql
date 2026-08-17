-- =============================================================================
-- Durcissement : retrait des droits EXECUTE inutiles sur des fonctions
-- SECURITY DEFINER exposées au rôle `anon`.
-- =============================================================================
-- Origine : audit du 17/08/2026 — advisors Supabase (472 WARN
-- `authenticated_security_definer_function_executable`, 48 WARN
-- `anon_security_definer_function_executable`) puis lecture du corps des
-- fonctions concernées.
--
-- AUCUN corps de fonction n'est modifié ici : uniquement des REVOKE.
-- Rappel doctrinal : SECURITY DEFINER contourne la RLS par construction, donc
-- le droit EXECUTE est le seul rempart restant.
--
-- -----------------------------------------------------------------------------
-- VÉRIFICATION PRÉALABLE — à ne pas défaire
-- -----------------------------------------------------------------------------
-- Une policy RLS s'évalue avec les droits de l'appelant : révoquer EXECUTE sur
-- une fonction citée dans une policy casse l'accès aux tables concernées, y
-- compris pour la navigation anonyme du catalogue.
--
-- Les fonctions suivantes portent des policies et ne sont donc VOLONTAIREMENT
-- PAS touchées (comptage au 17/08/2026) :
--   public.user_can_act_as_staff_on_library(uuid) ....... 33 policies
--   public.user_can_engage_library(uuid) ................ 32 policies
--   public.fn_caller_is_network_admin() ................. 26 policies
--   public.fn_library_visible_to_caller(uuid) ........... 12 policies
--   public.fn_caller_is_library_staff(uuid) .............. 1 policy
--
-- Toutes celles révoquées ci-dessous ont été contrôlées : 0 policy.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. PRIORITAIRE — déclencheur de traduction exposé sans authentification
-- -----------------------------------------------------------------------------
-- `fn_gazette_translate_call()` ne prend aucun argument, n'effectue aucun
-- contrôle d'appelant, lit le secret `gazette_cron_secret` dans le Vault et
-- appelle l'Edge Function `translate-gazette-submission`, qui consomme une API
-- de LLM facturée. Toute personne non authentifiée pouvait la déclencher via
-- /rest/v1/rpc/. Seul le job cron l'appelle légitimement, et il s'exécute avec
-- les droits du propriétaire — la révocation ne le gêne pas.
revoke execute on function public.fn_gazette_translate_call()
  from anon, authenticated, public;

-- -----------------------------------------------------------------------------
-- 2. Résolution d'identité civile sans session
-- -----------------------------------------------------------------------------
-- `fn_assembleia_facilitator_name(uuid)` renvoie prénom + nom depuis
-- `profiles` pour tout UUID correspondant à un·e facilitateur·rice
-- d'assemblée. Sans authentification, c'est à la fois un oracle
-- d'appartenance et une divulgation d'identité, portant précisément sur les
-- personnes les plus exposées du réseau.
revoke execute on function public.fn_assembleia_facilitator_name(p_user_id uuid)
  from anon, public;

-- -----------------------------------------------------------------------------
-- 3. Helpers de partenariat — oracles sur un tiers
-- -----------------------------------------------------------------------------
-- Renseignent l'état de consentement ou d'appartenance d'une lectrice tierce.
-- Usage interne (appelés depuis d'autres fonctions SECURITY DEFINER, ce qui
-- reste possible) : aucune raison d'être joignables sans session.
revoke execute on function public.fn_reader_consent_valid(p_user_id uuid, p_partnership_id uuid)
  from anon, public;
revoke execute on function public.fn_partnership_transparence_active(p_library_a uuid, p_library_b uuid, p_user_id uuid)
  from anon, public;
revoke execute on function public.fn_partnership_canonical_id(p_partnership_id uuid)
  from anon, public;
revoke execute on function public.fn_partnership_has_active_right(p_from uuid, p_to uuid, p_right_key text)
  from anon, public;

-- -----------------------------------------------------------------------------
-- 4. Fonctions à sémantique « mon / ma »
-- -----------------------------------------------------------------------------
-- Elles s'appuient sur auth.uid() : sans session, elles ne peuvent rien faire
-- d'utile. Retrait de `anon` par cohérence — `authenticated` est conservé.
revoke execute on function public.fn_get_my_notification_preferences()
  from anon, public;
revoke execute on function public.fn_set_my_notification_preferences(
    p_disable_reserva_pronta boolean, p_disable_consulta_pronta boolean,
    p_disable_rede_news boolean, p_disable_library_events boolean)
  from anon, public;
revoke execute on function public.fn_my_reading_note_target()
  from anon, public;

-- -----------------------------------------------------------------------------
-- 5. Prédicats d'autorisation hors policies
-- -----------------------------------------------------------------------------
-- Ne divulguent que la topologie des rôles, mais sans usage anonyme légitime.
revoke execute on function public.fn_caller_is_assembleia_facilitator(p_assembleia_id uuid)
  from anon, public;
revoke execute on function public.fn_is_catalog_coordinator()
  from anon, public;

-- -----------------------------------------------------------------------------
-- 6. Fonctions de trigger exposées en RPC par accident
-- -----------------------------------------------------------------------------
-- Elles retournent `trigger` et n'ont aucun sens en appel direct.
-- IMPORTANT : le déclenchement d'un trigger ne contrôle PAS le droit EXECUTE.
-- Les triggers continuent donc de fonctionner à l'identique après ces REVOKE.
revoke execute on function public.fn_books_ensure_work()
  from anon, authenticated, public;
revoke execute on function public.fn_validate_exemplar_library_matches_holding()
  from anon, authenticated, public;
revoke execute on function public.tg_notify_library_event_created()
  from anon, authenticated, public;
revoke execute on function public.fn_reading_note_before_insert()
  from anon, authenticated, public;
revoke execute on function public.fn_reading_note_before_update()
  from anon, authenticated, public;

commit;

-- =============================================================================
-- CONTRÔLE APRÈS DÉPLOIEMENT
-- =============================================================================
-- Doit renvoyer 48 - 15 = 33 lignes (les 15 révoquées pour `anon` ci-dessus
-- disparaissent de la liste) :
--
--   select n.nspname, p.proname
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--   where p.prosecdef and n.nspname in ('public','api')
--     and has_function_privilege('anon', p.oid, 'EXECUTE')
--   order by 1, 2;
--
-- Vérifier ensuite, en navigation ANONYME : le catalogue s'affiche, une notice
-- s'ouvre, une couverture se charge, l'endpoint OAI-PMH répond.
-- Puis, connecté·e : les préférences de notification et les notes de lecture
-- fonctionnent toujours.
-- =============================================================================
