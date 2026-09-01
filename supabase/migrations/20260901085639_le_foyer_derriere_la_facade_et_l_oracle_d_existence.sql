-- B14, schéma `public`, paquet 1 : le foyer derrière la façade, et un oracle
-- d'existence d'adresse e-mail.
--
-- ============================================================================
-- 1. LE FOYER DERRIÈRE LA FAÇADE — `fn_is_loan_blocked_by_dues`
-- ============================================================================
-- Le 01/09 au matin, le paquet 1 du lot `api` a fermé `api.get_due_date_for_loan`,
-- qui lisait l'état de cotisation de n'importe quel UUID. Le correctif était
-- juste — et incomplet : **le helper qu'elle appelait est lui-même exposé à
-- `authenticated`**. Fermer la façade laissait le foyer ouvert ; on pouvait
-- poser la même question directement à `/rest/v1/rpc/fn_is_loan_blocked_by_dues`.
-- C'est `DOC-RECENS-1` appliqué aux correctifs : corriger un chemin ne corrige
-- pas ce qu'il traversait.
--
-- Éprouvé en production avant écriture : appelée en contexte `authenticated`
-- par un tiers ni concerné ni staff, elle répond. Elle ne consulte jamais
-- `auth.uid()` — l'appelant lui est indifférent.
--
-- POURQUOI UNE GARDE ET NON UN `REVOKE` — et un faux positif de mon propre
-- recensement, corrigé avant d'écrire. Le relevé des appelants (`prosrc ~
-- 'fn_is_loan_blocked_by_dues'`) faisait apparaître `api.confirm_pickup_v1`,
-- qui est **SECURITY INVOKER** : un `REVOKE` l'aurait cassée. Vérification
-- faite, elle ne l'appelle pas — elle la **mentionne dans un commentaire**
-- (« lève fn_is_loan_blocked_by_dues si cotisation bloquante ») et délègue en
-- réalité à `fn_v2_convert_reserva_linhas_to_emprestimo`, qui est DEFINER.
-- Chercher un appel par le texte du corps trouve aussi les commentaires :
-- `DOC-RECENS-1` s'applique à l'inventaire des appelants comme au reste.
--
-- Le `REVOKE` serait donc sûr. On pose quand même la garde DANS LE CORPS, et
-- c'est un choix : elle protège le jour où un appelant INVOKER apparaîtra pour
-- de bon, elle vaut pour tous les chemins d'un coup, et elle suit `DOC-RPC-3`
-- (le refus vit dans le corps, pas dans le droit). Vérifié pour chacun des six
-- appelants réels : `auth.uid()` y est celui de la personne à l'écran — staff
-- qui prête pour une lectrice (passe par le second terme), ou lectrice sur son
-- propre compte (premier terme). Aucun ne casse.
--
-- La règle est celle déjà posée sur la façade : on ne répond que sur soi-même,
-- ou pour un membre de la bibliothèque dont on est staff. `auth.uid() IS NULL`
-- laisse passer — la fonction n'est pas exposée à `anon` (vérifié), donc ce cas
-- ne peut être qu'un contexte serveur : cron, `service_role`, Edge Function.

CREATE OR REPLACE FUNCTION public.fn_is_loan_blocked_by_dues(p_user_id uuid, p_library_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_enabled boolean;
  v_dues_status text;
  v_rule_required boolean;
BEGIN
  -- Garde d'appelant. NULL = contexte serveur (la fonction n'est pas exposée
  -- à `anon`) : on laisse passer, l'appelant a déjà gardé pour nous.
  IF v_caller IS NOT NULL
     AND v_caller <> p_user_id
     AND NOT public.user_has_library_staff_role(v_caller, p_library_id) THEN
    RAISE EXCEPTION 'forbidden: dues status is readable for yourself or by staff of that library'
      USING ERRCODE = '42501';
  END IF;

  SELECT membership_enabled INTO v_enabled
  FROM public.libraries WHERE id = p_library_id;

  IF NOT COALESCE(v_enabled, false) THEN
    RETURN false;
  END IF;

  SELECT dues_status INTO v_dues_status
  FROM public.v_active_memberships
  WHERE user_id = p_user_id AND library_id = p_library_id;

  IF v_dues_status IS NULL OR v_dues_status IN ('up_to_date', 'lifetime', 'not_applicable') THEN
    RETURN false;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.library_membership_rules
    WHERE library_id = p_library_id
      AND is_active = true
      AND is_required = true
  ) INTO v_rule_required;

  RETURN COALESCE(v_rule_required, false);
END
$function$;

COMMENT ON FUNCTION public.fn_is_loan_blocked_by_dues(uuid, uuid) IS
  'Prédicat interne : la cotisation bloque-t-elle le prêt ? Ne répond que sur soi-même ou pour un membre de la bibliothèque dont on est staff (durci le 01/09/2026, B14) — le helper était exposé à authenticated alors que sa façade api.get_due_date_for_loan venait d''être bornée le matin même. Garde dans le corps et non REVOKE, par défense en profondeur : tous les appelants réels sont SECURITY DEFINER (api.confirm_pickup_v1 ne fait que la citer en commentaire), mais la garde vaut pour tous les chemins et pour ceux à venir.';

-- ============================================================================
-- 2. QUATRE HELPERS INTERNES QUI N'ONT RIEN À FAIRE SUR LA SURFACE API
-- ============================================================================
-- Aucun n'est appelé par le frontend ni par une Edge Function (vérifié dans le
-- dépôt), aucun n'est cité par une policy RLS (vérifié en base), et TOUS leurs
-- appelants SQL sont `SECURITY DEFINER` — un `REVOKE` ne peut donc rien casser.
-- Ils sont exposés par le seul effet du défaut de schéma, pas par décision.
--
--   * `fn_membership_can_engage_circulation` — le même oracle que ci-dessus, en
--     pire : il distingue `restricted` de `dues`. Éprouvé lui aussi.
--   * `fn_network_notify_event` — helper d'émission vers l'outbox réseau ;
--     exposé, il laisse injecter des événements `network.%`.
--   * `fn_purge_audit_draft_snapshots` — purge d'audit à 90 jours, appelée par
--     le cron `anarbib-catalog-audit-snapshot-purge` en `service_role`. Exposée,
--     n'importe qui pouvait déclencher l'effacement de l'historique.
--   * `get_library_contact_for_cooperation` — rend courriel, téléphone,
--     WhatsApp et adresse postale de N'IMPORTE QUELLE bibliothèque, sans aucune
--     garde. **Elle n'a aucun appelant** : ni front, ni fonction, ni policy.
--     Même famille que la fuite d'annuaire fermée en août pour `anon` — ici
--     pour `authenticated`, et pour un annuaire de lieux militants.

REVOKE EXECUTE ON FUNCTION public.fn_membership_can_engage_circulation(uuid, uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_network_notify_event(text, jsonb) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_purge_audit_draft_snapshots() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_library_contact_for_cooperation(uuid) FROM authenticated;

COMMENT ON FUNCTION public.get_library_contact_for_cooperation(uuid) IS
  'Contacts d''une bibliothèque pour la coopération. AUCUN appelant au 01/09/2026 (ni front, ni fonction, ni policy) et aucune garde dans le corps : fermée à authenticated (B14). Si un usage la ressuscite, lui écrire d''abord une garde — partenariat actif ou staff — avant de la rouvrir.';

-- ============================================================================
-- 3. L'ORACLE D'EXISTENCE — `fn_painel_find_profile_by_lookup`
-- ============================================================================
-- La fonction cherche un profil par identifiant public ou par e-mail, et garde
-- correctement l'ACCÈS (`can_manage_profile_from_my_libraries`). Mais elle
-- distinguait deux refus : « compte trouvé, mais il n'appartient pas à la
-- bibliothèque active » d'un côté, « rien trouvé » de l'autre.
--
-- Le premier message confirme qu'un compte EXISTE dans le réseau. Toute
-- personne simplement inscrite pouvait donc tester une adresse e-mail et savoir
-- si elle correspond à un compte — sans y avoir accès. **Dans un réseau de
-- bibliothèques anarchistes, confirmer qu'une adresse appartient à quelqu'un du
-- réseau n'est pas une donnée technique.** Et c'est exploitable aujourd'hui :
-- il suffit d'un compte, aucune case à cocher n'a besoin d'être armée.
--
-- C'est l'exact contraire de `api.resolve_reader_card`, lue au paquet 4 du lot
-- `api`, qui rend **volontairement** le même motif pour « pas staff » et pour
-- « jeton inconnu », avec un commentaire expliquant que la banalité du motif
-- EST le contrôle. Les deux formes cohabitaient ; celle-ci est la mauvaise.
--
-- Correctif : un seul et même message pour les deux refus. L'usage légitime
-- n'en souffre pas — le staff qui trouve son profil reçoit la ligne, jamais un
-- message. CLAUDE.md signalait cette fonction depuis mai comme prioritaire pour
-- l'audit d'énumération ; c'est fait.

CREATE OR REPLACE FUNCTION public.fn_painel_find_profile_by_lookup(p_lookup text)
RETURNS public.profiles
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_row public.profiles;
  v_lookup text := trim(coalesce(p_lookup, ''));
  v_public_id text := upper(v_lookup);
  v_email text := lower(v_lookup);
  -- Message UNIQUE pour tout échec de résolution : « je n'ai rien pour vous ».
  -- Ne pas le spécialiser — un motif qui distingue « existe ailleurs » de
  -- « n'existe pas » rend la fonction énumérable (B14, 01/09/2026).
  c_msg constant text := 'Não encontrei esse ID público ou e-mail no cadastro da biblioteca ativa.';
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if v_lookup = '' then
    raise exception 'Informe um ID público ou e-mail.';
  end if;

  select p.* into v_row
  from public.profiles p
  where upper(coalesce(trim(p.public_id), '')) = v_public_id
  limit 1;

  if v_row.id is not null and public.can_manage_profile_from_my_libraries(v_row.id) then
    return v_row;
  end if;

  select p.* into v_row
  from public.profiles p
  where lower(coalesce(trim(p.email), '')) = v_email
  limit 1;

  if v_row.id is not null and public.can_manage_profile_from_my_libraries(v_row.id) then
    return v_row;
  end if;

  raise exception '%', c_msg;
end;
$function$;

COMMENT ON FUNCTION public.fn_painel_find_profile_by_lookup(text) IS
  'Résolution d''un profil par identifiant public ou e-mail, pour le panneau. Rend UN SEUL message d''échec, que le compte existe hors de vos bibliothèques ou qu''il n''existe pas — durci le 01/09/2026 (B14) : les deux messages distincts faisaient un oracle d''existence d''adresse e-mail. Même doctrine que api.resolve_reader_card : la banalité du motif est le contrôle.';

-- ============================================================================
-- GARDES DE FIN
-- ============================================================================
DO $$
DECLARE v_pb text;
BEGIN
  -- Les quatre fermées le sont bien.
  SELECT string_agg(p.proname, ', ') INTO v_pb
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('fn_membership_can_engage_circulation','fn_network_notify_event',
                       'fn_purge_audit_draft_snapshots','get_library_contact_for_cooperation')
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE');
  IF v_pb IS NOT NULL THEN
    RAISE EXCEPTION 'encore exposees a authenticated : % — rollback', v_pb;
  END IF;

  -- Celle qui doit RESTER exposée (son appelant est SECURITY INVOKER) l'est.
  IF NOT has_function_privilege('authenticated', 'public.fn_is_loan_blocked_by_dues(uuid, uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_is_loan_blocked_by_dues a perdu EXECUTE : confirm_pickup_v1 (SECURITY INVOKER) casserait — rollback';
  END IF;

  -- L'oracle d'existence ne doit plus porter deux messages distincts.
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'fn_painel_find_profile_by_lookup'
       AND p.prosrc ~ 'pertence'
  ) THEN
    RAISE EXCEPTION 'le message distinctif subsiste dans fn_painel_find_profile_by_lookup — rollback';
  END IF;
END $$;
