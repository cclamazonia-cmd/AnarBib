-- =========================================================================
-- D24 — le seau EPUB restreint s'ouvre au versement par l'administration du
-- réseau
-- =========================================================================
-- Date     : 2026-10-23
-- Chantier : documents numériques — EPUB des textes intégraux d'Anarchief.org
-- Auteur   : Claude (assistant·e), pour la coordination
-- Ref      : backlog D24 ; 20261018211310_fichiers_reserves_par_bibliotheque
--            (les politiques de pdf-restrito, même forme) ;
--            tests/sql/d24_epub_restreint_tests.sql
--
-- POURQUOI
--   Décision de Xavier du 23/10/2026 (questionnaire D24) : les textes intégraux
--   du wiki d'Anarchief se publient en EPUB, les ouverts (lettre A ou B des
--   lots de textes) dans anarbib-epub-public, les restreints dans
--   anarbib-epub-restricted, versés depuis la session de l'administration du
--   réseau. Le seau public accepte déjà le versement par le catalogage
--   (anarbib_epub_public_librarians_insert) ; le seau restreint n'avait AUCUNE
--   politique : personne, sinon la clé de service, n'y pouvait rien poser ni
--   lire. « Règle pour l'admin réseau » : c'est le choix de Xavier.
--
-- CE QUE FAIT LE PAQUET
--   Quatre politiques sur storage.objects pour anarbib-epub-restricted :
--   * INSERT : administration du réseau seule (fn_caller_is_network_admin ; la
--     double authentification lui est exigée par l'avant-requête, B42), sous
--     books/<identifiant de notice>/<nom>.epub, sans « .. » ;
--   * SELECT, UPDATE, DELETE : la règle des espaces réservés,
--     private.fn_objet_reserve_gerable (déposant d'une équipe, administration
--     du réseau, ou staff d'une bibliothèque détentrice d'un livre dont une
--     ressource désigne l'objet) — la même que pdf-restrito ; UPDATE garde le
--     chemin dans la forme du versement.
--   La lecture par le lectorat passe toujours par read-digital-asset (URL
--   signée à la clé de service, après la garde de la ressource) : ces
--   politiques ne la changent pas.
--
-- CHECKLIST DOCTRINE
--   [x] Aucune fonction créée ; politiques nommées, rejouables (DROP IF EXISTS)
--   [x] Sans storage.objects (banc sans pile) : rien n'est posé, et on le dit
--   [x] Garde : quatre politiques présentes après le paquet
-- =========================================================================

BEGIN;

DO $storage$
BEGIN
  IF to_regclass('storage.objects') IS NULL THEN
    RAISE NOTICE 'storage.objects absent, politiques non posées';
    RETURN;
  END IF;

  DROP POLICY IF EXISTS anarbib_epub_restricted_select ON storage.objects;
  DROP POLICY IF EXISTS anarbib_epub_restricted_insert ON storage.objects;
  DROP POLICY IF EXISTS anarbib_epub_restricted_update ON storage.objects;
  DROP POLICY IF EXISTS anarbib_epub_restricted_delete ON storage.objects;

  CREATE POLICY anarbib_epub_restricted_select ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'anarbib-epub-restricted' AND private.fn_objet_reserve_gerable(bucket_id, name, owner_id));
  CREATE POLICY anarbib_epub_restricted_insert ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'anarbib-epub-restricted'
                AND (SELECT public.fn_caller_is_network_admin())
                AND name ~ '^books/[0-9]{1,18}/[^/]+\.epub$'
                AND position('..' in name) = 0);
  CREATE POLICY anarbib_epub_restricted_update ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'anarbib-epub-restricted' AND private.fn_objet_reserve_gerable(bucket_id, name, owner_id))
    WITH CHECK (bucket_id = 'anarbib-epub-restricted'
                AND name ~ '^books/[0-9]{1,18}/[^/]+\.epub$'
                AND position('..' in name) = 0);
  CREATE POLICY anarbib_epub_restricted_delete ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'anarbib-epub-restricted' AND private.fn_objet_reserve_gerable(bucket_id, name, owner_id));

  IF (SELECT count(*) FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects'
        AND policyname LIKE 'anarbib\_epub\_restricted\_%') <> 4 THEN
    RAISE EXCEPTION 'D24 : les quatre politiques du seau EPUB restreint ne sont pas posées';
  END IF;
END
$storage$;

COMMIT;
