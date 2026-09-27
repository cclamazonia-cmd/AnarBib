-- =====================================================================
-- B29 — les brouillons de catalogage appartiennent à leur bibliothèque
-- Date : 2026-09-27 · Backlog v34 B29 · REGISTRE CAT-E18 (décisions de Xavier)
--
-- Constat : book_drafts, exemplar_drafts, author_drafts et les tables enfants
-- des notices n'avaient qu'une politique « peut cataloguer », sans portée de
-- bibliothèque : toute personne qui catalogue lisait et modifiait les
-- brouillons de toutes les bibliothèques, et une cinquantaine de fonctions
-- SECURITY DEFINER ne demandaient qu'un rôle de staff QUELQUE PART.
--
-- Règle : l'administration du réseau voit et modifie tout ; une coordination
-- ou une bibliothécaire, les brouillons des bibliothèques où elle a une
-- adhésion de staff ACTIVE. Bibliothèque d'un brouillon : owner_library_id
-- (notice), target_library_id (exemplaire ; sinon celle de sa notice), sinon
-- celle de l'adhésion de staff active de son CRÉATEUR — jamais pour un
-- brouillon né d'un import (dépôt d'une compagne non admise : à
-- l'administration), et jamais « celle de qui regarde » ; sans bibliothèque :
-- son créateur et l'administration. Autorités : lecture commune, écriture par
-- le créateur et l'administration. Mutirão : adhésion temporaire dans la
-- bibliothèque hôte.
--
--   1. aides (SECURITY DEFINER, STABLE, une évaluation par requête dans les
--      politiques : (select …)) et le prédicat unique fn_caller_can_edit_* ;
--   2. politiques : mêmes noms (gardes CI), portée ajoutée ; autorités en
--      quatre politiques ; enfants de la notice = notice visible ; suppression
--      définitive = coordination DE la bibliothèque du brouillon ;
--   3. par l'API : created_by figé (brouillons et lots), bibliothèque fixée
--      à la création, rangement dans un lot gardé (déclencheurs) ;
--   4. les fonctions SECURITY DEFINER qui lisent ou écrivent des brouillons
--      prennent la même règle (publication, fusion, doublons, lots, révision,
--      journal, reprises, lignes d'import) ; le rapport et les tours de
--      révision d'un lot sont à qui le possède ENTIER (fn_caller_owns_batch).
--
-- Corps des fonctions existantes extraits de la production (md5) et modifiés
-- par ancrages (script du 27/09), jamais retapés — sauf fn_batch_caller_can_edit
-- et fn_batch_owner_libraries, réécrites en entier (quelques lignes).
-- =====================================================================

-- ── 1. Les aides : qui est staff où, à qui appartient un brouillon ─────────
-- SECURITY DEFINER : elles lisent les adhésions d'autres personnes (le
-- créateur) et les liens d'import (schéma ingest, fermé). STABLE, search_path
-- figé. Exécutables par authenticated : les politiques les appellent sous le
-- rôle de qui lit.

-- Les bibliothèques où l'appelant a une adhésion de staff ACTIVE.
CREATE OR REPLACE FUNCTION public.fn_caller_staff_library_ids()
 RETURNS uuid[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select coalesce(array_agg(distinct m.library_id), '{}'::uuid[])
    from public.user_library_memberships m
   where m.user_id = (select auth.uid())
     and m.status = 'active'
     and m.role = any (array['librarian'::text, 'coordenador'::text]);
$function$;

-- Celles où il coordonne (suppression définitive des brouillons).
CREATE OR REPLACE FUNCTION public.fn_caller_coordinator_library_ids()
 RETURNS uuid[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select coalesce(array_agg(distinct m.library_id), '{}'::uuid[])
    from public.user_library_memberships m
   where m.user_id = (select auth.uid())
     and m.status = 'active'
     and m.role = any (array['coordenador'::text, 'administrador'::text]);
$function$;

-- La bibliothèque d'une personne : son adhésion de staff active, départagée
-- comme fn_book_draft_destination_library (principale, ancienneté, id).
CREATE OR REPLACE FUNCTION public.fn_user_staff_library(p_user uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select ulm.library_id
    from public.user_library_memberships ulm
   where ulm.user_id = p_user
     and ulm.status = 'active'
     and ulm.role = any (array['librarian'::text, 'coordenador'::text])
   order by ulm.is_primary desc, ulm.created_at, ulm.library_id
   limit 1;
$function$;

-- Celle de l'appelant (même départage) : pour le déclencheur qui fixe la
-- bibliothèque d'un brouillon créé par l'API. fn_user_staff_library, qui
-- répond pour N'IMPORTE QUI, n'est pas ouverte aux comptes connectés.
CREATE OR REPLACE FUNCTION public.fn_caller_staff_library()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select public.fn_user_staff_library((select auth.uid()));
$function$;

-- Bibliothèque d'un brouillon de notice SANS owner_library_id : celle de son
-- créateur — sauf s'il est né d'un import (le dépôt d'une compagne non admise,
-- promu par l'administration, reste à l'administration : on ne le prête pas à
-- la bibliothèque où l'admin est aussi staff).
CREATE OR REPLACE FUNCTION public.fn_book_draft_creator_library(p_draft_id bigint, p_created_by uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  -- (Créée par un compte d'administration du réseau : pas de repli non plus —
  -- les dépôts de compagnes sont promus par l'administration, et le lien
  -- ingest disparaît avec le run ; ce que l'écran crée reçoit sa bibliothèque
  -- dès l'INSERT, tg_drafts_library_fixed.)
  select case
           when p_created_by is null then null
           when exists (select 1 from ingest.partner_catalog_row_to_draft m where m.draft_id = p_draft_id) then null
           when exists (select 1 from public.network_administrators na
                         where na.user_id = p_created_by and na.status = 'active') then null
           else public.fn_user_staff_library(p_created_by)
         end;
$function$;

-- Bibliothèque RÉSOLUE d'un brouillon de notice.
CREATE OR REPLACE FUNCTION public.fn_book_draft_library(p_draft_id bigint)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select coalesce(d.owner_library_id, public.fn_book_draft_creator_library(d.id, d.created_by))
    from public.book_drafts d
   where d.id = p_draft_id;
$function$;

-- Bibliothèque d'un brouillon d'exemplaire SANS target_library_id : celle de sa
-- notice (exemplaire importé) ; rien pour un exemplaire de rapprochement ; celle
-- du créateur sinon.
CREATE OR REPLACE FUNCTION public.fn_exemplar_draft_fallback_library(p_book_draft_id bigint, p_import_staging_row_id bigint, p_created_by uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  -- La bibliothèque de la notice est résolue EN LIGNE (même règle que
  -- fn_book_draft_library → fn_book_draft_creator_library) : trois fonctions
  -- DEFINER imbriquées par exemplaire importé coûtaient 300 ms sur un dépôt de
  -- 1 800 exemplaires sans bibliothèque, dans chaque liste du staff.
  select case
           when p_book_draft_id is not null then (
             select coalesce(d.owner_library_id,
                      case when d.created_by is null then null
                           when exists (select 1 from ingest.partner_catalog_row_to_draft m where m.draft_id = d.id) then null
                           when exists (select 1 from public.network_administrators na
                                         where na.user_id = d.created_by and na.status = 'active') then null
                           else public.fn_user_staff_library(d.created_by) end)
               from public.book_drafts d where d.id = p_book_draft_id)
           when p_import_staging_row_id is not null then null
           when p_created_by is null then null
           -- créé par l'administration : pas de repli (fn_book_draft_creator_library)
           when exists (select 1 from public.network_administrators na
                         where na.user_id = p_created_by and na.status = 'active') then null
           else public.fn_user_staff_library(p_created_by)
         end;
$function$;

-- Le prédicat unique : l'appelant peut-il agir sur un brouillon de cette
-- bibliothèque (résolue), créé par cette personne ?
CREATE OR REPLACE FUNCTION public.fn_caller_can_edit_draft_library(p_library uuid, p_created_by uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select public.fn_caller_is_network_admin()
      or (p_library is not null and p_library = any (public.fn_caller_staff_library_ids()))
      or (p_library is null and p_created_by is not null
          and p_created_by = (select auth.uid())
          and cardinality(public.fn_caller_staff_library_ids()) > 0);
$function$;

CREATE OR REPLACE FUNCTION public.fn_caller_can_edit_book_draft(p_draft_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- faux (et non NULL) pour un brouillon inexistant : pas d'oracle d'existence
  select coalesce((
    select public.fn_caller_can_edit_draft_library(
             coalesce(d.owner_library_id, public.fn_book_draft_creator_library(d.id, d.created_by)),
             d.created_by)
      from public.book_drafts d
     where d.id = p_draft_id), false);
$function$;

CREATE OR REPLACE FUNCTION public.fn_caller_can_edit_exemplar_draft(p_draft_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select coalesce((
    select public.fn_caller_can_edit_draft_library(
             coalesce(x.target_library_id,
                      public.fn_exemplar_draft_fallback_library(x.book_draft_id, x.import_staging_row_id, x.created_by)),
             x.created_by)
      from public.exemplar_drafts x
     where x.id = p_draft_id), false);
$function$;

-- Autorités (CAT-E18 2) : écriture par qui a créé le brouillon, ou l'admin.
CREATE OR REPLACE FUNCTION public.fn_caller_can_edit_author_draft(p_draft_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select coalesce((
    select public.fn_caller_is_network_admin()
        or (a.created_by = (select auth.uid())
            and cardinality(public.fn_caller_staff_library_ids()) > 0)
      from public.author_drafts a
     where a.id = p_draft_id), false);
$function$;

-- Un lot : l'appelant peut-il en modifier TOUS les brouillons VIVANTS ? (Un
-- exemplaire importé suit sa notice ; p_all_kinds ajoute les exemplaires sans
-- notice et les autorités — publier le lot les publie aussi.) Un lot vide :
-- vrai pour le staff. En plpgsql : la liste des bibliothèques de l'appelant
-- n'est calculée qu'une fois par appel (un catalogue entier tient dans un lot).
CREATE OR REPLACE FUNCTION public.fn_caller_can_edit_batch(p_batch_id bigint, p_all_kinds boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff uuid[];
  v_uid uuid := auth.uid();
BEGIN
  IF public.fn_caller_is_network_admin() THEN RETURN true; END IF;
  v_staff := public.fn_caller_staff_library_ids();
  IF cardinality(v_staff) = 0 THEN RETURN false; END IF;
  IF EXISTS (
       SELECT 1 FROM public.book_drafts d
        WHERE d.batch_id = p_batch_id AND d.status IN ('draft', 'ready')
          -- IS NOT TRUE, pas NOT : une bibliothèque inconnue (NULL) n'est pas
          -- « à nous » — le dépôt d'une compagne non admise reste à l'administration.
          AND ( coalesce(d.owner_library_id, public.fn_book_draft_creator_library(d.id, d.created_by)) = ANY (v_staff)
                OR ( d.owner_library_id IS NULL AND d.created_by = v_uid
                     AND public.fn_book_draft_creator_library(d.id, d.created_by) IS NULL ) ) IS NOT TRUE) THEN
    RETURN false;
  END IF;
  IF p_all_kinds THEN
    IF EXISTS (
         SELECT 1 FROM public.exemplar_drafts x
          WHERE x.batch_id = p_batch_id AND x.status IN ('draft', 'ready') AND x.book_draft_id IS NULL
            AND ( coalesce(x.target_library_id,
                           public.fn_exemplar_draft_fallback_library(x.book_draft_id, x.import_staging_row_id, x.created_by)) = ANY (v_staff)
                  OR ( x.target_library_id IS NULL AND x.created_by = v_uid
                       AND public.fn_exemplar_draft_fallback_library(x.book_draft_id, x.import_staging_row_id, x.created_by) IS NULL ) ) IS NOT TRUE) THEN
      RETURN false;
    END IF;
    IF EXISTS (SELECT 1 FROM public.author_drafts a
                WHERE a.batch_id = p_batch_id AND a.status IN ('draft', 'ready')
                  AND a.created_by IS DISTINCT FROM v_uid) THEN
      RETURN false;
    END IF;
  END IF;
  RETURN true;
END;
$function$;

-- Un lot est-il « à nous » pour le VOIR ? Qu'on l'ait créé, qu'une collègue
-- d'une de nos bibliothèques l'ait créé (un lot vide se prépare à plusieurs),
-- ou qu'il porte au moins un brouillon (quel que soit son statut) de nos
-- bibliothèques. catalog_batches.created_by est figé (tg_drafts_created_by_frozen).
-- L'administration : tous. Staff actif exigé.
CREATE OR REPLACE FUNCTION public.fn_caller_can_see_batch(p_batch_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff uuid[];
BEGIN
  IF public.fn_caller_is_network_admin() THEN RETURN true; END IF;
  v_staff := public.fn_caller_staff_library_ids();
  IF cardinality(v_staff) = 0 THEN RETURN false; END IF;
  IF EXISTS (SELECT 1 FROM public.catalog_batches b
              WHERE b.id = p_batch_id
                AND ( b.created_by = auth.uid()
                      -- (pas le lot d'un compte d'administration, même staff ici :
                      -- ses lots d'import — dépôts, rapprochements, runs purgés —
                      -- ne se reconnaissent pas tous ; l'administration CONFIE un
                      -- lot en en changeant le créateur, tg_drafts_created_by_frozen)
                      OR ( EXISTS (SELECT 1 FROM public.user_library_memberships m
                                    WHERE m.user_id = b.created_by AND m.status = 'active'
                                      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
                                      AND m.library_id = ANY (v_staff))
                           AND NOT EXISTS (SELECT 1 FROM public.network_administrators na
                                            WHERE na.user_id = b.created_by AND na.status = 'active') ) )) THEN
    RETURN true;
  END IF;
  RETURN EXISTS (SELECT 1 FROM public.book_drafts d
                  WHERE d.batch_id = p_batch_id
                    AND coalesce(d.owner_library_id, public.fn_book_draft_creator_library(d.id, d.created_by)) = ANY (v_staff))
      OR EXISTS (SELECT 1 FROM public.exemplar_drafts x
                  WHERE x.batch_id = p_batch_id
                    -- un exemplaire importé sans cible suit sa notice, du même
                    -- lot, déjà lue ci-dessus
                    AND (x.book_draft_id IS NULL OR x.target_library_id IS NOT NULL)
                    AND coalesce(x.target_library_id,
                                 public.fn_exemplar_draft_fallback_library(x.book_draft_id, x.import_staging_row_id, x.created_by)) = ANY (v_staff));
END;
$function$;

-- Un lot est-il ENTIÈREMENT à nous ? Tous ses brouillons de notice et
-- d'exemplaire EN COURS (hors exemplaires importés, qui suivent leur notice)
-- dans nos bibliothèques ; un lot sans brouillon en cours : à qui le voit
-- (fn_caller_can_see_batch). Fiches publiées et corbeille ne comptent pas :
-- une réattribution les laisse où elles sont (IMP-20 c), et supprimer le lot
-- ne fait que détacher la corbeille (ON DELETE SET NULL). Sert à lire son
-- rapport et ses tours de révision, à y ranger un brouillon, à le supprimer
-- (un lot mixte en cours : l'administration).
CREATE OR REPLACE FUNCTION public.fn_caller_owns_batch(p_batch_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff uuid[];
  v_uid uuid := auth.uid();
BEGIN
  IF public.fn_caller_is_network_admin() THEN RETURN true; END IF;
  v_staff := public.fn_caller_staff_library_ids();
  IF cardinality(v_staff) = 0 THEN RETURN false; END IF;
  -- (Un lot sans brouillon EN COURS — tout publié, ou plus que sa corbeille —
  -- est « vide » : à qui le voit — créateur, collègue, ou bibliothèque d'un de
  -- ses brouillons, publiés et jetés compris.)
  IF NOT EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.batch_id = p_batch_id AND d.status IN ('draft', 'ready'))
     AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x WHERE x.batch_id = p_batch_id AND x.status IN ('draft', 'ready')
                                                              AND x.book_draft_id IS NULL) THEN
    -- … sauf si le lot porte des fiches PUBLIÉES d'une autre bibliothèque :
    -- c'est alors le lot d'autrui, entièrement publié (la corbeille, elle,
    -- ne compte toujours pas).
    RETURN public.fn_caller_can_see_batch(p_batch_id)
       AND NOT EXISTS (
             SELECT 1 FROM public.book_drafts d
              WHERE d.batch_id = p_batch_id AND d.status = 'published'
                AND ( coalesce(d.owner_library_id, public.fn_book_draft_creator_library(d.id, d.created_by)) = ANY (v_staff)
                      OR ( d.owner_library_id IS NULL AND d.created_by = v_uid
                           AND public.fn_book_draft_creator_library(d.id, d.created_by) IS NULL ) ) IS NOT TRUE)
       AND NOT EXISTS (
             SELECT 1 FROM public.exemplar_drafts x
              WHERE x.batch_id = p_batch_id AND x.status = 'published' AND x.book_draft_id IS NULL
                AND ( coalesce(x.target_library_id,
                               public.fn_exemplar_draft_fallback_library(x.book_draft_id, x.import_staging_row_id, x.created_by)) = ANY (v_staff)
                      OR ( x.target_library_id IS NULL AND x.created_by = v_uid
                           AND public.fn_exemplar_draft_fallback_library(x.book_draft_id, x.import_staging_row_id, x.created_by) IS NULL ) ) IS NOT TRUE);
  END IF;
  RETURN NOT EXISTS (
           SELECT 1 FROM public.book_drafts d
            WHERE d.batch_id = p_batch_id AND d.status IN ('draft', 'ready')
              AND ( coalesce(d.owner_library_id, public.fn_book_draft_creator_library(d.id, d.created_by)) = ANY (v_staff)
                    OR ( d.owner_library_id IS NULL AND d.created_by = v_uid
                         AND public.fn_book_draft_creator_library(d.id, d.created_by) IS NULL ) ) IS NOT TRUE)
     AND NOT EXISTS (
           SELECT 1 FROM public.exemplar_drafts x
            WHERE x.batch_id = p_batch_id AND x.status IN ('draft', 'ready')
              AND x.book_draft_id IS NULL   -- un exemplaire importé suit sa notice (le rapport signale justement celui qui vise une autre bibliothèque)
              AND ( coalesce(x.target_library_id,
                             public.fn_exemplar_draft_fallback_library(x.book_draft_id, x.import_staging_row_id, x.created_by)) = ANY (v_staff)
                    OR ( x.target_library_id IS NULL AND x.created_by = v_uid
                         AND public.fn_exemplar_draft_fallback_library(x.book_draft_id, x.import_staging_row_id, x.created_by) IS NULL ) ) IS NOT TRUE);
END;
$function$;

-- Coordonne-t-on ce lot ? Pour le SUPPRIMER (avec sa corbeille) et en demander
-- la RÉVISION : même porte que la suppression définitive d'un brouillon — la
-- coordination DE sa bibliothèque, pas une coordination quelconque. Lot créé
-- par soi, par une collègue d'une bibliothèque qu'on coordonne (pas un compte
-- de l'administration), ou qui porte un brouillon (tout statut)
-- d'une bibliothèque qu'on coordonne. L'administration : tous.
CREATE OR REPLACE FUNCTION public.fn_caller_coordinates_batch(p_batch_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_coord uuid[];
BEGIN
  IF public.fn_caller_is_network_admin() THEN RETURN true; END IF;
  v_coord := public.fn_caller_coordinator_library_ids();
  IF cardinality(v_coord) = 0 THEN RETURN false; END IF;
  IF EXISTS (SELECT 1 FROM public.catalog_batches b
              WHERE b.id = p_batch_id
                AND ( b.created_by = auth.uid()
                      OR ( EXISTS (SELECT 1 FROM public.user_library_memberships m
                                    WHERE m.user_id = b.created_by AND m.status = 'active'
                                      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
                                      AND m.library_id = ANY (v_coord))
                           AND NOT EXISTS (SELECT 1 FROM public.network_administrators na
                                            WHERE na.user_id = b.created_by AND na.status = 'active') ) )) THEN
    RETURN true;
  END IF;
  RETURN EXISTS (SELECT 1 FROM public.book_drafts d
                  WHERE d.batch_id = p_batch_id
                    AND coalesce(d.owner_library_id, public.fn_book_draft_creator_library(d.id, d.created_by)) = ANY (v_coord))
      OR EXISTS (SELECT 1 FROM public.exemplar_drafts x
                  WHERE x.batch_id = p_batch_id
                    AND (x.book_draft_id IS NULL OR x.target_library_id IS NOT NULL)
                    AND coalesce(x.target_library_id,
                                 public.fn_exemplar_draft_fallback_library(x.book_draft_id, x.import_staging_row_id, x.created_by)) = ANY (v_coord));
END;
$function$;

DO $droits$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.fn_caller_staff_library_ids()',
    'public.fn_caller_coordinator_library_ids()',
    'public.fn_caller_staff_library()',
    'public.fn_book_draft_creator_library(bigint, uuid)',
    'public.fn_exemplar_draft_fallback_library(bigint, bigint, uuid)',
    'public.fn_caller_can_edit_draft_library(uuid, uuid)',
    'public.fn_caller_can_edit_book_draft(bigint)',
    'public.fn_caller_can_edit_exemplar_draft(bigint)',
    'public.fn_caller_can_edit_author_draft(bigint)',
    'public.fn_caller_can_edit_batch(bigint, boolean)',
    'public.fn_caller_can_see_batch(bigint)',
    'public.fn_caller_owns_batch(bigint)',
    'public.fn_caller_coordinates_batch(bigint)'
  ] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', f);
  END LOOP;
  -- Ces deux-là répondent pour n'importe quel brouillon ou quelle personne :
  -- appelées seulement depuis des fonctions DEFINER, fermées aux comptes
  -- connectés (pas d'oracle d'existence ou d'adhésion).
  FOREACH f IN ARRAY ARRAY[
    'public.fn_user_staff_library(uuid)',
    'public.fn_book_draft_library(bigint)'
  ] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
  END LOOP;
END
$droits$;

-- ── 3. created_by : posé à l'INSERT, figé à l'UPDATE (par l'API) ──────────
-- La bibliothèque d'un brouillon sans owner est celle de son créateur, et une
-- autorité ne s'écrit que par qui l'a créée : created_by ne doit ni se forger
-- ni se réécrire. BookDraftForm le renvoyait à chaque enregistrement (le
-- dernier à enregistrer devenait « créateur »). Dans une fonction SECURITY
-- DEFINER, current_user est son propriétaire : rien ne change pour elles.
CREATE OR REPLACE FUNCTION public.tg_drafts_created_by_frozen()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  -- L'administration peut CONFIER un lot (créé sans adhésion de staff, il ne
  -- serait visible de personne d'autre) : created_by = un membre du staff.
  IF TG_OP = 'UPDATE' AND TG_TABLE_NAME = 'catalog_batches' AND public.fn_caller_is_network_admin() THEN
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
REVOKE EXECUTE ON FUNCTION public.tg_drafts_created_by_frozen() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS book_drafts_created_by_frozen ON public.book_drafts;
CREATE TRIGGER book_drafts_created_by_frozen
  BEFORE INSERT OR UPDATE OF created_by ON public.book_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_drafts_created_by_frozen();
DROP TRIGGER IF EXISTS exemplar_drafts_created_by_frozen ON public.exemplar_drafts;
CREATE TRIGGER exemplar_drafts_created_by_frozen
  BEFORE INSERT OR UPDATE OF created_by ON public.exemplar_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_drafts_created_by_frozen();
DROP TRIGGER IF EXISTS author_drafts_created_by_frozen ON public.author_drafts;
CREATE TRIGGER author_drafts_created_by_frozen
  BEFORE INSERT OR UPDATE OF created_by ON public.author_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_drafts_created_by_frozen();

-- Le créateur d'un lot ne se réécrit pas non plus : il décide de la
-- visibilité d'un lot vide (fn_caller_can_see_batch, fn_caller_owns_batch).
DROP TRIGGER IF EXISTS catalog_batches_created_by_frozen ON public.catalog_batches;
CREATE TRIGGER catalog_batches_created_by_frozen
  BEFORE INSERT OR UPDATE OF created_by ON public.catalog_batches
  FOR EACH ROW EXECUTE FUNCTION public.tg_drafts_created_by_frozen();

-- ── 3 bis. La bibliothèque d'un brouillon se FIXE à sa création ──────────
-- Déduite à chaque lecture de l'adhésion ACTUELLE du créateur, elle
-- changerait avec elle : un compte de mutirão révoqué ferait perdre ses
-- brouillons à la bibliothèque hôte. Par l'API, une notice sans
-- bibliothèque reçoit celle de son créateur (son adhésion de staff active,
-- principale d'abord) ; un exemplaire SAISI (ni importé ni rapproché), de
-- même. Une bibliothèque posée ne s'efface pas par l'API (la vider garde
-- l'ancienne). Les fonctions SECURITY DEFINER (imports, reprises) posent la
-- leur elles-mêmes.
CREATE OR REPLACE FUNCTION public.tg_drafts_library_fixed()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  -- À l'UPDATE, la bibliothèque RÉSOLUE du brouillon tel qu'il était (celle de
  -- son créateur, ou aucune : dépôt d'une compagne non admise), jamais celle de
  -- qui enregistre ; à l'INSERT, celle de qui crée.
  IF TG_TABLE_NAME = 'book_drafts' THEN
    IF NEW.owner_library_id IS NULL THEN
      IF TG_OP = 'UPDATE' THEN
        NEW.owner_library_id := coalesce(OLD.owner_library_id,
                                         public.fn_book_draft_creator_library(OLD.id, OLD.created_by));
      ELSE
        NEW.owner_library_id := public.fn_caller_staff_library();
      END IF;
      IF NEW.owner_library_id IS NOT NULL AND nullif(btrim(coalesce(NEW.owner_library, '')), '') IS NULL THEN
        NEW.owner_library := (SELECT l.name FROM public.libraries l WHERE l.id = NEW.owner_library_id);
      END IF;
    END IF;
  ELSIF NEW.book_draft_id IS NULL AND NEW.import_staging_row_id IS NULL AND NEW.target_library_id IS NULL THEN
    IF TG_OP = 'UPDATE' THEN
      NEW.target_library_id := coalesce(OLD.target_library_id,
                                        public.fn_exemplar_draft_fallback_library(OLD.book_draft_id, OLD.import_staging_row_id, OLD.created_by));
    ELSE
      NEW.target_library_id := public.fn_caller_staff_library();
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.tg_drafts_library_fixed() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS book_drafts_library_fixed ON public.book_drafts;
CREATE TRIGGER book_drafts_library_fixed
  BEFORE INSERT OR UPDATE OF owner_library_id ON public.book_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_drafts_library_fixed();
DROP TRIGGER IF EXISTS exemplar_drafts_library_fixed ON public.exemplar_drafts;
CREATE TRIGGER exemplar_drafts_library_fixed
  BEFORE INSERT OR UPDATE OF target_library_id ON public.exemplar_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_drafts_library_fixed();

-- ── 3 ter. Ranger un brouillon dans un lot, c'est y ajouter du travail ────
-- Par l'API, on ne range un brouillon que dans un lot ENTIÈREMENT à soi
-- (fn_caller_owns_batch : tous ses brouillons en cours et publiés ; un lot
-- vide, s'il est à soi ou à une collègue) : ranger les siens dans le
-- lot d'une autre bibliothèque — même vide, même publié — le rendait mixte, et
-- elle ne pouvait plus ni le publier, ni le réviser, ni le supprimer.
CREATE OR REPLACE FUNCTION public.tg_drafts_batch_guarded()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cle text;
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF NEW.batch_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.batch_id IS NOT DISTINCT FROM OLD.batch_id THEN
    -- Sortie de corbeille DANS le lot : la corbeille ne compte pas pour savoir
    -- à qui est un lot (fn_caller_owns_batch) ; restaurée dans un lot qui n'est
    -- plus à soi (réattribué, IMP-20 c), elle le rendrait mixte. Le brouillon
    -- revient, mais hors du lot. (Un exemplaire importé suit sa notice.)
    IF OLD.status = 'cancelled' AND NEW.status IS DISTINCT FROM 'cancelled'
       AND TG_TABLE_NAME IN ('book_drafts', 'exemplar_drafts') THEN
      IF TG_TABLE_NAME = 'exemplar_drafts' THEN
        IF NEW.book_draft_id IS NOT NULL THEN RETURN NEW; END IF;
      END IF;
      IF NOT public.fn_caller_owns_batch(NEW.batch_id) THEN
        NEW.batch_id := NULL;
      END IF;
    END IF;
    RETURN NEW;
  END IF;
  -- Un verdict favorable vaut pour la transaction : les politiques ne laissent
  -- ranger que ses propres brouillons, le lot reste donc « à soi ». Sans cela,
  -- ranger 200 brouillons dans un lot de 1 800 relisait 200 fois le lot (0,5 s).
  v_cle := 'anarbib.b29_lot_' || NEW.batch_id;
  IF current_setting(v_cle, true) = coalesce(auth.uid()::text, '-') THEN
    RETURN NEW;
  END IF;
  IF NOT public.fn_caller_owns_batch(NEW.batch_id) THEN
    RAISE EXCEPTION 'Lote com rascunhos de outras bibliotecas.'
      USING ERRCODE = '42501', HINT = 'error.batch.other_libraries';
  END IF;
  PERFORM set_config(v_cle, coalesce(auth.uid()::text, '-'), true);
  RETURN NEW;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.tg_drafts_batch_guarded() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS book_drafts_batch_guarded ON public.book_drafts;
CREATE TRIGGER book_drafts_batch_guarded
  BEFORE INSERT OR UPDATE OF batch_id, status ON public.book_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_drafts_batch_guarded();
DROP TRIGGER IF EXISTS exemplar_drafts_batch_guarded ON public.exemplar_drafts;
CREATE TRIGGER exemplar_drafts_batch_guarded
  BEFORE INSERT OR UPDATE OF batch_id, status ON public.exemplar_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_drafts_batch_guarded();
DROP TRIGGER IF EXISTS author_drafts_batch_guarded ON public.author_drafts;
CREATE TRIGGER author_drafts_batch_guarded
  BEFORE INSERT OR UPDATE OF batch_id ON public.author_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_drafts_batch_guarded();

-- ── 4. Les fonctions SECURITY DEFINER prennent la même règle ─────────────
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
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) THEN
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
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) THEN
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
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) THEN
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
      variant_forms, photo_object_path, notes, structured_meta, writing_language,
      created_by, updated_by, updated_at
    )
    values (
      v_draft.preferred_name, v_draft.sort_name, v_draft.biography,
      v_draft.birth_year, v_draft.death_year, v_draft.country,
      v_draft.source_kind, v_draft.source_label, v_draft.source_url,
      v_draft.viaf_id, v_draft.isni, v_draft.wikidata_id,
      v_draft.variant_forms, v_draft.photo_object_path, v_draft.notes,
      coalesce(v_draft.structured_meta, '{}'::jsonb), v_draft.writing_language,
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
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.' USING HINT = 'error.catalog.staff_only';
  END IF;
  if not exists (
    select 1
    from public.catalog_batches
    where id = p_batch_id
      and status = 'open'
  ) then
    raise exception 'Lote inválido ou já fechado: %', p_batch_id;
  end if;
  -- B29 (CAT-E18) : publier un lot, c'est publier TOUS ses brouillons (et le
  -- clore) ; qui ne voit pas le lot, ou ne peut pas modifier tous ses
  -- brouillons, ne le publie pas — l'administration du réseau le peut. Deux
  -- refus distincts : autre bibliothèque, ou autorités d'une autre personne.
  if not (public.fn_caller_can_see_batch(p_batch_id) and public.fn_caller_can_edit_batch(p_batch_id, false)) then
    raise exception 'Lote com rascunhos de outras bibliotecas.' using hint = 'error.batch.other_libraries';
  end if;
  if not public.fn_caller_can_edit_batch(p_batch_id, true) then
    if exists (select 1 from public.author_drafts a
                where a.batch_id = p_batch_id and a.status in ('draft', 'ready')
                  and a.created_by is distinct from auth.uid()) then
      raise exception 'Lote com autoridades de outras pessoas.' using hint = 'error.batch.other_authors';
    end if;
    raise exception 'Lote com rascunhos de outras bibliotecas.' using hint = 'error.batch.other_libraries';
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

CREATE OR REPLACE FUNCTION api.merge_book_drafts(p_survivor_id bigint, p_loser_id bigint, p_fields jsonb DEFAULT '{}'::jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_surv public.book_drafts%rowtype;
  v_lose public.book_drafts%rowtype;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING HINT = 'error.merge.staff_only';
  END IF;

  IF p_survivor_id = p_loser_id THEN
    RAISE EXCEPTION 'Sobrevivente e duplicado identicos.'
      USING HINT = 'error.merge.same_draft';
  END IF;

  SELECT * INTO v_surv FROM public.book_drafts WHERE id = p_survivor_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rascunho sobrevivente % inexistente.', p_survivor_id
      USING HINT = 'error.merge.draft_not_found';
  END IF;
  SELECT * INTO v_lose FROM public.book_drafts WHERE id = p_loser_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rascunho duplicado % inexistente.', p_loser_id
      USING HINT = 'error.merge.draft_not_found';
  END IF;
  -- B29 (CAT-E18) : les deux brouillons doivent être modifiables par l'appelant
  -- — avant le contrôle de statut, qui renseignerait sur celui d'autrui.
  IF NOT coalesce(public.fn_caller_can_edit_book_draft(p_survivor_id), false)
     OR NOT coalesce(public.fn_caller_can_edit_book_draft(p_loser_id), false) THEN
    RAISE EXCEPTION 'Rascunho de outra biblioteca.' USING HINT = 'error.catalog.draft_other_library';
  END IF;
  IF v_surv.status NOT IN ('draft', 'ready') OR v_lose.status NOT IN ('draft', 'ready') THEN
    RAISE EXCEPTION 'Ambos os rascunhos devem estar na fila.'
      USING HINT = 'error.merge.draft_not_in_queue';
  END IF;
  IF public.fn_book_draft_library(p_survivor_id) IS DISTINCT FROM public.fn_book_draft_library(p_loser_id) THEN   -- B29
    RAISE EXCEPTION 'Rascunhos de bibliotecas diferentes nao podem ser fundidos.'
      USING HINT = 'error.merge.cross_library';
  END IF;

  UPDATE public.book_drafts SET
    titulo    = COALESCE(p_fields->>'titulo',    titulo),
    subtitulo = COALESCE(p_fields->>'subtitulo', subtitulo),
    autor     = COALESCE(p_fields->>'autor',     autor),
    isbn      = COALESCE(p_fields->>'isbn',      isbn),
    ano       = COALESCE(p_fields->>'ano',       ano),
    editora   = COALESCE(p_fields->>'editora',   editora),
    cdd       = COALESCE(p_fields->>'cdd',       cdd),
    colecao   = COALESCE(p_fields->>'colecao',   colecao),
    idioma    = COALESCE(p_fields->>'idioma',    idioma),
    updated_by = auth.uid(), updated_at = now()
  WHERE id = p_survivor_id;

  IF v_lose.bib_ref IS NOT NULL AND v_surv.bib_ref IS NOT NULL THEN
    UPDATE public.exemplar_drafts SET
      target_bib_ref = v_surv.bib_ref, updated_at = now()
    WHERE batch_id IS NOT DISTINCT FROM v_lose.batch_id
      AND target_bib_ref = v_lose.bib_ref
      AND coalesce(public.fn_caller_can_edit_exemplar_draft(id), false);   -- B29
  END IF;

  -- H19 (27/09/2026) : les exemplaires importés du perdant (rattachés par
  -- book_draft_id, sans target_bib_ref avant publication : la réécriture
  -- ci-dessus ne les voit pas) passent au survivant, dans son lot. Sans cela
  -- l'écart du perdant les emportait avec lui.
  UPDATE public.exemplar_drafts SET
    book_draft_id = p_survivor_id, batch_id = v_surv.batch_id, updated_at = now()
  WHERE book_draft_id = p_loser_id AND status IN ('draft', 'ready');

  UPDATE public.book_drafts SET
    status = 'cancelled', updated_by = auth.uid(), updated_at = now()
  WHERE id = p_loser_id;

  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('book_draft', p_survivor_id, p_loser_id,
          jsonb_build_object('scenario', 'draft_into_draft',
                             'fields', COALESCE(p_fields, '{}'::jsonb)),
          auth.uid());

  RETURN p_survivor_id;
END;
$function$;

CREATE OR REPLACE FUNCTION api.merge_draft_into_book(p_draft_id bigint, p_book_id bigint, p_fields jsonb DEFAULT '{}'::jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_draft         public.book_drafts%rowtype;
  v_book_bib_ref  text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING HINT = 'error.merge.staff_only';
  END IF;

  SELECT * INTO v_draft FROM public.book_drafts WHERE id = p_draft_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rascunho % inexistente.', p_draft_id
      USING HINT = 'error.merge.draft_not_found';
  END IF;
  -- B29 (CAT-E18) : on n'absorbe que ses propres brouillons — avant le
  -- contrôle de statut, qui renseignerait sur celui d'autrui.
  IF NOT coalesce(public.fn_caller_can_edit_book_draft(p_draft_id), false) THEN
    RAISE EXCEPTION 'Rascunho de outra biblioteca.' USING HINT = 'error.catalog.draft_other_library';
  END IF;
  IF v_draft.status NOT IN ('draft', 'ready') THEN
    RAISE EXCEPTION 'Rascunho % nao esta na fila (status=%).', p_draft_id, v_draft.status
      USING HINT = 'error.merge.draft_not_in_queue';
  END IF;

  SELECT bib_ref INTO v_book_bib_ref FROM public.books WHERE id = p_book_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Livro % inexistente.', p_book_id
      USING HINT = 'error.merge.book_not_found';
  END IF;

  UPDATE public.books SET
    titulo    = COALESCE(p_fields->>'titulo',    titulo),
    subtitulo = COALESCE(p_fields->>'subtitulo', subtitulo),
    autor     = COALESCE(p_fields->>'autor',     autor),
    isbn      = COALESCE(p_fields->>'isbn',      isbn),
    ano       = COALESCE(p_fields->>'ano',       ano),
    editora   = COALESCE(p_fields->>'editora',   editora),
    cdd       = COALESCE(p_fields->>'cdd',       cdd),
    colecao   = COALESCE(p_fields->>'colecao',   colecao),
    idioma    = COALESCE(p_fields->>'idioma',    idioma),
    updated_by = auth.uid(), updated_at = now(), last_cataloged_at = now()
  WHERE id = p_book_id;

  -- H19 (27/09/2026) : les exemplaires importés du brouillon absorbé vont sur
  -- la fiche existante, comme ceux d'un rapprochement : sans notice
  -- (book_draft_id nul), avec la référence de la fiche ; leur bibliothèque et
  -- leur ligne importée restent (publish_exemplar_draft exige alors une
  -- bibliothèque, et d'en être staff). Sans cela l'écart du brouillon les
  -- emportait avec lui.
  UPDATE public.exemplar_drafts SET
    book_draft_id = NULL, target_bib_ref = v_book_bib_ref, target_holding_id = NULL, updated_at = now()
  WHERE book_draft_id = p_draft_id AND status IN ('draft', 'ready');

  UPDATE public.book_drafts SET
    published_book_id = p_book_id,
    bib_ref           = COALESCE(bib_ref, v_book_bib_ref),
    action            = 'update',
    status            = 'cancelled',
    updated_by = auth.uid(), updated_at = now()
  WHERE id = p_draft_id;

  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('book_draft', p_book_id, p_draft_id,
          jsonb_build_object('scenario', 'draft_into_book',
                             'fields', COALESCE(p_fields, '{}'::jsonb)),
          auth.uid());

  RETURN p_book_id;
END;
$function$;

CREATE OR REPLACE FUNCTION api.suggest_draft_duplicates(p_draft_id bigint)
 RETURNS TABLE(candidate_id bigint, source text, titulo text, subtitulo text, autor text, ano text, editora text, isbn text, cdd text, colecao text, idioma text, tipo_material text, match_kind text, score real)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
declare v_isbn text; v_title text; v_author text; v_lib uuid; v_pub bigint; v_work bigint;
        v_ano text; v_editora text; v_edicao text;
        v_admin boolean; v_staff uuid[];   -- B29
begin
  if not exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role=any(array['librarian'::text,'coordenador'::text])) then
    raise exception 'Acesso restrito ao staff de catalogacao.'; end if;
  select regexp_replace(upper(coalesce(d.isbn,'')),'[^0-9X]','','g'), public.fn_normalize_name(d.titulo), public.fn_normalize_name(d.autor), d.owner_library_id, d.published_book_id,
         d.ano, d.editora, d.edicao
    into v_isbn, v_title, v_author, v_lib, v_pub, v_ano, v_editora, v_edicao from public.book_drafts d where d.id=p_draft_id;
  if v_title is null then return; end if;
  -- B29 (CAT-E18) : rien pour un brouillon d'une autre bibliothèque ; et les
  -- candidats « brouillon » se limitent à ceux que l'appelant peut voir.
  if not coalesce(public.fn_caller_can_edit_book_draft(p_draft_id), false) then return; end if;
  v_admin := public.fn_caller_is_network_admin();
  v_staff := public.fn_caller_staff_library_ids();
  select b.work_id into v_work from public.books b where b.id = v_pub;
  return query
  with cand as (
    select d.id as cid,'draft'::text as src,d.titulo,d.subtitulo,d.autor,d.ano,d.editora,d.isbn,d.cdd,d.colecao,d.idioma,d.tipo_material,
           null::bigint as cwork, d.edicao as cedicao,
           regexp_replace(upper(coalesce(d.isbn,'')),'[^0-9X]','','g') as ni, public.fn_normalize_name(d.titulo) as nt, public.fn_normalize_name(d.autor) as na
    from public.book_drafts d where d.status='draft' and d.id<>p_draft_id and (v_lib is null or d.owner_library_id=v_lib)
      and (v_admin or coalesce(d.owner_library_id, public.fn_book_draft_creator_library(d.id, d.created_by)) = any(v_staff))
    union all
    select b.id,'book'::text,b.titulo,b.subtitulo,b.autor,b.ano,b.editora,b.isbn,b.cdd,b.colecao,b.idioma,b.tipo_material,
           b.work_id, b.edicao,
           regexp_replace(upper(coalesce(b.isbn,'')),'[^0-9X]','','g'), public.fn_normalize_name(b.titulo), public.fn_normalize_name(b.autor)
    from public.books b where b.id is distinct from v_pub)
  select c.cid,c.src,c.titulo,c.subtitulo,c.autor,c.ano,c.editora,c.isbn,c.cdd,c.colecao,c.idioma,c.tipo_material,
         case when v_isbn<>'' and c.ni=v_isbn then 'isbn' else 'approx' end,
         case when v_isbn<>'' and c.ni=v_isbn then 1.0::real else similarity(c.nt,v_title)::real end
  from cand c
  where c.nt<>''
    and not ( c.src='book' and v_pub is not null and exists (select 1 from public.book_not_duplicate nd where nd.book_id_a=least(v_pub,c.cid) and nd.book_id_b=greatest(v_pub,c.cid)) )
    -- P4 raffine (31/08) : meme oeuvre que le livre du brouillon = edition
    -- SEULEMENT si un champ d'edition les distingue vraiment.
    and not ( c.src='book' and v_work is not null and c.cwork = v_work
              and public.fn_editions_distinctes(v_isbn, c.isbn, v_ano, c.ano, v_editora, c.editora, v_edicao, c.cedicao) )
    and ( (v_isbn<>'' and c.ni=v_isbn)
       or ( similarity(c.nt,v_title)>=0.5 and (v_author='' or c.na='' or similarity(c.na,v_author)>=0.4)
            and not (v_isbn<>'' and c.ni<>'' and c.ni<>v_isbn) ) )
  order by 14 desc, c.src, c.titulo limit 50;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_batch_caller_can_edit(p_batch_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  -- B29 (CAT-E18, 27/09/2026) : agir sur un lot (numéroter, classer, lire ses
  -- rubriques), c'est agir sur TOUS ses brouillons vivants. L'administration du
  -- réseau, ou qui peut les modifier tous ; un lot vide, comme avant, à la
  -- coordination. (Avant : staff de la bibliothèque d'UN brouillon suffisait,
  -- et un lot mixte se laissait numéroter par l'une de ses bibliothèques.)
  select public.fn_caller_is_network_admin()
      or ( public.fn_caller_can_see_batch(p_batch_id)
           and public.fn_caller_can_edit_batch(p_batch_id, false)
           and ( exists (select 1 from public.book_drafts d
                          where d.batch_id = p_batch_id and d.status in ('draft', 'ready'))
                 or public.fn_is_catalog_coordinator() ) );
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

  select * into v_batch from public.catalog_batches where id = p_batch_id;
  if not found then
    raise exception 'Lote % introuvable', p_batch_id using hint = 'error.review.batch_not_found';
  end if;
  -- B29 (CAT-E18) : le rapport montre tous les brouillons du lot (titres,
  -- contributeurs, codes d'exemplaires), publiés compris ; il est à qui
  -- possède tout le lot (fn_caller_owns_batch), ou à l'administration.
  if not public.fn_caller_owns_batch(p_batch_id) then
    raise exception 'Lote com rascunhos de outras bibliotecas.' using hint = 'error.batch.other_libraries';
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
      'imported', public.fn_batch_is_imported(p_batch_id),
      'drafts_active', (select count(*) from public.fn_batch_live_drafts(p_batch_id)),
      'drafts_published', (select count(*) from public.book_drafts where batch_id = p_batch_id and status = 'published'),
      'drafts_cancelled', (select count(*) from public.book_drafts where batch_id = p_batch_id and status = 'cancelled'),
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
  if not (public.fn_caller_is_network_admin()
          or exists (select 1 from public.user_library_memberships m
                      where m.user_id = auth.uid() and m.status = 'active'
                        and m.role = 'coordenador')) then
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
  -- B29 (CAT-E18) : on ne demande la révision que d'un lot entièrement à soi
  -- (ses tours de révision se lisent sous la même règle), et qu'on COORDONNE
  -- (la coordination de sa bibliothèque, pas une coordination quelconque).
  if not public.fn_caller_owns_batch(p_batch_id) then
    raise exception 'Lote com rascunhos de outras bibliotecas.' using hint = 'error.batch.other_libraries';
  end if;
  if not public.fn_caller_coordinates_batch(p_batch_id) then
    raise exception 'Acesso restrito ao coordenador da biblioteca.' using hint = 'error.review.coordenador_only';
  end if;

  v_last := public.fn_batch_review_status(p_batch_id);
  if v_last = 'requested' then
    raise exception 'Revisao ja pedida para o lote %', p_batch_id using hint = 'error.review.already_requested';
  end if;
  if v_last = 'approved' then
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

CREATE OR REPLACE FUNCTION public.fn_batch_reviews_list()
 RETURNS TABLE(batch_id bigint, batch_name text, batch_status text, imported boolean, review_id bigint, round integer, status text, requested_by uuid, requester_name text, requested_at timestamp with time zone, coord_message text, reviewed_by uuid, reviewer_name text, reviewed_at timestamp with time zone, admin_notes text, report jsonb, report_generated_at timestamp with time zone, drafts_active bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest'
AS $function$
  select b.id, b.name, b.status,
         public.fn_batch_is_imported(b.id),
         r.id, r.round, r.status,
         r.requested_by,
         nullif(btrim(concat_ws(' ', pq.first_name, pq.last_name)), ''),
         r.requested_at, r.coord_message,
         r.reviewed_by,
         nullif(btrim(concat_ws(' ', pv.first_name, pv.last_name)), ''),
         r.reviewed_at, r.admin_notes,
         -- B29 : l'instantané du rapport montre tout le lot : à qui le possède entier.
         case when public.fn_caller_owns_batch(b.id) then r.report end, r.report_generated_at,
         (select count(*) from public.book_drafts d where d.batch_id = b.id and d.status in ('draft', 'ready'))
    from public.catalog_batches b
    left join lateral (
      select * from public.catalog_batch_reviews x
       where x.batch_id = b.id order by x.round desc limit 1
    ) r on true
    left join public.profiles pq on pq.id = r.requested_by
    left join public.profiles pv on pv.id = r.reviewed_by
   where b.status <> 'archived'
     and public.fn_caller_can_see_batch(b.id)   -- B29 : les lots où l'on a des brouillons (admin : tous)
   order by (r.status = 'requested') desc nulls last, r.requested_at desc nulls last, b.created_at desc;
$function$;

CREATE OR REPLACE FUNCTION public.fn_batch_owner_libraries()
 RETURNS TABLE(batch_id bigint, library_id uuid, library_name text, drafts bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  -- B29 (CAT-E18, 27/09/2026) : les lots où l'on a des brouillons, ou qu'on a
  -- créés (fn_caller_can_see_batch ; l'administration : tous) — avant : tous
  -- les lots pour tout staff. Calculés une fois par lot, pas par brouillon.
  with lots as materialized (
    select b.id
      from public.catalog_batches b
     where b.status <> 'archived'
       and public.fn_caller_can_see_batch(b.id)
  )
  select d.batch_id, d.owner_library_id, l.name, count(*)
    from lots
    join public.book_drafts d on d.batch_id = lots.id
    left join public.libraries l on l.id = d.owner_library_id
   where d.status in ('draft', 'ready')
   group by d.batch_id, d.owner_library_id, l.name
   order by d.batch_id, l.name nulls first;
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
           format('[%s] Lote reatribuido a biblioteca « %s » por %s (%s rascunho(s) em curso ; antes : %s).',
                  to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI UTC'),
                  v_lib.name, coalesce(v_who, '?'), v_n, coalesce(v_before, 'sem biblioteca'))),
         updated_at = now()
   WHERE id = p_batch_id;

  -- array_append, pas « || 'litteral' » : un litteral non type a droite d'un
  -- text[] est lu comme un tableau (« malformed array literal »), vu au banc.
  IF v_lib.tombo_pattern IS NULL THEN v_warnings := array_append(v_warnings, 'library_without_tombo_pattern'); END IF;
  IF NOT coalesce(v_lib.is_active, false) THEN v_warnings := array_append(v_warnings, 'library_inactive'); END IF;
  IF v_n = 0 AND v_items = 0 AND v_detached = 0 THEN v_warnings := array_append(v_warnings, 'nothing_to_do'); END IF;
  IF v_detached > 0 THEN v_warnings := array_append(v_warnings, 'items_detached'); END IF;   -- B29

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
    'warnings', to_jsonb(v_warnings)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_book_draft_destination_library(p_draft_id bigint)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog', 'pg_temp'
AS $function$
  -- Dans l'ordre : ce que le rascunho declare, puis l'adhesion ACTIVE de
  -- catalogage de qui l'a cree, puis celle de qui regarde (ou publie). Departage
  -- comme api.my_access departe l'adhesion effective — principale, anciennete —
  -- avec library_id en dernier critere pour etre DETERMINISTE.
  select coalesce(
    d.owner_library_id,
    (select ulm.library_id
       from public.user_library_memberships ulm
      where ulm.user_id = d.created_by
        and ulm.status = 'active'
        and ulm.role = any (array['librarian'::text, 'coordenador'::text])
      order by ulm.is_primary desc, ulm.created_at, ulm.library_id
      limit 1),
    (select ulm.library_id
       from public.user_library_memberships ulm
      where ulm.user_id = auth.uid()
        and ulm.status = 'active'
        and ulm.role = any (array['librarian'::text, 'coordenador'::text])
      order by ulm.is_primary desc, ulm.created_at, ulm.library_id
      limit 1)
  )
  from public.book_drafts d
  where d.id = p_draft_id
    and ((select auth.uid()) is null or public.fn_caller_can_edit_book_draft(d.id));   -- B29
$function$;

CREATE OR REPLACE FUNCTION public.fn_audit_draft_deletion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog', 'pg_temp'
AS $function$
declare
  v_entity  text;
  v_label   text;
  v_library uuid;
  v_details jsonb;
begin
  v_details := jsonb_build_object('snapshot', to_jsonb(old));

  if tg_table_name = 'book_drafts' then
    v_entity  := 'book';
    v_label   := old.titulo;
    -- B29 : la bibliothèque RÉSOLUE (celle du créateur quand owner est nul),
    -- que lit la politique du journal.
    v_library := coalesce(old.owner_library_id, public.fn_book_draft_creator_library(old.id, old.created_by));
    -- Les enfants en CASCADE : sans eux, le rejeu rendrait une coquille.
    v_details := v_details || jsonb_build_object('children', jsonb_build_object(
      'book_draft_contributors', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.book_draft_contributors c where c.draft_id = old.id), '[]'::jsonb),
      'book_draft_subjects', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.book_draft_subjects c where c.book_draft_id = old.id), '[]'::jsonb),
      'book_draft_catalog_context', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.book_draft_catalog_context c where c.book_draft_id = old.id), '[]'::jsonb),
      'book_draft_digital_resources', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.book_draft_digital_resources c where c.book_draft_id = old.id), '[]'::jsonb),
      -- H19 : ses exemplaires importés (CASCADE sur book_draft_id) ; rejoués
      -- avec elle, sinon la notice revenait sans eux et publiait l'exemplaire
      -- automatique, codes et cotes perdus.
      'exemplar_drafts', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.exemplar_drafts c where c.book_draft_id = old.id), '[]'::jsonb)
    ));
  elsif tg_table_name = 'author_drafts' then
    v_entity := 'author';
    v_label  := old.preferred_name;
  else
    -- H19 (27/09) : supprimé par CASCADE avec sa notice, il est déjà dans
    -- l'instantané de celle-ci (children.exemplar_drafts) : pas d'entrée à part.
    if old.book_draft_id is not null
       and not exists (select 1 from public.book_drafts b where b.id = old.book_draft_id) then
      return old;
    end if;
    v_entity  := 'exemplar';
    v_label   := coalesce(old.tombo, old.target_bib_ref);
    v_library := coalesce(old.target_library_id,
                          public.fn_exemplar_draft_fallback_library(old.book_draft_id, old.import_staging_row_id, old.created_by));
  end if;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, library_id, label, details)
  values (auth.uid(), 'delete', v_entity, old.id, v_library, v_label,
          v_details || jsonb_build_object('batch_id', old.batch_id, 'source_table', tg_table_name));

  return old;
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
        select coalesce(jsonb_agg(case
                 when e.v->>'import_staging_row_id' is not null
                      and not exists (select 1 from ingest.partner_catalog_staging_rows sr
                                       where sr.id = (e.v->>'import_staging_row_id')::bigint)
                 then jsonb_set(e.v, '{import_staging_row_id}', 'null'::jsonb)
                 else e.v end), '[]'::jsonb)
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
  if p_batch_id is not null and not public.fn_caller_owns_batch(p_batch_id) then
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
  if p_batch_id is not null and not public.fn_caller_owns_batch(p_batch_id) then
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
  if p_batch_id is not null and not public.fn_caller_owns_batch(p_batch_id) then
    raise exception 'Lote com rascunhos de outras bibliotecas.' using hint = 'error.batch.other_libraries';
  end if;
  insert into public.author_drafts (
    published_author_id, batch_id, action, status,
    preferred_name, sort_name, biography, birth_year, death_year, country,
    source_kind, source_label, source_url, viaf_id, isni, wikidata_id,
    variant_forms, photo_object_path, notes, structured_meta, writing_language,
    created_by, updated_by
  )
  select
    a.id, p_batch_id, 'update', 'draft',
    a.preferred_name, a.sort_name, a.biography, a.birth_year, a.death_year, a.country,
    a.source_kind, a.source_label, a.source_url, a.viaf_id, a.isni, a.wikidata_id,
    a.variant_forms, a.photo_object_path, a.notes,
    coalesce(a.structured_meta, '{}'::jsonb), a.writing_language,
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

CREATE OR REPLACE FUNCTION public.fn_import_list_run_rows(p_run_id bigint)
 RETURNS TABLE(id bigint, run_id bigint, row_no integer, external_key text, item_type text, title text, subtitle text, responsibility_statement text, authors jsonb, publisher text, place_of_publication text, publication_year text, edition_statement text, language text, isbn text, issn text, subjects jsonb, parse_status text, match_status text, review_status text, confidence numeric, warnings jsonb, editorial_decision text, editorial_note text, selected_for_draft boolean, proposed_book_id bigint, proposed_book_draft_id bigint, proposed_title text, created_book_draft_id bigint, created_exemplar_draft_id bigint, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth'
AS $function$
DECLARE
  v_actor public.my_access%rowtype;
  v_run_library_id uuid;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;

  SELECT r.library_id INTO v_run_library_id
  FROM ingest.partner_catalog_import_runs r
  WHERE r.id = p_run_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  IF v_run_library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  RETURN QUERY
  SELECT sr.id, sr.run_id, sr.row_no, sr.external_key, sr.item_type,
         sr.title, sr.subtitle, sr.responsibility_statement, sr.authors,
         sr.publisher, sr.place_of_publication, sr.publication_year,
         sr.edition_statement, sr.language, sr.isbn, sr.issn, sr.subjects,
         sr.parse_status, sr.match_status, sr.review_status,
         sr.confidence, sr.warnings,
         sr.editorial_decision, sr.editorial_note, sr.selected_for_draft,
         sr.proposed_book_id, sr.proposed_book_draft_id,
         coalesce(
           (SELECT b.titulo  FROM public.books       b  WHERE b.id  = sr.proposed_book_id),
           (SELECT bd.titulo FROM public.book_drafts bd WHERE bd.id = sr.proposed_book_draft_id
              AND coalesce(public.fn_caller_can_edit_book_draft(bd.id), false))   -- B29
         ) AS proposed_title,
         sr.created_book_draft_id,
         sr.created_exemplar_draft_id,
         sr.created_at
  FROM ingest.partner_catalog_staging_rows sr
  WHERE sr.run_id = p_run_id
  ORDER BY sr.row_no, sr.id;
END;
$function$;

-- ── 2. Les politiques ─────────────────────────────────────────────────────
-- Les noms restent (gardes CI : portee_catalogage T11) ; la portée s'ajoute.
-- Chaque appel qui ne dépend pas de la ligne est entouré de (select …) : une
-- évaluation par requête (InitPlan, garde hygiene T2) ; la bibliothèque du
-- créateur n'est cherchée que pour un brouillon sans bibliothèque (COALESCE
-- n'évalue son second terme qu'au besoin).

-- Notices.
ALTER POLICY book_drafts_catalogacao_librarian_all ON public.book_drafts
  USING (
    (SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
    AND ( (SELECT public.fn_caller_is_network_admin())
          OR coalesce(owner_library_id, public.fn_book_draft_creator_library(id, created_by))
             = ANY ((SELECT public.fn_caller_staff_library_ids())::uuid[])
          OR ( owner_library_id IS NULL AND created_by = (SELECT auth.uid())
               AND public.fn_book_draft_creator_library(id, created_by) IS NULL ) ) )
  WITH CHECK (
    (SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
    AND ( (SELECT public.fn_caller_is_network_admin())
          OR coalesce(owner_library_id, public.fn_book_draft_creator_library(id, created_by))
             = ANY ((SELECT public.fn_caller_staff_library_ids())::uuid[])
          OR ( owner_library_id IS NULL AND created_by = (SELECT auth.uid())
               AND public.fn_book_draft_creator_library(id, created_by) IS NULL ) ) );

-- Exemplaires : la cible, sinon la bibliothèque de la notice (importé), sinon
-- celle du créateur. Écrire une cible, c'est y être staff (WITH CHECK).
ALTER POLICY exemplar_drafts_catalogacao_librarian_all ON public.exemplar_drafts
  USING (
    (SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
    AND ( (SELECT public.fn_caller_is_network_admin())
          OR coalesce(target_library_id,
                      public.fn_exemplar_draft_fallback_library(book_draft_id, import_staging_row_id, created_by))
             = ANY ((SELECT public.fn_caller_staff_library_ids())::uuid[])
          OR ( target_library_id IS NULL AND created_by = (SELECT auth.uid())
               AND public.fn_exemplar_draft_fallback_library(book_draft_id, import_staging_row_id, created_by) IS NULL ) ) )
  WITH CHECK (
    (SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
    AND ( (SELECT public.fn_caller_is_network_admin())
          OR coalesce(target_library_id,
                      public.fn_exemplar_draft_fallback_library(book_draft_id, import_staging_row_id, created_by))
             = ANY ((SELECT public.fn_caller_staff_library_ids())::uuid[])
          OR ( target_library_id IS NULL AND created_by = (SELECT auth.uid())
               AND public.fn_exemplar_draft_fallback_library(book_draft_id, import_staging_row_id, created_by) IS NULL ) ) );

-- Autorités (CAT-E18 2) : lecture commune, écriture par le créateur ou l'admin.
DROP POLICY IF EXISTS author_drafts_catalogacao_librarian_all ON public.author_drafts;
DROP POLICY IF EXISTS author_drafts_catalogacao_read ON public.author_drafts;
DROP POLICY IF EXISTS author_drafts_catalogacao_insert ON public.author_drafts;
DROP POLICY IF EXISTS author_drafts_catalogacao_update ON public.author_drafts;
DROP POLICY IF EXISTS author_drafts_catalogacao_delete ON public.author_drafts;
CREATE POLICY author_drafts_catalogacao_read ON public.author_drafts
  FOR SELECT TO authenticated
  USING ((SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true)));
CREATE POLICY author_drafts_catalogacao_insert ON public.author_drafts
  FOR INSERT TO authenticated
  WITH CHECK (
    (SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
    AND ( (SELECT public.fn_caller_is_network_admin()) OR created_by = (SELECT auth.uid()) ) );
CREATE POLICY author_drafts_catalogacao_update ON public.author_drafts
  FOR UPDATE TO authenticated
  USING (
    (SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
    AND ( (SELECT public.fn_caller_is_network_admin()) OR created_by = (SELECT auth.uid()) ) )
  WITH CHECK (
    (SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
    AND ( (SELECT public.fn_caller_is_network_admin()) OR created_by = (SELECT auth.uid()) ) );
CREATE POLICY author_drafts_catalogacao_delete ON public.author_drafts
  FOR DELETE TO authenticated
  USING (
    (SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
    AND ( (SELECT public.fn_caller_is_network_admin()) OR created_by = (SELECT auth.uid()) ) );

-- Tables enfants de la notice : visibles et modifiables si la notice l'est
-- (la sous-requête sur book_drafts passe elle-même par sa politique).
ALTER POLICY book_draft_contributors_catalogacao_librarian_all ON public.book_draft_contributors
  USING (EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.id = book_draft_contributors.draft_id))
  WITH CHECK (EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.id = book_draft_contributors.draft_id));
ALTER POLICY book_draft_subjects_catalogacao_all ON public.book_draft_subjects
  USING (EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.id = book_draft_subjects.book_draft_id))
  WITH CHECK (EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.id = book_draft_subjects.book_draft_id));
ALTER POLICY book_draft_catalog_context_catalogacao_librarian_all ON public.book_draft_catalog_context
  USING (EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.id = book_draft_catalog_context.book_draft_id))
  WITH CHECK (EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.id = book_draft_catalog_context.book_draft_id));
ALTER POLICY book_draft_digital_resources_catalogacao_librarian_all ON public.book_draft_digital_resources
  USING (EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.id = book_draft_digital_resources.book_draft_id))
  WITH CHECK (EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.id = book_draft_digital_resources.book_draft_id));
ALTER POLICY book_draft_import_events_catalogacao_librarian_all ON public.book_draft_import_events
  USING (EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.id = book_draft_import_events.book_draft_id))
  WITH CHECK (EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.id = book_draft_import_events.book_draft_id));

-- Suppression définitive (RESTRICTIVE, en ET avec la portée) : la coordination
-- DE la bibliothèque du brouillon, ou l'administration (avant : coordination
-- de n'importe quelle bibliothèque). Autorités et lots : inchangés.
ALTER POLICY book_drafts_suppression_definitive_coordination ON public.book_drafts
  USING (
    (SELECT public.fn_caller_is_network_admin())
    OR coalesce(owner_library_id, public.fn_book_draft_creator_library(id, created_by))
       = ANY ((SELECT public.fn_caller_coordinator_library_ids())::uuid[])
    OR ( owner_library_id IS NULL AND created_by = (SELECT auth.uid())
         AND public.fn_book_draft_creator_library(id, created_by) IS NULL
         AND (SELECT public.fn_is_catalog_coordinator()) ) );
ALTER POLICY exemplar_drafts_suppression_definitive_coordination ON public.exemplar_drafts
  USING (
    (SELECT public.fn_caller_is_network_admin())
    OR coalesce(target_library_id,
                public.fn_exemplar_draft_fallback_library(book_draft_id, import_staging_row_id, created_by))
       = ANY ((SELECT public.fn_caller_coordinator_library_ids())::uuid[])
    OR ( target_library_id IS NULL AND created_by = (SELECT auth.uid())
         AND public.fn_exemplar_draft_fallback_library(book_draft_id, import_staging_row_id, created_by) IS NULL
         AND (SELECT public.fn_is_catalog_coordinator()) ) );

-- Journal des suppressions : l'instantané d'une notice ou d'un exemplaire se
-- lit dans sa bibliothèque (enregistrée résolue depuis cette migration), ou par
-- qui a supprimé, ou par l'administration ; le reste comme avant.
ALTER POLICY catalog_audit_log_select_staff ON public.catalog_audit_log
  USING (
    (SELECT public.fn_caller_is_network_admin())
    OR ( EXISTS (SELECT 1 FROM public.user_library_memberships m
                  WHERE m.user_id = (SELECT auth.uid())
                    AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
                    AND m.status = 'active')
         AND ( entity_type NOT IN ('book', 'exemplar')
               OR library_id = ANY ((SELECT public.fn_caller_staff_library_ids())::uuid[])
               OR actor_id = (SELECT auth.uid()) ) ) );

-- Tours de révision (et l'instantané du rapport qu'ils portent) : ceux des lots
-- ENTIÈREMENT à nous — tous leurs brouillons, quel que soit leur statut, dans
-- nos bibliothèques —, tous pour l'administration. (La table est lisible en
-- direct : le masquage de fn_batch_reviews_list ne suffit pas.)
ALTER POLICY catalog_batch_reviews_read_staff ON public.catalog_batch_reviews
  USING (public.fn_caller_owns_batch(batch_id));

-- Les lots eux-mêmes : tout le staff pouvait lire, renommer, fermer, archiver
-- ou supprimer le lot d'une autre bibliothèque (le supprimer effaçait ses tours
-- de révision, par cascade). Désormais : on voit les lots qu'on a créés, qu'une
-- collègue a créés, ou qui portent des brouillons de nos bibliothèques ; on
-- modifie ceux dont on peut modifier tous les brouillons en cours ; on
-- supprime ceux qui sont entièrement à nous (la garde « coordination » reste).
-- L'administration : tous. La création ne change pas (created_by est figé).
-- (created_by lu sur la ligne même : la fonction, STABLE, ne voit pas la ligne
-- que l'INSERT … RETURNING vient d'écrire.)
-- (Toujours sous la garde d'origine : un accès au catalogage — le créateur
-- d'un lot qui n'est plus staff ne le voit plus.)
ALTER POLICY catalog_batches_select_librarian ON public.catalog_batches
  USING ((SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
         AND (created_by = (SELECT auth.uid()) OR public.fn_caller_can_see_batch(id)));
ALTER POLICY catalog_batches_update_librarian ON public.catalog_batches
  USING ((SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
         AND public.fn_caller_can_see_batch(id) AND public.fn_caller_can_edit_batch(id, false))
  WITH CHECK ((SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
              AND public.fn_caller_can_see_batch(id) AND public.fn_caller_can_edit_batch(id, false));
ALTER POLICY catalog_batches_delete_librarian ON public.catalog_batches
  USING ((SELECT EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true)) AND public.fn_caller_owns_batch(id));
-- Et la porte restrictive de la suppression d'un lot (qui emporte sa
-- corbeille, 29/08) : la coordination DE ce lot, comme pour la suppression
-- définitive d'un brouillon — plus une coordination quelconque.
ALTER POLICY catalog_batches_suppression_definitive_coordination ON public.catalog_batches
  USING (public.fn_caller_coordinates_batch(id));

-- Journal des fusions : une fusion de BROUILLONS (valeurs des champs,
-- identifiants) se lit par qui peut modifier le brouillon absorbé, par qui a
-- fusionné, ou par l'administration ; les autres fusions comme avant (staff).
ALTER POLICY merge_log_staff_read ON public.merge_log
  USING (
    (SELECT public.fn_caller_is_network_admin())
    OR ( EXISTS (SELECT 1 FROM public.user_library_memberships m
                  WHERE m.user_id = (SELECT auth.uid())
                    AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
                    AND m.status = 'active')
         AND ( entity_type IS DISTINCT FROM 'book_draft'
               OR merged_by = (SELECT auth.uid())
               OR coalesce(public.fn_caller_can_edit_book_draft(duplicate_id), false) ) ) );

-- Droits des fonctions recréées : inchangés (CREATE OR REPLACE les garde),
-- réaffirmés pour les gardes CI.
REVOKE EXECUTE ON FUNCTION public.publish_book_draft(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_exemplar_draft(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_author_draft(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_catalog_batch(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION api.merge_book_drafts(bigint, bigint, jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION api.merge_draft_into_book(bigint, bigint, jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION api.suggest_draft_duplicates(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_batch_caller_can_edit(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_batch_review_report(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_batch_review_request(bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_batch_reviews_list() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_batch_owner_libraries() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_batch_reassign_library(bigint, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_book_draft_destination_library(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_audit_draft_deletion() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_restore_deleted_draft(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_book_draft_from_book(bigint, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_exemplar_draft_from_exemplar(bigint, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_author_draft_from_author(bigint, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_import_list_run_rows(bigint) FROM PUBLIC, anon;
