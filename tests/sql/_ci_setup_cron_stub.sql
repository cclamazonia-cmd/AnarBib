-- ===========================================================================
-- _ci_setup_cron_stub.sql — STUB du schéma `cron` (CI uniquement ; jamais une suite).
-- ---------------------------------------------------------------------------
-- CE QUE CE STUB NE PROUVE PAS — à lire avant tout le reste.
--
--   Il prouve qu'une migration APPELLE `cron.schedule`, avec quel nom et quelle
--   commande. Il ne prouve RIEN sur la production : ni qu'un job y existe, ni
--   qu'il y est actif, ni qu'il s'y déclenche, ni que la fonction appelée fait
--   ce qu'elle promet. Un job planifié ici est une ligne dans une table de
--   test ; personne ne l'exécutera jamais.
--
--   Confondre les deux serait PIRE que l'absence de couverture actuelle : un
--   trou visible (« pg_cron absent de ce banc d'essai ») deviendrait un trou
--   invisible (« les crons sont testés, tout est vert »). Toute suite qui
--   s'appuie sur ce stub doit donc le DIRE dans son bilan — DOC-SILENCE-1 : un
--   dispositif qui n'agit pas doit l'annoncer. Le marqueur `cron.is_ci_stub()`
--   plus bas existe pour ça : il permet à une suite de savoir sur quoi elle
--   parle, et de le déclarer.
--
-- POURQUOI UN STUB, ET PAS L'EXTENSION.
--
--   La CI reconstruit dans une base FRAÎCHE (CREATE DATABASE … TEMPLATE
--   template0), qui n'hérite d'AUCUNE extension de l'image : le schéma `cron`
--   n'y existe pas. `CREATE EXTENSION pg_cron` ne peut pas non plus servir de
--   correctif : pg_cron ne vit que dans UNE base du serveur, désignée par
--   `cron.database_name` au niveau serveur (postgresql.conf), et son
--   lancement d'arrière-plan n'a aucun sens dans une base jetable. Il ne reste
--   que la voie des trois autres stubs (auth, vault, storage) : reproduire
--   l'INTERFACE, pas le service.
--
--   Constat qui a déclenché ce fichier (31/08/2026) : la migration
--   20260831111700 a rougi la CI sur `relation "cron.job" does not exist`.
--   Le trou existait depuis toujours — trente-six jobs en production, zéro
--   couverture — mais restait invisible tant qu'aucune migration ne s'y cognait.
--
-- CE QUI EST REPRODUIT (interface réelle de pg_cron 1.6, cf. usages du dépôt).
--
--   * cron.job — mêmes colonnes, mêmes types, même contrainte d'unicité que la
--     vraie (jobname unique par username) ; c'est elle que lisent les blocs de
--     vérification des migrations et les suites.
--   * cron.schedule(jobname, schedule, command) → bigint, idempotente par nom :
--     replanifier un nom existant le REMPLACE (comme la vraie), et rend le jobid.
--   * cron.unschedule(name) / cron.unschedule(bigint) → boolean. Elles LÈVENT
--     quand le job n'existe pas, exactement comme la vraie : c'est la raison
--     d'être des `EXCEPTION WHEN OTHERS THEN NULL` autour des `unschedule`
--     aveugles du baseline. Un stub complaisant les rendrait inutiles ici et
--     laisserait passer un code qui casse en prod.
--   * cron.alter_job(jobid, …, active := …) — utilisée pour créer un job
--     inactif (20260619001820) puis pour l'activer (20260827080000, 20260821070000).
--     Elle lève aussi sur un jobid introuvable ou NULL : les migrations qui
--     écrivent `alter_job((select jobid from cron.job where jobname = …))` sont
--     ainsi réellement mises à l'épreuve — si le job visé n'a pas été planté
--     avant, ça se voit.
--
--   PERMISSIF SUR LA FORME, STRICT SUR L'EFFET : aucune validation de
--   l'expression de planification (« 15 9 * * * » ou n'importe quoi d'autre
--   passe — valider du cron n'est pas le métier de ce banc d'essai), mais
--   l'effet est exact : une ligne dans cron.job, sous le bon nom.
--
--   NON reproduit, volontairement : la forme à deux arguments
--   `cron.schedule(schedule, command)` (le dépôt ne l'emploie pas),
--   `cron.schedule_in_database`, `cron.job_run_details`, et bien sûr toute
--   exécution. Une migration qui les emploierait échouerait ici sur « function
--   does not exist » — un rouge franc, pas un faux vert : c'est le bon défaut.
--
-- Idempotent. BASE DE TEST JETABLE UNIQUEMENT : appliqué seulement par
-- scripts/ci/run-sql-suites.sh, comme les stubs auth/vault/storage. Ne doit
-- JAMAIS être joué ailleurs — sur une base pourvue du vrai pg_cron il ne
-- s'appliquerait pas (les objets existent), et sur la production il n'a rien
-- à faire.
-- ===========================================================================
CREATE SCHEMA IF NOT EXISTS cron;

COMMENT ON SCHEMA cron IS
  'STUB de banc d''essai (tests/sql/_ci_setup_cron_stub.sql) — PAS pg_cron. '
  'Aucun job planifié ici ne sera jamais exécuté.';

-- Structure de la vraie cron.job (pg_cron 1.6). Les colonnes que le dépôt lit
-- sont jobid, jobname, schedule, command et active ; les autres sont là pour
-- que la table ait la même forme, et qu'un `select *` ne mente pas.
CREATE TABLE IF NOT EXISTS cron.job (
  jobid    bigserial PRIMARY KEY,
  schedule text    NOT NULL,
  command  text    NOT NULL,
  nodename text    NOT NULL DEFAULT 'localhost',
  nodeport int     NOT NULL DEFAULT 5432,
  database text    NOT NULL DEFAULT current_database(),
  username text    NOT NULL DEFAULT CURRENT_USER,
  active   boolean NOT NULL DEFAULT true,
  jobname  name
);

-- Même unicité que la vraie : c'est elle qui fait de `schedule` un upsert.
CREATE UNIQUE INDEX IF NOT EXISTS job_jobname_username_uniq
  ON cron.job (jobname, username);

-- Marqueur : permet à une suite de dire sur quoi elle parle (cf. en-tête).
CREATE OR REPLACE FUNCTION cron.is_ci_stub() RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$ SELECT true $$;

COMMENT ON FUNCTION cron.is_ci_stub() IS
  'Présente uniquement sur le stub de banc d''essai. Absente là où pg_cron est réel.';

-- ---------------------------------------------------------------------------
-- cron.schedule — idempotente par nom, rend le jobid.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cron.schedule(job_name text, schedule text, command text)
RETURNS bigint
LANGUAGE plpgsql AS $fn$
DECLARE v_jobid bigint;
BEGIN
  IF job_name IS NULL OR schedule IS NULL OR command IS NULL THEN
    RAISE EXCEPTION 'cron.schedule (stub) : nom, planification et commande sont obligatoires';
  END IF;
  -- Replanifier un nom existant le remplace, sans changer son jobid : c'est ce
  -- que fait la vraie, et c'est ce qui rend les migrations rejouables.
  INSERT INTO cron.job (jobname, schedule, command)
  VALUES (job_name, schedule, command)
  ON CONFLICT (jobname, username) DO UPDATE
    SET schedule = EXCLUDED.schedule,
        command  = EXCLUDED.command,
        active   = true
  RETURNING jobid INTO v_jobid;
  RETURN v_jobid;
END;
$fn$;

-- ---------------------------------------------------------------------------
-- cron.unschedule — LÈVE quand le job n'existe pas (comme la vraie).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cron.unschedule(job_name name)
RETURNS boolean
LANGUAGE plpgsql AS $fn$
DECLARE v_n int;
BEGIN
  DELETE FROM cron.job WHERE jobname = job_name;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n = 0 THEN
    RAISE EXCEPTION 'could not find valid entry for job "%"', job_name;
  END IF;
  RETURN true;
END;
$fn$;

CREATE OR REPLACE FUNCTION cron.unschedule(job_id bigint)
RETURNS boolean
LANGUAGE plpgsql AS $fn$
DECLARE v_n int;
BEGIN
  DELETE FROM cron.job WHERE jobid = job_id;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n = 0 THEN
    RAISE EXCEPTION 'could not find valid entry for job %', job_id;
  END IF;
  RETURN true;
END;
$fn$;

-- ---------------------------------------------------------------------------
-- cron.alter_job — signature complète de la vraie ; seuls les arguments non
-- NULL sont appliqués. Lève sur un jobid introuvable OU NULL — le NULL est le
-- cas qui compte : `alter_job((select jobid from cron.job where jobname = …))`
-- sur un job jamais planté rendrait NULL, et un stub complaisant laisserait
-- croire à une activation qui n'a pas eu lieu.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cron.alter_job(
  job_id   bigint,
  schedule text    DEFAULT NULL,
  command  text    DEFAULT NULL,
  database text    DEFAULT NULL,
  username text    DEFAULT NULL,
  active   boolean DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql AS $fn$
DECLARE v_n int;
BEGIN
  IF job_id IS NULL THEN
    RAISE EXCEPTION 'could not find valid entry for job <NULL> (stub) : '
                    'le job visé n''a pas été planifié avant cette migration';
  END IF;
  UPDATE cron.job j
     SET schedule = COALESCE(alter_job.schedule, j.schedule),
         command  = COALESCE(alter_job.command,  j.command),
         database = COALESCE(alter_job.database, j.database),
         username = COALESCE(alter_job.username, j.username),
         active   = COALESCE(alter_job.active,   j.active)
   WHERE j.jobid = job_id;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n = 0 THEN
    RAISE EXCEPTION 'could not find valid entry for job %', job_id;
  END IF;
END;
$fn$;
