-- =============================================================================
-- Plafonds de taille et types autorises sur les buckets de numerisation
-- =============================================================================
-- Date     : 2026-08-20
-- Chantier : hebergement / dimensionnement disque
--
-- PROBLEME. Sur les seize buckets, un seul porte une limite :
-- library-privacy-public (512 ko, text/markdown et text/plain). Les buckets
-- lourds — PDF, EPUB, media, couvertures — n'ont ni file_size_limit ni
-- allowed_mime_types. Rien ne borne donc techniquement la croissance du
-- disque, au moment meme ou cette croissance est l'objet de la demande
-- d'hebergement (20 Go pour demarrer, jusqu'a 50 Go a trois-cinq ans).
--
-- Ce n'est pas une faille : les policies decident QUI depose. C'est une
-- absence de garde-fou sur COMBIEN. Un versement accidentel de plusieurs
-- gigaoctets passe aujourd'hui sans rien declencher, et se decouvre a la
-- facture ou a la sauvegarde suivante.
--
-- SOLUTION. Un plafond par famille et une liste blanche de types. Le plafond
-- protege de l'accident, il ne tranche pas la politique de numerisation :
-- c'est le profil de numerisation (bitonal par defaut, gris ou couleur page a
-- page) qui decide du poids reel d'un ouvrage. Si ce profil autorise la
-- couleur sur des ouvrages entiers, les 300 Mo des PDF se rediscutent.
--
-- PORTEE. Aucune table creee, aucune fonction, aucune policy touchee : cette
-- migration ne fait que renseigner deux colonnes de storage.buckets.
-- bg2-known-tables.txt n'a donc pas a bouger.
--
-- LIMITE ASSUMEE. allowed_mime_types se fie au type declare par le client au
-- depot. Ce n'est pas une inspection du contenu. Contre un versement
-- malveillant, ce sont les policies qui protegent ; ici on borne l'accident.
--
-- A CONFIRMER AVANT DEPOT : les buckets anarbib-media-* n'acceptent que de
-- l'audio dans cette version. Si de la video y est attendue, decommenter les
-- types video plus bas — sinon les depots seront refuses.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Documents PDF — 300 Mo
-- -----------------------------------------------------------------------------
-- Un ouvrage numerise en bitonal tient dans quelques dizaines de Mo. 300 Mo
-- laisse passer un scan en gris genereux et arrete un versement aberrant.
update storage.buckets
   set file_size_limit   = 314572800,
       allowed_mime_types = array['application/pdf']
 where id in ('anarbib-pdf-public', 'pdf-restrito');

-- -----------------------------------------------------------------------------
-- 2. Livres numeriques EPUB — 50 Mo
-- -----------------------------------------------------------------------------
update storage.buckets
   set file_size_limit   = 52428800,
       allowed_mime_types = array['application/epub+zip']
 where id in ('anarbib-epub-public', 'anarbib-epub-restricted');

-- -----------------------------------------------------------------------------
-- 3. Media sonores — 500 Mo
-- -----------------------------------------------------------------------------
-- Un enregistrement long en FLAC depasse facilement 300 Mo, d'ou le plafond
-- plus haut que celui des PDF.
update storage.buckets
   set file_size_limit   = 524288000,
       allowed_mime_types = array[
         'audio/mpeg',
         'audio/ogg',
         'audio/flac',
         'audio/wav'
         -- , 'video/mp4', 'video/webm'   -- decommenter si de la video est attendue
       ]
 where id in ('anarbib-media-public', 'anarbib-media-restricted');

-- -----------------------------------------------------------------------------
-- 4. Couvertures et portraits — 10 Mo
-- -----------------------------------------------------------------------------
update storage.buckets
   set file_size_limit   = 10485760,
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
 where id in ('covers', 'authors');

-- -----------------------------------------------------------------------------
-- 5. Verification — rollback automatique si un bucket vise reste sans plafond
-- -----------------------------------------------------------------------------
do $$
declare
  v_manquants text;
  v_attendus  text[] := array[
    'anarbib-pdf-public', 'pdf-restrito',
    'anarbib-epub-public', 'anarbib-epub-restricted',
    'anarbib-media-public', 'anarbib-media-restricted',
    'covers', 'authors'
  ];
  v_absents   text;
begin
  -- 5.1 Tous les buckets vises existent-ils encore ?
  select string_agg(a, ', ')
    into v_absents
    from unnest(v_attendus) a
   where not exists (select 1 from storage.buckets b where b.id = a);

  if v_absents is not null then
    raise exception
      'Buckets introuvables : %. Le nom a change ou le bucket a ete supprime — verifier avant de rejouer.',
      v_absents;
  end if;

  -- 5.2 Chacun porte-t-il bien un plafond ET une liste blanche ?
  select string_agg(b.id, ', ')
    into v_manquants
    from storage.buckets b
   where b.id = any(v_attendus)
     and (b.file_size_limit is null or b.allowed_mime_types is null);

  if v_manquants is not null then
    raise exception
      'Plafond ou liste de types manquant apres migration : %. Rollback automatique.',
      v_manquants;
  end if;

  raise notice 'Plafonds poses sur % buckets.', array_length(v_attendus, 1);
end $$;

commit;

-- =============================================================================
-- Rollback ciblé en cas de régression post-déploiement :
-- =============================================================================
-- begin;
--   update storage.buckets
--      set file_size_limit = null, allowed_mime_types = null
--    where id in ('anarbib-pdf-public','pdf-restrito',
--                 'anarbib-epub-public','anarbib-epub-restricted',
--                 'anarbib-media-public','anarbib-media-restricted',
--                 'covers','authors');
-- commit;
-- =============================================================================
--
-- NON TOUCHES, et pourquoi :
--   library-privacy-public      deja borne (512 ko, markdown/plain)
--   anarbib-carte-rede          deja borne (5 Mo, json/geojson)
--   partner-catalog-deposits    deja borne (50 Mo, liste de types longue)
--   library-regimentos-public   a borner aussi ? Un reglement interieur est
--   library-regimentos-private  petit ; un plafond de 20 Mo serait raisonnable,
--                               mais il n'a pas ete arbitre — laisse en l'etat.
--   library-ui-assets           logos et fragments d'interface, meme question.
--   network-map, catalogos_parceiros_raw, import : hors perimetre numerisation.
-- =============================================================================
