-- ===========================================================================
-- Un document restreint ne vit jamais dans un bucket public
-- ===========================================================================
--
-- CE QUE CETTE SUITE GARDE. Le paquet 10 de `B14` a audité la chaîne complète
-- d'accès aux documents numériques, et elle est saine — en trois étages :
--
--   1. la RPC `get_accessible_digital_asset_by_id_v2` décide, **avec le JWT de
--      l'appelante** : `publico` pour tout le monde, `conta_ativa` seulement
--      pour un compte actif membre d'une bibliothèque détentrice ;
--   2. l'Edge Function `read-digital-asset` signe alors l'URL **en
--      service_role** (TTL court) — la policy storage n'est pas le portier du
--      lectorat, la RPC l'est ;
--   3. le PEB numérique (`fn_ill_signed_url`) revalide le droit de partenariat
--      **au moment de l'accès** : un droit révoqué coupe l'accès aux reçus déjà
--      transmis (PARTNER-D5).
--
-- Cette chaîne a un talon, et il n'est gardé par rien d'autre que cette suite :
-- **le rangement**. Un asset `conta_ativa` catalogué par erreur dans un bucket
-- `public = true` serait servi par l'URL publique du bucket, sans passer par la
-- RPC ni par l'EF — mondialement lisible, et silencieusement, puisque le
-- parcours « normal » via l'EF continuerait de fonctionner. De même, une seule
-- bascule du flag `public` d'un bucket restreint exposerait tout son contenu
-- d'un coup.
--
-- Le talon n'est pas hypothétique : ce qui rend l'exposition silencieuse, c'est
-- précisément que rien ne casse quand elle se produit.
-- ===========================================================================

DO $$
DECLARE
  v_passed  int := 0;
  v_failed  int := 0;
  v_failures text[] := '{}';
  v_t text;
  v_reste text;
  v_n int;
BEGIN
  -- ---------------------------------------------------------------------
  -- T1 — aucun asset restreint dans un bucket public
  -- ---------------------------------------------------------------------
  v_t := 'T1 aucun asset non-publico ne vit dans un bucket public';
  BEGIN
    SELECT string_agg(r.id::text || ' (' || r.storage_bucket || ')', ', ') INTO v_reste
      FROM public.book_digital_resources r
      JOIN storage.buckets b ON b.id = r.storage_bucket
     WHERE r.access_scope <> 'publico'
       AND r.status = 'active' AND COALESCE(r.is_active, false)
       AND b.public;

    IF v_reste IS NULL THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : exposes -> ' || v_reste
        || ' | un bucket public sert ses fichiers par URL directe, sans RPC ni'
        || ' EF : le document restreint est mondialement lisible, et rien ne'
        || ' casse — le parcours normal continue de fonctionner');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T2 — les buckets restreints le restent
  -- ---------------------------------------------------------------------
  -- Une seule bascule du flag `public` exposerait tout le contenu d'un coup,
  -- et elle se fait en un clic de dashboard.
  v_t := 'T2 les trois buckets restreints ont public=false';
  BEGIN
    SELECT string_agg(id, ', ') INTO v_reste
      FROM storage.buckets
     WHERE id IN ('pdf-restrito','anarbib-media-restricted','anarbib-epub-restricted')
       AND public;

    IF v_reste IS NULL THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : devenus publics -> ' || v_reste);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T3 — la RPC d'accès garde ses deux conditions pour conta_ativa
  -- ---------------------------------------------------------------------
  -- L'EF signe en service_role tout ce que la RPC rend : si la RPC perdait une
  -- de ses conditions, l'EF signerait pour tout le monde. Le portier du
  -- lectorat, c'est ELLE.
  v_t := 'T3 get_accessible_digital_asset_by_id_v2 garde compte actif ET rattachement';
  BEGIN
    SELECT count(*) INTO v_n
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname = 'get_accessible_digital_asset_by_id_v2'
       AND p.prosrc ~ 'fn_current_user_conta_ativa'
       AND p.prosrc ~ 'fn_current_user_is_member_of_holding_library';

    IF v_n = 1 THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : condition perdue'
        || ' | l''EF read-digital-asset signe en service_role tout ce que cette'
        || ' RPC rend — sans ses deux conditions, elle signe pour tout le monde');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T4 — le PEB numérique revalide le droit AU MOMENT de l'accès
  -- ---------------------------------------------------------------------
  -- C'est la propriété qui rend le droit `digital_share` RÉVOCABLE
  -- (PARTNER-D5) : rompre le partenariat coupe l'accès aux reçus déjà
  -- transmis. Sans cette ligne, un reçu resterait lisible pour toujours.
  v_t := 'T4 fn_ill_signed_url revalide le droit de partenariat a l acces';
  BEGIN
    SELECT count(*) INTO v_n
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname = 'fn_ill_signed_url'
       AND p.prosrc ~ 'fn_partnership_has_active_right'
       AND p.prosrc ~ 'user_can_act_as_staff_on_library';

    IF v_n = 1 THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : revalidation perdue'
        || ' | le droit digital_share cesserait d''etre revocable — un'
        || ' partenariat rompu laisserait ses recus lisibles pour toujours');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- =====================================================================
  -- BILAN
  -- =====================================================================
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'DOCUMENTS_NUMERIQUES OK : %/% tests passés (0 skips)',
      v_passed, (v_passed + v_failed);
  ELSE
    RAISE EXCEPTION 'DOCUMENTS_NUMERIQUES ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed + v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
