-- ═══════════════════════════════════════════════════════════════════════════
-- #79 (suite) — retirer l'EXECUTE anon gratuit sur merge_book / merge_subject
-- ───────────────────────────────────────────────────────────────────────────
-- Session : Audit 360 — correctifs P0
-- Auteur  : AnarBib (assist. Claude)
-- Réf     : Audit 360° 17/06/2026, §10.1 (anon_security_definer) — slice ciblée.
--
-- CONSTAT
--   public.merge_book et public.merge_subject sont SECURITY DEFINER, gardées en
--   interne (staff catalogage librarian/coordenador) MAIS portent un
--   `GRANT EXECUTE … TO anon` gratuit (un anon est de toute façon bloqué par la
--   garde, auth.uid() NULL → RAISE) qui déclenche l'advisor
--   anon_security_definer_function_executable. merge_author est déjà propre.
--   Le front appelle merge_book en `authenticated` (BookDraftForm) ; aucun
--   appelant anon / Edge Function (vérifié).
--
-- ACTION
--   REVOKE EXECUTE … FROM PUBLIC, anon ; authenticated + service_role préservés.
--   REVOKE ciblé et justifié (mutations de catalogue jamais légitimement anon)
--   — PAS un balayage de masse (cf. doctrine advisors SECDEF intentionnels :
--   login/OPAC/catalogue lecture restent légitimement exécutables par anon).
--
-- ROLLBACK : bloc commenté en pied (manuel-only).
-- ═══════════════════════════════════════════════════════════════════════════

REVOKE EXECUTE ON FUNCTION public.merge_book(bigint, bigint) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.merge_book(bigint, bigint) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.merge_subject(bigint, bigint) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.merge_subject(bigint, bigint) TO authenticated, service_role;

-- ── Vérification (RAISE = auto-rollback) ────────────────────────────────────
DO $$
DECLARE
  v_name text;
  v_anon boolean;
  v_auth boolean;
BEGIN
  FOREACH v_name IN ARRAY ARRAY['merge_book','merge_subject'] LOOP
    SELECT EXISTS (SELECT 1 FROM information_schema.routine_privileges
                   WHERE routine_schema='public' AND routine_name=v_name
                     AND grantee='anon' AND privilege_type='EXECUTE') INTO v_anon;
    SELECT EXISTS (SELECT 1 FROM information_schema.routine_privileges
                   WHERE routine_schema='public' AND routine_name=v_name
                     AND grantee='authenticated' AND privilege_type='EXECUTE') INTO v_auth;
    IF v_anon THEN
      RAISE EXCEPTION 'merge revoke: anon a encore EXECUTE sur public.%', v_name;
    END IF;
    IF NOT v_auth THEN
      RAISE EXCEPTION 'merge revoke: authenticated a perdu EXECUTE sur public.% (sur-revoke)', v_name;
    END IF;
  END LOOP;
  RAISE NOTICE 'merge revoke OK : anon retiré de merge_book/merge_subject, authenticated préservé.';
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ROLLBACK MANUEL (ne pas exécuter en migration) — si régression visible :
-- GRANT EXECUTE ON FUNCTION public.merge_book(bigint, bigint) TO anon;
-- GRANT EXECUTE ON FUNCTION public.merge_subject(bigint, bigint) TO anon;
-- ═══════════════════════════════════════════════════════════════════════════
