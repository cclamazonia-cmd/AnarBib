-- =========================================================================
-- AnarBib — Le staff corrige une brève avant de la retenir
-- =========================================================================
-- Date     : 2026-09-15
-- Chantier : Gazette Rizoma — triage des brèves (GAZ-9)
--
-- POURQUOI
--   Entre « accepter tel quel » et « rejeter », il n'y avait rien. Une brève
--   qu'une coquille, un lien mort ou trois lignes de trop empêchaient de
--   paraître ne pouvait que repartir vers la personne (GAZ-7, une boucle de
--   plusieurs jours) ou être refusée. Le staff relit pourtant chaque brève :
--   il peut la corriger lui-même quand la correction est légère, et la
--   retenir dans le même geste.
--
-- CE QUE FAIT CETTE MIGRATION
--   a. LA CORRECTION EST TRACÉE. staff_edited_by / staff_edited_at disent qui
--      et quand ; original_title / original_body / original_link gardent la
--      version de la personne, posée à la PREMIÈRE correction et jamais
--      réécrite ensuite — c'est ce qui permet de montrer « ce qu'elle avait
--      écrit » à côté de « ce qui paraît ».
--   b. LA TRADUCTION REPART. Les title_i18n / body_i18n sont des traductions
--      du texte d'avant : un titre ou un corps modifié les rend fausses. On
--      les efface et i18n_status repasse à 'pending' — le cron */10 les
--      refait. Un lien modifié seul ne touche pas aux traductions.
--   c. LA PERSONNE LE SAIT. L'événement gazette.contribution.accepted porte
--      corrected=true et le texte retenu (title, body) : le courriel montre
--      ce qui paraîtra. Le calcul se fait dans le trigger de décision sans
--      dépendre de l'ordre des triggers BEFORE (les deux comparent OLD/NEW).
--
-- CE QUI NE CHANGE PAS
--   Aucune table créée, RLS inchangée (l'UPDATE reste réservé à network_staff
--   ; staff_edited_by = auth.uid(), donc jamais posé par l'EF, qui n'écrit
--   jamais title/body). Un rejet porte toujours un motif (GAZ-7).
-- =========================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Les colonnes de la trace
-- ---------------------------------------------------------------------
alter table public.gazette_submissions
  add column if not exists staff_edited_by uuid references public.profiles(id) on delete set null,
  add column if not exists staff_edited_at timestamptz,
  add column if not exists original_title  text,
  add column if not exists original_body   text,
  add column if not exists original_link   text;

comment on column public.gazette_submissions.staff_edited_at is
  'Dernière correction du texte (title/body/link) par le staff réseau, depuis le '
  'panneau. NULL = la brève est telle que la personne l''a écrite.';
comment on column public.gazette_submissions.original_body is
  'Corps tel que la personne l''a écrit, gardé à la PREMIÈRE correction du staff '
  'et jamais réécrit ensuite. NULL tant que le staff n''a rien corrigé.';

create index if not exists gazette_submissions_staff_edited_by_idx
  on public.gazette_submissions(staff_edited_by);

-- ---------------------------------------------------------------------
-- 2. La correction est tracée, la traduction repart
-- ---------------------------------------------------------------------
create or replace function public.fn_gazette_submission_staff_edit()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_texte_change boolean := new.title is distinct from old.title or new.body is distinct from old.body;
  v_lien_change  boolean := new.link  is distinct from old.link;
begin
  if not (v_texte_change or v_lien_change) then
    return new;
  end if;
  -- La version de la personne ne se garde qu'une fois : une seconde correction
  -- ne doit pas la remplacer par la première correction.
  if old.staff_edited_at is null then
    new.original_title := old.title;
    new.original_body  := old.body;
    new.original_link  := old.link;
  end if;
  new.staff_edited_at := now();
  new.staff_edited_by := auth.uid();
  if v_texte_change then
    new.title_i18n  := null;
    new.body_i18n   := null;
    new.i18n_status := 'pending';
    new.i18n_error  := null;
  end if;
  return new;
end;
$fn$;

comment on function public.fn_gazette_submission_staff_edit() is
  'BEFORE UPDATE OF title, body, link sur gazette_submissions : garde la version '
  'd''origine à la première correction, pose staff_edited_by/at, et remet la '
  'traduction en attente quand le texte change (un lien seul ne la touche pas).';

create or replace trigger tg_gazette_submission_staff_edit
  before update of title, body, link on public.gazette_submissions
  for each row execute function public.fn_gazette_submission_staff_edit();

-- ---------------------------------------------------------------------
-- 3. La personne sait que sa brève est retenue AVEC corrections
-- ---------------------------------------------------------------------
-- Corps repris de 20260915193525 (définition réelle du jour) ; l'événement
-- accepted porte en plus corrected, title (déjà), body, link.
create or replace function public.fn_gazette_submission_decision_enqueue()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  v_token text;
  v_email text := nullif(btrim(coalesce(new.contributor_email, '')), '');
  v_corrected boolean;
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  if new.status <> 'rejected' then
    new.resubmit_token_hash := null;
    new.resubmit_token_expires_at := null;
  end if;

  if v_email is null then
    return new;
  end if;

  if new.status = 'rejected' then
    v_token := encode(extensions.gen_random_bytes(32), 'hex');
    new.resubmit_token_hash       := encode(extensions.digest(v_token, 'sha256'), 'hex');
    new.resubmit_token_expires_at := now() + interval '60 days';
    new.resubmitted_at            := null;
    insert into public.gazette_submission_notification_outbox(event, payload)
    values ('gazette.contribution.rejected', jsonb_build_object(
      'to',             v_email,
      'to_name',        new.contributor_name,
      'locale',         new.locale,
      'submission_id',  new.id,
      'rubric',         new.rubric,
      'title',          new.title,
      'review_note',    new.review_note,
      'resubmit_token', v_token,
      'expires_at',     new.resubmit_token_expires_at
    ));
  elsif new.status = 'accepted' then
    -- Corrigée dans CE geste (title/body changent en même temps que le statut)
    -- ou avant (staff_edited_at déjà posé) : dans les deux cas la personne
    -- doit voir le texte retenu. Indépendant de l'ordre des triggers BEFORE.
    v_corrected := new.staff_edited_at is not null
                   or new.title is distinct from old.title
                   or new.body  is distinct from old.body;
    insert into public.gazette_submission_notification_outbox(event, payload)
    values ('gazette.contribution.accepted', jsonb_build_object(
      'to',            v_email,
      'to_name',       new.contributor_name,
      'locale',        new.locale,
      'submission_id', new.id,
      'rubric',        new.rubric,
      'title',         new.title,
      'body',          new.body,
      'link',          new.link,
      'corrected',     v_corrected
    ));
  end if;

  return new;
end;
$fn$;

-- ---------------------------------------------------------------------
-- 4. Portes : un trigger n'a besoin d'aucun grant
-- ---------------------------------------------------------------------
revoke all on function public.fn_gazette_submission_staff_edit()        from public, anon, authenticated;
revoke all on function public.fn_gazette_submission_decision_enqueue()  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Vérification — annule tout si l'état visé n'est pas atteint
-- ---------------------------------------------------------------------
do $$
declare
  v_n int;
begin
  select count(*) into v_n
    from information_schema.columns
   where table_schema = 'public' and table_name = 'gazette_submissions'
     and column_name in ('staff_edited_by','staff_edited_at','original_title','original_body','original_link');
  if v_n <> 5 then
    raise exception 'ECHEC : % colonne(s) de correction au lieu de 5', v_n;
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'tg_gazette_submission_staff_edit' and not tgisinternal) then
    raise exception 'ECHEC : trigger tg_gazette_submission_staff_edit absent';
  end if;
  if not exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'gazette_submissions_staff_edited_by_idx') then
    raise exception 'ECHEC : index de la FK staff_edited_by absent';
  end if;
  if position('corrected' in pg_get_functiondef('public.fn_gazette_submission_decision_enqueue()'::regprocedure)) = 0 then
    raise exception 'ECHEC : l''événement accepted ne dit pas corrected';
  end if;
  if has_function_privilege('anon', 'public.fn_gazette_submission_staff_edit()', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.fn_gazette_submission_staff_edit()', 'EXECUTE') then
    raise exception 'ECHEC : fn_gazette_submission_staff_edit reste exécutable par anon/authenticated';
  end if;
  raise notice 'OK : 5 colonnes, trigger de correction, accepted dit corrected, portes fermées.';
end $$;

commit;
