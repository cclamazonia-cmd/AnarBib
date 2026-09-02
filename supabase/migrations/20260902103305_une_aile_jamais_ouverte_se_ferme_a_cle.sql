-- B20, lot circulation : l'aile jamais ouverte se ferme à clé — on garde les murs.
--
-- ============================================================================
-- L'INSTRUCTION (02/09/2026), fonction par fonction
-- ============================================================================
-- Les huit dernières fonctions `api` sans appelant (GLB v17 ch. 6,
-- contre-vérifié : grep dépôt 0, base 0 appelant SQL/policy/cron) se
-- répartissent en quatre natures, et AUCUNE n'est à brancher :
--
-- * Sous-workflow d'agendamento de retour — `schedule_loan_return`,
--   `clear_loan_return_schedule`, `mark_loan_return_missed` : enveloppes
--   d'une chaîne complète (api → public.fn_v2_*_emprestimo_return* → sept
--   colonnes d'emprestimo_itens_v2) dont AUCUN étage n'a jamais servi :
--   0 ligne avec return_scheduled_for, aucun écran dans PanelPage. La spec
--   `spec-flux-emprunts.md` (§ côté bibliothécaire) le dit « largement
--   opérationnel » : c'est faux pour ce sous-workflow — écart de spec à
--   verser au même registre que D1. Les TROIS implémentations fn_v2_* de
--   `public`, que cette fermeture rend totalement orphelines, sont fermées
--   dans le même geste : une chaîne se ferme entière ou pas du tout.
-- * Créneau de retrait — `refuse_pickup_slot` : ancienne génération,
--   supplantée par la négociation `fn_propose/confirm_pickup_slot_as_reader/
--   as_library` (câblée) ; sa jumelle `confirm_pickup_slot` garde ses
--   appelants et n'est pas touchée.
-- * Helpers de lecture — `get_due_date_for_loan` (fuite fermée le 31/08,
--   suite b14_api_cotisation_autrui : appels en postgres, insensible au
--   grant), `get_remaining_renewals`,
--   `get_library_circulation_policy_rules_ui` : doublons sans emploi de
--   `resolve_circulation_rule` / `get_due_date_after_renewal` /
--   `get_library_circulation_policy_sets_ui`, qui ont leurs appelants et ne
--   bougent pas. Leur grant `service_role` explicite est conservé (porte
--   serveur, pas navigateur).
-- * Catalogage — `attach_exemplar` : supplantée par le flux brouillon
--   (`publish_book_draft` crée les exemplaires). Citée en modèle dans
--   l'audit du 01/09 pour sa déduction de biblio par l'appelant — le modèle
--   reste lisible dans son corps, qui ne bouge pas.
--
-- Les gardes de corps restent entières (paquet19 et oracle_existence_ordre
-- appellent en postgres : inchangées). La restauration de n'importe quel
-- étage est un GRANT, le jour où un écran est réellement dû.
-- ACL lue avant d'écrire : grants explicites, pas d'entrée PUBLIC héritée —
-- les trois cibles sont nommées par ceinture.

DO $$
DECLARE
  r record;
  v_fermees int := 0;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE (n.nspname = 'api' AND p.proname IN (
             'attach_exemplar','clear_loan_return_schedule','get_due_date_for_loan',
             'get_library_circulation_policy_rules_ui','get_remaining_renewals',
             'mark_loan_return_missed','refuse_pickup_slot','schedule_loan_return'))
       OR (n.nspname = 'public' AND p.proname IN (
             'fn_v2_schedule_emprestimo_return','fn_v2_clear_emprestimo_return_schedule',
             'fn_v2_mark_emprestimo_return_missed'))
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', r.sig);
    v_fermees := v_fermees + 1;
  END LOOP;

  IF v_fermees <> 11 THEN
    RAISE EXCEPTION '11 fonctions attendues, % trouvées — la liste et la base divergent, rollback', v_fermees;
  END IF;
END $$;

DO $$
DECLARE
  v_liste text;
BEGIN
  -- 1) Plus aucune des onze n'est ouverte à la porte du navigateur.
  SELECT string_agg(p.proname, ', ') INTO v_liste
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE ((n.nspname = 'api' AND p.proname IN (
           'attach_exemplar','clear_loan_return_schedule','get_due_date_for_loan',
           'get_library_circulation_policy_rules_ui','get_remaining_renewals',
           'mark_loan_return_missed','refuse_pickup_slot','schedule_loan_return'))
     OR (n.nspname = 'public' AND p.proname IN (
           'fn_v2_schedule_emprestimo_return','fn_v2_clear_emprestimo_return_schedule',
           'fn_v2_mark_emprestimo_return_missed')))
    AND (has_function_privilege('authenticated', p.oid, 'EXECUTE')
      OR has_function_privilege('anon', p.oid, 'EXECUTE'));
  IF v_liste IS NOT NULL THEN
    RAISE EXCEPTION 'révocation sans effet sur : % — rollback', v_liste;
  END IF;

  -- 2) Les jumelles câblées n'ont pas bougé : les fermer par accident
  --    éteindrait la réservation, le renouvellement et le catalogage.
  --    Couples (schéma, nom) explicites — publish_book_draft vit dans
  --    `public`, un filtre sur `api` seul l'aurait sauté en silence.
  SELECT string_agg(a.nsp||'.'||a.nom, ', ') INTO v_liste
  FROM (VALUES ('api','confirm_pickup_slot'),('api','fn_confirm_pickup_slot_as_reader'),
               ('api','fn_propose_pickup_slot_as_reader'),('api','get_due_date_after_renewal'),
               ('api','resolve_circulation_rule'),('api','get_library_circulation_policy_sets_ui'),
               ('public','publish_book_draft')) a(nsp, nom)
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = a.nsp AND p.proname = a.nom
      AND has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  IF v_liste IS NOT NULL THEN
    RAISE EXCEPTION 'jumelle câblée fermée ou introuvable : % — rollback', v_liste;
  END IF;
END $$;
