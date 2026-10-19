-- =========================================================================
-- Une notice d'une source partenaire, sans fichier, renvoie à sa page dans
-- la source (Anarchief.org : 393 notices)
-- =========================================================================
-- Date     : 2026-10-19
-- Chantier : sources partenaires — Anarchief.org (bibliothèque source)
-- Auteur   : Claude (assistant·e), pour la coordination
-- Session  : Anarchief — autorités et liens vers le wiki
-- Ref      : migration 20261019122125 (bibliothèque source, catalog_public) ;
--            tests/sql/lien_page_source_tests.sql ;
--            message à l'archiviste du 19/10/2026 (« voor de andere 393
--            voegen we die link nog toe »), accord de l'archiviste du 19/10
--            (« akkoord met elke verdere stap vooruit »)
--
-- POURQUOI
--   Les 1 002 notices d'Anarchief.Org sont au catalogue public depuis le
--   19/10. Les 609 notices qui ont un PDF renvoient à leur page du wiki par
--   leur ressource (source_page_url, « Aussi en ligne : Anarchief.org »). Les
--   393 autres n'ont que l'identifiant d'import (`book_external_ids`, schéma
--   `import:33`, valeur = identifiant de page du wiki), invisible : le
--   lecteur·rice ne peut pas aller voir la page d'origine. Le message envoyé
--   à l'archiviste le 19/10 promet ce lien.
--
-- CE QUE FAIT LE PAQUET
--   1. private.fn_lien_vers_la_page_source(bibliothèque, schéma, gabarit,
--      source, libellé, note, langue) : pour chaque notice tenue par la
--      bibliothèque, portant un identifiant du schéma donné et AUCUNE
--      ressource numérique (active ou non), ajoute une ressource
--      « lien externe » publique et validée vers gabarit(identifiant).
--      Rejouable (une notice qui a déjà une ressource est sautée),
--      SECURITY INVOKER, sans appelant API (EXECUTE retiré à PUBLIC).
--      Réutilisable pour une autre source partenaire, ou pour les notices
--      d'Anarchief qui arriveraient plus tard sans fichier.
--   2. L'appel pour Anarchief.Org, s'il existe (en production seulement ;
--      au banc la bibliothèque n'existe pas et rien n'est écrit).
--
-- LA FORME DU LIEN
--   https://anarchief.org/w/index.php?curid=<identifiant de page>, comme les
--   1 470 ressources PDF existantes (source_page_url). JAMAIS le titre de
--   page du wiki : certains portent un nom de lieu, et la commune de
--   l'archiviste ne doit apparaître nulle part (règle de sécurité du
--   19/10/2026). Pour la même raison, le libellé et la note sont des textes
--   FIXES : ni titre, ni nom de fichier, ni lieu. L'identifiant n'est
--   accepté que s'il est fait de chiffres (garde dans la fonction : une
--   valeur d'une autre forme ne fabrique pas d'URL).
--
-- CE QUE VOIT LE PUBLIC
--   La ressource est `link_externo` (type et usage), `publico`, active,
--   `bibliographic_match_validated` (la page EST la source de la notice),
--   jamais principale (un PDF versé plus tard passe devant), sans fichier
--   stocké, `text/html`. Le catalogue l'annonce « En ligne (lien) » ; la
--   fiche donne le lien vers la page (BookPage, même livraison).
--
-- CHECKLIST DOCTRINE
--   - Aucune table, aucun index, aucune policy neuve ; une fonction INVOKER
--     dans `private`, EXECUTE retiré à PUBLIC, anon, authenticated (garde
--     grants_herites T12).
--   - Écritures de lignes seules, pas de verrou exclusif de table.
--   - Garde finale : aucune notice d'Anarchief.Org ne reste sans ressource ;
--     toute ressource neuve suit le gabarit curid.
-- =========================================================================

CREATE OR REPLACE FUNCTION private.fn_lien_vers_la_page_source(
  p_library_id  uuid,
  p_scheme      text,
  p_gabarit     text,
  p_source_name text,
  p_label       text,
  p_note        text,
  p_language    text DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $fn$
DECLARE
  v_n integer;
BEGIN
  IF p_library_id IS NULL OR coalesce(p_scheme, '') = '' THEN
    RAISE EXCEPTION 'fn_lien_vers_la_page_source : bibliothèque et schéma requis';
  END IF;
  IF p_gabarit IS NULL OR p_gabarit !~ '^https://[^\s{}]+\{id\}[^\s{}]*$' THEN
    RAISE EXCEPTION 'fn_lien_vers_la_page_source : gabarit invalide (https://…{id}…) : %', p_gabarit;
  END IF;
  IF coalesce(btrim(p_label), '') = '' OR coalesce(btrim(p_source_name), '') = '' THEN
    RAISE EXCEPTION 'fn_lien_vers_la_page_source : libellé et nom de la source requis';
  END IF;

  WITH cibles AS (
    SELECT DISTINCT ON (e.book_id) e.book_id, e.value
      FROM public.book_external_ids e
     WHERE e.scheme = p_scheme
       AND e.value ~ '^[0-9]+$'
       AND EXISTS (SELECT 1 FROM public.book_holdings h
                    WHERE h.book_id = e.book_id AND h.library_id = p_library_id)
       AND NOT EXISTS (SELECT 1 FROM public.book_digital_resources r
                        WHERE r.book_id = e.book_id)
     ORDER BY e.book_id, e.value::bigint
  ), ins AS (
    INSERT INTO public.book_digital_resources (
      book_id, resource_type, usage_type, access_scope, status, is_active,
      mime_type, label, notes, language_code, source_name, source_url,
      source_page_url, attribution_text, is_primary,
      bibliographic_match_validated, activated_at, metadata)
    SELECT c.book_id, 'link_externo', 'link_externo', 'publico', 'active', true,
           'text/html', p_label, p_note, p_language, p_source_name,
           replace(p_gabarit, '{id}', c.value),
           replace(p_gabarit, '{id}', c.value),
           'Fonte: ' || p_source_name || ' (página ' || c.value || ')',
           false, true, now(),
           jsonb_build_object('source_identifier', c.value,
                              'source_scheme', p_scheme,
                              'added_via', 'private.fn_lien_vers_la_page_source')
      FROM cibles c
    RETURNING 1
  )
  SELECT count(*) INTO v_n FROM ins;
  RETURN v_n;
END
$fn$;

REVOKE ALL ON FUNCTION private.fn_lien_vers_la_page_source(uuid, text, text, text, text, text, text)
  FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION private.fn_lien_vers_la_page_source(uuid, text, text, text, text, text, text) IS
  'Ajoute une ressource « lien externe » publique vers sa page source à chaque notice de la bibliothèque qui porte un identifiant du schéma donné et n''a aucune ressource numérique. Rejouable. Migration 20261019144029.';

-- ── L'appel pour Anarchief.Org (production seulement) ──────────────────
DO $anarchief_liens$
DECLARE
  v_lib uuid;
  v_n integer;
  v_reste integer;
  v_hors integer;
BEGIN
  SELECT id INTO v_lib FROM public.libraries WHERE slug = 'anarchief-org';
  IF v_lib IS NULL THEN
    RAISE NOTICE 'Anarchief.Org absente (banc) : aucun lien ajouté';
    RETURN;
  END IF;

  v_n := private.fn_lien_vers_la_page_source(
    v_lib,
    'import:33',
    'https://anarchief.org/w/index.php?curid={id}',
    'Anarchief.org',
    'Página da ficha no Anarchief.org',
    'Ligação para a página desta ficha no wiki de origem, acrescentada em 19/10/2026 '
      || 'para as fichas sem arquivo digital, com o acordo do arquivista (mensagem de 19/10/2026).',
    'nl');

  -- Garde 1 : plus aucune notice d'Anarchief.Org sans ressource.
  SELECT count(*) INTO v_reste
    FROM (SELECT DISTINCT h.book_id FROM public.book_holdings h WHERE h.library_id = v_lib) b
   WHERE NOT EXISTS (SELECT 1 FROM public.book_digital_resources r WHERE r.book_id = b.book_id);
  IF v_reste > 0 THEN
    RAISE EXCEPTION 'Anarchief : % notice(s) restent sans ressource après l''ajout des liens', v_reste;
  END IF;

  -- Garde 2 : chaque lien posé suit le gabarit curid (jamais un titre de page).
  SELECT count(*) INTO v_hors
    FROM public.book_digital_resources r
   WHERE r.resource_type = 'link_externo'
     AND r.metadata->>'added_via' = 'private.fn_lien_vers_la_page_source'
     AND r.metadata->>'source_scheme' = 'import:33'
     AND (r.source_url !~ '^https://anarchief\.org/w/index\.php\?curid=[0-9]+$'
          OR r.source_page_url IS DISTINCT FROM r.source_url);
  IF v_hors > 0 THEN
    RAISE EXCEPTION 'Anarchief : % lien(s) hors du gabarit curid', v_hors;
  END IF;

  RAISE NOTICE 'Anarchief : % lien(s) vers la page du wiki ajouté(s)', v_n;
END
$anarchief_liens$;
