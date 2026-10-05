-- =====================================================================
-- H31 — « Retraiter » juge le run au moment d'effacer (05/10/2026)
--
-- Constat (revue du lot 0 de H21, prouvé au banc le 01/10, sondes P5/SCEP1,
-- P5/SK1r, P5/SK2r, P5/SK2) : la garde de « Retraiter »
-- (public.fn_import_dispatch, force_reparse) se juge à l'ENVOI ; l'edge
-- function (process-partner-catalog-import, receive-fonds-bundle) efface les
-- lignes du run quelques secondes plus tard sans rien relire. Dans cette
-- fenêtre (second onglet, API) :
--   * une promotion donne, après relecture, deux notices pour une ligne
--     (antérieur, H15) ;
--   * un rapprochement fait refuser l'effacement par le déclencheur
--     trg_staging_rows_retenue_par_rapproche (lot 0) ;
--   * un paquet de fonds retraité efface la trace d'attache de ses fichiers
--     reçus (receive-fonds-bundle les recrée « deposited »), et un même
--     fichier s'attache deux fois — que la garde de l'envoi ne regardait pas.
--
-- Correctif :
--   1. ingest.fn_h31_retraitement_refuse(run) : LA garde de « Retraiter »,
--      une seule définition, lue par l'envoi et par l'effacement — liens
--      ligne → brouillon (H15), exemplaires rapprochés non annulés ou à la
--      corbeille sans notice (H19, H21 lot 0), lignes écartées (IMP-27 e),
--      et, nouveau, fichier reçu déjà attaché (attached_digital_asset_id
--      posé par le mode « export »/« both », OU deposit_status = 'attached',
--      seul témoin du mode « read » de fn_attach_received_asset_record, qui
--      laisse attached_digital_asset_id NULL).
--   2. ingest.fn_h31_effacer_lignes_pour_retraitement(run, fichiers reçus) :
--      l'effacement des deux edge functions (service_role seul). Verrouille
--      le run (FOR UPDATE), REJOUE la garde, puis efface les lignes et, pour
--      un paquet de fonds, ses fichiers reçus — d'un seul tenant (avant, deux
--      DELETE séparés : le second en échec laissait les fichiers reçus sans
--      leurs lignes, doublés au retraitement suivant).
--   3. public.fn_import_dispatch : la garde devient l'appel à (1) — le refus
--      d'un fichier reçu attaché vient donc aussi tout de suite, à l'écran.
--   4. public.fn_import_promote, fn_import_reconcile_duplicates,
--      fn_import_set_editorial : le run verrouillé après les contrôles
--      d'accès, AVANT de lire les lignes. Une conversion attend un effacement
--      en cours et voit ensuite les lignes sorties du run (ignorées, lot 0) ;
--      un effacement attend la conversion en cours, puis rejuge la garde (qui
--      voit le lien ou l'exemplaire créé).
--      FOR NO KEY UPDATE, et non FOR SHARE : chacune de ces conversions finit
--      par écrire le run (ingest.fn_refresh_partner_catalog_run_counters) ;
--      deux conversions du même run tenant chacune un FOR SHARE
--      s'interbloquaient en voulant l'écrire (40P01, prouvé au banc le 05/10,
--      deux sessions). NO KEY UPDATE les met en file l'une derrière l'autre
--      (ce que l'écriture du run faisait déjà à la fin), reste compatible avec
--      les FOR KEY SHARE des clés étrangères, et attend comme FOR SHARE un
--      effacement en cours (FOR UPDATE).
--   5. public.fn_attach_received_asset_record : le run verrouillé (FOR
--      SHARE : l'attache n'écrit pas le run) après ses gardes d'accès, puis le
--      fichier reçu RELU sous verrou de ligne — effacé par un retraitement
--      entre-temps : refus « introuvable » ; attaché par un autre onglet :
--      réponse idempotente. Un effacement qui suit attend l'attache, puis
--      voit le fichier attaché et refuse.
--   6. public.fn_import_delete_run : le run verrouillé (FOR UPDATE) et relu
--      après ses contrôles d'accès, AVANT ses gardes (lot qui retient des
--      brouillons, brouillons liés hors lot, rapprochés à la corbeille ou en
--      attente). Prouvé au banc le 05/10 (revue sceptique, deux sessions) : une
--      promotion en cours passait sous ces gardes (ses liens non commités
--      étaient invisibles), puis la suppression attendait et effaçait le run et
--      les liens neufs en cascade — trois brouillons vivants sans preuve
--      d'import (IMP-27 a contournée). Désormais la suppression attend la
--      conversion, puis juge ses gardes sur ce qu'elle a commité ; et une
--      conversion qui attendait une suppression refuse « introuvable » (les
--      trois conversions vérifient que le run est encore là).
--
-- Méthode : substitutions comptées sur les définitions vivantes (relues en
-- production le 05/10 : md5 identiques à celles du rejeu des migrations).
-- =====================================================================

CREATE FUNCTION pg_temp.h31_remplacer(p_quoi text, p_def text, p_old text, p_new text)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'H31 — % : ancre trouvée % fois (attendu 1) — relire la définition réelle', p_quoi, v_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

-- ── 1. La garde de « Retraiter », une seule définition ──────────────────
CREATE OR REPLACE FUNCTION ingest.fn_h31_retraitement_refuse(p_run_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
  -- H15 (26/09/2026) : retraiter efface les lignes de staging, et le lien
  -- ligne → brouillon les suit (ON DELETE CASCADE). Un run déjà promu ne se
  -- relit donc plus : on importe à nouveau le fichier.
  SELECT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft l WHERE l.run_id = p_run_id)
         -- H19 (27/09/2026) : un rapprochement aussi a produit des brouillons
         -- (d'exemplaires) ; effacer les lignes les détacherait de leur import.
         -- H21 lot 0 : un exemplaire rapproché (sans notice) retient sa ligne
         -- jusqu'à sa publication, corbeille comprise.
      OR EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows sr
                   JOIN public.exemplar_drafts x ON x.import_staging_row_id = sr.id
                  WHERE sr.run_id = p_run_id
                    AND (x.status <> 'cancelled' OR x.book_draft_id IS NULL))
         -- IMP-27 (e) : une ligne écartée garde la preuve que lit le rejeu.
      OR EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows e
                  WHERE e.run_id = p_run_id AND e.discarded_draft_id IS NOT NULL)
         -- H31 (05/10/2026) : un fichier reçu déjà attaché à une notice —
         -- l'effacer le remettrait en file d'attache, et il s'attacherait deux
         -- fois. « Attaché » se lit comme fn_attach_received_asset_record le
         -- lit : un digital_asset (export, both) OU le statut (read seul).
      OR EXISTS (SELECT 1 FROM ingest.partner_catalog_received_assets ra
                  WHERE ra.run_id = p_run_id
                    AND (ra.attached_digital_asset_id IS NOT NULL OR ra.deposit_status = 'attached'))
$function$;

COMMENT ON FUNCTION ingest.fn_h31_retraitement_refuse(bigint) IS
  'H31 (05/10/2026). Garde de « Retraiter » : vrai si le run a une ligne promue (lien ligne → brouillon), un exemplaire rapproché non annulé ou à la corbeille sans notice, une ligne écartée (IMP-27 e) ou un fichier reçu attaché. Lue par public.fn_import_dispatch (à l''envoi) et par ingest.fn_h31_effacer_lignes_pour_retraitement (au moment d''effacer, sous verrou). INTERNE : aucun droit d''exécution hors propriétaire.';

REVOKE ALL ON FUNCTION ingest.fn_h31_retraitement_refuse(bigint) FROM PUBLIC, anon, authenticated, service_role;

-- ── 2. L'effacement des edge functions, jugé sous verrou ─────────────────
CREATE OR REPLACE FUNCTION ingest.fn_h31_effacer_lignes_pour_retraitement(p_run_id bigint, p_fichiers_recus boolean)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
DECLARE
  v_lignes integer := 0;
BEGIN
  -- Le run verrouillé d'abord : une promotion, un rapprochement ou une
  -- décision en cours sur ce run (qui le verrouillent aussi, FOR NO KEY
  -- UPDATE) finissent avant ; ceux qui arrivent après attendent ce COMMIT et
  -- trouvent les lignes sorties du run.
  PERFORM 1 FROM ingest.partner_catalog_import_runs r WHERE r.id = p_run_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  -- La garde de fn_import_dispatch, REJOUÉE maintenant : ce qui s'est
  -- converti, rapproché, écarté ou attaché depuis l'envoi compte.
  IF ingest.fn_h31_retraitement_refuse(p_run_id) THEN
    RAISE EXCEPTION 'Import % ja promovido em rascunhos : nao pode ser reprocessado.', p_run_id
      USING HINT = 'error.import.reparse_after_promotion';
  END IF;

  DELETE FROM ingest.partner_catalog_staging_rows WHERE run_id = p_run_id;
  GET DIAGNOSTICS v_lignes = ROW_COUNT;

  -- Un paquet de fonds (receive-fonds-bundle) : ses fichiers reçus partent
  -- avec ses lignes, dans la même transaction — jamais l'un sans l'autre.
  IF coalesce(p_fichiers_recus, false) THEN
    DELETE FROM ingest.partner_catalog_received_assets WHERE run_id = p_run_id;
  END IF;

  RETURN v_lignes;
END
$function$;

COMMENT ON FUNCTION ingest.fn_h31_effacer_lignes_pour_retraitement(bigint, boolean) IS
  'H31 (05/10/2026). Effacement des lignes d''un run avant « Retraiter » (edge functions process-partner-catalog-import et receive-fonds-bundle) : verrouille le run (FOR UPDATE), rejoue la garde ingest.fn_h31_retraitement_refuse (refus HINT error.import.reparse_after_promotion, rien n''est effacé), puis efface les lignes et, si p_fichiers_recus, les fichiers reçus du run. Rend le nombre de lignes effacées. service_role seul.';

REVOKE ALL ON FUNCTION ingest.fn_h31_effacer_lignes_pour_retraitement(bigint, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_h31_effacer_lignes_pour_retraitement(bigint, boolean) TO service_role;

-- ── 3. fn_import_dispatch : la garde devient l'appel ─────────────────────
DO $h31_dispatch$
DECLARE
  v_def text;
  v_debut text := $a$  IF coalesce(p_force_reparse, false)
     AND (EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft l WHERE l.run_id = p_run_id)$a$;
  v_fin text := $a$                      WHERE e.run_id = p_run_id AND e.discarded_draft_id IS NOT NULL)) THEN$a$;
  v_i int; v_j int;
BEGIN
  v_def := pg_get_functiondef('public.fn_import_dispatch(bigint, boolean)'::regprocedure);
  -- les deux bornes, chacune une fois, dans l'ordre
  PERFORM pg_temp.h31_remplacer('fn_import_dispatch (début de la garde)', v_def, v_debut, v_debut);
  PERFORM pg_temp.h31_remplacer('fn_import_dispatch (fin de la garde)', v_def, v_fin, v_fin);
  v_i := position(v_debut IN v_def);
  v_j := position(v_fin IN v_def) + length(v_fin);
  IF v_j <= v_i THEN
    RAISE EXCEPTION 'H31 — fn_import_dispatch : bornes de la garde dans le désordre';
  END IF;
  v_def := substr(v_def, 1, v_i - 1)
        || $b$  IF coalesce(p_force_reparse, false)
     -- H31 (05/10/2026) : la garde vit dans ingest.fn_h31_retraitement_refuse,
     -- que l'effacement (ingest.fn_h31_effacer_lignes_pour_retraitement)
     -- rejoue sous verrou au moment d'effacer : liens ligne → brouillon (H15),
     -- exemplaires rapprochés (H19, H21 lot 0), lignes écartées (IMP-27 e),
     -- fichiers reçus attachés (H31).
     AND ingest.fn_h31_retraitement_refuse(p_run_id) THEN$b$
        || substr(v_def, v_j);
  EXECUTE v_def;
END
$h31_dispatch$;

-- ── 4. Les trois conversions prennent le verrou du run ──────────────────
DO $h31_promote$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_import_promote(bigint, text[], text[], text, text, bigint[])'::regprocedure);
  v_def := pg_temp.h31_remplacer('fn_import_promote (verrou)', v_def,
$a$      USING HINT = 'error.import.deposit_admin_only';
  END IF;
$a$,
$b$      USING HINT = 'error.import.deposit_admin_only';
  END IF;

  -- H31 (05/10/2026) : le run verrouillé AVANT de lire ses lignes (après les
  -- contrôles d'accès). Un « Retraiter » en cours
  -- (ingest.fn_h31_effacer_lignes_pour_retraitement, FOR UPDATE) est attendu,
  -- et ses lignes effacées ne se promeuvent pas ; un effacement qui arrive
  -- après attend cette promotion, puis voit ses liens et refuse. NO KEY
  -- UPDATE et non SHARE : la promotion écrit le run en finissant (compteurs) ;
  -- deux conversions sous FOR SHARE s'interbloquaient.
  PERFORM 1 FROM ingest.partner_catalog_import_runs WHERE id = p_run_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN   -- supprimé pendant l'attente (fn_import_delete_run)
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;
$b$);
  EXECUTE v_def;
END
$h31_promote$;

DO $h31_reconcile$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_import_reconcile_duplicates(bigint, bigint[])'::regprocedure);
  v_def := pg_temp.h31_remplacer('fn_import_reconcile_duplicates (verrou)', v_def,
$a$  if v_run_library_id is distinct from v_actor.library_id then
    raise exception 'Run % introuvable', p_run_id;
  end if;
$a$,
$b$  if v_run_library_id is distinct from v_actor.library_id then
    raise exception 'Run % introuvable', p_run_id;
  end if;

  -- H31 (05/10/2026) : le run verrouillé AVANT de lire ses lignes (après les
  -- contrôles d'accès). Un « Retraiter » en cours
  -- (ingest.fn_h31_effacer_lignes_pour_retraitement, FOR UPDATE) est attendu,
  -- et ses lignes effacées comptent comme sorties du run (skipped_rows) ; un
  -- effacement qui arrive après attend ce rapprochement, puis voit ses
  -- exemplaires et refuse. NO KEY UPDATE et non SHARE : le rapprochement écrit
  -- le run en finissant (compteurs) ; deux conversions sous FOR SHARE
  -- s'interbloquaient.
  perform 1 from ingest.partner_catalog_import_runs where id = p_run_id for no key update;
  if not found then   -- supprimé pendant l'attente (fn_import_delete_run)
    raise exception 'Run % introuvable', p_run_id;
  end if;
$b$);
  EXECUTE v_def;
END
$h31_reconcile$;

DO $h31_set_editorial$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_import_set_editorial(bigint, bigint[], text, text)'::regprocedure);
  v_def := pg_temp.h31_remplacer('fn_import_set_editorial (verrou)', v_def,
$a$      USING HINT = 'error.import.rattacher_par_rapprocher';
  END IF;
$a$,
$b$      USING HINT = 'error.import.rattacher_par_rapprocher';
  END IF;

  -- H31 (05/10/2026) : le run verrouillé AVANT de lire ses lignes (après les
  -- contrôles d'accès). Un « Retraiter » en cours
  -- (ingest.fn_h31_effacer_lignes_pour_retraitement, FOR UPDATE) est attendu,
  -- et ses lignes effacées comptent comme sorties du run (skipped_rows) ; un
  -- effacement qui arrive après attend cette décision. NO KEY UPDATE et non
  -- SHARE : la décision écrit le run en finissant (compteurs) ; deux
  -- conversions sous FOR SHARE s'interbloquaient.
  PERFORM 1 FROM ingest.partner_catalog_import_runs WHERE id = p_run_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN   -- supprimé pendant l'attente (fn_import_delete_run)
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;
$b$);
  EXECUTE v_def;
END
$h31_set_editorial$;

-- ── 5. L'attache d'un fichier reçu prend aussi le verrou du run ─────────
-- Prouvé au banc le 05/10 (deux sessions) : une attache en cours pendant un
-- « Retraiter » passait sous la garde (non commitée, invisible), puis
-- l'effacement supprimait le fichier reçu tout juste attaché — un
-- digital_asset sans trace d'attache, et le même fichier de nouveau offert.
-- FOR SHARE suffit : l'attache n'écrit pas le run (ni elle, ni les
-- déclencheurs de digital_assets, book_digital_resources et
-- partner_catalog_received_assets). Le fichier reçu est RELU sous verrou de
-- ligne (FOR UPDATE) : effacé entre-temps par un retraitement, refus
-- « introuvable » (le même que pour un fichier inconnu) ; attaché entre-temps
-- par un autre onglet, la réponse idempotente d'avant — plus de double
-- attache du même fichier.
DO $h31_attache$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_attach_received_asset_record(bigint, bigint, text, text, text)'::regprocedure);
  v_def := pg_temp.h31_remplacer('fn_attach_received_asset_record (verrou)', v_def,
$a$  IF NOT v_authorized THEN RAISE EXCEPTION 'Recurso recebido introuvável.'; END IF;
$a$,
$b$  IF NOT v_authorized THEN RAISE EXCEPTION 'Recurso recebido introuvável.'; END IF;

  -- H31 (05/10/2026) : le run verrouillé (après les gardes d'accès), puis le
  -- fichier reçu relu sous verrou de ligne. Un « Retraiter » en cours
  -- (ingest.fn_h31_effacer_lignes_pour_retraitement, FOR UPDATE) est attendu :
  -- s'il a effacé ce fichier, refus « introuvable » ; un effacement qui arrive
  -- après attend cette attache, puis voit le fichier attaché et refuse.
  PERFORM 1 FROM ingest.partner_catalog_import_runs run WHERE run.id = ra.run_id FOR SHARE;
  SELECT * INTO ra FROM ingest.partner_catalog_received_assets WHERE id = p_received_asset_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Recurso recebido introuvável.' USING HINT = 'error.edge.received_asset_not_found'; END IF;
  IF ra.attached_digital_asset_id IS NOT NULL OR ra.deposit_status = 'attached' THEN
    RETURN jsonb_build_object('ok', true, 'asset_id', ra.attached_digital_asset_id, 'created', false, 'book_id', p_book_id);
  END IF;
$b$);
  EXECUTE v_def;
END
$h31_attache$;

-- ── 6. La suppression d'un run juge ses gardes sous verrou ──────────────
DO $h31_suppression$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_import_delete_run(bigint)'::regprocedure);
  v_def := pg_temp.h31_remplacer('fn_import_delete_run (verrou)', v_def,
$a$  IF v_run.library_id IS DISTINCT FROM v_actor.library_id
     AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;
$a$,
$b$  IF v_run.library_id IS DISTINCT FROM v_actor.library_id
     AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  -- H31 (05/10/2026) : le run verrouillé (FOR UPDATE) et RELU après les
  -- contrôles d'accès, AVANT les gardes : une promotion, un rapprochement,
  -- une décision ou une attache en cours sur ce run (qui le verrouillent
  -- aussi) finissent d'abord, et les gardes voient leurs liens et leurs
  -- brouillons ; ceux qui arrivent après attendent cette suppression, puis
  -- refusent « introuvable ».
  SELECT * INTO v_run FROM ingest.partner_catalog_import_runs WHERE id = p_run_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;
$b$);
  EXECUTE v_def;
END
$h31_suppression$;

-- ── Vérification structurelle ────────────────────────────────────────────
DO $h31_verif$
DECLARE
  v_disp text := pg_get_functiondef('public.fn_import_dispatch(bigint, boolean)'::regprocedure);
  v_garde text := pg_get_functiondef('ingest.fn_h31_retraitement_refuse(bigint)'::regprocedure);
  v_eff text := pg_get_functiondef('ingest.fn_h31_effacer_lignes_pour_retraitement(bigint, boolean)'::regprocedure);
  v_conv text;
  v_sig text;
BEGIN
  -- l'envoi : la garde appelée, ses autres refus en place, plus de copie locale
  IF position('ingest.fn_h31_retraitement_refuse(p_run_id)' IN v_disp) = 0
     OR position('error.import.reparse_after_promotion' IN v_disp) = 0
     OR position('error.import.reparse_no_file' IN v_disp) = 0
     OR position('error.import.profile_missing' IN v_disp) = 0
     OR position('partner_catalog_row_to_draft' IN v_disp) > 0
     OR NOT has_function_privilege('authenticated', 'public.fn_import_dispatch(bigint, boolean)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_import_dispatch(bigint, boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'H31 : vérification de fn_import_dispatch en échec';
  END IF;
  -- la garde : ses quatre conditions, aucun droit hors propriétaire
  IF position('partner_catalog_row_to_draft' IN v_garde) = 0
     OR position($q$x.status <> 'cancelled' OR x.book_draft_id IS NULL$q$ IN v_garde) = 0
     OR position('e.discarded_draft_id IS NOT NULL' IN v_garde) = 0
     OR position($q$ra.attached_digital_asset_id IS NOT NULL OR ra.deposit_status = 'attached'$q$ IN v_garde) = 0
     OR has_function_privilege('anon', 'ingest.fn_h31_retraitement_refuse(bigint)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'ingest.fn_h31_retraitement_refuse(bigint)', 'EXECUTE')
     OR has_function_privilege('service_role', 'ingest.fn_h31_retraitement_refuse(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'H31 : vérification de la garde en échec';
  END IF;
  -- l'effacement : DEFINER, verrou PUIS garde PUIS DELETE, service_role seul
  IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = 'ingest.fn_h31_effacer_lignes_pour_retraitement(bigint, boolean)'::regprocedure)
     OR position('FOR UPDATE' IN v_eff) = 0
     OR position('FOR UPDATE' IN v_eff) > position('ingest.fn_h31_retraitement_refuse(p_run_id)' IN v_eff)
     OR position('ingest.fn_h31_retraitement_refuse(p_run_id)' IN v_eff) > position('DELETE FROM ingest.partner_catalog_staging_rows' IN v_eff)
     OR position('error.import.reparse_after_promotion' IN v_eff) = 0
     OR has_function_privilege('anon', 'ingest.fn_h31_effacer_lignes_pour_retraitement(bigint, boolean)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'ingest.fn_h31_effacer_lignes_pour_retraitement(bigint, boolean)', 'EXECUTE')
     OR NOT has_function_privilege('service_role', 'ingest.fn_h31_effacer_lignes_pour_retraitement(bigint, boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'H31 : vérification de l''effacement en échec';
  END IF;
  -- les conversions : le verrou après « Run % introuvable », droits inchangés
  FOREACH v_sig IN ARRAY ARRAY['public.fn_import_promote(bigint, text[], text[], text, text, bigint[])',
                               'public.fn_import_reconcile_duplicates(bigint, bigint[])',
                               'public.fn_import_set_editorial(bigint, bigint[], text, text)'] LOOP
    v_conv := lower(pg_get_functiondef(v_sig::regprocedure));
    IF position('from ingest.partner_catalog_import_runs where id = p_run_id for no key update' IN v_conv) = 0
       OR position('from ingest.partner_catalog_import_runs where id = p_run_id for no key update' IN v_conv)
          < position('run % introuvable' IN v_conv)
       OR NOT has_function_privilege('authenticated', v_sig, 'EXECUTE')
       OR has_function_privilege('anon', v_sig, 'EXECUTE') THEN
      RAISE EXCEPTION 'H31 : vérification du verrou de % en échec', v_sig;
    END IF;
  END LOOP;
  -- l'attache : verrou du run APRÈS ses gardes d'accès, puis relecture sous
  -- verrou de ligne, AVANT toute écriture ; droits inchangés
  v_conv := pg_get_functiondef('public.fn_attach_received_asset_record(bigint, bigint, text, text, text)'::regprocedure);
  IF position('WHERE run.id = ra.run_id FOR SHARE' IN v_conv) = 0
     OR position('WHERE run.id = ra.run_id FOR SHARE' IN v_conv) < position('IF NOT v_authorized THEN' IN v_conv)
     OR position('WHERE id = p_received_asset_id FOR UPDATE' IN v_conv) < position('WHERE run.id = ra.run_id FOR SHARE' IN v_conv)
     OR position('INSERT INTO public.digital_assets' IN v_conv) < position('WHERE id = p_received_asset_id FOR UPDATE' IN v_conv)
     OR NOT has_function_privilege('authenticated', 'public.fn_attach_received_asset_record(bigint, bigint, text, text, text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_attach_received_asset_record(bigint, bigint, text, text, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'H31 : vérification du verrou de fn_attach_received_asset_record en échec';
  END IF;
  -- la suppression : verrou après les contrôles d'accès, avant les gardes et
  -- le DELETE ; les conversions refusent un run disparu pendant l'attente
  v_conv := pg_get_functiondef('public.fn_import_delete_run(bigint)'::regprocedure);
  IF position('WHERE id = p_run_id FOR UPDATE' IN v_conv) = 0
     OR position('WHERE id = p_run_id FOR UPDATE' IN v_conv) < position('AND NOT public.fn_caller_is_network_admin() THEN' IN v_conv)
     OR position('SELECT array_agg(DISTINCT m.batch_id)' IN v_conv) < position('WHERE id = p_run_id FOR UPDATE' IN v_conv)
     OR position('DELETE FROM ingest.partner_catalog_import_runs' IN v_conv) < position('WHERE id = p_run_id FOR UPDATE' IN v_conv)
     OR NOT has_function_privilege('authenticated', 'public.fn_import_delete_run(bigint)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_import_delete_run(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'H31 : vérification du verrou de fn_import_delete_run en échec';
  END IF;
  FOREACH v_sig IN ARRAY ARRAY['public.fn_import_promote(bigint, text[], text[], text, text, bigint[])',
                               'public.fn_import_reconcile_duplicates(bigint, bigint[])',
                               'public.fn_import_set_editorial(bigint, bigint[], text, text)'] LOOP
    IF lower(pg_get_functiondef(v_sig::regprocedure)) !~ 'for no key update;\s*if not found then\s*-- supprim' THEN
      RAISE EXCEPTION 'H31 : % ne vérifie pas que le run est encore là après son verrou', v_sig;
    END IF;
  END LOOP;
  RAISE NOTICE 'H31 : vérifications OK';
END
$h31_verif$;

NOTIFY pgrst, 'reload schema';
