-- ============================================================================
-- 20260522100000_peb_logistics_mode.sql
-- ----------------------------------------------------------------------------
-- Chantier #ILL-logistics — logistics_mode devient une enumeration.
--
-- PROBLEME
--   interlibrary_loans_v2.logistics_mode est un texte libre. Le frontend
--   ecrivait la valeur 'a_combinar' en dur pour tous les PEB : aucun choix
--   reel n'etait offert.
--
-- CORRECTIF
--   Un CHECK contraint logistics_mode a quatre valeurs, correspondant aux
--   manieres concretes dont des documents circulent entre collectifs anars :
--     - envio_postal        : envoi postal, tout service confondu
--     - entrega_em_maos     : remise en main propre (rendez-vous local)
--     - transporte_militante: portage militant — un·e camarade emporte les
--                             documents a l'occasion d'un voyage, d'une
--                             rencontre, d'un salon du livre
--     - a_combinar          : a convenir (egalement valeur legacy : les 9
--                             PEB existants la portent tous)
--
--   Le frontend proposera les quatre a la creation. 'a_combinar' reste un
--   choix honnete (« on en discute ») autant qu'une valeur historique.
--
-- PREALABLE VERIFIE
--   Les 9 PEB existants ont tous logistics_mode = 'a_combinar' (verifie le
--   22/05/2026), valeur incluse dans le CHECK : le ADD CONSTRAINT ne peut
--   pas echouer sur l'existant.
--
-- NOTE
--   Le champ logistics_mode peut etre NULL (PEB anciens, ou non renseigne).
--   Le CHECK tolere NULL (un CHECK ne rejette pas NULL par defaut). Le
--   caractere obligatoire du choix est porte cote frontend (saveIll).
--
-- VERIFICATION
--   Bloc DO : le CHECK est present et accepte les 4 valeurs.
-- ============================================================================

ALTER TABLE public.interlibrary_loans_v2
  DROP CONSTRAINT IF EXISTS interlibrary_loans_v2_logistics_mode_chk;

ALTER TABLE public.interlibrary_loans_v2
  ADD CONSTRAINT interlibrary_loans_v2_logistics_mode_chk
  CHECK (logistics_mode IS NULL OR logistics_mode IN (
    'envio_postal',
    'entrega_em_maos',
    'transporte_militante',
    'a_combinar'
  ));


-- ============================================================================
-- VERIFICATION POST-MIGRATION
-- ============================================================================
DO $verif$
declare
  v_def text;
begin
  select pg_get_constraintdef(con.oid) into v_def
  from pg_constraint con
  join pg_class c on c.oid = con.conrelid
  where c.relname = 'interlibrary_loans_v2'
    and con.conname = 'interlibrary_loans_v2_logistics_mode_chk';

  if v_def is null then
    raise exception 'Verification echouee : CHECK logistics_mode absent.';
  end if;
  -- Les quatre valeurs doivent figurer dans la definition du CHECK.
  if position('envio_postal' in v_def) = 0
     or position('entrega_em_maos' in v_def) = 0
     or position('transporte_militante' in v_def) = 0
     or position('a_combinar' in v_def) = 0 then
    raise exception 'Verification echouee : le CHECK logistics_mode ne couvre pas les 4 modes.';
  end if;

  raise notice 'Migration 20260522100000 : verification OK (CHECK logistics_mode, 4 modes).';
end;
$verif$;
