-- ============================================================================
-- 20260522040000_peb_event_type_partially_returned.sql
-- ----------------------------------------------------------------------------
-- Chantier #ILL-partial — correctif.
--
-- PROBLEME
--   La migration 20260522030000 a ajoute la branche 'parcialmente_devolvido'
--   au trigger de notification, qui emet l'event_type
--   'interlibrary_loan_partially_returned'. Mais la table
--   interlibrary_loan_notification_events porte un CHECK sur event_type
--   (interlibrary_loan_notification_events_type_chk) qui n'autorise pas
--   cette valeur. Resultat : a la premiere consolidation en retour partiel,
--   l'INSERT dans la file d'evenements echoue (SQLSTATE 23514), ce qui
--   annule toute la transaction de fn_peb_update_item_status.
--
-- CORRECTIF
--   Recree le CHECK avec 'interlibrary_loan_partially_returned' ajoute a la
--   liste. Les huit types existants sont reconduits a l'identique :
--     created, prepared, dispatched, due_soon, overdue,
--     return_started, returned, cancelled
--   + le neuvieme : partially_returned.
--
--   Note : 'interlibrary_loan_due_soon' est conserve bien qu'aucun trigger
--   ne l'emette aujourd'hui (type prevu, non cable — vestige inoffensif).
--   'interlibrary_loan_overdue' etait deja dans le CHECK : aucune action
--   requise pour cette branche dormante.
--
-- METHODE
--   DROP puis ADD du CHECK (un CHECK ne se modifie pas en place). Operation
--   sur contrainte uniquement, aucune donnee touchee. Les lignes existantes
--   de la table portent toutes un event_type deja valide : le ADD ne peut
--   pas echouer sur l'existant.
--
-- VERIFICATION
--   Bloc DO : confirme que le nouveau CHECK accepte bien
--   'interlibrary_loan_partially_returned'.
-- ============================================================================

ALTER TABLE public.interlibrary_loan_notification_events
  DROP CONSTRAINT IF EXISTS interlibrary_loan_notification_events_type_chk;

ALTER TABLE public.interlibrary_loan_notification_events
  ADD CONSTRAINT interlibrary_loan_notification_events_type_chk
  CHECK (event_type = ANY (ARRAY[
    'interlibrary_loan_created'::text,
    'interlibrary_loan_prepared'::text,
    'interlibrary_loan_dispatched'::text,
    'interlibrary_loan_due_soon'::text,
    'interlibrary_loan_overdue'::text,
    'interlibrary_loan_return_started'::text,
    'interlibrary_loan_returned'::text,
    'interlibrary_loan_cancelled'::text,
    'interlibrary_loan_partially_returned'::text
  ]));

-- ─── Verification post-migration ─────────────────────────────────────────────
DO $verif$
declare
  v_def text;
begin
  select pg_get_constraintdef(con.oid) into v_def
  from pg_constraint con
  join pg_class c on c.oid = con.conrelid
  where c.relname = 'interlibrary_loan_notification_events'
    and con.conname = 'interlibrary_loan_notification_events_type_chk';

  if v_def is null then
    raise exception 'Verification echouee : contrainte type_chk absente apres migration.';
  end if;

  if position('interlibrary_loan_partially_returned' in v_def) = 0 then
    raise exception 'Verification echouee : le CHECK ne contient pas interlibrary_loan_partially_returned.';
  end if;

  raise notice 'Migration 20260522040000 : verification OK (CHECK accepte partially_returned).';
end;
$verif$;
