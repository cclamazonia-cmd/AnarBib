-- I30 — empreinte des droits et des objets de public, ingest, private, api.
-- Identique en production et sur la base restaurée : comptes et md5 par
-- (schéma, sorte). Le concédant (grantor) est ignoré : après restauration
-- c'est le rôle qui rejoue ; seul compte « qui a quel droit sur quoi ».
SET search_path = pg_catalog;
WITH
fn AS (
  SELECT n.nspname s, 'fonctions' k,
         p.oid::regprocedure::text || CASE WHEN p.prosecdef THEN ' DEFINER' ELSE '' END
         || ' [' || coalesce((SELECT string_agg(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END || ':' || a.privilege_type, ',' ORDER BY 1)
                               FROM aclexplode(coalesce(p.proacl, acldefault('f'::"char", p.proowner))) a), '') || ']' x
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname IN ('public', 'ingest', 'private', 'api')
     AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')),
rel AS (
  SELECT n.nspname s, CASE c.relkind WHEN 'r' THEN 'tables' WHEN 'p' THEN 'tables' WHEN 'v' THEN 'vues' WHEN 'm' THEN 'vues_mat' WHEN 'S' THEN 'sequences' END k,
         c.oid::regclass::text
         || ' [' || coalesce((SELECT string_agg(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END || ':' || a.privilege_type, ',' ORDER BY 1)
                               FROM aclexplode(coalesce(c.relacl, acldefault((CASE WHEN c.relkind = 'S' THEN 's' ELSE 'r' END)::"char", c.relowner))) a), '') || ']' x
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname IN ('public', 'ingest', 'private', 'api') AND c.relkind IN ('r', 'p', 'v', 'm', 'S')
     AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = c.oid AND d.deptype = 'e')),
sch AS (
  SELECT n.nspname s, 'schema' k,
         n.nspname || ' [' || coalesce((SELECT string_agg(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END || ':' || a.privilege_type, ',' ORDER BY 1)
                                        FROM aclexplode(n.nspacl) a), '') || ']' x
    FROM pg_namespace n WHERE n.nspname IN ('public', 'ingest', 'private', 'api')),
defacl AS (
  SELECT n.nspname s, 'defaut:' || pg_get_userbyid(d.defaclrole) k,
         d.defaclobjtype::text || ' [' || coalesce((SELECT string_agg(CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END || ':' || a.privilege_type, ',' ORDER BY 1)
                                              FROM aclexplode(d.defaclacl) a), '') || ']' x
    FROM pg_default_acl d JOIN pg_namespace n ON n.oid = d.defaclnamespace
   WHERE n.nspname IN ('public', 'ingest', 'private', 'api')),
tout AS (SELECT * FROM fn UNION ALL SELECT * FROM rel UNION ALL SELECT * FROM sch UNION ALL SELECT * FROM defacl)
SELECT s || '/' || k AS objet, count(*) AS n, md5(string_agg(x, '|' ORDER BY x)) AS empreinte
  FROM tout GROUP BY s, k ORDER BY 1;
