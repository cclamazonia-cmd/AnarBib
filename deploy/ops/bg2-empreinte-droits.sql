-- I30 — empreinte des droits et des objets de public, ingest, private, api.
-- Identique en production et sur la base restaurée : comptes et md5 par
-- (schéma, sorte). Le concédant (grantor) est ignoré : après restauration
-- c'est le rôle qui rejoue ; seul compte « qui a quel droit sur quoi ».
-- Les listes (rôles, droits) sont triées par NOM : l'ordre d'un tableau d'ACL ou de
-- polroles suit les OID des rôles, propres à chaque instance (12/10 : 306 politiques
-- « différentes » qui ne l'étaient pas).
-- Variable psql `exclues` (obligatoire, -v exclues=...) : tables qualifiées,
-- séparées par des virgules, qu'aucun flux ne sauvegarde (bg2-exclude-long.txt)
-- — elles et leurs séquences ne comptent pas, une restauration ne les rend pas.
-- Variable psql `detail` (facultative, -v detail=1) : ajoute, après le résumé,
-- une ligne par objet — pour nommer ce qui diffère quand un md5 ne dit rien.
SET search_path = pg_catalog;
CREATE TEMP VIEW bg2_empreinte AS
WITH
fn AS (
  SELECT n.nspname s, 'fonctions' k,
         p.oid::regprocedure::text || CASE WHEN p.prosecdef THEN ' DEFINER' ELSE '' END
         || ' [' || coalesce((SELECT string_agg(g, ',' ORDER BY g)
                               FROM (SELECT CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END || ':' || a.privilege_type g FROM aclexplode(coalesce(p.proacl, acldefault('f'::"char", p.proowner))) a) z), '') || ']' x
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname IN ('public', 'ingest', 'private', 'api')
     AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')),
rel AS (
  SELECT n.nspname s, CASE c.relkind WHEN 'r' THEN 'tables' WHEN 'p' THEN 'tables' WHEN 'v' THEN 'vues' WHEN 'm' THEN 'vues_mat' WHEN 'S' THEN 'sequences' END k,
         c.oid::regclass::text
         || ' [' || coalesce((SELECT string_agg(g, ',' ORDER BY g)
                               FROM (SELECT CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END || ':' || a.privilege_type g FROM aclexplode(coalesce(c.relacl, acldefault((CASE WHEN c.relkind = 'S' THEN 's' ELSE 'r' END)::"char", c.relowner))) a) z), '') || ']' x
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname IN ('public', 'ingest', 'private', 'api') AND c.relkind IN ('r', 'p', 'v', 'm', 'S')
     AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = c.oid AND d.deptype = 'e')
     AND NOT (c.oid::regclass::text = ANY (string_to_array(:'exclues', ',')))
     -- leurs séquences : possédées (serial, 'a') ou d'identité ('i') — et, par le nom,
     -- la séquence serial qu'une restauration laisse orpheline quand sa table n'est pas rejouée
     AND NOT EXISTS (SELECT 1 FROM pg_depend d JOIN pg_class t ON t.oid = d.refobjid
                      WHERE d.objid = c.oid AND d.deptype IN ('a', 'i') AND c.relkind = 'S'
                        AND t.oid::regclass::text = ANY (string_to_array(:'exclues', ',')))
     AND NOT EXISTS (SELECT 1 FROM unnest(string_to_array(:'exclues', ',')) e
                      WHERE c.relkind = 'S' AND c.oid::regclass::text LIKE e || '\_%\_seq' ESCAPE '\')),
sch AS (
  SELECT n.nspname s, 'schema' k,
         n.nspname || ' [' || coalesce((SELECT string_agg(g, ',' ORDER BY g)
                                        FROM (SELECT CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END || ':' || a.privilege_type g FROM aclexplode(n.nspacl) a) z), '') || ']' x
    FROM pg_namespace n WHERE n.nspname IN ('public', 'ingest', 'private', 'api')),
defacl AS (
  SELECT n.nspname s, 'defaut:' || pg_get_userbyid(d.defaclrole) k,
         d.defaclobjtype::text || ' [' || coalesce((SELECT string_agg(g, ',' ORDER BY g)
                                              FROM (SELECT CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END || ':' || a.privilege_type g FROM aclexplode(d.defaclacl) a) z), '') || ']' x
    FROM pg_default_acl d JOIN pg_namespace n ON n.oid = d.defaclnamespace
   WHERE n.nspname IN ('public', 'ingest', 'private', 'api')),
-- 12/10 : une politique RLS perdue au rejeu (elle lisait une table de l'autre dump)
-- ouvre ou ferme une table sans qu'aucun GRANT ne bouge — elles comptent aussi.
pol AS (
  SELECT n.nspname s, 'politiques' k,
         c.oid::regclass::text || '.' || p.polname || ' ' || p.polcmd::text || CASE WHEN p.polpermissive THEN ' permissive' ELSE ' restrictive' END
         || ' [' || coalesce((SELECT string_agg(g, ',' ORDER BY g) FROM (SELECT CASE WHEN r = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(r) END g FROM unnest(p.polroles) r) z), '') || ']'
         || ' ' || md5(coalesce(pg_get_expr(p.polqual, p.polrelid), '') || '/' || coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '')) x
    FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname IN ('public', 'ingest', 'private', 'api')
     AND NOT (c.oid::regclass::text = ANY (string_to_array(:'exclues', ',')))),
tout AS (SELECT * FROM fn UNION ALL SELECT * FROM rel UNION ALL SELECT * FROM sch UNION ALL SELECT * FROM defacl UNION ALL SELECT * FROM pol)
SELECT * FROM tout;
SELECT s || '/' || k AS objet, count(*) AS n, md5(string_agg(x, '|' ORDER BY x)) AS empreinte
  FROM bg2_empreinte GROUP BY s, k ORDER BY 1;
\if :{?detail}
SELECT 'detail ' || s || '/' || k AS objet, x FROM bg2_empreinte ORDER BY 1, 2;
\endif
