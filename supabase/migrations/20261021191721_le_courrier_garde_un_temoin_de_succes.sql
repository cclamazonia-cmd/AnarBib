-- =====================================================================
-- Le courrier garde un témoin de ses succès, par canal (21/10/2026)
-- =====================================================================
-- Date     : 2026-10-21
-- Chantier : sortie de Resend par le relais SMTP Nodo50 (étape 7, surveillance)
-- Auteur   : AnarBib
-- Session  : Sortie de Resend par Nodo50
--
-- Le 21/10, on ne pouvait pas dire si les envois fonctionnaient. Les journaux
-- des fonctions ne remontent qu'à vingt-quatre heures, mail_transport_failures
-- ne note que les échecs, et Nodo50 n'offre ni API ni tableau des envois :
-- seul Resend tient son propre registre, et il partira à l'étape 8. Un silence
-- de deux jours pouvait vouloir dire « aucune activité » comme « plus rien ne
-- part ». Pour les quatre semaines d'observation qui suivent la bascule, il
-- faut un témoin de succès en base, le même pour les deux canaux.
--
-- Ici : une ligne par canal (`resend`, `smtp`) et par jour UTC, qui compte les
-- courriels acceptés par le transport et garde l'heure du premier et du
-- dernier. `_shared/transport/email.ts` appelle `fn_mail_envoi_reussi` après
-- chaque envoi accepté (Resend 2xx, relais SMTP « 250 ») — un message compte
-- une fois, rejeux compris ; un échec, un rejeu raté et la simulation
-- (MAIL_TRANSPORT=mock) ne comptent pas. Si l'appel échoue, l'envoi n'en
-- souffre pas : le transport l'avale et le dit une fois par isolat.
--
-- Ce qu'on n'écrit PAS : ni adresse, ni libellé, ni objet. Un canal, un jour,
-- un nombre, deux heures. Les jours au-delà de trente-et-un sont effacés à
-- chaque appel (la table tient en une soixantaine de lignes).
--
-- La sonde fn_healthcheck_mail_transport n'est pas modifiée : elle pourra lire
-- cette table plus tard (« aucun succès depuis N heures sur le canal actif »)
-- si la coordination le décide.
-- =====================================================================

CREATE TABLE IF NOT EXISTS private.mail_temoin_jour (
  canal          text        NOT NULL CHECK (canal ~ '^[a-z0-9_-]{1,40}$'),
  jour           date        NOT NULL,
  envois         integer     NOT NULL DEFAULT 1 CHECK (envois >= 0),
  premier_succes timestamptz NOT NULL,
  dernier_succes timestamptz NOT NULL,
  PRIMARY KEY (canal, jour)
);
ALTER TABLE private.mail_temoin_jour ENABLE ROW LEVEL SECURITY;
-- service_role lit (une sonde pourra s'en servir) ; seule la fonction écrit.
REVOKE ALL ON private.mail_temoin_jour FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON private.mail_temoin_jour TO service_role;
COMMENT ON TABLE private.mail_temoin_jour IS
  'Sortie de Resend (21/10/2026) : le nombre de courriels acceptés par le transport, par canal (`resend`, `smtp`) et par jour UTC, avec l''heure du premier et du dernier succès. Écrite seulement par public.fn_mail_envoi_reussi ; trente-et-un jours gardés. Ne porte aucune donnée personnelle (ni adresse, ni libellé, ni objet).';

CREATE OR REPLACE FUNCTION public.fn_mail_envoi_reussi(p_canal text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_maintenant timestamptz := clock_timestamp();
  v_jour       date := (clock_timestamp() AT TIME ZONE 'UTC')::date;
BEGIN
  IF p_canal IS NULL OR p_canal !~ '^[a-z0-9_-]{1,40}$' THEN
    RAISE EXCEPTION 'canal invalide' USING ERRCODE = '22023';
  END IF;

  INSERT INTO private.mail_temoin_jour AS t (canal, jour, envois, premier_succes, dernier_succes)
  VALUES (p_canal, v_jour, 1, v_maintenant, v_maintenant)
  ON CONFLICT (canal, jour) DO UPDATE
     SET envois = t.envois + 1,
         dernier_succes = greatest(t.dernier_succes, v_maintenant);

  DELETE FROM private.mail_temoin_jour WHERE jour < v_jour - 30;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_mail_envoi_reussi(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_mail_envoi_reussi(text) TO service_role;
COMMENT ON FUNCTION public.fn_mail_envoi_reussi(text) IS
  'Sortie de Resend (21/10/2026) : compte un courriel accepté par le transport du canal (`resend`, `smtp`) pour le jour UTC courant et met à jour l''heure du dernier succès. Appelée par _shared/transport/email.ts après chaque envoi réussi ; service_role seul.';

-- ─── Vérification : porte sur ce que CETTE migration fait (DOC-DEPLOY-4) ────
DO $verif$
BEGIN
  IF to_regclass('private.mail_temoin_jour') IS NULL THEN
    RAISE EXCEPTION 'private.mail_temoin_jour absente';
  END IF;
  IF has_function_privilege('anon', 'public.fn_mail_envoi_reussi(text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_mail_envoi_reussi(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_mail_envoi_reussi ouverte à anon ou authenticated';
  END IF;
  IF NOT has_function_privilege('service_role', 'public.fn_mail_envoi_reussi(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_mail_envoi_reussi fermée à service_role';
  END IF;
END
$verif$;

NOTIFY pgrst, 'reload schema';
