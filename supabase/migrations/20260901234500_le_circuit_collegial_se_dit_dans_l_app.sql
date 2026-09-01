-- =====================================================================
-- 20260901234500_le_circuit_collegial_se_dit_dans_l_app.sql
--
-- Objet : donner au circuit collégial une notification IN-APP, pour qu'il
--         cesse de dépendre du seul courriel pour avancer.
--
-- Constat (01/09/2026) : les événements `team.*` partent dans
--   `team_notification_outbox` -> `notify-event` -> e-mail, et **rien
--   d'autre**. Les huit fonctions qui écrivent dans `user_notifications`
--   concernent les cercles, le RGPD, la gazette, la lettre, les
--   consultations, les réservations et les événements de biblio : aucune
--   n'est un événement de gouvernance. Pour apprendre qu'une proposition
--   attend son endossement, il fallait donc recevoir le mail, ou aller
--   regarder l'écran d'équipe par hasard.
--
-- Pourquoi c'est devenu grave le jour même : depuis GOUV-13 l'accueil T1
--   passe aussi par ce circuit, et depuis GOUV-11 le saut également. TOUTE
--   nomination au staff dépendait donc d'un canal sortant qu'on ne maîtrise
--   pas — coupé sur les biblios de test, en spam ailleurs, sur une adresse
--   périmée parfois. Et `fn_team_expire_invitations` (20260826120000) ferme
--   proprement au bout de 30 jours : une proposition pouvait naître, être
--   ignorée et mourir sans qu'aucun être humain n'ait su qu'elle existait.
--   Le cron avait raison ; c'est le silence qui était fautif.
--
-- Choix de conception :
--
--   * TRIGGER sur la table, et non modification des RPC. La notification
--     in-app ne doit surtout pas dépendre du chemin du mail — c'est tout
--     l'objet. Et le déclencheur attrape AUSSI les chemins futurs : toute
--     invitation créée ou passée à `ready`, par quelque fonction que ce
--     soit, se dira dans l'app. Motif repris de
--     `fn_replicate_reserva_pronta_to_inapp`, qui fait exactement cela pour
--     la circulation.
--   * `title` et `body` portent des CLÉS i18n, pas du texte : la cloche
--     traduit au rendu, dans la langue de qui lit. Aucune langue n'est
--     figée à l'insertion (DOC-I18N-1).
--   * Destinataires distincts selon l'étape, parce que le geste attendu
--     n'est pas le même : à la proposition, celles et ceux qui peuvent
--     ENDOSSER ; au quorum atteint, la seule personne qui peut ACCEPTER.
--
-- Ce que ça ne fait pas : aucun rappel avant péremption. C'est un autre
--   sujet — il rouvre la doctrine des relances — et il est laissé ouvert
--   dans GOUV-17 plutôt que bâclé ici.
--
-- Rollback : `_rollback_20260901234500_...sql`.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Le déclencheur
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_team_invitation_notify_inapp()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  -- ── Proposition déposée : prévenir qui peut l'endosser ──
  --
  -- Le staff actif de la biblio, moins deux personnes : celle qui propose
  -- (elle sait, et son endossement est déjà enregistré d'office) et celle
  -- qui est visée (elle ne ratifie pas sa propre invitation — la RPC le lui
  -- refuse explicitement ; lui envoyer « à endosser » serait un mensonge).
  IF TG_OP = 'INSERT' AND NEW.status = 'pending_ratification' THEN
    INSERT INTO public.user_notifications
      (user_id, library_id, category, title, body, link_type, link_id, is_read)
    SELECT DISTINCT m.user_id, NEW.library_id, 'team',
           'notif.team.invitationProposed.title',
           'notif.team.invitationProposed.body',
           'team_invitation_ratify', NEW.id::text, false
      FROM public.user_library_memberships m
     WHERE m.library_id = NEW.library_id
       AND m.status = 'active'
       AND m.role IN ('librarian', 'coordenador')
       AND m.user_id <> NEW.invited_user_id
       AND m.user_id IS DISTINCT FROM NEW.proposed_by;
    RETURN NEW;
  END IF;

  -- ── Quorum atteint : prévenir la personne concernée, elle seule ──
  IF TG_OP = 'UPDATE' AND NEW.status = 'ready'
     AND OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public.user_notifications
      (user_id, library_id, category, title, body, link_type, link_id, is_read)
    VALUES (NEW.invited_user_id, NEW.library_id, 'team',
            'notif.team.invitationReady.title',
            'notif.team.invitationReady.body',
            'team_invitation_accept', NEW.id::text, false);
    RETURN NEW;
  END IF;

  RETURN NEW;
END
$fn$;

ALTER FUNCTION public.fn_team_invitation_notify_inapp() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_invitation_notify_inapp()
  FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION public.fn_team_invitation_notify_inapp() IS
  'Double les événements du circuit collégial d''une notification in-app (user_notifications), pour que le circuit ne dépende plus du seul e-mail. Déclencheur, jamais appelée directement. Cf. GOUV-17 et migration 20260901234500.';

DROP TRIGGER IF EXISTS trg_team_invitation_notify_inapp_ins ON public.library_team_invitations;
CREATE TRIGGER trg_team_invitation_notify_inapp_ins
AFTER INSERT ON public.library_team_invitations
FOR EACH ROW EXECUTE FUNCTION public.fn_team_invitation_notify_inapp();

DROP TRIGGER IF EXISTS trg_team_invitation_notify_inapp_upd ON public.library_team_invitations;
CREATE TRIGGER trg_team_invitation_notify_inapp_upd
AFTER UPDATE OF status ON public.library_team_invitations
FOR EACH ROW EXECUTE FUNCTION public.fn_team_invitation_notify_inapp();

-- ---------------------------------------------------------------------
-- 2. Rattrapage des invitations déjà vivantes
--
-- Le déclencheur ne vaut que pour l'avenir. Les propositions en cours au
-- moment du déploiement resteraient muettes — or c'est précisément la
-- situation qui a fait découvrir le trou. On les rattrape ici, sans
-- doublon possible : l'insertion est conditionnée à l'absence d'une
-- notification portant déjà ce `link_id`.
-- ---------------------------------------------------------------------

DO $rat$
DECLARE
  v_n integer;
BEGIN
  INSERT INTO public.user_notifications
    (user_id, library_id, category, title, body, link_type, link_id, is_read)
  SELECT DISTINCT m.user_id, i.library_id, 'team',
         'notif.team.invitationProposed.title',
         'notif.team.invitationProposed.body',
         'team_invitation_ratify', i.id::text, false
    FROM public.library_team_invitations i
    JOIN public.user_library_memberships m
      ON m.library_id = i.library_id
     AND m.status = 'active'
     AND m.role IN ('librarian', 'coordenador')
     AND m.user_id <> i.invited_user_id
     AND m.user_id IS DISTINCT FROM i.proposed_by
   WHERE i.status = 'pending_ratification'
     AND NOT EXISTS (
       SELECT 1 FROM public.user_notifications n
        WHERE n.link_type = 'team_invitation_ratify'
          AND n.link_id = i.id::text
          AND n.user_id = m.user_id
     );
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'rattrapage in-app : % notification(s) posee(s) sur les invitations en attente', v_n;

  INSERT INTO public.user_notifications
    (user_id, library_id, category, title, body, link_type, link_id, is_read)
  SELECT i.invited_user_id, i.library_id, 'team',
         'notif.team.invitationReady.title',
         'notif.team.invitationReady.body',
         'team_invitation_accept', i.id::text, false
    FROM public.library_team_invitations i
   WHERE i.status = 'ready'
     AND NOT EXISTS (
       SELECT 1 FROM public.user_notifications n
        WHERE n.link_type = 'team_invitation_accept'
          AND n.link_id = i.id::text
          AND n.user_id = i.invited_user_id
     );
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'rattrapage in-app : % notification(s) posee(s) sur les invitations pretes', v_n;
END
$rat$;

COMMIT;
