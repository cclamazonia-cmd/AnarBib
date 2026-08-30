-- =========================================================================
-- Paquet IDENTITE-MAIL — on retire la copie et le réglage mort
-- =========================================================================
-- Date     : 2026-08-30
-- Chantier : dédoublonnage de l'identité mail des bibliothèques
-- Ref      : 20260830193050 (GRANT à service_role sur la vue)
--            f4c35537 (register lit désormais api.library_email_identity)
--
-- PRÉ-REQUIS DE DÉPLOIEMENT, à ne pas défaire : ce paquet ne peut partir
-- qu'une fois la nouvelle `register` EN LIGNE, pas seulement poussée. La
-- version précédente lisait `public.library_email_identity` ; la supprimer
-- avant son remplacement casserait toute inscription. Dans ci.yml les edge
-- functions sont déployées avant `supabase db push`, donc un paquet qui
-- change la fonction ET le schéma est sûr ; celui-ci ne change que le schéma,
-- d'où l'attente explicite du marqueur `deployed-functions`.
--
-- CE QUI PART, ET POURQUOI
--
-- 1. `library_commons.email_delivery_mode` (normal|test_only|disabled) n'a
--    JAMAIS été appliqué nulle part : ni les fonctions notify-*, qui passent
--    toutes par safeSendEmail → transportDisabledReason, ni register. L'écran
--    l'affichait pourtant comme un sélecteur « Modo de envio », au-dessus des
--    vrais champs du canal — la BTL a reçu ses notifications pendant des mois
--    avec le réglage sur « test_only ». Le commutateur réel est
--    `library_mail_channels` (`active` coupe, `delivery_mode` choisit le
--    transport) ; l'écran le pilote depuis le 30/08. La colonne n'a plus ni
--    lecteur ni écrivain : elle part, pour qu'aucune relecture future ne la
--    reprenne pour un réglage.
--
-- 2. `public.library_email_identity` était une TABLE, copie figée de champs
--    que `api.library_email_identity` DÉRIVE de libraries ⋈ library_commons.
--    Rien ne les synchronisait, et la dérive était constatée : la table
--    portait encore, pour la BLMF et la BTL, un `logo_url` pointant vers
--    l'ancien site de staging sur github.io. Plus personne ne la lit.
--
--    À ne pas confondre avec le cas `my_access` / `my_session_context`
--    (commit 776b5441) : là, `public` est une PROJECTION de `api`, un seul
--    foyer et une façade — rien à réconcilier. Ici c'était bien une copie.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. La vue lâche la colonne morte
-- -------------------------------------------------------------------------
-- DROP + CREATE et non CREATE OR REPLACE : on ne peut pas retirer une colonne
-- d'une vue par remplacement. Les droits et le commentaire ne survivent pas au
-- DROP, ils sont reposés juste après — c'est la partie qu'on oublie.
DROP VIEW IF EXISTS api.library_email_identity;

CREATE VIEW api.library_email_identity AS
  SELECT l.id   AS library_id,
         l.slug AS library_slug,
         l.name AS library_name,
         c.display_name,
         c.short_name,
         c.contact_email,
         c.reply_to_email,
         c.postal_address,
         c.logo_url,
         c.logo_file_key,
         c.is_test_mode,
         c.is_active
    FROM public.libraries l
    LEFT JOIN public.library_commons c ON c.library_id = l.id
   WHERE l.is_active = true;

GRANT SELECT ON api.library_email_identity TO service_role;

COMMENT ON VIEW api.library_email_identity IS
  'Identite d''expedition par bibliotheque, derivee de libraries ⋈ library_commons, '
  'lue par les fonctions d''envoi de courriel (service_role uniquement). Reste SANS '
  'security_invoker : elle est lue par un role de service, hors de toute session '
  'utilisateur. N''est accordee ni a anon ni a authenticated, et ne doit jamais '
  'l''etre — elle reconstitue l''annuaire des bibliotheques (adresses de contact et '
  'postales). Si un GRANT applicatif lui etait accorde un jour, il faudrait la passer '
  'en security_invoker dans le meme mouvement. La colonne email_delivery_mode a ete '
  'retiree le 30/08/2026 : elle n''etait appliquee nulle part, le commutateur reel '
  'est library_mail_channels. Paquet API-VUES-DEFINER du 29/08/2026.';

-- -------------------------------------------------------------------------
-- 2. La colonne morte s'en va
-- -------------------------------------------------------------------------
ALTER TABLE public.library_commons DROP COLUMN IF EXISTS email_delivery_mode;

-- -------------------------------------------------------------------------
-- 3. La copie figée s'en va
-- -------------------------------------------------------------------------
DROP TABLE IF EXISTS public.library_email_identity;

-- -------------------------------------------------------------------------
-- 4. Vérification (doctrine)
-- -------------------------------------------------------------------------
DO $$
DECLARE v_n int;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema='public' AND table_name='library_commons'
                AND column_name='email_delivery_mode') THEN
    RAISE EXCEPTION 'library_commons.email_delivery_mode est toujours la';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
              WHERE n.nspname='public' AND c.relname='library_email_identity') THEN
    RAISE EXCEPTION 'public.library_email_identity est toujours la';
  END IF;

  IF NOT has_table_privilege('service_role', 'api.library_email_identity', 'SELECT') THEN
    RAISE EXCEPTION 'la vue recreee n''est plus lisible par service_role';
  END IF;

  SELECT count(*) INTO v_n FROM information_schema.role_table_grants
   WHERE table_schema='api' AND table_name='library_email_identity'
     AND grantee IN ('anon','authenticated');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'la vue recreee est accordee a % role(s) applicatif(s)', v_n;
  END IF;

  IF coalesce(obj_description('api.library_email_identity'::regclass, 'pg_class'), '')
     NOT LIKE '%API-VUES-DEFINER%' THEN
    RAISE EXCEPTION 'le commentaire de la vue a perdu son marqueur API-VUES-DEFINER';
  END IF;
END $$;

COMMIT;
