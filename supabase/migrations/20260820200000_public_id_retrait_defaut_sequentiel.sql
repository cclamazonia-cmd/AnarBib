-- =============================================================================
-- public_id — retrait du défaut séquentiel (la vraie cause)
-- =============================================================================
-- Suite de 20260817032913 (fuite d'annuaire) et 20260817123058 (generate_public_id
-- réparée). Ces deux migrations ont réparé le générateur et régénéré les 13
-- identifiants existants — mais **les nouveaux comptes repartaient en U000xxx**.
-- Constaté le 19/08 sur une inscription d'essai : U000783.
--
-- POURQUOI LE CORRECTIF DU 17/08 N'A RIEN CHANGÉ POUR LES NOUVEAUX COMPTES.
--
-- La colonne portait encore un DEFAULT :
--
--   'U' || lpad(nextval('profiles_public_id_seq')::text, 6, '0')
--
-- Or **un DEFAULT de colonne est appliqué AVANT que le trigger BEFORE INSERT
-- ne voie la ligne.** Quand trg_set_public_id s'exécute, new.public_id n'est
-- donc jamais NULL — sa condition `if new.public_id is null` n'a jamais pu être
-- vraie une seule fois depuis la création de la table. Le trigger était là,
-- actif, et mort.
--
-- C'est le piège classique : on répare la fonction, on vérifie que le trigger
-- est bien attaché et activé, tout a l'air correct — et rien ne se produit,
-- parce que le défaut a déjà tranché.
--
-- Conséquence de sécurité, la même qu'au 17/08 : un identifiant séquentiel
-- s'énumère. U000783 dit combien de comptes existent, et U000782 en désigne un
-- autre. C'est exactement ce que la régénération du 17/08 visait à supprimer.
--
-- TROIS GESTES, DANS CET ORDRE
--   1. retirer le défaut — sans quoi le reste est décoratif ;
--   2. supprimer la séquence, pour qu'aucun code futur ne puisse la rebrancher
--      par distraction (vérifié : plus aucune autre référence en base) ;
--   3. rendre le trigger autoritaire plutôt que conditionnel — il génère
--      désormais dès que la valeur n'est pas un identifiant conforme, au lieu
--      de se contenter du cas NULL. Si un défaut réapparaissait un jour, il
--      serait écrasé au lieu de passer.
-- =============================================================================

begin;

-- 1 ---------------------------------------------------------------------------
alter table public.profiles alter column public_id drop default;

-- 2 ---------------------------------------------------------------------------
-- La séquence n'est plus référencée nulle part une fois le défaut retiré
-- (contrôlé le 19/08 : aucun autre défaut de colonne, aucun corps de fonction).
drop sequence if exists public.profiles_public_id_seq;

-- 3 ---------------------------------------------------------------------------
-- Règle positive : on garde la valeur fournie SI ET SEULEMENT SI elle a la forme
-- attendue (20 caractères hexadécimaux). Tout le reste — NULL, U000xxx, valeur
-- fantaisiste — est régénéré. Ne concerne que les INSERT : les identifiants
-- existants ne bougent pas.
create or replace function public.set_public_id()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $$
begin
  if new.public_id is null or new.public_id !~ '^[0-9a-f]{20}$' then
    new.public_id := public.generate_public_id();
  end if;
  return new;
end;
$$;

comment on function public.set_public_id() is
  'Impose un public_id aléatoire (20 hex) à l''insertion. Règle positive : la '
  'valeur fournie n''est conservée que si elle est déjà conforme. Remplace la '
  'condition « si NULL », qui n''a jamais pu être vraie tant que la colonne '
  'portait un DEFAULT séquentiel — cf. 20260820200000.';

-- 4 — identifiant résiduel du compte anonymisé -------------------------------
-- removido@anarbib.local n'a personne à prévenir : on le régénère ici.
-- Les autres identifiants séquentiels restants, s'il y en a, appartiennent à
-- des personnes qu'il faut avertir avant de changer leur numéro : ils sont
-- traités à part, pas dans une migration.
update public.profiles
   set public_id = public.generate_public_id()
 where email = 'removido@anarbib.local'
   and public_id ~ '^U[0-9]{6}$';

commit;

-- =============================================================================
-- CONTRÔLE APRÈS DÉPLOIEMENT
-- =============================================================================
-- Le défaut doit avoir disparu :
--
--   select column_default from information_schema.columns
--    where table_schema='public' and table_name='profiles' and column_name='public_id';
--   -- attendu : NULL
--
-- Et il ne doit plus rester d'identifiant séquentiel, hors décision explicite :
--
--   select public_id, email from public.profiles where public_id ~ '^U[0-9]{6}$';
--
-- Le vrai contrôle reste une inscription d'essai : le numéro affiché à la fin
-- du formulaire doit être 20 caractères hexadécimaux, pas U000xxx.
