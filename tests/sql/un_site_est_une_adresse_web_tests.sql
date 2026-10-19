-- =====================================================================
-- AnarBib — Tests d'acceptation : un site est une adresse web
-- Date    : 2026-10-19
-- Ref     : migration 20261019100407_un_site_est_une_adresse_web
-- Session : Modele de menace
--
-- T1 les trois contraintes existent et sont validées.
-- T2 une adresse http(s) passe, NULL passe ; javascript:, data:, une
--    adresse sans schéma, une adresse avec espace ou guillemet sont refusées
--    (23514) — sur une proposition de la cartographie.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'SITE-ADRESSE-WEB OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text; v_txt text;
  v_state text; v_url text;
BEGIN
  v_t := 'T1 contraintes posees et validees';
  BEGIN
    IF (SELECT count(*) FROM pg_constraint
         WHERE conname IN ('cartography_entries_site_url_chk', 'cartography_submissions_site_url_chk', 'networks_site_url_chk')
           AND convalidated) = 3
    THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : contrainte absente ou non validee'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  v_t := 'T2 seules les adresses http(s) entrent';
  BEGIN
    v_txt := '';
    FOREACH v_url IN ARRAY ARRAY['https://exemple.org/a?b=1', 'http://exemple.org'] LOOP
      BEGIN
        INSERT INTO public.cartography_submissions (name, categorie, site_url) VALUES ('Essai site', 'biblioteca', v_url);
      EXCEPTION WHEN OTHERS THEN v_txt := v_txt || 'refuse(' || v_url || ')=' || SQLSTATE || ' '; END;
    END LOOP;
    BEGIN
      INSERT INTO public.cartography_submissions (name, categorie, site_url) VALUES ('Essai site', 'biblioteca', NULL);
    EXCEPTION WHEN OTHERS THEN v_txt := v_txt || 'null-refuse=' || SQLSTATE || ' '; END;
    FOREACH v_url IN ARRAY ARRAY['javascript:alert(1)', 'data:text/html,x', 'exemple.org', 'https://exemple.org/a b', 'https://exemple.org/"x', 'JAVASCRIPT://x'] LOOP
      v_state := NULL;
      BEGIN
        INSERT INTO public.cartography_submissions (name, categorie, site_url) VALUES ('Essai site', 'biblioteca', v_url);
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE; END;
      IF v_state IS DISTINCT FROM '23514' THEN v_txt := v_txt || 'accepte(' || v_url || ')=' || coalesce(v_state, 'ok') || ' '; END IF;
    END LOOP;
    IF v_txt = '' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'SITE-ADRESSE-WEB OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'SITE-ADRESSE-WEB ECHEC : %/% — %', v_passed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
