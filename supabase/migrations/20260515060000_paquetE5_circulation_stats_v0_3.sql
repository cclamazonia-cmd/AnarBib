-- ============================================================================
-- Paquet E.5 - Compteur library_circulation_stats.librarians_active sans 'administrador'
-- ============================================================================
-- Date  : 2026-05-15
-- Auteur: Xavier (AnarBib)
-- Ref.  : docs/spec-administrateur-reseau.md v0.3 (compteurs)
--
-- Contexte
-- --------
-- La vue api.library_circulation_stats expose le compteur librarians_active
-- qui agrege les memberships staff par bibliotheque. Avant E.5, le filtre
-- incluait role IN ('librarian', 'coordenador', 'administrador'). Or le role
-- local 'administrador' est deprecie en v0.3 (cf. paquet D.8) au profit de
-- la table transversale network_administrators.
--
-- Doctrine v0.3 §counters :
--   "Page = perimetre, no cross-calculation. Library page counts local
--    memberships; network page counts network admins. A person with both
--    local and network roles appears in both counters without double-counting."
--
-- Donc librarians_active (perimetre local) doit compter seulement les staff
-- locaux v0.3 : 'librarian' et 'coordenador'. Les admins reseau sont compres
-- ailleurs via api.network_overview ou api.network_administrators_public_v1.
--
-- Modification
-- ------------
-- CREATE OR REPLACE VIEW api.library_circulation_stats avec :
--   AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text]))
-- (retire 'administrador'::text du tableau)
--
-- Tout le reste de la definition de la vue est conserve a l'identique.
--
-- Effet en prod : Xavier (seul role='administrador' actif a BLMF) sortira
-- du compteur librarians_active de BLMF. Il reste compte dans network_overview
-- (admin reseau actif). Aucun autre user impacte (cf. audit paquet D.8).
-- ============================================================================

BEGIN;

CREATE OR REPLACE VIEW api.library_circulation_stats AS
SELECT 
    id AS library_id,
    slug,
    name AS library_name,
    ( SELECT count(*) AS count
           FROM emprestimos_v2 e
          WHERE e.library_id = l.id AND e.status_global = 'aberto'::text) AS loans_open,
    ( SELECT count(*) AS count
           FROM emprestimos_v2 e
          WHERE e.library_id = l.id AND e.status_global = 'aberto'::text AND e.due_at < CURRENT_DATE) AS loans_overdue,
    ( SELECT count(*) AS count
           FROM emprestimos_v2 e
          WHERE e.library_id = l.id AND e.status_global = 'devolvido'::text AND e.updated_at >= (CURRENT_DATE - '7 days'::interval)) AS loans_returned_7d,
    ( SELECT count(*) AS count
           FROM emprestimos_v2 e
          WHERE e.library_id = l.id AND (e.status_global = ANY (ARRAY['aberto'::text, 'devolvido'::text])) AND e.created_at >= (CURRENT_DATE - '7 days'::interval)) AS loans_created_7d,
    ( SELECT count(*) AS count
           FROM emprestimos_v2 e
          WHERE e.library_id = l.id AND (e.status_global = ANY (ARRAY['aberto'::text, 'devolvido'::text])) AND e.created_at >= (CURRENT_DATE - '30 days'::interval)) AS loans_created_30d,
    ( SELECT count(*) AS count
           FROM reservas_v2 r
          WHERE r.library_id = l.id AND (r.status_global = ANY (ARRAY['ativa'::text, 'em_preparacao'::text]))) AS reservations_active,
    ( SELECT count(*) AS count
           FROM reservas_v2 r
          WHERE r.library_id = l.id AND (r.status_global = ANY (ARRAY['ativa'::text, 'em_preparacao'::text, 'retirada_efetivada'::text, 'cancelada_leitor'::text, 'cancelada_biblioteca'::text, 'expirada'::text])) AND r.created_at >= (CURRENT_DATE - '30 days'::interval)) AS reservations_30d,
    ( SELECT count(*) AS count
           FROM consultas_locais_v2 c
          WHERE c.library_id = l.id AND (c.status_global = ANY (ARRAY['ativa'::text, 'em_preparacao'::text]))) AS consultations_active,
    ( SELECT count(*) AS count
           FROM book_holdings h
          WHERE h.library_id = l.id) AS holdings_count,
    ( SELECT count(*) AS count
           FROM exemplares e2
          WHERE e2.library_id = l.id) AS exemplars_count,
    ( SELECT count(DISTINCT m.user_id) AS count
           FROM user_library_memberships m
          WHERE m.library_id = l.id AND m.role = 'reader'::text AND m.status = 'active'::text) AS readers_active,
    ( SELECT count(DISTINCT m.user_id) AS count
           FROM user_library_memberships m
          WHERE m.library_id = l.id 
            AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text]))
            AND m.status = 'active'::text) AS librarians_active,
    ( SELECT jsonb_agg(row_to_json(tb.*) ORDER BY tb.cnt DESC) AS jsonb_agg
           FROM ( SELECT b.titulo,
                    b.autor,
                    count(*) AS cnt
                   FROM emprestimo_itens_v2 ei
                     JOIN emprestimos_v2 e ON e.id = ei.emprestimo_id
                     JOIN book_holdings h ON h.id = ei.holding_id
                     JOIN books b ON b.id = h.book_id
                  WHERE e.library_id = l.id AND e.created_at >= (CURRENT_DATE - '90 days'::interval)
                  GROUP BY b.titulo, b.autor
                  ORDER BY (count(*)) DESC
                 LIMIT 5) tb) AS top_books_90d
   FROM libraries l;

COMMENT ON VIEW api.library_circulation_stats IS 
    'E.5 v0.3 - librarians_active compte uniquement librarian + coordenador (role local administrador deprecie). Pour les admins reseau, voir api.network_overview ou api.network_administrators_public_v1.';

COMMIT;

-- ============================================================================
-- Notes post-deploiement
-- ============================================================================
-- 1. Migration enregistree :
--    SELECT version, name FROM supabase_migrations.schema_migrations
--    ORDER BY version DESC LIMIT 3;
--
-- 2. Verifier que la vue ne contient plus 'administrador' dans librarians_active :
--    SELECT pg_get_viewdef('api.library_circulation_stats'::regclass, true)
--    LIKE '%administrador%' AS still_contains_administrador;
--    -- Attendu : false
--
-- 3. Test fonctionnel : appeler la vue pour BLMF
--    SELECT library_name, librarians_active 
--    FROM api.library_circulation_stats 
--    WHERE slug = 'blmf';
--    -- Avant E.5 : Xavier compte (administrador) -> librarians_active = 1
--    -- Apres E.5 : Xavier ne compte plus (pas librarian/coordenador a BLMF) 
--    --             -> librarians_active = 0 (sauf si d'autres staff actifs a BLMF)
--
-- 4. Backlog item #80 paquet E : E.5 livre.
--    Restent E.2 (i18n frontend), E.3 (LibraryContext), E.4 (RedePage).
