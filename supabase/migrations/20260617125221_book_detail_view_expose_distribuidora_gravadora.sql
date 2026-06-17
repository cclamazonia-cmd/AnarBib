-- =========================================================================
-- v_book_detail_public_v2 — exposer distribuidora + gravadora (fiche détail)
-- =========================================================================
-- Date     : 2026-06-17
-- Chantier : Catalogação / cohérence supports non écrits (#CAT-EDITEUR-AV-AUDIO)
-- Auteur   : Xavier + Claude
-- Session  : File éditoriale — tri & supports AV
--
-- OBJET
-- -----
-- La fiche détail publique (BookPage) lit v_book_detail_public_v2, qui exposait
-- editora + tipo_material mais ni distribuidora ni gravadora. Pour afficher le
-- libellé adapté au support (distributeur / maison de disques), on ajoute ces
-- deux colonnes (append en fin de SELECT — CREATE OR REPLACE VIEW l'autorise).
--
-- MÉTHODE
-- -------
-- Patch IDEMPOTENT par réécriture : relit la définition courante (pg_get_viewdef),
-- append b.distribuidora + b.gravadora avant le FROM de l'outer SELECT, recrée la
-- vue en PRÉSERVANT security_invoker=true. Garde sur la présence de gravadora.
-- =========================================================================

begin;

do $patch$
declare q text;
begin
  if (select count(*) from information_schema.columns
        where table_schema='public' and table_name='v_book_detail_public_v2'
          and column_name='gravadora') = 0 then
    select pg_get_viewdef('public.v_book_detail_public_v2'::regclass, true) into q;
    q := replace(q,
      E'edb.earliest_due_back_at\n   FROM books b',
      E'edb.earliest_due_back_at,\n    b.distribuidora,\n    b.gravadora\n   FROM books b');
    execute 'create or replace view public.v_book_detail_public_v2 with (security_invoker=true) as ' || q;
    raise notice 'v_book_detail_public_v2 : distribuidora + gravadora ajoutées';
  else
    raise notice 'v_book_detail_public_v2 : gravadora déjà exposée (no-op)';
  end if;
end
$patch$;

notify pgrst, 'reload schema';

commit;
