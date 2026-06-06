-- =========================================================================
-- Paquet fix — dedoublonnage des brouillons du lot Maloca / Emma Goldman
-- =========================================================================
-- Date     : 2026-06-06 (horodatage UTC reel)
-- Chantier : Catalogage / preparation adhesion Maloca / Emma Goldman
-- Auteur   : Xavier + Claude
--
-- CONTEXTE
-- --------
-- Le lot 8 « Import partenaire — Biblioteca Maloca / Emma Goldman — CSV v1 —
-- run 3 » contient 478 brouillons de livre (tous status='draft', non publies)
-- avec des DOUBLONS : la meme notice importee plusieurs fois. La biblio va
-- bientot adherer et verifier son catalogue -> on lui laisse une base nette.
--
-- CLE DE DEDUP (choix utilisateur) : titre + auteur + annee (normalises ;
-- editeur ignore). On garde UN brouillon par groupe, on supprime les redondants.
-- Le KEPT est le plus COMPLET : editeur renseigne en priorite, sinon le plus
-- ancien id. Verifie : 63 redondants attendus. ISBN tous vides, aucun event
-- d'import (dedup par metadonnees). Les cas titre identique mais auteur/annee
-- DIFFERENTS (editions, anthologies) ne sont PAS touches -> revue humaine.
--
-- Tables enfants de book_drafts en ON DELETE CASCADE (contributeurs, etc.).
-- Gardes fail-fast : aucun redondant publie ; plus aucun groupe en double apres.
-- =========================================================================

BEGIN;

DO $dedup$
DECLARE
  v_expected int;
  n int;
BEGIN
  -- Redondants attendus (rn>1 par titre+auteur+annee)
  WITH ranked AS (
    SELECT id, published_book_id,
      row_number() OVER (
        PARTITION BY lower(btrim(titulo)), lower(btrim(coalesce(autor,''))), coalesce(btrim(ano),'')
        ORDER BY (CASE WHEN coalesce(btrim(editora),'') <> '' THEN 0 ELSE 1 END), id
      ) AS rn
    FROM public.book_drafts WHERE batch_id = 8
  )
  SELECT count(*) INTO v_expected FROM ranked WHERE rn > 1;

  IF v_expected = 0 THEN
    RAISE EXCEPTION 'abort : aucun doublon detecte (lot deja nettoye ?)';
  END IF;

  -- Garde : aucun redondant n'est publie (ne jamais effacer une fiche du catalogue)
  IF EXISTS (
    WITH ranked AS (
      SELECT id, published_book_id,
        row_number() OVER (
          PARTITION BY lower(btrim(titulo)), lower(btrim(coalesce(autor,''))), coalesce(btrim(ano),'')
          ORDER BY (CASE WHEN coalesce(btrim(editora),'') <> '' THEN 0 ELSE 1 END), id
        ) AS rn
      FROM public.book_drafts WHERE batch_id = 8
    )
    SELECT 1 FROM ranked WHERE rn > 1 AND published_book_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'abort : un brouillon redondant est publie';
  END IF;

  -- Suppression des redondants (cascade enfants)
  DELETE FROM public.book_drafts WHERE id IN (
    SELECT id FROM (
      SELECT id,
        row_number() OVER (
          PARTITION BY lower(btrim(titulo)), lower(btrim(coalesce(autor,''))), coalesce(btrim(ano),'')
          ORDER BY (CASE WHEN coalesce(btrim(editora),'') <> '' THEN 0 ELSE 1 END), id
        ) AS rn
      FROM public.book_drafts WHERE batch_id = 8
    ) z WHERE z.rn > 1
  );
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> v_expected THEN
    RAISE EXCEPTION 'dedup : % supprimes au lieu de % attendus', n, v_expected;
  END IF;

  -- Verification : plus aucun groupe titre+auteur+annee en double dans le lot
  IF EXISTS (
    SELECT 1 FROM public.book_drafts WHERE batch_id = 8
    GROUP BY lower(btrim(titulo)), lower(btrim(coalesce(autor,''))), coalesce(btrim(ano),'')
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'VERIF : des doublons titre+auteur+annee subsistent dans le lot 8';
  END IF;

  RAISE NOTICE 'dedup Maloca OK — % brouillons redondants supprimes (1 garde par titre+auteur+annee)', n;
END
$dedup$;

COMMIT;

-- =========================================================================
-- Rollback : non automatique (doublons supprimes volontairement).
-- =========================================================================
