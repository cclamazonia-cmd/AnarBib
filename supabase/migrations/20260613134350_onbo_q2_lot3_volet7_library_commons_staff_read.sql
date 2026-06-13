-- ════════════════════════════════════════════════════════════════════════════
-- ONBO-Q2 Lot 3 — Volet 7 « E-mails » : lecture staff de library_commons
-- ════════════════════════════════════════════════════════════════════════════
-- L'éditeur du volet 7 lit/écrit l'identité d'envoi e-mail sur library_commons
-- (contact_email, reply_to_email, email_delivery_mode). L'UPDATE est déjà ouvert
-- au staff (policy library_commons_staff_update, basée sur user_has_library_staff_role).
--
-- MAIS le SELECT (library_commons_public_read) passe par fn_library_visible_to_caller,
-- qui exige l.is_active = true à la racine → une biblio PRÉ-ACTIVE est illisible même
-- par sa coordinatrice : l'éditeur ne peut pas charger la ligne. C'était l'exception
-- identifiée à l'audit RLS du Lot 1 (les autres tables de volets sont staff-based).
--
-- On ouvre une voie SELECT dédiée au staff, calquée sur libraries_staff_read (Lot 1).
-- Permissive → s'ajoute en OR à library_commons_public_read (la lecture publique des
-- biblios actives reste inchangée).
-- ════════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "library_commons_staff_read" ON public.library_commons;
CREATE POLICY "library_commons_staff_read"
ON public.library_commons FOR SELECT TO authenticated
USING (public.user_can_act_as_staff_on_library(library_id));

COMMENT ON POLICY "library_commons_staff_read" ON public.library_commons IS
  'Le staff (membership active librarian/coordenador, ou admin réseau) lit toujours le '
  'library_commons de sa biblio, y compris pré-active (is_active=false) pendant la '
  'constitution — fn_library_visible_to_caller exige is_active=true et bloque sinon. '
  'S''ajoute (OR) à library_commons_public_read. Calque libraries_staff_read. '
  'ONBO-Q2 Lot 3 / volet 7 (2026-06-13).';

-- Garde-fou : la policy doit exister à l'issue de la migration.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policy
     WHERE polrelid = 'public.library_commons'::regclass
       AND polname  = 'library_commons_staff_read'
  ) THEN
    RAISE EXCEPTION 'KO: policy library_commons_staff_read manquante';
  END IF;
  RAISE NOTICE 'ONBO-Q2 Lot 3 volet 7 OK : library_commons_staff_read en place.';
END $$;
