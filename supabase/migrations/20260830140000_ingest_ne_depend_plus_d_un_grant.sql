-- =========================================================================
-- Paquet INGEST-RLS — le schema `ingest` ne depend plus d'un GRANT
-- =========================================================================
-- Date     : 2026-08-29
-- Chantier : hygiene de la securite — item B1 du backlog v34
-- Ref      : docs/backlogs/AnarBib-Backlog-2026-08-29-v34.md (B1)
--            docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md
--
-- CE QUE CE PAQUET NE CORRIGE PAS. Aucune faille n'est ouverte aujourd'hui.
-- Releve du 29/08 : `anon` et `authenticated` n'ont meme pas USAGE sur le
-- schema `ingest`, et aucune de ses tables ne leur accorde le moindre droit.
-- Le schema est ferme a la porte. Le backlog annoncait « priorite haute » sur
-- la seule absence de RLS, sans avoir regarde les droits : c'etait faux, et la
-- fiche a ete corrigee en meme temps que ce paquet.
--
-- CE QUE CE PAQUET FAIT. Il pose un second verrou, derriere le premier.
-- Aujourd'hui, la fermeture de `ingest` tient a UNE chose : l'absence de
-- GRANT. Un seul `GRANT USAGE ON SCHEMA ingest TO authenticated` — pose un
-- jour pour exposer une vue de travail, par exemple — rendrait d'un coup
-- lisibles 2 172 lignes de catalogues partenaires et 2 084 correspondances
-- vers des brouillons. Avec la RLS activee et zero policy, ce meme GRANT ne
-- donnerait rien : la table repond vide. C'est exactement le raisonnement de
-- `grants_herites_tests.sql` T2, applique au seul schema qu'il ne couvrait pas.
--
-- POURQUOI ZERO POLICY, ET POURQUOI CE N'EST PAS UN OUBLI. Les 17 fonctions
-- SECURITY DEFINER de `ingest` appartiennent a `postgres`, qui est aussi le
-- proprietaire des tables : elles ne sont donc pas soumises a la RLS. Et
-- `service_role` porte BYPASSRLS. L'import continue de fonctionner sans une
-- seule policy — ce n'est pas une hypothese, c'est deja le cas de
-- `ingest.import_profiles` et `ingest.partner_catalog_received_assets`, qui
-- ont la RLS activee depuis leur creation, aucune policy, et n'ont jamais
-- gene personne.
--
-- PIEGE A NE PAS REDECOUVRIR : ne JAMAIS ajouter FORCE ROW LEVEL SECURITY sur
-- ces tables. FORCE soumet le proprietaire lui-meme aux policies ; comme il
-- n'y en a aucune, les 17 fonctions d'import s'arreteraient toutes ensemble,
-- silencieusement, a la premiere ecriture. Le test T2 de la suite
-- `ingest_ferme_tests.sql` garde ce point a zero.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- BLOC A — Le verrou : RLS active sur les dix tables du schema
-- -------------------------------------------------------------------------
-- Les dix, et pas seulement les huit qui en manquaient : l'invariant porte
-- sur le schema entier, et `ENABLE ROW LEVEL SECURITY` est idempotent.

ALTER TABLE ingest.oai_harvest_state                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingest.partner_catalog_import_dispatch_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingest.partner_catalog_import_files        ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingest.partner_catalog_import_runs         ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingest.partner_catalog_match_candidates    ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingest.partner_catalog_row_to_draft        ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingest.partner_catalog_sources             ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingest.partner_catalog_staging_rows        ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingest.import_profiles                     ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingest.partner_catalog_received_assets     ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------------------
-- BLOC B — Dire pourquoi il n'y a pas de policy, sur chaque table
-- -------------------------------------------------------------------------
-- Une table avec RLS et sans policy est indistinguable, a la lecture, d'une
-- table dont on a oublie la policy. Le commentaire fait la difference. On
-- ajoute la mention au commentaire existant quand il y en a un, au lieu de
-- l'ecraser : trois de ces tables portent une description utile.

DO $$
DECLARE
  -- Le libelle evite la formule « SECURITY » + « DEFINER » a dessein : le hook
  -- pre-commit retire les commentaires avant analyse mais pas les litteraux,
  -- et la trouverait ici sans le search_path qui va normalement avec.
  v_regime constant text :=
    'Acces : uniquement les fonctions du schema, qui s''executent avec les droits de leur '
    'proprietaire, et service_role (BYPASSRLS). RLS activee SANS policy, deliberement : le schema n''est expose '
    'ni a anon ni a authenticated, et la RLS est le second verrou si un GRANT venait a etre '
    'pose. Ne jamais ajouter FORCE ROW LEVEL SECURITY : cela couperait les fonctions d''import. '
    'Paquet INGEST-RLS du 29/08/2026.';
  v_tbl  text;
  v_prev text;
BEGIN
  FOREACH v_tbl IN ARRAY ARRAY[
    'oai_harvest_state', 'partner_catalog_import_dispatch_log',
    'partner_catalog_import_files', 'partner_catalog_import_runs',
    'partner_catalog_match_candidates', 'partner_catalog_row_to_draft',
    'partner_catalog_sources', 'partner_catalog_staging_rows',
    'import_profiles', 'partner_catalog_received_assets'
  ]
  LOOP
    SELECT obj_description(('ingest.' || quote_ident(v_tbl))::regclass, 'pg_class')
      INTO v_prev;

    -- Rejeu : ne pas empiler la mention si elle est deja la.
    IF v_prev IS NOT NULL AND position('Paquet INGEST-RLS' in v_prev) > 0 THEN
      CONTINUE;
    END IF;

    EXECUTE format(
      'COMMENT ON TABLE ingest.%I IS %L',
      v_tbl,
      CASE
        WHEN v_prev IS NULL OR btrim(v_prev) = '' THEN v_regime
        ELSE btrim(v_prev) || ' — ' || v_regime
      END
    );
  END LOOP;
END $$;

-- -------------------------------------------------------------------------
-- BLOC C — Verification automatique (doctrine : RAISE EXCEPTION = rollback)
-- -------------------------------------------------------------------------

DO $$
DECLARE
  v_sans_rls   int;
  v_force      int;
  v_usage      int;
  v_grants     int;
  v_total      int;
  v_noms       text;
BEGIN
  SELECT count(*) FILTER (WHERE NOT c.relrowsecurity),
         count(*) FILTER (WHERE c.relforcerowsecurity),
         count(*),
         coalesce(string_agg(c.relname, ', ' ORDER BY c.relname)
                    FILTER (WHERE NOT c.relrowsecurity), '')
    INTO v_sans_rls, v_force, v_total, v_noms
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'ingest' AND c.relkind = 'r';

  IF v_sans_rls > 0 THEN
    RAISE EXCEPTION 'INGEST-RLS : % table(s) du schema ingest restent sans RLS (%). Rollback automatique.',
      v_sans_rls, v_noms;
  END IF;

  IF v_force > 0 THEN
    RAISE EXCEPTION 'INGEST-RLS : % table(s) en FORCE ROW LEVEL SECURITY — cela couperait les fonctions d''import. Rollback automatique.',
      v_force;
  END IF;

  -- Le premier verrou doit etre intact : ce paquet ajoute, il ne remplace pas.
  SELECT count(*) INTO v_usage
    FROM pg_roles r
   WHERE r.rolname IN ('anon', 'authenticated')
     AND has_schema_privilege(r.rolname, 'ingest', 'USAGE');

  IF v_usage > 0 THEN
    RAISE EXCEPTION 'INGEST-RLS : anon ou authenticated a recu USAGE sur ingest — le premier verrou a saute. Rollback automatique.';
  END IF;

  SELECT count(*) INTO v_grants
    FROM information_schema.role_table_grants
   WHERE table_schema = 'ingest' AND grantee IN ('anon', 'authenticated');

  IF v_grants > 0 THEN
    RAISE EXCEPTION 'INGEST-RLS : % droit(s) de table accordes a anon/authenticated dans ingest. Rollback automatique.',
      v_grants;
  END IF;

  RAISE NOTICE 'INGEST-RLS OK : %/% tables du schema ingest sous RLS, aucune en FORCE, schema toujours ferme a anon et authenticated.',
    v_total, v_total;
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé en cas de régression post-déploiement :
-- =========================================================================
-- BEGIN;
--   ALTER TABLE ingest.oai_harvest_state                   DISABLE ROW LEVEL SECURITY;
--   ALTER TABLE ingest.partner_catalog_import_dispatch_log DISABLE ROW LEVEL SECURITY;
--   ALTER TABLE ingest.partner_catalog_import_files        DISABLE ROW LEVEL SECURITY;
--   ALTER TABLE ingest.partner_catalog_import_runs         DISABLE ROW LEVEL SECURITY;
--   ALTER TABLE ingest.partner_catalog_match_candidates    DISABLE ROW LEVEL SECURITY;
--   ALTER TABLE ingest.partner_catalog_row_to_draft        DISABLE ROW LEVEL SECURITY;
--   ALTER TABLE ingest.partner_catalog_sources             DISABLE ROW LEVEL SECURITY;
--   ALTER TABLE ingest.partner_catalog_staging_rows        DISABLE ROW LEVEL SECURITY;
--   -- import_profiles et partner_catalog_received_assets avaient la RLS
--   -- AVANT ce paquet : ne pas les desactiver.
-- COMMIT;
-- =========================================================================
