-- =========================================================================
-- Paquet source-depot-sans-partenaire — la voie « source seule » redevient
-- praticable, et elle est enfin reliée à un écran
-- =========================================================================
-- Date     : 2026-08-28
-- Chantier : importations — fonds déposés par une bibliothèque amie
-- Auteur   : coordination AnarBib
--
-- POURQUOI
--   public.fn_import_register_deposit_source(p_partner_name, p_notes) écrivait :
--
--     INSERT INTO ingest.partner_catalog_sources (..., relation_status, ...)
--     VALUES (..., 'active', ...)
--
--   Or 'active' n'appartient pas au vocabulaire de la colonne. La contrainte
--   partner_catalog_sources_relation_status_check n'admet que : mapeada,
--   contatada, em_discussao, acordo_parcial, acordo_tecnico,
--   importacao_autorizada, mutualizacao_autorizada. Tout appel atteignant
--   l'INSERT levait donc une violation de contrainte : la fonction ne savait
--   que RETROUVER une source existante (branche du RETURN anticipé), jamais
--   en créer une. Du code mort, au sens strict.
--
--   La confusion est datée : la fonction sœur fn_partner_register_deposit_source
--   porte, elle, le commentaire « Vocabulaires DISTINCTS entre les deux tables »
--   et pose bien 'mapeada' / 'importacao_autorizada' côté source. La leçon avait
--   été tirée là-bas et jamais reportée ici.
--
--   Le défaut est resté invisible parce qu'aucune interface n'appelait cette
--   RPC : l'écran « Dépôt format maison » du Lot 2b avait ses libellés traduits
--   dans les dix langues mais n'a jamais été rendu. Un chemin jamais emprunté
--   n'est pas un chemin qui marche.
--
-- POURQUOI RÉPARER PLUTÔT QUE SUPPRIMER
--   Parce que c'est la SEULE voie qui crée une source de dépôt sans créer
--   d'entité public.catalog_partners. L'autre RPC,
--   fn_partner_register_deposit_source (utilisée par
--   ExternalDepositPartnerSection), crée toujours le partenaire — ce qui n'est
--   pas toujours souhaitable : admettre un collectif comme partenaire du réseau
--   est une décision fédérale, parfois délibérément différée, alors que recevoir
--   son fichier de catalogue ne l'est pas.
--
--   Le cas s'est présenté en vrai le 27/08/2026 avec le fonds Solidaires : la
--   source #17 « Bibliothèque Solidaires » a dû être posée à la main, par un
--   INSERT direct, précisément parce que cette voie n'existait pas.
--
-- POURQUOI 'mapeada'
--   C'est le statut le plus faible du vocabulaire : la source est repérée, rien
--   de plus. Il est cohérent avec l'absence d'entité partenaire — on n'affirme
--   aucune relation, aucun accord. C'est aussi exactement ce qui a été posé à la
--   main sur la source #17. import_enabled reste true : sans lui,
--   ingest.fn_create_partner_catalog_import refuse le dépôt (« La source %
--   n'autorise pas encore les imports »), et une source de dépôt qu'on ne peut
--   pas alimenter n'a aucun intérêt.
--
-- CHECKLIST DOCTRINE
--   [x] Fonction SECURITY DEFINER : search_path conservé (public, ingest, auth)
--   [x] REVOKE EXECUTE FROM PUBLIC + GRANT aux rôles ciblés rejoués
--   [x] Aucune table, vue ou policy touchée ; contrainte inchangée
--   [x] DO block de vérification structurel (pas de dépendance aux données :
--       les migrations tournent AVANT le seed en CI)
-- =========================================================================

begin;

create or replace function public.fn_import_register_deposit_source(
  p_partner_name text,
  p_notes        text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'ingest', 'auth'
as $function$
DECLARE
  v_actor     public.my_access%rowtype;
  v_source_id bigint;
  v_name      text;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  v_name := nullif(trim(p_partner_name), '');
  IF v_name IS NULL THEN
    RAISE EXCEPTION 'Nome do parceiro obrigatorio.';
  END IF;

  -- Cherche une source existante avec le même nom et kind
  SELECT id INTO v_source_id
    FROM ingest.partner_catalog_sources
   WHERE library_id  = v_actor.library_id
     AND source_kind = 'partner_deposit'
     AND partner_name = v_name
   LIMIT 1;

  IF v_source_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', true, 'source_id', v_source_id, 'created', false
    );
  END IF;

  -- 'mapeada' : statut le plus faible du vocabulaire de la colonne
  -- (partner_catalog_sources_relation_status_check). Cohérent avec
  -- catalog_partner_id NULL : on reçoit un fichier, on n'affirme aucune
  -- relation. Ne PAS écrire 'active' : ce mot n'appartient pas à ce
  -- vocabulaire — c'était le défaut réparé par ce paquet.
  INSERT INTO ingest.partner_catalog_sources
    (partner_name, library_id, relation_status, source_kind,
     import_enabled, notes)
  VALUES
    (v_name, v_actor.library_id, 'mapeada', 'partner_deposit',
     true, nullif(trim(p_notes), ''))
  RETURNING id INTO v_source_id;

  RETURN jsonb_build_object(
    'ok', true, 'source_id', v_source_id, 'created', true
  );
END;
$function$;

revoke execute on function public.fn_import_register_deposit_source(text, text) from public;
grant  execute on function public.fn_import_register_deposit_source(text, text) to authenticated, service_role;

comment on function public.fn_import_register_deposit_source(text, text) is
  'Enregistre une source de dépôt (partner_deposit) pour la bibliothèque active, '
  'SANS créer d''entité public.catalog_partners — la voie à emprunter quand '
  'l''admission comme partenaire du réseau n''est pas décidée. Idempotent : '
  'retourne la source existante si le nom correspond. relation_status = mapeada '
  '(paquet source-depot-sans-partenaire du 28/08/2026 ; posait auparavant '
  '''active'', hors vocabulaire, ce qui rendait la création impossible). '
  'Pour créer AUSSI l''entité partenaire, utiliser fn_partner_register_deposit_source.';

-- Vérification structurelle : le statut retenu doit appartenir au vocabulaire
-- de la contrainte, et le mot interdit ne doit plus figurer dans le corps.
do $$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname = 'fn_import_register_deposit_source';

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'fn_import_register_deposit_source introuvable apres migration';
  END IF;

  IF position('''active'', ''partner_deposit''' in v_def) > 0 THEN
    RAISE EXCEPTION 'fn_import_register_deposit_source insere encore le statut hors vocabulaire active';
  END IF;

  -- Le statut posé doit être accepté par la contrainte de la table.
  BEGIN
    INSERT INTO ingest.partner_catalog_sources
      (partner_name, library_id, relation_status, source_kind, import_enabled)
    VALUES
      ('__verif_paquet_depot__', NULL, 'mapeada', 'partner_deposit', true);
  EXCEPTION WHEN check_violation THEN
    RAISE EXCEPTION 'le statut mapeada est refuse par partner_catalog_sources_relation_status_check';
  END;
  DELETE FROM ingest.partner_catalog_sources WHERE partner_name = '__verif_paquet_depot__';

  RAISE NOTICE 'Paquet source-depot-sans-partenaire : verifications OK';
END $$;

commit;

-- =========================================================================
-- Rollback : il n'y en a pas d'utile. L'état antérieur était du code mort —
-- y revenir consisterait à réécrire 'active' dans le corps de la fonction,
-- c'est-à-dire à la recasser.
-- =========================================================================
