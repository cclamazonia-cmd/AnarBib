-- 20260621205119_audio_p3a_fingerprint_persist_and_public_tracklist.sql
--
-- Chantier #AUDIO-fonds — Paquet P3a (backend de P3).
-- Cf. spec-fonds-sonores §5/§11 ; REGISTRE §35 AUDIO ;
--     CADRAGE_fonds_sonores_P1_2026-06-21 (P3 = UI + OPAC).
--
-- Deux RPC :
--   (1) api.audio_resource_set_fingerprint — persiste l'empreinte calculée CÔTE
--       CLIENT (Chromaprint wasm, P3c) + l'AcoustID choisi (candidat, FS-D1) sur
--       les colonnes P0 de book_digital_resources. Staff.
--   (2) api.audio_tracklist_public — tracklist OPAC **anon-safe** d'une édition
--       audio : SECURITY DEFINER qui contourne la RLS staff-only de audio_tracks
--       MAIS ne renvoie QUE pour une notice publiquement visible (filtre via
--       api.catalog_list_anon_v1, même garde que api.work_public_detail). FS-D9.
--
-- Auteur  : Claude (assistant·e) — rédaction assistée
-- Session : Fonds sonores
-- Doctrine: DOC-OBJ-2 (SECURITY DEFINER + search_path + REVOKE/GRANT). Idempotent
--           (CREATE OR REPLACE). Validé BEGIN/ROLLBACK avant push.

begin;

-- ============================================================================
-- (1) Persistance de l'empreinte (staff)
-- ============================================================================
create or replace function api.audio_resource_set_fingerprint(
  p_resource_id bigint,
  p_chromaprint text,
  p_duration_ms integer default null,
  p_acoustid    text    default null
) returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $fn$
begin
  if not exists (select 1 from public.user_library_memberships m
                 where m.user_id=auth.uid() and m.role = any(array['librarian','coordenador']) and m.status='active') then
    raise exception 'error.audio.forbidden';
  end if;
  if not exists (select 1 from public.book_digital_resources d where d.id = p_resource_id) then
    raise exception 'error.audio.resourceNotFound';
  end if;

  update public.book_digital_resources set
    chromaprint_fp          = nullif(btrim(coalesce(p_chromaprint, '')), ''),
    fingerprint_duration_ms = p_duration_ms,
    acoustid_id             = nullif(btrim(coalesce(p_acoustid, '')), ''),
    updated_at              = now()
  where id = p_resource_id;
end;
$fn$;
revoke execute on function api.audio_resource_set_fingerprint(bigint,text,integer,text) from public, anon;
grant  execute on function api.audio_resource_set_fingerprint(bigint,text,integer,text) to authenticated;

comment on function api.audio_resource_set_fingerprint(bigint,text,integer,text) is
  'Persiste l''empreinte Chromaprint (calculée côté client) + l''AcoustID choisi '
  '(candidat, FS-D1) sur book_digital_resources. Staff. P3a (#AUDIO-fonds).';

-- ============================================================================
-- (2) Tracklist OPAC anon-safe (FS-D9 : public-safe via catalog_list_anon_v1)
-- ============================================================================
create or replace function api.audio_tracklist_public(p_book_id bigint)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_catalog
as $fn$
  select case
    -- Garde public-safe : rien si la notice n'est pas publiquement visible.
    when not exists (select 1 from api.catalog_list_anon_v1 c where c.book_id = p_book_id)
      then '[]'::jsonb
    else coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'track_id',              t.id,
          'position',              t."position",
          'title',                 t.title,
          'start_offset',          t.start_offset,
          'duration',              t.duration,
          'work_id',               t.work_id,
          'work_title',            w.uniform_title,
          'recording_type',        t.recording_type,
          'recording_date',        t.recording_date,
          'recording_date_approx', t.recording_date_approx,
          'place_text',            t.place_text,
          'contributors', coalesce((
            select jsonb_agg(
                     jsonb_build_object('name', c.name, 'role', c.role, 'author_id', c.author_id)
                     order by c."position", c.id)
            from public.audio_track_contributors c
            where c.track_id = t.id
          ), '[]'::jsonb)
        )
        order by t."position", t.id
      )
      from public.audio_tracks t
      left join public.works w on w.id = t.work_id
      where t.book_id = p_book_id
    ), '[]'::jsonb)
  end;
$fn$;
revoke execute on function api.audio_tracklist_public(bigint) from public;
grant  execute on function api.audio_tracklist_public(bigint) to anon, authenticated;

comment on function api.audio_tracklist_public(bigint) is
  'Tracklist OPAC anon-safe d''une édition audio : SECURITY DEFINER (contourne la RLS '
  'staff-only de audio_tracks) MAIS gardée par api.catalog_list_anon_v1 (notice publique '
  'seulement), même patron que api.work_public_detail. FS-D9. P3a (#AUDIO-fonds).';

notify pgrst, 'reload schema';

-- ============================================================================
-- Vérification
-- ============================================================================
do $$
declare v_missing text := '';
begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                 where n.nspname='api' and p.proname='audio_resource_set_fingerprint') then
    v_missing := v_missing || ' audio_resource_set_fingerprint';
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                 where n.nspname='api' and p.proname='audio_tracklist_public') then
    v_missing := v_missing || ' audio_tracklist_public';
  end if;
  if v_missing <> '' then
    raise exception 'AUDIO P3a — RPC manquantes :%', v_missing;
  end if;
  raise notice 'AUDIO P3a OK — 2 RPC (persist fingerprint + tracklist public) en place.';
end $$;

commit;
