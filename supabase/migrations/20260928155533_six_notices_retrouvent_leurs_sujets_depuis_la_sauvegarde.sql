-- ============================================================================
-- Six notices retrouvent les sujets que la sauvegarde #BG2 leur connaît.
--
-- Suite de 20260928133838 (« Éditer → Publier » effaçait les sujets) : treize
-- notices restaient sans sujet sans qu'aucune migration ne dise ce qu'elles
-- avaient — le rétro-remplissage du 8 juin est hors dépôt. Lecture des
-- instantanés du flux long (restic, `anarbib-long.sql`, bloc COPY de
-- book_subjects) du 30/06, 26/07, 26/08, 30/08, 20/09 et 27/09/2026, chacun
-- pris juste avant la première publication sans sujet de la notice :
--
--   · BTL-TL-000029 (34)        feminismo (5)             — perdu le 28/09 12:40 UTC
--   · BTL-TL-000447 (425)       revolucao-espanhola (26)  — perdu le 28/09 12:56
--   · BTL-TL-000448 (426)       revolucao-espanhola (26)  — perdu le 28/09 13:25
--   · BTL-TL-000449 (427)       revolucao-espanhola (26)  — perdu le 28/09 13:22
--   · BTL-TL-001992 (1867)      anarquismo (1)            — perdu le 27/09 15:52
--   · BTL-TL-002335 (2190)      anarquismo (1)            — perdu le 27/09 15:30
--   tous posés le 08/06/2026 12:14 UTC, identiques d'un instantané à l'autre.
--
-- Les sept autres (BTL-TL-000252, 000260, 000357, 001242, 001635 ; BLMF
-- 0000261, 0000264) n'ont de sujet dans aucun instantané : rien à restaurer.
--
-- Garde par ligne : notice retrouvée par id ET référence, encore sans sujet
-- (réindexée entre-temps → sautée), matière active. Rejouée, ne fait rien.
-- ============================================================================
begin;

do $$
declare
  r record; v_sid bigint; v_notices int := 0;
begin
  for r in
    select * from (values
      (34,   'BTL-TL-000029', 'feminismo'),
      (425,  'BTL-TL-000447', 'revolucao-espanhola'),
      (426,  'BTL-TL-000448', 'revolucao-espanhola'),
      (427,  'BTL-TL-000449', 'revolucao-espanhola'),
      (1867, 'BTL-TL-001992', 'anarquismo'),
      (2190, 'BTL-TL-002335', 'anarquismo')
    ) v(id, bib_ref, slug)
  loop
    if not exists (select 1 from public.books b where b.id = r.id and b.bib_ref = r.bib_ref) then
      raise notice 'Notice % (%) absente ou renumérotée : sautée', r.bib_ref, r.id;
      continue;
    end if;
    if exists (select 1 from public.book_subjects s where s.book_id = r.id) then
      continue;   -- réindexée entre-temps (ou passage précédent)
    end if;
    select id into v_sid from public.subjects where slug = r.slug and status = 'ativo';
    if v_sid is null then
      raise exception 'Sujets : matière % absente ou inactive', r.slug;
    end if;
    insert into public.book_subjects (book_id, subject_id, ord) values (r.id, v_sid, 1)
    on conflict do nothing;
    v_notices := v_notices + 1;
  end loop;
  raise notice 'Notices réindexées depuis la sauvegarde : %', v_notices;
end $$;

commit;
