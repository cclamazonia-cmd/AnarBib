-- =========================================================================
-- Paquet INTERRUPTEUR-UNIQUE — toute bibliothèque a sa ligne de canal
-- =========================================================================
-- Date     : 2026-08-30
-- Chantier : commutateur d'envoi des bibliothèques
--
-- POURQUOI
--
-- Depuis le commit « Un interrupteur qui ne coupe rien n'est pas un
-- interrupteur », `library_mail_channels` est le SEUL commutateur d'envoi :
-- `active` coupe, `delivery_mode` choisit le transport, et c'est là que vit le
-- destinataire des avis (`admin_notification_email`). Mais rien ne garantissait
-- qu'une bibliothèque ait sa ligne. Le chemin de constitution en pose trois —
-- library_commons, library_email_identity, library_service_state — et oublie
-- celle-ci.
--
-- Conséquence concrète au 30/08/2026 : CIRA Marseille n'avait aucune ligne,
-- donc aucun contrôle de canal affiché dans son écran « Comunicações » (le bloc
-- entier est conditionné à l'existence de la ligne). Sa coordination n'avait
-- aucun moyen de voir ni de régler ses envois. Un interrupteur qu'on ne peut
-- pas atteindre ne vaut pas mieux qu'un interrupteur qui ne coupe rien.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS
--
-- Elle ne change le comportement d'AUCUN envoi. Les lignes créées le sont avec
-- les défauts de la table (`platform_shared`, `not_tested`, `active=true`) et
-- surtout avec `admin_notification_email` À NULL — ce qui reproduit exactement
-- l'état actuel : sans ligne, resolveLibraryNotificationContext repliait déjà
-- sur ces mêmes valeurs et sur l'ADMIN_EMAIL du réseau
-- (cf. fallbackLibraryNotificationContext, _shared/context/library-notification-context.ts),
-- et normalizeLibraryNotificationContext fait le même repli quand la colonne est
-- nulle. Remplir cette adresse depuis le contact public de la biblio ferait
-- partir des avis vers un tiers qui n'en recevait pas : ce n'est pas à une
-- migration de le décider, c'est à la coordination de la biblio de le saisir
-- depuis son écran.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. L'invariant, porté par un trigger plutôt que par un chemin de création
-- -------------------------------------------------------------------------
-- Un trigger sur `libraries` couvre TOUS les chemins — constitution, seed,
-- création par un admin réseau, reprise manuelle — là où patcher la seule RPC
-- de constitution laisserait rentrer les autres. C'est la différence entre un
-- invariant et une habitude.
--
-- SECURITY DEFINER obligatoire : `library_mail_channels` est sous RLS
-- (user_can_manage_library_notifications), et au moment où la bibliothèque est
-- créée la personne qui la crée n'en est pas encore membre — l'INSERT du
-- trigger serait refusé, et la création de la bibliothèque échouerait avec elle.
CREATE OR REPLACE FUNCTION public.fn_library_ensure_mail_channel()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  INSERT INTO public.library_mail_channels (library_id)
  VALUES (NEW.id)
  ON CONFLICT (library_id) DO NOTHING;
  RETURN NULL;  -- AFTER trigger : la valeur de retour est ignorée
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_library_ensure_mail_channel() FROM PUBLIC;

COMMENT ON FUNCTION public.fn_library_ensure_mail_channel() IS
  'Garantit qu''une bibliothèque a sa ligne library_mail_channels dès sa création. '
  'SECURITY DEFINER car la table est sous RLS et la personne qui crée la biblio '
  'n''en est pas encore membre. Valeurs par défaut de la table, emails à NULL : '
  'aucun changement de comportement d''envoi, cf. en-tête de la migration.';

DROP TRIGGER IF EXISTS trg_library_ensure_mail_channel ON public.libraries;
CREATE TRIGGER trg_library_ensure_mail_channel
  AFTER INSERT ON public.libraries
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_library_ensure_mail_channel();

-- -------------------------------------------------------------------------
-- 2. Rattrapage des bibliothèques déjà créées
-- -------------------------------------------------------------------------
-- Idempotent, et sans effet en CI (schéma reconstruit sans données) : la
-- migration ne porte donc AUCUNE assertion sur les données, seulement la
-- structure. Le contrôle fonctionnel vit dans tests/sql.
INSERT INTO public.library_mail_channels (library_id)
SELECT l.id
FROM public.libraries l
WHERE NOT EXISTS (
  SELECT 1 FROM public.library_mail_channels c WHERE c.library_id = l.id
)
ON CONFLICT (library_id) DO NOTHING;

-- -------------------------------------------------------------------------
-- 3. Vérification de structure (doctrine)
-- -------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    WHERE c.relname = 'libraries'
      AND t.tgname = 'trg_library_ensure_mail_channel'
      AND NOT t.tgisinternal
  ) THEN
    RAISE EXCEPTION 'trg_library_ensure_mail_channel absent apres migration';
  END IF;

  -- Vacuement vrai en CI (aucune bibliotheque) ; en prod, prouve le rattrapage.
  IF EXISTS (
    SELECT 1 FROM public.libraries l
    WHERE NOT EXISTS (
      SELECT 1 FROM public.library_mail_channels c WHERE c.library_id = l.id
    )
  ) THEN
    RAISE EXCEPTION 'des bibliotheques restent sans ligne library_mail_channels';
  END IF;
END $$;

COMMIT;
