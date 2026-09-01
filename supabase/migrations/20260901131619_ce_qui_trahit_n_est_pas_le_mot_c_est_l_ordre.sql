-- B14, schéma `public`, paquet 6 : ce qui trahit n'est pas le mot, c'est l'ordre.
--
-- ============================================================================
-- CE QUE LE PAQUET 2 N'AVAIT PAS PU VOIR
-- ============================================================================
-- Le paquet 2 a fermé quatorze « oracles d'existence » : des fonctions qui
-- distinguaient « la chose n'existe pas » de « la chose existe, mais pas chez
-- vous ». Il les avait trouvées **par le motif du message** — d'abord
-- « não pertence », puis « nao pertence » sans les accents.
--
-- Ce paquet en trouve neuf de plus, et aucune ne dit « pertence ». Elles disent
-- « Acesso restrito », « Você não tem permissão », « Este empréstimo pertence a
-- outra pessoa ». **Chercher un vocabulaire ne pouvait pas les atteindre.**
--
-- Le critère qui les atteint est structurel, et il est mesurable : **un test
-- d'existence placé avant le contrôle de droit**, sur un identifiant que l'on
-- peut deviner. Relevé par comparaison des positions des deux refus dans le
-- corps, sur toute la surface exposée à `authenticated` — seize fonctions dans
-- ce cas, dont neuf sur un identifiant **séquentiel**.
--
-- *Le paquet 2 cherchait un mot ; il fallait chercher un ordre.* C'est la même
-- leçon que `DOC-RECENS-1`, d'un cran plus haut : un recensement par
-- vocabulaire ne trouve que ce qui parle la même langue que lui.
--
-- ============================================================================
-- POURQUOI ON N'INVERSE PAS L'ORDRE
-- ============================================================================
-- Le remède évident — garder d'abord, lire ensuite — est **impossible** ici, et
-- c'est ce qui rend ces cas différents de ceux du paquet 2 : la garde porte sur
-- la bibliothèque **de l'objet**, qu'il faut donc avoir lu pour la connaître.
-- C'est d'ailleurs la bonne forme, celle que le paquet 5 a désignée comme
-- modèle (`fn_import_set_profile` garde sur `v_run.library_id`, pas sur une
-- bibliothèque de session).
--
-- On ne touche donc pas à l'ordre : on unifie ce que les deux refus **disent**.
-- Doctrine de `api.resolve_reader_card`, déjà appliquée au paquet 2 : la
-- banalité du motif est le contrôle. Et l'identifiant sort du message, parce
-- qu'un identifiant renvoyé dans un refus est déjà une confirmation qu'on l'a lu.
--
-- ============================================================================
-- UNE CORRECTION DU PAQUET 2, À MOITIÉ FAITE
-- ============================================================================
-- `fn_attach_received_asset_record` avait été corrigée le 01/09 au matin : ses
-- deux premiers messages ont été unifiés sur « Recurso recebido introuvável ».
-- Le **troisième** — « Acesso restrito ao coordenador da biblioteca detentora »
-- — est resté, et il rouvre exactement l'oracle que la correction fermait. La
-- substitution du paquet 2 portait sur les motifs qu'elle connaissait ; celui-là
-- n'en faisait pas partie.
--
-- *Une fonction corrigée n'est pas une fonction close.* Le contrôle qui manquait
-- n'est pas « le motif a-t-il disparu ? » mais « reste-t-il DEUX refus
-- distinguables ? » — c'est ce que garde désormais la suite de tests.
--
-- ============================================================================
-- CE QUI N'EST PAS TOUCHÉ, ET POURQUOI
-- ============================================================================
--   * les identifiants **uuid** (`fn_partnership_accept`, `update_exemplar_labels`,
--     `api.resubmit_membership`…) : deux refus distincts y sont sans portée, un
--     uuid ne se devine pas. Les corriger serait du bruit ;
--   * `fn_v2_mark_emprestimo_return_missed` : ses refus sont des refus de RÔLE,
--     pas des tests d'existence — rien à unifier ;
--   * le message de rôle de `discard_exemplar` (« Apenas bibliotecárias e
--     coordenadoras… ») : il tombe **avant** toute lecture, il ne dit donc rien
--     sur l'existence de l'exemplaire.

DO $$
DECLARE
  r record;
  v_def text;
  v_new text;
  n int := 0;
  v_rate text := '';
BEGIN
  FOR r IN
    SELECT p.oid, p.proname
      FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'public'
       AND p.proname IN ('fn_confirm_digital_asset_rights',
                         'fn_publish_digital_asset_from_resource',
                         'fn_attach_received_asset_record',
                         'fn_import_set_adapter_overrides',
                         'fn_import_set_profile',
                         'fn_set_circulation_limits',
                         'discard_exemplar',
                         'fn_v2_schedule_emprestimo_return',
                         'fn_v2_clear_emprestimo_return_schedule')
  LOOP
    v_def := pg_get_functiondef(r.oid);
    v_new := v_def;

    -- Substitution CIBLÉE par fonction : un remplacement global unifierait
    -- `fn_publish_digital_asset_from_resource` vers « Asset introuvável » alors
    -- que son message d'absence dit « Recurso digital ». Deux fonctions
    -- voisines peuvent partager un refus sans partager leur objet.
    CASE r.proname
      WHEN 'fn_confirm_digital_asset_rights' THEN
        v_new := replace(v_new, '''Asset % introuvável.'', p_asset_id', '''Asset introuvável.''');
        v_new := replace(v_new, '''Acesso restrito ao coordenador da biblioteca detentora.''', '''Asset introuvável.''');

      WHEN 'fn_publish_digital_asset_from_resource' THEN
        v_new := replace(v_new, '''Recurso digital % introuvável.'', p_resource_id', '''Recurso digital introuvável.''');
        v_new := replace(v_new, '''Acesso restrito ao coordenador da biblioteca detentora.''', '''Recurso digital introuvável.''');

      WHEN 'fn_attach_received_asset_record' THEN
        v_new := replace(v_new, '''Acesso restrito ao coordenador da biblioteca detentora.''', '''Recurso recebido introuvável.''');

      WHEN 'fn_import_set_adapter_overrides' THEN
        v_new := replace(v_new, '''Run % introuvável.'', p_run_id', '''Run introuvável.''');
        v_new := replace(v_new, '''Acesso restrito ao coordenador da biblioteca.''', '''Run introuvável.''');

      WHEN 'fn_import_set_profile' THEN
        v_new := replace(v_new, '''Run % introuvável.'', p_run_id', '''Run introuvável.''');
        v_new := replace(v_new, '''Acesso restrito ao coordenador da biblioteca.''', '''Run introuvável.''');

      WHEN 'fn_set_circulation_limits' THEN
        v_new := replace(v_new, '''Acesso restrito ao staff da biblioteca.''', '''Jeu de règles introuvable.''');

      WHEN 'discard_exemplar' THEN
        v_new := replace(v_new, '''Exemplar não encontrado (ID %).'', p_exemplar_id', '''Exemplar não encontrado.''');
        v_new := replace(v_new, '''Você não tem permissão para descartar exemplares desta biblioteca.''', '''Exemplar não encontrado.''');

      ELSE  -- les deux fn_v2_* : contrat de STATUT, pas d'exception
        v_new := replace(v_new, '''Este empréstimo pertence a outra pessoa.''', '''Empréstimo não encontrado.''');
    END CASE;

    IF v_new = v_def THEN
      v_rate := v_rate || r.proname || ' ';
    ELSE
      EXECUTE v_new;
      n := n + 1;
    END IF;
  END LOOP;

  IF v_rate <> '' THEN
    RAISE EXCEPTION 'aucun motif substitué sur : % — ces fonctions ont changé de forme, migration interrompue plutôt que sans effet', v_rate;
  END IF;

  RAISE NOTICE 'refus unifiés sur % fonction(s)', n;
END $$;

COMMENT ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text, text) IS
  'Attache un fichier reçu d''un partenaire à une notice. Rend le MÊME message dans les trois cas de refus — ressource absente, ressource d''une autre bibliothèque, appelant·e non coordinateur·rice — et sans rappeler l''identifiant. Unifié en DEUX temps : les deux premiers le 01/09 au matin (paquet 2), le troisième l''après-midi (paquet 6), qui rouvrait l''oracle à lui seul. Une fonction corrigée n''est pas une fonction close.';

COMMENT ON FUNCTION public.fn_set_circulation_limits(bigint, integer, integer, integer) IS
  'Plafonds de circulation d''un jeu de règles. Rend « Jeu de règles introuvable » aussi bien quand le jeu n''existe pas que quand il appartient à une autre bibliothèque — unifié le 01/09/2026 (B14, paquet 6) : l''identifiant est un bigint séquentiel, deux messages distincts laissaient énumérer les jeux de règles du réseau.';

-- ============================================================================
-- GARDE DE FIN
-- ============================================================================
DO $$
DECLARE v_reste text;
BEGIN
  -- L'invariant n'est pas « le motif a disparu » — c'est celui-là qui a laissé
  -- passer le troisième message de fn_attach_received_asset_record. C'est :
  -- plus aucune de ces fonctions ne porte DEUX refus distinguables.
  SELECT string_agg(p.proname, ', ')
    INTO v_reste
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('fn_confirm_digital_asset_rights','fn_publish_digital_asset_from_resource',
                       'fn_attach_received_asset_record','fn_import_set_adapter_overrides',
                       'fn_import_set_profile','fn_set_circulation_limits','discard_exemplar',
                       'fn_v2_schedule_emprestimo_return','fn_v2_clear_emprestimo_return_schedule')
     AND (p.prosrc ~ 'Acesso restrito ao coordenador da biblioteca'
          OR p.prosrc ~ 'Acesso restrito ao staff da biblioteca'
          OR p.prosrc ~ 'não tem permissão para descartar exemplares'
          OR p.prosrc ~ 'pertence a outra pessoa');

  IF v_reste IS NOT NULL THEN
    RAISE EXCEPTION 'refus encore distinguable sur : % — rollback', v_reste;
  END IF;

  -- Et les fonctions restent appelables : le refus vit dans le corps, pas dans
  -- le droit (DOC-RPC-3). Fermer l'EXECUTE casserait l'écran au lieu de refuser.
  IF NOT has_function_privilege('authenticated', 'public.discard_exemplar(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'EXECUTE perdu sur discard_exemplar — rollback';
  END IF;
END $$;
