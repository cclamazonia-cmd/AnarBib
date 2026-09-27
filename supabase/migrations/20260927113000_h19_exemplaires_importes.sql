-- =====================================================================
-- H19 — les exemplaires d'un catalogue importé deviennent des exemplaires
-- Date : 2026-09-26, revue et corrections le 27/09 · Backlog v34 H19 · REGISTRE IMP-21 (décisions de Xavier)
--
-- Un export PMB porte ses exemplaires en 995 (UNIMARC ; 852 en MARC21) :
-- code-barres, cote, note, propriétaire, type, public. Depuis H19 l'EF
-- process-partner-catalog-import les lit (correspondance du profil de la
-- bibliothèque, défaut PMB 8.1) et les porte dans normalized_payload.items.
-- Cette migration en fait des exemplaires :
--   1. exemplares.source_item_code (le code d'origine), UNIQUE PAR
--      BIBLIOTHÈQUE — jamais dans une note : c'est la clé du réimport (H21) et
--      de la 995 $f à l'export (H24) ; exemplar_drafts gagne le même champ, le
--      lien vers son brouillon de notice et vers sa ligne importée ;
--      import_profiles.items_mapping porte la correspondance (IMP-21 c) ;
--   2. publish_exemplar_draft : pas avant sa notice, jamais sans bibliothèque,
--      staff de la bibliothèque visée (la garde de tête ne demandait qu'un
--      rôle QUELQUE PART), code d'origine pris = refus dit ; ne réessaie QUE
--      sur une collision de tombo ; une republication dans la même
--      bibliothèque garde son tombo, et le tombo posé revient au brouillon ;
--   3. fn_create_item_drafts_for_batch, appelée par fn_import_promote après le
--      tampon de la bibliothèque ;
--   4. publish_book_draft : les exemplaires importés REMPLACENT l'exemplaire
--      automatique (sinon N+1), reçoivent un tombo du schéma de la
--      bibliothèque (numérotation « B », IMP-21 a) et sont publiés avec la
--      notice ; publish_catalog_batch ne les republie pas ;
--   5. fn_batch_reassign_library les fait suivre ; le rapprochement
--      (fn_create_exemplar_drafts_from_import_rows) crée un brouillon par
--      exemplaire — dépôt compagnon réservé à l'administration du réseau et
--      versé à la destination de la source, code déjà dans la bibliothèque
--      non recréé — et son déclencheur ne défait plus la décision d'une ligne
--      tant qu'un exemplaire du même rapprochement vit ; une ligne rapprochée
--      n'est plus promue (ni l'inverse) ; le rapport de révision gagne
--      `items` (en un passage, 40 problèmes au plus) ;
--   6. les profils d'import portent la correspondance des exemplaires ;
--   7. l'exemplaire importé suit sa notice (corbeille, restauration, lot) et
--      ses liens d'import ne s'écrivent pas par l'API.
-- Revue contradictoire du 26-27/09 (4 lentilles, un sceptique par constat) :
-- corrections intégrées ici, avant tout déploiement.
-- La correspondance statut PMB → politique de circulation attend l'échantillon
-- de DIRA (IMP-21 d) : type, public et statut vont dans la note de provenance.
--
-- Corps des fonctions existantes EXTRAITS de pg_get_functiondef (banc local au
-- md5 de la production, vérifié fonction par fonction le 26/09) et modifiés par
-- ancrages (script du 26/09), jamais retapés.
-- =====================================================================

-- ── 1. Les colonnes ──────────────────────────────────────────────────────
ALTER TABLE public.exemplares ADD COLUMN IF NOT EXISTS source_item_code text;
COMMENT ON COLUMN public.exemplares.source_item_code IS
  'Code de l''exemplaire dans le système d''origine (code-barres PMB, 995 $f ; 852 $p en MARC21). '
  'Unique par bibliothèque. Ce n''est PAS le tombo (numérotation AnarBib, IMP-21 a) : il sert au '
  'réimport qui met à jour (H21) et à l''export (H24).';
CREATE UNIQUE INDEX IF NOT EXISTS exemplares_source_item_code_par_biblio
  ON public.exemplares (library_id, source_item_code) WHERE source_item_code IS NOT NULL;

ALTER TABLE public.exemplar_drafts
  ADD COLUMN IF NOT EXISTS source_item_code text,
  ADD COLUMN IF NOT EXISTS book_draft_id bigint REFERENCES public.book_drafts(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS import_staging_row_id bigint REFERENCES ingest.partner_catalog_staging_rows(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS exemplar_drafts_book_draft_id_idx ON public.exemplar_drafts (book_draft_id);
ALTER TABLE public.exemplar_drafts ADD COLUMN IF NOT EXISTS cancelled_with_record boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN public.exemplar_drafts.cancelled_with_record IS
  'H19 : écarté AVEC sa notice (déclencheur book_drafts_imported_items_follow) ; revient avec elle. Un exemplaire écarté seul reste écarté.';
CREATE INDEX IF NOT EXISTS exemplar_drafts_import_staging_row_id_idx ON public.exemplar_drafts (import_staging_row_id);
-- Le rapport de révision cherche un même code attendu par un autre lot ouvert.
CREATE INDEX IF NOT EXISTS exemplar_drafts_source_item_code_idx
  ON public.exemplar_drafts (target_library_id, source_item_code) WHERE source_item_code IS NOT NULL;
COMMENT ON COLUMN public.exemplar_drafts.book_draft_id IS
  'H19 : brouillon de notice auquel cet exemplaire importé appartient ; publié AVEC elle par publish_book_draft.';
COMMENT ON COLUMN public.exemplar_drafts.import_staging_row_id IS
  'H19 : ligne importée (ingest.partner_catalog_staging_rows) dont vient cet exemplaire.';
COMMENT ON COLUMN public.exemplar_drafts.source_item_code IS
  'H19 : code de l''exemplaire dans le système d''origine ; recopié dans exemplares.source_item_code.';

ALTER TABLE ingest.import_profiles ADD COLUMN IF NOT EXISTS items_mapping jsonb;
ALTER TABLE ingest.import_profiles DROP CONSTRAINT IF EXISTS import_profiles_items_mapping_object;
ALTER TABLE ingest.import_profiles ADD CONSTRAINT import_profiles_items_mapping_object
  CHECK (items_mapping IS NULL OR jsonb_typeof(items_mapping) = 'object');
COMMENT ON COLUMN ingest.import_profiles.items_mapping IS
  'H19 (IMP-21 c) : correspondance des sous-zones d''exemplaire (995 UNIMARC / 852 MARC21) — '
  '{tag, code, call_number, note, owner, item_type, public, status}. NULL = défaut PMB 8.1.';

-- ── 2. publish_exemplar_draft ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.publish_exemplar_draft(p_draft_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_draft public.exemplar_drafts%rowtype;
  v_exemplar_id bigint;
  v_library_id uuid;
  v_bridge record;
  v_resolved_holding_id bigint := null;
  v_resolved_bib_ref text := null;
  v_holding record;
  v_seed_policy text;
  v_final_tombo text;
  v_constraint text;          -- H19
  v_record_status text;       -- H19
  v_existing_library uuid;    -- H19 : l'exemplaire déjà publié (republication)
  v_existing_tombo text;      -- H19
  v_existing_code text;       -- H19
  v_item_code text;           -- H19 : code d'origine qu'aura l'exemplaire
begin
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.' USING HINT = 'error.catalog.staff_only';
  END IF;
  perform public.sync_exemplar_draft_holdings_bridge(p_draft_id);

  select * into v_draft from public.exemplar_drafts where id = p_draft_id;
  if not found then
    raise exception 'Rascunho de exemplar não encontrado: %', p_draft_id;
  end if;
  if v_draft.status = 'cancelled' then
    raise exception 'Este rascunho de exemplar foi descartado.';
  end if;

  -- H19 (26/09/2026, IMP-21) : un exemplaire importé est rattaché à SON
  -- brouillon de notice. Il ne se publie pas avant elle (publish_book_draft le
  -- publie elle-même, dans la détention qu'elle vient de poser : la garde de
  -- révision du lot s'applique ainsi par transitivité).
  if v_draft.book_draft_id is not null then
    select bd.status into v_record_status from public.book_drafts bd where bd.id = v_draft.book_draft_id;
    if v_record_status is distinct from 'published' then
      raise exception 'exemplar_importado_antes_da_ficha' using hint = 'error.publish.item_before_record';
    end if;
    -- Restauré seul depuis la corbeille APRÈS la publication de sa notice, il
    -- n'a pas reçu la référence de la fiche (publish_book_draft n'aligne que
    -- les vivants) : il la prend ici (troisième revue, 27/09).
    if nullif(btrim(coalesce(v_draft.target_bib_ref, '')), '') is null then
      select b.bib_ref into v_draft.target_bib_ref
        from public.book_drafts bd join public.books b on b.id = bd.published_book_id
       where bd.id = v_draft.book_draft_id;
    end if;
  end if;
  -- Un exemplaire venu d'un import (promotion OU rapprochement) ne se publie
  -- jamais sans bibliothèque : le repli sur la bibliothèque principale de qui
  -- publie enverrait le fonds d'une compagne chez qui clique.
  if (v_draft.book_draft_id is not null or v_draft.import_staging_row_id is not null)
     and v_draft.target_library_id is null then
    raise exception 'exemplar_importado_sem_biblioteca' using hint = 'error.publish.item_without_library';
  end if;

  v_library_id := v_draft.target_library_id;

  if v_draft.target_holding_id is not null then
    select h.id, h.library_id,
           coalesce(nullif(trim(h.local_bib_ref), ''), b.bib_ref) as reference_code
      into v_holding
      from public.book_holdings h
      left join public.books b on b.id = h.book_id
     where h.id = v_draft.target_holding_id
     limit 1;
    if found then
      if v_library_id is not null and v_holding.library_id is distinct from v_library_id then
        raise exception 'O holding % pertence a outra biblioteca do que a biblioteca-alvo do rascunho.', v_draft.target_holding_id
          USING ERRCODE = '23514', HINT = 'error.catalog.holding_library_mismatch';
      end if;
      v_resolved_holding_id := v_holding.id;
      v_library_id := v_holding.library_id;
      v_resolved_bib_ref := v_holding.reference_code;
    end if;
  end if;

  if v_library_id is null and v_draft.published_exemplar_id is not null then
    select e.library_id into v_library_id
      from public.exemplares e where e.id = v_draft.published_exemplar_id;
  end if;

  if v_library_id is null then
    select ulm.library_id into v_library_id
      from public.user_library_memberships ulm
     where ulm.user_id = auth.uid()
       and ulm.status = 'active'
       and ulm.role = any (array['librarian'::text, 'coordenador'::text])   -- H19
     order by ulm.is_primary desc nulls last, ulm.library_id
     limit 1;
  end if;

  if v_library_id is null then
    raise exception 'Nenhuma biblioteca ativa/principal encontrada para o usuário atual.';
  end if;

  -- H19 (27/09/2026, revue) : publier un exemplaire, c'est écrire dans le
  -- fonds d'une bibliothèque. La garde de tête ne demandait qu'un rôle de
  -- catalogage QUELQUE PART ; seule fn_next_tombo vérifiait l'appartenance,
  -- et un brouillon qui portait déjà son tombo la sautait. Même règle que
  -- fn_next_tombo et publish_book_draft : staff de la bibliothèque visée — et,
  -- pour une republication, de celle qui détient l'exemplaire aujourd'hui —
  -- ou administration du réseau. Placée AVANT le test du code d'origine : il
  -- ne renseigne pas sur le fonds d'une autre bibliothèque.
  if v_draft.published_exemplar_id is not null then
    select e.library_id, e.tombo, e.source_item_code into v_existing_library, v_existing_tombo, v_existing_code
      from public.exemplares e where e.id = v_draft.published_exemplar_id;
  end if;
  if auth.uid() is not null and not public.fn_caller_is_network_admin()
     and (not public.user_has_library_staff_role(auth.uid(), v_library_id)
          or (v_existing_library is not null
              and not public.user_has_library_staff_role(auth.uid(), v_existing_library))) then
    raise exception 'Ce rascunho est rattache a une bibliotheque dont vous n''etes pas membre (%).', v_library_id
      using hint = 'error.publish.other_library';
  end if;

  if v_resolved_holding_id is null then
    select * into v_bridge
      from public.resolve_library_holding_bridge(v_library_id, v_draft.target_bib_ref)
     limit 1;
    if found then
      v_resolved_holding_id := v_bridge.holding_id;
      v_resolved_bib_ref := coalesce(v_bridge.local_bib_ref, v_bridge.resolved_bib_ref);
    else
      v_resolved_bib_ref := nullif(trim(v_draft.target_bib_ref), '');
    end if;
  end if;

  select case when b.loanable then 'ambos' else 'consulta' end
    into v_seed_policy
    from public.book_holdings h
    join public.books b on b.id = h.book_id
   where h.id = v_resolved_holding_id;
  v_seed_policy := coalesce(v_seed_policy, 'consulta');

  -- Chantier 14 : tombo final. Si le brouillon n'en porte pas, on génère le
  -- prochain libre via fn_next_tombo (v_library_id garanti non-null ici).
  v_final_tombo := nullif(btrim(coalesce(v_draft.tombo, '')), '');
  -- H19 : republier un exemplaire déjà publié, dans la MÊME bibliothèque, garde
  -- son tombo (celui de l'étiquette collée) ; un brouillon importé n'en porte
  -- pas, et fn_next_tombo en aurait tiré un neuf à chaque passage. Un
  -- changement de bibliothèque (#cross-lib-reassign) renumérote, comme avant.
  if v_final_tombo is null and v_draft.published_exemplar_id is not null
     and v_existing_library is not distinct from v_library_id then
    v_final_tombo := nullif(btrim(coalesce(v_existing_tombo, '')), '');
  end if;
  if v_final_tombo is null then
    v_final_tombo := public.fn_next_tombo(v_library_id);
  end if;

  -- H19 : le code d'origine (code-barres PMB…) est unique PAR bibliothèque.
  -- Collision dite, jamais contournée : l'index partiel lèverait sinon une
  -- violation d'unicité que le repli du tombo ci-dessous prendrait pour la sienne.
  -- Le code contrôlé est celui qu'aura l'exemplaire : celui du brouillon, sinon
  -- celui qu'il porte déjà (un exemplaire importé réattribué à une autre
  -- bibliothèque l'emporte avec lui : 23505 brut sinon).
  v_item_code := coalesce(nullif(btrim(coalesce(v_draft.source_item_code, '')), ''), v_existing_code);
  if v_item_code is not null
     and exists (select 1 from public.exemplares e
                  where e.library_id = v_library_id
                    and e.source_item_code = v_item_code
                    and e.id is distinct from v_draft.published_exemplar_id) then
    raise exception 'codigo_de_origem_ja_usado: %', v_item_code
      using hint = 'error.publish.source_item_code_taken';
  end if;

  if v_draft.published_exemplar_id is null then
    -- #fix-tombo-stale (15/08/2026) : le tombo figé dans le brouillon peut être
    -- devenu obsolète (mutirão, double-clic, préfixe partagé). Sur collision
    -- d'unicité (forcément le tombo — seul index unique hors PK), on régénère un
    -- tombo libre et on réessaie une fois. fn_next_tombo est global-safe.
    begin
      insert into public.exemplares (
        bib_ref, tombo, shelf_location,
        label_title_override, label_author_override, label_cdd_override, label_note,
        notes, library_id, holding_id,
        circulation_policy, visibility,
        acquisition_mode, acquisition_date, provenance_note, source_library, source_item_code,
        created_at, updated_at
      ) values (
        coalesce(v_resolved_bib_ref, v_draft.target_bib_ref),
        v_final_tombo, v_draft.shelf_location,
        v_draft.label_title_override, v_draft.label_author_override, v_draft.label_cdd_override, v_draft.label_note,
        v_draft.notes, v_library_id, v_resolved_holding_id,
        coalesce(v_draft.circulation_policy, v_seed_policy),
        coalesce(v_draft.visibility, 'public'),
        v_draft.acquisition_mode, v_draft.acquisition_date, v_draft.provenance_note, v_draft.source_library, v_draft.source_item_code,
        now(), now()
      )
      returning id into v_exemplar_id;
    exception when unique_violation then
      -- H19 : ne réessayer que sur une collision de TOMBO ; toute autre
      -- violation d'unicité remonte telle quelle.
      get stacked diagnostics v_constraint = constraint_name;
      if v_constraint is distinct from 'exemplares_unique_tombo' then
        raise;
      end if;
      v_final_tombo := public.fn_next_tombo(v_library_id);
      insert into public.exemplares (
        bib_ref, tombo, shelf_location,
        label_title_override, label_author_override, label_cdd_override, label_note,
        notes, library_id, holding_id,
        circulation_policy, visibility,
        acquisition_mode, acquisition_date, provenance_note, source_library, source_item_code,
        created_at, updated_at
      ) values (
        coalesce(v_resolved_bib_ref, v_draft.target_bib_ref),
        v_final_tombo, v_draft.shelf_location,
        v_draft.label_title_override, v_draft.label_author_override, v_draft.label_cdd_override, v_draft.label_note,
        v_draft.notes, v_library_id, v_resolved_holding_id,
        coalesce(v_draft.circulation_policy, v_seed_policy),
        coalesce(v_draft.visibility, 'public'),
        v_draft.acquisition_mode, v_draft.acquisition_date, v_draft.provenance_note, v_draft.source_library, v_draft.source_item_code,
        now(), now()
      )
      returning id into v_exemplar_id;
    end;
  else
    update public.exemplares
       set bib_ref = coalesce(v_resolved_bib_ref, v_draft.target_bib_ref),
           tombo = coalesce(v_final_tombo, public.exemplares.tombo),
           shelf_location = v_draft.shelf_location,
           label_title_override = v_draft.label_title_override,
           label_author_override = v_draft.label_author_override,
           label_cdd_override = v_draft.label_cdd_override,
           label_note = v_draft.label_note,
           notes = v_draft.notes,
           library_id = coalesce(v_library_id, public.exemplares.library_id),
           holding_id = coalesce(v_resolved_holding_id, public.exemplares.holding_id),
           circulation_policy = coalesce(v_draft.circulation_policy, public.exemplares.circulation_policy),
           visibility = coalesce(v_draft.visibility, public.exemplares.visibility),
           acquisition_mode = coalesce(v_draft.acquisition_mode, public.exemplares.acquisition_mode),
           acquisition_date = coalesce(v_draft.acquisition_date, public.exemplares.acquisition_date),
           provenance_note  = coalesce(v_draft.provenance_note,  public.exemplares.provenance_note),
           source_library   = coalesce(v_draft.source_library,   public.exemplares.source_library),
           source_item_code = coalesce(v_draft.source_item_code, public.exemplares.source_item_code),
           updated_at = now()
     where id = v_draft.published_exemplar_id
    returning id into v_exemplar_id;
  end if;

  update public.exemplar_drafts
     set published_exemplar_id = v_exemplar_id,
         tombo = v_final_tombo,     -- H19 : le tombo réellement posé (republication, formulaire)
         target_library_id = coalesce(v_library_id, target_library_id),
         target_holding_id = coalesce(v_resolved_holding_id, target_holding_id),
         target_bib_ref = coalesce(v_resolved_bib_ref, target_bib_ref),
         status = 'published',
         label_status = 'ready',
         updated_by = coalesce(v_draft.updated_by, auth.uid()),
         updated_at = now()
   where id = p_draft_id;

  return v_exemplar_id;
end;
$function$;


-- ── 3. La création des brouillons d'exemplaires à la promotion ───────────
CREATE OR REPLACE FUNCTION ingest.fn_create_item_drafts_for_batch(p_batch_id bigint, p_created_by uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'ingest', 'public', 'auth'
AS $function$
DECLARE
  v_actor uuid := coalesce(p_created_by, auth.uid());
  v_n integer := 0;
  rec record;
  it jsonb;
BEGIN
  -- Pour chaque ligne importée devenue brouillon de notice dans ce lot : un
  -- brouillon d'exemplaire par exemplaire du fichier (normalized_payload.items,
  -- écrit par process-partner-catalog-import). Sans tombo (numérotation « B » :
  -- il sera pris dans le schéma de la bibliothèque à la publication), avec le
  -- code d'origine (dans SA colonne, jamais dans une note : IMP-21 b), la
  -- cote, la note, le propriétaire ; type, public et statut dans la note de
  -- provenance (IMP-21 d). Idempotent : une notice qui a déjà ses exemplaires
  -- n'en reçoit pas d'autres.
  FOR rec IN
    SELECT m.staging_row_id, m.draft_id, m.run_id, sr.row_no, sr.normalized_payload,
           d.owner_library_id, r.original_filename, s.partner_name
      FROM ingest.partner_catalog_row_to_draft m
      JOIN ingest.partner_catalog_staging_rows sr ON sr.id = m.staging_row_id
      JOIN public.book_drafts d ON d.id = m.draft_id
      JOIN ingest.partner_catalog_import_runs r ON r.id = m.run_id
      LEFT JOIN ingest.partner_catalog_sources s ON s.id = r.source_id
     WHERE m.batch_id = p_batch_id
       AND d.status IN ('draft', 'ready')
       AND jsonb_typeof(sr.normalized_payload->'items') = 'array'
       AND jsonb_array_length(sr.normalized_payload->'items') > 0
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x WHERE x.book_draft_id = m.draft_id)
     ORDER BY sr.row_no, m.staging_row_id
  LOOP
    FOR it IN SELECT value FROM jsonb_array_elements(rec.normalized_payload->'items') LOOP
      INSERT INTO public.exemplar_drafts (
        batch_id, action, status, label_status,
        book_draft_id, import_staging_row_id, target_library_id,
        source_item_code, shelf_location, notes, source_library, provenance_note,
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
        v_actor, v_actor
      );
      v_n := v_n + 1;
    END LOOP;
  END LOOP;
  RETURN v_n;
END;
$function$;
-- Fonction ingest : fermée à authenticated (ingest_ferme_tests) ; appelée par
-- fn_import_promote (SECURITY DEFINER, propriétaire).
REVOKE EXECUTE ON FUNCTION ingest.fn_create_item_drafts_for_batch(bigint, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_create_item_drafts_for_batch(bigint, uuid) TO service_role;

-- ── 4. publish_book_draft et publish_catalog_batch ──────────────────────
CREATE OR REPLACE FUNCTION public.publish_book_draft(p_draft_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_draft public.book_drafts%rowtype;
  v_book_id bigint;
  v_isbn_norm text;
  v_existing_book_id bigint;
  v_holding_id bigint;
  v_library_id uuid;
  v_circ_policy text;
  v_auto_tombo text;                         -- #tombo-serie (17/06)
  v_copies int;                              -- #copies (17/08) : nb d'exemplaires initiaux
  v_i int;
  v_linked int := 0;                         -- H19 : exemplaires importés rattachés
  v_x record;
  v_valid_types text[] := ARRAY[
    'livro','periodico','tract','cartaz','audio','audiovisual',
    'recurso_digital','dossie','tese','artigo','relatorio','zine'
  ];
begin
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.' USING HINT = 'error.catalog.staff_only';
  END IF;
  select * into v_draft from public.book_drafts where id = p_draft_id;
  if not found then
    raise exception 'rascunho_nao_encontrado' using hint = 'error.publish.draft_not_found';
  end if;
  if v_draft.status = 'cancelled' then
    raise exception 'rascunho_descartado' using hint = 'error.publish.draft_cancelled';
  end if;

  -- 05/09/2026 : un lot ne d'un import ne se publie qu'apres une revision
  -- approuvee par l'administration du reseau (catalog_batch_reviews).
  -- publish_catalog_batch passe ici pour chaque brouillon : la garde le couvre.
  if v_draft.batch_id is not null
     and public.fn_batch_is_imported(v_draft.batch_id)
     and public.fn_batch_review_status(v_draft.batch_id) is distinct from 'approved' then
    raise exception 'lote_importado_sem_revisao' using hint = 'error.publish.review_required';
  end if;

  if v_draft.titulo is null or btrim(v_draft.titulo) = '' then
    raise exception 'titulo_obrigatorio' using hint = 'error.publish.titulo_required';
  end if;
  if v_draft.bib_ref is null or btrim(v_draft.bib_ref) = '' then
    raise exception 'bib_ref_obrigatoria' using hint = 'error.publish.bib_ref_required';
  end if;
  if v_draft.tipo_material is null or btrim(v_draft.tipo_material) = '' then
    raise exception 'tipo_material_obrigatorio' using hint = 'error.publish.tipo_material_required';
  end if;
  if lower(v_draft.tipo_material) <> ALL(v_valid_types) then
    raise exception 'tipo_material_invalido' using hint = 'error.publish.tipo_material_invalid';
  end if;

  select b.id into v_existing_book_id
    from public.books b
   where b.bib_ref = v_draft.bib_ref
     and (v_draft.published_book_id is null or b.id <> v_draft.published_book_id)
   limit 1;
  if v_existing_book_id is not null then
    raise exception 'bib_ref_duplicado: %', v_existing_book_id
      using errcode = 'P0001',
            hint = format('Ja existe uma ficha publicada com a mesma referencia bibliografica %s (ficha %s). Altere a bib_ref ou verifique a ficha existente.', v_draft.bib_ref, v_existing_book_id);
  end if;
  v_existing_book_id := null;

  if v_draft.published_book_id is null then
    v_isbn_norm := regexp_replace(upper(coalesce(v_draft.isbn, '')), '[^0-9X]', '', 'g');
    if v_isbn_norm <> '' then
      select b.id into v_existing_book_id
        from public.books b
       where regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g') = v_isbn_norm
       limit 1;
      if v_existing_book_id is not null then
        raise exception 'isbn_duplicado: %', v_existing_book_id
          using errcode = 'P0001',
                hint = format('Ja existe uma ficha publicada com o mesmo ISBN (ficha %s). Revise o ISBN ou adicione um exemplar a ficha existente.', v_existing_book_id);
      end if;
    end if;

    insert into public.books (
      work_id,
      cdd, autor, titulo, ano, editora, bib_ref, loanable,
      subtitulo, edicao, local_publicacao, isbn, issn, idioma, paginas,
      notas, tipo_material, cover_object_path, marc_json, catalog_source,
      created_by, updated_by, updated_at, last_cataloged_at,
      serial_id,                             -- #périodiques P7 (27/08)
      titulo_periodico, volume, numero, fasciculo, data_edicao,
      periodicidade, colecao, acquisition_mode, acquisition_date,
      owner_library, holder_library, partner_source, source_record_id,
      source_record_url, import_format, import_method, provenance_note,
      mutualization_status, source_label,
      tract_campaign, emitter_org, approximate_date, diffusion_place,
      recto_verso, physical_format, print_technique, physical_state,
      audio_duration, audio_support, audio_format, audio_language,
      audio_participants, audio_recording_type,
      audiovisual_duration, audiovisual_support, audiovisual_language,
      audiovisual_director, audiovisual_participants, audiovisual_subtitles,
      audiovisual_access_note,
      digital_native_url, digital_native_access, digital_native_restriction,
      digital_native_usage, digital_native_file_note,
      dossier_scope, dossier_period, dossier_organizations, dossier_context,
      distribuidora, gravadora, tese_university, tese_advisor,
      artigo_source, artigo_volume, artigo_issue, artigo_pages,
      relatorio_org, relatorio_recipient, relatorio_internal_notes,
      zine_print_run, zine_technique, zine_format,
      subjects
    )
    values (
      v_draft.work_id,                       -- #œuvre (17/08) : NULL -> fn_books_ensure_work crée une œuvre neuve
      v_draft.cdd, v_draft.autor, v_draft.titulo, v_draft.ano,
      v_draft.editora, v_draft.bib_ref, coalesce(v_draft.loanable, true),
      v_draft.subtitulo, v_draft.edicao, v_draft.local_publicacao,
      v_draft.isbn, v_draft.issn, v_draft.idioma, v_draft.paginas,
      v_draft.notas, v_draft.tipo_material, v_draft.cover_object_path,
      coalesce(v_draft.marc_json, '{}'::jsonb), 'catalogacao',
      coalesce(v_draft.created_by, auth.uid()),
      coalesce(v_draft.updated_by, auth.uid()), now(), now(),
      v_draft.serial_id,                     -- #périodiques P7 (27/08)
      v_draft.titulo_periodico, v_draft.volume, v_draft.numero,
      v_draft.fasciculo, v_draft.data_edicao, v_draft.periodicidade,
      v_draft.colecao, v_draft.acquisition_mode, v_draft.acquisition_date,
      v_draft.owner_library, v_draft.holder_library, v_draft.partner_source,
      v_draft.source_record_id, v_draft.source_record_url,
      v_draft.import_format, v_draft.import_method, v_draft.provenance_note,
      v_draft.mutualization_status, v_draft.source_label,
      v_draft.tract_campaign, v_draft.emitter_org, v_draft.approximate_date,
      v_draft.diffusion_place, v_draft.recto_verso, v_draft.physical_format,
      v_draft.print_technique, v_draft.physical_state,
      v_draft.audio_duration, v_draft.audio_support, v_draft.audio_format,
      v_draft.audio_language, v_draft.audio_participants,
      v_draft.audio_recording_type,
      v_draft.audiovisual_duration, v_draft.audiovisual_support,
      v_draft.audiovisual_language, v_draft.audiovisual_director,
      v_draft.audiovisual_participants, v_draft.audiovisual_subtitles,
      v_draft.audiovisual_access_note,
      v_draft.digital_native_url, v_draft.digital_native_access,
      v_draft.digital_native_restriction, v_draft.digital_native_usage,
      v_draft.digital_native_file_note,
      v_draft.dossier_scope, v_draft.dossier_period,
      v_draft.dossier_organizations, v_draft.dossier_context,
      v_draft.distribuidora, v_draft.gravadora, v_draft.tese_university, v_draft.tese_advisor,
      v_draft.artigo_source, v_draft.artigo_volume, v_draft.artigo_issue,
      v_draft.artigo_pages, v_draft.relatorio_org, v_draft.relatorio_recipient,
      v_draft.relatorio_internal_notes,
      v_draft.zine_print_run, v_draft.zine_technique, v_draft.zine_format,
      v_draft.subjects
    )
    returning id into v_book_id;

    -- #biblio-choisie (17/08, elargi le 29/08/2026). La regle voulue : choisir
    -- explicitement la bibliotheque de destination est reserve a l'admin reseau.
    -- Elle etait posee sur initial_copies_library_id SEULEMENT, alors que
    -- owner_library_id est lu AVANT lui, decide donc en premier, et se modifie
    -- librement par toute personne qui catalogue (policy ALL sans portee de
    -- bibliotheque, UPDATE sur les 103 colonnes). La regle etait donc appliquee
    -- sur un champ et ouverte sur celui qui a la priorite.
    v_library_id := v_draft.owner_library_id;

    -- Publier dans le catalogue d'une bibliotheque, c'est y creer un holding et
    -- un exemplaire avec un tombo pris dans SA serie : on ne le fait pas au nom
    -- d'un collectif dont on n'est pas membre.
    if v_library_id is not null
       and not public.fn_caller_is_network_admin()
       and not exists (
         select 1 from public.user_library_memberships ulm
          where ulm.user_id = auth.uid()
            and ulm.status = 'active'
            and ulm.role = any (array['librarian'::text, 'coordenador'::text])
            and ulm.library_id = v_library_id
       ) then
      raise exception
        'Ce rascunho est rattache a une bibliotheque dont vous n''etes pas membre (%).', v_library_id
        using hint = 'error.publish.other_library';
    end if;

    -- La regle de resolution vit desormais dans UNE fonction, appelee ici et
    -- par la vue qui l'affiche a l'ecran. Deux copies d'une meme regle
    -- derivent : ce depot en a paye assez pour ne pas recommencer.
    if v_library_id is null then
      v_library_id := public.fn_book_draft_destination_library(p_draft_id);
    end if;

    -- L'override admin reste le seul chemin pour cibler une autre bibliotheque.
    -- H19 (27/09/2026, revue) : une notice qui porte des exemplaires importés
    -- les publie là où ils ont été attribués (tampon, réattribution du lot) ;
    -- le choix « exemplaires initiaux » de l'écran ne les sépare pas d'elle.
    if v_draft.initial_copies_library_id is not null and public.fn_caller_is_network_admin()
       and not exists (select 1 from public.exemplar_drafts x
                        where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')) then
      v_library_id := v_draft.initial_copies_library_id;
    end if;

    -- H19 : les exemplaires importés vont dans la bibliothèque qui leur a été
    -- DONNÉE (tampon à la promotion, ou réattribution par l'administration),
    -- jamais dans celle que le repli ci-dessus déduit de qui publie : c'est
    -- ainsi que le fonds d'une compagne non admise partirait chez qui clique
    -- (vu au banc le 26/09, suite import_exemplaires T6). Sans bibliothèque :
    -- refus ; bibliothèque différente de celle de la notice : refus.
    if exists (select 1 from public.exemplar_drafts x
                where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')
                  and x.target_library_id is null) then
      raise exception 'exemplares_importados_sem_biblioteca'
        using hint = 'error.publish.items_without_library';
    end if;
    if exists (select 1 from public.exemplar_drafts x
                where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')
                  and x.target_library_id is distinct from v_library_id) then
      raise exception 'exemplares_importados_de_outra_biblioteca'
        using hint = 'error.publish.items_library_mismatch';
    end if;

    if v_library_id is not null then
      v_circ_policy := case when coalesce(v_draft.loanable, true) then 'emprestavel' else 'consulta' end;
      insert into public.book_holdings (book_id, library_id)
      values (v_book_id, v_library_id)
      on conflict (book_id, library_id) do update set updated_at = now()
      returning id into v_holding_id;

      -- #copies (17/08) : N exemplaires (défaut 1, borné 1..50). fn_next_tombo,
      -- appelée en boucle dans la même transaction, voit ses propres INSERT et
      -- renvoie des tombos séquentiels distincts (+ verrou d'avis par préfixe).
      -- H19 : les exemplaires du fichier importé REMPLACENT l'exemplaire
      -- automatique (sinon N importés + 1 automatique). Ils sont publiés plus
      -- bas, une fois la notice marquée publiée.
      select count(*) into v_linked
        from public.exemplar_drafts x
       where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready');
      v_copies := case when v_linked > 0 then 0
                       else greatest(1, least(coalesce(v_draft.initial_copies, 1), 50)) end;
      for v_i in 1..v_copies loop
        begin
          v_auto_tombo := public.fn_next_tombo(v_library_id);
        exception when others then
          -- Pas de tombo_pattern : repli sur bib_ref, suffixé pour éviter la
          -- collision d'unicité globale au-delà du 1er exemplaire.
          v_auto_tombo := case when v_i = 1 then v_draft.bib_ref
                               else v_draft.bib_ref || '-' || v_i::text end;
        end;
        if v_auto_tombo is null or btrim(v_auto_tombo) = '' then
          v_auto_tombo := case when v_i = 1 then v_draft.bib_ref
                               else v_draft.bib_ref || '-' || v_i::text end;
        end if;
        insert into public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
        values (v_draft.bib_ref, v_auto_tombo, v_library_id, v_holding_id, v_circ_policy, 'public');
      end loop;

      perform public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[v_holding_id]);
    end if;

  else
    -- H19 : les exemplaires importés ne se rattachent qu'à une notice CRÉÉE
    -- par la publication (l'import ne produit que des brouillons 'create').
    if exists (select 1 from public.exemplar_drafts x
                where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')) then
      raise exception 'exemplares_importados_em_atualizacao'
        using hint = 'error.publish.items_on_update';
    end if;
    update public.books
    set
      work_id = coalesce(v_draft.work_id, work_id),
      cdd = v_draft.cdd, autor = v_draft.autor, titulo = v_draft.titulo,
      ano = v_draft.ano, editora = v_draft.editora, bib_ref = v_draft.bib_ref,
      loanable = coalesce(v_draft.loanable, true),
      subtitulo = v_draft.subtitulo, edicao = v_draft.edicao,
      local_publicacao = v_draft.local_publicacao,
      isbn = v_draft.isbn, issn = v_draft.issn, idioma = v_draft.idioma,
      paginas = v_draft.paginas, notas = v_draft.notas,
      tipo_material = v_draft.tipo_material,
      cover_object_path = v_draft.cover_object_path,
      marc_json = coalesce(v_draft.marc_json, '{}'::jsonb),
      updated_by = coalesce(v_draft.updated_by, auth.uid()),
      updated_at = now(), last_cataloged_at = now(),
      -- #périodiques P7b (27/08) : coalesce, comme work_id juste au-dessus.
      -- Un brouillon antérieur à la colonne porte NULL ; l'écrire tel quel
      -- EFFAÇAIT le rattachement à chaque republication, en silence.
      serial_id = coalesce(v_draft.serial_id, serial_id),
      titulo_periodico = v_draft.titulo_periodico,
      volume = v_draft.volume, numero = v_draft.numero,
      fasciculo = v_draft.fasciculo, data_edicao = v_draft.data_edicao,
      periodicidade = v_draft.periodicidade, colecao = v_draft.colecao,
      acquisition_mode = v_draft.acquisition_mode,
      acquisition_date = v_draft.acquisition_date,
      owner_library = v_draft.owner_library, holder_library = v_draft.holder_library,
      partner_source = v_draft.partner_source,
      source_record_id = v_draft.source_record_id,
      source_record_url = v_draft.source_record_url,
      import_format = v_draft.import_format, import_method = v_draft.import_method,
      provenance_note = v_draft.provenance_note,
      mutualization_status = v_draft.mutualization_status,
      source_label = v_draft.source_label,
      tract_campaign = v_draft.tract_campaign, emitter_org = v_draft.emitter_org,
      approximate_date = v_draft.approximate_date,
      diffusion_place = v_draft.diffusion_place, recto_verso = v_draft.recto_verso,
      physical_format = v_draft.physical_format,
      print_technique = v_draft.print_technique,
      physical_state = v_draft.physical_state,
      audio_duration = v_draft.audio_duration, audio_support = v_draft.audio_support,
      audio_format = v_draft.audio_format, audio_language = v_draft.audio_language,
      audio_participants = v_draft.audio_participants,
      audio_recording_type = v_draft.audio_recording_type,
      audiovisual_duration = v_draft.audiovisual_duration,
      audiovisual_support = v_draft.audiovisual_support,
      audiovisual_language = v_draft.audiovisual_language,
      audiovisual_director = v_draft.audiovisual_director,
      audiovisual_participants = v_draft.audiovisual_participants,
      audiovisual_subtitles = v_draft.audiovisual_subtitles,
      audiovisual_access_note = v_draft.audiovisual_access_note,
      digital_native_url = v_draft.digital_native_url,
      digital_native_access = v_draft.digital_native_access,
      digital_native_restriction = v_draft.digital_native_restriction,
      digital_native_usage = v_draft.digital_native_usage,
      digital_native_file_note = v_draft.digital_native_file_note,
      dossier_scope = v_draft.dossier_scope, dossier_period = v_draft.dossier_period,
      dossier_organizations = v_draft.dossier_organizations,
      dossier_context = v_draft.dossier_context,
      distribuidora = v_draft.distribuidora, gravadora = v_draft.gravadora,
      tese_university = v_draft.tese_university, tese_advisor = v_draft.tese_advisor,
      artigo_source = v_draft.artigo_source, artigo_volume = v_draft.artigo_volume,
      artigo_issue = v_draft.artigo_issue, artigo_pages = v_draft.artigo_pages,
      relatorio_org = v_draft.relatorio_org,
      relatorio_recipient = v_draft.relatorio_recipient,
      relatorio_internal_notes = v_draft.relatorio_internal_notes,
      zine_print_run = v_draft.zine_print_run,
      zine_technique = v_draft.zine_technique, zine_format = v_draft.zine_format,
      subjects = v_draft.subjects
    where id = v_draft.published_book_id
    returning id into v_book_id;
  end if;

  update public.book_drafts
  set published_book_id = v_book_id, status = 'published',
      updated_by = coalesce(v_draft.updated_by, auth.uid()), updated_at = now()
  where id = p_draft_id;

  -- H19 : publier les exemplaires importés rattachés, dans la détention qui
  -- vient d'être posée ; chacun reçoit un tombo du schéma de SA bibliothèque
  -- (IMP-21 a) et garde son code d'origine.
  if v_linked > 0 then
    update public.exemplar_drafts x
       set target_library_id = v_library_id,
           target_holding_id = v_holding_id,
           target_bib_ref    = v_draft.bib_ref,
           updated_at        = now()
     where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready');
    for v_x in
      select x.id from public.exemplar_drafts x
       where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')
       order by x.id
    loop
      perform public.publish_exemplar_draft(v_x.id);
    end loop;
    perform public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[v_holding_id]);
  end if;

  perform public.publish_book_draft_digital_resources(p_draft_id, v_book_id);

  return v_book_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.publish_catalog_batch(p_batch_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_books integer := 0;
  v_authors integer := 0;
  v_exemplars integer := 0;
  r record;
begin
  -- #79 RBAC : publication reservee au staff de catalogage (librarian/coordenador).
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.' USING HINT = 'error.catalog.staff_only';
  END IF;
  if not exists (
    select 1
    from public.catalog_batches
    where id = p_batch_id
      and status = 'open'
  ) then
    raise exception 'Lote inválido ou já fechado: %', p_batch_id;
  end if;

  for r in
    select id
    from public.book_drafts
    where batch_id = p_batch_id
      and status in ('draft','ready')
  loop
    perform public.publish_book_draft(r.id);
    v_books := v_books + 1;
  end loop;

  for r in
    select id
    from public.author_drafts
    where batch_id = p_batch_id
      and status in ('draft','ready')
  loop
    perform public.publish_author_draft(r.id);
    v_authors := v_authors + 1;
  end loop;

  for r in
    select id
    from public.exemplar_drafts
    where batch_id = p_batch_id
      and status in ('draft','ready')
      -- H19 : un exemplaire importé se publie AVEC sa notice (publish_book_draft) ;
      -- ceux d'une notice écartée restent en brouillon, ils ne font pas échouer le lot.
      and book_draft_id is null
  loop
    perform public.publish_exemplar_draft(r.id);
    v_exemplars := v_exemplars + 1;
  end loop;

  update public.catalog_batches
  set
    status = 'published',
    published_at = now(),
    updated_at = now(),
    published_by = auth.uid()
  where id = p_batch_id;

  return jsonb_build_object(
    'books_published', v_books,
    'authors_published', v_authors,
    'exemplars_published', v_exemplars
  );
end;
$function$;

-- ── 5. Promotion, réattribution, rapprochement, révision ────────────────
CREATE OR REPLACE FUNCTION public.fn_import_promote(p_run_id bigint, p_match_statuses text[] DEFAULT NULL::text[], p_editorial_decisions text[] DEFAULT ARRAY['accept_new'::text, 'accept_duplicate'::text], p_batch_name text DEFAULT NULL::text, p_batch_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth'
AS $function$
DECLARE
  v_actor public.my_access%rowtype;
  v_run_library_id uuid;
  v_source_kind text;
  v_destination uuid;
  v_owner uuid;
  v_result jsonb;
  v_batch_id bigint;
  v_stamped integer := 0;
  v_items integer := 0;       -- H19
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  SELECT r.library_id, s.source_kind, s.destination_library_id
    INTO v_run_library_id, v_source_kind, v_destination
  FROM ingest.partner_catalog_import_runs r
  LEFT JOIN ingest.partner_catalog_sources s ON s.id = r.source_id
  WHERE r.id = p_run_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  -- Meme message que « introuvable » (B14, oracle d'existence, cf. fn_import_create).
  IF v_run_library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  -- 04/09/2026 : un lot venu d'un depot compagnon n'entre dans la file de
  -- catalogage que par l'administration du reseau (cf. en-tete).
  IF v_source_kind IN ('partner_deposit', 'oai_pmh') AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Deposito de catalogo companheiro reservado a administracao da rede.'
      USING HINT = 'error.import.deposit_admin_only';
  END IF;

  v_result := ingest.fn_bulk_create_book_drafts_from_run(
    p_run_id              := p_run_id,
    p_match_statuses      := p_match_statuses,
    p_editorial_decisions := p_editorial_decisions,
    p_batch_name          := p_batch_name,
    p_batch_notes         := p_batch_notes,
    p_created_by          := v_actor.user_id
  );

  -- 15/09/2026 : la biblio proprietaire se tamponne ICI, pas au repli de la
  -- publication. Catalogue propre (own_catalog, manual_upload, zotero_*,
  -- institutional_lookup) : la biblio du run, qui detient les livres. Depot
  -- de compagne / entrepot OAI : la destination declaree sur la source —
  -- rien si elle n'est pas encore connue (compagne non admise), et l'ecran
  -- le montre (« sans bibliotheque ») ; fn_batch_reassign_library fait le
  -- reste le jour de l'admission.
  v_batch_id := nullif(v_result->>'batch_id', '')::bigint;
  IF v_batch_id IS NOT NULL THEN
    v_owner := CASE
                 WHEN v_source_kind IN ('partner_deposit', 'oai_pmh') THEN v_destination
                 ELSE v_run_library_id
               END;
    IF v_owner IS NOT NULL THEN
      UPDATE public.book_drafts d
         SET owner_library_id = l.id,
             owner_library    = l.name
        FROM public.libraries l
       WHERE l.id = v_owner
         AND d.batch_id = v_batch_id
         AND d.owner_library_id IS NULL;
      GET DIAGNOSTICS v_stamped = ROW_COUNT;
    END IF;
  END IF;

  -- H19 (IMP-21) : les exemplaires du fichier (normalized_payload.items)
  -- deviennent des brouillons d'exemplaires rattachés à leur brouillon de
  -- notice — APRÈS le tampon, dont ils héritent la bibliothèque.
  IF v_batch_id IS NOT NULL THEN
    v_items := ingest.fn_create_item_drafts_for_batch(v_batch_id, v_actor.user_id);
  END IF;

  RETURN v_result || jsonb_build_object(
    'owner_library_id', v_owner,
    'owner_stamped', v_stamped,
    'items_created', v_items
  );
END;
$function$;

CREATE OR REPLACE FUNCTION ingest.fn_bulk_create_book_drafts_from_run(p_run_id bigint, p_match_statuses text[] DEFAULT NULL::text[], p_editorial_decisions text[] DEFAULT ARRAY['accept_new'::text, 'accept_duplicate'::text], p_batch_name text DEFAULT NULL::text, p_batch_notes text DEFAULT NULL::text, p_created_by uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'ingest', 'public', 'auth'
AS $function$
declare
  v_match_statuses text[];
  v_editorial_decisions text[];
  v_row_ids bigint[];
  v_selected_count integer := 0;
  v_result jsonb;
begin
  select coalesce(array_agg(lower(trim(x))), '{}'::text[])
    into v_match_statuses
  from unnest(coalesce(p_match_statuses, '{}'::text[])) as t(x)
  where nullif(trim(x), '') is not null;

  select coalesce(array_agg(lower(trim(x))), '{}'::text[])
    into v_editorial_decisions
  from unnest(coalesce(p_editorial_decisions, '{}'::text[])) as t(x)
  where nullif(trim(x), '') is not null;

  select coalesce(array_agg(sr.id order by sr.row_no, sr.id), '{}'::bigint[])
    into v_row_ids
  from ingest.partner_catalog_staging_rows sr
  where sr.run_id = p_run_id
    and sr.created_book_draft_id is null
    and sr.created_exemplar_draft_id is null   -- H19 : déjà rapprochée
    and (
      coalesce(array_length(v_match_statuses, 1), 0) = 0
      or lower(sr.match_status) = any(v_match_statuses)
    )
    and (
      coalesce(array_length(v_editorial_decisions, 1), 0) = 0
      or lower(sr.editorial_decision) = any(v_editorial_decisions)
    )
    and (
      (sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new')
      or
      (sr.match_status in ('matched_book', 'matched_draft', 'possible_duplicate', 'manual_decision')
       and sr.editorial_decision = 'accept_duplicate')
    );

  v_selected_count := coalesce(array_length(v_row_ids, 1), 0);

  if v_selected_count = 0 then
    return jsonb_build_object(
      'run_id', p_run_id,
      'selected_count', 0,
      'message', 'Nenhuma linha elegível para criação em lote'
    );
  end if;

  v_result := ingest.fn_create_book_drafts_from_import_rows(
    p_run_id := p_run_id,
    p_row_ids := v_row_ids,
    p_batch_name := p_batch_name,
    p_batch_notes := p_batch_notes,
    p_created_by := p_created_by
  );

  return v_result || jsonb_build_object(
    'selected_count', v_selected_count,
    'selected_row_ids', to_jsonb(v_row_ids)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION ingest.fn_create_book_drafts_from_import_rows(p_run_id bigint, p_row_ids bigint[] DEFAULT NULL::bigint[], p_batch_name text DEFAULT NULL::text, p_batch_notes text DEFAULT NULL::text, p_created_by uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'ingest', 'public', 'auth'
AS $function$
declare
  v_actor uuid;
  v_partner_name text;
  v_relation_status text;
  v_original_filename text;
  v_detected_format text;
  v_batch_id bigint;
  v_batch_name text;
  v_batch_notes text;
  v_created_count integer := 0;
  v_requested_count integer := 0;
  v_draft_id bigint;
  v_refresh jsonb;
  v_collection_hint text;
  v_local_classification_hint text;
  v_provenance_note text;
  rec record;
begin
  v_actor := coalesce(p_created_by, auth.uid());

  select s.partner_name, s.relation_status, r.original_filename, r.detected_format
    into v_partner_name, v_relation_status, v_original_filename, v_detected_format
  from ingest.partner_catalog_import_runs r
  join ingest.partner_catalog_sources s on s.id = r.source_id
  where r.id = p_run_id;

  if not found then
    raise exception 'import_run % introuvable', p_run_id;
  end if;

  if coalesce(array_length(p_row_ids, 1), 0) > 0 then
    select count(*)::integer
      into v_requested_count
    from ingest.partner_catalog_staging_rows sr
    where sr.run_id = p_run_id
      and sr.id = any(p_row_ids)
      and sr.created_book_draft_id is null
      and sr.created_exemplar_draft_id is null   -- H19 : déjà rapprochée
      and (
        (sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new')
        or
        (sr.match_status in ('matched_book', 'matched_draft', 'possible_duplicate', 'manual_decision')
         and sr.editorial_decision = 'accept_duplicate')
      );
  else
    select count(*)::integer
      into v_requested_count
    from ingest.partner_catalog_staging_rows sr
    where sr.run_id = p_run_id
      and sr.created_book_draft_id is null
      and sr.created_exemplar_draft_id is null   -- H19 : déjà rapprochée
      and sr.selected_for_draft = true
      and sr.review_status = 'approved'
      and (
        (sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new')
        or
        (sr.match_status in ('matched_book', 'matched_draft', 'possible_duplicate', 'manual_decision')
         and sr.editorial_decision = 'accept_duplicate')
      );
  end if;

  if v_requested_count = 0 then
    raise exception 'Aucune ligne autorisée à convertir pour le run %', p_run_id;
  end if;

  v_batch_name := coalesce(
    nullif(trim(p_batch_name), ''),
    format(
      'Import parceiro #%s — %s — %s',
      p_run_id,
      left(coalesce(v_partner_name, 'parceiro sem nome'), 80),
      to_char(now() at time zone 'UTC', 'YYYY-MM-DD HH24:MI UTC')
    )
  );

  v_batch_notes := coalesce(
    nullif(trim(p_batch_notes), ''),
    format(
      'Lote criado a partir do import run %s (%s, formato %s).',
      p_run_id,
      coalesce(v_original_filename, 'arquivo sem nome'),
      coalesce(v_detected_format, 'unknown')
    )
  );

  insert into public.catalog_batches (name, notes, created_by)
  values (v_batch_name, v_batch_notes, v_actor)
  returning id into v_batch_id;

  for rec in
    select sr.*, r.original_filename, r.detected_format, s.partner_name, s.relation_status, s.source_kind
    from ingest.partner_catalog_staging_rows sr
    join ingest.partner_catalog_import_runs r on r.id = sr.run_id
    join ingest.partner_catalog_sources s on s.id = r.source_id
    where sr.run_id = p_run_id
      and sr.created_book_draft_id is null
      and sr.created_exemplar_draft_id is null   -- H19 : déjà rapprochée
      and not exists (
        select 1 from ingest.partner_catalog_row_to_draft rd where rd.staging_row_id = sr.id
      )
      and (
        (coalesce(array_length(p_row_ids, 1), 0) > 0 and sr.id = any(p_row_ids))
        or
        (coalesce(array_length(p_row_ids, 1), 0) = 0 and sr.selected_for_draft = true and sr.review_status = 'approved')
      )
      and (
        (sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new')
        or
        (sr.match_status in ('matched_book', 'matched_draft', 'possible_duplicate', 'manual_decision')
         and sr.editorial_decision = 'accept_duplicate')
      )
    order by sr.row_no, sr.id
  loop
    v_collection_hint := ingest.fn_partner_catalog_extract_collection_hint(rec.normalized_payload, rec.raw_payload);
    v_local_classification_hint := ingest.fn_partner_catalog_extract_local_classification_hint(rec.normalized_payload, rec.raw_payload);

    v_provenance_note := format(
      'Importado de catálogo parceiro "%s" (%s, run %s, linha %s, formato bruto %s, relação %s, decisão %s).',
      rec.partner_name,
      coalesce(rec.original_filename, 'arquivo sem nome'),
      rec.run_id,
      rec.row_no,
      coalesce(rec.detected_format, 'unknown'),
      coalesce(rec.relation_status, 'sem_status'),
      coalesce(rec.editorial_decision, 'pending')
    );

    if v_local_classification_hint is not null then
      v_provenance_note := v_provenance_note || format(' Sinal local da parceira preservado: %s.', v_local_classification_hint);
    end if;

    insert into public.book_drafts (
      batch_id, action, status, titulo, subtitulo, autor, edicao,
      local_publicacao, editora, ano, isbn, issn, idioma, tipo_material,
      cdd, colecao, marc_json, created_by, updated_by, acquisition_mode,
      partner_source, source_record_id, import_format, import_method,
      provenance_note, mutualization_status, source_label, notas
    ) values (
      v_batch_id,
      'create',
      'draft',
      nullif(trim(rec.title), ''),
      nullif(trim(rec.subtitle), ''),
      coalesce(nullif(trim(rec.responsibility_statement), ''), ingest.fn_format_partner_authors(rec.authors)),
      nullif(trim(rec.edition_statement), ''),
      nullif(trim(rec.place_of_publication), ''),
      nullif(trim(rec.publisher), ''),
      nullif(trim(rec.publication_year), ''),
      nullif(trim(rec.isbn), ''),
      nullif(trim(rec.issn), ''),
      nullif(trim(rec.language), ''),
      -- tipo_material : MAP du type brut (RIS/BibTeX) vers le vocabulaire valide.
      case lower(coalesce(nullif(trim(rec.item_type), ''), 'book'))
        when 'book' then 'livro'
        when 'livro' then 'livro'
        when 'jour' then 'periodico'
        when 'mgzn' then 'periodico'
        when 'news' then 'periodico'
        when 'newspaper' then 'periodico'
        when 'periodico' then 'periodico'
        when 'chap' then 'artigo'
        when 'inbook' then 'artigo'
        when 'article' then 'artigo'
        when 'artigo' then 'artigo'
        when 'thes' then 'tese'
        when 'tese' then 'tese'
        when 'rprt' then 'relatorio'
        when 'relatorio' then 'relatorio'
        when 'pamp' then 'tract'
        when 'tract' then 'tract'
        when 'zine' then 'zine'
        when 'elec' then 'recurso_digital'
        when 'sound' then 'audio'
        when 'audio' then 'audio'
        when 'video' then 'audiovisual'
        when 'mpct' then 'audiovisual'
        when 'audiovisual' then 'audiovisual'
        else 'livro'
      end,
      null,
      case
        when v_collection_hint is null then null
        when lower(coalesce(rec.item_type, '')) ~ '(periodic|journal|article|boletim|periodico|periódico|jour)' then null
        when lower(regexp_replace(coalesce(v_collection_hint, ''), '\s+', ' ', 'g')) = lower(regexp_replace(coalesce(rec.title, ''), '\s+', ' ', 'g')) then null
        else v_collection_hint
      end,
      coalesce(rec.normalized_payload, '{}'::jsonb)
        || jsonb_build_object(
             'ingest',
             jsonb_build_object(
               'run_id', rec.run_id,
               'staging_row_id', rec.id,
               'row_no', rec.row_no,
               'source_file_id', rec.source_file_id,
               'partner_name', rec.partner_name,
               'relation_status', rec.relation_status,
               'original_filename', rec.original_filename,
               'detected_format', rec.detected_format,
               'raw_payload', coalesce(rec.raw_payload, '{}'::jsonb),
               'authors', coalesce(rec.authors, '[]'::jsonb),
               'subjects', coalesce(rec.subjects, '[]'::jsonb),
               'editorial_decision', rec.editorial_decision,
               'editorial_note', rec.editorial_note,
               'derived_collection_hint', v_collection_hint,
               'derived_local_classification_hint', v_local_classification_hint
             )
           ),
      v_actor,
      v_actor,
      null,
      'other_partner',                               -- partner_source : code valide (FK source_partner_code). Nom precis dans provenance_note/source_label.
      coalesce(nullif(trim(rec.external_key), ''), rec.id::text),
      null,                                          -- import_format : NULL (evite FK source_format_code)
      null,                                          -- import_method : NULL (evite FK import_method_code)
      v_provenance_note,
      null,
      coalesce(rec.original_filename, rec.partner_name),
      concat_ws(
        ' ',
        case
          when rec.subjects is not null
           and jsonb_typeof(rec.subjects) = 'array'
           and jsonb_array_length(rec.subjects) > 0
          then 'Assuntos importados: '
               || array_to_string(array(select jsonb_array_elements_text(rec.subjects)), '; ')
          else null
        end,
        case
          when v_local_classification_hint is not null
          then format('Classificação / cote local preservada da parceira: %s.', v_local_classification_hint)
          else null
        end
      )
    ) returning id into v_draft_id;

    insert into ingest.partner_catalog_row_to_draft (staging_row_id, run_id, draft_id, batch_id, created_by)
    values (rec.id, rec.run_id, v_draft_id, v_batch_id, v_actor);

    update ingest.partner_catalog_staging_rows
       set created_book_draft_id = v_draft_id,
           review_status = 'draft_created',
           selected_for_draft = false
     where id = rec.id;

    v_created_count := v_created_count + 1;
  end loop;

  if v_created_count = 0 then
    delete from public.catalog_batches where id = v_batch_id;
    raise exception 'Aucun rascunho créé pour le run %', p_run_id;
  end if;

  v_refresh := ingest.fn_refresh_partner_catalog_run_counters(p_run_id);

  return jsonb_build_object(
    'run_id', p_run_id,
    'batch_id', v_batch_id,
    'batch_name', v_batch_name,
    'requested_rows', v_requested_count,
    'created_drafts', v_created_count,
    'run', v_refresh
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_batch_reassign_library(p_batch_id bigint, p_library_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest'
AS $function$
DECLARE
  v_batch    public.catalog_batches%rowtype;
  v_lib      public.libraries%rowtype;
  v_before   text;
  v_n        integer := 0;
  v_published bigint := 0;
  v_sources  integer := 0;
  v_who      text;
  v_warnings text[] := ARRAY[]::text[];
  v_items    integer := 0;   -- H19
BEGIN
  -- Reattribuer un lot, c'est decider a qui appartient un fonds : un acte de
  -- reseau, comme son entree (04/09) et sa revision (05/09).
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Reatribuicao de lote reservada a administracao da rede.'
      USING HINT = 'error.batch.reassign.admin_only';
  END IF;

  SELECT * INTO v_batch FROM public.catalog_batches WHERE id = p_batch_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lote % introuvable', p_batch_id
      USING HINT = 'error.batch.reassign.not_found';
  END IF;
  IF v_batch.status <> 'open' THEN
    RAISE EXCEPTION 'Lote % nao esta aberto (%)', p_batch_id, v_batch.status
      USING HINT = 'error.batch.reassign.not_open';
  END IF;

  SELECT * INTO v_lib FROM public.libraries WHERE id = p_library_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Biblioteca % introuvable', p_library_id
      USING HINT = 'error.batch.reassign.library_not_found';
  END IF;

  -- Une revision APPROUVEE l'a ete sur un rapport rendu pour une autre
  -- biblio : on ne change pas la destination sous une approbation. Un tour
  -- demande ou renvoye en retouches n'empeche rien.
  IF public.fn_batch_review_status(p_batch_id) = 'approved' THEN
    RAISE EXCEPTION 'Lote % tem revisao aprovada : pedir novo turno antes de reatribuir', p_batch_id
      USING HINT = 'error.batch.reassign.review_approved';
  END IF;

  -- D'ou viennent-ils (pour la trace) ?
  SELECT string_agg(DISTINCT coalesce(l.name, 'sem biblioteca'), ', ' ORDER BY coalesce(l.name, 'sem biblioteca'))
    INTO v_before
    FROM public.book_drafts d
    LEFT JOIN public.libraries l ON l.id = d.owner_library_id
   WHERE d.batch_id = p_batch_id AND d.status IN ('draft', 'ready');

  -- Les brouillons en cours changent de proprietaire. initial_copies_library_id
  -- est remis a nul : c'est l'override admin lu EN DERNIER par
  -- publish_book_draft, il l'emporterait sur la reattribution.
  UPDATE public.book_drafts d
     SET owner_library_id = v_lib.id,
         owner_library    = v_lib.name,
         initial_copies_library_id = NULL,
         updated_at = now()
   WHERE d.batch_id = p_batch_id
     AND d.status IN ('draft', 'ready')
     AND (d.owner_library_id IS DISTINCT FROM v_lib.id
          OR d.owner_library IS DISTINCT FROM v_lib.name
          OR d.initial_copies_library_id IS NOT NULL);
  GET DIAGNOSTICS v_n = ROW_COUNT;

  -- H19 : les brouillons d'exemplaires importés suivent leur notice (la
  -- détention sera posée à la publication, dans la nouvelle bibliothèque) ;
  -- ceux d'un rapprochement (sans notice : import_staging_row_id) aussi.
  UPDATE public.exemplar_drafts x
     SET target_library_id = v_lib.id, target_holding_id = NULL, updated_at = now()
   WHERE x.batch_id = p_batch_id
     AND (x.book_draft_id IS NOT NULL OR x.import_staging_row_id IS NOT NULL)
     AND x.status IN ('draft', 'ready')
     AND (x.target_library_id IS DISTINCT FROM v_lib.id OR x.target_holding_id IS NOT NULL);
  GET DIAGNOSTICS v_items = ROW_COUNT;

  SELECT count(*) INTO v_published
    FROM public.book_drafts d
   WHERE d.batch_id = p_batch_id AND d.status = 'published';

  -- La source compagne d'ou vient le lot suit : le prochain depot de la meme
  -- compagne arrivera directement chez elle.
  UPDATE ingest.partner_catalog_sources s
     SET destination_library_id = v_lib.id, updated_at = now()
   WHERE s.source_kind IN ('partner_deposit', 'oai_pmh')
     AND s.destination_library_id IS DISTINCT FROM v_lib.id
     AND s.id IN (
       SELECT r.source_id
         FROM ingest.partner_catalog_row_to_draft m
         JOIN ingest.partner_catalog_import_runs r ON r.id = m.run_id
        WHERE m.batch_id = p_batch_id
       -- H19 : la source d'un lot de rapprochement (sans notice) suit aussi.
       UNION
       SELECT r.source_id
         FROM public.exemplar_drafts x
         JOIN ingest.partner_catalog_staging_rows sr ON sr.id = x.import_staging_row_id
         JOIN ingest.partner_catalog_import_runs r ON r.id = sr.run_id
        WHERE x.batch_id = p_batch_id
     );
  GET DIAGNOSTICS v_sources = ROW_COUNT;

  -- La trace, dans la langue des notes de lot (pt-BR, comme fn_create_book_drafts_from_import_rows).
  SELECT coalesce(nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), ''), auth.uid()::text)
    INTO v_who
    FROM public.profiles p WHERE p.id = auth.uid();
  UPDATE public.catalog_batches
     SET notes = concat_ws(E'\n', nullif(notes, ''),
           format('[%s] Lote reatribuido a biblioteca « %s » por %s (%s rascunho(s) em curso ; antes : %s).',
                  to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI UTC'),
                  v_lib.name, coalesce(v_who, '?'), v_n, coalesce(v_before, 'sem biblioteca'))),
         updated_at = now()
   WHERE id = p_batch_id;

  -- array_append, pas « || 'litteral' » : un litteral non type a droite d'un
  -- text[] est lu comme un tableau (« malformed array literal »), vu au banc.
  IF v_lib.tombo_pattern IS NULL THEN v_warnings := array_append(v_warnings, 'library_without_tombo_pattern'); END IF;
  IF NOT coalesce(v_lib.is_active, false) THEN v_warnings := array_append(v_warnings, 'library_inactive'); END IF;
  IF v_n = 0 AND v_items = 0 THEN v_warnings := array_append(v_warnings, 'nothing_to_do'); END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'batch_id', p_batch_id,
    'library_id', v_lib.id,
    'library_name', v_lib.name,
    'drafts_updated', v_n,
    'items_updated', v_items,
    'drafts_published_untouched', v_published,
    'sources_aligned', v_sources,
    'previous', v_before,
    'warnings', to_jsonb(v_warnings)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION ingest.fn_create_exemplar_drafts_from_import_rows(p_run_id bigint, p_row_ids bigint[] DEFAULT NULL::bigint[], p_batch_name text DEFAULT NULL::text, p_batch_notes text DEFAULT NULL::text, p_created_by uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'ingest', 'public', 'auth'
AS $function$
declare
  v_actor uuid;
  v_library_id uuid;
  v_partner_name text;
  v_original_filename text;
  v_detected_format text;
  v_batch_id bigint;
  v_batch_name text;
  v_batch_notes text;
  v_requested_count integer := 0;
  v_created_count integer := 0;
  v_exemplar_draft_id bigint;
  v_first_id bigint;          -- H19
  v_items_created integer := 0;
  v_items_skipped integer := 0;
  v_rows_held integer := 0;
  v_source_kind text;
  v_destination uuid;
  v_item_library uuid;
  it jsonb;
  v_provenance_note text;
  v_refresh jsonb;
  rec record;
begin
  v_actor := coalesce(p_created_by, auth.uid());

  select r.library_id, s.partner_name, r.original_filename, r.detected_format, s.source_kind, s.destination_library_id
    into v_library_id, v_partner_name, v_original_filename, v_detected_format, v_source_kind, v_destination
  from ingest.partner_catalog_import_runs r
  join ingest.partner_catalog_sources s on s.id = r.source_id
  where r.id = p_run_id;

  if not found then
    raise exception 'import_run % introuvable', p_run_id;
  end if;

  -- H19 (27/09/2026, revue) : le fonds d'un dépôt compagnon (ou d'un entrepôt
  -- OAI) n'entre que par l'administration du réseau — même garde que
  -- fn_import_promote (04/09) — et va à la destination déclarée sur la source,
  -- rien tant qu'elle n'est pas connue (publish_exemplar_draft refuse alors) ;
  -- jamais dans la bibliothèque du run, qui est celle qui a déposé.
  if v_source_kind in ('partner_deposit', 'oai_pmh') and not public.fn_caller_is_network_admin() then
    raise exception 'Deposito de catalogo companheiro reservado a administracao da rede.'
      using hint = 'error.import.deposit_admin_only';
  end if;
  v_item_library := case when v_source_kind in ('partner_deposit', 'oai_pmh') then v_destination
                         else v_library_id end;

  -- Eligibilite : doublon d'un livre PUBLIE, decision accept_duplicate, pas
  -- deja rapproche.
  select count(*)::integer
    into v_requested_count
  from ingest.partner_catalog_staging_rows sr
  where sr.run_id = p_run_id
    and sr.created_exemplar_draft_id is null
    and sr.created_book_draft_id is null        -- H19
    and sr.proposed_book_id is not null
    and sr.editorial_decision = 'accept_duplicate'
    and sr.match_status in ('matched_book', 'possible_duplicate', 'manual_decision')
    and (coalesce(array_length(p_row_ids, 1), 0) = 0 or sr.id = any(p_row_ids));

  if v_requested_count = 0 then
    raise exception 'Aucune ligne eligible au rapprochement pour le run %', p_run_id;
  end if;

  v_batch_name := coalesce(
    nullif(trim(p_batch_name), ''),
    format(
      'Rapprochement parceiro #%s — %s — %s',
      p_run_id,
      left(coalesce(v_partner_name, 'parceiro sem nome'), 80),
      to_char(now() at time zone 'UTC', 'YYYY-MM-DD HH24:MI UTC')
    )
  );

  v_batch_notes := coalesce(
    nullif(trim(p_batch_notes), ''),
    format(
      'Exemplares de rascunho criados a partir do import run %s (%s, formato %s).',
      p_run_id,
      coalesce(v_original_filename, 'arquivo sem nome'),
      coalesce(v_detected_format, 'unknown')
    )
  );

  insert into public.catalog_batches (name, notes, created_by)
  values (v_batch_name, v_batch_notes, v_actor)
  returning id into v_batch_id;

  for rec in
    select sr.id as row_id,
           sr.row_no,
           sr.normalized_payload,
           b.bib_ref as proposed_bib_ref,
           b.titulo  as proposed_titulo
    from ingest.partner_catalog_staging_rows sr
    join public.books b on b.id = sr.proposed_book_id
    where sr.run_id = p_run_id
      and sr.created_exemplar_draft_id is null
      and sr.created_book_draft_id is null      -- H19
      and sr.proposed_book_id is not null
      and sr.editorial_decision = 'accept_duplicate'
      and sr.match_status in ('matched_book', 'possible_duplicate', 'manual_decision')
      and (coalesce(array_length(p_row_ids, 1), 0) = 0 or sr.id = any(p_row_ids))
    order by sr.row_no, sr.id
  loop
    v_provenance_note := format(
      'Exemplar criado a partir de catalogo parceiro "%s" (%s, run %s, linha %s): biblioteca importadora declara possuir um exemplar de "%s".',
      coalesce(v_partner_name, 'parceiro sem nome'),
      coalesce(v_original_filename, 'arquivo sem nome'),
      p_run_id,
      rec.row_no,
      coalesce(rec.proposed_titulo, 'sem titulo')
    );

    -- H19 (IMP-21) : UN brouillon d'exemplaire par exemplaire du fichier
    -- (995/852), avec son code d'origine et sa cote ; à défaut, un seul comme
    -- avant. La ligne pointe le premier (created_exemplar_draft_id) ; les
    -- autres la retrouvent par import_staging_row_id. Un exemplaire dont le
    -- code d'origine est DÉJÀ dans la bibliothèque (réexport du même
    -- catalogue) n'est pas recréé : il y est. Le code n'entre pas dans la
    -- note de provenance (IMP-21 b) : sa colonne suffit.
    v_first_id := null;
    for it in
      select value from jsonb_array_elements(
        case when jsonb_typeof(rec.normalized_payload->'items') = 'array'
              and jsonb_array_length(rec.normalized_payload->'items') > 0
             then rec.normalized_payload->'items'
             else '[{}]'::jsonb end)
    loop
      if nullif(btrim(it->>'source_item_code'), '') is not null
         and v_item_library is not null
         and exists (select 1 from public.exemplares e
                      where e.library_id = v_item_library
                        and e.source_item_code = btrim(it->>'source_item_code')) then
        v_items_skipped := v_items_skipped + 1;
        continue;
      end if;
      insert into public.exemplar_drafts (
        batch_id, action, status, label_status,
        target_library_id, target_bib_ref, source_library, provenance_note,
        source_item_code, shelf_location, notes, import_staging_row_id,
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
        v_actor, v_actor
      )
      returning id into v_exemplar_draft_id;
      v_first_id := coalesce(v_first_id, v_exemplar_draft_id);
      v_items_created := v_items_created + 1;

      -- Resout / relie le book_holdings (cree a la publication si absent).
      perform public.sync_exemplar_draft_holdings_bridge(v_exemplar_draft_id);
    end loop;
    v_exemplar_draft_id := v_first_id;
    -- Tous les exemplaires de la ligne sont déjà dans la bibliothèque : rien à
    -- rapprocher. La ligne est marquée rejetée, avec la raison — laissée en
    -- 'accept_duplicate' sans brouillon, le « Promouvoir » suivant en faisait
    -- une notice en double, impubliable (seconde revue, 27/09).
    if v_first_id is null then
      update ingest.partner_catalog_staging_rows
         set editorial_decision = 'reject',
             editorial_note = 'Todos os exemplares desta linha ja estao na biblioteca (mesmo codigo de origem): nada a aproximar.',
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
  end loop;

  if v_created_count = 0 then
    delete from public.catalog_batches where id = v_batch_id;
    -- H19 : tout était déjà dans la bibliothèque — dit, pas une erreur.
    if v_rows_held > 0 then
      v_refresh := ingest.fn_refresh_partner_catalog_run_counters(p_run_id);
      return jsonb_build_object(
        'run_id', p_run_id, 'batch_id', null, 'batch_name', null,
        'requested_rows', v_requested_count, 'created_exemplar_drafts', 0, 'created_items', 0,
        'items_skipped_code_taken', v_items_skipped, 'rows_already_held', v_rows_held,
        'run', v_refresh);
    end if;
    raise exception 'Aucun brouillon d''exemplaire cree pour le run %', p_run_id;
  end if;

  v_refresh := ingest.fn_refresh_partner_catalog_run_counters(p_run_id);

  return jsonb_build_object(
    'run_id', p_run_id,
    'batch_id', v_batch_id,
    'batch_name', v_batch_name,
    'requested_rows', v_requested_count,
    'created_exemplar_drafts', v_created_count,
    'created_items', v_items_created,
    'items_skipped_code_taken', v_items_skipped,
    'rows_already_held', v_rows_held,
    'run', v_refresh
  );
end;
$function$;

CREATE OR REPLACE FUNCTION ingest.fn_unreconcile_staging_on_exemplar_draft()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'ingest', 'public'
AS $function$
declare
  v_draft_id bigint;
  v_batch_id bigint;   -- H19
begin
  if tg_op = 'DELETE' then
    v_draft_id := old.id;
    v_batch_id := old.batch_id;
  else
    -- UPDATE : agir uniquement a la transition vers 'cancelled'
    if new.status is distinct from 'cancelled' or old.status = 'cancelled' then
      return new;
    end if;
    v_draft_id := new.id;
    v_batch_id := new.batch_id;
  end if;

  -- H19 (26/09/2026) : un rapprochement peut avoir créé PLUSIEURS exemplaires
  -- (un par 995). Annuler ou supprimer l'un d'eux ne défait pas la décision
  -- éditoriale tant qu'un autre vit : la ligne est repointée sur un survivant
  -- du MÊME rapprochement (même lot, sans notice) — jamais sur un exemplaire
  -- promu avec une notice, ni sur un brouillon d'ailleurs.
  update ingest.partner_catalog_staging_rows sr
     set created_exemplar_draft_id = (
           select min(x.id) from public.exemplar_drafts x
            where x.import_staging_row_id = sr.id and x.id <> v_draft_id
              and x.book_draft_id is null and x.batch_id is not distinct from v_batch_id
              and x.status in ('draft', 'ready', 'published'))
   where sr.created_exemplar_draft_id = v_draft_id
     and exists (select 1 from public.exemplar_drafts x
                  where x.import_staging_row_id = sr.id and x.id <> v_draft_id
                    and x.book_draft_id is null and x.batch_id is not distinct from v_batch_id
                    and x.status in ('draft', 'ready', 'published'));

  update ingest.partner_catalog_staging_rows sr
     set created_exemplar_draft_id = null,
         editorial_decision = 'pending',
         editorial_note = null,
         editorial_decided_at = null,
         editorial_decided_by = null,
         review_status = 'pending',
         selected_for_draft = false
   where sr.created_exemplar_draft_id = v_draft_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$function$;

-- ── Fusions de doublons, journal des suppressions, retraitement ─────────
CREATE OR REPLACE FUNCTION api.merge_book_drafts(p_survivor_id bigint, p_loser_id bigint, p_fields jsonb DEFAULT '{}'::jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_surv public.book_drafts%rowtype;
  v_lose public.book_drafts%rowtype;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING HINT = 'error.merge.staff_only';
  END IF;

  IF p_survivor_id = p_loser_id THEN
    RAISE EXCEPTION 'Sobrevivente e duplicado identicos.'
      USING HINT = 'error.merge.same_draft';
  END IF;

  SELECT * INTO v_surv FROM public.book_drafts WHERE id = p_survivor_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rascunho sobrevivente % inexistente.', p_survivor_id
      USING HINT = 'error.merge.draft_not_found';
  END IF;
  SELECT * INTO v_lose FROM public.book_drafts WHERE id = p_loser_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rascunho duplicado % inexistente.', p_loser_id
      USING HINT = 'error.merge.draft_not_found';
  END IF;
  IF v_surv.status NOT IN ('draft', 'ready') OR v_lose.status NOT IN ('draft', 'ready') THEN
    RAISE EXCEPTION 'Ambos os rascunhos devem estar na fila.'
      USING HINT = 'error.merge.draft_not_in_queue';
  END IF;
  IF v_surv.owner_library_id IS DISTINCT FROM v_lose.owner_library_id THEN
    RAISE EXCEPTION 'Rascunhos de bibliotecas diferentes nao podem ser fundidos.'
      USING HINT = 'error.merge.cross_library';
  END IF;

  UPDATE public.book_drafts SET
    titulo    = COALESCE(p_fields->>'titulo',    titulo),
    subtitulo = COALESCE(p_fields->>'subtitulo', subtitulo),
    autor     = COALESCE(p_fields->>'autor',     autor),
    isbn      = COALESCE(p_fields->>'isbn',      isbn),
    ano       = COALESCE(p_fields->>'ano',       ano),
    editora   = COALESCE(p_fields->>'editora',   editora),
    cdd       = COALESCE(p_fields->>'cdd',       cdd),
    colecao   = COALESCE(p_fields->>'colecao',   colecao),
    idioma    = COALESCE(p_fields->>'idioma',    idioma),
    updated_by = auth.uid(), updated_at = now()
  WHERE id = p_survivor_id;

  IF v_lose.bib_ref IS NOT NULL AND v_surv.bib_ref IS NOT NULL THEN
    UPDATE public.exemplar_drafts SET
      target_bib_ref = v_surv.bib_ref, updated_at = now()
    WHERE batch_id IS NOT DISTINCT FROM v_lose.batch_id
      AND target_bib_ref = v_lose.bib_ref;
  END IF;

  -- H19 (27/09/2026) : les exemplaires importés du perdant (rattachés par
  -- book_draft_id, sans target_bib_ref avant publication : la réécriture
  -- ci-dessus ne les voit pas) passent au survivant, dans son lot. Sans cela
  -- l'écart du perdant les emportait avec lui.
  UPDATE public.exemplar_drafts SET
    book_draft_id = p_survivor_id, batch_id = v_surv.batch_id, updated_at = now()
  WHERE book_draft_id = p_loser_id AND status IN ('draft', 'ready');

  UPDATE public.book_drafts SET
    status = 'cancelled', updated_by = auth.uid(), updated_at = now()
  WHERE id = p_loser_id;

  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('book_draft', p_survivor_id, p_loser_id,
          jsonb_build_object('scenario', 'draft_into_draft',
                             'fields', COALESCE(p_fields, '{}'::jsonb)),
          auth.uid());

  RETURN p_survivor_id;
END;
$function$;

CREATE OR REPLACE FUNCTION api.merge_draft_into_book(p_draft_id bigint, p_book_id bigint, p_fields jsonb DEFAULT '{}'::jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_draft         public.book_drafts%rowtype;
  v_book_bib_ref  text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING HINT = 'error.merge.staff_only';
  END IF;

  SELECT * INTO v_draft FROM public.book_drafts WHERE id = p_draft_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rascunho % inexistente.', p_draft_id
      USING HINT = 'error.merge.draft_not_found';
  END IF;
  IF v_draft.status NOT IN ('draft', 'ready') THEN
    RAISE EXCEPTION 'Rascunho % nao esta na fila (status=%).', p_draft_id, v_draft.status
      USING HINT = 'error.merge.draft_not_in_queue';
  END IF;

  SELECT bib_ref INTO v_book_bib_ref FROM public.books WHERE id = p_book_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Livro % inexistente.', p_book_id
      USING HINT = 'error.merge.book_not_found';
  END IF;

  UPDATE public.books SET
    titulo    = COALESCE(p_fields->>'titulo',    titulo),
    subtitulo = COALESCE(p_fields->>'subtitulo', subtitulo),
    autor     = COALESCE(p_fields->>'autor',     autor),
    isbn      = COALESCE(p_fields->>'isbn',      isbn),
    ano       = COALESCE(p_fields->>'ano',       ano),
    editora   = COALESCE(p_fields->>'editora',   editora),
    cdd       = COALESCE(p_fields->>'cdd',       cdd),
    colecao   = COALESCE(p_fields->>'colecao',   colecao),
    idioma    = COALESCE(p_fields->>'idioma',    idioma),
    updated_by = auth.uid(), updated_at = now(), last_cataloged_at = now()
  WHERE id = p_book_id;

  -- H19 (27/09/2026) : les exemplaires importés du brouillon absorbé vont sur
  -- la fiche existante, comme ceux d'un rapprochement : sans notice
  -- (book_draft_id nul), avec la référence de la fiche ; leur bibliothèque et
  -- leur ligne importée restent (publish_exemplar_draft exige alors une
  -- bibliothèque, et d'en être staff). Sans cela l'écart du brouillon les
  -- emportait avec lui.
  UPDATE public.exemplar_drafts SET
    book_draft_id = NULL, target_bib_ref = v_book_bib_ref, target_holding_id = NULL, updated_at = now()
  WHERE book_draft_id = p_draft_id AND status IN ('draft', 'ready');

  UPDATE public.book_drafts SET
    published_book_id = p_book_id,
    bib_ref           = COALESCE(bib_ref, v_book_bib_ref),
    action            = 'update',
    status            = 'cancelled',
    updated_by = auth.uid(), updated_at = now()
  WHERE id = p_draft_id;

  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('book_draft', p_book_id, p_draft_id,
          jsonb_build_object('scenario', 'draft_into_book',
                             'fields', COALESCE(p_fields, '{}'::jsonb)),
          auth.uid());

  RETURN p_book_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_audit_draft_deletion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog', 'pg_temp'
AS $function$
declare
  v_entity  text;
  v_label   text;
  v_library uuid;
  v_details jsonb;
begin
  v_details := jsonb_build_object('snapshot', to_jsonb(old));

  if tg_table_name = 'book_drafts' then
    v_entity  := 'book';
    v_label   := old.titulo;
    v_library := old.owner_library_id;
    -- Les enfants en CASCADE : sans eux, le rejeu rendrait une coquille.
    v_details := v_details || jsonb_build_object('children', jsonb_build_object(
      'book_draft_contributors', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.book_draft_contributors c where c.draft_id = old.id), '[]'::jsonb),
      'book_draft_subjects', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.book_draft_subjects c where c.book_draft_id = old.id), '[]'::jsonb),
      'book_draft_catalog_context', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.book_draft_catalog_context c where c.book_draft_id = old.id), '[]'::jsonb),
      'book_draft_digital_resources', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.book_draft_digital_resources c where c.book_draft_id = old.id), '[]'::jsonb),
      -- H19 : ses exemplaires importés (CASCADE sur book_draft_id) ; rejoués
      -- avec elle, sinon la notice revenait sans eux et publiait l'exemplaire
      -- automatique, codes et cotes perdus.
      'exemplar_drafts', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.exemplar_drafts c where c.book_draft_id = old.id), '[]'::jsonb)
    ));
  elsif tg_table_name = 'author_drafts' then
    v_entity := 'author';
    v_label  := old.preferred_name;
  else
    -- H19 (27/09) : supprimé par CASCADE avec sa notice, il est déjà dans
    -- l'instantané de celle-ci (children.exemplar_drafts) : pas d'entrée à part.
    if old.book_draft_id is not null
       and not exists (select 1 from public.book_drafts b where b.id = old.book_draft_id) then
      return old;
    end if;
    v_entity  := 'exemplar';
    v_label   := coalesce(old.tombo, old.target_bib_ref);
    v_library := old.target_library_id;
  end if;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, library_id, label, details)
  values (auth.uid(), 'delete', v_entity, old.id, v_library, v_label,
          v_details || jsonb_build_object('batch_id', old.batch_id, 'source_table', tg_table_name));

  return old;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_restore_deleted_draft(p_audit_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog', 'pg_temp'
AS $function$
declare
  v_log      public.catalog_audit_log%rowtype;
  v_snap     jsonb;
  v_tbl      text;
  v_id       bigint;
  v_exists   boolean;
  v_child    record;
  v_fk       text;
  v_enfants  int := 0;
  v_n        int;
  v_rows     jsonb;   -- H19
begin
  -- Meme porte que la publication : le staff de catalogage. Restaurer n'est pas
  -- un geste destructeur, il n'a pas a etre plus reserve que catalguer.
  if not exists (select 1 from public.user_library_memberships m
                  where m.user_id = auth.uid() and m.status = 'active'
                    and m.role = any (array['librarian'::text, 'coordenador'::text]))
     and not public.fn_caller_is_network_admin() then
    raise exception 'Acesso restrito ao staff de catalogacao.'
      using hint = 'error.catalog.staff_only';
  end if;

  select * into v_log from public.catalog_audit_log where id = p_audit_id;
  if not found or v_log.action <> 'delete' then
    raise exception 'entree de journal % introuvable ou pas une suppression', p_audit_id
      using hint = 'error.catalog.restore_not_found';
  end if;

  v_snap := v_log.details -> 'snapshot';
  v_tbl  := v_log.details ->> 'source_table';
  if v_snap is null or v_tbl is null then
    raise exception 'instantane absent pour le journal % (purge de retention ?)', p_audit_id
      using hint = 'error.catalog.restore_no_snapshot';
  end if;
  -- La table vient du journal : on la confronte a la liste, on ne la concatene
  -- pas telle quelle dans du SQL.
  if v_tbl not in ('book_drafts', 'author_drafts', 'exemplar_drafts') then
    raise exception 'table inattendue dans le journal % : %', p_audit_id, v_tbl;
  end if;

  v_id := (v_snap ->> 'id')::bigint;
  execute format('select exists (select 1 from public.%I where id = $1)', v_tbl)
    into v_exists using v_id;
  if v_exists then
    raise exception 'le brouillon % existe deja : rien a rejouer', v_id
      using hint = 'error.catalog.restore_already';
  end if;

  -- H19 (27/09) : un exemplaire rejoué seul. Sa notice a disparu depuis :
  -- refus dit (la rejouer d'abord, elle le ramènera s'il était dans son
  -- instantané). Sa ligne importée a été purgée : le lien seul tombe.
  if v_tbl = 'exemplar_drafts' then
    if v_snap->>'book_draft_id' is not null
       and not exists (select 1 from public.book_drafts b where b.id = (v_snap->>'book_draft_id')::bigint) then
      raise exception 'notice % absente : la restaurer d''abord', v_snap->>'book_draft_id'
        using hint = 'error.catalog.restore_record_first';
    end if;
    if v_snap->>'import_staging_row_id' is not null
       and not exists (select 1 from ingest.partner_catalog_staging_rows sr
                        where sr.id = (v_snap->>'import_staging_row_id')::bigint) then
      v_snap := jsonb_set(v_snap, '{import_staging_row_id}', 'null'::jsonb);
    end if;
  end if;
  execute format(
    'insert into public.%I select * from jsonb_populate_record(null::public.%I, $1)', v_tbl, v_tbl)
    using v_snap;

  if v_tbl = 'book_drafts' then
    for v_child in
      select key as tbl, value as rows
        from jsonb_each(coalesce(v_log.details -> 'children', '{}'::jsonb))
    loop
      if v_child.tbl not in ('book_draft_contributors', 'book_draft_subjects',
                             'book_draft_catalog_context', 'book_draft_digital_resources',
                             'exemplar_drafts') then   -- H19
        continue;
      end if;
      -- L'INSERT du parent a reveille ses propres triggers : celui qui seme les
      -- contributeurs depuis `autor`, celui qui derive le contexte de catalogage
      -- depuis marc_json. Ils viennent de fabriquer des enfants QUI NE SONT PAS
      -- ceux qu'on rejoue — d'ou un conflit de cle primaire sur
      -- book_draft_catalog_context (trouve par les tests, pas par la lecture).
      -- Regle retenue : l'instantane fait foi, il decrit l'etat au moment de la
      -- suppression. On efface ce que les triggers ont pose, puis on rejoue.
      v_fk := case v_child.tbl when 'book_draft_contributors' then 'draft_id'
                               else 'book_draft_id' end;
      execute format('delete from public.%I where %I = $1', v_child.tbl, v_fk) using v_id;
      v_rows := v_child.rows;
      -- H19 : une ligne importée purgée depuis ne bloque pas le rejeu de
      -- l'exemplaire (sa clé étrangère serait violée) : le lien seul tombe.
      if v_child.tbl = 'exemplar_drafts' then
        select coalesce(jsonb_agg(case
                 when e.v->>'import_staging_row_id' is not null
                      and not exists (select 1 from ingest.partner_catalog_staging_rows sr
                                       where sr.id = (e.v->>'import_staging_row_id')::bigint)
                 then jsonb_set(e.v, '{import_staging_row_id}', 'null'::jsonb)
                 else e.v end), '[]'::jsonb)
          into v_rows
          from jsonb_array_elements(v_child.rows) as e(v);
      end if;
      execute format(
        'insert into public.%I select * from jsonb_populate_recordset(null::public.%I, $1)',
        v_child.tbl, v_child.tbl) using v_rows;
      get diagnostics v_n = row_count;
      v_enfants := v_enfants + v_n;
    end loop;
  end if;

  -- Le journal est en ajout seul : on n'annote pas la ligne d'origine, on ecrit
  -- une seconde ligne. Une trace qui se reecrit n'est plus une trace.
  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, library_id, label, details)
  values (auth.uid(), 'restore', v_log.entity_type, v_id, v_log.library_id, v_log.label,
          jsonb_build_object('from_audit_id', p_audit_id, 'source_table', v_tbl,
                             'children_restored', v_enfants));

  return jsonb_build_object('ok', true, 'entity_type', v_log.entity_type,
                            'draft_id', v_id, 'source_table', v_tbl,
                            'children_restored', v_enfants);
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_import_dispatch(p_run_id bigint, p_force_reparse boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth'
AS $function$
DECLARE
  v_actor public.my_access%rowtype;
  v_run_library_id uuid;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  SELECT r.library_id INTO v_run_library_id
  FROM ingest.partner_catalog_import_runs r
  WHERE r.id = p_run_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  IF v_run_library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  -- H15 (26/09/2026) : retraiter efface les lignes de staging, et le lien
  -- ligne → brouillon les suit (ON DELETE CASCADE). Un run déjà promu ne se
  -- relit donc plus : on importe à nouveau le fichier.
  IF coalesce(p_force_reparse, false)
     AND (EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft l WHERE l.run_id = p_run_id)
          -- H19 (27/09/2026) : un rapprochement aussi a produit des brouillons
          -- (d'exemplaires) ; effacer les lignes les détacherait de leur import
          -- (import_staging_row_id → NULL) et ferait tomber leurs gardes.
          OR EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows sr
                       JOIN public.exemplar_drafts x ON x.import_staging_row_id = sr.id
                      WHERE sr.run_id = p_run_id AND x.status <> 'cancelled')) THEN
    RAISE EXCEPTION 'Import % ja promovido em rascunhos : nao pode ser reprocessado.', p_run_id
      USING HINT = 'error.import.reparse_after_promotion';
  END IF;

  -- H19 (27/09) : le profil posé sur le run a été supprimé depuis : l'EF
  -- refuserait de lire le fichier (sans lui, codes et cotes seraient relus
  -- avec la convention par défaut), mais en différé, sans personne à qui le
  -- dire. Refus ici, tout de suite, à l'écran.
  IF EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs r
              WHERE r.id = p_run_id
                AND coalesce(r.adapter_overrides->>'profile_id', '') ~ '^[0-9]+$'
                AND NOT EXISTS (SELECT 1 FROM ingest.import_profiles p
                                 WHERE p.id = (r.adapter_overrides->>'profile_id')::bigint)) THEN
    RAISE EXCEPTION 'Perfil de importacao do run % suprimido.', p_run_id
      USING HINT = 'error.import.profile_missing';
  END IF;

  RETURN ingest.fn_dispatch_partner_catalog_import(
    p_run_id       := p_run_id,
    p_force_reparse := p_force_reparse
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_batch_review_report(p_batch_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'extensions'
AS $function$
declare
  v_batch      public.catalog_batches%rowtype;
  v_conv       jsonb := '[]'::jsonb;
  v_rule       record;
  v_items      jsonb;
  v_count      int;
  v_issues     int := 0;
  v_dup_isbn   jsonb;
  v_dup_meta   jsonb;
  v_dup_intra  jsonb;
  v_matching   jsonb;
  v_unlinked   jsonb;
  v_unlinked_n int;
  v_linkable_n int;
  v_title_n    int;
  v_from       text;
  v_sql        text;
  v_ctx        text;
  v_coverage   jsonb;
  v_items_import jsonb;
  v_items_admin boolean;
  v_items_staff uuid[];
begin
  if not (public.fn_caller_is_network_admin()
          or exists (select 1 from public.user_library_memberships m
                      where m.user_id = auth.uid() and m.status = 'active'
                        and m.role in ('librarian', 'coordenador'))) then
    raise exception 'Acesso restrito ao staff de catalogacao.' using hint = 'error.catalog.staff_only';
  end if;

  select * into v_batch from public.catalog_batches where id = p_batch_id;
  if not found then
    raise exception 'Lote % introuvable', p_batch_id using hint = 'error.review.batch_not_found';
  end if;

  -- Les brouillons vivants du lot : une fonction, pas une table temporaire.
  -- (Une table temporaire creee dans une RPC reveille pgrst_ddl_watch a
  -- chaque appel : rechargement du cache PostgREST, et l'ecran recevait un 400.)
  v_from := format('public.fn_batch_live_drafts(%s) d', p_batch_id);

  -- ── Conventions : une regle = un SELECT (id, titulo, valeur) sur `d` ──
  for v_rule in
    select * from (values
      ('titulo_missing',   $q$ select d.id, d.titulo, null::text from %s where d.titulo is null or btrim(d.titulo) = '' $q$),
      ('titulo_caps',      $q$ select d.id, d.titulo, d.titulo from %s where d.titulo = upper(d.titulo) and d.titulo ~ '[A-ZÀ-Þ]{4,}' $q$),
      ('titulo_article_end', $q$ select d.id, d.titulo, d.titulo from %s where d.titulo ~ ', (O|A|Os|As|Um|Uma|Le|La|Les|El|Los|Las|The)$' $q$),
      ('autor_missing',    $q$ select d.id, d.titulo, null::text from %s
                                where (d.autor is null or btrim(d.autor) = '')
                                  and not exists (select 1 from public.book_draft_contributors c where c.draft_id = d.id) $q$),
      ('autor_unstructured', $q$ select d.id, d.titulo, d.autor from %s
                                where d.autor is not null and btrim(d.autor) <> ''
                                  and not public.fn_conv_est_non_agent(d.autor)
                                  and not exists (select 1 from public.book_draft_contributors c where c.draft_id = d.id) $q$),
      ('contrib_non_agent', $q$ select d.id, d.titulo, c.name from %s
                                join public.book_draft_contributors c on c.draft_id = d.id
                               where public.fn_conv_est_non_agent(c.name) $q$),
      ('contrib_caps',     $q$ select d.id, d.titulo, c.name from %s
                                join public.book_draft_contributors c on c.draft_id = d.id
                               where c.name ~ '\m[A-ZÀ-Þ]{2,}\M' and c.name !~ '[A-ZÀ-Þ]\.' and not public.fn_conv_est_non_agent(c.name) $q$),
      ('contrib_direct_form', $q$ select d.id, d.titulo, c.name from %s
                                join public.book_draft_contributors c on c.draft_id = d.id
                               where c.name !~ ',' and btrim(c.name) ~ '\s' and not public.fn_conv_est_non_agent(c.name) $q$),
      ('ano_invalid',      $q$ select d.id, d.titulo, d.ano from %s
                                where d.approximate_date is null and (d.ano is null or d.ano !~ '^\d{4}$') $q$),
      ('editora_missing',  $q$ select d.id, d.titulo, null::text from %s where d.editora is null or btrim(d.editora) = '' $q$),
      ('idioma_missing',   $q$ select d.id, d.titulo, null::text from %s where d.idioma is null or btrim(d.idioma) = '' $q$),
      ('tipo_material_invalid', $q$ select d.id, d.titulo, d.tipo_material from %s
                                where d.tipo_material is null or lower(d.tipo_material) <> all (array['livro','periodico','tract','cartaz','audio','audiovisual','recurso_digital','dossie','tese','artigo','relatorio','zine']) $q$),
      ('isbn_invalid',     $q$ select d.id, d.titulo, d.isbn from %s
                                where d.isbn is not null and btrim(d.isbn) <> ''
                                  and length(regexp_replace(upper(d.isbn), '[^0-9X]', '', 'g')) not in (10, 13) $q$),
      ('bib_ref_missing',  $q$ select d.id, d.titulo, null::text from %s where d.bib_ref is null or btrim(d.bib_ref) = '' $q$),
      ('subjects_missing', $q$ select d.id, d.titulo, null::text from %s
                                where (d.subjects is null or btrim(d.subjects) = '')
                                  and not exists (select 1 from public.book_draft_subjects s where s.book_draft_id = d.id) $q$)
    ) as r(rule, sql)
  loop
    v_sql := format(v_rule.sql, v_from);
    execute format('select count(*) from (%s) as q(id, titulo, v)', v_sql) into v_count;
    if v_count > 0 then
      execute format('select coalesce(jsonb_agg(jsonb_build_object(''draft_id'', t.id, ''titulo'', t.titulo, ''value'', t.v)), ''[]''::jsonb)
                        from (select q.id, q.titulo, q.v from (%s) as q(id, titulo, v) order by q.id limit 40) t', v_sql)
         into v_items;
      v_conv := v_conv || jsonb_build_object('rule', v_rule.rule, 'count', v_count, 'items', v_items);
      v_issues := v_issues + v_count;
    end if;
  end loop;

  -- Entree au titre (CONV-8) : informatif, pas un ecart.
  select count(*) into v_title_n from public.fn_batch_live_drafts(p_batch_id) d
   where d.autor is not null and public.fn_conv_est_non_agent(d.autor);

  -- ── Doublons contre le catalogue : ISBN, puis titre + auteur + annee ──
  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_dup_isbn from (
    select jsonb_build_object('draft_id', d.id, 'titulo', d.titulo, 'book_id', b.id, 'reason', 'isbn') as x
      from public.fn_batch_live_drafts(p_batch_id) d
      join public.books b
        on regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g')
         = regexp_replace(upper(coalesce(d.isbn, '')), '[^0-9X]', '', 'g')
     where coalesce(d.isbn, '') <> ''
       and (d.published_book_id is null or b.id <> d.published_book_id)
     order by d.id limit 40) s;

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_dup_meta from (
    select jsonb_build_object('draft_id', d.id, 'titulo', d.titulo, 'book_id', b.id, 'reason', 'titulo_autor_ano') as x
      from public.fn_batch_live_drafts(p_batch_id) d
      join public.books b
        on lower(extensions.unaccent(btrim(coalesce(b.titulo, '')))) = lower(extensions.unaccent(btrim(coalesce(d.titulo, ''))))
       and coalesce(b.ano, '') = coalesce(d.ano, '')
       and lower(extensions.unaccent(btrim(coalesce(b.autor, '')))) = lower(extensions.unaccent(btrim(coalesce(d.autor, ''))))
     where coalesce(d.titulo, '') <> ''
       and (d.published_book_id is null or b.id <> d.published_book_id)
       and not (coalesce(d.isbn, '') <> '' and
                regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g')
              = regexp_replace(upper(coalesce(d.isbn, '')), '[^0-9X]', '', 'g'))
     order by d.id limit 40) s;

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_dup_intra from (
    select jsonb_build_object('titulo', min(d.titulo), 'draft_ids', jsonb_agg(d.id order by d.id)) as x
      from public.fn_batch_live_drafts(p_batch_id) d
     where coalesce(d.titulo, '') <> ''
     group by lower(extensions.unaccent(btrim(d.titulo))),
              lower(extensions.unaccent(btrim(coalesce(d.autor, '')))),
              coalesce(d.ano, '')
    having count(*) > 1
     order by min(d.id) limit 40) s;

  select coalesce(jsonb_object_agg(match_status, n), '{}'::jsonb) into v_matching from (
    select sr.match_status, count(*) as n
      from ingest.partner_catalog_row_to_draft m
      join ingest.partner_catalog_staging_rows sr on sr.id = m.staging_row_id
     where m.batch_id = p_batch_id
     group by sr.match_status) s;

  -- ── Autorites : contributeurs non lies, et ceux qu'une fiche attend ──
  select count(*),
         count(*) filter (where public.fn_conv_autorite_homonyme(c.name) is not null)
    into v_unlinked_n, v_linkable_n
    from public.fn_batch_live_drafts(p_batch_id) d
    join public.book_draft_contributors c on c.draft_id = d.id
   where c.author_id is null and not public.fn_conv_est_non_agent(c.name);

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_unlinked from (
    select jsonb_build_object('draft_id', d.id, 'titulo', d.titulo, 'name', c.name,
                              'suggested_author_id', a.id, 'suggested_sort_name', a.sort_name) as x
      from public.fn_batch_live_drafts(p_batch_id) d
      join public.book_draft_contributors c on c.draft_id = d.id
      left join public.authors a on a.id = public.fn_conv_autorite_homonyme(c.name)
     where c.author_id is null and not public.fn_conv_est_non_agent(c.name)
     order by (a.id is null), d.id limit 40) s;

  -- ── H16 (26/09/2026) : ce que chaque import d'origine a repris ────────
  -- Pour chaque run dont ce lot est issu : les comptes (repris / indice /
  -- brut), l'encodage lu, les entrees ecartees, et SEULEMENT les zones,
  -- colonnes ou balises NON reprises (le rapport ne recopie pas tout le
  -- fichier). La couverture complete reste dans le summary du run.
  select coalesce(jsonb_agg(x order by (x->>'run_id')::bigint), '[]'::jsonb) into v_coverage from (
    select jsonb_build_object(
             'run_id', r.id,
             'original_filename', r.original_filename,
             'detected_format', r.detected_format,
             'counts', r.summary->'coverage_counts',
             'encoding', r.summary->'encoding',
             'skipped_rows', r.summary->'skipped_rows',
             'kind', r.summary->'coverage'->>'kind',
             'not_taken', coalesce(
               jsonb_path_query_array(r.summary->'coverage', '$.zones[*] ? (@.status != "repris")'),
               '[]'::jsonb)
               || coalesce(jsonb_path_query_array(r.summary->'coverage', '$.columns[*] ? (@.status != "repris")'), '[]'::jsonb)
               || coalesce(jsonb_path_query_array(r.summary->'coverage', '$.tags[*] ? (@.status != "repris")'), '[]'::jsonb)
           ) as x
      from ingest.partner_catalog_import_runs r
     where r.id in (select distinct m.run_id from ingest.partner_catalog_row_to_draft m where m.batch_id = p_batch_id)
  ) s;

  -- ── H19 (26-27/09/2026) : les exemplaires importés du lot ─────────────
  -- Ceux d'une notice promue (book_draft_id) et ceux d'un rapprochement
  -- (import_staging_row_id, sans notice). Ce qui empêcherait leur
  -- publication, dit AVANT : pas de bibliothèque ; bibliothèque autre que
  -- celle où la notice publiera ; pas de schéma de numérotation (fn_next_tombo
  -- lèverait) ; code d'origine déjà pris dans la bibliothèque ; présent deux
  -- fois dans le lot ; attendu par un brouillon vivant d'un AUTRE lot.
  -- En un passage (fenêtre, pas de sous-requête corrélée par ligne : un
  -- catalogue PMB entier passe dans un lot) ; 40 problèmes au plus, comme les
  -- autres sections, les comptes portent sur tout. « Code déjà pris » ne se
  -- calcule que pour une bibliothèque dont l'appelant est staff (ou pour
  -- l'administration du réseau) : ailleurs il renseignerait sur des
  -- exemplaires qu'il ne voit pas.
  v_items_admin := public.fn_caller_is_network_admin();
  select coalesce(array_agg(m.library_id), '{}'::uuid[]) into v_items_staff
    from public.user_library_memberships m
   where m.user_id = auth.uid() and m.status = 'active'
     and m.role in ('librarian', 'coordenador');

  with q0 as (
    select x.id, x.book_draft_id, x.source_item_code, x.target_library_id, x.tombo,
           coalesce(d.titulo, b.titulo) as titulo,
           case when d.id is not null
                then coalesce(d.owner_library_id, public.fn_book_draft_destination_library(d.id)) end as record_library,
           l.tombo_pattern,
           count(*) over (partition by x.target_library_id, x.source_item_code) as n_same_code
      from public.exemplar_drafts x
      left join public.book_drafts d on d.id = x.book_draft_id
      left join lateral (select bk.titulo from public.books bk
                          where x.book_draft_id is null and bk.bib_ref = x.target_bib_ref
                          limit 1) b on true
      left join public.libraries l on l.id = x.target_library_id
     where x.batch_id = p_batch_id
       and (x.book_draft_id is not null or x.import_staging_row_id is not null)
       and x.status in ('draft', 'ready')
       and (d.id is null or d.status in ('draft', 'ready'))
  ), q as (
    select q0.*,
           case
             when q0.target_library_id is null then 'without_library'
             when q0.book_draft_id is not null
                  and q0.record_library is distinct from q0.target_library_id then 'library_mismatch'
             when q0.tombo_pattern is null and nullif(btrim(coalesce(q0.tombo, '')), '') is null then 'library_without_numbering'
             when q0.source_item_code is not null
                  and (v_items_admin or q0.target_library_id = any(v_items_staff))
                  and exists (select 1 from public.exemplares e
                               where e.library_id = q0.target_library_id
                                 and e.source_item_code = q0.source_item_code) then 'code_taken'
             when q0.source_item_code is not null and q0.n_same_code > 1 then 'code_twice'
             when q0.source_item_code is not null and exists (
                    select 1 from public.exemplar_drafts y
                     where y.target_library_id = q0.target_library_id
                       and y.source_item_code = q0.source_item_code
                       and y.batch_id is distinct from p_batch_id
                       and y.status in ('draft', 'ready')) then 'code_pending_elsewhere'
             else null
           end as reason
      from q0
  )
  select jsonb_build_object(
           'count', count(*),
           'with_code', count(*) filter (where q.source_item_code is not null),
           'without_library', count(*) filter (where q.reason = 'without_library'),
           'library_mismatch', count(*) filter (where q.reason = 'library_mismatch'),
           'library_without_numbering', count(*) filter (where q.reason = 'library_without_numbering'),
           'code_taken', count(*) filter (where q.reason = 'code_taken'),
           'code_twice', count(*) filter (where q.reason = 'code_twice'),
           'code_pending_elsewhere', count(*) filter (where q.reason = 'code_pending_elsewhere'),
           'problems', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'item_draft_id', p.id, 'draft_id', p.book_draft_id, 'titulo', p.titulo,
                      'source_item_code', p.source_item_code, 'reason', p.reason)
                    order by p.book_draft_id nulls last, p.id)
               from (select * from q where q.reason is not null
                      order by q.book_draft_id nulls last, q.id limit 40) p), '[]'::jsonb))
    into v_items_import
    from q;

  return jsonb_build_object(
    'batch', jsonb_build_object(
      'id', v_batch.id, 'name', v_batch.name, 'status', v_batch.status,
      'imported', public.fn_batch_is_imported(p_batch_id),
      'drafts_active', (select count(*) from public.fn_batch_live_drafts(p_batch_id)),
      'drafts_published', (select count(*) from public.book_drafts where batch_id = p_batch_id and status = 'published'),
      'drafts_cancelled', (select count(*) from public.book_drafts where batch_id = p_batch_id and status = 'cancelled'),
      'title_entries', v_title_n),
    'generated_at', now(),
    'coverage', v_coverage,
    'items', v_items_import,
    'conventions', v_conv,
    'duplicates', jsonb_build_object(
      'catalog_isbn', v_dup_isbn,
      'catalog_meta', v_dup_meta,
      'intra_lot', v_dup_intra,
      'import_matching', v_matching),
    'authorities', jsonb_build_object(
      'unlinked_count', v_unlinked_n,
      'linkable_count', v_linkable_n,
      'unlinked', v_unlinked),
    'totals', jsonb_build_object(
      'convention_issues', v_issues,
      'duplicates', jsonb_array_length(v_dup_isbn) + jsonb_array_length(v_dup_meta) + jsonb_array_length(v_dup_intra),
      'unlinked_authorities', v_unlinked_n)
  );
exception when others then
  -- Le contexte de l'erreur remonte a l'ecran : la prochaine panne dira ou.
  get stacked diagnostics v_ctx = pg_exception_context;
  -- Pas de HINT i18n ici : l'ecran afficherait la cle traduite et perdrait le
  -- message ; le texte brut, lui, dit ou ca casse.
  raise exception '% [%] @ %', sqlerrm, sqlstate, left(regexp_replace(v_ctx, E'\\s+', ' ', 'g'), 240)
    using errcode = sqlstate;
end;
$function$;

-- ── 6. Profils d'import : la correspondance des exemplaires (IMP-21 c) ────
-- DROP + CREATE (signature et type de retour changent) ; corps partis des
-- définitions réelles (md5 prod 215dc01a…, cd9db2cd…), même garde, même
-- message. items_mapping : { tag?, code, call_number, note, owner, item_type,
-- public, status } — lettres de sous-zones (1 à 4), '' pour couper une clé.
DROP FUNCTION IF EXISTS public.fn_import_profile_create(uuid, text, jsonb, jsonb);
CREATE FUNCTION public.fn_import_profile_create(
  p_library_id uuid, p_name text,
  p_column_mappings jsonb DEFAULT '{}'::jsonb,
  p_default_values jsonb DEFAULT '{}'::jsonb,
  p_items_mapping jsonb DEFAULT NULL::jsonb
) RETURNS jsonb
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path TO 'public', 'ingest', 'auth', 'pg_catalog'
AS $function$
DECLARE v_id bigint; v_map jsonb; v_def jsonb; v_items jsonb; v_k text; v_v jsonb;
BEGIN
  IF p_library_id IS NULL OR nullif(btrim(coalesce(p_name,'')), '') IS NULL THEN
    RAISE EXCEPTION 'library_id et name obligatoires.';
  END IF;
  IF NOT (
    EXISTS (SELECT 1 FROM public.user_library_memberships m
             WHERE m.user_id = auth.uid() AND m.library_id = p_library_id
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) THEN RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.'; END IF;
  v_map := coalesce(p_column_mappings, '{}'::jsonb);
  v_def := coalesce(p_default_values, '{}'::jsonb);
  IF jsonb_typeof(v_map) <> 'object' OR jsonb_typeof(v_def) <> 'object' THEN
    RAISE EXCEPTION 'column_mappings et default_values doivent être des objets JSON.';
  END IF;
  -- H19 : la correspondance des exemplaires, clé par clé, sinon NULL (défaut
  -- du dialecte, lu par l'EF). Liste fermée : une clé inconnue ou une valeur
  -- hors forme est refusée, pas ignorée.
  v_items := nullif(p_items_mapping, '{}'::jsonb);
  IF v_items IS NOT NULL THEN
    IF jsonb_typeof(v_items) <> 'object' THEN
      RAISE EXCEPTION 'items_mapping doit être un objet JSON.' USING HINT = 'error.import.items_mapping_invalid';
    END IF;
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(v_items) LOOP
      IF v_k NOT IN ('tag', 'code', 'call_number', 'note', 'owner', 'item_type', 'public', 'status')
         OR jsonb_typeof(v_v) <> 'string'
         OR (v_k = 'tag' AND (v_v #>> '{}') !~ '^[0-9]{3}$')
         OR (v_k <> 'tag' AND lower(v_v #>> '{}') !~ '^[0-9a-z]{0,4}$') THEN
        RAISE EXCEPTION 'items_mapping invalide (%).', v_k USING HINT = 'error.import.items_mapping_invalid';
      END IF;
    END LOOP;
  END IF;
  INSERT INTO ingest.import_profiles (library_id, name, column_mappings, default_values, items_mapping)
  VALUES (p_library_id, btrim(p_name), v_map, v_def, v_items)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'name', btrim(p_name));
END; $function$;
REVOKE EXECUTE ON FUNCTION public.fn_import_profile_create(uuid, text, jsonb, jsonb, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_import_profile_create(uuid, text, jsonb, jsonb, jsonb) TO authenticated, service_role;

DROP FUNCTION IF EXISTS public.fn_import_profiles_list(uuid);
CREATE FUNCTION public.fn_import_profiles_list(p_library_id uuid)
 RETURNS TABLE(id bigint, name text, column_mappings jsonb, default_values jsonb, items_mapping jsonb, created_at timestamp with time zone)
 LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth', 'pg_catalog'
AS $function$
BEGIN
  IF p_library_id IS NULL THEN RAISE EXCEPTION 'library_id obrigatorio.'; END IF;
  IF NOT (
    EXISTS (SELECT 1 FROM public.user_library_memberships m
             WHERE m.user_id = auth.uid() AND m.library_id = p_library_id
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) THEN RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.'; END IF;
  RETURN QUERY
    SELECT p.id, p.name, p.column_mappings, p.default_values, p.items_mapping, p.created_at
      FROM ingest.import_profiles p WHERE p.library_id = p_library_id ORDER BY p.name;
END; $function$;
REVOKE EXECUTE ON FUNCTION public.fn_import_profiles_list(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_import_profiles_list(uuid) TO authenticated, service_role;

-- ── 7. L'exemplaire importé suit sa notice ; ses liens ne s'écrivent pas à la main
-- (26-27/09/2026, revues contradictoires de H19)
--
-- a) Corbeille, restauration, changement de lot : un brouillon d'exemplaire
--    importé n'a pas de sens sans sa notice. Notice écartée → ses exemplaires
--    vivants aussi, marqués cancelled_with_record ; notice restaurée → CES
--    exemplaires-là reviennent, pas ceux qu'on avait écartés un par un avant
--    elle (un exemplaire perdu ou pilonné ne ressuscite pas) ; notice déplacée
--    dans un autre lot (« Affecter au lot ») → ils la suivent.
CREATE OR REPLACE FUNCTION public.tg_book_drafts_imported_items_follow()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.status = 'cancelled' THEN
      UPDATE public.exemplar_drafts x
         SET status = 'cancelled', cancelled_with_record = true, updated_at = now()
       WHERE x.book_draft_id = NEW.id AND x.status IN ('draft', 'ready');
    ELSIF OLD.status = 'cancelled' AND NEW.status IN ('draft', 'ready') THEN
      UPDATE public.exemplar_drafts x
         SET status = 'draft', cancelled_with_record = false, updated_at = now()
       WHERE x.book_draft_id = NEW.id AND x.status = 'cancelled' AND x.cancelled_with_record;
    END IF;
  END IF;
  IF NEW.batch_id IS DISTINCT FROM OLD.batch_id THEN
    UPDATE public.exemplar_drafts x
       SET batch_id = NEW.batch_id, updated_at = now()
     WHERE x.book_draft_id = NEW.id AND x.status IN ('draft', 'ready', 'cancelled');
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.tg_book_drafts_imported_items_follow() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS book_drafts_imported_items_follow ON public.book_drafts;
CREATE TRIGGER book_drafts_imported_items_follow
  AFTER UPDATE OF status, batch_id ON public.book_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_book_drafts_imported_items_follow();

-- b) Par l'API (rôle authenticated ou anon ; dans une fonction SECURITY
--    DEFINER, current_user est son propriétaire et rien de ceci ne s'applique) :
--    - book_draft_id et import_staging_row_id ne s'écrivent pas : un brouillon
--      ne s'accroche pas à la notice d'une autre bibliothèque (publish_book_draft
--      le publierait avec les droits de celle-ci), ni à une ligne importée
--      d'ailleurs (le déclencheur de dé-rapprochement en figerait la décision) ;
--    - un exemplaire rattaché à une notice garde son published_exemplar_id
--      (sinon « UPDATE » forgé vers l'exemplaire d'une autre bibliothèque) et
--      reste dans le lot de sa notice (rapport, réattribution, révision le
--      voient avec elle) ;
--    - restauré seul alors que sa notice est à la corbeille, il reviendra AVEC
--      elle (cancelled_with_record) au lieu de vivre sous une notice écartée
--      — que « Vider la corbeille » supprimerait, lui compris, par CASCADE.
--    Les gestes de masse de la file (restaurer, affecter au lot : un paquet
--    d'ids par requête) ne lèvent pas d'erreur : une erreur ferait échouer tout
--    le paquet, exemplaires ordinaires compris. Seul un lien forgé est refusé.
CREATE OR REPLACE FUNCTION public.tg_exemplar_drafts_import_links_locked()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  v_record_status text;
  v_record_batch bigint;
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.book_draft_id IS NOT NULL OR NEW.import_staging_row_id IS NOT NULL THEN
      RAISE EXCEPTION 'Vinculo de importacao reservado ao circuito de importacao.' USING ERRCODE = '42501';
    END IF;
    NEW.cancelled_with_record := false;
    RETURN NEW;
  END IF;
  IF NEW.book_draft_id IS DISTINCT FROM OLD.book_draft_id
     OR NEW.import_staging_row_id IS DISTINCT FROM OLD.import_staging_row_id THEN
    RAISE EXCEPTION 'Vinculo de importacao reservado ao circuito de importacao.' USING ERRCODE = '42501';
  END IF;
  NEW.cancelled_with_record := OLD.cancelled_with_record;
  IF NEW.book_draft_id IS NOT NULL THEN
    NEW.published_exemplar_id := OLD.published_exemplar_id;
    SELECT bd.status, bd.batch_id INTO v_record_status, v_record_batch
      FROM public.book_drafts bd WHERE bd.id = NEW.book_draft_id;
    IF NEW.batch_id IS DISTINCT FROM OLD.batch_id AND NEW.batch_id IS DISTINCT FROM v_record_batch THEN
      NEW.batch_id := OLD.batch_id;
    END IF;
    IF OLD.status = 'cancelled' AND NEW.status IN ('draft', 'ready') AND v_record_status = 'cancelled' THEN
      NEW.status := 'cancelled';
      NEW.cancelled_with_record := true;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.tg_exemplar_drafts_import_links_locked() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS exemplar_drafts_import_links_locked ON public.exemplar_drafts;
CREATE TRIGGER exemplar_drafts_import_links_locked
  BEFORE INSERT OR UPDATE ON public.exemplar_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_exemplar_drafts_import_links_locked();

-- Droits des fonctions recréées : inchangés (CREATE OR REPLACE les conserve),
-- réaffirmés pour les gardes (grants_herites T10/T12, ingest_ferme).
REVOKE EXECUTE ON FUNCTION public.publish_exemplar_draft(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_book_draft(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_catalog_batch(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_import_promote(bigint, text[], text[], text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_batch_reassign_library(bigint, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_batch_review_report(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION api.merge_book_drafts(bigint, bigint, jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION api.merge_draft_into_book(bigint, bigint, jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_audit_draft_deletion() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_restore_deleted_draft(bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_import_dispatch(bigint, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION ingest.fn_bulk_create_book_drafts_from_run(bigint, text[], text[], text, text, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid) FROM PUBLIC, anon, authenticated;
