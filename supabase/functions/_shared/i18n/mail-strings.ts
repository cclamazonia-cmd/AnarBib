// ============================================================================
// mail-strings.ts — i18n des notifications mail (Edge Function notify-event)
// ============================================================================
// 10 locales : pt-BR (référence), fr, es, en, it, de, ca, eo, nl, el
//
// Conventions militantes par locale :
//   pt-BR : triple forme o-a-e, démonstratifs binôme dest(e-a),
//           contractions article-préposition triples d(o-a-e)
//   fr    : point médian (lecteur·rice, le·la)
//   es    : neutre argentin e (le, les, une, conectade), participes accordés
//   en    : neutre standard (épicène)
//   it    : asterisco * pour paires régulières (compagn*, bibliotecari*, attiv*),
//           slash pour paires irrégulières (lettore/trice, amministratore/trice,
//           coordinatore/trice), JAMAIS camerata
//   de    : Genderstern (Leser*in, Genoss*in), JAMAIS "Compas"
//   ca    : triple forme suffixe -a-e (lector-a-e, bibliotecari-ària-e, coordinador-a-e), déterminant neutre « le » (le lector-a-e), variantes parenthésées (a/e)
//   eo    : infixe -in- visibilisé par tirets (legant-in-o, kunordigant-in-o, administrant-in-o), pronom neutre ri
//   nl    : formes communes neutres (lezer, bibliothecaris, coördinator), pronom neutre die, sans marquage de genre
//   el    : grec monotonique, 2e pers. sing. (tutoiement lecteur·rice / vous équipe), formes inclusives par doublets ou neutres (αναγνώστης/στρια, συντονιστής/στρια), GDPR -> ΓΚΠΔ
//
// Date du fix : 2026-05-02 (chasse au bug wf.ready / wf.readyShort affichés
//               en clés brutes dans les mails — clés manquantes du dictionnaire)
// ============================================================================

export type SupportedMailLocale = "pt-BR" | "fr" | "es" | "en" | "it" | "de" | "ca" | "eo" | "nl" | "el";

const V = new Set<string>(["pt-BR", "fr", "es", "en", "it", "de", "ca", "eo", "nl", "el"]);

const S: Record<string, Record<SupportedMailLocale, string>> = {

  // ── Accueil dans l'équipe : invitation (lot 4) ────────────────────────────
  "team.invitation_proposed.sub": {
    "pt-BR": "Um convite a endossar — {libraryName}",
    fr: "Une invitation à endosser — {libraryName}",
    es: "Una invitación para respaldar — {libraryName}",
    en: "An invitation to endorse — {libraryName}",
    it: "Un invito da avallare — {libraryName}",
    de: "Eine Einladung zum Befürworten — {libraryName}",
    ca: "Una invitació per avalar — {libraryName}",
    eo: "Invito por aprobi — {libraryName}",
    nl: "Een uitnodiging om te steunen — {libraryName}",
    el: "Μια πρόσκληση προς υποστήριξη — {libraryName}"
  },
  "team.invitation_proposed.intro": {
    "pt-BR": "{actorName} propõe acolher {targetName} na equipe de {libraryName}. Seu endosso (coordenação) é necessário para finalizar o acolhimento. Acesse o painel da equipe para endossar.",
    fr: "{actorName} propose d'accueillir {targetName} dans l'équipe de {libraryName}. Votre endossement (coordination) est nécessaire pour finaliser l'accueil. Rendez-vous dans le panneau de l'équipe pour endosser.",
    es: "{actorName} propone acoger a {targetName} en el equipo de {libraryName}. Tu respaldo (coordinación) es necesario para finalizar el acogimiento. Entra al panel del equipo para respaldar.",
    en: "{actorName} proposes to welcome {targetName} to the team of {libraryName}. Your endorsement (coordination) is needed to finalize it. Go to the team panel to endorse.",
    it: "{actorName} propone di accogliere {targetName} nella squadra di {libraryName}. Il tuo avallo (coordinamento) è necessario per finalizzare l'accoglienza. Vai al pannello della squadra per avallare.",
    de: "{actorName} schlägt vor, {targetName} ins Team von {libraryName} aufzunehmen. Deine Befürwortung (Koordination) ist nötig, um es abzuschließen. Geh zum Team-Panel, um zu befürworten.",
    ca: "{actorName} proposa acollir {targetName} a l'equip de {libraryName}. El teu aval (coordinació) és necessari per finalitzar l'acolliment. Vés al tauler de l'equip per avalar.",
    eo: "{actorName} proponas akcepti {targetName} en la teamon de {libraryName}. Via aprobo (kunordigo) necesas por finpretigi. Iru al la teama panelo por aprobi.",
    nl: "{actorName} stelt voor om {targetName} in het team van {libraryName} op te nemen. Jouw steun (coördinatie) is nodig om dit af te ronden. Ga naar het teampaneel om te steunen.",
    el: "{actorName} προτείνει την ένταξη του ατόμου {targetName} στην ομάδα της {libraryName}. Η υποστήριξή σας (συντονισμός) χρειάζεται για την ολοκλήρωση. Μεταβείτε στον πίνακα της ομάδας για να υποστηρίξετε."
  },
  "team.invitation_ready.sub": {
    "pt-BR": "Convite para integrar a equipe de {libraryName}",
    fr: "Invitation à rejoindre l'équipe de {libraryName}",
    es: "Invitación para integrar el equipo de {libraryName}",
    en: "Invitation to join the team of {libraryName}",
    it: "Invito a entrare nella squadra di {libraryName}",
    de: "Einladung, dem Team von {libraryName} beizutreten",
    ca: "Invitació per formar part de l'equip de {libraryName}",
    eo: "Invito aliĝi al la teamo de {libraryName}",
    nl: "Uitnodiging om bij het team van {libraryName} te komen",
    el: "Πρόσκληση για ένταξη στην ομάδα της {libraryName}"
  },
  "team.invitation_ready.intro": {
    "pt-BR": "Seu convite para integrar a equipe de {libraryName} está pronto. Acesse sua conta (Minhas bibliotecas) para aceitar ou recusar.",
    fr: "Votre invitation à rejoindre l'équipe de {libraryName} est prête. Rendez-vous dans votre compte (Mes bibliothèques) pour l'accepter ou la décliner.",
    es: "Tu invitación para integrar el equipo de {libraryName} está lista. Entra a tu cuenta (Mis bibliotecas) para aceptarla o rechazarla.",
    en: "Your invitation to join the team of {libraryName} is ready. Go to your account (My libraries) to accept or decline it.",
    it: "Il tuo invito a entrare nella squadra di {libraryName} è pronto. Vai al tuo account (Le mie biblioteche) per accettarlo o rifiutarlo.",
    de: "Deine Einladung, dem Team von {libraryName} beizutreten, ist bereit. Geh zu deinem Konto (Meine Bibliotheken), um sie anzunehmen oder abzulehnen.",
    ca: "La teva invitació per formar part de l'equip de {libraryName} està a punt. Vés al teu compte (Les meves biblioteques) per acceptar-la o rebutjar-la.",
    eo: "Via invito aliĝi al la teamo de {libraryName} estas preta. Iru al via konto (Miaj bibliotekoj) por akcepti aŭ rifuzi ĝin.",
    nl: "Je uitnodiging om bij het team van {libraryName} te komen is klaar. Ga naar je account (Mijn bibliotheken) om die te aanvaarden of te weigeren.",
    el: "Η πρόσκλησή σας για ένταξη στην ομάδα της {libraryName} είναι έτοιμη. Μεταβείτε στον λογαριασμό σας (Οι βιβλιοθήκες μου) για να την αποδεχτείτε ή να την απορρίψετε."
  },

  // ── Actus réseau : digest hebdomadaire (EF notify-rede-digest) ────────────
  "rede.digest.subject": {
    "pt-BR": "{brand} · Novidades da rede",
    fr: "{brand} · Nouveautés du réseau",
    es: "{brand} · Novedades de la red",
    en: "{brand} · Network news",
    it: "{brand} · Novità della rete",
    de: "{brand} · Netzwerk-Neuigkeiten",
    ca: "{brand} · Novetats de la xarxa",
    eo: "{brand} · Novaĵoj de la reto",
    nl: "{brand} · Netwerknieuws",
    el: "{brand} · Νέα του δικτύου"
  },
  "rede.digest.title": {
    "pt-BR": "Novidades da rede",
    fr: "Nouveautés du réseau",
    es: "Novedades de la red",
    en: "Network news",
    it: "Novità della rete",
    de: "Netzwerk-Neuigkeiten",
    ca: "Novetats de la xarxa",
    eo: "Novaĵoj de la reto",
    nl: "Netwerknieuws",
    el: "Νέα του δικτύου"
  },
  "rede.digest.intro": {
    "pt-BR": "Aqui está o que há de novo na rede desde a última vez.",
    fr: "Voici ce qui est nouveau sur le réseau depuis la dernière fois.",
    es: "Esto es lo nuevo en la red desde la última vez.",
    en: "Here's what's new across the network since last time.",
    it: "Ecco le novità della rete dall'ultima volta.",
    de: "Das ist neu im Netzwerk seit dem letzten Mal.",
    ca: "Això és el que hi ha de nou a la xarxa des de l'última vegada.",
    eo: "Jen kio novas en la reto ekde la lasta fojo.",
    nl: "Dit is er nieuw in het netwerk sinds de vorige keer.",
    el: "Να τι νέο υπάρχει στο δίκτυο από την τελευταία φορά."
  },
  "rede.digest.gazette.heading": {
    "pt-BR": "Gazeta",
    fr: "Gazette",
    es: "Gaceta",
    en: "Gazette",
    it: "Gazzetta",
    de: "Gazette",
    ca: "Gaseta",
    eo: "Gazeto",
    nl: "Gazette",
    el: "Εφημερίδα"
  },
  "rede.digest.circles.heading": {
    "pt-BR": "Novos círculos",
    fr: "Nouveaux cercles",
    es: "Nuevos círculos",
    en: "New circles",
    it: "Nuovi circoli",
    de: "Neue Kreise",
    ca: "Nous cercles",
    eo: "Novaj rondoj",
    nl: "Nieuwe kringen",
    el: "Νέοι κύκλοι"
  },
  "rede.digest.unsub": {
    "pt-BR": "Cancelar a inscrição na Carta da federação",
    fr: "Se désabonner de la Lettre de la fédération",
    es: "Darse de baja de la Carta de la federación",
    en: "Unsubscribe from the federation Letter",
    it: "Annullare l'iscrizione alla Lettera della federazione",
    de: "Den Rundbrief der Föderation abbestellen",
    ca: "Donar-se de baixa de la Carta de la federació",
    eo: "Malaboni la Leteron de la federacio",
    nl: "Uitschrijven van de Brief van de federatie",
    el: "Διαγραφή από την Επιστολή της ομοσπονδίας"
  },

  // ── Cotisation : expiration (notify-event · #25, J-7 rappel) ──────────────
  "cotisation.expiring.subject": {
    "pt-BR": "A tua contribuição está perto do vencimento",
    fr: "Ta cotisation arrive à échéance",
    es: "Tu cuota está por vencer",
    en: "Your membership dues are about to expire",
    it: "La tua quota sta per scadere",
    de: "Dein Mitgliedsbeitrag läuft bald ab",
    ca: "La teva quota està a punt de vèncer",
    eo: "Via kotizo baldaŭ eksvalidiĝos",
    nl: "Je lidmaatschapsbijdrage verloopt binnenkort",
    el: "Η συνδρομή σου λήγει σύντομα"
  },
  "cotisation.expiring.intro": {
    "pt-BR": "A tua contribuição à {library} vence em {date}. Lembra-te de renová-la junto à biblioteca para continuar a pegar emprestado.",
    fr: "Ta cotisation à {library} expire le {date}. Pense à la renouveler auprès de la bibliothèque pour continuer à emprunter.",
    es: "Tu cuota en {library} vence el {date}. Acordate de renovarla en la biblioteca para seguir tomando préstamos.",
    en: "Your membership dues at {library} expire on {date}. Remember to renew them with the library to keep borrowing.",
    it: "La tua quota a {library} scade il {date}. Ricordati di rinnovarla in biblioteca per continuare a prendere in prestito.",
    de: "Dein Mitgliedsbeitrag bei {library} läuft am {date} ab. Denk daran, ihn in der Bibliothek zu erneuern, um weiter ausleihen zu können.",
    ca: "La teva quota a {library} venç el {date}. Recorda renovar-la a la biblioteca per continuar fent préstecs.",
    eo: "Via kotizo ĉe {library} eksvalidiĝos je {date}. Memoru renovigi ĝin ĉe la biblioteko por daŭre prunti.",
    nl: "Je lidmaatschapsbijdrage bij {library} verloopt op {date}. Vergeet niet om die bij de bibliotheek te verlengen zodat je kunt blijven lenen.",
    el: "Η συνδρομή σου στη {library} λήγει στις {date}. Θυμήσου να την ανανεώσεις στη βιβλιοθήκη για να συνεχίσεις να δανείζεσαι."
  },
  // ── Cotisation : expiration (notify-event · #25, J-0 jour J) ──────────────
  "cotisation.expiring_today.subject": {
    "pt-BR": "A tua contribuição vence hoje",
    fr: "Ta cotisation expire aujourd'hui",
    es: "Tu cuota vence hoy",
    en: "Your membership dues expire today",
    it: "La tua quota scade oggi",
    de: "Dein Mitgliedsbeitrag läuft heute ab",
    ca: "La teva quota venç avui",
    eo: "Via kotizo eksvalidiĝas hodiaŭ",
    nl: "Je lidmaatschapsbijdrage verloopt vandaag",
    el: "Η συνδρομή σου λήγει σήμερα"
  },
  "cotisation.expiring_today.intro": {
    "pt-BR": "A tua contribuição à {library} vence hoje ({date}). Renova-a junto à biblioteca para continuar a pegar emprestado.",
    fr: "Ta cotisation à {library} expire aujourd'hui ({date}). Renouvelle-la auprès de la bibliothèque pour continuer à emprunter.",
    es: "Tu cuota en {library} vence hoy ({date}). Renovala en la biblioteca para seguir tomando préstamos.",
    en: "Your membership dues at {library} expire today ({date}). Renew them with the library to keep borrowing.",
    it: "La tua quota a {library} scade oggi ({date}). Rinnovala in biblioteca per continuare a prendere in prestito.",
    de: "Dein Mitgliedsbeitrag bei {library} läuft heute ab ({date}). Erneuere ihn in der Bibliothek, um weiter ausleihen zu können.",
    ca: "La teva quota a {library} venç avui ({date}). Renova-la a la biblioteca per continuar fent préstecs.",
    eo: "Via kotizo ĉe {library} eksvalidiĝas hodiaŭ ({date}). Renovigu ĝin ĉe la biblioteko por daŭre prunti.",
    nl: "Je lidmaatschapsbijdrage bij {library} verloopt vandaag ({date}). Verleng die bij de bibliotheek zodat je kunt blijven lenen.",
    el: "Η συνδρομή σου στη {library} λήγει σήμερα ({date}). Ανανέωσέ την στη βιβλιοθήκη για να συνεχίσεις να δανείζεσαι."
  },

  // ── Entraide (notify-event · notif au cercle) ─────────────────────────────
  "entraide.request_circle.sub": {
    "pt-BR": "Novo chamado de apoio mútuo no teu círculo {circle}",
    fr: "Nouvel appel d'entraide dans ton cercle {circle}",
    es: "Nueva llamada de ayuda mutua en tu círculo {circle}",
    en: "New mutual-aid call in your circle {circle}",
    it: "Nuovo appello di mutuo aiuto nel tuo cerchio {circle}",
    de: "Neuer Hilferuf in deinem Kreis {circle}",
    ca: "Nova crida de suport mutu al teu cercle {circle}",
    eo: "Nova alvoko de reciproka helpo en via rondo {circle}",
    nl: "Nieuwe hulpoproep in jouw kring {circle}",
    el: "Νέο κάλεσμα αλληλοβοήθειας στον κύκλο σου {circle}"
  },
  "entraide.request_circle.intro": {
    "pt-BR": "Uma biblioteca do teu círculo « {circle} » publicou um chamado de apoio mútuo: {subject}. Podes responder na aba Apoio mútuo.",
    fr: "Une biblio de ton cercle « {circle} » a posté un appel à l'aide : {subject}. Tu peux y répondre dans l'onglet Entraide.",
    es: "Una biblioteca de tu círculo « {circle} » publicó una llamada de ayuda: {subject}. Puedes responder en la pestaña Ayuda mutua.",
    en: "A library in your circle “{circle}” posted a help call: {subject}. You can respond in the Mutual Aid tab.",
    it: "Una biblioteca del tuo cerchio « {circle} » ha pubblicato un appello d'aiuto: {subject}. Puoi rispondere nella scheda Mutuo aiuto.",
    de: "Eine Bibliothek aus deinem Kreis „{circle}“ hat einen Hilferuf gepostet: {subject}. Du kannst in der Registerkarte Gegenseitige Hilfe antworten.",
    ca: "Una biblioteca del teu cercle « {circle} » ha publicat una crida d'ajuda: {subject}. Pots respondre a la pestanya Suport mutu.",
    eo: "Biblioteko de via rondo « {circle} » afiŝis alvokon por helpo: {subject}. Vi povas respondi en la langeto Reciproka helpo.",
    nl: "Een bibliotheek uit jouw kring “{circle}” heeft een hulpoproep geplaatst: {subject}. Je kunt reageren op het tabblad Onderlinge hulp.",
    el: "Μια βιβλιοθήκη του κύκλου σου « {circle} » δημοσίευσε ένα κάλεσμα βοήθειας: {subject}. Μπορείς να απαντήσεις στην καρτέλα Αλληλοβοήθεια."
  },

  // ── Gazette (notify-event · Étape A) ──────────────────────────────────────
  "gazette.contribution.received.sub": {
    "pt-BR": "Nova nota proposta para a Gazeta",
    fr: "Nouvelle brève proposée à la Gazette",
    es: "Nueva nota propuesta para la Gaceta",
    en: "New note suggested for the Gazette",
    it: "Nuova nota proposta per la Gazzetta",
    de: "Neue Notiz für die Gazette vorgeschlagen",
    ca: "Nova nota proposada per a la Gaseta",
    eo: "Nova noto proponita por la Gazeto",
    nl: "Nieuw bericht voorgesteld voor de Gazette",
    el: "Νέο σημείωμα προτάθηκε για την εφημερίδα"
  },
  "gazette.contribution.received.intro": {
    "pt-BR": "Uma nova nota foi proposta para a rubrica « {rubric} »: {title}. Proposta por {author}. Para triar (aceitar ou rejeitar) no painel da rede.",
    fr: "Une nouvelle brève a été proposée pour la rubrique « {rubric} » : {title}. Proposée par {author}. À trier (accepter ou rejeter) dans le panneau réseau.",
    es: "Se ha propuesto una nueva nota para la sección « {rubric} »: {title}. Propuesta por {author}. Para clasificar (aceptar o rechazar) en el panel de la red.",
    en: "A new note has been suggested for the « {rubric} » section: {title}. Suggested by {author}. To triage (accept or reject) in the network panel.",
    it: "È stata proposta una nuova nota per la sezione « {rubric} »: {title}. Proposta da {author}. Da smistare (accettare o rifiutare) nel pannello della rete.",
    de: "Eine neue Notiz wurde für die Rubrik « {rubric} » vorgeschlagen: {title}. Vorgeschlagen von {author}. Zu sichten (annehmen oder ablehnen) im Netzwerk-Panel.",
    ca: "S'ha proposat una nova nota per a la secció « {rubric} »: {title}. Proposada per {author}. Per triar (acceptar o rebutjar) al tauler de la xarxa.",
    eo: "Nova noto estis proponita por la rubriko « {rubric} »: {title}. Proponita de {author}. Por trakti (akcepti aŭ malakcepti) en la reta panelo.",
    nl: "Er is een nieuw bericht voorgesteld voor de rubriek « {rubric} »: {title}. Voorgesteld door {author}. Te sorteren (accepteren of weigeren) in het netwerkpaneel.",
    el: "Προτάθηκε ένα νέο σημείωμα για την ενότητα « {rubric} »: {title}. Προτάθηκε από {author}. Για διαλογή (αποδοχή ή απόρριψη) στον πίνακα του δικτύου."
  },
  "gazette.draft.ready_for_review.sub": {
    "pt-BR": "Rascunho da Gazeta n.º {number} para revisar",
    fr: "Brouillon de la Gazette n°{number} à relire",
    es: "Borrador de la Gaceta n.º {number} para revisar",
    en: "Gazette draft no. {number} ready for review",
    it: "Bozza della Gazzetta n. {number} da rivedere",
    de: "Gazette-Entwurf Nr. {number} zur Durchsicht",
    ca: "Esborrany de la Gaseta núm. {number} per revisar",
    eo: "Malneto de la Gazeto n-ro {number} por revizii",
    nl: "Concept van de Gazette nr. {number} om na te kijken",
    el: "Πρόχειρο της εφημερίδας αρ. {number} προς αναθεώρηση"
  },
  "gazette.draft.ready_for_review.intro": {
    "pt-BR": "O rascunho mensal da Gazeta (n.º {number}) está pronto. Revise as 10 locales, corrija se necessário e publique pelo painel da rede. Nada é publicado automaticamente.",
    fr: "Le brouillon mensuel de la Gazette (n°{number}) est prêt. Relis les 10 locales, corrige si besoin, puis publie-le depuis le panneau réseau. Rien n'est publié automatiquement.",
    es: "El borrador mensual de la Gaceta (n.º {number}) está listo. Revisa las 10 locales, corrige si hace falta y publícalo desde el panel de la red. Nada se publica automáticamente.",
    en: "The monthly Gazette draft (no. {number}) is ready. Review the 10 locales, correct if needed, then publish it from the network panel. Nothing is published automatically.",
    it: "La bozza mensile della Gazzetta (n. {number}) è pronta. Rivedi le 10 lingue, correggi se serve, poi pubblicala dal pannello della rete. Niente viene pubblicato automaticamente.",
    de: "Der monatliche Gazette-Entwurf (Nr. {number}) ist fertig. Prüfe die 10 Sprachen, korrigiere bei Bedarf und veröffentliche ihn über das Netzwerk-Panel. Es wird nichts automatisch veröffentlicht.",
    ca: "L'esborrany mensual de la Gaseta (núm. {number}) està a punt. Revisa les 10 locales, corregeix si cal i publica'l des del tauler de la xarxa. No es publica res automàticament.",
    eo: "La monata malneto de la Gazeto (n-ro {number}) estas preta. Reviziu la 10 lingvojn, korektu se necese, poste publikigu ĝin el la reta panelo. Nenio estas publikigita aŭtomate.",
    nl: "Het maandelijkse concept van de Gazette (nr. {number}) is klaar. Bekijk de 10 talen, corrigeer indien nodig en publiceer het via het netwerkpaneel. Er wordt niets automatisch gepubliceerd.",
    el: "Το μηνιαίο πρόχειρο της εφημερίδας (αρ. {number}) είναι έτοιμο. Έλεγξε τις 10 γλώσσες, διόρθωσε αν χρειάζεται και δημοσίευσέ το από τον πίνακα του δικτύου. Τίποτα δεν δημοσιεύεται αυτόματα."
  },
  "gazette.issue.published.sub": {
    "pt-BR": "A Gazeta n.º {number} foi publicada!",
    fr: "La Gazette n°{number} est parue !",
    es: "¡La Gaceta n.º {number} ya está disponible!",
    en: "Gazette no. {number} is out!",
    it: "È uscita la Gazzetta n. {number}!",
    de: "Die Gazette Nr. {number} ist da!",
    ca: "Ja ha sortit la Gaseta núm. {number}!",
    eo: "La Gazeto n-ro {number} aperis!",
    nl: "Gazette nr. {number} is uit!",
    el: "Κυκλοφόρησε η εφημερίδα αρ. {number}!"
  },
  "gazette.issue.published.intro": {
    "pt-BR": "O número {number} da Gazeta da rede acaba de sair. Boa leitura — e fique à vontade para divulgá-la.",
    fr: "Le numéro {number} de la Gazette du réseau vient de paraître. Bonne lecture — et n'hésite pas à la diffuser autour de toi.",
    es: "El número {number} de la Gaceta de la red acaba de salir. Buena lectura — y no dudes en difundirla.",
    en: "Issue {number} of the network Gazette has just been published. Enjoy — and feel free to share it around.",
    it: "È appena uscito il numero {number} della Gazzetta della rete. Buona lettura — e sentiti libero di diffonderla.",
    de: "Ausgabe {number} der Netzwerk-Gazette ist soeben erschienen. Viel Freude beim Lesen — und teile sie gern weiter.",
    ca: "Acaba de sortir el número {number} de la Gaseta de la xarxa. Bona lectura — i no dubtis a difondre-la.",
    eo: "Ĵus aperis la numero {number} de la reta Gazeto. Bonan legadon — kaj disvastigu ĝin laŭplaĉe.",
    nl: "Nummer {number} van de netwerk-Gazette is zojuist verschenen. Veel leesplezier — en deel het gerust.",
    el: "Μόλις κυκλοφόρησε το τεύχος {number} της εφημερίδας του δικτύου. Καλή ανάγνωση — και μη διστάσεις να τη διαδώσεις."
  },

  // === Lettre de la fédération (double opt-in : confirmation + pages de retour) ===
  "lettre.optin.confirm.sub": {
    "pt-BR": "Confirma tua inscrição no Boletim da rede",
    fr: "Confirme ton abonnement à la Lettre de la fédération",
    es: "Confirma tu suscripción al Boletín de la red",
    en: "Confirm your subscription to the federation letter",
    it: "Conferma la tua iscrizione alla Lettera della rete",
    de: "Bestätige dein Abo des Netzwerk-Rundbriefs",
    ca: "Confirma la teva subscripció al Butlletí de la xarxa",
    eo: "Konfirmu vian abonon al la reta bulteno",
    nl: "Bevestig je inschrijving op de nieuwsbrief van het netwerk",
    el: "Επιβεβαίωσε την εγγραφή σου στο ενημερωτικό δελτίο του δικτύου"
  },
  "lettre.optin.confirm.intro": {
    "pt-BR": "Tu pediste para receber o Boletim da rede. Para confirmar tua inscrição, clica no botão abaixo.",
    fr: "Tu as demandé à recevoir la Lettre de la fédération. Pour confirmer ton abonnement, clique sur le bouton ci-dessous.",
    es: "Pediste recibir el Boletín de la red. Para confirmar tu suscripción, haz clic en el botón de abajo.",
    en: "You asked to receive the federation letter. To confirm your subscription, click the button below.",
    it: "Hai chiesto di ricevere la Lettera della rete. Per confermare la tua iscrizione, clicca sul pulsante qui sotto.",
    de: "Du hast den Netzwerk-Rundbrief abonniert. Klicke zur Bestätigung deines Abos auf die Schaltfläche unten.",
    ca: "Has demanat rebre el Butlletí de la xarxa. Per confirmar la teva subscripció, fes clic al botó de sota.",
    eo: "Vi petis ricevi la retan bultenon. Por konfirmi vian abonon, klaku la suban butonon.",
    nl: "Je hebt je aangemeld voor de nieuwsbrief van het netwerk. Klik op de knop hieronder om je inschrijving te bevestigen.",
    el: "Ζήτησες να λαμβάνεις το ενημερωτικό δελτίο του δικτύου. Για να επιβεβαιώσεις την εγγραφή σου, πάτησε το κουμπί παρακάτω."
  },
  "lettre.optin.confirm.cta": {
    "pt-BR": "Confirmar minha inscrição",
    fr: "Confirmer mon abonnement",
    es: "Confirmar mi suscripción",
    en: "Confirm my subscription",
    it: "Conferma la mia iscrizione",
    de: "Mein Abo bestätigen",
    ca: "Confirma la meva subscripció",
    eo: "Konfirmi mian abonon",
    nl: "Mijn inschrijving bevestigen",
    el: "Επιβεβαίωση της εγγραφής μου"
  },
  "lettre.optin.confirm.note": {
    "pt-BR": "Se não foste tu quem fez este pedido, ignora esta mensagem: nada será enviado sem tua confirmação.",
    fr: "Si tu n'es pas à l'origine de cette demande, ignore ce message : rien ne te sera envoyé sans ta confirmation.",
    es: "Si no hiciste esta solicitud, ignora este mensaje: no se te enviará nada sin tu confirmación.",
    en: "If you didn't make this request, just ignore this message: nothing will be sent without your confirmation.",
    it: "Se non hai fatto questa richiesta, ignora questo messaggio: non ti verrà inviato nulla senza la tua conferma.",
    de: "Wenn du diese Anfrage nicht gestellt hast, ignoriere diese Nachricht einfach: ohne deine Bestätigung wird dir nichts zugeschickt.",
    ca: "Si no has fet aquesta sol·licitud, ignora aquest missatge: no se t'enviarà res sense la teva confirmació.",
    eo: "Se vi ne faris ĉi tiun peton, simple ignoru ĉi tiun mesaĝon: nenio estos sendita sen via konfirmo.",
    nl: "Heb je dit niet aangevraagd? Negeer dit bericht dan: zonder je bevestiging wordt er niets verstuurd.",
    el: "Αν δεν έκανες εσύ αυτό το αίτημα, αγνόησε αυτό το μήνυμα: τίποτα δεν θα σταλεί χωρίς την επιβεβαίωσή σου."
  },
  "lettre.landing.cta": {
    "pt-BR": "Voltar ao AnarBib", fr: "Retour à AnarBib", es: "Volver a AnarBib", en: "Back to AnarBib",
    it: "Torna ad AnarBib", de: "Zurück zu AnarBib", ca: "Torna a AnarBib", eo: "Reen al AnarBib",
    nl: "Terug naar AnarBib", el: "Επιστροφή στο AnarBib"
  },
  "lettre.landing.confirmed": {
    "pt-BR": "Inscrição confirmada! Vais receber o Boletim da rede.",
    fr: "Abonnement confirmé ! Tu recevras la Lettre de la fédération.",
    es: "¡Suscripción confirmada! Recibirás el Boletín de la red.",
    en: "Subscription confirmed! You'll receive the federation letter.",
    it: "Iscrizione confermata! Riceverai la Lettera della rete.",
    de: "Abo bestätigt! Du erhältst künftig den Netzwerk-Rundbrief.",
    ca: "Subscripció confirmada! Rebràs el Butlletí de la xarxa.",
    eo: "Abono konfirmita! Vi ricevos la retan bultenon.",
    nl: "Inschrijving bevestigd! Je ontvangt voortaan de nieuwsbrief van het netwerk.",
    el: "Η εγγραφή επιβεβαιώθηκε! Θα λαμβάνεις το ενημερωτικό δελτίο του δικτύου."
  },
  "lettre.landing.already": {
    "pt-BR": "Tua inscrição já estava confirmada.",
    fr: "Ton abonnement était déjà confirmé.",
    es: "Tu suscripción ya estaba confirmada.",
    en: "Your subscription was already confirmed.",
    it: "La tua iscrizione era già confermata.",
    de: "Dein Abo war bereits bestätigt.",
    ca: "La teva subscripció ja estava confirmada.",
    eo: "Via abono jam estis konfirmita.",
    nl: "Je inschrijving was al bevestigd.",
    el: "Η εγγραφή σου είχε ήδη επιβεβαιωθεί."
  },
  "lettre.landing.expired": {
    "pt-BR": "Este link de confirmação expirou. Podes pedir um novo a partir da tua conta.",
    fr: "Ce lien de confirmation a expiré. Tu peux en redemander un depuis ton compte.",
    es: "Este enlace de confirmación ha caducado. Puedes pedir uno nuevo desde tu cuenta.",
    en: "This confirmation link has expired. You can request a new one from your account.",
    it: "Questo link di conferma è scaduto. Puoi richiederne uno nuovo dal tuo account.",
    de: "Dieser Bestätigungslink ist abgelaufen. In deinem Konto kannst du einen neuen anfordern.",
    ca: "Aquest enllaç de confirmació ha caducat. Pots demanar-ne un de nou des del teu compte.",
    eo: "Ĉi tiu konfirma ligilo eksvalidiĝis. Vi povas peti novan el via konto.",
    nl: "Deze bevestigingslink is verlopen. Je kunt een nieuwe aanvragen vanuit je account.",
    el: "Αυτός ο σύνδεσμος επιβεβαίωσης έληξε. Μπορείς να ζητήσεις νέον από τον λογαριασμό σου."
  },
  "lettre.landing.invalid": {
    "pt-BR": "Link inválido ou expirado.", fr: "Lien invalide ou expiré.", es: "Enlace no válido o caducado.",
    en: "Invalid or expired link.", it: "Link non valido o scaduto.", de: "Ungültiger oder abgelaufener Link.",
    ca: "Enllaç no vàlid o caducat.", eo: "Nevalida aŭ eksvalidiĝinta ligilo.", nl: "Ongeldige of verlopen link.",
    el: "Μη έγκυρος ή ληγμένος σύνδεσμος."
  },
  "lettre.landing.error": {
    "pt-BR": "Ocorreu um erro. Tenta de novo mais tarde.", fr: "Une erreur est survenue. Réessaie plus tard.",
    es: "Se ha producido un error. Inténtalo de nuevo más tarde.", en: "Something went wrong. Please try again later.",
    it: "Si è verificato un errore. Riprova più tardi.", de: "Etwas ist schiefgelaufen. Bitte versuche es später erneut.",
    ca: "S'ha produït un error. Torna-ho a provar més tard.", eo: "Okazis eraro. Bonvolu reprovi poste.",
    nl: "Er ging iets mis. Probeer het later opnieuw.", el: "Κάτι πήγε στραβά. Δοκίμασε ξανά αργότερα."
  },
  "lettre.landing.unsubscribed": {
    "pt-BR": "Pronto! Deixaste de receber o Boletim da rede.",
    fr: "C'est fait : tu es désabonné·e de la Lettre de la fédération.",
    es: "Listo: te has dado de baja del Boletín de la red.",
    en: "Done: you've been unsubscribed from the federation letter.",
    it: "Fatto: la tua iscrizione alla Lettera della rete è stata annullata.",
    de: "Erledigt: Du hast den Netzwerk-Rundbrief abbestellt.",
    ca: "Fet: t'has donat de baixa del Butlletí de la xarxa.",
    eo: "Farite: vi malabonis la retan bultenon.",
    nl: "Klaar: je bent uitgeschreven voor de nieuwsbrief van het netwerk.",
    el: "Έτοιμο: διαγράφηκες από το ενημερωτικό δελτίο του δικτύου."
  },

  // === Lettre de la fédération — numéros (Lot 3) ===
  "lettre.issue.subject": {
    "pt-BR": "Boletim da rede — n.º {number}",
    fr: "Lettre de la fédération — n°{number}",
    es: "Boletín de la red — n.º {number}",
    en: "Federation letter — no. {number}",
    it: "Lettera della rete — n. {number}",
    de: "Netzwerk-Rundbrief — Nr. {number}",
    ca: "Butlletí de la xarxa — núm. {number}",
    eo: "Reta bulteno — n-ro {number}",
    nl: "Nieuwsbrief van het netwerk — nr. {number}",
    el: "Ενημερωτικό δελτίο του δικτύου — αρ. {number}"
  },
  "lettre.issue.section.circles": {
    "pt-BR": "Novos círculos", fr: "Nouveaux cercles", es: "Nuevos círculos", en: "New circles",
    it: "Nuovi circoli", de: "Neue Kreise", ca: "Nous cercles", eo: "Novaj rondoj",
    nl: "Nieuwe kringen", el: "Νέοι κύκλοι"
  },
  "lettre.issue.section.assemblies": {
    "pt-BR": "Assembleias por vir", fr: "Assemblées à venir", es: "Asambleas próximas", en: "Upcoming assemblies",
    it: "Assemblee in arrivo", de: "Kommende Versammlungen", ca: "Assemblees properes", eo: "Venontaj asembleoj",
    nl: "Komende vergaderingen", el: "Επερχόμενες συνελεύσεις"
  },
  "lettre.issue.gazetteLink": {
    "pt-BR": "Saiu o n.º {number} da Rizoma — vem ler",
    fr: "Le n°{number} de Rizoma est paru — à lire",
    es: "Ya salió el n.º {number} de Rizoma — a leer",
    en: "Rizoma no. {number} is out — read it",
    it: "È uscito il n. {number} di Rizoma — da leggere",
    de: "Rizoma Nr. {number} ist da — zum Lesen",
    ca: "Ja ha sortit el núm. {number} de Rizoma — a llegir",
    eo: "Aperis la n-ro {number} de Rizoma — legu ĝin",
    nl: "Rizoma nr. {number} is uit — lees mee",
    el: "Κυκλοφόρησε το αρ. {number} της Rizoma — διάβασέ το"
  },
  "lettre.issue.empty": {
    "pt-BR": "Nada de novo desta vez — até breve.", fr: "Rien de neuf cette fois — à très vite.",
    es: "Nada nuevo esta vez — hasta pronto.", en: "Nothing new this time — see you soon.",
    it: "Niente di nuovo stavolta — a presto.", de: "Diesmal nichts Neues — bis bald.",
    ca: "Res de nou aquest cop — fins aviat.", eo: "Nenio nova ĉi-foje — ĝis baldaŭ.",
    nl: "Niets nieuws deze keer — tot snel.", el: "Τίποτα νέο αυτή τη φορά — τα λέμε σύντομα."
  },
  "lettre.issue.unsubscribePrefix": {
    "pt-BR": "Recebes este boletim porque te inscreveste nele.",
    fr: "Tu reçois cette lettre parce que tu t'y es abonné·e.",
    es: "Recibes este boletín porque te suscribiste a él.",
    en: "You're receiving this letter because you subscribed to it.",
    it: "Ricevi questa lettera perché ti sei iscritt* a essa.",
    de: "Du erhältst diesen Rundbrief, weil du ihn abonniert hast.",
    ca: "Reps aquest butlletí perquè t'hi vas subscriure.",
    eo: "Vi ricevas ĉi tiun bultenon ĉar vi abonis ĝin.",
    nl: "Je ontvangt deze nieuwsbrief omdat je je ervoor hebt ingeschreven.",
    el: "Λαμβάνεις αυτό το δελτίο επειδή εγγράφηκες σε αυτό."
  },
  "lettre.issue.unsubscribeLink": {
    "pt-BR": "Cancelar inscrição", fr: "Se désabonner", es: "Darse de baja", en: "Unsubscribe",
    it: "Disiscriviti", de: "Abbestellen", ca: "Donar-se de baixa", eo: "Malaboni",
    nl: "Uitschrijven", el: "Διαγραφή"
  },

  "lmsg.reader.sub": {
    "pt-BR": "Mensagem da sua biblioteca",
    fr: "Message de ta bibliothèque",
    es: "Mensaje de tu biblioteca",
    en: "A message from your library",
    it: "Un messaggio dalla tua biblioteca",
    de: "Eine Nachricht deiner Bibliothek",
    ca: "Un missatge de la teva biblioteca",
    eo: "Mesaĝo de via biblioteko",
    nl: "Een bericht van je bibliotheek",
    el: "Ένα μήνυμα από τη βιβλιοθήκη σου"
  },
  "lmsg.reader.intro": {
    "pt-BR": "Sua biblioteca lhe enviou uma mensagem:",
    fr: "Ta bibliothèque t'a écrit :",
    es: "Tu biblioteca te escribió:",
    en: "Your library has sent you a message:",
    it: "La tua biblioteca ti ha scritto:",
    de: "Deine Bibliothek hat dir geschrieben:",
    ca: "La teva biblioteca t'ha escrit:",
    eo: "Via biblioteko skribis al vi:",
    nl: "Je bibliotheek heeft je een bericht gestuurd:",
    el: "Η βιβλιοθήκη σου σού έστειλε ένα μήνυμα:"
  },

  "rmsg.staff.sub": {
    "pt-BR": "Novo recado de uma pessoa da biblioteca",
    fr: "Nouveau message d'un·e lecteur·rice",
    es: "Nuevo mensaje de une lectore",
    en: "New message from a reader",
    it: "Nuovo messaggio da una persona della biblioteca",
    de: "Neue Nachricht von einer*einem Leser*in",
    ca: "Nou missatge d'una persona de la biblioteca",
    eo: "Nova mesaĝo de leganto",
    nl: "Nieuw bericht van een lezer",
    el: "Νέο μήνυμα από έναν/μία αναγνώστη/στρια"
  },
  "rmsg.staff.intro": {
    "pt-BR": "Uma pessoa associada à sua biblioteca enviou um recado pelo sistema.",
    fr: "Une personne associée à votre bibliothèque vous a écrit via le système.",
    es: "Une persona asociade a tu biblioteca te escribió a través del sistema.",
    en: "Someone connected to your library has sent you a message through the system.",
    it: "Una persona associata alla vostra biblioteca vi ha scritto tramite il sistema.",
    de: "Eine mit eurer Bibliothek verbundene Person hat euch über das System geschrieben.",
    ca: "Una persona vinculada a la vostra biblioteca us ha escrit a través del sistema.",
    eo: "Persono ligita al via biblioteko skribis al vi per la sistemo.",
    nl: "Iemand die bij jullie bibliotheek hoort heeft via het systeem een bericht gestuurd.",
    el: "Κάποιο άτομο που σχετίζεται με τη βιβλιοθήκη σας σάς έστειλε μήνυμα μέσω του συστήματος."
  },
  "rmsg.reader.sub": {
    "pt-BR": "Seu recado foi enviado",
    fr: "Ton message a été envoyé",
    es: "Tu mensaje fue enviado",
    en: "Your message has been sent",
    it: "Il tuo messaggio è stato inviato",
    de: "Deine Nachricht wurde gesendet",
    ca: "El teu missatge s'ha enviat",
    eo: "Via mesaĝo estis sendita",
    nl: "Je bericht is verzonden",
    el: "Το μήνυμά σου στάλθηκε"
  },
  "rmsg.reader.intro": {
    "pt-BR": "Recebemos seu recado e avisamos a biblioteca. Aqui está uma cópia:",
    fr: "Nous avons bien reçu ton message et prévenu la bibliothèque. En voici une copie :",
    es: "Recibimos tu mensaje y avisamos a la biblioteca. Aquí tienes una copia:",
    en: "We received your message and notified the library. Here is a copy:",
    it: "Abbiamo ricevuto il tuo messaggio e avvisato la biblioteca. Ecco una copia:",
    de: "Wir haben deine Nachricht erhalten und die Bibliothek benachrichtigt. Hier eine Kopie:",
    ca: "Hem rebut el teu missatge i hem avisat la biblioteca. Aquí en tens una còpia:",
    eo: "Ni ricevis vian mesaĝon kaj avertis la bibliotekon. Jen kopio:",
    nl: "We hebben je bericht ontvangen en de bibliotheek op de hoogte gebracht. Hier is een kopie:",
    el: "Λάβαμε το μήνυμά σου και ειδοποιήσαμε τη βιβλιοθήκη. Ορίστε ένα αντίγραφο:"
  },

  // ===== Greetings ==========================================================
  "greeting.named": {
    "pt-BR": "Olá, {name}!",
    fr: "Bonjour, {name} !",
    es: "¡Hola, {name}!",
    en: "Hello, {name}!",
    it: "Ciao, {name}!",
    de: "Hallo, {name}!",
    ca: "Hola, {name}!",
    eo: "Saluton, {name}!",
    nl: "Hallo, {name}!",
    el: "Γεια σου, {name}!"
  },
  "greeting.anonymous": {
    "pt-BR": "Olá!",
    fr: "Bonjour !",
    es: "¡Hola!",
    en: "Hello!",
    it: "Ciao!",
    de: "Hallo!",
    ca: "Hola!",
    eo: "Saluton!",
    nl: "Hallo!",
    el: "Γεια σου!"
  },

  // ===== Layout =============================================================
  "layout.autoNotice": {
    "pt-BR": "Notificação automática",
    fr: "Notification automatique",
    es: "Notificación automática",
    en: "Automatic notification",
    it: "Notifica automatica",
    de: "Automatische Benachrichtigung",
    ca: "Notificació automàtica",
    eo: "Aŭtomata sciigo",
    nl: "Automatische melding",
    el: "Αυτόματη ειδοποίηση"
  },
  "layout.footerContact": {
    "pt-BR": "Em caso de dúvida, entre em contato com a biblioteca.",
    fr: "En cas de question, contacte la bibliothèque.",
    es: "En caso de duda, contacta la biblioteca.",
    en: "If in doubt, contact the library.",
    it: "In caso di dubbi, contatta la biblioteca.",
    de: "Bei Fragen wende dich an die Bibliothek.",
    ca: "En cas de dubte, contacta la biblioteca.",
    eo: "En kazo de dubo, kontaktu la bibliotekon.",
    nl: "Neem bij twijfel contact op met de bibliotheek.",
    el: "Σε περίπτωση αμφιβολίας, επικοινώνησε με τη βιβλιοθήκη."
  },
  "layout.keepMsg": {
    "pt-BR": "Guarde esta mensagem.",
    fr: "Conserve ce message.",
    es: "Guarda este mensaje.",
    en: "Keep this message.",
    it: "Conserva questo messaggio.",
    de: "Bewahre diese Nachricht auf.",
    ca: "Conserva aquest missatge.",
    eo: "Konservu ĉi tiun mesaĝon.",
    nl: "Bewaar dit bericht.",
    el: "Κράτησε αυτό το μήνυμα."
  },

  // ===== Chantier i18n layout 2B (18/05/2026) — labels footer générique =====
  "layout.phoneLabel": {
    "pt-BR": "Telefone",
    fr: "Téléphone",
    es: "Teléfono",
    en: "Phone",
    it: "Telefono",
    de: "Telefon",
    ca: "Telèfon",
    eo: "Telefono",
    nl: "Telefoon",
    el: "Τηλέφωνο"
  },
  "layout.regimentoLabel": {
    "pt-BR": "Regimento",
    fr: "Règlement",
    es: "Reglamento",
    en: "Regulations",
    it: "Regolamento",
    de: "Reglement",
    ca: "Reglament",
    eo: "Regularo",
    nl: "Reglement",
    el: "Κανονισμός"
  },
  "layout.footerText": {
    "pt-BR": "Mensagem automática da biblioteca. Responda apenas se o campo de resposta indicar um contato local.",
    fr: "Message automatique de la bibliothèque. Réponds uniquement si le champ de réponse indique un contact local.",
    es: "Mensaje automático de la biblioteca. Respondé únicamente si el campo de respuesta indica un contacto local.",
    en: "Automatic message from the library. Reply only if the reply-to field indicates a local contact.",
    it: "Messaggio automatico della biblioteca. Rispondi solo se il campo di risposta indica un contatto locale.",
    de: "Automatische Nachricht der Bibliothek. Antworte nur, wenn das Antwortfeld einen lokalen Kontakt anzeigt.",
    ca: "Missatge automàtic de la biblioteca. Respon únicament si el camp de resposta indica un contacte local.",
    eo: "Aŭtomata mesaĝo de la biblioteko. Respondu nur se la respondkampo indikas lokan kontakton.",
    nl: "Automatisch bericht van de bibliotheek. Antwoord alleen als het antwoordveld een lokaal contact aangeeft.",
    el: "Αυτόματο μήνυμα από τη βιβλιοθήκη. Απάντησε μόνο αν το πεδίο απάντησης υποδεικνύει τοπική επαφή."
  },

  // ===== Labels (l.*) =======================================================
  "l.book": {
    "pt-BR": "Livro",
    fr: "Document",
    es: "Libro",
    en: "Book",
    it: "Libro",
    de: "Buch",
    ca: "Document",
    eo: "Dokumento",
    nl: "Document",
    el: "Βιβλίο"
  },
  "l.items": {
    "pt-BR": "Itens",
    fr: "Documents",
    es: "Documentos",
    en: "Items",
    it: "Documenti",
    de: "Dokumente",
    ca: "Documents",
    eo: "Dokumentoj",
    nl: "Documenten",
    el: "Τεκμήρια"
  },
  "l.itemsReturned": {
    "pt-BR": "Documentos devolvidos",
    fr: "Documents rendus",
    es: "Documentos devueltos",
    en: "Documents returned",
    it: "Documenti restituiti",
    de: "Zurückgegebene Dokumente",
    ca: "Documents retornats",
    eo: "Redonitaj dokumentoj",
    nl: "Ingeleverde documenten",
    el: "Τεκμήρια που επιστράφηκαν"
  },
  "l.itemsRemaining": {
    "pt-BR": "Documentos ainda em mãos",
    fr: "Documents encore à rendre",
    es: "Documentos todavía pendientes",
    en: "Documents still to return",
    it: "Documenti ancora da restituire",
    de: "Noch zurückzugebende Dokumente",
    ca: "Documents encara per retornar",
    eo: "Dokumentoj ankoraŭ redonendaj",
    nl: "Nog in te leveren documenten",
    el: "Τεκμήρια προς επιστροφή"
  },
  "l.ref": {
    "pt-BR": "Referência",
    fr: "Référence",
    es: "Referencia",
    en: "Reference",
    it: "Riferimento",
    de: "Referenz",
    ca: "Referència",
    eo: "Referenco",
    nl: "Referentie",
    el: "Αναφορά"
  },
  "l.refs": {
    "pt-BR": "Referências",
    fr: "Références",
    es: "Referencias",
    en: "References",
    it: "Riferimenti",
    de: "Referenzen",
    ca: "Referències",
    eo: "Referencoj",
    nl: "Referenties",
    el: "Αναφορές"
  },
  "l.ids": {
    "pt-BR": "IDs",
    fr: "IDs",
    es: "IDs",
    en: "IDs",
    it: "IDs",
    de: "IDs",
    ca: "IDs",
    eo: "IDoj",
    nl: "ID's",
    el: "IDs"
  },
  "l.date": {
    "pt-BR": "Data",
    fr: "Date",
    es: "Fecha",
    en: "Date",
    it: "Data",
    de: "Datum",
    ca: "Data",
    eo: "Dato",
    nl: "Datum",
    el: "Ημερομηνία"
  },
  "l.executed_at": {
    "pt-BR": "Data de execução",
    fr: "Date d'exécution",
    es: "Fecha de ejecución",
    en: "Execution date",
    it: "Data di esecuzione",
    de: "Ausführungsdatum",
    ca: "Data d'execució",
    eo: "Plenuma dato",
    nl: "Uitvoeringsdatum",
    el: "Ημερομηνία εκτέλεσης"
  },
  "l.dueDate": {
    "pt-BR": "Devolução prevista",
    fr: "Retour prévu",
    es: "Devolución prevista",
    en: "Due date",
    it: "Restituzione prevista",
    de: "Fälligkeitsdatum",
    ca: "Retorn previst",
    eo: "Planita redono",
    nl: "Inleverdatum",
    el: "Προβλεπόμενη επιστροφή"
  },
  "l.newDueDate": {
    "pt-BR": "Nova devolução",
    fr: "Nouveau retour",
    es: "Nueva devolución",
    en: "New due date",
    it: "Nuova restituzione",
    de: "Neues Fälligkeitsdatum",
    ca: "Nou retorn",
    eo: "Nova redono",
    nl: "Nieuwe inleverdatum",
    el: "Νέα προβλεπόμενη επιστροφή"
  },
  "l.deadline": {
    "pt-BR": "Prazo",
    fr: "Échéance",
    es: "Plazo",
    en: "Deadline",
    it: "Scadenza",
    de: "Frist",
    ca: "Termini",
    eo: "Limdato",
    nl: "Uiterste datum",
    el: "Προθεσμία"
  },
  "l.registration": {
    "pt-BR": "Registro",
    fr: "Enregistrement",
    es: "Registro",
    en: "Registration",
    it: "Registrazione",
    de: "Registrierung",
    ca: "Registre",
    eo: "Registro",
    nl: "Registratie",
    el: "Καταχώριση"
  },
  "l.renewal": {
    "pt-BR": "Renovação em",
    fr: "Renouvelé le",
    es: "Renovación el",
    en: "Renewed on",
    it: "Rinnovo il",
    de: "Verlängert am",
    ca: "Renovació el",
    eo: "Renovigo la",
    nl: "Verlengd op",
    el: "Ανανεώθηκε στις"
  },
  "l.return": {
    "pt-BR": "Devolução",
    fr: "Retour",
    es: "Devolución",
    en: "Return",
    it: "Restituzione",
    de: "Rückgabe",
    ca: "Retorn",
    eo: "Redono",
    nl: "Inlevering",
    el: "Επιστροφή"
  },
  "l.reader": {
    "pt-BR": "Leitor(a/e)",
    fr: "Lecteur·rice",
    es: "Lector(a/e)",
    en: "Reader",
    it: "Lettore/trice",
    de: "Leser*in",
    ca: "Lector-a-e",
    eo: "Legant-in-o",
    nl: "Lezer",
    el: "Αναγνώστης/στρια"
  },
  "l.pickup": {
    "pt-BR": "Retirada",
    fr: "Retrait",
    es: "Retiro",
    en: "Pickup",
    it: "Ritiro",
    de: "Abholung",
    ca: "Recollida",
    eo: "Elpreno",
    nl: "Afhaling",
    el: "Παραλαβή"
  },
  "l.status": {
    "pt-BR": "Situação",
    fr: "Situation",
    es: "Situación",
    en: "Status",
    it: "Situazione",
    de: "Status",
    ca: "Situació",
    eo: "Situacio",
    nl: "Status",
    el: "Κατάσταση"
  },
  "l.reason": {
    "pt-BR": "Motivo",
    fr: "Motif",
    es: "Motivo",
    en: "Reason",
    it: "Motivo",
    de: "Grund",
    ca: "Motiu",
    eo: "Motivo",
    nl: "Reden",
    el: "Λόγος"
  },
  "l.note": {
    "pt-BR": "Observação",
    fr: "Observation",
    es: "Observación",
    en: "Note",
    it: "Osservazione",
    de: "Anmerkung",
    ca: "Observació",
    eo: "Observo",
    nl: "Opmerking",
    el: "Παρατήρηση"
  },
  "l.contact": {
    "pt-BR": "Contato",
    fr: "Contact",
    es: "Contacto",
    en: "Contact",
    it: "Contatto",
    de: "Kontakt",
    ca: "Contacte",
    eo: "Kontakto",
    nl: "Contact",
    el: "Επαφή"
  },
  "l.task": {
    "pt-BR": "Tarefa",
    fr: "Tâche",
    es: "Tarea",
    en: "Task",
    it: "Compito",
    de: "Aufgabe",
    ca: "Tasca",
    eo: "Tasko",
    nl: "Taak",
    el: "Εργασία"
  },
  "l.priority": {
    "pt-BR": "Prioridade",
    fr: "Priorité",
    es: "Prioridad",
    en: "Priority",
    it: "Priorità",
    de: "Priorität",
    ca: "Prioritat",
    eo: "Prioritato",
    nl: "Prioriteit",
    el: "Προτεραιότητα"
  },
  "l.tags": {
    "pt-BR": "Marcadores",
    fr: "Étiquettes",
    es: "Etiquetas",
    en: "Tags",
    it: "Etichette",
    de: "Schlagwörter",
    ca: "Etiquetes",
    eo: "Etikedoj",
    nl: "Tags",
    el: "Ετικέτες"
  },
  "l.firstDate": {
    "pt-BR": "Próximo vencimento",
    fr: "Prochaine échéance",
    es: "Próximo vencimiento",
    en: "Next due date",
    it: "Prossima scadenza",
    de: "Nächste Fälligkeit",
    ca: "Proper venciment",
    eo: "Sekva limdato",
    nl: "Volgende inleverdatum",
    el: "Επόμενη προθεσμία"
  },
  "l.pendingItems": {
    "pt-BR": "Itens pendentes",
    fr: "Documents en cours",
    es: "Documentos pendientes",
    en: "Pending items",
    it: "Documenti in corso",
    de: "Offene Dokumente",
    ca: "Documents en curs",
    eo: "Kurantaj dokumentoj",
    nl: "Lopende documenten",
    el: "Τεκμήρια σε εκκρεμότητα"
  },
  "l.readerNote": {
    "pt-BR": "Observação d(o/a/e) leitor(a/e)",
    fr: "Note du·de la lecteur·rice",
    es: "Nota de le lector(a/e)",
    en: "Reader note",
    it: "Nota del/la lettore/trice",
    de: "Anmerkung der*des Leser*in",
    ca: "Nota de le lector-a-e",
    eo: "Noto de la legant-in-o",
    nl: "Opmerking van de lezer",
    el: "Σημείωση αναγνώστη/στριας"
  },
  "l.reply": {
    "pt-BR": "Resposta",
    fr: "Réponse",
    es: "Respuesta",
    en: "Reply",
    it: "Risposta",
    de: "Antwort",
    ca: "Resposta",
    eo: "Respondo",
    nl: "Antwoord",
    el: "Απάντηση"
  },
  "l.restrictedSince": {
    "pt-BR": "Restrição desde",
    fr: "Restriction depuis",
    es: "Restricción desde",
    en: "Restricted since",
    it: "Restrizione da",
    de: "Eingeschränkt seit",
    ca: "Restricció des de",
    eo: "Restrikto ekde",
    nl: "Beperkt sinds",
    el: "Σε περιορισμό από"
  },

  // ===== Reservation events (res.*) =========================================
  "res.created.sub": {
    "pt-BR": "Reserva registrada",
    fr: "Réservation enregistrée",
    es: "Reserva registrada",
    en: "Reservation registered",
    it: "Prenotazione registrata",
    de: "Vormerkung registriert",
    ca: "Reserva registrada",
    eo: "Rezervo registrita",
    nl: "Reservering geregistreerd",
    el: "Η κράτηση καταχωρίστηκε"
  },
  "res.created.pre": {
    "pt-BR": "Sua reserva foi registrada com sucesso.",
    fr: "Ta réservation a bien été enregistrée.",
    es: "Tu reserva fue registrada con éxito.",
    en: "Your reservation has been registered.",
    it: "La tua prenotazione è stata registrata.",
    de: "Deine Vormerkung wurde registriert.",
    ca: "La teva reserva s'ha registrat correctament.",
    eo: "Via rezervo estis sukcese registrita.",
    nl: "Je reservering is geregistreerd.",
    el: "Η κράτησή σου καταχωρίστηκε."
  },
  "res.created.intro": {
    "pt-BR": "Recebemos sua reserva. A biblioteca confirmará a disponibilidade em breve.",
    fr: "Nous avons reçu ta réservation. La bibliothèque confirmera bientôt la disponibilité.",
    es: "Recibimos tu reserva. La biblioteca confirmará pronto la disponibilidad.",
    en: "We received your reservation. The library will confirm availability soon.",
    it: "Abbiamo ricevuto la tua prenotazione. La biblioteca confermerà presto la disponibilità.",
    de: "Wir haben deine Vormerkung erhalten. Die Bibliothek bestätigt bald die Verfügbarkeit.",
    ca: "Hem rebut la teva reserva. La biblioteca confirmarà aviat la disponibilitat.",
    eo: "Ni ricevis vian rezervon. La biblioteko baldaŭ konfirmos la disponeblecon.",
    nl: "We hebben je reservering ontvangen. De bibliotheek bevestigt binnenkort de beschikbaarheid.",
    el: "Λάβαμε την κράτησή σου. Η βιβλιοθήκη θα επιβεβαιώσει σύντομα τη διαθεσιμότητα."
  },
  "res.created.hint": {
    "pt-BR": "Você pode acompanhar o estado d(o/a/e) seu pedido na sua conta.",
    fr: "Tu peux suivre l'état de ta demande dans ton compte.",
    es: "Puedes seguir le estade de tu pedido en tu cuenta.",
    en: "You can track your request status in your account.",
    it: "Puoi seguire lo stato della tua richiesta nel tuo account.",
    de: "Du kannst den Status deiner Anfrage in deinem Konto verfolgen.",
    ca: "Pots seguir l'estat de le teu sol·licitud al teu compte.",
    eo: "Vi povas sekvi la staton de via peto en via konto.",
    nl: "Je kunt de status van je aanvraag volgen in je account.",
    el: "Μπορείς να παρακολουθείς την κατάσταση του αιτήματός σου στον λογαριασμό σου."
  },
  "res.created.admin": {
    "pt-BR": "Nova reserva registrada",
    fr: "Nouvelle réservation enregistrée",
    es: "Nueva reserva registrada",
    en: "New reservation registered",
    it: "Nuova prenotazione registrata",
    de: "Neue Vormerkung registriert",
    ca: "Nova reserva registrada",
    eo: "Nova rezervo registrita",
    nl: "Nieuwe reservering geregistreerd",
    el: "Καταχωρίστηκε νέα κράτηση"
  },
  "res.refused": {
    "pt-BR": "Reserva recusada pela biblioteca",
    fr: "Réservation refusée par la bibliothèque",
    es: "Reserva rechazada por la biblioteca",
    en: "Reservation declined by the library",
    it: "Prenotazione rifiutata dalla biblioteca",
    de: "Vormerkung von der Bibliothek abgelehnt",
    ca: "Reserva rebutjada per la biblioteca",
    eo: "Rezervo rifuzita de la biblioteko",
    nl: "Reservering geweigerd door de bibliotheek",
    el: "Η κράτηση απορρίφθηκε από τη βιβλιοθήκη"
  },
  "res.cancelStaff.sub": {
    "pt-BR": "Reserva cancelada pela biblioteca",
    fr: "Réservation annulée par la bibliothèque",
    es: "Reserva cancelada por la biblioteca",
    en: "Reservation cancelled by the library",
    it: "Prenotazione annullata dalla biblioteca",
    de: "Vormerkung von der Bibliothek storniert",
    ca: "Reserva cancel·lada per la biblioteca",
    eo: "Rezervo nuligita de la biblioteko",
    nl: "Reservering geannuleerd door de bibliotheek",
    el: "Η κράτηση ακυρώθηκε από τη βιβλιοθήκη"
  },
  "res.cancelStaff.intro": {
    "pt-BR": "Informamos que a biblioteca precisou cancelar a sua reserva. Isso não é uma recusa do seu pedido: o exemplar pode estar indisponível, danificado ou já de volta à circulação. Você pode reservá-lo novamente mais tarde, ou passar na biblioteca para encontrarmos uma solução junt-o-a-e.",
    fr: "Nous t'informons que la bibliothèque a dû annuler ta réservation. Ce n'est pas un refus de ta démarche : l'exemplaire peut être indisponible, abîmé, ou déjà reparti en circulation. Tu peux le réserver à nouveau plus tard, ou passer à la bibliothèque pour qu'on trouve une solution ensemble.",
    es: "Te informamos de que la biblioteca tuvo que cancelar tu reserva. No es un rechazo de tu solicitud: el ejemplar puede estar no disponible, dañado o ya de vuelta en circulación. Puedes reservarlo de nuevo más adelante, o pasar por la biblioteca para encontrar una solución entre todes.",
    en: "We're letting you know that the library had to cancel your reservation. This isn't a rejection of your request: the copy may be unavailable, damaged, or already back in circulation. You can reserve it again later, or drop by the library so we can find a solution together.",
    it: "Ti informiamo che la biblioteca ha dovuto annullare la tua prenotazione. Non è un rifiuto della tua richiesta: la copia può essere non disponibile, danneggiata o già tornata in circolazione. Puoi prenotarla di nuovo più avanti, oppure passare in biblioteca per trovare insieme una soluzione.",
    de: "Wir teilen dir mit, dass die Bibliothek deine Vormerkung stornieren musste. Das ist keine Ablehnung deines Anliegens: Das Exemplar kann nicht verfügbar, beschädigt oder bereits wieder im Umlauf sein. Du kannst es später erneut vormerken oder in der Bibliothek vorbeikommen, damit wir gemeinsam eine Lösung finden.",
    ca: "T'informem que la biblioteca ha hagut d'anul·lar la teva reserva. No és un rebuig de la teva sol·licitud: l'exemplar pot estar no disponible, malmès o ja de tornada en circulació. El pots reservar de nou més endavant, o passar per la biblioteca per trobar una solució plegades.",
    eo: "Ni informas vin, ke la biblioteko devis nuligi vian rezervon. Tio ne estas rifuzo de via peto: la ekzemplero povas esti nedisponebla, difektita aŭ jam reen en cirkulado. Vi povas rezervi ĝin denove poste, aŭ viziti la bibliotekon por ke ni trovu solvon kune.",
    nl: "We laten je weten dat de bibliotheek je reservering heeft moeten annuleren. Dit is geen afwijzing van je aanvraag: het exemplaar kan onbeschikbaar of beschadigd zijn, of alweer terug in circulatie. Je kunt het later opnieuw reserveren, of langskomen bij de bibliotheek zodat we samen een oplossing vinden.",
    el: "Σου γνωστοποιούμε ότι η βιβλιοθήκη χρειάστηκε να ακυρώσει την κράτησή σου. Δεν πρόκειται για απόρριψη του αιτήματός σου: το αντίτυπο μπορεί να είναι μη διαθέσιμο, φθαρμένο ή να έχει ήδη επιστρέψει στην κυκλοφορία. Μπορείς να το ξανακρατήσεις αργότερα ή να περάσεις από τη βιβλιοθήκη για να βρούμε μαζί μια λύση."
  },
  "res.cancelStaff.adminIntro": {
    "pt-BR": "Uma reserva foi cancelada pela biblioteca. Os exemplares correspondentes foram automaticamente recolocados em circulação. O motivo registrado no momento do cancelamento está indicado abaixo.",
    fr: "Une réservation a été annulée par la bibliothèque. Les exemplaires concernés ont été automatiquement remis en circulation. Le motif saisi au moment de l'annulation est indiqué ci-dessous.",
    es: "Una reserva fue cancelada por la biblioteca. Los ejemplares correspondientes se han vuelto a poner en circulación automáticamente. El motivo registrado en el momento de la cancelación se indica a continuación.",
    en: "A reservation was cancelled by the library. The corresponding copies have been automatically returned to circulation. The reason entered at the time of cancellation is shown below.",
    it: "Una prenotazione è stata annullata dalla biblioteca. Le copie corrispondenti sono state automaticamente rimesse in circolazione. Il motivo registrato al momento dell'annullamento è indicato qui sotto.",
    de: "Eine Vormerkung wurde von der Bibliothek storniert. Die betreffenden Exemplare wurden automatisch wieder in den Umlauf gegeben. Der bei der Stornierung angegebene Grund ist unten aufgeführt.",
    ca: "Una reserva ha estat anul·lada per la biblioteca. Els exemplars corresponents s'han tornat a posar en circulació automàticament. El motiu registrat en el moment de l'anul·lació s'indica a continuació.",
    eo: "Rezervo estis nuligita de la biblioteko. La koncernaj ekzempleroj estis aŭtomate remetitaj en cirkuladon. La kialo registrita dum la nuligo estas montrita sube.",
    nl: "Een reservering is geannuleerd door de bibliotheek. De betreffende exemplaren zijn automatisch terug in circulatie gebracht. De reden die bij de annulering is ingevoerd, staat hieronder.",
    el: "Μια κράτηση ακυρώθηκε από τη βιβλιοθήκη. Τα σχετικά αντίτυπα επέστρεψαν αυτόματα στην κυκλοφορία. Ο λόγος που καταχωρίστηκε κατά την ακύρωση εμφανίζεται παρακάτω."
  },
  "res.cancelReader.sub": {
    "pt-BR": "Reserva cancelada por você",
    fr: "Réservation annulée par toi",
    es: "Reserva cancelada por ti",
    en: "Reservation cancelled by you",
    it: "Prenotazione annullata da te",
    de: "Vormerkung von dir storniert",
    ca: "Reserva cancel·lada per tu",
    eo: "Rezervo nuligita de vi",
    nl: "Reservering door jou geannuleerd",
    el: "Η κράτηση ακυρώθηκε από εσένα"
  },
  "res.cancelReader.intro": {
    "pt-BR": "Confirmamos que a sua reserva foi cancelada a seu pedido. O exemplar volta a ficar disponível para outras pessoas. Você pode fazer uma nova reserva quando quiser.",
    fr: "Nous confirmons que ta réservation a bien été annulée à ta demande. L'exemplaire redevient disponible pour d'autres personnes. Tu peux faire une nouvelle réservation quand tu le souhaites.",
    es: "Confirmamos que tu reserva se ha cancelado a petición tuya. El ejemplar vuelve a estar disponible para otras personas. Puedes hacer una nueva reserva cuando quieras.",
    en: "We confirm that your reservation has been cancelled at your request. The copy is available again for other people. You can make a new reservation whenever you like.",
    it: "Confermiamo che la tua prenotazione è stata annullata su tua richiesta. La copia torna disponibile per altre persone. Puoi fare una nuova prenotazione quando vuoi.",
    de: "Wir bestätigen, dass deine Vormerkung auf deinen Wunsch hin storniert wurde. Das Exemplar ist wieder für andere Personen verfügbar. Du kannst jederzeit eine neue Vormerkung vornehmen.",
    ca: "Confirmem que la teva reserva s'ha anul·lat a petició teva. L'exemplar torna a estar disponible per a altres persones. Pots fer una nova reserva quan vulguis.",
    eo: "Ni konfirmas, ke via rezervo estis nuligita laŭ via peto. La ekzemplero denove disponeblas por aliaj personoj. Vi povas fari novan rezervon kiam ajn vi volas.",
    nl: "We bevestigen dat je reservering op je verzoek is geannuleerd. Het exemplaar is weer beschikbaar voor anderen. Je kunt een nieuwe reservering maken wanneer je maar wilt.",
    el: "Επιβεβαιώνουμε ότι η κράτησή σου ακυρώθηκε κατόπιν αιτήματός σου. Το αντίτυπο γίνεται ξανά διαθέσιμο για άλλα άτομα. Μπορείς να κάνεις νέα κράτηση όποτε θέλεις."
  },
  "res.cancelReader.adminIntro": {
    "pt-BR": "Um-a-e leitor-a-e cancelou a própria reserva. Os exemplares correspondentes foram automaticamente recolocados em circulação. Nenhuma ação da equipe é necessária.",
    fr: "Un·e lecteur·rice a annulé sa propre réservation. Les exemplaires concernés ont été automatiquement remis en circulation. Aucune action de l'équipe n'est nécessaire.",
    es: "Une lectore ha cancelado su propia reserva. Los ejemplares correspondientes se han vuelto a poner en circulación automáticamente. No se requiere ninguna acción del equipo.",
    en: "A reader has cancelled their own reservation. The corresponding copies have been automatically returned to circulation. No action from the team is needed.",
    it: "Un* lettore* ha annullato la propria prenotazione. Le copie corrispondenti sono state automaticamente rimesse in circolazione. Non è necessaria alcuna azione da parte dell'équipe.",
    de: "Eine lesende Person hat ihre eigene Vormerkung storniert. Die betreffenden Exemplare wurden automatisch wieder in den Umlauf gegeben. Es ist keine Aktion des Teams erforderlich.",
    ca: "Un·a lector·a ha anul·lat la seva pròpia reserva. Els exemplars corresponents s'han tornat a posar en circulació automàticament. No cal cap acció de l'equip.",
    eo: "Leganto nuligis sian propran rezervon. La koncernaj ekzempleroj estis aŭtomate remetitaj en cirkuladon. Neniu ago de la teamo necesas.",
    nl: "Een lezer heeft de eigen reservering geannuleerd. De betreffende exemplaren zijn automatisch terug in circulatie gebracht. Er is geen actie van het team nodig.",
    el: "Ένας/Μία αναγνώστης/στρια ακύρωσε τη δική του/της κράτηση. Τα σχετικά αντίτυπα επέστρεψαν αυτόματα στην κυκλοφορία. Δεν απαιτείται καμία ενέργεια από την ομάδα."
  },
  // Sujet de la COPIE BIBLIO (≠ sujet lecteur·rice « …par toi/vous ») : doit
  // indiquer que c'est le/la lecteur·rice qui a annulé, jamais la biblio.
  "res.cancelReader.adminSub": {
    "pt-BR": "Reserva cancelada pelo(a/e) leitor(a/e)",
    fr: "Réservation annulée par le·la lecteur·rice",
    es: "Reserva cancelada por le lector(a/e)",
    en: "Reservation cancelled by the reader",
    it: "Prenotazione annullata dal lettore/trice",
    de: "Vormerkung von der lesenden Person storniert",
    ca: "Reserva cancel·lada per le lector-a-e",
    eo: "Rezervo nuligita de la legant-in-o",
    nl: "Reservering geannuleerd door de lezer",
    el: "Η κράτηση ακυρώθηκε από τον/την αναγνώστη/στρια"
  },
  "res.expired.sub": {
    "pt-BR": "Reserva expirada",
    fr: "Réservation expirée",
    es: "Reserva expirada",
    en: "Reservation expired",
    it: "Prenotazione scaduta",
    de: "Vormerkung abgelaufen",
    ca: "Reserva expirada",
    eo: "Rezervo eksvalidiĝinta",
    nl: "Reservering verlopen",
    el: "Η κράτηση έληξε"
  },
  "res.expired.intro": {
    "pt-BR": "Informamos que a sua reserva expirou: o prazo para retirar o exemplar foi ultrapassado. O exemplar volta à circulação para outras pessoas. Se ainda tiver interesse, você pode fazer uma nova reserva quando quiser.",
    fr: "Nous t'informons que ta réservation a expiré : le délai pour retirer l'exemplaire a été dépassé. L'exemplaire repart en circulation pour d'autres personnes. Si tu es toujours intéressé·e, tu peux faire une nouvelle réservation quand tu le souhaites.",
    es: "Te informamos de que tu reserva ha expirado: se ha superado el plazo para retirar el ejemplar. El ejemplar vuelve a la circulación para otras personas. Si todavía te interesa, puedes hacer una nueva reserva cuando quieras.",
    en: "We're letting you know that your reservation has expired: the deadline to pick up the copy has passed. The copy returns to circulation for other people. If you're still interested, you can make a new reservation whenever you like.",
    it: "Ti informiamo che la tua prenotazione è scaduta: il termine per ritirare la copia è stato superato. La copia torna in circolazione per altre persone. Se sei ancora interessat*, puoi fare una nuova prenotazione quando vuoi.",
    de: "Wir teilen dir mit, dass deine Vormerkung abgelaufen ist: Die Frist zur Abholung des Exemplars ist verstrichen. Das Exemplar geht wieder in den Umlauf für andere Personen. Wenn du weiterhin Interesse hast, kannst du jederzeit eine neue Vormerkung vornehmen.",
    ca: "T'informem que la teva reserva ha expirat: s'ha superat el termini per recollir l'exemplar. L'exemplar torna a la circulació per a altres persones. Si encara t'interessa, pots fer una nova reserva quan vulguis.",
    eo: "Ni informas vin, ke via rezervo eksvalidiĝis: la limdato por preni la ekzempleron pasis. La ekzemplero revenas en cirkuladon por aliaj personoj. Se vi ankoraŭ interesiĝas, vi povas fari novan rezervon kiam ajn vi volas.",
    nl: "We laten je weten dat je reservering is verlopen: de termijn om het exemplaar af te halen is verstreken. Het exemplaar gaat terug in circulatie voor anderen. Ben je nog steeds geïnteresseerd, dan kun je een nieuwe reservering maken wanneer je maar wilt.",
    el: "Σου γνωστοποιούμε ότι η κράτησή σου έληξε: η προθεσμία παραλαβής του αντιτύπου παρήλθε. Το αντίτυπο επιστρέφει στην κυκλοφορία για άλλα άτομα. Αν εξακολουθείς να ενδιαφέρεσαι, μπορείς να κάνεις νέα κράτηση όποτε θέλεις."
  },
  "res.expired.adminIntro": {
    "pt-BR": "Uma reserva expirou automaticamente: o prazo de retirada foi ultrapassado sem que o exemplar fosse retirado. Os exemplares correspondentes voltaram à circulação. Nenhuma ação da equipe é necessária.",
    fr: "Une réservation a expiré automatiquement : le délai de retrait a été dépassé sans que l'exemplaire soit retiré. Les exemplaires concernés sont repartis en circulation. Aucune action de l'équipe n'est nécessaire.",
    es: "Una reserva ha expirado automáticamente: se superó el plazo de retirada sin que se recogiera el ejemplar. Los ejemplares correspondientes han vuelto a la circulación. No se requiere ninguna acción del equipo.",
    en: "A reservation has expired automatically: the pickup deadline passed without the copy being collected. The corresponding copies have returned to circulation. No action from the team is needed.",
    it: "Una prenotazione è scaduta automaticamente: il termine di ritiro è stato superato senza che la copia venisse ritirata. Le copie corrispondenti sono tornate in circolazione. Non è necessaria alcuna azione da parte dell'équipe.",
    de: "Eine Vormerkung ist automatisch abgelaufen: Die Abholfrist ist verstrichen, ohne dass das Exemplar abgeholt wurde. Die betreffenden Exemplare sind wieder in den Umlauf gegangen. Es ist keine Aktion des Teams erforderlich.",
    ca: "Una reserva ha expirat automàticament: s'ha superat el termini de recollida sense que es recollís l'exemplar. Els exemplars corresponents han tornat a la circulació. No cal cap acció de l'equip.",
    eo: "Rezervo aŭtomate eksvalidiĝis: la limdato de preno pasis sen ke la ekzemplero estu prenita. La koncernaj ekzempleroj revenis en cirkuladon. Neniu ago de la teamo necesas.",
    nl: "Een reservering is automatisch verlopen: de afhaaltermijn is verstreken zonder dat het exemplaar is opgehaald. De betreffende exemplaren zijn terug in circulatie. Er is geen actie van het team nodig.",
    el: "Μια κράτηση έληξε αυτόματα: η προθεσμία παραλαβής παρήλθε χωρίς να παραληφθεί το αντίτυπο. Τα σχετικά αντίτυπα επέστρεψαν στην κυκλοφορία. Δεν απαιτείται καμία ενέργεια από την ομάδα."
  },
  "res.converted.sub": {
    "pt-BR": "Reserva convertida em empréstimo",
    fr: "Réservation convertie en emprunt",
    es: "Reserva convertida en préstamo",
    en: "Reservation converted into a loan",
    it: "Prenotazione convertita in prestito",
    de: "Vormerkung in Ausleihe umgewandelt",
    ca: "Reserva convertida en préstec",
    eo: "Rezervo konvertita en prunton",
    nl: "Reservering omgezet in een uitlening",
    el: "Η κράτηση μετατράπηκε σε δανεισμό"
  },
  "res.converted.intro": {
    "pt-BR": "Boa notícia: a sua reserva foi convertida em empréstimo. O exemplar agora está com você. A data de devolução prevista está indicada abaixo — você receberá um lembrete quando ela se aproximar.",
    fr: "Bonne nouvelle : ta réservation a été convertie en emprunt. L'exemplaire est désormais entre tes mains. La date de retour prévue est indiquée ci-dessous — tu recevras un rappel à l'approche de l'échéance.",
    es: "Buena noticia: tu reserva se ha convertido en préstamo. El ejemplar ya está contigo. La fecha de devolución prevista se indica a continuación — recibirás un recordatorio cuando se acerque.",
    en: "Good news: your reservation has been converted into a loan. The copy is now in your hands. The expected return date is shown below — you'll get a reminder as it approaches.",
    it: "Buona notizia: la tua prenotazione è stata convertita in prestito. La copia è ora nelle tue mani. La data di restituzione prevista è indicata qui sotto — riceverai un promemoria all'avvicinarsi della scadenza.",
    de: "Gute Nachricht: Deine Vormerkung wurde in eine Ausleihe umgewandelt. Das Exemplar ist nun in deinen Händen. Das voraussichtliche Rückgabedatum ist unten angegeben — du erhältst eine Erinnerung, wenn es näher rückt.",
    ca: "Bona notícia: la teva reserva s'ha convertit en préstec. L'exemplar ja és a les teves mans. La data de retorn prevista s'indica a continuació — rebràs un recordatori quan s'acosti.",
    eo: "Bona novaĵo: via rezervo estis konvertita en prunton. La ekzemplero nun estas en viaj manoj. La planita redona dato estas montrita sube — vi ricevos memorigon kiam ĝi proksimiĝos.",
    nl: "Goed nieuws: je reservering is omgezet in een uitlening. Het exemplaar is nu in jouw handen. De verwachte inleverdatum staat hieronder — je krijgt een herinnering wanneer die nadert.",
    el: "Καλά νέα: η κράτησή σου μετατράπηκε σε δανεισμό. Το αντίτυπο είναι πλέον στα χέρια σου. Η προβλεπόμενη ημερομηνία επιστροφής εμφανίζεται παρακάτω — θα λάβεις υπενθύμιση καθώς πλησιάζει."
  },
  "res.converted.adminIntro": {
    "pt-BR": "Uma reserva foi convertida em empréstimo após a retirada presencial do exemplar. O empréstimo está agora ativo. A data de devolução prevista está indicada abaixo.",
    fr: "Une réservation a été convertie en emprunt après le retrait sur place de l'exemplaire. L'emprunt est désormais actif. La date de retour prévue est indiquée ci-dessous.",
    es: "Una reserva se ha convertido en préstamo tras la retirada presencial del ejemplar. El préstamo está ahora activo. La fecha de devolución prevista se indica a continuación.",
    en: "A reservation has been converted into a loan after the copy was picked up in person. The loan is now active. The expected return date is shown below.",
    it: "Una prenotazione è stata convertita in prestito dopo il ritiro in sede della copia. Il prestito è ora attivo. La data di restituzione prevista è indicata qui sotto.",
    de: "Eine Vormerkung wurde nach der persönlichen Abholung des Exemplars in eine Ausleihe umgewandelt. Die Ausleihe ist nun aktiv. Das voraussichtliche Rückgabedatum ist unten angegeben.",
    ca: "Una reserva s'ha convertit en préstec després de la recollida presencial de l'exemplar. El préstec ara està actiu. La data de retorn prevista s'indica a continuació.",
    eo: "Rezervo estis konvertita en prunton post la surloka preno de la ekzemplero. La prunto nun estas aktiva. La planita redona dato estas montrita sube.",
    nl: "Een reservering is omgezet in een uitlening nadat het exemplaar ter plaatse is opgehaald. De uitlening is nu actief. De verwachte inleverdatum staat hieronder.",
    el: "Μια κράτηση μετατράπηκε σε δανεισμό μετά την επιτόπια παραλαβή του αντιτύπου. Ο δανεισμός είναι πλέον ενεργός. Η προβλεπόμενη ημερομηνία επιστροφής εμφανίζεται παρακάτω."
  },

  // ===== Workflow events (wf.*) =============================================
  "wf.pickupScheduled": {
    "pt-BR": "Retirada agendada",
    fr: "Retrait programmé",
    es: "Retiro programado",
    en: "Pickup scheduled",
    it: "Ritiro programmato",
    de: "Abholung geplant",
    ca: "Recollida programada",
    eo: "Elpreno planita",
    nl: "Afhaling gepland",
    el: "Παραλαβή προγραμματισμένη"
  },
  "wf.pickupRescheduled": {
    "pt-BR": "Retirada reagendada",
    fr: "Retrait reprogrammé",
    es: "Retiro reprogramado",
    en: "Pickup rescheduled",
    it: "Ritiro riprogrammato",
    de: "Abholung neu geplant",
    ca: "Recollida reprogramada",
    eo: "Elpreno replanita",
    nl: "Afhaling opnieuw gepland",
    el: "Παραλαβή επαναπρογραμματίστηκε"
  },
  "wf.ready": {
    "pt-BR": "Sua reserva está pronta para retirada",
    fr: "Ta réservation est prête à être retirée",
    es: "Tu reserva está lista para retirar",
    en: "Your reservation is ready for pickup",
    it: "La tua prenotazione è pronta per il ritiro",
    de: "Deine Vormerkung liegt zur Abholung bereit",
    ca: "La teva reserva està llesta per recollir",
    eo: "Via rezervo estas preta por elpreno",
    nl: "Je reservering ligt klaar om af te halen",
    el: "Η κράτησή σου είναι έτοιμη για παραλαβή"
  },
  "wf.readyShort": {
    "pt-BR": "Reserva pronta",
    fr: "Réservation prête",
    es: "Reserva lista",
    en: "Reservation ready",
    it: "Prenotazione pronta",
    de: "Vormerkung bereit",
    ca: "Reserva llesta",
    eo: "Rezervo preta",
    nl: "Reservering klaar",
    el: "Κράτηση έτοιμη"
  },
  "wf.noShow": {
    "pt-BR": "Retirada não realizada",
    fr: "Retrait non effectué",
    es: "Retiro no realizado",
    en: "Pickup missed",
    it: "Ritiro non effettuato",
    de: "Abholung nicht erfolgt",
    ca: "Recollida no efectuada",
    eo: "Elpreno ne efektivigita",
    nl: "Afhaling gemist",
    el: "Η παραλαβή δεν έγινε"
  },
  "wf.closed": {
    "pt-BR": "Reserva encerrada",
    fr: "Réservation clôturée",
    es: "Reserva cerrada",
    en: "Reservation closed",
    it: "Prenotazione chiusa",
    de: "Vormerkung abgeschlossen",
    ca: "Reserva tancada",
    eo: "Rezervo fermita",
    nl: "Reservering afgesloten",
    el: "Η κράτηση έκλεισε"
  },
  "wf.preparing": {
    "pt-BR": "Sua reserva está em preparação",
    fr: "Ta réservation est en préparation",
    es: "Tu reserva está en preparación",
    en: "Your reservation is being prepared",
    it: "La tua prenotazione è in preparazione",
    de: "Deine Vormerkung wird vorbereitet",
    ca: "La teva reserva s'està preparant",
    eo: "Via rezervo estas preparata",
    nl: "Je reservering wordt voorbereid",
    el: "Η κράτησή σου προετοιμάζεται"
  },
  "wf.preparingShort": {
    "pt-BR": "Em preparação",
    fr: "En préparation",
    es: "En preparación",
    en: "Being prepared",
    it: "In preparazione",
    de: "In Vorbereitung",
    ca: "En preparació",
    eo: "En preparado",
    nl: "In voorbereiding",
    el: "Υπό προετοιμασία"
  },
  "wf.toCoordinate": {
    "pt-BR": "Retirada a combinar com a biblioteca",
    fr: "Retrait à organiser avec la bibliothèque",
    es: "Retiro a coordinar con la biblioteca",
    en: "Pickup to be arranged with the library",
    it: "Ritiro da concordare con la biblioteca",
    de: "Abholung mit der Bibliothek abzustimmen",
    ca: "Recollida a coordinar amb la biblioteca",
    eo: "Elpreno interkonsentenda kun la biblioteko",
    nl: "Afhaling te regelen met de bibliotheek",
    el: "Παραλαβή προς συνεννόηση με τη βιβλιοθήκη"
  },
  "wf.toCoordinateShort": {
    "pt-BR": "A combinar",
    fr: "À convenir",
    es: "A coordinar",
    en: "To arrange",
    it: "Da concordare",
    de: "Abzustimmen",
    ca: "A convenir",
    eo: "Interkonsentenda",
    nl: "Te regelen",
    el: "Προς συνεννόηση"
  },
    "wf.checkAccount": {
    "pt-BR": "Confira sua conta para mais detalhes.",
    fr: "Consulte ton compte pour plus de détails.",
    es: "Consulte tu cuenta para más detalles.",
    en: "Check your account for more details.",
    it: "Controlla il tuo account per maggiori dettagli.",
    de: "Sieh in deinem Konto für weitere Details nach.",
    ca: "Consulta el teu compte per a més detalls.",
    eo: "Konsultu vian konton por pliaj detaloj.",
    nl: "Bekijk je account voor meer details.",
    el: "Δες τον λογαριασμό σου για περισσότερες λεπτομέρειες."
  },

  // ===== Workflow v3 — lecteur (wf.reader.*) ================================
  "wf.reader.libraryProposed.subject": {
    "pt-BR": "Horário de retirada proposto pela biblioteca",
    fr: "Créneau de retrait proposé par la biblio",
    es: "Horario de retiro propuesto por la biblioteca",
    en: "Pickup slot proposed by the library",
    it: "Orario di ritiro proposto dalla biblioteca",
    de: "Abholtermin von der Bibliothek vorgeschlagen",
    ca: "Franja de recollida proposada per la biblioteca",
    eo: "Elpren-tempfendo proponita de la biblioteko",
    nl: "Afhaalmoment voorgesteld door de bibliotheek",
    el: "Χρόνος παραλαβής που πρότεινε η βιβλιοθήκη"
  },
  "wf.reader.libraryProposed.body": {
    "pt-BR": "A biblioteca propõe um horário para você vir retirar seu livro. Você pode aceitar este horário, propor outro, ou cancelar a reserva pela sua conta.",
    fr: "La biblio te propose un créneau pour venir retirer ton livre. Tu peux accepter ce créneau, en proposer un autre, ou annuler ta réservation depuis ton compte.",
    es: "La biblioteca te propone un horario para venir a retirar tu libro. Podés aceptar este horario, proponer otro, o cancelar tu reserva desde tu cuenta.",
    en: "The library is proposing a time slot for you to come pick up your book. You can accept this slot, propose another one, or cancel your reservation from your account.",
    it: "La biblioteca ti propone un orario per venire a ritirare il tuo libro. Puoi accettare questo orario, proporne un altro, o annullare la tua prenotazione dal tuo account.",
    de: "Die Bibliothek schlägt dir einen Termin vor, um dein Buch abzuholen. Du kannst diesen Termin annehmen, einen anderen vorschlagen oder deine Vormerkung über dein Konto stornieren.",
    ca: "La biblioteca et proposa una franja per venir a recollir el teu llibre. Pots acceptar aquesta franja, proposar-ne una altra, o cancel·lar la teva reserva des del teu compte.",
    eo: "La biblioteko proponas al vi tempfendon por veni elpreni vian libron. Vi povas akcepti ĉi tiun tempfendon, proponi alian, aŭ nuligi vian rezervon el via konto.",
    nl: "De bibliotheek stelt een tijdslot voor om je boek te komen afhalen. Je kunt dit tijdslot accepteren, een ander voorstellen of je reservering annuleren vanuit je account.",
    el: "Η βιβλιοθήκη σου προτείνει έναν χρόνο για να έρθεις να παραλάβεις το βιβλίο σου. Μπορείς να αποδεχτείς αυτόν τον χρόνο, να προτείνεις άλλον ή να ακυρώσεις την κράτησή σου από τον λογαριασμό σου."
  },
  "wf.reader.youCounterProposed.subject": {
    "pt-BR": "Contra-proposta enviada (tentativa {iter}/{max})",
    fr: "Contre-proposition transmise (essai {iter}/{max})",
    es: "Contrapropuesta enviada (intento {iter}/{max})",
    en: "Counter-proposal sent (attempt {iter}/{max})",
    it: "Controproposta inviata (tentativo {iter}/{max})",
    de: "Gegenvorschlag gesendet (Versuch {iter}/{max})",
    ca: "Contraproposta enviada (intent {iter}/{max})",
    eo: "Kontraŭpropono sendita (provo {iter}/{max})",
    nl: "Tegenvoorstel verzonden (poging {iter}/{max})",
    el: "Αντιπρόταση στάλθηκε (προσπάθεια {iter}/{max})"
  },
  "wf.reader.youCounterProposed.body": {
    "pt-BR": "Sua contra-proposta foi enviada à biblioteca (tentativa {iter}/{max}). Você será avisado(a/e) assim que ela responder.",
    fr: "Ta contre-proposition est bien transmise à la biblio (essai {iter}/{max}). Tu seras prévenu·e dès que celle-ci répond.",
    es: "Tu contrapropuesta fue enviada a la biblioteca (intento {iter}/{max}). Serás avisade en cuanto te respondan.",
    en: "Your counter-proposal has been sent to the library (attempt {iter}/{max}). You will be notified as soon as they reply.",
    it: "La tua controproposta è stata inviata alla biblioteca (tentativo {iter}/{max}). Sarai avvisatə non appena rispondano.",
    de: "Dein Gegenvorschlag wurde an die Bibliothek gesendet (Versuch {iter}/{max}). Du wirst benachrichtigt, sobald geantwortet wird.",
    ca: "La teva contraproposta s'ha enviat a la biblioteca (intent {iter}/{max}). Se t'avisarà tan bon punt respongui.",
    eo: "Via kontraŭpropono estis sendita al la biblioteko (provo {iter}/{max}). Vi estos avertita tuj kiam ĝi respondos.",
    nl: "Je tegenvoorstel is naar de bibliotheek verzonden (poging {iter}/{max}). Je krijgt bericht zodra zij reageren.",
    el: "Η αντιπρότασή σου στάλθηκε στη βιβλιοθήκη (προσπάθεια {iter}/{max}). Θα ειδοποιηθείς μόλις απαντήσει."
  },
  "wf.reader.slotLocked.subject": {
    "pt-BR": "Horário de retirada confirmado",
    fr: "Créneau de retrait confirmé",
    es: "Horario de retiro confirmado",
    en: "Pickup slot confirmed",
    it: "Orario di ritiro confermato",
    de: "Abholtermin bestätigt",
    ca: "Franja de recollida confirmada",
    eo: "Elpren-tempfendo konfirmita",
    nl: "Afhaalmoment bevestigd",
    el: "Ο χρόνος παραλαβής επιβεβαιώθηκε"
  },
  "wf.reader.slotLocked.body": {
    "pt-BR": "O horário está confirmado e bloqueado. O livro estará em breve pronto para retirada — você receberá uma notificação assim que isso acontecer.",
    fr: "Le créneau est confirmé et verrouillé. Le livre sera bientôt prêt à retirer — tu recevras une notification dès que ce sera le cas.",
    es: "El horario está confirmado y bloqueado. El libro estará pronto listo para retirar — recibirás una notificación apenas eso suceda.",
    en: "The slot is confirmed and locked. The book will soon be ready for pickup — you will receive a notification as soon as that happens.",
    it: "L'orario è confermato e bloccato. Il libro sarà presto pronto per il ritiro — riceverai una notifica appena ciò accada.",
    de: "Der Termin ist bestätigt und festgelegt. Das Buch wird bald zur Abholung bereit sein — du erhältst eine Benachrichtigung, sobald dies der Fall ist.",
    ca: "La franja està confirmada i bloquejada. El llibre estarà aviat llest per recollir — rebràs una notificació tan bon punt sigui el cas.",
    eo: "La tempfendo estas konfirmita kaj ŝlosita. La libro baldaŭ estos preta por elpreno — vi ricevos sciigon tuj kiam tio okazos.",
    nl: "Het tijdslot is bevestigd en vergrendeld. Het boek ligt binnenkort klaar om af te halen — je krijgt een melding zodra dat zo is.",
    el: "Ο χρόνος επιβεβαιώθηκε και κλειδώθηκε. Το βιβλίο θα είναι σύντομα έτοιμο για παραλαβή — θα λάβεις ειδοποίηση μόλις γίνει αυτό."
  },
  "wf.reader.maxIterations.subject": {
    "pt-BR": "Negociação sem acordo — contato direto recomendado",
    fr: "Négociation sans accord — contact direct conseillé",
    es: "Negociación sin acuerdo — contacto directo recomendado",
    en: "Negotiation without agreement — direct contact advised",
    it: "Negoziazione senza accordo — contatto diretto consigliato",
    de: "Verhandlung ohne Einigung — direkter Kontakt empfohlen",
    ca: "Negociació sense acord — es recomana contacte directe",
    eo: "Traktado sen interkonsento — rekta kontakto rekomendata",
    nl: "Onderhandeling zonder akkoord — direct contact aangeraden",
    el: "Διαπραγμάτευση χωρίς συμφωνία — συνιστάται άμεση επαφή"
  },
  "wf.reader.maxIterations.body": {
    "pt-BR": "Várias trocas sem encontrar um horário que funcione para todo mundo. Para continuar, o melhor é entrar em contato diretamente com a biblioteca para conversar.",
    fr: "Plusieurs allers-retours sans qu'on trouve un créneau qui convient à tout le monde. Pour continuer, le mieux est de contacter directement la biblio pour en discuter.",
    es: "Varios intercambios sin encontrar un horario que convenga a todes. Para continuar, lo mejor es contactar directamente a la biblioteca para conversar.",
    en: "Several exchanges without finding a time slot that works for everyone. To continue, the best is to contact the library directly to discuss.",
    it: "Diversi scambi senza trovare un orario che vada bene a tuttə. Per continuare, la cosa migliore è contattare direttamente la biblioteca per parlarne.",
    de: "Mehrere Versuche, ohne einen für alle passenden Termin zu finden. Um weiterzukommen, ist es am besten, sich direkt an die Bibliothek zu wenden, um darüber zu sprechen.",
    ca: "Diversos intercanvis sense trobar una franja que funcioni per a tothom. Per continuar, el millor és contactar directament la biblioteca per parlar-ne.",
    eo: "Pluraj interŝanĝoj sen trovi tempfendon kiu konvenas al ĉiuj. Por daŭrigi, plej bone estas kontakti rekte la bibliotekon por priparoli.",
    nl: "Meerdere keren heen en weer zonder een tijdslot te vinden dat voor iedereen werkt. Om verder te gaan, kun je het beste rechtstreeks contact opnemen met de bibliotheek om te overleggen.",
    el: "Αρκετές ανταλλαγές χωρίς να βρεθεί χρόνος που να βολεύει όλους/ες. Για να συνεχίσεις, το καλύτερο είναι να επικοινωνήσεις απευθείας με τη βιβλιοθήκη για να το συζητήσετε."
  },
  "wf.reader.negotiationTimeout.subject": {
    "pt-BR": "Reserva liberada — prazo de negociação expirado",
    fr: "Réservation libérée — délai de négociation dépassé",
    es: "Reserva liberada — plazo de negociación vencido",
    en: "Reservation released — negotiation deadline exceeded",
    it: "Prenotazione liberata — termine di negoziazione scaduto",
    de: "Vormerkung freigegeben — Verhandlungsfrist abgelaufen",
    ca: "Reserva alliberada — termini de negociació vençut",
    eo: "Rezervo liberigita — trakta limdato eksvalidiĝinta",
    nl: "Reservering vrijgegeven — onderhandelingstermijn verstreken",
    el: "Η κράτηση απελευθερώθηκε — η προθεσμία διαπραγμάτευσης παρήλθε"
  },
  "wf.reader.negotiationTimeout.body": {
    "pt-BR": "A negociação do seu horário ultrapassou o prazo sem acordo. A reserva foi liberada e o livro voltou à circulação. Você pode reservá-lo novamente quando quiser.",
    fr: "La négociation pour ton créneau a dépassé le délai sans accord. La réservation a été libérée, le livre repart en circulation. Tu peux le réserver à nouveau quand tu veux.",
    es: "La negociación de tu horario superó el plazo sin acuerdo. La reserva fue liberada, el libro vuelve a la circulación. Podés reservarlo nuevamente cuando quieras.",
    en: "The negotiation for your slot has exceeded the deadline without agreement. The reservation has been released, the book returns to circulation. You can reserve it again whenever you want.",
    it: "La negoziazione del tuo orario ha superato il termine senza accordo. La prenotazione è stata liberata, il libro torna in circolazione. Puoi prenotarlo di nuovo quando vuoi.",
    de: "Die Verhandlung über deinen Termin hat die Frist ohne Einigung überschritten. Die Vormerkung wurde freigegeben, das Buch geht zurück in den Umlauf. Du kannst es jederzeit erneut vormerken.",
    ca: "La negociació de la teva franja ha superat el termini sense acord. La reserva s'ha alliberat i el llibre ha tornat a la circulació. Pots reservar-lo de nou quan vulguis.",
    eo: "La traktado de via tempfendo superis la limdaton sen interkonsento. La rezervo estis liberigita kaj la libro revenis al cirkulado. Vi povas rezervi ĝin denove kiam vi volas.",
    nl: "De onderhandeling over je tijdslot heeft de termijn overschreden zonder akkoord. De reservering is vrijgegeven, het boek gaat terug in circulatie. Je kunt het opnieuw reserveren wanneer je maar wilt.",
    el: "Η διαπραγμάτευση για τον χρόνο σου ξεπέρασε την προθεσμία χωρίς συμφωνία. Η κράτηση απελευθερώθηκε, το βιβλίο επιστρέφει στην κυκλοφορία. Μπορείς να το ξανακρατήσεις όποτε θέλεις."
  },

  // ===== Workflow v3 — biblio (wf.staff.*) ==================================
  "wf.staff.negotiationOpened.subject": {
    "pt-BR": "Negociação de horário aberta com o(a/e) leitor(a/e)",
    fr: "Négociation de créneau ouverte avec le·la lecteur·rice",
    es: "Negociación de horario abierta con le lectore",
    en: "Slot negotiation opened with the reader",
    it: "Negoziazione di orario aperta con lə lettorə",
    de: "Terminverhandlung mit der*dem Leser*in eröffnet",
    ca: "Negociació de franja oberta amb le lector-a-e",
    eo: "Tempfenda traktado malfermita kun la legant-in-o",
    nl: "Onderhandeling over tijdslot geopend met de lezer",
    el: "Άνοιξε διαπραγμάτευση χρόνου με τον/την αναγνώστη/στρια"
  },
  "wf.staff.negotiationOpened.body": {
    "pt-BR": "A negociação de um horário de retirada foi aberta com o(a/e) leitor(a/e). O(a/e) leitor(a/e) foi avisado(a/e) por e-mail e pode aceitar, contra-propor ou cancelar pela própria conta.",
    fr: "La négociation d'un créneau de retrait a été ouverte avec le·la lecteur·rice. Le·la lecteur·rice a été prévenu·e par mail et peut accepter, contre-proposer ou annuler depuis son compte.",
    es: "Se abrió la negociación de un horario de retiro con le lectore. Le lectore fue avisade por correo y puede aceptar, contraproponer o cancelar desde su cuenta.",
    en: "A negotiation has been opened with the reader for a pickup slot. The reader has been notified by email and can accept, counter-propose, or cancel from their account.",
    it: "È stata aperta la negoziazione di un orario di ritiro con lə lettorə. Lə lettorə è statə avvisatə via email e può accettare, controproporre o annullare dal proprio account.",
    de: "Eine Verhandlung über einen Abholtermin wurde mit der*dem Leser*in eröffnet. Die*Der Leser*in wurde per E-Mail benachrichtigt und kann annehmen, gegenvorschlagen oder über das eigene Konto stornieren.",
    ca: "S'ha obert la negociació d'una franja de recollida amb le lector-a-e. Le lector-a-e ha estat avisade per correu i pot acceptar, contraproposar o cancel·lar des del seu compte.",
    eo: "La traktado de elpren-tempfendo estis malfermita kun la legant-in-o. La legant-in-o estis avertita retpoŝte kaj povas akcepti, kontraŭproponi aŭ nuligi el sia konto.",
    nl: "Er is een onderhandeling geopend met de lezer over een afhaalmoment. De lezer heeft een e-mail gekregen en kan accepteren, een tegenvoorstel doen of annuleren vanuit het eigen account.",
    el: "Άνοιξε διαπραγμάτευση χρόνου παραλαβής με τον/την αναγνώστη/στρια. Ο/Η αναγνώστης/στρια ειδοποιήθηκε με email και μπορεί να αποδεχτεί, να αντιπροτείνει ή να ακυρώσει από τον λογαριασμό του/της."
  },
  "wf.staff.readerCounterProposed.subject": {
    "pt-BR": "Contra-proposta do(a/e) leitor(a/e) — ação esperada",
    fr: "Contre-proposition du·de la lecteur·rice — action attendue",
    es: "Contrapropuesta de le lectore — acción esperada",
    en: "Counter-proposal from the reader — action expected",
    it: "Controproposta di lə lettorə — azione attesa",
    de: "Gegenvorschlag der*des Leser*in — Aktion erwartet",
    ca: "Contraproposta de le lector-a-e — acció esperada",
    eo: "Kontraŭpropono de la legant-in-o — ago atendata",
    nl: "Tegenvoorstel van de lezer — actie verwacht",
    el: "Αντιπρόταση από τον/την αναγνώστη/στρια — αναμένεται ενέργεια"
  },
  "wf.staff.readerCounterProposed.body": {
    "pt-BR": "O(a/e) leitor(a/e) contra-propôs outro horário para a retirada. <b>Resposta esperada</b> : abrir o painel para aceitar, contra-propor por sua vez, ou cancelar.",
    fr: "Le·la lecteur·rice a contre-proposé un autre créneau pour le retrait. <b>Réponse attendue</b> : ouvrir le tableau de bord pour accepter, contre-proposer à votre tour, ou annuler.",
    es: "Le lectore contrapropuso otro horario para el retiro. <b>Respuesta esperada</b> : abrir el panel para aceptar, contraproponer a su vez, o cancelar.",
    en: "The reader has counter-proposed another slot for the pickup. <b>Response expected</b> : open the dashboard to accept, counter-propose in turn, or cancel.",
    it: "Lə lettorə ha controproposto un altro orario per il ritiro. <b>Risposta attesa</b> : aprire il pannello per accettare, controproporre a vostra volta, o annullare.",
    de: "Die*Der Leser*in hat einen anderen Termin für die Abholung vorgeschlagen. <b>Antwort erwartet</b> : Öffnet das Dashboard, um anzunehmen, einen Gegenvorschlag zu machen oder zu stornieren.",
    ca: "Le lector-a-e ha contraproposat una altra franja per a la recollida. <b>Resposta esperada</b> : obrir el tauler per acceptar, contraproposar al teu torn, o cancel·lar.",
    eo: "La legant-in-o kontraŭproponis alian tempfendon por la elpreno. <b>Atendata respondo</b> : malfermi la panelon por akcepti, kontraŭproponi siavice, aŭ nuligi.",
    nl: "De lezer heeft een ander tijdslot voorgesteld voor de afhaling. <b>Reactie verwacht</b>: open het dashboard om te accepteren, zelf een tegenvoorstel te doen of te annuleren.",
    el: "Ο/Η αναγνώστης/στρια αντιπρότεινε άλλον χρόνο για την παραλαβή. <b>Αναμένεται απάντηση</b> : ανοίξτε τον πίνακα ελέγχου για να αποδεχτείτε, να αντιπροτείνετε με τη σειρά σας ή να ακυρώσετε."
  },
  "wf.staff.readerAccepted.subject": {
    "pt-BR": "Horário aceito pelo(a/e) leitor(a/e)",
    fr: "Créneau accepté par le·la lecteur·rice",
    es: "Horario aceptado por le lectore",
    en: "Slot accepted by the reader",
    it: "Orario accettato da lə lettorə",
    de: "Termin von der*dem Leser*in angenommen",
    ca: "Franja acceptada per le lector-a-e",
    eo: "Tempfendo akceptita de la legant-in-o",
    nl: "Tijdslot geaccepteerd door de lezer",
    el: "Ο χρόνος έγινε αποδεκτός από τον/την αναγνώστη/στρια"
  },
  "wf.staff.readerAccepted.body": {
    "pt-BR": "O(a/e) leitor(a/e) aceitou o horário proposto. O horário está bloqueado — o livro pode ser preparado para a retirada.",
    fr: "Le·la lecteur·rice a accepté le créneau proposé. Le créneau est verrouillé — le livre peut être préparé pour le retrait.",
    es: "Le lectore aceptó el horario propuesto. El horario está bloqueado — el libro puede ser preparado para el retiro.",
    en: "The reader has accepted the proposed slot. The slot is locked — the book can be prepared for pickup.",
    it: "Lə lettorə ha accettato l'orario proposto. L'orario è bloccato — il libro può essere preparato per il ritiro.",
    de: "Die*Der Leser*in hat den vorgeschlagenen Termin angenommen. Der Termin ist festgelegt — das Buch kann für die Abholung vorbereitet werden.",
    ca: "Le lector-a-e ha acceptat la franja proposada. La franja està bloquejada — el llibre es pot preparar per a la recollida.",
    eo: "La legant-in-o akceptis la proponitan tempfendon. La tempfendo estas ŝlosita — la libro povas esti preparita por la elpreno.",
    nl: "De lezer heeft het voorgestelde tijdslot geaccepteerd. Het tijdslot is vergrendeld — het boek kan worden voorbereid voor de afhaling.",
    el: "Ο/Η αναγνώστης/στρια αποδέχτηκε τον προτεινόμενο χρόνο. Ο χρόνος κλειδώθηκε — το βιβλίο μπορεί να προετοιμαστεί για παραλαβή."
  },
  "wf.staff.staffConfirmed.subject": {
    "pt-BR": "Horário do(a/e) leitor(a/e) confirmado",
    fr: "Créneau du·de la lecteur·rice confirmé",
    es: "Horario de le lectore confirmado",
    en: "Reader's slot confirmed",
    it: "Orario di lə lettorə confermato",
    de: "Termin der*des Leser*in bestätigt",
    ca: "Franja de le lector-a-e confirmada",
    eo: "Tempfendo de la legant-in-o konfirmita",
    nl: "Tijdslot van de lezer bevestigd",
    el: "Ο χρόνος του/της αναγνώστη/στριας επιβεβαιώθηκε"
  },
  "wf.staff.staffConfirmed.body": {
    "pt-BR": "Você confirmou o horário proposto pelo(a/e) leitor(a/e). O horário está bloqueado — o livro pode ser preparado para a retirada.",
    fr: "Tu as confirmé le créneau proposé par le·la lecteur·rice. Le créneau est verrouillé — le livre peut être préparé pour le retrait.",
    es: "Confirmaste el horario propuesto por le lectore. El horario está bloqueado — el libro puede ser preparado para el retiro.",
    en: "You have confirmed the slot proposed by the reader. The slot is locked — the book can be prepared for pickup.",
    it: "Avete confermato l'orario proposto da lə lettorə. L'orario è bloccato — il libro può essere preparato per il ritiro.",
    de: "Ihr habt den von der*dem Leser*in vorgeschlagenen Termin bestätigt. Der Termin ist festgelegt — das Buch kann für die Abholung vorbereitet werden.",
    ca: "Has confirmat la franja proposada per le lector-a-e. La franja està bloquejada — el llibre es pot preparar per a la recollida.",
    eo: "Vi konfirmis la tempfendon proponitan de la legant-in-o. La tempfendo estas ŝlosita — la libro povas esti preparita por la elpreno.",
    nl: "Je hebt het door de lezer voorgestelde tijdslot bevestigd. Het tijdslot is vergrendeld — het boek kan worden voorbereid voor de afhaling.",
    el: "Επιβεβαιώσατε τον χρόνο που πρότεινε ο/η αναγνώστης/στρια. Ο χρόνος κλειδώθηκε — το βιβλίο μπορεί να προετοιμαστεί για παραλαβή."
  },
  "wf.staff.ready.subject": {
    "pt-BR": "Livro pronto para retirada — leitor(a/e) avisado(a/e)",
    fr: "Livre prêt — lecteur·rice prévenu·e",
    es: "Libro listo — lectore avisade",
    en: "Book ready — reader notified",
    it: "Libro pronto — lettorə avvisatə",
    de: "Buch bereit — Leser*in benachrichtigt",
    ca: "Llibre llest per recollir — lector-a-e avisade",
    eo: "Libro preta por elpreno — legant-in-o avertita",
    nl: "Boek klaar — lezer op de hoogte gebracht",
    el: "Βιβλίο έτοιμο — ο/η αναγνώστης/στρια ειδοποιήθηκε"
  },
  "wf.staff.ready.body": {
    "pt-BR": "Você sinalizou que o livro está pronto para a retirada. O(a/e) leitor(a/e) foi avisado(a/e).",
    fr: "Tu as signalé que le livre est prêt à être retiré. Le·la lecteur·rice a été prévenu·e.",
    es: "Indicaste que el libro está listo para ser retirado. Le lectore fue avisade.",
    en: "You have signaled that the book is ready for pickup. The reader has been notified.",
    it: "Avete segnalato che il libro è pronto per il ritiro. Lə lettorə è statə avvisatə.",
    de: "Ihr habt gemeldet, dass das Buch zur Abholung bereit ist. Die*Der Leser*in wurde benachrichtigt.",
    ca: "Has indicat que el llibre està llest per ser recollit. Le lector-a-e ha estat avisade.",
    eo: "Vi indikis ke la libro estas preta por elpreno. La legant-in-o estis avertita.",
    nl: "Je hebt aangegeven dat het boek klaarligt om af te halen. De lezer heeft bericht gekregen.",
    el: "Επισημάνατε ότι το βιβλίο είναι έτοιμο για παραλαβή. Ο/Η αναγνώστης/στρια ειδοποιήθηκε."
  },
  "wf.staff.noShow.subject": {
    "pt-BR": "Retirada não realizada",
    fr: "Retrait non effectué",
    es: "Retiro no realizado",
    en: "Pickup missed",
    it: "Ritiro non effettuato",
    de: "Abholung nicht erfolgt",
    ca: "Recollida no efectuada",
    eo: "Elpreno ne efektivigita",
    nl: "Afhaling gemist",
    el: "Η παραλαβή δεν έγινε"
  },
  "wf.staff.noShow.body": {
    "pt-BR": "O livro não foi retirado no horário previsto. A reserva foi marcada como não-retirada — o livro voltará em breve à circulação livre.",
    fr: "Le livre n'a pas été retiré au créneau prévu. La réservation est marquée en non-retrait — le livre repassera bientôt en circulation libre.",
    es: "El libro no fue retirado en el horario previsto. La reserva fue marcada como no-retiro — el libro volverá pronto a la circulación libre.",
    en: "The book was not picked up at the scheduled time. The reservation is marked as no-show — the book will soon return to free circulation.",
    it: "Il libro non è stato ritirato nell'orario previsto. La prenotazione è stata segnata come non-ritiro — il libro tornerà presto in circolazione libera.",
    de: "Das Buch wurde zum vereinbarten Termin nicht abgeholt. Die Vormerkung ist als Nicht-Abholung markiert — das Buch geht bald zurück in den freien Umlauf.",
    ca: "El llibre no s'ha recollit en la franja prevista. La reserva s'ha marcat com a no-recollida — el llibre tornarà aviat a la circulació lliure.",
    eo: "La libro ne estis elprenita en la planita tempfendo. La rezervo estis markita kiel ne-elpreno — la libro baldaŭ revenos al libera cirkulado.",
    nl: "Het boek is niet afgehaald op het geplande moment. De reservering is gemarkeerd als niet-afgehaald — het boek gaat binnenkort terug in vrije circulatie.",
    el: "Το βιβλίο δεν παραλήφθηκε τον προγραμματισμένο χρόνο. Η κράτηση σημειώνεται ως μη παραλαβή — το βιβλίο θα επιστρέψει σύντομα στην ελεύθερη κυκλοφορία."
  },
  "wf.staff.closed.subject": {
    "pt-BR": "Reserva encerrada",
    fr: "Réservation close",
    es: "Reserva cerrada",
    en: "Reservation closed",
    it: "Prenotazione chiusa",
    de: "Vormerkung abgeschlossen",
    ca: "Reserva tancada",
    eo: "Rezervo fermita",
    nl: "Reservering afgesloten",
    el: "Η κράτηση έκλεισε"
  },
  "wf.staff.closed.body": {
    "pt-BR": "A reserva está encerrada, o livro voltou à circulação livre. Nenhuma ação adicional é esperada de sua parte.",
    fr: "La réservation est close, le livre repasse en circulation libre. Aucune action supplémentaire n'est attendue de votre part.",
    es: "La reserva está cerrada, el libro vuelve a la circulación libre. No se espera ninguna acción adicional de su parte.",
    en: "The reservation is closed, the book returns to free circulation. No additional action is expected from you.",
    it: "La prenotazione è chiusa, il libro torna in circolazione libera. Nessuna azione aggiuntiva è attesa da parte vostra.",
    de: "Die Vormerkung ist abgeschlossen, das Buch geht zurück in den freien Umlauf. Keine zusätzliche Aktion eurerseits ist erforderlich.",
    ca: "La reserva està tancada, el llibre torna a la circulació lliure. No s'espera cap acció addicional per part teva.",
    eo: "La rezervo estas fermita, la libro revenas al libera cirkulado. Neniu plia ago estas atendata de vi.",
    nl: "De reservering is afgesloten, het boek gaat terug in vrije circulatie. Er wordt geen verdere actie van je verwacht.",
    el: "Η κράτηση έκλεισε, το βιβλίο επιστρέφει στην ελεύθερη κυκλοφορία. Δεν αναμένεται καμία επιπλέον ενέργεια από εσάς."
  },
  "wf.staff.maxIterations.subject": {
    "pt-BR": "Negociação sem acordo — leitor(a/e) convidado(a/e) ao contato direto",
    fr: "Négociation sans accord — lecteur·rice invité·e au contact direct",
    es: "Negociación sin acuerdo — lectore invitade al contacto directo",
    en: "Negotiation without agreement — reader invited to direct contact",
    it: "Negoziazione senza accordo — lettorə invitatə al contatto diretto",
    de: "Verhandlung ohne Einigung — Leser*in zum direkten Kontakt eingeladen",
    ca: "Negociació sense acord — lector-a-e convidade al contacte directe",
    eo: "Traktado sen interkonsento — legant-in-o invitita al rekta kontakto",
    nl: "Onderhandeling zonder akkoord — lezer uitgenodigd voor direct contact",
    el: "Διαπραγμάτευση χωρίς συμφωνία — ο/η αναγνώστης/στρια κλήθηκε για άμεση επαφή"
  },
  "wf.staff.maxIterations.body": {
    "pt-BR": "Várias trocas sem acordo com o(a/e) leitor(a/e). O(a/e) leitor(a/e) foi convidado(a/e) a entrar em contato diretamente para encontrar uma solução.",
    fr: "Plusieurs allers-retours sans accord avec le·la lecteur·rice. Le·la lecteur·rice a été invité·e à vous contacter directement pour trouver une solution.",
    es: "Varios intercambios sin acuerdo con le lectore. Le lectore fue invitade a contactarles directamente para encontrar una solución.",
    en: "Several exchanges without agreement with the reader. The reader has been invited to contact you directly to find a solution.",
    it: "Diversi scambi senza accordo con lə lettorə. Lə lettorə è statə invitatə a contattarvi direttamente per trovare una soluzione.",
    de: "Mehrere Versuche ohne Einigung mit der*dem Leser*in. Die*Der Leser*in wurde gebeten, sich direkt an euch zu wenden, um eine Lösung zu finden.",
    ca: "Diversos intercanvis sense acord amb le lector-a-e. Le lector-a-e ha estat convidade a contactar-vos directament per trobar una solució.",
    eo: "Pluraj interŝanĝoj sen interkonsento kun la legant-in-o. La legant-in-o estis invitita kontakti vin rekte por trovi solvon.",
    nl: "Meerdere keren heen en weer zonder akkoord met de lezer. De lezer is uitgenodigd om rechtstreeks contact met je op te nemen om een oplossing te vinden.",
    el: "Αρκετές ανταλλαγές χωρίς συμφωνία με τον/την αναγνώστη/στρια. Ο/Η αναγνώστης/στρια κλήθηκε να επικοινωνήσει απευθείας μαζί σας για να βρεθεί λύση."
  },

  // ===== Workflow v3 — re-proposition staff après contre-prop lecteur =======
  // Couvre le cas spécifique où la coordo, après avoir reçu une contre-prop
  // du lecteur (negotiation_iteration_count > 0, pickup_proposed_by='leitor'),
  // décide de NE PAS accepter et de re-proposer un autre créneau. Décision
  // technique paquet 6 commit comportement (option Î²) : on distingue cette
  // re-proposition de la première ouverture de négo (wf.staff.negotiationOpened),
  // pour que la coordo voie clairement dans son trace mail "j'ai re-proposé"
  // vs "j'ai ouvert la négo".
  "wf.reader.libraryCounterProposed.subject": {
    "pt-BR": "Nova proposta da biblioteca",
    fr: "Nouvelle proposition de la biblio",
    es: "Nueva propuesta de la biblioteca",
    en: "New proposal from the library",
    it: "Nuova proposta della biblioteca",
    de: "Neuer Vorschlag der Bibliothek",
    ca: "Nova proposta de la biblioteca",
    eo: "Nova propono de la biblioteko",
    nl: "Nieuw voorstel van de bibliotheek",
    el: "Νέα πρόταση από τη βιβλιοθήκη"
  },
  "wf.reader.libraryCounterProposed.body": {
    "pt-BR": "A biblioteca respondeu à sua contra-proposta com um novo horário. Você pode aceitar este horário, propor outro, ou cancelar a reserva pela sua conta.",
    fr: "La biblio a répondu à ta contre-proposition avec un nouveau créneau. Tu peux accepter ce créneau, en proposer un autre, ou annuler ta réservation depuis ton compte.",
    es: "La biblioteca respondió a tu contrapropuesta con un nuevo horario. Podés aceptar este horario, proponer otro, o cancelar tu reserva desde tu cuenta.",
    en: "The library has responded to your counter-proposal with a new time slot. You can accept this slot, propose another one, or cancel your reservation from your account.",
    it: "La biblioteca ha risposto alla tua controproposta con un nuovo orario. Puoi accettare questo orario, proporne un altro, o annullare la tua prenotazione dal tuo account.",
    de: "Die Bibliothek hat auf deinen Gegenvorschlag mit einem neuen Termin geantwortet. Du kannst diesen Termin annehmen, einen anderen vorschlagen oder deine Vormerkung über dein Konto stornieren.",
    ca: "La biblioteca ha respost a la teva contraproposta amb una nova franja. Pots acceptar aquesta franja, proposar-ne una altra, o cancel·lar la teva reserva des del teu compte.",
    eo: "La biblioteko respondis al via kontraŭpropono per nova tempfendo. Vi povas akcepti ĉi tiun tempfendon, proponi alian, aŭ nuligi vian rezervon el via konto.",
    nl: "De bibliotheek heeft op je tegenvoorstel gereageerd met een nieuw tijdslot. Je kunt dit tijdslot accepteren, een ander voorstellen of je reservering annuleren vanuit je account.",
    el: "Η βιβλιοθήκη απάντησε στην αντιπρότασή σου με νέο χρόνο. Μπορείς να αποδεχτείς αυτόν τον χρόνο, να προτείνεις άλλον ή να ακυρώσεις την κράτησή σου από τον λογαριασμό σου."
  },
  "wf.staff.staffCounterProposed.subject": {
    "pt-BR": "Contra-proposta enviada ao(a/e) leitor(a/e)",
    fr: "Contre-proposition envoyée au·à la lecteur·rice",
    es: "Contrapropuesta enviada a le lectore",
    en: "Counter-proposal sent to the reader",
    it: "Controproposta inviata a lə lettorə",
    de: "Gegenvorschlag an die*den Leser*in gesendet",
    ca: "Contraproposta enviada a le lector-a-e",
    eo: "Kontraŭpropono sendita al la legant-in-o",
    nl: "Tegenvoorstel naar de lezer verzonden",
    el: "Αντιπρόταση στάλθηκε στον/στην αναγνώστη/στρια"
  },
  "wf.staff.staffCounterProposed.body": {
    "pt-BR": "Você enviou uma nova contra-proposta de horário ao(a/e) leitor(a/e) em resposta à proposta recebida. Aguarde a resposta.",
    fr: "Tu as envoyé une nouvelle contre-proposition de créneau au·à la lecteur·rice en réponse à sa proposition. En attente de sa réponse.",
    es: "Enviaste una nueva contrapropuesta de horario a le lectore en respuesta a su propuesta. Esperando su respuesta.",
    en: "You have sent a new counter-proposal to the reader in response to their proposal. Awaiting their reply.",
    it: "Avete inviato una nuova controproposta di orario a lə lettorə in risposta alla sua proposta. In attesa della sua risposta.",
    de: "Ihr habt einen neuen Gegenvorschlag an die*den Leser*in als Antwort auf deren Vorschlag gesendet. Wartet auf Antwort.",
    ca: "Has enviat una nova contraproposta de franja a le lector-a-e en resposta a la seva proposta. A l'espera de la seva resposta.",
    eo: "Vi sendis novan tempfendan kontraŭproponon al la legant-in-o responde al ĝia propono. Atendante ĝian respondon.",
    nl: "Je hebt een nieuw tegenvoorstel naar de lezer verzonden als reactie op het voorstel. In afwachting van een reactie.",
    el: "Στείλατε νέα αντιπρόταση χρόνου στον/στην αναγνώστη/στρια ως απάντηση στην πρότασή του/της. Σε αναμονή της απάντησής του/της."
  },

  // ===== Workflow v3 — cron timeout (wf.staff.negotiationTimedOut) ==========
  "wf.staff.negotiationTimedOut.subject": {
    "pt-BR": "Negociação expirada — reserva liberada",
    fr: "Négociation expirée — réservation libérée",
    es: "Negociación vencida — reserva liberada",
    en: "Negotiation expired — reservation released",
    it: "Negoziazione scaduta — prenotazione liberata",
    de: "Verhandlung abgelaufen — Vormerkung freigegeben",
    ca: "Negociació expirada — reserva alliberada",
    eo: "Traktado eksvalidiĝinta — rezervo liberigita",
    nl: "Onderhandeling verlopen — reservering vrijgegeven",
    el: "Η διαπραγμάτευση έληξε — η κράτηση απελευθερώθηκε"
  },
  "wf.staff.negotiationTimedOut.body": {
    "pt-BR": "A negociação para a retirada expirou sem acordo ({days} dias sem resposta). A reserva foi liberada automaticamente e o livro voltou à circulação livre.",
    fr: "La négociation pour le retrait a expiré sans accord ({days} jours sans réponse). La réservation a été libérée automatiquement, le livre repasse en circulation libre.",
    es: "La negociación para el retiro expiró sin acuerdo ({days} días sin respuesta). La reserva fue liberada automáticamente, el libro vuelve a la circulación libre.",
    en: "The negotiation for the pickup has expired without agreement ({days} days without reply). The reservation has been released automatically, the book returns to free circulation.",
    it: "La negoziazione per il ritiro è scaduta senza accordo ({days} giorni senza risposta). La prenotazione è stata liberata automaticamente, il libro torna in circolazione libera.",
    de: "Die Verhandlung über die Abholung ist ohne Einigung abgelaufen ({days} Tage ohne Antwort). Die Vormerkung wurde automatisch freigegeben, das Buch geht zurück in den freien Umlauf.",
    ca: "La negociació per a la recollida ha expirat sense acord ({days} dies sense resposta). La reserva s'ha alliberat automàticament i el llibre ha tornat a la circulació lliure.",
    eo: "La traktado por la elpreno eksvalidiĝis sen interkonsento ({days} tagoj sen respondo). La rezervo estis liberigita aŭtomate kaj la libro revenas al libera cirkulado.",
    nl: "De onderhandeling over de afhaling is verlopen zonder akkoord ({days} dagen zonder reactie). De reservering is automatisch vrijgegeven, het boek gaat terug in vrije circulatie.",
    el: "Η διαπραγμάτευση για την παραλαβή έληξε χωρίς συμφωνία ({days} ημέρες χωρίς απάντηση). Η κράτηση απελευθερώθηκε αυτόματα, το βιβλίο επιστρέφει στην ελεύθερη κυκλοφορία."
  },

  // ===== Action/info boxes (wf.staff.*Box.*) ================================
  // Encadrés visuels insérés dans le HTML du mail biblio :
  //   - actionBox : encadré orange/rouge quand action attendue
  //   - infoBox : encadré gris quand juste informatif
  "wf.staff.actionBox.title": {
    "pt-BR": "Ação esperada",
    fr: "Action attendue",
    es: "Acción esperada",
    en: "Action expected",
    it: "Azione attesa",
    de: "Aktion erwartet",
    ca: "Acció esperada",
    eo: "Atendata ago",
    nl: "Actie verwacht",
    el: "Αναμένεται ενέργεια"
  },
  "wf.staff.actionBox.openPanel": {
    "pt-BR": "Abrir o painel",
    fr: "Ouvrir le tableau de bord",
    es: "Abrir el panel",
    en: "Open the dashboard",
    it: "Aprire il pannello",
    de: "Dashboard öffnen",
    ca: "Obrir el tauler",
    eo: "Malfermi la panelon",
    nl: "Open het dashboard",
    el: "Άνοιγμα του πίνακα ελέγχου"
  },
  "wf.staff.infoBox.title": {
    "pt-BR": "Para sua informação",
    fr: "Pour information",
    es: "Para su información",
    en: "For your information",
    it: "Per vostra informazione",
    de: "Zu Ihrer Information",
    ca: "Per a la teva informació",
    eo: "Por via informo",
    nl: "Ter informatie",
    el: "Προς ενημέρωσή σας"
  },

  // ===== Subject prefixes (subj.*) ==========================================
  // Préfixes textuels pour le sujet du mail biblio, permettant aux coordo
  // de filtrer leur boîte (ex: dossier auto pour les actions requises).
  "subj.staff.action": {
    "pt-BR": "[Ação requerida]",
    fr: "[Action requise]",
    es: "[Acción requerida]",
    en: "[Action required]",
    it: "[Azione richiesta]",
    de: "[Aktion erforderlich]",
    ca: "[Acció requerida]",
    eo: "[Ago postulata]",
    nl: "[Actie vereist]",
    el: "[Απαιτείται ενέργεια]"
  },
  "subj.staff.info": {
    "pt-BR": "[Info]",
    fr: "[Info]",
    es: "[Info]",
    en: "[Info]",
    it: "[Info]",
    de: "[Info]",
    ca: "[Info]",
    eo: "[Info]",
    nl: "[Info]",
    el: "[Πληροφορία]"
  },
  // ===== Footer libre diffusion (paquet 6 commit fix-up) ====================
  // Remplace l'ancien symbole © (idéologiquement incompatible avec un projet
  // anarchiste). La chaîne s'affiche dans la dernière ligne de chaque mail :
  //   "{subjectTag} — {libre diffusion} — {footerText}"
  // Localisée dans la langue du destinataire (cohérence avec le reste du
  // paquet 6 : chaque destinataire reçoit dans sa propre langue).
  "subj.libreDiffusion": {
    "pt-BR": "livre difusão",
    fr: "libre diffusion",
    es: "libre difusión",
    en: "free distribution",
    it: "libera diffusione",
    de: "freie Verbreitung",
    ca: "lliure difusió",
    eo: "libera disvastigo",
    nl: "vrije verspreiding",
    el: "ελεύθερη διάδοση"
  },


  // ===== Loan events (loan.*) ===============================================
  "loan.created.sub": {
    "pt-BR": "Empréstimo registrado",
    fr: "Emprunt enregistré",
    es: "Préstamo registrado",
    en: "Loan registered",
    it: "Prestito registrato",
    de: "Ausleihe registriert",
    ca: "Préstec registrat",
    eo: "Prunto registrita",
    nl: "Uitlening geregistreerd",
    el: "Ο δανεισμός καταχωρίστηκε"
  },
  "loan.created.intro": {
    "pt-BR": "Seu empréstimo foi registrado.",
    fr: "Ton emprunt a bien été enregistré.",
    es: "Tu préstamo fue registrado.",
    en: "Your loan has been registered.",
    it: "Il tuo prestito è stato registrato.",
    de: "Deine Ausleihe wurde registriert.",
    ca: "El teu préstec s'ha registrat correctament.",
    eo: "Via prunto estis sukcese registrita.",
    nl: "Je uitlening is geregistreerd.",
    el: "Ο δανεισμός σου καταχωρίστηκε."
  },
  "loan.dueIn": {
    "pt-BR": "Devolução prevista para {date}.",
    fr: "Retour prévu pour le {date}.",
    es: "Devolución prevista para el {date}.",
    en: "Due date: {date}.",
    it: "Restituzione prevista per il {date}.",
    de: "Rückgabe vorgesehen für den {date}.",
    ca: "Retorn previst per al {date}.",
    eo: "Redono planita por la {date}.",
    nl: "Inleverdatum: {date}.",
    el: "Προβλεπόμενη επιστροφή: {date}."
  },
  "loan.renewed.sub": {
    "pt-BR": "Renovação confirmada",
    fr: "Renouvellement confirmé",
    es: "Renovación confirmada",
    en: "Renewal confirmed",
    it: "Rinnovo confermato",
    de: "Verlängerung bestätigt",
    ca: "Renovació confirmada",
    eo: "Renovigo konfirmita",
    nl: "Verlenging bevestigd",
    el: "Η ανανέωση επιβεβαιώθηκε"
  },
  "loan.renewed.intro": {
    "pt-BR": "Sua prorrogação foi confirmada.",
    fr: "Ta prolongation a bien été confirmée.",
    es: "Tu renovación fue confirmada.",
    en: "Your renewal has been confirmed.",
    it: "Il tuo rinnovo è stato confermato.",
    de: "Deine Verlängerung wurde bestätigt.",
    ca: "La teva renovació s'ha confirmat correctament.",
    eo: "Via renovigo estis sukcese konfirmita.",
    nl: "Je verlenging is bevestigd.",
    el: "Η ανανέωσή σου επιβεβαιώθηκε."
  },
  "loan.newDue": {
    "pt-BR": "Nova data de devolução: {date}.",
    fr: "Nouvelle date de retour : {date}.",
    es: "Nueva fecha de devolución: {date}.",
    en: "New due date: {date}.",
    it: "Nuova data di restituzione: {date}.",
    de: "Neues Rückgabedatum: {date}.",
    ca: "Nova data de retorn: {date}.",
    eo: "Nova redato: {date}.",
    nl: "Nieuwe inleverdatum: {date}.",
    el: "Νέα ημερομηνία επιστροφής: {date}."
  },
  "loan.renewed.once": {
    "pt-BR": "Lembre-se: cada exemplar pode ser prorrogado apenas uma vez.",
    fr: "Pour rappel : chaque exemplaire ne peut être prolongé qu'une seule fois.",
    es: "Recuerda: cada ejemplar puede renovarse solo una vez.",
    en: "Reminder: each item can be renewed only once.",
    it: "Ricorda: ogni copia può essere rinnovata solo una volta.",
    de: "Zur Erinnerung: jedes Exemplar kann nur einmal verlängert werden.",
    ca: "Recorda: cada exemplar només es pot renovar una vegada.",
    eo: "Memoru: ĉiu ekzemplero povas esti renovigita nur unufoje.",
    nl: "Ter herinnering: elk exemplaar kan slechts één keer worden verlengd.",
    el: "Υπενθύμιση: κάθε αντίτυπο μπορεί να ανανεωθεί μόνο μία φορά."
  },
  "loan.returned.sub": {
    "pt-BR": "Devolução registrada",
    fr: "Retour enregistré",
    es: "Devolución registrada",
    en: "Return registered",
    it: "Restituzione registrata",
    de: "Rückgabe registriert",
    ca: "Retorn registrat",
    eo: "Redono registrita",
    nl: "Inlevering geregistreerd",
    el: "Η επιστροφή καταχωρίστηκε"
  },
  "loan.returned.intro": {
    "pt-BR": "Registramos a devolução. Obrigad(o/a/e)!",
    fr: "Nous avons enregistré le retour. Merci !",
    es: "Registramos la devolución. ¡Gracias!",
    en: "We've recorded the return. Thank you!",
    it: "Abbiamo registrato la restituzione. Grazie!",
    de: "Wir haben die Rückgabe registriert. Danke!",
    ca: "Hem registrat el retorn. Gràcies!",
    eo: "Ni registris la redonon. Dankon!",
    nl: "We hebben de inlevering geregistreerd. Bedankt!",
    el: "Καταγράψαμε την επιστροφή. Ευχαριστούμε!"
  },
  "loan.returned.browse": {
    "pt-BR": "Continue navegando no acervo para suas próximas leituras.",
    fr: "Continue à explorer le fonds pour tes prochaines lectures.",
    es: "Sigue navegando el acervo para tus próximas lecturas.",
    en: "Keep browsing the collection for your next reads.",
    it: "Continua a esplorare il fondo per le tue prossime letture.",
    de: "Stöbere weiter im Bestand für deine nächste Lektüre.",
    ca: "Continua explorant el fons per a les teves properes lectures.",
    eo: "Daŭrigu esplori la fonduson por viaj sekvaj legaĵoj.",
    nl: "Blijf de collectie verkennen voor je volgende leesvoer.",
    el: "Συνέχισε να εξερευνείς τη συλλογή για τα επόμενα διαβάσματά σου."
  },
  "loan.returnScheduled": {
    "pt-BR": "Devolução agendada",
    fr: "Retour programmé",
    es: "Devolución programada",
    en: "Return scheduled",
    it: "Restituzione programmata",
    de: "Rückgabe geplant",
    ca: "Retorn programat",
    eo: "Redono planita",
    nl: "Inlevering gepland",
    el: "Επιστροφή προγραμματισμένη"
  },
  "loan.returnCancelled": {
    "pt-BR": "Devolução cancelada",
    fr: "Retour annulé",
    es: "Devolución cancelada",
    en: "Return cancelled",
    it: "Restituzione annullata",
    de: "Rückgabe storniert",
    ca: "Retorn cancel·lat",
    eo: "Redono nuligita",
    nl: "Inlevering geannuleerd",
    el: "Επιστροφή ακυρώθηκε"
  },
  "loan.returnMissed": {
    "pt-BR": "Devolução não realizada",
    fr: "Retour non effectué",
    es: "Devolución no realizada",
    en: "Return missed",
    it: "Restituzione non effettuata",
    de: "Rückgabe nicht erfolgt",
    ca: "Retorn no efectuat",
    eo: "Redono ne efektivigita",
    nl: "Inlevering gemist",
    el: "Επιστροφή δεν πραγματοποιήθηκε"
  },
  "loan.partialReturn.sub": {
    "pt-BR": "Devolução parcial registrada",
    fr: "Retour partiel enregistré",
    es: "Devolución parcial registrada",
    en: "Partial return recorded",
    it: "Restituzione parziale registrata",
    de: "Teilrückgabe registriert",
    ca: "Retorn parcial registrat",
    eo: "Parta redono registrita",
    nl: "Gedeeltelijke inlevering geregistreerd",
    el: "Καταγράφηκε μερική επιστροφή"
  },
  "loan.partialReturn.intro": {
    "pt-BR": "Registramos a devolução parcial do seu empréstimo. Obrigad(o/a/e) por trazer alguns documentos!",
    fr: "Nous avons enregistré le retour partiel de ton emprunt. Merci d'avoir rapporté une partie des documents !",
    es: "Registramos la devolución parcial de tu préstamo. ¡Gracias por traer une parte de los documentos!",
    en: "We've recorded the partial return of your loan. Thank you for bringing back some of the documents!",
    it: "Abbiamo registrato la restituzione parziale del tuo prestito. Grazie per aver riportato alcuni documenti!",
    de: "Wir haben die Teilrückgabe deiner Ausleihe registriert. Danke, dass du einige Dokumente zurückgebracht hast!",
    ca: "Hem registrat el retorn parcial del teu préstec. Gràcies per portar alguns documents!",
    eo: "Ni registris la partan redonon de via prunto. Dankon pro reporti kelkajn dokumentojn!",
    nl: "We hebben de gedeeltelijke inlevering van je uitlening geregistreerd. Bedankt voor het terugbrengen van een deel van de documenten!",
    el: "Καταγράψαμε τη μερική επιστροφή του δανεισμού σου. Ευχαριστούμε που έφερες πίσω μέρος των τεκμηρίων!"
  },
  "loan.partialReturn.dueReminder": {
    "pt-BR": "Lembrete: a data de devolução dos documentos restantes é {date}.",
    fr: "Rappel : la date de retour des documents restants est le {date}.",
    es: "Recordatorio: la fecha de devolución de los documentos restantes es el {date}.",
    en: "Reminder: the due date for the remaining documents is {date}.",
    it: "Promemoria: la data di restituzione dei documenti rimanenti è il {date}.",
    de: "Erinnerung: das Rückgabedatum für die verbleibenden Dokumente ist der {date}.",
    ca: "Recordatori: la data de retorn dels documents restants és el {date}.",
    eo: "Memorigo: la redato de la restantaj dokumentoj estas la {date}.",
    nl: "Ter herinnering: de inleverdatum voor de resterende documenten is {date}.",
    el: "Υπενθύμιση: η ημερομηνία επιστροφής για τα υπόλοιπα τεκμήρια είναι {date}."
  },
  "loan.partialReturn.outro": {
    "pt-BR": "Não esqueça de passar pela biblioteca para devolver os documentos restantes.",
    fr: "N'oublie pas de passer à la bibliothèque pour rendre les documents restants.",
    es: "No olvides pasar por la biblioteca para devolver los documentos restantes.",
    en: "Don't forget to drop by the library to return the remaining documents.",
    it: "Non dimenticare di passare in biblioteca per restituire i documenti rimanenti.",
    de: "Vergiss nicht, in der Bibliothek vorbeizuschauen, um die verbleibenden Dokumente zurückzugeben.",
    ca: "No oblidis passar per la biblioteca per retornar els documents restants.",
    eo: "Ne forgesu viziti la bibliotekon por redoni la restantajn dokumentojn.",
    nl: "Vergeet niet langs te komen bij de bibliotheek om de resterende documenten in te leveren.",
    el: "Μην ξεχάσεις να περάσεις από τη βιβλιοθήκη για να επιστρέψεις τα υπόλοιπα τεκμήρια."
  },
  "loan.fullyReturnedAfterPartial.sub": {
    "pt-BR": "Empréstimo concluído",
    fr: "Emprunt clôturé",
    es: "Préstamo concluido",
    en: "Loan completed",
    it: "Prestito concluso",
    de: "Ausleihe abgeschlossen",
    ca: "Préstec finalitzat",
    eo: "Prunto finita",
    nl: "Uitlening afgesloten",
    el: "Ο δανεισμός ολοκληρώθηκε"
  },
  "loan.fullyReturnedAfterPartial.intro": {
    "pt-BR": "Você devolveu o último documento do seu empréstimo. Tudo voltou! Obrigad(o/a/e) por cuidar bem dos livros da biblioteca.",
    fr: "Tu viens de rendre le dernier document de ton emprunt. Tout est revenu ! Merci d'avoir pris soin des documents de la bibliothèque.",
    es: "Devolviste el último documento de tu préstamo. ¡Todo volvió! Gracias por cuidar de los documentos de la biblioteca.",
    en: "You've returned the last document of your loan. Everything is back! Thank you for taking good care of the library's documents.",
    it: "Hai restituito l'ultimo documento del tuo prestito. È tutto rientrato! Grazie per esserti pres* cura dei documenti della biblioteca.",
    de: "Du hast das letzte Dokument deiner Ausleihe zurückgebracht. Alles ist wieder da! Danke, dass du gut auf die Dokumente der Bibliothek aufgepasst hast.",
    ca: "Has retornat l'últim document del teu préstec. Tot ha tornat! Gràcies per tenir cura dels documents de la biblioteca.",
    eo: "Vi redonis la lastan dokumenton de via prunto. Ĉio revenis! Dankon pro zorgi pri la dokumentoj de la biblioteko.",
    nl: "Je hebt het laatste document van je uitlening ingeleverd. Alles is terug! Bedankt voor het goed zorgen voor de documenten van de bibliotheek.",
    el: "Μόλις επέστρεψες το τελευταίο τεκμήριο του δανεισμού σου. Όλα επιστράφηκαν! Ευχαριστούμε που φρόντισες τα τεκμήρια της βιβλιοθήκης."
  },
  "loan.fullyReturnedAfterPartial.browse": {
    "pt-BR": "Continue navegando no acervo para suas próximas leituras.",
    fr: "Continue à explorer le fonds pour tes prochaines lectures.",
    es: "Sigue navegando el acervo para tus próximas lecturas.",
    en: "Keep browsing the collection for your next reads.",
    it: "Continua a esplorare il fondo per le tue prossime letture.",
    de: "Stöbere weiter im Bestand für deine nächste Lektüre.",
    ca: "Continua explorant el fons per a les teves properes lectures.",
    eo: "Daŭrigu esplori la fonduson por viaj sekvaj legaĵoj.",
    nl: "Blijf de collectie verkennen voor je volgende leesvoer.",
    el: "Συνέχισε να εξερευνείς τη συλλογή για τα επόμενα διαβάσματά σου."
  },

  // ===== Reminders (rem.*) ==================================================
  "rem.title": {
    "pt-BR": "Lembrete de devolução",
    fr: "Rappel de retour",
    es: "Recordatorio de devolución",
    en: "Return reminder",
    it: "Promemoria di restituzione",
    de: "Rückgabeerinnerung",
    ca: "Recordatori de retorn",
    eo: "Redonmemorigo",
    nl: "Inleverherinnering",
    el: "Υπενθύμιση επιστροφής"
  },
  "rem.5d": {
    "pt-BR": "Devolução em 5 dias",
    fr: "Retour dans 5 jours",
    es: "Devolución en 5 días",
    en: "Due in 5 days",
    it: "Restituzione tra 5 giorni",
    de: "Rückgabe in 5 Tagen",
    ca: "Retorn d'aquí a 5 dies",
    eo: "Redono post 5 tagoj",
    nl: "Inleveren over 5 dagen",
    el: "Επιστροφή σε 5 ημέρες"
  },
  "rem.5d.body": {
    "pt-BR": "Seu empréstimo vence em 5 dias",
    fr: "Ton emprunt arrive à échéance dans 5 jours",
    es: "Tu préstamo vence en 5 días",
    en: "Your loan is due in 5 days",
    it: "Il tuo prestito scade tra 5 giorni",
    de: "Deine Ausleihe läuft in 5 Tagen ab",
    ca: "El teu préstec venç d'aquí a 5 dies",
    eo: "Via prunto eksvalidiĝas post 5 tagoj",
    nl: "Je uitlening moet over 5 dagen worden ingeleverd",
    el: "Ο δανεισμός σου λήγει σε 5 ημέρες"
  },
  "rem.3d": {
    "pt-BR": "Devolução em 3 dias",
    fr: "Retour dans 3 jours",
    es: "Devolución en 3 días",
    en: "Due in 3 days",
    it: "Restituzione tra 3 giorni",
    de: "Rückgabe in 3 Tagen",
    ca: "Retorn d'aquí a 3 dies",
    eo: "Redono post 3 tagoj",
    nl: "Inleveren over 3 dagen",
    el: "Επιστροφή σε 3 ημέρες"
  },
  "rem.3d.body": {
    "pt-BR": "Faltam 3 dias para a devolução do seu empréstimo.",
    fr: "Plus que 3 jours avant la date de retour de ton emprunt.",
    es: "Quedan 3 días para la devolución de tu préstamo.",
    en: "Only 3 days left until the return date of your loan.",
    it: "Mancano 3 giorni alla data di restituzione del tuo prestito.",
    de: "Nur noch 3 Tage bis zum Rückgabedatum deiner Ausleihe.",
    ca: "Falten 3 dies per al retorn del teu préstec.",
    eo: "Restas 3 tagoj antaŭ la redono de via prunto.",
    nl: "Nog maar 3 dagen tot de inleverdatum van je uitlening.",
    el: "Απομένουν μόνο 3 ημέρες μέχρι την ημερομηνία επιστροφής του δανεισμού σου."
  },
  "rem.today": {
    "pt-BR": "Devolução hoje",
    fr: "Retour aujourd'hui",
    es: "Devolución hoy",
    en: "Due today",
    it: "Restituzione oggi",
    de: "Rückgabe heute",
    ca: "Retorn avui",
    eo: "Redono hodiaŭ",
    nl: "Vandaag inleveren",
    el: "Επιστροφή σήμερα"
  },
  "rem.today.body": {
    "pt-BR": "Sua devolução é hoje",
    fr: "Ton retour est prévu aujourd'hui",
    es: "Tu devolución es hoy",
    en: "Your return is due today",
    it: "La tua restituzione è oggi",
    de: "Deine Rückgabe ist heute fällig",
    ca: "El teu retorn és avui",
    eo: "Via redono estas hodiaŭ",
    nl: "Je moet vandaag inleveren",
    el: "Η επιστροφή σου είναι για σήμερα"
  },

  // ===== Overdue (ov.*) =====================================================
  "ov.title": {
    "pt-BR": "Aviso de atraso",
    fr: "Avis de retard",
    es: "Aviso de retraso",
    en: "Overdue notice",
    it: "Avviso di ritardo",
    de: "Überfälligkeitshinweis",
    ca: "Avís de retard",
    eo: "Malfruavizo",
    nl: "Aanmaning",
    el: "Ειδοποίηση καθυστέρησης"
  },
  "ov.1d": {
    "pt-BR": "Empréstimo em atraso",
    fr: "Emprunt en retard",
    es: "Préstamo en retraso",
    en: "Loan overdue",
    it: "Prestito in ritardo",
    de: "Ausleihe überfällig",
    ca: "Préstec endarrerit",
    eo: "Prunto malfruita",
    nl: "Uitlening te laat",
    el: "Δανεισμός σε καθυστέρηση"
  },
  "ov.1d.body": {
    "pt-BR": "Seu empréstimo está em atraso desde {date}. Por favor, providencie a devolução.",
    fr: "Ton emprunt est en retard depuis le {date}. Merci de prévoir le retour ou la prolongation.",
    es: "Tu préstamo está en retraso desde el {date}. Por favor, organiza la devolución o la renovación.",
    en: "Your loan has been overdue since {date}. Please arrange the return or a renewal.",
    it: "Il tuo prestito è in ritardo dal {date}. Per favore, organizza la restituzione o il rinnovo.",
    de: "Deine Ausleihe ist seit dem {date} überfällig. Bitte sorge für die Rückgabe oder eine Verlängerung.",
    ca: "El teu préstec està endarrerit des del {date}. Si us plau, organitza el retorn o la renovació.",
    eo: "Via prunto estas malfruita ekde la {date}. Bonvolu organizi la redonon aŭ la renovigon.",
    nl: "Je uitlening is te laat sinds {date}. Regel alsjeblieft de inlevering of een verlenging.",
    el: "Ο δανεισμός σου είναι σε καθυστέρηση από {date}. Φρόντισε για την επιστροφή ή την ανανέωση."
  },
  "ov.7d": {
    "pt-BR": "Empréstimo com {days} dias de atraso",
    fr: "Emprunt en retard de {days} jours",
    es: "Préstamo con {days} días de retraso",
    en: "Loan {days} days overdue",
    it: "Prestito in ritardo di {days} giorni",
    de: "Ausleihe seit {days} Tagen überfällig",
    ca: "Préstec amb {days} dies de retard",
    eo: "Prunto kun {days} tagoj da malfruo",
    nl: "Uitlening {days} dagen te laat",
    el: "Δανεισμός σε καθυστέρηση {days} ημερών"
  },
  "ov.7d.body": {
    "pt-BR": "Seu empréstimo está com {days} dias de atraso. Entre em contato com a biblioteca.",
    fr: "Ton emprunt est en retard de {days} jours. Contacte la bibliothèque pour trouver une solution.",
    es: "Tu préstamo está con {days} días de retraso. Contacta la biblioteca para encontrar una solución.",
    en: "Your loan is {days} days overdue. Contact the library to find a solution.",
    it: "Il tuo prestito è in ritardo di {days} giorni. Contatta la biblioteca per trovare una soluzione.",
    de: "Deine Ausleihe ist seit {days} Tagen überfällig. Kontaktiere die Bibliothek, um eine Lösung zu finden.",
    ca: "El teu préstec té {days} dies de retard. Contacta la biblioteca per trobar una solució.",
    eo: "Via prunto havas {days} tagojn da malfruo. Kontaktu la bibliotekon por trovi solvon.",
    nl: "Je uitlening is {days} dagen te laat. Neem contact op met de bibliotheek om een oplossing te vinden.",
    el: "Ο δανεισμός σου είναι σε καθυστέρηση {days} ημερών. Επικοινώνησε με τη βιβλιοθήκη για να βρεθεί λύση."
  },
  "ov.30d": {
    "pt-BR": "Empréstimo com {days} dias de atraso — situação grave",
    fr: "Emprunt en retard de {days} jours — situation à régulariser",
    es: "Préstamo con {days} días de retraso — situación a regularizar",
    en: "Loan {days} days overdue — situation to resolve",
    it: "Prestito in ritardo di {days} giorni — situazione da regolarizzare",
    de: "Ausleihe seit {days} Tagen überfällig — Situation zu klären",
    ca: "Préstec amb {days} dies de retard — situació a regularitzar",
    eo: "Prunto kun {days} tagoj da malfruo — situacio reguligenda",
    nl: "Uitlening {days} dagen te laat — situatie recht te zetten",
    el: "Δανεισμός σε καθυστέρηση {days} ημερών — κατάσταση προς τακτοποίηση"
  },
  "ov.30d.body": {
    "pt-BR": "Seu empréstimo está com {days} dias de atraso. Esta situação compromete o funcionamento da biblioteca.",
    fr: "Ton emprunt est en retard de {days} jours. Cette situation pèse sur le fonctionnement collectif de la bibliothèque. Prends contact avec la biblio pour qu'on trouve ensemble comment régulariser.",
    es: "Tu préstamo está con {days} días de retraso. Esta situación afecta el funcionamiento colectivo de la biblioteca. Toma contacto con la biblio para que encontremos juntes cómo regularizar.",
    en: "Your loan is {days} days overdue. This situation affects the collective functioning of the library. Get in touch so we can find a way forward together.",
    it: "Il tuo prestito è in ritardo di {days} giorni. Questa situazione pesa sul funzionamento collettivo della biblioteca. Mettiti in contatto con la biblio per trovare insieme una soluzione.",
    de: "Deine Ausleihe ist seit {days} Tagen überfällig. Diese Situation belastet den kollektiven Betrieb der Bibliothek. Nimm Kontakt auf, damit wir gemeinsam eine Lösung finden.",
    ca: "El teu préstec té {days} dies de retard. Aquesta situació afecta el funcionament col·lectiu de la biblioteca. Posa't en contacte amb la biblioteca perquè trobem juntes com regularitzar-ho.",
    eo: "Via prunto havas {days} tagojn da malfruo. Ĉi tiu situacio pezas sur la kolektiva funkciado de la biblioteko. Kontaktu la bibliotekon por ke ni kune trovu kiel reguligi ĝin.",
    nl: "Je uitlening is {days} dagen te laat. Deze situatie weegt op de collectieve werking van de bibliotheek. Neem contact op zodat we samen een oplossing kunnen vinden.",
    el: "Ο δανεισμός σου είναι σε καθυστέρηση {days} ημερών. Αυτή η κατάσταση επιβαρύνει τη συλλογική λειτουργία της βιβλιοθήκης. Έλα σε επαφή ώστε να βρούμε μαζί τον τρόπο να τακτοποιηθεί."
  },
  "ov.30d.admin": {
    "pt-BR": "Empréstimo com mais de 30 dias de atraso",
    fr: "Emprunt avec plus de 30 jours de retard",
    es: "Préstamo con más de 30 días de retraso",
    en: "Loan over 30 days overdue",
    it: "Prestito con oltre 30 giorni di ritardo",
    de: "Ausleihe seit über 30 Tagen überfällig",
    ca: "Préstec amb més de 30 dies de retard",
    eo: "Prunto kun pli ol 30 tagoj da malfruo",
    nl: "Uitlening meer dan 30 dagen te laat",
    el: "Δανεισμός με καθυστέρηση άνω των 30 ημερών"
  },

  // ===== Profile notices (prof.*) ===========================================
  "membership_validation_requested.subject": {
    "pt-BR": "Nova solicitação de inscrição",
    fr: "Nouvelle demande d'inscription",
    es: "Nueva solicitud de inscripción",
    en: "New sign-up request",
    it: "Nuova richiesta di iscrizione",
    de: "Neue Anmeldeanfrage",
    ca: "Nova sol·licitud d'inscripció",
    eo: "Nova aliĝpeto",
    nl: "Nieuw aanmeldverzoek",
    el: "Νέο αίτημα εγγραφής"
  },
  "membership_validation_requested.intro": {
    "pt-BR": "Uma pessoa solicitou ingressar na sua biblioteca e aguarda validação presencial.",
    fr: "Une personne demande à rejoindre votre bibliothèque et attend une validation en présentiel.",
    es: "Una persona ha solicitado unirse a vuestra biblioteca y espera una validación presencial.",
    en: "Someone has requested to join your library and is awaiting in-person validation.",
    it: "Una persona ha chiesto di unirsi alla vostra biblioteca e attende una convalida di persona.",
    de: "Jemand möchte eurer Bibliothek beitreten und wartet auf eine Bestätigung vor Ort.",
    ca: "Una persona ha sol·licitat unir-se a la vostra biblioteca i espera una validació presencial.",
    eo: "Iu petis aliĝi al via biblioteko kaj atendas surlokan validon.",
    nl: "Iemand heeft gevraagd om lid te worden van jullie bibliotheek en wacht op validatie ter plaatse.",
    el: "Κάποιο άτομο ζήτησε να εγγραφεί στη βιβλιοθήκη σας και αναμένει δια ζώσης επικύρωση."
  },
  "membership_validation_requested.actionTitle": {
    "pt-BR": "Validar a inscrição",
    fr: "Valider l'inscription",
    es: "Validar la inscripción",
    en: "Validate the sign-up",
    it: "Convalida l'iscrizione",
    de: "Anmeldung bestätigen",
    ca: "Validar la inscripció",
    eo: "Validigi la aliĝon",
    nl: "Aanmelding valideren",
    el: "Επικύρωση της εγγραφής"
  },
  "membership_validation_requested.cta": {
    "pt-BR": "Abrir o painel",
    fr: "Ouvrir le panneau",
    es: "Abrir el panel",
    en: "Open the panel",
    it: "Apri il pannello",
    de: "Panel öffnen",
    ca: "Obrir el tauler",
    eo: "Malfermi la panelon",
    nl: "Paneel openen",
    el: "Άνοιγμα του πίνακα"
  },
  "partnership.partnerLabel": {
    "pt-BR": "Biblioteca parceira", fr: "Bibliothèque partenaire", es: "Biblioteca asociada",
    en: "Partner library", it: "Biblioteca partner", de: "Partnerbibliothek",
    ca: "Biblioteca associada", eo: "Partnera biblioteko", nl: "Partnerbibliotheek",
    el: "Συνεργαζόμενη βιβλιοθήκη"
  },
  "partnership.actionTitle": {
    "pt-BR": "Gerir a parceria", fr: "Gérer le partenariat", es: "Gestionar la asociación",
    en: "Manage the partnership", it: "Gestisci il partenariato", de: "Partnerschaft verwalten",
    ca: "Gestionar el partenariat", eo: "Administri la partnerecon", nl: "Partnerschap beheren",
    el: "Διαχείριση της συνεργασίας"
  },
  "partnership.cta": {
    "pt-BR": "Abrir a biblioteca", fr: "Ouvrir la bibliothèque", es: "Abrir la biblioteca",
    en: "Open the library", it: "Apri la biblioteca", de: "Bibliothek öffnen",
    ca: "Obrir la biblioteca", eo: "Malfermi la bibliotekon", nl: "Bibliotheek openen",
    el: "Άνοιγμα της βιβλιοθήκης"
  },
  "partnership_proposed.subject": {
    "pt-BR": "Nova proposta de parceria", fr: "Nouvelle proposition de partenariat",
    es: "Nueva propuesta de asociación", en: "New partnership proposal",
    it: "Nuova proposta di partenariato", de: "Neuer Partnerschaftsvorschlag",
    ca: "Nova proposta de partenariat", eo: "Nova propono de partnereco",
    nl: "Nieuw partnerschapsvoorstel", el: "Νέα πρόταση συνεργασίας"
  },
  "partnership_proposed.intro": {
    "pt-BR": "A biblioteca parceira abaixo propôs uma parceria à sua biblioteca. Você pode aceitá-la ou recusá-la na página da biblioteca.",
    fr: "La bibliothèque partenaire ci-dessous propose un partenariat à votre bibliothèque. Vous pouvez l'accepter ou la refuser depuis la page de la bibliothèque.",
    es: "La biblioteca asociada indicada abajo ha propuesto una asociación a vuestra biblioteca. Podéis aceptarla o rechazarla desde la página de la biblioteca.",
    en: "The partner library below has proposed a partnership to your library. You can accept or decline it from the library page.",
    it: "La biblioteca partner qui sotto ha proposto un partenariato alla vostra biblioteca. Potete accettarlo o rifiutarlo dalla pagina della biblioteca.",
    de: "Die unten genannte Partnerbibliothek hat eurer Bibliothek eine Partnerschaft vorgeschlagen. Ihr könnt sie auf der Bibliotheksseite annehmen oder ablehnen.",
    ca: "La biblioteca associada de sota ha proposat un partenariat a la vostra biblioteca. Podeu acceptar-lo o rebutjar-lo des de la pàgina de la biblioteca.",
    eo: "La suba partnera biblioteko proponis partnerecon al via biblioteko. Vi povas akcepti aŭ rifuzi ĝin el la bibliotekpaĝo.",
    nl: "De onderstaande partnerbibliotheek heeft jullie bibliotheek een partnerschap voorgesteld. Je kunt het accepteren of weigeren op de bibliotheekpagina.",
    el: "Η παρακάτω συνεργαζόμενη βιβλιοθήκη πρότεινε συνεργασία στη βιβλιοθήκη σας. Μπορείτε να την αποδεχτείτε ή να την απορρίψετε από τη σελίδα της βιβλιοθήκης."
  },
  "partnership_accepted.subject": {
    "pt-BR": "Parceria aceita", fr: "Partenariat accepté", es: "Asociación aceptada",
    en: "Partnership accepted", it: "Partenariato accettato", de: "Partnerschaft angenommen",
    ca: "Partenariat acceptat", eo: "Partnereco akceptita", nl: "Partnerschap geaccepteerd",
    el: "Η συνεργασία έγινε δεκτή"
  },
  "partnership_accepted.intro": {
    "pt-BR": "A biblioteca parceira aceitou sua proposta de parceria. A parceria está agora ativa: você pode ativar os direitos recíprocos na página da biblioteca.",
    fr: "La bibliothèque partenaire a accepté votre proposition de partenariat. Le partenariat est désormais actif : vous pouvez activer les droits réciproques depuis la page de la bibliothèque.",
    es: "La biblioteca asociada ha aceptado vuestra propuesta de asociación. La asociación está ahora activa: podéis activar los derechos recíprocos desde la página de la biblioteca.",
    en: "The partner library has accepted your partnership proposal. The partnership is now active: you can enable the reciprocal rights from the library page.",
    it: "La biblioteca partner ha accettato la vostra proposta di partenariato. Il partenariato è ora attivo: potete attivare i diritti reciproci dalla pagina della biblioteca.",
    de: "Die Partnerbibliothek hat euren Partnerschaftsvorschlag angenommen. Die Partnerschaft ist nun aktiv: Ihr könnt die gegenseitigen Rechte auf der Bibliotheksseite aktivieren.",
    ca: "La biblioteca associada ha acceptat la vostra proposta de partenariat. El partenariat ja és actiu: podeu activar els drets recíprocs des de la pàgina de la biblioteca.",
    eo: "La partnera biblioteko akceptis vian proponon de partnereco. La partnereco nun estas aktiva: vi povas aktivigi la reciprokajn rajtojn el la bibliotekpaĝo.",
    nl: "De partnerbibliotheek heeft jullie partnerschapsvoorstel geaccepteerd. Het partnerschap is nu actief: je kunt de wederzijdse rechten op de bibliotheekpagina inschakelen.",
    el: "Η συνεργαζόμενη βιβλιοθήκη αποδέχτηκε την πρότασή σας για συνεργασία. Η συνεργασία είναι πλέον ενεργή: μπορείτε να ενεργοποιήσετε τα αμοιβαία δικαιώματα από τη σελίδα της βιβλιοθήκης."
  },
  "partnership_refused.subject": {
    "pt-BR": "Proposta de parceria recusada", fr: "Proposition de partenariat refusée",
    es: "Propuesta de asociación rechazada", en: "Partnership proposal declined",
    it: "Proposta di partenariato rifiutata", de: "Partnerschaftsvorschlag abgelehnt",
    ca: "Proposta de partenariat rebutjada", eo: "Propono de partnereco rifuzita",
    nl: "Partnerschapsvoorstel geweigerd", el: "Η πρόταση συνεργασίας απορρίφθηκε"
  },
  "partnership_refused.intro": {
    "pt-BR": "A biblioteca parceira recusou sua proposta de parceria. Você pode propor novamente mais tarde, se desejar.",
    fr: "La bibliothèque partenaire a refusé votre proposition de partenariat. Vous pourrez en proposer une nouvelle plus tard si vous le souhaitez.",
    es: "La biblioteca asociada ha rechazado vuestra propuesta de asociación. Podréis proponer otra más adelante si lo deseáis.",
    en: "The partner library has declined your partnership proposal. You may propose again later if you wish.",
    it: "La biblioteca partner ha rifiutato la vostra proposta di partenariato. Potete riproporla più avanti, se lo desiderate.",
    de: "Die Partnerbibliothek hat euren Partnerschaftsvorschlag abgelehnt. Ihr könnt später erneut einen Vorschlag machen, wenn ihr möchtet.",
    ca: "La biblioteca associada ha rebutjat la vostra proposta de partenariat. Podeu tornar a proposar-ne una més endavant si voleu.",
    eo: "La partnera biblioteko rifuzis vian proponon de partnereco. Vi povas reproponi poste, se vi deziras.",
    nl: "De partnerbibliotheek heeft jullie partnerschapsvoorstel geweigerd. Je kunt later opnieuw een voorstel doen als je wilt.",
    el: "Η συνεργαζόμενη βιβλιοθήκη απέρριψε την πρότασή σας για συνεργασία. Μπορείτε να προτείνετε ξανά αργότερα, αν θέλετε."
  },
  "partnership_broken.subject": {
    "pt-BR": "Parceria encerrada", fr: "Partenariat rompu", es: "Asociación finalizada",
    en: "Partnership ended", it: "Partenariato terminato", de: "Partnerschaft beendet",
    ca: "Partenariat finalitzat", eo: "Partnereco ĉesigita", nl: "Partnerschap beëindigd",
    el: "Η συνεργασία τερματίστηκε"
  },
  "partnership_broken.intro": {
    "pt-BR": "A parceria com a biblioteca parceira abaixo foi encerrada. Os direitos recíprocos foram desativados nos dois lados.",
    fr: "Le partenariat avec la bibliothèque partenaire ci-dessous a été rompu. Les droits réciproques ont été désactivés des deux côtés.",
    es: "La asociación con la biblioteca asociada indicada abajo ha finalizado. Los derechos recíprocos se han desactivado en ambos lados.",
    en: "The partnership with the partner library below has ended. The reciprocal rights have been disabled on both sides.",
    it: "Il partenariato con la biblioteca partner qui sotto è terminato. I diritti reciproci sono stati disattivati da entrambi i lati.",
    de: "Die Partnerschaft mit der unten genannten Partnerbibliothek wurde beendet. Die gegenseitigen Rechte wurden auf beiden Seiten deaktiviert.",
    ca: "El partenariat amb la biblioteca associada de sota ha finalitzat. Els drets recíprocs s'han desactivat a banda i banda.",
    eo: "La partnereco kun la suba partnera biblioteko ĉesis. La reciprokaj rajtoj estis malaktivigitaj ambaŭflanke.",
    nl: "Het partnerschap met de onderstaande partnerbibliotheek is beëindigd. De wederzijdse rechten zijn aan beide kanten uitgeschakeld.",
    el: "Η συνεργασία με την παρακάτω συνεργαζόμενη βιβλιοθήκη τερματίστηκε. Τα αμοιβαία δικαιώματα απενεργοποιήθηκαν και στις δύο πλευρές."
  },
  "partnership_transparence_enabled.subject": {
    "pt-BR": "Compartilhamento entre suas bibliotecas: seu consentimento",
    fr: "Partage entre tes bibliothèques : ton consentement",
    es: "Compartir entre tus bibliotecas: tu consentimiento",
    en: "Sharing between your libraries: your consent",
    it: "Condivisione tra le tue biblioteche: il tuo consenso",
    de: "Austausch zwischen deinen Bibliotheken: deine Zustimmung",
    ca: "Compartició entre les teves biblioteques: el teu consentiment",
    eo: "Kunhavigo inter viaj bibliotekoj: via konsento",
    nl: "Delen tussen je bibliotheken: jouw toestemming",
    el: "Κοινή χρήση μεταξύ των βιβλιοθηκών σου: η συγκατάθεσή σου"
  },
  "partnership_transparence_enabled.intro": {
    "pt-BR": "Duas bibliotecas das quais você é membro(a/e) formaram uma parceria e ativaram um compartilhamento de informações sobre você entre elas (« transparência »). Esse compartilhamento só vale se você consentir. Você pode dar ou retirar seu consentimento a qualquer momento no seu espaço.",
    fr: "Deux bibliothèques dont tu es membre ont formé un partenariat et activé un partage d'informations te concernant entre elles (« transparence »). Ce partage ne prend effet que si tu y consens. Tu peux donner ou retirer ton consentement à tout moment depuis ton espace.",
    es: "Dos bibliotecas de las que sos miembre formaron una asociación y activaron un intercambio de información sobre vos entre ellas (« transparencia »). Ese intercambio solo tiene efecto si das tu consentimiento. Podés darlo o retirarlo en cualquier momento desde tu espacio.",
    en: "Two libraries you belong to have formed a partnership and enabled sharing of information about you between them (« transparency »). This sharing only takes effect if you consent to it. You can give or withdraw your consent at any time from your account.",
    it: "Due biblioteche di cui fai parte hanno avviato un partenariato e attivato una condivisione di informazioni che ti riguardano tra di loro (« trasparenza »). Questa condivisione ha effetto solo se vi acconsenti. Puoi dare o revocare il tuo consenso in qualsiasi momento dal tuo spazio.",
    de: "Zwei Bibliotheken, in denen du Mitglied bist, sind eine Partnerschaft eingegangen und haben einen Austausch von Informationen über dich zwischen ihnen aktiviert (« Transparenz »). Dieser Austausch wird nur wirksam, wenn du zustimmst. Du kannst deine Zustimmung jederzeit in deinem Konto geben oder widerrufen.",
    ca: "Dues biblioteques de les quals ets membre han format un partenariat i han activat una compartició d'informació sobre tu entre elles (« transparència »). Aquesta compartició només té efecte si hi dónes el teu consentiment. Pots donar-lo o retirar-lo en qualsevol moment des del teu espai.",
    eo: "Du bibliotekoj, al kiuj vi apartenas, formis partnerecon kaj aktivigis kunhavigon de informoj pri vi inter ili (« travidebleco »). Tiu kunhavigo efikas nur se vi konsentas. Vi povas doni aŭ retiri vian konsenton iam ajn el via konto.",
    nl: "Twee bibliotheken waar je lid van bent zijn een partnerschap aangegaan en hebben het delen van informatie over jou tussen hen ingeschakeld (« transparantie »). Dit delen werkt alleen als je ermee instemt. Je kunt je toestemming op elk moment geven of intrekken vanuit je account.",
    el: "Δύο βιβλιοθήκες στις οποίες ανήκεις σύναψαν συνεργασία και ενεργοποίησαν την κοινή χρήση πληροφοριών που σε αφορούν μεταξύ τους (« διαφάνεια »). Η κοινή χρήση ισχύει μόνο αν συναινέσεις. Μπορείς να δώσεις ή να ανακαλέσεις τη συγκατάθεσή σου ανά πάσα στιγμή από τον λογαριασμό σου."
  },
  "partnership_transparence_enabled.librariesLabel": {
    "pt-BR": "Bibliotecas envolvidas", fr: "Bibliothèques concernées", es: "Bibliotecas implicadas",
    en: "Libraries involved", it: "Biblioteche coinvolte", de: "Beteiligte Bibliotheken",
    ca: "Biblioteques implicades", eo: "Koncernataj bibliotekoj", nl: "Betrokken bibliotheken",
    el: "Εμπλεκόμενες βιβλιοθήκες"
  },
  "partnership_transparence_enabled.actionTitle": {
    "pt-BR": "Gerir seu consentimento", fr: "Gérer ton consentement", es: "Gestionar tu consentimiento",
    en: "Manage your consent", it: "Gestisci il tuo consenso", de: "Deine Zustimmung verwalten",
    ca: "Gestionar el teu consentiment", eo: "Administri vian konsenton", nl: "Je toestemming beheren",
    el: "Διαχείριση της συγκατάθεσής σου"
  },
  "partnership_transparence_enabled.cta": {
    "pt-BR": "Minha conta", fr: "Mon compte", es: "Mi cuenta", en: "My account",
    it: "Il mio spazio", de: "Mein Konto", ca: "El meu compte", eo: "Mia konto",
    nl: "Mijn account", el: "Ο λογαριασμός μου"
  },
  "partnership_config_expanded.subject": {
    "pt-BR": "Os termos de uma parceria mudaram: revise seu consentimento",
    fr: "Les conditions d'un partenariat ont changé : réexamine ton consentement",
    es: "Cambiaron las condiciones de una asociación: revisá tu consentimiento",
    en: "A partnership's terms changed: review your consent",
    it: "Le condizioni di un partenariato sono cambiate: rivedi il tuo consenso",
    de: "Die Bedingungen einer Partnerschaft haben sich geändert: prüfe deine Zustimmung",
    ca: "Han canviat les condicions d'un partenariat: revisa el teu consentiment",
    eo: "La kondiĉoj de partnereco ŝanĝiĝis: rekontrolu vian konsenton",
    nl: "De voorwaarden van een partnerschap zijn gewijzigd: herzie je toestemming",
    el: "Οι όροι μιας συνεργασίας άλλαξαν: αναθεώρησε τη συγκατάθεσή σου"
  },
  "partnership_config_expanded.intro": {
    "pt-BR": "Uma parceria entre duas bibliotecas das quais você é membro(a/e) ampliou seu compartilhamento. Seu consentimento anterior não cobre mais os novos termos: enquanto você não o revisar, o compartilhamento ampliado sobre você fica pausado. Você pode reexaminar e renovar (ou recusar) seu consentimento no seu espaço.",
    fr: "Un partenariat entre deux bibliothèques dont tu es membre a élargi son partage. Ton consentement précédent ne couvre plus les nouvelles conditions : tant que tu ne l'as pas réexaminé, le partage élargi te concernant reste en pause. Tu peux réexaminer et renouveler (ou refuser) ton consentement depuis ton espace.",
    es: "Una asociación entre dos bibliotecas de las que sos miembre amplió su intercambio. Tu consentimiento anterior ya no cubre las nuevas condiciones: mientras no lo revisés, el intercambio ampliado sobre vos queda en pausa. Podés revisar y renovar (o rechazar) tu consentimiento desde tu espacio.",
    en: "A partnership between two libraries you belong to has expanded its sharing. Your previous consent no longer covers the new terms: until you review it, the expanded sharing about you stays paused. You can review and renew (or refuse) your consent from your account.",
    it: "Un partenariato tra due biblioteche di cui fai parte ha ampliato la sua condivisione. Il tuo consenso precedente non copre più le nuove condizioni: finché non lo riesamini, la condivisione ampliata che ti riguarda resta sospesa. Puoi riesaminare e rinnovare (o rifiutare) il tuo consenso dal tuo spazio.",
    de: "Eine Partnerschaft zwischen zwei Bibliotheken, in denen du Mitglied bist, hat ihren Austausch erweitert. Deine bisherige Zustimmung deckt die neuen Bedingungen nicht mehr ab: Bis du sie prüfst, bleibt der erweiterte Austausch über dich pausiert. Du kannst deine Zustimmung in deinem Konto prüfen und erneuern (oder ablehnen).",
    ca: "Un partenariat entre dues biblioteques de les quals ets membre ha ampliat la seva compartició. El teu consentiment anterior ja no cobreix les noves condicions: mentre no el revisis, la compartició ampliada sobre tu queda en pausa. Pots revisar i renovar (o rebutjar) el teu consentiment des del teu espai.",
    eo: "Partnereco inter du bibliotekoj, al kiuj vi apartenas, plilarĝigis sian kunhavigon. Via antaŭa konsento ne plu kovras la novajn kondiĉojn: ĝis vi rekontrolas ĝin, la plilarĝigita kunhavigo pri vi restas paŭzigita. Vi povas rekontroli kaj renovigi (aŭ rifuzi) vian konsenton el via konto.",
    nl: "Een partnerschap tussen twee bibliotheken waar je lid van bent heeft het delen uitgebreid. Je vorige toestemming dekt de nieuwe voorwaarden niet meer: zolang je het niet herziet, blijft het uitgebreide delen over jou gepauzeerd. Je kunt je toestemming herzien en vernieuwen (of weigeren) vanuit je account.",
    el: "Μια συνεργασία μεταξύ δύο βιβλιοθηκών στις οποίες ανήκεις διεύρυνε την κοινή χρήση της. Η προηγούμενη συγκατάθεσή σου δεν καλύπτει πλέον τους νέους όρους: μέχρι να την αναθεωρήσεις, η διευρυμένη κοινή χρήση που σε αφορά παραμένει σε παύση. Μπορείς να αναθεωρήσεις και να ανανεώσεις (ή να αρνηθείς) τη συγκατάθεσή σου από τον λογαριασμό σου."
  },
  "partnership_config_expanded.actionTitle": {
    "pt-BR": "Reexaminar seu consentimento", fr: "Réexaminer ton consentement",
    es: "Revisar tu consentimiento", en: "Review your consent",
    it: "Riesaminare il tuo consenso", de: "Deine Zustimmung prüfen",
    ca: "Revisar el teu consentiment", eo: "Rekontroli vian konsenton",
    nl: "Je toestemming herzien", el: "Αναθεώρηση της συγκατάθεσής σου"
  },
  "validation_confirmed.subject": {
    "pt-BR": "Inscrição confirmada",
    fr: "Inscription confirmée",
    es: "Inscripción confirmada",
    en: "Sign-up confirmed",
    it: "Iscrizione confermata",
    de: "Anmeldung bestätigt",
    ca: "Inscripció confirmada",
    eo: "Aliĝo konfirmita",
    nl: "Aanmelding bevestigd",
    el: "Η εγγραφή επιβεβαιώθηκε"
  },
  "validation_confirmed.intro": {
    "pt-BR": "Sua inscrição foi validada pela equipe. Agora você pode reservar e pegar documentos emprestados.",
    fr: "Ton inscription a été validée par l'équipe. Tu peux désormais réserver et emprunter des documents.",
    es: "Tu inscripción fue validada por el equipo. Ya puedes reservar y tomar prestados documentos.",
    en: "Your sign-up has been validated by the team. You can now reserve and borrow items.",
    it: "La tua iscrizione è stata convalidata dal gruppo. Ora puoi prenotare e prendere in prestito documenti.",
    de: "Deine Anmeldung wurde vom Team bestätigt. Du kannst jetzt Medien vormerken und ausleihen.",
    ca: "La teva inscripció ha estat validada per l'equip. Ara pots reservar i agafar en préstec documents.",
    eo: "Via aliĝo estis validigita de la teamo. Vi nun povas rezervi kaj prunti dokumentojn.",
    nl: "Je aanmelding is gevalideerd door het team. Je kunt nu materialen reserveren en lenen.",
    el: "Η εγγραφή σου επικυρώθηκε από την ομάδα. Μπορείς πλέον να κρατάς και να δανείζεσαι τεκμήρια."
  },
  "validation_confirmed.libraryLabel": {
    "pt-BR": "Biblioteca",
    fr: "Bibliothèque",
    es: "Biblioteca",
    en: "Library",
    it: "Biblioteca",
    de: "Bibliothek",
    ca: "Biblioteca",
    eo: "Biblioteko",
    nl: "Bibliotheek",
    el: "Βιβλιοθήκη"
  },
  "validation_confirmed.readerNumberLabel": {
    "pt-BR": "Nº de leitor(a)",
    fr: "N° de lecteur·rice",
    es: "Nº de lector·a",
    en: "Reader no.",
    it: "N° lettore/trice",
    de: "Leser*in-Nr.",
    ca: "Núm. de lector·a",
    eo: "Leganto-n-ro",
    nl: "Lezersnr.",
    el: "Αρ. μέλους"
  },
  "validation_confirmed.actionTitle": {
    "pt-BR": "Acesse seu espaço",
    fr: "Accède à ton espace",
    es: "Accede a tu espacio",
    en: "Go to your account",
    it: "Vai al tuo spazio",
    de: "Zu deinem Konto",
    ca: "Accedeix al teu espai",
    eo: "Iru al via konto",
    nl: "Ga naar je account",
    el: "Μετάβαση στον λογαριασμό σου"
  },
  "validation_confirmed.cta": {
    "pt-BR": "Minha conta",
    fr: "Mon compte",
    es: "Mi cuenta",
    en: "My account",
    it: "Il mio account",
    de: "Mein Konto",
    ca: "El meu compte",
    eo: "Mia konto",
    nl: "Mijn account",
    el: "Ο λογαριασμός μου"
  },
  "reader_identity_assigned.subject": {
    "pt-BR": "Tua identidade de leitor(a/e)",
    fr: "Ton identité de lecteur·rice",
    es: "Tu identidad de lectore",
    en: "Your reader identity",
    it: "La tua identità di lettore/trice",
    de: "Deine Leser*in-Kennung",
    ca: "La teva identitat de lector-a-e",
    eo: "Via legant-in-a identigo",
    nl: "Je lezersidentiteit",
    el: "Η ταυτότητά σου ως αναγνώστη/στριας"
  },
  "reader_identity_assigned.intro": {
    "pt-BR": "A equipe te atribuiu uma identidade nesta biblioteca. Podes apresentá-la nas tuas visitas.",
    fr: "L'équipe t'a attribué une identité dans cette bibliothèque. Tu peux la présenter lors de tes passages.",
    es: "El equipo te asignó una identidad en esta biblioteca. Puedes presentarla en tus visitas.",
    en: "The team assigned you an identity at this library. You can show it when you visit.",
    it: "Il gruppo ti ha assegnato un'identità in questa biblioteca. Puoi mostrarla quando passi.",
    de: "Das Team hat dir in dieser Bibliothek eine Kennung zugewiesen. Du kannst sie bei deinen Besuchen vorzeigen.",
    ca: "L'equip t'ha assignat una identitat en aquesta biblioteca. Pots presentar-la a les teves visites.",
    eo: "La teamo atribuis al vi identigon en ĉi tiu biblioteko. Vi povas montri ĝin dum viaj vizitoj.",
    nl: "Het team heeft je een identiteit toegekend bij deze bibliotheek. Je kunt die tonen bij je bezoek.",
    el: "Η ομάδα σού απέδωσε μια ταυτότητα σε αυτή τη βιβλιοθήκη. Μπορείς να την δείχνεις στις επισκέψεις σου."
  },
  "reader_identity_assigned.identityLabel": {
    "pt-BR": "Identidade",
    fr: "Identité",
    es: "Identidad",
    en: "Identity",
    it: "Identità",
    de: "Kennung",
    ca: "Identitat",
    eo: "Identigo",
    nl: "Identiteit",
    el: "Ταυτότητα"
  },
  "reader_identity_assigned.adminSubject": {
    "pt-BR": "Identidade atribuída",
    fr: "Identité attribuée",
    es: "Identidad asignada",
    en: "Identity assigned",
    it: "Identità assegnata",
    de: "Kennung zugewiesen",
    ca: "Identitat assignada",
    eo: "Identigo atribuita",
    nl: "Identiteit toegekend",
    el: "Αποδόθηκε ταυτότητα"
  },
  "reader_identity_assigned.adminIntro": {
    "pt-BR": "Uma identidade local foi atribuída a {reader} em {library}.",
    fr: "Une identité locale a été attribuée à {reader} dans {library}.",
    es: "Se asignó una identidad local a {reader} en {library}.",
    en: "A local identity was assigned to {reader} at {library}.",
    it: "È stata assegnata un'identità locale a {reader} in {library}.",
    de: "{reader} wurde in {library} eine lokale Kennung zugewiesen.",
    ca: "S'ha assignat una identitat local a {reader} a {library}.",
    eo: "Loka identigo estis atribuita al {reader} en {library}.",
    nl: "Aan {reader} is een lokale identiteit toegekend bij {library}.",
    el: "Αποδόθηκε τοπική ταυτότητα σε {reader} στη {library}."
  },
  "cotisation.payment.subject": {
    "pt-BR": "Pagamento de contribuição registrado",
    fr: "Paiement de cotisation enregistré",
    es: "Pago de cuota registrado",
    en: "Membership payment recorded",
    it: "Pagamento del contributo registrato",
    de: "Beitragszahlung erfasst",
    ca: "Pagament de quota registrat",
    eo: "Kotizpago registrita",
    nl: "Bijdragebetaling geregistreerd",
    el: "Η πληρωμή συνδρομής καταχωρήθηκε"
  },
  "cotisation.payment.intro": {
    "pt-BR": "Sua contribuição foi registrada. Aqui está o seu comprovante.",
    fr: "Ta cotisation a été enregistrée. Voici ton reçu.",
    es: "Tu cuota fue registrada. Aquí tienes tu comprobante.",
    en: "Your contribution has been recorded. Here is your receipt.",
    it: "Il tuo contributo è stato registrato. Ecco la tua ricevuta.",
    de: "Dein Beitrag wurde erfasst. Hier ist deine Quittung.",
    ca: "La teva quota s'ha registrat. Aquí tens el teu comprovant.",
    eo: "Via kotizo estis registrita. Jen via kvitanco.",
    nl: "Je bijdrage is geregistreerd. Hier is je bewijs.",
    el: "Η συνεισφορά σου καταχωρήθηκε. Ορίστε η απόδειξή σου."
  },
  "cot.noExpiry": {
    "pt-BR": "sem vencimento",
    fr: "sans échéance",
    es: "sin vencimiento",
    en: "no expiry",
    it: "senza scadenza",
    de: "ohne Ablauf",
    ca: "sense venciment",
    eo: "sen limdato",
    nl: "zonder vervaldatum",
    el: "χωρίς λήξη"
  },
  "l.cotAmount": {
    "pt-BR": "Valor",
    fr: "Montant",
    es: "Importe",
    en: "Amount",
    it: "Importo",
    de: "Betrag",
    ca: "Import",
    eo: "Sumo",
    nl: "Bedrag",
    el: "Ποσό"
  },
  "l.cotPeriod": {
    "pt-BR": "Período de validade",
    fr: "Période de validité",
    es: "Período de validez",
    en: "Validity period",
    it: "Periodo di validità",
    de: "Gültigkeitszeitraum",
    ca: "Període de validesa",
    eo: "Validperiodo",
    nl: "Geldigheidsperiode",
    el: "Περίοδος ισχύος"
  },
  "l.cotMethod": {
    "pt-BR": "Forma de pagamento",
    fr: "Moyen de paiement",
    es: "Forma de pago",
    en: "Payment method",
    it: "Metodo di pagamento",
    de: "Zahlungsart",
    ca: "Forma de pagament",
    eo: "Pagmaniero",
    nl: "Betaalwijze",
    el: "Τρόπος πληρωμής"
  },
  "cot.method.cash": {
    "pt-BR": "Dinheiro",
    fr: "Espèces",
    es: "Efectivo",
    en: "Cash",
    it: "Contanti",
    de: "Bargeld",
    ca: "Efectiu",
    eo: "Kontanta mono",
    nl: "Contant",
    el: "Μετρητά"
  },
  "cot.method.transfer": {
    "pt-BR": "Transferência",
    fr: "Virement",
    es: "Transferencia",
    en: "Bank transfer",
    it: "Bonifico",
    de: "Überweisung",
    ca: "Transferència",
    eo: "Bankĝiro",
    nl: "Overschrijving",
    el: "Τραπεζικό έμβασμα"
  },
  "cot.method.card": {
    "pt-BR": "Cartão",
    fr: "Carte",
    es: "Tarjeta",
    en: "Card",
    it: "Carta",
    de: "Karte",
    ca: "Targeta",
    eo: "Karto",
    nl: "Kaart",
    el: "Κάρτα"
  },
  "cot.method.check": {
    "pt-BR": "Cheque",
    fr: "Chèque",
    es: "Cheque",
    en: "Check",
    it: "Assegno",
    de: "Scheck",
    ca: "Xec",
    eo: "Ĉeko",
    nl: "Cheque",
    el: "Επιταγή"
  },
  "cot.method.in_kind": {
    "pt-BR": "Em espécie",
    fr: "En nature",
    es: "En especie",
    en: "In kind",
    it: "In natura",
    de: "Sachleistung",
    ca: "En espècie",
    eo: "Naturkotizo",
    nl: "In natura",
    el: "Σε είδος"
  },
  "cot.method.exemption": {
    "pt-BR": "Isenção",
    fr: "Exemption",
    es: "Exención",
    en: "Exemption",
    it: "Esenzione",
    de: "Befreiung",
    ca: "Exempció",
    eo: "Sendevigo",
    nl: "Vrijstelling",
    el: "Απαλλαγή"
  },
  "cot.method.other": {
    "pt-BR": "Outro",
    fr: "Autre",
    es: "Otro",
    en: "Other",
    it: "Altro",
    de: "Andere",
    ca: "Altre",
    eo: "Alia",
    nl: "Anders",
    el: "Άλλο"
  },
  "restriction.global.subject": {
    "pt-BR": "Conta congelada (rede)",
    fr: "Compte gelé (réseau)",
    es: "Cuenta congelada (red)",
    en: "Account frozen (network)",
    it: "Account congelato (rete)",
    de: "Konto gesperrt (Netzwerk)",
    ca: "Compte congelat (xarxa)",
    eo: "Konto frostigita (reto)",
    nl: "Account bevroren (netwerk)",
    el: "Λογαριασμός παγωμένος (δίκτυο)"
  },
  "restriction.global.intro": {
    "pt-BR": "Sua conta foi congelada em toda a rede.",
    fr: "Ton compte a été gelé sur l'ensemble du réseau.",
    es: "Tu cuenta fue congelada en toda la red.",
    en: "Your account has been frozen across the whole network.",
    it: "Il tuo account è stato congelato su tutta la rete.",
    de: "Dein Konto wurde im gesamten Netzwerk gesperrt.",
    ca: "El teu compte s'ha congelat a tota la xarxa.",
    eo: "Via konto estis frostigita tra la tuta reto.",
    nl: "Je account is in het hele netwerk bevroren.",
    el: "Ο λογαριασμός σου παγώθηκε σε όλο το δίκτυο."
  },
  "restriction.lifted.subject": {
    "pt-BR": "Restrição removida",
    fr: "Restriction levée",
    es: "Restricción retirada",
    en: "Restriction lifted",
    it: "Restrizione rimossa",
    de: "Einschränkung aufgehoben",
    ca: "Restricció retirada",
    eo: "Restrikto forigita",
    nl: "Beperking opgeheven",
    el: "Ο περιορισμός ήρθη"
  },
  "restriction.lifted.intro": {
    "pt-BR": "Sua restrição foi removida. Sua conta está novamente plenamente ativa.",
    fr: "Ta restriction a été levée. Ton compte est de nouveau pleinement actif.",
    es: "Tu restricción fue retirada. Tu cuenta vuelve a estar plenamente activa.",
    en: "Your restriction has been lifted. Your account is fully active again.",
    it: "La tua restrizione è stata rimossa. Il tuo account è di nuovo pienamente attivo.",
    de: "Deine Einschränkung wurde aufgehoben. Dein Konto ist wieder voll aktiv.",
    ca: "La teva restricció s'ha retirat. El teu compte torna a estar plenament actiu.",
    eo: "Via restrikto estis forigita. Via konto denove estas plene aktiva.",
    nl: "Je beperking is opgeheven. Je account is weer volledig actief.",
    el: "Ο περιορισμός σου ήρθη. Ο λογαριασμός σου είναι ξανά πλήρως ενεργός."
  },
  "l.scope": {
    "pt-BR": "Abrangência",
    fr: "Portée",
    es: "Alcance",
    en: "Scope",
    it: "Ambito",
    de: "Geltungsbereich",
    ca: "Abast",
    eo: "Amplekso",
    nl: "Bereik",
    el: "Εμβέλεια"
  },
  "restriction.scope.network": {
    "pt-BR": "Rede AnarBib",
    fr: "Réseau AnarBib",
    es: "Red AnarBib",
    en: "AnarBib network",
    it: "Rete AnarBib",
    de: "AnarBib-Netzwerk",
    ca: "Xarxa AnarBib",
    eo: "Reto AnarBib",
    nl: "AnarBib-netwerk",
    el: "Δίκτυο AnarBib"
  },
  "prof.restricted": {
    "pt-BR": "Cadastro com restrições",
    fr: "Compte avec restrictions",
    es: "Cuenta con restricciones",
    en: "Account with restrictions",
    it: "Account con restrizioni",
    de: "Konto mit Einschränkungen",
    ca: "Compte amb restriccions",
    eo: "Konto kun restriktoj",
    nl: "Account met beperkingen",
    el: "Λογαριασμός με περιορισμούς"
  },
  "prof.restricted.intro": {
    "pt-BR": "Seu cadastro foi marcado com restrições.",
    fr: "Ton compte a été marqué avec des restrictions.",
    es: "Tu cuenta fue marcada con restricciones.",
    en: "Your account has been marked with restrictions.",
    it: "Il tuo account è stato segnato con restrizioni.",
    de: "Dein Konto wurde mit Einschränkungen markiert.",
    ca: "El teu compte s'ha marcat amb restriccions.",
    eo: "Via konto estis markita kun restriktoj.",
    nl: "Je account is gemarkeerd met beperkingen.",
    el: "Ο λογαριασμός σου επισημάνθηκε με περιορισμούς."
  },
  "prof.contactLibrary": {
    "pt-BR": "Entre em contato com a biblioteca para regularizar sua situação.",
    fr: "Contacte la bibliothèque pour régulariser ta situation.",
    es: "Contacta la biblioteca para regularizar tu situación.",
    en: "Contact the library to resolve your situation.",
    it: "Contatta la biblioteca per regolarizzare la tua situazione.",
    de: "Kontaktiere die Bibliothek, um deine Situation zu klären.",
    ca: "Contacta la biblioteca per regularitzar la teva situació.",
    eo: "Kontaktu la bibliotekon por reguligi vian situacion.",
    nl: "Neem contact op met de bibliotheek om je situatie recht te zetten.",
    el: "Επικοινώνησε με τη βιβλιοθήκη για να τακτοποιήσεις την κατάστασή σου."
  },
  "prof.formalNotice": {
    "pt-BR": "Aviso formal de restrição",
    fr: "Avis formel concernant la restriction",
    es: "Aviso formal sobre la restricción",
    en: "Formal notice regarding the restriction",
    it: "Avviso formale relativo alla restrizione",
    de: "Formelle Mitteilung zur Einschränkung",
    ca: "Avís formal sobre la restricció",
    eo: "Formala avizo pri la restrikto",
    nl: "Formele kennisgeving over de beperking",
    el: "Τυπική ειδοποίηση σχετικά με τον περιορισμό"
  },
  "prof.formalNotice.intro": {
    "pt-BR": "Esta mensagem é um aviso formal sobre a restrição d(o/a/e) seu cadastro.",
    fr: "Ce message est un avis formel concernant la restriction de ton compte.",
    es: "Este mensaje es un aviso formal sobre la restricción de tu cuenta.",
    en: "This message is a formal notice regarding the restriction on your account.",
    it: "Questo messaggio è un avviso formale relativo alla restrizione del tuo account.",
    de: "Diese Nachricht ist eine formelle Mitteilung zur Einschränkung deines Kontos.",
    ca: "Aquest missatge és un avís formal sobre la restricció del teu compte.",
    eo: "Ĉi tiu mesaĝo estas formala avizo pri la restrikto de via konto.",
    nl: "Dit bericht is een formele kennisgeving over de beperking van je account.",
    el: "Αυτό το μήνυμα είναι μια τυπική ειδοποίηση σχετικά με τον περιορισμό του λογαριασμού σου."
  },

  // ===== Pickup reply (pr.*) — admin-only mais traduit pour cohérence ======
  "pr.readerReply": {
    "pt-BR": "Resposta d(o/a/e) leitor(a/e) sobre a retirada",
    fr: "Réponse du·de la lecteur·rice sur le retrait",
    es: "Respuesta de le lector(a/e) sobre el retiro",
    en: "Reader reply about pickup",
    it: "Risposta del/la lettore/trice sul ritiro",
    de: "Antwort der*des Leser*in zur Abholung",
    ca: "Resposta de le lector-a-e sobre la recollida",
    eo: "Respondo de la legant-in-o pri la elpreno",
    nl: "Reactie van de lezer over de afhaling",
    el: "Απάντηση αναγνώστη/στριας για την παραλαβή"
  },
  "pr.confirmed": {
    "pt-BR": "Leitor(a/e) confirmou o horário de retirada",
    fr: "Le·la lecteur·rice a confirmé l'horaire de retrait",
    es: "Le lector(a/e) confirmó el horario de retiro",
    en: "Reader confirmed the pickup time",
    it: "Il/la lettore/trice ha confermato l'orario di ritiro",
    de: "Leser*in hat den Abholzeitpunkt bestätigt",
    ca: "Le lector-a-e ha confirmat l'horari de recollida",
    eo: "La legant-in-o konfirmis la elpren-horon",
    nl: "De lezer heeft het afhaalmoment bevestigd",
    el: "Ο/Η αναγνώστης/στρια επιβεβαίωσε τον χρόνο παραλαβής"
  },
  "pr.declined": {
    "pt-BR": "Leitor(a/e) não pode no horário proposto",
    fr: "Le·la lecteur·rice ne peut pas à l'horaire proposé",
    es: "Le lector(a/e) no puede en el horario propuesto",
    en: "Reader can't make the proposed time",
    it: "Il/la lettore/trice non può all'orario proposto",
    de: "Leser*in kann zum vorgeschlagenen Zeitpunkt nicht",
    ca: "Le lector-a-e no pot a l'horari proposat",
    eo: "La legant-in-o ne povas je la proponita horo",
    nl: "De lezer kan niet op het voorgestelde moment",
    el: "Ο/Η αναγνώστης/στρια δεν μπορεί τον προτεινόμενο χρόνο"
  },

  // ===== Admin subjects (admin.*) ===========================================
  "admin.newLoan": {
    "pt-BR": "Novo empréstimo registrado",
    fr: "Nouvel emprunt enregistré",
    es: "Nuevo préstamo registrado",
    en: "New loan registered",
    it: "Nuovo prestito registrato",
    de: "Neue Ausleihe registriert",
    ca: "Nou préstec registrat",
    eo: "Nova prunto registrita",
    nl: "Nieuwe uitlening geregistreerd",
    el: "Καταχωρίστηκε νέος δανεισμός"
  },
  "admin.renewalDone": {
    "pt-BR": "Prorrogação registrada",
    fr: "Prolongation enregistrée",
    es: "Renovación registrada",
    en: "Renewal recorded",
    it: "Rinnovo registrato",
    de: "Verlängerung registriert",
    ca: "Renovació registrada",
    eo: "Renovigo registrita",
    nl: "Verlenging geregistreerd",
    el: "Καταγράφηκε ανανέωση"
  },
  "admin.returnDone": {
    "pt-BR": "Devolução registrada",
    fr: "Retour enregistré",
    es: "Devolución registrada",
    en: "Return recorded",
    it: "Restituzione registrata",
    de: "Rückgabe registriert",
    ca: "Retorn registrat",
    eo: "Redono registrita",
    nl: "Inlevering geregistreerd",
    el: "Καταγράφηκε επιστροφή"
  },
  "admin.partialReturnDone": {
    "pt-BR": "Devolução parcial registrada",
    fr: "Retour partiel enregistré",
    es: "Devolución parcial registrada",
    en: "Partial return recorded",
    it: "Restituzione parziale registrata",
    de: "Teilrückgabe registriert",
    ca: "Retorn parcial registrat",
    eo: "Parta redono registrita",
    nl: "Gedeeltelijke inlevering geregistreerd",
    el: "Καταγράφηκε μερική επιστροφή"
  },
  "admin.fullyReturnedAfterPartialDone": {
    "pt-BR": "Empréstimo concluído (após devolução parcial)",
    fr: "Emprunt clôturé (après retour partiel)",
    es: "Préstamo concluido (tras devolución parcial)",
    en: "Loan completed (after partial return)",
    it: "Prestito concluso (dopo restituzione parziale)",
    de: "Ausleihe abgeschlossen (nach Teilrückgabe)",
    ca: "Préstec finalitzat (després de retorn parcial)",
    eo: "Prunto finita (post parta redono)",
    nl: "Uitlening afgesloten (na gedeeltelijke inlevering)",
    el: "Ο δανεισμός ολοκληρώθηκε (μετά από μερική επιστροφή)"
  },
  "admin.returnUpdate": {
    "pt-BR": "Atualização sobre devolução",
    fr: "Mise à jour sur un retour",
    es: "Actualización sobre devolución",
    en: "Return update",
    it: "Aggiornamento su una restituzione",
    de: "Aktualisierung zu einer Rückgabe",
    ca: "Actualització sobre un retorn",
    eo: "Ĝisdatigo pri redono",
    nl: "Update over een inlevering",
    el: "Ενημέρωση για μια επιστροφή"
  },
  "admin.loanUpdate": {
    "pt-BR": "Atualização d(o/a/e) empréstimo",
    fr: "Mise à jour de l'emprunt",
    es: "Actualización del préstamo",
    en: "Loan update",
    it: "Aggiornamento del prestito",
    de: "Aktualisierung der Ausleihe",
    ca: "Actualització del préstec",
    eo: "Ĝisdatigo de la prunto",
    nl: "Update van de uitlening",
    el: "Ενημέρωση δανεισμού"
  },
  "admin.resUpdate": {
    "pt-BR": "Atualização da reserva",
    fr: "Mise à jour de la réservation",
    es: "Actualización de la reserva",
    en: "Reservation update",
    it: "Aggiornamento della prenotazione",
    de: "Aktualisierung der Vormerkung",
    ca: "Actualització de la reserva",
    eo: "Ĝisdatigo de la rezervo",
    nl: "Update van de reservering",
    el: "Ενημέρωση κράτησης"
  },
  "admin.profileNotice": {
    "pt-BR": "Aviso sobre cadastro",
    fr: "Avis sur un compte",
    es: "Aviso sobre cuenta",
    en: "Account notice",
    it: "Avviso su un account",
    de: "Mitteilung zu einem Konto",
    ca: "Avís sobre un compte",
    eo: "Avizo pri konto",
    nl: "Bericht over een account",
    el: "Ειδοποίηση για έναν λογαριασμό"
  },

  // ===== Task statuses (ts.*) — usage Painel internal tasks =================
  "ts.aberta": {
    "pt-BR": "Aberta",
    fr: "Ouverte",
    es: "Abierta",
    en: "Open",
    it: "Aperta",
    de: "Offen",
    ca: "Oberta",
    eo: "Malferma",
    nl: "Open",
    el: "Ανοιχτή"
  },
  "ts.a_fazer": {
    "pt-BR": "A fazer",
    fr: "À faire",
    es: "Por hacer",
    en: "To do",
    it: "Da fare",
    de: "Zu erledigen",
    ca: "Per fer",
    eo: "Farenda",
    nl: "Te doen",
    el: "Προς εκτέλεση"
  },
  "ts.em_andamento": {
    "pt-BR": "Em andamento",
    fr: "En cours",
    es: "En progreso",
    en: "In progress",
    it: "In corso",
    de: "In Bearbeitung",
    ca: "En curs",
    eo: "En kurso",
    nl: "In uitvoering",
    el: "Σε εξέλιξη"
  },
  "ts.concluida": {
    "pt-BR": "Concluída",
    fr: "Terminée",
    es: "Completada",
    en: "Completed",
    it: "Completata",
    de: "Abgeschlossen",
    ca: "Completada",
    eo: "Finita",
    nl: "Voltooid",
    el: "Ολοκληρωμένη"
  },
  "ts.cancelada": {
    "pt-BR": "Cancelada",
    fr: "Annulée",
    es: "Cancelada",
    en: "Cancelled",
    it: "Annullata",
    de: "Storniert",
    ca: "Cancel·lada",
    eo: "Nuligita",
    nl: "Geannuleerd",
    el: "Ακυρωμένη"
  },

  // ===== Task priorities (tp.*) =============================================
  "tp.alta": {
    "pt-BR": "Alta",
    fr: "Haute",
    es: "Alta",
    en: "High",
    it: "Alta",
    de: "Hoch",
    ca: "Alta",
    eo: "Alta",
    nl: "Hoog",
    el: "Υψηλή"
  },
  "tp.media": {
    "pt-BR": "Média",
    fr: "Moyenne",
    es: "Media",
    en: "Medium",
    it: "Media",
    de: "Mittel",
    ca: "Mitjana",
    eo: "Meza",
    nl: "Gemiddeld",
    el: "Μεσαία"
  },
  "tp.baixa": {
    "pt-BR": "Baixa",
    fr: "Basse",
    es: "Baja",
    en: "Low",
    it: "Bassa",
    de: "Niedrig",
    ca: "Baixa",
    eo: "Malalta",
    nl: "Laag",
    el: "Χαμηλή"
  },
  "tp.urgente": {
    "pt-BR": "Urgente",
    fr: "Urgente",
    es: "Urgente",
    en: "Urgent",
    it: "Urgente",
    de: "Dringend",
    ca: "Urgent",
    eo: "Urĝa",
    nl: "Urgent",
    el: "Επείγουσα"
  },

  // ===== Team — Rôles dynamiques (team.role.*) ==============================
  "team.role.librarian": {
    "pt-BR": "bibliotecári(o/a/e)",
    fr: "bibliothécaire",
    es: "bibliotecarie",
    en: "librarian",
    it: "bibliotecari*",
    de: "Bibliothekar*in",
    ca: "bibliotecari-ària-e",
    eo: "bibliotekist-in-o",
    nl: "bibliothecaris",
    el: "βιβλιοθηκάριος"
  },
  "team.role.coordenador": {
    "pt-BR": "coordenador(o/a/e)",
    fr: "coordinateur·rice",
    es: "coordinadore",
    en: "coordinator",
    it: "coordinatore/trice",
    de: "Koordinator*in",
    ca: "coordinador-a-e",
    eo: "kunordigant-in-o",
    nl: "coördinator",
    el: "συντονιστής/στρια"
  },

  // ===== Team — Admissions concertées (team.promoted_*) =====================
  "team.promoted_to_librarian.sub": {
    "pt-BR": "Você foi admitid(o/a/e) bibliotecári(o/a/e)",
    fr: "Tu as été admis·e bibliothécaire",
    es: "Fuiste admitide bibliotecarie",
    en: "You have been admitted as a librarian",
    it: "Sei stat* ammess* come bibliotecari*",
    de: "Du wurdest als Bibliothekar*in aufgenommen",
    ca: "Has estat admès-a-e com a bibliotecari-ària-e",
    eo: "Vi estis akceptita kiel bibliotekist-in-o",
    nl: "Je bent toegelaten als bibliothecaris",
    el: "Έγινες δεκτός/ή ως βιβλιοθηκάριος"
  },
  "team.promoted_to_librarian.intro": {
    "pt-BR": "Você acaba de ser admitid(o/a/e) bibliotecári(o/a/e) na {libraryName} de maneira concertada pela equipe de animação da biblioteca. Seja bem-vind(o/a/e)!",
    fr: "Tu viens d'être admis·e bibliothécaire à la {libraryName} de manière concertée par l'équipe d'animation de la bibliothèque. Bienvenue !",
    es: "Acabás de ser admitide bibliotecarie en le {libraryName} de manera concertada por le equipo de animación de la biblioteca. ¡Bienvenide!",
    en: "You have just been admitted as a librarian at {libraryName} through a concerted decision by the library's animation team. Welcome!",
    it: "Sei appena stat* ammess* come bibliotecari* a {libraryName} in modo concertato dall'equipe di animazione della biblioteca. Benvenut*!",
    de: "Du bist soeben als Bibliothekar*in bei {libraryName} in Abstimmung mit dem Animationsteam der Bibliothek aufgenommen worden. Willkommen!",
    ca: "Acabes de ser admès-a-e com a bibliotecari-ària-e a le {libraryName} de manera concertada per l'equip d'animació de la biblioteca. Benvingut-da-e!",
    eo: "Vi ĵus estis akceptita kiel bibliotekist-in-o ĉe {libraryName} interkonsente fare de la animteamo de la biblioteko. Bonvenon!",
    nl: "Je bent zojuist toegelaten als bibliothecaris bij {libraryName} via een gezamenlijk besluit van het animatieteam van de bibliotheek. Welkom!",
    el: "Μόλις έγινες δεκτός/ή ως βιβλιοθηκάριος στη {libraryName} με συναινετική απόφαση της ομάδας εμψύχωσης της βιβλιοθήκης. Καλώς όρισες!"
  },
  "team.promoted_to_coordenador.sub": {
    "pt-BR": "Você foi admitid(o/a/e) coordenador(o/a/e)",
    fr: "Tu as été admis·e coordinateur·rice",
    es: "Fuiste admitide coordinadore",
    en: "You have been admitted as a coordinator",
    it: "Sei stat* ammess* come coordinatore/trice",
    de: "Du wurdest als Koordinator*in aufgenommen",
    ca: "Has estat admès-a-e com a coordinador-a-e",
    eo: "Vi estis akceptita kiel kunordigant-in-o",
    nl: "Je bent toegelaten als coördinator",
    el: "Έγινες δεκτός/ή ως συντονιστής/στρια"
  },
  "team.promoted_to_coordenador.intro": {
    "pt-BR": "Você acaba de ser admitid(o/a/e) coordenador(o/a/e) na {libraryName} de maneira concertada. Você junta-se ao círculo de coordenação. Suas responsabilidades se ampliam: governança da equipe, validações sensíveis. O regimento interno está aqui: {regimentoUrl}",
    fr: "Tu viens d'être admis·e coordinateur·rice à la {libraryName} de manière concertée. Tu rejoins le cercle de coordination. Tes responsabilités s'élargissent : gouvernance de l'équipe, validations sensibles. Le règlement intérieur est ici : {regimentoUrl}",
    es: "Acabás de ser admitide coordinadore en le {libraryName} de manera concertada. Te sumás al círculo de coordinación. Tus responsabilidades se amplían: gobernanza de le equipo, validaciones sensibles. El reglamento interno está acá: {regimentoUrl}",
    en: "You have just been admitted as a coordinator at {libraryName} through a concerted decision. You join the coordination circle. Your responsibilities expand: team governance, sensitive validations. The internal rules are here: {regimentoUrl}",
    it: "Sei appena stat* ammess* come coordinatore/trice a {libraryName} in modo concertato. Entri nel cerchio di coordinamento. Le tue responsabilità si ampliano: governance dell'equipe, validazioni sensibili. Il regolamento interno è qui: {regimentoUrl}",
    de: "Du bist soeben als Koordinator*in bei {libraryName} in Abstimmung aufgenommen worden. Du trittst dem Koordinationskreis bei. Deine Verantwortungen erweitern sich: Governance des Teams, sensible Validierungen. Die interne Geschäftsordnung findest du hier: {regimentoUrl}",
    ca: "Acabes de ser admès-a-e com a coordinador-a-e a le {libraryName} de manera concertada. T'incorpores al cercle de coordinació. Les teves responsabilitats s'amplien: governança de l'equip, validacions sensibles. El reglament intern és aquí: {regimentoUrl}",
    eo: "Vi ĵus estis akceptita kiel kunordigant-in-o ĉe {libraryName} interkonsente. Vi aliĝas al la kunordiga rondo. Viaj respondecoj plivastiĝas: memmastrumado de la teamo, sentemaj validigoj. La interna regularo estas ĉi tie: {regimentoUrl}",
    nl: "Je bent zojuist toegelaten als coördinator bij {libraryName} via een gezamenlijk besluit. Je treedt toe tot de coördinatiekring. Je verantwoordelijkheden worden groter: teambestuur, gevoelige validaties. Het huishoudelijk reglement vind je hier: {regimentoUrl}",
    el: "Μόλις έγινες δεκτός/ή ως συντονιστής/στρια στη {libraryName} με συναινετική απόφαση. Εντάσσεσαι στον κύκλο συντονισμού. Οι ευθύνες σου διευρύνονται: διακυβέρνηση της ομάδας, ευαίσθητες επικυρώσεις. Ο εσωτερικός κανονισμός είναι εδώ: {regimentoUrl}"
  },

  // ===== Team — Retour volontaire à un autre rôle (team.self_demoted) =======
  "team.self_demoted.sub": {
    "pt-BR": "{actorName} retornou ao papel de {toRole}",
    fr: "{actorName} est revenu·e au rôle de {toRole}",
    es: "{actorName} volvió al rol de {toRole}",
    en: "{actorName} has returned to the {toRole} role",
    it: "{actorName} è tornat* al ruolo di {toRole}",
    de: "{actorName} ist zur Rolle {toRole} zurückgekehrt",
    ca: "{actorName} ha tornat al rol de {toRole}",
    eo: "{actorName} revenis al la rolo de {toRole}",
    nl: "{actorName} is teruggekeerd naar de rol van {toRole}",
    el: "Ο/Η {actorName} επέστρεψε στον ρόλο {toRole}"
  },
  "team.self_demoted.intro": {
    "pt-BR": "{actorName} retornou do papel de {fromRole} ao papel de {toRole} na {libraryName}. Esta decisão é voluntária e imediata.",
    fr: "{actorName} est revenu·e du rôle de {fromRole} au rôle de {toRole} à la {libraryName}. Cette décision est volontaire et immédiate.",
    es: "{actorName} volvió de le rol de {fromRole} al rol de {toRole} en le {libraryName}. Esta decisión es voluntaria e inmediata.",
    en: "{actorName} has returned from the {fromRole} role to the {toRole} role at {libraryName}. This decision is voluntary and effective immediately.",
    it: "{actorName} è tornat* dal ruolo di {fromRole} al ruolo di {toRole} a {libraryName}. Questa decisione è volontaria e immediata.",
    de: "{actorName} ist von der Rolle {fromRole} zur Rolle {toRole} bei {libraryName} zurückgekehrt. Diese Entscheidung ist freiwillig und sofort wirksam.",
    ca: "{actorName} ha tornat del rol de {fromRole} al rol de {toRole} a le {libraryName}. Aquesta decisió és voluntària i immediata.",
    eo: "{actorName} revenis de la rolo de {fromRole} al la rolo de {toRole} ĉe {libraryName}. Ĉi tiu decido estas volonta kaj tuja.",
    nl: "{actorName} is teruggekeerd van de rol van {fromRole} naar de rol van {toRole} bij {libraryName}. Dit besluit is vrijwillig en gaat onmiddellijk in.",
    el: "Ο/Η {actorName} επέστρεψε από τον ρόλο {fromRole} στον ρόλο {toRole} στη {libraryName}. Αυτή η απόφαση είναι εθελοντική και άμεση."
  },

  // ===== Team — Demande de retrait avec carence 7j (team.removal_*) =========
  "team.removal_requested.sub": {
    "pt-BR": "Pedido de retirada concernente a você",
    fr: "Demande de retrait te concernant",
    es: "Solicitud de retiro que te concierne",
    en: "Removal request concerning you",
    it: "Richiesta di rimozione che ti riguarda",
    de: "Antrag auf Entzug, der dich betrifft",
    ca: "Sol·licitud de retirada que et concerneix",
    eo: "Forigpeto koncernanta vin",
    nl: "Verzoek tot verwijdering dat jou betreft",
    el: "Αίτημα απομάκρυνσης που σε αφορά"
  },
  "team.removal_requested.intro": {
    "pt-BR": "Um pedido de retirada do papel de {role} concernente a você foi depositado na {libraryName}. Este pedido está submetido a um prazo de 7 dias durante o qual você pode trocar com outr(o/a/e)s coordenador(o/a/e)s para compreender ou contestar esta decisão. Sem anulação da parte del(e/a/e)s antes de {pendingUntilDate}, seu papel de {role} será retirado.",
    fr: "Une demande de retrait du rôle de {role} te concernant a été déposée à la {libraryName}. Cette demande est soumise à un délai de 7 jours pendant lequel tu peux échanger avec les autres coordinateur·rices pour comprendre ou contester cette décision. Sans annulation de leur part avant le {pendingUntilDate}, ton rôle de {role} sera retiré.",
    es: "Une solicitud de retiro de le rol de {role} que te concierne fue depositada en le {libraryName}. Esta solicitud está sometida a un plazo de 7 días durante el cual podés intercambiar con les otres coordinadores para comprender o contestar esta decisión. Sin anulación de su parte antes de le {pendingUntilDate}, tu rol de {role} será retirado.",
    en: "A request to remove your {role} role at {libraryName} has been filed. This request is subject to a 7-day waiting period during which you may discuss with the other coordinators to understand or contest this decision. Without cancellation on their part before {pendingUntilDate}, your {role} role will be removed.",
    it: "Una richiesta di rimozione dal ruolo di {role} che ti riguarda è stata depositata a {libraryName}. Questa richiesta è soggetta a un termine di 7 giorni durante il quale puoi confrontarti con le altre coordinatrici e gli altri coordinatori per comprendere o contestare questa decisione. Senza annullamento da parte loro entro il {pendingUntilDate}, il tuo ruolo di {role} sarà rimosso.",
    de: "Ein Antrag auf Entzug der Rolle {role}, der dich betrifft, wurde bei {libraryName} eingereicht. Dieser Antrag unterliegt einer Frist von 7 Tagen, während der du dich mit den anderen Koordinator*innen austauschen kannst, um diese Entscheidung zu verstehen oder anzufechten. Ohne Annullierung ihrerseits vor dem {pendingUntilDate} wird deine Rolle als {role} entzogen.",
    ca: "S'ha presentat una sol·licitud de retirada del rol de {role} que et concerneix a le {libraryName}. Aquesta sol·licitud està sotmesa a un termini de 7 dies durant el qual pots intercanviar amb les altres coordinadores per comprendre o impugnar aquesta decisió. Sense anul·lació per part seva abans del {pendingUntilDate}, el teu rol de {role} serà retirat.",
    eo: "Forigpeto pri la rolo de {role} koncernanta vin estis deponita ĉe {libraryName}. Ĉi tiu peto estas submetita al limdato de 7 tagoj dum kiu vi povas interŝanĝi kun la aliaj kunordigant-in-oj por kompreni aŭ kontesti ĉi tiun decidon. Sen nuligo flanke de ili antaŭ la {pendingUntilDate}, via rolo de {role} estos forigita.",
    nl: "Er is een verzoek ingediend om je rol van {role} bij {libraryName} te verwijderen. Voor dit verzoek geldt een wachttijd van 7 dagen waarin je met de andere coördinatoren kunt overleggen om dit besluit te begrijpen of aan te vechten. Zonder annulering van hun kant vóór {pendingUntilDate} wordt je rol van {role} verwijderd.",
    el: "Κατατέθηκε αίτημα απομάκρυνσης του ρόλου σου {role} στη {libraryName}. Αυτό το αίτημα υπόκειται σε περίοδο αναμονής 7 ημερών, στη διάρκεια της οποίας μπορείς να συζητήσεις με τους/τις άλλους/ες συντονιστές/στριες για να κατανοήσεις ή να αμφισβητήσεις αυτή την απόφαση. Χωρίς ακύρωση από μέρους τους πριν τις {pendingUntilDate}, ο ρόλος σου {role} θα αφαιρεθεί."
  },
  "team.removal_cancelled.sub": {
    "pt-BR": "O pedido de retirada concernente a você foi anulado",
    fr: "La demande de retrait te concernant a été annulée",
    es: "La solicitud de retiro que te concierne fue anulada",
    en: "The removal request concerning you has been cancelled",
    it: "La richiesta di rimozione che ti riguarda è stata annullata",
    de: "Der Antrag auf Entzug, der dich betraf, wurde annulliert",
    ca: "La sol·licitud de retirada que et concerneix s'ha anul·lat",
    eo: "La forigpeto koncernanta vin estis nuligita",
    nl: "Het verzoek tot verwijdering dat jou betreft is geannuleerd",
    el: "Το αίτημα απομάκρυνσης που σε αφορά ακυρώθηκε"
  },
  "team.removal_cancelled.intro": {
    "pt-BR": "O pedido de retirada concernente a você na {libraryName} foi anulado por {cancellerName}. Você recupera todos os seus direitos de {role} imediatamente.",
    fr: "La demande de retrait te concernant à la {libraryName} a été annulée par {cancellerName}. Tu retrouves tous tes droits de {role} immédiatement.",
    es: "La solicitud de retiro que te concierne en le {libraryName} fue anulada por {cancellerName}. Recuperás todos tus derechos de {role} inmediatamente.",
    en: "The removal request concerning you at {libraryName} has been cancelled by {cancellerName}. You immediately regain all your {role} rights.",
    it: "La richiesta di rimozione che ti riguarda a {libraryName} è stata annullata da {cancellerName}. Recuperi immediatamente tutti i tuoi diritti di {role}.",
    de: "Der Antrag auf Entzug, der dich bei {libraryName} betraf, wurde von {cancellerName} annulliert. Du erhältst sofort alle deine Rechte als {role} zurück.",
    ca: "La sol·licitud de retirada que et concerneix a le {libraryName} ha estat anul·lada per {cancellerName}. Recuperes immediatament tots els teus drets de {role}.",
    eo: "La forigpeto koncernanta vin ĉe {libraryName} estis nuligita de {cancellerName}. Vi tuj reakiras ĉiujn viajn rajtojn de {role}.",
    nl: "Het verzoek tot verwijdering dat jou betreft bij {libraryName} is geannuleerd door {cancellerName}. Je krijgt al je {role}-rechten onmiddellijk terug.",
    el: "Το αίτημα απομάκρυνσης που σε αφορά στη {libraryName} ακυρώθηκε από {cancellerName}. Ανακτάς αμέσως όλα τα δικαιώματά σου ως {role}."
  },
  "team.removal_completed.sub": {
    "pt-BR": "Sua retirada do papel de {role} foi finalizada",
    fr: "Ton retrait du rôle de {role} a été finalisé",
    es: "Tu retiro de le rol de {role} fue finalizado",
    en: "Your removal from the {role} role has been finalised",
    it: "La tua rimozione dal ruolo di {role} è stata finalizzata",
    de: "Dein Entzug der Rolle {role} wurde abgeschlossen",
    ca: "La teva retirada del rol de {role} s'ha finalitzat",
    eo: "Via forigo el la rolo de {role} estis finita",
    nl: "Je verwijdering uit de rol van {role} is afgerond",
    el: "Η απομάκρυνσή σου από τον ρόλο {role} οριστικοποιήθηκε"
  },
  "team.removal_completed.intro": {
    "pt-BR": "O prazo de 7 dias decorreu sem anulação. Seu papel de {role} na {libraryName} foi retirado. Se você deseja compreender esta decisão ou discuti-la, entre em contato com (o/a/e)s coordenador(o/a/e)s.",
    fr: "Le délai de 7 jours s'est écoulé sans annulation. Ton rôle de {role} à la {libraryName} a été retiré. Si tu souhaites comprendre cette décision ou en discuter, contacte les coordinateur·rices.",
    es: "El plazo de 7 días transcurrió sin anulación. Tu rol de {role} en le {libraryName} fue retirado. Si querés comprender esta decisión o discutirla, contactá a les coordinadores.",
    en: "The 7-day period has elapsed without cancellation. Your {role} role at {libraryName} has been removed. If you wish to understand this decision or discuss it, contact the coordinators.",
    it: "Il termine di 7 giorni è trascorso senza annullamento. Il tuo ruolo di {role} a {libraryName} è stato rimosso. Se desideri comprendere questa decisione o discuterne, contatta le coordinatrici e i coordinatori.",
    de: "Die Frist von 7 Tagen ist ohne Annullierung verstrichen. Deine Rolle als {role} bei {libraryName} wurde entzogen. Wenn du diese Entscheidung verstehen oder besprechen möchtest, wende dich an die Koordinator*innen.",
    ca: "El termini de 7 dies ha transcorregut sense anul·lació. El teu rol de {role} a le {libraryName} ha estat retirat. Si vols comprendre aquesta decisió o discutir-la, contacta les coordinadores.",
    eo: "La limdato de 7 tagoj forpasis sen nuligo. Via rolo de {role} ĉe {libraryName} estis forigita. Se vi deziras kompreni ĉi tiun decidon aŭ priparoli ĝin, kontaktu la kunordigant-in-ojn.",
    nl: "De termijn van 7 dagen is verstreken zonder annulering. Je rol van {role} bij {libraryName} is verwijderd. Als je dit besluit wilt begrijpen of erover wilt praten, neem dan contact op met de coördinatoren.",
    el: "Η περίοδος των 7 ημερών παρήλθε χωρίς ακύρωση. Ο ρόλος σου {role} στη {libraryName} αφαιρέθηκε. Αν θέλεις να κατανοήσεις αυτή την απόφαση ή να τη συζητήσεις, επικοινώνησε με τους/τις συντονιστές/στριες."
  },

  // ===== Team — Suspension immédiate (team.suspended_*) =====================
  "team.suspended.sub": {
    "pt-BR": "Suspensão imediata dos seus direitos de {role}",
    fr: "Suspension immédiate de tes droits de {role}",
    es: "Suspensión inmediata de tus derechos de {role}",
    en: "Immediate suspension of your {role} rights",
    it: "Sospensione immediata dei tuoi diritti di {role}",
    de: "Sofortige Aussetzung deiner {role}-Rechte",
    ca: "Suspensió immediata dels teus drets de {role}",
    eo: "Tuja suspendo de viaj rajtoj de {role}",
    nl: "Onmiddellijke schorsing van je {role}-rechten",
    el: "Άμεση αναστολή των δικαιωμάτων σου ως {role}"
  },
  "team.suspended.intro": {
    "pt-BR": "Seus direitos de {role} na {libraryName} foram suspensos por medida cautelar. Motivo comunicado: {reason}. Para compreender ou contestar esta decisão, entre em contato com (o/a/e)s coordenador(o/a/e)s o mais rápido possível.",
    fr: "Tes droits de {role} à la {libraryName} ont été suspendus par mesure conservatoire. Motif communiqué : {reason}. Pour comprendre ou contester cette décision, contacte les coordinateur·rices au plus vite.",
    es: "Tus derechos de {role} en le {libraryName} fueron suspendidos por medida cautelar. Motivo comunicado: {reason}. Para comprender o contestar esta decisión, contactá a les coordinadores lo antes posible.",
    en: "Your {role} rights at {libraryName} have been suspended as a precautionary measure. Communicated reason: {reason}. To understand or contest this decision, contact the coordinators as soon as possible.",
    it: "I tuoi diritti di {role} a {libraryName} sono stati sospesi come misura cautelare. Motivo comunicato: {reason}. Per comprendere o contestare questa decisione, contatta le coordinatrici e i coordinatori il prima possibile.",
    de: "Deine {role}-Rechte bei {libraryName} wurden als vorsorgliche Maßnahme ausgesetzt. Mitgeteilter Grund: {reason}. Um diese Entscheidung zu verstehen oder anzufechten, wende dich so schnell wie möglich an die Koordinator*innen.",
    ca: "Els teus drets de {role} a le {libraryName} han estat suspesos per mesura cautelar. Motiu comunicat: {reason}. Per comprendre o impugnar aquesta decisió, contacta les coordinadores com més aviat millor.",
    eo: "Viaj rajtoj de {role} ĉe {libraryName} estis suspenditaj kiel antaŭgarda mezuro. Komunikita motivo: {reason}. Por kompreni aŭ kontesti ĉi tiun decidon, kontaktu la kunordigant-in-ojn kiel eble plej baldaŭ.",
    nl: "Je {role}-rechten bij {libraryName} zijn als voorzorgsmaatregel geschorst. Meegedeelde reden: {reason}. Om dit besluit te begrijpen of aan te vechten, neem zo snel mogelijk contact op met de coördinatoren.",
    el: "Τα δικαιώματά σου ως {role} στη {libraryName} ανεστάλησαν ως προληπτικό μέτρο. Λόγος που γνωστοποιήθηκε: {reason}. Για να κατανοήσεις ή να αμφισβητήσεις αυτή την απόφαση, επικοινώνησε με τους/τις συντονιστές/στριες το συντομότερο."
  },
  "team.unsuspended.sub": {
    "pt-BR": "Levantamento da sua suspensão",
    fr: "Levée de ta suspension",
    es: "Levantamiento de tu suspensión",
    en: "Lifting of your suspension",
    it: "Revoca della tua sospensione",
    de: "Aufhebung deiner Aussetzung",
    ca: "Aixecament de la teva suspensió",
    eo: "Levo de via suspendo",
    nl: "Opheffing van je schorsing",
    el: "Άρση της αναστολής σου"
  },
  "team.unsuspended.intro": {
    "pt-BR": "A suspensão dos seus direitos de {role} na {libraryName} foi levantada por {actorName}. Você recupera imediatamente seus acessos.",
    fr: "La suspension de tes droits de {role} à la {libraryName} a été levée par {actorName}. Tu retrouves immédiatement tes accès.",
    es: "La suspensión de tus derechos de {role} en le {libraryName} fue levantada por {actorName}. Recuperás inmediatamente tus accesos.",
    en: "The suspension of your {role} rights at {libraryName} has been lifted by {actorName}. You immediately regain your access.",
    it: "La sospensione dei tuoi diritti di {role} a {libraryName} è stata revocata da {actorName}. Recuperi immediatamente i tuoi accessi.",
    de: "Die Aussetzung deiner {role}-Rechte bei {libraryName} wurde von {actorName} aufgehoben. Du erhältst sofort deinen Zugang zurück.",
    ca: "La suspensió dels teus drets de {role} a le {libraryName} ha estat aixecada per {actorName}. Recuperes immediatament els teus accessos.",
    eo: "La suspendo de viaj rajtoj de {role} ĉe {libraryName} estis levita de {actorName}. Vi tuj reakiras viajn alirojn.",
    nl: "De schorsing van je {role}-rechten bij {libraryName} is opgeheven door {actorName}. Je krijgt onmiddellijk weer toegang.",
    el: "Η αναστολή των δικαιωμάτων σου ως {role} στη {libraryName} ήρθη από {actorName}. Ανακτάς αμέσως την πρόσβασή σου."
  },

  // ===== Team — Escalades aux administrateur·rices AnarBib (team.last_*) ====
  "team.last_coordinator_left.sub": {
    "pt-BR": "{libraryName} não tem mais coordenador(o/a/e)",
    fr: "{libraryName} n'a plus de coordinateur·rice",
    es: "{libraryName} ya no tiene coordinadore",
    en: "{libraryName} no longer has a coordinator",
    it: "{libraryName} non ha più coordinatori/trici",
    de: "{libraryName} hat keine Koordinator*in mehr",
    ca: "{libraryName} ja no té coordinador-a-e",
    eo: "{libraryName} ne plu havas kunordigant-in-on",
    nl: "{libraryName} heeft geen coördinator meer",
    el: "Η {libraryName} δεν έχει πλέον συντονιστή/στρια"
  },
  "team.last_coordinator_left.intro": {
    "pt-BR": "A biblioteca {libraryName} encontra-se sem coordenador(o/a/e) ativ(o/a/e). {actorName} acaba de retornar a um papel não-coordenador, e ninguém mais ocupa o papel. A biblioteca permanece funcional tecnicamente (os bibliotecári(o/a/e)s podem continuar a operar) mas não tem mais instância de coordenação interna. Uma intervenção política da rede AnarBib é provavelmente necessária.",
    fr: "La bibliothèque {libraryName} se retrouve sans coordinateur·rice actif·ve. {actorName} vient de revenir à un rôle non-coordinateur, et personne d'autre n'occupe le rôle. La bibliothèque reste fonctionnelle techniquement (les bibliothécaires peuvent toujours opérer) mais n'a plus d'instance de coordination interne. Une intervention politique du réseau AnarBib est probablement nécessaire.",
    es: "La biblioteca {libraryName} se encuentra sin coordinadore active. {actorName} acaba de volver a un rol no-coordinadore, y nadie más ocupa el rol. La biblioteca permanece funcional técnicamente (les bibliotecaries pueden seguir operando) pero ya no tiene instancia de coordinación interna. Una intervención política de le red AnarBib es probablemente necesaria.",
    en: "The {libraryName} library finds itself without an active coordinator. {actorName} has just returned to a non-coordinator role, and no one else holds the position. The library remains technically functional (librarians can still operate) but no longer has an internal coordination body. A political intervention from the AnarBib network is likely necessary.",
    it: "La biblioteca {libraryName} si ritrova senza coordinatori/trici attiv*. {actorName} è appena tornat* a un ruolo non-coordinatore, e nessun'altra persona occupa il ruolo. La biblioteca rimane funzionale tecnicamente (le bibliotecarie e i bibliotecari possono continuare a operare) ma non ha più un'istanza di coordinamento interna. Un intervento politico della rete AnarBib è probabilmente necessario.",
    de: "Die Bibliothek {libraryName} steht ohne aktive Koordinator*in da. {actorName} ist soeben zu einer Nicht-Koordinator*innen-Rolle zurückgekehrt, und niemand sonst nimmt die Rolle wahr. Die Bibliothek bleibt technisch funktionsfähig (die Bibliothekar*innen können weiter arbeiten), hat aber keine interne Koordinationsinstanz mehr. Eine politische Intervention des AnarBib-Netzwerks ist wahrscheinlich notwendig.",
    ca: "La biblioteca {libraryName} es troba sense coordinador-a-e actiu-iva-e. {actorName} acaba de tornar a un rol no coordinador, i ningú més ocupa el rol. La biblioteca segueix sent funcional tècnicament (les bibliotecàries poden continuar operant) però ja no té instància de coordinació interna. Probablement cal una intervenció política de la xarxa AnarBib.",
    eo: "La biblioteko {libraryName} troviĝas sen aktiva kunordigant-in-o. {actorName} ĵus revenis al ne-kunordiga rolo, kaj neniu alia okupas la rolon. La biblioteko restas teknike funkcia (la bibliotekist-in-oj povas plu funkcii) sed ne plu havas internan kunordigan instancon. Politika interveno de la reto AnarBib estas verŝajne necesa.",
    nl: "Bibliotheek {libraryName} bevindt zich zonder actieve coördinator. {actorName} is zojuist teruggekeerd naar een niet-coördinerende rol, en niemand anders bekleedt die rol. De bibliotheek blijft technisch functioneel (bibliothecarissen kunnen nog werken), maar heeft geen intern coördinatieorgaan meer. Een politieke interventie van het AnarBib-netwerk is waarschijnlijk nodig.",
    el: "Η βιβλιοθήκη {libraryName} βρίσκεται χωρίς ενεργό/ή συντονιστή/στρια. Ο/Η {actorName} μόλις επέστρεψε σε ρόλο μη συντονιστή/στριας, και κανείς άλλος δεν κατέχει τον ρόλο. Η βιβλιοθήκη παραμένει τεχνικά λειτουργική (οι βιβλιοθηκάριοι μπορούν ακόμη να λειτουργούν) αλλά δεν έχει πλέον εσωτερικό όργανο συντονισμού. Πιθανότατα απαιτείται πολιτική παρέμβαση του δικτύου AnarBib."
  },
  "team.last_coordinator_pending_removal.sub": {
    "pt-BR": "{libraryName} corre risco de ficar sem coordenador(o/a/e)",
    fr: "{libraryName} risque de se retrouver sans coordinateur·rice",
    es: "{libraryName} corre el riesgo de quedarse sin coordinadore",
    en: "{libraryName} risks finding itself without a coordinator",
    it: "{libraryName} rischia di ritrovarsi senza coordinatori/trici",
    de: "{libraryName} läuft Gefahr, ohne Koordinator*in dazustehen",
    ca: "{libraryName} corre el risc de quedar-se sense coordinador-a-e",
    eo: "{libraryName} riskas resti sen kunordigant-in-o",
    nl: "{libraryName} dreigt zonder coördinator te komen",
    el: "Η {libraryName} κινδυνεύει να μείνει χωρίς συντονιστή/στρια"
  },
  "team.last_coordinator_pending_removal.intro": {
    "pt-BR": "A biblioteca {libraryName} não terá mais coordenador(o/a/e) ativ(o/a/e) a partir de {pendingUntilDate} se o pedido de retirada em curso não for anulado. {actorName} pediu a retirada d(o/a/e) últim(o/a/e) coordenador(o/a/e) ativ(o/a/e) da biblioteca. Você pode observar a situação, ou intervir politicamente se necessário.",
    fr: "La bibliothèque {libraryName} aura plus de coordinateur·rice actif·ve à partir du {pendingUntilDate} si la demande de retrait en cours n'est pas annulée. {actorName} a demandé le retrait de la dernière coordinateur·rice actif·ve de la bibliothèque. Tu peux observer la situation, ou intervenir politiquement si nécessaire.",
    es: "La biblioteca {libraryName} ya no tendrá coordinadore active a partir de le {pendingUntilDate} si la solicitud de retiro en curso no es anulada. {actorName} solicitó el retiro de le última coordinadore active de la biblioteca. Podés observar la situación, o intervenir políticamente si es necesario.",
    en: "The {libraryName} library will have no active coordinator from {pendingUntilDate} onwards if the pending removal request is not cancelled. {actorName} requested the removal of the last active coordinator at the library. You may observe the situation, or intervene politically if necessary.",
    it: "La biblioteca {libraryName} non avrà più coordinatori/trici attiv* a partire dal {pendingUntilDate} se la richiesta di rimozione in corso non viene annullata. {actorName} ha richiesto la rimozione dell'ultim* coordinatore/trice attiv* della biblioteca. Puoi osservare la situazione, o intervenire politicamente se necessario.",
    de: "Die Bibliothek {libraryName} wird ab dem {pendingUntilDate} keine aktive Koordinator*in mehr haben, falls der laufende Antrag auf Entzug nicht annulliert wird. {actorName} hat den Entzug der letzten aktiven Koordinator*in der Bibliothek beantragt. Du kannst die Situation beobachten oder politisch intervenieren, falls notwendig.",
    ca: "La biblioteca {libraryName} ja no tindrà coordinador-a-e actiu-iva-e a partir del {pendingUntilDate} si la sol·licitud de retirada en curs no s'anul·la. {actorName} ha sol·licitat la retirada de le darrere coordinador-a-e actiu-iva-e de la biblioteca. Pots observar la situació, o intervenir políticament si cal.",
    eo: "La biblioteko {libraryName} ne plu havos aktivan kunordigant-in-on ekde la {pendingUntilDate} se la kuranta forigpeto ne estos nuligita. {actorName} petis la forigon de la lasta aktiva kunordigant-in-o de la biblioteko. Vi povas observi la situacion, aŭ interveni politike se necese.",
    nl: "Bibliotheek {libraryName} heeft vanaf {pendingUntilDate} geen actieve coördinator meer als het lopende verzoek tot verwijdering niet wordt geannuleerd. {actorName} heeft de verwijdering van de laatste actieve coördinator van de bibliotheek aangevraagd. Je kunt de situatie volgen, of indien nodig politiek ingrijpen.",
    el: "Η βιβλιοθήκη {libraryName} δεν θα έχει ενεργό/ή συντονιστή/στρια από τις {pendingUntilDate} και μετά, αν το εκκρεμές αίτημα απομάκρυνσης δεν ακυρωθεί. Ο/Η {actorName} ζήτησε την απομάκρυνση του/της τελευταίου/ας ενεργού/ής συντονιστή/στριας της βιβλιοθήκης. Μπορείς να παρακολουθήσεις την κατάσταση ή να παρέμβεις πολιτικά αν χρειαστεί."
  },

  // ===== Team — Avertissements et passage en inactif (team.inactive_*) ======
  // École 1 stricte : "inactif" qualifie "compte" / "statut" (concepts), donc
  // accord grammatical standard, pas de marquage militant.
  "team.inactive_warning_30d.sub": {
    "pt-BR": "Sua conta vai passar a inativa em 30 dias",
    fr: "Ton compte va passer en inactif dans 30 jours",
    es: "Tu cuenta va a pasar a inactiva en 30 días",
    en: "Your account will become inactive in 30 days",
    it: "Il tuo account passerà a inattivo tra 30 giorni",
    de: "Dein Konto wird in 30 Tagen inaktiv",
    ca: "El teu compte passarà a inactiu d'aquí a 30 dies",
    eo: "Via konto iĝos neaktiva post 30 tagoj",
    nl: "Je account wordt over 30 dagen inactief",
    el: "Ο λογαριασμός σου θα γίνει ανενεργός σε 30 ημέρες"
  },
  "team.inactive_warning_30d.intro": {
    "pt-BR": "Você não se conectou em AnarBib há 8 meses. Sem conexão da sua parte nos próximos 30 dias, seu status de {role} na {libraryName} passará automaticamente a inativo. Para conservar seus acessos, conecte-se simplesmente a AnarBib antes de {deadlineDate}.",
    fr: "Tu ne t'es pas connecté·e sur AnarBib depuis 8 mois. Sans connexion de ta part dans les 30 prochains jours, ton statut de {role} à la {libraryName} passera automatiquement en inactif. Pour conserver tes accès, connecte-toi simplement à AnarBib avant le {deadlineDate}.",
    es: "No te conectaste a AnarBib desde hace 8 meses. Sin conexión de tu parte en los próximos 30 días, tu estatus de {role} en le {libraryName} pasará automáticamente a inactivo. Para conservar tus accesos, conectate simplemente a AnarBib antes de le {deadlineDate}.",
    en: "You have not signed in to AnarBib for 8 months. Without a connection on your part within the next 30 days, your {role} status at {libraryName} will automatically become inactive. To keep your access, simply log in to AnarBib before {deadlineDate}.",
    it: "Non ti sei conness* ad AnarBib da 8 mesi. Senza una connessione da parte tua nei prossimi 30 giorni, il tuo status di {role} a {libraryName} passerà automaticamente a inattivo. Per conservare i tuoi accessi, connettiti semplicemente ad AnarBib prima del {deadlineDate}.",
    de: "Du hast dich seit 8 Monaten nicht mehr bei AnarBib angemeldet. Ohne Anmeldung deinerseits in den nächsten 30 Tagen wird dein Status als {role} bei {libraryName} automatisch auf inaktiv gesetzt. Um deinen Zugang zu behalten, melde dich einfach bei AnarBib vor dem {deadlineDate} an.",
    ca: "Fa 8 mesos que no et connectes a AnarBib. Sense connexió per part teva en els pròxims 30 dies, el teu estat de {role} a le {libraryName} passarà automàticament a inactiu. Per conservar els teus accessos, simplement connecta't a AnarBib abans del {deadlineDate}.",
    eo: "Vi ne konektiĝis al AnarBib de 8 monatoj. Sen konekto flanke de vi en la venontaj 30 tagoj, via stato de {role} ĉe {libraryName} aŭtomate iĝos neaktiva. Por konservi viajn alirojn, simple konektiĝu al AnarBib antaŭ la {deadlineDate}.",
    nl: "Je hebt al 8 maanden niet ingelogd op AnarBib. Zonder dat je binnen de komende 30 dagen inlogt, wordt je status van {role} bij {libraryName} automatisch inactief. Om je toegang te behouden, log je gewoon in op AnarBib vóór {deadlineDate}.",
    el: "Δεν έχεις συνδεθεί στο AnarBib εδώ και 8 μήνες. Χωρίς σύνδεση από μέρους σου μέσα στις επόμενες 30 ημέρες, η ιδιότητά σου ως {role} στη {libraryName} θα γίνει αυτόματα ανενεργή. Για να διατηρήσεις την πρόσβασή σου, απλώς συνδέσου στο AnarBib πριν τις {deadlineDate}."
  },
  "team.inactive_warning_7d.sub": {
    "pt-BR": "Último lembrete: sua conta passa a inativa em 7 dias",
    fr: "Dernier rappel : ton compte passe en inactif dans 7 jours",
    es: "Último recordatorio: tu cuenta pasa a inactiva en 7 días",
    en: "Last reminder: your account becomes inactive in 7 days",
    it: "Ultimo promemoria: il tuo account passa a inattivo tra 7 giorni",
    de: "Letzte Erinnerung: Dein Konto wird in 7 Tagen inaktiv",
    ca: "Últim recordatori: el teu compte passa a inactiu d'aquí a 7 dies",
    eo: "Lasta memorigo: via konto iĝas neaktiva post 7 tagoj",
    nl: "Laatste herinnering: je account wordt over 7 dagen inactief",
    el: "Τελευταία υπενθύμιση: ο λογαριασμός σου γίνεται ανενεργός σε 7 ημέρες"
  },
  "team.inactive_warning_7d.intro": {
    "pt-BR": "Sem conexão da sua parte nos próximos 7 dias, seu status de {role} na {libraryName} passará automaticamente a inativo em {deadlineDate}.",
    fr: "Sans connexion de ta part dans les 7 prochains jours, ton statut de {role} à la {libraryName} passera automatiquement en inactif le {deadlineDate}.",
    es: "Sin conexión de tu parte en los próximos 7 días, tu estatus de {role} en le {libraryName} pasará automáticamente a inactivo el {deadlineDate}.",
    en: "Without a connection on your part within the next 7 days, your {role} status at {libraryName} will automatically become inactive on {deadlineDate}.",
    it: "Senza una connessione da parte tua nei prossimi 7 giorni, il tuo status di {role} a {libraryName} passerà automaticamente a inattivo il {deadlineDate}.",
    de: "Ohne Anmeldung deinerseits in den nächsten 7 Tagen wird dein Status als {role} bei {libraryName} am {deadlineDate} automatisch auf inaktiv gesetzt.",
    ca: "Sense connexió per part teva en els pròxims 7 dies, el teu estat de {role} a le {libraryName} passarà automàticament a inactiu el {deadlineDate}.",
    eo: "Sen konekto flanke de vi en la venontaj 7 tagoj, via stato de {role} ĉe {libraryName} aŭtomate iĝos neaktiva la {deadlineDate}.",
    nl: "Zonder dat je binnen de komende 7 dagen inlogt, wordt je status van {role} bij {libraryName} op {deadlineDate} automatisch inactief.",
    el: "Χωρίς σύνδεση από μέρους σου μέσα στις επόμενες 7 ημέρες, η ιδιότητά σου ως {role} στη {libraryName} θα γίνει αυτόματα ανενεργή στις {deadlineDate}."
  },
  "team.inactive_auto.sub": {
    "pt-BR": "Sua conta passou a inativa",
    fr: "Ton compte est passé en inactif",
    es: "Tu cuenta pasó a inactiva",
    en: "Your account has become inactive",
    it: "Il tuo account è passato a inattivo",
    de: "Dein Konto ist inaktiv geworden",
    ca: "El teu compte ha passat a inactiu",
    eo: "Via konto iĝis neaktiva",
    nl: "Je account is inactief geworden",
    el: "Ο λογαριασμός σου έγινε ανενεργός"
  },
  "team.inactive_auto.intro": {
    "pt-BR": "Após 9 meses sem conexão, seu status de {role} na {libraryName} passou a inativo. Seus acessos estão fechados. Se você desejar recuperá-los, entre em contato com (o/a/e)s coordenador(o/a/e)s da biblioteca para uma reativação.",
    fr: "Après 9 mois sans connexion, ton statut de {role} à la {libraryName} est passé en inactif. Tes accès sont fermés. Si tu souhaites les retrouver, contacte les coordinateur·rices de la bibliothèque pour une réactivation.",
    es: "Después de 9 meses sin conexión, tu estatus de {role} en le {libraryName} pasó a inactivo. Tus accesos están cerrados. Si querés recuperarlos, contactá a les coordinadores de la biblioteca para una reactivación.",
    en: "After 9 months without a connection, your {role} status at {libraryName} has become inactive. Your access is closed. If you wish to regain it, contact the library coordinators for a reactivation.",
    it: "Dopo 9 mesi senza connessione, il tuo status di {role} a {libraryName} è passato a inattivo. I tuoi accessi sono chiusi. Se desideri recuperarli, contatta le coordinatrici e i coordinatori della biblioteca per una riattivazione.",
    de: "Nach 9 Monaten ohne Anmeldung ist dein Status als {role} bei {libraryName} auf inaktiv gesetzt worden. Dein Zugang ist geschlossen. Wenn du ihn zurückerhalten möchtest, wende dich an die Koordinator*innen der Bibliothek für eine Reaktivierung.",
    ca: "Després de 9 mesos sense connexió, el teu estat de {role} a le {libraryName} ha passat a inactiu. Els teus accessos estan tancats. Si vols recuperar-los, contacta les coordinadores de la biblioteca per a una reactivació.",
    eo: "Post 9 monatoj sen konekto, via stato de {role} ĉe {libraryName} iĝis neaktiva. Viaj aliroj estas fermitaj. Se vi deziras reakiri ilin, kontaktu la kunordigant-in-ojn de la biblioteko por reaktivigo.",
    nl: "Na 9 maanden zonder inloggen is je status van {role} bij {libraryName} inactief geworden. Je toegang is gesloten. Als je die wilt terugkrijgen, neem dan contact op met de coördinatoren van de bibliotheek voor een heractivering.",
    el: "Μετά από 9 μήνες χωρίς σύνδεση, η ιδιότητά σου ως {role} στη {libraryName} έγινε ανενεργή. Η πρόσβασή σου έκλεισε. Αν θέλεις να την ανακτήσεις, επικοινώνησε με τους/τις συντονιστές/στριες της βιβλιοθήκης για επανενεργοποίηση."
  },

  // ===== TM-B (#153.B) — titres et intros des mails admin team.* =====
  "team.promoted.admin.sub": {
    "pt-BR": "Admissão concertada — {role}",
    fr: "Admission concertée — {role}",
    es: "Admisión concertada — {role}",
    en: "Agreed admission — {role}",
    it: "Ammissione concertata — {role}",
    de: "Einvernehmliche Aufnahme — {role}",
    ca: "Admissió concertada — {role}",
    eo: "Interkonsentita akcepto — {role}",
    nl: "Gezamenlijke toelating — {role}",
    el: "Συναινετική ένταξη — {role}"
  },
  "team.promoted.admin.intro": {
    "pt-BR": "{actorName} admitiu {targetName} como {role} na {libraryName}.",
    fr: "{actorName} a admis {targetName} comme {role} à la {libraryName}.",
    es: "{actorName} admitió a {targetName} como {role} en la {libraryName}.",
    en: "{actorName} admitted {targetName} as {role} at {libraryName}.",
    it: "{actorName} ha ammesso {targetName} come {role} presso {libraryName}.",
    de: "{actorName} hat {targetName} als {role} bei {libraryName} aufgenommen.",
    ca: "{actorName} ha admès {targetName} com a {role} a la {libraryName}.",
    eo: "{actorName} akceptis {targetName} kiel {role} ĉe {libraryName}.",
    nl: "{actorName} heeft {targetName} toegelaten als {role} bij {libraryName}.",
    el: "Ο/Η {actorName} δέχτηκε τον/την {targetName} ως {role} στη {libraryName}."
  },
  "team.self_demoted.admin.sub": {
    "pt-BR": "Retorno voluntário ao papel de {toRole}",
    fr: "Retour volontaire au rôle de {toRole}",
    es: "Retorno voluntario al rol de {toRole}",
    en: "Voluntary return to the {toRole} role",
    it: "Ritorno volontario al ruolo di {toRole}",
    de: "Freiwillige Rückkehr zur Rolle {toRole}",
    ca: "Retorn voluntari al rol de {toRole}",
    eo: "Memvola reveno al la rolo {toRole}",
    nl: "Vrijwillige terugkeer naar de rol van {toRole}",
    el: "Εθελοντική επιστροφή στον ρόλο {toRole}"
  },
  "team.self_demoted.admin.intro": {
    "pt-BR": "{actorName} retornou do papel de {fromRole} ao papel de {toRole} na {libraryName}.",
    fr: "{actorName} est revenu·e du rôle de {fromRole} au rôle de {toRole} à la {libraryName}.",
    es: "{actorName} volvió del rol de {fromRole} al rol de {toRole} en la {libraryName}.",
    en: "{actorName} stepped back from the {fromRole} role to the {toRole} role at {libraryName}.",
    it: "{actorName} è tornat* dal ruolo di {fromRole} al ruolo di {toRole} presso {libraryName}.",
    de: "{actorName} ist von der Rolle {fromRole} zur Rolle {toRole} bei {libraryName} zurückgekehrt.",
    ca: "{actorName} ha tornat del rol de {fromRole} al rol de {toRole} a la {libraryName}.",
    eo: "{actorName} revenis de la rolo {fromRole} al la rolo {toRole} ĉe {libraryName}.",
    nl: "{actorName} is teruggetreden van de rol van {fromRole} naar de rol van {toRole} bij {libraryName}.",
    el: "Ο/Η {actorName} επέστρεψε από τον ρόλο {fromRole} στον ρόλο {toRole} στη {libraryName}."
  },
  "team.removal_requested.admin.sub": {
    "pt-BR": "Pedido de retirada — {role}",
    fr: "Demande de retrait — {role}",
    es: "Solicitud de retiro — {role}",
    en: "Removal request — {role}",
    it: "Richiesta di rimozione — {role}",
    de: "Antrag auf Entzug — {role}",
    ca: "Sol·licitud de retirada — {role}",
    eo: "Forigpeto — {role}",
    nl: "Verzoek tot verwijdering — {role}",
    el: "Αίτημα απομάκρυνσης — {role}"
  },
  "team.removal_requested.admin.intro": {
    "pt-BR": "{actorName} solicitou a retirada de {targetName} do papel de {role} na {libraryName}. Prazo de carência: 7 dias.",
    fr: "{actorName} a demandé le retrait de {targetName} du rôle de {role} à la {libraryName}. Délai de carence : 7 jours.",
    es: "{actorName} solicitó el retiro de {targetName} del rol de {role} en la {libraryName}. Plazo de gracia: 7 días.",
    en: "{actorName} requested the removal of {targetName} from the {role} role at {libraryName}. Grace period: 7 days.",
    it: "{actorName} ha richiesto la rimozione di {targetName} dal ruolo di {role} presso {libraryName}. Periodo di tolleranza: 7 giorni.",
    de: "{actorName} hat den Entzug der Rolle {role} von {targetName} bei {libraryName} beantragt. Kulanzfrist: 7 Tage.",
    ca: "{actorName} ha sol·licitat la retirada de {targetName} del rol de {role} a la {libraryName}. Termini de gràcia: 7 dies.",
    eo: "{actorName} petis la forigon de {targetName} el la rolo {role} ĉe {libraryName}. Prokrastperiodo: 7 tagoj.",
    nl: "{actorName} heeft de verwijdering van {targetName} uit de rol van {role} bij {libraryName} aangevraagd. Respijtperiode: 7 dagen.",
    el: "Ο/Η {actorName} ζήτησε την απομάκρυνση του/της {targetName} από τον ρόλο {role} στη {libraryName}. Περίοδος χάριτος: 7 ημέρες."
  },
  "team.removal_cancelled.admin.sub": {
    "pt-BR": "Pedido de retirada anulado — {role}",
    fr: "Demande de retrait annulée — {role}",
    es: "Solicitud de retiro anulada — {role}",
    en: "Removal request cancelled — {role}",
    it: "Richiesta di rimozione annullata — {role}",
    de: "Antrag auf Entzug aufgehoben — {role}",
    ca: "Sol·licitud de retirada anul·lada — {role}",
    eo: "Forigpeto nuligita — {role}",
    nl: "Verzoek tot verwijdering geannuleerd — {role}",
    el: "Αίτημα απομάκρυνσης ακυρώθηκε — {role}"
  },
  "team.removal_cancelled.admin.intro": {
    "pt-BR": "{cancellerName} anulou o pedido de retirada de {targetName} do papel de {role} na {libraryName}. {targetName} recupera todos os direitos imediatamente.",
    fr: "{cancellerName} a annulé la demande de retrait de {targetName} du rôle de {role} à la {libraryName}. {targetName} recouvre tous ses droits immédiatement.",
    es: "{cancellerName} anuló la solicitud de retiro de {targetName} del rol de {role} en la {libraryName}. {targetName} recupera todos sus derechos de inmediato.",
    en: "{cancellerName} cancelled the removal request for {targetName} from the {role} role at {libraryName}. {targetName} regains all rights immediately.",
    it: "{cancellerName} ha annullato la richiesta di rimozione di {targetName} dal ruolo di {role} presso {libraryName}. {targetName} riacquista tutti i diritti immediatamente.",
    de: "{cancellerName} hat den Antrag auf Entzug der Rolle {role} von {targetName} bei {libraryName} aufgehoben. {targetName} erhält alle Rechte sofort zurück.",
    ca: "{cancellerName} ha anul·lat la sol·licitud de retirada de {targetName} del rol de {role} a la {libraryName}. {targetName} recupera tots els drets immediatament.",
    eo: "{cancellerName} nuligis la forigpeton de {targetName} el la rolo {role} ĉe {libraryName}. {targetName} tuj reakiras ĉiujn rajtojn.",
    nl: "{cancellerName} heeft het verzoek tot verwijdering van {targetName} uit de rol van {role} bij {libraryName} geannuleerd. {targetName} krijgt alle rechten onmiddellijk terug.",
    el: "Ο/Η {cancellerName} ακύρωσε το αίτημα απομάκρυνσης του/της {targetName} από τον ρόλο {role} στη {libraryName}. Ο/Η {targetName} ανακτά όλα τα δικαιώματα αμέσως."
  },
  "team.removal_completed.admin.sub": {
    "pt-BR": "Retirada finalizada — {role}",
    fr: "Retrait finalisé — {role}",
    es: "Retiro finalizado — {role}",
    en: "Removal completed — {role}",
    it: "Rimozione completata — {role}",
    de: "Entzug abgeschlossen — {role}",
    ca: "Retirada finalitzada — {role}",
    eo: "Forigo finita — {role}",
    nl: "Verwijdering afgerond — {role}",
    el: "Απομάκρυνση ολοκληρώθηκε — {role}"
  },
  "team.removal_completed.admin.intro": {
    "pt-BR": "O prazo de 7 dias decorreu sem anulação. {targetName} foi retirad-o-a-e do papel de {role} na {libraryName}.",
    fr: "Le délai de 7 jours s’est écoulé sans annulation. {targetName} a été retiré·e du rôle de {role} à la {libraryName}.",
    es: "El plazo de 7 días transcurrió sin anulación. {targetName} fue retirad(o/a/e) del rol de {role} en la {libraryName}.",
    en: "The 7-day period elapsed without cancellation. {targetName} has been removed from the {role} role at {libraryName}.",
    it: "Il termine di 7 giorni è trascorso senza annullamento. {targetName} è stat* rimoss* dal ruolo di {role} presso {libraryName}.",
    de: "Die 7-Tage-Frist ist ohne Aufhebung verstrichen. {targetName} wurde von der Rolle {role} bei {libraryName} entbunden.",
    ca: "El termini de 7 dies ha transcorregut sense anul·lació. {targetName} ha estat retirat(a/e) del rol de {role} a la {libraryName}.",
    eo: "La 7-taga periodo pasis sen nuligo. {targetName} estis forigita el la rolo {role} ĉe {libraryName}.",
    nl: "De termijn van 7 dagen is verstreken zonder annulering. {targetName} is verwijderd uit de rol van {role} bij {libraryName}.",
    el: "Η περίοδος των 7 ημερών παρήλθε χωρίς ακύρωση. Ο/Η {targetName} απομακρύνθηκε από τον ρόλο {role} στη {libraryName}."
  },
  "team.suspended.admin.sub": {
    "pt-BR": "Suspensão imediata — {role}",
    fr: "Suspension immédiate — {role}",
    es: "Suspensión inmediata — {role}",
    en: "Immediate suspension — {role}",
    it: "Sospensione immediata — {role}",
    de: "Sofortige Aussetzung — {role}",
    ca: "Suspensió immediata — {role}",
    eo: "Tuja suspendo — {role}",
    nl: "Onmiddellijke schorsing — {role}",
    el: "Άμεση αναστολή — {role}"
  },
  "team.suspended.admin.intro": {
    "pt-BR": "{actorName} suspendeu os direitos de {role} de {targetName} na {libraryName} por medida cautelar.",
    fr: "{actorName} a suspendu les droits de {role} de {targetName} à la {libraryName} par mesure conservatoire.",
    es: "{actorName} suspendió los derechos de {role} de {targetName} en la {libraryName} como medida cautelar.",
    en: "{actorName} suspended {targetName}'s {role} rights at {libraryName} as a precautionary measure.",
    it: "{actorName} ha sospeso i diritti di {role} di {targetName} presso {libraryName} a titolo cautelare.",
    de: "{actorName} hat die {role}-Rechte von {targetName} bei {libraryName} vorsorglich ausgesetzt.",
    ca: "{actorName} ha suspès els drets de {role} de {targetName} a la {libraryName} com a mesura cautelar.",
    eo: "{actorName} suspendis la {role}-rajtojn de {targetName} ĉe {libraryName} kiel antaŭzorgan rimedon.",
    nl: "{actorName} heeft de {role}-rechten van {targetName} bij {libraryName} als voorzorgsmaatregel geschorst.",
    el: "Ο/Η {actorName} ανέστειλε τα δικαιώματα {role} του/της {targetName} στη {libraryName} ως προληπτικό μέτρο."
  },
  "team.unsuspended.admin.sub": {
    "pt-BR": "Levantamento de suspensão — {role}",
    fr: "Levée de suspension — {role}",
    es: "Levantamiento de suspensión — {role}",
    en: "Suspension lifted — {role}",
    it: "Revoca della sospensione — {role}",
    de: "Aufhebung der Aussetzung — {role}",
    ca: "Aixecament de la suspensió — {role}",
    eo: "Nuligo de suspendo — {role}",
    nl: "Schorsing opgeheven — {role}",
    el: "Άρση αναστολής — {role}"
  },
  "team.unsuspended.admin.intro": {
    "pt-BR": "{actorName} levantou a suspensão dos direitos de {role} de {targetName} na {libraryName}. Acessos restaurados.",
    fr: "{actorName} a levé la suspension des droits de {role} de {targetName} à la {libraryName}. Accès restaurés.",
    es: "{actorName} levantó la suspensión de los derechos de {role} de {targetName} en la {libraryName}. Accesos restaurados.",
    en: "{actorName} lifted the suspension of {targetName}'s {role} rights at {libraryName}. Access restored.",
    it: "{actorName} ha revocato la sospensione dei diritti di {role} di {targetName} presso {libraryName}. Accessi ripristinati.",
    de: "{actorName} hat die Aussetzung der {role}-Rechte von {targetName} bei {libraryName} aufgehoben. Zugänge wiederhergestellt.",
    ca: "{actorName} ha aixecat la suspensió dels drets de {role} de {targetName} a la {libraryName}. Accessos restaurats.",
    eo: "{actorName} nuligis la suspendon de la {role}-rajtoj de {targetName} ĉe {libraryName}. Aliroj restarigitaj.",
    nl: "{actorName} heeft de schorsing van de {role}-rechten van {targetName} bij {libraryName} opgeheven. Toegang hersteld.",
    el: "Ο/Η {actorName} ήρε την αναστολή των δικαιωμάτων {role} του/της {targetName} στη {libraryName}. Η πρόσβαση αποκαταστάθηκε."
  },
  "team.inactive_warning_7d.admin.sub": {
    "pt-BR": "Aviso de inatividade — 7 dias antes da passagem para inativo",
    fr: "Avertissement d'inactivité — 7 jours avant le passage en inactif",
    es: "Aviso de inactividad — 7 días antes del paso a inactivo",
    en: "Inactivity warning — 7 days before becoming inactive",
    it: "Avviso di inattività — 7 giorni prima del passaggio a inattivo",
    de: "Inaktivitätswarnung — 7 Tage vor dem Wechsel zu inaktiv",
    ca: "Avís d'inactivitat — 7 dies abans del pas a inactiu",
    eo: "Averto pri neaktiveco — 7 tagoj antaŭ la ŝanĝo al neaktiva",
    nl: "Inactiviteitswaarschuwing — 7 dagen vóór inactiviteit",
    el: "Προειδοποίηση αδράνειας — 7 ημέρες πριν γίνει ανενεργός"
  },
  "team.inactive_warning_7d.admin.intro": {
    "pt-BR": "{targetName} está prestes a passar para inativo (papel de {role}) na {libraryName} em {deadlineDate} se não se conectar.",
    fr: "{targetName} est sur le point de passer en inactif (rôle de {role}) à la {libraryName} le {deadlineDate} en l'absence de connexion.",
    es: "{targetName} está a punto de pasar a inactivo (rol de {role}) en la {libraryName} el {deadlineDate} si no se conecta.",
    en: "{targetName} is about to become inactive ({role} role) at {libraryName} on {deadlineDate} unless they log in.",
    it: "{targetName} sta per passare a inattivo (ruolo di {role}) presso {libraryName} il {deadlineDate} se non si connette.",
    de: "{targetName} wird bei {libraryName} am {deadlineDate} auf inaktiv gesetzt ({role}-Rolle), falls keine Anmeldung erfolgt.",
    ca: "{targetName} està a punt de passar a inactiu (rol de {role}) a la {libraryName} el {deadlineDate} si no es connecta.",
    eo: "{targetName} baldaŭ fariĝos neaktiva (rolo {role}) ĉe {libraryName} je {deadlineDate}, se ri ne ensalutos.",
    nl: "{targetName} staat op het punt inactief te worden (rol van {role}) bij {libraryName} op {deadlineDate}, tenzij die inlogt.",
    el: "Ο/Η {targetName} πρόκειται να γίνει ανενεργός/ή (ρόλος {role}) στη {libraryName} στις {deadlineDate} εκτός αν συνδεθεί."
  },
  // ===== TM-A (#153.B) — escalade réseau au seuil J-7 (dernier·e coord) =====
  "team.inactive_warning_7d.escalation.sub": {
    "pt-BR": "Escalada de rede — última coordenação inativa: {libraryName}",
    fr: "Escalade réseau — dernière coordination inactive : {libraryName}",
    es: "Escalada de red — última coordinación inactiva: {libraryName}",
    en: "Network escalation — last coordination inactive: {libraryName}",
    it: "Escalation di rete — ultimo coordinamento inattivo: {libraryName}",
    de: "Netzwerk-Eskalation — letzte Koordination inaktiv: {libraryName}",
    ca: "Escalada de xarxa — última coordinació inactiva: {libraryName}",
    eo: "Reta plialtigo — lasta kunordigo neaktiva: {libraryName}",
    nl: "Netwerkescalatie — laatste coördinatie inactief: {libraryName}",
    el: "Κλιμάκωση δικτύου — ανενεργός/ή ο/η τελευταίος/α συντονιστής/στρια: {libraryName}"
  },
  "team.inactive_warning_7d.escalation.intro": {
    "pt-BR": "{targetName}, únic-o-a-e coordenador-a-e de {libraryName}, está inativ-o-a-e e passará automaticamente para inativo em {deadlineDate} (em 7 dias). Como não há outra coordenação local para ser avisada, esta notificação é escalada à administração da rede. Sem reação, a biblioteca ficará sem coordenação ativa.",
    fr: "{targetName}, unique coordinateur·rice de {libraryName}, est inactif·ve et passera automatiquement en inactif le {deadlineDate} (dans 7 jours). Comme il n'y a pas d'autre coordination locale à prévenir, cette notification est escaladée à l'administration du réseau. Sans réaction, la bibliothèque se retrouvera sans coordination active.",
    es: "{targetName}, únic(a/e) coordinador(a/e) de {libraryName}, está inactiv(a/e) y pasará automáticamente a inactivo el {deadlineDate} (en 7 días). Como no hay otra coordinación local a la que avisar, esta notificación se escala a la administración de la red. Sin reacción, la biblioteca quedará sin coordinación activa.",
    en: "{targetName}, the only coordinator of {libraryName}, is inactive and will automatically become inactive on {deadlineDate} (in 7 days). As there is no other local coordination to notify, this notice is escalated to the network administration. Without action, the library will be left with no active coordination.",
    it: "{targetName}, unica coordinazione di {libraryName}, è inattiva e passerà automaticamente a inattivo il {deadlineDate} (tra 7 giorni). Poiché non c'è altro coordinamento locale da avvisare, questa notifica è inoltrata all'amministrazione della rete. Senza reazione, la biblioteca resterà senza coordinamento attivo.",
    de: "{targetName}, einzige Koordination von {libraryName}, ist inaktiv und wird am {deadlineDate} (in 7 Tagen) automatisch auf inaktiv gesetzt. Da es keine andere lokale Koordination zu benachrichtigen gibt, wird diese Mitteilung an die Netzwerk-Verwaltung eskaliert. Ohne Reaktion bleibt die Bibliothek ohne aktive Koordination.",
    ca: "{targetName}, únic(a/e) coordinador(a/e) de {libraryName}, està inactiv(a/e) i passarà automàticament a inactiu el {deadlineDate} (d'aquí a 7 dies). Com que no hi ha cap altra coordinació local a qui avisar, aquesta notificació s'escala a l'administració de la xarxa. Sense reacció, la biblioteca quedarà sense coordinació activa.",
    eo: "{targetName}, sola kunordiganto de {libraryName}, estas neaktiva kaj aŭtomate fariĝos neaktiva je {deadlineDate} (post 7 tagoj). Ĉar ne ekzistas alia loka kunordigo por averti, ĉi tiu sciigo estas plialtigita al la reta administrado. Sen reago, la biblioteko restos sen aktiva kunordigo.",
    nl: "{targetName}, de enige coördinator van {libraryName}, is inactief en wordt op {deadlineDate} (over 7 dagen) automatisch inactief. Omdat er geen andere lokale coördinatie is om te waarschuwen, wordt deze melding geëscaleerd naar het netwerkbeheer. Zonder reactie blijft de bibliotheek zonder actieve coördinatie.",
    el: "Ο/Η {targetName}, ο/η μοναδικός/ή συντονιστής/στρια της {libraryName}, είναι αδρανής και θα γίνει αυτόματα ανενεργός/ή στις {deadlineDate} (σε 7 ημέρες). Καθώς δεν υπάρχει άλλος τοπικός συντονισμός για ειδοποίηση, αυτή η ειδοποίηση κλιμακώνεται στη διαχείριση του δικτύου. Χωρίς ενέργεια, η βιβλιοθήκη θα μείνει χωρίς ενεργό συντονισμό."
  },
  "team.inactive_auto.admin.sub": {
    "pt-BR": "Passagem para inativo confirmada — {role}",
    fr: "Passage en inactif confirmé — {role}",
    es: "Paso a inactivo confirmado — {role}",
    en: "Transition to inactive confirmed — {role}",
    it: "Passaggio a inattivo confermato — {role}",
    de: "Wechsel zu inaktiv bestätigt — {role}",
    ca: "Pas a inactiu confirmat — {role}",
    eo: "Ŝanĝo al neaktiva konfirmita — {role}",
    nl: "Overgang naar inactief bevestigd — {role}",
    el: "Μετάβαση σε ανενεργό επιβεβαιώθηκε — {role}"
  },
  "team.inactive_auto.admin.intro": {
    "pt-BR": "{targetName} passou para inativo após 9 meses sem conexão (papel de {role}) na {libraryName}. Acessos fechados.",
    fr: "{targetName} est passé·e en inactif après 9 mois sans connexion (rôle de {role}) à la {libraryName}. Accès fermés.",
    es: "{targetName} pasó a inactivo tras 9 meses sin conexión (rol de {role}) en la {libraryName}. Accesos cerrados.",
    en: "{targetName} became inactive after 9 months without logging in ({role} role) at {libraryName}. Access closed.",
    it: "{targetName} è passat* a inattivo dopo 9 mesi senza connessione (ruolo di {role}) presso {libraryName}. Accessi chiusi.",
    de: "{targetName} wurde nach 9 Monaten ohne Anmeldung auf inaktiv gesetzt ({role}-Rolle) bei {libraryName}. Zugänge geschlossen.",
    ca: "{targetName} ha passat a inactiu després de 9 mesos sense connexió (rol de {role}) a la {libraryName}. Accessos tancats.",
    eo: "{targetName} fariĝis neaktiva post 9 monatoj sen ensaluto (rolo {role}) ĉe {libraryName}. Aliroj fermitaj.",
    nl: "{targetName} is inactief geworden na 9 maanden zonder inloggen (rol van {role}) bij {libraryName}. Toegang gesloten.",
    el: "Ο/Η {targetName} έγινε ανενεργός/ή μετά από 9 μήνες χωρίς σύνδεση (ρόλος {role}) στη {libraryName}. Η πρόσβαση έκλεισε."
  },

  // ===== Welcome — mail de bienvenue post-inscription (welcome.*) ============
  // Section utilisée par register/index.ts > buildUserMail()
  // Cas standard : inscription rattachée à une biblio existante
  // Cas "initial" : inscription orpheline (signup_without_library=true)
  //   ââ€ ’ contient le CTA vers /solicitar-biblioteca avec claim token (TTL 14j)
  // ===== TR-4 (#153.B) — titres/sous-titres/sujets des mails internes register =====
  "register.internal.pretitle.coordination": {
    "pt-BR": "Notificação da coordenação AnarBib",
    fr: "Notification de la coordination AnarBib",
    es: "Notificación de la coordinación AnarBib",
    en: "AnarBib coordination notice",
    it: "Notifica del coordinamento AnarBib",
    de: "Mitteilung der AnarBib-Koordination",
    ca: "Notificació de la coordinació AnarBib",
    eo: "Sciigo de la AnarBib-kunordigo",
    nl: "Melding van de AnarBib-coördinatie",
    el: "Ειδοποίηση του συντονισμού AnarBib"
  },
  "register.internal.pretitle.library": {
    "pt-BR": "Notificação da biblioteca",
    fr: "Notification de la bibliothèque",
    es: "Notificación de la biblioteca",
    en: "Library notice",
    it: "Notifica della biblioteca",
    de: "Mitteilung der Bibliothek",
    ca: "Notificació de la biblioteca",
    eo: "Sciigo de la biblioteko",
    nl: "Melding van de bibliotheek",
    el: "Ειδοποίηση της βιβλιοθήκης"
  },
  "register.internal.pretitle.management": {
    "pt-BR": "Notificação da gestão AnarBib",
    fr: "Notification de la gestion AnarBib",
    es: "Notificación de la gestión AnarBib",
    en: "AnarBib management notice",
    it: "Notifica della gestione AnarBib",
    de: "Mitteilung der AnarBib-Verwaltung",
    ca: "Notificació de la gestió AnarBib",
    eo: "Sciigo de la AnarBib-administrado",
    nl: "Melding van het AnarBib-beheer",
    el: "Ειδοποίηση της διαχείρισης AnarBib"
  },
  "register.internal.title.orphan": {
    "pt-BR": "Cadastro de leitor-a-e órfã-o-e — {displayName}",
    fr: "Inscription de lecteur·rice orphelin·e — {displayName}",
    es: "Registro de lector(a/e) huérfan(a/e) — {displayName}",
    en: "Registration of an unaffiliated reader — {displayName}",
    it: "Registrazione di lettore/trice orfan* — {displayName}",
    de: "Anmeldung einer noch nicht zugeordneten lesenden Person — {displayName}",
    ca: "Registre de lector(a/e) orfe(na/e) — {displayName}",
    eo: "Registriĝo de senbiblioteka leganto — {displayName}",
    nl: "Inschrijving van een niet-aangesloten lezer — {displayName}",
    el: "Εγγραφή ανένταχτου/ης αναγνώστη/στριας — {displayName}"
  },
  "register.internal.title.initial": {
    "pt-BR": "Cadastro inicial sem biblioteca — {displayName}",
    fr: "Inscription initiale sans bibliothèque — {displayName}",
    es: "Registro inicial sin biblioteca — {displayName}",
    en: "Initial registration without a library — {displayName}",
    it: "Registrazione iniziale senza biblioteca — {displayName}",
    de: "Erstanmeldung ohne Bibliothek — {displayName}",
    ca: "Registre inicial sense biblioteca — {displayName}",
    eo: "Komenca registriĝo sen biblioteko — {displayName}",
    nl: "Initiële inschrijving zonder bibliotheek — {displayName}",
    el: "Αρχική εγγραφή χωρίς βιβλιοθήκη — {displayName}"
  },
  "register.internal.title.standard": {
    "pt-BR": "Novo cadastro — {displayName}",
    fr: "Nouvelle inscription — {displayName}",
    es: "Nuevo registro — {displayName}",
    en: "New registration — {displayName}",
    it: "Nuova registrazione — {displayName}",
    de: "Neue Anmeldung — {displayName}",
    ca: "Nou registre — {displayName}",
    eo: "Nova registriĝo — {displayName}",
    nl: "Nieuwe inschrijving — {displayName}",
    el: "Νέα εγγραφή — {displayName}"
  },
  "register.internal.subtitle.orphan": {
    "pt-BR": "Nov-o-a-e leitor-a-e órfã-o-e (biblioteca ainda não no AnarBib), ID {publicId}.",
    fr: "Nouvelle lecteur·rice orphelin·e (bibliothèque pas encore sur AnarBib), ID {publicId}.",
    es: "Nueva lectora huérfana (biblioteca aún no en AnarBib), ID {publicId}.",
    en: "New unaffiliated reader (library not yet on AnarBib), ID {publicId}.",
    it: "Nuov* lettore/trice orfan* (biblioteca non ancora su AnarBib), ID {publicId}.",
    de: "Neue noch nicht zugeordnete lesende Person (Bibliothek noch nicht bei AnarBib), ID {publicId}.",
    ca: "Nova lectora òrfena (biblioteca encara no a AnarBib), ID {publicId}.",
    eo: "Nova senbiblioteka leganto (biblioteko ankoraŭ ne en AnarBib), ID {publicId}.",
    nl: "Nieuwe niet-aangesloten lezer (bibliotheek nog niet op AnarBib), ID {publicId}.",
    el: "Νέος/α ανένταχτος/η αναγνώστης/στρια (η βιβλιοθήκη δεν είναι ακόμη στο AnarBib), ID {publicId}."
  },
  "register.internal.subtitle.initial": {
    "pt-BR": "Novo cadastro inicial sem biblioteca vinculada, com ID {publicId}.",
    fr: "Nouvelle inscription initiale sans bibliothèque rattachée, ID {publicId}.",
    es: "Nuevo registro inicial sin biblioteca vinculada, con ID {publicId}.",
    en: "New initial registration with no library attached, ID {publicId}.",
    it: "Nuova registrazione iniziale senza biblioteca collegata, ID {publicId}.",
    de: "Neue Erstanmeldung ohne zugeordnete Bibliothek, ID {publicId}.",
    ca: "Nou registre inicial sense biblioteca vinculada, amb ID {publicId}.",
    eo: "Nova komenca registriĝo sen ligita biblioteko, ID {publicId}.",
    nl: "Nieuwe initiële inschrijving zonder gekoppelde bibliotheek, ID {publicId}.",
    el: "Νέα αρχική εγγραφή χωρίς συνδεδεμένη βιβλιοθήκη, ID {publicId}."
  },
  "register.internal.subtitle.standard": {
    "pt-BR": "Novo cadastro de leitor-a-e com ID {publicId}.",
    fr: "Nouvelle inscription de lecteur·rice, ID {publicId}.",
    es: "Nuevo registro de lector(a/e) con ID {publicId}.",
    en: "New reader registration, ID {publicId}.",
    it: "Nuova registrazione di lettore/trice, ID {publicId}.",
    de: "Neue Anmeldung einer lesenden Person, ID {publicId}.",
    ca: "Nou registre de lector(a/e), amb ID {publicId}.",
    eo: "Nova registriĝo de leganto, ID {publicId}.",
    nl: "Nieuwe inschrijving van een lezer, ID {publicId}.",
    el: "Νέα εγγραφή αναγνώστη/στριας, ID {publicId}."
  },
  "register.internal.orphanLib.mentioned": {
    "pt-BR": " Biblioteca mencionada: \"{libraryName}\".",
    fr: " Bibliothèque mentionnée : « {libraryName} ».",
    es: " Biblioteca mencionada: «{libraryName}».",
    en: " Library mentioned: \"{libraryName}\".",
    it: " Biblioteca menzionata: «{libraryName}».",
    de: " Genannte Bibliothek: „{libraryName}\".",
    ca: " Biblioteca esmentada: «{libraryName}».",
    eo: " Menciita biblioteko: \"{libraryName}\".",
    nl: " Genoemde bibliotheek: „{libraryName}”.",
    el: " Αναφερόμενη βιβλιοθήκη: «{libraryName}»."
  },
  "register.internal.orphanLib.none": {
    "pt-BR": " Nenhuma biblioteca mencionada.",
    fr: " Aucune bibliothèque mentionnée.",
    es: " Ninguna biblioteca mencionada.",
    en: " No library mentioned.",
    it: " Nessuna biblioteca menzionata.",
    de: " Keine Bibliothek genannt.",
    ca: " Cap biblioteca esmentada.",
    eo: " Neniu biblioteko menciita.",
    nl: " Geen bibliotheek genoemd.",
    el: " Καμία βιβλιοθήκη δεν αναφέρθηκε."
  },
  "register.internal.testContextNote": {
    "pt-BR": "Este cadastro passou por uma rota com redirecionamento ou marcação de teste ativa.",
    fr: "Cette inscription est passée par une route avec redirection ou marquage de test actif.",
    es: "Este registro pasó por una ruta con redirección o marcado de prueba activo.",
    en: "This registration went through a route with an active redirect or test flag.",
    it: "Questa registrazione è passata per una rotta con reindirizzamento o marcatura di test attiva.",
    de: "Diese Anmeldung lief über eine Route mit aktiver Weiterleitung oder Testmarkierung.",
    ca: "Aquest registre ha passat per una ruta amb redirecció o marcatge de prova actiu.",
    eo: "Ĉi tiu registriĝo pasis tra vojo kun aktiva alidirektado aŭ testmarko.",
    nl: "Deze inschrijving liep via een route met een actieve omleiding of testmarkering.",
    el: "Αυτή η εγγραφή πέρασε από διαδρομή με ενεργή ανακατεύθυνση ή σήμανση δοκιμής."
  },
  "register.internal.subject": {
    "pt-BR": "Novo cadastro — {displayName} — {publicId}",
    fr: "Nouvelle inscription — {displayName} — {publicId}",
    es: "Nuevo registro — {displayName} — {publicId}",
    en: "New registration — {displayName} — {publicId}",
    it: "Nuova registrazione — {displayName} — {publicId}",
    de: "Neue Anmeldung — {displayName} — {publicId}",
    ca: "Nou registre — {displayName} — {publicId}",
    eo: "Nova registriĝo — {displayName} — {publicId}",
    nl: "Nieuwe inschrijving — {displayName} — {publicId}",
    el: "Νέα εγγραφή — {displayName} — {publicId}"
  },
  "welcome.subject": {
    "pt-BR": "Cadastro criado — {displayName}",
    fr: "Inscription créée — {displayName}",
    es: "Inscripción creada — {displayName}",
    en: "Registration created — {displayName}",
    it: "Iscrizione creata — {displayName}",
    de: "Anmeldung erstellt — {displayName}",
    ca: "Inscripció creada — {displayName}",
    eo: "Registriĝo kreita — {displayName}",
    nl: "Inschrijving aangemaakt — {displayName}",
    el: "Η εγγραφή δημιουργήθηκε — {displayName}"
  },
  "welcome.subject.initial": {
    "pt-BR": "Cadastro inicial criado — {displayName}",
    fr: "Inscription initiale créée — {displayName}",
    es: "Inscripción inicial creada — {displayName}",
    en: "Initial registration created — {displayName}",
    it: "Iscrizione iniziale creata — {displayName}",
    de: "Anmeldung initialisiert — {displayName}",
    ca: "Inscripció inicial creada — {displayName}",
    eo: "Komenca registriĝo kreita — {displayName}",
    nl: "Initiële inschrijving aangemaakt — {displayName}",
    el: "Η αρχική εγγραφή δημιουργήθηκε — {displayName}"
  },
  "welcome.pretitle": {
    "pt-BR": "Cadastro criado",
    fr: "Inscription créée",
    es: "Inscripción creada",
    en: "Registration created",
    it: "Iscrizione creata",
    de: "Anmeldung erstellt",
    ca: "Inscripció creada",
    eo: "Registriĝo kreita",
    nl: "Inschrijving aangemaakt",
    el: "Η εγγραφή δημιουργήθηκε"
  },
  "welcome.pretitle.initial": {
    "pt-BR": "Cadastro inicial criado",
    fr: "Inscription initiale créée",
    es: "Inscripción inicial creada",
    en: "Initial registration created",
    it: "Iscrizione iniziale creata",
    de: "Anmeldung initialisiert",
    ca: "Inscripció inicial creada",
    eo: "Komenca registriĝo kreita",
    nl: "Initiële inschrijving aangemaakt",
    el: "Η αρχική εγγραφή δημιουργήθηκε"
  },
  "welcome.title.initial": {
    "pt-BR": "Bem-vind(o/a/e) à rede AnarBib",
    fr: "Bienvenue dans le réseau AnarBib",
    es: "Bienvenide a la red AnarBib",
    en: "Welcome to the AnarBib network",
    it: "Benvenutə nella rete AnarBib",
    de: "Willkommen im AnarBib-Netzwerk",
    ca: "Benvingut-da-e a la xarxa AnarBib",
    eo: "Bonvenon en la reton AnarBib",
    nl: "Welkom bij het AnarBib-netwerk",
    el: "Καλώς όρισες στο δίκτυο AnarBib"
  },
   "welcome.title": {
    "pt-BR": "Bem-vind(o/a/e) à {libraryName}",
    fr: "Bienvenue à la {libraryName}",
    es: "Bienvenide a le {libraryName}",
    en: "Welcome to {libraryName}",
    it: "Benvenutə alla {libraryName}",
    de: "Willkommen bei {libraryName}",
    ca: "Benvingut-da-e a le {libraryName}",
    eo: "Bonvenon ĉe {libraryName}",
    nl: "Welkom bij {libraryName}",
    el: "Καλώς όρισες στη {libraryName}"
  },
  "welcome.subtitle": {
    "pt-BR": "Seu acesso inicial ao AnarBib já está pronto.",
    fr: "Ton accès initial à AnarBib est prêt.",
    es: "Tu acceso inicial a AnarBib ya está listo.",
    en: "Your initial access to AnarBib is ready.",
    it: "Il tuo accesso iniziale ad AnarBib è pronto.",
    de: "Dein erster Zugang zu AnarBib ist bereit.",
    ca: "El teu accés inicial a AnarBib ja està llest.",
    eo: "Via komenca aliro al AnarBib estas preta.",
    nl: "Je eerste toegang tot AnarBib staat klaar.",
    el: "Η αρχική σου πρόσβαση στο AnarBib είναι έτοιμη."
  },
  "welcome.greeting": {
    "pt-BR": "Olá, <b>{firstName}</b>.",
    fr: "Bonjour, <b>{firstName}</b>.",
    es: "Hola, <b>{firstName}</b>.",
    en: "Hello, <b>{firstName}</b>.",
    it: "Ciao, <b>{firstName}</b>.",
    de: "Hallo, <b>{firstName}</b>.",
    ca: "Hola, <b>{firstName}</b>.",
    eo: "Saluton, <b>{firstName}</b>.",
    nl: "Hallo, <b>{firstName}</b>.",
    el: "Γεια σου, <b>{firstName}</b>."
  },
  "welcome.context.standard": {
    "pt-BR": "Seu cadastro de leitor(a/e) na <b>{libraryName}</b> foi criado com sucesso.",
    fr: "Ton inscription en tant que lecteur·rice à la <b>{libraryName}</b> a été créée avec succès.",
    es: "Tu inscripción como lector(a/e) en le <b>{libraryName}</b> fue creada con éxito.",
    en: "Your reader registration at <b>{libraryName}</b> has been created successfully.",
    it: "La tua iscrizione come lettore/trice presso <b>{libraryName}</b> è stata creata con successo.",
    de: "Deine Leser*innen-Anmeldung bei <b>{libraryName}</b> wurde erfolgreich erstellt.",
    ca: "La teva inscripció com a lector-a-e a le <b>{libraryName}</b> s'ha creat correctament.",
    eo: "Via registriĝo kiel legant-in-o ĉe <b>{libraryName}</b> estis sukcese kreita.",
    nl: "Je inschrijving als lezer bij <b>{libraryName}</b> is succesvol aangemaakt.",
    el: "Η εγγραφή σου ως αναγνώστης/στρια στη <b>{libraryName}</b> δημιουργήθηκε με επιτυχία."
  },
  "welcome.context.initial": {
    "pt-BR": "Sua conta inicial no <b>AnarBib</b> foi criada com sucesso. A próxima etapa é enviar a solicitação institucional da sua biblioteca para análise da coordenação da rede.",
    fr: "Ton compte initial sur <b>AnarBib</b> a été créé avec succès. La prochaine étape est d'envoyer la demande institutionnelle de ta bibliothèque pour analyse de la coordination du réseau.",
    es: "Tu cuenta inicial en <b>AnarBib</b> fue creada con éxito. El próximo paso es enviar la solicitud institucional de tu biblioteca para análisis de la coordinación de la red.",
    en: "Your initial account on <b>AnarBib</b> has been created successfully. The next step is to submit the institutional request for your library to the network coordination for review.",
    it: "Il tuo account iniziale su <b>AnarBib</b> è stato creato con successo. Il prossimo passo è inviare la richiesta istituzionale della tua biblioteca per l'analisi del coordinamento della rete.",
    de: "Dein erstes Konto auf <b>AnarBib</b> wurde erfolgreich erstellt. Der nächste Schritt ist, den institutionellen Antrag deiner Bibliothek zur Prüfung durch die Netzwerkkoordination einzureichen.",
    ca: "El teu compte inicial a <b>AnarBib</b> s'ha creat correctament. El pròxim pas és enviar la sol·licitud institucional de la teva biblioteca per a l'anàlisi de la coordinació de la xarxa.",
    eo: "Via komenca konto ĉe <b>AnarBib</b> estis sukcese kreita. La sekva etapo estas sendi la institucian peton de via biblioteko por analizo fare de la kunordigo de la reto.",
    nl: "Je initiële account op <b>AnarBib</b> is succesvol aangemaakt. De volgende stap is om de institutionele aanvraag voor je bibliotheek in te dienen bij de netwerkcoördinatie ter beoordeling.",
    el: "Ο αρχικός σου λογαριασμός στο <b>AnarBib</b> δημιουργήθηκε με επιτυχία. Το επόμενο βήμα είναι να υποβάλεις το θεσμικό αίτημα της βιβλιοθήκης σου προς εξέταση από τον συντονισμό του δικτύου."
  },
  "welcome.publicIdLabel": {
    "pt-BR": "Seu ID público",
    fr: "Ton identifiant public",
    es: "Tu identificador público",
    en: "Your public ID",
    it: "Il tuo ID pubblico",
    de: "Deine öffentliche Kennung",
    ca: "El teu ID públic",
    eo: "Via publika ID",
    nl: "Je openbare ID",
    el: "Το δημόσιο ID σου"
  },
  "welcome.tempPasswordLabel": {
    "pt-BR": "Senha provisória",
    fr: "Mot de passe provisoire",
    es: "Contraseña provisional",
    en: "Temporary password",
    it: "Password provvisoria",
    de: "Vorläufiges Passwort",
    ca: "Contrasenya provisional",
    eo: "Provizora pasvorto",
    nl: "Tijdelijk wachtwoord",
    el: "Προσωρινός κωδικός"
  },
  "welcome.nextAccess": {
    "pt-BR": "Nos próximos acessos ao AnarBib, entre com seu <b>ID público</b> e sua senha.",
    fr: "Pour tes prochains accès à AnarBib, connecte-toi avec ton <b>identifiant public</b> et ton mot de passe.",
    es: "En tus próximos accesos a AnarBib, ingresá con tu <b>identificador público</b> y tu contraseña.",
    en: "For your next visits to AnarBib, log in with your <b>public ID</b> and your password.",
    it: "Per i tuoi prossimi accessi ad AnarBib, accedi con il tuo <b>ID pubblico</b> e la tua password.",
    de: "Bei deinen nächsten Anmeldungen bei AnarBib verwende deine <b>öffentliche Kennung</b> und dein Passwort.",
    ca: "Per als teus pròxims accessos a AnarBib, connecta't amb el teu <b>ID públic</b> i la teva contrasenya.",
    eo: "Por viaj sekvaj aliroj al AnarBib, konektiĝu per via <b>publika ID</b> kaj via pasvorto.",
    nl: "Voor je volgende bezoeken aan AnarBib log je in met je <b>openbare ID</b> en je wachtwoord.",
    el: "Για τις επόμενες επισκέψεις σου στο AnarBib, συνδέσου με το <b>δημόσιο ID σου</b> και τον κωδικό σου."
  },
  "welcome.important": {
    "pt-BR": "<b>Importante:</b> a senha enviada aqui é provisória. Depois do primeiro acesso, altere-a na página <b>Conta</b>.",
    fr: "<b>Important :</b> le mot de passe envoyé ici est provisoire. Dès ton premier accès, tu seras invité·e à le changer.",
    es: "<b>Importante:</b> la contraseña enviada aquí es provisional. En tu primer acceso, se te invitará a cambiarla.",
    en: "<b>Important:</b> the password sent here is temporary. On your first login, you will be prompted to change it.",
    it: "<b>Importante:</b> la password inviata qui è provvisoria. Al primo accesso, ti verrà chiesto di cambiarla.",
    de: "<b>Wichtig:</b> Das hier gesendete Passwort ist vorläufig. Bei deiner ersten Anmeldung wirst du aufgefordert, es zu ändern.",
    ca: "<b>Important:</b> la contrasenya enviada aquí és provisional. Al teu primer accés, se t'invitarà a canviar-la.",
    eo: "<b>Grave:</b> la pasvorto sendita ĉi tie estas provizora. Ĉe via unua aliro, vi estos invitita ŝanĝi ĝin.",
    nl: "<b>Belangrijk:</b> het hier verzonden wachtwoord is tijdelijk. Bij je eerste keer inloggen word je gevraagd het te wijzigen.",
    el: "<b>Σημαντικό:</b> ο κωδικός που στάλθηκε εδώ είναι προσωρινός. Στην πρώτη σου σύνδεση, θα σου ζητηθεί να τον αλλάξεις."
  },
  "welcome.forgotHint": {
    "pt-BR": "Se você perder o acesso, use o botão <b>\"Esqueci minha senha\"</b> na página de login.",
    fr: "Si tu perds l'accès, utilise le bouton <b>« Mot de passe oublié »</b> sur la page de connexion.",
    es: "Si perdés el acceso, usá el botón <b>«Olvidé mi contraseña»</b> en la página de inicio de sesión.",
    en: "If you lose access, use the <b>\"Forgot my password\"</b> button on the login page.",
    it: "Se perdi l'accesso, usa il pulsante <b>«Ho dimenticato la password»</b> nella pagina di accesso.",
    de: "Wenn du den Zugang verlierst, verwende die Schaltfläche <b>„Passwort vergessen\"</b> auf der Anmeldeseite.",
    ca: "Si perds l'accés, fes servir el botó <b>«He oblidat la contrasenya»</b> a la pàgina d'inici de sessió.",
    eo: "Se vi perdas la aliron, uzu la butonon <b>«Mi forgesis mian pasvorton»</b> en la ensaluta paĝo.",
    nl: "Als je de toegang verliest, gebruik dan de knop <b>„Wachtwoord vergeten”</b> op de inlogpagina.",
    el: "Αν χάσεις την πρόσβαση, χρησιμοποίησε το κουμπί <b>«Ξέχασα τον κωδικό μου»</b> στη σελίδα σύνδεσης."
  },
  "welcome.libraryRequest.intro": {
    "pt-BR": "Use o botão abaixo para iniciar a solicitação institucional da sua biblioteca. Este link já está ligado à sua conta inicial, não precisa entrar manualmente de novo para começar.",
    fr: "Utilise le bouton ci-dessous pour initier la demande institutionnelle de ta bibliothèque. Ce lien est déjà lié à ton compte initial, tu n'as pas besoin de te reconnecter manuellement pour commencer.",
    es: "Usá el botón de abajo para iniciar la solicitud institucional de tu biblioteca. Este enlace ya está vinculado a tu cuenta inicial, no necesitás iniciar sesión manualmente otra vez para comenzar.",
    en: "Use the button below to start the institutional request for your library. This link is already tied to your initial account — no need to log in manually again to begin.",
    it: "Usa il pulsante qui sotto per avviare la richiesta istituzionale della tua biblioteca. Questo link è già collegato al tuo account iniziale, non hai bisogno di accedere manualmente di nuovo per iniziare.",
    de: "Verwende die Schaltfläche unten, um den institutionellen Antrag deiner Bibliothek zu starten. Dieser Link ist bereits mit deinem ersten Konto verknüpft — du musst dich nicht erneut manuell anmelden, um zu beginnen.",
    ca: "Fes servir el botó de sota per iniciar la sol·licitud institucional de la teva biblioteca. Aquest enllaç ja està vinculat al teu compte inicial, no cal que tornis a iniciar sessió manualment per començar.",
    eo: "Uzu la suban butonon por komenci la institucian peton de via biblioteko. Ĉi tiu ligilo jam estas ligita al via komenca konto, vi ne bezonas reensaluti permane por komenci.",
    nl: "Gebruik de knop hieronder om de institutionele aanvraag voor je bibliotheek te starten. Deze link is al gekoppeld aan je initiële account — je hoeft niet opnieuw handmatig in te loggen om te beginnen.",
    el: "Χρησιμοποίησε το παρακάτω κουμπί για να ξεκινήσεις το θεσμικό αίτημα της βιβλιοθήκης σου. Αυτός ο σύνδεσμος είναι ήδη συνδεδεμένος με τον αρχικό σου λογαριασμό — δεν χρειάζεται να συνδεθείς ξανά χειροκίνητα για να ξεκινήσεις."
  },
  "welcome.libraryRequest.cta": {
    "pt-BR": "Iniciar solicitação da biblioteca",
    fr: "Démarrer la demande de bibliothèque",
    es: "Iniciar solicitud de la biblioteca",
    en: "Start the library request",
    it: "Avviare la richiesta della biblioteca",
    de: "Antrag der Bibliothek starten",
    ca: "Iniciar la sol·licitud de la biblioteca",
    eo: "Komenci la peton de la biblioteko",
    nl: "De bibliotheekaanvraag starten",
    el: "Ξεκίνα το αίτημα βιβλιοθήκης"
  },
  "welcome.libraryRequest.fallback": {
    "pt-BR": "Se o link expirar, entre em contato com a coordenação do AnarBib para receber um novo acesso.",
    fr: "Si le lien expire, contacte la coordination d'AnarBib pour recevoir un nouvel accès.",
    es: "Si el enlace expira, contactá a la coordinación de AnarBib para recibir un nuevo acceso.",
    en: "If the link expires, contact the AnarBib coordination to receive a new access.",
    it: "Se il link scade, contatta il coordinamento di AnarBib per ricevere un nuovo accesso.",
    de: "Wenn der Link abläuft, wende dich an die AnarBib-Koordination, um einen neuen Zugang zu erhalten.",
    ca: "Si l'enllaç expira, contacta la coordinació d'AnarBib per rebre un accés nou.",
    eo: "Se la ligilo eksvalidiĝas, kontaktu la kunordigon de AnarBib por ricevi novan aliron.",
    nl: "Als de link verloopt, neem dan contact op met de AnarBib-coördinatie om een nieuwe toegang te ontvangen.",
    el: "Αν ο σύνδεσμος λήξει, επικοινώνησε με τον συντονισμό του AnarBib για να λάβεις νέα πρόσβαση."
  },
  "welcome.libraryAddressLabel": {
    "pt-BR": "Endereço da biblioteca:",
    fr: "Adresse de la bibliothèque :",
    es: "Dirección de la biblioteca:",
    en: "Library address:",
    it: "Indirizzo della biblioteca:",
    de: "Adresse der Bibliothek:",
    ca: "Adreça de la biblioteca:",
    eo: "Adreso de la biblioteko:",
    nl: "Adres van de bibliotheek:",
    el: "Διεύθυνση βιβλιοθήκης:"
  },
  "welcome.libraryContactLabel": {
    "pt-BR": "Contato da biblioteca:",
    fr: "Contact de la bibliothèque :",
    es: "Contacto de la biblioteca:",
    en: "Library contact:",
    it: "Contatto della biblioteca:",
    de: "Kontakt der Bibliothek:",
    ca: "Contacte de la biblioteca:",
    eo: "Kontakto de la biblioteko:",
    nl: "Contact van de bibliotheek:",
    el: "Επαφή βιβλιοθήκης:"
  },
  "welcome.howItWorks.title": {
    "pt-BR": "Como funciona tua biblioteca",
    fr: "Comment marche ta bibliothèque",
    es: "Cómo funciona tu biblioteca",
    en: "How your library works",
    it: "Come funziona la tua biblioteca",
    de: "So funktioniert deine Bibliothek",
    ca: "Com funciona la teva biblioteca",
    eo: "Kiel funkcias via biblioteko",
    nl: "Hoe je bibliotheek werkt",
    el: "Πώς λειτουργεί η βιβλιοθήκη σου"
  },
  "welcome.howItWorks.card": {
    "pt-BR": "Vais receber uma carteira de leitor(a/e).",
    fr: "Tu recevras une carte de lecteur·rice.",
    es: "Recibirás una tarjeta de lectore.",
    en: "You'll receive a reader card.",
    it: "Riceverai una tessera di lettore/trice.",
    de: "Du erhältst einen Leser*in-Ausweis.",
    ca: "Rebràs un carnet de lector-a-e.",
    eo: "Vi ricevos legant-in-an karton.",
    nl: "Je ontvangt een lezerspas.",
    el: "Θα λάβεις κάρτα αναγνώστη/στριας."
  },
  "welcome.howItWorks.identity.remote": {
    "pt-BR": "Tua identidade de leitor(a/e) te será enviada por e-mail.",
    fr: "Ton identité de lecteur·rice te sera envoyée par e-mail.",
    es: "Tu identidad de lectore te será enviada por correo.",
    en: "Your reader identity will be sent to you by e-mail.",
    it: "La tua identità di lettore/trice ti sarà inviata via email.",
    de: "Deine Leser*in-Kennung wird dir per E-Mail zugeschickt.",
    ca: "La teva identitat de lector-a-e t'arribarà per correu electrònic.",
    eo: "Via legant-in-a identigo estos sendita al vi retpoŝte.",
    nl: "Je lezersidentiteit wordt je per e-mail toegestuurd.",
    el: "Η ταυτότητά σου ως αναγνώστη/στριας θα σου σταλεί με email."
  },
  "welcome.howItWorks.identity.presential": {
    "pt-BR": "Tua identidade de leitor(a/e) te será atribuída na tua primeira visita.",
    fr: "Ton identité de lecteur·rice te sera attribuée à ton premier passage.",
    es: "Tu identidad de lectore te será asignada en tu primera visita.",
    en: "Your reader identity will be assigned on your first visit.",
    it: "La tua identità di lettore/trice ti sarà assegnata alla tua prima visita.",
    de: "Deine Leser*in-Kennung wird dir bei deinem ersten Besuch zugewiesen.",
    ca: "La teva identitat de lector-a-e t'assignaran a la teva primera visita.",
    eo: "Via legant-in-a identigo estos atribuita al vi dum via unua vizito.",
    nl: "Je lezersidentiteit wordt toegekend bij je eerste bezoek.",
    el: "Η ταυτότητά σου ως αναγνώστη/στριας θα σου αποδοθεί στην πρώτη σου επίσκεψη."
  },
  "welcome.pending": {
    "pt-BR": "Tua inscrição precisa ser validada pela equipe: poderás pegar emprestado e reservar assim que for validada.",
    fr: "Ton inscription doit être validée par l'équipe : tu pourras emprunter et réserver une fois validée.",
    es: "Tu inscripción debe ser validada por el equipo: podrás tomar prestado y reservar una vez validada.",
    en: "Your sign-up must be validated by the team: you'll be able to borrow and reserve once validated.",
    it: "La tua iscrizione deve essere convalidata dal gruppo: potrai prendere in prestito e prenotare una volta convalidata.",
    de: "Deine Anmeldung muss vom Team bestätigt werden: sobald sie bestätigt ist, kannst du ausleihen und vormerken.",
    ca: "La teva inscripció ha de ser validada per l'equip: podràs agafar en préstec i reservar un cop validada.",
    eo: "Via aliĝo devas esti validigita de la teamo: vi povos prunti kaj rezervi post validigo.",
    nl: "Je aanmelding moet door het team worden gevalideerd: zodra dat gebeurd is, kun je lenen en reserveren.",
    el: "Η εγγραφή σου πρέπει να επικυρωθεί από την ομάδα: μόλις επικυρωθεί, θα μπορείς να δανείζεσαι και να κρατάς."
  },
  "welcome.autoMessage": {
    "pt-BR": "Mensagem automática do cadastro AnarBib. As respostas a este e-mail serão encaminhadas para a gestão do projeto.",
    fr: "Message automatique de l'inscription AnarBib. Les réponses à cet e-mail sont transmises à la gestion du projet.",
    es: "Mensaje automático del registro AnarBib. Las respuestas a este correo serán reenviadas a la gestión del proyecto.",
    en: "Automatic message from the AnarBib registration. Replies to this email are forwarded to the project management.",
    it: "Messaggio automatico dell'iscrizione AnarBib. Le risposte a questa e-mail vengono inoltrate alla gestione del progetto.",
    de: "Automatische Nachricht der AnarBib-Anmeldung. Antworten auf diese E-Mail werden an die Projektleitung weitergeleitet.",
    ca: "Missatge automàtic de la inscripció AnarBib. Les respostes a aquest correu es transmeten a la gestió del projecte.",
    eo: "Aŭtomata mesaĝo de la registriĝo AnarBib. La respondoj al ĉi tiu retpoŝto estas plusenditaj al la projektmastrumado.",
    nl: "Automatisch bericht van de AnarBib-inschrijving. Antwoorden op deze e-mail worden doorgestuurd naar het projectbeheer.",
    el: "Αυτόματο μήνυμα από την εγγραφή στο AnarBib. Οι απαντήσεις σε αυτό το email προωθούνται στη διαχείριση του εγχειρήματος."
  },
  // ===== Paquet 6 criar-conta — mail welcome-reader-orphan (welcome.*.orphan) =
  "welcome.pretitle.orphan": {
    "pt-BR": "Conta criada",
    fr: "Compte créé",
    es: "Cuenta creada",
    en: "Account created",
    it: "Account creato",
    de: "Konto erstellt",
    ca: "Compte creat",
    eo: "Konto kreita",
    nl: "Account aangemaakt",
    el: "Ο λογαριασμός δημιουργήθηκε"
  },
  "welcome.title.orphan": {
    "pt-BR": "Bem-vind-a-e ao AnarBib",
    fr: "Bienvenue dans le réseau AnarBib",
    es: "Bienvenide a la red AnarBib",
    en: "Welcome to the AnarBib network",
    it: "Benvenut* nella rete AnarBib",
    de: "Willkommen im AnarBib-Netzwerk",
    ca: "Benvingut-da-e a la xarxa AnarBib",
    eo: "Bonvenon en la reton AnarBib",
    nl: "Welkom bij het AnarBib-netwerk",
    el: "Καλώς όρισες στο δίκτυο AnarBib"
  },
  "welcome.subject.orphan": {
    "pt-BR": "Sua conta no AnarBib foi criada",
    fr: "Ton compte AnarBib a été créé",
    es: "Tu cuenta de AnarBib fue creada",
    en: "Your AnarBib account has been created",
    it: "Il tuo account AnarBib è stato creato",
    de: "Dein AnarBib-Konto wurde erstellt",
    ca: "El teu compte d'AnarBib s'ha creat",
    eo: "Via konto ĉe AnarBib estis kreita",
    nl: "Je AnarBib-account is aangemaakt",
    el: "Ο λογαριασμός σου στο AnarBib δημιουργήθηκε"
  },
  "welcome.context.orphan": {
    "pt-BR": "Sua conta foi criada. Como você nos indicou, sua biblioteca ainda não está na rede AnarBib. Fale do AnarBib com a equipe da sua biblioteca: se essa decidir aderir, você poderá ser integrad-a-e como leitor-a-e com a mesma conta que acaba de criar. Enquanto isso, você pode explorar livremente os catálogos das bibliotecas que escolheram torná-los públicos.",
    fr: "Ton compte a été créé. Comme tu nous l'as indiqué, ta bibliothèque n'est pas encore dans le réseau AnarBib. Parle d'AnarBib à l'équipe de ta bibliothèque : si elle décide d'adhérer, tu pourras y être intégré·e comme lecteur·rice avec le compte que tu viens de créer. En attendant, tu peux explorer librement les catalogues des bibliothèques qui ont choisi de les rendre publics.",
    es: "Tu cuenta fue creada. Como nos indicaste, tu biblioteca todavía no está en la red AnarBib. Hablá de AnarBib con el equipo de tu biblioteca: si este decide sumarse, vas a poder ser integrade como lectore con la misma cuenta que acabás de crear. Mientras tanto, podés explorar libremente los catálogos de las bibliotecas que eligieron hacerlos públicos.",
    en: "Your account has been created. As you told us, your library is not yet part of the AnarBib network. Talk about AnarBib with your library's team: if it decides to join, you'll be able to be added as a reader with the same account you've just created. In the meantime, you can freely explore the catalogues of the libraries that have chosen to make them public.",
    it: "Il tuo account è stato creato. Come ci hai indicato, la tua biblioteca non fa ancora parte della rete AnarBib. Parla di AnarBib con l'équipe della tua biblioteca: se questa decide di aderire, potrai essere integrat* come lettore* con lo stesso account che hai appena creato. Nel frattempo, puoi esplorare liberamente i cataloghi delle biblioteche che hanno scelto di renderli pubblici.",
    de: "Dein Konto wurde erstellt. Wie du uns mitgeteilt hast, gehört deine Bibliothek noch nicht zum AnarBib-Netzwerk. Sprich mit dem Team deiner Bibliothek über AnarBib: wenn es sich entscheidet beizutreten, kannst du als Leser*in mit demselben Konto, das du gerade erstellt hast, aufgenommen werden. In der Zwischenzeit kannst du die Kataloge der Bibliotheken, die sie öffentlich gemacht haben, frei durchstöbern.",
    ca: "El teu compte s'ha creat. Tal com ens vas indicar, la teva biblioteca encara no forma part de la xarxa AnarBib. Parla d'AnarBib amb l'equip de la teva biblioteca: si aquest decideix adherir-s'hi, podràs ser integrat-da-e com a lector-a-e amb el mateix compte que acabes de crear. Mentrestant, pots explorar lliurement els catàlegs de les biblioteques que han decidit fer-los públics.",
    eo: "Via konto estis kreita. Kiel vi indikis al ni, via biblioteko ankoraŭ ne apartenas al la reto AnarBib. Parolu pri AnarBib kun la teamo de via biblioteko: se ĝi decidas aliĝi, vi povos esti integrit-in-e kiel legant-in-e per la sama konto kiun vi ĵus kreis. Dume, vi povas libere esplori la katalogojn de la bibliotekoj kiuj elektis publikigi ilin.",
    nl: "Je account is aangemaakt. Zoals je ons hebt aangegeven, maakt je bibliotheek nog geen deel uit van het AnarBib-netwerk. Praat over AnarBib met het team van je bibliotheek: als die besluit toe te treden, kun je als lezer worden toegevoegd met hetzelfde account dat je net hebt aangemaakt. In de tussentijd kun je vrij de catalogi verkennen van de bibliotheken die ervoor hebben gekozen ze openbaar te maken.",
    el: "Ο λογαριασμός σου δημιουργήθηκε. Όπως μας ανέφερες, η βιβλιοθήκη σου δεν είναι ακόμη μέρος του δικτύου AnarBib. Μίλησε για το AnarBib στην ομάδα της βιβλιοθήκης σου: αν αποφασίσει να ενταχθεί, θα μπορέσεις να προστεθείς ως αναγνώστης/στρια με τον ίδιο λογαριασμό που μόλις δημιούργησες. Στο μεταξύ, μπορείς να εξερευνήσεις ελεύθερα τους καταλόγους των βιβλιοθηκών που επέλεξαν να τους κάνουν δημόσιους."
  },
  "welcome.orphan.exploreCta": {
    "pt-BR": "→ Explorar os catálogos",
    fr: "→ Explorer les catalogues",
    es: "→ Explorar los catálogos",
    en: "→ Explore the catalogues",
    it: "→ Esplora i cataloghi",
    de: "→ Kataloge durchstöbern",
    ca: "→ Explorar els catàlegs",
    eo: "→ Esplori la katalogojn",
    nl: "→ Verken de catalogi",
    el: "→ Εξερεύνησε τους καταλόγους"
  },
  "welcome.orphan.aboutIntro": {
    "pt-BR": "Para saber mais sobre o projeto AnarBib e como sua biblioteca pode aderir, acesse:",
    fr: "Pour en savoir plus sur le projet AnarBib et comment ta bibliothèque peut adhérer, rends-toi sur :",
    es: "Para saber más sobre el proyecto AnarBib y cómo tu biblioteca puede sumarse, entrá en:",
    en: "To learn more about the AnarBib project and how your library can join, go to:",
    it: "Per saperne di più sul progetto AnarBib e su come la tua biblioteca può aderire, vai su:",
    de: "Um mehr über das AnarBib-Projekt zu erfahren und wie deine Bibliothek beitreten kann, geh auf:",
    ca: "Per saber-ne més sobre el projecte AnarBib i com pot adherir-s'hi la teva biblioteca, vés a:",
    eo: "Por scii pli pri la projekto AnarBib kaj kiel via biblioteko povas aliĝi, iru al:",
    nl: "Wil je meer weten over het AnarBib-project en hoe je bibliotheek kan toetreden, ga dan naar:",
    el: "Για να μάθεις περισσότερα για το εγχείρημα AnarBib και πώς μπορεί να ενταχθεί η βιβλιοθήκη σου, πήγαινε στο:"
  },
  "welcome.orphan.fallback": {
    "pt-BR": "Se o botão não funcionar, copie este endereço no seu navegador:",
    fr: "Si le bouton ne fonctionne pas, copie cette adresse dans ton navigateur :",
    es: "Si el botón no funciona, copiá esta dirección en tu navegador:",
    en: "If the button doesn't work, copy this address into your browser:",
    it: "Se il pulsante non funziona, copia questo indirizzo nel tuo browser:",
    de: "Wenn der Button nicht funktioniert, kopiere diese Adresse in deinen Browser:",
    ca: "Si el botó no funciona, copia aquesta adreça al teu navegador:",
    eo: "Se la butono ne funkcias, kopiu ĉi tiun adreson en vian retumilon:",
    nl: "Werkt de knop niet, kopieer dan dit adres in je browser:",
    el: "Αν το κουμπί δεν λειτουργεί, αντίγραψε αυτή τη διεύθυνση στο πρόγραμμα περιήγησής σου:"
  },

// ============================================================================
// Paquet E.1 — Bloc i18n à insérer dans mail-strings.ts
// ============================================================================
// 6 events × 6 locales (pt-BR, fr, es, en, it, de)
// Conventions militantes strictes par locale (cf. en-tête mail-strings.ts) :
//   pt-BR : triple o/a/e, d(o/a/e), dest(e/a)
//   fr    : point médian (lecteur·rice, le·la)
//   es    : neutre argentin (le, les, une, conectade)
//   en    : neutre standard épicène
//   it    : compagn*
//   de    : Genderstern (Leser*in, Genoss*in)
// Adresse : vouvoiement neutre (vos / votre / your / ihr·e / usted / vostro / Sie)
//
// Granularité par event :
//   - network.cooptation_reminder       : .sub .intro .cta .deadline_label
//   - network.collective_removal_proposed : .sub .intro .cta .motivation_label
//   - network.collective_removal_vote_cast : .sub .intro .rationale_label
//   - network.collective_removal_unanimous : .sub .intro .carence_label .target_intro
//   - network.collective_removal_cancelled : .sub .intro
//   - network.collective_removal_executed  : .sub .intro .target_intro
//
// Placeholders standard utilisés :
//   {proposedName}    nom de la personne proposée (cooptation) ou ciblée (retrait)
//   {proposerName}    nom de la personne qui propose
//   {voterName}       nom du votant (peut être "Pessoa anônima" si non-disclose)
//   {voteKind}        favor / against (déjà traduit côté EF avant insertion)
//   {pendingDeadline} date lisible pour fin de carence ou fin de fenêtre
// ============================================================================

  // ===== network.cooptation_reminder ========================================
  // Rappel J+14 ou J+25 envoyé aux admins n'ayant pas voté.
  // Edge Function : choisira le bon variant via payload.reminder_kind ('j14'|'j25')
  // et préfixera le sujet par "[J+14]" ou "[J+25]" si pertinent.
  "network.cooptation_reminder.proposer_intro": {
    "pt-BR": "Olá, {proposerName}. Sua proposta de cooptação de {targetName} ainda não recebeu votos suficientes. A proposta expira em {expiresAt}. Você pode acompanhar o andamento na sua área de administração.",
    fr: "Bonjour {proposerName}. Ta proposition de cooptation de {targetName} n'a pas encore recueilli assez de votes. La proposition expire le {expiresAt}. Tu peux suivre son avancement dans ton espace d'administration.",
    es: "Hola, {proposerName}. Tu propuesta de cooptación de {targetName} todavía no ha recibido suficientes votos. La propuesta expira el {expiresAt}. Podés seguir su avance en tu área de administración.",
    en: "Hello {proposerName}. Your cooptation proposal for {targetName} hasn't gathered enough votes yet. The proposal expires on {expiresAt}. You can follow its progress in your admin area.",
    it: "Ciao {proposerName}. La tua proposta di cooptazione di {targetName} non ha ancora raccolto abbastanza voti. La proposta scade il {expiresAt}. Puoi seguirne l'avanzamento nella tua area di amministrazione.",
    de: "Hallo {proposerName}. Dein Kooptationsvorschlag für {targetName} hat noch nicht genug Stimmen gesammelt. Der Vorschlag läuft am {expiresAt} ab. Du kannst den Verlauf in deinem Administrationsbereich verfolgen.",
    ca: "Hola, {proposerName}. La teva proposta de cooptació de {targetName} encara no ha rebut prou vots. La proposta expira el {expiresAt}. Pots seguir-ne l'evolució a la teva àrea d'administració.",
    eo: "Saluton, {proposerName}. Via kooptad-propono pri {targetName} ankoraŭ ne ricevis sufiĉe da voĉdonoj. La propono eksvalidiĝas la {expiresAt}. Vi povas sekvi ĝian progreson en via administra spaco.",
    nl: "Hallo {proposerName}. Je coöptatievoorstel voor {targetName} heeft nog niet genoeg stemmen verzameld. Het voorstel verloopt op {expiresAt}. Je kunt de voortgang volgen in je beheerruimte.",
    el: "Γεια σου {proposerName}. Η πρότασή σου για κοόπτηση του/της {targetName} δεν έχει συγκεντρώσει ακόμη αρκετές ψήφους. Η πρόταση λήγει στις {expiresAt}. Μπορείς να παρακολουθείς την πρόοδό της στον χώρο διαχείρισής σου."
  },
  "network.cooptation_reminder.sub": {
    "pt-BR": "Lembrete : votação pendente sobre a cooptação de {proposedName}",
    fr: "Rappel · vote en attente sur la cooptation de {proposedName}",
    es: "Recordatorio · votación pendiente sobre la cooptación de {proposedName}",
    en: "Reminder · pending vote on the cooptation of {proposedName}",
    it: "Promemoria · voto in sospeso sulla cooptazione di {proposedName}",
    de: "Erinnerung · ausstehende Abstimmung zur Kooptation von {proposedName}",
    ca: "Recordatori · votació pendent sobre la cooptació de {proposedName}",
    eo: "Memorigo · atendanta voĉdono pri la kooptado de {proposedName}",
    nl: "Herinnering · stem in afwachting over de coöptatie van {proposedName}",
    el: "Υπενθύμιση · εκκρεμεί ψήφος για την κοόπτηση του/της {proposedName}"
  },
  "network.cooptation_reminder.intro": {
    "pt-BR": "Uma proposta de cooptação foi aberta há vários dias e ainda aguarda vossa decisão. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s é necessária para concluir o processo.",
    fr: "Une proposition de cooptation a été ouverte il y a plusieurs jours et attend encore votre décision. L'unanimité des administrateur·rices actif·ves est nécessaire pour conclure le processus.",
    es: "Una propuesta de cooptación fue abierta hace varios días y aún espera vuestra decisión. La unanimidad de les administradores activos es necesaria para cerrar el proceso.",
    en: "A cooptation proposal was opened several days ago and is still awaiting your decision. Unanimity among active network administrators is required to complete the process.",
    it: "Una proposta di cooptazione è stata aperta diversi giorni fa e attende ancora la vostra decisione. L'unanimità dei compagn* amministratori/trici attiv* è necessaria per concludere il processo.",
    de: "Ein Kooptationsvorschlag wurde vor mehreren Tagen eröffnet und wartet noch auf Ihre Entscheidung. Einstimmigkeit der aktiven Netzwerk-Administrator*innen ist erforderlich, um den Prozess abzuschließen.",
    ca: "S'ha obert una proposta de cooptació fa diversos dies i encara espera la vostra decisió. La unanimitat de les administradores actives és necessària per concloure el procés.",
    eo: "Kooptad-propono estis malfermita antaŭ pluraj tagoj kaj ankoraŭ atendas vian decidon. La unuanimeco de la aktivaj administrant-in-oj estas necesa por konkludi la procezon.",
    nl: "Een coöptatievoorstel is enkele dagen geleden geopend en wacht nog op je beslissing. Unanimiteit onder de actieve netwerkbeheerders is vereist om het proces af te ronden.",
    el: "Μια πρόταση κοόπτησης άνοιξε πριν αρκετές ημέρες και αναμένει ακόμη την απόφασή σας. Απαιτείται ομοφωνία των ενεργών διαχειριστών/στριών του δικτύου για να ολοκληρωθεί η διαδικασία."
  },
  "network.cooptation_reminder.cta": {
    "pt-BR": "Acessar a proposta e votar",
    fr: "Accéder à la proposition et voter",
    es: "Acceder a la propuesta y votar",
    en: "Open the proposal and vote",
    it: "Accedere alla proposta e votare",
    de: "Vorschlag öffnen und abstimmen",
    ca: "Accedir a la proposta i votar",
    eo: "Aliri la proponon kaj voĉdoni",
    nl: "Open het voorstel en stem",
    el: "Άνοιξε την πρόταση και ψήφισε"
  },
  "network.cooptation_reminder.deadline_label": {
    "pt-BR": "A proposta expira em {pendingDeadline}.",
    fr: "La proposition expire le {pendingDeadline}.",
    es: "La propuesta expira el {pendingDeadline}.",
    en: "The proposal expires on {pendingDeadline}.",
    it: "La proposta scade il {pendingDeadline}.",
    de: "Der Vorschlag läuft am {pendingDeadline} ab.",
    ca: "La proposta expira el {pendingDeadline}.",
    eo: "La propono eksvalidiĝas la {pendingDeadline}.",
    nl: "Het voorstel verloopt op {pendingDeadline}.",
    el: "Η πρόταση λήγει στις {pendingDeadline}."
  },

  // ===== network.request_eval_digest (#111 — digest d'évaluation des demandes) =====
  "network.request_eval_digest.sub": {
    "pt-BR": "Avaliação de solicitações — ação necessária",
    fr: "Évaluation des demandes — action requise",
    es: "Evaluación de solicitudes — acción necesaria",
    en: "Membership requests — action needed",
    it: "Valutazione delle richieste — azione necessaria",
    de: "Bewertung der Anträge — Aktion erforderlich",
    ca: "Avaluació de sol·licituds — acció necessària",
    eo: "Pritakso de petoj — ago necesa",
    nl: "Beoordeling van aanvragen — actie nodig",
    el: "Αξιολόγηση αιτημάτων — απαιτείται ενέργεια"
  },
  "network.request_eval_digest.intro_proposal": {
    "pt-BR": "Uma proposta de decisão sobre uma solicitação de adesão aguarda vosso voto. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s da rede é necessária.",
    fr: "Une proposition de décision sur une demande d'adhésion attend votre vote. L'unanimité des administrateur·rices réseau actif·ves est requise.",
    es: "Una propuesta de decisión sobre una solicitud de adhesión espera vuestro voto. Se requiere la unanimidad de les administradores activos de la red.",
    en: "A decision proposal on a membership request is awaiting your vote. Unanimity among active network administrators is required.",
    it: "Una proposta di decisione su una richiesta di adesione attende il vostro voto. È necessaria l'unanimità degli amministratori/trici attiv* della rete.",
    de: "Ein Entscheidungsvorschlag zu einem Aufnahmeantrag wartet auf Ihre Stimme. Einstimmigkeit der aktiven Netzwerk-Administrator*innen ist erforderlich.",
    ca: "Una proposta de decisió sobre una sol·licitud d'adhesió espera el vostre vot. Cal la unanimitat de les administradores actives de la xarxa.",
    eo: "Decid-propono pri aliĝpeto atendas vian voĉdonon. Necesas la unuanimeco de la aktivaj retaj administrant-in-oj.",
    nl: "Een beslissingsvoorstel over een toetredingsaanvraag wacht op je stem. Unanimiteit onder de actieve netwerkbeheerders is vereist.",
    el: "Μια πρόταση απόφασης για ένα αίτημα ένταξης αναμένει την ψήφο σας. Απαιτείται ομοφωνία των ενεργών διαχειριστών/στριών του δικτύου."
  },
  "network.request_eval_digest.intro_backlog": {
    "pt-BR": "{count} solicitação(ões) de adesão aguardam avaliação pela coordenação da rede.",
    fr: "{count} demande·s d'adhésion attendent une évaluation par la coordination du réseau.",
    es: "{count} solicitud·es de adhesión esperan evaluación por la coordinación de la red.",
    en: "{count} membership request(s) are awaiting evaluation by the network coordination.",
    it: "{count} richiesta/e di adesione attendono una valutazione da parte della coordinazione della rete.",
    de: "{count} Aufnahmeantrag/-anträge warten auf eine Bewertung durch die Netzwerkkoordination.",
    ca: "{count} sol·licitud·s d'adhesió esperen una avaluació per la coordinació de la xarxa.",
    eo: "{count} aliĝpeto(j) atendas pritakson de la reta kunordigado.",
    nl: "{count} toetredingsaanvraag/-aanvragen wachten op beoordeling door de netwerkcoördinatie.",
    el: "{count} αίτημα(τα) ένταξης αναμένουν αξιολόγηση από τον συντονισμό του δικτύου."
  },
  "network.request_eval_digest.cta": {
    "pt-BR": "Abrir o painel de rede",
    fr: "Ouvrir le panneau réseau",
    es: "Abrir el panel de red",
    en: "Open the network panel",
    it: "Aprire il pannello di rete",
    de: "Netzwerk-Panel öffnen",
    ca: "Obrir el tauler de xarxa",
    eo: "Malfermi la retan panelon",
    nl: "Het netwerkpaneel openen",
    el: "Άνοιγμα του πίνακα δικτύου"
  },

  // ===== network.collective_removal_proposed ================================
  // Envoyé aux autres admins actifs (hors proposeur, hors target).
  // Le target n'est pas notifié à cette étape (doctrine v0.3 §Q5).
  "network.collective_removal_proposed.sub": {
    "pt-BR": "Proposta de retirada coletiva : {proposedName}",
    fr: "Proposition de retrait collectif · {proposedName}",
    es: "Propuesta de retiro colectivo · {proposedName}",
    en: "Collective removal proposal · {proposedName}",
    it: "Proposta di ritiro collettivo · {proposedName}",
    de: "Vorschlag eines kollektiven Rückzugs · {proposedName}",
    ca: "Proposta de retirada col·lectiva · {proposedName}",
    eo: "Propono de kolektiva forigo · {proposedName}",
    nl: "Voorstel tot collectieve afzetting · {proposedName}",
    el: "Πρόταση συλλογικής απομάκρυνσης · {proposedName}"
  },
  "network.collective_removal_proposed.intro": {
    "pt-BR": "{proposerName} abriu uma proposta de retirada coletiva d(o/a/e) administrador(a/e) {proposedName}. Esta é uma decisão política grave que exige unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s (excluíd(o/a/e) (o/a/e) próprio(a/e) target). Vosso voto é necessário.",
    fr: "{proposerName} a ouvert une proposition de retrait collectif de l'administrateur·rice {proposedName}. Il s'agit d'une décision politique grave qui requiert l'unanimité des administrateur·rices actif·ves (à l'exclusion de la personne ciblée). Votre vote est nécessaire.",
    es: "{proposerName} abrió una propuesta de retiro colectivo de le administrade {proposedName}. Es una decisión política grave que exige la unanimidad de les administradores activos (excluide le propie target). Vuestro voto es necesario.",
    en: "{proposerName} has opened a proposal for the collective removal of network administrator {proposedName}. This is a serious political decision requiring unanimity among active administrators (excluding the target). Your vote is needed.",
    it: "{proposerName} ha aperto una proposta di ritiro collettivo dell'amministratore/trice {proposedName}. È una decisione politica grave che richiede l'unanimità dei compagn* amministratori/trici attiv* (esclu* (il/la/le) compagn* oggetto). Il vostro voto è necessario.",
    de: "{proposerName} hat einen Vorschlag zum kollektiven Rückzug von Netzwerk-Administrator*in {proposedName} eröffnet. Dies ist eine schwerwiegende politische Entscheidung, die die Einstimmigkeit der aktiven Administrator*innen erfordert (ausgenommen die betroffene Person). Ihre Stimme ist erforderlich.",
    ca: "{proposerName} ha obert una proposta de retirada col·lectiva de l'administrador-a-e {proposedName}. Es tracta d'una decisió política greu que requereix la unanimitat de les administradores actives (excloent la persona objecte de la proposta). El vostre vot és necessari.",
    eo: "{proposerName} malfermis proponon de kolektiva forigo de la administrant-in-o {proposedName}. Temas pri grava politika decido kiu postulas la unuanimecon de la aktivaj administrant-in-oj (escepte de la celata persono). Via voĉdono estas necesa.",
    nl: "{proposerName} heeft een voorstel geopend tot collectieve afzetting van netwerkbeheerder {proposedName}. Dit is een ernstige politieke beslissing die unanimiteit vereist onder de actieve beheerders (met uitzondering van de betrokken persoon). Je stem is nodig.",
    el: "Ο/Η {proposerName} άνοιξε πρόταση συλλογικής απομάκρυνσης του/της διαχειριστή/στριας δικτύου {proposedName}. Πρόκειται για σοβαρή πολιτική απόφαση που απαιτεί ομοφωνία των ενεργών διαχειριστών/στριών (εξαιρουμένου/ης του/της εμπλεκόμενου/ης). Η ψήφος σας είναι απαραίτητη."
  },
  "network.collective_removal_proposed.cta": {
    "pt-BR": "Acessar a proposta e votar",
    fr: "Accéder à la proposition et voter",
    es: "Acceder a la propuesta y votar",
    en: "Open the proposal and vote",
    it: "Accedere alla proposta e votare",
    de: "Vorschlag öffnen und abstimmen",
    ca: "Accedir a la proposta i votar",
    eo: "Aliri la proponon kaj voĉdoni",
    nl: "Open het voorstel en stem",
    el: "Άνοιξε την πρόταση και ψήφισε"
  },
  "network.collective_removal_proposed.motivation_label": {
    "pt-BR": "Motivação invocada :",
    fr: "Motivation invoquée :",
    es: "Motivación invocada :",
    en: "Stated motivation:",
    it: "Motivazione invocata :",
    de: "Angegebene Begründung:",
    ca: "Motivació invocada:",
    eo: "Invokita motivo:",
    nl: "Aangevoerde motivatie:",
    el: "Αιτιολόγηση που προβλήθηκε:"
  },

  // ===== network.collective_removal_vote_cast ===============================
  // Envoyé aux autres admins actifs après chaque vote intermédiaire
  // (hors votant, hors target).
  // payload.voter_user_id peut être NULL si disclose_identity=false côté DB :
  // dans ce cas, l'Edge Function substituera {voterName} par une chaîne neutre.
  "network.collective_removal_vote_cast.sub": {
    "pt-BR": "Voto registrado : retirada coletiva de {proposedName}",
    fr: "Vote enregistré · retrait collectif de {proposedName}",
    es: "Voto registrado · retiro colectivo de {proposedName}",
    en: "Vote registered · collective removal of {proposedName}",
    it: "Voto registrato · ritiro collettivo di {proposedName}",
    de: "Stimme registriert · kollektiver Rückzug von {proposedName}",
    ca: "Vot registrat · retirada col·lectiva de {proposedName}",
    eo: "Voĉdono registrita · kolektiva forigo de {proposedName}",
    nl: "Stem geregistreerd · collectieve afzetting van {proposedName}",
    el: "Ψήφος καταχωρίστηκε · συλλογική απομάκρυνση του/της {proposedName}"
  },
  "network.collective_removal_vote_cast.intro": {
    "pt-BR": "Um(a/e) administrador(a/e) de rede acaba de votar sobre a proposta de retirada coletiva d(o/a/e) administrador(a/e) {proposedName}, aberta por {proposerName}. Acessai a app para ver o estado atual da deliberação e votar.",
    fr: "Un·e administrateur·rice du réseau vient de voter sur la proposition de retrait collectif de l'administrateur·rice {proposedName}, ouverte par {proposerName}. Accédez à l'app pour voir l'état actuel de la délibération et voter.",
    es: "Une administrade de red acaba de votar sobre la propuesta de retiro colectivo de le administrade {proposedName}, abierta por {proposerName}. Accedé a la app para ver el estado actual de la deliberación y votar.",
    en: "A network administrator has just cast a vote on the collective removal proposal of administrator {proposedName}, opened by {proposerName}. Open the app to see the current state of the deliberation and vote.",
    it: "Un compagn* amministratore/trice di rete ha appena votato sulla proposta di ritiro collettivo dell'amministratore/trice {proposedName}, aperta da {proposerName}. Accedi all'app per vedere lo stato attuale della deliberazione e votare.",
    de: "Ein*e Netzwerk-Administrator*in hat soeben über den Vorschlag eines kollektiven Rückzugs von Administrator*in {proposedName} abgestimmt, eröffnet von {proposerName}. Öffnen Sie die App, um den aktuellen Stand der Beratung zu sehen und abzustimmen.",
    ca: "Una administradora de xarxa acaba de votar sobre la proposta de retirada col·lectiva de l'administrador-a-e {proposedName}, oberta per {proposerName}. Accediu a l'aplicació per veure l'estat actual de la deliberació i votar.",
    eo: "Reta administrant-in-o ĵus voĉdonis pri la propono de kolektiva forigo de la administrant-in-o {proposedName}, malfermita de {proposerName}. Aliru la aplikaĵon por vidi la nunan staton de la pridiskuto kaj voĉdoni.",
    nl: "Een netwerkbeheerder heeft zojuist gestemd over het voorstel tot collectieve afzetting van beheerder {proposedName}, geopend door {proposerName}. Open de app om de huidige stand van de beraadslaging te zien en te stemmen.",
    el: "Ένας/Μία διαχειριστής/στρια του δικτύου μόλις ψήφισε για την πρόταση συλλογικής απομάκρυνσης του/της διαχειριστή/στριας {proposedName}, που άνοιξε ο/η {proposerName}. Ανοίξτε την εφαρμογή για να δείτε την τρέχουσα κατάσταση της διαβούλευσης και να ψηφίσετε."
  },
  "network.collective_removal_vote_cast.rationale_label": {
    "pt-BR": "Motivo do voto contrário :",
    fr: "Motif du vote défavorable :",
    es: "Motivo del voto contrario :",
    en: "Reason for opposing vote:",
    it: "Motivo del voto contrario :",
    de: "Begründung der Ablehnung:",
    ca: "Motiu del vot contrari:",
    eo: "Motivo de la kontraŭa voĉdono:",
    nl: "Reden voor de tegenstem:",
    el: "Λόγος αρνητικής ψήφου:"
  },

  // ===== network.collective_removal_unanimous ===============================
  // Envoyé à TOUS les admins actifs (target inclus) au moment où l'unanimité
  // est atteinte. Déclenche les 7 jours de carence avant exécution.
  // L'Edge Function adaptera l'intro selon que le destinataire est le target
  // ou un autre admin (variante .target_intro).
  "network.collective_removal_unanimous.sub": {
    "pt-BR": "Retirada coletiva confirmada por unanimidade : {proposedName} — carência de 7 dias",
    fr: "Retrait collectif confirmé à l'unanimité · {proposedName} — carence de 7 jours",
    es: "Retiro colectivo confirmado por unanimidad · {proposedName} — período de gracia de 7 días",
    en: "Collective removal confirmed by unanimity · {proposedName} — 7-day grace period",
    it: "Ritiro collettivo confermato all'unanimità · {proposedName} — periodo di grazia di 7 giorni",
    de: "Kollektiver Rückzug einstimmig bestätigt · {proposedName} — 7-tägige Karenzfrist",
    ca: "Retirada col·lectiva confirmada per unanimitat · {proposedName} — termini de gràcia de 7 dies",
    eo: "Kolektiva forigo konfirmita unuanime · {proposedName} — grac-periodo de 7 tagoj",
    nl: "Collectieve afzetting unaniem bevestigd · {proposedName} — respijtperiode van 7 dagen",
    el: "Συλλογική απομάκρυνση επιβεβαιώθηκε με ομοφωνία · {proposedName} — περίοδος χάριτος 7 ημερών"
  },
  "network.collective_removal_unanimous.intro": {
    "pt-BR": "A unanimidade d(o/a/e)s administrador(a/e)s foi alcançada sobre a retirada coletiva d(o/a/e) {proposedName}. Uma carência de 7 dias se aplica antes da efetivação. Durante este período, qualquer votante pode anular a decisão se houver mudança de posição coletiva.",
    fr: "L'unanimité des administrateur·rices a été atteinte sur le retrait collectif de {proposedName}. Une carence de 7 jours s'applique avant exécution. Pendant cette période, tout·e votant·e peut annuler la décision en cas de changement de position collective.",
    es: "Se alcanzó la unanimidad de les administradores sobre el retiro colectivo de {proposedName}. Se aplica un período de gracia de 7 días antes de la ejecución. Durante este período, cualquier votante puede anular la decisión si hay un cambio de posición colectiva.",
    en: "Unanimity among network administrators has been reached on the collective removal of {proposedName}. A 7-day grace period applies before execution. During this period, any voter may cancel the decision if the collective position changes.",
    it: "L'unanimità dei compagn* amministratori/trici è stata raggiunta sul ritiro collettivo di {proposedName}. Si applica un periodo di grazia di 7 giorni prima dell'esecuzione. Durante questo periodo, qualsiasi votante può annullare la decisione in caso di cambiamento di posizione collettiva.",
    de: "Einstimmigkeit der Netzwerk-Administrator*innen über den kollektiven Rückzug von {proposedName} wurde erreicht. Eine 7-tägige Karenzfrist gilt vor der Vollziehung. Während dieser Frist kann jede*r Abstimmende die Entscheidung aufheben, falls sich die kollektive Position ändert.",
    ca: "S'ha assolit la unanimitat de les administradores sobre la retirada col·lectiva de {proposedName}. S'aplica un termini de gràcia de 7 dies abans de l'execució. Durant aquest període, qualsevol votant pot anul·lar la decisió si hi ha un canvi de posició col·lectiva.",
    eo: "La unuanimeco de la administrant-in-oj estis atingita pri la kolektiva forigo de {proposedName}. Grac-periodo de 7 tagoj validas antaŭ la plenumo. Dum ĉi tiu periodo, ĉiu voĉdoninto povas nuligi la decidon en kazo de ŝanĝo de kolektiva pozicio.",
    nl: "Onder de netwerkbeheerders is unanimiteit bereikt over de collectieve afzetting van {proposedName}. Vóór uitvoering geldt een respijtperiode van 7 dagen. Tijdens deze periode kan elke stemmer de beslissing annuleren als het collectieve standpunt verandert.",
    el: "Επιτεύχθηκε ομοφωνία των διαχειριστών/στριών του δικτύου για τη συλλογική απομάκρυνση του/της {proposedName}. Ισχύει περίοδος χάριτος 7 ημερών πριν την εκτέλεση. Σε αυτό το διάστημα, κάθε ψηφοφόρος μπορεί να ακυρώσει την απόφαση αν αλλάξει η συλλογική θέση."
  },
  "network.collective_removal_unanimous.target_intro": {
    "pt-BR": "Esta mensagem informa que a unanimidade d(o/a/e)s outr(o/a/e)s administrador(a/e)s ativ(o/a/e)s foi alcançada sobre a vossa retirada coletiva. Uma carência de 7 dias se aplica antes da efetivação. Vossa palavra é livre durante esta janela.",
    fr: "Ce message vous informe que l'unanimité des autres administrateur·rices actif·ves a été atteinte sur votre retrait collectif. Une carence de 7 jours s'applique avant exécution. Votre parole est libre durant cette fenêtre.",
    es: "Este mensaje le informa que se alcanzó la unanimidad de les otres administradores activos sobre vuestro retiro colectivo. Se aplica un período de gracia de 7 días antes de la ejecución. Vuestra palabra es libre durante esta ventana.",
    en: "This message informs you that unanimity among the other active network administrators has been reached regarding your collective removal. A 7-day grace period applies before execution. Your voice remains free during this window.",
    it: "Questo messaggio vi informa che l'unanimità degli/delle altr* compagn* amministratori/trici attiv* è stata raggiunta sul vostro ritiro collettivo. Si applica un periodo di grazia di 7 giorni prima dell'esecuzione. La vostra parola resta libera durante questa finestra.",
    de: "Diese Nachricht informiert Sie darüber, dass die Einstimmigkeit der anderen aktiven Netzwerk-Administrator*innen über Ihren kollektiven Rückzug erreicht wurde. Eine 7-tägige Karenzfrist gilt vor der Vollziehung. Ihr Wort bleibt frei während dieses Zeitraums.",
    ca: "Aquest missatge us informa que s'ha assolit la unanimitat de les altres administradores actives sobre la vostra retirada col·lectiva. S'aplica un termini de gràcia de 7 dies abans de l'execució. La vostra paraula és lliure durant aquesta finestra.",
    eo: "Ĉi tiu mesaĝo informas vin ke la unuanimeco de la aliaj aktivaj administrant-in-oj estis atingita pri via kolektiva forigo. Grac-periodo de 7 tagoj validas antaŭ la plenumo. Via parolo estas libera dum ĉi tiu fenestro.",
    nl: "Dit bericht informeert je dat onder de andere actieve netwerkbeheerders unanimiteit is bereikt over je collectieve afzetting. Vóór uitvoering geldt een respijtperiode van 7 dagen. Je stem blijft vrij tijdens dit venster.",
    el: "Αυτό το μήνυμα σάς ενημερώνει ότι επιτεύχθηκε ομοφωνία μεταξύ των άλλων ενεργών διαχειριστών/στριών του δικτύου σχετικά με τη συλλογική σας απομάκρυνση. Ισχύει περίοδος χάριτος 7 ημερών πριν την εκτέλεση. Ο λόγος σας παραμένει ελεύθερος σε αυτό το διάστημα."
  },
  "network.collective_removal_unanimous.carence_label": {
    "pt-BR": "Período de carência : a execução efetiva ocorrerá em {executionDate}.",
    fr: "Période de carence : l'exécution effective interviendra le {executionDate}.",
    es: "Período de carencia : la ejecución efectiva ocurrirá el {executionDate}.",
    en: "Grace period: effective execution will occur on {executionDate}.",
    it: "Periodo di carenza : l'esecuzione effettiva avverrà il {executionDate}.",
    de: "Karenzzeit: die tatsächliche Ausführung erfolgt am {executionDate}.",
    ca: "Període de gràcia: l'execució efectiva tindrà lloc el {executionDate}.",
    eo: "Grac-periodo: la efektiva plenumo okazos la {executionDate}.",
    nl: "Respijtperiode: de daadwerkelijke uitvoering vindt plaats op {executionDate}.",
    el: "Περίοδος χάριτος: η εκτέλεση θα πραγματοποιηθεί στις {executionDate}."
  },

  // ===== network.collective_removal_cancelled ===============================
  // Envoyé aux autres admins (et au target si la proposition était unanimous).
  // Purement informatif.
  "network.collective_removal_cancelled.reason_label": {
    "pt-BR": "Motivo da anulação :",
    fr: "Motif d'annulation :",
    es: "Motivo de la anulación :",
    en: "Cancellation reason:",
    it: "Motivo dell'annullamento :",
    de: "Annullierungsgrund:",
    ca: "Motiu de l'anul·lació:",
    eo: "Motivo de la nuligo:",
    nl: "Reden voor annulering:",
    el: "Λόγος ακύρωσης:"
  },
  "network.collective_removal_cancelled.sub": {
    "pt-BR": "Retirada coletiva cancelada : {proposedName}",
    fr: "Retrait collectif annulé · {proposedName}",
    es: "Retiro colectivo cancelado · {proposedName}",
    en: "Collective removal cancelled · {proposedName}",
    it: "Ritiro collettivo annullato · {proposedName}",
    de: "Kollektiver Rückzug abgebrochen · {proposedName}",
    ca: "Retirada col·lectiva anul·lada · {proposedName}",
    eo: "Kolektiva forigo nuligita · {proposedName}",
    nl: "Collectieve afzetting geannuleerd · {proposedName}",
    el: "Συλλογική απομάκρυνση ακυρώθηκε · {proposedName}"
  },
  "network.collective_removal_cancelled.target_intro": {
    "pt-BR": "Olá, {targetName}. A proposta de retirada coletiva que tinha sido aberta sobre você foi anulada. Você permanece administrador·a ativo·a da rede AnarBib. Esta decisão é coletiva e política.",
    fr: "Bonjour {targetName}. La proposition de retrait collectif qui avait été ouverte à ton sujet a été annulée. Tu restes administrateur·rice actif·ve du réseau AnarBib. Cette décision est collective et politique.",
    es: "Hola, {targetName}. La propuesta de retiro colectivo que se había abierto sobre vos fue anulada. Seguís siendo administrador·a activo·a de la red AnarBib. Esta decisión es colectiva y política.",
    en: "Hello {targetName}. The collective removal proposal that had been opened concerning you has been cancelled. You remain an active administrator of the AnarBib network. This decision is collective and political.",
    it: "Ciao {targetName}. La proposta di rimozione collettiva aperta nei tuoi confronti è stata annullata. Resti amministratore/trice attiv* della rete AnarBib. Questa decisione è collettiva e politica.",
    de: "Hallo {targetName}. Der kollektive Entzugsvorschlag, der dich betraf, wurde annulliert. Du bleibst aktive*r Administrator*in des AnarBib-Netzwerks. Diese Entscheidung ist kollektiv und politisch.",
    ca: "Hola, {targetName}. La proposta de retirada col·lectiva que s'havia obert sobre tu ha estat anul·lada. Continues sent administrador-a-e actiu-iva-e de la xarxa AnarBib. Aquesta decisió és col·lectiva i política.",
    eo: "Saluton, {targetName}. La propono de kolektiva forigo kiu estis malfermita pri vi estis nuligita. Vi restas aktiva administrant-in-o de la reto AnarBib. Ĉi tiu decido estas kolektiva kaj politika.",
    nl: "Hallo {targetName}. Het voorstel tot collectieve afzetting dat over jou was geopend, is geannuleerd. Je blijft een actieve beheerder van het AnarBib-netwerk. Deze beslissing is collectief en politiek.",
    el: "Γεια σου {targetName}. Η πρόταση συλλογικής απομάκρυνσης που είχε ανοίξει σχετικά με εσένα ακυρώθηκε. Παραμένεις ενεργός/ή διαχειριστής/στρια του δικτύου AnarBib. Αυτή η απόφαση είναι συλλογική και πολιτική."
  },
  "network.collective_removal_cancelled.intro": {
    "pt-BR": "A proposta de retirada coletiva d(o/a/e) {proposedName} foi anulada. Nenhuma efetivação será realizada. Esta decisão é registrada no histórico militante da rede.",
    fr: "La proposition de retrait collectif de {proposedName} a été annulée. Aucune exécution ne sera réalisée. Cette décision est consignée dans l'historique militant du réseau.",
    es: "La propuesta de retiro colectivo de {proposedName} fue cancelada. No se realizará ninguna ejecución. Esta decisión queda registrada en el historial militante de la red.",
    en: "The collective removal proposal for {proposedName} has been cancelled. No execution will occur. This decision is recorded in the militant history of the network.",
    it: "La proposta di ritiro collettivo di {proposedName} è stata annullata. Nessuna esecuzione avrà luogo. Questa decisione è registrata nella storia militante della rete.",
    de: "Der Vorschlag zum kollektiven Rückzug von {proposedName} wurde abgebrochen. Es erfolgt keine Vollziehung. Diese Entscheidung wird in der militanten Geschichte des Netzwerks festgehalten.",
    ca: "La proposta de retirada col·lectiva de {proposedName} ha estat anul·lada. No es realitzarà cap execució. Aquesta decisió queda registrada a l'historial militant de la xarxa.",
    eo: "La propono de kolektiva forigo de {proposedName} estis nuligita. Neniu plenumo okazos. Ĉi tiu decido estas registrita en la aktivisma historio de la reto.",
    nl: "Het voorstel tot collectieve afzetting van {proposedName} is geannuleerd. Er vindt geen uitvoering plaats. Deze beslissing wordt vastgelegd in de militante geschiedenis van het netwerk.",
    el: "Η πρόταση συλλογικής απομάκρυνσης του/της {proposedName} ακυρώθηκε. Δεν θα γίνει καμία εκτέλεση. Αυτή η απόφαση καταγράφεται στο αγωνιστικό ιστορικό του δικτύου."
  },

  // ===== network.collective_removal_executed ================================
  // Envoyé après la carence de 7j, par le cron. Au target + autres admins.
  // L'Edge Function adaptera selon destinataire (target vs autres) via
  // variante .target_intro.
  "network.collective_removal_executed.sub": {
    "pt-BR": "Retirada coletiva executada : {proposedName}",
    fr: "Retrait collectif exécuté · {proposedName}",
    es: "Retiro colectivo ejecutado · {proposedName}",
    en: "Collective removal executed · {proposedName}",
    it: "Ritiro collettivo eseguito · {proposedName}",
    de: "Kollektiver Rückzug vollzogen · {proposedName}",
    ca: "Retirada col·lectiva executada · {proposedName}",
    eo: "Kolektiva forigo plenumita · {proposedName}",
    nl: "Collectieve afzetting uitgevoerd · {proposedName}",
    el: "Συλλογική απομάκρυνση εκτελέστηκε · {proposedName}"
  },
  "network.collective_removal_executed.intro": {
    "pt-BR": "Após o término da carência de 7 dias, a retirada coletiva d(o/a/e) {proposedName} foi efetivada. Esta pessoa não tem mais o papel d(o/a/e) administrador(a/e) de rede. A decisão é registrada no histórico militante d(o/a/e) AnarBib.",
    fr: "À l'issue de la carence de 7 jours, le retrait collectif de {proposedName} a été effectué. Cette personne n'occupe plus la fonction d'administrateur·rice de réseau. La décision est consignée dans l'historique militant d'AnarBib.",
    es: "Tras el fin del período de gracia de 7 días, el retiro colectivo de {proposedName} se hizo efectivo. Esta persona ya no ocupa la función de administrade de red. La decisión queda registrada en el historial militante de AnarBib.",
    en: "After the 7-day grace period, the collective removal of {proposedName} has been carried out. This person no longer holds the network administrator role. The decision is recorded in the militant history of AnarBib.",
    it: "Al termine del periodo di grazia di 7 giorni, il ritiro collettivo di {proposedName} è stato attuato. Questa persona non ricopre più il ruolo di amministratore/trice di rete. La decisione è registrata nella storia militante di AnarBib.",
    de: "Nach Ablauf der 7-tägigen Karenzfrist wurde der kollektive Rückzug von {proposedName} vollzogen. Diese Person ist nicht mehr Netzwerk-Administrator*in. Die Entscheidung wird in der militanten Geschichte von AnarBib festgehalten.",
    ca: "Un cop finalitzat el termini de gràcia de 7 dies, la retirada col·lectiva de {proposedName} s'ha fet efectiva. Aquesta persona ja no ocupa la funció d'administrador-a-e de xarxa. La decisió queda registrada a l'historial militant d'AnarBib.",
    eo: "Post la fino de la grac-periodo de 7 tagoj, la kolektiva forigo de {proposedName} estis efektivigita. Ĉi tiu persono ne plu okupas la funkcion de reta administrant-in-o. La decido estas registrita en la aktivisma historio de AnarBib.",
    nl: "Na de respijtperiode van 7 dagen is de collectieve afzetting van {proposedName} uitgevoerd. Deze persoon bekleedt de functie van netwerkbeheerder niet langer. De beslissing wordt vastgelegd in de militante geschiedenis van AnarBib.",
    el: "Μετά την περίοδο χάριτος 7 ημερών, η συλλογική απομάκρυνση του/της {proposedName} πραγματοποιήθηκε. Αυτό το άτομο δεν κατέχει πλέον τον ρόλο του/της διαχειριστή/στριας δικτύου. Η απόφαση καταγράφεται στο αγωνιστικό ιστορικό του AnarBib."
  },
  "network.collective_removal_executed.target_intro": {
    "pt-BR": "A carência de 7 dias terminou e a retirada coletiva votada por unanimidade está agora efetiva. Vossa função d(o/a/e) administrador(a/e) de rede no AnarBib foi removida. Esta decisão é registrada no histórico militante.",
    fr: "La carence de 7 jours est arrivée à terme et le retrait collectif voté à l'unanimité prend effet. Votre fonction d'administrateur·rice de réseau dans AnarBib a été retirée. Cette décision est consignée dans l'historique militant.",
    es: "Terminó el período de gracia de 7 días y el retiro colectivo votado por unanimidad entra en vigor. Vuestra función de administrade de red en AnarBib fue retirada. Esta decisión queda registrada en el historial militante.",
    en: "The 7-day grace period has ended and the unanimously-voted collective removal now takes effect. Your network administrator role in AnarBib has been removed. This decision is recorded in the militant history.",
    it: "Il periodo di grazia di 7 giorni è terminato e il ritiro collettivo votato all'unanimità entra in vigore. La vostra funzione di amministratore/trice di rete in AnarBib è stata rimossa. Questa decisione è registrata nella storia militante.",
    de: "Die 7-tägige Karenzfrist ist abgelaufen, und der einstimmig beschlossene kollektive Rückzug wird wirksam. Ihre Funktion als Netzwerk-Administrator*in in AnarBib wurde entzogen. Diese Entscheidung wird in der militanten Geschichte festgehalten.",
    ca: "El termini de gràcia de 7 dies ha acabat i la retirada col·lectiva votada per unanimitat entra en vigor. La vostra funció d'administrador-a-e de xarxa a AnarBib ha estat retirada. Aquesta decisió queda registrada a l'historial militant.",
    eo: "La grac-periodo de 7 tagoj finiĝis kaj la kolektiva forigo voĉdonita unuanime ekvalidas. Via funkcio de reta administrant-in-o en AnarBib estis forigita. Ĉi tiu decido estas registrita en la aktivisma historio.",
    nl: "De respijtperiode van 7 dagen is afgelopen en de unaniem aangenomen collectieve afzetting wordt nu van kracht. Je functie van netwerkbeheerder in AnarBib is verwijderd. Deze beslissing wordt vastgelegd in de militante geschiedenis.",
    el: "Η περίοδος χάριτος 7 ημερών έληξε και η συλλογική απομάκρυνση που ψηφίστηκε ομόφωνα τίθεται σε ισχύ. Ο ρόλος σας ως διαχειριστής/στρια δικτύου στο AnarBib αφαιρέθηκε. Αυτή η απόφαση καταγράφεται στο αγωνιστικό ιστορικό."
  },
// ============================================================================
// Paquet E.1bis - Bloc i18n cooptation (4 events x 6 locales)
// ============================================================================
// 4 events :
//   - network.cooptation_proposed   .sub .intro .cta .motivation_label
//   - network.cooptation_voted      .sub .intro .rationale_label
//   - network.cooptation_rejected   .sub .intro .target_intro
//   - network.cooptation_completed  .sub .intro .target_intro .cta
//
// Conventions militantes strictes par locale (cf. en-tete mail-strings.ts).
// Adresse : vouvoiement neutre pour les 6 locales.
//
// Placeholders standard :
//   {proposedName}    nom de la personne proposee a la cooptation
//   {proposerName}    nom de la personne qui propose
//   {voterName}       nom du votant (peut etre neutralise cote EF si non-disclose)
//   {opposedCount}    nombre de votes opposed (rejected)
//   {favorableCount}  nombre de votes favorable
//   {pendingDeadline} date lisible (proposal expires_at)
// ============================================================================

  // ── Assemblée du réseau (AG, paquet P3) ──────────────────────────────────
  "network.assembleia.convocada.sub": {
    "pt-BR": "Assembleia da rede convocada — {title}",
    fr: "Assemblée du réseau convoquée — {title}",
    es: "Asamblea de la red convocada — {title}",
    en: "Network assembly convened — {title}",
    it: "Assemblea della rete convocata — {title}",
    de: "Netzwerkversammlung einberufen — {title}",
    ca: "Assemblea de la xarxa convocada — {title}",
    eo: "Reta asembleo kunvokita — {title}",
    nl: "Netwerkvergadering bijeengeroepen — {title}",
    el: "Συνέλευση του δικτύου συγκλήθηκε — {title}"
  },
  "network.assembleia.convocada.intro": {
    "pt-BR": "Uma assembleia da rede foi convocada: « {title} ». A ordem do dia está se constituindo — é hora de avisar sua biblioteca e preparar o mandato de quem vos representará.",
    fr: "Une assemblée du réseau est convoquée : « {title} ». L'ordre du jour se constitue — c'est le moment de prévenir ta bibliothèque et de préparer le mandat de votre délégué·e.",
    es: "Se ha convocado una asamblea de la red: « {title} ». El orden del día se está formando — es momento de avisar a tu biblioteca y preparar el mandato de quien os represente.",
    en: "A network assembly has been convened: “{title}”. The agenda is taking shape — it's time to inform your library and prepare your delegate's mandate.",
    it: "È stata convocata un'assemblea della rete: « {title} ». L'ordine del giorno si sta formando — è il momento di avvisare la tua biblioteca e preparare il mandato di chi vi rappresenterà.",
    de: "Eine Netzwerkversammlung wurde einberufen: « {title} ». Die Tagesordnung entsteht — informiere jetzt deine Bibliothek und bereitet das Mandat eurer Delegation vor.",
    ca: "S'ha convocat una assemblea de la xarxa: « {title} ». L'ordre del dia s'està constituint — és el moment d'avisar la teva biblioteca i preparar el mandat de qui us representi.",
    eo: "Reta asembleo estas kunvokita: « {title} ». La tagordo formiĝas — jen la momento por averti vian bibliotekon kaj prepari la mandaton de via reprezentanto.",
    nl: "Er is een netwerkvergadering bijeengeroepen: « {title} ». De agenda krijgt vorm — informeer nu je bibliotheek en bereid het mandaat van jullie afgevaardigde voor.",
    el: "Συγκλήθηκε συνέλευση του δικτύου: « {title} ». Η ημερήσια διάταξη διαμορφώνεται — είναι η στιγμή να ενημερώσετε τη βιβλιοθήκη σας και να προετοιμάσετε την εντολή του εκπροσώπου σας."
  },
  "network.assembleia.convocada.cta": {
    "pt-BR": "Ver a assembleia",
    fr: "Voir l'assemblée",
    es: "Ver la asamblea",
    en: "View the assembly",
    it: "Vedi l'assemblea",
    de: "Versammlung ansehen",
    ca: "Veure l'assemblea",
    eo: "Vidi la asembleon",
    nl: "Vergadering bekijken",
    el: "Δείτε τη συνέλευση"
  },
  "network.assembleia.agenda_published.sub": {
    "pt-BR": "Ordem do dia publicada — {title}",
    fr: "Ordre du jour publié — {title}",
    es: "Orden del día publicado — {title}",
    en: "Agenda published — {title}",
    it: "Ordine del giorno pubblicato — {title}",
    de: "Tagesordnung veröffentlicht — {title}",
    ca: "Ordre del dia publicat — {title}",
    eo: "Tagordo publikigita — {title}",
    nl: "Agenda gepubliceerd — {title}",
    el: "Δημοσιεύτηκε η ημερήσια διάταξη — {title}"
  },
  "network.assembleia.agenda_published.intro": {
    "pt-BR": "A ordem do dia de « {title} » está fixada e traduzida. Tomem conhecimento e mandatem quem vos representará ponto a ponto antes da realização.",
    fr: "L'ordre du jour de « {title} » est figé et traduit. Prenez-en connaissance et mandatez votre délégué·e point par point avant la tenue.",
    es: "El orden del día de « {title} » está fijado y traducido. Tomen conocimiento y manden a quien os represente punto por punto antes de la celebración.",
    en: "The agenda for “{title}” is finalised and translated. Review it and mandate your delegate point by point before the assembly is held.",
    it: "L'ordine del giorno di « {title} » è fissato e tradotto. Prendetene visione e mandatate chi vi rappresenterà punto per punto prima dello svolgimento.",
    de: "Die Tagesordnung von « {title} » steht fest und ist übersetzt. Nehmt sie zur Kenntnis und mandatiert eure Delegation Punkt für Punkt vor der Durchführung.",
    ca: "L'ordre del dia de « {title} » està fixat i traduït. Preneu-ne coneixement i mandateu qui us representi punt per punt abans de la realització.",
    eo: "La tagordo de « {title} » estas fiksita kaj tradukita. Konatiĝu kun ĝi kaj mandatu vian reprezentanton punkton post punkto antaŭ la okazigo.",
    nl: "De agenda van « {title} » is vastgesteld en vertaald. Neem er kennis van en mandateer jullie afgevaardigde punt voor punt vóór de bijeenkomst.",
    el: "Η ημερήσια διάταξη της « {title} » οριστικοποιήθηκε και μεταφράστηκε. Λάβετε γνώση και δώστε εντολή στον εκπρόσωπό σας σημείο προς σημείο πριν από τη διεξαγωγή."
  },
  "network.assembleia.agenda_published.cta": {
    "pt-BR": "Ler a ordem do dia",
    fr: "Lire l'ordre du jour",
    es: "Leer el orden del día",
    en: "Read the agenda",
    it: "Leggere l'ordine del giorno",
    de: "Tagesordnung lesen",
    ca: "Llegir l'ordre del dia",
    eo: "Legi la tagordon",
    nl: "Agenda lezen",
    el: "Διαβάστε την ημερήσια διάταξη"
  },
  "network.assembleia.item_proposed.sub": {
    "pt-BR": "Novo ponto na ordem do dia — {title}",
    fr: "Nouveau point à l'ordre du jour — {title}",
    es: "Nuevo punto en el orden del día — {title}",
    en: "New agenda item — {title}",
    it: "Nuovo punto all'ordine del giorno — {title}",
    de: "Neuer Tagesordnungspunkt — {title}",
    ca: "Nou punt a l'ordre del dia — {title}",
    eo: "Nova tagordero — {title}",
    nl: "Nieuw agendapunt — {title}",
    el: "Νέο σημείο στην ημερήσια διάταξη — {title}"
  },
  "network.assembleia.item_proposed.intro": {
    "pt-BR": "{library} inscreveu um ponto: « {itemTitle} ». A ordenar na ordem do dia no momento certo — sem nunca suprimi-lo.",
    fr: "{library} a déposé un point : « {itemTitle} ». À ordonner dans l'ordre du jour le moment venu — sans jamais le supprimer.",
    es: "{library} inscribió un punto: « {itemTitle} ». A ordenar en el orden del día llegado el momento — sin suprimirlo nunca.",
    en: "{library} submitted an item: “{itemTitle}”. To be ordered in the agenda when the time comes — never removed.",
    it: "{library} ha inserito un punto: « {itemTitle} ». Da ordinare nell'ordine del giorno al momento giusto — senza mai eliminarlo.",
    de: "{library} hat einen Punkt eingereicht: « {itemTitle} ». Zur gegebenen Zeit in der Tagesordnung einzuordnen — niemals zu entfernen.",
    ca: "{library} ha inscrit un punt: « {itemTitle} ». A ordenar a l'ordre del dia quan sigui el moment — sense suprimir-lo mai.",
    eo: "{library} enskribis punkton: « {itemTitle} ». Ordigenda en la tagordo ĝustatempe — neniam forigenda.",
    nl: "{library} heeft een punt ingediend: « {itemTitle} ». Te ordenen in de agenda wanneer het moment daar is — nooit te verwijderen.",
    el: "{library} κατέθεσε ένα σημείο: « {itemTitle} ». Προς τακτοποίηση στην ημερήσια διάταξη όταν έρθει η ώρα — χωρίς ποτέ να αφαιρεθεί."
  },
  "network.assembleia.item_proposed.cta": {
    "pt-BR": "Ver a ordem do dia",
    fr: "Voir l'ordre du jour",
    es: "Ver el orden del día",
    en: "View the agenda",
    it: "Vedi l'ordine del giorno",
    de: "Tagesordnung ansehen",
    ca: "Veure l'ordre del dia",
    eo: "Vidi la tagordon",
    nl: "Agenda bekijken",
    el: "Δείτε την ημερήσια διάταξη"
  },
  // ===== network.cooptation_proposed ========================================
  // Envoye aux autres admins actifs (hors proposeur, hors target).
  // Le target n'est PAS notifie a cette etape : sa cooptation se discute
  // entre les admins existants avant qu'il en soit informe.
  "network.cooptation_proposed.sub": {
    "pt-BR": "Proposta de cooptação : {proposedName}",
    fr: "Proposition de cooptation : {proposedName}",
    es: "Propuesta de cooptación : {proposedName}",
    en: "Cooptation proposal: {proposedName}",
    it: "Proposta di cooptazione : {proposedName}",
    de: "Kooptationsvorschlag: {proposedName}",
    ca: "Proposta de cooptació: {proposedName}",
    eo: "Kooptad-propono: {proposedName}",
    nl: "Coöptatievoorstel: {proposedName}",
    el: "Πρόταση κοόπτησης: {proposedName}"
  },
  "network.cooptation_proposed.intro": {
    "pt-BR": "{proposerName} propôs cooptar {proposedName} como administrador(a/e) de rede. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s é necessária para concluir o processo. Vosso voto é esperado.",
    fr: "{proposerName} propose de coopter {proposedName} comme administrateur·rice du réseau. L'unanimité des administrateur·rices actif·ves est nécessaire pour conclure le processus. Votre vote est attendu.",
    es: "{proposerName} propone cooptar a {proposedName} como administrade de red. La unanimidad de les administradores activos es necesaria para cerrar el proceso. Vuestro voto es esperado.",
    en: "{proposerName} proposes to coopt {proposedName} as a network administrator. Unanimity among active network administrators is required to complete the process. Your vote is expected.",
    it: "{proposerName} propone di cooptare {proposedName} come amministratore/trice di rete. L'unanimità dei compagn* amministratori/trici attiv* è necessaria per concludere il processo. Il vostro voto è atteso.",
    de: "{proposerName} schlägt vor, {proposedName} als Netzwerk-Administrator*in zu kooptieren. Die Einstimmigkeit der aktiven Netzwerk-Administrator*innen ist erforderlich, um den Prozess abzuschließen. Ihre Stimme wird erwartet.",
    ca: "{proposerName} proposa cooptar {proposedName} com a administrador-a-e de xarxa. La unanimitat de les administradores actives és necessària per concloure el procés. S'espera el vostre vot.",
    eo: "{proposerName} proponas koopti {proposedName} kiel retan administrant-in-on. La unuanimeco de la aktivaj administrant-in-oj estas necesa por konkludi la procezon. Via voĉdono estas atendata.",
    nl: "{proposerName} stelt voor om {proposedName} te coöpteren als netwerkbeheerder. Unanimiteit onder de actieve netwerkbeheerders is vereist om het proces af te ronden. Je stem wordt verwacht.",
    el: "Ο/Η {proposerName} προτείνει την κοόπτηση του/της {proposedName} ως διαχειριστή/στρια του δικτύου. Απαιτείται ομοφωνία των ενεργών διαχειριστών/στριών του δικτύου για να ολοκληρωθεί η διαδικασία. Αναμένεται η ψήφος σας."
  },
  "network.cooptation_proposed.cta": {
    "pt-BR": "Acessar a proposta e votar",
    fr: "Accéder à la proposition et voter",
    es: "Acceder a la propuesta y votar",
    en: "Open the proposal and vote",
    it: "Accedere alla proposta e votare",
    de: "Vorschlag öffnen und abstimmen",
    ca: "Accedir a la proposta i votar",
    eo: "Aliri la proponon kaj voĉdoni",
    nl: "Open het voorstel en stem",
    el: "Άνοιξε την πρόταση και ψήφισε"
  },
  "network.cooptation_proposed.motivation_label": {
    "pt-BR": "Motivacao invocada :",
    fr: "Motivation invoquee :",
    es: "Motivacion invocada :",
    en: "Stated motivation:",
    it: "Motivazione invocata :",
    de: "Angegebene Begrundung:",
    ca: "Motivació invocada:",
    eo: "Invokita motivo:",
    nl: "Aangevoerde motivatie:",
    el: "Αιτιολόγηση που προβλήθηκε:"
  },

  // ===== network.cooptation_voted ===========================================
  // Envoye aux autres admins (hors votant, hors target) apres chaque vote
  // intermediaire (Q1 transparence). payload.voter_user_id peut etre NULL
  // si disclose_identity=false : cote EF, substitution par chaine neutre.
  "network.cooptation_voted.sub": {
    "pt-BR": "Voto registrado : cooptação de {proposedName}",
    fr: "Vote enregistré · cooptation de {proposedName}",
    es: "Voto registrado · cooptación de {proposedName}",
    en: "Vote registered · cooptation of {proposedName}",
    it: "Voto registrato · cooptazione di {proposedName}",
    de: "Stimme registriert · Kooptation von {proposedName}",
    ca: "Vot registrat · cooptació de {proposedName}",
    eo: "Voĉdono registrita · kooptado de {proposedName}",
    nl: "Stem geregistreerd · coöptatie van {proposedName}",
    el: "Ψήφος καταχωρίστηκε · κοόπτηση του/της {proposedName}"
  },
  "network.cooptation_voted.intro": {
    "pt-BR": "Um(a/e) administrador(a/e) de rede acaba de votar sobre a proposta de cooptação de {proposedName}, aberta por {proposerName}. Acessai a app para ver o estado atual da deliberação e votar se ainda não o fizeste.",
    fr: "Un·e administrateur·rice du réseau vient de voter sur la proposition de cooptation de {proposedName}, ouverte par {proposerName}. Accédez à l'app pour voir l'état actuel de la délibération et voter si ce n'est pas déjà fait.",
    es: "Une administrade de red acaba de votar sobre la propuesta de cooptación de {proposedName}, abierta por {proposerName}. Accedé a la app para ver el estado actual de la deliberación y votar si aún no lo hiciste.",
    en: "A network administrator has just cast a vote on the cooptation proposal of {proposedName}, opened by {proposerName}. Open the app to see the current state of the deliberation and vote if you haven't already.",
    it: "Un compagn* amministratore/trice di rete ha appena votato sulla proposta di cooptazione di {proposedName}, aperta da {proposerName}. Accedi all'app per vedere lo stato attuale della deliberazione e votare se non l'hai ancora fatto.",
    de: "Ein*e Netzwerk-Administrator*in hat soeben über den Kooptationsvorschlag von {proposedName} abgestimmt, eröffnet von {proposerName}. Öffnen Sie die App, um den aktuellen Stand der Beratung zu sehen und abzustimmen, falls noch nicht geschehen.",
    ca: "Una administradora de xarxa acaba de votar sobre la proposta de cooptació de {proposedName}, oberta per {proposerName}. Accediu a l'aplicació per veure l'estat actual de la deliberació i votar si encara no ho heu fet.",
    eo: "Reta administrant-in-o ĵus voĉdonis pri la kooptad-propono de {proposedName}, malfermita de {proposerName}. Aliru la aplikaĵon por vidi la nunan staton de la pridiskuto kaj voĉdoni se vi ankoraŭ ne faris tion.",
    nl: "Een netwerkbeheerder heeft zojuist gestemd over het coöptatievoorstel van {proposedName}, geopend door {proposerName}. Open de app om de huidige stand van de beraadslaging te zien en te stemmen als je dat nog niet hebt gedaan.",
    el: "Ένας/Μία διαχειριστής/στρια του δικτύου μόλις ψήφισε για την πρόταση κοόπτησης του/της {proposedName}, που άνοιξε ο/η {proposerName}. Ανοίξτε την εφαρμογή για να δείτε την τρέχουσα κατάσταση της διαβούλευσης και να ψηφίσετε αν δεν το έχετε ήδη κάνει."
  },
  "network.cooptation_voted.rationale_label": {
    "pt-BR": "Motivo do voto contrário :",
    fr: "Motif du vote défavorable :",
    es: "Motivo del voto contrario :",
    en: "Reason for opposing vote:",
    it: "Motivo del voto contrario :",
    de: "Begründung der Ablehnung:",
    ca: "Motiu del vot contrari:",
    eo: "Motivo de la kontraŭa voĉdono:",
    nl: "Reden voor de tegenstem:",
    el: "Λόγος αρνητικής ψήφου:"
  },

  // ===== network.cooptation_rejected ========================================
  // Un seul vote opposed = veto immediat (doctrine v0.3 unanimite).
  // Q3 : target + proposeur + autres admins.
  // Variante target_intro pour le target ("votre cooptation a ete refusee").
  "network.cooptation_rejected.sub": {
    "pt-BR": "Cooptação rejeitada : {proposedName}",
    fr: "Cooptation rejetée · {proposedName}",
    es: "Cooptación rechazada · {proposedName}",
    en: "Cooptation rejected · {proposedName}",
    it: "Cooptazione respinta · {proposedName}",
    de: "Kooptation abgelehnt · {proposedName}",
    ca: "Cooptació rebutjada · {proposedName}",
    eo: "Kooptado rifuzita · {proposedName}",
    nl: "Coöptatie afgewezen · {proposedName}",
    el: "Κοόπτηση απορρίφθηκε · {proposedName}"
  },
  "network.cooptation_rejected.intro": {
    "pt-BR": "A proposta de cooptação de {proposedName}, aberta por {proposerName}, foi rejeitada por pelo menos um voto contrário. A unanimidade requerida não foi alcançada e o processo é encerrado.",
    fr: "La proposition de cooptation de {proposedName}, ouverte par {proposerName}, a été rejetée par au moins un vote défavorable. L'unanimité requise n'est pas atteinte et le processus est clos.",
    es: "La propuesta de cooptación de {proposedName}, abierta por {proposerName}, fue rechazada por al menos un voto contrario. La unanimidad requerida no se alcanzó y el proceso se cierra.",
    en: "The cooptation proposal of {proposedName}, opened by {proposerName}, has been rejected by at least one opposing vote. The required unanimity was not reached and the process is closed.",
    it: "La proposta di cooptazione di {proposedName}, aperta da {proposerName}, è stata respinta per almeno un voto contrario. L'unanimità richiesta non è stata raggiunta e il processo si chiude.",
    de: "Der Kooptationsvorschlag von {proposedName}, eröffnet von {proposerName}, wurde durch mindestens eine Gegenstimme abgelehnt. Die erforderliche Einstimmigkeit wurde nicht erreicht und der Prozess wird geschlossen.",
    ca: "La proposta de cooptació de {proposedName}, oberta per {proposerName}, ha estat rebutjada per almenys un vot contrari. La unanimitat requerida no s'ha assolit i el procés es tanca.",
    eo: "La kooptad-propono de {proposedName}, malfermita de {proposerName}, estis rifuzita pro almenaŭ unu kontraŭa voĉdono. La postulata unuanimeco ne estis atingita kaj la procezo fermiĝas.",
    nl: "Het coöptatievoorstel van {proposedName}, geopend door {proposerName}, is afgewezen door minstens één tegenstem. De vereiste unanimiteit is niet bereikt en het proces is afgesloten.",
    el: "Η πρόταση κοόπτησης του/της {proposedName}, που άνοιξε ο/η {proposerName}, απορρίφθηκε από τουλάχιστον μία αρνητική ψήφο. Η απαιτούμενη ομοφωνία δεν επιτεύχθηκε και η διαδικασία έκλεισε."
  },
  "network.cooptation_rejected.target_intro": {
    "pt-BR": "Olá {targetName}. Uma proposta de cooptação para integrar-te como administrador(a/e) de rede AnarBib foi aberta e discutida pel(o/a/e)s administrador(a/e)s ativ(o/a/e)s. Esta proposta não foi acolhida à unanimidade : recebeu pelo menos um voto contrário e o processo é encerrado. Esta decisão é coletiva e política, não pessoal.",
    fr: "Bonjour {targetName}. Une proposition de cooptation pour t'intégrer comme administrateur·rice du réseau AnarBib a été ouverte et discutée par les administrateur·rices actif·ves. Cette proposition n'a pas recueilli l'unanimité : elle a reçu au moins un vote défavorable et le processus est clos. Cette décision est collective et politique, non personnelle.",
    es: "Hola {targetName}. Una propuesta de cooptación para integrarte como administrade de red AnarBib fue abierta y discutida por les administradores activos. Esta propuesta no obtuvo unanimidad : recibió al menos un voto contrario y el proceso se cierra. Esta decisión es colectiva y política, no personal.",
    en: "Hello {targetName}. A cooptation proposal to integrate you as a network administrator of AnarBib was opened and discussed by the active administrators. This proposal did not reach unanimity: it received at least one opposing vote and the process is closed. This decision is collective and political, not personal.",
    it: "Ciao {targetName}. Una proposta di cooptazione per integrarti come amministratore/trice di rete AnarBib è stata aperta e discussa dai compagn* amministratori/trici attiv*. Questa proposta non ha raggiunto l'unanimità : ha ricevuto almeno un voto contrario e il processo si chiude. Questa decisione è collettiva e politica, non personale.",
    de: "Hallo {targetName}. Ein Kooptationsvorschlag, um Sie als Netzwerk-Administrator*in von AnarBib zu integrieren, wurde eröffnet und von den aktiven Administrator*innen besprochen. Dieser Vorschlag erreichte keine Einstimmigkeit: er erhielt mindestens eine Gegenstimme und der Prozess wird geschlossen. Diese Entscheidung ist kollektiv und politisch, nicht persönlich.",
    ca: "Hola, {targetName}. S'ha obert i discutit una proposta de cooptació per integrar-te com a administrador-a-e de la xarxa AnarBib per part de les administradores actives. Aquesta proposta no ha obtingut la unanimitat: ha rebut almenys un vot contrari i el procés es tanca. Aquesta decisió és col·lectiva i política, no personal.",
    eo: "Saluton, {targetName}. Kooptad-propono por integri vin kiel administrant-in-on de la reto AnarBib estis malfermita kaj pridiskutita de la aktivaj administrant-in-oj. Ĉi tiu propono ne atingis la unuanimecon: ĝi ricevis almenaŭ unu kontraŭan voĉdonon kaj la procezo fermiĝas. Ĉi tiu decido estas kolektiva kaj politika, ne persona.",
    nl: "Hallo {targetName}. Een coöptatievoorstel om jou op te nemen als netwerkbeheerder van AnarBib is geopend en besproken door de actieve beheerders. Dit voorstel heeft geen unanimiteit bereikt: het kreeg minstens één tegenstem en het proces is afgesloten. Deze beslissing is collectief en politiek, niet persoonlijk.",
    el: "Γεια σου {targetName}. Μια πρόταση κοόπτησης για την ένταξή σου ως διαχειριστή/στρια του δικτύου AnarBib άνοιξε και συζητήθηκε από τους/τις ενεργούς/ές διαχειριστές/στριες. Αυτή η πρόταση δεν συγκέντρωσε ομοφωνία: έλαβε τουλάχιστον μία αρνητική ψήφο και η διαδικασία έκλεισε. Αυτή η απόφαση είναι συλλογική και πολιτική, όχι προσωπική."
  },

  // ===== network.cooptation_completed =======================================
  // Unanimite atteinte. Q4 : target + proposeur + autres admins.
  // Variante target_intro : ton particulier "bienvenue dans la coordination".
  "network.cooptation_completed.sub": {
    "pt-BR": "Cooptação concluída à unanimidade : {proposedName}",
    fr: "Cooptation conclue à l'unanimité · {proposedName}",
    es: "Cooptación concluida por unanimidad · {proposedName}",
    en: "Cooptation completed unanimously · {proposedName}",
    it: "Cooptazione conclusa all'unanimità · {proposedName}",
    de: "Kooptation einstimmig abgeschlossen · {proposedName}",
    ca: "Cooptació conclosa per unanimitat · {proposedName}",
    eo: "Kooptado konkludita unuanime · {proposedName}",
    nl: "Coöptatie unaniem afgerond · {proposedName}",
    el: "Κοόπτηση ολοκληρώθηκε ομόφωνα · {proposedName}"
  },
  "network.cooptation_completed.intro": {
    "pt-BR": "A proposta de cooptação de {proposedName}, aberta por {proposerName}, foi concluída à unanimidade. {proposedName} torna-se administrador(a/e) de rede ativ(o/a/e) da AnarBib.",
    fr: "La proposition de cooptation de {proposedName}, ouverte par {proposerName}, a été conclue à l'unanimité. {proposedName} devient administrateur·rice du réseau AnarBib actif·ve.",
    es: "La propuesta de cooptación de {proposedName}, abierta por {proposerName}, fue concluida por unanimidad. {proposedName} se vuelve administrade de red activa de AnarBib.",
    en: "The cooptation proposal of {proposedName}, opened by {proposerName}, has been concluded unanimously. {proposedName} becomes an active network administrator of AnarBib.",
    it: "La proposta di cooptazione di {proposedName}, aperta da {proposerName}, è stata conclusa all'unanimità. {proposedName} diventa compagn* amministratore/trice di rete attiv* di AnarBib.",
    de: "Der Kooptationsvorschlag von {proposedName}, eröffnet von {proposerName}, wurde einstimmig abgeschlossen. {proposedName} wird aktive*r Netzwerk-Administrator*in von AnarBib.",
    ca: "La proposta de cooptació de {proposedName}, oberta per {proposerName}, s'ha conclòs per unanimitat. {proposedName} esdevé administrador-a-e de xarxa actiu-iva-e d'AnarBib.",
    eo: "La kooptad-propono de {proposedName}, malfermita de {proposerName}, estis konkludita unuanime. {proposedName} iĝas aktiva reta administrant-in-o de AnarBib.",
    nl: "Het coöptatievoorstel van {proposedName}, geopend door {proposerName}, is unaniem afgerond. {proposedName} wordt een actieve netwerkbeheerder van AnarBib.",
    el: "Η πρόταση κοόπτησης του/της {proposedName}, που άνοιξε ο/η {proposerName}, ολοκληρώθηκε ομόφωνα. Ο/Η {proposedName} γίνεται ενεργός/ή διαχειριστής/στρια του δικτύου AnarBib."
  },
  "network.cooptation_completed.target_intro": {
    "pt-BR": "Olá {targetName}. A proposta de cooptação para integrar-te como administrador(a/e) de rede AnarBib foi concluída à unanimidade. Sejas bem-vind(o/a/e) na equipa de administração de rede.",
    fr: "Bonjour {targetName}. La proposition de cooptation pour t'intégrer comme administrateur·rice du réseau AnarBib a été conclue à l'unanimité. Bienvenue dans l'équipe d'administration du réseau.",
    es: "Hola {targetName}. La propuesta de cooptación para integrarte como administrade de red AnarBib fue concluida por unanimidad. ¡Bienvenide al equipo de administración de red!",
    en: "Hello {targetName}. The cooptation proposal to integrate you as a network administrator of AnarBib has been concluded unanimously. Welcome to the network administration team.",
    it: "Ciao {targetName}. La proposta di cooptazione per integrarti come amministratore/trice di rete AnarBib è stata conclusa all'unanimità. Benvenut* nel team di amministrazione di rete.",
    de: "Hallo {targetName}. Der Kooptationsvorschlag, um Sie als Netzwerk-Administrator*in von AnarBib zu integrieren, wurde einstimmig abgeschlossen. Willkommen im Netzwerk-Administrationsteam.",
    ca: "Hola, {targetName}. La proposta de cooptació per integrar-te com a administrador-a-e de la xarxa AnarBib s'ha conclòs per unanimitat. Benvingut-da-e a l'equip d'administració de la xarxa.",
    eo: "Saluton, {targetName}. La kooptad-propono por integri vin kiel administrant-in-on de la reto AnarBib estis konkludita unuanime. Bonvenon en la retadministran teamon.",
    nl: "Hallo {targetName}. Het coöptatievoorstel om jou op te nemen als netwerkbeheerder van AnarBib is unaniem afgerond. Welkom in het netwerkbeheerteam.",
    el: "Γεια σου {targetName}. Η πρόταση κοόπτησης για την ένταξή σου ως διαχειριστή/στρια του δικτύου AnarBib ολοκληρώθηκε ομόφωνα. Καλώς όρισες στην ομάδα διαχείρισης του δικτύου."
  },
  "network.cooptation_completed.cta": {
    "pt-BR": "Acessar o painel de administração de rede",
    fr: "Accéder au panneau d'administration du réseau",
    es: "Acceder al panel de administración de red",
    en: "Open the network administration panel",
    it: "Accedere al pannello di amministrazione di rete",
    de: "Netzwerk-Administrationspanel öffnen",
    ca: "Accedir al tauler d'administració de la xarxa",
    eo: "Aliri la retadministran panelon",
    nl: "Open het netwerkbeheerpaneel",
    el: "Άνοιγμα του πίνακα διαχείρισης του δικτύου"
  },
  // ===== Consulta locale lifecycle (con.*) =================================
  "con.created.sub": {
    "pt-BR": "Pedido de consulta local recebido",
    fr: "Demande de consultation sur place reçue",
    es: "Pedido de consulta local recibido",
    en: "Local consultation request received",
    it: "Richiesta di consultazione in loco ricevuta",
    de: "Anfrage für Vor-Ort-Einsichtnahme eingegangen",
    ca: "Sol·licitud de consulta in situ rebuda",
    eo: "Peto de surloka konsulto ricevita",
    nl: "Aanvraag voor raadpleging ter plaatse ontvangen",
    el: "Λήφθηκε αίτημα επιτόπιας μελέτης"
  },
  "con.created.pre": {
    "pt-BR": "Sua consulta foi registrada.",
    fr: "Ta consultation a été enregistrée.",
    es: "Tu consulta fue registrada.",
    en: "Your consultation has been registered.",
    it: "La tua consultazione è stata registrata.",
    de: "Deine Einsichtnahme wurde registriert.",
    ca: "La teva consulta s'ha registrat.",
    eo: "Via konsulto estis registrita.",
    nl: "Je raadpleging is geregistreerd.",
    el: "Η μελέτη σου καταχωρίστηκε."
  },
  "con.created.intro": {
    "pt-BR": "Recebemos seu pedido de consulta local. A biblioteca confirmará a data e o horário em breve.",
    fr: "Nous avons reçu ta demande de consultation sur place. La bibliothèque te confirmera la date et l'horaire bientôt.",
    es: "Recibimos tu pedido de consulta local. La biblioteca confirmará pronto la fecha y el horario.",
    en: "We received your local consultation request. The library will confirm the date and time soon.",
    it: "Abbiamo ricevuto la tua richiesta di consultazione in loco. La biblioteca confermerà presto data e orario.",
    de: "Wir haben deine Anfrage für Vor-Ort-Einsichtnahme erhalten. Die Bibliothek bestätigt Datum und Uhrzeit in Kürze.",
    ca: "Hem rebut la teva sol·licitud de consulta in situ. La biblioteca et confirmarà aviat la data i l'hora.",
    eo: "Ni ricevis vian peton de surloka konsulto. La biblioteko baldaŭ konfirmos al vi la daton kaj la horon.",
    nl: "We hebben je aanvraag voor raadpleging ter plaatse ontvangen. De bibliotheek bevestigt binnenkort de datum en het tijdstip.",
    el: "Λάβαμε το αίτημά σου για επιτόπια μελέτη. Η βιβλιοθήκη θα σου επιβεβαιώσει σύντομα την ημερομηνία και την ώρα."
  },
  "con.created.hint": {
    "pt-BR": "Lembramos que a consulta local acontece nos espaços da biblioteca, sem empréstimo do(s) item(ns).",
    fr: "Rappel : la consultation se fait dans les espaces de la bibliothèque, sans emprunt de l'ouvrage.",
    es: "Recordá que la consulta local se hace en los espacios de la biblioteca, sin préstamo del material.",
    en: "Remember: the consultation takes place at the library, with no item loan.",
    it: "Ti ricordiamo che la consultazione avviene negli spazi della biblioteca, senza prestito del materiale.",
    de: "Hinweis: Die Einsichtnahme findet in den Räumen der Bibliothek statt, ohne Ausleihe.",
    ca: "Recorda: la consulta in situ es fa als espais de la biblioteca, sense préstec del document.",
    eo: "Memoru: la surloka konsulto okazas en la spacoj de la biblioteko, sen prunto de la dokumento.",
    nl: "Ter herinnering: de raadpleging vindt plaats in de bibliotheek, zonder uitlening van het document.",
    el: "Υπενθύμιση: η μελέτη γίνεται στους χώρους της βιβλιοθήκης, χωρίς δανεισμό του τεκμηρίου."
  },
  "con.created.admin": {
    "pt-BR": "Novo pedido de consulta local",
    fr: "Nouvelle demande de consultation sur place",
    es: "Nuevo pedido de consulta local",
    en: "New local consultation request",
    it: "Nuova richiesta di consultazione in loco",
    de: "Neue Anfrage für Vor-Ort-Einsichtnahme",
    ca: "Nova sol·licitud de consulta in situ",
    eo: "Nova peto de surloka konsulto",
    nl: "Nieuwe aanvraag voor raadpleging ter plaatse",
    el: "Νέο αίτημα επιτόπιας μελέτης"
  },
  "con.realized": {
    "pt-BR": "Consulta local registrada como realizada",
    fr: "Consultation sur place enregistrée comme effectuée",
    es: "Consulta local registrada como realizada",
    en: "Local consultation marked as completed",
    it: "Consultazione in loco registrata come effettuata",
    de: "Vor-Ort-Einsichtnahme als durchgeführt vermerkt",
    ca: "Consulta in situ registrada com a efectuada",
    eo: "Surloka konsulto registrita kiel efektivigita",
    nl: "Raadpleging ter plaatse gemarkeerd als voltooid",
    el: "Η επιτόπια μελέτη καταχωρίστηκε ως πραγματοποιηθείσα"
  },
  "con.cancelReader": {
    "pt-BR": "O(a/e) leitor(a/e) cancelou um pedido de consulta local",
    fr: "Le·la lecteur·rice a annulé une demande de consultation",
    es: "Le lectore canceló un pedido de consulta local",
    en: "The reader cancelled a consultation request",
    it: "Lettor* ha annullato una richiesta di consultazione",
    de: "Leser*in hat eine Anfrage für Einsichtnahme storniert",
    ca: "Le lector-a-e ha cancel·lat una sol·licitud de consulta in situ",
    eo: "La legant-in-o nuligis peton de surloka konsulto",
    nl: "De lezer heeft een aanvraag voor raadpleging geannuleerd",
    el: "Ο/Η αναγνώστης/στρια ακύρωσε ένα αίτημα μελέτης"
  },
  "con.cancelStaff": {
    "pt-BR": "A biblioteca cancelou seu pedido de consulta local",
    fr: "La bibliothèque a annulé ta demande de consultation",
    es: "La biblioteca canceló tu pedido de consulta local",
    en: "The library cancelled your consultation request",
    it: "La biblioteca ha annullato la tua richiesta di consultazione",
    de: "Die Bibliothek hat deine Anfrage für Einsichtnahme storniert",
    ca: "La biblioteca ha cancel·lat la teva sol·licitud de consulta in situ",
    eo: "La biblioteko nuligis vian peton de surloka konsulto",
    nl: "De bibliotheek heeft je aanvraag voor raadpleging geannuleerd",
    el: "Η βιβλιοθήκη ακύρωσε το αίτημα μελέτης σου"
  },
  "con.expired": {
    "pt-BR": "Pedido de consulta local expirado",
    fr: "Demande de consultation expirée",
    es: "Pedido de consulta local expirado",
    en: "Consultation request expired",
    it: "Richiesta di consultazione scaduta",
    de: "Anfrage für Einsichtnahme abgelaufen",
    ca: "Sol·licitud de consulta in situ expirada",
    eo: "Peto de surloka konsulto eksvalidiĝinta",
    nl: "Aanvraag voor raadpleging verlopen",
    el: "Το αίτημα μελέτης έληξε"
  },

  // ===== Consulta workflow (cwf.*) =========================================
  "cwf.reader.scheduled": {
    "pt-BR": "A biblioteca propôs um horário para sua consulta local: {date}, das {time_start} às {time_end} ({tz}). Confirme se este horário funciona para você.",
    fr: "La bibliothèque te propose un horaire pour ta consultation : {date}, de {time_start} à {time_end} ({tz}). Confirme si cela te convient.",
    es: "La biblioteca te propone un horario para tu consulta: {date}, de {time_start} a {time_end} ({tz}). Confirmá si te conviene.",
    en: "The library has proposed a time slot for your consultation: {date}, from {time_start} to {time_end} ({tz}). Please confirm if this works for you.",
    it: "La biblioteca propone un orario per la tua consultazione: {date}, dalle {time_start} alle {time_end} ({tz}). Conferma se l'orario va bene.",
    de: "Die Bibliothek schlägt einen Termin für deine Einsichtnahme vor: {date}, von {time_start} bis {time_end} ({tz}). Bitte bestätige, ob das passt.",
    ca: "La biblioteca t'ha proposat un horari per a la teva consulta in situ: {date}, de {time_start} a {time_end} ({tz}). Confirma si aquest horari et va bé.",
    eo: "La biblioteko proponis al vi horon por via surloka konsulto: {date}, de {time_start} ĝis {time_end} ({tz}). Konfirmu ĉu ĉi tiu horo konvenas al vi.",
    nl: "De bibliotheek stelt een tijdstip voor je raadpleging voor: {date}, van {time_start} tot {time_end} ({tz}). Bevestig of dit je past.",
    el: "Η βιβλιοθήκη σου πρότεινε έναν χρόνο για τη μελέτη σου: {date}, από {time_start} έως {time_end} ({tz}). Επιβεβαίωσε αν σου ταιριάζει."
  },
  "cwf.reader.rescheduled": {
    "pt-BR": "A biblioteca atualizou o horário proposto para sua consulta local: {date}, das {time_start} às {time_end} ({tz}). Confirme se este novo horário funciona.",
    fr: "La bibliothèque a modifié l'horaire proposé pour ta consultation : {date}, de {time_start} à {time_end} ({tz}). Confirme si ce nouvel horaire te convient.",
    es: "La biblioteca actualizó el horario propuesto para tu consulta: {date}, de {time_start} a {time_end} ({tz}). Confirmá si este nuevo horario funciona.",
    en: "The library has updated the proposed time for your consultation: {date}, from {time_start} to {time_end} ({tz}). Please confirm if this new time works.",
    it: "La biblioteca ha aggiornato l'orario proposto per la tua consultazione: {date}, dalle {time_start} alle {time_end} ({tz}). Conferma se il nuovo orario va bene.",
    de: "Die Bibliothek hat den vorgeschlagenen Termin für deine Einsichtnahme aktualisiert: {date}, von {time_start} bis {time_end} ({tz}). Bitte bestätige, ob das neue Datum passt.",
    ca: "La biblioteca ha actualitzat l'horari proposat per a la teva consulta in situ: {date}, de {time_start} a {time_end} ({tz}). Confirma si aquest nou horari et va bé.",
    eo: "La biblioteko ĝisdatigis la proponitan horon por via surloka konsulto: {date}, de {time_start} ĝis {time_end} ({tz}). Konfirmu ĉu ĉi tiu nova horo konvenas.",
    nl: "De bibliotheek heeft het voorgestelde tijdstip voor je raadpleging gewijzigd: {date}, van {time_start} tot {time_end} ({tz}). Bevestig of dit nieuwe tijdstip je past.",
    el: "Η βιβλιοθήκη τροποποίησε τον προτεινόμενο χρόνο για τη μελέτη σου: {date}, από {time_start} έως {time_end} ({tz}). Επιβεβαίωσε αν σου ταιριάζει αυτός ο νέος χρόνος."
  },
  "cwf.staff.scheduled": {
    "pt-BR": "Horário proposto ao(à/e) leitor(a/e)",
    fr: "Horaire proposé au·à la lecteur·rice",
    es: "Horario propuesto a le lectore",
    en: "Time slot proposed to the reader",
    it: "Orario proposto a lettore/trice",
    de: "Termin an Leser*in vorgeschlagen",
    ca: "Horari proposat a le lector-a-e",
    eo: "Horo proponita al la legant-in-o",
    nl: "Tijdstip voorgesteld aan de lezer",
    el: "Χρόνος που προτάθηκε στον/στην αναγνώστη/στρια"
  },
  "cwf.staff.rescheduled": {
    "pt-BR": "Horário atualizado proposto ao(à/e) leitor(a/e)",
    fr: "Horaire modifié proposé au·à la lecteur·rice",
    es: "Horario actualizado propuesto a le lectore",
    en: "Updated time slot proposed to the reader",
    it: "Orario aggiornato proposto a lettore/trice",
    de: "Aktualisierter Termin an Leser*in vorgeschlagen",
    ca: "Horari actualitzat proposat a le lector-a-e",
    eo: "Ĝisdatigita horo proponita al la legant-in-o",
    nl: "Gewijzigd tijdstip voorgesteld aan de lezer",
    el: "Τροποποιημένος χρόνος που προτάθηκε στον/στην αναγνώστη/στρια"
  },
  "cwf.staff.readerConfirmed": {
    "pt-BR": "O(a/e) leitor(a/e) confirmou o horário proposto",
    fr: "Le·la lecteur·rice a confirmé l'horaire proposé",
    es: "Le lectore confirmó el horario propuesto",
    en: "The reader confirmed the proposed time slot",
    it: "Lettor* ha confermato l'orario proposto",
    de: "Leser*in hat den vorgeschlagenen Termin bestätigt",
    ca: "Le lector-a-e ha confirmat l'horari proposat",
    eo: "La legant-in-o konfirmis la proponitan horon",
    nl: "De lezer heeft het voorgestelde tijdstip bevestigd",
    el: "Ο/Η αναγνώστης/στρια επιβεβαίωσε τον προτεινόμενο χρόνο"
  },
  "cwf.staff.readerRefused": {
    "pt-BR": "O(a/e) leitor(a/e) recusou o horário proposto",
    fr: "Le·la lecteur·rice a refusé l'horaire proposé",
    es: "Le lectore rechazó el horario propuesto",
    en: "The reader declined the proposed time slot",
    it: "Lettor* ha rifiutato l'orario proposto",
    de: "Leser*in hat den vorgeschlagenen Termin abgelehnt",
    ca: "Le lector-a-e ha rebutjat l'horari proposat",
    eo: "La legant-in-o rifuzis la proponitan horon",
    nl: "De lezer heeft het voorgestelde tijdstip geweigerd",
    el: "Ο/Η αναγνώστης/στρια απέρριψε τον προτεινόμενο χρόνο"
  },
  // ===== Paquet 141.2 (16/05/2026) =====
  // Templates pour 2 nouveaux events workflow consultas :
  //   - em_preparacao (B2) : transition solicitada -> em_preparacao
  //   - nao_compareceu (B5) : transition vers nao_compareceu
  // Doctrine : la note workflow_note (si presente) est injectee comme
  // ligne supplementaire dans 'details' du renderEmail, pas dans le template.
  "cwf.reader.em_preparacao": {
    "pt-BR": "Sua solicitação de consulta local está em preparação. A biblioteca vai propor um horário em breve.",
    fr: "Ta demande de consultation est en préparation. La bibliothèque te proposera un horaire bientôt.",
    es: "Tu solicitud de consulta local está en preparación. La biblioteca propondrá un horario pronto.",
    en: "Your local consultation request is being prepared. The library will propose a time slot soon.",
    it: "La tua richiesta di consultazione locale è in preparazione. La biblioteca proporrà un orario a breve.",
    de: "Deine Anfrage zur lokalen Einsichtnahme wird vorbereitet. Die Bibliothek wird bald einen Termin vorschlagen.",
    ca: "La teva sol·licitud de consulta in situ s'està preparant. La biblioteca et proposarà un horari aviat.",
    eo: "Via peto de surloka konsulto estas preparata. La biblioteko baldaŭ proponos al vi horon.",
    nl: "Je aanvraag voor raadpleging wordt voorbereid. De bibliotheek stelt binnenkort een tijdstip voor.",
    el: "Το αίτημά σου για επιτόπια μελέτη προετοιμάζεται. Η βιβλιοθήκη θα σου προτείνει χρόνο σύντομα."
  },
  "cwf.reader.nao_compareceu": {
    "pt-BR": "Você foi marcado(a/e) como ausente na consulta local agendada para {date}, das {time_start} às {time_end}. A biblioteca tinha se preparado para te receber. Caso queira marcar um novo horário, entre em contato com a biblioteca.",
    fr: "Tu as été marqué·e comme absent·e à la consultation prévue le {date}, de {time_start} à {time_end}. La bibliothèque s'était préparée à t'accueillir. Si tu souhaites fixer un nouvel horaire, contacte la bibliothèque.",
    es: "Has sido marcado(a/e) como ausente en la consulta local programada para {date}, de {time_start} a {time_end}. La biblioteca se había preparado para recibirte. Si quieres fijar un nuevo horario, contactá a la biblioteca.",
    en: "You have been marked as absent for the local consultation scheduled on {date}, from {time_start} to {time_end}. The library had prepared to welcome you. If you wish to schedule a new time, please contact the library.",
    it: "Sei stat* segnalat* come assente alla consultazione locale prevista per il {date}, dalle {time_start} alle {time_end}. La biblioteca si era preparata ad accoglierti. Se desideri fissare un nuovo orario, contatta la biblioteca.",
    de: "Du wurdest als abwesend bei der lokalen Einsichtnahme am {date} von {time_start} bis {time_end} markiert. Die Bibliothek hatte sich darauf vorbereitet, dich zu empfangen. Wenn du einen neuen Termin vereinbaren möchtest, kontaktiere die Bibliothek.",
    ca: "Has estat marcat-da-e com a absent-a-e a la consulta in situ prevista per al {date}, de {time_start} a {time_end}. La biblioteca s'havia preparat per rebre't. Si vols fixar un nou horari, contacta la biblioteca.",
    eo: "Vi estis markita kiel forestanta ĉe la surloka konsulto planita por la {date}, de {time_start} ĝis {time_end}. La biblioteko estis preparinta sin por akcepti vin. Se vi deziras fiksi novan horon, kontaktu la bibliotekon.",
    nl: "Je bent gemarkeerd als afwezig voor de raadpleging ter plaatse die gepland was op {date}, van {time_start} tot {time_end}. De bibliotheek had zich voorbereid om je te ontvangen. Als je een nieuw tijdstip wilt afspreken, neem dan contact op met de bibliotheek.",
    el: "Σημειώθηκες ως απών/απούσα στην επιτόπια μελέτη που ήταν προγραμματισμένη στις {date}, από {time_start} έως {time_end}. Η βιβλιοθήκη είχε προετοιμαστεί να σε υποδεχτεί. Αν θέλεις να ορίσεις νέο χρόνο, επικοινώνησε με τη βιβλιοθήκη."
  },
  "cwf.staff.nao_compareceu": {
    "pt-BR": "Não comparecimento registrado",
    fr: "Non-présentation enregistrée",
    es: "No comparecencia registrada",
    en: "No-show recorded",
    it: "Mancata presentazione registrata",
    de: "Nichterscheinen erfasst",
    ca: "No-presentació registrada",
    eo: "Neapero registrita",
    nl: "Niet-verschijning geregistreerd",
    el: "Μη εμφάνιση καταγράφηκε"
  },
  "cwf.actionBox.replySlot": {
    "pt-BR": "Responder à proposta",
    fr: "Répondre à la proposition",
    es: "Responder a la propuesta",
    en: "Reply to the proposal",
    it: "Rispondi alla proposta",
    de: "Auf den Vorschlag antworten",
    ca: "Respondre a la proposta",
    eo: "Respondi al la propono",
    nl: "Reageer op het voorstel",
    el: "Απάντησε στην πρόταση"
  },
  "cwf.actionBox.preparePainel": {
    "pt-BR": "Abrir o painel",
    fr: "Ouvrir le painel",
    es: "Abrir el panel",
    en: "Open the panel",
    it: "Apri il pannello",
    de: "Panel öffnen",
    ca: "Obrir el tauler",
    eo: "Malfermi la panelon",
    nl: "Open het paneel",
    el: "Άνοιγμα του πίνακα"
  },
  // Section #114.A : labels et valeurs de vote pour la cooptation reseau
  "l.vote": {
    "pt-BR": "Voto",
    fr: "Vote",
    es: "Voto",
    en: "Vote",
    it: "Voto",
    de: "Stimme",
    ca: "Vot",
    eo: "Voĉdono",
    nl: "Stem",
    el: "Ψήφος"
  },
  "l.voter": {
    "pt-BR": "Voto emitido por",
    fr: "Vote émis par",
    es: "Voto emitido por",
    en: "Vote cast by",
    it: "Voto espresso da",
    de: "Stimme abgegeben von",
    ca: "Vot emès per",
    eo: "Voĉdono donita de",
    nl: "Stem uitgebracht door",
    el: "Ψήφος από"
  },
  "l.proposer": {
    "pt-BR": "Proposta por",
    fr: "Proposée par",
    es: "Propuesta por",
    en: "Proposed by",
    it: "Proposta da",
    de: "Vorgeschlagen von",
    ca: "Proposada per",
    eo: "Proponita de",
    nl: "Voorgesteld door",
    el: "Προτάθηκε από"
  },
  // ===== TM-B (#153.B) — libelles de details mails admin team.* =====
  "l.target": {
    "pt-BR": "Pessoa concernida",
    fr: "Personne concernée",
    es: "Persona concernida",
    en: "Person concerned",
    it: "Persona interessata",
    de: "Betroffene Person",
    ca: "Persona concernida",
    eo: "Koncernata persono",
    nl: "Betrokken persoon",
    el: "Εμπλεκόμενο άτομο"
  },
  "l.actor": {
    "pt-BR": "Autor-a-e da ação",
    fr: "Auteur·rice de l'action",
    es: "Autor(a/e) de la acción",
    en: "Action taken by",
    it: "Autore/trice dell'azione",
    de: "Ausführende Person",
    ca: "Autor(a/e) de l'acció",
    eo: "Aŭtoro de la ago",
    nl: "Actie uitgevoerd door",
    el: "Ενέργεια από"
  },
  "l.cancelledBy": {
    "pt-BR": "Anulado por",
    fr: "Annulé par",
    es: "Anulado por",
    en: "Cancelled by",
    it: "Annullato da",
    de: "Aufgehoben von",
    ca: "Anul·lat per",
    eo: "Nuligita de",
    nl: "Geannuleerd door",
    el: "Ακυρώθηκε από"
  },
  "l.library": {
    "pt-BR": "Biblioteca",
    fr: "Bibliothèque",
    es: "Biblioteca",
    en: "Library",
    it: "Biblioteca",
    de: "Bibliothek",
    ca: "Biblioteca",
    eo: "Biblioteko",
    nl: "Bibliotheek",
    el: "Βιβλιοθήκη"
  },
  "l.role": {
    "pt-BR": "Papel",
    fr: "Rôle",
    es: "Rol",
    en: "Role",
    it: "Ruolo",
    de: "Rolle",
    ca: "Rol",
    eo: "Rolo",
    nl: "Rol",
    el: "Ρόλος"
  },
  "l.roleConcerned": {
    "pt-BR": "Papel concernido",
    fr: "Rôle concerné",
    es: "Rol concernido",
    en: "Role concerned",
    it: "Ruolo interessato",
    de: "Betroffene Rolle",
    ca: "Rol concernit",
    eo: "Koncernata rolo",
    nl: "Betrokken rol",
    el: "Σχετικός ρόλος"
  },
  "l.roleRemoved": {
    "pt-BR": "Papel retirado",
    fr: "Rôle retiré",
    es: "Rol retirado",
    en: "Role removed",
    it: "Ruolo rimosso",
    de: "Entzogene Rolle",
    ca: "Rol retirat",
    eo: "Forigita rolo",
    nl: "Verwijderde rol",
    el: "Ρόλος που αφαιρέθηκε"
  },
  "l.roleFrom": {
    "pt-BR": "Papel anterior",
    fr: "Ancien rôle",
    es: "Rol anterior",
    en: "Previous role",
    it: "Ruolo precedente",
    de: "Bisherige Rolle",
    ca: "Rol anterior",
    eo: "Antaŭa rolo",
    nl: "Vorige rol",
    el: "Προηγούμενος ρόλος"
  },
  "l.roleTo": {
    "pt-BR": "Novo papel",
    fr: "Nouveau rôle",
    es: "Nuevo rol",
    en: "New role",
    it: "Nuovo ruolo",
    de: "Neue Rolle",
    ca: "Nou rol",
    eo: "Nova rolo",
    nl: "Nieuwe rol",
    el: "Νέος ρόλος"
  },
  "l.gracePeriodEnd": {
    "pt-BR": "Fim do prazo de carência",
    fr: "Fin du délai de carence",
    es: "Fin del plazo de gracia",
    en: "End of grace period",
    it: "Fine del periodo di tolleranza",
    de: "Ende der Kulanzfrist",
    ca: "Fi del termini de gràcia",
    eo: "Fino de la prokrastperiodo",
    nl: "Einde van de respijtperiode",
    el: "Τέλος περιόδου χάριτος"
  },
  // ===== TR-4 (#153.B) — libelles des mails internes register =====
  "l.publicId": {
    "pt-BR": "ID público",
    fr: "ID public",
    es: "ID público",
    en: "Public ID",
    it: "ID pubblico",
    de: "Öffentliche ID",
    ca: "ID públic",
    eo: "Publika ID",
    nl: "Openbare ID",
    el: "Δημόσιο ID"
  },
  "l.name": {
    "pt-BR": "Nome",
    fr: "Nom",
    es: "Nombre",
    en: "Name",
    it: "Nome",
    de: "Name",
    ca: "Nom",
    eo: "Nomo",
    nl: "Naam",
    el: "Όνομα"
  },
  "l.email": {
    "pt-BR": "E-mail",
    fr: "E-mail",
    es: "Correo electrónico",
    en: "Email",
    it: "E-mail",
    de: "E-Mail",
    ca: "Correu electrònic",
    eo: "Retpoŝto",
    nl: "E-mail",
    el: "Email"
  },
  "l.phone": {
    "pt-BR": "Telefone",
    fr: "Téléphone",
    es: "Teléfono",
    en: "Phone",
    it: "Telefono",
    de: "Telefon",
    ca: "Telèfon",
    eo: "Telefono",
    nl: "Telefoon",
    el: "Τηλέφωνο"
  },
  "l.address": {
    "pt-BR": "Endereço informado",
    fr: "Adresse renseignée",
    es: "Dirección indicada",
    en: "Address provided",
    it: "Indirizzo fornito",
    de: "Angegebene Adresse",
    ca: "Adreça indicada",
    eo: "Indikita adreso",
    nl: "Opgegeven adres",
    el: "Δηλωμένη διεύθυνση"
  },
  "l.registrationDate": {
    "pt-BR": "Data do cadastro",
    fr: "Date d'inscription",
    es: "Fecha de registro",
    en: "Registration date",
    it: "Data di registrazione",
    de: "Anmeldedatum",
    ca: "Data de registre",
    eo: "Dato de registriĝo",
    nl: "Inschrijvingsdatum",
    el: "Ημερομηνία εγγραφής"
  },
  "l.testContext": {
    "pt-BR": "Contexto de teste",
    fr: "Contexte de test",
    es: "Contexto de prueba",
    en: "Test context",
    it: "Contesto di test",
    de: "Testkontext",
    ca: "Context de prova",
    eo: "Testa kunteksto",
    nl: "Testcontext",
    el: "Πλαίσιο δοκιμής"
  },
  "l.organization": {
    "pt-BR": "Organização / coletivo",
    fr: "Organisation / collectif",
    es: "Organización / colectivo",
    en: "Organization / collective",
    it: "Organizzazione / collettivo",
    de: "Organisation / Kollektiv",
    ca: "Organització / col·lectiu",
    eo: "Organizo / kolektivo",
    nl: "Organisatie / collectief",
    el: "Οργάνωση / συλλογικότητα"
  },
  "l.motivation": {
    "pt-BR": "Motivação",
    fr: "Motivation",
    es: "Motivación",
    en: "Motivation",
    it: "Motivazione",
    de: "Beweggrund",
    ca: "Motivació",
    eo: "Motivo",
    nl: "Motivatie",
    el: "Κίνητρο"
  },
  "authority.proposal_opened.subject": { "pt-BR": "Nova proposta no acervo de autoridades", "fr": "Nouvelle proposition dans le corpus d'autorités", "es": "Nueva propuesta en el corpus de autoridades", "en": "New proposal in the authorities corpus", "it": "New proposal in the authorities corpus", "de": "New proposal in the authorities corpus", "ca": "New proposal in the authorities corpus", "eo": "New proposal in the authorities corpus", "nl": "New proposal in the authorities corpus", "el": "New proposal in the authorities corpus" },
  "authority.proposal_opened.intro": { "pt-BR": "Uma proposta de contribuição foi aberta sobre uma autoridade que sua biblioteca utiliza. Sem objeção motivada até o prazo, ela será aplicada por consentimento.", "fr": "Une proposition de contribution vient d'être ouverte sur une autorité que ta bibliothèque utilise. Sans objection motivée avant l'échéance, elle sera appliquée par consentement.", "es": "Se ha abierto una propuesta de contribución sobre una autoridad que tu biblioteca utiliza. Sin objeción motivada antes del plazo, se aplicará por consentimiento.", "en": "A contribution proposal has been opened on an authority your library uses. Without a motivated objection before the deadline, it will be applied by consent.", "it": "A contribution proposal has been opened on an authority your library uses. Without a motivated objection before the deadline, it will be applied by consent.", "de": "A contribution proposal has been opened on an authority your library uses. Without a motivated objection before the deadline, it will be applied by consent.", "ca": "A contribution proposal has been opened on an authority your library uses. Without a motivated objection before the deadline, it will be applied by consent.", "eo": "A contribution proposal has been opened on an authority your library uses. Without a motivated objection before the deadline, it will be applied by consent.", "nl": "A contribution proposal has been opened on an authority your library uses. Without a motivated objection before the deadline, it will be applied by consent.", "el": "A contribution proposal has been opened on an authority your library uses. Without a motivated objection before the deadline, it will be applied by consent." },
  "authority.proposal_objected.subject": { "pt-BR": "Objeção registrada em uma proposta", "fr": "Objection déposée sur une proposition", "es": "Objeción registrada en una propuesta", "en": "Objection filed on a proposal", "it": "Objection filed on a proposal", "de": "Objection filed on a proposal", "ca": "Objection filed on a proposal", "eo": "Objection filed on a proposal", "nl": "Objection filed on a proposal", "el": "Objection filed on a proposal" },
  "authority.proposal_objected.intro": { "pt-BR": "Uma objeção motivada foi registrada sobre uma proposta. A discussão permanece aberta (anti-blackball).", "fr": "Une objection motivée a été déposée sur une proposition. La discussion reste ouverte (anti-blackball).", "es": "Se ha registrado una objeción motivada sobre una propuesta. La discusión permanece abierta (anti-blackball).", "en": "A motivated objection has been filed on a proposal. The discussion stays open (anti-blackball).", "it": "A motivated objection has been filed on a proposal. The discussion stays open (anti-blackball).", "de": "A motivated objection has been filed on a proposal. The discussion stays open (anti-blackball).", "ca": "A motivated objection has been filed on a proposal. The discussion stays open (anti-blackball).", "eo": "A motivated objection has been filed on a proposal. The discussion stays open (anti-blackball).", "nl": "A motivated objection has been filed on a proposal. The discussion stays open (anti-blackball).", "el": "A motivated objection has been filed on a proposal. The discussion stays open (anti-blackball)." },
  "authority.proposal_resolved_consent.subject": { "pt-BR": "Proposta aceita por consentimento", "fr": "Proposition adoptée par consentement", "es": "Propuesta aceptada por consentimiento", "en": "Proposal accepted by consent", "it": "Proposal accepted by consent", "de": "Proposal accepted by consent", "ca": "Proposal accepted by consent", "eo": "Proposal accepted by consent", "nl": "Proposal accepted by consent", "el": "Proposal accepted by consent" },
  "authority.proposal_resolved_consent.intro": { "pt-BR": "O prazo terminou sem objeção: a proposta foi aceita por consentimento. Um membro da equipe poderá aplicá-la.", "fr": "L'échéance est passée sans objection : la proposition est adoptée par consentement. Un membre de l'équipe pourra l'appliquer.", "es": "El plazo terminó sin objeción: la propuesta fue aceptada por consentimiento. Un miembro del equipo podrá aplicarla.", "en": "The deadline passed without objection: the proposal is accepted by consent. A team member may apply it.", "it": "The deadline passed without objection: the proposal is accepted by consent. A team member may apply it.", "de": "The deadline passed without objection: the proposal is accepted by consent. A team member may apply it.", "ca": "The deadline passed without objection: the proposal is accepted by consent. A team member may apply it.", "eo": "The deadline passed without objection: the proposal is accepted by consent. A team member may apply it.", "nl": "The deadline passed without objection: the proposal is accepted by consent. A team member may apply it.", "el": "The deadline passed without objection: the proposal is accepted by consent. A team member may apply it." },
  "authority.proposal_refused.subject": { "pt-BR": "Proposta recusada", "fr": "Proposition refusée", "es": "Propuesta rechazada", "en": "Proposal refused", "it": "Proposal refused", "de": "Proposal refused", "ca": "Proposal refused", "eo": "Proposal refused", "nl": "Proposal refused", "el": "Proposal refused" },
  "authority.proposal_refused.intro": { "pt-BR": "Sua proposta foi recusada após objeção(ões) motivada(s). A motivação está indicada abaixo.", "fr": "Ta proposition a été refusée suite à une ou des objections motivées. La motivation est indiquée ci-dessous.", "es": "Tu propuesta fue rechazada tras una o varias objeciones motivadas. La motivación se indica a continuación.", "en": "Your proposal was refused after one or more motivated objections. The reason is shown below.", "it": "Your proposal was refused after one or more motivated objections. The reason is shown below.", "de": "Your proposal was refused after one or more motivated objections. The reason is shown below.", "ca": "Your proposal was refused after one or more motivated objections. The reason is shown below.", "eo": "Your proposal was refused after one or more motivated objections. The reason is shown below.", "nl": "Your proposal was refused after one or more motivated objections. The reason is shown below.", "el": "Your proposal was refused after one or more motivated objections. The reason is shown below." },
  "authority.merge_executed.subject": { "pt-BR": "Fusão aplicada no acervo de autoridades", "fr": "Fusion appliquée dans le corpus d'autorités", "es": "Fusión aplicada en el corpus de autoridades", "en": "Merge applied in the authorities corpus", "it": "Merge applied in the authorities corpus", "de": "Merge applied in the authorities corpus", "ca": "Merge applied in the authorities corpus", "eo": "Merge applied in the authorities corpus", "nl": "Merge applied in the authorities corpus", "el": "Merge applied in the authorities corpus" },
  "authority.merge_executed.intro": { "pt-BR": "Uma fusão de duplicata foi aplicada em uma autoridade que sua biblioteca utiliza.", "fr": "Une fusion de doublon a été appliquée sur une autorité que ta bibliothèque utilise.", "es": "Se aplicó una fusión de duplicado en una autoridad que tu biblioteca utiliza.", "en": "A duplicate merge was applied on an authority your library uses.", "it": "A duplicate merge was applied on an authority your library uses.", "de": "A duplicate merge was applied on an authority your library uses.", "ca": "A duplicate merge was applied on an authority your library uses.", "eo": "A duplicate merge was applied on an authority your library uses.", "nl": "A duplicate merge was applied on an authority your library uses.", "el": "A duplicate merge was applied on an authority your library uses." },
  "authority.edit_applied.subject": { "pt-BR": "Edição aplicada no acervo de autoridades", "fr": "Édition appliquée dans le corpus d'autorités", "es": "Edición aplicada en el corpus de autoridades", "en": "Edit applied in the authorities corpus", "it": "Edit applied in the authorities corpus", "de": "Edit applied in the authorities corpus", "ca": "Edit applied in the authorities corpus", "eo": "Edit applied in the authorities corpus", "nl": "Edit applied in the authorities corpus", "el": "Edit applied in the authorities corpus" },
  "authority.edit_applied.intro": { "pt-BR": "Uma edição foi aplicada em uma autoridade que sua biblioteca utiliza.", "fr": "Une édition a été appliquée sur une autorité que ta bibliothèque utilise.", "es": "Se aplicó una edición en una autoridad que tu biblioteca utiliza.", "en": "An edit was applied on an authority your library uses.", "it": "An edit was applied on an authority your library uses.", "de": "An edit was applied on an authority your library uses.", "ca": "An edit was applied on an authority your library uses.", "eo": "An edit was applied on an authority your library uses.", "nl": "An edit was applied on an authority your library uses.", "el": "An edit was applied on an authority your library uses." },
  "authority.label.kind": { "pt-BR": "Tipo de proposta", "fr": "Type de proposition", "es": "Tipo de propuesta", "en": "Proposal type", "it": "Proposal type", "de": "Proposal type", "ca": "Proposal type", "eo": "Proposal type", "nl": "Proposal type", "el": "Proposal type" },
  "authority.label.authority": { "pt-BR": "Autoridade", "fr": "Autorité", "es": "Autoridad", "en": "Authority", "it": "Authority", "de": "Authority", "ca": "Authority", "eo": "Authority", "nl": "Authority", "el": "Authority" },
  "authority.label.reason": { "pt-BR": "Motivação", "fr": "Motivation", "es": "Motivación", "en": "Reason", "it": "Reason", "de": "Reason", "ca": "Reason", "eo": "Reason", "nl": "Reason", "el": "Reason" },
  "authority.kind.creation": { "pt-BR": "Criação", "fr": "Création", "es": "Creación", "en": "Creation", "it": "Creation", "de": "Creation", "ca": "Creation", "eo": "Creation", "nl": "Creation", "el": "Creation" },
  "authority.kind.edition": { "pt-BR": "Edição", "fr": "Édition", "es": "Edición", "en": "Edit", "it": "Edit", "de": "Edit", "ca": "Edit", "eo": "Edit", "nl": "Edit", "el": "Edit" },
  "authority.kind.fusion": { "pt-BR": "Fusão", "fr": "Fusion", "es": "Fusión", "en": "Merge", "it": "Merge", "de": "Merge", "ca": "Merge", "eo": "Merge", "nl": "Merge", "el": "Merge" },
  "authority.kind.traduction": { "pt-BR": "Tradução", "fr": "Traduction", "es": "Traducción", "en": "Translation", "it": "Translation", "de": "Translation", "ca": "Translation", "eo": "Translation", "nl": "Translation", "el": "Translation" },
  "authority.action.title": { "pt-BR": "Oficina de autoridades", "fr": "Atelier des autorités", "es": "Taller de autoridades", "en": "Authorities workshop", "it": "Authorities workshop", "de": "Authorities workshop", "ca": "Authorities workshop", "eo": "Authorities workshop", "nl": "Authorities workshop", "el": "Authorities workshop" },
  "authority.action.cta": { "pt-BR": "Abrir a oficina", "fr": "Ouvrir l'atelier", "es": "Abrir el taller", "en": "Open the workshop", "it": "Open the workshop", "de": "Open the workshop", "ca": "Open the workshop", "eo": "Open the workshop", "nl": "Open the workshop", "el": "Open the workshop" },
  "welcome.context.contributor": { "pt-BR": "Sua conta de contribuinte foi criada. Você integra a equipe de contribuição do AnarBib: ajude a melhorar o acervo compartilhado de autoridades (pessoas, coletividades, matérias) propondo fusões, correções e traduções. Não é preciso ter biblioteca para isso.", "fr": "Ton compte de contributeur·rice est créé. Tu rejoins l'équipe de contribution d'AnarBib : aide à améliorer le corpus partagé d'autorités (personnes, collectivités, matières) en proposant des fusions, des corrections et des traductions. Pas besoin de bibliothèque pour cela.", "es": "Tu cuenta de colaboración ha sido creada. Te unes al equipo de contribución de AnarBib: ayuda a mejorar el corpus compartido de autoridades (personas, colectividades, materias) proponiendo fusiones, correcciones y traducciones. No hace falta tener biblioteca para ello.", "en": "Your contributor account has been created. You're joining AnarBib's contribution team: help improve the shared authorities corpus (people, collectivities, subjects) by proposing merges, corrections and translations. No library is needed for that.", "it": "Your contributor account has been created. You're joining AnarBib's contribution team: help improve the shared authorities corpus (people, collectivities, subjects) by proposing merges, corrections and translations. No library is needed for that.", "de": "Your contributor account has been created. You're joining AnarBib's contribution team: help improve the shared authorities corpus (people, collectivities, subjects) by proposing merges, corrections and translations. No library is needed for that.", "ca": "Your contributor account has been created. You're joining AnarBib's contribution team: help improve the shared authorities corpus (people, collectivities, subjects) by proposing merges, corrections and translations. No library is needed for that.", "eo": "Your contributor account has been created. You're joining AnarBib's contribution team: help improve the shared authorities corpus (people, collectivities, subjects) by proposing merges, corrections and translations. No library is needed for that.", "nl": "Your contributor account has been created. You're joining AnarBib's contribution team: help improve the shared authorities corpus (people, collectivities, subjects) by proposing merges, corrections and translations. No library is needed for that.", "el": "Your contributor account has been created. You're joining AnarBib's contribution team: help improve the shared authorities corpus (people, collectivities, subjects) by proposing merges, corrections and translations. No library is needed for that." },
  "welcome.contributor.atelierCta": { "pt-BR": "Abrir a oficina de contribuição", "fr": "Ouvrir l'atelier de contribution", "es": "Abrir el taller de contribución", "en": "Open the contribution workshop", "it": "Open the contribution workshop", "de": "Open the contribution workshop", "ca": "Open the contribution workshop", "eo": "Open the contribution workshop", "nl": "Open the contribution workshop", "el": "Open the contribution workshop" },
  "welcome.contributor.catalogIntro": { "pt-BR": "Você também pode explorar o acervo compartilhado:", "fr": "Tu peux aussi explorer le catalogue partagé :", "es": "También puedes explorar el catálogo compartido:", "en": "You can also browse the shared catalog:", "it": "You can also browse the shared catalog:", "de": "You can also browse the shared catalog:", "ca": "You can also browse the shared catalog:", "eo": "You can also browse the shared catalog:", "nl": "You can also browse the shared catalog:", "el": "You can also browse the shared catalog:" },
  "welcome.pretitle.contributor": { "pt-BR": "CONTA DE CONTRIBUINTE", "fr": "COMPTE CONTRIBUTEUR·RICE", "es": "CUENTA DE COLABORACIÓN", "en": "CONTRIBUTOR ACCOUNT", "it": "CONTRIBUTOR ACCOUNT", "de": "CONTRIBUTOR ACCOUNT", "ca": "CONTRIBUTOR ACCOUNT", "eo": "CONTRIBUTOR ACCOUNT", "nl": "CONTRIBUTOR ACCOUNT", "el": "CONTRIBUTOR ACCOUNT" },
  "welcome.title.contributor": { "pt-BR": "Bem-vinde à equipe de contribuição", "fr": "Bienvenue dans l'équipe de contribution", "es": "Bienvenide al equipo de contribución", "en": "Welcome to the contribution team", "it": "Welcome to the contribution team", "de": "Welcome to the contribution team", "ca": "Welcome to the contribution team", "eo": "Welcome to the contribution team", "nl": "Welcome to the contribution team", "el": "Welcome to the contribution team" },
  "welcome.subtitle.contributor": { "pt-BR": "Sua conta de contribuinte do AnarBib está pronta.", "fr": "Ton compte de contributeur·rice AnarBib est prêt.", "es": "Tu cuenta de colaboración en AnarBib está lista.", "en": "Your AnarBib contributor account is ready.", "it": "Your AnarBib contributor account is ready.", "de": "Your AnarBib contributor account is ready.", "ca": "Your AnarBib contributor account is ready.", "eo": "Your AnarBib contributor account is ready.", "nl": "Your AnarBib contributor account is ready.", "el": "Your AnarBib contributor account is ready." },
  "welcome.subject.contributor": { "pt-BR": "Bem-vinde à equipe de contribuição do AnarBib", "fr": "Bienvenue dans l'équipe de contribution d'AnarBib", "es": "Bienvenide al equipo de contribución de AnarBib", "en": "Welcome to the AnarBib contribution team", "it": "Welcome to the AnarBib contribution team", "de": "Welcome to the AnarBib contribution team", "ca": "Welcome to the AnarBib contribution team", "eo": "Welcome to the AnarBib contribution team", "nl": "Welcome to the AnarBib contribution team", "el": "Welcome to the AnarBib contribution team" },
  "register.internal.title.contributor": { "pt-BR": "Novo contribuinte de rede", "fr": "Nouveau·elle contributeur·rice de réseau", "es": "Nuevo·a colaborador·e de red", "en": "New network contributor", "it": "New network contributor", "de": "New network contributor", "ca": "New network contributor", "eo": "New network contributor", "nl": "New network contributor", "el": "New network contributor" },
  "register.internal.subtitle.contributor": { "pt-BR": "Novo·a contribuinte de rede (sem biblioteca), ID {publicId}.", "fr": "Nouveau·elle contributeur·rice de réseau (sans bibliothèque), ID {publicId}.", "es": "Nuevo·a colaborador·e de red (sin biblioteca), ID {publicId}.", "en": "New network contributor (no library), ID {publicId}.", "it": "New network contributor (no library), ID {publicId}.", "de": "New network contributor (no library), ID {publicId}.", "ca": "New network contributor (no library), ID {publicId}.", "eo": "New network contributor (no library), ID {publicId}.", "nl": "New network contributor (no library), ID {publicId}.", "el": "New network contributor (no library), ID {publicId}." },
  "network.cooptation_voted.cta": {
    "pt-BR": "Acessar a proposta e votar",
    fr: "Accéder à la proposition et voter",
    es: "Acceder a la propuesta y votar",
    en: "Open the proposal and vote",
    it: "Accedere alla proposta e votare",
    de: "Vorschlag öffnen und abstimmen",
    ca: "Accedir a la proposta i votar",
    eo: "Aliri la proponon kaj voĉdoni",
    nl: "Open het voorstel en stem",
    el: "Άνοιξε την πρόταση και ψήφισε"
  },
  "network.vote.favorable": {
    "pt-BR": "favorável",
    fr: "favorable",
    es: "favorable",
    en: "in favour",
    it: "favorevole",
    de: "dafür",
    ca: "favorable",
    eo: "favora",
    nl: "voor",
    el: "υπέρ"
  },
  "network.vote.opposed": {
    "pt-BR": "contrário",
    fr: "défavorable",
    es: "contrario",
    en: "against",
    it: "contrario",
    de: "dagegen",
    ca: "contrari",
    eo: "kontraŭa",
    nl: "tegen",
    el: "κατά"
  },
  "network.vote.abstain": {
    "pt-BR": "abstenção",
    fr: "abstention",
    es: "abstención",
    en: "abstention",
    it: "astensione",
    de: "Enthaltung",
    ca: "abstenció",
    eo: "sindeteno",
    nl: "onthouding",
    el: "αποχή"
  },
  // ===== B.5 — library_profile : sujets ====================================
  "library_profile.proposed.sub": {
    "pt-BR": "{libraryName}: nova proposta de transição em {axisLoc}",
    fr: "{libraryName} : nouvelle proposition de transition — {axisLoc}",
    es: "{libraryName}: nueva propuesta de transición — {axisLoc}",
    en: "{libraryName}: new transition proposal — {axisLoc}",
    it: "{libraryName}: nuova proposta di transizione — {axisLoc}",
    de: "{libraryName}: neuer Übergangsvorschlag — {axisLoc}",
    ca: "{libraryName}: nova proposta de transició — {axisLoc}",
    eo: "{libraryName}: nova transir-propono — {axisLoc}",
    nl: "{libraryName}: nieuw overgangsvoorstel — {axisLoc}",
    el: "{libraryName}: νέα πρόταση μετάβασης — {axisLoc}"
  },
  "library_profile.voted.sub": {
    "pt-BR": "{libraryName}: novo voto sobre {axisLoc}",
    fr: "{libraryName} : nouveau vote sur {axisLoc}",
    es: "{libraryName}: nuevo voto sobre {axisLoc}",
    en: "{libraryName}: new vote on {axisLoc}",
    it: "{libraryName}: nuovo voto su {axisLoc}",
    de: "{libraryName}: neue Stimme zu {axisLoc}",
    ca: "{libraryName}: nou vot sobre {axisLoc}",
    eo: "{libraryName}: nova voĉdono pri {axisLoc}",
    nl: "{libraryName}: nieuwe stem over {axisLoc}",
    el: "{libraryName}: νέα ψήφος για {axisLoc}"
  },
  "library_profile.accepted.sub": {
    "pt-BR": "{libraryName}: transição em {axisLoc} aprovada coletivamente",
    fr: "{libraryName} : transition sur {axisLoc} acceptée collectivement",
    es: "{libraryName}: transición sobre {axisLoc} aceptada colectivamente",
    en: "{libraryName}: transition on {axisLoc} accepted collectively",
    it: "{libraryName}: transizione su {axisLoc} accettata collettivamente",
    de: "{libraryName}: Übergang zu {axisLoc} kollektiv angenommen",
    ca: "{libraryName}: transició sobre {axisLoc} acceptada col·lectivament",
    eo: "{libraryName}: transiro pri {axisLoc} kolektive akceptita",
    nl: "{libraryName}: overgang op {axisLoc} collectief aanvaard",
    el: "{libraryName}: η μετάβαση για {axisLoc} έγινε αποδεκτή συλλογικά"
  },
  "library_profile.rejected.sub": {
    "pt-BR": "{libraryName}: proposta em {axisLoc} não passou",
    fr: "{libraryName} : proposition sur {axisLoc} non retenue",
    es: "{libraryName}: propuesta sobre {axisLoc} no aceptada",
    en: "{libraryName}: proposal on {axisLoc} did not pass",
    it: "{libraryName}: proposta su {axisLoc} non accettata",
    de: "{libraryName}: Vorschlag zu {axisLoc} nicht angenommen",
    ca: "{libraryName}: proposta sobre {axisLoc} no acceptada",
    eo: "{libraryName}: propono pri {axisLoc} ne sukcesis",
    nl: "{libraryName}: voorstel over {axisLoc} niet aangenomen",
    el: "{libraryName}: η πρόταση για {axisLoc} δεν πέρασε"
  },
  "library_profile.cancelled.sub": {
    "pt-BR": "{libraryName}: proposta em {axisLoc} retirada pel(o/a/e) proponente",
    fr: "{libraryName} : proposition sur {axisLoc} retirée par le·la proposant·e",
    es: "{libraryName}: propuesta sobre {axisLoc} retirada por le proponente",
    en: "{libraryName}: proposal on {axisLoc} withdrawn by the proposer",
    it: "{libraryName}: proposta su {axisLoc} ritirata dal/dalla proponente",
    de: "{libraryName}: Vorschlag zu {axisLoc} von der*dem Vorschlagenden zurückgezogen",
    ca: "{libraryName}: proposta sobre {axisLoc} retirada per le proposant-a-e",
    eo: "{libraryName}: propono pri {axisLoc} retirita de la propon-int-o",
    nl: "{libraryName}: voorstel over {axisLoc} ingetrokken door de indiener",
    el: "{libraryName}: η πρόταση για {axisLoc} αποσύρθηκε από τον/την προτείνοντα/ουσα"
  },
  "library_profile.executed.sub": {
    "pt-BR": "{libraryName}: transição em {axisLoc} agora em vigor",
    fr: "{libraryName} : transition sur {axisLoc} désormais en vigueur",
    es: "{libraryName}: transición sobre {axisLoc} ahora en vigor",
    en: "{libraryName}: transition on {axisLoc} now in effect",
    it: "{libraryName}: transizione su {axisLoc} ora in vigore",
    de: "{libraryName}: Übergang zu {axisLoc} jetzt in Kraft",
    ca: "{libraryName}: transició sobre {axisLoc} ara en vigor",
    eo: "{libraryName}: transiro pri {axisLoc} nun en vigoro",
    nl: "{libraryName}: overgang op {axisLoc} nu van kracht",
    el: "{libraryName}: η μετάβαση για {axisLoc} είναι πλέον σε ισχύ"
  },

  // ===== B.5 — library_profile : intros ====================================
  "library_profile.proposed.intro": {
    "pt-BR": "<b>{proposerName}</b> abriu uma proposta para que <b>{libraryName}</b> mude seu <b>{axisLoc}</b>, passando de <i>{oldValueLoc}</i> para <b>{newValueLoc}</b>. A equipe é convidada a deliberar e votar.",
    fr: "<b>{proposerName}</b> a ouvert une proposition pour que <b>{libraryName}</b> change son <b>{axisLoc}</b>, passant de <i>{oldValueLoc}</i> à <b>{newValueLoc}</b>. L'équipe est invitée à délibérer et à voter.",
    es: "<b>{proposerName}</b> abrió una propuesta para que <b>{libraryName}</b> cambie su <b>{axisLoc}</b>, pasando de <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>. Le invitamos al equipo a deliberar y votar.",
    en: "<b>{proposerName}</b> opened a proposal for <b>{libraryName}</b> to change its <b>{axisLoc}</b>, moving from <i>{oldValueLoc}</i> to <b>{newValueLoc}</b>. The team is invited to deliberate and vote.",
    it: "<b>{proposerName}</b> ha aperto una proposta affinché <b>{libraryName}</b> cambi il suo <b>{axisLoc}</b>, passando da <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>. L'equipe è invitata a deliberare e votare.",
    de: "<b>{proposerName}</b> hat einen Vorschlag eröffnet, damit <b>{libraryName}</b> seinen <b>{axisLoc}</b> ändert, von <i>{oldValueLoc}</i> zu <b>{newValueLoc}</b>. Das Team ist eingeladen, zu beraten und abzustimmen.",
    ca: "<b>{proposerName}</b> ha obert una proposta perquè <b>{libraryName}</b> canviï el seu <b>{axisLoc}</b>, passant de <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>. S'invita l'equip a deliberar i votar.",
    eo: "<b>{proposerName}</b> malfermis proponon por ke <b>{libraryName}</b> ŝanĝu sian <b>{axisLoc}</b>, transirante de <i>{oldValueLoc}</i> al <b>{newValueLoc}</b>. La teamo estas invitita pridiskuti kaj voĉdoni.",
    nl: "<b>{proposerName}</b> heeft een voorstel geopend om <b>{libraryName}</b> zijn <b>{axisLoc}</b> te laten wijzigen, van <i>{oldValueLoc}</i> naar <b>{newValueLoc}</b>. Het team wordt uitgenodigd om te beraadslagen en te stemmen.",
    el: "Ο/Η <b>{proposerName}</b> άνοιξε πρόταση ώστε η <b>{libraryName}</b> να αλλάξει τον/το <b>{axisLoc}</b>, μετακινούμενη από <i>{oldValueLoc}</i> σε <b>{newValueLoc}</b>. Η ομάδα καλείται να διαβουλευτεί και να ψηφίσει."
  },
  "library_profile.voted.intro": {
    "pt-BR": "<b>{voterName}</b> votou <b>{voteLoc}</b> sobre a proposta de mudança em <b>{axisLoc}</b> da <b>{libraryName}</b> (de <i>{oldValueLoc}</i> para <b>{newValueLoc}</b>).",
    fr: "<b>{voterName}</b> a voté <b>{voteLoc}</b> sur la proposition de transition de <b>{axisLoc}</b> de <b>{libraryName}</b> (de <i>{oldValueLoc}</i> vers <b>{newValueLoc}</b>).",
    es: "<b>{voterName}</b> votó <b>{voteLoc}</b> sobre la propuesta de transición de <b>{axisLoc}</b> de <b>{libraryName}</b> (de <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>).",
    en: "<b>{voterName}</b> voted <b>{voteLoc}</b> on the transition proposal for <b>{axisLoc}</b> at <b>{libraryName}</b> (from <i>{oldValueLoc}</i> to <b>{newValueLoc}</b>).",
    it: "<b>{voterName}</b> ha votato <b>{voteLoc}</b> sulla proposta di transizione di <b>{axisLoc}</b> a <b>{libraryName}</b> (da <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>).",
    de: "<b>{voterName}</b> hat <b>{voteLoc}</b> zum Übergangsvorschlag für <b>{axisLoc}</b> bei <b>{libraryName}</b> gestimmt (von <i>{oldValueLoc}</i> zu <b>{newValueLoc}</b>).",
    ca: "<b>{voterName}</b> ha votat <b>{voteLoc}</b> sobre la proposta de transició de <b>{axisLoc}</b> de <b>{libraryName}</b> (de <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>).",
    eo: "<b>{voterName}</b> voĉdonis <b>{voteLoc}</b> pri la transir-propono de <b>{axisLoc}</b> de <b>{libraryName}</b> (de <i>{oldValueLoc}</i> al <b>{newValueLoc}</b>).",
    nl: "<b>{voterName}</b> heeft <b>{voteLoc}</b> gestemd op het overgangsvoorstel voor <b>{axisLoc}</b> bij <b>{libraryName}</b> (van <i>{oldValueLoc}</i> naar <b>{newValueLoc}</b>).",
    el: "Ο/Η <b>{voterName}</b> ψήφισε <b>{voteLoc}</b> στην πρόταση μετάβασης για <b>{axisLoc}</b> στη <b>{libraryName}</b> (από <i>{oldValueLoc}</i> σε <b>{newValueLoc}</b>)."
  },
  "library_profile.accepted.intro": {
    "pt-BR": "A coletividade da <b>{libraryName}</b> aprovou (<i>{acceptedLoc}</i>) a transição em <b>{axisLoc}</b>: de <i>{oldValueLoc}</i> para <b>{newValueLoc}</b>. A decisão entrará em vigor após o período de carência, durante o qual a comunidade pode ainda se manifestar.",
    fr: "La collectivité de <b>{libraryName}</b> a accepté (<i>{acceptedLoc}</i>) la transition de <b>{axisLoc}</b> : de <i>{oldValueLoc}</i> à <b>{newValueLoc}</b>. La décision entrera en vigueur après le délai de réflexion, pendant lequel la communauté peut encore se manifester.",
    es: "La colectividad de <b>{libraryName}</b> aceptó (<i>{acceptedLoc}</i>) la transición de <b>{axisLoc}</b>: de <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>. La decisión entrará en vigor después del plazo de reflexión, durante el cual la comunidad aún puede manifestarse.",
    en: "The collective of <b>{libraryName}</b> accepted (<i>{acceptedLoc}</i>) the transition of <b>{axisLoc}</b>: from <i>{oldValueLoc}</i> to <b>{newValueLoc}</b>. The decision will take effect after the reflection period, during which the community may still raise objections.",
    it: "La collettività di <b>{libraryName}</b> ha accettato (<i>{acceptedLoc}</i>) la transizione di <b>{axisLoc}</b>: da <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>. La decisione entrerà in vigore dopo il periodo di riflessione, durante il quale la comunità può ancora manifestarsi.",
    de: "Das Kollektiv von <b>{libraryName}</b> hat den Übergang von <b>{axisLoc}</b> angenommen (<i>{acceptedLoc}</i>): von <i>{oldValueLoc}</i> zu <b>{newValueLoc}</b>. Die Entscheidung tritt nach der Reflexionsfrist in Kraft, während der die Gemeinschaft sich noch äußern kann.",
    ca: "La col·lectivitat de <b>{libraryName}</b> ha acceptat (<i>{acceptedLoc}</i>) la transició de <b>{axisLoc}</b>: de <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>. La decisió entrarà en vigor després del termini de reflexió, durant el qual la comunitat encara pot manifestar-se.",
    eo: "La kolektivo de <b>{libraryName}</b> akceptis (<i>{acceptedLoc}</i>) la transiron de <b>{axisLoc}</b>: de <i>{oldValueLoc}</i> al <b>{newValueLoc}</b>. La decido ekvalidos post la pripensa periodo, dum kiu la komunumo ankoraŭ povas esprimiĝi.",
    nl: "Het collectief van <b>{libraryName}</b> heeft de overgang van <b>{axisLoc}</b> aanvaard (<i>{acceptedLoc}</i>): van <i>{oldValueLoc}</i> naar <b>{newValueLoc}</b>. De beslissing wordt van kracht na de bedenktijd, waarin de gemeenschap nog bezwaar kan maken.",
    el: "Η συλλογικότητα της <b>{libraryName}</b> αποδέχτηκε (<i>{acceptedLoc}</i>) τη μετάβαση του/της <b>{axisLoc}</b>: από <i>{oldValueLoc}</i> σε <b>{newValueLoc}</b>. Η απόφαση θα τεθεί σε ισχύ μετά την περίοδο σκέψης, στη διάρκεια της οποίας η κοινότητα μπορεί ακόμη να εκφράσει αντιρρήσεις."
  },
  "library_profile.rejected.intro": {
    "pt-BR": "A proposta de transição em <b>{axisLoc}</b> da <b>{libraryName}</b> (de <i>{oldValueLoc}</i> para <b>{newValueLoc}</b>) não passou: <i>{reasonLoc}</i>. O modo atual permanece em vigor.",
    fr: "La proposition de transition de <b>{axisLoc}</b> de <b>{libraryName}</b> (de <i>{oldValueLoc}</i> vers <b>{newValueLoc}</b>) n'a pas abouti : <i>{reasonLoc}</i>. Le fonctionnement actuel reste en vigueur.",
    es: "La propuesta de transición de <b>{axisLoc}</b> de <b>{libraryName}</b> (de <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>) no fue aceptada: <i>{reasonLoc}</i>. El funcionamiento actual se mantiene en vigor.",
    en: "The transition proposal for <b>{axisLoc}</b> at <b>{libraryName}</b> (from <i>{oldValueLoc}</i> to <b>{newValueLoc}</b>) did not pass: <i>{reasonLoc}</i>. The current setup remains in effect.",
    it: "La proposta di transizione di <b>{axisLoc}</b> a <b>{libraryName}</b> (da <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>) non è passata: <i>{reasonLoc}</i>. Il funzionamento attuale rimane in vigore.",
    de: "Der Übergangsvorschlag für <b>{axisLoc}</b> bei <b>{libraryName}</b> (von <i>{oldValueLoc}</i> zu <b>{newValueLoc}</b>) wurde nicht angenommen: <i>{reasonLoc}</i>. Die aktuelle Funktionsweise bleibt in Kraft.",
    ca: "La proposta de transició de <b>{axisLoc}</b> de <b>{libraryName}</b> (de <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>) no ha prosperat: <i>{reasonLoc}</i>. El funcionament actual es manté en vigor.",
    eo: "La transir-propono de <b>{axisLoc}</b> de <b>{libraryName}</b> (de <i>{oldValueLoc}</i> al <b>{newValueLoc}</b>) ne sukcesis: <i>{reasonLoc}</i>. La nuna funkciado restas en vigoro.",
    nl: "Het overgangsvoorstel voor <b>{axisLoc}</b> bij <b>{libraryName}</b> (van <i>{oldValueLoc}</i> naar <b>{newValueLoc}</b>) is niet aangenomen: <i>{reasonLoc}</i>. De huidige opzet blijft van kracht.",
    el: "Η πρόταση μετάβασης για <b>{axisLoc}</b> στη <b>{libraryName}</b> (από <i>{oldValueLoc}</i> σε <b>{newValueLoc}</b>) δεν πέρασε: <i>{reasonLoc}</i>. Η τρέχουσα ρύθμιση παραμένει σε ισχύ."
  },
  "library_profile.cancelled.intro": {
    "pt-BR": "<b>{proposerName}</b> retirou sua própria proposta de transição em <b>{axisLoc}</b> da <b>{libraryName}</b> (que era: de <i>{oldValueLoc}</i> para <i>{newValueLoc}</i>). O modo atual permanece em vigor.",
    fr: "<b>{proposerName}</b> a retiré sa propre proposition de transition de <b>{axisLoc}</b> de <b>{libraryName}</b> (qui était : de <i>{oldValueLoc}</i> vers <i>{newValueLoc}</i>). Le fonctionnement actuel reste en vigueur.",
    es: "<b>{proposerName}</b> retiró su propia propuesta de transición de <b>{axisLoc}</b> de <b>{libraryName}</b> (que era: de <i>{oldValueLoc}</i> a <i>{newValueLoc}</i>). El funcionamiento actual se mantiene en vigor.",
    en: "<b>{proposerName}</b> withdrew their own transition proposal for <b>{axisLoc}</b> at <b>{libraryName}</b> (which was: from <i>{oldValueLoc}</i> to <i>{newValueLoc}</i>). The current setup remains in effect.",
    it: "<b>{proposerName}</b> ha ritirato la propria proposta di transizione di <b>{axisLoc}</b> a <b>{libraryName}</b> (che era: da <i>{oldValueLoc}</i> a <i>{newValueLoc}</i>). Il funzionamento attuale rimane in vigore.",
    de: "<b>{proposerName}</b> hat den eigenen Übergangsvorschlag für <b>{axisLoc}</b> bei <b>{libraryName}</b> zurückgezogen (er war: von <i>{oldValueLoc}</i> zu <i>{newValueLoc}</i>). Die aktuelle Funktionsweise bleibt in Kraft.",
    ca: "<b>{proposerName}</b> ha retirat la seva pròpia proposta de transició de <b>{axisLoc}</b> de <b>{libraryName}</b> (que era: de <i>{oldValueLoc}</i> a <i>{newValueLoc}</i>). El funcionament actual es manté en vigor.",
    eo: "<b>{proposerName}</b> retiris sian propran transir-proponon de <b>{axisLoc}</b> de <b>{libraryName}</b> (kiu estis: de <i>{oldValueLoc}</i> al <i>{newValueLoc}</i>). La nuna funkciado restas en vigoro.",
    nl: "<b>{proposerName}</b> heeft het eigen overgangsvoorstel voor <b>{axisLoc}</b> bij <b>{libraryName}</b> ingetrokken (dat was: van <i>{oldValueLoc}</i> naar <i>{newValueLoc}</i>). De huidige opzet blijft van kracht.",
    el: "Ο/Η <b>{proposerName}</b> απέσυρε τη δική του/της πρόταση μετάβασης για <b>{axisLoc}</b> στη <b>{libraryName}</b> (που ήταν: από <i>{oldValueLoc}</i> σε <i>{newValueLoc}</i>). Η τρέχουσα ρύθμιση παραμένει σε ισχύ."
  },
  "library_profile.executed.intro": {
    "pt-BR": "A <b>{libraryName}</b> acaba de basculhar seu <b>{axisLoc}</b>: a partir de agora, ela funciona em <b>{newValueLoc}</b> (anteriormente: <i>{oldValueLoc}</i>). Esta transição foi decidida coletivamente.",
    fr: "<b>{libraryName}</b> adopte un nouveau <b>{axisLoc}</b> : à partir de maintenant, <i>{oldValueLoc}</i> devient <b>{newValueLoc}</b>. Cette transition a été décidée collectivement.",
    es: "<b>{libraryName}</b> adopta un nuevo <b>{axisLoc}</b>: a partir de ahora, <i>{oldValueLoc}</i> deviene <b>{newValueLoc}</b>. Esta transición fue decidida colectivamente.",
    en: "<b>{libraryName}</b> adopts a new <b>{axisLoc}</b>: from now on, <i>{oldValueLoc}</i> becomes <b>{newValueLoc}</b>. This transition was decided collectively.",
    it: "<b>{libraryName}</b> adotta un nuovo <b>{axisLoc}</b>: da ora in poi, <i>{oldValueLoc}</i> diventa <b>{newValueLoc}</b>. Questa transizione è stata decisa collettivamente.",
    de: "<b>{libraryName}</b> nimmt einen neuen <b>{axisLoc}</b> an: ab jetzt wird <i>{oldValueLoc}</i> zu <b>{newValueLoc}</b>. Diese Transition wurde kollektiv beschlossen.",
    ca: "<b>{libraryName}</b> adopta un nou <b>{axisLoc}</b>: a partir d'ara, <i>{oldValueLoc}</i> esdevé <b>{newValueLoc}</b>. Aquesta transició s'ha decidit col·lectivament.",
    eo: "<b>{libraryName}</b> adoptas novan <b>{axisLoc}</b>: ekde nun, <i>{oldValueLoc}</i> iĝas <b>{newValueLoc}</b>. Ĉi tiu transiro estis decidita kolektive.",
    nl: "<b>{libraryName}</b> neemt een nieuwe <b>{axisLoc}</b> aan: vanaf nu wordt <i>{oldValueLoc}</i> <b>{newValueLoc}</b>. Deze overgang is collectief besloten.",
    el: "Η <b>{libraryName}</b> υιοθετεί νέο/α <b>{axisLoc}</b>: από εδώ και πέρα, το <i>{oldValueLoc}</i> γίνεται <b>{newValueLoc}</b>. Αυτή η μετάβαση αποφασίστηκε συλλογικά."
  },

  // ===== B.5 — library_profile : CTA et infos ==============================
  "library_profile.proposed.cta": {
    "pt-BR": "Deliberar e votar",
    fr: "Délibérer et voter",
    es: "Deliberar y votar",
    en: "Deliberate and vote",
    it: "Deliberare e votare",
    de: "Beraten und abstimmen",
    ca: "Deliberar i votar",
    eo: "Pridiskuti kaj voĉdoni",
    nl: "Beraadslagen en stemmen",
    el: "Διαβουλεύσου και ψήφισε"
  },
  "library_profile.voted.cta": {
    "pt-BR": "Ver a proposta",
    fr: "Voir la proposition",
    es: "Ver la propuesta",
    en: "View the proposal",
    it: "Vedere la proposta",
    de: "Vorschlag ansehen",
    ca: "Veure la proposta",
    eo: "Vidi la proponon",
    nl: "Bekijk het voorstel",
    el: "Δες την πρόταση"
  },
  "library_profile.accepted.cta": {
    "pt-BR": "Ver os detalhes",
    fr: "Voir les détails",
    es: "Ver los detalles",
    en: "View the details",
    it: "Vedere i dettagli",
    de: "Details ansehen",
    ca: "Veure els detalls",
    eo: "Vidi la detalojn",
    nl: "Bekijk de details",
    el: "Δες τις λεπτομέρειες"
  },
  "library_profile.accepted.gracePeriodInfo": {
    "pt-BR": "Período de carência em curso",
    fr: "Délai de réflexion en cours",
    es: "Plazo de reflexión en curso",
    en: "Reflection period in progress",
    it: "Periodo di riflessione in corso",
    de: "Reflexionsfrist läuft",
    ca: "Termini de reflexió en curs",
    eo: "Pripensa periodo en kurso",
    nl: "Bedenktijd loopt",
    el: "Περίοδος σκέψης σε εξέλιξη"
  },
  "library_profile.executed.cta": {
    "pt-BR": "Ver o perfil da biblioteca",
    fr: "Voir le profil de la bibliothèque",
    es: "Ver el perfil de la biblioteca",
    en: "View the library profile",
    it: "Vedere il profilo della biblioteca",
    de: "Bibliotheksprofil ansehen",
    ca: "Veure el perfil de la biblioteca",
    eo: "Vidi la profilon de la biblioteko",
    nl: "Bekijk het bibliotheekprofiel",
    el: "Δες το προφίλ της βιβλιοθήκης"
  },
  "library_profile.executed.info": {
    "pt-BR": "Transição aplicada",
    fr: "Transition appliquée",
    es: "Transición aplicada",
    en: "Transition applied",
    it: "Transizione applicata",
    de: "Übergang angewendet",
    ca: "Transició aplicada",
    eo: "Transiro aplikita",
    nl: "Overgang toegepast",
    el: "Η μετάβαση εφαρμόστηκε"
  },

  // ===== B.7 — library_profile reader_executed (mail lecteur·rice·s sur circulation_mode) =====
  "library_profile.reader_executed.sub": {
    "pt-BR": "{libraryName}: mudança no {axisLoc}",
    fr: "{libraryName} : changement de {axisLoc}",
    es: "{libraryName}: cambio en {axisLoc}",
    en: "{libraryName}: change in {axisLoc}",
    it: "{libraryName}: cambiamento di {axisLoc}",
    de: "{libraryName}: Änderung des {axisLoc}",
    ca: "{libraryName}: canvi en {axisLoc}",
    eo: "{libraryName}: ŝanĝo de {axisLoc}",
    nl: "{libraryName}: wijziging in {axisLoc}",
    el: "{libraryName}: αλλαγή στο/στον {axisLoc}"
  },
  "library_profile.reader_executed.intro": {
    "pt-BR": "A coletividade de <b>{libraryName}</b> decidiu mudar seu <b>{axisLoc}</b>: a partir de agora, <i>{oldValueLoc}</i> torna-se <b>{newValueLoc}</b>.",
    fr: "La collectivité de <b>{libraryName}</b> a décidé de changer son <b>{axisLoc}</b> : à partir de maintenant, <i>{oldValueLoc}</i> devient <b>{newValueLoc}</b>.",
    es: "La colectividad de <b>{libraryName}</b> decidió cambiar su <b>{axisLoc}</b>: a partir de ahora, <i>{oldValueLoc}</i> deviene <b>{newValueLoc}</b>.",
    en: "The collective of <b>{libraryName}</b> has decided to change its <b>{axisLoc}</b>: from now on, <i>{oldValueLoc}</i> becomes <b>{newValueLoc}</b>.",
    it: "La collettività di <b>{libraryName}</b> ha deciso di cambiare il suo <b>{axisLoc}</b>: da ora in poi, <i>{oldValueLoc}</i> diventa <b>{newValueLoc}</b>.",
    de: "Das Kollektiv von <b>{libraryName}</b> hat beschlossen, seinen <b>{axisLoc}</b> zu ändern: ab jetzt wird <i>{oldValueLoc}</i> zu <b>{newValueLoc}</b>.",
    ca: "La col·lectivitat de <b>{libraryName}</b> ha decidit canviar el seu <b>{axisLoc}</b>: a partir d'ara, <i>{oldValueLoc}</i> esdevé <b>{newValueLoc}</b>.",
    eo: "La kolektivo de <b>{libraryName}</b> decidis ŝanĝi sian <b>{axisLoc}</b>: ekde nun, <i>{oldValueLoc}</i> iĝas <b>{newValueLoc}</b>.",
    nl: "Het collectief van <b>{libraryName}</b> heeft besloten zijn <b>{axisLoc}</b> te wijzigen: vanaf nu wordt <i>{oldValueLoc}</i> <b>{newValueLoc}</b>.",
    el: "Η συλλογικότητα της <b>{libraryName}</b> αποφάσισε να αλλάξει τον/το <b>{axisLoc}</b>: από εδώ και πέρα, το <i>{oldValueLoc}</i> γίνεται <b>{newValueLoc}</b>."
  },
  "library_profile.reader_executed.impact.full_sigb": {
    "pt-BR": "Para você como leitor·a·e: a partir de agora, você pode pegar emprestados livros, fazer reservas e consultar documentos no local através da interface AnarBib de <b>{libraryName}</b>.",
    fr: "Pour toi en tant que lecteur·rice : à partir de maintenant, tu peux emprunter des livres, faire des réservations et consulter des documents sur place via l'interface AnarBib de <b>{libraryName}</b>.",
    es: "Para vos como lector·a·e: a partir de ahora, podés tomar prestados libros, hacer reservas y consultar documentos en el lugar a través de la interfaz AnarBib de <b>{libraryName}</b>.",
    en: "For you as a reader: from now on, you can borrow books, make reservations and consult documents on site through the AnarBib interface of <b>{libraryName}</b>.",
    it: "Per te come lettore/trice: da ora in poi, puoi prendere in prestito libri, fare prenotazioni e consultare documenti sul posto attraverso l'interfaccia AnarBib di <b>{libraryName}</b>.",
    de: "Für dich als Leser*in: ab jetzt kannst du Bücher ausleihen, Reservierungen vornehmen und Dokumente vor Ort über die AnarBib-Oberfläche von <b>{libraryName}</b> einsehen.",
    ca: "Per a tu com a lector-a-e: a partir d'ara, pots demanar llibres en préstec, fer reserves i consultar documents in situ a través de la interfície AnarBib de <b>{libraryName}</b>.",
    eo: "Por vi kiel legant-in-o: ekde nun, vi povas prunti librojn, fari rezervojn kaj surloke konsulti dokumentojn pere de la interfaco AnarBib de <b>{libraryName}</b>.",
    nl: "Voor jou als lezer: vanaf nu kun je boeken lenen, reserveringen maken en documenten ter plaatse raadplegen via de AnarBib-interface van <b>{libraryName}</b>.",
    el: "Για σένα ως αναγνώστη/στρια: από εδώ και πέρα, μπορείς να δανείζεσαι βιβλία, να κάνεις κρατήσεις και να μελετάς τεκμήρια επιτόπου μέσω της διεπαφής AnarBib της <b>{libraryName}</b>."
  },
  "library_profile.reader_executed.impact.informal": {
    "pt-BR": "Para você como leitor·a·e: a partir de agora, a circulação acontece de maneira informal, fora da interface AnarBib. Entre em contato diretamente com <b>{libraryName}</b> para pegar emprestado ou consultar.",
    fr: "Pour toi en tant que lecteur·rice : à partir de maintenant, la circulation se fait de manière informelle, hors interface AnarBib. Contacte directement <b>{libraryName}</b> pour emprunter ou consulter.",
    es: "Para vos como lector·a·e: a partir de ahora, la circulación se hace de manera informal, fuera de la interfaz AnarBib. Contactá directamente a <b>{libraryName}</b> para tomar prestado o consultar.",
    en: "For you as a reader: from now on, circulation happens informally, outside the AnarBib interface. Contact <b>{libraryName}</b> directly to borrow or consult.",
    it: "Per te come lettore/trice: da ora in poi, la circolazione avviene in modo informale, fuori dall'interfaccia AnarBib. Contatta direttamente <b>{libraryName}</b> per prendere in prestito o consultare.",
    de: "Für dich als Leser*in: ab jetzt erfolgt die Zirkulation informell, außerhalb der AnarBib-Oberfläche. Wende dich direkt an <b>{libraryName}</b>, um etwas auszuleihen oder einzusehen.",
    ca: "Per a tu com a lector-a-e: a partir d'ara, la circulació es fa de manera informal, fora de la interfície AnarBib. Contacta directament <b>{libraryName}</b> per demanar en préstec o consultar.",
    eo: "Por vi kiel legant-in-o: ekde nun, la cirkulado okazas neformale, ekster la interfaco AnarBib. Kontaktu rekte <b>{libraryName}</b> por prunti aŭ konsulti.",
    nl: "Voor jou als lezer: vanaf nu verloopt de circulatie informeel, buiten de AnarBib-interface. Neem rechtstreeks contact op met <b>{libraryName}</b> om te lenen of te raadplegen.",
    el: "Για σένα ως αναγνώστη/στρια: από εδώ και πέρα, η κυκλοφορία γίνεται ανεπίσημα, εκτός της διεπαφής AnarBib. Επικοινώνησε απευθείας με τη <b>{libraryName}</b> για δανεισμό ή μελέτη."
  },
  "library_profile.reader_executed.impact.off": {
    "pt-BR": "Para você como leitor·a·e: a partir de agora, <b>{libraryName}</b> não oferece mais serviço de empréstimo nem de consulta para leitor·a·e·s via AnarBib. Você ainda pode entrar em contato com a biblioteca para conversar sobre o acervo.",
    fr: "Pour toi en tant que lecteur·rice : à partir de maintenant, <b>{libraryName}</b> ne propose plus de service de prêt ni de consultation aux lecteur·rice·s via AnarBib. Tu peux toujours contacter la bibliothèque pour échanger sur le fonds.",
    es: "Para vos como lector·a·e: a partir de ahora, <b>{libraryName}</b> ya no ofrece servicio de préstamo ni de consulta para lector·a·e·s vía AnarBib. Aún podés contactar la biblioteca para conversar sobre el acervo.",
    en: "For you as a reader: from now on, <b>{libraryName}</b> no longer offers borrowing or consultation services for readers via AnarBib. You can still contact the library to discuss the collection.",
    it: "Per te come lettore/trice: da ora in poi, <b>{libraryName}</b> non offre più servizi di prestito o consultazione per lettori/trici via AnarBib. Puoi ancora contattare la biblioteca per parlare della collezione.",
    de: "Für dich als Leser*in: ab jetzt bietet <b>{libraryName}</b> keine Ausleih- oder Einsichtsdienste mehr für Leser*innen über AnarBib an. Du kannst die Bibliothek weiterhin kontaktieren, um über den Bestand zu sprechen.",
    ca: "Per a tu com a lector-a-e: a partir d'ara, <b>{libraryName}</b> ja no ofereix servei de préstec ni de consulta per a lectores via AnarBib. Encara pots contactar la biblioteca per parlar del fons.",
    eo: "Por vi kiel legant-in-o: ekde nun, <b>{libraryName}</b> ne plu ofertas prunt- aŭ konsult-servon por legant-in-oj pere de AnarBib. Vi ankoraŭ povas kontakti la bibliotekon por priparoli la fonduson.",
    nl: "Voor jou als lezer: vanaf nu biedt <b>{libraryName}</b> geen uitleen- of raadpleegdienst voor lezers meer aan via AnarBib. Je kunt nog altijd contact opnemen met de bibliotheek om over de collectie te praten.",
    el: "Για σένα ως αναγνώστη/στρια: από εδώ και πέρα, η <b>{libraryName}</b> δεν προσφέρει πλέον υπηρεσίες δανεισμού ή μελέτης για αναγνώστες/στριες μέσω AnarBib. Μπορείς ακόμη να επικοινωνήσεις με τη βιβλιοθήκη για να συζητήσεις για τη συλλογή."
  },
  "library_profile.reader_executed.cta": {
    "pt-BR": "Ver a biblioteca",
    fr: "Voir la bibliothèque",
    es: "Ver la biblioteca",
    en: "View the library",
    it: "Vedere la biblioteca",
    de: "Bibliothek ansehen",
    ca: "Veure la biblioteca",
    eo: "Vidi la bibliotekon",
    nl: "Bekijk de bibliotheek",
    el: "Δες τη βιβλιοθήκη"
  },

  // ===== B.5 — Labels d'axe ================================================
  "lp.axis.catalog_mode": {
    "pt-BR": "modo de catalogação",
    fr: "mode de catalogage",
    es: "modo de catalogación",
    en: "cataloguing mode",
    it: "modo di catalogazione",
    de: "Katalogmodus",
    ca: "mode de catalogació",
    eo: "katalogada reĝimo",
    nl: "catalogiseermodus",
    el: "λειτουργία καταλογογράφησης"
  },
  "lp.axis.circulation_mode": {
    "pt-BR": "modo de circulação",
    fr: "mode de circulation",
    es: "modo de circulación",
    en: "circulation mode",
    it: "modo di circolazione",
    de: "Zirkulationsmodus",
    ca: "mode de circulació",
    eo: "cirkulada reĝimo",
    nl: "circulatiemodus",
    el: "λειτουργία κυκλοφορίας"
  },
  "lp.axis.network_mode": {
    "pt-BR": "vínculo à federação",
    fr: "lien à la fédération",
    es: "vínculo con la federación",
    en: "link to the federation",
    it: "legame con la federazione",
    de: "Verbindung zur Föderation",
    ca: "vincle amb la federació",
    eo: "ligo al la federacio",
    nl: "band met de federatie",
    el: "σύνδεση με την ομοσπονδία"
  },
  "lp.axis.governance_mode": {
    "pt-BR": "modo de governança",
    fr: "mode de gouvernance",
    es: "modo de gobernanza",
    en: "governance mode",
    it: "modo di governance",
    de: "Governance-Modus",
    ca: "mode de governança",
    eo: "memmastruma reĝimo",
    nl: "bestuursmodus",
    el: "λειτουργία διακυβέρνησης"
  },

  // ===== B.5 — Labels de valeur d'axe ======================================
  "lp.value.catalog_mode.local_only": {
    "pt-BR": "catálogo apenas local",
    fr: "catalogue local uniquement",
    es: "catálogo solo local",
    en: "local catalogue only",
    it: "catalogo solo locale",
    de: "nur lokaler Katalog",
    ca: "catàleg només local",
    eo: "nur loka katalogo",
    nl: "alleen lokale catalogus",
    el: "μόνο τοπικός κατάλογος"
  },
  "lp.value.catalog_mode.network_published": {
    "pt-BR": "catálogo publicado na federação",
    fr: "catalogue publié dans la fédération",
    es: "catálogo publicado en la federación",
    en: "catalogue published in the federation",
    it: "catalogo pubblicato nella federazione",
    de: "in der Föderation veröffentlichter Katalog",
    ca: "catàleg publicat a la federació",
    eo: "katalogo publikigita en la federacio",
    nl: "catalogus gepubliceerd in de federatie",
    el: "κατάλογος δημοσιευμένος στην ομοσπονδία"
  },
  "lp.value.circulation_mode.off": {
    "pt-BR": "sem circulação",
    fr: "sans circulation",
    es: "sin circulación",
    en: "no circulation",
    it: "senza circolazione",
    de: "keine Zirkulation",
    ca: "sense circulació",
    eo: "sen cirkulado",
    nl: "zonder circulatie",
    el: "χωρίς κυκλοφορία"
  },
  "lp.value.circulation_mode.informal": {
    "pt-BR": "circulação informal",
    fr: "circulation informelle",
    es: "circulación informal",
    en: "informal circulation",
    it: "circolazione informale",
    de: "informelle Zirkulation",
    ca: "circulació informal",
    eo: "neformala cirkulado",
    nl: "informele circulatie",
    el: "ανεπίσημη κυκλοφορία"
  },
  "lp.value.circulation_mode.full_sigb": {
    "pt-BR": "SIGB completo (empréstimos, reservas, consultas)",
    fr: "SIGB complet (emprunts, réservations, consultations)",
    es: "SIGB completo (préstamos, reservas, consultas)",
    en: "full ILS (loans, reservations, consultations)",
    it: "SIGB completo (prestiti, prenotazioni, consultazioni)",
    de: "vollständiges ILS (Ausleihen, Reservierungen, Konsultationen)",
    ca: "SIGB complet (préstecs, reserves, consultes)",
    eo: "kompleta SIGB (pruntoj, rezervoj, konsultoj)",
    nl: "volledig bibliotheeksysteem (uitleningen, reserveringen, raadplegingen)",
    el: "πλήρες σύστημα διαχείρισης βιβλιοθήκης (δανεισμοί, κρατήσεις, μελέτες)"
  },
  "lp.value.network_mode.isolated": {
    "pt-BR": "isolada da federação",
    fr: "isolée de la fédération",
    es: "aislada de la federación",
    en: "isolated from the federation",
    it: "isolata dalla federazione",
    de: "von der Föderation isoliert",
    ca: "aïllada de la federació",
    eo: "izolita de la federacio",
    nl: "geïsoleerd van de federatie",
    el: "απομονωμένη από την ομοσπονδία"
  },
  "lp.value.network_mode.observer": {
    "pt-BR": "observadora da federação",
    fr: "observatrice de la fédération",
    es: "observadora de la federación",
    en: "observer of the federation",
    it: "osservatrice della federazione",
    de: "Beobachterin der Föderation",
    ca: "observadora de la federació",
    eo: "observanta la federacion",
    nl: "waarnemer van de federatie",
    el: "παρατηρήτρια της ομοσπονδίας"
  },
  "lp.value.network_mode.federated": {
    "pt-BR": "federada (participação plena)",
    fr: "fédérée (participation pleine)",
    es: "federada (participación plena)",
    en: "federated (full participation)",
    it: "federata (partecipazione piena)",
    de: "föderiert (volle Teilnahme)",
    ca: "federada (participació plena)",
    eo: "federita (plena partopreno)",
    nl: "gefedereerd (volledige deelname)",
    el: "ομόσπονδη (πλήρης συμμετοχή)"
  },
  "lp.value.governance_mode.informal": {
    "pt-BR": "governança informal (sem papéis declarados)",
    fr: "gouvernance informelle (sans rôles déclarés)",
    es: "gobernanza informal (sin roles declarados)",
    en: "informal governance (no declared roles)",
    it: "governance informale (senza ruoli dichiarati)",
    de: "informelle Governance (ohne erklärte Rollen)",
    ca: "governança informal (sense rols declarats)",
    eo: "neformala memmastrumado (sen deklaritaj roloj)",
    nl: "informeel bestuur (geen verklaarde rollen)",
    el: "ανεπίσημη διακυβέρνηση (χωρίς δηλωμένους ρόλους)"
  },
  "lp.value.governance_mode.staff_roles": {
    "pt-BR": "papéis declarados (bibliotecári(o/a/e) e coordenador(o/a/e))",
    fr: "rôles déclarés (bibliothécaires et coordinateur·rice·s)",
    es: "roles declarados (bibliotecaries y coordinadores)",
    en: "declared roles (librarians and coordinators)",
    it: "ruoli dichiarati (bibliotecari* e coordinatori/trici)",
    de: "erklärte Rollen (Bibliothekar*innen und Koordinator*innen)",
    ca: "rols declarats (bibliotecari-ària-e i coordinador-a-e)",
    eo: "deklaritaj roloj (bibliotekist-in-o kaj kunordigant-in-o)",
    nl: "verklaarde rollen (bibliothecarissen en coördinatoren)",
    el: "δηλωμένοι ρόλοι (βιβλιοθηκάριοι και συντονιστές/στριες)"
  },
  "lp.value.governance_mode.full_governance": {
    "pt-BR": "governança plena (com todas as rotinas coletivas)",
    fr: "gouvernance pleine (avec toutes les routines collectives)",
    es: "gobernanza plena (con todas las rutinas colectivas)",
    en: "full governance (with all collective routines)",
    it: "governance piena (con tutte le routine collettive)",
    de: "volle Governance (mit allen kollektiven Routinen)",
    ca: "governança plena (amb totes les rutines col·lectives)",
    eo: "plena memmastrumado (kun ĉiuj kolektivaj rutinoj)",
    nl: "volledig bestuur (met alle collectieve routines)",
    el: "πλήρης διακυβέρνηση (με όλες τις συλλογικές ρουτίνες)"
  },

  // ===== B.5 — Labels de type de transition ================================
  "lp.transition.direct": {
    "pt-BR": "transição direta (sem deliberação)",
    fr: "transition directe (sans délibération)",
    es: "transición directa (sin deliberación)",
    en: "direct transition (no deliberation)",
    it: "transizione diretta (senza deliberazione)",
    de: "direkter Übergang (ohne Beratung)",
    ca: "transició directa (sense deliberació)",
    eo: "rekta transiro (sen pridiskuto)",
    nl: "directe overgang (zonder beraadslaging)",
    el: "άμεση μετάβαση (χωρίς διαβούλευση)"
  },
  "lp.transition.majority": {
    "pt-BR": "maioria simples",
    fr: "majorité simple",
    es: "mayoría simple",
    en: "simple majority",
    it: "maggioranza semplice",
    de: "einfache Mehrheit",
    ca: "majoria simple",
    eo: "simpla plimulto",
    nl: "gewone meerderheid",
    el: "απλή πλειοψηφία"
  },
  "lp.transition.unanimous": {
    "pt-BR": "unanimidade",
    fr: "unanimité",
    es: "unanimidad",
    en: "unanimity",
    it: "unanimità",
    de: "Einstimmigkeit",
    ca: "unanimitat",
    eo: "unuanimeco",
    nl: "unanimiteit",
    el: "ομοφωνία"
  },
  "lp.transition.unanimous_extended": {
    "pt-BR": "unanimidade alargada (com período de carência reforçado)",
    fr: "unanimité élargie (avec délai de réflexion renforcé)",
    es: "unanimidad ampliada (con plazo de reflexión reforzado)",
    en: "extended unanimity (with reinforced reflection period)",
    it: "unanimità allargata (con periodo di riflessione rafforzato)",
    de: "erweiterte Einstimmigkeit (mit verstärkter Reflexionsfrist)",
    ca: "unanimitat ampliada (amb termini de reflexió reforçat)",
    eo: "etendita unuanimeco (kun plifortigita pripensa periodo)",
    nl: "uitgebreide unanimiteit (met versterkte bedenktijd)",
    el: "εκτεταμένη ομοφωνία (με ενισχυμένη περίοδο σκέψης)"
  },
  "lp.transition.unknown": {
    "pt-BR": "tipo de transição desconhecido",
    fr: "type de transition inconnu",
    es: "tipo de transición desconocido",
    en: "unknown transition type",
    it: "tipo di transizione sconosciuto",
    de: "unbekannter Übergangstyp",
    ca: "tipus de transició desconegut",
    eo: "nekonata transir-tipo",
    nl: "onbekend overgangstype",
    el: "άγνωστος τύπος μετάβασης"
  },

  // ===== B.5 — Labels de vote ==============================================
  "lp.vote.favor": {
    "pt-BR": "a favor",
    fr: "pour",
    es: "a favor",
    en: "in favor",
    it: "a favore",
    de: "dafür",
    ca: "a favor",
    eo: "por",
    nl: "voor",
    el: "υπέρ"
  },
  "lp.vote.against": {
    "pt-BR": "contra",
    fr: "contre",
    es: "en contra",
    en: "against",
    it: "contro",
    de: "dagegen",
    ca: "en contra",
    eo: "kontraŭ",
    nl: "tegen",
    el: "κατά"
  },
  "lp.vote.abstain": {
    "pt-BR": "abstenção",
    fr: "abstention",
    es: "abstención",
    en: "abstention",
    it: "astensione",
    de: "Enthaltung",
    ca: "abstenció",
    eo: "sindeteno",
    nl: "onthouding",
    el: "αποχή"
  },

  // ===== B.5 — Labels de statut acceptation =================================
  "lp.status.accepted_unanimous": {
    "pt-BR": "por unanimidade",
    fr: "à l'unanimité",
    es: "por unanimidad",
    en: "unanimously",
    it: "all'unanimità",
    de: "einstimmig",
    ca: "per unanimitat",
    eo: "unuanime",
    nl: "unaniem",
    el: "ομόφωνα"
  },
  "lp.status.accepted_majority": {
    "pt-BR": "por maioria",
    fr: "à la majorité",
    es: "por mayoría",
    en: "by majority",
    it: "a maggioranza",
    de: "mehrheitlich",
    ca: "per majoria",
    eo: "plimulte",
    nl: "met meerderheid",
    el: "κατά πλειοψηφία"
  },

  // ===== B.5 — Labels de raison de rejet ===================================
  "lp.rejected.reason.rejected": {
    "pt-BR": "voto coletivo desfavorável",
    fr: "vote collectif défavorable",
    es: "voto colectivo desfavorable",
    en: "unfavorable collective vote",
    it: "voto collettivo sfavorevole",
    de: "ungünstige kollektive Abstimmung",
    ca: "vot col·lectiu desfavorable",
    eo: "malfavora kolektiva voĉdono",
    nl: "ongunstige collectieve stemming",
    el: "δυσμενής συλλογική ψήφος"
  },
  "lp.rejected.reason.expired": {
    "pt-BR": "prazo de deliberação atingido sem decisão",
    fr: "délai de délibération atteint sans décision",
    es: "plazo de deliberación alcanzado sin decisión",
    en: "deliberation deadline reached without decision",
    it: "termine di deliberazione raggiunto senza decisione",
    de: "Beratungsfrist ohne Entscheidung abgelaufen",
    ca: "termini de deliberació assolit sense decisió",
    eo: "pridiskuta limdato atingita sen decido",
    nl: "beraadslagingstermijn bereikt zonder beslissing",
    el: "η προθεσμία διαβούλευσης παρήλθε χωρίς απόφαση"
  },

  // ===== B.5 — Labels génériques (via label()) =============================
  "l.lp.transitionType": {
    "pt-BR": "Tipo de transição",
    fr: "Type de transition",
    es: "Tipo de transición",
    en: "Transition type",
    it: "Tipo di transizione",
    de: "Übergangstyp",
    ca: "Tipus de transició",
    eo: "Transir-tipo",
    nl: "Overgangstype",
    el: "Τύπος μετάβασης"
  },
  "l.lp.motivation": {
    "pt-BR": "Motivação",
    fr: "Motivation",
    es: "Motivación",
    en: "Motivation",
    it: "Motivazione",
    de: "Begründung",
    ca: "Motivació",
    eo: "Motivo",
    nl: "Motivatie",
    el: "Αιτιολόγηση"
  },
  "l.lp.proposer": {
    "pt-BR": "Proponente",
    fr: "Proposant·e",
    es: "Proponente",
    en: "Proposer",
    it: "Proponente",
    de: "Vorschlagende*r",
    ca: "Proposant-a-e",
    eo: "Propon-int-o",
    nl: "Indiener",
    el: "Προτείνων/ουσα"
  },
  "l.lp.voteCount": {
    "pt-BR": "Votos",
    fr: "Voix",
    es: "Votos",
    en: "Votes",
    it: "Voti",
    de: "Stimmen",
    ca: "Vots",
    eo: "Voĉdonoj",
    nl: "Stemmen",
    el: "Ψήφοι"
  },
  "l.lp.rationaleAgainst": {
    "pt-BR": "Justificação do voto contra",
    fr: "Justification du vote contre",
    es: "Justificación del voto en contra",
    en: "Rationale for vote against",
    it: "Giustificazione del voto contrario",
    de: "Begründung der Gegenstimme",
    ca: "Justificació del vot en contra",
    eo: "Pravigo de la kontraŭa voĉdono",
    nl: "Motivering van de tegenstem",
    el: "Αιτιολόγηση ψήφου κατά"
  },
  "l.lp.gracePeriodUntil": {
    "pt-BR": "Carência até",
    fr: "Délai de réflexion jusqu'au",
    es: "Plazo de reflexión hasta",
    en: "Reflection period until",
    it: "Periodo di riflessione fino al",
    de: "Reflexionsfrist bis",
    ca: "Termini de reflexió fins al",
    eo: "Pripensa periodo ĝis",
    nl: "Bedenktijd tot",
    el: "Περίοδος σκέψης έως"
  },
  "l.lp.reason": {
    "pt-BR": "Razão",
    fr: "Raison",
    es: "Razón",
    en: "Reason",
    it: "Ragione",
    de: "Grund",
    ca: "Raó",
    eo: "Kialo",
    nl: "Reden",
    el: "Λόγος"
  },
  "l.lp.cancelledMotivation": {
    "pt-BR": "Motivo do retiro",
    fr: "Motif du retrait",
    es: "Motivo del retiro",
    en: "Reason for withdrawal",
    it: "Motivo del ritiro",
    de: "Grund des Rückzugs",
    ca: "Motiu de la retirada",
    eo: "Motivo de la retiro",
    nl: "Reden voor intrekking",
    el: "Λόγος απόσυρσης"
  },
  "l.lp.executedAt": {
    "pt-BR": "Aplicada em",
    fr: "Appliquée le",
    es: "Aplicada el",
    en: "Applied on",
    it: "Applicata il",
    de: "Angewendet am",
    ca: "Aplicada el",
    eo: "Aplikita la",
    nl: "Toegepast op",
    el: "Εφαρμόστηκε στις"
  },

  // ===== Prêts interbibliothèques (PEB / ILL) ==============================
  // Module notify-interlibrary-loan. 38 clés × 8 locales.
  // Flèche univoque {lender} → {borrower} : la prêteuse vers l'emprunteuse.
  // Convention inclusive : ca = triplet "lector-a-e" ; eo = "legant-in-o".
  // Le contenu est surtout institutionnel (bibliothèques, documents) ;
  // peu de formes genrées de personnes.

  // --- Sujets (8) ----------------------------------------------------------
  "ill.subject.created": {
    "pt-BR": "Empréstimo interbibliotecas {lender} → {borrower} — novo pedido",
    fr: "Prêt interbibliothèques {lender} → {borrower} — nouvelle demande",
    es: "Préstamo interbibliotecario {lender} → {borrower} — nueva solicitud",
    en: "Interlibrary loan {lender} → {borrower} — new request",
    it: "Prestito interbibliotecario {lender} → {borrower} — nuova richiesta",
    de: "Fernleihe {lender} → {borrower} — neue Anfrage",
    ca: "Préstec interbibliotecari {lender} → {borrower} — nova sol·licitud",
    eo: "Interbiblioteka prunto {lender} → {borrower} — nova peto",
    nl: "Interbibliothecair leenverkeer {lender} → {borrower} — nieuwe aanvraag",
    el: "Διαδανεισμός {lender} → {borrower} — νέο αίτημα"
  },
  "ill.subject.prepared": {
    "pt-BR": "Empréstimo interbibliotecas {lender} → {borrower} — preparado",
    fr: "Prêt interbibliothèques {lender} → {borrower} — préparé",
    es: "Préstamo interbibliotecario {lender} → {borrower} — preparado",
    en: "Interlibrary loan {lender} → {borrower} — prepared",
    it: "Prestito interbibliotecario {lender} → {borrower} — preparato",
    de: "Fernleihe {lender} → {borrower} — vorbereitet",
    ca: "Préstec interbibliotecari {lender} → {borrower} — preparat",
    eo: "Interbiblioteka prunto {lender} → {borrower} — preparita",
    nl: "Interbibliothecair leenverkeer {lender} → {borrower} — voorbereid",
    el: "Διαδανεισμός {lender} → {borrower} — προετοιμασμένος"
  },
  "ill.subject.dispatched": {
    "pt-BR": "Empréstimo interbibliotecas {lender} → {borrower} — em circulação",
    fr: "Prêt interbibliothèques {lender} → {borrower} — en circulation",
    es: "Préstamo interbibliotecario {lender} → {borrower} — en circulación",
    en: "Interlibrary loan {lender} → {borrower} — in transit",
    it: "Prestito interbibliotecario {lender} → {borrower} — in circolazione",
    de: "Fernleihe {lender} → {borrower} — unterwegs",
    ca: "Préstec interbibliotecari {lender} → {borrower} — en circulació",
    eo: "Interbiblioteka prunto {lender} → {borrower} — en cirkulado",
    nl: "Interbibliothecair leenverkeer {lender} → {borrower} — onderweg",
    el: "Διαδανεισμός {lender} → {borrower} — σε μεταφορά"
  },
  "ill.subject.return_started": {
    "pt-BR": "Empréstimo interbibliotecas {lender} → {borrower} — devolução iniciada",
    fr: "Prêt interbibliothèques {lender} → {borrower} — retour amorcé",
    es: "Préstamo interbibliotecario {lender} → {borrower} — devolución iniciada",
    en: "Interlibrary loan {lender} → {borrower} — return started",
    it: "Prestito interbibliotecario {lender} → {borrower} — restituzione avviata",
    de: "Fernleihe {lender} → {borrower} — Rückgabe begonnen",
    ca: "Préstec interbibliotecari {lender} → {borrower} — devolució iniciada",
    eo: "Interbiblioteka prunto {lender} → {borrower} — redono komencita",
    nl: "Interbibliothecair leenverkeer {lender} → {borrower} — retour gestart",
    el: "Διαδανεισμός {lender} → {borrower} — έναρξη επιστροφής"
  },
  "ill.subject.returned": {
    "pt-BR": "Empréstimo interbibliotecas {lender} → {borrower} — encerrado",
    fr: "Prêt interbibliothèques {lender} → {borrower} — clôturé",
    es: "Préstamo interbibliotecario {lender} → {borrower} — cerrado",
    en: "Interlibrary loan {lender} → {borrower} — closed",
    it: "Prestito interbibliotecario {lender} → {borrower} — concluso",
    de: "Fernleihe {lender} → {borrower} — abgeschlossen",
    ca: "Préstec interbibliotecari {lender} → {borrower} — tancat",
    eo: "Interbiblioteka prunto {lender} → {borrower} — fermita",
    nl: "Interbibliothecair leenverkeer {lender} → {borrower} — afgesloten",
    el: "Διαδανεισμός {lender} → {borrower} — έκλεισε"
  },
  "ill.subject.cancelled": {
    "pt-BR": "Empréstimo interbibliotecas {lender} → {borrower} — cancelado",
    fr: "Prêt interbibliothèques {lender} → {borrower} — annulé",
    es: "Préstamo interbibliotecario {lender} → {borrower} — cancelado",
    en: "Interlibrary loan {lender} → {borrower} — cancelled",
    it: "Prestito interbibliotecario {lender} → {borrower} — annullato",
    de: "Fernleihe {lender} → {borrower} — storniert",
    ca: "Préstec interbibliotecari {lender} → {borrower} — anul·lat",
    eo: "Interbiblioteka prunto {lender} → {borrower} — nuligita",
    nl: "Interbibliothecair leenverkeer {lender} → {borrower} — geannuleerd",
    el: "Διαδανεισμός {lender} → {borrower} — ακυρώθηκε"
  },
  "ill.subject.overdue": {
    "pt-BR": "Empréstimo interbibliotecas {lender} → {borrower} — em atraso",
    fr: "Prêt interbibliothèques {lender} → {borrower} — en retard",
    es: "Préstamo interbibliotecario {lender} → {borrower} — atrasado",
    en: "Interlibrary loan {lender} → {borrower} — overdue",
    it: "Prestito interbibliotecario {lender} → {borrower} — in ritardo",
    de: "Fernleihe {lender} → {borrower} — überfällig",
    ca: "Préstec interbibliotecari {lender} → {borrower} — endarrerit",
    eo: "Interbiblioteka prunto {lender} → {borrower} — malfruita",
    nl: "Interbibliothecair leenverkeer {lender} → {borrower} — te laat",
    el: "Διαδανεισμός {lender} → {borrower} — σε καθυστέρηση"
  },
  "ill.subject.partially_returned": {
    "pt-BR": "Empréstimo interbibliotecas {lender} → {borrower} — devolução parcial",
    fr: "Prêt interbibliothèques {lender} → {borrower} — retour partiel",
    es: "Préstamo interbibliotecario {lender} → {borrower} — devolución parcial",
    en: "Interlibrary loan {lender} → {borrower} — partial return",
    it: "Prestito interbibliotecario {lender} → {borrower} — restituzione parziale",
    de: "Fernleihe {lender} → {borrower} — Teilrückgabe",
    ca: "Préstec interbibliotecari {lender} → {borrower} — devolució parcial",
    eo: "Interbiblioteka prunto {lender} → {borrower} — parta redono",
    nl: "Interbibliothecair leenverkeer {lender} → {borrower} — gedeeltelijke retour",
    el: "Διαδανεισμός {lender} → {borrower} — μερική επιστροφή"
  },

  // --- Titres (8) ----------------------------------------------------------
  "ill.title.created": {
    "pt-BR": "Novo pedido de empréstimo interbibliotecas",
    fr: "Nouvelle demande de prêt interbibliothèques",
    es: "Nueva solicitud de préstamo interbibliotecario",
    en: "New interlibrary loan request",
    it: "Nuova richiesta di prestito interbibliotecario",
    de: "Neue Fernleihe-Anfrage",
    ca: "Nova sol·licitud de préstec interbibliotecari",
    eo: "Nova peto de interbiblioteka prunto",
    nl: "Nieuwe aanvraag interbibliothecair leenverkeer",
    el: "Νέο αίτημα διαδανεισμού"
  },
  "ill.title.prepared": {
    "pt-BR": "Empréstimo preparado",
    fr: "Prêt préparé",
    es: "Préstamo preparado",
    en: "Loan prepared",
    it: "Prestito preparato",
    de: "Leihe vorbereitet",
    ca: "Préstec preparat",
    eo: "Prunto preparita",
    nl: "Uitlening voorbereid",
    el: "Ο δανεισμός προετοιμάστηκε"
  },
  "ill.title.dispatched": {
    "pt-BR": "Empréstimo em circulação",
    fr: "Prêt en circulation",
    es: "Préstamo en circulación",
    en: "Loan in transit",
    it: "Prestito in circolazione",
    de: "Leihe unterwegs",
    ca: "Préstec en circulació",
    eo: "Prunto en cirkulado",
    nl: "Uitlening onderweg",
    el: "Ο δανεισμός σε μεταφορά"
  },
  "ill.title.return_started": {
    "pt-BR": "Devolução iniciada",
    fr: "Retour amorcé",
    es: "Devolución iniciada",
    en: "Return started",
    it: "Restituzione avviata",
    de: "Rückgabe begonnen",
    ca: "Devolució iniciada",
    eo: "Redono komencita",
    nl: "Retour gestart",
    el: "Έναρξη επιστροφής"
  },
  "ill.title.returned": {
    "pt-BR": "Empréstimo encerrado",
    fr: "Prêt clôturé",
    es: "Préstamo cerrado",
    en: "Loan closed",
    it: "Prestito concluso",
    de: "Leihe abgeschlossen",
    ca: "Préstec tancat",
    eo: "Prunto fermita",
    nl: "Uitlening afgesloten",
    el: "Ο δανεισμός έκλεισε"
  },
  "ill.title.cancelled": {
    "pt-BR": "Empréstimo cancelado",
    fr: "Prêt annulé",
    es: "Préstamo cancelado",
    en: "Loan cancelled",
    it: "Prestito annullato",
    de: "Leihe storniert",
    ca: "Préstec anul·lat",
    eo: "Prunto nuligita",
    nl: "Uitlening geannuleerd",
    el: "Ο δανεισμός ακυρώθηκε"
  },
  "ill.title.overdue": {
    "pt-BR": "Empréstimo em atraso",
    fr: "Prêt en retard",
    es: "Préstamo atrasado",
    en: "Loan overdue",
    it: "Prestito in ritardo",
    de: "Leihe überfällig",
    ca: "Préstec endarrerit",
    eo: "Prunto malfruita",
    nl: "Uitlening te laat",
    el: "Δανεισμός σε καθυστέρηση"
  },
  "ill.title.partially_returned": {
    "pt-BR": "Devolução parcial",
    fr: "Retour partiel",
    es: "Devolución parcial",
    en: "Partial return",
    it: "Restituzione parziale",
    de: "Teilrückgabe",
    ca: "Devolució parcial",
    eo: "Parta redono",
    nl: "Gedeeltelijke retour",
    el: "Μερική επιστροφή"
  },

  // --- Intros de 'created' — matrice à 2 axes (4) --------------------------
  "ill.intro.created.lender_initiator": {
    "pt-BR": "Sua biblioteca acaba de propor um empréstimo de documentos a {borrower}. O pedido {loanRef} está registrado. {borrower} foi informada e responderá para dar seguimento a esta proposta. O detalhe dos documentos envolvidos está abaixo.",
    fr: "Votre bibliothèque vient de proposer un prêt de documents à {borrower}. La demande {loanRef} est enregistrée. {borrower} en est informée et vous répondra pour donner suite à cette proposition. Le détail des documents concernés figure ci-dessous.",
    es: "Tu biblioteca acaba de proponer un préstamo de documentos a {borrower}. La solicitud {loanRef} está registrada. {borrower} ha sido informada y os responderá para dar curso a esta propuesta. El detalle de los documentos implicados está abajo.",
    en: "Your library has just offered a loan of documents to {borrower}. Request {loanRef} is registered. {borrower} has been notified and will reply to take this offer forward. The list of documents concerned is below.",
    it: "La vostra biblioteca ha appena proposto un prestito di documenti a {borrower}. La richiesta {loanRef} è registrata. {borrower} è stata informata e vi risponderà per dare seguito a questa proposta. Il dettaglio dei documenti interessati è qui sotto.",
    de: "Eure Bibliothek hat {borrower} soeben eine Ausleihe von Dokumenten angeboten. Die Anfrage {loanRef} ist registriert. {borrower} wurde benachrichtigt und wird antworten, um dieses Angebot weiterzuverfolgen. Die Liste der betreffenden Dokumente steht unten.",
    ca: "La vostra biblioteca acaba de proposar un préstec de documents a {borrower}. La sol·licitud {loanRef} està registrada. {borrower} ha estat informada i us respondrà per donar curs a aquesta proposta. El detall dels documents implicats és a sota.",
    eo: "Via biblioteko ĵus proponis prunton de dokumentoj al {borrower}. La peto {loanRef} estas registrita. {borrower} estis informita kaj respondos por daŭrigi ĉi tiun proponon. La detalo de la koncernaj dokumentoj estas sube.",
    nl: "Je bibliotheek heeft zojuist een uitlening van documenten aangeboden aan {borrower}. Aanvraag {loanRef} is geregistreerd. {borrower} is op de hoogte gebracht en zal reageren om dit voorstel een vervolg te geven. De lijst met betrokken documenten staat hieronder.",
    el: "Η βιβλιοθήκη σας μόλις πρότεινε δανεισμό τεκμηρίων στη {borrower}. Το αίτημα {loanRef} καταχωρίστηκε. Η {borrower} ενημερώθηκε και θα σας απαντήσει για να προχωρήσει αυτή η πρόταση. Η λίστα των σχετικών τεκμηρίων είναι παρακάτω."
  },
  "ill.intro.created.borrower_partner": {
    "pt-BR": "{lender} propõe à sua biblioteca um empréstimo de documentos. O pedido {loanRef} acaba de ser aberto. Para aceitar, conversar ou organizar a retirada, entre em contato com a pessoa indicada abaixo. O detalhe dos documentos propostos está mais abaixo.",
    fr: "{lender} propose à votre bibliothèque un prêt de documents. La demande {loanRef} vient d'être ouverte. Pour accepter, en discuter ou organiser le retrait, contactez la personne indiquée ci-dessous. Le détail des documents proposés figure plus bas.",
    es: "{lender} propone a tu biblioteca un préstamo de documentos. La solicitud {loanRef} acaba de abrirse. Para aceptar, conversar u organizar el retiro, contacta a la persona indicada abajo. El detalle de los documentos propuestos está más abajo.",
    en: "{lender} is offering your library a loan of documents. Request {loanRef} has just been opened. To accept, discuss it or arrange pickup, contact the person indicated below. The list of documents offered is further down.",
    it: "{lender} propone alla vostra biblioteca un prestito di documenti. La richiesta {loanRef} è appena stata aperta. Per accettare, discuterne o organizzare il ritiro, contattate la persona indicata qui sotto. Il dettaglio dei documenti proposti è più in basso.",
    de: "{lender} bietet eurer Bibliothek eine Ausleihe von Dokumenten an. Die Anfrage {loanRef} wurde soeben eröffnet. Um anzunehmen, zu besprechen oder die Abholung zu organisieren, wendet euch an die unten genannte Person. Die Liste der angebotenen Dokumente steht weiter unten.",
    ca: "{lender} proposa a la vostra biblioteca un préstec de documents. La sol·licitud {loanRef} acaba d'obrir-se. Per acceptar, parlar-ne o organitzar la recollida, contacteu la persona indicada a sota. El detall dels documents proposats és més avall.",
    eo: "{lender} proponas al via biblioteko prunton de dokumentoj. La peto {loanRef} ĵus malfermiĝis. Por akcepti, priparoli aŭ organizi la prenon, kontaktu la personon indikitan sube. La detalo de la proponitaj dokumentoj estas pli sube.",
    nl: "{lender} biedt je bibliotheek een uitlening van documenten aan. Aanvraag {loanRef} is zojuist geopend. Om te accepteren, te overleggen of de afhaling te regelen, neem contact op met de hieronder vermelde persoon. De lijst met aangeboden documenten staat verderop.",
    el: "Η {lender} προσφέρει στη βιβλιοθήκη σας δανεισμό τεκμηρίων. Το αίτημα {loanRef} μόλις άνοιξε. Για να αποδεχτείτε, να το συζητήσετε ή να οργανώσετε την παραλαβή, επικοινωνήστε με το άτομο που αναφέρεται παρακάτω. Η λίστα των προσφερόμενων τεκμηρίων είναι πιο κάτω."
  },
  "ill.intro.created.borrower_initiator": {
    "pt-BR": "Sua biblioteca acaba de solicitar um empréstimo de documentos a {lender}. O pedido {loanRef} está registrado. {lender} foi informada e responderá para dar seguimento a este pedido. O detalhe dos documentos solicitados está abaixo.",
    fr: "Votre bibliothèque vient de solliciter un emprunt de documents auprès de {lender}. La demande {loanRef} est enregistrée. {lender} en est informée et vous répondra pour donner suite à cette demande. Le détail des documents demandés figure ci-dessous.",
    es: "Tu biblioteca acaba de solicitar un préstamo de documentos a {lender}. La solicitud {loanRef} está registrada. {lender} ha sido informada y os responderá para dar curso a esta solicitud. El detalle de los documentos solicitados está abajo.",
    en: "Your library has just requested a loan of documents from {lender}. Request {loanRef} is registered. {lender} has been notified and will reply to take this request forward. The list of documents requested is below.",
    it: "La vostra biblioteca ha appena richiesto un prestito di documenti a {lender}. La richiesta {loanRef} è registrata. {lender} è stata informata e vi risponderà per dare seguito a questa richiesta. Il dettaglio dei documenti richiesti è qui sotto.",
    de: "Eure Bibliothek hat soeben eine Ausleihe von Dokumenten bei {lender} angefragt. Die Anfrage {loanRef} ist registriert. {lender} wurde benachrichtigt und wird antworten, um diese Anfrage weiterzuverfolgen. Die Liste der angefragten Dokumente steht unten.",
    ca: "La vostra biblioteca acaba de sol·licitar un préstec de documents a {lender}. La sol·licitud {loanRef} està registrada. {lender} ha estat informada i us respondrà per donar curs a aquesta sol·licitud. El detall dels documents sol·licitats és a sota.",
    eo: "Via biblioteko ĵus petis prunton de dokumentoj de {lender}. La peto {loanRef} estas registrita. {lender} estis informita kaj respondos por daŭrigi ĉi tiun peton. La detalo de la petitaj dokumentoj estas sube.",
    nl: "Je bibliotheek heeft zojuist een uitlening van documenten aangevraagd bij {lender}. Aanvraag {loanRef} is geregistreerd. {lender} is op de hoogte gebracht en zal reageren om deze aanvraag een vervolg te geven. De lijst met aangevraagde documenten staat hieronder.",
    el: "Η βιβλιοθήκη σας μόλις ζήτησε δανεισμό τεκμηρίων από τη {lender}. Το αίτημα {loanRef} καταχωρίστηκε. Η {lender} ενημερώθηκε και θα σας απαντήσει για να προχωρήσει αυτό το αίτημα. Η λίστα των τεκμηρίων που ζητήθηκαν είναι παρακάτω."
  },
  "ill.intro.created.lender_partner": {
    "pt-BR": "{borrower} solicita à sua biblioteca um empréstimo de documentos. O pedido {loanRef} acaba de ser aberto. Para responder, conversar ou organizar o envio, entre em contato com a pessoa indicada abaixo. O detalhe dos documentos solicitados está mais abaixo.",
    fr: "{borrower} sollicite auprès de votre bibliothèque un emprunt de documents. La demande {loanRef} vient d'être ouverte. Pour répondre, en discuter ou organiser l'envoi, contactez la personne indiquée ci-dessous. Le détail des documents demandés figure plus bas.",
    es: "{borrower} solicita a tu biblioteca un préstamo de documentos. La solicitud {loanRef} acaba de abrirse. Para responder, conversar u organizar el envío, contacta a la persona indicada abajo. El detalle de los documentos solicitados está más abajo.",
    en: "{borrower} is requesting a loan of documents from your library. Request {loanRef} has just been opened. To reply, discuss it or arrange dispatch, contact the person indicated below. The list of documents requested is further down.",
    it: "{borrower} richiede alla vostra biblioteca un prestito di documenti. La richiesta {loanRef} è appena stata aperta. Per rispondere, discuterne o organizzare l'invio, contattate la persona indicata qui sotto. Il dettaglio dei documenti richiesti è più in basso.",
    de: "{borrower} fragt bei eurer Bibliothek eine Ausleihe von Dokumenten an. Die Anfrage {loanRef} wurde soeben eröffnet. Um zu antworten, zu besprechen oder den Versand zu organisieren, wendet euch an die unten genannte Person. Die Liste der angefragten Dokumente steht weiter unten.",
    ca: "{borrower} sol·licita a la vostra biblioteca un préstec de documents. La sol·licitud {loanRef} acaba d'obrir-se. Per respondre, parlar-ne o organitzar l'enviament, contacteu la persona indicada a sota. El detall dels documents sol·licitats és més avall.",
    eo: "{borrower} petas de via biblioteko prunton de dokumentoj. La peto {loanRef} ĵus malfermiĝis. Por respondi, priparoli aŭ organizi la sendon, kontaktu la personon indikitan sube. La detalo de la petitaj dokumentoj estas pli sube.",
    nl: "{borrower} vraagt je bibliotheek een uitlening van documenten aan. Aanvraag {loanRef} is zojuist geopend. Om te reageren, te overleggen of de verzending te regelen, neem contact op met de hieronder vermelde persoon. De lijst met aangevraagde documenten staat verderop.",
    el: "Η {borrower} ζητά δανεισμό τεκμηρίων από τη βιβλιοθήκη σας. Το αίτημα {loanRef} μόλις άνοιξε. Για να απαντήσετε, να το συζητήσετε ή να οργανώσετε την αποστολή, επικοινωνήστε με το άτομο που αναφέρεται παρακάτω. Η λίστα των τεκμηρίων που ζητήθηκαν είναι πιο κάτω."
  },

  // --- Intros de statut — symétriques (7) ----------------------------------
  "ill.intro.prepared": {
    "pt-BR": "O empréstimo interbibliotecas {loanRef} entre {lender} e {borrower} está agora preparado. Os documentos foram reunidos e estão prontos para partir. O detalhe está abaixo.",
    fr: "Le prêt interbibliothèques {loanRef} entre {lender} et {borrower} est maintenant préparé. Les documents sont rassemblés et prêts à partir. Le détail figure ci-dessous.",
    es: "El préstamo interbibliotecario {loanRef} entre {lender} y {borrower} ya está preparado. Los documentos están reunidos y listos para partir. El detalle está abajo.",
    en: "Interlibrary loan {loanRef} between {lender} and {borrower} is now prepared. The documents are gathered and ready to leave. The details are below.",
    it: "Il prestito interbibliotecario {loanRef} tra {lender} e {borrower} è ora preparato. I documenti sono stati riuniti e pronti a partire. Il dettaglio è qui sotto.",
    de: "Die Fernleihe {loanRef} zwischen {lender} und {borrower} ist nun vorbereitet. Die Dokumente sind zusammengestellt und versandbereit. Die Einzelheiten stehen unten.",
    ca: "El préstec interbibliotecari {loanRef} entre {lender} i {borrower} ja està preparat. Els documents estan reunits i a punt per sortir. El detall és a sota.",
    eo: "La interbiblioteka prunto {loanRef} inter {lender} kaj {borrower} nun estas preparita. La dokumentoj estas kunigitaj kaj pretaj por foriri. La detalo estas sube.",
    nl: "Het interbibliothecair leenverkeer {loanRef} tussen {lender} en {borrower} is nu voorbereid. De documenten zijn verzameld en klaar om te vertrekken. De details staan hieronder.",
    el: "Ο διαδανεισμός {loanRef} μεταξύ {lender} και {borrower} είναι πλέον προετοιμασμένος. Τα τεκμήρια συγκεντρώθηκαν και είναι έτοιμα να φύγουν. Οι λεπτομέρειες είναι παρακάτω."
  },
  "ill.intro.dispatched": {
    "pt-BR": "Os documentos do empréstimo interbibliotecas {loanRef} estão em circulação entre {lender} e {borrower}. Conforme o modo combinado, viajam pelo correio ou em mãos. O detalhe está abaixo.",
    fr: "Les documents du prêt interbibliothèques {loanRef} sont en circulation entre {lender} et {borrower}. Selon le mode convenu, ils voyagent par voie postale ou de la main à la main. Le détail figure ci-dessous.",
    es: "Los documentos del préstamo interbibliotecario {loanRef} están en circulación entre {lender} y {borrower}. Según el modo acordado, viajan por correo o en mano. El detalle está abajo.",
    en: "The documents of interlibrary loan {loanRef} are in transit between {lender} and {borrower}. Depending on the agreed method, they travel by post or hand to hand. The details are below.",
    it: "I documenti del prestito interbibliotecario {loanRef} sono in circolazione tra {lender} e {borrower}. Secondo il modo concordato, viaggiano per posta o a mano. Il dettaglio è qui sotto.",
    de: "Die Dokumente der Fernleihe {loanRef} sind zwischen {lender} und {borrower} unterwegs. Je nach vereinbarter Art reisen sie per Post oder von Hand zu Hand. Die Einzelheiten stehen unten.",
    ca: "Els documents del préstec interbibliotecari {loanRef} estan en circulació entre {lender} i {borrower}. Segons el mode acordat, viatgen per correu o en mà. El detall és a sota.",
    eo: "La dokumentoj de la interbiblioteka prunto {loanRef} estas en cirkulado inter {lender} kaj {borrower}. Laŭ la interkonsentita maniero, ili vojaĝas poŝte aŭ man-al-mane. La detalo estas sube.",
    nl: "De documenten van het interbibliothecair leenverkeer {loanRef} zijn onderweg tussen {lender} en {borrower}. Afhankelijk van de afgesproken wijze reizen ze per post of van hand tot hand. De details staan hieronder.",
    el: "Τα τεκμήρια του διαδανεισμού {loanRef} βρίσκονται σε μεταφορά μεταξύ {lender} και {borrower}. Ανάλογα με τον συμφωνημένο τρόπο, ταξιδεύουν ταχυδρομικά ή από χέρι σε χέρι. Οι λεπτομέρειες είναι παρακάτω."
  },
  "ill.intro.return_started": {
    "pt-BR": "A devolução do empréstimo interbibliotecas {loanRef} entre {lender} e {borrower} acaba de ser iniciada. Os documentos fazem o caminho de volta. O detalhe está abaixo.",
    fr: "Le retour du prêt interbibliothèques {loanRef} entre {lender} et {borrower} vient d'être amorcé. Les documents font le chemin inverse. Le détail figure ci-dessous.",
    es: "La devolución del préstamo interbibliotecario {loanRef} entre {lender} y {borrower} acaba de iniciarse. Los documentos hacen el camino de vuelta. El detalle está abajo.",
    en: "The return of interlibrary loan {loanRef} between {lender} and {borrower} has just started. The documents are making the journey back. The details are below.",
    it: "La restituzione del prestito interbibliotecario {loanRef} tra {lender} e {borrower} è appena stata avviata. I documenti fanno il percorso inverso. Il dettaglio è qui sotto.",
    de: "Die Rückgabe der Fernleihe {loanRef} zwischen {lender} und {borrower} hat soeben begonnen. Die Dokumente treten den Rückweg an. Die Einzelheiten stehen unten.",
    ca: "La devolució del préstec interbibliotecari {loanRef} entre {lender} i {borrower} acaba d'iniciar-se. Els documents fan el camí de tornada. El detall és a sota.",
    eo: "La redono de la interbiblioteka prunto {loanRef} inter {lender} kaj {borrower} ĵus komenciĝis. La dokumentoj faras la revojon. La detalo estas sube.",
    nl: "De retour van het interbibliothecair leenverkeer {loanRef} tussen {lender} en {borrower} is zojuist gestart. De documenten maken de terugreis. De details staan hieronder.",
    el: "Η επιστροφή του διαδανεισμού {loanRef} μεταξύ {lender} και {borrower} μόλις ξεκίνησε. Τα τεκμήρια κάνουν την αντίστροφη διαδρομή. Οι λεπτομέρειες είναι παρακάτω."
  },
  "ill.intro.returned": {
    "pt-BR": "O empréstimo interbibliotecas {loanRef} entre {lender} e {borrower} está encerrado. Os documentos voltaram à sua biblioteca. Um acervo circulou de um coletivo a outro: é assim que vivem nossas bibliotecas.",
    fr: "Le prêt interbibliothèques {loanRef} entre {lender} et {borrower} est clôturé. Les documents ont regagné leur bibliothèque. Un fonds a circulé d'un collectif vers un autre : c'est ainsi que vivent nos bibliothèques.",
    es: "El préstamo interbibliotecario {loanRef} entre {lender} y {borrower} está cerrado. Los documentos han vuelto a su biblioteca. Un fondo ha circulado de un colectivo a otro: así es como viven nuestras bibliotecas.",
    en: "Interlibrary loan {loanRef} between {lender} and {borrower} is closed. The documents have returned to their library. A collection has travelled from one collective to another: this is how our libraries live.",
    it: "Il prestito interbibliotecario {loanRef} tra {lender} e {borrower} è concluso. I documenti sono tornati alla loro biblioteca. Un fondo è circolato da un collettivo all'altro: è così che vivono le nostre biblioteche.",
    de: "Die Fernleihe {loanRef} zwischen {lender} und {borrower} ist abgeschlossen. Die Dokumente sind in ihre Bibliothek zurückgekehrt. Ein Bestand ist von einem Kollektiv zum anderen gewandert: so leben unsere Bibliotheken.",
    ca: "El préstec interbibliotecari {loanRef} entre {lender} i {borrower} està tancat. Els documents han tornat a la seva biblioteca. Un fons ha circulat d'un col·lectiu a un altre: així és com viuen les nostres biblioteques.",
    eo: "La interbiblioteka prunto {loanRef} inter {lender} kaj {borrower} estas fermita. La dokumentoj revenis al sia biblioteko. Kolekto cirkulis de unu kolektivo al alia: tiel vivas niaj bibliotekoj.",
    nl: "Het interbibliothecair leenverkeer {loanRef} tussen {lender} en {borrower} is afgesloten. De documenten zijn teruggekeerd naar hun bibliotheek. Een collectie is van het ene collectief naar het andere gereisd: zo leven onze bibliotheken.",
    el: "Ο διαδανεισμός {loanRef} μεταξύ {lender} και {borrower} έκλεισε. Τα τεκμήρια επέστρεψαν στη βιβλιοθήκη τους. Μια συλλογή ταξίδεψε από μια συλλογικότητα σε μια άλλη: έτσι ζουν οι βιβλιοθήκες μας."
  },
  "ill.intro.cancelled": {
    "pt-BR": "O empréstimo interbibliotecas {loanRef} entre {lender} e {borrower} foi cancelado. Nenhuma troca ocorrerá no âmbito deste pedido. Para qualquer dúvida, as duas bibliotecas podem se contatar diretamente.",
    fr: "Le prêt interbibliothèques {loanRef} entre {lender} et {borrower} a été annulé. Aucun échange n'aura lieu dans le cadre de cette demande. Pour toute question, les deux bibliothèques peuvent se rapprocher directement.",
    es: "El préstamo interbibliotecario {loanRef} entre {lender} y {borrower} ha sido cancelado. No habrá ningún intercambio en el marco de esta solicitud. Para cualquier duda, las dos bibliotecas pueden contactarse directamente.",
    en: "Interlibrary loan {loanRef} between {lender} and {borrower} has been cancelled. No exchange will take place under this request. For any question, the two libraries can get in touch directly.",
    it: "Il prestito interbibliotecario {loanRef} tra {lender} e {borrower} è stato annullato. Nessuno scambio avrà luogo nell'ambito di questa richiesta. Per qualsiasi domanda, le due biblioteche possono contattarsi direttamente.",
    de: "Die Fernleihe {loanRef} zwischen {lender} und {borrower} wurde storniert. Im Rahmen dieser Anfrage findet kein Austausch statt. Bei Fragen können sich die beiden Bibliotheken direkt miteinander in Verbindung setzen.",
    ca: "El préstec interbibliotecari {loanRef} entre {lender} i {borrower} ha estat anul·lat. No hi haurà cap intercanvi en el marc d'aquesta sol·licitud. Per a qualsevol dubte, les dues biblioteques poden contactar-se directament.",
    eo: "La interbiblioteka prunto {loanRef} inter {lender} kaj {borrower} estis nuligita. Neniu interŝanĝo okazos en la kadro de ĉi tiu peto. Por iu ajn demando, la du bibliotekoj povas rekte interkontaktiĝi.",
    nl: "Het interbibliothecair leenverkeer {loanRef} tussen {lender} en {borrower} is geannuleerd. Er vindt geen uitwisseling plaats in het kader van deze aanvraag. Bij vragen kunnen de twee bibliotheken rechtstreeks contact met elkaar opnemen.",
    el: "Ο διαδανεισμός {loanRef} μεταξύ {lender} και {borrower} ακυρώθηκε. Καμία ανταλλαγή δεν θα γίνει στο πλαίσιο αυτού του αιτήματος. Για οποιαδήποτε ερώτηση, οι δύο βιβλιοθήκες μπορούν να επικοινωνήσουν απευθείας."
  },
  "ill.intro.overdue": {
    "pt-BR": "O empréstimo interbibliotecas {loanRef} entre {lender} e {borrower} ultrapassou a data de devolução prevista. As duas bibliotecas são convidadas a se aproximar para fazer o ponto sobre a situação dos documentos. O detalhe está abaixo.",
    fr: "Le prêt interbibliothèques {loanRef} entre {lender} et {borrower} a dépassé sa date de retour prévue. Les deux bibliothèques sont invitées à se rapprocher pour faire le point sur la situation des documents. Le détail figure ci-dessous.",
    es: "El préstamo interbibliotecario {loanRef} entre {lender} y {borrower} ha superado su fecha de devolución prevista. Se invita a las dos bibliotecas a ponerse en contacto para hacer el punto sobre la situación de los documentos. El detalle está abajo.",
    en: "Interlibrary loan {loanRef} between {lender} and {borrower} has passed its expected return date. Both libraries are invited to get in touch to take stock of where the documents stand. The details are below.",
    it: "Il prestito interbibliotecario {loanRef} tra {lender} e {borrower} ha superato la data di restituzione prevista. Le due biblioteche sono invitate a mettersi in contatto per fare il punto sulla situazione dei documenti. Il dettaglio è qui sotto.",
    de: "Die Fernleihe {loanRef} zwischen {lender} und {borrower} hat ihr vorgesehenes Rückgabedatum überschritten. Beide Bibliotheken sind eingeladen, sich abzustimmen, um den Stand der Dokumente zu klären. Die Einzelheiten stehen unten.",
    ca: "El préstec interbibliotecari {loanRef} entre {lender} i {borrower} ha superat la data de devolució prevista. Es convida les dues biblioteques a posar-se en contacte per fer el punt sobre la situació dels documents. El detall és a sota.",
    eo: "La interbiblioteka prunto {loanRef} inter {lender} kaj {borrower} preterpasis sian antaŭviditan redatan daton. La du bibliotekoj estas invitataj interkontaktiĝi por pripensi la situacion de la dokumentoj. La detalo estas sube.",
    nl: "Het interbibliothecair leenverkeer {loanRef} tussen {lender} en {borrower} heeft de verwachte retourdatum overschreden. Beide bibliotheken worden uitgenodigd om contact op te nemen en de stand van zaken van de documenten te bekijken. De details staan hieronder.",
    el: "Ο διαδανεισμός {loanRef} μεταξύ {lender} και {borrower} ξεπέρασε την προβλεπόμενη ημερομηνία επιστροφής. Οι δύο βιβλιοθήκες καλούνται να επικοινωνήσουν για να κάνουν τον απολογισμό της κατάστασης των τεκμηρίων. Οι λεπτομέρειες είναι παρακάτω."
  },
  "ill.intro.partially_returned": {
    "pt-BR": "O empréstimo interbibliotecas {loanRef} entre {lender} e {borrower} foi parcialmente devolvido. Uma parte dos documentos voltou à sua biblioteca; o restante ainda está em circulação. O detalhe está abaixo, documento por documento.",
    fr: "Le prêt interbibliothèques {loanRef} entre {lender} et {borrower} est partiellement rendu. Une partie des documents a regagné sa bibliothèque ; le reste est encore en circulation. Le détail figure ci-dessous, document par document.",
    es: "El préstamo interbibliotecario {loanRef} entre {lender} y {borrower} ha sido devuelto parcialmente. Una parte de los documentos ha vuelto a su biblioteca; el resto sigue en circulación. El detalle está abajo, documento por documento.",
    en: "Interlibrary loan {loanRef} between {lender} and {borrower} has been partially returned. Some of the documents have returned to their library; the rest are still in transit. The details are below, document by document.",
    it: "Il prestito interbibliotecario {loanRef} tra {lender} e {borrower} è stato restituito parzialmente. Una parte dei documenti è tornata alla propria biblioteca; il resto è ancora in circolazione. Il dettaglio è qui sotto, documento per documento.",
    de: "Die Fernleihe {loanRef} zwischen {lender} und {borrower} wurde teilweise zurückgegeben. Ein Teil der Dokumente ist in seine Bibliothek zurückgekehrt; der Rest ist noch unterwegs. Die Einzelheiten stehen unten, Dokument für Dokument.",
    ca: "El préstec interbibliotecari {loanRef} entre {lender} i {borrower} ha estat retornat parcialment. Una part dels documents ha tornat a la seva biblioteca; la resta encara està en circulació. El detall és a sota, document per document.",
    eo: "La interbiblioteka prunto {loanRef} inter {lender} kaj {borrower} estis parte redonita. Parto de la dokumentoj revenis al sia biblioteko; la cetero ankoraŭ estas en cirkulado. La detalo estas sube, dokumento post dokumento.",
    nl: "Het interbibliothecair leenverkeer {loanRef} tussen {lender} en {borrower} is gedeeltelijk teruggebracht. Een deel van de documenten is teruggekeerd naar hun bibliotheek; de rest is nog onderweg. De details staan hieronder, document voor document.",
    el: "Ο διαδανεισμός {loanRef} μεταξύ {lender} και {borrower} επιστράφηκε μερικώς. Μέρος των τεκμηρίων επέστρεψε στη βιβλιοθήκη του· τα υπόλοιπα βρίσκονται ακόμη σε μεταφορά. Οι λεπτομέρειες είναι παρακάτω, τεκμήριο προς τεκμήριο."
  },

  // --- ActionBox (1) -------------------------------------------------------
  "ill.actionBox.contactPartner": {
    "pt-BR": "Para dar seguimento, entre em contato com: {contact}",
    fr: "Pour donner suite, contactez : {contact}",
    es: "Para dar curso, contacta con: {contact}",
    en: "To take this forward, contact: {contact}",
    it: "Per dare seguito, contattate: {contact}",
    de: "Um fortzufahren, wendet euch an: {contact}",
    ca: "Per donar curs, contacteu amb: {contact}",
    eo: "Por daŭrigi, kontaktu: {contact}",
    nl: "Neem voor het vervolg contact op: {contact}",
    el: "Για να προχωρήσει, επικοινωνήστε: {contact}"
  },

  // --- Libellés de détails (9) ---------------------------------------------
  "ill.detail.loanRef": {
    "pt-BR": "Referência do empréstimo", fr: "Référence du prêt",
    es: "Referencia del préstamo", en: "Loan reference",
    it: "Riferimento del prestito", de: "Leih-Referenz",
    ca: "Referència del préstec", eo: "Referenco de la prunto", nl: "Referentie van de uitlening",
    el: "Αναφορά δανεισμού"
  },
  "ill.detail.lender": {
    "pt-BR": "Biblioteca emprestadora", fr: "Bibliothèque prêteuse",
    es: "Biblioteca prestadora", en: "Lending library",
    it: "Biblioteca prestatrice", de: "Verleihende Bibliothek",
    ca: "Biblioteca prestadora", eo: "Pruntedonanta biblioteko", nl: "Uitlenende bibliotheek",
    el: "Δανείζουσα βιβλιοθήκη"
  },
  "ill.detail.borrower": {
    "pt-BR": "Biblioteca tomadora", fr: "Bibliothèque emprunteuse",
    es: "Biblioteca prestataria", en: "Borrowing library",
    it: "Biblioteca richiedente", de: "Entleihende Bibliothek",
    ca: "Biblioteca prestatària", eo: "Prunteprenanta biblioteko", nl: "Lenende bibliotheek",
    el: "Δανειζόμενη βιβλιοθήκη"
  },
  "ill.detail.startDate": {
    "pt-BR": "Data de partida", fr: "Date de départ",
    es: "Fecha de salida", en: "Start date",
    it: "Data di partenza", de: "Startdatum",
    ca: "Data de sortida", eo: "Ekdato", nl: "Vertrekdatum",
    el: "Ημερομηνία αναχώρησης"
  },
  "ill.detail.dueDate": {
    "pt-BR": "Devolução prevista", fr: "Retour prévu",
    es: "Devolución prevista", en: "Expected return",
    it: "Restituzione prevista", de: "Erwartete Rückgabe",
    ca: "Devolució prevista", eo: "Antaŭvidita redono", nl: "Verwachte retour",
    el: "Προβλεπόμενη επιστροφή"
  },
  "ill.detail.logistics": {
    "pt-BR": "Logística", fr: "Logistique",
    es: "Logística", en: "Logistics",
    it: "Logistica", de: "Logistik",
    ca: "Logística", eo: "Loĝistiko", nl: "Logistiek",
    el: "Εφοδιαστική"
  },
  "ill.detail.meetingPoint": {
    "pt-BR": "Ponto de encontro", fr: "Point de rencontre",
    es: "Punto de encuentro", en: "Meeting point",
    it: "Punto d'incontro", de: "Treffpunkt",
    ca: "Punt de trobada", eo: "Renkontiĝejo", nl: "Ontmoetingspunt",
    el: "Σημείο συνάντησης"
  },
  "ill.detail.itemCount": {
    "pt-BR": "Número de documentos", fr: "Nombre de documents",
    es: "Número de documentos", en: "Number of documents",
    it: "Numero di documenti", de: "Anzahl der Dokumente",
    ca: "Nombre de documents", eo: "Nombro de dokumentoj", nl: "Aantal documenten",
    el: "Αριθμός τεκμηρίων"
  },
  "ill.detail.itemLine": {
    "pt-BR": "Documento", fr: "Document",
    es: "Documento", en: "Document",
    it: "Documento", de: "Dokument",
    ca: "Document", eo: "Dokumento", nl: "Document",
    el: "Τεκμήριο"
  },

  // --- Logistique (1) ------------------------------------------------------
  "ill.logistics.a_combinar": {
    "pt-BR": "A combinar", fr: "À convenir",
    es: "A convenir", en: "To be arranged",
    it: "Da concordare", de: "Noch festzulegen",
    ca: "A convenir", eo: "Interkonsentota", nl: "Af te spreken",
    el: "Προς συνεννόηση"
  },
  // ===== PEB — statut d'exemplaire & synthèse retour partiel ===============
  // #ILL-partial. Utilisées par buildDetails() de notify-interlibrary-loan,
  // sur les événements partially_returned (statut + synthèse) et returned
  // (statut). Vocabulaire « tourné destinataire » : emprestado se dit
  // « encore en circulation » (ce qui n'est pas revenu), cancelado « retiré
  // du prêt ». Divergence assumée avec le dictionnaire applicatif, qui parle
  // au gestionnaire (« En prêt », « Annulé »).
  "ill.itemStatus.reservado_para_saida": {
    "pt-BR": "Reservado para saída",
    fr: "Réservé au départ",
    es: "Reservado para la salida",
    en: "Reserved for dispatch",
    it: "Riservato per la partenza",
    de: "Für den Versand reserviert",
    ca: "Reservat per a la sortida",
    eo: "Rezervita por la foriro",
    nl: "Gereserveerd voor verzending",
    el: "Δεσμευμένο για αποστολή"
  },
  "ill.itemStatus.emprestado": {
    "pt-BR": "Ainda em circulação",
    fr: "Encore en circulation",
    es: "Aún en circulación",
    en: "Still in circulation",
    it: "Ancora in circolazione",
    de: "Noch unterwegs",
    ca: "Encara en circulació",
    eo: "Ankoraŭ en cirkulado",
    nl: "Nog in circulatie",
    el: "Ακόμη σε κυκλοφορία"
  },
  "ill.itemStatus.devolvido": {
    "pt-BR": "Devolvido",
    fr: "Rendu",
    es: "Devuelto",
    en: "Returned",
    it: "Restituito",
    de: "Zurückgegeben",
    ca: "Retornat",
    eo: "Redonita",
    nl: "Teruggebracht",
    el: "Επιστράφηκε"
  },
  "ill.itemStatus.perdido": {
    "pt-BR": "Perdido",
    fr: "Perdu",
    es: "Perdido",
    en: "Lost",
    it: "Perduto",
    de: "Verloren",
    ca: "Perdut",
    eo: "Perdita",
    nl: "Verloren",
    el: "Χαμένο"
  },
  "ill.itemStatus.danificado": {
    "pt-BR": "Danificado",
    fr: "Endommagé",
    es: "Dañado",
    en: "Damaged",
    it: "Danneggiato",
    de: "Beschädigt",
    ca: "Malmès",
    eo: "Difektita",
    nl: "Beschadigd",
    el: "Φθαρμένο"
  },
  "ill.itemStatus.cancelado": {
    "pt-BR": "Retirado do empréstimo",
    fr: "Retiré du prêt",
    es: "Retirado del préstamo",
    en: "Removed from the loan",
    it: "Rimosso dal prestito",
    de: "Aus der Leihe entfernt",
    ca: "Retirat del préstec",
    eo: "Forigita el la prunto",
    nl: "Uit de uitlening verwijderd",
    el: "Αφαιρέθηκε από τον δανεισμό"
  },
  "ill.detail.returnSummary": {
    "pt-BR": "Balanço da devolução",
    fr: "Bilan du retour",
    es: "Balance de la devolución",
    en: "Return summary",
    it: "Bilancio della restituzione",
    de: "Rückgabe-Übersicht",
    ca: "Balanç de la devolució",
    eo: "Bilanco de la redono",
    nl: "Overzicht van de retour",
    el: "Απολογισμός επιστροφής"
  },
  "ill.detail.returnSummaryValue": {
    "pt-BR": "{settled} resolvido(s), {outstanding} ainda em circulação",
    fr: "{settled} réglé(s), {outstanding} encore en circulation",
    es: "{settled} resuelto(s), {outstanding} aún en circulación",
    en: "{settled} settled, {outstanding} still in circulation",
    it: "{settled} risolto(i), {outstanding} ancora in circolazione",
    de: "{settled} erledigt, {outstanding} noch unterwegs",
    ca: "{settled} resolt(s), {outstanding} encara en circulació",
    eo: "{settled} solvita(j), {outstanding} ankoraŭ en cirkulado",
    nl: "{settled} afgehandeld, {outstanding} nog in circulatie",
    el: "{settled} τακτοποιημένα, {outstanding} ακόμη σε κυκλοφορία"
  },
  // ===== PEB — modes logistiques (#ILL-logistics) ==========================
  // Utilisés par renderLogistics() de notify-interlibrary-loan. 'a_combinar'
  // existe déjà dans ce dictionnaire ; on ajoute les 3 modes introduits par
  // l'énumération logistics_mode.
  "ill.logistics.envio_postal": {
    "pt-BR": "Envio postal",
    fr: "Envoi postal",
    es: "Envío postal",
    en: "Postal delivery",
    it: "Invio postale",
    de: "Postversand",
    ca: "Enviament postal",
    eo: "Poŝta sendo",
    nl: "Verzending per post",
    el: "Ταχυδρομική αποστολή"
  },
  "ill.logistics.entrega_em_maos": {
    "pt-BR": "Entrega em mãos",
    fr: "Remise en main propre",
    es: "Entrega en mano",
    en: "Hand delivery",
    it: "Consegna a mano",
    de: "Persönliche Übergabe",
    ca: "Lliurament en mà",
    eo: "Enmana transdono",
    nl: "Persoonlijke overhandiging",
    el: "Παράδοση στο χέρι"
  },
  "ill.logistics.transporte_militante": {
    "pt-BR": "Transporte militante",
    fr: "Portage militant",
    es: "Transporte militante",
    en: "Militant carriage",
    it: "Trasporto militante",
    de: "Militante Beförderung",
    ca: "Transport militant",
    eo: "Aktivisma transporto",
    nl: "Militant transport",
    el: "Αγωνιστική μεταφορά"
  },

  // ===== RGPD purge warning (Spec §7.1, 31/05/2026) =========================
  "rgpd.purge.loans.title": {
    "pt-BR": "Aviso de exclusão de dados — empréstimos",
    fr: "Avis de suppression de données — emprunts",
    es: "Aviso de eliminación de datos — préstamos",
    en: "Data deletion notice — loans",
    it: "Avviso di cancellazione dati — prestiti",
    de: "Hinweis zur Datenlöschung — Ausleihen",
    ca: "Avís de supressió de dades — préstecs",
    eo: "Sciigo pri datumforviŝo — pruntoj",
    nl: "Bericht over gegevensverwijdering — uitleningen",
    el: "Ειδοποίηση διαγραφής δεδομένων — δανεισμοί"
  },
  "rgpd.purge.loans.intro": {
    "pt-BR": "Conforme nossa política de retenção de dados, teu histórico de empréstimos antigos será excluído em 30 dias.",
    fr: "Conformément à notre politique de rétention de données, ton historique d'emprunts anciens sera supprimé dans 30 jours.",
    es: "Conforme a nuestra política de retención de datos, tu historial de préstamos antiguos será eliminado en 30 días.",
    en: "In accordance with our data retention policy, your history of old loans will be deleted in 30 days.",
    it: "Secondo la nostra politica di conservazione dei dati, la tua cronologia di prestiti vecchi sarà cancellata tra 30 giorni.",
    de: "Gemäß unserer Datenaufbewahrungsrichtlinie wird dein Verlauf alter Ausleihen in 30 Tagen gelöscht.",
    ca: "D'acord amb la nostra política de retenció de dades, el teu historial de préstecs antics serà eliminat en 30 dies.",
    eo: "Laŭ nia datumretenpolitiko, via historio de malnovaj pruntoj estos forviŝita post 30 tagoj.",
    nl: "Conform ons gegevensbewaarbeleid wordt je geschiedenis van oude uitleningen over 30 dagen verwijderd.",
    el: "Σύμφωνα με την πολιτική διατήρησης δεδομένων μας, το ιστορικό των παλιών σου δανεισμών θα διαγραφεί σε 30 ημέρες."
  },
  "rgpd.purge.reservations.title": {
    "pt-BR": "Aviso de exclusão de dados — reservas",
    fr: "Avis de suppression de données — réservations",
    es: "Aviso de eliminación de datos — reservas",
    en: "Data deletion notice — reservations",
    it: "Avviso di cancellazione dati — prenotazioni",
    de: "Hinweis zur Datenlöschung — Vormerkungen",
    ca: "Avís de supressió de dades — reserves",
    eo: "Sciigo pri datumforviŝo — rezervoj",
    nl: "Bericht over gegevensverwijdering — reserveringen",
    el: "Ειδοποίηση διαγραφής δεδομένων — κρατήσεις"
  },
  "rgpd.purge.reservations.intro": {
    "pt-BR": "Conforme nossa política de retenção de dados, teu histórico de reservas antigas será excluído em 30 dias.",
    fr: "Conformément à notre politique de rétention de données, ton historique de réservations anciennes sera supprimé dans 30 jours.",
    es: "Conforme a nuestra política de retención de datos, tu historial de reservas antiguas será eliminado en 30 días.",
    en: "In accordance with our data retention policy, your history of old reservations will be deleted in 30 days.",
    it: "Secondo la nostra politica di conservazione dei dati, la tua cronologia di prenotazioni vecchie sarà cancellata tra 30 giorni.",
    de: "Gemäß unserer Datenaufbewahrungsrichtlinie wird dein Verlauf alter Vormerkungen in 30 Tagen gelöscht.",
    ca: "D'acord amb la nostra política de retenció de dades, el teu historial de reserves antigues serà eliminat en 30 dies.",
    eo: "Laŭ nia datumretenpolitiko, via historio de malnovaj rezervoj estos forviŝita post 30 tagoj.",
    nl: "Conform ons gegevensbewaarbeleid wordt je geschiedenis van oude reserveringen over 30 dagen verwijderd.",
    el: "Σύμφωνα με την πολιτική διατήρησης δεδομένων μας, το ιστορικό των παλιών σου κρατήσεων θα διαγραφεί σε 30 ημέρες."
  },
  "rgpd.purge.consultations.title": {
    "pt-BR": "Aviso de exclusão de dados — consultas locais",
    fr: "Avis de suppression de données — consultations sur place",
    es: "Aviso de eliminación de datos — consultas locales",
    en: "Data deletion notice — on-site consultations",
    it: "Avviso di cancellazione dati — consultazioni in sede",
    de: "Hinweis zur Datenlöschung — Lesetermine vor Ort",
    ca: "Avís de supressió de dades — consultes locals",
    eo: "Sciigo pri datumforviŝo — surlokaj konsultoj",
    nl: "Bericht over gegevensverwijdering — raadplegingen ter plaatse",
    el: "Ειδοποίηση διαγραφής δεδομένων — επιτόπιες μελέτες"
  },
  "rgpd.purge.consultations.intro": {
    "pt-BR": "Conforme nossa política de retenção de dados, teu histórico de consultas locais antigas será excluído em 30 dias.",
    fr: "Conformément à notre politique de rétention de données, ton historique de consultations sur place anciennes sera supprimé dans 30 jours.",
    es: "Conforme a nuestra política de retención de datos, tu historial de consultas locales antiguas será eliminado en 30 días.",
    en: "In accordance with our data retention policy, your history of old on-site consultations will be deleted in 30 days.",
    it: "Secondo la nostra politica di conservazione dei dati, la tua cronologia di consultazioni in sede vecchie sarà cancellata tra 30 giorni.",
    de: "Gemäß unserer Datenaufbewahrungsrichtlinie wird dein Verlauf alter Lesetermine vor Ort in 30 Tagen gelöscht.",
    ca: "D'acord amb la nostra política de retenció de dades, el teu historial de consultes locals antigues serà eliminat en 30 dies.",
    eo: "Laŭ nia datumretenpolitiko, via historio de malnovaj surlokaj konsultoj estos forviŝita post 30 tagoj.",
    nl: "Conform ons gegevensbewaarbeleid wordt je geschiedenis van oude raadplegingen ter plaatse over 30 dagen verwijderd.",
    el: "Σύμφωνα με την πολιτική διατήρησης δεδομένων μας, το ιστορικό των παλιών σου επιτόπιων μελετών θα διαγραφεί σε 30 ημέρες."
  },
  "rgpd.purge.windowExplain": {
    "pt-BR": "Esta exclusão é automática e definitiva. Não há nenhuma cópia conservada após o prazo.",
    fr: "Cette suppression est automatique et définitive. Aucune copie n'est conservée au-delà du délai.",
    es: "Esta eliminación es automática y definitiva. No se conserva ninguna copia después del plazo.",
    en: "This deletion is automatic and final. No copy is kept beyond the deadline.",
    it: "Questa cancellazione è automatica e definitiva. Nessuna copia viene conservata dopo la scadenza.",
    de: "Diese Löschung ist automatisch und endgültig. Nach Ablauf der Frist wird keine Kopie aufbewahrt.",
    ca: "Aquesta supressió és automàtica i definitiva. No es conserva cap còpia després del termini.",
    eo: "Tiu ĉi forviŝo estas aŭtomata kaj definitiva. Neniu kopio estas konservita post la limdato.",
    nl: "Deze verwijdering is automatisch en definitief. Er wordt geen kopie bewaard na de termijn.",
    el: "Αυτή η διαγραφή είναι αυτόματη και οριστική. Κανένα αντίγραφο δεν διατηρείται μετά την προθεσμία."
  },
  "rgpd.purge.howToCancel": {
    "pt-BR": "Se quiseres exportar teus dados antes da exclusão, entra em contato com a biblioteca pelos canais habituais.",
    fr: "Si tu souhaites exporter tes données avant la suppression, contacte la bibliothèque par les canaux habituels.",
    es: "Si deseas exportar tus datos antes de la eliminación, contacta con la biblioteca por los canales habituales.",
    en: "If you wish to export your data before deletion, contact the library through the usual channels.",
    it: "Se desideri esportare i tuoi dati prima della cancellazione, contatta la biblioteca tramite i canali abituali.",
    de: "Wenn du deine Daten vor der Löschung exportieren möchtest, kontaktiere die Bibliothek über die üblichen Kanäle.",
    ca: "Si vols exportar les teves dades abans de la supressió, contacta amb la biblioteca pels canals habituals.",
    eo: "Se vi volas eksporti viajn datumojn antaŭ la forviŝo, kontaktu la bibliotekon per la kutimaj kanaloj.",
    nl: "Als je je gegevens vóór verwijdering wilt exporteren, neem dan contact op met de bibliotheek via de gebruikelijke kanalen.",
    el: "Αν θέλεις να εξαγάγεις τα δεδομένα σου πριν τη διαγραφή, επικοινώνησε με τη βιβλιοθήκη μέσω των συνηθισμένων καναλιών."
  },

  // ========================================================================
  // OAI « être source » — gouvernance d'ouverture du endpoint (paquet OAI-O4)
  // Params : {lib} {entity} {date} {target}. Adresse fédérale = expéditeur.
  // ========================================================================
  "oai.requested.sub": {
    "pt-BR": "Pedido de abertura OAI — {lib}", fr: "Demande d'ouverture OAI — {lib}",
    es: "Solicitud de apertura OAI — {lib}", en: "OAI opening request — {lib}",
    it: "Richiesta di apertura OAI — {lib}", de: "OAI-Öffnungsanfrage — {lib}",
    ca: "Sol·licitud d'obertura OAI — {lib}", eo: "Peto de malfermo OAI — {lib}",
    nl: "OAI-openstellingsverzoek — {lib}", el: "Αίτημα ανοίγματος OAI — {lib}"
  },
  "oai.requested.intro": {
    "pt-BR": "A biblioteca {lib} pede a abertura do seu catálogo à colheita OAI-PMH. Basta o acordo de um(a/e) admin da rede para validar.",
    fr: "La bibliothèque {lib} demande l'ouverture de son catalogue au moissonnage OAI-PMH. Un seul accord d'admin réseau suffit pour valider.",
    es: "La biblioteca {lib} pide abrir su catálogo a la recolección OAI-PMH. Basta el acuerdo de una admin de la red para validar.",
    en: "The library {lib} requests opening its catalog to OAI-PMH harvesting. A single network admin's approval is enough.",
    it: "La biblioteca {lib} chiede di aprire il proprio catalogo alla raccolta OAI-PMH. Basta l'accordo di una admin della rete.",
    de: "Die Bibliothek {lib} möchte ihren Katalog für die OAI-PMH-Ernte öffnen. Die Zustimmung einer Netz-Admin genügt.",
    ca: "La biblioteca {lib} demana obrir el seu catàleg a la collita OAI-PMH. Amb l'acord d'una admin de la xarxa n'hi ha prou.",
    eo: "La biblioteko {lib} petas malfermi sian katalogon al rikolto OAI-PMH. Sufiĉas la konsento de unu reta administranto.",
    nl: "De bibliotheek {lib} vraagt om haar catalogus open te stellen voor OAI-PMH-oogst. De goedkeuring van één netwerkbeheerder volstaat.",
    el: "Η βιβλιοθήκη {lib} ζητά να ανοίξει τον κατάλογό της σε συγκομιδή OAI-PMH. Αρκεί η έγκριση μίας διαχειρίστριας του δικτύου."
  },
  "oai.approved.sub": {
    "pt-BR": "Abertura OAI aprovada — {lib}", fr: "Ouverture OAI approuvée — {lib}",
    es: "Apertura OAI aprobada — {lib}", en: "OAI opening approved — {lib}",
    it: "Apertura OAI approvata — {lib}", de: "OAI-Öffnung genehmigt — {lib}",
    ca: "Obertura OAI aprovada — {lib}", eo: "Malfermo OAI aprobita — {lib}",
    nl: "OAI-openstelling goedgekeurd — {lib}", el: "Το άνοιγμα OAI εγκρίθηκε — {lib}"
  },
  "oai.approved.intro": {
    "pt-BR": "Seu pedido de abertura OAI para {lib} foi aprovado. Lembre-se de fechar assim que a colheita for confirmada como concluída.",
    fr: "Ta demande d'ouverture OAI pour {lib} a été approuvée. Pense à refermer dès que le moissonnage est confirmé terminé.",
    es: "Tu solicitud de apertura OAI para {lib} ha sido aprobada. Recuerda cerrarla en cuanto la recolección se confirme terminada.",
    en: "Your OAI opening request for {lib} has been approved. Remember to close it once harvesting is confirmed complete.",
    it: "La tua richiesta di apertura OAI per {lib} è stata approvata. Ricordati di chiudere appena la raccolta è confermata conclusa.",
    de: "Deine OAI-Öffnungsanfrage für {lib} wurde genehmigt. Denk daran zu schließen, sobald die Ernte als abgeschlossen bestätigt ist.",
    ca: "La teva sol·licitud d'obertura OAI per a {lib} ha estat aprovada. Recorda tancar-la tan bon punt la collita es confirmi acabada.",
    eo: "Via peto de malfermo OAI por {lib} estis aprobita. Memoru fermi tuj kiam la rikolto estas konfirmita finita.",
    nl: "Je OAI-openstellingsverzoek voor {lib} is goedgekeurd. Denk eraan te sluiten zodra de oogst als voltooid is bevestigd.",
    el: "Το αίτημα ανοίγματος OAI για {lib} εγκρίθηκε. Θυμήσου να το κλείσεις μόλις επιβεβαιωθεί ότι η συγκομιδή ολοκληρώθηκε."
  },
  "oai.refused.sub": {
    "pt-BR": "Abertura OAI recusada — {lib}", fr: "Ouverture OAI refusée — {lib}",
    es: "Apertura OAI rechazada — {lib}", en: "OAI opening refused — {lib}",
    it: "Apertura OAI rifiutata — {lib}", de: "OAI-Öffnung abgelehnt — {lib}",
    ca: "Obertura OAI rebutjada — {lib}", eo: "Malfermo OAI rifuzita — {lib}",
    nl: "OAI-openstelling geweigerd — {lib}", el: "Το άνοιγμα OAI απορρίφθηκε — {lib}"
  },
  "oai.refused.intro": {
    "pt-BR": "Seu pedido de abertura OAI para {lib} foi recusado por um(a/e) admin da rede.",
    fr: "Ta demande d'ouverture OAI pour {lib} a été refusée par une admin réseau.",
    es: "Tu solicitud de apertura OAI para {lib} ha sido rechazada por una admin de la red.",
    en: "Your OAI opening request for {lib} was refused by a network admin.",
    it: "La tua richiesta di apertura OAI per {lib} è stata rifiutata da una admin della rete.",
    de: "Deine OAI-Öffnungsanfrage für {lib} wurde von einer Netz-Admin abgelehnt.",
    ca: "La teva sol·licitud d'obertura OAI per a {lib} ha estat rebutjada per una admin de la xarxa.",
    eo: "Via peto de malfermo OAI por {lib} estis rifuzita de reta administranto.",
    nl: "Je OAI-openstellingsverzoek voor {lib} is geweigerd door een netwerkbeheerder.",
    el: "Το αίτημα ανοίγματος OAI για {lib} απορρίφθηκε από διαχειρίστρια του δικτύου."
  },
  "oai.proposed.sub": {
    "pt-BR": "Consulta da rede — colheita por {entity}", fr: "Consultation réseau — moissonnage par {entity}",
    es: "Consulta de la red — recolección por {entity}", en: "Network consultation — harvesting by {entity}",
    it: "Consultazione della rete — raccolta da {entity}", de: "Netz-Abstimmung — Ernte durch {entity}",
    ca: "Consulta de la xarxa — collita per {entity}", eo: "Reta konsulto — rikolto de {entity}",
    nl: "Netwerkraadpleging — oogst door {entity}", el: "Διαβούλευση δικτύου — συγκομιδή από {entity}"
  },
  "oai.proposed.intro": {
    "pt-BR": "{entity} pede para colher o catálogo da rede. Sua biblioteca está envolvida: vote até {date}. Sem resposta, seu acordo é presumido; um único recuso bloqueia.",
    fr: "{entity} demande à moissonner le catalogue du réseau. Ta bibliothèque est concernée : vote avant le {date}. Sans réponse, ton accord est présumé ; un seul refus bloque.",
    es: "{entity} solicita recolectar el catálogo de la red. Tu biblioteca está implicada: vota antes del {date}. Sin respuesta, se presume tu acuerdo; un solo rechazo bloquea.",
    en: "{entity} requests to harvest the network catalog. Your library is concerned: vote by {date}. No reply means consent; a single refusal blocks it.",
    it: "{entity} chiede di raccogliere il catalogo della rete. La tua biblioteca è coinvolta: vota entro il {date}. Senza risposta l'accordo è presunto; un solo rifiuto blocca.",
    de: "{entity} möchte den Netzkatalog ernten. Deine Bibliothek ist betroffen: stimme bis {date} ab. Ohne Antwort gilt Zustimmung; eine einzige Ablehnung blockiert.",
    ca: "{entity} demana collir el catàleg de la xarxa. La teva biblioteca hi està implicada: vota abans del {date}. Sense resposta, es presumeix el teu acord; un sol rebuig ho bloqueja.",
    eo: "{entity} petas rikolti la retan katalogon. Via biblioteko estas koncernata: voĉdonu antaŭ {date}. Sen respondo, via konsento estas supozata; unu sola rifuzo blokas.",
    nl: "{entity} vraagt om de netwerkcatalogus te oogsten. Jouw bibliotheek is betrokken: stem vóór {date}. Geen antwoord betekent instemming; één weigering blokkeert.",
    el: "Η/Ο {entity} ζητά να συγκομίσει τον κατάλογο του δικτύου. Η βιβλιοθήκη σου εμπλέκεται: ψήφισε έως {date}. Χωρίς απάντηση τεκμαίρεται συναίνεση· μία άρνηση μπλοκάρει."
  },
  "oai.resolvedOpen.sub": {
    "pt-BR": "Consulta OAI concluída — {entity}", fr: "Consultation OAI aboutie — {entity}",
    es: "Consulta OAI concluida — {entity}", en: "OAI consultation passed — {entity}",
    it: "Consultazione OAI conclusa — {entity}", de: "OAI-Abstimmung angenommen — {entity}",
    ca: "Consulta OAI conclosa — {entity}", eo: "Konsulto OAI sukcesa — {entity}",
    nl: "OAI-raadpleging geslaagd — {entity}", el: "Η διαβούλευση OAI ολοκληρώθηκε — {entity}"
  },
  "oai.resolvedOpen.intro": {
    "pt-BR": "A consulta para {entity} é unânime: a rede está aberta à colheita.",
    fr: "La consultation pour {entity} est unanime : le réseau est ouvert au moissonnage.",
    es: "La consulta para {entity} es unánime: la red está abierta a la recolección.",
    en: "The consultation for {entity} is unanimous: the network is open to harvesting.",
    it: "La consultazione per {entity} è unanime: la rete è aperta alla raccolta.",
    de: "Die Abstimmung für {entity} ist einstimmig: das Netz ist zur Ernte geöffnet.",
    ca: "La consulta per a {entity} és unànime: la xarxa està oberta a la collita.",
    eo: "La konsulto por {entity} estas unuanima: la reto estas malfermita al rikoltado.",
    nl: "De raadpleging voor {entity} is unaniem: het netwerk staat open voor oogst.",
    el: "Η διαβούλευση για {entity} είναι ομόφωνη: το δίκτυο είναι ανοιχτό σε συγκομιδή."
  },
  "oai.resolvedRefused.sub": {
    "pt-BR": "Consulta OAI encerrada — {entity}", fr: "Consultation OAI close — {entity}",
    es: "Consulta OAI cerrada — {entity}", en: "OAI consultation closed — {entity}",
    it: "Consultazione OAI chiusa — {entity}", de: "OAI-Abstimmung abgelehnt — {entity}",
    ca: "Consulta OAI tancada — {entity}", eo: "Konsulto OAI fermita — {entity}",
    nl: "OAI-raadpleging gesloten — {entity}", el: "Η διαβούλευση OAI έκλεισε — {entity}"
  },
  "oai.resolvedRefused.intro": {
    "pt-BR": "A consulta para {entity} foi bloqueada por um recuso: a rede não está aberta.",
    fr: "La consultation pour {entity} est bloquée par un refus : le réseau n'est pas ouvert.",
    es: "La consulta para {entity} ha sido bloqueada por un rechazo: la red no está abierta.",
    en: "The consultation for {entity} was blocked by a refusal: the network is not opened.",
    it: "La consultazione per {entity} è stata bloccata da un rifiuto: la rete non è aperta.",
    de: "Die Abstimmung für {entity} wurde durch eine Ablehnung blockiert: das Netz ist nicht geöffnet.",
    ca: "La consulta per a {entity} ha estat bloquejada per un rebuig: la xarxa no està oberta.",
    eo: "La konsulto por {entity} estis blokita de rifuzo: la reto ne estas malfermita.",
    nl: "De raadpleging voor {entity} is geblokkeerd door een weigering: het netwerk is niet opengesteld.",
    el: "Η διαβούλευση για {entity} μπλοκαρίστηκε από μία άρνηση: το δίκτυο δεν ανοίγει."
  },
  "oai.closed.sub": {
    "pt-BR": "Abertura OAI fechada — {target}", fr: "Ouverture OAI refermée — {target}",
    es: "Apertura OAI cerrada — {target}", en: "OAI opening closed — {target}",
    it: "Apertura OAI chiusa — {target}", de: "OAI-Öffnung geschlossen — {target}",
    ca: "Obertura OAI tancada — {target}", eo: "Malfermo OAI fermita — {target}",
    nl: "OAI-openstelling gesloten — {target}", el: "Το άνοιγμα OAI έκλεισε — {target}"
  },
  "oai.closed.intro": {
    "pt-BR": "Uma abertura OAI referente a {target} foi fechada.",
    fr: "Une ouverture OAI concernant {target} a été refermée.",
    es: "Una apertura OAI relativa a {target} ha sido cerrada.",
    en: "An OAI opening concerning {target} has been closed.",
    it: "Un'apertura OAI relativa a {target} è stata chiusa.",
    de: "Eine OAI-Öffnung betreffend {target} wurde geschlossen.",
    ca: "Una obertura OAI relativa a {target} s'ha tancat.",
    eo: "Malfermo OAI koncernanta {target} estis fermita.",
    nl: "Een OAI-openstelling met betrekking tot {target} is gesloten.",
    el: "Ένα άνοιγμα OAI σχετικά με {target} έκλεισε."
  },
  "oai.networkWord": {
    "pt-BR": "a rede", fr: "le réseau", es: "la red", en: "the network", it: "la rete",
    de: "das Netz", ca: "la xarxa", eo: "la reto", nl: "het netwerk", el: "το δίκτυο"
  },
  "oai.cta": {
    "pt-BR": "Abrir na Rede", fr: "Ouvrir dans Réseau", es: "Abrir en Red", en: "Open in Network",
    it: "Apri in Rete", de: "Im Netz öffnen", ca: "Obrir a Xarxa", eo: "Malfermi en Reto",
    nl: "Openen in Netwerk", el: "Άνοιγμα στο Δίκτυο"
  },

  // ========================================================================
  // ILL — partage numérique inter-biblios (paquet ILL-I4)
  // Params : {requester} {source} {book} {reason}.
  // ========================================================================
  "ill.requested.sub": {
    "pt-BR": "Pedido de partilha digital — {book}", fr: "Demande de partage numérique — {book}",
    es: "Solicitud de compartición digital — {book}", en: "Digital sharing request — {book}",
    it: "Richiesta di condivisione digitale — {book}", de: "Anfrage zur digitalen Teilung — {book}",
    ca: "Sol·licitud de compartició digital — {book}", eo: "Peto de cifereca kunhavigo — {book}",
    nl: "Verzoek om digitaal delen — {book}", el: "Αίτημα ψηφιακής κοινοποίησης — {book}"
  },
  "ill.requested.intro": {
    "pt-BR": "{requester} solicita a partilha digital do documento « {book} ». A ti aceitar, recusar ou sinalizar a indisponibilidade.",
    fr: "{requester} sollicite le partage numérique du document « {book} ». À toi d'accepter, refuser ou signaler l'indisponibilité.",
    es: "{requester} solicita la compartición digital del documento « {book} ». Te toca aceptar, rechazar o señalar la indisponibilidad.",
    en: "{requester} requests the digital sharing of « {book} ». It's up to you to accept, refuse or mark it unavailable.",
    it: "{requester} chiede la condivisione digitale del documento « {book} ». Tocca a te accettare, rifiutare o segnalare l'indisponibilità.",
    de: "{requester} bittet um die digitale Teilung von « {book} ». Du kannst annehmen, ablehnen oder als nicht verfügbar melden.",
    ca: "{requester} sol·licita la compartició digital del document « {book} ». Et toca acceptar, rebutjar o assenyalar la indisponibilitat.",
    eo: "{requester} petas la ciferecan kunhavigon de la dokumento « {book} ». Vi povas akcepti, rifuzi aŭ signali nedisponeblon.",
    nl: "{requester} vraagt om het digitaal delen van « {book} ». Aan jou om te accepteren, te weigeren of als onbeschikbaar te melden.",
    el: "Η/Ο {requester} ζητά την ψηφιακή κοινοποίηση του τεκμηρίου « {book} ». Σε εσένα να αποδεχθείς, να αρνηθείς ή να δηλώσεις μη διαθεσιμότητα."
  },
  "ill.accepted.sub": {
    "pt-BR": "Partilha aceita — {book}", fr: "Partage accepté — {book}", es: "Compartición aceptada — {book}",
    en: "Sharing accepted — {book}", it: "Condivisione accettata — {book}", de: "Teilung angenommen — {book}",
    ca: "Compartició acceptada — {book}", eo: "Kunhavigo akceptita — {book}",
    nl: "Delen geaccepteerd — {book}", el: "Η κοινοποίηση έγινε δεκτή — {book}"
  },
  "ill.accepted.intro": {
    "pt-BR": "{source} aceitou seu pedido de partilha para « {book} ». A digitalização segue.",
    fr: "{source} a accepté ta demande de partage pour « {book} ». La numérisation suit.",
    es: "{source} aceptó tu solicitud de compartición para « {book} ». La digitalización sigue.",
    en: "{source} accepted your sharing request for « {book} ». Digitization follows.",
    it: "{source} ha accettato la tua richiesta di condivisione per « {book} ». La digitalizzazione segue.",
    de: "{source} hat deine Teilungsanfrage für « {book} » angenommen. Die Digitalisierung folgt.",
    ca: "{source} ha acceptat la teva sol·licitud de compartició per a « {book} ». La digitalització segueix.",
    eo: "{source} akceptis vian peton de kunhavigo por « {book} ». La ciferecigo sekvas.",
    nl: "{source} heeft je deelverzoek voor « {book} » geaccepteerd. Digitalisering volgt.",
    el: "Η/Ο {source} αποδέχθηκε το αίτημά σου για « {book} ». Ακολουθεί η ψηφιοποίηση."
  },
  "ill.refused.sub": {
    "pt-BR": "Partilha recusada — {book}", fr: "Partage refusé — {book}", es: "Compartición rechazada — {book}",
    en: "Sharing refused — {book}", it: "Condivisione rifiutata — {book}", de: "Teilung abgelehnt — {book}",
    ca: "Compartició rebutjada — {book}", eo: "Kunhavigo rifuzita — {book}",
    nl: "Delen geweigerd — {book}", el: "Η κοινοποίηση απορρίφθηκε — {book}"
  },
  "ill.refused.intro": {
    "pt-BR": "{source} recusou seu pedido de partilha para « {book} ». Motivo: {reason}",
    fr: "{source} a refusé ta demande de partage pour « {book} ». Motif : {reason}",
    es: "{source} rechazó tu solicitud de compartición para « {book} ». Motivo: {reason}",
    en: "{source} refused your sharing request for « {book} ». Reason: {reason}",
    it: "{source} ha rifiutato la tua richiesta di condivisione per « {book} ». Motivo: {reason}",
    de: "{source} hat deine Teilungsanfrage für « {book} » abgelehnt. Grund: {reason}",
    ca: "{source} ha rebutjat la teva sol·licitud de compartició per a « {book} ». Motiu: {reason}",
    eo: "{source} rifuzis vian peton de kunhavigo por « {book} ». Kialo: {reason}",
    nl: "{source} heeft je deelverzoek voor « {book} » geweigerd. Reden: {reason}",
    el: "Η/Ο {source} αρνήθηκε το αίτημά σου για « {book} ». Αιτία: {reason}"
  },
  "ill.unavailable.sub": {
    "pt-BR": "Documento indisponível — {book}", fr: "Document indisponible — {book}",
    es: "Documento no disponible — {book}", en: "Document unavailable — {book}",
    it: "Documento non disponibile — {book}", de: "Dokument nicht verfügbar — {book}",
    ca: "Document no disponible — {book}", eo: "Dokumento nedisponebla — {book}",
    nl: "Document niet beschikbaar — {book}", el: "Μη διαθέσιμο τεκμήριο — {book}"
  },
  "ill.unavailable.intro": {
    "pt-BR": "{source} sinaliza que « {book} » está indisponível para partilha no momento.",
    fr: "{source} signale que « {book} » est indisponible au partage pour le moment.",
    es: "{source} señala que « {book} » no está disponible para compartir por ahora.",
    en: "{source} reports that « {book} » is unavailable for sharing at the moment.",
    it: "{source} segnala che « {book} » è al momento non disponibile per la condivisione.",
    de: "{source} meldet, dass « {book} » derzeit nicht zur Teilung verfügbar ist.",
    ca: "{source} assenyala que « {book} » no està disponible per compartir de moment.",
    eo: "{source} signalas, ke « {book} » estas nuntempe nedisponebla por kunhavigo.",
    nl: "{source} meldt dat « {book} » momenteel niet beschikbaar is om te delen.",
    el: "Η/Ο {source} αναφέρει ότι το « {book} » δεν είναι διαθέσιμο για κοινοποίηση αυτή τη στιγμή."
  },
  "ill.transmitted.sub": {
    "pt-BR": "Documento transmitido — {book}", fr: "Document transmis — {book}",
    es: "Documento transmitido — {book}", en: "Document transmitted — {book}",
    it: "Documento trasmesso — {book}", de: "Dokument übermittelt — {book}",
    ca: "Document transmès — {book}", eo: "Dokumento transdonita — {book}",
    nl: "Document verzonden — {book}", el: "Το τεκμήριο διαβιβάστηκε — {book}"
  },
  "ill.transmitted.intro": {
    "pt-BR": "{source} transmitiu « {book} ». Você pode consultá-lo no espaço de partilha.",
    fr: "{source} a transmis « {book} ». Tu peux le consulter dans l'espace de partage.",
    es: "{source} transmitió « {book} ». Puedes consultarlo en el espacio de compartición.",
    en: "{source} transmitted « {book} ». You can view it in the sharing space.",
    it: "{source} ha trasmesso « {book} ». Puoi consultarlo nello spazio di condivisione.",
    de: "{source} hat « {book} » übermittelt. Du kannst es im Teilungsbereich ansehen.",
    ca: "{source} ha transmès « {book} ». El pots consultar a l'espai de compartició.",
    eo: "{source} transdonis « {book} ». Vi povas konsulti ĝin en la kunhaviga spaco.",
    nl: "{source} heeft « {book} » verzonden. Je kunt het bekijken in de deelruimte.",
    el: "Η/Ο {source} διαβίβασε το « {book} ». Μπορείς να το δεις στον χώρο κοινοποίησης."
  },
  "ill.closed.sub": {
    "pt-BR": "Partilha encerrada — {book}", fr: "Partage clôturé — {book}", es: "Compartición cerrada — {book}",
    en: "Sharing closed — {book}", it: "Condivisione chiusa — {book}", de: "Teilung abgeschlossen — {book}",
    ca: "Compartició tancada — {book}", eo: "Kunhavigo fermita — {book}",
    nl: "Delen afgesloten — {book}", el: "Η κοινοποίηση έκλεισε — {book}"
  },
  "ill.closed.intro": {
    "pt-BR": "A partilha digital de « {book} » foi encerrada.",
    fr: "Le partage numérique de « {book} » est clôturé.",
    es: "La compartición digital de « {book} » ha sido cerrada.",
    en: "The digital sharing of « {book} » has been closed.",
    it: "La condivisione digitale di « {book} » è stata chiusa.",
    de: "Die digitale Teilung von « {book} » wurde abgeschlossen.",
    ca: "La compartició digital de « {book} » s'ha tancat.",
    eo: "La cifereca kunhavigo de « {book} » estis fermita.",
    nl: "Het digitaal delen van « {book} » is afgesloten.",
    el: "Η ψηφιακή κοινοποίηση του « {book} » έκλεισε."
  },
  "ill.cta": {
    "pt-BR": "Abrir a partilha", fr: "Ouvrir le partage", es: "Abrir la compartición", en: "Open the share",
    it: "Apri la condivisione", de: "Teilung öffnen", ca: "Obrir la compartició", eo: "Malfermi la kunhavigon",
    nl: "Delen openen", el: "Άνοιγμα κοινοποίησης"
  },

  // ── Notes système consulta/réserve (Route B) ──────────────────────────────
  // Décodage des sentinelles @@note:<clé> dans le corps des mails
  // (cf. _shared/i18n/systemNotes.ts → decodeSystemNote). Les 5 clés réutilisées
  // reprennent mot pour mot les libellés des locales React ; les 4 systemNote.*
  // sont nouvelles. Toute clé décodable atteignant un mail doit figurer ici.
  "account.reserve.noteConsult": {
    "pt-BR": "Pedido de consulta local criado pela conta do(a-e) leitor(a-e).",
    fr: "Demande de consultation créée depuis le compte lecteur·rice.",
    es: "Solicitud de consulta local creada desde la cuenta de le lectore.",
    en: "Local consultation request created from reader account.",
    it: "Richiesta di consultazione creata dall'account lettore/trice.",
    de: "Einsichtnahme-Anfrage aus dem Leserkonto erstellt.",
    ca: "Sol·licitud de consulta creada des del compte de lector-a-e.",
    eo: "Konsultpeto kreita el la konto de legant-in-o.",
    nl: "Aanvraag voor raadpleging ter plaatse aangemaakt vanuit het lezersaccount.",
    el: "Αίτημα επιτόπιας μελέτης που δημιουργήθηκε από λογαριασμό αναγνώστη/στριας."
  },
  "account.reserve.noteLoan": {
    "pt-BR": "Reserva criada pela conta do(a-e) leitor(a-e).",
    fr: "Réservation créée depuis le compte lecteur·rice.",
    es: "Reserva creada desde la cuenta de le lectore.",
    en: "Reservation created from reader account.",
    it: "Prenotazione creata dall'account lettore/trice.",
    de: "Vormerkung aus dem Leserkonto erstellt.",
    ca: "Reserva creada des del compte de lector-a-e.",
    eo: "Rezervo kreita el la konto de legant-in-o.",
    nl: "Reservering aangemaakt vanuit het lezersaccount.",
    el: "Κράτηση που δημιουργήθηκε από λογαριασμό αναγνώστη/στριας."
  },
  "catalog.quickReserve.note": {
    "pt-BR": "Reserva criada a partir do catálogo.",
    fr: "Réservation créée depuis le catalogue.",
    es: "Reserva creada desde el catálogo.",
    en: "Reservation created from the catalog.",
    it: "Prenotazione creata dal catalogo.",
    de: "Reservierung aus dem Katalog erstellt.",
    ca: "Reserva creada des del catàleg.",
    eo: "Rezervo kreita el la katalogo.",
    nl: "Reservering aangemaakt vanuit de catalogus.",
    el: "Η κράτηση δημιουργήθηκε από τον κατάλογο."
  },
  "catalog.quickConsulta.note": {
    "pt-BR": "Pedido feito desde a busca",
    fr: "Demande faite depuis la recherche",
    es: "Pedido hecho desde la búsqueda",
    en: "Requested from search",
    it: "Richiesto dalla ricerca",
    de: "Aus der Suche angefragt",
    ca: "Sol·licitud feta des de la cerca",
    eo: "Peto farita el la serĉo",
    nl: "Aangevraagd vanuit de zoekopdracht",
    el: "Ζητήθηκε από την αναζήτηση"
  },
  "book.reserve.consult.note": {
    "pt-BR": "Pedido feito desde a página do documento",
    fr: "Demande faite depuis la fiche du document",
    es: "Pedido hecho desde la página del documento",
    en: "Requested from the document page",
    it: "Richiesto dalla pagina del documento",
    de: "Über die Dokumentseite angefragt",
    ca: "Sol·licitud feta des de la fitxa del document",
    eo: "Peto farita el la slipo de la dokumento",
    nl: "Aangevraagd vanaf de documentpagina",
    el: "Ζητήθηκε από τη σελίδα του τεκμηρίου"
  },
  "systemNote.consultaReceived": {
    "pt-BR": "Pedido de consulta local recebido.",
    fr: "Demande de consultation locale reçue.",
    es: "Solicitud de consulta local recibida.",
    en: "Local consultation request received.",
    it: "Richiesta di consultazione ricevuta.",
    de: "Einsichtnahme-Anfrage eingegangen.",
    ca: "Sol·licitud de consulta rebuda.",
    eo: "Konsultpeto ricevita.",
    nl: "Aanvraag voor raadpleging ter plaatse ontvangen.",
    el: "Το αίτημα επιτόπιας μελέτης ελήφθη."
  },
  "systemNote.reservaReceived": {
    "pt-BR": "Reserva recebida.",
    fr: "Réservation reçue.",
    es: "Reserva recibida.",
    en: "Reservation received.",
    it: "Prenotazione ricevuta.",
    de: "Vormerkung eingegangen.",
    ca: "Reserva rebuda.",
    eo: "Rezervo ricevita.",
    nl: "Reservering ontvangen.",
    el: "Η κράτηση ελήφθη."
  },
  "systemNote.cancelRequestedByReader": {
    "pt-BR": "Cancelamento solicitado pela conta do(a-e) leitor(a-e).",
    fr: "Annulation demandée depuis le compte lecteur·rice.",
    es: "Cancelación solicitada desde la cuenta de le lectore.",
    en: "Cancellation requested from reader account.",
    it: "Annullamento richiesto dall'account lettore/trice.",
    de: "Stornierung aus dem Leserkonto angefordert.",
    ca: "Cancel·lació sol·licitada des del compte de lector-a-e.",
    eo: "Nuligo petita el la konto de legant-in-o.",
    nl: "Annulering aangevraagd vanuit het lezersaccount.",
    el: "Ακύρωση που ζητήθηκε από λογαριασμό αναγνώστη/στριας."
  },
  "systemNote.cancelledByLibrary": {
    "pt-BR": "Cancelamento efetuado pela biblioteca.",
    fr: "Annulation effectuée par la bibliothèque.",
    es: "Cancelación realizada por la biblioteca.",
    en: "Cancellation made by the library.",
    it: "Annullamento effettuato dalla biblioteca.",
    de: "Stornierung durch die Bibliothek.",
    ca: "Cancel·lació efectuada per la biblioteca.",
    eo: "Nuligo farita de la biblioteko.",
    nl: "Annulering uitgevoerd door de bibliotheek.",
    el: "Ακύρωση που πραγματοποιήθηκε από τη βιβλιοθήκη."
  },
};

const D: SupportedMailLocale = "pt-BR";

// ============================================================================
// API publique du module
// ============================================================================

/**
 * Récupère la traduction d'une clé pour une locale donnée.
 * Si la clé n'existe pas, retourne la clé brute (pour faciliter le debug).
 * Si la locale n'est pas supportée ou est null, fallback vers pt-BR (D).
 *
 * @param locale Code locale (ex: 'pt-BR', 'fr', 'es', etc.) ou null
 * @param key Clé du dictionnaire (ex: 'wf.ready', 'l.items')
 * @param params Paramètres à interpoler (ex: {date: '05/05/2026'})
 */
export function tMail(
  locale: string | null | undefined,
  key: string,
  params?: Record<string, string | number>
): string {
  const e = (locale && V.has(locale) ? locale : D) as SupportedMailLocale;
  const d = S[key];
  if (!d) return key;
  let t = d[e] || d[D] || key;
  if (params) {
    for (const [k, v] of Object.entries(params)) {
      t = t.replace(new RegExp(`\\{${k}\\}`, "g"), String(v));
    }
  }
  return t;
}

/** Salutation localisée, avec ou sans nom. */
export function greeting(locale: string | null | undefined, name?: string | null): string {
  return name ? tMail(locale, "greeting.named", { name }) : tMail(locale, "greeting.anonymous");
}

/** Label localisé pour les détails de mail (passe par le préfixe `l.`). */
export function label(locale: string | null | undefined, key: string): string {
  return tMail(locale, `l.${key}`);
}

/** Statut de tâche localisé (préfixe `ts.`). */
export function taskStatusLabel(locale: string | null | undefined, status: string): string {
  return tMail(locale, `ts.${status}`);
}

/** Priorité de tâche localisée (préfixe `tp.`). */
export function taskPriorityLabel(locale: string | null | undefined, priority: string): string {
  return tMail(locale, `tp.${priority}`);
}

/** Formate une date selon la locale (DD/MM/YYYY en pt-BR par défaut). */
export function formatDateLocale(d: string | Date | null | undefined, locale?: string | null): string {
  if (!d) return "";
  const v = d instanceof Date ? d : new Date(d);
  if (isNaN(v.getTime())) return String(d);
  const loc = locale && V.has(locale) ? locale : "pt-BR";
  try {
    return v.toLocaleDateString(loc, {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      timeZone: "UTC"
    });
  } catch {
    return `${String(v.getUTCDate()).padStart(2, "0")}/${String(v.getUTCMonth() + 1).padStart(2, "0")}/${v.getUTCFullYear()}`;
  }
}

// ============================================================================
// Helpers exportés pour les tests anti-régression
// ============================================================================

/** Liste toutes les clés définies (utile pour les tests). */
export function _allKeys(): string[] {
  return Object.keys(S);
}

/** Retourne l'ensemble des locales supportées (utile pour les tests). */
export function _supportedLocales(): SupportedMailLocale[] {
  return ["pt-BR", "fr", "es", "en", "it", "de", "ca", "eo", "nl", "el"];
}

/** Vérifie qu'une clé donnée a une traduction non vide pour toutes les locales. */
export function _isComplete(key: string): boolean {
  const d = S[key];
  if (!d) return false;
  for (const loc of _supportedLocales()) {
    if (!d[loc] || !String(d[loc]).trim()) return false;
  }
  return true;
}

