-- =========================================================================
-- Le type de document d'une ligne importée dit la NATURE du document
-- =========================================================================
-- Date     : 2026-10-19
-- Chantier : banc OAI ASB → AnarBib (19/10/2026), section 3 — décision de
--            Xavier le même jour
-- Auteur   : Claude (Opus 5.5), à la demande de Xavier
-- Suite    : tests/sql/import_type_de_document_tests.sql
--
-- LA DÉCISION.
--   tipo_material dit la nature du document, pas son support : un texte lu en
--   ligne qui transcrit un livre reste « livro » (« Livre / brochure »), un
--   article reste « artigo », une revue « periodico ». La lecture en ligne est
--   portée par la ressource numérique de la notice (lien externe, PDF), pas
--   par le type. « recurso_digital » reste réservé aux ressources nées
--   numériques (page web, jeu de données). C'est déjà la règle d'Anarchief.org
--   (808 livro, 142 periodico, 43 artigo, 9 tese, tous sans exemplaire).
--
-- LE CONSTAT (banc du 19/10).
--   La correspondance de ingest.fn_import_row_as_book (H17) rendait « livro »
--   pour tout type brut qu'elle ne connaissait pas. Trois trous :
--     - le vocabulaire d'AnarcosyndicalismeBOOK (type_materiel, servi en
--       dc:type) : « revue » et « affiche » devenaient des livres ;
--     - les types DCMI courants (dc:type) : « Image », « MovingImage » ;
--     - nos PROPRES codes « cartaz », « dossie » et « recurso_digital » : une
--       notice AnarBib moissonnée par une autre instance AnarBib (notre oai_dc
--       sert le code en dc:type) perdait son type. En production, quatre
--       lignes de staging portent déjà « cartaz » ou « dossie ».
--
-- LE GESTE.
--   ingest.fn_import_row_as_book, réécrite depuis sa DÉFINITION RÉELLE
--   (pg_get_functiondef ; lue en production le 19/10/2026 : md5
--   e8bb252d61756dbaa2dfb848307e378c, 13 459 caractères) — une ancre comptée
--   (une occurrence exacte), neuf cas ajoutés avant le « else 'livro' ». Rien
--   d'autre ne bouge : IMMUTABLE, search_path, droits (postgres et
--   service_role), le type déduit du guide MARC qui passe avant le type brut,
--   le défaut « livro ».
--
-- CE QUE LE PAQUET NE FAIT PAS.
--   - Les notices déjà publiées gardent leur type. Au réimport d'une source
--     qui portait « cartaz » ou « dossie », la comparaison (H21) verra la
--     nouvelle valeur et proposera la correction par le chemin habituel.
--   - Des types bruts en portugais vus en production, seuls « panfleto »
--     (→ tract, 14 lignes) et « folheto » (→ livro, écrit en clair) sont
--     traités (décision du 19/10) ; les genres (« carta », « biografia »,
--     « discurso »…) ne sont pas des natures du vocabulaire et restent livro.
--
-- CHECKLIST DOCTRINE
--   [x] Fonction réécrite depuis sa définition réelle, droits et volatilité
--       comparés avant / après dans le bloc
--   [x] Pas de table, pas de colonne, pas de policy touchée
--   [x] Ancre comptée : la migration ÉCHOUE si elle manque ou se répète ;
--       rejouée sur une fonction déjà modifiée, elle ne fait rien
--   [x] Le fonctionnel est dans la suite SQL (DOC-MIGR-1)
-- =========================================================================

BEGIN;

DO $migration$
DECLARE
  v_sig   constant regprocedure := 'ingest.fn_import_row_as_book(ingest.partner_catalog_staging_rows,jsonb)'::regprocedure;
  v_def   text;
  v_acl   text;
  v_vol   "char";
  v_n     int;
  v_ancre constant text := E'        when ''audiovisual'' then ''audiovisual''\n        else ''livro''\n';
  v_cas   constant text := $cas$        -- 19/10/2026 (décision de Xavier, banc OAI ASB) : la nature du document,
        -- pas son support. Vocabulaire d'AnarcosyndicalismeBOOK (dc:type),
        -- types DCMI courants, et nos propres codes, que notre oai_dc sert.
        when 'revue' then 'periodico'
        when 'affiche' then 'cartaz'
        when 'image' then 'cartaz'
        when 'movingimage' then 'audiovisual'
        when 'cartaz' then 'cartaz'
        when 'dossie' then 'dossie'
        when 'recurso_digital' then 'recurso_digital'
        -- Types bruts en portugais vus en production (décision du 19/10) :
        -- panfleto est un tract ; folheto (brochure) reste un livre, écrit en clair.
        when 'panfleto' then 'tract'
        when 'folheto' then 'livro'
$cas$;
BEGIN
  v_def := pg_get_functiondef(v_sig);
  SELECT proacl::text, provolatile INTO v_acl, v_vol FROM pg_proc WHERE oid = v_sig;

  IF strpos(v_def, 'when ''movingimage'' then ''audiovisual''') > 0 THEN
    RAISE NOTICE 'fn_import_row_as_book connait deja ces types : rien a faire.';
    RETURN;
  END IF;

  v_n := (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'Ancre de fn_import_row_as_book trouvee % fois (attendu 1) : la definition reelle a change, ne rien appliquer.', v_n;
  END IF;

  EXECUTE replace(v_def, v_ancre,
                  E'        when ''audiovisual'' then ''audiovisual''\n' || v_cas || E'        else ''livro''\n');

  v_def := pg_get_functiondef(v_sig);
  IF strpos(v_def, 'when ''revue'' then ''periodico''') = 0 OR strpos(v_def, 'when ''recurso_digital'' then ''recurso_digital''') = 0 THEN
    RAISE EXCEPTION 'Les nouveaux cas sont absents apres reecriture.';
  END IF;
  IF (SELECT proacl::text FROM pg_proc WHERE oid = v_sig) IS DISTINCT FROM v_acl THEN
    RAISE EXCEPTION 'Les droits de fn_import_row_as_book ont change.';
  END IF;
  IF (SELECT provolatile FROM pg_proc WHERE oid = v_sig) IS DISTINCT FROM v_vol THEN
    RAISE EXCEPTION 'La volatilite de fn_import_row_as_book a change.';
  END IF;
END
$migration$;

COMMIT;
