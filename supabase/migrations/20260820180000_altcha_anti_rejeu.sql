-- =============================================================================
-- Altcha — anti-rejeu des défis (AR-4)
-- =============================================================================
-- Cf. docs/journal/arbitrages/DECISION_anti_robots_2026-08-20.md
--
-- POURQUOI CETTE TABLE EST UNE CONDITION DE MISE EN SERVICE, PAS UN CONFORT.
--
-- Un défi Altcha est SANS ÉTAT : le serveur l'émet signé en HMAC, le navigateur
-- le résout, le serveur vérifie la signature et la solution. Rien n'est stocké.
-- C'est élégant, et c'est aussi le trou : **une solution valide reste valide**
-- jusqu'à expiration du défi. Un attaquant résout UN défi, puis rejoue le même
-- couple (défi, solution) autant de fois qu'il veut dans la fenêtre.
--
-- Sans cette table, la preuve de travail coûte une fois et rapporte mille fois.
-- Autrement dit : elle ne coûte rien.
--
-- On enregistre donc chaque défi CONSOMMÉ. L'insertion est le contrôle : si la
-- ligne existe déjà, c'est un rejeu. `on conflict do nothing` rend l'opération
-- atomique — deux requêtes simultanées avec le même défi ne peuvent pas passer
-- toutes les deux, ce qu'un « select puis insert » ne garantirait pas.
-- =============================================================================

begin;

create table if not exists public.altcha_consumed_challenges (
  challenge   text        primary key,
  consumed_at timestamptz not null default now(),
  expires_at  timestamptz not null,
  purpose     text        not null check (purpose in ('register', 'cartography'))
);

comment on table public.altcha_consumed_challenges is
  'Défis Altcha déjà consommés. L''unicité de la clé primaire EST le contrôle '
  'anti-rejeu : sans elle, une preuve de travail résolue une fois se rejoue '
  'indéfiniment jusqu''à expiration. Cf. DECISION_anti_robots_2026-08-20 (AR-4).';

create index if not exists altcha_consumed_expires_idx
  on public.altcha_consumed_challenges (expires_at);

-- RLS : personne ne lit, personne n'écrit directement. Seule la fonction
-- ci-dessous touche cette table, et elle est en SECURITY DEFINER.
alter table public.altcha_consumed_challenges enable row level security;

revoke all on table public.altcha_consumed_challenges from public, anon, authenticated;
grant select, insert, delete on table public.altcha_consumed_challenges to service_role;

-- -----------------------------------------------------------------------------
-- Consommation atomique
-- -----------------------------------------------------------------------------
-- Renvoie TRUE si le défi est neuf (et le marque consommé), FALSE si c'est un
-- rejeu. Le nettoyage des défis périmés est fait ici, à l'occasion : pas besoin
-- d'un job cron pour une table qui ne dépassera jamais quelques milliers de
-- lignes, et ça garantit qu'elle est purgée même si personne ne surveille.
create or replace function public.fn_consume_altcha_challenge(
  p_challenge  text,
  p_expires_at timestamptz,
  p_purpose    text
) returns boolean
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_insere boolean;
begin
  if p_purpose not in ('register', 'cartography') then
    raise exception 'usage inconnu : %', p_purpose using errcode = '22023';
  end if;

  -- Un défi déjà périmé n'a pas à être accepté, même s'il est neuf.
  if p_expires_at <= now() then
    return false;
  end if;

  insert into public.altcha_consumed_challenges (challenge, expires_at, purpose)
  values (p_challenge, p_expires_at, p_purpose)
  on conflict (challenge) do nothing
  returning true into v_insere;

  -- Purge opportuniste : une ligne périmée ne sert plus à rien, puisqu'un défi
  -- périmé est de toute façon refusé plus haut.
  delete from public.altcha_consumed_challenges where expires_at < now() - interval '1 hour';

  return coalesce(v_insere, false);
end;
$$;

comment on function public.fn_consume_altcha_challenge(text, timestamptz, text) is
  'Marque un défi Altcha comme consommé. TRUE = premier usage, FALSE = rejeu ou '
  'défi périmé. Atomique par la clé primaire : deux appels concurrents sur le '
  'même défi ne peuvent pas réussir tous les deux.';

revoke execute on function public.fn_consume_altcha_challenge(text, timestamptz, text)
  from public, anon, authenticated;

commit;

-- =============================================================================
-- CONTRÔLE APRÈS DÉPLOIEMENT
-- =============================================================================
-- Le rejeu doit échouer au deuxième appel :
--
--   select public.fn_consume_altcha_challenge('essai-abc', now() + interval '5 min', 'register');
--   -- attendu : true
--   select public.fn_consume_altcha_challenge('essai-abc', now() + interval '5 min', 'register');
--   -- attendu : false   ← c'est TOUT l'intérêt de la table
--
-- Et un défi déjà périmé doit être refusé même neuf :
--
--   select public.fn_consume_altcha_challenge('essai-vieux', now() - interval '1 min', 'register');
--   -- attendu : false
--
--   delete from public.altcha_consumed_challenges where challenge like 'essai-%';
