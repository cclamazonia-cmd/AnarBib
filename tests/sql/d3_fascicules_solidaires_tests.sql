-- =====================================================================
-- AnarBib — Tests d'acceptation : les fascicules du lot SOLIDAIRES
-- rattachés à leurs revues (D3, 19/10/2026)
-- Ref     : migration 20261019131842_d3_les_fascicules_solidaires_rattaches_a_leurs_revues
--
-- La migration vise le lot 63 de la production. Ici, un lot 63 miniature est
-- fabriqué dans la transaction, la migration est jouée DEUX fois (\ir), puis
-- tout est annulé.
-- T1 les 3 titres naissent « proposto », une fois chacun, avec leur note de
--    portée (Revue internationale : le risque d'homonymie est dit).
-- T2 un brouillon dont la source nomme une revue devient un fascicule : type,
--    titre de revue, forme transcrite, numéro (la casse et les espaces de la
--    source ne gênent pas) ; sans numéro dans la source, numero reste vide.
-- T3 rien n'est fusionné : les deux lignes d'un même numéro sont rattachées
--    toutes les deux, titre de la notice et charge brute intacts, aucun
--    brouillon écarté.
-- T4 anti-écrasement : un brouillon déjà retouché (numéro saisi), un
--    brouillon d'un autre lot et un livre sans revue ne bougent pas.
-- T5 updated_at préservé ; une seule ligne datée dans les notes du lot.
-- T6 idempotence : le second passage ne crée ni titre ni ligne de note.
-- =====================================================================
BEGIN;

DO $$
DECLARE v_autre bigint;
  raw_ jsonb;
BEGIN
  IF EXISTS (SELECT 1 FROM public.catalog_batches WHERE id = 63) THEN
    RAISE EXCEPTION 'D3-FASCICULES ECHEC : 0/1 — un lot 63 existe déjà sur ce banc, la fixture ne peut pas le fabriquer';
  END IF;
  INSERT INTO public.catalog_batches (id, name, status, notes) VALUES (63, 'D3 lot miniature', 'open', 'Lote criado a partir do import.');
  INSERT INTO public.catalog_batches (name, status) VALUES ('D3 autre lot', 'open') RETURNING id INTO v_autre;

  -- titulo, lot, tipo, numero du brouillon, periodico, numero source, duplo
  INSERT INTO public.book_drafts (titulo, batch_id, status, tipo_material, numero, updated_at, marc_json)
  SELECT t, b, 'draft', tm, nb, timestamptz '2026-09-15 12:00+00',
         jsonb_build_object('ingest', jsonb_build_object('raw_payload',
           jsonb_strip_nulls(jsonb_build_object('periodico', p, 'numero', ns, 'duplo_numero', du, 'titulo', t))))
    FROM (VALUES
      ('D3 Les utopiques n°5 - premier',  63, 'livro', NULL, 'Les utopiques', '5', 'meme numero aussi en ligne 2 — a trancher par la source'),
      ('D3 Les utopiques n°5 - second',   63, 'livro', NULL, 'Les utopiques', '5', 'meme numero aussi en ligne 1 — a trancher par la source'),
      ('D3 Les utopiques sans numero',    63, 'livro', NULL, 'Les utopiques', '',  NULL),
      ('D3 Cahiers n°6',                  63, 'livro', NULL, '  cahiers de la formation SYNDICALE ', '6', NULL),
      ('D3 Revue internationale n°9',     63, 'livro', NULL, 'Revue internationale', ' 9 ', NULL),
      ('D3 Deja retouche',                63, 'livro', '7',  'Les utopiques', '7', NULL),
      ('D3 Livre sans revue',             63, 'livro', NULL, NULL, NULL, NULL),
      ('D3 Autre lot',                    v_autre::int, 'livro', NULL, 'Les utopiques', '3', NULL)
    ) AS f(t, b, tm, nb, p, ns, du);
END $$;

\ir ../../supabase/migrations/20261019131842_d3_les_fascicules_solidaires_rattaches_a_leurs_revues.sql
\ir ../../supabase/migrations/20261019131842_d3_les_fascicules_solidaires_rattaches_a_leurs_revues.sql

DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := '{}'; v_t text;
  s_u bigint; s_c bigint; s_r bigint;
  d record;
BEGIN
  SELECT id INTO s_u FROM public.serials WHERE slug = 'les-utopiques';
  SELECT id INTO s_c FROM public.serials WHERE slug = 'cahiers-de-la-formation-syndicale';
  SELECT id INTO s_r FROM public.serials WHERE slug = 'revue-internationale';

  -- T1
  v_t := 'T1 trois titres proposés, une fois chacun';
  IF (SELECT count(*) FROM public.serials WHERE slug IN ('les-utopiques','cahiers-de-la-formation-syndicale','revue-internationale')) = 3
     AND (SELECT bool_and(status = 'proposto') FROM public.serials WHERE id IN (s_u, s_c, s_r))
     AND (SELECT uniform_title || '|' || title_nonfiling FROM public.serials WHERE id = s_u) = 'Les utopiques|4'
     AND (SELECT scope_note ~ 'homonymie' FROM public.serials WHERE id = s_r)
     AND (SELECT scope_note ~ 'lot 63' FROM public.serials WHERE id = s_c)
  THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  -- T2
  v_t := 'T2 fascicules typés, rattachés, numérotés';
  IF (SELECT tipo_material||'|'||serial_id||'|'||titulo_periodico||'|'||numero FROM public.book_drafts WHERE titulo = 'D3 Les utopiques n°5 - premier')
       = 'periodico|'||s_u||'|Les utopiques|5'
     AND (SELECT serial_id||'|'||titulo_periodico||'|'||numero FROM public.book_drafts WHERE titulo = 'D3 Cahiers n°6')
       = s_c||'|cahiers de la formation SYNDICALE|6'
     AND (SELECT serial_id||'|'||numero FROM public.book_drafts WHERE titulo = 'D3 Revue internationale n°9') = s_r||'|9'
     AND (SELECT serial_id = s_u AND tipo_material = 'periodico' AND numero IS NULL FROM public.book_drafts WHERE titulo = 'D3 Les utopiques sans numero')
  THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  -- T3
  v_t := 'T3 rien n''est fusionné ni écarté';
  IF (SELECT count(*) FROM public.book_drafts WHERE titulo LIKE 'D3 Les utopiques n°5%' AND serial_id = s_u AND numero = '5' AND status = 'draft') = 2
     AND (SELECT count(*) FROM public.book_drafts WHERE titulo LIKE 'D3 %') = 8
     AND NOT EXISTS (SELECT 1 FROM public.book_drafts WHERE titulo LIKE 'D3 %' AND status <> 'draft')
     AND (SELECT marc_json->'ingest'->'raw_payload'->>'duplo_numero' FROM public.book_drafts WHERE titulo = 'D3 Les utopiques n°5 - second') LIKE 'meme numero%'
  THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  -- T4
  v_t := 'T4 anti-écrasement';
  IF (SELECT tipo_material = 'livro' AND serial_id IS NULL AND numero = '7' FROM public.book_drafts WHERE titulo = 'D3 Deja retouche')
     AND (SELECT tipo_material = 'livro' AND serial_id IS NULL FROM public.book_drafts WHERE titulo = 'D3 Autre lot')
     AND (SELECT tipo_material = 'livro' AND serial_id IS NULL FROM public.book_drafts WHERE titulo = 'D3 Livre sans revue')
  THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  -- T5
  v_t := 'T5 updated_at préservé, une ligne de note';
  IF NOT EXISTS (SELECT 1 FROM public.book_drafts WHERE titulo LIKE 'D3 %' AND updated_at <> timestamptz '2026-09-15 12:00+00')
     AND (SELECT (length(notes) - length(replace(notes, '— D3.', ''))) / length('— D3.') FROM public.catalog_batches WHERE id = 63) = 1
     AND (SELECT notes ~ '5 fascicule\(s\) rattaché\(s\).*3 titre\(s\) créé\(s\)' FROM public.catalog_batches WHERE id = 63)
     AND (SELECT notes LIKE 'Lote criado a partir do import.%' FROM public.catalog_batches WHERE id = 63)
  THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : notes='||coalesce((SELECT notes FROM public.catalog_batches WHERE id = 63),'∅')); END IF;

  -- T6
  v_t := 'T6 idempotence';
  IF (SELECT count(*) FROM public.serials WHERE uniform_title IN ('Les utopiques','Cahiers de la formation syndicale','Revue internationale')) = 3
     AND (SELECT count(*) FROM public.book_drafts WHERE titulo LIKE 'D3 %' AND serial_id IS NOT NULL) = 5
  THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'D3-FASCICULES OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'D3-FASCICULES ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;

ROLLBACK;
