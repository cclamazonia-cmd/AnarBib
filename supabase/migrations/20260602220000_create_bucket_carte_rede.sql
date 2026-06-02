-- Migration : bucket prive pour la carte reseau detaillee (chantier carte).
-- Regime d'acces : lecture par tout membre authentifie ; ecriture hors client (service_role / CI).
-- Deploiement : git push -> Woodpecker -> supabase db push --linked. Ne pas appliquer a la main.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('anarbib-carte-rede', 'anarbib-carte-rede', false, 5242880,
        array['application/json', 'application/geo+json'])
on conflict (id) do nothing;

drop policy if exists "carte_rede_authenticated_select" on storage.objects;
create policy "carte_rede_authenticated_select"
  on storage.objects for select to authenticated
  using (bucket_id = 'anarbib-carte-rede');

-- Verification structurelle (RAISE EXCEPTION -> rollback de la transaction de migration).
do $$
begin
  if not exists (select 1 from storage.buckets
                 where id = 'anarbib-carte-rede' and public = false) then
    raise exception 'bucket anarbib-carte-rede manquant ou non prive';
  end if;
  if not exists (select 1 from pg_policies
                 where schemaname = 'storage' and tablename = 'objects'
                   and policyname = 'carte_rede_authenticated_select') then
    raise exception 'policy carte_rede_authenticated_select manquante';
  end if;
end $$;
