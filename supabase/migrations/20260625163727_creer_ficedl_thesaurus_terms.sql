-- =========================================================================
-- Thésaurus partagé FICEDL — table-cache des descripteurs-sujets (P1)
-- =========================================================================
-- Date     : 2026-06-25
-- Chantier : Intégration thésaurus FICEDL comme vocabulaire-sujets (anti-fork)
-- Auteur   : AnarBib
-- Session  : Intégration thésaurus FICEDL P1 (table-cache + seed)
--
-- OBJET
--   Cache RÉ-ASPIRABLE du thésaurus partagé FICEDL (https://thesaurus.ficedl.info).
--   La SOURCE DE VÉRITÉ reste le SPIP FICEDL : AnarBib ne fait que CACHER une copie
--   (politique ANTI-FORK absolue). Les libellés s'affichent TELS QU'ASPIRÉS, sans
--   application de la charte de langage inclusif d'AnarBib (qui régit l'UI propre,
--   pas le vocabulaire partagé). Aucune ré-écriture de libellé.
--
--   La table est alimentée HORS de cette migration, par scripts/ficedl_thesaurus_sync.mjs
--   (upsert via service_role). Ce script sert aussi de mécanisme de re-sync (P4).
--
-- CHECKLIST DOCTRINE (cf. docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md)
--   [x] Création de table dans public :
--       [x] GRANT SELECT explicites (anon + authenticated) — catalogue public
--       [x] GRANT ALL TO service_role (alimentation hors RLS)
--       [x] ALTER TABLE ... ENABLE ROW LEVEL SECURITY
--       [x] Policy SELECT publique (USING true) ; AUCUNE policy write → écriture
--           réservée au service_role qui bypass la RLS (anti-fork : pas d'écriture
--           depuis l'app)
--       [x] DO block de vérification anon/authenticated en fin de transaction
-- =========================================================================

BEGIN;

CREATE TABLE public.ficedl_thesaurus_terms (
  mot_id                text        PRIMARY KEY,                   -- 'mot44' = identifiant FICEDL = clé de fédération
  facet                 text[]      NOT NULL,                      -- {sujets} | {geo} | {sujets,geo}
  labels                jsonb       NOT NULL,                      -- {fr,ca,de,el,en,eo,es,it,nl,pt} (creux : langues manquantes laissées en l'état)
  el_roman              text,                                      -- romanisation du grec (absente sur quelques fiches)
  hierarchy             jsonb       NOT NULL DEFAULT '[]'::jsonb,  -- chaîne hiérarchique du descripteur
  depth                 int,                                       -- profondeur dans la hiérarchie
  catalog_links         jsonb       NOT NULL DEFAULT '[]'::jsonb,  -- liens catalogues partenaires (fédération réciproque, P3)
  import_normalizations jsonb       NOT NULL DEFAULT '[]'::jsonb,  -- journal anti-fork : re-routage de balises de langue erronées (libellé inchangé)
  import_flags          jsonb       NOT NULL DEFAULT '[]'::jsonb,  -- signaux d'audit par terme (eq_fr, english_leak, de_no_caps…) — diagnostic, à remonter À LA SOURCE
  source_url            text        NOT NULL,                      -- URL canonique de la fiche sur le SPIP FICEDL
  harvested_at          timestamptz NOT NULL DEFAULT now()         -- horodatage de la dernière aspiration (fixé par le script de sync)
);

-- Catalogue public : lisible par tous (anon + authenticated). Pas d'index en P1
-- (~462 lignes, la PK suffit) ; GIN sur facet/labels viendra en P3 avec l'UI.
GRANT SELECT ON public.ficedl_thesaurus_terms TO anon;
GRANT SELECT ON public.ficedl_thesaurus_terms TO authenticated;
GRANT ALL    ON public.ficedl_thesaurus_terms TO service_role;

ALTER TABLE public.ficedl_thesaurus_terms ENABLE ROW LEVEL SECURITY;

-- Lecture publique. AUCUNE policy d'écriture : seul le service_role (qui bypass la
-- RLS) alimente la table → l'application ne peut JAMAIS modifier le vocabulaire
-- partagé (garantie anti-fork au niveau base).
CREATE POLICY "ficedl_thesaurus_terms_select_public"
  ON public.ficedl_thesaurus_terms
  FOR SELECT
  TO anon, authenticated
  USING (true);

COMMENT ON TABLE public.ficedl_thesaurus_terms IS
  'Cache ré-aspirable du thésaurus partagé FICEDL (thesaurus.ficedl.info). '
  'Source de vérité = SPIP FICEDL ; AnarBib ne fait que CACHER (anti-fork absolu, '
  'libellés tels qu''aspirés, jamais ré-écrits). Écriture réservée au service_role '
  'via scripts/ficedl_thesaurus_sync.mjs. Créé en P1 le 25/06/2026.';

COMMENT ON COLUMN public.ficedl_thesaurus_terms.mot_id IS
  'Identifiant FICEDL (« mot44 ») = clé de fédération entre catalogues partenaires.';
COMMENT ON COLUMN public.ficedl_thesaurus_terms.labels IS
  'Libellés par locale {fr,ca,de,el,en,eo,es,it,nl,pt}, TELS QU''ASPIRÉS. JSON creux : '
  'une langue manquante à la source est absente, jamais fabriquée.';
COMMENT ON COLUMN public.ficedl_thesaurus_terms.import_normalizations IS
  'Journal anti-fork : balises de langue manifestement erronées re-routées vers la '
  'bonne case À L''IMPORT, libellé INCHANGÉ. À remonter au/à la mainteneur·euse FICEDL.';
COMMENT ON COLUMN public.ficedl_thesaurus_terms.import_flags IS
  'Signaux d''audit par terme (eq_fr, english_leak, de_no_caps, pt_old_ortho…). '
  'Purement diagnostique : aucune correction appliquée (anti-fork).';

-- -------------------------------------------------------------------------
-- Vérification : la table est lisible en contexte anon ET authenticated.
-- (Le seed est séparé : on n'impose pas de seuil de lignes ici.)
-- -------------------------------------------------------------------------
DO $$
DECLARE
  v_count int;
BEGIN
  SET LOCAL ROLE anon;
  SET LOCAL "request.jwt.claims" = '{}';
  SELECT count(*) INTO v_count FROM public.ficedl_thesaurus_terms;
  RESET ROLE;

  SET LOCAL ROLE authenticated;
  SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}';
  PERFORM count(*) FROM public.ficedl_thesaurus_terms;
  RESET ROLE;

  RAISE NOTICE 'ficedl_thesaurus_terms : table créée et lisible (anon = % lignes avant seed).', v_count;
END $$;

-- Recharge le cache de schéma PostgREST (nouvelle table exposée via la Data API).
NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback ciblé (à adapter) :
-- =========================================================================
-- BEGIN;
--   DROP TABLE IF EXISTS public.ficedl_thesaurus_terms;
--   NOTIFY pgrst, 'reload schema';
-- COMMIT;
-- =========================================================================
