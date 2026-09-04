-- =====================================================================
-- AnarBib -- Les notes d'import s'effacent des notices
-- Date    : 2026-09-04  ·  demande Xavier (soir)
--
-- 2 125 notices portaient dans `notas` la trace de l'import de juin :
--   « Importado da Biblioteca Terra Livre para staging AnarBib.
--     source_seq=1131
--     source_item_type=BOOK »
-- Une note de catalogage, publique sur la page du livre, qui ne parle qu'a
-- l'outil d'import. Quarante-six d'entre elles portent APRES ces trois lignes
-- un resume ou une URL (« resumo=… », « url=… ») : ceux-la restent, seules les
-- trois lignes d'import partent. Meme nettoyage sur les brouillons publies
-- (une reprise de notice repartirait sinon de la note d'import). Idempotent.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.fn_sans_note_import(p text)
RETURNS text
LANGUAGE sql IMMUTABLE
AS $$
  SELECT NULLIF(btrim(
    regexp_replace(
      regexp_replace(COALESCE(p, ''),
        '(^|\n)\s*Importad[oa] d[aeo]s? [^\n]*para staging AnarBib\.?[^\n]*', '\1', 'gi'),
      '(^|\n)\s*source_(seq|item_type|library|id|type)=[^\n]*', '\1', 'gi'),
    E' \n\r\t'), '');
$$;

UPDATE public.books
   SET notas = pg_temp.fn_sans_note_import(notas)
 WHERE notas ~* 'para staging AnarBib' OR notas ~* '(^|\n)\s*source_(seq|item_type)=';

UPDATE public.book_drafts
   SET notas = pg_temp.fn_sans_note_import(notas)
 WHERE notas ~* 'para staging AnarBib' OR notas ~* '(^|\n)\s*source_(seq|item_type)=';

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM public.books WHERE notas ~* 'para staging AnarBib';
  IF n > 0 THEN RAISE EXCEPTION 'Garde-fou : % note(s) d''import restante(s)', n; END IF;
END $$;

COMMIT;
