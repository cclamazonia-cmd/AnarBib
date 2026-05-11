-- ============================================================================
-- 20260511040000_paquet23_circulation_stats_distinct_users.sql
-- ============================================================================
-- Paquet 23 v2 — Robustesse multi-rôle de library_circulation_stats
--                + cleanup ligne BLMF du 07/05
--                + homogénéisation du vocabulaire status sur
--                  user_library_memberships (aligné sur network_administrators)
--
-- Réf : étape 0 du paquet B de docs/spec-administrateur-reseau.md v0.1
--
-- Contenu :
--   1. ALTER CHECK sur user_library_memberships.status
--      Avant : ('active', 'inactive', 'pending', 'pending_removal', 'suspended')
--      Après : ('active', 'pending_removal', 'removed', 'inactive')
--      Audit du 11/05 : aucune ligne en 'pending' ou 'suspended' → safe.
--      Aligne sur le vocabulaire de network_administrators (cohérence
--      conceptuelle avec la spec-administrateur-reseau v0.1).
--
--   2. Cleanup de la ligne user_library_memberships coordenador BLMF du 07/05.
--      Passage en status='removed' (préserve la traçabilité historique vs DELETE).
--
--   3. Réécriture de api.library_circulation_stats :
--      - librarians_active : COUNT(DISTINCT user_id) au lieu de COUNT(*)
--      - readers_active    : COUNT(DISTINCT user_id) au lieu de COUNT(*)
--      Rend la vue robuste face au multi-rôle même personne / même biblio.
--
-- Atomicité : transaction unique. Si n'importe quel garde-fou échoue, rollback.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 0 : VÉRIFICATION DE SÉCURITÉ PRÉALABLE
-- ============================================================================
-- Avant de modifier le CHECK, s'assurer qu'aucune ligne existante n'utilise
-- un status qui ne serait pas dans le nouveau domaine (pending, suspended).

DO $$
DECLARE
    v_bad_count integer;
BEGIN
    SELECT count(*) INTO v_bad_count
    FROM public.user_library_memberships
    WHERE status NOT IN ('active', 'pending_removal', 'removed', 'inactive');
    
    IF v_bad_count > 0 THEN
        RAISE EXCEPTION 'cannot_narrow_status_check: % rows have a status outside the new allowed set (active, pending_removal, removed, inactive). Migrate them first.', v_bad_count;
    END IF;
    
    RAISE NOTICE 'precheck_ok: 0 row with disallowed status, safe to narrow the CHECK';
END;
$$;

-- ============================================================================
-- SECTION 1 : ALTER CHECK SUR user_library_memberships.status
-- ============================================================================

ALTER TABLE public.user_library_memberships
    DROP CONSTRAINT user_library_memberships_status_check;

ALTER TABLE public.user_library_memberships
    ADD CONSTRAINT user_library_memberships_status_check 
    CHECK (status IN ('active', 'pending_removal', 'removed', 'inactive'));

COMMENT ON CONSTRAINT user_library_memberships_status_check 
    ON public.user_library_memberships IS 
'Domaine des status d''un membership local. Aligné sur network_administrators (paquet 23, 11/05/2026) pour cohérence conceptuelle réseau/local. Anciens status pending et suspended retirés : aucune ligne ne les utilisait au 11/05.';

DO $$
BEGIN
    RAISE NOTICE 'check_updated: user_library_memberships.status now allows (active, pending_removal, removed, inactive)';
END;
$$;

-- ============================================================================
-- SECTION 2 : CLEANUP DU DOUBLON BLMF
-- ============================================================================
-- Passage en status='removed' (préserve traçabilité historique conformément
-- spec gouvernance du 5/05) de la ligne coordenador créée le 07/05 par effet
-- de bord des tests Phase B.

WITH cleanup AS (
    UPDATE public.user_library_memberships
    SET status = 'removed',
        updated_at = now()
    WHERE user_id = 'd6710372-e5e5-4608-800b-99a26817c677'  -- Xavier
      AND library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'  -- BLMF
      AND role = 'coordenador'
      AND status = 'active'
      AND created_at >= '2026-05-07 00:00:00+00'  -- ligne créée le 7/05
      AND created_at <  '2026-05-08 00:00:00+00'
    RETURNING id, user_id, library_id, role, status, created_at, updated_at
)
SELECT 'cleanup_result' AS info, * FROM cleanup;

-- Validation : exactement 1 ligne modifiée
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM public.user_library_memberships
    WHERE user_id = 'd6710372-e5e5-4608-800b-99a26817c677'
      AND library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
      AND role = 'coordenador'
      AND status = 'removed'
      AND updated_at >= (now() - interval '1 minute');
    
    IF v_count = 0 THEN
        RAISE EXCEPTION 'cleanup_failed: aucune ligne BLMF coordenador trouvée correspondant aux critères. Vérifier manuellement.';
    END IF;
    
    IF v_count > 1 THEN
        RAISE EXCEPTION 'cleanup_multiple_rows: % lignes modifiées au lieu d''une seule. ROLLBACK conseillé.', v_count;
    END IF;
    
    RAISE NOTICE 'cleanup_ok: 1 ligne user_library_memberships passée en status=removed';
END;
$$;

-- Safety check : l'admin BLMF du 24/03 doit toujours être actif
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM public.user_library_memberships
    WHERE user_id = 'd6710372-e5e5-4608-800b-99a26817c677'
      AND library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
      AND role = 'administrador'
      AND status = 'active';
    
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'admin_safety_check_failed: l''administrateur BLMF de Xavier devrait toujours être actif (status=active), trouvé % lignes', v_count;
    END IF;
    
    RAISE NOTICE 'admin_safety_check_ok: administrateur BLMF de Xavier intact';
END;
$$;

-- ============================================================================
-- SECTION 3 : RÉÉCRITURE DE api.library_circulation_stats
--             AVEC COUNT(DISTINCT user_id)
-- ============================================================================
-- Repart du paquet 22 (vue sans WHERE EXISTS, librarians_active élargi
-- aux 3 rôles staff), modifie uniquement les 2 compteurs de personnes.

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
    
    -- Paquet 23 : COUNT(DISTINCT user_id) pour compter des personnes.
    ( SELECT count(DISTINCT m.user_id)
        FROM user_library_memberships m
        WHERE m.library_id = l.id 
          AND m.role = 'reader'::text 
          AND m.status = 'active'::text
    ) AS readers_active,
    
    -- Paquet 22 : élargissement aux 3 rôles staff (sémantique "équipe").
    -- Paquet 23 : COUNT(DISTINCT user_id) pour robustesse multi-rôle.
    -- Note : 'administrador' restera dans l'ARRAY pendant toute la phase
    -- de coexistence (paquets B → F de spec-administrateur-reseau.md).
    -- Au paquet F, retrait après suppression du rôle de user_library_memberships.
    ( SELECT count(DISTINCT m.user_id)
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

GRANT SELECT ON api.library_circulation_stats TO authenticated;

COMMENT ON VIEW api.library_circulation_stats IS 
'Statistiques de circulation par bibliothèque. Vue agrégeant emprunts, '
'réservations, consultations, équipe et lecteurs actifs. '
'Sécurité déléguée aux RLS des tables sous-jacentes. '
'Paquet 22 (11/05/2026) : suppression du WHERE EXISTS qui invisibilisait '
'la vue pour les administrateurs réseau. '
'Paquet 23 (11/05/2026) : COUNT(DISTINCT user_id) sur librarians_active et '
'readers_active pour robustesse face au multi-rôle.';

-- ============================================================================
-- SECTION 4 : VALIDATION FINALE
-- ============================================================================

DO $$
DECLARE
    v_blmf_librarians integer;
    v_blmf_readers integer;
BEGIN
    SELECT librarians_active, readers_active 
    INTO v_blmf_librarians, v_blmf_readers
    FROM api.library_circulation_stats
    WHERE slug = 'blmf';
    
    IF v_blmf_librarians IS NULL THEN
        RAISE WARNING 'validation_warning: pas de ligne BLMF dans la vue. Vérifier manuellement.';
    ELSE
        RAISE NOTICE 'validation: BLMF librarians_active=% readers_active=%', v_blmf_librarians, v_blmf_readers;
        
        IF v_blmf_librarians <> 1 THEN
            RAISE WARNING 'validation_warning: BLMF librarians_active=% (attendu : 1, Xavier comme administrador uniquement)', v_blmf_librarians;
        ELSE
            RAISE NOTICE 'validation_ok: BLMF librarians_active=1';
        END IF;
    END IF;
END;
$$;

COMMIT;

-- ============================================================================
-- Vérifications manuelles post-application :
-- ============================================================================
-- 
-- 1. CHECK constraint mis à jour :
--    SELECT pg_get_constraintdef(c.oid)
--    FROM pg_constraint c
--    JOIN pg_class t ON t.oid = c.conrelid
--    WHERE t.relname = 'user_library_memberships'
--      AND c.conname = 'user_library_memberships_status_check';
--    Attendu : CHECK ((status = ANY (ARRAY['active'::text, 'pending_removal'::text, 'removed'::text, 'inactive'::text])))
-- 
-- 2. Ligne BLMF coordenador en status=removed :
--    SELECT role, status, created_at, updated_at 
--    FROM user_library_memberships
--    WHERE user_id = 'd6710372-e5e5-4608-800b-99a26817c677'
--      AND library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
--    ORDER BY created_at;
-- 
-- 3. Plus de doublons staff :
--    SELECT user_id, library_id, count(*) AS nb
--    FROM user_library_memberships
--    WHERE status = 'active'
--      AND role = ANY (ARRAY['librarian','coordenador','administrador'])
--    GROUP BY user_id, library_id
--    HAVING count(*) > 1;
--    Attendu : 0 ligne
-- 
-- 4. /rede recharge (Ctrl+Shift+R) : bandeau EQUIPE = 2, BLMF Equipe = 1
--
-- ============================================================================
-- Fin du fichier.
-- ============================================================================
