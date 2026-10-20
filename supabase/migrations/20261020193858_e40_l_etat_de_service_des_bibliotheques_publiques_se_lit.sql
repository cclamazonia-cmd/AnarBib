-- E40 (20/10/2026) — l'état de service d'une bibliothèque publique se lit
-- sans compte.
--
-- La page publique `/bibliotecas/:slug` lit `api.library_service_public`
-- (vue invoker) pour son « mot public ». La vue lit `library_service_state`,
-- dont la seule politique de lecture est celle de l'équipe
-- (`user_can_act_as_staff_on_library`) : vérifié le 19/10 sous le rôle
-- anonyme, 0 ligne, même pour les bibliothèques publiques. Le mot public ne
-- s'affichait jamais à qui en a besoin.
--
-- Même modèle que le contact public (`library_public_contact_read_optin`) :
-- une politique de lecture, pour anon et authenticated, limitée aux
-- bibliothèques actives ET publiques. Une bibliothèque privée ne montre rien.
--
-- Les champs : ceux que portent les deux vues publiques, et rien d'autre —
-- mode de service, mot public, réservations et prêts ouverts ou non, date de
-- mise à jour. Les réglages de consultation (fuseau, horaire, nombre de
-- consultations simultanées) et les notes de lecture restent à l'équipe :
-- `anon` perd le droit de table et ne garde que ces colonnes. `authenticated`
-- garde le droit de table (l'équipe lit et écrit tout, sous sa politique).

DROP POLICY IF EXISTS library_service_state_read_public ON public.library_service_state;
CREATE POLICY library_service_state_read_public ON public.library_service_state
  FOR SELECT TO anon, authenticated
  USING (EXISTS (SELECT 1 FROM public.libraries l
                  WHERE l.id = library_service_state.library_id
                    AND l.is_active = true
                    AND l.visibility_level = 'public'));

REVOKE ALL ON TABLE public.library_service_state FROM anon;
GRANT SELECT (library_id, service_mode, public_message, allows_new_reservations, allows_new_loans, updated_at)
  ON TABLE public.library_service_state TO anon;

DO $e40_verif$
DECLARE v_e text := '';
BEGIN
  IF has_column_privilege('anon', 'public.library_service_state', 'consultation_schedule_struct', 'SELECT') THEN v_e := v_e || ' horaire'; END IF;
  IF has_column_privilege('anon', 'public.library_service_state', 'max_simultaneous_consultations', 'SELECT') THEN v_e := v_e || ' consultations'; END IF;
  IF NOT has_column_privilege('anon', 'public.library_service_state', 'public_message', 'SELECT') THEN v_e := v_e || ' mot-public'; END IF;
  IF has_table_privilege('anon', 'public.library_service_state', 'INSERT,UPDATE,DELETE') THEN v_e := v_e || ' ecriture'; END IF;
  IF NOT has_table_privilege('anon', 'api.library_service_public', 'SELECT') THEN v_e := v_e || ' vue'; END IF;
  IF v_e <> '' THEN RAISE EXCEPTION 'E40 : vérification en échec :%', v_e; END IF;
  RAISE NOTICE 'E40 : l''état de service des bibliothèques publiques se lit sans compte.';
END
$e40_verif$;

NOTIFY pgrst, 'reload schema';
