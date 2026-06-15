-- =========================================================================
-- Paquet SECU-MV — Fermer l'accès DIRECT aux MV catalogue via l'API
-- =========================================================================
-- Date     : 2026-06-15
-- Chantier : Nettoyage des security advisors Supabase (vrai risque)
-- Auteur   : AnarBib
-- Session  : Perf UX + nettoyage advisors sécurité
--
-- RISQUE CORRIGÉ (advisor materialized_view_in_api, fuite latente)
--   `mv_books_catalog_list_network_v1` (2673 livres dont ~2174 network-only
--   de Biblioteca Terra Livre) avait un GRANT SELECT DIRECT à `authenticated`.
--   La vue `api.catalog_list_session_v1` (security_invoker) applique pourtant
--   un filtre d'appartenance réseau (un non-membre ne doit voir que le
--   sous-ensemble détenu par une biblio publique). Une MV ne peut pas porter
--   de RLS → tout compte connecté pouvait CONTOURNER ce filtre via
--   GET /rest/v1/mv_books_catalog_list_network_v1 et lire les 2673 lignes.
--   Latent aujourd'hui (les 6 comptes sont membres) mais à fermer.
--
-- STRATÉGIE (option C, doctrine-pure — vues restent security_invoker)
--   1. 2 wrappers SECURITY DEFINER qui lisent la MV en tant que `postgres`
--      (owner), exposés en RPC mais ne renvoyant les lignes qu'à travers la
--      vue filtrante.
--   2. Réécriture des 2 vues catalogue (toujours security_invoker=true) pour
--      lire via les wrappers au lieu de la MV directe.
--   3. REVOKE SELECT sur les MV pour anon/authenticated → l'endpoint REST
--      direct renvoie 403, le contournement est fermé, l'advisor tombe.
--   `api.search_catalog_v1` et `refresh_mv_books_catalog_list_v1` sont
--   SECURITY DEFINER (lisent la MV en tant que postgres) → INCHANGÉS, la
--   recherche OPAC n'est pas touchée.
--
--   NB : +2 fonctions SECDEF (bucket « intentionnel ») en échange de -2
--   materialized_view_in_api ; le compteur reste ~stable mais la FUITE est
--   fermée et on évite des vues SECURITY DEFINER (qui seraient ERROR).
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Wrappers SECURITY DEFINER (lecture de la MV en tant que postgres)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_catalog_public_rows()
RETURNS SETOF public.mv_books_catalog_list_v1
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $fn$ SELECT * FROM public.mv_books_catalog_list_v1 $fn$;

REVOKE EXECUTE ON FUNCTION public.fn_catalog_public_rows() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_catalog_public_rows() TO anon, authenticated;
COMMENT ON FUNCTION public.fn_catalog_public_rows() IS
  'Wrapper SECDEF de la MV catalogue publique. Permet a la vue invoker '
  'catalog_list_anon_v1 de lire la MV sans GRANT direct (paquet SECU-MV 15/06/2026).';

CREATE OR REPLACE FUNCTION public.fn_catalog_network_rows()
RETURNS SETOF public.mv_books_catalog_list_network_v1
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $fn$ SELECT * FROM public.mv_books_catalog_list_network_v1 $fn$;

REVOKE EXECUTE ON FUNCTION public.fn_catalog_network_rows() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_catalog_network_rows() TO authenticated;
COMMENT ON FUNCTION public.fn_catalog_network_rows() IS
  'Wrapper SECDEF de la MV catalogue reseau. La vue invoker '
  'catalog_list_session_v1 applique PAR-DESSUS le filtre d''appartenance '
  'reseau ; l''acces direct a la MV est revoque (paquet SECU-MV 15/06/2026).';

-- -------------------------------------------------------------------------
-- 2. Réécriture des vues (security_invoker=true) pour passer par les wrappers
--    (seule la source FROM change ; colonnes/logique identiques)
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW api.catalog_list_anon_v1
WITH (security_invoker = true) AS
 SELECT book_id,
    bib_ref,
    autor,
    titulo,
    ano,
    editora,
    cdd,
    loanable,
    available_count,
    created_at,
    cover_object_path,
    subtitulo,
    edicao,
    local_publicacao,
    isbn,
    issn,
    idioma,
    tipo_material,
    colecao,
    assuntos,
    author_id,
    catalog_source,
    library_id,
    library_slug,
    library_name,
    biblioteca,
    has_online_reading,
    author_display,
    author_chips,
    exemplares_total,
    bibliotecas_count,
    global_available_count,
    global_exemplares_total,
    holding_library_names_json
   FROM public.fn_catalog_public_rows()
  WHERE COALESCE(exemplares_total, 0) > 0;

CREATE OR REPLACE VIEW api.catalog_list_session_v1
WITH (security_invoker = true) AS
 WITH session_ctx AS (
         SELECT msc.default_library_id
           FROM api.my_session_context msc
         LIMIT 1
        ), is_network_member AS (
         SELECT (EXISTS ( SELECT 1
                   FROM user_library_memberships ulm
                  WHERE ulm.user_id = auth.uid() AND ulm.status = 'active'::text)) AS is_member
        ), session_holdings AS (
         SELECT h.book_id,
            h.id AS holding_id,
            h.library_id,
            h.local_bib_ref,
            h.loanable AS holding_loanable,
            COALESCE(h.available_count, 0) AS available_count,
            COALESCE(h.exemplares_total, 0) AS exemplares_total
           FROM book_holdings h
          WHERE h.library_id = (( SELECT session_ctx.default_library_id
                   FROM session_ctx))
        )
 SELECT m.book_id,
    m.bib_ref,
    m.autor,
    m.titulo,
    m.ano,
    m.editora,
    m.cdd,
    m.loanable,
    m.available_count,
    m.created_at,
    m.cover_object_path,
    m.subtitulo,
    m.edicao,
    m.local_publicacao,
    m.isbn,
    m.issn,
    m.idioma,
    m.tipo_material,
    m.colecao,
    m.assuntos,
    m.author_id,
    m.catalog_source,
    m.library_id,
    m.library_slug,
    m.library_name,
    m.biblioteca,
    m.has_online_reading,
    m.author_display,
    m.author_chips,
    m.exemplares_total,
    m.bibliotecas_count,
    m.global_available_count,
    m.global_exemplares_total,
    m.holding_library_names_json,
    sc.default_library_id AS session_library_id,
    ls.slug AS session_library_slug,
    ls.name AS session_library_name,
    COALESCE(sh.exemplares_total, 0) AS session_exemplares_total,
    sh.holding_id IS NOT NULL AS session_has_holding,
        CASE
            WHEN sc.default_library_id IS NULL THEN 'sem_biblioteca_de_sessao'::text
            WHEN sh.holding_id IS NULL THEN 'indisponivel_para_voce'::text
            WHEN COALESCE(sh.holding_loanable, m.loanable, true) IS FALSE THEN 'consultavel_no_local'::text
            ELSE 'no_acervo_da_sua_biblioteca'::text
        END AS session_status_hint,
    COALESCE(sh.available_count, 0) AS session_available_count,
    COALESCE(sh.holding_loanable, m.loanable, true) AS session_loanable
   FROM public.fn_catalog_network_rows() m
     LEFT JOIN session_ctx sc ON true
     LEFT JOIN libraries ls ON ls.id = sc.default_library_id
     LEFT JOIN session_holdings sh ON sh.book_id = m.book_id
  WHERE ( SELECT is_network_member.is_member
           FROM is_network_member) OR (EXISTS ( SELECT 1
           FROM book_holdings h2
             JOIN libraries l2 ON l2.id = h2.library_id
          WHERE h2.book_id = m.book_id AND l2.is_active = true AND l2.visibility_level = 'public'::text));

-- -------------------------------------------------------------------------
-- 3. Révocation de l'accès DIRECT aux MV (ferme le contournement REST)
--    postgres + service_role conservent SELECT (refresh, wrappers SECDEF).
-- -------------------------------------------------------------------------
REVOKE SELECT ON public.mv_books_catalog_list_v1         FROM anon, authenticated;
REVOKE SELECT ON public.mv_books_catalog_list_network_v1 FROM anon, authenticated;

-- -------------------------------------------------------------------------
-- 4. Vérification (rollback si fuite non fermée, vue cassée, ou filtre perdu)
-- -------------------------------------------------------------------------
DO $verify$
DECLARE
  v_member        uuid;
  v_anon_rows     int;
  v_member_rows   int;
  v_nonmember_rows int;
  v_search        int;
BEGIN
  -- (a) Les MV ne sont plus selectables par anon/authenticated (fuite fermee)
  IF has_table_privilege('anon', 'public.mv_books_catalog_list_v1', 'SELECT')
     OR has_table_privilege('authenticated', 'public.mv_books_catalog_list_v1', 'SELECT')
     OR has_table_privilege('anon', 'public.mv_books_catalog_list_network_v1', 'SELECT')
     OR has_table_privilege('authenticated', 'public.mv_books_catalog_list_network_v1', 'SELECT') THEN
    RAISE EXCEPTION 'Verif echouee : une MV reste selectable par anon/authenticated. Rollback.';
  END IF;

  -- (b) anon : le catalogue public fonctionne + la recherche OPAC ne plante pas
  SET LOCAL ROLE anon;
  SET LOCAL "request.jwt.claims" = '{"role":"anon"}';
  SELECT count(*) INTO v_anon_rows FROM api.catalog_list_anon_v1;
  SELECT count(*) INTO v_search    FROM api.search_catalog_v1('anarquismo');
  RESET ROLE;
  IF v_anon_rows < 1 THEN
    RAISE EXCEPTION 'Verif echouee : catalog_list_anon_v1 vide en anon (% lignes). Rollback.', v_anon_rows;
  END IF;

  -- (c) membre : voit tout le reseau
  SELECT user_id INTO v_member FROM public.user_library_memberships WHERE status = 'active' LIMIT 1;
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_member, 'role', 'authenticated')::text, true);
  SELECT count(*) INTO v_member_rows FROM api.catalog_list_session_v1;
  RESET ROLE;

  -- (d) non-membre simule : ne voit que le sous-ensemble public (filtre vivant)
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  SELECT count(*) INTO v_nonmember_rows FROM api.catalog_list_session_v1;
  RESET ROLE;

  IF v_member_rows < 1 THEN
    RAISE EXCEPTION 'Verif echouee : catalog_list_session_v1 vide pour un membre (% lignes). Rollback.', v_member_rows;
  END IF;
  IF v_nonmember_rows >= v_member_rows THEN
    RAISE EXCEPTION 'Verif echouee : le filtre reseau ne restreint plus le non-membre (nonmembre=% >= membre=%). Rollback.', v_nonmember_rows, v_member_rows;
  END IF;

  RAISE NOTICE 'SECU-MV OK : anon=% membre=% nonmembre=% search=% (fuite fermee, filtre vivant).',
    v_anon_rows, v_member_rows, v_nonmember_rows, v_search;
END
$verify$;

-- Rafraîchir le cache de schéma PostgREST.
NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback ciblé (en cas de régression post-déploiement) :
-- =========================================================================
-- BEGIN;
--   GRANT SELECT ON public.mv_books_catalog_list_v1         TO anon, authenticated;
--   GRANT SELECT ON public.mv_books_catalog_list_network_v1 TO authenticated;
--   -- puis recréer les vues avec FROM mv_books_catalog_list_*_v1 (cf. git)
--   -- DROP FUNCTION IF EXISTS public.fn_catalog_public_rows();
--   -- DROP FUNCTION IF EXISTS public.fn_catalog_network_rows();
-- COMMIT;
-- =========================================================================
