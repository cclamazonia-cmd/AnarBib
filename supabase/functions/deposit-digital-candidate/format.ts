// Format d'un fichier versé (D25, 23/10/2026 : Word et ODT admis, en
// téléchargement seulement ; décision de Xavier).
//
// Le format se lit au nom du fichier (original_filename, sinon la fin de
// l'URL) — c'est aussi le nom que garde le chemin final, et c'est à
// l'extension de ce chemin que ingest.fn_digital_candidate_deposit_record
// reconnaît un document (type « documento », jamais principal). Le CONTENU
// doit ensuite le confirmer par sa signature, lue sur les premiers octets du
// flux : %PDF- pour un PDF ; PK\x03\x04 (une archive ZIP) pour .docx et .odt ;
// D0 CF 11 E0 A1 B1 1A E1 (un conteneur OLE) pour .doc. Un nom en .odt qui
// rend du HTML (page d'erreur, page de connexion) est refusé comme un faux PDF.
// Garde : src/tests/numdif-format-de-fichier.test.js.

export type Format = { ext: 'pdf' | 'doc' | 'docx' | 'odt'; mime: string; signature: number[] };

const PDF: Format = { ext: 'pdf', mime: 'application/pdf', signature: [0x25, 0x50, 0x44, 0x46, 0x2d] };
const FORMATS: Record<string, Format> = {
  pdf: PDF,
  doc: { ext: 'doc', mime: 'application/msword', signature: [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1] },
  docx: { ext: 'docx', mime: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', signature: [0x50, 0x4b, 0x03, 0x04] },
  odt: { ext: 'odt', mime: 'application/vnd.oasis.opendocument.text', signature: [0x50, 0x4b, 0x03, 0x04] },
};

/** Le format attendu d'après le nom ; un nom sans extension connue reste un PDF (le cas d'avant D25). */
export function formatAttendu(nom: string): Format {
  const ext = /\.([A-Za-z]+)$/.exec(String(nom || '').trim())?.[1]?.toLowerCase() ?? '';
  return FORMATS[ext] ?? PDF;
}

/** Octets à lire avant de juger la signature. */
export const LONGUEUR_TETE = 8;

/** null tant que la tête est trop courte pour juger ; sinon vrai si le contenu porte la signature du format. */
export function signatureConforme(format: Format, tete: Uint8Array): boolean | null {
  if (tete.length < format.signature.length) return null;
  return format.signature.every((o, i) => tete[i] === o);
}

export const estDocument = (format: Format) => format.ext !== 'pdf';
