-- supabase/migrations/20260617043337_publib_public_optin.sql
-- Session : Gazette Rizoma & Lettre federation
-- Chantier PUBLIB (REGISTRE §31) — Phase 2 : opt-in NIVEAU 2 + vues publiques gated.
--
-- PUBLIB-OPTIN-1 : drapeau dédié PAR SECTION, défaut false (« trouvable ≠ horaires
--   publics »). Niveau 1 (apparaître à l'annuaire) = libraries.visibility_level='public'
--   (déjà en place). Niveau 2 (données sensibles) = library_public_contact.is_public
--   + library_opening_hours.is_public.
-- PUBLIB-OPTIN-2 : bascule = coordenador (user_can_manage_library), via RPC.
-- Lecture anon des SEULES lignes opt-in d'une biblio active+publique (policies
--   additives aux policies membre existantes ; RLS = OR). Évolution assumée de
--   MYLIB-2 (« pas de lecture anon ») : ouverte UNIQUEMENT aux lignes is_public.
-- Vues api security_invoker=true (cohérent api.public_libraries) → les policies
--   anol ci-dessous gating les lignes. DOC-OBJ-2 / DOC-RPC-3. Idempotent.
--
-- ⚠️ Horodatage à RE-VÉRIFIER à l'intégration worktree (> max réel ; sessions
--    parallèles actives). ⚠️ Gating ANON à vérifier APRÈS apply (en tant qu'anon :
--    BEGIN/ROLLBACK via MCP teste la validité DDL, PAS le comportement RLS anon).

-- ── 1. Drapeaux opt-in niveau 2 (défaut OFF) ────────────────────────────────
alter table public.library_public_contact add column if not exists is_public boolean not null default false;
alter table public.library_opening_hours  add column if not exists is_public boolean not null default false;
comment on column public.library_public_contact.is_public is 'PUBLIB-OPTIN-1 : opt-in niveau 2, expose le contact à l''anon (fiche publique). Défaut false.';
comment on column public.library_opening_hours.is_public  is 'PUBLIB-OPTIN-1 : opt-in niveau 2, expose les horaires à l''anon (fiche publique). Défaut false.';

-- ── 2. Lecture ANON des lignes opt-in d'une biblio active + publique ────────
--     (s'ajoute aux policies membre ; ne les restreint pas — RLS = OR.)
grant select on public.library_public_contact to anon;
grant select on public.library_opening_hours  to anon;

drop policy if exists library_public_contact_read_optin on public.library_public_contact;
create policy library_public_contact_read_optin on public.library_public_contact
  for select to anon, authenticated
  using (
    is_public = true
    and exists (
      select 1 from public.libraries l
      where l.id = library_public_contact.library_id
        and l.is_active = true and l.visibility_level = 'public'
    )
  );

drop policy if exists library_opening_hours_read_optin on public.library_opening_hours;
create policy library_opening_hours_read_optin on public.library_opening_hours
  for select to anon, authenticated
  using (
    is_public = true
    and exists (
      select 1 from public.libraries l
      where l.id = library_opening_hours.library_id
        and l.is_active = true and l.visibility_level = 'public'
    )
  );

-- ── 3. Vues publiques gated (security_invoker → policies anon ci-dessus) ─────
create or replace view api.library_contact_public_v1
with (security_invoker = true) as
  select l.slug, c.public_email, c.public_phone, c.public_whatsapp, c.public_address, c.public_note
  from public.library_public_contact c
  join public.libraries l on l.id = c.library_id
  where c.is_public = true and l.is_active = true and l.visibility_level = 'public';
comment on view api.library_contact_public_v1 is 'Contact public d''une biblio (opt-in niveau 2 PUBLIB). Anon : seules les lignes is_public d''une biblio publique active.';
grant select on api.library_contact_public_v1 to anon, authenticated;

create or replace view api.library_opening_hours_public_v1
with (security_invoker = true) as
  select l.slug, h.slots, h.public_note
  from public.library_opening_hours h
  join public.libraries l on l.id = h.library_id
  where h.is_public = true and l.is_active = true and l.visibility_level = 'public';
comment on view api.library_opening_hours_public_v1 is 'Horaires publics d''une biblio (opt-in niveau 2 PUBLIB). slots = [{day 1..7, start, end, label?}]. Anon : seules les lignes is_public d''une biblio publique active.';
grant select on api.library_opening_hours_public_v1 to anon, authenticated;

-- ── 4. RPC toggles coordenador (PUBLIB-OPTIN-2) ─────────────────────────────
create or replace function api.fn_set_library_contact_public(p_library_id uuid, p_is_public boolean)
returns void
language plpgsql
security definer
set search_path = public, api, pg_temp
as $$
begin
  if not public.user_can_manage_library(p_library_id) then
    raise exception 'forbidden: coordenador only' using errcode = '42501';
  end if;
  update public.library_public_contact set is_public = coalesce(p_is_public, false) where library_id = p_library_id;
  if not found then
    insert into public.library_public_contact (library_id, is_public) values (p_library_id, coalesce(p_is_public, false));
  end if;
end;
$$;
revoke all on function api.fn_set_library_contact_public(uuid, boolean) from public, anon, service_role;
grant execute on function api.fn_set_library_contact_public(uuid, boolean) to authenticated;

create or replace function api.fn_set_library_hours_public(p_library_id uuid, p_is_public boolean)
returns void
language plpgsql
security definer
set search_path = public, api, pg_temp
as $$
begin
  if not public.user_can_manage_library(p_library_id) then
    raise exception 'forbidden: coordenador only' using errcode = '42501';
  end if;
  update public.library_opening_hours set is_public = coalesce(p_is_public, false) where library_id = p_library_id;
  if not found then
    insert into public.library_opening_hours (library_id, is_public) values (p_library_id, coalesce(p_is_public, false));
  end if;
end;
$$;
revoke all on function api.fn_set_library_hours_public(uuid, boolean) from public, anon, service_role;
grant execute on function api.fn_set_library_hours_public(uuid, boolean) to authenticated;

notify pgrst, 'reload schema';
