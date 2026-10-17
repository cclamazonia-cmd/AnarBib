-- =====================================================================
-- F25 suite (17/10/2026) — une cadence commune à tous les isolats pour les
-- envois Resend.
--
-- Le 09/10, quatorze propositions de l'Atelier versées d'un coup ont fait 72
-- envois en deux secondes : 58 refusés par Resend (429, dix requêtes par
-- seconde au plus). Le correctif du 09/10 (6b03ebe4) cadence les envois d'un
-- MÊME isolat (huit par seconde) et rejoue un 429. L'épreuve réelle du 17/10 à
-- 03 h 45 UTC (le cron de résolution a résolu les quatorze propositions de C4
-- d'un coup) a montré la limite : quatorze isolats en parallèle, chacun à huit
-- par seconde ; 72 courriels partis, aucun perdu, mais 82 réponses 429
-- rattrapées par le rejeu, dont une au troisième et dernier essai.
--
-- Ici : une ligne par canal d'envoi (`resend`), qui porte le prochain créneau
-- libre. Chaque envoi réserve le sien par `fn_mail_cadence_creneau` — la mise
-- à jour verrouille la ligne, donc deux isolats ne réservent jamais le même —
-- et reçoit le nombre de millisecondes à attendre. La cadence devient celle
-- du réseau entier, plus celle d'un isolat. Le transport retombe sur sa
-- cadence locale si la fonction manque ou échoue (une pile qui n'a pas encore
-- cette migration) : le rejeu reste le filet.
-- =====================================================================

CREATE TABLE IF NOT EXISTS private.mail_cadence (
  canal            text        PRIMARY KEY CHECK (char_length(canal) BETWEEN 1 AND 40),
  prochain_creneau timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE private.mail_cadence ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.mail_cadence FROM PUBLIC, anon, authenticated;
GRANT ALL ON private.mail_cadence TO service_role;
COMMENT ON TABLE private.mail_cadence IS
  'F25 (17/10/2026) : le prochain créneau d''envoi libre par canal (`resend`), commun à tous les isolats des Edge Functions. Écrite seulement par public.fn_mail_cadence_creneau ; une ligne par canal, créée au premier envoi. Ne porte aucune donnée personnelle.';

CREATE OR REPLACE FUNCTION public.fn_mail_cadence_creneau(p_canal text, p_intervalle_ms integer)
RETURNS integer
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_maintenant timestamptz := clock_timestamp();
  v_pas        interval;
  v_creneau    timestamptz;
BEGIN
  IF p_canal IS NULL OR char_length(p_canal) NOT BETWEEN 1 AND 40 THEN
    RAISE EXCEPTION 'canal invalide' USING ERRCODE = '22023';
  END IF;
  -- Le pas est borné : zéro (pas de cadence) à deux secondes.
  v_pas := make_interval(secs => least(greatest(coalesce(p_intervalle_ms, 125), 0), 2000) / 1000.0);

  INSERT INTO private.mail_cadence AS c (canal, prochain_creneau)
  VALUES (p_canal, v_maintenant + v_pas)
  ON CONFLICT (canal) DO UPDATE
     SET prochain_creneau = greatest(c.prochain_creneau, v_maintenant) + v_pas
  RETURNING c.prochain_creneau - v_pas INTO v_creneau;

  -- Millisecondes à attendre avant d'envoyer (0 si le créneau est déjà là).
  RETURN greatest(0, ceil(extract(epoch FROM (v_creneau - v_maintenant)) * 1000))::integer;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_mail_cadence_creneau(text, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_mail_cadence_creneau(text, integer) TO service_role;
COMMENT ON FUNCTION public.fn_mail_cadence_creneau(text, integer) IS
  'F25 (17/10/2026) : réserve le prochain créneau d''envoi du canal (pas = p_intervalle_ms, borné à 0-2000) et rend les millisecondes à attendre. Appelée par _shared/transport/email.ts avant chaque envoi Resend, rejeux compris ; service_role seul.';
