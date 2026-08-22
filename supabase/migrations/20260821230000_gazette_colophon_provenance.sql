-- =========================================================================
-- Paquet gazette-colophon — provenance affichée dans la gazette elle-même
-- =========================================================================
-- Date     : 2026-08-21
-- Chantier : plan de bataille Rizoma (sortie d'orbite LLM)
-- Auteur   : coordination AnarBib
--
-- POURQUOI
--   La charte technique de la gazette engage le réseau à imprimer, dans chaque
--   numéro et pour chaque langue, comment ce numéro a été fabriqué. Le colophon
--   ne doit donc PAS dépendre d'un bloc rédigé par le modèle : il est calculé
--   par l'application à partir de trois faits stockés ici.
--
--   1. gazette_issues.build_mode        — comment le corps du numéro a été produit
--      • 'assisted' : digests rédigés par un modèle de langage (état 2026-08)
--      • 'revue'    : revue de presse déterministe (reprise titre + chapô + lien)
--      • 'manual'   : rédigé par des membres, sans assistance machine
--      Le mode est porté par le NUMÉRO (pas par la langue) : il décrit la
--      fabrication du corps, commune à toutes les traductions.
--
--   2. gazette_issue_locales.reviewed_by_label — le collectif qui a relu CETTE langue
--   3. gazette_issue_locales.reviewed_at       — quand
--      Couplés au translation_status existant ('original' | 'machine' |
--      'human_reviewed'), ils permettent d'écrire « traduction automatique,
--      non relue » ou « traduction relue par la BLMF » sans jamais mentir.
--
-- CHECKLIST DOCTRINE
--   [x] Aucune table créée (deux ALTER + un CREATE OR REPLACE VIEW)
--   [x] Vue recréée avec (security_invoker = true), colonnes AJOUTÉES EN FIN
--       de liste — condition de CREATE OR REPLACE VIEW, et les GRANT existants
--       sont conservés
--   [x] Aucune fonction SECURITY DEFINER
--   [x] reviewed_by_label = nom de COLLECTIF, jamais de personne (le champ est
--       lu par anon via la vue publique ; cf. audit annuaire 2026-07)
--   [x] DO block de vérification en fin de migration
-- =========================================================================

begin;

-- ── 1. Mode de fabrication, porté par le numéro ──────────────────────────
alter table public.gazette_issues
  add column if not exists build_mode text not null default 'assisted';

alter table public.gazette_issues
  drop constraint if exists gazette_issues_build_mode_check;
alter table public.gazette_issues
  add constraint gazette_issues_build_mode_check
  check (build_mode = any (array['assisted'::text, 'revue'::text, 'manual'::text]));

comment on column public.gazette_issues.build_mode is
  'Fabrication du corps du numéro : assisted (digests par modèle de langage), '
  'revue (revue de presse déterministe), manual (rédigé par des membres). '
  'Affiché tel quel dans le colophon public — ne le changer qu''en changeant '
  'réellement le pipeline.';

-- ── 2. Relecture humaine, portée par la langue ───────────────────────────
alter table public.gazette_issue_locales
  add column if not exists reviewed_by_label text;
alter table public.gazette_issue_locales
  add column if not exists reviewed_at timestamptz;

comment on column public.gazette_issue_locales.reviewed_by_label is
  'Collectif ou bibliothèque ayant relu cette langue (ex. « BLMF »). '
  'JAMAIS un nom de personne : ce champ est lu publiquement via '
  'api.gazette_locales_public_v1.';
comment on column public.gazette_issue_locales.reviewed_at is
  'Date de la relecture humaine. Renseignée en même temps que '
  'translation_status = ''human_reviewed''.';

-- Cohérence : on ne peut pas être « relu » sans dire par qui.
alter table public.gazette_issue_locales
  drop constraint if exists gazette_locales_reviewed_coherent_check;
alter table public.gazette_issue_locales
  add constraint gazette_locales_reviewed_coherent_check
  check (
    translation_status <> 'human_reviewed'
    or (reviewed_by_label is not null and btrim(reviewed_by_label) <> '')
  );

-- ── 3. Vue publique : exposer la provenance ──────────────────────────────
-- Colonnes ajoutées EN FIN de liste (contrainte de CREATE OR REPLACE VIEW).
create or replace view api.gazette_locales_public_v1
  with (security_invoker = 'on') as
 select l.issue_id,
    i.number as issue_number,
    i.cover_date,
    l.locale,
    l.tagline,
    l.masthead,
    l.content,
    l.translation_status,
    l.pdf_object_path,
    l.source_locale,
    l.reviewed_by_label,
    l.reviewed_at,
    i.build_mode
   from public.gazette_issue_locales l
     join public.gazette_issues i on i.id = l.issue_id
  where i.status = 'published';

comment on view api.gazette_locales_public_v1 is
  'Numéros publiés de la gazette, par langue. Expose la provenance '
  '(translation_status, source_locale, reviewed_by_label, reviewed_at, '
  'build_mode) pour que le colophon imprimé dise comment le numéro a été '
  'fabriqué. Lecture anon — ne jamais y mettre de nom de personne.';

-- ── 4. Vérification ──────────────────────────────────────────────────────
do $$
declare
  v_missing text;
begin
  select string_agg(c, ', ') into v_missing
  from unnest(array['source_locale','reviewed_by_label','reviewed_at','build_mode']) as c
  where not exists (
    select 1 from information_schema.columns
    where table_schema = 'api'
      and table_name = 'gazette_locales_public_v1'
      and column_name = c
  );
  if v_missing is not null then
    raise exception 'gazette_locales_public_v1 : colonnes manquantes (%)', v_missing;
  end if;

  if not exists (
    select 1 from pg_class cl
    join pg_namespace ns on ns.oid = cl.relnamespace
    where ns.nspname = 'api'
      and cl.relname = 'gazette_locales_public_v1'
      and cl.reloptions @> array['security_invoker=on']
  ) then
    raise exception 'gazette_locales_public_v1 : security_invoker perdu';
  end if;
end $$;

commit;
