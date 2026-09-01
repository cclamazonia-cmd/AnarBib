-- ===========================================================================
-- « Es-tu staff ? » et « où ? » doivent désigner la MÊME bibliothèque
-- ===========================================================================
--
-- CE QUE CETTE SUITE EMPÊCHE DE REVENIR. `api.my_access` rend deux colonnes que
-- **trente-sept fonctions** lisent ensemble — dont **vingt-quatre qui écrivent** :
-- circulation, cotisations, dépôts, import. Jusqu'au 01/09/2026 elles ne
-- parlaient pas de la même bibliothèque :
--
--   * `can_access_painel` = « as-tu un rôle staff **quelque part** ? »
--   * `library_id`        = « quelle est ta bibliothèque **principale** ? »
--
-- Une personne bibliothécaire à A et simple lectrice à B, avec **B pour
-- bibliothèque principale**, obtenait le panneau de B. `fn_record_deposit` et
-- `fn_record_membership_payment` vérifient `v_actor.library_id` : elles n'ont
-- aucun moyen de savoir que la réponse vient d'ailleurs.
--
-- Le défaut a été DÉMONTRÉ en production, en transaction annulée, en armant le
-- cas (l'adhésion lectrice désignée principale) : la vue d'alors répondait
-- `btl painel=true`, la vue corrigée répond `blmf painel=true role=librarian`.
--
-- Le correctif tient à **un mot dans un ORDER BY** (`is_staff DESC` avant
-- `is_primary DESC`) et à une formule alignée sur l'adhésion effective. C'est
-- exactement le genre de détail qu'un `CREATE OR REPLACE VIEW` ultérieur
-- emporte sans bruit — d'où le T3, qui garde la forme, et le T1, qui garde
-- l'effet. Les deux sont nécessaires : le T3 seul passerait si la formule de
-- `can_access_painel` était redéfaite, et le T1 seul ne dirait pas pourquoi.
-- ===========================================================================

DO $$
DECLARE
  v_passed  int := 0;
  v_failed  int := 0;
  v_skipped int := 0;
  v_failures text[] := '{}';
  v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_blmf  uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_autre uuid;
  v_lib   uuid;
  v_painel boolean;
  v_role  text;
  v_def   text;
  v_n     int;
BEGIN
  -- ---------------------------------------------------------------------
  -- T1 — l'épreuve : une adhésion NON staff désignée principale ailleurs
  --      ne doit PAS emporter la bibliothèque de travail
  -- ---------------------------------------------------------------------
  v_t := 'T1 une adhesion lectrice principale n emporte pas la biblio de travail';
  BEGIN
    -- La personne du seed doit exister : hors de la base de CI (en production,
    -- par exemple), cet identifiant n'a pas de compte et l'insertion échouerait
    -- sur une clé étrangère. Une fixture absente est un SKIP déclaré, jamais un
    -- échec — sinon la suite crie « régression » là où elle n'a rien mesuré.
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_coord) THEN
      v_skipped := v_skipped + 1;
      RAISE NOTICE 'T1 saute : la personne de seed % n''existe pas dans cette base', v_coord;
    ELSE

    SELECT id INTO v_autre FROM public.libraries WHERE id <> v_blmf AND is_active
     ORDER BY slug LIMIT 1;
    IF v_autre IS NULL THEN
      INSERT INTO public.libraries (slug, name)
      VALUES ('my-access-test', 'Bibliotheque de test — my_access') RETURNING id INTO v_autre;
    END IF;

    -- On ARME le défaut : lectrice ailleurs, et c'est cette adhésion-là qui
    -- porte `is_primary`. Le tri d'avant la prenait ; celui d'aujourd'hui non.
    UPDATE public.user_library_memberships SET is_primary = false WHERE user_id = v_coord;
    INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
    VALUES (v_coord, v_autre, 'reader', 'active', true)
    -- L'unicité porte sur (user_id, library_id, ROLE) : une même personne peut
    -- porter deux rôles dans une même bibliothèque. Le conflit se déclare donc
    -- sur les trois colonnes, sinon l'insertion échoue au lieu de reprendre.
    ON CONFLICT (user_id, library_id, role)
      DO UPDATE SET status = 'active', is_primary = true;

    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

    SELECT library_id, can_access_painel, role
      INTO v_lib, v_painel, v_role
      FROM public.my_access LIMIT 1;

    PERFORM set_config('request.jwt.claims', NULL, true);

    IF v_lib IS NULL THEN
      -- La vue ne rend rien pour cette personne dans cette base : le test n'a
      -- pas de matière. On le déclare, on ne le fait pas passer en silence.
      v_skipped := v_skipped + 1;
    ELSIF v_lib = v_blmf AND v_painel AND v_role IN ('librarian','coordenador') THEN
      v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : library_id=' || coalesce(v_lib::text,'null')
        || ' painel=' || coalesce(v_painel::text,'null') || ' role=' || coalesce(v_role,'null')
        || ' | le panneau s ouvre sur une bibliotheque ou la personne n a aucun role,'
        || ' et 24 fonctions d ecriture y ecrivent (circulation, cotisations, depots)');
    END IF;

    END IF;  -- fin du garde-fou « la personne de seed existe »
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', NULL, true);
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T2 — la vue ne retombe pas en SECURITY DEFINER
  -- ---------------------------------------------------------------------
  -- `CREATE OR REPLACE VIEW` réinitialise les options. Ce piège a exposé
  -- l'annuaire pendant une heure le 31/08/2026.
  v_t := 'T2 api.my_access reste en security_invoker';
  BEGIN
    SELECT count(*) INTO v_n
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'api' AND c.relname = 'my_access'
       AND c.reloptions @> ARRAY['security_invoker=true'];

    IF v_n = 1 THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : option absente'
        || ' | la vue contournerait la RLS pour tout le monde');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T3 — le rôle passe devant la préférence d'affichage dans le tri
  -- ---------------------------------------------------------------------
  -- Le correctif tient à un mot. Un `CREATE OR REPLACE VIEW` distrait le
  -- reprendrait sans que rien ne rougisse — sauf ici.
  v_t := 'T3 l adhesion effective prefere un role staff';
  BEGIN
    v_def := pg_get_viewdef('api.my_access'::regclass, true);
    IF v_def ~ 'is_staff DESC' AND v_def ~ 'is_staff' THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : « is_staff DESC » a disparu du tri'
        || ' | can_access_painel et library_id peuvent de nouveau designer'
        || ' deux bibliotheques differentes');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T4 — la liste de colonnes ne bouge pas
  -- ---------------------------------------------------------------------
  -- `public.my_access` nomme ses colonnes une à une : un ajout en amont la
  -- laisserait muette sur la nouvelle, un retrait la casserait.
  v_t := 'T4 api.my_access rend toujours 20 colonnes';
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.columns
     WHERE table_schema = 'api' AND table_name = 'my_access';
    IF v_n = 20 THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : ' || v_n || ' colonnes'
        || ' | public.my_access les nomme une a une et ne suivrait plus');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- =====================================================================
  -- BILAN (le RAISE annule les fixtures : adhésions et bibliothèque créées)
  -- =====================================================================
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'MY_ACCESS_BIBLIO_EFFECTIVE OK : %/% tests passés (% skips)',
      v_passed, (v_passed + v_failed), v_skipped;
  ELSE
    RAISE EXCEPTION 'MY_ACCESS_BIBLIO_EFFECTIVE ECHEC : %/% OK, % échec(s), % skip(s) | %',
      v_passed, (v_passed + v_failed), v_failed, v_skipped, array_to_string(v_failures, ' || ');
  END IF;
END $$;
