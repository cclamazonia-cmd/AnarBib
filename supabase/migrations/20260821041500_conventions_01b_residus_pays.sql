-- =============================================================================
-- CONV/01b — normaliser les deux pays residuels, qui bloquent tout le reste
-- =============================================================================
-- POURQUOI CETTE MIGRATION S'INTERCALE ICI. `20260821041000` (CONV/01) a pose
-- `authors_country_iso_chk` en NOT VALID et a annonce lui-meme son residu :
--
--     NOTICE : CONV/01 — residu a traiter a la main : idioma 0 · country 2
--
-- Deux lignes non conformes, laissees en place. `20260821042000` (CONV/02) a
-- alors echoue en production :
--
--     ERROR: new row for relation "authors" violates check constraint
--            "authors_country_iso_chk" (SQLSTATE 23514)
--     Failing row contains (10973, Abdullah OCALAN, ..., Türkiye, ...)
--
-- LE MECANISME, qui vaut d'etre retenu. Une contrainte `NOT VALID` n'examine
-- PAS l'existant — mais elle controle CHAQUE ECRITURE. Les lignes residuelles
-- sont donc tolerees au repos et refusees au premier `UPDATE`, **meme si la
-- mise a jour porte sur une tout autre colonne** : Postgres revalide la ligne
-- entiere. CONV/02 mettait a jour `birth_year_qualifier` ; c'est le pays qui a
-- fait echouer la transaction.
--
-- CE N'ETAIT PAS QU'UN ROUGE DE CI. La contrainte etant vivante en production,
-- editer l'un de ces deux auteurs depuis l'application echouait deja, avec un
-- message parlant d'un champ que la personne n'avait pas touche.
--
-- CE QUE FAIT CETTE MIGRATION. Elle traduit les deux valeurs en ISO 3166-1
-- alpha-2, ce que la contrainte attend :
--
--     10973  Abdullah OCALAN    Türkiye    -> TR
--     11001  Anton PANNEKOEK    Nederland  -> NL
--
-- Elle est numerotee 041500 pour s'appliquer APRES CONV/01 (qui pose la
-- contrainte) et AVANT CONV/02 (qui trebuche dessus). Sans ce placement, la
-- chaine reste bloquee : CONV/02 a 045000 ne peuvent pas passer.
--
-- Portee volontairement etroite : deux lignes nommees, rien d'autre. Le reste
-- du chantier « conventions » appartient a la session qui le mene.
-- =============================================================================

begin;

update public.authors set country = 'TR'
 where id = 10973 and country = 'Türkiye';

update public.authors set country = 'NL'
 where id = 11001 and country = 'Nederland';

-- -----------------------------------------------------------------------------
-- Verification : plus aucun residu, sinon CONV/02 echouera de nouveau.
-- -----------------------------------------------------------------------------
do $$
declare
  v_pays  integer;
  v_idiom integer;
begin
  select count(*) into v_pays
    from public.authors
   where country is not null and country !~ '^[A-Z]{2}$';

  select count(*) into v_idiom
    from public.books
   where idioma is not null and idioma !~ '^[a-z]{2}(-[A-Z]{2})?$';

  if v_pays <> 0 then
    raise exception 'CONV/01b : % pays encore non conformes — CONV/02 echouera', v_pays;
  end if;
  if v_idiom <> 0 then
    raise exception 'CONV/01b : % idiomes non conformes — a traiter avant CONV/02', v_idiom;
  end if;

  raise notice 'CONV/01b — residus normalises : 0 pays, 0 idiome. CONV/02 peut passer.';
end $$;

commit;

-- =============================================================================
-- A RETENIR POUR LES PROCHAINES CONTRAINTES
-- =============================================================================
-- Poser une contrainte NOT VALID en laissant sciemment des residus reporte le
-- probleme sur la premiere ecriture venue — y compris celle d'une migration
-- ulterieure, ou celle d'une personne qui edite une fiche. Deux facons de ne
-- pas se le refaire :
--   * normaliser les residus DANS la migration qui pose la contrainte ; ou
--   * si l'on choisit de les laisser, le dire dans le NOTICE **et** poser un
--     garde-fou qui empeche les migrations suivantes de toucher ces lignes.
-- Un NOTICE que personne ne lit n'est pas un garde-fou.
-- =============================================================================
