-- =========================================================================
-- Paquet numerotation-et-rangement-d-une-bibliotheque — E21 : la serie de
-- numeros d'inventaire et la cote se reglent depuis l'ecran ; un lot recoit
-- ses cotes et ses classes de rangement en un geste
-- =========================================================================
-- Date     : 2026-09-15
-- Chantier : catalogage — ce qu'il faut a une bibliotheque pour publier
-- Auteur   : coordination AnarBib (demande Xavier du 15/09/2026, backlog E21)
--
-- POURQUOI
--   `libraries.tombo_pattern` (JSON {prefix, year, sep, pad}, lu par
--   fn_next_tombo a chaque exemplaire publie) et `bib_ref_prefix / _pad /
--   _auto` (la cote, suggeree par le formulaire de notice) n'avaient AUCUN
--   ecran ni RPC : BLMF, BTL et MLEG ont ete reglees en SQL a la main ;
--   `blmf-teste` et Solidaires n'ont rien. Une bibliotheque nee dans l'app ne
--   pouvait donc publier aucun exemplaire (tombo_pattern_not_configured), et
--   avant meme le tombo, publish_book_draft refuse tout brouillon sans cote :
--   les 1 673 brouillons Solidaires n'en ont aucune, et aucun outil ne
--   numerotait un lot en masse. Enfin, le numero d'inventaire ne range rien :
--   c'est la classe (champ `cdd`, texte libre, Dewey non impose) qui fait la
--   cote de rangement de l'etiquette de dos, et le lot Solidaires arrive avec
--   ses 35 rubriques dans la charge utile brute de l'import, sans classe.
--
-- CE QUE FAIT LE PAQUET (trois gestes, meme patron : une convention, un
-- apercu, une application, une trace)
--   1. fn_library_numbering_get / fn_library_numbering_set — la coordination
--      de la bibliotheque (ou l'administration du reseau) lit et regle la
--      serie de tombos et la cote. Gardes serveur : prefixe obligatoire, sans
--      '%' ni '_' (fn_next_tombo cherche par LIKE), UNIQUE dans le reseau —
--      exemplares.tombo est unique sur toute la base, deux bibliotheques au
--      meme prefixe se voleraient leurs numeros — et qui ne peut plus changer
--      (prefixe, annee, separateur) des qu'un exemplaire de la bibliotheque
--      l'a utilise ; le remplissage (pad) reste modifiable.
--   2. fn_batch_assign_bib_refs(lot, appliquer) — les brouillons en cours
--      d'un lot ouvert qui n'ont pas de cote en recoivent une, dans l'ordre du
--      lot, a la suite des cotes existantes de leur bibliotheque
--      proprietaire (notices publiees, holdings, brouillons vivants), selon
--      sa convention (bib_ref_auto). Apercu par defaut, application explicite.
--   3. fn_batch_rubrics(lot) / fn_batch_apply_rubric_classes(lot, table) —
--      la rubrique de chaque brouillon est lue la ou l'import l'a laissee
--      (fn_book_draft_rubric : sujets importes, `assunto_local` de la charge
--      utile brute, indice de classification locale, sujets lies, champ
--      texte) ; la coordination recoit la liste des rubriques distinctes avec
--      leurs effectifs, ecrit le code de rangement en face (35 lignes pour
--      Solidaires, pas 1 673) et l'application ecrit `cdd` sur les brouillons
--      qui n'en ont pas. L'etiquette de dos suit d'elle-meme.
--   Qui peut : fn_batch_caller_can_edit(lot) — administration du reseau, ou
--   staff de catalogage d'une bibliotheque proprietaire d'un brouillon du
--   lot, ou (lot sans proprietaire) coordination de catalogage.
--
-- CE QUE LE PAQUET NE FAIT PAS
--   * Il ne change ni fn_next_tombo, ni next_bib_ref, ni publish_book_draft.
--   * Il ne regle aucune bibliotheque et ne numerote aucun lot : ce sont des
--     gestes d'ecran (premier cas reel : Solidaires, apres choix du prefixe).
--   * Aucune table (rien a classer pour la sauvegarde).
--
-- CHECKLIST DOCTRINE
--   [x] DEFINER : search_path pose ; REVOKE PUBLIC/anon (+ authenticated pour
--       fn_book_draft_rubric, helper interne)
--   [x] aucune fonction ouverte a anon (garde T10 inchangee)
--   [x] DO block de verification en fin de transaction
--   [x] suite : tests/sql/numerotation_et_rangement_tests.sql
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1a. Lire la numerotation d'une bibliotheque (staff de la biblio ou admin)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_library_numbering_get(p_library_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_lib public.libraries%rowtype;
  v_next_tombo text;
  v_next_bib_ref text;
  v_last_tombo text;
  v_count bigint;
  v_frozen boolean := false;
BEGIN
  IF NOT (public.user_has_library_staff_role(auth.uid(), p_library_id) OR public.fn_caller_is_network_admin()) THEN
    RAISE EXCEPTION 'Numeracao reservada ao staff da biblioteca.' USING HINT = 'error.numbering.staff_only';
  END IF;
  SELECT * INTO v_lib FROM public.libraries WHERE id = p_library_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Biblioteca % introuvable', p_library_id USING HINT = 'error.numbering.library_not_found';
  END IF;

  SELECT count(*), max(e.tombo) INTO v_count, v_last_tombo
    FROM public.exemplares e WHERE e.library_id = p_library_id;

  -- Fige des qu'un exemplaire de la bibliotheque porte le prefixe courant.
  IF v_lib.tombo_pattern IS NOT NULL AND coalesce(v_lib.tombo_pattern->>'prefix', '') <> '' THEN
    v_frozen := EXISTS (
      SELECT 1 FROM public.exemplares e
       WHERE e.library_id = p_library_id
         AND e.tombo LIKE (v_lib.tombo_pattern->>'prefix') || '%'
    );
  END IF;

  BEGIN
    v_next_tombo := public.fn_next_tombo(p_library_id);
  EXCEPTION WHEN OTHERS THEN
    v_next_tombo := NULL;   -- pas de serie : c'est ce que l'ecran doit dire
  END;
  BEGIN
    v_next_bib_ref := public.next_bib_ref(p_library_id);
  EXCEPTION WHEN OTHERS THEN
    v_next_bib_ref := NULL;
  END;

  RETURN jsonb_build_object(
    'library_id', v_lib.id,
    'library_name', v_lib.name,
    'tombo_pattern', v_lib.tombo_pattern,
    'tombo_prefix', v_lib.tombo_pattern->>'prefix',
    'tombo_year', coalesce((v_lib.tombo_pattern->>'year')::boolean, false),
    'tombo_sep', coalesce(v_lib.tombo_pattern->>'sep', ''),
    'tombo_pad', coalesce((v_lib.tombo_pattern->>'pad')::int, 0),
    'bib_ref_prefix', coalesce(v_lib.bib_ref_prefix, ''),
    'bib_ref_pad', coalesce(v_lib.bib_ref_pad, 1),
    'bib_ref_auto', coalesce(v_lib.bib_ref_auto, false),
    'exemplars_count', v_count,
    'last_tombo', v_last_tombo,
    'tombo_frozen', v_frozen,
    'next_tombo', v_next_tombo,
    'next_bib_ref', v_next_bib_ref
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_library_numbering_get(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_library_numbering_get(uuid) TO authenticated, service_role;

-- -------------------------------------------------------------------------
-- 1b. Regler la numerotation (coordination de la biblio ou admin reseau)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_library_numbering_set(
  p_library_id uuid,
  p_tombo_prefix text,
  p_tombo_year boolean DEFAULT false,
  p_tombo_sep text DEFAULT '',
  p_tombo_pad integer DEFAULT 0,
  p_bib_ref_prefix text DEFAULT '',
  p_bib_ref_pad integer DEFAULT 5,
  p_bib_ref_auto boolean DEFAULT true
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_lib     public.libraries%rowtype;
  v_prefix  text := btrim(coalesce(p_tombo_prefix, ''));
  v_sep     text := coalesce(p_tombo_sep, '');
  v_pad     integer := coalesce(p_tombo_pad, 0);
  v_bprefix text := btrim(coalesce(p_bib_ref_prefix, ''));
  v_bpad    integer := coalesce(p_bib_ref_pad, 1);
  v_cur_prefix text;
  v_used    boolean;
BEGIN
  -- Regler la serie d'une bibliotheque engage son registre d'inventaire :
  -- la coordination de CETTE bibliotheque, ou l'administration du reseau.
  IF NOT (public.fn_caller_is_network_admin() OR EXISTS (
            SELECT 1 FROM public.user_library_memberships m
             WHERE m.user_id = auth.uid() AND m.library_id = p_library_id
               AND m.status = 'active' AND m.role = 'coordenador')) THEN
    RAISE EXCEPTION 'Numeracao reservada a coordenacao da biblioteca.' USING HINT = 'error.numbering.coord_only';
  END IF;

  SELECT * INTO v_lib FROM public.libraries WHERE id = p_library_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Biblioteca % introuvable', p_library_id USING HINT = 'error.numbering.library_not_found';
  END IF;

  IF v_prefix = '' THEN
    RAISE EXCEPTION 'Prefixo de tombo obrigatorio.' USING HINT = 'error.numbering.prefix_required';
  END IF;
  IF char_length(v_prefix) > 24 OR char_length(v_sep) > 3 THEN
    RAISE EXCEPTION 'Prefixo ou separador longo demais.' USING HINT = 'error.numbering.prefix_too_long';
  END IF;
  -- fn_next_tombo cherche les numeros par LIKE prefixe || '%' : les jokers
  -- SQL dans le prefixe compteraient les exemplaires des autres.
  IF v_prefix ~ '[%_]' OR v_sep ~ '[%_]' THEN
    RAISE EXCEPTION 'Prefixo com caracteres proibidos (%% ou _).' USING HINT = 'error.numbering.prefix_chars';
  END IF;
  IF v_pad < 0 OR v_pad > 8 OR v_bpad < 1 OR v_bpad > 10 THEN
    RAISE EXCEPTION 'Preenchimento fora dos limites.' USING HINT = 'error.numbering.pad_range';
  END IF;

  -- Unique dans le reseau : ni le meme prefixe, ni un prefixe qui en contient
  -- un autre (« SOL » et « SOL- » se liraient l'un l'autre), ni un prefixe
  -- deja porte par des exemplaires d'une autre bibliotheque (series heritees).
  IF EXISTS (
       SELECT 1 FROM public.libraries l2
        WHERE l2.id <> p_library_id
          AND coalesce(l2.tombo_pattern->>'prefix', '') <> ''
          AND (lower(l2.tombo_pattern->>'prefix') LIKE lower(v_prefix) || '%'
               OR lower(v_prefix) LIKE lower(l2.tombo_pattern->>'prefix') || '%'))
     OR EXISTS (
       SELECT 1 FROM public.exemplares e
        WHERE e.library_id <> p_library_id AND lower(e.tombo) LIKE lower(v_prefix) || '%') THEN
    RAISE EXCEPTION 'Prefixo % ja usado por outra biblioteca.', v_prefix USING HINT = 'error.numbering.prefix_taken';
  END IF;
  IF v_bprefix <> '' AND EXISTS (
       SELECT 1 FROM public.libraries l2
        WHERE l2.id <> p_library_id AND lower(coalesce(l2.bib_ref_prefix, '')) = lower(v_bprefix)) THEN
    RAISE EXCEPTION 'Prefixo de cota % ja usado por outra biblioteca.', v_bprefix USING HINT = 'error.numbering.bibref_prefix_taken';
  END IF;

  -- Fige des qu'un exemplaire l'a utilise : prefixe, annee et separateur ne
  -- changent plus (le remplissage, si : fn_next_tombo lit les chiffres).
  v_cur_prefix := v_lib.tombo_pattern->>'prefix';
  IF v_cur_prefix IS NOT NULL AND v_cur_prefix <> '' THEN
    v_used := EXISTS (SELECT 1 FROM public.exemplares e
                       WHERE e.library_id = p_library_id AND e.tombo LIKE v_cur_prefix || '%');
    IF v_used AND (lower(v_cur_prefix) <> lower(v_prefix)
                   OR coalesce((v_lib.tombo_pattern->>'year')::boolean, false) IS DISTINCT FROM coalesce(p_tombo_year, false)
                   OR coalesce(v_lib.tombo_pattern->>'sep', '') <> v_sep) THEN
      RAISE EXCEPTION 'Serie de tombos ja usada : prefixo, ano e separador nao mudam mais.' USING HINT = 'error.numbering.frozen';
    END IF;
  END IF;

  UPDATE public.libraries
     SET tombo_pattern  = jsonb_build_object('prefix', v_prefix, 'year', coalesce(p_tombo_year, false), 'sep', v_sep, 'pad', v_pad),
         bib_ref_prefix = v_bprefix,
         bib_ref_pad    = v_bpad,
         bib_ref_auto   = coalesce(p_bib_ref_auto, true),
         updated_at     = now()
   WHERE id = p_library_id;

  RETURN public.fn_library_numbering_get(p_library_id);
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_library_numbering_set(uuid, text, boolean, text, integer, text, integer, boolean) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_library_numbering_set(uuid, text, boolean, text, integer, text, integer, boolean) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_library_numbering_set(uuid, text, boolean, text, integer, text, integer, boolean) IS
  'Coordination de la biblio ou admin reseau : regle libraries.tombo_pattern {prefix, year, sep, pad} et la cote '
  '(bib_ref_prefix/pad/auto). Prefixe obligatoire, sans %% ni _, unique dans le reseau (y compris series heritees '
  'des exemplaires), fige (prefixe/annee/separateur) des qu''un exemplaire l''a utilise. Paquet E21, 15/09/2026.';

-- -------------------------------------------------------------------------
-- 2a. Qui peut agir sur un lot : admin reseau, staff d'une biblio
--     proprietaire d'un brouillon en cours du lot, ou (lot sans proprietaire)
--     coordination de catalogage
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_batch_caller_can_edit(p_batch_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select public.fn_caller_is_network_admin()
      or exists (
           select 1
             from public.book_drafts d
             join public.user_library_memberships m on m.library_id = d.owner_library_id
            where d.batch_id = p_batch_id and d.status in ('draft', 'ready')
              and m.user_id = auth.uid() and m.status = 'active'
              and m.role in ('librarian', 'coordenador'))
      or (not exists (select 1 from public.book_drafts d
                       where d.batch_id = p_batch_id and d.status in ('draft', 'ready')
                         and d.owner_library_id is not null)
          and public.fn_is_catalog_coordinator());
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_batch_caller_can_edit(bigint) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_batch_caller_can_edit(bigint) TO authenticated, service_role;

-- -------------------------------------------------------------------------
-- 2b. Les cotes manquantes d'un lot, dans l'ordre du lot
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_batch_assign_bib_refs(p_batch_id bigint, p_apply boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_batch  public.catalog_batches%rowtype;
  v_lib    public.libraries%rowtype;
  v_owners integer;
  v_owner  uuid;
  v_prefix text;
  v_pad    integer;
  v_re     text;
  v_max    bigint;
  v_n      bigint;
  v_updated integer := 0;
  v_who    text;
BEGIN
  SELECT * INTO v_batch FROM public.catalog_batches WHERE id = p_batch_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lote % introuvable', p_batch_id USING HINT = 'error.bibref.batch.not_found';
  END IF;
  IF NOT public.fn_batch_caller_can_edit(p_batch_id) THEN
    RAISE EXCEPTION 'Cotas do lote reservadas ao staff da biblioteca proprietaria.' USING HINT = 'error.bibref.batch.staff_only';
  END IF;
  IF v_batch.status <> 'open' THEN
    RAISE EXCEPTION 'Lote % nao esta aberto', p_batch_id USING HINT = 'error.bibref.batch.not_open';
  END IF;

  -- Les brouillons sans cote doivent appartenir a UNE bibliotheque : la cote
  -- suit sa convention et sa serie.
  SELECT count(DISTINCT d.owner_library_id), min(d.owner_library_id::text)::uuid, count(*)
    INTO v_owners, v_owner, v_n
    FROM public.book_drafts d
   WHERE d.batch_id = p_batch_id AND d.status IN ('draft', 'ready')
     AND nullif(btrim(coalesce(d.bib_ref, '')), '') IS NULL;
  IF v_n = 0 THEN
    RETURN jsonb_build_object('ok', true, 'batch_id', p_batch_id, 'candidates', 0, 'applied', false, 'updated', 0);
  END IF;
  IF v_owners > 1 THEN
    RAISE EXCEPTION 'Lote % com brouillons de varias bibliotecas', p_batch_id USING HINT = 'error.bibref.batch.mixed_owner';
  END IF;
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'Lote % sem biblioteca proprietaria', p_batch_id USING HINT = 'error.bibref.batch.no_owner';
  END IF;

  SELECT * INTO v_lib FROM public.libraries WHERE id = v_owner;
  IF NOT coalesce(v_lib.bib_ref_auto, false) THEN
    RAISE EXCEPTION 'Biblioteca % sem convencao de cota', v_lib.name USING HINT = 'error.bibref.batch.no_convention';
  END IF;
  v_prefix := coalesce(v_lib.bib_ref_prefix, '');
  v_pad    := greatest(coalesce(v_lib.bib_ref_pad, 1), 1);
  v_re     := '^' || regexp_replace(v_prefix, '([.^$|()\[\]{}*+?\\])', '\\\1', 'g') || '([0-9]{' || v_pad || ',})$';

  -- Serialise par prefixe : deux lots de la meme biblio numerotes en meme
  -- temps ne se marchent pas dessus.
  PERFORM pg_advisory_xact_lock(hashtext('bibref:' || v_prefix));

  -- Le max sous ce prefixe, partout ou une cote vit : notices publiees,
  -- holdings (cote locale), brouillons vivants (le geste rejoue se poursuit).
  SELECT max((substring(ref FROM v_re))::bigint) INTO v_max
    FROM (
      SELECT b.bib_ref AS ref FROM public.books b
      UNION ALL
      SELECT h.local_bib_ref FROM public.book_holdings h WHERE h.library_id = v_owner
      UNION ALL
      SELECT d.bib_ref FROM public.book_drafts d WHERE d.status <> 'cancelled'
    ) x
   WHERE ref ~ v_re;
  v_max := coalesce(v_max, 0);

  IF p_apply THEN
    UPDATE public.book_drafts d
       SET bib_ref = v_prefix || lpad((v_max + s.rn)::text, v_pad, '0'),
           updated_at = now()
      FROM (SELECT d2.id, row_number() OVER (ORDER BY d2.id) AS rn
              FROM public.book_drafts d2
             WHERE d2.batch_id = p_batch_id AND d2.status IN ('draft', 'ready')
               AND nullif(btrim(coalesce(d2.bib_ref, '')), '') IS NULL) s
     WHERE d.id = s.id;
    GET DIAGNOSTICS v_updated = ROW_COUNT;

    SELECT coalesce(nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), ''), auth.uid()::text)
      INTO v_who FROM public.profiles p WHERE p.id = auth.uid();
    UPDATE public.catalog_batches
       SET notes = concat_ws(E'\n', nullif(notes, ''),
             format('[%s] %s cota(s) atribuida(s) por %s : %s a %s (biblioteca « %s »).',
                    to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI UTC'), v_updated, coalesce(v_who, '?'),
                    v_prefix || lpad((v_max + 1)::text, v_pad, '0'),
                    v_prefix || lpad((v_max + v_updated)::text, v_pad, '0'), v_lib.name)),
           updated_at = now()
     WHERE id = p_batch_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'batch_id', p_batch_id,
    'library_id', v_owner,
    'library_name', v_lib.name,
    'prefix', v_prefix,
    'pad', v_pad,
    'candidates', v_n,
    'first', v_prefix || lpad((v_max + 1)::text, v_pad, '0'),
    'last',  v_prefix || lpad((v_max + v_n)::text, v_pad, '0'),
    'applied', p_apply,
    'updated', v_updated
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_batch_assign_bib_refs(bigint, boolean) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_batch_assign_bib_refs(bigint, boolean) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_batch_assign_bib_refs(bigint, boolean) IS
  'Staff de la biblio proprietaire ou admin : les brouillons en cours d''un lot OUVERT sans cote en recoivent une '
  'dans l''ordre du lot, a la suite des cotes existantes (books, holdings, brouillons vivants) selon bib_ref_prefix/'
  'pad de la biblio (bib_ref_auto requis). p_apply=false : apercu seulement. Trace dans catalog_batches.notes. E21.';

-- -------------------------------------------------------------------------
-- 3a. La rubrique d'un brouillon, la ou l'import l'a laissee
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_book_draft_rubric(p_draft_id bigint)
 RETURNS text
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select nullif(btrim(coalesce(
           -- 1. sujets normalises par l'import
           d.marc_json->'ingest'->'subjects'->>0,
           -- 2. la charge utile brute : rubrique locale de la source (Solidaires : assunto_local)
           d.marc_json->'ingest'->'raw_payload'->>'assunto_local',
           d.marc_json->'ingest'->'raw_payload'->>'assuntos',
           d.marc_json->'ingest'->'raw_payload'->>'assunto',
           d.marc_json->'ingest'->'raw_payload'->>'subjects',
           d.marc_json->'ingest'->'raw_payload'->>'subject',
           d.marc_json->'ingest'->'raw_payload'->>'rubrique',
           d.marc_json->'ingest'->'raw_payload'->>'rubrica',
           -- 3. l'indice de classification locale derive par l'import
           d.marc_json->'ingest'->>'derived_local_classification_hint',
           -- 4. le premier sujet lie
           (select coalesce(s.label_i18n->>'pt-BR', s.label_i18n->>'fr', s.label_i18n->>'en', s.label_i18n->>'es', s.slug)
              from public.book_draft_subjects bds join public.subjects s on s.id = bds.subject_id
             where bds.book_draft_id = d.id order by bds.ord nulls last, s.id limit 1),
           -- 5. le champ texte herite
           split_part(coalesce(d.subjects, ''), ';', 1)
         )), '')
    from public.book_drafts d
   where d.id = p_draft_id;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_book_draft_rubric(bigint) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.fn_book_draft_rubric(bigint) TO service_role;

-- -------------------------------------------------------------------------
-- 3b. Les rubriques distinctes d'un lot, avec leurs effectifs
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_batch_rubrics(p_batch_id bigint)
 RETURNS TABLE(rubric text, drafts bigint, without_class bigint)
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.catalog_batches WHERE id = p_batch_id) THEN
    RAISE EXCEPTION 'Lote % introuvable', p_batch_id USING HINT = 'error.rubrics.batch.not_found';
  END IF;
  IF NOT public.fn_batch_caller_can_edit(p_batch_id) THEN
    RAISE EXCEPTION 'Rubricas do lote reservadas ao staff da biblioteca proprietaria.' USING HINT = 'error.rubrics.batch.staff_only';
  END IF;
  RETURN QUERY
  SELECT q.rubric, count(*)::bigint, count(*) FILTER (WHERE q.sans_classe)::bigint
    FROM (SELECT public.fn_book_draft_rubric(d.id) AS rubric,
                 nullif(btrim(coalesce(d.cdd, '')), '') IS NULL AS sans_classe
            FROM public.book_drafts d
           WHERE d.batch_id = p_batch_id AND d.status IN ('draft', 'ready')) q
   GROUP BY q.rubric
   ORDER BY count(*) DESC, q.rubric NULLS LAST;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_batch_rubrics(bigint) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_batch_rubrics(bigint) TO authenticated, service_role;

-- -------------------------------------------------------------------------
-- 3c. Ecrire les classes de rangement selon la table rubrique -> code
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_batch_apply_rubric_classes(p_batch_id bigint, p_map jsonb, p_overwrite boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_batch   public.catalog_batches%rowtype;
  r         record;
  v_code    text;
  v_updated integer := 0;
  v_unmapped integer := 0;
  v_kept    integer := 0;
  v_codes   text[] := ARRAY[]::text[];
  v_who     text;
BEGIN
  SELECT * INTO v_batch FROM public.catalog_batches WHERE id = p_batch_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lote % introuvable', p_batch_id USING HINT = 'error.rubrics.batch.not_found';
  END IF;
  IF NOT public.fn_batch_caller_can_edit(p_batch_id) THEN
    RAISE EXCEPTION 'Rubricas do lote reservadas ao staff da biblioteca proprietaria.' USING HINT = 'error.rubrics.batch.staff_only';
  END IF;
  IF v_batch.status <> 'open' THEN
    RAISE EXCEPTION 'Lote % nao esta aberto', p_batch_id USING HINT = 'error.rubrics.batch.not_open';
  END IF;
  IF p_map IS NULL OR jsonb_typeof(p_map) <> 'object' THEN
    RAISE EXCEPTION 'Tabela rubrica -> classe invalida' USING HINT = 'error.rubrics.batch.bad_map';
  END IF;

  FOR r IN
    SELECT d.id, d.cdd, public.fn_book_draft_rubric(d.id) AS rubric
      FROM public.book_drafts d
     WHERE d.batch_id = p_batch_id AND d.status IN ('draft', 'ready')
     ORDER BY d.id
  LOOP
    v_code := CASE WHEN r.rubric IS NULL THEN NULL ELSE nullif(btrim(coalesce(p_map->>r.rubric, '')), '') END;
    IF v_code IS NULL THEN
      v_unmapped := v_unmapped + 1;
    ELSIF nullif(btrim(coalesce(r.cdd, '')), '') IS NOT NULL AND NOT coalesce(p_overwrite, false) THEN
      v_kept := v_kept + 1;
    ELSE
      UPDATE public.book_drafts SET cdd = v_code, updated_at = now() WHERE id = r.id;
      v_updated := v_updated + 1;
      IF NOT (v_code = ANY (v_codes)) THEN v_codes := array_append(v_codes, v_code); END IF;
    END IF;
  END LOOP;

  IF v_updated > 0 THEN
    SELECT coalesce(nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), ''), auth.uid()::text)
      INTO v_who FROM public.profiles p WHERE p.id = auth.uid();
    UPDATE public.catalog_batches
       SET notes = concat_ws(E'\n', nullif(notes, ''),
             format('[%s] Classe de arrumacao escrita em %s rascunho(s) por %s (%s codigo(s) : %s).',
                    to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI UTC'), v_updated, coalesce(v_who, '?'),
                    coalesce(array_length(v_codes, 1), 0), left(array_to_string(v_codes, ', '), 300))),
           updated_at = now()
     WHERE id = p_batch_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'batch_id', p_batch_id,
    'updated', v_updated, 'skipped_unmapped', v_unmapped, 'skipped_has_class', v_kept,
    'codes', to_jsonb(v_codes)
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_batch_apply_rubric_classes(bigint, jsonb, boolean) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_batch_apply_rubric_classes(bigint, jsonb, boolean) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_batch_apply_rubric_classes(bigint, jsonb, boolean) IS
  'Staff de la biblio proprietaire ou admin : pour chaque brouillon en cours d''un lot OUVERT, la rubrique '
  '(fn_book_draft_rubric) est cherchee dans p_map {rubrique: code} et le code ecrit dans cdd — sauf classe deja '
  'presente (p_overwrite=false). Trace dans catalog_batches.notes. E21, 15/09/2026.';

-- -------------------------------------------------------------------------
-- Verification en fin de transaction
-- -------------------------------------------------------------------------
DO $verif$
BEGIN
  IF has_function_privilege('anon', 'public.fn_library_numbering_get(uuid)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_library_numbering_set(uuid, text, boolean, text, integer, text, integer, boolean)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_batch_caller_can_edit(bigint)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_batch_assign_bib_refs(bigint, boolean)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_book_draft_rubric(bigint)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_book_draft_rubric(bigint)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_batch_rubrics(bigint)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_batch_apply_rubric_classes(bigint, jsonb, boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'une fonction du paquet E21 est ouverte a anon (ou le helper a authenticated)';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.fn_library_numbering_set(uuid, text, boolean, text, integer, text, integer, boolean)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.fn_batch_assign_bib_refs(bigint, boolean)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.fn_batch_apply_rubric_classes(bigint, jsonb, boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'une fonction d''ecran du paquet E21 n''est pas executable par authenticated';
  END IF;
  RAISE NOTICE 'paquet E21 numerotation-et-rangement : verifications OK';
END;
$verif$;

COMMIT;
