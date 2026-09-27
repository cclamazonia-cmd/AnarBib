-- ============================================================================
-- C6 — les propositions en attente du lot « titre_casse » sont refaites
-- selon la casse de la langue (spec conventions §4.1)
--
-- Décision de Xavier du 27/09, sur la fiche
-- docs/journal/arbitrages/C6_propositions_casse_file_titres_2026-09-27.md
-- (173 lignes en file, 171 dont la notice porte toujours le titre semé).
--
-- Ne change QUE la proposition (`apres_propose`) et la note : aucune notice
-- n'est touchée, chaque ligne reste à valider, corriger ou écarter dans
-- l'Atelier. Lignes visées : lot titre_casse, décision « à revoir », titre de
-- la notice inchangé depuis le semis (les lignes « périmées » restent telles
-- quelles, l'Atelier les signale déjà). La proposition est calculée par
-- public.fn_conv_casse_titre (migration 20260927154351), avec la langue
-- ACTUELLE de la notice. Idempotente : rejouée, elle réécrit la même valeur.
-- ============================================================================
begin;

do $$
declare
  v_n int;
  v_ecarts int;
begin
  update public.catalog_review_queue q
     set apres_propose = public.fn_conv_casse_titre(b.titulo, b.idioma),
         note = regexp_replace(coalesce(q.note, ''), ' Proposition refaite le 27/09.*$', '')
                || ' Proposition refaite le 27/09 : casse de la langue (§4.1), noms propres attestés gardés.'
    from public.books b
   where q.lot = 'titre_casse'
     and q.decision = 'a_revoir'
     and q.entity_kind = 'book'
     and b.id = q.entity_id
     and b.titulo = q.avant
     and b.idioma is not null;
  get diagnostics v_n = row_count;

  select count(*) into v_ecarts
    from public.catalog_review_queue q
    join public.books b on b.id = q.entity_id
   where q.lot = 'titre_casse' and q.decision = 'a_revoir' and b.titulo = q.avant and b.idioma is not null
     and q.apres_propose is distinct from public.fn_conv_casse_titre(b.titulo, b.idioma);
  if v_ecarts > 0 then
    raise exception 'C6 : % proposition(s) ne suivent pas fn_conv_casse_titre', v_ecarts;
  end if;
  raise notice 'C6 : % proposition(s) refaite(s) dans la file titre_casse', v_n;
end $$;

commit;
