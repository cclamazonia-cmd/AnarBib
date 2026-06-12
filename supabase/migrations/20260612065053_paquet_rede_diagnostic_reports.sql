-- =========================================================================
-- Paquet RAPPORTS-REDE — Rapports diagnostiques réseau (page « rede »)
-- =========================================================================
-- Date     : 2026-06-12
-- Chantier : outils admins réseau / diagnostic catalogue (suite arrivée Baqueiro)
-- Auteur   : Xavier (AnarBib)
-- Session  : Rapports diagnostiques rede
--
-- But
-- ---
-- Exposer aux admins réseau, en LECTURE SEULE, cinq diagnostics du catalogue
-- mutualisé, exportables en PDF depuis l'onglet « Rapports » de RedePage :
--   1. report_documents_incomplets   — fiches `books` aux champs-clés manquants
--   2. report_autorites_a_completer  — fiches `authors` à enrichir (dates/ID/bio)
--   3. report_auteurs_non_resolus    — auteurs legacy non rattachés + noms libres
--   4. report_autorites_doublons     — autorités probablement dupliquées (homonymes)
--   5. report_incoherences_auteurs   — book_authors ≠ book_contributors(autor)
--
-- AUCUNE écriture. La correction/fusion (autorités partagées, gouvernées au
-- fédéral) reste hors périmètre : future page des cercles fédéraux.
--
-- CHECKLIST DOCTRINE (objets sécurisés)
--   [x] Fonctions SECURITY DEFINER :
--       [x] SET search_path = public, pg_catalog
--       [x] REVOKE EXECUTE ... FROM PUBLIC
--       [x] GRANT EXECUTE ... TO authenticated
--   [x] Bloc DO de vérification (le gate renvoie 0 ligne hors admin réseau)
--
-- POURQUOI SECURITY DEFINER plutôt que des vues security_invoker
-- -------------------------------------------------------------
-- La RLS de `authors` (authors_staff_read), `book_authors` et `book_contributors`
-- (book_contributors_catalogacao_librarian_all) s'appuie sur le RÔLE LOCAL
-- (librarian/coordenador, accès catalogação) — PAS sur le statut d'admin réseau.
-- Or un admin réseau peut n'avoir AUCUN rôle local (profil « poids politique »).
-- En security_invoker, il ne verrait alors aucun book_contributors et qu'un
-- sous-ensemble d'authors → rapports faussés/vides. Les fonctions ci-dessous
-- s'exécutent comme propriétaire (RLS contournée) pour donner la vue réseau
-- COMPLÈTE, et sont gardées explicitement par public.fn_caller_is_network_admin()
-- (un non-admin reçoit un jeu vide, sans erreur). Justification consignée ici
-- conformément à la doctrine (exception SECURITY DEFINER documentée en COMMENT).
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1) report_documents_incomplets
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.report_documents_incomplets()
RETURNS TABLE (
  id                bigint,
  bib_ref           text,
  titulo            text,
  autor             text,
  owner_library_id  uuid,
  biblioteca        text,
  sans_auteur       boolean,
  sans_ano          boolean,
  sans_editora      boolean,
  sans_idioma       boolean,
  sans_isbn         boolean,
  sans_paginas      boolean,
  sans_cdd          boolean,
  sans_capa         boolean,
  completude_score  int,
  champs_manquants  text[]
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT b.id, b.bib_ref, b.titulo, b.autor, b.owner_library_id,
      (COALESCE(NULLIF(btrim(b.autor),''),'')=''
        AND NOT EXISTS (SELECT 1 FROM public.book_contributors bc
                         WHERE bc.book_id=b.id AND bc.role='autor')) AS sans_auteur,
      (COALESCE(NULLIF(btrim(b.ano),''),'')='')               AS sans_ano,
      (COALESCE(NULLIF(btrim(b.editora),''),'')='')           AS sans_editora,
      (COALESCE(NULLIF(btrim(b.idioma),''),'')='')            AS sans_idioma,
      (COALESCE(NULLIF(btrim(b.isbn),''),'')='')              AS sans_isbn,
      (b.paginas IS NULL)                                     AS sans_paginas,
      (COALESCE(NULLIF(btrim(b.cdd),''),'')='')               AS sans_cdd,
      (COALESCE(NULLIF(btrim(b.cover_object_path),''),'')='') AS sans_capa
    FROM public.books b
  )
  SELECT base.id, base.bib_ref, base.titulo, base.autor, base.owner_library_id,
         l.name AS biblioteca,
         base.sans_auteur, base.sans_ano, base.sans_editora, base.sans_idioma,
         base.sans_isbn, base.sans_paginas, base.sans_cdd, base.sans_capa,
         ROUND(100.0 * (
             2
           + (CASE WHEN NOT base.sans_auteur  THEN 2   ELSE 0 END)
           + (CASE WHEN NOT base.sans_ano      THEN 1   ELSE 0 END)
           + (CASE WHEN NOT base.sans_editora  THEN 1   ELSE 0 END)
           + (CASE WHEN NOT base.sans_idioma   THEN 1   ELSE 0 END)
           + (CASE WHEN NOT base.sans_isbn     THEN 0.5 ELSE 0 END)
           + (CASE WHEN NOT base.sans_paginas  THEN 0.5 ELSE 0 END)
           + (CASE WHEN NOT base.sans_cdd      THEN 0.5 ELSE 0 END)
           + (CASE WHEN NOT base.sans_capa     THEN 0.5 ELSE 0 END)
         ) / 9.0)::int AS completude_score,
         array_remove(ARRAY[
           CASE WHEN base.sans_auteur  THEN 'auteur'  END,
           CASE WHEN base.sans_ano     THEN 'ano'     END,
           CASE WHEN base.sans_editora THEN 'editora' END,
           CASE WHEN base.sans_idioma  THEN 'idioma'  END,
           CASE WHEN base.sans_isbn    THEN 'isbn'    END,
           CASE WHEN base.sans_paginas THEN 'paginas' END,
           CASE WHEN base.sans_cdd     THEN 'cdd'     END,
           CASE WHEN base.sans_capa    THEN 'capa'    END
         ], NULL) AS champs_manquants
  FROM base
  LEFT JOIN public.libraries l ON l.id = base.owner_library_id
  WHERE base.sans_auteur OR base.sans_ano OR base.sans_editora OR base.sans_idioma
  ORDER BY completude_score ASC, base.id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.report_documents_incomplets() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.report_documents_incomplets() TO authenticated;
COMMENT ON FUNCTION api.report_documents_incomplets() IS
  'Rapport réseau (lecture seule) : fiches documents incomplètes + score de complétude pondéré. SECURITY DEFINER (contourne RLS pour vue réseau complète) gardé par fn_caller_is_network_admin(). Paquet RAPPORTS-REDE du 12/06/2026.';

-- -------------------------------------------------------------------------
-- 2) report_autorites_a_completer
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.report_autorites_a_completer()
RETURNS TABLE (
  id               bigint,
  preferred_name   text,
  sort_name        text,
  nb_documents     bigint,
  sans_dates       boolean,
  sans_bio         boolean,
  sans_id_externe  boolean,
  sans_photo       boolean,
  sans_pays        boolean,
  completude_score int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH a AS (
    SELECT au.id, au.preferred_name, au.sort_name,
      (au.birth_year IS NULL AND au.death_year IS NULL)        AS sans_dates,
      (COALESCE(NULLIF(btrim(au.biography),''),'')='')         AS sans_bio,
      (au.viaf_id IS NULL AND au.isni IS NULL AND au.wikidata_id IS NULL) AS sans_id_externe,
      (COALESCE(NULLIF(btrim(au.photo_object_path),''),'')='') AS sans_photo,
      (COALESCE(NULLIF(btrim(au.country),''),'')='')           AS sans_pays,
      (SELECT count(DISTINCT x.book_id) FROM (
          SELECT book_id FROM public.book_authors      WHERE author_id = au.id
          UNION
          SELECT book_id FROM public.book_contributors WHERE author_id = au.id) x) AS nb_documents
    FROM public.authors au
  )
  SELECT a.id, a.preferred_name, a.sort_name, a.nb_documents,
         a.sans_dates, a.sans_bio, a.sans_id_externe, a.sans_photo, a.sans_pays,
         ROUND(100.0 * (
             (CASE WHEN NOT a.sans_dates      THEN 1   ELSE 0 END)
           + (CASE WHEN NOT a.sans_bio        THEN 1   ELSE 0 END)
           + (CASE WHEN NOT a.sans_id_externe THEN 1   ELSE 0 END)
           + (CASE WHEN NOT a.sans_photo      THEN 0.5 ELSE 0 END)
           + (CASE WHEN NOT a.sans_pays       THEN 0.5 ELSE 0 END)
         ) / 4.0)::int AS completude_score
  FROM a
  WHERE a.sans_dates OR a.sans_bio OR a.sans_id_externe OR a.sans_photo
  ORDER BY a.nb_documents DESC, a.id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.report_autorites_a_completer() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.report_autorites_a_completer() TO authenticated;
COMMENT ON FUNCTION api.report_autorites_a_completer() IS
  'Rapport réseau (lecture seule) : autorités à enrichir (dates / ID externe / bio / photo / pays), priorisées par nb de documents. SECURITY DEFINER gardé par fn_caller_is_network_admin(). Paquet RAPPORTS-REDE du 12/06/2026.';

-- -------------------------------------------------------------------------
-- 3) report_auteurs_non_resolus
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.report_auteurs_non_resolus()
RETURNS TABLE (
  source       text,
  label        text,
  autor_norm   text,
  occurrences  bigint,
  status       text,
  sample       text,
  sample_ref   text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT 'legacy_autor'::text, w.autor, w.autor_norm, w.books_count::bigint,
         w.status, w.sample_title, w.sample_bib_ref
  FROM public.v_author_alias_worklist w
  UNION ALL
  SELECT 'contributor_libre'::text, s.raw_name, s.unresolved_norm, s.uses::bigint,
         'needs_seed'::text, NULL::text, NULL::text
  FROM public.v_author_seed_candidates s
  ORDER BY 4 DESC, 2;
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.report_auteurs_non_resolus() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.report_auteurs_non_resolus() TO authenticated;
COMMENT ON FUNCTION api.report_auteurs_non_resolus() IS
  'Rapport réseau (lecture seule) : auteurs legacy non rattachés (v_author_alias_worklist) + noms de contributeurs sans autorité (v_author_seed_candidates). SECURITY DEFINER gardé par fn_caller_is_network_admin() — ces vues sources ne sont pas accordées à authenticated. Paquet RAPPORTS-REDE du 12/06/2026.';

-- -------------------------------------------------------------------------
-- 4) report_autorites_doublons
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.report_autorites_doublons()
RETURNS TABLE (
  nom_normalise text,
  n             bigint,
  author_ids    bigint[],
  noms          text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH norm AS (
    SELECT au.id, au.preferred_name,
      public.normalize_author_alias(COALESCE(NULLIF(btrim(au.sort_name),''), au.preferred_name)) AS nrm
    FROM public.authors au
  )
  SELECT n.nrm, count(*)::bigint,
         array_agg(n.id ORDER BY n.id),
         string_agg(n.preferred_name, ' | ' ORDER BY n.id)
  FROM norm n
  WHERE COALESCE(n.nrm,'') <> ''
  GROUP BY n.nrm
  HAVING count(*) > 1
  ORDER BY count(*) DESC, n.nrm;
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.report_autorites_doublons() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.report_autorites_doublons() TO authenticated;
COMMENT ON FUNCTION api.report_autorites_doublons() IS
  'Rapport réseau (lecture seule) : autorités probablement dupliquées (même nom normalisé via normalize_author_alias). Diagnostic uniquement — la fusion relève du cercle fédéral. SECURITY DEFINER gardé par fn_caller_is_network_admin(). Paquet RAPPORTS-REDE du 12/06/2026.';

-- -------------------------------------------------------------------------
-- 5) report_incoherences_auteurs
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.report_incoherences_auteurs()
RETURNS TABLE (
  book_id           bigint,
  bib_ref           text,
  titulo            text,
  ba_ids            bigint[],
  bc_ids            bigint[],
  type_incoherence  text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH ba AS (
    SELECT b1.book_id, array_agg(DISTINCT b1.author_id ORDER BY b1.author_id) AS ids
    FROM public.book_authors b1 GROUP BY b1.book_id
  ), bc AS (
    SELECT b2.book_id, array_agg(DISTINCT b2.author_id ORDER BY b2.author_id) AS ids
    FROM public.book_contributors b2
    WHERE b2.role='autor' AND b2.author_id IS NOT NULL
    GROUP BY b2.book_id
  ), diff AS (
    SELECT COALESCE(ba.book_id, bc.book_id) AS book_id, ba.ids AS ba_ids, bc.ids AS bc_ids,
      CASE WHEN ba.ids IS NULL THEN 'manque_dans_book_authors' ELSE 'divergence' END AS type_incoherence
    FROM ba FULL OUTER JOIN bc ON ba.book_id = bc.book_id
    WHERE bc.ids IS NOT NULL                 -- au moins une autorité résolue côté contributeur
      AND ba.ids IS DISTINCT FROM bc.ids     -- ... et les ensembles diffèrent
  )
  SELECT d.book_id, b.bib_ref, b.titulo, d.ba_ids, d.bc_ids, d.type_incoherence
  FROM diff d
  JOIN public.books b ON b.id = d.book_id
  ORDER BY d.book_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.report_incoherences_auteurs() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.report_incoherences_auteurs() TO authenticated;
COMMENT ON FUNCTION api.report_incoherences_auteurs() IS
  'Rapport réseau (lecture seule) : fiches où book_authors et book_contributors(role=autor) résolus divergent (classe de bug du livre 518). Exclut le bruit « contributeur autor non rattaché » (= report_auteurs_non_resolus). SECURITY DEFINER gardé par fn_caller_is_network_admin(). Paquet RAPPORTS-REDE du 12/06/2026.';

-- -------------------------------------------------------------------------
-- BLOC DE VÉRIFICATION — le gate doit renvoyer 0 ligne hors admin réseau
-- (contexte migration : auth.uid() NULL → fn_caller_is_network_admin()=false).
-- RAISE EXCEPTION ⇒ rollback automatique si une fonction fuit hors admin.
-- -------------------------------------------------------------------------
DO $$
DECLARE c bigint;
BEGIN
  SELECT count(*) INTO c FROM api.report_documents_incomplets();
  IF c <> 0 THEN RAISE EXCEPTION 'gate report_documents_incomplets: % lignes hors admin (attendu 0)', c; END IF;
  SELECT count(*) INTO c FROM api.report_autorites_a_completer();
  IF c <> 0 THEN RAISE EXCEPTION 'gate report_autorites_a_completer: % lignes hors admin (attendu 0)', c; END IF;
  SELECT count(*) INTO c FROM api.report_auteurs_non_resolus();
  IF c <> 0 THEN RAISE EXCEPTION 'gate report_auteurs_non_resolus: % lignes hors admin (attendu 0)', c; END IF;
  SELECT count(*) INTO c FROM api.report_autorites_doublons();
  IF c <> 0 THEN RAISE EXCEPTION 'gate report_autorites_doublons: % lignes hors admin (attendu 0)', c; END IF;
  SELECT count(*) INTO c FROM api.report_incoherences_auteurs();
  IF c <> 0 THEN RAISE EXCEPTION 'gate report_incoherences_auteurs: % lignes hors admin (attendu 0)', c; END IF;
  RAISE NOTICE 'paquet RAPPORTS-REDE : gate OK (0 ligne hors admin réseau pour les 5 fonctions)';
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé (si régression post-déploiement) :
-- =========================================================================
-- BEGIN;
--   DROP FUNCTION IF EXISTS api.report_documents_incomplets();
--   DROP FUNCTION IF EXISTS api.report_autorites_a_completer();
--   DROP FUNCTION IF EXISTS api.report_auteurs_non_resolus();
--   DROP FUNCTION IF EXISTS api.report_autorites_doublons();
--   DROP FUNCTION IF EXISTS api.report_incoherences_auteurs();
-- COMMIT;
-- =========================================================================
