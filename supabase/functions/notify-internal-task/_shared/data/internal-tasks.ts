import { supabaseAdmin } from "../core/env.ts";
export async function fetchInternalTask(taskId) {
  const { data, error } = await supabaseAdmin.from("painel_internal_tasks").select("id,title,description,priority,status,owner,owner_user_id,due_date,tags,created_at,library_id").eq("id", taskId).maybeSingle();
  if (error) throw new Error(`internal_task_fetch_failed: ${error.message}`);
  return data || null;
}
export async function fetchInternalTaskOwnerProfile(ownerEmail) {
  const { data, error } = await supabaseAdmin.from("profiles").select("id,email,is_librarian,first_name,last_name").ilike("email", ownerEmail).maybeSingle();
  if (error && error.code !== "PGRST116") {
    throw new Error(`internal_task_owner_profile_failed: ${error.message}`);
  }
  return data || null;
}
export async function claimInternalTaskNotificationBatch(limit) {
  const { data, error } = await supabaseAdmin.rpc("claim_internal_task_notification_batch", {
    p_limit: limit
  });
  if (error) throw new Error(`internal_task_queue_claim_failed: ${error.message}`);
  return Array.isArray(data) ? data : [];
}
export async function updateInternalTaskQueueStatus(queueId, patch) {
  const { error } = await supabaseAdmin.from("internal_task_notification_queue").update(patch).eq("id", queueId);
  if (error) throw new Error(`internal_task_queue_update_failed: ${error.message}`);
}
