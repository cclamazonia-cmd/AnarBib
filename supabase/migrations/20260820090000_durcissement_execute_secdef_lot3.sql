-- =============================================================================
-- Durcissement EXECUTE des fonctions SECURITY DEFINER — lot 3
-- =============================================================================
-- Termine l'audit commence le 17/08. Etat au 20/08 :
--
--   453 fonctions SECURITY DEFINER dans public
--   -81 fonctions de declencheur, non appelables en RPC
--    29 appelables sans compte  -> auditees, AUCUNE faille
--   292 appelables par un compte connecte
--    74 d'entre elles touchent des tables de donnees personnelles
--     8 sans controle apparent de l'appelant -> les 8 ont ete lues
--
-- Sur ces 8 : 2 etaient deja reglees, 3 se sont revelees saines (le controle
-- passe par un predicat, pas par auth.uid() -- voir plus bas), 3 sont traitees
-- ici.
--
-- LIMITE DE LA METHODE, a retenir pour les prochains lots : chercher
-- « auth.uid() » dans le corps d'une fonction ne prouve rien sur cette base.
-- Le controle est presque toujours delegue a un predicat :
--   fn_current_user_can_access_network_dashboard(), fn_current_user_conta_ativa(),
--   fn_library_visible_to_caller(), fn_caller_is_network_admin()...
-- Six fonctions suspectees sur ce critere se sont averees correctement gardees.
-- Le bon critere est : « que renvoie-t-elle, a partir de quel parametre, et
-- qu'est-ce qui interdit a un tiers de le demander ? »
--
-- VERIFIE AVANT ECRITURE, pour les trois fonctions ci-dessous :
--   * 0 policy RLS         (une policy s'evalue avec les droits de l'appelant)
--   * 0 vue security_invoker  (meme piege -- cf. fn_assembleia_facilitator_name,
--                              intouchable pour cette raison)
--   * 0 appel depuis src/ ou depuis les Edge Functions
--   * leurs seuls appelants sont des fonctions SECURITY DEFINER, donc l'appel
--     imbrique s'execute avec les droits du proprietaire, pas de l'appelant
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. circulation_reader_scope(uuid, uuid) — le plus serieux des trois
-- -----------------------------------------------------------------------------
-- Renvoie 'restricted' | 'librarian' | 'local_member' | 'network_member' |
-- 'non_member' pour un couple (personne, bibliotheque) quelconque.
--
-- Un compte connecte quelconque pouvait donc, avec un UUID, savoir :
--   - si cette personne est membre de telle bibliotheque ;
--   - si elle y est bibliothecaire ou coordinatrice ;
--   - SI ELLE EST EN RESTRICTION.
--
-- Dans un reseau de bibliotheques libertaires, l'appartenance est deja une
-- donnee sensible. Le statut de restriction l'est bien davantage.
--
-- Seul appelant : resolve_circulation_rule (SECURITY DEFINER).
revoke execute on function public.circulation_reader_scope(p_user_id uuid, p_library_id uuid)
  from anon, authenticated, public;

-- -----------------------------------------------------------------------------
-- 2. fn_reader_consent_valid(uuid, uuid)
-- -----------------------------------------------------------------------------
-- Renvoie un booleen : telle personne a-t-elle consenti a tel partenariat ?
-- Interrogeable sur n'importe quel UUID par n'importe quel compte connecte.
-- Revele a la fois une appartenance et un choix de partage de donnees.
--
-- Seul appelant : fn_partnership_transparence_active (SECURITY DEFINER).
revoke execute on function public.fn_reader_consent_valid(p_user_id uuid, p_partnership_id uuid)
  from anon, authenticated, public;

-- -----------------------------------------------------------------------------
-- 3. fn_validate_consulta_schedule_window(...) — hygiene, pas une faille
-- -----------------------------------------------------------------------------
-- Validateur pur : il leve des exceptions, il ne renvoie rien (RETURNS void).
-- Il ne divulgue aucune donnee personnelle. On le ferme parce qu'il n'a aucune
-- raison d'etre appelable directement, pas parce qu'il fuit : par sondage
-- repete, on pourrait au pire deduire les horaires d'ouverture (publics) et
-- l'occupation d'un creneau.
--
-- Appelants : fn_v2_set_consulta_linhas_schedule_reply et
--             fn_v2_set_consulta_linhas_workflow_slot (les deux SECURITY DEFINER).
revoke execute on function public.fn_validate_consulta_schedule_window(
    p_library_id uuid,
    p_consulta_id bigint,
    p_consultation_starts_at timestamp with time zone,
    p_consultation_ends_at timestamp with time zone)
  from anon, authenticated, public;

-- -----------------------------------------------------------------------------
-- Controle a passer apres deploiement
-- -----------------------------------------------------------------------------
-- select proname,
--        has_function_privilege('authenticated', oid, 'EXECUTE') as auth,
--        has_function_privilege('service_role',  oid, 'EXECUTE') as svc
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--  where n.nspname = 'public'
--    and proname in ('circulation_reader_scope','fn_reader_consent_valid',
--                    'fn_validate_consulta_schedule_window');
--
-- Attendu : auth = false pour les trois.
--
-- Et le controle fonctionnel, celui qui compte vraiment : un emprunt et une
-- consultation locale doivent continuer de fonctionner depuis le painel. C'est
-- resolve_circulation_rule et fn_v2_set_consulta_linhas_workflow_slot qui les
-- portent, et elles appellent les fonctions ci-dessus.
