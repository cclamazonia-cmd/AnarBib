-- ============================================================================
-- Un filtre de langue atteint les variantes régionales, côté serveur aussi
--
-- Le catalogue a DEUX chemins de filtrage. Le 22/10 j'ai élargi celui du client
-- (`buildServerFilters`) pour que « pt » atteigne les notices en « pt-BR » — le
-- référentiel des notices écrit le portugais ainsi, et les descripteurs de
-- langue du thésaurus FICEDL le nomment par le code court. Mais le mode
-- « œuvres », qui est celui affiché par défaut, filtre ICI, dans
-- `api.catalog_works_v1`, et portait la même égalité stricte :
--
--     CASE WHEN p.language ~ '^[a-z]{2}(-[A-Z]{2})?$'
--          THEN s.idioma = p.language
--          ELSE s.idioma ILIKE '%' || p.language || '%' END
--
-- Résultat : `?idioma=pt` rendait « Œuvres : 0 » alors que la fiche du
-- descripteur « portugais » annonçait 1 278 notices. Le défaut a été vu en
-- cliquant le lien, pas en mesurant — la mesure, elle, portait sa propre union.
--
-- RÈGLE RETENUE, la même aux deux endroits : un code de langue SANS région
-- désigne la langue, donc ses variantes régionales. « pt » prend « pt-BR »,
-- « fr » prendrait « fr-CA ». Un code complet reste une égalité stricte, et une
-- saisie libre garde son ILIKE (résidu d'avant la normalisation, CONV-7).
--
-- POURQUOI CETTE MIGRATION NE RECOPIE PAS LA FONCTION. Elle fait 16,6 Ko. La
-- retranscrire pour n'en changer qu'une ligne, c'est offrir une faute de frappe
-- invisible dans 16 600 caractères. La migration DÉRIVE donc la définition de
-- l'état réel (`pg_get_functiondef`) et n'y remplace que la condition — avec un
-- garde-fou qui exige EXACTEMENT une occurrence et échoue sinon. Elle rend le
-- même résultat sur la production et sur le dépôt rejoué, puisque les deux
-- partent de la même définition.
--
-- Attributs conservés : CREATE OR REPLACE garde les droits (anon et
-- authenticated ont EXECUTE), et `pg_get_functiondef` réémet SECURITY INVOKER,
-- STABLE et `search_path=public, pg_catalog`.
-- ============================================================================

DO $maj$
DECLARE
  v_def text;
  v_motif constant text := 's.idioma = p.language';
  v_neuf  constant text := '(s.idioma = p.language OR (p.language ~ ''^[a-z]{2}$'' AND s.idioma LIKE p.language || ''-%''))';
  v_n int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p
   WHERE p.proname = 'catalog_works_v1'
     AND p.pronamespace = 'api'::regnamespace;

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'api.catalog_works_v1 est absente : migration à revoir avant de la rejouer';
  END IF;

  -- Déjà élargie ? (migration rejouée) On ne touche à rien.
  IF position(v_neuf in v_def) > 0 THEN
    RAISE NOTICE 'api.catalog_works_v1 porte déjà le filtre élargi : rien à faire.';
    RETURN;
  END IF;

  v_n := (length(v_def) - length(replace(v_def, v_motif, ''))) / length(v_motif);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'attendu UNE occurrence de « % » dans api.catalog_works_v1, trouvé % : la fonction a changé, migration à revoir', v_motif, v_n;
  END IF;

  EXECUTE replace(v_def, v_motif, v_neuf);
  RAISE NOTICE 'api.catalog_works_v1 : le filtre de langue atteint désormais les variantes régionales.';
END
$maj$;

-- Contrôle structurel : la condition élargie est bien dans le corps, et la
-- fonction garde ses attributs. (DOC : une migration vérifie le catalogue
-- système, pas un comportement métier — celui-là est tenu par les tests.)
DO $ctrl$
DECLARE v_ok boolean;
BEGIN
  SELECT p.prosrc LIKE '%s.idioma LIKE p.language || ''-%''%'
         AND p.prosecdef = false
         AND p.provolatile = 's'
    INTO v_ok
    FROM pg_proc p
   WHERE p.proname = 'catalog_works_v1' AND p.pronamespace = 'api'::regnamespace;
  IF NOT v_ok THEN
    RAISE EXCEPTION 'api.catalog_works_v1 : filtre élargi absent, ou attributs perdus (INVOKER/STABLE)';
  END IF;
END
$ctrl$;
