-- =====================================================================
-- H21 lot 7 — les exemplaires retirés
-- (REGISTRE IMP-26 d, e, f ; IMP-27 ; IMP-28 a ; IMP-33 ; IMP-34, décisions
-- de Xavier du 09/10/2026 ; fiche H21)
--
-- « Retiré » est un constat réversible, pas un désherbage (IMP-26 d) :
-- proposé en révision du lot, posé seulement après verdict ; statut « sorti du
-- catalogue d'origine » — non prêtable, masqué à l'OPAC, exclu de l'export ;
-- jamais supprimé ; levé si l'exemplaire réapparaît dans un réimport.
--
-- Décisions de Xavier du 09/10/2026 (IMP-34) :
--  (a) SEUIL : si les disparus dépassent 10 % des exemplaires de la source
--      dans la bibliothèque ET sont au moins 20, aucun retrait n'est proposé
--      tant que la coordination n'a pas confirmé « c'est bien un export
--      complet » pour ce run (geste tracé : qui, quand) ; sous le seuil,
--      proposés directement.
--  (b) ENGAGÉ : un disparu en prêt ouvert, réservé, en PEB ou en consultation
--      au constat est signalé « disparu mais engagé », pas proposé (il le sera
--      au réimport suivant) ; la pose est REFUSÉE s'il s'est engagé entre la
--      proposition et la publication. Aucune réservation n'est annulée.
--  (c) LEVÉE : un retiré qui réapparaît (verdict « déjà là » du lot 6a, ou
--      réétiqueté dans la même source) reçoit une levée proposée dans le lot du
--      run, révisée, publiée — symétrique de la pose.
--  (d) OPAC : une notice dont tous les exemplaires sont retirés disparaît de
--      l'OPAC comme une notice sans exemplaire public ; elle reste au catalogue
--      pour le staff.
-- Tranchés par la spécification (prudents, annoncés à Xavier) : « même
-- source » = strictement la source du run (IMP-26 e à la lettre) ; une notice
-- absente du fichier ne propose rien (compte informatif « hors_fichier ») ; un
-- fichier qui ne décrit AUCUN exemplaire ne propose aucun retrait, même
-- « export complet » coché ; un retiré reste visible pour le staff de sa
-- bibliothèque (badge « sorti du catalogue d'origine ») ; au récolement il est
-- « retiré », pas « manquant » ; aucune autre détentrice n'est avertie.
--
-- Choix faits ici (les plus prudents ; signalés au rapport) :
--  (1) Le drapeau « export complet » est une colonne du run
--      (partner_catalog_import_runs.export_complet, avec qui et quand), posé
--      par une RPC séparée, public.fn_import_set_export_complet, AVANT le
--      dispatch seulement (run « uploaded », jamais démarré, aucun envoi au
--      journal de dispatch) — ni coché ni décoché ensuite, dans les deux sens.
--      Accès : la coordination de la bibliothèque du run (bibliothèque active),
--      l'administration ; dépôt compagnon et entrepôt OAI : l'administration
--      seule (comme les autres gestes du run). Un paquet de fonds
--      (receive-fonds-bundle) et un dépôt direct naissent en traitement : ils
--      ne portent jamais le drapeau (pas de manifeste — une donnée venue de
--      l'extérieur ne déclare pas un export complet à la place de qui dépose).
--  (2) La confirmation du seuil est une RPC dédiée,
--      public.fn_import_confirmer_export_complet (qui, quand, sur le run ;
--      exige le drapeau ; la première confirmation reste).
--  (3) Le seuil compte TOUS les disparus (proposables, engagés, en brouillon)
--      sur les exemplaires NON retirés de la source dans la bibliothèque :
--      le plus prudent (le seuil est atteint plus tôt).
--  (4) Une ligne rejetée par choix ne compte pas comme « notice présente dans
--      le fichier » : ses exemplaires ne sont jamais proposés au retrait, ni
--      à la levée.
--  (5) Réservation au niveau du fonds (ligne active sans exemplaire désigné,
--      sur le fonds de l'exemplaire, ou sur sa notice dans sa bibliothèque) :
--      elle engage TOUS les exemplaires de ce fonds (règle du plus prudent :
--      aucun ne lui est retiré). Une ligne de PEB ou de consultation désigne
--      toujours son exemplaire (item_id NOT NULL).
--  (6) La levée n'exige pas « export complet » (un exemplaire présent dans le
--      fichier est un signal positif) mais exige un run stable, sans ligne en
--      échec, et la même source.
--  (7) Le brouillon de retrait ou de levée porte sa trace dans une colonne à
--      part, exemplar_drafts.import_retrait (nature retrait|levee, run, source,
--      bibliothèque, exemplaire, notice, fonds…), posée par le geste seul
--      (l'API ne la pose ni ne la change, à l'INSERT comme à l'UPDATE) ; il
--      n'est lié à AUCUNE ligne (import_staging_row_id NULL : un disparu n'a
--      pas de ligne) ; le lot qui le contient est « né d'un import »
--      (fn_batch_is_imported) et le lot ouvert du run le retrouve
--      (fn_h21_lot_ouvert_du_run). Sa publication ne passe par AUCUNE des deux
--      branches de publish_exemplar_draft : elle est jugée et faite à part
--      (ingest.fn_h21_publier_retrait), AVANT les portes et le choix de
--      branche ; sa republication est refusée (déjà publié).
--  (8) Le marqueur (exemplares.retire_at, retire_run_id, retire_trace) ne
--      change que par ce geste : un déclencheur le refuse à toute autre voie,
--      fonction DEFINER comprise (copie, reprise, « Éditer », réattribution,
--      fusion), sauf la remise à NULL de retire_run_id par la clé étrangère
--      quand le run est supprimé (le marqueur, lui, reste : retire_at — jamais
--      de renaissance par ON DELETE SET NULL). Un retiré supprimé à la main
--      (discard_exemplar, désherbage du staff) n'est pas empêché.
--  (9) Un seul brouillon vivant par exemplaire : le déclencheur d'exclusivité
--      du lot 6b tient aussi les brouillons de retrait et de levée (« Éditer »
--      attend, une mise à jour d'import attend, et un retrait ne naît pas à
--      côté d'un autre brouillon vivant).
--  (10) Le constat est une étape DÉDIÉE, sur le fichier entier, en une passe
--      SQL (ingest.fn_h21_retraits_constat), lue par l'écran
--      (public.fn_import_retraits, pages de 200) et rejouée par le geste
--      « Proposer les retraits » (public.fn_import_proposer_retraits, 1 000
--      brouillons au plus par appel, mesuré : 5 000 brouillons coûtaient 5 à 14 s —
--      l'écran rappelle tant qu'il en reste, « déjà en brouillon » ensuite) ;
--      jamais pendant le recalcul par pages.
--  (11) La garde « revenu dans le fichier » cherche le code (bibliothèque) ou
--      l'expl_id (même source) dans les exemplaires du run par un index GIN
--      (jsonb_path_ops) : égalité exacte sur la valeur normalisée par
--      l'analyse (clean(), espaces retirés).
--  Revue sceptique du 10/10 (corrigés ici) :
--  (12) LE FICHIER ACTUEL DE LA SOURCE (IMP-26, décision de la coordination du
--      10/10) : seul le run le plus récent NON ARCHIVÉ de la source propose
--      des retraits ou des levées, et il doit être stable — un run plus ancien
--      est bloqué (« run_perime » : un fichier plus récent de cette source
--      existe), un run archivé aussi (« run_archive »). Plus prudent que « le
--      dernier run stable » : un run plus récent encore en cours, ou en
--      échec, bloque aussi l'ancien (le fichier actuel n'est pas lu) ; archiver
--      le run en échec débloque. Un exemplaire né d'un run postérieur
--      (import_run_id plus grand) ou créé après le run n'est jamais
--      « disparu ». À la pose et à la levée : refus si le run du brouillon n'est
--      plus le plus récent non archivé de la source
--      (error.publish.item_retrait_run_superseded), et, pour un retrait, si un
--      run plus récent de la source, archivé compris, décrit l'exemplaire (code
--      ou expl_id ; error.publish.item_retrait_in_newer_file).
--  (13) « Jamais supprimé » (IMP-26 d) : un exemplaire retiré ne se supprime
--      par aucune voie (déclencheur BEFORE DELETE). discard_exemplar et
--      discard_book_cascade sont les deux seules voies qui suppriment un
--      exemplaire ; la suppression d'une notice ne supprime pas ses
--      exemplaires (exemplares.holding_id est ON DELETE SET NULL) : il n'y a
--      donc pas de cascade à excepter (error.catalog.discard.retired).
--  (14) Un retiré ne change pas de bibliothèque (déclencheur BEFORE UPDATE OF
--      library_id : réattributions network_admin_reassign_book_to_library et
--      _from_to_library, republication d'un « Éditer » reciblé — toutes les
--      voies qui écrivent exemplares.library_id) : le marqueur n'a de sens que
--      dans sa bibliothèque, une levée deviendrait impossible
--      (error.catalog.item_retired_no_reassign).
--  (15) Verrou à la pose : le fonds de l'exemplaire est pris FOR UPDATE avant
--      le contrôle « engagé » (l'exemplaire l'est déjà). Une ligne de
--      réservation (au niveau du fonds comme de l'exemplaire), de prêt, de PEB
--      ou de consultation prend, par sa clé étrangère, un verrou KEY SHARE sur
--      le fonds ou sur l'exemplaire : une création en cours est attendue, puis
--      vue par le contrôle, qui lit un nouvel instantané. Reste ouvert
--      (consigné, non corrigé : il faudrait toucher les fonctions de
--      circulation) : une création qui a jugé la disponibilité AVANT la pose et
--      insère APRÈS (elle attend le verrou, puis passe).
--
-- Le trou « visibility » (consigné pour un item à part, NON corrigé ici) :
-- fn_v2_create_reserva_by_holdings, fn_v2_convert_reserva_linhas_to_emprestimo,
-- fn_v2_add_emprestimo_interbibliotecas_itens, fn_peb_create_loan_with_items ne
-- filtrent pas visibility = 'public' (un exemplaire réservé au staff y est
-- compté, choisi ou prêté) ; ce lot y ajoute le filtre du RETRAIT seulement.
--
-- Méthode : chaque fonction existante est modifiée SUR SA DÉFINITION VIVANTE
-- (pg_get_functiondef, retours chariot retirés) par ancres comptées ; aucune
-- signature ne change ; les politiques de lecture de exemplares par ALTER
-- POLICY sur leur expression vivante ; aucune vue touchée (l'OPAC lit les
-- comptes du fonds, recalculés). md5 de prosrc lus le 09/10/2026, relus le 10/10/2026 (inchangés), en production
-- (MCP, lecture seule) et sur le banc privé reconstruit depuis le dépôt
-- (identiques) :
--   public.publish_exemplar_draft                       d9d3489439637881601318c33ce72640
--   public.fn_v2_recompute_holdings_availability        e2702e06ff777704f52043f0039e705e
--   public.fn_v2_create_emprestimo_by_holdings          7e80a0ca0b64e18e30865b0e3cc33398
--   public.fn_v2_create_consulta_local_by_holdings      02bd8decd3c3ed40996193e975a81c9d
--   public.fn_v2_resolve_consulta_exemplar              b6766e615ab3da910846319db94d3c50
--   public.fn_peb_search_exemplares                     040bb8c9cdaa4a2a2c7f0c603429e152
--   public.fn_v2_create_reserva_by_holdings             58b2a3146264829c11ea9af573523066
--   public.fn_v2_convert_reserva_linhas_to_emprestimo   519680fdeaa67610a48b9cdd5859330e
--   public.fn_v2_add_emprestimo_interbibliotecas_itens  a8dd523e6d75bdf8ff214959a53b2221
--   public.fn_peb_create_loan_with_items                d0f20b482437268d141a45a6717978b2
--   public.fn_export_catalog_lote                       73b56917e6026529353422f2873a591c
--   api.recolement_start                                00b976d85ac33df8d15ef5d31fe1fc7d
--   api.recolement_scan                                 75ff7849f718ccd93f2a2bf06105b7d4
--   api.recolement_finish                               93ceac496625aaac2f38053759cd7da0
--   public.tg_exemplar_drafts_import_links_locked       66b5d4b193d85c4b2ff0f5a78b40d54e
--   public.tg_exemplar_drafts_maj_import_exclusive      ae67dd6dbb9bff871fbfc8f4a0beda4f
--   api.merge_book_drafts                               60863061d45c4afd12410f6540de033a
--   public.fn_batch_is_imported                         c9a77cc89fcb5ee11a57424730d1a243
--   ingest.fn_h21_lot_ouvert_du_run                     f95cd949c0122320390cd46c00fa05f9
--   public.fn_batch_review_report                       b0b26d964c368fe29e7bd6f8b9742eab
--   politiques exemplares_public_read                   237343035ffdc03cbf511de8aafea654 (md5 de l'expression)
--               exemplares_select_authenticated         dd32b39fd18925789d944f0a87d592d2
-- Suite : tests/sql/h21_lot7_retires_tests.sql.
-- =====================================================================

-- Outils de la migration, éphémères (pg_temp).
CREATE OR REPLACE FUNCTION pg_temp.h21l7_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'H21 lot 7 — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN
    RAISE EXCEPTION 'H21 lot 7 — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

CREATE OR REPLACE FUNCTION pg_temp.h21l7_def(p_fn regprocedure)
RETURNS text LANGUAGE sql AS $f$
  SELECT replace(pg_get_functiondef(p_fn), E'\r', '');
$f$;


-- ─────────────────────────────────────────────────────────────────────
-- 1. Colonnes, contraintes, index
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE ingest.partner_catalog_import_runs
  ADD COLUMN IF NOT EXISTS export_complet boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS export_complet_par uuid,
  ADD COLUMN IF NOT EXISTS export_complet_le timestamptz,
  ADD COLUMN IF NOT EXISTS retraits_confirmes_par uuid,
  ADD COLUMN IF NOT EXISTS retraits_confirmes_le timestamptz;
ALTER TABLE ingest.partner_catalog_import_runs DROP CONSTRAINT IF EXISTS partner_catalog_import_runs_confirmation_exige_export_complet;
ALTER TABLE ingest.partner_catalog_import_runs ADD CONSTRAINT partner_catalog_import_runs_confirmation_exige_export_complet
  CHECK (retraits_confirmes_le IS NULL OR export_complet);
COMMENT ON COLUMN ingest.partner_catalog_import_runs.export_complet IS
  'H21 lot 7 (IMP-26 f) : la coordination déclare au dépôt que ce fichier est un export COMPLET de son catalogue — sans quoi aucune disparition n''est proposée au retrait. Posé par public.fn_import_set_export_complet avant le dispatch seulement (export_complet_par, export_complet_le).';
COMMENT ON COLUMN ingest.partner_catalog_import_runs.retraits_confirmes_le IS
  'H21 lot 7 (IMP-34 a) : au-delà du seuil (10 % des exemplaires de la source dans la bibliothèque ET au moins 20 disparus), la confirmation explicite « c''est bien un export complet » (public.fn_import_confirmer_export_complet) : qui (retraits_confirmes_par), quand.';

ALTER TABLE public.exemplares
  ADD COLUMN IF NOT EXISTS retire_at timestamptz,
  ADD COLUMN IF NOT EXISTS retire_run_id bigint,
  ADD COLUMN IF NOT EXISTS retire_trace jsonb;
ALTER TABLE public.exemplares DROP CONSTRAINT IF EXISTS exemplares_retire_run_id_fkey;
ALTER TABLE public.exemplares ADD CONSTRAINT exemplares_retire_run_id_fkey
  FOREIGN KEY (retire_run_id) REFERENCES ingest.partner_catalog_import_runs(id) ON DELETE SET NULL;
ALTER TABLE public.exemplares DROP CONSTRAINT IF EXISTS exemplares_retire_coherent;
ALTER TABLE public.exemplares ADD CONSTRAINT exemplares_retire_coherent
  CHECK ((retire_run_id IS NULL OR retire_at IS NOT NULL)
         AND (retire_trace IS NULL OR jsonb_typeof(retire_trace) = 'object'));
CREATE INDEX IF NOT EXISTS exemplares_retire_run_id_idx ON public.exemplares (retire_run_id);
CREATE INDEX IF NOT EXISTS exemplares_retires_idx ON public.exemplares (library_id) WHERE retire_at IS NOT NULL;
COMMENT ON COLUMN public.exemplares.retire_at IS
  'H21 lot 7 (IMP-26 d) : « sorti du catalogue d''origine » — l''exemplaire a disparu d''un export complet de sa source ; posé après révision (ingest.fn_h21_publier_retrait), levé s''il réapparaît. Retiré : non prêtable, non réservable, non consultable, hors PEB, hors disponibilité et OPAC, hors export ; visible au staff de sa bibliothèque ; jamais supprimé par le retrait. Marqueur réservé au geste (tg_exemplares_marqueur_retrait).';
COMMENT ON COLUMN public.exemplares.retire_run_id IS
  'H21 lot 7 : le run dont le constat a fait poser le retrait (remis à NULL si le run est supprimé ; le retrait, retire_at, reste).';
COMMENT ON COLUMN public.exemplares.retire_trace IS
  'H21 lot 7 : la trace du dernier retrait et de sa levée (run, source, brouillon, lot, qui, quand).';

ALTER TABLE public.exemplar_drafts ADD COLUMN IF NOT EXISTS import_retrait jsonb;
ALTER TABLE public.exemplar_drafts DROP CONSTRAINT IF EXISTS exemplar_drafts_import_retrait_objet;
ALTER TABLE public.exemplar_drafts ADD CONSTRAINT exemplar_drafts_import_retrait_objet
  CHECK (import_retrait IS NULL
         OR (jsonb_typeof(import_retrait) = 'object' AND import_retrait->>'nature' IN ('retrait', 'levee')
             AND import_update IS NULL));
CREATE INDEX IF NOT EXISTS exemplar_drafts_import_retrait_run_idx ON public.exemplar_drafts ((import_retrait->>'run_id'))
  WHERE import_retrait IS NOT NULL;
COMMENT ON COLUMN public.exemplar_drafts.import_retrait IS
  'H21 lot 7 (IMP-26 d, IMP-34) : trace d''un brouillon de RETRAIT ou de LEVÉE d''exemplaire proposé par un réimport (« Proposer les retraits ») — nature, run, source, bibliothèque, exemplaire, notice, fonds. Posée par le geste seul ; ni posée ni changée par l''API (tg_exemplar_drafts_import_links_locked) ; sa publication ne change que le marqueur (ingest.fn_h21_publier_retrait).';

-- La garde « revenu dans le fichier » : un exemplaire du run par son code ou
-- son expl_id, sans parcourir le fichier (voir l'en-tête, (11)).
CREATE INDEX IF NOT EXISTS partner_catalog_staging_rows_items_gin
  ON ingest.partner_catalog_staging_rows USING gin ((normalized_payload->'items') jsonb_path_ops);


-- ─────────────────────────────────────────────────────────────────────
-- 2. Le marqueur : réservé au geste
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tg_exemplares_marqueur_retrait()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF coalesce(current_setting('anarbib.h21_marqueur_retrait', true), '') = 'on' THEN
    RETURN NEW;   -- ingest.fn_h21_publier_retrait, le seul geste qui pose ou lève
  END IF;
  IF TG_OP = 'UPDATE'
     AND NEW.retire_at IS NOT DISTINCT FROM OLD.retire_at
     AND NEW.retire_trace IS NOT DISTINCT FROM OLD.retire_trace
     AND NEW.retire_run_id IS NULL AND OLD.retire_run_id IS NOT NULL THEN
    RETURN NEW;   -- la clé étrangère : le run supprimé ; le retrait reste
  END IF;
  IF (TG_OP = 'INSERT' AND (NEW.retire_at IS NOT NULL OR NEW.retire_run_id IS NOT NULL OR NEW.retire_trace IS NOT NULL))
     OR (TG_OP = 'UPDATE' AND (NEW.retire_at IS DISTINCT FROM OLD.retire_at
                               OR NEW.retire_run_id IS DISTINCT FROM OLD.retire_run_id
                               OR NEW.retire_trace IS DISTINCT FROM OLD.retire_trace)) THEN
    RAISE EXCEPTION 'Marcador de retirada reservado ao circuito de importacao.'
      USING ERRCODE = '42501', HINT = 'error.import.item_retrait_reserved';
  END IF;
  RETURN NEW;
END
$function$;
REVOKE ALL ON FUNCTION public.tg_exemplares_marqueur_retrait() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tg_exemplares_marqueur_retrait() TO service_role;
DROP TRIGGER IF EXISTS exemplares_marqueur_retrait ON public.exemplares;
CREATE TRIGGER exemplares_marqueur_retrait
  BEFORE INSERT OR UPDATE OF retire_at, retire_run_id, retire_trace ON public.exemplares
  FOR EACH ROW EXECUTE FUNCTION public.tg_exemplares_marqueur_retrait();


-- Un retiré ne se supprime pas et ne change pas de bibliothèque (voir
-- l'en-tête, (13) et (14)), quelle que soit la voie.
CREATE OR REPLACE FUNCTION public.tg_exemplares_retire_garde()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.retire_at IS NOT NULL THEN
      RAISE EXCEPTION 'Exemplar retirado do catalogo de origem: nunca apagado.'
        USING ERRCODE = 'P0001', HINT = 'error.catalog.discard.retired';
    END IF;
    RETURN OLD;
  END IF;
  IF OLD.retire_at IS NOT NULL AND NEW.library_id IS DISTINCT FROM OLD.library_id THEN
    RAISE EXCEPTION 'Exemplar retirado do catalogo de origem: nao muda de biblioteca.'
      USING ERRCODE = 'P0001', HINT = 'error.catalog.item_retired_no_reassign';
  END IF;
  RETURN NEW;
END
$function$;
REVOKE ALL ON FUNCTION public.tg_exemplares_retire_garde() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tg_exemplares_retire_garde() TO service_role;
DROP TRIGGER IF EXISTS exemplares_retire_jamais_supprime ON public.exemplares;
CREATE TRIGGER exemplares_retire_jamais_supprime
  BEFORE DELETE ON public.exemplares
  FOR EACH ROW EXECUTE FUNCTION public.tg_exemplares_retire_garde();
DROP TRIGGER IF EXISTS exemplares_retire_reste_chez_soi ON public.exemplares;
CREATE TRIGGER exemplares_retire_reste_chez_soi
  BEFORE UPDATE OF library_id ON public.exemplares
  FOR EACH ROW EXECUTE FUNCTION public.tg_exemplares_retire_garde();


-- ─────────────────────────────────────────────────────────────────────
-- 3. Les aides : engagé, empreinte, présence dans le fichier, accès
-- ─────────────────────────────────────────────────────────────────────
-- L'exemplaire est-il engagé (IMP-34 b) ? Le motif, ou NULL. Voir l'en-tête (5).
CREATE OR REPLACE FUNCTION ingest.fn_h21_retrait_engage(p_exemplar_id bigint)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select case
    when exists (select 1 from public.emprestimo_itens_v2 i
                  where i.item_id = e.id and i.item_status = 'aberto') then 'pret'
    when exists (select 1 from public.reserva_linhas_v2 rl
                   join public.reservas_v2 r on r.id = rl.reserva_id
                  where rl.item_status = 'ativa'
                    and (rl.item_id = e.id
                         or (rl.item_id is null
                             and (rl.holding_id = e.holding_id
                                  or (rl.holding_id is null and r.library_id = e.library_id
                                      and rl.book_id = h.book_id))))) then 'reservation'
    -- (une ligne de PEB ou de consultation désigne toujours son exemplaire :
    -- item_id NOT NULL)
    when exists (select 1 from public.interlibrary_loan_items_v2 il
                  where il.item_id = e.id and il.item_status in ('reservado_para_saida', 'emprestado')) then 'peb'
    when exists (select 1 from public.consulta_linhas_v2 c
                  where c.item_id = e.id and c.item_status = 'ativa') then 'consultation'
  end
  from public.exemplares e
  left join public.book_holdings h on h.id = e.holding_id
  where e.id = p_exemplar_id;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_retrait_engage(bigint) IS
  'H21 lot 7 (IMP-34 b) : l''exemplaire est-il engagé — prêt ouvert, réservation active (désignée, ou au niveau de son fonds ou de sa notice dans sa bibliothèque), PEB, consultation ? Le motif (pret, reservation, peb, consultation) ou NULL. Interne.';

-- Ce que la pose ou la levée NE doit PAS changer : l'exemplaire hors le
-- marqueur et updated_at, l'identité de son fonds, sa circulation, son
-- récolement (même règle que l'empreinte « hors patch » du lot 6b).
CREATE OR REPLACE FUNCTION ingest.fn_h21_empreinte_hors_marqueur(p_exemplar_id bigint)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select md5(jsonb_build_array(
    (select to_jsonb(e) - array['updated_at', 'retire_at', 'retire_run_id', 'retire_trace'] from public.exemplares e where e.id = p_exemplar_id),
    (select jsonb_build_array(h.id, h.book_id, h.library_id, h.local_bib_ref, h.loanable, h.notes)
       from public.exemplares e join public.book_holdings h on h.id = e.holding_id where e.id = p_exemplar_id),
    (select coalesce(jsonb_agg(to_jsonb(i) order by i.id), '[]'::jsonb) from public.emprestimo_itens_v2 i where i.item_id = p_exemplar_id),
    (select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb) from public.consulta_linhas_v2 c where c.item_id = p_exemplar_id),
    (select coalesce(jsonb_agg(to_jsonb(l) order by l.id), '[]'::jsonb) from public.interlibrary_loan_items_v2 l where l.item_id = p_exemplar_id),
    (select coalesce(jsonb_agg(to_jsonb(r) order by r.id), '[]'::jsonb) from public.reserva_linhas_v2 r where r.item_id = p_exemplar_id),
    (select coalesce(jsonb_agg(to_jsonb(s) order by s.id), '[]'::jsonb) from public.recolement_scans s where s.exemplar_id = p_exemplar_id))::text);
$function$;

-- Le code (dans la bibliothèque) ou l'expl_id (même source) est-il décrit par
-- un exemplaire du run ? Index GIN (voir l'en-tête, (11)).
CREATE OR REPLACE FUNCTION ingest.fn_h21_retrait_dans_le_fichier(p_run_id bigint, p_code text, p_xid text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select (nullif(btrim(coalesce(p_code, '')), '') is not null
          and exists (select 1 from ingest.partner_catalog_staging_rows sr
                       where sr.run_id = p_run_id
                         and (sr.normalized_payload->'items')
                             @> jsonb_build_array(jsonb_build_object('source_item_code', btrim(p_code)))))
      or (nullif(btrim(coalesce(p_xid, '')), '') is not null
          and exists (select 1 from ingest.partner_catalog_staging_rows sr
                       where sr.run_id = p_run_id
                         and (sr.normalized_payload->'items')
                             @> jsonb_build_array(jsonb_build_object('source_item_id', btrim(p_xid)))));
$function$;

-- L'accès aux gestes du lot (les contrôles de fn_import_preparer_mises_a_jour) :
-- la coordination de la bibliothèque du run, ou l'administration du réseau
-- dont la bibliothèque active est celle du run ; dépôt compagnon et entrepôt
-- OAI : l'administration seule. Rend l'utilisateur.
CREATE OR REPLACE FUNCTION ingest.fn_h21_acces_retraits(p_run_id bigint)
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'ingest', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_actor public.my_access%rowtype;
  v_run_library_id uuid;
  v_source_kind text;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;
  SELECT r.library_id, s.source_kind
    INTO v_run_library_id, v_source_kind
    FROM ingest.partner_catalog_import_runs r
    LEFT JOIN ingest.partner_catalog_sources s ON s.id = r.source_id
   WHERE r.id = p_run_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;
  IF v_run_library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;
  IF v_source_kind IN ('partner_deposit', 'oai_pmh') AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Deposito de catalogo companheiro reservado a administracao da rede.'
      USING HINT = 'error.import.deposit_admin_only';
  END IF;
  RETURN v_actor.user_id;
END
$function$;

-- Le run est-il le fichier ACTUEL de sa source (voir l'en-tête, (12)) ? NULL si
-- oui ; 'run_archive' s'il est archivé ; 'run_perime' si un run plus récent de
-- la source, non archivé, existe.
CREATE OR REPLACE FUNCTION ingest.fn_h21_run_courant(p_run_id bigint)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  select case
    when r.archived_at is not null then 'run_archive'
    when exists (select 1 from ingest.partner_catalog_import_runs r2
                  where r2.source_id = r.source_id and r2.id > r.id and r2.archived_at is null) then 'run_perime'
  end
  from ingest.partner_catalog_import_runs r
  where r.id = p_run_id;
$function$;

-- Le plafond de brouillons de retrait et de levée par appel du geste.
CREATE OR REPLACE FUNCTION ingest.fn_h21_retraits_par_appel()
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
 SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
  select 1000;
$function$;


-- ─────────────────────────────────────────────────────────────────────
-- 4. Le constat des disparus et des réapparus (une passe, fichier entier)
-- ─────────────────────────────────────────────────────────────────────
-- Disparus (p_disparus) : exemplaires de la bibliothèque importatrice, de la
-- SOURCE du run, non retirés, dont la notice ACTUELLE est la notice proposée
-- d'une ligne reconnue (known_record, non rejetée par choix) du run, et dont
-- ni le code (bibliothèque) ni l'expl_id (même source) ne sont décrits par
-- AUCUN exemplaire du run (un déplacé ou un réétiqueté n'est jamais disparu).
-- Verdicts : disparu (proposable), disparu_engage (motif), disparu_brouillon
-- (un brouillon vivant ; draft_nature). Réapparus (p_reapparus) : exemplaires
-- RETIRÉS de la même bibliothèque et de la même source qu'un exemplaire d'une
-- ligne reconnue du run désigne, au verdict « déjà là » ou « réétiqueté » du
-- constat du lot 6a : retire_reapparu (proposable sans brouillon vivant).
CREATE OR REPLACE FUNCTION ingest.fn_h21_retraits_constat(p_run_id bigint, p_disparus boolean DEFAULT true, p_reapparus boolean DEFAULT true)
 RETURNS TABLE(exemplar_id bigint, verdict text, motif text, draft_id bigint, draft_nature text,
               book_id bigint, holding_id bigint, tombo text, code text, expl_id text,
               staging_row_id bigint, constat text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  with run as materialized (
    select r.id, r.source_id, r.created_at, ingest.fn_h21_bibliotheque_importatrice(r.id, NULL, NULL) as lib
      from ingest.partner_catalog_import_runs r
     where r.id = p_run_id
  ), lignes as materialized (
    select sr.id, sr.proposed_book_id,
           (sr.match_status = 'known_record' and sr.proposed_book_id is not null
            and not ingest.fn_h21_rejet_par_choix(sr.editorial_decision, sr.editorial_note, sr.discarded_draft_id)) as reconnue,
           case when jsonb_typeof(sr.normalized_payload->'items') = 'array'
                then sr.normalized_payload->'items' else '[]'::jsonb end as items
      from ingest.partner_catalog_staging_rows sr
     where sr.run_id = p_run_id
  ), items as materialized (
    select l.id as row_id, l.proposed_book_id, l.reconnue, i.o,
           nullif(btrim(i.v->>'source_item_code'), '') as code,
           nullif(btrim(i.v->>'source_item_id'), '') as xid
      from lignes l
      cross join lateral jsonb_array_elements(l.items) with ordinality i(v, o)
  ), notices as materialized (
    select distinct l.proposed_book_id as book_id from lignes l where l.reconnue
  ), disparus as materialized (
    select e.id, e.holding_id, h.book_id, e.tombo, e.source_item_code, e.source_item_id
      from run
      join public.exemplares e on e.library_id = run.lib and e.import_source_id = run.source_id
      join public.book_holdings h on h.id = e.holding_id
     where p_disparus
       and e.retire_at is null
       -- (revue sceptique du 10/10) jamais un exemplaire plus récent que le fichier
       and e.created_at <= run.created_at
       and (e.import_run_id is null or e.import_run_id <= run.id)
       and h.book_id in (select n.book_id from notices n)
       and coalesce(nullif(btrim(e.source_item_code), ''), nullif(btrim(e.source_item_id), '')) is not null
       and not exists (select 1 from items it where it.code = btrim(e.source_item_code))
       and not exists (select 1 from items it where it.xid = btrim(e.source_item_id))
  ), retires as materialized (
    -- les retirés de la bibliothèque et de la source (index partiel)
    select e.* from run
      join public.exemplares e on e.library_id = run.lib and e.retire_at is not null
     where p_reapparus and e.import_source_id = run.source_id
  ), paires as materialized (
    -- un exemplaire du fichier désigne un retiré par son code OU son expl_id
    -- (deux jointures d'égalité : un OU empêcherait la jointure par hachage)
    select it.row_id, it.o, it.proposed_book_id, it.code, it.xid, r.id
      from items it join retires r on btrim(r.source_item_code) = it.code
     where it.reconnue and it.code is not null
    union
    select it.row_id, it.o, it.proposed_book_id, it.code, it.xid, r.id
      from items it join retires r on btrim(r.source_item_id) = it.xid
     where it.reconnue and it.code is not null and it.xid is not null
  ), reapparus as materialized (
    select distinct on (e.id) e.id, e.holding_id, h.book_id, e.tombo, e.source_item_code, e.source_item_id,
           it.row_id, k.c->>'verdict' as constat
      from run
      join paires it on true
      join public.exemplares e on e.id = it.id
      left join public.book_holdings h on h.id = e.holding_id
      cross join lateral (select ingest.fn_h21_constat_exemplaire(run.lib, run.source_id, it.proposed_book_id,
                                                                  it.code, it.xid) as c) k
     where (k.c->>'exemplar_id')::bigint = e.id
       and k.c->>'verdict' in ('deja_la', 'reetiquete')
     order by e.id, it.row_id, it.o
  ), tous as (
    select d.id, 'd'::text as cote, d.holding_id, d.book_id, d.tombo, d.source_item_code, d.source_item_id,
           NULL::bigint as row_id, NULL::text as constat, ingest.fn_h21_retrait_engage(d.id) as engage
      from disparus d
    union all
    select r.id, 'r', r.holding_id, r.book_id, r.tombo, r.source_item_code, r.source_item_id,
           r.row_id, r.constat, NULL
      from reapparus r
  )
  select t.id,
         case when t.cote = 'r' then 'retire_reapparu'
              when t.engage is not null then 'disparu_engage'
              when v.id is not null then 'disparu_brouillon'
              else 'disparu' end,
         t.engage, v.id, v.nature, t.book_id, t.holding_id, t.tombo,
         nullif(btrim(t.source_item_code), ''), nullif(btrim(t.source_item_id), ''),
         t.row_id, t.constat
    from tous t
    left join lateral (select y.id,
                              case when y.import_retrait is not null then y.import_retrait->>'nature'
                                   when y.import_update is not null then 'mise_a_jour'
                                   else 'autre' end as nature
                         from public.exemplar_drafts y
                        where y.published_exemplar_id = t.id and y.status in ('draft', 'ready')
                        order by y.id
                        limit 1) v on true;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_retraits_constat(bigint, boolean, boolean) IS
  'H21 lot 7 (IMP-26 e, IMP-34) : le constat des disparus (disparu, disparu_engage, disparu_brouillon) et des retirés réapparus (retire_reapparu) d''un run, sur le fichier entier, en une passe. Lecture seule. Interne.';

-- Le bilan d'un run : conditions, comptes, seuil, confirmation, blocages ;
-- une page des exemplaires constatés si p_items.
CREATE OR REPLACE FUNCTION ingest.fn_h21_retraits_bilan(p_run_id bigint, p_items boolean DEFAULT false,
                                                        p_limite integer DEFAULT 200, p_decalage integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_r ingest.partner_catalog_import_runs%rowtype;
  v_lib uuid;
  v_n_items bigint := 0;
  v_n_err bigint := 0;
  v_base text;
  v_bloque_r text;
  v_bloque_l text;
  v_counts jsonb;
  v_disp bigint := 0;
  v_prop_r bigint := 0;
  v_prop_l bigint := 0;
  v_items jsonb;
  v_total bigint := 0;
  v_hors bigint := 0;
  v_retires bigint := 0;
  v_seuil boolean := false;
begin
  select * into v_r from ingest.partner_catalog_import_runs where id = p_run_id;
  if not found then
    return null;
  end if;
  v_lib := ingest.fn_h21_bibliotheque_importatrice(p_run_id, NULL, NULL);
  select coalesce(sum(case when jsonb_typeof(sr.normalized_payload->'items') = 'array'
                           then jsonb_array_length(sr.normalized_payload->'items') else 0 end), 0),
         count(*) filter (where sr.parse_status = 'error')
    into v_n_items, v_n_err
    from ingest.partner_catalog_staging_rows sr
   where sr.run_id = p_run_id;

  -- les conditions préalables (IMP-34, spécification du lot)
  v_base := case
    when v_lib is null or v_r.source_id is null then 'sans_bibliotheque'
    -- (revue sceptique du 10/10) le fichier ACTUEL de la source seulement
    when v_r.archived_at is not null then 'run_archive'
    when ingest.fn_h21_run_courant(p_run_id) = 'run_perime' then 'run_perime'
    when v_r.run_status in ('uploaded', 'queued', 'processing', 'parsed', 'matching') then 'run_en_cours'
    when v_r.run_status in ('failed', 'partially_failed') or v_n_err > 0 then 'lignes_en_echec'
    when v_r.run_status not in ('ready_for_review', 'drafts_created') then 'run_en_cours'
  end;
  v_bloque_l := v_base;
  v_bloque_r := coalesce(v_base, case when v_n_items = 0 then 'fichier_sans_exemplaires' end);

  with c as materialized (
    select * from ingest.fn_h21_retraits_constat(p_run_id, v_bloque_r is null, v_base is null)
  )
  select jsonb_build_object(
           'disparu',           count(*) filter (where c.verdict = 'disparu'),
           'disparu_engage',    count(*) filter (where c.verdict = 'disparu_engage'),
           'disparu_brouillon', count(*) filter (where c.verdict = 'disparu_brouillon'),
           'retire_reapparu',   count(*) filter (where c.verdict = 'retire_reapparu')),
         count(*) filter (where c.verdict in ('disparu', 'disparu_engage', 'disparu_brouillon')),
         count(*) filter (where c.verdict = 'disparu'),
         count(*) filter (where c.verdict = 'retire_reapparu' and c.draft_id is null),
         case when p_items then
           (select coalesce(jsonb_agg(to_jsonb(x) - 'k' order by x.k, x.tombo, x.exemplar_id), '[]'::jsonb)
              from (select c2.*, (select b.titulo from public.books b where b.id = c2.book_id) as titulo,
                           case c2.verdict when 'disparu' then 1 when 'disparu_engage' then 2
                                           when 'disparu_brouillon' then 3 else 4 end as k
                      from c c2
                     order by k, c2.tombo, c2.exemplar_id
                     limit greatest(coalesce(p_limite, 200), 0) offset greatest(coalesce(p_decalage, 0), 0)) x)
         end
    into v_counts, v_disp, v_prop_r, v_prop_l, v_items
    from c;

  if v_lib is not null and v_r.source_id is not null then
    select count(*) filter (where e.retire_at is null),
           count(*) filter (where e.retire_at is not null),
           count(*) filter (where e.retire_at is null
                              and not exists (select 1 from ingest.partner_catalog_staging_rows sr
                                               where sr.proposed_book_id = h.book_id and sr.run_id = p_run_id
                                                 and sr.match_status = 'known_record'
                                                 and not ingest.fn_h21_rejet_par_choix(sr.editorial_decision, sr.editorial_note,
                                                                                       sr.discarded_draft_id)))
      into v_total, v_retires, v_hors
      from public.exemplares e
      left join public.book_holdings h on h.id = e.holding_id
     where e.library_id = v_lib and e.import_source_id = v_r.source_id;
  end if;

  -- (a) le seuil : plus de 10 % des exemplaires non retirés de la source dans
  -- la bibliothèque ET au moins 20 disparus (tous verdicts : voir l'en-tête, (3))
  v_seuil := v_disp >= 20 and v_disp * 10 > v_total;
  if v_bloque_r is null then
    v_bloque_r := case when not v_r.export_complet then 'pas_export_complet'
                       when v_seuil and v_r.retraits_confirmes_le is null then 'seuil_non_confirme' end;
  end if;

  return jsonb_build_object(
    'version', 'h21-lot7/2026-10-09',
    'run_id', p_run_id,
    'library_id', v_lib,
    'source_id', v_r.source_id,
    'run_status', v_r.run_status,
    'export_complet', v_r.export_complet,
    'export_complet_par', v_r.export_complet_par,
    'export_complet_le', v_r.export_complet_le,
    'confirme', v_r.retraits_confirmes_le is not null,
    'confirme_par', v_r.retraits_confirmes_par,
    'confirme_le', v_r.retraits_confirmes_le,
    'items_du_fichier', v_n_items,
    'lignes_en_echec', v_n_err,
    'bloque_retraits', v_bloque_r,
    'bloque_levees', v_bloque_l,
    'counts', v_counts || jsonb_build_object('hors_fichier', v_hors, 'retires', v_retires),
    'seuil', jsonb_build_object('disparus', v_disp, 'total', v_total, 'pourcentage', 10, 'minimum', 20,
                                'taux', case when v_total > 0 then round(100.0 * v_disp / v_total, 1) end,
                                'atteint', v_seuil),
    'proposables', jsonb_build_object('retraits', case when v_bloque_r is null then v_prop_r else 0 end,
                                      'levees', case when v_bloque_l is null then v_prop_l else 0 end))
    || case when p_items then jsonb_build_object('items', coalesce(v_items, '[]'::jsonb),
                                                 'limite', p_limite, 'decalage', p_decalage) else '{}'::jsonb end;
end;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_retraits_bilan(bigint, boolean, integer, integer) IS
  'H21 lot 7 (IMP-34) : le bilan des retraits d''un run — conditions (export complet, fichier à exemplaires, aucune ligne en échec, run stable), comptes par verdict, seuil (10 %, 20) et confirmation, blocages, proposables ; une page des exemplaires constatés. Lecture seule. Interne.';


-- ─────────────────────────────────────────────────────────────────────
-- 5. La publication d'un retrait ou d'une levée (la garde et le geste)
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION ingest.fn_h21_publier_retrait(p_draft_id bigint, p_republication boolean DEFAULT false)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
declare
  v_d public.exemplar_drafts%rowtype;
  v_u jsonb;
  v_nature text;
  v_e public.exemplares%rowtype;
  v_lib uuid;
  v_src bigint;
  v_run ingest.partner_catalog_import_runs%rowtype;
  v_book bigint;
  v_avant text;
  v_engage text;
  v_ok boolean;
  v_trace jsonb;
begin
  select * into v_d from public.exemplar_drafts where id = p_draft_id for update;
  v_u := v_d.import_retrait;
  if v_u is null then
    raise exception 'rascunho_sem_retirada' using hint = 'error.publish.item_retrait_gone';
  end if;
  v_nature := v_u->>'nature';
  v_lib := nullif(v_u->>'library_id', '')::uuid;
  v_src := nullif(v_u->>'source_id', '')::bigint;

  -- (0) une seule publication : la republication ne refait rien
  if p_republication or v_d.status = 'published' then
    raise exception 'retirada_ja_publicada' using hint = 'error.publish.item_retrait_already_published';
  end if;
  -- (1) jamais une création : l'exemplaire visé existe, c'est celui de la trace
  if v_d.published_exemplar_id is null or v_d.published_exemplar_id::text is distinct from v_u->>'exemplar_id' then
    raise exception 'retirada_sem_exemplar' using hint = 'error.publish.item_retrait_gone';
  end if;
  select * into v_e from public.exemplares where id = v_d.published_exemplar_id for update;
  if not found then
    raise exception 'retirada_sem_exemplar' using hint = 'error.publish.item_retrait_gone';
  end if;
  -- (2) la bibliothèque : celle de la trace, de l'exemplaire et du brouillon
  if v_lib is null or v_e.library_id is distinct from v_lib
     or coalesce(v_d.target_library_id, v_lib) is distinct from v_lib then
    raise exception 'retirada_biblioteca_alterada' using hint = 'error.publish.item_retrait_library_changed';
  end if;
  -- (3) la notice et le fonds
  select h.book_id into v_book from public.book_holdings h where h.id = v_e.holding_id;
  -- (revue sceptique du 10/10, en-tête (15)) le fonds verrouillé AVANT le
  -- contrôle « engagé » : une réservation du fonds en cours est attendue, puis vue
  perform 1 from public.book_holdings h where h.id = v_e.holding_id for update;
  if v_book is null or v_book::text is distinct from v_u->>'book_id'
     or v_e.holding_id::text is distinct from v_u->>'holding_id'
     or coalesce(v_d.target_holding_id, v_e.holding_id) is distinct from v_e.holding_id then
    raise exception 'retirada_exemplar_movido' using hint = 'error.publish.item_retrait_moved';
  end if;
  -- (4) la source : strictement celle du run (IMP-26 e)
  if v_src is null or v_e.import_source_id is distinct from v_src then
    raise exception 'retirada_fonte_alterada' using hint = 'error.publish.item_retrait_source_changed';
  end if;
  -- (5) le run : présent, de la même source, stable, sans ligne en échec
  select * into v_run from ingest.partner_catalog_import_runs where id = nullif(v_u->>'run_id', '')::bigint;
  if not found or v_run.source_id is distinct from v_src then
    raise exception 'retirada_sem_run' using hint = 'error.publish.item_retrait_run_gone';
  end if;
  if v_run.run_status not in ('ready_for_review', 'drafts_created')
     or exists (select 1 from ingest.partner_catalog_staging_rows sr
                 where sr.run_id = v_run.id and sr.parse_status = 'error') then
    raise exception 'retirada_run_instavel' using hint = 'error.publish.item_retrait_run_unstable';
  end if;
  -- (5 bis) le fichier ACTUEL de la source (revue sceptique du 10/10)
  if ingest.fn_h21_run_courant(v_run.id) is not null then
    raise exception 'retirada_run_superado' using hint = 'error.publish.item_retrait_run_superseded';
  end if;
  -- (6) déjà retiré, déjà levé
  if v_nature = 'retrait' and v_e.retire_at is not null then
    raise exception 'exemplar_ja_retirado' using hint = 'error.publish.item_retrait_already_retired';
  end if;
  if v_nature = 'levee' and v_e.retire_at is null then
    raise exception 'retirada_ja_levantada' using hint = 'error.publish.item_retrait_already_lifted';
  end if;
  -- (7) la révision du lot (IMP-27) : dans un lot, approuvé, couvert par le tour
  if v_d.batch_id is null then
    raise exception 'retirada_fora_de_lote' using hint = 'error.publish.imported_needs_batch';
  end if;
  if public.fn_batch_review_status(v_d.batch_id) is distinct from 'approved' then
    raise exception 'lote_importado_sem_revisao' using hint = 'error.publish.review_required';
  end if;
  if not public.fn_batch_review_couvre(v_d.batch_id, p_draft_id, 'exemplar') then
    raise exception 'rascunho_acrescentado_apos_revisao' using hint = 'error.publish.added_after_review';
  end if;
  -- (8) qui publie : le staff de la bibliothèque de l'exemplaire, ou l'administration
  if auth.uid() is not null and not public.fn_caller_is_network_admin()
     and not public.user_has_library_staff_role(auth.uid(), v_lib) then
    raise exception 'Ce rascunho est rattache a une bibliotheque dont vous n''etes pas membre (%).', v_lib
      using hint = 'error.publish.other_library';
  end if;

  if v_nature = 'retrait' then
    -- (9) engagé entre la proposition et la publication (IMP-34 b) : refus,
    --     rien n'est annulé chez personne
    v_engage := ingest.fn_h21_retrait_engage(v_e.id);
    if v_engage is not null then
      raise exception 'exemplar_engajado: %', v_engage using hint = 'error.publish.item_retrait_engaged';
    end if;
    -- (10) revenu dans le fichier (fichier entier), ou notice sortie du fichier
    if ingest.fn_h21_retrait_dans_le_fichier(v_run.id, v_e.source_item_code, v_e.source_item_id) then
      raise exception 'exemplar_de_volta_no_arquivo' using hint = 'error.publish.item_retrait_back_in_file';
    end if;
    -- (10 bis) un fichier plus récent de la source (archivé compris) le décrit
    if exists (select 1 from ingest.partner_catalog_import_runs r2
                where r2.source_id = v_src and r2.id > v_run.id
                  and ingest.fn_h21_retrait_dans_le_fichier(r2.id, v_e.source_item_code, v_e.source_item_id)) then
      raise exception 'exemplar_num_arquivo_mais_recente' using hint = 'error.publish.item_retrait_in_newer_file';
    end if;
    if not exists (select 1 from ingest.partner_catalog_staging_rows sr
                    where sr.proposed_book_id = v_book and sr.run_id = v_run.id
                      and sr.match_status = 'known_record'
                      and not ingest.fn_h21_rejet_par_choix(sr.editorial_decision, sr.editorial_note, sr.discarded_draft_id)) then
      raise exception 'ficha_fora_do_arquivo' using hint = 'error.publish.item_retrait_notice_absent';
    end if;
    -- l'export complet déclaré (ne change plus après le dispatch : filet)
    if not v_run.export_complet then
      raise exception 'exportacao_completa_ausente' using hint = 'error.import.export_complet_absent';
    end if;
  else
    -- (10 bis) la levée : l'exemplaire est toujours dans le fichier, « déjà là »
    --     ou « réétiqueté » pour CET exemplaire (constat du lot 6a)
    select exists (
      select 1
        from ingest.partner_catalog_staging_rows sr
        cross join lateral jsonb_array_elements(case when jsonb_typeof(sr.normalized_payload->'items') = 'array'
                                                     then sr.normalized_payload->'items' else '[]'::jsonb end) i(v)
       where sr.run_id = v_run.id
         and sr.match_status = 'known_record' and sr.proposed_book_id is not null
         and not ingest.fn_h21_rejet_par_choix(sr.editorial_decision, sr.editorial_note, sr.discarded_draft_id)
         and ((nullif(btrim(v_e.source_item_code), '') is not null
               and (sr.normalized_payload->'items') @> jsonb_build_array(jsonb_build_object('source_item_code', btrim(v_e.source_item_code))))
              or (nullif(btrim(v_e.source_item_id), '') is not null
                  and (sr.normalized_payload->'items') @> jsonb_build_array(jsonb_build_object('source_item_id', btrim(v_e.source_item_id)))))
         and nullif(btrim(i.v->>'source_item_code'), '') is not null
         and (ingest.fn_h21_constat_exemplaire(v_lib, v_src, sr.proposed_book_id,
                                               i.v->>'source_item_code', i.v->>'source_item_id')->>'exemplar_id')::bigint = v_e.id
         and ingest.fn_h21_constat_exemplaire(v_lib, v_src, sr.proposed_book_id,
                                              i.v->>'source_item_code', i.v->>'source_item_id')->>'verdict' in ('deja_la', 'reetiquete'))
      into v_ok;
    if not v_ok then
      raise exception 'exemplar_fora_do_arquivo' using hint = 'error.publish.item_levee_gone_from_file';
    end if;
  end if;

  -- Le geste : le marqueur SEUL (empreinte avant/après de tout le reste)
  v_avant := ingest.fn_h21_empreinte_hors_marqueur(v_e.id);
  perform set_config('anarbib.h21_marqueur_retrait', 'on', true);
  if v_nature = 'retrait' then
    v_trace := jsonb_build_object('version', 'h21-lot7/2026-10-09', 'retire_at', now(), 'retire_by', auth.uid(),
                                  'run_id', v_run.id, 'source_id', v_src, 'draft_id', p_draft_id,
                                  'batch_id', v_d.batch_id, 'code', v_e.source_item_code, 'expl_id', v_e.source_item_id,
                                  'proposed_at', v_u->'proposed_at', 'proposed_by', v_u->'proposed_by');
    update public.exemplares
       set retire_at = now(), retire_run_id = v_run.id, retire_trace = v_trace
     where id = v_e.id;
  else
    v_trace := coalesce(v_e.retire_trace, '{}'::jsonb)
               || jsonb_build_object('leve_at', now(), 'leve_by', auth.uid(), 'leve_run_id', v_run.id,
                                     'leve_draft_id', p_draft_id, 'leve_batch_id', v_d.batch_id,
                                     'leve_constat', v_u->'constat');
    update public.exemplares
       set retire_at = NULL, retire_run_id = NULL, retire_trace = v_trace
     where id = v_e.id;
  end if;
  perform set_config('anarbib.h21_marqueur_retrait', '', true);
  if ingest.fn_h21_empreinte_hors_marqueur(v_e.id) is distinct from v_avant then
    raise exception 'retirada_efeito_colateral' using hint = 'error.publish.item_retrait_side_effect';
  end if;
  -- la disponibilité du fonds (le déclencheur de l'exemplaire l'a recalculée ;
  -- explicite ici : le compte suit le marqueur)
  perform public.fn_v2_recompute_holdings_availability(p_holding_ids := array[v_e.holding_id]);

  update public.exemplar_drafts
     set status = 'published',
         label_status = 'ready',
         import_retrait = jsonb_set(import_retrait, '{publication}',
                                    jsonb_build_object('published_at', now(), 'published_by', auth.uid())),
         updated_by = coalesce(auth.uid(), updated_by),
         updated_at = now()
   where id = p_draft_id;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, library_id, label, details)
  values (auth.uid(), case when v_nature = 'retrait' then 'import_retrait_pose' else 'import_retrait_leve' end,
          'exemplar', v_e.id, v_lib, coalesce(v_e.tombo, v_e.bib_ref),
          jsonb_build_object('via', 'publish_exemplar_draft', 'draft_id', p_draft_id, 'run_id', v_run.id,
                             'source_id', v_src, 'batch_id', v_d.batch_id));
  return v_e.id;
end;
$function$;
COMMENT ON FUNCTION ingest.fn_h21_publier_retrait(bigint, boolean) IS
  'H21 lot 7 (IMP-26 d, IMP-34) : publication d''un brouillon de retrait ou de levée — garde (jamais une création, bibliothèque, notice et fonds, source, run stable, déjà retiré / levé, révision du lot, staff ; retrait : engagé, revenu dans le fichier, notice sortie, export complet ; levée : toujours dans le fichier) puis le marqueur seul (empreinte avant/après). Republication refusée. Interne : publish_exemplar_draft.';


-- ─────────────────────────────────────────────────────────────────────
-- 6. Droits des aides (internes)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l7_droits$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'ingest.fn_h21_retrait_engage(bigint)', 'ingest.fn_h21_empreinte_hors_marqueur(bigint)',
    'ingest.fn_h21_retrait_dans_le_fichier(bigint, text, text)', 'ingest.fn_h21_acces_retraits(bigint)',
    'ingest.fn_h21_retraits_par_appel()', 'ingest.fn_h21_retraits_constat(bigint, boolean, boolean)',
    'ingest.fn_h21_retraits_bilan(bigint, boolean, integer, integer)',
    'ingest.fn_h21_publier_retrait(bigint, boolean)', 'ingest.fn_h21_run_courant(bigint)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
  END LOOP;
END
$h21l7_droits$;


-- ─────────────────────────────────────────────────────────────────────
-- 7. Les portes : drapeau, confirmation, constat, proposition
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_import_set_export_complet(p_run_id bigint, p_export_complet boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid;
  v_run ingest.partner_catalog_import_runs%rowtype;
BEGIN
  v_uid := ingest.fn_h21_acces_retraits(p_run_id);
  SELECT * INTO v_run FROM ingest.partner_catalog_import_runs WHERE id = p_run_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;
  -- Avant le dispatch seulement : jamais démarré, jamais envoyé (voir l'en-tête, (1)).
  IF v_run.run_status IS DISTINCT FROM 'uploaded' OR v_run.started_at IS NOT NULL
     OR EXISTS (SELECT 1 FROM ingest.partner_catalog_import_dispatch_log g WHERE g.run_id = p_run_id) THEN
    RAISE EXCEPTION 'Exportacao completa so se declara antes do envio do arquivo (run %).', p_run_id
      USING HINT = 'error.import.export_complet_after_dispatch';
  END IF;
  UPDATE ingest.partner_catalog_import_runs
     SET export_complet = coalesce(p_export_complet, false),
         export_complet_par = CASE WHEN coalesce(p_export_complet, false) THEN v_uid END,
         export_complet_le = CASE WHEN coalesce(p_export_complet, false) THEN now() END
   WHERE id = p_run_id;
  RETURN jsonb_build_object('ok', true, 'run_id', p_run_id, 'export_complet', coalesce(p_export_complet, false));
END;
$function$;
COMMENT ON FUNCTION public.fn_import_set_export_complet(bigint, boolean) IS
  'H21 lot 7 (IMP-26 f) : déclarer au dépôt que le fichier est un export complet (sans quoi aucune disparition n''est proposée au retrait) — avant le dispatch seulement ; coordination de la bibliothèque du run, administration (dépôt compagnon, OAI : administration seule).';

CREATE OR REPLACE FUNCTION public.fn_import_confirmer_export_complet(p_run_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid;
  v_run ingest.partner_catalog_import_runs%rowtype;
BEGIN
  v_uid := ingest.fn_h21_acces_retraits(p_run_id);
  SELECT * INTO v_run FROM ingest.partner_catalog_import_runs WHERE id = p_run_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;
  IF NOT v_run.export_complet THEN
    RAISE EXCEPTION 'Run % sem exportacao completa declarada.', p_run_id
      USING HINT = 'error.import.export_complet_absent';
  END IF;
  IF v_run.retraits_confirmes_le IS NULL THEN
    UPDATE ingest.partner_catalog_import_runs
       SET retraits_confirmes_par = v_uid, retraits_confirmes_le = now()
     WHERE id = p_run_id
     RETURNING * INTO v_run;
  END IF;
  RETURN jsonb_build_object('ok', true, 'run_id', p_run_id,
                            'confirme_par', v_run.retraits_confirmes_par, 'confirme_le', v_run.retraits_confirmes_le);
END;
$function$;
COMMENT ON FUNCTION public.fn_import_confirmer_export_complet(bigint) IS
  'H21 lot 7 (IMP-34 a) : au-delà du seuil, la coordination confirme « c''est bien un export complet » pour ce run (qui, quand ; la première confirmation reste). Exige le drapeau export complet.';

CREATE OR REPLACE FUNCTION public.fn_import_retraits(p_run_id bigint, p_limite integer DEFAULT 200, p_decalage integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth', 'pg_temp'
AS $function$
BEGIN
  PERFORM ingest.fn_h21_acces_retraits(p_run_id);
  RETURN ingest.fn_h21_retraits_bilan(p_run_id, true, least(greatest(coalesce(p_limite, 200), 1), 200),
                                      greatest(coalesce(p_decalage, 0), 0));
END;
$function$;
COMMENT ON FUNCTION public.fn_import_retraits(bigint, integer, integer) IS
  'H21 lot 7 (IMP-34) : le constat des retraits d''un run pour l''écran — conditions, comptes par verdict (disparu, disparu_engage, disparu_brouillon, retire_reapparu), seuil et confirmation, blocages, une page de 200 exemplaires. Lecture seule ; coordination de la bibliothèque du run, administration.';

CREATE OR REPLACE FUNCTION public.fn_import_proposer_retraits(p_run_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid;
  v_lib uuid;
  v_bilan jsonb;
  v_ok_r boolean;
  v_ok_l boolean;
  v_n integer;
  v_batch bigint;
  v_crees bigint[] := '{}'::bigint[];
BEGIN
  v_uid := ingest.fn_h21_acces_retraits(p_run_id);
  -- H31 : le verrou du run des conversions, après les contrôles d'accès.
  PERFORM 1 FROM ingest.partner_catalog_import_runs WHERE id = p_run_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;
  v_lib := ingest.fn_h21_bibliotheque_importatrice(p_run_id, NULL, NULL);
  IF v_lib IS NOT NULL THEN
    -- deux propositions de la même bibliothèque attendent l'une l'autre
    PERFORM pg_advisory_xact_lock(hashtextextended('h21-lot7/retraits/' || v_lib::text, 0));
  END IF;

  v_bilan := ingest.fn_h21_retraits_bilan(p_run_id, false, 0, 0);
  v_ok_r := v_bilan->>'bloque_retraits' IS NULL;
  v_ok_l := v_bilan->>'bloque_levees' IS NULL;

  -- (les proposables, comptés par le bilan sur le même constat)
  v_n := coalesce((v_bilan->'proposables'->>'retraits')::int, 0) + coalesce((v_bilan->'proposables'->>'levees')::int, 0);

  IF v_n > 0 THEN
    -- dans le lot ouvert du run (IMP-27 d), sinon un lot neuf de la bibliothèque
    v_batch := ingest.fn_h21_lot_ouvert_du_run(p_run_id, v_lib);
    IF v_batch IS NULL THEN
      v_batch := ingest.fn_h21_lot_de_la_mise_a_jour(p_run_id, v_lib, v_uid);
    END IF;

    -- La COPIE COMPLÈTE de l'exemplaire (comme le lot 6b), la trace
    -- import_retrait ; created_at ≠ now() : jamais une « reprise vierge ».
    WITH cand AS (
      SELECT c.*
        FROM ingest.fn_h21_retraits_constat(p_run_id, v_ok_r, v_ok_l) c
       WHERE (c.verdict = 'disparu' AND v_ok_r) OR (c.verdict = 'retire_reapparu' AND c.draft_id IS NULL AND v_ok_l)
       ORDER BY c.exemplar_id
       LIMIT ingest.fn_h21_retraits_par_appel()
    ), ins AS (
      INSERT INTO public.exemplar_drafts (
        published_exemplar_id, batch_id, action, status, label_status,
        target_bib_ref, target_library_id, target_holding_id, tombo,
        shelf_location, label_title_override, label_author_override, label_cdd_override, label_note, notes,
        acquisition_mode, acquisition_date, provenance_note, source_library, circulation_policy, visibility,
        source_item_code, source_item_id, import_source_id, import_run_id,
        import_retrait, created_by, updated_by, created_at
      )
      SELECT e.id, v_batch, 'update', 'draft', 'pending',
             coalesce(nullif(btrim(h.local_bib_ref), ''), b.bib_ref, e.bib_ref), e.library_id, e.holding_id, e.tombo,
             e.shelf_location, e.label_title_override, e.label_author_override, e.label_cdd_override, e.label_note, e.notes,
             e.acquisition_mode, e.acquisition_date, e.provenance_note, e.source_library, e.circulation_policy, e.visibility,
             e.source_item_code, e.source_item_id, e.import_source_id, e.import_run_id,
             jsonb_build_object(
               'version', 'h21-lot7/2026-10-09',
               'nature', CASE WHEN a.verdict = 'disparu' THEN 'retrait' ELSE 'levee' END,
               'run_id', p_run_id,
               'source_id', (v_bilan->>'source_id')::bigint,
               'library_id', v_lib,
               'exemplar_id', e.id,
               'book_id', a.book_id,
               'holding_id', a.holding_id,
               'tombo', e.tombo,
               'code', a.code,
               'expl_id', a.expl_id,
               'verdict', a.verdict,
               'staging_row_id', a.staging_row_id,
               'constat', a.constat,
               'seuil', v_bilan->'seuil',
               'confirme_le', v_bilan->'confirme_le',
               'proposed_at', now(),
               'proposed_by', v_uid),
             v_uid, v_uid, greatest(clock_timestamp(), now() + interval '1 microsecond')
        FROM cand a
        JOIN public.exemplares e ON e.id = a.exemplar_id AND e.library_id = v_lib
        LEFT JOIN public.book_holdings h ON h.id = e.holding_id
        LEFT JOIN public.books b ON b.id = h.book_id
      RETURNING id
    )
    SELECT coalesce(array_agg(ins.id), '{}'::bigint[]) INTO v_crees FROM ins;
  END IF;

  RETURN jsonb_build_object(
    'run_id', p_run_id,
    'batch_id', v_batch,
    'retraits', (SELECT count(*) FROM public.exemplar_drafts x WHERE x.id = ANY (v_crees) AND x.import_retrait->>'nature' = 'retrait'),
    'levees', (SELECT count(*) FROM public.exemplar_drafts x WHERE x.id = ANY (v_crees) AND x.import_retrait->>'nature' = 'levee'),
    'reste', greatest(v_n - cardinality(v_crees), 0),
    'ignores', jsonb_build_object('disparu_engage', coalesce((v_bilan->'counts'->>'disparu_engage')::int, 0),
                                  'disparu_brouillon', coalesce((v_bilan->'counts'->>'disparu_brouillon')::int, 0)),
    'bloque_retraits', v_bilan->'bloque_retraits',
    'bloque_levees', v_bilan->'bloque_levees',
    'seuil', v_bilan->'seuil');
END;
$function$;
COMMENT ON FUNCTION public.fn_import_proposer_retraits(bigint) IS
  'H21 lot 7 (IMP-26 d, IMP-34) : « Proposer les retraits » — un brouillon de retrait par exemplaire disparu proposable, un brouillon de levée par retiré réapparu, dans le lot ouvert du run (révision obligatoire) ; rien au-delà du seuil sans confirmation, rien sans export complet ; 1 000 au plus par appel (l''écran rappelle). Coordination de la bibliothèque du run, administration.';

DO $h21l7_portes$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.fn_import_set_export_complet(bigint, boolean)', 'public.fn_import_confirmer_export_complet(bigint)',
    'public.fn_import_retraits(bigint, integer, integer)', 'public.fn_import_proposer_retraits(bigint)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', f);
  END LOOP;
END
$h21l7_portes$;


-- ─────────────────────────────────────────────────────────────────────
-- 8. publish_exemplar_draft : le retrait et la levée, avant les portes et la
--    branche
-- ─────────────────────────────────────────────────────────────────────
DO $h21l7_publication$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l7_def('public.publish_exemplar_draft(bigint)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('publish_exemplar_draft (retrait)', v_def,
$a$  if v_draft.import_update is not null then
    perform ingest.fn_h21_garde_mise_a_jour_exemplaire(p_draft_id, v_draft.status = 'published');
    v_maj_exemplaire := v_draft.status is distinct from 'published';
  end if;
$a$,
$b$  if v_draft.import_update is not null then
    perform ingest.fn_h21_garde_mise_a_jour_exemplaire(p_draft_id, v_draft.status = 'published');
    v_maj_exemplaire := v_draft.status is distinct from 'published';
  end if;

  -- H21 lot 7 (09/10/2026, IMP-26 d, IMP-34) : un brouillon de RETRAIT ou de
  -- LEVÉE (trace import_retrait, figée pour l'API) ne passe par aucune des
  -- deux branches : jugé et fait à part, AVANT les portes de révision et le
  -- choix de branche — la publication ne change que le marqueur ; la
  -- republication est refusée (ingest.fn_h21_publier_retrait).
  if v_draft.import_retrait is not null then
    return ingest.fn_h21_publier_retrait(p_draft_id, v_draft.status = 'published');
  end if;
$b$);
  EXECUTE v_def;
END
$h21l7_publication$;


-- ─────────────────────────────────────────────────────────────────────
-- 9. La trace d'un brouillon de retrait : jamais par l'API
-- ─────────────────────────────────────────────────────────────────────
DO $h21l7_trace$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l7_def('public.tg_exemplar_drafts_import_links_locked()'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('tg_exemplar_drafts_import_links_locked', v_def,
$a$    RAISE EXCEPTION 'Rastro de atualizacao do exemplar reservado ao circuito de importacao.'
      USING ERRCODE = '42501', HINT = 'error.import.item_update_trace_reserved';
  END IF;
$a$,
$b$    RAISE EXCEPTION 'Rastro de atualizacao do exemplar reservado ao circuito de importacao.'
      USING ERRCODE = '42501', HINT = 'error.import.item_update_trace_reserved';
  END IF;
  -- H21 lot 7 (09/10/2026) : la trace d'un brouillon de retrait ou de levée
  -- (import_retrait) ne se pose ni ne se change par l'API, à l'INSERT comme à
  -- l'UPDATE ; l'exemplaire visé d'un tel brouillon non plus.
  IF (TG_OP = 'INSERT' AND NEW.import_retrait IS NOT NULL)
     OR (TG_OP = 'UPDATE' AND (NEW.import_retrait IS DISTINCT FROM OLD.import_retrait
                               OR (OLD.import_retrait IS NOT NULL
                                   AND NEW.published_exemplar_id IS DISTINCT FROM OLD.published_exemplar_id))) THEN
    RAISE EXCEPTION 'Rastro de retirada do exemplar reservado ao circuito de importacao.'
      USING ERRCODE = '42501', HINT = 'error.import.item_retrait_trace_reserved';
  END IF;
$b$);
  EXECUTE v_def;
END
$h21l7_trace$;


-- ─────────────────────────────────────────────────────────────────────
-- 10. Un seul brouillon vivant par exemplaire (exclusivité du lot 6b étendue)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l7_exclusif$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l7_def('public.tg_exemplar_drafts_maj_import_exclusive()'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('tg_exemplar_drafts_maj_import_exclusive', v_def,
$a$  IF EXISTS (SELECT 1 FROM public.exemplar_drafts y
              WHERE y.published_exemplar_id = NEW.published_exemplar_id
                AND y.status IN ('draft', 'ready') AND y.import_update IS NOT NULL
                AND y.id IS DISTINCT FROM NEW.id) THEN$a$,
$b$  -- H21 lot 7 (09/10/2026) : un brouillon de retrait ou de levée vivant tient
  -- l'exemplaire comme une mise à jour d'import (« Éditer », une mise à jour,
  -- un autre retrait attendent) ; et un retrait ne naît ni ne revient à côté
  -- d'un autre brouillon vivant, quel qu'il soit.
  IF EXISTS (SELECT 1 FROM public.exemplar_drafts y
              WHERE y.published_exemplar_id = NEW.published_exemplar_id
                AND y.status IN ('draft', 'ready') AND y.import_retrait IS NOT NULL
                AND y.id IS DISTINCT FROM NEW.id) THEN
    IF NEW.import_retrait IS NOT NULL OR NEW.import_update IS NOT NULL THEN
      RAISE EXCEPTION 'retirada_de_exemplar_substituida: %', NEW.published_exemplar_id
        USING HINT = 'error.import.item_retrait_superseded';
    END IF;
    RAISE EXCEPTION 'exemplar_com_retirada_pendente: %', NEW.published_exemplar_id
      USING HINT = 'error.catalog.item_retrait_pending';
  END IF;
  IF NEW.import_retrait IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.exemplar_drafts y
                  WHERE y.published_exemplar_id = NEW.published_exemplar_id
                    AND y.status IN ('draft', 'ready')
                    AND y.id IS DISTINCT FROM NEW.id) THEN
    RAISE EXCEPTION 'retirada_de_exemplar_substituida: %', NEW.published_exemplar_id
      USING HINT = 'error.import.item_retrait_superseded';
  END IF;
  IF EXISTS (SELECT 1 FROM public.exemplar_drafts y
              WHERE y.published_exemplar_id = NEW.published_exemplar_id
                AND y.status IN ('draft', 'ready') AND y.import_update IS NOT NULL
                AND y.id IS DISTINCT FROM NEW.id) THEN$b$);
  EXECUTE v_def;
END
$h21l7_exclusif$;


-- ─────────────────────────────────────────────────────────────────────
-- 11. Le lot : né d'un import, retrouvé par le run ; une fusion de brouillons
--     n'emporte pas un retrait
-- ─────────────────────────────────────────────────────────────────────
DO $h21l7_lot$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l7_def('public.fn_batch_is_imported(bigint)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('fn_batch_is_imported', v_def,
$a$              and x.import_staging_row_id is not null
         );$a$,
$b$              and x.import_staging_row_id is not null
         )
      -- H21 lot 7 (09/10/2026) : un lot qui contient un brouillon de retrait ou
      -- de levée (sans ligne : un disparu n'en a pas) est né d'un import.
      or exists (
           select 1 from public.exemplar_drafts x
            where x.batch_id = p_batch_id
              and x.import_retrait is not null
         );$b$);
  EXECUTE v_def;

  v_def := pg_temp.h21l7_def('ingest.fn_h21_lot_ouvert_du_run(bigint, uuid)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('fn_h21_lot_ouvert_du_run', v_def,
$a$                       WHERE sr.run_id = p_run_id AND x.batch_id IS NOT NULL))$a$,
$b$                       WHERE sr.run_id = p_run_id AND x.batch_id IS NOT NULL)
          -- H21 lot 7 : ou par un brouillon de retrait ou de levée de ce run
          OR b.id IN (SELECT x.batch_id FROM public.exemplar_drafts x
                       WHERE x.import_retrait IS NOT NULL AND x.import_retrait->>'run_id' = p_run_id::text
                         AND x.batch_id IS NOT NULL))$b$);
  EXECUTE v_def;

  v_def := pg_temp.h21l7_def('api.merge_book_drafts(bigint, bigint, jsonb)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('api.merge_book_drafts', v_def,
$a$                  AND x.import_update IS NOT NULL) THEN$a$,
$b$                  AND (x.import_update IS NOT NULL
                       OR x.import_retrait IS NOT NULL)) THEN   -- H21 lot 7 : ni un retrait$b$);
  EXECUTE v_def;
END
$h21l7_lot$;


-- ─────────────────────────────────────────────────────────────────────
-- 12. La circulation : un retiré n'est ni prêté, ni réservé, ni consulté,
--     ni en PEB, ni compté
-- ─────────────────────────────────────────────────────────────────────
DO $h21l7_circulation$
DECLARE v_def text;
BEGIN
  -- la disponibilité (et donc l'OPAC, qui lit les comptes du fonds)
  v_def := pg_temp.h21l7_def('public.fn_v2_recompute_holdings_availability(bigint[], bigint[])'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('fn_v2_recompute_holdings_availability', v_def,
$a$      and e.visibility = 'public'   -- P1.4a
$a$,
$b$      and e.visibility = 'public'   -- P1.4a
      and e.retire_at is null       -- H21 lot 7 : un retiré ne compte pas
$b$, 4);
  EXECUTE v_def;

  -- le prêt
  v_def := pg_temp.h21l7_def('public.fn_v2_create_emprestimo_by_holdings(uuid, bigint[], date, text)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('fn_v2_create_emprestimo_by_holdings', v_def,
$a$      and e.visibility = 'public'                            -- P1.4b §6.2
$a$,
$b$      and e.visibility = 'public'                            -- P1.4b §6.2
      and e.retire_at is null                                -- H21 lot 7
$b$, 2);
  EXECUTE v_def;

  -- la consultation (le résolveur, et le message « aucune consultable »)
  v_def := pg_temp.h21l7_def('public.fn_v2_resolve_consulta_exemplar(bigint)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('fn_v2_resolve_consulta_exemplar', v_def,
$a$    AND e.visibility = 'public'                          -- P1.4b §6.2
$a$,
$b$    AND e.visibility = 'public'                          -- P1.4b §6.2
    AND e.retire_at IS NULL                              -- H21 lot 7
$b$);
  EXECUTE v_def;
  v_def := pg_temp.h21l7_def('public.fn_v2_create_consulta_local_by_holdings(uuid, bigint[], timestamp with time zone, text)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('fn_v2_create_consulta_local_by_holdings', v_def,
$a$          and e.visibility = 'public'
          and e.circulation_policy in ('consulta', 'ambos')
$a$,
$b$          and e.visibility = 'public'
          and e.retire_at is null   -- H21 lot 7
          and e.circulation_policy in ('consulta', 'ambos')
$b$);
  EXECUTE v_def;

  -- la recherche PEB
  v_def := pg_temp.h21l7_def('public.fn_peb_search_exemplares(text, uuid)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('fn_peb_search_exemplares', v_def,
$a$    AND e.visibility = 'public'
    AND e.circulation_policy IN ('emprestavel', 'ambos')
$a$,
$b$    AND e.visibility = 'public'
    AND e.retire_at IS NULL   -- H21 lot 7
    AND e.circulation_policy IN ('emprestavel', 'ambos')
$b$);
  EXECUTE v_def;

  -- les quatre trous (retrait seulement ; le trou visibility est consigné)
  v_def := pg_temp.h21l7_def('public.fn_v2_create_reserva_by_holdings(uuid, bigint[], timestamp with time zone, text)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('fn_v2_create_reserva_by_holdings', v_def,
$a$        where e.holding_id = h.id
      ) as exemplares_total,$a$,
$b$        where e.holding_id = h.id
          and e.retire_at is null   -- H21 lot 7 : un retiré ne se réserve pas
      ) as exemplares_total,$b$);
  EXECUTE v_def;

  v_def := pg_temp.h21l7_def('public.fn_v2_convert_reserva_linhas_to_emprestimo(bigint, integer[], date, text)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('fn_v2_convert_reserva_linhas_to_emprestimo', v_def,
$a$e.library_id = v_reserva.library_id
$a$,
$b$e.library_id = v_reserva.library_id
        and e.retire_at is null   -- H21 lot 7
$b$, 4);
  EXECUTE v_def;

  v_def := pg_temp.h21l7_def('public.fn_v2_add_emprestimo_interbibliotecas_itens(bigint, bigint[], date, text)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('fn_v2_add_emprestimo_interbibliotecas_itens', v_def,
$a$    if exists (
      select 1
      from public.emprestimo_itens_v2 i
      where i.item_id = v_item_id
        and i.item_status = 'aberto'
    ) then$a$,
$b$    -- H21 lot 7 (09/10/2026) : un retiré ne part pas en PEB
    if exists (select 1 from public.exemplares x where x.id = v_item_id and x.retire_at is not null) then
      v_unavailable := array_append(v_unavailable, v_item_id);
      continue;
    end if;

    if exists (
      select 1
      from public.emprestimo_itens_v2 i
      where i.item_id = v_item_id
        and i.item_status = 'aberto'
    ) then$b$);
  EXECUTE v_def;

  v_def := pg_temp.h21l7_def('public.fn_peb_create_loan_with_items(jsonb, jsonb)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('fn_peb_create_loan_with_items', v_def,
$a$      SELECT (
           EXISTS (SELECT 1 FROM emprestimo_itens_v2 ei$a$,
$b$      -- H21 lot 7 (09/10/2026) : un retiré ne part pas en PEB
      IF EXISTS (SELECT 1 FROM public.exemplares x WHERE x.id = v_item_id AND x.retire_at IS NOT NULL) THEN
        RAISE EXCEPTION 'fn_peb_create_loan_with_items: exemplaire id=% sorti du catalogue d''origine (retire)', v_item_id
          USING HINT = 'error.circulation.item_retired';
      END IF;

      SELECT (
           EXISTS (SELECT 1 FROM emprestimo_itens_v2 ei$b$);
  EXECUTE v_def;
END
$h21l7_circulation$;


-- ─────────────────────────────────────────────────────────────────────
-- 13. Lecture : anon ne voit pas un retiré ; le staff de sa bibliothèque oui
-- ─────────────────────────────────────────────────────────────────────
DO $h21l7_rls$
DECLARE v_q text; p text;
BEGIN
  FOREACH p IN ARRAY ARRAY['exemplares_public_read', 'exemplares_select_authenticated'] LOOP
    SELECT pg_get_expr(polqual, polrelid) INTO v_q FROM pg_policy
     WHERE polrelid = 'public.exemplares'::regclass AND polname = p;
    IF v_q IS NULL THEN
      RAISE EXCEPTION 'H21 lot 7 — politique % absente', p;
    END IF;
    v_q := pg_temp.h21l7_remplacer('politique ' || p, v_q,
      '(exemplares.visibility = ''public''::text)',
      '((exemplares.visibility = ''public''::text) AND (exemplares.retire_at IS NULL))');
    EXECUTE format('ALTER POLICY %I ON public.exemplares USING (%s)', p, v_q);
  END LOOP;
END
$h21l7_rls$;


-- ─────────────────────────────────────────────────────────────────────
-- 14. L'export : un retiré n'en sort pas (sinon il repart vers la source)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l7_export$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l7_def('public.fn_export_catalog_lote(uuid, bigint, integer)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('fn_export_catalog_lote', v_def,
$a$             WHERE h.book_id = b.id AND h.library_id = p_library_id AND e.library_id = p_library_id),$a$,
$b$             WHERE h.book_id = b.id AND h.library_id = p_library_id AND e.library_id = p_library_id
               AND e.retire_at IS NULL),   -- H21 lot 7 : un retiré n'est pas exporté$b$);
  EXECUTE v_def;
END
$h21l7_export$;


-- ─────────────────────────────────────────────────────────────────────
-- 15. Le récolement : « retiré », pas « manquant »
-- ─────────────────────────────────────────────────────────────────────
DO $h21l7_recolement$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l7_def('api.recolement_start(uuid)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('recolement_start', v_def,
$a$  SELECT count(*) INTO v_acervo FROM public.exemplares WHERE library_id = p_library_id;$a$,
$b$  SELECT count(*) INTO v_acervo FROM public.exemplares WHERE library_id = p_library_id
     AND retire_at IS NULL;   -- H21 lot 7 : un retiré n'est pas attendu en rayon$b$);
  EXECUTE v_def;

  v_def := pg_temp.h21l7_def('api.recolement_scan(uuid, bigint)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('recolement_scan', v_def,
$a$    'scanned_count', v_count
  );$a$,
$b$    'scanned_count', v_count,
    -- H21 lot 7 : l'exemplaire scanné est sorti du catalogue d'origine
    'retire', (v_ex.retire_at IS NOT NULL)
  );$b$);
  EXECUTE v_def;

  v_def := pg_temp.h21l7_def('api.recolement_finish(uuid)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('recolement_finish (déclarations)', v_def,
$a$  v_missing jsonb; v_intrus_list jsonb;$a$,
$b$  v_missing jsonb; v_intrus_list jsonb;
  v_retires jsonb; v_present_retires int;   -- H21 lot 7$b$);
  v_def := pg_temp.h21l7_remplacer('recolement_finish (fonds)', v_def,
$a$  SELECT count(*) INTO v_acervo  FROM public.exemplares WHERE library_id = v_lib;$a$,
$b$  SELECT count(*) INTO v_acervo  FROM public.exemplares WHERE library_id = v_lib
     AND retire_at IS NULL;   -- H21 lot 7$b$);
  v_def := pg_temp.h21l7_remplacer('recolement_finish (présents)', v_def,
$a$      AND EXISTS (SELECT 1 FROM public.exemplares e WHERE e.id = s.exemplar_id AND e.library_id = v_lib);
  v_intrus := v_scanned - v_present;$a$,
$b$      AND EXISTS (SELECT 1 FROM public.exemplares e WHERE e.id = s.exemplar_id AND e.library_id = v_lib
                    AND e.retire_at IS NULL);
  -- H21 lot 7 : un retiré scanné n'est ni présent attendu ni intrus
  SELECT count(*) INTO v_present_retires FROM public.recolement_scans s
    WHERE s.session_id = p_session_id
      AND EXISTS (SELECT 1 FROM public.exemplares e WHERE e.id = s.exemplar_id AND e.library_id = v_lib
                    AND e.retire_at IS NOT NULL);
  v_intrus := v_scanned - v_present - v_present_retires;$b$);
  v_def := pg_temp.h21l7_remplacer('recolement_finish (manquants)', v_def,
$a$    WHERE e.library_id = v_lib
      AND NOT EXISTS (SELECT 1 FROM public.recolement_scans s WHERE s.session_id = p_session_id AND s.exemplar_id = e.id);$a$,
$b$    WHERE e.library_id = v_lib
      AND e.retire_at IS NULL   -- H21 lot 7 : « retiré », pas « manquant »
      AND NOT EXISTS (SELECT 1 FROM public.recolement_scans s WHERE s.session_id = p_session_id AND s.exemplar_id = e.id);

  -- H21 lot 7 (09/10/2026) : les retirés de la bibliothèque, à part
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'exemplar_id', e.id, 'tombo', e.tombo, 'shelf', e.shelf_location, 'retire_at', e.retire_at,
           'title', (SELECT b.titulo FROM public.book_holdings h JOIN public.books b ON b.id = h.book_id WHERE h.id = e.holding_id),
           'scanned', EXISTS (SELECT 1 FROM public.recolement_scans s WHERE s.session_id = p_session_id AND s.exemplar_id = e.id)
         ) ORDER BY e.tombo), '[]'::jsonb)
    INTO v_retires
    FROM public.exemplares e
    WHERE e.library_id = v_lib AND e.retire_at IS NOT NULL;$b$);
  v_def := pg_temp.h21l7_remplacer('recolement_finish (rendu)', v_def,
$a$    'intrus', v_intrus_list
  );$a$,
$b$    'intrus', v_intrus_list,
    'retired_count', jsonb_array_length(v_retires),   -- H21 lot 7
    'retired', v_retires
  );$b$);
  EXECUTE v_def;
END
$h21l7_recolement$;


-- ─────────────────────────────────────────────────────────────────────
-- 16. Le rapport de révision : retraits et levées proposés, disparus
--     engagés, seuil et confirmation
-- ─────────────────────────────────────────────────────────────────────
DO $h21l7_rapport$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l7_def('public.fn_batch_review_report(bigint)'::regprocedure);
  v_def := pg_temp.h21l7_remplacer('fn_batch_review_report (déclarations)', v_def,
$a$  v_prep_ex jsonb;   -- H21 lot 6b$a$,
$b$  v_prep_ex jsonb;   -- H21 lot 6b
  v_retraits jsonb;  -- H21 lot 7$b$);
  v_def := pg_temp.h21l7_remplacer('fn_batch_review_report (section)', v_def,
$a$  return jsonb_build_object(
    'batch', jsonb_build_object($a$,
$b$  -- ── H21 lot 7 (09/10/2026, IMP-26 d, IMP-34) : les brouillons de retrait
  -- et de levée du lot (trace import_retrait) — comptes, 40 exemples ; pour
  -- chaque run concerné, le constat (disparus engagés compris), le seuil et
  -- la confirmation. Clé absente sans tel brouillon.
  with rx as materialized (
    select x.id, x.status, x.published_exemplar_id, x.tombo, x.source_item_code, x.import_retrait as u
      from public.exemplar_drafts x
     where x.batch_id = p_batch_id and x.status in ('draft', 'ready', 'published')
       and x.import_retrait is not null
  )
  select case when (select count(*) from rx) = 0 then null else jsonb_build_object(
           'count', (select count(*) from rx),
           'retraits', (select count(*) from rx where u->>'nature' = 'retrait'),
           'levees', (select count(*) from rx where u->>'nature' = 'levee'),
           'published', (select count(*) from rx where status = 'published'),
           'examples', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'item_draft_id', m.id, 'exemplar_id', m.published_exemplar_id, 'tombo', m.tombo,
                      'code', m.source_item_code, 'nature', m.u->>'nature', 'book_id', (m.u->>'book_id')::bigint,
                      'titulo', (select b.titulo from public.books b where b.id = (m.u->>'book_id')::bigint),
                      'status', m.status) order by m.id)
               from (select * from rx order by id limit 40) m), '[]'::jsonb),
           'runs', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'run_id', k.run_id,
                      'bilan', ingest.fn_h21_retraits_bilan(k.run_id, false, 0, 0),
                      'engages', (select coalesce(jsonb_agg(jsonb_build_object('exemplar_id', c.exemplar_id, 'tombo', c.tombo,
                                                                               'motif', c.motif, 'book_id', c.book_id)
                                                            order by c.tombo, c.exemplar_id), '[]'::jsonb)
                                    from (select * from ingest.fn_h21_retraits_constat(k.run_id, true, false) c0
                                           where c0.verdict = 'disparu_engage' order by c0.tombo, c0.exemplar_id limit 40) c))
                    order by k.run_id)
               from (select distinct (u->>'run_id')::bigint as run_id from rx
                      where exists (select 1 from ingest.partner_catalog_import_runs r where r.id = (rx.u->>'run_id')::bigint)) k), '[]'::jsonb))
         end
    into v_retraits;

  return jsonb_build_object(
    'batch', jsonb_build_object($b$);
  v_def := pg_temp.h21l7_remplacer('fn_batch_review_report (rendu)', v_def,
$a$    || case when v_prep_ex is null then '{}'::jsonb else jsonb_build_object('prepared_item_updates', v_prep_ex) end;   -- H21 lot 6b$a$,
$b$    || case when v_prep_ex is null then '{}'::jsonb else jsonb_build_object('prepared_item_updates', v_prep_ex) end   -- H21 lot 6b
    || case when v_retraits is null then '{}'::jsonb else jsonb_build_object('retraits', v_retraits) end;   -- H21 lot 7$b$);
  EXECUTE v_def;
END
$h21l7_rapport$;


-- ─────────────────────────────────────────────────────────────────────
-- 17. Vérification (structurelle : les migrations passent avant le seed)
-- ─────────────────────────────────────────────────────────────────────
DO $h21l7_verif$
DECLARE
  v_e text := '';
  v_def text;
  v_f text;
BEGIN
  -- le marqueur : colonnes, clé étrangère indexée, déclencheur INSERT ET UPDATE
  IF NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.exemplares'::regclass
                  AND t.tgname = 'exemplares_marqueur_retrait' AND NOT t.tgisinternal
                  AND t.tgfoid = 'public.tg_exemplares_marqueur_retrait()'::regprocedure
                  AND (t.tgtype & 2) = 2 AND (t.tgtype & 4) = 4 AND (t.tgtype & 16) = 16)
     OR NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conname = 'exemplares_retire_run_id_fkey' AND c.confdeltype = 'n')
     OR NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = 'public.exemplares'::regclass
                     AND i.indkey[0] = (SELECT attnum FROM pg_attribute WHERE attrelid = 'public.exemplares'::regclass AND attname = 'retire_run_id')) THEN
    v_e := v_e || ' marqueur';
  END IF;
  -- (revue sceptique du 10/10) jamais supprimé, jamais réattribué ; le fonds
  -- verrouillé avant le contrôle « engagé »
  IF NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.exemplares'::regclass
                  AND t.tgname = 'exemplares_retire_jamais_supprime' AND NOT t.tgisinternal
                  AND (t.tgtype & 2) = 2 AND (t.tgtype & 8) = 8)
     OR NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid = 'public.exemplares'::regclass
                     AND t.tgname = 'exemplares_retire_reste_chez_soi' AND NOT t.tgisinternal
                     AND (t.tgtype & 2) = 2 AND (t.tgtype & 16) = 16)
     OR position('from public.book_holdings h where h.id = v_e.holding_id for update' IN pg_get_functiondef('ingest.fn_h21_publier_retrait(bigint, boolean)'::regprocedure)) = 0
     OR position('from public.book_holdings h where h.id = v_e.holding_id for update' IN pg_get_functiondef('ingest.fn_h21_publier_retrait(bigint, boolean)'::regprocedure))
        > position('ingest.fn_h21_retrait_engage(v_e.id)' IN pg_get_functiondef('ingest.fn_h21_publier_retrait(bigint, boolean)'::regprocedure)) THEN
    v_e := v_e || ' garde-retire';
  END IF;
  -- la publication : le retrait AVANT les portes de révision et la branche
  v_def := pg_get_functiondef('public.publish_exemplar_draft(bigint)'::regprocedure);
  IF position('return ingest.fn_h21_publier_retrait(p_draft_id, v_draft.status = ''published'');' IN v_def) = 0
     OR position('fn_h21_publier_retrait' IN v_def) > position('lote_importado_sem_revisao' IN v_def)
     OR position('fn_h21_publier_retrait' IN v_def) > position('if v_draft.published_exemplar_id is null then' IN v_def)
     OR position('fn_h21_publier_retrait' IN v_def) < position('error.publish.other_library' IN v_def) THEN
    v_e := v_e || ' publication';
  END IF;
  v_def := pg_get_functiondef('ingest.fn_h21_publier_retrait(bigint, boolean)'::regprocedure);
  FOREACH v_f IN ARRAY ARRAY['error.publish.item_retrait_already_published', 'error.publish.item_retrait_gone',
                             'error.publish.item_retrait_library_changed', 'error.publish.item_retrait_moved',
                             'error.publish.item_retrait_source_changed', 'error.publish.item_retrait_run_gone',
                             'error.publish.item_retrait_run_unstable', 'error.publish.item_retrait_already_retired',
                             'error.publish.item_retrait_already_lifted', 'error.publish.review_required',
                             'error.publish.added_after_review', 'error.publish.item_retrait_engaged',
                             'error.publish.item_retrait_back_in_file', 'error.publish.item_retrait_notice_absent',
                             'error.publish.item_levee_gone_from_file', 'error.publish.item_retrait_side_effect',
                             'error.publish.item_retrait_run_superseded', 'error.publish.item_retrait_in_newer_file'] LOOP
    IF position(v_f IN v_def) = 0 THEN v_e := v_e || ' garde(' || v_f || ')'; END IF;
  END LOOP;
  -- la trace : l'API ne la pose ni ne la change ; l'exclusivité ; le lot ; la fusion
  IF position('error.import.item_retrait_trace_reserved' IN pg_get_functiondef('public.tg_exemplar_drafts_import_links_locked()'::regprocedure)) = 0
     OR position('error.import.item_retrait_superseded' IN pg_get_functiondef('public.tg_exemplar_drafts_maj_import_exclusive()'::regprocedure)) = 0
     OR position('error.catalog.item_retrait_pending' IN pg_get_functiondef('public.tg_exemplar_drafts_maj_import_exclusive()'::regprocedure)) = 0
     OR position('import_retrait is not null' IN pg_get_functiondef('public.fn_batch_is_imported(bigint)'::regprocedure)) = 0
     OR position('import_retrait' IN pg_get_functiondef('ingest.fn_h21_lot_ouvert_du_run(bigint, uuid)'::regprocedure)) = 0
     OR position('x.import_retrait IS NOT NULL' IN pg_get_functiondef('api.merge_book_drafts(bigint, bigint, jsonb)'::regprocedure)) = 0 THEN
    v_e := v_e || ' trace';
  END IF;
  -- la circulation, l'export, le récolement, le rapport
  IF (SELECT count(*) FROM regexp_matches(pg_get_functiondef('public.fn_v2_recompute_holdings_availability(bigint[], bigint[])'::regprocedure), 'e\.retire_at is null', 'g')) <> 4
     OR (SELECT count(*) FROM regexp_matches(pg_get_functiondef('public.fn_v2_create_emprestimo_by_holdings(uuid, bigint[], date, text)'::regprocedure), 'e\.retire_at is null', 'g')) <> 2
     OR (SELECT count(*) FROM regexp_matches(pg_get_functiondef('public.fn_v2_convert_reserva_linhas_to_emprestimo(bigint, integer[], date, text)'::regprocedure), 'e\.retire_at is null', 'g')) <> 4
     OR position('retire_at' IN pg_get_functiondef('public.fn_v2_resolve_consulta_exemplar(bigint)'::regprocedure)) = 0
     OR position('retire_at' IN pg_get_functiondef('public.fn_v2_create_consulta_local_by_holdings(uuid, bigint[], timestamp with time zone, text)'::regprocedure)) = 0
     OR position('retire_at' IN pg_get_functiondef('public.fn_peb_search_exemplares(text, uuid)'::regprocedure)) = 0
     OR position('retire_at' IN pg_get_functiondef('public.fn_v2_create_reserva_by_holdings(uuid, bigint[], timestamp with time zone, text)'::regprocedure)) = 0
     OR position('retire_at' IN pg_get_functiondef('public.fn_v2_add_emprestimo_interbibliotecas_itens(bigint, bigint[], date, text)'::regprocedure)) = 0
     OR position('retire_at' IN pg_get_functiondef('public.fn_peb_create_loan_with_items(jsonb, jsonb)'::regprocedure)) = 0
     OR position('retire_at IS NULL' IN pg_get_functiondef('public.fn_export_catalog_lote(uuid, bigint, integer)'::regprocedure)) = 0
     OR position('retire_at' IN pg_get_functiondef('api.recolement_start(uuid)'::regprocedure)) = 0
     OR position('''retire''' IN pg_get_functiondef('api.recolement_scan(uuid, bigint)'::regprocedure)) = 0
     OR position('retired_count' IN pg_get_functiondef('api.recolement_finish(uuid)'::regprocedure)) = 0
     OR position('jsonb_build_object(''retraits'', v_retraits)' IN pg_get_functiondef('public.fn_batch_review_report(bigint)'::regprocedure)) = 0 THEN
    v_e := v_e || ' filtres';
  END IF;
  IF (SELECT count(*) FROM pg_policy p WHERE p.polrelid = 'public.exemplares'::regclass
        AND p.polname IN ('exemplares_public_read', 'exemplares_select_authenticated')
        AND position('retire_at IS NULL' IN pg_get_expr(p.polqual, p.polrelid)) > 0) <> 2 THEN
    v_e := v_e || ' rls';
  END IF;
  -- droits : portes ouvertes à authenticated (pas anon), DEFINER à search_path ;
  -- aides fermées ; portes modifiées inchangées
  FOREACH v_f IN ARRAY ARRAY[
    'public.fn_import_set_export_complet(bigint, boolean)', 'public.fn_import_confirmer_export_complet(bigint)',
    'public.fn_import_retraits(bigint, integer, integer)', 'public.fn_import_proposer_retraits(bigint)',
    'public.publish_exemplar_draft(bigint)', 'public.fn_batch_review_report(bigint)',
    'public.fn_export_catalog_lote(uuid, bigint, integer)'] LOOP
    IF NOT has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0)
       OR EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid = v_f::regprocedure
                   AND (NOT p.prosecdef OR coalesce(p.proconfig::text, '') NOT LIKE '%search_path%')) THEN
      v_e := v_e || ' droits-portes(' || v_f || ')';
    END IF;
  END LOOP;
  FOREACH v_f IN ARRAY ARRAY[
    'ingest.fn_h21_retrait_engage(bigint)', 'ingest.fn_h21_empreinte_hors_marqueur(bigint)',
    'ingest.fn_h21_retrait_dans_le_fichier(bigint, text, text)', 'ingest.fn_h21_acces_retraits(bigint)',
    'ingest.fn_h21_retraits_par_appel()', 'ingest.fn_h21_retraits_constat(bigint, boolean, boolean)',
    'ingest.fn_h21_retraits_bilan(bigint, boolean, integer, integer)',
    'ingest.fn_h21_publier_retrait(bigint, boolean)', 'public.tg_exemplares_marqueur_retrait()',
    'ingest.fn_h21_run_courant(bigint)', 'public.tg_exemplares_retire_garde()'] LOOP
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0) THEN
      v_e := v_e || ' droits-internes(' || v_f || ')';
    END IF;
  END LOOP;
  IF NOT has_function_privilege('authenticated', 'api.recolement_finish(uuid)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.fn_peb_create_loan_with_items(jsonb, jsonb)', 'EXECUTE') THEN
    v_e := v_e || ' droits-inchanges';
  END IF;

  IF v_e <> '' THEN
    RAISE EXCEPTION 'H21 lot 7 : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'H21 lot 7 : vérifications OK';
END
$h21l7_verif$;

NOTIFY pgrst, 'reload schema';
