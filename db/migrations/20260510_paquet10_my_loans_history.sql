-- =====================================================================
-- AnarBib — Paquet 10 : vue historique des emprunts cote lecteur
-- Date : 2026-05-10
-- Spec : docs/spec-flux-emprunts.md Phase 4 (item 4)
--
-- Calque sur api.my_reservations_history_v2 (cf. structure exposee
-- par pg_get_viewdef du 10/05). Granularite : 1 ligne par emprunt
-- (et non par item) — agrege titres et autres metadonnees.
-- Ne sort que les emprunts encerrados (status_global = 'encerrado').
--
-- Filtre : auth.uid() via jointure sur api.my_profile (security_invoker)
-- =====================================================================

BEGIN;

CREATE OR REPLACE VIEW api.my_loans_history_v1
WITH (security_invoker='true')
AS
WITH me AS (
  SELECT mp.id, mp.is_authenticated, mp.default_library_id
    FROM api.my_profile mp
),
items_aggreg AS (
  -- Agrege les items de chaque emprunt en colonnes denormalisees
  SELECT
    i.emprestimo_id,
    COUNT(*)::int AS items_count,
    -- Concatener titres en string lisible (separes par ' ; ')
    string_agg(
      COALESCE(i.titulo_cache, '[' || COALESCE(i.bib_ref, '') || ']'),
      ' ; '
      ORDER BY i.line_no
    ) AS titulos,
    string_agg(
      DISTINCT COALESCE(i.autor_cache, ''),
      ' ; '
    ) FILTER (WHERE COALESCE(i.autor_cache, '') <> '') AS autores,
    string_agg(
      i.bib_ref,
      ' ; '
      ORDER BY i.line_no
    ) AS bib_refs,
    -- Date de retour effective : max(returned_at) parmi les items
    MAX(i.returned_at) AS last_returned_at,
    -- Date d'emprunt initiale = min(due_at) effectif... non, on garde
    -- le created_at du header pour la coherence.
    -- Premiere ref pour link vers livre (peu fiable en multi-items mais
    -- mieux que rien)
    MIN(i.book_id) AS first_book_id
  FROM public.emprestimo_itens_v2 i
  GROUP BY i.emprestimo_id
)
SELECT
  e.id AS emprestimo_id,
  e.id AS id,                          -- alias compat pattern reservations
  e.user_id,
  e.library_id,
  l.slug AS library_slug,
  l.display_name AS library_name,
  e.library_id = m.default_library_id AS is_default_library,
  e.status_global,
  e.notes,
  e.created_at AS emprestimo_created_at,
  e.created_at,
  e.updated_at,
  e.due_at,
  e.extended_once,
  e.extended_at,
  e.renewals_used,
  -- Items agreges
  ia.items_count,
  ia.titulos,
  ia.autores,
  ia.bib_refs,
  ia.last_returned_at AS returned_at,
  ia.first_book_id AS book_id,
  -- closed_at = date de cloture effective (dernier retour ou updated_at)
  COALESCE(ia.last_returned_at, e.updated_at) AS closed_at
FROM public.emprestimos_v2 e
JOIN me m ON e.user_id = m.id
LEFT JOIN items_aggreg ia ON ia.emprestimo_id = e.id
LEFT JOIN public.library_commons l ON l.library_id = e.library_id
WHERE m.is_authenticated = true
  AND e.status_global = 'encerrado'
ORDER BY COALESCE(ia.last_returned_at, e.updated_at) DESC, e.id DESC;

ALTER VIEW api.my_loans_history_v1 OWNER TO postgres;

COMMENT ON VIEW api.my_loans_history_v1 IS
'Paquet 10 (10/05/2026) : historique des emprunts encerrados du lecteur
connecte. Granularite : 1 ligne par emprunt (items agreges en titulos/
autores/bib_refs separes par '' ; ''). Calque sur my_reservations_history_v2.
security_invoker=true filtre par auth.uid() via api.my_profile.';

GRANT SELECT ON api.my_loans_history_v1 TO authenticated;

COMMIT;

-- =====================================================================
-- Test apres deploiement :
--
-- SET LOCAL role authenticated;
-- SET LOCAL request.jwt.claim.sub TO '<uuid_lecteur_test>';
-- SELECT emprestimo_id, items_count, titulos, last_returned_at
-- FROM api.my_loans_history_v1
-- LIMIT 5;
-- =====================================================================
