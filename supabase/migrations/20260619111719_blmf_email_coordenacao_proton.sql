-- =====================================================================
-- Migration : bascule de la coordination e-mail de la BLMF vers sa
--             boite dediee blmf.belem@proton.me.
--
-- Date de conception : 2026-06-19
-- Auteur  : Xavier VAN WELDEN et AnarBib contributors
-- Session : Separation boite coordination BLMF / CCLA
--
-- Contexte : la Biblioteca Libertaria Maxwell Ferreira (slug=blmf) utilisait
-- la boite generale de son collectif parent, le CCLA
-- (cclamazonia@gmail.com), pour TOUT son routage e-mail de coordination.
-- Une boite dediee blmf.belem@proton.me a ete creee pour distinguer la
-- BLMF du CCLA. On repointe les 6 champs de routage/contact de la SEULE
-- BLMF.
--
-- NON modifie (legitime) : library_commons.affiliation_label et
-- website_url, qui referencent le CCLA en tant que collectif parent.
-- Les secrets Edge Function RESEAU (ADMIN_EMAIL, ANARBIB_ADMIN_EMAIL)
-- pilotent la coordination du RESEAU AnarBib, pas la BLMF : hors de
-- cette migration.
--
-- Idempotent : ciblage par slug='blmf' ; rejouer reecrit les memes
-- valeurs sans effet de bord.
-- Reversible : repasser 'blmf.belem@proton.me' -> 'cclamazonia@gmail.com'.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  v_lib uuid;
  v_new text := 'blmf.belem@proton.me';
BEGIN
  SELECT id INTO v_lib FROM public.libraries WHERE slug = 'blmf';
  IF v_lib IS NULL THEN
    RAISE EXCEPTION 'BLMF introuvable (slug=blmf)';
  END IF;

  -- 1. Identite d'envoi + reply-to technique
  UPDATE public.library_commons
     SET contact_email  = v_new,
         reply_to_email = v_new
   WHERE library_id = v_lib;

  -- 2. Canaux mail : copie admin + rapport hebdomadaire
  UPDATE public.library_mail_channels
     SET admin_notification_email = v_new,
         weekly_report_email      = v_new
   WHERE library_id = v_lib;

  -- 3. Profil de notification : reply-to
  UPDATE public.library_notification_profiles
     SET reply_to_email = v_new
   WHERE library_id = v_lib;

  -- 4. Contact reseau confidentiel (cooperation PEB)
  UPDATE public.library_contact_profiles
     SET contact_email = v_new
   WHERE library_id = v_lib;

  -- 5. Contact public (OPAC / annuaire PUBLIB)
  UPDATE public.library_public_contact
     SET public_email = v_new
   WHERE library_id = v_lib;

  -- 6. Mode de livraison : reply-to LOCAL. L'envoi part toujours du
  --    domaine partage (notifications.anarbib.org), mais le reply-to des
  --    mails aux lectrices devient la boite BLMF (sinon les reponses
  --    partent vers le domaine expediteur). Cf. resolveMailRouting :
  --    rte n'est emis que si delivery_mode IN
  --    (platform_shared_local_reply, library_own_transport).
  UPDATE public.library_mail_channels
     SET delivery_mode = 'platform_shared_local_reply'
   WHERE library_id = v_lib
     AND delivery_mode = 'platform_shared';

  RAISE NOTICE 'BLMF coordination e-mail repointee vers % (lib %)', v_new, v_lib;
END $$;

-- Verification : plus aucune trace de l'ancienne boite CCLA sur la BLMF.
DO $$
DECLARE
  v_lib uuid;
  v_bad int;
  v_old text := 'cclamazonia@gmail.com';
BEGIN
  SELECT id INTO v_lib FROM public.libraries WHERE slug = 'blmf';

  SELECT
      (SELECT count(*) FROM public.library_commons
         WHERE library_id = v_lib
           AND (contact_email = v_old OR reply_to_email = v_old))
    + (SELECT count(*) FROM public.library_mail_channels
         WHERE library_id = v_lib
           AND (admin_notification_email = v_old OR weekly_report_email = v_old))
    + (SELECT count(*) FROM public.library_notification_profiles
         WHERE library_id = v_lib AND reply_to_email = v_old)
    + (SELECT count(*) FROM public.library_contact_profiles
         WHERE library_id = v_lib AND contact_email = v_old)
    + (SELECT count(*) FROM public.library_public_contact
         WHERE library_id = v_lib AND public_email = v_old)
    INTO v_bad;

  IF v_bad > 0 THEN
    RAISE EXCEPTION 'BLMF : % champ(s) pointent encore vers %', v_bad, v_old;
  END IF;
  RAISE NOTICE 'OK BLMF : aucun champ ne pointe plus vers %', v_old;
END $$;

COMMIT;
