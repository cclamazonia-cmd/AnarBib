-- =========================================================================
-- Catalogue — champ « gravadora » (maison de disques) pour les supports audio
-- =========================================================================
-- Date     : 2026-06-17
-- Chantier : Catalogação / cohérence supports non écrits (#CAT-EDITEUR-AV-AUDIO)
-- Auteur   : Xavier + Claude
-- Session  : File éditoriale — tri & supports AV
--
-- OBJET
-- -----
-- Pendant audio du `distribuidora` (audiovisuel) : capture la maison de disques
-- / le label d'un enregistrement. Colonne TEXT nullable sur book_drafts et
-- books (saisie au formulaire, section audio). La copie au PUBLISH et
-- l'exposition dans les vues catalogue (v_book_detail_public_v2 + MV) sont
-- traitées dans des migrations dédiées.
-- =========================================================================

begin;

alter table public.book_drafts add column if not exists gravadora text;
alter table public.books       add column if not exists gravadora text;

comment on column public.book_drafts.gravadora is 'Maison de disques / label (support audio). Pendant audio de distribuidora.';
comment on column public.books.gravadora       is 'Maison de disques / label (support audio). Pendant audio de distribuidora.';

notify pgrst, 'reload schema';

commit;

-- =========================================================================
-- Rollback :
--   alter table public.book_drafts drop column if exists gravadora;
--   alter table public.books       drop column if exists gravadora;
-- =========================================================================
