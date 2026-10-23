-- =====================================================================
-- AnarBib — Tests : le préavis de purge suit la rétention.
-- Date    : 2026-10-23
-- Session : Modele de menace
-- Réf     : supabase/migrations/20261023224114_le_preavis_de_purge_suit_la_retention.sql
--
--   T1  un prêt clos depuis 710 jours, dans une bibliothèque INACTIVE, est
--       annoncé (défaut 730) ; un prêt clos depuis 600 jours ne l'est pas ;
--   T2  la durée propre à une bibliothèque compte (30 jours : tout prêt clos
--       est annoncé) ;
--   T3  messagerie : la personne lectrice d'un échange éteint depuis près de
--       12 mois est prévenue, par bibliothèque ; un échange vivant, non ;
--   T4  lecture en cours et envies : près de 24 mois sans connexion → préavis
--       sans bibliothèque ; connexion récente ou rien à perdre → rien ;
--   T5  un second passage ne double aucun préavis ;
--   T6  le bilan compte par famille ;
--   T7  ni anon ni authenticated n'appellent le préavis, l'aide est fermée à tous ;
--   T8  une famille inconnue est refusée (22023).
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'PREAVIS-PURGE OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_suf   text := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_libA  uuid; v_libI uuid;
  v_coord uuid := gen_random_uuid();
  v_r1 uuid := gen_random_uuid(); v_r2 uuid := gen_random_uuid(); v_r3 uuid := gen_random_uuid();
  v_r4 uuid := gen_random_uuid(); v_r5 uuid := gen_random_uuid(); v_r6 uuid := gen_random_uuid();
  v_book bigint; v_bilan jsonb; v_bilan2 jsonb; v_n int; v_x text; v_state text;
BEGIN
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-preavis-a-' || v_suf, 'Essai préavis A', true, 'public') RETURNING id INTO v_libA;
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-preavis-i-' || v_suf, 'Essai préavis inactive', false, 'public') RETURNING id INTO v_libI;

  -- r1 : prêt ancien, bibliothèque inactive ; r2 : prêt de 600 jours ;
  -- r3 : échange éteint ; r4 : échange vivant ; r5 : sans connexion depuis
  -- 23,5 mois avec une envie ; r6 : même ancienneté, rien à perdre.
  INSERT INTO auth.users (id, email, created_at, last_sign_in_at) VALUES
    (v_coord, 'pv-coord-' || v_suf || '@example.invalid', now() - interval '3 years', now()),
    (v_r1, 'pv-r1-' || v_suf || '@example.invalid', now() - interval '3 years', now()),
    (v_r2, 'pv-r2-' || v_suf || '@example.invalid', now() - interval '3 years', now()),
    (v_r3, 'pv-r3-' || v_suf || '@example.invalid', now() - interval '3 years', now()),
    (v_r4, 'pv-r4-' || v_suf || '@example.invalid', now() - interval '3 years', now()),
    (v_r5, 'pv-r5-' || v_suf || '@example.invalid', now() - interval '3 years', now() - interval '715 days'),
    (v_r6, 'pv-r6-' || v_suf || '@example.invalid', now() - interval '3 years', now() - interval '715 days');
  INSERT INTO public.profiles (id, email, first_name, last_name)
  SELECT u.id, u.email, 'Essai', 'Préavis' FROM auth.users u
   WHERE u.id IN (v_coord, v_r1, v_r2, v_r3, v_r4, v_r5, v_r6)
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status) VALUES
    (v_coord, v_libA, 'coordenador', 'active'),
    (v_r1, v_libI, 'reader', 'active'),
    (v_r2, v_libI, 'reader', 'active'),
    (v_r2, v_libA, 'reader', 'active'),
    (v_r3, v_libA, 'reader', 'active'),
    (v_r4, v_libA, 'reader', 'active');

  -- prêts clos sans exemplaire
  INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at, created_at, updated_at) VALUES
    (v_r1, v_libI, 'encerrado', current_date - 720, now() - interval '720 days', now() - interval '710 days'),
    (v_r2, v_libI, 'encerrado', current_date - 610, now() - interval '610 days', now() - interval '600 days');

  -- messagerie
  INSERT INTO public.reader_library_messages (library_id, sender_id, direction, body, created_at) VALUES
    (v_libA, v_r3, 'reader', 'question ancienne', now() - interval '12 months'),
    (v_libA, v_r4, 'reader', 'question ancienne', now() - interval '12 months');
  INSERT INTO public.reader_library_messages (library_id, sender_id, recipient_id, direction, body, created_at) VALUES
    (v_libA, v_coord, v_r3, 'library', 'réponse ancienne', now() - interval '11 months' - interval '10 days'),
    (v_libA, v_coord, v_r4, 'library', 'réponse récente', now() - interval '2 months');

  -- envie de r5
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Essai préavis', 'PV-' || v_suf, 'livro') RETURNING id INTO v_book;
  INSERT INTO public.user_wishlist (user_id, book_id) VALUES (v_r5, v_book);

  v_bilan := public.fn_notify_users_before_purge();

  -- ── T1 ─────────────────────────────────────────────────────────────────
  v_t := 'T1 bibliothèque inactive comprise, 710 jours annoncé, 600 jours non';
  IF EXISTS (SELECT 1 FROM public.user_notifications WHERE user_id = v_r1 AND library_id = v_libI AND category = 'rgpd_retention_loans'
               AND title = 'notif.rgpd.purgeWarning.loans.title' AND NOT is_read)
     AND NOT EXISTS (SELECT 1 FROM public.user_notifications WHERE user_id = v_r2 AND category = 'rgpd_retention_loans') THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  -- ── T2 ─────────────────────────────────────────────────────────────────
  v_t := 'T2 la durée de la bibliothèque compte';
  INSERT INTO public.library_retention_policies (library_id, retention_loans_days) VALUES (v_libA, 30);
  INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at, created_at, updated_at)
  VALUES (v_r2, v_libA, 'encerrado', current_date - 15, now() - interval '15 days', now() - interval '10 days');
  PERFORM public.fn_notify_users_before_purge();
  IF EXISTS (SELECT 1 FROM public.user_notifications WHERE user_id = v_r2 AND library_id = v_libA AND category = 'rgpd_retention_loans') THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  -- ── T3 ─────────────────────────────────────────────────────────────────
  v_t := 'T3 messagerie : échange éteint prévenu, échange vivant non';
  IF EXISTS (SELECT 1 FROM public.user_notifications WHERE user_id = v_r3 AND library_id = v_libA AND category = 'rgpd_retention_messages'
               AND title = 'notif.rgpd.purgeWarning.messages.title')
     AND NOT EXISTS (SELECT 1 FROM public.user_notifications WHERE user_id = v_r4 AND category = 'rgpd_retention_messages')
     AND NOT EXISTS (SELECT 1 FROM public.user_notifications WHERE user_id = v_coord AND category = 'rgpd_retention_messages') THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  -- ── T4 ─────────────────────────────────────────────────────────────────
  v_t := 'T4 lecture et envies : préavis sans bibliothèque, seulement s''il y a à perdre';
  IF EXISTS (SELECT 1 FROM public.user_notifications WHERE user_id = v_r5 AND library_id IS NULL AND category = 'rgpd_retention_reading'
               AND body = 'notif.rgpd.purgeWarning.reading.body')
     AND NOT EXISTS (SELECT 1 FROM public.user_notifications WHERE user_id = v_r6 AND category = 'rgpd_retention_reading')
     AND NOT EXISTS (SELECT 1 FROM public.user_notifications WHERE user_id = v_r1 AND category = 'rgpd_retention_reading') THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  -- ── T5 ─────────────────────────────────────────────────────────────────
  v_t := 'T5 un second passage ne double rien';
  SELECT count(*) INTO v_n FROM public.user_notifications
   WHERE user_id IN (v_r1, v_r2, v_r3, v_r4, v_r5, v_r6) AND category LIKE 'rgpd_retention_%';
  v_bilan2 := public.fn_notify_users_before_purge();
  IF (SELECT count(*) FROM public.user_notifications
       WHERE user_id IN (v_r1, v_r2, v_r3, v_r4, v_r5, v_r6) AND category LIKE 'rgpd_retention_%') = v_n
     AND v_n = 4 THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' préavis'); END IF;

  -- ── T6 ─────────────────────────────────────────────────────────────────
  v_t := 'T6 le bilan compte par famille';
  IF (v_bilan->'par_famille'->>'loans')::int >= 1
     AND (v_bilan->'par_famille'->>'messages')::int >= 1
     AND (v_bilan->'par_famille'->>'reading')::int >= 1
     AND v_bilan->'par_famille' ? 'consultations'
     AND (v_bilan->>'total_notifications_created')::int >= 3
     AND v_bilan->>'mode' = 'notify' THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(v_bilan::text, 300)); END IF;

  -- ── T7 ─────────────────────────────────────────────────────────────────
  v_t := 'T7 droits';
  IF NOT has_function_privilege('anon', 'public.fn_notify_users_before_purge()', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.fn_notify_users_before_purge()', 'EXECUTE')
     AND has_function_privilege('service_role', 'public.fn_notify_users_before_purge()', 'EXECUTE')
     AND NOT has_function_privilege('service_role', 'private.fn_preavis_purge_envoyer(uuid[], uuid, text)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'private.fn_preavis_purge_envoyer(uuid[], uuid, text)', 'EXECUTE') THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  -- ── T8 ─────────────────────────────────────────────────────────────────
  v_t := 'T8 une famille inconnue est refusée';
  v_state := NULL;
  BEGIN
    PERFORM private.fn_preavis_purge_envoyer(ARRAY[v_r1], NULL, 'journaux');
  EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; END;
  IF v_state = '22023' THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||COALESCE(v_state, 'aucune erreur')); END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'PREAVIS-PURGE OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'PREAVIS-PURGE ECHEC : %/% OK, % échec(s) | %',
      v_passed, v_passed + v_failed, v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
