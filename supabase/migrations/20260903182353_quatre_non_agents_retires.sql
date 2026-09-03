-- ============================================================================
-- Évidences de l'audit du 03/09 (2/4) — quatre non-agents retirés des autorités
-- Foyer : REGISTRE §37 `CONV` · AUDIT_autorites_2026-09-03 §N4
-- ============================================================================
-- DÉCISION. Xavier, 03/09 au soir : corriger ce qui est évident. Une autorité
-- est un AGENT (personne, collectivité, congrès). Quatre fiches n'en sont pas :
--   · 11366 « ?? » — du bruit, lié à une notice ;
--   · 11431 « identificado, Não » — « non identifié » inversé, passé au travers
--     du filtre de C5 et validé parmi 464, deux liens ;
--   · 11511 « Piccolo Dizionario degli Orrori » — le TITRE d'un livre ;
--   · 10512 « Dizionario, Piccolo » — le même titre, importé en juin, orphelin
--     (une œuvre le porte encore en `primary_author_id`).
-- Les périodiques (« Noir et Rouge », « Le Monde Diplomatique », « UFRGS, Revista
-- do IFCH / ») et l'éditeur (« Imprensa Marginal ») ne sont PAS retirés : un
-- groupe éditeur peut être une collectivité — c'est un jugement, il reste à la file.
--
-- LE GESTE EST CELUI DE `discard_author` (auth.uid, injoignable en migration),
-- précédé du déliage que `discard_author` exige : le contributeur garde son
-- NOM (`book_contributors.name`), il perd seulement le lien ; le trigger
-- `trg_sync_book_authors` retire la ligne dérivée ; l'œuvre perd son auteur
-- principal ; la ligne de la file est écartée avec la raison ; le journal
-- `catalog_audit_log` reçoit l'instantané, comme `discard_author` le fait.
-- Anti-écrasement : la fiche doit porter exactement le nom attendu.
--
-- SECURITY INVOKER, aucun grant. Suite : conv_evidence_non_agents_tests.sql.
-- ============================================================================
begin;

create or replace function public.fn_conv_retirer_non_agent(p_id bigint, p_sort_name text)
returns boolean
language plpgsql
security invoker
set search_path to 'public', 'pg_catalog'
as $$
declare v_a public.authors%rowtype;
begin
  select * into v_a from public.authors where id = p_id;
  if v_a.id is null or v_a.sort_name is distinct from p_sort_name then return false; end if;
  if coalesce(v_a.source_label, '') like 'formacao-%' then return false; end if;

  update public.book_contributors set author_id = null where author_id = p_id;      -- le nom reste
  delete from public.book_authors where author_id = p_id;                            -- filet (le trigger l'a fait)
  update public.book_draft_contributors set author_id = null where author_id = p_id;
  update public.audio_track_contributors set author_id = null where author_id = p_id;
  update public.author_drafts set published_author_id = null where published_author_id = p_id;
  update public.works set primary_author_id = null where primary_author_id = p_id;

  update public.catalog_review_queue q
     set decision = 'ecarte', decided_at = now(),
         note = coalesce(q.note || ' · ', '') || 'Retirée : ce n''est pas un agent (audit 03/09, §N4).'
   where q.entity_kind = 'author' and q.entity_id = p_id and q.applique_le is null;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
  values (null, 'discard', 'author', p_id, v_a.preferred_name,
          jsonb_build_object('via', 'migration évidences audit 03/09 (fn_conv_retirer_non_agent)',
                             'raison', 'non-agent', 'snapshot', to_jsonb(v_a)));

  delete from public.authors where id = p_id;
  return true;
end;
$$;

comment on function public.fn_conv_retirer_non_agent(bigint, text) is
  'Audit 03/09 · retire une fiche d''autorité qui n''est pas un agent (bruit, « non '
  'identifié », titre) : délie ses contributeurs (le nom reste), ses œuvres et brouillons, '
  'écarte ses lignes de la file, journalise l''instantané, supprime. Refuse si le nom '
  'n''est pas exactement celui attendu ou si la fiche est une fixture de formation. '
  'Migration seulement (aucun grant).';

revoke all on function public.fn_conv_retirer_non_agent(bigint, text) from public, anon, authenticated;

do $$
begin
  if has_function_privilege('anon', 'public.fn_conv_retirer_non_agent(bigint,text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.fn_conv_retirer_non_agent(bigint,text)', 'EXECUTE') then
    raise exception 'Évidences 03/09 — le retrait est exécutable depuis l''application : abandon.';
  end if;
end $$;

do $$
declare r record; v_n int := 0;
begin
  for r in select * from (values
      (11366, '??'),
      (11431, 'identificado, Não'),
      (11511, 'Piccolo Dizionario degli Orrori'),
      (10512, 'Dizionario, Piccolo')
    ) as t(id, sort_name)
  loop
    if public.fn_conv_retirer_non_agent(r.id, r.sort_name) then v_n := v_n + 1; end if;
  end loop;
  raise notice 'Évidences 03/09 — % non-agent(s) retiré(s) (4 attendus en production, 0 sur une base fraîche).', v_n;
end $$;

commit;
