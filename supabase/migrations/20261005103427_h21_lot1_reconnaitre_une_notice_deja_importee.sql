-- =====================================================================
-- H21 lot 1 — reconnaître une notice déjà importée (REGISTRE IMP-28,
-- décidé le 05/10/2026 par Xavier ; précise IMP-26 et IMP-27)
--
-- Décisions :
--  (a) une ligne réimportée dont l'identifiant d'origine est déjà connu est
--      reconnue par TOUTE source de la même bibliothèque (clé : bibliothèque +
--      identifiant), pas seulement par la source qui l'a importée — un nouvel
--      export du même PMB, déposé comme nouvelle source, est reconnu ;
--  (b) reconnue mais plus détenue par la bibliothèque (réattribuée,
--      désherbée, fondue) : reconnue ET signalée ; ni création ni mise à jour
--      proposées ; la coordination rapproche (nouvel exemplaire) ou rejette ;
--  (c) un identifiant d'origine appartient à la bibliothèque dont le PMB l'a
--      émis : réattribuer un exemplaire ne le recopie pas pour la cible ;
--  (d) un exemplaire RATTACHÉ à une notice importée, sorti de la corbeille
--      après la demande de révision, attend un nouveau tour comme une notice
--      (IMP-27 b) ; il ne suit plus sa notice hors de la liste figée du tour.
--
-- Ce que fait la migration :
--  1. Statut de rapprochement `known_record` (« Déjà importée »), posé par
--     ingest.fn_match_partner_catalog_row AVANT toute passe floue quand la
--     clé de la ligne (ingest.fn_h20_cle_de_la_ligne, non NULL : ni clé vide,
--     ni numéro de fascicule d'un CSV, ni clé répétée dans le fichier) est
--     connue dans public.book_external_ids pour la BIBLIOTHÈQUE QUI IMPORTE
--     (destination de la source pour un dépôt compagnon ou un entrepôt OAI,
--     sinon bibliothèque du run — la règle de B30 et du lot 0), toutes sources
--     confondues (scheme 'import:%'), sur UNE notice. Alors : notice proposée
--     = cette notice, un candidat `external_id` score 100, aucune autre passe.
--     Deux notices ou plus pour la même (bibliothèque, valeur) : pas de
--     reconnaissance, rapprochement ordinaire, et un avertissement sur la
--     ligne (kind 'known_record_ambiguous').
--     Méthode de candidat `external_id` admise par la CHECK des candidats.
--  2. Décisions sur une ligne `known_record` : en attente, rejet, et
--     « Rapprocher » (accept_duplicate, posé par
--     public.fn_import_reconcile_duplicates seulement) → brouillons
--     d'exemplaire sur la notice reconnue (H19 : codes déjà présents non
--     recréés, ligne entièrement détenue rejetée). Jamais « Créer »
--     (accept_new reste réservé à new_record : refusé par la compatibilité,
--     et la promotion ne choisit que new_record).
--  3. public.fn_import_list_run_rows rend `proposed_book_held` : la
--     bibliothèque qui importe détient-elle la notice proposée
--     (book_holdings) ? NULL sans notice proposée (IMP-28 b, pour l'écran).
--  4. Index book_external_ids (library_id, value) : la reconnaissance cherche
--     par bibliothèque et valeur, toutes sources.
--  5. IMP-28 (c) : publish_exemplar_draft enregistre l'identifiant d'origine
--     d'un exemplaire rapproché pour la bibliothèque qui a IMPORTÉ la ligne
--     (run et source de la ligne), plus pour la cible d'une réattribution.
--  6. IMP-28 (d) : un exemplaire rattaché dont le lot est importé ne se publie
--     que si le dernier tour approuvé le couvre — publish_exemplar_draft
--     (même porte que les rapprochés, après la garde « notice publiée ») ;
--     publish_book_draft saute ceux que le tour ne couvre pas (ils restent en
--     brouillon, la notice se publie) ; fn_batch_ajouts_apres_revision les
--     compte (la coordination peut redemander un tour).
--  7. Conséquence de (d), trouvée au banc : « Publier le lot »
--     (publish_catalog_batch) ne voyait pas un rattaché dont la notice est
--     déjà publiée — après le nouveau tour, le lot se fermait sur lui, en
--     brouillon. Il passe par la boucle des exemplaires du lot : publié s'il
--     est couvert ; sinon la publication du lot est refusée
--     (added_after_review), tout ou rien, comme pour une notice ajoutée.
--  8. IMP-28 (c), aussi pour une NOTICE importée (revue sceptique du 05/10) :
--     publish_book_draft enregistrait l'identifiant d'origine pour la
--     bibliothèque de la notice publiée. Or fn_batch_reassign_library change
--     la bibliothèque des brouillons d'un lot du catalogue propre sans toucher
--     au run : le lot du PMB de BLMF réattribué à B, publié, donnait à B
--     l'identifiant de BLMF — et le réimport du PMB de B, où ce numéro est une
--     autre œuvre, reconnaissait la notice de BLMF. L'identifiant va désormais
--     à la bibliothèque qui a IMPORTÉ (ingest.fn_h21_bibliotheque_importatrice :
--     destination d'un dépôt ou d'un entrepôt OAI — qu'une réattribution
--     déplace avec le lot —, sinon bibliothèque du run ; run disparu : la
--     source), pour le brouillon publié comme pour les brouillons importés
--     qu'il a absorbés. Une reprise (« Éditer ») par une autre détentrice ne
--     lui donne plus l'identifiant non plus.
--
-- Mesuré en production le 05/10/2026 : 264 identifiants d'origine dans
-- book_external_ids, tous de MLEG (source 3) — aucun n'a été recopié pour une
-- autre bibliothèque par une réattribution : rien à nettoyer pour (c).
--
-- Méthode : chaque fonction existante est modifiée SUR SA DÉFINITION VIVANTE
-- (pg_get_functiondef, retours chariot retirés : deux des définitions en
-- portent, héritées du baseline), par ancres dont le nombre d'occurrences est
-- contrôlé avant tout remplacement — une production qui aurait bougé fait
-- échouer la migration au lieu de réinstaller un texte périmé. DROP + CREATE
-- seulement pour fn_import_list_run_rows (RETURNS TABLE change), droits
-- restaurés à l'identique. Définitions lues le 05/10 sur le banc reconstruit
-- depuis le dépôt (md5 de prosrc, retours chariot compris) :
--   ingest.fn_match_partner_catalog_row               1fda575236f290b5441371f438977600
--   ingest.fn_is_editorial_decision_compatible        e7d3b6f3f8e9baf4c288a81d369fc12a
--   ingest.fn_set_partner_catalog_rows_review         9a70f5ebc015646780ccabb557287344
--   ingest.fn_create_exemplar_drafts_from_import_rows 1f1b92448eb17f237c29ae85840c58f5
--   public.fn_import_reconcile_duplicates             9c032342165e1b3e8e8e1d15c9b5a190
--   public.fn_import_list_run_rows                    93e3ed4d5ed50cd43aa0d7ec6a3c1554
--   public.publish_exemplar_draft                     b280484369161d1d79853e23e9b685a9
--     (production le 05/10 : 3314ed3b9886de542b811124c3dc0f86, après C23
--      20261005092748 ; rebasé, les ancres comptées tiennent — banc 167/167)
--   public.publish_book_draft                         8910f9ee0fca532909d5e000506ec549
--   public.fn_batch_ajouts_apres_revision             8e48b765f91affa8b2e042e87d73d010
--   public.publish_catalog_batch                      bc3060a0371ccd93fbaaf930b930be0d
-- Suite : tests/sql/h21_lot1_reconnaitre_tests.sql.
-- =====================================================================

-- Outil de la migration, éphémère (pg_temp) : remplace une ancre qui doit
-- figurer exactement p_n fois. Nom propre au lot : une session qui
-- enchaînerait les migrations a déjà l'outil du lot 0.
CREATE OR REPLACE FUNCTION pg_temp.h21l1_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'H21 lot 1 — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN
    RAISE EXCEPTION 'H21 lot 1 — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

-- La définition vivante, sans retours chariot.
CREATE OR REPLACE FUNCTION pg_temp.h21l1_def(p_fn regprocedure)
RETURNS text LANGUAGE sql AS $f$
  SELECT replace(pg_get_functiondef(p_fn), E'\r', '');
$f$;


-- ─────────────────────────────────────────────────────────────────────
-- 1. Les valeurs admises : statut known_record, méthode external_id
-- ─────────────────────────────────────────────────────────────────────
DO $h21l1_check$
BEGIN
  IF (SELECT pg_get_constraintdef(c.oid) FROM pg_constraint c
       WHERE c.conrelid = 'ingest.partner_catalog_staging_rows'::regclass
         AND c.conname = 'partner_catalog_staging_rows_match_status_check')
     IS DISTINCT FROM 'CHECK ((match_status = ANY (ARRAY[''unreviewed''::text, ''new_record''::text, ''possible_duplicate''::text, ''matched_book''::text, ''matched_draft''::text, ''manual_decision''::text])))' THEN
    RAISE EXCEPTION 'H21 lot 1 : partner_catalog_staging_rows_match_status_check a changé — relire avant d''élargir';
  END IF;
  IF (SELECT pg_get_constraintdef(c.oid) FROM pg_constraint c
       WHERE c.conrelid = 'ingest.partner_catalog_match_candidates'::regclass
         AND c.conname = 'partner_catalog_match_candidates_match_method_check')
     IS DISTINCT FROM 'CHECK ((match_method = ANY (ARRAY[''isbn_exact''::text, ''issn_exact''::text, ''title_author_year''::text, ''title_author''::text, ''manual''::text])))' THEN
    RAISE EXCEPTION 'H21 lot 1 : partner_catalog_match_candidates_match_method_check a changé — relire avant d''élargir';
  END IF;
END
$h21l1_check$;

ALTER TABLE ingest.partner_catalog_staging_rows
  DROP CONSTRAINT partner_catalog_staging_rows_match_status_check,
  ADD CONSTRAINT partner_catalog_staging_rows_match_status_check
    CHECK (match_status = ANY (ARRAY['unreviewed'::text, 'new_record'::text, 'possible_duplicate'::text,
                                     'matched_book'::text, 'matched_draft'::text, 'manual_decision'::text,
                                     'known_record'::text]));
ALTER TABLE ingest.partner_catalog_match_candidates
  DROP CONSTRAINT partner_catalog_match_candidates_match_method_check,
  ADD CONSTRAINT partner_catalog_match_candidates_match_method_check
    CHECK (match_method = ANY (ARRAY['isbn_exact'::text, 'issn_exact'::text, 'title_author_year'::text,
                                     'title_author'::text, 'manual'::text, 'external_id'::text]));

-- La reconnaissance cherche par (bibliothèque, valeur), toutes sources : la
-- contrainte d'unicité (library_id, scheme, value) n'y sert que par sa
-- première colonne.
CREATE INDEX IF NOT EXISTS book_external_ids_bibliotheque_valeur_idx
  ON public.book_external_ids (library_id, value);


-- ─────────────────────────────────────────────────────────────────────
-- 2. Le rapprochement reconnaît une notice déjà importée
-- ─────────────────────────────────────────────────────────────────────
DO $h21l1_rapprochement$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l1_def('ingest.fn_match_partner_catalog_row(bigint)'::regprocedure);
  v_def := pg_temp.h21l1_remplacer('fn_match_partner_catalog_row (déclarations)', v_def,
$a$  v_proposed_book_draft_id bigint := null;
begin$a$,
$b$  v_proposed_book_draft_id bigint := null;

  v_cle text;                          -- H21 lot 1 (IMP-28 a)
  v_bibliotheque_importatrice uuid;
  v_notices_connues bigint[];
begin$b$);
  v_def := pg_temp.h21l1_remplacer('fn_match_partner_catalog_row (reconnaissance)', v_def,
$a$  update ingest.partner_catalog_staging_rows
     set proposed_book_id = null,
         proposed_book_draft_id = null
   where id = p_staging_row_id;
$a$,
$b$  update ingest.partner_catalog_staging_rows
     set proposed_book_id = null,
         proposed_book_draft_id = null
   where id = p_staging_row_id;

  -- -------------------------------------------------------
  -- 0) H21 lot 1 (05/10/2026, REGISTRE IMP-28 a) : NOTICE DÉJÀ IMPORTÉE
  -- -------------------------------------------------------
  -- La clé que le fichier donne à la ligne (le juge du lot 0 : ni clé vide,
  -- ni numéro de fascicule d'un CSV, ni clé que portent plusieurs lignes du
  -- fichier), connue pour la bibliothèque QUI IMPORTE (destination d'un dépôt
  -- compagnon ou d'un entrepôt OAI, sinon bibliothèque du run), par TOUTE
  -- source de cette bibliothèque, sur UNE notice : la ligne est reconnue,
  -- aucune passe floue ne joue (une ligne reconnue n'est pas rapprochée par
  -- son ISBN vers une autre notice). Détenue ou non (IMP-28 b) : l'écran le
  -- dit (fn_import_list_run_rows.proposed_book_held).
  -- L'avertissement d'ambiguïté d'un passage précédent s'efface : le
  -- rapprochement se rejoue, seul son dernier verdict compte.
  if jsonb_typeof(rec.warnings) = 'array'
     and rec.warnings @> '[{"kind": "known_record_ambiguous"}]'::jsonb then
    update ingest.partner_catalog_staging_rows sr
       set warnings = coalesce((select jsonb_agg(w)
                                  from jsonb_array_elements(sr.warnings) w
                                 where w->>'kind' is distinct from 'known_record_ambiguous'), '[]'::jsonb)
     where sr.id = p_staging_row_id;
  end if;

  v_cle := ingest.fn_h20_cle_de_la_ligne(p_staging_row_id);
  if v_cle is not null then
    select case when s.source_kind in ('partner_deposit', 'oai_pmh') then s.destination_library_id
                else r.library_id end
      into v_bibliotheque_importatrice
      from ingest.partner_catalog_import_runs r
      left join ingest.partner_catalog_sources s on s.id = r.source_id
     where r.id = rec.run_id;

    select array_agg(distinct e.book_id order by e.book_id)
      into v_notices_connues
      from public.book_external_ids e
     where e.library_id = v_bibliotheque_importatrice
       and e.value = v_cle
       and e.scheme like 'import:%';

    if cardinality(v_notices_connues) = 1 then
      insert into ingest.partner_catalog_match_candidates (
        staging_row_id, candidate_type, candidate_id, match_method, match_score, details
      )
      select p_staging_row_id, 'book', b.id, 'external_id', 100.00,
             jsonb_build_object(
               'source_table', 'books',
               'title', b.titulo,
               'author', b.autor,
               'year', b.ano,
               'publisher', b.editora,
               'place', b.local_publicacao,
               'isbn', b.isbn,
               'external_id', v_cle,
               'library_id', v_bibliotheque_importatrice,
               'schemes', (select jsonb_agg(e.scheme order by e.scheme)
                             from public.book_external_ids e
                            where e.library_id = v_bibliotheque_importatrice
                              and e.value = v_cle and e.book_id = b.id
                              and e.scheme like 'import:%'))
        from public.books b
       where b.id = v_notices_connues[1];

      update ingest.partner_catalog_staging_rows
         set match_status = 'known_record',
             proposed_book_id = v_notices_connues[1],
             proposed_book_draft_id = null
       where id = p_staging_row_id;

      return jsonb_build_object(
        'staging_row_id', p_staging_row_id,
        'match_status', 'known_record',
        'top_candidate_type', 'book',
        'top_candidate_id', v_notices_connues[1],
        'top_match_method', 'external_id',
        'top_match_score', 100.00::numeric(5,2)
      );
    elsif cardinality(v_notices_connues) > 1 then
      -- Deux notices (deux sources de la bibliothèque) pour la même valeur :
      -- l'identifiant ne désigne pas UNE notice. Rapprochement ordinaire, dit.
      update ingest.partner_catalog_staging_rows sr
         set warnings = (case when jsonb_typeof(sr.warnings) = 'array' then sr.warnings else '[]'::jsonb end)
                        || jsonb_build_array(jsonb_build_object(
                             'kind', 'known_record_ambiguous',
                             'external_id', v_cle,
                             'book_ids', to_jsonb(v_notices_connues)))
       where sr.id = p_staging_row_id;
    end if;
  end if;
$b$);
  EXECUTE v_def;
END
$h21l1_rapprochement$;
COMMENT ON FUNCTION ingest.fn_match_partner_catalog_row(bigint) IS
  'Rapprochement d''une ligne d''import avec le catalogue. H21 lot 1 (05/10/2026, IMP-28 a) : une ligne dont la clé (ingest.fn_h20_cle_de_la_ligne) est connue dans book_external_ids pour la bibliothèque qui importe, toutes sources, sur une seule notice, est known_record (candidat external_id, score 100) avant toute passe floue ; plusieurs notices : warning known_record_ambiguous.';

-- La compatibilité d'une décision : « Rapprocher » (accept_duplicate) sur une
-- ligne reconnue ; « Créer » (accept_new) reste réservé à new_record.
DO $h21l1_compatibilite$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l1_def('ingest.fn_is_editorial_decision_compatible(text, text)'::regprocedure);
  v_def := pg_temp.h21l1_remplacer('fn_is_editorial_decision_compatible', v_def,
$a$      'possible_duplicate',
      'manual_decision'
    )$a$,
$b$      'possible_duplicate',
      'manual_decision',
      'known_record'   -- H21 lot 1 (IMP-28) : « Rapprocher » une notice déjà importée
    )$b$);
  EXECUTE v_def;
END
$h21l1_compatibilite$;

-- Code mort (aucun appelant), gardé cohérent avec la CHECK.
DO $h21l1_revue$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l1_def('ingest.fn_set_partner_catalog_rows_review(bigint, bigint[], text, boolean, text)'::regprocedure);
  v_def := pg_temp.h21l1_remplacer('fn_set_partner_catalog_rows_review', v_def,
$a$      'matched_draft',
      'manual_decision'
    ) then$a$,
$b$      'matched_draft',
      'manual_decision',
      'known_record'   -- H21 lot 1
    ) then$b$);
  EXECUTE v_def;
END
$h21l1_revue$;

-- « Rapprocher » : une ligne reconnue est éligible (exemplaires sur la notice
-- reconnue). Les deux sélections de la fonction d'ingest, et le filtre de
-- l'écran (lignes déjà traitées ailleurs ignorées).
DO $h21l1_eligibilite$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l1_def('ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure);
  v_def := pg_temp.h21l1_remplacer('fn_create_exemplar_drafts_from_import_rows (éligibilité)', v_def,
$a$and sr.match_status in ('matched_book', 'possible_duplicate', 'manual_decision')$a$,
$b$and sr.match_status in ('matched_book', 'possible_duplicate', 'manual_decision', 'known_record')   -- H21 lot 1$b$, 2);
  EXECUTE v_def;

  v_def := pg_temp.h21l1_def('public.fn_import_reconcile_duplicates(bigint, bigint[])'::regprocedure);
  v_def := pg_temp.h21l1_remplacer('fn_import_reconcile_duplicates (filtre)', v_def,
$a$and sr.match_status in ('matched_book', 'possible_duplicate', 'manual_decision')), '{}'::bigint[])$a$,
$b$and sr.match_status in ('matched_book', 'possible_duplicate', 'manual_decision',
                                                                       'known_record')), '{}'::bigint[])   -- H21 lot 1$b$);
  EXECUTE v_def;
END
$h21l1_eligibilite$;


-- ─────────────────────────────────────────────────────────────────────
-- 3. L'écran : la bibliothèque qui importe détient-elle la notice proposée ?
-- ─────────────────────────────────────────────────────────────────────
-- RETURNS TABLE change : DROP puis création depuis la définition vivante ;
-- colonnes existantes dans le même ordre, la nouvelle à la fin.
DO $h21l1_liste$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l1_def('public.fn_import_list_run_rows(bigint)'::regprocedure);
  v_def := pg_temp.h21l1_remplacer('fn_import_list_run_rows (colonne)', v_def,
$a$created_exemplar_draft_id bigint, created_at timestamp with time zone)$a$,
$b$created_exemplar_draft_id bigint, created_at timestamp with time zone, proposed_book_held boolean)$b$);
  v_def := pg_temp.h21l1_remplacer('fn_import_list_run_rows (déclarations)', v_def,
$a$  v_run_library_id uuid;
BEGIN$a$,
$b$  v_run_library_id uuid;
  v_bibliotheque_importatrice uuid;   -- H21 lot 1 (IMP-28 b)
BEGIN$b$);
  v_def := pg_temp.h21l1_remplacer('fn_import_list_run_rows (bibliothèque qui importe)', v_def,
$a$  IF v_run_library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;
$a$,
$b$  IF v_run_library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  -- H21 lot 1 (05/10/2026, IMP-28 b) : la bibliothèque qui importe — la
  -- destination d'un dépôt compagnon ou d'un entrepôt OAI, sinon celle du run.
  SELECT CASE WHEN s.source_kind IN ('partner_deposit', 'oai_pmh') THEN s.destination_library_id
              ELSE r.library_id END
    INTO v_bibliotheque_importatrice
    FROM ingest.partner_catalog_import_runs r
    LEFT JOIN ingest.partner_catalog_sources s ON s.id = r.source_id
   WHERE r.id = p_run_id;
$b$);
  v_def := pg_temp.h21l1_remplacer('fn_import_list_run_rows (valeur)', v_def,
$a$         sr.created_at
  FROM ingest.partner_catalog_staging_rows sr$a$,
$b$         sr.created_at,
         -- H21 lot 1 (IMP-28 b) : la notice proposée est-elle détenue par la
         -- bibliothèque qui importe ? NULL sans notice proposée. Une ligne
         -- reconnue (known_record) qui ne l'est plus : « plus détenue par ta
         -- bibliothèque » — ni création ni mise à jour, « Rapprocher » ou rejeter.
         CASE WHEN sr.proposed_book_id IS NULL THEN NULL
              ELSE EXISTS (SELECT 1 FROM public.book_holdings h
                            WHERE h.book_id = sr.proposed_book_id
                              AND h.library_id = v_bibliotheque_importatrice) END AS proposed_book_held
  FROM ingest.partner_catalog_staging_rows sr$b$);
  DROP FUNCTION public.fn_import_list_run_rows(bigint);
  EXECUTE v_def;
END
$h21l1_liste$;
REVOKE EXECUTE ON FUNCTION public.fn_import_list_run_rows(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_import_list_run_rows(bigint) TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_import_list_run_rows(bigint) IS
  'Lignes d''un run d''import pour l''écran. H21 lot 1 (05/10/2026, IMP-28 b) : proposed_book_held = la bibliothèque qui importe (destination d''un dépôt ou d''un entrepôt OAI, sinon celle du run) détient la notice proposée (book_holdings) ; NULL sans notice proposée.';


-- ─────────────────────────────────────────────────────────────────────
-- 4. Suites du lot 0 : IMP-28 (c) et (d)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l1_publier_exemplaire$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l1_def('public.publish_exemplar_draft(bigint)'::regprocedure);
  -- (c) l'identifiant d'origine va à la bibliothèque qui a importé la ligne.
  v_def := pg_temp.h21l1_remplacer('publish_exemplar_draft (IMP-28 c)', v_def,
$a$      v_library_id,
      (select r.source_id from ingest.partner_catalog_staging_rows sr$a$,
$b$      -- H21 lot 1 (05/10/2026, IMP-28 c) : un identifiant d'origine appartient
      -- à la bibliothèque dont le PMB l'a émis — celle qui a IMPORTÉ la ligne
      -- (destination d'un dépôt compagnon ou d'un entrepôt OAI, sinon
      -- bibliothèque du run), jamais la cible d'une réattribution
      -- (v_library_id), où un identifiant homonyme de son propre PMB serait
      -- pris pour cette notice.
      (select case when s.source_kind in ('partner_deposit', 'oai_pmh') then s.destination_library_id
                   else r.library_id end
         from ingest.partner_catalog_staging_rows sr
         join ingest.partner_catalog_import_runs r on r.id = sr.run_id
         left join ingest.partner_catalog_sources s on s.id = r.source_id
        where sr.id = v_draft.import_staging_row_id),
      (select r.source_id from ingest.partner_catalog_staging_rows sr$b$);
  -- (d) un exemplaire RATTACHÉ passe la porte de révision des rapprochés.
  v_def := pg_temp.h21l1_remplacer('publish_exemplar_draft (IMP-28 d, porte)', v_def,
$a$      if not public.fn_batch_review_couvre(v_draft.batch_id, p_draft_id, 'exemplar') then
        raise exception 'rascunho_acrescentado_apos_revisao' using hint = 'error.publish.added_after_review';
      end if;
    end if;
  end if;
$a$,
$b$      if not public.fn_batch_review_couvre(v_draft.batch_id, p_draft_id, 'exemplar') then
        raise exception 'rascunho_acrescentado_apos_revisao' using hint = 'error.publish.added_after_review';
      end if;
    end if;
  end if;

  -- H21 lot 1 (05/10/2026, IMP-28 d) : un exemplaire RATTACHÉ à une notice
  -- importée (book_draft_id, que seule la promotion écrit) ne suit plus sa
  -- notice hors de la liste figée du tour : sa notice publiée (garde plus
  -- haut), il passe la même porte que les rapprochés — dans un lot, après une
  -- révision approuvée, et s'il figurait parmi ce que le tour a soumis
  -- (sorti de la corbeille après la demande, il attend un nouveau tour, que
  -- la coordination peut demander : fn_batch_ajouts_apres_revision le compte).
  -- Déjà publié (statut que seule la publication pose, ET exemplaire au
  -- catalogue), il se republie hors lot, comme un rapproché.
  if v_draft.book_draft_id is not null then
    if v_draft.batch_id is null
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
  -- Les deux commentaires qui disaient la transitivité d'avant.
  v_def := pg_temp.h21l1_remplacer('publish_exemplar_draft (commentaire H19)', v_def,
$a$  -- publie elle-même, dans la détention qu'elle vient de poser : la garde de
  -- révision du lot s'applique ainsi par transitivité).$a$,
$b$  -- publie elle-même, dans la détention qu'elle vient de poser). Depuis le
  -- H21 lot 1 (IMP-28 d), il passe aussi la porte de révision (plus bas).$b$);
  v_def := pg_temp.h21l1_remplacer('publish_exemplar_draft (commentaire IMP-27 c)', v_def,
$a$  -- le tour a soumis (b). Un exemplaire d'une notice importée (book_draft_id)
  -- suit la garde de sa notice, qui le publie ; un exemplaire fait à la main,$a$,
$b$  -- le tour a soumis (b). Un exemplaire d'une notice importée (book_draft_id)
  -- passe la même porte (IMP-28 d, plus bas) ; un exemplaire fait à la main,$b$);
  EXECUTE v_def;
END
$h21l1_publier_exemplaire$;

DO $h21l1_publier_notice$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l1_def('public.publish_book_draft(bigint)'::regprocedure);
  v_def := pg_temp.h21l1_remplacer('publish_book_draft (IMP-28 d, boucle)', v_def,
$a$      select x.id from public.exemplar_drafts x
       where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')
       order by x.id$a$,
$b$      select x.id from public.exemplar_drafts x
       where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')
         -- H21 lot 1 (05/10/2026, IMP-28 d) : un rattaché que le dernier tour
         -- approuvé ne couvre pas (sorti de la corbeille après la demande)
         -- reste en brouillon ; la notice se publie. Même porte que
         -- publish_exemplar_draft, jugée avant l'appel : il ne fait pas
         -- échouer la publication de sa notice.
         and (x.batch_id is null
              or not public.fn_batch_is_imported(x.batch_id)
              or public.fn_batch_review_couvre(x.batch_id, x.id, 'exemplar'))
       order by x.id$b$);
  EXECUTE v_def;
END
$h21l1_publier_notice$;

-- IMP-28 (c) pour une notice importée : la bibliothèque qui a importé, pas
-- celle où la notice est publiée (réattribution du lot, reprise par une autre
-- détentrice). Même règle que la reconnaissance, la liste de l'écran et
-- l'exemplaire rapproché ; le run disparu (supprimé), la source le dit.
CREATE OR REPLACE FUNCTION ingest.fn_h21_bibliotheque_importatrice(p_run_id bigint, p_source_id bigint)
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select coalesce(
    (select case when s.source_kind in ('partner_deposit', 'oai_pmh') then s.destination_library_id
                 else r.library_id end
       from ingest.partner_catalog_import_runs r
       left join ingest.partner_catalog_sources s on s.id = r.source_id
      where r.id = p_run_id),
    (select case when s.source_kind in ('partner_deposit', 'oai_pmh') then s.destination_library_id
                 else s.library_id end
       from ingest.partner_catalog_sources s
      where s.id = p_source_id));
$function$;
REVOKE EXECUTE ON FUNCTION ingest.fn_h21_bibliotheque_importatrice(bigint, bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_h21_bibliotheque_importatrice(bigint, bigint) TO service_role;
COMMENT ON FUNCTION ingest.fn_h21_bibliotheque_importatrice(bigint, bigint) IS
  'H21 lot 1 (05/10/2026, IMP-28 c) : la bibliothèque qui a importé — destination de la source pour un dépôt compagnon ou un entrepôt OAI, sinon bibliothèque du run ; run disparu : celle de la source. Interne : publish_book_draft (identifiant d''origine d''une notice importée).';

DO $h21l1_identifiant_notice$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l1_def('public.publish_book_draft(bigint)'::regprocedure);
  v_def := pg_temp.h21l1_remplacer('publish_book_draft (IMP-28 c, brouillon publié)', v_def,
$a$        v_book_id, v_library_id, coalesce((v_draft.marc_json->'ingest'->>'source_id')::bigint,$a$,
$b$        -- H21 lot 1 (05/10/2026, IMP-28 c) : la bibliothèque qui a IMPORTÉ, pas
        -- v_library_id (celle de la notice : un lot réattribué, une reprise).
        v_book_id,
        ingest.fn_h21_bibliotheque_importatrice((v_draft.marc_json->'ingest'->>'run_id')::bigint,
                                                (v_draft.marc_json->'ingest'->>'source_id')::bigint),
        coalesce((v_draft.marc_json->'ingest'->>'source_id')::bigint,$b$);
  v_def := pg_temp.h21l1_remplacer('publish_book_draft (IMP-28 c, brouillons absorbés)', v_def,
$a$              v_book_id, v_library_id, coalesce((l.marc_json->'ingest'->>'source_id')::bigint,$a$,
$b$              v_book_id,
              -- H21 lot 1 (IMP-28 c) : la bibliothèque qui a importé l'absorbé.
              ingest.fn_h21_bibliotheque_importatrice((l.marc_json->'ingest'->>'run_id')::bigint,
                                                      (l.marc_json->'ingest'->>'source_id')::bigint),
              coalesce((l.marc_json->'ingest'->>'source_id')::bigint,$b$);
  EXECUTE v_def;
END
$h21l1_identifiant_notice$;

-- « Publier le lot » : un rattaché dont la notice est DÉJÀ publiée n'avait
-- aucun chemin de lot (la boucle des notices ne prend que draft/ready, celle
-- des exemplaires que les exemplaires sans notice) : après le nouveau tour,
-- le lot se fermait sur lui, en brouillon (mesuré au banc le 05/10). Il passe
-- désormais par la boucle des exemplaires — publié s'il est couvert, sinon la
-- publication du lot est refusée (added_after_review), tout ou rien, comme
-- pour une notice ajoutée. Ceux d'une notice écartée restent hors du lot.
DO $h21l1_publier_lot$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l1_def('public.publish_catalog_batch(bigint)'::regprocedure);
  v_def := pg_temp.h21l1_remplacer('publish_catalog_batch (rattachés d''une notice publiée)', v_def,
$a$      -- ceux d'une notice écartée restent en brouillon, ils ne font pas échouer le lot.
      and book_draft_id is null$a$,
$b$      -- ceux d'une notice écartée restent en brouillon, ils ne font pas échouer le lot.
      and (book_draft_id is null
           -- H21 lot 1 (05/10/2026, IMP-28 d) : un rattaché dont la notice est
           -- DÉJÀ publiée (sorti de la corbeille après la demande, laissé par
           -- publish_book_draft) se publie avec le lot s'il est couvert ; sinon
           -- publish_exemplar_draft refuse le lot entier (added_after_review) —
           -- jamais un lot fermé sur un exemplaire oublié.
           or exists (select 1 from public.book_drafts bd
                       where bd.id = exemplar_drafts.book_draft_id
                         and bd.status = 'published' and bd.published_book_id is not null))$b$);
  EXECUTE v_def;
END
$h21l1_publier_lot$;

DO $h21l1_ajouts$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l1_def('public.fn_batch_ajouts_apres_revision(bigint)'::regprocedure);
  v_def := pg_temp.h21l1_remplacer('fn_batch_ajouts_apres_revision (rattachés)', v_def,
$a$               where x.batch_id = p_batch_id and x.book_draft_id is null
$a$,
$b$               -- H21 lot 1 (05/10/2026, IMP-28 d) : les rattachés comptent aussi —
               -- ils attendent un tour comme les autres.
               where x.batch_id = p_batch_id
$b$);
  EXECUTE v_def;
END
$h21l1_ajouts$;
COMMENT ON FUNCTION public.fn_batch_ajouts_apres_revision(bigint) IS
  'IMP-27 b (29/09/2026) : brouillons vivants d''un lot approuvé que le dernier tour ne couvre pas — exemplaires rattachés à une notice compris depuis le H21 lot 1 (IMP-28 d, 05/10/2026). Interne : fn_batch_review_request, fn_batch_reviews_list.';


-- ─────────────────────────────────────────────────────────────────────
-- 5. Vérification (structurelle : les migrations passent avant le seed)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l1_verif$
DECLARE
  v_e text := '';
  v_def text;
BEGIN
  IF position('known_record' IN pg_get_constraintdef((SELECT oid FROM pg_constraint
        WHERE conname = 'partner_catalog_staging_rows_match_status_check'
          AND conrelid = 'ingest.partner_catalog_staging_rows'::regclass))) = 0 THEN v_e := v_e || ' check-statut'; END IF;
  IF position('external_id' IN pg_get_constraintdef((SELECT oid FROM pg_constraint
        WHERE conname = 'partner_catalog_match_candidates_match_method_check'
          AND conrelid = 'ingest.partner_catalog_match_candidates'::regclass))) = 0 THEN v_e := v_e || ' check-methode'; END IF;
  IF to_regclass('public.book_external_ids_bibliotheque_valeur_idx') IS NULL THEN v_e := v_e || ' index'; END IF;

  v_def := pg_get_functiondef('ingest.fn_match_partner_catalog_row(bigint)'::regprocedure);
  IF position('ingest.fn_h20_cle_de_la_ligne(p_staging_row_id)' IN v_def) = 0
     OR position('''known_record_ambiguous''' IN v_def) = 0
     OR position('e.scheme like ''import:%''' IN v_def) = 0
     OR position('s.destination_library_id' IN v_def) = 0
     -- la reconnaissance AVANT la première passe floue
     OR position('''known_record''' IN v_def) > position('1) ISBN EXACT -> BOOKS' IN v_def)
     OR (length(v_def) - length(replace(v_def, '<> ''artigo''', ''))) / length('<> ''artigo''') <> 4
     OR position('statement_timeout TO ''120s''' IN v_def) = 0 THEN v_e := v_e || ' rapprochement'; END IF;
  IF NOT ingest.fn_is_editorial_decision_compatible('known_record', 'accept_duplicate')
     OR ingest.fn_is_editorial_decision_compatible('known_record', 'accept_new')
     OR NOT ingest.fn_is_editorial_decision_compatible('known_record', 'reject')
     OR NOT ingest.fn_is_editorial_decision_compatible('new_record', 'accept_new') THEN v_e := v_e || ' compatibilite'; END IF;
  IF (length(pg_get_functiondef('ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure))
      - length(replace(pg_get_functiondef('ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure),
                       '''manual_decision'', ''known_record'')', ''))) / length('''manual_decision'', ''known_record'')') <> 2 THEN v_e := v_e || ' eligibilite'; END IF;
  IF position('''known_record'')), ''{}''::bigint[])' IN pg_get_functiondef('public.fn_import_reconcile_duplicates(bigint, bigint[])'::regprocedure)) = 0 THEN v_e := v_e || ' rapprocher'; END IF;
  IF position('''known_record''' IN pg_get_functiondef('ingest.fn_set_partner_catalog_rows_review(bigint, bigint[], text, boolean, text)'::regprocedure)) = 0 THEN v_e := v_e || ' revue'; END IF;

  -- la liste : la colonne ajoutée à la fin, droits de l'écran
  IF (SELECT (p.proargnames)[array_length(p.proargnames, 1)] FROM pg_proc p
       WHERE p.oid = 'public.fn_import_list_run_rows(bigint)'::regprocedure) IS DISTINCT FROM 'proposed_book_held'
     OR (SELECT (p.proargnames)[array_length(p.proargnames, 1) - 1] FROM pg_proc p
          WHERE p.oid = 'public.fn_import_list_run_rows(bigint)'::regprocedure) IS DISTINCT FROM 'created_at'
     OR (SELECT array_length(p.proargnames, 1) FROM pg_proc p
          WHERE p.oid = 'public.fn_import_list_run_rows(bigint)'::regprocedure) <> 33 THEN v_e := v_e || ' liste-colonnes'; END IF;

  v_def := pg_get_functiondef('public.publish_exemplar_draft(bigint)'::regprocedure);
  IF position('IMP-28 c' IN v_def) = 0
     OR (length(v_def) - length(replace(v_def, 'error.publish.added_after_review', ''))) / length('error.publish.added_after_review') <> 2
     OR (length(v_def) - length(replace(v_def, 'error.publish.imported_needs_batch', ''))) / length('error.publish.imported_needs_batch') <> 2
     OR position('IMP-28 d) : un exemplaire RATTACHÉ' IN v_def) < position('error.publish.item_before_record' IN v_def)
     -- les gardes d'avant restent
     OR position('ingest.fn_h20_cle_de_la_ligne(v_draft.import_staging_row_id)' IN v_def) = 0
     OR position('error.publish.exemplar_moved' IN v_def) = 0
     OR position('fn_fonds_vides_menage' IN v_def) = 0
     OR position('bd.published_book_id is null then' IN v_def) = 0
     OR position('par transitivité' IN v_def) > 0 THEN v_e := v_e || ' publier-exemplaire'; END IF;
  v_def := pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure);
  IF position('public.fn_batch_review_couvre(x.batch_id, x.id, ''exemplar'')' IN v_def) = 0
     OR position('error.publish.imported_needs_batch' IN v_def) = 0
     OR position('error.publish.added_after_review' IN v_def) = 0
     OR position('item_tag' IN v_def) = 0 THEN v_e := v_e || ' publier-notice'; END IF;
  IF (length(v_def) - length(replace(v_def, 'ingest.fn_h21_bibliotheque_importatrice(', ''))) / length('ingest.fn_h21_bibliotheque_importatrice(') <> 2
     OR position('v_book_id, v_library_id, coalesce(' IN v_def) > 0 THEN v_e := v_e || ' identifiant-notice'; END IF;
  IF has_function_privilege('authenticated', 'ingest.fn_h21_bibliotheque_importatrice(bigint, bigint)', 'EXECUTE')
     OR has_function_privilege('anon', 'ingest.fn_h21_bibliotheque_importatrice(bigint, bigint)', 'EXECUTE') THEN v_e := v_e || ' droits-importatrice'; END IF;
  IF position('x.book_draft_id is null' IN pg_get_functiondef('public.fn_batch_ajouts_apres_revision(bigint)'::regprocedure)) > 0 THEN v_e := v_e || ' ajouts'; END IF;
  v_def := pg_get_functiondef('public.publish_catalog_batch(bigint)'::regprocedure);
  IF position('where bd.id = exemplar_drafts.book_draft_id' IN v_def) = 0
     OR position('error.batch.other_authors' IN v_def) = 0 THEN v_e := v_e || ' publier-lot'; END IF;

  -- droits : l'écran garde les siens, les aides internes restent fermées
  IF EXISTS (SELECT 1 FROM unnest(ARRAY[
        'public.fn_import_list_run_rows(bigint)', 'public.fn_import_reconcile_duplicates(bigint, bigint[])',
        'public.publish_exemplar_draft(bigint)', 'public.publish_book_draft(bigint)',
        'public.publish_catalog_batch(bigint)']) f
      WHERE NOT has_function_privilege('authenticated', f, 'EXECUTE') OR has_function_privilege('anon', f, 'EXECUTE')
         OR NOT has_function_privilege('service_role', f, 'EXECUTE')) THEN
    v_e := v_e || ' droits-ecran';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
              WHERE p.oid = 'public.fn_import_list_run_rows(bigint)'::regprocedure AND a.grantee = 0) THEN
    v_e := v_e || ' droits-public';
  END IF;
  IF EXISTS (SELECT 1 FROM unnest(ARRAY[
        'ingest.fn_match_partner_catalog_row(bigint)', 'ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)',
        'ingest.fn_set_partner_catalog_rows_review(bigint, bigint[], text, boolean, text)',
        'public.fn_batch_ajouts_apres_revision(bigint)']) f
      WHERE has_function_privilege('authenticated', f, 'EXECUTE') OR has_function_privilege('anon', f, 'EXECUTE')
         OR NOT has_function_privilege('service_role', f, 'EXECUTE')) THEN
    v_e := v_e || ' droits-internes';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p
              WHERE p.oid IN ('ingest.fn_match_partner_catalog_row(bigint)'::regprocedure,
                              'ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure,
                              'public.fn_import_reconcile_duplicates(bigint, bigint[])'::regprocedure,
                              'public.fn_import_list_run_rows(bigint)'::regprocedure,
                              'public.publish_exemplar_draft(bigint)'::regprocedure,
                              'public.publish_book_draft(bigint)'::regprocedure,
                              'public.publish_catalog_batch(bigint)'::regprocedure,
                              'public.fn_batch_ajouts_apres_revision(bigint)'::regprocedure)
                AND (NOT p.prosecdef OR coalesce(p.proconfig::text, '') NOT LIKE '%search_path%')) THEN
    v_e := v_e || ' definer';
  END IF;

  IF v_e <> '' THEN
    RAISE EXCEPTION 'H21 lot 1 : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'H21 lot 1 : vérifications OK';
END
$h21l1_verif$;

NOTIFY pgrst, 'reload schema';
