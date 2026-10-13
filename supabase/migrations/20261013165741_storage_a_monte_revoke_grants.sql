-- =============================================================================
-- Pins d'images : Storage a monté le 13/10 — 73 → 74, droits retirés
-- =============================================================================
-- Date     : 2026-10-13
-- Chantier : auto-hébergement (I2) / supervision
-- Ref      : 20260921190301 (remesure précédente), deploy/banc-paliers.sh
--
-- À 13 h 31 min 43 s (heure de Paris, `storage.migrations.executed_at`),
-- l'hébergeur a monté Storage (1.77.x → 1.80.2, `/storage/v1/version`) : une
-- migration neuve, `revoke-grants-to-unused-operations`, 73 → 74. La sonde
-- `images_pins` l'a vu à 13 h 35 (incident ouvert, courriel « la production a
-- monté »). GoTrue n'a pas bougé (v2.197.0, 82, dernière 20260831180000).
--
-- Remesuré au banc (deploy/banc-paliers.sh, une base vierge par palier) :
--   v1.77.0 (témoin) → 73, dernière drop-bucketid-objname-index
--   v1.78.0 → 74, dernière revoke-grants-to-unused-operations   ← retenu
--   v1.79.0, v1.79.38, v1.80.0, v1.80.2 → 74
--   v1.81.0 → 75 (unlock-object-versioning : au-delà de la production)
-- Les noms des migrations de v1.78.0 sont ceux de la production.
--
-- Concordance, pile GoTrue v2.197.0 + Storage v1.78.0 sur base vierge :
--   * colonnes — les 344 colonnes de `auth` et `storage` de la production, même
--     empreinte md5 (ffb91953…), hors `storage.iceberg_*` que l'image crée en plus ;
--   * DROITS — cette montée ne touche à aucune colonne, elle retire des droits :
--     les 93 privilèges de anon / authenticated / service_role / public sur les
--     tables et fonctions de `storage` sont identiques à la production. Sous
--     l'ancien pin v1.77.0 il y en avait 117 : anon et authenticated gardaient
--     TRUNCATE, TRIGGER, REFERENCES et MAINTAIN sur storage.buckets, objects et
--     buckets_analytics. TRUNCATE ne passe pas par la RLS : une pile restaurée
--     sous v1.77.0 aurait été plus ouverte que la production. La concordance
--     des colonnes seule ne l'aurait pas vu.
--
-- Cette migration ne fait QUE remplacer l'attendu. Elle va avec
-- deploy/.env.example, deploy/bootstrap.sh et deploy/README.md, dans le même
-- commit — la garde src/tests/pins-images-coherence.test.js refuse la moitié.
-- Aucun verrou de table : sans risque pendant une sauvegarde.
-- =============================================================================

begin;

create or replace function private.fn_images_pins_attendus()
returns jsonb
language sql
immutable
set search_path to 'pg_temp'
as $fn$
  select jsonb_build_object(
    'releve_le', '2026-10-13',
    'gotrue',  jsonb_build_object('tag', 'v2.197.0', 'migrations', 82, 'derniere', '20260831180000'),
    'storage', jsonb_build_object('tag', 'v1.78.0',  'migrations', 74, 'derniere', 'revoke-grants-to-unused-operations')
  );
$fn$;

revoke all on function private.fn_images_pins_attendus() from public, anon, authenticated;

do $verif$
declare v jsonb;
begin
  v := private.fn_images_pins_bilan(82, '20260831180000', 74, 'revoke-grants-to-unused-operations');
  if (v ->> 'ok')::boolean is not true then
    raise exception 'images_pins : le constat du 13/10 ne rend pas ok (%).', v;
  end if;
  v := private.fn_images_pins_bilan(82, '20260831180000', 73, 'drop-bucketid-objname-index');
  if v -> 'pins_a_remesurer' -> 0 ->> 'sens' <> 'instance_en_retard' then
    raise exception 'images_pins : le constat du 21/09 devrait se lire « instance en retard » (%).', v;
  end if;
end $verif$;

commit;
