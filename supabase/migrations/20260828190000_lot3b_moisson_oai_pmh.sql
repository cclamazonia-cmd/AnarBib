-- =========================================================================
-- Paquet lot3b-moisson-oai-pmh — le moissonnage ramène vraiment des notices,
-- et le verrou se relâche
-- =========================================================================
-- Date     : 2026-08-28
-- Chantier : importations — moisson OAI-PMH (mode « oai »), Lot 3b
-- Voisin   : 20260828170000_chemin_oai_pmh_executable.sql — lire son en-tête :
--            il rend les deux RPC exécutables et dit en toutes lettres ce qui
--            restait, à savoir CE paquet.
--
-- CE QUE LE LOT 3A LAISSAIT
--   fn_import_harvest_oai créait un run, posait oai_harvest_state.harvest_status
--   = in_progress comme VERROU, et s'arrêtait sur un « TODO Lot 3b : appel
--   pg_net vers l'EF harvest-oai-pmh ». Cette EF n'existait pas. Le verrou
--   n'était donc relâché par personne : le moissonnage marchait UNE fois par
--   source, puis toute tentative se heurtait à « Moissonnage deja en cours »
--   — pour toujours, et sans que rien ne le signale, puisque la RPC répondait
--   comme si un travail tournait vraiment.
--
--   Ce paquet livre les trois pièces qui manquaient :
--     1. l'EF supabase/functions/harvest-oai-pmh (moisson + dépôt en file de
--        révision + rapprochement + RELÂCHEMENT DU VERROU sur tout chemin) ;
--     2. ingest.fn_dispatch_oai_harvest, l'appel pg_net qui l'atteint ;
--     3. la reprise de verrou périmé, ici, pour le cas où l'EF n'est JAMAIS
--        atteinte (pg_net en panne, démarrage à froid, EF tuée par l'expiration
--        côté pg_net) — car alors personne n'exécute son `finally`.
--
-- POURQUOI UNE REPRISE DE VERROU, ET PAS SEULEMENT UN `finally` DANS L'EF
--   Un `finally` ne protège que les chemins qui l'atteignent. Il ne dit rien du
--   cas où le processus n'a jamais démarré. C'est exactement la forme de panne
--   déjà rencontrée sur les sauvegardes #BG2 : restic tué laisse un verrou
--   orphelin qui fige le flux, et la parade a été d'ajouter un unlock_stale
--   AVANT chaque sauvegarde plutôt que d'espérer une sortie propre. Même
--   raisonnement, même remède : au-delà de 30 minutes, un in_progress est
--   considéré comme abandonné et repris.
--
--   Le délai est LARGE devant un cycle réel : lots_per_cycle vaut 5 par défaut,
--   chaque lot est une requête HTTP plafonnée à 20 s côté EF, et pg_net coupe à
--   120 s. Une reprise ne peut donc pas doubler un moissonnage qui travaille
--   encore. À l'inverse elle ne masque rien : la RPC renvoie
--   `reclaimed_stale_lock: true`, et plusieurs reprises d'affilée veulent dire
--   que l'EF n'aboutit pas — ça se lit dans oai_harvest_state.last_error.
--
-- LE SECRET : CELUI QUI EXISTE DÉJÀ
--   ANARBIB_PARTNER_IMPORT_SECRET (coffre + variable d'EF), en-tête
--   x-import-secret. C'est celui de process-partner-catalog-import et de
--   receive-fonds-bundle : même famille, même porte. Un secret de plus serait
--   un secret de plus à provisionner, à faire tourner et à perdre — pour une
--   frontière de confiance identique. Rien à créer côté Supabase.
--
-- CE QUE CE PAQUET NE CHANGE PAS
--   Aucune contrainte, aucune table, aucune policy, aucune RLS. Les deux CHECK
--   élargies la veille (source_kind, detected_format) restent telles quelles :
--   le run naît toujours `queued`, et c'est l'EF qui le fait monter
--   (processing → ready_for_review), par les barreaux normaux de l'échelle.
--
-- CHECKLIST DOCTRINE
--   [x] Corps de fn_import_harvest_oai EXTRAIT de sa dernière définition au
--       dépôt (20260828170000) et modifié par ancrages vérifiés (3
--       remplacements, 1 occurrence exacte chacun) — jamais retapé
--   [x] SECURITY DEFINER : search_path conservé (public, ingest, auth)
--   [x] REVOKE EXECUTE FROM PUBLIC + GRANT aux rôles du baseline rejoués
--   [x] La nouvelle fonction de dispatch est INTERNE (schéma ingest, aucun
--       GRANT à authenticated : elle n'est appelable que par ses sœurs DEFINER)
--   [x] DO block de vérification STRUCTUREL ; le fonctionnel vit dans
--       tests/sql/import_oai_pmh_tests.sql (SQL) et
--       src/tests/harvest-oai-pmh.test.js (l'EF, exercée pour de vrai)
-- =========================================================================

begin;

-- ── 1. Le dispatch pg_net vers l'EF ──────────────────────────────────────
-- Décalque de ingest.fn_dispatch_partner_catalog_import : même coffre, même
-- en-tête, même journal (partner_catalog_import_dispatch_log), pour que le
-- moissonnage se diagnostique avec les mêmes gestes que le reste des imports.
create or replace function ingest.fn_dispatch_oai_harvest(
  p_run_id bigint,
  p_max_lots integer default null
) returns jsonb
language plpgsql
security definer
set search_path to 'ingest', 'public', 'auth'
as $function$
declare
  v_secret     text;
  v_request_id bigint;
  v_body       jsonb;
  v_log_id     bigint;
  v_url        text := 'https://uflwmikiyjfnikiphtcp.supabase.co/functions/v1/harvest-oai-pmh';
begin
  if not exists (select 1 from ingest.partner_catalog_import_runs where id = p_run_id) then
    raise exception 'Run % introuvable', p_run_id;
  end if;

  select ds.decrypted_secret into v_secret
    from vault.decrypted_secrets ds
   where ds.name = 'ANARBIB_PARTNER_IMPORT_SECRET'
   order by ds.created_at desc
   limit 1;

  if coalesce(v_secret, '') = '' then
    raise exception 'Secret ANARBIB_PARTNER_IMPORT_SECRET introuvable dans vault.decrypted_secrets';
  end if;

  v_body := jsonb_build_object('run_id', p_run_id, 'max_lots', p_max_lots);

  insert into ingest.partner_catalog_import_dispatch_log
    (run_id, force_reparse, request_body, requested_by, dispatch_status)
  values (p_run_id, false, v_body, auth.uid(), 'queued')
  returning id into v_log_id;

  -- timeout_milliseconds vaut 5000 par DEFAUT dans net.http_post — trop court
  -- ici : un cycle enchaine jusqu'a lots_per_cycle requetes HTTP vers un
  -- entrepot distant. On donne 120 s. Au-dela, pg_net abandonne et l'EF peut
  -- etre tuee en cours de route : c'est precisement le cas que la reprise de
  -- verrou perime rattrape, et le resumptionToken deja ecrit fait repartir le
  -- cycle suivant ou celui-ci s'est arrete.
  v_request_id := net.http_post(
    url                  := v_url,
    headers              := jsonb_build_object(
                              'Content-Type', 'application/json',
                              'x-import-secret', v_secret),
    body                 := v_body,
    timeout_milliseconds := 120000
  );

  update ingest.partner_catalog_import_dispatch_log
     set request_id = v_request_id, dispatch_status = 'sent'
   where id = v_log_id;

  -- Pas de bloc `exception when others` ici, contrairement au voisin : son
  -- `update … dispatch_status='failed'` suivi de `raise` est annule par le
  -- rollback que le raise declenche. Ecrire une trace qui ne survit pas donne
  -- l'illusion d'un journal. Ici un echec remonte tel quel a l'appelante, qui
  -- perd avec lui son run et son verrou — l'etat le plus propre possible.
  return jsonb_build_object(
    'ok', true, 'run_id', p_run_id, 'dispatch_log_id', v_log_id,
    'request_id', v_request_id, 'function_url', v_url, 'max_lots', p_max_lots
  );
end;
$function$;

revoke execute on function ingest.fn_dispatch_oai_harvest(bigint, integer) from public;
grant  execute on function ingest.fn_dispatch_oai_harvest(bigint, integer) to service_role;

comment on function ingest.fn_dispatch_oai_harvest(bigint, integer) is
  'Lot 3b — Appelle l''EF harvest-oai-pmh par pg_net (auth interne '
  'x-import-secret / ANARBIB_PARTNER_IMPORT_SECRET, le meme que '
  'process-partner-catalog-import) et journalise dans '
  'partner_catalog_import_dispatch_log. INTERNE : appelee par '
  'public.fn_import_harvest_oai, jamais depuis le client. Asynchrone — elle '
  'depose la requete et rend la main ; c''est l''EF qui ecrit les notices et '
  'relache le verrou de oai_harvest_state.';

-- ── 2. La RPC de moissonnage appelle enfin l'EF ──────────────────────────
-- Corps EXTRAIT de 20260828170000_chemin_oai_pmh_executable.sql, modifié par
-- ancrages (3 remplacements, 1 occurrence exacte chacun) — jamais retapé.
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
  'elle rend la main tout de suite, l''EF ecrit les notices, fait rapprocher le '
  'run et RELACHE le verrou. Paquet lot3b-moisson-oai-pmh du 28/08/2026 : '
  'jusque-la l''EF n''existait pas, donc le verrou ne se relachait jamais et le '
  'moissonnage ne marchait qu''une fois par source. Un in_progress de plus de '
  '30 minutes est desormais repris (l''EF n''a jamais rendu la main) ; la '
  'reponse porte alors reclaimed_stale_lock = true.';

-- ── 3. Vérification STRUCTURELLE (aucune donnée requise : en CI les
--       migrations tournent AVANT le seed) ────────────────────────────────
do $$
DECLARE
  v_def text;
BEGIN
  -- 3.1 La fonction de dispatch existe et vise la bonne EF.
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'ingest' AND p.proname = 'fn_dispatch_oai_harvest';
  IF v_def IS NULL THEN
    RAISE EXCEPTION 'ingest.fn_dispatch_oai_harvest introuvable apres migration';
  END IF;
  IF position('harvest-oai-pmh' in v_def) = 0 THEN
    RAISE EXCEPTION 'le dispatch ne vise pas l''EF harvest-oai-pmh';
  END IF;
  IF position('ANARBIB_PARTNER_IMPORT_SECRET' in v_def) = 0 THEN
    RAISE EXCEPTION 'le dispatch n''utilise pas le secret d''import attendu';
  END IF;
  -- Le defaut de net.http_post (5 s) tuerait un cycle de plusieurs lots.
  IF position('timeout_milliseconds' in v_def) = 0 THEN
    RAISE EXCEPTION 'le dispatch laisse le timeout par defaut de net.http_post (5 s)';
  END IF;

  -- 3.2 La RPC appelle vraiment le dispatch, et ne s'excuse plus.
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'fn_import_harvest_oai';
  IF v_def IS NULL THEN
    RAISE EXCEPTION 'public.fn_import_harvest_oai introuvable apres migration';
  END IF;
  IF position('fn_dispatch_oai_harvest' in v_def) = 0 THEN
    RAISE EXCEPTION 'fn_import_harvest_oai n''appelle pas le dispatch : le TODO Lot 3b tient toujours';
  END IF;
  -- Le champ 'note' annoncait l'absence d'EF, et l'ecran l'affichait A LA PLACE
  -- du message localise. Sa presence signifierait que la RPC dit encore que
  -- rien n'existe. (Cite sans guillemets : ce controle cherche le LITTERAL.)
  IF position('''note''' in v_def) > 0 THEN
    RAISE EXCEPTION 'fn_import_harvest_oai renvoie encore le champ note du Lot 3a';
  END IF;

  -- 3.3 La reprise de verrou perime est en place. Sans elle, une EF jamais
  --     atteinte laisse la source inmoissonnable, exactement comme avant.
  IF position('30 minutes' in v_def) = 0 THEN
    RAISE EXCEPTION 'la reprise de verrou perime a disparu de fn_import_harvest_oai';
  END IF;
  IF position('reclaimed_stale_lock' in v_def) = 0 THEN
    RAISE EXCEPTION 'la reprise de verrou ne se signale pas dans la reponse';
  END IF;

  RAISE NOTICE 'lot3b-moisson-oai-pmh : verifications structurelles OK';
END $$;

commit;
