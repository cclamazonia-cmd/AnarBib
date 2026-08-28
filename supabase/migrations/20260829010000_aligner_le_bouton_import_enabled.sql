-- =========================================================================
-- Paquet aligner-le-bouton — import_enabled vaut aussi pour le geste manuel
-- =========================================================================
-- Date     : 2026-08-28
-- Chantier : importations — moisson OAI-PMH
-- Voisin   : 20260828230000_moisson_oai_hebdomadaire.sql — c'est en écrivant
--            son cron qu'on a découvert que la colonne n'était lue par personne.
--
-- POURQUOI
--   ingest.partner_catalog_sources.import_enabled existe depuis le baseline,
--   est posée à true par fn_import_register_oai_source… et n'était consultée
--   par AUCUNE fonction. Vérifié par pg_get_functiondef le 28/08/2026 :
--   fn_import_harvest_oai ne la mentionnait pas.
--
--   Le paquet du cron l'a rendue effective pour le moissonnage AUTOMATIQUE.
--   Restait l'asymétrie : décocher une source l'excluait du cron mais pas du
--   bouton « Moissonner maintenant ». Une case à cocher que la moitié du
--   logiciel ignore est pire qu'une case absente — elle fait croire que la
--   décision a été prise, et c'est précisément vers un partenaire extérieur
--   qu'on continuerait d'envoyer des requêtes après avoir dit qu'on arrêtait.
--
--   C'est le même motif que le reste de ce chantier, dans sa variante la plus
--   discrète : non pas un chemin jamais emprunté, mais un DRAPEAU jamais lu.
--   Rien ne plante, rien ne rougit ; le bouton fonctionne parfaitement, il
--   désobéit simplement.
--
-- LE REFUS PORTE UN HINT, PAS UNE PHRASE
--   src/lib/localizeError.js pose la doctrine : le backend lève avec
--   `USING HINT = 'error.foo.bar'` et le front traduit. Les autres messages de
--   cette fonction sont des phrases libres (héritage du baseline) ; on ne les
--   touche pas, mais le nouveau refus suit la règle. La clé
--   error.oai.sourceDisabled est ajoutée dans les 10 locales par
--   scripts/i18n-add-oai-source-disabled.cjs, et son texte dit À QUI S'ADRESSER :
--   la personne qui clique est coordenadora, pas admin réseau — elle ne peut pas
--   réactiver la source elle-même.
--
--   Le refus tombe APRÈS le contrôle d'appartenance et AVANT toute écriture :
--   aucune source désactivée ne produit de run, ni ne pose de verrou.
--
-- CHECKLIST DOCTRINE
--   [x] Corps EXTRAIT de sa dernière définition au dépôt (20260828190000) et
--       modifié par ancrage vérifié (1 remplacement, 1 occurrence) — jamais retapé
--   [x] SECURITY DEFINER : search_path conservé (public, ingest, auth)
--   [x] REVOKE EXECUTE FROM PUBLIC + GRANT rejoués
--   [x] Aucune table, contrainte, vue ou policy touchée
--   [x] DO block de vérification STRUCTUREL ; le fonctionnel vit dans
--       tests/sql/import_oai_pmh_tests.sql
-- =========================================================================

begin;

-- Corps EXTRAIT de 20260828190000_lot3b_moisson_oai_pmh.sql, modifié par
-- ancrage (1 remplacement, 1 occurrence exacte) — jamais retapé.
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
  v_stale      boolean := false;
  v_dispatch   jsonb;
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

  -- import_enabled : une colonne qui existait, etait posee a true a
  -- l'enregistrement, et n'etait LUE PAR PERSONNE. Le cron hebdomadaire
  -- (ingest.fn_cron_import_harvest_oai, 28/08/2026) l'a rendue effective ; le
  -- bouton, lui, continuait de moissonner une source decochee. Une case a
  -- cocher que la moitie du logiciel ignore est pire qu'une case absente : elle
  -- fait croire que la decision a ete prise.
  --
  -- HINT plutot qu'un message libre : c'est la doctrine du depot
  -- (src/lib/localizeError.js) et la personne qui clique est coordinatrice, pas
  -- admin reseau — elle ne peut pas reactiver la source elle-meme, le message
  -- doit donc lui dire a qui s'adresser. Le refus tombe AVANT toute ecriture.
  IF NOT coalesce(v_source.import_enabled, false) THEN
    RAISE EXCEPTION 'Fonte % desativada para importacao.', p_source_id
      USING HINT = 'error.oai.sourceDisabled';
  END IF;

  -- 3. Vérifier l'état
  SELECT * INTO v_state
    FROM ingest.oai_harvest_state
   WHERE source_id = p_source_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Etat de moissonnage introuvable pour source %.', p_source_id;
  END IF;

  -- Le verrou est un vrai verrou : deux moissonnages concurrents sur la meme
  -- source se marcheraient dessus (meme run, meme jeton de reprise). Mais un
  -- verrou que personne ne relache est pire que pas de verrou du tout : jusqu'au
  -- Lot 3b il n'existait aucune EF pour le lever, et la source devenait
  -- inmoissonnable pour toujours. L'EF le releve maintenant sur TOUS ses chemins
  -- de sortie (finally) — sauf si elle n'est jamais atteinte : pg_net en panne,
  -- demarrage a froid trop long, EF tuee par l'expiration cote pg_net.
  --
  -- D'ou cette reprise. updated_at est pose par un trigger a chaque ecriture de
  -- la ligne, donc tant que le statut est in_progress il date exactement de la
  -- prise du verrou. Au-dela du delai, on considere que l'EF ne rendra plus la
  -- main et on reprend — meme parade que unlock_stale avant chaque sauvegarde
  -- restic. Le delai est LARGE devant un cycle (quelques minutes au pire) :
  -- il ne peut pas doubler un moissonnage qui travaille encore.
  IF v_state.harvest_status = 'in_progress' THEN
    IF v_state.updated_at > now() - interval '30 minutes' THEN
      RAISE EXCEPTION 'Moissonnage deja en cours pour source %.', p_source_id;
    END IF;
    v_stale := true;
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

  -- 6. Lot 3b : l'EF harvest-oai-pmh est appelee (pg_net, asynchrone).
  --    Ce qui suit n'attend PAS la moisson : net.http_post depose la requete et
  --    rend la main tout de suite. L'EF ecrira les notices, fera rapprocher le
  --    run et relachera le verrou. L'ecran, lui, se contente d'annoncer que le
  --    moissonnage est lance et rafraichit la liste.
  --
  --    Si le dispatch echoue (secret absent du coffre, pg_net indisponible), il
  --    LEVE — et comme tout ce qui precede est dans la meme transaction, le run
  --    ET le verrou disparaissent avec. C'est voulu : mieux vaut aucun run et un
  --    message clair qu'un run orphelin devant un verrou que rien ne relachera.
  v_dispatch := ingest.fn_dispatch_oai_harvest(v_run_id, v_max);

  RETURN jsonb_build_object(
    'ok',        true,
    'run_id',    v_run_id,
    'source_id', p_source_id,
    'max_lots',  v_max,
    'endpoint',  v_source.oai_endpoint_url,
    'prefix',    v_source.oai_metadata_prefix,
    'from_date', v_state.last_harvest_at,
    -- Signale a la coordination que le cycle precedent n'a jamais rendu la main.
    -- Ce n'est pas une erreur (on a repris), mais c'est un symptome : plusieurs
    -- reprises d'affilee veulent dire que l'EF n'aboutit pas.
    'reclaimed_stale_lock', v_stale,
    'dispatch',  v_dispatch
  );
END;
$$;

revoke execute on function public.fn_import_harvest_oai(bigint, integer) from public;
grant  execute on function public.fn_import_harvest_oai(bigint, integer) to authenticated, service_role;

comment on function public.fn_import_harvest_oai(bigint, integer) is
  'Lot 3a/3b — Declenche un moissonnage OAI-PMH pour une source donnee : cree '
  'un run (queued), pose le verrou in_progress, puis appelle l''EF '
  'harvest-oai-pmh par pg_net (ingest.fn_dispatch_oai_harvest). Asynchrone : '
  'l''EF ecrit les notices, fait rapprocher le run et RELACHE le verrou ; un '
  'in_progress de plus de 30 minutes est repris (reclaimed_stale_lock). '
  'Refuse une source dont import_enabled est faux (paquet aligner-le-bouton du '
  '28/08/2026 : la colonne n''etait lue par personne, puis seulement par le '
  'cron hebdomadaire — le bouton moissonnait encore une source decochee).';

-- ── Vérification STRUCTURELLE ────────────────────────────────────────────
do $$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'fn_import_harvest_oai';
  IF v_def IS NULL THEN
    RAISE EXCEPTION 'public.fn_import_harvest_oai introuvable apres migration';
  END IF;

  -- La garde elle-meme.
  IF position('import_enabled' in v_def) = 0 THEN
    RAISE EXCEPTION 'le bouton ignore toujours import_enabled';
  END IF;
  IF position('error.oai.sourceDisabled' in v_def) = 0 THEN
    RAISE EXCEPTION 'le refus ne porte pas de HINT traduisible';
  END IF;

  -- Non-regression des deux paquets precedents : cette migration reecrit la
  -- fonction entiere, elle ne doit rien emporter au passage.
  IF position('fn_dispatch_oai_harvest' in v_def) = 0 THEN
    RAISE EXCEPTION 'l''appel a l''EF (Lot 3b) a disparu';
  END IF;
  IF position('30 minutes' in v_def) = 0 THEN
    RAISE EXCEPTION 'la reprise de verrou perime a disparu';
  END IF;
  IF position('''queued''' in v_def) = 0 THEN
    RAISE EXCEPTION 'le run ne nait plus queued';
  END IF;

  RAISE NOTICE 'aligner-le-bouton : verifications structurelles OK';
END $$;

commit;
