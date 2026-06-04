-- 20260604190251_restore_btl_exemplares_36_37.sql
-- ----------------------------------------------------------------------------
-- ONE-OFF (correction de donnees prod). Les exemplaires BTL-TL-EX-000036/037
-- avaient ete supprimes pendant le test du discard, puis recrees via l'UMI sous
-- BLMF (biblio active de l'operateur) et NON rattaches (holding_id null).
-- On les repoint vers BTL + leurs holdings d'origine (qui existent, a 0 copie) :
--   id 2463 (BTL-TL-EX-000036) -> library BTL, holding 1987 (livre 40)
--   id 2464 (BTL-TL-EX-000037) -> library BTL, holding 830  (livre 41)
--
-- Garde id+tombo+holding_id null => strictement no-op sur toute base ou ces
-- lignes n'existent pas / sont deja corrigees. Idempotent.
-- NB : les champs mineurs (source_library, overrides d'etiquette) peuvent
-- differer des originaux (perdus avec le delete) -- acceptable pour des copies
-- de test ; l'essentiel (biblio + rattachement au document) est retabli.
-- Pas de SECURITY DEFINER ici : commit normal (pas de --no-verify).
-- ----------------------------------------------------------------------------

update public.exemplares
   set library_id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a',
       holding_id = 1987
 where id = 2463 and tombo = 'BTL-TL-EX-000036' and holding_id is null;

update public.exemplares
   set library_id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a',
       holding_id = 830
 where id = 2464 and tombo = 'BTL-TL-EX-000037' and holding_id is null;

-- verification : si les lignes existent en prod, elles doivent etre repointees ;
-- si elles n'existent pas (base fraiche), 0 ligne -> no-op, OK.
do $verif$
declare v_bad int;
begin
  select count(*) into v_bad
  from public.exemplares
  where id in (2463, 2464)
    and ( library_id <> 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a' or holding_id is null );
  if v_bad > 0 then
    raise exception 'VERIF : % exemplaire(s) non repointe(s) (verifier id/tombo)', v_bad;
  end if;
  raise notice 'VERIF OK : 2463/2464 -> BTL + holdings 1987/830 (ou base fraiche, no-op)';
end
$verif$;
