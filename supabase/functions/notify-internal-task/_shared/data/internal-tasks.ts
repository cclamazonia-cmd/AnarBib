import { supabaseAdmin } from "../core/env.ts";
export async function fetchInternalTask(taskId) {
  const { data, error } = await supabaseAdmin.from("painel_internal_tasks").select("id,title,description,priority,status,owner,owner_user_id,due_date,tags,created_at,library_id,title_i18n,description_i18n").eq("id", taskId).maybeSingle();
  if (error) throw new Error(`internal_task_fetch_failed: ${error.message}`);
  return data || null;
}
export async function fetchInternalTaskOwnerProfile(ownerEmail) {
  const { data, error } = await supabaseAdmin.from("profiles").select("id,email,is_librarian,first_name,last_name,preferred_language").ilike("email", ownerEmail).maybeSingle();
  if (error && error.code !== "PGRST116") {
    throw new Error(`internal_task_owner_profile_failed: ${error.message}`);
  }
  return data || null;
}
