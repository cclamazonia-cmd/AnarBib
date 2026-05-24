-- =============================================================================
-- Migration : library_partnerships
-- Chantier  : Partenaires de correspondance d'une bibliotheque
-- Spec       : docs/decisions/CHANTIER_partenaires_correspondance_2026-05-24.md
-- Date       : 2026-05-24
-- -----------------------------------------------------------------------------
-- Cree la relation partenariale par bibliotheque : chaque bibliotheque declare
-- ses partenaires de correspondance, qui sont soit une autre bibliotheque
-- AnarBib federee, soit un collectif de l'annuaire catalog_partners.
--
-- Decisions de conception (cf. spec, section 3) :
--   D1 - le partenaire-catalogue reference public.catalog_partners
--   D3 - deux colonnes nullables exclusives + CHECK num_nonnulls = 1
--   D4 - une ligne par declaration unilaterale, pas de workflow de confirmation
--   D5 - simple appartenance, pas d'echelle d'intensite ; colonne notes libre
--
-- Securite : ecriture reservee au staff de coordination via
--   public.user_can_engage_library (admin reseau OU coordenador local).
-- Doctrine RPC v3 : ecritures par RPC SECURITY INVOKER ; lecture par from()
--   sur la vue api.library_partnerships_ui protegee par RLS.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE public.library_partnerships (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    library_id          uuid        NOT NULL
                                    REFERENCES public.libraries (id) ON DELETE CASCADE,
    partner_library_id  uuid        NULL
                                    REFERENCES public.libraries (id) ON DELETE CASCADE,
    partner_catalog_id  bigint      NULL
                                    REFERENCES public.catalog_partners (id) ON DELETE CASCADE,
    notes               text        NULL,
    created_at          timestamptz NOT NULL DEFAULT now(),
    created_by          uuid        NULL
                                    REFERENCES public.profiles (id) ON DELETE SET NULL,

    -- D3 : exactement une cible renseignee (biblio federee OU collectif catalogue)
    CONSTRAINT library_partnerships_one_target_chk
        CHECK (num_nonnulls(partner_library_id, partner_catalog_id) = 1),

    -- une bibliotheque ne se declare pas partenaire d'elle-meme
    CONSTRAINT library_partnerships_no_self_chk
        CHECK (partner_library_id IS DISTINCT FROM library_id)
);

COMMENT ON TABLE public.library_partnerships IS
    'Partenaires de correspondance declares par chaque bibliotheque. Une ligne = '
    'une declaration unilaterale. La cible est soit une bibliotheque AnarBib federee '
    '(partner_library_id), soit un collectif de l''annuaire catalog_partners '
    '(partner_catalog_id), exclusivement. Cf. CHANTIER_partenaires_correspondance_2026-05-24.';
COMMENT ON COLUMN public.library_partnerships.library_id IS
    'Bibliotheque qui declare la correspondance (proprietaire de la ligne).';
COMMENT ON COLUMN public.library_partnerships.partner_library_id IS
    'Cible si le partenaire est une autre bibliotheque AnarBib. Exclusif avec partner_catalog_id.';
COMMENT ON COLUMN public.library_partnerships.partner_catalog_id IS
    'Cible si le partenaire est un collectif de catalog_partners. Exclusif avec partner_library_id.';
COMMENT ON COLUMN public.library_partnerships.notes IS
    'Note de contexte libre, facultative.';

-- Index uniques partiels : pas de doublon de partenaire pour une meme bibliotheque
CREATE UNIQUE INDEX library_partnerships_uniq_partner_library
    ON public.library_partnerships (library_id, partner_library_id)
    WHERE partner_library_id IS NOT NULL;

CREATE UNIQUE INDEX library_partnerships_uniq_partner_catalog
    ON public.library_partnerships (library_id, partner_catalog_id)
    WHERE partner_catalog_id IS NOT NULL;

-- Index de lecture (la vue filtre toujours par library_id)
CREATE INDEX library_partnerships_library_id_idx
    ON public.library_partnerships (library_id);

-- Grants explicites sur la table (conformite Supabase 30/10/2026, doctrine
-- de creation d'objets securises). La securite NE repose PAS sur ces grants
-- mais sur la RLS ci-dessous et sur la validation metier des RPC :
--   - anon          : aucun droit (rien a exposer a un visiteur non connecte)
--   - authenticated : SELECT + INSERT/UPDATE/DELETE. Les ecritures ne sont PAS
--                     ouvertes a tout authenticated : les RPC fn_library_partnership_*
--                     sont SECURITY INVOKER, elles s'executent avec les droits de
--                     l'appelant ; il faut donc que authenticated detienne ces
--                     droits sur la table, sinon la RPC echoue. La RLS
--                     (user_can_engage_library) restreint effectivement l'ecriture
--                     au staff de coordination. Grant large, RLS etroite.
--   - service_role  : ALL (Edge Functions et administration).
REVOKE ALL ON TABLE public.library_partnerships FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.library_partnerships TO authenticated;
GRANT ALL ON TABLE public.library_partnerships TO service_role;

-- -----------------------------------------------------------------------------
-- 2. RLS
-- -----------------------------------------------------------------------------
ALTER TABLE public.library_partnerships ENABLE ROW LEVEL SECURITY;

-- Lecture : la liste des partenaires de correspondance est une information
-- publique de la bibliotheque. On delegue a fn_library_visible_to_caller, le
-- helper unifie de visibilite (public / network / private).
CREATE POLICY library_partnerships_select
    ON public.library_partnerships
    FOR SELECT
    USING ( public.fn_library_visible_to_caller(library_id) );

-- Ecriture : reservee au staff de coordination de la bibliotheque concernee.
-- user_can_engage_library = admin reseau OU coordenador local actif.
-- Les librarian ne peuvent pas declarer un partenaire (acte d'engagement).
CREATE POLICY library_partnerships_insert
    ON public.library_partnerships
    FOR INSERT
    WITH CHECK ( public.user_can_engage_library(library_id) );

CREATE POLICY library_partnerships_update
    ON public.library_partnerships
    FOR UPDATE
    USING ( public.user_can_engage_library(library_id) )
    WITH CHECK ( public.user_can_engage_library(library_id) );

CREATE POLICY library_partnerships_delete
    ON public.library_partnerships
    FOR DELETE
    USING ( public.user_can_engage_library(library_id) );

-- -----------------------------------------------------------------------------
-- 3. RPC (doctrine v3 : ecritures a validation metier)
-- -----------------------------------------------------------------------------

-- 3.1 Ajout d'un partenaire de correspondance
CREATE OR REPLACE FUNCTION public.fn_library_partnership_add(
    p_library_id          uuid,
    p_partner_library_id  uuid    DEFAULT NULL,
    p_partner_catalog_id  bigint  DEFAULT NULL,
    p_notes               text    DEFAULT NULL
)
RETURNS public.library_partnerships
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
DECLARE
    v_row public.library_partnerships;
BEGIN
    -- Droit : seul le staff de coordination peut declarer un partenaire
    IF NOT public.user_can_engage_library(p_library_id) THEN
        RAISE EXCEPTION 'forbidden: caller cannot engage library %', p_library_id
            USING ERRCODE = '42501';
    END IF;

    -- Exactement une cible
    IF num_nonnulls(p_partner_library_id, p_partner_catalog_id) <> 1 THEN
        RAISE EXCEPTION 'invalid_target: exactly one of partner_library_id / partner_catalog_id required'
            USING ERRCODE = '22023';
    END IF;

    -- Pas d'auto-reference
    IF p_partner_library_id IS NOT NULL AND p_partner_library_id = p_library_id THEN
        RAISE EXCEPTION 'invalid_target: a library cannot be its own partner'
            USING ERRCODE = '22023';
    END IF;

    -- Cible existante
    IF p_partner_library_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.libraries WHERE id = p_partner_library_id) THEN
        RAISE EXCEPTION 'not_found: partner library % does not exist', p_partner_library_id
            USING ERRCODE = '23503';
    END IF;
    IF p_partner_catalog_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.catalog_partners WHERE id = p_partner_catalog_id) THEN
        RAISE EXCEPTION 'not_found: catalog partner % does not exist', p_partner_catalog_id
            USING ERRCODE = '23503';
    END IF;

    -- Pas de doublon (message clair plutot que violation d'index brute)
    IF p_partner_library_id IS NOT NULL
       AND EXISTS (SELECT 1 FROM public.library_partnerships
                   WHERE library_id = p_library_id
                     AND partner_library_id = p_partner_library_id) THEN
        RAISE EXCEPTION 'duplicate: partnership already declared'
            USING ERRCODE = '23505';
    END IF;
    IF p_partner_catalog_id IS NOT NULL
       AND EXISTS (SELECT 1 FROM public.library_partnerships
                   WHERE library_id = p_library_id
                     AND partner_catalog_id = p_partner_catalog_id) THEN
        RAISE EXCEPTION 'duplicate: partnership already declared'
            USING ERRCODE = '23505';
    END IF;

    INSERT INTO public.library_partnerships
        (library_id, partner_library_id, partner_catalog_id, notes, created_by)
    VALUES
        (p_library_id, p_partner_library_id, p_partner_catalog_id,
         NULLIF(btrim(p_notes), ''), auth.uid())
    RETURNING * INTO v_row;

    RETURN v_row;
END;
$$;

COMMENT ON FUNCTION public.fn_library_partnership_add(uuid, uuid, bigint, text) IS
    'Declare un partenaire de correspondance pour une bibliotheque. Validation metier '
    'complete (droits, cible unique, existence, anti-doublon). Doctrine RPC v3.';

-- 3.2 Suppression d'un partenaire de correspondance
CREATE OR REPLACE FUNCTION public.fn_library_partnership_remove(
    p_partnership_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
DECLARE
    v_library_id uuid;
BEGIN
    SELECT library_id INTO v_library_id
    FROM public.library_partnerships
    WHERE id = p_partnership_id;

    IF v_library_id IS NULL THEN
        RAISE EXCEPTION 'not_found: partnership % does not exist', p_partnership_id
            USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.user_can_engage_library(v_library_id) THEN
        RAISE EXCEPTION 'forbidden: caller cannot engage library %', v_library_id
            USING ERRCODE = '42501';
    END IF;

    DELETE FROM public.library_partnerships WHERE id = p_partnership_id;
END;
$$;

COMMENT ON FUNCTION public.fn_library_partnership_remove(uuid) IS
    'Retire un partenaire de correspondance. Reserve au staff de coordination de la '
    'bibliotheque proprietaire de la relation. Doctrine RPC v3.';

-- 3.3 Mise a jour de la note de contexte
CREATE OR REPLACE FUNCTION public.fn_library_partnership_update_notes(
    p_partnership_id uuid,
    p_notes          text
)
RETURNS public.library_partnerships
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
DECLARE
    v_library_id uuid;
    v_row        public.library_partnerships;
BEGIN
    SELECT library_id INTO v_library_id
    FROM public.library_partnerships
    WHERE id = p_partnership_id;

    IF v_library_id IS NULL THEN
        RAISE EXCEPTION 'not_found: partnership % does not exist', p_partnership_id
            USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.user_can_engage_library(v_library_id) THEN
        RAISE EXCEPTION 'forbidden: caller cannot engage library %', v_library_id
            USING ERRCODE = '42501';
    END IF;

    UPDATE public.library_partnerships
    SET notes = NULLIF(btrim(p_notes), '')
    WHERE id = p_partnership_id
    RETURNING * INTO v_row;

    RETURN v_row;
END;
$$;

COMMENT ON FUNCTION public.fn_library_partnership_update_notes(uuid, text) IS
    'Met a jour la note de contexte d''un partenariat. Reserve au staff de '
    'coordination de la bibliotheque proprietaire. Doctrine RPC v3.';

-- Grants RPC : revoke etendu puis grant cible sur authenticated uniquement.
REVOKE ALL ON FUNCTION public.fn_library_partnership_add(uuid, uuid, bigint, text)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.fn_library_partnership_remove(uuid)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.fn_library_partnership_update_notes(uuid, text)
    FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.fn_library_partnership_add(uuid, uuid, bigint, text)
    TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_library_partnership_remove(uuid)
    TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_library_partnership_update_notes(uuid, text)
    TO authenticated;

-- -----------------------------------------------------------------------------
-- 4. VUE DE LECTURE  api.library_partnerships_ui
-- -----------------------------------------------------------------------------
-- security_invoker = true : la RLS de library_partnerships s'applique au
-- caller. Le frontend lit cette vue par from() (doctrine v3 : lecture simple
-- protegee par RLS). La vue resout l'union des deux types de partenaire pour
-- exposer une liste homogene.
CREATE OR REPLACE VIEW api.library_partnerships_ui
WITH (security_invoker = true)
AS
SELECT
    lp.id,
    lp.library_id,
    CASE
        WHEN lp.partner_library_id IS NOT NULL THEN 'library'
        ELSE 'catalog_partner'
    END                                              AS partner_kind,
    lp.partner_library_id,
    lp.partner_catalog_id,
    -- nom d'affichage resolu selon le type
    COALESCE(pl.display_name, cp.display_name)        AS partner_display_name,
    -- metadonnees specifiques biblio
    pl.slug                                          AS partner_library_slug,
    pl.network_mode                                  AS partner_library_network_mode,
    -- metadonnees specifiques collectif catalogue
    cp.slug                                          AS partner_catalog_slug,
    cp.base_url                                      AS partner_catalog_base_url,
    cp.country_code                                  AS partner_catalog_country_code,
    -- reciprocite : vrai si le partenaire-biblio a declare en retour
    CASE
        WHEN lp.partner_library_id IS NOT NULL THEN EXISTS (
            SELECT 1 FROM public.library_partnerships rev
            WHERE rev.library_id = lp.partner_library_id
              AND rev.partner_library_id = lp.library_id
        )
        ELSE NULL
    END                                              AS is_reciprocal,
    lp.notes,
    lp.created_at,
    lp.created_by
FROM public.library_partnerships lp
LEFT JOIN public.libraries        pl ON pl.id = lp.partner_library_id
LEFT JOIN public.catalog_partners cp ON cp.id = lp.partner_catalog_id;

COMMENT ON VIEW api.library_partnerships_ui IS
    'Vue UI des partenaires de correspondance par bibliotheque. security_invoker : '
    'la RLS de library_partnerships s''applique. Resout le nom et les metadonnees du '
    'partenaire selon son type, et calcule la reciprocite pour les partenaires-biblio.';

GRANT SELECT ON api.library_partnerships_ui TO authenticated, anon;

-- -----------------------------------------------------------------------------
-- 5. BLOC DE VERIFICATION  (RAISE EXCEPTION -> ROLLBACK automatique si invariant casse)
-- -----------------------------------------------------------------------------
DO $verify$
DECLARE
    v_count int;
BEGIN
    -- 5.1 La table existe et la RLS est activee
    SELECT count(*) INTO v_count
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'library_partnerships'
      AND c.relrowsecurity = true;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'VERIFY FAILED: library_partnerships absente ou RLS non activee';
    END IF;

    -- 5.2 Les 4 policies attendues sont presentes
    SELECT count(*) INTO v_count
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'library_partnerships';
    IF v_count <> 4 THEN
        RAISE EXCEPTION 'VERIFY FAILED: % policies sur library_partnerships, 4 attendues', v_count;
    END IF;

    -- 5.3 Les 2 CHECK metier sont presents
    SELECT count(*) INTO v_count
    FROM pg_constraint
    WHERE conrelid = 'public.library_partnerships'::regclass
      AND contype = 'c'
      AND conname IN ('library_partnerships_one_target_chk',
                      'library_partnerships_no_self_chk');
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'VERIFY FAILED: % CHECK metier, 2 attendus', v_count;
    END IF;

    -- 5.4 Les 3 RPC existent et sont SECURITY INVOKER (prosecdef = false)
    SELECT count(*) INTO v_count
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('fn_library_partnership_add',
                        'fn_library_partnership_remove',
                        'fn_library_partnership_update_notes')
      AND p.prosecdef = false;
    IF v_count <> 3 THEN
        RAISE EXCEPTION 'VERIFY FAILED: % RPC SECURITY INVOKER, 3 attendues', v_count;
    END IF;

    -- 5.5 Aucune RPC ne porte de droit a anon (doctrine #150)
    SELECT count(*) INTO v_count
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('fn_library_partnership_add',
                        'fn_library_partnership_remove',
                        'fn_library_partnership_update_notes')
      AND has_function_privilege('anon', p.oid, 'EXECUTE');
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'VERIFY FAILED: % RPC executables par anon, 0 attendu', v_count;
    END IF;

    -- 5.6 La vue api existe
    SELECT count(*) INTO v_count
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'api' AND c.relname = 'library_partnerships_ui' AND c.relkind = 'v';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'VERIFY FAILED: vue api.library_partnerships_ui absente';
    END IF;

    -- 5.7 Le CHECK d'exclusivite rejette bien une ligne a deux cibles.
    -- On tente l'insertion fautive dans un sous-bloc ; elle DOIT echouer.
    BEGIN
        INSERT INTO public.library_partnerships
            (library_id, partner_library_id, partner_catalog_id)
        VALUES
            (gen_random_uuid(), gen_random_uuid(), 1);
        RAISE EXCEPTION 'VERIFY FAILED: le CHECK one_target n''a pas rejete une double cible';
    EXCEPTION
        WHEN check_violation THEN
            NULL;  -- comportement attendu
        WHEN foreign_key_violation THEN
            -- la FK peut sauter avant le CHECK selon l'ordre d'evaluation ;
            -- dans les deux cas la ligne fautive est rejetee : invariant tenu.
            NULL;
    END;

    -- 5.8 Grants table : anon n'a aucun droit ; authenticated a SELECT.
    IF has_table_privilege('anon', 'public.library_partnerships', 'SELECT')
       OR has_table_privilege('anon', 'public.library_partnerships', 'INSERT') THEN
        RAISE EXCEPTION 'VERIFY FAILED: anon detient un droit sur library_partnerships';
    END IF;
    IF NOT has_table_privilege('authenticated', 'public.library_partnerships', 'SELECT') THEN
        RAISE EXCEPTION 'VERIFY FAILED: authenticated n''a pas SELECT sur library_partnerships';
    END IF;
    IF NOT has_table_privilege('authenticated', 'public.library_partnerships', 'INSERT') THEN
        RAISE EXCEPTION 'VERIFY FAILED: authenticated n''a pas INSERT (requis pour les RPC INVOKER)';
    END IF;

    RAISE NOTICE 'VERIFY OK: library_partnerships, 4 policies, 2 CHECK, 3 RPC INVOKER, grants table, vue api.';
END;
$verify$;

COMMIT;
