-- Catalogue : repli de l'auteur canonique vers organisateur/coordinateur/collectif
-- en l'absence de role 'autor' (par analogie avec le repli realisateur/compositeur
-- deja en place pour l'audiovisuel/audio).
--
-- Bug corrige : une notice dont le seul contributeur relie porte un role
-- organizacao / organizador / coordenador / coletivo (et non 'autor') n'avait
-- AUCUN author_display canonique -> la MV catalogue retombait sur le texte legacy
-- fige books.autor (jamais resynchronise sur les liens). ~14 notices concernees
-- (13 'organizacao' = collectifs CNT/FARJ/CCLA + la notice 842 'coordenador',
-- "Cronache Anarchiche", Franco Schirone).
--
-- La correction d'un sort_name corrompu isole (auteur 11325) est geree
-- separement cote fiche auteur, hors de cette migration.

-- 1) Vue canonique elargie (preserve security_invoker=true ; memes colonnes).
CREATE OR REPLACE VIEW public.v_book_authors_canonical
WITH (security_invoker = true) AS
WITH per_book AS (
  SELECT bc.book_id, bool_or(bc.role = 'autor') AS has_autor
  FROM public.book_contributors bc
  GROUP BY bc.book_id
),
canon_source AS (
  SELECT bc.book_id, bc.author_id, bc."position" AS ord,
         COALESCE(NULLIF(btrim(a.sort_name), ''),
                  NULLIF(btrim(a.preferred_name), ''),
                  NULLIF(btrim(bc.name), '')) AS base_name
  FROM public.book_contributors bc
    LEFT JOIN public.authors a ON a.id = bc.author_id
    LEFT JOIN public.books b   ON b.id = bc.book_id
    LEFT JOIN per_book pb       ON pb.book_id = bc.book_id
  WHERE bc.role = 'autor'
     OR (pb.has_autor = false AND (
            (b.tipo_material = 'audiovisual' AND bc.role = 'realizador')
         OR (b.tipo_material = 'audio'       AND bc.role = 'compositor')
         OR (COALESCE(b.tipo_material, '') NOT IN ('audiovisual', 'audio')
             AND bc.role IN ('organizador', 'organizacao', 'coordenador', 'coletivo'))
        ))
),
canon AS (
  SELECT cs.book_id, cs.author_id, cs.ord,
         CASE
           WHEN cs.base_name IS NULL THEN NULL::text
           WHEN POSITION(',' IN cs.base_name) > 0
             THEN upper(btrim(split_part(cs.base_name, ',', 1)))
                  || CASE
                       WHEN NULLIF(btrim(substring(cs.base_name FROM POSITION(',' IN cs.base_name) + 1)), '') IS NOT NULL
                         THEN ', ' || btrim(substring(cs.base_name FROM POSITION(',' IN cs.base_name) + 1))
                       ELSE ''
                     END
           ELSE cs.base_name
         END AS display_name
  FROM canon_source cs
)
SELECT book_id,
       string_agg(display_name, ' ; ' ORDER BY ord, display_name) AS author_display,
       jsonb_agg(jsonb_build_object('author_id', author_id, 'label', display_name, 'ord', ord)
                 ORDER BY ord, display_name) AS author_chips
FROM canon
GROUP BY book_id;

-- 2) Rafraichir les MV catalogue (publique + reseau) -> propage l'affichage.
SELECT public.refresh_mv_books_catalog_list_v1();

-- 3) Recharger le cache de schema PostgREST (vue publique modifiee).
NOTIFY pgrst, 'reload schema';
