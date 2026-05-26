-- =============================================================================
-- Migration #153.C — chantier C (corrections post-audit #153)
-- =============================================================================
-- Objet : ajouter la colonne logo_url à la table public.libraries, afin que le
--         logo d'une bibliothèque dans ses mails soit résolu depuis son
--         contexte (la base) et non depuis un objet codé en dur dans le code
--         source de l'Edge Function register.
--
-- Contexte (constat TR-6.2b de l'audit #153, sévérité doctrinale) :
-- Les logos de bibliothèques étaient résolus dans register/index.ts via l'objet
-- LIBRARY_MAIL_ASSETS, qui codait en dur les logos de deux biblios (blmf, btl).
-- Conséquence : une nouvelle bibliothèque rejoignant le réseau n'aurait pas son
-- logo dans ses mails sans édition du code source et redéploiement — frein
-- direct à l'extensibilité fédérative d'AnarBib.
--
-- Cette migration est le premier des deux volets du chantier C. Elle crée et
-- renseigne la colonne. Le second volet (séparé, déployé seulement APRÈS que
-- cette migration soit appliquée) modifie register/index.ts pour lire
-- libraries.logo_url au lieu de LIBRARY_MAIL_ASSETS, et retire l'objet en dur.
-- Séquencement migration-d'abord : le code qui lit logo_url ne doit pas être
-- déployé tant que la colonne n'existe pas (sinon le select de register plante).
--
-- Hors périmètre : le logo *réseau* AnarBib reste codé en dur (constat TR-6.2a,
-- validé non-constat — objet unique et invariant). Cette migration ne concerne
-- que les logos *de bibliothèques*.
--
-- Pas de migration de données au sens strict : la colonne n'existait pas, il
-- n'y a aucune donnée préexistante. Les UPDATE ci-dessous reportent dans la base
-- les deux URLs jusqu'ici codées en dur dans LIBRARY_MAIL_ASSETS.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Création de la colonne
-- -----------------------------------------------------------------------------
-- Nullable : une bibliothèque sans logo est un état légitime. Le rendu des mails
-- (buildLogoTable, register) gère déjà le cas vide en omettant la cellule logo.

ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS logo_url text;

COMMENT ON COLUMN public.libraries.logo_url IS
  'URL du logo de la bibliothèque, affiché dans ses mails. NULL = pas de logo (repli : cellule omise). Introduit par le chantier C de l''audit #153 pour résoudre les logos depuis le contexte plutôt qu''en dur dans le code.';

-- -----------------------------------------------------------------------------
-- 2. Renseignement des bibliothèques connues
-- -----------------------------------------------------------------------------
-- Reprise des deux URLs jusqu'ici dans LIBRARY_MAIL_ASSETS (register/index.ts).
-- Ciblage par id (clé primaire) — aucune ambiguïté. Slug indiqué en commentaire.

-- blmf — Biblioteca Libertária Maxwell Ferreira
UPDATE public.libraries
  SET logo_url = 'https://cclamazonia.noblogs.org/files/2026/03/logo_detoure_BLMF.png'
  WHERE id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca';

-- btl — Biblioteca Terra Livre
UPDATE public.libraries
  SET logo_url = 'https://cclamazonia.noblogs.org/files/2026/03/logo-btl.png'
  WHERE id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a';

-- blt-test-informal — bibliothèque de test, appelée à disparaître de la base :
-- logo_url laissée à NULL volontairement. Sert au passage de cas réel pour
-- vérifier le comportement de repli (logo absent).

-- -----------------------------------------------------------------------------
-- 3. Vérification en fin de transaction
-- -----------------------------------------------------------------------------
-- RAISE EXCEPTION ici => rollback automatique de toute la migration.

DO $verify$
DECLARE
  v_blmf_logo text;
  v_btl_logo  text;
BEGIN
  -- La colonne doit exister.
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'libraries'
      AND column_name = 'logo_url'
  ) THEN
    RAISE EXCEPTION '#153.C : la colonne libraries.logo_url n''existe pas après migration.';
  END IF;

  -- blmf et btl doivent avoir une logo_url non vide.
  SELECT logo_url INTO v_blmf_logo FROM public.libraries
    WHERE id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  SELECT logo_url INTO v_btl_logo FROM public.libraries
    WHERE id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a';

  IF v_blmf_logo IS NULL OR length(trim(v_blmf_logo)) = 0 THEN
    RAISE EXCEPTION '#153.C : logo_url de blmf non renseignée.';
  END IF;
  IF v_btl_logo IS NULL OR length(trim(v_btl_logo)) = 0 THEN
    RAISE EXCEPTION '#153.C : logo_url de btl non renseignée.';
  END IF;

  RAISE NOTICE '#153.C : migration vérifiée — colonne logo_url créée, blmf et btl renseignées.';
END;
$verify$;
