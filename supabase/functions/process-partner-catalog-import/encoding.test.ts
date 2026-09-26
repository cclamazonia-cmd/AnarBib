// Tests du decodage des fichiers importes (H15). Lancer : deno test encoding.test.ts
// Joue aussi sous vitest par src/tests/deno-tests-pont.test.js.
import { assertEquals, assert } from 'jsr:@std/assert';
import { decodeImportBytes, encodingWarning, normalizeForcedEncoding, IMPORT_ENCODINGS } from './encoding.ts';

const utf8 = (s) => new TextEncoder().encode(s);
const latin1 = (s) => Uint8Array.from([...s].map((c) => c.charCodeAt(0)));
// Octets windows-1252 : € = 0x80, œ = 0x9C, ’ = 0x92 (absents de l'ISO-8859-1 strict).
const cp1252 = Uint8Array.from([0x44, 0xE9, 0x6A, 0xE0, 0x20, 0x80, 0x20, 0x9C, 0x92]); // « Déjà € œ’ »

Deno.test('UTF-8 valide : decode tel quel, sans repli ni avertissement', () => {
  const d = decodeImportBytes(utf8('Déjà vu — Élisée Reclus, 東京, Αναρχία'));
  assertEquals(d.text, 'Déjà vu — Élisée Reclus, 東京, Αναρχία');
  assertEquals(d.encoding, 'utf-8');
  assertEquals(d.fallback, false);
  assertEquals(d.forced, null);
  assertEquals(encodingWarning(d), null);
});

Deno.test('UTF-8 avec BOM : le BOM est retire', () => {
  const d = decodeImportBytes(Uint8Array.from([0xEF, 0xBB, 0xBF, ...utf8('titre;auteur')]));
  assertEquals(d.text, 'titre;auteur');
  assertEquals(d.fallback, false);
});

Deno.test('latin-1 / windows-1252 : repli SUPPOSE, texte exact, avertissement', () => {
  const d = decodeImportBytes(latin1('Déjà vu'));
  assertEquals(d.text, 'Déjà vu');
  assertEquals(d.encoding, 'windows-1252');
  assertEquals(d.fallback, true);
  assert(encodingWarning(d).includes('suppose'));
  const d2 = decodeImportBytes(cp1252);
  assertEquals(d2.text, 'Déjà € œ’');
});

Deno.test('encodage impose : honore, sans repli ; iso-8859-1 donne le decodeur windows-1252', () => {
  const d = decodeImportBytes(latin1('Déjà vu'), 'iso-8859-1');
  assertEquals(d.text, 'Déjà vu');
  assertEquals(d.encoding, 'windows-1252');
  assertEquals(d.forced, 'iso-8859-1');
  assertEquals(d.fallback, false);
  assertEquals(encodingWarning(d), null);
  // Impose a tort (UTF-8 lu en windows-1252) : mojibake attendu, c'est le prix du forcage.
  assertEquals(decodeImportBytes(utf8('é'), 'windows-1252').text, 'Ã©');
});

Deno.test('normalizeForcedEncoding : liste fermee, casse et blancs tolerees', () => {
  assertEquals(IMPORT_ENCODINGS, ['utf-8', 'windows-1252', 'iso-8859-1']);
  assertEquals(normalizeForcedEncoding(' UTF-8 '), 'utf-8');
  assertEquals(normalizeForcedEncoding('macintosh'), null);
  assertEquals(normalizeForcedEncoding(''), null);
  assertEquals(normalizeForcedEncoding(null), null);
  // Un encodage inconnu est ignore : detection automatique.
  assertEquals(decodeImportBytes(latin1('é'), 'klingon').fallback, true);
});
