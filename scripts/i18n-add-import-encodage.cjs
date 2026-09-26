/* ===========================================================================
 * i18n-add-import-encodage.cjs
 * H15 (26/09/2026) — l'encodage d'un fichier importé : sélecteur de
 * l'adaptateur, panneau « encodage lu » d'un run, geste « Retraiter », refus
 * de retraiter un import déjà promu (HINT error.import.reparse_after_promotion).
 * 14 clés × 10 locales. Idempotent : une clé déjà présente n'est pas réécrite.
 * Usage : node scripts/i18n-add-import-encodage.cjs
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const ADD = {
  'pt-BR': {
    'importacoes.adapter.encoding': 'Codificação',
    'importacoes.adapter.encodingUtf8': 'UTF-8',
    'importacoes.adapter.encodingLatin1': 'Latin-1 / Windows-1252',
    'importacoes.run.encoding.label': 'Codificação do arquivo',
    'importacoes.run.encoding.auto': 'Lido em {enc} (detectado).',
    'importacoes.run.encoding.forced': 'Lido em {enc} (imposto).',
    'importacoes.run.encoding.fallback': 'Lido em {enc}, por suposição: o arquivo não é UTF-8 válido. Confira os acentos das primeiras notícias; se estiverem errados, reprocesse impondo a codificação.',
    'importacoes.run.encoding.declaredUnicode': 'O arquivo declara Unicode (UNIMARC 100 $a) mas não é UTF-8: incoerência da exportação.',
    'importacoes.run.encoding.declaredUnsupported': 'O arquivo declara um conjunto de caracteres não suportado ({codes}): alguns caracteres podem estar errados. Reexporte em UTF-8.',
    'importacoes.run.reprocess.title': 'Reler o arquivo com a codificação',
    'importacoes.run.reprocess.button': 'Reprocessar',
    'importacoes.run.reprocess.done': 'Importação #{id} relançada: as linhas vão ser relidas.',
    'importacoes.run.reprocess.locked': 'Esta importação já gerou rascunhos: não pode mais ser reprocessada. Para relê-la, importe o arquivo de novo.',
    'error.import.reparse_after_promotion': 'Esta importação já gerou rascunhos: não pode mais ser reprocessada (os rascunhos perderiam o vínculo com a importação). Importe o arquivo de novo.',
  },
  fr: {
    'importacoes.adapter.encoding': 'Encodage',
    'importacoes.adapter.encodingUtf8': 'UTF-8',
    'importacoes.adapter.encodingLatin1': 'Latin-1 / Windows-1252',
    'importacoes.run.encoding.label': 'Encodage du fichier',
    'importacoes.run.encoding.auto': 'Lu en {enc} (détecté).',
    'importacoes.run.encoding.forced': 'Lu en {enc} (imposé).',
    'importacoes.run.encoding.fallback': 'Lu en {enc}, par supposition : le fichier n’est pas de l’UTF-8 valide. Vérifiez les accents des premières notices ; s’ils sont faux, retraitez en imposant l’encodage.',
    'importacoes.run.encoding.declaredUnicode': 'Le fichier déclare de l’Unicode (UNIMARC 100 $a) mais n’est pas en UTF-8 : incohérence de l’export.',
    'importacoes.run.encoding.declaredUnsupported': 'Le fichier déclare un jeu de caractères non pris en charge ({codes}) : des caractères peuvent être faux. Ré-exportez en UTF-8.',
    'importacoes.run.reprocess.title': 'Relire le fichier avec l’encodage',
    'importacoes.run.reprocess.button': 'Retraiter',
    'importacoes.run.reprocess.done': 'Import #{id} relancé : les lignes vont être relues.',
    'importacoes.run.reprocess.locked': 'Cet import a déjà produit des brouillons : il ne peut plus être retraité. Pour le relire, importez de nouveau le fichier.',
    'error.import.reparse_after_promotion': 'Cet import a déjà produit des brouillons : il ne peut plus être retraité (les brouillons perdraient le lien vers leur import). Importez de nouveau le fichier.',
  },
  es: {
    'importacoes.adapter.encoding': 'Codificación',
    'importacoes.adapter.encodingUtf8': 'UTF-8',
    'importacoes.adapter.encodingLatin1': 'Latin-1 / Windows-1252',
    'importacoes.run.encoding.label': 'Codificación del archivo',
    'importacoes.run.encoding.auto': 'Leído en {enc} (detectado).',
    'importacoes.run.encoding.forced': 'Leído en {enc} (impuesto).',
    'importacoes.run.encoding.fallback': 'Leído en {enc}, por suposición: el archivo no es UTF-8 válido. Revisa los acentos de las primeras fichas; si están mal, reprocesa imponiendo la codificación.',
    'importacoes.run.encoding.declaredUnicode': 'El archivo declara Unicode (UNIMARC 100 $a) pero no está en UTF-8: incoherencia de la exportación.',
    'importacoes.run.encoding.declaredUnsupported': 'El archivo declara un juego de caracteres no admitido ({codes}): algunos caracteres pueden estar mal. Vuelve a exportar en UTF-8.',
    'importacoes.run.reprocess.title': 'Releer el archivo con la codificación',
    'importacoes.run.reprocess.button': 'Reprocesar',
    'importacoes.run.reprocess.done': 'Importación #{id} relanzada: las líneas se volverán a leer.',
    'importacoes.run.reprocess.locked': 'Esta importación ya generó borradores: ya no se puede reprocesar. Para releerla, importa de nuevo el archivo.',
    'error.import.reparse_after_promotion': 'Esta importación ya generó borradores: ya no se puede reprocesar (los borradores perderían el vínculo con su importación). Importa de nuevo el archivo.',
  },
  en: {
    'importacoes.adapter.encoding': 'Encoding',
    'importacoes.adapter.encodingUtf8': 'UTF-8',
    'importacoes.adapter.encodingLatin1': 'Latin-1 / Windows-1252',
    'importacoes.run.encoding.label': 'File encoding',
    'importacoes.run.encoding.auto': 'Read as {enc} (detected).',
    'importacoes.run.encoding.forced': 'Read as {enc} (forced).',
    'importacoes.run.encoding.fallback': 'Read as {enc}, by assumption: the file is not valid UTF-8. Check the accents of the first records; if they are wrong, reprocess with a forced encoding.',
    'importacoes.run.encoding.declaredUnicode': 'The file declares Unicode (UNIMARC 100 $a) but is not UTF-8: the export is inconsistent.',
    'importacoes.run.encoding.declaredUnsupported': 'The file declares an unsupported character set ({codes}): some characters may be wrong. Re-export as UTF-8.',
    'importacoes.run.reprocess.title': 'Read the file again with encoding',
    'importacoes.run.reprocess.button': 'Reprocess',
    'importacoes.run.reprocess.done': 'Import #{id} restarted: the rows will be read again.',
    'importacoes.run.reprocess.locked': 'This import has already produced drafts: it can no longer be reprocessed. To read it again, import the file anew.',
    'error.import.reparse_after_promotion': 'This import has already produced drafts: it can no longer be reprocessed (the drafts would lose their link to the import). Import the file anew.',
  },
  ca: {
    'importacoes.adapter.encoding': 'Codificació',
    'importacoes.adapter.encodingUtf8': 'UTF-8',
    'importacoes.adapter.encodingLatin1': 'Latin-1 / Windows-1252',
    'importacoes.run.encoding.label': 'Codificació del fitxer',
    'importacoes.run.encoding.auto': 'Llegit en {enc} (detectat).',
    'importacoes.run.encoding.forced': 'Llegit en {enc} (imposat).',
    'importacoes.run.encoding.fallback': 'Llegit en {enc}, per suposició: el fitxer no és UTF-8 vàlid. Reviseu els accents de les primeres fitxes; si són incorrectes, reprocesseu imposant la codificació.',
    'importacoes.run.encoding.declaredUnicode': 'El fitxer declara Unicode (UNIMARC 100 $a) però no és UTF-8: incoherència de l’exportació.',
    'importacoes.run.encoding.declaredUnsupported': 'El fitxer declara un joc de caràcters no admès ({codes}): alguns caràcters poden ser incorrectes. Torneu a exportar en UTF-8.',
    'importacoes.run.reprocess.title': 'Tornar a llegir el fitxer amb la codificació',
    'importacoes.run.reprocess.button': 'Reprocessar',
    'importacoes.run.reprocess.done': 'Importació #{id} rellançada: les línies es tornaran a llegir.',
    'importacoes.run.reprocess.locked': 'Aquesta importació ja ha generat esborranys: ja no es pot reprocessar. Per tornar-la a llegir, importeu de nou el fitxer.',
    'error.import.reparse_after_promotion': 'Aquesta importació ja ha generat esborranys: ja no es pot reprocessar (els esborranys perdrien el vincle amb la importació). Importeu de nou el fitxer.',
  },
  de: {
    'importacoes.adapter.encoding': 'Zeichenkodierung',
    'importacoes.adapter.encodingUtf8': 'UTF-8',
    'importacoes.adapter.encodingLatin1': 'Latin-1 / Windows-1252',
    'importacoes.run.encoding.label': 'Kodierung der Datei',
    'importacoes.run.encoding.auto': 'Gelesen als {enc} (erkannt).',
    'importacoes.run.encoding.forced': 'Gelesen als {enc} (vorgegeben).',
    'importacoes.run.encoding.fallback': 'Gelesen als {enc}, angenommen: Die Datei ist kein gültiges UTF-8. Prüft die Umlaute und Akzente der ersten Datensätze; sind sie falsch, verarbeitet die Datei mit vorgegebener Kodierung neu.',
    'importacoes.run.encoding.declaredUnicode': 'Die Datei erklärt Unicode (UNIMARC 100 $a), ist aber kein UTF-8: Der Export ist widersprüchlich.',
    'importacoes.run.encoding.declaredUnsupported': 'Die Datei erklärt einen nicht unterstützten Zeichensatz ({codes}): Einige Zeichen können falsch sein. Bitte als UTF-8 neu exportieren.',
    'importacoes.run.reprocess.title': 'Datei neu lesen mit Kodierung',
    'importacoes.run.reprocess.button': 'Neu verarbeiten',
    'importacoes.run.reprocess.done': 'Import #{id} neu gestartet: Die Zeilen werden neu gelesen.',
    'importacoes.run.reprocess.locked': 'Dieser Import hat bereits Entwürfe erzeugt: Er kann nicht mehr neu verarbeitet werden. Um ihn neu zu lesen, importiert die Datei erneut.',
    'error.import.reparse_after_promotion': 'Dieser Import hat bereits Entwürfe erzeugt: Er kann nicht mehr neu verarbeitet werden (die Entwürfe verlören ihre Verbindung zum Import). Importiert die Datei erneut.',
  },
  el: {
    'importacoes.adapter.encoding': 'Κωδικοποίηση',
    'importacoes.adapter.encodingUtf8': 'UTF-8',
    'importacoes.adapter.encodingLatin1': 'Latin-1 / Windows-1252',
    'importacoes.run.encoding.label': 'Κωδικοποίηση αρχείου',
    'importacoes.run.encoding.auto': 'Διαβάστηκε ως {enc} (εντοπίστηκε).',
    'importacoes.run.encoding.forced': 'Διαβάστηκε ως {enc} (επιβλήθηκε).',
    'importacoes.run.encoding.fallback': 'Διαβάστηκε ως {enc}, κατ’ υπόθεση: το αρχείο δεν είναι έγκυρο UTF-8. Ελέγξτε τους τόνους των πρώτων εγγραφών· αν είναι λάθος, επανεπεξεργαστείτε επιβάλλοντας την κωδικοποίηση.',
    'importacoes.run.encoding.declaredUnicode': 'Το αρχείο δηλώνει Unicode (UNIMARC 100 $a) αλλά δεν είναι UTF-8: ασυνέπεια της εξαγωγής.',
    'importacoes.run.encoding.declaredUnsupported': 'Το αρχείο δηλώνει μη υποστηριζόμενο σύνολο χαρακτήρων ({codes}): ορισμένοι χαρακτήρες μπορεί να είναι λάθος. Εξαγάγετε ξανά σε UTF-8.',
    'importacoes.run.reprocess.title': 'Νέα ανάγνωση του αρχείου με κωδικοποίηση',
    'importacoes.run.reprocess.button': 'Επανεπεξεργασία',
    'importacoes.run.reprocess.done': 'Η εισαγωγή #{id} ξεκίνησε ξανά: οι γραμμές θα διαβαστούν εκ νέου.',
    'importacoes.run.reprocess.locked': 'Αυτή η εισαγωγή έχει ήδη δημιουργήσει πρόχειρα: δεν μπορεί πλέον να επανεπεξεργαστεί. Για νέα ανάγνωση, εισαγάγετε ξανά το αρχείο.',
    'error.import.reparse_after_promotion': 'Αυτή η εισαγωγή έχει ήδη δημιουργήσει πρόχειρα: δεν μπορεί πλέον να επανεπεξεργαστεί (τα πρόχειρα θα έχαναν τον σύνδεσμο με την εισαγωγή). Εισαγάγετε ξανά το αρχείο.',
  },
  eo: {
    'importacoes.adapter.encoding': 'Kodoprezento',
    'importacoes.adapter.encodingUtf8': 'UTF-8',
    'importacoes.adapter.encodingLatin1': 'Latin-1 / Windows-1252',
    'importacoes.run.encoding.label': 'Kodoprezento de la dosiero',
    'importacoes.run.encoding.auto': 'Legita kiel {enc} (detektita).',
    'importacoes.run.encoding.forced': 'Legita kiel {enc} (trudita).',
    'importacoes.run.encoding.fallback': 'Legita kiel {enc}, supoze: la dosiero ne estas valida UTF-8. Kontrolu la supersignojn de la unuaj registroj; se ili estas malĝustaj, repritraktu trudante la kodoprezenton.',
    'importacoes.run.encoding.declaredUnicode': 'La dosiero deklaras Unikodon (UNIMARC 100 $a) sed ne estas UTF-8: nekohera eksporto.',
    'importacoes.run.encoding.declaredUnsupported': 'La dosiero deklaras ne subtenatan signaron ({codes}): kelkaj signoj povas esti malĝustaj. Reeksportu en UTF-8.',
    'importacoes.run.reprocess.title': 'Relegi la dosieron kun la kodoprezento',
    'importacoes.run.reprocess.button': 'Repritrakti',
    'importacoes.run.reprocess.done': 'Importo #{id} relanĉita: la linioj estos relegataj.',
    'importacoes.run.reprocess.locked': 'Ĉi tiu importo jam kreis malnetojn: ĝi ne plu povas esti repritraktata. Por relegi ĝin, importu la dosieron denove.',
    'error.import.reparse_after_promotion': 'Ĉi tiu importo jam kreis malnetojn: ĝi ne plu povas esti repritraktata (la malnetoj perdus la ligon al la importo). Importu la dosieron denove.',
  },
  it: {
    'importacoes.adapter.encoding': 'Codifica',
    'importacoes.adapter.encodingUtf8': 'UTF-8',
    'importacoes.adapter.encodingLatin1': 'Latin-1 / Windows-1252',
    'importacoes.run.encoding.label': 'Codifica del file',
    'importacoes.run.encoding.auto': 'Letto come {enc} (rilevato).',
    'importacoes.run.encoding.forced': 'Letto come {enc} (imposto).',
    'importacoes.run.encoding.fallback': 'Letto come {enc}, per ipotesi: il file non è UTF-8 valido. Controllate gli accenti delle prime schede; se sono sbagliati, rielaborate imponendo la codifica.',
    'importacoes.run.encoding.declaredUnicode': 'Il file dichiara Unicode (UNIMARC 100 $a) ma non è in UTF-8: esportazione incoerente.',
    'importacoes.run.encoding.declaredUnsupported': 'Il file dichiara un set di caratteri non supportato ({codes}): alcuni caratteri possono essere sbagliati. Riesportate in UTF-8.',
    'importacoes.run.reprocess.title': 'Rileggere il file con la codifica',
    'importacoes.run.reprocess.button': 'Rielabora',
    'importacoes.run.reprocess.done': 'Importazione #{id} rilanciata: le righe verranno rilette.',
    'importacoes.run.reprocess.locked': 'Questa importazione ha già prodotto bozze: non può più essere rielaborata. Per rileggerla, importate di nuovo il file.',
    'error.import.reparse_after_promotion': 'Questa importazione ha già prodotto bozze: non può più essere rielaborata (le bozze perderebbero il legame con l’importazione). Importate di nuovo il file.',
  },
  nl: {
    'importacoes.adapter.encoding': 'Codering',
    'importacoes.adapter.encodingUtf8': 'UTF-8',
    'importacoes.adapter.encodingLatin1': 'Latin-1 / Windows-1252',
    'importacoes.run.encoding.label': 'Codering van het bestand',
    'importacoes.run.encoding.auto': 'Gelezen als {enc} (gedetecteerd).',
    'importacoes.run.encoding.forced': 'Gelezen als {enc} (opgelegd).',
    'importacoes.run.encoding.fallback': 'Gelezen als {enc}, bij veronderstelling: het bestand is geen geldige UTF-8. Controleer de accenten van de eerste records; kloppen ze niet, verwerk dan opnieuw met een opgelegde codering.',
    'importacoes.run.encoding.declaredUnicode': 'Het bestand verklaart Unicode (UNIMARC 100 $a) maar is geen UTF-8: de export is inconsistent.',
    'importacoes.run.encoding.declaredUnsupported': 'Het bestand verklaart een niet-ondersteunde tekenset ({codes}): sommige tekens kunnen fout zijn. Exporteer opnieuw als UTF-8.',
    'importacoes.run.reprocess.title': 'Bestand opnieuw lezen met codering',
    'importacoes.run.reprocess.button': 'Opnieuw verwerken',
    'importacoes.run.reprocess.done': 'Import #{id} opnieuw gestart: de regels worden opnieuw gelezen.',
    'importacoes.run.reprocess.locked': 'Deze import heeft al concepten opgeleverd: hij kan niet meer opnieuw verwerkt worden. Importeer het bestand opnieuw om het opnieuw te lezen.',
    'error.import.reparse_after_promotion': 'Deze import heeft al concepten opgeleverd: hij kan niet meer opnieuw verwerkt worden (de concepten zouden hun koppeling met de import verliezen). Importeer het bestand opnieuw.',
  },
};

let total = 0;
for (const loc of LOCALES) {
  const f = path.join(DIR, `${loc}.json`);
  const j = JSON.parse(fs.readFileSync(f, 'utf8'));
  const add = ADD[loc];
  if (!add) throw new Error(`locale sans traduction : ${loc}`);
  let n = 0;
  for (const [k, v] of Object.entries(add)) {
    if (!(k in j)) { j[k] = v; n++; }
  }
  fs.writeFileSync(f, JSON.stringify(j, null, 2) + '\n');
  total += n;
  console.log(`${loc}: +${n}`);
}
console.log(`total : ${total}`);
