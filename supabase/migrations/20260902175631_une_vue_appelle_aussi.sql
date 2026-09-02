-- B20, rattrapage : une vue appelle aussi — trois fonctions rouvertes à `authenticated`.
--
-- ============================================================================
-- LE CONSTAT (02/09/2026, en préparant les captures du Manuel v5)
-- ============================================================================
-- L'onglet Círculos de /federacao affichait « Sua biblioteca ainda não faz
-- parte de nenhum círculo » pour la BLMF, membre de trois cercles. Console :
--   apiQuery my_library_circles_v1 failed: 403 {"code":"42501",
--   "message":"permission denied for function fn_circle_member_count"}
--
-- Les trois campagnes de fermeture (20260901140139, 20260902103305,
-- 20260902104830) avaient mesuré « 0 appelant SQL, 0 policy, 0 cron » et
-- « 0 occurrence dans src/ ». Les deux mesures étaient vraies et la conclusion
-- fausse : ces fonctions sont appelées par des VUES `api` en
-- `security_invoker = true`, et le front lit les vues, pas les fonctions.
-- Une vue security_invoker exécute ses fonctions sous le rôle de la personne
-- qui la lit : EXECUTE lui est donc nécessaire, PostgREST rend 403 sinon.
-- pg_depend le savait (classid = pg_rewrite) ; prosrc et le grep de src/
-- ne pouvaient pas le voir.
--
--   fonction                                  vue(s) appelante(s)             écran
--   public.fn_circle_member_count(uuid)       my_library_circles_v1,          FederacaoPage (Círculos),
--                                             circles_directory_v1            EntraideTab
--   public.fn_assembleia_facilitator_name     assembleia_facilitators_v1      AssembleiasTab
--   api.get_remaining_renewals(...)           my_loans_renewal_status_v1      AccountPage (Empréstimos em curso),
--                                             (+ _by_item, + staff_*)         PanelPage, TabEmprestimos
--
-- Rien n'est rouvert à `anon` : aucune de ces sept vues n'est lisible par
-- anon. Le grant `service_role` explicite est inchangé.
--
-- DETTE conservée : `fn_assembleia_facilitator_name` avait été fermée le
-- 01/09 pour une raison de fond (aucune garde, identité + rôle militant pour
-- n'importe quel identifiant). La vue qui l'appelle EST l'écran des
-- facilitateur·rices ; la rouvrir rend l'écran, pas la garde. Le geste
-- propre est de faire porter le nom par la vue elle-même (jointure sous RLS)
-- et de refermer la fonction — à faire avec le chantier assembleias.
--
-- LEÇON pour la prochaine campagne (à porter au registre B2/B20) : avant un
-- REVOKE, interroger pg_depend avec classid = 'pg_rewrite'::regclass — les
-- vues sont des appelants, et security_invoker les fait appeler sous le rôle
-- du lecteur.

GRANT EXECUTE ON FUNCTION public.fn_circle_member_count(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_assembleia_facilitator_name(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION api.get_remaining_renewals(uuid, uuid, bigint, bigint, integer, integer, date) TO authenticated;

COMMENT ON FUNCTION public.fn_assembleia_facilitator_name(uuid) IS
  'Nom d''une personne facilitatrice d''assemblée. Fermée à authenticated le 01/09/2026 (B14, paquet 7) puis ROUVERTE le 02/09/2026 : la vue api.assembleia_facilitators_v1 (security_invoker), lue par AssembleiasTab, l''appelle sous le rôle du lecteur — la campagne n''avait pas regardé pg_rewrite. Dette : faire porter le nom par la vue (jointure sous RLS) et refermer la fonction. Toujours fermée à anon.';

-- ============================================================================
-- GARDES DE FIN
-- ============================================================================
DO $$
DECLARE
  v_liste text;
BEGIN
  -- 1) Les trois sont ouvertes à authenticated : sinon les sept vues rendent 403.
  SELECT string_agg(n.nspname||'.'||p.proname, ', ') INTO v_liste
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE ((n.nspname = 'public' AND p.proname IN ('fn_circle_member_count','fn_assembleia_facilitator_name'))
      OR (n.nspname = 'api' AND p.proname = 'get_remaining_renewals'))
    AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE');
  IF v_liste IS NOT NULL THEN
    RAISE EXCEPTION 'toujours fermée à authenticated : % — rollback', v_liste;
  END IF;

  -- 2) Aucune n'est ouverte à anon : le rattrapage ne rouvre que la porte des membres.
  SELECT string_agg(n.nspname||'.'||p.proname, ', ') INTO v_liste
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE ((n.nspname = 'public' AND p.proname IN ('fn_circle_member_count','fn_assembleia_facilitator_name'))
      OR (n.nspname = 'api' AND p.proname = 'get_remaining_renewals'))
    AND has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_liste IS NOT NULL THEN
    RAISE EXCEPTION 'ouverte à anon par erreur : % — rollback', v_liste;
  END IF;

  -- 3) Les vues appelantes existent toujours et sont bien en security_invoker
  --    (sinon ce rattrapage n'aurait plus d'objet et quelqu'un doit le savoir).
  SELECT string_agg(c.relname, ', ') INTO v_liste
  FROM (VALUES ('my_library_circles_v1'),('circles_directory_v1'),('assembleia_facilitators_v1'),
               ('my_loans_renewal_status_v1'),('staff_loans_renewal_status_v1')) v(nom)
  LEFT JOIN pg_class c ON c.relname = v.nom
       AND c.relnamespace = 'api'::regnamespace
       AND c.relkind = 'v'
       AND 'security_invoker=true' = ANY (c.reloptions)
  WHERE c.oid IS NULL;
  IF v_liste IS NOT NULL THEN
    RAISE EXCEPTION 'vue appelante absente ou plus en security_invoker : % — relire ce rattrapage', v_liste;
  END IF;
END $$;
