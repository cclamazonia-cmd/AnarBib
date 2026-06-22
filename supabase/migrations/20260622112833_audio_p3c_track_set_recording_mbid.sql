-- 20260622112833_audio_p3c_track_set_recording_mbid.sql
--
-- Chantier #AUDIO-fonds — P3c polish (A) : appliquer un candidat AcoustID à un SEGMENT.
-- Cf. spec-fonds-sonores §6 ; REGISTRE §35.
--
-- RPC qui pose le MBID d'enregistrement (+ AcoustID) choisi dans
-- audio_tracks.external_ids (slot créé en P1). Permet de lier un segment à son
-- enregistrement MusicBrainz sans dépendre d'une ressource numérique
-- (api.audio_resource_set_fingerprint reste pour le grain fichier). Candidat
-- jamais écrit en aveugle (FS-D1) : le staff choisit.
--
-- Auteur  : Claude (assistant·e)
-- Session : Fonds sonores
-- Doctrine: SECURITY DEFINER + search_path + REVOKE/GRANT. Validé BEGIN/ROLLBACK.

begin;

create or replace function api.audio_track_set_recording_mbid(
  p_track_id       bigint,
  p_recording_mbid text,
  p_acoustid       text default null
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
  if not exists (select 1 from public.audio_tracks t where t.id = p_track_id) then
    raise exception 'error.audio.trackNotFound';
  end if;

  update public.audio_tracks set
    external_ids = coalesce(external_ids, '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object(
      'musicbrainz', nullif(btrim(coalesce(p_recording_mbid, '')), ''),
      'acoustid',    nullif(btrim(coalesce(p_acoustid, '')), '')
    )),
    updated_at = now()
  where id = p_track_id;
end;
$fn$;
revoke execute on function api.audio_track_set_recording_mbid(bigint,text,text) from public, anon;
grant  execute on function api.audio_track_set_recording_mbid(bigint,text,text) to authenticated;

comment on function api.audio_track_set_recording_mbid(bigint,text,text) is
  'Pose le MBID d''enregistrement MusicBrainz (+ AcoustID) choisi dans '
  'audio_tracks.external_ids. Staff. Candidat (FS-D1). P3c (#AUDIO-fonds).';

notify pgrst, 'reload schema';

do $$
begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                 where n.nspname='api' and p.proname='audio_track_set_recording_mbid') then
    raise exception 'AUDIO P3c(A) — RPC audio_track_set_recording_mbid manquante';
  end if;
  raise notice 'AUDIO P3c(A) OK';
end $$;

commit;
