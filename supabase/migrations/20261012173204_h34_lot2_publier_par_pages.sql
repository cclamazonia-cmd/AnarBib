-- =====================================================================
-- H34, lot 2 — un lot approuvé se publie par pages (IMP-36)
--
-- ── Le constat (lot 1, migration 20261012153013) ──
-- Une fois les deux défauts quadratiques corrigés, publier un lot reste
-- LINÉAIRE : ~15 ms par notice et ~3,4 ms par exemplaire au banc privé, au
-- calme (jusqu'à ~19 ms et ~4 ms sous une charge légère). 5 000 exemplaires
-- prennent 18,5 s, 500 notices à un exemplaire 7,8 s, un run de DIRA (plus de
-- 3 000 notices) 45 à 55 s : un appel de l'API est coupé à 8 s.
--
-- ── La décision (Xavier, 12/10/2026, REGISTRE IMP-36) ──
-- Un lot importé, révisé et approuvé une seule fois, se publie par pages
-- quand il dépasse ce qu'un appel tient.
--
-- ── Ce que fait cette migration ──
--   1. private.fn_h34_page_de_publication() : la borne d'une page — 60
--      notices ET 400 exemplaires. Mesuré au banc privé (fond de la production,
--      calme), première page : 60 notices et 360 exemplaires 3,2 s ; 57 et 399,
--      2,8 s ; 20 et 400, 1,8 s ; 60 et 60, 1,0 s — au plus la moitié du
--      plafond de 8 s, la marge x2 pour la charge d'une CI. (La borne de
--      100 notices et 500 exemplaires d'abord essayée donnait 4,4 s au pire :
--      trop près.) Une notice compte
--      avec ses exemplaires rattachés (book_draft_id) : ils vont dans la MÊME
--      page qu'elle, jamais séparés ; une notice seule plus grosse que la borne
--      fait sa page à elle seule.
--   2. public.publish_catalog_batch (définition vivante, par ancres) :
--      - un appel à la fois par lot : la ligne du lot est verrouillée sans
--        attendre (FOR UPDATE NOWAIT) ; un second appel concurrent est refusé
--        (55P03, HINT error.batch.publication_busy), il ne publie rien ;
--      - chaque appel publie au plus une page, dans l'ordre d'avant (notices et
--        leurs exemplaires, puis autorités, puis exemplaires sans notice du
--        lot : rapprochés, mises à jour 6b, retraits et levées du lot 7), en
--        une transaction : la page entière ou rien ;
--      - le recompte des fonds du lot 1 a lieu à la fin de chaque page ;
--      - tant qu'il reste une page, le lot passe à l'état « publishing »
--        (publication en cours) ; il n'est « published » qu'à la dernière ;
--      - la réponse garde ses trois comptes (ceux de la page) et ajoute
--        done, remaining (notices, autorités, exemplaires vivants du lot) et
--        page (comptes et bornes) ;
--      - un brouillon publié ne se republie pas, un brouillon restant n'est pas
--        sauté : chaque page reprend ce qui est encore « draft » ou « ready »,
--        et seule la publication pose « published » (IMP-27) ; une page
--        refusée n'écrit rien, les pages d'avant restent, un nouvel appel
--        reprend la page refusée.
--      Un lot qui tient en une page se publie exactement comme avant (mêmes
--      requêtes, même ordre, mêmes écritures ; le lot ne passe jamais par
--      « publishing »).
--   3. L'état « publishing » (CHECK catalog_batches_status_check élargie) :
--      - rien ne s'ajoute au lot et aucun brouillon du lot ne se retouche, ne
--        sort du lot ni ne se supprime par l'API, directement ou par une RPC
--        (déclencheur public.tg_h34_lot_en_publication sur book_drafts,
--        author_drafts, exemplar_drafts ; HINT error.batch.publishing_locked) —
--        seule la publication du lot elle-même écrit ses brouillons ; les
--        gestes sur le lot (cotes, classes, réattribution, nouvelle sélection
--        d'un run) le refusent déjà, il n'est plus « open » ;
--      - le lot ne quitte « publishing » que par la publication de sa dernière
--        page, ou par un nouveau tour de révision (fn_batch_review_request), qui
--        le rouvre (« open ») : les pages publiées le restent, la révision juge
--        de nouveau, la publication reprendra après l'approbation
--        (fn_batch_review_couvre reste la garde) ; aucun autre geste ne pose ni
--        ne lève « publishing » (déclencheur public.tg_h34_statut_publication
--        sur catalog_batches).
--
-- Définitions de départ (banc privé = dépôt après le lot 1, md5) :
--   public.publish_catalog_batch    8ce282c3375951aa01a79077ebf47985
--     (production au 12/10 16 h UTC : 52bfe412…, le lot 1 n'y était pas
--      encore appliqué ; la garde ci-dessous refuse tout autre texte)
--   public.fn_batch_review_request  9955d1fa0534e2ea59608db003b1d354 (production identique)
-- Suite : tests/sql/h34_publier_un_gros_lot_tests.sql (T12 à T19).
-- =====================================================================

CREATE OR REPLACE FUNCTION pg_temp.h34_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'H34 lot 2 — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN
    RAISE EXCEPTION 'H34 lot 2 — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

CREATE OR REPLACE FUNCTION pg_temp.h34_def(p_fn regprocedure, p_md5 text)
RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  IF md5(pg_get_functiondef(p_fn)) <> p_md5 THEN
    RAISE EXCEPTION 'H34 lot 2 — % n''est pas la définition attendue (md5 %, attendu %) — repartir de la définition réelle',
      p_fn, md5(pg_get_functiondef(p_fn)), p_md5;
  END IF;
  RETURN replace(pg_get_functiondef(p_fn), E'\r', '');
END
$f$;


-- ─────────────────────────────────────────────────────────────────────
-- 1. La borne d'une page
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION private.fn_h34_page_de_publication()
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
SET search_path TO 'pg_catalog'
AS $function$
  -- H34 lot 2 (12/10/2026, IMP-36) : ce qu'une page de publication d'un lot
  -- porte au plus. Au banc privé, au calme, une page pleine (60 notices et
  -- 360 à 400 exemplaires) prend au plus 3,2 s : la moitié du plafond de 8 s
  -- des appels de l'API (marge pour une CI chargée).
  SELECT '{"notices": 60, "exemplaires": 400}'::jsonb
$function$;
REVOKE ALL ON FUNCTION private.fn_h34_page_de_publication() FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION private.fn_h34_page_de_publication() IS
  'H34 lot 2 (IMP-36) : la borne d''une page de publish_catalog_batch — au plus 60 notices et 400 exemplaires (une notice '
  'et ses exemplaires rattachés ne se séparent jamais). Lue par publish_catalog_batch.';


-- ─────────────────────────────────────────────────────────────────────
-- 2. L'état « publishing » et ses deux gardes
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE public.catalog_batches DROP CONSTRAINT catalog_batches_status_check;
ALTER TABLE public.catalog_batches ADD CONSTRAINT catalog_batches_status_check
  CHECK (status = ANY (ARRAY['open'::text, 'publishing'::text, 'published'::text, 'closed'::text, 'cancelled'::text, 'archived'::text]));
COMMENT ON COLUMN public.catalog_batches.status IS
  'open | publishing | published | closed | cancelled | archived. « publishing » (H34 lot 2, IMP-36) : publication par pages en '
  'cours — rien ne s''y ajoute ni ne s''y retouche ; ne se pose et ne se lève que par publish_catalog_batch, ou par un nouveau '
  'tour de révision (fn_batch_review_request, qui rouvre le lot).';

-- Le lot ne passe par « publishing » que par la publication, et n'en sort que
-- par elle ou par un nouveau tour de révision : chacune pose, le temps de son
-- UPDATE, anarbib.h34_statut_lot = l'identifiant du lot.
CREATE OR REPLACE FUNCTION public.tg_h34_statut_publication()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF (TG_OP = 'INSERT' AND NEW.status = 'publishing')
     OR (TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status AND 'publishing' IN (OLD.status, NEW.status)) THEN
    IF coalesce(current_setting('anarbib.h34_statut_lot', true), '') IS DISTINCT FROM NEW.id::text THEN
      RAISE EXCEPTION 'Lote %: publicação em curso — só a publicação ou uma nova revisão mudam este estado.', NEW.id
        USING ERRCODE = 'P0001', HINT = 'error.batch.publishing_locked';
    END IF;
  END IF;
  RETURN NEW;
END
$function$;
REVOKE ALL ON FUNCTION public.tg_h34_statut_publication() FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION public.tg_h34_statut_publication() IS
  'H34 lot 2 (IMP-36) : l''état « publishing » d''un lot ne se pose et ne se lève que par publish_catalog_batch ou '
  'fn_batch_review_request (réglage local anarbib.h34_statut_lot). Déclencheur seulement.';
DROP TRIGGER IF EXISTS catalog_batches_h34_statut_publication ON public.catalog_batches;
CREATE TRIGGER catalog_batches_h34_statut_publication
  BEFORE INSERT OR UPDATE OF status ON public.catalog_batches
  FOR EACH ROW EXECUTE FUNCTION public.tg_h34_statut_publication();

-- Pendant « publishing », les brouillons du lot sont figés pour l'API (appel
-- direct ou par une RPC : jeton présent) ; seule la publication de CE lot
-- (anarbib.h34_publication_lot, posé par publish_catalog_batch) les écrit.
-- DEFINER : le statut du lot se lit sans la RLS de qui écrit.
CREATE OR REPLACE FUNCTION public.tg_h34_lot_en_publication()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_lots bigint[] := '{}';
  v_lot bigint;
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN v_lots := v_lots || OLD.batch_id; END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') THEN v_lots := v_lots || NEW.batch_id; END IF;
  v_lots := array_remove(v_lots, NULL);
  IF cardinality(v_lots) = 0 THEN
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
  END IF;
  SELECT b.id INTO v_lot
    FROM public.catalog_batches b
   WHERE b.id = ANY (v_lots) AND b.status = 'publishing'
     AND b.id::text IS DISTINCT FROM coalesce(current_setting('anarbib.h34_publication_lot', true), '')
   LIMIT 1;
  IF v_lot IS NOT NULL
     AND (auth.uid() IS NOT NULL OR coalesce(auth.role(), '') IN ('authenticated', 'anon')) THEN
    RAISE EXCEPTION 'Lote % em publicação: nada se acrescenta nem se retoca sem nova revisão.', v_lot
      USING ERRCODE = 'P0001', HINT = 'error.batch.publishing_locked';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END
$function$;
REVOKE ALL ON FUNCTION public.tg_h34_lot_en_publication() FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION public.tg_h34_lot_en_publication() IS
  'H34 lot 2 (IMP-36) : pendant la publication par pages d''un lot (« publishing »), aucun brouillon n''y entre, n''en sort, '
  'n''y est retouché ni supprimé par l''API (directement ou par une RPC) ; seule la publication de ce lot les écrit. '
  'Déclencheur seulement.';
DROP TRIGGER IF EXISTS book_drafts_aa_h34_lot_en_publication ON public.book_drafts;
CREATE TRIGGER book_drafts_aa_h34_lot_en_publication
  BEFORE INSERT OR UPDATE OR DELETE ON public.book_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_h34_lot_en_publication();
DROP TRIGGER IF EXISTS author_drafts_aa_h34_lot_en_publication ON public.author_drafts;
CREATE TRIGGER author_drafts_aa_h34_lot_en_publication
  BEFORE INSERT OR UPDATE OR DELETE ON public.author_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_h34_lot_en_publication();
DROP TRIGGER IF EXISTS exemplar_drafts_aa_h34_lot_en_publication ON public.exemplar_drafts;
CREATE TRIGGER exemplar_drafts_aa_h34_lot_en_publication
  BEFORE INSERT OR UPDATE OR DELETE ON public.exemplar_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_h34_lot_en_publication();


-- ─────────────────────────────────────────────────────────────────────
-- 3. publish_catalog_batch : une page par appel
-- ─────────────────────────────────────────────────────────────────────
DO $h34l2_lot$
DECLARE
  v_def text;
BEGIN
  v_def := pg_temp.h34_def('public.publish_catalog_batch(bigint)'::regprocedure, '8ce282c3375951aa01a79077ebf47985');
  -- (a) les compteurs de la page
  v_def := pg_temp.h34_remplacer('lot (déclarations)', v_def,
$a$  r record;
begin
$a$,
$b$  r record;
  -- H34 lot 2 (IMP-36) : la page de cet appel
  v_borne jsonb := private.fn_h34_page_de_publication();
  v_max_notices integer := (v_borne->>'notices')::integer;
  v_max_exemplaires integer := (v_borne->>'exemplaires')::integer;
  v_page_notices integer := 0;
  v_page_exemplaires integer := 0;
  v_unites integer := 0;
  v_k integer;
  v_plein boolean := false;
  v_statut text;
begin
$b$);
  -- (b) un appel à la fois par lot ; « publishing » reprend
  v_def := pg_temp.h34_remplacer('lot (état)', v_def,
$a$  if not exists (
    select 1
    from public.catalog_batches
    where id = p_batch_id
      and status = 'open'
  ) then
    raise exception 'Lote inválido ou já fechado: %', p_batch_id;
  end if;
$a$,
$b$  -- H34 lot 2 (IMP-36) : un appel à la fois par lot — la ligne du lot est
  -- verrouillée sans attendre ; un lot « publishing » (pages déjà publiées)
  -- reprend où il en était.
  begin
    select b.status into v_statut
      from public.catalog_batches b
     where b.id = p_batch_id
       for update nowait;
  exception when lock_not_available then
    raise exception 'Lote % já em publicação por outra chamada.', p_batch_id
      using errcode = '55P03', hint = 'error.batch.publication_busy';
  end;
  if v_statut is null or v_statut not in ('open', 'publishing') then
    raise exception 'Lote inválido ou já fechado: %', p_batch_id;
  end if;
$b$);
  -- (c) la publication de CE lot écrit ses brouillons (garde « publishing »)
  v_def := pg_temp.h34_remplacer('lot (réglages)', v_def,
$a$  perform set_config('anarbib.h34_disponibilite_differee', 'on', true);
$a$,
$b$  perform set_config('anarbib.h34_disponibilite_differee', 'on', true);
  perform set_config('anarbib.h34_publication_lot', p_batch_id::text, true);   -- H34 lot 2
$b$);
  -- (d) notices : avec leurs exemplaires rattachés, dans la même page
  v_def := pg_temp.h34_remplacer('lot (notices)', v_def,
$a$  loop
    perform public.publish_book_draft(r.id);
    v_books := v_books + 1;
  end loop;
$a$,
$b$  loop
    -- H34 lot 2 : la notice et ses exemplaires rattachés (publish_book_draft
    -- les publie avec elle) comptent ensemble ; la page pleine, on s'arrête.
    select count(*) into v_k
      from public.exemplar_drafts x
     where x.book_draft_id = r.id and x.status in ('draft', 'ready');
    if v_unites > 0 and (v_page_notices + 1 > v_max_notices
                         or v_page_exemplaires + v_k > v_max_exemplaires) then
      v_plein := true;
      exit;
    end if;
    perform public.publish_book_draft(r.id);
    v_books := v_books + 1;
    v_page_notices := v_page_notices + 1;
    v_page_exemplaires := v_page_exemplaires + v_k;
    v_unites := v_unites + 1;
  end loop;
$b$);
  -- (e) autorités
  v_def := pg_temp.h34_remplacer('lot (autorités)', v_def,
$a$  loop
    perform public.publish_author_draft(r.id);
    v_authors := v_authors + 1;
  end loop;
$a$,
$b$  loop
    exit when v_plein;   -- H34 lot 2 : page pleine
    if v_unites > 0 and v_page_notices + 1 > v_max_notices then
      v_plein := true;
      exit;
    end if;
    perform public.publish_author_draft(r.id);
    v_authors := v_authors + 1;
    v_page_notices := v_page_notices + 1;
    v_unites := v_unites + 1;
  end loop;
$b$);
  -- (f) exemplaires sans notice du lot (rapprochés, mises à jour, retraits)
  v_def := pg_temp.h34_remplacer('lot (exemplaires)', v_def,
$a$  loop
    perform public.publish_exemplar_draft(r.id);
    v_exemplars := v_exemplars + 1;
  end loop;
$a$,
$b$  loop
    exit when v_plein;   -- H34 lot 2 : page pleine
    if v_unites > 0 and v_page_exemplaires + 1 > v_max_exemplaires then
      v_plein := true;
      exit;
    end if;
    perform public.publish_exemplar_draft(r.id);
    v_exemplars := v_exemplars + 1;
    v_page_exemplaires := v_page_exemplaires + 1;
    v_unites := v_unites + 1;
  end loop;
$b$);
  -- (g) la fin de la page : « publishing » s'il reste une page, sinon « published »
  v_def := pg_temp.h34_remplacer('lot (fin)', v_def,
$a$  perform private.fn_h34_recompter_fonds_notes();   -- H34

  update public.catalog_batches
  set
    status = 'published',
    published_at = now(),
    updated_at = now(),
    published_by = auth.uid()
  where id = p_batch_id;

  return jsonb_build_object(
    'books_published', v_books,
    'authors_published', v_authors,
    'exemplars_published', v_exemplars
  );
$a$,
$b$  perform private.fn_h34_recompter_fonds_notes();   -- H34

  -- H34 lot 2 (IMP-36) : il reste une page — le lot est « publishing » ; sinon
  -- il est publié, comme avant.
  perform set_config('anarbib.h34_statut_lot', p_batch_id::text, true);
  if v_plein then
    update public.catalog_batches
       set status = 'publishing', updated_at = now()
     where id = p_batch_id and status <> 'publishing';
  else
  update public.catalog_batches
  set
    status = 'published',
    published_at = now(),
    updated_at = now(),
    published_by = auth.uid()
  where id = p_batch_id;
  end if;
  perform set_config('anarbib.h34_statut_lot', '', true);
  perform set_config('anarbib.h34_publication_lot', '', true);

  return jsonb_build_object(
    'books_published', v_books,
    'authors_published', v_authors,
    'exemplars_published', v_exemplars,
    -- H34 lot 2 : la page, et ce qui reste à publier
    'done', not v_plein,
    'remaining', jsonb_build_object(
      'books', (select count(*) from public.book_drafts d where d.batch_id = p_batch_id and d.status in ('draft', 'ready')),
      'authors', (select count(*) from public.author_drafts a where a.batch_id = p_batch_id and a.status in ('draft', 'ready')),
      'exemplars', (select count(*) from public.exemplar_drafts x where x.batch_id = p_batch_id and x.status in ('draft', 'ready'))),
    'page', jsonb_build_object('notices', v_page_notices, 'exemplaires', v_page_exemplaires,
                               'max_notices', v_max_notices, 'max_exemplaires', v_max_exemplaires)
  );
$b$);
  EXECUTE v_def;
END
$h34l2_lot$;


-- ─────────────────────────────────────────────────────────────────────
-- 4. fn_batch_review_request : un nouveau tour rouvre un lot « publishing »
-- ─────────────────────────────────────────────────────────────────────
DO $h34l2_revue$
DECLARE
  v_def text;
BEGIN
  v_def := pg_temp.h34_def('public.fn_batch_review_request(bigint, text)'::regprocedure, '9955d1fa0534e2ea59608db003b1d354');
  v_def := pg_temp.h34_remplacer('revue (état)', v_def,
$a$  if v_batch.status <> 'open' then$a$,
$b$  -- H34 lot 2 (IMP-36) : un lot en cours de publication se redemande aussi
  -- (nouveau tour : seule façon d'en retoucher un brouillon) ; il est rouvert
  -- plus bas.
  if v_batch.status not in ('open', 'publishing') then$b$);
  v_def := pg_temp.h34_remplacer('revue (réouverture)', v_def,
$a$  return jsonb_build_object('ok', true, 'review_id', v_id, 'round', v_round);$a$,
$b$  -- H34 lot 2 : le lot « publishing » redevient « open » ; ses pages publiées
  -- le restent, la publication reprendra après l'approbation.
  if v_batch.status = 'publishing' then
    perform set_config('anarbib.h34_statut_lot', p_batch_id::text, true);
    update public.catalog_batches set status = 'open', updated_at = now() where id = p_batch_id;
    perform set_config('anarbib.h34_statut_lot', '', true);
  end if;

  return jsonb_build_object('ok', true, 'review_id', v_id, 'round', v_round);$b$);
  EXECUTE v_def;
END
$h34l2_revue$;


-- ─────────────────────────────────────────────────────────────────────
-- 5. Vérification structurelle
-- ─────────────────────────────────────────────────────────────────────
DO $h34l2_verif$
DECLARE
  v_e text := '';
  v_f text;
  v_lot text := pg_get_functiondef('public.publish_catalog_batch(bigint)'::regprocedure);
  v_rev text := pg_get_functiondef('public.fn_batch_review_request(bigint, text)'::regprocedure);
BEGIN
  IF position('for update nowait' IN v_lot) = 0 OR position('error.batch.publication_busy' IN v_lot) = 0
     OR position('private.fn_h34_page_de_publication()' IN v_lot) = 0
     OR position('set status = ''publishing''' IN v_lot) = 0
     OR position('perform private.fn_h34_recompter_fonds_notes();' IN v_lot) = 0
     OR position('anarbib.h34_publication_lot' IN v_lot) = 0
     OR position('error.catalog.staff_only' IN v_lot) = 0 OR position('error.batch.other_libraries' IN v_lot) = 0
     OR position('error.batch.other_authors' IN v_lot) = 0
     OR (length(v_lot) - length(replace(v_lot, 'exit when v_plein;', ''))) / length('exit when v_plein;') <> 2 THEN
    v_e := v_e || ' lot';
  END IF;
  IF position('''open'', ''publishing''' IN v_rev) = 0 OR position('error.review.coordenador_only' IN v_rev) = 0
     OR position('error.review.already_approved' IN v_rev) = 0 THEN
    v_e := v_e || ' revue';
  END IF;
  IF pg_get_constraintdef((SELECT oid FROM pg_constraint WHERE conname = 'catalog_batches_status_check'
                            AND conrelid = 'public.catalog_batches'::regclass)) NOT LIKE '%publishing%' THEN
    v_e := v_e || ' check';
  END IF;
  IF (SELECT count(*) FROM pg_trigger WHERE tgname LIKE '%\_aa\_h34\_lot\_en\_publication' AND NOT tgisinternal) <> 3
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'catalog_batches_h34_statut_publication') THEN
    v_e := v_e || ' declencheurs';
  END IF;
  FOREACH v_f IN ARRAY ARRAY['public.publish_catalog_batch(bigint)', 'public.fn_batch_review_request(bigint, text)'] LOOP
    IF NOT has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT (SELECT p.prosecdef AND coalesce(p.proconfig::text, '') LIKE '%search_path%' FROM pg_proc p WHERE p.oid = v_f::regprocedure) THEN
      v_e := v_e || ' droits(' || v_f || ')';
    END IF;
  END LOOP;
  FOREACH v_f IN ARRAY ARRAY['private.fn_h34_page_de_publication()', 'public.tg_h34_statut_publication()', 'public.tg_h34_lot_en_publication()'] LOOP
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a WHERE p.oid = v_f::regprocedure AND a.grantee = 0)
       OR (SELECT coalesce(p.proconfig::text, '') NOT LIKE '%search_path%' FROM pg_proc p WHERE p.oid = v_f::regprocedure) THEN
      v_e := v_e || ' droits-aides(' || v_f || ')';
    END IF;
  END LOOP;
  IF v_e <> '' THEN
    RAISE EXCEPTION 'H34 lot 2 : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'H34 lot 2 : vérifications OK';
END
$h34l2_verif$;

NOTIFY pgrst, 'reload schema';
