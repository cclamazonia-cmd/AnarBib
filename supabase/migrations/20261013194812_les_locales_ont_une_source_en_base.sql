-- =====================================================================
-- AnarBib — les locales ont une source en base : public.fn_supported_locales()
-- Date    : 2026-10-13  ·  Chantier « locale ro », lot 1 (source unique)
-- Doctrine: DOC-I18N-4 (une source par couche), DOC-GRANT-2/3 (droits
--           explicites), « repartir de la définition réelle »
-- Banc    : tests/sql/locales_source_unique_tests.sql
--
-- CONSTAT (13/10/2026, production lue en lecture seule). La liste des dix
-- locales était recopiée dans huit contraintes CHECK et huit fonctions, dans
-- trois ordres différents (« en, it » ou « it, en » ; « el » avant ou après
-- « ca »). Ajouter une langue demandait seize retouches, et une copie oubliée
-- refuse la langue sans bruit — c'est arrivé côté Edge Functions (register,
-- 27/08) et dans install.sh (DOC-I18N-2, 20/09).
--
-- CE QUE FAIT CETTE MIGRATION, sans rien changer à ce qu'acceptent les tables :
--  1. public.fn_supported_locales() rend les dix codes, dans l'ordre de l'app
--     (src/i18n/locales.js) : pt-BR, fr, es, en, it, de, ca, eo, nl, el.
--     L'ordre n'est pas décoratif : tg_libraries_read_languages_normaliser
--     range read_languages dans cet ordre, comme le front (ReadLanguagesField).
--  2. Les huit contraintes la lisent. Particularités gardées à l'identique :
--     gazette_sources accepte aussi 'mul' (flux multilingue),
--     gazette_submissions accepte NULL.
--  3. Les huit fonctions la lisent, définitions repartant de
--     pg_get_functiondef en production (13/10) — propriétaire, SECURITY,
--     search_path et ACL inchangés (vérifiés en fin de migration).
--     fn_work_titles_pending perd aussi son « < 10 » en dur : une œuvre est
--     complète quand elle a un titre par locale, quel qu'en soit le nombre.
--
-- DROITS (DOC-GRANT-2/3). Une contrainte CHECK et un déclencheur INVOKER
-- appellent la fonction AVEC LES DROITS DE QUI ÉCRIT : authenticated (les
-- politiques d'écriture des huit tables sont toutes TO authenticated) et
-- service_role (Edge Functions). anon n'a de politique d'écriture sur aucune
-- des huit tables : la fonction lui est fermée, explicitement, et la liste
-- fermée de grants_herites (T12) n'a pas à bouger. Pas de SECURITY DEFINER :
-- une constante n'a rien à lire.
--
-- IMMUTABLE : la fonction ne change qu'avec une migration. Y AJOUTER une
-- langue ne rend aucune ligne invalide ; en RETIRER une laisserait des lignes
-- que les contraintes ne revalident pas — un retrait se prépare à part.
--
-- Hors périmètre (lot 2/3) : fn_locale_from_idioma, ingest.fn_idioma_bcp47
-- (correspondances de codes de notice), fn_notify_fonds_deposit_received
-- (chaînes en dur), la regex de casse de phrase de 20260904130100.
--
-- Verrous : DROP/ADD CONSTRAINT prend un ACCESS EXCLUSIVE sur huit tables
-- (dont libraries) le temps de revalider — à ne pas pousser pour un backend
-- qui tomberait dans la sauvegarde de 19:00 (Paris), ni le dimanche 20:00.
-- =====================================================================

-- Instantané des huit fonctions avant réécriture (comparé en fin de migration).
CREATE TEMP TABLE _locales_fonctions_avant AS
SELECT p.oid, p.oid::regprocedure::text AS sig, p.proowner, p.prosecdef, p.proconfig, p.proacl::text AS acl, p.provolatile
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE (n.nspname, p.proname) IN (
   ('api', 'fn_lettre_set_locale'), ('api', 'fn_work_title_validate'),
   ('public', 'fn_correspondance_langue'), ('public', 'fn_work_proposal_check'),
   ('public', 'fn_work_titles_autofill_apply'), ('public', 'fn_work_titles_pending'),
   ('public', 'set_work_title'), ('public', 'tg_libraries_read_languages_normaliser'));

-- ── 1. La source ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_supported_locales()
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT ARRAY['pt-BR','fr','es','en','it','de','ca','eo','nl','el']::text[]
$function$;

COMMENT ON FUNCTION public.fn_supported_locales() IS
  'Les locales de l''app, dans l''ordre du sélecteur (DOC-I18N-4). Source SQL unique : contraintes CHECK et fonctions la lisent. Même liste que src/i18n/locales.js et supabase/functions/_shared/i18n/locales.ts.';

REVOKE ALL ON FUNCTION public.fn_supported_locales() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_supported_locales() TO authenticated, service_role;

-- ── 2. Les huit contraintes ─────────────────────────────────────────
ALTER TABLE public.author_translations
  DROP CONSTRAINT author_translations_lang_check,
  ADD CONSTRAINT author_translations_lang_check CHECK (lang = ANY (public.fn_supported_locales()));

ALTER TABLE public.gazette_issue_locales
  DROP CONSTRAINT gazette_issue_locales_locale_check,
  ADD CONSTRAINT gazette_issue_locales_locale_check CHECK (locale = ANY (public.fn_supported_locales()));

ALTER TABLE public.gazette_sources
  DROP CONSTRAINT gazette_sources_locale_check,
  ADD CONSTRAINT gazette_sources_locale_check CHECK (locale = ANY (public.fn_supported_locales() || 'mul'::text));

ALTER TABLE public.gazette_submissions
  DROP CONSTRAINT gazette_submissions_locale_check,
  ADD CONSTRAINT gazette_submissions_locale_check CHECK (locale IS NULL OR locale = ANY (public.fn_supported_locales()));

ALTER TABLE public.lettre_issue_locales
  DROP CONSTRAINT lettre_issue_locales_locale_check,
  ADD CONSTRAINT lettre_issue_locales_locale_check CHECK (locale = ANY (public.fn_supported_locales()));

ALTER TABLE public.libraries
  DROP CONSTRAINT libraries_read_languages_check,
  ADD CONSTRAINT libraries_read_languages_check CHECK (read_languages <@ public.fn_supported_locales());

ALTER TABLE public.library_messages
  DROP CONSTRAINT library_messages_lang_check,
  ADD CONSTRAINT library_messages_lang_check CHECK (lang = ANY (public.fn_supported_locales()));

ALTER TABLE public.work_titles
  DROP CONSTRAINT work_titles_lang_check,
  ADD CONSTRAINT work_titles_lang_check CHECK (lang = ANY (public.fn_supported_locales()));

-- ── 3. Les huit fonctions (définitions de production du 13/10/2026) ──
-- « x NOT IN (liste) » devient « x <> ALL (fn_supported_locales()) » : même
-- sémantique, NULL compris (les deux rendent NULL, donc ne lèvent pas).

CREATE OR REPLACE FUNCTION api.fn_lettre_set_locale(p_issue_id uuid, p_locale text, p_title text, p_body_md text, p_translation_status text DEFAULT 'machine'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'api', 'pg_temp'
AS $function$
declare v_uid uuid := auth.uid();
begin
  if not exists (select 1 from public.network_staff ns where ns.user_id = v_uid and ns.is_active) then
    raise exception 'forbidden: network_staff only' using errcode = '42501';
  end if;
  if p_locale <> all (public.fn_supported_locales()) then
    raise exception 'locale invalide: %', p_locale using errcode = '22023';
  end if;
  insert into public.lettre_issue_locales (issue_id, locale, title, body_md, translation_status)
    values (p_issue_id, p_locale, coalesce(p_title,''), coalesce(p_body_md,''),
            coalesce(p_translation_status,'machine'))
  on conflict (issue_id, locale) do update
    set title = excluded.title, body_md = excluded.body_md,
        translation_status = excluded.translation_status;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_work_proposal_check(p_kind text, p_target_id bigint, p_merge_into_id bigint, p_payload jsonb)
 RETURNS void
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_part jsonb; v_n int; v_book bigint; v_w bigint; v_seen bigint[] := '{}';
begin
  if p_kind not in ('titre', 'fusion', 'rattachement', 'scission', 'tomes') then
    raise exception 'bad_kind_for_work' using hint = 'error.atelier.workKind';
  end if;
  if p_target_id is null or not exists (select 1 from public.works where id = p_target_id) then
    raise exception 'target_not_found' using hint = 'error.atelier.workNotFound';
  end if;

  if p_kind = 'titre' then
    if coalesce(p_payload ->> 'lang', '') <> all (public.fn_supported_locales()) then
      raise exception 'bad_lang' using hint = 'error.atelier.workLang';
    end if;
    if nullif(btrim(coalesce(p_payload ->> 'title', '')), '') is null then
      raise exception 'title_required' using hint = 'error.atelier.workTitle';
    end if;

  elsif p_kind = 'fusion' then
    if p_merge_into_id is null or p_merge_into_id = p_target_id then
      raise exception 'bad_merge_target' using hint = 'error.atelier.workMergeTarget';
    end if;
    if not exists (select 1 from public.works where id = p_merge_into_id) then
      raise exception 'canonical_not_found' using hint = 'error.atelier.workNotFound';
    end if;
    if exists (select 1 from public.work_not_same s
                where (s.work_id_a, s.work_id_b) in ((p_target_id, p_merge_into_id), (p_merge_into_id, p_target_id))) then
      raise exception 'works_declared_distinct' using hint = 'error.atelier.workNotSame';
    end if;

  elsif p_kind = 'rattachement' then
    v_book := (p_payload ->> 'book_id')::bigint;
    if v_book is null or not exists (select 1 from public.books where id = v_book) then
      raise exception 'book_not_found' using hint = 'error.atelier.workBook';
    end if;
    if (select work_id from public.books where id = v_book) = p_target_id then
      raise exception 'book_already_in_work' using hint = 'error.atelier.workBookSame';
    end if;

  elsif p_kind = 'scission' then
    if jsonb_typeof(p_payload -> 'parts') <> 'array' or jsonb_array_length(p_payload -> 'parts') < 2 then
      raise exception 'scission_needs_two_parts' using hint = 'error.atelier.scissionParts';
    end if;
    for v_part in select * from jsonb_array_elements(p_payload -> 'parts') loop
      if nullif(btrim(coalesce(v_part ->> 'uniform_title', '')), '') is null then
        raise exception 'scission_part_incomplete' using hint = 'error.atelier.scissionPartIncomplete';
      end if;
      if jsonb_typeof(v_part -> 'book_ids') <> 'array' or jsonb_array_length(v_part -> 'book_ids') < 1 then
        raise exception 'scission_part_no_books' using hint = 'error.atelier.workPartBooks';
      end if;
      for v_book in select (x #>> '{}')::bigint from jsonb_array_elements(v_part -> 'book_ids') x loop
        if not exists (select 1 from public.books b where b.id = v_book and b.work_id = p_target_id) then
          raise exception 'scission_book_not_in_work: %', v_book using hint = 'error.atelier.workPartBooks';
        end if;
        if v_book = any (v_seen) then
          raise exception 'scission_book_twice: %', v_book using hint = 'error.atelier.workPartBooks';
        end if;
        v_seen := v_seen || v_book;
      end loop;
    end loop;

  elsif p_kind = 'tomes' then
    if jsonb_typeof(p_payload -> 'work_ids') <> 'array' or jsonb_array_length(p_payload -> 'work_ids') < 1 then
      raise exception 'tomes_need_works' using hint = 'error.atelier.workTomes';
    end if;
    for v_w in select (x #>> '{}')::bigint from jsonb_array_elements(p_payload -> 'work_ids') x loop
      if v_w = p_target_id or not exists (select 1 from public.works where id = v_w) then
        raise exception 'tome_not_found: %', v_w using hint = 'error.atelier.workTomes';
      end if;
      if v_w = any (v_seen) then
        raise exception 'tome_twice: %', v_w using hint = 'error.atelier.workTomes';
      end if;
      v_seen := v_seen || v_w;
    end loop;
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION api.fn_work_title_validate(p_work_id bigint, p_lang text, p_title text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare v_title text;
begin
  if not public.fn_caller_is_staff() then
    raise exception 'forbidden' using hint = 'error.atelier.notStaff';
  end if;
  if coalesce(p_lang, '') <> all (public.fn_supported_locales()) then
    raise exception 'bad_lang' using hint = 'error.atelier.workLang';
  end if;
  v_title := nullif(btrim(coalesce(p_title, '')), '');
  if v_title is null then
    -- Valider tel quel : la pre-traduction devient un titre assume.
    update public.work_titles set source = 'manual', source_book_id = null, needs_review = false, updated_at = now()
     where work_id = p_work_id and lang = p_lang;
    if not found then raise exception 'title_not_found' using hint = 'error.atelier.workTitle'; end if;
  else
    insert into public.work_titles (work_id, lang, title, source, source_book_id, needs_review)
    values (p_work_id, p_lang, v_title, 'manual', null, false)
    on conflict (work_id, lang) do update
      set title = excluded.title, source = 'manual', source_book_id = null, needs_review = false, updated_at = now();
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_correspondance_langue(p_lang text, p_library_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v text;
BEGIN
  v := nullif(btrim(coalesce(p_lang, '')), '');
  IF v IS NULL THEN
    SELECT pr.preferred_language INTO v FROM public.profiles pr WHERE pr.id = (SELECT auth.uid());
  END IF;
  IF v IS NULL OR v = '' THEN
    SELECT l.default_locale INTO v FROM public.libraries l WHERE l.id = p_library_id;
  END IF;
  v := coalesce(nullif(v, ''), 'pt-BR');
  IF v <> ALL (public.fn_supported_locales()) THEN
    RAISE EXCEPTION 'lang_invalid: %', v USING errcode = '22023', hint = 'error.correspondance.lang_invalid';
  END IF;
  RETURN v;
END;
$function$;

CREATE OR REPLACE FUNCTION public.set_work_title(p_work_id bigint, p_lang text, p_title text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid() AND m.role = ANY(ARRAY['librarian','coordenador']) AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.works WHERE id = p_work_id) THEN
    RAISE EXCEPTION 'Obra inexistente.' USING ERRCODE = 'P0002', HINT = 'error.catalog.work.notFound';
  END IF;
  IF p_lang IS NULL OR p_lang <> ALL (public.fn_supported_locales()) THEN
    RAISE EXCEPTION 'Locale desconhecida.' USING ERRCODE = 'P0001', HINT = 'error.catalog.work.badLocale';
  END IF;
  IF NULLIF(btrim(COALESCE(p_title, '')), '') IS NULL THEN
    -- Effacer la saisie manuelle : le titre d'edition ou uniforme reprend.
    DELETE FROM public.work_titles WHERE work_id = p_work_id AND lang = p_lang;
    PERFORM public.fn_work_titles_reseed(p_work_id);
    RETURN;
  END IF;
  INSERT INTO public.work_titles (work_id, lang, title, source, source_book_id, needs_review)
  VALUES (p_work_id, p_lang, btrim(p_title), 'manual', NULL, false)
  ON CONFLICT (work_id, lang) DO UPDATE
     SET title = EXCLUDED.title, source = 'manual', source_book_id = NULL, needs_review = false, updated_at = now();
  UPDATE public.works SET updated_at = now() WHERE id = p_work_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_work_titles_pending(p_limit integer DEFAULT 5)
 RETURNS TABLE(work_id bigint, uniform_title text, author_name text, titles jsonb, editions jsonb, missing text[])
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  WITH locales AS (SELECT unnest(public.fn_supported_locales()) AS lang),
  cand AS (
    SELECT w.id, w.uniform_title, w.primary_author_id
      FROM public.works w
     WHERE (SELECT count(*) FROM public.books b WHERE b.work_id = w.id) >= 2
       AND EXISTS (SELECT 1 FROM public.work_titles t WHERE t.work_id = w.id)
       AND (SELECT count(*) FROM public.work_titles t WHERE t.work_id = w.id) < cardinality(public.fn_supported_locales())
       AND (w.titles_autofill_at IS NULL OR w.titles_autofill_at < now() - interval '1 day')
     ORDER BY w.titles_autofill_at NULLS FIRST, w.id
     LIMIT GREATEST(COALESCE(p_limit, 5), 1)
  )
  SELECT c.id, c.uniform_title, a.preferred_name,
         COALESCE((SELECT jsonb_object_agg(t.lang, jsonb_build_object('title', t.title, 'source', t.source))
                     FROM public.work_titles t WHERE t.work_id = c.id), '{}'::jsonb),
         COALESCE((SELECT jsonb_agg(jsonb_build_object('titulo', b.titulo, 'idioma', b.idioma, 'ano', b.ano, 'editora', b.editora)
                                     ORDER BY b.id)
                     FROM public.books b WHERE b.work_id = c.id), '[]'::jsonb),
         ARRAY(SELECT l.lang FROM locales l
                WHERE NOT EXISTS (SELECT 1 FROM public.work_titles t WHERE t.work_id = c.id AND t.lang = l.lang)
                ORDER BY l.lang)
    FROM cand c
    LEFT JOIN public.authors a ON a.id = c.primary_author_id;
$function$;

CREATE OR REPLACE FUNCTION public.fn_work_titles_autofill_apply(p_work_id bigint, p_titles jsonb, p_error text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE v_n integer := 0;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.works WHERE id = p_work_id) THEN RETURN 0; END IF;
  IF p_error IS NULL AND jsonb_typeof(COALESCE(p_titles, 'null'::jsonb)) = 'object' THEN
    INSERT INTO public.work_titles (work_id, lang, title, source, needs_review)
    SELECT p_work_id, kv.key, btrim(kv.value), 'auto', true
      FROM jsonb_each_text(p_titles) kv
     WHERE kv.key = ANY (public.fn_supported_locales())
       AND NULLIF(btrim(kv.value), '') IS NOT NULL
    ON CONFLICT (work_id, lang) DO NOTHING;   -- jamais par-dessus manual / edition
    GET DIAGNOSTICS v_n = ROW_COUNT;
  END IF;
  UPDATE public.works
     SET titles_autofill_at = now(), titles_autofill_error = LEFT(p_error, 500)
   WHERE id = p_work_id;
  RETURN v_n;
END;
$function$;

-- Le déclencheur est INVOKER : il appelle fn_supported_locales() avec les
-- droits de la coordination qui écrit (authenticated, GRANT ci-dessus).
CREATE OR REPLACE FUNCTION public.tg_libraries_read_languages_normaliser()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_canon constant text[] := public.fn_supported_locales();
BEGIN
  NEW.read_languages := COALESCE(ARRAY(
    SELECT x FROM (SELECT DISTINCT unnest(NEW.read_languages) AS x) d
    ORDER BY array_position(c_canon, x) NULLS LAST, x), '{}'::text[]);
  RETURN NEW;
END;
$function$;

-- ── Vérification ────────────────────────────────────────────────────
DO $$
DECLARE
  v_n int; v_diff text; v_reste text;
BEGIN
  -- La source : dix codes, fermée à anon, ouverte à qui écrit.
  IF cardinality(public.fn_supported_locales()) <> 10
     OR has_function_privilege('anon', 'public.fn_supported_locales()', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.fn_supported_locales()', 'EXECUTE')
     OR NOT has_function_privilege('service_role', 'public.fn_supported_locales()', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_supported_locales : liste ou droits inattendus';
  END IF;

  -- Les huit fonctions : propriétaire, SECURITY, search_path, volatilité et ACL inchangés.
  SELECT count(*) INTO v_n FROM _locales_fonctions_avant;
  IF v_n <> 8 THEN RAISE EXCEPTION 'attendu 8 fonctions, trouvé %', v_n; END IF;
  SELECT string_agg(a.sig, ', ') INTO v_diff
    FROM _locales_fonctions_avant a JOIN pg_proc p ON p.oid = a.oid
   WHERE (p.proowner, p.prosecdef, p.proconfig, p.proacl::text, p.provolatile)
         IS DISTINCT FROM (a.proowner, a.prosecdef, a.proconfig, a.acl, a.provolatile);
  IF v_diff IS NOT NULL THEN RAISE EXCEPTION 'attributs changés : %', v_diff; END IF;

  -- Plus aucune copie de la liste : ni dans les huit fonctions, ni dans les huit contraintes.
  SELECT string_agg(a.sig, ', ') INTO v_reste
    FROM _locales_fonctions_avant a JOIN pg_proc p ON p.oid = a.oid
   WHERE p.prosrc ~ '''eo''' OR p.prosrc !~ 'fn_supported_locales\(\)';
  IF v_reste IS NOT NULL THEN RAISE EXCEPTION 'liste encore recopiée : %', v_reste; END IF;
  SELECT string_agg(conname, ', ') INTO v_reste FROM pg_constraint
   WHERE contype = 'c' AND pg_get_constraintdef(oid) ~ '''(pt-BR|eo)''';
  IF v_reste IS NOT NULL THEN RAISE EXCEPTION 'contrainte encore recopiée : %', v_reste; END IF;
  SELECT count(*) INTO v_n FROM pg_constraint
   WHERE contype = 'c' AND pg_get_constraintdef(oid) ~ 'fn_supported_locales\(\)';
  IF v_n <> 8 THEN RAISE EXCEPTION 'attendu 8 contraintes sur fn_supported_locales, trouvé %', v_n; END IF;
END $$;

DROP TABLE _locales_fonctions_avant;
