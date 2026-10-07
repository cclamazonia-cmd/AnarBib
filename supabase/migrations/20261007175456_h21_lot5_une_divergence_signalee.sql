-- =====================================================================
-- H21 lot 5 — notice partagée : une divergence signalée, jamais réécrite
-- (REGISTRE IMP-26 a, b, c ; IMP-29, IMP-30, IMP-31 ; IMP-32, décisions de
-- Xavier du 07/10/2026 ; cartographie H21 du 28/09, pièges 12, 17, 18 et 19)
--
-- Décisions de Xavier du 07/10/2026 (IMP-32) :
--  (a) OÙ : chaque coordination d'une bibliothèque DÉTENTRICE de la notice
--      (book_holdings — jamais owner_library_id) voit la divergence, par un
--      bandeau sur la notice au catalogage et dans la liste « Divergences à
--      traiter » ; l'administration du réseau voit tout ; la bibliothèque qui
--      importe la voit aussi dans Importations (comparaison du lot 3).
--  (b) APPLIQUER = un brouillon de reprise PRÉREMPLI : la copie de la notice
--      (ingest.fn_h21_copie_de_la_notice, lot 4), les champs choisis remplis
--      avec la valeur du fichier ; la détentrice relit et publie elle-même
--      (publish_book_draft). Responsabilités (contributors) et champs vidés par
--      la source : montrés, jamais préremplis (IMP-31 b).
--  (c) CHAMP PAR CHAMP : chaque champ divergent s'écarte ou s'applique
--      séparément, plus « Tout écarter » par notice. La base n'avance que pour
--      les champs écartés ou appliqués.
--
-- 1. La table ingest.book_import_divergences (RLS activée, AUCUNE politique,
--    aucun droit pour anon ni authenticated : accès par les fonctions DEFINER
--    ci-dessous ; service_role) : une divergence = (notice, bibliothèque qui
--    importe, champ) ; la source, le run, la ligne de staging et la base où
--    elle a été vue en dernier ; B, A (au constat), N ; verdict (source_seule,
--    conflit, sans_base) ; statut (ouverte, ecartee, appliquee, resolue,
--    caduque) ; qui et quand l'a traitée ; empreintes de B et de N pour ce
--    champ ; le brouillon de reprise qui l'applique (draft_id). Une seule
--    divergence OUVERTE par (notice, bibliothèque qui importe, champ) (index
--    unique partiel). Chaque clé étrangère a son index (garde « FK sans
--    index »). Classée ingest.book_import_divergences dans
--    deploy/bg2-known-tables.txt (flux long #BG2, comme tout ingest).
--    Une notice supprimée (retirée, fondue) emporte ses divergences (ON DELETE
--    CASCADE) : le prochain constat sur la notice qui reste les repose.
--
-- 2. Le constat (ingest.fn_h21_constater_divergences(run, lignes)), appelé par
--    public.fn_import_recomparer (définition VIVANTE, par ancres) et par
--    public.fn_import_preparer_mises_a_jour (lot 4, qui écarte une notice
--    partagée : son message dit désormais « signalée aux détentrices » — le
--    constat la rend vraie), juste après le stockage des comparaisons, sur les
--    lignes known_record dont la comparaison stockée vise la notice proposée :
--      - notice PARTAGÉE (plus d'une détentrice, book_holdings) : pour chaque
--        champ au verdict source_seule, conflit ou sans_base, la divergence
--        ouverte est mise à jour (valeurs, verdict, run, ligne, base,
--        empreintes) ou posée — SAUF si la dernière divergence traitée de la
--        même clé est « écartée » au même N (IMP-26 c : écarter vaut accord ;
--        filet utile quand il n'y a pas de base à avancer) ; un champ revenu
--        à un autre verdict (inchangé, identique, changé dans AnarBib
--        seulement) : sa divergence ouverte passe « resolue » ;
--      - notice qui n'est plus partagée : TOUTES ses divergences ouvertes
--        passent « caduque » (le lot 4 reprend la main).
--    Aucune écriture au catalogue : le constat n'écrit que dans
--    ingest.book_import_divergences. Ensembliste (aucune table temporaire —
--    cache de plan PostgREST) ; mesuré au banc avec la page de 200 (voir 7).
--
-- 3. Lire (DEFINER, authenticated seulement, droits nominaux) :
--    - public.fn_divergences_a_traiter(p_library_id, p_limit, p_offset) : les
--      divergences ouvertes des notices partagées que détient une bibliothèque
--      dont l'appelant est la coordination (fn_caller_coordinator_library_ids)
--      — toutes pour l'administration du réseau —, groupées par (notice,
--      bibliothèque qui importe) : titre, bib_ref, bibliothèque qui importe,
--      champs, brouillon de reprise vivant ; total ; p_library_id restreint à
--      une détentrice (que l'appelant coordonne, sauf administration).
--    - public.fn_notice_divergences(p_book_id) : le bandeau et le détail champ
--      par champ (B, A actuelle, A au constat, N, verdict, applicable ou
--      montré et pourquoi) ; vide ({book_id, groupes: []}, sans titre) si
--      l'appelant n'est ni coordination d'une détentrice ni administration.
--      Jamais d'autre donnée de la ligne de staging de l'autre bibliothèque :
--      seulement les valeurs bibliographiques des champs comparés.
--    CHOIX (spécification, à confirmer) : le LIBRARIAN d'une détentrice ne
--    voit pas les divergences (IMP-26 b dit « la coordination ») — ni liste,
--    ni bandeau, ni geste ; il voit la notice et la corrige comme avant.
--
-- 4. Écarter (public.fn_divergences_ecarter(p_ids), 200 au plus) :
--    coordination d'une détentrice de la notice, ou administration ; chaque
--    divergence est écartée ou IGNORÉE avec sa raison (jamais un refus en
--    bloc) : introuvable, pas_detentrice (jugé avant le statut : rien ne se
--    dit d'une divergence hors de portée), pas_ouverte, non_partagee (passée
--    « caduque » au passage), perimee (la base de ce champ a changé depuis le
--    constat : recomparer d'abord). Écartée : statut « ecartee », qui, quand ;
--    la base avance à N pour CE champ seul (même règle que le lot 4 : mapped
--    ou responsabilités, champ douteux levé, origine « import » quand plus
--    aucun) ; sans base (sans_base sans base) : rien à avancer, le filet du
--    constat retient « écartée au même N ».
--
-- 5. Appliquer (public.fn_divergences_appliquer(p_book_id, p_ids)) :
--    CHOIX (appelant qui coordonne plusieurs détentrices) : le brouillon est
--    pour la bibliothèque ACTIVE de l'appelant (my_access.library_id), comme
--    toute reprise (B29) ; elle doit DÉTENIR la notice (book_holdings) et
--    l'appelant en être la coordination (ou l'administration du réseau dont
--    c'est la bibliothèque active) ; sinon refus traduit
--    (error.divergence.not_holder / error.divergence.coord_only) — changer de
--    bibliothèque active pour appliquer au nom d'une autre.
--    Refus aussi : notice introuvable, brouillon de reprise VIVANT (brouillon,
--    prêt) de cette notice déjà issu d'une divergence
--    (error.divergence.draft_exists), page de plus de 200, rien à préremplir
--    (error.divergence.nothing_to_apply : la sélection n'a que des
--    responsabilités ou des effacements — à reprendre à la main). Les ids
--    hors de la notice, plus ouverts ou d'une notice non partagée sont
--    ignorés avec leur raison.
--    Le brouillon : ingest.fn_h21_copie_de_la_notice (lot 4 : copie complète,
--    jamais une reprise vierge), SANS LOT (il n'est pas importé : pas de lien
--    row_to_draft ; published_book_id non nul — fn_book_draft_is_imported le
--    dit non importé ; pas de révision du lot d'import), patché des seuls
--    champs choisis applicables (valeur normalisée N, au type de la colonne).
--    Provenance de la notice INTACTE (marc_json.ingest, source_record_id…) ;
--    trace à part, marc_json.ingest_divergence : notice, bibliothèque,
--    bib_ref, empreinte de A (ingest.fn_h21_empreinte_notice, lot 4), ids et
--    champs appliqués (B, A, N, empreintes de B et de N), champs montrés non
--    préremplis (raison : responsabilites, efface_par_la_source). Les
--    divergences appliquées désignent le brouillon (draft_id, que l'API
--    n'écrit pas). Rend l'id du brouillon : l'écran l'ouvre dans l'éditeur.
--    Supprimer le brouillon laisse les divergences ouvertes (draft_id remis à
--    NULL par la clé étrangère).
--
-- 6. La publication (publish_book_draft, définition VIVANTE, par ancres) :
--    garde ingest.fn_h21_garde_divergence posée AVANT le choix de branche (la
--    leçon du lot 4 : une garde dans une seule branche se contourne par
--    l'autre) — et avant les portes de révision, juste après les contrôles
--    d'accès (B29) et le refus d'un brouillon annulé : une notice disparue
--    s'y dirait sinon « importée hors lot » (marc_json.ingest copié) — et
--    valable à la republication ; refus traduits :
--      error.divergence.record_gone       la notice a disparu (published_book_id
--                                         vidé par la clé étrangère) — jamais
--                                         la branche création ;
--      error.divergence.not_holder        la bibliothèque du brouillon n'est plus
--                                         celle de la trace, ou ne détient plus
--                                         la notice ;
--      error.divergence.bib_ref_changed   bib_ref du brouillon ≠ celui de la
--                                         notice (piège 12) ;
--      error.divergence.draft_unlinked    (première publication) aucune
--                                         divergence ne désigne ce brouillon :
--                                         la trace n'a pas été posée par le geste ;
--      error.divergence.record_changed    (première publication) la notice a
--                                         changé depuis le préremplissage
--                                         (empreinte de A, lot 4 : la circulation
--                                         seule ne compte pas — piège 19).
--    À la republication (une retouche, IMP-27 b) : détention et bib_ref
--    seulement, comme le lot 4.
--    À la première publication (ingest.fn_h21_divergences_apres_publication) :
--    chaque divergence de la trace encore ouverte, désignant ce brouillon, au
--    même N, et que la notice publiée dit comme le fichier passe « appliquee »
--    (qui, quand) et sa base avance à N pour ce champ ; une valeur retouchée
--    dans le brouillon (A ≠ N) laisse la divergence ouverte et la base telle
--    quelle (le geste local reste un geste local, comme au lot 4). Le résultat
--    est noté dans marc_json.ingest_divergence.publication du brouillon ; la
--    trace ne va jamais sur la notice (retirée dans les deux branches).
--    La trace et la notice visée d'un tel brouillon sont figées pour l'API
--    (tg_book_drafts_trace_import_figee, étendu : remise en silence).
--    api.merge_draft_into_book refuse un tel brouillon
--    (error.divergence.draft_not_mergeable) : elle n'a ni garde de détention
--    ni empreinte.
--
-- 7. Performance : le constat ajoute une passe ensembliste à la page de 200 de
--    fn_import_recomparer (plafond de 8 s des appels de l'API ; un SET
--    statement_timeout dans la fonction ne prolongerait rien) — mesuré au banc
--    privé (tests/sql/h21_lot5_divergences_tests.sql, T20 : 200 notices
--    partagées, 3 champs divergents chacune, sous le jeton de la
--    coordination) ; voir le rapport du lot.
--
-- 8. Revue sceptique du 07/10/2026 (deux défauts bloquants, prouvés au banc) :
--    B1. La copie du lot 4 (ingest.fn_h21_copie_de_la_notice, en production)
--        ne recopiait pas circulation_default : le brouillon prenait le défaut
--        de la colonne ('emprestavel') et, à la publication, le déclencheur
--        fn_propagate_circulation_default_on_publish réécrivait
--        circulation_default ET loanable sur la notice — une notice en
--        consultation devenait empruntable, champ que personne n'avait choisi
--        (mise à jour du lot 4 comme reprise préremplie du lot 5). La copie
--        recopie désormais circulation_default (définition VIVANTE, par
--        ancres). Revue des colonnes : toutes les colonnes de books que porte
--        book_drafts et qu'écrit la publication (branche update ET
--        déclencheurs de publication) sont copiées, sauf work_id (écrit en
--        coalesce : NULL garde celui de la notice), publisher_id (déduit
--        d'editora par déclencheur), owner_library_id (jamais écrit par la
--        branche update), les horodatages et auteurs de modification ; la
--        vérification finale le contrôle. Constat consigné, non corrigé ici
--        (hors du lot) : public.create_book_draft_from_book (« Éditer »)
--        omet aussi circulation_default — la même bascule touche toute
--        reprise à la main d'une notice en consultation.
--    B2. Les traces marc_json.ingest_divergence et marc_json.ingest_update se
--        posaient par l'API à l'INSERT (le déclencheur de trace figée est
--        BEFORE UPDATE) : la coordination d'une bibliothèque NON détentrice
--        insérait un brouillon « de reprise » sur la notice d'autrui, et
--        bloquait « Appliquer » (draft_exists) et le bandeau, indéfiniment ;
--        de même « Préparer la mise à jour » (lot 4 : deja_preparee).
--        (a) public.tg_book_drafts_trace_import_insert (BEFORE INSERT) refuse
--            par l'API (current_user authenticated ou anon — une fonction
--            DEFINER insère sous son propriétaire et passe) un brouillon qui
--            porte l'une de ces traces (error.import.trace_reserved) ;
--        (b) le brouillon vivant qui bloque « Appliquer », et celui que
--            montrent la liste et le bandeau, est un brouillon auquel une
--            divergence est LIÉE (draft_id, que l'API n'écrit pas).
--
-- Méthode : chaque fonction existante est modifiée SUR SA DÉFINITION VIVANTE
-- (pg_get_functiondef, retours chariot retirés) par ancres comptées ; aucune
-- signature ne change (pas de DROP) ; droits restaurés et vérifiés. md5 de
-- prosrc lus le 07/10/2026 en production (MCP, lecture seule) et sur le banc
-- reconstruit depuis le dépôt (identiques) :
--   public.publish_book_draft                 c244b636dd816fc423df9e6cb5ab7928
--   public.fn_import_recomparer               20d15edf5251c14f05aa0e63a82f1c41
--   public.fn_import_preparer_mises_a_jour    b0ec43f63ffe2363d78a3d44996b97d2
--   public.tg_book_drafts_trace_import_figee  76f15ad6c2d21985a39463e8a9b7c05d
--   api.merge_draft_into_book                 b444c14286c62c794a65fd0976c0304c
--   ingest.fn_h21_copie_de_la_notice          5ae63469fbf68dee33e27c98bcf56309
-- Suite : tests/sql/h21_lot5_divergences_tests.sql.
-- =====================================================================

-- Outils de la migration, éphémères (pg_temp).
CREATE OR REPLACE FUNCTION pg_temp.h21l5_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'H21 lot 5 — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN
    RAISE EXCEPTION 'H21 lot 5 — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

CREATE OR REPLACE FUNCTION pg_temp.h21l5_def(p_fn regprocedure)
RETURNS text LANGUAGE sql AS $f$
  SELECT replace(pg_get_functiondef(p_fn), E'\r', '');
$f$;


-- ─────────────────────────────────────────────────────────────────────
-- 0. B1 (revue sceptique) : la copie de la notice recopie circulation_default
-- ─────────────────────────────────────────────────────────────────────
DO $h21l5_copie$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l5_def('ingest.fn_h21_copie_de_la_notice(bigint, bigint, uuid, uuid)'::regprocedure);
  v_def := pg_temp.h21l5_remplacer('fn_h21_copie_de_la_notice (colonnes)', v_def,
$a$    zine_format, zine_print_run, zine_technique, distribuidora, gravadora, subjects,
    created_by, updated_by, created_at$a$,
$b$    zine_format, zine_print_run, zine_technique, distribuidora, gravadora, subjects,
    -- H21 lot 5 (revue sceptique du 07/10) : le déclencheur de publication
    -- (fn_propagate_circulation_default_on_publish) réécrit circulation_default
    -- et loanable sur la notice depuis le brouillon : sans elle, le défaut
    -- 'emprestavel' rendait empruntable une notice en consultation.
    circulation_default,
    created_by, updated_by, created_at$b$);
  v_def := pg_temp.h21l5_remplacer('fn_h21_copie_de_la_notice (valeurs)', v_def,
$a$    b.zine_format, b.zine_print_run, b.zine_technique, b.distribuidora, b.gravadora, b.subjects,
    p_actor, p_actor,$a$,
$b$    b.zine_format, b.zine_print_run, b.zine_technique, b.distribuidora, b.gravadora, b.subjects,
    b.circulation_default,
    p_actor, p_actor,$b$);
  EXECUTE v_def;
END
$h21l5_copie$;


-- ─────────────────────────────────────────────────────────────────────
-- 1. La table des divergences
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ingest.book_import_divergences (
  id               bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  book_id          bigint NOT NULL REFERENCES public.books(id) ON DELETE CASCADE,
  library_id       uuid   NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,   -- la bibliothèque qui importe
  source_id        bigint REFERENCES ingest.partner_catalog_sources(id) ON DELETE SET NULL,
  run_id           bigint REFERENCES ingest.partner_catalog_import_runs(id) ON DELETE SET NULL,
  staging_row_id   bigint REFERENCES ingest.partner_catalog_staging_rows(id) ON DELETE SET NULL,
  baseline_id      bigint REFERENCES ingest.book_import_baselines(id) ON DELETE SET NULL,
  champ            text   NOT NULL CONSTRAINT book_import_divergences_champ_nomme CHECK (btrim(champ) <> ''),
  verdict          text   NOT NULL CONSTRAINT book_import_divergences_verdict_check
                          CHECK (verdict IN ('source_seule', 'conflit', 'sans_base')),
  valeur_base      jsonb,
  valeur_anarbib   jsonb,             -- A au constat
  valeur_fichier   jsonb,
  empreinte_base   text   NOT NULL,   -- md5 de B normalisé pour ce champ
  empreinte_fichier text  NOT NULL,   -- md5 de N normalisé pour ce champ
  statut           text   NOT NULL DEFAULT 'ouverte' CONSTRAINT book_import_divergences_statut_check
                          CHECK (statut IN ('ouverte', 'ecartee', 'appliquee', 'resolue', 'caduque')),
  draft_id         bigint REFERENCES public.book_drafts(id) ON DELETE SET NULL,   -- le brouillon de reprise qui l'applique
  base_avancee     boolean,           -- écartée ou appliquée : la base a-t-elle avancé à N ?
  traitee_par      uuid,              -- auth.uid() d'un geste (NULL : résolue ou caduque par le constat)
  traitee_le       timestamptz,
  vue_le           timestamptz NOT NULL DEFAULT now(),   -- dernier constat
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT book_import_divergences_traitee CHECK ((statut = 'ouverte') = (traitee_le IS NULL))
);
-- Une seule divergence ouverte par (notice, bibliothèque qui importe, champ).
CREATE UNIQUE INDEX IF NOT EXISTS book_import_divergences_ouverte_unique
  ON ingest.book_import_divergences (book_id, library_id, champ) WHERE statut = 'ouverte';
-- Index de chaque clé étrangère (garde « FK sans index ») ; le premier sert
-- aussi la « dernière divergence traitée » d'une clé (id décroissant).
CREATE INDEX IF NOT EXISTS book_import_divergences_cle_idx
  ON ingest.book_import_divergences (book_id, library_id, champ, id);
CREATE INDEX IF NOT EXISTS book_import_divergences_library_idx ON ingest.book_import_divergences (library_id);
CREATE INDEX IF NOT EXISTS book_import_divergences_source_idx ON ingest.book_import_divergences (source_id);
CREATE INDEX IF NOT EXISTS book_import_divergences_run_idx ON ingest.book_import_divergences (run_id);
CREATE INDEX IF NOT EXISTS book_import_divergences_ligne_idx ON ingest.book_import_divergences (staging_row_id);
CREATE INDEX IF NOT EXISTS book_import_divergences_base_idx ON ingest.book_import_divergences (baseline_id);
CREATE INDEX IF NOT EXISTS book_import_divergences_draft_idx ON ingest.book_import_divergences (draft_id);
CREATE INDEX IF NOT EXISTS book_import_divergences_ouvertes_idx
  ON ingest.book_import_divergences (vue_le DESC) WHERE statut = 'ouverte';

COMMENT ON TABLE ingest.book_import_divergences IS
  'H21 lot 5 (07/10/2026, IMP-26 b/c, IMP-32) : ce qu''un réimport a trouvé de différent sur une notice PARTAGÉE '
  '(jamais réécrite) — une ligne par (notice, bibliothèque qui importe, champ) ouverte au plus ; posée et tenue à jour '
  'par ingest.fn_h21_constater_divergences (fn_import_recomparer, fn_import_preparer_mises_a_jour) ; écartée '
  '(fn_divergences_ecarter : la base avance à N pour ce champ) ou appliquée (fn_divergences_appliquer : brouillon de '
  'reprise prérempli ; « appliquee » à sa première publication) par la coordination d''une détentrice ou '
  'l''administration ; resolue (le champ est revenu égal) ou caduque (notice redevenue non partagée) par le constat. '
  'Paquet INGEST-RLS (schéma fermé, 29/08/2026) : RLS sans politique, aucun droit pour anon ni authenticated — accès par '
  'les fonctions DEFINER ci-dessus (portée : coordination d''une bibliothèque détentrice, ou administration du réseau) ; service_role. '
  'Sauvegarde #BG2 : flux long (schéma ingest).';
COMMENT ON COLUMN ingest.book_import_divergences.library_id IS
  'La bibliothèque qui importe (ingest.fn_h21_bibliotheque_importatrice) — pas une détentrice : les détentrices se lisent dans book_holdings.';
COMMENT ON COLUMN ingest.book_import_divergences.draft_id IS
  'Le brouillon de reprise prérempli qui applique cette divergence (fn_divergences_appliquer) ; seule preuve que lit la publication.';

ALTER TABLE ingest.book_import_divergences ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ingest.book_import_divergences FROM PUBLIC, anon, authenticated;
GRANT ALL ON ingest.book_import_divergences TO service_role;


-- ─────────────────────────────────────────────────────────────────────
-- 2. Les aides : empreinte d'une valeur, valeur de base d'un champ, partage,
--    avance de la base pour un champ
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION ingest.fn_h21_empreinte_valeur(p jsonb)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
 SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
  select md5(coalesce(nullif(p, 'null'::jsonb)::text, 'null'));
$function$;
COMMENT ON FUNCTION ingest.fn_h21_empreinte_valeur(jsonb) IS
  'H21 lot 5 (07/10/2026) : empreinte d''une valeur normalisée d''un champ comparé (NULL et null JSON confondus). Interne.';

-- B d'un champ, normalisé comme la comparaison (lot 3).
CREATE OR REPLACE FUNCTION ingest.fn_h21_valeur_de_base(p_baseline_id bigint, p_champ text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select nullif(ingest.fn_h21_normaliser(jsonb_build_object('mapped', bl.mapped, 'contributors', bl.contributors)) -> p_champ,
                'null'::jsonb)
    from ingest.book_import_baselines bl
   where bl.id = p_baseline_id;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_valeur_de_base(bigint, text) IS
  'H21 lot 5 (07/10/2026) : la valeur normalisée d''un champ d''une base (ingest.book_import_baselines), comme la lit la comparaison. Interne.';

-- La notice est-elle partagée (plus d'une détentrice, book_holdings) ?
CREATE OR REPLACE FUNCTION ingest.fn_h21_notice_partagee(p_book_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select (select count(distinct h.library_id) from public.book_holdings h where h.book_id = p_book_id) > 1;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_notice_partagee(bigint) IS
  'H21 lot 5 (07/10/2026) : plus d''une bibliothèque détient la notice (book_holdings — jamais owner_library_id). Interne.';

-- La base de la divergence avance à N pour CE champ seul (IMP-26 c ; même
-- règle que le lot 4 : mapped ou responsabilités, champ douteux levé).
-- p_verifier : la base de ce champ doit être encore celle du constat
-- (empreinte_base) — sinon 'perimee', rien d'écrit. Rend 'avancee',
-- 'sans_base' (pas de base à avancer) ou 'perimee'.
CREATE OR REPLACE FUNCTION ingest.fn_h21_divergence_avancer_base(p_divergence_id bigint, p_verifier boolean)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_d ingest.book_import_divergences%rowtype;
  v_bl ingest.book_import_baselines%rowtype;
  v_douteux text[];
begin
  select * into v_d from ingest.book_import_divergences where id = p_divergence_id;
  if not found or v_d.baseline_id is null then
    return 'sans_base';
  end if;
  select * into v_bl from ingest.book_import_baselines where id = v_d.baseline_id for update;
  if not found then
    return 'sans_base';
  end if;
  if p_verifier
     and ingest.fn_h21_empreinte_valeur(ingest.fn_h21_valeur_de_base(v_bl.id, v_d.champ)) is distinct from v_d.empreinte_base then
    return 'perimee';
  end if;
  v_douteux := array_remove(v_bl.reprise_champs_douteux, v_d.champ);
  update ingest.book_import_baselines bl
     set mapped = case when v_d.champ = 'contributors' then bl.mapped
                       when v_d.valeur_fichier is null or v_d.valeur_fichier = 'null'::jsonb then bl.mapped - v_d.champ
                       else jsonb_set(bl.mapped, array[v_d.champ], v_d.valeur_fichier) end,
         -- les responsabilités : la liste ordonnée [nom, rôle] du fichier,
         -- rendue à la forme de la base (fn_h21_responsabilites la relit pareil)
         contributors = case when v_d.champ <> 'contributors' then bl.contributors
                             else coalesce((select jsonb_agg(jsonb_build_object('position', x.o, 'name', x.v->>0, 'role', x.v->>1)
                                                             order by x.o)
                                              from jsonb_array_elements(case when jsonb_typeof(v_d.valeur_fichier) = 'array'
                                                                             then v_d.valeur_fichier else '[]'::jsonb end)
                                                   with ordinality x(v, o)), '[]'::jsonb) end,
         reprise_champs_douteux = v_douteux,
         origine = case when cardinality(v_douteux) = 0 then 'import' else bl.origine end,
         confirmed_at = now(),
         updated_at = now()
   where bl.id = v_bl.id;
  return 'avancee';
end;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_divergence_avancer_base(bigint, boolean) IS
  'H21 lot 5 (07/10/2026, IMP-26 c) : la base de la divergence avance à N pour ce champ seul (écarter, appliquer) ; p_verifier : refuse (perimee) si la base de ce champ a changé depuis le constat. Interne.';


-- ─────────────────────────────────────────────────────────────────────
-- 3. Le constat
-- ─────────────────────────────────────────────────────────────────────
-- Sur les lignes du périmètre (p_row_ids NULL : tout le run) : voir l'en-tête,
-- 2. Rend {posees, mises_a_jour, resolues, caduques, notices_partagees}.
CREATE OR REPLACE FUNCTION ingest.fn_h21_constater_divergences(p_run_id bigint, p_row_ids bigint[] DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_lib uuid;
  v_src bigint;
  v_caduques integer := 0;
  v_resolues integer := 0;
  v_maj integer := 0;
  v_posees integer := 0;
  v_partagees integer := 0;
begin
  select r.source_id into v_src from ingest.partner_catalog_import_runs r where r.id = p_run_id;
  if not found then
    return jsonb_build_object('posees', 0, 'mises_a_jour', 0, 'resolues', 0, 'caduques', 0, 'notices_partagees', 0);
  end if;
  v_lib := ingest.fn_h21_bibliotheque_importatrice(p_run_id, NULL, NULL);
  if v_lib is null then
    return jsonb_build_object('posees', 0, 'mises_a_jour', 0, 'resolues', 0, 'caduques', 0, 'notices_partagees', 0);
  end if;

  -- (a) les notices du périmètre qui ne sont plus partagées : toutes leurs
  --     divergences ouvertes sont caduques
  update ingest.book_import_divergences d
     set statut = 'caduque', traitee_le = now(), updated_at = now()
   where d.statut = 'ouverte'
     and d.book_id in (select sr.proposed_book_id
                         from ingest.partner_catalog_staging_rows sr
                        where sr.run_id = p_run_id
                          and (p_row_ids is null or sr.id = any (p_row_ids))
                          and sr.match_status = 'known_record' and sr.proposed_book_id is not null
                          and not ingest.fn_h21_notice_partagee(sr.proposed_book_id));
  get diagnostics v_caduques = row_count;

  -- (b) les champs des notices partagées : une ligne par (notice, champ) — la
  --     ligne la plus récente si deux lignes du run visent la même notice
  --     (une seule instruction : les CTE voient le même instantané ; leurs
  --     clés sont disjointes — résolues hors verdicts signalés, tenues et
  --     posées dans les verdicts signalés)
  with lignes as materialized (
    select sr.id, sr.proposed_book_id as book_id, sr.comparaison as c
      from ingest.partner_catalog_staging_rows sr
     where sr.run_id = p_run_id
       and (p_row_ids is null or sr.id = any (p_row_ids))
       and sr.match_status = 'known_record' and sr.proposed_book_id is not null
       and sr.comparaison is not null
       and (sr.comparaison->>'book_id') = sr.proposed_book_id::text
       and ingest.fn_h21_notice_partagee(sr.proposed_book_id)
  ), champs as materialized (
    select distinct on (l.book_id, x.v->>'champ')
           l.id as row_id, l.book_id, nullif(l.c->>'baseline_id', '')::bigint as baseline_id,
           x.v->>'champ' as champ, x.v->>'verdict' as verdict,
           nullif(x.v->'b', 'null'::jsonb) as b, nullif(x.v->'a', 'null'::jsonb) as a, nullif(x.v->'n', 'null'::jsonb) as n
      from lignes l
      cross join jsonb_array_elements(l.c->'champs') x(v)
     order by l.book_id, x.v->>'champ', l.id desc
  ), resolues as (
    update ingest.book_import_divergences d
       set statut = 'resolue', traitee_le = now(), updated_at = now(),
           run_id = p_run_id, staging_row_id = c.row_id, vue_le = now()
      from champs c
     where d.statut = 'ouverte' and d.book_id = c.book_id and d.library_id = v_lib and d.champ = c.champ
       and c.verdict not in ('source_seule', 'conflit', 'sans_base')
    returning 1
  ), tenues as (
    update ingest.book_import_divergences d
       set verdict = c.verdict, valeur_base = c.b, valeur_anarbib = c.a, valeur_fichier = c.n,
           empreinte_base = ingest.fn_h21_empreinte_valeur(c.b), empreinte_fichier = ingest.fn_h21_empreinte_valeur(c.n),
           source_id = v_src, run_id = p_run_id, staging_row_id = c.row_id, baseline_id = c.baseline_id,
           vue_le = now(), updated_at = now()
      from champs c
     where d.statut = 'ouverte' and d.book_id = c.book_id and d.library_id = v_lib and d.champ = c.champ
       and c.verdict in ('source_seule', 'conflit', 'sans_base')
    returning 1
  ), posees as (
    insert into ingest.book_import_divergences
      (book_id, library_id, source_id, run_id, staging_row_id, baseline_id, champ, verdict,
       valeur_base, valeur_anarbib, valeur_fichier, empreinte_base, empreinte_fichier)
    select c.book_id, v_lib, v_src, p_run_id, c.row_id, c.baseline_id, c.champ, c.verdict,
           c.b, c.a, c.n, ingest.fn_h21_empreinte_valeur(c.b), ingest.fn_h21_empreinte_valeur(c.n)
      from champs c
     where c.verdict in ('source_seule', 'conflit', 'sans_base')
       and not exists (select 1 from ingest.book_import_divergences d
                        where d.statut = 'ouverte' and d.book_id = c.book_id and d.library_id = v_lib and d.champ = c.champ)
       -- IMP-26 c : écartée au même N, elle ne revient pas
       and coalesce((select d.statut = 'ecartee' and d.empreinte_fichier = ingest.fn_h21_empreinte_valeur(c.n)
                       from ingest.book_import_divergences d
                      where d.book_id = c.book_id and d.library_id = v_lib and d.champ = c.champ
                      order by d.id desc limit 1), false) is false
    on conflict (book_id, library_id, champ) where statut = 'ouverte' do nothing
    returning 1
  )
  select (select count(*) from resolues), (select count(*) from tenues), (select count(*) from posees),
         (select count(distinct book_id) from champs)
    into v_resolues, v_maj, v_posees, v_partagees;

  return jsonb_build_object('posees', v_posees, 'mises_a_jour', v_maj, 'resolues', v_resolues,
                            'caduques', v_caduques, 'notices_partagees', v_partagees);
end;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_constater_divergences(bigint, bigint[]) IS
  'H21 lot 5 (07/10/2026, IMP-26 b/c, IMP-32) : à partir des comparaisons stockées (lot 3) des lignes known_record du périmètre, pose ou tient à jour les divergences des notices PARTAGÉES (source_seule, conflit, sans_base ; pas une écartée au même N), résout celles dont le champ est revenu égal, rend caduques celles des notices redevenues non partagées. N''écrit rien au catalogue. Interne : fn_import_recomparer, fn_import_preparer_mises_a_jour.';


-- ─────────────────────────────────────────────────────────────────────
-- 4. Lire
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_divergences_a_traiter(p_library_id uuid DEFAULT NULL, p_limit integer DEFAULT 50,
                                                           p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
DECLARE
  v_admin boolean := coalesce(public.fn_caller_is_network_admin(), false);
  v_coord uuid[] := coalesce(public.fn_caller_coordinator_library_ids(), '{}'::uuid[]);
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_res jsonb;
BEGIN
  -- La coordination d'une détentrice, ou l'administration du réseau (IMP-32 a) ;
  -- le librarian et la lectrice ne voient rien (choix de l'en-tête, 3).
  IF auth.uid() IS NULL OR (NOT v_admin AND cardinality(v_coord) = 0)
     OR (p_library_id IS NOT NULL AND NOT v_admin AND NOT (p_library_id = ANY (v_coord))) THEN
    RETURN jsonb_build_object('total', 0, 'divergences', 0, 'notices', '[]'::jsonb);
  END IF;

  WITH vis AS MATERIALIZED (
    SELECT d.id, d.book_id, d.library_id, d.champ, d.verdict, d.vue_le
      FROM ingest.book_import_divergences d
     WHERE d.statut = 'ouverte'
       AND ingest.fn_h21_notice_partagee(d.book_id)
       AND (p_library_id IS NULL
            OR EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = d.book_id AND h.library_id = p_library_id))
       AND (v_admin
            OR EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = d.book_id AND h.library_id = ANY (v_coord)))
  ), grp AS MATERIALIZED (
    SELECT v.book_id, v.library_id, count(*)::integer AS n, max(v.vue_le) AS vue_le,
           jsonb_agg(jsonb_build_object('id', v.id, 'champ', v.champ, 'verdict', v.verdict)
                     ORDER BY array_position(ingest.fn_h21_champs_compares(), v.champ), v.id) AS champs
      FROM vis v
     GROUP BY v.book_id, v.library_id
  ), page AS (
    SELECT g.* FROM grp g ORDER BY g.vue_le DESC, g.book_id, g.library_id LIMIT v_limit OFFSET v_offset
  )
  SELECT jsonb_build_object(
           'total', (SELECT count(*) FROM grp),
           'divergences', (SELECT count(*) FROM vis),
           'notices', coalesce((
             SELECT jsonb_agg(jsonb_build_object(
                      'book_id', p.book_id, 'titulo', b.titulo, 'bib_ref', b.bib_ref,
                      'library_id', p.library_id, 'library_name', l.name,
                      'count', p.n, 'champs', p.champs, 'vue_le', p.vue_le,
                      'draft_id', (SELECT max(dr.id) FROM public.book_drafts dr
                                    WHERE dr.published_book_id = p.book_id AND dr.status IN ('draft', 'ready')
                                      AND coalesce(dr.marc_json, '{}'::jsonb) ? 'ingest_divergence'
                                      -- B2 (b) : un brouillon auquel une divergence est liée
                                      AND EXISTS (SELECT 1 FROM ingest.book_import_divergences x WHERE x.draft_id = dr.id)))
                    ORDER BY p.vue_le DESC, p.book_id, p.library_id)
               FROM page p
               JOIN public.books b ON b.id = p.book_id
               LEFT JOIN public.libraries l ON l.id = p.library_id), '[]'::jsonb))
    INTO v_res;
  RETURN v_res;
END;
$function$;
COMMENT ON FUNCTION public.fn_divergences_a_traiter(uuid, integer, integer) IS
  'H21 lot 5 (07/10/2026, IMP-32 a) : les divergences ouvertes des notices partagées que détient une bibliothèque dont l''appelant est la coordination (toutes pour l''administration du réseau ; p_library_id : une détentrice), groupées par notice et bibliothèque qui importe ; total. Vide pour qui n''est ni coordination ni administration.';

CREATE OR REPLACE FUNCTION public.fn_notice_divergences(p_book_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
DECLARE
  v_admin boolean := coalesce(public.fn_caller_is_network_admin(), false);
  v_coord uuid[] := coalesce(public.fn_caller_coordinator_library_ids(), '{}'::uuid[]);
  v_active uuid;
  v_livre jsonb;
  v_ac jsonb;
  v_groupes jsonb;
  v_draft jsonb;
BEGIN
  -- Ni coordination d'une détentrice ni administration : vide, sans rien dire
  -- de la notice (IMP-32 a ; le librarian ne voit rien — en-tête, 3).
  IF auth.uid() IS NULL
     OR NOT (v_admin OR EXISTS (SELECT 1 FROM public.book_holdings h
                                 WHERE h.book_id = p_book_id AND h.library_id = ANY (v_coord))) THEN
    RETURN jsonb_build_object('book_id', p_book_id, 'groupes', '[]'::jsonb);
  END IF;
  SELECT to_jsonb(b) INTO v_livre FROM public.books b WHERE b.id = p_book_id;
  IF v_livre IS NULL OR NOT ingest.fn_h21_notice_partagee(p_book_id) THEN
    RETURN jsonb_build_object('book_id', p_book_id, 'groupes', '[]'::jsonb);
  END IF;
  -- A actuelle, normalisée comme la comparaison (responsabilités : book_contributors)
  v_ac := ingest.fn_h21_responsabilites(coalesce(
            (SELECT jsonb_agg(jsonb_build_object('position', c.position, 'name', c.name, 'role', c.role) ORDER BY c.position)
               FROM public.book_contributors c WHERE c.book_id = p_book_id), '[]'::jsonb));

  SELECT coalesce(jsonb_agg(g.groupe ORDER BY g.vue_le DESC, g.library_id), '[]'::jsonb) INTO v_groupes
    FROM (SELECT d.library_id, max(d.vue_le) AS vue_le,
                 jsonb_build_object(
                   'library_id', d.library_id,
                   'library_name', (SELECT l.name FROM public.libraries l WHERE l.id = d.library_id),
                   'count', count(*),
                   'champs', jsonb_agg(jsonb_build_object(
                               'id', d.id, 'champ', d.champ, 'verdict', d.verdict,
                               'b', d.valeur_base, 'a_constat', d.valeur_anarbib, 'n', d.valeur_fichier,
                               'a', CASE d.champ WHEN 'contributors' THEN v_ac
                                                 ELSE to_jsonb(nullif(btrim(v_livre->>d.champ), '')) END,
                               'vue_le', d.vue_le, 'draft_id', d.draft_id,
                               'applicable', d.champ <> 'contributors' AND d.valeur_fichier IS NOT NULL
                                             AND d.valeur_fichier <> 'null'::jsonb,
                               'raison', CASE WHEN d.champ = 'contributors' THEN 'responsabilites'
                                              WHEN d.valeur_fichier IS NULL OR d.valeur_fichier = 'null'::jsonb
                                              THEN 'efface_par_la_source' END)
                             ORDER BY array_position(ingest.fn_h21_champs_compares(), d.champ), d.id)) AS groupe
            FROM ingest.book_import_divergences d
           WHERE d.book_id = p_book_id AND d.statut = 'ouverte'
           GROUP BY d.library_id) g;

  SELECT jsonb_build_object('id', dr.id, 'status', dr.status, 'library_id', dr.owner_library_id) INTO v_draft
    FROM public.book_drafts dr
   WHERE dr.published_book_id = p_book_id AND dr.status IN ('draft', 'ready')
     AND coalesce(dr.marc_json, '{}'::jsonb) ? 'ingest_divergence'
     -- B2 (b) : un brouillon auquel une divergence est liée (draft_id)
     AND EXISTS (SELECT 1 FROM ingest.book_import_divergences x WHERE x.draft_id = dr.id)
   ORDER BY dr.id DESC LIMIT 1;

  SELECT a.library_id INTO v_active FROM public.my_access a LIMIT 1;
  RETURN jsonb_build_object(
    'book_id', p_book_id,
    'titulo', v_livre->>'titulo',
    'bib_ref', v_livre->>'bib_ref',
    'groupes', v_groupes,
    'draft', v_draft,
    -- appliquer : la bibliothèque active de l'appelant détient la notice et il
    -- en est la coordination (ou l'administration) — en-tête, 5
    'can_apply', v_active IS NOT NULL
                 AND EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = p_book_id AND h.library_id = v_active)
                 AND (v_admin OR v_active = ANY (v_coord)),
    'active_library_id', v_active);
END;
$function$;
COMMENT ON FUNCTION public.fn_notice_divergences(bigint) IS
  'H21 lot 5 (07/10/2026, IMP-32 a) : les divergences ouvertes d''une notice partagée, par bibliothèque qui importe, champ par champ (base, AnarBib actuelle et au constat, fichier, verdict, applicable ou montré) ; le brouillon de reprise vivant ; can_apply. Vide ({book_id, groupes: []}) pour qui n''est ni coordination d''une détentrice ni administration. Aucune autre donnée de la ligne d''import.';


-- ─────────────────────────────────────────────────────────────────────
-- 5. Écarter
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_divergences_ecarter(p_ids bigint[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_admin boolean := coalesce(public.fn_caller_is_network_admin(), false);
  v_coord uuid[] := coalesce(public.fn_caller_coordinator_library_ids(), '{}'::uuid[]);
  v_ids bigint[];
  v_d ingest.book_import_divergences%rowtype;
  v_x bigint;
  v_raison text;
  v_base text;
  v_skipped jsonb := '{}'::jsonb;
  v_faites bigint[] := '{}'::bigint[];
BEGIN
  IF v_uid IS NULL OR (NOT v_admin AND cardinality(v_coord) = 0) THEN
    RAISE EXCEPTION 'Acesso restrito a coordenacao de uma biblioteca detentora.' USING HINT = 'error.divergence.coord_only';
  END IF;
  IF coalesce(cardinality(p_ids), 0) > 200 THEN
    RAISE EXCEPTION 'No maximo 200 divergencias por chamada.' USING HINT = 'error.divergence.page_too_large';
  END IF;
  v_ids := ARRAY(SELECT DISTINCT x FROM unnest(coalesce(p_ids, '{}'::bigint[])) x WHERE x IS NOT NULL ORDER BY x);

  FOREACH v_x IN ARRAY v_ids LOOP
    v_raison := NULL;
    SELECT * INTO v_d FROM ingest.book_import_divergences WHERE id = v_x FOR UPDATE;
    IF NOT FOUND THEN
      v_raison := 'introuvable';
    -- la portée d'abord : rien ne se dit d'une divergence hors de portée
    ELSIF NOT v_admin AND NOT EXISTS (SELECT 1 FROM public.book_holdings h
                                       WHERE h.book_id = v_d.book_id AND h.library_id = ANY (v_coord)) THEN
      v_raison := 'pas_detentrice';
    ELSIF v_d.statut <> 'ouverte' THEN
      v_raison := 'pas_ouverte';
    ELSIF NOT ingest.fn_h21_notice_partagee(v_d.book_id) THEN
      v_raison := 'non_partagee';
      UPDATE ingest.book_import_divergences SET statut = 'caduque', traitee_le = now(), updated_at = now() WHERE id = v_x;
    ELSE
      v_base := ingest.fn_h21_divergence_avancer_base(v_x, true);
      IF v_base = 'perimee' THEN
        v_raison := 'perimee';
      ELSE
        UPDATE ingest.book_import_divergences
           SET statut = 'ecartee', traitee_par = v_uid, traitee_le = now(), updated_at = now(),
               base_avancee = (v_base = 'avancee')
         WHERE id = v_x;
        v_faites := v_faites || v_x;
      END IF;
    END IF;
    IF v_raison IS NOT NULL THEN
      v_skipped := v_skipped || jsonb_build_object(v_raison, coalesce((v_skipped->>v_raison)::int, 0) + 1);
    END IF;
  END LOOP;

  RETURN jsonb_build_object('asked', cardinality(v_ids), 'ecartees', cardinality(v_faites),
                            'skipped_rows', cardinality(v_ids) - cardinality(v_faites),
                            'skipped', v_skipped, 'ids', to_jsonb(v_faites));
END;
$function$;
COMMENT ON FUNCTION public.fn_divergences_ecarter(bigint[]) IS
  'H21 lot 5 (07/10/2026, IMP-26 c, IMP-32 c) : écarte des divergences ouvertes (200 au plus) — la base avance à N pour ces champs seuls ; les autres sont ignorées avec leur raison. Coordination d''une détentrice de la notice, ou administration du réseau.';


-- ─────────────────────────────────────────────────────────────────────
-- 6. Appliquer : un brouillon de reprise prérempli
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_divergences_appliquer(p_book_id bigint, p_ids bigint[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_actor public.my_access%rowtype;
  v_lib uuid;
  v_ids bigint[];
  v_bib_ref text;
  v_existant bigint;
  v_skipped jsonb := '{}'::jsonb;
  v_appl jsonb := '[]'::jsonb;
  v_montres jsonb := '[]'::jsonb;
  v_appl_ids bigint[] := '{}'::bigint[];
  v_raison text;
  v_draft bigint;
  v_set text;
  v_n_set integer;
  v_trace jsonb;
  v_x bigint;
  v_d ingest.book_import_divergences%rowtype;
BEGIN
  -- La bibliothèque ACTIVE de l'appelant (choix de l'en-tête, 5) : sa
  -- coordination, ou l'administration du réseau dont c'est la bibliothèque active.
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.' USING HINT = 'error.divergence.coord_only';
  END IF;
  v_lib := v_actor.library_id;
  IF NOT (v_lib = ANY (coalesce(public.fn_caller_coordinator_library_ids(), '{}'::uuid[]))
          OR public.fn_caller_is_network_admin()) THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.' USING HINT = 'error.divergence.coord_only';
  END IF;
  IF coalesce(cardinality(p_ids), 0) > 200 THEN
    RAISE EXCEPTION 'No maximo 200 divergencias por chamada.' USING HINT = 'error.divergence.page_too_large';
  END IF;
  v_ids := ARRAY(SELECT DISTINCT x FROM unnest(coalesce(p_ids, '{}'::bigint[])) x WHERE x IS NOT NULL ORDER BY x);
  IF cardinality(v_ids) = 0 THEN
    RAISE EXCEPTION 'Nenhuma divergencia selecionada.' USING HINT = 'error.divergence.nothing_to_apply';
  END IF;

  -- deux préparations de la même notice s'attendent ; la notice verrouillée
  PERFORM pg_advisory_xact_lock(hashtextextended('h21-lot5/notice/' || p_book_id, 0));
  SELECT b.bib_ref INTO v_bib_ref FROM public.books b WHERE b.id = p_book_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ficha % inexistente.', p_book_id USING HINT = 'error.divergence.record_gone';
  END IF;
  -- la bibliothèque active détient la notice (book_holdings, piège 18)
  IF NOT EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = p_book_id AND h.library_id = v_lib) THEN
    RAISE EXCEPTION 'Sua biblioteca ativa nao detem esta ficha.' USING HINT = 'error.divergence.not_holder';
  END IF;
  -- un seul brouillon de reprise vivant issu d'une divergence, par notice
  SELECT max(d.id) INTO v_existant
    FROM public.book_drafts d
   WHERE d.published_book_id = p_book_id AND d.status IN ('draft', 'ready')
     AND coalesce(d.marc_json, '{}'::jsonb) ? 'ingest_divergence'
     -- B2 (b) : seul un brouillon auquel une divergence est liée (draft_id, que
     -- l'API n'écrit pas) bloque — jamais un brouillon posé par d'autres mains
     AND EXISTS (SELECT 1 FROM ingest.book_import_divergences x WHERE x.draft_id = d.id);
  IF v_existant IS NOT NULL THEN
    RAISE EXCEPTION 'Ja existe um rascunho de retomada desta divergencia (%).', v_existant
      USING HINT = 'error.divergence.draft_exists', DETAIL = v_existant::text;
  END IF;

  FOREACH v_x IN ARRAY v_ids LOOP
    v_raison := NULL;
    SELECT * INTO v_d FROM ingest.book_import_divergences WHERE id = v_x FOR UPDATE;
    IF NOT FOUND OR v_d.book_id IS DISTINCT FROM p_book_id THEN
      v_raison := 'autre_notice';
    ELSIF v_d.statut <> 'ouverte' THEN
      v_raison := 'pas_ouverte';
    ELSIF NOT ingest.fn_h21_notice_partagee(p_book_id) THEN
      v_raison := 'non_partagee';
    ELSIF v_d.champ = 'contributors' OR v_d.valeur_fichier IS NULL OR v_d.valeur_fichier = 'null'::jsonb THEN
      -- montrés, jamais préremplis (IMP-31 b, IMP-32 b)
      v_montres := v_montres || jsonb_build_array(jsonb_build_object(
                     'id', v_d.id, 'champ', v_d.champ, 'verdict', v_d.verdict, 'b', v_d.valeur_base,
                     'a', v_d.valeur_anarbib, 'n', v_d.valeur_fichier,
                     'raison', CASE WHEN v_d.champ = 'contributors' THEN 'responsabilites' ELSE 'efface_par_la_source' END));
    ELSE
      v_appl := v_appl || jsonb_build_array(jsonb_build_object(
                  'id', v_d.id, 'champ', v_d.champ, 'verdict', v_d.verdict, 'library_id', v_d.library_id,
                  'b', v_d.valeur_base, 'a', v_d.valeur_anarbib, 'n', v_d.valeur_fichier,
                  'empreinte_base', v_d.empreinte_base, 'empreinte_fichier', v_d.empreinte_fichier));
      v_appl_ids := v_appl_ids || v_d.id;
    END IF;
    IF v_raison IS NOT NULL THEN
      v_skipped := v_skipped || jsonb_build_object(v_raison, coalesce((v_skipped->>v_raison)::int, 0) + 1);
    END IF;
  END LOOP;

  IF jsonb_array_length(v_appl) = 0 THEN
    RAISE EXCEPTION 'Nada a preencher: responsabilidades e campos esvaziados pela fonte se retomam a mao.'
      USING HINT = 'error.divergence.nothing_to_apply';
  END IF;
  -- deux divergences du même champ (deux bibliothèques qui importent, deux
  -- valeurs) ne préremplissent pas la même colonne
  IF (SELECT count(DISTINCT x->>'champ') FROM jsonb_array_elements(v_appl) x) <> jsonb_array_length(v_appl) THEN
    RAISE EXCEPTION 'Duas divergencias do mesmo campo: escolha uma.' USING HINT = 'error.divergence.same_field_twice';
  END IF;

  v_trace := jsonb_build_object(
    'version', 'h21-lot5/2026-10-07',
    'book_id', p_book_id,
    'library_id', v_lib,
    'bib_ref', v_bib_ref,
    'empreinte_notice', ingest.fn_h21_empreinte_notice(p_book_id),
    'prepared_at', now(),
    'prepared_by', v_actor.user_id,
    'divergence_ids', to_jsonb(v_appl_ids),
    'appliques', v_appl,
    'montres', v_montres);

  -- la copie complète de la notice (lot 4), sans lot, pour la bibliothèque active
  v_draft := ingest.fn_h21_copie_de_la_notice(p_book_id, NULL, v_lib, v_actor.user_id);

  -- le patch : les seuls champs choisis applicables, valeur N normalisée, au
  -- type de la colonne du brouillon
  SELECT string_agg(format('%I = %L::%s', x->>'champ', x->>'n', format_type(a.atttypid, a.atttypmod)), ', '),
         count(*)
    INTO v_set, v_n_set
    FROM jsonb_array_elements(v_appl) x
    JOIN pg_catalog.pg_attribute a ON a.attrelid = 'public.book_drafts'::regclass
                                  AND a.attname = x->>'champ' AND a.attnum > 0 AND NOT a.attisdropped;
  IF v_n_set IS DISTINCT FROM jsonb_array_length(v_appl) THEN
    RAISE EXCEPTION 'H21 lot 5 : champ sans colonne au brouillon (%/%)', v_n_set, jsonb_array_length(v_appl);
  END IF;
  EXECUTE format('UPDATE public.book_drafts SET %s, marc_json = (coalesce(marc_json, ''{}''::jsonb) - ''ingest_divergence'') || jsonb_build_object(''ingest_divergence'', $2::jsonb) WHERE id = $1', v_set)
    USING v_draft, v_trace;

  UPDATE ingest.book_import_divergences SET draft_id = v_draft, updated_at = now() WHERE id = ANY (v_appl_ids);

  RETURN jsonb_build_object(
    'draft_id', v_draft,
    'book_id', p_book_id,
    'library_id', v_lib,
    'applied', (SELECT coalesce(jsonb_agg(x->'champ'), '[]'::jsonb) FROM jsonb_array_elements(v_appl) x),
    'shown', (SELECT coalesce(jsonb_agg(jsonb_build_object('champ', x->'champ', 'raison', x->'raison')), '[]'::jsonb)
                FROM jsonb_array_elements(v_montres) x),
    'skipped', v_skipped);
END;
$function$;
COMMENT ON FUNCTION public.fn_divergences_appliquer(bigint, bigint[]) IS
  'H21 lot 5 (07/10/2026, IMP-32 b) : un brouillon de reprise de la notice partagée, prérempli des seuls champs choisis applicables (valeur du fichier ; responsabilités et effacements montrés, jamais préremplis), pour la bibliothèque active de l''appelant, qui doit détenir la notice et en être la coordination (ou l''administration) ; trace marc_json.ingest_divergence. Rend draft_id. La détentrice relit et publie (publish_book_draft).';


-- ─────────────────────────────────────────────────────────────────────
-- 7. La garde de publication, l'après-publication
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION ingest.fn_h21_garde_divergence(p_draft_id bigint, p_republication boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_d public.book_drafts%rowtype;
  v_u jsonb;
  v_lib uuid;
  v_bib_ref text;
begin
  select * into v_d from public.book_drafts where id = p_draft_id;
  v_u := v_d.marc_json -> 'ingest_divergence';
  if v_u is null then
    return;
  end if;
  -- la notice a disparu : jamais la branche création
  if v_d.published_book_id is null then
    raise exception 'divergencia_sem_ficha' using hint = 'error.divergence.record_gone';
  end if;
  select b.bib_ref into v_bib_ref from public.books b where b.id = v_d.published_book_id for update;
  if not found then
    raise exception 'divergencia_sem_ficha' using hint = 'error.divergence.record_gone';
  end if;
  if v_d.published_book_id::text is distinct from v_u->>'book_id' then
    raise exception 'divergencia_ficha_alterada' using hint = 'error.divergence.record_changed';
  end if;
  -- la bibliothèque du brouillon : celle de la trace, détentrice (piège 18)
  v_lib := nullif(v_u->>'library_id', '')::uuid;
  if v_lib is null or v_d.owner_library_id is distinct from v_lib
     or not exists (select 1 from public.book_holdings h where h.book_id = v_d.published_book_id and h.library_id = v_lib) then
    raise exception 'divergencia_biblioteca_nao_detentora' using hint = 'error.divergence.not_holder';
  end if;
  -- bib_ref : celui de la notice (piège 12)
  if v_d.bib_ref is distinct from v_bib_ref then
    raise exception 'divergencia_bib_ref_alterada' using hint = 'error.divergence.bib_ref_changed';
  end if;
  if p_republication then
    return;
  end if;
  -- le geste a posé la trace : des divergences désignent ce brouillon
  if not exists (select 1 from ingest.book_import_divergences x where x.draft_id = p_draft_id) then
    raise exception 'divergencia_sem_vinculo' using hint = 'error.divergence.draft_unlinked';
  end if;
  -- la notice n'a pas changé depuis le préremplissage (empreinte de A, lot 4)
  if ingest.fn_h21_empreinte_notice(v_d.published_book_id) is distinct from v_u->>'empreinte_notice' then
    raise exception 'divergencia_ficha_alterada' using hint = 'error.divergence.record_changed';
  end if;
end;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_garde_divergence(bigint, boolean) IS
  'H21 lot 5 (07/10/2026) : garde de la publication d''un brouillon de reprise prérempli depuis des divergences (trace marc_json.ingest_divergence) — notice présente, bibliothèque de la trace détentrice et celle du brouillon, bib_ref ; à la première publication, lien des divergences et empreinte de la notice. Interne : publish_book_draft, avant le choix de branche.';

CREATE OR REPLACE FUNCTION ingest.fn_h21_divergences_apres_publication(p_draft_id bigint, p_book_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_u jsonb;
  v_a jsonb;
  v_x jsonb;
  v_d ingest.book_import_divergences%rowtype;
  v_appliquees bigint[] := '{}'::bigint[];
  v_gardees jsonb := '[]'::jsonb;
  v_base text;
  v_res jsonb;
begin
  select d.marc_json->'ingest_divergence' into v_u from public.book_drafts d where d.id = p_draft_id;
  if v_u is null then
    return null;
  end if;
  select to_jsonb(b) into v_a from public.books b where b.id = p_book_id;
  for v_x in select x from jsonb_array_elements(coalesce(v_u->'appliques', '[]'::jsonb)) x loop
    select * into v_d from ingest.book_import_divergences
     where id = (v_x->>'id')::bigint for update;
    if not found or v_d.draft_id is distinct from p_draft_id or v_d.statut <> 'ouverte'
       or v_d.empreinte_fichier is distinct from v_x->>'empreinte_fichier' then
      v_gardees := v_gardees || jsonb_build_array(jsonb_build_object('id', v_x->'id', 'champ', v_x->'champ', 'raison', 'plus_ouverte'));
      continue;
    end if;
    -- la notice publiée dit-elle le fichier ? (retouchée dans le brouillon : non)
    if to_jsonb(nullif(btrim(v_a->>v_d.champ), '')) is distinct from nullif(v_d.valeur_fichier, 'null'::jsonb) then
      v_gardees := v_gardees || jsonb_build_array(jsonb_build_object('id', v_d.id, 'champ', v_d.champ, 'raison', 'retouchee'));
      continue;
    end if;
    v_base := ingest.fn_h21_divergence_avancer_base(v_d.id, false);
    update ingest.book_import_divergences
       set statut = 'appliquee', traitee_par = auth.uid(), traitee_le = now(), updated_at = now(),
           base_avancee = (v_base = 'avancee'), valeur_anarbib = to_jsonb(nullif(btrim(v_a->>v_d.champ), ''))
     where id = v_d.id;
    v_appliquees := v_appliquees || v_d.id;
  end loop;
  v_res := jsonb_build_object('appliquees', to_jsonb(v_appliquees), 'gardees', v_gardees, 'published_at', now());
  update public.book_drafts d
     set marc_json = jsonb_set(d.marc_json, '{ingest_divergence,publication}', v_res)
   where d.id = p_draft_id;
  return v_res;
end;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_divergences_apres_publication(bigint, bigint) IS
  'H21 lot 5 (07/10/2026) : à la première publication d''un brouillon de reprise prérempli, chaque divergence de la trace encore ouverte, liée, au même N, que la notice publiée dit comme le fichier, passe « appliquee » et sa base avance à N pour ce champ ; une valeur retouchée laisse la divergence ouverte. Interne : publish_book_draft.';

DO $h21l5_droits$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'ingest.fn_h21_empreinte_valeur(jsonb)', 'ingest.fn_h21_valeur_de_base(bigint, text)',
    'ingest.fn_h21_notice_partagee(bigint)', 'ingest.fn_h21_divergence_avancer_base(bigint, boolean)',
    'ingest.fn_h21_constater_divergences(bigint, bigint[])', 'ingest.fn_h21_garde_divergence(bigint, boolean)',
    'ingest.fn_h21_divergences_apres_publication(bigint, bigint)'] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
  END LOOP;
  FOREACH f IN ARRAY ARRAY[
    'public.fn_divergences_a_traiter(uuid, integer, integer)', 'public.fn_notice_divergences(bigint)',
    'public.fn_divergences_ecarter(bigint[])', 'public.fn_divergences_appliquer(bigint, bigint[])'] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', f);
  END LOOP;
END
$h21l5_droits$;


-- ─────────────────────────────────────────────────────────────────────
-- 8. Le constat dans le recalcul et dans le geste du lot 4
-- ─────────────────────────────────────────────────────────────────────
DO $h21l5_recomparer$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l5_def('public.fn_import_recomparer(bigint, bigint[])'::regprocedure);
  v_def := pg_temp.h21l5_remplacer('fn_import_recomparer (déclarations)', v_def,
$a$  v_n integer;
BEGIN$a$,
$b$  v_n integer;
  v_div jsonb;   -- H21 lot 5
BEGIN$b$);
  v_def := pg_temp.h21l5_remplacer('fn_import_recomparer (constat)', v_def,
$a$  v_n := ingest.fn_h21_stocker_comparaisons(p_run_id, p_row_ids);$a$,
$b$  v_n := ingest.fn_h21_stocker_comparaisons(p_run_id, p_row_ids);
  -- H21 lot 5 (07/10/2026, IMP-26 b, IMP-32) : une notice PARTAGÉE n'est jamais
  -- réécrite par un réimport — ses champs divergents sont signalés aux
  -- détentrices (ingest.book_import_divergences) ; aucune écriture au catalogue.
  v_div := ingest.fn_h21_constater_divergences(p_run_id, p_row_ids);$b$);
  v_def := pg_temp.h21l5_remplacer('fn_import_recomparer (rendu)', v_def,
$a$    'compared_rows', v_n,$a$,
$b$    'compared_rows', v_n,
    'divergences', v_div,   -- H21 lot 5$b$);
  EXECUTE v_def;
END
$h21l5_recomparer$;

DO $h21l5_preparer$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l5_def('public.fn_import_preparer_mises_a_jour(bigint, bigint[])'::regprocedure);
  v_def := pg_temp.h21l5_remplacer('fn_import_preparer_mises_a_jour (constat)', v_def,
$a$  PERFORM ingest.fn_h21_stocker_comparaisons(p_run_id, v_ids);$a$,
$b$  PERFORM ingest.fn_h21_stocker_comparaisons(p_run_id, v_ids);
  -- H21 lot 5 (07/10/2026) : une notice partagée est ignorée ici (« partagee »)
  -- et SIGNALÉE aux détentrices (ingest.book_import_divergences).
  PERFORM ingest.fn_h21_constater_divergences(p_run_id, v_ids);$b$);
  EXECUTE v_def;
END
$h21l5_preparer$;


-- ─────────────────────────────────────────────────────────────────────
-- 9. La trace d'une reprise préremplie ne s'écrit pas par l'API
-- ─────────────────────────────────────────────────────────────────────
DO $h21l5_trace$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l5_def('public.tg_book_drafts_trace_import_figee()'::regprocedure);
  v_def := pg_temp.h21l5_remplacer('tg_book_drafts_trace_import_figee', v_def,
$a$  IF coalesce(OLD.marc_json, '{}'::jsonb) ? 'ingest' THEN$a$,
$b$  -- H21 lot 5 (07/10/2026) : la trace d'une reprise préremplie depuis des
  -- divergences (marc_json.ingest_divergence : notice, bibliothèque, empreinte,
  -- champs appliqués) ne se pose, ne se réécrit ni ne s'efface par l'API, et
  -- la notice visée d'un tel brouillon non plus — la garde de publication lit
  -- l'une et l'autre.
  IF coalesce(OLD.marc_json, '{}'::jsonb) ? 'ingest_divergence' OR coalesce(NEW.marc_json, '{}'::jsonb) ? 'ingest_divergence' THEN
    IF (NEW.marc_json -> 'ingest_divergence') IS DISTINCT FROM (OLD.marc_json -> 'ingest_divergence') THEN
      NEW.marc_json := (coalesce(NEW.marc_json, '{}'::jsonb) - 'ingest_divergence')
                       || CASE WHEN coalesce(OLD.marc_json, '{}'::jsonb) ? 'ingest_divergence'
                               THEN jsonb_build_object('ingest_divergence', OLD.marc_json -> 'ingest_divergence')
                               ELSE '{}'::jsonb END;
    END IF;
    IF coalesce(OLD.marc_json, '{}'::jsonb) ? 'ingest_divergence'
       AND NEW.published_book_id IS DISTINCT FROM OLD.published_book_id THEN
      NEW.published_book_id := OLD.published_book_id;
    END IF;
  END IF;
  IF coalesce(OLD.marc_json, '{}'::jsonb) ? 'ingest' THEN$b$);
  EXECUTE v_def;
END
$h21l5_trace$;


-- ─────────────────────────────────────────────────────────────────────
-- 9 bis. B2 (a) : une trace d'import ne se pose pas par l'API à l'INSERT
-- ─────────────────────────────────────────────────────────────────────
-- Le déclencheur de trace figée est BEFORE UPDATE : à l'INSERT, l'API pouvait
-- poser marc_json.ingest_divergence (lot 5) ou marc_json.ingest_update (lot 4)
-- sur un brouillon visant la notice d'autrui. Refus, sous les seuls rôles de
-- l'API (authenticated, anon) : une fonction SECURITY DEFINER (copie de la
-- notice, rejeu du journal) insère sous son propriétaire et passe.
CREATE OR REPLACE FUNCTION public.tg_book_drafts_trace_import_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF current_user IN ('authenticated', 'anon')
     AND (coalesce(NEW.marc_json, '{}'::jsonb) ? 'ingest_divergence'
          OR coalesce(NEW.marc_json, '{}'::jsonb) ? 'ingest_update') THEN
    RAISE EXCEPTION 'Rastro de importacao reservado.' USING HINT = 'error.import.trace_reserved';
  END IF;
  RETURN NEW;
END
$function$;
REVOKE EXECUTE ON FUNCTION public.tg_book_drafts_trace_import_insert() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tg_book_drafts_trace_import_insert() TO service_role;
COMMENT ON FUNCTION public.tg_book_drafts_trace_import_insert() IS
  'H21 lot 5 (07/10/2026, revue sceptique B2) : refuse à l''API (authenticated, anon) l''insertion d''un brouillon qui porte marc_json.ingest_divergence ou marc_json.ingest_update — traces que seuls les gestes (fonctions DEFINER) posent.';
DROP TRIGGER IF EXISTS book_drafts_trace_import_insert ON public.book_drafts;
CREATE TRIGGER book_drafts_trace_import_insert
  BEFORE INSERT ON public.book_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_book_drafts_trace_import_insert();


-- ─────────────────────────────────────────────────────────────────────
-- 10. publish_book_draft : la garde avant le choix de branche, la trace hors
--     de la notice, l'après-publication
-- ─────────────────────────────────────────────────────────────────────
DO $h21l5_publication$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l5_def('public.publish_book_draft(bigint)'::regprocedure);
  v_def := pg_temp.h21l5_remplacer('publish_book_draft (déclarations)', v_def,
$a$  v_maj_import boolean := false;             -- H21 lot 4 : mise à jour préparée par un réimport$a$,
$b$  v_maj_import boolean := false;             -- H21 lot 4 : mise à jour préparée par un réimport
  v_divergence boolean := false;             -- H21 lot 5 : reprise préremplie depuis des divergences$b$);
  v_def := pg_temp.h21l5_remplacer('publish_book_draft (garde avant la branche)', v_def,
$a$    raise exception 'rascunho_descartado' using hint = 'error.publish.draft_cancelled';
  end if;
$a$,
$b$    raise exception 'rascunho_descartado' using hint = 'error.publish.draft_cancelled';
  end if;

  -- H21 lot 5 (07/10/2026, IMP-32 b) : une reprise préremplie depuis des
  -- divergences (trace marc_json.ingest_divergence, figée pour l'API) est
  -- jugée AVANT le choix de branche — une garde dans une seule branche se
  -- contourne par l'autre (leçon du lot 4) — et avant les portes de révision
  -- (une notice disparue s'y dirait « importée hors lot ») ; à la
  -- republication aussi : notice présente (jamais la branche création),
  -- bibliothèque détentrice, bib_ref ; à la première publication, lien des
  -- divergences et empreinte de la notice (ingest.fn_h21_garde_divergence).
  -- Puis les divergences appliquées (plus bas).
  if coalesce(v_draft.marc_json, '{}'::jsonb) ? 'ingest_divergence' then
    perform ingest.fn_h21_garde_divergence(p_draft_id, v_draft.status = 'published');
    v_divergence := v_draft.status is distinct from 'published';
  end if;
$b$);
  v_def := pg_temp.h21l5_remplacer('publish_book_draft (création, trace)', v_def,
$a$      coalesce(v_draft.marc_json, '{}'::jsonb) - 'ingest_update', 'catalogacao',$a$,
$b$      coalesce(v_draft.marc_json, '{}'::jsonb) - 'ingest_update' - 'ingest_divergence', 'catalogacao',$b$);
  v_def := pg_temp.h21l5_remplacer('publish_book_draft (mise à jour, trace)', v_def,
$a$      marc_json = coalesce(v_draft.marc_json, '{}'::jsonb) - 'ingest_update',$a$,
$b$      -- H21 lot 5 : la trace d'une reprise préremplie reste au brouillon
      marc_json = coalesce(v_draft.marc_json, '{}'::jsonb) - 'ingest_update' - 'ingest_divergence',$b$);
  v_def := pg_temp.h21l5_remplacer('publish_book_draft (après-publication)', v_def,
$a$  if v_maj_import then
    perform ingest.fn_h21_avancer_base_apres_mise_a_jour(p_draft_id, v_book_id);
  end if;$a$,
$b$  if v_maj_import then
    perform ingest.fn_h21_avancer_base_apres_mise_a_jour(p_draft_id, v_book_id);
  end if;
  -- H21 lot 5 : les divergences appliquées (la notice publiée dit le fichier)
  -- passent « appliquee », leur base avance à N pour ces champs.
  if v_divergence then
    perform ingest.fn_h21_divergences_apres_publication(p_draft_id, v_book_id);
  end if;$b$);
  EXECUTE v_def;
END
$h21l5_publication$;


-- ─────────────────────────────────────────────────────────────────────
-- 11. Une reprise préremplie ne s'absorbe pas dans une notice
-- ─────────────────────────────────────────────────────────────────────
DO $h21l5_absorption$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l5_def('api.merge_draft_into_book(bigint, bigint, jsonb)'::regprocedure);
  v_def := pg_temp.h21l5_remplacer('api.merge_draft_into_book (reprise préremplie)', v_def,
$a$      USING HINT = 'error.import.update_draft_not_mergeable';
  END IF;$a$,
$b$      USING HINT = 'error.import.update_draft_not_mergeable';
  END IF;
  -- H21 lot 5 (07/10/2026) : une reprise préremplie depuis des divergences
  -- (trace marc_json.ingest_divergence) ne s'absorbe pas : l'absorption n'a ni
  -- garde de détention ni empreinte. Elle se publie, ou se met à la corbeille.
  IF coalesce(v_draft.marc_json, '{}'::jsonb) ? 'ingest_divergence' THEN
    RAISE EXCEPTION 'Rascunho de divergencia nao se absorve.'
      USING HINT = 'error.divergence.draft_not_mergeable';
  END IF;$b$);
  EXECUTE v_def;
END
$h21l5_absorption$;


-- ─────────────────────────────────────────────────────────────────────
-- 12. Vérification (structurelle : les migrations passent avant le seed)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l5_verif$
DECLARE
  v_e text := '';
  v_def text;
  v_f text;
BEGIN
  -- la publication : garde AVANT le choix de branche et après le refus du lot 4,
  -- valable à la republication ; trace retirée des deux branches ; après-publication
  v_def := pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure);
  IF position('perform ingest.fn_h21_garde_divergence(p_draft_id, v_draft.status = ''published'');' IN v_def) = 0
     OR position('perform ingest.fn_h21_garde_divergence(p_draft_id, ' IN v_def)
        > position('if v_draft.published_book_id is null then' IN v_def)
     OR position('perform ingest.fn_h21_garde_divergence(p_draft_id, ' IN v_def)
        > position('lote_importado_sem_revisao' IN v_def)
     OR position('perform ingest.fn_h21_garde_divergence(p_draft_id, ' IN v_def)
        < position('error.publish.other_library' IN v_def)
     OR position('- ''ingest_update'' - ''ingest_divergence'', ''catalogacao''' IN v_def) = 0
     OR position('marc_json = coalesce(v_draft.marc_json, ''{}''::jsonb) - ''ingest_update'' - ''ingest_divergence'',' IN v_def) = 0
     OR position('perform ingest.fn_h21_divergences_apres_publication(p_draft_id, v_book_id);' IN v_def)
        < position('update public.book_drafts' IN v_def) THEN
    v_e := v_e || ' publication';
  END IF;
  IF position('error.divergence.draft_not_mergeable' IN pg_get_functiondef('api.merge_draft_into_book(bigint, bigint, jsonb)'::regprocedure)) = 0
     OR position('error.divergence.draft_not_mergeable' IN pg_get_functiondef('api.merge_draft_into_book(bigint, bigint, jsonb)'::regprocedure))
        > position('UPDATE public.books' IN pg_get_functiondef('api.merge_draft_into_book(bigint, bigint, jsonb)'::regprocedure)) THEN
    v_e := v_e || ' absorption';
  END IF;
  v_def := pg_get_functiondef('ingest.fn_h21_garde_divergence(bigint, boolean)'::regprocedure);
  FOREACH v_f IN ARRAY ARRAY['error.divergence.record_gone', 'error.divergence.not_holder', 'error.divergence.bib_ref_changed',
                             'error.divergence.draft_unlinked', 'error.divergence.record_changed'] LOOP
    IF position(v_f IN v_def) = 0 THEN v_e := v_e || ' garde(' || v_f || ')'; END IF;
  END LOOP;
  IF position('if p_republication then' IN v_def) > position('error.divergence.draft_unlinked' IN v_def)
     OR position('if p_republication then' IN v_def) < position('error.divergence.bib_ref_changed' IN v_def) THEN
    v_e := v_e || ' republication';
  END IF;
  IF position('ingest_divergence' IN pg_get_functiondef('public.tg_book_drafts_trace_import_figee()'::regprocedure)) = 0 THEN
    v_e := v_e || ' trace';
  END IF;
  IF position('ingest.fn_h21_constater_divergences(p_run_id, p_row_ids)' IN pg_get_functiondef('public.fn_import_recomparer(bigint, bigint[])'::regprocedure)) = 0
     OR position('ingest.fn_h21_constater_divergences(p_run_id, v_ids)' IN pg_get_functiondef('public.fn_import_preparer_mises_a_jour(bigint, bigint[])'::regprocedure)) = 0 THEN
    v_e := v_e || ' constat';
  END IF;
  -- le geste « Appliquer » n'emprunte pas create_book_draft_from_book (qui ne
  -- vérifie pas la détention — piège 17) et ne lie aucune ligne d'import
  v_def := pg_get_functiondef('public.fn_divergences_appliquer(bigint, bigint[])'::regprocedure);
  IF position('create_book_draft_from_book' IN v_def) > 0 OR position('partner_catalog_row_to_draft' IN v_def) > 0
     OR position('error.divergence.not_holder' IN v_def) = 0 OR position('error.divergence.draft_exists' IN v_def) = 0 THEN
    v_e := v_e || ' appliquer';
  END IF;
  -- B1 : la copie écrit toutes les colonnes de books que porte le brouillon et
  -- qu'écrit la publication (branche update, déclencheur de circulation), hors
  -- work_id (coalesce), publisher_id (déduit), owner_library_id, horodatages
  v_def := pg_get_functiondef('ingest.fn_h21_copie_de_la_notice(bigint, bigint, uuid, uuid)'::regprocedure);
  SELECT string_agg(c.column_name, ',' ORDER BY c.column_name) INTO v_f
    FROM information_schema.columns c
   WHERE c.table_schema = 'public' AND c.table_name = 'books'
     AND EXISTS (SELECT 1 FROM information_schema.columns d
                  WHERE d.table_schema = 'public' AND d.table_name = 'book_drafts' AND d.column_name = c.column_name)
     AND c.column_name NOT IN ('id', 'work_id', 'publisher_id', 'owner_library_id', 'created_at', 'created_by',
                               'updated_at', 'updated_by')
     AND v_def !~ ('\mb\.' || c.column_name || '\M');
  IF v_f IS NOT NULL THEN
    v_e := v_e || ' copie(' || v_f || ')';
  END IF;
  -- B2 (a) : la garde à l'INSERT ; (b) les brouillons liés
  IF NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.book_drafts'::regclass
                  AND t.tgname = 'book_drafts_trace_import_insert' AND NOT t.tgisinternal
                  AND t.tgfoid = 'public.tg_book_drafts_trace_import_insert()'::regprocedure
                  AND (t.tgtype & 2) = 2 AND (t.tgtype & 4) = 4)
     OR position('x.draft_id = d.id' IN pg_get_functiondef('public.fn_divergences_appliquer(bigint, bigint[])'::regprocedure)) = 0
     OR position('x.draft_id = dr.id' IN pg_get_functiondef('public.fn_notice_divergences(bigint)'::regprocedure)) = 0
     OR position('x.draft_id = dr.id' IN pg_get_functiondef('public.fn_divergences_a_traiter(uuid, integer, integer)'::regprocedure)) = 0
     OR has_function_privilege('authenticated', 'public.tg_book_drafts_trace_import_insert()', 'EXECUTE')
     OR has_function_privilege('anon', 'public.tg_book_drafts_trace_import_insert()', 'EXECUTE') THEN
    v_e := v_e || ' insertion';
  END IF;
  -- la table : RLS sans politique, aucun droit API, index unique des ouvertes
  IF NOT (SELECT c.relrowsecurity FROM pg_class c WHERE c.oid = 'ingest.book_import_divergences'::regclass)
     OR EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = 'ingest.book_import_divergences'::regclass)
     OR has_table_privilege('authenticated', 'ingest.book_import_divergences', 'SELECT')
     OR has_table_privilege('anon', 'ingest.book_import_divergences', 'SELECT')
     OR NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indexrelid = 'ingest.book_import_divergences_ouverte_unique'::regclass
                     AND i.indisunique AND i.indpred IS NOT NULL) THEN
    v_e := v_e || ' table';
  END IF;
  -- droits : quatre portes authenticated, fermées à anon ; aides internes fermées
  FOREACH v_f IN ARRAY ARRAY[
    'public.fn_divergences_a_traiter(uuid, integer, integer)', 'public.fn_notice_divergences(bigint)',
    'public.fn_divergences_ecarter(bigint[])', 'public.fn_divergences_appliquer(bigint, bigint[])',
    'public.fn_import_recomparer(bigint, bigint[])', 'public.fn_import_preparer_mises_a_jour(bigint, bigint[])',
    'public.publish_book_draft(bigint)'] LOOP
    IF NOT has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0) THEN
      v_e := v_e || ' droits-portes(' || v_f || ')';
    END IF;
  END LOOP;
  FOREACH v_f IN ARRAY ARRAY[
    'ingest.fn_h21_empreinte_valeur(jsonb)', 'ingest.fn_h21_valeur_de_base(bigint, text)',
    'ingest.fn_h21_notice_partagee(bigint)', 'ingest.fn_h21_divergence_avancer_base(bigint, boolean)',
    'ingest.fn_h21_constater_divergences(bigint, bigint[])', 'ingest.fn_h21_garde_divergence(bigint, boolean)',
    'ingest.fn_h21_divergences_apres_publication(bigint, bigint)'] LOOP
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0) THEN
      v_e := v_e || ' droits-internes(' || v_f || ')';
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_proc p
              WHERE p.oid IN ('public.fn_divergences_a_traiter(uuid, integer, integer)'::regprocedure,
                              'public.fn_notice_divergences(bigint)'::regprocedure,
                              'public.fn_divergences_ecarter(bigint[])'::regprocedure,
                              'public.fn_divergences_appliquer(bigint, bigint[])'::regprocedure,
                              'ingest.fn_h21_valeur_de_base(bigint, text)'::regprocedure,
                              'ingest.fn_h21_notice_partagee(bigint)'::regprocedure,
                              'ingest.fn_h21_divergence_avancer_base(bigint, boolean)'::regprocedure,
                              'ingest.fn_h21_constater_divergences(bigint, bigint[])'::regprocedure,
                              'ingest.fn_h21_garde_divergence(bigint, boolean)'::regprocedure,
                              'ingest.fn_h21_divergences_apres_publication(bigint, bigint)'::regprocedure,
                              'public.fn_import_recomparer(bigint, bigint[])'::regprocedure,
                              'public.fn_import_preparer_mises_a_jour(bigint, bigint[])'::regprocedure,
                              'public.publish_book_draft(bigint)'::regprocedure)
                AND (NOT p.prosecdef OR coalesce(p.proconfig::text, '') NOT LIKE '%search_path%')) THEN
    v_e := v_e || ' definer';
  END IF;

  IF v_e <> '' THEN
    RAISE EXCEPTION 'H21 lot 5 : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'H21 lot 5 : vérifications OK';
END
$h21l5_verif$;

NOTIFY pgrst, 'reload schema';
