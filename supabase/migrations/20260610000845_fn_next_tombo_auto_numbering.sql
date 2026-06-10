-- ════════════════════════════════════════════════════════════════════════════
-- Numérotation automatique des tombos (fn_next_tombo) + fallback à la publication
-- Auteur  : Claude (Opus)
-- Session : Enrichissement données & backlog
-- Date    : 2026-06-10 (UTC)
--
-- PROBLÈME (chantier 14) :
--   exemplares.tombo est NOT NULL + UNIQUE. attach_exemplar(p_tombo) accepte un
--   tombo optionnel ; si le staff ne le saisit pas, le brouillon a tombo = NULL
--   et publish_exemplar_draft lève une exception not-null brute. Aucune fonction
--   de numérotation n'existait en prod.
--
-- DÉCISION (validée avec la coordination, 2026-06-10) :
--   Config explicite par bibliothèque via libraries.tombo_pattern (jsonb).
--   Chaque biblio déclare : prefix, year (séquence par année oui/non),
--   sep (séparateur année↔numéro), pad (largeur de zéro-padding, 0 = aucun).
--   fn_next_tombo lit ce motif et renvoie le prochain numéro libre.
--
--   Motifs des 3 biblios actuelles (déduits des données existantes) :
--     BTL  : {prefix:'BTL-TL-EX-', year:false,           pad:6} → BTL-TL-EX-002364
--     MLEG : {prefix:'MLEG-',      year:true,  sep:'-',  pad:4} → MLEG-2026-0265
--     BLMF : {prefix:'CCLA.',      year:true,  sep:'.',  pad:0} → CCLA.2026.77
--
--   Un advisory lock transactionnel par biblio sérialise la génération
--   (deux publications concurrentes ne peuvent pas calculer le même max+1).
--   Le fallback est posé dans publish_exemplar_draft (point de passage commun
--   de TOUS les chemins de création d'exemplaire), pas seulement attach_exemplar.
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1. Config de motif de tombo par bibliothèque ──────────────────────────

ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS tombo_pattern jsonb;

COMMENT ON COLUMN public.libraries.tombo_pattern IS
  'Motif de numérotation des tombos : {prefix, year:bool, sep, pad:int}. '
  'fn_next_tombo génère le prochain tombo selon ce motif. NULL = pas de '
  'génération auto (le tombo doit alors être saisi manuellement).';

UPDATE public.libraries
   SET tombo_pattern = '{"prefix":"BTL-TL-EX-","year":false,"pad":6}'::jsonb
 WHERE id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a';

UPDATE public.libraries
   SET tombo_pattern = '{"prefix":"MLEG-","year":true,"sep":"-","pad":4}'::jsonb
 WHERE id = 'dfa87c64-4a2f-4a6d-9e92-646d90ac2b22';

UPDATE public.libraries
   SET tombo_pattern = '{"prefix":"CCLA.","year":true,"sep":".","pad":0}'::jsonb
 WHERE id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca';

-- ── 2. fn_next_tombo : prochain tombo libre pour une bibliothèque ─────────

CREATE OR REPLACE FUNCTION public.fn_next_tombo(p_library_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
declare
  v_pat         jsonb;
  v_prefix      text;
  v_use_year    boolean;
  v_sep         text;
  v_pad         int;
  v_full_prefix text;
  v_max         bigint;
  v_next        bigint;
  v_num_str     text;
begin
  select tombo_pattern into v_pat
    from public.libraries where id = p_library_id;

  if v_pat is null then
    raise exception 'tombo_pattern_not_configured'
      using errcode = 'P0001',
            hint = format('Nenhum padrão de tombo configurado para a biblioteca %s.', p_library_id);
  end if;

  v_prefix   := coalesce(v_pat->>'prefix', '');
  v_use_year := coalesce((v_pat->>'year')::boolean, false);
  v_sep      := coalesce(v_pat->>'sep', '');
  v_pad      := coalesce((v_pat->>'pad')::int, 0);

  -- Préfixe complet de recherche (avec année courante si séquence annuelle).
  v_full_prefix := v_prefix
    || case when v_use_year then to_char(current_date, 'YYYY') || v_sep else '' end;

  -- Sérialise la génération par biblio pour la durée de la transaction :
  -- deux publications concurrentes ne peuvent pas lire le même max+1.
  perform pg_advisory_xact_lock(hashtext('tombo:' || p_library_id::text));

  -- Plus grand numéro existant sous ce préfixe (séquence à trous tolérée).
  -- NB : les préfixes en prod ne contiennent ni '%' ni '_' → LIKE sûr sans escape.
  select coalesce(max(
           (substring(e.tombo from char_length(v_full_prefix) + 1))::bigint
         ), 0)
    into v_max
    from public.exemplares e
   where e.library_id = p_library_id
     and e.tombo like v_full_prefix || '%'
     and substring(e.tombo from char_length(v_full_prefix) + 1) ~ '^[0-9]+$';

  v_next := v_max + 1;
  v_num_str := case when v_pad > 0
                    then lpad(v_next::text, v_pad, '0')
                    else v_next::text end;

  return v_full_prefix || v_num_str;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_next_tombo(uuid) FROM PUBLIC;

-- ── 3. publish_exemplar_draft : fallback de tombo si le brouillon n'en a pas ─
-- (reprise exacte du corps en prod + calcul de v_final_tombo avant l'écriture)

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
  v_seed_policy text;                       -- P1.2 : seed circulation_policy
  v_final_tombo text;                       -- chantier 14 : tombo final (saisi ou auto)
begin
  perform public.sync_exemplar_draft_holdings_bridge(p_draft_id);

  select * into v_draft from public.exemplar_drafts where id = p_draft_id;
  if not found then
    raise exception 'Rascunho de exemplar não encontrado: %', p_draft_id;
  end if;
  if v_draft.status = 'cancelled' then
    raise exception 'Este rascunho de exemplar foi descartado.';
  end if;

  v_library_id := v_draft.target_library_id;

  if v_draft.target_holding_id is not null then
    select h.id, h.library_id,
           coalesce(nullif(trim(h.local_bib_ref), ''), b.bib_ref) as reference_code
      into v_holding
      from public.book_holdings h
      left join public.books b on b.id = h.book_id
     where h.id = v_draft.target_holding_id
       and (v_library_id is null or h.library_id = v_library_id)
     limit 1;
    if found then
      v_resolved_holding_id := v_holding.id;
      v_library_id := coalesce(v_holding.library_id, v_library_id);
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
       and ulm.is_primary = true
     limit 1;
  end if;

  if v_library_id is null then
    raise exception 'Nenhuma biblioteca ativa/principal encontrada para o usuário atual.';
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

  -- P1.2 + DOC-CIRC-1 : seed du padrão de circulation depuis la fiche (books.loanable).
  select case when b.loanable then 'ambos' else 'consulta' end   -- DOC-CIRC-1
    into v_seed_policy
    from public.book_holdings h
    join public.books b on b.id = h.book_id
   where h.id = v_resolved_holding_id;
  v_seed_policy := coalesce(v_seed_policy, 'consulta');

  -- Chantier 14 : tombo final. Si le brouillon n'en porte pas, on génère le
  -- prochain libre via fn_next_tombo (v_library_id est garanti non-null ici).
  v_final_tombo := nullif(btrim(coalesce(v_draft.tombo, '')), '');
  if v_final_tombo is null then
    v_final_tombo := public.fn_next_tombo(v_library_id);
  end if;

  if v_draft.published_exemplar_id is null then
    insert into public.exemplares (
      bib_ref,
      tombo,
      shelf_location,
      label_title_override,
      label_author_override,
      label_cdd_override,
      label_note,
      notes,
      library_id,
      holding_id,
      circulation_policy,                   -- P1.2
      visibility,                           -- P1.2
      acquisition_mode,                     -- acquisition
      acquisition_date,                     -- acquisition
      provenance_note,                      -- acquisition
      source_library,                       -- acquisition
      created_at,
      updated_at
    )
    values (
      coalesce(v_resolved_bib_ref, v_draft.target_bib_ref),
      v_final_tombo,
      v_draft.shelf_location,
      v_draft.label_title_override,
      v_draft.label_author_override,
      v_draft.label_cdd_override,
      v_draft.label_note,
      v_draft.notes,
      v_library_id,
      v_resolved_holding_id,
      coalesce(v_draft.circulation_policy, v_seed_policy),   -- P1.2
      coalesce(v_draft.visibility, 'public'),                -- P1.2
      v_draft.acquisition_mode,
      v_draft.acquisition_date,
      v_draft.provenance_note,
      v_draft.source_library,
      now(),
      now()
    )
    returning id into v_exemplar_id;
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
           library_id = coalesce(public.exemplares.library_id, v_library_id),
           holding_id = coalesce(v_resolved_holding_id, public.exemplares.holding_id),
           circulation_policy = coalesce(v_draft.circulation_policy, public.exemplares.circulation_policy),  -- P1.2
           visibility = coalesce(v_draft.visibility, public.exemplares.visibility),                          -- P1.2
           acquisition_mode = coalesce(v_draft.acquisition_mode, public.exemplares.acquisition_mode),
           acquisition_date = coalesce(v_draft.acquisition_date, public.exemplares.acquisition_date),
           provenance_note  = coalesce(v_draft.provenance_note,  public.exemplares.provenance_note),
           source_library   = coalesce(v_draft.source_library,   public.exemplares.source_library),
           updated_at = now()
     where id = v_draft.published_exemplar_id
    returning id into v_exemplar_id;
  end if;

  update public.exemplar_drafts
     set published_exemplar_id = v_exemplar_id,
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
