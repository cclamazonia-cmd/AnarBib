-- CHEMIN DÉPÔT : supabase/migrations/<timestamp>_gazette_submission_i18n.sql
-- Additif/idempotent — flux normal CI. Ajoute la traduction des brèves réseau dans les 10 locales,
-- pour que chaque membre relise/valide une contribution dans sa langue.

alter table public.gazette_submissions
  add column if not exists title_i18n  jsonb,   -- { "<locale>": "titre traduit", ... }
  add column if not exists body_i18n   jsonb,   -- { "<locale>": "corps traduit", ... }
  add column if not exists i18n_status text not null default 'pending'
    check (i18n_status in ('pending','done','error')),
  add column if not exists i18n_error  text;

comment on column public.gazette_submissions.body_i18n is
 'Traductions du corps de la contribution dans les 10 locales (rempli par l''EF translate-gazette-submission). Permet la relecture/validation par chaque membre dans sa langue.';

-- Index partiel : retrouver rapidement les contributions à traduire.
create index if not exists gazette_submissions_i18n_pending_idx
  on public.gazette_submissions(i18n_status) where i18n_status = 'pending';
