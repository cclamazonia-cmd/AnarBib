-- Migration : policy storage manquante pour le bucket d'import de fichiers
-- Auteur  : Claude Opus 4.8
-- Session : Unification partenaire <-> source d'import (fix import dépôt)
-- Date    : 2026-06-11 (UTC)
--
-- BUG : la face « Importação de arquivo » (handleUploadAndProcess) uploade dans
-- le bucket storage 'catalogos_parceiros_raw' — qui n'avait AUCUNE policy RLS.
-- L'upload était donc refusé (ni fichier ni run créé), test d'import bloqué.
-- (Le bucket voisin 'partner-catalog-deposits' a bien sa policy partner_deposit_
-- insert ; celui-ci avait été oublié.)
--
-- Fix : policy storage pour le staff de bibliothèque (api.my_access.
-- can_access_painel), gabarit identique aux autres buckets. Le contrôle fin
-- (coordenador, IMP-14) reste assuré par fn_import_create côté RPC.

DROP POLICY IF EXISTS "catalogos_parceiros_raw staff manage" ON storage.objects;

CREATE POLICY "catalogos_parceiros_raw staff manage" ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'catalogos_parceiros_raw'
    AND EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_painel = true)
  )
  WITH CHECK (
    bucket_id = 'catalogos_parceiros_raw'
    AND EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_painel = true)
  );

-- Vérification
DO $verif$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='storage' AND tablename='objects'
      AND policyname='catalogos_parceiros_raw staff manage'
  ) THEN
    RAISE EXCEPTION 'Policy storage catalogos_parceiros_raw absente.';
  END IF;
  RAISE NOTICE 'Policy storage catalogos_parceiros_raw OK : upload staff autorise.';
END
$verif$;
