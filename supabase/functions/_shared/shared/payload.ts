export function asRecord(v) {
  return v && typeof v === "object" && !Array.isArray(v) ? v : null;
}
export function getNestedPayload(p) {
  const d = asRecord(p || null);
  return asRecord(d?.payload) || asRecord(d?.data) || d || {};
}
export function getPayloadValue(p, k) {
  return getNestedPayload(p)[k];
}
export function normalizeLineNos(v) {
  if (!Array.isArray(v)) return [];
  return v.map((x)=>Number(x)).filter((x)=>Number.isInteger(x) && x > 0);
}
export function normalizeWorkflowItems(v) {
  if (!Array.isArray(v)) return [];
  return v.map((i)=>asRecord(i)).filter(Boolean).map((i)=>({
      line_no: Number(i.line_no || 0) || undefined,
      sub_id: String(i.sub_id || "").trim() || null,
      bib_ref: String(i.bib_ref || "").trim() || null,
      titulo: String(i.titulo || "").trim() || null,
      autor: String(i.autor || "").trim() || null,
      rotulo: String(i.rotulo || "").trim() || null,
      item_status: String(i.item_status || "").trim() || null,
      workflow_stage_effective: String(i.workflow_stage_effective || "").trim() || null,
      workflow_note: String(i.workflow_note || "").trim() || null,
      pickup_scheduled_for: String(i.pickup_scheduled_for || "").trim() || null
    }));
}
