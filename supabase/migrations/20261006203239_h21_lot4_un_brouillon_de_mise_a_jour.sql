-- =====================================================================
-- H21 lot 4 — seule détentrice : un brouillon de mise à jour
-- (REGISTRE IMP-23, IMP-26, IMP-27, IMP-28, IMP-29, IMP-30, IMP-31 ;
-- cartographie H21 du 28/09, §5.4, §5.8 ligne « 4 », pièges 12, 13, 14,
-- 17, 18, 19 et 20)
--
-- Décisions de Xavier du 06/10/2026 (IMP-31) :
--  (a) un brouillon de mise à jour naît d'un GESTE, « Préparer la mise à
--      jour », sur les lignes known_record sélectionnées (comme « Créer » pour
--      les nouveautés) — jamais d'office ;
--  (b) seuls les champs bibliographiques au verdict source_seule (changés dans
--      le fichier seulement) sont appliqués. Les responsabilités
--      (contributors) au verdict source_seule sont MONTRÉES (brouillon,
--      révision), jamais appliquées : les liens d'autorité restent intacts.
--      conflit : signalé, jamais appliqué ; sans_base : à revoir, jamais
--      appliqué ; local_seul : AnarBib gardé.
-- Décisions de Xavier du 06/10/2026 (sur le rapport du lot), même IMP-31 :
--  (c) un champ que le fichier VIDE (B = A non vide, N vide : source_seule)
--      est MONTRÉ, jamais appliqué, comme les responsabilités (raison
--      « efface_par_la_source ») ; la base le garde (règle 3) ; une ligne dont
--      le seul changement applicable est un effacement : rien_a_appliquer ;
--  (d) « Préparer la mise à jour » et « Rapprocher » sont deux gestes
--      INDÉPENDANTS, dans n'importe quel ordre : une ligne rapprochée se
--      prépare (et une ligne préparée se rapproche, comme avant) — y compris
--      celle que « Rapprocher » a marquée rejetée parce que tous ses
--      exemplaires étaient déjà là (H19 : ce n'est pas un choix de rejeter la
--      notice) ; « Rejeter » une ligne préparée est IGNORÉ (skipped_rows,
--      fn_import_set_editorial, comme une ligne convertie au lot 0) — le
--      brouillon se retire depuis le catalogage ;
--  (e) une mise à jour supprimée définitivement écarte sa ligne (IMP-27 e).
--
-- 1. Le geste : public.fn_import_preparer_mises_a_jour(p_run_id, p_row_ids).
--    Accès de fn_import_set_editorial (la coordination de la bibliothèque du
--    run, ou l'administration du réseau dont la bibliothèque active est celle
--    du run ; un dépôt compagnon ou un entrepôt OAI : l'administration seule,
--    comme fn_import_promote) ; verrou du run FOR NO KEY UPDATE après l'accès
--    (H31) ; une page de 200 lignes au plus. La comparaison à trois états est
--    RECALCULÉE dans la transaction (ingest.fn_h21_stocker_comparaisons, lot
--    3 : la liste et le rapport voient la même). Chaque ligne est préparée ou
--    IGNORÉE avec sa raison — jamais de refus en bloc (doctrine du lot 0) :
--      hors_run        la ligne n'est pas (plus) dans ce run ;
--      pas_reconnue    pas known_record, ou sans notice proposée ;
--      rejetee         rejetée par choix, ou écartée (IMP-27 e) —
--                      ingest.fn_h21_rejet_par_choix : pas le rejet que
--                      « Rapprocher » pose quand tous les exemplaires sont
--                      déjà là (H19), décision (d) ;
--      deja_preparee   la ligne a déjà un brouillon (lien row_to_draft, un
--                      seul par ligne, quel qu'en soit le statut — corbeille
--                      comprise : seule sa restauration le reprend), ou la
--                      notice a déjà un brouillon de mise à jour d'import
--                      vivant (brouillon, prêt) ;
--      plus_detenue    la bibliothèque qui importe
--                      (ingest.fn_h21_bibliotheque_importatrice) ne détient
--                      plus la notice (book_holdings — piège 18 : jamais
--                      owner_library_id) ;
--      partagee        une autre bibliothèque la détient aussi (IMP-26 a :
--                      un réimport ne réécrit jamais une notice partagée —
--                      son signalement est le lot 5) ; AUCUNE écriture ;
--      non_comparee    pas de comparaison (filet : notice disparue) ;
--      sans_base       pas de base pour cet identifiant (tout serait « à
--                      revoir ») ;
--      rien_a_appliquer aucun champ source_seule hors responsabilités dont le
--                      fichier donne une valeur (un effacement ne
--                      s'applique pas, décision (c)).
--    Rend {run_id, batch_id, asked, prepared, skipped_rows, skipped:{raison:n},
--    drafts:[{row_id, draft_id, book_id, applied:[champs]}]}.
--
-- 2. Le brouillon : une COPIE COMPLÈTE de la notice
--    (ingest.fn_h21_copie_de_la_notice, sur le modèle de
--    create_book_draft_from_book, qui ne vérifie pas la détention — piège 17 —
--    et que le geste ne lui emprunte donc pas), puis le patch des SEULS champs
--    source_seule hors responsabilités dont le fichier donne une valeur, avec
--    cette valeur telle que la comparaison l'a normalisée (nullif(btrim)) ; un
--    champ que le fichier vide est montré, jamais vidé (décision (c)). Jamais en posant
--    published_book_id sur le brouillon importé (piège 12) : la copie a, comme
--    toute reprise, sa notice pour published_book_id, et ses responsabilités,
--    vedettes (déclencheurs de semis) et ressources numériques sont celles de
--    la notice, liens d'autorité compris.
--    - Provenance INTACTE (piège 13) : source_record_id, partner_source,
--      import_format, textes owner/holder, marc_json.ingest sont ceux de la
--      notice. La trace de la mise à jour va dans une clé à part,
--      marc_json.ingest_update : run, ligne, clé, bibliothèque, notice,
--      identifiant d'origine, base, champs appliqués (b, a, n), champs MONTRÉS
--      non appliqués (responsabilités source_seule, effacements par la source
--      — raison « efface_par_la_source » —, conflits, sans_base),
--      verdict et n normalisé des 24 champs, N brut (mapped, contributors,
--      subjects, version, empreinte du fichier), empreinte de la notice (A),
--      empreinte de la base. L'API ne la réécrit pas
--      (tg_book_drafts_trace_import_figee, étendu : remise en silence, comme
--      marc_json.ingest ; published_book_id figé de même). La publication ne
--      la recopie pas sur la notice (books.marc_json reste celui d'avant).
--    - Rejoint le lot ouvert du run (IMP-27 d ; un lot a une bibliothèque,
--      B30 : celle qui importe) ou en ouvre un ; la ligne est liée par
--      ingest.partner_catalog_row_to_draft (que l'API n'écrit pas) : preuve
--      d'import, révision obligatoire (fn_batch_is_imported,
--      fn_book_draft_is_imported), suppression définitive = ligne écartée
--      (IMP-27 e). PAS created_book_draft_id : cette colonne dit « la ligne
--      est devenue une notice » (promotion, journal, écran) — une ligne
--      known_record ne devient jamais une création.
--    - retake_untouched FAUX : une reprise vierge est cachée de la file et
--      oubliée par le job horaire (20261003202521) ; la copie naît avec
--      created_at = clock_timestamp() (≠ now()), que le déclencheur lit comme
--      une reprise qui n'est pas « vierge ».
--
-- 3. La base (IMP-29) à la publication (ingest.fn_h21_avancer_base_apres_mise_a_jour) :
--    pour chaque champ comparé, la base AVANCE à N si la notice publiée dit N
--    (valeur normalisée, après publication) ; sinon elle GARDE B.
--      - source_seule appliqué : A = N après publication → B := N ;
--      - identique / inchange : A = N → B := N ;
--      - conflit, sans_base, contributors et effacements non appliqués :
--        A ≠ N → B gardé —
--        le signal se répète au réimport suivant (« un signal répété plutôt
--        qu'un oubli ») ;
--      - local_seul : B = N déjà (gardé) ;
--      - un champ appliqué puis retouché à la main dans le brouillon (A ≠ N) :
--        B gardé — le geste local reste un geste local au prochain réimport.
--    Le reste suit le fichier accepté : run, ligne, raw_payload (relu sur la
--    ligne : l'export le réémet d'abord — piège 14 —), version, empreinte ;
--    les clés de mapped non comparées (autor) ; les vedettes brutes
--    (subjects) suivent notas, qui les porte (IMP-30). Un champ douteux d'une
--    base reprise (piège 20) qui avance n'est plus douteux ; plus aucun champ
--    douteux : origine 'import'. Le résultat (avancés, gardés) est noté dans
--    marc_json.ingest_update.publication du brouillon.
--    La base n'avance qu'à la PREMIÈRE publication (statut ≠ published).
--    Republier une mise à jour déjà publiée est une retouche (IMP-27 b) : les
--    contrôles d'empreinte, de base, de lien et d'identifiant sont sautés (la
--    première publication a changé la notice et la base), mais la
--    bibliothèque doit être ENCORE la seule détentrice (IMP-26 a : un
--    réimport ne réécrit jamais une notice partagée) et bib_ref être celui de
--    la notice (piège 12) — revue sceptique du 06/10 : une republication
--    rétablissait le titre et la bib_ref de la copie périmée sur une notice
--    qu'une autre bibliothèque détenait, et renommait son exemplaire.
--
-- 4. La garde de publication (ingest.fn_h21_garde_mise_a_jour, appelée par la
--    branche update de publish_book_draft — définition VIVANTE, par ancres —
--    après les portes de révision, la notice verrouillée) ; refus traduits :
--      error.publish.update_import_row_gone   la trace sans son lien d'import ;
--      error.publish.update_shared_record     la bibliothèque n'est plus la
--                                             seule détentrice ;
--      error.publish.update_origin_moved      l'identifiant d'origine ne
--                                             désigne plus cette notice ;
--      error.publish.update_bib_ref_changed   bib_ref du brouillon ≠ celui de
--                                             la notice (piège 12 : il
--                                             renommerait les exemplaires des
--                                             autres) ;
--      error.publish.update_baseline_changed  la base a changé ;
--      error.publish.update_record_changed    la notice a changé depuis la
--                                             préparation (empreinte de A).
--    L'empreinte de A (ingest.fn_h21_empreinte_notice) porte sur ce que la
--    publication réécrit : les colonnes de books moins celles que la branche
--    update n'écrit pas ou qui bougent sans catalogage (id, available_count,
--    horodatages et auteurs de modification — piège 19 —, catalog_source,
--    circulation_default, owner/holder_library_id, publisher_id, work_id,
--    expression_id, title_nonfiling, issue_key, colonnes héritées), plus les
--    responsabilités (liens d'autorité compris), les vedettes et les
--    ressources numériques (colonnes que la publication réécrit).
--    La publication passe par la branche update EXISTANTE.
--    Avant le choix de branche : un brouillon qui porte ingest_update et n'a
--    plus de notice visée (published_book_id NULL : la notice a été retirée,
--    discard_book_cascade, et la clé étrangère l'a vidé sous le rôle
--    propriétaire) est refusé (error.import.update_record_gone) — sinon la
--    branche création faisait naître une notice neuve, avec fonds, exemplaire
--    automatique, identifiant d'origine et base de l'ancien run (revue
--    sceptique du 06/10).
--    api.merge_draft_into_book refuse d'absorber un brouillon de mise à jour
--    (error.import.update_draft_not_mergeable) : elle n'a ni garde de
--    détention ni révision, et poserait la base depuis le marc_json.ingest
--    COPIÉ de la notice (l'ancienne provenance).
--
-- 5. L'écran : fn_import_list_run_rows (DROP + CREATE, colonnes d'avant à
--    leur place) rend update_applicable (champs source_seule hors
--    responsabilités de la comparaison valide), update_draft_id et
--    update_draft_status ; fn_batch_review_report gagne la clé
--    prepared_updates (brouillons de mise à jour du lot : champs appliqués,
--    champs montrés non appliqués, 40 exemples).
--
-- 6. Performance : une page de 200 lignes préparées (comparaison recalculée,
--    copie, patch, lien), mesurée au banc privé
--    (tests/sql/h21_lot4_mise_a_jour_tests.sql, T18 ; 200 notices, base, 2
--    responsabilités chacune, statistiques à jour, sous le jeton de la
--    coordination) : 2,0 à 3,0 s sur 5 tirs du 06/10 (poste partagé) — environ
--    10 à 15 ms par ligne préparée (copie et ses déclencheurs, ressources,
--    patch, correspondance rejouée pour N brut, lien), sous le plafond de 8 s.
--
-- 7. Les deux gestes indépendants (décision (d)) : fn_import_set_editorial
--    ignore une ligne préparée (lien row_to_draft) ; « Rapprocher » ne lit pas
--    ce lien (inchangé) ; la liste rend update_applicable = 0 pour une ligne
--    rejetée par choix ou écartée, et l'écran coche une ligne rapprochée qui a
--    une mise à jour à préparer. Consigné : « Rejeter » une ligne que
--    « Rapprocher » a déjà marquée rejetée (H19) est ignoré (lot 0, 30/09) : sa
--    raison reste celle de H19, et elle reste préparable.
--
-- Méthode : chaque fonction existante est modifiée SUR SA DÉFINITION VIVANTE
-- (pg_get_functiondef, retours chariot retirés) par ancres comptées ; DROP +
-- CREATE pour fn_import_list_run_rows seulement (RETURNS TABLE change), droits
-- restaurés. md5 de prosrc lus le 06/10 en production et sur le banc
-- reconstruit depuis le dépôt (identiques) :
--   public.publish_book_draft                b298422dd1c00cae019ee9c98713018e
--   public.fn_import_list_run_rows           955f206751076fe111b71ea7b9a29632
--   public.fn_batch_review_report            9be6411c5df3a86d22b13841cdc2f010
--   public.fn_import_set_editorial           36cb4511cc87e524ec36f5f028c6dfef
--   api.merge_draft_into_book                86fe4c68f1cde726ab8db81ddf4f9d8a
--   public.tg_book_drafts_trace_import_figee (banc = dépôt)
-- Suite : tests/sql/h21_lot4_mise_a_jour_tests.sql.
-- =====================================================================

-- Outils de la migration, éphémères (pg_temp).
CREATE OR REPLACE FUNCTION pg_temp.h21l4_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'H21 lot 4 — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN
    RAISE EXCEPTION 'H21 lot 4 — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

CREATE OR REPLACE FUNCTION pg_temp.h21l4_def(p_fn regprocedure)
RETURNS text LANGUAGE sql AS $f$
  SELECT replace(pg_get_functiondef(p_fn), E'\r', '');
$f$;


-- ─────────────────────────────────────────────────────────────────────
-- 1. Les empreintes : la notice (A), la base
-- ─────────────────────────────────────────────────────────────────────
-- Ce que la publication d'une mise à jour réécrirait (voir l'en-tête, 4).
-- NULL si la notice n'existe pas.
CREATE OR REPLACE FUNCTION ingest.fn_h21_empreinte_notice(p_book_id bigint)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select md5(jsonb_build_array(
    (select to_jsonb(b) - array['id', 'available_count', 'created_at', 'created_by', 'updated_at', 'updated_by',
                                'last_cataloged_at', 'catalog_source', 'circulation_default', 'owner_library_id',
                                'holder_library_id', 'publisher_id', 'work_id', 'expression_id', 'title_nonfiling',
                                'issue_key', 'autores_secundarios', 'assuntos', 'tradutor', 'organizador']
       from public.books b where b.id = p_book_id),
    (select coalesce(jsonb_agg(jsonb_build_array(c.position, c.name, c.role, c.is_primary, c.author_id, c.nature, c.role_code)
                               order by c.position, c.id), '[]'::jsonb)
       from public.book_contributors c where c.book_id = p_book_id),
    (select coalesce(jsonb_agg(jsonb_build_array(s.subject_id, s.ord) order by s.subject_id), '[]'::jsonb)
       from public.book_subjects s where s.book_id = p_book_id),
    (select coalesce(jsonb_agg(jsonb_build_array(r.id, r.resource_type, r.usage_type, r.access_scope, r.status, r.is_active,
                                                 r.storage_bucket, r.storage_path, r.mime_type, r.label, r.notes, r.metadata,
                                                 r.retired_at, r.language_code, r.source_name, r.source_url,
                                                 r.attribution_text, r.rights_status, r.rights_justification, r.is_primary,
                                                 r.bibliographic_match_validated) order by r.id), '[]'::jsonb)
       from public.book_digital_resources r where r.book_id = p_book_id))::text)
  where exists (select 1 from public.books b where b.id = p_book_id);
$function$;
COMMENT ON FUNCTION ingest.fn_h21_empreinte_notice(bigint) IS
  'H21 lot 4 (06/10/2026) : empreinte de ce que la publication d''une mise à jour réécrirait (colonnes de books écrites par la branche update, responsabilités et liens d''autorité, vedettes, ressources numériques). Interne.';

CREATE OR REPLACE FUNCTION ingest.fn_h21_empreinte_base(p_baseline_id bigint)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select md5(jsonb_build_array(bl.id, bl.external_id_id, bl.mapped, bl.contributors, bl.subjects,
                               bl.reprise_champs_douteux, bl.origine)::text)
    from ingest.book_import_baselines bl
   where bl.id = p_baseline_id;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_empreinte_base(bigint) IS
  'H21 lot 4 (06/10/2026) : empreinte d''une base (ingest.book_import_baselines) — ce que la comparaison en lit. Interne.';


-- Une ligne rejetée PAR CHOIX (« Rejeter », ou écartée par la suppression de
-- son brouillon, IMP-27 e) — pas celle que « Rapprocher » marque rejetée parce
-- que tous ses exemplaires sont déjà dans la bibliothèque (H19, note écrite par
-- ingest.fn_create_exemplar_drafts_from_import_rows, vérifiée en fin de
-- migration) : ce rejet-là ne porte que sur les exemplaires (décision (d)).
CREATE OR REPLACE FUNCTION ingest.fn_h21_rejet_par_choix(p_decision text, p_note text, p_discarded_draft_id bigint)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
 SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
  select p_discarded_draft_id is not null
      or (p_decision = 'reject'
          and coalesce(p_note, '') not like 'Todos os exemplares desta linha ja estao na biblioteca%');
$function$;
COMMENT ON FUNCTION ingest.fn_h21_rejet_par_choix(text, text, bigint) IS
  'H21 lot 4 (06/10/2026) : la ligne est-elle rejetée par choix (« Rejeter ») ou écartée (IMP-27 e) — et non marquée rejetée par « Rapprocher » parce que tous ses exemplaires étaient déjà là (H19) ? Interne.';


-- ─────────────────────────────────────────────────────────────────────
-- 2. Le lot, la copie
-- ─────────────────────────────────────────────────────────────────────
-- IMP-27 (d) : le lot ouvert que ce run a ouvert (promotion ou préparation :
-- un lien row_to_draft), de la bibliothèque qui importe, sans révision
-- demandée ni approuvée ; sinon un lot neuf, de cette bibliothèque (B30).
CREATE OR REPLACE FUNCTION ingest.fn_h21_lot_de_la_mise_a_jour(p_run_id bigint, p_library_id uuid, p_actor uuid)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_batch bigint;
begin
  select b.id into v_batch
    from public.catalog_batches b
   where b.status = 'open'
     and b.library_id is not distinct from p_library_id
     and b.id in (select m.batch_id from ingest.partner_catalog_row_to_draft m
                   where m.run_id = p_run_id and m.batch_id is not null)
     and coalesce(public.fn_batch_review_status(b.id), 'aucune') in ('aucune', 'changes_requested')
   order by b.id desc
   limit 1
   for update of b;
  if v_batch is not null then
    return v_batch;
  end if;

  insert into public.catalog_batches (name, notes, created_by, library_id)
  select format('Atualização do import #%s — %s — %s', p_run_id, left(coalesce(s.partner_name, 'parceiro sem nome'), 80),
                to_char(now() at time zone 'UTC', 'YYYY-MM-DD HH24:MI UTC')),
         format('Lote de atualizações preparado a partir do import run %s (%s, formato %s) — H21 lote 4.',
                p_run_id, coalesce(r.original_filename, 'arquivo sem nome'), coalesce(r.detected_format, 'unknown')),
         p_actor, p_library_id
    from ingest.partner_catalog_import_runs r
    left join ingest.partner_catalog_sources s on s.id = r.source_id
   where r.id = p_run_id
  returning id into v_batch;
  return v_batch;
end;
$function$;

-- La copie complète d'une notice, en brouillon de mise à jour : les colonnes
-- de create_book_draft_from_book (définition du 06/10), pour la bibliothèque
-- qui importe, dans le lot donné. Responsabilités et vedettes : semées par les
-- déclencheurs (trg_seed_draft_contributors, trg_seed_draft_subjects), liens
-- d'autorité compris ; ressources numériques : copy_book_digital_resources_to_draft.
-- created_at = clock_timestamp() : pas une « reprise vierge » (voir l'en-tête, 2).
CREATE OR REPLACE FUNCTION ingest.fn_h21_copie_de_la_notice(p_book_id bigint, p_batch_id bigint, p_library_id uuid, p_actor uuid)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_id bigint;
begin
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
    artigo_source, artigo_volume, artigo_issue, artigo_pages,
    tese_university, tese_advisor, relatorio_org, relatorio_recipient, relatorio_internal_notes,
    zine_format, zine_print_run, zine_technique, distribuidora, gravadora, subjects,
    created_by, updated_by, created_at
  )
  select
    b.id, p_batch_id, 'update', 'draft',
    b.bib_ref, b.titulo, b.subtitulo, b.autor, b.edicao, b.local_publicacao, b.editora, b.ano,
    b.isbn, b.issn, b.serial_id, b.titulo_periodico, b.volume, b.numero, b.fasciculo, b.data_edicao, b.periodicidade,
    b.cdd, b.idioma, b.paginas, b.notas, b.tipo_material, b.loanable, b.colecao,
    b.cover_object_path, b.cover_source, b.cover_license, coalesce(b.marc_json, '{}'::jsonb) - 'ingest_update',
    b.acquisition_mode, b.acquisition_date,
    b.owner_library, b.holder_library,
    p_library_id, b.holder_library_id,
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
    b.artigo_source, b.artigo_volume, b.artigo_issue, b.artigo_pages,
    b.tese_university, b.tese_advisor, b.relatorio_org, b.relatorio_recipient, b.relatorio_internal_notes,
    b.zine_format, b.zine_print_run, b.zine_technique, b.distribuidora, b.gravadora, b.subjects,
    p_actor, p_actor, greatest(clock_timestamp(), now() + interval '1 microsecond')
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
COMMENT ON FUNCTION ingest.fn_h21_copie_de_la_notice(bigint, bigint, uuid, uuid) IS
  'H21 lot 4 (06/10/2026) : copie complète d''une notice en brouillon de mise à jour (modèle create_book_draft_from_book), pour la bibliothèque qui importe, dans le lot donné ; jamais une reprise vierge. Interne : public.fn_import_preparer_mises_a_jour.';


-- ─────────────────────────────────────────────────────────────────────
-- 3. Le geste : préparer la mise à jour
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_import_preparer_mises_a_jour(p_run_id bigint, p_row_ids bigint[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth'
AS $function$
DECLARE
  v_actor public.my_access%rowtype;
  v_run_library_id uuid;
  v_source_kind text;
  v_source_id bigint;
  v_lib uuid;
  v_ids bigint[];
  v_batch bigint;
  v_skipped jsonb := '{}'::jsonb;
  v_drafts jsonb := '[]'::jsonb;
  v_prepared integer := 0;
  v_raison text;
  v_draft bigint;
  v_set text;
  v_n_set integer;
  v_n jsonb;
  v_trace jsonb;
  v_base bigint;
  rec record;
BEGIN
  -- Les contrôles de fn_import_set_editorial : la coordination de la
  -- bibliothèque du run, ou l'administration du réseau dont la bibliothèque
  -- active est celle du run.
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  SELECT r.library_id, s.source_kind, r.source_id
    INTO v_run_library_id, v_source_kind, v_source_id
    FROM ingest.partner_catalog_import_runs r
    LEFT JOIN ingest.partner_catalog_sources s ON s.id = r.source_id
   WHERE r.id = p_run_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;
  IF v_run_library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;
  -- Un dépôt compagnon ou un entrepôt OAI : l'administration seule (comme
  -- fn_import_promote).
  IF v_source_kind IN ('partner_deposit', 'oai_pmh') AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Deposito de catalogo companheiro reservado a administracao da rede.'
      USING HINT = 'error.import.deposit_admin_only';
  END IF;
  -- Une page : 200 lignes au plus (l'écran envoie des pages de 200 ; le
  -- plafond des appels de l'API est de 8 s).
  IF coalesce(cardinality(p_row_ids), 0) > 200 THEN
    RAISE EXCEPTION 'No maximo 200 linhas por chamada.' USING HINT = 'error.import.update_page_too_large';
  END IF;

  -- H31 : le verrou du run des conversions, après les contrôles d'accès.
  PERFORM 1 FROM ingest.partner_catalog_import_runs WHERE id = p_run_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  v_ids := ARRAY(SELECT DISTINCT x FROM unnest(coalesce(p_row_ids, '{}'::bigint[])) x WHERE x IS NOT NULL ORDER BY x);
  IF cardinality(v_ids) = 0 THEN
    RETURN jsonb_build_object('run_id', p_run_id, 'batch_id', NULL, 'asked', 0, 'prepared', 0,
                              'skipped_rows', 0, 'skipped', '{}'::jsonb, 'drafts', '[]'::jsonb);
  END IF;

  v_lib := ingest.fn_h21_bibliotheque_importatrice(p_run_id, NULL, NULL);

  -- La comparaison RECALCULÉE dans cette transaction (et stockée : la liste et
  -- le rapport voient celle qui a servi).
  PERFORM ingest.fn_h21_stocker_comparaisons(p_run_id, v_ids);

  FOR rec IN
    SELECT x.id AS demande, sr.id, sr.match_status, sr.proposed_book_id, sr.editorial_decision,
           sr.editorial_note, sr.discarded_draft_id, sr.external_key, sr.comparaison
      FROM unnest(v_ids) x(id)
      LEFT JOIN ingest.partner_catalog_staging_rows sr ON sr.id = x.id AND sr.run_id = p_run_id
     ORDER BY x.id
  LOOP
    v_raison := NULL;
    IF rec.id IS NULL THEN
      v_raison := 'hors_run';
    ELSIF rec.match_status IS DISTINCT FROM 'known_record' OR rec.proposed_book_id IS NULL THEN
      v_raison := 'pas_reconnue';
    ELSIF ingest.fn_h21_rejet_par_choix(rec.editorial_decision, rec.editorial_note, rec.discarded_draft_id) THEN
      v_raison := 'rejetee';
    ELSIF EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = rec.id) THEN
      v_raison := 'deja_preparee';
    END IF;

    IF v_raison IS NULL THEN
      -- deux préparations de la même notice (deux runs) attendent l'une l'autre
      PERFORM pg_advisory_xact_lock(hashtextextended('h21-lot4/notice/' || rec.proposed_book_id, 0));
      IF v_lib IS NULL
         OR NOT EXISTS (SELECT 1 FROM public.book_holdings h
                         WHERE h.book_id = rec.proposed_book_id AND h.library_id = v_lib) THEN
        v_raison := 'plus_detenue';
      ELSIF EXISTS (SELECT 1 FROM public.book_holdings h
                     WHERE h.book_id = rec.proposed_book_id AND h.library_id IS DISTINCT FROM v_lib) THEN
        v_raison := 'partagee';
      ELSIF EXISTS (SELECT 1 FROM public.book_drafts d
                     WHERE d.published_book_id = rec.proposed_book_id AND d.status IN ('draft', 'ready')
                       AND coalesce(d.marc_json, '{}'::jsonb) ? 'ingest_update') THEN
        v_raison := 'deja_preparee';
      ELSIF rec.comparaison IS NULL OR (rec.comparaison->>'book_id') IS DISTINCT FROM rec.proposed_book_id::text THEN
        v_raison := 'non_comparee';
      ELSIF rec.comparaison->>'baseline_id' IS NULL THEN
        v_raison := 'sans_base';
      ELSIF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(rec.comparaison->'champs') c
                         WHERE c->>'verdict' = 'source_seule' AND c->>'champ' <> 'contributors'
                           AND coalesce(c->'n', 'null'::jsonb) <> 'null'::jsonb) THEN   -- (c) : un effacement ne s'applique pas
        v_raison := 'rien_a_appliquer';
      END IF;
    END IF;

    IF v_raison IS NOT NULL THEN
      v_skipped := v_skipped || jsonb_build_object(v_raison, coalesce((v_skipped->>v_raison)::int, 0) + 1);
      CONTINUE;
    END IF;

    -- ── La ligne se prépare ──
    IF v_batch IS NULL THEN
      v_batch := ingest.fn_h21_lot_de_la_mise_a_jour(p_run_id, v_lib, v_actor.user_id);
    END IF;
    v_base := (rec.comparaison->>'baseline_id')::bigint;
    -- N brut (la correspondance de la création), pour la base à la publication
    v_n := ingest.fn_h21_base_de_la_ligne(rec.id);
    v_trace := jsonb_build_object(
      'version', 'h21-lot4/2026-10-06',
      'run_id', p_run_id,
      'staging_row_id', rec.id,
      'external_key', btrim(rec.external_key),
      'library_id', v_lib,
      'source_id', v_source_id,
      'book_id', rec.proposed_book_id,
      'baseline_id', v_base,
      'external_id_id', (SELECT bl.external_id_id FROM ingest.book_import_baselines bl WHERE bl.id = v_base),
      'empreinte_notice', ingest.fn_h21_empreinte_notice(rec.proposed_book_id),
      'empreinte_base', ingest.fn_h21_empreinte_base(v_base),
      'prepared_at', now(),
      'prepared_by', v_actor.user_id,
      -- appliqués : source_seule, hors responsabilités, avec une valeur du
      -- fichier (IMP-31 b, c)
      'appliques', (SELECT coalesce(jsonb_agg(jsonb_build_object('champ', c->>'champ', 'b', c->'b', 'a', c->'a', 'n', c->'n')
                                              ORDER BY o), '[]'::jsonb)
                      FROM jsonb_array_elements(rec.comparaison->'champs') WITH ORDINALITY t(c, o)
                     WHERE c->>'verdict' = 'source_seule' AND c->>'champ' <> 'contributors'
                       AND coalesce(c->'n', 'null'::jsonb) <> 'null'::jsonb),
      -- montrés, jamais appliqués : responsabilités source_seule, effacements
      -- par la source (raison efface_par_la_source), conflits, sans base
      'montres', (SELECT coalesce(jsonb_agg(jsonb_build_object('champ', c->>'champ', 'verdict', c->>'verdict',
                                                               'b', c->'b', 'a', c->'a', 'n', c->'n')
                                            || CASE WHEN c->>'verdict' = 'source_seule' AND c->>'champ' <> 'contributors'
                                                    THEN jsonb_build_object('raison', 'efface_par_la_source')
                                                    ELSE '{}'::jsonb END
                                            ORDER BY o), '[]'::jsonb)
                    FROM jsonb_array_elements(rec.comparaison->'champs') WITH ORDINALITY t(c, o)
                   WHERE (c->>'verdict' = 'source_seule'
                          AND (c->>'champ' = 'contributors' OR coalesce(c->'n', 'null'::jsonb) = 'null'::jsonb))
                      OR c->>'verdict' IN ('conflit', 'sans_base')),
      'champs', (SELECT coalesce(jsonb_agg(jsonb_build_object('champ', c->>'champ', 'verdict', c->>'verdict', 'n', c->'n')
                                           ORDER BY o), '[]'::jsonb)
                   FROM jsonb_array_elements(rec.comparaison->'champs') WITH ORDINALITY t(c, o)),
      'n_livre', jsonb_build_object('mapped', v_n->'mapped', 'contributors', v_n->'contributors',
                                    'subjects', v_n->'subjects', 'mapping_version', v_n->>'mapping_version',
                                    'payload_hash', v_n->>'payload_hash'));

    v_draft := ingest.fn_h21_copie_de_la_notice(rec.proposed_book_id, v_batch, v_lib, v_actor.user_id);

    -- le patch : les seuls champs source_seule hors responsabilités dont le
    -- fichier donne une valeur (décision (c)), valeur normalisée, au type de la
    -- colonne du brouillon
    SELECT string_agg(format('%I = %L::%s', c->>'champ', c->>'n', format_type(a.atttypid, a.atttypmod)), ', '),
           count(*)
      INTO v_set, v_n_set
      FROM jsonb_array_elements(rec.comparaison->'champs') c
      JOIN pg_catalog.pg_attribute a ON a.attrelid = 'public.book_drafts'::regclass
                                    AND a.attname = c->>'champ' AND a.attnum > 0 AND NOT a.attisdropped
     WHERE c->>'verdict' = 'source_seule' AND c->>'champ' <> 'contributors'
       AND coalesce(c->'n', 'null'::jsonb) <> 'null'::jsonb;
    IF v_n_set IS DISTINCT FROM jsonb_array_length(v_trace->'appliques') THEN
      RAISE EXCEPTION 'H21 lot 4 : champ sans colonne au brouillon (%/%)', v_n_set, jsonb_array_length(v_trace->'appliques');
    END IF;
    EXECUTE format('UPDATE public.book_drafts SET %s, marc_json = coalesce(marc_json, ''{}''::jsonb) || jsonb_build_object(''ingest_update'', $2::jsonb) WHERE id = $1', v_set)
      USING v_draft, v_trace;

    INSERT INTO ingest.partner_catalog_row_to_draft (staging_row_id, run_id, draft_id, batch_id, created_by)
    VALUES (rec.id, p_run_id, v_draft, v_batch, v_actor.user_id);

    v_prepared := v_prepared + 1;
    v_drafts := v_drafts || jsonb_build_array(jsonb_build_object(
                  'row_id', rec.id, 'draft_id', v_draft, 'book_id', rec.proposed_book_id,
                  'applied', (SELECT coalesce(jsonb_agg(x->'champ'), '[]'::jsonb) FROM jsonb_array_elements(v_trace->'appliques') x)));
  END LOOP;

  RETURN jsonb_build_object(
    'run_id', p_run_id,
    'batch_id', v_batch,
    'asked', cardinality(v_ids),
    'prepared', v_prepared,
    'skipped_rows', cardinality(v_ids) - v_prepared,
    'skipped', v_skipped,
    'drafts', v_drafts);
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_import_preparer_mises_a_jour(bigint, bigint[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_import_preparer_mises_a_jour(bigint, bigint[]) TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_import_preparer_mises_a_jour(bigint, bigint[]) IS
  'H21 lot 4 (06/10/2026, IMP-31) : « Préparer la mise à jour » — pour chaque ligne known_record dont la bibliothèque qui importe est la seule détentrice et dont la comparaison recalculée a un champ source_seule (hors responsabilités), un brouillon de mise à jour (copie complète de la notice, patch de ces seuls champs, trace marc_json.ingest_update) dans le lot du run ; les autres lignes sont ignorées avec leur raison. Coordination de la bibliothèque du run, ou administration ; 200 lignes par appel.';


-- ─────────────────────────────────────────────────────────────────────
-- 4. La trace de la mise à jour ne s'écrit pas par l'API
-- ─────────────────────────────────────────────────────────────────────
DO $h21l4_trace$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l4_def('public.tg_book_drafts_trace_import_figee()'::regprocedure);
  v_def := pg_temp.h21l4_remplacer('tg_book_drafts_trace_import_figee', v_def,
$a$  IF coalesce(OLD.marc_json, '{}'::jsonb) ? 'ingest' THEN$a$,
$b$  -- H21 lot 4 (06/10/2026) : la trace d'une mise à jour préparée par un
  -- réimport (marc_json.ingest_update : empreintes, base, champs appliqués) ne
  -- se pose, ne se réécrit ni ne s'efface par l'API — remise en silence, comme
  -- marc_json.ingest ; la notice visée (published_book_id) d'un tel brouillon
  -- non plus : la garde de publication lit l'une et l'autre.
  IF coalesce(OLD.marc_json, '{}'::jsonb) ? 'ingest_update' OR coalesce(NEW.marc_json, '{}'::jsonb) ? 'ingest_update' THEN
    IF (NEW.marc_json -> 'ingest_update') IS DISTINCT FROM (OLD.marc_json -> 'ingest_update') THEN
      NEW.marc_json := (coalesce(NEW.marc_json, '{}'::jsonb) - 'ingest_update')
                       || CASE WHEN coalesce(OLD.marc_json, '{}'::jsonb) ? 'ingest_update'
                               THEN jsonb_build_object('ingest_update', OLD.marc_json -> 'ingest_update')
                               ELSE '{}'::jsonb END;
    END IF;
    IF coalesce(OLD.marc_json, '{}'::jsonb) ? 'ingest_update'
       AND NEW.published_book_id IS DISTINCT FROM OLD.published_book_id THEN
      NEW.published_book_id := OLD.published_book_id;
    END IF;
  END IF;
  IF coalesce(OLD.marc_json, '{}'::jsonb) ? 'ingest' THEN$b$);
  EXECUTE v_def;
END
$h21l4_trace$;


-- ─────────────────────────────────────────────────────────────────────
-- 5. La garde de publication, la base
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION ingest.fn_h21_garde_mise_a_jour(p_draft_id bigint, p_republication boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_d public.book_drafts%rowtype;
  v_u jsonb;
  v_book bigint;
  v_lib uuid;
  v_bib_ref text;
begin
  select * into v_d from public.book_drafts where id = p_draft_id;
  v_u := v_d.marc_json -> 'ingest_update';
  if v_u is null then
    return;
  end if;
  v_book := v_d.published_book_id;
  v_lib := nullif(v_u->>'library_id', '')::uuid;

  -- Republication d'une mise à jour déjà publiée (une retouche) : la notice a
  -- changé par la première publication, la base aussi — leurs contrôles sont
  -- sautés ; restent la détention exclusive (IMP-26 a) et bib_ref (piège 12).
  if p_republication then
    select b.bib_ref into v_bib_ref from public.books b where b.id = v_book for update;
    if v_lib is null
       or not exists (select 1 from public.book_holdings h where h.book_id = v_book and h.library_id = v_lib)
       or exists (select 1 from public.book_holdings h where h.book_id = v_book and h.library_id is distinct from v_lib) then
      raise exception 'atualizacao_ficha_compartilhada' using hint = 'error.publish.update_shared_record';
    end if;
    if v_d.bib_ref is distinct from v_bib_ref then
      raise exception 'atualizacao_bib_ref_alterada' using hint = 'error.publish.update_bib_ref_changed';
    end if;
    return;
  end if;

  -- (0) la trace sans son lien d'import (ligne disparue) : rien ne prouve plus
  --     d'où vient le brouillon, ni qu'il passe par la révision
  if not exists (select 1 from ingest.partner_catalog_row_to_draft m
                  where m.draft_id = p_draft_id and m.staging_row_id::text = v_u->>'staging_row_id') then
    raise exception 'atualizacao_sem_linha_de_importacao' using hint = 'error.publish.update_import_row_gone';
  end if;
  -- la notice, verrouillée jusqu'à la fin de la publication
  select b.bib_ref into v_bib_ref from public.books b where b.id = v_book for update;
  if not found or v_book::text is distinct from v_u->>'book_id' then
    raise exception 'atualizacao_ficha_alterada' using hint = 'error.publish.update_record_changed';
  end if;
  -- (1) seule détentrice (book_holdings, piège 18)
  if v_lib is null
     or not exists (select 1 from public.book_holdings h where h.book_id = v_book and h.library_id = v_lib)
     or exists (select 1 from public.book_holdings h where h.book_id = v_book and h.library_id is distinct from v_lib) then
    raise exception 'atualizacao_ficha_compartilhada' using hint = 'error.publish.update_shared_record';
  end if;
  -- (2) l'identifiant d'origine désigne toujours cette notice, pour elle
  if not exists (select 1 from public.book_external_ids e
                  where e.id = nullif(v_u->>'external_id_id', '')::bigint
                    and e.book_id = v_book and e.library_id = v_lib
                    and e.value = v_u->>'external_key') then
    raise exception 'atualizacao_identificador_de_origem' using hint = 'error.publish.update_origin_moved';
  end if;
  -- (3) bib_ref : celui de la notice (piège 12)
  if v_d.bib_ref is distinct from v_bib_ref then
    raise exception 'atualizacao_bib_ref_alterada' using hint = 'error.publish.update_bib_ref_changed';
  end if;
  -- (4) la base : la même, toujours à cet identifiant
  if not exists (select 1 from ingest.book_import_baselines bl
                  where bl.id = nullif(v_u->>'baseline_id', '')::bigint
                    and bl.external_id_id = nullif(v_u->>'external_id_id', '')::bigint)
     or ingest.fn_h21_empreinte_base(nullif(v_u->>'baseline_id', '')::bigint) is distinct from v_u->>'empreinte_base' then
    raise exception 'atualizacao_base_alterada' using hint = 'error.publish.update_baseline_changed';
  end if;
  -- (5) la notice n'a pas changé depuis la préparation (empreinte de A)
  if ingest.fn_h21_empreinte_notice(v_book) is distinct from v_u->>'empreinte_notice' then
    raise exception 'atualizacao_ficha_alterada' using hint = 'error.publish.update_record_changed';
  end if;
end;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_garde_mise_a_jour(bigint, boolean) IS
  'H21 lot 4 (06/10/2026) : garde de la publication d''un brouillon de mise à jour préparé par un réimport (trace marc_json.ingest_update) — première publication : lien d''import, seule détentrice, identifiant d''origine, bib_ref, base, empreinte de la notice ; republication : seule détentrice et bib_ref. Interne : publish_book_draft.';

-- La base avance à N pour les champs que la notice publiée dit comme le
-- fichier ; elle garde B pour les autres (voir l'en-tête, 3).
CREATE OR REPLACE FUNCTION ingest.fn_h21_avancer_base_apres_mise_a_jour(p_draft_id bigint, p_book_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_u jsonb;
  v_b ingest.book_import_baselines%rowtype;
  v_a jsonb;
  v_ac jsonb;
  v_avances text[];
  v_gardes text[];
  v_douteux text[];
  v_mapped jsonb;
  v_raw jsonb;
  v_f text;
  v_res jsonb;
begin
  select d.marc_json->'ingest_update' into v_u from public.book_drafts d where d.id = p_draft_id;
  if v_u is null then
    return null;
  end if;
  select * into v_b from ingest.book_import_baselines where id = nullif(v_u->>'baseline_id', '')::bigint for update;
  if not found then
    return null;   -- la garde l'a vérifiée juste avant, dans la même transaction
  end if;

  -- A après publication, normalisée comme la comparaison (lot 3)
  select to_jsonb(b) into v_a from public.books b where b.id = p_book_id;
  v_ac := ingest.fn_h21_responsabilites(coalesce(
            (select jsonb_agg(jsonb_build_object('position', c.position, 'name', c.name, 'role', c.role) order by c.position)
               from public.book_contributors c where c.book_id = p_book_id), '[]'::jsonb));
  select coalesce(array_agg(x.champ order by x.o) filter (where x.avance), '{}'::text[]),
         coalesce(array_agg(x.champ order by x.o) filter (where not x.avance), '{}'::text[])
    into v_avances, v_gardes
    from (select c->>'champ' as champ, o,
                 (case c->>'champ' when 'contributors' then v_ac
                                   else to_jsonb(nullif(btrim(v_a->>(c->>'champ')), '')) end)
                   is not distinct from nullif(c->'n', 'null'::jsonb) as avance
            from jsonb_array_elements(v_u->'champs') with ordinality t(c, o)) x;

  -- mapped : celui du fichier, sauf les champs comparés gardés
  v_mapped := coalesce(v_u->'n_livre'->'mapped', '{}'::jsonb);
  foreach v_f in array v_gardes loop
    if v_f <> 'contributors' then
      v_mapped := case when v_b.mapped ? v_f then jsonb_set(v_mapped, array[v_f], v_b.mapped->v_f)
                       else v_mapped - v_f end;
    end if;
  end loop;
  select sr.raw_payload into v_raw
    from ingest.partner_catalog_staging_rows sr where sr.id = nullif(v_u->>'staging_row_id', '')::bigint;
  v_douteux := array(select x from unnest(v_b.reprise_champs_douteux) x where x <> all (v_avances));

  update ingest.book_import_baselines bl
     set run_id = nullif(v_u->>'run_id', '')::bigint,
         staging_row_id = nullif(v_u->>'staging_row_id', '')::bigint,
         mapped = v_mapped,
         contributors = case when 'contributors' = any (v_avances)
                             then coalesce(v_u->'n_livre'->'contributors', '[]'::jsonb) else bl.contributors end,
         subjects = case when 'notas' = any (v_avances)
                         then coalesce(v_u->'n_livre'->'subjects', '[]'::jsonb) else bl.subjects end,
         raw_payload = coalesce(v_raw, bl.raw_payload),
         mapping_version = coalesce(v_u->'n_livre'->>'mapping_version', bl.mapping_version),
         payload_hash = coalesce(v_u->'n_livre'->>'payload_hash', bl.payload_hash),
         reprise_champs_douteux = v_douteux,
         origine = case when cardinality(v_douteux) = 0 then 'import' else bl.origine end,
         imported_at = now(),
         confirmed_at = now(),
         updated_at = now()
   where bl.id = v_b.id;

  v_res := jsonb_build_object('baseline_id', v_b.id, 'avances', to_jsonb(v_avances), 'gardes', to_jsonb(v_gardes),
                              'published_at', now());
  update public.book_drafts d
     set marc_json = jsonb_set(d.marc_json, '{ingest_update,publication}', v_res)
   where d.id = p_draft_id;
  return v_res;
end;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_avancer_base_apres_mise_a_jour(bigint, bigint) IS
  'H21 lot 4 (06/10/2026) : à la publication d''une mise à jour préparée, la base avance à N pour les champs que la notice publiée dit comme le fichier, garde B pour les autres (conflits, sans base, responsabilités non appliquées, retouches) ; raw_payload, version et empreinte suivent le fichier accepté. Interne : publish_book_draft.';

DO $h21l4_droits$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'ingest.fn_h21_empreinte_notice(bigint)', 'ingest.fn_h21_empreinte_base(bigint)',
    'ingest.fn_h21_lot_de_la_mise_a_jour(bigint, uuid, uuid)', 'ingest.fn_h21_copie_de_la_notice(bigint, bigint, uuid, uuid)',
    'ingest.fn_h21_garde_mise_a_jour(bigint, boolean)', 'ingest.fn_h21_avancer_base_apres_mise_a_jour(bigint, bigint)',
    'ingest.fn_h21_rejet_par_choix(text, text, bigint)'] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
  END LOOP;
END
$h21l4_droits$;


-- ─────────────────────────────────────────────────────────────────────
-- 6. publish_book_draft : la garde, la trace hors de la notice, la base
-- ─────────────────────────────────────────────────────────────────────
DO $h21l4_publication$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l4_def('public.publish_book_draft(bigint)'::regprocedure);
  v_def := pg_temp.h21l4_remplacer('publish_book_draft (déclarations)', v_def,
$a$  v_linked int := 0;                         -- H19 : exemplaires importés rattachés
  v_x record;$a$,
$b$  v_linked int := 0;                         -- H19 : exemplaires importés rattachés
  v_x record;
  v_maj_import boolean := false;             -- H21 lot 4 : mise à jour préparée par un réimport$b$);
  -- la trace de la mise à jour ne va jamais sur la notice (création : filet)
  -- une mise à jour préparée dont la notice a été retirée ne devient jamais
  -- une création (revue sceptique du 06/10)
  v_def := pg_temp.h21l4_remplacer('publish_book_draft (notice retirée)', v_def,
$a$  if v_draft.titulo is null or btrim(v_draft.titulo) = '' then$a$,
$b$  -- H21 lot 4 (06/10/2026) : une mise à jour préparée par un réimport (trace
  -- marc_json.ingest_update) dont la notice visée a disparu (retirée :
  -- published_book_id vidé par la clé étrangère) ne prend jamais la branche
  -- création — elle ferait naître une notice neuve, avec fonds, exemplaire,
  -- identifiant d'origine et base de l'ancien run.
  if v_draft.published_book_id is null and coalesce(v_draft.marc_json, '{}'::jsonb) ? 'ingest_update' then
    raise exception 'atualizacao_sem_ficha' using hint = 'error.import.update_record_gone';
  end if;

  if v_draft.titulo is null or btrim(v_draft.titulo) = '' then$b$);
  v_def := pg_temp.h21l4_remplacer('publish_book_draft (création, trace)', v_def,
$a$      coalesce(v_draft.marc_json, '{}'::jsonb), 'catalogacao',$a$,
$b$      coalesce(v_draft.marc_json, '{}'::jsonb) - 'ingest_update', 'catalogacao',$b$);
  v_def := pg_temp.h21l4_remplacer('publish_book_draft (mise à jour, garde)', v_def,
$a$  else
    -- H19 : les exemplaires importés ne se rattachent qu'à une notice CRÉÉE$a$,
$b$  else
    -- H21 lot 4 (06/10/2026, IMP-31) : un brouillon de mise à jour préparé par
    -- un réimport (trace marc_json.ingest_update, figée pour l'API) ne se
    -- publie la première fois que si, depuis la préparation, sa ligne d'import
    -- le désigne encore, la bibliothèque est la seule détentrice,
    -- l'identifiant d'origine désigne cette notice, bib_ref est celui de la
    -- notice, la base et la notice n'ont pas changé
    -- (ingest.fn_h21_garde_mise_a_jour) ; puis la base avance (plus bas).
    -- Republier une mise à jour déjà publiée est une retouche (IMP-27 b) :
    -- seules la détention exclusive et bib_ref sont rejugées, la base
    -- n'avance pas (revue sceptique du 06/10).
    if coalesce(v_draft.marc_json, '{}'::jsonb) ? 'ingest_update' then
      perform ingest.fn_h21_garde_mise_a_jour(p_draft_id, v_draft.status = 'published');
      v_maj_import := v_draft.status is distinct from 'published';
    end if;
    -- H19 : les exemplaires importés ne se rattachent qu'à une notice CRÉÉE$b$);
  v_def := pg_temp.h21l4_remplacer('publish_book_draft (mise à jour, trace)', v_def,
$a$      marc_json = coalesce(v_draft.marc_json, '{}'::jsonb),$a$,
$b$      -- H21 lot 4 : la trace d'une mise à jour préparée reste au brouillon
      marc_json = coalesce(v_draft.marc_json, '{}'::jsonb) - 'ingest_update',$b$);
  v_def := pg_temp.h21l4_remplacer('publish_book_draft (base)', v_def,
$a$  perform public.publish_book_draft_digital_resources(p_draft_id, v_book_id);$a$,
$b$  -- H21 lot 4 : la base de l'identifiant avance à N pour les champs que la
  -- notice publiée dit comme le fichier (IMP-29 ; règle dans l'en-tête de la
  -- migration du lot 4).
  if v_maj_import then
    perform ingest.fn_h21_avancer_base_apres_mise_a_jour(p_draft_id, v_book_id);
  end if;

  perform public.publish_book_draft_digital_resources(p_draft_id, v_book_id);$b$);
  EXECUTE v_def;
END
$h21l4_publication$;


-- ─────────────────────────────────────────────────────────────────────
-- 7. L'écran : applicables et brouillon de mise à jour dans la liste
-- ─────────────────────────────────────────────────────────────────────
DO $h21l4_liste$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l4_def('public.fn_import_list_run_rows(bigint)'::regprocedure);
  v_def := pg_temp.h21l4_remplacer('fn_import_list_run_rows (colonnes)', v_def,
$a$proposed_book_held boolean, comparison_counts jsonb)$a$,
$b$proposed_book_held boolean, comparison_counts jsonb, update_applicable integer, update_draft_id bigint, update_draft_status text)$b$);
  v_def := pg_temp.h21l4_remplacer('fn_import_list_run_rows (valeurs)', v_def,
$a$              THEN sr.comparaison->'counts' END AS comparison_counts
  FROM ingest.partner_catalog_staging_rows sr$a$,
$b$              THEN sr.comparaison->'counts' END AS comparison_counts,
         -- H21 lot 4 (06/10/2026) : les champs que « Préparer la mise à jour »
         -- appliquerait (source_seule hors responsabilités, avec une valeur du
         -- fichier : un effacement ne s'applique pas) dans la comparaison
         -- valide ; 0 pour une ligne rejetée par choix ou écartée (le geste
         -- l'ignore) ; NULL sans comparaison. Et le brouillon de mise à jour.
         CASE WHEN sr.match_status = 'known_record'
                   AND (sr.comparaison->>'book_id') = sr.proposed_book_id::text
              THEN CASE WHEN ingest.fn_h21_rejet_par_choix(sr.editorial_decision, sr.editorial_note, sr.discarded_draft_id) THEN 0
                        ELSE (SELECT count(*)::integer FROM jsonb_array_elements(sr.comparaison->'champs') c
                               WHERE c->>'verdict' = 'source_seule' AND c->>'champ' <> 'contributors'
                                 AND coalesce(c->'n', 'null'::jsonb) <> 'null'::jsonb) END
         END AS update_applicable,
         mu.draft_id AS update_draft_id,
         mu.draft_status AS update_draft_status
  FROM ingest.partner_catalog_staging_rows sr
  LEFT JOIN LATERAL (SELECT m.draft_id, d.status AS draft_status
                       FROM ingest.partner_catalog_row_to_draft m
                       JOIN public.book_drafts d ON d.id = m.draft_id
                      WHERE m.staging_row_id = sr.id
                        AND coalesce(d.marc_json, '{}'::jsonb) ? 'ingest_update') mu ON true$b$);
  DROP FUNCTION public.fn_import_list_run_rows(bigint);
  EXECUTE v_def;
END
$h21l4_liste$;
REVOKE EXECUTE ON FUNCTION public.fn_import_list_run_rows(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_import_list_run_rows(bigint) TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_import_list_run_rows(bigint) IS
  'Lignes d''un run d''import pour l''écran. H21 lot 1 (05/10/2026, IMP-28 b) : proposed_book_held = la bibliothèque qui importe (destination d''un dépôt ou d''un entrepôt OAI, sinon celle du run) détient la notice proposée (book_holdings) ; NULL sans notice proposée. H21 lot 3 (05-06/10/2026) : comparison_counts = comptes par verdict de la comparaison à trois états stockée ; NULL hors known_record ou si elle est périmée (autre notice que la proposée). H21 lot 4 (06/10/2026) : update_applicable = champs source_seule hors responsabilités, avec une valeur du fichier, de cette comparaison (0 si la ligne est rejetée par choix ou écartée) ; update_draft_id / update_draft_status = le brouillon de mise à jour préparé pour la ligne.';


-- ─────────────────────────────────────────────────────────────────────
-- 7 bis. Une décision éditoriale ignore une ligne préparée (décision (d))
-- ─────────────────────────────────────────────────────────────────────
DO $h21l4_decision$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l4_def('public.fn_import_set_editorial(bigint, bigint[], text, text)'::regprocedure);
  v_def := pg_temp.h21l4_remplacer('fn_import_set_editorial (ligne préparée)', v_def,
$a$  SELECT coalesce(array_agg(sr.id) FILTER (WHERE sr.created_book_draft_id IS NULL
                                             AND sr.created_exemplar_draft_id IS NULL$a$,
$b$  -- H21 lot 4 (06/10/2026, IMP-31 d) : une ligne PRÉPARÉE (brouillon de mise
  -- à jour, lien row_to_draft) est ignorée comme une ligne convertie :
  -- « Rejeter » ne la rejette pas ; son brouillon se retire depuis le catalogage.
  SELECT coalesce(array_agg(sr.id) FILTER (WHERE sr.created_book_draft_id IS NULL
                                             AND sr.created_exemplar_draft_id IS NULL
                                             AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m
                                                              WHERE m.staging_row_id = sr.id)$b$);
  EXECUTE v_def;
END
$h21l4_decision$;


-- ─────────────────────────────────────────────────────────────────────
-- 7 ter. Un brouillon de mise à jour ne s'absorbe pas dans une notice
-- ─────────────────────────────────────────────────────────────────────
DO $h21l4_absorption$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l4_def('api.merge_draft_into_book(bigint, bigint, jsonb)'::regprocedure);
  v_def := pg_temp.h21l4_remplacer('api.merge_draft_into_book (mise à jour préparée)', v_def,
$a$      USING HINT = 'error.merge.draft_not_in_queue';
  END IF;$a$,
$b$      USING HINT = 'error.merge.draft_not_in_queue';
  END IF;
  -- H21 lot 4 (06/10/2026, revue sceptique) : un brouillon de mise à jour
  -- préparé par un réimport (trace marc_json.ingest_update) ne s'absorbe pas :
  -- l'absorption n'a ni garde de détention ni révision, et poserait la base
  -- depuis le marc_json.ingest copié de sa notice (l'ancienne provenance). Il
  -- se publie par son lot, ou se met à la corbeille.
  IF coalesce(v_draft.marc_json, '{}'::jsonb) ? 'ingest_update' THEN
    RAISE EXCEPTION 'Rascunho de atualizacao de importacao nao se absorve.'
      USING HINT = 'error.import.update_draft_not_mergeable';
  END IF;$b$);
  EXECUTE v_def;
END
$h21l4_absorption$;


-- ─────────────────────────────────────────────────────────────────────
-- 8. Le rapport de révision : les brouillons de mise à jour du lot
-- ─────────────────────────────────────────────────────────────────────
DO $h21l4_rapport$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l4_def('public.fn_batch_review_report(bigint)'::regprocedure);
  v_def := pg_temp.h21l4_remplacer('fn_batch_review_report (déclarations)', v_def,
$a$  v_updates jsonb;   -- H21 lot 3
begin$a$,
$b$  v_updates jsonb;   -- H21 lot 3
  v_prepared jsonb;  -- H21 lot 4
begin$b$);
  v_def := pg_temp.h21l4_remplacer('fn_batch_review_report (calcul)', v_def,
$a$  return jsonb_build_object(
    'batch', jsonb_build_object($a$,
$b$  -- ── H21 lot 4 (06/10/2026, IMP-31) : les brouillons de mise à jour ──
  -- préparés par un réimport, rangés dans le lot (lien d'import et trace
  -- marc_json.ingest_update) : pour chacun, les champs appliqués (base,
  -- AnarBib, fichier) et les champs MONTRÉS non appliqués (responsabilités
  -- changées dans le fichier, conflits, sans base) ; 40 exemples au plus,
  -- les comptes portent sur tout. Clé absente sans brouillon de mise à jour.
  with maj as materialized (
    select d.id, d.titulo, d.published_book_id, d.status, d.marc_json->'ingest_update' as u
      from public.book_drafts d
     where d.batch_id = p_batch_id and d.status in ('draft', 'ready', 'published')
       and coalesce(d.marc_json, '{}'::jsonb) ? 'ingest_update'
       and exists (select 1 from ingest.partner_catalog_row_to_draft m where m.draft_id = d.id)
  )
  select case when (select count(*) from maj) = 0 then null else jsonb_build_object(
           'count', (select count(*) from maj),
           'published', (select count(*) from maj where status = 'published'),
           'applied_fields', (select coalesce(sum(jsonb_array_length(coalesce(u->'appliques', '[]'::jsonb))), 0) from maj),
           'shown_fields', (select coalesce(sum(jsonb_array_length(coalesce(u->'montres', '[]'::jsonb))), 0) from maj),
           'examples', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'draft_id', x.id, 'book_id', x.published_book_id, 'titulo', x.titulo,
                      'external_key', x.u->>'external_key', 'status', x.status,
                      'applied', coalesce(x.u->'appliques', '[]'::jsonb),
                      'shown', coalesce(x.u->'montres', '[]'::jsonb)) order by x.id)
               from (select * from maj order by id limit 40) x), '[]'::jsonb)) end
    into v_prepared;

  return jsonb_build_object(
    'batch', jsonb_build_object($b$);
  v_def := pg_temp.h21l4_remplacer('fn_batch_review_report (clé)', v_def,
$a$  ) || case when v_updates is null then '{}'::jsonb else jsonb_build_object('updates', v_updates) end;   -- H21 lot 3$a$,
$b$  ) || case when v_updates is null then '{}'::jsonb else jsonb_build_object('updates', v_updates) end   -- H21 lot 3
    || case when v_prepared is null then '{}'::jsonb else jsonb_build_object('prepared_updates', v_prepared) end;   -- H21 lot 4$b$);
  EXECUTE v_def;
END
$h21l4_rapport$;


-- ─────────────────────────────────────────────────────────────────────
-- 9. Vérification (structurelle : les migrations passent avant le seed)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l4_verif$
DECLARE
  v_e text := '';
  v_def text;
  v_f text;
BEGIN
  -- la publication : garde avant l'UPDATE de la notice, trace retirée, base après
  v_def := pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure);
  IF position('perform ingest.fn_h21_garde_mise_a_jour(p_draft_id, ' IN v_def) = 0
     OR position('perform ingest.fn_h21_garde_mise_a_jour(p_draft_id, ' IN v_def) > position('update public.books' IN v_def)
     OR position('perform ingest.fn_h21_avancer_base_apres_mise_a_jour(p_draft_id, v_book_id);' IN v_def)
        < position('update public.book_drafts' IN v_def)
     OR position('marc_json = coalesce(v_draft.marc_json, ''{}''::jsonb) - ''ingest_update''' IN v_def) = 0
     OR position('coalesce(v_draft.marc_json, ''{}''::jsonb) - ''ingest_update'', ''catalogacao''' IN v_def) = 0
     OR position('lote_importado_sem_revisao' IN v_def) > position('fn_h21_garde_mise_a_jour' IN v_def)
     OR position('v_draft.status is distinct from ''published''' IN v_def) = 0
     OR position('error.import.update_record_gone' IN v_def) = 0
     OR position('error.import.update_record_gone' IN v_def) > position('if v_draft.published_book_id is null then' IN v_def)
     OR position('fn_h21_garde_mise_a_jour(p_draft_id, v_draft.status = ''published'')' IN v_def) = 0 THEN
    v_e := v_e || ' publication';
  END IF;
  IF position('error.import.update_draft_not_mergeable' IN pg_get_functiondef('api.merge_draft_into_book(bigint, bigint, jsonb)'::regprocedure)) = 0
     OR position('error.import.update_draft_not_mergeable' IN pg_get_functiondef('api.merge_draft_into_book(bigint, bigint, jsonb)'::regprocedure))
        > position('UPDATE public.books' IN pg_get_functiondef('api.merge_draft_into_book(bigint, bigint, jsonb)'::regprocedure)) THEN
    v_e := v_e || ' absorption';
  END IF;
  -- la garde : ses six refus ; la republication rejuge détention et bib_ref
  v_def := pg_get_functiondef('ingest.fn_h21_garde_mise_a_jour(bigint, boolean)'::regprocedure);
  IF position('if p_republication then' IN v_def) = 0
     OR position('error.publish.update_shared_record' IN v_def) > position('error.publish.update_import_row_gone' IN v_def) THEN
    v_e := v_e || ' republication';
  END IF;
  FOREACH v_f IN ARRAY ARRAY['error.publish.update_import_row_gone', 'error.publish.update_shared_record',
                             'error.publish.update_origin_moved', 'error.publish.update_bib_ref_changed',
                             'error.publish.update_baseline_changed', 'error.publish.update_record_changed'] LOOP
    IF position(v_f IN v_def) = 0 THEN v_e := v_e || ' garde(' || v_f || ')'; END IF;
  END LOOP;
  -- la trace figée pour l'API
  IF position('ingest_update' IN pg_get_functiondef('public.tg_book_drafts_trace_import_figee()'::regprocedure)) = 0 THEN
    v_e := v_e || ' trace';
  END IF;
  -- le geste : accès de fn_import_set_editorial, verrou après l'accès, comparaison recalculée
  v_def := pg_get_functiondef('public.fn_import_preparer_mises_a_jour(bigint, bigint[])'::regprocedure);
  IF position('Acesso restrito ao coordenador da biblioteca.' IN v_def) = 0
     OR position('FOR NO KEY UPDATE' IN v_def) < position('Run % introuvable' IN v_def)
     OR position('ingest.fn_h21_stocker_comparaisons(p_run_id, v_ids)' IN v_def) < position('FOR NO KEY UPDATE' IN v_def)
     OR position('create_book_draft_from_book' IN v_def) > 0
     OR position('created_book_draft_id' IN v_def) > 0 THEN
    v_e := v_e || ' geste';
  END IF;
  -- les deux gestes indépendants : la décision ignore une ligne préparée ; la
  -- note du rejet H19 que lit fn_h21_rejet_par_choix est toujours écrite
  IF position('partner_catalog_row_to_draft m' IN pg_get_functiondef('public.fn_import_set_editorial(bigint, bigint[], text, text)'::regprocedure)) = 0
     OR position('Todos os exemplares desta linha ja estao na biblioteca' IN
                 (SELECT string_agg(pg_get_functiondef(p.oid), '') FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'ingest' AND p.proname = 'fn_create_exemplar_drafts_from_import_rows')) = 0
     OR ingest.fn_h21_rejet_par_choix('reject', 'Todos os exemplares desta linha ja estao na biblioteca (mesmo codigo de origem): nada a aproximar.', NULL)
     OR NOT ingest.fn_h21_rejet_par_choix('reject', 'page import: écarté', NULL)
     OR NOT ingest.fn_h21_rejet_par_choix('pending', NULL, 1) THEN
    v_e := v_e || ' gestes-independants';
  END IF;
  -- un effacement par la source ne s'applique pas
  IF position('coalesce(c->''n'', ''null''::jsonb) <> ''null''::jsonb' IN
              pg_get_functiondef('public.fn_import_preparer_mises_a_jour(bigint, bigint[])'::regprocedure)) = 0 THEN
    v_e := v_e || ' effacement';
  END IF;
  -- la liste : colonnes ajoutées à la fin
  IF (SELECT (p.proargnames)[array_length(p.proargnames, 1)] FROM pg_proc p
       WHERE p.oid = 'public.fn_import_list_run_rows(bigint)'::regprocedure) IS DISTINCT FROM 'update_draft_status'
     OR (SELECT (p.proargnames)[34] FROM pg_proc p
          WHERE p.oid = 'public.fn_import_list_run_rows(bigint)'::regprocedure) IS DISTINCT FROM 'comparison_counts'
     OR (SELECT array_length(p.proargnames, 1) FROM pg_proc p
          WHERE p.oid = 'public.fn_import_list_run_rows(bigint)'::regprocedure) <> 37 THEN
    v_e := v_e || ' liste-colonnes';
  END IF;
  -- le rapport
  IF position('jsonb_build_object(''prepared_updates'', v_prepared)' IN
              pg_get_functiondef('public.fn_batch_review_report(bigint)'::regprocedure)) = 0 THEN
    v_e := v_e || ' rapport';
  END IF;
  -- droits
  IF EXISTS (SELECT 1 FROM unnest(ARRAY[
        'public.fn_import_preparer_mises_a_jour(bigint, bigint[])', 'public.fn_import_list_run_rows(bigint)',
        'public.fn_batch_review_report(bigint)', 'public.publish_book_draft(bigint)']) f
      WHERE NOT has_function_privilege('authenticated', f, 'EXECUTE') OR has_function_privilege('anon', f, 'EXECUTE')
         OR NOT has_function_privilege('service_role', f, 'EXECUTE')) THEN
    v_e := v_e || ' droits-ecran';
  END IF;
  FOREACH v_f IN ARRAY ARRAY[
    'ingest.fn_h21_empreinte_notice(bigint)', 'ingest.fn_h21_empreinte_base(bigint)',
    'ingest.fn_h21_lot_de_la_mise_a_jour(bigint, uuid, uuid)', 'ingest.fn_h21_copie_de_la_notice(bigint, bigint, uuid, uuid)',
    'ingest.fn_h21_garde_mise_a_jour(bigint, boolean)', 'ingest.fn_h21_avancer_base_apres_mise_a_jour(bigint, bigint)',
    'ingest.fn_h21_rejet_par_choix(text, text, bigint)'] LOOP
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0) THEN
      v_e := v_e || ' droits-internes(' || v_f || ')';
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_proc p
              WHERE p.oid IN ('public.fn_import_preparer_mises_a_jour(bigint, bigint[])'::regprocedure,
                              'ingest.fn_h21_empreinte_notice(bigint)'::regprocedure,
                              'ingest.fn_h21_empreinte_base(bigint)'::regprocedure,
                              'ingest.fn_h21_lot_de_la_mise_a_jour(bigint, uuid, uuid)'::regprocedure,
                              'ingest.fn_h21_copie_de_la_notice(bigint, bigint, uuid, uuid)'::regprocedure,
                              'ingest.fn_h21_garde_mise_a_jour(bigint, boolean)'::regprocedure,
                              'ingest.fn_h21_avancer_base_apres_mise_a_jour(bigint, bigint)'::regprocedure,
                              'public.fn_import_list_run_rows(bigint)'::regprocedure,
                              'public.fn_batch_review_report(bigint)'::regprocedure,
                              'public.publish_book_draft(bigint)'::regprocedure,
                              'public.fn_import_set_editorial(bigint, bigint[], text, text)'::regprocedure)
                AND (NOT p.prosecdef OR coalesce(p.proconfig::text, '') NOT LIKE '%search_path%')) THEN
    v_e := v_e || ' definer';
  END IF;

  IF v_e <> '' THEN
    RAISE EXCEPTION 'H21 lot 4 : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'H21 lot 4 : vérifications OK';
END
$h21l4_verif$;

NOTIFY pgrst, 'reload schema';
