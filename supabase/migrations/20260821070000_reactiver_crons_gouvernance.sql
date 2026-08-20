-- =============================================================================
-- Reactiver les deux crons de gouvernance dormants
-- =============================================================================
-- Date     : 2026-08-21
-- Chantier : exploitation / taches planifiees
--
-- CONSTAT. Sur 33 taches planifiees, 30 tournent. Trois dorment depuis le
-- baseline, dont deux sans raison connue :
--
--   anarbib-collective-removal-execute-daily   3 h 15   execute les retraits
--                                                       collectifs decides
--   anarbib-cooptation-reminders-daily         9 h 25   relance les votes de
--                                                       cooptation en cours
--
-- La troisieme, anarbib-request-eval-digest, N'EST PAS CONCERNEE : sa migration
-- la cree explicitement inactive, c'est un choix, on n'y touche pas.
--
-- POURQUOI MAINTENANT, ET PAS PLUS TARD. Les deux tables de gouvernance sont
-- VIDES — zero proposition de retrait collectif, zero cooptation, jamais. Les
-- rallumer ne declenche donc rien : aucune execution, aucun rappel, aucun
-- arriere qui partirait d'un coup. C'est precisement ce qui rend le geste sur.
--
-- L'inverse ne l'est pas. Les laisser eteintes ne coute rien TANT QUE personne
-- n'ouvre une procedure. Le jour ou une cooptation sera lancee, les rappels ne
-- partiraient pas et l'execution ne se ferait pas — silencieusement, sans
-- erreur, sans trace. C'est la meme forme de panne muette que les flux `long`
-- et `storage` tenus en vert par des lignes de semis : on ne la decouvre qu'au
-- moment ou l'on comptait dessus. Une tache qu'on rallume a vide se verifie
-- tranquillement ; une tache qu'on decouvre eteinte le jour ou elle sert, non.
--
-- FORME. `cron.alter_job` par jobNAME et non par jobid : les identifiants
-- different d'une pile reconstruite a l'autre, les noms non. Et bloc
-- do/exception : le harnais `sql-tests` reconstruit le schema SANS pg_cron, un
-- appel nu y rendrait la CI rouge (regle deja apprise, cf. les migrations de
-- crons precedentes).
--
-- Pour desactiver a nouveau :
--   select cron.alter_job((select jobid from cron.job
--     where jobname = 'anarbib-collective-removal-execute-daily'), active := false);
-- =============================================================================

do $cron$
begin
  perform cron.alter_job(
    (select jobid from cron.job where jobname = 'anarbib-collective-removal-execute-daily'),
    active := true);
  raise notice 'Cron collective-removal-execute-daily active.';
exception when others then
  raise warning 'Cron collective-removal-execute-daily NON active (cron indisponible ici ?) : %.', sqlerrm;
end
$cron$;

do $cron$
begin
  perform cron.alter_job(
    (select jobid from cron.job where jobname = 'anarbib-cooptation-reminders-daily'),
    active := true);
  raise notice 'Cron cooptation-reminders-daily active.';
exception when others then
  raise warning 'Cron cooptation-reminders-daily NON active (cron indisponible ici ?) : %.', sqlerrm;
end
$cron$;
