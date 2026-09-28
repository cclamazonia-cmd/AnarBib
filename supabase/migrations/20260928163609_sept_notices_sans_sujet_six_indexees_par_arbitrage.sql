-- ============================================================================
-- Six notices indexées par arbitrage de Xavier (28/09/2026) — la septième reste
-- sans matière, faute d'une qui convienne.
--
-- Après 20260928133838 et 20260928155533, sept notices restaient sans sujet
-- sans qu'aucun instantané de la sauvegarde #BG2 (30/06 → 27/09) ne leur en
-- connaisse : elles n'en avaient jamais eu. Propositions dans le vocabulaire
-- existant (THES-4 : jamais créer de matière), validées par Xavier :
--
--   · BTL-TL-000252  10 Centavos (W. Alves Ferraz, éd. L@ Poema, 1974)   → ficcao (poésie)
--   · BTL-TL-000260  A Paizagem no Conto, na Novella e no Romance (F. Luz, 1922) → ficcao (essai littéraire)
--   · BTL-TL-000357  A Democracia como Valor universal (C. N. Coutinho, 1984) → marxismo, socialismo
--   · BTL-TL-001635  O Dia em que o Mundo Mudou (R. Creagh, 2001)        → anarquismo
--   · BLMF 0000261 et 0000264  Encontros com a Civilização Brasileira (revue, 1978-1979) → ditadura
--   · BTL-TL-001242  Escolas de ontem e de hoje (A. de Almeida Prado, 1961) : AUCUNE —
--     « educacao-libertaria » serait faux (souvenirs d'école, pas pédagogie libertaire).
--
-- Garde par ligne : notice retrouvée par id ET référence, encore sans sujet
-- (indexée entre-temps → sautée), matière active. Le compte de `subjects` ne
-- bouge pas. Rejouée, ne fait rien.
-- ============================================================================
begin;

do $$
declare
  r record; v_sid bigint; v_slug text; v_ord int; v_notices int := 0;
  v_subjects_avant int := (select count(*) from public.subjects);
begin
  for r in
    select * from (values
      (246,  'BTL-TL-000252', array['ficcao']),
      (254,  'BTL-TL-000260', array['ficcao']),
      (337,  'BTL-TL-000357', array['marxismo', 'socialismo']),
      (1535, 'BTL-TL-001635', array['anarquismo']),
      (2449, '0000261',       array['ditadura']),
      (2451, '0000264',       array['ditadura'])
    ) v(id, bib_ref, slugs)
  loop
    if not exists (select 1 from public.books b where b.id = r.id and b.bib_ref = r.bib_ref) then
      raise notice 'Notice % (%) absente ou renumérotée : sautée', r.bib_ref, r.id;
      continue;
    end if;
    if exists (select 1 from public.book_subjects s where s.book_id = r.id) then
      continue;   -- indexée entre-temps (ou passage précédent)
    end if;
    v_ord := 0;
    foreach v_slug in array r.slugs loop
      select id into v_sid from public.subjects where slug = v_slug and status = 'ativo';
      if v_sid is null then
        raise exception 'Sujets : matière % absente ou inactive', v_slug;
      end if;
      v_ord := v_ord + 1;
      insert into public.book_subjects (book_id, subject_id, ord) values (r.id, v_sid, v_ord)
      on conflict do nothing;
    end loop;
    v_notices := v_notices + 1;
  end loop;
  if (select count(*) from public.subjects) <> v_subjects_avant then
    raise exception 'Sujets : le nombre de matières a changé (THES-4)';
  end if;
  raise notice 'Notices indexées par arbitrage : %', v_notices;
end $$;

commit;
