-- ============================================================================
-- 2026_05_11_fix_library_circulation_stats.sql
-- ============================================================================
-- Corrige deux bugs dans la vue api.library_circulation_stats :
--
-- BUG A — Sécurité trop restrictive
--   La clause "WHERE EXISTS (... auth.uid() ... staff de cette biblio)"
--   empêchait les administrateurs réseau de voir les stats des biblios dont
--   ils ne sont pas membres staff. Conséquence : RedePage onglet
--   "Visão geral" affichait 0 partout pour un admin réseau.
--   Fix : on enlève la clause. Les RLS des tables sous-jacentes
--   (emprestimos_v2, reservas_v2, consultas_locais_v2,
--   user_library_memberships, book_holdings, exemplares) gèrent déjà
--   l'autorisation correctement, audit RLS du 11/05/2026 confirmé.
--
-- BUG B — Comptage 'librarians_active' incomplet
--   La vue comptait uniquement role='librarian' strict, oubliant
--   coordenador et administrador. Une biblio avec 1 coordinatrice et
--   0 librarian apparaissait avec "EQUIPE: 0" — UX trompeuse.
--   Fix : élargissement à role IN ('librarian','coordenador','administrador')
--   pour cohérence avec la fonction user_has_library_staff_role et la
--   sémantique "fait partie de l'équipe" posée le 5/05/2026.
--
-- Tous les autres compteurs sont inchangés.
-- ============================================================================

CREATE OR REPLACE VIEW api.library_circulation_stats AS
SELECT 
    l.id AS library_id,
    l.slug,
    l.name AS library_name,
    
    ( SELECT count(*)
        FROM emprestimos_v2 e
        WHERE e.library_id = l.id 
          AND e.status_global = 'aberto'::text
    ) AS loans_open,
    
    ( SELECT count(*)
        FROM emprestimos_v2 e
        WHERE e.library_id = l.id 
          AND e.status_global = 'aberto'::text 
          AND e.due_at < CURRENT_DATE
    ) AS loans_overdue,
    
    ( SELECT count(*)
        FROM emprestimos_v2 e
        WHERE e.library_id = l.id 
          AND e.status_global = 'devolvido'::text 
          AND e.updated_at >= (CURRENT_DATE - '7 days'::interval)
    ) AS loans_returned_7d,
    
    ( SELECT count(*)
        FROM emprestimos_v2 e
        WHERE e.library_id = l.id 
          AND e.status_global = ANY (ARRAY['aberto'::text, 'devolvido'::text])
          AND e.created_at >= (CURRENT_DATE - '7 days'::interval)
    ) AS loans_created_7d,
    
    ( SELECT count(*)
        FROM emprestimos_v2 e
        WHERE e.library_id = l.id 
          AND e.status_global = ANY (ARRAY['aberto'::text, 'devolvido'::text])
          AND e.created_at >= (CURRENT_DATE - '30 days'::interval)
    ) AS loans_created_30d,
    
    ( SELECT count(*)
        FROM reservas_v2 r
        WHERE r.library_id = l.id 
          AND r.status_global = ANY (ARRAY['ativa'::text, 'em_preparacao'::text])
    ) AS reservations_active,
    
    ( SELECT count(*)
        FROM reservas_v2 r
        WHERE r.library_id = l.id 
          AND r.status_global = ANY (ARRAY[
            'ativa'::text, 
            'em_preparacao'::text, 
            'retirada_efetivada'::text, 
            'cancelada_leitor'::text, 
            'cancelada_biblioteca'::text, 
            'expirada'::text
          ])
          AND r.created_at >= (CURRENT_DATE - '30 days'::interval)
    ) AS reservations_30d,
    
    ( SELECT count(*)
        FROM consultas_locais_v2 c
        WHERE c.library_id = l.id 
          AND c.status_global = ANY (ARRAY['ativa'::text, 'em_preparacao'::text])
    ) AS consultations_active,
    
    ( SELECT count(*)
        FROM book_holdings h
        WHERE h.library_id = l.id
    ) AS holdings_count,
    
    ( SELECT count(*)
        FROM exemplares e2
        WHERE e2.library_id = l.id
    ) AS exemplars_count,
    
    ( SELECT count(*)
        FROM user_library_memberships m
        WHERE m.library_id = l.id 
          AND m.role = 'reader'::text 
          AND m.status = 'active'::text
    ) AS readers_active,
    
    -- FIX BUG B : élargissement aux 3 rôles staff (sémantique "équipe")
    -- Aligne sur user_has_library_staff_role défini le 5/05/2026 :
    -- "fait partie de l'équipe" = librarian + coordenador + administrador
    ( SELECT count(*)
        FROM user_library_memberships m
        WHERE m.library_id = l.id 
          AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text, 'administrador'::text])
          AND m.status = 'active'::text
    ) AS librarians_active,
    
    ( SELECT jsonb_agg(row_to_json(tb.*) ORDER BY tb.cnt DESC)
        FROM ( SELECT b.titulo,
                    b.autor,
                    count(*) AS cnt
                FROM emprestimo_itens_v2 ei
                JOIN emprestimos_v2 e ON e.id = ei.emprestimo_id
                JOIN book_holdings h ON h.id = ei.holding_id
                JOIN books b ON b.id = h.book_id
                WHERE e.library_id = l.id 
                  AND e.created_at >= (CURRENT_DATE - '90 days'::interval)
                GROUP BY b.titulo, b.autor
                ORDER BY count(*) DESC
                LIMIT 5
        ) tb
    ) AS top_books_90d
    
FROM libraries l;
-- FIX BUG A : suppression du WHERE EXISTS qui filtrait à l'utilisateur courant.
-- Les RLS des tables sous-jacentes (emprestimos_v2, reservas_v2, etc.)
-- prennent le relais — audit du 11/05/2026 :
--   - emprestimos_v2_select_policy : auth.uid()=user_id OR can_access_painel
--   - reservas_v2_select_own + reservas_v2_select_librarian_same_library
--   - consultas_locais_v2_select_policy : idem emprestimos_v2
--   - ulm_select_all_for_administrador : fn_caller_is_administrador()
--   - book_holdings_public_read : fn_library_visible_to_caller()
--   - exemplares_public_read : via fn_library_visible_to_caller cascade

-- Permissions : la vue était déjà accessible à authenticated, on conserve.
GRANT SELECT ON api.library_circulation_stats TO authenticated;

-- Commentaire pour mémoire institutionnelle
COMMENT ON VIEW api.library_circulation_stats IS 
'Statistiques de circulation par bibliothèque. Vue agrégeant emprunts, '
'réservations, consultations, équipe et lecteurs actifs. '
'Sécurité déléguée aux RLS des tables sous-jacentes. '
'Réf migration 2026_05_11_fix_library_circulation_stats.sql.';
