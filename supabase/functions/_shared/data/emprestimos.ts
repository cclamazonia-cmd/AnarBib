import { supabaseAdmin } from "../core/env.ts";
export async function getEmprestimoDetalhes(id) {
  const { data, error } = await supabaseAdmin.from("v_loans_detalhes").select("*").eq("id", id).maybeSingle();
  if (error) throw error;
  if (!data) throw new Error("Empréstimo não encontrado.");
  return data;
}
export async function getEmprestimoV2Bundle(id) {
  const { data: emp, error: e1 } = await supabaseAdmin.from("emprestimos_v2").select("id,user_id,library_id,created_at,updated_at,due_at,status_global,notes,extended_once,extended_at,renewals_used").eq("id", id).maybeSingle();
  if (e1) throw e1;
  if (!emp) throw new Error("Empréstimo não encontrado.");
  const { data: profile, error: e2 } = await supabaseAdmin.from("profiles").select("id,email,first_name,last_name,phone,address,consent_email,is_restricted,restricted_since,restricted_reason,preferred_language").eq("id", emp.user_id).maybeSingle();
  if (e2) throw e2;
  if (!profile) throw new Error("Perfil não encontrado.");
  const { data: items, error: e3 } = await supabaseAdmin.from("emprestimo_itens_v2").select("emprestimo_id,line_no,sub_id,bib_ref,autor:autor_cache,titulo:titulo_cache,editora:editora_cache,ano:ano_cache,item_status,returned_at,due_at,extended_until").eq("emprestimo_id", id).order("line_no", {
    ascending: true
  });
  if (e3) throw e3;
  return {
    emprestimo: emp,
    profile: profile,
    items: items || []
  };
}
export async function getEmprestimoV2Notificavel(id) {
  const { data, error } = await supabaseAdmin.from("v_emprestimos_v2_notificaveis").select("*").eq("id", id).maybeSingle();
  if (error) throw error;
  if (!data) throw new Error("Empréstimo notificável não encontrado.");
  return data;
}
export async function getEmprestimoDevolucaoBundle(id, lineNos) {
  let q = supabaseAdmin.from("v_emprestimos_notificacao_detalhes").select("*").eq("emprestimo_id", id).order("line_no", {
    ascending: true
  });
  if (lineNos?.length) q = q.in("line_no", lineNos);
  const { data, error } = await q;
  if (error) throw error;
  if (!data || data.length === 0) throw new Error("Empréstimo não encontrado.");
  return data;
}
