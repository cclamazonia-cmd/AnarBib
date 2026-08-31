-- =========================================================================
-- Le règlement affiché dans un courriel est celui de la bibliothèque
-- =========================================================================
-- Date     : 2026-08-31
-- Chantier : pied de page des courriels (item F7)
--
-- CE QUI NE MARCHAIT PAS
--
-- `footerPadrao` affichait un lien « Règlement » à partir de la variable
-- d'environnement `REGIMENTO_URL`. Elle est vide, et ses deux replis
-- (`ANARBIB_REGIMENTO_URL`, `NETWORK_REGIMENTO_URL`) n'existent pas du tout :
-- la constante vaut la chaîne vide, la condition est fausse, et la ligne n'a
-- **jamais** été affichée dans un seul message.
--
-- CE QUE LA VARIABLE SUPPOSAIT, ET QUI EST FAUX
--
-- Un règlement unique, du réseau. Or AnarBib n'en a pas et n'en aura pas :
-- **ce sont les bibliothèques qui définissent le leur**. Une variable globale
-- ne pouvait donc pas porter la bonne valeur — au mieux elle en aurait porté
-- une fausse pour toutes sauf une.
--
-- CE QUE FAIT CE PAQUET
--
-- Les données existent déjà : `library_regulation_documents` porte, par
-- bibliothèque, le document publié dans le bucket public
-- `library-regimentos-public`. La vue de contexte les expose désormais, et le
-- pied de page n'affichera le lien que pour les bibliothèques qui ont un
-- règlement actif et publié. Les autres n'auront pas de ligne vide ni de lien
-- mort — elles n'auront rien, ce qui est exact.
--
-- On expose le SEAU et le CHEMIN, pas une URL construite : l'adresse publique
-- se fabrique côté fonction, avec le client qui connaît déjà l'hôte du projet.
-- Écrire l'hôte dans une vue, c'est le figer dans la base.
--
-- Le choix du document quand il y en a plusieurs : le plus récemment publié
-- parmi les actifs. La BLMF en a deux, dont un seul actif — mais la règle doit
-- valoir sans dépendre de ce fait.
-- =========================================================================

BEGIN;

-- CORRECTIF DU 31/08, une heure apres la premiere version de ce fichier.
--
-- `WITH (security_invoker = true)` N'ETAIT PAS LA, et son absence n'est pas
-- neutre : `CREATE OR REPLACE VIEW` REINITIALISE les options de la vue quand la
-- clause WITH est omise. La vue etait `security_invoker` depuis le baseline ;
-- ma premiere version l'a donc fait retomber en SECURITY DEFINER — c'est-a-dire
-- lue avec les droits du proprietaire, RLS des tables sous-jacentes contournee.
--
-- Or cette vue est accordee en SELECT a `anon` et `authenticated`. Pendant une
-- heure, n'importe quel visiteur NON CONNECTE pouvait donc lire, pour chaque
-- bibliotheque du reseau : adresse de reponse, adresse de notification admin,
-- adresse du rapport hebdomadaire, adresse des alertes graves. L'annuaire
-- complet des contacts, exactement le trou que l'audit de juillet avait ferme.
--
-- Referme en production par un ALTER VIEW des la detection ; la clause est
-- posee ici pour que le rejeu depuis zero ne repasse jamais par l'etat definer.
--
-- LA LECON : ajouter une colonne a une vue n'est pas une operation anodine.
-- CREATE OR REPLACE preserve les DROITS mais pas les OPTIONS — donc il faut
-- reecrire la clause WITH a chaque fois, sous peine de changer le modele de
-- securite en croyant ne toucher qu'a la liste des colonnes.
--
-- C'est le T7 de tests/sql/grants_herites_tests.sql qui l'a vu, en refusant
-- toute vue hors des policies lisible par anon ou authenticated. Le garde-fou
-- a fait exactement son travail.
CREATE OR REPLACE VIEW public.v_library_notification_context
WITH (security_invoker = true) AS
 SELECT l.id AS library_id,
    l.slug,
    l.name AS library_name,
    l.short_name AS library_short_name,
    p.sender_display_name,
    p.reply_to_name,
    p.reply_to_email,
    p.signature_short,
    p.signature_short_i18n,
    p.footer_local,
    p.use_library_name_as_sender,
    p.use_library_logo,
    p.sender_visible_email,
    pol.reservation_created_enabled,
    pol.reservation_status_enabled,
    pol.reservation_workflow_enabled,
    pol.local_consultation_enabled,
    pol.loan_lifecycle_enabled,
    pol.loan_reminders_enabled,
    pol.loan_overdue_enabled,
    pol.profile_restriction_enabled,
    pol.mid_loan_message_enabled,
    pol.reading_recommendations_enabled,
    pol.admin_copy_reservations_enabled,
    pol.admin_copy_loans_enabled,
    pol.tech_alerts_enabled,
    pol.task_alerts_enabled,
    ch.delivery_mode,
    ch.admin_notification_email,
    ch.weekly_report_email,
    ch.severe_alert_email,
    ch.transport_state,
    ch.transport_channel,
    ch.last_tested_at,
    ch.active AS channel_active,
    lc.logo_url,
    lc.logo_file_key,
    l.default_locale,
    -- Les deux colonnes neuves vont EN FIN de liste : CREATE OR REPLACE VIEW
    -- sait ajouter des colonnes a la fin, jamais en inserer au milieu. Postgres
    -- refuse d'ailleurs clairement — « cannot change name of view column ».
    reg.storage_bucket AS regulation_bucket,
    reg.storage_path_public AS regulation_path
   FROM libraries l
     LEFT JOIN library_notification_profiles p ON p.library_id = l.id
     LEFT JOIN library_notification_policies pol ON pol.library_id = l.id
     LEFT JOIN library_mail_channels ch ON ch.library_id = l.id
     LEFT JOIN library_commons lc ON lc.library_id = l.id
     LEFT JOIN LATERAL (
       SELECT d.storage_bucket, d.storage_path_public
         FROM library_regulation_documents d
        WHERE d.library_id = l.id
          AND d.is_active
          AND d.publication_status = 'published'
          AND nullif(btrim(coalesce(d.storage_path_public, '')), '') IS NOT NULL
        ORDER BY d.published_at DESC NULLS LAST, d.id DESC
        LIMIT 1
     ) reg ON true;

COMMENT ON VIEW public.v_library_notification_context IS
  'Contexte d''envoi d''une bibliotheque, lu par toutes les fonctions notify-*. '
  'Depuis le 31/08/2026 elle porte aussi regulation_bucket et regulation_path : '
  'le reglement PUBLIE et ACTIF de la bibliotheque, pour que le pied de page des '
  'courriels renvoie au sien et non a un reglement de reseau qui n''existe pas. '
  'On expose le seau et le chemin, pas une URL : l''hote du projet se resout cote '
  'fonction, il n''a rien a faire dans une vue.';

-- -------------------------------------------------------------------------
-- Vérification (doctrine)
-- -------------------------------------------------------------------------
DO $$
DECLARE v_n int; v_bucket text; v_path text;
BEGIN
  SELECT count(*) INTO v_n FROM information_schema.columns
   WHERE table_schema='public' AND table_name='v_library_notification_context'
     AND column_name IN ('regulation_bucket','regulation_path');
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'les deux colonnes de reglement ne sont pas exposees (%)', v_n;
  END IF;

  -- Le modele de securite de la vue, garde ici parce que c'est precisement ce
  -- qu'une premiere version de ce fichier avait perdu sans le dire.
  IF coalesce((SELECT option_value FROM pg_class c
                 JOIN pg_namespace ns ON ns.oid = c.relnamespace
                 CROSS JOIN pg_options_to_table(c.reloptions)
                WHERE ns.nspname='public' AND c.relname='v_library_notification_context'
                  AND option_name='security_invoker'), 'false') <> 'true' THEN
    RAISE EXCEPTION 'la vue a perdu security_invoker : elle serait lue avec les droits du proprietaire, RLS contournee, alors qu''elle est accordee a anon';
  END IF;

  -- Une biblio par ligne, toujours : le LATERAL ne doit pas dupliquer.
  SELECT count(*) INTO v_n FROM public.v_library_notification_context;
  IF v_n <> (SELECT count(*) FROM public.libraries) THEN
    RAISE EXCEPTION 'la vue rend % lignes pour % bibliotheques', v_n, (SELECT count(*) FROM public.libraries);
  END IF;

  -- Le seau annonce doit etre public, sinon le lien serait mort pour la lectrice.
  FOR v_bucket, v_path IN
    SELECT regulation_bucket, regulation_path FROM public.v_library_notification_context
     WHERE regulation_path IS NOT NULL
  LOOP
    IF NOT EXISTS (SELECT 1 FROM storage.buckets b WHERE b.id = v_bucket AND b.public) THEN
      RAISE EXCEPTION 'le reglement pointe vers un seau non public : %', v_bucket;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM storage.objects o WHERE o.bucket_id = v_bucket AND o.name = v_path) THEN
      RAISE NOTICE 'reglement annonce mais fichier absent du seau : %/%', v_bucket, v_path;
    END IF;
  END LOOP;
END $$;

COMMIT;
