-- =====================================================================
-- AnarBib — Tests d'acceptation : invitation d'une bibliotheque, LOT 2
-- Date    : 2026-08-27  ·  Session : chantier invitation (option A)
-- Ref     : migration 20260827170000_invitation_claims_lot2_rpc
--           docs/journal/cadrages/CADRAGE_invitation_bibliotheque_2026-08-27.md
--
-- Ce lot ouvre un droit d'emission. Les tests gardent surtout QUI l'exerce
-- (D2 : les admins reseau, personne d'autre), le fait que le jeton ne se
-- persiste jamais en clair, et que la liste ne fuit ni jeton ni hash.
--   Bilan OK : 'INV-L2 OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_admin uuid := gen_random_uuid();
  v_coord uuid := gen_random_uuid();
  v_claim uuid; v_token text; v_exp timestamptz;
  v_claim2 uuid; v_token2 text; v_exp2 timestamptz;
  v_n int; v_txt text; v_jours numeric;
BEGIN
  INSERT INTO auth.users(id,email) VALUES (v_admin,'admin@ex.org'),(v_coord,'coord@ex.org');
  INSERT INTO public.profiles(id,email) VALUES (v_admin,'admin@ex.org'),(v_coord,'coord@ex.org');
  INSERT INTO public.network_administrators(user_id,status) VALUES (v_admin,'active');

  -- ── D2 : qui peut inviter ──────────────────────────────────────────
  v_t := 'T1 non-admin ne peut pas inviter';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM public.fn_create_library_request_invitation('cible@ex.org','Biblioteca X');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : emission acceptee');
  EXCEPTION WHEN insufficient_privilege THEN v_passed:=v_passed+1;
            WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  v_t := 'T2 admin reseau emet une invitation';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    SELECT claim_id, claim_token, expires_at INTO v_claim, v_token, v_exp
      FROM public.fn_create_library_request_invitation('cible@ex.org','Biblioteca X','vue a Bologne');
    IF v_claim IS NOT NULL AND length(coalesce(v_token,'')) >= 32 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : claim/jeton absent'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T3 la ligne posee est bien une invitation signee et sans compte';
  BEGIN
    SELECT count(*) INTO v_n FROM public.library_request_claims c
     WHERE c.id = v_claim AND c.claim_origin = 'invitation'
       AND c.user_id IS NULL AND c.created_by_user_id = v_admin
       AND c.email_snapshot = 'cible@ex.org';
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- ── D3 : 45 jours ──────────────────────────────────────────────────
  v_t := 'T4 duree de vie = 45 jours (D3)';
  BEGIN
    SELECT extract(epoch from (v_exp - now()))/86400 INTO v_jours;
    IF v_jours > 44.9 AND v_jours < 45.1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||round(v_jours,2)||' jours'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Le jeton ne se persiste jamais en clair ────────────────────────
  v_t := 'T5 seul le hash est stocke, jamais le jeton';
  BEGIN
    SELECT count(*) INTO v_n FROM public.library_request_claims c
     WHERE c.id = v_claim
       AND c.claim_token_hash = public.fn_hash_claim_token(v_token)
       AND c.claim_token_hash <> v_token;
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T6 le jeton rendu ouvre vraiment le formulaire (contexte valide)';
  BEGIN
    SELECT count(*) INTO v_n FROM public.fn_get_library_request_claim_context(v_token);
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Une seule invitation vivante par adresse ───────────────────────
  v_t := 'T7 seconde invitation a la meme adresse -> refusee';
  BEGIN
    PERFORM public.fn_create_library_request_invitation('cible@ex.org','Biblioteca X');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : doublon accepte');
  EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1;
            WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  -- ── Revocation ─────────────────────────────────────────────────────
  v_t := 'T8 revocation sans motif -> refusee';
  BEGIN
    PERFORM public.fn_revoke_library_request_invitation(v_claim, '   ');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : revocation muette acceptee');
  EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1;
            WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  v_t := 'T9 non-admin ne peut pas revoquer';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM public.fn_revoke_library_request_invitation(v_claim, 'adresse erronee');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : revocation acceptee');
  EXCEPTION WHEN insufficient_privilege THEN v_passed:=v_passed+1;
            WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  v_t := 'T10 admin revoque, et le jeton cesse d''ouvrir quoi que ce soit';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_revoke_library_request_invitation(v_claim, 'adresse erronee');
    SELECT count(*) INTO v_n FROM public.fn_get_library_request_claim_context(v_token);
    IF v_n = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : contexte encore ouvert'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T11 double revocation -> refusee';
  BEGIN
    PERFORM public.fn_revoke_library_request_invitation(v_claim, 'encore');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : seconde revocation acceptee');
  EXCEPTION WHEN insufficient_privilege THEN v_passed:=v_passed+1;
            WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  v_t := 'T12 apres revocation, on peut reinviter la meme adresse';
  BEGIN
    SELECT claim_id, claim_token, expires_at INTO v_claim2, v_token2, v_exp2
      FROM public.fn_create_library_request_invitation('cible@ex.org','Biblioteca X');
    IF v_claim2 IS NOT NULL AND v_claim2 <> v_claim THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : pas de nouvelle invitation'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T13 on ne revoque pas une auto-candidature';
  BEGIN
    INSERT INTO public.library_request_claims
      (user_id, email_snapshot, claim_token_hash, expires_at, claim_origin)
    VALUES (v_coord,'coord@ex.org',public.fn_hash_claim_token('auto1'),now()+interval '14 days','self_signup');
    PERFORM public.fn_revoke_library_request_invitation(
      (SELECT id FROM public.library_request_claims WHERE claim_token_hash = public.fn_hash_claim_token('auto1')),
      'tentative');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : auto-candidature revoquee');
  EXCEPTION WHEN insufficient_privilege THEN v_passed:=v_passed+1;
            WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  -- ── La liste ───────────────────────────────────────────────────────
  v_t := 'T14 la liste ne montre que des invitations, pas les auto-candidatures';
  BEGIN
    SELECT count(*) INTO v_n FROM public.fn_list_library_request_invitations(true);
    IF v_n = 2 THEN v_passed:=v_passed+1;   -- la revoquee + la nouvelle
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n||' (2 attendues)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T15 par defaut la liste masque les invitations closes';
  BEGIN
    SELECT count(*) INTO v_n FROM public.fn_list_library_request_invitations();
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n||' (1 attendue)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T16 etats rendus : revoquee + en_attente';
  BEGIN
    SELECT string_agg(etat, ',' ORDER BY etat) INTO v_txt
      FROM public.fn_list_library_request_invitations(true);
    IF v_txt = 'en_attente,revoquee' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_txt,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T17 la liste ne rend ni jeton ni hash';
  BEGIN
    SELECT count(*) INTO v_n
      FROM information_schema.routines r
      JOIN information_schema.parameters p
        ON p.specific_name = r.specific_name
     WHERE r.routine_schema = 'public'
       AND r.routine_name = 'fn_list_library_request_invitations'
       AND p.parameter_mode = 'OUT'
       AND (p.parameter_name ILIKE '%token%' OR p.parameter_name ILIKE '%hash%');
    IF v_n = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||v_n||' colonne(s) sensibles exposees'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T18 un non-admin ne voit aucune invitation';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_n FROM public.fn_list_library_request_invitations(true);
    IF v_n = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN RAISE EXCEPTION 'INV-L2 OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE RAISE EXCEPTION 'INV-L2 ECHEC : %/% OK, % échec(s) | %', v_passed,(v_passed+v_failed),v_failed,array_to_string(v_failures,' || '); END IF;
END $$;
