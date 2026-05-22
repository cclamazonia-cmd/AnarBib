-- ============================================================================
-- 20260522020000_peb_webhook_initiated_by.sql
-- ----------------------------------------------------------------------------
-- Chantier : notifications PEB (Edge Function notify-interlibrary-loan).
--
-- OBJET
--   Ajoute `initiated_by_library_id` a la payload JSON envoyee par
--   `fn_notify_emprestimo_interbibliotecas_webhook` vers l'Edge Function.
--
-- POURQUOI
--   L'EF notify-interlibrary-loan doit, pour l'evenement 'created',
--   distinguer la bibliotheque INITIATRICE (qui a declenche le flux) de la
--   bibliotheque PARTENAIRE, afin de leur envoyer deux contenus differents
--   (confirmation vs sollicitation). Cette information vit dans la colonne
--   `interlibrary_loans_v2.initiated_by_library_id`, mais la payload du
--   webhook ne la transmettait pas. Sans elle, l'EF retombe sur un envoi
--   symetrique (mode degrade). Cette migration la rend disponible.
--
-- METHODE
--   Une fonction PL/pgSQL ne se patche pas : on la recree entiere via
--   CREATE OR REPLACE. Le corps est identique a la version en production,
--   a deux ajouts pres :
--     1. `h.initiated_by_library_id` dans le SELECT ... INTO v_header ;
--     2. `'initiated_by_library_id', v_header.initiated_by_library_id`
--        dans l'objet 'loan' du jsonb_build_object.
--   Les attributs SECURITY DEFINER et SET search_path = 'public' sont
--   reconduits A L'IDENTIQUE (ne pas degrader la securite de la fonction).
--
-- PRIVILEGES (doctrine objets securises, chantier #150)
--   La fonction est DEJA durcie en production : proacl = postgres=X/postgres,
--   PUBLIC sans droit EXECUTE. Le bloc REVOKE/GRANT ci-dessous est donc
--   strictement IDEMPOTENT — il ne modifie aucun privilege reel, il rend
--   l'etat de securite explicite dans la migration (auto-documentation) et
--   satisfait le hook pre-commit sans recours a --no-verify.
--
-- VERIFICATION
--   Un bloc DO en fin de migration controle (a) que la colonne source
--   existe, (b) que la nouvelle definition contient `initiated_by_library_id`,
--   (c) que PUBLIC n'a PAS le droit EXECUTE sur la fonction. Tout echec
--   -> RAISE EXCEPTION -> rollback automatique de la transaction.
--
-- PIPELINE
--   Fichier depose dans supabase/migrations/, applique par Woodpecker via
--   `supabase db push --linked`. Ne PAS executer a la main dans le SQL
--   Editor avant le push (doctrine : timestamp = ordre d'application).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_notify_emprestimo_interbibliotecas_webhook(p_notification_event_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_event record;
  v_header record;
  v_items jsonb := '[]'::jsonb;
  v_webhook_url text;
  v_webhook_secret text;
  v_request_id bigint;
  v_body jsonb;
begin
  select
    e.id,
    e.interlibrary_loan_id,
    e.event_type,
    e.event_key,
    e.status_snapshot,
    e.payload_snapshot,
    e.pgnet_request_id,
    e.created_at
  into v_event
  from public.interlibrary_loan_notification_events e
  where e.id = p_notification_event_id;

  if v_event.id is null then
    raise exception 'Notification event % introuvable.', p_notification_event_id;
  end if;

  if v_event.pgnet_request_id is not null then
    return v_event.pgnet_request_id;
  end if;

  select decrypted_secret
    into v_webhook_url
  from vault.decrypted_secrets
  where name = 'NOTIFY_INTERLIBRARY_LOAN_WEBHOOK_URL'
  order by created_at desc
  limit 1;

  select decrypted_secret
    into v_webhook_secret
  from vault.decrypted_secrets
  where name = 'NOTIFY_INTERLIBRARY_LOAN_WEBHOOK_SECRET'
  order by created_at desc
  limit 1;

  if nullif(trim(coalesce(v_webhook_url, '')), '') is null then
    raise exception 'Secret vault NOTIFY_INTERLIBRARY_LOAN_WEBHOOK_URL absent.';
  end if;

  if nullif(trim(coalesce(v_webhook_secret, '')), '') is null then
    raise exception 'Secret vault NOTIFY_INTERLIBRARY_LOAN_WEBHOOK_SECRET absent.';
  end if;

  select
    h.id,
    h.request_id,
    h.status_global,
    h.start_date,
    h.due_date,
    h.dispatched_at,
    h.return_started_at,
    h.returned_at,
    h.lender_library_id,
    ll.name as lender_library_name,
    ll.short_name as lender_library_short_name,
    h.borrower_library_id,
    bl.name as borrower_library_name,
    bl.short_name as borrower_library_short_name,
    -- AJOUT 20260522020000 : bibliotheque a l'origine du flux PEB.
    h.initiated_by_library_id,
    h.coordination_contact_name,
    h.coordination_contact_email,
    h.coordination_contact_phone,
    h.logistics_mode,
    h.meeting_point,
    h.notes,
    h.created_at,
    h.updated_at
  into v_header
  from public.interlibrary_loans_v2 h
  left join public.libraries ll
    on ll.id = h.lender_library_id
  left join public.libraries bl
    on bl.id = h.borrower_library_id
  where h.id = v_event.interlibrary_loan_id;

  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'line_no', i.line_no,
               'sub_id', i.sub_id,
               'item_id', i.item_id,
               'holding_id', i.holding_id,
               'bib_ref', i.bib_ref,
               'tombo', i.rotulo_cache,
               'titulo', i.titulo_cache,
               'autor', i.autor_cache,
               'item_status', i.item_status,
               'due_date', i.due_date,
               'returned_at', i.returned_at
             )
             order by i.line_no
           ),
           '[]'::jsonb
         )
    into v_items
  from public.interlibrary_loan_items_v2 i
  where i.interlibrary_loan_id = v_event.interlibrary_loan_id;

  v_body := jsonb_build_object(
    'source', 'supabase-db',
    'kind', 'interlibrary-loan',
    'event_id', v_event.id,
    'event_type', v_event.event_type,
    'event_key', v_event.event_key,
    'created_at', v_event.created_at,
    'loan', jsonb_build_object(
      'id', v_header.id,
      'request_id', v_header.request_id,
      'status_global', v_header.status_global,
      'start_date', v_header.start_date,
      'due_date', v_header.due_date,
      'dispatched_at', v_header.dispatched_at,
      'return_started_at', v_header.return_started_at,
      'returned_at', v_header.returned_at,
      'lender_library_id', v_header.lender_library_id,
      'lender_library_name', v_header.lender_library_name,
      'lender_library_short_name', v_header.lender_library_short_name,
      'borrower_library_id', v_header.borrower_library_id,
      'borrower_library_name', v_header.borrower_library_name,
      'borrower_library_short_name', v_header.borrower_library_short_name,
      -- AJOUT 20260522020000 : transmis a l'EF pour la matrice 'created'
      -- (distinction initiatrice / partenaire).
      'initiated_by_library_id', v_header.initiated_by_library_id,
      'coordination_contact_name', v_header.coordination_contact_name,
      'coordination_contact_email', v_header.coordination_contact_email,
      'coordination_contact_phone', v_header.coordination_contact_phone,
      'logistics_mode', v_header.logistics_mode,
      'meeting_point', v_header.meeting_point,
      'notes', v_header.notes
    ),
    'items', v_items
  );

  select net.http_post(
    url := v_webhook_url,
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-webhook-secret', v_webhook_secret
    ),
    body := v_body
  )
  into v_request_id;

  update public.interlibrary_loan_notification_events e
     set pgnet_request_id = v_request_id
   where e.id = p_notification_event_id;

  return v_request_id;
end;
$function$;

-- ─── Privileges (doctrine objets securises #150) ────────────────────────────
-- Bloc IDEMPOTENT : la fonction est deja durcie en production
-- (proacl = postgres=X/postgres, PUBLIC sans droit EXECUTE). On reconduit
-- cet etat explicitement — la migration devient auto-documentee et le hook
-- pre-commit passe sans --no-verify. Aucun privilege reel n'est modifie.
REVOKE EXECUTE ON FUNCTION public.fn_notify_emprestimo_interbibliotecas_webhook(bigint) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_notify_emprestimo_interbibliotecas_webhook(bigint)
  TO postgres;

-- ─── Verification post-migration (doctrine : bloc DO en fin de transaction) ──
-- Tout echec ici provoque un RAISE EXCEPTION, donc un rollback automatique :
-- la migration ne s'applique que si les trois controles passent.
DO $verif$
declare
  v_col_exists boolean;
  v_def text;
  v_public_can_execute boolean;
begin
  -- (a) La colonne source doit exister sur interlibrary_loans_v2.
  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'interlibrary_loans_v2'
      and column_name = 'initiated_by_library_id'
  ) into v_col_exists;

  if not v_col_exists then
    raise exception
      'Verification echouee : colonne interlibrary_loans_v2.initiated_by_library_id absente.';
  end if;

  -- (b) La nouvelle definition de la fonction doit contenir le champ ajoute.
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'fn_notify_emprestimo_interbibliotecas_webhook';

  if v_def is null then
    raise exception
      'Verification echouee : fonction fn_notify_emprestimo_interbibliotecas_webhook introuvable.';
  end if;

  if position('initiated_by_library_id' in v_def) = 0 then
    raise exception
      'Verification echouee : la nouvelle definition ne contient pas initiated_by_library_id.';
  end if;

  -- (c) PUBLIC ne doit PAS pouvoir executer la fonction (doctrine #150).
  select has_function_privilege(
           'public',
           'public.fn_notify_emprestimo_interbibliotecas_webhook(bigint)',
           'EXECUTE'
         ) into v_public_can_execute;

  if v_public_can_execute then
    raise exception
      'Verification echouee : PUBLIC a le droit EXECUTE sur la fonction (doctrine #150 violee).';
  end if;

  raise notice 'Migration 20260522020000 : verification OK (colonne presente, fonction a jour, PUBLIC sans EXECUTE).';
end;
$verif$;
