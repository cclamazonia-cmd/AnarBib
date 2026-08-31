-- =====================================================================
-- AnarBib -- Un saut dit desormais pourquoi
-- Date    : 2026-08-31  ·  Item B12  ·  doctrine DOC-SILENCE-1
-- Portee  : les CINQ outbox dont un handler peut decider de ne pas envoyer
--
-- CE QUE LE RELEVE A MONTRE.
--
-- Sur 28 lignes de `team_notification_outbox`, 24 sont `sent` et 4 sont
-- `skipped`. Les quatre portent le MEME event -- `network.cross_library_
-- critical_action` -- et ce sont les seules de cet event : il n'est jamais
-- parti, depuis le 8 juin 2026. Tous les autres events partent a 100 %.
-- La cause est un handler manquant dans `_shared/domain/network.ts` ; c'est
-- un item a part (B17), cette migration ne le remplace pas.
--
-- Ce qu'elle corrige est le SILENCE, et il n'etait pas cantonne a un event :
--
--   1. LA RAISON EXISTE MAIS NE SORT PAS DE LA MEMOIRE. Les handlers la
--      nomment -- `unknown_network_event`, `unknown_team_event`,
--      `no_recipients` -- et la jettent, faute d'une colonne pour la
--      recevoir. `last_error` ne peut pas jouer ce role : un saut delibere
--      n'est pas une panne, et les confondre ferait sonner l'alerte sur un
--      comportement voulu.
--
--   2. `sent_at` EST POSE SUR UNE LIGNE DONT RIEN N'EST PARTI. Dans une
--      table qui sert de journal, c'est un mensonge datant. `sent_at` veut
--      dire « un courriel est parti », et rien d'autre.
--
--   3. ET DANS UN CAS, LA TABLE AFFIRME LE CONTRAIRE DE CE QUI S'EST PASSE.
--      `authority.ts` marque `sent` quoi qu'il arrive, y compris quand son
--      propre routage vient de retourner `{ skipped: "unknown_event" }` ou
--      `{ sent: 0, skipped: "no_recipients" }`. Son `status` n'acceptait
--      meme pas la valeur `skipped` : cette migration l'ajoute.
--
-- LES DEUX CHECK NE SONT PAS DECORATIFS. Si un chemin de code marque
-- `skipped` sans raison, l'UPDATE echoue et la ligne part en `failed` avec
-- son message : bruyant, donc reparable. C'est DOC-SILENCE-1 inscrit dans le
-- schema plutot que confie a la discipline.
--
-- HORS PORTEE, ET DELIBEREMENT. Les deux tables `painel_internal_task_*`
-- portent `dispatch_status` et sont servies par la copie gelee de la pile
-- courriel : c'est le terrain de F6, on n'y touche pas en passant.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. La colonne qui manquait
-- ---------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'team_notification_outbox',
    'authority_proposal_notification_outbox',
    'cartography_submission_notification_outbox',
    'gazette_submission_notification_outbox',
    'lettre_notification_outbox'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS skip_reason text', t);

    EXECUTE format(
      'COMMENT ON COLUMN public.%I.skip_reason IS %L', t,
      'Raison pour laquelle aucun courriel n''a ete emis alors que la ligne a ete '
      'traitee sans erreur (status = ''skipped''). Valeurs ecrites par les handlers : '
      'unknown_<domaine>_event, no_recipients. DISTINCTE de last_error : un saut '
      'delibere n''est pas une panne, et les confondre ferait sonner l''alerte sur un '
      'comportement voulu. Item B12, doctrine DOC-SILENCE-1.');
  END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 2. `authority` peut enfin dire qu'elle n'a pas envoye
-- ---------------------------------------------------------------------
-- Son enum de statut valait ('queued','sent','failed') : le handler n'avait
-- litteralement pas le vocabulaire pour dire « je n'ai rien envoye », d'ou le
-- `sent` par defaut. Le code cesse de mentir dans le meme commit.
ALTER TABLE public.authority_proposal_notification_outbox
  DROP CONSTRAINT IF EXISTS authority_outbox_status_chk;
ALTER TABLE public.authority_proposal_notification_outbox
  ADD  CONSTRAINT authority_outbox_status_chk
       CHECK (status = ANY (ARRAY['queued'::text, 'sent'::text, 'failed'::text, 'skipped'::text]));

-- ---------------------------------------------------------------------
-- 3. Reprise des lignes existantes -- AVANT de poser la garde
-- ---------------------------------------------------------------------
-- Les quatre lignes sautees de production portent toutes le meme event, et
-- leur raison a ete etablie en LISANT LE CODE, pas en relisant un journal --
-- il n'y en avait pas. On l'inscrit, nommee comme le code la nomme, pour que
-- la reprise (rejouer ou clore) se decide sur une raison et non sur une
-- conjecture.
--
-- `sent_at` repasse a NULL sur ces lignes : aucun courriel n'en est parti. La
-- date de traitement reste dans `created_at` ; ce qui disparait ici est une
-- information fausse.
--
-- En CI la base est reconstruite depuis le baseline et le seed : ces UPDATE
-- ne touchent alors aucune ligne, et c'est normal.
UPDATE public.team_notification_outbox
   SET skip_reason = 'unknown_network_event', sent_at = NULL
 WHERE status = 'skipped' AND skip_reason IS NULL
   AND event = 'network.cross_library_critical_action';

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'team_notification_outbox',
    'authority_proposal_notification_outbox',
    'cartography_submission_notification_outbox',
    'gazette_submission_notification_outbox',
    'lettre_notification_outbox'
  ] LOOP
    EXECUTE format(
      'UPDATE public.%I SET skip_reason = %L, sent_at = NULL '
      'WHERE status = ''skipped'' AND skip_reason IS NULL',
      t, 'raison_non_consignee_avant_B12');
  END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 4. Les gardes -- EN DERNIER, et c'est le point de la reprise
-- ---------------------------------------------------------------------
-- ORDRE. Une premiere version de cette migration posait les CHECK avant la
-- reprise des lignes. Sur une base RECONSTRUITE -- celle de la CI, qui part du
-- baseline et du seed -- il n'y a aucune ligne sautee, donc rien ne casse et
-- la suite passe au vert. Sur la PRODUCTION, la contrainte a trouve les quatre
-- lignes qu'elle est justement chargee de faire disparaitre :
--
--   ERROR: check constraint "team_notification_outbox_skip_reason_chk"
--          is violated by some row (SQLSTATE 23514)
--
-- Une migration qui ne casse que sur des donnees existantes est INVISIBLE a un
-- banc d'essai qui part de zero. La CI ne pouvait pas le dire ; seul `db push`
-- le pouvait. D'ou la regle : colonne, puis reprise, puis garde -- jamais
-- l'inverse.
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'team_notification_outbox',
    'authority_proposal_notification_outbox',
    'cartography_submission_notification_outbox',
    'gazette_submission_notification_outbox',
    'lettre_notification_outbox'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT IF EXISTS %I', t, t || '_skip_reason_chk');
    EXECUTE format(
      'ALTER TABLE public.%I ADD CONSTRAINT %I CHECK (status <> ''skipped'' OR skip_reason IS NOT NULL)',
      t, t || '_skip_reason_chk');

    EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT IF EXISTS %I', t, t || '_skipped_sent_at_chk');
    EXECUTE format(
      'ALTER TABLE public.%I ADD CONSTRAINT %I CHECK (status <> ''skipped'' OR sent_at IS NULL)',
      t, t || '_skipped_sent_at_chk');
  END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- Verification -- annule tout si l'etat vise n'est pas atteint
-- ---------------------------------------------------------------------
DO $$
DECLARE
  v_n int;
  v_txt text;
BEGIN
  SELECT count(*) INTO v_n
    FROM information_schema.columns
   WHERE table_schema = 'public' AND column_name = 'skip_reason'
     AND table_name IN ('team_notification_outbox',
                        'authority_proposal_notification_outbox',
                        'cartography_submission_notification_outbox',
                        'gazette_submission_notification_outbox',
                        'lettre_notification_outbox');
  IF v_n <> 5 THEN
    RAISE EXCEPTION 'ECHEC : % colonne(s) skip_reason au lieu de 5', v_n;
  END IF;

  SELECT count(*) INTO v_n
    FROM pg_constraint
   WHERE conname LIKE '%\_skip\_reason\_chk' OR conname LIKE '%\_skipped\_sent\_at\_chk';
  IF v_n <> 10 THEN
    RAISE EXCEPTION 'ECHEC : % garde(s) au lieu de 10 (5 tables x 2)', v_n;
  END IF;

  -- `authority` a desormais le mot pour le dire.
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'authority_outbox_status_chk'
       AND pg_get_constraintdef(oid) LIKE '%skipped%'
  ) THEN
    RAISE EXCEPTION 'ECHEC : authority_proposal_notification_outbox ne connait toujours pas skipped';
  END IF;

  SELECT count(*) INTO v_n
    FROM public.team_notification_outbox
   WHERE status = 'skipped' AND (skip_reason IS NULL OR sent_at IS NOT NULL);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'ECHEC : % ligne(s) sautee(s) encore muette(s)', v_n;
  END IF;

  SELECT string_agg(skip_reason || ' x' || n, ', ' ORDER BY skip_reason) INTO v_txt
    FROM (SELECT skip_reason, count(*) n FROM public.team_notification_outbox
           WHERE status = 'skipped' GROUP BY skip_reason) s;
  RAISE NOTICE 'OK : 5 colonnes, 10 gardes, authority sait dire skipped. Lignes reprises : %',
               coalesce(v_txt, 'aucune (base reconstruite)');
END $$;

COMMIT;
