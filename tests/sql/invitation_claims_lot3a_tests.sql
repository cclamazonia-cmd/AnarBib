-- =====================================================================
-- AnarBib — Tests d'acceptation : invitation d'une bibliotheque, LOT 3a
-- Date    : 2026-08-27  ·  Session : chantier invitation (option A)
-- Ref     : migration 20260827200000_invitation_claims_lot3a
--
-- Ce lot scinde la note en deux et pose une purge. Les tests gardent les deux
-- choses qui, si elles lachent, lachent en silence : que la note INTERNE ne
-- sorte jamais vers la personne invitee (A4), et que la purge efface vraiment
-- ce qu'elle doit sans emporter ce qu'elle ne doit pas (B).
--   Bilan OK : 'INV-L3A OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_admin uuid := gen_random_uuid();
  v_lect  uuid := gen_random_uuid();
  v_claim uuid; v_token text; v_exp timestamptz;
  v_vieille uuid; v_revoquee uuid; v_aboutie uuid; v_auto uuid;
  v_n int; v_txt text; v_res jsonb;
BEGIN
  INSERT INTO auth.users(id,email) VALUES (v_admin,'admin@ex.org'),(v_lect,'lect@ex.org');
  INSERT INTO public.profiles(id,email) VALUES (v_admin,'admin@ex.org'),(v_lect,'lect@ex.org');
  INSERT INTO public.network_administrators(user_id,status) VALUES (v_admin,'active');
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);

  SELECT claim_id, claim_token, expires_at INTO v_claim, v_token, v_exp
    FROM public.fn_create_library_request_invitation(
      'biblio@ex.org','Bibliotheque Machin',
      'mefiants, y aller doucement',          -- note_interne
      'on s''est vus a Bologne');             -- mot_accompagnement

  -- ── A1 / A3 / A4 : ce que le lien montre, et ce qu'il ne montre pas ──
  v_t := 'T1 le contexte rend le nom de la bibliotheque (A1)';
  BEGIN
    SELECT library_name INTO v_txt FROM public.fn_get_library_request_claim_context(v_token);
    IF v_txt = 'Bibliotheque Machin' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_txt,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T2 le contexte rend le mot d''accompagnement';
  BEGIN
    SELECT mot_accompagnement INTO v_txt FROM public.fn_get_library_request_claim_context(v_token);
    IF v_txt = 'on s''est vus a Bologne' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_txt,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T3 le contexte n''expose AUCUNE colonne de note interne (A4)';
  BEGIN
    SELECT count(*) INTO v_n
      FROM information_schema.routines r
      JOIN information_schema.parameters p ON p.specific_name = r.specific_name
     WHERE r.routine_schema='public' AND r.routine_name='fn_get_library_request_claim_context'
       AND p.parameter_mode='OUT'
       AND (p.parameter_name ILIKE '%interne%' OR p.parameter_name ILIKE '%note%');
    IF v_n = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||v_n||' colonne(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T4 la note interne n''apparait dans AUCUNE valeur rendue par le contexte';
  BEGIN
    SELECT count(*) INTO v_n FROM public.fn_get_library_request_claim_context(v_token) c
     WHERE coalesce(c.library_name,'')||coalesce(c.mot_accompagnement,'')||coalesce(c.email_snapshot,'')
           ILIKE '%mefiants%';
    IF v_n = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : la note interne a fuite'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T5 le contexte ne dit rien de l''emetteur (A3, signature institutionnelle)';
  BEGIN
    SELECT count(*) INTO v_n
      FROM information_schema.routines r
      JOIN information_schema.parameters p ON p.specific_name = r.specific_name
     WHERE r.routine_schema='public' AND r.routine_name='fn_get_library_request_claim_context'
       AND p.parameter_mode='OUT'
       AND (p.parameter_name ILIKE '%created_by%' OR p.parameter_name ILIKE '%invit%'
            OR p.parameter_name ILIKE '%admin%');
    IF v_n = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||v_n||' colonne(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T6 la liste (admins) voit bien les DEUX notes';
  BEGIN
    SELECT count(*) INTO v_n FROM public.fn_list_library_request_invitations(true) l
     WHERE l.note_interne = 'mefiants, y aller doucement'
       AND l.mot_accompagnement = 'on s''est vus a Bologne';
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- ── B : la purge ────────────────────────────────────────────────────
  -- Fixtures : une expiree de 50 j, une revoquee de 50 j, une aboutie, une
  -- auto-candidature. Toutes hors delai, sauf celle creee plus haut (vivante).
  -- created_at antidate lui aussi : la table exige expires_at > created_at.
  INSERT INTO public.library_request_claims
    (user_id,email_snapshot,claim_token_hash,created_at,expires_at,claim_origin,created_by_user_id,metadata)
  VALUES (null,'vieille@ex.org',public.fn_hash_claim_token('v1'),
          now()-interval '95 days',now()-interval '50 days',
          'invitation',v_admin,'{"library_name":"Vieille","note_interne":"secret","mot_accompagnement":"coucou"}'::jsonb)
  RETURNING id INTO v_vieille;

  INSERT INTO public.library_request_claims
    (user_id,email_snapshot,claim_token_hash,created_at,expires_at,claim_origin,created_by_user_id,
     revoked_at,revoked_by_user_id,revoked_reason,metadata)
  VALUES (null,'revoquee@ex.org',public.fn_hash_claim_token('v2'),now()-interval '95 days',
          now()+interval '10 days',
          'invitation',v_admin,now()-interval '50 days',v_admin,'mauvaise adresse',
          '{"library_name":"Revoquee","note_interne":"secret"}'::jsonb)
  RETURNING id INTO v_revoquee;

  INSERT INTO public.library_request_claims
    (user_id,email_snapshot,claim_token_hash,created_at,expires_at,claim_origin,created_by_user_id,
     used_at,metadata)
  VALUES (null,'aboutie@ex.org',public.fn_hash_claim_token('v3'),
          now()-interval '95 days',now()-interval '50 days',
          'invitation',v_admin,now()-interval '49 days','{"library_name":"Aboutie"}'::jsonb)
  RETURNING id INTO v_aboutie;

  INSERT INTO public.library_request_claims
    (user_id,email_snapshot,claim_token_hash,created_at,expires_at,claim_origin)
  VALUES (v_lect,'lect@ex.org',public.fn_hash_claim_token('v4'),
          now()-interval '95 days',now()-interval '50 days','self_signup')
  RETURNING id INTO v_auto;

  v_t := 'T7 la purge efface les deux invitations hors delai, et elles seules';
  BEGIN
    SELECT public.fn_purge_library_request_invitations() INTO v_res;
    IF (v_res->>'purgees')::int = 2 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_res->>'purgees','?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T8 la ligne purgee survit : email et notes partis, audit garde';
  BEGIN
    SELECT count(*) INTO v_n FROM public.library_request_claims c
     WHERE c.id = v_vieille
       AND c.email_snapshot IS NULL
       AND c.purged_at IS NOT NULL
       AND c.metadata->>'note_interne' IS NULL
       AND c.metadata->>'mot_accompagnement' IS NULL
       AND c.metadata->>'library_name' = 'Vieille'   -- l'audit garde le QUI
       AND c.created_by_user_id = v_admin;           -- et le PAR QUI
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T9 le motif de revocation survit a la purge';
  BEGIN
    SELECT count(*) INTO v_n FROM public.library_request_claims c
     WHERE c.id = v_revoquee AND c.email_snapshot IS NULL
       AND c.revoked_reason = 'mauvaise adresse';
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T10 une invitation ABOUTIE n''est pas purgee';
  BEGIN
    SELECT count(*) INTO v_n FROM public.library_request_claims c
     WHERE c.id = v_aboutie AND c.email_snapshot = 'aboutie@ex.org' AND c.purged_at IS NULL;
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : elle a ete purgee'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T11 une auto-candidature n''est pas purgee';
  BEGIN
    SELECT count(*) INTO v_n FROM public.library_request_claims c
     WHERE c.id = v_auto AND c.email_snapshot = 'lect@ex.org' AND c.purged_at IS NULL;
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : elle a ete purgee'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T12 l''invitation vivante n''est pas touchee';
  BEGIN
    SELECT count(*) INTO v_n FROM public.library_request_claims c
     WHERE c.id = v_claim AND c.email_snapshot = 'biblio@ex.org' AND c.purged_at IS NULL;
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : elle a ete purgee'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T13 la purge est idempotente (second passage : 0)';
  BEGIN
    SELECT public.fn_purge_library_request_invitations() INTO v_res;
    IF (v_res->>'purgees')::int = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_res->>'purgees','?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T14 un email absent SANS purge -> refuse (la nullabilite reste un cas nomme)';
  BEGIN
    INSERT INTO public.library_request_claims
      (user_id,email_snapshot,claim_token_hash,expires_at,claim_origin,created_by_user_id)
    VALUES (null,null,public.fn_hash_claim_token('v5'),now()+interval '10 days','invitation',v_admin);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : insertion acceptee');
  EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1;
            WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  v_t := 'T15 la purge n''est pas appelable par un compte connecte';
  BEGIN
    SELECT count(*) INTO v_n
      FROM information_schema.routine_privileges
     WHERE routine_schema='public'
       AND routine_name='fn_purge_library_request_invitations'
       AND grantee IN ('authenticated','anon','PUBLIC');
    IF v_n = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||v_n||' droit(s) de trop'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN RAISE EXCEPTION 'INV-L3A OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE RAISE EXCEPTION 'INV-L3A ECHEC : %/% OK, % échec(s) | %', v_passed,(v_passed+v_failed),v_failed,array_to_string(v_failures,' || '); END IF;
END $$;
