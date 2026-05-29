-- =====================================================================
-- AnarBib — Paquet 7 : alignement renouvellement (lecteur + biblio)
-- Date : 2026-05-10
-- Spec : docs/spec-flux-emprunts.md (commit 669a5eb)
-- Backlog : item #60 (Motif de refus de renouvellement) + fix bug
--           reserva_itens_v2 dans fn_renew_my_loan (decouvert audit 10/05)
--
-- Ce paquet :
-- 1. Ajoute la colonne renewals_used (compteur explicite) avec backfill
-- 2. Pose un trigger qui maintient extended_once en sync (retrocompat)
-- 3. Reecrit fn_renew_my_loan avec 8 reasons et fix du bug reserva_linhas_v2
-- 4. Reecrit fn_v2_extend_emprestimo_once en jsonb harmonise (memes 8 reasons)
-- 5. Cree la vue api.my_loans_renewal_status_v1 pour pre-evaluation frontend
-- =====================================================================

BEGIN;

-- =====================================================================
-- 1. Colonne renewals_used + backfill
-- =====================================================================

ALTER TABLE public.emprestimos_v2
  ADD COLUMN IF NOT EXISTS renewals_used int NOT NULL DEFAULT 0;

-- Backfill : si extended_once = true en prod, renewals_used := 1
UPDATE public.emprestimos_v2
   SET renewals_used = 1
 WHERE extended_once = true AND renewals_used = 0;

COMMENT ON COLUMN public.emprestimos_v2.renewals_used IS
'Compteur explicite de renouvellements appliques. Source de verite a partir
du paquet 7 (10/05/2026). extended_once est maintenu en sync par
trg_emprestimo_sync_extended_once pour ne pas casser les consommateurs
qui le lisent encore.';

-- =====================================================================
-- 2. Trigger de sync extended_once <- (renewals_used >= 1)
-- =====================================================================

CREATE OR REPLACE FUNCTION public.trg_emprestimo_sync_extended_once()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  NEW.extended_once := (COALESCE(NEW.renewals_used, 0) >= 1);
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.trg_emprestimo_sync_extended_once() OWNER TO postgres;

DROP TRIGGER IF EXISTS trg_emprestimo_sync_extended_once ON public.emprestimos_v2;
CREATE TRIGGER trg_emprestimo_sync_extended_once
BEFORE INSERT OR UPDATE OF renewals_used ON public.emprestimos_v2
FOR EACH ROW EXECUTE FUNCTION public.trg_emprestimo_sync_extended_once();

COMMENT ON TRIGGER trg_emprestimo_sync_extended_once ON public.emprestimos_v2 IS
'Maintient extended_once en sync avec (renewals_used >= 1) pour retrocompat
des consommateurs frontend qui n''ont pas encore migre vers renewals_used.
A retirer apres bascule complete du frontend (paquet 8+).';

-- =====================================================================
-- 3. Reecriture fn_renew_my_loan
--    - Fix bug : reserva_itens_v2 (inexistante) -> reserva_linhas_v2
--    - 8 reasons : not_authenticated, not_found, dues_blocked, not_renewable,
--      quota_exceeded, overdue, reserved_by_other, already_extended (kept
--      for backward-compat via the renewals_used >= renewal_max_count test)
--    - Branche api.get_due_date_after_renewal pour calcul propre
--    - Incremente renewals_used au lieu de extended_once = true
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_renew_my_loan(p_emprestimo_id bigint)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'api'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_header public.emprestimos_v2%ROWTYPE;
  v_quantity int := 0;
  v_first_book_id bigint := NULL;
  v_first_holding_id bigint := NULL;
  v_current_due date := NULL;
  v_renewals_used int := 0;
  v_rule record;
  v_dues_blocked boolean := false;
  v_has_reservation boolean := false;
  v_new_due date;
BEGIN
  -- 1. Authentification
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  -- 2. Charger l'en-tete + verifier appartenance
  SELECT * INTO v_header
    FROM public.emprestimos_v2
   WHERE id = p_emprestimo_id AND user_id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;

  -- 3. Cotisation a jour
  v_dues_blocked := public.fn_is_loan_blocked_by_dues(v_user_id, v_header.library_id);
  IF v_dues_blocked THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'dues_blocked');
  END IF;

  -- 4. Aggregats sur les items ouverts
  SELECT COUNT(*)::int,
         MIN(i.book_id),
         MIN(i.holding_id),
         MAX(COALESCE(i.extended_until, i.due_at))
    INTO v_quantity, v_first_book_id, v_first_holding_id, v_current_due
    FROM public.emprestimo_itens_v2 i
   WHERE i.emprestimo_id = p_emprestimo_id
     AND i.item_status = 'aberto';

  IF COALESCE(v_quantity, 0) = 0 THEN
    -- Plus rien a renouveler : equivalent functionnel de not_found
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;

  -- 5. Pas en retard (avant les regles de circulation, plus parlant pour le lecteur)
  IF COALESCE(v_current_due, CURRENT_DATE) < CURRENT_DATE THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'overdue');
  END IF;

  -- 6. Reserve par un autre lecteur sur le meme livre dans la meme biblio
  --    FIX BUG : la table est reserva_linhas_v2 (et non reserva_itens_v2 qui n'existe pas)
  SELECT EXISTS (
    SELECT 1
      FROM public.reserva_linhas_v2 rl
      JOIN public.reservas_v2 r ON r.id = rl.reserva_id
     WHERE rl.book_id = v_first_book_id
       AND r.library_id = v_header.library_id
       AND r.user_id <> v_user_id
       AND r.status_global IN ('ativa', 'parcialmente_encerrada')
       AND rl.item_status = 'ativa'
  ) INTO v_has_reservation;

  IF v_has_reservation THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'reserved_by_other');
  END IF;

  -- 7. Quota et politique de circulation : on delegue a api.get_due_date_after_renewal
  v_renewals_used := COALESCE(v_header.renewals_used, 0);

  SELECT *
    INTO v_rule
    FROM api.get_due_date_after_renewal(
      p_library_id := v_header.library_id,
      p_user_id := v_user_id,
      p_book_id := v_first_book_id,
      p_holding_id := v_first_holding_id,
      p_quantity := v_quantity,
      p_current_due_date := GREATEST(COALESCE(v_current_due, CURRENT_DATE), CURRENT_DATE),
      p_renewals_used := v_renewals_used,
      p_as_of_date := CURRENT_DATE
    )
    LIMIT 1;

  -- Cas : la regle existe mais marque le pret comme non-renouvelable
  IF v_rule IS NOT NULL AND COALESCE(v_rule.renewable, false) IS false THEN
    -- Distinguer "non renouvelable du tout" vs "quota epuise"
    IF COALESCE(v_rule.renewals_remaining, 0) <= 0 AND v_renewals_used > 0 THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'quota_exceeded');
    ELSE
      RETURN jsonb_build_object('ok', false, 'reason', 'not_renewable');
    END IF;
  END IF;

  -- Cas defensif : aucune regle resolue, on bloque par prudence
  IF v_rule.new_due_date IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_renewable');
  END IF;

  -- 8. Conservation pour retrocompat de la cle 'already_extended' :
  --    si renewal_max_count = 1 et renewals_used = 1, la regle ci-dessus
  --    aura deja retourne quota_exceeded ; cette branche est defensive.
  IF v_renewals_used >= 1
     AND COALESCE(v_rule.renewals_remaining, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'already_extended');
  END IF;

  v_new_due := v_rule.new_due_date;

  -- 9. Application : MAJ items + tete (le trigger sync extended_once)
  UPDATE public.emprestimo_itens_v2
     SET extended_until = v_new_due,
         extension_note = COALESCE(NULLIF(v_rule.explanation, ''),
                                    'renewal_by_reader'),
         return_schedule_status = 'emprestimo_prorrogado',
         return_scheduled_for = NULL,
         return_scheduled_by = NULL,
         return_scheduled_at = NULL,
         return_completed_at = NULL,
         return_missed_at = NULL,
         updated_at = now()
   WHERE emprestimo_id = p_emprestimo_id
     AND item_status = 'aberto';

  UPDATE public.emprestimos_v2
     SET renewals_used = renewals_used + 1,
         extended_at = now(),
         updated_at = now()
   WHERE id = p_emprestimo_id;

  RETURN jsonb_build_object(
    'ok', true,
    'reason', 'renewed',
    'new_due_date', v_new_due
  );
END;
$$;

ALTER FUNCTION public.fn_renew_my_loan(bigint) OWNER TO postgres;

COMMENT ON FUNCTION public.fn_renew_my_loan(bigint) IS
'Renouvellement par le lecteur. Paquet 7 (10/05/2026) : 8 reasons, fix bug
reserva_linhas_v2, branche api.get_due_date_after_renewal, incrementation
de renewals_used (le trigger maintient extended_once retrocompatible).
Symetrique a fn_v2_extend_emprestimo_once cote biblio.';

REVOKE ALL ON FUNCTION public.fn_renew_my_loan(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_renew_my_loan(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_renew_my_loan(bigint) TO service_role;

-- =====================================================================
-- 4. Reecriture fn_v2_extend_emprestimo_once
--    - Memes 8 reasons que fn_renew_my_loan
--    - Retour jsonb au lieu de TABLE (BREAKING CHANGE de signature)
--    - Cote biblio : verifie role + library_id, mais memes regles metier
-- =====================================================================

DROP FUNCTION IF EXISTS public.fn_v2_extend_emprestimo_once(bigint);

CREATE OR REPLACE FUNCTION public.fn_v2_extend_emprestimo_once(p_emprestimo_id bigint)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'api'
AS $$
DECLARE
  v_actor public.my_access%ROWTYPE;
  v_header public.emprestimos_v2%ROWTYPE;
  v_quantity int := 0;
  v_first_book_id bigint := NULL;
  v_first_holding_id bigint := NULL;
  v_current_due date := NULL;
  v_renewals_used int := 0;
  v_rule record;
  v_dues_blocked boolean := false;
  v_has_reservation boolean := false;
  v_new_due date;
  v_is_self boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;

  SELECT * INTO v_header
    FROM public.emprestimos_v2
   WHERE id = p_emprestimo_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;

  -- Permission : soit le lecteur lui-meme (cas legitime, fonction utilisee
  -- aussi historiquement par AccountPage), soit un staff de la biblio
  v_is_self := (v_header.user_id = auth.uid());
  IF NOT v_is_self THEN
    SELECT * INTO v_actor FROM public.my_access LIMIT 1;
    IF NOT (
      COALESCE(v_actor.can_access_painel, false) IS true
      AND v_actor.library_id = v_header.library_id
    ) THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
    END IF;
  END IF;

  -- Cotisation
  v_dues_blocked := public.fn_is_loan_blocked_by_dues(v_header.user_id, v_header.library_id);
  IF v_dues_blocked THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'dues_blocked');
  END IF;

  -- Aggregats items ouverts
  SELECT COUNT(*)::int,
         MIN(i.book_id),
         MIN(i.holding_id),
         MAX(COALESCE(i.extended_until, i.due_at))
    INTO v_quantity, v_first_book_id, v_first_holding_id, v_current_due
    FROM public.emprestimo_itens_v2 i
   WHERE i.emprestimo_id = p_emprestimo_id
     AND i.item_status = 'aberto';

  IF COALESCE(v_quantity, 0) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;

  IF COALESCE(v_current_due, CURRENT_DATE) < CURRENT_DATE THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'overdue');
  END IF;

  SELECT EXISTS (
    SELECT 1
      FROM public.reserva_linhas_v2 rl
      JOIN public.reservas_v2 r ON r.id = rl.reserva_id
     WHERE rl.book_id = v_first_book_id
       AND r.library_id = v_header.library_id
       AND r.user_id <> v_header.user_id
       AND r.status_global IN ('ativa', 'parcialmente_encerrada')
       AND rl.item_status = 'ativa'
  ) INTO v_has_reservation;

  IF v_has_reservation THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'reserved_by_other');
  END IF;

  v_renewals_used := COALESCE(v_header.renewals_used, 0);

  SELECT *
    INTO v_rule
    FROM api.get_due_date_after_renewal(
      p_library_id := v_header.library_id,
      p_user_id := v_header.user_id,
      p_book_id := v_first_book_id,
      p_holding_id := v_first_holding_id,
      p_quantity := v_quantity,
      p_current_due_date := GREATEST(COALESCE(v_current_due, CURRENT_DATE), CURRENT_DATE),
      p_renewals_used := v_renewals_used,
      p_as_of_date := CURRENT_DATE
    )
    LIMIT 1;

  IF v_rule IS NOT NULL AND COALESCE(v_rule.renewable, false) IS false THEN
    IF COALESCE(v_rule.renewals_remaining, 0) <= 0 AND v_renewals_used > 0 THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'quota_exceeded');
    ELSE
      RETURN jsonb_build_object('ok', false, 'reason', 'not_renewable');
    END IF;
  END IF;

  IF v_rule.new_due_date IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_renewable');
  END IF;

  IF v_renewals_used >= 1
     AND COALESCE(v_rule.renewals_remaining, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'already_extended');
  END IF;

  v_new_due := v_rule.new_due_date;

  UPDATE public.emprestimo_itens_v2
     SET extended_until = v_new_due,
         extension_note = COALESCE(NULLIF(v_rule.explanation, ''),
                                    CASE WHEN v_is_self
                                         THEN 'renewal_by_reader'
                                         ELSE 'renewal_by_library' END),
         return_schedule_status = 'emprestimo_prorrogado',
         return_scheduled_for = NULL,
         return_scheduled_by = NULL,
         return_scheduled_at = NULL,
         return_completed_at = NULL,
         return_missed_at = NULL,
         updated_at = now()
   WHERE emprestimo_id = p_emprestimo_id
     AND item_status = 'aberto';

  UPDATE public.emprestimos_v2
     SET renewals_used = renewals_used + 1,
         extended_at = now(),
         updated_at = now()
   WHERE id = p_emprestimo_id;

  RETURN jsonb_build_object(
    'ok', true,
    'reason', 'renewed',
    'new_due_date', v_new_due
  );
END;
$$;

ALTER FUNCTION public.fn_v2_extend_emprestimo_once(bigint) OWNER TO postgres;

COMMENT ON FUNCTION public.fn_v2_extend_emprestimo_once(bigint) IS
'Prolongation par biblio (ou par lecteur si auto-call). Paquet 7
(10/05/2026) : retour jsonb harmonise avec fn_renew_my_loan (8 reasons),
incrementation de renewals_used. BREAKING CHANGE : ancienne signature
TABLE(ok, message, new_due_date) remplacee par jsonb.';

REVOKE ALL ON FUNCTION public.fn_v2_extend_emprestimo_once(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_v2_extend_emprestimo_once(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_v2_extend_emprestimo_once(bigint) TO service_role;

-- =====================================================================
-- 5. Vue api.my_loans_renewal_status_v1
--    Pre-evaluation pour AccountPage (un seul SELECT cote frontend)
--    Pour chaque emprunt actif du lecteur connecte :
--    - emprestimo_id, due_at effectif, renewals_used
--    - renewable (si renewable selon politique)
--    - renewals_remaining (selon api.get_remaining_renewals)
--    - blocking_reason : meme logique que fn_renew_my_loan, dans l'ordre
-- =====================================================================

CREATE OR REPLACE VIEW api.my_loans_renewal_status_v1
WITH (security_invoker='true')
AS
WITH my_open_loans AS (
  SELECT
    e.id AS emprestimo_id,
    e.user_id,
    e.library_id,
    e.renewals_used,
    e.extended_once,
    -- Aggregats sur les items ouverts
    (SELECT COUNT(*)::int
       FROM public.emprestimo_itens_v2 i
      WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto') AS open_items_count,
    (SELECT MIN(i.book_id)
       FROM public.emprestimo_itens_v2 i
      WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto') AS first_book_id,
    (SELECT MIN(i.holding_id)
       FROM public.emprestimo_itens_v2 i
      WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto') AS first_holding_id,
    (SELECT MAX(COALESCE(i.extended_until, i.due_at))
       FROM public.emprestimo_itens_v2 i
      WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto') AS effective_due_at
  FROM public.emprestimos_v2 e
  WHERE e.user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.emprestimo_itens_v2 i
       WHERE i.emprestimo_id = e.id AND i.item_status = 'aberto'
    )
),
with_dues AS (
  SELECT l.*,
         public.fn_is_loan_blocked_by_dues(l.user_id, l.library_id) AS dues_blocked,
         EXISTS (
           SELECT 1
             FROM public.reserva_linhas_v2 rl
             JOIN public.reservas_v2 r ON r.id = rl.reserva_id
            WHERE rl.book_id = l.first_book_id
              AND r.library_id = l.library_id
              AND r.user_id <> l.user_id
              AND r.status_global IN ('ativa', 'parcialmente_encerrada')
              AND rl.item_status = 'ativa'
         ) AS reserved_by_other
    FROM my_open_loans l
),
with_rule AS (
  SELECT w.*,
         rr.renewable,
         rr.renewals_remaining,
         rr.renewal_days,
         rr.rule_label
    FROM with_dues w
    LEFT JOIN LATERAL api.get_remaining_renewals(
      p_library_id := w.library_id,
      p_user_id := w.user_id,
      p_book_id := w.first_book_id,
      p_holding_id := w.first_holding_id,
      p_quantity := w.open_items_count,
      p_renewals_used := COALESCE(w.renewals_used, 0),
      p_as_of_date := CURRENT_DATE
    ) rr ON true
)
SELECT
  emprestimo_id,
  library_id,
  effective_due_at,
  open_items_count,
  renewals_used,
  COALESCE(renewable, false) AS renewable,
  COALESCE(renewals_remaining, 0) AS renewals_remaining,
  rule_label,
  -- blocking_reason : ordre de priorite identique a fn_renew_my_loan
  CASE
    WHEN dues_blocked
      THEN 'dues_blocked'
    WHEN COALESCE(effective_due_at, CURRENT_DATE) < CURRENT_DATE
      THEN 'overdue'
    WHEN reserved_by_other
      THEN 'reserved_by_other'
    WHEN COALESCE(renewable, false) IS false
         AND COALESCE(renewals_remaining, 0) <= 0
         AND COALESCE(renewals_used, 0) > 0
      THEN 'quota_exceeded'
    WHEN COALESCE(renewable, false) IS false
      THEN 'not_renewable'
    WHEN COALESCE(renewals_used, 0) >= 1
         AND COALESCE(renewals_remaining, 0) <= 0
      THEN 'already_extended'
    ELSE NULL
  END AS blocking_reason,
  -- can_renew = pas de blocking_reason ET (renewable OU encore des renewals_remaining)
  (
    COALESCE(renewable, false) IS true
    AND NOT dues_blocked
    AND COALESCE(effective_due_at, CURRENT_DATE) >= CURRENT_DATE
    AND NOT reserved_by_other
    AND COALESCE(renewals_remaining, 0) > 0
  ) AS can_renew
FROM with_rule;

ALTER VIEW api.my_loans_renewal_status_v1 OWNER TO postgres;

COMMENT ON VIEW api.my_loans_renewal_status_v1 IS
'Vue de pre-evaluation des renouvellements pour AccountPage (paquet 7,
10/05/2026). Filtre sur auth.uid() via security_invoker. Retourne pour
chaque emprunt actif du lecteur le blocking_reason eventuel (meme ordre
que fn_renew_my_loan) et un flag can_renew. Permet de pre-desactiver
le bouton Renovar avec tooltip explicatif.';

GRANT SELECT ON api.my_loans_renewal_status_v1 TO authenticated;

COMMIT;

-- =====================================================================
-- Tests manuels recommandes (a executer apres deploiement) :
--
-- -- 1. Verifier le backfill
-- SELECT id, extended_once, renewals_used FROM emprestimos_v2;
-- -- Tout extended_once=true doit avoir renewals_used=1
--
-- -- 2. Verifier le trigger
-- UPDATE emprestimos_v2 SET renewals_used = 2 WHERE id = <id_test>;
-- SELECT id, extended_once, renewals_used FROM emprestimos_v2 WHERE id = <id_test>;
-- -- extended_once doit etre passe a true automatiquement
--
-- -- 3. Tester fn_renew_my_loan via SECURITY DEFINER + auth.uid() simulee
-- --    (a faire depuis le frontend en se connectant comme lecteur test)
-- SELECT public.fn_renew_my_loan(<emprestimo_id>);
-- -- Doit retourner jsonb avec ok et reason
--
-- -- 4. Tester la vue
-- SET LOCAL role authenticated;
-- SET LOCAL request.jwt.claim.sub TO '<uuid_lecteur_test>';
-- SELECT * FROM api.my_loans_renewal_status_v1;
-- -- Doit lister les emprunts du lecteur avec can_renew et blocking_reason
-- =====================================================================
