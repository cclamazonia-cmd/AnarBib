// Ajoute les clés catalogacao.infocard.* (cards "para informação") aux 10 locales.
// Session : Enrichissement données & backlog
const fs = require('fs');
const path = require('path');
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  'catalogacao.infocard.forInfo':       { 'pt-BR':'para informação', fr:'pour information', es:'para información', en:'for information', it:'per informazione', de:'zur Information', ca:'per a informació', eo:'por informo', nl:'ter informatie', el:'για ενημέρωση' },
  'catalogacao.infocard.authorTitle':   { 'pt-BR':'Autoria associada', fr:'Autorité liée', es:'Autoría asociada', en:'Linked author', it:'Autore collegato', de:'Verknüpfte Autor*in', ca:'Autoria associada', eo:'Ligita aŭtor-in-o', nl:'Gekoppelde auteur', el:'Συνδεδεμένη συγγραφή' },
  'catalogacao.infocard.exemplarTitle': { 'pt-BR':'Exemplares por biblioteca', fr:'Exemplaires par bibliothèque', es:'Ejemplares por biblioteca', en:'Copies by library', it:'Copie per biblioteca', de:'Exemplare nach Bibliothek', ca:'Exemplars per biblioteca', eo:'Ekzempleroj laŭ biblioteko', nl:'Exemplaren per bibliotheek', el:'Αντίτυπα ανά βιβλιοθήκη' },
  'catalogacao.infocard.goAuthor':      { 'pt-BR':'Ir para Autoria', fr:'Aller à Autorité', es:'Ir a Autoría', en:'Go to Authorship', it:'Vai ad Autore', de:'Zu Autorschaft', ca:'Vés a Autoria', eo:'Iri al Aŭtoreco', nl:'Naar Auteurschap', el:'Μετάβαση στη Συγγραφή' },
  'catalogacao.infocard.goExemplar':    { 'pt-BR':'Ir para Indexação', fr:'Aller à Indexation', es:'Ir a Indexación', en:'Go to Indexing', it:'Vai a Indicizzazione', de:'Zur Indexierung', ca:'Vés a Indexació', eo:'Iri al Indeksado', nl:'Naar Indexering', el:'Μετάβαση στην Ευρετηρίαση' },
  'catalogacao.infocard.noAuthor':      { 'pt-BR':'Nenhuma autoria informada ainda', fr:'Aucune autorité renseignée pour l’instant', es:'Ninguna autoría indicada todavía', en:'No author entered yet', it:'Nessun autore indicato ancora', de:'Noch keine Autorschaft angegeben', ca:'Cap autoria indicada encara', eo:'Ankoraŭ neniu aŭtor-in-o indikita', nl:'Nog geen auteur opgegeven', el:'Δεν έχει οριστεί συγγραφή ακόμη' },
  'catalogacao.infocard.linked':        { 'pt-BR':'vinculada', fr:'liée', es:'vinculada', en:'linked', it:'collegata', de:'verknüpft', ca:'vinculada', eo:'ligita', nl:'gekoppeld', el:'συνδεδεμένη' },
  'catalogacao.infocard.unlinked':      { 'pt-BR':'texto livre', fr:'texte libre', es:'texto libre', en:'free text', it:'testo libero', de:'Freitext', ca:'text lliure', eo:'libera teksto', nl:'vrije tekst', el:'ελεύθερο κείμενο' },
  'catalogacao.infocard.noExemplar':    { 'pt-BR':'Nenhum exemplar ainda', fr:'Aucun exemplaire pour l’instant', es:'Ningún ejemplar todavía', en:'No copies yet', it:'Nessuna copia ancora', de:'Noch keine Exemplare', ca:'Cap exemplar encara', eo:'Ankoraŭ neniu ekzemplero', nl:'Nog geen exemplaren', el:'Κανένα αντίτυπο ακόμη' },
  'catalogacao.infocard.exemplarUnsaved': { 'pt-BR':'Salve a ficha para gerir exemplares', fr:'Enregistrez la fiche pour gérer les exemplaires', es:'Guarde la ficha para gestionar ejemplares', en:'Save the record to manage copies', it:'Salva la scheda per gestire le copie', de:'Datensatz speichern, um Exemplare zu verwalten', ca:'Deseu la fitxa per gestionar exemplars', eo:'Konservu la skedon por administri ekzemplerojn', nl:'Sla de fiche op om exemplaren te beheren', el:'Αποθηκεύστε την καρτέλα για διαχείριση αντιτύπων' },
  'catalogacao.infocard.exemplarCount': { 'pt-BR':'{n} exempl.', fr:'{n} ex.', es:'{n} ejempl.', en:'{n} copies', it:'{n} copie', de:'{n} Ex.', ca:'{n} exempl.', eo:'{n} ekz.', nl:'{n} ex.', el:'{n} αντίτ.' },
};

const LOCALES = ['pt-BR','fr','es','en','it','de','ca','eo','nl','el'];
for (const loc of LOCALES) {
  const file = path.join(DIR, `${loc}.json`);
  const obj = JSON.parse(fs.readFileSync(file, 'utf8'));
  let added = 0;
  for (const [k, vals] of Object.entries(KEYS)) {
    if (!(k in obj)) { obj[k] = vals[loc]; added++; }
  }
  const sorted = {};
  for (const k of Object.keys(obj).sort()) sorted[k] = obj[k];
  fs.writeFileSync(file, JSON.stringify(sorted, null, 2) + '\n', 'utf8');
  console.log(`${loc}: +${added} clés`);
}
