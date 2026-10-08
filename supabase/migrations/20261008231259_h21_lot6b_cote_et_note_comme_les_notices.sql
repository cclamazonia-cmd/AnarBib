-- =====================================================================
-- H21 lot 6b — la cote et la note d'un exemplaire, comme les notices
-- (REGISTRE IMP-23 b, IMP-26, IMP-27, IMP-29, IMP-30, IMP-31, IMP-32,
-- IMP-33 c ; fiche H21)
--
-- Décision de Xavier du 08/10/2026 (IMP-33 c) : « une cote ou une note changée
-- se traite comme une notice : base par exemplaire, trois états, ce qui n'a
-- changé que dans le fichier s'applique par un brouillon d'exemplaire soumis à
-- la révision du lot ; conflit et retouche faite dans AnarBib gardés et
-- signalés ». Tranchés par la spécification du lot (annoncés à Xavier) :
--  - deux champs seulement : la cote (exemplares.shelf_location, 995 $k) et la
--    note (exemplares.notes, 995 $u) ; localisation, statut, type, public,
--    propriétaire restent hors du lot (IMP-21 d) ;
--  - UN SEUL GESTE : « Préparer la mise à jour » (fn_import_preparer_mises_a_jour,
--    lot 4) prépare aussi, pour les lignes choisies, un brouillon d'exemplaire
--    par exemplaire « déjà là » de la bibliothèque importatrice dont un champ
--    au moins est « changé dans le fichier seulement », dans le lot ouvert du
--    run ; la partie exemplaires est INDÉPENDANTE de la partie notice (une
--    notice partagée — lot 5 — ou sans rien à appliquer n'empêche pas les
--    exemplaires : l'exemplaire n'appartient qu'à la bibliothèque qui importe,
--    IMP-23 b) ; comptes séparés notices / exemplaires ;
--  - seul source_seule s'applique ; conflit, sans_base, local_seul : montrés,
--    jamais appliqués ; un champ que la source a vidé : montré, jamais vidé
--    (comme IMP-31 b/c) ;
--  - jamais un exemplaire d'une autre bibliothèque, jamais un exemplaire
--    déplacé, réétiqueté, au code repris (lot 6a), jamais une création.
--
-- Choix faits ici (les plus prudents, signalés au rapport) :
--  (1) La base est une TABLE À PART, ingest.exemplar_import_baselines, et non
--      une extension de ingest.book_import_baselines : celle-ci est une ligne
--      par IDENTIFIANT D'ORIGINE de notice (external_id_id UNIQUE, mapped,
--      contributors, CHECK sur les champs douteux d'une reprise), qui suit
--      l'identifiant (fusion de notices, suppression) ; un exemplaire a son
--      identité et son cycle propres (il change de notice par une fusion, se
--      supprime seul). Une ligne par exemplaire (exemplar_id UNIQUE, ON DELETE
--      CASCADE : l'exemplaire supprimé, sa base part), la bibliothèque qui a
--      importé (celle de l'exemplaire à la pose : la base n'est posée que si
--      la bibliothèque importatrice EST celle de l'exemplaire), source, run et
--      ligne (run et ligne sans clé étrangère, comme book_import_baselines),
--      code et expl_id du fichier, cote et note du fichier, empreinte de
--      l'exemplaire du fichier.
--  (2) Une base dont la bibliothèque n'est plus celle de l'exemplaire (ou de
--      la bibliothèque qui importe) n'est pas utilisable : « sans base ».
--  (3) La comparaison des exemplaires est rangée À CÔTÉ du constat du lot 6a,
--      dans une colonne propre de la ligne (exemplaires_comparaison) : le
--      constat (exemplaires_constat) est celui de la promotion ou de
--      « Rapprocher » (brouillons créés, lot, rapport « écartés ») ; la
--      comparaison est un calcul en lecture seule, refait à chaque recalcul,
--      qui refait le constat (même fonction, ingest.fn_h21_constat_exemplaire)
--      sans rien créer.
--  (4) Le brouillon de mise à jour d'exemplaire porte sa trace dans une colonne
--      à part, exemplar_drafts.import_update (posée par le geste seul :
--      l'API ne la pose ni ne la change, à l'INSERT comme à l'UPDATE, ni ne
--      change l'exemplaire visé d'un tel brouillon) ; il est lié à sa ligne par
--      import_staging_row_id (déjà verrouillé pour l'API) : le lot est « né
--      d'un import » (fn_batch_is_imported), la révision est obligatoire, la
--      ligne est retenue tant que le brouillon n'est pas publié
--      (fn_h21_ligne_retenue_par_exemplaire_rapproche, fn_h31_retraitement_refuse).
--  (5) Un exemplaire qui a déjà un autre brouillon vivant (« Éditer » en cours)
--      n'est pas préparé (« brouillon_en_cours ») : deux brouillons du même
--      exemplaire se réécriraient l'un l'autre.
--  (6) À la PREMIÈRE publication, l'exemplaire ne change QUE dans ses champs
--      patchés (cote, note) : contrôlé par une empreinte avant/après de
--      l'exemplaire (hors cote, note, updated_at), de l'identité de son fonds
--      (notice, bibliothèque, référence locale, prêtabilité, note) et de sa
--      circulation (prêts, consultations, prêts entre bibliothèques) — refus
--      sinon (error.publish.item_update_side_effect). Une retouche du
--      brouillon en révision hors cote et note (tombo, étiquette, cible) est
--      donc refusée à la première publication : elle passe par « Éditer ».
--      Les comptes du fonds (exemplares_total, available_count), que le
--      déclencheur de disponibilité recalcule, ne sont pas dans l'empreinte
--      d'exécution (un compte périmé corrigé ne bloque pas) ; la suite prouve
--      qu'ils ne bougent pas.
--  (7) Le bloc H20 de publish_exemplar_draft (identifiant d'origine de la
--      notice et base rapprochée) ne s'exécute pas pour un brouillon de mise à
--      jour d'exemplaire : sa publication ne touche ni la notice ni sa base.
--  (8) api.merge_book_drafts refuse de réécrire la cible d'un brouillon de mise
--      à jour d'exemplaire (error.import.item_update_not_mergeable) — fusion
--      de brouillons de notice qui emporterait un tel brouillon ; aucune autre
--      fusion ne touche un brouillon d'exemplaire sans notice
--      (merge_draft_into_book ne prend que ceux de son brouillon,
--      book_draft_id, que l'API ne pose pas) ; une fusion de NOTICES
--      (fn_fusion_notices) qui déplace l'exemplaire fait refuser la
--      publication (notice ou fonds changés).
--  (9) La suppression définitive d'un brouillon de mise à jour d'exemplaire
--      n'écarte pas sa ligne (IMP-27 e vaut pour les notices) : la ligne reste
--      préparable.
--  Revue sceptique du 08/10 (corrigés ici) :
--  (10) La republication ne défait jamais un exemplaire changé depuis la
--      dernière publication du brouillon (« Éditer » publié entre-temps) :
--      l'empreinte de l'exemplaire tel que chaque publication le laisse est
--      gardée dans la trace (import_update.empreinte_apres) et rejugée
--      (error.publish.item_update_changed_since_publication).
--  (11) Tant qu'un brouillon de mise à jour d'import est vivant pour un
--      exemplaire, aucun autre brouillon de reprise de cet exemplaire ne naît
--      ni ne revient, par aucune voie (« Éditer », API, corbeille, journal) :
--      déclencheur exemplar_drafts_maj_import_exclusive
--      (error.catalog.item_update_pending) ; une mise à jour supplantée ne
--      revient pas (error.import.item_update_superseded, au lieu de « code
--      repris »).
--  (12) Hors de vue, le détail et la liste ne rendent ni A, ni B, ni le
--      verdict fin (il trahirait A), ni la base, ni les applicables : un état
--      « masque » et la valeur du fichier.
--  (13) La liste ne compte pas préparable un exemplaire qui a déjà un
--      brouillon vivant (mise à jour, d'un autre run aussi, ou « Éditer ») :
--      clé « empeche ».
--  (14) Coût : la préparation allongeait un jsonb à chaque exemplaire (recopie
--      entière à chaque tour : quadratique — 18 s pour 200 lignes × 25
--      exemplaires) ; les brouillons créés sont listés en une requête à la
--      fin, et le verrou d'avis est pris une fois par bibliothèque au lieu
--      d'un par exemplaire. L'empreinte « hors patch » couvre aussi les
--      réservations et le récolement.
--
-- 1. LA BASE : ingest.exemplar_import_baselines (voir (1)). RLS sans politique,
--    aucun droit pour l'API (paquet INGEST-RLS), service_role ; un index par
--    clé étrangère ; classée au flux long (deploy/bg2-known-tables.txt).
--    Posée à la PREMIÈRE publication d'un exemplaire né d'un import (branche
--    création de publish_exemplar_draft, brouillon lié à sa ligne) — les
--    valeurs du fichier de cette ligne, pour cet exemplaire (même code) ;
--    jamais remplacée là (ON CONFLICT DO NOTHING). Avancée à la première
--    publication d'un brouillon de mise à jour d'exemplaire selon la règle (d)
--    d'IMP-31 : pour chaque champ, la base passe à N si l'exemplaire publié
--    dit N, garde B sinon (conflit, sans base, local seul, effacement, champ
--    retouché dans le brouillon) ; run, ligne, code, expl_id et empreinte
--    suivent le fichier accepté. Republication : la base n'avance pas.
--    Reprise : ingest.fn_h21_reprendre_les_bases_exemplaires() (idempotente)
--    pour les exemplaires importés sans base, depuis le brouillon importé qui
--    les a créés et sa ligne vivante (origine 'reprise', non confirmée).
--    Mesuré en production le 08/10/2026 (lecture seule) : 0 exemplaire à trace
--    d'import, 0 brouillon d'exemplaire importé, 0 ligne known_record.
--
-- 2. COMPARER : ingest.fn_h21_exemplaires_trois_etats(ligne) — pour une ligne
--    known_record, chaque exemplaire du fichier est constaté
--    (fn_h21_constat_exemplaire, bibliothèque importatrice, notice proposée) ;
--    pour un « déjà là », cote et note comparées B / A / N (valeurs
--    nullif(btrim), même correspondance que la création : 995 $k → cote,
--    995 $u → note) par LE verdict des notices (ingest.fn_h21_verdict).
--    Rangée par fn_import_recomparer et fn_import_preparer_mises_a_jour
--    (ingest.fn_h21_stocker_comparaisons_exemplaires), pages de 200, aucune
--    écriture au catalogue. Lue : fn_import_list_run_rows.exemplaires_maj
--    (verdicts sans valeurs, applicables, brouillon préparé ; NULL si
--    périmée) ; fn_import_row_comparison.exemplaires (calculée à la lecture,
--    valeurs AnarBib masquées si l'appelant ne voit pas l'exemplaire —
--    administration, ou bibliothèque visible et exemplaire public, ou staff
--    de sa bibliothèque : la règle de la policy de exemplares).
--
-- 3. PRÉPARER : ingest.fn_h21_preparer_exemplaires, appelée par
--    fn_import_preparer_mises_a_jour APRÈS la partie notice (accès, page de
--    200, verrou du run : ceux du geste). Raisons d'ignorer un exemplaire :
--    signale (déplacé, réétiqueté, code repris, sans code — ou plus sur la
--    notice), pas_au_catalogue (nouveau, déjà en brouillon), rejetee (ligne
--    rejetée par choix), autre_bibliotheque, deja_preparee (brouillon de mise
--    à jour vivant), brouillon_en_cours (autre brouillon vivant), sans_base,
--    rien_a_appliquer, non_comparee (filet). Brouillon = COPIE COMPLÈTE de
--    l'exemplaire (les colonnes qu'écrit la branche update de
--    publish_exemplar_draft, trace source/run/expl_id du lot 6a comprise),
--    patchée des seuls champs source_seule à valeur ; trace import_update :
--    run, ligne, n, code, expl_id, bibliothèque, notice, fonds, exemplaire,
--    base, empreintes de l'exemplaire et de la base, champs appliqués (b, a,
--    n), montrés non appliqués (raison efface_par_la_source), N du fichier.
--    Un exemplaire en prêt ou réservé se prépare : cote et note ne touchent
--    pas la circulation (prouvé par la suite).
--
-- 4. GARDE (ingest.fn_h21_garde_mise_a_jour_exemplaire), dans
--    publish_exemplar_draft AVANT les portes de révision et le choix de
--    branche, à la publication ET à la republication ; publish_catalog_batch
--    passe par publish_exemplar_draft ; publish_book_draft ne publie que les
--    exemplaires de SON brouillon (book_draft_id, jamais posé sur un brouillon
--    de mise à jour d'exemplaire). Refus traduits :
--      error.publish.item_update_gone            plus d'exemplaire visé
--                                                (lien vidé : jamais une création) ;
--      error.publish.item_update_library_changed bibliothèque changée (de
--                                                l'exemplaire ou du brouillon) ;
--      error.publish.item_update_moved           notice changée — ou fonds, à
--                                                la première publication ;
--      error.publish.item_update_import_row_gone la ligne d'import n'est plus
--                                                celle de la trace ;
--      error.publish.item_update_baseline_changed la base a changé ;
--      error.publish.item_update_changed         l'exemplaire a changé depuis
--                                                la préparation (empreinte de A) ;
--      error.publish.item_update_side_effect     voir (6).
--    Republication : bibliothèque et notice seulement ; la base n'avance pas.
--
-- 5. ÉCRAN : rapport de révision (fn_batch_review_report) : section
--    prepared_item_updates (brouillons de mise à jour d'exemplaire du lot,
--    champs appliqués, montrés non appliqués) ; la section H19 « items » ne
--    les compte plus (leur code est celui de l'exemplaire qu'ils visent :
--    « code déjà pris » à tort).
--
-- Méthode : chaque fonction existante est modifiée SUR SA DÉFINITION VIVANTE
-- (pg_get_functiondef, retours chariot retirés) par ancres comptées ;
-- fn_import_list_run_rows seule change de type de retour (DROP + CREATE,
-- droits restaurés) ; vérification structurelle finale. md5 de prosrc lus le
-- 08/10/2026 en production (MCP, lecture seule) et sur le banc privé
-- reconstruit depuis le dépôt (identiques) :
--   public.fn_import_preparer_mises_a_jour        af53f6864626a8c7b11c7bbccd799fd2
--   public.publish_exemplar_draft                 958558d11971c1ca739a9cff44772209
--   public.fn_import_recomparer                   71c568adf728070f755593e035b75b02
--   public.fn_import_row_comparison               a36c52d7f2d4f3c8c87e2f7f3dad6544
--   public.fn_import_list_run_rows                ce0d11836b8b6f477fbc8517cf51a775
--   public.fn_batch_review_report                 c7a2b59589e767819ab3b697d11a98f4
--   public.tg_exemplar_drafts_import_links_locked fff3a374866389a757a74bacec4630a4
--   api.merge_book_drafts                         cda65ec5aff35bd7d435f02d253ddfe9
--   public.fn_restore_deleted_draft               f8d31ab563df9d60bdc0e589873ccca4   (revue sceptique)
-- Suite : tests/sql/h21_lot6b_exemplaires_maj_tests.sql.
-- =====================================================================

-- Outils de la migration, éphémères (pg_temp).
CREATE OR REPLACE FUNCTION pg_temp.h21l6b_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'H21 lot 6b — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN
    RAISE EXCEPTION 'H21 lot 6b — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

CREATE OR REPLACE FUNCTION pg_temp.h21l6b_def(p_fn regprocedure)
RETURNS text LANGUAGE sql AS $f$
  SELECT replace(pg_get_functiondef(p_fn), E'\r', '');
$f$;


-- ─────────────────────────────────────────────────────────────────────
-- 1. La base, la trace, la comparaison rangée
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ingest.exemplar_import_baselines (
  id               bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  exemplar_id      bigint NOT NULL
                   CONSTRAINT exemplar_import_baselines_exemplaire_unique UNIQUE
                   REFERENCES public.exemplares(id) ON DELETE CASCADE,
  library_id       uuid   NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  source_id        bigint REFERENCES ingest.partner_catalog_sources(id) ON DELETE SET NULL,
  run_id           bigint,   -- sans clé étrangère : un run se supprime (comme book_import_baselines)
  staging_row_id   bigint,
  source_item_code text,
  source_item_id   text,
  shelf_location   text,     -- la cote du fichier (995 $k), normalisée
  notes            text,     -- la note du fichier (995 $u), normalisée
  payload_hash     text   NOT NULL,
  origine          text   NOT NULL CONSTRAINT exemplar_import_baselines_origine_check CHECK (origine IN ('import', 'reprise')),
  imported_at      timestamptz NOT NULL DEFAULT now(),
  confirmed_at     timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS exemplar_import_baselines_library_idx ON ingest.exemplar_import_baselines (library_id);
CREATE INDEX IF NOT EXISTS exemplar_import_baselines_source_idx ON ingest.exemplar_import_baselines (source_id);
COMMENT ON TABLE ingest.exemplar_import_baselines IS
  'H21 lot 6b (08/10/2026, IMP-33 c) : la base d''un exemplaire importé — la cote et la note que le dernier fichier ACCEPTÉ '
  'a apportées (une ligne par exemplaire, pour la bibliothèque qui l''a importé et qui le détient). Posée à la première '
  'publication d''un exemplaire né d''un import, avancée à la première publication d''un brouillon de mise à jour '
  'd''exemplaire (règle d d''IMP-31), reprise par ingest.fn_h21_reprendre_les_bases_exemplaires(). '
  'Paquet INGEST-RLS (schéma fermé, 29/08/2026) : RLS sans politique, aucun droit pour anon ni authenticated — accès '
  'par les fonctions DEFINER du schéma ; service_role. Sauvegarde #BG2 : flux long (schéma ingest).';

ALTER TABLE ingest.exemplar_import_baselines ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ingest.exemplar_import_baselines FROM PUBLIC, anon, authenticated;
GRANT ALL ON ingest.exemplar_import_baselines TO service_role;

ALTER TABLE public.exemplar_drafts ADD COLUMN IF NOT EXISTS import_update jsonb;
ALTER TABLE public.exemplar_drafts DROP CONSTRAINT IF EXISTS exemplar_drafts_import_update_objet;
ALTER TABLE public.exemplar_drafts ADD CONSTRAINT exemplar_drafts_import_update_objet
  CHECK (import_update IS NULL OR jsonb_typeof(import_update) = 'object');
COMMENT ON COLUMN public.exemplar_drafts.import_update IS
  'H21 lot 6b (IMP-33 c) : trace d''un brouillon de mise à jour d''exemplaire préparé par un réimport (« Préparer la mise à jour ») — run, ligne, exemplaire, base, empreintes, champs appliqués et montrés. Posée par le geste seul ; ni posée ni changée par l''API (tg_exemplar_drafts_import_links_locked) ; lue par la garde de publication.';

ALTER TABLE ingest.partner_catalog_staging_rows ADD COLUMN IF NOT EXISTS exemplaires_comparaison jsonb;
ALTER TABLE ingest.partner_catalog_staging_rows DROP CONSTRAINT IF EXISTS partner_catalog_staging_rows_exemplaires_comparaison_objet;
ALTER TABLE ingest.partner_catalog_staging_rows ADD CONSTRAINT partner_catalog_staging_rows_exemplaires_comparaison_objet
  CHECK (exemplaires_comparaison IS NULL OR jsonb_typeof(exemplaires_comparaison) = 'object');
COMMENT ON COLUMN ingest.partner_catalog_staging_rows.exemplaires_comparaison IS
  'H21 lot 6b (IMP-33 c) : la comparaison à trois états (base, AnarBib, fichier) de la cote et de la note des exemplaires « déjà là » de cette ligne reconnue — rangée par fn_import_recomparer et fn_import_preparer_mises_a_jour (ingest.fn_h21_stocker_comparaisons_exemplaires).';


-- ─────────────────────────────────────────────────────────────────────
-- 2. Les aides : N d'un exemplaire du fichier, empreintes, visibilité
-- ─────────────────────────────────────────────────────────────────────
-- Les champs comparés d'un exemplaire, dans l'ordre de l'écran.
CREATE OR REPLACE FUNCTION ingest.fn_h21_champs_exemplaire()
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
 SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
  select array['shelf_location', 'notes']::text[];
$function$;

-- N : ce que le fichier dit d'un exemplaire, dans l'espace des colonnes
-- (la correspondance de la création : call_number → cote, note → note),
-- normalisé comme la comparaison des notices (nullif(btrim)).
CREATE OR REPLACE FUNCTION ingest.fn_h21_n_exemplaire(p_item jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
 SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
  select jsonb_build_object('shelf_location', nullif(btrim(p_item->>'call_number'), ''),
                            'notes', nullif(btrim(p_item->>'note'), ''),
                            'code', nullif(btrim(p_item->>'source_item_code'), ''),
                            'expl_id', nullif(btrim(p_item->>'source_item_id'), ''),
                            'payload_hash', md5(coalesce(p_item, '{}'::jsonb)::text));
$function$;

-- L'exemplaire du fichier d'une ligne qui porte ce code (le premier).
CREATE OR REPLACE FUNCTION ingest.fn_h21_item_de_la_ligne(p_staging_row_id bigint, p_code text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
  select i.v || jsonb_build_object('n', i.o)
    from ingest.partner_catalog_staging_rows sr
    cross join lateral jsonb_array_elements(case when jsonb_typeof(sr.normalized_payload->'items') = 'array'
                                                 then sr.normalized_payload->'items' else '[]'::jsonb end) with ordinality i(v, o)
   where sr.id = p_staging_row_id
     and nullif(btrim(coalesce(p_code, '')), '') is not null
     and btrim(i.v->>'source_item_code') = btrim(p_code)
   order by i.o
   limit 1;
$function$;

-- Empreinte de l'exemplaire (A) : la ligne entière, hors updated_at.
CREATE OR REPLACE FUNCTION ingest.fn_h21_empreinte_exemplaire(p_exemplar_id bigint)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select md5((to_jsonb(e) - 'updated_at')::text) from public.exemplares e where e.id = p_exemplar_id;
$function$;

-- Empreinte de tout ce que la publication d'une mise à jour d'exemplaire NE
-- doit PAS changer (voir l'en-tête, (6)) : l'exemplaire hors cote, note et
-- updated_at ; l'identité de son fonds ; sa circulation.
CREATE OR REPLACE FUNCTION ingest.fn_h21_empreinte_hors_patch(p_exemplar_id bigint)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select md5(jsonb_build_array(
    (select to_jsonb(e) - array['updated_at', 'shelf_location', 'notes'] from public.exemplares e where e.id = p_exemplar_id),
    (select jsonb_build_array(h.id, h.book_id, h.library_id, h.local_bib_ref, h.loanable, h.notes)
       from public.exemplares e join public.book_holdings h on h.id = e.holding_id where e.id = p_exemplar_id),
    (select coalesce(jsonb_agg(to_jsonb(i) order by i.id), '[]'::jsonb) from public.emprestimo_itens_v2 i where i.item_id = p_exemplar_id),
    (select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb) from public.consulta_linhas_v2 c where c.item_id = p_exemplar_id),
    (select coalesce(jsonb_agg(to_jsonb(l) order by l.id), '[]'::jsonb) from public.interlibrary_loan_items_v2 l where l.item_id = p_exemplar_id),
    -- (revue sceptique du 08/10) les réservations et le récolement aussi
    (select coalesce(jsonb_agg(to_jsonb(r) order by r.id), '[]'::jsonb) from public.reserva_linhas_v2 r where r.item_id = p_exemplar_id),
    (select coalesce(jsonb_agg(to_jsonb(s) order by s.id), '[]'::jsonb) from public.recolement_scans s where s.exemplar_id = p_exemplar_id))::text);
$function$;

-- Empreinte d'une base d'exemplaire (ce que la comparaison en lit).
CREATE OR REPLACE FUNCTION ingest.fn_h21_empreinte_base_exemplaire(p_baseline_id bigint)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select md5(jsonb_build_array(bl.id, bl.exemplar_id, bl.library_id, bl.shelf_location, bl.notes,
                               bl.payload_hash, bl.origine)::text)
    from ingest.exemplar_import_baselines bl where bl.id = p_baseline_id;
$function$;

-- L'appelant verrait-il cet exemplaire ? La règle de la policy de exemplares
-- (bibliothèque visible, exemplaire public ou staff de cette bibliothèque),
-- l'administration, ou le staff de la bibliothèque de l'exemplaire.
CREATE OR REPLACE FUNCTION ingest.fn_h21_exemplaire_visible(p_exemplar_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select coalesce(public.fn_caller_is_network_admin(), false)
      or exists (select 1 from public.exemplares e
                  where e.id = p_exemplar_id
                    and (public.user_has_library_staff_role(auth.uid(), e.library_id)
                         or exists (select 1 from public.book_holdings h
                                     where h.id = e.holding_id
                                       and h.library_id = any ((select public.fn_visible_library_ids())::uuid[])
                                       and (e.visibility = 'public' or public.fn_caller_is_library_staff(h.library_id)))));
$function$;


-- Le plafond d'exemplaires du fichier par appel (recalcul, préparation) :
-- 200 lignes au plus ET 5 000 exemplaires au plus (revue sceptique du 08/10 :
-- 200 lignes × 25 exemplaires = 5 000, mesurés sous 8 s ; au-delà, l'écran
-- découpe — src/lib/importItemUpdates.js, PLAFOND_EXEMPLAIRES).
CREATE OR REPLACE FUNCTION ingest.fn_h21_exemplaires_par_appel()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
 SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
  select 5000;
$function$;

CREATE OR REPLACE FUNCTION ingest.fn_h21_garde_plafond_exemplaires(p_run_id bigint, p_row_ids bigint[])
 RETURNS void
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_n bigint;
begin
  select coalesce(sum(case when jsonb_typeof(sr.normalized_payload->'items') = 'array'
                           then jsonb_array_length(sr.normalized_payload->'items') else 0 end), 0)
    into v_n
    from ingest.partner_catalog_staging_rows sr
   where sr.run_id = p_run_id
     and (p_row_ids is null or sr.id = any (p_row_ids))
     and sr.match_status = 'known_record';
  if v_n > ingest.fn_h21_exemplaires_par_appel() then
    raise exception 'No maximo % exemplares do arquivo por chamada (%).', ingest.fn_h21_exemplaires_par_appel(), v_n
      using hint = 'error.import.update_page_too_many_items';
  end if;
end;
$function$;


-- ─────────────────────────────────────────────────────────────────────
-- 3. La base : posée, reprise
-- ─────────────────────────────────────────────────────────────────────
-- Pose la base d'un exemplaire né d'un import, à sa première publication :
-- les valeurs du fichier de la ligne du brouillon, pour l'exemplaire de même
-- code ; seulement si la bibliothèque importatrice est celle de l'exemplaire ;
-- jamais remplacée (une base existante reste). p_origine 'import' (confirmée
-- par la publication) ou 'reprise'. Rend vrai si une base a été écrite.
CREATE OR REPLACE FUNCTION ingest.fn_h21_poser_base_exemplaire(p_exemplar_id bigint, p_draft_id bigint, p_origine text DEFAULT 'import')
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_d public.exemplar_drafts%rowtype;
  v_e public.exemplares%rowtype;
  v_run bigint;
  v_src bigint;
  v_lib uuid;
  v_item jsonb;
  v_n jsonb;
  v_k int;
begin
  select * into v_d from public.exemplar_drafts where id = p_draft_id;
  if not found or v_d.import_staging_row_id is null or v_d.import_update is not null then
    return false;
  end if;
  select * into v_e from public.exemplares where id = p_exemplar_id;
  if not found then
    return false;
  end if;
  select sr.run_id, r.source_id into v_run, v_src
    from ingest.partner_catalog_staging_rows sr
    join ingest.partner_catalog_import_runs r on r.id = sr.run_id
   where sr.id = v_d.import_staging_row_id;
  if v_run is null then
    return false;
  end if;
  v_lib := ingest.fn_h21_bibliotheque_importatrice(v_run, NULL, v_e.library_id);
  if v_lib is null or v_lib is distinct from v_e.library_id then
    return false;
  end if;
  v_item := ingest.fn_h21_item_de_la_ligne(v_d.import_staging_row_id, coalesce(v_d.source_item_code, v_e.source_item_code));
  if v_item is null then
    return false;
  end if;
  v_n := ingest.fn_h21_n_exemplaire(v_item);
  insert into ingest.exemplar_import_baselines (exemplar_id, library_id, source_id, run_id, staging_row_id,
                                                source_item_code, source_item_id, shelf_location, notes,
                                                payload_hash, origine, imported_at, confirmed_at)
  values (v_e.id, v_lib, v_src, v_run, v_d.import_staging_row_id,
          v_n->>'code', v_n->>'expl_id', v_n->>'shelf_location', v_n->>'notes',
          v_n->>'payload_hash', p_origine, now(), case when p_origine = 'import' then now() end)
  on conflict (exemplar_id) do nothing;
  get diagnostics v_k = row_count;
  return v_k > 0;
end;
$function$;

-- Reprise : les exemplaires nés d'un import (brouillon publié lié à une ligne
-- vivante), sans base, reçoivent celle du brouillon qui les a créés (le plus
-- ancien), origine 'reprise', non confirmée. Idempotente.
CREATE OR REPLACE FUNCTION ingest.fn_h21_reprendre_les_bases_exemplaires()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_n integer := 0;
  rec record;
begin
  for rec in
    select distinct on (x.published_exemplar_id) x.published_exemplar_id as eid, x.id as draft_id
      from public.exemplar_drafts x
     where x.published_exemplar_id is not null and x.status = 'published'
       and x.import_staging_row_id is not null and x.import_update is null
       and not exists (select 1 from ingest.exemplar_import_baselines bl where bl.exemplar_id = x.published_exemplar_id)
     order by x.published_exemplar_id, x.id
  loop
    if ingest.fn_h21_poser_base_exemplaire(rec.eid, rec.draft_id, 'reprise') then
      v_n := v_n + 1;
    end if;
  end loop;
  return v_n;
end;
$function$;


-- ─────────────────────────────────────────────────────────────────────
-- 4. Comparer à trois états (lecture seule), ranger, lire
-- ─────────────────────────────────────────────────────────────────────
-- La comparaison des exemplaires des lignes reconnues d'un run (p_row_ids NULL :
-- toutes), EN UNE PASSE (revue sceptique du 08/10 : une boucle plpgsql par
-- exemplaire coûtait 1,5 ms l'exemplaire — 200 lignes × 25 exemplaires
-- dépassaient 8 s). Une ligne par ligne de staging comparée.
CREATE OR REPLACE FUNCTION ingest.fn_h21_exemplaires_trois_etats_lot(p_run_id bigint, p_row_ids bigint[] DEFAULT NULL)
 RETURNS TABLE(staging_row_id bigint, comparaison jsonb)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  with run as materialized (
    select r.id, r.source_id, ingest.fn_h21_bibliotheque_importatrice(r.id, NULL, NULL) as lib
      from ingest.partner_catalog_import_runs r
     where r.id = p_run_id
  ), lignes as materialized (
    select sr.id, sr.proposed_book_id, run.lib, run.source_id,
           case when jsonb_typeof(sr.normalized_payload->'items') = 'array'
                then sr.normalized_payload->'items' else '[]'::jsonb end as items
      from ingest.partner_catalog_staging_rows sr
      cross join run
     where sr.run_id = p_run_id
       and (p_row_ids is null or sr.id = any (p_row_ids))
       and sr.match_status = 'known_record'
       and sr.proposed_book_id is not null
  ), items as materialized (
    -- le constat du lot 6a, la règle unique (lecture seule)
    select l.id, l.lib, l.source_id, l.proposed_book_id, i.v, i.o::integer as o,
           ingest.fn_h21_constat_exemplaire(l.lib, l.source_id, l.proposed_book_id,
                                            i.v->>'source_item_code', i.v->>'source_item_id') as c
      from lignes l
      cross join lateral jsonb_array_elements(l.items) with ordinality i(v, o)
  ), deja as materialized (
    -- les « déjà là » : l'exemplaire (A), sa base (B) — celle de l'exemplaire,
    -- pour la bibliothèque qui importe, qui le détient toujours —, le fichier (N)
    select it.id, it.o, it.c, to_jsonb(e) as ej, bl.id as bl_id, to_jsonb(bl) as blj,
           md5(jsonb_build_array(bl.id, bl.exemplar_id, bl.library_id, bl.shelf_location, bl.notes,
                                 bl.payload_hash, bl.origine)::text) as empreinte_base,
           ingest.fn_h21_n_exemplaire(it.v) as nj
      from items it
      join public.exemplares e on e.id = (it.c->>'exemplar_id')::bigint
      left join ingest.exemplar_import_baselines bl
             on bl.exemplar_id = e.id
         and bl.library_id = it.lib and e.library_id = it.lib
     where it.c->>'verdict' = 'deja_la'
  ), champs as materialized (
    select d.id, d.o, f.champ, f.k, f.b, f.a, f.n,
           ingest.fn_h21_verdict(d.bl_id is not null, f.a is not distinct from f.n,
                                 f.n is not distinct from f.b, f.b is not distinct from f.a) as verdict
      from deja d
      cross join lateral (
        select c.champ, c.k::integer as k,
               case when d.bl_id is not null then nullif(btrim(d.blj->>c.champ), '') end as b,
               nullif(btrim(d.ej->>c.champ), '') as a,
               nullif(btrim(d.nj->>c.champ), '') as n
          from unnest(ingest.fn_h21_champs_exemplaire()) with ordinality c(champ, k)) f
  ), par_item as (
    select ch.id, ch.o,
           jsonb_agg(jsonb_build_object('champ', ch.champ, 'verdict', ch.verdict, 'b', ch.b, 'a', ch.a, 'n', ch.n)
                     order by ch.k) as champs,
           (count(*) filter (where ch.verdict = 'source_seule' and ch.n is not null))::integer as app
      from champs ch
     group by ch.id, ch.o
  ), items_json as (
    select it.id, it.o, d.id is not null as est_la, coalesce(p.app, 0) as app,
           jsonb_build_object('n', it.o,
             'code', nullif(btrim(it.v->>'source_item_code'), ''),
             'expl_id', nullif(btrim(it.v->>'source_item_id'), ''),
             'constat', it.c->>'verdict')
           || case
                when d.id is not null then jsonb_build_object(
                  'exemplar_id', (it.c->>'exemplar_id')::bigint, 'tombo', it.c->>'tombo',
                  'holding_id', (d.ej->>'holding_id')::bigint,
                  'baseline_id', d.bl_id,
                  -- les empreintes, sur les lignes déjà lues : MÊMES expressions que
                  -- ingest.fn_h21_empreinte_exemplaire et fn_h21_empreinte_base_exemplaire
                  -- (la suite le vérifie : trace = fonctions) — deux lectures de moins
                  -- par exemplaire
                  'empreinte_exemplaire', md5((d.ej - 'updated_at')::text),
                  'empreinte_base', case when d.bl_id is not null then d.empreinte_base end,
                  'n_item', d.nj,
                  'champs', p.champs,
                  'applicables', coalesce(p.app, 0))
                when it.c ? 'exemplar_id' then jsonb_build_object(
                  'exemplar_id', (it.c->>'exemplar_id')::bigint, 'tombo', it.c->>'tombo')
                else '{}'::jsonb
              end as j
      from items it
      left join deja d on d.id = it.id and d.o = it.o
      left join par_item p on p.id = it.id and p.o = it.o
  ), par_ligne as (
    select ij.id, jsonb_agg(ij.j order by ij.o) as items,
           (count(*) filter (where ij.est_la))::integer as deja_la,
           coalesce(sum(ij.app), 0)::integer as app
      from items_json ij
     group by ij.id
  ), comptes as (
    select ch.id, jsonb_build_object(
             'inchange',     count(*) filter (where ch.verdict = 'inchange'),
             'identique',    count(*) filter (where ch.verdict = 'identique'),
             'source_seule', count(*) filter (where ch.verdict = 'source_seule'),
             'local_seul',   count(*) filter (where ch.verdict = 'local_seul'),
             'conflit',      count(*) filter (where ch.verdict = 'conflit'),
             'sans_base',    count(*) filter (where ch.verdict = 'sans_base')) as counts
      from champs ch
     group by ch.id
  )
  select l.id, jsonb_build_object(
           'version', 'h21-lot6b/2026-10-08',
           'at', clock_timestamp(),
           'run_id', p_run_id,
           'library_id', l.lib,
           'source_id', l.source_id,
           'book_id', l.proposed_book_id,
           'deja_la', coalesce(pl.deja_la, 0),
           'applicables', coalesce(pl.app, 0),
           'counts', coalesce(c.counts, jsonb_build_object('inchange', 0, 'identique', 0, 'source_seule', 0,
                                                           'local_seul', 0, 'conflit', 0, 'sans_base', 0)),
           'items', coalesce(pl.items, '[]'::jsonb))
    from lignes l
    left join par_ligne pl on pl.id = l.id
    left join comptes c on c.id = l.id;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_exemplaires_trois_etats_lot(bigint, bigint[]) IS
  'H21 lot 6b (08/10/2026, IMP-33 c) : la comparaison à trois états (base, AnarBib, fichier) de la cote et de la note des exemplaires « déjà là » des lignes reconnues d''un run — constat du lot 6a refait sans rien créer, verdicts d''IMP-30 — en une passe ensembliste. Lecture seule. Interne.';

-- La même, pour UNE ligne (le détail) : NULL hors ligne reconnue.
CREATE OR REPLACE FUNCTION ingest.fn_h21_exemplaires_trois_etats(p_row_id bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select t.comparaison
    from ingest.partner_catalog_staging_rows sr
    cross join lateral ingest.fn_h21_exemplaires_trois_etats_lot(sr.run_id, array[sr.id]) t
   where sr.id = p_row_id;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_exemplaires_trois_etats(bigint) IS
  'H21 lot 6b (08/10/2026, IMP-33 c) : la comparaison à trois états des exemplaires « déjà là » d''une ligne reconnue (ingest.fn_h21_exemplaires_trois_etats_lot). Lecture seule. Interne.';

-- Ranger : pour les lignes du périmètre, la comparaison (ligne reconnue) ou
-- rien (toute autre). Rend le nombre de lignes comparées.
CREATE OR REPLACE FUNCTION ingest.fn_h21_stocker_comparaisons_exemplaires(p_run_id bigint, p_row_ids bigint[] DEFAULT NULL)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_n integer;
begin
  with calc as materialized (
    select t.staging_row_id, t.comparaison from ingest.fn_h21_exemplaires_trois_etats_lot(p_run_id, p_row_ids) t
  ), perimetre as (
    select sr.id, c.comparaison
      from ingest.partner_catalog_staging_rows sr
      left join calc c on c.staging_row_id = sr.id
     where sr.run_id = p_run_id
       and (p_row_ids is null or sr.id = any (p_row_ids))
       and (c.comparaison is not null or sr.exemplaires_comparaison is not null)
  ), maj as (
    update ingest.partner_catalog_staging_rows sr
       set exemplaires_comparaison = p.comparaison
      from perimetre p
     where sr.id = p.id
    returning p.comparaison is not null as comparee
  )
  select count(*) filter (where comparee) into v_n from maj;
  return coalesce(v_n, 0);
end;
$function$;

-- Lire (la liste, le recalcul) : verdicts SANS valeurs, applicables, le
-- brouillon de mise à jour préparé depuis cette ligne ; NULL si la comparaison
-- manque ou est périmée (autre notice que la proposée). p_rejetee : la ligne
-- est rejetée par choix (rien n'est applicable).
CREATE OR REPLACE FUNCTION ingest.fn_h21_exemplaires_maj(p_row_id bigint, p_cmp jsonb, p_proposed_book_id bigint, p_rejetee boolean)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  with items as (
    select x.v, (x.v->>'n')::integer as n, (x.v->>'exemplar_id')::bigint as eid,
           d.id as draft_id, d.status as draft_status,
           -- revue sceptique du 08/10 : ce que « Préparer » refuserait de toute
           -- façon — un brouillon de mise à jour vivant (d'un autre run aussi),
           -- ou un autre brouillon vivant (« Éditer ») — n'est pas préparable
           v.vivant_maj, v.vivant_autre,
           -- (la visibilité : d'un coup pour l'administration et le staff de la
           -- bibliothèque qui importe ; exemplaire par exemplaire sinon)
           x.v ? 'champs' and not ctx.voit_tout
             and not ingest.fn_h21_exemplaire_visible((x.v->>'exemplar_id')::bigint) as masque
      from jsonb_array_elements(p_cmp->'items') x(v)
      cross join (select coalesce(public.fn_caller_is_network_admin(), false)
                         or coalesce(public.user_has_library_staff_role(auth.uid(), (p_cmp->>'library_id')::uuid), false)
                         as voit_tout) ctx
      left join lateral (select y.id, y.status from public.exemplar_drafts y
                          where y.import_staging_row_id = p_row_id and y.import_update is not null
                            and y.published_exemplar_id = (x.v->>'exemplar_id')::bigint
                            and y.status <> 'cancelled'
                          order by y.id desc limit 1) d on true
      left join lateral (select coalesce(bool_or(y.import_update is not null), false) as vivant_maj,
                                coalesce(bool_or(y.import_update is null), false) as vivant_autre
                           from public.exemplar_drafts y
                          where y.published_exemplar_id = (x.v->>'exemplar_id')::bigint
                            and y.status in ('draft', 'ready')) v on true
  )
  select case when p_cmp is null or (p_cmp->>'book_id') is distinct from p_proposed_book_id::text then null
  else jsonb_build_object(
    'computed_at', p_cmp->'at',
    'deja_la', coalesce((p_cmp->>'deja_la')::integer, 0),
    'applicables', case when coalesce(p_rejetee, false) then 0
                        else (select count(*)::integer from items i
                               where i.v->>'constat' = 'deja_la' and i.v->>'baseline_id' is not null
                                 and coalesce((i.v->>'applicables')::integer, 0) > 0 and i.draft_id is null
                                 and not i.vivant_maj and not i.vivant_autre and not i.masque) end,
    'items', coalesce((select jsonb_agg(jsonb_build_object(
                         'n', i.n, 'constat', i.v->>'constat', 'exemplar_id', i.eid, 'tombo', i.v->>'tombo',
                         -- hors de vue : « masque », jamais le verdict fin (il trahirait A)
                         'verdicts', (select jsonb_object_agg(c->>'champ', case when i.masque then 'masque' else c->>'verdict' end)
                                        from jsonb_array_elements(i.v->'champs') c),
                         'applicables', case when i.masque then 0 else coalesce((i.v->>'applicables')::integer, 0) end,
                         'sans_base', not i.masque and i.v->>'constat' = 'deja_la' and i.v->>'baseline_id' is null,
                         'empeche', case when i.vivant_maj then 'deja_preparee' when i.vivant_autre then 'brouillon_en_cours' end,
                         'draft_id', i.draft_id, 'draft_status', i.draft_status) order by i.n)
                         from items i), '[]'::jsonb)) end;
$function$;

-- Lire le détail (fn_import_row_comparison) : valeurs AnarBib masquées d'un
-- exemplaire que l'appelant ne verrait pas ; empreintes retirées.
CREATE OR REPLACE FUNCTION ingest.fn_h21_exemplaires_a_lire(p_cmp jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select case when p_cmp is null then null else
    -- (sans l'heure du calcul : deux lectures de la même ligne disent la même chose)
    (p_cmp - 'items' - 'at') || jsonb_build_object('items', coalesce((
      select jsonb_agg(case
               -- revue sceptique du 08/10 : hors de vue, ni A, ni B, ni le verdict
               -- fin (source_seule avec B dit A = B), ni les applicables, ni la
               -- base — un état « masqué » ; la valeur du fichier (N) reste.
               when x.v ? 'champs' and not ingest.fn_h21_exemplaire_visible((x.v->>'exemplar_id')::bigint) then
                 (x.v - array['empreinte_exemplaire', 'empreinte_base', 'n_item', 'champs', 'baseline_id', 'applicables'])
                 || jsonb_build_object('a_masque', true,
                                       'champs', (select jsonb_agg(jsonb_build_object('champ', c->>'champ', 'verdict', 'masque', 'n', c->'n') order by o)
                                                    from jsonb_array_elements(x.v->'champs') with ordinality t(c, o)))
               else (x.v - array['empreinte_exemplaire', 'empreinte_base', 'n_item'])
                    || case when x.v ? 'champs' then jsonb_build_object('a_masque', false) else '{}'::jsonb end
             end order by (x.v->>'n')::integer)
        from jsonb_array_elements(p_cmp->'items') x(v)), '[]'::jsonb)) end;
$function$;


-- ─────────────────────────────────────────────────────────────────────
-- 5. Préparer : un brouillon de mise à jour par exemplaire
-- ─────────────────────────────────────────────────────────────────────
-- Appelée par fn_import_preparer_mises_a_jour (accès, page, verrou du run,
-- comparaison rangée dans la même transaction). p_batch : le lot que la
-- partie notice a pris, s'il y en a un. Rend {batch_id, prepared, skipped,
-- drafts}.
CREATE OR REPLACE FUNCTION ingest.fn_h21_preparer_exemplaires(p_run_id bigint, p_row_ids bigint[], p_lib uuid,
                                                              p_actor uuid, p_batch bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  -- Les raisons d'ignorer un exemplaire (l'écran : RAISONS_EXEMPLAIRES ; la
  -- vérification de fin de migration contrôle que le jugement les emploie).
  c_raisons constant text[] := array['signale', 'pas_au_catalogue', 'rejetee', 'autre_bibliotheque', 'deja_preparee',
                                     'brouillon_en_cours', 'sans_base', 'rien_a_appliquer'];
  v_batch bigint := p_batch;
  v_juge jsonb;
  v_skipped jsonb;
  v_eligibles integer;
  v_crees bigint[];
begin
  -- Deux préparations de la même bibliothèque (deux runs) attendent l'une
  -- l'autre : un verrou d'avis par bibliothèque, pris une fois (revue
  -- sceptique du 08/10 : un verrou par exemplaire en prenait 5 000 dans la
  -- table des verrous pour une page de 200 lignes à 25 exemplaires).
  if p_lib is not null then
    perform pg_advisory_xact_lock(hashtextextended('h21-lot6b/exemplaires/' || p_lib::text, 0));
  end if;

  -- Le jugement de chaque exemplaire du fichier des lignes demandées, EN UNE
  -- PASSE (revue sceptique du 08/10 : la boucle par exemplaire, et un jsonb
  -- allongé à chaque tour, coûtaient 18 s pour 5 000 exemplaires).
  with items as (
    select sr.id as row_id, sr.proposed_book_id, x.v as it, (x.v->>'n')::integer as n,
           (x.v->>'exemplar_id')::bigint as eid, sr.exemplaires_comparaison->'source_id' as source_id,
           ingest.fn_h21_rejet_par_choix(sr.editorial_decision, sr.editorial_note, sr.discarded_draft_id) as rejetee
      from ingest.partner_catalog_staging_rows sr
      cross join lateral jsonb_array_elements(coalesce(sr.exemplaires_comparaison->'items', '[]'::jsonb)) x(v)
     where sr.run_id = p_run_id and sr.id = any (coalesce(p_row_ids, '{}'::bigint[]))
       and sr.match_status = 'known_record' and sr.proposed_book_id is not null
       and (sr.exemplaires_comparaison->>'book_id') = sr.proposed_book_id::text   -- la partie notice dit les autres
  ), juge0 as (
    select i.*, e.holding_id, e.tombo,
           case
             when i.it->>'constat' in ('sans_code', 'deplace', 'reetiquete', 'code_repris') then 'signale'
             when i.it->>'constat' is distinct from 'deja_la' then 'pas_au_catalogue'
             when i.rejetee then 'rejetee'
             when e.id is null or p_lib is null or e.library_id is distinct from p_lib then 'autre_bibliotheque'
             when h.book_id is distinct from i.proposed_book_id then 'signale'
             when exists (select 1 from public.exemplar_drafts y
                           where y.published_exemplar_id = i.eid and y.status in ('draft', 'ready')
                             and y.import_update is not null) then 'deja_preparee'
             when exists (select 1 from public.exemplar_drafts y
                           where y.published_exemplar_id = i.eid and y.status in ('draft', 'ready')) then 'brouillon_en_cours'
             when i.it->>'baseline_id' is null then 'sans_base'
             when coalesce((i.it->>'applicables')::integer, 0) = 0 then 'rien_a_appliquer'
           end as raison
      from items i
      left join public.exemplares e on e.id = i.eid
      left join public.book_holdings h on h.id = e.holding_id
  ), juge as (
    -- le même exemplaire deux fois dans la sélection (deux lignes, deux fois le
    -- code) : un seul brouillon, les autres « déjà préparé »
    select j.*, case when j.raison is null
                      and row_number() over (partition by j.eid, j.raison is null order by j.row_id, j.n) > 1
                     then 'deja_preparee' else j.raison end as raison_finale
      from juge0 j
  )
  select coalesce(jsonb_agg(jsonb_build_object('row_id', j.row_id, 'eid', j.eid, 'raison', j.raison_finale,
                                               'source_id', j.source_id, 'holding_id', j.holding_id, 'tombo', j.tombo,
                                               'book_id', j.proposed_book_id, 'it', j.it)), '[]'::jsonb)
    into v_juge
    from juge j;

  select coalesce(jsonb_object_agg(s.raison, s.k) filter (where s.raison is not null), '{}'::jsonb),
         coalesce(sum(s.k) filter (where s.raison is null), 0)
    into v_skipped, v_eligibles
    from (select x->>'raison' as raison, count(*)::integer as k
            from jsonb_array_elements(v_juge) x group by 1) s;

  if v_eligibles > 0 and v_batch is null then
    -- dans le lot ouvert du run (IMP-27 d), sinon un lot neuf de la bibliothèque
    v_batch := ingest.fn_h21_lot_ouvert_du_run(p_run_id, p_lib);
    if v_batch is null then
      v_batch := ingest.fn_h21_lot_de_la_mise_a_jour(p_run_id, p_lib, p_actor);
    end if;
  end if;

  -- La COPIE COMPLÈTE de chaque exemplaire préparable : les colonnes qu'écrit
  -- la branche update de publish_exemplar_draft (et la trace du lot 6a),
  -- patchée des seuls champs appliqués (source_seule avec une valeur du
  -- fichier : un effacement est montré, jamais appliqué) ; la trace
  -- import_update. created_at ≠ now() : jamais une « reprise vierge »
  -- (tg_drafts_retake_untouched).
  with cand as (
    select x->'it' as it, (x->>'row_id')::bigint as row_id, (x->>'eid')::bigint as eid, x->'source_id' as source_id,
           (x->>'holding_id')::bigint as holding_id, x->>'tombo' as tombo, (x->>'book_id')::bigint as book_id,
           (select coalesce(jsonb_object_agg(c->>'champ', c->'n'), '{}'::jsonb)
              from jsonb_array_elements(x->'it'->'champs') c
             where c->>'verdict' = 'source_seule' and coalesce(c->'n', 'null'::jsonb) <> 'null'::jsonb) as app
      from jsonb_array_elements(v_juge) x
     where x->>'raison' is null
  ), ins as (
    insert into public.exemplar_drafts (
      published_exemplar_id, batch_id, action, status, label_status,
      target_bib_ref, target_library_id, target_holding_id, tombo,
      shelf_location, label_title_override, label_author_override, label_cdd_override, label_note, notes,
      acquisition_mode, acquisition_date, provenance_note, source_library, circulation_policy, visibility,
      source_item_code, source_item_id, import_source_id, import_run_id,
      import_staging_row_id, import_update,
      created_by, updated_by, created_at
    )
    select e.id, v_batch, 'update', 'draft', 'pending',
           coalesce(nullif(btrim(h.local_bib_ref), ''), b.bib_ref, e.bib_ref), e.library_id, e.holding_id, e.tombo,
           case when a.app ? 'shelf_location' then a.app->>'shelf_location' else e.shelf_location end,
           e.label_title_override, e.label_author_override, e.label_cdd_override, e.label_note,
           case when a.app ? 'notes' then a.app->>'notes' else e.notes end,
           e.acquisition_mode, e.acquisition_date, e.provenance_note, e.source_library, e.circulation_policy, e.visibility,
           e.source_item_code, e.source_item_id, e.import_source_id, e.import_run_id,
           a.row_id,
           jsonb_build_object(
             'version', 'h21-lot6b/2026-10-08',
             'run_id', p_run_id,
             'staging_row_id', a.row_id,
             'n', (a.it->>'n')::integer,
             'code', a.it->'code',
             'expl_id', a.it->'expl_id',
             'library_id', p_lib,
             'source_id', a.source_id,
             'book_id', a.book_id,
             'holding_id', a.holding_id,
             'exemplar_id', a.eid,
             'tombo', a.tombo,
             'baseline_id', (a.it->>'baseline_id')::bigint,
             'empreinte_exemplaire', a.it->>'empreinte_exemplaire',
             'empreinte_base', a.it->>'empreinte_base',
             'prepared_at', now(),
             'prepared_by', p_actor,
             'appliques', (select coalesce(jsonb_agg(jsonb_build_object('champ', c->>'champ', 'b', c->'b', 'a', c->'a', 'n', c->'n')
                                                     order by o), '[]'::jsonb)
                             from jsonb_array_elements(a.it->'champs') with ordinality t(c, o)
                            where c->>'verdict' = 'source_seule' and coalesce(c->'n', 'null'::jsonb) <> 'null'::jsonb),
             -- montrés, jamais appliqués : effacements par la source, conflits,
             -- sans base, changés dans AnarBib seulement
             'montres', (select coalesce(jsonb_agg(jsonb_build_object('champ', c->>'champ', 'verdict', c->>'verdict',
                                                                      'b', c->'b', 'a', c->'a', 'n', c->'n')
                                                   || case when c->>'verdict' = 'source_seule'
                                                           then jsonb_build_object('raison', 'efface_par_la_source')
                                                           else '{}'::jsonb end
                                                   order by o), '[]'::jsonb)
                           from jsonb_array_elements(a.it->'champs') with ordinality t(c, o)
                          where (c->>'verdict' = 'source_seule' and coalesce(c->'n', 'null'::jsonb) = 'null'::jsonb)
                             or c->>'verdict' in ('conflit', 'sans_base', 'local_seul')),
             'champs', (select coalesce(jsonb_agg(jsonb_build_object('champ', c->>'champ', 'verdict', c->>'verdict', 'n', c->'n')
                                                  order by o), '[]'::jsonb)
                          from jsonb_array_elements(a.it->'champs') with ordinality t(c, o)),
             'n_item', a.it->'n_item'),
           p_actor, p_actor, greatest(clock_timestamp(), now() + interval '1 microsecond')
      from cand a
      join public.exemplares e on e.id = a.eid
      left join public.book_holdings h on h.id = e.holding_id
      left join public.books b on b.id = h.book_id
    returning id
  )
  select coalesce(array_agg(ins.id), '{}'::bigint[]) into v_crees from ins;

  -- La liste des brouillons créés, en une requête à la fin.
  return jsonb_build_object('batch_id', v_batch, 'prepared', cardinality(v_crees), 'skipped', v_skipped,
    'drafts', (select coalesce(jsonb_agg(jsonb_build_object(
                         'row_id', x.import_staging_row_id, 'item_draft_id', x.id, 'exemplar_id', x.published_exemplar_id,
                         'applied', (select coalesce(jsonb_agg(a->>'champ' order by a->>'champ'), '[]'::jsonb)
                                       from jsonb_array_elements(x.import_update->'appliques') a)) order by x.id), '[]'::jsonb)
                 from public.exemplar_drafts x where x.id = any (v_crees)));
end;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_preparer_exemplaires(bigint, bigint[], uuid, uuid, bigint) IS
  'H21 lot 6b (08/10/2026, IMP-33 c) : la partie exemplaires de « Préparer la mise à jour » — pour chaque exemplaire « déjà là » de la bibliothèque qui importe dont la cote ou la note a changé dans le fichier seulement, un brouillon de mise à jour (copie complète patchée, trace import_update) dans le lot ouvert du run ; les autres ignorés avec leur raison. Interne : public.fn_import_preparer_mises_a_jour.';


-- ─────────────────────────────────────────────────────────────────────
-- 6. La garde de publication, la base qui avance
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION ingest.fn_h21_garde_mise_a_jour_exemplaire(p_draft_id bigint, p_republication boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_d public.exemplar_drafts%rowtype;
  v_u jsonb;
  v_e public.exemplares%rowtype;
  v_lib uuid;
  v_book bigint;
begin
  select * into v_d from public.exemplar_drafts where id = p_draft_id;
  v_u := v_d.import_update;
  if v_u is null then
    return;
  end if;
  v_lib := nullif(v_u->>'library_id', '')::uuid;

  -- (0) jamais une création : l'exemplaire visé existe, c'est celui de la trace
  --     (un exemplaire supprimé vide le lien : ON DELETE SET NULL)
  if v_d.published_exemplar_id is null then
    raise exception 'atualizacao_de_exemplar_sem_exemplar' using hint = 'error.publish.item_update_gone';
  end if;
  select * into v_e from public.exemplares where id = v_d.published_exemplar_id for update;
  if not found or v_d.published_exemplar_id::text is distinct from v_u->>'exemplar_id' then
    raise exception 'atualizacao_de_exemplar_sem_exemplar' using hint = 'error.publish.item_update_gone';
  end if;
  -- (1) la bibliothèque : celle de la trace, de l'exemplaire et du brouillon
  if v_lib is null or v_e.library_id is distinct from v_lib
     or coalesce(v_d.target_library_id, v_lib) is distinct from v_lib then
    raise exception 'atualizacao_de_exemplar_biblioteca_alterada' using hint = 'error.publish.item_update_library_changed';
  end if;
  -- (2) la notice (et, à la première publication, le fonds)
  select h.book_id into v_book from public.book_holdings h where h.id = v_e.holding_id;
  if v_book is null or v_book::text is distinct from v_u->>'book_id' then
    raise exception 'atualizacao_de_exemplar_movido' using hint = 'error.publish.item_update_moved';
  end if;
  if p_republication then
    -- republication : bibliothèque et notice ; et (revue sceptique du 08/10)
    -- l'exemplaire tel que la dernière publication de ce brouillon l'a laissé
    -- — un « Éditer » publié entre-temps n'est jamais défait en silence.
    if v_u->>'empreinte_apres' is null
       or ingest.fn_h21_empreinte_exemplaire(v_e.id) is distinct from v_u->>'empreinte_apres' then
      raise exception 'atualizacao_de_exemplar_alterada_desde_a_publicacao'
        using hint = 'error.publish.item_update_changed_since_publication';
    end if;
    return;
  end if;
  if v_e.holding_id::text is distinct from v_u->>'holding_id'
     or coalesce(v_d.target_holding_id, v_e.holding_id) is distinct from v_e.holding_id then
    raise exception 'atualizacao_de_exemplar_movido' using hint = 'error.publish.item_update_moved';
  end if;
  -- (3) la ligne d'import de la trace (preuve d'import, révision)
  if v_d.import_staging_row_id is null
     or v_d.import_staging_row_id::text is distinct from v_u->>'staging_row_id'
     or not exists (select 1 from ingest.partner_catalog_staging_rows sr
                     where sr.id = v_d.import_staging_row_id and sr.run_id::text = v_u->>'run_id') then
    raise exception 'atualizacao_de_exemplar_sem_linha' using hint = 'error.publish.item_update_import_row_gone';
  end if;
  -- (4) la base : la même, toujours à cet exemplaire et cette bibliothèque
  if not exists (select 1 from ingest.exemplar_import_baselines bl
                  where bl.id = nullif(v_u->>'baseline_id', '')::bigint
                    and bl.exemplar_id = v_e.id and bl.library_id = v_lib)
     or ingest.fn_h21_empreinte_base_exemplaire(nullif(v_u->>'baseline_id', '')::bigint) is distinct from v_u->>'empreinte_base' then
    raise exception 'atualizacao_de_exemplar_base_alterada' using hint = 'error.publish.item_update_baseline_changed';
  end if;
  -- (5) l'exemplaire n'a pas changé depuis la préparation (empreinte de A)
  if ingest.fn_h21_empreinte_exemplaire(v_e.id) is distinct from v_u->>'empreinte_exemplaire' then
    raise exception 'atualizacao_de_exemplar_alterado' using hint = 'error.publish.item_update_changed';
  end if;
end;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_garde_mise_a_jour_exemplaire(bigint, boolean) IS
  'H21 lot 6b (08/10/2026) : garde de la publication d''un brouillon de mise à jour d''exemplaire (trace import_update) — toujours : exemplaire présent (jamais une création), bibliothèque, notice ; première publication : aussi fonds, ligne d''import, base, empreinte de l''exemplaire. Interne : publish_exemplar_draft.';

-- La base avance à N pour les champs que l'exemplaire publié dit comme le
-- fichier, garde B pour les autres (règle (d) d'IMP-31) ; run, ligne, code,
-- expl_id et empreinte suivent le fichier accepté.
CREATE OR REPLACE FUNCTION ingest.fn_h21_avancer_base_exemplaire(p_draft_id bigint, p_exemplar_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_u jsonb;
  v_bl ingest.exemplar_import_baselines%rowtype;
  v_ej jsonb;
  v_avances text[];
  v_gardes text[];
  v_res jsonb;
begin
  select x.import_update into v_u from public.exemplar_drafts x where x.id = p_draft_id;
  if v_u is null then
    return null;
  end if;
  select * into v_bl from ingest.exemplar_import_baselines
   where id = nullif(v_u->>'baseline_id', '')::bigint and exemplar_id = p_exemplar_id for update;
  if not found then
    return null;   -- la garde l'a vérifiée juste avant, dans la même transaction
  end if;
  select to_jsonb(e) into v_ej from public.exemplares e where e.id = p_exemplar_id;
  select coalesce(array_agg(x.champ order by x.o) filter (where x.avance), '{}'::text[]),
         coalesce(array_agg(x.champ order by x.o) filter (where not x.avance), '{}'::text[])
    into v_avances, v_gardes
    from (select c->>'champ' as champ, o,
                 nullif(btrim(v_ej->>(c->>'champ')), '') is not distinct from nullif(btrim(c->>'n'), '') as avance
            from jsonb_array_elements(v_u->'champs') with ordinality t(c, o)) x;

  update ingest.exemplar_import_baselines bl
     set shelf_location = case when 'shelf_location' = any (v_avances) then v_u->'n_item'->>'shelf_location' else bl.shelf_location end,
         notes = case when 'notes' = any (v_avances) then v_u->'n_item'->>'notes' else bl.notes end,
         run_id = nullif(v_u->>'run_id', '')::bigint,
         staging_row_id = nullif(v_u->>'staging_row_id', '')::bigint,
         source_item_code = coalesce(v_u->'n_item'->>'code', bl.source_item_code),
         source_item_id = coalesce(v_u->'n_item'->>'expl_id', bl.source_item_id),
         payload_hash = coalesce(v_u->'n_item'->>'payload_hash', bl.payload_hash),
         origine = 'import',
         imported_at = now(),
         confirmed_at = now(),
         updated_at = now()
   where bl.id = v_bl.id;

  v_res := jsonb_build_object('baseline_id', v_bl.id, 'avances', to_jsonb(v_avances), 'gardes', to_jsonb(v_gardes),
                              'published_at', now());
  update public.exemplar_drafts x
     set import_update = jsonb_set(x.import_update, '{publication}', v_res)
   where x.id = p_draft_id;
  return v_res;
end;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_avancer_base_exemplaire(bigint, bigint) IS
  'H21 lot 6b (08/10/2026) : à la première publication d''un brouillon de mise à jour d''exemplaire, la base avance à N pour les champs que l''exemplaire publié dit comme le fichier, garde B pour les autres ; run, ligne, code, expl_id, empreinte suivent le fichier accepté. Interne : publish_exemplar_draft.';

DO $h21l6b_droits$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'ingest.fn_h21_champs_exemplaire()', 'ingest.fn_h21_n_exemplaire(jsonb)',
    'ingest.fn_h21_item_de_la_ligne(bigint, text)', 'ingest.fn_h21_empreinte_exemplaire(bigint)',
    'ingest.fn_h21_empreinte_hors_patch(bigint)', 'ingest.fn_h21_empreinte_base_exemplaire(bigint)',
    'ingest.fn_h21_exemplaire_visible(bigint)', 'ingest.fn_h21_poser_base_exemplaire(bigint, bigint, text)',
    'ingest.fn_h21_reprendre_les_bases_exemplaires()', 'ingest.fn_h21_exemplaires_trois_etats(bigint)',
    'ingest.fn_h21_exemplaires_trois_etats_lot(bigint, bigint[])',
    'ingest.fn_h21_exemplaires_par_appel()', 'ingest.fn_h21_garde_plafond_exemplaires(bigint, bigint[])',
    'ingest.fn_h21_stocker_comparaisons_exemplaires(bigint, bigint[])',
    'ingest.fn_h21_exemplaires_maj(bigint, jsonb, bigint, boolean)', 'ingest.fn_h21_exemplaires_a_lire(jsonb)',
    'ingest.fn_h21_preparer_exemplaires(bigint, bigint[], uuid, uuid, bigint)',
    'ingest.fn_h21_garde_mise_a_jour_exemplaire(bigint, boolean)',
    'ingest.fn_h21_avancer_base_exemplaire(bigint, bigint)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
  END LOOP;
END
$h21l6b_droits$;


-- ─────────────────────────────────────────────────────────────────────
-- 7. L'API ne pose ni ne change la trace, ni l'exemplaire visé
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6b_trace$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6b_def('public.tg_exemplar_drafts_import_links_locked()'::regprocedure);
  v_def := pg_temp.h21l6b_remplacer('tg_exemplar_drafts_import_links_locked', v_def,
$a$    RAISE EXCEPTION 'Rastro de importacao do exemplar reservado ao circuito de importacao.'
      USING ERRCODE = '42501', HINT = 'error.import.item_trace_reserved';
  END IF;
$a$,
$b$    RAISE EXCEPTION 'Rastro de importacao do exemplar reservado ao circuito de importacao.'
      USING ERRCODE = '42501', HINT = 'error.import.item_trace_reserved';
  END IF;
  -- H21 lot 6b (08/10/2026) : la trace d'un brouillon de mise à jour
  -- d'exemplaire (import_update) ne se pose ni ne se change par l'API, à
  -- l'INSERT comme à l'UPDATE ; l'exemplaire visé d'un tel brouillon non plus.
  IF (TG_OP = 'INSERT' AND NEW.import_update IS NOT NULL)
     OR (TG_OP = 'UPDATE' AND (NEW.import_update IS DISTINCT FROM OLD.import_update
                               OR (OLD.import_update IS NOT NULL
                                   AND NEW.published_exemplar_id IS DISTINCT FROM OLD.published_exemplar_id))) THEN
    RAISE EXCEPTION 'Rastro de atualizacao do exemplar reservado ao circuito de importacao.'
      USING ERRCODE = '42501', HINT = 'error.import.item_update_trace_reserved';
  END IF;
$b$);
  EXECUTE v_def;
END
$h21l6b_trace$;


-- ─────────────────────────────────────────────────────────────────────
-- 7 bis. Un seul brouillon vivant à la fois sur un exemplaire qui a une mise
--        à jour d'import en attente (revue sceptique du 08/10)
-- ─────────────────────────────────────────────────────────────────────
-- Le pendant de « brouillon_en_cours » : tant qu'un brouillon de mise à jour
-- d'import est vivant pour un exemplaire, aucun autre brouillon de reprise ne
-- naît pour lui (« Éditer », API, sortie de corbeille, rejeu du journal,
-- toute fonction : le déclencheur juge, quelle que soit la voie) — sinon,
-- publié après la mise à jour, il réécrirait la cote importée en silence
-- (error.catalog.item_update_pending). Et un brouillon de mise à jour qui
-- revient (corbeille) alors qu'une autre mise à jour a été préparée depuis
-- pour le même exemplaire est refusé avec son vrai motif
-- (error.import.item_update_superseded).
CREATE OR REPLACE FUNCTION public.tg_exemplar_drafts_maj_import_exclusive()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.published_exemplar_id IS NULL OR NEW.status NOT IN ('draft', 'ready') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status IN ('draft', 'ready')
     AND OLD.published_exemplar_id IS NOT DISTINCT FROM NEW.published_exemplar_id THEN
    RETURN NEW;   -- ni naissance, ni retour, ni changement d'exemplaire
  END IF;
  IF EXISTS (SELECT 1 FROM public.exemplar_drafts y
              WHERE y.published_exemplar_id = NEW.published_exemplar_id
                AND y.status IN ('draft', 'ready') AND y.import_update IS NOT NULL
                AND y.id IS DISTINCT FROM NEW.id) THEN
    IF NEW.import_update IS NOT NULL THEN
      RAISE EXCEPTION 'atualizacao_de_exemplar_substituida: %', NEW.published_exemplar_id
        USING HINT = 'error.import.item_update_superseded';
    END IF;
    RAISE EXCEPTION 'exemplar_com_atualizacao_de_importacao_pendente: %', NEW.published_exemplar_id
      USING HINT = 'error.catalog.item_update_pending';
  END IF;
  RETURN NEW;
END
$function$;
REVOKE ALL ON FUNCTION public.tg_exemplar_drafts_maj_import_exclusive() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tg_exemplar_drafts_maj_import_exclusive() TO service_role;
-- (avant exemplar_drafts_zx_code_libre_au_retour : ordre alphabétique des déclencheurs)
DROP TRIGGER IF EXISTS exemplar_drafts_maj_import_exclusive ON public.exemplar_drafts;
CREATE TRIGGER exemplar_drafts_maj_import_exclusive
  BEFORE INSERT OR UPDATE OF status, published_exemplar_id ON public.exemplar_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_exemplar_drafts_maj_import_exclusive();

-- Le rejeu du journal : son contrôle « code pris » passe avant l'insertion ;
-- un brouillon de mise à jour supplanté y reçoit son vrai motif.
DO $h21l6b_journal$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6b_def('public.fn_restore_deleted_draft(bigint)'::regprocedure);
  v_def := pg_temp.h21l6b_remplacer('fn_restore_deleted_draft (mise à jour supplantée)', v_def,
$a$  -- H21 lot 6a (08/10/2026) : la trace d'import revient avec le brouillon$a$,
$b$  -- H21 lot 6b (revue sceptique du 08/10) : un brouillon de mise à jour
  -- d'exemplaire dont une autre mise à jour a été préparée depuis pour le même
  -- exemplaire ne revient pas — motif dit (et non « code repris »).
  if v_tbl = 'exemplar_drafts' and jsonb_typeof(v_snap->'import_update') = 'object'
     and coalesce(v_snap->>'status', 'draft') in ('draft', 'ready')
     and exists (select 1 from public.exemplar_drafts y
                  where y.published_exemplar_id = (v_snap->>'published_exemplar_id')::bigint
                    and y.status in ('draft', 'ready') and y.import_update is not null
                    and y.id <> v_id) then
    raise exception 'atualizacao_de_exemplar_substituida: %', v_snap->>'published_exemplar_id'
      using hint = 'error.import.item_update_superseded';
  end if;
  -- H21 lot 6a (08/10/2026) : la trace d'import revient avec le brouillon$b$);
  EXECUTE v_def;
END
$h21l6b_journal$;


-- ─────────────────────────────────────────────────────────────────────
-- 8. publish_exemplar_draft : la garde avant les portes et la branche,
--    l'empreinte avant/après, la base posée ou avancée
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6b_publication$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6b_def('public.publish_exemplar_draft(bigint)'::regprocedure);
  v_def := pg_temp.h21l6b_remplacer('publish_exemplar_draft (déclarations)', v_def,
$a$  v_item_src bigint;          -- H21 lot 6a : et sa source
begin$a$,
$b$  v_item_src bigint;          -- H21 lot 6a : et sa source
  v_maj_exemplaire boolean := false;   -- H21 lot 6b : première publication d'une mise à jour d'exemplaire
  v_hors_patch text;                   -- H21 lot 6b : empreinte de ce qui ne doit pas bouger
begin$b$);
  v_def := pg_temp.h21l6b_remplacer('publish_exemplar_draft (garde)', v_def,
$a$  if v_draft.status = 'cancelled' then
    raise exception 'Este rascunho de exemplar foi descartado.';
  end if;
$a$,
$b$  if v_draft.status = 'cancelled' then
    raise exception 'Este rascunho de exemplar foi descartado.';
  end if;

  -- H21 lot 6b (08/10/2026, IMP-33 c) : un brouillon de mise à jour
  -- d'exemplaire préparé par un réimport (trace import_update, figée pour
  -- l'API) est jugé AVANT les portes de révision et le choix de branche — une
  -- garde dans une seule branche se contourne par l'autre — et à la
  -- republication aussi : exemplaire présent (jamais une création),
  -- bibliothèque, notice ; à la première publication, fonds, ligne d'import,
  -- base et empreinte de l'exemplaire (ingest.fn_h21_garde_mise_a_jour_exemplaire).
  if v_draft.import_update is not null then
    perform ingest.fn_h21_garde_mise_a_jour_exemplaire(p_draft_id, v_draft.status = 'published');
    v_maj_exemplaire := v_draft.status is distinct from 'published';
  end if;
$b$);
  v_def := pg_temp.h21l6b_remplacer('publish_exemplar_draft (empreinte avant)', v_def,
$a$  if v_draft.published_exemplar_id is null then
    -- #fix-tombo-stale$a$,
$b$  -- H21 lot 6b : ce que la mise à jour ne doit pas toucher, juste avant d'écrire
  if v_maj_exemplaire then
    v_hors_patch := ingest.fn_h21_empreinte_hors_patch(v_draft.published_exemplar_id);
  end if;

  if v_draft.published_exemplar_id is null then
    -- #fix-tombo-stale$b$);
  v_def := pg_temp.h21l6b_remplacer('publish_exemplar_draft (empreinte après)', v_def,
$a$     where id = v_draft.published_exemplar_id
    returning id into v_exemplar_id;
  end if;
$a$,
$b$     where id = v_draft.published_exemplar_id
    returning id into v_exemplar_id;
  end if;

  -- H21 lot 6b (08/10/2026) : la première publication d'une mise à jour
  -- d'exemplaire ne change QUE la cote et la note — l'exemplaire hors ces
  -- champs, l'identité de son fonds et sa circulation sont ceux d'avant ;
  -- sinon refus (une retouche du brouillon hors cote et note passe par « Éditer »).
  if v_maj_exemplaire
     and ingest.fn_h21_empreinte_hors_patch(v_exemplar_id) is distinct from v_hors_patch then
    raise exception 'atualizacao_de_exemplar_efeito_colateral' using hint = 'error.publish.item_update_side_effect';
  end if;
$b$);
  v_def := pg_temp.h21l6b_remplacer('publish_exemplar_draft (H20 hors mise à jour)', v_def,
$a$  if v_draft.import_staging_row_id is not null and v_draft.book_draft_id is null then
    perform ingest.fn_record_book_external_id($a$,
$b$  -- H21 lot 6b : une mise à jour d'exemplaire ne touche ni l'identifiant
  -- d'origine de la notice ni sa base (le bloc H20 est celui du rapprochement)
  if v_draft.import_staging_row_id is not null and v_draft.book_draft_id is null
     and v_draft.import_update is null then
    perform ingest.fn_record_book_external_id($b$);
  v_def := pg_temp.h21l6b_remplacer('publish_exemplar_draft (base)', v_def,
$a$      v_draft.import_staging_row_id, v_library_id);
  end if;

  return v_exemplar_id;$a$,
$b$      v_draft.import_staging_row_id, v_library_id);
  end if;

  -- H21 lot 6b (08/10/2026, IMP-33 c) : la base de l'exemplaire — POSÉE à la
  -- première publication d'un exemplaire né d'un import (les valeurs du
  -- fichier de sa ligne ; jamais remplacée ici) ; AVANCÉE à la première
  -- publication d'une mise à jour d'exemplaire (règle (d) d'IMP-31).
  if v_draft.published_exemplar_id is null and v_draft.import_staging_row_id is not null then
    perform ingest.fn_h21_poser_base_exemplaire(v_exemplar_id, p_draft_id);
  end if;
  if v_maj_exemplaire then
    perform ingest.fn_h21_avancer_base_exemplaire(p_draft_id, v_exemplar_id);
  end if;
  -- (revue sceptique du 08/10) l'empreinte de l'exemplaire tel que ce
  -- brouillon le laisse, à chaque publication : la republication refuse un
  -- exemplaire changé depuis (ingest.fn_h21_garde_mise_a_jour_exemplaire).
  if v_draft.import_update is not null then
    update public.exemplar_drafts x
       set import_update = jsonb_set(x.import_update, '{empreinte_apres}',
                                     coalesce(to_jsonb(ingest.fn_h21_empreinte_exemplaire(v_exemplar_id)), 'null'::jsonb))
     where x.id = p_draft_id;
  end if;

  return v_exemplar_id;$b$);
  EXECUTE v_def;
END
$h21l6b_publication$;


-- ─────────────────────────────────────────────────────────────────────
-- 9. Le geste : « Préparer la mise à jour » prépare aussi les exemplaires
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6b_preparer$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6b_def('public.fn_import_preparer_mises_a_jour(bigint, bigint[])'::regprocedure);
  v_def := pg_temp.h21l6b_remplacer('fn_import_preparer_mises_a_jour (déclarations)', v_def,
$a$  v_base bigint;
  rec record;
BEGIN$a$,
$b$  v_base bigint;
  rec record;
  v_ex jsonb;   -- H21 lot 6b : la partie exemplaires
BEGIN$b$);
  v_def := pg_temp.h21l6b_remplacer('fn_import_preparer_mises_a_jour (rien demandé)', v_def,
$a$    RETURN jsonb_build_object('run_id', p_run_id, 'batch_id', NULL, 'asked', 0, 'prepared', 0,
                              'skipped_rows', 0, 'skipped', '{}'::jsonb, 'drafts', '[]'::jsonb);$a$,
$b$    RETURN jsonb_build_object('run_id', p_run_id, 'batch_id', NULL, 'asked', 0, 'prepared', 0,
                              'skipped_rows', 0, 'skipped', '{}'::jsonb, 'drafts', '[]'::jsonb,
                              'exemplaires', jsonb_build_object('prepared', 0, 'skipped', '{}'::jsonb, 'drafts', '[]'::jsonb));$b$);
  v_def := pg_temp.h21l6b_remplacer('fn_import_preparer_mises_a_jour (plafond d''exemplaires)', v_def,
$a$  v_lib := ingest.fn_h21_bibliotheque_importatrice(p_run_id, NULL, NULL);$a$,
$b$  -- H21 lot 6b (revue sceptique du 08/10) : 5 000 exemplaires du fichier au
  -- plus par appel (l'écran découpe), refus dit, avant tout calcul.
  PERFORM ingest.fn_h21_garde_plafond_exemplaires(p_run_id, v_ids);
  v_lib := ingest.fn_h21_bibliotheque_importatrice(p_run_id, NULL, NULL);$b$);
  v_def := pg_temp.h21l6b_remplacer('fn_import_preparer_mises_a_jour (comparaison des exemplaires)', v_def,
$a$  PERFORM ingest.fn_h21_constater_divergences(p_run_id, v_ids);$a$,
$b$  PERFORM ingest.fn_h21_constater_divergences(p_run_id, v_ids);
  -- H21 lot 6b (08/10/2026, IMP-33 c) : la cote et la note des exemplaires
  -- « déjà là », comparées à trois états dans cette transaction.
  PERFORM ingest.fn_h21_stocker_comparaisons_exemplaires(p_run_id, v_ids);$b$);
  v_def := pg_temp.h21l6b_remplacer('fn_import_preparer_mises_a_jour (partie exemplaires)', v_def,
$a$  RETURN jsonb_build_object(
    'run_id', p_run_id,
    'batch_id', v_batch,$a$,
$b$  -- H21 lot 6b (08/10/2026, IMP-33 c) : la partie exemplaires, INDÉPENDANTE
  -- de la partie notice (une notice partagée ou sans rien à appliquer
  -- n'empêche pas ses exemplaires : ils n'appartiennent qu'à la bibliothèque
  -- qui importe) ; même lot ouvert du run.
  v_ex := ingest.fn_h21_preparer_exemplaires(p_run_id, v_ids, v_lib, v_actor.user_id, v_batch);
  v_batch := coalesce(v_batch, (v_ex->>'batch_id')::bigint);

  RETURN jsonb_build_object(
    'run_id', p_run_id,
    'batch_id', v_batch,$b$);
  v_def := pg_temp.h21l6b_remplacer('fn_import_preparer_mises_a_jour (rendu)', v_def,
$a$    'drafts', v_drafts);
END;$a$,
$b$    'drafts', v_drafts,
    'exemplaires', v_ex - 'batch_id');   -- H21 lot 6b
END;$b$);
  EXECUTE v_def;
END
$h21l6b_preparer$;


-- ─────────────────────────────────────────────────────────────────────
-- 10. Le recalcul compare aussi les exemplaires
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6b_recomparer$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6b_def('public.fn_import_recomparer(bigint, bigint[])'::regprocedure);
  v_def := pg_temp.h21l6b_remplacer('fn_import_recomparer (déclarations)', v_def,
$a$  v_div jsonb;   -- H21 lot 5$a$,
$b$  v_div jsonb;   -- H21 lot 5
  v_ex integer;  -- H21 lot 6b$b$);
  v_def := pg_temp.h21l6b_remplacer('fn_import_recomparer (plafond d''exemplaires)', v_def,
$a$  v_n := ingest.fn_h21_stocker_comparaisons(p_run_id, p_row_ids);$a$,
$b$  -- H21 lot 6b (revue sceptique du 08/10) : 5 000 exemplaires du fichier au
  -- plus par appel (l'écran découpe), refus dit, avant tout calcul.
  PERFORM ingest.fn_h21_garde_plafond_exemplaires(p_run_id, p_row_ids);
  v_n := ingest.fn_h21_stocker_comparaisons(p_run_id, p_row_ids);$b$);
  v_def := pg_temp.h21l6b_remplacer('fn_import_recomparer (exemplaires)', v_def,
$a$  v_div := ingest.fn_h21_constater_divergences(p_run_id, p_row_ids);$a$,
$b$  v_div := ingest.fn_h21_constater_divergences(p_run_id, p_row_ids);
  -- H21 lot 6b (08/10/2026, IMP-33 c) : la cote et la note des exemplaires
  -- « déjà là », à trois états ; aucune écriture au catalogue.
  v_ex := ingest.fn_h21_stocker_comparaisons_exemplaires(p_run_id, p_row_ids);$b$);
  v_def := pg_temp.h21l6b_remplacer('fn_import_recomparer (rendu)', v_def,
$a$    'divergences', v_div,   -- H21 lot 5$a$,
$b$    'divergences', v_div,   -- H21 lot 5
    'exemplaires_comparees', v_ex,   -- H21 lot 6b$b$);
  v_def := pg_temp.h21l6b_remplacer('fn_import_recomparer (lignes)', v_def,
$a$jsonb_build_object('id', sr.id, 'counts', sr.comparaison->'counts')$a$,
$b$jsonb_build_object('id', sr.id, 'counts', sr.comparaison->'counts',
                                                 -- H21 lot 6b : l'écran les pose sans recharger
                                                 'exemplaires_maj', ingest.fn_h21_exemplaires_maj(sr.id, sr.exemplaires_comparaison, sr.proposed_book_id,
                                                   ingest.fn_h21_rejet_par_choix(sr.editorial_decision, sr.editorial_note, sr.discarded_draft_id)))$b$);
  EXECUTE v_def;
END
$h21l6b_recomparer$;


-- ─────────────────────────────────────────────────────────────────────
-- 11. Le détail d'une ligne : les exemplaires, champ par champ
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6b_detail$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6b_def('public.fn_import_row_comparison(bigint, bigint)'::regprocedure);
  v_def := pg_temp.h21l6b_remplacer('fn_import_row_comparison', v_def,
$a$    'champs', coalesce(v_champs, '[]'::jsonb));$a$,
$b$    'champs', coalesce(v_champs, '[]'::jsonb),
    -- H21 lot 6b (08/10/2026, IMP-33 c) : les exemplaires « déjà là » de la
    -- ligne, cote et note à trois états, calculés à la lecture ; valeurs
    -- AnarBib masquées d'un exemplaire que l'appelant ne verrait pas.
    'exemplaires', ingest.fn_h21_exemplaires_a_lire(ingest.fn_h21_exemplaires_trois_etats(p_row_id)));$b$);
  EXECUTE v_def;
END
$h21l6b_detail$;


-- ─────────────────────────────────────────────────────────────────────
-- 12. La liste : les exemplaires comparés (DROP + CREATE : une colonne de plus)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6b_liste$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6b_def('public.fn_import_list_run_rows(bigint)'::regprocedure);
  v_def := pg_temp.h21l6b_remplacer('fn_import_list_run_rows (type de retour)', v_def,
$a$ update_draft_id bigint, update_draft_status text, exemplaires jsonb)$a$,
$b$ update_draft_id bigint, update_draft_status text, exemplaires jsonb, exemplaires_maj jsonb)$b$);
  v_def := pg_temp.h21l6b_remplacer('fn_import_list_run_rows (colonne)', v_def,
$a$         END AS exemplaires
  FROM ingest.partner_catalog_staging_rows sr$a$,
$b$         END AS exemplaires,
         -- H21 lot 6b (08/10/2026, IMP-33 c) : la cote et la note des
         -- exemplaires « déjà là » comparées à trois états — verdicts, sans
         -- valeurs (le détail les lit, masquées hors de vue), exemplaires
         -- préparables, brouillon de mise à jour préparé ; NULL hors
         -- known_record, sans comparaison, ou périmée (l'écran recalcule).
         CASE WHEN sr.match_status = 'known_record' THEN
                ingest.fn_h21_exemplaires_maj(sr.id, sr.exemplaires_comparaison, sr.proposed_book_id,
                  ingest.fn_h21_rejet_par_choix(sr.editorial_decision, sr.editorial_note, sr.discarded_draft_id))
         END AS exemplaires_maj
  FROM ingest.partner_catalog_staging_rows sr$b$);
  DROP FUNCTION public.fn_import_list_run_rows(bigint);
  EXECUTE v_def;
END
$h21l6b_liste$;
REVOKE ALL ON FUNCTION public.fn_import_list_run_rows(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_import_list_run_rows(bigint) TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_import_list_run_rows(bigint) IS
  'Lignes d''un run d''import pour l''écran. H21 lot 1 (05/10/2026, IMP-28 b) : proposed_book_held = la bibliothèque qui importe (destination d''un dépôt ou d''un entrepôt OAI, sinon celle du run) détient la notice proposée (book_holdings) ; NULL sans notice proposée. H21 lot 3 (05-06/10/2026) : comparison_counts = comptes par verdict de la comparaison à trois états stockée ; NULL hors known_record ou si elle est périmée (autre notice que la proposée). H21 lot 4 (06/10/2026) : update_applicable = champs source_seule hors responsabilités, avec une valeur du fichier, de cette comparaison (0 si la ligne est rejetée par choix ou écartée) ; update_draft_id / update_draft_status = le brouillon de mise à jour préparé pour la ligne. H21 lot 6a (08/10/2026) : exemplaires = les exemplaires du fichier et leur verdict. H21 lot 6b (08/10/2026) : exemplaires_maj = cote et note des exemplaires déjà là comparées à trois états (verdicts sans valeurs, préparables, brouillon préparé).';


-- ─────────────────────────────────────────────────────────────────────
-- 13. Le rapport de révision : les mises à jour d'exemplaire du lot
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6b_rapport$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6b_def('public.fn_batch_review_report(bigint)'::regprocedure);
  v_def := pg_temp.h21l6b_remplacer('fn_batch_review_report (déclarations)', v_def,
$a$  v_ecartes jsonb;   -- H21 lot 6a$a$,
$b$  v_ecartes jsonb;   -- H21 lot 6a
  v_prep_ex jsonb;   -- H21 lot 6b$b$);
  v_def := pg_temp.h21l6b_remplacer('fn_batch_review_report (items H19 sans les mises à jour)', v_def,
$a$     where x.batch_id = p_batch_id
       and (x.book_draft_id is not null or x.import_staging_row_id is not null)$a$,
$b$     where x.batch_id = p_batch_id
       and (x.book_draft_id is not null or x.import_staging_row_id is not null)
       -- H21 lot 6b : une mise à jour d'exemplaire porte le code de
       -- l'exemplaire qu'elle vise — sa section est plus bas
       and x.import_update is null$b$);
  v_def := pg_temp.h21l6b_remplacer('fn_batch_review_report (section)', v_def,
$a$  return jsonb_build_object(
    'batch', jsonb_build_object($a$,
$b$  -- ── H21 lot 6b (08/10/2026, IMP-33 c) : les brouillons de mise à jour ──
  -- d'exemplaire préparés par un réimport, rangés dans le lot (trace
  -- import_update) : pour chacun, les champs appliqués (base, AnarBib,
  -- fichier) et les champs MONTRÉS non appliqués (effacements, conflits, sans
  -- base, changés dans AnarBib) ; 40 exemples, les comptes sur tout. Clé
  -- absente sans tel brouillon.
  with mx as materialized (
    select x.id, x.status, x.published_exemplar_id, x.tombo, x.source_item_code, x.import_update as u
      from public.exemplar_drafts x
     where x.batch_id = p_batch_id and x.status in ('draft', 'ready', 'published')
       and x.import_update is not null
  )
  select case when (select count(*) from mx) = 0 then null else jsonb_build_object(
           'count', (select count(*) from mx),
           'published', (select count(*) from mx where status = 'published'),
           'applied_fields', (select coalesce(sum(jsonb_array_length(coalesce(u->'appliques', '[]'::jsonb))), 0) from mx),
           'shown_fields', (select coalesce(sum(jsonb_array_length(coalesce(u->'montres', '[]'::jsonb))), 0) from mx),
           'examples', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'item_draft_id', m.id, 'exemplar_id', m.published_exemplar_id, 'tombo', m.tombo,
                      'code', m.source_item_code, 'book_id', (m.u->>'book_id')::bigint,
                      'titulo', (select b.titulo from public.books b where b.id = (m.u->>'book_id')::bigint),
                      'status', m.status,
                      'applied', coalesce(m.u->'appliques', '[]'::jsonb),
                      'shown', coalesce(m.u->'montres', '[]'::jsonb)) order by m.id)
               from (select * from mx order by id limit 40) m), '[]'::jsonb)) end
    into v_prep_ex;

  return jsonb_build_object(
    'batch', jsonb_build_object($b$);
  v_def := pg_temp.h21l6b_remplacer('fn_batch_review_report (rendu)', v_def,
$a$    || case when v_ecartes is null then '{}'::jsonb else jsonb_build_object('items_set_aside', v_ecartes) end;   -- H21 lot 6a$a$,
$b$    || case when v_ecartes is null then '{}'::jsonb else jsonb_build_object('items_set_aside', v_ecartes) end   -- H21 lot 6a
    || case when v_prep_ex is null then '{}'::jsonb else jsonb_build_object('prepared_item_updates', v_prep_ex) end;   -- H21 lot 6b$b$);
  EXECUTE v_def;
END
$h21l6b_rapport$;


-- ─────────────────────────────────────────────────────────────────────
-- 14. Une fusion de brouillons de notice n'emporte pas une mise à jour
--     d'exemplaire
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6b_fusion$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6b_def('api.merge_book_drafts(bigint, bigint, jsonb)'::regprocedure);
  v_def := pg_temp.h21l6b_remplacer('api.merge_book_drafts', v_def,
$a$  IF v_lose.bib_ref IS NOT NULL AND v_surv.bib_ref IS NOT NULL THEN
    UPDATE public.exemplar_drafts SET$a$,
$b$  IF v_lose.bib_ref IS NOT NULL AND v_surv.bib_ref IS NOT NULL THEN
    -- H21 lot 6b (08/10/2026) : un brouillon de mise à jour d'exemplaire
    -- préparé par un réimport (trace import_update) vise un exemplaire au
    -- catalogue ; une fusion ne réécrit pas sa cible — refus dit.
    IF EXISTS (SELECT 1 FROM public.exemplar_drafts x
                WHERE x.batch_id IS NOT DISTINCT FROM v_lose.batch_id
                  AND x.target_bib_ref = v_lose.bib_ref
                  AND x.import_update IS NOT NULL) THEN
      RAISE EXCEPTION 'Rascunho de atualizacao de exemplar nao se funde.'
        USING HINT = 'error.import.item_update_not_mergeable';
    END IF;
    UPDATE public.exemplar_drafts SET$b$);
  EXECUTE v_def;
END
$h21l6b_fusion$;


-- ─────────────────────────────────────────────────────────────────────
-- 15. Reprise (en production le 08/10 : rien à reprendre)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6b_reprise$
DECLARE v_n int;
BEGIN
  v_n := ingest.fn_h21_reprendre_les_bases_exemplaires();
  RAISE NOTICE 'H21 lot 6b reprise : % base(s) d''exemplaire reprise(s)', v_n;
END
$h21l6b_reprise$;


-- ─────────────────────────────────────────────────────────────────────
-- 16. Vérification (structurelle : les migrations passent avant le seed)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6b_verif$
DECLARE
  v_e text := '';
  v_def text;
  v_f text;
BEGIN
  -- la table : RLS sans politique, aucun droit API, FK indexées
  IF NOT (SELECT c.relrowsecurity FROM pg_class c WHERE c.oid = 'ingest.exemplar_import_baselines'::regclass)
     OR EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = 'ingest.exemplar_import_baselines'::regclass)
     OR has_table_privilege('authenticated', 'ingest.exemplar_import_baselines', 'SELECT')
     OR has_table_privilege('anon', 'ingest.exemplar_import_baselines', 'SELECT')
     OR has_table_privilege('authenticated', 'ingest.exemplar_import_baselines', 'INSERT')
     OR position('INGEST-RLS' IN coalesce(obj_description('ingest.exemplar_import_baselines'::regclass, 'pg_class'), '')) = 0
     OR (SELECT count(*) FROM pg_constraint c WHERE c.conrelid = 'ingest.exemplar_import_baselines'::regclass AND c.contype = 'f') <> 3 THEN
    v_e := v_e || ' table';
  END IF;
  -- la publication : garde avant les portes de révision et la branche, à la
  -- republication aussi ; empreinte avant/après ; base posée et avancée ; H20 sauté
  v_def := pg_get_functiondef('public.publish_exemplar_draft(bigint)'::regprocedure);
  IF position('perform ingest.fn_h21_garde_mise_a_jour_exemplaire(p_draft_id, v_draft.status = ''published'');' IN v_def) = 0
     OR position('fn_h21_garde_mise_a_jour_exemplaire' IN v_def) > position('lote_importado_sem_revisao' IN v_def)
     OR position('fn_h21_garde_mise_a_jour_exemplaire' IN v_def) > position('if v_draft.published_exemplar_id is null then' IN v_def)
     OR position('fn_h21_garde_mise_a_jour_exemplaire' IN v_def) < position('error.publish.other_library' IN v_def)
     OR position('v_hors_patch := ingest.fn_h21_empreinte_hors_patch(v_draft.published_exemplar_id);' IN v_def) = 0
     OR position('error.publish.item_update_side_effect' IN v_def) < position('update public.exemplares' IN v_def)
     OR position('perform ingest.fn_h21_avancer_base_exemplaire(p_draft_id, v_exemplar_id);' IN v_def) = 0
     OR position('perform ingest.fn_h21_poser_base_exemplaire(v_exemplar_id, p_draft_id);' IN v_def) = 0
     OR position('and v_draft.import_update is null then' IN v_def) = 0 THEN
    v_e := v_e || ' publication';
  END IF;
  v_def := pg_get_functiondef('ingest.fn_h21_garde_mise_a_jour_exemplaire(bigint, boolean)'::regprocedure);
  FOREACH v_f IN ARRAY ARRAY['error.publish.item_update_gone', 'error.publish.item_update_library_changed',
                             'error.publish.item_update_moved', 'error.publish.item_update_import_row_gone',
                             'error.publish.item_update_baseline_changed', 'error.publish.item_update_changed'] LOOP
    IF position(v_f IN v_def) = 0 THEN v_e := v_e || ' garde(' || v_f || ')'; END IF;
  END LOOP;
  IF position('if p_republication then' IN v_def) < position('error.publish.item_update_library_changed' IN v_def)
     OR position('if p_republication then' IN v_def) > position('error.publish.item_update_import_row_gone' IN v_def) THEN
    v_e := v_e || ' republication';
  END IF;
  -- la trace : l'API ne la pose ni ne la change (INSERT et UPDATE)
  IF position('error.import.item_update_trace_reserved' IN pg_get_functiondef('public.tg_exemplar_drafts_import_links_locked()'::regprocedure)) = 0
     OR NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.exemplar_drafts'::regclass
                     AND t.tgname = 'exemplar_drafts_import_links_locked' AND NOT t.tgisinternal
                     AND (t.tgtype & 4) = 4 AND (t.tgtype & 16) = 16) THEN
    v_e := v_e || ' trace';
  END IF;
  -- (revue sceptique) un seul brouillon vivant à côté d'une mise à jour ; le
  -- journal ; la republication rejuge l'exemplaire
  IF NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.exemplar_drafts'::regclass
                  AND t.tgname = 'exemplar_drafts_maj_import_exclusive' AND NOT t.tgisinternal
                  AND t.tgfoid = 'public.tg_exemplar_drafts_maj_import_exclusive()'::regprocedure
                  AND (t.tgtype & 4) = 4 AND (t.tgtype & 16) = 16)
     OR position('error.import.item_update_superseded' IN pg_get_functiondef('public.fn_restore_deleted_draft(bigint)'::regprocedure)) = 0
     OR position('error.publish.item_update_changed_since_publication' IN pg_get_functiondef('ingest.fn_h21_garde_mise_a_jour_exemplaire(bigint, boolean)'::regprocedure)) = 0
     OR position('{empreinte_apres}' IN pg_get_functiondef('public.publish_exemplar_draft(bigint)'::regprocedure)) = 0
     OR position('reserva_linhas_v2' IN pg_get_functiondef('ingest.fn_h21_empreinte_hors_patch(bigint)'::regprocedure)) = 0
     OR position('ingest.fn_h21_garde_plafond_exemplaires(p_run_id, v_ids)' IN pg_get_functiondef('public.fn_import_preparer_mises_a_jour(bigint, bigint[])'::regprocedure)) = 0
     OR position('ingest.fn_h21_garde_plafond_exemplaires(p_run_id, p_row_ids)' IN pg_get_functiondef('public.fn_import_recomparer(bigint, bigint[])'::regprocedure)) = 0
     OR position('v_drafts' IN pg_get_functiondef('ingest.fn_h21_preparer_exemplaires(bigint, bigint[], uuid, uuid, bigint)'::regprocedure)) > 0
     OR has_function_privilege('authenticated', 'public.tg_exemplar_drafts_maj_import_exclusive()', 'EXECUTE')
     OR has_function_privilege('anon', 'public.tg_exemplar_drafts_maj_import_exclusive()', 'EXECUTE') THEN
    v_e := v_e || ' exclusivite';
  END IF;
  -- le geste, le recalcul, le détail, la liste, le rapport, la fusion
  IF position('ingest.fn_h21_preparer_exemplaires(p_run_id, v_ids, v_lib, v_actor.user_id, v_batch)' IN
              pg_get_functiondef('public.fn_import_preparer_mises_a_jour(bigint, bigint[])'::regprocedure)) = 0
     OR position('ingest.fn_h21_stocker_comparaisons_exemplaires(p_run_id, v_ids)' IN
              pg_get_functiondef('public.fn_import_preparer_mises_a_jour(bigint, bigint[])'::regprocedure)) = 0
     OR position('ingest.fn_h21_stocker_comparaisons_exemplaires(p_run_id, p_row_ids)' IN
              pg_get_functiondef('public.fn_import_recomparer(bigint, bigint[])'::regprocedure)) = 0
     OR position('ingest.fn_h21_exemplaires_a_lire(' IN
              pg_get_functiondef('public.fn_import_row_comparison(bigint, bigint)'::regprocedure)) = 0
     OR NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid = 'public.fn_import_list_run_rows(bigint)'::regprocedure
                     AND (p.proargnames)[array_length(p.proargnames, 1)] = 'exemplaires_maj')
     OR position('prepared_item_updates' IN pg_get_functiondef('public.fn_batch_review_report(bigint)'::regprocedure)) = 0
     OR position('and x.import_update is null' IN pg_get_functiondef('public.fn_batch_review_report(bigint)'::regprocedure)) = 0
     OR position('error.import.item_update_not_mergeable' IN pg_get_functiondef('api.merge_book_drafts(bigint, bigint, jsonb)'::regprocedure)) = 0 THEN
    v_e := v_e || ' portes';
  END IF;
  -- le jugement emploie chacune des raisons déclarées (et l'écran les mêmes)
  v_def := pg_get_functiondef('ingest.fn_h21_preparer_exemplaires(bigint, bigint[], uuid, uuid, bigint)'::regprocedure);
  FOREACH v_f IN ARRAY ARRAY['signale', 'pas_au_catalogue', 'rejetee', 'autre_bibliotheque', 'deja_preparee',
                             'brouillon_en_cours', 'sans_base', 'rien_a_appliquer'] LOOP
    IF position('then ''' || v_f || '''' IN v_def) = 0 THEN v_e := v_e || ' raison(' || v_f || ')'; END IF;
  END LOOP;
  -- la copie : toutes les colonnes qu'écrit la branche update de la
  -- publication (et la trace du lot 6a) — « une colonne = tous les endroits »
  v_def := pg_get_functiondef('ingest.fn_h21_preparer_exemplaires(bigint, bigint[], uuid, uuid, bigint)'::regprocedure);
  SELECT string_agg(c.column_name, ',' ORDER BY c.column_name) INTO v_f
    FROM information_schema.columns c
   WHERE c.table_schema = 'public' AND c.table_name = 'exemplares'
     AND c.column_name NOT IN ('id', 'created_at', 'updated_at', 'bib_ref')
     AND v_def !~ ('\me\.' || c.column_name || '\M');
  IF v_f IS NOT NULL THEN
    v_e := v_e || ' copie(' || v_f || ')';
  END IF;
  -- droits : portes authenticated inchangées, fermées à anon ; aides fermées
  FOREACH v_f IN ARRAY ARRAY[
    'public.fn_import_preparer_mises_a_jour(bigint, bigint[])', 'public.fn_import_recomparer(bigint, bigint[])',
    'public.fn_import_row_comparison(bigint, bigint)', 'public.fn_import_list_run_rows(bigint)',
    'public.fn_batch_review_report(bigint)', 'public.publish_exemplar_draft(bigint)'] LOOP
    IF NOT has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0) THEN
      v_e := v_e || ' droits-portes(' || v_f || ')';
    END IF;
  END LOOP;
  -- api.merge_book_drafts : ses droits d'avant (authenticated, pas anon ; pas
  -- de droit service_role, inchangé)
  IF NOT has_function_privilege('authenticated', 'api.merge_book_drafts(bigint, bigint, jsonb)', 'EXECUTE')
     OR has_function_privilege('anon', 'api.merge_book_drafts(bigint, bigint, jsonb)', 'EXECUTE') THEN
    v_e := v_e || ' droits-portes(api.merge_book_drafts)';
  END IF;
  FOREACH v_f IN ARRAY ARRAY[
    'ingest.fn_h21_champs_exemplaire()', 'ingest.fn_h21_n_exemplaire(jsonb)',
    'ingest.fn_h21_item_de_la_ligne(bigint, text)', 'ingest.fn_h21_empreinte_exemplaire(bigint)',
    'ingest.fn_h21_empreinte_hors_patch(bigint)', 'ingest.fn_h21_empreinte_base_exemplaire(bigint)',
    'ingest.fn_h21_exemplaire_visible(bigint)', 'ingest.fn_h21_poser_base_exemplaire(bigint, bigint, text)',
    'ingest.fn_h21_reprendre_les_bases_exemplaires()', 'ingest.fn_h21_exemplaires_trois_etats(bigint)',
    'ingest.fn_h21_exemplaires_trois_etats_lot(bigint, bigint[])',
    'ingest.fn_h21_exemplaires_par_appel()', 'ingest.fn_h21_garde_plafond_exemplaires(bigint, bigint[])',
    'ingest.fn_h21_stocker_comparaisons_exemplaires(bigint, bigint[])',
    'ingest.fn_h21_exemplaires_maj(bigint, jsonb, bigint, boolean)', 'ingest.fn_h21_exemplaires_a_lire(jsonb)',
    'ingest.fn_h21_preparer_exemplaires(bigint, bigint[], uuid, uuid, bigint)',
    'ingest.fn_h21_garde_mise_a_jour_exemplaire(bigint, boolean)',
    'ingest.fn_h21_avancer_base_exemplaire(bigint, bigint)'] LOOP
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0) THEN
      v_e := v_e || ' droits-internes(' || v_f || ')';
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_proc p
              WHERE p.oid IN ('public.fn_import_preparer_mises_a_jour(bigint, bigint[])'::regprocedure,
                              'public.fn_import_recomparer(bigint, bigint[])'::regprocedure,
                              'public.fn_import_row_comparison(bigint, bigint)'::regprocedure,
                              'public.fn_import_list_run_rows(bigint)'::regprocedure,
                              'public.fn_batch_review_report(bigint)'::regprocedure,
                              'public.publish_exemplar_draft(bigint)'::regprocedure,
                              'api.merge_book_drafts(bigint, bigint, jsonb)'::regprocedure,
                              'ingest.fn_h21_preparer_exemplaires(bigint, bigint[], uuid, uuid, bigint)'::regprocedure,
                              'ingest.fn_h21_garde_mise_a_jour_exemplaire(bigint, boolean)'::regprocedure,
                              'ingest.fn_h21_avancer_base_exemplaire(bigint, bigint)'::regprocedure,
                              'ingest.fn_h21_exemplaires_trois_etats(bigint)'::regprocedure)
                AND (NOT p.prosecdef OR coalesce(p.proconfig::text, '') NOT LIKE '%search_path%')) THEN
    v_e := v_e || ' definer';
  END IF;

  IF v_e <> '' THEN
    RAISE EXCEPTION 'H21 lot 6b : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'H21 lot 6b : vérifications OK';
END
$h21l6b_verif$;

NOTIFY pgrst, 'reload schema';
