-- Active le cron du recapitulatif hebdomadaire des actions inter-bibliotheques.
--
-- Le job existait depuis l'origine mais etait reste INACTIF, faute d'Edge
-- Function : l'appeler aurait donne un 404. La fonction
-- notify-cross-library-digest a ete ecrite le 2026-08-17 et eprouvee sur les
-- donnees reelles du journal (simulation : 4 actions, 2 bibliotheques,
-- 5 messages composes, aucun envoye). On peut donc l'activer.
--
-- Sans cette migration, une reconstruction du schema laisserait le job inactif
-- et l'ecart avec la production serait invisible.
--
-- Rappel du comportement : lundi 8h30 UTC, sur la semaine ISO precedente.
-- AUCUN envoi si aucune action sur la periode — un recapitulatif vide chaque
-- semaine ferait qu'on cesserait de les lire.
--
-- Pour desactiver :
--   select cron.alter_job((select jobid from cron.job
--     where jobname = 'anarbib-notify-cross-library-digest-weekly'), active := false);

do $cron$
begin
  perform cron.alter_job(
    (select jobid from cron.job where jobname = 'anarbib-notify-cross-library-digest-weekly'),
    active := true);
exception when others then
  raise warning 'Cron cross-library-digest NON active (cron indisponible ici ?) : %.', sqlerrm;
end
$cron$;
