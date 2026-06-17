-- =========================================================================
-- publish_book_draft — copier gravadora (maison de disques) au PUBLISH
-- =========================================================================
-- Date     : 2026-06-17
-- Chantier : Catalogação / cohérence supports non écrits (#CAT-EDITEUR-AV-AUDIO)
-- Auteur   : Xavier + Claude
-- Session  : File éditoriale — tri & supports AV
--
-- OBJET
-- -----
-- Suite de 20260617123948 (colonne gravadora). Ajoute la copie de gravadora
-- draft → books dans publish_book_draft, aux 3 emplacements où figure
-- distribuidora (INSERT, VALUES, UPDATE).
--
-- MÉTHODE
-- -------
-- Patch IDEMPOTENT par réécriture : on relit la définition courante de la
-- fonction (pg_get_functiondef), on insère gravadora à côté de distribuidora
-- (3 substrings uniques), et on recrée la fonction. Évite de retranscrire
-- ~150 lignes (risque d'erreur) et garde les GRANT existants (CREATE OR
-- REPLACE les préserve). Le garde sur 'v_draft.gravadora' rend le rejeu sûr.
-- Le CREATE OR REPLACE valide la cohérence INSERT/VALUES (check_function_bodies).
-- =========================================================================

begin;

do $patch$
declare d text;
begin
  select pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure) into d;
  if position('v_draft.gravadora' in d) = 0 then
    d := replace(d, 'distribuidora, tese_university, tese_advisor,', 'distribuidora, gravadora, tese_university, tese_advisor,');
    d := replace(d, 'v_draft.distribuidora, v_draft.tese_university, v_draft.tese_advisor,', 'v_draft.distribuidora, v_draft.gravadora, v_draft.tese_university, v_draft.tese_advisor,');
    d := replace(d, 'distribuidora = v_draft.distribuidora,', 'distribuidora = v_draft.distribuidora, gravadora = v_draft.gravadora,');
    execute d;
    raise notice 'publish_book_draft : gravadora ajoutée';
  else
    raise notice 'publish_book_draft : gravadora déjà présente (no-op)';
  end if;
end
$patch$;

notify pgrst, 'reload schema';

commit;
