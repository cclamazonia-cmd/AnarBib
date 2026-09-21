-- =============================================================================
-- Pins d'images : Storage a monté le soir même — première remesure
-- =============================================================================
-- Date     : 2026-09-21 (soir)
-- Chantier : auto-hébergement (I2) / supervision
-- Ref      : docs/journal/operations/NOTE_pins-images-remesures_2026-09-21.md §6
--
-- La sonde posée par 20260921181812 est entrée en production dans la soirée du
-- 21/09. À 20 h 43 min 42 s (heure de Paris, `storage.migrations.executed_at`),
-- l'hébergeur montait Storage de 1.73.1 à 1.77.5 : cinq migrations neuves (`bucket-lifecycle-configuration`,
-- `validate-bucket-lifecycle-constraints`, `list-objects-with-versions`,
-- `objects-delete-marker-index`, `drop-bucketid-objname-index`), 68 → 73. La
-- sonde l'a vu dans les deux minutes, l'incident `images_pins` s'est ouvert et le
-- courriel est parti à 20 h 45. Le pin mesuré l'après-midi avait tenu moins de
-- trois heures.
--
-- Remesuré au banc (deploy/banc-paliers.sh, une base vierge par palier) :
--   v1.72.0 (témoin) → 68     v1.74.0, v1.74.5, v1.75.1 → 70     v1.76.2 → 72
--   v1.77.0 → 73, dernière drop-bucketid-objname-index   ← retenu
--   v1.77.5 → 73
-- Les noms des migrations de v1.77.0 sont ceux de la production. Concordance
-- des colonnes, pile GoTrue v2.197.0 + Storage v1.77.0 sur base vierge : les
-- 344 colonnes de `auth` et `storage` de la production s'y retrouvent, même
-- empreinte md5 (l'image crée en plus les deux tables `storage.iceberg_*`).
-- GoTrue n'a pas bougé (v2.197.0, 82).
--
-- Cette migration ne fait QUE remplacer l'attendu. Elle va avec
-- deploy/.env.example et deploy/bootstrap.sh, dans le même commit — la garde
-- src/tests/pins-images-coherence.test.js refuse la moitié.
-- =============================================================================

begin;

create or replace function private.fn_images_pins_attendus()
returns jsonb
language sql
immutable
set search_path to 'pg_temp'
as $fn$
  select jsonb_build_object(
    'releve_le', '2026-09-21',
    'gotrue',  jsonb_build_object('tag', 'v2.197.0', 'migrations', 82, 'derniere', '20260831180000'),
    'storage', jsonb_build_object('tag', 'v1.77.0',  'migrations', 73, 'derniere', 'drop-bucketid-objname-index')
  );
$fn$;

revoke all on function private.fn_images_pins_attendus() from public, anon, authenticated;

do $verif$
declare v jsonb;
begin
  v := private.fn_images_pins_bilan(82, '20260831180000', 73, 'drop-bucketid-objname-index');
  if (v ->> 'ok')::boolean is not true then
    raise exception 'images_pins : le constat du 21/09 au soir ne rend pas ok (%).', v;
  end if;
  v := private.fn_images_pins_bilan(82, '20260831180000', 68, 'objects-null-version-index');
  if v -> 'pins_a_remesurer' -> 0 ->> 'sens' <> 'instance_en_retard' then
    raise exception 'images_pins : l''ancien constat devrait se lire « instance en retard » (%).', v;
  end if;
end $verif$;

commit;
