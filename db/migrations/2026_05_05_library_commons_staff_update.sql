-- ═══════════════════════════════════════════════════════════════════════════
-- Migration : politique RLS UPDATE manquante sur library_commons
-- Date     : 2026-05-05
-- ═══════════════════════════════════════════════════════════════════════════
--
-- CONTEXTE
-- --------
-- La table `library_commons` (identité publique de chaque bibliothèque :
-- nom, logo, contact mail, mode delivery, etc.) avait RLS activée mais
-- UNIQUEMENT une policy SELECT (`library_commons_public_read`).
--
-- Conséquence : aucune écriture possible via REST API. Les libraires ne
-- pouvaient pas modifier l'identité de leur biblio depuis l'UI ; seule
-- la fonction SECURITY DEFINER `fn_activate_approved_library_request`
-- pouvait écrire.
--
-- DÉCISION
-- --------
-- On ajoute une policy UPDATE alignée sur la policy `libraries_staff_update`
-- de la table `libraries`. Permissions identiques :
--   - rôles autorisés : librarian, coordenador, administrador
--   - membership actif sur la library_id ciblée
--   - profil utilisateur·rice non restreint
--
-- On utilise le helper `user_has_library_staff_role(p_user_id, p_library_id)`
-- pour rester DRY (helper créé le 04/05).
--
-- Volontairement PAS de policy INSERT/DELETE :
--   - INSERT → doit passer par fn_activate_approved_library_request
--     (workflow d'activation administratif)
--   - DELETE → idem, doit passer par un workflow de fermeture (à définir)
--
-- ═══════════════════════════════════════════════════════════════════════════

-- Drop de sécurité (idempotent, au cas où une version antérieure existerait)
drop policy if exists library_commons_staff_update on public.library_commons;

-- Création de la policy UPDATE
create policy library_commons_staff_update
  on public.library_commons
  for update
  to authenticated
  using (
    public.user_has_library_staff_role(auth.uid(), library_commons.library_id)
    and not coalesce(
      (select profiles.is_restricted from public.profiles where profiles.id = auth.uid()),
      false
    )
  )
  with check (
    public.user_has_library_staff_role(auth.uid(), library_commons.library_id)
    and not coalesce(
      (select profiles.is_restricted from public.profiles where profiles.id = auth.uid()),
      false
    )
  );

comment on policy library_commons_staff_update on public.library_commons is
  'Permet aux libraires (librarian/coordenador/administrador) de modifier l''identité publique '
  'de leur bibliothèque (nom, logo, contact, mode email, etc.). '
  'Aligne sur libraries_staff_update. Ajoutée 2026-05-05.';

-- ═══════════════════════════════════════════════════════════════════════════
-- VÉRIFICATION POST-MIGRATION
-- ═══════════════════════════════════════════════════════════════════════════
-- Lancer ces 2 requêtes pour vérifier le résultat :
--
-- 1. La policy a bien été créée :
--   select polname, polcmd, polroles::regrole[]
--   from pg_policy
--   where polrelid = 'public.library_commons'::regclass
--   order by polname;
--
-- 2. Test fonctionnel : se connecter avec un compte librarian et tenter
--    une UPDATE. Avant migration : refusé silencieusement (0 rows updated).
--    Après migration : OK pour les staff de la biblio cible.
