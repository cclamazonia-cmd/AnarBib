-- =========================================================================
-- Actus réseau — Phase 1 : la Lettre crée un avis in-app au compte lecteur·rice
-- =========================================================================
-- Date     : 2026-06-17
-- Chantier : Feeding « avis & notifications » — surfacer les diffusions réseau
-- Auteur   : Claude (assistant·e)
-- Session  : Avis & notifications — feeding réseau (Phase 1 Lettre)
-- Branche  : rede-actus-notifs-inapp (hors worktree partagé)
--
-- Problème : la section avis du compte lecteur·rice est quasi vide, et les
-- diffusions de la fédération (Lettre, Gazette, cercles) n'y arrivent jamais —
-- seules des notifications transactionnelles ou des e-mails opt-in existent.
-- Un lecteur·rice qui ne va pas de lui-même sur /federacao ne sait rien d'une
-- nouvelle Lettre.
--
-- Décisions produit (Xavier) :
--   - Canal : avis IN-APP par défaut pour tou·tes, e-mail réservé aux opt-in
--     existants (la Lettre garde son double consentement / outbox e-mail).
--   - Anti-spam : un SEUL toggle « actus réseau » (pas un par type) — gouverne
--     Lettre + (à venir) Gazette + cercles.
--
-- Phase 1 = Lettre (le gabarit). Gazette et cercles suivront sur le même modèle.
--
-- Contenu :
--   1) Préférences : nouvelle colonne disable_rede_news (toggle « actus réseau »)
--      + fn_get/fn_set_my_notification_preferences étendues.
--   2) api.fn_lettre_issue_send : en plus du fan-out e-mail opt-in (inchangé),
--      insère un avis in-app (category 'rede_lettre', titre/corps = clés i18n
--      résolues côté front, lien → /federacao/carta) pour les lecteur·rices
--      actif·ves NON opt-out. Idempotent (la fonction sort tôt si déjà envoyée).
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1) Toggle « actus réseau »
-- -------------------------------------------------------------------------
ALTER TABLE public.user_notification_preferences
  ADD COLUMN IF NOT EXISTS disable_rede_news boolean NOT NULL DEFAULT false;

-- Ajout d'une colonne au RETURNS TABLE = changement de type de retour -> DROP+CREATE
-- (CREATE OR REPLACE l'interdit). DROP perd les grants -> on les repose ensuite.
DROP FUNCTION IF EXISTS public.fn_get_my_notification_preferences();
CREATE OR REPLACE FUNCTION public.fn_get_my_notification_preferences()
 RETURNS TABLE(disable_reserva_pronta boolean, disable_consulta_pronta boolean, disable_rede_news boolean)
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth required'
      USING HINT = 'fn_get_my_notification_preferences: no authenticated user';
  END IF;
  RETURN QUERY
  SELECT
    COALESCE(p.disable_reserva_pronta, false),
    COALESCE(p.disable_consulta_pronta, false),
    COALESCE(p.disable_rede_news, false)
  FROM (SELECT v_user_id AS uid) u
  LEFT JOIN public.user_notification_preferences p ON p.user_id = u.uid;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_get_my_notification_preferences() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_get_my_notification_preferences() TO authenticated;

-- Signature étendue (3e arg) -> DROP + CREATE. Le 3e arg a un DEFAULT pour que
-- l'appel front legacy à 2 arguments continue de résoudre pendant la transition.
DROP FUNCTION IF EXISTS public.fn_set_my_notification_preferences(boolean, boolean);
CREATE OR REPLACE FUNCTION public.fn_set_my_notification_preferences(
  p_disable_reserva_pronta boolean,
  p_disable_consulta_pronta boolean,
  p_disable_rede_news boolean DEFAULT false
)
 RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth required'
      USING HINT = 'fn_set_my_notification_preferences: no authenticated user';
  END IF;
  INSERT INTO public.user_notification_preferences (
    user_id, disable_reserva_pronta, disable_consulta_pronta, disable_rede_news, updated_at
  )
  VALUES (
    v_user_id,
    COALESCE(p_disable_reserva_pronta, false),
    COALESCE(p_disable_consulta_pronta, false),
    COALESCE(p_disable_rede_news, false),
    now()
  )
  ON CONFLICT (user_id) DO UPDATE
    SET disable_reserva_pronta  = EXCLUDED.disable_reserva_pronta,
        disable_consulta_pronta = EXCLUDED.disable_consulta_pronta,
        disable_rede_news       = EXCLUDED.disable_rede_news,
        updated_at              = now();
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_set_my_notification_preferences(boolean, boolean, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_set_my_notification_preferences(boolean, boolean, boolean) TO authenticated;

-- -------------------------------------------------------------------------
-- 2) Lettre envoyée -> avis in-app (en plus du fan-out e-mail opt-in inchangé)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_lettre_issue_send(p_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'api', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_issue public.lettre_issues;
  v_count int := 0;
begin
  if not exists (select 1 from public.network_staff ns where ns.user_id = v_uid and ns.is_active) then
    raise exception 'forbidden: network_staff only' using errcode = '42501';
  end if;

  select * into v_issue from public.lettre_issues where id = p_id for update;
  if not found then raise exception 'numéro introuvable' using errcode = '22023'; end if;
  if v_issue.status = 'sent' then return 0; end if;  -- déjà envoyé : idempotent

  -- Garantir un token de désabonnement stable pour chaque abonné·e (1-clic sans login).
  insert into public.lettre_consent_tokens (user_id, action)
    select p.id, 'unsubscribe'
    from public.profiles p
    where p.consent_lettre = true and coalesce(p.email, '') <> ''
      and not exists (
        select 1 from public.lettre_consent_tokens t
        where t.user_id = p.id and t.action = 'unsubscribe' and t.consumed_at is null);

  -- Fan-out e-mail : 1 ligne d'outbox par abonné·e opt-in -> trigger dispatch notify-event.
  with subs as (
    select p.id, p.email, p.first_name, p.preferred_language,
           (select t.token from public.lettre_consent_tokens t
             where t.user_id = p.id and t.action = 'unsubscribe' and t.consumed_at is null
             order by t.created_at desc limit 1) as unsub_token
    from public.profiles p
    where p.consent_lettre = true and coalesce(p.email, '') <> ''
  ),
  ins as (
    insert into public.lettre_notification_outbox (event, payload)
    select 'lettre.issue.sent',
           jsonb_build_object(
             'issue_id',    v_issue.id,
             'number',      v_issue.number,
             'to',          s.email,
             'to_name',     s.first_name,
             'locale',      coalesce(s.preferred_language, 'pt-BR'),
             'intro',       v_issue.intro_md,
             'items',       v_issue.items,
             'unsub_token', s.unsub_token
           )
    from subs s
    returning 1
  )
  select count(*) into v_count from ins;

  -- AJOUT 17/06/2026 : fan-out AVIS IN-APP « actus réseau ». Canal par défaut,
  -- indépendant de l'opt-in e-mail : tou·tes les lecteur·rices actif·ves qui
  -- n'ont pas désactivé le toggle « actus réseau ». Titre/corps = clés i18n
  -- résolues côté front (cf. catégorie 'rede_*'), lien -> /federacao/carta.
  -- Une seule fois (la fonction sort plus haut si v_issue.status = 'sent').
  insert into public.user_notifications (
    user_id, library_id, category, title, body, link_type, link_id, is_read
  )
  select distinct m.user_id, null::uuid, 'rede_lettre',
         'notif.rede.lettre.title', 'notif.rede.lettre.body',
         'rede_lettre', v_issue.id::text, false
  from public.user_library_memberships m
  left join public.user_notification_preferences np on np.user_id = m.user_id
  where m.status = 'active'
    and coalesce(np.disable_rede_news, false) = false;

  update public.lettre_issues
     set status = 'sent', sent_at = now(), sent_by = v_uid, recipients_count = v_count
   where id = p_id;
  return v_count;
end;
$function$;

COMMIT;
