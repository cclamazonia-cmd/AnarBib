-- =========================================================================
-- Paquet AUT-VAR — les formes variantes d'une autorité servent enfin
-- =========================================================================
-- Date     : 2026-10-12
-- Chantier : catalogage / autorités
-- Auteur   : Xavier (+ Claude)
--
-- CONSTAT (fiche « Serge Netchaïev », 11577, créée le 12/10 à 14:36 UTC).
-- L'ouvrage MLEG-0025 porte le contributeur « Netchaev », sans autorité. Sur la
-- fiche, « Rattacher aux œuvres » répondait « Aucune œuvre candidate », alors
-- que la fiche portait « Serguei Netchaev » dans « Formes variantes » et une
-- soixantaine de graphies Wikidata. Quatre défauts s'additionnaient :
--
--   1. suggest_author_book_matches ne lisait que preferred_name, sort_name et
--      variant_forms s'il était un TABLEAU. Or Wikidata range les graphies
--      par langue ({"fr": [...], ...} : 37 fiches), les fusions en tableau
--      d'objets ({form, source} : 15 fiches, lus comme du JSON brut), et le
--      champ « Formes variantes » saisi à la main (structured_meta.variantNames,
--      comme « Pseudonymes ») n'était lu par AUCUNE recherche. « netchaev »
--      contre « netchaiev serge » seul : similarité 0,39 < 0,45.
--   2. Le formulaire ne rechargeait pas variant_forms en rouvrant une fiche ;
--      au réenregistrement il envoyait NULL, et publish_author_draft écrasait
--      l'autorité. Quatre fiches y ont perdu leurs graphies (Netchaïev, Barrué,
--      Rocker, Eichenbaum) ; leurs brouillons les gardent. Le formulaire est
--      corrigé dans le même commit ; la base ne s'y fie plus pour autant.
--   3. Les deux détections de doublons ne comparaient que des NOMS : deux
--      fiches au même Wikidata/VIAF/ISNI et aux noms éloignés (« Sergei
--      Nechayev » / « Serge Netchaïev », similarité 0,19) ne se voyaient pas.
--      9 paires au même Wikidata en prod au 12/10.
--
-- CE QUE FAIT LE PAQUET.
--   a. private.fn_formes_d_un_auteur(id) : TOUTES les formes normalisées d'une
--      autorité — nom, forme de tri, alias actifs, variant_forms sous ses deux
--      formes (objet par langue ; tableau de chaînes ou de {form}), « Formes
--      variantes » et « Pseudonymes » découpés sur , ; et retour à la ligne.
--      Lecture du jsonb reprise de private.fn_auteurs_par_nom (11/10).
--   b. suggest_author_book_matches lit ces formes. Corps inchangé sinon.
--   c. suggest_author_duplicates ET suggest_authority_duplicates (DEDUP-6 :
--      les deux ensemble) reconnaissent un identifiant commun — Wikidata,
--      VIAF ou ISNI, chacun comparé à lui-même — même quand les noms
--      s'éloignent. Les paires écartées (author_not_duplicate) restent
--      écartées. Les formes variantes n'entrent PAS dans la détection de
--      doublons : elle reste sur les noms + alias, pour ne pas faire diverger
--      les deux vues.
--   d. publish_author_draft : variant_forms = coalesce(brouillon, autorité)
--      à la mise à jour — un brouillon sans graphies n'efface plus celles de
--      l'autorité (aucun écran ne permet de les vider volontairement).
--   e. Restauration : les autorités sans variant_forms reprennent celles de
--      leur dernier brouillon qui en avait.
--
-- CHECKLIST DOCTRINE :
--   [x] Fonction neuve dans private, INVOKER, search_path vide, REVOKE PUBLIC,
--       anon, authenticated (appelée seulement par des DEFINER de postgres)
--   [x] CREATE OR REPLACE des quatre fonctions repartant de pg_get_functiondef
--       de la PROD (12/10, 14:50 UTC) — signatures, défauts, DEFINER et
--       search_path identiques ; les ACL sont conservées par OR REPLACE
--   [x] DO block de vérification
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- a. Toutes les formes d'une autorité
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.fn_formes_d_un_auteur(p_author_id bigint)
 RETURNS text[]
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  SELECT coalesce(pg_catalog.array_agg(DISTINCT n.forme) FILTER (WHERE n.forme <> ''), '{}'::text[])
    FROM public.authors a
    CROSS JOIN LATERAL (
      SELECT a.preferred_name AS brute
      UNION ALL
      SELECT a.sort_name
      UNION ALL
      SELECT x.alias_text
        FROM public.author_name_aliases x
       WHERE x.author_id = a.id AND x.is_active
      UNION ALL
      -- variant_forms : {"fr": ["Pierre Kropotkine", …], …} (Wikidata)
      SELECT f.forme
        FROM pg_catalog.jsonb_each(CASE WHEN pg_catalog.jsonb_typeof(a.variant_forms) = 'object'
                                        THEN a.variant_forms ELSE '{}'::jsonb END) l,
             pg_catalog.jsonb_array_elements_text(CASE WHEN pg_catalog.jsonb_typeof(l.value) = 'array'
                                                       THEN l.value ELSE '[]'::jsonb END) f(forme)
      UNION ALL
      -- … ou [{"form": "…", "source": "fusion …"}] (fusions du 05/09), ou ["…"]
      SELECT CASE pg_catalog.jsonb_typeof(e)
               WHEN 'object' THEN e->>'form'
               WHEN 'string' THEN e #>> '{}'
             END
        FROM pg_catalog.jsonb_array_elements(CASE WHEN pg_catalog.jsonb_typeof(a.variant_forms) = 'array'
                                                  THEN a.variant_forms ELSE '[]'::jsonb END) e
      UNION ALL
      -- « Formes variantes » et « Pseudonymes » saisis à la main (texte libre).
      SELECT m
        FROM pg_catalog.regexp_split_to_table(
               coalesce(a.structured_meta->>'variantNames', '') || E'\n' ||
               coalesce(a.structured_meta->>'pseudonyms', ''),
               '[,;\n]+') m
    ) s
    CROSS JOIN LATERAL (SELECT public.fn_normalize_name(pg_catalog.btrim(s.brute)) AS forme) n
   WHERE a.id = p_author_id
     AND s.brute IS NOT NULL
$function$;

COMMENT ON FUNCTION private.fn_formes_d_un_auteur(bigint) IS
  'AUT-VAR (12/10/2026) : formes normalisées (fn_normalize_name) d''une autorité — nom, tri, alias actifs, variant_forms (objet par langue ou tableau), structured_meta.variantNames et pseudonyms découpés sur , ; et retour à la ligne.';

REVOKE ALL ON FUNCTION private.fn_formes_d_un_auteur(bigint) FROM PUBLIC, anon, authenticated;

-- -------------------------------------------------------------------------
-- b. Rattacher aux œuvres : toutes les formes
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.suggest_author_book_matches(p_author_id bigint)
 RETURNS TABLE(contributor_id bigint, book_id bigint, book_title text, contributor_name text, role text, match_kind text, score real)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
DECLARE
  v_forms text[];
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  -- AUT-VAR : toutes les formes (variantes Wikidata, saisies, pseudonymes, alias).
  v_forms := private.fn_formes_d_un_auteur(p_author_id);

  IF v_forms IS NULL OR array_length(v_forms, 1) IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH cand AS (
    SELECT bc.id AS cid, bc.book_id AS bid, bc.name AS cname, bc.role AS crole,
           public.fn_normalize_name(bc.name) AS cn
    FROM public.book_contributors bc
    WHERE bc.author_id IS NULL
  )
  SELECT c.cid, c.bid, b.titulo, c.cname, c.crole,
         CASE WHEN c.cn = ANY (v_forms) THEN 'exact' ELSE 'approx' END,
         CASE WHEN c.cn = ANY (v_forms) THEN 1.0::real
              ELSE (SELECT max(similarity(c.cn, f)) FROM unnest(v_forms) f) END
  FROM cand c
  JOIN public.books b ON b.id = c.bid
  WHERE c.cn <> ''
    AND ( c.cn = ANY (v_forms)
          OR (SELECT max(similarity(c.cn, f)) FROM unnest(v_forms) f) >= 0.45 )
  ORDER BY 7 DESC, b.titulo;
END;
$function$;

-- -------------------------------------------------------------------------
-- c1. Doublons par autorité : + identifiant commun
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.suggest_author_duplicates(p_author_id bigint)
 RETURNS TABLE(author_id bigint, preferred_name text, sort_name text, linked_books integer, match_kind text, score real)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
DECLARE
  v_forms text[];
  v_wd    text;
  v_viaf  text;
  v_isni  text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  SELECT array_agg(DISTINCT nf) INTO v_forms
  FROM (
    SELECT public.fn_normalize_name(a.preferred_name) AS nf FROM public.authors a WHERE a.id = p_author_id
    UNION
    SELECT public.fn_normalize_name(a.sort_name) FROM public.authors a WHERE a.id = p_author_id
    UNION
    SELECT al.alias_norm FROM public.author_name_aliases al WHERE al.author_id = p_author_id AND al.is_active
  ) s
  WHERE s.nf <> '';

  IF v_forms IS NULL OR array_length(v_forms, 1) IS NULL THEN
    RETURN;
  END IF;

  -- AUT-VAR : identifiants de la fiche (vides = absents).
  SELECT nullif(btrim(a.wikidata_id), ''), nullif(btrim(a.viaf_id), ''), nullif(btrim(a.isni), '')
    INTO v_wd, v_viaf, v_isni
    FROM public.authors a WHERE a.id = p_author_id;

  RETURN QUERY
  WITH other AS (
    SELECT a.id, a.preferred_name, a.sort_name,
           public.fn_normalize_name(a.preferred_name) AS np,
           coalesce(nullif(btrim(a.wikidata_id), '') = v_wd, false)
             OR coalesce(nullif(btrim(a.viaf_id), '') = v_viaf, false)
             OR coalesce(nullif(btrim(a.isni), '') = v_isni, false) AS meme_id
    FROM public.authors a
    WHERE a.id <> p_author_id
  )
  SELECT o.id, o.preferred_name, o.sort_name,
         (SELECT count(DISTINCT ba.book_id)::integer FROM public.book_authors ba WHERE ba.author_id = o.id),
         CASE WHEN o.meme_id OR o.np = ANY (v_forms) THEN 'exact' ELSE 'approx' END,
         CASE WHEN o.meme_id OR o.np = ANY (v_forms) THEN 1.0::real
              ELSE (SELECT max(similarity(o.np, f)) FROM unnest(v_forms) f) END
  FROM other o
  WHERE ( o.meme_id
          OR ( o.np <> ''
               AND ( o.np = ANY (v_forms)
                     OR (SELECT max(similarity(o.np, f)) FROM unnest(v_forms) f) >= 0.45 ) ) )
    -- AJOUT P11 : les paires arbitrées « pas un doublon » sortent de la détection.
    AND NOT EXISTS (
      SELECT 1 FROM public.author_not_duplicate nd
       WHERE nd.author_id_a = least(p_author_id, o.id)
         AND nd.author_id_b = greatest(p_author_id, o.id)
    )
  ORDER BY 6 DESC, o.preferred_name;
END;
$function$;

-- -------------------------------------------------------------------------
-- c2. Balayage global : + paires à identifiant commun (DEDUP-6)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.suggest_authority_duplicates(p_max integer DEFAULT 500)
 RETURNS TABLE(author_id_a bigint, nom_a text, tri_a text, oeuvres_a integer, author_id_b bigint, nom_b text, tri_b text, oeuvres_b integer, match_kind text, score real, niveau_preuve text, rang_preuve integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian','coordenador'])
                   AND m.status = 'active') THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;

  PERFORM set_config('pg_trgm.similarity_threshold', '0.3', true);

  RETURN QUERY
  WITH formes AS (
    SELECT a.id, public.fn_normalize_name(a.preferred_name) AS f FROM public.authors a
    UNION
    SELECT a.id, public.fn_normalize_name(a.sort_name) FROM public.authors a
    UNION
    SELECT al.author_id, al.alias_norm FROM public.author_name_aliases al WHERE al.is_active
  ), formes_net AS (
    SELECT id, f FROM formes WHERE f IS NOT NULL AND f <> ''
  ), ids AS (
    -- AJOUT AUT-VAR : chaque identifiant comparé à lui-même.
    SELECT a.id, 'wd'::text AS k, nullif(btrim(a.wikidata_id), '') AS v FROM public.authors a
    UNION ALL
    SELECT a.id, 'viaf', nullif(btrim(a.viaf_id), '') FROM public.authors a
    UNION ALL
    SELECT a.id, 'isni', nullif(btrim(a.isni), '') FROM public.authors a
  ), candidats AS (
    SELECT DISTINCT least(fo.id, b.id) AS ida, greatest(fo.id, b.id) AS idb
    FROM formes_net fo
    JOIN public.authors b
      ON b.id <> fo.id
     AND public.fn_normalize_name(b.preferred_name) % fo.f
    UNION
    -- AJOUT AUT-VAR : même identifiant, quels que soient les noms.
    SELECT x.id, y.id
    FROM ids x
    JOIN ids y ON y.k = x.k AND y.v = x.v AND y.id > x.id
    WHERE x.v IS NOT NULL
  ), evalues AS (
    SELECT c.ida, c.idb,
           aa.preferred_name AS na, aa.sort_name AS sa,
           ab.preferred_name AS nb, ab.sort_name AS sb,
           public.fn_normalize_name(aa.preferred_name) AS npa,
           public.fn_normalize_name(ab.preferred_name) AS npb,
           aa.birth_year AS ba, aa.death_year AS da,
           ab.birth_year AS bb, ab.death_year AS db,
           nullif(btrim(coalesce(aa.viaf_id, aa.isni, '')), '') AS xa,
           nullif(btrim(coalesce(ab.viaf_id, ab.isni, '')), '') AS xb,
           EXISTS (SELECT 1 FROM ids i JOIN ids j ON j.k = i.k AND j.v = i.v
                    WHERE i.id = c.ida AND j.id = c.idb AND i.v IS NOT NULL) AS meme_ident
    FROM candidats c
    JOIN public.authors aa ON aa.id = c.ida
    JOIN public.authors ab ON ab.id = c.idb
    -- AJOUT P11 : même exclusion que la détection par autorité.
    WHERE NOT EXISTS (
      SELECT 1 FROM public.author_not_duplicate nd
       WHERE nd.author_id_a = c.ida AND nd.author_id_b = c.idb
    )
  ), scores AS (
    SELECT e.*,
           (EXISTS (SELECT 1 FROM formes_net f WHERE f.id = e.ida AND f.f = e.npb)
            OR EXISTS (SELECT 1 FROM formes_net f WHERE f.id = e.idb AND f.f = e.npa)) AS exact,
           greatest(
             coalesce((SELECT max(similarity(e.npb, f.f)) FROM formes_net f WHERE f.id = e.ida), 0),
             coalesce((SELECT max(similarity(e.npa, f.f)) FROM formes_net f WHERE f.id = e.idb), 0)
           )::real AS sc
    FROM evalues e
  ), classes AS (
    SELECT s.*,
           coalesce((s.ba IS NOT NULL AND s.ba = s.bb) OR (s.da IS NOT NULL AND s.da = s.db), false) AS dates_ok,
           coalesce(s.xa IS NOT NULL AND s.xa = s.xb, false) OR s.meme_ident AS meme_id
    FROM scores s
    WHERE s.exact OR s.sc >= 0.45 OR s.meme_ident
  )
  SELECT
    k.ida, k.na, k.sa,
    (SELECT count(DISTINCT ba.book_id)::integer FROM public.book_authors ba WHERE ba.author_id = k.ida),
    k.idb, k.nb, k.sb,
    (SELECT count(DISTINCT bb.book_id)::integer FROM public.book_authors bb WHERE bb.author_id = k.idb),
    CASE WHEN k.exact THEN 'exact' ELSE 'approx' END,
    k.sc,
    CASE WHEN k.meme_id  THEN 'identifiant'
         WHEN k.exact    THEN 'nom_exact'
         WHEN k.dates_ok THEN 'nom_et_dates'
         ELSE 'nom_seul' END,
    CASE WHEN k.meme_id  THEN 1
         WHEN k.exact    THEN 2
         WHEN k.dates_ok THEN 3
         ELSE 4 END
  FROM classes k
  ORDER BY
    CASE WHEN k.meme_id THEN 1 WHEN k.exact THEN 2 WHEN k.dates_ok THEN 3 ELSE 4 END,
    k.sc DESC, k.na
  LIMIT greatest(1, coalesce(p_max, 500));
END;
$function$;

-- -------------------------------------------------------------------------
-- d. Publier : un brouillon sans graphies n'efface plus celles de l'autorité
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.publish_author_draft(p_draft_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_draft public.author_drafts%rowtype;
  v_author_id bigint;
begin
  -- #79 RBAC : publication reservee au staff de catalogage (librarian/coordenador).
  -- B30 : le staff de catalogage ACTIF, ou l'administration du réseau — les
  -- lots sans bibliothèque ne sont qu'à elle ; la garde #79 ne demandait pas
  -- d'adhésion active et fermait la porte à l'administration sans adhésion.
  IF NOT (public.fn_caller_is_network_admin()
          OR EXISTS (SELECT 1 FROM public.user_library_memberships m
                      WHERE m.user_id = auth.uid() AND m.status = 'active'
                        AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text]))) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.' USING HINT = 'error.catalog.staff_only';
  END IF;
  select * into v_draft
  from public.author_drafts
  where id = p_draft_id;

  if not found then
    raise exception 'Rascunho de autor nao encontrado: %', p_draft_id;
  end if;
  -- B29 (CAT-E18 2) : un brouillon d'autorité se lit partout, mais ne s'écrit
  -- (ni ne se publie) que par qui l'a créé, ou par l'administration du réseau.
  if not coalesce(public.fn_caller_can_edit_author_draft(p_draft_id), false) then
    raise exception 'Rascunho de autoridade de outra pessoa.' using hint = 'error.catalog.author_draft_creator_only';
  end if;

  if v_draft.status = 'cancelled' then
    raise exception 'Este rascunho de autor foi descartado.';
  end if;

  if v_draft.published_author_id is null then
    insert into public.authors (
      preferred_name, sort_name, biography, birth_year, death_year, country,
      source_kind, source_label, source_url, viaf_id, isni, wikidata_id,
      variant_forms, photo_object_path, notes, structured_meta, writing_language, name_lang,
      created_by, updated_by, updated_at
    )
    values (
      v_draft.preferred_name, v_draft.sort_name, v_draft.biography,
      v_draft.birth_year, v_draft.death_year, v_draft.country,
      v_draft.source_kind, v_draft.source_label, v_draft.source_url,
      v_draft.viaf_id, v_draft.isni, v_draft.wikidata_id,
      v_draft.variant_forms, v_draft.photo_object_path, v_draft.notes,
      coalesce(v_draft.structured_meta, '{}'::jsonb), v_draft.writing_language, v_draft.name_lang,
      coalesce(v_draft.created_by, auth.uid()),
      coalesce(v_draft.updated_by, auth.uid()), now()
    )
    returning id into v_author_id;
  else
    update public.authors
    set
      preferred_name = v_draft.preferred_name,
      sort_name = v_draft.sort_name,
      biography = v_draft.biography,
      birth_year = v_draft.birth_year,
      death_year = v_draft.death_year,
      country = v_draft.country,
      source_kind = v_draft.source_kind,
      source_label = v_draft.source_label,
      source_url = v_draft.source_url,
      viaf_id = v_draft.viaf_id,
      isni = v_draft.isni,
      wikidata_id = v_draft.wikidata_id,
      -- AUT-VAR : un brouillon sans graphies (formulaire qui ne les rechargeait
      -- pas, avant le 12/10) ne vide plus celles de l'autorité.
      variant_forms = coalesce(v_draft.variant_forms, variant_forms),
      photo_object_path = v_draft.photo_object_path,
      notes = v_draft.notes,
      structured_meta = coalesce(v_draft.structured_meta, '{}'::jsonb),
      writing_language = v_draft.writing_language,
      name_lang = v_draft.name_lang,
      updated_by = coalesce(v_draft.updated_by, auth.uid()),
      updated_at = now()
    where id = v_draft.published_author_id
    returning id into v_author_id;
  end if;

  update public.author_drafts
  set
    published_author_id = v_author_id,
    status = 'published',
    updated_by = coalesce(v_draft.updated_by, auth.uid()),
    updated_at = now()
  where id = p_draft_id;

  return v_author_id;
end;
$function$;

-- -------------------------------------------------------------------------
-- e. Rendre aux autorités les graphies que leurs brouillons ont gardées
-- -------------------------------------------------------------------------
UPDATE public.authors a
   SET variant_forms = d.variant_forms
  FROM (
    SELECT DISTINCT ON (ad.published_author_id) ad.published_author_id, ad.variant_forms
      FROM public.author_drafts ad
     WHERE ad.published_author_id IS NOT NULL
       AND ad.variant_forms IS NOT NULL
       AND jsonb_typeof(ad.variant_forms) IN ('object', 'array')
       AND ad.variant_forms NOT IN ('{}'::jsonb, '[]'::jsonb)
     ORDER BY ad.published_author_id, ad.updated_at DESC, ad.id DESC
  ) d
 WHERE a.id = d.published_author_id
   AND a.variant_forms IS NULL;

-- -------------------------------------------------------------------------
-- Vérification
-- -------------------------------------------------------------------------
DO $$
DECLARE
  v_n int;
BEGIN
  IF has_function_privilege('anon', 'private.fn_formes_d_un_auteur(bigint)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'private.fn_formes_d_un_auteur(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'AUT-VAR : private.fn_formes_d_un_auteur ouverte à anon/authenticated.';
  END IF;
  IF has_function_privilege('anon', 'public.suggest_author_book_matches(bigint)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.suggest_author_duplicates(bigint)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.suggest_authority_duplicates(integer)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.publish_author_draft(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'AUT-VAR : une fonction remplacée est devenue exécutable par anon.';
  END IF;
  SELECT count(*) INTO v_n
    FROM public.authors a
   WHERE a.variant_forms IS NULL
     AND EXISTS (SELECT 1 FROM public.author_drafts ad
                  WHERE ad.published_author_id = a.id
                    AND jsonb_typeof(ad.variant_forms) IN ('object', 'array')
                    AND ad.variant_forms NOT IN ('{}'::jsonb, '[]'::jsonb));
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'AUT-VAR : % autorité(s) sans les graphies de leurs brouillons.', v_n;
  END IF;
END $$;

COMMIT;
