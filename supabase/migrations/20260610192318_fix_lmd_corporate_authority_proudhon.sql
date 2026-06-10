-- ════════════════════════════════════════════════════════════════════════════
-- Catalogage : « Le Monde Diplomatique » = autorité COLLECTIVE (auteur corporatif)
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-10 (UTC)
--
-- CAS : « El Mundo libertario : Anarquismo en el Bicentenario de Proudhon »
-- (BTL-TL-001120, books.id=1046, Santiago 2009) — dossier/anthologie produit par
-- la revue Le Monde Diplomatique (édition chilienne), publié sous son nom par
-- l'imprint « Editorial Aún Creemos en los Sueños ».
--
-- ÉTAT FAUTIF : la revue était saisie comme AUTEUR PERSONNEL inversé
-- (« DIPLOMATIQUE, Le Monde », authority_type null = personne), avec des liens
-- incohérents (book_authors en double : rôles 'autor' ET 'outro' ; contributor
-- en rôle 'outro' → la vue canonique, qui n'agrège que role='autor', n'affichait
-- AUCUN auteur).
--
-- DOCTRINE (cf. REGISTRE — CAT-COLL) : œuvre émanant d'une revue/collectif et
-- publiée SOUS SON NOM → autorité de type `collective`, rôle `autor` (entrée
-- principale corporative). `organizador` réservé à « Personne X (org.) » compilant
-- des textes d'auteur·rices distinct·es. `editora` = toujours l'imprint matériel.
--
-- CORRECTION (autorité 10507, exclusive à ce livre) :
--   1. autorité → type collective, nom non inversé « Le Monde Diplomatique » ;
--   2. lien book_authors dédupliqué (1 ligne, role='autor') ;
--   3. contributor role 'outro' → 'autor' (apparaît enfin en vue canonique) ;
--   4. champ plat books.autor nettoyé (forme non inversée).
-- Idempotent (valeurs cibles fixes). Le catalogue public se rafraîchit au prochain
-- REFRESH de la MV (mv_books_catalog_list_*) — non déclenché ici.
-- ════════════════════════════════════════════════════════════════════════════

UPDATE public.authors
  SET preferred_name = 'Le Monde Diplomatique',
      sort_name      = 'Le Monde Diplomatique',
      structured_meta = coalesce(structured_meta, '{}'::jsonb) || '{"authorityType":"collective"}'::jsonb,
      updated_at = now()
  WHERE id = 10507;

-- 2) Dédup du lien canonique : retirer la ligne 'outro', garder une seule 'autor'
DELETE FROM public.book_authors
  WHERE book_id = 1046 AND author_id = 10507 AND role = 'outro';
UPDATE public.book_authors
  SET role = 'autor', ord = 1
  WHERE book_id = 1046 AND author_id = 10507;

-- 3) Contributor : rôle d'entrée principale corporative
UPDATE public.book_contributors
  SET role = 'autor', name = 'Le Monde Diplomatique', is_primary = true, updated_at = now()
  WHERE book_id = 1046 AND author_id = 10507;

-- 4) Champ plat (legacy) : forme non inversée, cohérente avec l'autorité
UPDATE public.books
  SET autor = 'Le Monde Diplomatique', updated_at = now()
  WHERE id = 1046;
