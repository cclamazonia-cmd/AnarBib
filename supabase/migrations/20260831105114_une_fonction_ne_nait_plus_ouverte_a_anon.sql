-- =====================================================================
-- AnarBib -- Une fonction ne nait plus ouverte a `anon`
-- Date    : 2026-08-31  ·  Item B2, lot 3  ·  advisor Supabase 0028
-- Ref     : CONSTAT_500_avertissements_advisor_2026-08-30
--           migration 20260830181207 (lots 1 et 2)
--           tests/sql/grants_herites_tests.sql (T10 : la liste nommee)
--
-- LA CAUSE, ENFIN.
--
-- Les 141 lignes `REVOKE ... FROM anon` du depot sont la trace d'une lutte
-- menee a la main, fonction par fonction, contre une cause jamais retournee :
-- le schema `public` porte `ALTER DEFAULT PRIVILEGES ... GRANT ALL ON
-- FUNCTIONS TO anon, authenticated, service_role`, herite du socle Supabase.
-- Toute fonction creee la NAIT executable par `anon`. Le grant apparait dans
-- l'ACL parce que Postgres materialise le defaut a la creation -- pas parce
-- qu'une personne a decide. C'est ce que cette migration retourne.
--
-- DEUX VERIFICATIONS FAITES AVANT D'ECRIRE, ET ELLES ONT TOUTES DEUX CORRIGE
-- LE CONSTAT.
--
--   1. IL Y A DEUX ENTREES, PAS UNE. `pg_default_acl` porte une ligne pour le
--      role `postgres` ET une pour `supabase_admin`, toutes deux sur les
--      fonctions de `public`. Nos migrations tournent en `postgres` et les 621
--      fonctions de `public` lui appartiennent : c'est celle-la qui decide.
--      L'autre ne s'appliquerait qu'a une fonction creee PAR `supabase_admin`,
--      ce que le depot ne fait jamais -- et nous n'avons pas le droit de la
--      modifier. Elle est donc laissee, et nommee ici pour que personne ne la
--      redecouvre en croyant a un oubli.
--
--   2. AUCUNE DES 621 FONCTIONS N'A D'ACL NULLE, et c'est ce qui rend
--      l'operation sure. Le defaut NATIF de PostgreSQL accorde `EXECUTE` a
--      `PUBLIC` ; des qu'une entree `pg_default_acl` existe pour les
--      fonctions, elle le REMPLACE. Retirer `anon` de cette entree ne fait
--      donc pas retomber sur `PUBLIC` : ca ferme reellement.
--
--      COROLLAIRE, ET C'EST LE PIEGE A NE PAS TOMBER DEDANS : il ne faut
--      JAMAIS tout revoquer d'un coup. Une entree `pg_default_acl` devenue
--      vide est SUPPRIMEE par Postgres, et le defaut natif -- `PUBLIC=X` --
--      revient. On croirait fermer et on ouvrirait a tout le monde. On garde
--      donc `postgres`, `authenticated` et `service_role` : la ligne survit.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS. Elle ne touche a AUCUNE fonction
-- existante : les 29 ouvertes a `anon` le restent, et le T10 de
-- `grants_herites_tests.sql` garde cette liste nommee dans les deux sens. Elle
-- ne se prononce pas sur `authenticated` -- c'est l'item B14, et le meme piege
-- l'attend. Elle ne touche pas non plus aux defauts sur les TABLES ni sur les
-- SEQUENCES de `public`, qui accordent eux aussi a `anon` : les tables sont
-- gardees par RLS, les sequences meritent leur propre examen (note portee au
-- backlog plutot que corrigee en passant).
--
-- CE QUI CHANGE POUR LA SUITE, ET IL FAUT LE SAVOIR EN L'ECRIVANT. Une
-- fonction publique -- appelee par une visiteuse non connectee -- devra
-- desormais porter un `GRANT EXECUTE ... TO anon` EXPLICITE. C'est le but :
-- une ouverture devient une decision ecrite, et non plus un heritage. Si la
-- ligne manque, l'appel echoue avec `permission denied for function` : bruyant,
-- donc reparable, et jamais silencieux.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- Le geste : une seule ligne, et elle ne vaut que pour l'avenir
-- ---------------------------------------------------------------------
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon;

-- ---------------------------------------------------------------------
-- Verification -- annule tout si l'etat vise n'est pas atteint
-- ---------------------------------------------------------------------
DO $$
DECLARE
  v_acl text;
  v_n   int;
BEGIN
  SELECT d.defaclacl::text INTO v_acl
    FROM pg_default_acl d
    JOIN pg_namespace n ON n.oid = d.defaclnamespace
   WHERE pg_get_userbyid(d.defaclrole) = 'postgres'
     AND n.nspname = 'public'
     AND d.defaclobjtype = 'f';

  -- 1. La ligne existe TOUJOURS. Si elle avait disparu, le defaut natif
  --    `PUBLIC=X` serait revenu et on aurait ouvert au lieu de fermer.
  IF v_acl IS NULL THEN
    RAISE EXCEPTION
      'ECHEC : l''entree pg_default_acl a disparu -- le defaut natif PUBLIC=X reprend, '
      'ce qui OUVRE au lieu de fermer. Il faut conserver au moins un role dans l''entree.';
  END IF;

  -- 2. `anon` n'y est plus.
  IF v_acl LIKE '%anon=%' THEN
    RAISE EXCEPTION 'ECHEC : anon figure encore dans le defaut -> %', v_acl;
  END IF;

  -- 3. Et le reste n'a pas ete emporte au passage.
  IF v_acl NOT LIKE '%authenticated=X%' OR v_acl NOT LIKE '%service_role=X%' THEN
    RAISE EXCEPTION 'ECHEC : le revoke a emporte authenticated ou service_role -> %', v_acl;
  END IF;

  -- 4. Aucune fonction existante n'a bouge : la liste nommee du T10 tient.
  SELECT count(*) INTO v_n
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND has_function_privilege('anon', p.oid, 'EXECUTE');
  RAISE NOTICE 'OK : une fonction naitra desormais fermee a anon. Defaut = %. '
               'Fonctions existantes encore ouvertes a anon : % (inchangees, gardees par le T10).',
               v_acl, v_n;
END $$;

COMMIT;
