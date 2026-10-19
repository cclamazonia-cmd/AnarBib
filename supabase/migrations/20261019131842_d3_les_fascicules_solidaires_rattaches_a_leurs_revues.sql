-- D3 (19/10/2026, décision de Xavier) : les 43 fascicules du lot SOLIDAIRES
-- rattachés à leurs 3 revues, avant la révision du lot.
--
-- Le lot 63 (run 29, `SOLIDAIRES_import_v2.csv`) porte 1 673 brouillons, tous
-- entrés comme des livres : le profil d'import n'a repris ni la revue ni le
-- numéro, restés dans la charge brute (`marc_json->ingest->raw_payload`, clés
-- `periodico` et `numero`). 43 lignes y nomment une revue — *Les utopiques* (27),
-- *Cahiers de la formation syndicale* (10), *Revue internationale* (6).
--
-- Ce que fait cette migration :
--   1. crée les 3 titres en « proposto » (invisibles du public jusqu'à leur
--      promotion, Catalogage › Périodiques), avec une note de portée qui dit
--      d'où ils viennent ;
--   2. fait de chacun des 43 brouillons un fascicule : `tipo_material` =
--      'periodico', `serial_id`, `titulo_periodico` (la forme transcrite de la
--      source) et `numero` (la colonne de la source ; vide pour une ligne).
-- Ce qu'elle ne fait PAS : rien n'est fusionné ni écarté. La source marque 18
-- de ces lignes « même numéro aussi en ligne X — à trancher par la source »
-- (9 paires) : un même fascicule décrit deux fois, ou deux fascicules — c'est
-- un jugement humain, laissé à la coordination. Le titre de la notice, la
-- charge brute, les cotes, la bibliothèque et le statut ne sont pas touchés.
--
-- Anti-écrasement : un brouillon n'est touché que s'il est encore tel que lu
-- le 19/10 — lot 63, `draft`, type 'livro', sans `serial_id` ni `numero`. Un
-- brouillon déjà retouché par la coordination reste comme elle l'a laissé.
-- `updated_at` est préservé (`anarbib.skip_touch_updated_at`) : la date de
-- dernière modification du lot continue de dire quand la coordination y a
-- travaillé. Une ligne datée s'ajoute aux notes du lot.
--
-- Idempotente. Sur une base sans ce lot ou sans ces lignes (rejeu, banc), ne
-- crée aucun titre et ne touche rien.

DO $$
DECLARE
  v_lot   constant bigint := 63;
  v_titres int := 0;
  v_fasc   int := 0;
  v_reste  int := 0;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.catalog_batches WHERE id = v_lot AND status = 'open') THEN
    RAISE NOTICE 'D3 : lot % absent ou pas ouvert — rien à faire.', v_lot;
    RETURN;
  END IF;

  PERFORM set_config('anarbib.skip_touch_updated_at', 'on', true);

  -- 1. Les titres, seulement pour une revue réellement présente dans le lot.
  WITH revues(cle, titre, nonfiling, slug, note) AS (
    VALUES
      ('les utopiques', 'Les utopiques', 4, 'les-utopiques',
       'Titre créé le 19/10/2026 depuis le lot 63 (Bibliothèque Solidaires, SOLIDAIRES_import_v2.csv), forme de la source ; à relire avant promotion (D3).'),
      ('cahiers de la formation syndicale', 'Cahiers de la formation syndicale', 0, 'cahiers-de-la-formation-syndicale',
       'Titre créé le 19/10/2026 depuis le lot 63 (Bibliothèque Solidaires, SOLIDAIRES_import_v2.csv), forme de la source ; à relire avant promotion (D3).'),
      ('revue internationale', 'Revue internationale', 0, 'revue-internationale',
       'Titre créé le 19/10/2026 depuis le lot 63 (Bibliothèque Solidaires, SOLIDAIRES_import_v2.csv), forme de la source ; titre générique, risque d''homonymie : préciser l''organisme émetteur avant promotion (D3).')
  ), ins AS (
    INSERT INTO public.serials (uniform_title, slug, title_nonfiling, status, scope_note)
    SELECT r.titre, r.slug, r.nonfiling, 'proposto', r.note
      FROM revues r
     WHERE NOT EXISTS (SELECT 1 FROM public.serials s WHERE s.slug = r.slug)
       AND EXISTS (SELECT 1 FROM public.book_drafts d
                    WHERE d.batch_id = v_lot
                      AND lower(btrim(d.marc_json->'ingest'->'raw_payload'->>'periodico')) = r.cle)
    RETURNING 1
  )
  SELECT count(*) INTO v_titres FROM ins;

  -- 2. Les fascicules.
  WITH revues(cle, slug) AS (
    VALUES ('les utopiques', 'les-utopiques'),
           ('cahiers de la formation syndicale', 'cahiers-de-la-formation-syndicale'),
           ('revue internationale', 'revue-internationale')
  ), maj AS (
    UPDATE public.book_drafts d
       SET tipo_material    = 'periodico',
           serial_id        = s.id,
           titulo_periodico = btrim(d.marc_json->'ingest'->'raw_payload'->>'periodico'),
           numero           = nullif(btrim(d.marc_json->'ingest'->'raw_payload'->>'numero'), '')
      FROM revues r
      JOIN public.serials s ON s.slug = r.slug
     WHERE d.batch_id = v_lot
       AND d.status = 'draft'
       AND d.tipo_material = 'livro'
       AND d.serial_id IS NULL
       AND nullif(btrim(d.numero), '') IS NULL
       AND lower(btrim(d.marc_json->'ingest'->'raw_payload'->>'periodico')) = r.cle
    RETURNING 1
  )
  SELECT count(*) INTO v_fasc FROM maj;

  SELECT count(*) INTO v_reste
    FROM public.book_drafts d
   WHERE d.batch_id = v_lot AND d.status = 'draft'
     AND nullif(btrim(d.marc_json->'ingest'->'raw_payload'->>'periodico'), '') IS NOT NULL
     AND d.serial_id IS NULL;

  IF v_fasc > 0 THEN
    UPDATE public.catalog_batches
       SET notes = coalesce(notes || E'\n', '')
                || '[' || to_char(now() at time zone 'utc', 'YYYY-MM-DD HH24:MI') || ' UTC] '
                || v_fasc || ' fascicule(s) rattaché(s) à leur revue depuis les colonnes « periodico » et « numero » de la source ('
                || v_titres || ' titre(s) créé(s) en « proposé ») — D3. Rien n''est fusionné : les lignes « même numéro aussi en ligne X » restent à trancher.'
     WHERE id = v_lot;
  END IF;

  RAISE NOTICE 'D3 : % titre(s) créé(s), % fascicule(s) rattaché(s), % ligne(s) de revue laissée(s) telle(s) quelle(s).', v_titres, v_fasc, v_reste;
END $$;
