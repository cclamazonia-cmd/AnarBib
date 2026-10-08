-- =====================================================================
-- H21 lot 6a — reconnaître les exemplaires d'un réimport
-- (REGISTRE IMP-21 b/d, IMP-23 a, IMP-26 e, IMP-27 d, IMP-28 c, IMP-31,
-- IMP-32 ; IMP-33, décisions de Xavier du 08/10/2026 ; fiches H21, H19, H24)
--
-- Décisions de Xavier du 08/10/2026 (IMP-33) :
--  (a) CLÉ : le code-barres (995 $f) reste la clé ; l'identifiant interne de
--      PMB (996 $9 expl_id, désormais lu par l'edge function) est un SECOND
--      signal : code-barres changé à expl_id égal → signalé « réétiqueté »,
--      jamais appliqué d'office.
--  (b) SANS CODE : signalé, jamais ajouté d'office.
--  (c) Cote / note changées : lot 6b (base, trois états, brouillon soumis à
--      révision) — CE LOT NE COMPARE NI N'APPLIQUE AUCUN CHAMP D'EXEMPLAIRE.
--  (d) DÉPLACÉ d'une notice à une autre dans PMB : signalé seulement
--      (« déplacé dans PMB vers <notice> »), jamais déplacé.
-- Tranchés par la spécification (prudents) : un exemplaire déplacé vers une
-- notice NOUVELLE du fichier est écarté des brouillons de cette notice et
-- signalé (la notice se publie) ; une ligne reconnue dont tous les
-- exemplaires sont déjà là n'est rejetée d'office que si elle n'apporte RIEN ;
-- chaque exemplaire porte sa source et son run (prérequis du lot 7) ; le
-- rapprochement rejoint le lot ouvert du run (IMP-27 d) ; localisation,
-- statut, type, public restent hors du lot (IMP-21 d).
--
-- 1. COLONNES (trace d'import, que l'API ne pose jamais) :
--    public.exemplares et public.exemplar_drafts reçoivent
--      source_item_id   text    l'identifiant interne à la source (expl_id) ;
--      import_source_id bigint  → ingest.partner_catalog_sources  ON DELETE SET NULL ;
--      import_run_id    bigint  → ingest.partner_catalog_import_runs ON DELETE SET NULL ;
--    un index par clé étrangère (garde « FK sans index ») ; unicité partielle
--    (library_id, import_source_id, source_item_id) sur exemplares — revue
--    sceptique du 08/10 : un identifiant appartient au PMB qui l'a émis, et un
--    PMB est une source (IMP-28 c, IMP-33 a) ; les expl_id de PMB repartent de
--    1 dans chaque installation, deux PMB qui alimentent la même bibliothèque
--    se marcheraient dessus. Le code-barres, lui, reste unique PAR
--    BIBLIOTHÈQUE, toutes sources confondues (exemplares_source_item_code_par_biblio) ;
--    index de recherche (target_library_id, source_item_id) sur les brouillons.
--    Un exemplaire dont la source a été supprimée (import_source_id remis à
--    NULL par la clé étrangère) garde son expl_id, qui ne sert plus de signal
--    (ni constat, ni unicité, ni garde).
--    ingest.partner_catalog_staging_rows.exemplaires_constat jsonb (objet) :
--    le constat de la ligne (3).
--    Reprise : les brouillons d'exemplaire importés reçoivent run et source par
--    leur ligne (import_staging_row_id), l'identifiant par l'exemplaire du
--    fichier au même code ; les exemplaires publiés les reçoivent de leur
--    brouillon publié (unicité respectée). En production le 08/10 : 0
--    exemplaire à code d'origine, 0 brouillon d'exemplaire importé.
--
-- 2. QUI ÉCRIT CES COLONNES (règle « une colonne = tous les endroits ») :
--    - ingest.fn_create_item_drafts_for_batch (promotion) et
--      ingest.fn_create_exemplar_drafts_from_import_rows (« Rapprocher ») les
--      posent sur le brouillon ;
--    - public.publish_exemplar_draft les recopie : branche création (les deux
--      INSERT, celui du repli de tombo compris) ET branche republication
--      (coalesce : un brouillon qui ne les porte pas ne les efface jamais) ;
--      et refuse un identifiant interne déjà pris dans la bibliothèque
--      (error.publish.source_item_id_taken), comme le code
--      (error.publish.source_item_code_taken) — sans quoi 23505 brut ;
--    - public.fn_restore_deleted_draft (rejeu du journal) : l'instantané les
--      porte (c'est le même brouillon) ; une source ou un run disparus depuis :
--      le lien seul tombe (ingest.fn_h21_trace_exemplaire_rejouable), sinon
--      23503 brut.
--    Copies et reprises qui NE les recopient PAS (choix) :
--    - create_exemplar_draft_from_exemplar (« Éditer » un exemplaire) ne
--      recopie pas plus le code d'origine qu'avant : la republication garde
--      ceux de l'exemplaire (coalesce) ;
--    - api.attach_exemplar (exemplaire saisi à la main) : aucune trace ;
--    - réattribution (network_admin_reassign_book_to_library,
--      _from_to_library, fn_batch_reassign_library), fusion de notices
--      (fn_fusion_notices), absorptions (api.merge_*) : des UPDATE qui ne
--      touchent pas ces colonnes — l'exemplaire GARDE sa trace, comme il
--      garde son code d'origine depuis H19 (QUESTION OUVERTE, à Xavier :
--      IMP-28 c dit qu'un identifiant appartient à la bibliothèque dont le PMB
--      l'a émis ; un exemplaire réattribué emporte aujourd'hui code et
--      expl_id dans la bibliothèque cible, où ils peuvent heurter ceux de son
--      propre PMB — refus dit à la publication, jamais d'écriture).
--    L'API ne les pose pas : public.tg_exemplar_drafts_import_links_locked
--    (INSERT ET UPDATE, current_user authenticated ou anon) refuse
--    (error.import.item_trace_reserved) ; public.exemplares n'a aucune politique
--    d'écriture pour l'API (RLS : lecture seule) — vérifié par la suite.
--
-- 3. LE CONSTAT, une fonction unique : ingest.fn_h21_constat_exemplaire(
--    bibliothèque importatrice, notice de la ligne, code, expl_id) → verdict,
--    TOUJOURS par la bibliothèque importatrice
--    (ingest.fn_h21_bibliotheque_importatrice — IMP-28 c) ; le CODE se compare
--    à tous les exemplaires et brouillons vivants de la bibliothèque (un nouvel
--    export du même PMB déposé comme nouvelle source est reconnu par le code,
--    IMP-28 a), l'EXPL_ID seulement à ceux de la MÊME SOURCE (revue sceptique) ;
--    dans cet ordre :
--      sans_code          pas de code-barres (même avec un expl_id) ;
--      code_repris        même code qu'un exemplaire de la bibliothèque venu de
--                         la MÊME source, mais son expl_id diffère, ou l'expl_id
--                         du fichier est celui d'un AUTRE exemplaire de la
--                         source : un autre exemplaire PMB a repris le code ;
--      deplace            même code (sans contradiction), sur une AUTRE notice
--                         que celle de la ligne — toujours, pour une notice
--                         nouvelle (promotion) ;
--      deja_la            même code, sans contradiction, sur la notice de la
--                         ligne ;
--      reetiquete         code inconnu, expl_id égal à celui d'un exemplaire de
--                         la même source : ancien code → nouveau ;
--      deja_en_brouillon  un brouillon VIVANT (brouillon, prêt) de la même
--                         bibliothèque porte ce code, ou cet expl_id de la même
--                         source ;
--      nouveau            sinon — SEUL verdict qui crée un brouillon.
--    Le constat de chaque exemplaire du fichier est posé sur la ligne
--    (exemplaires_constat : version, via promotion|rapprochement, date, run,
--    bibliothèque, notice, lot ; items[] : n, code, expl_id, cote, verdict,
--    exemplaire, tombo et notice trouvés, ancien code, autre expl_id,
--    brouillon trouvé, brouillon créé). Aucune écriture sur un exemplaire
--    existant, ni sur sa notice, son fonds, sa circulation. Les exemplaires
--    d'une même ligne sont constatés l'un après l'autre : un code présent deux
--    fois dans la ligne donne un brouillon, puis « déjà en brouillon ».
--    Un verrou d'avis par bibliothèque (pg_advisory_xact_lock) sérialise les
--    constats concurrents (deux runs de la même bibliothèque).
--
-- 4. « Rapprocher » (fn_create_exemplar_drafts_from_import_rows, définition
--    VIVANTE par ancres) : le constat ; seul « nouveau » crée un brouillon
--    (avec code, expl_id, source, run), dans le LOT OUVERT DU RUN
--    (ingest.fn_h21_lot_ouvert_du_run : lot ouvert de la bibliothèque, lié au
--    run par une promotion, une mise à jour ou un rapprochement, sans
--    révision demandée ni approuvée — sinon un lot neuf, créé au PREMIER
--    brouillon : plus jamais de lot vide créé puis supprimé, ni de lot
--    existant supprimé). Une ligne d'un format qui ne décrit jamais
--    d'exemplaire (CSV, RIS : pas de raw_payload.item_tag) garde l'exemplaire
--    implicite d'avant (H19), un seul. Revue sceptique du 08/10 : une ligne
--    MARC lue AVEC sa zone d'exemplaire (raw_payload.item_tag, le critère
--    d'IMP-25 dans publish_book_draft) qui n'en décrit aucun n'en reçoit pas —
--    sans quoi chaque réimport en ajoutait un ; elle n'apporte rien : rejetée
--    d'office (note au même préfixe, « o arquivo nao descreve nenhum exemplar »).
--    La promotion n'a pas ce trou : elle ne crée que des exemplaires du fichier,
--    et publish_book_draft ne pose l'automatique que sans item_tag (IMP-25).
--    La ligne reconnue n'est rejetée d'office (note d'avant, que
--    ingest.fn_h21_rejet_par_choix reconnaît : texte INCHANGÉ) que si elle
--    n'apporte RIEN : tous ses exemplaires déjà là ou déjà en brouillon. Un
--    signal (sans code, déplacé, réétiqueté, code repris) la laisse « Accepté
--    (rattaché) » — décision accept_duplicate, revue approuvée, plus
--    sélectionnée —, sans brouillon : elle ne bloque rien (les compteurs du run
--    ne comptent que les notices créées ; « Retraiter » n'est retenu que par un
--    brouillon ; « Préparer la mise à jour » la traite comme toute ligne
--    reconnue non rejetée ; un nouveau « Rapprocher » la reconstate, sans rien
--    créer de plus). Deux « Rapprocher » successifs ne font qu'un brouillon
--    (déjà en brouillon). Rendu : comptes par verdict (verdicts), lignes
--    signalées (rows_signalled), lot rejoint (batch_joined) ; le constat
--    désigne le lot du rapprochement, sinon (rien créé) le lot ouvert du run
--    s'il existe (sans en ouvrir) : le rapport de révision le montre ; les clés d'avant
--    restent (items_skipped_code_taken = déjà là). Plus jamais d'exception
--    « Aucun brouillon d'exemplaire créé » : rien à créer se dit.
--
-- 5. Promotion (fn_create_item_drafts_for_batch, définition VIVANTE) : le
--    même constat, notice NOUVELLE (aucune notice de ligne) : déplacé,
--    réétiqueté, code repris, déjà là (impossible ici), déjà en brouillon,
--    sans code n'entrent pas dans les brouillons de la notice, qui se publie
--    (IMP-25 : un fichier MARC à zone d'exemplaire ne reçoit pas
--    d'exemplaire automatique).
--
-- 6. Corbeille : sortir de la corbeille un brouillon d'exemplaire dont le
--    code ou l'expl_id est désormais pris par un exemplaire ou un brouillon
--    vivant de la même bibliothèque est refusé
--    (error.import.item_restore_code_taken), par un déclencheur
--    (exemplar_drafts_zx_code_libre_au_retour, BEFORE UPDATE OF status,
--    après les autres déclencheurs de même nom) ; la notice restaurée de la
--    corbeille ne ramène pas un tel exemplaire (il y reste,
--    tg_book_drafts_imported_items_follow) ; le rejeu du journal refuse un
--    exemplaire vivant ainsi pris (même HINT) et, rejouant une notice, laisse
--    à la corbeille avec elle ses exemplaires pris.
--
-- 7. Lire : public.fn_import_list_run_rows (DROP + CREATE : une colonne de
--    plus, exemplaires jsonb — le constat, sinon la liste des exemplaires du
--    fichier sans verdict ; titre de la notice où l'exemplaire est trouvé) ;
--    public.fn_batch_review_report (définition VIVANTE) : section
--    items_set_aside, les exemplaires du fichier écartés pour ce lot et
--    pourquoi (40 exemples, comptes sur tout).
--
-- 8. Profil d'import : public.fn_import_profile_create accepte id_tag (zone à
--    3 chiffres ou ''), id_code (une sous-zone ou ''), id_prefix (32
--    caractères sans espace au plus) — la correspondance de l'identifiant,
--    défaut 996 / 9 / « expl_id: » (correspondance.ts) ; l'écran du profil
--    ne les montre pas encore.
--
-- HORS DE CE LOT (choix prudents, signalés au rapport) : aucun champ
-- d'exemplaire comparé ni appliqué (6b) ; publish_book_draft inchangée — un
-- exemplaire « nouveau » à la promotion dont le code est pris ENTRE la
-- promotion et la publication fait encore refuser la publication de sa
-- notice (refus dit, codigo_de_origem_ja_usado), comme avant ; l'export
-- (H24, 995 $f depuis source_item_code) inchangé ; la couverture (996 reste
-- « laissée » : seul son identifiant est lu).
--
-- Méthode : chaque fonction existante est modifiée SUR SA DÉFINITION VIVANTE
-- (pg_get_functiondef, retours chariot retirés) par ancres comptées ;
-- fn_import_list_run_rows seule change de type de retour (DROP + CREATE,
-- droits restaurés) ; vérification structurelle finale. md5 de prosrc lus le
-- 08/10/2026 en production (MCP, lecture seule) et sur le banc reconstruit
-- depuis le dépôt (identiques) :
--   ingest.fn_create_exemplar_drafts_from_import_rows  4c2d96ed877a0ff764fe1eb2b6fff9b7
--   ingest.fn_create_item_drafts_for_batch             14665764a13b8bfec89ea53439f52e22
--   public.publish_exemplar_draft                      6111a309c922ba5f8258e09d140271f8
--   public.tg_exemplar_drafts_import_links_locked      e3d5f8447a45044344be52da543c35d3
--   public.tg_book_drafts_imported_items_follow        b8837c0260cb7f1a49257e14f1b06bf9
--   public.fn_restore_deleted_draft                    c57d64b6a70fcad975ace4d052754ed4
--   public.fn_batch_review_report                      a17bb1782b1167f735fb58d7cbec33f4
--   public.fn_import_list_run_rows                     6e817a0cd8774578dfe88b1f1c75f8f3
--   public.fn_import_profile_create                    c9d36e54e511ba64b497b874e1ef24ed
-- Suite : tests/sql/h21_lot6a_exemplaires_tests.sql.
-- =====================================================================

-- Outils de la migration, éphémères (pg_temp).
CREATE OR REPLACE FUNCTION pg_temp.h21l6_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'H21 lot 6a — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN
    RAISE EXCEPTION 'H21 lot 6a — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

-- Remplace tout ce qui va de p_debut à p_fin (inclus) ; chacun présent une fois.
CREATE OR REPLACE FUNCTION pg_temp.h21l6_remplacer_entre(p_quoi text, p_def text, p_debut text, p_fin text, p_new text)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_i int; v_j int;
BEGIN
  IF (length(p_def) - length(replace(p_def, p_debut, ''))) / length(p_debut) <> 1
     OR (length(p_def) - length(replace(p_def, p_fin, ''))) / length(p_fin) <> 1 THEN
    RAISE EXCEPTION 'H21 lot 6a — % : bornes absentes ou répétées — relire la définition réelle', p_quoi;
  END IF;
  v_i := position(p_debut IN p_def);
  v_j := position(p_fin IN p_def) + length(p_fin);
  IF v_j <= v_i THEN
    RAISE EXCEPTION 'H21 lot 6a — % : bornes dans le désordre', p_quoi;
  END IF;
  RETURN substr(p_def, 1, v_i - 1) || p_new || substr(p_def, v_j);
END
$f$;

CREATE OR REPLACE FUNCTION pg_temp.h21l6_def(p_fn regprocedure)
RETURNS text LANGUAGE sql AS $f$
  SELECT replace(pg_get_functiondef(p_fn), E'\r', '');
$f$;


-- ─────────────────────────────────────────────────────────────────────
-- 1. Colonnes, index, contraintes
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE public.exemplares
  ADD COLUMN IF NOT EXISTS source_item_id text,
  ADD COLUMN IF NOT EXISTS import_source_id bigint,
  ADD COLUMN IF NOT EXISTS import_run_id bigint;
ALTER TABLE public.exemplar_drafts
  ADD COLUMN IF NOT EXISTS source_item_id text,
  ADD COLUMN IF NOT EXISTS import_source_id bigint,
  ADD COLUMN IF NOT EXISTS import_run_id bigint;
ALTER TABLE ingest.partner_catalog_staging_rows
  ADD COLUMN IF NOT EXISTS exemplaires_constat jsonb;

ALTER TABLE public.exemplares DROP CONSTRAINT IF EXISTS exemplares_import_source_id_fkey;
ALTER TABLE public.exemplares ADD CONSTRAINT exemplares_import_source_id_fkey
  FOREIGN KEY (import_source_id) REFERENCES ingest.partner_catalog_sources(id) ON DELETE SET NULL;
ALTER TABLE public.exemplares DROP CONSTRAINT IF EXISTS exemplares_import_run_id_fkey;
ALTER TABLE public.exemplares ADD CONSTRAINT exemplares_import_run_id_fkey
  FOREIGN KEY (import_run_id) REFERENCES ingest.partner_catalog_import_runs(id) ON DELETE SET NULL;
ALTER TABLE public.exemplar_drafts DROP CONSTRAINT IF EXISTS exemplar_drafts_import_source_id_fkey;
ALTER TABLE public.exemplar_drafts ADD CONSTRAINT exemplar_drafts_import_source_id_fkey
  FOREIGN KEY (import_source_id) REFERENCES ingest.partner_catalog_sources(id) ON DELETE SET NULL;
ALTER TABLE public.exemplar_drafts DROP CONSTRAINT IF EXISTS exemplar_drafts_import_run_id_fkey;
ALTER TABLE public.exemplar_drafts ADD CONSTRAINT exemplar_drafts_import_run_id_fkey
  FOREIGN KEY (import_run_id) REFERENCES ingest.partner_catalog_import_runs(id) ON DELETE SET NULL;
ALTER TABLE ingest.partner_catalog_staging_rows DROP CONSTRAINT IF EXISTS partner_catalog_staging_rows_exemplaires_constat_objet;
ALTER TABLE ingest.partner_catalog_staging_rows ADD CONSTRAINT partner_catalog_staging_rows_exemplaires_constat_objet
  CHECK (exemplaires_constat IS NULL OR jsonb_typeof(exemplaires_constat) = 'object');
ALTER TABLE public.exemplares DROP CONSTRAINT IF EXISTS exemplares_source_item_id_non_vide;
ALTER TABLE public.exemplares ADD CONSTRAINT exemplares_source_item_id_non_vide
  CHECK (source_item_id IS NULL OR btrim(source_item_id) <> '');

CREATE INDEX IF NOT EXISTS exemplares_import_source_id_idx ON public.exemplares (import_source_id);
CREATE INDEX IF NOT EXISTS exemplares_import_run_id_idx ON public.exemplares (import_run_id);
CREATE INDEX IF NOT EXISTS exemplar_drafts_import_source_id_idx ON public.exemplar_drafts (import_source_id);
CREATE INDEX IF NOT EXISTS exemplar_drafts_import_run_id_idx ON public.exemplar_drafts (import_run_id);
CREATE INDEX IF NOT EXISTS exemplar_drafts_source_item_id_idx ON public.exemplar_drafts (target_library_id, source_item_id)
  WHERE source_item_id IS NOT NULL;

COMMENT ON COLUMN public.exemplares.source_item_id IS
  'H21 lot 6a (IMP-33 a) : identifiant interne de l''exemplaire à la source (PMB : 996 $9 expl_id), unique par bibliothèque ; second signal du réimport (le code-barres, source_item_code, reste la clé). Trace d''import : jamais posée par l''API.';
COMMENT ON COLUMN public.exemplares.import_source_id IS
  'H21 lot 6a : la source d''import qui a créé l''exemplaire (prérequis du retrait, lot 7). Trace d''import.';
COMMENT ON COLUMN public.exemplares.import_run_id IS
  'H21 lot 6a : le run d''import qui a créé l''exemplaire. Trace d''import.';
COMMENT ON COLUMN public.exemplar_drafts.source_item_id IS
  'H21 lot 6a : identifiant interne de l''exemplaire à la source, recopié par publish_exemplar_draft. Posé par l''import seul.';
COMMENT ON COLUMN ingest.partner_catalog_staging_rows.exemplaires_constat IS
  'H21 lot 6a (IMP-33) : le constat des exemplaires du fichier de cette ligne (ingest.fn_h21_constat_exemplaire), posé par la promotion et par « Rapprocher » : un verdict par exemplaire (nouveau, deja_la, deja_en_brouillon, sans_code, deplace, reetiquete, code_repris).';


-- ─────────────────────────────────────────────────────────────────────
-- 2. Reprise des données (en production le 08/10 : rien à reprendre)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6_reprise$
DECLARE v_n int;
BEGIN
  -- Les horodatages et l'état « reprise intacte » des brouillons ne bougent pas.
  PERFORM set_config('anarbib.skip_touch_updated_at', 'on', true);
  UPDATE public.exemplar_drafts x
     SET import_run_id = sr.run_id, import_source_id = r.source_id
    FROM ingest.partner_catalog_staging_rows sr
    JOIN ingest.partner_catalog_import_runs r ON r.id = sr.run_id
   WHERE sr.id = x.import_staging_row_id
     AND x.import_run_id IS NULL AND x.import_source_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'H21 lot 6a reprise : % brouillon(s) d''exemplaire relié(s) à leur run', v_n;
  UPDATE public.exemplar_drafts x
     SET source_item_id = t.id_source
    FROM (SELECT x2.id,
                 (SELECT nullif(btrim(i.v->>'source_item_id'), '')
                    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(sr.normalized_payload->'items') = 'array'
                                                   THEN sr.normalized_payload->'items' ELSE '[]'::jsonb END) i(v)
                   WHERE btrim(i.v->>'source_item_code') = x2.source_item_code
                   LIMIT 1) AS id_source
            FROM public.exemplar_drafts x2
            JOIN ingest.partner_catalog_staging_rows sr ON sr.id = x2.import_staging_row_id
           WHERE x2.source_item_code IS NOT NULL AND x2.source_item_id IS NULL) t
   WHERE t.id = x.id AND t.id_source IS NOT NULL;
  -- Les exemplaires publiés : depuis leur dernier brouillon publié ;
  -- l'identifiant seulement s'il reste unique dans la bibliothèque pour sa source.
  WITH d AS (
    SELECT DISTINCT ON (x.published_exemplar_id) x.published_exemplar_id AS eid,
           x.source_item_id, x.import_source_id, x.import_run_id
      FROM public.exemplar_drafts x
     WHERE x.published_exemplar_id IS NOT NULL AND x.status = 'published'
       AND (x.import_run_id IS NOT NULL OR x.source_item_id IS NOT NULL)
     ORDER BY x.published_exemplar_id, x.id DESC
  ), c AS (
    SELECT d.*, e.library_id,
           count(*) OVER (PARTITION BY e.library_id, d.import_source_id, d.source_item_id) AS n_meme
      FROM d JOIN public.exemplares e ON e.id = d.eid
     WHERE e.import_run_id IS NULL AND e.import_source_id IS NULL AND e.source_item_id IS NULL
  )
  UPDATE public.exemplares e
     SET import_run_id = c.import_run_id, import_source_id = c.import_source_id,
         source_item_id = CASE WHEN c.source_item_id IS NOT NULL AND c.n_meme = 1
                                    AND NOT EXISTS (SELECT 1 FROM public.exemplares o
                                                     WHERE o.library_id = c.library_id AND o.import_source_id = c.import_source_id
                                                       AND o.source_item_id = c.source_item_id)
                               THEN c.source_item_id END
    FROM c WHERE e.id = c.eid;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'H21 lot 6a reprise : % exemplaire(s) relié(s) à leur import', v_n;
  PERFORM set_config('anarbib.skip_touch_updated_at', '', true);
END
$h21l6_reprise$;

CREATE UNIQUE INDEX IF NOT EXISTS exemplares_source_item_id_par_source
  ON public.exemplares (library_id, import_source_id, source_item_id)
  WHERE source_item_id IS NOT NULL AND import_source_id IS NOT NULL;


-- ─────────────────────────────────────────────────────────────────────
-- 3. Le constat (une fonction unique) et ses aides
-- ─────────────────────────────────────────────────────────────────────
-- Le code (dans la bibliothèque) ou l'identifiant (dans la bibliothèque, pour la
-- même source ; sans source : aucun signal) est-il pris par un exemplaire ou par
-- un brouillon VIVANT (hors le brouillon et l'exemplaire donnés) ?
CREATE OR REPLACE FUNCTION ingest.fn_h21_exemplaire_pris(
  p_library uuid, p_code text, p_item_id text, p_source bigint,
  p_sauf_brouillon bigint DEFAULT NULL, p_sauf_exemplaire bigint DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql STABLE
SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
DECLARE
  v_code text := nullif(btrim(coalesce(p_code, '')), '');
  -- l'expl_id n'est un signal qu'avec sa source (un PMB = une source)
  v_id text := CASE WHEN p_source IS NOT NULL THEN nullif(btrim(coalesce(p_item_id, '')), '') END;
BEGIN
  IF p_library IS NULL OR (v_code IS NULL AND v_id IS NULL) THEN
    RETURN false;
  END IF;
  RETURN EXISTS (SELECT 1 FROM public.exemplares e
                  WHERE e.library_id = p_library AND e.source_item_code = v_code
                    AND e.id IS DISTINCT FROM p_sauf_exemplaire)
      OR EXISTS (SELECT 1 FROM public.exemplares e
                  WHERE e.library_id = p_library AND e.import_source_id = p_source AND e.source_item_id = v_id
                    AND e.id IS DISTINCT FROM p_sauf_exemplaire)
      OR EXISTS (SELECT 1 FROM public.exemplar_drafts y
                  WHERE y.status IN ('draft', 'ready') AND y.id IS DISTINCT FROM p_sauf_brouillon
                    AND y.target_library_id = p_library
                    AND (y.source_item_code = v_code OR (y.import_source_id = p_source AND y.source_item_id = v_id)))
      OR EXISTS (SELECT 1 FROM public.exemplar_drafts y
                  WHERE y.status IN ('draft', 'ready') AND y.id IS DISTINCT FROM p_sauf_brouillon
                    AND y.target_library_id IS NULL AND y.book_draft_id IS NOT NULL
                    AND (y.source_item_code = v_code OR (y.import_source_id = p_source AND y.source_item_id = v_id))
                    AND public.fn_book_draft_library(y.book_draft_id) = p_library);
END
$function$;
REVOKE ALL ON FUNCTION ingest.fn_h21_exemplaire_pris(uuid, text, text, bigint, bigint, bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_h21_exemplaire_pris(uuid, text, text, bigint, bigint, bigint) TO service_role;

-- Le verdict d'UN exemplaire du fichier (voir l'en-tête, 3). p_source : la
-- source du fichier (l'expl_id ne se compare qu'à elle) ; p_book_id : la
-- notice de la ligne (rapprochement), NULL pour une notice nouvelle
-- (promotion). Lecture seule.
CREATE OR REPLACE FUNCTION ingest.fn_h21_constat_exemplaire(
  p_library uuid, p_source bigint, p_book_id bigint, p_code text, p_item_id text)
RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
DECLARE
  v_code text := nullif(btrim(coalesce(p_code, '')), '');
  -- l'expl_id n'est un signal qu'avec sa source (un PMB = une source)
  v_id text := CASE WHEN p_source IS NOT NULL THEN nullif(btrim(coalesce(p_item_id, '')), '') END;
  c_id bigint; c_tombo text; c_code text; c_xid text; c_book bigint;   -- trouvé par le code
  c_src bigint;
  x_id bigint; x_tombo text; x_code text; x_xid text; x_book bigint;   -- trouvé par l'expl_id
  v_draft bigint;
BEGIN
  IF v_code IS NULL THEN
    RETURN jsonb_build_object('verdict', 'sans_code');
  END IF;
  IF p_library IS NULL THEN
    -- sans bibliothèque (dépôt sans destination) : rien à comparer ; la
    -- publication refusera l'exemplaire (exemplar_importado_sem_biblioteca)
    RETURN jsonb_build_object('verdict', 'nouveau', 'sans_bibliotheque', true);
  END IF;
  SELECT e.id, e.tombo, e.source_item_code, e.source_item_id, e.import_source_id,
         coalesce(h.book_id, (SELECT b.id FROM public.books b WHERE b.bib_ref = e.bib_ref ORDER BY b.id LIMIT 1))
    INTO c_id, c_tombo, c_code, c_xid, c_src, c_book
    FROM public.exemplares e
    LEFT JOIN public.book_holdings h ON h.id = e.holding_id
   WHERE e.library_id = p_library AND e.source_item_code = v_code;
  IF v_id IS NOT NULL THEN
    SELECT e.id, e.tombo, e.source_item_code, e.source_item_id,
           coalesce(h.book_id, (SELECT b.id FROM public.books b WHERE b.bib_ref = e.bib_ref ORDER BY b.id LIMIT 1))
      INTO x_id, x_tombo, x_code, x_xid, x_book
      FROM public.exemplares e
      LEFT JOIN public.book_holdings h ON h.id = e.holding_id
     WHERE e.library_id = p_library AND e.import_source_id = p_source AND e.source_item_id = v_id;
  END IF;
  IF c_id IS NOT NULL THEN
    -- même code : contradiction de l'expl_id (de la MÊME source) ? un autre
    -- exemplaire PMB a repris le code ; venu d'une autre source, l'expl_id de
    -- l'exemplaire ne dit rien (un nouvel export du même PMB, nouvelle source)
    IF v_id IS NOT NULL AND ((c_xid IS NOT NULL AND c_src = p_source AND c_xid <> v_id) OR (x_id IS NOT NULL AND x_id <> c_id)) THEN
      RETURN jsonb_build_object('verdict', 'code_repris', 'exemplar_id', c_id, 'tombo', c_tombo, 'book_id', c_book,
                                'autre_expl_id', CASE WHEN c_src = p_source THEN c_xid END)
             || CASE WHEN x_id IS NOT NULL AND x_id <> c_id
                     THEN jsonb_build_object('exemplar_id_expl', x_id, 'tombo_expl', x_tombo, 'code_expl', x_code)
                     ELSE '{}'::jsonb END;
    END IF;
    IF p_book_id IS NULL OR c_book IS DISTINCT FROM p_book_id THEN
      RETURN jsonb_build_object('verdict', 'deplace', 'exemplar_id', c_id, 'tombo', c_tombo, 'book_id', c_book);
    END IF;
    RETURN jsonb_build_object('verdict', 'deja_la', 'exemplar_id', c_id, 'tombo', c_tombo, 'book_id', c_book);
  END IF;
  IF x_id IS NOT NULL THEN
    -- l'expl_id est connu sous un autre code : réétiqueté dans PMB
    RETURN jsonb_build_object('verdict', 'reetiquete', 'exemplar_id', x_id, 'tombo', x_tombo, 'book_id', x_book,
                              'ancien_code', x_code);
  END IF;
  SELECT y.id INTO v_draft FROM public.exemplar_drafts y
   WHERE y.status IN ('draft', 'ready') AND y.target_library_id = p_library
     AND (y.source_item_code = v_code OR (v_id IS NOT NULL AND y.import_source_id = p_source AND y.source_item_id = v_id))
   ORDER BY y.id LIMIT 1;
  IF v_draft IS NULL THEN
    SELECT y.id INTO v_draft FROM public.exemplar_drafts y
     WHERE y.status IN ('draft', 'ready') AND y.target_library_id IS NULL AND y.book_draft_id IS NOT NULL
       AND (y.source_item_code = v_code OR (v_id IS NOT NULL AND y.import_source_id = p_source AND y.source_item_id = v_id))
       AND public.fn_book_draft_library(y.book_draft_id) = p_library
     ORDER BY y.id LIMIT 1;
  END IF;
  IF v_draft IS NOT NULL THEN
    RETURN jsonb_build_object('verdict', 'deja_en_brouillon', 'draft_id', v_draft);
  END IF;
  RETURN jsonb_build_object('verdict', 'nouveau');
END
$function$;
REVOKE ALL ON FUNCTION ingest.fn_h21_constat_exemplaire(uuid, bigint, bigint, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_h21_constat_exemplaire(uuid, bigint, bigint, text, text) TO service_role;

-- Le lot ouvert du run (IMP-27 d) : lot ouvert de la bibliothèque, lié au run
-- par une promotion ou une mise à jour (row_to_draft) OU par un rapprochement
-- (brouillons d'exemplaire de ses lignes), sans révision demandée ni approuvée.
-- NULL sinon (l'appelant en ouvre un). Verrouillé.
CREATE OR REPLACE FUNCTION ingest.fn_h21_lot_ouvert_du_run(p_run_id bigint, p_library_id uuid)
RETURNS bigint
LANGUAGE plpgsql
SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
DECLARE v_batch bigint;
BEGIN
  SELECT b.id INTO v_batch
    FROM public.catalog_batches b
   WHERE b.status = 'open'
     AND b.library_id IS NOT DISTINCT FROM p_library_id
     AND (b.id IN (SELECT m.batch_id FROM ingest.partner_catalog_row_to_draft m
                    WHERE m.run_id = p_run_id AND m.batch_id IS NOT NULL)
          OR b.id IN (SELECT x.batch_id FROM public.exemplar_drafts x
                        JOIN ingest.partner_catalog_staging_rows sr ON sr.id = x.import_staging_row_id
                       WHERE sr.run_id = p_run_id AND x.batch_id IS NOT NULL))
     AND coalesce(public.fn_batch_review_status(b.id), 'aucune') IN ('aucune', 'changes_requested')
   ORDER BY b.id DESC
   LIMIT 1
   FOR UPDATE OF b;
  RETURN v_batch;
END
$function$;
REVOKE ALL ON FUNCTION ingest.fn_h21_lot_ouvert_du_run(bigint, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_h21_lot_ouvert_du_run(bigint, uuid) TO service_role;

-- Un instantané de brouillon d'exemplaire rejoué du journal : une source ou un
-- run disparus depuis, le lien seul tombe (sinon 23503).
CREATE OR REPLACE FUNCTION ingest.fn_h21_trace_exemplaire_rejouable(p_snap jsonb)
RETURNS jsonb
LANGUAGE sql STABLE
SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  SELECT p_snap
         || CASE WHEN p_snap->>'import_run_id' IS NOT NULL
                      AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs r
                                       WHERE r.id = (p_snap->>'import_run_id')::bigint)
                 THEN jsonb_build_object('import_run_id', NULL) ELSE '{}'::jsonb END
         || CASE WHEN p_snap->>'import_source_id' IS NOT NULL
                      AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_sources s
                                       WHERE s.id = (p_snap->>'import_source_id')::bigint)
                 THEN jsonb_build_object('import_source_id', NULL) ELSE '{}'::jsonb END;
$function$;
REVOKE ALL ON FUNCTION ingest.fn_h21_trace_exemplaire_rejouable(jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_h21_trace_exemplaire_rejouable(jsonb) TO service_role;


-- ─────────────────────────────────────────────────────────────────────
-- 4. « Rapprocher » : le constat, le lot ouvert du run, le rejet seulement
--    quand la ligne n'apporte rien
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6_rapprocher$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6_def('ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure);
  v_def := pg_temp.h21l6_remplacer('rapprocher (déclarations)', v_def,
$a$  v_refresh jsonb;
  rec record;
begin$a$,
$b$  v_refresh jsonb;
  rec record;
  -- H21 lot 6a
  v_lib_imp uuid;               -- la bibliothèque importatrice (IMP-28 c)
  v_source_id bigint;
  v_constat jsonb;
  v_c jsonb;
  v_k integer;
  v_implicite boolean;
  v_signal boolean;
  v_verdicts jsonb := jsonb_build_object('nouveau', 0, 'deja_la', 0, 'deja_en_brouillon', 0, 'sans_code', 0,
                                         'deplace', 0, 'reetiquete', 0, 'code_repris', 0);
  v_rows_signalees integer := 0;
  v_lot_rejoint boolean := false;
  v_lignes bigint[] := '{}'::bigint[];
  v_lot_constat bigint;
begin$b$);
  v_def := pg_temp.h21l6_remplacer('rapprocher (lot à la demande)', v_def,
$a$  -- B30 : le lot de rapprochement naît avec la bibliothèque des exemplaires.
  insert into public.catalog_batches (name, notes, created_by, library_id)
  values (v_batch_name, v_batch_notes, v_actor, v_item_library)
  returning id into v_batch_id;
$a$,
$b$  -- H21 lot 6a (08/10/2026) : plus de lot créé d'avance. Le premier brouillon
  -- rejoint le lot ouvert du run (IMP-27 d, ingest.fn_h21_lot_ouvert_du_run),
  -- sinon il ouvre un lot — B30 : avec la bibliothèque des exemplaires. Le
  -- constat se fait pour la bibliothèque IMPORTATRICE (IMP-28 c), sous un
  -- verrou d'avis par bibliothèque (deux constats concurrents).
  v_lib_imp := ingest.fn_h21_bibliotheque_importatrice(p_run_id, NULL, v_item_library);
  select r.source_id into v_source_id from ingest.partner_catalog_import_runs r where r.id = p_run_id;
  if v_lib_imp is not null then
    perform pg_advisory_xact_lock(hashtextextended('h21-lot6a/exemplaires/' || v_lib_imp::text, 0));
  end if;
$b$);
  v_def := pg_temp.h21l6_remplacer('rapprocher (notice de la ligne)', v_def,
$a$           b.titulo  as proposed_titulo
    from ingest.partner_catalog_staging_rows sr$a$,
$b$           b.titulo  as proposed_titulo,
           sr.proposed_book_id,     -- H21 lot 6a : la notice de la ligne (constat)
           -- H21 lot 6a (revue sceptique) : la ligne vient-elle d'un format qui
           -- décrit ses exemplaires (MARC lu avec sa zone 995/852 : item_tag,
           -- le critère d'IMP-25) ?
           coalesce(sr.raw_payload ? 'item_tag', false) as zone_exemplaire
    from ingest.partner_catalog_staging_rows sr$b$);
  v_def := pg_temp.h21l6_remplacer_entre('rapprocher (constat par exemplaire)', v_def,
$a$    -- H19 (IMP-21) : UN brouillon d'exemplaire par exemplaire du fichier$a$,
$a$    v_created_count := v_created_count + 1;
  end loop;$a$,
$b$    -- H19 (IMP-21) : UN brouillon d'exemplaire par exemplaire du fichier
    -- (995/852), avec son code d'origine et sa cote ; à défaut (CSV, MARC
    -- sans 995), un seul comme avant. La ligne pointe le premier
    -- (created_exemplar_draft_id) ; les autres la retrouvent par
    -- import_staging_row_id. Le code n'entre pas dans la note de provenance
    -- (IMP-21 b) : sa colonne suffit.
    -- H21 lot 6a (08/10/2026, IMP-33) : chaque exemplaire du fichier est
    -- CONSTATÉ (ingest.fn_h21_constat_exemplaire, la règle unique de la
    -- promotion et du rapprochement) ; seul « nouveau » crée un brouillon —
    -- avec son identifiant interne, sa source et son run. Le constat est posé
    -- sur la ligne.
    v_first_id := null;
    v_constat := '[]'::jsonb;
    v_signal := false;
    v_k := 0;
    -- L'exemplaire implicite (H19) : seulement pour une ligne d'un format qui ne
    -- décrit jamais d'exemplaire (CSV, RIS : normalized_payload ou items absent,
    -- pas de zone d'exemplaire). Une ligne MARC lue avec sa zone d'exemplaire
    -- qui n'en décrit aucun n'en reçoit pas (IMP-25) : rien à rapprocher.
    v_implicite := not coalesce(jsonb_typeof(rec.normalized_payload->'items') = 'array'
                                and jsonb_array_length(rec.normalized_payload->'items') > 0, false)
                   and not rec.zone_exemplaire;
    for it in
      select value from jsonb_array_elements(
        case when v_implicite then '[{}]'::jsonb
             when jsonb_typeof(rec.normalized_payload->'items') = 'array' then rec.normalized_payload->'items'
             else '[]'::jsonb end)
    loop
      v_k := v_k + 1;
      v_c := jsonb_build_object('n', v_k,
               'code', nullif(btrim(it->>'source_item_code'), ''),
               'expl_id', nullif(btrim(it->>'source_item_id'), ''),
               'cote', nullif(btrim(it->>'call_number'), ''))
          || case when v_implicite then jsonb_build_object('verdict', 'nouveau', 'implicite', true)
                  else ingest.fn_h21_constat_exemplaire(v_lib_imp, v_source_id, rec.proposed_book_id,
                         it->>'source_item_code', it->>'source_item_id') end;
      v_verdicts := jsonb_set(v_verdicts, array[v_c->>'verdict'],
                              to_jsonb(coalesce((v_verdicts->>(v_c->>'verdict'))::integer, 0) + 1));
      if v_c->>'verdict' is distinct from 'nouveau' then
        -- rien à créer : signalé (sans code, déplacé, réétiqueté, code repris)
        -- ou déjà là / déjà en brouillon. Aucune écriture sur l'existant.
        if v_c->>'verdict' in ('sans_code', 'deplace', 'reetiquete', 'code_repris') then
          v_signal := true;
        end if;
        if v_c->>'verdict' = 'deja_la' then
          v_items_skipped := v_items_skipped + 1;
        end if;
        v_constat := v_constat || jsonb_build_array(v_c);
        continue;
      end if;
      if v_batch_id is null then
        v_batch_id := ingest.fn_h21_lot_ouvert_du_run(p_run_id, v_item_library);
        if v_batch_id is null then
          -- B30 : le lot de rapprochement naît avec la bibliothèque des exemplaires.
          insert into public.catalog_batches (name, notes, created_by, library_id)
          values (v_batch_name, v_batch_notes, v_actor, v_item_library)
          returning id into v_batch_id;
        else
          select b.name into v_batch_name from public.catalog_batches b where b.id = v_batch_id;
          v_lot_rejoint := true;
        end if;
      end if;
      insert into public.exemplar_drafts (
        batch_id, action, status, label_status,
        target_library_id, target_bib_ref, source_library, provenance_note,
        source_item_code, shelf_location, notes, import_staging_row_id,
        source_item_id, import_source_id, import_run_id,     -- H21 lot 6a
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
        nullif(btrim(it->>'source_item_id'), ''), v_source_id, p_run_id,
        v_actor, v_actor
      )
      returning id into v_exemplar_draft_id;
      v_first_id := coalesce(v_first_id, v_exemplar_draft_id);
      v_items_created := v_items_created + 1;
      v_constat := v_constat || jsonb_build_array(v_c || jsonb_build_object('brouillon_cree', v_exemplar_draft_id));

      -- Resout / relie le book_holdings (cree a la publication si absent).
      perform public.sync_exemplar_draft_holdings_bridge(v_exemplar_draft_id);
    end loop;
    v_exemplar_draft_id := v_first_id;
    v_lignes := v_lignes || rec.row_id;
    update ingest.partner_catalog_staging_rows
       set exemplaires_constat = jsonb_build_object(
             'version', 'h21-lot6a/2026-10-08', 'via', 'rapprochement', 'at', now(),
             'run_id', p_run_id, 'library_id', v_lib_imp, 'book_id', rec.proposed_book_id,
             'source_id', v_source_id, 'sans_exemplaire_decrit', v_k = 0,
             'batch_id', v_batch_id, 'items', v_constat)
     where id = rec.row_id;
    -- Rien à créer. H19 marquait la ligne rejetée (laissée en
    -- 'accept_duplicate' sans brouillon, le « Promouvoir » suivant en faisait
    -- une notice en double — seconde revue, 27/09). H21 lot 6a : rejetée
    -- d'office — avec la note d'avant, que ingest.fn_h21_rejet_par_choix
    -- reconnaît — SEULEMENT si elle n'apporte rien (tous ses exemplaires déjà
    -- là ou déjà en brouillon). Un signal la laisse « rattachée », sans
    -- brouillon, plus sélectionnée : visible, le geste est à la main.
    if v_first_id is null then
      if v_signal then
        update ingest.partner_catalog_staging_rows
           set selected_for_draft = false
         where id = rec.row_id;
        v_rows_signalees := v_rows_signalees + 1;
        continue;
      end if;
      -- (même préfixe de note, que ingest.fn_h21_rejet_par_choix reconnaît)
      update ingest.partner_catalog_staging_rows
         set editorial_decision = 'reject',
             editorial_note = case when v_k = 0
               then 'Todos os exemplares desta linha ja estao na biblioteca (o arquivo nao descreve nenhum exemplar desta linha): nada a aproximar.'
               else 'Todos os exemplares desta linha ja estao na biblioteca (mesmo codigo de origem): nada a aproximar.' end,
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
  end loop;$b$);
  v_def := pg_temp.h21l6_remplacer_entre('rapprocher (rendu)', v_def,
$a$  if v_created_count = 0 then
    delete from public.catalog_batches where id = v_batch_id;$a$,
$a$    'rows_already_held', v_rows_held,
    'run', v_refresh
  );$a$,
$b$  -- H21 lot 6a : le constat désigne le lot où le rapport de révision le
  -- montrera — celui de ce rapprochement, sinon (rien créé) le lot ouvert du
  -- run s'il y en a un, sans en ouvrir — y compris pour les lignes constatées
  -- avant la naissance du lot. Rien à créer n'est pas une erreur : dit.
  v_lot_constat := coalesce(v_batch_id, ingest.fn_h21_lot_ouvert_du_run(p_run_id, v_item_library));
  if v_lot_constat is not null then
    update ingest.partner_catalog_staging_rows sr
       set exemplaires_constat = jsonb_set(sr.exemplaires_constat, '{batch_id}', to_jsonb(v_lot_constat))
     where sr.id = any (v_lignes) and sr.exemplaires_constat->>'batch_id' is null;
  end if;

  v_refresh := ingest.fn_refresh_partner_catalog_run_counters(p_run_id);

  return jsonb_build_object(
    'run_id', p_run_id,
    'batch_id', v_batch_id,
    'batch_name', case when v_batch_id is not null then v_batch_name end,
    'batch_joined', v_lot_rejoint,
    'requested_rows', v_requested_count,
    'created_exemplar_drafts', v_created_count,
    'created_items', v_items_created,
    'items_skipped_code_taken', v_items_skipped,
    'rows_already_held', v_rows_held,
    'rows_signalled', v_rows_signalees,
    'verdicts', v_verdicts,
    'run', v_refresh
  );$b$);
  EXECUTE v_def;
END
$h21l6_rapprocher$;


-- ─────────────────────────────────────────────────────────────────────
-- 5. Promotion : le même constat ; seuls les « nouveau » entrent dans les
--    brouillons de la notice nouvelle
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6_promotion$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6_def('ingest.fn_create_item_drafts_for_batch(bigint, uuid, bigint[])'::regprocedure);
  v_def := pg_temp.h21l6_remplacer('promotion (déclarations)', v_def,
$a$  it jsonb;
BEGIN$a$,
$b$  it jsonb;
  -- H21 lot 6a
  v_lib_imp uuid;
  v_constat jsonb;
  v_c jsonb;
  v_k integer;
  v_x bigint;
BEGIN$b$);
  v_def := pg_temp.h21l6_remplacer('promotion (source du run)', v_def,
$a$           d.owner_library_id, r.original_filename, s.partner_name$a$,
$b$           d.owner_library_id, r.original_filename, s.partner_name, r.source_id$b$);
  v_def := pg_temp.h21l6_remplacer_entre('promotion (constat par exemplaire)', v_def,
$a$    FOR it IN SELECT value FROM jsonb_array_elements(rec.normalized_payload->'items') LOOP$a$,
$a$      v_n := v_n + 1;
    END LOOP;$a$,
$b$    -- H21 lot 6a (08/10/2026, IMP-33) : chaque exemplaire du fichier est
    -- constaté (ingest.fn_h21_constat_exemplaire) pour la bibliothèque
    -- importatrice, la notice étant NOUVELLE : un exemplaire déjà dans la
    -- bibliothèque (déplacé dans PMB vers cette notice), réétiqueté, au code
    -- repris, déjà en brouillon ou sans code n'entre pas dans ses brouillons
    -- — signalé sur la ligne ; la notice se publie sans lui.
    v_lib_imp := ingest.fn_h21_bibliotheque_importatrice(rec.run_id, NULL, rec.owner_library_id);
    IF v_lib_imp IS NOT NULL THEN
      PERFORM pg_advisory_xact_lock(hashtextextended('h21-lot6a/exemplaires/' || v_lib_imp::text, 0));
    END IF;
    v_constat := '[]'::jsonb;
    v_k := 0;
    FOR it IN SELECT value FROM jsonb_array_elements(rec.normalized_payload->'items') LOOP
      v_k := v_k + 1;
      v_c := jsonb_build_object('n', v_k,
               'code', nullif(btrim(it->>'source_item_code'), ''),
               'expl_id', nullif(btrim(it->>'source_item_id'), ''),
               'cote', nullif(btrim(it->>'call_number'), ''))
          || ingest.fn_h21_constat_exemplaire(v_lib_imp, rec.source_id, NULL, it->>'source_item_code', it->>'source_item_id');
      IF v_c->>'verdict' IS DISTINCT FROM 'nouveau' THEN
        v_constat := v_constat || jsonb_build_array(v_c);
        CONTINUE;
      END IF;
      INSERT INTO public.exemplar_drafts (
        batch_id, action, status, label_status,
        book_draft_id, import_staging_row_id, target_library_id,
        source_item_code, shelf_location, notes, source_library, provenance_note,
        source_item_id, import_source_id, import_run_id,     -- H21 lot 6a
        created_by, updated_by
      ) VALUES (
        p_batch_id, 'create', 'draft', 'pending',
        rec.draft_id, rec.staging_row_id, rec.owner_library_id,
        nullif(btrim(it->>'source_item_code'), ''),
        nullif(btrim(it->>'call_number'), ''),
        nullif(btrim(it->>'note'), ''),
        nullif(btrim(it->>'owner'), ''),
        concat_ws(' ',
          format('Exemplar importado de "%s" (%s, run %s, linha %s).',
                 coalesce(rec.partner_name, 'parceiro sem nome'),
                 coalesce(rec.original_filename, 'arquivo sem nome'), rec.run_id, rec.row_no),
          'Tipo: ' || nullif(btrim(it->>'item_type'), '') || '.',
          'Publico: ' || nullif(btrim(it->>'public'), '') || '.',
          'Situacao: ' || nullif(btrim(it->>'status'), '') || '.'),
        nullif(btrim(it->>'source_item_id'), ''), rec.source_id, rec.run_id,
        v_actor, v_actor
      )
      RETURNING id INTO v_x;
      v_constat := v_constat || jsonb_build_array(v_c || jsonb_build_object('brouillon_cree', v_x));
      v_n := v_n + 1;
    END LOOP;
    UPDATE ingest.partner_catalog_staging_rows
       SET exemplaires_constat = jsonb_build_object(
             'version', 'h21-lot6a/2026-10-08', 'via', 'promotion', 'at', now(),
             'run_id', rec.run_id, 'library_id', v_lib_imp, 'book_id', NULL, 'source_id', rec.source_id, 'source_id', rec.source_id,
             'book_draft_id', rec.draft_id, 'batch_id', p_batch_id, 'items', v_constat)
     WHERE id = rec.staging_row_id;$b$);
  EXECUTE v_def;
END
$h21l6_promotion$;


-- ─────────────────────────────────────────────────────────────────────
-- 6. La publication recopie la trace (les deux branches) et refuse un
--    identifiant interne déjà pris
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6_publication$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6_def('public.publish_exemplar_draft(bigint)'::regprocedure);
  v_def := pg_temp.h21l6_remplacer('publish_exemplar_draft (déclarations)', v_def,
$a$  v_existing_holding bigint;  -- C14 (3) : le fonds que l'exemplaire quitte
begin$a$,
$b$  v_existing_holding bigint;  -- C14 (3) : le fonds que l'exemplaire quitte
  v_existing_item_id text;    -- H21 lot 6a : l'identifiant interne qu'il porte déjà
  v_existing_src bigint;      -- H21 lot 6a : et sa source
  v_item_id text;             -- H21 lot 6a : celui qu'il aura
  v_item_src bigint;          -- H21 lot 6a : et sa source
begin$b$);
  v_def := pg_temp.h21l6_remplacer('publish_exemplar_draft (exemplaire existant)', v_def,
$a$    select e.library_id, e.tombo, e.source_item_code, e.holding_id into v_existing_library, v_existing_tombo, v_existing_code, v_existing_holding$a$,
$b$    select e.library_id, e.tombo, e.source_item_code, e.holding_id, e.source_item_id, e.import_source_id
      into v_existing_library, v_existing_tombo, v_existing_code, v_existing_holding, v_existing_item_id, v_existing_src$b$);
  v_def := pg_temp.h21l6_remplacer('publish_exemplar_draft (identifiant interne pris)', v_def,
$a$    raise exception 'codigo_de_origem_ja_usado: %', v_item_code
      using hint = 'error.publish.source_item_code_taken';
  end if;
$a$,
$b$    raise exception 'codigo_de_origem_ja_usado: %', v_item_code
      using hint = 'error.publish.source_item_code_taken';
  end if;
  -- H21 lot 6a (08/10/2026) : l'identifiant interne (expl_id) est unique par
  -- bibliothèque ET SOURCE (un PMB = une source ; revue sceptique) — refus dit,
  -- jamais un 23505 brut. Sans source, il n'est plus un signal : pas de garde.
  v_item_id := coalesce(nullif(btrim(coalesce(v_draft.source_item_id, '')), ''), v_existing_item_id);
  v_item_src := coalesce(v_draft.import_source_id, v_existing_src);
  if v_item_id is not null and v_item_src is not null
     and exists (select 1 from public.exemplares e
                  where e.library_id = v_library_id
                    and e.import_source_id = v_item_src
                    and e.source_item_id = v_item_id
                    and e.id is distinct from v_draft.published_exemplar_id) then
    raise exception 'identificador_de_origem_ja_usado: %', v_item_id
      using hint = 'error.publish.source_item_id_taken';
  end if;
$b$);
  v_def := pg_temp.h21l6_remplacer('publish_exemplar_draft (création, colonnes)', v_def,
$a$        acquisition_mode, acquisition_date, provenance_note, source_library, source_item_code,
        created_at, updated_at$a$,
$b$        acquisition_mode, acquisition_date, provenance_note, source_library, source_item_code,
        source_item_id, import_source_id, import_run_id,     -- H21 lot 6a
        created_at, updated_at$b$, 2);
  v_def := pg_temp.h21l6_remplacer('publish_exemplar_draft (création, valeurs)', v_def,
$a$        v_draft.acquisition_mode, v_draft.acquisition_date, v_draft.provenance_note, v_draft.source_library, v_draft.source_item_code,
        now(), now()$a$,
$b$        v_draft.acquisition_mode, v_draft.acquisition_date, v_draft.provenance_note, v_draft.source_library, v_draft.source_item_code,
        nullif(btrim(coalesce(v_draft.source_item_id, '')), ''), v_draft.import_source_id, v_draft.import_run_id,
        now(), now()$b$, 2);
  v_def := pg_temp.h21l6_remplacer('publish_exemplar_draft (republication)', v_def,
$a$           source_item_code = coalesce(v_draft.source_item_code, public.exemplares.source_item_code),$a$,
$b$           source_item_code = coalesce(v_draft.source_item_code, public.exemplares.source_item_code),
           -- H21 lot 6a : un brouillon qui ne porte pas la trace (« Éditer ») ne l'efface pas
           source_item_id   = coalesce(nullif(btrim(coalesce(v_draft.source_item_id, '')), ''), public.exemplares.source_item_id),
           import_source_id = coalesce(v_draft.import_source_id, public.exemplares.import_source_id),
           import_run_id    = coalesce(v_draft.import_run_id,    public.exemplares.import_run_id),$b$);
  EXECUTE v_def;
END
$h21l6_publication$;


-- ─────────────────────────────────────────────────────────────────────
-- 7. L'API ne pose pas la trace d'import d'un brouillon d'exemplaire
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6_trace$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6_def('public.tg_exemplar_drafts_import_links_locked()'::regprocedure);
  v_def := pg_temp.h21l6_remplacer('tg_exemplar_drafts_import_links_locked', v_def,
$a$  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
$a$,
$b$  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  -- H21 lot 6a (08/10/2026) : identifiant interne, source et run sont une
  -- trace d'import — posés par la promotion et le rapprochement seuls, à
  -- l'INSERT comme à l'UPDATE (la leçon du lot 5).
  IF (TG_OP = 'INSERT' AND (NEW.source_item_id IS NOT NULL OR NEW.import_source_id IS NOT NULL
                            OR NEW.import_run_id IS NOT NULL))
     OR (TG_OP = 'UPDATE' AND (NEW.source_item_id IS DISTINCT FROM OLD.source_item_id
                               OR NEW.import_source_id IS DISTINCT FROM OLD.import_source_id
                               OR NEW.import_run_id IS DISTINCT FROM OLD.import_run_id)) THEN
    RAISE EXCEPTION 'Rastro de importacao do exemplar reservado ao circuito de importacao.'
      USING ERRCODE = '42501', HINT = 'error.import.item_trace_reserved';
  END IF;
$b$);
  EXECUTE v_def;
END
$h21l6_trace$;


-- ─────────────────────────────────────────────────────────────────────
-- 8. Corbeille : un exemplaire dont le code ou l'identifiant est pris ne
--    revient pas
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tg_exemplar_drafts_code_libre_au_retour()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
BEGIN
  -- H21 lot 6a (08/10/2026) : défaut consigné au lot 0 — un exemplaire
  -- rapproché mis à la corbeille libère sa ligne ; un nouveau « Rapprocher »
  -- en refait un ; la sortie de corbeille du premier faisait un doublon. Refus
  -- dit, quelle que soit la voie (écran, API, fonction) : le code d'origine ou
  -- l'identifiant interne est désormais pris dans la bibliothèque par un
  -- exemplaire ou par un brouillon vivant.
  IF OLD.status = 'cancelled' AND NEW.status IN ('draft', 'ready')
     AND ingest.fn_h21_exemplaire_pris(coalesce(NEW.target_library_id, public.fn_book_draft_library(NEW.book_draft_id)),
                                       NEW.source_item_code, NEW.source_item_id, NEW.import_source_id,
                                       NEW.id, NEW.published_exemplar_id) THEN
    RAISE EXCEPTION 'exemplar_com_codigo_ja_retomado: %', coalesce(NEW.source_item_code, NEW.source_item_id)
      USING HINT = 'error.import.item_restore_code_taken';
  END IF;
  RETURN NEW;
END
$function$;
REVOKE ALL ON FUNCTION public.tg_exemplar_drafts_code_libre_au_retour() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tg_exemplar_drafts_code_libre_au_retour() TO service_role;
DROP TRIGGER IF EXISTS exemplar_drafts_zx_code_libre_au_retour ON public.exemplar_drafts;
CREATE TRIGGER exemplar_drafts_zx_code_libre_au_retour
  BEFORE UPDATE OF status ON public.exemplar_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_exemplar_drafts_code_libre_au_retour();

DO $h21l6_suivre$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6_def('public.tg_book_drafts_imported_items_follow()'::regprocedure);
  v_def := pg_temp.h21l6_remplacer('tg_book_drafts_imported_items_follow (restauration)', v_def,
$a$       WHERE x.book_draft_id = NEW.id AND x.status = 'cancelled' AND x.cancelled_with_record;$a$,
$b$       WHERE x.book_draft_id = NEW.id AND x.status = 'cancelled' AND x.cancelled_with_record
         -- H21 lot 6a : un exemplaire dont le code ou l'identifiant est pris
         -- depuis reste à la corbeille ; la notice revient sans lui.
         AND NOT ingest.fn_h21_exemplaire_pris(coalesce(x.target_library_id, public.fn_book_draft_library(NEW.id)),
                                               x.source_item_code, x.source_item_id, x.import_source_id,
                                               x.id, x.published_exemplar_id);$b$);
  EXECUTE v_def;
END
$h21l6_suivre$;

DO $h21l6_journal$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6_def('public.fn_restore_deleted_draft(bigint)'::regprocedure);
  v_def := pg_temp.h21l6_remplacer('fn_restore_deleted_draft (exemplaire seul)', v_def,
$a$      v_snap := jsonb_set(v_snap, '{import_staging_row_id}', 'null'::jsonb);
    end if;
  end if;
$a$,
$b$      v_snap := jsonb_set(v_snap, '{import_staging_row_id}', 'null'::jsonb);
    end if;
  end if;
  -- H21 lot 6a (08/10/2026) : la trace d'import revient avec le brouillon
  -- (une source ou un run disparus : le lien seul tombe) ; un exemplaire
  -- VIVANT dont le code ou l'identifiant est pris depuis ne revient pas.
  if v_tbl = 'exemplar_drafts' then
    v_snap := ingest.fn_h21_trace_exemplaire_rejouable(v_snap);
    if coalesce(v_snap->>'status', 'draft') in ('draft', 'ready')
       and ingest.fn_h21_exemplaire_pris(
             coalesce((v_snap->>'target_library_id')::uuid, public.fn_book_draft_library((v_snap->>'book_draft_id')::bigint)),
             v_snap->>'source_item_code', v_snap->>'source_item_id', (v_snap->>'import_source_id')::bigint,
             v_id, (v_snap->>'published_exemplar_id')::bigint) then
      raise exception 'exemplar_com_codigo_ja_retomado: %', coalesce(v_snap->>'source_item_code', v_snap->>'source_item_id')
        using hint = 'error.import.item_restore_code_taken';
    end if;
  end if;
$b$);
  v_def := pg_temp.h21l6_remplacer('fn_restore_deleted_draft (exemplaires de la notice)', v_def,
$a$                  from jsonb_array_elements(v_child.rows) as x(v)) as e;
      end if;$a$,
$b$                  from jsonb_array_elements(v_child.rows) as x(v)) as e;
        -- H21 lot 6a : la trace (source, run disparus : le lien seul tombe) ;
        -- un exemplaire vivant dont le code ou l'identifiant est pris depuis
        -- revient à la corbeille avec sa notice (cancelled_with_record), sans
        -- bloquer le rejeu de la notice.
        select coalesce(jsonb_agg(case
                 when coalesce(t.v->>'status', 'draft') in ('draft', 'ready')
                      and ingest.fn_h21_exemplaire_pris(
                            coalesce((t.v->>'target_library_id')::uuid, public.fn_book_draft_library(v_id)),
                            t.v->>'source_item_code', t.v->>'source_item_id', (t.v->>'import_source_id')::bigint,
                            (t.v->>'id')::bigint, (t.v->>'published_exemplar_id')::bigint)
                 then t.v || jsonb_build_object('status', 'cancelled', 'cancelled_with_record', true)
                 else t.v end order by t.o), '[]'::jsonb)
          into v_rows
          from (select ingest.fn_h21_trace_exemplaire_rejouable(x.v) as v, x.o
                  from jsonb_array_elements(v_rows) with ordinality as x(v, o)) t;
      end if;$b$);
  EXECUTE v_def;
END
$h21l6_journal$;


-- ─────────────────────────────────────────────────────────────────────
-- 9. Lire : la liste des lignes d'un run porte les exemplaires du fichier et
--    leur verdict (DROP + CREATE : type de retour élargi)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6_liste$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6_def('public.fn_import_list_run_rows(bigint)'::regprocedure);
  v_def := pg_temp.h21l6_remplacer('fn_import_list_run_rows (type de retour)', v_def,
$a$ update_draft_id bigint, update_draft_status text)$a$,
$b$ update_draft_id bigint, update_draft_status text, exemplaires jsonb)$b$);
  v_def := pg_temp.h21l6_remplacer('fn_import_list_run_rows (colonne)', v_def,
$a$         mu.draft_id AS update_draft_id,
         mu.draft_status AS update_draft_status
  FROM ingest.partner_catalog_staging_rows sr$a$,
$b$         mu.draft_id AS update_draft_id,
         mu.draft_status AS update_draft_status,
         -- H21 lot 6a (08/10/2026) : les exemplaires du fichier et leur verdict
         -- (le constat posé par la promotion ou « Rapprocher » ; avant lui, la
         -- liste sans verdict) ; le titre de la notice où un exemplaire est
         -- trouvé (déplacé, réétiqueté, code repris, déjà là).
         CASE WHEN sr.exemplaires_constat IS NOT NULL THEN
                (SELECT coalesce(jsonb_agg(x.v || CASE WHEN x.v ? 'book_id' AND x.v->>'book_id' IS NOT NULL
                                                       THEN jsonb_build_object('book_titulo',
                                                              (SELECT b.titulo FROM public.books b WHERE b.id = (x.v->>'book_id')::bigint))
                                                       ELSE '{}'::jsonb END
                                           ORDER BY (x.v->>'n')::integer), '[]'::jsonb)
                   FROM jsonb_array_elements(sr.exemplaires_constat->'items') x(v))
              WHEN jsonb_typeof(sr.normalized_payload->'items') = 'array'
                   AND jsonb_array_length(sr.normalized_payload->'items') > 0 THEN
                (SELECT jsonb_agg(jsonb_build_object('n', i.o,
                                    'code', nullif(btrim(i.v->>'source_item_code'), ''),
                                    'expl_id', nullif(btrim(i.v->>'source_item_id'), ''),
                                    'cote', nullif(btrim(i.v->>'call_number'), '')) ORDER BY i.o)
                   FROM jsonb_array_elements(sr.normalized_payload->'items') WITH ORDINALITY i(v, o))
         END AS exemplaires
  FROM ingest.partner_catalog_staging_rows sr$b$);
  DROP FUNCTION public.fn_import_list_run_rows(bigint);
  EXECUTE v_def;
END
$h21l6_liste$;
REVOKE ALL ON FUNCTION public.fn_import_list_run_rows(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_import_list_run_rows(bigint) TO authenticated, service_role;


-- ─────────────────────────────────────────────────────────────────────
-- 10. Le rapport de révision : les exemplaires du fichier écartés pour ce lot
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6_rapport$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6_def('public.fn_batch_review_report(bigint)'::regprocedure);
  v_def := pg_temp.h21l6_remplacer('fn_batch_review_report (déclarations)', v_def,
$a$  v_prepared jsonb;  -- H21 lot 4$a$,
$b$  v_prepared jsonb;  -- H21 lot 4
  v_ecartes jsonb;   -- H21 lot 6a$b$);
  v_def := pg_temp.h21l6_remplacer('fn_batch_review_report (section)', v_def,
$a$  return jsonb_build_object(
    'batch', jsonb_build_object($a$,
$b$  -- ── H21 lot 6a (08/10/2026, IMP-33) : les exemplaires du fichier écartés ──
  -- pour ce lot (constat de la promotion ou du rapprochement qui l'a rempli)
  -- et pourquoi : déjà là, déjà en brouillon, sans code-barres, déplacé dans
  -- PMB, réétiqueté, code repris. Comptes sur tout, 40 exemples (signaux
  -- d'abord). Clé absente s'il n'y en a aucun.
  with runs as (
    select m.run_id from ingest.partner_catalog_row_to_draft m where m.batch_id = p_batch_id
    union
    select sr.run_id from public.exemplar_drafts x
      join ingest.partner_catalog_staging_rows sr on sr.id = x.import_staging_row_id
     where x.batch_id = p_batch_id
  ), ec as materialized (
    select sr.id as row_id, sr.external_key, sr.title, i.v as it
      from ingest.partner_catalog_staging_rows sr
      cross join lateral jsonb_array_elements(sr.exemplaires_constat->'items') i(v)
     where sr.run_id in (select runs.run_id from runs)
       and sr.exemplaires_constat->>'batch_id' = p_batch_id::text
       and i.v->>'verdict' is distinct from 'nouveau'
  )
  select case when count(*) = 0 then null else jsonb_build_object(
           'count', count(*),
           'rows', count(distinct ec.row_id),
           'counts', jsonb_build_object(
             'deja_la',           count(*) filter (where ec.it->>'verdict' = 'deja_la'),
             'deja_en_brouillon', count(*) filter (where ec.it->>'verdict' = 'deja_en_brouillon'),
             'sans_code',         count(*) filter (where ec.it->>'verdict' = 'sans_code'),
             'deplace',           count(*) filter (where ec.it->>'verdict' = 'deplace'),
             'reetiquete',        count(*) filter (where ec.it->>'verdict' = 'reetiquete'),
             'code_repris',       count(*) filter (where ec.it->>'verdict' = 'code_repris')),
           'examples', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'row_id', e.row_id, 'external_key', e.external_key, 'titulo', e.title,
                      'n', (e.it->>'n')::integer, 'code', e.it->>'code', 'expl_id', e.it->>'expl_id',
                      'verdict', e.it->>'verdict', 'exemplar_id', (e.it->>'exemplar_id')::bigint,
                      'tombo', e.it->>'tombo', 'book_id', (e.it->>'book_id')::bigint,
                      'book_titulo', (select b.titulo from public.books b where b.id = (e.it->>'book_id')::bigint),
                      'ancien_code', e.it->>'ancien_code', 'autre_expl_id', e.it->>'autre_expl_id',
                      'draft_id', (e.it->>'draft_id')::bigint) order by e.rang)
               from (select ec2.*, row_number() over (
                               order by array_position(array['code_repris', 'reetiquete', 'deplace', 'sans_code',
                                                             'deja_en_brouillon', 'deja_la'], ec2.it->>'verdict'),
                                        ec2.row_id, (ec2.it->>'n')::integer) as rang
                       from ec ec2
                      order by rang limit 40) e), '[]'::jsonb)) end
    into v_ecartes
    from ec;

  return jsonb_build_object(
    'batch', jsonb_build_object($b$);
  v_def := pg_temp.h21l6_remplacer('fn_batch_review_report (rendu)', v_def,
$a$    || case when v_prepared is null then '{}'::jsonb else jsonb_build_object('prepared_updates', v_prepared) end;   -- H21 lot 4$a$,
$b$    || case when v_prepared is null then '{}'::jsonb else jsonb_build_object('prepared_updates', v_prepared) end   -- H21 lot 4
    || case when v_ecartes is null then '{}'::jsonb else jsonb_build_object('items_set_aside', v_ecartes) end;   -- H21 lot 6a$b$);
  EXECUTE v_def;
END
$h21l6_rapport$;


-- ─────────────────────────────────────────────────────────────────────
-- 11. Profil d'import : la correspondance de l'identifiant interne
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6_profil$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l6_def('public.fn_import_profile_create(uuid, text, jsonb, jsonb, jsonb)'::regprocedure);
  v_def := pg_temp.h21l6_remplacer('fn_import_profile_create', v_def,
$a$      IF v_k NOT IN ('tag', 'code', 'call_number', 'note', 'owner', 'item_type', 'public', 'status')
         OR jsonb_typeof(v_v) <> 'string'
         OR (v_k = 'tag' AND (v_v #>> '{}') !~ '^[0-9]{3}$')
         OR (v_k <> 'tag' AND lower(v_v #>> '{}') !~ '^[0-9a-z]{0,4}$') THEN$a$,
$b$      -- H21 lot 6a : id_tag, id_code, id_prefix — l'identifiant interne de
      -- l'exemplaire (même règle que resolveItemMapping, marc.ts).
      IF v_k NOT IN ('tag', 'code', 'call_number', 'note', 'owner', 'item_type', 'public', 'status',
                     'id_tag', 'id_code', 'id_prefix')
         OR jsonb_typeof(v_v) <> 'string'
         OR (v_k = 'tag' AND (v_v #>> '{}') !~ '^[0-9]{3}$')
         OR (v_k = 'id_tag' AND (v_v #>> '{}') !~ '^([0-9]{3})?$')
         OR (v_k = 'id_code' AND lower(v_v #>> '{}') !~ '^[0-9a-z]?$')
         OR (v_k = 'id_prefix' AND (v_v #>> '{}') !~ '^\S{0,32}$')
         OR (v_k NOT IN ('tag', 'id_tag', 'id_code', 'id_prefix') AND lower(v_v #>> '{}') !~ '^[0-9a-z]{0,4}$') THEN$b$);
  EXECUTE v_def;
END
$h21l6_profil$;


-- ─────────────────────────────────────────────────────────────────────
-- 12. Vérification (structurelle : les migrations passent avant le seed)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l6_verif$
DECLARE
  v_e text := '';
  v_def text;
  v_f text;
BEGIN
  -- colonnes, clés étrangères (SET NULL), index, unicité
  SELECT string_agg(x, ',') INTO v_f FROM (
    SELECT t || '.' || c AS x FROM (VALUES ('exemplares'), ('exemplar_drafts')) a(t)
     CROSS JOIN (VALUES ('source_item_id'), ('import_source_id'), ('import_run_id')) b(c)
     WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns k
                        WHERE k.table_schema = 'public' AND k.table_name = a.t AND k.column_name = b.c)) z;
  IF v_f IS NOT NULL THEN v_e := v_e || ' colonnes(' || v_f || ')'; END IF;
  IF (SELECT count(*) FROM pg_constraint c
       WHERE c.contype = 'f' AND c.confdeltype = 'n'
         AND c.conname IN ('exemplares_import_source_id_fkey', 'exemplares_import_run_id_fkey',
                           'exemplar_drafts_import_source_id_fkey', 'exemplar_drafts_import_run_id_fkey')) <> 4 THEN
    v_e := v_e || ' fk';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indexrelid = 'public.exemplares_source_item_id_par_source'::regclass
                  AND i.indisunique AND i.indpred IS NOT NULL AND i.indnatts = 3) THEN
    v_e := v_e || ' unicite';
  END IF;
  -- le constat : promotion ET rapprochement ; seul « nouveau » crée
  IF position('ingest.fn_h21_constat_exemplaire(v_lib_imp, v_source_id, rec.proposed_book_id,' IN
              pg_get_functiondef('ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure)) = 0
     OR position('ingest.fn_h21_lot_ouvert_du_run(p_run_id, v_item_library)' IN
              pg_get_functiondef('ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure)) = 0
     OR position('delete from public.catalog_batches' IN
              pg_get_functiondef('ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure)) > 0
     OR position('and not rec.zone_exemplaire' IN
              pg_get_functiondef('ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure)) = 0
     OR position('ingest.fn_h21_constat_exemplaire(v_lib_imp, rec.source_id, NULL,' IN
              pg_get_functiondef('ingest.fn_create_item_drafts_for_batch(bigint, uuid, bigint[])'::regprocedure)) = 0 THEN
    v_e := v_e || ' constat';
  END IF;
  -- la publication : deux INSERT et la republication portent la trace ; refus dit
  v_def := pg_get_functiondef('public.publish_exemplar_draft(bigint)'::regprocedure);
  IF (length(v_def) - length(replace(v_def, 'source_item_id, import_source_id, import_run_id,', ''))) / length('source_item_id, import_source_id, import_run_id,') <> 2
     OR position('import_run_id    = coalesce(v_draft.import_run_id,    public.exemplares.import_run_id)' IN v_def) = 0
     OR position('error.publish.source_item_id_taken' IN v_def) = 0
     OR position('and e.import_source_id = v_item_src' IN v_def) = 0 THEN
    v_e := v_e || ' publication';
  END IF;
  IF position('error.import.item_trace_reserved' IN pg_get_functiondef('public.tg_exemplar_drafts_import_links_locked()'::regprocedure)) = 0
     OR NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.exemplar_drafts'::regclass
                     AND t.tgname = 'exemplar_drafts_import_links_locked' AND NOT t.tgisinternal
                     AND (t.tgtype & 4) = 4 AND (t.tgtype & 16) = 16) THEN
    v_e := v_e || ' trace';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.exemplar_drafts'::regclass
                  AND t.tgname = 'exemplar_drafts_zx_code_libre_au_retour' AND NOT t.tgisinternal
                  AND t.tgfoid = 'public.tg_exemplar_drafts_code_libre_au_retour()'::regprocedure)
     OR position('fn_h21_exemplaire_pris' IN pg_get_functiondef('public.tg_book_drafts_imported_items_follow()'::regprocedure)) = 0
     OR position('error.import.item_restore_code_taken' IN pg_get_functiondef('public.fn_restore_deleted_draft(bigint)'::regprocedure)) = 0
     OR position('fn_h21_trace_exemplaire_rejouable(x.v)' IN pg_get_functiondef('public.fn_restore_deleted_draft(bigint)'::regprocedure)) = 0 THEN
    v_e := v_e || ' corbeille';
  END IF;
  IF position('items_set_aside' IN pg_get_functiondef('public.fn_batch_review_report(bigint)'::regprocedure)) = 0
     OR NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid = 'public.fn_import_list_run_rows(bigint)'::regprocedure
                     AND 'exemplaires' = ANY (p.proargnames)) THEN
    v_e := v_e || ' lecture';
  END IF;
  -- droits : portes authenticated inchangées, fermées à anon ; aides internes fermées
  FOREACH v_f IN ARRAY ARRAY[
    'public.fn_import_list_run_rows(bigint)', 'public.fn_batch_review_report(bigint)',
    'public.fn_import_reconcile_duplicates(bigint, bigint[])', 'public.publish_exemplar_draft(bigint)',
    'public.fn_restore_deleted_draft(bigint)', 'public.fn_import_profile_create(uuid, text, jsonb, jsonb, jsonb)'] LOOP
    IF NOT has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0) THEN
      v_e := v_e || ' droits-portes(' || v_f || ')';
    END IF;
  END LOOP;
  FOREACH v_f IN ARRAY ARRAY[
    'ingest.fn_h21_exemplaire_pris(uuid, text, text, bigint, bigint, bigint)', 'ingest.fn_h21_constat_exemplaire(uuid, bigint, bigint, text, text)',
    'ingest.fn_h21_lot_ouvert_du_run(bigint, uuid)', 'ingest.fn_h21_trace_exemplaire_rejouable(jsonb)',
    'public.tg_exemplar_drafts_code_libre_au_retour()',
    'ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)',
    'ingest.fn_create_item_drafts_for_batch(bigint, uuid, bigint[])'] LOOP
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0) THEN
      v_e := v_e || ' droits-internes(' || v_f || ')';
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_proc p
              WHERE p.oid IN ('public.fn_import_list_run_rows(bigint)'::regprocedure,
                              'public.fn_batch_review_report(bigint)'::regprocedure,
                              'public.publish_exemplar_draft(bigint)'::regprocedure,
                              'public.fn_restore_deleted_draft(bigint)'::regprocedure,
                              'public.tg_exemplar_drafts_code_libre_au_retour()'::regprocedure,
                              'ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure,
                              'ingest.fn_create_item_drafts_for_batch(bigint, uuid, bigint[])'::regprocedure)
                AND (NOT p.prosecdef OR coalesce(p.proconfig::text, '') NOT LIKE '%search_path%')) THEN
    v_e := v_e || ' definer';
  END IF;

  IF v_e <> '' THEN
    RAISE EXCEPTION 'H21 lot 6a : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'H21 lot 6a : vérifications OK';
END
$h21l6_verif$;

NOTIFY pgrst, 'reload schema';
