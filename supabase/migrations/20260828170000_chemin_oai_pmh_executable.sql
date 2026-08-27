-- =========================================================================
-- Paquet chemin-oai-pmh-executable — le moissonnage OAI-PMH cesse d'être
-- un écran qui ne peut rien produire
-- =========================================================================
-- Date     : 2026-08-28
-- Chantier : importations — moisson OAI-PMH (mode « oai »)
-- Voisins  : 20260828100000_source_depot_sans_partenaire.sql
--            20260828140000_candidat_institutionnel_ingerable.sql
--            Ce paquet-ci est celui que l'en-tête du second ANNONCE comme
--            restant à faire ; lire ce passage, il porte le raisonnement.
--
-- POURQUOI
--   Quatrième et cinquième occurrences du même motif : une fonction dont
--   personne n'a jamais emprunté le chemin, et dont les écarts entre ce
--   qu'elle écrit et ce que les colonnes acceptent ne se voient qu'à
--   l'exécution. Les deux RPC du circuit OAI-PMH sont concernées.
--
--   1. public.fn_import_register_oai_source — un seul écart dans le corps :
--      relation_status portait un mot hors de
--      partner_catalog_sources_relation_status_check.            -> 23514
--      C'est EXACTEMENT la faute réparée le 28/08 dans
--      fn_import_register_deposit_source, même table, même colonne.
--      (source_kind = oai_pmh était le second écart ; il est réparé ici du
--      côté de la CHECK, pas de la fonction — voir plus bas.)
--
--   2. public.fn_import_harvest_oai — trois écarts, deux CHECK et un NOT NULL :
--      detected_format = oai_pmh hors vocabulaire                 -> 23514
--      run_status portait un mot hors vocabulaire                 -> 23514
--      storage_path (NOT NULL SANS défaut) n'était pas fourni     -> 23502
--
--   VÉRIFIÉ EN BASE le 28/08/2026 (staging uflwmikiyjfnikiphtcp), pas supposé.
--   La preuve que ces fonctions n'ont JAMAIS abouti tient en trois comptages :
--     ingest.partner_catalog_sources     where source_kind='oai_pmh'      -> 0
--     ingest.partner_catalog_import_runs where detected_format='oai_pmh'  -> 0
--     ingest.oai_harvest_state                                            -> 0
--   Le troisième est le plus parlant : register_oai_source crée la source PUIS
--   son état de moissonnage. La table d'état est vide parce que l'INSERT qui
--   la précède n'est jamais passé. Aucune migration postérieure au baseline ne
--   redéfinit ces deux fonctions : le corps en base est bien celui du baseline
--   (confronté par pg_get_functiondef le 28/08).
--
--   Corollaire du corollaire : la branche « la source existe déjà, je la mets
--   à jour » de register_oai_source n'a elle non plus jamais tourné — aucune
--   ligne ne pouvant porter oai_pmh, le SELECT ne trouvait jamais rien. Comme
--   pour le candidat institutionnel, la branche de repli EST la branche.
--
-- LA DÉCISION DE VOCABULAIRE : ÉLARGIR, POUR LA MÊME RAISON QUE LE 28/08
--   Deux CHECK sont élargies à oai_pmh. Le raisonnement est celui retenu pour
--   institutional_lookup : ces colonnes disent la PROVENANCE. Une notice
--   moissonnée sur un entrepôt OAI-PMH n'a été téléversée par personne
--   (manual_upload mentirait) et ne vient d'aucune bibliothèque compagne ayant
--   accordé quoi que ce soit (partner_deposit mentirait, et afficherait un
--   badge de relation que personne n'a négocié). C'est une quatrième
--   provenance, avec son propre écran, sa propre RPC de liste
--   (fn_import_list_oai_sources filtre déjà sur source_kind = 'oai_pmh') et sa
--   propre table d'état. Le mot existait partout SAUF dans les contraintes.
--
--   detected_format : on n'écrit pas marcxml, bien que ce soit le préfixe par
--   défaut. À la naissance du run, le format réel n'est pas connu — le préfixe
--   demandé est auto-négocié par l'EF (c'est écrit dans le commentaire de la
--   colonne oai_metadata_prefix). Écrire marcxml serait affirmer le résultat
--   d'une négociation qui n'a pas eu lieu.
--
--   Élargir n'est anodin que si personne n'aiguille dessus. Vérifié dans
--   src/pages/importacoes/ImportacoesPage.jsx : le front n'aiguille ni sur
--   source_kind (il ne fait que FILTRER, cf. plus bas) ni sur detected_format
--   (affiché tel quel dans une pastille). Aucune vue, aucune fonction, aucune
--   EF ne branche sur ces deux mots.
--
-- LE run_status D'UN RUN QUI VIENT DE NAÎTRE : queued, PAS processing
--   Le corps de fn_import_harvest_oai porte encore un TODO « Lot 3b : appel
--   pg_net vers l'EF harvest-oai-pmh ». Vérifié : cette EF N'EXISTE PAS dans
--   supabase/functions/ (oai-pmh-provider va dans le sens inverse — c'est
--   AnarBib qui EXPOSE son catalogue en OAI-PMH). Il n'y a donc aucune attente
--   d'EF à satisfaire : le choix se tranche sur le sens que le vocabulaire se
--   donne à lui-même, dans api.partner_catalog_import_run_policy_ui :
--     queued     -> dispatch_pending, « à lancer ou relancer explicitement »
--     processing -> « traitement en cours », wait_or_refresh
--   Rien ne traite ce run. queued le dit ; processing l'inventerait. Et quand
--   le Lot 3b arrivera, l'EF fera monter le run par les barreaux normaux
--   (queued -> processing -> parsed -> ready_for_review), sans en sauter un.
--
--   Contrepartie assumée de queued : la vue expose can_dispatch = true sur ce
--   run. Sans effet ici — fn_import_dispatch n'est appelé que juste après un
--   fn_import_create, jamais sur un run existant (même constat qu'au 28/08).
--
-- CE QUE CE PAQUET NE FAIT PAS, ET QU'IL FAUT SAVOIR
--   fn_import_harvest_oai pose oai_harvest_state.harvest_status = in_progress
--   comme un VERROU (elle refuse un second moissonnage tant qu'il tient, et le
--   bouton du front se désactive). Ce verrou est relâché par l'EF du Lot 3b…
--   qui n'existe pas. Conséquence : après ce paquet, le moissonnage
--   s'exécutera UNE FOIS par source, puis sera refusé. C'est un progrès réel
--   (il ne s'exécutait pas du tout, et la fonction le DIT dans sa réponse :
--   le champ « note » annonce l'absence d'EF, et le front l'affiche) mais ce
--   n'est pas un circuit bout en bout. Relâcher le verrou automatiquement
--   serait un arbitrage produit — pas une réparation — et il appartient au
--   Lot 3b avec l'EF. La suite de tests le GARDE explicitement plutôt que de
--   le laisser se découvrir en production.
--
-- CHECKLIST DOCTRINE
--   [x] Les DEUX corps EXTRAITS du baseline et modifiés par ancrages vérifiés
--       (2 remplacements, 1 occurrence exacte chacun) — jamais retapés
--   [x] Fonctions SECURITY DEFINER : search_path conservé (public, ingest, auth)
--   [x] REVOKE EXECUTE FROM PUBLIC + GRANT aux rôles du baseline rejoués
--   [x] Deux CHECK élargies ; aucune ligne existante invalidée (l'ancien
--       vocabulaire est un sous-ensemble strict du nouveau) — et 0 ligne à
--       migrer, les comptages ci-dessus le prouvent
--   [x] Aucune table, vue ou policy créée ; RLS inchangée
--   [x] DO block de vérification STRUCTUREL (les migrations tournent AVANT le
--       seed en CI) ; le bout-en-bout fonctionnel vit dans
--       tests/sql/import_oai_pmh_tests.sql
-- =========================================================================

begin;

-- ── 1. Les deux vocabulaires s'ouvrent au mot que le code écrit ──────────
alter table ingest.partner_catalog_sources
  drop constraint if exists partner_catalog_sources_source_kind_check;
alter table ingest.partner_catalog_sources
  add constraint partner_catalog_sources_source_kind_check
  check (source_kind = any (array[
    'manual_upload',
    'zotero_file_export',
    'zotero_api',
    'partner_deposit',
    'institutional_lookup',
    -- Entrepôt interrogé en OAI-PMH par fn_import_register_oai_source. Ni
    -- téléversement, ni dépôt d'une compagne : sa propre provenance, avec sa
    -- propre table d'état (ingest.oai_harvest_state) et son propre écran.
    'oai_pmh'
  ]));

alter table ingest.partner_catalog_import_runs
  drop constraint if exists partner_catalog_import_runs_detected_format_check;
alter table ingest.partner_catalog_import_runs
  add constraint partner_catalog_import_runs_detected_format_check
  check (detected_format = any (array[
    'csv', 'tsv', 'xlsx', 'xls', 'ods', 'json', 'csl_json', 'ris',
    'bibtex', 'biblatex', 'mods', 'marcxml', 'xml', 'pdf', 'zip',
    'lookup',
    -- Run né d'un moissonnage : aucun fichier reçu, et le format des notices
    -- n'est pas encore connu (le préfixe demandé est auto-négocié par l'EF).
    -- Écrire marcxml affirmerait le résultat d'une négociation non tenue.
    'oai_pmh',
    'unknown'
  ]));

comment on constraint partner_catalog_sources_source_kind_check
  on ingest.partner_catalog_sources is
  'Vocabulaire de provenance des sources. Elargi le 28/08/2026 a '
  '''institutional_lookup'' (paquet candidat-institutionnel-ingerable) puis a '
  '''oai_pmh'' (paquet chemin-oai-pmh-executable, le meme jour) : les deux mots '
  'etaient ecrits par des fonctions qui ne pouvaient donc pas s''executer. '
  'Regle : ces colonnes disent la PROVENANCE — n''y ranger un mot deja admis '
  'que si la provenance est reellement la meme.';

comment on constraint partner_catalog_import_runs_detected_format_check
  on ingest.partner_catalog_import_runs is
  'Formats de fichier, plus deux provenances SANS fichier : ''lookup'' (run '
  'alimente ligne a ligne par fn_import_ingest_candidate) et ''oai_pmh'' (run '
  'ne d''un moissonnage, dont le format reel n''est pas connu a sa naissance). '
  'Elargie le 28/08/2026.';

-- ── 2. Les deux fonctions ────────────────────────────────────────────────
-- Corps EXTRAITS du baseline (20260510000000_baseline_live.sql) et modifiés
-- par ancrages, jamais retapés.
CREATE OR REPLACE FUNCTION "public"."fn_import_register_oai_source"("p_partner_name" "text", "p_oai_endpoint_url" "text", "p_library_id" "uuid", "p_oai_metadata_prefix" "text" DEFAULT 'marcxml'::"text", "p_oai_set" "text" DEFAULT NULL::"text", "p_lots_per_cycle" integer DEFAULT 5, "p_notes" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'ingest', 'auth'
    AS $$
DECLARE
  v_source_id  bigint;
  v_state_id   bigint;
BEGIN
  -- Admin réseau obligatoire
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito a administradores de rede.';
  END IF;

  -- Validation
  IF p_oai_endpoint_url IS NULL OR trim(p_oai_endpoint_url) = '' THEN
    RAISE EXCEPTION 'oai_endpoint_url obrigatorio.';
  END IF;

  IF p_library_id IS NULL THEN
    RAISE EXCEPTION 'library_id obrigatorio.';
  END IF;

  -- Cherche une source OAI existante avec le même endpoint pour la même biblio
  SELECT id INTO v_source_id
    FROM ingest.partner_catalog_sources
   WHERE library_id       = p_library_id
     AND source_kind      = 'oai_pmh'
     AND oai_endpoint_url = trim(p_oai_endpoint_url)
   LIMIT 1;

  IF v_source_id IS NOT NULL THEN
    -- Met à jour les paramètres si la source existe déjà
    UPDATE ingest.partner_catalog_sources
       SET oai_metadata_prefix = coalesce(p_oai_metadata_prefix, oai_metadata_prefix),
           oai_set             = p_oai_set,
           notes               = coalesce(p_notes, notes),
           partner_name        = coalesce(p_partner_name, partner_name),
           updated_at          = now()
     WHERE id = v_source_id;

    -- Met à jour lots_per_cycle sur le state
    UPDATE ingest.oai_harvest_state
       SET lots_per_cycle = coalesce(p_lots_per_cycle, lots_per_cycle)
     WHERE source_id = v_source_id;

    RETURN jsonb_build_object(
      'ok', true, 'source_id', v_source_id, 'created', false
    );
  END IF;

  -- Crée la source
  -- relation_status portait un mot hors de
  -- partner_catalog_sources_relation_status_check : 23514 a chaque appel, donc
  -- aucune source OAI n'a jamais existe. On pose le statut le plus faible du
  -- vocabulaire : la source est REPEREE, aucune relation n'est affirmee. Un
  -- endpoint OAI-PMH est une offre technique de moissonnage, pas un accord
  -- negocie — et la fonction ne recoit aucun argument de relation, donc tout
  -- autre choix serait une affirmation inventee. Meme arbitrage que les deux
  -- paquets du 28/08/2026 (source-depot-sans-partenaire, candidat-institutionnel).
  INSERT INTO ingest.partner_catalog_sources
    (partner_name, library_id, relation_status, source_kind,
     import_enabled, oai_endpoint_url, oai_metadata_prefix, oai_set, notes)
  VALUES
    (p_partner_name, p_library_id, 'mapeada', 'oai_pmh',
     true, trim(p_oai_endpoint_url), coalesce(p_oai_metadata_prefix, 'marcxml'),
     p_oai_set, p_notes)
  RETURNING id INTO v_source_id;

  -- Crée la ligne harvest_state associée
  INSERT INTO ingest.oai_harvest_state (source_id, lots_per_cycle)
  VALUES (v_source_id, coalesce(p_lots_per_cycle, 5))
  RETURNING id INTO v_state_id;

  RETURN jsonb_build_object(
    'ok', true, 'source_id', v_source_id, 'state_id', v_state_id, 'created', true
  );
END;
$$;
CREATE OR REPLACE FUNCTION "public"."fn_import_harvest_oai"("p_source_id" bigint, "p_max_lots" integer DEFAULT NULL::integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'ingest', 'auth'
    AS $$
DECLARE
  v_actor      public.my_access%rowtype;
  v_source     record;
  v_state      record;
  v_run_id     bigint;
  v_max        integer;
BEGIN
  -- 1. Contrôle d'accès
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  -- 2. Vérifier la source
  SELECT * INTO v_source
    FROM ingest.partner_catalog_sources
   WHERE id = p_source_id AND source_kind = 'oai_pmh';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Source OAI-PMH % introuvable.', p_source_id;
  END IF;

  -- Vérifier appartenance (sauf admin réseau)
  IF NOT public.fn_caller_is_network_admin()
     AND v_source.library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Source % nao pertence a esta biblioteca.', p_source_id;
  END IF;

  -- 3. Vérifier l'état
  SELECT * INTO v_state
    FROM ingest.oai_harvest_state
   WHERE source_id = p_source_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Etat de moissonnage introuvable pour source %.', p_source_id;
  END IF;

  IF v_state.harvest_status = 'in_progress' THEN
    RAISE EXCEPTION 'Moissonnage deja en cours pour source %.', p_source_id;
  END IF;

  v_max := coalesce(p_max_lots, v_state.lots_per_cycle);

  -- 4. Créer un run
  -- Trois fautes cumulees ici, toutes invisibles a la relecture et toutes
  -- fatales a l'execution :
  --   * detected_format = oai_pmh n'appartenait pas a
  --     partner_catalog_import_runs_detected_format_check          -> 23514
  --     (le vocabulaire est elargi par cette migration : c'est une provenance
  --     reelle, et le prefixe de metadonnees n'est PAS connu a la naissance du
  --     run — l'EF le negocie, cf. commentaire de oai_metadata_prefix.)
  --   * run_status portait un mot absent de
  --     partner_catalog_import_runs_run_status_check               -> 23514
  --     On prend le mot du vocabulaire qui dit la verite : le run existe, rien
  --     ne le traite encore. C'est ce que la vue
  --     api.partner_catalog_import_run_policy_ui appelle dispatch_pending
  --     (« a lancer ou relancer explicitement »). Ecrire processing
  --     affirmerait qu'un traitement tourne, ce qui est faux tant que l'EF
  --     harvest-oai-pmh n'existe pas — verifie le 28/08/2026 : elle n'est pas
  --     dans supabase/functions/ (oai-pmh-provider est le sens INVERSE, c'est
  --     AnarBib qui expose son catalogue). Quand le Lot 3b arrivera, l'EF fera
  --     monter le run par les barreaux normaux de l'echelle.
  --   * storage_path est NOT NULL et SANS defaut, et n'etait pas fourni -> 23502
  --     Aucun fichier n'est televerse ici (les notices arrivent par HTTP), mais
  --     la colonne veut une adresse : chemin de CONVENTION, comme
  --     fn_deposit_fonds_direct_prepare pose direct/<source>/<cible> et
  --     fn_import_ingest_candidate lookup/<library_id>/<date>. Rien ne le lit :
  --     ce run n'est jamais confie a l'EF de parsing de fichiers.
  INSERT INTO ingest.partner_catalog_import_runs
    (source_id, library_id, detected_format, run_status, storage_path,
     original_filename, requested_by, imported_rows)
  VALUES
    (p_source_id, v_source.library_id, 'oai_pmh', 'queued',
     'oai/' || p_source_id::text || '/' || current_date::text,
     'oai-harvest-' || current_date::text, v_actor.user_id, 0)
  RETURNING id INTO v_run_id;

  -- 5. Marquer l'état en cours
  UPDATE ingest.oai_harvest_state
     SET harvest_status            = 'in_progress',
         last_run_id               = v_run_id,
         lots_completed_this_cycle = 0,
         last_error                = NULL
   WHERE source_id = p_source_id;

  -- 6. TODO Lot 3b : appel pg_net vers l'EF harvest-oai-pmh
  --    Pour l'instant on retourne l'info du run créé.
  --    L'EF mettra à jour le run et le state après parsing.

  RETURN jsonb_build_object(
    'ok',        true,
    'run_id',    v_run_id,
    'source_id', p_source_id,
    'max_lots',  v_max,
    'endpoint',  v_source.oai_endpoint_url,
    'prefix',    v_source.oai_metadata_prefix,
    'from_date', v_state.last_harvest_at,
    'note',      'Edge Function harvest-oai-pmh pas encore deployee (Lot 3b). Run cree en attente.'
  );
END;
$$;

-- ── 3. Droits rejoués à l'identique du baseline ──────────────────────────
revoke execute on function public.fn_import_register_oai_source(text, text, uuid, text, text, integer, text) from public;
grant  execute on function public.fn_import_register_oai_source(text, text, uuid, text, text, integer, text) to authenticated, service_role;

revoke execute on function public.fn_import_harvest_oai(bigint, integer) from public;
grant  execute on function public.fn_import_harvest_oai(bigint, integer) to authenticated, service_role;

comment on function public.fn_import_register_oai_source(text, text, uuid, text, text, integer, text) is
  'Lot 3a — Enregistre une source OAI-PMH + initialise son etat de moissonnage. '
  'Reserve aux admins reseau. Idempotent : met a jour si l''endpoint existe deja. '
  'Paquet chemin-oai-pmh-executable du 28/08/2026 : la fonction etait '
  'INEXECUTABLE depuis son ecriture — relation_status hors de sa CHECK, et '
  'source_kind ecrivant un mot que la CHECK n''admettait pas. Aucune source '
  'oai_pmh n''existait donc en base, ce qui rendait aussi sa branche de mise a '
  'jour inatteignable : la branche de repli ETAIT la branche.';

comment on function public.fn_import_harvest_oai(bigint, integer) is
  'Lot 3a — Declenche un moissonnage OAI-PMH pour une source donnee. Cree un '
  'run (queued) + pose le verrou in_progress sur l''etat. Paquet '
  'chemin-oai-pmh-executable du 28/08/2026 : la fonction etait INEXECUTABLE '
  'depuis son ecriture (detected_format et run_status hors de leurs CHECK, '
  'storage_path NOT NULL sans defaut non fourni). ATTENTION Lot 3b : l''EF '
  'harvest-oai-pmh n''existe pas encore, donc PERSONNE ne relache le verrou '
  'in_progress — le moissonnage s''execute une fois par source, puis est refuse. '
  'C''est le Lot 3b qui doit brancher l''EF et faire monter le run.';

-- ── 4. Vérification STRUCTURELLE (aucune donnée requise : en CI les
--       migrations tournent AVANT le seed) ────────────────────────────────
do $$
DECLARE
  v_def text;
  v_con text;
  v_missing text;
BEGIN
  -- 4.1 Les deux fonctions existent toujours.
  FOR v_missing IN
    SELECT x FROM unnest(ARRAY['fn_import_register_oai_source','fn_import_harvest_oai']) x
     WHERE NOT EXISTS (
       SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = x)
  LOOP
    RAISE EXCEPTION '% introuvable apres migration', v_missing;
  END LOOP;

  -- 4.2 register : le mot hors vocabulaire ne doit plus etre ecrit, et le mot
  --     du vocabulaire doit l'etre. (Les litteraux sont cites SANS guillemets
  --     dans les commentaires de la fonction, sinon ce controle se mentirait
  --     a lui-meme : il cherche le LITTERAL entre apostrophes dans le corps.)
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'fn_import_register_oai_source';
  IF position('''active''' in v_def) > 0 THEN
    RAISE EXCEPTION 'register_oai_source ecrit encore un relation_status hors vocabulaire';
  END IF;
  IF position('''mapeada''' in v_def) = 0 THEN
    RAISE EXCEPTION 'register_oai_source n''ecrit pas le relation_status attendu';
  END IF;

  -- 4.3 harvest : storage_path nomme dans l'INSERT, et plus de statut fantome.
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'fn_import_harvest_oai';
  IF position('storage_path' in v_def) = 0 THEN
    RAISE EXCEPTION 'harvest_oai : storage_path toujours absent de l''INSERT (NOT NULL sans defaut)';
  END IF;
  IF position('''pending''' in v_def) > 0 THEN
    RAISE EXCEPTION 'harvest_oai ecrit encore un run_status hors vocabulaire';
  END IF;
  IF position('''queued''' in v_def) = 0 THEN
    RAISE EXCEPTION 'harvest_oai n''ecrit pas le run_status attendu';
  END IF;

  -- 4.4 Les vocabulaires admettent bien le mot que les deux fonctions ecrivent.
  --     Confronte a pg_get_constraintdef, pas a une liste recopiee ici.
  SELECT pg_get_constraintdef(c.oid) INTO v_con FROM pg_constraint c
   WHERE c.conname = 'partner_catalog_sources_source_kind_check';
  IF v_con IS NULL OR position('''oai_pmh''' in v_con) = 0 THEN
    RAISE EXCEPTION 'source_kind_check n''admet pas oai_pmh : %', coalesce(v_con, '<absente>');
  END IF;

  SELECT pg_get_constraintdef(c.oid) INTO v_con FROM pg_constraint c
   WHERE c.conname = 'partner_catalog_import_runs_detected_format_check';
  IF v_con IS NULL OR position('''oai_pmh''' in v_con) = 0 THEN
    RAISE EXCEPTION 'detected_format_check n''admet pas oai_pmh : %', coalesce(v_con, '<absente>');
  END IF;

  -- Non-regression du paquet voisin du meme jour : elargir ne doit pas retirer.
  IF position('''institutional_lookup''' in
       (SELECT pg_get_constraintdef(c.oid) FROM pg_constraint c
         WHERE c.conname = 'partner_catalog_sources_source_kind_check')) = 0 THEN
    RAISE EXCEPTION 'source_kind_check a PERDU institutional_lookup en s''elargissant';
  END IF;

  -- 4.5 run_status : rien a elargir, mais on verifie que le mot choisi y est
  --     deja — si quelqu'un retirait queued du vocabulaire, harvest_oai
  --     redeviendrait inexecutable sans que rien ne le dise.
  SELECT pg_get_constraintdef(c.oid) INTO v_con FROM pg_constraint c
   WHERE c.conname = 'partner_catalog_import_runs_run_status_check';
  IF v_con IS NULL OR position('''queued''' in v_con) = 0 THEN
    RAISE EXCEPTION 'run_status_check n''admet pas queued : %', coalesce(v_con, '<absente>');
  END IF;

  RAISE NOTICE 'chemin-oai-pmh-executable : verifications structurelles OK';
END $$;

commit;
