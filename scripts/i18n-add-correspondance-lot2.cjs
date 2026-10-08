/* ===========================================================================
 * i18n-add-correspondance-lot2.cjs — G19 lot 2 (REGISTRE CORR-5, 08/10/2026)
 * L'onglet « Correspondance » de la page Bibliothèque (CorrespondanceSection) :
 * 27 clés × 10 locales. Tutoiement partout ; pt-BR au « você ».
 * Idempotent : ce script est la SOURCE des clés du lot.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const CLES = {
  'biblioteca.tab.correspondance': { fr: 'Correspondance', 'pt-BR': 'Correspondência', en: 'Correspondence', es: 'Correspondencia', ca: 'Correspondència', it: 'Corrispondenza', de: 'Korrespondenz', nl: 'Correspondentie', eo: 'Korespondado', el: 'Αλληλογραφία' },
  'biblioteca.correspondance.title': { fr: 'Correspondance entre bibliothèques', 'pt-BR': 'Correspondência entre bibliotecas', en: 'Correspondence between libraries', es: 'Correspondencia entre bibliotecas', ca: 'Correspondència entre biblioteques', it: 'Corrispondenza tra biblioteche', de: 'Korrespondenz zwischen Bibliotheken', nl: 'Correspondentie tussen bibliotheken', eo: 'Korespondado inter bibliotekoj', el: 'Αλληλογραφία μεταξύ βιβλιοθηκών' },
  'biblioteca.correspondance.intro': {
    fr: 'Écris à une autre bibliothèque du réseau, au nom de la tienne. Chaque message garde sa langue ; la coordination de l’autre bibliothèque est prévenue. Un fil s’archive, il ne se supprime pas.',
    'pt-BR': 'Escreva a outra biblioteca da rede, em nome da sua. Cada mensagem guarda a sua língua; a coordenação da outra biblioteca é avisada. Um fio se arquiva, não se apaga.',
    en: 'Write to another library of the network, on behalf of yours. Each message keeps its language; the other library’s coordination is notified. A thread is archived, never deleted.',
    es: 'Escribe a otra biblioteca de la red, en nombre de la tuya. Cada mensaje conserva su lengua; la coordinación de la otra biblioteca queda avisada. Un hilo se archiva, no se borra.',
    ca: 'Aquí pots escriure a una altra biblioteca de la xarxa, en nom de la teva. Cada missatge conserva la seva llengua; la coordinació de l’altra biblioteca n’és avisada. Un fil s’arxiva, no s’esborra.',
    it: 'Scrivi a un’altra biblioteca della rete, a nome della tua. Ogni messaggio conserva la sua lingua; la coordinazione dell’altra biblioteca viene avvisata. Una conversazione si archivia, non si cancella.',
    de: 'Schreib einer anderen Bibliothek des Netzwerks, im Namen deiner eigenen. Jede Nachricht behält ihre Sprache; die Koordination der anderen Bibliothek wird benachrichtigt. Ein Faden wird archiviert, nie gelöscht.',
    nl: 'Schrijf aan een andere bibliotheek van het netwerk, in naam van de jouwe. Elk bericht behoudt zijn taal; de coördinatie van de andere bibliotheek wordt verwittigd. Een draad wordt gearchiveerd, nooit verwijderd.',
    eo: 'Skribu al alia biblioteko de la reto, en la nomo de la via. Ĉiu mesaĝo konservas sian lingvon; la kunordigo de la alia biblioteko estas avertita. Fadeno arkiviĝas, ne forviŝiĝas.',
    el: 'Γράψε σε άλλη βιβλιοθήκη του δικτύου, εξ ονόματος της δικής σου. Κάθε μήνυμα κρατά τη γλώσσα του· ο συντονισμός της άλλης βιβλιοθήκης ενημερώνεται. Ένα νήμα αρχειοθετείται, δεν διαγράφεται.',
  },
  'biblioteca.correspondance.write': { fr: 'Écrire à une bibliothèque', 'pt-BR': 'Escrever a uma biblioteca', en: 'Write to a library', es: 'Escribir a una biblioteca', ca: 'Escriure a una biblioteca', it: 'Scrivere a una biblioteca', de: 'Einer Bibliothek schreiben', nl: 'Aan een bibliotheek schrijven', eo: 'Skribi al biblioteko', el: 'Γράψε σε βιβλιοθήκη' },
  'biblioteca.correspondance.to': { fr: 'À', 'pt-BR': 'Para', en: 'To', es: 'Para', ca: 'A', it: 'A', de: 'An', nl: 'Aan', eo: 'Al', el: 'Προς' },
  'biblioteca.correspondance.subject': { fr: 'Sujet', 'pt-BR': 'Assunto', en: 'Subject', es: 'Asunto', ca: 'Assumpte', it: 'Oggetto', de: 'Betreff', nl: 'Onderwerp', eo: 'Temo', el: 'Θέμα' },
  'biblioteca.correspondance.body': { fr: 'Message', 'pt-BR': 'Mensagem', en: 'Message', es: 'Mensaje', ca: 'Missatge', it: 'Messaggio', de: 'Nachricht', nl: 'Bericht', eo: 'Mesaĝo', el: 'Μήνυμα' },
  'biblioteca.correspondance.lang': { fr: 'Langue du message', 'pt-BR': 'Língua da mensagem', en: 'Message language', es: 'Lengua del mensaje', ca: 'Llengua del missatge', it: 'Lingua del messaggio', de: 'Sprache der Nachricht', nl: 'Taal van het bericht', eo: 'Lingvo de la mesaĝo', el: 'Γλώσσα του μηνύματος' },
  'biblioteca.correspondance.send': { fr: 'Envoyer', 'pt-BR': 'Enviar', en: 'Send', es: 'Enviar', ca: 'Enviar', it: 'Invia', de: 'Senden', nl: 'Verzenden', eo: 'Sendi', el: 'Αποστολή' },
  'biblioteca.correspondance.reply': { fr: 'Répondre', 'pt-BR': 'Responder', en: 'Reply', es: 'Responder', ca: 'Respondre', it: 'Rispondi', de: 'Antworten', nl: 'Antwoorden', eo: 'Respondi', el: 'Απάντηση' },
  'biblioteca.correspondance.open': { fr: 'Ouvrir', 'pt-BR': 'Abrir', en: 'Open', es: 'Abrir', ca: 'Obrir', it: 'Apri', de: 'Öffnen', nl: 'Openen', eo: 'Malfermi', el: 'Άνοιγμα' },
  'biblioteca.correspondance.back': { fr: 'Retour aux fils', 'pt-BR': 'Voltar aos fios', en: 'Back to threads', es: 'Volver a los hilos', ca: 'Tornar als fils', it: 'Torna alle conversazioni', de: 'Zurück zu den Fäden', nl: 'Terug naar de draden', eo: 'Reen al la fadenoj', el: 'Πίσω στα νήματα' },
  'biblioteca.correspondance.archive': { fr: 'Archiver ce fil pour ma bibliothèque', 'pt-BR': 'Arquivar este fio para a minha biblioteca', en: 'Archive this thread for my library', es: 'Archivar este hilo para mi biblioteca', ca: 'Arxivar aquest fil per a la meva biblioteca', it: 'Archivia questa conversazione per la mia biblioteca', de: 'Diesen Faden für meine Bibliothek archivieren', nl: 'Deze draad archiveren voor mijn bibliotheek', eo: 'Arkivi ĉi tiun fadenon por mia biblioteko', el: 'Αρχειοθέτηση αυτού του νήματος για τη βιβλιοθήκη μου' },
  'biblioteca.correspondance.unarchive': { fr: 'Rouvrir ce fil', 'pt-BR': 'Reabrir este fio', en: 'Reopen this thread', es: 'Reabrir este hilo', ca: 'Reobrir aquest fil', it: 'Riapri questa conversazione', de: 'Diesen Faden wieder öffnen', nl: 'Deze draad heropenen', eo: 'Remalfermi ĉi tiun fadenon', el: 'Επανάνοιγμα αυτού του νήματος' },
  'biblioteca.correspondance.filterActive': { fr: 'En cours', 'pt-BR': 'Em curso', en: 'Active', es: 'En curso', ca: 'En curs', it: 'In corso', de: 'Laufend', nl: 'Lopend', eo: 'Aktivaj', el: 'Ενεργά' },
  'biblioteca.correspondance.filterArchived': { fr: 'Archivés', 'pt-BR': 'Arquivados', en: 'Archived', es: 'Archivados', ca: 'Arxivats', it: 'Archiviate', de: 'Archiviert', nl: 'Gearchiveerd', eo: 'Arkivitaj', el: 'Αρχειοθετημένα' },
  'biblioteca.correspondance.empty': { fr: 'Aucun fil en cours. Écris à une bibliothèque pour en ouvrir un.', 'pt-BR': 'Nenhum fio em curso. Escreva a uma biblioteca para abrir um.', en: 'No active thread. Write to a library to open one.', es: 'Ningún hilo en curso. Escribe a una biblioteca para abrir uno.', ca: 'Cap fil en curs. Pots escriure a una biblioteca per obrir-ne un.', it: 'Nessuna conversazione in corso. Scrivi a una biblioteca per aprirne una.', de: 'Kein laufender Faden. Schreib einer Bibliothek, um einen zu eröffnen.', nl: 'Geen lopende draad. Schrijf aan een bibliotheek om er een te openen.', eo: 'Neniu aktiva fadeno. Skribu al biblioteko por malfermi unu.', el: 'Κανένα ενεργό νήμα. Γράψε σε μια βιβλιοθήκη για να ανοίξεις ένα.' },
  'biblioteca.correspondance.emptyArchived': { fr: 'Aucun fil archivé.', 'pt-BR': 'Nenhum fio arquivado.', en: 'No archived thread.', es: 'Ningún hilo archivado.', ca: 'Cap fil arxivat.', it: 'Nessuna conversazione archiviata.', de: 'Kein archivierter Faden.', nl: 'Geen gearchiveerde draad.', eo: 'Neniu arkivita fadeno.', el: 'Κανένα αρχειοθετημένο νήμα.' },
  'biblioteca.correspondance.participants': { fr: 'Bibliothèques du fil', 'pt-BR': 'Bibliotecas do fio', en: 'Libraries in this thread', es: 'Bibliotecas del hilo', ca: 'Biblioteques del fil', it: 'Biblioteche della conversazione', de: 'Bibliotheken dieses Fadens', nl: 'Bibliotheken in deze draad', eo: 'Bibliotekoj de la fadeno', el: 'Βιβλιοθήκες του νήματος' },
  'biblioteca.correspondance.withLibraries': { fr: 'Avec {libraries}', 'pt-BR': 'Com {libraries}', en: 'With {libraries}', es: 'Con {libraries}', ca: 'Amb {libraries}', it: 'Con {libraries}', de: 'Mit {libraries}', nl: 'Met {libraries}', eo: 'Kun {libraries}', el: 'Με {libraries}' },
  'biblioteca.correspondance.unread': { fr: '{n, plural, one {# non lu} other {# non lus}}', 'pt-BR': '{n, plural, one {# não lida} other {# não lidas}}', en: '{n, plural, one {# unread} other {# unread}}', es: '{n, plural, one {# sin leer} other {# sin leer}}', ca: '{n, plural, one {# sense llegir} other {# sense llegir}}', it: '{n, plural, one {# non letto} other {# non letti}}', de: '{n, plural, one {# ungelesen} other {# ungelesen}}', nl: '{n, plural, one {# ongelezen} other {# ongelezen}}', eo: '{n, plural, one {# nelegita} other {# nelegitaj}}', el: '{n, plural, one {# μη αναγνωσμένο} other {# μη αναγνωσμένα}}' },
  'biblioteca.correspondance.writtenIn': { fr: 'Écrit en {lang}', 'pt-BR': 'Escrito em {lang}', en: 'Written in {lang}', es: 'Escrito en {lang}', ca: 'Escrit en {lang}', it: 'Scritto in {lang}', de: 'Geschrieben in {lang}', nl: 'Geschreven in {lang}', eo: 'Skribita en {lang}', el: 'Γραμμένο σε {lang}' },
  'biblioteca.correspondance.sent': { fr: 'Message envoyé.', 'pt-BR': 'Mensagem enviada.', en: 'Message sent.', es: 'Mensaje enviado.', ca: 'Missatge enviat.', it: 'Messaggio inviato.', de: 'Nachricht gesendet.', nl: 'Bericht verzonden.', eo: 'Mesaĝo sendita.', el: 'Το μήνυμα στάλθηκε.' },
  'biblioteca.correspondance.archived': { fr: 'Fil archivé pour ta bibliothèque.', 'pt-BR': 'Fio arquivado para a sua biblioteca.', en: 'Thread archived for your library.', es: 'Hilo archivado para tu biblioteca.', ca: 'Fil arxivat per a la teva biblioteca.', it: 'Conversazione archiviata per la tua biblioteca.', de: 'Faden für deine Bibliothek archiviert.', nl: 'Draad gearchiveerd voor je bibliotheek.', eo: 'Fadeno arkivita por via biblioteko.', el: 'Το νήμα αρχειοθετήθηκε για τη βιβλιοθήκη σου.' },
  'biblioteca.correspondance.unarchived': { fr: 'Fil rouvert.', 'pt-BR': 'Fio reaberto.', en: 'Thread reopened.', es: 'Hilo reabierto.', ca: 'Fil reobert.', it: 'Conversazione riaperta.', de: 'Faden wieder geöffnet.', nl: 'Draad heropend.', eo: 'Fadeno remalfermita.', el: 'Το νήμα ανοίχτηκε ξανά.' },
  'biblioteca.correspondance.libraryLocale': { fr: 'Langue de cette bibliothèque : {lang}', 'pt-BR': 'Língua desta biblioteca: {lang}', en: 'This library’s language: {lang}', es: 'Lengua de esta biblioteca: {lang}', ca: 'Llengua d’aquesta biblioteca: {lang}', it: 'Lingua di questa biblioteca: {lang}', de: 'Sprache dieser Bibliothek: {lang}', nl: 'Taal van deze bibliotheek: {lang}', eo: 'Lingvo de ĉi tiu biblioteko: {lang}', el: 'Γλώσσα αυτής της βιβλιοθήκης: {lang}' },
  'biblioteca.correspondance.unknownLibrary': { fr: 'Bibliothèque inconnue', 'pt-BR': 'Biblioteca desconhecida', en: 'Unknown library', es: 'Biblioteca desconocida', ca: 'Biblioteca desconeguda', it: 'Biblioteca sconosciuta', de: 'Unbekannte Bibliothek', nl: 'Onbekende bibliotheek', eo: 'Nekonata biblioteko', el: 'Άγνωστη βιβλιοθήκη' },
};
const ligneDe = (cle) => new RegExp('^  ' + JSON.stringify(cle).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ': (".*?")(,?)$', 'm');
for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  let ajoutees = 0, corrigees = 0;
  for (const [cle, valeurs] of Object.entries(CLES)) {
    const val = valeurs[loc];
    if (!val) throw new Error(`Valeur manquante : ${cle} / ${loc}`);
    const m = content.match(ligneDe(cle));
    if (m) {
      if (JSON.parse(m[1]) !== val) { content = content.replace(m[0], '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(val) + m[2]); corrigees++; }
      continue;
    }
    const entry = '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(val);
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entry + '\n' + content.slice(marker);
    ajoutees++;
  }
  if (!content.endsWith('\n')) content += '\n';
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(`${loc} : ${ajoutees} clé(s) ajoutée(s), ${corrigees} corrigée(s), JSON valide.`);
}
