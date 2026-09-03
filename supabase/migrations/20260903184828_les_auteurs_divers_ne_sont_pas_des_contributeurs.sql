-- ============================================================================
-- CONV-8 — « AA. VV. », « Anônimo », « Coletivo » ne sont pas des contributeurs :
-- l'entrée se fait au titre, la transcription reste
-- Foyer : REGISTRE §37 `CONV` · CONV-8 (acté 03/09, soir) · AUDIT_autorites_2026-09-03 §N4, §N8
-- ============================================================================
-- LE MODÈLE INTERNATIONAL (ISBD, AACR2, RDA, MARC) ne connaît ni vedette
-- « auteurs divers » ni vedette « anonyme ». Quand la responsabilité est
-- inconnue ou diffuse, l'entrée principale se fait AU TITRE ; la mention de
-- responsabilité se transcrit telle qu'imprimée ; chaque personne ou
-- collectivité RÉELLE devient un contributeur avec son rôle. « AA. VV. »
-- (Autori vari), « VV. AA. », « Vários autores », « Collectif », « Anônimo »,
-- « identificado, Não », « ?? » sont des usages d'éditeurs et de libraires,
-- pas des agents — ils n'ont rien à faire dans `book_contributors`.
--
-- Chez nous, seize lignes de contributeurs portent l'un de ces mots, sans
-- autorité (elles ont été semées par l'import depuis `books.autor`). Elles
-- sont RETIRÉES. La transcription (`books.autor`) ne bouge pas : elle est la
-- mention de responsabilité ; l'OPAC l'affiche désormais entre crochets, dans
-- la langue du lecteur (« [autores vários] », « [anonyme] »), quand aucune
-- autorité n'est liée — c'est la partie frontend de CONV-8, même commit-série.
--
-- Deux lignes qui ressemblent à ces mots sont LAISSÉES, parce qu'elles nomment
-- peut-être une collectivité réelle : « Leueroth, Pelo Coletivo Edgar »
-- (le Coletivo Edgar Leuenroth ?) et « Coletivo de Ex-Trabalhadores ». C'est un
-- jugement, pas une évidence. Une ligne de plus est retirée : « Piccolo
-- Dizionario degli Orrori » sur la notice 1707, qui est un TITRE (le même que
-- l'autorité retirée par la migration des non-agents), pas un agent.
--
-- Le retrait est une fonction à liste fermée, gardée par le nom exact et par
-- l'absence d'autorité ; le trigger `trg_sync_book_authors` n'a rien à retirer
-- (aucune autorité), `books.autor` est intact. Si la ligne retirée était la
-- seule « primaire » du livre et qu'il en reste d'autres, la première
-- restante devient primaire. Suite : conv_8_auteurs_divers_tests.sql.
-- ============================================================================
begin;

create or replace function public.fn_conv_retirer_contributeur_non_agent(p_id bigint, p_name text)
returns boolean
language plpgsql
security invoker
set search_path to 'public', 'pg_catalog'
as $$
declare c public.book_contributors%rowtype;
begin
  select * into c from public.book_contributors where id = p_id;
  if c.id is null or c.name is distinct from p_name or c.author_id is not null then return false; end if;

  delete from public.book_contributors where id = p_id;

  -- une autre ligne du livre devient primaire s'il n'en reste aucune
  if c.is_primary and exists (select 1 from public.book_contributors x where x.book_id = c.book_id)
     and not exists (select 1 from public.book_contributors x where x.book_id = c.book_id and x.is_primary) then
    update public.book_contributors x set is_primary = true
     where x.id = (select id from public.book_contributors y where y.book_id = c.book_id order by y.position limit 1);
  end if;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
  values (null, 'discard', 'book', c.book_id, c.name,
          jsonb_build_object('via', 'migration CONV-8 (fn_conv_retirer_contributeur_non_agent)',
                             'raison', 'contributeur qui n''est pas un agent (auteurs divers, anonyme, titre)',
                             'contributeur', to_jsonb(c)));
  return true;
end;
$$;

comment on function public.fn_conv_retirer_contributeur_non_agent(bigint, text) is
  'CONV-8 · retire une ligne de book_contributors qui n''est pas un agent (« AA. VV. », '
  '« Anônimo », « Coletivo », un titre) : nom exact exigé, aucune autorité liée, books.autor '
  'intact (la transcription reste), journal écrit, primaire réattribuée. Migration seulement.';

revoke all on function public.fn_conv_retirer_contributeur_non_agent(bigint, text) from public, anon, authenticated;

do $$
begin
  if has_function_privilege('anon', 'public.fn_conv_retirer_contributeur_non_agent(bigint,text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.fn_conv_retirer_contributeur_non_agent(bigint,text)', 'EXECUTE') then
    raise exception 'CONV-8 — le retrait est exécutable depuis l''application : abandon.';
  end if;
end $$;

-- La liste fermée, relevée en production le 03/09 au soir. 0 sur une base fraîche.
do $$
declare r record; v_n int := 0;
begin
  for r in select * from (values
      (5573, '??'),
      (4015, 'AA. VV'), (4690, 'AA. VV'),
      (5460, 'AA. VV.'), (5459, 'AA. VV.'),
      (2957, 'Anônimo'), (4040, 'Anônimo'), (4521, 'Anônimo'),
      (5066, 'Coletivo'), (5074, 'Coletivo'),
      (4752, 'Collectif'),
      (2977, 'identificado, Não'), (3317, 'identificado, Não'),
      (5067, 'Vários Autores'), (5069, 'Vários Autores'),
      (5725, 'Piccolo Dizionario degli Orrori')
    ) as t(id, name)
  loop
    if public.fn_conv_retirer_contributeur_non_agent(r.id, r.name) then v_n := v_n + 1; end if;
  end loop;
  raise notice 'CONV-8 — % ligne(s) de contributeur retirée(s) (16 attendues en production).', v_n;
end $$;

commit;
