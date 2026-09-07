-- =============================================================================
-- Bucket `map-tiles` : le fond de carte quitte OpenStreetMap et vient chez nous
-- =============================================================================
-- Date     : 2026-09-07
-- Chantier : backlog v34 E5 (« relayer les tuiles OpenStreetMap par le serveur »)
--
-- CE QUE C'EST.
--
-- Jusqu'ici, les trois cartes de l'application (annuaire du réseau, modale
-- d'édition, auto-déclaration) chargeaient leurs tuiles depuis
-- tile.openstreetmap.org : le navigateur de chaque visiteuse livrait son
-- adresse IP à un tiers — la seule exception anti-pistage restante (INV-5),
-- déclarée dans `privacy.s6.maptiles`. À partir de ce paquet, le fond de carte
-- est UN fichier PMTiles (extrait du planet Protomaps, dérivé d'OpenStreetMap,
-- ODbL) servi par notre Storage et lu par requêtes HTTP Range : le navigateur
-- ne parle plus qu'à nous. Le front lit `<projet>/storage/v1/object/public/
-- map-tiles/planet-z12.pmtiles` (src/lib/mapTiles.js).
--
-- Dimension : 18 Go (planet, zooms 0 à 12, mesuré le 07/09/2026 ; z13 = 36 Go,
-- z14 = 68 Go, z15 = 138 Go). Recette : scripts/maptiles/README.md.
--
-- -----------------------------------------------------------------------------
-- CE QUE FAIT CETTE MIGRATION, ET POURQUOI EN DEUX TEMPS
-- -----------------------------------------------------------------------------
-- 1. Crée le bucket public `map-tiles`, plafond 20 Gio, tout type MIME.
--
-- 2. Fige à 500 Mo les cinq buckets qui n'avaient PAS de plafond propre
--    (`library-regimentos-public`, `library-regimentos-private`,
--    `library-ui-assets`, `network-map`, `catalogos_parceiros_raw`). Jusqu'ici
--    ils héritaient du plafond GLOBAL du projet (500 Mo, réglage Storage du
--    tableau de bord). Or un plafond de bucket ne peut pas dépasser le plafond
--    global : pour téléverser 18 Go dans `map-tiles`, le global doit monter
--    à 20 Gio — et sans ce second temps, les cinq buckets sans plafond propre
--    auraient suivi en silence. On leur écrit donc la valeur qu'ils avaient
--    de fait. Aucun comportement ne change pour eux.
--
--    Le plafond global lui-même n'est pas dans la base : il se pose via l'API
--    de gestion (PATCH /v1/projects/<ref>/config/storage {"fileSizeLimit":
--    21474836480}), fait le 07/09/2026 après cette migration. Sur une pile
--    auto-hébergée, c'est la variable FILE_SIZE_LIMIT du service Storage.
--
-- -----------------------------------------------------------------------------
-- INNOCUITÉ ET REJEU
-- -----------------------------------------------------------------------------
-- * `on conflict (id) do nothing` sur le bucket : rejouable.
-- * Les cinq `update` ne touchent que les lignes encore à `null` : rejouables,
--   et inertes si quelqu'un a déjà posé un plafond à la main.
-- * Aucune policy : le bucket est public en lecture par construction ; l'écriture
--   passe par la clé secrète (CLI `supabase storage cp`), jamais par le front.
-- * Aucune table dans `public` : `bg2-known-tables.txt` ne bouge pas.
-- * Sauvegarde #BG2 : `map-tiles` est volontairement HORS de la liste BUCKETS
--   du flux storage (18 Go reconstructibles en 30 min depuis Protomaps).
-- * Stub CI `tests/sql/_ci_setup_storage_stub.sql` : `map-tiles` y est ajouté,
--   le stub suit la production.
-- =============================================================================

begin;

do $$
begin
  if to_regclass('storage.buckets') is null then
    raise notice
      'storage.buckets absent : bucket map-tiles NON créé. Rejouer ce fichier une fois le service Storage levé.';
    return;
  end if;

  -- 1. Le bucket du fond de carte (public, 20 Gio).
  insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('map-tiles', 'map-tiles', true, 21474836480, null)
  on conflict (id) do nothing;

  -- 2. Les cinq buckets sans plafond propre gardent celui qu'ils avaient de fait.
  update storage.buckets
     set file_size_limit = 524288000
   where id in ('library-regimentos-public', 'library-regimentos-private',
                'library-ui-assets', 'network-map', 'catalogos_parceiros_raw')
     and file_size_limit is null;

  if not exists (select 1 from storage.buckets where id = 'map-tiles' and public) then
    raise exception 'Bucket map-tiles absent ou non public après insertion.';
  end if;
end $$;

commit;

-- =============================================================================
-- CONTRÔLE APRÈS DÉPLOIEMENT
-- =============================================================================
--   select id, public, file_size_limit from storage.buckets
--    where id = 'map-tiles' or file_size_limit is null;   -- attendu : 1 ligne, map-tiles
--   curl -sI -r 0-99 <projet>/storage/v1/object/public/map-tiles/planet-z12.pmtiles
--     → HTTP 206, Access-Control-Allow-Origin: *
