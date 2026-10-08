#!/usr/bin/env node
/**
 * i18n-contact-profile-intro-confidentiel.cjs (08/10/2026)
 * biblioteca.contactProfile.intro disait, dans les 10 locales, que le profil
 * de contact est « montré aux autres bibliothèques du réseau ». C'est faux :
 * la RLS (can_manage_library_contact_profile) en réserve la lecture à
 * l'équipe de la bibliothèque (librarian, coordenador), et son seul autre
 * lecteur, notify-document-permission-request, y prend l'adresse où écrire
 * À CETTE bibliothèque pour une troca (commentaire de
 * LibraryContactProfileSection.jsx corrigé dans dba89e7a).
 * Remplacement DE → PARA clé par clé : refuse d'écrire si l'ancienne valeur
 * n'est pas celle attendue. Idempotent (valeur nouvelle déjà posée = rien).
 */
const fs = require('fs');
const path = require('path');
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const KEY = 'biblioteca.contactProfile.intro';

const PARA = {
  'pt-BR': 'Contato humano da biblioteca para a cooperação entre bibliotecas — quem procurar, como, onde —, diferente do e-mail técnico de envio. Só a equipe da biblioteca vê estes dados; as outras bibliotecas não os veem. O endereço de e-mail recebe os avisos de troca dirigidos à biblioteca.',
  fr: 'Contact humain de la bibliothèque pour la coopération entre bibliothèques — qui joindre, comment, où —, distinct de l’e-mail technique d’envoi. Seule l’équipe de la bibliothèque voit ces coordonnées ; les autres bibliothèques ne les voient pas. L’adresse e-mail reçoit les avis d’échange adressés à la bibliothèque.',
  es: 'Contacto humano de la biblioteca para la cooperación entre bibliotecas — a quién acudir, cómo, dónde —, distinto del correo técnico de envío. Solo el equipo de la biblioteca ve estos datos; las otras bibliotecas no los ven. La dirección de correo recibe los avisos de intercambio dirigidos a la biblioteca.',
  en: 'The library’s human contact for cooperation between libraries — who to reach, how, where — distinct from the technical sending email. Only the library’s team sees these details; other libraries do not. The email address receives the exchange notices addressed to the library.',
  it: 'Contatto umano della biblioteca per la cooperazione tra biblioteche — chi cercare, come, dove —, distinto dall’e-mail tecnica di invio. Solo la squadra della biblioteca vede questi dati; le altre biblioteche non li vedono. L’indirizzo e-mail riceve gli avvisi di scambio indirizzati alla biblioteca.',
  de: 'Menschlicher Kontakt der Bibliothek für die Zusammenarbeit zwischen Bibliotheken — wen erreichen, wie, wo —, getrennt von der technischen Versand-E-Mail. Nur das Team der Bibliothek sieht diese Daten; andere Bibliotheken sehen sie nicht. Die E-Mail-Adresse erhält die an die Bibliothek gerichteten Tauschbenachrichtigungen.',
  ca: 'Contacte humà de la biblioteca per a la cooperació entre biblioteques — a qui adreçar-se, com, on —, diferent del correu tècnic d’enviament. Aquestes dades només són visibles per a l’equip de la biblioteca; les altres biblioteques no hi tenen accés. L’adreça electrònica rep els avisos d’intercanvi adreçats a la biblioteca.',
  eo: 'Homa kontakto de la biblioteko por la kunlaboro inter bibliotekoj — kiun trovi, kiel, kie —, malsama ol la teknika senda retpoŝto. Nur la teamo de la biblioteko vidas ĉi tiujn datumojn; la aliaj bibliotekoj ne vidas ilin. La retpoŝtadreso ricevas la interŝanĝajn sciigojn adresitajn al la biblioteko.',
  nl: 'Menselijk contact van de bibliotheek voor de samenwerking tussen bibliotheken — wie te bereiken, hoe, waar — los van het technische verzend-e-mailadres. Alleen het team van de bibliotheek ziet deze gegevens; andere bibliotheken zien ze niet. Het e-mailadres ontvangt de uitwisselingsberichten die aan de bibliotheek gericht zijn.',
  el: 'Ανθρώπινη επαφή της βιβλιοθήκης για τη συνεργασία μεταξύ βιβλιοθηκών — ποιον να βρεις, πώς, πού — διακριτή από το τεχνικό email αποστολής. Μόνο η ομάδα της βιβλιοθήκης βλέπει αυτά τα στοιχεία· οι άλλες βιβλιοθήκες δεν τα βλέπουν. Η διεύθυνση email λαμβάνει τις ειδοποιήσεις ανταλλαγής που απευθύνονται στη βιβλιοθήκη.',
};

// Signature de l'ancienne valeur, par locale : le texte faux à remplacer.
const DE = {
  'pt-BR': 'mostrados às outras bibliotecas da rede',
  fr: 'montrées aux autres bibliothèques du réseau',
  es: 'mostrados a las otras bibliotecas de la red',
  en: 'shown to the other libraries of the network',
  it: 'mostrati alle altre biblioteche della rete',
  de: 'den anderen Bibliotheken des Netzwerks für die Fernleihe und die Tausche gezeigt',
  ca: 'mostrades a les altres biblioteques de la xarxa',
  eo: 'montritaj al la aliaj bibliotekoj de la reto',
  nl: 'getoond aan de andere bibliotheken van het netwerk',
  el: 'που εμφανίζονται στις άλλες βιβλιοθήκες του δικτύου',
};

for (const [loc, valeur] of Object.entries(PARA)) {
  const file = path.join(DIR, loc + '.json');
  const content = fs.readFileSync(file, 'utf8');
  const actuel = JSON.parse(content)[KEY];
  if (actuel === valeur) { console.log(loc + ': déjà posée'); continue; }
  if (typeof actuel !== 'string' || !actuel.includes(DE[loc])) {
    throw new Error(loc + ': valeur inattendue, rien écrit — ' + actuel);
  }
  const ligne = '  ' + JSON.stringify(KEY) + ': ' + JSON.stringify(actuel);
  if (content.split(ligne).length !== 2) throw new Error(loc + ': ligne introuvable ou en double');
  fs.writeFileSync(file, content.replace(ligne, '  ' + JSON.stringify(KEY) + ': ' + JSON.stringify(valeur)), 'utf8');
  if (JSON.parse(fs.readFileSync(file, 'utf8'))[KEY] !== valeur) throw new Error(loc + ': écriture non relue');
  console.log(loc + ': remplacée');
}
