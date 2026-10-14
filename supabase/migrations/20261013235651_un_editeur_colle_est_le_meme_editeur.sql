-- =====================================================================
-- AnarBib -- Un nom d'éditeur collé (« LaMalatesta ») est le même éditeur que
--            son écriture en deux mots (DEDUP-16)
-- Date     : 2026-10-14  ·  Relevé de Xavier (revue des capas, deux fois
--            « Venezuela — La Revolución como espectáculo » à la BTL)
-- Dépend   : 20260928163920 (DEDUP-14 : fn_editeur_coeur, fn_meme_editeur,
--            définition réelle relue en prod le 13/10 avant réécriture)
--
-- CONSTAT (prod, 13/10). BTL-TL-000005 et BTL-TL-000012 (Uzcátegui,
-- Venezuela…, 2010, même œuvre 153, titres identiques, sans ISBN) ne sont
-- jamais proposées : l'éditeur de l'une est la co-édition « El Libertario/La
-- Cucaracha Ilustrada/Libros de Anarres/Tierra de fuego/LaMalatesta
-- Editorial », celui de l'autre « La Malatesta ». Le cœur du premier porte
-- le mot « lamalatesta » (collé), celui du second « malatesta » (l'article
-- est un mot générique retiré) : aucun mot commun, similarité loin de 0,75,
-- donc « deux éditeurs », donc « deux éditions », donc la règle P4 masque la
-- paire. Même famille que DEDUP-14 : une différence d'écriture prise pour
-- une différence d'édition.
--
-- CE QUI CHANGE. fn_editeur_coeur coupe un mot collé à sa majuscule interne
-- (« LaMalatesta » → « La Malatesta », « LaCucaracha » → « La Cucaracha »)
-- avant la normalisation ; le reste de la règle (mots génériques, égalité,
-- inclusion, similarité ≥ 0,75) est inchangé. Un sigle en capitales
-- (« CNT-AIT ») n'a pas de minuscule suivie d'une majuscule : il ne bouge pas.
-- Droits inchangés (CREATE OR REPLACE conserve les GRANT ; fermée à anon).
-- Suite : tests/sql/editions_distinctes_tests.sql, T9.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_editeur_coeur(p_editora text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  select coalesce(array_to_string(array(
    select tok
      from unnest(string_to_array(public.fn_normalize_name(
             -- DEDUP-16 (14/10) : un nom collé à sa majuscule interne est coupé avant normalisation.
             regexp_replace(coalesce(p_editora, ''), '([[:lower:]])([[:upper:]])', '\1 \2', 'g')), ' ')) as tok
     where tok <> '' and length(tok) > 1
       and tok <> all (array[
         'editora','editorial','editoriale','editoriali','ediciones','edicions','edicoes','edicao','edicion','edition','editions',
         'editeur','editeurs','editores','editore','editor','ed','eds','verlag','press','publishing','publishers','publisher',
         'books','livros','livraria','libreria','librairie','libri','casa','cia','cie','co','ltda','ltd','sa','srl','inc',
         'grafica','tipografia','imprenta','imprensa','impressora','oficina','oficinas','colecao','coleccion','collection',
         'de','da','do','das','dos','del','della','di','la','le','les','el','los','las','the','and','et','und'])
     order by tok), ' '), '');
$function$;

-- Garde-fou de la migration elle-même : une mutation la fait refuser AVANT la suite.
DO $$
BEGIN
  IF public.fn_editeur_coeur('LaMalatesta Editorial') <> 'malatesta'
     OR NOT public.fn_meme_editeur('El Libertario/La Cucaracha Ilustrada/Libros de Anarres/Tierra de fuego/LaMalatesta Editorial', 'La Malatesta')
     OR public.fn_editions_distinctes('', '', '2010', '2010', 'El Libertario/La Cucaracha Ilustrada/Libros de Anarres/Tierra de fuego/LaMalatesta Editorial', 'La Malatesta', '', '') THEN
    RAISE EXCEPTION 'DEDUP-16 : « LaMalatesta » et « La Malatesta » ne sont pas reconnus comme le même éditeur';
  END IF;
  IF public.fn_editeur_coeur('Ediciones Manantial') <> 'manantial'
     OR public.fn_editeur_coeur('CNT-AIT') <> public.fn_editeur_coeur('cnt ait')
     OR public.fn_meme_editeur('Manantial', 'Hedra') THEN
    RAISE EXCEPTION 'DEDUP-16 : la règle des éditeurs a changé au-delà des noms collés';
  END IF;
  IF has_function_privilege('anon', 'public.fn_editeur_coeur(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'DEDUP-16 : fn_editeur_coeur ouverte à anon';
  END IF;
END $$;

COMMIT;
