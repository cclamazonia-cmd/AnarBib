-- generate_public_id() n'a jamais pu s'executer : bug de search_path.
--
-- La fonction appelle gen_random_bytes() avec `SET search_path TO 'public',
-- 'pg_temp'`, or pgcrypto est installe dans le schema `extensions` (convention
-- Supabase). Tout appel echouait donc en « function gen_random_bytes(integer)
-- does not exist ».
--
-- Le defaut est passe inapercu parce que le trigger trg_set_public_id
-- (BEFORE INSERT) ne genere que si public_id est NULL, et que les comptes
-- reels arrivent avec un public_id deja rempli. C'est aussi ce qui explique
-- que les identifiants en base soient de la forme U + numero (sequentiels,
-- donc enumerables — cf. 20260817032913) au lieu des 20 caracteres hex
-- aleatoires que cette fonction etait censee produire.
--
-- Constate le 2026-08-17 en tentant la regeneration des identifiants : les 13
-- tentatives ont echoue, aucun e-mail n'est parti (le code s'arrete avant
-- l'envoi si la generation echoue).
--
-- Correctif : `extensions` ajoute au search_path ET appel pleinement qualifie.
-- Semantique inchangee (10 octets -> 20 hex, boucle d'unicite). Reste en
-- SECURITY INVOKER comme avant.

create or replace function public.generate_public_id()
returns text
language plpgsql
set search_path to 'public', 'extensions', 'pg_temp'
as $$
declare
  v_id text;
begin
  loop
    -- 10 octets = 20 caracteres hex
    v_id := lower(encode(extensions.gen_random_bytes(10), 'hex'));
    exit when not exists (
      select 1 from public.profiles where public_id = v_id
    );
  end loop;
  return v_id;
end;
$$;

comment on function public.generate_public_id() is
  'Genere un public_id aleatoire (20 hex) non devinable, unique dans profiles. Appel pleinement qualifie vers extensions.gen_random_bytes : pgcrypto n''est pas dans le search_path public.';
