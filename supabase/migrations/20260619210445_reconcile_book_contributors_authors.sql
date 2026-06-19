-- 20260619210445_reconcile_book_contributors_authors.sql
-- ----------------------------------------------------------------------------
-- Réconciliation book_contributors <-> book_authors (désync héritée des imports).
--
-- CONSTAT (prod, 19/06) : ~59 % des liens book_authors (1517/2556) sont
-- « fantômes » — l'autorité est attribuée au livre via book_authors mais le
-- contributeur correspondant a author_id NULL. Les deux tables se contredisent :
-- la fiche affiche bien l'auteur (book_authors pilote l'OPAC) mais l'outil de
-- rattachement (contributeurs) le propose comme « à lier », et le dédoublonnage
-- compte des livres incohérents. Même classe que le « lien fantôme » LUZ.
--
-- CORRECTIF : pour chaque contributeur NON lié dont le nom normalisé correspond
-- à UNE SEULE autorité DÉJÀ attribuée au même livre via book_authors (même rôle,
-- même position = ord), on pose author_id = cette autorité. On n'invente AUCUNE
-- attribution : on fait concorder book_contributors avec book_authors (déjà la
-- source d'affichage). Le trigger fn_sync_book_authors_from_contributor se
-- déclenche par ligne et fait INSERT ... ON CONFLICT DO NOTHING (la ligne
-- book_authors existe déjà, ord=position garanti par la jointure) -> no-op, zéro
-- doublon. La branche DELETE du trigger ne se déclenche pas (OLD.author_id NULL).
--
-- Idempotent (WHERE author_id IS NULL). Correspondances ambiguës (>1 autorité
-- candidate sur le même livre) EXCLUES (having count distinct = 1) -> revue
-- manuelle. Vérifié en begin/rollback sur prod : 1243 contributeurs réconciliés,
-- 0 risque de doublon.
-- Session : Doublons d'autorité & i18n erreurs catalogue
-- ----------------------------------------------------------------------------

update public.book_contributors bc
set author_id = m.author_id
from (
  select bc2.id as bc_id, min(ba.author_id) as author_id
  from public.book_contributors bc2
  join public.book_authors ba
    on ba.book_id = bc2.book_id and ba.role = bc2.role and ba.ord = bc2.position
  join public.authors a on a.id = ba.author_id
  where bc2.author_id is null
    and public.fn_normalize_name(a.preferred_name) = public.fn_normalize_name(bc2.name)
  group by bc2.id
  having count(distinct ba.author_id) = 1
) m
where bc.id = m.bc_id and bc.author_id is null;
