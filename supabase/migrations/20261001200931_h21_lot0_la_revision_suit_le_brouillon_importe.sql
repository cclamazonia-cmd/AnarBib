-- =====================================================================
-- H21 lot 0 — préalables au réimport (REGISTRE IMP-26 et IMP-27, 29/09/2026)
--
-- Décisions de Xavier du 29/09 :
--  (a) une notice née d'un import ne se publie que dans un lot révisé, même
--      sortie de son lot (« Sans lot », changement de bibliothèque,
--      restauration, lot supprimé) ;
--  (b) l'approbation d'un tour couvre les brouillons que ce tour a soumis,
--      figés à la demande ; un brouillon rangé ensuite attend un nouveau tour,
--      que la coordination peut demander elle-même ;
--  (c) un lot né d'un rapprochement (exemplaires ajoutés à des notices déjà au
--      catalogue) passe aussi par la révision ;
--  (d) une nouvelle sélection d'un run rejoint le lot que ce run a ouvert,
--      tant qu'aucune révision n'y est demandée ni approuvée ;
--  (e) vider la corbeille d'un brouillon importé écarte sa ligne d'import :
--      elle ne revient pas au prochain « Promouvoir » ;
--  IMP-26 (h) « Accepté (rattaché) » ne devient jamais une notice ;
--  et « Promouvoir la sélection » ne promeut que la sélection ; l'identifiant
--  d'origine se juge sur la ligne d'import, exemplaire rapproché compris.
--
-- Méthode : chaque fonction existante est modifiée SUR SA DÉFINITION VIVANTE
-- (pg_get_functiondef), par ancres dont le nombre d'occurrences est contrôlé
-- — une production qui aurait bougé fait échouer la migration au lieu de
-- réinstaller un texte périmé. Définitions lues le 29/09 (md5 = production
-- pour toutes, sauf fn_import_delete_run, fn_batch_reviews_list,
-- fn_create_item_drafts_for_batch et fn_restore_deleted_draft : définitions du
-- banc ; toutes relues en production le 29/09 au soir : md5 identiques).
-- Relu par deux revues contradictoires. Première : les listes figées comptent
-- les publiés et les exemplaires rattachés, la trace d'import ne se réécrit
-- pas par l'API, le journal ne rejoue pas une ligne repromue. Seconde (19
-- constats, 14 confirmés dans le périmètre) : seule la publication pose le
-- statut « publié » ; un exemplaire rattaché ne suit qu'une notice réellement
-- publiée ; un exemplaire rapproché à la corbeille retient son run, et ne
-- revient pas du journal si sa ligne a disparu ; une création rejouée reprend
-- sa ligne (et une reprise se rejoue de nouveau) ; l'écartement passe par des
-- lectures indexées ; la décision éditoriale ignore une ligne déjà convertie ;
-- l'effaceur épargne une saisie à la main ; le rattrapage des tours est une
-- fonction nommée, jouée aussi par la suite de tests. Contre-vérification de
-- la seconde passe (deux sceptiques par correctif) : le statut « publié » d'un
-- brouillon d'exemplaire est réservé lui aussi ; la ligne écartée garde le
-- brouillon qui l'a libérée (discarded_draft_id), seule preuve que lit la
-- reprise au rejeu — dans tous les ordres, après une réattribution de lot
-- comme après un geste sur la décision ; « Accepté (nouveau) » ne relève pas
-- une ligne rejetée. Quatrième passe : une ligne écartée n'accepte plus aucune
-- décision (seul le rejeu de son brouillon la relève) et le journal refuse un
-- brouillon dont la ligne a été libérée depuis par un autre ; une ligne ne
-- s'efface pas sous un exemplaire rapproché non publié (run, « Retraiter »,
-- dépôt) ; « Rapprocher » ignore les lignes déjà traitées ailleurs.
-- Cinquième passe (30/09) : « Retraiter » est refusé tout de suite, à l'écran,
-- pour un run dont une ligne est écartée ou retenue par un exemplaire rapproché
-- à la corbeille (sinon le refus arrivait en différé, dans l'edge function, qui
-- laissait le run en échec — ou relisait la ligne écartée en ligne neuve,
-- promouvable) ; « Rapprocher » et la décision éditoriale comptent comme
-- ignorées les lignes sorties du run depuis le chargement de l'écran, au lieu
-- d'un refus brut ou d'un faux succès ; « Rejeter » ne réécrit pas la raison
-- d'une ligne déjà rejetée. Mesuré en production le 30/09 : aucune ligne libre
-- ne reste d'une création importée purgée avant cette migration (1 663
-- purges, toutes sur des runs supprimés depuis). La garde de « Retraiter » se
-- juge à l'envoi : une conversion faite dans les secondes qui séparent l'envoi
-- de l'effacement par l'edge function (second onglet, API) n'est pas couverte
-- — course antérieure (H15), consignée au backlog avec ses pistes.
-- Sixième passe (01/10) : une notice importée ou un exemplaire rapproché DÉJÀ
-- publiés se republient hors lot (« Sans lot », « Réattribuer à une autre
-- bibliothèque ») — leurs retouches ne sont pas concernées (b), et le statut
-- « publié » ne se pose que par la publication ; « Rapprocher » ignore aussi
-- une ligne dont la notice proposée a disparu depuis le chargement.
-- =====================================================================

-- Outil de la migration, éphémère (pg_temp) : remplace une ancre qui doit
-- figurer exactement p_n fois.
CREATE FUNCTION pg_temp.h21_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'H21 lot 0 — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN
    RAISE EXCEPTION 'H21 lot 0 — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;


-- ─────────────────────────────────────────────────────────────────────
-- 1. L'identifiant d'origine se juge sur la LIGNE d'import
-- ─────────────────────────────────────────────────────────────────────
-- La clé que le FICHIER donne à une notice (external_key), si elle désigne
-- UNE notice dans sa source ; sinon NULL. Un seul juge : pour l'exemplaire
-- rapproché (publish_exemplar_draft), pour le brouillon né d'une ligne
-- (fn_h20_identifiant_d_origine), et demain pour reconnaître une notice au
-- réimport (IMP-23 c). N'en est pas une :
--  * une clé vide ;
--  * le numéro d'un FASCICULE : la colonne « numero » d'un CSV de périodiques
--    (« periodico » remplie) ; le format est celui du run ;
--  * une clé que portent plusieurs LIGNES du même fichier, quelle que soit
--    leur décision : elle ne désigne pas une notice. Deux runs d'une même
--    source portent les mêmes clés : c'est le réimport, pas une répétition.
CREATE OR REPLACE FUNCTION ingest.fn_h20_cle_de_la_ligne(p_staging_row_id bigint)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select case
    when nullif(btrim(coalesce(sr.external_key, '')), '') is null then null
    when r.detected_format in ('csv', 'tsv')
         and btrim(sr.external_key) = btrim(sr.raw_payload->>'numero')
         and nullif(btrim(sr.raw_payload->>'periodico'), '') is not null then null
    when exists (select 1 from ingest.partner_catalog_staging_rows s2
                  where s2.run_id = sr.run_id and s2.id <> sr.id
                    and btrim(s2.external_key) = btrim(sr.external_key)) then null
    else btrim(sr.external_key)
  end
  from ingest.partner_catalog_staging_rows sr
  join ingest.partner_catalog_import_runs r on r.id = sr.run_id
  where sr.id = p_staging_row_id;
$function$;
REVOKE EXECUTE ON FUNCTION ingest.fn_h20_cle_de_la_ligne(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_h20_cle_de_la_ligne(bigint) TO service_role;
COMMENT ON FUNCTION ingest.fn_h20_cle_de_la_ligne(bigint) IS
  'H21 lot 0 (29/09/2026) : identifiant d''origine d''une ligne d''import, ou NULL (clé vide, numéro de fascicule d''un CSV de périodiques, clé portée par plusieurs lignes du run). Interne : fn_h20_identifiant_d_origine, publish_exemplar_draft.';

-- Le juge demande, pour chaque ligne, si une autre ligne du run porte la même
-- clé : sans index, un run de N lignes coûte N² lectures à la promotion
-- (fn_h20_effacer_faux_identifiants). Index complet : un index partiel ne
-- serait pas choisi.
CREATE INDEX IF NOT EXISTS partner_catalog_staging_rows_run_cle_idx
  ON ingest.partner_catalog_staging_rows (run_id, btrim(external_key));

DO $h21_juge$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('ingest.fn_h20_identifiant_d_origine(bigint)'::regprocedure);
  v_def := pg_temp.h21_remplacer('fn_h20_identifiant_d_origine (délégation)', v_def,
$a$  select case
    when nullif(btrim(coalesce(d.source_record_id, '')), '') is null then null$a$,
$b$  select case
    -- H21 lot 0 (29/09/2026) : un brouillon né d'une ligne d'import (lien
    -- row_to_draft, que seule la promotion écrit) se juge sur SA ligne, par le
    -- juge de l'exemplaire rapproché : la clé que le fichier donne, celle que
    -- le réimport cherchera (IMP-23 c) ; jamais source_record_id ni
    -- marc_json.ingest, que le formulaire et l'API réécrivent. Les règles
    -- suivantes ne jugent plus que les brouillons sans lien.
    when rd.staging_row_id is not null then ingest.fn_h20_cle_de_la_ligne(rd.staging_row_id)
    when nullif(btrim(coalesce(d.source_record_id, '')), '') is null then null$b$);
  v_def := pg_temp.h21_remplacer('fn_h20_identifiant_d_origine (lien)', v_def,
$a$  from public.book_drafts d
  where d.id = p_draft_id and d.marc_json ? 'ingest';$a$,
$b$  from public.book_drafts d
  left join lateral (select m.staging_row_id from ingest.partner_catalog_row_to_draft m
                      where m.draft_id = d.id order by m.id limit 1) rd on true
  where d.id = p_draft_id and d.marc_json ? 'ingest';$b$);
  EXECUTE v_def;
END
$h21_juge$;

-- L'effaceur des faux identifiants juge désormais un brouillon lié par sa
-- ligne, sans lire source_record_id : il effacerait une valeur saisie à la
-- main au formulaire, à la sélection suivante du même run (IMP-27 d la rend
-- ordinaire). Pour un brouillon lié, il n'efface que la clé venue du fichier.
DO $h21_effaceur$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('ingest.fn_h20_effacer_faux_identifiants(bigint)'::regprocedure);
  v_def := pg_temp.h21_remplacer('fn_h20_effacer_faux_identifiants', v_def,
$a$       AND ingest.fn_h20_identifiant_d_origine(d.id) IS NULL
$a$,
$b$       AND ingest.fn_h20_identifiant_d_origine(d.id) IS NULL
       -- H21 lot 0 (29/09/2026) : un brouillon lié à sa ligne ne perd que la
       -- clé que le fichier lui a donnée ; une valeur saisie à la main reste.
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m
                         JOIN ingest.partner_catalog_staging_rows sr ON sr.id = m.staging_row_id
                        WHERE m.draft_id = d.id
                          AND btrim(d.source_record_id) IS DISTINCT FROM btrim(sr.external_key))
$b$);
  EXECUTE v_def;
END
$h21_effaceur$;


-- ─────────────────────────────────────────────────────────────────────
-- 2. La révision : ce qu'un tour soumet, et qui en sort
-- ─────────────────────────────────────────────────────────────────────
-- IMP-27 (b) : ce que ce tour soumet à la révision, figé à la demande. Les
-- tours d'avant le 29/09 sont rattrapés ci-dessous ; une liste NULL (tour
-- écrit sans elle, ce que seules des fixtures font) couvre le lot : garde de
-- compatibilité.
ALTER TABLE public.catalog_batch_reviews
  ADD COLUMN IF NOT EXISTS draft_ids bigint[],
  ADD COLUMN IF NOT EXISTS exemplar_draft_ids bigint[];
COMMENT ON COLUMN public.catalog_batch_reviews.draft_ids IS
  'IMP-27 b (29/09/2026) : brouillons de notice du lot (draft, ready, published) à la demande de ce tour. L''approbation ne couvre qu''eux. NULL (tour écrit sans liste) : l''approbation couvre le lot.';
COMMENT ON COLUMN public.catalog_batch_reviews.exemplar_draft_ids IS
  'IMP-27 b (29/09/2026) : brouillons d''exemplaire du lot (draft, ready, published ; rattachés à une notice ou non) à la demande de ce tour — un exemplaire rattaché que l''absorption de sa notice détache ensuite reste couvert. NULL : tour écrit sans liste.';

-- Tours existants (aucun en production le 29/09) : ils couvrent ce que leur
-- lot contient au moment de la migration — on ne sait pas ce qu'il contenait
-- à la demande ; rien de plus n'est ouvert. Une fonction nommée, pour que la
-- suite de tests joue le même rattrapage que la migration.
CREATE OR REPLACE FUNCTION private.fn_h21_rattraper_listes_des_tours()
 RETURNS integer
 LANGUAGE sql
 SET search_path TO 'public', 'pg_temp'
AS $function$
  with maj as (
    update public.catalog_batch_reviews r
       set draft_ids = coalesce((select array_agg(d.id order by d.id) from public.book_drafts d
                                  where d.batch_id = r.batch_id and d.status <> 'cancelled'), '{}'::bigint[]),
           exemplar_draft_ids = coalesce((select array_agg(x.id order by x.id) from public.exemplar_drafts x
                                           where x.batch_id = r.batch_id and x.status <> 'cancelled'), '{}'::bigint[])
     where r.draft_ids is null
     returning 1)
  select count(*)::integer from maj;
$function$;
REVOKE EXECUTE ON FUNCTION private.fn_h21_rattraper_listes_des_tours() FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION private.fn_h21_rattraper_listes_des_tours() IS
  'IMP-27 b (29/09/2026) : rattrapage des listes des tours de révision écrits sans elles (contenu non annulé du lot). Joué par la migration du lot 0 de H21, et par sa suite de tests.';
SELECT private.fn_h21_rattraper_listes_des_tours();

-- Vrai si le dernier tour du lot est approuvé ET couvre ce brouillon.
CREATE OR REPLACE FUNCTION public.fn_batch_review_couvre(p_batch_id bigint, p_draft_id bigint, p_kind text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select coalesce((
    select r.status = 'approved'
           and case when p_kind = 'exemplar'
                    then r.exemplar_draft_ids is null or p_draft_id = any (r.exemplar_draft_ids)
                    else r.draft_ids is null or p_draft_id = any (r.draft_ids) end
      from public.catalog_batch_reviews r
     where r.batch_id = p_batch_id
     order by r.round desc
     limit 1), false);
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_batch_review_couvre(bigint, bigint, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_batch_review_couvre(bigint, bigint, text) TO service_role;
COMMENT ON FUNCTION public.fn_batch_review_couvre(bigint, bigint, text) IS
  'IMP-27 b (29/09/2026) : le dernier tour du lot est approuvé et couvre ce brouillon (p_kind : book ou exemplar). Interne : publish_book_draft, publish_exemplar_draft.';

-- Nombre de brouillons vivants d'un lot approuvé que son dernier tour ne
-- couvre pas (rangés après la demande) : 0 hors approbation.
CREATE OR REPLACE FUNCTION public.fn_batch_ajouts_apres_revision(p_batch_id bigint)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select coalesce((
    select case when r.status <> 'approved' then 0 else
             (select count(*)::int from public.book_drafts d
               where d.batch_id = p_batch_id and d.status in ('draft', 'ready')
                 and r.draft_ids is not null and not (d.id = any (r.draft_ids)))
           + (select count(*)::int from public.exemplar_drafts x
               where x.batch_id = p_batch_id and x.book_draft_id is null
                 and x.status in ('draft', 'ready')
                 and r.exemplar_draft_ids is not null and not (x.id = any (r.exemplar_draft_ids)))
           end
      from public.catalog_batch_reviews r
     where r.batch_id = p_batch_id
     order by r.round desc
     limit 1), 0);
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_batch_ajouts_apres_revision(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_batch_ajouts_apres_revision(bigint) TO service_role;
COMMENT ON FUNCTION public.fn_batch_ajouts_apres_revision(bigint) IS
  'IMP-27 b (29/09/2026) : brouillons vivants d''un lot approuvé que le dernier tour ne couvre pas. Interne : fn_batch_review_request, fn_batch_reviews_list.';

-- IMP-27 (a) : un brouillon de notice est né d'un import s'il porte le lien de
-- promotion (ingest.partner_catalog_row_to_draft, que l'API n'écrit pas) ou,
-- pour une création, la trace que la promotion laisse dans marc_json : le lien
-- part en cascade avec le run ou une suppression définitive, et le rejeu du
-- journal ne le recrée que si la ligne existe encore ; la trace, que l'API ne
-- réécrit pas, reste (même critère que publish_book_draft
-- pour la bibliothèque d'une notice importée, B30). Un brouillon de reprise
-- (published_book_id posé) recopie le marc_json de sa notice : la trace n'y
-- prouve rien. partner_source / import_method ne prouvent rien : l'API les écrit.
CREATE OR REPLACE FUNCTION public.fn_book_draft_is_imported(p_draft_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select exists (select 1 from ingest.partner_catalog_row_to_draft m
                  where m.draft_id = p_draft_id)
      or exists (select 1 from public.book_drafts d
                  where d.id = p_draft_id
                    and d.published_book_id is null
                    and coalesce(d.marc_json, '{}'::jsonb) ? 'ingest');
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_book_draft_is_imported(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_book_draft_is_imported(bigint) TO service_role;
COMMENT ON FUNCTION public.fn_book_draft_is_imported(bigint) IS
  'IMP-27 a (29/09/2026) : le brouillon de notice est né d''un import (lien row_to_draft, ou trace marc_json.ingest d''une création). Interne : publish_book_draft ; fn_batch_is_imported applique la même règle en ensemble.';

DO $h21_lot_importe$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_batch_is_imported(bigint)'::regprocedure);
  v_def := pg_temp.h21_remplacer('fn_batch_is_imported', v_def,
$a$              and (d.import_method is not null or d.partner_source is not null)
         );$a$,
$b$              and (d.import_method is not null or d.partner_source is not null)
         )
      -- IMP-27 (a) (29/09/2026) : un lot qui CONTIENT un brouillon né d'un
      -- import l'est aussi — sorti de son lot d'origine (row_to_draft.batch_id
      -- garde le lot de la promotion) ou revenu sans son lien (run supprimé :
      -- la trace marc_json.ingest d'une création reste).
      -- Même règle que public.fn_book_draft_is_imported, écrite en ensemble.
      or exists (
           select 1 from public.book_drafts d
            where d.batch_id = p_batch_id
              and (exists (select 1 from ingest.partner_catalog_row_to_draft m
                            where m.draft_id = d.id)
                   or (d.published_book_id is null
                       and coalesce(d.marc_json, '{}'::jsonb) ? 'ingest'))
         )
      -- IMP-27 (c) : un lot né d'un RAPPROCHEMENT (exemplaires d'un fichier
      -- ajoutés à des notices déjà au catalogue) est né d'un import.
      or exists (
           select 1 from public.exemplar_drafts x
            where x.batch_id = p_batch_id
              and x.book_draft_id is null
              and x.import_staging_row_id is not null
         );$b$);
  EXECUTE v_def;
END
$h21_lot_importe$;

DO $h21_publier_notice$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure);
  v_def := pg_temp.h21_remplacer('publish_book_draft', v_def,
$a$    raise exception 'lote_importado_sem_revisao' using hint = 'error.publish.review_required';
  end if;
$a$,
$b$    raise exception 'lote_importado_sem_revisao' using hint = 'error.publish.review_required';
  end if;

  -- IMP-27 (a) (29/09/2026) : la garde suit aussi le BROUILLON. Né d'un import
  -- (public.fn_book_draft_is_imported : lien row_to_draft, que l'API n'écrit
  -- pas, ou trace marc_json.ingest d'une création), il ne se publie que DANS
  -- un lot : « Sans lot », changement de bibliothèque, restauration, lot
  -- supprimé le laissaient hors de toute révision. Un brouillon DÉJÀ publié
  -- — statut que seule la publication pose, après cette porte, ET notice
  -- encore au catalogue (une notice retirée vide published_book_id : la
  -- republier en créerait une neuve) — se republie hors lot : ses retouches
  -- ne sont pas concernées (b) — sixième passe.
  if v_draft.batch_id is null
     and not (v_draft.status = 'published' and v_draft.published_book_id is not null)
     and public.fn_book_draft_is_imported(p_draft_id) then
    raise exception 'noticia_importada_fora_de_lote' using hint = 'error.publish.imported_needs_batch';
  end if;
  -- IMP-27 (b) : l'approbation couvre les brouillons que son tour a soumis
  -- (catalog_batch_reviews.draft_ids, figés à la demande) ; un brouillon rangé
  -- ensuite dans le lot attend un nouveau tour.
  if v_draft.batch_id is not null
     and public.fn_batch_review_status(v_draft.batch_id) = 'approved'
     and not public.fn_batch_review_couvre(v_draft.batch_id, p_draft_id, 'book')
     and public.fn_batch_is_imported(v_draft.batch_id) then
    raise exception 'rascunho_acrescentado_apos_revisao' using hint = 'error.publish.added_after_review';
  end if;
$b$);
  EXECUTE v_def;
END
$h21_publier_notice$;

DO $h21_publier_exemplaire$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.publish_exemplar_draft(bigint)'::regprocedure);
  v_def := pg_temp.h21_remplacer('publish_exemplar_draft (porte)', v_def,
$a$    raise exception 'exemplar_importado_sem_biblioteca' using hint = 'error.publish.item_without_library';
  end if;
$a$,
$b$    raise exception 'exemplar_importado_sem_biblioteca' using hint = 'error.publish.item_without_library';
  end if;

  -- IMP-27 (c) (29/09/2026) : un exemplaire RAPPROCHÉ (venu d'une ligne
  -- d'import, sans notice importée) se publie comme une notice importée :
  -- dans un lot, après une révision approuvée, et s'il figurait parmi ce que
  -- le tour a soumis (b). Un exemplaire d'une notice importée (book_draft_id)
  -- suit la garde de sa notice, qui le publie ; un exemplaire fait à la main,
  -- rangé dans un lot né d'un import, attend avec lui, comme une notice.
  -- Un exemplaire rapproché DÉJÀ publié (statut que seule la publication pose,
  -- après cette porte, ET exemplaire au catalogue) se republie hors lot : « Réattribuer à une autre
  -- bibliothèque » le sort de son lot (un lot a une bibliothèque), et ses
  -- retouches ne sont pas concernées (b) — sixième passe, 01/10.
  if v_draft.book_draft_id is null then
    if v_draft.batch_id is null and v_draft.import_staging_row_id is not null
       and not (v_draft.status = 'published' and v_draft.published_exemplar_id is not null) then
      raise exception 'exemplar_importado_fora_de_lote' using hint = 'error.publish.imported_needs_batch';
    end if;
    if v_draft.batch_id is not null and public.fn_batch_is_imported(v_draft.batch_id) then
      if public.fn_batch_review_status(v_draft.batch_id) is distinct from 'approved' then
        raise exception 'lote_importado_sem_revisao' using hint = 'error.publish.review_required';
      end if;
      if not public.fn_batch_review_couvre(v_draft.batch_id, p_draft_id, 'exemplar') then
        raise exception 'rascunho_acrescentado_apos_revisao' using hint = 'error.publish.added_after_review';
      end if;
    end if;
  end if;
$b$);
  v_def := pg_temp.h21_remplacer('publish_exemplar_draft (clé jugée)', v_def,
$a$      (select sr.external_key from ingest.partner_catalog_staging_rows sr
        where sr.id = v_draft.import_staging_row_id));$a$,
$b$      -- H21 lot 0 (29/09/2026) : la clé JUGÉE sur sa ligne
      -- (ingest.fn_h20_cle_de_la_ligne) : une clé que portent plusieurs lignes
      -- du fichier, ou le numéro d'un fascicule d'un CSV de périodiques, n'est
      -- pas un identifiant d'origine.
      ingest.fn_h20_cle_de_la_ligne(v_draft.import_staging_row_id));$b$);
  -- Un exemplaire rattaché ne suit sa notice que si elle est RÉELLEMENT publiée
  -- (published_book_id, que seule la publication pose) : le statut seul
  -- s'écrivait par l'API.
  v_def := pg_temp.h21_remplacer('publish_exemplar_draft (notice publiée)', v_def,
$a$    select bd.status into v_record_status from public.book_drafts bd where bd.id = v_draft.book_draft_id;$a$,
$b$    -- H21 lot 0 (29/09/2026) : publiée = statut ET notice au catalogue.
    select case when bd.published_book_id is null then 'draft' else bd.status end
      into v_record_status from public.book_drafts bd where bd.id = v_draft.book_draft_id;$b$);
  EXECUTE v_def;
END
$h21_publier_exemplaire$;

DO $h21_demander$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_batch_review_request(bigint, text)'::regprocedure);
  v_def := pg_temp.h21_remplacer('fn_batch_review_request (rouvrir)', v_def,
$a$  if v_last = 'approved' and not public.fn_caller_is_network_admin() then$a$,
$b$  -- IMP-27 (b) (29/09/2026) : la coordination rouvre elle-même un lot approuvé
  -- où des brouillons sont entrés après la demande (ils attendent un tour).
  if v_last = 'approved' and not public.fn_caller_is_network_admin()
     and public.fn_batch_ajouts_apres_revision(p_batch_id) = 0 then$b$);
  v_def := pg_temp.h21_remplacer('fn_batch_review_request (liste figée)', v_def,
$a$    (batch_id, round, status, requested_by, coord_message, report, report_generated_at)
  values
    (p_batch_id, v_round, 'requested', auth.uid(), nullif(btrim(p_message), ''),
     public.fn_batch_review_report(p_batch_id), now())$a$,
$b$    (batch_id, round, status, requested_by, coord_message, report, report_generated_at,
     draft_ids, exemplar_draft_ids)
  values
    (p_batch_id, v_round, 'requested', auth.uid(), nullif(btrim(p_message), ''),
     public.fn_batch_review_report(p_batch_id), now(),
     -- IMP-27 (b) : ce que ce tour soumet, figé ; l'approbation ne couvre qu'eux.
     -- Les publiés aussi (une republication ne redevient pas « ajoutée ») ;
     -- tous les exemplaires, rattachés compris (l'absorption de leur notice
     -- les détache sans les avoir rangés après la demande).
     coalesce((select array_agg(d.id order by d.id) from public.book_drafts d
                where d.batch_id = p_batch_id and d.status in ('draft', 'ready', 'published')), '{}'::bigint[]),
     coalesce((select array_agg(x.id order by x.id) from public.exemplar_drafts x
                where x.batch_id = p_batch_id
                  and x.status in ('draft', 'ready', 'published')), '{}'::bigint[]))$b$);
  EXECUTE v_def;
END
$h21_demander$;

-- La liste des lots dit combien de brouillons attendent un nouveau tour.
-- RETURNS TABLE change : DROP puis création depuis la définition vivante.
DO $h21_liste$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_batch_reviews_list()'::regprocedure);
  v_def := pg_temp.h21_remplacer('fn_batch_reviews_list (colonne)', v_def,
$a$batch_library_id uuid, batch_library_name text)$a$,
$b$batch_library_id uuid, batch_library_name text, after_review integer)$b$);
  v_def := pg_temp.h21_remplacer('fn_batch_reviews_list (valeur)', v_def,
$a$         b.library_id, coalesce(lb.short_name, lb.name)
$a$,
$b$         b.library_id, coalesce(lb.short_name, lb.name),
         -- IMP-27 (b) : brouillons rangés après la demande d'un tour approuvé
         case when r.status = 'approved' then public.fn_batch_ajouts_apres_revision(b.id) else 0 end
$b$);
  DROP FUNCTION public.fn_batch_reviews_list();
  EXECUTE v_def;
END
$h21_liste$;
REVOKE EXECUTE ON FUNCTION public.fn_batch_reviews_list() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_batch_reviews_list() TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_batch_reviews_list() IS
  'Un enregistrement par lot non archive avec son DERNIER tour de revision (null si jamais demande) ; '
  'lots de ses bibliotheques (staff), tous pour l''administration du reseau ; '
  'batch_library_id / batch_library_name = bibliotheque du lot (NULL = administration du reseau). B30, 27/09/2026. '
  'after_review = brouillons vivants d''un lot approuve que son dernier tour ne couvre pas (IMP-27 b, 29/09/2026).';

DO $h21_supprimer_run$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_import_delete_run(bigint)'::regprocedure);
  v_def := pg_temp.h21_remplacer('fn_import_delete_run', v_def,
$a$  -- H20 (revue du 28/09/2026) : un exemplaire RAPPROCHÉ (hors des lots
$a$,
$b$  -- IMP-27 (a) (29/09/2026) : le lien row_to_draft prouve qu'une notice vient
  -- d'un import (publish_book_draft, fn_batch_is_imported) et il part en
  -- cascade avec le run. Le compte par LOT ci-dessus ne voit pas un brouillon
  -- lié sorti de son lot d'origine : on compte aussi les brouillons liés
  -- eux-mêmes, où qu'ils soient, tant qu'ils peuvent être publiés.
  SELECT count(*) INTO v_actifs
    FROM ingest.partner_catalog_row_to_draft m
    JOIN public.book_drafts d ON d.id = m.draft_id
   WHERE m.run_id = p_run_id AND d.status IN ('draft', 'ready');
  IF v_actifs > 0 THEN
    RAISE EXCEPTION
      'Run % : % brouillon(s) de notice nés de cet import attendent hors de leur lot d''origine.',
      p_run_id, v_actifs
      USING HINT = 'error.import.run_has_linked_drafts';
  END IF;
  -- IMP-27 (c) : un exemplaire RAPPROCHÉ n'a d'autre preuve d'import que sa
  -- ligne (import_staging_row_id, qui passe à NULL avec le run). Même à la
  -- corbeille, il retient le run : restauré ensuite, il se publierait comme
  -- un exemplaire fait à la main, sans révision.
  SELECT count(*) INTO v_actifs
    FROM public.exemplar_drafts x
    JOIN ingest.partner_catalog_staging_rows sr ON sr.id = x.import_staging_row_id
   WHERE sr.run_id = p_run_id AND x.book_draft_id IS NULL AND x.status = 'cancelled';
  IF v_actifs > 0 THEN
    RAISE EXCEPTION
      'Run % : % exemplaire(s) rapproché(s) de cet import sont à la corbeille.',
      p_run_id, v_actifs
      USING HINT = 'error.import.run_has_trashed_items';
  END IF;

  -- H20 (revue du 28/09/2026) : un exemplaire RAPPROCHÉ (hors des lots
$b$);
  EXECUTE v_def;
END
$h21_supprimer_run$;


-- ─────────────────────────────────────────────────────────────────────
-- 3. Promouvoir : la sélection, jamais une ligne rattachée, dans le lot du run
-- ─────────────────────────────────────────────────────────────────────
DO $h21_creer_brouillons$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure);
  -- IMP-26 (h) : les deux comptes et la boucle.
  v_def := pg_temp.h21_remplacer('fn_create_book_drafts_from_import_rows (rattachée)', v_def,
$a$      and (
        (sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new')
        or
        (sr.match_status in ('matched_book', 'matched_draft', 'possible_duplicate', 'manual_decision')
         and sr.editorial_decision = 'accept_duplicate')
      )$a$,
$b$      -- IMP-26 (h) : une ligne « Accepté (rattaché) » ne devient jamais une
      -- notice ; un exemplaire sur la notice existante, c'est « Rapprocher ».
      and sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new'$b$, 3);
  -- IMP-27 (d) : le lot du run.
  v_def := pg_temp.h21_remplacer('fn_create_book_drafts_from_import_rows (déclarations)', v_def,
$a$  v_batch_id bigint;
$a$,
$b$  v_batch_id bigint;
  v_batch_library uuid;        -- IMP-27 (d)
  v_batch_neuf boolean := false;
  v_lot_repris bigint;
  v_lot_repris_nom text;
$b$);
  v_def := pg_temp.h21_remplacer('fn_create_book_drafts_from_import_rows (lot du run)', v_def,
$a$  insert into public.catalog_batches (name, notes, created_by, library_id)
  values (v_batch_name, v_batch_notes, v_actor,
          (select case when s.source_kind in ('partner_deposit', 'oai_pmh') then s.destination_library_id
                       else r.library_id end
             from ingest.partner_catalog_import_runs r
             left join ingest.partner_catalog_sources s on s.id = r.source_id
            where r.id = p_run_id))
  returning id into v_batch_id;
$a$,
$b$  select case when s.source_kind in ('partner_deposit', 'oai_pmh') then s.destination_library_id
              else r.library_id end
    into v_batch_library
    from ingest.partner_catalog_import_runs r
    left join ingest.partner_catalog_sources s on s.id = r.source_id
   where r.id = p_run_id;

  -- IMP-27 (d) (29/09/2026) : une nouvelle sélection du run rejoint le lot
  -- qu'une promotion précédente de ce run a ouvert, tant qu'il est ouvert, de
  -- la même bibliothèque, et qu'aucune révision n'y est demandée ni approuvée
  -- (« retouches demandées » : la coordination y travaille encore) — une
  -- révision de moins pour l'administration à chaque sélection.
  select b.id, b.name into v_lot_repris, v_lot_repris_nom
    from public.catalog_batches b
   where b.status = 'open'
     and b.library_id is not distinct from v_batch_library
     and b.id in (select m.batch_id from ingest.partner_catalog_row_to_draft m
                   where m.run_id = p_run_id and m.batch_id is not null)
     and coalesce(public.fn_batch_review_status(b.id), 'aucune') in ('aucune', 'changes_requested')
   order by b.id desc
   limit 1
   for update of b;

  if v_lot_repris is not null then
    v_batch_id := v_lot_repris;
    v_batch_name := v_lot_repris_nom;
  else
    insert into public.catalog_batches (name, notes, created_by, library_id)
    values (v_batch_name, v_batch_notes, v_actor, v_batch_library)
    returning id into v_batch_id;
    v_batch_neuf := true;
  end if;
$b$);
  v_def := pg_temp.h21_remplacer('fn_create_book_drafts_from_import_rows (lot vide)', v_def,
$a$  if v_created_count = 0 then
    delete from public.catalog_batches where id = v_batch_id;$a$,
$b$  if v_created_count = 0 then
    -- IMP-27 (d) : un lot repris n'est pas à nous ; on ne supprime que le neuf.
    if v_batch_neuf then
      delete from public.catalog_batches where id = v_batch_id;
    end if;$b$);
  EXECUTE v_def;
END
$h21_creer_brouillons$;

-- Les exemplaires du fichier : seulement ceux des lignes de CETTE promotion.
-- Dans un lot repris, l'idempotence « la notice a déjà ses exemplaires »
-- recréerait un exemplaire qu'on a supprimé entre deux sélections.
DO $h21_exemplaires_du_lot$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('ingest.fn_create_item_drafts_for_batch(bigint, uuid)'::regprocedure);
  v_def := pg_temp.h21_remplacer('fn_create_item_drafts_for_batch (signature)', v_def,
$a$(p_batch_id bigint, p_created_by uuid DEFAULT NULL::uuid)$a$,
$b$(p_batch_id bigint, p_created_by uuid DEFAULT NULL::uuid, p_staging_row_ids bigint[] DEFAULT NULL::bigint[])$b$);
  v_def := pg_temp.h21_remplacer('fn_create_item_drafts_for_batch (lignes)', v_def,
$a$     WHERE m.batch_id = p_batch_id
$a$,
$b$     WHERE m.batch_id = p_batch_id
       -- IMP-27 (d) : les lignes de la promotion en cours (NULL : tout le lot).
       AND (p_staging_row_ids IS NULL OR m.staging_row_id = ANY (p_staging_row_ids))
$b$);
  DROP FUNCTION ingest.fn_create_item_drafts_for_batch(bigint, uuid);
  EXECUTE v_def;
END
$h21_exemplaires_du_lot$;
REVOKE EXECUTE ON FUNCTION ingest.fn_create_item_drafts_for_batch(bigint, uuid, bigint[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_create_item_drafts_for_batch(bigint, uuid, bigint[]) TO service_role;

DO $h21_bulk$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('ingest.fn_bulk_create_book_drafts_from_run(bigint, text[], text[], text, text, uuid)'::regprocedure);
  v_def := pg_temp.h21_remplacer('fn_bulk_create_book_drafts_from_run (défaut)', v_def,
$a$p_editorial_decisions text[] DEFAULT ARRAY['accept_new'::text, 'accept_duplicate'::text]$a$,
$b$p_editorial_decisions text[] DEFAULT ARRAY['accept_new'::text]$b$);
  v_def := pg_temp.h21_remplacer('fn_bulk_create_book_drafts_from_run (signature)', v_def,
$a$p_created_by uuid DEFAULT NULL::uuid)$a$,
$b$p_created_by uuid DEFAULT NULL::uuid, p_row_ids bigint[] DEFAULT NULL::bigint[])$b$);
  v_def := pg_temp.h21_remplacer('fn_bulk_create_book_drafts_from_run (sélection)', v_def,
$a$  where sr.run_id = p_run_id
    and sr.created_book_draft_id is null
$a$,
$b$  where sr.run_id = p_run_id
    -- H21 lot 0 (29/09/2026) : « Promouvoir la sélection » ne promeut que la
    -- sélection. Intersection : une ligne d'un autre run, non éligible ou déjà
    -- promue est ignorée sans erreur (selected_row_ids dit ce qui part). NULL =
    -- tout le run ; '{}' = rien — jamais le motif coalesce(array_length(...), 0)
    -- = 0, qui ferait de '{}' « tout le run ».
    and (p_row_ids is null or sr.id = any (p_row_ids))
    and sr.created_book_draft_id is null
$b$);
  v_def := pg_temp.h21_remplacer('fn_bulk_create_book_drafts_from_run (rattachée)', v_def,
$a$    and (
      (sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new')
      or
      (sr.match_status in ('matched_book', 'matched_draft', 'possible_duplicate', 'manual_decision')
       and sr.editorial_decision = 'accept_duplicate')
    )$a$,
$b$    -- IMP-26 (h) : une ligne « Accepté (rattaché) » ne devient jamais une
    -- notice ; un exemplaire sur la notice existante, c'est « Rapprocher ».
    and sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new'$b$);
  DROP FUNCTION ingest.fn_bulk_create_book_drafts_from_run(bigint, text[], text[], text, text, uuid);
  EXECUTE v_def;
END
$h21_bulk$;
REVOKE EXECUTE ON FUNCTION ingest.fn_bulk_create_book_drafts_from_run(bigint, text[], text[], text, text, uuid, bigint[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_bulk_create_book_drafts_from_run(bigint, text[], text[], text, text, uuid, bigint[]) TO service_role;
COMMENT ON FUNCTION ingest.fn_bulk_create_book_drafts_from_run(bigint, text[], text[], text, text, uuid, bigint[]) IS
  'Seule fonction de ce nom depuis le 05/09/2026 (B7) : l''homonyme de public, appelé par personne, a été supprimé. Appelée par public.fn_import_promote. H21 lot 0 (29/09/2026) : p_row_ids restreint la promotion aux lignes choisies (NULL = tout le run, ''{}'' = rien) ; une ligne « rattachée » n''est jamais promue (IMP-26 h).';

DO $h21_promote$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_import_promote(bigint, text[], text[], text, text)'::regprocedure);
  v_def := pg_temp.h21_remplacer('fn_import_promote (défaut)', v_def,
$a$p_editorial_decisions text[] DEFAULT ARRAY['accept_new'::text, 'accept_duplicate'::text]$a$,
$b$p_editorial_decisions text[] DEFAULT ARRAY['accept_new'::text]$b$);
  v_def := pg_temp.h21_remplacer('fn_import_promote (signature)', v_def,
$a$p_batch_notes text DEFAULT NULL::text)$a$,
$b$p_batch_notes text DEFAULT NULL::text, p_row_ids bigint[] DEFAULT NULL::bigint[])$b$);
  v_def := pg_temp.h21_remplacer('fn_import_promote (sélection)', v_def,
$a$    p_batch_notes         := p_batch_notes,
    p_created_by          := v_actor.user_id
  );$a$,
$b$    p_batch_notes         := p_batch_notes,
    p_created_by          := v_actor.user_id,
    -- H21 lot 0 (29/09/2026) : les lignes choisies à l'écran, et elles seules ;
    -- NULL = tout le run (suites SQL, assistant d'import).
    p_row_ids             := p_row_ids
  );$b$);
  v_def := pg_temp.h21_remplacer('fn_import_promote (exemplaires de la promotion)', v_def,
$a$    v_items := ingest.fn_create_item_drafts_for_batch(v_batch_id, v_actor.user_id);$a$,
$b$    -- IMP-27 (d) : le lot peut être repris ; seulement les lignes de CETTE promotion.
    -- Sans liste rendue, aucune ligne (jamais « tout le lot »).
    v_items := ingest.fn_create_item_drafts_for_batch(v_batch_id, v_actor.user_id,
                 coalesce((select array_agg(x::bigint) from jsonb_array_elements_text(v_result->'selected_row_ids') x),
                          '{}'::bigint[]));$b$);
  DROP FUNCTION public.fn_import_promote(bigint, text[], text[], text, text);
  EXECUTE v_def;
END
$h21_promote$;
REVOKE EXECUTE ON FUNCTION public.fn_import_promote(bigint, text[], text[], text, text, bigint[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_import_promote(bigint, text[], text[], text, text, bigint[]) TO authenticated, service_role;

-- IMP-26 (h) : « rattaché » se pose par « Rapprocher », qui crée aussi les
-- exemplaires ; posé seul par l'API, il ne mènerait nulle part.
DO $h21_decision$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_import_set_editorial(bigint, bigint[], text, text)'::regprocedure);
  v_def := pg_temp.h21_remplacer('fn_import_set_editorial (déclarations)', v_def,
$a$  v_run_library_id uuid;
$a$,
$b$  v_run_library_id uuid;
  v_ids bigint[];          -- H21 lot 0
  v_ignorees integer := 0;
$b$);
  v_def := pg_temp.h21_remplacer('fn_import_set_editorial (rattachée, lignes converties)', v_def,
$a$  RETURN ingest.fn_set_partner_catalog_editorial_decision($a$,
$b$  -- IMP-26 (h) (29/09/2026) : « Accepté (rattaché) » se pose par « Rapprocher »
  -- (fn_import_reconcile_duplicates), qui crée aussi les exemplaires.
  IF lower(btrim(coalesce(p_editorial_decision, ''))) = 'accept_duplicate' THEN
    RAISE EXCEPTION 'Decisao accept_duplicate reservada a aproximacao.'
      USING HINT = 'error.import.rattacher_par_rapprocher';
  END IF;

  -- H21 lot 0 : une ligne déjà convertie (brouillon de notice ou d'exemplaire)
  -- est ignorée, pas refusée : entre le chargement de l'écran et le clic, un
  -- autre onglet a pu la promouvoir ou la rapprocher. De même, « Accepté
  -- (nouveau) » ne relève pas une ligne rejetée — ailleurs, ou écartée par la
  -- suppression de son brouillon (IMP-27 e) : l'écran n'offre aucun geste pour
  -- dé-rejeter, seul un onglet périmé ou l'API l'aurait fait. L'écran compare
  -- ensuite ce qui a été fait à ce qu'il demandait (promotedPartial,
  -- rejectedPartial).
  -- Une ligne ÉCARTÉE par la suppression définitive de son brouillon
  -- (discarded_draft_id) n'accepte plus aucune décision : seul le rejeu de SON
  -- brouillon la relève — sinon « En attente » puis « Accepté (nouveau) » la
  -- repromouvait, et deux purges successives donnaient deux brouillons pour
  -- une ligne.
  -- Cinquième passe (30/09) : « Rejeter » ne réécrit pas une ligne déjà
  -- rejetée (sa raison — celle de H19, « tous les exemplaires sont déjà là » —
  -- resterait sinon écrasée par celle de l'onglet périmé).
  SELECT coalesce(array_agg(sr.id) FILTER (WHERE sr.created_book_draft_id IS NULL
                                             AND sr.created_exemplar_draft_id IS NULL
                                             AND sr.discarded_draft_id IS NULL
                                             AND NOT (lower(btrim(coalesce(p_editorial_decision, ''))) IN ('accept_new', 'reject')
                                                      AND sr.editorial_decision = 'reject')), '{}'::bigint[])
    INTO v_ids
    FROM ingest.partner_catalog_staging_rows sr
   WHERE sr.run_id = p_run_id AND sr.id = ANY (p_row_ids);
  -- Ignorées : tout ce qui était demandé et ne sera pas écrit — lignes
  -- converties, rejetées ou écartées, ET lignes sorties du run (« Retraiter »
  -- les a remplacées depuis le chargement de l'écran) : l'écran le dit, au
  -- lieu d'annoncer un succès. (Un run SUPPRIMÉ, lui, est refusé plus haut,
  -- « Run % introuvable », comme avant.)
  v_ignorees := (SELECT count(DISTINCT x) FROM unnest(p_row_ids) x WHERE x IS NOT NULL) - cardinality(v_ids);
  -- Retour anticipé seulement pour une décision valide : une décision inconnue
  -- va jusqu'au refus de la fonction d'ingest, comme avant.
  IF v_ignorees > 0 AND cardinality(v_ids) = 0
     AND lower(btrim(coalesce(p_editorial_decision, ''))) IN ('pending', 'accept_new', 'reject') THEN
    RETURN jsonb_build_object('run_id', p_run_id, 'updated_rows', 0,
                              'editorial_decision', lower(btrim(p_editorial_decision)),
                              'skipped_rows', v_ignorees);
  END IF;
  IF v_ignorees = 0
     OR lower(btrim(coalesce(p_editorial_decision, ''))) NOT IN ('pending', 'accept_new', 'reject') THEN
    v_ids := p_row_ids;      -- rien d'écarté, ou décision inconnue : l'appel d'avant, tel quel
    v_ignorees := 0;
  END IF;

  RETURN ingest.fn_set_partner_catalog_editorial_decision($b$);
  v_def := pg_temp.h21_remplacer('fn_import_set_editorial (liste)', v_def,
$a$    p_row_ids            := p_row_ids,$a$,
$b$    p_row_ids            := v_ids,$b$);
  v_def := pg_temp.h21_remplacer('fn_import_set_editorial (retour)', v_def,
$a$    p_decided_by         := v_actor.user_id
  );$a$,
$b$    p_decided_by         := v_actor.user_id
  ) || jsonb_build_object('skipped_rows', v_ignorees);$b$);
  EXECUTE v_def;
END
$h21_decision$;

-- « Rapprocher » : même règle que la décision éditoriale. Il posait
-- « rattaché » sur TOUTES les lignes reçues avant de filtrer : une ligne promue,
-- rapprochée, rejetée ou écartée entre-temps dans un autre onglet faisait
-- refuser la sélection en bloc (message brut), ou recevait une décision qui ne
-- menait nulle part. Elle est désormais ignorée, et comptée (skipped_rows).
DO $h21_rapprocher$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_import_reconcile_duplicates(bigint, bigint[])'::regprocedure);
  v_def := pg_temp.h21_remplacer('fn_import_reconcile_duplicates (déclarations)', v_def,
$a$  v_run_library_id uuid;
begin$a$,
$b$  v_run_library_id uuid;
  v_ids bigint[];          -- H21 lot 0
  v_ignorees integer := 0;
begin$b$);
  v_def := pg_temp.h21_remplacer('fn_import_reconcile_duplicates (filtre)', v_def,
$a$  -- Marque la decision accept_duplicate (avec controle de compatibilite +$a$,
$b$  -- H21 lot 0 (29/09/2026) : les lignes déjà converties (brouillon de notice
  -- ou d'exemplaire), rejetées ou écartées (IMP-27 e) sont ignorées.
  v_ids := p_row_ids;
  if p_row_ids is not null then
    -- Sixième passe (01/10) : et l'éligibilité même de la fonction d'ingest
    -- (notice proposée encore là, statut rapprochable) — une notice proposée
    -- descartée dans un autre onglet vide proposed_book_id ; sans ceci, la
    -- ligne recevait « rattaché » sans exemplaire, ou la sélection était
    -- refusée en bloc.
    select coalesce(array_agg(sr.id) filter (where sr.created_book_draft_id is null
                                               and sr.created_exemplar_draft_id is null
                                               and sr.discarded_draft_id is null
                                               and sr.editorial_decision is distinct from 'reject'
                                               and sr.proposed_book_id is not null
                                               and sr.match_status in ('matched_book', 'possible_duplicate', 'manual_decision')), '{}'::bigint[])
      into v_ids
      from ingest.partner_catalog_staging_rows sr
     where sr.run_id = p_run_id and sr.id = any (p_row_ids);
    -- Cinquième passe (30/09) : une ligne sortie du run (remplacée par
    -- « Retraiter » depuis le chargement de l'écran) est ignorée aussi, au
    -- lieu du refus en bloc sans HINT de la fonction d'ingest.
    v_ignorees := (select count(distinct x) from unnest(p_row_ids) x where x is not null) - cardinality(v_ids);
    if v_ignorees > 0 and cardinality(v_ids) = 0 then
      return jsonb_build_object('run_id', p_run_id, 'created_items', 0, 'skipped_rows', v_ignorees);
    end if;
    if v_ignorees = 0 then
      v_ids := p_row_ids;    -- rien d'écarté : l'appel d'avant, tel quel
    end if;
  end if;

  -- Marque la decision accept_duplicate (avec controle de compatibilite +$b$);
  v_def := pg_temp.h21_remplacer('fn_import_reconcile_duplicates (décision)', v_def,
$a$    p_row_ids            := p_row_ids,
    p_editorial_decision := 'accept_duplicate',$a$,
$b$    p_row_ids            := v_ids,
    p_editorial_decision := 'accept_duplicate',$b$);
  v_def := pg_temp.h21_remplacer('fn_import_reconcile_duplicates (exemplaires)', v_def,
$a$    p_row_ids    := p_row_ids,
    p_batch_name := null,$a$,
$b$    p_row_ids    := v_ids,
    p_batch_name := null,$b$);
  v_def := pg_temp.h21_remplacer('fn_import_reconcile_duplicates (retour)', v_def,
$a$    p_created_by := v_actor.user_id
  );
end;$a$,
$b$    p_created_by := v_actor.user_id
  ) || jsonb_build_object('skipped_rows', v_ignorees);
end;$b$);
  EXECUTE v_def;
END
$h21_rapprocher$;

-- Un seul point de passage pour la preuve d'import d'un exemplaire RAPPROCHÉ
-- (sa ligne) : une ligne ne s'efface pas tant qu'un exemplaire rapproché non
-- publié la désigne — suppression du run, « Retraiter » (force_reparse de
-- l'edge function), dépôt d'un fonds qui remplace les lignes. Sans elle,
-- l'exemplaire, sa ligne perdue (clé étrangère SET NULL), se publierait comme
-- un exemplaire fait à la main, sans révision (IMP-27 c).
CREATE OR REPLACE FUNCTION ingest.fn_h21_ligne_retenue_par_exemplaire_rapproche()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
BEGIN
  IF EXISTS (SELECT 1 FROM public.exemplar_drafts x
              WHERE x.import_staging_row_id = OLD.id
                AND x.book_draft_id IS NULL
                AND x.status <> 'published') THEN
    RAISE EXCEPTION 'Linha de importacao % retida por um exemplar aproximado ainda nao publicado.', OLD.id
      USING HINT = 'error.import.rows_held_by_items';
  END IF;
  RETURN OLD;
END
$function$;
REVOKE EXECUTE ON FUNCTION ingest.fn_h21_ligne_retenue_par_exemplaire_rapproche() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_staging_rows_retenue_par_rapproche ON ingest.partner_catalog_staging_rows;
CREATE TRIGGER trg_staging_rows_retenue_par_rapproche
  BEFORE DELETE ON ingest.partner_catalog_staging_rows
  FOR EACH ROW EXECUTE FUNCTION ingest.fn_h21_ligne_retenue_par_exemplaire_rapproche();
-- La garde lit les brouillons d'exemplaire par leur ligne : un index, s'il
-- n'y en a pas déjà un sur cette colonne.
DO $h21_index_exemplaires$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes
                  WHERE schemaname = 'public' AND tablename = 'exemplar_drafts'
                    AND indexdef ~ '\(import_staging_row_id\)') THEN
    CREATE INDEX exemplar_drafts_import_staging_row_idx
      ON public.exemplar_drafts (import_staging_row_id) WHERE import_staging_row_id IS NOT NULL;
  END IF;
END
$h21_index_exemplaires$;

-- « Retraiter » (fn_import_dispatch, force_reparse) : le refus vient tout de
-- suite, à l'écran, avec sa HINT traduite — pas en différé dans l'edge
-- function, qui laisse alors le run en échec et sa file cachée (cinquième
-- passe, 30/09). Deux cas s'ajoutent à la garde H15/H19 :
--  * un exemplaire RAPPROCHÉ à la corbeille : sa ligne est retenue par le
--    déclencheur ci-dessus, l'effacement échouerait ;
--  * une ligne ÉCARTÉE par la purge de son brouillon (IMP-27 e) : la relire la
--    remplacerait par une ligne neuve, promouvable, sans la preuve que lit le
--    rejeu de ce brouillon — deux notices pour une ligne du fichier.
DO $h21_dispatch$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_import_dispatch(bigint, boolean)'::regprocedure);
  v_def := pg_temp.h21_remplacer('fn_import_dispatch (retraiter)', v_def,
$a$                      WHERE sr.run_id = p_run_id AND x.status <> 'cancelled')) THEN$a$,
$b$                      WHERE sr.run_id = p_run_id
                        -- H21 lot 0 : un exemplaire rapproché (sans notice)
                        -- retient sa ligne jusqu'à sa publication, corbeille
                        -- comprise.
                        AND (x.status <> 'cancelled' OR x.book_draft_id IS NULL))
          -- IMP-27 (e) : une ligne écartée garde la preuve que lit le rejeu.
          OR EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows e
                      WHERE e.run_id = p_run_id AND e.discarded_draft_id IS NOT NULL)) THEN$b$);
  EXECUTE v_def;
END
$h21_dispatch$;


-- ─────────────────────────────────────────────────────────────────────
-- 4. IMP-27 (e) : vider la corbeille d'un brouillon importé écarte sa ligne
-- ─────────────────────────────────────────────────────────────────────
-- La clé étrangère de la ligne passe à NULL et le lien part en cascade : sans
-- ceci, la ligne redevenait promouvable, et le journal pouvait ensuite
-- restaurer l'ancien brouillon — deux notices pour une ligne. La ligne garde
-- QUEL brouillon l'a libérée (discarded_draft_id, que l'API n'écrit pas : le
-- schéma ingest lui est fermé) : c'est la preuve que le rejeu de ce brouillon
-- lit pour la reprendre — pas la note ni la décision, que tout geste écrase.
ALTER TABLE ingest.partner_catalog_staging_rows
  ADD COLUMN IF NOT EXISTS discarded_draft_id bigint;
CREATE INDEX IF NOT EXISTS partner_catalog_staging_rows_discarded_draft_idx
  ON ingest.partner_catalog_staging_rows (discarded_draft_id) WHERE discarded_draft_id IS NOT NULL;
COMMENT ON COLUMN ingest.partner_catalog_staging_rows.discarded_draft_id IS
  'IMP-27 e (29/09/2026) : brouillon de notice dont la suppression définitive a écarté cette ligne (sans clé étrangère : le brouillon n''existe plus). Le rejeu de CE brouillon depuis le journal reprend la ligne. Écrit par ingest.fn_h21_ecarter_ligne_du_brouillon_supprime, vidé par la reprise.';

CREATE OR REPLACE FUNCTION ingest.fn_h21_ecarter_ligne_du_brouillon_supprime()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
DECLARE
  v_ids bigint[];
BEGIN
  -- Deux lectures indexées (lien par draft_id, ligne par created_book_draft_id),
  -- jamais « … OR … » sur la table des lignes : « Vider la corbeille » passe ici
  -- pour chaque brouillon, sous le délai de l'API.
  v_ids := ARRAY(SELECT m.staging_row_id FROM ingest.partner_catalog_row_to_draft m WHERE m.draft_id = OLD.id
                 UNION
                 SELECT s.id FROM ingest.partner_catalog_staging_rows s WHERE s.created_book_draft_id = OLD.id);
  IF cardinality(v_ids) = 0 THEN
    RETURN OLD;
  END IF;
  UPDATE ingest.partner_catalog_staging_rows sr
     SET editorial_decision = 'reject',
         editorial_note = format('Rascunho %s (%s) excluido definitivamente: a linha nao volta a ser promovida (IMP-27 e).',
                                 OLD.id, OLD.status),
         editorial_decided_at = now(),
         editorial_decided_by = auth.uid(),
         review_status = 'rejected',
         selected_for_draft = false,
         discarded_draft_id = OLD.id
   WHERE sr.id = ANY (v_ids);
  RETURN OLD;
END
$function$;
REVOKE EXECUTE ON FUNCTION ingest.fn_h21_ecarter_ligne_du_brouillon_supprime() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_book_drafts_ecarte_ligne_importee ON public.book_drafts;
CREATE TRIGGER trg_book_drafts_ecarte_ligne_importee
  BEFORE DELETE ON public.book_drafts
  FOR EACH ROW EXECUTE FUNCTION ingest.fn_h21_ecarter_ligne_du_brouillon_supprime();

-- Et le journal : jamais deux notices pour une ligne, dans aucun ordre — la
-- ligne écartée ne se relit pas (« Retraiter » refusé plus haut ; hors la
-- course entre l'envoi et l'effacement, consignée en tête), ne se
-- re-décide pas (décision éditoriale), et seul son brouillon la reprend.
-- Un run SUPPRIMÉ emporte ses lignes : ses brouillons rejoués reviennent sans
-- lien (règle d'avant), et un nouvel import du fichier est un autre run (le
-- réimport, lots suivants de H21).
--  * une CRÉATION née d'une ligne ne revient pas si cette ligne a, depuis,
--    donné un autre brouillon (réacceptée par l'API puis promue) ; une reprise
--    (« Éditer », published_book_id posé) recopie la trace de sa notice sans
--    être née de la ligne : elle revient ;
--  * une création rejouée reprend la ligne que SA suppression avait écartée
--    (décision reverrouillée, lien rétabli) : une réacceptation ensuite ne fait
--    plus un second brouillon ;
--  * un exemplaire RAPPROCHÉ dont la ligne a disparu ne revient pas : sans elle,
--    il se publierait comme un exemplaire fait à la main (IMP-27 c).
DO $h21_restaurer$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_restore_deleted_draft(bigint)'::regprocedure);
  v_def := pg_temp.h21_remplacer('fn_restore_deleted_draft (ligne repromue)', v_def,
$a$  if v_exists then
    raise exception 'le brouillon % existe deja : rien a rejouer', v_id
      using hint = 'error.catalog.restore_already';
  end if;
$a$,
$b$  if v_exists then
    raise exception 'le brouillon % existe deja : rien a rejouer', v_id
      using hint = 'error.catalog.restore_already';
  end if;

  -- IMP-27 (e) (29/09/2026) : une création née d'une ligne d'import ne revient
  -- pas si cette ligne a, depuis, donné un autre brouillon : deux notices pour
  -- une ligne. Une reprise (published_book_id) n'est pas concernée.
  if v_tbl = 'book_drafts'
     and v_snap ->> 'published_book_id' is null
     and (v_snap #>> '{marc_json,ingest,staging_row_id}') ~ '^[0-9]{1,18}$'
     and exists (select 1 from ingest.partner_catalog_staging_rows sr
                  where sr.id = (v_snap #>> '{marc_json,ingest,staging_row_id}')::bigint
                    and (sr.created_book_draft_id is not null
                         or exists (select 1 from ingest.partner_catalog_row_to_draft m
                                     where m.staging_row_id = sr.id)
                         -- repromue puis purgée à son tour : un autre brouillon
                         -- l'a libérée depuis
                         or (sr.discarded_draft_id is not null and sr.discarded_draft_id <> v_id))) then
    raise exception 'ligne d''import deja repromue : le brouillon % ne revient pas', v_id
      using hint = 'error.catalog.restore_line_repromoted';
  end if;
$b$);
  v_def := pg_temp.h21_remplacer('fn_restore_deleted_draft (exemplaire sans ligne)', v_def,
$a$    if v_snap->>'import_staging_row_id' is not null
       and not exists (select 1 from ingest.partner_catalog_staging_rows sr
                        where sr.id = (v_snap->>'import_staging_row_id')::bigint) then
      v_snap := jsonb_set(v_snap, '{import_staging_row_id}', 'null'::jsonb);$a$,
$b$    if v_snap->>'import_staging_row_id' is not null
       and not exists (select 1 from ingest.partner_catalog_staging_rows sr
                        where sr.id = (v_snap->>'import_staging_row_id')::bigint) then
      -- IMP-27 (c) (29/09/2026) : un exemplaire RAPPROCHÉ (sans notice) n'a
      -- d'autre preuve d'import que sa ligne ; elle a disparu (run supprimé).
      if v_snap->>'book_draft_id' is null then
        raise exception 'la ligne d''import de l''exemplaire % a disparu : il ne revient pas', v_id
          using hint = 'error.catalog.restore_item_import_gone';
      end if;
      v_snap := jsonb_set(v_snap, '{import_staging_row_id}', 'null'::jsonb);$b$);
  v_def := pg_temp.h21_remplacer('fn_restore_deleted_draft (ligne reprise)', v_def,
$a$  execute format(
    'insert into public.%I select * from jsonb_populate_record(null::public.%I, $1)', v_tbl, v_tbl)
    using v_snap;
$a$,
$b$  execute format(
    'insert into public.%I select * from jsonb_populate_record(null::public.%I, $1)', v_tbl, v_tbl)
    using v_snap;

  -- IMP-27 (e) (29/09/2026) : un brouillon rejoué reprend la ligne d'import
  -- que SA suppression avait écartée — la ligne le dit (discarded_draft_id,
  -- écrit par le déclencheur d'écartement, que l'API n'atteint pas), quelle
  -- que soit sa décision depuis et même si le lot a changé de bibliothèque —,
  -- si elle est restée libre : la décision se reverrouille, et le lien, preuve
  -- d'import, revient (sans lot de promotion : il n'y en a plus). Une ligne
  -- repromue entre-temps a été refusée plus haut.
  if v_tbl = 'book_drafts' then
    update ingest.partner_catalog_staging_rows sr
       set created_book_draft_id = v_id,
           editorial_decision = 'accept_new',
           editorial_note = format('Rascunho %s restaurado do diario: a linha volta a ele (IMP-27 e).', v_id),
           editorial_decided_at = now(),
           editorial_decided_by = auth.uid(),
           review_status = 'draft_created',
           selected_for_draft = false,
           discarded_draft_id = null
     where sr.discarded_draft_id = v_id
       and sr.match_status = 'new_record'
       and sr.created_book_draft_id is null
       and not exists (select 1 from ingest.partner_catalog_row_to_draft m where m.staging_row_id = sr.id);
    if found then
      insert into ingest.partner_catalog_row_to_draft (staging_row_id, run_id, draft_id, batch_id, created_by)
      select sr.id, sr.run_id, v_id, null, auth.uid()
        from ingest.partner_catalog_staging_rows sr
       where sr.created_book_draft_id = v_id;
    end if;
  end if;
$b$);
  EXECUTE v_def;
END
$h21_restaurer$;


-- ─────────────────────────────────────────────────────────────────────
-- 4 bis. IMP-27 (a) : la trace d'import ne se réécrit pas par l'API
-- ─────────────────────────────────────────────────────────────────────
-- La trace marc_json.ingest prouve seule qu'un brouillon sans lien (run
-- supprimé, rejeu du journal) vient d'un import ; published_book_id fait d'un
-- brouillon une reprise, que la règle (a) ne garde pas. Pour le rôle de l'API,
-- sur un brouillon qui porte la trace : la trace reste celle qu'elle était, et
-- une création ne devient pas une reprise. Silencieux, comme le pont de
-- provenance : le formulaire renvoie tout le brouillon, trace comprise.
CREATE OR REPLACE FUNCTION public.tg_book_drafts_trace_import_figee()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF coalesce(OLD.marc_json, '{}'::jsonb) ? 'ingest' THEN
    IF (NEW.marc_json -> 'ingest') IS DISTINCT FROM (OLD.marc_json -> 'ingest') THEN
      NEW.marc_json := jsonb_set(coalesce(NEW.marc_json, '{}'::jsonb), '{ingest}', OLD.marc_json -> 'ingest');
    END IF;
    IF OLD.published_book_id IS NULL AND NEW.published_book_id IS NOT NULL THEN
      NEW.published_book_id := NULL;
    END IF;
  END IF;
  RETURN NEW;
END
$function$;
REVOKE EXECUTE ON FUNCTION public.tg_book_drafts_trace_import_figee() FROM PUBLIC, anon, authenticated;

-- Seule la publication (publish_book_draft, fonction DEFINER) met un brouillon
-- de notice au statut « publié » : posé par l'API, il faisait publier seuls les
-- exemplaires rattachés d'une notice jamais révisée. Le formulaire ne poste
-- que 'draft' ou 'ready' ; un brouillon déjà publié qu'on réenregistre garde
-- son statut (inchangé : rien n'est refusé).
CREATE OR REPLACE FUNCTION public.tg_book_drafts_statut_publie_reserve()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF NEW.status = 'published' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'published') THEN
    RAISE EXCEPTION 'Somente a publicacao poe um rascunho em published.'
      USING ERRCODE = '42501', HINT = 'error.publish.status_reserved';
  END IF;
  RETURN NEW;
END
$function$;
REVOKE EXECUTE ON FUNCTION public.tg_book_drafts_statut_publie_reserve() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS book_drafts_statut_publie_reserve ON public.book_drafts;
CREATE TRIGGER book_drafts_statut_publie_reserve
  BEFORE INSERT OR UPDATE OF status ON public.book_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_book_drafts_statut_publie_reserve();

-- De même pour un brouillon d'exemplaire : seule publish_exemplar_draft (ou
-- publish_book_draft, qui l'appelle) le publie. Posé par l'API, « publié »
-- libérait le run d'un exemplaire rapproché (fn_import_delete_run ne retient
-- que draft, ready et la corbeille), et l'exemplaire, sa ligne perdue, se
-- publiait ensuite comme fait à la main (IMP-27 c). Même fonction : elle ne
-- lit que le statut.
DROP TRIGGER IF EXISTS exemplar_drafts_statut_publie_reserve ON public.exemplar_drafts;
CREATE TRIGGER exemplar_drafts_statut_publie_reserve
  BEFORE INSERT OR UPDATE OF status ON public.exemplar_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_book_drafts_statut_publie_reserve();
DROP TRIGGER IF EXISTS book_drafts_trace_import_figee ON public.book_drafts;
CREATE TRIGGER book_drafts_trace_import_figee
  BEFORE UPDATE OF marc_json, published_book_id ON public.book_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_book_drafts_trace_import_figee();


-- ─────────────────────────────────────────────────────────────────────
-- 5. Vérification (structurelle : les migrations passent avant le seed)
-- ─────────────────────────────────────────────────────────────────────
DO $h21_verif$
DECLARE
  v_e text := '';
  v_def text;
  v_n int;
  k_elig constant text := 'and sr.match_status = ''new_record'' and sr.editorial_decision = ''accept_new''';
BEGIN
  -- une signature par nom (PostgREST hésiterait sinon, PGRST203)
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname IN ('public', 'ingest', 'api')
     AND p.proname IN ('fn_import_promote', 'fn_bulk_create_book_drafts_from_run', 'fn_create_item_drafts_for_batch', 'fn_batch_reviews_list');
  IF v_n <> 4 THEN v_e := v_e || format(' signatures(%s)', v_n); END IF;

  v_def := pg_get_functiondef('ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure);
  IF position('accept_duplicate' IN v_def) > 0 OR (length(v_def) - length(replace(v_def, k_elig, ''))) / length(k_elig) <> 3
     OR position('v_lot_repris' IN v_def) = 0 THEN v_e := v_e || ' creation'; END IF;
  v_def := pg_get_functiondef('ingest.fn_bulk_create_book_drafts_from_run(bigint, text[], text[], text, text, uuid, bigint[])'::regprocedure);
  IF position('accept_duplicate' IN v_def) > 0 OR position(k_elig IN v_def) = 0
     OR position('and (p_row_ids is null or sr.id = any (p_row_ids))' IN v_def) = 0 THEN v_e := v_e || ' bulk'; END IF;
  v_def := pg_get_functiondef('public.fn_import_promote(bigint, text[], text[], text, text, bigint[])'::regprocedure);
  IF position('accept_duplicate' IN v_def) > 0 OR v_def !~ 'p_row_ids\s+:=\s*p_row_ids'
     OR position('error.import.deposit_admin_only' IN v_def) = 0 OR position('owner_library_id' IN v_def) = 0
     OR position('selected_row_ids' IN v_def) = 0 THEN v_e := v_e || ' promote'; END IF;

  v_def := pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure);
  IF position('error.publish.imported_needs_batch' IN v_def) = 0 OR position('error.publish.added_after_review' IN v_def) = 0
     OR position('error.publish.imported_needs_batch' IN v_def) < position('error.publish.review_required' IN v_def)
     OR position('error.publish.added_after_review' IN v_def) > position('error.publish.titulo_required' IN v_def)
     OR position('item_tag' IN v_def) = 0 THEN v_e := v_e || ' publier-notice'; END IF;
  v_def := pg_get_functiondef('public.publish_exemplar_draft(bigint)'::regprocedure);
  IF position('ingest.fn_h20_cle_de_la_ligne(v_draft.import_staging_row_id)' IN v_def) = 0
     OR position('select sr.external_key from' IN v_def) > 0
     OR position('error.publish.added_after_review' IN v_def) = 0 THEN v_e := v_e || ' publier-exemplaire'; END IF;
  v_def := pg_get_functiondef('ingest.fn_h20_identifiant_d_origine(bigint)'::regprocedure);
  IF position('ingest.fn_h20_cle_de_la_ligne(rd.staging_row_id)' IN v_def) = 0 THEN v_e := v_e || ' juge'; END IF;
  v_def := pg_get_functiondef('public.fn_batch_is_imported(bigint)'::regprocedure);
  IF position('m.draft_id = d.id' IN v_def) = 0 OR position('x.import_staging_row_id is not null' IN v_def) = 0 THEN v_e := v_e || ' lot-importe'; END IF;
  v_def := pg_get_functiondef('public.fn_batch_review_request(bigint, text)'::regprocedure);
  IF position('exemplar_draft_ids' IN v_def) = 0 OR position('fn_batch_ajouts_apres_revision' IN v_def) = 0 THEN v_e := v_e || ' demande'; END IF;
  IF position('error.import.run_has_linked_drafts' IN pg_get_functiondef('public.fn_import_delete_run(bigint)'::regprocedure)) = 0 THEN v_e := v_e || ' suppression-run'; END IF;
  IF position('error.import.rattacher_par_rapprocher' IN pg_get_functiondef('public.fn_import_set_editorial(bigint, bigint[], text, text)'::regprocedure)) = 0 THEN v_e := v_e || ' decision'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_book_drafts_ecarte_ligne_importee' AND tgrelid = 'public.book_drafts'::regclass) THEN v_e := v_e || ' declencheur'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'book_drafts_trace_import_figee' AND tgrelid = 'public.book_drafts'::regclass) THEN v_e := v_e || ' trace-figee'; END IF;
  IF position('error.catalog.restore_line_repromoted' IN pg_get_functiondef('public.fn_restore_deleted_draft(bigint)'::regprocedure)) = 0 THEN v_e := v_e || ' restauration'; END IF;
  IF obj_description('public.fn_batch_reviews_list()'::regprocedure, 'pg_proc') IS NULL THEN v_e := v_e || ' commentaire-liste'; END IF;
  -- seconde passe (revue du 29/09)
  IF EXISTS (SELECT 1 FROM public.catalog_batch_reviews WHERE draft_ids IS NULL OR exemplar_draft_ids IS NULL) THEN v_e := v_e || ' rattrapage'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'book_drafts_statut_publie_reserve' AND tgrelid = 'public.book_drafts'::regclass) THEN v_e := v_e || ' statut-reserve'; END IF;
  IF position('error.import.run_has_trashed_items' IN pg_get_functiondef('public.fn_import_delete_run(bigint)'::regprocedure)) = 0 THEN v_e := v_e || ' run-corbeille'; END IF;
  v_def := pg_get_functiondef('public.fn_restore_deleted_draft(bigint)'::regprocedure);
  IF position('error.catalog.restore_item_import_gone' IN v_def) = 0 OR position('restaurado do diario' IN v_def) = 0
     OR position('v_snap ->> ''published_book_id'' is null' IN v_def) = 0 THEN v_e := v_e || ' restauration-2'; END IF;
  IF position('bd.published_book_id is null then' IN pg_get_functiondef('public.publish_exemplar_draft(bigint)'::regprocedure)) = 0 THEN v_e := v_e || ' exemplaire-notice-publiee'; END IF;
  IF position('skipped_rows' IN pg_get_functiondef('public.fn_import_set_editorial(bigint, bigint[], text, text)'::regprocedure)) = 0 THEN v_e := v_e || ' decision-convertie'; END IF;
  -- troisième passe
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'exemplar_drafts_statut_publie_reserve' AND tgrelid = 'public.exemplar_drafts'::regclass) THEN v_e := v_e || ' statut-reserve-exemplaire'; END IF;
  IF position('discarded_draft_id = OLD.id' IN pg_get_functiondef('ingest.fn_h21_ecarter_ligne_du_brouillon_supprime()'::regprocedure)) = 0
     OR position('sr.discarded_draft_id = v_id' IN pg_get_functiondef('public.fn_restore_deleted_draft(bigint)'::regprocedure)) = 0
     OR position('editorial_note like' IN pg_get_functiondef('public.fn_restore_deleted_draft(bigint)'::regprocedure)) > 0 THEN v_e := v_e || ' preuve-ecartement'; END IF;
  -- quatrième passe
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_staging_rows_retenue_par_rapproche' AND tgrelid = 'ingest.partner_catalog_staging_rows'::regclass) THEN v_e := v_e || ' ligne-retenue'; END IF;
  IF position('skipped_rows' IN pg_get_functiondef('public.fn_import_reconcile_duplicates(bigint, bigint[])'::regprocedure)) = 0 THEN v_e := v_e || ' rapprocher-filtre'; END IF;
  IF position('AND sr.discarded_draft_id IS NULL' IN pg_get_functiondef('public.fn_import_set_editorial(bigint, bigint[], text, text)'::regprocedure)) = 0 THEN v_e := v_e || ' decision-ecartee'; END IF;
  IF position('sr.discarded_draft_id <> v_id' IN pg_get_functiondef('public.fn_restore_deleted_draft(bigint)'::regprocedure)) = 0 THEN v_e := v_e || ' garde-ecartee'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'exemplar_drafts'
                    AND indexdef ~ '\(import_staging_row_id\)') THEN v_e := v_e || ' index-exemplaires'; END IF;
  IF has_function_privilege('authenticated', 'private.fn_h21_rattraper_listes_des_tours()', 'EXECUTE')
     OR has_function_privilege('anon', 'private.fn_h21_rattraper_listes_des_tours()', 'EXECUTE') THEN v_e := v_e || ' droits-rattrapage'; END IF;
  IF position('une valeur saisie à la main reste' IN pg_get_functiondef('ingest.fn_h20_effacer_faux_identifiants(bigint)'::regprocedure)) = 0 THEN v_e := v_e || ' effaceur'; END IF;
  v_def := pg_get_functiondef('ingest.fn_h21_ecarter_ligne_du_brouillon_supprime()'::regprocedure);
  IF position('cardinality(v_ids)' IN v_def) = 0 OR position('OR sr.created_book_draft_id' IN v_def) > 0 THEN v_e := v_e || ' ecartement-indexe'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'ingest' AND tablename = 'partner_catalog_staging_rows'
                    AND indexdef ~ '\(created_book_draft_id\)') THEN v_e := v_e || ' index-created_book_draft_id'; END IF;
  IF to_regclass('ingest.partner_catalog_staging_rows_run_cle_idx') IS NULL THEN v_e := v_e || ' index'; END IF;
  -- cinquième passe
  v_def := pg_get_functiondef('public.fn_import_dispatch(bigint, boolean)'::regprocedure);
  IF position('OR x.book_draft_id IS NULL' IN v_def) = 0 OR position('e.discarded_draft_id IS NOT NULL' IN v_def) = 0
     OR position('error.import.reparse_after_promotion' IN v_def) = 0 THEN v_e := v_e || ' retraiter'; END IF;
  IF position('count(DISTINCT x) FROM unnest(p_row_ids)' IN pg_get_functiondef('public.fn_import_set_editorial(bigint, bigint[], text, text)'::regprocedure)) = 0
     OR position('count(distinct x) from unnest(p_row_ids)' IN pg_get_functiondef('public.fn_import_reconcile_duplicates(bigint, bigint[])'::regprocedure)) = 0 THEN
    v_e := v_e || ' lignes-sorties';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.fn_import_dispatch(bigint, boolean)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_import_dispatch(bigint, boolean)', 'EXECUTE') THEN v_e := v_e || ' droits-retraiter'; END IF;
  -- sixième passe
  IF position('and not (v_draft.status = ''published'' and v_draft.published_exemplar_id is not null) then' IN pg_get_functiondef('public.publish_exemplar_draft(bigint)'::regprocedure)) = 0 THEN v_e := v_e || ' republier-hors-lot'; END IF;
  IF position('and not (v_draft.status = ''published'' and v_draft.published_book_id is not null)' IN pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure)) = 0 THEN v_e := v_e || ' republier-notice-hors-lot'; END IF;
  IF position('and sr.proposed_book_id is not null' IN pg_get_functiondef('public.fn_import_reconcile_duplicates(bigint, bigint[])'::regprocedure)) = 0 THEN v_e := v_e || ' rapprocher-eligibilite'; END IF;

  -- droits : l'écran garde les siens, les aides internes restent fermées
  IF EXISTS (SELECT 1 FROM unnest(ARRAY[
        'public.fn_import_promote(bigint, text[], text[], text, text, bigint[])', 'public.publish_book_draft(bigint)',
        'public.publish_exemplar_draft(bigint)', 'public.fn_import_delete_run(bigint)',
        'public.fn_import_set_editorial(bigint, bigint[], text, text)', 'public.fn_batch_review_request(bigint, text)',
        'public.fn_batch_reviews_list()']) f
      WHERE NOT has_function_privilege('authenticated', f, 'EXECUTE') OR has_function_privilege('anon', f, 'EXECUTE')) THEN
    v_e := v_e || ' droits-ecran';
  END IF;
  IF EXISTS (SELECT 1 FROM unnest(ARRAY[
        'ingest.fn_h20_cle_de_la_ligne(bigint)', 'ingest.fn_h20_identifiant_d_origine(bigint)',
        'public.fn_book_draft_is_imported(bigint)', 'public.fn_batch_is_imported(bigint)',
        'public.fn_batch_review_couvre(bigint, bigint, text)', 'public.fn_batch_ajouts_apres_revision(bigint)',
        'ingest.fn_bulk_create_book_drafts_from_run(bigint, text[], text[], text, text, uuid, bigint[])',
        'ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)',
        'ingest.fn_create_item_drafts_for_batch(bigint, uuid, bigint[])']) f
      WHERE has_function_privilege('authenticated', f, 'EXECUTE') OR has_function_privilege('anon', f, 'EXECUTE')
         OR NOT has_function_privilege('service_role', f, 'EXECUTE')) THEN
    v_e := v_e || ' droits-internes';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
              WHERE p.oid IN ('public.fn_import_promote(bigint, text[], text[], text, text, bigint[])'::regprocedure,
                              'ingest.fn_bulk_create_book_drafts_from_run(bigint, text[], text[], text, text, uuid, bigint[])'::regprocedure,
                              'ingest.fn_create_item_drafts_for_batch(bigint, uuid, bigint[])'::regprocedure,
                              'public.fn_batch_reviews_list()'::regprocedure)
                AND a.grantee = 0) THEN
    v_e := v_e || ' droits-public';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE (n.nspname, p.proname) IN (('public', 'fn_import_promote'), ('ingest', 'fn_bulk_create_book_drafts_from_run'),
                                                ('ingest', 'fn_create_item_drafts_for_batch'), ('public', 'fn_batch_reviews_list'),
                                                ('ingest', 'fn_h20_cle_de_la_ligne'), ('public', 'fn_book_draft_is_imported'),
                                                ('public', 'fn_batch_review_couvre'), ('public', 'fn_batch_ajouts_apres_revision'),
                                                ('ingest', 'fn_h21_ecarter_ligne_du_brouillon_supprime'))
                AND (NOT p.prosecdef OR coalesce(p.proconfig::text, '') NOT LIKE '%search_path%')) THEN
    v_e := v_e || ' definer';
  END IF;

  IF v_e <> '' THEN
    RAISE EXCEPTION 'H21 lot 0 : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'H21 lot 0 : vérifications OK';
END
$h21_verif$;

NOTIFY pgrst, 'reload schema';
