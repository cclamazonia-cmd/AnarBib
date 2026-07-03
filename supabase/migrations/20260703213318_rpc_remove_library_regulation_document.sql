-- Retrait d'un règlement périmé (chantier « bouton supprimer règlement », 2026-07-03).
-- Archivage réversible par défaut (archived_at) ; suppression dure réservée aux
-- brouillons jamais publiés et non référencés. Gardé coordenador/librarian.
-- Ne touche JAMAIS le règlement actif ni un doc référencé par un jeu de circulation.
create or replace function public.remove_library_regulation_document(p_document_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to 'public','auth','pg_temp'
as $function$
declare
  v_doc public.library_regulation_documents%rowtype;
  v_referenced boolean;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into v_doc
  from public.library_regulation_documents d
  where d.id = p_document_id;

  if v_doc.id is null then
    raise exception 'Documento institucional não encontrado: %', p_document_id;
  end if;

  if not public.can_manage_library_regulation_documents(v_doc.library_id) then
    raise exception 'permission denied for library_regulation_documents';
  end if;

  -- Garde 1 : jamais le règlement actif (il faut d'abord en activer un autre).
  if coalesce(v_doc.is_active, false) then
    raise exception 'error.regulation.active_cannot_remove' using errcode = 'check_violation';
  end if;

  -- Idempotent : déjà archivé.
  if v_doc.archived_at is not null then
    return jsonb_build_object('action', 'already_archived', 'document_id', v_doc.id);
  end if;

  select exists (
    select 1 from public.library_circulation_policy_sets s
    where s.regulation_document_id = v_doc.id
  ) into v_referenced;

  -- Suppression dure : uniquement un brouillon jamais publié ET non référencé.
  if v_doc.publication_status = 'draft_only' and not v_referenced then
    delete from public.library_regulation_documents d where d.id = v_doc.id;
    return jsonb_build_object(
      'action', 'deleted',
      'document_id', v_doc.id,
      'storage_bucket', v_doc.storage_bucket,
      'storage_paths',
        case when v_doc.storage_path_draft is not null
             then jsonb_build_array(v_doc.storage_path_draft)
             else '[]'::jsonb end
    );
  end if;

  -- Sinon : archivage réversible (garde la ligne → FK intacte, mémoire préservée).
  update public.library_regulation_documents d
     set archived_at = now(), updated_at = now(), updated_by = auth.uid()
   where d.id = v_doc.id;

  return jsonb_build_object('action', 'archived', 'document_id', v_doc.id);
end;
$function$;

revoke all on function public.remove_library_regulation_document(bigint) from public;
grant execute on function public.remove_library_regulation_document(bigint) to authenticated;
