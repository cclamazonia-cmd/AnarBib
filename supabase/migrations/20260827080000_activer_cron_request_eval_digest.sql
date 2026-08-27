-- =============================================================================
-- Activer le digest d'evaluation des demandes d'adhesion
-- =============================================================================
-- Date     : 2026-08-27
-- Chantier : inscription « je represente une bibliotheque » (collective_candidate)
--
-- CE QUI CHANGE. `anarbib-request-eval-digest` (17 h 08 UTC, quotidien) passe
-- de inactif a actif. Sa migration d'origine
-- (20260619001820_onbo_111_lot3c_eval_digest_cron.sql) le cree explicitement
-- eteint, et 20260821070000_reactiver_crons_gouvernance.sql a pris soin de NE
-- PAS y toucher : « c'est un choix, on n'y touche pas ». Cette decision est
-- revisee ici, et voici pourquoi.
--
-- POURQUOI MAINTENANT. Le meme jour, la voie d'inscription « je represente une
-- bibliotheque qui souhaite rejoindre le reseau » a ete requalifiee pour
-- deposer la personne directement sur /solicitar-biblioteca. Autrement dit :
-- a partir d'aujourd'hui on envoie activement des gens remplir ce formulaire,
-- alors que jusqu'ici personne n'y arrivait (zero compte collective_candidate
-- depuis l'ouverture). Deux demandes d'adhesion attendent deja d'y etre
-- orientees (Anarchief.org 22/08, Bibliotheque SOLIDAIRES 26/08).
--
-- Or c'est ce cron, et lui seul, qui rappelle a la coordination :
--   1. les propositions `proposta_aprovacao` / `proposta_recusa` que tous les
--      admins actifs n'ont pas encore votees ;
--   2. le backlog des demandes `pendente` depuis plus de 7 jours.
-- Sans lui, une demande peut dormir indefiniment dans library_requests sans que
-- rien ne le signale. Envoyer des gens vers un formulaire dont les reponses ne
-- reveillent personne serait la pire des portes : ouverte, et sur une piece
-- vide. Le cadrage du chantier posait d'ailleurs cette activation en
-- prealable explicite.
--
-- POURQUOI C'EST SUR AUJOURD'HUI. `library_requests` est VIDE (verifie le
-- 27/08/2026 : zero ligne, tous statuts confondus). Le premier passage
-- n'enverra donc rien du tout — ni rappel de vote, ni alerte de backlog. C'est
-- exactement le raisonnement du 21/08 sur les deux crons de gouvernance : une
-- tache qu'on rallume a vide se verifie tranquillement ; une tache qu'on
-- decouvre eteinte le jour ou elle sert, non.
--
-- CE QUI N'EST PAS CE CRON. Il ne relance PAS les candidates : il ne parle
-- qu'a la coordination. Le « calendrier de pression » qui relancerait une
-- personne a qui l'on vient d'ecrire « rien ne presse » n'existe dans aucun
-- cron, et n'est pas introduit ici.
--
-- CHAINE VERIFIEE AVANT ACTIVATION (27/08/2026) :
--   - fn_cron_request_eval_digest existe et emet via fn_network_notify_event ;
--   - ce helper ne filtre que le prefixe `network.` — aucune allowlist ni CHECK
--     ne peut avaler l'evenement en WARNING silencieux ;
--   - le handler `network.request_eval_digest` existe cote Edge Function
--     (_shared/domain/network.ts) et ses chaines sont dans mail-strings.ts.
--
-- FORME. `cron.alter_job` par jobNAME et non par jobid (les identifiants
-- different d'une pile reconstruite a l'autre, les noms non), dans un bloc
-- do/exception : le harnais `sql-tests` reconstruit le schema SANS pg_cron, un
-- appel nu y rendrait la CI rouge.
--
-- Pour desactiver a nouveau :
--   select cron.alter_job((select jobid from cron.job
--     where jobname = 'anarbib-request-eval-digest'), active := false);
-- =============================================================================

do $cron$
begin
  perform cron.alter_job(
    (select jobid from cron.job where jobname = 'anarbib-request-eval-digest'),
    active := true);
  raise notice 'Cron request-eval-digest active.';
exception when others then
  raise warning 'Cron request-eval-digest NON active (cron indisponible ici ?) : %.', sqlerrm;
end
$cron$;
