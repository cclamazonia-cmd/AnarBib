/* ===========================================================================
 * i18n-add-numdif-file-candidats.cjs — NUMDIF D13/D15/D16 (15/10/2026) : la
 * file de candidats PDF (REGISTRE §47). Les HINT error.digital_candidate.* de
 * la migration 20261015172008 (D13) ; l'écran de validation (D15) et le
 * versement (D16) ajoutent leurs clés ici au fil des lots.
 * Session : File de candidats PDF.
 * Tutoiement ; pt-BR au « você » ; el au singulier. Onze locales.
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR', 'ro'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  // ── D13 : les refus de la base ────────────────────────────────────────
  'error.digital_candidate.coord_only': {
    fr: 'Seule la coordination de la bibliothèque détentrice (ou l’administration du réseau) gère sa file de candidats PDF.',
    'pt-BR': 'Só a coordenação da biblioteca detentora (ou a administração da rede) cuida da sua fila de candidatos PDF.',
    en: 'Only the coordination of the holding library (or the network administration) manages its PDF candidate queue.',
    es: 'Solo la coordinación de la biblioteca que tiene el ejemplar (o la administración de la red) gestiona su cola de candidatos PDF.',
    ca: 'Només la coordinació de la biblioteca que té l’exemplar (o l’administració de la xarxa) gestiona la seva cua de candidats PDF.',
    it: 'Solo il coordinamento della biblioteca che possiede l’esemplare (o l’amministrazione della rete) gestisce la sua coda di candidati PDF.',
    de: 'Nur die Koordination der besitzenden Bibliothek (oder die Netzwerkverwaltung) verwaltet ihre Warteschlange von PDF-Kandidaten.',
    nl: 'Alleen de coördinatie van de bibliotheek die het exemplaar bezit (of het netwerkbeheer) beheert haar wachtrij van pdf-kandidaten.',
    eo: 'Nur la kunordigo de la posedanta biblioteko (aŭ la administrado de la reto) mastrumas ĝian vicon de PDF-kandidatoj.',
    el: 'Μόνο ο συντονισμός της βιβλιοθήκης που έχει το αντίτυπο (ή η διαχείριση του δικτύου) διαχειρίζεται την ουρά υποψήφιων PDF της.',
    ro: 'Doar echipa de coordonare a bibliotecii care deține exemplarul (sau administrarea rețelei) își gestionează coada de candidați PDF.',
  },
  'error.digital_candidate.bad_payload': {
    fr: 'Le fichier de candidats est mal formé : il doit contenir une liste de candidats.',
    'pt-BR': 'O arquivo de candidatos está mal formado: ele deve conter uma lista de candidatos.',
    en: 'The candidate file is malformed: it must contain a list of candidates.',
    es: 'El archivo de candidatos está mal formado: debe contener una lista de candidatos.',
    ca: 'El fitxer de candidats està mal format: ha de contenir una llista de candidats.',
    it: 'Il file dei candidati non è valido: deve contenere un elenco di candidati.',
    de: 'Die Kandidatendatei ist fehlerhaft: Sie muss eine Liste von Kandidaten enthalten.',
    nl: 'Het kandidatenbestand is ongeldig: het moet een lijst van kandidaten bevatten.',
    eo: 'La dosiero de kandidatoj estas misformita: ĝi devas enhavi liston de kandidatoj.',
    el: 'Το αρχείο υποψηφίων δεν είναι έγκυρο: πρέπει να περιέχει λίστα υποψηφίων.',
    ro: 'Fișierul de candidați este greșit format: trebuie să conțină o listă de candidați.',
  },
  'error.digital_candidate.page_too_large': {
    fr: 'Au plus 200 candidats à la fois : découpe le fichier.',
    'pt-BR': 'No máximo 200 candidatos de cada vez: divida o arquivo.',
    en: 'At most 200 candidates at a time: split the file.',
    es: 'Como máximo 200 candidatos a la vez: divide el archivo.',
    ca: 'Com a màxim 200 candidats alhora: divideix el fitxer.',
    it: 'Al massimo 200 candidati alla volta: dividi il file.',
    de: 'Höchstens 200 Kandidaten auf einmal: Teile die Datei auf.',
    nl: 'Maximaal 200 kandidaten tegelijk: splits het bestand.',
    eo: 'Maksimume 200 kandidatoj samtempe: dividu la dosieron.',
    el: 'Το πολύ 200 υποψήφιοι κάθε φορά: χώρισε το αρχείο.',
    ro: 'Cel mult 200 de candidați odată: împarte fișierul.',
  },
  'error.digital_candidate.bad_decision': {
    fr: 'Décision inconnue : choisis « valider » ou « rejeter ».',
    'pt-BR': 'Decisão desconhecida: escolha «validar» ou «rejeitar».',
    en: 'Unknown decision: choose “validate” or “reject”.',
    es: 'Decisión desconocida: elige «validar» o «rechazar».',
    ca: 'Decisió desconeguda: tria «validar» o «rebutjar».',
    it: 'Decisione sconosciuta: scegli «convalida» o «rifiuta».',
    de: 'Unbekannte Entscheidung: Wähle „bestätigen“ oder „ablehnen“.',
    nl: 'Onbekende beslissing: kies ‘bevestigen’ of ‘afwijzen’.',
    eo: 'Nekonata decido: elektu «validigi» aŭ «malakcepti».',
    el: 'Άγνωστη απόφαση: διάλεξε «επικύρωση» ή «απόρριψη».',
    ro: 'Decizie necunoscută: alege „validează” sau „respinge”.',
  },
  'error.digital_candidate.not_found': {
    fr: 'Candidat introuvable : il a peut-être été retiré, ou il appartient à une autre bibliothèque.',
    'pt-BR': 'Candidato não encontrado: talvez tenha sido retirado, ou pertença a outra biblioteca.',
    en: 'Candidate not found: it may have been removed, or it belongs to another library.',
    es: 'Candidato no encontrado: quizá se retiró, o pertenece a otra biblioteca.',
    ca: 'No s’ha trobat el candidat: potser s’ha retirat, o pertany a una altra biblioteca.',
    it: 'Candidato non trovato: forse è stato ritirato, o appartiene a un’altra biblioteca.',
    de: 'Kandidat nicht gefunden: Er wurde vielleicht entfernt oder gehört einer anderen Bibliothek.',
    nl: 'Kandidaat niet gevonden: misschien is hij verwijderd, of hoort hij bij een andere bibliotheek.',
    eo: 'Kandidato ne trovita: eble ĝi estis forigita, aŭ ĝi apartenas al alia biblioteko.',
    el: 'Ο υποψήφιος δεν βρέθηκε: ίσως αφαιρέθηκε ή ανήκει σε άλλη βιβλιοθήκη.',
    ro: 'Candidat negăsit: poate a fost retras sau aparține altei biblioteci.',
  },
  'error.digital_candidate.not_holding': {
    fr: 'Ta bibliothèque ne détient plus cette notice : elle ne peut plus décider de ce candidat ni le verser.',
    'pt-BR': 'A sua biblioteca não possui mais esta ficha: ela não pode mais decidir sobre este candidato nem enviá-lo.',
    en: 'Your library no longer holds this record: it can no longer decide on this candidate or deposit it.',
    es: 'Tu biblioteca ya no tiene esta ficha: ya no puede decidir sobre este candidato ni subirlo.',
    ca: 'La teva biblioteca ja no té aquesta fitxa: ja no pot decidir sobre aquest candidat ni dipositar-lo.',
    it: 'La tua biblioteca non possiede più questa scheda: non può più decidere su questo candidato né depositarlo.',
    de: 'Deine Bibliothek besitzt diesen Eintrag nicht mehr: Sie kann über diesen Kandidaten nicht mehr entscheiden und ihn nicht mehr ablegen.',
    nl: 'Je bibliotheek bezit dit record niet meer: ze kan niet meer over deze kandidaat beslissen of hem opslaan.',
    eo: 'Via biblioteko ne plu havas ĉi tiun slipon: ĝi ne plu povas decidi pri ĉi tiu kandidato nek deponi ĝin.',
    el: 'Η βιβλιοθήκη σου δεν έχει πια αυτή την εγγραφή: δεν μπορεί πια να αποφασίσει για αυτόν τον υποψήφιο ούτε να τον καταθέσει.',
    ro: 'Biblioteca ta nu mai deține această fișă: nu mai poate decide asupra acestui candidat și nici nu-l mai poate depune.',
  },
  'error.digital_candidate.bad_page_url': {
    fr: 'L’adresse de la page doit commencer par http:// ou https://.',
    'pt-BR': 'O endereço da página deve começar por http:// ou https://.',
    en: 'The page address must start with http:// or https://.',
    es: 'La dirección de la página debe empezar por http:// o https://.',
    ca: 'L’adreça de la pàgina ha de començar per http:// o https://.',
    it: 'L’indirizzo della pagina deve iniziare con http:// o https://.',
    de: 'Die Adresse der Seite muss mit http:// oder https:// beginnen.',
    nl: 'Het adres van de pagina moet beginnen met http:// of https://.',
    eo: 'La adreso de la paĝo devas komenciĝi per http:// aŭ https://.',
    el: 'Η διεύθυνση της σελίδας πρέπει να αρχίζει με http:// ή https://.',
    ro: 'Adresa paginii trebuie să înceapă cu http:// sau https://.',
  },
  'error.digital_candidate.already_decided': {
    fr: 'Ce candidat a déjà été décidé : recharge la file.',
    'pt-BR': 'Este candidato já foi decidido: recarregue a fila.',
    en: 'This candidate has already been decided: reload the queue.',
    es: 'Este candidato ya fue decidido: vuelve a cargar la cola.',
    ca: 'Aquest candidat ja s’ha decidit: torna a carregar la cua.',
    it: 'Questo candidato è già stato deciso: ricarica la coda.',
    de: 'Über diesen Kandidaten wurde schon entschieden: Lade die Warteschlange neu.',
    nl: 'Over deze kandidaat is al beslist: laad de wachtrij opnieuw.',
    eo: 'Pri ĉi tiu kandidato jam estis decidite: reŝargu la vicon.',
    el: 'Για αυτόν τον υποψήφιο έχει ήδη αποφασιστεί: φόρτωσε ξανά την ουρά.',
    ro: 'Pentru acest candidat s-a decis deja: reîncarcă coada.',
  },
  'error.digital_candidate.same_edition_only': {
    fr: 'On ne valide que le fichier de la même édition que l’exemplaire détenu (éditeur, lieu, année, traduction). Rejette-le : l’édition trouvée reste notée.',
    'pt-BR': 'Só se valida o arquivo da mesma edição que o exemplar possuído (editora, local, ano, tradução). Rejeite-o: a edição encontrada fica registrada.',
    en: 'Only a file of the same edition as the held copy can be validated (publisher, place, year, translation). Reject it: the edition found stays on record.',
    es: 'Solo se valida el archivo de la misma edición que el ejemplar que se tiene (editorial, lugar, año, traducción). Recházalo: la edición encontrada queda anotada.',
    ca: 'Només es valida el fitxer de la mateixa edició que l’exemplar que es té (editorial, lloc, any, traducció). Rebutja’l: l’edició trobada queda anotada.',
    it: 'Si convalida solo il file della stessa edizione dell’esemplare posseduto (editore, luogo, anno, traduzione). Rifiutalo: l’edizione trovata resta annotata.',
    de: 'Bestätigt wird nur die Datei derselben Ausgabe wie das vorhandene Exemplar (Verlag, Ort, Jahr, Übersetzung). Lehne sie ab: Die gefundene Ausgabe bleibt vermerkt.',
    nl: 'Alleen het bestand van dezelfde uitgave als het aanwezige exemplaar wordt bevestigd (uitgever, plaats, jaar, vertaling). Wijs het af: de gevonden uitgave blijft genoteerd.',
    eo: 'Oni validigas nur la dosieron de la sama eldono kiel la posedata ekzemplero (eldonejo, loko, jaro, traduko). Malakceptu ĝin: la trovita eldono restas notita.',
    el: 'Επικυρώνεται μόνο το αρχείο της ίδιας έκδοσης με το αντίτυπο που υπάρχει (εκδότης, τόπος, έτος, μετάφραση). Απόρριψέ το: η έκδοση που βρέθηκε μένει καταγεγραμμένη.',
    ro: 'Se validează doar fișierul aceleiași ediții ca exemplarul deținut (editură, loc, an, traducere). Respinge-l: ediția găsită rămâne notată.',
  },
  'error.digital_candidate.case_required': {
    fr: 'Choisis le cas de source : il fixe le statut de droits et l’accès.',
    'pt-BR': 'Escolha o caso de origem: ele define o estatuto de direitos e o acesso.',
    en: 'Choose the source case: it sets the rights status and the access.',
    es: 'Elige el caso de origen: fija el estatus de derechos y el acceso.',
    ca: 'Tria el cas d’origen: fixa l’estatus de drets i l’accés.',
    it: 'Scegli il caso di origine: stabilisce lo stato dei diritti e l’accesso.',
    de: 'Wähle den Quellenfall: Er legt den Rechtestatus und den Zugang fest.',
    nl: 'Kies het bronscenario: het bepaalt de rechtenstatus en de toegang.',
    eo: 'Elektu la fontan kazon: ĝi fiksas la rajtostaton kaj la aliron.',
    el: 'Διάλεξε την περίπτωση πηγής: ορίζει το καθεστώς δικαιωμάτων και την πρόσβαση.',
    ro: 'Alege cazul sursei: el stabilește statutul drepturilor și accesul.',
  },
  'error.digital_candidate.justification_required': {
    fr: 'Écris la justification du versement.',
    'pt-BR': 'Escreva a justificativa do envio.',
    en: 'Write the justification for the deposit.',
    es: 'Escribe la justificación de la subida.',
    ca: 'Escriu la justificació del dipòsit.',
    it: 'Scrivi la motivazione del deposito.',
    de: 'Schreib die Begründung für die Ablage.',
    nl: 'Schrijf de rechtvaardiging van de opslag.',
    eo: 'Skribu la pravigon de la deponado.',
    el: 'Γράψε την αιτιολόγηση της κατάθεσης.',
    ro: 'Scrie justificarea depunerii.',
  },
  'error.digital_candidate.mention_required': {
    fr: 'Pour une licence libre, cite la mention imprimée dans l’édition et la page où elle figure.',
    'pt-BR': 'Para uma licença livre, cite a menção impressa na edição e a página onde ela aparece.',
    en: 'For a free licence, quote the notice printed in the edition and the page where it appears.',
    es: 'Para una licencia libre, cita la mención impresa en la edición y la página donde figura.',
    ca: 'Per a una llicència lliure, cita la menció impresa a l’edició i la pàgina on figura.',
    it: 'Per una licenza libera, cita la dicitura stampata nell’edizione e la pagina in cui compare.',
    de: 'Bei einer freien Lizenz zitiere den in der Ausgabe gedruckten Vermerk und die Seite, auf der er steht.',
    nl: 'Citeer bij een vrije licentie de vermelding die in de uitgave gedrukt staat, en de pagina waar ze staat.',
    eo: 'Por libera permesilo, citu la mencion presitan en la eldono kaj la paĝon, kie ĝi troviĝas.',
    el: 'Για ελεύθερη άδεια, παράθεσε τη σημείωση που είναι τυπωμένη στην έκδοση και τη σελίδα όπου βρίσκεται.',
    ro: 'Pentru o licență liberă, citează mențiunea tipărită în ediție și pagina unde apare.',
  },
  'error.digital_candidate.reason_required': {
    fr: 'Écris le motif du rejet.',
    'pt-BR': 'Escreva o motivo da rejeição.',
    en: 'Write the reason for the rejection.',
    es: 'Escribe el motivo del rechazo.',
    ca: 'Escriu el motiu del rebuig.',
    it: 'Scrivi il motivo del rifiuto.',
    de: 'Schreib den Grund für die Ablehnung.',
    nl: 'Schrijf de reden van de afwijzing.',
    eo: 'Skribu la kialon de la malakcepto.',
    el: 'Γράψε τον λόγο της απόρριψης.',
    ro: 'Scrie motivul respingerii.',
  },
  'error.digital_candidate.no_fingerprint': {
    fr: 'Ce candidat n’a pas d’empreinte SHA-256 : relance l’outil de recherche pour le télécharger avant de valider.',
    'pt-BR': 'Este candidato não tem impressão SHA-256: rode de novo a ferramenta de busca para baixá-lo antes de validar.',
    en: 'This candidate has no SHA-256 fingerprint: run the search tool again to download it before validating.',
    es: 'Este candidato no tiene huella SHA-256: vuelve a lanzar la herramienta de búsqueda para descargarlo antes de validar.',
    ca: 'Aquest candidat no té empremta SHA-256: torna a executar l’eina de cerca per baixar-lo abans de validar.',
    it: 'Questo candidato non ha un’impronta SHA-256: rilancia lo strumento di ricerca per scaricarlo prima di convalidare.',
    de: 'Dieser Kandidat hat keinen SHA-256-Fingerabdruck: Starte das Suchwerkzeug erneut, um ihn vor der Bestätigung herunterzuladen.',
    nl: 'Deze kandidaat heeft geen SHA-256-vingerafdruk: start de zoektool opnieuw om hem te downloaden voor je bevestigt.',
    eo: 'Ĉi tiu kandidato ne havas SHA-256-fingrospuron: relanĉu la serĉilon por elŝuti ĝin antaŭ ol validigi.',
    el: 'Αυτός ο υποψήφιος δεν έχει αποτύπωμα SHA-256: ξανατρέξε το εργαλείο αναζήτησης για να τον κατεβάσεις πριν την επικύρωση.',
    ro: 'Acest candidat nu are amprentă SHA-256: relansează instrumentul de căutare ca să-l descarci înainte de validare.',
  },
};

const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  const bilan = { ajoutee: 0, corrigee: 0, inchangee: 0 };
  for (const [cle, vals] of Object.entries(KEYS)) {
    const val = vals[loc];
    if (typeof val !== 'string' || !val) throw new Error(`valeur manquante ${cle} ${loc}`);
    const ligne = new RegExp('^  ' + esc(JSON.stringify(cle)) + ': (".*?")(,?)$', 'm');
    const m = content.match(ligne);
    if (m) {
      if (JSON.parse(m[1]) !== val) {
        content = content.replace(m[0], '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(val) + m[2]);
        bilan.corrigee++;
      } else bilan.inchangee++;
    } else {
      const marker = content.lastIndexOf('}');
      content = content.slice(0, marker).replace(/\s*$/, '') + ',\n  ' + JSON.stringify(cle) + ': ' + JSON.stringify(val) + '\n' + content.slice(marker);
      bilan.ajoutee++;
    }
  }
  if (!content.endsWith('\n')) content += '\n';
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(`${loc} : ${bilan.ajoutee} ajoutée(s), ${bilan.corrigee} corrigée(s), ${bilan.inchangee} inchangée(s) ; JSON valide.`);
}
