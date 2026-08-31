-- =========================================================================
-- L'identité visuelle d'une bibliothèque n'a plus qu'une adresse : le bucket
-- =========================================================================
-- Date     : 2026-08-31
-- Chantier : dédoublonnage de l'identité visuelle
--
-- `libraries.logo_url` n'a plus AUCUN lecteur depuis le 30/08 : `register`
-- était sa dernière, et elle résout désormais le logo comme toutes les autres
-- fonctions, depuis `library_commons`. Vérifié avant de retirer, des deux
-- côtés que Postgres ne relie pas tout seul :
--
--   * aucune vue n'en dépend (pg_depend sur l'attribut) ;
--   * aucune fonction ne la cite (pg_proc.prosrc, commentaires retirés) —
--     `fn_provision_preactive_library` mentionne bien `logo_url`, mais dans
--     son insert `library_commons`, jamais dans celui de `libraries` ;
--   * aucun écran ne la lit : le seul `lib.logo_url` du frontend
--     (CriarContaPage) porte la valeur de `library_commons`, recopiée sur
--     l'objet quelques lignes plus haut.
--
-- CE QU'ELLE CONTENAIT, ET POURQUOI ON NE LE GARDE PAS
--
-- Trois URL : deux vers noblogs.org (BLMF, BTL), une vers le bucket (MLEG,
-- doublon exact de son `logo_file_key`). Les images noblogs ne sont pas
-- perdues — elles vivent sur le site du collectif. Ce qui part, c'est un
-- pointeur que plus personne ne suit, et qui désignait pour la BLMF et la BTL
-- une image DIFFÉRENTE de celle que l'app affiche.
--
-- La décision qui fonde ce retrait : tout ce qui touche à l'identité visuelle
-- d'une bibliothèque pointe vers le bucket `library-ui-assets`, via
-- `library_commons.logo_file_key`. Une seule adresse, un seul endroit à
-- corriger le jour où un logo change.
-- =========================================================================

BEGIN;

ALTER TABLE public.libraries DROP COLUMN IF EXISTS logo_url;

-- -------------------------------------------------------------------------
-- Vérification (doctrine)
-- -------------------------------------------------------------------------
DO $$
DECLARE v_noms text;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema='public' AND table_name='libraries'
                AND column_name='logo_url') THEN
    RAISE EXCEPTION 'libraries.logo_url est toujours la';
  END IF;

  -- Le logo de chaque biblio active doit rester atteignable par le chemin qui
  -- reste. Sans cela on aurait retire un pointeur mort ET casse l'affichage.
  SELECT string_agg(l.slug, ', ' ORDER BY l.slug) INTO v_noms
    FROM public.libraries l
    LEFT JOIN public.library_commons c ON c.library_id = l.id
   WHERE l.is_active
     AND coalesce(nullif(btrim(coalesce(c.logo_file_key, '')), ''),
                  nullif(btrim(coalesce(c.logo_url, '')), '')) IS NULL;
  IF v_noms IS NOT NULL THEN
    RAISE NOTICE 'bibliotheques actives sans logo apres retrait : % (a completer dans library_commons)', v_noms;
  END IF;
END $$;

COMMIT;
