-- B14, lot `api` : `get_due_date_for_loan` consultait les cotisations d'autrui.
--
-- CE QUE LA FONCTION FAISAIT. Elle prend un `p_user_id` en paramètre et, avant
-- toute chose, appelait `fn_is_loan_blocked_by_dues(p_user_id, …)` avec le
-- paramètre BRUT, puis lisait `v_active_memberships.dues_status` pour ce même
-- identifiant. Une personne simplement inscrite pouvait donc demander l'état de
-- cotisation de n'importe qui : « Contribuição vencida » ou « Contribuição
-- obrigatória não registrada », à partir d'un UUID. C'est la forme exacte que
-- l'audit du 18/05 apprend à chercher — un identifiant en paramètre, une donnée
-- nominative en retour — et dans une bibliothèque militante, savoir qui n'est
-- pas à jour de sa cotisation n'est pas une donnée technique.
--
-- POURQUOI PERSONNE NE L'A VU. `api.resolve_circulation_rule`, appelée juste
-- après, fait le travail correctement (son étape 3 « RÉSOLUTION SÉCURISÉE DE
-- v_user_id » : un `p_user_id` étranger retombe silencieusement sur l'appelant,
-- sauf pour le staff de la bibliothèque). La garde EXISTE, elle est bien
-- écrite, elle est juste APRÈS le bloc qui lit les cotisations. Lire la
-- fonction déléguée rassure ; c'est la fonction appelante qu'il fallait lire.
--
-- CE QUI FAIT QUE CE N'ÉTAIT PAS ENCORE EXPLOITABLE — et pourquoi ça ne change
-- rien à l'urgence. `fn_is_loan_blocked_by_dues` sort `false` d'emblée si la
-- bibliothèque n'a pas `membership_enabled`. Relevé le 01/09/2026 : AUCUNE
-- bibliothèque ne l'a activé, donc le bloc n'est jamais atteint aujourd'hui.
-- La fuite est DORMANTE : elle s'arme toute seule le jour où une bibliothèque
-- active les cotisations (chantier `COTIS`), sans que rien ne le signale. Un
-- défaut qui attend une case à cocher pour devenir réel est un défaut qu'on
-- corrige avant la case, pas après.
--
-- LE CORRECTIF. La même résolution que l'étape 3 de `resolve_circulation_rule`,
-- appliquée AVANT la lecture des cotisations : on ne lit l'état que de
-- soi-même, ou d'un membre de la bibliothèque dont on est staff. Le staff garde
-- son usage réel (le Painel projette un prêt pour une lectrice au comptoir).
-- Pour tout autre appelant, `p_user_id` est ignoré et remplacé par l'appelant —
-- silencieusement, exactement comme le fait déjà la fonction déléguée : la
-- réponse reste vraie, elle porte simplement sur soi.

CREATE OR REPLACE FUNCTION api.get_due_date_for_loan(
  p_library_id uuid,
  p_user_id uuid DEFAULT NULL::uuid,
  p_book_id bigint DEFAULT NULL::bigint,
  p_holding_id bigint DEFAULT NULL::bigint,
  p_quantity integer DEFAULT 1,
  p_as_of_date date DEFAULT NULL::date
)
RETURNS TABLE(due_date date, loan_allowed boolean, consultation_only boolean, policy_set_id bigint, rule_id bigint, rule_label text, explanation text)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'api', 'auth', 'pg_temp'
AS $function$
declare
  v_caller_uid uuid := auth.uid();
  v_user_id uuid;
  v_dues_blocked boolean := false;
  v_dues_status text;
  v_dues_message text;
begin
  -- Résolution sécurisée de l'identifiant lu — MÊME RÈGLE que l'étape 3 de
  -- api.resolve_circulation_rule, appliquée ici parce que le bloc « cotisations »
  -- s'exécute AVANT elle. Toute évolution de l'une doit suivre dans l'autre.
  v_user_id := case
    when v_caller_uid is null then null
    when v_caller_uid = p_user_id then p_user_id
    when public.user_has_library_staff_role(v_caller_uid, p_library_id)
      then coalesce(p_user_id, v_caller_uid)
    else v_caller_uid
  end;

  if v_user_id is not null then
    v_dues_blocked := public.fn_is_loan_blocked_by_dues(v_user_id, p_library_id);

    if v_dues_blocked then
      select dues_status into v_dues_status
      from public.v_active_memberships
      where user_id = v_user_id and library_id = p_library_id;

      v_dues_message := case v_dues_status
        when 'never_paid' then 'Contribuição obrigatória não registrada.'
        when 'expired'   then 'Contribuição vencida.'
        else                  'Contribuição obrigatória não está em dia.'
      end;

      return query
      select
        null::date as due_date,
        false      as loan_allowed,
        false      as consultation_only,
        null::bigint as policy_set_id,
        null::bigint as rule_id,
        'dues_blocked'::text as rule_label,
        v_dues_message as explanation;
      return;
    end if;
  end if;

  return query
  select
    r.resolved_due_date as due_date,
    r.loan_allowed,
    r.consultation_only,
    r.policy_set_id,
    r.rule_id,
    r.rule_label,
    r.explanation
  from api.resolve_circulation_rule(
    p_library_id := p_library_id,
    p_mode := 'loan',
    p_user_id := v_user_id,
    p_book_id := p_book_id,
    p_holding_id := p_holding_id,
    p_quantity := p_quantity,
    p_as_of_date := p_as_of_date,
    p_current_due_date := null,
    p_renewals_used := 0
  ) r;
end;
$function$;

COMMENT ON FUNCTION api.get_due_date_for_loan(uuid, uuid, bigint, bigint, integer, date) IS
  'Projette la date de retour d''un prêt. p_user_id n''est honoré que pour soi-même ou par le staff de la bibliothèque : pour tout autre appelant il est remplacé par l''appelant (même règle que l''étape 3 de api.resolve_circulation_rule). Durci le 01/09/2026 (B14) — le bloc « cotisations » s''exécutant AVANT la fonction déléguée, il lisait l''état de cotisation de n''importe quel UUID ; fuite dormante, aucune bibliothèque n''ayant activé membership_enabled à cette date.';

DO $$
BEGIN
  IF NOT has_function_privilege('authenticated', 'api.get_due_date_for_loan(uuid, uuid, bigint, bigint, integer, date)', 'EXECUTE') THEN
    RAISE EXCEPTION 'get_due_date_for_loan a perdu EXECUTE pour authenticated — le Painel casserait, rollback';
  END IF;
END $$;
