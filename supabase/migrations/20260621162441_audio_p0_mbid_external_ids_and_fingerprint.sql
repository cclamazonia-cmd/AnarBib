-- 20260621162441_audio_p0_mbid_external_ids_and_fingerprint.sql
--
-- Chantier #AUDIO-fonds — Paquet P0 (cf. spec-fonds-sonores v0.1 ; REGISTRE §35 `AUDIO`).
-- « Quick win » sans bouleversement de schéma — deux ajouts additifs et non-cassants :
--   (1) FS-D6 — MBID (et futurs identifiants externes) sur l'autorité `authors`,
--       via `external_ids jsonb`. Les colonnes viaf_id/isni/wikidata_id restent
--       INCHANGÉES (foyer de ces 3 identifiants) ; la consolidation éventuelle est
--       différée à la couche autorité. Forme provisoire (FS-D6 « à trancher »).
--   (2) FS-D7 / FS-Q5 — empreinte acoustique (Chromaprint / AcoustID) sur la
--       ressource numérique `book_digital_resources`, en COLONNES dédiées indexées.
--       Le prototype tranche FS-Q5 vers les colonnes (dédoublonnage requêtable dès P0)
--       plutôt que le jsonb-first. Le CALCUL de l'empreinte se fait côté client (wasm,
--       patron tesseract.js/zxing) — hors de cette migration.
--
-- Auteur  : Claude (assistant·e) — rédaction assistée
-- Session : Fonds sonores
-- Doctrine : DOC-DEPLOY-1 (push → Forgejo applique) ; DOC-OBJ-2 (objets sécurisés) ;
--            bloc DO de vérification en fin de transaction.
-- Sûreté  : idempotent (IF NOT EXISTS) ; AUCUNE table/fonction/vue nouvelle, AUCUN
--           SECURITY DEFINER → la RLS et les GRANT des tables hôtes restent inchangés
--           (les nouvelles colonnes héritent des policies de ligne existantes).

begin;

-- ============================================================================
-- (1) authors.external_ids — foyer des identifiants externes additionnels (MBID)
-- ============================================================================
alter table public.authors
  add column if not exists external_ids jsonb not null default '{}'::jsonb;

comment on column public.authors.external_ids is
  'Identifiants externes additionnels de l''autorité, au format jsonb objet '
  '(ex. {"musicbrainz":"<MBID artist>"}). FS-D6 (spec-fonds-sonores, REGISTRE §35). '
  'Les colonnes viaf_id / isni / wikidata_id restent le foyer de ces 3 identifiants '
  '(consolidation éventuelle différée à la couche autorité).';

-- garde-fou : external_ids doit être un OBJET jsonb (jamais array/scalaire) ;
-- toutes les lignes existantes valent '{}' (default) → la contrainte valide immédiatement.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'authors_external_ids_is_object'
  ) then
    alter table public.authors
      add constraint authors_external_ids_is_object
      check (jsonb_typeof(external_ids) = 'object');
  end if;
end $$;

-- recherche d'une autorité par identifiant externe (ex. par MBID)
create index if not exists idx_authors_external_ids
  on public.authors using gin (external_ids);

-- ============================================================================
-- (2) book_digital_resources — empreinte acoustique (FS-D7 / FS-Q5 → colonnes)
-- ============================================================================
alter table public.book_digital_resources
  add column if not exists acoustid_id text,
  add column if not exists chromaprint_fp text,
  add column if not exists fingerprint_duration_ms integer;

comment on column public.book_digital_resources.acoustid_id is
  'AcoustID (UUID) de la ressource audio, candidat issu du lookup AcoustID — '
  'jamais écrit en aveugle (candidat, FS-D1). FS-D7 (spec-fonds-sonores).';
comment on column public.book_digital_resources.chromaprint_fp is
  'Empreinte Chromaprint brute, calculée côté client (wasm). Sert au dédoublonnage '
  'interne des numérisations, indépendamment d''AcoustID. FS-D7.';
comment on column public.book_digital_resources.fingerprint_duration_ms is
  'Durée (ms) associée à l''empreinte Chromaprint (requise pour le lookup AcoustID).';

-- dédoublonnage / lookup par AcoustID (partiel : la grande majorité des ressources
-- ne sont pas audio, donc pas d'empreinte → index réservé aux lignes renseignées)
create index if not exists idx_bdr_acoustid_id
  on public.book_digital_resources (acoustid_id)
  where acoustid_id is not null;

-- ============================================================================
-- Vérification (doctrine : bloc DO de contrôle en fin de transaction)
-- ============================================================================
do $$
declare
  v_missing text := '';
begin
  if not exists (select 1 from information_schema.columns
    where table_schema='public' and table_name='authors' and column_name='external_ids') then
    v_missing := v_missing || ' authors.external_ids';
  end if;
  if not exists (select 1 from pg_constraint where conname='authors_external_ids_is_object') then
    v_missing := v_missing || ' authors_external_ids_is_object';
  end if;
  if not exists (select 1 from pg_indexes
    where schemaname='public' and indexname='idx_authors_external_ids') then
    v_missing := v_missing || ' idx_authors_external_ids';
  end if;
  if not exists (select 1 from information_schema.columns
    where table_schema='public' and table_name='book_digital_resources' and column_name='acoustid_id') then
    v_missing := v_missing || ' book_digital_resources.acoustid_id';
  end if;
  if not exists (select 1 from information_schema.columns
    where table_schema='public' and table_name='book_digital_resources' and column_name='chromaprint_fp') then
    v_missing := v_missing || ' book_digital_resources.chromaprint_fp';
  end if;
  if not exists (select 1 from information_schema.columns
    where table_schema='public' and table_name='book_digital_resources' and column_name='fingerprint_duration_ms') then
    v_missing := v_missing || ' book_digital_resources.fingerprint_duration_ms';
  end if;
  if not exists (select 1 from pg_indexes
    where schemaname='public' and indexname='idx_bdr_acoustid_id') then
    v_missing := v_missing || ' idx_bdr_acoustid_id';
  end if;

  if v_missing <> '' then
    raise exception 'AUDIO P0 — objets manquants :%', v_missing;
  end if;
  raise notice 'AUDIO P0 OK — authors.external_ids (+GIN) et empreinte book_digital_resources (+index) en place.';
end $$;

commit;
