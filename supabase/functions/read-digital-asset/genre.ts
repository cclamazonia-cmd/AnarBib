// Le genre de lecteur d'une ressource numérique, et le nom de téléchargement
// d'un document (read-digital-asset). Module à part, sans Deno : le banc
// src/tests/d25-documents-lecture.test.js l'importe.

// D25 (23/10/2026) : Word et ODT, en téléchargement seulement (aucun lecteur en ligne)
const MIME_DOCUMENTS = [
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.oasis.opendocument.text",
];
export function inferViewerKind(resourceType, mimeType, sourceUrl) {
  const rt = String(resourceType || "").toLowerCase();
  const mt = String(mimeType || "").toLowerCase();
  const su = String(sourceUrl || "").toLowerCase();
  if (rt === "link_externo") return "external_link";
  if (rt === "documento" || MIME_DOCUMENTS.includes(mt)) return "document";
  if (rt === "audio" || mt.startsWith("audio/")) return "audio";
  if (rt === "video" || mt.startsWith("video/")) return "video";
  if (rt === "image" || mt.startsWith("image/")) return "image";
  if (rt === "epub" || mt === "application/epub+zip" || su.endsWith(".epub")) return "epub";
  if (rt === "pdf_publico" || rt === "pdf_restrito" || mt === "application/pdf" || su.endsWith(".pdf")) return "pdf";
  return "generic";
}
// Le nom proposé au téléchargement d'un document : celui du chemin, sans
// l'horodatage du versement (books/<id>/<ms>_<nom>.<ext>).
export function nomDeTelechargement(storagePath) {
  const dernier = String(storagePath || "").split("/").pop() || "document";
  return dernier.replace(/^\d{10,}_/, "") || dernier;
}
