-- D23 (20/10/2026) — deux dates de droits recoupées sur une source citée.
--
-- Deux PDF versés en lecture publique le 16/10 reposaient sur une date « à
-- confirmer » :
--   * ressource 981, notice 223 (Cornelissen, « A caminho da sociedade nova »,
--     1907) : le traducteur Eugénio Vieira, « 1877-1948 », d'après un résumé
--     de recherche. Recoupé le 20/10 sur l'index « Revistas de Ideias e
--     Cultura » (pt.revistasdeideias.net, autorité aut_0000013495 : « Vieira,
--     Eugénio (1877-1948), escritor, tradutor português » ; la même base
--     l'attribue comme traducteur de cette édition de 1907). Cornelissen
--     †1942. Domaine public confirmé.
--   * ressource 979, notice 191 (Fabbri, « La crisis del anarquismo », 1921) :
--     les textes signés « Catilina ». « Catilina » est un pseudonyme connu de
--     Luigi Fabbri (Wikidata, Luigi Fabbri, pseudonyme), †1935 ; et même
--     d'auteur inconnu, une œuvre pseudonyme publiée en 1921 est dans le
--     domaine public depuis 1992 (Lei 9.610/98, art. 43, par. único ;
--     Convention de Berne, art. 7.3). Domaine public confirmé.
-- Les deux restent en lecture publique ; la justification cite désormais sa
-- source, sur la ressource et sur son brouillon. Garde : n'écrit que si la
-- justification est encore celle d'avant (le mot « confirmar » ou le
-- pseudonyme sans source).

DO $d23$
DECLARE v_n int := 0; v_k int;
  c_981 constant text := 'Domínio público: Christiaan Cornelissen (†1942) e o tradutor Eugénio Vieira (1877-1948) mortos há mais de 70 anos. '
    || 'Datas do tradutor e atribuição da tradução de 1907 conferidas em 20/10/2026 no índice «Revistas de Ideias e Cultura» '
    || '(pt.revistasdeideias.net, aut_0000013495: «Vieira, Eugénio (1877-1948), escritor, tradutor português»).';
  c_979 constant text := 'Domínio público: Luigi Fabbri (†1935) morto há mais de 70 anos; tradução anônima publicada em 1921. '
    || '«Catilina» é pseudônimo conhecido de Luigi Fabbri (Wikidata, conferido em 20/10/2026); mesmo de autor não identificado, '
    || 'obra pseudônima publicada em 1921 está em domínio público desde 1992 (Lei 9.610/98, art. 43, parágrafo único; Convenção de Berna, art. 7.3).';
BEGIN
  UPDATE public.book_digital_resources SET rights_justification = c_981
   WHERE id = 981 AND rights_status = 'dominio_publico' AND rights_justification ILIKE '%a confirmar%';
  GET DIAGNOSTICS v_k = ROW_COUNT; v_n := v_n + v_k;
  UPDATE public.book_draft_digital_resources SET rights_justification = c_981
   WHERE published_resource_id = 981 AND rights_justification ILIKE '%a confirmar%';

  UPDATE public.book_digital_resources SET rights_justification = c_979
   WHERE id = 979 AND rights_status = 'dominio_publico'
     AND rights_justification ILIKE '%«Catilina»%' AND rights_justification NOT ILIKE '%Wikidata%';
  GET DIAGNOSTICS v_k = ROW_COUNT; v_n := v_n + v_k;
  UPDATE public.book_draft_digital_resources SET rights_justification = c_979
   WHERE published_resource_id = 979
     AND rights_justification ILIKE '%«Catilina»%' AND rights_justification NOT ILIKE '%Wikidata%';

  RAISE NOTICE 'D23 : % justification(s) de droits recoupée(s).', v_n;
END
$d23$;
