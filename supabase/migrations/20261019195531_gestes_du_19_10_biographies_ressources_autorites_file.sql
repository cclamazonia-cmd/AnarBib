-- Quatre gestes décidés par Xavier le 19/10/2026 au soir, gardés chacun par
-- l'état lu en production juste avant (lecture seule), et vérifiés à la fin.
--
-- C30 — les biographies d'autorité traduites automatiquement, VALIDÉES EN BLOC
--   (décision de Xavier, comme pour le roumain). 853 traductions au statut
--   `draft`, déjà affichées sans mention sur les pages d'autorité (la page lit
--   `author_translations` sans filtrer le statut) : 358 portent la note
--   « Traduction automatique (Claude) depuis pt-BR, 19/10/2026 — à relire »,
--   492 plus anciennes (01-18/10) sont de la même série (50 par langue, sans
--   auteur). Passent `reviewed`, avec la décision en note. Seules les
--   traductions nées avant le 19/10 à 19 h 56 UTC sont concernées.
-- D18 — les pages sources des ressources 70, 72, 73, 76 (vérifiées le 15/10,
--   `AUDIT_ressources_restreintes_numdif_2026-10-15.md`, éditions validées par
--   Xavier le 16/10), sur la ressource et son brouillon ; la ressource 62
--   (édition validée le 16/10) reçoit son statut de droits et sa validation.
-- C32 — deux formes « Gramsci » rattachées par erreur à Isidro Guardia Abella
--   (10212) passent à l'autorité de Gramsci (11346) ; Agustín Souchy en double
--   (10304 « Souchy Bauer » dans 10066, qui a l'identifiant Wikidata), par
--   `fn_conv_fusionner_variante` : l'autre graphie survit en forme variante.
-- C3 — les lignes « auteur sans autorité » devenues sans objet (tous les
--   contributeurs de la notice liés à une autorité depuis `1704c05c`) sont
--   écartées, avec le motif.
--
-- Sur une base sans ces lignes (banc, rejeu), chaque geste ne fait rien.

DO $$
DECLARE
  v_n int;
BEGIN
  -- ── C30 ──────────────────────────────────────────────────────────────
  UPDATE public.author_translations t
     SET status = 'reviewed',
         reviewed_at = now(),
         translator_notes = coalesce(t.translator_notes || ' — ', '')
                            || 'Validée en bloc par décision de Xavier, 19/10/2026 (C30), sans relecture native.'
   WHERE t.status = 'draft'
     AND t.created_at < timestamptz '2026-10-19 19:56:00+00';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'C30 : % traduction(s) validée(s) en bloc.', v_n;

  -- ── D18 ──────────────────────────────────────────────────────────────
  WITH pages(resource_id, page) AS (VALUES
    (70, 'https://dokumen.pub/el-congreso-confederal-de-zaragoza-1936-8431704462.html'),
    (72, 'https://pdfcoffee.com/a-anarquia-perante-os-tribunais-pdf-free.html'),
    (73, 'https://www.anarquista.net/ajuda-mutua-um-fator-de-evolucao-de-piotr-kropotkin-livro/'),
    (76, 'https://colectivolibertarioevora.wordpress.com/livros-digitais/')
  ), pub AS (
    UPDATE public.book_digital_resources r
       SET source_page_url = p.page
      FROM pages p
     WHERE r.id = p.resource_id AND r.source_page_url IS NULL
    RETURNING r.id
  )
  UPDATE public.book_draft_digital_resources d
     SET source_page_url = p.page
    FROM pages p
   WHERE d.published_resource_id = p.resource_id AND d.source_page_url IS NULL;

  UPDATE public.book_digital_resources r
     SET rights_status = 'sob_direitos',
         bibliographic_match_validated = true,
         rights_justification = coalesce(r.rights_justification || ' ', '')
                                || 'Edição validada pela administração da rede em 16/10/2026 (D18) ; cópia restrita, fonte de origem fora do ar desde 15/10/2026.'
   WHERE r.id = 62 AND r.rights_status IS NULL AND NOT r.bibliographic_match_validated;

  -- ── C32 ──────────────────────────────────────────────────────────────
  IF EXISTS (SELECT 1 FROM public.authors WHERE id = 11346) THEN
    UPDATE public.author_name_aliases a
       SET author_id = 11346,
           note = coalesce(a.note || ' — ', '') || 'Rattachée par erreur à 10212 ; rendue à Gramsci (11346) le 19/10/2026 (C32).'
     WHERE a.id IN (2778, 2779) AND a.author_id = 10212
       AND a.alias_norm IN ('gramsci', 'gramsci, antonio');
  END IF;
  IF EXISTS (SELECT 1 FROM public.authors WHERE id = 10066)
     AND EXISTS (SELECT 1 FROM public.authors WHERE id = 10304 AND sort_name = 'Bauer, Agustín Souchy') THEN
    PERFORM public.fn_conv_fusionner_variante(10066, 10304, 'C32, 19/10/2026 : même personne (Agustín Souchy Bauer), doublon');
  END IF;

  -- ── C3 ───────────────────────────────────────────────────────────────
  UPDATE public.catalog_review_queue q
     SET decision = 'ecarte',
         decided_at = now(),
         note = coalesce(q.note || ' · ', '')
                || 'Sans objet le 19/10/2026 : tous les contributeurs de la notice sont liés à une autorité (1704c05c).'
   WHERE q.lot = 'autor_sans_autorite'
     AND q.decision = 'a_revoir'
     AND EXISTS (SELECT 1 FROM public.book_contributors c WHERE c.book_id = q.entity_id)
     AND NOT EXISTS (SELECT 1 FROM public.book_contributors c WHERE c.book_id = q.entity_id AND c.author_id IS NULL);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'C3 : % ligne(s) sans objet écartée(s).', v_n;

  -- ── Vérification ─────────────────────────────────────────────────────
  IF EXISTS (SELECT 1 FROM public.author_name_aliases WHERE id IN (2778, 2779) AND author_id = 10212) THEN
    RAISE EXCEPTION 'C32 : une forme « Gramsci » est encore sur 10212.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.book_digital_resources WHERE id IN (70, 72, 73, 76) AND source_page_url IS NULL)
     AND EXISTS (SELECT 1 FROM public.book_digital_resources WHERE id = 62) THEN
    RAISE EXCEPTION 'D18 : une ressource reste sans page source.';
  END IF;
END $$;
