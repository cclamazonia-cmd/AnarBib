-- =========================================================================
-- File éditoriale — colonne « dernière ouverture » des brouillons
-- =========================================================================
-- Date     : 2026-06-17
-- Chantier : Catalogação / file éditoriale (tri par en-tête + colonne « Ouvert le »)
-- Auteur   : Xavier + Claude
-- Session  : File éditoriale — tri & supports AV
--
-- OBJET
-- -----
-- Ajoute last_opened_at aux 3 tables brouillon pour afficher / trier la file
-- éditoriale par « Ouvert le ». L'ENREGISTREMENT de l'ouverture ne doit PAS
-- toucher updated_at (« ouvrir » ≠ « modifier ») : or les 3 tables portent un
-- trigger BEFORE UPDATE → public.touch_updated_at(). On ajoute donc un garde
-- par variable de session (anarbib.skip_touch_updated_at) — strictement
-- additif et sans effet quand le flag est absent (comportement historique
-- préservé pour TOUTES les tables qui partagent touch_updated_at) — et une RPC
-- dédiée qui pose ce flag (transaction-local) avant d'écrire last_opened_at.
-- =========================================================================

begin;

-- 1) Colonnes -------------------------------------------------------------
alter table public.book_drafts     add column if not exists last_opened_at timestamptz;
alter table public.author_drafts   add column if not exists last_opened_at timestamptz;
alter table public.exemplar_drafts add column if not exists last_opened_at timestamptz;

comment on column public.book_drafts.last_opened_at     is 'Dernière ouverture du brouillon pour édition (file éditoriale). N''indique pas une modification — cf. updated_at.';
comment on column public.author_drafts.last_opened_at   is 'Dernière ouverture du brouillon pour édition (file éditoriale). N''indique pas une modification — cf. updated_at.';
comment on column public.exemplar_drafts.last_opened_at is 'Dernière ouverture du brouillon pour édition (file éditoriale). N''indique pas une modification — cf. updated_at.';

-- 2) Garde additif sur le trigger PARTAGÉ touch_updated_at ----------------
-- Si le flag de session anarbib.skip_touch_updated_at = 'on', on ne rafraîchit
-- pas updated_at. Flag absent (cas par défaut, toutes les autres tables) →
-- comportement strictement inchangé.
create or replace function public.touch_updated_at()
 returns trigger
 language plpgsql
 set search_path to 'public', 'pg_temp'
as $function$
begin
  if coalesce(current_setting('anarbib.skip_touch_updated_at', true), '') = 'on' then
    return new;
  end if;
  new.updated_at := timezone('utc', now());
  return new;
end;
$function$;

-- 3) RPC d'enregistrement d'ouverture -------------------------------------
-- SECURITY INVOKER : respecte la RLS (n'écrit que sur les brouillons que
-- l'appelant·e peut déjà modifier). Pose le garde transaction-local puis
-- tamponne last_opened_at SANS bumper updated_at.
create or replace function public.fn_touch_draft_opened(p_type text, p_id bigint)
 returns void
 language plpgsql
 security invoker
 set search_path to 'public', 'pg_temp'
as $function$
begin
  if p_id is null or p_type is null then
    return;
  end if;
  perform set_config('anarbib.skip_touch_updated_at', 'on', true);  -- transaction-local
  if p_type = 'book' then
    update public.book_drafts     set last_opened_at = timezone('utc', now()) where id = p_id;
  elsif p_type = 'author' then
    update public.author_drafts   set last_opened_at = timezone('utc', now()) where id = p_id;
  elsif p_type = 'exemplar' then
    update public.exemplar_drafts set last_opened_at = timezone('utc', now()) where id = p_id;
  end if;
end;
$function$;

revoke execute on function public.fn_touch_draft_opened(text, bigint) from public;
grant  execute on function public.fn_touch_draft_opened(text, bigint) to authenticated;

notify pgrst, 'reload schema';

commit;

-- =========================================================================
-- Rollback (manuel) :
--   drop function if exists public.fn_touch_draft_opened(text, bigint);
--   alter table public.book_drafts     drop column if exists last_opened_at;
--   alter table public.author_drafts   drop column if exists last_opened_at;
--   alter table public.exemplar_drafts drop column if exists last_opened_at;
--   -- puis restaurer touch_updated_at() sans le garde (cf. définition d'origine).
-- =========================================================================
