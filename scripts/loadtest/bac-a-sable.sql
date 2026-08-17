-- ===========================================================================
-- bac-a-sable.sql — bibliothèque jetable + comptes de test pour le harnais de
-- charge (scripts/loadtest/anarbib-loadtest.mjs).
-- ---------------------------------------------------------------------------
-- Il n'existe qu'UN SEUL projet Supabase : les tests de charge tapent donc sur
-- l'environnement réel, avec de vraies données. D'où ce bac à sable :
--   * une bibliothèque privée / isolée / catalogue local, sans entrée dans la
--     cartographie -> invisible des trois surfaces publiques (inscription,
--     catalogue réseau, carte) ;
--   * des comptes dédiés en @loadtest.invalid (TLD réservé, non délivrable) ;
--   * toutes les écritures du harnais y sont confinées.
--
-- ⚠ NE JAMAIS inclure dans le volume les chemins qui déclenchent des e-mails
-- (réservations, consultations : triggers pg_net -> notify-event -> Resend).
-- Le harnais écrit dans user_wishlist et book_drafts, qui n'ont aucun trigger
-- de notification. Vérifier avant d'ajouter une opération d'écriture.
--
-- Usage :
--   1. Exécuter la PARTIE 1, noter l'UUID renvoyé.
--   2. node scripts/loadtest/anarbib-loadtest.mjs --lib=<UUID> --vu=40 ...
--   3. Exécuter la PARTIE 2 et vérifier que les compteurs sont revenus à
--      l'identique.
-- ===========================================================================

-- ─────────────────────────── PARTIE 1 : création ──────────────────────────
do $$
declare v_lib uuid; v_uid uuid; v_email text; i int;
        v_pwd text := 'LoadTest!2026-Bologna';
begin
  insert into public.libraries (
    slug, name, short_name, city, country, is_active, visibility_level,
    network_mode, catalog_mode, accepts_public_signup, membership_enabled,
    default_locale, admin_notes)
  values (
    'zzz-charge-test', 'ZZZ Charge Test (jetable)', 'ZZZCT', 'Nulle-part', 'Brasil',
    true, 'private', 'isolated', 'local_only', false, false, 'fr',
    'Bac a sable du harnais de charge - A SUPPRIMER apres usage')
  returning id into v_lib;

  for i in 1..30 loop
    v_uid := gen_random_uuid();
    v_email := format('loadtest-%s@loadtest.invalid', lpad(i::text, 2, '0'));

    -- Les 8 colonnes de tokens DOIVENT être à '' et jamais NULL, sinon GoTrue
    -- renvoie 500 sur signInWithPassword (erreur de désérialisation).
    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change, email_change_token_new,
      email_change_token_current, phone_change, phone_change_token, reauthentication_token)
    values (
      v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      v_email, extensions.crypt(v_pwd, extensions.gen_salt('bf', 10)), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('first_name','Charge','last_name','Test'||i,'preferred_language','fr'),
      now(), now(), '', '', '', '', '', '', '', '');

    insert into auth.identities (
      id, user_id, provider, provider_id, identity_data, created_at, updated_at, last_sign_in_at)
    values (
      gen_random_uuid(), v_uid, 'email', v_uid::text,
      jsonb_build_object('sub', v_uid::text, 'email', v_email, 'email_verified', true),
      now(), now(), now());

    -- 6 catalogueurs (écritures book_drafts) + 24 lecteurs.
    insert into public.user_library_memberships (user_id, library_id, role, status, is_primary)
    values (v_uid, v_lib, case when i <= 6 then 'librarian' else 'reader' end, 'active', true);
  end loop;
end $$;

-- L'UUID à passer au harnais via --lib=
select id as library_id_a_passer_au_harnais
from public.libraries where slug = 'zzz-charge-test';

-- Contrôle : la biblio ne doit apparaître sur AUCUNE surface publique.
select
  (select count(*) from public.v_libraries_for_signup where slug='zzz-charge-test') as fuite_inscription,
  (select count(*) from api.public_libraries      where slug='zzz-charge-test') as fuite_catalogue,
  (select count(*) from public.cartography_entries c join public.libraries l on l.id=c.library_id
    where l.slug='zzz-charge-test') as fuite_carte;

-- ─────────────────────────── PARTIE 2 : purge ─────────────────────────────
-- À exécuter APRÈS les tests. Comparer les compteurs à ceux relevés avant.
/*
do $$
declare v_lib uuid; v_users uuid[];
begin
  select id into v_lib from public.libraries where slug = 'zzz-charge-test';
  select array_agg(id) into v_users from auth.users where email like 'loadtest-%@loadtest.invalid';
  if v_lib is null then raise exception 'biblio de test introuvable'; end if;

  delete from public.book_drafts where owner_library_id = v_lib or holder_library_id = v_lib;
  delete from public.user_wishlist where user_id = any(v_users);
  delete from public.user_library_memberships where library_id = v_lib or user_id = any(v_users);
  delete from public.profiles where id = any(v_users);
  delete from auth.identities where user_id = any(v_users);
  delete from auth.users where id = any(v_users);
  delete from public.libraries where id = v_lib;
end $$;

select
  (select count(*) from public.libraries) as libraries,
  (select count(*) from auth.users) as users,
  (select count(*) from public.user_library_memberships) as memberships,
  (select count(*) from public.book_drafts) as book_drafts,
  (select count(*) from public.user_wishlist) as wishlist,
  (select count(*) from public.profiles) as profiles;
*/
