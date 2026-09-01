-- =====================================================================
-- 20260901213921_rappel_avant_peremption.sql
--
-- Objet : qu'une proposition d'équipe cesse de pouvoir mourir en silence.
--
-- Constat (GOUV-17b / backlog F8) : depuis le 01/09 la cloche annonce
--   qu'une proposition existe, mais rien ne dit qu'elle va expirer.
--   `fn_team_expire_invitations` referme à 30 jours — à raison — et
--   jusqu'ici sans un mot. Une promotion pouvait donc échouer sans que
--   personne n'ait rien décidé : un silence tenant lieu de refus, alors
--   que TOUTE nomination au staff passe désormais par ce circuit
--   (GOUV-11, GOUV-13).
--
-- Décision (arbitrage Xavier, 01/09/2026 au soir) :
--
--   * UN rappel à J+21 — neuf jours restants : assez pour agir, assez
--     tard pour compter. La transposition proportionnelle de RES-Q3
--     (J+14/J+25 sur 60 jours → J+7/J+12 sur 30) a été écartée : ces
--     échéances réseau sont dans la PREMIÈRE moitié de la fenêtre, faites
--     pour entretenir l'élan d'un vote ; elles auraient laissé dix-huit
--     jours de silence avant l'expiration, soit le trou qu'on rebouche.
--
--   * UN avis à l'expiration. C'est lui le vrai correctif, plus qu'un
--     second rappel : répéter ne fait que répéter, tandis que l'avis
--     transforme une disparition silencieuse en fait consigné.
--
--   * Qui a PROPOSÉ est prévenu dans les deux cas. L'objection était
--     qu'iel ne peut rien débloquer seul·e — donc culpabilité sans
--     pouvoir. C'est l'inverse : la prévenir lui rend le seul pouvoir qui
--     vaille ici, celui d'aller parler aux gens. Doctrine du canal humain
--     premier (DOC-COLLECTIVE-1, RES-D9) : la machine signale, les
--     personnes se parlent.
--
-- Mécanique : aucune colonne ajoutée. Le cron tournant tous les jours, un
--   rappel se déclenche sur l'égalité de DATE `created_at + 21 jours` =
--   aujourd'hui — donc une fois et une seule, sans marqueur à maintenir.
--
-- Les deux canaux : in-app (user_notifications, la voie qu'on maîtrise) et
--   e-mail (outbox → notify-event). L'in-app ne dépend pas du mail, c'est
--   tout l'objet de GOUV-17 ; le mail atteint qui ne se connecte pas.
--
-- Rollback : `_rollback_20260901213921_rappel_avant_peremption.sql`.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Le rappel à J+21
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_team_invitation_remind()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_inv record;
  v_n integer := 0;
BEGIN
  FOR v_inv IN
    SELECT i.id, i.library_id, i.invited_user_id, i.proposed_by,
           i.role_proposed, i.status
      FROM public.library_team_invitations i
     WHERE i.status IN ('pending_ratification', 'ready')
       AND i.expires_at IS NOT NULL
       -- Égalité de DATE : le cron passant une fois par jour, la condition
       -- n'est vraie qu'un seul jour. Pas de colonne « déjà relancé » à
       -- tenir à jour, donc rien qui puisse se désynchroniser.
       AND (i.created_at + interval '21 days')::date = (now() AT TIME ZONE 'utc')::date
  LOOP
    -- ── in-app ──
    -- Qui doit agir : le staff qui peut endosser tant que le quorum n'est
    -- pas atteint, la personne concernée une fois qu'il l'est.
    IF v_inv.status = 'pending_ratification' THEN
      INSERT INTO public.user_notifications
        (user_id, library_id, category, title, body, link_type, link_id, is_read)
      SELECT DISTINCT m.user_id, v_inv.library_id, 'team',
             'notif.team.invitationReminder.title',
             'notif.team.invitationReminder.body',
             'team_invitation_ratify', v_inv.id::text, false
        FROM public.user_library_memberships m
       WHERE m.library_id = v_inv.library_id
         AND m.status = 'active'
         AND m.role IN ('librarian', 'coordenador')
         AND m.user_id <> v_inv.invited_user_id;
    ELSE
      INSERT INTO public.user_notifications
        (user_id, library_id, category, title, body, link_type, link_id, is_read)
      VALUES (v_inv.invited_user_id, v_inv.library_id, 'team',
              'notif.team.invitationReminder.title',
              'notif.team.invitationReminder.body',
              'team_invitation_accept', v_inv.id::text, false);
    END IF;

    -- Qui a proposé est prévenu dans les deux cas — pour aller parler aux
    -- gens, pas pour subir un rappel de plus. Le lien mène à l'écran
    -- d'équipe, là où la proposition se suit.
    IF v_inv.proposed_by IS NOT NULL
       AND v_inv.proposed_by <> v_inv.invited_user_id THEN
      INSERT INTO public.user_notifications
        (user_id, library_id, category, title, body, link_type, link_id, is_read)
      SELECT v_inv.proposed_by, v_inv.library_id, 'team',
             'notif.team.invitationReminder.title',
             'notif.team.invitationReminder.body',
             'team_invitation_ratify', v_inv.id::text, false
       WHERE NOT EXISTS (
         SELECT 1 FROM public.user_notifications n
          WHERE n.user_id = v_inv.proposed_by
            AND n.link_id = v_inv.id::text
            AND n.title = 'notif.team.invitationReminder.title'
       );
    END IF;

    -- ── e-mail ──
    PERFORM public.fn_team_notify_event('team.invitation_reminder', jsonb_build_object(
      'library_id', v_inv.library_id,
      'target_user_id', v_inv.invited_user_id,
      'actor_user_id', v_inv.proposed_by,
      'invitation_id', v_inv.id,
      'role_proposed', v_inv.role_proposed,
      'stage', v_inv.status));

    v_n := v_n + 1;
  END LOOP;

  RETURN v_n;
END
$fn$;

ALTER FUNCTION public.fn_team_invitation_remind() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_invitation_remind()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_team_invitation_remind() TO service_role;

COMMENT ON FUNCTION public.fn_team_invitation_remind() IS
  'Relance à J+21 les invitations d''équipe encore vivantes : in-app à qui doit agir ET à qui a proposé, plus un e-mail. Appelée par le cron anarbib-team-invitations-remind. Cf. GOUV-17b et migration 20260901213921.';

-- ---------------------------------------------------------------------
-- 2. L'expiration cesse d'être muette
--
-- Corps repris de 20260826120000 §6, avec la seule addition de l'avis.
-- La boucle remplace l'UPDATE global : il faut savoir QUI prévenir, donc
-- connaître chaque ligne fermée — un UPDATE ... RETURNING dans une CTE ne
-- permettrait pas d'appeler fn_team_notify_event par ligne.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_team_expire_invitations()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_inv record;
  v_count integer := 0;
BEGIN
  FOR v_inv IN
    UPDATE public.library_team_invitations
       SET status = 'expired',
           resolved_at = now(),
           updated_at = now(),
           resolution_note = COALESCE(resolution_note, '')
                             || ' [expirée automatiquement]'
     WHERE status IN ('pending_ratification', 'ready')
       AND expires_at IS NOT NULL
       AND expires_at < now()
    RETURNING id, library_id, invited_user_id, proposed_by, role_proposed
  LOOP
    -- La personne visée : quelque chose la concernant s'est refermé.
    INSERT INTO public.user_notifications
      (user_id, library_id, category, title, body, link_type, link_id, is_read)
    VALUES (v_inv.invited_user_id, v_inv.library_id, 'team',
            'notif.team.invitationExpired.title',
            'notif.team.invitationExpired.body',
            'team_invitation_accept', v_inv.id::text, false);

    -- Qui a proposé : sa proposition est tombée. Ne pas le lui dire, c'est
    -- la laisser croire qu'elle suit son cours.
    IF v_inv.proposed_by IS NOT NULL
       AND v_inv.proposed_by <> v_inv.invited_user_id THEN
      INSERT INTO public.user_notifications
        (user_id, library_id, category, title, body, link_type, link_id, is_read)
      VALUES (v_inv.proposed_by, v_inv.library_id, 'team',
              'notif.team.invitationExpired.title',
              'notif.team.invitationExpired.body',
              'team_invitation_ratify', v_inv.id::text, false);
    END IF;

    PERFORM public.fn_team_notify_event('team.invitation_expired', jsonb_build_object(
      'library_id', v_inv.library_id,
      'target_user_id', v_inv.invited_user_id,
      'actor_user_id', v_inv.proposed_by,
      'invitation_id', v_inv.id,
      'role_proposed', v_inv.role_proposed));

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END
$fn$;

ALTER FUNCTION public.fn_team_expire_invitations() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_expire_invitations()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_team_expire_invitations() TO service_role;

-- ---------------------------------------------------------------------
-- 3. Le cron du rappel
--
-- 09 h 35 UTC, dans le créneau matinal des autres relances d'équipe
-- (anarbib-cooptation-reminders-daily tourne à 09 h 25) et franchement à
-- l'écart de la péremption de 03 h 20 : un rappel se lit le matin, une
-- fermeture se fait la nuit.
-- ---------------------------------------------------------------------

DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'anarbib-team-invitations-remind') THEN
    PERFORM cron.unschedule('anarbib-team-invitations-remind');
  END IF;
  PERFORM cron.schedule(
    'anarbib-team-invitations-remind',
    '35 9 * * *',
    $job$SELECT public.fn_team_invitation_remind()$job$
  );
EXCEPTION
  WHEN undefined_table OR undefined_function OR invalid_schema_name OR insufficient_privilege THEN
    RAISE NOTICE 'pg_cron indisponible ici : planifier anarbib-team-invitations-remind manuellement';
END
$do$;

COMMIT;
