-- =========================================================================
-- AnarBib — Une brève rejetée dit pourquoi, et peut revenir
-- =========================================================================
-- Date     : 2026-09-15
-- Chantier : Gazette Rizoma — boucle de contribution à la page « Vie du réseau »
-- Décision : REGISTRE §29 GAZ-7
--
-- CE QUE LE RELEVÉ A MONTRÉ (15/09/2026)
--   Rejeter une brève, dans le panneau réseau, écrivait trois colonnes :
--   status, reviewed_by, reviewed_at. Rien d'autre.
--   1. `review_note` existe depuis la création de la table (20260615064958)
--      et n'a JAMAIS été écrite : aucun champ côté staff, aucune lecture.
--   2. Le trigger d'enfilement ne se déclenche qu'à l'INSERT : accepter ou
--      rejeter n'émettait aucun événement, donc aucun courriel — ni vers la
--      personne qui a écrit, ni vers le réseau.
--   3. La table ne connaît la personne que par du texte libre
--      (contributor_email) : pas de compte, pas d'espace « mes brèves ».
--   Résultat : un rejet était un mur silencieux. La personne ne savait pas
--   que son texte avait été refusé, encore moins pourquoi, et n'avait aucun
--   chemin de correction. En production le 15/09 : 1 brève rejetée, sans
--   motif, sans e-mail.
--
-- CE QUE FAIT CETTE MIGRATION
--   a. UN REJET PORTE UN MOTIF : CHECK (status <> 'rejected' OR review_note
--      IS NOT NULL). Colonne, puis reprise de la ligne existante, puis garde
--      — l'ordre de 20260831090412 : une garde posée avant la reprise casse
--      en production et pas en CI.
--   b. UNE BRÈVE PEUT REVENIR : parent_submission_id chaîne la reprise à la
--      brève rejetée ; resubmit_token_hash / resubmit_token_expires_at
--      portent un jeton d'usage unique (60 jours), envoyé par courriel, dont
--      la base ne garde que l'empreinte SHA-256 ; resubmitted_at marque le
--      jeton consommé. La reprise passe par l'Edge Function publique
--      submit-gazette-contribution (action « prefill » puis envoi), jamais
--      par un accès direct à la table.
--   c. LA DÉCISION EST DITE : trigger BEFORE UPDATE OF status →
--      gazette.contribution.rejected (motif + jeton) ou .accepted, dans la
--      même outbox que l'INSERT, SEULEMENT si la personne a laissé un
--      e-mail. Sans e-mail il n'y a personne à prévenir : aucune ligne, et
--      le panneau le dit à l'écran au moment de rejeter. Quitter l'état
--      rejeté (retour en 'new', passage en 'accepted') révoque le jeton.
--   d. L'AVIS AU RÉSEAU D'UNE REPRISE DIT QU'ELLE EN EST UNE :
--      fn_gazette_submission_enqueue ajoute parent_submission_id au payload.
--
-- CE QUI NE CHANGE PAS
--   Aucune table créée (rien à classer pour la sauvegarde). RLS inchangée :
--   lecture et écriture network_staff ; l'EF écrit avec la clé secrète. Aucune
--   auto-publication. La personne qui contribue n'atteint jamais la table.
--
-- GARDES CI (tests/sql) : FK → index (fk_sans_index_garde) ; fonctions
--   DEFINER fermées à PUBLIC/anon/authenticated (grants_herites T10, trigger
--   compris) ; suite dédiée tests/sql/gazette_reprise_tests.sql.
-- =========================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Les colonnes de la reprise
-- ---------------------------------------------------------------------
alter table public.gazette_submissions
  add column if not exists parent_submission_id uuid
    references public.gazette_submissions(id) on delete set null,
  add column if not exists resubmit_token_hash text,
  add column if not exists resubmit_token_expires_at timestamptz,
  add column if not exists resubmitted_at timestamptz;

comment on column public.gazette_submissions.parent_submission_id is
  'Brève rejetée dont celle-ci est la reprise (corrigée puis renvoyée par la '
  'personne, via le jeton reçu par courriel). NULL pour une première proposition.';
comment on column public.gazette_submissions.resubmit_token_hash is
  'Empreinte SHA-256 (hex) du jeton de reprise envoyé par courriel au rejet. Le '
  'jeton lui-même n''est jamais stocké. NULL si pas d''e-mail, ou une fois la '
  'brève sortie de l''état rejeté.';
comment on column public.gazette_submissions.resubmit_token_expires_at is
  'Fin de validité du jeton de reprise (60 jours après le rejet).';
comment on column public.gazette_submissions.resubmitted_at is
  'Moment où le jeton a été consommé : une reprise (parent_submission_id = cette '
  'ligne) a été déposée. Un jeton ne sert qu''une fois.';

-- FK sans index = rouge à fk_sans_index_garde_tests.
create index if not exists gazette_submissions_parent_idx
  on public.gazette_submissions(parent_submission_id);
-- Recherche par empreinte à la reprise ; unique : deux jetons ne peuvent
-- pas se confondre.
create unique index if not exists gazette_submissions_resubmit_token_hash_uidx
  on public.gazette_submissions(resubmit_token_hash)
  where resubmit_token_hash is not null;

-- ---------------------------------------------------------------------
-- 2. Reprise de l'existant — AVANT la garde
-- ---------------------------------------------------------------------
-- Une brève rejetée sans motif en production (15/09). En CI, base
-- reconstruite : aucune ligne, et c'est normal.
update public.gazette_submissions
   set review_note = 'Motif non consigné : rejet antérieur au 15/09/2026, '
                     'avant que le panneau ne le demande.'
 where status = 'rejected' and review_note is null;

-- ---------------------------------------------------------------------
-- 3. La garde : un rejet porte un motif
-- ---------------------------------------------------------------------
alter table public.gazette_submissions
  drop constraint if exists gazette_submissions_rejet_motive_chk;
alter table public.gazette_submissions
  add constraint gazette_submissions_rejet_motive_chk
  check (status <> 'rejected' or review_note is not null);

-- ---------------------------------------------------------------------
-- 4. La décision est dite (rejet → motif + jeton ; acceptation → avis)
-- ---------------------------------------------------------------------
create or replace function public.fn_gazette_submission_decision_enqueue()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $fn$
declare
  v_token text;
  v_email text := nullif(btrim(coalesce(new.contributor_email, '')), '');
begin
  -- Le trigger est déclaré « OF status » : il tourne dès que la colonne est
  -- dans le SET, même à valeur égale. On ne dit une décision que si elle
  -- change.
  if new.status is not distinct from old.status then
    return new;
  end if;

  -- Quitter l'état rejeté révoque le jeton, quoi qu'il arrive ensuite.
  if new.status <> 'rejected' then
    new.resubmit_token_hash := null;
    new.resubmit_token_expires_at := null;
  end if;

  if v_email is null then
    -- Personne à prévenir : aucune ligne d'outbox. Le panneau le dit à
    -- l'écran ; ici on ne fabrique pas un jeton que nul ne recevra.
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
    insert into public.gazette_submission_notification_outbox(event, payload)
    values ('gazette.contribution.accepted', jsonb_build_object(
      'to',            v_email,
      'to_name',       new.contributor_name,
      'locale',        new.locale,
      'submission_id', new.id,
      'rubric',        new.rubric,
      'title',         new.title
    ));
  end if;

  return new;
end;
$fn$;

comment on function public.fn_gazette_submission_decision_enqueue() is
  'BEFORE UPDATE OF status sur gazette_submissions : à un rejet, pose le jeton '
  'de reprise (empreinte + échéance) et enfile gazette.contribution.rejected '
  '(motif + jeton) ; à une acceptation, enfile gazette.contribution.accepted. '
  'Seulement si contributor_email est renseigné. Quitter l''état rejeté révoque '
  'le jeton. Consommé par notify-event (domain/gazette.ts).';

create or replace trigger tg_gazette_submission_decision
  before update of status on public.gazette_submissions
  for each row execute function public.fn_gazette_submission_decision_enqueue();

-- ---------------------------------------------------------------------
-- 5. L'avis au réseau d'une reprise dit qu'elle en est une
-- ---------------------------------------------------------------------
-- Corps repris de la définition réelle (20260615064958, inchangée depuis) ;
-- une seule clé ajoutée : parent_submission_id.
create or replace function public.fn_gazette_submission_enqueue()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  insert into public.gazette_submission_notification_outbox(event, payload)
  values ('gazette.contribution.received',
    jsonb_build_object('to','fede@anarbib.org','submission_id',new.id,'rubric',new.rubric,
      'locale',new.locale,'title',new.title,'excerpt',left(new.body,280),'link',new.link,
      'event_date',new.event_date,'contributor_name',new.contributor_name,
      'contributor_collective',new.contributor_collective,'contributor_email',new.contributor_email,
      'parent_submission_id',new.parent_submission_id,
      'created_at',new.created_at));
  return new;
end;
$fn$;

-- ---------------------------------------------------------------------
-- 6. Portes : un trigger n'a besoin d'aucun grant
-- ---------------------------------------------------------------------
revoke all on function public.fn_gazette_submission_decision_enqueue() from public, anon, authenticated;
revoke all on function public.fn_gazette_submission_enqueue()          from public, anon, authenticated;

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
     and column_name in ('parent_submission_id','resubmit_token_hash',
                         'resubmit_token_expires_at','resubmitted_at');
  if v_n <> 4 then
    raise exception 'ECHEC : % colonne(s) de reprise au lieu de 4', v_n;
  end if;

  if not exists (select 1 from pg_constraint where conname = 'gazette_submissions_rejet_motive_chk') then
    raise exception 'ECHEC : la garde « un rejet porte un motif » est absente';
  end if;

  select count(*) into v_n from public.gazette_submissions
   where status = 'rejected' and review_note is null;
  if v_n <> 0 then
    raise exception 'ECHEC : % rejet(s) encore sans motif', v_n;
  end if;

  if not exists (select 1 from pg_trigger where tgname = 'tg_gazette_submission_decision' and not tgisinternal) then
    raise exception 'ECHEC : trigger tg_gazette_submission_decision absent';
  end if;

  if not exists (select 1 from pg_indexes where schemaname = 'public'
                   and indexname in ('gazette_submissions_parent_idx')) then
    raise exception 'ECHEC : index de la FK parent_submission_id absent';
  end if;

  if has_function_privilege('anon', 'public.fn_gazette_submission_decision_enqueue()', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.fn_gazette_submission_decision_enqueue()', 'EXECUTE')
     or has_function_privilege('anon', 'public.fn_gazette_submission_enqueue()', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.fn_gazette_submission_enqueue()', 'EXECUTE') then
    raise exception 'ECHEC : une fonction trigger de la gazette reste exécutable par anon/authenticated';
  end if;

  if position('parent_submission_id' in pg_get_functiondef('public.fn_gazette_submission_enqueue()'::regprocedure)) = 0 then
    raise exception 'ECHEC : l''avis au réseau ne porte pas parent_submission_id';
  end if;

  raise notice 'OK : 4 colonnes, garde du motif, trigger de décision, avis de reprise, portes fermées.';
end $$;

commit;
