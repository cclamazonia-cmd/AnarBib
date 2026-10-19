-- Un lieu retiré des copies d'import d'une notice (19/10/2026, demande de
-- Xavier, sécurité d'un partenaire).
--
-- Un partenaire a demandé qu'un nom de lieu qui le situe n'apparaisse plus
-- nulle part. Il a été effacé le 19/10 des champs visibles (bibliothèque,
-- éditeur de la notice), mais il restait dans les COPIES D'IMPORT de la notice
-- `ANARCHIEF-21161` : le titre de la page source (« … (<lieu>, <année>) »), son
-- adresse, et l'éditeur brut — dans `books.marc_json.ingest.raw_payload` (lisible
-- sans compte depuis que la bibliothèque publie au catalogue), dans le
-- brouillon publié, la ligne d'import et la référence d'import (`ingest`).
--
-- Ce fichier ne contient pas ce nom, et n'en contiendra jamais aucun : il le
-- relit dans la donnée — la parenthèse finale du titre de page de la notice —
-- puis le retire de chaque copie qui porte ce même titre de page :
--   * l'adresse de la page devient l'adresse neutre `…/index.php?curid=<page>` ;
--   * un champ qui ne contenait que le lieu devient vide ;
--   * un texte qui le contenait le perd (« (<lieu>, 2024) » → « (2024) »).
-- Puis il VÉRIFIE qu'il n'en reste rien dans ces lignes, et échoue sinon (rien
-- n'est alors écrit).
--
-- `private.fn_jsonb_sans_lieu` reste disponible pour un cas semblable.
-- Sans la notice (banc, rejeu, ou une fois le lieu retiré), ne fait rien.

CREATE OR REPLACE FUNCTION private.fn_jsonb_sans_lieu(p_doc jsonb, p_lieu text, p_url_page text DEFAULT NULL)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $function$
  SELECT CASE
    WHEN p_doc IS NULL OR jsonb_typeof(p_doc) <> 'object' OR nullif(btrim(coalesce(p_lieu, '')), '') IS NULL THEN p_doc
    ELSE (
      SELECT coalesce(jsonb_object_agg(e.key,
        CASE
          WHEN e.key = 'url_page' AND p_url_page IS NOT NULL
               AND position(lower(btrim(p_lieu)) IN lower(coalesce(e.value #>> '{}', ''))) > 0
            THEN to_jsonb(p_url_page)
          WHEN jsonb_typeof(e.value) = 'string' AND lower(btrim(e.value #>> '{}')) = lower(btrim(p_lieu))
            THEN 'null'::jsonb
          WHEN jsonb_typeof(e.value) = 'string' AND position(lower(btrim(p_lieu)) IN lower(e.value #>> '{}')) > 0
            THEN to_jsonb(btrim(regexp_replace(regexp_replace(regexp_replace(
                   e.value #>> '{}',
                   '\(\s*' || regexp_replace(btrim(p_lieu), '([.\\+*?\[^\]$(){}=!<>|:/-])', '\\\1', 'g') || '\s*,\s*', '(', 'gi'),
                   regexp_replace(btrim(p_lieu), '([.\\+*?\[^\]$(){}=!<>|:/-])', '\\\1', 'g'), '', 'gi'),
                   '\s{2,}', ' ', 'g')))
          ELSE e.value
        END), '{}'::jsonb)
      FROM jsonb_each(p_doc) e)
  END
$function$;

REVOKE ALL ON FUNCTION private.fn_jsonb_sans_lieu(jsonb, text, text) FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION private.fn_jsonb_sans_lieu(jsonb, text, text) IS
  'Retire un nom de lieu des valeurs texte de premier niveau d''un objet jsonb (champ égal → null ; texte qui le contient → sans lui ; url_page → p_url_page). 19/10/2026.';

DO $$
DECLARE
  v_book   bigint;
  v_page   text;
  v_titre  text;
  v_lieu   text;
  v_url    text;
  v_esc    text;
  v_reste  int;
BEGIN
  SELECT b.id, b.marc_json->'ingest'->'raw_payload'->>'cle', b.marc_json->'ingest'->'raw_payload'->>'titre_wiki'
    INTO v_book, v_page, v_titre
    FROM public.books b
   WHERE b.bib_ref = 'ANARCHIEF-21161';
  IF v_book IS NULL THEN
    RAISE NOTICE 'Lieu : notice absente — rien à faire.';
    RETURN;
  END IF;

  v_lieu := btrim(substring(v_titre FROM '\(([^,()]+),\s*\d{4}\)\s*$'));
  IF v_lieu IS NULL OR length(v_lieu) NOT BETWEEN 2 AND 60 THEN
    RAISE NOTICE 'Lieu : aucun lieu à retirer dans le titre de page — rien à faire.';
    RETURN;
  END IF;
  v_url := 'https://anarchief.org/w/index.php?curid=' || v_page;
  v_esc := regexp_replace(v_lieu, '([.\\+*?\[^\]$(){}=!<>|:/-])', '\\\1', 'g');

  -- 1. La notice publiée.
  -- (la racine du marc_json aussi : un brouillon y garde un `publisher` brut ;
  --  jsonb_set n'est appelé que si la copie d'import existe, jamais sur NULL)
  UPDATE public.books b
     SET marc_json = CASE WHEN b.marc_json->'ingest'->'raw_payload' IS NOT NULL
                          THEN jsonb_set(private.fn_jsonb_sans_lieu(b.marc_json, v_lieu, v_url), '{ingest,raw_payload}',
                                         private.fn_jsonb_sans_lieu(b.marc_json->'ingest'->'raw_payload', v_lieu, v_url))
                          ELSE private.fn_jsonb_sans_lieu(b.marc_json, v_lieu, v_url) END
   WHERE b.id = v_book;

  -- 2. Ses brouillons (publié ou non) : même titre de page.
  UPDATE public.book_drafts d
     SET marc_json = CASE WHEN d.marc_json->'ingest'->'raw_payload' IS NOT NULL
                          THEN jsonb_set(private.fn_jsonb_sans_lieu(d.marc_json, v_lieu, v_url), '{ingest,raw_payload}',
                                         private.fn_jsonb_sans_lieu(d.marc_json->'ingest'->'raw_payload', v_lieu, v_url))
                          ELSE private.fn_jsonb_sans_lieu(d.marc_json, v_lieu, v_url) END,
         editora = CASE WHEN d.editora ~* v_esc THEN nullif(btrim(regexp_replace(d.editora, v_esc, '', 'gi')), '') ELSE d.editora END,
         local_publicacao = CASE WHEN d.local_publicacao ~* v_esc THEN nullif(btrim(regexp_replace(d.local_publicacao, v_esc, '', 'gi')), '') ELSE d.local_publicacao END
   WHERE d.published_book_id = v_book
      OR d.marc_json->'ingest'->'raw_payload'->>'titre_wiki' = v_titre;

  -- 3. La ligne d'import et 4. la référence d'import : même titre de page.
  UPDATE ingest.partner_catalog_staging_rows s
     SET raw_payload = private.fn_jsonb_sans_lieu(s.raw_payload, v_lieu, v_url),
         normalized_payload = private.fn_jsonb_sans_lieu(s.normalized_payload, v_lieu, v_url),
         publisher = CASE WHEN s.publisher ~* v_esc THEN nullif(btrim(regexp_replace(s.publisher, v_esc, '', 'gi')), '') ELSE s.publisher END
   WHERE s.raw_payload->>'titre_wiki' = v_titre;

  UPDATE ingest.book_import_baselines r
     SET raw_payload = private.fn_jsonb_sans_lieu(r.raw_payload, v_lieu, v_url),
         mapped = private.fn_jsonb_sans_lieu(r.mapped, v_lieu, v_url)
   WHERE r.raw_payload->>'titre_wiki' = v_titre;

  -- Vérification : plus aucune trace dans ces lignes, sinon tout est annulé.
  SELECT (SELECT count(*) FROM public.books b WHERE b.id = v_book AND to_jsonb(b)::text ~* v_esc)
       + (SELECT count(*) FROM public.book_drafts d WHERE (d.published_book_id = v_book OR d.marc_json->'ingest'->'raw_payload'->>'titre_wiki' = v_titre) AND to_jsonb(d)::text ~* v_esc)
       + (SELECT count(*) FROM ingest.partner_catalog_staging_rows s WHERE s.raw_payload->>'cle' = v_page AND to_jsonb(s)::text ~* v_esc)
       + (SELECT count(*) FROM ingest.book_import_baselines r WHERE r.raw_payload->>'cle' = v_page AND to_jsonb(r)::text ~* v_esc)
    INTO v_reste;
  IF v_reste > 0 THEN
    RAISE EXCEPTION 'Lieu : % ligne(s) le portent encore après nettoyage — migration annulée.', v_reste;
  END IF;
  RAISE NOTICE 'Lieu : retiré des copies d''import de la notice %.', v_book;
END $$;
