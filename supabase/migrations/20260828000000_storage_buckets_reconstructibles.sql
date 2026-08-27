-- =============================================================================
-- Les seize buckets deviennent reconstructibles depuis le dépôt
-- =============================================================================
-- Date     : 2026-08-28
-- Chantier : hébergement / bascule auto-hébergée
--
-- CE QUE LA RÉPÉTITION DU 27/08 A TROUVÉ.
--
-- `bootstrap.sh --depuis-le-depot` s'est arrêté à la migration 139/200,
-- `20260820230000_plafonds_buckets_numerisation.sql` :
--
--   ERROR: Buckets introuvables : covers, anarbib-media-restricted, …
--
-- La cause n'est pas cette migration. Elle est en amont, et elle est plus
-- grave : **aucune migration du dépôt ne crée de bucket.** Les seize buckets de
-- la production ont été créés à la main, par le tableau de bord Supabase. Ils
-- n'existent donc nulle part ailleurs que dans la production elle-même.
--
-- Conséquence : une pile reconstruite depuis le dépôt démarre avec un schéma
-- `storage` complet et **zéro bucket**. Le catalogue s'affiche, et il n'a ni
-- couverture, ni PDF, ni EPUB, ni portrait d'auteur·rice. La migration des
-- plafonds a seulement eu le mérite d'être assez bruyante pour le dire — sans
-- elle, la pile serait montée en silence, et le trou se serait découvert au
-- premier clic sur une couverture manquante.
--
-- C'est le même défaut de fond que celui du 26/08 sur les fichiers physiques :
-- ce qui n'est pas dans le dépôt n'existe pas au rejeu. Ici on ferme la partie
-- « déclaration des buckets » ; les OBJETS eux-mêmes (~450 Mo) restent hors
-- dépôt et se remettent après la base, cf. l'en-tête de deploy/bootstrap.sh.
--
-- -----------------------------------------------------------------------------
-- PORTÉE ET INNOCUITÉ
-- -----------------------------------------------------------------------------
-- * `on conflict (id) do nothing` : **sur la production, cette migration ne fait
--   rien.** Les seize buckets y existent déjà, avec ces valeurs exactes — elles
--   ont été relevées depuis la production le 27/08, pas recopiées d'un fichier.
-- * Aucune policy n'est touchée : les policies de `storage.objects` sont posées
--   ailleurs et ne dépendent pas de cette insertion.
-- * Aucune table créée dans `public` : `bg2-known-tables.txt` ne bouge pas.
--
-- ⚠️ CE QUI RESTE HORS DE PORTÉE. Le caractère `public` d'un bucket décide de la
-- lisibilité anonyme des objets. Les valeurs ci-dessous reproduisent la
-- production ; les modifier ici change une frontière de confidentialité, pas un
-- réglage de confort. Ne pas « harmoniser » sans arbitrage.
-- =============================================================================

begin;

do $$
declare
  v_cree int;
  v_total int;
begin

  -- ---------------------------------------------------------------------------
  -- Garde : sans le schéma storage, on ne fait rien, et on le dit.
  -- ---------------------------------------------------------------------------
  -- Cas attendu : harnais sql-tests d'avant le stub storage, ou pile dont le
  -- service Storage n'a pas encore démarré.
  if to_regclass('storage.buckets') is null then
    raise notice
      'storage.buckets absent : buckets NON créés. deploy/bootstrap.sh démarre Storage avant les migrations (étape 4/8) ; hors de ce cadre, rejouer ce fichier une fois le service levé.';
    return;
  end if;

  -- ---------------------------------------------------------------------------
  -- 1. Déclaration des seize buckets
  -- ---------------------------------------------------------------------------
  -- Relevé de la production le 27/08/2026. Le plafond PDF est bien à 500 Mo :
  -- il a été relevé de 300 à 500 le 20/08 pour les recueils illustrés
  -- (20260820012512), et c'est cette valeur-là qui fait foi.
  insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values
    ('anarbib-carte-rede',        'anarbib-carte-rede',        false,   5242880, array['application/json', 'application/geo+json']),
    ('anarbib-epub-public',       'anarbib-epub-public',       true,   52428800, array['application/epub+zip']),
    ('anarbib-epub-restricted',   'anarbib-epub-restricted',   false,  52428800, array['application/epub+zip']),
    ('anarbib-media-public',      'anarbib-media-public',      true,  524288000, array['audio/mpeg', 'audio/ogg', 'audio/flac', 'audio/wav']),
    ('anarbib-media-restricted',  'anarbib-media-restricted',  false, 524288000, array['audio/mpeg', 'audio/ogg', 'audio/flac', 'audio/wav']),
    ('anarbib-pdf-public',        'anarbib-pdf-public',        true,  524288000, array['application/pdf']),
    ('pdf-restrito',              'pdf-restrito',              false, 524288000, array['application/pdf']),
    ('covers',                    'covers',                    true,   10485760, array['image/jpeg', 'image/png', 'image/webp']),
    ('authors',                   'authors',                   true,   10485760, array['image/jpeg', 'image/png', 'image/webp']),
    ('library-privacy-public',    'library-privacy-public',    true,     524288, array['text/markdown', 'text/plain']),
    ('library-regimentos-public', 'library-regimentos-public', true,       null, null),
    ('library-regimentos-private','library-regimentos-private',false,      null, null),
    ('library-ui-assets',         'library-ui-assets',         true,       null, null),
    ('network-map',               'network-map',               false,      null, null),
    ('catalogos_parceiros_raw',   'catalogos_parceiros_raw',   false,      null, null),
    ('partner-catalog-deposits',  'partner-catalog-deposits',  false,  52428800, array[
        'text/csv', 'text/tab-separated-values', 'text/plain',
        'application/json', 'application/xml', 'text/xml', 'application/marc',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.oasis.opendocument.spreadsheet',
        'application/zip', 'application/pdf', 'application/octet-stream'])
  on conflict (id) do nothing;

  get diagnostics v_cree = row_count;
  select count(*) into v_total from storage.buckets;

  if v_cree = 0 then
    raise notice 'Les seize buckets existaient déjà : rien créé (cas de la production).';
  else
    raise notice 'Buckets créés : % (total en base : %).', v_cree, v_total;
  end if;

  -- ---------------------------------------------------------------------------
  -- 2. Vérification — rollback automatique si un bucket manque encore
  -- ---------------------------------------------------------------------------
  -- Ici, contrairement à 20260820230000, l'absence n'est plus tolérable : on
  -- vient de les insérer. S'il en manque un, c'est que l'insertion a été
  -- refusée, et il vaut mieux le savoir tout de suite.
  if exists (
    select 1 from unnest(array[
      'anarbib-carte-rede','anarbib-epub-public','anarbib-epub-restricted',
      'anarbib-media-public','anarbib-media-restricted','anarbib-pdf-public',
      'pdf-restrito','covers','authors','library-privacy-public',
      'library-regimentos-public','library-regimentos-private',
      'library-ui-assets','network-map','catalogos_parceiros_raw',
      'partner-catalog-deposits']) a
     where not exists (select 1 from storage.buckets b where b.id = a)
  ) then
    raise exception 'Bucket manquant après insertion — vérifier les droits sur storage.buckets.';
  end if;

end $$;

commit;

-- =============================================================================
-- CONTRÔLE APRÈS DÉPLOIEMENT
-- =============================================================================
--   select count(*) from storage.buckets;                    -- attendu : 16
--   select id, public, file_size_limit from storage.buckets order by id;
--
-- Sur la production, le compte ne doit PAS bouger : cette migration y est
-- inerte. Sur une pile reconstruite, elle est ce qui rend Storage utilisable.
