-- =====================================================================
-- Migration : BLMF — repointer library_email_identity vers proton
--             (complète la migration 20260619111719 qui l'avait oubliée).
--
-- Date    : 2026-06-22
-- Auteur  : Claude (livré en fichier, appliqué par Forgejo / supabase db push)
-- Chantier: séparation boîte coordination BLMF / CCLA — Suite (b)
--
-- Contexte : 20260619111719_blmf_email_coordenacao_proton a basculé 6 tables
-- de routage de la BLMF vers blmf.belem@proton.me, MAIS a oublié
-- public.library_email_identity (contact_email + reply_to_email restés à
-- cclamazonia@gmail.com). Or c'est ce contact_email que vise la notification
-- « Novo cadastro » (cf. register/index.ts qui lit library_email_identity) →
-- elle partait encore vers l'ancienne boîte CCLA. On complète ici.
--
-- Idempotent : ciblage par library_slug='blmf' ; rejouer réécrit la même valeur.
-- Réversible : repasser 'blmf.belem@proton.me' -> 'cclamazonia@gmail.com'.
-- Note : l'adresse postale (postal_address) reste hors scope (inchangée).
-- =====================================================================

BEGIN;

DO $$
DECLARE
  v_new text := 'blmf.belem@proton.me';
BEGIN
  UPDATE public.library_email_identity
     SET contact_email  = v_new,
         reply_to_email = v_new
   WHERE library_slug = 'blmf';

  IF NOT FOUND THEN
    -- Base sans la BLMF (CI sql-tests / instance neuve) : no-op au lieu d'échouer.
    RAISE NOTICE 'library_email_identity blmf absente — migration sans effet';
  ELSE
    RAISE NOTICE 'BLMF library_email_identity repointée vers %', v_new;
  END IF;
END $$;

-- Vérification : plus aucune trace de l'ancienne boîte CCLA sur ce champ.
DO $$
DECLARE
  v_bad int;
  v_old text := 'cclamazonia@gmail.com';
BEGIN
  SELECT count(*) INTO v_bad
  FROM public.library_email_identity
  WHERE library_slug = 'blmf'
    AND (contact_email = v_old OR reply_to_email = v_old);

  IF v_bad > 0 THEN
    RAISE EXCEPTION 'BLMF : library_email_identity pointe encore vers % (% champ[s])', v_old, v_bad;
  END IF;
  RAISE NOTICE 'OK BLMF : library_email_identity ne pointe plus vers %', v_old;
END $$;

COMMIT;
