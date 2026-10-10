-- C29 lot 3 (10/10/2026) — « Modifier » un exemplaire publié sans voir le brouillon.
--
-- Jusqu'ici, changer la cote d'un exemplaire publié prenait six gestes : onglet
-- Catalogue → Exemplaires → chercher le numéro → « Reprendre » (un brouillon par
-- create_exemplar_draft_from_exemplar) → l'éditeur → « Publier ». Le modèle de
-- l'application reste le brouillon (file, traçabilité, lots) ; on cesse
-- seulement de l'imposer à l'écran : UNE fonction enchaîne, dans une seule
-- transaction, la reprise, la mise à jour des champs permis et la publication
-- par publish_exemplar_draft TEL QUEL — toutes les gardes de la base
-- s'appliquent (staff de la bibliothèque, numéro jamais redonné, fonds de la
-- bibliothèque). Si la publication échoue, rien ne reste : pas de brouillon
-- orphelin. Le brouillon publié reste comme trace (published_exemplar_id).
--
-- Ce que la fonction NE permet pas, à dessein : changer le numéro
-- d'inventaire (C17 : un numéro ne se redonne jamais ; le chemin de rejeu de
-- publish_exemplar_draft reste le sien), changer de bibliothèque (une
-- réattribution se confirme dans l'éditeur complet, #cross-lib-reassign),
-- toucher un exemplaire qui a DÉJÀ un brouillon de mise à jour vivant (la
-- reprise se poursuit dans l'éditeur ; deux brouillons pour un exemplaire,
-- c'est le défaut que le lot 1 a fermé à l'écran).
--
-- Au passage, un défaut de la reprise : create_exemplar_draft_from_exemplar ne
-- copiait ni circulation_policy ni visibility ; le brouillon naissait « public »
-- (défaut NOT NULL) et publish_exemplar_draft écrit coalesce(brouillon, …) → un
-- exemplaire « équipe uniquement » repassait PUBLIC à la republication, et
-- l'éditeur montrait « Public » à la reprise. Les deux colonnes sont copiées
-- désormais (définition repartie de la production, identique au dépôt).
--
-- Droits : DEFINER, search_path figé, EXECUTE à authenticated et service_role,
-- fermée à PUBLIC et anon (T10/T12 de grants_herites_tests inchangés).
-- Suite : tests/sql/c29_exemplaire_modifier_et_publier_tests.sql.
-- Complément à docs/journal/audits/AUDIT_execute_authenticated_2026-09-01.md.

-- ── 1. La reprise copie circulation et visibilité ───────────────────────────
CREATE OR REPLACE FUNCTION public.create_exemplar_draft_from_exemplar(p_exemplar_id bigint, p_batch_id bigint DEFAULT NULL::bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id bigint;
begin
  -- B29 (CAT-E18) : on ne reprend que les exemplaires de ses bibliothèques.
  if exists (select 1 from public.exemplares e where e.id = p_exemplar_id)
     and not public.fn_caller_can_edit_draft_library(
               (select e.library_id from public.exemplares e where e.id = p_exemplar_id), null) then
    raise exception 'Exemplar de outra biblioteca.' using hint = 'error.catalog.draft_other_library';
  end if;
  -- B30 : dans un lot de la bibliothèque de l'exemplaire.
  if p_batch_id is not null and not public.fn_caller_can_range_in_batch(p_batch_id,
       (select e.library_id from public.exemplares e where e.id = p_exemplar_id)) then
    if public.fn_caller_can_see_batch(p_batch_id) then   -- B30
      raise exception 'Rascunho de outra biblioteca do que a do lote.' using errcode = '42501', hint = 'error.batch.library_mismatch';
    end if;
    raise exception 'Lote com rascunhos de outras bibliotecas.' using hint = 'error.batch.other_libraries';
  end if;
  insert into public.exemplar_drafts (
    published_exemplar_id,
    batch_id,
    action,
    status,
    label_status,
    target_bib_ref,
    target_library_id,
    target_holding_id,
    tombo,
    shelf_location,
    label_title_override,
    label_author_override,
    label_cdd_override,
    label_note,
    notes,
    acquisition_mode,
    acquisition_date,
    provenance_note,
    source_library,
    circulation_policy,      -- C29 lot 3 : ce que l'exemplaire a, le brouillon le reprend
    visibility,              -- C29 lot 3 : idem (« équipe uniquement » ne repasse plus public)
    created_by,
    updated_by
  )
  select
    e.id,
    p_batch_id,
    'update',
    'draft',
    'pending',
    coalesce(
      nullif(trim(h.local_bib_ref), ''),
      rb.local_bib_ref,
      b_holding.bib_ref,
      b_legacy.bib_ref,
      e.bib_ref
    ) as target_bib_ref,
    e.library_id as target_library_id,
    coalesce(e.holding_id, rb.holding_id) as target_holding_id,
    e.tombo,
    e.shelf_location,
    e.label_title_override,
    e.label_author_override,
    e.label_cdd_override,
    e.label_note,
    e.notes,
    e.acquisition_mode,
    e.acquisition_date,
    e.provenance_note,
    e.source_library,
    e.circulation_policy,
    coalesce(e.visibility, 'public'),
    auth.uid(),
    auth.uid()
  from public.exemplares e
  left join public.book_holdings h
    on h.id = e.holding_id
  left join public.books b_holding
    on b_holding.id = h.book_id
  left join lateral public.resolve_library_holding_bridge(e.library_id, e.bib_ref) rb
    on e.holding_id is null
  left join public.books b_legacy
    on e.holding_id is null
   and rb.holding_id is null
   and b_legacy.bib_ref = e.bib_ref
  where e.id = p_exemplar_id
  returning id into v_id;

  if v_id is null then
    raise exception 'Exemplar não encontrado: %', p_exemplar_id;
  end if;

  perform public.sync_exemplar_draft_holdings_bridge(v_id);

  return v_id;
end;
$function$;

-- ── 2. Modifier et publier en un geste ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_exemplaire_modifier_et_publier(p_exemplar_id bigint, p_changes jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_lib     uuid;
  v_draft   bigint;
  v_pending bigint;
  v_ex      bigint;
  v_key     text;
  -- Les champs qu'un exemplaire publié peut changer ici. Ni tombo (C17), ni
  -- bibliothèque (réattribution confirmée dans l'éditeur complet), ni fonds.
  c_permis CONSTANT text[] := ARRAY[
    'shelf_location', 'circulation_policy', 'visibility', 'notes',
    'acquisition_mode', 'acquisition_date', 'provenance_note', 'source_library',
    'label_title_override', 'label_author_override', 'label_cdd_override', 'label_note'
  ];
BEGIN
  SELECT e.library_id INTO v_lib FROM public.exemplares e WHERE e.id = p_exemplar_id;
  IF v_lib IS NULL THEN
    RAISE EXCEPTION 'Exemplar não encontrado: %', p_exemplar_id USING HINT = 'error.copies.not_found';
  END IF;
  -- Même garde que la reprise : staff de la bibliothèque de l'exemplaire, ou
  -- administration du réseau. auth.uid() nul → faux.
  IF NOT coalesce(public.fn_caller_can_edit_draft_library(v_lib, NULL), false) THEN
    RAISE EXCEPTION 'Exemplar de outra biblioteca.' USING ERRCODE = '42501', HINT = 'error.catalog.draft_other_library';
  END IF;
  IF p_changes IS NULL OR jsonb_typeof(p_changes) <> 'object' THEN
    RAISE EXCEPTION 'Alterações inválidas.' USING ERRCODE = '22023', HINT = 'error.copies.changes_invalid';
  END IF;
  FOR v_key IN SELECT jsonb_object_keys(p_changes) LOOP
    IF NOT (v_key = ANY (c_permis)) THEN
      RAISE EXCEPTION 'Campo não editável aqui: %', v_key USING ERRCODE = '22023', HINT = 'error.copies.field_not_allowed';
    END IF;
  END LOOP;
  -- Un brouillon de mise à jour vivant existe déjà : il se poursuit dans
  -- l'éditeur, on n'en ouvre pas un second.
  SELECT d.id INTO v_pending
    FROM public.exemplar_drafts d
   WHERE d.published_exemplar_id = p_exemplar_id
     AND d.status IN ('draft', 'ready')
     AND NOT d.retake_untouched
   LIMIT 1;
  IF v_pending IS NOT NULL THEN
    RAISE EXCEPTION 'Este exemplar já tem um rascunho de atualização (%).', v_pending USING HINT = 'error.copies.update_pending';
  END IF;

  v_draft := public.create_exemplar_draft_from_exemplar(p_exemplar_id, NULL);

  -- Seuls les champs PRÉSENTS dans p_changes changent ; une valeur vide efface.
  UPDATE public.exemplar_drafts d
     SET shelf_location        = CASE WHEN p_changes ? 'shelf_location'        THEN nullif(btrim(p_changes->>'shelf_location'), '')        ELSE d.shelf_location END,
         circulation_policy    = CASE WHEN p_changes ? 'circulation_policy'    THEN nullif(btrim(p_changes->>'circulation_policy'), '')    ELSE d.circulation_policy END,
         visibility            = CASE WHEN p_changes ? 'visibility'            THEN coalesce(nullif(btrim(p_changes->>'visibility'), ''), 'public') ELSE d.visibility END,
         notes                 = CASE WHEN p_changes ? 'notes'                 THEN nullif(btrim(p_changes->>'notes'), '')                 ELSE d.notes END,
         acquisition_mode      = CASE WHEN p_changes ? 'acquisition_mode'      THEN nullif(btrim(p_changes->>'acquisition_mode'), '')      ELSE d.acquisition_mode END,
         acquisition_date      = CASE WHEN p_changes ? 'acquisition_date'      THEN nullif(btrim(p_changes->>'acquisition_date'), '')::date ELSE d.acquisition_date END,
         provenance_note       = CASE WHEN p_changes ? 'provenance_note'       THEN nullif(btrim(p_changes->>'provenance_note'), '')       ELSE d.provenance_note END,
         source_library        = CASE WHEN p_changes ? 'source_library'        THEN nullif(btrim(p_changes->>'source_library'), '')        ELSE d.source_library END,
         label_title_override  = CASE WHEN p_changes ? 'label_title_override'  THEN nullif(btrim(p_changes->>'label_title_override'), '')  ELSE d.label_title_override END,
         label_author_override = CASE WHEN p_changes ? 'label_author_override' THEN nullif(btrim(p_changes->>'label_author_override'), '') ELSE d.label_author_override END,
         label_cdd_override    = CASE WHEN p_changes ? 'label_cdd_override'    THEN nullif(btrim(p_changes->>'label_cdd_override'), '')    ELSE d.label_cdd_override END,
         label_note            = CASE WHEN p_changes ? 'label_note'            THEN nullif(btrim(p_changes->>'label_note'), '')            ELSE d.label_note END,
         updated_by            = auth.uid()
   WHERE d.id = v_draft;

  v_ex := public.publish_exemplar_draft(v_draft);
  RETURN v_ex;
END;
$function$;

COMMENT ON FUNCTION public.fn_exemplaire_modifier_et_publier(bigint, jsonb) IS
  'C29 lot 3 : modifie un exemplaire publié et le republie en une transaction (reprise → champs permis → publish_exemplar_draft). Ni tombo, ni bibliothèque. Staff de la bibliothèque ou administration du réseau.';

REVOKE ALL ON FUNCTION public.fn_exemplaire_modifier_et_publier(bigint, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_exemplaire_modifier_et_publier(bigint, jsonb) TO authenticated, service_role;
