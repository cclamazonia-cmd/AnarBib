-- =========================================================================
-- api.library_circulation_stats : + colonne trocas_active
-- =========================================================================
-- Date     : 2026-06-08 (horodatage UTC reel)
-- Chantier : Completude rapports (consultations + trocas) -- reliquat grille
-- Auteur   : Xavier + Claude
-- Session  : QR codes etiquettes module mobile
--
-- OBJET
-- -----
-- Ajoute trocas_active a la vue de stats (snapshot du bandeau « Relatorios e
-- resumos »), pour afficher « Trocas ativas » a cote de Reservas/Consultas.
-- Une troca active = document_permission_requests object_type=
-- 'interlibrary_exchange', status='accepted', impliquant la biblio (requerante
-- OU cible), dont la phase d'execution (object_ref JSON) n'est ni 'completed'
-- ni 'cancelled' (phase absente/illisible = active).
--
-- Helper try_parse_jsonb : cast jsonb securise (NULL si texte non-JSON), pour
-- ne jamais casser la vue (utilisee a chaque chargement du tableau de bord)
-- sur un object_ref malforme.
--
-- CREATE OR REPLACE VIEW : colonnes existantes inchangees (memes noms/ordre/
-- types) ; trocas_active ajoutee EN FIN. security_invoker=true conserve.
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.try_parse_jsonb(p_text text)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog
AS $fn$
BEGIN
  RETURN p_text::jsonb;
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$fn$;

CREATE OR REPLACE VIEW api.library_circulation_stats
WITH (security_invoker = true) AS
 SELECT l.id AS library_id,
    l.slug,
    l.name AS library_name,
    ( SELECT count(*) FROM public.emprestimos_v2 e
       WHERE e.library_id = l.id AND e.status_global = 'aberto' AND e.archived_at IS NULL) AS loans_open,
    ( SELECT count(*) FROM public.emprestimos_v2 e
       WHERE e.library_id = l.id AND e.status_global = 'aberto' AND e.due_at < CURRENT_DATE AND e.archived_at IS NULL) AS loans_overdue,
    ( SELECT count(*) FROM public.emprestimos_v2 e
       WHERE e.library_id = l.id AND e.status_global = 'devolvido' AND e.updated_at >= (CURRENT_DATE - interval '7 days') AND e.archived_at IS NULL) AS loans_returned_7d,
    ( SELECT count(*) FROM public.emprestimos_v2 e
       WHERE e.library_id = l.id AND e.status_global = ANY (ARRAY['aberto','devolvido']) AND e.created_at >= (CURRENT_DATE - interval '7 days') AND e.archived_at IS NULL) AS loans_created_7d,
    ( SELECT count(*) FROM public.emprestimos_v2 e
       WHERE e.library_id = l.id AND e.status_global = ANY (ARRAY['aberto','devolvido']) AND e.created_at >= (CURRENT_DATE - interval '30 days') AND e.archived_at IS NULL) AS loans_created_30d,
    ( SELECT count(*) FROM public.reservas_v2 r
       WHERE r.library_id = l.id AND r.status_global = ANY (ARRAY['ativa','em_preparacao']) AND r.archived_at IS NULL) AS reservations_active,
    ( SELECT count(*) FROM public.reservas_v2 r
       WHERE r.library_id = l.id AND r.status_global = ANY (ARRAY['ativa','em_preparacao','retirada_efetivada','cancelada_leitor','cancelada_biblioteca','expirada']) AND r.created_at >= (CURRENT_DATE - interval '30 days') AND r.archived_at IS NULL) AS reservations_30d,
    ( SELECT count(*) FROM public.consultas_locais_v2 c
       WHERE c.library_id = l.id AND c.status_global = ANY (ARRAY['ativa','em_preparacao']) AND c.archived_at IS NULL) AS consultations_active,
    ( SELECT count(*) FROM public.book_holdings h
       WHERE h.library_id = l.id) AS holdings_count,
    ( SELECT count(*) FROM public.exemplares e2
       WHERE e2.library_id = l.id) AS exemplars_count,
    ( SELECT count(DISTINCT m.user_id) FROM public.user_library_memberships m
       WHERE m.library_id = l.id AND m.role = 'reader' AND m.status = 'active') AS readers_active,
    ( SELECT count(DISTINCT m.user_id) FROM public.user_library_memberships m
       WHERE m.library_id = l.id AND m.role = ANY (ARRAY['librarian','coordenador']) AND m.status = 'active') AS librarians_active,
    ( SELECT jsonb_agg(row_to_json(tb.*) ORDER BY tb.cnt DESC) AS jsonb_agg
       FROM ( SELECT b.titulo, b.autor, count(*) AS cnt
                FROM public.emprestimo_itens_v2 ei
                  JOIN public.emprestimos_v2 e ON e.id = ei.emprestimo_id
                  JOIN public.book_holdings h ON h.id = ei.holding_id
                  JOIN public.books b ON b.id = h.book_id
               WHERE e.library_id = l.id AND e.created_at >= (CURRENT_DATE - interval '90 days') AND e.archived_at IS NULL
               GROUP BY b.titulo, b.autor
               ORDER BY count(*) DESC
              LIMIT 5) tb) AS top_books_90d,
    ( SELECT count(*) FROM public.document_permission_requests dpr
       WHERE dpr.object_type = 'interlibrary_exchange'
         AND dpr.status = 'accepted'
         AND (dpr.requester_library_id = l.id OR dpr.target_library_id = l.id)
         AND COALESCE(public.try_parse_jsonb(dpr.object_ref) -> 'execution_followup' ->> 'phase', '') NOT IN ('completed','cancelled')
    ) AS trocas_active
   FROM public.libraries l;

COMMIT;

-- =========================================================================
-- Rollback : recreer la vue sans la colonne trocas_active (CREATE OR REPLACE)
-- et DROP FUNCTION public.try_parse_jsonb(text) si plus utilisee.
-- =========================================================================
