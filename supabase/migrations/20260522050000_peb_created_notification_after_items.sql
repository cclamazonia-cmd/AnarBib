-- ============================================================================
-- 20260522050000_peb_created_notification_after_items.sql
-- ----------------------------------------------------------------------------
-- Chantier #ILL-partial — correctif « 0 document » du mail de creation.
--
-- PROBLEME
--   fn_peb_create_loan_with_items insere d'abord le pret dans
--   interlibrary_loans_v2, PUIS les exemplaires dans
--   interlibrary_loan_items_v2. L'INSERT du pret declenche immediatement
--   le trigger AFTER INSERT trg_interlibrary_loan_enqueue_notifications,
--   qui emet l'evenement 'created'. A cet instant, AUCUN exemplaire n'est
--   encore en base : la payload du webhook compte 0 item, et le mail de
--   creation affiche « Numero de documentos : 0 » alors que le pret en a.
--
--   C'est un bug d'ordre d'operations : la notification part avant que les
--   donnees soient completes (cf. doctrine #141.2.E sur l'ordre des
--   ecritures quand des triggers sont impliques).
--
-- CORRECTIF
--   1. Le trigger trg_interlibrary_loan_enqueue_notifications est recree
--      SANS la branche tg_op = 'INSERT'. Il ne gere plus que les UPDATE de
--      status_global. L'INSERT d'un pret n'emet donc plus de notification
--      automatique.
--   2. fn_peb_create_loan_with_items est recree a l'identique, avec un bloc
--      final — APRES la boucle d'insertion des items — qui emet
--      explicitement l'evenement 'created'. A ce point, les exemplaires
--      sont tous en base (meme transaction), donc la payload les compte.
--
--   Mode TOLERANT : l'emission de la notification est enveloppee dans un
--   bloc EXCEPTION. Si fn_notify_..._webhook echoue (reseau, secret), le
--   pret est tout de meme cree — la creation, acte metier essentiel, n'est
--   pas annulee par une panne mail. L'echec est seulement signale par un
--   RAISE WARNING.
--
-- HYPOTHESE
--   fn_peb_create_loan_with_items est l'unique chemin de creation d'un PEB
--   (le frontend BibliotecaPage.saveIll appelle cette RPC ; chantier EA-12
--   phase 1 a bascule la creation dessus). Si un autre chemin de creation
--   apparait un jour, il devra emettre 'created' lui-meme.
--
-- VERIFICATION
--   Bloc DO : confirme l'absence de branche INSERT dans le trigger et la
--   presence de l'emission 'created' dans la RPC.
-- ============================================================================


-- ============================================================================
-- PARTIE 1 — Trigger de notification SANS la branche INSERT
-- ============================================================================
-- Recree a l'identique de la version 20260522030000, MOINS le bloc
-- if tg_op = 'INSERT'. SECURITY DEFINER + search_path reconduits.
CREATE OR REPLACE FUNCTION public.trg_interlibrary_loan_enqueue_notifications()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_event_id bigint;
begin
  -- NOTE 20260522050000 (#ILL-partial) : la gestion de l'evenement de
  -- creation a ete retiree de ce trigger. L'evenement est desormais emis
  -- explicitement par fn_peb_create_loan_with_items, APRES insertion des
  -- exemplaires, pour que la payload compte correctement les documents.
  -- Ce trigger ne gere plus que les changements de status_global (UPDATE).

  if tg_op = 'UPDATE' then
    if old.status_global is distinct from new.status_global then
      if new.status_global = 'aguardando_saida' then
        v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
          new.id,
          'interlibrary_loan_prepared',
          'prepared'
        );
        perform public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);

      elsif new.status_global = 'emprestado' then
        v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
          new.id,
          'interlibrary_loan_dispatched',
          'dispatched'
        );
        perform public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);

      elsif new.status_global = 'em_devolucao' then
        v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
          new.id,
          'interlibrary_loan_return_started',
          'return_started'
        );
        perform public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);

      elsif new.status_global = 'devolvido' then
        v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
          new.id,
          'interlibrary_loan_returned',
          'returned'
        );
        perform public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);

      elsif new.status_global = 'parcialmente_devolvido' then
        v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
          new.id,
          'interlibrary_loan_partially_returned',
          'partially_returned'
        );
        perform public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);

      elsif new.status_global = 'cancelado' then
        v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
          new.id,
          'interlibrary_loan_cancelled',
          'cancelled'
        );
        perform public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);

      elsif new.status_global = 'atrasado' then
        v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
          new.id,
          'interlibrary_loan_overdue',
          'overdue'
        );
        perform public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);
      end if;
    end if;

    return new;
  end if;

  return new;
end;
$function$;


-- ============================================================================
-- PARTIE 2 — RPC de creation : emet 'created' APRES les items (tolerant)
-- ============================================================================
-- Recree a l'identique de la version courante, avec un bloc final ajoute
-- juste avant le RETURN : emission explicite de l'evenement 'created'.
CREATE OR REPLACE FUNCTION public.fn_peb_create_loan_with_items(p_loan jsonb, p_items jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_new_loan interlibrary_loans_v2%ROWTYPE;
  v_new_items jsonb;
  v_item jsonb;
  v_event_id bigint;
BEGIN
  -- Validation minimale : les champs obligatoires doivent être présents
  IF (p_loan->>'lender_library_id') IS NULL
     OR (p_loan->>'borrower_library_id') IS NULL
     OR (p_loan->>'initiated_by_library_id') IS NULL
  THEN
    RAISE EXCEPTION 'fn_peb_create_loan_with_items: champs obligatoires manquants (lender, borrower, initiated_by)';
  END IF;

  -- INSERT du loan. La RLS interlibrary_loans_v2_insert vérifie automatiquement :
  --   - user_can_manage_library(lender OR borrower)
  --   - fn_peb_authorized(lender, borrower)
  -- Si une de ces conditions échoue, l'INSERT lève une erreur RLS.
  INSERT INTO interlibrary_loans_v2 (
    request_id,
    lender_library_id,
    borrower_library_id,
    initiated_by_library_id,
    status_global,
    start_date,
    due_date,
    coordination_contact_name,
    coordination_contact_email,
    coordination_contact_phone,
    logistics_mode,
    meeting_point,
    notes,
    metadata,
    created_by
  )
  VALUES (
    NULLIF(p_loan->>'request_id', '')::uuid,
    (p_loan->>'lender_library_id')::uuid,
    (p_loan->>'borrower_library_id')::uuid,
    (p_loan->>'initiated_by_library_id')::uuid,
    COALESCE(p_loan->>'status_global', 'preparacao'),
    NULLIF(p_loan->>'start_date', '')::date,
    NULLIF(p_loan->>'due_date', '')::date,
    p_loan->>'coordination_contact_name',
    p_loan->>'coordination_contact_email',
    p_loan->>'coordination_contact_phone',
    p_loan->>'logistics_mode',
    p_loan->>'meeting_point',
    p_loan->>'notes',
    COALESCE(p_loan->'metadata', '{}'::jsonb),
    auth.uid()
  )
  RETURNING * INTO v_new_loan;

  -- INSERT des items (si fournis)
  IF jsonb_array_length(p_items) > 0 THEN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
      -- Validation minimale par item
      IF (v_item->>'line_no') IS NULL
         OR (v_item->>'holding_id') IS NULL
         OR (v_item->>'item_id') IS NULL
         OR (v_item->>'bib_ref') IS NULL
      THEN
        RAISE EXCEPTION 'fn_peb_create_loan_with_items: item invalide (line_no, holding_id, item_id, bib_ref obligatoires) — item: %', v_item;
      END IF;

      -- La RLS interlibrary_loan_items_v2_insert vérifie automatiquement
      -- l'EXISTS sur la table parente (loan créée juste au-dessus).
      -- CORRECTIF 20260522010000 : la colonne sub_id (GENERATED ALWAYS)
      -- est retiree de l'INSERT - Postgres la calcule lui-meme.
      INSERT INTO interlibrary_loan_items_v2 (
        interlibrary_loan_id,
        line_no,
        book_id,
        holding_id,
        item_id,
        bib_ref,
        rotulo_cache,
        titulo_cache,
        autor_cache,
        editora_cache,
        ano_cache,
        item_status,
        notes,
        metadata
      )
      VALUES (
        v_new_loan.id,
        (v_item->>'line_no')::integer,
        NULLIF(v_item->>'book_id', '')::bigint,
        (v_item->>'holding_id')::bigint,
        (v_item->>'item_id')::bigint,
        v_item->>'bib_ref',
        v_item->>'rotulo_cache',
        v_item->>'titulo_cache',
        v_item->>'autor_cache',
        v_item->>'editora_cache',
        v_item->>'ano_cache',
        COALESCE(v_item->>'item_status', 'reservado_para_saida'),
        v_item->>'notes',
        COALESCE(v_item->'metadata', '{}'::jsonb)
      );
    END LOOP;
  END IF;

  -- Récupère les items créés pour les retourner
  SELECT COALESCE(jsonb_agg(to_jsonb(i.*) ORDER BY i.line_no), '[]'::jsonb)
  INTO v_new_items
  FROM interlibrary_loan_items_v2 i
  WHERE i.interlibrary_loan_id = v_new_loan.id;

  -- ─── Emission de l'evenement 'created' (#ILL-partial 20260522050000) ──────
  -- A ce point, le pret ET tous ses exemplaires sont en base, dans la meme
  -- transaction : fn_notify_..._webhook comptera correctement les documents.
  -- Mode TOLERANT : un echec d'emission ne doit PAS annuler la creation du
  -- pret. On enveloppe dans un bloc EXCEPTION ; en cas d'echec, RAISE WARNING
  -- et on poursuit.
  BEGIN
    v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
      v_new_loan.id,
      'interlibrary_loan_created',
      'created'
    );
    perform public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'fn_peb_create_loan_with_items: pret % cree, mais emission de la notification ''created'' echouee (%). Le pret est conserve.', v_new_loan.id, SQLERRM;
  END;

  RETURN jsonb_build_object(
    'loan', to_jsonb(v_new_loan),
    'items', v_new_items
  );
END;
$function$;


-- ============================================================================
-- PRIVILEGES (doctrine objets securises #150)
-- ============================================================================
-- trg_interlibrary_loan_enqueue_notifications : recreee, bloc idempotent.
REVOKE EXECUTE ON FUNCTION public.trg_interlibrary_loan_enqueue_notifications() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.trg_interlibrary_loan_enqueue_notifications() TO postgres;

-- fn_peb_create_loan_with_items : recreee. On reconduit a l'identique son
-- profil d'origine (cf. pg_proc : postgres, anon, authenticated, service_role).
-- Note : ce profil large est anterieur a la doctrine #150 ; son alignement
-- est suivi en backlog (#ILL-rpc-anon). Cette migration ne le modifie pas,
-- pour ne pas changer le comportement hors de son perimetre.
GRANT EXECUTE ON FUNCTION public.fn_peb_create_loan_with_items(jsonb, jsonb) TO anon, authenticated, service_role;


-- ============================================================================
-- VERIFICATION POST-MIGRATION
-- ============================================================================
DO $verif$
declare
  v_trg_def text;
  v_rpc_def text;
begin
  -- (a) Le trigger ne contient plus la branche INSERT.
  -- On cherche la structure de controle complete 'if tg_op = ''INSERT'' then'
  -- (avec if et then) : ce motif n'apparait que dans du code executable,
  -- jamais dans une phrase de commentaire — evite le faux positif.
  select pg_get_functiondef(p.oid) into v_trg_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'trg_interlibrary_loan_enqueue_notifications';

  if v_trg_def is null then
    raise exception 'Verification echouee : trigger de notification absent.';
  end if;
  if position('if tg_op = ''INSERT'' then' in lower(v_trg_def)) > 0 then
    raise exception 'Verification echouee : la branche INSERT est toujours dans le trigger.';
  end if;

  -- (b) La RPC emet bien l'evenement 'created'.
  select pg_get_functiondef(p.oid) into v_rpc_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'fn_peb_create_loan_with_items';

  if v_rpc_def is null then
    raise exception 'Verification echouee : fn_peb_create_loan_with_items absente.';
  end if;
  if position('interlibrary_loan_created' in v_rpc_def) = 0 then
    raise exception 'Verification echouee : la RPC n''emet pas l''evenement created.';
  end if;
  -- Le bloc EXCEPTION de tolerance doit etre present.
  if position('EXCEPTION WHEN OTHERS' in v_rpc_def) = 0 then
    raise exception 'Verification echouee : bloc de tolerance EXCEPTION absent de la RPC.';
  end if;

  raise notice 'Migration 20260522050000 : verification OK (trigger sans INSERT, RPC emet created en mode tolerant).';
end;
$verif$;
