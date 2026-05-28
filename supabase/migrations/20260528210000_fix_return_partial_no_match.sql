-- ═══════════════════════════════════════════════════════════════════════════
-- BUG-retour-partiel-faux-succès (28/05/2026)
-- ───────────────────────────────────────────────────────────────────────────
-- Defense en profondeur : si aucune ligne ne matche les criteres de retour
-- (emprestimo_id + line_no parmi p_line_nos + item_status = 'aberto'), la
-- fonction retournait silencieusement 0. Les appelants ignorant la valeur de
-- retour considerait l'appel comme reussi : faux positifs cote UI, aucun mail
-- envoye, aucun message d'erreur.
--
-- Correctif : lever une exception explicite 'no_lines_returned' (errcode P0001)
-- pour que les wrappers api.* et le front gerent l'erreur clairement.
--
-- Cas d'usage detectes :
--   - sub_id saisi a la place du book_id (ex: '0000185' au lieu de '47.2')
--     → filtre cote front, ne devrait plus arriver ici apres fix front,
--       mais la fonction reste defensive.
--   - line_no inexistant pour cet emprestimo (ex: 47.99)
--   - line_no valide mais item deja rendu (ex: 47.2 sur emprunt #47
--     dont line_no=2 est deja 'devolvido')
--
-- Impact appelants :
--   - api.return_loan_partial : remontera l'exception → front gerera
--   - public.fn_v2_return_emprestimo_linhas : impact direct sur les appelants
--
-- Doctrine SECURITY DEFINER (chantier #150, 18/05/2026) :
--   REVOKE EXECUTE FROM PUBLIC, anon, authenticated, service_role
--   puis GRANT EXECUTE TO <roles legitimes>
--   cf. docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_v2_return_emprestimo_linhas(
  p_emprestimo_id bigint,
  p_line_nos integer[],
  p_notes text DEFAULT NULL::text
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_actor public.my_access%rowtype;
  v_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  select * into v_actor from public.my_access limit 1;

  if coalesce(v_actor.can_access_painel, false) is false then
    raise exception 'Acesso bibliotecário obrigatório.';
  end if;

  with updated as (
    update public.emprestimo_itens_v2 i
       set item_status = 'devolvido',
           returned_at = now(),
           return_schedule_status = 'devolucao_realizada',
           return_completed_at = now(),
           notes = coalesce(p_notes, i.notes),
           updated_at = now()
     where i.emprestimo_id = p_emprestimo_id
       and i.line_no = any(p_line_nos)
       and i.item_status = 'aberto'
     returning i.book_id
  )
  select count(*)::int into v_count from updated;

  -- BUG-retour-partiel-faux-succès (28/05/2026) : exception explicite si 0 ligne.
  -- Auparavant : return 0 silencieux → faux positif cote UI.
  if v_count = 0 then
    raise exception 'no_lines_returned'
      using errcode = 'P0001',
            hint = format('Nenhuma linha aberta encontrada para o empréstimo %s nas linhas %s.',
                          p_emprestimo_id, p_line_nos::text);
  end if;

  update public.books b
     set available_count = coalesce(b.available_count, 0) + x.qty
    from (
      select book_id, count(*)::int as qty
      from public.emprestimo_itens_v2
      where emprestimo_id = p_emprestimo_id
        and line_no = any(p_line_nos)
        and returned_at is not null
      group by book_id
    ) x
   where b.id = x.book_id;

  perform public.fn_v2_refresh_emprestimo_status_global(p_emprestimo_id);
  perform public.fn_v2_recompute_from_emprestimo_lines(p_emprestimo_id, p_line_nos);

  return v_count;
end;
$function$;

-- ── Doctrine SECURITY DEFINER : REVOKE puis GRANT explicites ────────────
-- La fonction etait deja correctement protegee en prod (pas de grant PUBLIC ni
-- anon avant cette migration). On reaffirme l'etat doctrinal explicitement
-- pour eviter toute regression future.
REVOKE EXECUTE ON FUNCTION public.fn_v2_return_emprestimo_linhas(bigint, integer[], text)
  FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.fn_v2_return_emprestimo_linhas(bigint, integer[], text)
  TO authenticated, service_role;

-- ── Verifications doctrinales ────────────────────────────────────────────
DO $$
DECLARE
  v_has_raise boolean;
  v_has_anon_grant boolean;
  v_has_authenticated_grant boolean;
BEGIN
  -- 1) Le corps de la fonction contient bien le RAISE EXCEPTION
  SELECT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'fn_v2_return_emprestimo_linhas'
      AND pg_get_functiondef(p.oid) ILIKE '%no_lines_returned%'
  ) INTO v_has_raise;

  IF NOT v_has_raise THEN
    RAISE EXCEPTION 'fix non applique : RAISE EXCEPTION no_lines_returned absent du corps';
  END IF;

  -- 2) anon ne doit PAS avoir EXECUTE
  SELECT EXISTS (
    SELECT 1 FROM information_schema.routine_privileges
    WHERE routine_schema = 'public'
      AND routine_name = 'fn_v2_return_emprestimo_linhas'
      AND grantee = 'anon'
      AND privilege_type = 'EXECUTE'
  ) INTO v_has_anon_grant;

  IF v_has_anon_grant THEN
    RAISE EXCEPTION 'doctrine violee : anon ne devrait pas avoir EXECUTE';
  END IF;

  -- 3) authenticated DOIT avoir EXECUTE (sinon le panel ne marche plus)
  SELECT EXISTS (
    SELECT 1 FROM information_schema.routine_privileges
    WHERE routine_schema = 'public'
      AND routine_name = 'fn_v2_return_emprestimo_linhas'
      AND grantee = 'authenticated'
      AND privilege_type = 'EXECUTE'
  ) INTO v_has_authenticated_grant;

  IF NOT v_has_authenticated_grant THEN
    RAISE EXCEPTION 'authenticated doit avoir EXECUTE pour que le panel fonctionne';
  END IF;

  RAISE NOTICE 'Verif OK : RAISE present, anon revoque, authenticated granted.';
END $$;
