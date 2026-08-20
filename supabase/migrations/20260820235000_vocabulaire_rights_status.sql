-- =============================================================================
-- Vocabulaire controle de rights_status + justification ecrite
-- =============================================================================
-- Date     : 2026-08-20
-- Chantier : numerisation / profil et droits
-- Reference : docs/journal/arbitrages/DECISION_profil_numerisation_2026-08-20.md §1
--
-- PROBLEME. `rights_status` est un champ texte libre. Sur 44 lignes deja
-- versees (18 en catalogue, 26 en brouillon), il porte TROIS graphies pour
-- DEUX concepts, dans deux langues :
--
--     livre_de_direitos                28
--     Domínio público                  12
--     Direitos concedidos pelo autor    4
--
-- A 44 lignes c'est reparable. A mille cinq cents, aucun filtre, aucun export
-- et aucune verification juridique ne sera fiable. Et le profil de
-- numerisation pose que c'est la justification ECRITE qui protege, pas le
-- classement — or il n'existait aucun endroit ou l'ecrire.
--
-- DEUX PORTES produisaient ces graphies, pas une :
--   1. le formulaire de catalogage, ou le champ etait un `input type="text"`
--      libre (corrige dans le meme lot, BookDraftForm.jsx) ;
--   2. `fn_attach_received_asset_record`, qui inserait dans cette colonne le
--      statut envoye par une bibliotheque partenaire, ou a defaut `to_review`
--      — une valeur qui appartient au vocabulaire d'une AUTRE table.
--
-- SOLUTION. Quatre valeurs, une contrainte, et une colonne de justification.
--
--     dominio_publico   duree de protection expiree
--     cessao_autoral    cession ecrite obtenue
--     licenca_livre     publie sous licence libre
--     sob_direitos      sous droits — couverture seule
--
-- NULL reste permis : « pas encore classe » est un etat legitime, et plus
-- honnete qu'une valeur par defaut qui aurait l'air d'un classement.
--
-- -----------------------------------------------------------------------------
-- CE QUI N'EST PAS TOUCHE, ET POURQUOI
-- -----------------------------------------------------------------------------
-- `public.digital_assets` porte une colonne du MEME NOM avec un vocabulaire
-- entierement different — `to_review` / `public_domain_confirmed` — qui n'est
-- pas une classification de droits mais un ETAT DE WORKFLOW de verification, et
-- qui commande la visibilite au catalogue public. Deux concepts, un seul nom.
-- On n'y touche pas ici. Renommer l'une des deux colonnes serait la correction
-- de fond ; elle demande son propre lot.
--
-- -----------------------------------------------------------------------------
-- LE CHOIX QUI MERITE D'ETRE DISCUTE
-- -----------------------------------------------------------------------------
-- `livre_de_direitos` (28 lignes) est ambigu : « libre de droits » peut vouloir
-- dire domaine public OU licence libre, et rien en base ne permet de trancher
-- ligne par ligne. On mappe vers `dominio_publico`, le sens le plus probable,
-- ET on inscrit dans la justification que la valeur vient d'une migration
-- automatique et reste a verifier. Aucune ligne ne doit avoir l'air verifiee
-- alors qu'elle ne l'est pas.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. La colonne de justification
-- -----------------------------------------------------------------------------
alter table public.book_digital_resources
  add column if not exists rights_justification text;

alter table public.book_draft_digital_resources
  add column if not exists rights_justification text;

comment on column public.book_digital_resources.rights_justification is
  'Pourquoi ce statut de droits : nom et date de mort de l''auteur, reference de licence, lien vers la cession. C''est la justification ecrite qui protege, pas le classement (DECISION_profil_numerisation 2026-08-20).';

comment on column public.book_draft_digital_resources.rights_justification is
  'Idem book_digital_resources.rights_justification.';

-- -----------------------------------------------------------------------------
-- 2. Normalisation des 44 lignes existantes
-- -----------------------------------------------------------------------------
-- Le marqueur n'est pose QUE sur les lignes issues de `livre_de_direitos`,
-- celles dont le sens etait ambigu. `Domínio público` et
-- `Direitos concedidos pelo autor` sont explicites : ils se traduisent sans
-- perte, et n'ont pas a etre signales comme douteux.

update public.book_digital_resources
   set rights_status        = 'dominio_publico',
       rights_justification = coalesce(nullif(trim(rights_justification), '') || ' — ', '')
                              || 'a verificar: importado automaticamente de "livre_de_direitos" em 2026-08-20 (migração de vocabulário). Pode ser domínio público OU licença livre.'
 where rights_status = 'livre_de_direitos';

update public.book_draft_digital_resources
   set rights_status        = 'dominio_publico',
       rights_justification = coalesce(nullif(trim(rights_justification), '') || ' — ', '')
                              || 'a verificar: importado automaticamente de "livre_de_direitos" em 2026-08-20 (migração de vocabulário). Pode ser domínio público OU licença livre.'
 where rights_status = 'livre_de_direitos';

update public.book_digital_resources
   set rights_status = 'dominio_publico'
 where rights_status in ('Domínio público', 'Dominio publico', 'domínio público');

update public.book_draft_digital_resources
   set rights_status = 'dominio_publico'
 where rights_status in ('Domínio público', 'Dominio publico', 'domínio público');

update public.book_digital_resources
   set rights_status = 'cessao_autoral'
 where rights_status in ('Direitos concedidos pelo autor', 'direitos concedidos pelo autor');

update public.book_draft_digital_resources
   set rights_status = 'cessao_autoral'
 where rights_status in ('Direitos concedidos pelo autor', 'direitos concedidos pelo autor');

-- Filet : toute valeur non prevue devient NULL, et le dit dans la
-- justification. Mieux vaut « non classe, voici ce qui etait ecrit » qu'une
-- transaction qui echoue en laissant la colonne libre pour six mois de plus.
update public.book_digital_resources
   set rights_justification = coalesce(nullif(trim(rights_justification), '') || ' — ', '')
                              || 'a verificar: valor de origem não reconhecido pela migração de 2026-08-20: "' || rights_status || '"',
       rights_status = null
 where rights_status is not null
   and rights_status not in ('dominio_publico', 'cessao_autoral', 'licenca_livre', 'sob_direitos');

update public.book_draft_digital_resources
   set rights_justification = coalesce(nullif(trim(rights_justification), '') || ' — ', '')
                              || 'a verificar: valor de origem não reconhecido pela migração de 2026-08-20: "' || rights_status || '"',
       rights_status = null
 where rights_status is not null
   and rights_status not in ('dominio_publico', 'cessao_autoral', 'licenca_livre', 'sob_direitos');

-- -----------------------------------------------------------------------------
-- 3. Fermer la deuxieme porte : le flux des fonds recus
-- -----------------------------------------------------------------------------
-- Cette fonction inserait dans book_digital_resources.rights_status le statut
-- envoye par le partenaire, ou a defaut 'to_review' — vocabulaire de
-- digital_assets. Elle pose desormais NULL, et conserve ce que le partenaire
-- avait declare dans la justification, ou c'est lisible sans etre pris pour un
-- classement fait par nous.
--
-- L'insertion dans digital_assets, elle, garde 'to_review' : c'est sa
-- semantique propre, et elle est correcte.
--
-- Definition reprise a l'identique de la production au 2026-08-20 ; seul le
-- bloc d'insertion book_digital_resources change.

CREATE OR REPLACE FUNCTION public.fn_attach_received_asset_record(p_received_asset_id bigint, p_book_id bigint, p_bucket_name text, p_object_path text, p_mode text DEFAULT 'both'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth', 'pg_catalog'
AS $function$
DECLARE
  ra ingest.partner_catalog_received_assets%rowtype;
  v_authorized boolean;
  v_kind text;
  v_title text;
  v_asset_id bigint;
  v_resource_id bigint;
  v_rtype text;
  v_utype text;
BEGIN
  IF p_received_asset_id IS NULL OR p_book_id IS NULL THEN RAISE EXCEPTION 'received_asset_id e book_id obrigatorios.'; END IF;
  IF p_mode NOT IN ('export','read','both') THEN RAISE EXCEPTION 'mode inválido (%).', p_mode; END IF;
  IF p_bucket_name NOT IN ('pdf-restrito','anarbib-media-restricted') THEN RAISE EXCEPTION 'Bucket destino inválido (%).', p_bucket_name; END IF;
  IF p_object_path IS NULL OR p_object_path LIKE 'http%' THEN RAISE EXCEPTION 'Caminho de destino inválido.'; END IF;

  SELECT * INTO ra FROM ingest.partner_catalog_received_assets WHERE id = p_received_asset_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Recurso recebido % introuvável.', p_received_asset_id; END IF;
  -- Idempotence : déjà attaché (asset OU lecture-seule marquée attached).
  IF ra.attached_digital_asset_id IS NOT NULL OR ra.deposit_status = 'attached' THEN
    RETURN jsonb_build_object('ok', true, 'asset_id', ra.attached_digital_asset_id, 'created', false, 'book_id', p_book_id);
  END IF;

  -- Garde 0 : le fichier reçu appartient à une biblio coordonnée par l'appelant.
  IF NOT public.fn_caller_is_network_admin() AND NOT EXISTS (
    SELECT 1 FROM ingest.partner_catalog_import_runs run
      JOIN public.user_library_memberships m ON m.library_id = run.library_id
     WHERE run.id = ra.run_id AND m.user_id = auth.uid() AND m.status = 'active' AND m.role = 'coordenador'
  ) THEN RAISE EXCEPTION 'Recurso recebido não pertence a uma biblioteca que você coordena.'; END IF;

  -- Garde : coordenador d'une biblio détentrice du livre (ou admin réseau).
  SELECT (
    EXISTS (SELECT 1 FROM public.book_holdings h
              JOIN public.user_library_memberships m ON m.library_id = h.library_id
             WHERE h.book_id = p_book_id AND m.user_id = auth.uid()
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) INTO v_authorized;
  IF NOT v_authorized THEN RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca detentora.'; END IF;

  v_kind := CASE
    WHEN p_bucket_name = 'pdf-restrito' THEN 'pdf'
    WHEN ra.mime_type LIKE 'image/%' THEN 'image'
    WHEN ra.mime_type LIKE 'audio/%' THEN 'audio'
    WHEN ra.mime_type LIKE 'video/%' THEN 'video'
    WHEN ra.asset_kind IN ('image','audio','video') THEN ra.asset_kind
    ELSE 'image' END;
  v_title := coalesce(nullif(trim(ra.title), ''), 'Recurso recebido');

  -- ── Export / partage : digital_asset to_review (couche curée) ──────────────
  IF p_mode IN ('export','both') THEN
    INSERT INTO public.digital_assets
      (asset_kind, title, book_id, source_name, attribution_text, source_license_name,
       rights_status, bucket_name, object_path, is_public, mime_type, file_size_bytes, checksum_sha256, notes)
    VALUES
      (v_kind, v_title, p_book_id, coalesce(nullif(trim(ra.source_name), ''), 'AnarBib'),
       ra.attribution_text, ra.source_license_name, 'to_review', p_bucket_name, p_object_path, false,
       coalesce(ra.mime_type, 'application/octet-stream'), ra.file_size_bytes, ra.checksum_sha256,
       'Attaché depuis un fonds reçu (received_asset ' || p_received_asset_id || ') — à vérifier')
    RETURNING id INTO v_asset_id;
  END IF;

  -- ── Lecture locale : book_digital_resources (couche catalogue, même fichier) ─
  IF p_mode IN ('read','both') THEN
    v_rtype := CASE WHEN v_kind = 'pdf' THEN 'pdf_restrito' WHEN v_kind = 'audio' THEN 'audio'
                    WHEN v_kind = 'video' THEN 'video' ELSE 'image' END;
    v_utype := CASE WHEN v_kind = 'pdf' THEN 'leitura_online' WHEN v_kind = 'audio' THEN 'escuta_online'
                    ELSE 'visualizacao_online' END;
    -- rights_status reste NULL : le statut declare par le partenaire appartient
    -- a un autre vocabulaire et n'a pas ete verifie par nous. Il est conserve
    -- en clair dans la justification. (Migration vocabulaire, 2026-08-20.)
    INSERT INTO public.book_digital_resources
      (book_id, resource_type, usage_type, access_scope, status, is_active,
       storage_bucket, storage_path, mime_type, label, source_name, attribution_text,
       rights_status, rights_justification, is_primary, bibliographic_match_validated, notes)
    VALUES
      (p_book_id, v_rtype, v_utype, 'conta_ativa', 'active', true,
       p_bucket_name, p_object_path, coalesce(ra.mime_type, 'application/octet-stream'), v_title,
       nullif(trim(ra.source_name), ''), ra.attribution_text,
       NULL,
       'a verificar: recebido de ' || coalesce(nullif(trim(ra.source_name), ''), 'parceiro')
         || ' — status declarado na origem: '
         || coalesce(nullif(trim(ra.rights_status), ''), 'não informado'),
       false, true,
       'Attaché (lisible local) depuis un fonds reçu (received_asset ' || p_received_asset_id || ')')
    RETURNING id INTO v_resource_id;
  END IF;

  UPDATE ingest.partner_catalog_received_assets
     SET attached_digital_asset_id = v_asset_id, deposit_status = 'attached'
   WHERE id = p_received_asset_id;

  RETURN jsonb_build_object('ok', true, 'asset_id', v_asset_id, 'resource_id', v_resource_id,
    'created', true, 'book_id', p_book_id, 'mode', p_mode,
    'rights_status', CASE WHEN v_asset_id IS NOT NULL THEN 'to_review' ELSE NULL END);
END;
$function$;

-- -----------------------------------------------------------------------------
-- 4. La contrainte, une fois les deux portes fermees
-- -----------------------------------------------------------------------------
alter table public.book_digital_resources
  drop constraint if exists book_digital_resources_rights_status_check;
alter table public.book_digital_resources
  add constraint book_digital_resources_rights_status_check
  check (rights_status is null
         or rights_status in ('dominio_publico', 'cessao_autoral', 'licenca_livre', 'sob_direitos'));

alter table public.book_draft_digital_resources
  drop constraint if exists book_draft_digital_resources_rights_status_check;
alter table public.book_draft_digital_resources
  add constraint book_draft_digital_resources_rights_status_check
  check (rights_status is null
         or rights_status in ('dominio_publico', 'cessao_autoral', 'licenca_livre', 'sob_direitos'));

-- -----------------------------------------------------------------------------
-- 5. Verification — rollback automatique si une valeur echappe encore
-- -----------------------------------------------------------------------------
do $$
declare
  v_hors_vocabulaire int;
  v_sans_justif      int;
begin
  select count(*) into v_hors_vocabulaire
    from (
      select rights_status from public.book_digital_resources
      union all
      select rights_status from public.book_draft_digital_resources
    ) t
   where rights_status is not null
     and rights_status not in ('dominio_publico', 'cessao_autoral', 'licenca_livre', 'sob_direitos');

  if v_hors_vocabulaire > 0 then
    raise exception 'MIGRATION 20260820 : % ligne(s) hors vocabulaire apres normalisation. Rollback automatique.',
      v_hors_vocabulaire;
  end if;

  -- Les lignes issues de `livre_de_direitos` doivent TOUTES porter leur marqueur.
  select count(*) into v_sans_justif
    from public.book_digital_resources
   where rights_status = 'dominio_publico'
     and coalesce(rights_justification, '') not like '%a verificar%'
     and id in (select id from public.book_digital_resources);

  raise notice 'Vocabulaire rights_status ferme. Lignes a verifier (marqueur pose) : %.',
    (select count(*) from public.book_digital_resources
      where coalesce(rights_justification, '') like 'a verificar%')
    + (select count(*) from public.book_draft_digital_resources
        where coalesce(rights_justification, '') like 'a verificar%');
end $$;

commit;

-- =============================================================================
-- Rollback ciblé :
-- =============================================================================
-- begin;
--   alter table public.book_digital_resources
--     drop constraint if exists book_digital_resources_rights_status_check;
--   alter table public.book_draft_digital_resources
--     drop constraint if exists book_draft_digital_resources_rights_status_check;
--   -- Les colonnes rights_justification peuvent rester : elles ne genent rien
--   -- et contiennent desormais de l'information qui n'existe nulle part ailleurs.
-- commit;
-- =============================================================================
