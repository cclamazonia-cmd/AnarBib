-- =====================================================================
-- H21 lot 3 — comparer à trois états, en lecture seule
-- (REGISTRE IMP-23, IMP-26, IMP-28, IMP-29 ; cartographie H21 du 28/09,
-- §5.1, §5.7, §5.8 ligne « 3 — Comparer », pièges 3, 19 et 20)
--
-- Pour chaque ligne `known_record` d'un run (une notice que la bibliothèque
-- qui importe a déjà importée, lot 1), comparer champ par champ :
--   B = la base de son identifiant d'origine (ingest.book_import_baselines,
--       lot 2), pour la bibliothèque qui importe ;
--   A = la notice AnarBib maintenant (books, book_contributors ; JAMAIS
--       books.autor — piège 3 : 203 écarts sur 264 en production) ;
--   N = le nouveau fichier, passé par la MÊME correspondance
--       (ingest.fn_import_row_as_book, lot 2).
-- Aucune écriture au catalogue, aucun brouillon : le lot 3 calcule, stocke le
-- résultat sur la ligne de staging et le montre. Rien ne s'applique (lot 4).
--
-- 1. Les verdicts (ingest.fn_h21_verdict, UNE règle pour tous les champs).
--    La spécification du 05/10 définit `inchange` par « N = B, A ≠ N » et
--    `local_seul` par « B = N ≠ A » : deux fois la même condition. Avec trois
--    valeurs, il n'y a que cinq situations ; je retiens la lecture de la liste
--    des tests de la spécification (« identique (les deux, pareil) »,
--    « inchangé ») :
--      inchange      B = A = N    rien n'a bougé ;
--      identique     A = N ≠ B    les deux ont changé, pareil (rien à faire) ;
--      source_seule  B = A ≠ N    le fichier seul a changé : le SEUL verdict
--                                 que le lot 4 pourra appliquer ;
--      local_seul    B = N ≠ A    AnarBib seule a changé : on garde AnarBib ;
--      conflit       B, A, N tous différents : signalé, jamais appliqué ;
--      sans_base     base absente, ou champ marqué douteux dans la base
--                    (base.reprise_champs_douteux, piège 20), ET A ≠ N :
--                    « à revoir », jamais appliqué d'office.
--    Sans base, ou sur un champ douteux, A = N donne `identique` (le fichier
--    dit ce que dit AnarBib : il n'y a rien à revoir), jamais `sans_base`.
--    Lecture retenue par Xavier le 06/10/2026 (ces verdicts, et l'accès des
--    RPC ci-dessous).
--
-- 2. Les champs comparés (liste FERMÉE, ingest.fn_h21_champs_compares()) :
--    les colonnes que fn_import_row_as_book produit (clé `mapped`) et qui
--    existent sur books ET book_drafts (une colonne de books = trois endroits :
--    book_drafts, publish_book_draft, create_book_draft_from_book) — titulo,
--    subtitulo, edicao, local_publicacao, editora, ano, isbn, issn, idioma,
--    tipo_material, cdd, colecao, notas, paginas, volume, digital_native_url,
--    titulo_periodico, artigo_source, artigo_volume, artigo_issue,
--    artigo_pages, data_edicao, numero —, plus `contributors` : 24 champs.
--    Exclus, liste fermée :
--      - subjects (décision de Xavier du 06/10/2026, REGISTRE IMP-30) : les
--        vedettes du fichier ne sont pas comparées pour l'instant. L'import ne
--        les verse pas dans book_subjects : la création des brouillons les
--        écrit dans notas (« Assuntos importados : … »), qui est comparé — une
--        vedette changée dans le fichier s'y voit (source_seule sur notas).
--        Comparées à book_subjects, elles donnaient local_seul sur toute
--        notice importée sans vedette cataloguée, et conflit à chaque vedette
--        changée dans le fichier. À rouvrir quand l'import alimentera
--        book_subjects ;
--      - autor : piège 3, books.autor n'est pas l'auteur du fichier ; les
--        responsabilités se comparent par `contributors` (book_contributors) ;
--      - tout ce que la correspondance rend hors de `mapped` : provenance
--        (source_record_id, partner_source, source_label, provenance_note),
--        marc_json (trace d'import), raw_payload, payload_hash,
--        mapping_version — de la provenance, pas de la description ;
--      - toute colonne de books que la correspondance ne produit pas :
--        identifiants (id, work_id, serial_id, publisher_id), horodatages
--        (created_at, updated_at, last_cataloged_at — piège 19 : rien ne date
--        une modification, seule la valeur compte), bib_ref (champ local),
--        couverture (cover_*), owner_library_id, holder/owner_library, prêt
--        (loanable), et les champs propres aux types que l'import ne remplit
--        pas (audio_*, tract_*, zine_*…).
--    La migration vérifie que la liste fermée = les clés de `mapped` moins
--    autor : une correspondance qui gagnerait une clé fait échouer une
--    migration qui recréerait ces fonctions sans la regarder.
--
-- 3. La normalisation (ce qui est comparé, et rendu comme valeur) :
--    - un champ texte : nullif(btrim(valeur), '') — une espace en bord ou une
--      chaîne vide ne sont pas des modifications (l'écran de catalogage et
--      l'import n'ont jamais garanti l'un ou l'autre) ; la casse et
--      l'intérieur du texte COMPTENT : corriger une majuscule est un geste
--      local que le lot 4 ne doit pas défaire ;
--    - paginas (entier) : sa forme texte, même règle ;
--    - contributors : une LISTE ORDONNÉE de paires [nom, rôle] (nom :
--      nullif(btrim) ; rôle tel quel ; par position) — l'ordre dit qui est la
--      responsabilité principale ; is_primary s'en déduit (première), nature
--      et role_code sont des détails du MARC que l'écran ne montre pas comme
--      responsabilité. A : book_contributors, JAMAIS books.autor.
--
-- 4. La base d'une ligne : l'identifiant d'origine (bibliothèque qui importe —
--    ingest.fn_h21_bibliotheque_importatrice —, clé btrim(external_key) :
--    une ligne known_record a passé le juge ingest.fn_h20_cle_de_la_ligne au
--    rapprochement, seul à poser ce statut —, schéma import:%) qui désigne la notice
--    proposée ; plusieurs (plusieurs sources de la bibliothèque) : celui de la
--    source du run d'abord, puis la base la plus récemment acceptée.
--
-- 5. Le stockage : sur la ligne de staging (comparaison jsonb,
--    comparaison_at), pas dans une table. Pourquoi : la comparaison est un
--    attribut de la ligne, recalculé à chaque rapprochement ; elle part avec
--    elle (« Retraiter », suppression du run) sans clé étrangère ni purge à
--    écrire ; ingest entre tout entier au flux long #BG2 depuis I29 (05/10),
--    lignes de staging comprises — rien à classer dans
--    deploy/bg2-known-tables.txt ; la taille (24 champs, valeurs normalisées :
--    1 Ko compressé en moyenne au banc, 2 000 lignes ; davantage pour des notes
--    longues) va dans le TOAST de la ligne.
--    Contenu : version, notice, base, comptes par verdict, et pour chaque
--    champ le verdict et les trois valeurs comparées ; plus l'empreinte de ce
--    que le fichier dit de la ligne (empreinte_fichier : md5 des colonnes que
--    la correspondance lit et de la version de la règle —
--    ingest.fn_h21_version_de_la_regle, l'empreinte des définitions de la
--    correspondance, de ses aides et de la normalisation). Tant que
--    l'empreinte tient, un recalcul reprend N (champs[].n) au lieu de rejouer
--    la correspondance, qui fait les trois quarts du coût (voir 7) ; A
--    est toujours relu, B aussi (sa normalisation reprise tant que
--    l'empreinte de la base tient : empreinte_base).
--    Écrite par public.fn_import_recomparer(p_run_id, p_row_ids) SEULEMENT,
--    par pages (l'écran : 200 lignes par appel), sous le verrou du run des
--    conversions H31 (FOR NO KEY UPDATE, après les contrôles d'accès).
--    PAS dans le rapprochement : les edge functions appellent
--    fn_match_partner_catalog_run par PostgREST sous authenticator
--    (statement_timeout 8 s, lock_timeout 8 s ; un SET statement_timeout dans
--    la fonction ne prolonge pas l'instruction en cours), et le premier calcul
--    coûte ~3 ms par ligne reconnue (voir 7) : un gros réimport y échouerait
--    (revue sceptique du 06/10). Le rapprochement n'y fait qu'un geste léger :
--    il EFFACE la comparaison des lignes de son périmètre qui ne sont plus
--    known_record, ou dont la notice proposée n'est plus celle comparée.
--    L'écran (ImportacoesPage), à l'ouverture d'un run, recalcule par pages de
--    200 les lignes known_record dont comparison_counts est NULL (jamais
--    calculée, effacée, ou périmée : voir la liste ci-dessous) — si
--    l'appelant est la coordination ou l'administration ; sinon la mention dit
--    « comparaison non calculée ».
--    Lecture : la liste (fn_import_list_run_rows.comparison_counts) et la
--    section du rapport de révision (fn_batch_review_report.updates) lisent
--    le STOCKÉ — plus de calcul à la lecture, qui pouvait dépasser 8 s ; la
--    liste rend NULL pour une comparaison dont la notice n'est plus la notice
--    proposée (une fusion de notices déplace proposed_book_id : la
--    comparaison est alors périmée, et l'écran la recalcule) ; le rapport dit
--    combien de lignes du lot sont comparées et la date de la plus ancienne
--    comparaison. Le détail d'une ligne (fn_import_row_comparison) est calculé
--    à la lecture : une ligne, quelques millisecondes.
--
-- 6. Accès. ingest.fn_import_trois_etats et les aides restent internes
--    (service_role ; schéma ingest fermé). Lire (fn_import_row_comparison, la
--    liste) : le staff (accès au panneau, my_access) de la bibliothèque du run,
--    ou l'administration du réseau. Recalculer (fn_import_recomparer) : les
--    mêmes contrôles que fn_import_set_editorial — la coordination de la
--    bibliothèque du run, ou l'administration (qui a, comme là, une
--    bibliothèque active : celle du run) ; le librarian lit, ne recalcule pas.
--    Lecture hors RLS : fn_import_row_comparison et la section du rapport
--    rendent les valeurs AnarBib (A) d'une notice que l'appelant ne verrait pas
--    au catalogue — la règle de la policy books_select_authenticated
--    (administration ; ou une détentrice dans fn_visible_library_ids() ; ou une
--    détentrice dont l'appelant est staff : ingest.fn_h21_notice_visible) —
--    masquées (a : null, a_masque : true) ; les verdicts restent (revue
--    sceptique du 06/10 : une notice détenue par une seule bibliothèque
--    privée, dont BLMF garde l'identifiant d'origine, montrait son titre et
--    ses notes). Constat consigné, non corrigé ici (antérieur au lot 3) :
--    fn_import_list_run_rows.proposed_title rend déjà le titre de la notice
--    proposée sans ce contrôle.
--
-- 7. Performance (plafond : statement_timeout d'authenticated, 8 s, qui
--    vaut aussi pour les edge functions — authenticator) : mesurée au banc
--    privé (tests/sql/h21_lot3_comparer_tests.sql, T14, et un banc EXPLAIN
--    ANALYZE hors dépôt ; poste chargé, CI à l'arrêt, statistiques à jour) :
--    un run de 2 000 lignes known_record, chacune avec base, 2
--    responsabilités, 10 % de notices retouchées, recalculé par
--    fn_import_recomparer en 10 pages de 200 lignes (accès + verrou +
--    comparaison + stockage) :
--    - premier calcul (la correspondance rejouée sur chaque ligne), 3 tirs du
--      06/10 : page la plus lente 428 à 703 ms, les 10 pages 4,2 à 4,7 s ; la
--      correspondance ingest.fn_import_row_as_book (lot 2) en fait l'essentiel
--      (~1,5 à 2 ms par ligne) ;
--    - recalcul du run entier en un appel (N et B normalisés gardés) : 1,4 à
--      2,1 s (mêmes tirs, 24 champs).
--    Sur un tir où le poste était saturé (charge 7 sur 8 cœurs), tous les
--    temps ont triplé : une page de 200 reste sous 2 s.
--    Rejouer le juge H20 par ligne (fn_h20_cle_de_la_ligne) coûtait à lui seul
--    5,6 s pour 2 000 lignes (statistiques absentes) : la clé est lue telle
--    quelle (voir 4).
--
-- 8. Consigné, non corrigé :
--    - une comparaison stockée ne suit pas la notice : une retouche dans
--      AnarBib après le calcul n'est vue qu'au prochain recalcul (bouton de
--      l'écran à venir au lot 4 ; aujourd'hui : rouvrir un run ne recalcule
--      que les comparaisons absentes ou périmées par fusion). Une fusion de
--      notices, elle, est détectée (book_id stocké ≠ notice proposée) ;
--    - N gardé est invalidé par toute migration qui redéfinit la
--      correspondance ou ses aides, normalize_author_alias comprise
--      (ingest.fn_h21_version_de_la_regle) : le recalcul suivant rejoue la
--      correspondance sur toutes les lignes (premier calcul, par pages) ;
--    - proposed_title (liste) : voir 6.

-- Méthode : chaque fonction existante est modifiée SUR SA DÉFINITION VIVANTE
-- (pg_get_functiondef, retours chariot retirés) par ancres comptées ; DROP +
-- CREATE pour fn_import_list_run_rows seulement (RETURNS TABLE change), droits
-- restaurés à l'identique. md5 de prosrc lus le 05/10 sur le banc reconstruit
-- depuis le dépôt ET en production (identiques) :
--   ingest.fn_match_partner_catalog_run  b26da46644a96d1316cd514d05ac8cc7
--   public.fn_import_list_run_rows       1a1dbba797694bda03bf58dc213040f6
--   public.fn_batch_review_report        10f959b6282ab28ab46d072a59452b0e
-- Suite : tests/sql/h21_lot3_comparer_tests.sql.
-- =====================================================================

-- Outils de la migration, éphémères (pg_temp).
CREATE OR REPLACE FUNCTION pg_temp.h21l3_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'H21 lot 3 — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN
    RAISE EXCEPTION 'H21 lot 3 — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

CREATE OR REPLACE FUNCTION pg_temp.h21l3_def(p_fn regprocedure)
RETURNS text LANGUAGE sql AS $f$
  SELECT replace(pg_get_functiondef(p_fn), E'\r', '');
$f$;


-- ─────────────────────────────────────────────────────────────────────
-- 1. Le stockage, sur la ligne de staging
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE ingest.partner_catalog_staging_rows
  ADD COLUMN IF NOT EXISTS comparaison jsonb,
  ADD COLUMN IF NOT EXISTS comparaison_at timestamptz;
DO $h21l3_check$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'ingest.partner_catalog_staging_rows'::regclass
                    AND conname = 'partner_catalog_staging_rows_comparaison_objet') THEN
    ALTER TABLE ingest.partner_catalog_staging_rows
      ADD CONSTRAINT partner_catalog_staging_rows_comparaison_objet
      CHECK (comparaison IS NULL OR jsonb_typeof(comparaison) = 'object');
  END IF;
END
$h21l3_check$;
COMMENT ON COLUMN ingest.partner_catalog_staging_rows.comparaison IS
  'H21 lot 3 (05/10/2026) : comparaison à trois états d''une ligne known_record — base (ingest.book_import_baselines), '
  'notice AnarBib, fichier (ingest.fn_import_row_as_book) : {version, book_id, baseline_id, counts{verdict: n}, '
  'champs[{champ, verdict, b, a, n}]}. Écrite par ingest.fn_h21_stocker_comparaisons (appelée par '
  'public.fn_import_recomparer, par pages) ; effacée par le rapprochement quand elle devient fausse. NULL hors known_record.';
COMMENT ON COLUMN ingest.partner_catalog_staging_rows.comparaison_at IS
  'H21 lot 3 : quand la comparaison a été calculée.';


-- ─────────────────────────────────────────────────────────────────────
-- 2. Les règles : champs, normalisation, verdict
-- ─────────────────────────────────────────────────────────────────────
-- La liste fermée des champs comparés, dans l'ordre de l'écran.
CREATE OR REPLACE FUNCTION ingest.fn_h21_champs_compares()
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
 SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
  select array['titulo', 'subtitulo', 'edicao', 'local_publicacao', 'editora', 'ano', 'isbn', 'issn', 'idioma',
               'tipo_material', 'cdd', 'colecao', 'notas', 'paginas', 'volume', 'digital_native_url',
               'titulo_periodico', 'artigo_source', 'artigo_volume', 'artigo_issue', 'artigo_pages', 'data_edicao',
               'numero', 'contributors']::text[];   -- subjects : exclu (IMP-30, voir l'en-tête)
$function$;

-- LE verdict d'un champ (voir l'en-tête, 1).
CREATE OR REPLACE FUNCTION ingest.fn_h21_verdict(p_base_utilisable boolean, p_a_egal_n boolean,
                                                 p_n_egal_b boolean, p_b_egal_a boolean)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
 SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
  select case
    when not coalesce(p_base_utilisable, false) then
      case when p_a_egal_n then 'identique' else 'sans_base' end
    when p_a_egal_n and p_n_egal_b then 'inchange'
    when p_a_egal_n then 'identique'
    when p_b_egal_a then 'source_seule'
    when p_n_egal_b then 'local_seul'
    else 'conflit'
  end;
$function$;

-- Les responsabilités : liste ordonnée de [nom, rôle] (NULL si pas de liste).
CREATE OR REPLACE FUNCTION ingest.fn_h21_responsabilites(p jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
 SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
  select case when jsonb_typeof(p) = 'array' then
    coalesce((select jsonb_agg(jsonb_build_array(nullif(btrim(c.v->>'name'), ''), c.v->>'role')
                               order by case when (c.v->>'position') ~ '^[0-9]{1,9}$' then (c.v->>'position')::int end nulls last, c.o)
                from jsonb_array_elements(p) with ordinality c(v, o)
               where jsonb_typeof(c.v) = 'object' and nullif(btrim(c.v->>'name'), '') is not null), '[]'::jsonb)
  end;
$function$;

-- Ce que la correspondance dit d'une ligne (ou ce qu'une base a gardé), dans
-- l'espace comparé : {champ: valeur normalisée} pour les 24 champs.
CREATE OR REPLACE FUNCTION ingest.fn_h21_normaliser(p_livre jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
 SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
  select jsonb_object_agg(f.champ, case f.champ
           when 'contributors' then ingest.fn_h21_responsabilites(m.livre->'contributors')
           else to_jsonb(nullif(btrim(m.mapped->>f.champ), '')) end)
    from (select p_livre as livre, p_livre->'mapped' as mapped) m
    cross join unnest(ingest.fn_h21_champs_compares()) f(champ);
$function$;

-- La version de la règle : l'empreinte des définitions qui font N (la
-- correspondance et ses aides, la liste des champs, la normalisation). Une
-- correspondance redéfinie invalide le N gardé sur les lignes.
CREATE OR REPLACE FUNCTION ingest.fn_h21_version_de_la_regle()
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'pg_temp'
AS $function$
  select md5(string_agg(md5(p.prosrc), '/' order by n.nspname, p.proname))
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
   where (n.nspname = 'ingest' and p.proname in ('fn_import_row_as_book', 'fn_partner_catalog_extract_collection_hint',
                                                 'fn_partner_catalog_extract_local_classification_hint',
                                                 'fn_format_partner_authors', 'fn_idioma_bcp47', 'fn_h18_nom_d_auteur',
                                                 'fn_h21_champs_compares', 'fn_h21_responsabilites',
                                                 'fn_h21_normaliser'))
      or (n.nspname = 'public' and p.proname in ('fn_conv_est_non_agent', 'normalize_author_alias'));
$function$;


-- ─────────────────────────────────────────────────────────────────────
-- 3. La comparaison, ensembliste (une passe SQL)
-- ─────────────────────────────────────────────────────────────────────
-- p_row_ids NULL : tout le run ; tableau (même vide) : ces lignes seulement.
-- N gardé : la correspondance coûte ~1,5 à 2 ms par ligne (mesuré au banc,
-- 2 000 lignes : 2,8 à 4,5 s, les trois quarts de la comparaison). N ne dépend
-- que de la ligne (ce que le fichier dit) et de la règle : il est gardé dans la
-- comparaison stockée (champs[].n) avec son empreinte (empreinte_fichier =
-- md5 des colonnes que la correspondance lit + version de la règle) ; il n'est
-- recalculé que si l'empreinte a changé. De même B normalisé (champs[].b),
-- gardé avec l'empreinte de la base (empreinte_base : son id, ses valeurs, la
-- règle). A (la notice) est toujours relu ; B toujours relu dans la table
-- (seule sa normalisation est reprise).
CREATE OR REPLACE FUNCTION ingest.fn_import_trois_etats(p_run_id bigint, p_row_ids bigint[] DEFAULT NULL)
 RETURNS TABLE(staging_row_id bigint, book_id bigint, baseline_id bigint, champ text, ordre integer, verdict text,
               valeur_base jsonb, valeur_anarbib jsonb, valeur_fichier jsonb, empreinte_fichier text,
               empreinte_base text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  with run as materialized (
    select r.id, r.source_id,
           ingest.fn_h21_bibliotheque_importatrice(r.id, NULL, NULL) as lib,
           coalesce(ingest.fn_h21_contexte_du_run(r.id), '{}'::jsonb) as ctx,
           ingest.fn_h21_version_de_la_regle() as regle
      from ingest.partner_catalog_import_runs r
     where r.id = p_run_id
  ), lignes0 as materialized (
    -- La clé : btrim(external_key). Une ligne known_record a passé le juge
    -- H20 (ingest.fn_h20_cle_de_la_ligne) au rapprochement, seul à poser ce
    -- statut, et sa clé ne change plus (« Retraiter » recrée les lignes) ;
    -- rejouer le juge ligne par ligne coûtait 2,8 ms par ligne au banc.
    select sr.id, sr.proposed_book_id, run.lib, run.source_id, run.ctx, run.regle, sr as ligne,
           btrim(sr.external_key) as cle,
           sr.comparaison as gardee,
           md5(jsonb_build_array(sr.item_type, sr.title, sr.subtitle, sr.responsibility_statement, sr.authors,
                                 sr.edition_statement, sr.place_of_publication, sr.publisher, sr.publication_year,
                                 sr.isbn, sr.issn, sr.language, sr.subjects, sr.normalized_payload, sr.raw_payload)::text  -- subjects : ils font notas
               || '/' || run.regle) as empreinte
      from ingest.partner_catalog_staging_rows sr
      cross join run
     where sr.run_id = p_run_id
       and sr.match_status = 'known_record'
       and sr.proposed_book_id is not null
       and (p_row_ids is null or sr.id = any (p_row_ids))
  ), lignes as materialized (
    -- N : la ligne passée par LA correspondance (celle de la création),
    -- normalisée ; le N gardé si la ligne et la règle n'ont pas changé.
    select l.id, l.proposed_book_id, l.lib, l.source_id, l.empreinte, l.cle, l.gardee, l.regle,
           case when l.gardee->>'empreinte_fichier' = l.empreinte
                     and jsonb_typeof(l.gardee->'champs') = 'array'
                     and jsonb_array_length(l.gardee->'champs') = cardinality(ingest.fn_h21_champs_compares())
                then (select jsonb_object_agg(c->>'champ', c->'n') from jsonb_array_elements(l.gardee->'champs') c)
                else ingest.fn_h21_normaliser(ingest.fn_import_row_as_book(l.ligne, l.ctx)) end as nf
      from lignes0 l
  ), etats as materialized (
    select l.id, b.id as book_id, l.nf, l.empreinte,
           -- B : la base de l'identifiant (bibliothèque qui importe, clé jugée,
           -- notice proposée), normalisée comme N (la normalisation gardée si
           -- la base et la règle n'ont pas changé)
           bl.id as baseline_id, bl.empreinte_base,
           case when bl.id is null then null
                when l.gardee->>'empreinte_base' = bl.empreinte_base
                     and jsonb_typeof(l.gardee->'champs') = 'array'
                     and jsonb_array_length(l.gardee->'champs') = cardinality(ingest.fn_h21_champs_compares())
                then (select jsonb_object_agg(c->>'champ', c->'b') from jsonb_array_elements(l.gardee->'champs') c)
                else ingest.fn_h21_normaliser(jsonb_build_object('mapped', bl.mapped, 'contributors', bl.contributors))
           end as bf,
           coalesce(bl.reprise_champs_douteux, '{}'::text[]) as douteux,
           -- A : la notice maintenant ; responsabilités par book_contributors (piège 3)
           to_jsonb(b) as a_livre,
           ingest.fn_h21_responsabilites(
             coalesce((select jsonb_agg(jsonb_build_object('position', c.position, 'name', c.name, 'role', c.role)
                                        order by c.position)
                         from public.book_contributors c where c.book_id = b.id), '[]'::jsonb)) as a_contrib
      from lignes l
      join public.books b on b.id = l.proposed_book_id
      left join lateral (
        select x.*, md5(x.id || '/' || x.mapped::text || '/' || x.contributors::text || '/' || l.regle) as empreinte_base
          from public.book_external_ids e
          join ingest.book_import_baselines x on x.external_id_id = e.id
         where e.library_id = l.lib and e.value = l.cle and e.scheme like 'import:%'
           and e.book_id = l.proposed_book_id
         order by (e.scheme = 'import:' || l.source_id) desc, coalesce(x.confirmed_at, x.imported_at) desc, x.id desc
         limit 1) bl on true
  ), valeurs as (
    select e.id, e.book_id, e.baseline_id, e.empreinte, e.empreinte_base, f.champ, f.ordre::integer as ordre, e.douteux,
           nullif(e.bf->f.champ, 'null'::jsonb) as b,
           case f.champ
             when 'contributors' then e.a_contrib
             else to_jsonb(nullif(btrim(e.a_livre->>f.champ), '')) end as a,
           nullif(e.nf->f.champ, 'null'::jsonb) as n
      from etats e
      cross join unnest(ingest.fn_h21_champs_compares()) with ordinality f(champ, ordre)
  )
  select v.id, v.book_id, v.baseline_id, v.champ, v.ordre,
         ingest.fn_h21_verdict(v.baseline_id is not null and not (v.champ = any (v.douteux)),
                               v.a is not distinct from v.n,
                               v.n is not distinct from v.b,
                               v.b is not distinct from v.a),
         v.b, v.a, v.n, v.empreinte, v.empreinte_base
    from valeurs v
   order by v.id, v.ordre;
$function$;
COMMENT ON FUNCTION ingest.fn_import_trois_etats(bigint, bigint[]) IS
  'H21 lot 3 (05/10/2026) : comparaison à trois états (base, AnarBib, fichier) des lignes known_record d''un run '
  '(p_row_ids NULL : toutes) — une ligne par (ligne, champ) : verdict (inchange, identique, source_seule, local_seul, '
  'conflit, sans_base), les trois valeurs normalisées, et l''empreinte de ce que le fichier dit de la ligne. Lecture '
  'seule. Interne.';

-- Le stockage : pour les lignes du périmètre, la comparaison calculée (ligne
-- reconnue avec notice) ou effacée (toute autre). Rend le nombre de lignes
-- comparées.
CREATE OR REPLACE FUNCTION ingest.fn_h21_stocker_comparaisons(p_run_id bigint, p_row_ids bigint[] DEFAULT NULL)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_n integer;
begin
  with calc as (
    select t.staging_row_id, t.book_id, t.baseline_id, min(t.empreinte_fichier) as empreinte,
           min(t.empreinte_base) as empreinte_base,
           jsonb_build_object(
             'inchange',     count(*) filter (where t.verdict = 'inchange'),
             'identique',    count(*) filter (where t.verdict = 'identique'),
             'source_seule', count(*) filter (where t.verdict = 'source_seule'),
             'local_seul',   count(*) filter (where t.verdict = 'local_seul'),
             'conflit',      count(*) filter (where t.verdict = 'conflit'),
             'sans_base',    count(*) filter (where t.verdict = 'sans_base')) as counts,
           jsonb_agg(jsonb_build_object('champ', t.champ, 'verdict', t.verdict,
                                        'b', t.valeur_base, 'a', t.valeur_anarbib, 'n', t.valeur_fichier)
                     order by t.ordre) as champs
      from ingest.fn_import_trois_etats(p_run_id, p_row_ids) t
     group by t.staging_row_id, t.book_id, t.baseline_id
  ), perimetre as (
    select sr.id, c.staging_row_id is not null as comparee,
           jsonb_build_object('version', 'h21-lot3/2026-10-05', 'book_id', c.book_id, 'baseline_id', c.baseline_id,
                              'empreinte_fichier', c.empreinte,
                              'empreinte_base', c.empreinte_base, 'counts', c.counts, 'champs', c.champs) as cmp
      from ingest.partner_catalog_staging_rows sr
      left join calc c on c.staging_row_id = sr.id
     where sr.run_id = p_run_id
       and (p_row_ids is null or sr.id = any (p_row_ids))
  ), maj as (
    update ingest.partner_catalog_staging_rows sr
       set comparaison = case when p.comparee then p.cmp end,
           -- l'heure du calcul (pas celle de la transaction : un recalcul dans la
           -- même transaction se date)
           comparaison_at = case when p.comparee then clock_timestamp() end
      from perimetre p
     where sr.id = p.id
       and (p.comparee or sr.comparaison is not null or sr.comparaison_at is not null)
    returning p.comparee
  )
  select count(*) filter (where comparee) into v_n from maj;
  return coalesce(v_n, 0);
end;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_stocker_comparaisons(bigint, bigint[]) IS
  'H21 lot 3 (05/10/2026) : écrit la comparaison (ingest.fn_import_trois_etats) sur les lignes known_record du '
  'périmètre, l''efface sur les autres. Interne : public.fn_import_recomparer.';

-- La notice serait-elle visible à l'appelant au catalogue ? La règle de la
-- policy books_select_authenticated : administration du réseau ; ou une
-- détentrice parmi les bibliothèques visibles (fn_visible_library_ids) ; ou
-- une détentrice dont l'appelant est staff.
CREATE OR REPLACE FUNCTION ingest.fn_h21_notice_visible(p_book_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select coalesce(public.fn_caller_is_network_admin(), false)
      or exists (select 1 from public.book_holdings h
                  where h.book_id = p_book_id
                    and (h.library_id = any ((select public.fn_visible_library_ids())::uuid[])
                         or public.user_has_library_staff_role(auth.uid(), h.library_id)));
$function$;

DO $h21l3_droits$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'ingest.fn_h21_champs_compares()', 'ingest.fn_h21_verdict(boolean, boolean, boolean, boolean)',
    'ingest.fn_h21_responsabilites(jsonb)',
    'ingest.fn_h21_normaliser(jsonb)', 'ingest.fn_h21_version_de_la_regle()',
    'ingest.fn_import_trois_etats(bigint, bigint[])', 'ingest.fn_h21_stocker_comparaisons(bigint, bigint[])',
    'ingest.fn_h21_notice_visible(bigint)'] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
  END LOOP;
END
$h21l3_droits$;


-- ─────────────────────────────────────────────────────────────────────
-- 4. Le rapprochement efface les comparaisons devenues fausses (sans calculer)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l3_rapprochement$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l3_def('ingest.fn_match_partner_catalog_run(bigint, bigint[])'::regprocedure);
  v_def := pg_temp.h21l3_remplacer('fn_match_partner_catalog_run (déclarations)', v_def,
$a$  v_intra jsonb;
  rec record;
begin$a$,
$b$  v_intra jsonb;
  v_comparaisons_effacees integer;   -- H21 lot 3
  rec record;
begin$b$);
  v_def := pg_temp.h21l3_remplacer('fn_match_partner_catalog_run (effacement)', v_def,
$a$  v_refresh := ingest.fn_refresh_partner_catalog_run_counters(p_run_id);$a$,
$b$  -- H21 lot 3 (05-06/10/2026) : la comparaison à trois états n'est PAS
  -- calculée ici (les edge functions appellent ce rapprochement sous
  -- authenticator, 8 s ; le calcul se fait par pages, public.fn_import_recomparer).
  -- Seul geste : effacer, dans le périmètre, la comparaison d'une ligne qui
  -- n'est plus known_record, ou dont la notice proposée a changé.
  update ingest.partner_catalog_staging_rows sr
     set comparaison = null, comparaison_at = null
   where sr.run_id = p_run_id
     and (coalesce(array_length(p_row_ids, 1), 0) = 0 or sr.id = any(p_row_ids))
     and sr.comparaison is not null
     and (sr.match_status is distinct from 'known_record'
          or (sr.comparaison->>'book_id') is distinct from sr.proposed_book_id::text);
  get diagnostics v_comparaisons_effacees = row_count;

  v_refresh := ingest.fn_refresh_partner_catalog_run_counters(p_run_id);$b$);
  v_def := pg_temp.h21l3_remplacer('fn_match_partner_catalog_run (rendu)', v_def,
$a$    'doublons_internes', v_intra,$a$,
$b$    'doublons_internes', v_intra,
    'comparaisons_effacees', v_comparaisons_effacees,   -- H21 lot 3$b$);
  EXECUTE v_def;
END
$h21l3_rapprochement$;


-- ─────────────────────────────────────────────────────────────────────
-- 5. Les RPC : recalculer, lire le détail d'une ligne
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_import_recomparer(p_run_id bigint, p_row_ids bigint[] DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth'
AS $function$
DECLARE
  v_actor public.my_access%rowtype;
  v_run_library_id uuid;
  v_n integer;
BEGIN
  -- Les contrôles de fn_import_set_editorial (décision du 06/10) : la
  -- coordination de la bibliothèque du run, ou l'administration du réseau
  -- dont la bibliothèque active est celle du run ; le librarian lit les
  -- comparaisons, il ne les recalcule pas.
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
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

  -- H31 : le verrou du run des conversions, après les contrôles d'accès (un
  -- « Retraiter » en cours est attendu ; ses lignes effacées ne sont plus
  -- comparées).
  PERFORM 1 FROM ingest.partner_catalog_import_runs WHERE id = p_run_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  v_n := ingest.fn_h21_stocker_comparaisons(p_run_id, p_row_ids);

  RETURN jsonb_build_object(
    'run_id', p_run_id,
    'compared_rows', v_n,
    -- les comptes de chaque ligne recalculée : l'écran les pose sans recharger
    'rows', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', sr.id, 'counts', sr.comparaison->'counts') ORDER BY sr.id), '[]'::jsonb)
               FROM ingest.partner_catalog_staging_rows sr
              WHERE sr.run_id = p_run_id AND sr.comparaison IS NOT NULL
                AND (p_row_ids IS NULL OR sr.id = ANY (p_row_ids))),
    'counts', (SELECT jsonb_build_object(
                        'inchange',     coalesce(sum((sr.comparaison->'counts'->>'inchange')::int), 0),
                        'identique',    coalesce(sum((sr.comparaison->'counts'->>'identique')::int), 0),
                        'source_seule', coalesce(sum((sr.comparaison->'counts'->>'source_seule')::int), 0),
                        'local_seul',   coalesce(sum((sr.comparaison->'counts'->>'local_seul')::int), 0),
                        'conflit',      coalesce(sum((sr.comparaison->'counts'->>'conflit')::int), 0),
                        'sans_base',    coalesce(sum((sr.comparaison->'counts'->>'sans_base')::int), 0))
                 FROM ingest.partner_catalog_staging_rows sr
                WHERE sr.run_id = p_run_id AND sr.comparaison IS NOT NULL
                  AND (p_row_ids IS NULL OR sr.id = ANY (p_row_ids))));
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_import_recomparer(bigint, bigint[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_import_recomparer(bigint, bigint[]) TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_import_recomparer(bigint, bigint[]) IS
  'H21 lot 3 (05/10/2026) : recalcule et stocke la comparaison à trois états des lignes known_record du run '
  '(p_row_ids NULL : toutes ; l''écran : pages de 200). Coordination de la bibliothèque du run, ou administration '
  '(contrôles de fn_import_set_editorial). N''écrit rien au catalogue.';

-- Le détail d'UNE ligne (le panneau du lot 4) : calculé à la lecture.
CREATE OR REPLACE FUNCTION public.fn_import_row_comparison(p_run_id bigint, p_row_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth'
AS $function$
DECLARE
  v_actor public.my_access%rowtype;
  v_run_library_id uuid;
  v_ligne record;
  v_champs jsonb;
  v_book bigint;
  v_base bigint;
  v_masque boolean;
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    SELECT * INTO v_actor FROM public.my_access LIMIT 1;
    IF v_actor.library_id IS NULL
       OR NOT coalesce(v_actor.can_access_painel, false) THEN
      RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
    END IF;
  END IF;

  SELECT r.library_id INTO v_run_library_id
  FROM ingest.partner_catalog_import_runs r
  WHERE r.id = p_run_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;
  IF NOT public.fn_caller_is_network_admin() AND v_run_library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  SELECT sr.id, sr.match_status, sr.external_key, sr.proposed_book_id INTO v_ligne
    FROM ingest.partner_catalog_staging_rows sr
   WHERE sr.id = p_row_id AND sr.run_id = p_run_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Linha % introuvable', p_row_id;
  END IF;

  SELECT min(t.book_id), min(t.baseline_id),
         jsonb_agg(jsonb_build_object('champ', t.champ, 'verdict', t.verdict, 'b', t.valeur_base,
                                      'a', t.valeur_anarbib, 'n', t.valeur_fichier) ORDER BY t.ordre)
    INTO v_book, v_base, v_champs
    FROM ingest.fn_import_trois_etats(p_run_id, ARRAY[p_row_id]) t;

  -- Une notice que l'appelant ne verrait pas au catalogue (hors RLS ici) :
  -- ses valeurs AnarBib sont masquées, les verdicts restent.
  v_masque := v_book IS NOT NULL AND NOT ingest.fn_h21_notice_visible(v_book);
  IF v_masque THEN
    SELECT jsonb_agg(c || jsonb_build_object('a', NULL) ORDER BY o) INTO v_champs
      FROM jsonb_array_elements(v_champs) WITH ORDINALITY x(c, o);
  END IF;

  RETURN jsonb_build_object(
    'run_id', p_run_id,
    'row_id', p_row_id,
    'match_status', v_ligne.match_status,
    'external_key', v_ligne.external_key,
    'book_id', v_book,
    'baseline_id', v_base,
    'a_masque', coalesce(v_masque, false),
    'counts', CASE WHEN v_champs IS NULL THEN NULL ELSE (
                SELECT jsonb_build_object(
                         'inchange',     count(*) FILTER (WHERE c->>'verdict' = 'inchange'),
                         'identique',    count(*) FILTER (WHERE c->>'verdict' = 'identique'),
                         'source_seule', count(*) FILTER (WHERE c->>'verdict' = 'source_seule'),
                         'local_seul',   count(*) FILTER (WHERE c->>'verdict' = 'local_seul'),
                         'conflit',      count(*) FILTER (WHERE c->>'verdict' = 'conflit'),
                         'sans_base',    count(*) FILTER (WHERE c->>'verdict' = 'sans_base'))
                  FROM jsonb_array_elements(v_champs) c) END,
    'champs', coalesce(v_champs, '[]'::jsonb));
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_import_row_comparison(bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_import_row_comparison(bigint, bigint) TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_import_row_comparison(bigint, bigint) IS
  'H21 lot 3 (05/10/2026) : détail de la comparaison à trois états d''une ligne (champ, verdict, base, AnarBib, '
  'fichier), calculé à la lecture ; champs [] hors known_record ; valeurs AnarBib masquées (a_masque) pour une notice '
  'que l''appelant ne verrait pas au catalogue. Staff de la bibliothèque du run, ou administration.';


-- ─────────────────────────────────────────────────────────────────────
-- 6. L'écran : les comptes par verdict dans la liste des lignes
-- ─────────────────────────────────────────────────────────────────────
-- RETURNS TABLE change : DROP puis création depuis la définition vivante ;
-- colonnes existantes dans le même ordre, la nouvelle à la fin.
DO $h21l3_liste$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l3_def('public.fn_import_list_run_rows(bigint)'::regprocedure);
  v_def := pg_temp.h21l3_remplacer('fn_import_list_run_rows (colonne)', v_def,
$a$created_at timestamp with time zone, proposed_book_held boolean)$a$,
$b$created_at timestamp with time zone, proposed_book_held boolean, comparison_counts jsonb)$b$);
  v_def := pg_temp.h21l3_remplacer('fn_import_list_run_rows (valeur)', v_def,
$a$                              AND h.library_id = v_bibliotheque_importatrice) END AS proposed_book_held
  FROM ingest.partner_catalog_staging_rows sr$a$,
$b$                              AND h.library_id = v_bibliotheque_importatrice) END AS proposed_book_held,
         -- H21 lot 3 (05-06/10/2026) : les comptes par verdict de la comparaison
         -- à trois états stockée (base, AnarBib, fichier) ; NULL hors
         -- known_record, et NULL si elle est périmée (faite contre une autre
         -- notice que la notice proposée : une fusion) — l'écran recalcule.
         CASE WHEN sr.match_status = 'known_record'
                   AND (sr.comparaison->>'book_id') = sr.proposed_book_id::text
              THEN sr.comparaison->'counts' END AS comparison_counts
  FROM ingest.partner_catalog_staging_rows sr$b$);
  DROP FUNCTION public.fn_import_list_run_rows(bigint);
  EXECUTE v_def;
END
$h21l3_liste$;
REVOKE EXECUTE ON FUNCTION public.fn_import_list_run_rows(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_import_list_run_rows(bigint) TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_import_list_run_rows(bigint) IS
  'Lignes d''un run d''import pour l''écran. H21 lot 1 (05/10/2026, IMP-28 b) : proposed_book_held = la bibliothèque qui importe (destination d''un dépôt ou d''un entrepôt OAI, sinon celle du run) détient la notice proposée (book_holdings) ; NULL sans notice proposée. H21 lot 3 (05-06/10/2026) : comparison_counts = comptes par verdict de la comparaison à trois états stockée ; NULL hors known_record ou si elle est périmée (autre notice que la proposée).';


-- ─────────────────────────────────────────────────────────────────────
-- 7. Le rapport de révision : la section « mises à jour »
-- ─────────────────────────────────────────────────────────────────────
DO $h21l3_rapport$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l3_def('public.fn_batch_review_report(bigint)'::regprocedure);
  v_def := pg_temp.h21l3_remplacer('fn_batch_review_report (déclarations)', v_def,
$a$  v_hint_err text;   -- B29
begin$a$,
$b$  v_hint_err text;   -- B29
  v_updates jsonb;   -- H21 lot 3
begin$b$);
  v_def := pg_temp.h21l3_remplacer('fn_batch_review_report (calcul)', v_def,
$a$  return jsonb_build_object(
    'batch', jsonb_build_object($a$,
$b$  -- ── H21 lot 3 (05-06/10/2026) : les mises à jour que le fichier apporte ──
  -- Les lignes reconnues (known_record) liées au lot — ses exemplaires
  -- rapprochés, ou un lien ligne → brouillon —, par leur comparaison à trois
  -- états STOCKÉE (public.fn_import_recomparer ; aucun calcul ici, qui pouvait
  -- dépasser 8 s) : comptes par verdict, 40 exemples au plus (conflits
  -- d'abord, puis ce que le fichier seul change, ce qui est à revoir, ce
  -- qu'AnarBib seule a changé). Une comparaison périmée (autre notice que la
  -- proposée) ne compte pas : compared_rows < rows le dit, comme la date de
  -- la plus ancienne. Valeurs AnarBib et titre masqués pour une notice que
  -- l'appelant ne verrait pas au catalogue. Clé absente sans ligne reconnue.
  with lignes as materialized (
    select sr.id, sr.external_key, sr.proposed_book_id,
           case when sr.comparaison is not null
                     and (sr.comparaison->>'book_id') = sr.proposed_book_id::text
                then sr.comparaison end as cmp,
           sr.comparaison_at
      from ingest.partner_catalog_staging_rows sr
     where sr.match_status = 'known_record'
       and sr.id in (select x.import_staging_row_id from public.exemplar_drafts x
                      where x.batch_id = p_batch_id and x.import_staging_row_id is not null
                     union
                     select m.staging_row_id from ingest.partner_catalog_row_to_draft m
                      where m.batch_id = p_batch_id)
  ), comparees as materialized (
    select l.*, ingest.fn_h21_notice_visible(l.proposed_book_id) as visible
      from lignes l where l.cmp is not null
  ), champs as materialized (
    select c.id, c.external_key, c.proposed_book_id, c.visible, f.o as ordre,
           f.v->>'champ' as champ, f.v->>'verdict' as verdict, f.v->'b' as vb, f.v->'a' as va, f.v->'n' as vn
      from comparees c
      cross join lateral jsonb_array_elements(c.cmp->'champs') with ordinality f(v, o)
  )
  select case when (select count(*) from lignes) = 0 then null else jsonb_build_object(
           'rows', (select count(*) from lignes),
           'compared_rows', (select count(*) from comparees),
           'compared_at_min', (select min(c.comparaison_at) from comparees c),
           'rows_with_changes', (select count(distinct ch.id) from champs ch
                                  where ch.verdict in ('source_seule', 'conflit')),   -- comme l'écran
           'counts', (select jsonb_build_object(
                               'inchange',     count(*) filter (where ch.verdict = 'inchange'),
                               'identique',    count(*) filter (where ch.verdict = 'identique'),
                               'source_seule', count(*) filter (where ch.verdict = 'source_seule'),
                               'local_seul',   count(*) filter (where ch.verdict = 'local_seul'),
                               'conflit',      count(*) filter (where ch.verdict = 'conflit'),
                               'sans_base',    count(*) filter (where ch.verdict = 'sans_base'))
                        from champs ch),
           'examples', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'row_id', e.id, 'book_id', e.proposed_book_id,
                      'titulo', case when e.visible then e.titulo end,
                      'external_key', e.external_key, 'champ', e.champ, 'verdict', e.verdict,
                      'b', e.vb, 'a', case when e.visible then e.va end, 'n', e.vn,
                      'a_masque', not e.visible) order by e.rang)
               from (select ch.*, b.titulo,
                            row_number() over (order by array_position(array['conflit', 'source_seule', 'sans_base', 'local_seul'], ch.verdict),
                                                        ch.id, ch.ordre) as rang
                       from champs ch
                       left join public.books b on b.id = ch.proposed_book_id
                      where ch.verdict in ('conflit', 'source_seule', 'sans_base', 'local_seul')
                      order by rang limit 40) e), '[]'::jsonb)) end
    into v_updates;

  return jsonb_build_object(
    'batch', jsonb_build_object($b$);
  v_def := pg_temp.h21l3_remplacer('fn_batch_review_report (clé)', v_def,
$a$      'unlinked_authorities', v_unlinked_n)
  );
exception when others then$a$,
$b$      'unlinked_authorities', v_unlinked_n)
  ) || case when v_updates is null then '{}'::jsonb else jsonb_build_object('updates', v_updates) end;   -- H21 lot 3
exception when others then$b$);
  EXECUTE v_def;
END
$h21l3_rapport$;


-- ─────────────────────────────────────────────────────────────────────
-- 8. Vérification (structurelle : les migrations passent avant le seed)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l3_verif$
DECLARE
  v_e text := '';
  v_def text;
  v_f text;
  v_cles text[];
BEGIN
  -- la liste fermée = les clés de `mapped` de la correspondance, moins autor ;
  -- chacune est une colonne de books et de book_drafts
  SELECT array_agg(k ORDER BY k) INTO v_cles
    FROM jsonb_object_keys(ingest.fn_import_row_as_book(
           jsonb_populate_record(NULL::ingest.partner_catalog_staging_rows, '{}'::jsonb), '{}'::jsonb)->'mapped') k
   WHERE k <> 'autor';
  IF v_cles IS DISTINCT FROM (SELECT array_agg(c ORDER BY c) FROM unnest(ingest.fn_h21_champs_compares()) c
                               WHERE c <> 'contributors') THEN
    v_e := v_e || ' champs(' || coalesce(array_to_string(v_cles, ','), '∅') || ')';
  END IF;
  IF EXISTS (SELECT 1 FROM unnest(v_cles) k
              WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns c
                                 WHERE c.table_schema = 'public' AND c.table_name = 'books' AND c.column_name = k)
                 OR NOT EXISTS (SELECT 1 FROM information_schema.columns c
                                 WHERE c.table_schema = 'public' AND c.table_name = 'book_drafts' AND c.column_name = k)) THEN
    v_e := v_e || ' colonnes';
  END IF;
  IF 'autor' = ANY (ingest.fn_h21_champs_compares()) THEN v_e := v_e || ' autor'; END IF;
  -- IMP-30 (06/10) : les vedettes ne sont pas comparées tant que l'import ne
  -- les verse pas dans book_subjects
  IF 'subjects' = ANY (ingest.fn_h21_champs_compares())
     OR cardinality(ingest.fn_h21_champs_compares()) <> 24 THEN v_e := v_e || ' subjects'; END IF;

  -- le verdict, sur ses six cas
  IF ingest.fn_h21_verdict(true, true, true, true) <> 'inchange'
     OR ingest.fn_h21_verdict(true, true, false, false) <> 'identique'
     OR ingest.fn_h21_verdict(true, false, false, true) <> 'source_seule'
     OR ingest.fn_h21_verdict(true, false, true, false) <> 'local_seul'
     OR ingest.fn_h21_verdict(true, false, false, false) <> 'conflit'
     OR ingest.fn_h21_verdict(false, false, false, false) <> 'sans_base'
     OR ingest.fn_h21_verdict(false, true, false, false) <> 'identique' THEN v_e := v_e || ' verdict'; END IF;

  -- le stockage
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'ingest'
                    AND table_name = 'partner_catalog_staging_rows' AND column_name = 'comparaison' AND data_type = 'jsonb')
     OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'ingest'
                    AND table_name = 'partner_catalog_staging_rows' AND column_name = 'comparaison_at') THEN
    v_e := v_e || ' stockage'; END IF;

  -- le rapprochement ne calcule pas (8 s sous authenticator) : il efface
  v_def := pg_get_functiondef('ingest.fn_match_partner_catalog_run(bigint, bigint[])'::regprocedure);
  IF position('ingest.fn_h21_stocker_comparaisons(' IN v_def) > 0
     OR position('ingest.fn_import_trois_etats(' IN v_def) > 0
     OR position('''comparaisons_effacees''' IN v_def) = 0
     OR position('set comparaison = null, comparaison_at = null' IN v_def) = 0
     OR position('ingest.fn_flag_intra_run_duplicates(p_run_id)' IN v_def) = 0
     OR position('statement_timeout' IN coalesce((SELECT proconfig::text FROM pg_proc
                                                   WHERE oid = 'ingest.fn_match_partner_catalog_run(bigint, bigint[])'::regprocedure), '')) = 0
    THEN v_e := v_e || ' rapprochement'; END IF;

  -- la liste : la colonne ajoutée à la fin, les colonnes d'avant à leur place
  IF (SELECT (p.proargnames)[array_length(p.proargnames, 1)] FROM pg_proc p
       WHERE p.oid = 'public.fn_import_list_run_rows(bigint)'::regprocedure) IS DISTINCT FROM 'comparison_counts'
     OR (SELECT (p.proargnames)[array_length(p.proargnames, 1) - 1] FROM pg_proc p
          WHERE p.oid = 'public.fn_import_list_run_rows(bigint)'::regprocedure) IS DISTINCT FROM 'proposed_book_held'
     OR (SELECT array_length(p.proargnames, 1) FROM pg_proc p
          WHERE p.oid = 'public.fn_import_list_run_rows(bigint)'::regprocedure) <> 34 THEN v_e := v_e || ' liste-colonnes'; END IF;

  -- le rapport
  v_def := pg_get_functiondef('public.fn_batch_review_report(bigint)'::regprocedure);
  IF position('ingest.fn_import_trois_etats(' IN v_def) > 0
     OR position('ingest.fn_h21_notice_visible(' IN v_def) = 0
     OR position('jsonb_build_object(''updates'', v_updates)' IN v_def) = 0
     OR position('fn_caller_owns_batch(p_batch_id)' IN v_def) = 0
     OR position('''items'', v_items_import' IN v_def) = 0 THEN v_e := v_e || ' rapport'; END IF;

  -- le recalcul : les contrôles de fn_import_set_editorial ; le détail masque A hors RLS
  v_def := pg_get_functiondef('public.fn_import_recomparer(bigint, bigint[])'::regprocedure);
  IF position('Acesso restrito ao coordenador da biblioteca.' IN v_def) = 0
     OR position('FOR NO KEY UPDATE' IN v_def) < position('Run % introuvable' IN v_def) THEN v_e := v_e || ' recalcul'; END IF;
  IF position('ingest.fn_h21_notice_visible(v_book)' IN pg_get_functiondef('public.fn_import_row_comparison(bigint, bigint)'::regprocedure)) = 0
    THEN v_e := v_e || ' masque'; END IF;

  -- droits : l'écran a les siennes, les aides restent internes
  IF EXISTS (SELECT 1 FROM unnest(ARRAY[
        'public.fn_import_list_run_rows(bigint)', 'public.fn_import_recomparer(bigint, bigint[])',
        'public.fn_import_row_comparison(bigint, bigint)', 'public.fn_batch_review_report(bigint)']) f
      WHERE NOT has_function_privilege('authenticated', f, 'EXECUTE') OR has_function_privilege('anon', f, 'EXECUTE')
         OR NOT has_function_privilege('service_role', f, 'EXECUTE')
         OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                     WHERE p.oid = f::regprocedure AND a.grantee = 0)) THEN
    v_e := v_e || ' droits-ecran';
  END IF;
  FOREACH v_f IN ARRAY ARRAY[
    'ingest.fn_h21_champs_compares()', 'ingest.fn_h21_verdict(boolean, boolean, boolean, boolean)',
    'ingest.fn_h21_responsabilites(jsonb)',
    'ingest.fn_h21_normaliser(jsonb)', 'ingest.fn_h21_version_de_la_regle()',
    'ingest.fn_import_trois_etats(bigint, bigint[])', 'ingest.fn_h21_stocker_comparaisons(bigint, bigint[])',
    'ingest.fn_h21_notice_visible(bigint)', 'ingest.fn_match_partner_catalog_run(bigint, bigint[])'] LOOP
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0) THEN
      v_e := v_e || ' droits-internes(' || v_f || ')';
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_proc p
              WHERE p.oid IN ('ingest.fn_import_trois_etats(bigint, bigint[])'::regprocedure,
                              'ingest.fn_h21_stocker_comparaisons(bigint, bigint[])'::regprocedure,
                              'ingest.fn_h21_notice_visible(bigint)'::regprocedure,
                              'public.fn_import_recomparer(bigint, bigint[])'::regprocedure,
                              'public.fn_import_row_comparison(bigint, bigint)'::regprocedure,
                              'public.fn_import_list_run_rows(bigint)'::regprocedure,
                              'public.fn_batch_review_report(bigint)'::regprocedure,
                              'ingest.fn_match_partner_catalog_run(bigint, bigint[])'::regprocedure)
                AND (NOT p.prosecdef OR coalesce(p.proconfig::text, '') NOT LIKE '%search_path%')) THEN
    v_e := v_e || ' definer';
  END IF;

  IF v_e <> '' THEN
    RAISE EXCEPTION 'H21 lot 3 : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'H21 lot 3 : vérifications OK';
END
$h21l3_verif$;

NOTIFY pgrst, 'reload schema';
