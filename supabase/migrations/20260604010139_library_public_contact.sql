-- ============================================================================
-- library_public_contact : vitrine publique de contact d'une bibliotheque
-- Chantier "Carte ma bibliotheque cote lecteur" -- etape 1 -- 2026-06-04
-- ----------------------------------------------------------------------------
-- Surface PUBLIQUE opt-in, vide par defaut, DISTINCTE du contact confidentiel
-- de cooperation library_contact_profiles. Lue par les membres actifs de la
-- biblio ; ecrite par la coordination (user_can_manage_library) via RPC.
-- Doctrine RPC v3 : SELECT = from() protege RLS ; ecriture = RPC.
-- Helpers/colonnes verifies en base le 2026-06-04 :
--   public.user_can_manage_library(p_library_id uuid) -> boolean (INVOKER)
--   libraries.id uuid / profiles.id uuid
--   user_library_memberships(user_id uuid, library_id uuid, status text='active')
-- ============================================================================

-- 1. Table -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.library_public_contact (
  library_id      uuid PRIMARY KEY REFERENCES public.libraries(id) ON DELETE CASCADE,
  public_email    text,
  public_phone    text,
  public_whatsapp text,
  public_address  text,
  public_note     text,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  updated_by      uuid REFERENCES public.profiles(id)
);

COMMENT ON TABLE public.library_public_contact IS
  'Coordonnees publiques opt-in d''une bibliotheque, montrees a ses lecteur-rices. Distinct de library_contact_profiles (contact confidentiel cooperation inter-biblios).';

-- 2. RLS ---------------------------------------------------------------------
ALTER TABLE public.library_public_contact ENABLE ROW LEVEL SECURITY;

-- SELECT : membre ACTIF de la biblio (lecteurs + staff actifs).
DROP POLICY IF EXISTS library_public_contact_select_member ON public.library_public_contact;
CREATE POLICY library_public_contact_select_member
  ON public.library_public_contact
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.library_id = library_public_contact.library_id
      AND m.user_id    = auth.uid()
      AND m.status     = 'active'
  ));

-- INSERT : coordination uniquement.
DROP POLICY IF EXISTS library_public_contact_insert_coord ON public.library_public_contact;
CREATE POLICY library_public_contact_insert_coord
  ON public.library_public_contact
  FOR INSERT TO authenticated
  WITH CHECK (public.user_can_manage_library(library_id));

-- UPDATE : coordination uniquement.
DROP POLICY IF EXISTS library_public_contact_update_coord ON public.library_public_contact;
CREATE POLICY library_public_contact_update_coord
  ON public.library_public_contact
  FOR UPDATE TO authenticated
  USING (public.user_can_manage_library(library_id))
  WITH CHECK (public.user_can_manage_library(library_id));
-- (pas de policy DELETE : on ne supprime pas la ligne, on vide les champs.)

-- 3. Grants table (minimisation : authenticated oui, anon non) ----------------
GRANT SELECT, INSERT, UPDATE ON public.library_public_contact TO authenticated;
REVOKE ALL ON public.library_public_contact FROM anon;

-- 4. RPC d'upsert (SECURITY INVOKER : la RLS coordOnly gate l'ecriture) -------
CREATE OR REPLACE FUNCTION public.upsert_library_public_contact(
  p_library_id uuid,
  p_profile    jsonb
) RETURNS public.library_public_contact
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $fn$
DECLARE
  v_row public.library_public_contact;
BEGIN
  -- Garde de droit (defense en profondeur ; la RLS WITH CHECK gate aussi).
  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'not_authorized' USING errcode = '42501';
  END IF;

  INSERT INTO public.library_public_contact AS t (
    library_id, public_email, public_phone, public_whatsapp,
    public_address, public_note, updated_at, updated_by
  ) VALUES (
    p_library_id,
    NULLIF(p_profile->>'public_email',    ''),
    NULLIF(p_profile->>'public_phone',    ''),
    NULLIF(p_profile->>'public_whatsapp', ''),
    NULLIF(p_profile->>'public_address',  ''),
    NULLIF(p_profile->>'public_note',     ''),
    now(), auth.uid()
  )
  ON CONFLICT (library_id) DO UPDATE SET
    public_email    = NULLIF(p_profile->>'public_email',    ''),
    public_phone    = NULLIF(p_profile->>'public_phone',    ''),
    public_whatsapp = NULLIF(p_profile->>'public_whatsapp', ''),
    public_address  = NULLIF(p_profile->>'public_address',  ''),
    public_note     = NULLIF(p_profile->>'public_note',     ''),
    updated_at      = now(),
    updated_by      = auth.uid()
  RETURNING t.* INTO v_row;

  RETURN v_row;
END;
$fn$;

-- 5. Permissions fonction (doctrine #150) ------------------------------------
REVOKE EXECUTE ON FUNCTION public.upsert_library_public_contact(uuid, jsonb)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT  EXECUTE ON FUNCTION public.upsert_library_public_contact(uuid, jsonb)
  TO authenticated;

-- 6. Verification (rollback auto si echec via bloc DO) -----------------------
DO $verify$
DECLARE
  v_cnt    int;
  v_relrls boolean;
BEGIN
  -- 6.1 RLS active
  SELECT relrowsecurity INTO v_relrls
  FROM pg_class WHERE oid = 'public.library_public_contact'::regclass;
  IF NOT v_relrls THEN
    RAISE EXCEPTION 'VERIF: RLS non active sur library_public_contact';
  END IF;

  -- 6.2 Les 3 policies attendues existent
  SELECT count(*) INTO v_cnt FROM pg_policies
  WHERE schemaname='public' AND tablename='library_public_contact'
    AND policyname IN (
      'library_public_contact_select_member',
      'library_public_contact_insert_coord',
      'library_public_contact_update_coord');
  IF v_cnt <> 3 THEN
    RAISE EXCEPTION 'VERIF: % policies trouvees au lieu de 3', v_cnt;
  END IF;

  -- 6.3 La RPC existe en SECURITY INVOKER (prosecdef = false)
  PERFORM 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname='upsert_library_public_contact'
     AND p.prosecdef = false;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'VERIF: upsert_library_public_contact absente ou pas en SECURITY INVOKER';
  END IF;

  -- 6.4 Simulation PostgREST (data-independante) : un authenticated SANS
  --     membership ne voit aucune ligne (uid aleatoire -> 0 attendu).
  BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}';
    SELECT count(*) INTO v_cnt FROM public.library_public_contact;
    IF v_cnt <> 0 THEN
      RAISE EXCEPTION 'VERIF: un non-membre voit % lignes (attendu 0)', v_cnt;
    END IF;
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE EXCEPTION 'VERIF: SELECT refuse (insufficient_privilege) -- GRANT authenticated manquant ?';
  END;
  RESET ROLE;

  RAISE NOTICE 'VERIF OK: library_public_contact (table + RLS + 3 policies + RPC INVOKER + filtre SELECT).';
END;
$verify$;

-- 7. PostgREST reload --------------------------------------------------------
NOTIFY pgrst, 'reload schema';
