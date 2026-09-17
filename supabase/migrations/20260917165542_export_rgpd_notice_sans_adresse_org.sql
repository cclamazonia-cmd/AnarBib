-- ============================================================================
-- La notice RGPD de l'export personnel ne cite plus contato@anarbib.org
-- ============================================================================
-- Décision Xavier du 16/09/2026 : éviter de s'appuyer sur des adresses en .org ;
-- le canal humain montré aux gens est celui de l'oficina, anarbib@proton.me.
-- La passe du 17/09 a retiré l'adresse des textes de l'application (politique de
-- confidentialité, notice du fichier exporté, mail d'invitation) ; il restait
-- la chaîne 'rgpd_notice' construite par public.fn_export_my_data() elle-même.
--
-- Méthode : on repart de la DÉFINITION RÉELLE (pg_get_functiondef sur la base
-- où la migration s'exécute), on y remplace la seule adresse, on rejoue le
-- CREATE OR REPLACE — droits, propriétaire et search_path conservés. Aucune
-- copie du corps ici : le baseline ment parfois (B14), et 7,5 Ko recopiés sont
-- 7,5 Ko à relire. Idempotent : sans occurrence, rien n'est réécrit.
--
-- Vérifié en production le 17/09/2026 (lecture seule) : une seule fonction
-- porte l'adresse, public.fn_export_my_data(), une occurrence ; invoker,
-- STABLE, garde auth.uid() en tête.
-- ============================================================================

DO $$
DECLARE
  v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_export_my_data'::regproc);
  IF v_def NOT LIKE '%contato@anarbib.org%' THEN
    RAISE NOTICE 'fn_export_my_data : adresse déjà remplacée, rien à faire';
    RETURN;
  END IF;
  IF (length(v_def) - length(replace(v_def, 'contato@anarbib.org', ''))) / length('contato@anarbib.org') <> 1 THEN
    RAISE EXCEPTION 'fn_export_my_data : nombre d''occurrences inattendu, migration à relire';
  END IF;
  EXECUTE replace(v_def, 'contato@anarbib.org', 'anarbib@proton.me');
END $$;

-- Vérification : ce que la migration fait, pas un invariant global (DOC-DEPLOY-4).
DO $$
DECLARE
  v_src text;
BEGIN
  SELECT prosrc INTO v_src FROM pg_proc WHERE oid = 'public.fn_export_my_data'::regproc;
  IF v_src LIKE '%contato@anarbib.org%' THEN
    RAISE EXCEPTION 'fn_export_my_data porte encore contato@anarbib.org';
  END IF;
  IF v_src NOT LIKE '%anarbib@proton.me%' THEN
    RAISE EXCEPTION 'fn_export_my_data ne porte pas anarbib@proton.me';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.fn_export_my_data()', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_export_my_data : le droit EXECUTE d''authenticated a été perdu';
  END IF;
END $$;
