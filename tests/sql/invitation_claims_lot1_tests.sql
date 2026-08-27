-- =====================================================================
-- AnarBib — Tests d'acceptation : invitation d'une bibliotheque, LOT 1
-- Date    : 2026-08-27  ·  Session : chantier invitation (option A)
-- Ref     : migration 20260827120000_invitation_claims_lot1_schema
--           docs/journal/cadrages/CADRAGE_invitation_bibliotheque_2026-08-27.md
--
-- Ce lot rend library_request_claims.user_id nullable. Ces tests gardent le
-- fait que la garantie perdue a bien ete REMPLACEE et non abandonnee : un
-- claim d'auto-candidature doit toujours porter son compte, seule une
-- invitation a le droit d'attendre. Et ils gardent que la revocation MORD :
-- un revoked_at que les lectures ignorent serait pire que pas de revocation.
--   Bilan OK : 'INV-L1 OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_admin uuid := gen_random_uuid();
  v_membre uuid := gen_random_uuid();
  v_claim uuid;
  v_ctx_lignes int;
  v_origine text;
BEGIN
  INSERT INTO auth.users(id,email) VALUES (v_admin,'coord@ex.org'),(v_membre,'membre@ex.org');
  INSERT INTO public.profiles(id,email) VALUES (v_admin,'coord@ex.org'),(v_membre,'membre@ex.org');

  -- ── Le verrou remplace ─────────────────────────────────────────────
  v_t := 'T1 auto-candidature sans compte -> REFUSEE (la garantie tient)';
  BEGIN
    INSERT INTO public.library_request_claims
      (user_id, email_snapshot, claim_token_hash, expires_at, claim_origin)
    VALUES (NULL,'x@ex.org',public.fn_hash_claim_token('t1'),now()+interval '7 days','self_signup');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : insertion acceptee alors qu''elle devait echouer');
  EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1;
            WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  v_t := 'T2 invitation sans compte mais signee -> ACCEPTEE';
  BEGIN
    INSERT INTO public.library_request_claims
      (user_id, email_snapshot, claim_token_hash, expires_at, claim_origin, created_by_user_id)
    VALUES (NULL,'biblio@ex.org',public.fn_hash_claim_token('t2'),now()+interval '30 days','invitation',v_admin);
    v_passed:=v_passed+1;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T3 invitation NON signee -> REFUSEE (on sait toujours qui a sollicite)';
  BEGIN
    INSERT INTO public.library_request_claims
      (user_id, email_snapshot, claim_token_hash, expires_at, claim_origin, created_by_user_id)
    VALUES (NULL,'anonyme@ex.org',public.fn_hash_claim_token('t3'),now()+interval '30 days','invitation',NULL);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : insertion acceptee alors qu''elle devait echouer');
  EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1;
            WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  v_t := 'T4 origine invalide -> REFUSEE';
  BEGIN
    INSERT INTO public.library_request_claims
      (user_id, email_snapshot, claim_token_hash, expires_at, claim_origin)
    VALUES (v_membre,'y@ex.org',public.fn_hash_claim_token('t4'),now()+interval '7 days','prospection');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : origine libre acceptee');
  EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1;
            WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  -- ── Retro-compatibilite : l'EF register ne connait pas claim_origin ──
  v_t := 'T5 insertion a l''ancienne (sans claim_origin) -> defaut self_signup';
  BEGIN
    INSERT INTO public.library_request_claims
      (user_id, email_snapshot, claim_token_hash, claim_purpose, expires_at, metadata, created_by_user_id)
    VALUES (v_membre,'membre@ex.org',public.fn_hash_claim_token('t5'),'library_request',
            now()+interval '14 days','{"source":"register_signup_without_library"}'::jsonb,v_membre)
    RETURNING id, claim_origin INTO v_claim, v_origine;
    IF v_origine = 'self_signup' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_origine,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T6 non-regression : un claim sain reste visible du contexte';
  BEGIN
    SELECT count(*) INTO v_ctx_lignes FROM public.fn_get_library_request_claim_context('t5');
    IF v_ctx_lignes = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_ctx_lignes); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- ── La revocation doit MORDRE ──────────────────────────────────────
  v_t := 'T7 revocation sans motif -> REFUSEE (doctrine note obligatoire)';
  BEGIN
    UPDATE public.library_request_claims SET revoked_at = now() WHERE id = v_claim;
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : revocation muette acceptee');
  EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1;
            WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  v_t := 'T8 claim revoque -> INVISIBLE du contexte';
  BEGIN
    UPDATE public.library_request_claims
       SET revoked_at = now(), revoked_by_user_id = v_admin, revoked_reason = 'adresse erronee'
     WHERE id = v_claim;
    SELECT count(*) INTO v_ctx_lignes FROM public.fn_get_library_request_claim_context('t5');
    IF v_ctx_lignes = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : encore visible ('||v_ctx_lignes||')'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T9 claim revoque -> NON CONSOMMABLE';
  BEGIN
    PERFORM public.fn_consume_library_request_claim('t5');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : consommation acceptee sur un claim revoque');
  EXCEPTION WHEN insufficient_privilege THEN v_passed:=v_passed+1;
            WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  v_t := 'T10 non-regression : un claim sain se consomme toujours';
  BEGIN
    PERFORM public.fn_consume_library_request_claim('t2');
    v_passed:=v_passed+1;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN RAISE EXCEPTION 'INV-L1 OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE RAISE EXCEPTION 'INV-L1 ECHEC : %/% OK, % échec(s) | %', v_passed,(v_passed+v_failed),v_failed,array_to_string(v_failures,' || '); END IF;
END $$;
