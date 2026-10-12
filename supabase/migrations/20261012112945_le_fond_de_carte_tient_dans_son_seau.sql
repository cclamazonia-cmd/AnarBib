-- =========================================================================
-- Le fond de carte tient dans son seau : map-tiles à 80 Gio, comme en production
-- =========================================================================
-- Date     : 2026-10-12
-- Chantier : hébergement / VM auto-hébergée (préparation de la VM d'ASR2026)
-- Auteur   : Claude (Fable 5.1), pour Xavier
--
-- CE QUE LE RELEVÉ DU 12/10/2026 A TROUVÉ.
--
-- `20260907234500_bucket_map_tiles_fond_de_carte` crée le bucket `map-tiles`
-- avec un plafond de 20 Gio, pour un fichier PMTiles de 18 Go (zoom 12). La
-- production sert depuis un fond de carte au zoom 13 — 36 Go — et son bucket
-- a été porté à 80 Gio (85 899 345 920 octets) par le tableau de bord, hors
-- migration. Une pile reconstruite depuis le dépôt gardait donc 20 Gio : le
-- fond de carte de la production n'y tenait pas, et rien ne le disait avant
-- le téléversement.
--
-- Ce fichier aligne le dépôt sur la production. Il ne RELÈVE que : un plafond
-- déjà supérieur ou égal est laissé tel quel. Sur la production il est inerte.
--
-- Le plafond GLOBAL du service (FILE_SIZE_LIMIT, `STORAGE_FILE_SIZE_LIMIT` dans
-- deploy/.env.example) doit être au moins égal : un bucket ne peut pas accepter
-- plus que lui. `.env.example` passe à la même valeur dans le même commit ; sur
-- le projet hébergé, le plafond global se règle par l'API de gestion.
--
-- INNOCUITÉ : un seul UPDATE, borné par un `where` ; aucune policy, aucune
-- table de `public` (bg2-known-tables.txt ne bouge pas) ; garde habituelle si
-- le schéma storage n'existe pas encore (harnais sans stub, pile dont Storage
-- n'a pas démarré) : on ne fait rien et on le dit, deploy/bootstrap.sh rejoue
-- les plafonds à l'étape 8.
-- =========================================================================

begin;

do $$
declare
  v_plafond bigint := 85899345920;  -- 80 Gio, relevé de la production le 12/10/2026
  v_actuel  bigint;
begin
  if to_regclass('storage.buckets') is null then
    raise notice
      'storage.buckets absent : plafond de map-tiles NON relevé. Rejouer ce fichier une fois le service Storage levé.';
    return;
  end if;

  select file_size_limit into v_actuel from storage.buckets where id = 'map-tiles';

  if not found then
    raise notice
      'Bucket map-tiles absent : rien à relever (il est créé par 20260907234500 ; installation sans fond de carte ?).';
    return;
  end if;

  update storage.buckets
     set file_size_limit = v_plafond
   where id = 'map-tiles'
     and (file_size_limit is null or file_size_limit < v_plafond);

  if found then
    raise notice 'map-tiles : plafond % -> % octets.', coalesce(v_actuel::text, 'null'), v_plafond;
  else
    raise notice 'map-tiles : plafond déjà à % octets, rien à faire (cas de la production).', v_actuel;
  end if;

  if not exists (select 1 from storage.buckets where id = 'map-tiles' and file_size_limit >= v_plafond) then
    raise exception 'map-tiles : plafond toujours sous % octets après mise à jour.', v_plafond;
  end if;
end $$;

commit;

-- =========================================================================
-- CONTRÔLE APRÈS DÉPLOIEMENT
-- =========================================================================
--   select id, public, file_size_limit from storage.buckets where id = 'map-tiles';
--   -- attendu : true, 85899345920 (inchangé en production)
