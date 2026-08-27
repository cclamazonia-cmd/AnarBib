-- =========================================================================
-- Paquet gazette-reviewed-at — accepter une contribution redevient possible
-- =========================================================================
-- Date     : 2026-08-28
-- Chantier : plan de bataille Rizoma — la page « Vie du réseau »
-- Auteur   : coordination AnarBib
--
-- POURQUOI
--   Le panneau Gazette écrit, à chaque acceptation ou rejet d'une contribution
--   (GazetteStaffPanel.decideSubmission) :
--
--     .update({ status, reviewed_by: user.id, reviewed_at: new Date()... })
--
--   Or gazette_submissions.reviewed_at N'EXISTE PAS. La colonne a été prévue
--   côté application et jamais créée en base : PostgREST répond 42703 et le
--   bouton « Accepter » échoue. Autrement dit, depuis l'ouverture du formulaire
--   de contribution, AUCUNE brève n'aurait pu être acceptée.
--
--   Le défaut est resté invisible pour une seule raison : la table est restée
--   vide — personne n'avait encore envoyé de contribution, donc personne n'avait
--   encore cliqué sur « Accepter ». Il se serait manifesté au premier geste du
--   premier collectif qui aurait répondu à l'appel, c'est-à-dire au pire moment.
--
--   On ajoute la colonne plutôt que de retirer l'écriture côté application :
--   savoir QUAND une contribution a été acceptée, et par qui (reviewed_by
--   existe déjà), c'est la trace minimale d'une décision éditoriale humaine —
--   exactement ce que la charte demande de pouvoir montrer.
--
-- CHECKLIST DOCTRINE
--   [x] Aucune table créée, aucune vue touchée, aucune fonction SECURITY DEFINER
--   [x] Colonne nullable : les lignes existantes restent valides
--   [x] RLS inchangée (policies *_network_staff déjà en place)
--   [x] DO block de vérification en fin de migration
-- =========================================================================

begin;

alter table public.gazette_submissions
  add column if not exists reviewed_at timestamptz;

comment on column public.gazette_submissions.reviewed_at is
  'Date de la décision du staff réseau sur cette contribution (acceptée ou '
  'rejetée). Écrite par le panneau Gazette en même temps que status et '
  'reviewed_by. Trace de la décision humaine exigée par la charte technique.';

do $$
begin
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public'
       and table_name = 'gazette_submissions'
       and column_name = 'reviewed_at'
  ) then
    raise exception 'gazette_submissions.reviewed_at manquante';
  end if;
end $$;

commit;
