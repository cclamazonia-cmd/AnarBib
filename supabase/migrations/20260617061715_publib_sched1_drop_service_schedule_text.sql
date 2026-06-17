-- supabase/migrations/20260617061715_publib_sched1_drop_service_schedule_text.sql
-- Session : Gazette Rizoma & Lettre federation
-- Chantier PUBLIB (REGISTRE §31) — PUBLIB-SCHED-1 : solde de la « dette des 3
-- représentations d'horaires ». Sondage 17/06 (confronté au réel) :
--   1. library_service_state.consultation_schedule_struct = LIVE, lu par
--      fn_validate_consulta_schedule_window (réservation de consultation sur
--      place : jour activé, open/close, pause, capacité). → CONSERVÉ (usage
--      légitime, distinct des horaires publics).
--   2. library_service_state.service_schedule_text = MORT : vide partout (seule
--      blmf l'avait, en chaînes vides) ; AUCUN lecteur fonctionnel (uses_service_text
--      = false dans la fn de validation ; 0 usage frontend) ; seul le trigger
--      d'audit tg_lss_log_cross_library_action en détecte le changement. → SUPPRIMÉ.
--   3. library_opening_hours = horaires publics présentables. → CANONIQUE (PUBLIB-SCHED-1).
-- Donc : pas de fusion (les deux vivants ont des rôles distincts), mais frontière
-- documentée + colonne morte retirée. Le trigger d'audit est recréé SANS le bloc
-- service_schedule_text (sinon il référencerait une colonne disparue → erreur au
-- prochain UPDATE). Idempotent. Validé BEGIN/ROLLBACK.

-- ── 1. Recréer le trigger d'audit SANS le bloc service_schedule_text ─────────
--    (consultation_schedule_struct conservé ; reste du corps inchangé).
create or replace function public.tg_lss_log_cross_library_action()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
    v_delta jsonb := '{}'::jsonb;
begin
    if old.service_mode is distinct from new.service_mode then
        v_delta := v_delta || jsonb_build_object('service_mode', jsonb_build_object('old', old.service_mode, 'new', new.service_mode));
    end if;
    if old.public_message is distinct from new.public_message then
        v_delta := v_delta || jsonb_build_object('public_message_changed', true);
    end if;
    if old.allows_new_reservations is distinct from new.allows_new_reservations then
        v_delta := v_delta || jsonb_build_object('allows_new_reservations', jsonb_build_object('old', old.allows_new_reservations, 'new', new.allows_new_reservations));
    end if;
    if old.allows_new_loans is distinct from new.allows_new_loans then
        v_delta := v_delta || jsonb_build_object('allows_new_loans', jsonb_build_object('old', old.allows_new_loans, 'new', new.allows_new_loans));
    end if;
    if old.consultation_timezone is distinct from new.consultation_timezone then
        v_delta := v_delta || jsonb_build_object('consultation_timezone', jsonb_build_object('old', old.consultation_timezone, 'new', new.consultation_timezone));
    end if;
    if old.max_simultaneous_consultations is distinct from new.max_simultaneous_consultations then
        v_delta := v_delta || jsonb_build_object('max_simultaneous_consultations', jsonb_build_object('old', old.max_simultaneous_consultations, 'new', new.max_simultaneous_consultations));
    end if;
    if old.consultation_schedule_struct is distinct from new.consultation_schedule_struct then
        v_delta := v_delta || jsonb_build_object('consultation_schedule_struct_changed', true);
    end if;
    -- (bloc service_schedule_text retiré : colonne supprimée — PUBLIB-SCHED-1)

    if v_delta = '{}'::jsonb then
        return new;
    end if;

    perform public.fn_log_cross_library_action(
        p_library_id        := new.library_id,
        p_action_type       := 'update_library_service_state',
        p_is_critical       := public.fn_is_critical_action_type('update_library_service_state'),
        p_target_entity_type := 'library_service_state',
        p_target_entity_id  := new.library_id,
        p_payload           := jsonb_build_object('delta', v_delta)
    );

    return new;
end;
$$;

-- ── 2. Supprimer la colonne morte ───────────────────────────────────────────
alter table public.library_service_state drop column if exists service_schedule_text;

-- ── 3. Documenter la frontière (PUBLIB-SCHED-1) ─────────────────────────────
comment on column public.library_service_state.consultation_schedule_struct is
  'Disponibilité STRUCTURÉE pour la réservation de consultation sur place (jour {enabled,open,close,pause?}), lue par fn_validate_consulta_schedule_window. DISTINCTE des horaires publics présentables — ceux-ci sont CANONIQUES dans public.library_opening_hours (PUBLIB-SCHED-1, REGISTRE §31). Ne pas confondre les deux usages.';
comment on table public.library_opening_hours is
  'CANONIQUE des horaires/permanences PUBLICS présentables d''une biblio (PUBLIB-SCHED-1). slots = [{day 1..7, start HH:MM, end HH:MM, label?}]. Écriture coordenador (fn_upsert_library_opening_hours) ; lecture membres actifs + anon si is_public (vue api.library_opening_hours_public_v1). À NE PAS confondre avec library_service_state.consultation_schedule_struct (réservation de consultation, autre usage).';

notify pgrst, 'reload schema';
