-- =========================================================================
-- Paquet gazette-revue — de quoi composer un numéro sans modèle de langage
-- =========================================================================
-- Date     : 2026-08-22
-- Chantier : plan de bataille Rizoma — étage 2 (revue de presse déterministe)
-- Auteur   : coordination AnarBib
--
-- POURQUOI
--   `gazette_issues.build_mode` existait déjà mais n'était que DÉCLARÉ dans le
--   colophon : rien ne le lisait. L'edge function le lit désormais et compose le
--   corps du numéro sans appeler de modèle quand il vaut 'revue' ou 'manual'.
--   Il manquait pour cela deux choses en base.
--
--   1. gazette_sources.rubric — dans quelle page ranger les reprises d'un flux.
--      C'est le SEUL arbitrage éditorial du mode déterministe, et il est fait à
--      la main, une fois, par le staff réseau (article 2 de la charte). Sans
--      cette colonne il faudrait un modèle pour trier, ce qui viderait de son
--      sens le fait de s'en passer.
--
--   2. gazette_build_jobs.consumed_ids — les contributions réellement reprises
--      dans CE numéro. Sans ce registre, `stepFinalize` devrait marquer comme
--      publiées « toutes les contributions acceptées », ce qui emporterait au
--      passage celles acceptées après le début du build. Corrige aussi un
--      travers latent : jusqu'ici, les brèves acceptées n'étaient jamais
--      retirées du vivier et seraient revenues à l'identique chaque mois.
--
-- CHECKLIST DOCTRINE
--   [x] Aucune table créée (deux ALTER + un UPDATE de démarrage)
--   [x] Aucune fonction SECURITY DEFINER, aucune vue touchée
--   [x] RLS de gazette_sources inchangée (lecture + écriture network_staff)
--   [x] Idempotent : add column if not exists, contrainte droppée puis recréée
--   [x] DO block de vérification en fin de migration
-- =========================================================================

begin;

-- ── 1. Rubrique de destination d'un flux ─────────────────────────────────
alter table public.gazette_sources
  add column if not exists rubric text not null default 'luttes';

alter table public.gazette_sources
  drop constraint if exists gazette_sources_rubric_check;
alter table public.gazette_sources
  add constraint gazette_sources_rubric_check
  check (rubric = any (array['luttes'::text, 'international'::text, 'cultures'::text]));

comment on column public.gazette_sources.rubric is
  'Page du numéro où atterrissent les reprises de ce flux, en mode revue de '
  'presse : luttes | international | cultures. Choisi à la main par le staff '
  'réseau — c''est le seul arbitrage éditorial du mode déterministe. '
  'L''agenda ne vient pas des flux mais des contributions (rubric=''agenda'').';

-- Point de départ : les deux flux déclarés « mul » (sans ancrage national)
-- alimentent l'International ; tout le reste part en Luttes & mouvements.
-- À réajuster depuis l'écran « Sources » du panneau Gazette.
update public.gazette_sources
   set rubric = 'international'
 where locale = 'mul' and rubric = 'luttes';

-- ── 2. Contributions consommées par un numéro ────────────────────────────
alter table public.gazette_build_jobs
  add column if not exists consumed_ids jsonb not null default '[]'::jsonb;

comment on column public.gazette_build_jobs.consumed_ids is
  'ids des gazette_submissions réellement reprises dans ce numéro (édito, '
  'brèves réseau, agenda, rubriques). Renseigné pendant la composition ; '
  'stepFinalize les passe de accepted à published pour qu''elles ne '
  'reviennent pas au numéro suivant.';

-- ── 3. Vérification ──────────────────────────────────────────────────────
do $$
declare
  v_sans_rubrique int;
begin
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'gazette_sources'
       and column_name = 'rubric'
  ) then
    raise exception 'gazette_sources.rubric manquante';
  end if;

  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'gazette_build_jobs'
       and column_name = 'consumed_ids'
  ) then
    raise exception 'gazette_build_jobs.consumed_ids manquante';
  end if;

  select count(*) into v_sans_rubrique
    from public.gazette_sources
   where rubric is null or rubric not in ('luttes', 'international', 'cultures');
  if v_sans_rubrique > 0 then
    raise exception 'gazette_sources : % ligne(s) sans rubrique valide', v_sans_rubrique;
  end if;
end $$;

commit;
