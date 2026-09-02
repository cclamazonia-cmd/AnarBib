-- B18, dernier geste : le vestige vault de la clé anon legacy disparaît.
--
-- Les clés API legacy (anon + service_role JWT) ont été DÉSACTIVÉES au
-- tableau de bord le 02/09/2026, feu vert chiffré à l'appui : zéro requête
-- service_role depuis la bascule du 01/09, et côté anon un seul onglet
-- navigateur (rechargé avant le geste) plus Googlebot rejouant son cache.
-- Contre-preuve post-clic : zéro JWT legacy et zéro 401 sur le trafic vivant.
--
-- `vault.secrets` portait encore `anarbib_staging_anon_key` — la clé anon
-- legacy copiée au coffre à l'époque où un script l'y lisait. Plus aucun
-- appelant (vérifié : ni fonction, ni script, ni EF ne lit ce nom), et la
-- valeur qu'il garde est celle d'une clé désormais refusée par la
-- passerelle : un secret mort dans un coffre est une fausse piste offerte
-- à la prochaine relecture.
--
-- Garde d'environnement : sur le banc CI et la pile auto-hébergée, vault
-- est un stub — l'absence de la table ou du secret n'est pas une erreur.

DO $$
BEGIN
  IF to_regclass('vault.secrets') IS NULL THEN
    RAISE NOTICE 'vault absent : rien à supprimer (banc CI ou pile auto-hébergée)';
    RETURN;
  END IF;

  DELETE FROM vault.secrets WHERE name = 'anarbib_staging_anon_key';

  IF EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'anarbib_staging_anon_key') THEN
    RAISE EXCEPTION 'le vestige anarbib_staging_anon_key survit à sa suppression — rollback';
  END IF;
END $$;
