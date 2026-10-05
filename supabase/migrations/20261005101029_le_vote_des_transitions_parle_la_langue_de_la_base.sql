-- =====================================================================
-- G16 (05/10/2026) — le vote des transitions (changer un mode de
-- fonctionnement d'une bibliothèque) parle la langue de la base, et
-- l'abstention est gardée (décision de Xavier, 05/10).
--
-- Relevé en traduisant les refus de la base (E23). Le circuit n'avait jamais
-- servi : 0 proposition, 0 vote en production le 05/10.
--
--   · L'écran envoyait « pro », « contre » ou « abstain » ; la fonction et la
--     table n'acceptaient que « for » ou « against » : tout vote aurait été
--     refusé (VOTE_INVALID_VALUE). L'écran traduit désormais ses boutons ; la
--     base apprend « abstain ».
--   · Une transition de type 4 (unanimous_extended : cesser la circulation
--     formelle, abandonner la gouvernance) ne se fermait JAMAIS : la fonction
--     ne connaissait que « majority » et « unanimous ». Elle suit maintenant la
--     doctrine (CHANTIER_doctrine_transitions_profils_2026-05-17) : unanimité
--     du staff et carence de 14 jours ; l'archivage (paquet D) reste à
--     l'exécution, inchangé.
--   · Une transition de type 2 (majorité) acceptée ne se fermait pas non plus :
--     sans carence (doctrine : 0 jour), la fonction posait un verrou de carence
--     qui finissait à l'instant même où il était posé, et la CHECK
--     chk_lpgl_grace_after_lock (grace_until > locked_at) refusait le vote
--     gagnant. Sans carence, pas de verrou : le verrou ne sert qu'à suspendre
--     les tâches PENDANT une carence ; l'exécution (cron, 15 min) suit seule.
--
-- RÈGLE DE L'ABSTENTION — celle de la cooptation, seule règle déjà en service
-- dans AnarBib (CADRAGE_111 : « s'aligner exactement sur la cooptation ») :
-- l'abstention n'est pas une opposition (aucune justification demandée) ;
-- elle n'est pas un « pour ».
--   · majorité : il faut (staff actif / 2) + 1 « pour » ; une abstention compte
--     comme une voix exprimée qui ne s'ajoute pas aux « pour » — la
--     proposition est rejetée dès que la majorité n'est plus atteignable ;
--   · unanimité (simple ou étendue) : tout le staff actif doit voter « pour » ;
--     une abstention, comme une opposition, rend l'unanimité impossible — la
--     proposition est close « rejetée » aussitôt (le vote est définitif), au
--     lieu d'attendre son expiration sans issue possible. Elle peut être
--     proposée de nouveau.
--
-- La fonction est réécrite depuis sa définition RÉELLE (pg_get_functiondef,
-- retours chariot retirés), ancres COMPTÉES, empreinte relevée le 05/10.
-- Les deux CHECK de la table sont élargies (table vide le 05/10).
-- Suite : tests/sql/vote_des_transitions_tests.sql.
-- =====================================================================

ALTER TABLE public.library_profile_votes DROP CONSTRAINT library_profile_votes_vote_check;
ALTER TABLE public.library_profile_votes ADD CONSTRAINT library_profile_votes_vote_check
  CHECK (vote = ANY (ARRAY['for'::text, 'against'::text, 'abstain'::text]));

ALTER TABLE public.library_profile_votes DROP CONSTRAINT chk_lpv_rationale_required_against;
ALTER TABLE public.library_profile_votes ADD CONSTRAINT chk_lpv_rationale_required_against
  CHECK (((vote = 'for'::text) AND (rationale_against IS NULL))
      OR ((vote = 'against'::text) AND (rationale_against IS NOT NULL) AND (length(rationale_against) >= 20))
      OR ((vote = 'abstain'::text) AND (rationale_against IS NULL)));

DO $mig$
DECLARE
  v_fn    regprocedure := 'public.fn_vote_library_profile_change(uuid,text,text)'::regprocedure;
  v_def   text;
  v_md5   text;
  v_n     int;
  v_i     int;
  v_vieux text[] := ARRAY[
$a$  IF p_vote NOT IN ('for', 'against') THEN
    RAISE EXCEPTION 'VOTE_INVALID_VALUE : vote doit etre for ou against, recu (%)', p_vote$a$,
$a$  v_votes_against     int;
$a$,
$a$    count(*) FILTER (WHERE vote = 'against')
  INTO v_votes_for, v_votes_against$a$,
$a$    ELSIF (v_votes_for + (v_active_staff - v_votes_for - v_votes_against)) < v_votes_needed THEN$a$,
$a$  ELSIF v_proposal.governance_required = 'unanimous' THEN
    -- Unanime : tous les staff ont vote ET tous 'for'
    IF v_votes_against > 0 THEN
      v_new_status := 'rejected';   -- un seul against = unanimite rompue
    ELSIF v_votes_for = v_active_staff THEN$a$,
$a$      WHEN 'unanimous' THEN 7   -- 7 jours
    END;$a$,
$a$    'votes_against',     v_votes_against,
$a$,
$a$    IF v_new_status IN ('accepted_majority', 'accepted_unanimous') THEN
      INSERT INTO public.library_profile_grace_locks ($a$];
  v_neuf  text[] := ARRAY[
$a$  -- G16 (05/10/2026) : l'abstention est une voix (règle de la cooptation).
  IF p_vote IS NULL OR p_vote NOT IN ('for', 'against', 'abstain') THEN
    RAISE EXCEPTION 'VOTE_INVALID_VALUE : vote doit etre for, against ou abstain, recu (%)', p_vote$a$,
$a$  v_votes_against     int;
  v_votes_abstain     int;   -- G16
$a$,
$a$    count(*) FILTER (WHERE vote = 'against'),
    count(*) FILTER (WHERE vote = 'abstain')
  INTO v_votes_for, v_votes_against, v_votes_abstain$a$,
$a$    -- G16 : une abstention est exprimée et ne s'ajoute pas aux « pour ».
    ELSIF (v_votes_for + greatest(v_active_staff - v_votes_for - v_votes_against - v_votes_abstain, 0)) < v_votes_needed THEN$a$,
$a$  ELSIF v_proposal.governance_required IN ('unanimous', 'unanimous_extended') THEN
    -- Unanime (G16 : étendue comprise, type 4) : tout le staff actif vote 'for'.
    -- Une opposition, ou une abstention (règle de la cooptation), rend
    -- l'unanimité impossible : le vote étant définitif, on clôt aussitôt.
    IF v_votes_against > 0 OR v_votes_abstain > 0 THEN
      v_new_status := 'rejected';
    ELSIF v_votes_for >= v_active_staff THEN$a$,
$a$      WHEN 'unanimous' THEN 7   -- 7 jours
      WHEN 'unanimous_extended' THEN 14   -- G16 : doctrine du type 4
    END;$a$,
$a$    'votes_against',     v_votes_against,
    'votes_abstain',     v_votes_abstain,
$a$,
$a$    -- G16 : sans carence (majorité), pas de verrou — il finirait à l'instant
    -- où il est posé, ce que refuse chk_lpgl_grace_after_lock.
    IF v_new_status IN ('accepted_majority', 'accepted_unanimous') AND v_grace_days > 0 THEN
      INSERT INTO public.library_profile_grace_locks ($a$];
BEGIN
  SELECT md5(replace(prosrc, E'\r', '')) INTO v_md5 FROM pg_proc WHERE oid = v_fn;
  IF v_md5 <> 'c5b8b163aac17cc827d56d7384271778' THEN
    RAISE EXCEPTION 'G16 : % a changé depuis le relevé du 05/10 — relire avant de réécrire', v_fn;
  END IF;
  v_def := replace(pg_get_functiondef(v_fn), E'\r', '');
  FOR v_i IN 1 .. array_length(v_vieux, 1) LOOP
    v_n := (length(v_def) - length(replace(v_def, v_vieux[v_i], ''))) / length(v_vieux[v_i]);
    IF v_n <> 1 THEN
      RAISE EXCEPTION 'G16 : ancre % trouvée % fois (1 attendue)', v_i, v_n;
    END IF;
  END LOOP;
  FOR v_i IN 1 .. array_length(v_vieux, 1) LOOP
    v_def := replace(v_def, v_vieux[v_i], v_neuf[v_i]);
  END LOOP;
  EXECUTE v_def;

  IF pg_get_functiondef(v_fn) NOT LIKE '%unanimous_extended'' THEN 14%'
     OR pg_get_functiondef(v_fn) NOT LIKE '%''for'', ''against'', ''abstain''%'
     OR pg_get_functiondef(v_fn) NOT LIKE '%AND v_grace_days > 0 THEN%' THEN
    RAISE EXCEPTION 'G16 : réécriture incomplète';
  END IF;
END
$mig$;
