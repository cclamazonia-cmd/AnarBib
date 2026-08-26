-- ============================================================================
-- Alignement des sujets AnarBib sur le thesaurus FICEDL
-- Genere le 26/08/2026 -- revise le 26/08/2026 apres echec CI sql-tests.
--
-- Etat de depart en production : subject_ficedl_links vide ; 54 sujets locaux ;
-- 462 termes FICEDL importes et renseignes dans les 10 locales.
--
-- IMPORTANT -- pourquoi la verification n'est pas un compte fige.
-- Les tables subjects et ficedl_thesaurus_terms sont alimentees par des
-- imports, pas par des migrations. Sur un schema reconstruit a neuf (CI
-- sql-tests, instance auto-hebergee vierge) elles sont VIDES : ce script
-- n'a alors rien a aligner, et c'est normal. La verification compare donc
-- ce qui etait alignable a ce qui a ete aligne, au lieu d'exiger 51.
--
-- Arbitrages de Xavier, 26/08/2026 :
--   anticlericalisme      -> libre-pensee (mot165), ecarte religion
--   abolitionnisme penal  -> prison (mot235), ecarte justice
--   anarcho-communisme    -> anarchisme (mot8), ecarte communisme
--   makhnovtchina         -> Ukraine (mot403), ecarte Russie 1917-1921
--   especifismo           -> mouvement anarchiste (mot199), ecarte organisation
--   resistance au gouv.   -> desobeissance civile (mot75), ecarte revolte
--   doublons              -> 43 fusionne dans 4 ; 58 fusionne dans 50 ;
--                            6 et 52 conserves distincts
--   anarcho-capitalisme   -> deliberement non aligne
--   anarcho-punk          -> art : musique (mot27), faute de mieux
--
-- match_type est contraint a 'exact' | 'close'.
-- Idempotent : ON CONFLICT DO NOTHING sur (subject_id, mot_id).
-- En production : 51 liens (28 exact, 23 close).
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 0. Correspondances voulues
-- ---------------------------------------------------------------------------
create temporary table _align_intent (
  subject_id int  not null,
  mot_id     text not null,
  match_type text not null
) on commit drop;

insert into _align_intent (subject_id, mot_id, match_type) values
  (1, 'mot8', 'exact'),
  (2, 'mot263', 'exact'),
  (3, 'mot202', 'exact'),
  (4, 'mot104', 'close'),
  (5, 'mot122', 'exact'),
  (6, 'mot87', 'close'),
  (7, 'mot11', 'exact'),
  (8, 'mot119', 'close'),
  (9, 'mot1', 'exact'),
  (10, 'mot165', 'close'),
  (11, 'mot235', 'close'),
  (12, 'mot191', 'close'),
  (13, 'mot201', 'exact'),
  (14, 'mot169', 'exact'),
  (15, 'mot71', 'close'),
  (16, 'mot17', 'close'),
  (17, 'mot272', 'exact'),
  (18, 'mot8', 'close'),
  (19, 'mot122', 'close'),
  (20, 'mot153', 'close'),
  (21, 'mot204', 'exact'),
  (22, 'mot194', 'exact'),
  (23, 'mot36', 'exact'),
  (24, 'mot271', 'exact'),
  (25, 'mot129', 'exact'),
  (26, 'mot326', 'exact'),
  (27, 'mot338', 'exact'),
  (28, 'mot494', 'exact'),
  (29, 'mot403', 'close'),
  (33, 'mot123', 'close'),
  (35, 'mot192', 'close'),
  (36, 'mot281', 'close'),
  (37, 'mot115', 'close'),
  (38, 'mot228', 'exact'),
  (39, 'mot232', 'exact'),
  (40, 'mot199', 'close'),
  (41, 'mot313', 'close'),
  (42, 'mot247', 'exact'),
  (44, 'mot119', 'exact'),
  (45, 'mot510', 'exact'),
  (46, 'mot8', 'close'),
  (47, 'mot213', 'exact'),
  (48, 'mot55', 'exact'),
  (49, 'mot75', 'close'),
  (50, 'mot373', 'exact'),
  (51, 'mot166', 'close'),
  (52, 'mot87', 'exact'),
  (53, 'mot261', 'close'),
  (55, 'mot27', 'close'),
  (56, 'mot250', 'exact'),
  (57, 'mot78', 'exact');

-- ---------------------------------------------------------------------------
-- 1. Fusion des doublons -- IMPERATIVEMENT AVANT les liens
--    Aligner un doublon reviendrait a le figer dans le vocabulaire partage.
--    Sans donnees (schema neuf) ces ordres ne trouvent rien : sans effet.
-- ---------------------------------------------------------------------------
-- pedagogia-libertaria (#43) -> educacao-libertaria (#4)
--   book_subjects a pour cle primaire (book_id, subject_id) : on retire d'abord
--   les indexations en double, sinon l'update viole la cle.
delete from public.book_subjects a
 where a.subject_id = 43
   and exists (select 1 from public.book_subjects b
                where b.book_id = a.book_id and b.subject_id = 4);
update public.book_subjects set subject_id = 4 where subject_id = 43;
update public.subjects set status = 'depreciado', updated_at = now() where id = 43;

-- mexico-2 (#58) -> mexico (#50)
--   book_subjects a pour cle primaire (book_id, subject_id) : on retire d'abord
--   les indexations en double, sinon l'update viole la cle.
delete from public.book_subjects a
 where a.subject_id = 58
   and exists (select 1 from public.book_subjects b
                where b.book_id = a.book_id and b.subject_id = 50);
update public.book_subjects set subject_id = 50 where subject_id = 58;
update public.subjects set status = 'depreciado', updated_at = now() where id = 58;

-- ---------------------------------------------------------------------------
-- 2. Alignement
-- ---------------------------------------------------------------------------
insert into public.subject_ficedl_links (subject_id, mot_id, match_type, created_by)
select i.subject_id, i.mot_id, i.match_type, null
from _align_intent i
where exists (select 1 from public.subjects s
               where s.id = i.subject_id and s.status = 'ativo')
  and exists (select 1 from public.ficedl_thesaurus_terms f
               where f.mot_id = i.mot_id)
on conflict (subject_id, mot_id) do nothing;

-- ---------------------------------------------------------------------------
-- 3. Verification -- relative, donc valable a vide comme en production
-- ---------------------------------------------------------------------------
do $$
declare n_exp int; n_got int; n_orphelines int;
begin
  select count(*) into n_exp
    from _align_intent i
   where exists (select 1 from public.subjects s
                  where s.id = i.subject_id and s.status = 'ativo')
     and exists (select 1 from public.ficedl_thesaurus_terms f
                  where f.mot_id = i.mot_id);

  select count(*) into n_got
    from _align_intent i
    join public.subject_ficedl_links l
      on l.subject_id = i.subject_id and l.mot_id = i.mot_id;

  select count(*) into n_orphelines
    from public.book_subjects where subject_id in (43, 58);

  raise notice 'alignables : % / alignes : % / indexations restees sur un doublon : %',
               n_exp, n_got, n_orphelines;

  if n_got <> n_exp then
    raise exception 'alignement incomplet : % alignables, % poses', n_exp, n_got;
  end if;

  if n_orphelines <> 0 then
    raise exception 'fusion incomplete : % indexations pointent encore sur un sujet deprecie',
                    n_orphelines;
  end if;

  if n_exp = 0 then
    raise notice 'aucune donnee de reference : schema neuf, rien a aligner (normal en CI)';
  end if;
end $$;

commit;

-- ---------------------------------------------------------------------------
-- Volontairement hors de ce script
--
-- * anarcocapitalismo (#54) n'est pas aligne. L'absence du terme dans le
--   thesaurus est une position de la federation, pas un oubli. Si un livre
--   arrive un jour et qu'on tranche autrement :
--     insert into public.subject_ficedl_links (subject_id, mot_id, match_type)
--     values (54, 'mot44', 'close');
--
-- * anarco-punk (#55) est rattache a 'art : musique' faute de mieux.
--   Pour revenir dessus :
--     delete from public.subject_ficedl_links where subject_id = 55;
--
-- * Artefacts d'import : les sujets 46 (anarchisme-social) et 47 (organisation)
--   ont un libelle pt-BR non traduit, recopie du francais.
--
-- * Cle de locale : subjects.label_i18n utilise 'pt-BR',
--   ficedl_thesaurus_terms.labels utilise 'pt'. A harmoniser cote lecture.
--
-- * Huit sujets n'ont aucun equivalent FICEDL et sont rattaches a un terme
--   plus large -- voir la 2e feuille du classeur ALIGNEMENT_thesaurus_FICEDL.
-- ---------------------------------------------------------------------------
