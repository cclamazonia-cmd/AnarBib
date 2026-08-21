-- =============================================================================
-- service_health_incidents : un incident par SUJET, garanti par la base
-- =============================================================================
-- Date     : 2026-08-21
-- Chantier : supervision / temoin de vie des sauvegardes (#BG2-16)
--
-- LE TROU. Le bloc `backup` de health-probe ouvre UN incident pour les trois
-- flux restic a la fois, et sa condition d'ouverture est « aucun incident
-- backup ouvert ». Consequence, verifiee sur le code du 20/08 :
--
--   * `court` devient muet   -> incident ouvert, courriel parti, il nomme court ;
--   * `long` tombe a son tour -> un incident backup est deja ouvert -> RIEN.
--     Aucune alerte, et le courriel deja parti ne mentionnera jamais `long`.
--
-- Le mecanisme cense eviter la repetition d'une meme alerte supprime aussi les
-- alertes DIFFERENTES. Un flux peut donc mourir sans que personne ne l'apprenne,
-- et la fermeture exige de toute facon que les trois soient revenus.
--
-- C'est exactement l'argument que la migration 20260821060000 tenait pour les
-- deux sondes structurelles : « les deux domaines tombent en panne
-- independamment [...] un type unique exigerait que les deux soient reparees
-- pour clore ». Il vaut a l'identique pour les trois flux d'un meme type.
--
-- LE CHOIX : ajouter un SUJET, et le faire tenir par la base.
--
-- `subject` porte l'objet precis de l'incident a l'interieur de son domaine :
-- le nom du flux pour `backup`, NULL pour les types qui n'ont qu'un objet.
--
-- L'index unique partiel est le coeur de la migration, et il fait plus que
-- servir ce chantier. Jusqu'ici, « un seul incident ouvert a la fois » etait une
-- CONVENTION tenue par du TypeScript qui lit puis ecrit sans transaction : deux
-- tours qui se chevauchent pouvaient ouvrir deux incidents pour la meme cause,
-- et donc envoyer deux courriels. C'est desormais impossible — et l'echec de
-- l'insertion est deja traite proprement par health-probe, qui RETIENT l'alerte
-- plutot que de l'envoyer sans trace (le repli ajoute par 5fc750952).
--
-- On rend donc structurel un invariant qui reposait sur la bonne conduite du
-- code appelant. C'est le sens du mot « sur » ici : pas un test de plus, une
-- contrainte que le code ne peut pas oublier.
-- =============================================================================

begin;

alter table public.service_health_incidents
  add column if not exists subject text;

comment on column public.service_health_incidents.subject is
  'Objet precis de l''incident a l''interieur de son `kind` : le nom du flux restic (court / long / storage) pour kind = ''backup'', NULL pour les types qui n''ont qu''un seul objet. Un incident ouvert par sujet, garanti par l''index unique partiel service_health_incidents_ouvert_par_sujet : deux pannes distinctes donnent deux incidents, se ferment separement, et aucune n''est masquee par l''autre.';

-- Heritage : un incident agrege (subject NULL) ne se laisse pas repartir sur
-- des flux. On le clot, pour que le tour suivant rouvre proprement flux par
-- flux. Cout maximal : un courriel de plus, une fois. Aucune ligne concernee au
-- moment d'ecrire (les trois incidents existants sont clos) — c'est un filet
-- pour le cas ou la migration serait rejouee sur une base dans un autre etat.
update public.service_health_incidents
   set closed_at = now()
 where kind = 'backup'
   and closed_at is null
   and subject is null;

-- `coalesce` et non `subject` seul : dans un index unique, deux NULL ne se
-- heurtent PAS. Sans lui, la contrainte ne dirait rien des types a objet unique
-- — c'est-a-dire de tous les types sauf `backup`, et notamment de `service`,
-- celui qui a le plus de chances de voir deux tours se chevaucher.
create unique index if not exists service_health_incidents_ouvert_par_sujet
  on public.service_health_incidents (kind, coalesce(subject, ''))
  where closed_at is null;

commit;
