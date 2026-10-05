-- =====================================================================
-- H21 lot 2 — la base : ce que le dernier import accepté a apporté
-- (REGISTRE IMP-23, IMP-26, IMP-27, IMP-28 ; cartographie H21 du 28/09,
-- §5.1, §5.2, §5.8 ligne « 2 — La base »)
--
-- Pour chaque identifiant d'origine (public.book_external_ids : une
-- bibliothèque, un schéma import:<source>, une valeur → une notice), la BASE
-- garde ce que le dernier import ACCEPTÉ a apporté pour cette notice, dans
-- l'espace des colonnes AnarBib. Le lot 3 comparera la base (B), AnarBib
-- maintenant (A) et le nouveau fichier (N) par la MÊME fonction de
-- correspondance. Ce lot ne compare rien, n'écrit rien au catalogue hors de la
-- base, et ne change rien à l'écran.
--
-- Ce que fait la migration :
--  1. Table ingest.book_import_baselines : une ligne par identifiant
--     d'origine (external_id_id UNIQUE, FK ON DELETE CASCADE : une fusion de
--     notices déplace l'identifiant en place — fn_fusion_notices —, la base
--     suit ; l'identifiant supprimé, la base part). run_id et staging_row_id
--     sans FK (un run se supprime). mapped (colonnes AnarBib), contributors
--     (position, nom, rôle, principale, nature, code d'origine : ce que H18
--     garde), subjects, raw_payload ; mapping_version, payload_hash ; origine
--     'import' ou 'reprise' ; reprise_champs_douteux (voir 5) ; imported_at
--     (quand la ligne a été lue du fichier) et confirmed_at (quand une personne
--     a accepté ces valeurs pour la notice : publication, absorption ; NULL
--     pour un rapprochement et pour une reprise).
--     Accès : le schéma ingest reste FERMÉ (paquet INGEST-RLS du 29/08, suite
--     ingest_ferme_tests) — aucun droit pour anon ni authenticated : l'API
--     n'écrit pas la base et ne la lit pas ; seules les fonctions DEFINER
--     ci-dessous l'écrivent. La règle de lecture voulue (staff de la
--     bibliothèque de l'identifiant et administration, celle de
--     book_external_ids, H20) est posée en policy SELECT : second verrou si un
--     droit de lecture venait à être accordé.
--  2. ingest.fn_import_row_as_book(ligne de staging, contexte) → jsonb :
--     LA correspondance fichier → colonnes, extraite telle quelle de
--     ingest.fn_create_book_drafts_from_import_rows (dernier CREATE : H27
--     20260928170909, l.263-415, patchée par H21L0) — fonction PURE (aucune
--     lecture de table, aucune écriture). La création des brouillons
--     l'APPELLE désormais : une seule règle pour la création, la base et,
--     au lot 3, la comparaison. Preuve d'égalité : tests/sql/
--     aller_retour_pmb_tests.sql T5 (les 64 brouillons des fixtures PMB, figés
--     avec la définition d'avant : tests/pmb/aller-retour-brouillons.json) et
--     tests/sql/h21_lot2_la_base_tests.sql (l'ancienne définition rejouée dans
--     la même transaction, sur chaque branche de la correspondance).
--  3. La base s'écrit aux moments où un import est accepté pour une notice,
--     TOUJOURS pour la bibliothèque qui a importé (IMP-28 c :
--     ingest.fn_h21_bibliotheque_importatrice, jamais la cible d'une
--     réattribution) et seulement si l'identifiant désigne bien CETTE notice
--     (une clé que fn_record_book_external_id n'a pas donnée — elle était à une
--     autre notice — ne reçoit pas de base) :
--     (a) publication d'un brouillon importé (publish_book_draft) : la base est
--         posée ou AVANCÉE (confirmée) ; les brouillons importés qu'il a
--         absorbés (merge_book_drafts, en chaîne) posent la base de leur
--         identifiant s'il n'en a pas — le brouillon publié passe d'abord ;
--     (b) absorption d'un brouillon importé par une notice existante
--         (api.merge_draft_into_book) : posée ou AVANCÉE. La personne a
--         comparé et choisi les champs à reprendre (ApercuFusion) : le fichier
--         est accepté comme cette notice, et un champ qu'elle n'a pas pris est
--         un choix local — au lot 3, « local seul », pas « source seule ».
--         Au passage, l'identifiant d'origine que cette fonction enregistre va
--         lui aussi à la bibliothèque qui a importé (IMP-28 c ; le lot 1 l'avait
--         fait pour publish_book_draft et publish_exemplar_draft, pas ici : un
--         brouillon d'un lot réattribué donnait l'identifiant à la cible) ;
--     (c) publication d'un exemplaire rapproché (publish_exemplar_draft, bloc
--         H20 / IMP-28 c) ;
--     (d) « à chaque réimport accepté » : au lot 2 aucune mise à jour n'est
--         encore acceptée (lot 4). RÈGLE DU LOT 2 : un rapprochement (une ligne
--         known_record ou possible_duplicate rapprochée, dont les exemplaires
--         sont publiés — c) n'AVANCE PAS la base d'une notice qui en a déjà
--         une : la notice n'a reçu aucun de ces champs ; il la CRÉE seulement
--         si elle manque (origine 'import', confirmed_at NULL). Le lot 4
--         décidera de ce qui avance la base à un réimport accepté.
--     La base est tirée de la ligne de staging vivante (lien row_to_draft,
--     sinon marc_json.ingest.staging_row_id) ; à défaut, de marc_json.ingest
--     du brouillon (ligne reconstituée : la ligne normalisée et
--     l'enregistrement d'origine que la promotion y a copiés). Une copie
--     (« Éditer » d'une notice importée recopie marc_json.ingest) n'est pas un
--     brouillon importé : seul le PREMIER brouillon qui porte une trace
--     d'import donnée en tient lieu.
--  3 bis. La bibliothèque qui a importé (IMP-28 c : l'identifiant appartient
--     à la bibliothèque dont le PMB l'a émis) ne manque plus en silence
--     (revue sceptique du 05/10). ingest.fn_h21_bibliotheque_importatrice
--     rendait NULL pour un run sans bibliothèque dont la source n'en a pas
--     (source 3, MLEG) : fn_record_book_external_id n'écrivait rien — ni
--     identifiant ni base —, en production depuis le lot 1 pour
--     publish_book_draft, et le lot 2 l'étendait à merge_draft_into_book. Elle
--     gagne des replis, dans l'ordre :
--       (1) comme avant : la destination d'un dépôt compagnon ou d'un entrepôt
--           OAI, sinon la bibliothèque du run, sinon celle de la source ;
--       (2) sinon la bibliothèque qui porte DÉJÀ les identifiants de cette
--           source (book_external_ids.scheme = 'import:' || source), si elle est
--           UNIQUE ;
--       (3) sinon le repli que passe l'appelant (nouveau paramètre p_repli) :
--           publish_book_draft et merge_draft_into_book passent la bibliothèque
--           du brouillon (fn_book_draft_library), publish_exemplar_draft celle
--           de l'exemplaire.
--     Signature changée : DROP + CREATE (fonction interne, schéma ingest non
--     exposé à PostgREST, droits restaurés : service_role seul). Le
--     rapprochement (publish_exemplar_draft) et sa base prennent désormais la
--     même fonction au lieu de leur expression en ligne (r.library_id, sans le
--     repli de la source). Index book_external_ids (scheme, library_id) pour (2).
--     Mesuré en production le 05/10/2026 (lecture seule) : 3 sources, 1 sans
--     bibliothèque — la source 3 (MLEG, manual_upload, 7 runs tous sans
--     bibliothèque), dont les 264 identifiants sont dans UNE bibliothèque
--     (MLEG) ; 147 brouillons importés de cette source en attente, qui
--     n'auraient reçu ni identifiant ni base à leur publication : (2) les
--     donne à MLEG. Aucune source n'a d'identifiants dans plusieurs
--     bibliothèques.
--  4. Reprise (données) : les identifiants d'origine qui n'ont pas de base en
--     reçoivent une, origine 'reprise', tirée de la ligne de staging vivante
--     du brouillon importé publié ou absorbé sur la notice (ou de l'exemplaire
--     rapproché publié), même source et même clé ; à défaut, de
--     marc_json.ingest du brouillon. Bibliothèque : celle de l'identifiant
--     (book_external_ids.library_id — les runs de la source 3 n'en ont pas,
--     piège 5 de la cartographie). Idempotente : ingest.fn_h21_reprendre_les_bases().
--     Mesuré en production le 05/10/2026 (lecture seule) : 264 identifiants
--     d'origine (263 notices), tous import:3 (MLEG) ; les 264 ont une ligne de
--     staging vivante (run 3, CSV, lue le 03/04/2026), liée par row_to_draft
--     au brouillon de création publié sur la notice, de même clé — clé jugée
--     valide par fn_h20_cle_de_la_ligne pour les 264 ; 0 n'a que son
--     brouillon ; 0 absorption (merge_log) ; 17 de ces notices n'ont pas de
--     marc_json.ingest (notices d'une autre bibliothèque) : leur base vient de
--     la ligne quand même. 0 table book_import_baselines.
--  5. Champs douteux d'une reprise (reprise_champs_douteux text[]) : la
--     correspondance a changé le 28/09 (H17/H18 20260928111814, H27
--     20260928170909). Une reprise calcule la base avec la correspondance
--     d'AUJOURD'HUI sur une ligne qu'une correspondance plus ancienne avait
--     versée dans la notice (les 264 brouillons de production datent du
--     04/04) : pour ces champs, un écart entre la base et la notice peut venir
--     de la règle et non d'une main. Le lot 4 ne les appliquera pas d'office.
--     Liste : les cinq dont la règle a changé (cdd, colecao, issn, notas,
--     tipo_material) et ceux que H17/H18 ont fait naître et qu'une notice
--     d'avant n'a jamais reçus (paginas, volume, digital_native_url,
--     titulo_periodico, artigo_*, data_edicao, numero, contributors). Une
--     colonne plutôt qu'une clé dans mapped : le lot 3 la lit sans connaître
--     la forme de mapped, et la CHECK la vide pour une base d'import.
--  6. Export : fn_export_catalog_lote lit l'enregistrement d'origine (zones
--     réémises) d'abord dans la base de (notice, bibliothèque exportée) — la
--     plus récemment acceptée qui porte des zones MARC —, puis se rabat sur
--     marc_json.ingest avec les conditions d'avant. Une notice partagée
--     réémet ainsi, pour chaque bibliothèque, SON enregistrement (pièges 13 et
--     14 de la cartographie), sans toucher books.marc_json. Preuve d'export
--     identique : aller_retour_pmb_tests.sql T3 (attendu figé inchangé) et T8
--     (export lu dans la base = export par le repli, sur les 64 notices).
--
-- BG2 : au 05/10, la sauvegarde #BG2 (flux long) ne prend que le schéma public
-- (deploy/ops/anarbib-bg2.sh : pg_dump --schema=public) ; le schéma ingest
-- n'est sauvegardé par aucun flux (cadrage BG2-13 du 30/06 : « ingest → flux
-- long », jamais appliqué). Décision de Xavier du 05/10 : ajouter ingest au flux
-- long (item séparé, qui classera aussi cette table dans
-- deploy/bg2-known-tables.txt et rendra le filet conscient des schémas). D'ici
-- là, la base se reconstitue après une restauration par
-- ingest.fn_h21_reprendre_les_bases() depuis book_drafts.marc_json.ingest
-- (public, sauvegardé).
--
-- Méthode : chaque fonction existante est modifiée SUR SA DÉFINITION VIVANTE
-- (pg_get_functiondef, retours chariot retirés), par ancres comptées ; les
-- deux blocs remplacés de la création le sont entre deux ancres, et
-- l'empreinte du bloc remplacé est contrôlée — une production qui aurait bougé
-- fait échouer la migration. Définitions lues le 05/10 sur le banc reconstruit
-- depuis le dépôt ET en production (md5 de prosrc identiques) :
--   ingest.fn_create_book_drafts_from_import_rows a390fbedcca11e5d17c7c464239e805f
--   public.publish_book_draft                     502d6b067f859be729afc14ad1bf0e25
--   public.publish_exemplar_draft                 6120cc5fc3e3e9b9bdd9693976a8fe75
--   api.merge_draft_into_book                     de9462996b3f255af7d1c00c8d546642
--   public.fn_export_catalog_lote                 6a6de2d6bf0f4bb1d48ac9f1c66687d3
-- Suite : tests/sql/h21_lot2_la_base_tests.sql.
-- =====================================================================

-- Outils de la migration, éphémères (pg_temp).
CREATE OR REPLACE FUNCTION pg_temp.h21l2_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'H21 lot 2 — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN
    RAISE EXCEPTION 'H21 lot 2 — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

-- Remplace le bloc qui va de p_debut à p_fin (inclus), chacune présente une
-- seule fois, après avoir contrôlé l'empreinte du bloc remplacé.
CREATE OR REPLACE FUNCTION pg_temp.h21l2_remplacer_entre(p_quoi text, p_def text, p_debut text, p_fin text, p_md5 text, p_new text)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_d int; v_f int; v_bloc text;
BEGIN
  IF (length(p_def) - length(replace(p_def, p_debut, ''))) / length(p_debut) <> 1
     OR (length(p_def) - length(replace(p_def, p_fin, ''))) / length(p_fin) <> 1 THEN
    RAISE EXCEPTION 'H21 lot 2 — % : ancres de début ou de fin absentes ou répétées — relire la définition réelle', p_quoi;
  END IF;
  v_d := strpos(p_def, p_debut);
  v_f := strpos(p_def, p_fin) + length(p_fin);
  IF v_f <= v_d THEN
    RAISE EXCEPTION 'H21 lot 2 — % : fin avant le début', p_quoi;
  END IF;
  v_bloc := substr(p_def, v_d, v_f - v_d);
  IF md5(v_bloc) <> p_md5 THEN
    RAISE EXCEPTION 'H21 lot 2 — % : le bloc a changé (md5 %, attendu %) — relire la définition réelle', p_quoi, md5(v_bloc), p_md5;
  END IF;
  RETURN substr(p_def, 1, v_d - 1) || p_new || substr(p_def, v_f);
END
$f$;

CREATE OR REPLACE FUNCTION pg_temp.h21l2_def(p_fn regprocedure)
RETURNS text LANGUAGE sql AS $f$
  SELECT replace(pg_get_functiondef(p_fn), E'\r', '');
$f$;


-- ─────────────────────────────────────────────────────────────────────
-- 1. La table de la base
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ingest.book_import_baselines (
  id              bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  external_id_id  bigint NOT NULL
                  CONSTRAINT book_import_baselines_identifiant_unique UNIQUE
                  REFERENCES public.book_external_ids(id) ON DELETE CASCADE,
  run_id          bigint,
  staging_row_id  bigint,
  mapped          jsonb  NOT NULL CONSTRAINT book_import_baselines_mapped_objet CHECK (jsonb_typeof(mapped) = 'object'),
  contributors    jsonb  NOT NULL DEFAULT '[]'::jsonb CONSTRAINT book_import_baselines_contributors_liste CHECK (jsonb_typeof(contributors) = 'array'),
  subjects        jsonb  NOT NULL DEFAULT '[]'::jsonb,
  raw_payload     jsonb  NOT NULL DEFAULT '{}'::jsonb,
  mapping_version text   NOT NULL,
  payload_hash    text   NOT NULL,
  origine         text   NOT NULL CONSTRAINT book_import_baselines_origine_check CHECK (origine IN ('import', 'reprise')),
  reprise_champs_douteux text[] NOT NULL DEFAULT '{}'::text[],
  imported_at     timestamptz NOT NULL DEFAULT now(),
  confirmed_at    timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT book_import_baselines_douteux_si_reprise CHECK (origine = 'reprise' OR cardinality(reprise_champs_douteux) = 0)
);
COMMENT ON TABLE ingest.book_import_baselines IS
  'H21 lot 2 (05/10/2026) : la base d''un identifiant d''origine (book_external_ids) — ce que le dernier import ACCEPTÉ '
  'a apporté pour la notice, dans l''espace des colonnes AnarBib (ingest.fn_import_row_as_book). Posée à la publication '
  'd''un brouillon importé, à l''absorption, à la publication d''un exemplaire rapproché (créée seulement si absente), '
  'reprise le 05/10 pour les identifiants existants (origine reprise). Suit l''identifiant (fusion, suppression). '
  'Accès : les fonctions du schéma (droits du propriétaire) et service_role ; aucun droit pour anon ni authenticated '
  '(schéma fermé, paquet INGEST-RLS du 29/08/2026) ; policy de lecture = staff de la bibliothèque de l''identifiant et '
  'administration (règle de book_external_ids), second verrou si un droit venait à être posé. Ne jamais ajouter FORCE ROW '
  'LEVEL SECURITY. Sauvegarde #BG2 : le schéma ingest entre dans le flux long (décision du 05/10/2026, item séparé) ; d''ici là et en tout cas, reconstituable par ingest.fn_h21_reprendre_les_bases().';
COMMENT ON COLUMN ingest.book_import_baselines.reprise_champs_douteux IS
  'Champs d''une base REPRISE dont la correspondance a changé le 28/09 (H17/H18/H27) : un écart avec la notice peut venir '
  'de la règle, pas d''une main. Le lot 4 ne les applique pas d''office.';
COMMENT ON COLUMN ingest.book_import_baselines.confirmed_at IS
  'Quand une personne a accepté ces valeurs pour la notice (publication, absorption). NULL : rapprochement (la notice n''a '
  'reçu aucun de ces champs) ou reprise.';

-- Le schéma ingest reste fermé (paquet INGEST-RLS du 29/08, suite
-- ingest_ferme_tests : ni USAGE ni droit de table pour anon/authenticated) :
-- AUCUN droit n'est accordé à l'API, qui n'écrit ni ne lit la base. La règle
-- de lecture voulue (staff de la bibliothèque de l'identifiant,
-- administration : celle de book_external_ids, H20) est posée en policy : le
-- second verrou si un droit de lecture venait à être accordé, et la règle
-- qu'une fonction de lecture (lot 3) doit appliquer.
ALTER TABLE ingest.book_import_baselines ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ingest.book_import_baselines FROM PUBLIC, anon, authenticated;
GRANT ALL ON ingest.book_import_baselines TO service_role;
-- L'identifiant est lu sous la RLS de qui lit, qui applique la même règle.
DROP POLICY IF EXISTS book_import_baselines_select_staff ON ingest.book_import_baselines;
CREATE POLICY book_import_baselines_select_staff ON ingest.book_import_baselines
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.book_external_ids e
                  WHERE e.id = book_import_baselines.external_id_id
                    AND ((SELECT public.fn_caller_is_network_admin())
                         OR e.library_id = ANY ((SELECT public.fn_caller_staff_library_ids())::uuid[]))));


-- ─────────────────────────────────────────────────────────────────────
-- 2. La correspondance fichier → colonnes, une fonction pure
-- ─────────────────────────────────────────────────────────────────────
-- Extraite TELLE QUELLE de la création (mêmes expressions, mêmes fonctions
-- d'aide, toutes IMMUTABLE). Le contexte : ce que la ligne ne porte pas et que
-- la création lit dans le run et la source (source_id, partner_name,
-- relation_status, original_filename, detected_format).
-- Rend : mapping_version, payload_hash (empreinte de ce que le fichier dit de
-- la ligne : ses colonnes, sa ligne normalisée, son enregistrement d'origine —
-- deux lignes de même empreinte donnent la même base), mapped (les colonnes
-- bibliographiques de book_drafts/books), provenance (source_record_id,
-- partner_source, source_label, provenance_note), marc_json (la trace que la
-- création pose), contributors (position, name, role, is_primary, nature,
-- role_code), subjects, raw_payload.
CREATE OR REPLACE FUNCTION ingest.fn_import_row_as_book(p_ligne ingest.partner_catalog_staging_rows, p_contexte jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE PARALLEL SAFE
 SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
declare
  rec ingest.partner_catalog_staging_rows := p_ligne;
  v_partner_name text := p_contexte->>'partner_name';
  v_relation_status text := p_contexte->>'relation_status';
  v_original_filename text := p_contexte->>'original_filename';
  v_detected_format text := p_contexte->>'detected_format';
  v_collection_hint text;
  v_local_classification_hint text;
  v_provenance_note text;
  v_mapped jsonb;
  v_contributeurs jsonb;
begin
  v_collection_hint := ingest.fn_partner_catalog_extract_collection_hint(rec.normalized_payload, rec.raw_payload);
  v_local_classification_hint := ingest.fn_partner_catalog_extract_local_classification_hint(rec.normalized_payload, rec.raw_payload);

  v_provenance_note := format(
    'Importado de catálogo parceiro "%s" (%s, run %s, linha %s, formato bruto %s, relação %s, decisão %s).',
    v_partner_name,
    coalesce(v_original_filename, 'arquivo sem nome'),
    rec.run_id,
    rec.row_no,
    coalesce(v_detected_format, 'unknown'),
    coalesce(v_relation_status, 'sem_status'),
    coalesce(rec.editorial_decision, 'pending')
  );

  if v_local_classification_hint is not null then
    v_provenance_note := v_provenance_note || format(' Sinal local da parceira preservado: %s.', v_local_classification_hint);
  end if;

  v_mapped := jsonb_build_object(
    'titulo', nullif(trim(rec.title), ''),
    'subtitulo', nullif(trim(rec.subtitle), ''),
    'autor', coalesce(nullif(trim(rec.responsibility_statement), ''), ingest.fn_format_partner_authors(rec.authors)),
    'edicao', nullif(trim(rec.edition_statement), ''),
    'local_publicacao', nullif(trim(rec.place_of_publication), ''),
    'editora', nullif(trim(rec.publisher), ''),
    'ano', nullif(trim(rec.publication_year), ''),
    'isbn', nullif(trim(rec.isbn), ''),
    -- H17 / H27 : un article n'a pas d'ISSN à lui — celui de sa revue d'abord
    -- (461 $x, 773 $x), l'export le rend en 461 $x ; un périodique, le sien.
    'issn', case when rec.normalized_payload->>'material_type' = 'artigo'
           then coalesce(nullif(btrim(rec.normalized_payload->'host'->>'issn'), ''), nullif(trim(rec.issn), ''))
           else coalesce(nullif(trim(rec.issn), ''),
                         case when rec.normalized_payload->>'material_type' = 'periodico'
                              then nullif(btrim(rec.normalized_payload->'host'->>'issn'), '') end)
      end,
    'idioma', ingest.fn_idioma_bcp47(rec.language),
    -- tipo_material : H17, le type déduit du guide MARC (article dépouillé,
    -- périodique, son…) quand il est valide ; sinon le type brut (RIS/BibTeX).
    'tipo_material', coalesce(case when rec.normalized_payload->>'material_type' = any (array['livro','periodico','tract','cartaz','audio','audiovisual','recurso_digital','dossie','tese','artigo','relatorio','zine'])
                    then rec.normalized_payload->>'material_type' end,
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
      end),
    -- H17 : la classification (676 / 082).
    'cdd', nullif(btrim(rec.normalized_payload->>'classification'), ''),
    'colecao', coalesce(nullif(btrim(rec.normalized_payload->>'series'), ''),   -- H17 : 225/410, 490
      case
        when v_collection_hint is null then null
        -- H17 (revue) : la revue d'un article ou d'un fascicule n'est pas sa collection
        when rec.normalized_payload->>'material_type' in ('artigo', 'periodico') then null
        when lower(coalesce(rec.item_type, '')) ~ '(periodic|journal|article|boletim|periodico|periódico|jour)' then null
        when lower(regexp_replace(coalesce(v_collection_hint, ''), '\s+', ' ', 'g')) = lower(regexp_replace(coalesce(rec.title, ''), '\s+', ' ', 'g')) then null
        else v_collection_hint
      end),
    'notas', nullif(concat_ws(E'\n\n',
        nullif(btrim(rec.normalized_payload->>'notes'), ''),
        case when nullif(btrim(rec.normalized_payload->>'url'), '') is not null
              and rec.normalized_payload->>'material_type' is distinct from 'recurso_digital'
             then 'Endereço eletrônico: ' || btrim(rec.normalized_payload->>'url') end,
        -- H27 : les mots-clés libres (610 / 653), à part des vedettes ; l'export
        -- les rend en 610 / 653 (_shared/marc/ecriture.ts, deplierNotes).
        case when jsonb_typeof(rec.normalized_payload->'keywords') = 'array'
              and jsonb_array_length(rec.normalized_payload->'keywords') > 0
             then 'Palavras-chave importadas: '
                  || array_to_string(array(select jsonb_array_elements_text(rec.normalized_payload->'keywords')), '; ') end,
      nullif(concat_ws(
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
      ), '')), ''),
    -- H17
    'paginas', case when (rec.normalized_payload->>'pages') ~ '^[0-9]{1,5}$' then (rec.normalized_payload->>'pages')::integer end,
    'volume', nullif(btrim(rec.normalized_payload->>'volume'), ''),
    'digital_native_url', case when rec.normalized_payload->>'material_type' = 'recurso_digital'
           then nullif(btrim(rec.normalized_payload->>'url'), '') end,
    'titulo_periodico', case when rec.normalized_payload->>'material_type' = 'periodico'
           then coalesce(nullif(btrim(rec.normalized_payload->>'key_title'), ''), nullif(trim(rec.title), '')) end,
    'artigo_source', case when rec.normalized_payload->>'material_type' = 'artigo' then nullif(btrim(rec.normalized_payload->'host'->>'title'), '') end,
    'artigo_volume', case when rec.normalized_payload->>'material_type' = 'artigo' then nullif(btrim(rec.normalized_payload->'host'->>'volume'), '') end,
    'artigo_issue', case when rec.normalized_payload->>'material_type' = 'artigo' then nullif(btrim(rec.normalized_payload->'issue'->>'number'), '') end,
    'artigo_pages', case when rec.normalized_payload->>'material_type' = 'artigo' then nullif(btrim(rec.normalized_payload->>'extent'), '') end,
    'data_edicao', case when rec.normalized_payload->>'material_type' in ('artigo', 'periodico') then nullif(btrim(rec.normalized_payload->'issue'->>'date'), '') end,
    -- H17 (revue) : le numéro d'un fascicule (notice de bulletin de PMB)
    'numero', case when rec.normalized_payload->>'material_type' = 'periodico' then nullif(btrim(rec.normalized_payload->'issue'->>'number'), '') end
  );

  -- H18 (27/09/2026) : les responsabilités, structurées quand le fichier les
  -- porte (MARC : nom, nature, rôle, code d'origine) ; sinon les noms de la
  -- ligne (CSV, RIS : des chaînes ; recherche institutionnelle, paquet de
  -- fonds : des objets {name|label|display|family+given, role}), en
  -- auteur·rice sauf rôle AnarBib dit. La principale d'abord. Jamais un
  -- non-agent (« Collectif », « Vários » : CONV-8, entrée au titre).
  select jsonb_agg(jsonb_build_object('position', x.n, 'name', x.name, 'role', x.role, 'is_primary', x.is_primary,
                                      'nature', x.nature, 'role_code', x.role_code) order by x.n)
    into v_contributeurs
    from (select row_number() over (order by c.ord)::integer as n, left(btrim(c.value->>'name'), 500) as name,
                 case when c.value->>'role' = any (array['autor','coautor','organizacao','organizador','tradutor','ilustrador','prefaciador','coordenador','editor','realizador','roteirista','ator','interprete','compositor','narrador','produtor','locutor','outro']) then c.value->>'role' else 'outro' end as role,
                 row_number() over (order by c.ord) = 1 and (c.value->'primary') is distinct from 'false'::jsonb as is_primary,
                 case when c.value->>'nature' in ('person', 'collective', 'congress') then c.value->>'nature' end as nature,
                 nullif(left(btrim(c.value->>'role_code'), 40), '') as role_code
            from jsonb_array_elements(case when jsonb_typeof(rec.normalized_payload->'contributors') = 'array'
                                           then rec.normalized_payload->'contributors' else '[]'::jsonb end)
                 with ordinality as c(value, ord)
           where jsonb_typeof(c.value) = 'object' and nullif(btrim(c.value->>'name'), '') is not null
             and not public.fn_conv_est_non_agent(c.value->>'name')) x;
  if v_contributeurs is null then
    select jsonb_agg(jsonb_build_object('position', x.n, 'name', x.name, 'role', x.role, 'is_primary', x.is_primary,
                                        'nature', null, 'role_code', null) order by x.n)
      into v_contributeurs
      from (select row_number() over (order by a.ord)::integer as n, left(nm.nom, 500) as name,
                   case when a.value->>'role' = any (array['autor','coautor','organizacao','organizador','tradutor','ilustrador','prefaciador','coordenador','editor','realizador','roteirista','ator','interprete','compositor','narrador','produtor','locutor','outro']) then a.value->>'role' else 'autor' end as role,
                   row_number() over (order by a.ord) = 1 as is_primary
              from jsonb_array_elements(case when jsonb_typeof(rec.authors) = 'array' then rec.authors else '[]'::jsonb end)
                   with ordinality as a(value, ord)
              cross join lateral (select ingest.fn_h18_nom_d_auteur(a.value) as nom) nm
             where nm.nom is not null and not public.fn_conv_est_non_agent(nm.nom)) x;
  end if;

  return jsonb_build_object(
    'mapping_version', 'h21-lot2/2026-10-05',
    'payload_hash', md5(jsonb_build_object(
        'external_key', rec.external_key, 'item_type', rec.item_type, 'title', rec.title, 'subtitle', rec.subtitle,
        'responsibility_statement', rec.responsibility_statement, 'authors', rec.authors, 'publisher', rec.publisher,
        'place_of_publication', rec.place_of_publication, 'publication_year', rec.publication_year,
        'edition_statement', rec.edition_statement, 'language', rec.language, 'isbn', rec.isbn, 'issn', rec.issn,
        'subjects', rec.subjects, 'raw_payload', rec.raw_payload, 'normalized_payload', rec.normalized_payload)::text),
    'mapped', v_mapped,
    'provenance', jsonb_build_object(
      -- H20 : l'identifiant d'origine du fichier (001), ou rien — jamais le
      -- numéro de la ligne de staging, qui passait pour un numéro de PMB.
      'source_record_id', nullif(trim(rec.external_key), ''),
      -- partner_source : code valide (FK source_partner_code). Nom précis dans provenance_note/source_label.
      'partner_source', 'other_partner',
      'source_label', coalesce(v_original_filename, v_partner_name),
      'provenance_note', v_provenance_note),
    'marc_json', coalesce(rec.normalized_payload, '{}'::jsonb)
        || jsonb_build_object(
             'ingest',
             jsonb_build_object(
               'run_id', rec.run_id,
               'source_id', p_contexte->'source_id',   -- H20
               'staging_row_id', rec.id,
               'row_no', rec.row_no,
               'source_file_id', rec.source_file_id,
               'partner_name', v_partner_name,
               'relation_status', v_relation_status,
               'original_filename', v_original_filename,
               'detected_format', v_detected_format,
               'raw_payload', coalesce(rec.raw_payload, '{}'::jsonb),
               'authors', coalesce(rec.authors, '[]'::jsonb),
               'subjects', coalesce(rec.subjects, '[]'::jsonb),
               'editorial_decision', rec.editorial_decision,
               'editorial_note', rec.editorial_note,
               'derived_collection_hint', v_collection_hint,
               'derived_local_classification_hint', v_local_classification_hint
             )
           ),
    'contributors', coalesce(v_contributeurs, '[]'::jsonb),
    'subjects', coalesce(rec.subjects, '[]'::jsonb),
    'raw_payload', coalesce(rec.raw_payload, '{}'::jsonb)
  );
end;
$function$;
REVOKE EXECUTE ON FUNCTION ingest.fn_import_row_as_book(ingest.partner_catalog_staging_rows, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_import_row_as_book(ingest.partner_catalog_staging_rows, jsonb) TO service_role;
COMMENT ON FUNCTION ingest.fn_import_row_as_book(ingest.partner_catalog_staging_rows, jsonb) IS
  'H21 lot 2 (05/10/2026) : LA correspondance fichier → colonnes AnarBib d''une ligne de staging (pure). Appelée par la '
  'création des brouillons, par la base (ingest.book_import_baselines) et, au lot 3, par la comparaison.';


-- ─────────────────────────────────────────────────────────────────────
-- 3. La création des brouillons appelle la correspondance
-- ─────────────────────────────────────────────────────────────────────
DO $h21l2_creation$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l2_def('ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure);
  v_def := pg_temp.h21l2_remplacer('fn_create_book_drafts_from_import_rows (déclarations)', v_def,
$a$  rec record;
begin$a$,
$b$  rec record;
  v_livre jsonb;               -- H21 lot 2 : la ligne vue comme notice
begin$b$);
  v_def := pg_temp.h21l2_remplacer('fn_create_book_drafts_from_import_rows (ligne entière)', v_def,
$a$    select sr.*, r.original_filename, r.detected_format, s.partner_name, s.relation_status, s.source_kind
    from ingest.partner_catalog_staging_rows sr$a$,
$b$    select sr.*, r.original_filename, r.detected_format, s.partner_name, s.relation_status, s.source_kind,
           sr as h21_ligne, r.source_id as h21_source_id   -- H21 lot 2
    from ingest.partner_catalog_staging_rows sr$b$);
  -- La correspondance (H27 l.263-415, telle que H21L0 l'a laissée) : remplacée
  -- par l'appel de ingest.fn_import_row_as_book, qui en porte les expressions.
  v_def := pg_temp.h21l2_remplacer_entre('fn_create_book_drafts_from_import_rows (correspondance)', v_def,
    'v_collection_hint := ingest.fn_partner_catalog_extract_collection_hint(rec.normalized_payload, rec.raw_payload);',
    ') returning id into v_draft_id;',
    '7694bc4fa8ef6bb72ee55c07061348ee',
$b$-- H21 lot 2 (05/10/2026) : la correspondance fichier → colonnes est UNE
    -- fonction, ingest.fn_import_row_as_book (pure), que la base de l'import et
    -- la comparaison du réimport emploient aussi : une seule règle.
    v_livre := ingest.fn_import_row_as_book(rec.h21_ligne, jsonb_build_object(
                 'source_id', rec.h21_source_id,
                 'partner_name', rec.partner_name,
                 'relation_status', rec.relation_status,
                 'original_filename', rec.original_filename,
                 'detected_format', rec.detected_format));

    insert into public.book_drafts (
      batch_id, action, status, titulo, subtitulo, autor, edicao,
      local_publicacao, editora, ano, isbn, issn, idioma, tipo_material,
      cdd, colecao, marc_json, created_by, updated_by, acquisition_mode,
      partner_source, source_record_id, import_format, import_method,
      provenance_note, mutualization_status, source_label, notas,
      -- H17 : pages, volume, adresse, périodique et article
      paginas, volume, digital_native_url, titulo_periodico,
      artigo_source, artigo_volume, artigo_issue, artigo_pages, data_edicao, numero
    ) values (
      v_batch_id,
      'create',
      'draft',
      v_livre->'mapped'->>'titulo',
      v_livre->'mapped'->>'subtitulo',
      v_livre->'mapped'->>'autor',
      v_livre->'mapped'->>'edicao',
      v_livre->'mapped'->>'local_publicacao',
      v_livre->'mapped'->>'editora',
      v_livre->'mapped'->>'ano',
      v_livre->'mapped'->>'isbn',
      v_livre->'mapped'->>'issn',
      v_livre->'mapped'->>'idioma',
      v_livre->'mapped'->>'tipo_material',
      v_livre->'mapped'->>'cdd',
      v_livre->'mapped'->>'colecao',
      v_livre->'marc_json',
      v_actor,
      v_actor,
      null,
      v_livre->'provenance'->>'partner_source',
      v_livre->'provenance'->>'source_record_id',
      null,                                          -- import_format : NULL (evite FK source_format_code)
      null,                                          -- import_method : NULL (evite FK import_method_code)
      v_livre->'provenance'->>'provenance_note',
      null,
      v_livre->'provenance'->>'source_label',
      v_livre->'mapped'->>'notas',
      (v_livre->'mapped'->>'paginas')::integer,
      v_livre->'mapped'->>'volume',
      v_livre->'mapped'->>'digital_native_url',
      v_livre->'mapped'->>'titulo_periodico',
      v_livre->'mapped'->>'artigo_source',
      v_livre->'mapped'->>'artigo_volume',
      v_livre->'mapped'->>'artigo_issue',
      v_livre->'mapped'->>'artigo_pages',
      v_livre->'mapped'->>'data_edicao',
      v_livre->'mapped'->>'numero'
    ) returning id into v_draft_id;$b$);
  v_def := pg_temp.h21l2_remplacer_entre('fn_create_book_drafts_from_import_rows (responsabilités)', v_def,
    '-- H18 (27/09/2026) : les responsabilités, structurées quand le fichier les',
    'where n.nom is not null and not public.fn_conv_est_non_agent(n.nom);
    end if;',
    '10f889c34a13f5ade12c131e327b791b',
$b$-- H18 (27/09/2026) : les responsabilités (règle dans
    -- ingest.fn_import_row_as_book depuis le H21 lot 2) : structurées quand le
    -- fichier les porte, sinon les noms de la ligne ; jamais un non-agent.
    -- Aucune autorité n'est rattachée d'office : les rapprochements se
    -- proposent en révision du lot.
    insert into public.book_draft_contributors (draft_id, position, name, role, is_primary, nature, role_code)
    select v_draft_id, (c.value->>'position')::integer, c.value->>'name', c.value->>'role',
           (c.value->>'is_primary')::boolean, c.value->>'nature', c.value->>'role_code'
      from jsonb_array_elements(v_livre->'contributors') with ordinality as c(value, ord)
     order by c.ord;$b$);
  EXECUTE v_def;
END
$h21l2_creation$;


-- ─────────────────────────────────────────────────────────────────────
-- 4. Poser la base
-- ─────────────────────────────────────────────────────────────────────
-- 3 bis (voir l'en-tête) : la bibliothèque qui a importé, avec ses replis.
-- Elle n'est appelée que par des fonctions plpgsql (résolution à l'exécution,
-- aucune dépendance enregistrée) : publish_book_draft (lot 1), et ici
-- merge_draft_into_book, publish_exemplar_draft et les fonctions de la base.
DO $h21l2_importatrice_avant$
BEGIN
  IF to_regprocedure('ingest.fn_h21_bibliotheque_importatrice(bigint, bigint)') IS NULL THEN
    RAISE EXCEPTION 'H21 lot 2 : ingest.fn_h21_bibliotheque_importatrice(bigint, bigint) absente — relire la définition réelle';
  END IF;
  -- la définition du lot 1 (20261005103427), md5 de prosrc relevé en production le 05/10
  IF md5(replace((SELECT prosrc FROM pg_proc WHERE oid = 'ingest.fn_h21_bibliotheque_importatrice(bigint, bigint)'::regprocedure), E'\r', ''))
     <> '01f429c26a2aa43eaf6764d684f1d9bd' THEN
    RAISE EXCEPTION 'H21 lot 2 : ingest.fn_h21_bibliotheque_importatrice a changé depuis le lot 1 — relire avant de la remplacer';
  END IF;
END
$h21l2_importatrice_avant$;
DROP FUNCTION ingest.fn_h21_bibliotheque_importatrice(bigint, bigint);
CREATE INDEX IF NOT EXISTS book_external_ids_schema_bibliotheque_idx ON public.book_external_ids (scheme, library_id);
CREATE FUNCTION ingest.fn_h21_bibliotheque_importatrice(p_run_id bigint, p_source_id bigint, p_repli uuid DEFAULT NULL)
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select coalesce(
    -- (1) la destination d'un dépôt compagnon ou d'un entrepôt OAI, sinon la
    --     bibliothèque du run, sinon celle de la source (run disparu compris)
    (select case when s.source_kind in ('partner_deposit', 'oai_pmh') then s.destination_library_id
                 else coalesce(r.library_id, s.library_id) end
       from (select 1) x
       left join ingest.partner_catalog_import_runs r on r.id = p_run_id
       left join ingest.partner_catalog_sources s on s.id = coalesce(r.source_id, p_source_id)
      where s.id is not null or r.id is not null),
    -- (2) la bibliothèque qui porte déjà les identifiants de cette source, si unique
    (select case when count(distinct e.library_id) = 1 then (array_agg(e.library_id))[1] end
       from public.book_external_ids e
      where e.scheme = 'import:' || coalesce((select r.source_id from ingest.partner_catalog_import_runs r where r.id = p_run_id),
                                             p_source_id)),
    -- (3) le repli de l'appelant (la bibliothèque du brouillon, de l'exemplaire)
    p_repli);
$function$;
REVOKE EXECUTE ON FUNCTION ingest.fn_h21_bibliotheque_importatrice(bigint, bigint, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_h21_bibliotheque_importatrice(bigint, bigint, uuid) TO service_role;
COMMENT ON FUNCTION ingest.fn_h21_bibliotheque_importatrice(bigint, bigint, uuid) IS
  'H21 lot 1 (IMP-28 c), replis du lot 2 (05/10/2026) : la bibliothèque qui a importé — (1) destination de la source pour '
  'un dépôt compagnon ou un entrepôt OAI, sinon bibliothèque du run, sinon de la source ; (2) sinon la bibliothèque qui porte '
  'déjà les identifiants de cette source, si elle est unique ; (3) sinon p_repli (bibliothèque du brouillon ou de '
  'l''exemplaire). Interne : identifiant d''origine et base.';

-- Le contexte d'une ligne vivante : ce que la création lit dans le run et la source.
CREATE OR REPLACE FUNCTION ingest.fn_h21_contexte_du_run(p_run_id bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select jsonb_build_object('source_id', r.source_id, 'partner_name', s.partner_name, 'relation_status', s.relation_status,
                            'original_filename', r.original_filename, 'detected_format', r.detected_format)
    from ingest.partner_catalog_import_runs r
    join ingest.partner_catalog_sources s on s.id = r.source_id
   where r.id = p_run_id;
$function$;

-- La base d'une ligne de staging vivante (NULL si elle n'existe plus).
CREATE OR REPLACE FUNCTION ingest.fn_h21_base_de_la_ligne(p_staging_row_id bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select ingest.fn_import_row_as_book(sr, coalesce(ingest.fn_h21_contexte_du_run(sr.run_id), '{}'::jsonb))
         || jsonb_build_object('run_id', sr.run_id, 'staging_row_id', sr.id, 'imported_at', sr.created_at)
    from ingest.partner_catalog_staging_rows sr
   where sr.id = p_staging_row_id;
$function$;

-- La base d'un BROUILLON IMPORTÉ : sa ligne vivante (lien row_to_draft, sinon
-- marc_json.ingest.staging_row_id du même run) ; à défaut, la ligne
-- reconstituée depuis marc_json.ingest (ligne normalisée et enregistrement
-- d'origine que la promotion y a copiés). NULL pour une COPIE : « Éditer »
-- recopie marc_json.ingest dans un brouillon de reprise ; seul le PREMIER
-- brouillon qui porte une trace d'import donnée est le brouillon importé.
CREATE OR REPLACE FUNCTION ingest.fn_h21_base_du_brouillon(p_draft_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_d public.book_drafts%rowtype;
  v_ing jsonb;
  v_lien bigint;
  v_sr bigint;
  v_n jsonb;
  v_ligne ingest.partner_catalog_staging_rows;
begin
  select * into v_d from public.book_drafts d where d.id = p_draft_id and coalesce(d.marc_json, '{}'::jsonb) ? 'ingest';
  if not found then
    return null;
  end if;
  v_ing := v_d.marc_json->'ingest';

  select m.staging_row_id into v_lien
    from ingest.partner_catalog_row_to_draft m where m.draft_id = p_draft_id order by m.id limit 1;
  if v_lien is not null and exists (select 1 from ingest.partner_catalog_staging_rows sr where sr.id = v_lien) then
    return ingest.fn_h21_base_de_la_ligne(v_lien);
  end if;

  -- sans lien : une copie n'est pas le brouillon importé
  if exists (select 1 from public.book_drafts d2
              where d2.id < p_draft_id and coalesce(d2.marc_json, '{}'::jsonb) ? 'ingest'
                and d2.marc_json->'ingest' = v_ing) then
    return null;
  end if;

  if (v_ing->>'staging_row_id') ~ '^[0-9]{1,18}$' then
    select sr.id into v_sr from ingest.partner_catalog_staging_rows sr
     where sr.id = (v_ing->>'staging_row_id')::bigint
       and sr.run_id::text is not distinct from (v_ing->>'run_id');
    if v_sr is not null then
      return ingest.fn_h21_base_de_la_ligne(v_sr);
    end if;
  end if;

  -- la ligne reconstituée
  v_n := coalesce(v_d.marc_json, '{}'::jsonb) - 'ingest' - 'anarbib_provenance' - 'anarbib_acquisition' - 'anarbib_network';
  v_ligne := jsonb_populate_record(null::ingest.partner_catalog_staging_rows, jsonb_build_object(
    'id', case when (v_ing->>'staging_row_id') ~ '^[0-9]{1,18}$' then v_ing->'staging_row_id' end,
    'run_id', case when (v_ing->>'run_id') ~ '^[0-9]{1,18}$' then v_ing->'run_id' end,
    'row_no', case when (v_ing->>'row_no') ~ '^[0-9]{1,9}$' then v_ing->'row_no' end,
    'source_file_id', case when (v_ing->>'source_file_id') ~ '^[0-9]{1,18}$' then v_ing->'source_file_id' end,
    'external_key', coalesce(v_n->'external_key', to_jsonb(v_d.source_record_id)),
    'item_type', v_n->'item_type', 'title', v_n->'title', 'subtitle', v_n->'subtitle',
    'responsibility_statement', v_n->'responsibility_statement',
    'authors', coalesce(v_ing->'authors', v_n->'authors'),
    'publisher', v_n->'publisher', 'place_of_publication', v_n->'place_of_publication',
    'publication_year', v_n->'publication_year', 'edition_statement', v_n->'edition_statement',
    'language', v_n->'language', 'isbn', v_n->'isbn', 'issn', v_n->'issn',
    'subjects', coalesce(v_ing->'subjects', v_n->'subjects'),
    'raw_payload', v_ing->'raw_payload',
    'normalized_payload', v_n,
    'editorial_decision', v_ing->'editorial_decision',
    'editorial_note', v_ing->'editorial_note'));
  return ingest.fn_import_row_as_book(v_ligne, jsonb_build_object(
           'source_id', v_ing->'source_id', 'partner_name', v_ing->'partner_name',
           'relation_status', v_ing->'relation_status', 'original_filename', v_ing->'original_filename',
           'detected_format', v_ing->'detected_format'))
         || jsonb_build_object('run_id', v_ligne.run_id, 'staging_row_id', v_ligne.id,
                               'imported_at', v_d.created_at, 'reconstituee', true);
end;
$function$;

-- Écrit la base de l'identifiant (bibliothèque, import:<source>, clé) QUAND il
-- désigne p_book_id. p_avancer : remplacer une base existante (publication,
-- absorption) ou seulement la créer si elle manque (rapprochement, reprise,
-- absorbés). Rend vrai si une base a été écrite.
CREATE OR REPLACE FUNCTION ingest.fn_h21_poser_base(p_book_id bigint, p_library_id uuid, p_source_id bigint, p_cle text,
                                                    p_base jsonb, p_origine text, p_avancer boolean, p_confirmer boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_eid bigint;
  v_n int;
begin
  if p_base is null or p_book_id is null or p_library_id is null or p_source_id is null
     or nullif(btrim(coalesce(p_cle, '')), '') is null then
    return false;
  end if;
  select e.id into v_eid from public.book_external_ids e
   where e.library_id = p_library_id and e.scheme = 'import:' || p_source_id and e.value = btrim(p_cle)
     and e.book_id = p_book_id;
  if v_eid is null then
    return false;
  end if;
  insert into ingest.book_import_baselines (external_id_id, run_id, staging_row_id, mapped, contributors, subjects,
                                            raw_payload, mapping_version, payload_hash, origine, reprise_champs_douteux,
                                            imported_at, confirmed_at)
  values (v_eid,
          case when (p_base->>'run_id') ~ '^[0-9]{1,18}$' then (p_base->>'run_id')::bigint end,
          case when (p_base->>'staging_row_id') ~ '^[0-9]{1,18}$' then (p_base->>'staging_row_id')::bigint end,
          p_base->'mapped', coalesce(p_base->'contributors', '[]'::jsonb), coalesce(p_base->'subjects', '[]'::jsonb),
          coalesce(p_base->'raw_payload', '{}'::jsonb), p_base->>'mapping_version', p_base->>'payload_hash', p_origine,
          case when p_origine = 'reprise'
               then array['cdd', 'colecao', 'issn', 'notas', 'tipo_material',
                          'paginas', 'volume', 'digital_native_url', 'titulo_periodico', 'artigo_source', 'artigo_volume',
                          'artigo_issue', 'artigo_pages', 'data_edicao', 'numero', 'contributors']
               else '{}'::text[] end,
          coalesce((p_base->>'imported_at')::timestamptz, now()),
          case when p_confirmer then now() end)
  on conflict (external_id_id) do update
     set run_id = excluded.run_id, staging_row_id = excluded.staging_row_id, mapped = excluded.mapped,
         contributors = excluded.contributors, subjects = excluded.subjects, raw_payload = excluded.raw_payload,
         mapping_version = excluded.mapping_version, payload_hash = excluded.payload_hash, origine = excluded.origine,
         reprise_champs_douteux = excluded.reprise_champs_douteux, imported_at = excluded.imported_at,
         confirmed_at = excluded.confirmed_at, updated_at = now()
   where p_avancer;
  get diagnostics v_n = row_count;
  return v_n > 0;
end;
$function$;

-- (a) et (b) : la base de l'identifiant d'un brouillon importé — mêmes
-- bibliothèque (celle qui a importé), source et clé que l'enregistrement de
-- l'identifiant dans publish_book_draft et merge_draft_into_book.
CREATE OR REPLACE FUNCTION ingest.fn_h21_poser_base_du_brouillon(p_book_id bigint, p_draft_id bigint, p_avancer boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_ing jsonb;
begin
  select d.marc_json->'ingest' into v_ing
    from public.book_drafts d where d.id = p_draft_id and coalesce(d.marc_json, '{}'::jsonb) ? 'ingest';
  if v_ing is null then
    return false;
  end if;
  return ingest.fn_h21_poser_base(
    p_book_id,
    ingest.fn_h21_bibliotheque_importatrice((v_ing->>'run_id')::bigint, (v_ing->>'source_id')::bigint,
                                            public.fn_book_draft_library(p_draft_id)),
    coalesce((v_ing->>'source_id')::bigint,
             (select r.source_id from ingest.partner_catalog_import_runs r where r.id = (v_ing->>'run_id')::bigint)),
    ingest.fn_h20_identifiant_d_origine(p_draft_id),
    ingest.fn_h21_base_du_brouillon(p_draft_id),
    'import', p_avancer, true);
end;
$function$;

-- (c) : la base de l'identifiant d'un exemplaire rapproché — mêmes
-- bibliothèque (celle qui a importé, replis compris ; p_repli : la
-- bibliothèque de l'exemplaire), source et clé que publish_exemplar_draft
-- (bloc H20/IMP-28 c). Créée seulement si elle manque, jamais confirmée
-- (règle du lot 2).
CREATE OR REPLACE FUNCTION ingest.fn_h21_poser_base_rapprochee(p_book_id bigint, p_staging_row_id bigint, p_repli uuid DEFAULT NULL)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select coalesce(ingest.fn_h21_poser_base(
           p_book_id,
           (select ingest.fn_h21_bibliotheque_importatrice(sr.run_id, NULL, p_repli)
              from ingest.partner_catalog_staging_rows sr
             where sr.id = p_staging_row_id),
           (select r.source_id from ingest.partner_catalog_staging_rows sr
              join ingest.partner_catalog_import_runs r on r.id = sr.run_id
             where sr.id = p_staging_row_id),
           ingest.fn_h20_cle_de_la_ligne(p_staging_row_id),
           ingest.fn_h21_base_de_la_ligne(p_staging_row_id),
           'import', false, false), false);
$function$;

DO $h21l2_droits$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'ingest.fn_h21_contexte_du_run(bigint)', 'ingest.fn_h21_base_de_la_ligne(bigint)',
    'ingest.fn_h21_base_du_brouillon(bigint)',
    'ingest.fn_h21_poser_base(bigint, uuid, bigint, text, jsonb, text, boolean, boolean)',
    'ingest.fn_h21_poser_base_du_brouillon(bigint, bigint, boolean)',
    'ingest.fn_h21_poser_base_rapprochee(bigint, bigint, uuid)'] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
  END LOOP;
END
$h21l2_droits$;


-- ─────────────────────────────────────────────────────────────────────
-- 5. Les moments où la base s'écrit
-- ─────────────────────────────────────────────────────────────────────
-- (a) publication d'un brouillon importé, puis ses absorbés
DO $h21l2_publier_notice$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l2_def('public.publish_book_draft(bigint)'::regprocedure);
  v_def := pg_temp.h21l2_remplacer('publish_book_draft (a, brouillon publié)', v_def,
$a$        ingest.fn_h20_identifiant_d_origine(p_draft_id));
    end if;$a$,
$b$        ingest.fn_h20_identifiant_d_origine(p_draft_id));
      -- H21 lot 2 (05/10/2026) : la base de cet identifiant — ce que l'import
      -- a apporté, accepté par la publication (posée ou avancée, confirmée).
      perform ingest.fn_h21_poser_base_du_brouillon(v_book_id, p_draft_id, true);
    end if;$b$);
  -- 3 bis : la bibliothèque qui a importé, avec le repli sur celle du brouillon
  -- (source sans bibliothèque et sans identifiants) — le publié et ses absorbés.
  v_def := pg_temp.h21l2_remplacer('publish_book_draft (3 bis, brouillon publié)', v_def,
$a$        ingest.fn_h21_bibliotheque_importatrice((v_draft.marc_json->'ingest'->>'run_id')::bigint,
                                                (v_draft.marc_json->'ingest'->>'source_id')::bigint),$a$,
$b$        ingest.fn_h21_bibliotheque_importatrice((v_draft.marc_json->'ingest'->>'run_id')::bigint,
                                                (v_draft.marc_json->'ingest'->>'source_id')::bigint,
                                                public.fn_book_draft_library(p_draft_id)),$b$);
  v_def := pg_temp.h21l2_remplacer('publish_book_draft (3 bis, brouillons absorbés)', v_def,
$a$              ingest.fn_h21_bibliotheque_importatrice((l.marc_json->'ingest'->>'run_id')::bigint,
                                                      (l.marc_json->'ingest'->>'source_id')::bigint),$a$,
$b$              ingest.fn_h21_bibliotheque_importatrice((l.marc_json->'ingest'->>'run_id')::bigint,
                                                      (l.marc_json->'ingest'->>'source_id')::bigint,
                                                      public.fn_book_draft_library(l.id)),$b$);
  v_def := pg_temp.h21l2_remplacer('publish_book_draft (a, brouillons absorbés)', v_def,
$a$        and l.status = 'cancelled' and l.marc_json ? 'ingest';
  end if;$a$,
$b$        and l.status = 'cancelled' and l.marc_json ? 'ingest';
    -- H21 lot 2 : les absorbés posent la base de LEUR identifiant s'il n'en a
    -- pas (le brouillon publié a posé la sienne avant, il l'emporte).
    perform ingest.fn_h21_poser_base_du_brouillon(v_book_id, l.id, false)
       from public.book_drafts l
      where l.id in (with recursive absorbes(id) as (
                        select ml.duplicate_id from public.merge_log ml
                         where ml.entity_type = 'book_draft' and ml.details->>'scenario' = 'draft_into_draft'
                           and ml.canonical_id = p_draft_id
                        union
                        select ml.duplicate_id from public.merge_log ml
                          join absorbes a on ml.canonical_id = a.id
                         where ml.entity_type = 'book_draft' and ml.details->>'scenario' = 'draft_into_draft')
                      select id from absorbes)
        and l.status = 'cancelled' and l.marc_json ? 'ingest';
  end if;$b$);
  EXECUTE v_def;
END
$h21l2_publier_notice$;

-- (b) absorption par une notice existante ; l'identifiant à la bibliothèque
-- qui a importé (IMP-28 c), comme publish_book_draft depuis le lot 1.
DO $h21l2_absorber$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l2_def('api.merge_draft_into_book(bigint, bigint, jsonb)'::regprocedure);
  v_def := pg_temp.h21l2_remplacer('merge_draft_into_book (IMP-28 c)', v_def,
$a$      p_book_id, public.fn_book_draft_library(p_draft_id),$a$,
$b$      -- H21 lot 2 (05/10/2026, IMP-28 c) : la bibliothèque qui a IMPORTÉ le
      -- brouillon, pas celle du brouillon (la cible d'un lot réattribué) ;
      -- celle du brouillon en dernier repli seulement (3 bis : source sans
      -- bibliothèque et sans identifiants ailleurs).
      p_book_id,
      ingest.fn_h21_bibliotheque_importatrice((v_draft.marc_json->'ingest'->>'run_id')::bigint,
                                              (v_draft.marc_json->'ingest'->>'source_id')::bigint,
                                              public.fn_book_draft_library(p_draft_id)),$b$);
  v_def := pg_temp.h21l2_remplacer('merge_draft_into_book (b, base)', v_def,
$a$      ingest.fn_h20_identifiant_d_origine(p_draft_id));
  END IF;$a$,
$b$      ingest.fn_h20_identifiant_d_origine(p_draft_id));
    -- H21 lot 2 : la base de cet identifiant (posée ou avancée, confirmée) :
    -- la personne a comparé et choisi les champs à reprendre ; ceux qu'elle
    -- n'a pas pris sont un choix local, pas un apport à venir de la source.
    PERFORM ingest.fn_h21_poser_base_du_brouillon(p_book_id, p_draft_id, true);
  END IF;$b$);
  EXECUTE v_def;
END
$h21l2_absorber$;

-- (c) publication d'un exemplaire rapproché
DO $h21l2_publier_exemplaire$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l2_def('public.publish_exemplar_draft(bigint)'::regprocedure);
  v_def := pg_temp.h21l2_remplacer('publish_exemplar_draft (c, base)', v_def,
$a$      ingest.fn_h20_cle_de_la_ligne(v_draft.import_staging_row_id));
  end if;$a$,
$b$      ingest.fn_h20_cle_de_la_ligne(v_draft.import_staging_row_id));
    -- H21 lot 2 (05/10/2026) : la base de cet identifiant, CRÉÉE seulement si
    -- elle manque (non confirmée) : un rapprochement n'apporte aucun champ à la
    -- notice, il n'avance pas une base existante (le lot 4 décidera).
    perform ingest.fn_h21_poser_base_rapprochee(
      coalesce((select h.book_id from public.exemplares e
                  join public.book_holdings h on h.id = e.holding_id
                 where e.id = v_exemplar_id),
               (select b.id from public.books b
                 where b.bib_ref = coalesce(v_resolved_bib_ref, v_draft.target_bib_ref) limit 1)),
      v_draft.import_staging_row_id, v_library_id);
  end if;$b$);
  -- 3 bis : l'identifiant du rapproché par la même fonction que la notice
  -- (l'expression en ligne du lot 1 ne prenait ni la source ni les replis).
  v_def := pg_temp.h21l2_remplacer('publish_exemplar_draft (3 bis)', v_def,
$a$      (select case when s.source_kind in ('partner_deposit', 'oai_pmh') then s.destination_library_id
                   else r.library_id end
         from ingest.partner_catalog_staging_rows sr
         join ingest.partner_catalog_import_runs r on r.id = sr.run_id
         left join ingest.partner_catalog_sources s on s.id = r.source_id
        where sr.id = v_draft.import_staging_row_id),$a$,
$b$      -- H21 lot 2 (3 bis) : par ingest.fn_h21_bibliotheque_importatrice — la
      -- source, puis la bibliothèque des identifiants de la source, puis celle
      -- de l'exemplaire en dernier repli.
      (select ingest.fn_h21_bibliotheque_importatrice(sr.run_id, NULL, v_library_id)
         from ingest.partner_catalog_staging_rows sr
        where sr.id = v_draft.import_staging_row_id),$b$);
  EXECUTE v_def;
END
$h21l2_publier_exemplaire$;


-- ─────────────────────────────────────────────────────────────────────
-- 6. L'export lit l'enregistrement d'origine dans la base
-- ─────────────────────────────────────────────────────────────────────
DO $h21l2_export$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l2_def('public.fn_export_catalog_lote(uuid, bigint, integer)'::regprocedure);
  v_def := pg_temp.h21l2_remplacer('fn_export_catalog_lote (source)', v_def,
$a$          'source', CASE
              WHEN jsonb_typeof(b.marc_json->'ingest'->'raw_payload'->'fields') = 'array'
               AND (b.marc_json->'ingest'->>'run_id') ~ '^[0-9]{1,18}$'
               -- la bibliothèque d'où vient la notice : celle que la promotion a
               -- tamponnée — la destination d'un dépôt compagnon ou d'un
               -- moissonnage, sinon celle du run (ou de sa source)
               AND EXISTS (
                     SELECT 1
                       FROM ingest.partner_catalog_sources s
                       LEFT JOIN ingest.partner_catalog_import_runs r
                              ON r.id = (b.marc_json->'ingest'->>'run_id')::bigint
                      WHERE s.id = coalesce(r.source_id,
                                            CASE WHEN (b.marc_json->'ingest'->>'source_id') ~ '^[0-9]{1,18}$'
                                                 THEN (b.marc_json->'ingest'->>'source_id')::bigint END)
                        AND CASE WHEN s.source_kind IN ('partner_deposit', 'oai_pmh') THEN s.destination_library_id
                                 ELSE coalesce(r.library_id, s.library_id) END = p_library_id)
              THEN jsonb_build_object(
                     'dialect', b.marc_json->'ingest'->'raw_payload'->>'marc_dialect',
                     'leader', b.marc_json->'ingest'->'raw_payload'->>'leader',
                     -- la zone d'exemplaire que l'import a lue (profil compris)
                     'itemTag', b.marc_json->'ingest'->'raw_payload'->>'item_tag',
                     'fields', (SELECT coalesce(jsonb_agg(f ORDER BY n), '[]'::jsonb)
                                  FROM jsonb_array_elements(b.marc_json->'ingest'->'raw_payload'->'fields') WITH ORDINALITY AS z(f, n)
                                 WHERE f->>'tag' NOT IN ('995', '996', '852')
                                   AND f->>'tag' IS DISTINCT FROM b.marc_json->'ingest'->'raw_payload'->>'item_tag'))
            END$a$,
$b$          -- H21 lot 2 (05/10/2026) : l'enregistrement d'origine vient d'abord de la
          -- base de la notice POUR CETTE bibliothèque (src, plus bas), sinon de
          -- marc_json.ingest aux conditions d'avant.
          'source', CASE
              WHEN src.raw IS NOT NULL
              THEN jsonb_build_object(
                     'dialect', src.raw->>'marc_dialect',
                     'leader', src.raw->>'leader',
                     -- la zone d'exemplaire que l'import a lue (profil compris)
                     'itemTag', src.raw->>'item_tag',
                     'fields', (SELECT coalesce(jsonb_agg(f ORDER BY n), '[]'::jsonb)
                                  FROM jsonb_array_elements(src.raw->'fields') WITH ORDINALITY AS z(f, n)
                                 WHERE f->>'tag' NOT IN ('995', '996', '852')
                                   AND f->>'tag' IS DISTINCT FROM src.raw->>'item_tag'))
            END$b$);
  v_def := pg_temp.h21l2_remplacer('fn_export_catalog_lote (base d''abord)', v_def,
$a$        FROM public.books b
       WHERE EXISTS ($a$,
$b$        FROM public.books b
        -- H21 lot 2 : l'enregistrement d'origine — la base la plus récemment
        -- acceptée d'un identifiant de CETTE bibliothèque sur la notice, qui
        -- porte des zones MARC ; sinon marc_json.ingest, réémis pour la seule
        -- bibliothèque dont l'import a créé la notice (H24, IMP-22 b).
        LEFT JOIN LATERAL (
          SELECT coalesce(
                   (SELECT bl.raw_payload
                      FROM public.book_external_ids e
                      JOIN ingest.book_import_baselines bl ON bl.external_id_id = e.id
                     WHERE e.book_id = b.id AND e.library_id = p_library_id
                       AND jsonb_typeof(bl.raw_payload->'fields') = 'array'
                     ORDER BY coalesce(bl.confirmed_at, bl.imported_at) DESC, bl.id DESC
                     LIMIT 1),
                   CASE
                     WHEN jsonb_typeof(b.marc_json->'ingest'->'raw_payload'->'fields') = 'array'
                      AND (b.marc_json->'ingest'->>'run_id') ~ '^[0-9]{1,18}$'
                      -- la bibliothèque d'où vient la notice : celle que la promotion a
                      -- tamponnée — la destination d'un dépôt compagnon ou d'un
                      -- moissonnage, sinon celle du run (ou de sa source)
                      AND EXISTS (
                            SELECT 1
                              FROM ingest.partner_catalog_sources s
                              LEFT JOIN ingest.partner_catalog_import_runs r
                                     ON r.id = (b.marc_json->'ingest'->>'run_id')::bigint
                             WHERE s.id = coalesce(r.source_id,
                                                   CASE WHEN (b.marc_json->'ingest'->>'source_id') ~ '^[0-9]{1,18}$'
                                                        THEN (b.marc_json->'ingest'->>'source_id')::bigint END)
                               AND CASE WHEN s.source_kind IN ('partner_deposit', 'oai_pmh') THEN s.destination_library_id
                                        ELSE coalesce(r.library_id, s.library_id) END = p_library_id)
                     THEN b.marc_json->'ingest'->'raw_payload'
                   END) AS raw) src ON true
       WHERE EXISTS ($b$);
  EXECUTE v_def;
END
$h21l2_export$;


-- ─────────────────────────────────────────────────────────────────────
-- 7. Reprise : une base pour chaque identifiant d'origine qui n'en a pas
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION ingest.fn_h21_reprendre_les_bases()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  e record;
  v_src bigint;
  v_sr bigint;
  v_draft bigint;
  v_sans_base int := 0;
  v_ligne int := 0;
  v_brouillon int := 0;
  v_rien int := 0;
begin
  for e in
    select x.* from public.book_external_ids x
     where x.scheme like 'import:%'
       and not exists (select 1 from ingest.book_import_baselines bl where bl.external_id_id = x.id)
     order by x.id
  loop
    v_sans_base := v_sans_base + 1;
    v_src := coalesce(e.source_id, case when e.scheme ~ '^import:[0-9]{1,18}$' then substr(e.scheme, 8)::bigint end);
    v_sr := null; v_draft := null;

    -- la ligne vivante : celle d'un brouillon importé publié ou absorbé sur
    -- la notice, ou d'un exemplaire rapproché publié sur elle ; même source,
    -- même clé ; la plus récente.
    select c.sr_id into v_sr from (
      select sr.id as sr_id
        from public.book_drafts d
        join ingest.partner_catalog_staging_rows sr
          on sr.id = coalesce((select m.staging_row_id from ingest.partner_catalog_row_to_draft m
                                where m.draft_id = d.id order by m.id limit 1),
                              case when (d.marc_json->'ingest'->>'staging_row_id') ~ '^[0-9]{1,18}$'
                                   then (d.marc_json->'ingest'->>'staging_row_id')::bigint end)
        join ingest.partner_catalog_import_runs r on r.id = sr.run_id
       where d.published_book_id = e.book_id and d.status in ('published', 'cancelled')
         and coalesce(d.marc_json, '{}'::jsonb) ? 'ingest'
         and r.source_id = v_src and btrim(sr.external_key) = e.value
      union all
      select sr.id
        from public.exemplar_drafts x
        join public.exemplares ex on ex.id = x.published_exemplar_id
        join public.book_holdings h on h.id = ex.holding_id
        join ingest.partner_catalog_staging_rows sr on sr.id = x.import_staging_row_id
        join ingest.partner_catalog_import_runs r on r.id = sr.run_id
       where x.book_draft_id is null and x.status = 'published' and h.book_id = e.book_id
         and r.source_id = v_src and btrim(sr.external_key) = e.value) c
     order by c.sr_id desc limit 1;

    if v_sr is not null then
      if ingest.fn_h21_poser_base(e.book_id, e.library_id, v_src, e.value, ingest.fn_h21_base_de_la_ligne(v_sr),
                                  'reprise', false, false) then
        v_ligne := v_ligne + 1;
      end if;
      continue;
    end if;

    -- à défaut : le brouillon importé (pas une copie), même source, même clé
    select d.id into v_draft
      from public.book_drafts d
      left join ingest.partner_catalog_import_runs r
             on r.id = case when (d.marc_json->'ingest'->>'run_id') ~ '^[0-9]{1,18}$'
                            then (d.marc_json->'ingest'->>'run_id')::bigint end
     where d.published_book_id = e.book_id and d.status in ('published', 'cancelled')
       and coalesce(d.marc_json, '{}'::jsonb) ? 'ingest'
       and coalesce(case when (d.marc_json->'ingest'->>'source_id') ~ '^[0-9]{1,18}$'
                         then (d.marc_json->'ingest'->>'source_id')::bigint end, r.source_id) = v_src
       and ingest.fn_h20_identifiant_d_origine(d.id) = e.value
       and ingest.fn_h21_base_du_brouillon(d.id) is not null
     order by d.id desc limit 1;
    if v_draft is not null
       and ingest.fn_h21_poser_base(e.book_id, e.library_id, v_src, e.value, ingest.fn_h21_base_du_brouillon(v_draft),
                                    'reprise', false, false) then
      v_brouillon := v_brouillon + 1;
    else
      v_rien := v_rien + 1;
    end if;
  end loop;
  return jsonb_build_object('identifiants_sans_base', v_sans_base, 'depuis_la_ligne', v_ligne,
                            'depuis_le_brouillon', v_brouillon, 'sans_source', v_rien);
end;
$function$;
REVOKE EXECUTE ON FUNCTION ingest.fn_h21_reprendre_les_bases() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_h21_reprendre_les_bases() TO service_role;
COMMENT ON FUNCTION ingest.fn_h21_reprendre_les_bases() IS
  'H21 lot 2 (05/10/2026) : pose une base (origine reprise) pour chaque identifiant d''origine qui n''en a pas — ligne de '
  'staging vivante, sinon marc_json.ingest du brouillon importé. Idempotente. Aussi après une restauration qui n''aurait pas '
  'le schéma ingest.';

DO $h21l2_reprise$
DECLARE v_r jsonb;
BEGIN
  v_r := ingest.fn_h21_reprendre_les_bases();
  RAISE NOTICE 'H21 lot 2 : reprise des bases %', v_r;
END
$h21l2_reprise$;


-- ─────────────────────────────────────────────────────────────────────
-- 8. Vérification (structurelle : les migrations passent avant le seed)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l2_verif$
DECLARE
  v_e text := '';
  v_def text;
  v_f text;
BEGIN
  -- la table : identifiant unique, cascade, RLS, droits
  IF to_regclass('ingest.book_import_baselines') IS NULL THEN v_e := v_e || ' table'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint c
                  WHERE c.conrelid = 'ingest.book_import_baselines'::regclass AND c.contype = 'f'
                    AND c.confrelid = 'public.book_external_ids'::regclass AND c.confdeltype = 'c') THEN v_e := v_e || ' fk-cascade'; END IF;
  IF (SELECT count(*) FROM pg_constraint c WHERE c.conrelid = 'ingest.book_import_baselines'::regclass AND c.contype = 'f') <> 1 THEN
    v_e := v_e || ' fk-seule'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint c
                  WHERE c.conrelid = 'ingest.book_import_baselines'::regclass AND c.contype = 'u'
                    AND c.conkey = ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid = 'ingest.book_import_baselines'::regclass AND attname = 'external_id_id')]) THEN
    v_e := v_e || ' unique'; END IF;
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'ingest.book_import_baselines'::regclass) THEN v_e := v_e || ' rls'; END IF;
  IF (SELECT count(*) FROM pg_policy WHERE polrelid = 'ingest.book_import_baselines'::regclass) <> 1
     OR (SELECT polcmd FROM pg_policy WHERE polrelid = 'ingest.book_import_baselines'::regclass) <> 'r' THEN v_e := v_e || ' politique'; END IF;
  IF has_table_privilege('authenticated', 'ingest.book_import_baselines', 'SELECT')
     OR has_table_privilege('authenticated', 'ingest.book_import_baselines', 'INSERT')
     OR has_table_privilege('authenticated', 'ingest.book_import_baselines', 'UPDATE')
     OR has_table_privilege('authenticated', 'ingest.book_import_baselines', 'DELETE')
     OR has_table_privilege('anon', 'ingest.book_import_baselines', 'SELECT') THEN v_e := v_e || ' droits-table'; END IF;

  -- la correspondance : pure, et ce qu'elle appelle aussi
  IF (SELECT provolatile FROM pg_proc WHERE oid = 'ingest.fn_import_row_as_book(ingest.partner_catalog_staging_rows, jsonb)'::regprocedure) <> 'i'
     OR EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid IN (
                  'ingest.fn_partner_catalog_extract_collection_hint(jsonb, jsonb)'::regprocedure,
                  'ingest.fn_partner_catalog_extract_local_classification_hint(jsonb, jsonb)'::regprocedure,
                  'ingest.fn_format_partner_authors(jsonb)'::regprocedure,
                  'ingest.fn_idioma_bcp47(text)'::regprocedure,
                  'ingest.fn_h18_nom_d_auteur(jsonb)'::regprocedure,
                  'public.fn_conv_est_non_agent(text)'::regprocedure) AND p.provolatile <> 'i') THEN v_e := v_e || ' purete'; END IF;
  v_def := pg_get_functiondef('ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure);
  IF position('ingest.fn_import_row_as_book(rec.h21_ligne' IN v_def) = 0
     OR position('fn_partner_catalog_extract_collection_hint' IN v_def) > 0
     OR position('fn_conv_est_non_agent' IN v_def) > 0
     OR position('ingest.fn_h20_effacer_faux_identifiants(p_run_id)' IN v_def) = 0
     OR position('IMP-27 (d)' IN v_def) = 0
     OR position('sr.created_exemplar_draft_id is null' IN v_def) = 0 THEN v_e := v_e || ' creation'; END IF;

  -- les moments
  v_def := pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure);
  IF position('ingest.fn_h21_poser_base_du_brouillon(v_book_id, p_draft_id, true)' IN v_def) = 0
     OR position('ingest.fn_h21_poser_base_du_brouillon(v_book_id, l.id, false)' IN v_def) = 0
     OR position('ingest.fn_h21_poser_base_du_brouillon(v_book_id, p_draft_id, true)' IN v_def)
        < position('ingest.fn_h20_identifiant_d_origine(p_draft_id)' IN v_def)
     OR position('public.fn_batch_review_couvre(x.batch_id, x.id, ''exemplar'')' IN v_def) = 0 THEN v_e := v_e || ' publier-notice'; END IF;
  v_def := pg_get_functiondef('api.merge_draft_into_book(bigint, bigint, jsonb)'::regprocedure);
  IF position('ingest.fn_h21_poser_base_du_brouillon(p_book_id, p_draft_id, true)' IN v_def) = 0
     OR position('ingest.fn_h21_bibliotheque_importatrice(' IN v_def) = 0
     OR position('public.fn_book_draft_library(p_draft_id),' IN v_def) > 0 THEN v_e := v_e || ' absorber'; END IF;
  v_def := pg_get_functiondef('public.publish_exemplar_draft(bigint)'::regprocedure);
  IF position('ingest.fn_h21_poser_base_rapprochee(' IN v_def) = 0
     OR position('ingest.fn_h21_poser_base_rapprochee(' IN v_def) < position('ingest.fn_record_book_external_id(' IN v_def)
     OR position('IMP-28 c' IN v_def) = 0
     OR position('ingest.fn_h21_bibliotheque_importatrice(sr.run_id, NULL, v_library_id)' IN v_def) = 0
     OR position('else r.library_id end' IN v_def) > 0 THEN v_e := v_e || ' publier-exemplaire'; END IF;
  -- 3 bis : une seule signature de la bibliothèque qui a importé, avec ses replis ; les appelants passent le leur
  IF to_regprocedure('ingest.fn_h21_bibliotheque_importatrice(bigint, bigint)') IS NOT NULL
     OR to_regprocedure('ingest.fn_h21_bibliotheque_importatrice(bigint, bigint, uuid)') IS NULL
     OR position('public.book_external_ids e' IN pg_get_functiondef('ingest.fn_h21_bibliotheque_importatrice(bigint, bigint, uuid)'::regprocedure)) = 0
     OR to_regclass('public.book_external_ids_schema_bibliotheque_idx') IS NULL THEN v_e := v_e || ' importatrice'; END IF;
  v_def := pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure);
  IF position('public.fn_book_draft_library(p_draft_id))' IN v_def) = 0
     OR position('public.fn_book_draft_library(l.id))' IN v_def) = 0 THEN v_e := v_e || ' replis-notice'; END IF;
  IF position('public.fn_book_draft_library(p_draft_id))' IN pg_get_functiondef('api.merge_draft_into_book(bigint, bigint, jsonb)'::regprocedure)) = 0
     OR position('public.fn_book_draft_library(p_draft_id))' IN pg_get_functiondef('ingest.fn_h21_poser_base_du_brouillon(bigint, bigint, boolean)'::regprocedure)) = 0
     OR position('ingest.fn_h21_bibliotheque_importatrice(sr.run_id, NULL, p_repli)' IN pg_get_functiondef('ingest.fn_h21_poser_base_rapprochee(bigint, bigint, uuid)'::regprocedure)) = 0
    THEN v_e := v_e || ' replis-base'; END IF;
  v_def := pg_get_functiondef('public.fn_export_catalog_lote(uuid, bigint, integer)'::regprocedure);
  IF position('ingest.book_import_baselines' IN v_def) = 0
     OR position('''source'', CASE
              WHEN src.raw IS NOT NULL' IN v_def) = 0
     OR position('IMP-14' IN v_def) = 0 THEN v_e := v_e || ' export'; END IF;

  -- droits : l'écran garde les siens, les aides internes restent fermées
  IF EXISTS (SELECT 1 FROM unnest(ARRAY[
        'public.publish_exemplar_draft(bigint)', 'public.publish_book_draft(bigint)',
        'public.fn_export_catalog_lote(uuid, bigint, integer)']) f
      WHERE NOT has_function_privilege('authenticated', f, 'EXECUTE') OR has_function_privilege('anon', f, 'EXECUTE')
         OR NOT has_function_privilege('service_role', f, 'EXECUTE')) THEN v_e := v_e || ' droits-ecran'; END IF;
  IF NOT has_function_privilege('authenticated', 'api.merge_draft_into_book(bigint, bigint, jsonb)', 'EXECUTE')
     OR has_function_privilege('anon', 'api.merge_draft_into_book(bigint, bigint, jsonb)', 'EXECUTE') THEN v_e := v_e || ' droits-absorber'; END IF;
  FOREACH v_f IN ARRAY ARRAY[
    'ingest.fn_import_row_as_book(ingest.partner_catalog_staging_rows, jsonb)',
    'ingest.fn_h21_contexte_du_run(bigint)', 'ingest.fn_h21_base_de_la_ligne(bigint)', 'ingest.fn_h21_base_du_brouillon(bigint)',
    'ingest.fn_h21_poser_base(bigint, uuid, bigint, text, jsonb, text, boolean, boolean)',
    'ingest.fn_h21_poser_base_du_brouillon(bigint, bigint, boolean)', 'ingest.fn_h21_poser_base_rapprochee(bigint, bigint, uuid)',
    'ingest.fn_h21_bibliotheque_importatrice(bigint, bigint, uuid)',
    'ingest.fn_h21_reprendre_les_bases()', 'ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'] LOOP
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0) THEN
      v_e := v_e || ' droits-internes(' || v_f || ')';
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_proc p
              WHERE p.oid IN ('ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure,
                              'public.publish_book_draft(bigint)'::regprocedure,
                              'public.publish_exemplar_draft(bigint)'::regprocedure,
                              'api.merge_draft_into_book(bigint, bigint, jsonb)'::regprocedure,
                              'public.fn_export_catalog_lote(uuid, bigint, integer)'::regprocedure,
                              'ingest.fn_h21_poser_base(bigint, uuid, bigint, text, jsonb, text, boolean, boolean)'::regprocedure,
                              'ingest.fn_h21_reprendre_les_bases()'::regprocedure)
                AND (NOT p.prosecdef OR coalesce(p.proconfig::text, '') NOT LIKE '%search_path%')) THEN
    v_e := v_e || ' definer';
  END IF;

  IF v_e <> '' THEN
    RAISE EXCEPTION 'H21 lot 2 : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'H21 lot 2 : vérifications OK';
END
$h21l2_verif$;

NOTIFY pgrst, 'reload schema';
