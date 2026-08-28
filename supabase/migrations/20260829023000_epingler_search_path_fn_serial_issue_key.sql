-- =============================================================================
-- Epingler le search_path de fn_serial_issue_key
-- =============================================================================
-- Date     : 2026-08-29
-- Chantier : audit des advisors (suite du lot periodiques)
--
-- L'advisor 0011 (`function_search_path_mutable`) etait a ZERO depuis le
-- 22/08. Il est remonte a 1 : `public.fn_serial_issue_key`, nee avec le lot
-- periodiques du 27/08.
--
-- POURQUOI CELLE-CI MERITE MIEUX QUE « DE L'HYGIENE ».
--
-- La regle de tri du projet dit qu'un search_path mutable n'ouvre rien sur une
-- fonction SECURITY INVOKER : elle s'execute deja avec les droits de l'appelant,
-- il n'y a pas de privilege a voler. C'est vrai ici — la fonction est bien
-- INVOKER, et il n'y a aucune escalade possible.
--
-- Mais elle n'est pas appelee comme une RPC : elle alimente une COLONNE GENEREE,
-- `books.issue_key` (`fn_serial_issue_key(volume, numero, fasciculo,
-- data_edicao, ano)`). Deux consequences que la regle generale ne couvre pas :
--
--   1. Une fonction utilisee par une colonne generee doit etre IMMUTABLE, et
--      Postgres l'exige. Or « immuable » veut dire : meme entree, meme sortie,
--      toujours. Un search_path mutable rend cette promesse dependante du
--      contexte d'appel — c'est-a-dire la contredit.
--
--   2. `pg_dump` OMET les colonnes generees. Elles sont donc RECALCULEES a la
--      restauration, sous le search_path de `pg_restore` et non sous celui des
--      ecritures d'origine. C'est le jour de la restauration que l'ecart se
--      paierait, et c'est le pire jour pour le decouvrir.
--
-- En pratique le corps n'appelle que des fonctions natives (concat_ws, btrim,
-- lower, nullif, coalesce, regexp_replace), toutes dans pg_catalog, qui est
-- TOUJOURS resolu en premier quel que soit le search_path. Aucune valeur ne
-- change donc aujourd'hui, et aucune colonne n'est reecrite : `ALTER FUNCTION
-- ... SET` ne touche pas au corps, ne change pas la volatilite, et n'invalide
-- pas les valeurs deja stockees.
--
-- On ne repare pas un bug : on retire une classe de risque, et on ramene
-- l'advisor 0011 a zero — ce qui rend le prochain 1 significatif au lieu d'etre
-- noye dans un bruit habituel.
--
-- pg_temp est ajoute apres pg_catalog par prudence d'usage : il est de toute
-- facon place en tete si on ne le nomme pas, et le nommer explicitement en fin
-- de liste evite qu'un objet temporaire masque un objet du catalogue.
-- =============================================================================

begin;

alter function public.fn_serial_issue_key(text, text, text, text, text)
  set search_path = pg_catalog, pg_temp;

-- -----------------------------------------------------------------------------
-- Verification
-- -----------------------------------------------------------------------------
-- Structurelle ET fonctionnelle : la fonction est pure, donc on peut verifier
-- qu'epingler ne change AUCUNE valeur, sans avoir besoin de donnees seedees.
do $verif$
declare
  v_cfg text[];
begin
  select p.proconfig into v_cfg
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'fn_serial_issue_key';

  if v_cfg is null or not exists (
    select 1 from unnest(v_cfg) c where c like 'search_path=%'
  ) then
    raise exception 'le search_path de fn_serial_issue_key n''est pas epingle';
  end if;

  -- La volatilite doit rester IMMUTABLE : la colonne generee books.issue_key en
  -- depend, et Postgres refuserait la colonne autrement.
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'fn_serial_issue_key'
       and p.provolatile = 'i'
  ) then
    raise exception 'fn_serial_issue_key n''est plus IMMUTABLE';
  end if;

  -- Le resultat ne bouge pas. Trois cas : numerique bruite, date en casse
  -- melangee, et le cas entierement vide qui doit rendre NULL (c'est lui qui
  -- permet a l'index d'unicite d'ignorer les livres non periodiques).
  if public.fn_serial_issue_key('vol. 12', 'n°3', '', 'Mars 2020', '2020')
     is distinct from '12|3|mars 2020|2020' then
    raise exception 'fn_serial_issue_key : resultat inattendu sur le cas nominal (%)',
      public.fn_serial_issue_key('vol. 12', 'n°3', '', 'Mars 2020', '2020');
  end if;

  if public.fn_serial_issue_key(null, null, null, null, null) is not null then
    raise exception 'fn_serial_issue_key : le cas entierement vide doit rendre NULL';
  end if;

  if public.fn_serial_issue_key('', '', '', '   ', '') is not null then
    raise exception 'fn_serial_issue_key : le cas blanc doit rendre NULL';
  end if;
end
$verif$;

commit;

-- =============================================================================
-- CONTROLE APRES DEPLOIEMENT
-- =============================================================================
--   select proname, proconfig from pg_proc p
--     join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname='public' and p.proname='fn_serial_issue_key';
--   -- attendu : {search_path=pg_catalog,\ pg_temp}
--
-- Et le controle qui vaut plus que le compte d'advisors — la classe REELLEMENT
-- dangereuse, DEFINER sans search_path epingle, doit rester vide :
--
--   select n.nspname||'.'||p.proname from pg_proc p
--     join pg_namespace n on n.oid=p.pronamespace
--    where n.nspname in ('public','api','ingest') and p.prosecdef
--      and not exists (select 1 from unnest(coalesce(p.proconfig,'{}')) c
--                       where c like 'search_path=%');
-- =============================================================================
