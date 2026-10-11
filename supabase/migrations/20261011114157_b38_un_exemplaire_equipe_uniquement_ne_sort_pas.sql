-- =====================================================================
-- AnarBib — B38 (11/10/2026) : un exemplaire « équipe uniquement » ne sort pas
-- de la bibliothèque par un chemin détourné.
--
-- Constat (état des lieux du lot 7 de H21, 09/10) : quatre fonctions de
-- circulation comptaient, choisissaient ou prêtaient un exemplaire sans lire
-- sa visibilité ni sa politique de circulation, alors que le prêt direct
-- (fn_v2_create_emprestimo_by_holdings), la consultation et la recherche PEB
-- (fn_peb_search_exemplares) exigent visibility = 'public' et
-- circulation_policy in ('emprestavel', 'ambos') (matrice P1.4b §6.2) :
--   · fn_v2_create_reserva_by_holdings : le compte des exemplaires du fonds
--     (exemplares_total) prenait un « équipe uniquement » ou un « consultation
--     seule » — une réservation naissait sur un fonds qui n'a rien à prêter ;
--   · fn_v2_convert_reserva_linhas_to_emprestimo : les quatre choix d'un
--     exemplaire libre (par exemplaire, par fonds, par pont, par cote)
--     prenaient le premier libre, fût-il d'archive ;
--   · fn_v2_add_emprestimo_interbibliotecas_itens : ne vérifiait que
--     `loanable` du fonds ;
--   · fn_peb_create_loan_with_items : ne vérifiait que l'engagement.
-- En production le 11/10 : 2 762 exemplaires, tous « public » ; 16 en
-- « consulta ». Le trou n'a pas servi ; il est fermé avant qu'il ne serve.
--
-- Ce que fait cette migration : sur la DÉFINITION VIVANTE de chaque fonction
-- (pg_get_functiondef, retours chariot retirés), par ancres comptées, elle
-- ajoute le même filtre que le prêt direct — aux comptes et aux choix
-- (réservation, conversion : l'exemplaire est évité), et un refus explicite
-- aux deux fonctions où l'exemplaire est désigné par son identifiant (PEB :
-- HINT `error.circulation.item_staff_only` / `error.circulation.item_consult_only`,
-- traduits dans les dix locales). Aucune signature ne change ; aucune
-- fonction nouvelle ; aucune porte nouvelle à l'audit.
-- md5 de prosrc lus le 11/10/2026 en production (MCP, lecture seule) :
--   public.fn_v2_create_reserva_by_holdings             0faa7fd390de0f87b85f02eb6e0e1be6
--   public.fn_v2_convert_reserva_linhas_to_emprestimo   9aaa664b639ddddd8c9adc48c54c4c0a
--   public.fn_v2_add_emprestimo_interbibliotecas_itens  d583ca1200ff27a5c98eb6f8039ec305
--   public.fn_peb_create_loan_with_items                6ecf7a797399aedb40bd60fafeb599f6
-- Suite : tests/sql/b38_equipe_uniquement_ne_sort_pas_tests.sql (mutant
-- éprouvé : sans les lignes « -- B38 », huit tests sur neuf rougissent).
-- =====================================================================

CREATE OR REPLACE FUNCTION pg_temp.b38_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'B38 — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN
    RAISE EXCEPTION 'B38 — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

CREATE OR REPLACE FUNCTION pg_temp.b38_def(p_fn regprocedure)
RETURNS text LANGUAGE sql AS $f$
  SELECT replace(pg_get_functiondef(p_fn), E'\r', '');
$f$;

DO $b38$
DECLARE
  v_def text;
  v_md5 text;
BEGIN
  -- Les définitions attendues : si l'une a bougé depuis la lecture, on s'arrête
  -- (les ancres comptées protègent aussi, mais autant le dire tôt et clairement).
  FOR v_def, v_md5 IN VALUES
    ('public.fn_v2_create_reserva_by_holdings(uuid, bigint[], timestamp with time zone, text)', '0faa7fd390de0f87b85f02eb6e0e1be6'),
    ('public.fn_v2_convert_reserva_linhas_to_emprestimo(bigint, integer[], date, text)', '9aaa664b639ddddd8c9adc48c54c4c0a'),
    ('public.fn_v2_add_emprestimo_interbibliotecas_itens(bigint, bigint[], date, text)', 'd583ca1200ff27a5c98eb6f8039ec305'),
    ('public.fn_peb_create_loan_with_items(jsonb, jsonb)', '6ecf7a797399aedb40bd60fafeb599f6')
  LOOP
    IF (SELECT md5(replace(p.prosrc, E'\r', '')) FROM pg_proc p WHERE p.oid = v_def::regprocedure) <> v_md5
       AND (SELECT md5(p.prosrc) FROM pg_proc p WHERE p.oid = v_def::regprocedure) <> v_md5 THEN
      RAISE EXCEPTION 'B38 — % : la définition a changé depuis le 11/10/2026 (md5 attendu %) — relire la définition réelle', v_def, v_md5;
    END IF;
  END LOOP;

  -- 1. La réservation ne compte que ce qui peut se prêter.
  v_def := pg_temp.b38_def('public.fn_v2_create_reserva_by_holdings(uuid, bigint[], timestamp with time zone, text)'::regprocedure);
  v_def := pg_temp.b38_remplacer('fn_v2_create_reserva_by_holdings', v_def,
$a$        where e.holding_id = h.id
          and e.retire_at is null   -- H21 lot 7 : un retiré ne se réserve pas
      ) as exemplares_total,$a$,
$b$        where e.holding_id = h.id
          and e.retire_at is null   -- H21 lot 7 : un retiré ne se réserve pas
          and e.visibility = 'public'                            -- B38 : un « équipe uniquement » ne se réserve pas
          and e.circulation_policy in ('emprestavel', 'ambos')   -- B38 : ni un « consultation seule »
      ) as exemplares_total,$b$);
  EXECUTE v_def;

  -- 2. La conversion d'une réservation ne choisit qu'un exemplaire qui peut se prêter (quatre choix).
  v_def := pg_temp.b38_def('public.fn_v2_convert_reserva_linhas_to_emprestimo(bigint, integer[], date, text)'::regprocedure);
  v_def := pg_temp.b38_remplacer('fn_v2_convert_reserva_linhas_to_emprestimo', v_def,
$a$        and e.retire_at is null   -- H21 lot 7
$a$,
$b$        and e.retire_at is null   -- H21 lot 7
        and e.visibility = 'public'                            -- B38 : un « équipe uniquement » ne se prête pas
        and e.circulation_policy in ('emprestavel', 'ambos')   -- B38 : ni un « consultation seule »
$b$, 4);
  EXECUTE v_def;

  -- 3. Le PEB (ajout d'exemplaires désignés) refuse, en le disant.
  v_def := pg_temp.b38_def('public.fn_v2_add_emprestimo_interbibliotecas_itens(bigint, bigint[], date, text)'::regprocedure);
  v_def := pg_temp.b38_remplacer('fn_v2_add_emprestimo_interbibliotecas_itens', v_def,
$a$    -- H21 lot 7 (09/10/2026) : un retiré ne part pas en PEB
    if exists (select 1 from public.exemplares x where x.id = v_item_id and x.retire_at is not null) then$a$,
$b$    -- B38 (début) (11/10/2026) : un « équipe uniquement » ou un « consultation seule » ne part pas en PEB
    if exists (select 1 from public.exemplares x where x.id = v_item_id and x.visibility is distinct from 'public') then
      raise exception 'O exemplar % é reservado à equipe (arquivo): não sai em empréstimo interbibliotecas.', v_item_id
        using errcode = 'P0001', hint = 'error.circulation.item_staff_only';
    end if;
    if exists (select 1 from public.exemplares x where x.id = v_item_id and coalesce(x.circulation_policy, '') not in ('emprestavel', 'ambos')) then
      raise exception 'O exemplar % é só de consulta local: não sai em empréstimo interbibliotecas.', v_item_id
        using errcode = 'P0001', hint = 'error.circulation.item_consult_only';
    end if;
    -- B38 (fin)
    -- H21 lot 7 (09/10/2026) : un retiré ne part pas en PEB
    if exists (select 1 from public.exemplares x where x.id = v_item_id and x.retire_at is not null) then$b$);
  EXECUTE v_def;

  -- 4. Le PEB (création avec exemplaires) refuse, en le disant.
  v_def := pg_temp.b38_def('public.fn_peb_create_loan_with_items(jsonb, jsonb)'::regprocedure);
  v_def := pg_temp.b38_remplacer('fn_peb_create_loan_with_items', v_def,
$a$      -- H21 lot 7 (09/10/2026) : un retiré ne part pas en PEB
      IF EXISTS (SELECT 1 FROM public.exemplares x WHERE x.id = v_item_id AND x.retire_at IS NOT NULL) THEN$a$,
$b$      -- B38 (début) (11/10/2026) : un « équipe uniquement » ou un « consultation seule » ne part pas en PEB
      IF EXISTS (SELECT 1 FROM public.exemplares x WHERE x.id = v_item_id AND x.visibility IS DISTINCT FROM 'public') THEN
        RAISE EXCEPTION 'fn_peb_create_loan_with_items: exemplaire id=% réservé à l''équipe (archive)', v_item_id
          USING ERRCODE = 'P0001', HINT = 'error.circulation.item_staff_only';
      END IF;
      IF EXISTS (SELECT 1 FROM public.exemplares x WHERE x.id = v_item_id AND coalesce(x.circulation_policy, '') NOT IN ('emprestavel', 'ambos')) THEN
        RAISE EXCEPTION 'fn_peb_create_loan_with_items: exemplaire id=% en consultation sur place seulement', v_item_id
          USING ERRCODE = 'P0001', HINT = 'error.circulation.item_consult_only';
      END IF;
      -- B38 (fin)
      -- H21 lot 7 (09/10/2026) : un retiré ne part pas en PEB
      IF EXISTS (SELECT 1 FROM public.exemplares x WHERE x.id = v_item_id AND x.retire_at IS NOT NULL) THEN$b$);
  EXECUTE v_def;
END
$b38$;

-- Vérification : les quatre filtres sont en place, les signatures et les droits n'ont pas bougé.
DO $b38_verif$
DECLARE v_e text := '';
BEGIN
  IF (SELECT count(*) FROM regexp_matches(pg_get_functiondef('public.fn_v2_create_reserva_by_holdings(uuid, bigint[], timestamp with time zone, text)'::regprocedure), 'e\.visibility = ''public''', 'g')) <> 1
     OR (SELECT count(*) FROM regexp_matches(pg_get_functiondef('public.fn_v2_convert_reserva_linhas_to_emprestimo(bigint, integer[], date, text)'::regprocedure), 'e\.visibility = ''public''', 'g')) <> 4
     OR (SELECT count(*) FROM regexp_matches(pg_get_functiondef('public.fn_v2_convert_reserva_linhas_to_emprestimo(bigint, integer[], date, text)'::regprocedure), 'e\.circulation_policy in \(''emprestavel'', ''ambos''\)', 'g')) <> 4
     OR position('error.circulation.item_staff_only' IN pg_get_functiondef('public.fn_v2_add_emprestimo_interbibliotecas_itens(bigint, bigint[], date, text)'::regprocedure)) = 0
     OR position('error.circulation.item_consult_only' IN pg_get_functiondef('public.fn_v2_add_emprestimo_interbibliotecas_itens(bigint, bigint[], date, text)'::regprocedure)) = 0
     OR position('error.circulation.item_staff_only' IN pg_get_functiondef('public.fn_peb_create_loan_with_items(jsonb, jsonb)'::regprocedure)) = 0
     OR position('error.circulation.item_consult_only' IN pg_get_functiondef('public.fn_peb_create_loan_with_items(jsonb, jsonb)'::regprocedure)) = 0 THEN
    v_e := v_e || ' filtres';
  END IF;
  -- Le retrait (H21 lot 7) est toujours lu, juste après.
  IF position('retire_at' IN pg_get_functiondef('public.fn_v2_create_reserva_by_holdings(uuid, bigint[], timestamp with time zone, text)'::regprocedure)) = 0
     OR position('retire_at' IN pg_get_functiondef('public.fn_v2_add_emprestimo_interbibliotecas_itens(bigint, bigint[], date, text)'::regprocedure)) = 0
     OR position('retire_at' IN pg_get_functiondef('public.fn_peb_create_loan_with_items(jsonb, jsonb)'::regprocedure)) = 0 THEN
    v_e := v_e || ' retrait';
  END IF;
  -- Les trois DEFINER le restent, search_path figé ; le PEB invoker le reste.
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.prosecdef
         AND p.proname IN ('fn_v2_create_reserva_by_holdings', 'fn_v2_convert_reserva_linhas_to_emprestimo', 'fn_v2_add_emprestimo_interbibliotecas_itens')
         AND EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%')) <> 3
     OR (SELECT p.prosecdef FROM pg_proc p WHERE p.oid = 'public.fn_peb_create_loan_with_items(jsonb, jsonb)'::regprocedure) THEN
    v_e := v_e || ' droits';
  END IF;
  IF v_e <> '' THEN
    RAISE EXCEPTION 'B38 — vérification en échec :%', v_e;
  END IF;
END
$b38_verif$;
