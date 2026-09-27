-- =====================================================================
-- B30 — un lot de catalogage a une bibliothèque (suite de B29)
-- Date : 2026-09-27 · Backlog v34 B30 · REGISTRE CAT-E18 (décisions de Xavier)
--
-- Constat : B29 déduisait « à qui est un lot » de ses brouillons (en cours,
-- publiés, jetés, réattribués, importés) ; quatre vérifications ont trouvé à
-- chaque fois de nouveaux cas limites. Un lot porte désormais sa bibliothèque.
--
--   1. catalog_batches.library_id (NULL : lot de l'administration du réseau),
--      clé étrangère RESTRICT, indexée ;
--   2. reprise des lots existants : la bibliothèque commune de leurs
--      brouillons en cours et publiés, sinon celle du créateur (hors compte
--      d'administration), sinon aucune ;
--   3. prédicats de lot ramenés à la colonne (mêmes noms : l'écran et les
--      tests les appellent) : voir, modifier, rapport, révisions, ranger =
--      staff de la bibliothèque du lot ; supprimer, demander la révision =
--      sa coordination ; l'administration : tout ;
--   4. la bibliothèque se pose à la création (l'écran la choisit ; à défaut
--      celle de staff principale), figée par l'API ; seule la réattribution
--      (administration) la change — elle remplace « confier » un lot ;
--   5. un brouillon ne se range que dans un lot de SA bibliothèque ;
--   6. listes (lots, révisions avec la bibliothèque), rapport, numérotation,
--      rubriques, reprises, rejeu, imports : même règle.
--
-- Corps des fonctions existantes extraits de la production (md5) et modifiés
-- par ancrages (script du 27/09), jamais retapés — sauf les prédicats et
-- listes propres à B29, réécrits en entier.
-- =====================================================================

-- ── 1. La colonne ──────────────────────────────────────────────────────────
-- RESTRICT : supprimer une bibliothèque qui a des lots doit être un refus dit,
-- pas un transfert silencieux des lots à l'administration (SET NULL).
ALTER TABLE public.catalog_batches
  ADD COLUMN IF NOT EXISTS library_id uuid
  CONSTRAINT catalog_batches_library_id_fkey REFERENCES public.libraries(id) ON DELETE RESTRICT;
CREATE INDEX IF NOT EXISTS idx_catalog_batches_library_id ON public.catalog_batches (library_id);
COMMENT ON COLUMN public.catalog_batches.library_id IS
  'B30 (CAT-E18) : la bibliothèque du lot — qui le voit, le modifie, le révise, le supprime, et quels brouillons s''y rangent. NULL : lot de l''administration du réseau. Posée à la création, figée par l''API ; seule fn_batch_reassign_library la change.';

-- ── 2. Reprise des lots existants ──────────────────────────────────────────
-- La bibliothèque d'un lot existant, déduite de ses brouillons (notices ;
-- exemplaires saisis ; un exemplaire importé suit sa notice ; bibliothèques
-- inconnues ignorées) : celle, unique, de ses brouillons EN COURS — un lot
-- réattribué après une publication partielle (IMP-20 c : les fiches publiées
-- restent à l'ancienne bibliothèque) est à la nouvelle ; sans brouillon en
-- cours, celle, unique, de ses fiches publiées ; sans aucun brouillon, celle de
-- son créateur s'il n'est pas un compte d'administration ; sinon (plusieurs
-- bibliothèques, ou inconnue) : aucune — l'administration. Une fonction
-- nommée : la suite SQL l'éprouve sur des lots de toutes les formes.
CREATE OR REPLACE FUNCTION public.fn_b30_lot_bibliotheque_initiale(p_batch_id bigint)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  with br as (
    select coalesce(d.owner_library_id, public.fn_book_draft_creator_library(d.id, d.created_by)) as lib,
           d.status in ('draft', 'ready') as en_cours
      from public.book_drafts d
     where d.batch_id = p_batch_id and d.status in ('draft', 'ready', 'published')
    union all
    select coalesce(x.target_library_id,
                    public.fn_exemplar_draft_fallback_library(x.book_draft_id, x.import_staging_row_id, x.created_by)),
           x.status in ('draft', 'ready')
      from public.exemplar_drafts x
     where x.batch_id = p_batch_id and x.book_draft_id is null and x.status in ('draft', 'ready', 'published')
  ), k as (
    select count(distinct lib) filter (where en_cours and lib is not null) as n_cours,
           min(lib::text) filter (where en_cours and lib is not null)     as lib_cours,
           count(*) filter (where en_cours)                               as nb_cours,
           count(distinct lib) filter (where lib is not null)             as n_tous,
           min(lib::text) filter (where lib is not null)                  as lib_tous,
           count(*)                                                       as nb_tous
      from br
  )
  select case
           when k.n_cours = 1 then k.lib_cours::uuid
           when k.nb_cours = 0 and k.n_tous = 1 then k.lib_tous::uuid
           -- le créateur : seulement pour un lot SANS aucun brouillon (une fiche
           -- de bibliothèque inconnue, même publiée, laisse le lot à l'administration)
           when k.nb_tous = 0
                and not exists (select 1 from public.catalog_batches b
                                  join public.network_administrators na on na.user_id = b.created_by and na.status = 'active'
                                 where b.id = p_batch_id)
             then (select public.fn_user_staff_library(b.created_by) from public.catalog_batches b where b.id = p_batch_id)
         end
    from k;
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_b30_lot_bibliotheque_initiale(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_b30_lot_bibliotheque_initiale(bigint) TO service_role;

-- updated_at n'est pas touché : la reprise n'est pas un geste sur le lot.
ALTER TABLE public.catalog_batches DISABLE TRIGGER trg_catalog_batches_touch_updated_at;
UPDATE public.catalog_batches b
   SET library_id = public.fn_b30_lot_bibliotheque_initiale(b.id)
 WHERE b.library_id IS NULL;
ALTER TABLE public.catalog_batches ENABLE TRIGGER trg_catalog_batches_touch_updated_at;

DO $reprise$
DECLARE v text;
BEGIN
  SELECT string_agg(b.id || ' → ' || coalesce(l.slug, 'administration'), ', ' ORDER BY b.id) INTO v
    FROM public.catalog_batches b LEFT JOIN public.libraries l ON l.id = b.library_id;
  RAISE NOTICE 'B30, bibliothèque des lots : %', coalesce(v, '(aucun lot)');
END
$reprise$;

-- ── 3. Les prédicats de lot, ramenés à la colonne ─────────────────────────
-- Mêmes noms et signatures qu'en B29 : l'écran les appelle en RPC, la
-- politique des tours de révision nomme fn_caller_owns_batch (garde CI T3).

-- Voir, modifier, lire le rapport et les tours de révision, y ranger :
-- l'administration, ou le staff de la bibliothèque du lot.
CREATE OR REPLACE FUNCTION public.fn_caller_can_see_batch(p_batch_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select public.fn_caller_is_network_admin()
      or exists (select 1 from public.catalog_batches b
                  where b.id = p_batch_id
                    and b.library_id = any (public.fn_caller_staff_library_ids()));
$function$;

CREATE OR REPLACE FUNCTION public.fn_caller_owns_batch(p_batch_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- B30 : le lot a une bibliothèque ; « le posséder », c'est en être le staff.
  select public.fn_caller_can_see_batch(p_batch_id);
$function$;

-- Agir sur TOUT le lot (le publier) : p_all_kinds ajoute les autorités, qui
-- n'ont pas de bibliothèque et ne s'écrivent que par qui les a créées (CAT-E18 2).
CREATE OR REPLACE FUNCTION public.fn_caller_can_edit_batch(p_batch_id bigint, p_all_kinds boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select public.fn_caller_can_see_batch(p_batch_id)
     and ( not p_all_kinds
           or public.fn_caller_is_network_admin()
           or not exists (select 1 from public.author_drafts a
                           where a.batch_id = p_batch_id and a.status in ('draft', 'ready')
                             and a.created_by is distinct from (select auth.uid())) );
$function$;

-- Supprimer le lot, en demander la révision : la coordination DE sa
-- bibliothèque (ou l'administration).
CREATE OR REPLACE FUNCTION public.fn_caller_coordinates_batch(p_batch_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select public.fn_caller_is_network_admin()
      or exists (select 1 from public.catalog_batches b
                  where b.id = p_batch_id
                    and b.library_id = any (public.fn_caller_coordinator_library_ids()));
$function$;

-- Numéroter, classer, lire les rubriques : le staff de la bibliothèque du lot.
CREATE OR REPLACE FUNCTION public.fn_batch_caller_can_edit(p_batch_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  -- B30 (CAT-E18, 27/09/2026) : le lot a une bibliothèque ; y agir revient à
  -- son staff, ou à l'administration du réseau. (B29 le déduisait de tous ses
  -- brouillons vivants ; avant, le staff d'UN brouillon suffisait.)
  select public.fn_caller_can_see_batch(p_batch_id);
$function$;

-- La bibliothèque d'un lot, pour qui peut la connaître (le déclencheur de
-- rangement tourne sous le rôle de qui écrit : il ne lit pas la table
-- directement) : NULL pour un lot d'autrui ou de l'administration.
-- VOLATILE et FOR KEY SHARE : on attend une réattribution en cours (FOR UPDATE
-- du lot) et on juge sur la bibliothèque qu'elle vient de poser — sans
-- verrou, on lirait l'ancienne et un brouillon qu'elle n'a pas vu entrerait.
-- Pour un brouillon qui ENTRE dans le lot (INSERT, changement de lot), le
-- contrôle de clé étrangère prenait déjà ce verrou, plus tard : rien de neuf.
CREATE OR REPLACE FUNCTION public.fn_caller_batch_library(p_batch_id bigint)
 RETURNS uuid
 LANGUAGE sql
 VOLATILE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select b.library_id from public.catalog_batches b
   where b.id = p_batch_id
     and ( public.fn_caller_is_network_admin()
           or b.library_id = any (public.fn_caller_staff_library_ids()) )
     for key share of b;
$function$;

-- La même, SANS attendre : pour rejuger un brouillon qui RESTE dans son lot
-- (sortie de corbeille, changement de bibliothèque), la ligne du brouillon est
-- déjà verrouillée — attendre le lot croiserait la réattribution, qui tient le
-- lot puis met à jour les brouillons (interblocage). Un lot en cours de
-- réattribution (ou de suppression) rend NULL : le brouillon sort du lot.
CREATE OR REPLACE FUNCTION public.fn_caller_batch_library_sans_attente(p_batch_id bigint)
 RETURNS uuid
 LANGUAGE sql
 VOLATILE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select b.library_id from public.catalog_batches b
   where b.id = p_batch_id
     and ( public.fn_caller_is_network_admin()
           or b.library_id = any (public.fn_caller_staff_library_ids()) )
     for key share of b skip locked;
$function$;

-- Un brouillon de la bibliothèque p_library peut-il se ranger dans ce lot ?
-- (Fonctions DEFINER : reprises, rejeu du journal.) Lu sous verrou, comme le
-- déclencheur : une réattribution en cours est attendue.
CREATE OR REPLACE FUNCTION public.fn_caller_can_range_in_batch(p_batch_id bigint, p_library uuid)
 RETURNS boolean
 LANGUAGE sql
 VOLATILE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select public.fn_caller_is_network_admin()
      or coalesce(public.fn_caller_batch_library(p_batch_id) = p_library, false);
$function$;

DO $droits$
BEGIN
  REVOKE EXECUTE ON FUNCTION public.fn_caller_batch_library(bigint) FROM PUBLIC, anon;
  GRANT EXECUTE ON FUNCTION public.fn_caller_batch_library(bigint) TO authenticated, service_role;
  REVOKE EXECUTE ON FUNCTION public.fn_caller_batch_library_sans_attente(bigint) FROM PUBLIC, anon;
  GRANT EXECUTE ON FUNCTION public.fn_caller_batch_library_sans_attente(bigint) TO authenticated, service_role;
  REVOKE EXECUTE ON FUNCTION public.fn_caller_can_range_in_batch(bigint, uuid) FROM PUBLIC, anon, authenticated;
  GRANT EXECUTE ON FUNCTION public.fn_caller_can_range_in_batch(bigint, uuid) TO service_role;
END
$droits$;

-- ── 4. La bibliothèque d'un lot se fixe à sa création ─────────────────────
-- Par l'API : posée à l'INSERT (celle de staff principale de qui crée, si
-- l'écran n'en choisit pas — l'administration peut créer un lot sans
-- bibliothèque), figée ensuite pour TOUS, administration comprise : seule
-- fn_batch_reassign_library (DEFINER) la change, avec ce qui va avec
-- (brouillons en cours, exemplaires saisis d'ailleurs, source, trace).
CREATE OR REPLACE FUNCTION public.tg_catalog_batches_library_fixed()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.library_id IS NULL AND NOT public.fn_caller_is_network_admin() THEN
      NEW.library_id := public.fn_caller_staff_library();
    END IF;
  ELSE
    NEW.library_id := OLD.library_id;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.tg_catalog_batches_library_fixed() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS catalog_batches_library_fixed ON public.catalog_batches;
CREATE TRIGGER catalog_batches_library_fixed
  BEFORE INSERT OR UPDATE OF library_id ON public.catalog_batches
  FOR EACH ROW EXECUTE FUNCTION public.tg_catalog_batches_library_fixed();

-- created_by : l'exception « l'administration CONFIE un lot » (B29) n'a plus
-- d'objet — confier un lot, c'est changer sa bibliothèque.
CREATE OR REPLACE FUNCTION public.tg_drafts_created_by_frozen()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.created_by := auth.uid();
  ELSE
    NEW.created_by := OLD.created_by;
  END IF;
  RETURN NEW;
END;
$function$;

-- ── 5. Ranger un brouillon : dans un lot de SA bibliothèque ───────────────
-- Par l'API, hors administration : une notice (owner_library_id), un
-- exemplaire saisi (target_library_id, sinon celle de son créateur) ne se
-- rangent que dans un lot de leur bibliothèque où l'on est staff ; une
-- autorité (sans bibliothèque), dans un lot où l'on est staff ; un exemplaire
-- importé suit sa notice. Le déclencheur passe EN DERNIER (« zz ») : il juge
-- la ligne finale, bibliothèque posée (tg_drafts_library_fixed), créateur
-- figé, lot ramené à celui de la notice (tg_exemplar_drafts_import_links_locked).
-- Refus : à la création, une erreur dite ; un rangement refusé (geste de
-- masse par paquets de 200) laisse le brouillon dans son ancien lot, sans
-- faire échouer le paquet ; une sortie de corbeille, ou un changement de
-- bibliothèque d'un brouillon rangé, le sort du lot.
CREATE OR REPLACE FUNCTION public.tg_drafts_batch_guarded()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_lot    uuid;
  v_ok     boolean;
  v_rejuge boolean := false;
  v_meme_lot boolean := false;
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF NEW.batch_id IS NULL OR public.fn_caller_is_network_admin() THEN
    RETURN NEW;
  END IF;
  IF TG_TABLE_NAME = 'exemplar_drafts' THEN
    IF NEW.book_draft_id IS NOT NULL THEN RETURN NEW; END IF;
  END IF;
  IF TG_OP = 'UPDATE' THEN
    -- Un nouveau jugement : une sortie de corbeille, ou un changement de
    -- bibliothèque — comparée RÉSOLUE avant et après (celle que
    -- tg_drafts_library_fixed vient de matérialiser n'est pas un changement).
    v_rejuge := OLD.status = 'cancelled' AND NEW.status IS DISTINCT FROM 'cancelled';
    IF NOT v_rejuge AND TG_TABLE_NAME = 'book_drafts' THEN
      v_rejuge := coalesce(NEW.owner_library_id, public.fn_book_draft_creator_library(NEW.id, NEW.created_by))
                  IS DISTINCT FROM
                  coalesce(OLD.owner_library_id, public.fn_book_draft_creator_library(OLD.id, OLD.created_by));
    ELSIF NOT v_rejuge AND TG_TABLE_NAME = 'exemplar_drafts' THEN
      v_rejuge := coalesce(NEW.target_library_id,
                           public.fn_exemplar_draft_fallback_library(NULL, NEW.import_staging_row_id, NEW.created_by))
                  IS DISTINCT FROM
                  coalesce(OLD.target_library_id,
                           public.fn_exemplar_draft_fallback_library(NULL, OLD.import_staging_row_id, OLD.created_by));
    END IF;
    IF NEW.batch_id IS NOT DISTINCT FROM OLD.batch_id AND NOT v_rejuge THEN
      RETURN NEW;
    END IF;
    v_meme_lot := NEW.batch_id IS NOT DISTINCT FROM OLD.batch_id;
  END IF;

  -- NULL : lot d'autrui ou de l'administration (ou, pour un brouillon qui reste
  -- dans son lot, lot en cours de réattribution : il en sort).
  IF v_meme_lot THEN
    v_lot := public.fn_caller_batch_library_sans_attente(NEW.batch_id);
  ELSE
    v_lot := public.fn_caller_batch_library(NEW.batch_id);
  END IF;
  IF v_lot IS NULL THEN
    v_ok := false;
  ELSIF TG_TABLE_NAME = 'author_drafts' THEN
    v_ok := true;
  ELSIF TG_TABLE_NAME = 'book_drafts' THEN
    -- bibliothèque RÉSOLUE (une notice d'avant B29 sans owner : celle de son créateur)
    v_ok := coalesce(NEW.owner_library_id, public.fn_book_draft_creator_library(NEW.id, NEW.created_by))
            IS NOT DISTINCT FROM v_lot;
  ELSE
    v_ok := coalesce(NEW.target_library_id,
                     public.fn_exemplar_draft_fallback_library(NULL, NEW.import_staging_row_id, NEW.created_by))
            IS NOT DISTINCT FROM v_lot;
  END IF;
  IF v_ok THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    RAISE EXCEPTION 'Rascunho de outra biblioteca do que a do lote.'
      USING ERRCODE = '42501', HINT = 'error.batch.library_mismatch';
  END IF;
  -- Refus en UPDATE : un rangement SEUL refusé laisse le brouillon dans son
  -- ancien lot (qui l'accueillait : rien d'autre n'a changé) ; avec une sortie
  -- de corbeille ou un changement de bibliothèque, il sort du lot — l'ancien
  -- ne l'accueillerait plus forcément.
  IF NEW.batch_id IS DISTINCT FROM OLD.batch_id AND NOT v_rejuge THEN
    NEW.batch_id := OLD.batch_id;
  ELSE
    NEW.batch_id := NULL;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.tg_drafts_batch_guarded() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS book_drafts_batch_guarded ON public.book_drafts;
DROP TRIGGER IF EXISTS exemplar_drafts_batch_guarded ON public.exemplar_drafts;
DROP TRIGGER IF EXISTS author_drafts_batch_guarded ON public.author_drafts;
DROP TRIGGER IF EXISTS book_drafts_zz_batch_guarded ON public.book_drafts;
CREATE TRIGGER book_drafts_zz_batch_guarded
  BEFORE INSERT OR UPDATE OF batch_id, status, owner_library_id ON public.book_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_drafts_batch_guarded();
DROP TRIGGER IF EXISTS exemplar_drafts_zz_batch_guarded ON public.exemplar_drafts;
CREATE TRIGGER exemplar_drafts_zz_batch_guarded
  BEFORE INSERT OR UPDATE OF batch_id, status, target_library_id ON public.exemplar_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_drafts_batch_guarded();
DROP TRIGGER IF EXISTS author_drafts_zz_batch_guarded ON public.author_drafts;
CREATE TRIGGER author_drafts_zz_batch_guarded
  BEFORE INSERT OR UPDATE OF batch_id, status ON public.author_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_drafts_batch_guarded();
-- Une notice sortie de son lot par le garde (UPDATE qui ne nomme que
-- owner_library_id) : ses exemplaires importés la suivent aussi.
DROP TRIGGER IF EXISTS book_drafts_imported_items_follow ON public.book_drafts;
CREATE TRIGGER book_drafts_imported_items_follow
  AFTER UPDATE OF status, batch_id, owner_library_id ON public.book_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_book_drafts_imported_items_follow();

-- ── 6. Les listes de lots ─────────────────────────────────────────────────
-- Les bibliothèques des brouillons EN COURS des lots qu'on voit : l'écran y
-- lit un lot devenu mixte (brouillons d'une autre bibliothèque que la sienne).
CREATE OR REPLACE FUNCTION public.fn_batch_owner_libraries()
 RETURNS TABLE(batch_id bigint, library_id uuid, library_name text, drafts bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  -- B30 (CAT-E18, 27/09/2026) : les lots qu'on voit — ceux de ses
  -- bibliothèques (l'administration : tous).
  with moi as materialized (
    select public.fn_caller_is_network_admin() as admin,
           public.fn_caller_staff_library_ids() as libs
  )
  select d.batch_id, d.owner_library_id, l.name, count(*)
    from moi
    join public.catalog_batches b on b.status <> 'archived'
                                 and (moi.admin or b.library_id = any (moi.libs))
    join public.book_drafts d on d.batch_id = b.id and d.status in ('draft', 'ready')
    left join public.libraries l on l.id = d.owner_library_id
   group by d.batch_id, d.owner_library_id, l.name
   order by d.batch_id, l.name nulls first;
$function$;

-- Les lots et leur dernier tour de révision ; la bibliothèque du lot en plus
-- (les colonnes changent : DROP puis CREATE, droits réaffirmés).
DROP FUNCTION IF EXISTS public.fn_batch_reviews_list();
CREATE FUNCTION public.fn_batch_reviews_list()
 RETURNS TABLE(batch_id bigint, batch_name text, batch_status text, imported boolean, review_id bigint, round integer, status text, requested_by uuid, requester_name text, requested_at timestamp with time zone, coord_message text, reviewed_by uuid, reviewer_name text, reviewed_at timestamp with time zone, admin_notes text, report jsonb, report_generated_at timestamp with time zone, drafts_active bigint, batch_library_id uuid, batch_library_name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest'
AS $function$
  -- B30 (CAT-E18, 27/09/2026) : les lots de ses bibliothèques (l'administration :
  -- tous) ; leur rapport aussi, sous la même règle.
  with moi as materialized (
    select public.fn_caller_is_network_admin() as admin,
           public.fn_caller_staff_library_ids() as libs
  )
  select b.id, b.name, b.status,
         public.fn_batch_is_imported(b.id),
         r.id, r.round, r.status,
         r.requested_by,
         nullif(btrim(concat_ws(' ', pq.first_name, pq.last_name)), ''),
         r.requested_at, r.coord_message,
         r.reviewed_by,
         nullif(btrim(concat_ws(' ', pv.first_name, pv.last_name)), ''),
         r.reviewed_at, r.admin_notes,
         r.report, r.report_generated_at,
         (select count(*) from public.book_drafts d where d.batch_id = b.id and d.status in ('draft', 'ready')),
         b.library_id, coalesce(lb.short_name, lb.name)
    from moi
    join public.catalog_batches b on b.status <> 'archived'
                                 and (moi.admin or b.library_id = any (moi.libs))
    left join public.libraries lb on lb.id = b.library_id
    left join lateral (
      select * from public.catalog_batch_reviews x
       where x.batch_id = b.id order by x.round desc limit 1
    ) r on true
    left join public.profiles pq on pq.id = r.requested_by
    left join public.profiles pv on pv.id = r.reviewed_by
   order by (r.status = 'requested') desc nulls last, r.requested_at desc nulls last, b.created_at desc;
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_batch_reviews_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_batch_reviews_list() TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_batch_reviews_list() IS
  'Un enregistrement par lot non archive avec son DERNIER tour de revision (null si jamais demande) ; '
  'lots de ses bibliotheques (staff), tous pour l''administration du reseau ; '
  'batch_library_id / batch_library_name = bibliotheque du lot (NULL = administration du reseau). B30, 27/09/2026.';

-- ── 7. Le rapport ne dit que ce que la bibliothèque du lot voit ───────────
-- Les brouillons vivants d'un lot, pour son rapport de révision : hors
-- administration, ceux de la bibliothèque du lot — un brouillon d'ailleurs
-- (rangé là par l'administration) reste invisible à qui ne le lit pas dans
-- book_drafts. (Définition de production du 05/09 + ce filtre.)
CREATE OR REPLACE FUNCTION public.fn_batch_live_drafts(p_batch_id bigint)
 RETURNS SETOF book_drafts
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select d.* from public.book_drafts d
   where d.batch_id = p_batch_id and d.status in ('draft', 'ready')
     -- B30 (CAT-E18, 27/09/2026)
     and (public.fn_caller_is_network_admin()
          or coalesce(d.owner_library_id, public.fn_book_draft_creator_library(d.id, d.created_by))
             is not distinct from (select b.library_id from public.catalog_batches b where b.id = p_batch_id));
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_batch_live_drafts(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_batch_live_drafts(bigint) TO service_role;

-- ── 8. Supprimer un lot : ce qui l'empêche, compté sur TOUT le lot ────────
-- L'écran vérifie avant de vider la corbeille ; la vue des comptes est
-- invoker (on n'y voit que ses brouillons) quand le garde de suppression
-- compte tout. Un lot réattribué qui porte des fiches publiées d'une autre
-- bibliothèque (IMP-20 c) : le savoir AVANT d'avoir vidé sa corbeille.
CREATE OR REPLACE FUNCTION public.fn_batch_delete_blockers(p_batch_id bigint)
 RETURNS TABLE(en_cours bigint, publies bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select coalesce(c.en_cours, 0)::bigint, coalesce(c.publies, 0)::bigint
    from public.v_catalog_batch_draft_counts c
   where c.batch_id = p_batch_id
     and public.fn_caller_coordinates_batch(p_batch_id);
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_batch_delete_blockers(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_batch_delete_blockers(bigint) TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_batch_delete_blockers(bigint) IS
  'Comptes en_cours / publies de TOUT le lot (ceux du garde de suppression), pour la coordination '
  'de la bibliotheque du lot ou l''administration ; aucune ligne sinon. B30, 27/09/2026.';

-- ── 7. Les fonctions SECURITY DEFINER qui touchent un lot ────────────────
CREATE OR REPLACE FUNCTION public.publish_catalog_batch(p_batch_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_books integer := 0;
  v_authors integer := 0;
  v_exemplars integer := 0;
  r record;
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
  -- B30 (CAT-E18) : le lot a une bibliothèque ; on ne publie que les lots de
  -- ses bibliothèques (l'administration : tous) — refus AVANT tout autre
  -- contrôle, lot inexistant compris (pas d'oracle d'existence ni de statut).
  if not public.fn_caller_can_see_batch(p_batch_id) then
    raise exception 'Lote de outra biblioteca.' using hint = 'error.batch.other_libraries';
  end if;
  if not exists (
    select 1
    from public.catalog_batches
    where id = p_batch_id
      and status = 'open'
  ) then
    raise exception 'Lote inválido ou já fechado: %', p_batch_id;
  end if;
  -- Publier le lot, c'est publier TOUS ses brouillons : les autorités d'une
  -- autre personne (sans bibliothèque, CAT-E18 2) l'empêchent. Les gardes par
  -- brouillon de publish_*_draft restent le filet d'un lot hérité mixte.
  if not public.fn_caller_can_edit_batch(p_batch_id, true) then
    raise exception 'Lote com autoridades de outras pessoas.' using hint = 'error.batch.other_authors';
  end if;

  for r in
    select id
    from public.book_drafts
    where batch_id = p_batch_id
      and status in ('draft','ready')
  loop
    perform public.publish_book_draft(r.id);
    v_books := v_books + 1;
  end loop;

  for r in
    select id
    from public.author_drafts
    where batch_id = p_batch_id
      and status in ('draft','ready')
  loop
    perform public.publish_author_draft(r.id);
    v_authors := v_authors + 1;
  end loop;

  for r in
    select id
    from public.exemplar_drafts
    where batch_id = p_batch_id
      and status in ('draft','ready')
      -- H19 : un exemplaire importé se publie AVEC sa notice (publish_book_draft) ;
      -- ceux d'une notice écartée restent en brouillon, ils ne font pas échouer le lot.
      and book_draft_id is null
  loop
    perform public.publish_exemplar_draft(r.id);
    v_exemplars := v_exemplars + 1;
  end loop;

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
end;
$function$;

CREATE OR REPLACE FUNCTION public.publish_book_draft(p_draft_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_draft public.book_drafts%rowtype;
  v_book_id bigint;
  v_isbn_norm text;
  v_existing_book_id bigint;
  v_holding_id bigint;
  v_library_id uuid;
  v_circ_policy text;
  v_auto_tombo text;                         -- #tombo-serie (17/06)
  v_copies int;                              -- #copies (17/08) : nb d'exemplaires initiaux
  v_i int;
  v_linked int := 0;                         -- H19 : exemplaires importés rattachés
  v_x record;
  v_valid_types text[] := ARRAY[
    'livro','periodico','tract','cartaz','audio','audiovisual',
    'recurso_digital','dossie','tese','artigo','relatorio','zine'
  ];
begin
  -- B30 : le staff de catalogage ACTIF, ou l'administration du réseau — les
  -- lots sans bibliothèque ne sont qu'à elle ; la garde #79 ne demandait pas
  -- d'adhésion active et fermait la porte à l'administration sans adhésion.
  IF NOT (public.fn_caller_is_network_admin()
          OR EXISTS (SELECT 1 FROM public.user_library_memberships m
                      WHERE m.user_id = auth.uid() AND m.status = 'active'
                        AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text]))) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.' USING HINT = 'error.catalog.staff_only';
  END IF;
  select * into v_draft from public.book_drafts where id = p_draft_id;
  if not found then
    raise exception 'rascunho_nao_encontrado' using hint = 'error.publish.draft_not_found';
  end if;
  -- B29 (CAT-E18) : on ne publie que les brouillons de ses bibliothèques
  -- (celle du brouillon, sinon celle de son créateur), ou comme administration.
  -- Avant tout autre contrôle : aucun ne renseigne sur le brouillon d'autrui.
  if not coalesce(public.fn_caller_can_edit_book_draft(p_draft_id), false) then
    raise exception 'Ce rascunho est rattache a une bibliotheque dont vous n''etes pas membre.' using hint = 'error.publish.other_library';
  end if;
  if v_draft.status = 'cancelled' then
    raise exception 'rascunho_descartado' using hint = 'error.publish.draft_cancelled';
  end if;

  -- 05/09/2026 : un lot ne d'un import ne se publie qu'apres une revision
  -- approuvee par l'administration du reseau (catalog_batch_reviews).
  -- publish_catalog_batch passe ici pour chaque brouillon : la garde le couvre.
  if v_draft.batch_id is not null
     and public.fn_batch_is_imported(v_draft.batch_id)
     and public.fn_batch_review_status(v_draft.batch_id) is distinct from 'approved' then
    raise exception 'lote_importado_sem_revisao' using hint = 'error.publish.review_required';
  end if;

  if v_draft.titulo is null or btrim(v_draft.titulo) = '' then
    raise exception 'titulo_obrigatorio' using hint = 'error.publish.titulo_required';
  end if;
  if v_draft.bib_ref is null or btrim(v_draft.bib_ref) = '' then
    raise exception 'bib_ref_obrigatoria' using hint = 'error.publish.bib_ref_required';
  end if;
  if v_draft.tipo_material is null or btrim(v_draft.tipo_material) = '' then
    raise exception 'tipo_material_obrigatorio' using hint = 'error.publish.tipo_material_required';
  end if;
  if lower(v_draft.tipo_material) <> ALL(v_valid_types) then
    raise exception 'tipo_material_invalido' using hint = 'error.publish.tipo_material_invalid';
  end if;

  select b.id into v_existing_book_id
    from public.books b
   where b.bib_ref = v_draft.bib_ref
     and (v_draft.published_book_id is null or b.id <> v_draft.published_book_id)
   limit 1;
  if v_existing_book_id is not null then
    raise exception 'bib_ref_duplicado: %', v_existing_book_id
      using errcode = 'P0001',
            hint = format('Ja existe uma ficha publicada com a mesma referencia bibliografica %s (ficha %s). Altere a bib_ref ou verifique a ficha existente.', v_draft.bib_ref, v_existing_book_id);
  end if;
  v_existing_book_id := null;

  if v_draft.published_book_id is null then
    v_isbn_norm := regexp_replace(upper(coalesce(v_draft.isbn, '')), '[^0-9X]', '', 'g');
    if v_isbn_norm <> '' then
      select b.id into v_existing_book_id
        from public.books b
       where regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g') = v_isbn_norm
         -- Volumes (27/09/2026) : l'ISBN d'un ensemble est porté par chacun de
         -- ses volumes (BTL-TL-000447 et BTL-TL-000448 : volumes 2 et 3 de « La
         -- C.N.T. y la Revolución Española », même ISBN). Deux notices qui portent
         -- des numéros de volume DIFFÉRENTS ne sont pas des doublons : refuser la
         -- seconde poussait, par le message ci-dessous, à enregistrer le volume 4
         -- comme un exemplaire du volume 2. Même volume, ou volume absent d'un
         -- côté : doublon, comme avant.
         and not (nullif(btrim(coalesce(v_draft.volume, '')), '') is not null
                  and nullif(btrim(coalesce(b.volume, '')), '') is not null
                  and lower(btrim(b.volume)) <> lower(btrim(v_draft.volume)))
       limit 1;
      if v_existing_book_id is not null then
        raise exception 'isbn_duplicado: %', v_existing_book_id
          using errcode = 'P0001',
                hint = format('Ja existe uma ficha publicada com o mesmo ISBN (ficha %s). Revise o ISBN ou adicione um exemplar a ficha existente.', v_existing_book_id);
      end if;
    end if;

    insert into public.books (
      work_id,
      cdd, autor, titulo, ano, editora, bib_ref, loanable,
      subtitulo, edicao, local_publicacao, isbn, issn, idioma, paginas,
      notas, tipo_material, cover_object_path, cover_source, cover_license, marc_json, catalog_source,
      created_by, updated_by, updated_at, last_cataloged_at,
      serial_id,                             -- #périodiques P7 (27/08)
      titulo_periodico, volume, numero, fasciculo, data_edicao,
      periodicidade, colecao, acquisition_mode, acquisition_date,
      owner_library, holder_library, partner_source, source_record_id,
      source_record_url, import_format, import_method, provenance_note,
      mutualization_status, source_label,
      tract_campaign, emitter_org, approximate_date, diffusion_place,
      recto_verso, physical_format, print_technique, physical_state,
      audio_duration, audio_support, audio_format, audio_language,
      audio_participants, audio_recording_type,
      audiovisual_duration, audiovisual_support, audiovisual_language,
      audiovisual_director, audiovisual_participants, audiovisual_subtitles,
      audiovisual_access_note,
      digital_native_url, digital_native_access, digital_native_restriction,
      digital_native_usage, digital_native_file_note,
      dossier_scope, dossier_period, dossier_organizations, dossier_context,
      distribuidora, gravadora, tese_university, tese_advisor,
      artigo_source, artigo_volume, artigo_issue, artigo_pages,
      relatorio_org, relatorio_recipient, relatorio_internal_notes,
      zine_print_run, zine_technique, zine_format,
      subjects
    )
    values (
      v_draft.work_id,                       -- #œuvre (17/08) : NULL -> fn_books_ensure_work crée une œuvre neuve
      v_draft.cdd, v_draft.autor, v_draft.titulo, v_draft.ano,
      v_draft.editora, v_draft.bib_ref, coalesce(v_draft.loanable, true),
      v_draft.subtitulo, v_draft.edicao, v_draft.local_publicacao,
      v_draft.isbn, v_draft.issn, v_draft.idioma, v_draft.paginas,
      v_draft.notas, v_draft.tipo_material, v_draft.cover_object_path,
      v_draft.cover_source, v_draft.cover_license,  -- capas (27/09) : provenance et licence de l'image
      coalesce(v_draft.marc_json, '{}'::jsonb), 'catalogacao',
      coalesce(v_draft.created_by, auth.uid()),
      coalesce(v_draft.updated_by, auth.uid()), now(), now(),
      v_draft.serial_id,                     -- #périodiques P7 (27/08)
      v_draft.titulo_periodico, v_draft.volume, v_draft.numero,
      v_draft.fasciculo, v_draft.data_edicao, v_draft.periodicidade,
      v_draft.colecao, v_draft.acquisition_mode, v_draft.acquisition_date,
      v_draft.owner_library, v_draft.holder_library, v_draft.partner_source,
      v_draft.source_record_id, v_draft.source_record_url,
      v_draft.import_format, v_draft.import_method, v_draft.provenance_note,
      v_draft.mutualization_status, v_draft.source_label,
      v_draft.tract_campaign, v_draft.emitter_org, v_draft.approximate_date,
      v_draft.diffusion_place, v_draft.recto_verso, v_draft.physical_format,
      v_draft.print_technique, v_draft.physical_state,
      v_draft.audio_duration, v_draft.audio_support, v_draft.audio_format,
      v_draft.audio_language, v_draft.audio_participants,
      v_draft.audio_recording_type,
      v_draft.audiovisual_duration, v_draft.audiovisual_support,
      v_draft.audiovisual_language, v_draft.audiovisual_director,
      v_draft.audiovisual_participants, v_draft.audiovisual_subtitles,
      v_draft.audiovisual_access_note,
      v_draft.digital_native_url, v_draft.digital_native_access,
      v_draft.digital_native_restriction, v_draft.digital_native_usage,
      v_draft.digital_native_file_note,
      v_draft.dossier_scope, v_draft.dossier_period,
      v_draft.dossier_organizations, v_draft.dossier_context,
      v_draft.distribuidora, v_draft.gravadora, v_draft.tese_university, v_draft.tese_advisor,
      v_draft.artigo_source, v_draft.artigo_volume, v_draft.artigo_issue,
      v_draft.artigo_pages, v_draft.relatorio_org, v_draft.relatorio_recipient,
      v_draft.relatorio_internal_notes,
      v_draft.zine_print_run, v_draft.zine_technique, v_draft.zine_format,
      v_draft.subjects
    )
    returning id into v_book_id;

    -- #biblio-choisie (17/08, elargi le 29/08/2026). La regle voulue : choisir
    -- explicitement la bibliotheque de destination est reserve a l'admin reseau.
    -- Elle etait posee sur initial_copies_library_id SEULEMENT, alors que
    -- owner_library_id est lu AVANT lui, decide donc en premier, et se modifie
    -- librement par toute personne qui catalogue (policy ALL sans portee de
    -- bibliotheque, UPDATE sur les 103 colonnes). La regle etait donc appliquee
    -- sur un champ et ouverte sur celui qui a la priorite.
    v_library_id := v_draft.owner_library_id;

    -- Publier dans le catalogue d'une bibliotheque, c'est y creer un holding et
    -- un exemplaire avec un tombo pris dans SA serie : on ne le fait pas au nom
    -- d'un collectif dont on n'est pas membre.
    if v_library_id is not null
       and not public.fn_caller_is_network_admin()
       and not exists (
         select 1 from public.user_library_memberships ulm
          where ulm.user_id = auth.uid()
            and ulm.status = 'active'
            and ulm.role = any (array['librarian'::text, 'coordenador'::text])
            and ulm.library_id = v_library_id
       ) then
      raise exception
        'Ce rascunho est rattache a une bibliotheque dont vous n''etes pas membre (%).', v_library_id
        using hint = 'error.publish.other_library';
    end if;

    -- La regle de resolution vit desormais dans UNE fonction, appelee ici et
    -- par la vue qui l'affiche a l'ecran. Deux copies d'une meme regle
    -- derivent : ce depot en a paye assez pour ne pas recommencer.
    -- B30 (revue) : une notice IMPORTÉE sans bibliothèque (dépôt d'une compagne
    -- non admise, destination inconnue) ne se publie pas : le repli ci-dessous
    -- la mettrait dans la bibliothèque de qui publie — ou nulle part, pour une
    -- administration sans adhésion. Sa bibliothèque vient du lot (« Changer la
    -- bibliothèque du lot »), ou d'un choix explicite de l'administration.
    if v_library_id is null
       and not (v_draft.initial_copies_library_id is not null and public.fn_caller_is_network_admin())
       -- importée : le lien d'import, ou la trace que la promotion laisse dans
       -- marc_json (le lien part avec une suppression définitive ou avec le run ;
       -- le rejeu du journal ne le recrée pas, la trace reste)
       and (exists (select 1 from ingest.partner_catalog_row_to_draft m where m.draft_id = p_draft_id)
            or coalesce(v_draft.marc_json, '{}'::jsonb) ? 'ingest')
       -- avec des exemplaires importés, le refus H19 ci-dessous dit mieux ce qui manque
       and not exists (select 1 from public.exemplar_drafts x
                        where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')) then
      raise exception 'noticia_importada_sem_biblioteca' using hint = 'error.publish.record_without_library';
    end if;
    if v_library_id is null then
      v_library_id := public.fn_book_draft_destination_library(p_draft_id);
    end if;

    -- L'override admin reste le seul chemin pour cibler une autre bibliotheque.
    -- H19 (27/09/2026, revue) : une notice qui porte des exemplaires importés
    -- les publie là où ils ont été attribués (tampon, réattribution du lot) ;
    -- le choix « exemplaires initiaux » de l'écran ne les sépare pas d'elle.
    if v_draft.initial_copies_library_id is not null and public.fn_caller_is_network_admin()
       and not exists (select 1 from public.exemplar_drafts x
                        where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')) then
      v_library_id := v_draft.initial_copies_library_id;
    end if;

    -- H19 : les exemplaires importés vont dans la bibliothèque qui leur a été
    -- DONNÉE (tampon à la promotion, ou réattribution par l'administration),
    -- jamais dans celle que le repli ci-dessus déduit de qui publie : c'est
    -- ainsi que le fonds d'une compagne non admise partirait chez qui clique
    -- (vu au banc le 26/09, suite import_exemplaires T6). Sans bibliothèque :
    -- refus ; bibliothèque différente de celle de la notice : refus.
    if exists (select 1 from public.exemplar_drafts x
                where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')
                  and x.target_library_id is null) then
      raise exception 'exemplares_importados_sem_biblioteca'
        using hint = 'error.publish.items_without_library';
    end if;
    if exists (select 1 from public.exemplar_drafts x
                where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')
                  and x.target_library_id is distinct from v_library_id) then
      raise exception 'exemplares_importados_de_outra_biblioteca'
        using hint = 'error.publish.items_library_mismatch';
    end if;

    if v_library_id is not null then
      v_circ_policy := case when coalesce(v_draft.loanable, true) then 'emprestavel' else 'consulta' end;
      insert into public.book_holdings (book_id, library_id)
      values (v_book_id, v_library_id)
      on conflict (book_id, library_id) do update set updated_at = now()
      returning id into v_holding_id;

      -- #copies (17/08) : N exemplaires (défaut 1, borné 1..50). fn_next_tombo,
      -- appelée en boucle dans la même transaction, voit ses propres INSERT et
      -- renvoie des tombos séquentiels distincts (+ verrou d'avis par préfixe).
      -- H19 : les exemplaires du fichier importé REMPLACENT l'exemplaire
      -- automatique (sinon N importés + 1 automatique). Ils sont publiés plus
      -- bas, une fois la notice marquée publiée.
      select count(*) into v_linked
        from public.exemplar_drafts x
       where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready');
      v_copies := case when v_linked > 0 then 0
                       else greatest(1, least(coalesce(v_draft.initial_copies, 1), 50)) end;
      for v_i in 1..v_copies loop
        begin
          v_auto_tombo := public.fn_next_tombo(v_library_id);
        exception when others then
          -- Pas de tombo_pattern : repli sur bib_ref, suffixé pour éviter la
          -- collision d'unicité globale au-delà du 1er exemplaire.
          v_auto_tombo := case when v_i = 1 then v_draft.bib_ref
                               else v_draft.bib_ref || '-' || v_i::text end;
        end;
        if v_auto_tombo is null or btrim(v_auto_tombo) = '' then
          v_auto_tombo := case when v_i = 1 then v_draft.bib_ref
                               else v_draft.bib_ref || '-' || v_i::text end;
        end if;
        insert into public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
        values (v_draft.bib_ref, v_auto_tombo, v_library_id, v_holding_id, v_circ_policy, 'public');
      end loop;

      perform public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[v_holding_id]);
    end if;

  else
    -- H19 : les exemplaires importés ne se rattachent qu'à une notice CRÉÉE
    -- par la publication (l'import ne produit que des brouillons 'create').
    if exists (select 1 from public.exemplar_drafts x
                where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')) then
      raise exception 'exemplares_importados_em_atualizacao'
        using hint = 'error.publish.items_on_update';
    end if;
    update public.books
    set
      work_id = coalesce(v_draft.work_id, work_id),
      cdd = v_draft.cdd, autor = v_draft.autor, titulo = v_draft.titulo,
      ano = v_draft.ano, editora = v_draft.editora, bib_ref = v_draft.bib_ref,
      loanable = coalesce(v_draft.loanable, true),
      subtitulo = v_draft.subtitulo, edicao = v_draft.edicao,
      local_publicacao = v_draft.local_publicacao,
      isbn = v_draft.isbn, issn = v_draft.issn, idioma = v_draft.idioma,
      paginas = v_draft.paginas, notas = v_draft.notas,
      tipo_material = v_draft.tipo_material,
      cover_object_path = v_draft.cover_object_path,
      -- Capas (27/09/2026) : provenance et licence vont PAR PAIRE et suivent
      -- l'IMAGE. Un brouillon qui porte une provenance impose la sienne,
      -- licence comprise même nulle (Open Library et Inventaire écrivent au
      -- MÊME chemin books/<clé>/front.jpg : re-choisir une candidate ne doit
      -- pas garder la licence de l'autre). Un brouillon qui n'en porte pas
      -- (reprise d'avant cette migration) garde celles de la notice si l'image
      -- est la même — les écrire à NULL effacerait une attribution connue,
      -- comme serial_id le 27/08 — et n'hérite de rien pour une autre image.
      -- Dans un SET, la colonne nue désigne l'ANCIENNE valeur de la ligne.
      cover_source = case when v_draft.cover_source is not null then v_draft.cover_source
                          when v_draft.cover_object_path is not distinct from cover_object_path then cover_source
                          end,
      cover_license = case when v_draft.cover_source is not null then v_draft.cover_license
                           when v_draft.cover_object_path is not distinct from cover_object_path then cover_license
                           end,
      marc_json = coalesce(v_draft.marc_json, '{}'::jsonb),
      updated_by = coalesce(v_draft.updated_by, auth.uid()),
      updated_at = now(), last_cataloged_at = now(),
      -- #périodiques P7b (27/08) : coalesce, comme work_id juste au-dessus.
      -- Un brouillon antérieur à la colonne porte NULL ; l'écrire tel quel
      -- EFFAÇAIT le rattachement à chaque republication, en silence.
      serial_id = coalesce(v_draft.serial_id, serial_id),
      titulo_periodico = v_draft.titulo_periodico,
      volume = v_draft.volume, numero = v_draft.numero,
      fasciculo = v_draft.fasciculo, data_edicao = v_draft.data_edicao,
      periodicidade = v_draft.periodicidade, colecao = v_draft.colecao,
      acquisition_mode = v_draft.acquisition_mode,
      acquisition_date = v_draft.acquisition_date,
      owner_library = v_draft.owner_library, holder_library = v_draft.holder_library,
      partner_source = v_draft.partner_source,
      source_record_id = v_draft.source_record_id,
      source_record_url = v_draft.source_record_url,
      import_format = v_draft.import_format, import_method = v_draft.import_method,
      provenance_note = v_draft.provenance_note,
      mutualization_status = v_draft.mutualization_status,
      source_label = v_draft.source_label,
      tract_campaign = v_draft.tract_campaign, emitter_org = v_draft.emitter_org,
      approximate_date = v_draft.approximate_date,
      diffusion_place = v_draft.diffusion_place, recto_verso = v_draft.recto_verso,
      physical_format = v_draft.physical_format,
      print_technique = v_draft.print_technique,
      physical_state = v_draft.physical_state,
      audio_duration = v_draft.audio_duration, audio_support = v_draft.audio_support,
      audio_format = v_draft.audio_format, audio_language = v_draft.audio_language,
      audio_participants = v_draft.audio_participants,
      audio_recording_type = v_draft.audio_recording_type,
      audiovisual_duration = v_draft.audiovisual_duration,
      audiovisual_support = v_draft.audiovisual_support,
      audiovisual_language = v_draft.audiovisual_language,
      audiovisual_director = v_draft.audiovisual_director,
      audiovisual_participants = v_draft.audiovisual_participants,
      audiovisual_subtitles = v_draft.audiovisual_subtitles,
      audiovisual_access_note = v_draft.audiovisual_access_note,
      digital_native_url = v_draft.digital_native_url,
      digital_native_access = v_draft.digital_native_access,
      digital_native_restriction = v_draft.digital_native_restriction,
      digital_native_usage = v_draft.digital_native_usage,
      digital_native_file_note = v_draft.digital_native_file_note,
      dossier_scope = v_draft.dossier_scope, dossier_period = v_draft.dossier_period,
      dossier_organizations = v_draft.dossier_organizations,
      dossier_context = v_draft.dossier_context,
      distribuidora = v_draft.distribuidora, gravadora = v_draft.gravadora,
      tese_university = v_draft.tese_university, tese_advisor = v_draft.tese_advisor,
      artigo_source = v_draft.artigo_source, artigo_volume = v_draft.artigo_volume,
      artigo_issue = v_draft.artigo_issue, artigo_pages = v_draft.artigo_pages,
      relatorio_org = v_draft.relatorio_org,
      relatorio_recipient = v_draft.relatorio_recipient,
      relatorio_internal_notes = v_draft.relatorio_internal_notes,
      zine_print_run = v_draft.zine_print_run,
      zine_technique = v_draft.zine_technique, zine_format = v_draft.zine_format,
      subjects = v_draft.subjects
    where id = v_draft.published_book_id
    returning id into v_book_id;
  end if;

  update public.book_drafts
  set published_book_id = v_book_id, status = 'published',
      updated_by = coalesce(v_draft.updated_by, auth.uid()), updated_at = now()
  where id = p_draft_id;

  -- H19 : publier les exemplaires importés rattachés, dans la détention qui
  -- vient d'être posée ; chacun reçoit un tombo du schéma de SA bibliothèque
  -- (IMP-21 a) et garde son code d'origine.
  if v_linked > 0 then
    update public.exemplar_drafts x
       set target_library_id = v_library_id,
           target_holding_id = v_holding_id,
           target_bib_ref    = v_draft.bib_ref,
           updated_at        = now()
     where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready');
    for v_x in
      select x.id from public.exemplar_drafts x
       where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')
       order by x.id
    loop
      perform public.publish_exemplar_draft(v_x.id);
    end loop;
    perform public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[v_holding_id]);
  end if;

  perform public.publish_book_draft_digital_resources(p_draft_id, v_book_id);

  return v_book_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.publish_exemplar_draft(p_draft_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_draft public.exemplar_drafts%rowtype;
  v_exemplar_id bigint;
  v_library_id uuid;
  v_bridge record;
  v_resolved_holding_id bigint := null;
  v_resolved_bib_ref text := null;
  v_holding record;
  v_seed_policy text;
  v_final_tombo text;
  v_constraint text;          -- H19
  v_record_status text;       -- H19
  v_existing_library uuid;    -- H19 : l'exemplaire déjà publié (republication)
  v_existing_tombo text;      -- H19
  v_existing_code text;       -- H19
  v_item_code text;           -- H19 : code d'origine qu'aura l'exemplaire
begin
  -- B30 : le staff de catalogage ACTIF, ou l'administration du réseau — les
  -- lots sans bibliothèque ne sont qu'à elle ; la garde #79 ne demandait pas
  -- d'adhésion active et fermait la porte à l'administration sans adhésion.
  IF NOT (public.fn_caller_is_network_admin()
          OR EXISTS (SELECT 1 FROM public.user_library_memberships m
                      WHERE m.user_id = auth.uid() AND m.status = 'active'
                        AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text]))) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.' USING HINT = 'error.catalog.staff_only';
  END IF;
  -- B29 (CAT-E18) : l'exemplaire appartient à sa bibliothèque (cible, sinon
  -- celle de sa notice, sinon celle de son créateur). AVANT la synchronisation
  -- de sa détention, qui écrit dans le brouillon.
  if exists (select 1 from public.exemplar_drafts x where x.id = p_draft_id)
     and not coalesce(public.fn_caller_can_edit_exemplar_draft(p_draft_id), false) then
    raise exception 'Ce rascunho est rattache a une bibliotheque dont vous n''etes pas membre.' using hint = 'error.publish.other_library';
  end if;
  perform public.sync_exemplar_draft_holdings_bridge(p_draft_id);

  select * into v_draft from public.exemplar_drafts where id = p_draft_id;
  if not found then
    raise exception 'Rascunho de exemplar não encontrado: %', p_draft_id;
  end if;
  if v_draft.status = 'cancelled' then
    raise exception 'Este rascunho de exemplar foi descartado.';
  end if;

  -- H19 (26/09/2026, IMP-21) : un exemplaire importé est rattaché à SON
  -- brouillon de notice. Il ne se publie pas avant elle (publish_book_draft le
  -- publie elle-même, dans la détention qu'elle vient de poser : la garde de
  -- révision du lot s'applique ainsi par transitivité).
  if v_draft.book_draft_id is not null then
    select bd.status into v_record_status from public.book_drafts bd where bd.id = v_draft.book_draft_id;
    if v_record_status is distinct from 'published' then
      raise exception 'exemplar_importado_antes_da_ficha' using hint = 'error.publish.item_before_record';
    end if;
    -- Restauré seul depuis la corbeille APRÈS la publication de sa notice, il
    -- n'a pas reçu la référence de la fiche (publish_book_draft n'aligne que
    -- les vivants) : il la prend ici (troisième revue, 27/09).
    if nullif(btrim(coalesce(v_draft.target_bib_ref, '')), '') is null then
      select b.bib_ref into v_draft.target_bib_ref
        from public.book_drafts bd join public.books b on b.id = bd.published_book_id
       where bd.id = v_draft.book_draft_id;
    end if;
  end if;
  -- Un exemplaire venu d'un import (promotion OU rapprochement) ne se publie
  -- jamais sans bibliothèque : le repli sur la bibliothèque principale de qui
  -- publie enverrait le fonds d'une compagne chez qui clique.
  if (v_draft.book_draft_id is not null or v_draft.import_staging_row_id is not null)
     and v_draft.target_library_id is null then
    raise exception 'exemplar_importado_sem_biblioteca' using hint = 'error.publish.item_without_library';
  end if;

  v_library_id := v_draft.target_library_id;

  if v_draft.target_holding_id is not null then
    select h.id, h.library_id,
           coalesce(nullif(trim(h.local_bib_ref), ''), b.bib_ref) as reference_code
      into v_holding
      from public.book_holdings h
      left join public.books b on b.id = h.book_id
     where h.id = v_draft.target_holding_id
     limit 1;
    if found then
      if v_library_id is not null and v_holding.library_id is distinct from v_library_id then
        raise exception 'O holding % pertence a outra biblioteca do que a biblioteca-alvo do rascunho.', v_draft.target_holding_id
          USING ERRCODE = '23514', HINT = 'error.catalog.holding_library_mismatch';
      end if;
      v_resolved_holding_id := v_holding.id;
      v_library_id := v_holding.library_id;
      v_resolved_bib_ref := v_holding.reference_code;
    end if;
  end if;

  if v_library_id is null and v_draft.published_exemplar_id is not null then
    select e.library_id into v_library_id
      from public.exemplares e where e.id = v_draft.published_exemplar_id;
  end if;

  if v_library_id is null then   -- B29
    v_library_id := public.fn_exemplar_draft_fallback_library(v_draft.book_draft_id, v_draft.import_staging_row_id, v_draft.created_by);
  end if;

  if v_library_id is null then
    select ulm.library_id into v_library_id
      from public.user_library_memberships ulm
     where ulm.user_id = auth.uid()
       and ulm.status = 'active'
       and ulm.role = any (array['librarian'::text, 'coordenador'::text])   -- H19
     order by ulm.is_primary desc nulls last, ulm.library_id
     limit 1;
  end if;

  if v_library_id is null then
    raise exception 'Nenhuma biblioteca ativa/principal encontrada para o usuário atual.';
  end if;

  -- H19 (27/09/2026, revue) : publier un exemplaire, c'est écrire dans le
  -- fonds d'une bibliothèque. La garde de tête ne demandait qu'un rôle de
  -- catalogage QUELQUE PART ; seule fn_next_tombo vérifiait l'appartenance,
  -- et un brouillon qui portait déjà son tombo la sautait. Même règle que
  -- fn_next_tombo et publish_book_draft : staff de la bibliothèque visée — et,
  -- pour une republication, de celle qui détient l'exemplaire aujourd'hui —
  -- ou administration du réseau. Placée AVANT le test du code d'origine : il
  -- ne renseigne pas sur le fonds d'une autre bibliothèque.
  if v_draft.published_exemplar_id is not null then
    select e.library_id, e.tombo, e.source_item_code into v_existing_library, v_existing_tombo, v_existing_code
      from public.exemplares e where e.id = v_draft.published_exemplar_id;
  end if;
  if auth.uid() is not null and not public.fn_caller_is_network_admin()
     and (not public.user_has_library_staff_role(auth.uid(), v_library_id)
          or (v_existing_library is not null
              and not public.user_has_library_staff_role(auth.uid(), v_existing_library))) then
    raise exception 'Ce rascunho est rattache a une bibliotheque dont vous n''etes pas membre (%).', v_library_id
      using hint = 'error.publish.other_library';
  end if;

  if v_resolved_holding_id is null then
    select * into v_bridge
      from public.resolve_library_holding_bridge(v_library_id, v_draft.target_bib_ref)
     limit 1;
    if found then
      v_resolved_holding_id := v_bridge.holding_id;
      v_resolved_bib_ref := coalesce(v_bridge.local_bib_ref, v_bridge.resolved_bib_ref);
    else
      v_resolved_bib_ref := nullif(trim(v_draft.target_bib_ref), '');
    end if;
  end if;

  select case when b.loanable then 'ambos' else 'consulta' end
    into v_seed_policy
    from public.book_holdings h
    join public.books b on b.id = h.book_id
   where h.id = v_resolved_holding_id;
  v_seed_policy := coalesce(v_seed_policy, 'consulta');

  -- Chantier 14 : tombo final. Si le brouillon n'en porte pas, on génère le
  -- prochain libre via fn_next_tombo (v_library_id garanti non-null ici).
  v_final_tombo := nullif(btrim(coalesce(v_draft.tombo, '')), '');
  -- H19 : republier un exemplaire déjà publié, dans la MÊME bibliothèque, garde
  -- son tombo (celui de l'étiquette collée) ; un brouillon importé n'en porte
  -- pas, et fn_next_tombo en aurait tiré un neuf à chaque passage. Un
  -- changement de bibliothèque (#cross-lib-reassign) renumérote, comme avant.
  if v_final_tombo is null and v_draft.published_exemplar_id is not null
     and v_existing_library is not distinct from v_library_id then
    v_final_tombo := nullif(btrim(coalesce(v_existing_tombo, '')), '');
  end if;
  if v_final_tombo is null then
    v_final_tombo := public.fn_next_tombo(v_library_id);
  end if;

  -- H19 : le code d'origine (code-barres PMB…) est unique PAR bibliothèque.
  -- Collision dite, jamais contournée : l'index partiel lèverait sinon une
  -- violation d'unicité que le repli du tombo ci-dessous prendrait pour la sienne.
  -- Le code contrôlé est celui qu'aura l'exemplaire : celui du brouillon, sinon
  -- celui qu'il porte déjà (un exemplaire importé réattribué à une autre
  -- bibliothèque l'emporte avec lui : 23505 brut sinon).
  v_item_code := coalesce(nullif(btrim(coalesce(v_draft.source_item_code, '')), ''), v_existing_code);
  if v_item_code is not null
     and exists (select 1 from public.exemplares e
                  where e.library_id = v_library_id
                    and e.source_item_code = v_item_code
                    and e.id is distinct from v_draft.published_exemplar_id) then
    raise exception 'codigo_de_origem_ja_usado: %', v_item_code
      using hint = 'error.publish.source_item_code_taken';
  end if;

  if v_draft.published_exemplar_id is null then
    -- #fix-tombo-stale (15/08/2026) : le tombo figé dans le brouillon peut être
    -- devenu obsolète (mutirão, double-clic, préfixe partagé). Sur collision
    -- d'unicité (forcément le tombo — seul index unique hors PK), on régénère un
    -- tombo libre et on réessaie une fois. fn_next_tombo est global-safe.
    begin
      insert into public.exemplares (
        bib_ref, tombo, shelf_location,
        label_title_override, label_author_override, label_cdd_override, label_note,
        notes, library_id, holding_id,
        circulation_policy, visibility,
        acquisition_mode, acquisition_date, provenance_note, source_library, source_item_code,
        created_at, updated_at
      ) values (
        coalesce(v_resolved_bib_ref, v_draft.target_bib_ref),
        v_final_tombo, v_draft.shelf_location,
        v_draft.label_title_override, v_draft.label_author_override, v_draft.label_cdd_override, v_draft.label_note,
        v_draft.notes, v_library_id, v_resolved_holding_id,
        coalesce(v_draft.circulation_policy, v_seed_policy),
        coalesce(v_draft.visibility, 'public'),
        v_draft.acquisition_mode, v_draft.acquisition_date, v_draft.provenance_note, v_draft.source_library, v_draft.source_item_code,
        now(), now()
      )
      returning id into v_exemplar_id;
    exception when unique_violation then
      -- H19 : ne réessayer que sur une collision de TOMBO ; toute autre
      -- violation d'unicité remonte telle quelle.
      get stacked diagnostics v_constraint = constraint_name;
      if v_constraint is distinct from 'exemplares_unique_tombo' then
        raise;
      end if;
      v_final_tombo := public.fn_next_tombo(v_library_id);
      insert into public.exemplares (
        bib_ref, tombo, shelf_location,
        label_title_override, label_author_override, label_cdd_override, label_note,
        notes, library_id, holding_id,
        circulation_policy, visibility,
        acquisition_mode, acquisition_date, provenance_note, source_library, source_item_code,
        created_at, updated_at
      ) values (
        coalesce(v_resolved_bib_ref, v_draft.target_bib_ref),
        v_final_tombo, v_draft.shelf_location,
        v_draft.label_title_override, v_draft.label_author_override, v_draft.label_cdd_override, v_draft.label_note,
        v_draft.notes, v_library_id, v_resolved_holding_id,
        coalesce(v_draft.circulation_policy, v_seed_policy),
        coalesce(v_draft.visibility, 'public'),
        v_draft.acquisition_mode, v_draft.acquisition_date, v_draft.provenance_note, v_draft.source_library, v_draft.source_item_code,
        now(), now()
      )
      returning id into v_exemplar_id;
    end;
  else
    update public.exemplares
       set bib_ref = coalesce(v_resolved_bib_ref, v_draft.target_bib_ref),
           tombo = coalesce(v_final_tombo, public.exemplares.tombo),
           shelf_location = v_draft.shelf_location,
           label_title_override = v_draft.label_title_override,
           label_author_override = v_draft.label_author_override,
           label_cdd_override = v_draft.label_cdd_override,
           label_note = v_draft.label_note,
           notes = v_draft.notes,
           library_id = coalesce(v_library_id, public.exemplares.library_id),
           holding_id = coalesce(v_resolved_holding_id, public.exemplares.holding_id),
           circulation_policy = coalesce(v_draft.circulation_policy, public.exemplares.circulation_policy),
           visibility = coalesce(v_draft.visibility, public.exemplares.visibility),
           acquisition_mode = coalesce(v_draft.acquisition_mode, public.exemplares.acquisition_mode),
           acquisition_date = coalesce(v_draft.acquisition_date, public.exemplares.acquisition_date),
           provenance_note  = coalesce(v_draft.provenance_note,  public.exemplares.provenance_note),
           source_library   = coalesce(v_draft.source_library,   public.exemplares.source_library),
           source_item_code = coalesce(v_draft.source_item_code, public.exemplares.source_item_code),
           updated_at = now()
     where id = v_draft.published_exemplar_id
    returning id into v_exemplar_id;
  end if;

  update public.exemplar_drafts
     set published_exemplar_id = v_exemplar_id,
         tombo = v_final_tombo,     -- H19 : le tombo réellement posé (republication, formulaire)
         target_library_id = coalesce(v_library_id, target_library_id),
         target_holding_id = coalesce(v_resolved_holding_id, target_holding_id),
         target_bib_ref = coalesce(v_resolved_bib_ref, target_bib_ref),
         status = 'published',
         label_status = 'ready',
         updated_by = coalesce(v_draft.updated_by, auth.uid()),
         updated_at = now()
   where id = p_draft_id;

  return v_exemplar_id;
end;
$function$;

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
      variant_forms = v_draft.variant_forms,
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

CREATE OR REPLACE FUNCTION public.fn_batch_review_report(p_batch_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'extensions'
AS $function$
declare
  v_batch      public.catalog_batches%rowtype;
  v_conv       jsonb := '[]'::jsonb;
  v_rule       record;
  v_items      jsonb;
  v_count      int;
  v_issues     int := 0;
  v_dup_isbn   jsonb;
  v_dup_meta   jsonb;
  v_dup_intra  jsonb;
  v_matching   jsonb;
  v_unlinked   jsonb;
  v_unlinked_n int;
  v_linkable_n int;
  v_title_n    int;
  v_from       text;
  v_sql        text;
  v_ctx        text;
  v_coverage   jsonb;
  v_items_import jsonb;
  v_items_admin boolean;
  v_items_staff uuid[];
  v_hint_err text;   -- B29
begin
  if not (public.fn_caller_is_network_admin()
          or exists (select 1 from public.user_library_memberships m
                      where m.user_id = auth.uid() and m.status = 'active'
                        and m.role in ('librarian', 'coordenador'))) then
    raise exception 'Acesso restrito ao staff de catalogacao.' using hint = 'error.catalog.staff_only';
  end if;

  -- B30 (CAT-E18) : le rapport est au staff de la bibliothèque du lot (et à
  -- l'administration) — refus avant le test d'existence.
  if not public.fn_caller_owns_batch(p_batch_id) then
    raise exception 'Lote de outra biblioteca.' using hint = 'error.batch.other_libraries';
  end if;
  select * into v_batch from public.catalog_batches where id = p_batch_id;
  if not found then
    raise exception 'Lote % introuvable', p_batch_id using hint = 'error.review.batch_not_found';
  end if;

  -- Les brouillons vivants du lot : une fonction, pas une table temporaire.
  -- (Une table temporaire creee dans une RPC reveille pgrst_ddl_watch a
  -- chaque appel : rechargement du cache PostgREST, et l'ecran recevait un 400.)
  v_from := format('public.fn_batch_live_drafts(%s) d', p_batch_id);

  -- ── Conventions : une regle = un SELECT (id, titulo, valeur) sur `d` ──
  for v_rule in
    select * from (values
      ('titulo_missing',   $q$ select d.id, d.titulo, null::text from %s where d.titulo is null or btrim(d.titulo) = '' $q$),
      ('titulo_caps',      $q$ select d.id, d.titulo, d.titulo from %s where d.titulo = upper(d.titulo) and d.titulo ~ '[A-ZÀ-Þ]{4,}' $q$),
      ('titulo_article_end', $q$ select d.id, d.titulo, d.titulo from %s where d.titulo ~ ', (O|A|Os|As|Um|Uma|Le|La|Les|El|Los|Las|The)$' $q$),
      ('autor_missing',    $q$ select d.id, d.titulo, null::text from %s
                                where (d.autor is null or btrim(d.autor) = '')
                                  and not exists (select 1 from public.book_draft_contributors c where c.draft_id = d.id) $q$),
      ('autor_unstructured', $q$ select d.id, d.titulo, d.autor from %s
                                where d.autor is not null and btrim(d.autor) <> ''
                                  and not public.fn_conv_est_non_agent(d.autor)
                                  and not exists (select 1 from public.book_draft_contributors c where c.draft_id = d.id) $q$),
      ('contrib_non_agent', $q$ select d.id, d.titulo, c.name from %s
                                join public.book_draft_contributors c on c.draft_id = d.id
                               where public.fn_conv_est_non_agent(c.name) $q$),
      ('contrib_caps',     $q$ select d.id, d.titulo, c.name from %s
                                join public.book_draft_contributors c on c.draft_id = d.id
                               where c.name ~ '\m[A-ZÀ-Þ]{2,}\M' and c.name !~ '[A-ZÀ-Þ]\.' and not public.fn_conv_est_non_agent(c.name) $q$),
      ('contrib_direct_form', $q$ select d.id, d.titulo, c.name from %s
                                join public.book_draft_contributors c on c.draft_id = d.id
                               where c.name !~ ',' and btrim(c.name) ~ '\s' and not public.fn_conv_est_non_agent(c.name) $q$),
      ('ano_invalid',      $q$ select d.id, d.titulo, d.ano from %s
                                where d.approximate_date is null and (d.ano is null or d.ano !~ '^\d{4}$') $q$),
      ('editora_missing',  $q$ select d.id, d.titulo, null::text from %s where d.editora is null or btrim(d.editora) = '' $q$),
      ('idioma_missing',   $q$ select d.id, d.titulo, null::text from %s where d.idioma is null or btrim(d.idioma) = '' $q$),
      ('tipo_material_invalid', $q$ select d.id, d.titulo, d.tipo_material from %s
                                where d.tipo_material is null or lower(d.tipo_material) <> all (array['livro','periodico','tract','cartaz','audio','audiovisual','recurso_digital','dossie','tese','artigo','relatorio','zine']) $q$),
      ('isbn_invalid',     $q$ select d.id, d.titulo, d.isbn from %s
                                where d.isbn is not null and btrim(d.isbn) <> ''
                                  and length(regexp_replace(upper(d.isbn), '[^0-9X]', '', 'g')) not in (10, 13) $q$),
      ('bib_ref_missing',  $q$ select d.id, d.titulo, null::text from %s where d.bib_ref is null or btrim(d.bib_ref) = '' $q$),
      ('subjects_missing', $q$ select d.id, d.titulo, null::text from %s
                                where (d.subjects is null or btrim(d.subjects) = '')
                                  and not exists (select 1 from public.book_draft_subjects s where s.book_draft_id = d.id) $q$)
    ) as r(rule, sql)
  loop
    v_sql := format(v_rule.sql, v_from);
    execute format('select count(*) from (%s) as q(id, titulo, v)', v_sql) into v_count;
    if v_count > 0 then
      execute format('select coalesce(jsonb_agg(jsonb_build_object(''draft_id'', t.id, ''titulo'', t.titulo, ''value'', t.v)), ''[]''::jsonb)
                        from (select q.id, q.titulo, q.v from (%s) as q(id, titulo, v) order by q.id limit 40) t', v_sql)
         into v_items;
      v_conv := v_conv || jsonb_build_object('rule', v_rule.rule, 'count', v_count, 'items', v_items);
      v_issues := v_issues + v_count;
    end if;
  end loop;

  -- Entree au titre (CONV-8) : informatif, pas un ecart.
  select count(*) into v_title_n from public.fn_batch_live_drafts(p_batch_id) d
   where d.autor is not null and public.fn_conv_est_non_agent(d.autor);

  -- ── Doublons contre le catalogue : ISBN, puis titre + auteur + annee ──
  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_dup_isbn from (
    select jsonb_build_object('draft_id', d.id, 'titulo', d.titulo, 'book_id', b.id, 'reason', 'isbn') as x
      from public.fn_batch_live_drafts(p_batch_id) d
      join public.books b
        on regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g')
         = regexp_replace(upper(coalesce(d.isbn, '')), '[^0-9X]', '', 'g')
     where coalesce(d.isbn, '') <> ''
       and (d.published_book_id is null or b.id <> d.published_book_id)
     order by d.id limit 40) s;

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_dup_meta from (
    select jsonb_build_object('draft_id', d.id, 'titulo', d.titulo, 'book_id', b.id, 'reason', 'titulo_autor_ano') as x
      from public.fn_batch_live_drafts(p_batch_id) d
      join public.books b
        on lower(extensions.unaccent(btrim(coalesce(b.titulo, '')))) = lower(extensions.unaccent(btrim(coalesce(d.titulo, ''))))
       and coalesce(b.ano, '') = coalesce(d.ano, '')
       and lower(extensions.unaccent(btrim(coalesce(b.autor, '')))) = lower(extensions.unaccent(btrim(coalesce(d.autor, ''))))
     where coalesce(d.titulo, '') <> ''
       and (d.published_book_id is null or b.id <> d.published_book_id)
       and not (coalesce(d.isbn, '') <> '' and
                regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g')
              = regexp_replace(upper(coalesce(d.isbn, '')), '[^0-9X]', '', 'g'))
     order by d.id limit 40) s;

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_dup_intra from (
    select jsonb_build_object('titulo', min(d.titulo), 'draft_ids', jsonb_agg(d.id order by d.id)) as x
      from public.fn_batch_live_drafts(p_batch_id) d
     where coalesce(d.titulo, '') <> ''
     group by lower(extensions.unaccent(btrim(d.titulo))),
              lower(extensions.unaccent(btrim(coalesce(d.autor, '')))),
              coalesce(d.ano, '')
    having count(*) > 1
     order by min(d.id) limit 40) s;

  select coalesce(jsonb_object_agg(match_status, n), '{}'::jsonb) into v_matching from (
    select sr.match_status, count(*) as n
      from ingest.partner_catalog_row_to_draft m
      join ingest.partner_catalog_staging_rows sr on sr.id = m.staging_row_id
     where m.batch_id = p_batch_id
     group by sr.match_status) s;

  -- ── Autorites : contributeurs non lies, et ceux qu'une fiche attend ──
  select count(*),
         count(*) filter (where public.fn_conv_autorite_homonyme(c.name) is not null)
    into v_unlinked_n, v_linkable_n
    from public.fn_batch_live_drafts(p_batch_id) d
    join public.book_draft_contributors c on c.draft_id = d.id
   where c.author_id is null and not public.fn_conv_est_non_agent(c.name);

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_unlinked from (
    select jsonb_build_object('draft_id', d.id, 'titulo', d.titulo, 'name', c.name,
                              'suggested_author_id', a.id, 'suggested_sort_name', a.sort_name) as x
      from public.fn_batch_live_drafts(p_batch_id) d
      join public.book_draft_contributors c on c.draft_id = d.id
      left join public.authors a on a.id = public.fn_conv_autorite_homonyme(c.name)
     where c.author_id is null and not public.fn_conv_est_non_agent(c.name)
     order by (a.id is null), d.id limit 40) s;

  -- ── H16 (26/09/2026) : ce que chaque import d'origine a repris ────────
  -- Pour chaque run dont ce lot est issu : les comptes (repris / indice /
  -- brut), l'encodage lu, les entrees ecartees, et SEULEMENT les zones,
  -- colonnes ou balises NON reprises (le rapport ne recopie pas tout le
  -- fichier). La couverture complete reste dans le summary du run.
  select coalesce(jsonb_agg(x order by (x->>'run_id')::bigint), '[]'::jsonb) into v_coverage from (
    select jsonb_build_object(
             'run_id', r.id,
             'original_filename', r.original_filename,
             'detected_format', r.detected_format,
             'counts', r.summary->'coverage_counts',
             'encoding', r.summary->'encoding',
             'skipped_rows', r.summary->'skipped_rows',
             'kind', r.summary->'coverage'->>'kind',
             'not_taken', coalesce(
               jsonb_path_query_array(r.summary->'coverage', '$.zones[*] ? (@.status != "repris")'),
               '[]'::jsonb)
               || coalesce(jsonb_path_query_array(r.summary->'coverage', '$.columns[*] ? (@.status != "repris")'), '[]'::jsonb)
               || coalesce(jsonb_path_query_array(r.summary->'coverage', '$.tags[*] ? (@.status != "repris")'), '[]'::jsonb)
           ) as x
      from ingest.partner_catalog_import_runs r
     where r.id in (select distinct m.run_id from ingest.partner_catalog_row_to_draft m where m.batch_id = p_batch_id)
  ) s;

  -- ── H19 (26-27/09/2026) : les exemplaires importés du lot ─────────────
  -- Ceux d'une notice promue (book_draft_id) et ceux d'un rapprochement
  -- (import_staging_row_id, sans notice). Ce qui empêcherait leur
  -- publication, dit AVANT : pas de bibliothèque ; bibliothèque autre que
  -- celle où la notice publiera ; pas de schéma de numérotation (fn_next_tombo
  -- lèverait) ; code d'origine déjà pris dans la bibliothèque ; présent deux
  -- fois dans le lot ; attendu par un brouillon vivant d'un AUTRE lot.
  -- En un passage (fenêtre, pas de sous-requête corrélée par ligne : un
  -- catalogue PMB entier passe dans un lot) ; 40 problèmes au plus, comme les
  -- autres sections, les comptes portent sur tout. « Code déjà pris » ne se
  -- calcule que pour une bibliothèque dont l'appelant est staff (ou pour
  -- l'administration du réseau) : ailleurs il renseignerait sur des
  -- exemplaires qu'il ne voit pas.
  v_items_admin := public.fn_caller_is_network_admin();
  select coalesce(array_agg(m.library_id), '{}'::uuid[]) into v_items_staff
    from public.user_library_memberships m
   where m.user_id = auth.uid() and m.status = 'active'
     and m.role in ('librarian', 'coordenador');

  with q0 as (
    select x.id, x.book_draft_id, x.source_item_code, x.target_library_id, x.tombo,
           coalesce(d.titulo, b.titulo) as titulo,
           case when d.id is not null
                then public.fn_book_draft_library(d.id) end as record_library,   -- B29 : sans repli sur qui regarde
           l.tombo_pattern,
           count(*) over (partition by x.target_library_id, x.source_item_code) as n_same_code
      from public.exemplar_drafts x
      left join public.book_drafts d on d.id = x.book_draft_id
      left join lateral (select bk.titulo from public.books bk
                          where x.book_draft_id is null and bk.bib_ref = x.target_bib_ref
                          limit 1) b on true
      left join public.libraries l on l.id = x.target_library_id
     where x.batch_id = p_batch_id
       and (x.book_draft_id is not null or x.import_staging_row_id is not null)
       and x.status in ('draft', 'ready')
       and (d.id is null or d.status in ('draft', 'ready'))
       -- B30 : hors administration, les exemplaires de la bibliothèque du lot
       -- (d'une notice : la bibliothèque de la notice ; d'un rapprochement : sa cible).
       and (v_items_admin
            or (d.id is null and x.target_library_id = v_batch.library_id)
            or (d.id is not null
                and coalesce(d.owner_library_id, public.fn_book_draft_creator_library(d.id, d.created_by))
                    is not distinct from v_batch.library_id))
  ), q as (
    select q0.*,
           case
             when q0.target_library_id is null then 'without_library'
             when q0.book_draft_id is not null
                  and q0.record_library is distinct from q0.target_library_id then 'library_mismatch'
             when q0.tombo_pattern is null and nullif(btrim(coalesce(q0.tombo, '')), '') is null then 'library_without_numbering'
             when q0.source_item_code is not null
                  and (v_items_admin or q0.target_library_id = any(v_items_staff))
                  and exists (select 1 from public.exemplares e
                               where e.library_id = q0.target_library_id
                                 and e.source_item_code = q0.source_item_code) then 'code_taken'
             when q0.source_item_code is not null and q0.n_same_code > 1 then 'code_twice'
             when q0.source_item_code is not null and exists (
                    select 1 from public.exemplar_drafts y
                     where y.target_library_id = q0.target_library_id
                       and y.source_item_code = q0.source_item_code
                       and y.batch_id is distinct from p_batch_id
                       and y.status in ('draft', 'ready')) then 'code_pending_elsewhere'
             else null
           end as reason
      from q0
  )
  select jsonb_build_object(
           'count', count(*),
           'with_code', count(*) filter (where q.source_item_code is not null),
           'without_library', count(*) filter (where q.reason = 'without_library'),
           'library_mismatch', count(*) filter (where q.reason = 'library_mismatch'),
           'library_without_numbering', count(*) filter (where q.reason = 'library_without_numbering'),
           'code_taken', count(*) filter (where q.reason = 'code_taken'),
           'code_twice', count(*) filter (where q.reason = 'code_twice'),
           'code_pending_elsewhere', count(*) filter (where q.reason = 'code_pending_elsewhere'),
           'problems', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'item_draft_id', p.id, 'draft_id', p.book_draft_id, 'titulo', p.titulo,
                      'source_item_code', p.source_item_code, 'reason', p.reason)
                    order by p.book_draft_id nulls last, p.id)
               from (select * from q where q.reason is not null
                      order by q.book_draft_id nulls last, q.id limit 40) p), '[]'::jsonb))
    into v_items_import
    from q;

  return jsonb_build_object(
    'batch', jsonb_build_object(
      'id', v_batch.id, 'name', v_batch.name, 'status', v_batch.status,
      'library_id', v_batch.library_id,   -- B30
      'library_name', (select coalesce(l.short_name, l.name) from public.libraries l where l.id = v_batch.library_id),
      'imported', public.fn_batch_is_imported(p_batch_id),
      'drafts_active', (select count(*) from public.fn_batch_live_drafts(p_batch_id)),
      'drafts_published', (select count(*) from public.book_drafts where batch_id = p_batch_id and status = 'published'),
      -- B30 : la corbeille de la bibliothèque du lot (les publiées : tout le lot, son historique).
      'drafts_cancelled', (select count(*) from public.book_drafts d where d.batch_id = p_batch_id and d.status = 'cancelled'
                             and (v_items_admin
                                  or coalesce(d.owner_library_id, public.fn_book_draft_creator_library(d.id, d.created_by))
                                     is not distinct from v_batch.library_id)),
      'title_entries', v_title_n),
    'generated_at', now(),
    'coverage', v_coverage,
    'items', v_items_import,
    'conventions', v_conv,
    'duplicates', jsonb_build_object(
      'catalog_isbn', v_dup_isbn,
      'catalog_meta', v_dup_meta,
      'intra_lot', v_dup_intra,
      'import_matching', v_matching),
    'authorities', jsonb_build_object(
      'unlinked_count', v_unlinked_n,
      'linkable_count', v_linkable_n,
      'unlinked', v_unlinked),
    'totals', jsonb_build_object(
      'convention_issues', v_issues,
      'duplicates', jsonb_array_length(v_dup_isbn) + jsonb_array_length(v_dup_meta) + jsonb_array_length(v_dup_intra),
      'unlinked_authorities', v_unlinked_n)
  );
exception when others then
  -- Le contexte de l'erreur remonte a l'ecran : la prochaine panne dira ou.
  get stacked diagnostics v_ctx = pg_exception_context, v_hint_err = pg_exception_hint;
  -- B29 : un refus métier (HINT 'error.…' : staff, lot d'autres bibliothèques)
  -- remonte tel quel, traduisible par l'écran ; une panne, avec son contexte.
  if v_hint_err like 'error.%' then
    raise exception '%', sqlerrm using errcode = sqlstate, hint = v_hint_err;
  end if;
  -- Pas de HINT i18n ici : l'ecran afficherait la cle traduite et perdrait le
  -- message ; le texte brut, lui, dit ou ca casse.
  raise exception '% [%] @ %', sqlerrm, sqlstate, left(regexp_replace(v_ctx, E'\\s+', ' ', 'g'), 240)
    using errcode = sqlstate;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_batch_review_request(p_batch_id bigint, p_message text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest'
AS $function$
declare
  v_batch  public.catalog_batches%rowtype;
  v_last   text;
  v_round  int;
  v_id     bigint;
begin
  -- B30 (CAT-E18) : la coordination DE la bibliothèque du lot (ou
  -- l'administration) — avant tout autre contrôle, lot inexistant compris.
  if not public.fn_caller_coordinates_batch(p_batch_id) then
    raise exception 'Acesso restrito ao coordenador da biblioteca.' using hint = 'error.review.coordenador_only';
  end if;

  select * into v_batch from public.catalog_batches where id = p_batch_id;
  if not found then
    raise exception 'Lote % introuvable', p_batch_id using hint = 'error.review.batch_not_found';
  end if;
  if v_batch.status <> 'open' then
    raise exception 'Lote % nao esta aberto', p_batch_id using hint = 'error.review.batch_not_open';
  end if;
  if not public.fn_batch_is_imported(p_batch_id) then
    raise exception 'Lote % nao vem de uma importacao', p_batch_id using hint = 'error.review.not_imported';
  end if;

  v_last := public.fn_batch_review_status(p_batch_id);
  if v_last = 'requested' then
    raise exception 'Revisao ja pedida para o lote %', p_batch_id using hint = 'error.review.already_requested';
  end if;
  -- B30 : l'administration peut rouvrir un lot approuvé (nouveau tour) — la
  -- sortie qu'annonce error.batch.reassign.review_approved : on ne change pas
  -- la bibliothèque d'un lot sous une approbation, on la redemande d'abord.
  if v_last = 'approved' and not public.fn_caller_is_network_admin() then
    raise exception 'Lote % ja aprovado', p_batch_id using hint = 'error.review.already_approved';
  end if;

  select coalesce(max(round), 0) + 1 into v_round
    from public.catalog_batch_reviews where batch_id = p_batch_id;

  insert into public.catalog_batch_reviews
    (batch_id, round, status, requested_by, coord_message, report, report_generated_at)
  values
    (p_batch_id, v_round, 'requested', auth.uid(), nullif(btrim(p_message), ''),
     public.fn_batch_review_report(p_batch_id), now())
  returning id into v_id;

  return jsonb_build_object('ok', true, 'review_id', v_id, 'round', v_round);
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_batch_reassign_library(p_batch_id bigint, p_library_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest'
AS $function$
DECLARE
  v_batch    public.catalog_batches%rowtype;
  v_lib      public.libraries%rowtype;
  v_before   text;
  v_n        integer := 0;
  v_published bigint := 0;
  v_sources  integer := 0;
  v_who      text;
  v_warnings text[] := ARRAY[]::text[];
  v_items    integer := 0;   -- H19
  v_detached integer := 0;   -- B29
  v_authors_out integer := 0;   -- B30
BEGIN
  -- Reattribuer un lot, c'est decider a qui appartient un fonds : un acte de
  -- reseau, comme son entree (04/09) et sa revision (05/09).
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Reatribuicao de lote reservada a administracao da rede.'
      USING HINT = 'error.batch.reassign.admin_only';
  END IF;

  SELECT * INTO v_batch FROM public.catalog_batches WHERE id = p_batch_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lote % introuvable', p_batch_id
      USING HINT = 'error.batch.reassign.not_found';
  END IF;
  IF v_batch.status <> 'open' THEN
    RAISE EXCEPTION 'Lote % nao esta aberto (%)', p_batch_id, v_batch.status
      USING HINT = 'error.batch.reassign.not_open';
  END IF;

  SELECT * INTO v_lib FROM public.libraries WHERE id = p_library_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Biblioteca % introuvable', p_library_id
      USING HINT = 'error.batch.reassign.library_not_found';
  END IF;

  -- Une revision APPROUVEE l'a ete sur un rapport rendu pour une autre
  -- biblio : on ne change pas la destination sous une approbation. Un tour
  -- demande ou renvoye en retouches n'empeche rien.
  IF public.fn_batch_review_status(p_batch_id) = 'approved' THEN
    RAISE EXCEPTION 'Lote % tem revisao aprovada : pedir novo turno antes de reatribuir', p_batch_id
      USING HINT = 'error.batch.reassign.review_approved';
  END IF;

  -- D'ou viennent-ils (pour la trace) ?
  SELECT string_agg(DISTINCT coalesce(l.name, 'sem biblioteca'), ', ' ORDER BY coalesce(l.name, 'sem biblioteca'))
    INTO v_before
    FROM public.book_drafts d
    LEFT JOIN public.libraries l ON l.id = d.owner_library_id
   WHERE d.batch_id = p_batch_id AND d.status IN ('draft', 'ready');

  -- Les brouillons en cours changent de proprietaire. initial_copies_library_id
  -- est remis a nul : c'est l'override admin lu EN DERNIER par
  -- publish_book_draft, il l'emporterait sur la reattribution.
  UPDATE public.book_drafts d
     SET owner_library_id = v_lib.id,
         owner_library    = v_lib.name,
         initial_copies_library_id = NULL,
         updated_at = now()
   WHERE d.batch_id = p_batch_id
     AND d.status IN ('draft', 'ready')
     AND (d.owner_library_id IS DISTINCT FROM v_lib.id
          OR d.owner_library IS DISTINCT FROM v_lib.name
          OR d.initial_copies_library_id IS NOT NULL);
  GET DIAGNOSTICS v_n = ROW_COUNT;

  -- H19 : les brouillons d'exemplaires importés suivent leur notice (la
  -- détention sera posée à la publication, dans la nouvelle bibliothèque) ;
  -- ceux d'un rapprochement (sans notice : import_staging_row_id) aussi.
  UPDATE public.exemplar_drafts x
     SET target_library_id = v_lib.id, target_holding_id = NULL, updated_at = now()
   WHERE x.batch_id = p_batch_id
     AND (x.book_draft_id IS NOT NULL OR x.import_staging_row_id IS NOT NULL)
     AND x.status IN ('draft', 'ready')
     AND (x.target_library_id IS DISTINCT FROM v_lib.id OR x.target_holding_id IS NOT NULL);
  GET DIAGNOSTICS v_items = ROW_COUNT;

  -- B29 (CAT-E18) : les exemplaires SAISIS en cours d'une autre bibliothèque
  -- sortent du lot (ils restent dans sa file) ; publiés et corbeille intacts.
  UPDATE public.exemplar_drafts x
     SET batch_id = NULL, updated_at = now()
   WHERE x.batch_id = p_batch_id
     AND x.book_draft_id IS NULL AND x.import_staging_row_id IS NULL
     AND x.status IN ('draft', 'ready')
     AND coalesce(x.target_library_id, public.fn_exemplar_draft_fallback_library(NULL, NULL, x.created_by))
         IS DISTINCT FROM v_lib.id;
  GET DIAGNOSTICS v_detached = ROW_COUNT;

  -- B30 : les autorités en cours d'une personne qui n'est pas staff de la
  -- nouvelle bibliothèque sortent du lot et retournent à sa file (le lot
  -- ne lui est plus visible). Publiées et corbeille intactes.
  UPDATE public.author_drafts a
     SET batch_id = NULL, updated_at = now()
   WHERE a.batch_id = p_batch_id AND a.status IN ('draft', 'ready')
     AND NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                      WHERE m.user_id = a.created_by AND m.status = 'active'
                        AND m.library_id = v_lib.id
                        AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text]))
     -- l'administration voit tous les lots : les siennes restent.
     AND NOT EXISTS (SELECT 1 FROM public.network_administrators na
                      WHERE na.user_id = a.created_by AND na.status = 'active');
  GET DIAGNOSTICS v_authors_out = ROW_COUNT;

  SELECT count(*) INTO v_published
    FROM public.book_drafts d
   WHERE d.batch_id = p_batch_id AND d.status = 'published';

  -- La source compagne d'ou vient le lot suit : le prochain depot de la meme
  -- compagne arrivera directement chez elle.
  UPDATE ingest.partner_catalog_sources s
     SET destination_library_id = v_lib.id, updated_at = now()
   WHERE s.source_kind IN ('partner_deposit', 'oai_pmh')
     AND s.destination_library_id IS DISTINCT FROM v_lib.id
     AND s.id IN (
       SELECT r.source_id
         FROM ingest.partner_catalog_row_to_draft m
         JOIN ingest.partner_catalog_import_runs r ON r.id = m.run_id
        WHERE m.batch_id = p_batch_id
       -- H19 : la source d'un lot de rapprochement (sans notice) suit aussi.
       UNION
       SELECT r.source_id
         FROM public.exemplar_drafts x
         JOIN ingest.partner_catalog_staging_rows sr ON sr.id = x.import_staging_row_id
         JOIN ingest.partner_catalog_import_runs r ON r.id = sr.run_id
        WHERE x.batch_id = p_batch_id
     );
  GET DIAGNOSTICS v_sources = ROW_COUNT;

  -- La trace, dans la langue des notes de lot (pt-BR, comme fn_create_book_drafts_from_import_rows).
  SELECT coalesce(nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), ''), auth.uid()::text)
    INTO v_who
    FROM public.profiles p WHERE p.id = auth.uid();
  UPDATE public.catalog_batches
     SET notes = concat_ws(E'\n', nullif(notes, ''),
           format('[%s] Lote reatribuido a biblioteca « %s » por %s (lote antes : %s ; %s rascunho(s) em curso ; antes : %s).',
                  to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI UTC'),
                  v_lib.name, coalesce(v_who, '?'),
                  -- B30 : la bibliothèque du lot d'avant (la seule trace durable)
                  coalesce((SELECT l.name FROM public.libraries l WHERE l.id = v_batch.library_id), 'administracao da rede'),
                  v_n, coalesce(v_before, 'sem biblioteca'))),
         library_id = v_lib.id,   -- B30 : la bibliothèque du lot
         updated_at = now()
   WHERE id = p_batch_id;

  -- array_append, pas « || 'litteral' » : un litteral non type a droite d'un
  -- text[] est lu comme un tableau (« malformed array literal »), vu au banc.
  IF v_lib.tombo_pattern IS NULL THEN v_warnings := array_append(v_warnings, 'library_without_tombo_pattern'); END IF;
  IF NOT coalesce(v_lib.is_active, false) THEN v_warnings := array_append(v_warnings, 'library_inactive'); END IF;
  -- B30 : un lot (même vide) qui change de bibliothèque n'est pas « rien à faire ».
  IF v_n = 0 AND v_items = 0 AND v_detached = 0 AND v_authors_out = 0 AND v_batch.library_id IS NOT DISTINCT FROM v_lib.id THEN v_warnings := array_append(v_warnings, 'nothing_to_do'); END IF;
  IF v_detached > 0 THEN v_warnings := array_append(v_warnings, 'items_detached'); END IF;   -- B29
  IF v_authors_out > 0 THEN v_warnings := array_append(v_warnings, 'authors_detached'); END IF;   -- B30

  RETURN jsonb_build_object(
    'ok', true,
    'batch_id', p_batch_id,
    'library_id', v_lib.id,
    'library_name', v_lib.name,
    'drafts_updated', v_n,
    'items_updated', v_items,
    'items_detached', v_detached,   -- B29
    'drafts_published_untouched', v_published,
    'sources_aligned', v_sources,
    'previous', v_before,
    'previous_library_id', v_batch.library_id,   -- B30
    'previous_library_name', (SELECT l.name FROM public.libraries l WHERE l.id = v_batch.library_id),
    'authors_detached', v_authors_out,
    'warnings', to_jsonb(v_warnings)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_book_draft_from_book(p_book_id bigint, p_batch_id bigint DEFAULT NULL::bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id bigint;
begin
  -- B29 (CAT-E18) : reprendre une notice publiée crée un brouillon de SA
  -- bibliothèque — celle de la notice si l'on y est staff, sinon la sienne
  -- (catalogue partagé : une bibliothèque qui détient le livre peut en
  -- proposer une reprise ; la publication ne touche pas owner_library_id).
  if not (public.fn_caller_is_network_admin()
          or cardinality(public.fn_caller_staff_library_ids()) > 0) then
    raise exception 'Acesso restrito ao staff de catalogacao.' using hint = 'error.catalog.staff_only';
  end if;
  -- B30 : dans un lot de la bibliothèque du brouillon (celle de la notice si
  -- l'on y est staff, sinon la sienne) où l'on est staff.
  if p_batch_id is not null and not public.fn_caller_can_range_in_batch(p_batch_id,
       (select case when public.fn_caller_is_network_admin()
                         or b.owner_library_id = any (public.fn_caller_staff_library_ids())
                    then b.owner_library_id
                    else public.fn_user_staff_library((select auth.uid())) end
          from public.books b where b.id = p_book_id)) then
    if public.fn_caller_can_see_batch(p_batch_id) then   -- B30
      raise exception 'Rascunho de outra biblioteca do que a do lote.' using errcode = '42501', hint = 'error.batch.library_mismatch';
    end if;
    raise exception 'Lote com rascunhos de outras bibliotecas.' using hint = 'error.batch.other_libraries';
  end if;
  insert into public.book_drafts (
    published_book_id, batch_id, action, status,
    bib_ref, titulo, subtitulo, autor, edicao, local_publicacao, editora, ano,
    isbn, issn, serial_id, titulo_periodico, volume, numero, fasciculo, data_edicao, periodicidade,
    cdd, idioma, paginas, notas, tipo_material, loanable, colecao,
    cover_object_path, cover_source, cover_license, marc_json,
    acquisition_mode, acquisition_date,
    owner_library, holder_library,
    owner_library_id, holder_library_id,
    partner_source, source_record_id, source_record_url,
    import_format, import_method, provenance_note, mutualization_status, source_label,
    tract_campaign, emitter_org, approximate_date, diffusion_place,
    recto_verso, physical_format, print_technique, physical_state,
    audio_duration, audio_support, audio_format, audio_language,
    audio_participants, audio_recording_type,
    audiovisual_duration, audiovisual_support, audiovisual_language,
    audiovisual_director, audiovisual_participants, audiovisual_subtitles,
    audiovisual_access_note,
    digital_native_url, digital_native_access, digital_native_restriction,
    digital_native_usage, digital_native_file_note,
    dossier_scope, dossier_period, dossier_organizations, dossier_context,
    created_by, updated_by
  )
  select
    b.id, p_batch_id, 'update', 'draft',
    b.bib_ref, b.titulo, b.subtitulo, b.autor, b.edicao, b.local_publicacao, b.editora, b.ano,
    b.isbn, b.issn, b.serial_id, b.titulo_periodico, b.volume, b.numero, b.fasciculo, b.data_edicao, b.periodicidade,
    b.cdd, b.idioma, b.paginas, b.notas, b.tipo_material, b.loanable, b.colecao,
    b.cover_object_path, b.cover_source, b.cover_license, coalesce(b.marc_json, '{}'::jsonb),
    b.acquisition_mode, b.acquisition_date,
    b.owner_library, b.holder_library,
    case when public.fn_caller_is_network_admin()
              or b.owner_library_id = any (public.fn_caller_staff_library_ids())
         then b.owner_library_id
         else public.fn_user_staff_library((select auth.uid())) end,
    b.holder_library_id,
    b.partner_source, b.source_record_id, b.source_record_url,
    b.import_format, b.import_method, b.provenance_note, b.mutualization_status, b.source_label,
    b.tract_campaign, b.emitter_org, b.approximate_date, b.diffusion_place,
    b.recto_verso, b.physical_format, b.print_technique, b.physical_state,
    b.audio_duration, b.audio_support, b.audio_format, b.audio_language,
    b.audio_participants, b.audio_recording_type,
    b.audiovisual_duration, b.audiovisual_support, b.audiovisual_language,
    b.audiovisual_director, b.audiovisual_participants, b.audiovisual_subtitles,
    b.audiovisual_access_note,
    b.digital_native_url, b.digital_native_access, b.digital_native_restriction,
    b.digital_native_usage, b.digital_native_file_note,
    b.dossier_scope, b.dossier_period, b.dossier_organizations, b.dossier_context,
    auth.uid(), auth.uid()
  from public.books b
  where b.id = p_book_id
  returning id into v_id;

  if v_id is null then
    raise exception 'Livro nao encontrado: %', p_book_id;
  end if;

  perform public.copy_book_digital_resources_to_draft(p_book_id, v_id);

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_exemplar_draft_from_exemplar(p_exemplar_id bigint, p_batch_id bigint DEFAULT NULL::bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id bigint;
begin
  -- B29 (CAT-E18) : on ne reprend que les exemplaires de ses bibliothèques.
  if exists (select 1 from public.exemplares e where e.id = p_exemplar_id)
     and not public.fn_caller_can_edit_draft_library(
               (select e.library_id from public.exemplares e where e.id = p_exemplar_id), null) then
    raise exception 'Exemplar de outra biblioteca.' using hint = 'error.catalog.draft_other_library';
  end if;
  -- B30 : dans un lot de la bibliothèque de l'exemplaire.
  if p_batch_id is not null and not public.fn_caller_can_range_in_batch(p_batch_id,
       (select e.library_id from public.exemplares e where e.id = p_exemplar_id)) then
    if public.fn_caller_can_see_batch(p_batch_id) then   -- B30
      raise exception 'Rascunho de outra biblioteca do que a do lote.' using errcode = '42501', hint = 'error.batch.library_mismatch';
    end if;
    raise exception 'Lote com rascunhos de outras bibliotecas.' using hint = 'error.batch.other_libraries';
  end if;
  insert into public.exemplar_drafts (
    published_exemplar_id,
    batch_id,
    action,
    status,
    label_status,
    target_bib_ref,
    target_library_id,
    target_holding_id,
    tombo,
    shelf_location,
    label_title_override,
    label_author_override,
    label_cdd_override,
    label_note,
    notes,
    acquisition_mode,
    acquisition_date,
    provenance_note,
    source_library,
    created_by,
    updated_by
  )
  select
    e.id,
    p_batch_id,
    'update',
    'draft',
    'pending',
    coalesce(
      nullif(trim(h.local_bib_ref), ''),
      rb.local_bib_ref,
      b_holding.bib_ref,
      b_legacy.bib_ref,
      e.bib_ref
    ) as target_bib_ref,
    e.library_id as target_library_id,
    coalesce(e.holding_id, rb.holding_id) as target_holding_id,
    e.tombo,
    e.shelf_location,
    e.label_title_override,
    e.label_author_override,
    e.label_cdd_override,
    e.label_note,
    e.notes,
    e.acquisition_mode,
    e.acquisition_date,
    e.provenance_note,
    e.source_library,
    auth.uid(),
    auth.uid()
  from public.exemplares e
  left join public.book_holdings h
    on h.id = e.holding_id
  left join public.books b_holding
    on b_holding.id = h.book_id
  left join lateral public.resolve_library_holding_bridge(e.library_id, e.bib_ref) rb
    on e.holding_id is null
  left join public.books b_legacy
    on e.holding_id is null
   and rb.holding_id is null
   and b_legacy.bib_ref = e.bib_ref
  where e.id = p_exemplar_id
  returning id into v_id;

  if v_id is null then
    raise exception 'Exemplar não encontrado: %', p_exemplar_id;
  end if;

  perform public.sync_exemplar_draft_holdings_bridge(v_id);

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_author_draft_from_author(p_author_id bigint, p_batch_id bigint DEFAULT NULL::bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id bigint;
begin
  -- B29 : reprendre une autorité est un geste de catalogage (staff actif, ou
  -- administration du réseau) ; le brouillon est à qui l'a repris.
  if not (public.fn_caller_is_network_admin()
          or cardinality(public.fn_caller_staff_library_ids()) > 0) then
    raise exception 'Acesso restrito ao staff de catalogacao.' using hint = 'error.catalog.staff_only';
  end if;
  -- B30 : une autorité (sans bibliothèque) dans un lot où l'on est staff
  -- (lu sous verrou : une réattribution en cours est attendue).
  if p_batch_id is not null
     and not (public.fn_caller_is_network_admin() or public.fn_caller_batch_library(p_batch_id) is not null) then
    raise exception 'Lote com rascunhos de outras bibliotecas.' using hint = 'error.batch.other_libraries';
  end if;
  insert into public.author_drafts (
    published_author_id, batch_id, action, status,
    preferred_name, sort_name, biography, birth_year, death_year, country,
    source_kind, source_label, source_url, viaf_id, isni, wikidata_id,
    variant_forms, photo_object_path, notes, structured_meta, writing_language, name_lang,
    created_by, updated_by
  )
  select
    a.id, p_batch_id, 'update', 'draft',
    a.preferred_name, a.sort_name, a.biography, a.birth_year, a.death_year, a.country,
    a.source_kind, a.source_label, a.source_url, a.viaf_id, a.isni, a.wikidata_id,
    a.variant_forms, a.photo_object_path, a.notes,
    coalesce(a.structured_meta, '{}'::jsonb), a.writing_language, a.name_lang,
    auth.uid(), auth.uid()
  from public.authors a
  where a.id = p_author_id
  returning id into v_id;

  if v_id is null then
    raise exception 'Autor nao encontrado: %', p_author_id;
  end if;

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_restore_deleted_draft(p_audit_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog', 'pg_temp'
AS $function$
declare
  v_log      public.catalog_audit_log%rowtype;
  v_snap     jsonb;
  v_tbl      text;
  v_id       bigint;
  v_exists   boolean;
  v_child    record;
  v_fk       text;
  v_enfants  int := 0;
  v_n        int;
  v_lib      uuid;   -- B29
  v_rows     jsonb;   -- H19
begin
  -- Meme porte que la publication : le staff de catalogage. Restaurer n'est pas
  -- un geste destructeur, il n'a pas a etre plus reserve que catalguer.
  if not exists (select 1 from public.user_library_memberships m
                  where m.user_id = auth.uid() and m.status = 'active'
                    and m.role = any (array['librarian'::text, 'coordenador'::text]))
     and not public.fn_caller_is_network_admin() then
    raise exception 'Acesso restrito ao staff de catalogacao.'
      using hint = 'error.catalog.staff_only';
  end if;

  select * into v_log from public.catalog_audit_log where id = p_audit_id;
  if not found or v_log.action <> 'delete' then
    raise exception 'entree de journal % introuvable ou pas une suppression', p_audit_id
      using hint = 'error.catalog.restore_not_found';
  end if;

  v_snap := v_log.details -> 'snapshot';
  v_tbl  := v_log.details ->> 'source_table';
  if v_snap is null or v_tbl is null then
    raise exception 'instantane absent pour le journal % (purge de retention ?)', p_audit_id
      using hint = 'error.catalog.restore_no_snapshot';
  end if;
  -- La table vient du journal : on la confronte a la liste, on ne la concatene
  -- pas telle quelle dans du SQL.
  if v_tbl not in ('book_drafts', 'author_drafts', 'exemplar_drafts') then
    raise exception 'table inattendue dans le journal % : %', p_audit_id, v_tbl;
  end if;

  v_id := (v_snap ->> 'id')::bigint;

  -- B29 (CAT-E18) : on ne rejoue que ce qu'on pourrait modifier. Autorité :
  -- qui l'a créée, ou l'administration. Notice, exemplaire : la bibliothèque
  -- enregistrée par le journal, sinon celle de l'instantané, sinon celle du
  -- créateur.
  if v_tbl = 'author_drafts' then
    if (public.fn_caller_is_network_admin()
        or (v_snap ->> 'created_by') = (select auth.uid())::text) is not true then   -- created_by nul : pas à soi
      raise exception 'Rascunho de autoridade de outra pessoa.' using hint = 'error.catalog.author_draft_creator_only';
    end if;
  else
    v_lib := coalesce(
      v_log.library_id,
      case when v_tbl = 'book_drafts' then (v_snap ->> 'owner_library_id')::uuid
           else coalesce((v_snap ->> 'target_library_id')::uuid,
                         public.fn_book_draft_library((v_snap ->> 'book_draft_id')::bigint)) end,
      -- (pas pour un brouillon créé par l'administration : un dépôt promu perd
      -- son lien d'import à la suppression — même règle que
      -- fn_book_draft_creator_library)
      case when v_snap ->> 'import_staging_row_id' is null
                and not exists (select 1 from public.network_administrators na
                                 where na.user_id = (v_snap ->> 'created_by')::uuid and na.status = 'active')
           then public.fn_user_staff_library((v_snap ->> 'created_by')::uuid) end);
    if not public.fn_caller_can_edit_draft_library(v_lib, (v_snap ->> 'created_by')::uuid) then
      raise exception 'Rascunho de outra biblioteca.' using hint = 'error.catalog.draft_other_library';
    end if;
  end if;
  execute format('select exists (select 1 from public.%I where id = $1)', v_tbl)
    into v_exists using v_id;
  if v_exists then
    raise exception 'le brouillon % existe deja : rien a rejouer', v_id
      using hint = 'error.catalog.restore_already';
  end if;

  -- H19 (27/09) : un exemplaire rejoué seul. Sa notice a disparu depuis :
  -- refus dit (la rejouer d'abord, elle le ramènera s'il était dans son
  -- instantané). Sa ligne importée a été purgée : le lien seul tombe.
  if v_tbl = 'exemplar_drafts' then
    if v_snap->>'book_draft_id' is not null
       and not exists (select 1 from public.book_drafts b where b.id = (v_snap->>'book_draft_id')::bigint) then
      raise exception 'notice % absente : la restaurer d''abord', v_snap->>'book_draft_id'
        using hint = 'error.catalog.restore_record_first';
    end if;
    if v_snap->>'import_staging_row_id' is not null
       and not exists (select 1 from ingest.partner_catalog_staging_rows sr
                        where sr.id = (v_snap->>'import_staging_row_id')::bigint) then
      v_snap := jsonb_set(v_snap, '{import_staging_row_id}', 'null'::jsonb);
    end if;
  end if;
  if v_lib is not null then   -- B29
    if v_tbl = 'book_drafts' and v_snap ->> 'owner_library_id' is null then
      v_snap := jsonb_set(v_snap, '{owner_library_id}', to_jsonb(v_lib));
      if nullif(btrim(coalesce(v_snap ->> 'owner_library', '')), '') is null then
        v_snap := jsonb_set(v_snap, '{owner_library}',
                            coalesce((select to_jsonb(l.name) from public.libraries l where l.id = v_lib), 'null'::jsonb));
      end if;
    elsif v_tbl = 'exemplar_drafts' and v_snap ->> 'target_library_id' is null
          and v_snap ->> 'book_draft_id' is null and v_snap ->> 'import_staging_row_id' is null then
      v_snap := jsonb_set(v_snap, '{target_library_id}', to_jsonb(v_lib));
    end if;
  end if;
  -- B30 : le lot de l'instantané n'est repris que s'il existe encore et que le
  -- brouillon peut s'y ranger (sa bibliothèque = celle du lot, où l'on est
  -- staff ; une autorité : un lot où l'on est staff ; l'administration : tout) ;
  -- sinon il revient hors lot (un lot supprimé depuis violerait la clé). Un
  -- exemplaire importé rejoué seul reprend le lot de sa notice.
  if v_tbl = 'exemplar_drafts' and v_snap ->> 'book_draft_id' is not null then
    v_snap := jsonb_set(v_snap, '{batch_id}',
                coalesce((select to_jsonb(b.batch_id) from public.book_drafts b
                           where b.id = (v_snap ->> 'book_draft_id')::bigint), 'null'::jsonb));
  elsif v_snap ->> 'batch_id' is not null then
    if not exists (select 1 from public.catalog_batches b where b.id = (v_snap ->> 'batch_id')::bigint)
       or not (case when v_tbl = 'author_drafts'
                    then (public.fn_caller_is_network_admin()
                          or public.fn_caller_batch_library((v_snap ->> 'batch_id')::bigint) is not null)
                    else public.fn_caller_can_range_in_batch((v_snap ->> 'batch_id')::bigint,
                           case when v_tbl = 'book_drafts' then (v_snap ->> 'owner_library_id')::uuid
                                else coalesce((v_snap ->> 'target_library_id')::uuid, v_lib) end) end) then
      v_snap := jsonb_set(v_snap, '{batch_id}', 'null'::jsonb);
    end if;
  end if;
  execute format(
    'insert into public.%I select * from jsonb_populate_record(null::public.%I, $1)', v_tbl, v_tbl)
    using v_snap;

  if v_tbl = 'book_drafts' then
    for v_child in
      select key as tbl, value as rows
        from jsonb_each(coalesce(v_log.details -> 'children', '{}'::jsonb))
    loop
      if v_child.tbl not in ('book_draft_contributors', 'book_draft_subjects',
                             'book_draft_catalog_context', 'book_draft_digital_resources',
                             'exemplar_drafts') then   -- H19
        continue;
      end if;
      -- L'INSERT du parent a reveille ses propres triggers : celui qui seme les
      -- contributeurs depuis `autor`, celui qui derive le contexte de catalogage
      -- depuis marc_json. Ils viennent de fabriquer des enfants QUI NE SONT PAS
      -- ceux qu'on rejoue — d'ou un conflit de cle primaire sur
      -- book_draft_catalog_context (trouve par les tests, pas par la lecture).
      -- Regle retenue : l'instantane fait foi, il decrit l'etat au moment de la
      -- suppression. On efface ce que les triggers ont pose, puis on rejoue.
      v_fk := case v_child.tbl when 'book_draft_contributors' then 'draft_id'
                               else 'book_draft_id' end;
      execute format('delete from public.%I where %I = $1', v_child.tbl, v_fk) using v_id;
      v_rows := v_child.rows;
      -- H19 : une ligne importée purgée depuis ne bloque pas le rejeu de
      -- l'exemplaire (sa clé étrangère serait violée) : le lien seul tombe.
      if v_child.tbl = 'exemplar_drafts' then
        select coalesce(jsonb_agg(jsonb_set(case
                 when e.v->>'import_staging_row_id' is not null
                      and not exists (select 1 from ingest.partner_catalog_staging_rows sr
                                       where sr.id = (e.v->>'import_staging_row_id')::bigint)
                 then jsonb_set(e.v, '{import_staging_row_id}', 'null'::jsonb)
                 else e.v end, '{batch_id}', coalesce(v_snap -> 'batch_id', 'null'::jsonb))), '[]'::jsonb)   -- B30 : le lot de la notice
          into v_rows
          from jsonb_array_elements(v_child.rows) as e(v);
      end if;
      execute format(
        'insert into public.%I select * from jsonb_populate_recordset(null::public.%I, $1)',
        v_child.tbl, v_child.tbl) using v_rows;
      get diagnostics v_n = row_count;
      v_enfants := v_enfants + v_n;
    end loop;
  end if;

  -- Le journal est en ajout seul : on n'annote pas la ligne d'origine, on ecrit
  -- une seconde ligne. Une trace qui se reecrit n'est plus une trace.
  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, library_id, label, details)
  values (auth.uid(), 'restore', v_log.entity_type, v_id, v_log.library_id, v_log.label,
          jsonb_build_object('from_audit_id', p_audit_id, 'source_table', v_tbl,
                             'children_restored', v_enfants));

  return jsonb_build_object('ok', true, 'entity_type', v_log.entity_type,
                            'draft_id', v_id, 'source_table', v_tbl,
                            'children_restored', v_enfants);
end;
$function$;

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
  -- B30 : le droit d'abord (lot inexistant compris), puis l'existence.
  IF NOT public.fn_batch_caller_can_edit(p_batch_id) THEN
    RAISE EXCEPTION 'Cotas do lote reservadas ao staff da biblioteca proprietaria.' USING HINT = 'error.bibref.batch.staff_only';
  END IF;
  SELECT * INTO v_batch FROM public.catalog_batches WHERE id = p_batch_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lote % introuvable', p_batch_id USING HINT = 'error.bibref.batch.not_found';
  END IF;
  IF v_batch.status <> 'open' THEN
    RAISE EXCEPTION 'Lote % nao esta aberto', p_batch_id USING HINT = 'error.bibref.batch.not_open';
  END IF;

  -- Les brouillons sans cote doivent appartenir a UNE bibliotheque : la cote
  -- suit sa convention et sa serie.
  -- B30 : la convention est celle de la bibliothèque DU LOT ; un brouillon sans
  -- cote d'une autre bibliothèque (ou sans bibliothèque) rend le lot « mixte ».
  v_owner := v_batch.library_id;
  SELECT count(*) FILTER (WHERE coalesce(d.owner_library_id, public.fn_book_draft_creator_library(d.id, d.created_by))
                                  IS DISTINCT FROM v_batch.library_id),
         count(*)
    INTO v_owners, v_n
    FROM public.book_drafts d
   WHERE d.batch_id = p_batch_id AND d.status IN ('draft', 'ready')
     AND nullif(btrim(coalesce(d.bib_ref, '')), '') IS NULL;
  IF v_n = 0 THEN
    RETURN jsonb_build_object('ok', true, 'batch_id', p_batch_id, 'candidates', 0, 'applied', false, 'updated', 0);
  END IF;
  IF v_owner IS NOT NULL AND v_owners > 0 THEN   -- B30
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

CREATE OR REPLACE FUNCTION public.fn_batch_rubrics(p_batch_id bigint)
 RETURNS TABLE(rubric text, drafts bigint, without_class bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
BEGIN
  -- B30 : le droit d'abord (lot inexistant compris), puis l'existence.
  IF NOT public.fn_batch_caller_can_edit(p_batch_id) THEN
    RAISE EXCEPTION 'Rubricas do lote reservadas ao staff da biblioteca proprietaria.' USING HINT = 'error.rubrics.batch.staff_only';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.catalog_batches WHERE id = p_batch_id) THEN
    RAISE EXCEPTION 'Lote % introuvable', p_batch_id USING HINT = 'error.rubrics.batch.not_found';
  END IF;
  RETURN QUERY
  SELECT q.rubric, count(*)::bigint, count(*) FILTER (WHERE q.sans_classe)::bigint
    FROM (SELECT public.fn_book_draft_rubric(d.id) AS rubric,
                 nullif(btrim(coalesce(d.cdd, '')), '') IS NULL AS sans_classe
            FROM public.book_drafts d
           WHERE d.batch_id = p_batch_id AND d.status IN ('draft', 'ready')
             -- B30 : ce que fn_batch_apply_rubric_classes écrira — hors administration,
             -- les brouillons de la bibliothèque du lot.
             AND (public.fn_caller_is_network_admin()
                  OR coalesce(d.owner_library_id, public.fn_book_draft_creator_library(d.id, d.created_by))
                     IS NOT DISTINCT FROM (SELECT b.library_id FROM public.catalog_batches b WHERE b.id = p_batch_id))) q
   GROUP BY q.rubric
   ORDER BY count(*) DESC, q.rubric NULLS LAST;
END;
$function$;

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
  -- B30 : le droit d'abord (lot inexistant compris), puis l'existence.
  IF NOT public.fn_batch_caller_can_edit(p_batch_id) THEN
    RAISE EXCEPTION 'Rubricas do lote reservadas ao staff da biblioteca proprietaria.' USING HINT = 'error.rubrics.batch.staff_only';
  END IF;
  SELECT * INTO v_batch FROM public.catalog_batches WHERE id = p_batch_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lote % introuvable', p_batch_id USING HINT = 'error.rubrics.batch.not_found';
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
       -- B30 : hors administration, seulement les brouillons de la bibliothèque
       -- du lot (un brouillon d'ailleurs, rangé par l'administration, n'est pas
       -- réécrit par elle).
       AND (public.fn_caller_is_network_admin()
            OR coalesce(d.owner_library_id, public.fn_book_draft_creator_library(d.id, d.created_by))
               IS NOT DISTINCT FROM v_batch.library_id)
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

CREATE OR REPLACE FUNCTION ingest.fn_create_book_drafts_from_import_rows(p_run_id bigint, p_row_ids bigint[] DEFAULT NULL::bigint[], p_batch_name text DEFAULT NULL::text, p_batch_notes text DEFAULT NULL::text, p_created_by uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'ingest', 'public', 'auth'
AS $function$
declare
  v_actor uuid;
  v_partner_name text;
  v_relation_status text;
  v_original_filename text;
  v_detected_format text;
  v_batch_id bigint;
  v_batch_name text;
  v_batch_notes text;
  v_created_count integer := 0;
  v_requested_count integer := 0;
  v_draft_id bigint;
  v_refresh jsonb;
  v_collection_hint text;
  v_local_classification_hint text;
  v_provenance_note text;
  rec record;
begin
  v_actor := coalesce(p_created_by, auth.uid());

  select s.partner_name, s.relation_status, r.original_filename, r.detected_format
    into v_partner_name, v_relation_status, v_original_filename, v_detected_format
  from ingest.partner_catalog_import_runs r
  join ingest.partner_catalog_sources s on s.id = r.source_id
  where r.id = p_run_id;

  if not found then
    raise exception 'import_run % introuvable', p_run_id;
  end if;

  if coalesce(array_length(p_row_ids, 1), 0) > 0 then
    select count(*)::integer
      into v_requested_count
    from ingest.partner_catalog_staging_rows sr
    where sr.run_id = p_run_id
      and sr.id = any(p_row_ids)
      and sr.created_book_draft_id is null
      and sr.created_exemplar_draft_id is null   -- H19 : déjà rapprochée
      and (
        (sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new')
        or
        (sr.match_status in ('matched_book', 'matched_draft', 'possible_duplicate', 'manual_decision')
         and sr.editorial_decision = 'accept_duplicate')
      );
  else
    select count(*)::integer
      into v_requested_count
    from ingest.partner_catalog_staging_rows sr
    where sr.run_id = p_run_id
      and sr.created_book_draft_id is null
      and sr.created_exemplar_draft_id is null   -- H19 : déjà rapprochée
      and sr.selected_for_draft = true
      and sr.review_status = 'approved'
      and (
        (sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new')
        or
        (sr.match_status in ('matched_book', 'matched_draft', 'possible_duplicate', 'manual_decision')
         and sr.editorial_decision = 'accept_duplicate')
      );
  end if;

  if v_requested_count = 0 then
    raise exception 'Aucune ligne autorisée à convertir pour le run %', p_run_id;
  end if;

  v_batch_name := coalesce(
    nullif(trim(p_batch_name), ''),
    format(
      'Import parceiro #%s — %s — %s',
      p_run_id,
      left(coalesce(v_partner_name, 'parceiro sem nome'), 80),
      to_char(now() at time zone 'UTC', 'YYYY-MM-DD HH24:MI UTC')
    )
  );

  v_batch_notes := coalesce(
    nullif(trim(p_batch_notes), ''),
    format(
      'Lote criado a partir do import run %s (%s, formato %s).',
      p_run_id,
      coalesce(v_original_filename, 'arquivo sem nome'),
      coalesce(v_detected_format, 'unknown')
    )
  );

  -- B30 : le lot naît avec sa bibliothèque — celle que fn_import_promote
  -- tamponne ensuite sur ses notices : le run pour un catalogue propre, la
  -- destination pour un dépôt compagnon ou un entrepôt OAI (nulle tant qu'elle
  -- est inconnue : le lot est alors à l'administration).
  insert into public.catalog_batches (name, notes, created_by, library_id)
  values (v_batch_name, v_batch_notes, v_actor,
          (select case when s.source_kind in ('partner_deposit', 'oai_pmh') then s.destination_library_id
                       else r.library_id end
             from ingest.partner_catalog_import_runs r
             left join ingest.partner_catalog_sources s on s.id = r.source_id
            where r.id = p_run_id))
  returning id into v_batch_id;

  for rec in
    select sr.*, r.original_filename, r.detected_format, s.partner_name, s.relation_status, s.source_kind
    from ingest.partner_catalog_staging_rows sr
    join ingest.partner_catalog_import_runs r on r.id = sr.run_id
    join ingest.partner_catalog_sources s on s.id = r.source_id
    where sr.run_id = p_run_id
      and sr.created_book_draft_id is null
      and sr.created_exemplar_draft_id is null   -- H19 : déjà rapprochée
      and not exists (
        select 1 from ingest.partner_catalog_row_to_draft rd where rd.staging_row_id = sr.id
      )
      and (
        (coalesce(array_length(p_row_ids, 1), 0) > 0 and sr.id = any(p_row_ids))
        or
        (coalesce(array_length(p_row_ids, 1), 0) = 0 and sr.selected_for_draft = true and sr.review_status = 'approved')
      )
      and (
        (sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new')
        or
        (sr.match_status in ('matched_book', 'matched_draft', 'possible_duplicate', 'manual_decision')
         and sr.editorial_decision = 'accept_duplicate')
      )
    order by sr.row_no, sr.id
  loop
    v_collection_hint := ingest.fn_partner_catalog_extract_collection_hint(rec.normalized_payload, rec.raw_payload);
    v_local_classification_hint := ingest.fn_partner_catalog_extract_local_classification_hint(rec.normalized_payload, rec.raw_payload);

    v_provenance_note := format(
      'Importado de catálogo parceiro "%s" (%s, run %s, linha %s, formato bruto %s, relação %s, decisão %s).',
      rec.partner_name,
      coalesce(rec.original_filename, 'arquivo sem nome'),
      rec.run_id,
      rec.row_no,
      coalesce(rec.detected_format, 'unknown'),
      coalesce(rec.relation_status, 'sem_status'),
      coalesce(rec.editorial_decision, 'pending')
    );

    if v_local_classification_hint is not null then
      v_provenance_note := v_provenance_note || format(' Sinal local da parceira preservado: %s.', v_local_classification_hint);
    end if;

    insert into public.book_drafts (
      batch_id, action, status, titulo, subtitulo, autor, edicao,
      local_publicacao, editora, ano, isbn, issn, idioma, tipo_material,
      cdd, colecao, marc_json, created_by, updated_by, acquisition_mode,
      partner_source, source_record_id, import_format, import_method,
      provenance_note, mutualization_status, source_label, notas
    ) values (
      v_batch_id,
      'create',
      'draft',
      nullif(trim(rec.title), ''),
      nullif(trim(rec.subtitle), ''),
      coalesce(nullif(trim(rec.responsibility_statement), ''), ingest.fn_format_partner_authors(rec.authors)),
      nullif(trim(rec.edition_statement), ''),
      nullif(trim(rec.place_of_publication), ''),
      nullif(trim(rec.publisher), ''),
      nullif(trim(rec.publication_year), ''),
      nullif(trim(rec.isbn), ''),
      nullif(trim(rec.issn), ''),
      nullif(trim(rec.language), ''),
      -- tipo_material : MAP du type brut (RIS/BibTeX) vers le vocabulaire valide.
      case lower(coalesce(nullif(trim(rec.item_type), ''), 'book'))
        when 'book' then 'livro'
        when 'livro' then 'livro'
        when 'jour' then 'periodico'
        when 'mgzn' then 'periodico'
        when 'news' then 'periodico'
        when 'newspaper' then 'periodico'
        when 'periodico' then 'periodico'
        when 'chap' then 'artigo'
        when 'inbook' then 'artigo'
        when 'article' then 'artigo'
        when 'artigo' then 'artigo'
        when 'thes' then 'tese'
        when 'tese' then 'tese'
        when 'rprt' then 'relatorio'
        when 'relatorio' then 'relatorio'
        when 'pamp' then 'tract'
        when 'tract' then 'tract'
        when 'zine' then 'zine'
        when 'elec' then 'recurso_digital'
        when 'sound' then 'audio'
        when 'audio' then 'audio'
        when 'video' then 'audiovisual'
        when 'mpct' then 'audiovisual'
        when 'audiovisual' then 'audiovisual'
        else 'livro'
      end,
      null,
      case
        when v_collection_hint is null then null
        when lower(coalesce(rec.item_type, '')) ~ '(periodic|journal|article|boletim|periodico|periódico|jour)' then null
        when lower(regexp_replace(coalesce(v_collection_hint, ''), '\s+', ' ', 'g')) = lower(regexp_replace(coalesce(rec.title, ''), '\s+', ' ', 'g')) then null
        else v_collection_hint
      end,
      coalesce(rec.normalized_payload, '{}'::jsonb)
        || jsonb_build_object(
             'ingest',
             jsonb_build_object(
               'run_id', rec.run_id,
               'staging_row_id', rec.id,
               'row_no', rec.row_no,
               'source_file_id', rec.source_file_id,
               'partner_name', rec.partner_name,
               'relation_status', rec.relation_status,
               'original_filename', rec.original_filename,
               'detected_format', rec.detected_format,
               'raw_payload', coalesce(rec.raw_payload, '{}'::jsonb),
               'authors', coalesce(rec.authors, '[]'::jsonb),
               'subjects', coalesce(rec.subjects, '[]'::jsonb),
               'editorial_decision', rec.editorial_decision,
               'editorial_note', rec.editorial_note,
               'derived_collection_hint', v_collection_hint,
               'derived_local_classification_hint', v_local_classification_hint
             )
           ),
      v_actor,
      v_actor,
      null,
      'other_partner',                               -- partner_source : code valide (FK source_partner_code). Nom precis dans provenance_note/source_label.
      coalesce(nullif(trim(rec.external_key), ''), rec.id::text),
      null,                                          -- import_format : NULL (evite FK source_format_code)
      null,                                          -- import_method : NULL (evite FK import_method_code)
      v_provenance_note,
      null,
      coalesce(rec.original_filename, rec.partner_name),
      concat_ws(
        ' ',
        case
          when rec.subjects is not null
           and jsonb_typeof(rec.subjects) = 'array'
           and jsonb_array_length(rec.subjects) > 0
          then 'Assuntos importados: '
               || array_to_string(array(select jsonb_array_elements_text(rec.subjects)), '; ')
          else null
        end,
        case
          when v_local_classification_hint is not null
          then format('Classificação / cote local preservada da parceira: %s.', v_local_classification_hint)
          else null
        end
      )
    ) returning id into v_draft_id;

    insert into ingest.partner_catalog_row_to_draft (staging_row_id, run_id, draft_id, batch_id, created_by)
    values (rec.id, rec.run_id, v_draft_id, v_batch_id, v_actor);

    update ingest.partner_catalog_staging_rows
       set created_book_draft_id = v_draft_id,
           review_status = 'draft_created',
           selected_for_draft = false
     where id = rec.id;

    v_created_count := v_created_count + 1;
  end loop;

  if v_created_count = 0 then
    delete from public.catalog_batches where id = v_batch_id;
    raise exception 'Aucun rascunho créé pour le run %', p_run_id;
  end if;

  v_refresh := ingest.fn_refresh_partner_catalog_run_counters(p_run_id);

  return jsonb_build_object(
    'run_id', p_run_id,
    'batch_id', v_batch_id,
    'batch_name', v_batch_name,
    'requested_rows', v_requested_count,
    'created_drafts', v_created_count,
    'run', v_refresh
  );
end;
$function$;

CREATE OR REPLACE FUNCTION ingest.fn_create_exemplar_drafts_from_import_rows(p_run_id bigint, p_row_ids bigint[] DEFAULT NULL::bigint[], p_batch_name text DEFAULT NULL::text, p_batch_notes text DEFAULT NULL::text, p_created_by uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'ingest', 'public', 'auth'
AS $function$
declare
  v_actor uuid;
  v_library_id uuid;
  v_partner_name text;
  v_original_filename text;
  v_detected_format text;
  v_batch_id bigint;
  v_batch_name text;
  v_batch_notes text;
  v_requested_count integer := 0;
  v_created_count integer := 0;
  v_exemplar_draft_id bigint;
  v_first_id bigint;          -- H19
  v_items_created integer := 0;
  v_items_skipped integer := 0;
  v_rows_held integer := 0;
  v_source_kind text;
  v_destination uuid;
  v_item_library uuid;
  it jsonb;
  v_provenance_note text;
  v_refresh jsonb;
  rec record;
begin
  v_actor := coalesce(p_created_by, auth.uid());

  select r.library_id, s.partner_name, r.original_filename, r.detected_format, s.source_kind, s.destination_library_id
    into v_library_id, v_partner_name, v_original_filename, v_detected_format, v_source_kind, v_destination
  from ingest.partner_catalog_import_runs r
  join ingest.partner_catalog_sources s on s.id = r.source_id
  where r.id = p_run_id;

  if not found then
    raise exception 'import_run % introuvable', p_run_id;
  end if;

  -- H19 (27/09/2026, revue) : le fonds d'un dépôt compagnon (ou d'un entrepôt
  -- OAI) n'entre que par l'administration du réseau — même garde que
  -- fn_import_promote (04/09) — et va à la destination déclarée sur la source,
  -- rien tant qu'elle n'est pas connue (publish_exemplar_draft refuse alors) ;
  -- jamais dans la bibliothèque du run, qui est celle qui a déposé.
  if v_source_kind in ('partner_deposit', 'oai_pmh') and not public.fn_caller_is_network_admin() then
    raise exception 'Deposito de catalogo companheiro reservado a administracao da rede.'
      using hint = 'error.import.deposit_admin_only';
  end if;
  v_item_library := case when v_source_kind in ('partner_deposit', 'oai_pmh') then v_destination
                         else v_library_id end;

  -- Eligibilite : doublon d'un livre PUBLIE, decision accept_duplicate, pas
  -- deja rapproche.
  select count(*)::integer
    into v_requested_count
  from ingest.partner_catalog_staging_rows sr
  where sr.run_id = p_run_id
    and sr.created_exemplar_draft_id is null
    and sr.created_book_draft_id is null        -- H19
    and sr.proposed_book_id is not null
    and sr.editorial_decision = 'accept_duplicate'
    and sr.match_status in ('matched_book', 'possible_duplicate', 'manual_decision')
    and (coalesce(array_length(p_row_ids, 1), 0) = 0 or sr.id = any(p_row_ids));

  if v_requested_count = 0 then
    raise exception 'Aucune ligne eligible au rapprochement pour le run %', p_run_id;
  end if;

  v_batch_name := coalesce(
    nullif(trim(p_batch_name), ''),
    format(
      'Rapprochement parceiro #%s — %s — %s',
      p_run_id,
      left(coalesce(v_partner_name, 'parceiro sem nome'), 80),
      to_char(now() at time zone 'UTC', 'YYYY-MM-DD HH24:MI UTC')
    )
  );

  v_batch_notes := coalesce(
    nullif(trim(p_batch_notes), ''),
    format(
      'Exemplares de rascunho criados a partir do import run %s (%s, formato %s).',
      p_run_id,
      coalesce(v_original_filename, 'arquivo sem nome'),
      coalesce(v_detected_format, 'unknown')
    )
  );

  -- B30 : le lot de rapprochement naît avec la bibliothèque des exemplaires.
  insert into public.catalog_batches (name, notes, created_by, library_id)
  values (v_batch_name, v_batch_notes, v_actor, v_item_library)
  returning id into v_batch_id;

  for rec in
    select sr.id as row_id,
           sr.row_no,
           sr.normalized_payload,
           b.bib_ref as proposed_bib_ref,
           b.titulo  as proposed_titulo
    from ingest.partner_catalog_staging_rows sr
    join public.books b on b.id = sr.proposed_book_id
    where sr.run_id = p_run_id
      and sr.created_exemplar_draft_id is null
      and sr.created_book_draft_id is null      -- H19
      and sr.proposed_book_id is not null
      and sr.editorial_decision = 'accept_duplicate'
      and sr.match_status in ('matched_book', 'possible_duplicate', 'manual_decision')
      and (coalesce(array_length(p_row_ids, 1), 0) = 0 or sr.id = any(p_row_ids))
    order by sr.row_no, sr.id
  loop
    v_provenance_note := format(
      'Exemplar criado a partir de catalogo parceiro "%s" (%s, run %s, linha %s): biblioteca importadora declara possuir um exemplar de "%s".',
      coalesce(v_partner_name, 'parceiro sem nome'),
      coalesce(v_original_filename, 'arquivo sem nome'),
      p_run_id,
      rec.row_no,
      coalesce(rec.proposed_titulo, 'sem titulo')
    );

    -- H19 (IMP-21) : UN brouillon d'exemplaire par exemplaire du fichier
    -- (995/852), avec son code d'origine et sa cote ; à défaut, un seul comme
    -- avant. La ligne pointe le premier (created_exemplar_draft_id) ; les
    -- autres la retrouvent par import_staging_row_id. Un exemplaire dont le
    -- code d'origine est DÉJÀ dans la bibliothèque (réexport du même
    -- catalogue) n'est pas recréé : il y est. Le code n'entre pas dans la
    -- note de provenance (IMP-21 b) : sa colonne suffit.
    v_first_id := null;
    for it in
      select value from jsonb_array_elements(
        case when jsonb_typeof(rec.normalized_payload->'items') = 'array'
              and jsonb_array_length(rec.normalized_payload->'items') > 0
             then rec.normalized_payload->'items'
             else '[{}]'::jsonb end)
    loop
      if nullif(btrim(it->>'source_item_code'), '') is not null
         and v_item_library is not null
         and exists (select 1 from public.exemplares e
                      where e.library_id = v_item_library
                        and e.source_item_code = btrim(it->>'source_item_code')) then
        v_items_skipped := v_items_skipped + 1;
        continue;
      end if;
      insert into public.exemplar_drafts (
        batch_id, action, status, label_status,
        target_library_id, target_bib_ref, source_library, provenance_note,
        source_item_code, shelf_location, notes, import_staging_row_id,
        created_by, updated_by
      ) values (
        v_batch_id, 'create', 'draft', 'pending',
        v_item_library, rec.proposed_bib_ref,
        coalesce(nullif(btrim(it->>'owner'), ''), v_partner_name),
        concat_ws(' ', v_provenance_note,
          'Tipo: ' || nullif(btrim(it->>'item_type'), '') || '.',
          'Publico: ' || nullif(btrim(it->>'public'), '') || '.',
          'Situacao: ' || nullif(btrim(it->>'status'), '') || '.'),
        nullif(btrim(it->>'source_item_code'), ''),
        nullif(btrim(it->>'call_number'), ''),
        nullif(btrim(it->>'note'), ''),
        rec.row_id,
        v_actor, v_actor
      )
      returning id into v_exemplar_draft_id;
      v_first_id := coalesce(v_first_id, v_exemplar_draft_id);
      v_items_created := v_items_created + 1;

      -- Resout / relie le book_holdings (cree a la publication si absent).
      perform public.sync_exemplar_draft_holdings_bridge(v_exemplar_draft_id);
    end loop;
    v_exemplar_draft_id := v_first_id;
    -- Tous les exemplaires de la ligne sont déjà dans la bibliothèque : rien à
    -- rapprocher. La ligne est marquée rejetée, avec la raison — laissée en
    -- 'accept_duplicate' sans brouillon, le « Promouvoir » suivant en faisait
    -- une notice en double, impubliable (seconde revue, 27/09).
    if v_first_id is null then
      update ingest.partner_catalog_staging_rows
         set editorial_decision = 'reject',
             editorial_note = 'Todos os exemplares desta linha ja estao na biblioteca (mesmo codigo de origem): nada a aproximar.',
             editorial_decided_at = now(),
             editorial_decided_by = v_actor,
             review_status = 'rejected',
             selected_for_draft = false
       where id = rec.row_id;
      v_rows_held := v_rows_held + 1;
      continue;
    end if;

    update ingest.partner_catalog_staging_rows
       set created_exemplar_draft_id = v_exemplar_draft_id,
           review_status = 'draft_created',
           selected_for_draft = false
     where id = rec.row_id;

    v_created_count := v_created_count + 1;
  end loop;

  if v_created_count = 0 then
    delete from public.catalog_batches where id = v_batch_id;
    -- H19 : tout était déjà dans la bibliothèque — dit, pas une erreur.
    if v_rows_held > 0 then
      v_refresh := ingest.fn_refresh_partner_catalog_run_counters(p_run_id);
      return jsonb_build_object(
        'run_id', p_run_id, 'batch_id', null, 'batch_name', null,
        'requested_rows', v_requested_count, 'created_exemplar_drafts', 0, 'created_items', 0,
        'items_skipped_code_taken', v_items_skipped, 'rows_already_held', v_rows_held,
        'run', v_refresh);
    end if;
    raise exception 'Aucun brouillon d''exemplaire cree pour le run %', p_run_id;
  end if;

  v_refresh := ingest.fn_refresh_partner_catalog_run_counters(p_run_id);

  return jsonb_build_object(
    'run_id', p_run_id,
    'batch_id', v_batch_id,
    'batch_name', v_batch_name,
    'requested_rows', v_requested_count,
    'created_exemplar_drafts', v_created_count,
    'created_items', v_items_created,
    'items_skipped_code_taken', v_items_skipped,
    'rows_already_held', v_rows_held,
    'run', v_refresh
  );
end;
$function$;


-- ── 8. Les politiques des lots lisent la colonne ──────────────────────────
-- Sur la ligne même (pas une fonction qui relit le lot par id : elle ne
-- verrait pas la ligne qu'un INSERT … RETURNING vient d'écrire), sous la garde
-- d'origine (un accès au catalogage), les aides en InitPlan (garde CI T2).
ALTER POLICY catalog_batches_select_librarian ON public.catalog_batches
  USING ((SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
         AND ((SELECT public.fn_caller_is_network_admin())
              OR library_id = ANY ((SELECT public.fn_caller_staff_library_ids())::uuid[])));
-- Créer un lot : dans une bibliothèque où l'on est staff (le déclencheur a
-- posé la sienne si l'écran n'en a pas choisi) ; sans bibliothèque :
-- l'administration seule. Évalué APRÈS les déclencheurs BEFORE INSERT.
ALTER POLICY catalog_batches_insert_librarian ON public.catalog_batches
  WITH CHECK ((SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
              AND ((SELECT public.fn_caller_is_network_admin())
                   OR library_id = ANY ((SELECT public.fn_caller_staff_library_ids())::uuid[])));
ALTER POLICY catalog_batches_update_librarian ON public.catalog_batches
  USING ((SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
         AND ((SELECT public.fn_caller_is_network_admin())
              OR library_id = ANY ((SELECT public.fn_caller_staff_library_ids())::uuid[])))
  WITH CHECK ((SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
              AND ((SELECT public.fn_caller_is_network_admin())
                   OR library_id = ANY ((SELECT public.fn_caller_staff_library_ids())::uuid[])));
ALTER POLICY catalog_batches_delete_librarian ON public.catalog_batches
  USING ((SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
         AND ((SELECT public.fn_caller_is_network_admin())
              OR library_id = ANY ((SELECT public.fn_caller_staff_library_ids())::uuid[])));
-- La porte restrictive de la suppression d'un lot (qui emporte sa corbeille,
-- 29/08) : la coordination DE sa bibliothèque — rôles coordenador et
-- administrador —, ou l'administration.
ALTER POLICY catalog_batches_suppression_definitive_coordination ON public.catalog_batches
  USING ((SELECT public.fn_caller_is_network_admin())
         OR library_id = ANY ((SELECT public.fn_caller_coordinator_library_ids())::uuid[]));

-- Droits des fonctions recréées : inchangés (CREATE OR REPLACE les garde),
-- réaffirmés pour les gardes CI.
REVOKE EXECUTE ON FUNCTION public.publish_catalog_batch(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_batch_review_report(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_batch_review_request(bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_batch_reassign_library(bigint, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_book_draft_from_book(bigint, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_exemplar_draft_from_exemplar(bigint, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_author_draft_from_author(bigint, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_restore_deleted_draft(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_batch_assign_bib_refs(bigint, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_batch_rubrics(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_batch_apply_rubric_classes(bigint, jsonb, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_batch_owner_libraries() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid) FROM PUBLIC, anon, authenticated;
