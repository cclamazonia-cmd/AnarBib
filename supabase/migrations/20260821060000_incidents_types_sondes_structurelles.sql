-- =============================================================================
-- service_health_incidents : accueillir les sondes STRUCTURELLES
-- =============================================================================
-- Date     : 2026-08-21
-- Chantier : supervision / brancher les sondes existantes
--
-- POURQUOI. Deux sondes existent et ne sont lues par PERSONNE :
-- fn_healthcheck_notifications (17/08) et fn_healthcheck_digital_resources
-- (20260821030000). Verifie ce jour : elles n'apparaissent que dans les
-- migrations qui les creent — aucune edge function, aucun des 32 crons, aucun
-- script, rien au frontend. Un instrument d'observation que personne n'observe
-- ne vaut pas mieux que pas d'instrument.
--
-- health-probe les lira desormais a chaque tour (toutes les 5 minutes). Cette
-- migration ouvre la porte cote base : le `kind` des incidents etait ferme a
-- ('service','backup').
--
-- ⚠️ SANS CET ELARGISSEMENT, LE BRANCHEMENT AURAIT PROVOQUE UN DELUGE DE MAILS.
-- Le code de health-probe ne verifie pas l'erreur retournee par l'insertion
-- d'incident (meme motif que le bloc `backup` existant). Un `kind` refuse par la
-- CHECK aurait donc : echoue silencieusement -> aucun incident enregistre ->
-- la condition `!incidentOuvert` serait restee vraie -> UNE ALERTE TOUTES LES
-- CINQ MINUTES, indefiniment. Meme classe de piege que l'allowlist
-- fn_enqueue_* face a la CHECK des *_notification_events : elargir la fonction
-- sans elargir la contrainte fabrique une panne muette.
--
-- DEUX TYPES PLUTOT QU'UN SEUL « coherence ». Les deux domaines tombent en
-- panne independamment : un incident de notifications ne doit pas etre tenu
-- ouvert par un defaut de ressources numeriques, ni l'inverse. Un type unique
-- exigerait que les deux soient reparees pour clore.
-- =============================================================================

begin;

alter table public.service_health_incidents
  drop constraint if exists service_health_incidents_kind_check;

alter table public.service_health_incidents
  add constraint service_health_incidents_kind_check
  check (kind = any (array[
    'service',                -- sondes HTTP du parcours public
    'backup',                 -- temoin de vie des trois flux restic
    'notifications',          -- fn_healthcheck_notifications
    'ressources_numeriques'   -- fn_healthcheck_digital_resources
  ]));

comment on column public.service_health_incidents.kind is
  'Domaine de l''incident. `service` et `backup` sont des sondes de DISPONIBILITE (un etat exterieur qu''on constate) ; `notifications` et `ressources_numeriques` sont des sondes STRUCTURELLES (une incoherence interne de la base). Les secondes sont deterministes : un seul tour suffit a alerter, la temporisation a deux tours des sondes reseau n''a pas lieu d''etre. Tout nouveau type doit etre ajoute ICI en meme temps que dans health-probe, sinon l''insertion echoue en silence et l''alerte se repete a chaque tour.';

commit;
