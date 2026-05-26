// ============================================================================
// mail-strings.ts — i18n des notifications mail (Edge Function notify-event)
// ============================================================================
// 6 locales : pt-BR (référence), fr, es, en, it, de
//
// Conventions militantes par locale :
//   pt-BR : triple forme o/a/e, démonstratifs binôme dest(e/a),
//           contractions article-préposition triples d(o/a/e)
//   fr    : point médian (lecteur·rice, le·la)
//   es    : neutre argentin e (le, les, une, conectade), participes accordés
//   en    : neutre standard (épicène)
//   it    : compagno/a/e ou variantes, JAMAIS camerata
//   de    : Genderstern (Leser*in, Genoss*in), JAMAIS "Compas"
//
// Date du fix : 2026-05-02 (chasse au bug wf.ready / wf.readyShort affichés
//               en clés brutes dans les mails — clés manquantes du dictionnaire)
// ============================================================================

export type SupportedMailLocale = "pt-BR" | "fr" | "es" | "en" | "it" | "de" | "ca" | "eo";

const V = new Set<string>(["pt-BR", "fr", "es", "en", "it", "de", "ca", "eo"]);

const S: Record<string, Record<SupportedMailLocale, string>> = {

  // ===== Greetings ==========================================================
  "greeting.named": {
    "pt-BR": "Olá, {name}!",
    fr: "Bonjour, {name} !",
    es: "¡Hola, {name}!",
    en: "Hello, {name}!",
    it: "Ciao, {name}!",
    de: "Hallo, {name}!",
    ca: "Hola, {name}!",
    eo: "Saluton, {name}!"
  },
  "greeting.anonymous": {
    "pt-BR": "Olá!",
    fr: "Bonjour !",
    es: "¡Hola!",
    en: "Hello!",
    it: "Ciao!",
    de: "Hallo!",
    ca: "Hola!",
    eo: "Saluton!"
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
    eo: "Aŭtomata sciigo"
  },
  "layout.footerContact": {
    "pt-BR": "Em caso de dúvida, entre em contato com a biblioteca.",
    fr: "En cas de question, contacte la bibliothèque.",
    es: "En caso de duda, contacta la biblioteca.",
    en: "If in doubt, contact the library.",
    it: "In caso di dubbi, contatta la biblioteca.",
    de: "Bei Fragen wende dich an die Bibliothek.",
    ca: "En cas de dubte, contacta la biblioteca.",
    eo: "En kazo de dubo, kontaktu la bibliotekon."
  },
  "layout.keepMsg": {
    "pt-BR": "Guarde esta mensagem.",
    fr: "Conserve ce message.",
    es: "Guarda este mensaje.",
    en: "Keep this message.",
    it: "Conserva questo messaggio.",
    de: "Bewahre diese Nachricht auf.",
    ca: "Conserva aquest missatge.",
    eo: "Konservu ĉi tiun mesaĝon."
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
    eo: "Telefono"
  },
  "layout.regimentoLabel": {
    "pt-BR": "Regimento",
    fr: "Règlement",
    es: "Reglamento",
    en: "Regulations",
    it: "Regolamento",
    de: "Reglement",
    ca: "Reglament",
    eo: "Regularo"
  },
  "layout.footerText": {
    "pt-BR": "Mensagem automática da biblioteca. Responda apenas se o campo de resposta indicar um contato local.",
    fr: "Message automatique de la bibliothèque. Réponds uniquement si le champ de réponse indique un contact local.",
    es: "Mensaje automático de la biblioteca. Respondé únicamente si el campo de respuesta indica un contacto local.",
    en: "Automatic message from the library. Reply only if the reply-to field indicates a local contact.",
    it: "Messaggio automatico della biblioteca. Rispondi solo se il campo di risposta indica un contatto locale.",
    de: "Automatische Nachricht der Bibliothek. Antworte nur, wenn das Antwortfeld einen lokalen Kontakt anzeigt.",
    ca: "Missatge automàtic de la biblioteca. Respon únicament si el camp de resposta indica un contacte local.",
    eo: "Aŭtomata mesaĝo de la biblioteko. Respondu nur se la respondkampo indikas lokan kontakton."
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
    eo: "Dokumento"
  },
  "l.items": {
    "pt-BR": "Itens",
    fr: "Documents",
    es: "Documentos",
    en: "Items",
    it: "Documenti",
    de: "Dokumente",
    ca: "Documents",
    eo: "Dokumentoj"
  },
  "l.itemsReturned": {
    "pt-BR": "Documentos devolvidos",
    fr: "Documents rendus",
    es: "Documentos devueltos",
    en: "Documents returned",
    it: "Documenti restituiti",
    de: "Zurückgegebene Dokumente",
    ca: "Documents retornats",
    eo: "Redonitaj dokumentoj"
  },
  "l.itemsRemaining": {
    "pt-BR": "Documentos ainda em mãos",
    fr: "Documents encore à rendre",
    es: "Documentos todavía pendientes",
    en: "Documents still to return",
    it: "Documenti ancora da restituire",
    de: "Noch zurückzugebende Dokumente",
    ca: "Documents encara per retornar",
    eo: "Dokumentoj ankoraŭ redonendaj"
  },
  "l.ref": {
    "pt-BR": "Referência",
    fr: "Référence",
    es: "Referencia",
    en: "Reference",
    it: "Riferimento",
    de: "Referenz",
    ca: "Referència",
    eo: "Referenco"
  },
  "l.refs": {
    "pt-BR": "Referências",
    fr: "Références",
    es: "Referencias",
    en: "References",
    it: "Riferimenti",
    de: "Referenzen",
    ca: "Referències",
    eo: "Referencoj"
  },
  "l.ids": {
    "pt-BR": "IDs",
    fr: "IDs",
    es: "IDs",
    en: "IDs",
    it: "IDs",
    de: "IDs",
    ca: "IDs",
    eo: "IDoj"
  },
  "l.date": {
    "pt-BR": "Data",
    fr: "Date",
    es: "Fecha",
    en: "Date",
    it: "Data",
    de: "Datum",
    ca: "Data",
    eo: "Dato"
  },
  "l.dueDate": {
    "pt-BR": "Devolução prevista",
    fr: "Retour prévu",
    es: "Devolución prevista",
    en: "Due date",
    it: "Restituzione prevista",
    de: "Fälligkeitsdatum",
    ca: "Retorn previst",
    eo: "Planita redono"
  },
  "l.newDueDate": {
    "pt-BR": "Nova devolução",
    fr: "Nouveau retour",
    es: "Nueva devolución",
    en: "New due date",
    it: "Nuova restituzione",
    de: "Neues Fälligkeitsdatum",
    ca: "Nou retorn",
    eo: "Nova redono"
  },
  "l.deadline": {
    "pt-BR": "Prazo",
    fr: "Échéance",
    es: "Plazo",
    en: "Deadline",
    it: "Scadenza",
    de: "Frist",
    ca: "Termini",
    eo: "Limdato"
  },
  "l.registration": {
    "pt-BR": "Registro",
    fr: "Enregistrement",
    es: "Registro",
    en: "Registration",
    it: "Registrazione",
    de: "Registrierung",
    ca: "Registre",
    eo: "Registro"
  },
  "l.renewal": {
    "pt-BR": "Renovação em",
    fr: "Renouvelé le",
    es: "Renovación el",
    en: "Renewed on",
    it: "Rinnovo il",
    de: "Verlängert am",
    ca: "Renovació el",
    eo: "Renovigo la"
  },
  "l.return": {
    "pt-BR": "Devolução",
    fr: "Retour",
    es: "Devolución",
    en: "Return",
    it: "Restituzione",
    de: "Rückgabe",
    ca: "Retorn",
    eo: "Redono"
  },
  "l.reader": {
    "pt-BR": "Leitor(a/e)",
    fr: "Lecteur·rice",
    es: "Lector(a/e)",
    en: "Reader",
    it: "Lettore/trice",
    de: "Leser*in",
    ca: "Lector-a-e",
    eo: "Legant-in-o"
  },
  "l.pickup": {
    "pt-BR": "Retirada",
    fr: "Retrait",
    es: "Retiro",
    en: "Pickup",
    it: "Ritiro",
    de: "Abholung",
    ca: "Recollida",
    eo: "Elpreno"
  },
  "l.status": {
    "pt-BR": "Situação",
    fr: "Situation",
    es: "Situación",
    en: "Status",
    it: "Situazione",
    de: "Status",
    ca: "Situació",
    eo: "Situacio"
  },
  "l.reason": {
    "pt-BR": "Motivo",
    fr: "Motif",
    es: "Motivo",
    en: "Reason",
    it: "Motivo",
    de: "Grund",
    ca: "Motiu",
    eo: "Motivo"
  },
  "l.note": {
    "pt-BR": "Observação",
    fr: "Observation",
    es: "Observación",
    en: "Note",
    it: "Osservazione",
    de: "Anmerkung",
    ca: "Observació",
    eo: "Observo"
  },
  "l.contact": {
    "pt-BR": "Contato",
    fr: "Contact",
    es: "Contacto",
    en: "Contact",
    it: "Contatto",
    de: "Kontakt",
    ca: "Contacte",
    eo: "Kontakto"
  },
  "l.task": {
    "pt-BR": "Tarefa",
    fr: "Tâche",
    es: "Tarea",
    en: "Task",
    it: "Compito",
    de: "Aufgabe",
    ca: "Tasca",
    eo: "Tasko"
  },
  "l.priority": {
    "pt-BR": "Prioridade",
    fr: "Priorité",
    es: "Prioridad",
    en: "Priority",
    it: "Priorità",
    de: "Priorität",
    ca: "Prioritat",
    eo: "Prioritato"
  },
  "l.tags": {
    "pt-BR": "Marcadores",
    fr: "Étiquettes",
    es: "Etiquetas",
    en: "Tags",
    it: "Etichette",
    de: "Schlagwörter",
    ca: "Etiquetes",
    eo: "Etikedoj"
  },
  "l.firstDate": {
    "pt-BR": "Próximo vencimento",
    fr: "Prochaine échéance",
    es: "Próximo vencimiento",
    en: "Next due date",
    it: "Prossima scadenza",
    de: "Nächste Fälligkeit",
    ca: "Proper venciment",
    eo: "Sekva limdato"
  },
  "l.pendingItems": {
    "pt-BR": "Itens pendentes",
    fr: "Documents en cours",
    es: "Documentos pendientes",
    en: "Pending items",
    it: "Documenti in corso",
    de: "Offene Dokumente",
    ca: "Documents en curs",
    eo: "Kurantaj dokumentoj"
  },
  "l.readerNote": {
    "pt-BR": "Observação d(o/a/e) leitor(a/e)",
    fr: "Note du·de la lecteur·rice",
    es: "Nota de le lector(a/e)",
    en: "Reader note",
    it: "Nota del/la lettore/trice",
    de: "Anmerkung der*des Leser*in",
    ca: "Nota de le lector-a-e",
    eo: "Noto de la legant-in-o"
  },
  "l.reply": {
    "pt-BR": "Resposta",
    fr: "Réponse",
    es: "Respuesta",
    en: "Reply",
    it: "Risposta",
    de: "Antwort",
    ca: "Resposta",
    eo: "Respondo"
  },
  "l.restrictedSince": {
    "pt-BR": "Restrição desde",
    fr: "Restriction depuis",
    es: "Restricción desde",
    en: "Restricted since",
    it: "Restrizione da",
    de: "Eingeschränkt seit",
    ca: "Restricció des de",
    eo: "Restrikto ekde"
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
    eo: "Rezervo registrita"
  },
  "res.created.pre": {
    "pt-BR": "Sua reserva foi registrada com sucesso.",
    fr: "Ta réservation a bien été enregistrée.",
    es: "Tu reserva fue registrada con éxito.",
    en: "Your reservation has been registered.",
    it: "La tua prenotazione è stata registrata.",
    de: "Deine Vormerkung wurde registriert.",
    ca: "La teva reserva s'ha registrat correctament.",
    eo: "Via rezervo estis sukcese registrita."
  },
  "res.created.intro": {
    "pt-BR": "Recebemos sua reserva. A biblioteca confirmará a disponibilidade em breve.",
    fr: "Nous avons reçu ta réservation. La bibliothèque confirmera bientôt la disponibilité.",
    es: "Recibimos tu reserva. La biblioteca confirmará pronto la disponibilidad.",
    en: "We received your reservation. The library will confirm availability soon.",
    it: "Abbiamo ricevuto la tua prenotazione. La biblioteca confermerà presto la disponibilità.",
    de: "Wir haben deine Vormerkung erhalten. Die Bibliothek bestätigt bald die Verfügbarkeit.",
    ca: "Hem rebut la teva reserva. La biblioteca confirmarà aviat la disponibilitat.",
    eo: "Ni ricevis vian rezervon. La biblioteko baldaŭ konfirmos la disponeblecon."
  },
  "res.created.hint": {
    "pt-BR": "Você pode acompanhar o estado d(o/a/e) seu pedido na sua conta.",
    fr: "Tu peux suivre l'état de ta demande dans ton compte.",
    es: "Puedes seguir le estade de tu pedido en tu cuenta.",
    en: "You can track your request status in your account.",
    it: "Puoi seguire lo stato della tua richiesta nel tuo account.",
    de: "Du kannst den Status deiner Anfrage in deinem Konto verfolgen.",
    ca: "Pots seguir l'estat de le teu sol·licitud al teu compte.",
    eo: "Vi povas sekvi la staton de via peto en via konto."
  },
  "res.created.admin": {
    "pt-BR": "Nova reserva registrada",
    fr: "Nouvelle réservation enregistrée",
    es: "Nueva reserva registrada",
    en: "New reservation registered",
    it: "Nuova prenotazione registrata",
    de: "Neue Vormerkung registriert",
    ca: "Nova reserva registrada",
    eo: "Nova rezervo registrita"
  },
  "res.refused": {
    "pt-BR": "Reserva recusada pela biblioteca",
    fr: "Réservation refusée par la bibliothèque",
    es: "Reserva rechazada por la biblioteca",
    en: "Reservation declined by the library",
    it: "Prenotazione rifiutata dalla biblioteca",
    de: "Vormerkung von der Bibliothek abgelehnt",
    ca: "Reserva rebutjada per la biblioteca",
    eo: "Rezervo rifuzita de la biblioteko"
  },
  "res.cancelStaff": {
    "pt-BR": "Reserva cancelada pela biblioteca",
    fr: "Réservation annulée par la bibliothèque",
    es: "Reserva cancelada por la biblioteca",
    en: "Reservation cancelled by the library",
    it: "Prenotazione annullata dalla biblioteca",
    de: "Vormerkung von der Bibliothek storniert",
    ca: "Reserva cancel·lada per la biblioteca",
    eo: "Rezervo nuligita de la biblioteko"
  },
  "res.cancelReader": {
    "pt-BR": "Reserva cancelada por você",
    fr: "Réservation annulée par toi",
    es: "Reserva cancelada por ti",
    en: "Reservation cancelled by you",
    it: "Prenotazione annullata da te",
    de: "Vormerkung von dir storniert",
    ca: "Reserva cancel·lada per tu",
    eo: "Rezervo nuligita de vi"
  },
  "res.expired": {
    "pt-BR": "Reserva expirada",
    fr: "Réservation expirée",
    es: "Reserva expirada",
    en: "Reservation expired",
    it: "Prenotazione scaduta",
    de: "Vormerkung abgelaufen",
    ca: "Reserva expirada",
    eo: "Rezervo eksvalidiĝinta"
  },
  "res.converted": {
    "pt-BR": "Reserva convertida em empréstimo",
    fr: "Réservation convertie en emprunt",
    es: "Reserva convertide en préstamo",
    en: "Reservation converted into a loan",
    it: "Prenotazione convertita in prestito",
    de: "Vormerkung in Ausleihe umgewandelt",
    ca: "Reserva convertida en préstec",
    eo: "Rezervo konvertita en prunton"
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
    eo: "Elpreno planita"
  },
  "wf.pickupRescheduled": {
    "pt-BR": "Retirada reagendada",
    fr: "Retrait reprogrammé",
    es: "Retiro reprogramado",
    en: "Pickup rescheduled",
    it: "Ritiro riprogrammato",
    de: "Abholung neu geplant",
    ca: "Recollida reprogramada",
    eo: "Elpreno replanita"
  },
  "wf.ready": {
    "pt-BR": "Sua reserva está pronta para retirada",
    fr: "Ta réservation est prête à être retirée",
    es: "Tu reserva está lista para retirar",
    en: "Your reservation is ready for pickup",
    it: "La tua prenotazione è pronta per il ritiro",
    de: "Deine Vormerkung liegt zur Abholung bereit",
    ca: "La teva reserva està llesta per recollir",
    eo: "Via rezervo estas preta por elpreno"
  },
  "wf.readyShort": {
    "pt-BR": "Reserva pronta",
    fr: "Réservation prête",
    es: "Reserva lista",
    en: "Reservation ready",
    it: "Prenotazione pronta",
    de: "Vormerkung bereit",
    ca: "Reserva llesta",
    eo: "Rezervo preta"
  },
  "wf.noShow": {
    "pt-BR": "Retirada não realizada",
    fr: "Retrait non effectué",
    es: "Retiro no realizado",
    en: "Pickup missed",
    it: "Ritiro non effettuato",
    de: "Abholung nicht erfolgt",
    ca: "Recollida no efectuada",
    eo: "Elpreno ne efektivigita"
  },
  "wf.closed": {
    "pt-BR": "Reserva encerrada",
    fr: "Réservation clôturée",
    es: "Reserva cerrada",
    en: "Reservation closed",
    it: "Prenotazione chiusa",
    de: "Vormerkung abgeschlossen",
    ca: "Reserva tancada",
    eo: "Rezervo fermita"
  },
  "wf.preparing": {
    "pt-BR": "Sua reserva está em preparação",
    fr: "Ta réservation est en préparation",
    es: "Tu reserva está en preparación",
    en: "Your reservation is being prepared",
    it: "La tua prenotazione è in preparazione",
    de: "Deine Vormerkung wird vorbereitet",
    ca: "La teva reserva s'està preparant",
    eo: "Via rezervo estas preparata"
  },
  "wf.preparingShort": {
    "pt-BR": "Em preparação",
    fr: "En préparation",
    es: "En preparación",
    en: "Being prepared",
    it: "In preparazione",
    de: "In Vorbereitung",
    ca: "En preparació",
    eo: "En preparado"
  },
  "wf.toCoordinate": {
    "pt-BR": "Retirada a combinar com a biblioteca",
    fr: "Retrait à organiser avec la bibliothèque",
    es: "Retiro a coordinar con la biblioteca",
    en: "Pickup to be arranged with the library",
    it: "Ritiro da concordare con la biblioteca",
    de: "Abholung mit der Bibliothek abzustimmen",
    ca: "Recollida a coordinar amb la biblioteca",
    eo: "Elpreno interkonsentenda kun la biblioteko"
  },
  "wf.toCoordinateShort": {
    "pt-BR": "A combinar",
    fr: "À convenir",
    es: "A coordinar",
    en: "To arrange",
    it: "Da concordare",
    de: "Abzustimmen",
    ca: "A convenir",
    eo: "Interkonsentenda"
  },
    "wf.checkAccount": {
    "pt-BR": "Confira sua conta para mais detalhes.",
    fr: "Consulte ton compte pour plus de détails.",
    es: "Consulte tu cuenta para más detalles.",
    en: "Check your account for more details.",
    it: "Controlla il tuo account per maggiori dettagli.",
    de: "Sieh in deinem Konto für weitere Details nach.",
    ca: "Consulta el teu compte per a més detalls.",
    eo: "Konsultu vian konton por pliaj detaloj."
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
    eo: "Elpren-tempfendo proponita de la biblioteko"
  },
  "wf.reader.libraryProposed.body": {
    "pt-BR": "A biblioteca propõe um horário para você vir retirar seu livro. Você pode aceitar este horário, propor outro, ou cancelar a reserva pela sua conta.",
    fr: "La biblio te propose un créneau pour venir retirer ton livre. Tu peux accepter ce créneau, en proposer un autre, ou annuler ta réservation depuis ton compte.",
    es: "La biblioteca te propone un horario para venir a retirar tu libro. Podés aceptar este horario, proponer otro, o cancelar tu reserva desde tu cuenta.",
    en: "The library is proposing a time slot for you to come pick up your book. You can accept this slot, propose another one, or cancel your reservation from your account.",
    it: "La biblioteca ti propone un orario per venire a ritirare il tuo libro. Puoi accettare questo orario, proporne un altro, o annullare la tua prenotazione dal tuo account.",
    de: "Die Bibliothek schlägt dir einen Termin vor, um dein Buch abzuholen. Du kannst diesen Termin annehmen, einen anderen vorschlagen oder deine Vormerkung über dein Konto stornieren.",
    ca: "La biblioteca et proposa una franja per venir a recollir el teu llibre. Pots acceptar aquesta franja, proposar-ne una altra, o cancel·lar la teva reserva des del teu compte.",
    eo: "La biblioteko proponas al vi tempfendon por veni elpreni vian libron. Vi povas akcepti ĉi tiun tempfendon, proponi alian, aŭ nuligi vian rezervon el via konto."
  },
  "wf.reader.youCounterProposed.subject": {
    "pt-BR": "Contra-proposta enviada (tentativa {iter}/{max})",
    fr: "Contre-proposition transmise (essai {iter}/{max})",
    es: "Contrapropuesta enviada (intento {iter}/{max})",
    en: "Counter-proposal sent (attempt {iter}/{max})",
    it: "Controproposta inviata (tentativo {iter}/{max})",
    de: "Gegenvorschlag gesendet (Versuch {iter}/{max})",
    ca: "Contraproposta enviada (intent {iter}/{max})",
    eo: "Kontraŭpropono sendita (provo {iter}/{max})"
  },
  "wf.reader.youCounterProposed.body": {
    "pt-BR": "Sua contra-proposta foi enviada à biblioteca (tentativa {iter}/{max}). Você será avisado(a/e) assim que ela responder.",
    fr: "Ta contre-proposition est bien transmise à la biblio (essai {iter}/{max}). Tu seras prévenu·e dès que celle-ci répond.",
    es: "Tu contrapropuesta fue enviada a la biblioteca (intento {iter}/{max}). Serás avisade en cuanto te respondan.",
    en: "Your counter-proposal has been sent to the library (attempt {iter}/{max}). You will be notified as soon as they reply.",
    it: "La tua controproposta è stata inviata alla biblioteca (tentativo {iter}/{max}). Sarai avvisatə non appena rispondano.",
    de: "Dein Gegenvorschlag wurde an die Bibliothek gesendet (Versuch {iter}/{max}). Du wirst benachrichtigt, sobald geantwortet wird.",
    ca: "La teva contraproposta s'ha enviat a la biblioteca (intent {iter}/{max}). Se t'avisarà tan bon punt respongui.",
    eo: "Via kontraŭpropono estis sendita al la biblioteko (provo {iter}/{max}). Vi estos avertita tuj kiam ĝi respondos."
  },
  "wf.reader.slotLocked.subject": {
    "pt-BR": "Horário de retirada confirmado",
    fr: "Créneau de retrait confirmé",
    es: "Horario de retiro confirmado",
    en: "Pickup slot confirmed",
    it: "Orario di ritiro confermato",
    de: "Abholtermin bestätigt",
    ca: "Franja de recollida confirmada",
    eo: "Elpren-tempfendo konfirmita"
  },
  "wf.reader.slotLocked.body": {
    "pt-BR": "O horário está confirmado e bloqueado. O livro estará em breve pronto para retirada — você receberá uma notificação assim que isso acontecer.",
    fr: "Le créneau est confirmé et verrouillé. Le livre sera bientôt prêt à retirer — tu recevras une notification dès que ce sera le cas.",
    es: "El horario está confirmado y bloqueado. El libro estará pronto listo para retirar — recibirás una notificación apenas eso suceda.",
    en: "The slot is confirmed and locked. The book will soon be ready for pickup — you will receive a notification as soon as that happens.",
    it: "L'orario è confermato e bloccato. Il libro sarà presto pronto per il ritiro — riceverai una notifica appena ciò accada.",
    de: "Der Termin ist bestätigt und festgelegt. Das Buch wird bald zur Abholung bereit sein — du erhältst eine Benachrichtigung, sobald dies der Fall ist.",
    ca: "La franja està confirmada i bloquejada. El llibre estarà aviat llest per recollir — rebràs una notificació tan bon punt sigui el cas.",
    eo: "La tempfendo estas konfirmita kaj ŝlosita. La libro baldaŭ estos preta por elpreno — vi ricevos sciigon tuj kiam tio okazos."
  },
  "wf.reader.maxIterations.subject": {
    "pt-BR": "Negociação sem acordo — contato direto recomendado",
    fr: "Négociation sans accord — contact direct conseillé",
    es: "Negociación sin acuerdo — contacto directo recomendado",
    en: "Negotiation without agreement — direct contact advised",
    it: "Negoziazione senza accordo — contatto diretto consigliato",
    de: "Verhandlung ohne Einigung — direkter Kontakt empfohlen",
    ca: "Negociació sense acord — es recomana contacte directe",
    eo: "Traktado sen interkonsento — rekta kontakto rekomendata"
  },
  "wf.reader.maxIterations.body": {
    "pt-BR": "Várias trocas sem encontrar um horário que funcione para todo mundo. Para continuar, o melhor é entrar em contato diretamente com a biblioteca para conversar.",
    fr: "Plusieurs allers-retours sans qu'on trouve un créneau qui convient à tout le monde. Pour continuer, le mieux est de contacter directement la biblio pour en discuter.",
    es: "Varios intercambios sin encontrar un horario que convenga a todes. Para continuar, lo mejor es contactar directamente a la biblioteca para conversar.",
    en: "Several exchanges without finding a time slot that works for everyone. To continue, the best is to contact the library directly to discuss.",
    it: "Diversi scambi senza trovare un orario che vada bene a tuttə. Per continuare, la cosa migliore è contattare direttamente la biblioteca per parlarne.",
    de: "Mehrere Versuche, ohne einen für alle passenden Termin zu finden. Um weiterzukommen, ist es am besten, sich direkt an die Bibliothek zu wenden, um darüber zu sprechen.",
    ca: "Diversos intercanvis sense trobar una franja que funcioni per a tothom. Per continuar, el millor és contactar directament la biblioteca per parlar-ne.",
    eo: "Pluraj interŝanĝoj sen trovi tempfendon kiu konvenas al ĉiuj. Por daŭrigi, plej bone estas kontakti rekte la bibliotekon por priparoli."
  },
  "wf.reader.negotiationTimeout.subject": {
    "pt-BR": "Reserva liberada — prazo de negociação expirado",
    fr: "Réservation libérée — délai de négociation dépassé",
    es: "Reserva liberada — plazo de negociación vencido",
    en: "Reservation released — negotiation deadline exceeded",
    it: "Prenotazione liberata — termine di negoziazione scaduto",
    de: "Vormerkung freigegeben — Verhandlungsfrist abgelaufen",
    ca: "Reserva alliberada — termini de negociació vençut",
    eo: "Rezervo liberigita — trakta limdato eksvalidiĝinta"
  },
  "wf.reader.negotiationTimeout.body": {
    "pt-BR": "A negociação do seu horário ultrapassou o prazo sem acordo. A reserva foi liberada e o livro voltou à circulação. Você pode reservá-lo novamente quando quiser.",
    fr: "La négociation pour ton créneau a dépassé le délai sans accord. La réservation a été libérée, le livre repart en circulation. Tu peux le réserver à nouveau quand tu veux.",
    es: "La negociación de tu horario superó el plazo sin acuerdo. La reserva fue liberada, el libro vuelve a la circulación. Podés reservarlo nuevamente cuando quieras.",
    en: "The negotiation for your slot has exceeded the deadline without agreement. The reservation has been released, the book returns to circulation. You can reserve it again whenever you want.",
    it: "La negoziazione del tuo orario ha superato il termine senza accordo. La prenotazione è stata liberata, il libro torna in circolazione. Puoi prenotarlo di nuovo quando vuoi.",
    de: "Die Verhandlung über deinen Termin hat die Frist ohne Einigung überschritten. Die Vormerkung wurde freigegeben, das Buch geht zurück in den Umlauf. Du kannst es jederzeit erneut vormerken.",
    ca: "La negociació de la teva franja ha superat el termini sense acord. La reserva s'ha alliberat i el llibre ha tornat a la circulació. Pots reservar-lo de nou quan vulguis.",
    eo: "La traktado de via tempfendo superis la limdaton sen interkonsento. La rezervo estis liberigita kaj la libro revenis al cirkulado. Vi povas rezervi ĝin denove kiam vi volas."
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
    eo: "Tempfenda traktado malfermita kun la legant-in-o"
  },
  "wf.staff.negotiationOpened.body": {
    "pt-BR": "A negociação de um horário de retirada foi aberta com o(a/e) leitor(a/e). O(a/e) leitor(a/e) foi avisado(a/e) por e-mail e pode aceitar, contra-propor ou cancelar pela própria conta.",
    fr: "La négociation d'un créneau de retrait a été ouverte avec le·la lecteur·rice. Le·la lecteur·rice a été prévenu·e par mail et peut accepter, contre-proposer ou annuler depuis son compte.",
    es: "Se abrió la negociación de un horario de retiro con le lectore. Le lectore fue avisade por correo y puede aceptar, contraproponer o cancelar desde su cuenta.",
    en: "A negotiation has been opened with the reader for a pickup slot. The reader has been notified by email and can accept, counter-propose, or cancel from their account.",
    it: "È stata aperta la negoziazione di un orario di ritiro con lə lettorə. Lə lettorə è statə avvisatə via email e può accettare, controproporre o annullare dal proprio account.",
    de: "Eine Verhandlung über einen Abholtermin wurde mit der*dem Leser*in eröffnet. Die*Der Leser*in wurde per E-Mail benachrichtigt und kann annehmen, gegenvorschlagen oder über das eigene Konto stornieren.",
    ca: "S'ha obert la negociació d'una franja de recollida amb le lector-a-e. Le lector-a-e ha estat avisade per correu i pot acceptar, contraproposar o cancel·lar des del seu compte.",
    eo: "La traktado de elpren-tempfendo estis malfermita kun la legant-in-o. La legant-in-o estis avertita retpoŝte kaj povas akcepti, kontraŭproponi aŭ nuligi el sia konto."
  },
  "wf.staff.readerCounterProposed.subject": {
    "pt-BR": "Contra-proposta do(a/e) leitor(a/e) — ação esperada",
    fr: "Contre-proposition du·de la lecteur·rice — action attendue",
    es: "Contrapropuesta de le lectore — acción esperada",
    en: "Counter-proposal from the reader — action expected",
    it: "Controproposta di lə lettorə — azione attesa",
    de: "Gegenvorschlag der*des Leser*in — Aktion erwartet",
    ca: "Contraproposta de le lector-a-e — acció esperada",
    eo: "Kontraŭpropono de la legant-in-o — ago atendata"
  },
  "wf.staff.readerCounterProposed.body": {
    "pt-BR": "O(a/e) leitor(a/e) contra-propôs outro horário para a retirada. <b>Resposta esperada</b> : abrir o painel para aceitar, contra-propor por sua vez, ou cancelar.",
    fr: "Le·la lecteur·rice a contre-proposé un autre créneau pour le retrait. <b>Réponse attendue</b> : ouvrir le tableau de bord pour accepter, contre-proposer à votre tour, ou annuler.",
    es: "Le lectore contrapropuso otro horario para el retiro. <b>Respuesta esperada</b> : abrir el panel para aceptar, contraproponer a su vez, o cancelar.",
    en: "The reader has counter-proposed another slot for the pickup. <b>Response expected</b> : open the dashboard to accept, counter-propose in turn, or cancel.",
    it: "Lə lettorə ha controproposto un altro orario per il ritiro. <b>Risposta attesa</b> : aprire il pannello per accettare, controproporre a vostra volta, o annullare.",
    de: "Die*Der Leser*in hat einen anderen Termin für die Abholung vorgeschlagen. <b>Antwort erwartet</b> : Öffnet das Dashboard, um anzunehmen, einen Gegenvorschlag zu machen oder zu stornieren.",
    ca: "Le lector-a-e ha contraproposat una altra franja per a la recollida. <b>Resposta esperada</b> : obrir el tauler per acceptar, contraproposar al teu torn, o cancel·lar.",
    eo: "La legant-in-o kontraŭproponis alian tempfendon por la elpreno. <b>Atendata respondo</b> : malfermi la panelon por akcepti, kontraŭproponi siavice, aŭ nuligi."
  },
  "wf.staff.readerAccepted.subject": {
    "pt-BR": "Horário aceito pelo(a/e) leitor(a/e)",
    fr: "Créneau accepté par le·la lecteur·rice",
    es: "Horario aceptado por le lectore",
    en: "Slot accepted by the reader",
    it: "Orario accettato da lə lettorə",
    de: "Termin von der*dem Leser*in angenommen",
    ca: "Franja acceptada per le lector-a-e",
    eo: "Tempfendo akceptita de la legant-in-o"
  },
  "wf.staff.readerAccepted.body": {
    "pt-BR": "O(a/e) leitor(a/e) aceitou o horário proposto. O horário está bloqueado — o livro pode ser preparado para a retirada.",
    fr: "Le·la lecteur·rice a accepté le créneau proposé. Le créneau est verrouillé — le livre peut être préparé pour le retrait.",
    es: "Le lectore aceptó el horario propuesto. El horario está bloqueado — el libro puede ser preparado para el retiro.",
    en: "The reader has accepted the proposed slot. The slot is locked — the book can be prepared for pickup.",
    it: "Lə lettorə ha accettato l'orario proposto. L'orario è bloccato — il libro può essere preparato per il ritiro.",
    de: "Die*Der Leser*in hat den vorgeschlagenen Termin angenommen. Der Termin ist festgelegt — das Buch kann für die Abholung vorbereitet werden.",
    ca: "Le lector-a-e ha acceptat la franja proposada. La franja està bloquejada — el llibre es pot preparar per a la recollida.",
    eo: "La legant-in-o akceptis la proponitan tempfendon. La tempfendo estas ŝlosita — la libro povas esti preparita por la elpreno."
  },
  "wf.staff.staffConfirmed.subject": {
    "pt-BR": "Horário do(a/e) leitor(a/e) confirmado",
    fr: "Créneau du·de la lecteur·rice confirmé",
    es: "Horario de le lectore confirmado",
    en: "Reader's slot confirmed",
    it: "Orario di lə lettorə confermato",
    de: "Termin der*des Leser*in bestätigt",
    ca: "Franja de le lector-a-e confirmada",
    eo: "Tempfendo de la legant-in-o konfirmita"
  },
  "wf.staff.staffConfirmed.body": {
    "pt-BR": "Você confirmou o horário proposto pelo(a/e) leitor(a/e). O horário está bloqueado — o livro pode ser preparado para a retirada.",
    fr: "Tu as confirmé le créneau proposé par le·la lecteur·rice. Le créneau est verrouillé — le livre peut être préparé pour le retrait.",
    es: "Confirmaste el horario propuesto por le lectore. El horario está bloqueado — el libro puede ser preparado para el retiro.",
    en: "You have confirmed the slot proposed by the reader. The slot is locked — the book can be prepared for pickup.",
    it: "Avete confermato l'orario proposto da lə lettorə. L'orario è bloccato — il libro può essere preparato per il ritiro.",
    de: "Ihr habt den von der*dem Leser*in vorgeschlagenen Termin bestätigt. Der Termin ist festgelegt — das Buch kann für die Abholung vorbereitet werden.",
    ca: "Has confirmat la franja proposada per le lector-a-e. La franja està bloquejada — el llibre es pot preparar per a la recollida.",
    eo: "Vi konfirmis la tempfendon proponitan de la legant-in-o. La tempfendo estas ŝlosita — la libro povas esti preparita por la elpreno."
  },
  "wf.staff.ready.subject": {
    "pt-BR": "Livro pronto para retirada — leitor(a/e) avisado(a/e)",
    fr: "Livre prêt — lecteur·rice prévenu·e",
    es: "Libro listo — lectore avisade",
    en: "Book ready — reader notified",
    it: "Libro pronto — lettorə avvisatə",
    de: "Buch bereit — Leser*in benachrichtigt",
    ca: "Llibre llest per recollir — lector-a-e avisade",
    eo: "Libro preta por elpreno — legant-in-o avertita"
  },
  "wf.staff.ready.body": {
    "pt-BR": "Você sinalizou que o livro está pronto para a retirada. O(a/e) leitor(a/e) foi avisado(a/e).",
    fr: "Tu as signalé que le livre est prêt à être retiré. Le·la lecteur·rice a été prévenu·e.",
    es: "Indicaste que el libro está listo para ser retirado. Le lectore fue avisade.",
    en: "You have signaled that the book is ready for pickup. The reader has been notified.",
    it: "Avete segnalato che il libro è pronto per il ritiro. Lə lettorə è statə avvisatə.",
    de: "Ihr habt gemeldet, dass das Buch zur Abholung bereit ist. Die*Der Leser*in wurde benachrichtigt.",
    ca: "Has indicat que el llibre està llest per ser recollit. Le lector-a-e ha estat avisade.",
    eo: "Vi indikis ke la libro estas preta por elpreno. La legant-in-o estis avertita."
  },
  "wf.staff.noShow.subject": {
    "pt-BR": "Retirada não realizada",
    fr: "Retrait non effectué",
    es: "Retiro no realizado",
    en: "Pickup missed",
    it: "Ritiro non effettuato",
    de: "Abholung nicht erfolgt",
    ca: "Recollida no efectuada",
    eo: "Elpreno ne efektivigita"
  },
  "wf.staff.noShow.body": {
    "pt-BR": "O livro não foi retirado no horário previsto. A reserva foi marcada como não-retirada — o livro voltará em breve à circulação livre.",
    fr: "Le livre n'a pas été retiré au créneau prévu. La réservation est marquée en non-retrait — le livre repassera bientôt en circulation libre.",
    es: "El libro no fue retirado en el horario previsto. La reserva fue marcada como no-retiro — el libro volverá pronto a la circulación libre.",
    en: "The book was not picked up at the scheduled time. The reservation is marked as no-show — the book will soon return to free circulation.",
    it: "Il libro non è stato ritirato nell'orario previsto. La prenotazione è stata segnata come non-ritiro — il libro tornerà presto in circolazione libera.",
    de: "Das Buch wurde zum vereinbarten Termin nicht abgeholt. Die Vormerkung ist als Nicht-Abholung markiert — das Buch geht bald zurück in den freien Umlauf.",
    ca: "El llibre no s'ha recollit en la franja prevista. La reserva s'ha marcat com a no-recollida — el llibre tornarà aviat a la circulació lliure.",
    eo: "La libro ne estis elprenita en la planita tempfendo. La rezervo estis markita kiel ne-elpreno — la libro baldaŭ revenos al libera cirkulado."
  },
  "wf.staff.closed.subject": {
    "pt-BR": "Reserva encerrada",
    fr: "Réservation close",
    es: "Reserva cerrada",
    en: "Reservation closed",
    it: "Prenotazione chiusa",
    de: "Vormerkung abgeschlossen",
    ca: "Reserva tancada",
    eo: "Rezervo fermita"
  },
  "wf.staff.closed.body": {
    "pt-BR": "A reserva está encerrada, o livro voltou à circulação livre. Nenhuma ação adicional é esperada de sua parte.",
    fr: "La réservation est close, le livre repasse en circulation libre. Aucune action supplémentaire n'est attendue de votre part.",
    es: "La reserva está cerrada, el libro vuelve a la circulación libre. No se espera ninguna acción adicional de su parte.",
    en: "The reservation is closed, the book returns to free circulation. No additional action is expected from you.",
    it: "La prenotazione è chiusa, il libro torna in circolazione libera. Nessuna azione aggiuntiva è attesa da parte vostra.",
    de: "Die Vormerkung ist abgeschlossen, das Buch geht zurück in den freien Umlauf. Keine zusätzliche Aktion eurerseits ist erforderlich.",
    ca: "La reserva està tancada, el llibre torna a la circulació lliure. No s'espera cap acció addicional per part teva.",
    eo: "La rezervo estas fermita, la libro revenas al libera cirkulado. Neniu plia ago estas atendata de vi."
  },
  "wf.staff.maxIterations.subject": {
    "pt-BR": "Negociação sem acordo — leitor(a/e) convidado(a/e) ao contato direto",
    fr: "Négociation sans accord — lecteur·rice invité·e au contact direct",
    es: "Negociación sin acuerdo — lectore invitade al contacto directo",
    en: "Negotiation without agreement — reader invited to direct contact",
    it: "Negoziazione senza accordo — lettorə invitatə al contatto diretto",
    de: "Verhandlung ohne Einigung — Leser*in zum direkten Kontakt eingeladen",
    ca: "Negociació sense acord — lector-a-e convidade al contacte directe",
    eo: "Traktado sen interkonsento — legant-in-o invitita al rekta kontakto"
  },
  "wf.staff.maxIterations.body": {
    "pt-BR": "Várias trocas sem acordo com o(a/e) leitor(a/e). O(a/e) leitor(a/e) foi convidado(a/e) a entrar em contato diretamente para encontrar uma solução.",
    fr: "Plusieurs allers-retours sans accord avec le·la lecteur·rice. Le·la lecteur·rice a été invité·e à vous contacter directement pour trouver une solution.",
    es: "Varios intercambios sin acuerdo con le lectore. Le lectore fue invitade a contactarles directamente para encontrar una solución.",
    en: "Several exchanges without agreement with the reader. The reader has been invited to contact you directly to find a solution.",
    it: "Diversi scambi senza accordo con lə lettorə. Lə lettorə è statə invitatə a contattarvi direttamente per trovare una soluzione.",
    de: "Mehrere Versuche ohne Einigung mit der*dem Leser*in. Die*Der Leser*in wurde gebeten, sich direkt an euch zu wenden, um eine Lösung zu finden.",
    ca: "Diversos intercanvis sense acord amb le lector-a-e. Le lector-a-e ha estat convidade a contactar-vos directament per trobar una solució.",
    eo: "Pluraj interŝanĝoj sen interkonsento kun la legant-in-o. La legant-in-o estis invitita kontakti vin rekte por trovi solvon."
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
    eo: "Nova propono de la biblioteko"
  },
  "wf.reader.libraryCounterProposed.body": {
    "pt-BR": "A biblioteca respondeu à sua contra-proposta com um novo horário. Você pode aceitar este horário, propor outro, ou cancelar a reserva pela sua conta.",
    fr: "La biblio a répondu à ta contre-proposition avec un nouveau créneau. Tu peux accepter ce créneau, en proposer un autre, ou annuler ta réservation depuis ton compte.",
    es: "La biblioteca respondió a tu contrapropuesta con un nuevo horario. Podés aceptar este horario, proponer otro, o cancelar tu reserva desde tu cuenta.",
    en: "The library has responded to your counter-proposal with a new time slot. You can accept this slot, propose another one, or cancel your reservation from your account.",
    it: "La biblioteca ha risposto alla tua controproposta con un nuovo orario. Puoi accettare questo orario, proporne un altro, o annullare la tua prenotazione dal tuo account.",
    de: "Die Bibliothek hat auf deinen Gegenvorschlag mit einem neuen Termin geantwortet. Du kannst diesen Termin annehmen, einen anderen vorschlagen oder deine Vormerkung über dein Konto stornieren.",
    ca: "La biblioteca ha respost a la teva contraproposta amb una nova franja. Pots acceptar aquesta franja, proposar-ne una altra, o cancel·lar la teva reserva des del teu compte.",
    eo: "La biblioteko respondis al via kontraŭpropono per nova tempfendo. Vi povas akcepti ĉi tiun tempfendon, proponi alian, aŭ nuligi vian rezervon el via konto."
  },
  "wf.staff.staffCounterProposed.subject": {
    "pt-BR": "Contra-proposta enviada ao(a/e) leitor(a/e)",
    fr: "Contre-proposition envoyée au·à la lecteur·rice",
    es: "Contrapropuesta enviada a le lectore",
    en: "Counter-proposal sent to the reader",
    it: "Controproposta inviata a lə lettorə",
    de: "Gegenvorschlag an die*den Leser*in gesendet",
    ca: "Contraproposta enviada a le lector-a-e",
    eo: "Kontraŭpropono sendita al la legant-in-o"
  },
  "wf.staff.staffCounterProposed.body": {
    "pt-BR": "Você enviou uma nova contra-proposta de horário ao(a/e) leitor(a/e) em resposta à proposta recebida. Aguarde a resposta.",
    fr: "Tu as envoyé une nouvelle contre-proposition de créneau au·à la lecteur·rice en réponse à sa proposition. En attente de sa réponse.",
    es: "Enviaste una nueva contrapropuesta de horario a le lectore en respuesta a su propuesta. Esperando su respuesta.",
    en: "You have sent a new counter-proposal to the reader in response to their proposal. Awaiting their reply.",
    it: "Avete inviato una nuova controproposta di orario a lə lettorə in risposta alla sua proposta. In attesa della sua risposta.",
    de: "Ihr habt einen neuen Gegenvorschlag an die*den Leser*in als Antwort auf deren Vorschlag gesendet. Wartet auf Antwort.",
    ca: "Has enviat una nova contraproposta de franja a le lector-a-e en resposta a la seva proposta. A l'espera de la seva resposta.",
    eo: "Vi sendis novan tempfendan kontraŭproponon al la legant-in-o responde al ĝia propono. Atendante ĝian respondon."
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
    eo: "Traktado eksvalidiĝinta — rezervo liberigita"
  },
  "wf.staff.negotiationTimedOut.body": {
    "pt-BR": "A negociação para a retirada expirou sem acordo ({days} dias sem resposta). A reserva foi liberada automaticamente e o livro voltou à circulação livre.",
    fr: "La négociation pour le retrait a expiré sans accord ({days} jours sans réponse). La réservation a été libérée automatiquement, le livre repasse en circulation libre.",
    es: "La negociación para el retiro expiró sin acuerdo ({days} días sin respuesta). La reserva fue liberada automáticamente, el libro vuelve a la circulación libre.",
    en: "The negotiation for the pickup has expired without agreement ({days} days without reply). The reservation has been released automatically, the book returns to free circulation.",
    it: "La negoziazione per il ritiro è scaduta senza accordo ({days} giorni senza risposta). La prenotazione è stata liberata automaticamente, il libro torna in circolazione libera.",
    de: "Die Verhandlung über die Abholung ist ohne Einigung abgelaufen ({days} Tage ohne Antwort). Die Vormerkung wurde automatisch freigegeben, das Buch geht zurück in den freien Umlauf.",
    ca: "La negociació per a la recollida ha expirat sense acord ({days} dies sense resposta). La reserva s'ha alliberat automàticament i el llibre ha tornat a la circulació lliure.",
    eo: "La traktado por la elpreno eksvalidiĝis sen interkonsento ({days} tagoj sen respondo). La rezervo estis liberigita aŭtomate kaj la libro revenas al libera cirkulado."
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
    eo: "Atendata ago"
  },
  "wf.staff.actionBox.openPanel": {
    "pt-BR": "Abrir o painel",
    fr: "Ouvrir le tableau de bord",
    es: "Abrir el panel",
    en: "Open the dashboard",
    it: "Aprire il pannello",
    de: "Dashboard öffnen",
    ca: "Obrir el tauler",
    eo: "Malfermi la panelon"
  },
  "wf.staff.infoBox.title": {
    "pt-BR": "Para sua informação",
    fr: "Pour information",
    es: "Para su información",
    en: "For your information",
    it: "Per vostra informazione",
    de: "Zu Ihrer Information",
    ca: "Per a la teva informació",
    eo: "Por via informo"
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
    eo: "[Ago postulata]"
  },
  "subj.staff.info": {
    "pt-BR": "[Info]",
    fr: "[Info]",
    es: "[Info]",
    en: "[Info]",
    it: "[Info]",
    de: "[Info]",
    ca: "[Info]",
    eo: "[Info]"
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
    eo: "libera disvastigo"
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
    eo: "Prunto registrita"
  },
  "loan.created.intro": {
    "pt-BR": "Seu empréstimo foi registrado.",
    fr: "Ton emprunt a bien été enregistré.",
    es: "Tu préstamo fue registrado.",
    en: "Your loan has been registered.",
    it: "Il tuo prestito è stato registrato.",
    de: "Deine Ausleihe wurde registriert.",
    ca: "El teu préstec s'ha registrat correctament.",
    eo: "Via prunto estis sukcese registrita."
  },
  "loan.dueIn": {
    "pt-BR": "Devolução prevista para {date}.",
    fr: "Retour prévu pour le {date}.",
    es: "Devolución prevista para el {date}.",
    en: "Due date: {date}.",
    it: "Restituzione prevista per il {date}.",
    de: "Rückgabe vorgesehen für den {date}.",
    ca: "Retorn previst per al {date}.",
    eo: "Redono planita por la {date}."
  },
  "loan.renewed.sub": {
    "pt-BR": "Renovação confirmada",
    fr: "Renouvellement confirmé",
    es: "Renovación confirmada",
    en: "Renewal confirmed",
    it: "Rinnovo confermato",
    de: "Verlängerung bestätigt",
    ca: "Renovació confirmada",
    eo: "Renovigo konfirmita"
  },
  "loan.renewed.intro": {
    "pt-BR": "Sua prorrogação foi confirmada.",
    fr: "Ta prolongation a bien été confirmée.",
    es: "Tu renovación fue confirmada.",
    en: "Your renewal has been confirmed.",
    it: "Il tuo rinnovo è stato confermato.",
    de: "Deine Verlängerung wurde bestätigt.",
    ca: "La teva renovació s'ha confirmat correctament.",
    eo: "Via renovigo estis sukcese konfirmita."
  },
  "loan.newDue": {
    "pt-BR": "Nova data de devolução: {date}.",
    fr: "Nouvelle date de retour : {date}.",
    es: "Nueva fecha de devolución: {date}.",
    en: "New due date: {date}.",
    it: "Nuova data di restituzione: {date}.",
    de: "Neues Rückgabedatum: {date}.",
    ca: "Nova data de retorn: {date}.",
    eo: "Nova redato: {date}."
  },
  "loan.renewed.once": {
    "pt-BR": "Lembre-se: cada empréstimo pode ser prorrogado apenas uma vez.",
    fr: "Pour rappel : chaque emprunt ne peut être prolongé qu'une seule fois.",
    es: "Recuerda: cada préstamo puede renovarse solo une vez.",
    en: "Reminder: each loan can be renewed only once.",
    it: "Ricorda: ogni prestito può essere rinnovato solo una volta.",
    de: "Zur Erinnerung: jede Ausleihe kann nur einmal verlängert werden.",
    ca: "Recorda: cada préstec només es pot renovar una vegada.",
    eo: "Memoru: ĉiu prunto povas esti renovigita nur unufoje."
  },
  "loan.returned.sub": {
    "pt-BR": "Devolução registrada",
    fr: "Retour enregistré",
    es: "Devolución registrada",
    en: "Return registered",
    it: "Restituzione registrata",
    de: "Rückgabe registriert",
    ca: "Retorn registrat",
    eo: "Redono registrita"
  },
  "loan.returned.intro": {
    "pt-BR": "Registramos a devolução. Obrigad(o/a/e)!",
    fr: "Nous avons enregistré le retour. Merci !",
    es: "Registramos la devolución. ¡Gracias!",
    en: "We've recorded the return. Thank you!",
    it: "Abbiamo registrato la restituzione. Grazie!",
    de: "Wir haben die Rückgabe registriert. Danke!",
    ca: "Hem registrat el retorn. Gràcies!",
    eo: "Ni registris la redonon. Dankon!"
  },
  "loan.returned.browse": {
    "pt-BR": "Continue navegando no acervo para suas próximas leituras.",
    fr: "Continue à explorer le fonds pour tes prochaines lectures.",
    es: "Sigue navegando el acervo para tus próximas lecturas.",
    en: "Keep browsing the collection for your next reads.",
    it: "Continua a esplorare il fondo per le tue prossime letture.",
    de: "Stöbere weiter im Bestand für deine nächste Lektüre.",
    ca: "Continua explorant el fons per a les teves properes lectures.",
    eo: "Daŭrigu esplori la fonduson por viaj sekvaj legaĵoj."
  },
  "loan.returnScheduled": {
    "pt-BR": "Devolução agendada",
    fr: "Retour programmé",
    es: "Devolución programada",
    en: "Return scheduled",
    it: "Restituzione programmata",
    de: "Rückgabe geplant",
    ca: "Retorn programat",
    eo: "Redono planita"
  },
  "loan.returnCancelled": {
    "pt-BR": "Devolução cancelada",
    fr: "Retour annulé",
    es: "Devolución cancelada",
    en: "Return cancelled",
    it: "Restituzione annullata",
    de: "Rückgabe storniert",
    ca: "Retorn cancel·lat",
    eo: "Redono nuligita"
  },
  "loan.returnMissed": {
    "pt-BR": "Devolução não realizada",
    fr: "Retour non effectué",
    es: "Devolución no realizada",
    en: "Return missed",
    it: "Restituzione non effettuata",
    de: "Rückgabe nicht erfolgt",
    ca: "Retorn no efectuat",
    eo: "Redono ne efektivigita"
  },
  "loan.partialReturn.sub": {
    "pt-BR": "Devolução parcial registrada",
    fr: "Retour partiel enregistré",
    es: "Devolución parcial registrada",
    en: "Partial return recorded",
    it: "Restituzione parziale registrata",
    de: "Teilrückgabe registriert",
    ca: "Retorn parcial registrat",
    eo: "Parta redono registrita"
  },
  "loan.partialReturn.intro": {
    "pt-BR": "Registramos a devolução parcial do seu empréstimo. Obrigad(o/a/e) por trazer alguns documentos!",
    fr: "Nous avons enregistré le retour partiel de ton emprunt. Merci d'avoir rapporté une partie des documents !",
    es: "Registramos la devolución parcial de tu préstamo. ¡Gracias por traer une parte de los documentos!",
    en: "We've recorded the partial return of your loan. Thank you for bringing back some of the documents!",
    it: "Abbiamo registrato la restituzione parziale del tuo prestito. Grazie per aver riportato alcuni documenti!",
    de: "Wir haben die Teilrückgabe deiner Ausleihe registriert. Danke, dass du einige Dokumente zurückgebracht hast!",
    ca: "Hem registrat el retorn parcial del teu préstec. Gràcies per portar alguns documents!",
    eo: "Ni registris la partan redonon de via prunto. Dankon pro reporti kelkajn dokumentojn!"
  },
  "loan.partialReturn.dueReminder": {
    "pt-BR": "Lembrete: a data de devolução dos documentos restantes é {date}.",
    fr: "Rappel : la date de retour des documents restants est le {date}.",
    es: "Recordatorio: la fecha de devolución de los documentos restantes es el {date}.",
    en: "Reminder: the due date for the remaining documents is {date}.",
    it: "Promemoria: la data di restituzione dei documenti rimanenti è il {date}.",
    de: "Erinnerung: das Rückgabedatum für die verbleibenden Dokumente ist der {date}.",
    ca: "Recordatori: la data de retorn dels documents restants és el {date}.",
    eo: "Memorigo: la redato de la restantaj dokumentoj estas la {date}."
  },
  "loan.partialReturn.outro": {
    "pt-BR": "Não esqueça de passar pela biblioteca para devolver os documentos restantes.",
    fr: "N'oublie pas de passer à la bibliothèque pour rendre les documents restants.",
    es: "No olvides pasar por la biblioteca para devolver los documentos restantes.",
    en: "Don't forget to drop by the library to return the remaining documents.",
    it: "Non dimenticare di passare in biblioteca per restituire i documenti rimanenti.",
    de: "Vergiss nicht, in der Bibliothek vorbeizuschauen, um die verbleibenden Dokumente zurückzugeben.",
    ca: "No oblidis passar per la biblioteca per retornar els documents restants.",
    eo: "Ne forgesu viziti la bibliotekon por redoni la restantajn dokumentojn."
  },
  "loan.fullyReturnedAfterPartial.sub": {
    "pt-BR": "Empréstimo concluído",
    fr: "Emprunt clôturé",
    es: "Préstamo concluido",
    en: "Loan completed",
    it: "Prestito concluso",
    de: "Ausleihe abgeschlossen",
    ca: "Préstec finalitzat",
    eo: "Prunto finita"
  },
  "loan.fullyReturnedAfterPartial.intro": {
    "pt-BR": "Você devolveu o último documento do seu empréstimo. Tudo voltou! Obrigad(o/a/e) por cuidar bem dos livros da biblioteca.",
    fr: "Tu viens de rendre le dernier document de ton emprunt. Tout est revenu ! Merci d'avoir pris soin des documents de la bibliothèque.",
    es: "Devolviste el último documento de tu préstamo. ¡Todo volvió! Gracias por cuidar de los documentos de la biblioteca.",
    en: "You've returned the last document of your loan. Everything is back! Thank you for taking good care of the library's documents.",
    it: "Hai restituito l'ultimo documento del tuo prestito. È tutto rientrato! Grazie per esserti preso/a/* cura dei documenti della biblioteca.",
    de: "Du hast das letzte Dokument deiner Ausleihe zurückgebracht. Alles ist wieder da! Danke, dass du gut auf die Dokumente der Bibliothek aufgepasst hast.",
    ca: "Has retornat l'últim document del teu préstec. Tot ha tornat! Gràcies per tenir cura dels documents de la biblioteca.",
    eo: "Vi redonis la lastan dokumenton de via prunto. Ĉio revenis! Dankon pro zorgi pri la dokumentoj de la biblioteko."
  },
  "loan.fullyReturnedAfterPartial.browse": {
    "pt-BR": "Continue navegando no acervo para suas próximas leituras.",
    fr: "Continue à explorer le fonds pour tes prochaines lectures.",
    es: "Sigue navegando el acervo para tus próximas lecturas.",
    en: "Keep browsing the collection for your next reads.",
    it: "Continua a esplorare il fondo per le tue prossime letture.",
    de: "Stöbere weiter im Bestand für deine nächste Lektüre.",
    ca: "Continua explorant el fons per a les teves properes lectures.",
    eo: "Daŭrigu esplori la fonduson por viaj sekvaj legaĵoj."
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
    eo: "Redonmemorigo"
  },
  "rem.5d": {
    "pt-BR": "Devolução em 5 dias",
    fr: "Retour dans 5 jours",
    es: "Devolución en 5 días",
    en: "Due in 5 days",
    it: "Restituzione tra 5 giorni",
    de: "Rückgabe in 5 Tagen",
    ca: "Retorn d'aquí a 5 dies",
    eo: "Redono post 5 tagoj"
  },
  "rem.5d.body": {
    "pt-BR": "Seu empréstimo vence em 5 dias",
    fr: "Ton emprunt arrive à échéance dans 5 jours",
    es: "Tu préstamo vence en 5 días",
    en: "Your loan is due in 5 days",
    it: "Il tuo prestito scade tra 5 giorni",
    de: "Deine Ausleihe läuft in 5 Tagen ab",
    ca: "El teu préstec venç d'aquí a 5 dies",
    eo: "Via prunto eksvalidiĝas post 5 tagoj"
  },
  "rem.3d": {
    "pt-BR": "Devolução em 3 dias",
    fr: "Retour dans 3 jours",
    es: "Devolución en 3 días",
    en: "Due in 3 days",
    it: "Restituzione tra 3 giorni",
    de: "Rückgabe in 3 Tagen",
    ca: "Retorn d'aquí a 3 dies",
    eo: "Redono post 3 tagoj"
  },
  "rem.3d.body": {
    "pt-BR": "Faltam 3 dias para a devolução do seu empréstimo.",
    fr: "Plus que 3 jours avant la date de retour de ton emprunt.",
    es: "Quedan 3 días para la devolución de tu préstamo.",
    en: "Only 3 days left until the return date of your loan.",
    it: "Mancano 3 giorni alla data di restituzione del tuo prestito.",
    de: "Nur noch 3 Tage bis zum Rückgabedatum deiner Ausleihe.",
    ca: "Falten 3 dies per al retorn del teu préstec.",
    eo: "Restas 3 tagoj antaŭ la redono de via prunto."
  },
  "rem.today": {
    "pt-BR": "Devolução hoje",
    fr: "Retour aujourd'hui",
    es: "Devolución hoy",
    en: "Due today",
    it: "Restituzione oggi",
    de: "Rückgabe heute",
    ca: "Retorn avui",
    eo: "Redono hodiaŭ"
  },
  "rem.today.body": {
    "pt-BR": "Sua devolução é hoje",
    fr: "Ton retour est prévu aujourd'hui",
    es: "Tu devolución es hoy",
    en: "Your return is due today",
    it: "La tua restituzione è oggi",
    de: "Deine Rückgabe ist heute fällig",
    ca: "El teu retorn és avui",
    eo: "Via redono estas hodiaŭ"
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
    eo: "Malfruavizo"
  },
  "ov.1d": {
    "pt-BR": "Empréstimo em atraso",
    fr: "Emprunt en retard",
    es: "Préstamo en retraso",
    en: "Loan overdue",
    it: "Prestito in ritardo",
    de: "Ausleihe überfällig",
    ca: "Préstec endarrerit",
    eo: "Prunto malfruita"
  },
  "ov.1d.body": {
    "pt-BR": "Seu empréstimo está em atraso desde {date}. Por favor, providencie a devolução.",
    fr: "Ton emprunt est en retard depuis le {date}. Merci de prévoir le retour ou la prolongation.",
    es: "Tu préstamo está en retraso desde el {date}. Por favor, organiza la devolución o la renovación.",
    en: "Your loan has been overdue since {date}. Please arrange the return or a renewal.",
    it: "Il tuo prestito è in ritardo dal {date}. Per favore, organizza la restituzione o il rinnovo.",
    de: "Deine Ausleihe ist seit dem {date} überfällig. Bitte sorge für die Rückgabe oder eine Verlängerung.",
    ca: "El teu préstec està endarrerit des del {date}. Si us plau, organitza el retorn o la renovació.",
    eo: "Via prunto estas malfruita ekde la {date}. Bonvolu organizi la redonon aŭ la renovigon."
  },
  "ov.7d": {
    "pt-BR": "Empréstimo com {days} dias de atraso",
    fr: "Emprunt en retard de {days} jours",
    es: "Préstamo con {days} días de retraso",
    en: "Loan {days} days overdue",
    it: "Prestito in ritardo di {days} giorni",
    de: "Ausleihe seit {days} Tagen überfällig",
    ca: "Préstec amb {days} dies de retard",
    eo: "Prunto kun {days} tagoj da malfruo"
  },
  "ov.7d.body": {
    "pt-BR": "Seu empréstimo está com {days} dias de atraso. Entre em contato com a biblioteca.",
    fr: "Ton emprunt est en retard de {days} jours. Contacte la bibliothèque pour trouver une solution.",
    es: "Tu préstamo está con {days} días de retraso. Contacta la biblioteca para encontrar una solución.",
    en: "Your loan is {days} days overdue. Contact the library to find a solution.",
    it: "Il tuo prestito è in ritardo di {days} giorni. Contatta la biblioteca per trovare una soluzione.",
    de: "Deine Ausleihe ist seit {days} Tagen überfällig. Kontaktiere die Bibliothek, um eine Lösung zu finden.",
    ca: "El teu préstec té {days} dies de retard. Contacta la biblioteca per trobar una solució.",
    eo: "Via prunto havas {days} tagojn da malfruo. Kontaktu la bibliotekon por trovi solvon."
  },
  "ov.30d": {
    "pt-BR": "Empréstimo com {days} dias de atraso — situação grave",
    fr: "Emprunt en retard de {days} jours — situation à régulariser",
    es: "Préstamo con {days} días de retraso — situación a regularizar",
    en: "Loan {days} days overdue — situation to resolve",
    it: "Prestito in ritardo di {days} giorni — situazione da regolarizzare",
    de: "Ausleihe seit {days} Tagen überfällig — Situation zu klären",
    ca: "Préstec amb {days} dies de retard — situació a regularitzar",
    eo: "Prunto kun {days} tagoj da malfruo — situacio reguligenda"
  },
  "ov.30d.body": {
    "pt-BR": "Seu empréstimo está com {days} dias de atraso. Esta situação compromete o funcionamento da biblioteca.",
    fr: "Ton emprunt est en retard de {days} jours. Cette situation pèse sur le fonctionnement collectif de la bibliothèque. Prends contact avec la biblio pour qu'on trouve ensemble comment régulariser.",
    es: "Tu préstamo está con {days} días de retraso. Esta situación afecta el funcionamiento colectivo de la biblioteca. Toma contacto con la biblio para que encontremos juntes cómo regularizar.",
    en: "Your loan is {days} days overdue. This situation affects the collective functioning of the library. Get in touch so we can find a way forward together.",
    it: "Il tuo prestito è in ritardo di {days} giorni. Questa situazione pesa sul funzionamento collettivo della biblioteca. Mettiti in contatto con la biblio per trovare insieme una soluzione.",
    de: "Deine Ausleihe ist seit {days} Tagen überfällig. Diese Situation belastet den kollektiven Betrieb der Bibliothek. Nimm Kontakt auf, damit wir gemeinsam eine Lösung finden.",
    ca: "El teu préstec té {days} dies de retard. Aquesta situació afecta el funcionament col·lectiu de la biblioteca. Posa't en contacte amb la biblioteca perquè trobem juntes com regularitzar-ho.",
    eo: "Via prunto havas {days} tagojn da malfruo. Ĉi tiu situacio pezas sur la kolektiva funkciado de la biblioteko. Kontaktu la bibliotekon por ke ni kune trovu kiel reguligi ĝin."
  },
  "ov.30d.admin": {
    "pt-BR": "Empréstimo com mais de 30 dias de atraso",
    fr: "Emprunt avec plus de 30 jours de retard",
    es: "Préstamo con más de 30 días de retraso",
    en: "Loan over 30 days overdue",
    it: "Prestito con oltre 30 giorni di ritardo",
    de: "Ausleihe seit über 30 Tagen überfällig",
    ca: "Préstec amb més de 30 dies de retard",
    eo: "Prunto kun pli ol 30 tagoj da malfruo"
  },

  // ===== Profile notices (prof.*) ===========================================
  "prof.restricted": {
    "pt-BR": "Cadastro com restrições",
    fr: "Compte avec restrictions",
    es: "Cuenta con restricciones",
    en: "Account with restrictions",
    it: "Account con restrizioni",
    de: "Konto mit Einschränkungen",
    ca: "Compte amb restriccions",
    eo: "Konto kun restriktoj"
  },
  "prof.restricted.intro": {
    "pt-BR": "Seu cadastro foi marcado com restrições.",
    fr: "Ton compte a été marqué avec des restrictions.",
    es: "Tu cuenta fue marcada con restricciones.",
    en: "Your account has been marked with restrictions.",
    it: "Il tuo account è stato segnato con restrizioni.",
    de: "Dein Konto wurde mit Einschränkungen markiert.",
    ca: "El teu compte s'ha marcat amb restriccions.",
    eo: "Via konto estis markita kun restriktoj."
  },
  "prof.contactLibrary": {
    "pt-BR": "Entre em contato com a biblioteca para regularizar sua situação.",
    fr: "Contacte la bibliothèque pour régulariser ta situation.",
    es: "Contacta la biblioteca para regularizar tu situación.",
    en: "Contact the library to resolve your situation.",
    it: "Contatta la biblioteca per regolarizzare la tua situazione.",
    de: "Kontaktiere die Bibliothek, um deine Situation zu klären.",
    ca: "Contacta la biblioteca per regularitzar la teva situació.",
    eo: "Kontaktu la bibliotekon por reguligi vian situacion."
  },
  "prof.formalNotice": {
    "pt-BR": "Aviso formal de restrição",
    fr: "Avis formel concernant la restriction",
    es: "Aviso formal sobre la restricción",
    en: "Formal notice regarding the restriction",
    it: "Avviso formale relativo alla restrizione",
    de: "Formelle Mitteilung zur Einschränkung",
    ca: "Avís formal sobre la restricció",
    eo: "Formala avizo pri la restrikto"
  },
  "prof.formalNotice.intro": {
    "pt-BR": "Esta mensagem é um aviso formal sobre a restrição d(o/a/e) seu cadastro.",
    fr: "Ce message est un avis formel concernant la restriction de ton compte.",
    es: "Este mensaje es un aviso formal sobre la restricción de tu cuenta.",
    en: "This message is a formal notice regarding the restriction on your account.",
    it: "Questo messaggio è un avviso formale relativo alla restrizione del tuo account.",
    de: "Diese Nachricht ist eine formelle Mitteilung zur Einschränkung deines Kontos.",
    ca: "Aquest missatge és un avís formal sobre la restricció del teu compte.",
    eo: "Ĉi tiu mesaĝo estas formala avizo pri la restrikto de via konto."
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
    eo: "Respondo de la legant-in-o pri la elpreno"
  },
  "pr.confirmed": {
    "pt-BR": "Leitor(a/e) confirmou o horário de retirada",
    fr: "Le·la lecteur·rice a confirmé l'horaire de retrait",
    es: "Le lector(a/e) confirmó el horario de retiro",
    en: "Reader confirmed the pickup time",
    it: "Il/la lettore/trice ha confermato l'orario di ritiro",
    de: "Leser*in hat den Abholzeitpunkt bestätigt",
    ca: "Le lector-a-e ha confirmat l'horari de recollida",
    eo: "La legant-in-o konfirmis la elpren-horon"
  },
  "pr.declined": {
    "pt-BR": "Leitor(a/e) não pode no horário proposto",
    fr: "Le·la lecteur·rice ne peut pas à l'horaire proposé",
    es: "Le lector(a/e) no puede en el horario propuesto",
    en: "Reader can't make the proposed time",
    it: "Il/la lettore/trice non può all'orario proposto",
    de: "Leser*in kann zum vorgeschlagenen Zeitpunkt nicht",
    ca: "Le lector-a-e no pot a l'horari proposat",
    eo: "La legant-in-o ne povas je la proponita horo"
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
    eo: "Nova prunto registrita"
  },
  "admin.renewalDone": {
    "pt-BR": "Prorrogação registrada",
    fr: "Prolongation enregistrée",
    es: "Renovación registrada",
    en: "Renewal recorded",
    it: "Rinnovo registrato",
    de: "Verlängerung registriert",
    ca: "Renovació registrada",
    eo: "Renovigo registrita"
  },
  "admin.returnDone": {
    "pt-BR": "Devolução registrada",
    fr: "Retour enregistré",
    es: "Devolución registrada",
    en: "Return recorded",
    it: "Restituzione registrata",
    de: "Rückgabe registriert",
    ca: "Retorn registrat",
    eo: "Redono registrita"
  },
  "admin.partialReturnDone": {
    "pt-BR": "Devolução parcial registrada",
    fr: "Retour partiel enregistré",
    es: "Devolución parcial registrada",
    en: "Partial return recorded",
    it: "Restituzione parziale registrata",
    de: "Teilrückgabe registriert",
    ca: "Retorn parcial registrat",
    eo: "Parta redono registrita"
  },
  "admin.fullyReturnedAfterPartialDone": {
    "pt-BR": "Empréstimo concluído (após devolução parcial)",
    fr: "Emprunt clôturé (après retour partiel)",
    es: "Préstamo concluido (tras devolución parcial)",
    en: "Loan completed (after partial return)",
    it: "Prestito concluso (dopo restituzione parziale)",
    de: "Ausleihe abgeschlossen (nach Teilrückgabe)",
    ca: "Préstec finalitzat (després de retorn parcial)",
    eo: "Prunto finita (post parta redono)"
  },
  "admin.returnUpdate": {
    "pt-BR": "Atualização sobre devolução",
    fr: "Mise à jour sur un retour",
    es: "Actualización sobre devolución",
    en: "Return update",
    it: "Aggiornamento su una restituzione",
    de: "Aktualisierung zu einer Rückgabe",
    ca: "Actualització sobre un retorn",
    eo: "Ĝisdatigo pri redono"
  },
  "admin.loanUpdate": {
    "pt-BR": "Atualização d(o/a/e) empréstimo",
    fr: "Mise à jour de l'emprunt",
    es: "Actualización del préstamo",
    en: "Loan update",
    it: "Aggiornamento del prestito",
    de: "Aktualisierung der Ausleihe",
    ca: "Actualització del préstec",
    eo: "Ĝisdatigo de la prunto"
  },
  "admin.resUpdate": {
    "pt-BR": "Atualização da reserva",
    fr: "Mise à jour de la réservation",
    es: "Actualización de la reserva",
    en: "Reservation update",
    it: "Aggiornamento della prenotazione",
    de: "Aktualisierung der Vormerkung",
    ca: "Actualització de la reserva",
    eo: "Ĝisdatigo de la rezervo"
  },
  "admin.profileNotice": {
    "pt-BR": "Aviso sobre cadastro",
    fr: "Avis sur un compte",
    es: "Aviso sobre cuenta",
    en: "Account notice",
    it: "Avviso su un account",
    de: "Mitteilung zu einem Konto",
    ca: "Avís sobre un compte",
    eo: "Avizo pri konto"
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
    eo: "Malferma"
  },
  "ts.a_fazer": {
    "pt-BR": "A fazer",
    fr: "À faire",
    es: "Por hacer",
    en: "To do",
    it: "Da fare",
    de: "Zu erledigen",
    ca: "Per fer",
    eo: "Farenda"
  },
  "ts.em_andamento": {
    "pt-BR": "Em andamento",
    fr: "En cours",
    es: "En progreso",
    en: "In progress",
    it: "In corso",
    de: "In Bearbeitung",
    ca: "En curs",
    eo: "En kurso"
  },
  "ts.concluida": {
    "pt-BR": "Concluída",
    fr: "Terminée",
    es: "Completada",
    en: "Completed",
    it: "Completata",
    de: "Abgeschlossen",
    ca: "Completada",
    eo: "Finita"
  },
  "ts.cancelada": {
    "pt-BR": "Cancelada",
    fr: "Annulée",
    es: "Cancelada",
    en: "Cancelled",
    it: "Annullata",
    de: "Storniert",
    ca: "Cancel·lada",
    eo: "Nuligita"
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
    eo: "Alta"
  },
  "tp.media": {
    "pt-BR": "Média",
    fr: "Moyenne",
    es: "Media",
    en: "Medium",
    it: "Media",
    de: "Mittel",
    ca: "Mitjana",
    eo: "Meza"
  },
  "tp.baixa": {
    "pt-BR": "Baixa",
    fr: "Basse",
    es: "Baja",
    en: "Low",
    it: "Bassa",
    de: "Niedrig",
    ca: "Baixa",
    eo: "Malalta"
  },
  "tp.urgente": {
    "pt-BR": "Urgente",
    fr: "Urgente",
    es: "Urgente",
    en: "Urgent",
    it: "Urgente",
    de: "Dringend",
    ca: "Urgent",
    eo: "Urĝa"
  },

  // ===== Team — Rôles dynamiques (team.role.*) ==============================
  "team.role.librarian": {
    "pt-BR": "bibliotecári(o/a/e)",
    fr: "bibliothécaire",
    es: "bibliotecarie",
    en: "librarian",
    it: "bibliotecario/a/e",
    de: "Bibliothekar*in",
    ca: "bibliotecari-ària-e",
    eo: "bibliotekist-in-o"
  },
  "team.role.coordenador": {
    "pt-BR": "coordenador(o/a/e)",
    fr: "coordinateur·rice",
    es: "coordinadore",
    en: "coordinator",
    it: "coordinatore/trice/e",
    de: "Koordinator*in",
    ca: "coordinador-a-e",
    eo: "kunordigant-in-o"
  },

  // ===== Team — Admissions concertées (team.promoted_*) =====================
  "team.promoted_to_librarian.sub": {
    "pt-BR": "Você foi admitid(o/a/e) bibliotecári(o/a/e)",
    fr: "Tu as été admis·e bibliothécaire",
    es: "Fuiste admitide bibliotecarie",
    en: "You have been admitted as a librarian",
    it: "Sei stato/a/e ammesso/a/e come bibliotecario/a/e",
    de: "Du wurdest als Bibliothekar*in aufgenommen",
    ca: "Has estat admès-a-e com a bibliotecari-ària-e",
    eo: "Vi estis akceptita kiel bibliotekist-in-o"
  },
  "team.promoted_to_librarian.intro": {
    "pt-BR": "Você acaba de ser admitid(o/a/e) bibliotecári(o/a/e) na {libraryName} de maneira concertada pela equipe de animação da biblioteca. Seja bem-vind(o/a/e)!",
    fr: "Tu viens d'être admis·e bibliothécaire à la {libraryName} de manière concertée par l'équipe d'animation de la bibliothèque. Bienvenue !",
    es: "Acabás de ser admitide bibliotecarie en le {libraryName} de manera concertada por le equipo de animación de la biblioteca. ¡Bienvenide!",
    en: "You have just been admitted as a librarian at {libraryName} through a concerted decision by the library's animation team. Welcome!",
    it: "Sei appena stato/a/e ammesso/a/e come bibliotecario/a/e a {libraryName} in modo concertato dall'equipe di animazione della biblioteca. Benvenuto/a/e!",
    de: "Du bist soeben als Bibliothekar*in bei {libraryName} in Abstimmung mit dem Animationsteam der Bibliothek aufgenommen worden. Willkommen!",
    ca: "Acabes de ser admès-a-e com a bibliotecari-ària-e a le {libraryName} de manera concertada per l'equip d'animació de la biblioteca. Benvingut-da-e!",
    eo: "Vi ĵus estis akceptita kiel bibliotekist-in-o ĉe {libraryName} interkonsente fare de la animteamo de la biblioteko. Bonvenon!"
  },
  "team.promoted_to_coordenador.sub": {
    "pt-BR": "Você foi admitid(o/a/e) coordenador(o/a/e)",
    fr: "Tu as été admis·e coordinateur·rice",
    es: "Fuiste admitide coordinadore",
    en: "You have been admitted as a coordinator",
    it: "Sei stato/a/e ammesso/a/e come coordinatore/trice/e",
    de: "Du wurdest als Koordinator*in aufgenommen",
    ca: "Has estat admès-a-e com a coordinador-a-e",
    eo: "Vi estis akceptita kiel kunordigant-in-o"
  },
  "team.promoted_to_coordenador.intro": {
    "pt-BR": "Você acaba de ser admitid(o/a/e) coordenador(o/a/e) na {libraryName} de maneira concertada. Você junta-se ao círculo de coordenação. Suas responsabilidades se ampliam: governança da equipe, validações sensíveis. O regimento interno está aqui: {regimentoUrl}",
    fr: "Tu viens d'être admis·e coordinateur·rice à la {libraryName} de manière concertée. Tu rejoins le cercle de coordination. Tes responsabilités s'élargissent : gouvernance de l'équipe, validations sensibles. Le règlement intérieur est ici : {regimentoUrl}",
    es: "Acabás de ser admitide coordinadore en le {libraryName} de manera concertada. Te sumás al círculo de coordinación. Tus responsabilidades se amplían: gobernanza de le equipo, validaciones sensibles. El reglamento interno está acá: {regimentoUrl}",
    en: "You have just been admitted as a coordinator at {libraryName} through a concerted decision. You join the coordination circle. Your responsibilities expand: team governance, sensitive validations. The internal rules are here: {regimentoUrl}",
    it: "Sei appena stato/a/e ammesso/a/e come coordinatore/trice/e a {libraryName} in modo concertato. Entri nel cerchio di coordinamento. Le tue responsabilità si ampliano: governance dell'equipe, validazioni sensibili. Il regolamento interno è qui: {regimentoUrl}",
    de: "Du bist soeben als Koordinator*in bei {libraryName} in Abstimmung aufgenommen worden. Du trittst dem Koordinationskreis bei. Deine Verantwortungen erweitern sich: Governance des Teams, sensible Validierungen. Die interne Geschäftsordnung findest du hier: {regimentoUrl}",
    ca: "Acabes de ser admès-a-e com a coordinador-a-e a le {libraryName} de manera concertada. T'incorpores al cercle de coordinació. Les teves responsabilitats s'amplien: governança de l'equip, validacions sensibles. El reglament intern és aquí: {regimentoUrl}",
    eo: "Vi ĵus estis akceptita kiel kunordigant-in-o ĉe {libraryName} interkonsente. Vi aliĝas al la kunordiga rondo. Viaj respondecoj plivastiĝas: memmastrumado de la teamo, sentemaj validigoj. La interna regularo estas ĉi tie: {regimentoUrl}"
  },

  // ===== Team — Retour volontaire à un autre rôle (team.self_demoted) =======
  "team.self_demoted.sub": {
    "pt-BR": "{actorName} retornou ao papel de {toRole}",
    fr: "{actorName} est revenu·e au rôle de {toRole}",
    es: "{actorName} volvió al rol de {toRole}",
    en: "{actorName} has returned to the {toRole} role",
    it: "{actorName} è tornato/a/e al ruolo di {toRole}",
    de: "{actorName} ist zur Rolle {toRole} zurückgekehrt",
    ca: "{actorName} ha tornat al rol de {toRole}",
    eo: "{actorName} revenis al la rolo de {toRole}"
  },
  "team.self_demoted.intro": {
    "pt-BR": "{actorName} retornou do papel de {fromRole} ao papel de {toRole} na {libraryName}. Esta decisão é voluntária e imediata.",
    fr: "{actorName} est revenu·e du rôle de {fromRole} au rôle de {toRole} à la {libraryName}. Cette décision est volontaire et immédiate.",
    es: "{actorName} volvió de le rol de {fromRole} al rol de {toRole} en le {libraryName}. Esta decisión es voluntaria e inmediata.",
    en: "{actorName} has returned from the {fromRole} role to the {toRole} role at {libraryName}. This decision is voluntary and effective immediately.",
    it: "{actorName} è tornato/a/e dal ruolo di {fromRole} al ruolo di {toRole} a {libraryName}. Questa decisione è volontaria e immediata.",
    de: "{actorName} ist von der Rolle {fromRole} zur Rolle {toRole} bei {libraryName} zurückgekehrt. Diese Entscheidung ist freiwillig und sofort wirksam.",
    ca: "{actorName} ha tornat del rol de {fromRole} al rol de {toRole} a le {libraryName}. Aquesta decisió és voluntària i immediata.",
    eo: "{actorName} revenis de la rolo de {fromRole} al la rolo de {toRole} ĉe {libraryName}. Ĉi tiu decido estas volonta kaj tuja."
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
    eo: "Forigpeto koncernanta vin"
  },
  "team.removal_requested.intro": {
    "pt-BR": "Um pedido de retirada do papel de {role} concernente a você foi depositado na {libraryName}. Este pedido está submetido a um prazo de 7 dias durante o qual você pode trocar com outr(o/a/e)s coordenador(o/a/e)s para compreender ou contestar esta decisão. Sem anulação da parte del(e/a/e)s antes de {pendingUntilDate}, seu papel de {role} será retirado.",
    fr: "Une demande de retrait du rôle de {role} te concernant a été déposée à la {libraryName}. Cette demande est soumise à un délai de 7 jours pendant lequel tu peux échanger avec les autres coordinateur·rices pour comprendre ou contester cette décision. Sans annulation de leur part avant le {pendingUntilDate}, ton rôle de {role} sera retiré.",
    es: "Une solicitud de retiro de le rol de {role} que te concierne fue depositada en le {libraryName}. Esta solicitud está sometida a un plazo de 7 días durante el cual podés intercambiar con les otres coordinadores para comprender o contestar esta decisión. Sin anulación de su parte antes de le {pendingUntilDate}, tu rol de {role} será retirado.",
    en: "A request to remove your {role} role at {libraryName} has been filed. This request is subject to a 7-day waiting period during which you may discuss with the other coordinators to understand or contest this decision. Without cancellation on their part before {pendingUntilDate}, your {role} role will be removed.",
    it: "Una richiesta di rimozione dal ruolo di {role} che ti riguarda è stata depositata a {libraryName}. Questa richiesta è soggetta a un termine di 7 giorni durante il quale puoi confrontarti con le altre coordinatrici e gli altri coordinatori per comprendere o contestare questa decisione. Senza annullamento da parte loro entro il {pendingUntilDate}, il tuo ruolo di {role} sarà rimosso.",
    de: "Ein Antrag auf Entzug der Rolle {role}, der dich betrifft, wurde bei {libraryName} eingereicht. Dieser Antrag unterliegt einer Frist von 7 Tagen, während der du dich mit den anderen Koordinator*innen austauschen kannst, um diese Entscheidung zu verstehen oder anzufechten. Ohne Annullierung ihrerseits vor dem {pendingUntilDate} wird deine Rolle als {role} entzogen.",
    ca: "S'ha presentat una sol·licitud de retirada del rol de {role} que et concerneix a le {libraryName}. Aquesta sol·licitud està sotmesa a un termini de 7 dies durant el qual pots intercanviar amb les altres coordinadores per comprendre o impugnar aquesta decisió. Sense anul·lació per part seva abans del {pendingUntilDate}, el teu rol de {role} serà retirat.",
    eo: "Forigpeto pri la rolo de {role} koncernanta vin estis deponita ĉe {libraryName}. Ĉi tiu peto estas submetita al limdato de 7 tagoj dum kiu vi povas interŝanĝi kun la aliaj kunordigant-in-oj por kompreni aŭ kontesti ĉi tiun decidon. Sen nuligo flanke de ili antaŭ la {pendingUntilDate}, via rolo de {role} estos forigita."
  },
  "team.removal_cancelled.sub": {
    "pt-BR": "O pedido de retirada concernente a você foi anulado",
    fr: "La demande de retrait te concernant a été annulée",
    es: "La solicitud de retiro que te concierne fue anulada",
    en: "The removal request concerning you has been cancelled",
    it: "La richiesta di rimozione che ti riguarda è stata annullata",
    de: "Der Antrag auf Entzug, der dich betraf, wurde annulliert",
    ca: "La sol·licitud de retirada que et concerneix s'ha anul·lat",
    eo: "La forigpeto koncernanta vin estis nuligita"
  },
  "team.removal_cancelled.intro": {
    "pt-BR": "O pedido de retirada concernente a você na {libraryName} foi anulado por {cancellerName}. Você recupera todos os seus direitos de {role} imediatamente.",
    fr: "La demande de retrait te concernant à la {libraryName} a été annulée par {cancellerName}. Tu retrouves tous tes droits de {role} immédiatement.",
    es: "La solicitud de retiro que te concierne en le {libraryName} fue anulada por {cancellerName}. Recuperás todos tus derechos de {role} inmediatamente.",
    en: "The removal request concerning you at {libraryName} has been cancelled by {cancellerName}. You immediately regain all your {role} rights.",
    it: "La richiesta di rimozione che ti riguarda a {libraryName} è stata annullata da {cancellerName}. Recuperi immediatamente tutti i tuoi diritti di {role}.",
    de: "Der Antrag auf Entzug, der dich bei {libraryName} betraf, wurde von {cancellerName} annulliert. Du erhältst sofort alle deine Rechte als {role} zurück.",
    ca: "La sol·licitud de retirada que et concerneix a le {libraryName} ha estat anul·lada per {cancellerName}. Recuperes immediatament tots els teus drets de {role}.",
    eo: "La forigpeto koncernanta vin ĉe {libraryName} estis nuligita de {cancellerName}. Vi tuj reakiras ĉiujn viajn rajtojn de {role}."
  },
  "team.removal_completed.sub": {
    "pt-BR": "Sua retirada do papel de {role} foi finalizada",
    fr: "Ton retrait du rôle de {role} a été finalisé",
    es: "Tu retiro de le rol de {role} fue finalizado",
    en: "Your removal from the {role} role has been finalised",
    it: "La tua rimozione dal ruolo di {role} è stata finalizzata",
    de: "Dein Entzug der Rolle {role} wurde abgeschlossen",
    ca: "La teva retirada del rol de {role} s'ha finalitzat",
    eo: "Via forigo el la rolo de {role} estis finita"
  },
  "team.removal_completed.intro": {
    "pt-BR": "O prazo de 7 dias decorreu sem anulação. Seu papel de {role} na {libraryName} foi retirado. Se você deseja compreender esta decisão ou discuti-la, entre em contato com (o/a/e)s coordenador(o/a/e)s.",
    fr: "Le délai de 7 jours s'est écoulé sans annulation. Ton rôle de {role} à la {libraryName} a été retiré. Si tu souhaites comprendre cette décision ou en discuter, contacte les coordinateur·rices.",
    es: "El plazo de 7 días transcurrió sin anulación. Tu rol de {role} en le {libraryName} fue retirado. Si querés comprender esta decisión o discutirla, contactá a les coordinadores.",
    en: "The 7-day period has elapsed without cancellation. Your {role} role at {libraryName} has been removed. If you wish to understand this decision or discuss it, contact the coordinators.",
    it: "Il termine di 7 giorni è trascorso senza annullamento. Il tuo ruolo di {role} a {libraryName} è stato rimosso. Se desideri comprendere questa decisione o discuterne, contatta le coordinatrici e i coordinatori.",
    de: "Die Frist von 7 Tagen ist ohne Annullierung verstrichen. Deine Rolle als {role} bei {libraryName} wurde entzogen. Wenn du diese Entscheidung verstehen oder besprechen möchtest, wende dich an die Koordinator*innen.",
    ca: "El termini de 7 dies ha transcorregut sense anul·lació. El teu rol de {role} a le {libraryName} ha estat retirat. Si vols comprendre aquesta decisió o discutir-la, contacta les coordinadores.",
    eo: "La limdato de 7 tagoj forpasis sen nuligo. Via rolo de {role} ĉe {libraryName} estis forigita. Se vi deziras kompreni ĉi tiun decidon aŭ priparoli ĝin, kontaktu la kunordigant-in-ojn."
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
    eo: "Tuja suspendo de viaj rajtoj de {role}"
  },
  "team.suspended.intro": {
    "pt-BR": "Seus direitos de {role} na {libraryName} foram suspensos por medida cautelar. Motivo comunicado: {reason}. Para compreender ou contestar esta decisão, entre em contato com (o/a/e)s coordenador(o/a/e)s o mais rápido possível.",
    fr: "Tes droits de {role} à la {libraryName} ont été suspendus par mesure conservatoire. Motif communiqué : {reason}. Pour comprendre ou contester cette décision, contacte les coordinateur·rices au plus vite.",
    es: "Tus derechos de {role} en le {libraryName} fueron suspendidos por medida cautelar. Motivo comunicado: {reason}. Para comprender o contestar esta decisión, contactá a les coordinadores lo antes posible.",
    en: "Your {role} rights at {libraryName} have been suspended as a precautionary measure. Communicated reason: {reason}. To understand or contest this decision, contact the coordinators as soon as possible.",
    it: "I tuoi diritti di {role} a {libraryName} sono stati sospesi come misura cautelare. Motivo comunicato: {reason}. Per comprendere o contestare questa decisione, contatta le coordinatrici e i coordinatori il prima possibile.",
    de: "Deine {role}-Rechte bei {libraryName} wurden als vorsorgliche Maßnahme ausgesetzt. Mitgeteilter Grund: {reason}. Um diese Entscheidung zu verstehen oder anzufechten, wende dich so schnell wie möglich an die Koordinator*innen.",
    ca: "Els teus drets de {role} a le {libraryName} han estat suspesos per mesura cautelar. Motiu comunicat: {reason}. Per comprendre o impugnar aquesta decisió, contacta les coordinadores com més aviat millor.",
    eo: "Viaj rajtoj de {role} ĉe {libraryName} estis suspenditaj kiel antaŭgarda mezuro. Komunikita motivo: {reason}. Por kompreni aŭ kontesti ĉi tiun decidon, kontaktu la kunordigant-in-ojn kiel eble plej baldaŭ."
  },
  "team.unsuspended.sub": {
    "pt-BR": "Levantamento da sua suspensão",
    fr: "Levée de ta suspension",
    es: "Levantamiento de tu suspensión",
    en: "Lifting of your suspension",
    it: "Revoca della tua sospensione",
    de: "Aufhebung deiner Aussetzung",
    ca: "Aixecament de la teva suspensió",
    eo: "Levo de via suspendo"
  },
  "team.unsuspended.intro": {
    "pt-BR": "A suspensão dos seus direitos de {role} na {libraryName} foi levantada por {actorName}. Você recupera imediatamente seus acessos.",
    fr: "La suspension de tes droits de {role} à la {libraryName} a été levée par {actorName}. Tu retrouves immédiatement tes accès.",
    es: "La suspensión de tus derechos de {role} en le {libraryName} fue levantada por {actorName}. Recuperás inmediatamente tus accesos.",
    en: "The suspension of your {role} rights at {libraryName} has been lifted by {actorName}. You immediately regain your access.",
    it: "La sospensione dei tuoi diritti di {role} a {libraryName} è stata revocata da {actorName}. Recuperi immediatamente i tuoi accessi.",
    de: "Die Aussetzung deiner {role}-Rechte bei {libraryName} wurde von {actorName} aufgehoben. Du erhältst sofort deinen Zugang zurück.",
    ca: "La suspensió dels teus drets de {role} a le {libraryName} ha estat aixecada per {actorName}. Recuperes immediatament els teus accessos.",
    eo: "La suspendo de viaj rajtoj de {role} ĉe {libraryName} estis levita de {actorName}. Vi tuj reakiras viajn alirojn."
  },

  // ===== Team — Escalades aux administrateur·rices AnarBib (team.last_*) ====
  "team.last_coordinator_left.sub": {
    "pt-BR": "{libraryName} não tem mais coordenador(o/a/e)",
    fr: "{libraryName} n'a plus de coordinateur·rice",
    es: "{libraryName} ya no tiene coordinadore",
    en: "{libraryName} no longer has a coordinator",
    it: "{libraryName} non ha più coordinatori/trici/e",
    de: "{libraryName} hat keine Koordinator*in mehr",
    ca: "{libraryName} ja no té coordinador-a-e",
    eo: "{libraryName} ne plu havas kunordigant-in-on"
  },
  "team.last_coordinator_left.intro": {
    "pt-BR": "A biblioteca {libraryName} encontra-se sem coordenador(o/a/e) ativ(o/a/e). {actorName} acaba de retornar a um papel não-coordenador, e ninguém mais ocupa o papel. A biblioteca permanece funcional tecnicamente (os bibliotecári(o/a/e)s podem continuar a operar) mas não tem mais instância de coordenação interna. Uma intervenção política da rede AnarBib é provavelmente necessária.",
    fr: "La bibliothèque {libraryName} se retrouve sans coordinateur·rice actif·ve. {actorName} vient de revenir à un rôle non-coordinateur, et personne d'autre n'occupe le rôle. La bibliothèque reste fonctionnelle techniquement (les bibliothécaires peuvent toujours opérer) mais n'a plus d'instance de coordination interne. Une intervention politique du réseau AnarBib est probablement nécessaire.",
    es: "La biblioteca {libraryName} se encuentra sin coordinadore active. {actorName} acaba de volver a un rol no-coordinadore, y nadie más ocupa el rol. La biblioteca permanece funcional técnicamente (les bibliotecaries pueden seguir operando) pero ya no tiene instancia de coordinación interna. Una intervención política de le red AnarBib es probablemente necesaria.",
    en: "The {libraryName} library finds itself without an active coordinator. {actorName} has just returned to a non-coordinator role, and no one else holds the position. The library remains technically functional (librarians can still operate) but no longer has an internal coordination body. A political intervention from the AnarBib network is likely necessary.",
    it: "La biblioteca {libraryName} si ritrova senza coordinatori/trici/e attivi/e. {actorName} è appena tornato/a/e a un ruolo non-coordinatore, e nessun'altra persona occupa il ruolo. La biblioteca rimane funzionale tecnicamente (le bibliotecarie e i bibliotecari possono continuare a operare) ma non ha più un'istanza di coordinamento interna. Un intervento politico della rete AnarBib è probabilmente necessario.",
    de: "Die Bibliothek {libraryName} steht ohne aktive Koordinator*in da. {actorName} ist soeben zu einer Nicht-Koordinator*innen-Rolle zurückgekehrt, und niemand sonst nimmt die Rolle wahr. Die Bibliothek bleibt technisch funktionsfähig (die Bibliothekar*innen können weiter arbeiten), hat aber keine interne Koordinationsinstanz mehr. Eine politische Intervention des AnarBib-Netzwerks ist wahrscheinlich notwendig.",
    ca: "La biblioteca {libraryName} es troba sense coordinador-a-e actiu-iva-e. {actorName} acaba de tornar a un rol no coordinador, i ningú més ocupa el rol. La biblioteca segueix sent funcional tècnicament (les bibliotecàries poden continuar operant) però ja no té instància de coordinació interna. Probablement cal una intervenció política de la xarxa AnarBib.",
    eo: "La biblioteko {libraryName} troviĝas sen aktiva kunordigant-in-o. {actorName} ĵus revenis al ne-kunordiga rolo, kaj neniu alia okupas la rolon. La biblioteko restas teknike funkcia (la bibliotekist-in-oj povas plu funkcii) sed ne plu havas internan kunordigan instancon. Politika interveno de la reto AnarBib estas verŝajne necesa."
  },
  "team.last_coordinator_pending_removal.sub": {
    "pt-BR": "{libraryName} corre risco de ficar sem coordenador(o/a/e)",
    fr: "{libraryName} risque de se retrouver sans coordinateur·rice",
    es: "{libraryName} corre el riesgo de quedarse sin coordinadore",
    en: "{libraryName} risks finding itself without a coordinator",
    it: "{libraryName} rischia di ritrovarsi senza coordinatori/trici/e",
    de: "{libraryName} läuft Gefahr, ohne Koordinator*in dazustehen",
    ca: "{libraryName} corre el risc de quedar-se sense coordinador-a-e",
    eo: "{libraryName} riskas resti sen kunordigant-in-o"
  },
  "team.last_coordinator_pending_removal.intro": {
    "pt-BR": "A biblioteca {libraryName} não terá mais coordenador(o/a/e) ativ(o/a/e) a partir de {pendingUntilDate} se o pedido de retirada em curso não for anulado. {actorName} pediu a retirada d(o/a/e) últim(o/a/e) coordenador(o/a/e) ativ(o/a/e) da biblioteca. Você pode observar a situação, ou intervir politicamente se necessário.",
    fr: "La bibliothèque {libraryName} aura plus de coordinateur·rice actif·ve à partir du {pendingUntilDate} si la demande de retrait en cours n'est pas annulée. {actorName} a demandé le retrait de la dernière coordinateur·rice actif·ve de la bibliothèque. Tu peux observer la situation, ou intervenir politiquement si nécessaire.",
    es: "La biblioteca {libraryName} ya no tendrá coordinadore active a partir de le {pendingUntilDate} si la solicitud de retiro en curso no es anulada. {actorName} solicitó el retiro de le última coordinadore active de la biblioteca. Podés observar la situación, o intervenir políticamente si es necesario.",
    en: "The {libraryName} library will have no active coordinator from {pendingUntilDate} onwards if the pending removal request is not cancelled. {actorName} requested the removal of the last active coordinator at the library. You may observe the situation, or intervene politically if necessary.",
    it: "La biblioteca {libraryName} non avrà più coordinatori/trici/e attivi/e a partire dal {pendingUntilDate} se la richiesta di rimozione in corso non viene annullata. {actorName} ha richiesto la rimozione dell'ultim(o/a/e) coordinator(e/trice/e) attiv(o/a/e) della biblioteca. Puoi osservare la situazione, o intervenire politicamente se necessario.",
    de: "Die Bibliothek {libraryName} wird ab dem {pendingUntilDate} keine aktive Koordinator*in mehr haben, falls der laufende Antrag auf Entzug nicht annulliert wird. {actorName} hat den Entzug der letzten aktiven Koordinator*in der Bibliothek beantragt. Du kannst die Situation beobachten oder politisch intervenieren, falls notwendig.",
    ca: "La biblioteca {libraryName} ja no tindrà coordinador-a-e actiu-iva-e a partir del {pendingUntilDate} si la sol·licitud de retirada en curs no s'anul·la. {actorName} ha sol·licitat la retirada de le darrere coordinador-a-e actiu-iva-e de la biblioteca. Pots observar la situació, o intervenir políticament si cal.",
    eo: "La biblioteko {libraryName} ne plu havos aktivan kunordigant-in-on ekde la {pendingUntilDate} se la kuranta forigpeto ne estos nuligita. {actorName} petis la forigon de la lasta aktiva kunordigant-in-o de la biblioteko. Vi povas observi la situacion, aŭ interveni politike se necese."
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
    eo: "Via konto iĝos neaktiva post 30 tagoj"
  },
  "team.inactive_warning_30d.intro": {
    "pt-BR": "Você não se conectou em AnarBib há 8 meses. Sem conexão da sua parte nos próximos 30 dias, seu status de {role} na {libraryName} passará automaticamente a inativo. Para conservar seus acessos, conecte-se simplesmente a AnarBib antes de {deadlineDate}.",
    fr: "Tu ne t'es pas connecté·e sur AnarBib depuis 8 mois. Sans connexion de ta part dans les 30 prochains jours, ton statut de {role} à la {libraryName} passera automatiquement en inactif. Pour conserver tes accès, connecte-toi simplement à AnarBib avant le {deadlineDate}.",
    es: "No te conectaste a AnarBib desde hace 8 meses. Sin conexión de tu parte en los próximos 30 días, tu estatus de {role} en le {libraryName} pasará automáticamente a inactivo. Para conservar tus accesos, conectate simplemente a AnarBib antes de le {deadlineDate}.",
    en: "You have not signed in to AnarBib for 8 months. Without a connection on your part within the next 30 days, your {role} status at {libraryName} will automatically become inactive. To keep your access, simply log in to AnarBib before {deadlineDate}.",
    it: "Non ti sei connesso/a/e ad AnarBib da 8 mesi. Senza una connessione da parte tua nei prossimi 30 giorni, il tuo status di {role} a {libraryName} passerà automaticamente a inattivo. Per conservare i tuoi accessi, connettiti semplicemente ad AnarBib prima del {deadlineDate}.",
    de: "Du hast dich seit 8 Monaten nicht mehr bei AnarBib angemeldet. Ohne Anmeldung deinerseits in den nächsten 30 Tagen wird dein Status als {role} bei {libraryName} automatisch auf inaktiv gesetzt. Um deinen Zugang zu behalten, melde dich einfach bei AnarBib vor dem {deadlineDate} an.",
    ca: "Fa 8 mesos que no et connectes a AnarBib. Sense connexió per part teva en els pròxims 30 dies, el teu estat de {role} a le {libraryName} passarà automàticament a inactiu. Per conservar els teus accessos, simplement connecta't a AnarBib abans del {deadlineDate}.",
    eo: "Vi ne konektiĝis al AnarBib de 8 monatoj. Sen konekto flanke de vi en la venontaj 30 tagoj, via stato de {role} ĉe {libraryName} aŭtomate iĝos neaktiva. Por konservi viajn alirojn, simple konektiĝu al AnarBib antaŭ la {deadlineDate}."
  },
  "team.inactive_warning_7d.sub": {
    "pt-BR": "Último lembrete: sua conta passa a inativa em 7 dias",
    fr: "Dernier rappel : ton compte passe en inactif dans 7 jours",
    es: "Último recordatorio: tu cuenta pasa a inactiva en 7 días",
    en: "Last reminder: your account becomes inactive in 7 days",
    it: "Ultimo promemoria: il tuo account passa a inattivo tra 7 giorni",
    de: "Letzte Erinnerung: Dein Konto wird in 7 Tagen inaktiv",
    ca: "Últim recordatori: el teu compte passa a inactiu d'aquí a 7 dies",
    eo: "Lasta memorigo: via konto iĝas neaktiva post 7 tagoj"
  },
  "team.inactive_warning_7d.intro": {
    "pt-BR": "Sem conexão da sua parte nos próximos 7 dias, seu status de {role} na {libraryName} passará automaticamente a inativo em {deadlineDate}.",
    fr: "Sans connexion de ta part dans les 7 prochains jours, ton statut de {role} à la {libraryName} passera automatiquement en inactif le {deadlineDate}.",
    es: "Sin conexión de tu parte en los próximos 7 días, tu estatus de {role} en le {libraryName} pasará automáticamente a inactivo el {deadlineDate}.",
    en: "Without a connection on your part within the next 7 days, your {role} status at {libraryName} will automatically become inactive on {deadlineDate}.",
    it: "Senza una connessione da parte tua nei prossimi 7 giorni, il tuo status di {role} a {libraryName} passerà automaticamente a inattivo il {deadlineDate}.",
    de: "Ohne Anmeldung deinerseits in den nächsten 7 Tagen wird dein Status als {role} bei {libraryName} am {deadlineDate} automatisch auf inaktiv gesetzt.",
    ca: "Sense connexió per part teva en els pròxims 7 dies, el teu estat de {role} a le {libraryName} passarà automàticament a inactiu el {deadlineDate}.",
    eo: "Sen konekto flanke de vi en la venontaj 7 tagoj, via stato de {role} ĉe {libraryName} aŭtomate iĝos neaktiva la {deadlineDate}."
  },
  "team.inactive_auto.sub": {
    "pt-BR": "Sua conta passou a inativa",
    fr: "Ton compte est passé en inactif",
    es: "Tu cuenta pasó a inactiva",
    en: "Your account has become inactive",
    it: "Il tuo account è passato a inattivo",
    de: "Dein Konto ist inaktiv geworden",
    ca: "El teu compte ha passat a inactiu",
    eo: "Via konto iĝis neaktiva"
  },
  "team.inactive_auto.intro": {
    "pt-BR": "Após 9 meses sem conexão, seu status de {role} na {libraryName} passou a inativo. Seus acessos estão fechados. Se você desejar recuperá-los, entre em contato com (o/a/e)s coordenador(o/a/e)s da biblioteca para uma reativação.",
    fr: "Après 9 mois sans connexion, ton statut de {role} à la {libraryName} est passé en inactif. Tes accès sont fermés. Si tu souhaites les retrouver, contacte les coordinateur·rices de la bibliothèque pour une réactivation.",
    es: "Después de 9 meses sin conexión, tu estatus de {role} en le {libraryName} pasó a inactivo. Tus accesos están cerrados. Si querés recuperarlos, contactá a les coordinadores de la biblioteca para una reactivación.",
    en: "After 9 months without a connection, your {role} status at {libraryName} has become inactive. Your access is closed. If you wish to regain it, contact the library coordinators for a reactivation.",
    it: "Dopo 9 mesi senza connessione, il tuo status di {role} a {libraryName} è passato a inattivo. I tuoi accessi sono chiusi. Se desideri recuperarli, contatta le coordinatrici e i coordinatori della biblioteca per una riattivazione.",
    de: "Nach 9 Monaten ohne Anmeldung ist dein Status als {role} bei {libraryName} auf inaktiv gesetzt worden. Dein Zugang ist geschlossen. Wenn du ihn zurückerhalten möchtest, wende dich an die Koordinator*innen der Bibliothek für eine Reaktivierung.",
    ca: "Després de 9 mesos sense connexió, el teu estat de {role} a le {libraryName} ha passat a inactiu. Els teus accessos estan tancats. Si vols recuperar-los, contacta les coordinadores de la biblioteca per a una reactivació.",
    eo: "Post 9 monatoj sen konekto, via stato de {role} ĉe {libraryName} iĝis neaktiva. Viaj aliroj estas fermitaj. Se vi deziras reakiri ilin, kontaktu la kunordigant-in-ojn de la biblioteko por reaktivigo."
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
    eo: "Interkonsentita akcepto — {role}"
  },
  "team.promoted.admin.intro": {
    "pt-BR": "{actorName} admitiu {targetName} como {role} na {libraryName}.",
    fr: "{actorName} a admis {targetName} comme {role} à la {libraryName}.",
    es: "{actorName} admitió a {targetName} como {role} en la {libraryName}.",
    en: "{actorName} admitted {targetName} as {role} at {libraryName}.",
    it: "{actorName} ha ammesso {targetName} come {role} presso {libraryName}.",
    de: "{actorName} hat {targetName} als {role} bei {libraryName} aufgenommen.",
    ca: "{actorName} ha admès {targetName} com a {role} a la {libraryName}.",
    eo: "{actorName} akceptis {targetName} kiel {role} ĉe {libraryName}."
  },
  "team.self_demoted.admin.sub": {
    "pt-BR": "Retorno voluntário ao papel de {toRole}",
    fr: "Retour volontaire au rôle de {toRole}",
    es: "Retorno voluntario al rol de {toRole}",
    en: "Voluntary return to the {toRole} role",
    it: "Ritorno volontario al ruolo di {toRole}",
    de: "Freiwillige Rückkehr zur Rolle {toRole}",
    ca: "Retorn voluntari al rol de {toRole}",
    eo: "Memvola reveno al la rolo {toRole}"
  },
  "team.self_demoted.admin.intro": {
    "pt-BR": "{actorName} retornou do papel de {fromRole} ao papel de {toRole} na {libraryName}.",
    fr: "{actorName} est revenu·e du rôle de {fromRole} au rôle de {toRole} à la {libraryName}.",
    es: "{actorName} volvió del rol de {fromRole} al rol de {toRole} en la {libraryName}.",
    en: "{actorName} stepped back from the {fromRole} role to the {toRole} role at {libraryName}.",
    it: "{actorName} è tornato/a dal ruolo di {fromRole} al ruolo di {toRole} presso {libraryName}.",
    de: "{actorName} ist von der Rolle {fromRole} zur Rolle {toRole} bei {libraryName} zurückgekehrt.",
    ca: "{actorName} ha tornat del rol de {fromRole} al rol de {toRole} a la {libraryName}.",
    eo: "{actorName} revenis de la rolo {fromRole} al la rolo {toRole} ĉe {libraryName}."
  },
  "team.removal_requested.admin.sub": {
    "pt-BR": "Pedido de retirada — {role}",
    fr: "Demande de retrait — {role}",
    es: "Solicitud de retiro — {role}",
    en: "Removal request — {role}",
    it: "Richiesta di rimozione — {role}",
    de: "Antrag auf Entzug — {role}",
    ca: "Sol·licitud de retirada — {role}",
    eo: "Forigpeto — {role}"
  },
  "team.removal_requested.admin.intro": {
    "pt-BR": "{actorName} solicitou a retirada de {targetName} do papel de {role} na {libraryName}. Prazo de carência: 7 dias.",
    fr: "{actorName} a demandé le retrait de {targetName} du rôle de {role} à la {libraryName}. Délai de carence : 7 jours.",
    es: "{actorName} solicitó el retiro de {targetName} del rol de {role} en la {libraryName}. Plazo de gracia: 7 días.",
    en: "{actorName} requested the removal of {targetName} from the {role} role at {libraryName}. Grace period: 7 days.",
    it: "{actorName} ha richiesto la rimozione di {targetName} dal ruolo di {role} presso {libraryName}. Periodo di tolleranza: 7 giorni.",
    de: "{actorName} hat den Entzug der Rolle {role} von {targetName} bei {libraryName} beantragt. Kulanzfrist: 7 Tage.",
    ca: "{actorName} ha sol·licitat la retirada de {targetName} del rol de {role} a la {libraryName}. Termini de gràcia: 7 dies.",
    eo: "{actorName} petis la forigon de {targetName} el la rolo {role} ĉe {libraryName}. Prokrastperiodo: 7 tagoj."
  },
  "team.removal_cancelled.admin.sub": {
    "pt-BR": "Pedido de retirada anulado — {role}",
    fr: "Demande de retrait annulée — {role}",
    es: "Solicitud de retiro anulada — {role}",
    en: "Removal request cancelled — {role}",
    it: "Richiesta di rimozione annullata — {role}",
    de: "Antrag auf Entzug aufgehoben — {role}",
    ca: "Sol·licitud de retirada anul·lada — {role}",
    eo: "Forigpeto nuligita — {role}"
  },
  "team.removal_cancelled.admin.intro": {
    "pt-BR": "{cancellerName} anulou o pedido de retirada de {targetName} do papel de {role} na {libraryName}. {targetName} recupera todos os direitos imediatamente.",
    fr: "{cancellerName} a annulé la demande de retrait de {targetName} du rôle de {role} à la {libraryName}. {targetName} recouvre tous ses droits immédiatement.",
    es: "{cancellerName} anuló la solicitud de retiro de {targetName} del rol de {role} en la {libraryName}. {targetName} recupera todos sus derechos de inmediato.",
    en: "{cancellerName} cancelled the removal request for {targetName} from the {role} role at {libraryName}. {targetName} regains all rights immediately.",
    it: "{cancellerName} ha annullato la richiesta di rimozione di {targetName} dal ruolo di {role} presso {libraryName}. {targetName} riacquista tutti i diritti immediatamente.",
    de: "{cancellerName} hat den Antrag auf Entzug der Rolle {role} von {targetName} bei {libraryName} aufgehoben. {targetName} erhält alle Rechte sofort zurück.",
    ca: "{cancellerName} ha anul·lat la sol·licitud de retirada de {targetName} del rol de {role} a la {libraryName}. {targetName} recupera tots els drets immediatament.",
    eo: "{cancellerName} nuligis la forigpeton de {targetName} el la rolo {role} ĉe {libraryName}. {targetName} tuj reakiras ĉiujn rajtojn."
  },
  "team.removal_completed.admin.sub": {
    "pt-BR": "Retirada finalizada — {role}",
    fr: "Retrait finalisé — {role}",
    es: "Retiro finalizado — {role}",
    en: "Removal completed — {role}",
    it: "Rimozione completata — {role}",
    de: "Entzug abgeschlossen — {role}",
    ca: "Retirada finalitzada — {role}",
    eo: "Forigo finita — {role}"
  },
  "team.removal_completed.admin.intro": {
    "pt-BR": "O prazo de 7 dias decorreu sem anulação. {targetName} foi retirad-o-a-e do papel de {role} na {libraryName}.",
    fr: "Le délai de 7 jours s’est écoulé sans annulation. {targetName} a été retiré·e du rôle de {role} à la {libraryName}.",
    es: "El plazo de 7 días transcurrió sin anulación. {targetName} fue retirad(o/a/e) del rol de {role} en la {libraryName}.",
    en: "The 7-day period elapsed without cancellation. {targetName} has been removed from the {role} role at {libraryName}.",
    it: "Il termine di 7 giorni è trascorso senza annullamento. {targetName} è stato/a rimosso/a dal ruolo di {role} presso {libraryName}.",
    de: "Die 7-Tage-Frist ist ohne Aufhebung verstrichen. {targetName} wurde von der Rolle {role} bei {libraryName} entbunden.",
    ca: "El termini de 7 dies ha transcorregut sense anul·lació. {targetName} ha estat retirat(a/e) del rol de {role} a la {libraryName}.",
    eo: "La 7-taga periodo pasis sen nuligo. {targetName} estis forigita el la rolo {role} ĉe {libraryName}."
  },
  "team.suspended.admin.sub": {
    "pt-BR": "Suspensão imediata — {role}",
    fr: "Suspension immédiate — {role}",
    es: "Suspensión inmediata — {role}",
    en: "Immediate suspension — {role}",
    it: "Sospensione immediata — {role}",
    de: "Sofortige Aussetzung — {role}",
    ca: "Suspensió immediata — {role}",
    eo: "Tuja suspendo — {role}"
  },
  "team.suspended.admin.intro": {
    "pt-BR": "{actorName} suspendeu os direitos de {role} de {targetName} na {libraryName} por medida cautelar.",
    fr: "{actorName} a suspendu les droits de {role} de {targetName} à la {libraryName} par mesure conservatoire.",
    es: "{actorName} suspendió los derechos de {role} de {targetName} en la {libraryName} como medida cautelar.",
    en: "{actorName} suspended {targetName}'s {role} rights at {libraryName} as a precautionary measure.",
    it: "{actorName} ha sospeso i diritti di {role} di {targetName} presso {libraryName} a titolo cautelare.",
    de: "{actorName} hat die {role}-Rechte von {targetName} bei {libraryName} vorsorglich ausgesetzt.",
    ca: "{actorName} ha suspès els drets de {role} de {targetName} a la {libraryName} com a mesura cautelar.",
    eo: "{actorName} suspendis la {role}-rajtojn de {targetName} ĉe {libraryName} kiel antaŭzorgan rimedon."
  },
  "team.unsuspended.admin.sub": {
    "pt-BR": "Levantamento de suspensão — {role}",
    fr: "Levée de suspension — {role}",
    es: "Levantamiento de suspensión — {role}",
    en: "Suspension lifted — {role}",
    it: "Revoca della sospensione — {role}",
    de: "Aufhebung der Aussetzung — {role}",
    ca: "Aixecament de la suspensió — {role}",
    eo: "Nuligo de suspendo — {role}"
  },
  "team.unsuspended.admin.intro": {
    "pt-BR": "{actorName} levantou a suspensão dos direitos de {role} de {targetName} na {libraryName}. Acessos restaurados.",
    fr: "{actorName} a levé la suspension des droits de {role} de {targetName} à la {libraryName}. Accès restaurés.",
    es: "{actorName} levantó la suspensión de los derechos de {role} de {targetName} en la {libraryName}. Accesos restaurados.",
    en: "{actorName} lifted the suspension of {targetName}'s {role} rights at {libraryName}. Access restored.",
    it: "{actorName} ha revocato la sospensione dei diritti di {role} di {targetName} presso {libraryName}. Accessi ripristinati.",
    de: "{actorName} hat die Aussetzung der {role}-Rechte von {targetName} bei {libraryName} aufgehoben. Zugänge wiederhergestellt.",
    ca: "{actorName} ha aixecat la suspensió dels drets de {role} de {targetName} a la {libraryName}. Accessos restaurats.",
    eo: "{actorName} nuligis la suspendon de la {role}-rajtoj de {targetName} ĉe {libraryName}. Aliroj restarigitaj."
  },
  "team.inactive_warning_7d.admin.sub": {
    "pt-BR": "Aviso de inatividade — 7 dias antes da passagem para inativo",
    fr: "Avertissement d'inactivité — 7 jours avant le passage en inactif",
    es: "Aviso de inactividad — 7 días antes del paso a inactivo",
    en: "Inactivity warning — 7 days before becoming inactive",
    it: "Avviso di inattività — 7 giorni prima del passaggio a inattivo",
    de: "Inaktivitätswarnung — 7 Tage vor dem Wechsel zu inaktiv",
    ca: "Avís d'inactivitat — 7 dies abans del pas a inactiu",
    eo: "Averto pri neaktiveco — 7 tagoj antaŭ la ŝanĝo al neaktiva"
  },
  "team.inactive_warning_7d.admin.intro": {
    "pt-BR": "{targetName} está prestes a passar para inativo (papel de {role}) na {libraryName} em {deadlineDate} se não se conectar.",
    fr: "{targetName} est sur le point de passer en inactif (rôle de {role}) à la {libraryName} le {deadlineDate} en l'absence de connexion.",
    es: "{targetName} está a punto de pasar a inactivo (rol de {role}) en la {libraryName} el {deadlineDate} si no se conecta.",
    en: "{targetName} is about to become inactive ({role} role) at {libraryName} on {deadlineDate} unless they log in.",
    it: "{targetName} sta per passare a inattivo (ruolo di {role}) presso {libraryName} il {deadlineDate} se non si connette.",
    de: "{targetName} wird bei {libraryName} am {deadlineDate} auf inaktiv gesetzt ({role}-Rolle), falls keine Anmeldung erfolgt.",
    ca: "{targetName} està a punt de passar a inactiu (rol de {role}) a la {libraryName} el {deadlineDate} si no es connecta.",
    eo: "{targetName} baldaŭ fariĝos neaktiva (rolo {role}) ĉe {libraryName} je {deadlineDate}, se ri ne ensalutos."
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
    eo: "Reta plialtigo — lasta kunordigo neaktiva: {libraryName}"
  },
  "team.inactive_warning_7d.escalation.intro": {
    "pt-BR": "{targetName}, únic-o-a-e coordenador-a-e de {libraryName}, está inativ-o-a-e e passará automaticamente para inativo em {deadlineDate} (em 7 dias). Como não há outra coordenação local para ser avisada, esta notificação é escalada à administração da rede. Sem reação, a biblioteca ficará sem coordenação ativa.",
    fr: "{targetName}, unique coordinateur·rice de {libraryName}, est inactif·ve et passera automatiquement en inactif le {deadlineDate} (dans 7 jours). Comme il n'y a pas d'autre coordination locale à prévenir, cette notification est escaladée à l'administration du réseau. Sans réaction, la bibliothèque se retrouvera sans coordination active.",
    es: "{targetName}, únic(a/e) coordinador(a/e) de {libraryName}, está inactiv(a/e) y pasará automáticamente a inactivo el {deadlineDate} (en 7 días). Como no hay otra coordinación local a la que avisar, esta notificación se escala a la administración de la red. Sin reacción, la biblioteca quedará sin coordinación activa.",
    en: "{targetName}, the only coordinator of {libraryName}, is inactive and will automatically become inactive on {deadlineDate} (in 7 days). As there is no other local coordination to notify, this notice is escalated to the network administration. Without action, the library will be left with no active coordination.",
    it: "{targetName}, unica coordinazione di {libraryName}, è inattiva e passerà automaticamente a inattivo il {deadlineDate} (tra 7 giorni). Poiché non c'è altro coordinamento locale da avvisare, questa notifica è inoltrata all'amministrazione della rete. Senza reazione, la biblioteca resterà senza coordinamento attivo.",
    de: "{targetName}, einzige Koordination von {libraryName}, ist inaktiv und wird am {deadlineDate} (in 7 Tagen) automatisch auf inaktiv gesetzt. Da es keine andere lokale Koordination zu benachrichtigen gibt, wird diese Mitteilung an die Netzwerk-Verwaltung eskaliert. Ohne Reaktion bleibt die Bibliothek ohne aktive Koordination.",
    ca: "{targetName}, únic(a/e) coordinador(a/e) de {libraryName}, està inactiv(a/e) i passarà automàticament a inactiu el {deadlineDate} (d'aquí a 7 dies). Com que no hi ha cap altra coordinació local a qui avisar, aquesta notificació s'escala a l'administració de la xarxa. Sense reacció, la biblioteca quedarà sense coordinació activa.",
    eo: "{targetName}, sola kunordiganto de {libraryName}, estas neaktiva kaj aŭtomate fariĝos neaktiva je {deadlineDate} (post 7 tagoj). Ĉar ne ekzistas alia loka kunordigo por averti, ĉi tiu sciigo estas plialtigita al la reta administrado. Sen reago, la biblioteko restos sen aktiva kunordigo."
  },
  "team.inactive_auto.admin.sub": {
    "pt-BR": "Passagem para inativo confirmada — {role}",
    fr: "Passage en inactif confirmé — {role}",
    es: "Paso a inactivo confirmado — {role}",
    en: "Transition to inactive confirmed — {role}",
    it: "Passaggio a inattivo confermato — {role}",
    de: "Wechsel zu inaktiv bestätigt — {role}",
    ca: "Pas a inactiu confirmat — {role}",
    eo: "Ŝanĝo al neaktiva konfirmita — {role}"
  },
  "team.inactive_auto.admin.intro": {
    "pt-BR": "{targetName} passou para inativo após 9 meses sem conexão (papel de {role}) na {libraryName}. Acessos fechados.",
    fr: "{targetName} est passé·e en inactif après 9 mois sans connexion (rôle de {role}) à la {libraryName}. Accès fermés.",
    es: "{targetName} pasó a inactivo tras 9 meses sin conexión (rol de {role}) en la {libraryName}. Accesos cerrados.",
    en: "{targetName} became inactive after 9 months without logging in ({role} role) at {libraryName}. Access closed.",
    it: "{targetName} è passato/a a inattivo dopo 9 mesi senza connessione (ruolo di {role}) presso {libraryName}. Accessi chiusi.",
    de: "{targetName} wurde nach 9 Monaten ohne Anmeldung auf inaktiv gesetzt ({role}-Rolle) bei {libraryName}. Zugänge geschlossen.",
    ca: "{targetName} ha passat a inactiu després de 9 mesos sense connexió (rol de {role}) a la {libraryName}. Accessos tancats.",
    eo: "{targetName} fariĝis neaktiva post 9 monatoj sen ensaluto (rolo {role}) ĉe {libraryName}. Aliroj fermitaj."
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
    eo: "Sciigo de la AnarBib-kunordigo"
  },
  "register.internal.pretitle.library": {
    "pt-BR": "Notificação da biblioteca",
    fr: "Notification de la bibliothèque",
    es: "Notificación de la biblioteca",
    en: "Library notice",
    it: "Notifica della biblioteca",
    de: "Mitteilung der Bibliothek",
    ca: "Notificació de la biblioteca",
    eo: "Sciigo de la biblioteko"
  },
  "register.internal.pretitle.management": {
    "pt-BR": "Notificação da gestão AnarBib",
    fr: "Notification de la gestion AnarBib",
    es: "Notificación de la gestión AnarBib",
    en: "AnarBib management notice",
    it: "Notifica della gestione AnarBib",
    de: "Mitteilung der AnarBib-Verwaltung",
    ca: "Notificació de la gestió AnarBib",
    eo: "Sciigo de la AnarBib-administrado"
  },
  "register.internal.title.orphan": {
    "pt-BR": "Cadastro de leitor-a-e órfã-o-e — {displayName}",
    fr: "Inscription de lecteur·rice orphelin·e — {displayName}",
    es: "Registro de lector(a/e) huérfan(a/e) — {displayName}",
    en: "Registration of an unaffiliated reader — {displayName}",
    it: "Registrazione di lettore/lettrice orfano/a — {displayName}",
    de: "Anmeldung einer noch nicht zugeordneten lesenden Person — {displayName}",
    ca: "Registre de lector(a/e) orfe(na/e) — {displayName}",
    eo: "Registriĝo de senbiblioteka leganto — {displayName}"
  },
  "register.internal.title.initial": {
    "pt-BR": "Cadastro inicial sem biblioteca — {displayName}",
    fr: "Inscription initiale sans bibliothèque — {displayName}",
    es: "Registro inicial sin biblioteca — {displayName}",
    en: "Initial registration without a library — {displayName}",
    it: "Registrazione iniziale senza biblioteca — {displayName}",
    de: "Erstanmeldung ohne Bibliothek — {displayName}",
    ca: "Registre inicial sense biblioteca — {displayName}",
    eo: "Komenca registriĝo sen biblioteko — {displayName}"
  },
  "register.internal.title.standard": {
    "pt-BR": "Novo cadastro — {displayName}",
    fr: "Nouvelle inscription — {displayName}",
    es: "Nuevo registro — {displayName}",
    en: "New registration — {displayName}",
    it: "Nuova registrazione — {displayName}",
    de: "Neue Anmeldung — {displayName}",
    ca: "Nou registre — {displayName}",
    eo: "Nova registriĝo — {displayName}"
  },
  "register.internal.subtitle.orphan": {
    "pt-BR": "Nov-o-a-e leitor-a-e órfã-o-e (biblioteca ainda não no AnarBib), ID {publicId}.",
    fr: "Nouvelle lecteur·rice orphelin·e (bibliothèque pas encore sur AnarBib), ID {publicId}.",
    es: "Nueva lectora huérfana (biblioteca aún no en AnarBib), ID {publicId}.",
    en: "New unaffiliated reader (library not yet on AnarBib), ID {publicId}.",
    it: "Nuovo/a lettore/lettrice orfano/a (biblioteca non ancora su AnarBib), ID {publicId}.",
    de: "Neue noch nicht zugeordnete lesende Person (Bibliothek noch nicht bei AnarBib), ID {publicId}.",
    ca: "Nova lectora òrfena (biblioteca encara no a AnarBib), ID {publicId}.",
    eo: "Nova senbiblioteka leganto (biblioteko ankoraŭ ne en AnarBib), ID {publicId}."
  },
  "register.internal.subtitle.initial": {
    "pt-BR": "Novo cadastro inicial sem biblioteca vinculada, com ID {publicId}.",
    fr: "Nouvelle inscription initiale sans bibliothèque rattachée, ID {publicId}.",
    es: "Nuevo registro inicial sin biblioteca vinculada, con ID {publicId}.",
    en: "New initial registration with no library attached, ID {publicId}.",
    it: "Nuova registrazione iniziale senza biblioteca collegata, ID {publicId}.",
    de: "Neue Erstanmeldung ohne zugeordnete Bibliothek, ID {publicId}.",
    ca: "Nou registre inicial sense biblioteca vinculada, amb ID {publicId}.",
    eo: "Nova komenca registriĝo sen ligita biblioteko, ID {publicId}."
  },
  "register.internal.subtitle.standard": {
    "pt-BR": "Novo cadastro de leitor-a-e com ID {publicId}.",
    fr: "Nouvelle inscription de lecteur·rice, ID {publicId}.",
    es: "Nuevo registro de lector(a/e) con ID {publicId}.",
    en: "New reader registration, ID {publicId}.",
    it: "Nuova registrazione di lettore/lettrice, ID {publicId}.",
    de: "Neue Anmeldung einer lesenden Person, ID {publicId}.",
    ca: "Nou registre de lector(a/e), amb ID {publicId}.",
    eo: "Nova registriĝo de leganto, ID {publicId}."
  },
  "register.internal.orphanLib.mentioned": {
    "pt-BR": " Biblioteca mencionada: \"{libraryName}\".",
    fr: " Bibliothèque mentionnée : « {libraryName} ».",
    es: " Biblioteca mencionada: «{libraryName}».",
    en: " Library mentioned: \"{libraryName}\".",
    it: " Biblioteca menzionata: «{libraryName}».",
    de: " Genannte Bibliothek: „{libraryName}\".",
    ca: " Biblioteca esmentada: «{libraryName}».",
    eo: " Menciita biblioteko: \"{libraryName}\"."
  },
  "register.internal.orphanLib.none": {
    "pt-BR": " Nenhuma biblioteca mencionada.",
    fr: " Aucune bibliothèque mentionnée.",
    es: " Ninguna biblioteca mencionada.",
    en: " No library mentioned.",
    it: " Nessuna biblioteca menzionata.",
    de: " Keine Bibliothek genannt.",
    ca: " Cap biblioteca esmentada.",
    eo: " Neniu biblioteko menciita."
  },
  "register.internal.testContextNote": {
    "pt-BR": "Este cadastro passou por uma rota com redirecionamento ou marcação de teste ativa.",
    fr: "Cette inscription est passée par une route avec redirection ou marquage de test actif.",
    es: "Este registro pasó por una ruta con redirección o marcado de prueba activo.",
    en: "This registration went through a route with an active redirect or test flag.",
    it: "Questa registrazione è passata per una rotta con reindirizzamento o marcatura di test attiva.",
    de: "Diese Anmeldung lief über eine Route mit aktiver Weiterleitung oder Testmarkierung.",
    ca: "Aquest registre ha passat per una ruta amb redirecció o marcatge de prova actiu.",
    eo: "Ĉi tiu registriĝo pasis tra vojo kun aktiva alidirektado aŭ testmarko."
  },
  "register.internal.subject": {
    "pt-BR": "Novo cadastro — {displayName} — {publicId}",
    fr: "Nouvelle inscription — {displayName} — {publicId}",
    es: "Nuevo registro — {displayName} — {publicId}",
    en: "New registration — {displayName} — {publicId}",
    it: "Nuova registrazione — {displayName} — {publicId}",
    de: "Neue Anmeldung — {displayName} — {publicId}",
    ca: "Nou registre — {displayName} — {publicId}",
    eo: "Nova registriĝo — {displayName} — {publicId}"
  },
  "welcome.subject": {
    "pt-BR": "Cadastro criado — {displayName}",
    fr: "Inscription créée — {displayName}",
    es: "Inscripción creada — {displayName}",
    en: "Registration created — {displayName}",
    it: "Iscrizione creata — {displayName}",
    de: "Anmeldung erstellt — {displayName}",
    ca: "Inscripció creada — {displayName}",
    eo: "Registriĝo kreita — {displayName}"
  },
  "welcome.subject.initial": {
    "pt-BR": "Cadastro inicial criado — {displayName}",
    fr: "Inscription initiale créée — {displayName}",
    es: "Inscripción inicial creada — {displayName}",
    en: "Initial registration created — {displayName}",
    it: "Iscrizione iniziale creata — {displayName}",
    de: "Anmeldung initialisiert — {displayName}",
    ca: "Inscripció inicial creada — {displayName}",
    eo: "Komenca registriĝo kreita — {displayName}"
  },
  "welcome.pretitle": {
    "pt-BR": "Cadastro criado",
    fr: "Inscription créée",
    es: "Inscripción creada",
    en: "Registration created",
    it: "Iscrizione creata",
    de: "Anmeldung erstellt",
    ca: "Inscripció creada",
    eo: "Registriĝo kreita"
  },
  "welcome.pretitle.initial": {
    "pt-BR": "Cadastro inicial criado",
    fr: "Inscription initiale créée",
    es: "Inscripción inicial creada",
    en: "Initial registration created",
    it: "Iscrizione iniziale creata",
    de: "Anmeldung initialisiert",
    ca: "Inscripció inicial creada",
    eo: "Komenca registriĝo kreita"
  },
  "welcome.title.initial": {
    "pt-BR": "Bem-vindo/a/e à rede AnarBib",
    fr: "Bienvenue dans le réseau AnarBib",
    es: "Bienvenide a la red AnarBib",
    en: "Welcome to the AnarBib network",
    it: "Benvenutə nella rete AnarBib",
    de: "Willkommen im AnarBib-Netzwerk",
    ca: "Benvingut-da-e a la xarxa AnarBib",
    eo: "Bonvenon en la reton AnarBib"
  },
   "welcome.title": {
    "pt-BR": "Bem-vindo/a/e à {libraryName}",
    fr: "Bienvenue à la {libraryName}",
    es: "Bienvenide a le {libraryName}",
    en: "Welcome to {libraryName}",
    it: "Benvenutə alla {libraryName}",
    de: "Willkommen bei {libraryName}",
    ca: "Benvingut-da-e a le {libraryName}",
    eo: "Bonvenon ĉe {libraryName}"
  },
  "welcome.subtitle": {
    "pt-BR": "Seu acesso inicial ao AnarBib já está pronto.",
    fr: "Ton accès initial à AnarBib est prêt.",
    es: "Tu acceso inicial a AnarBib ya está listo.",
    en: "Your initial access to AnarBib is ready.",
    it: "Il tuo accesso iniziale ad AnarBib è pronto.",
    de: "Dein erster Zugang zu AnarBib ist bereit.",
    ca: "El teu accés inicial a AnarBib ja està llest.",
    eo: "Via komenca aliro al AnarBib estas preta."
  },
  "welcome.greeting": {
    "pt-BR": "Olá, <b>{firstName}</b>.",
    fr: "Bonjour, <b>{firstName}</b>.",
    es: "Hola, <b>{firstName}</b>.",
    en: "Hello, <b>{firstName}</b>.",
    it: "Ciao, <b>{firstName}</b>.",
    de: "Hallo, <b>{firstName}</b>.",
    ca: "Hola, <b>{firstName}</b>.",
    eo: "Saluton, <b>{firstName}</b>."
  },
  "welcome.context.standard": {
    "pt-BR": "Seu cadastro de leitor/a/e na <b>{libraryName}</b> foi criado com sucesso.",
    fr: "Ton inscription en tant que lecteur·rice à la <b>{libraryName}</b> a été créée avec succès.",
    es: "Tu inscripción como lector(a/e) en le <b>{libraryName}</b> fue creada con éxito.",
    en: "Your reader registration at <b>{libraryName}</b> has been created successfully.",
    it: "La tua iscrizione come lettore/lettrice presso <b>{libraryName}</b> è stata creata con successo.",
    de: "Deine Leser*innen-Anmeldung bei <b>{libraryName}</b> wurde erfolgreich erstellt.",
    ca: "La teva inscripció com a lector-a-e a le <b>{libraryName}</b> s'ha creat correctament.",
    eo: "Via registriĝo kiel legant-in-o ĉe <b>{libraryName}</b> estis sukcese kreita."
  },
  "welcome.context.initial": {
    "pt-BR": "Sua conta inicial no <b>AnarBib</b> foi criada com sucesso. A próxima etapa é enviar a solicitação institucional da sua biblioteca para análise da coordenação da rede.",
    fr: "Ton compte initial sur <b>AnarBib</b> a été créé avec succès. La prochaine étape est d'envoyer la demande institutionnelle de ta bibliothèque pour analyse de la coordination du réseau.",
    es: "Tu cuenta inicial en <b>AnarBib</b> fue creada con éxito. El próximo paso es enviar la solicitud institucional de tu biblioteca para análisis de la coordinación de la red.",
    en: "Your initial account on <b>AnarBib</b> has been created successfully. The next step is to submit the institutional request for your library to the network coordination for review.",
    it: "Il tuo account iniziale su <b>AnarBib</b> è stato creato con successo. Il prossimo passo è inviare la richiesta istituzionale della tua biblioteca per l'analisi del coordinamento della rete.",
    de: "Dein erstes Konto auf <b>AnarBib</b> wurde erfolgreich erstellt. Der nächste Schritt ist, den institutionellen Antrag deiner Bibliothek zur Prüfung durch die Netzwerkkoordination einzureichen.",
    ca: "El teu compte inicial a <b>AnarBib</b> s'ha creat correctament. El pròxim pas és enviar la sol·licitud institucional de la teva biblioteca per a l'anàlisi de la coordinació de la xarxa.",
    eo: "Via komenca konto ĉe <b>AnarBib</b> estis sukcese kreita. La sekva etapo estas sendi la institucian peton de via biblioteko por analizo fare de la kunordigo de la reto."
  },
  "welcome.publicIdLabel": {
    "pt-BR": "Seu ID público",
    fr: "Ton identifiant public",
    es: "Tu identificador público",
    en: "Your public ID",
    it: "Il tuo ID pubblico",
    de: "Deine öffentliche Kennung",
    ca: "El teu ID públic",
    eo: "Via publika ID"
  },
  "welcome.tempPasswordLabel": {
    "pt-BR": "Senha provisória",
    fr: "Mot de passe provisoire",
    es: "Contraseña provisional",
    en: "Temporary password",
    it: "Password provvisoria",
    de: "Vorläufiges Passwort",
    ca: "Contrasenya provisional",
    eo: "Provizora pasvorto"
  },
  "welcome.nextAccess": {
    "pt-BR": "Nos próximos acessos ao AnarBib, entre com seu <b>ID público</b> e sua senha.",
    fr: "Pour tes prochains accès à AnarBib, connecte-toi avec ton <b>identifiant public</b> et ton mot de passe.",
    es: "En tus próximos accesos a AnarBib, ingresá con tu <b>identificador público</b> y tu contraseña.",
    en: "For your next visits to AnarBib, log in with your <b>public ID</b> and your password.",
    it: "Per i tuoi prossimi accessi ad AnarBib, accedi con il tuo <b>ID pubblico</b> e la tua password.",
    de: "Bei deinen nächsten Anmeldungen bei AnarBib verwende deine <b>öffentliche Kennung</b> und dein Passwort.",
    ca: "Per als teus pròxims accessos a AnarBib, connecta't amb el teu <b>ID públic</b> i la teva contrasenya.",
    eo: "Por viaj sekvaj aliroj al AnarBib, konektiĝu per via <b>publika ID</b> kaj via pasvorto."
  },
  "welcome.important": {
    "pt-BR": "<b>Importante:</b> a senha enviada aqui é provisória. Depois do primeiro acesso, altere-a na página <b>Conta</b>.",
    fr: "<b>Important :</b> le mot de passe envoyé ici est provisoire. Dès ton premier accès, tu seras invité·e à le changer.",
    es: "<b>Importante:</b> la contraseña enviada aquí es provisional. En tu primer acceso, se te invitará a cambiarla.",
    en: "<b>Important:</b> the password sent here is temporary. On your first login, you will be prompted to change it.",
    it: "<b>Importante:</b> la password inviata qui è provvisoria. Al primo accesso, ti verrà chiesto di cambiarla.",
    de: "<b>Wichtig:</b> Das hier gesendete Passwort ist vorläufig. Bei deiner ersten Anmeldung wirst du aufgefordert, es zu ändern.",
    ca: "<b>Important:</b> la contrasenya enviada aquí és provisional. Al teu primer accés, se t'invitarà a canviar-la.",
    eo: "<b>Grave:</b> la pasvorto sendita ĉi tie estas provizora. Ĉe via unua aliro, vi estos invitita ŝanĝi ĝin."
  },
  "welcome.forgotHint": {
    "pt-BR": "Se você perder o acesso, use o botão <b>\"Esqueci minha senha\"</b> na página de login.",
    fr: "Si tu perds l'accès, utilise le bouton <b>« Mot de passe oublié »</b> sur la page de connexion.",
    es: "Si perdés el acceso, usá el botón <b>«Olvidé mi contraseña»</b> en la página de inicio de sesión.",
    en: "If you lose access, use the <b>\"Forgot my password\"</b> button on the login page.",
    it: "Se perdi l'accesso, usa il pulsante <b>«Ho dimenticato la password»</b> nella pagina di accesso.",
    de: "Wenn du den Zugang verlierst, verwende die Schaltfläche <b>„Passwort vergessen\"</b> auf der Anmeldeseite.",
    ca: "Si perds l'accés, fes servir el botó <b>«He oblidat la contrasenya»</b> a la pàgina d'inici de sessió.",
    eo: "Se vi perdas la aliron, uzu la butonon <b>«Mi forgesis mian pasvorton»</b> en la ensaluta paĝo."
  },
  "welcome.libraryRequest.intro": {
    "pt-BR": "Use o botão abaixo para iniciar a solicitação institucional da sua biblioteca. Este link já está ligado à sua conta inicial, não precisa entrar manualmente de novo para começar.",
    fr: "Utilise le bouton ci-dessous pour initier la demande institutionnelle de ta bibliothèque. Ce lien est déjà lié à ton compte initial, tu n'as pas besoin de te reconnecter manuellement pour commencer.",
    es: "Usá el botón de abajo para iniciar la solicitud institucional de tu biblioteca. Este enlace ya está vinculado a tu cuenta inicial, no necesitás iniciar sesión manualmente otra vez para comenzar.",
    en: "Use the button below to start the institutional request for your library. This link is already tied to your initial account — no need to log in manually again to begin.",
    it: "Usa il pulsante qui sotto per avviare la richiesta istituzionale della tua biblioteca. Questo link è già collegato al tuo account iniziale, non hai bisogno di accedere manualmente di nuovo per iniziare.",
    de: "Verwende die Schaltfläche unten, um den institutionellen Antrag deiner Bibliothek zu starten. Dieser Link ist bereits mit deinem ersten Konto verknüpft — du musst dich nicht erneut manuell anmelden, um zu beginnen.",
    ca: "Fes servir el botó de sota per iniciar la sol·licitud institucional de la teva biblioteca. Aquest enllaç ja està vinculat al teu compte inicial, no cal que tornis a iniciar sessió manualment per començar.",
    eo: "Uzu la suban butonon por komenci la institucian peton de via biblioteko. Ĉi tiu ligilo jam estas ligita al via komenca konto, vi ne bezonas reensaluti permane por komenci."
  },
  "welcome.libraryRequest.cta": {
    "pt-BR": "Iniciar solicitação da biblioteca",
    fr: "Démarrer la demande de bibliothèque",
    es: "Iniciar solicitud de la biblioteca",
    en: "Start the library request",
    it: "Avviare la richiesta della biblioteca",
    de: "Antrag der Bibliothek starten",
    ca: "Iniciar la sol·licitud de la biblioteca",
    eo: "Komenci la peton de la biblioteko"
  },
  "welcome.libraryRequest.fallback": {
    "pt-BR": "Se o link expirar, entre em contato com a coordenação do AnarBib para receber um novo acesso.",
    fr: "Si le lien expire, contacte la coordination d'AnarBib pour recevoir un nouvel accès.",
    es: "Si el enlace expira, contactá a la coordinación de AnarBib para recibir un nuevo acceso.",
    en: "If the link expires, contact the AnarBib coordination to receive a new access.",
    it: "Se il link scade, contatta il coordinamento di AnarBib per ricevere un nuovo accesso.",
    de: "Wenn der Link abläuft, wende dich an die AnarBib-Koordination, um einen neuen Zugang zu erhalten.",
    ca: "Si l'enllaç expira, contacta la coordinació d'AnarBib per rebre un accés nou.",
    eo: "Se la ligilo eksvalidiĝas, kontaktu la kunordigon de AnarBib por ricevi novan aliron."
  },
  "welcome.libraryAddressLabel": {
    "pt-BR": "Endereço da biblioteca:",
    fr: "Adresse de la bibliothèque :",
    es: "Dirección de la biblioteca:",
    en: "Library address:",
    it: "Indirizzo della biblioteca:",
    de: "Adresse der Bibliothek:",
    ca: "Adreça de la biblioteca:",
    eo: "Adreso de la biblioteko:"
  },
  "welcome.libraryContactLabel": {
    "pt-BR": "Contato da biblioteca:",
    fr: "Contact de la bibliothèque :",
    es: "Contacto de la biblioteca:",
    en: "Library contact:",
    it: "Contatto della biblioteca:",
    de: "Kontakt der Bibliothek:",
    ca: "Contacte de la biblioteca:",
    eo: "Kontakto de la biblioteko:"
  },
  "welcome.autoMessage": {
    "pt-BR": "Mensagem automática do cadastro AnarBib. As respostas a este e-mail serão encaminhadas para a gestão do projeto.",
    fr: "Message automatique de l'inscription AnarBib. Les réponses à cet e-mail sont transmises à la gestion du projet.",
    es: "Mensaje automático del registro AnarBib. Las respuestas a este correo serán reenviadas a la gestión del proyecto.",
    en: "Automatic message from the AnarBib registration. Replies to this email are forwarded to the project management.",
    it: "Messaggio automatico dell'iscrizione AnarBib. Le risposte a questa e-mail vengono inoltrate alla gestione del progetto.",
    de: "Automatische Nachricht der AnarBib-Anmeldung. Antworten auf diese E-Mail werden an die Projektleitung weitergeleitet.",
    ca: "Missatge automàtic de la inscripció AnarBib. Les respostes a aquest correu es transmeten a la gestió del projecte.",
    eo: "Aŭtomata mesaĝo de la registriĝo AnarBib. La respondoj al ĉi tiu retpoŝto estas plusenditaj al la projektmastrumado."
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
    eo: "Konto kreita"
  },
  "welcome.title.orphan": {
    "pt-BR": "Bem-vind-a-e ao AnarBib",
    fr: "Bienvenue dans le réseau AnarBib",
    es: "Bienvenide a la red AnarBib",
    en: "Welcome to the AnarBib network",
    it: "Benvenut* nella rete AnarBib",
    de: "Willkommen im AnarBib-Netzwerk",
    ca: "Benvingut-da-e a la xarxa AnarBib",
    eo: "Bonvenon en la reton AnarBib"
  },
  "welcome.subject.orphan": {
    "pt-BR": "Sua conta no AnarBib foi criada",
    fr: "Ton compte AnarBib a été créé",
    es: "Tu cuenta de AnarBib fue creada",
    en: "Your AnarBib account has been created",
    it: "Il tuo account AnarBib è stato creato",
    de: "Dein AnarBib-Konto wurde erstellt",
    ca: "El teu compte d'AnarBib s'ha creat",
    eo: "Via konto ĉe AnarBib estis kreita"
  },
  "welcome.context.orphan": {
    "pt-BR": "Sua conta foi criada. Como você nos indicou, sua biblioteca ainda não está na rede AnarBib. Fale do AnarBib com a equipe da sua biblioteca: se essa decidir aderir, você poderá ser integrad-a-e como leitor-a-e com a mesma conta que acaba de criar. Enquanto isso, você pode explorar livremente os catálogos das bibliotecas que escolheram torná-los públicos.",
    fr: "Ton compte a été créé. Comme tu nous l'as indiqué, ta bibliothèque n'est pas encore dans le réseau AnarBib. Parle d'AnarBib à l'équipe de ta bibliothèque : si elle décide d'adhérer, tu pourras y être intégré·e comme lecteur·rice avec le compte que tu viens de créer. En attendant, tu peux explorer librement les catalogues des bibliothèques qui ont choisi de les rendre publics.",
    es: "Tu cuenta fue creada. Como nos indicaste, tu biblioteca todavía no está en la red AnarBib. Hablá de AnarBib con el equipo de tu biblioteca: si este decide sumarse, vas a poder ser integrade como lectore con la misma cuenta que acabás de crear. Mientras tanto, podés explorar libremente los catálogos de las bibliotecas que eligieron hacerlos públicos.",
    en: "Your account has been created. As you told us, your library is not yet part of the AnarBib network. Talk about AnarBib with your library's team: if it decides to join, you'll be able to be added as a reader with the same account you've just created. In the meantime, you can freely explore the catalogues of the libraries that have chosen to make them public.",
    it: "Il tuo account è stato creato. Come ci hai indicato, la tua biblioteca non fa ancora parte della rete AnarBib. Parla di AnarBib con l'équipe della tua biblioteca: se questa decide di aderire, potrai essere integrat* come lettore* con lo stesso account che hai appena creato. Nel frattempo, puoi esplorare liberamente i cataloghi delle biblioteche che hanno scelto di renderli pubblici.",
    de: "Dein Konto wurde erstellt. Wie du uns mitgeteilt hast, gehört deine Bibliothek noch nicht zum AnarBib-Netzwerk. Sprich mit dem Team deiner Bibliothek über AnarBib: wenn es sich entscheidet beizutreten, kannst du als Leser*in mit demselben Konto, das du gerade erstellt hast, aufgenommen werden. In der Zwischenzeit kannst du die Kataloge der Bibliotheken, die sie öffentlich gemacht haben, frei durchstöbern.",
    ca: "El teu compte s'ha creat. Tal com ens vas indicar, la teva biblioteca encara no forma part de la xarxa AnarBib. Parla d'AnarBib amb l'equip de la teva biblioteca: si aquest decideix adherir-s'hi, podràs ser integrat-da-e com a lector-a-e amb el mateix compte que acabes de crear. Mentrestant, pots explorar lliurement els catàlegs de les biblioteques que han decidit fer-los públics.",
    eo: "Via konto estis kreita. Kiel vi indikis al ni, via biblioteko ankoraŭ ne apartenas al la reto AnarBib. Parolu pri AnarBib kun la teamo de via biblioteko: se ĝi decidas aliĝi, vi povos esti integrit-in-e kiel legant-in-e per la sama konto kiun vi ĵus kreis. Dume, vi povas libere esplori la katalogojn de la bibliotekoj kiuj elektis publikigi ilin."
  },
  "welcome.orphan.exploreCta": {
    "pt-BR": "→ Explorar os catálogos",
    fr: "→ Explorer les catalogues",
    es: "→ Explorar los catálogos",
    en: "→ Explore the catalogues",
    it: "→ Esplora i cataloghi",
    de: "→ Kataloge durchstöbern",
    ca: "→ Explorar els catàlegs",
    eo: "→ Esplori la katalogojn"
  },
  "welcome.orphan.aboutIntro": {
    "pt-BR": "Para saber mais sobre o projeto AnarBib e como sua biblioteca pode aderir, acesse:",
    fr: "Pour en savoir plus sur le projet AnarBib et comment ta bibliothèque peut adhérer, rends-toi sur :",
    es: "Para saber más sobre el proyecto AnarBib y cómo tu biblioteca puede sumarse, entrá en:",
    en: "To learn more about the AnarBib project and how your library can join, go to:",
    it: "Per saperne di più sul progetto AnarBib e su come la tua biblioteca può aderire, vai su:",
    de: "Um mehr über das AnarBib-Projekt zu erfahren und wie deine Bibliothek beitreten kann, geh auf:",
    ca: "Per saber-ne més sobre el projecte AnarBib i com pot adherir-s'hi la teva biblioteca, vés a:",
    eo: "Por scii pli pri la projekto AnarBib kaj kiel via biblioteko povas aliĝi, iru al:"
  },
  "welcome.orphan.fallback": {
    "pt-BR": "Se o botão não funcionar, copie este endereço no seu navegador:",
    fr: "Si le bouton ne fonctionne pas, copie cette adresse dans ton navigateur :",
    es: "Si el botón no funciona, copiá esta dirección en tu navegador:",
    en: "If the button doesn't work, copy this address into your browser:",
    it: "Se il pulsante non funziona, copia questo indirizzo nel tuo browser:",
    de: "Wenn der Button nicht funktioniert, kopiere diese Adresse in deinen Browser:",
    ca: "Si el botó no funciona, copia aquesta adreça al teu navegador:",
    eo: "Se la butono ne funkcias, kopiu ĉi tiun adreson en vian retumilon:"
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
//   it    : compagno/a/e
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
    eo: "Saluton, {proposerName}. Via kooptad-propono pri {targetName} ankoraŭ ne ricevis sufiĉe da voĉdonoj. La propono eksvalidiĝas la {expiresAt}. Vi povas sekvi ĝian progreson en via administra spaco."
  },
  "network.cooptation_reminder.sub": {
    "pt-BR": "Lembrete : votação pendente sobre a cooptação de {proposedName}",
    fr: "Rappel · vote en attente sur la cooptation de {proposedName}",
    es: "Recordatorio · votación pendiente sobre la cooptación de {proposedName}",
    en: "Reminder · pending vote on the cooptation of {proposedName}",
    it: "Promemoria · voto in sospeso sulla cooptazione di {proposedName}",
    de: "Erinnerung · ausstehende Abstimmung zur Kooptation von {proposedName}",
    ca: "Recordatori · votació pendent sobre la cooptació de {proposedName}",
    eo: "Memorigo · atendanta voĉdono pri la kooptado de {proposedName}"
  },
  "network.cooptation_reminder.intro": {
    "pt-BR": "Uma proposta de cooptação foi aberta há vários dias e ainda aguarda vossa decisão. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s é necessária para concluir o processo.",
    fr: "Une proposition de cooptation a été ouverte il y a plusieurs jours et attend encore votre décision. L'unanimité des administrateur·rices actif·ves est nécessaire pour conclure le processus.",
    es: "Una propuesta de cooptación fue abierta hace varios días y aún espera vuestra decisión. La unanimidad de les administradores activos es necesaria para cerrar el proceso.",
    en: "A cooptation proposal was opened several days ago and is still awaiting your decision. Unanimity among active network administrators is required to complete the process.",
    it: "Una proposta di cooptazione è stata aperta diversi giorni fa e attende ancora la vostra decisione. L'unanimità dei compagni/e amministratori/e attivi/e è necessaria per concludere il processo.",
    de: "Ein Kooptationsvorschlag wurde vor mehreren Tagen eröffnet und wartet noch auf Ihre Entscheidung. Einstimmigkeit der aktiven Netzwerk-Administrator*innen ist erforderlich, um den Prozess abzuschließen.",
    ca: "S'ha obert una proposta de cooptació fa diversos dies i encara espera la vostra decisió. La unanimitat de les administradores actives és necessària per concloure el procés.",
    eo: "Kooptad-propono estis malfermita antaŭ pluraj tagoj kaj ankoraŭ atendas vian decidon. La unuanimeco de la aktivaj administrant-in-oj estas necesa por konkludi la procezon."
  },
  "network.cooptation_reminder.cta": {
    "pt-BR": "Acessar a proposta e votar",
    fr: "Accéder à la proposition et voter",
    es: "Acceder a la propuesta y votar",
    en: "Open the proposal and vote",
    it: "Accedere alla proposta e votare",
    de: "Vorschlag öffnen und abstimmen",
    ca: "Accedir a la proposta i votar",
    eo: "Aliri la proponon kaj voĉdoni"
  },
  "network.cooptation_reminder.deadline_label": {
    "pt-BR": "A proposta expira em {pendingDeadline}.",
    fr: "La proposition expire le {pendingDeadline}.",
    es: "La propuesta expira el {pendingDeadline}.",
    en: "The proposal expires on {pendingDeadline}.",
    it: "La proposta scade il {pendingDeadline}.",
    de: "Der Vorschlag läuft am {pendingDeadline} ab.",
    ca: "La proposta expira el {pendingDeadline}.",
    eo: "La propono eksvalidiĝas la {pendingDeadline}."
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
    eo: "Propono de kolektiva forigo · {proposedName}"
  },
  "network.collective_removal_proposed.intro": {
    "pt-BR": "{proposerName} abriu uma proposta de retirada coletiva d(o/a/e) administrador(a/e) {proposedName}. Esta é uma decisão política grave que exige unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s (excluíd(o/a/e) (o/a/e) próprio(a/e) target). Vosso voto é necessário.",
    fr: "{proposerName} a ouvert une proposition de retrait collectif de l'administrateur·rice {proposedName}. Il s'agit d'une décision politique grave qui requiert l'unanimité des administrateur·rices actif·ves (à l'exclusion de la personne ciblée). Votre vote est nécessaire.",
    es: "{proposerName} abrió una propuesta de retiro colectivo de le administrade {proposedName}. Es una decisión política grave que exige la unanimidad de les administradores activos (excluide le propie target). Vuestro voto es necesario.",
    en: "{proposerName} has opened a proposal for the collective removal of network administrator {proposedName}. This is a serious political decision requiring unanimity among active administrators (excluding the target). Your vote is needed.",
    it: "{proposerName} ha aperto una proposta di ritiro collettivo dell'amministratore/trice/e {proposedName}. È una decisione politica grave che richiede l'unanimità dei compagni/e amministratori/e attivi/e (escluso/a/e (il/la/le) compagno/a/e oggetto). Il vostro voto è necessario.",
    de: "{proposerName} hat einen Vorschlag zum kollektiven Rückzug von Netzwerk-Administrator*in {proposedName} eröffnet. Dies ist eine schwerwiegende politische Entscheidung, die die Einstimmigkeit der aktiven Administrator*innen erfordert (ausgenommen die betroffene Person). Ihre Stimme ist erforderlich.",
    ca: "{proposerName} ha obert una proposta de retirada col·lectiva de l'administrador-a-e {proposedName}. Es tracta d'una decisió política greu que requereix la unanimitat de les administradores actives (excloent la persona objecte de la proposta). El vostre vot és necessari.",
    eo: "{proposerName} malfermis proponon de kolektiva forigo de la administrant-in-o {proposedName}. Temas pri grava politika decido kiu postulas la unuanimecon de la aktivaj administrant-in-oj (escepte de la celata persono). Via voĉdono estas necesa."
  },
  "network.collective_removal_proposed.cta": {
    "pt-BR": "Acessar a proposta e votar",
    fr: "Accéder à la proposition et voter",
    es: "Acceder a la propuesta y votar",
    en: "Open the proposal and vote",
    it: "Accedere alla proposta e votare",
    de: "Vorschlag öffnen und abstimmen",
    ca: "Accedir a la proposta i votar",
    eo: "Aliri la proponon kaj voĉdoni"
  },
  "network.collective_removal_proposed.motivation_label": {
    "pt-BR": "Motivação invocada :",
    fr: "Motivation invoquée :",
    es: "Motivación invocada :",
    en: "Stated motivation:",
    it: "Motivazione invocata :",
    de: "Angegebene Begründung:",
    ca: "Motivació invocada:",
    eo: "Invokita motivo:"
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
    eo: "Voĉdono registrita · kolektiva forigo de {proposedName}"
  },
  "network.collective_removal_vote_cast.intro": {
    "pt-BR": "Um(a/e) administrador(a/e) de rede acaba de votar sobre a proposta de retirada coletiva d(o/a/e) administrador(a/e) {proposedName}, aberta por {proposerName}. Acessai a app para ver o estado atual da deliberação e votar.",
    fr: "Un·e administrateur·rice du réseau vient de voter sur la proposition de retrait collectif de l'administrateur·rice {proposedName}, ouverte par {proposerName}. Accédez à l'app pour voir l'état actuel de la délibération et voter.",
    es: "Une administrade de red acaba de votar sobre la propuesta de retiro colectivo de le administrade {proposedName}, abierta por {proposerName}. Accedé a la app para ver el estado actual de la deliberación y votar.",
    en: "A network administrator has just cast a vote on the collective removal proposal of administrator {proposedName}, opened by {proposerName}. Open the app to see the current state of the deliberation and vote.",
    it: "Un compagno/a/e amministratore/trice/e di rete ha appena votato sulla proposta di ritiro collettivo dell'amministratore/trice/e {proposedName}, aperta da {proposerName}. Accedi all'app per vedere lo stato attuale della deliberazione e votare.",
    de: "Ein*e Netzwerk-Administrator*in hat soeben über den Vorschlag eines kollektiven Rückzugs von Administrator*in {proposedName} abgestimmt, eröffnet von {proposerName}. Öffnen Sie die App, um den aktuellen Stand der Beratung zu sehen und abzustimmen.",
    ca: "Una administradora de xarxa acaba de votar sobre la proposta de retirada col·lectiva de l'administrador-a-e {proposedName}, oberta per {proposerName}. Accediu a l'aplicació per veure l'estat actual de la deliberació i votar.",
    eo: "Reta administrant-in-o ĵus voĉdonis pri la propono de kolektiva forigo de la administrant-in-o {proposedName}, malfermita de {proposerName}. Aliru la aplikaĵon por vidi la nunan staton de la pridiskuto kaj voĉdoni."
  },
  "network.collective_removal_vote_cast.rationale_label": {
    "pt-BR": "Motivo do voto contrário :",
    fr: "Motif du vote défavorable :",
    es: "Motivo del voto contrario :",
    en: "Reason for opposing vote:",
    it: "Motivo del voto contrario :",
    de: "Begründung der Ablehnung:",
    ca: "Motiu del vot contrari:",
    eo: "Motivo de la kontraŭa voĉdono:"
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
    eo: "Kolektiva forigo konfirmita unuanime · {proposedName} — grac-periodo de 7 tagoj"
  },
  "network.collective_removal_unanimous.intro": {
    "pt-BR": "A unanimidade d(o/a/e)s administrador(a/e)s foi alcançada sobre a retirada coletiva d(o/a/e) {proposedName}. Uma carência de 7 dias se aplica antes da efetivação. Durante este período, qualquer votante pode anular a decisão se houver mudança de posição coletiva.",
    fr: "L'unanimité des administrateur·rices a été atteinte sur le retrait collectif de {proposedName}. Une carence de 7 jours s'applique avant exécution. Pendant cette période, tout·e votant·e peut annuler la décision en cas de changement de position collective.",
    es: "Se alcanzó la unanimidad de les administradores sobre el retiro colectivo de {proposedName}. Se aplica un período de gracia de 7 días antes de la ejecución. Durante este período, cualquier votante puede anular la decisión si hay un cambio de posición colectiva.",
    en: "Unanimity among network administrators has been reached on the collective removal of {proposedName}. A 7-day grace period applies before execution. During this period, any voter may cancel the decision if the collective position changes.",
    it: "L'unanimità dei compagni/e amministratori/e è stata raggiunta sul ritiro collettivo di {proposedName}. Si applica un periodo di grazia di 7 giorni prima dell'esecuzione. Durante questo periodo, qualsiasi votante può annullare la decisione in caso di cambiamento di posizione collettiva.",
    de: "Einstimmigkeit der Netzwerk-Administrator*innen über den kollektiven Rückzug von {proposedName} wurde erreicht. Eine 7-tägige Karenzfrist gilt vor der Vollziehung. Während dieser Frist kann jede*r Abstimmende die Entscheidung aufheben, falls sich die kollektive Position ändert.",
    ca: "S'ha assolit la unanimitat de les administradores sobre la retirada col·lectiva de {proposedName}. S'aplica un termini de gràcia de 7 dies abans de l'execució. Durant aquest període, qualsevol votant pot anul·lar la decisió si hi ha un canvi de posició col·lectiva.",
    eo: "La unuanimeco de la administrant-in-oj estis atingita pri la kolektiva forigo de {proposedName}. Grac-periodo de 7 tagoj validas antaŭ la plenumo. Dum ĉi tiu periodo, ĉiu voĉdoninto povas nuligi la decidon en kazo de ŝanĝo de kolektiva pozicio."
  },
  "network.collective_removal_unanimous.target_intro": {
    "pt-BR": "Esta mensagem informa que a unanimidade d(o/a/e)s outr(o/a/e)s administrador(a/e)s ativ(o/a/e)s foi alcançada sobre a vossa retirada coletiva. Uma carência de 7 dias se aplica antes da efetivação. Vossa palavra é livre durante esta janela.",
    fr: "Ce message vous informe que l'unanimité des autres administrateur·rices actif·ves a été atteinte sur votre retrait collectif. Une carence de 7 jours s'applique avant exécution. Votre parole est libre durant cette fenêtre.",
    es: "Este mensaje le informa que se alcanzó la unanimidad de les otres administradores activos sobre vuestro retiro colectivo. Se aplica un período de gracia de 7 días antes de la ejecución. Vuestra palabra es libre durante esta ventana.",
    en: "This message informs you that unanimity among the other active network administrators has been reached regarding your collective removal. A 7-day grace period applies before execution. Your voice remains free during this window.",
    it: "Questo messaggio vi informa che l'unanimità degli/delle altr(i/e/u) compagn(i/e/u) amministratori/e attivi/e è stata raggiunta sul vostro ritiro collettivo. Si applica un periodo di grazia di 7 giorni prima dell'esecuzione. La vostra parola resta libera durante questa finestra.",
    de: "Diese Nachricht informiert Sie darüber, dass die Einstimmigkeit der anderen aktiven Netzwerk-Administrator*innen über Ihren kollektiven Rückzug erreicht wurde. Eine 7-tägige Karenzfrist gilt vor der Vollziehung. Ihr Wort bleibt frei während dieses Zeitraums.",
    ca: "Aquest missatge us informa que s'ha assolit la unanimitat de les altres administradores actives sobre la vostra retirada col·lectiva. S'aplica un termini de gràcia de 7 dies abans de l'execució. La vostra paraula és lliure durant aquesta finestra.",
    eo: "Ĉi tiu mesaĝo informas vin ke la unuanimeco de la aliaj aktivaj administrant-in-oj estis atingita pri via kolektiva forigo. Grac-periodo de 7 tagoj validas antaŭ la plenumo. Via parolo estas libera dum ĉi tiu fenestro."
  },
  "network.collective_removal_unanimous.carence_label": {
    "pt-BR": "Período de carência : a execução efetiva ocorrerá em {executionDate}.",
    fr: "Période de carence : l'exécution effective interviendra le {executionDate}.",
    es: "Período de carencia : la ejecución efectiva ocurrirá el {executionDate}.",
    en: "Grace period: effective execution will occur on {executionDate}.",
    it: "Periodo di carenza : l'esecuzione effettiva avverrà il {executionDate}.",
    de: "Karenzzeit: die tatsächliche Ausführung erfolgt am {executionDate}.",
    ca: "Període de gràcia: l'execució efectiva tindrà lloc el {executionDate}.",
    eo: "Grac-periodo: la efektiva plenumo okazos la {executionDate}."
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
    eo: "Motivo de la nuligo:"
  },
  "network.collective_removal_cancelled.sub": {
    "pt-BR": "Retirada coletiva cancelada : {proposedName}",
    fr: "Retrait collectif annulé · {proposedName}",
    es: "Retiro colectivo cancelado · {proposedName}",
    en: "Collective removal cancelled · {proposedName}",
    it: "Ritiro collettivo annullato · {proposedName}",
    de: "Kollektiver Rückzug abgebrochen · {proposedName}",
    ca: "Retirada col·lectiva anul·lada · {proposedName}",
    eo: "Kolektiva forigo nuligita · {proposedName}"
  },
  "network.collective_removal_cancelled.target_intro": {
    "pt-BR": "Olá, {targetName}. A proposta de retirada coletiva que tinha sido aberta sobre você foi anulada. Você permanece administrador·a ativo·a da rede AnarBib. Esta decisão é coletiva e política.",
    fr: "Bonjour {targetName}. La proposition de retrait collectif qui avait été ouverte à ton sujet a été annulée. Tu restes administrateur·rice actif·ve du réseau AnarBib. Cette décision est collective et politique.",
    es: "Hola, {targetName}. La propuesta de retiro colectivo que se había abierto sobre vos fue anulada. Seguís siendo administrador·a activo·a de la red AnarBib. Esta decisión es colectiva y política.",
    en: "Hello {targetName}. The collective removal proposal that had been opened concerning you has been cancelled. You remain an active administrator of the AnarBib network. This decision is collective and political.",
    it: "Ciao {targetName}. La proposta di rimozione collettiva aperta nei tuoi confronti è stata annullata. Resti amministratore/trice attivo/a della rete AnarBib. Questa decisione è collettiva e politica.",
    de: "Hallo {targetName}. Der kollektive Entzugsvorschlag, der dich betraf, wurde annulliert. Du bleibst aktive*r Administrator*in des AnarBib-Netzwerks. Diese Entscheidung ist kollektiv und politisch.",
    ca: "Hola, {targetName}. La proposta de retirada col·lectiva que s'havia obert sobre tu ha estat anul·lada. Continues sent administrador-a-e actiu-iva-e de la xarxa AnarBib. Aquesta decisió és col·lectiva i política.",
    eo: "Saluton, {targetName}. La propono de kolektiva forigo kiu estis malfermita pri vi estis nuligita. Vi restas aktiva administrant-in-o de la reto AnarBib. Ĉi tiu decido estas kolektiva kaj politika."
  },
  "network.collective_removal_cancelled.intro": {
    "pt-BR": "A proposta de retirada coletiva d(o/a/e) {proposedName} foi anulada. Nenhuma efetivação será realizada. Esta decisão é registrada no histórico militante da rede.",
    fr: "La proposition de retrait collectif de {proposedName} a été annulée. Aucune exécution ne sera réalisée. Cette décision est consignée dans l'historique militant du réseau.",
    es: "La propuesta de retiro colectivo de {proposedName} fue cancelada. No se realizará ninguna ejecución. Esta decisión queda registrada en el historial militante de la red.",
    en: "The collective removal proposal for {proposedName} has been cancelled. No execution will occur. This decision is recorded in the militant history of the network.",
    it: "La proposta di ritiro collettivo di {proposedName} è stata annullata. Nessuna esecuzione avrà luogo. Questa decisione è registrata nella storia militante della rete.",
    de: "Der Vorschlag zum kollektiven Rückzug von {proposedName} wurde abgebrochen. Es erfolgt keine Vollziehung. Diese Entscheidung wird in der militanten Geschichte des Netzwerks festgehalten.",
    ca: "La proposta de retirada col·lectiva de {proposedName} ha estat anul·lada. No es realitzarà cap execució. Aquesta decisió queda registrada a l'historial militant de la xarxa.",
    eo: "La propono de kolektiva forigo de {proposedName} estis nuligita. Neniu plenumo okazos. Ĉi tiu decido estas registrita en la aktivisma historio de la reto."
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
    eo: "Kolektiva forigo plenumita · {proposedName}"
  },
  "network.collective_removal_executed.intro": {
    "pt-BR": "Após o término da carência de 7 dias, a retirada coletiva d(o/a/e) {proposedName} foi efetivada. Esta pessoa não tem mais o papel d(o/a/e) administrador(a/e) de rede. A decisão é registrada no histórico militante d(o/a/e) AnarBib.",
    fr: "À l'issue de la carence de 7 jours, le retrait collectif de {proposedName} a été effectué. Cette personne n'occupe plus la fonction d'administrateur·rice de réseau. La décision est consignée dans l'historique militant d'AnarBib.",
    es: "Tras el fin del período de gracia de 7 días, el retiro colectivo de {proposedName} se hizo efectivo. Esta persona ya no ocupa la función de administrade de red. La decisión queda registrada en el historial militante de AnarBib.",
    en: "After the 7-day grace period, the collective removal of {proposedName} has been carried out. This person no longer holds the network administrator role. The decision is recorded in the militant history of AnarBib.",
    it: "Al termine del periodo di grazia di 7 giorni, il ritiro collettivo di {proposedName} è stato attuato. Questa persona non ricopre più il ruolo di amministratore/trice/e di rete. La decisione è registrata nella storia militante di AnarBib.",
    de: "Nach Ablauf der 7-tägigen Karenzfrist wurde der kollektive Rückzug von {proposedName} vollzogen. Diese Person ist nicht mehr Netzwerk-Administrator*in. Die Entscheidung wird in der militanten Geschichte von AnarBib festgehalten.",
    ca: "Un cop finalitzat el termini de gràcia de 7 dies, la retirada col·lectiva de {proposedName} s'ha fet efectiva. Aquesta persona ja no ocupa la funció d'administrador-a-e de xarxa. La decisió queda registrada a l'historial militant d'AnarBib.",
    eo: "Post la fino de la grac-periodo de 7 tagoj, la kolektiva forigo de {proposedName} estis efektivigita. Ĉi tiu persono ne plu okupas la funkcion de reta administrant-in-o. La decido estas registrita en la aktivisma historio de AnarBib."
  },
  "network.collective_removal_executed.target_intro": {
    "pt-BR": "A carência de 7 dias terminou e a retirada coletiva votada por unanimidade está agora efetiva. Vossa função d(o/a/e) administrador(a/e) de rede no AnarBib foi removida. Esta decisão é registrada no histórico militante.",
    fr: "La carence de 7 jours est arrivée à terme et le retrait collectif voté à l'unanimité prend effet. Votre fonction d'administrateur·rice de réseau dans AnarBib a été retirée. Cette décision est consignée dans l'historique militant.",
    es: "Terminó el período de gracia de 7 días y el retiro colectivo votado por unanimidad entra en vigor. Vuestra función de administrade de red en AnarBib fue retirada. Esta decisión queda registrada en el historial militante.",
    en: "The 7-day grace period has ended and the unanimously-voted collective removal now takes effect. Your network administrator role in AnarBib has been removed. This decision is recorded in the militant history.",
    it: "Il periodo di grazia di 7 giorni è terminato e il ritiro collettivo votato all'unanimità entra in vigore. La vostra funzione di amministratore/trice/e di rete in AnarBib è stata rimossa. Questa decisione è registrata nella storia militante.",
    de: "Die 7-tägige Karenzfrist ist abgelaufen, und der einstimmig beschlossene kollektive Rückzug wird wirksam. Ihre Funktion als Netzwerk-Administrator*in in AnarBib wurde entzogen. Diese Entscheidung wird in der militanten Geschichte festgehalten.",
    ca: "El termini de gràcia de 7 dies ha acabat i la retirada col·lectiva votada per unanimitat entra en vigor. La vostra funció d'administrador-a-e de xarxa a AnarBib ha estat retirada. Aquesta decisió queda registrada a l'historial militant.",
    eo: "La grac-periodo de 7 tagoj finiĝis kaj la kolektiva forigo voĉdonita unuanime ekvalidas. Via funkcio de reta administrant-in-o en AnarBib estis forigita. Ĉi tiu decido estas registrita en la aktivisma historio."
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
    eo: "Kooptad-propono: {proposedName}"
  },
  "network.cooptation_proposed.intro": {
    "pt-BR": "{proposerName} propôs cooptar {proposedName} como administrador(a/e) de rede. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s é necessária para concluir o processo. Vosso voto é esperado.",
    fr: "{proposerName} propose de coopter {proposedName} comme administrateur·rice du réseau. L'unanimité des administrateur·rices actif·ves est nécessaire pour conclure le processus. Votre vote est attendu.",
    es: "{proposerName} propone cooptar a {proposedName} como administrade de red. La unanimidad de les administradores activos es necesaria para cerrar el proceso. Vuestro voto es esperado.",
    en: "{proposerName} proposes to coopt {proposedName} as a network administrator. Unanimity among active network administrators is required to complete the process. Your vote is expected.",
    it: "{proposerName} propone di cooptare {proposedName} come amministratore/trice/e di rete. L'unanimità dei compagni/e amministratori/e attivi/e è necessaria per concludere il processo. Il vostro voto è atteso.",
    de: "{proposerName} schlägt vor, {proposedName} als Netzwerk-Administrator*in zu kooptieren. Die Einstimmigkeit der aktiven Netzwerk-Administrator*innen ist erforderlich, um den Prozess abzuschließen. Ihre Stimme wird erwartet.",
    ca: "{proposerName} proposa cooptar {proposedName} com a administrador-a-e de xarxa. La unanimitat de les administradores actives és necessària per concloure el procés. S'espera el vostre vot.",
    eo: "{proposerName} proponas koopti {proposedName} kiel retan administrant-in-on. La unuanimeco de la aktivaj administrant-in-oj estas necesa por konkludi la procezon. Via voĉdono estas atendata."
  },
  "network.cooptation_proposed.cta": {
    "pt-BR": "Acessar a proposta e votar",
    fr: "Accéder à la proposition et voter",
    es: "Acceder a la propuesta y votar",
    en: "Open the proposal and vote",
    it: "Accedere alla proposta e votare",
    de: "Vorschlag öffnen und abstimmen",
    ca: "Accedir a la proposta i votar",
    eo: "Aliri la proponon kaj voĉdoni"
  },
  "network.cooptation_proposed.motivation_label": {
    "pt-BR": "Motivacao invocada :",
    fr: "Motivation invoquee :",
    es: "Motivacion invocada :",
    en: "Stated motivation:",
    it: "Motivazione invocata :",
    de: "Angegebene Begrundung:",
    ca: "Motivació invocada:",
    eo: "Invokita motivo:"
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
    eo: "Voĉdono registrita · kooptado de {proposedName}"
  },
  "network.cooptation_voted.intro": {
    "pt-BR": "Um(a/e) administrador(a/e) de rede acaba de votar sobre a proposta de cooptação de {proposedName}, aberta por {proposerName}. Acessai a app para ver o estado atual da deliberação e votar se ainda não o fizeste.",
    fr: "Un·e administrateur·rice du réseau vient de voter sur la proposition de cooptation de {proposedName}, ouverte par {proposerName}. Accédez à l'app pour voir l'état actuel de la délibération et voter si ce n'est pas déjà fait.",
    es: "Une administrade de red acaba de votar sobre la propuesta de cooptación de {proposedName}, abierta por {proposerName}. Accedé a la app para ver el estado actual de la deliberación y votar si aún no lo hiciste.",
    en: "A network administrator has just cast a vote on the cooptation proposal of {proposedName}, opened by {proposerName}. Open the app to see the current state of the deliberation and vote if you haven't already.",
    it: "Un compagno/a/e amministratore/trice/e di rete ha appena votato sulla proposta di cooptazione di {proposedName}, aperta da {proposerName}. Accedi all'app per vedere lo stato attuale della deliberazione e votare se non l'hai ancora fatto.",
    de: "Ein*e Netzwerk-Administrator*in hat soeben über den Kooptationsvorschlag von {proposedName} abgestimmt, eröffnet von {proposerName}. Öffnen Sie die App, um den aktuellen Stand der Beratung zu sehen und abzustimmen, falls noch nicht geschehen.",
    ca: "Una administradora de xarxa acaba de votar sobre la proposta de cooptació de {proposedName}, oberta per {proposerName}. Accediu a l'aplicació per veure l'estat actual de la deliberació i votar si encara no ho heu fet.",
    eo: "Reta administrant-in-o ĵus voĉdonis pri la kooptad-propono de {proposedName}, malfermita de {proposerName}. Aliru la aplikaĵon por vidi la nunan staton de la pridiskuto kaj voĉdoni se vi ankoraŭ ne faris tion."
  },
  "network.cooptation_voted.rationale_label": {
    "pt-BR": "Motivo do voto contrário :",
    fr: "Motif du vote défavorable :",
    es: "Motivo del voto contrario :",
    en: "Reason for opposing vote:",
    it: "Motivo del voto contrario :",
    de: "Begründung der Ablehnung:",
    ca: "Motiu del vot contrari:",
    eo: "Motivo de la kontraŭa voĉdono:"
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
    eo: "Kooptado rifuzita · {proposedName}"
  },
  "network.cooptation_rejected.intro": {
    "pt-BR": "A proposta de cooptação de {proposedName}, aberta por {proposerName}, foi rejeitada por pelo menos um voto contrário. A unanimidade requerida não foi alcançada e o processo é encerrado.",
    fr: "La proposition de cooptation de {proposedName}, ouverte par {proposerName}, a été rejetée par au moins un vote défavorable. L'unanimité requise n'est pas atteinte et le processus est clos.",
    es: "La propuesta de cooptación de {proposedName}, abierta por {proposerName}, fue rechazada por al menos un voto contrario. La unanimidad requerida no se alcanzó y el proceso se cierra.",
    en: "The cooptation proposal of {proposedName}, opened by {proposerName}, has been rejected by at least one opposing vote. The required unanimity was not reached and the process is closed.",
    it: "La proposta di cooptazione di {proposedName}, aperta da {proposerName}, è stata respinta per almeno un voto contrario. L'unanimità richiesta non è stata raggiunta e il processo si chiude.",
    de: "Der Kooptationsvorschlag von {proposedName}, eröffnet von {proposerName}, wurde durch mindestens eine Gegenstimme abgelehnt. Die erforderliche Einstimmigkeit wurde nicht erreicht und der Prozess wird geschlossen.",
    ca: "La proposta de cooptació de {proposedName}, oberta per {proposerName}, ha estat rebutjada per almenys un vot contrari. La unanimitat requerida no s'ha assolit i el procés es tanca.",
    eo: "La kooptad-propono de {proposedName}, malfermita de {proposerName}, estis rifuzita pro almenaŭ unu kontraŭa voĉdono. La postulata unuanimeco ne estis atingita kaj la procezo fermiĝas."
  },
  "network.cooptation_rejected.target_intro": {
    "pt-BR": "Olá {targetName}. Uma proposta de cooptação para integrar-te como administrador(a/e) de rede AnarBib foi aberta e discutida pel(o/a/e)s administrador(a/e)s ativ(o/a/e)s. Esta proposta não foi acolhida à unanimidade : recebeu pelo menos um voto contrário e o processo é encerrado. Esta decisão é coletiva e política, não pessoal.",
    fr: "Bonjour {targetName}. Une proposition de cooptation pour t'intégrer comme administrateur·rice du réseau AnarBib a été ouverte et discutée par les administrateur·rices actif·ves. Cette proposition n'a pas recueilli l'unanimité : elle a reçu au moins un vote défavorable et le processus est clos. Cette décision est collective et politique, non personnelle.",
    es: "Hola {targetName}. Una propuesta de cooptación para integrarte como administrade de red AnarBib fue abierta y discutida por les administradores activos. Esta propuesta no obtuvo unanimidad : recibió al menos un voto contrario y el proceso se cierra. Esta decisión es colectiva y política, no personal.",
    en: "Hello {targetName}. A cooptation proposal to integrate you as a network administrator of AnarBib was opened and discussed by the active administrators. This proposal did not reach unanimity: it received at least one opposing vote and the process is closed. This decision is collective and political, not personal.",
    it: "Ciao {targetName}. Una proposta di cooptazione per integrarti come amministratore/trice/e di rete AnarBib è stata aperta e discussa dai compagni/e amministratori/e attivi/e. Questa proposta non ha raggiunto l'unanimità : ha ricevuto almeno un voto contrario e il processo si chiude. Questa decisione è collettiva e politica, non personale.",
    de: "Hallo {targetName}. Ein Kooptationsvorschlag, um Sie als Netzwerk-Administrator*in von AnarBib zu integrieren, wurde eröffnet und von den aktiven Administrator*innen besprochen. Dieser Vorschlag erreichte keine Einstimmigkeit: er erhielt mindestens eine Gegenstimme und der Prozess wird geschlossen. Diese Entscheidung ist kollektiv und politisch, nicht persönlich.",
    ca: "Hola, {targetName}. S'ha obert i discutit una proposta de cooptació per integrar-te com a administrador-a-e de la xarxa AnarBib per part de les administradores actives. Aquesta proposta no ha obtingut la unanimitat: ha rebut almenys un vot contrari i el procés es tanca. Aquesta decisió és col·lectiva i política, no personal.",
    eo: "Saluton, {targetName}. Kooptad-propono por integri vin kiel administrant-in-on de la reto AnarBib estis malfermita kaj pridiskutita de la aktivaj administrant-in-oj. Ĉi tiu propono ne atingis la unuanimecon: ĝi ricevis almenaŭ unu kontraŭan voĉdonon kaj la procezo fermiĝas. Ĉi tiu decido estas kolektiva kaj politika, ne persona."
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
    eo: "Kooptado konkludita unuanime · {proposedName}"
  },
  "network.cooptation_completed.intro": {
    "pt-BR": "A proposta de cooptação de {proposedName}, aberta por {proposerName}, foi concluída à unanimidade. {proposedName} torna-se administrador(a/e) de rede ativ(o/a/e) da AnarBib.",
    fr: "La proposition de cooptation de {proposedName}, ouverte par {proposerName}, a été conclue à l'unanimité. {proposedName} devient administrateur·rice du réseau AnarBib actif·ve.",
    es: "La propuesta de cooptación de {proposedName}, abierta por {proposerName}, fue concluida por unanimidad. {proposedName} se vuelve administrade de red activa de AnarBib.",
    en: "The cooptation proposal of {proposedName}, opened by {proposerName}, has been concluded unanimously. {proposedName} becomes an active network administrator of AnarBib.",
    it: "La proposta di cooptazione di {proposedName}, aperta da {proposerName}, è stata conclusa all'unanimità. {proposedName} diventa compagno/a/e amministratore/trice/e di rete attiv(o/a/e) di AnarBib.",
    de: "Der Kooptationsvorschlag von {proposedName}, eröffnet von {proposerName}, wurde einstimmig abgeschlossen. {proposedName} wird aktive*r Netzwerk-Administrator*in von AnarBib.",
    ca: "La proposta de cooptació de {proposedName}, oberta per {proposerName}, s'ha conclòs per unanimitat. {proposedName} esdevé administrador-a-e de xarxa actiu-iva-e d'AnarBib.",
    eo: "La kooptad-propono de {proposedName}, malfermita de {proposerName}, estis konkludita unuanime. {proposedName} iĝas aktiva reta administrant-in-o de AnarBib."
  },
  "network.cooptation_completed.target_intro": {
    "pt-BR": "Olá {targetName}. A proposta de cooptação para integrar-te como administrador(a/e) de rede AnarBib foi concluída à unanimidade. Sejas bem-vind(o/a/e) na equipa de administração de rede.",
    fr: "Bonjour {targetName}. La proposition de cooptation pour t'intégrer comme administrateur·rice du réseau AnarBib a été conclue à l'unanimité. Bienvenue dans l'équipe d'administration du réseau.",
    es: "Hola {targetName}. La propuesta de cooptación para integrarte como administrade de red AnarBib fue concluida por unanimidad. ¡Bienvenide al equipo de administración de red!",
    en: "Hello {targetName}. The cooptation proposal to integrate you as a network administrator of AnarBib has been concluded unanimously. Welcome to the network administration team.",
    it: "Ciao {targetName}. La proposta di cooptazione per integrarti come amministratore/trice/e di rete AnarBib è stata conclusa all'unanimità. Benvenuto/a/e nel team di amministrazione di rete.",
    de: "Hallo {targetName}. Der Kooptationsvorschlag, um Sie als Netzwerk-Administrator*in von AnarBib zu integrieren, wurde einstimmig abgeschlossen. Willkommen im Netzwerk-Administrationsteam.",
    ca: "Hola, {targetName}. La proposta de cooptació per integrar-te com a administrador-a-e de la xarxa AnarBib s'ha conclòs per unanimitat. Benvingut-da-e a l'equip d'administració de la xarxa.",
    eo: "Saluton, {targetName}. La kooptad-propono por integri vin kiel administrant-in-on de la reto AnarBib estis konkludita unuanime. Bonvenon en la retadministran teamon."
  },
  "network.cooptation_completed.cta": {
    "pt-BR": "Acessar o painel de administração de rede",
    fr: "Accéder au panneau d'administration du réseau",
    es: "Acceder al panel de administración de red",
    en: "Open the network administration panel",
    it: "Accedere al pannello di amministrazione di rete",
    de: "Netzwerk-Administrationspanel öffnen",
    ca: "Accedir al tauler d'administració de la xarxa",
    eo: "Aliri la retadministran panelon"
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
    eo: "Peto de surloka konsulto ricevita"
  },
  "con.created.pre": {
    "pt-BR": "Sua consulta foi registrada.",
    fr: "Ta consultation a été enregistrée.",
    es: "Tu consulta fue registrada.",
    en: "Your consultation has been registered.",
    it: "La tua consultazione è stata registrata.",
    de: "Deine Einsichtnahme wurde registriert.",
    ca: "La teva consulta s'ha registrat.",
    eo: "Via konsulto estis registrita."
  },
  "con.created.intro": {
    "pt-BR": "Recebemos seu pedido de consulta local. A biblioteca confirmará a data e o horário em breve.",
    fr: "Nous avons reçu ta demande de consultation sur place. La bibliothèque te confirmera la date et l'horaire bientôt.",
    es: "Recibimos tu pedido de consulta local. La biblioteca confirmará pronto la fecha y el horario.",
    en: "We received your local consultation request. The library will confirm the date and time soon.",
    it: "Abbiamo ricevuto la tua richiesta di consultazione in loco. La biblioteca confermerà presto data e orario.",
    de: "Wir haben deine Anfrage für Vor-Ort-Einsichtnahme erhalten. Die Bibliothek bestätigt Datum und Uhrzeit in Kürze.",
    ca: "Hem rebut la teva sol·licitud de consulta in situ. La biblioteca et confirmarà aviat la data i l'hora.",
    eo: "Ni ricevis vian peton de surloka konsulto. La biblioteko baldaŭ konfirmos al vi la daton kaj la horon."
  },
  "con.created.hint": {
    "pt-BR": "Lembramos que a consulta local acontece nos espaços da biblioteca, sem empréstimo do(s) item(ns).",
    fr: "Rappel : la consultation se fait dans les espaces de la bibliothèque, sans emprunt de l'ouvrage.",
    es: "Recordá que la consulta local se hace en los espacios de la biblioteca, sin préstamo del material.",
    en: "Remember: the consultation takes place at the library, with no item loan.",
    it: "Ti ricordiamo che la consultazione avviene negli spazi della biblioteca, senza prestito del materiale.",
    de: "Hinweis: Die Einsichtnahme findet in den Räumen der Bibliothek statt, ohne Ausleihe.",
    ca: "Recorda: la consulta in situ es fa als espais de la biblioteca, sense préstec del document.",
    eo: "Memoru: la surloka konsulto okazas en la spacoj de la biblioteko, sen prunto de la dokumento."
  },
  "con.created.admin": {
    "pt-BR": "Novo pedido de consulta local",
    fr: "Nouvelle demande de consultation sur place",
    es: "Nuevo pedido de consulta local",
    en: "New local consultation request",
    it: "Nuova richiesta di consultazione in loco",
    de: "Neue Anfrage für Vor-Ort-Einsichtnahme",
    ca: "Nova sol·licitud de consulta in situ",
    eo: "Nova peto de surloka konsulto"
  },
  "con.realized": {
    "pt-BR": "Consulta local registrada como realizada",
    fr: "Consultation sur place enregistrée comme effectuée",
    es: "Consulta local registrada como realizada",
    en: "Local consultation marked as completed",
    it: "Consultazione in loco registrata come effettuata",
    de: "Vor-Ort-Einsichtnahme als durchgeführt vermerkt",
    ca: "Consulta in situ registrada com a efectuada",
    eo: "Surloka konsulto registrita kiel efektivigita"
  },
  "con.cancelReader": {
    "pt-BR": "O(a/e) leitor(a/e) cancelou um pedido de consulta local",
    fr: "Le·la lecteur·rice a annulé une demande de consultation",
    es: "Le lectore canceló un pedido de consulta local",
    en: "The reader cancelled a consultation request",
    it: "Lettor* ha annullato una richiesta di consultazione",
    de: "Leser*in hat eine Anfrage für Einsichtnahme storniert",
    ca: "Le lector-a-e ha cancel·lat una sol·licitud de consulta in situ",
    eo: "La legant-in-o nuligis peton de surloka konsulto"
  },
  "con.cancelStaff": {
    "pt-BR": "A biblioteca cancelou seu pedido de consulta local",
    fr: "La bibliothèque a annulé ta demande de consultation",
    es: "La biblioteca canceló tu pedido de consulta local",
    en: "The library cancelled your consultation request",
    it: "La biblioteca ha annullato la tua richiesta di consultazione",
    de: "Die Bibliothek hat deine Anfrage für Einsichtnahme storniert",
    ca: "La biblioteca ha cancel·lat la teva sol·licitud de consulta in situ",
    eo: "La biblioteko nuligis vian peton de surloka konsulto"
  },
  "con.expired": {
    "pt-BR": "Pedido de consulta local expirado",
    fr: "Demande de consultation expirée",
    es: "Pedido de consulta local expirado",
    en: "Consultation request expired",
    it: "Richiesta di consultazione scaduta",
    de: "Anfrage für Einsichtnahme abgelaufen",
    ca: "Sol·licitud de consulta in situ expirada",
    eo: "Peto de surloka konsulto eksvalidiĝinta"
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
    eo: "La biblioteko proponis al vi horon por via surloka konsulto: {date}, de {time_start} ĝis {time_end} ({tz}). Konfirmu ĉu ĉi tiu horo konvenas al vi."
  },
  "cwf.reader.rescheduled": {
    "pt-BR": "A biblioteca atualizou o horário proposto para sua consulta local: {date}, das {time_start} às {time_end} ({tz}). Confirme se este novo horário funciona.",
    fr: "La bibliothèque a modifié l'horaire proposé pour ta consultation : {date}, de {time_start} à {time_end} ({tz}). Confirme si ce nouvel horaire te convient.",
    es: "La biblioteca actualizó el horario propuesto para tu consulta: {date}, de {time_start} a {time_end} ({tz}). Confirmá si este nuevo horario funciona.",
    en: "The library has updated the proposed time for your consultation: {date}, from {time_start} to {time_end} ({tz}). Please confirm if this new time works.",
    it: "La biblioteca ha aggiornato l'orario proposto per la tua consultazione: {date}, dalle {time_start} alle {time_end} ({tz}). Conferma se il nuovo orario va bene.",
    de: "Die Bibliothek hat den vorgeschlagenen Termin für deine Einsichtnahme aktualisiert: {date}, von {time_start} bis {time_end} ({tz}). Bitte bestätige, ob das neue Datum passt.",
    ca: "La biblioteca ha actualitzat l'horari proposat per a la teva consulta in situ: {date}, de {time_start} a {time_end} ({tz}). Confirma si aquest nou horari et va bé.",
    eo: "La biblioteko ĝisdatigis la proponitan horon por via surloka konsulto: {date}, de {time_start} ĝis {time_end} ({tz}). Konfirmu ĉu ĉi tiu nova horo konvenas."
  },
  "cwf.staff.scheduled": {
    "pt-BR": "Horário proposto ao(à/e) leitor(a/e)",
    fr: "Horaire proposé au·à la lecteur·rice",
    es: "Horario propuesto a le lectore",
    en: "Time slot proposed to the reader",
    it: "Orario proposto a lettor*",
    de: "Termin an Leser*in vorgeschlagen",
    ca: "Horari proposat a le lector-a-e",
    eo: "Horo proponita al la legant-in-o"
  },
  "cwf.staff.rescheduled": {
    "pt-BR": "Horário atualizado proposto ao(à/e) leitor(a/e)",
    fr: "Horaire modifié proposé au·à la lecteur·rice",
    es: "Horario actualizado propuesto a le lectore",
    en: "Updated time slot proposed to the reader",
    it: "Orario aggiornato proposto a lettor*",
    de: "Aktualisierter Termin an Leser*in vorgeschlagen",
    ca: "Horari actualitzat proposat a le lector-a-e",
    eo: "Ĝisdatigita horo proponita al la legant-in-o"
  },
  "cwf.staff.readerConfirmed": {
    "pt-BR": "O(a/e) leitor(a/e) confirmou o horário proposto",
    fr: "Le·la lecteur·rice a confirmé l'horaire proposé",
    es: "Le lectore confirmó el horario propuesto",
    en: "The reader confirmed the proposed time slot",
    it: "Lettor* ha confermato l'orario proposto",
    de: "Leser*in hat den vorgeschlagenen Termin bestätigt",
    ca: "Le lector-a-e ha confirmat l'horari proposat",
    eo: "La legant-in-o konfirmis la proponitan horon"
  },
  "cwf.staff.readerRefused": {
    "pt-BR": "O(a/e) leitor(a/e) recusou o horário proposto",
    fr: "Le·la lecteur·rice a refusé l'horaire proposé",
    es: "Le lectore rechazó el horario propuesto",
    en: "The reader declined the proposed time slot",
    it: "Lettor* ha rifiutato l'orario proposto",
    de: "Leser*in hat den vorgeschlagenen Termin abgelehnt",
    ca: "Le lector-a-e ha rebutjat l'horari proposat",
    eo: "La legant-in-o rifuzis la proponitan horon"
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
    eo: "Via peto de surloka konsulto estas preparata. La biblioteko baldaŭ proponos al vi horon."
  },
  "cwf.reader.nao_compareceu": {
    "pt-BR": "Você foi marcado(a/e) como ausente na consulta local agendada para {date}, das {time_start} às {time_end}. A biblioteca tinha se preparado para te receber. Caso queira marcar um novo horário, entre em contato com a biblioteca.",
    fr: "Tu as été marqué·e comme absent·e à la consultation prévue le {date}, de {time_start} à {time_end}. La bibliothèque s'était préparée à t'accueillir. Si tu souhaites fixer un nouvel horaire, contacte la bibliothèque.",
    es: "Has sido marcado(a/e) como ausente en la consulta local programada para {date}, de {time_start} a {time_end}. La biblioteca se había preparado para recibirte. Si quieres fijar un nuevo horario, contactá a la biblioteca.",
    en: "You have been marked as absent for the local consultation scheduled on {date}, from {time_start} to {time_end}. The library had prepared to welcome you. If you wish to schedule a new time, please contact the library.",
    it: "Sei stato/a/* segnalato/a/* come assente alla consultazione locale prevista per il {date}, dalle {time_start} alle {time_end}. La biblioteca si era preparata ad accoglierti. Se desideri fissare un nuovo orario, contatta la biblioteca.",
    de: "Du wurdest als abwesend bei der lokalen Einsichtnahme am {date} von {time_start} bis {time_end} markiert. Die Bibliothek hatte sich darauf vorbereitet, dich zu empfangen. Wenn du einen neuen Termin vereinbaren möchtest, kontaktiere die Bibliothek.",
    ca: "Has estat marcat-da-e com a absent-a-e a la consulta in situ prevista per al {date}, de {time_start} a {time_end}. La biblioteca s'havia preparat per rebre't. Si vols fixar un nou horari, contacta la biblioteca.",
    eo: "Vi estis markita kiel forestanta ĉe la surloka konsulto planita por la {date}, de {time_start} ĝis {time_end}. La biblioteko estis preparinta sin por akcepti vin. Se vi deziras fiksi novan horon, kontaktu la bibliotekon."
  },
  "cwf.staff.nao_compareceu": {
    "pt-BR": "Não comparecimento registrado",
    fr: "Non-présentation enregistrée",
    es: "No comparecencia registrada",
    en: "No-show recorded",
    it: "Mancata presentazione registrata",
    de: "Nichterscheinen erfasst",
    ca: "No-presentació registrada",
    eo: "Neapero registrita"
  },
  "cwf.actionBox.replySlot": {
    "pt-BR": "Responder à proposta",
    fr: "Répondre à la proposition",
    es: "Responder a la propuesta",
    en: "Reply to the proposal",
    it: "Rispondi alla proposta",
    de: "Auf den Vorschlag antworten",
    ca: "Respondre a la proposta",
    eo: "Respondi al la propono"
  },
  "cwf.actionBox.preparePainel": {
    "pt-BR": "Abrir o painel",
    fr: "Ouvrir le painel",
    es: "Abrir el panel",
    en: "Open the panel",
    it: "Apri il pannello",
    de: "Panel öffnen",
    ca: "Obrir el tauler",
    eo: "Malfermi la panelon"
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
    eo: "Voĉdono"
  },
  "l.voter": {
    "pt-BR": "Voto emitido por",
    fr: "Vote émis par",
    es: "Voto emitido por",
    en: "Vote cast by",
    it: "Voto espresso da",
    de: "Stimme abgegeben von",
    ca: "Vot emès per",
    eo: "Voĉdono donita de"
  },
  "l.proposer": {
    "pt-BR": "Proposta por",
    fr: "Proposée par",
    es: "Propuesta por",
    en: "Proposed by",
    it: "Proposta da",
    de: "Vorgeschlagen von",
    ca: "Proposada per",
    eo: "Proponita de"
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
    eo: "Koncernata persono"
  },
  "l.actor": {
    "pt-BR": "Autor-a-e da ação",
    fr: "Auteur·rice de l'action",
    es: "Autor(a/e) de la acción",
    en: "Action taken by",
    it: "Autore/a dell'azione",
    de: "Ausführende Person",
    ca: "Autor(a/e) de l'acció",
    eo: "Aŭtoro de la ago"
  },
  "l.cancelledBy": {
    "pt-BR": "Anulado por",
    fr: "Annulé par",
    es: "Anulado por",
    en: "Cancelled by",
    it: "Annullato da",
    de: "Aufgehoben von",
    ca: "Anul·lat per",
    eo: "Nuligita de"
  },
  "l.library": {
    "pt-BR": "Biblioteca",
    fr: "Bibliothèque",
    es: "Biblioteca",
    en: "Library",
    it: "Biblioteca",
    de: "Bibliothek",
    ca: "Biblioteca",
    eo: "Biblioteko"
  },
  "l.role": {
    "pt-BR": "Papel",
    fr: "Rôle",
    es: "Rol",
    en: "Role",
    it: "Ruolo",
    de: "Rolle",
    ca: "Rol",
    eo: "Rolo"
  },
  "l.roleConcerned": {
    "pt-BR": "Papel concernido",
    fr: "Rôle concerné",
    es: "Rol concernido",
    en: "Role concerned",
    it: "Ruolo interessato",
    de: "Betroffene Rolle",
    ca: "Rol concernit",
    eo: "Koncernata rolo"
  },
  "l.roleRemoved": {
    "pt-BR": "Papel retirado",
    fr: "Rôle retiré",
    es: "Rol retirado",
    en: "Role removed",
    it: "Ruolo rimosso",
    de: "Entzogene Rolle",
    ca: "Rol retirat",
    eo: "Forigita rolo"
  },
  "l.roleFrom": {
    "pt-BR": "Papel anterior",
    fr: "Ancien rôle",
    es: "Rol anterior",
    en: "Previous role",
    it: "Ruolo precedente",
    de: "Bisherige Rolle",
    ca: "Rol anterior",
    eo: "Antaŭa rolo"
  },
  "l.roleTo": {
    "pt-BR": "Novo papel",
    fr: "Nouveau rôle",
    es: "Nuevo rol",
    en: "New role",
    it: "Nuovo ruolo",
    de: "Neue Rolle",
    ca: "Nou rol",
    eo: "Nova rolo"
  },
  "l.gracePeriodEnd": {
    "pt-BR": "Fim do prazo de carência",
    fr: "Fin du délai de carence",
    es: "Fin del plazo de gracia",
    en: "End of grace period",
    it: "Fine del periodo di tolleranza",
    de: "Ende der Kulanzfrist",
    ca: "Fi del termini de gràcia",
    eo: "Fino de la prokrastperiodo"
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
    eo: "Publika ID"
  },
  "l.name": {
    "pt-BR": "Nome",
    fr: "Nom",
    es: "Nombre",
    en: "Name",
    it: "Nome",
    de: "Name",
    ca: "Nom",
    eo: "Nomo"
  },
  "l.email": {
    "pt-BR": "E-mail",
    fr: "E-mail",
    es: "Correo electrónico",
    en: "Email",
    it: "E-mail",
    de: "E-Mail",
    ca: "Correu electrònic",
    eo: "Retpoŝto"
  },
  "l.phone": {
    "pt-BR": "Telefone",
    fr: "Téléphone",
    es: "Teléfono",
    en: "Phone",
    it: "Telefono",
    de: "Telefon",
    ca: "Telèfon",
    eo: "Telefono"
  },
  "l.address": {
    "pt-BR": "Endereço informado",
    fr: "Adresse renseignée",
    es: "Dirección indicada",
    en: "Address provided",
    it: "Indirizzo fornito",
    de: "Angegebene Adresse",
    ca: "Adreça indicada",
    eo: "Indikita adreso"
  },
  "l.registrationDate": {
    "pt-BR": "Data do cadastro",
    fr: "Date d'inscription",
    es: "Fecha de registro",
    en: "Registration date",
    it: "Data di registrazione",
    de: "Anmeldedatum",
    ca: "Data de registre",
    eo: "Dato de registriĝo"
  },
  "l.testContext": {
    "pt-BR": "Contexto de teste",
    fr: "Contexte de test",
    es: "Contexto de prueba",
    en: "Test context",
    it: "Contesto di test",
    de: "Testkontext",
    ca: "Context de prova",
    eo: "Testa kunteksto"
  },
  "network.cooptation_voted.cta": {
    "pt-BR": "Acessar a proposta e votar",
    fr: "Accéder à la proposition et voter",
    es: "Acceder a la propuesta y votar",
    en: "Open the proposal and vote",
    it: "Accedere alla proposta e votare",
    de: "Vorschlag öffnen und abstimmen",
    ca: "Accedir a la proposta i votar",
    eo: "Aliri la proponon kaj voĉdoni"
  },
  "network.vote.favorable": {
    "pt-BR": "favorável",
    fr: "favorable",
    es: "favorable",
    en: "in favour",
    it: "favorevole",
    de: "dafür",
    ca: "favorable",
    eo: "favora"
  },
  "network.vote.opposed": {
    "pt-BR": "contrário",
    fr: "défavorable",
    es: "contrario",
    en: "against",
    it: "contrario",
    de: "dagegen",
    ca: "contrari",
    eo: "kontraŭa"
  },
  "network.vote.abstain": {
    "pt-BR": "abstenção",
    fr: "abstention",
    es: "abstención",
    en: "abstention",
    it: "astensione",
    de: "Enthaltung",
    ca: "abstenció",
    eo: "sindeteno"
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
    eo: "{libraryName}: nova transir-propono — {axisLoc}"
  },
  "library_profile.voted.sub": {
    "pt-BR": "{libraryName}: novo voto sobre {axisLoc}",
    fr: "{libraryName} : nouveau vote sur {axisLoc}",
    es: "{libraryName}: nuevo voto sobre {axisLoc}",
    en: "{libraryName}: new vote on {axisLoc}",
    it: "{libraryName}: nuovo voto su {axisLoc}",
    de: "{libraryName}: neue Stimme zu {axisLoc}",
    ca: "{libraryName}: nou vot sobre {axisLoc}",
    eo: "{libraryName}: nova voĉdono pri {axisLoc}"
  },
  "library_profile.accepted.sub": {
    "pt-BR": "{libraryName}: transição em {axisLoc} aprovada coletivamente",
    fr: "{libraryName} : transition sur {axisLoc} acceptée collectivement",
    es: "{libraryName}: transición sobre {axisLoc} aceptada colectivamente",
    en: "{libraryName}: transition on {axisLoc} accepted collectively",
    it: "{libraryName}: transizione su {axisLoc} accettata collettivamente",
    de: "{libraryName}: Übergang zu {axisLoc} kollektiv angenommen",
    ca: "{libraryName}: transició sobre {axisLoc} acceptada col·lectivament",
    eo: "{libraryName}: transiro pri {axisLoc} kolektive akceptita"
  },
  "library_profile.rejected.sub": {
    "pt-BR": "{libraryName}: proposta em {axisLoc} não passou",
    fr: "{libraryName} : proposition sur {axisLoc} non retenue",
    es: "{libraryName}: propuesta sobre {axisLoc} no aceptada",
    en: "{libraryName}: proposal on {axisLoc} did not pass",
    it: "{libraryName}: proposta su {axisLoc} non accettata",
    de: "{libraryName}: Vorschlag zu {axisLoc} nicht angenommen",
    ca: "{libraryName}: proposta sobre {axisLoc} no acceptada",
    eo: "{libraryName}: propono pri {axisLoc} ne sukcesis"
  },
  "library_profile.cancelled.sub": {
    "pt-BR": "{libraryName}: proposta em {axisLoc} retirada pel(o/a/e) proponente",
    fr: "{libraryName} : proposition sur {axisLoc} retirée par le·la proposant·e",
    es: "{libraryName}: propuesta sobre {axisLoc} retirada por le proponente",
    en: "{libraryName}: proposal on {axisLoc} withdrawn by the proposer",
    it: "{libraryName}: proposta su {axisLoc} ritirata dal/dalla proponente",
    de: "{libraryName}: Vorschlag zu {axisLoc} von der*dem Vorschlagenden zurückgezogen",
    ca: "{libraryName}: proposta sobre {axisLoc} retirada per le proposant-a-e",
    eo: "{libraryName}: propono pri {axisLoc} retirita de la propon-int-o"
  },
  "library_profile.executed.sub": {
    "pt-BR": "{libraryName}: transição em {axisLoc} agora em vigor",
    fr: "{libraryName} : transition sur {axisLoc} désormais en vigueur",
    es: "{libraryName}: transición sobre {axisLoc} ahora en vigor",
    en: "{libraryName}: transition on {axisLoc} now in effect",
    it: "{libraryName}: transizione su {axisLoc} ora in vigore",
    de: "{libraryName}: Übergang zu {axisLoc} jetzt in Kraft",
    ca: "{libraryName}: transició sobre {axisLoc} ara en vigor",
    eo: "{libraryName}: transiro pri {axisLoc} nun en vigoro"
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
    eo: "<b>{proposerName}</b> malfermis proponon por ke <b>{libraryName}</b> ŝanĝu sian <b>{axisLoc}</b>, transirante de <i>{oldValueLoc}</i> al <b>{newValueLoc}</b>. La teamo estas invitita pridiskuti kaj voĉdoni."
  },
  "library_profile.voted.intro": {
    "pt-BR": "<b>{voterName}</b> votou <b>{voteLoc}</b> sobre a proposta de mudança em <b>{axisLoc}</b> da <b>{libraryName}</b> (de <i>{oldValueLoc}</i> para <b>{newValueLoc}</b>).",
    fr: "<b>{voterName}</b> a voté <b>{voteLoc}</b> sur la proposition de transition de <b>{axisLoc}</b> de <b>{libraryName}</b> (de <i>{oldValueLoc}</i> vers <b>{newValueLoc}</b>).",
    es: "<b>{voterName}</b> votó <b>{voteLoc}</b> sobre la propuesta de transición de <b>{axisLoc}</b> de <b>{libraryName}</b> (de <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>).",
    en: "<b>{voterName}</b> voted <b>{voteLoc}</b> on the transition proposal for <b>{axisLoc}</b> at <b>{libraryName}</b> (from <i>{oldValueLoc}</i> to <b>{newValueLoc}</b>).",
    it: "<b>{voterName}</b> ha votato <b>{voteLoc}</b> sulla proposta di transizione di <b>{axisLoc}</b> a <b>{libraryName}</b> (da <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>).",
    de: "<b>{voterName}</b> hat <b>{voteLoc}</b> zum Übergangsvorschlag für <b>{axisLoc}</b> bei <b>{libraryName}</b> gestimmt (von <i>{oldValueLoc}</i> zu <b>{newValueLoc}</b>).",
    ca: "<b>{voterName}</b> ha votat <b>{voteLoc}</b> sobre la proposta de transició de <b>{axisLoc}</b> de <b>{libraryName}</b> (de <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>).",
    eo: "<b>{voterName}</b> voĉdonis <b>{voteLoc}</b> pri la transir-propono de <b>{axisLoc}</b> de <b>{libraryName}</b> (de <i>{oldValueLoc}</i> al <b>{newValueLoc}</b>)."
  },
  "library_profile.accepted.intro": {
    "pt-BR": "A coletividade da <b>{libraryName}</b> aprovou (<i>{acceptedLoc}</i>) a transição em <b>{axisLoc}</b>: de <i>{oldValueLoc}</i> para <b>{newValueLoc}</b>. A decisão entrará em vigor após o período de carência, durante o qual a comunidade pode ainda se manifestar.",
    fr: "La collectivité de <b>{libraryName}</b> a accepté (<i>{acceptedLoc}</i>) la transition de <b>{axisLoc}</b> : de <i>{oldValueLoc}</i> à <b>{newValueLoc}</b>. La décision entrera en vigueur après le délai de réflexion, pendant lequel la communauté peut encore se manifester.",
    es: "La colectividad de <b>{libraryName}</b> aceptó (<i>{acceptedLoc}</i>) la transición de <b>{axisLoc}</b>: de <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>. La decisión entrará en vigor después del plazo de reflexión, durante el cual la comunidad aún puede manifestarse.",
    en: "The collective of <b>{libraryName}</b> accepted (<i>{acceptedLoc}</i>) the transition of <b>{axisLoc}</b>: from <i>{oldValueLoc}</i> to <b>{newValueLoc}</b>. The decision will take effect after the reflection period, during which the community may still raise objections.",
    it: "La collettività di <b>{libraryName}</b> ha accettato (<i>{acceptedLoc}</i>) la transizione di <b>{axisLoc}</b>: da <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>. La decisione entrerà in vigore dopo il periodo di riflessione, durante il quale la comunità può ancora manifestarsi.",
    de: "Das Kollektiv von <b>{libraryName}</b> hat den Übergang von <b>{axisLoc}</b> angenommen (<i>{acceptedLoc}</i>): von <i>{oldValueLoc}</i> zu <b>{newValueLoc}</b>. Die Entscheidung tritt nach der Reflexionsfrist in Kraft, während der die Gemeinschaft sich noch äußern kann.",
    ca: "La col·lectivitat de <b>{libraryName}</b> ha acceptat (<i>{acceptedLoc}</i>) la transició de <b>{axisLoc}</b>: de <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>. La decisió entrarà en vigor després del termini de reflexió, durant el qual la comunitat encara pot manifestar-se.",
    eo: "La kolektivo de <b>{libraryName}</b> akceptis (<i>{acceptedLoc}</i>) la transiron de <b>{axisLoc}</b>: de <i>{oldValueLoc}</i> al <b>{newValueLoc}</b>. La decido ekvalidos post la pripensa periodo, dum kiu la komunumo ankoraŭ povas esprimiĝi."
  },
  "library_profile.rejected.intro": {
    "pt-BR": "A proposta de transição em <b>{axisLoc}</b> da <b>{libraryName}</b> (de <i>{oldValueLoc}</i> para <b>{newValueLoc}</b>) não passou: <i>{reasonLoc}</i>. O modo atual permanece em vigor.",
    fr: "La proposition de transition de <b>{axisLoc}</b> de <b>{libraryName}</b> (de <i>{oldValueLoc}</i> vers <b>{newValueLoc}</b>) n'a pas abouti : <i>{reasonLoc}</i>. Le fonctionnement actuel reste en vigueur.",
    es: "La propuesta de transición de <b>{axisLoc}</b> de <b>{libraryName}</b> (de <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>) no fue aceptada: <i>{reasonLoc}</i>. El funcionamiento actual se mantiene en vigor.",
    en: "The transition proposal for <b>{axisLoc}</b> at <b>{libraryName}</b> (from <i>{oldValueLoc}</i> to <b>{newValueLoc}</b>) did not pass: <i>{reasonLoc}</i>. The current setup remains in effect.",
    it: "La proposta di transizione di <b>{axisLoc}</b> a <b>{libraryName}</b> (da <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>) non è passata: <i>{reasonLoc}</i>. Il funzionamento attuale rimane in vigore.",
    de: "Der Übergangsvorschlag für <b>{axisLoc}</b> bei <b>{libraryName}</b> (von <i>{oldValueLoc}</i> zu <b>{newValueLoc}</b>) wurde nicht angenommen: <i>{reasonLoc}</i>. Die aktuelle Funktionsweise bleibt in Kraft.",
    ca: "La proposta de transició de <b>{axisLoc}</b> de <b>{libraryName}</b> (de <i>{oldValueLoc}</i> a <b>{newValueLoc}</b>) no ha prosperat: <i>{reasonLoc}</i>. El funcionament actual es manté en vigor.",
    eo: "La transir-propono de <b>{axisLoc}</b> de <b>{libraryName}</b> (de <i>{oldValueLoc}</i> al <b>{newValueLoc}</b>) ne sukcesis: <i>{reasonLoc}</i>. La nuna funkciado restas en vigoro."
  },
  "library_profile.cancelled.intro": {
    "pt-BR": "<b>{proposerName}</b> retirou sua própria proposta de transição em <b>{axisLoc}</b> da <b>{libraryName}</b> (que era: de <i>{oldValueLoc}</i> para <i>{newValueLoc}</i>). O modo atual permanece em vigor.",
    fr: "<b>{proposerName}</b> a retiré sa propre proposition de transition de <b>{axisLoc}</b> de <b>{libraryName}</b> (qui était : de <i>{oldValueLoc}</i> vers <i>{newValueLoc}</i>). Le fonctionnement actuel reste en vigueur.",
    es: "<b>{proposerName}</b> retiró su propia propuesta de transición de <b>{axisLoc}</b> de <b>{libraryName}</b> (que era: de <i>{oldValueLoc}</i> a <i>{newValueLoc}</i>). El funcionamiento actual se mantiene en vigor.",
    en: "<b>{proposerName}</b> withdrew their own transition proposal for <b>{axisLoc}</b> at <b>{libraryName}</b> (which was: from <i>{oldValueLoc}</i> to <i>{newValueLoc}</i>). The current setup remains in effect.",
    it: "<b>{proposerName}</b> ha ritirato la propria proposta di transizione di <b>{axisLoc}</b> a <b>{libraryName}</b> (che era: da <i>{oldValueLoc}</i> a <i>{newValueLoc}</i>). Il funzionamento attuale rimane in vigore.",
    de: "<b>{proposerName}</b> hat den eigenen Übergangsvorschlag für <b>{axisLoc}</b> bei <b>{libraryName}</b> zurückgezogen (er war: von <i>{oldValueLoc}</i> zu <i>{newValueLoc}</i>). Die aktuelle Funktionsweise bleibt in Kraft.",
    ca: "<b>{proposerName}</b> ha retirat la seva pròpia proposta de transició de <b>{axisLoc}</b> de <b>{libraryName}</b> (que era: de <i>{oldValueLoc}</i> a <i>{newValueLoc}</i>). El funcionament actual es manté en vigor.",
    eo: "<b>{proposerName}</b> retiris sian propran transir-proponon de <b>{axisLoc}</b> de <b>{libraryName}</b> (kiu estis: de <i>{oldValueLoc}</i> al <i>{newValueLoc}</i>). La nuna funkciado restas en vigoro."
  },
  "library_profile.executed.intro": {
    "pt-BR": "A <b>{libraryName}</b> acaba de basculhar seu <b>{axisLoc}</b>: a partir de agora, ela funciona em <b>{newValueLoc}</b> (anteriormente: <i>{oldValueLoc}</i>). Esta transição foi decidida coletivamente.",
    fr: "<b>{libraryName}</b> adopte un nouveau <b>{axisLoc}</b> : à partir de maintenant, <i>{oldValueLoc}</i> devient <b>{newValueLoc}</b>. Cette transition a été décidée collectivement.",
    es: "<b>{libraryName}</b> adopta un nuevo <b>{axisLoc}</b>: a partir de ahora, <i>{oldValueLoc}</i> deviene <b>{newValueLoc}</b>. Esta transición fue decidida colectivamente.",
    en: "<b>{libraryName}</b> adopts a new <b>{axisLoc}</b>: from now on, <i>{oldValueLoc}</i> becomes <b>{newValueLoc}</b>. This transition was decided collectively.",
    it: "<b>{libraryName}</b> adotta un nuovo <b>{axisLoc}</b>: da ora in poi, <i>{oldValueLoc}</i> diventa <b>{newValueLoc}</b>. Questa transizione è stata decisa collettivamente.",
    de: "<b>{libraryName}</b> nimmt einen neuen <b>{axisLoc}</b> an: ab jetzt wird <i>{oldValueLoc}</i> zu <b>{newValueLoc}</b>. Diese Transition wurde kollektiv beschlossen.",
    ca: "<b>{libraryName}</b> adopta un nou <b>{axisLoc}</b>: a partir d'ara, <i>{oldValueLoc}</i> esdevé <b>{newValueLoc}</b>. Aquesta transició s'ha decidit col·lectivament.",
    eo: "<b>{libraryName}</b> adoptas novan <b>{axisLoc}</b>: ekde nun, <i>{oldValueLoc}</i> iĝas <b>{newValueLoc}</b>. Ĉi tiu transiro estis decidita kolektive."
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
    eo: "Pridiskuti kaj voĉdoni"
  },
  "library_profile.voted.cta": {
    "pt-BR": "Ver a proposta",
    fr: "Voir la proposition",
    es: "Ver la propuesta",
    en: "View the proposal",
    it: "Vedere la proposta",
    de: "Vorschlag ansehen",
    ca: "Veure la proposta",
    eo: "Vidi la proponon"
  },
  "library_profile.accepted.cta": {
    "pt-BR": "Ver os detalhes",
    fr: "Voir les détails",
    es: "Ver los detalles",
    en: "View the details",
    it: "Vedere i dettagli",
    de: "Details ansehen",
    ca: "Veure els detalls",
    eo: "Vidi la detalojn"
  },
  "library_profile.accepted.gracePeriodInfo": {
    "pt-BR": "Período de carência em curso",
    fr: "Délai de réflexion en cours",
    es: "Plazo de reflexión en curso",
    en: "Reflection period in progress",
    it: "Periodo di riflessione in corso",
    de: "Reflexionsfrist läuft",
    ca: "Termini de reflexió en curs",
    eo: "Pripensa periodo en kurso"
  },
  "library_profile.executed.cta": {
    "pt-BR": "Ver o perfil da biblioteca",
    fr: "Voir le profil de la bibliothèque",
    es: "Ver el perfil de la biblioteca",
    en: "View the library profile",
    it: "Vedere il profilo della biblioteca",
    de: "Bibliotheksprofil ansehen",
    ca: "Veure el perfil de la biblioteca",
    eo: "Vidi la profilon de la biblioteko"
  },
  "library_profile.executed.info": {
    "pt-BR": "Transição aplicada",
    fr: "Transition appliquée",
    es: "Transición aplicada",
    en: "Transition applied",
    it: "Transizione applicata",
    de: "Übergang angewendet",
    ca: "Transició aplicada",
    eo: "Transiro aplikita"
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
    eo: "{libraryName}: ŝanĝo de {axisLoc}"
  },
  "library_profile.reader_executed.intro": {
    "pt-BR": "A coletividade de <b>{libraryName}</b> decidiu mudar seu <b>{axisLoc}</b>: a partir de agora, <i>{oldValueLoc}</i> torna-se <b>{newValueLoc}</b>.",
    fr: "La collectivité de <b>{libraryName}</b> a décidé de changer son <b>{axisLoc}</b> : à partir de maintenant, <i>{oldValueLoc}</i> devient <b>{newValueLoc}</b>.",
    es: "La colectividad de <b>{libraryName}</b> decidió cambiar su <b>{axisLoc}</b>: a partir de ahora, <i>{oldValueLoc}</i> deviene <b>{newValueLoc}</b>.",
    en: "The collective of <b>{libraryName}</b> has decided to change its <b>{axisLoc}</b>: from now on, <i>{oldValueLoc}</i> becomes <b>{newValueLoc}</b>.",
    it: "La collettività di <b>{libraryName}</b> ha deciso di cambiare il suo <b>{axisLoc}</b>: da ora in poi, <i>{oldValueLoc}</i> diventa <b>{newValueLoc}</b>.",
    de: "Das Kollektiv von <b>{libraryName}</b> hat beschlossen, seinen <b>{axisLoc}</b> zu ändern: ab jetzt wird <i>{oldValueLoc}</i> zu <b>{newValueLoc}</b>.",
    ca: "La col·lectivitat de <b>{libraryName}</b> ha decidit canviar el seu <b>{axisLoc}</b>: a partir d'ara, <i>{oldValueLoc}</i> esdevé <b>{newValueLoc}</b>.",
    eo: "La kolektivo de <b>{libraryName}</b> decidis ŝanĝi sian <b>{axisLoc}</b>: ekde nun, <i>{oldValueLoc}</i> iĝas <b>{newValueLoc}</b>."
  },
  "library_profile.reader_executed.impact.full_sigb": {
    "pt-BR": "Para você como leitor·a·e: a partir de agora, você pode pegar emprestados livros, fazer reservas e consultar documentos no local através da interface AnarBib de <b>{libraryName}</b>.",
    fr: "Pour toi en tant que lecteur·rice : à partir de maintenant, tu peux emprunter des livres, faire des réservations et consulter des documents sur place via l'interface AnarBib de <b>{libraryName}</b>.",
    es: "Para vos como lector·a·e: a partir de ahora, podés tomar prestados libros, hacer reservas y consultar documentos en el lugar a través de la interfaz AnarBib de <b>{libraryName}</b>.",
    en: "For you as a reader: from now on, you can borrow books, make reservations and consult documents on site through the AnarBib interface of <b>{libraryName}</b>.",
    it: "Per te come lettore/trice/x: da ora in poi, puoi prendere in prestito libri, fare prenotazioni e consultare documenti sul posto attraverso l'interfaccia AnarBib di <b>{libraryName}</b>.",
    de: "Für dich als Leser*in: ab jetzt kannst du Bücher ausleihen, Reservierungen vornehmen und Dokumente vor Ort über die AnarBib-Oberfläche von <b>{libraryName}</b> einsehen.",
    ca: "Per a tu com a lector-a-e: a partir d'ara, pots demanar llibres en préstec, fer reserves i consultar documents in situ a través de la interfície AnarBib de <b>{libraryName}</b>.",
    eo: "Por vi kiel legant-in-o: ekde nun, vi povas prunti librojn, fari rezervojn kaj surloke konsulti dokumentojn pere de la interfaco AnarBib de <b>{libraryName}</b>."
  },
  "library_profile.reader_executed.impact.informal": {
    "pt-BR": "Para você como leitor·a·e: a partir de agora, a circulação acontece de maneira informal, fora da interface AnarBib. Entre em contato diretamente com <b>{libraryName}</b> para pegar emprestado ou consultar.",
    fr: "Pour toi en tant que lecteur·rice : à partir de maintenant, la circulation se fait de manière informelle, hors interface AnarBib. Contacte directement <b>{libraryName}</b> pour emprunter ou consulter.",
    es: "Para vos como lector·a·e: a partir de ahora, la circulación se hace de manera informal, fuera de la interfaz AnarBib. Contactá directamente a <b>{libraryName}</b> para tomar prestado o consultar.",
    en: "For you as a reader: from now on, circulation happens informally, outside the AnarBib interface. Contact <b>{libraryName}</b> directly to borrow or consult.",
    it: "Per te come lettore/trice/x: da ora in poi, la circolazione avviene in modo informale, fuori dall'interfaccia AnarBib. Contatta direttamente <b>{libraryName}</b> per prendere in prestito o consultare.",
    de: "Für dich als Leser*in: ab jetzt erfolgt die Zirkulation informell, außerhalb der AnarBib-Oberfläche. Wende dich direkt an <b>{libraryName}</b>, um etwas auszuleihen oder einzusehen.",
    ca: "Per a tu com a lector-a-e: a partir d'ara, la circulació es fa de manera informal, fora de la interfície AnarBib. Contacta directament <b>{libraryName}</b> per demanar en préstec o consultar.",
    eo: "Por vi kiel legant-in-o: ekde nun, la cirkulado okazas neformale, ekster la interfaco AnarBib. Kontaktu rekte <b>{libraryName}</b> por prunti aŭ konsulti."
  },
  "library_profile.reader_executed.impact.off": {
    "pt-BR": "Para você como leitor·a·e: a partir de agora, <b>{libraryName}</b> não oferece mais serviço de empréstimo nem de consulta para leitor·a·e·s via AnarBib. Você ainda pode entrar em contato com a biblioteca para conversar sobre o acervo.",
    fr: "Pour toi en tant que lecteur·rice : à partir de maintenant, <b>{libraryName}</b> ne propose plus de service de prêt ni de consultation aux lecteur·rice·s via AnarBib. Tu peux toujours contacter la bibliothèque pour échanger sur le fonds.",
    es: "Para vos como lector·a·e: a partir de ahora, <b>{libraryName}</b> ya no ofrece servicio de préstamo ni de consulta para lector·a·e·s vía AnarBib. Aún podés contactar la biblioteca para conversar sobre el acervo.",
    en: "For you as a reader: from now on, <b>{libraryName}</b> no longer offers borrowing or consultation services for readers via AnarBib. You can still contact the library to discuss the collection.",
    it: "Per te come lettore/trice/x: da ora in poi, <b>{libraryName}</b> non offre più servizi di prestito o consultazione per lettori/trici/x via AnarBib. Puoi ancora contattare la biblioteca per parlare della collezione.",
    de: "Für dich als Leser*in: ab jetzt bietet <b>{libraryName}</b> keine Ausleih- oder Einsichtsdienste mehr für Leser*innen über AnarBib an. Du kannst die Bibliothek weiterhin kontaktieren, um über den Bestand zu sprechen.",
    ca: "Per a tu com a lector-a-e: a partir d'ara, <b>{libraryName}</b> ja no ofereix servei de préstec ni de consulta per a lectores via AnarBib. Encara pots contactar la biblioteca per parlar del fons.",
    eo: "Por vi kiel legant-in-o: ekde nun, <b>{libraryName}</b> ne plu ofertas prunt- aŭ konsult-servon por legant-in-oj pere de AnarBib. Vi ankoraŭ povas kontakti la bibliotekon por priparoli la fonduson."
  },
  "library_profile.reader_executed.cta": {
    "pt-BR": "Ver a biblioteca",
    fr: "Voir la bibliothèque",
    es: "Ver la biblioteca",
    en: "View the library",
    it: "Vedere la biblioteca",
    de: "Bibliothek ansehen",
    ca: "Veure la biblioteca",
    eo: "Vidi la bibliotekon"
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
    eo: "katalogada reĝimo"
  },
  "lp.axis.circulation_mode": {
    "pt-BR": "modo de circulação",
    fr: "mode de circulation",
    es: "modo de circulación",
    en: "circulation mode",
    it: "modo di circolazione",
    de: "Zirkulationsmodus",
    ca: "mode de circulació",
    eo: "cirkulada reĝimo"
  },
  "lp.axis.network_mode": {
    "pt-BR": "vínculo à federação",
    fr: "lien à la fédération",
    es: "vínculo con la federación",
    en: "link to the federation",
    it: "legame con la federazione",
    de: "Verbindung zur Föderation",
    ca: "vincle amb la federació",
    eo: "ligo al la federacio"
  },
  "lp.axis.governance_mode": {
    "pt-BR": "modo de governança",
    fr: "mode de gouvernance",
    es: "modo de gobernanza",
    en: "governance mode",
    it: "modo di governance",
    de: "Governance-Modus",
    ca: "mode de governança",
    eo: "memmastruma reĝimo"
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
    eo: "nur loka katalogo"
  },
  "lp.value.catalog_mode.network_published": {
    "pt-BR": "catálogo publicado na federação",
    fr: "catalogue publié dans la fédération",
    es: "catálogo publicado en la federación",
    en: "catalogue published in the federation",
    it: "catalogo pubblicato nella federazione",
    de: "in der Föderation veröffentlichter Katalog",
    ca: "catàleg publicat a la federació",
    eo: "katalogo publikigita en la federacio"
  },
  "lp.value.circulation_mode.off": {
    "pt-BR": "sem circulação",
    fr: "sans circulation",
    es: "sin circulación",
    en: "no circulation",
    it: "senza circolazione",
    de: "keine Zirkulation",
    ca: "sense circulació",
    eo: "sen cirkulado"
  },
  "lp.value.circulation_mode.informal": {
    "pt-BR": "circulação informal",
    fr: "circulation informelle",
    es: "circulación informal",
    en: "informal circulation",
    it: "circolazione informale",
    de: "informelle Zirkulation",
    ca: "circulació informal",
    eo: "neformala cirkulado"
  },
  "lp.value.circulation_mode.full_sigb": {
    "pt-BR": "SIGB completo (empréstimos, reservas, consultas)",
    fr: "SIGB complet (emprunts, réservations, consultations)",
    es: "SIGB completo (préstamos, reservas, consultas)",
    en: "full ILS (loans, reservations, consultations)",
    it: "SIGB completo (prestiti, prenotazioni, consultazioni)",
    de: "vollständiges ILS (Ausleihen, Reservierungen, Konsultationen)",
    ca: "SIGB complet (préstecs, reserves, consultes)",
    eo: "kompleta SIGB (pruntoj, rezervoj, konsultoj)"
  },
  "lp.value.network_mode.isolated": {
    "pt-BR": "isolada da federação",
    fr: "isolée de la fédération",
    es: "aislada de la federación",
    en: "isolated from the federation",
    it: "isolata dalla federazione",
    de: "von der Föderation isoliert",
    ca: "aïllada de la federació",
    eo: "izolita de la federacio"
  },
  "lp.value.network_mode.observer": {
    "pt-BR": "observadora da federação",
    fr: "observatrice de la fédération",
    es: "observadora de la federación",
    en: "observer of the federation",
    it: "osservatrice della federazione",
    de: "Beobachterin der Föderation",
    ca: "observadora de la federació",
    eo: "observanta la federacion"
  },
  "lp.value.network_mode.federated": {
    "pt-BR": "federada (participação plena)",
    fr: "fédérée (participation pleine)",
    es: "federada (participación plena)",
    en: "federated (full participation)",
    it: "federata (partecipazione piena)",
    de: "föderiert (volle Teilnahme)",
    ca: "federada (participació plena)",
    eo: "federita (plena partopreno)"
  },
  "lp.value.governance_mode.informal": {
    "pt-BR": "governança informal (sem papéis declarados)",
    fr: "gouvernance informelle (sans rôles déclarés)",
    es: "gobernanza informal (sin roles declarados)",
    en: "informal governance (no declared roles)",
    it: "governance informale (senza ruoli dichiarati)",
    de: "informelle Governance (ohne erklärte Rollen)",
    ca: "governança informal (sense rols declarats)",
    eo: "neformala memmastrumado (sen deklaritaj roloj)"
  },
  "lp.value.governance_mode.staff_roles": {
    "pt-BR": "papéis declarados (bibliotecári(o/a/e) e coordenador(o/a/e))",
    fr: "rôles déclarés (bibliothécaires et coordinateur·rice·s)",
    es: "roles declarados (bibliotecaries y coordinadores)",
    en: "declared roles (librarians and coordinators)",
    it: "ruoli dichiarati (bibliotecari/e/o e coordinatori/e/o)",
    de: "erklärte Rollen (Bibliothekar*innen und Koordinator*innen)",
    ca: "rols declarats (bibliotecari-ària-e i coordinador-a-e)",
    eo: "deklaritaj roloj (bibliotekist-in-o kaj kunordigant-in-o)"
  },
  "lp.value.governance_mode.full_governance": {
    "pt-BR": "governança plena (com todas as rotinas coletivas)",
    fr: "gouvernance pleine (avec toutes les routines collectives)",
    es: "gobernanza plena (con todas las rutinas colectivas)",
    en: "full governance (with all collective routines)",
    it: "governance piena (con tutte le routine collettive)",
    de: "volle Governance (mit allen kollektiven Routinen)",
    ca: "governança plena (amb totes les rutines col·lectives)",
    eo: "plena memmastrumado (kun ĉiuj kolektivaj rutinoj)"
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
    eo: "rekta transiro (sen pridiskuto)"
  },
  "lp.transition.majority": {
    "pt-BR": "maioria simples",
    fr: "majorité simple",
    es: "mayoría simple",
    en: "simple majority",
    it: "maggioranza semplice",
    de: "einfache Mehrheit",
    ca: "majoria simple",
    eo: "simpla plimulto"
  },
  "lp.transition.unanimous": {
    "pt-BR": "unanimidade",
    fr: "unanimité",
    es: "unanimidad",
    en: "unanimity",
    it: "unanimità",
    de: "Einstimmigkeit",
    ca: "unanimitat",
    eo: "unuanimeco"
  },
  "lp.transition.unanimous_extended": {
    "pt-BR": "unanimidade alargada (com período de carência reforçado)",
    fr: "unanimité élargie (avec délai de réflexion renforcé)",
    es: "unanimidad ampliada (con plazo de reflexión reforzado)",
    en: "extended unanimity (with reinforced reflection period)",
    it: "unanimità allargata (con periodo di riflessione rafforzato)",
    de: "erweiterte Einstimmigkeit (mit verstärkter Reflexionsfrist)",
    ca: "unanimitat ampliada (amb termini de reflexió reforçat)",
    eo: "etendita unuanimeco (kun plifortigita pripensa periodo)"
  },
  "lp.transition.unknown": {
    "pt-BR": "tipo de transição desconhecido",
    fr: "type de transition inconnu",
    es: "tipo de transición desconocido",
    en: "unknown transition type",
    it: "tipo di transizione sconosciuto",
    de: "unbekannter Übergangstyp",
    ca: "tipus de transició desconegut",
    eo: "nekonata transir-tipo"
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
    eo: "por"
  },
  "lp.vote.against": {
    "pt-BR": "contra",
    fr: "contre",
    es: "en contra",
    en: "against",
    it: "contro",
    de: "dagegen",
    ca: "en contra",
    eo: "kontraŭ"
  },
  "lp.vote.abstain": {
    "pt-BR": "abstenção",
    fr: "abstention",
    es: "abstención",
    en: "abstention",
    it: "astensione",
    de: "Enthaltung",
    ca: "abstenció",
    eo: "sindeteno"
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
    eo: "unuanime"
  },
  "lp.status.accepted_majority": {
    "pt-BR": "por maioria",
    fr: "à la majorité",
    es: "por mayoría",
    en: "by majority",
    it: "a maggioranza",
    de: "mehrheitlich",
    ca: "per majoria",
    eo: "plimulte"
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
    eo: "malfavora kolektiva voĉdono"
  },
  "lp.rejected.reason.expired": {
    "pt-BR": "prazo de deliberação atingido sem decisão",
    fr: "délai de délibération atteint sans décision",
    es: "plazo de deliberación alcanzado sin decisión",
    en: "deliberation deadline reached without decision",
    it: "termine di deliberazione raggiunto senza decisione",
    de: "Beratungsfrist ohne Entscheidung abgelaufen",
    ca: "termini de deliberació assolit sense decisió",
    eo: "pridiskuta limdato atingita sen decido"
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
    eo: "Transir-tipo"
  },
  "l.lp.motivation": {
    "pt-BR": "Motivação",
    fr: "Motivation",
    es: "Motivación",
    en: "Motivation",
    it: "Motivazione",
    de: "Begründung",
    ca: "Motivació",
    eo: "Motivo"
  },
  "l.lp.proposer": {
    "pt-BR": "Proponente",
    fr: "Proposant·e",
    es: "Proponente",
    en: "Proposer",
    it: "Proponente",
    de: "Vorschlagende*r",
    ca: "Proposant-a-e",
    eo: "Propon-int-o"
  },
  "l.lp.voteCount": {
    "pt-BR": "Votos",
    fr: "Voix",
    es: "Votos",
    en: "Votes",
    it: "Voti",
    de: "Stimmen",
    ca: "Vots",
    eo: "Voĉdonoj"
  },
  "l.lp.rationaleAgainst": {
    "pt-BR": "Justificação do voto contra",
    fr: "Justification du vote contre",
    es: "Justificación del voto en contra",
    en: "Rationale for vote against",
    it: "Giustificazione del voto contrario",
    de: "Begründung der Gegenstimme",
    ca: "Justificació del vot en contra",
    eo: "Pravigo de la kontraŭa voĉdono"
  },
  "l.lp.gracePeriodUntil": {
    "pt-BR": "Carência até",
    fr: "Délai de réflexion jusqu'au",
    es: "Plazo de reflexión hasta",
    en: "Reflection period until",
    it: "Periodo di riflessione fino al",
    de: "Reflexionsfrist bis",
    ca: "Termini de reflexió fins al",
    eo: "Pripensa periodo ĝis"
  },
  "l.lp.reason": {
    "pt-BR": "Razão",
    fr: "Raison",
    es: "Razón",
    en: "Reason",
    it: "Ragione",
    de: "Grund",
    ca: "Raó",
    eo: "Kialo"
  },
  "l.lp.cancelledMotivation": {
    "pt-BR": "Motivo do retiro",
    fr: "Motif du retrait",
    es: "Motivo del retiro",
    en: "Reason for withdrawal",
    it: "Motivo del ritiro",
    de: "Grund des Rückzugs",
    ca: "Motiu de la retirada",
    eo: "Motivo de la retiro"
  },
  "l.lp.executedAt": {
    "pt-BR": "Aplicada em",
    fr: "Appliquée le",
    es: "Aplicada el",
    en: "Applied on",
    it: "Applicata il",
    de: "Angewendet am",
    ca: "Aplicada el",
    eo: "Aplikita la"
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
    eo: "Interbiblioteka prunto {lender} → {borrower} — nova peto"
  },
  "ill.subject.prepared": {
    "pt-BR": "Empréstimo interbibliotecas {lender} → {borrower} — preparado",
    fr: "Prêt interbibliothèques {lender} → {borrower} — préparé",
    es: "Préstamo interbibliotecario {lender} → {borrower} — preparado",
    en: "Interlibrary loan {lender} → {borrower} — prepared",
    it: "Prestito interbibliotecario {lender} → {borrower} — preparato",
    de: "Fernleihe {lender} → {borrower} — vorbereitet",
    ca: "Préstec interbibliotecari {lender} → {borrower} — preparat",
    eo: "Interbiblioteka prunto {lender} → {borrower} — preparita"
  },
  "ill.subject.dispatched": {
    "pt-BR": "Empréstimo interbibliotecas {lender} → {borrower} — em circulação",
    fr: "Prêt interbibliothèques {lender} → {borrower} — en circulation",
    es: "Préstamo interbibliotecario {lender} → {borrower} — en circulación",
    en: "Interlibrary loan {lender} → {borrower} — in transit",
    it: "Prestito interbibliotecario {lender} → {borrower} — in circolazione",
    de: "Fernleihe {lender} → {borrower} — unterwegs",
    ca: "Préstec interbibliotecari {lender} → {borrower} — en circulació",
    eo: "Interbiblioteka prunto {lender} → {borrower} — en cirkulado"
  },
  "ill.subject.return_started": {
    "pt-BR": "Empréstimo interbibliotecas {lender} → {borrower} — devolução iniciada",
    fr: "Prêt interbibliothèques {lender} → {borrower} — retour amorcé",
    es: "Préstamo interbibliotecario {lender} → {borrower} — devolución iniciada",
    en: "Interlibrary loan {lender} → {borrower} — return started",
    it: "Prestito interbibliotecario {lender} → {borrower} — restituzione avviata",
    de: "Fernleihe {lender} → {borrower} — Rückgabe begonnen",
    ca: "Préstec interbibliotecari {lender} → {borrower} — devolució iniciada",
    eo: "Interbiblioteka prunto {lender} → {borrower} — redono komencita"
  },
  "ill.subject.returned": {
    "pt-BR": "Empréstimo interbibliotecas {lender} → {borrower} — encerrado",
    fr: "Prêt interbibliothèques {lender} → {borrower} — clôturé",
    es: "Préstamo interbibliotecario {lender} → {borrower} — cerrado",
    en: "Interlibrary loan {lender} → {borrower} — closed",
    it: "Prestito interbibliotecario {lender} → {borrower} — concluso",
    de: "Fernleihe {lender} → {borrower} — abgeschlossen",
    ca: "Préstec interbibliotecari {lender} → {borrower} — tancat",
    eo: "Interbiblioteka prunto {lender} → {borrower} — fermita"
  },
  "ill.subject.cancelled": {
    "pt-BR": "Empréstimo interbibliotecas {lender} → {borrower} — cancelado",
    fr: "Prêt interbibliothèques {lender} → {borrower} — annulé",
    es: "Préstamo interbibliotecario {lender} → {borrower} — cancelado",
    en: "Interlibrary loan {lender} → {borrower} — cancelled",
    it: "Prestito interbibliotecario {lender} → {borrower} — annullato",
    de: "Fernleihe {lender} → {borrower} — storniert",
    ca: "Préstec interbibliotecari {lender} → {borrower} — anul·lat",
    eo: "Interbiblioteka prunto {lender} → {borrower} — nuligita"
  },
  "ill.subject.overdue": {
    "pt-BR": "Empréstimo interbibliotecas {lender} → {borrower} — em atraso",
    fr: "Prêt interbibliothèques {lender} → {borrower} — en retard",
    es: "Préstamo interbibliotecario {lender} → {borrower} — atrasado",
    en: "Interlibrary loan {lender} → {borrower} — overdue",
    it: "Prestito interbibliotecario {lender} → {borrower} — in ritardo",
    de: "Fernleihe {lender} → {borrower} — überfällig",
    ca: "Préstec interbibliotecari {lender} → {borrower} — endarrerit",
    eo: "Interbiblioteka prunto {lender} → {borrower} — malfruita"
  },
  "ill.subject.partially_returned": {
    "pt-BR": "Empréstimo interbibliotecas {lender} → {borrower} — devolução parcial",
    fr: "Prêt interbibliothèques {lender} → {borrower} — retour partiel",
    es: "Préstamo interbibliotecario {lender} → {borrower} — devolución parcial",
    en: "Interlibrary loan {lender} → {borrower} — partial return",
    it: "Prestito interbibliotecario {lender} → {borrower} — restituzione parziale",
    de: "Fernleihe {lender} → {borrower} — Teilrückgabe",
    ca: "Préstec interbibliotecari {lender} → {borrower} — devolució parcial",
    eo: "Interbiblioteka prunto {lender} → {borrower} — parta redono"
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
    eo: "Nova peto de interbiblioteka prunto"
  },
  "ill.title.prepared": {
    "pt-BR": "Empréstimo preparado",
    fr: "Prêt préparé",
    es: "Préstamo preparado",
    en: "Loan prepared",
    it: "Prestito preparato",
    de: "Leihe vorbereitet",
    ca: "Préstec preparat",
    eo: "Prunto preparita"
  },
  "ill.title.dispatched": {
    "pt-BR": "Empréstimo em circulação",
    fr: "Prêt en circulation",
    es: "Préstamo en circulación",
    en: "Loan in transit",
    it: "Prestito in circolazione",
    de: "Leihe unterwegs",
    ca: "Préstec en circulació",
    eo: "Prunto en cirkulado"
  },
  "ill.title.return_started": {
    "pt-BR": "Devolução iniciada",
    fr: "Retour amorcé",
    es: "Devolución iniciada",
    en: "Return started",
    it: "Restituzione avviata",
    de: "Rückgabe begonnen",
    ca: "Devolució iniciada",
    eo: "Redono komencita"
  },
  "ill.title.returned": {
    "pt-BR": "Empréstimo encerrado",
    fr: "Prêt clôturé",
    es: "Préstamo cerrado",
    en: "Loan closed",
    it: "Prestito concluso",
    de: "Leihe abgeschlossen",
    ca: "Préstec tancat",
    eo: "Prunto fermita"
  },
  "ill.title.cancelled": {
    "pt-BR": "Empréstimo cancelado",
    fr: "Prêt annulé",
    es: "Préstamo cancelado",
    en: "Loan cancelled",
    it: "Prestito annullato",
    de: "Leihe storniert",
    ca: "Préstec anul·lat",
    eo: "Prunto nuligita"
  },
  "ill.title.overdue": {
    "pt-BR": "Empréstimo em atraso",
    fr: "Prêt en retard",
    es: "Préstamo atrasado",
    en: "Loan overdue",
    it: "Prestito in ritardo",
    de: "Leihe überfällig",
    ca: "Préstec endarrerit",
    eo: "Prunto malfruita"
  },
  "ill.title.partially_returned": {
    "pt-BR": "Devolução parcial",
    fr: "Retour partiel",
    es: "Devolución parcial",
    en: "Partial return",
    it: "Restituzione parziale",
    de: "Teilrückgabe",
    ca: "Devolució parcial",
    eo: "Parta redono"
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
    eo: "Via biblioteko ĵus proponis prunton de dokumentoj al {borrower}. La peto {loanRef} estas registrita. {borrower} estis informita kaj respondos por daŭrigi ĉi tiun proponon. La detalo de la koncernaj dokumentoj estas sube."
  },
  "ill.intro.created.borrower_partner": {
    "pt-BR": "{lender} propõe à sua biblioteca um empréstimo de documentos. O pedido {loanRef} acaba de ser aberto. Para aceitar, conversar ou organizar a retirada, entre em contato com a pessoa indicada abaixo. O detalhe dos documentos propostos está mais abaixo.",
    fr: "{lender} propose à votre bibliothèque un prêt de documents. La demande {loanRef} vient d'être ouverte. Pour accepter, en discuter ou organiser le retrait, contactez la personne indiquée ci-dessous. Le détail des documents proposés figure plus bas.",
    es: "{lender} propone a tu biblioteca un préstamo de documentos. La solicitud {loanRef} acaba de abrirse. Para aceptar, conversar u organizar el retiro, contacta a la persona indicada abajo. El detalle de los documentos propuestos está más abajo.",
    en: "{lender} is offering your library a loan of documents. Request {loanRef} has just been opened. To accept, discuss it or arrange pickup, contact the person indicated below. The list of documents offered is further down.",
    it: "{lender} propone alla vostra biblioteca un prestito di documenti. La richiesta {loanRef} è appena stata aperta. Per accettare, discuterne o organizzare il ritiro, contattate la persona indicata qui sotto. Il dettaglio dei documenti proposti è più in basso.",
    de: "{lender} bietet eurer Bibliothek eine Ausleihe von Dokumenten an. Die Anfrage {loanRef} wurde soeben eröffnet. Um anzunehmen, zu besprechen oder die Abholung zu organisieren, wendet euch an die unten genannte Person. Die Liste der angebotenen Dokumente steht weiter unten.",
    ca: "{lender} proposa a la vostra biblioteca un préstec de documents. La sol·licitud {loanRef} acaba d'obrir-se. Per acceptar, parlar-ne o organitzar la recollida, contacteu la persona indicada a sota. El detall dels documents proposats és més avall.",
    eo: "{lender} proponas al via biblioteko prunton de dokumentoj. La peto {loanRef} ĵus malfermiĝis. Por akcepti, priparoli aŭ organizi la prenon, kontaktu la personon indikitan sube. La detalo de la proponitaj dokumentoj estas pli sube."
  },
  "ill.intro.created.borrower_initiator": {
    "pt-BR": "Sua biblioteca acaba de solicitar um empréstimo de documentos a {lender}. O pedido {loanRef} está registrado. {lender} foi informada e responderá para dar seguimento a este pedido. O detalhe dos documentos solicitados está abaixo.",
    fr: "Votre bibliothèque vient de solliciter un emprunt de documents auprès de {lender}. La demande {loanRef} est enregistrée. {lender} en est informée et vous répondra pour donner suite à cette demande. Le détail des documents demandés figure ci-dessous.",
    es: "Tu biblioteca acaba de solicitar un préstamo de documentos a {lender}. La solicitud {loanRef} está registrada. {lender} ha sido informada y os responderá para dar curso a esta solicitud. El detalle de los documentos solicitados está abajo.",
    en: "Your library has just requested a loan of documents from {lender}. Request {loanRef} is registered. {lender} has been notified and will reply to take this request forward. The list of documents requested is below.",
    it: "La vostra biblioteca ha appena richiesto un prestito di documenti a {lender}. La richiesta {loanRef} è registrata. {lender} è stata informata e vi risponderà per dare seguito a questa richiesta. Il dettaglio dei documenti richiesti è qui sotto.",
    de: "Eure Bibliothek hat soeben eine Ausleihe von Dokumenten bei {lender} angefragt. Die Anfrage {loanRef} ist registriert. {lender} wurde benachrichtigt und wird antworten, um diese Anfrage weiterzuverfolgen. Die Liste der angefragten Dokumente steht unten.",
    ca: "La vostra biblioteca acaba de sol·licitar un préstec de documents a {lender}. La sol·licitud {loanRef} està registrada. {lender} ha estat informada i us respondrà per donar curs a aquesta sol·licitud. El detall dels documents sol·licitats és a sota.",
    eo: "Via biblioteko ĵus petis prunton de dokumentoj de {lender}. La peto {loanRef} estas registrita. {lender} estis informita kaj respondos por daŭrigi ĉi tiun peton. La detalo de la petitaj dokumentoj estas sube."
  },
  "ill.intro.created.lender_partner": {
    "pt-BR": "{borrower} solicita à sua biblioteca um empréstimo de documentos. O pedido {loanRef} acaba de ser aberto. Para responder, conversar ou organizar o envio, entre em contato com a pessoa indicada abaixo. O detalhe dos documentos solicitados está mais abaixo.",
    fr: "{borrower} sollicite auprès de votre bibliothèque un emprunt de documents. La demande {loanRef} vient d'être ouverte. Pour répondre, en discuter ou organiser l'envoi, contactez la personne indiquée ci-dessous. Le détail des documents demandés figure plus bas.",
    es: "{borrower} solicita a tu biblioteca un préstamo de documentos. La solicitud {loanRef} acaba de abrirse. Para responder, conversar u organizar el envío, contacta a la persona indicada abajo. El detalle de los documentos solicitados está más abajo.",
    en: "{borrower} is requesting a loan of documents from your library. Request {loanRef} has just been opened. To reply, discuss it or arrange dispatch, contact the person indicated below. The list of documents requested is further down.",
    it: "{borrower} richiede alla vostra biblioteca un prestito di documenti. La richiesta {loanRef} è appena stata aperta. Per rispondere, discuterne o organizzare l'invio, contattate la persona indicata qui sotto. Il dettaglio dei documenti richiesti è più in basso.",
    de: "{borrower} fragt bei eurer Bibliothek eine Ausleihe von Dokumenten an. Die Anfrage {loanRef} wurde soeben eröffnet. Um zu antworten, zu besprechen oder den Versand zu organisieren, wendet euch an die unten genannte Person. Die Liste der angefragten Dokumente steht weiter unten.",
    ca: "{borrower} sol·licita a la vostra biblioteca un préstec de documents. La sol·licitud {loanRef} acaba d'obrir-se. Per respondre, parlar-ne o organitzar l'enviament, contacteu la persona indicada a sota. El detall dels documents sol·licitats és més avall.",
    eo: "{borrower} petas de via biblioteko prunton de dokumentoj. La peto {loanRef} ĵus malfermiĝis. Por respondi, priparoli aŭ organizi la sendon, kontaktu la personon indikitan sube. La detalo de la petitaj dokumentoj estas pli sube."
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
    eo: "La interbiblioteka prunto {loanRef} inter {lender} kaj {borrower} nun estas preparita. La dokumentoj estas kunigitaj kaj pretaj por foriri. La detalo estas sube."
  },
  "ill.intro.dispatched": {
    "pt-BR": "Os documentos do empréstimo interbibliotecas {loanRef} estão em circulação entre {lender} e {borrower}. Conforme o modo combinado, viajam pelo correio ou em mãos. O detalhe está abaixo.",
    fr: "Les documents du prêt interbibliothèques {loanRef} sont en circulation entre {lender} et {borrower}. Selon le mode convenu, ils voyagent par voie postale ou de la main à la main. Le détail figure ci-dessous.",
    es: "Los documentos del préstamo interbibliotecario {loanRef} están en circulación entre {lender} y {borrower}. Según el modo acordado, viajan por correo o en mano. El detalle está abajo.",
    en: "The documents of interlibrary loan {loanRef} are in transit between {lender} and {borrower}. Depending on the agreed method, they travel by post or hand to hand. The details are below.",
    it: "I documenti del prestito interbibliotecario {loanRef} sono in circolazione tra {lender} e {borrower}. Secondo il modo concordato, viaggiano per posta o a mano. Il dettaglio è qui sotto.",
    de: "Die Dokumente der Fernleihe {loanRef} sind zwischen {lender} und {borrower} unterwegs. Je nach vereinbarter Art reisen sie per Post oder von Hand zu Hand. Die Einzelheiten stehen unten.",
    ca: "Els documents del préstec interbibliotecari {loanRef} estan en circulació entre {lender} i {borrower}. Segons el mode acordat, viatgen per correu o en mà. El detall és a sota.",
    eo: "La dokumentoj de la interbiblioteka prunto {loanRef} estas en cirkulado inter {lender} kaj {borrower}. Laŭ la interkonsentita maniero, ili vojaĝas poŝte aŭ man-al-mane. La detalo estas sube."
  },
  "ill.intro.return_started": {
    "pt-BR": "A devolução do empréstimo interbibliotecas {loanRef} entre {lender} e {borrower} acaba de ser iniciada. Os documentos fazem o caminho de volta. O detalhe está abaixo.",
    fr: "Le retour du prêt interbibliothèques {loanRef} entre {lender} et {borrower} vient d'être amorcé. Les documents font le chemin inverse. Le détail figure ci-dessous.",
    es: "La devolución del préstamo interbibliotecario {loanRef} entre {lender} y {borrower} acaba de iniciarse. Los documentos hacen el camino de vuelta. El detalle está abajo.",
    en: "The return of interlibrary loan {loanRef} between {lender} and {borrower} has just started. The documents are making the journey back. The details are below.",
    it: "La restituzione del prestito interbibliotecario {loanRef} tra {lender} e {borrower} è appena stata avviata. I documenti fanno il percorso inverso. Il dettaglio è qui sotto.",
    de: "Die Rückgabe der Fernleihe {loanRef} zwischen {lender} und {borrower} hat soeben begonnen. Die Dokumente treten den Rückweg an. Die Einzelheiten stehen unten.",
    ca: "La devolució del préstec interbibliotecari {loanRef} entre {lender} i {borrower} acaba d'iniciar-se. Els documents fan el camí de tornada. El detall és a sota.",
    eo: "La redono de la interbiblioteka prunto {loanRef} inter {lender} kaj {borrower} ĵus komenciĝis. La dokumentoj faras la revojon. La detalo estas sube."
  },
  "ill.intro.returned": {
    "pt-BR": "O empréstimo interbibliotecas {loanRef} entre {lender} e {borrower} está encerrado. Os documentos voltaram à sua biblioteca. Um acervo circulou de um coletivo a outro: é assim que vivem nossas bibliotecas.",
    fr: "Le prêt interbibliothèques {loanRef} entre {lender} et {borrower} est clôturé. Les documents ont regagné leur bibliothèque. Un fonds a circulé d'un collectif vers un autre : c'est ainsi que vivent nos bibliothèques.",
    es: "El préstamo interbibliotecario {loanRef} entre {lender} y {borrower} está cerrado. Los documentos han vuelto a su biblioteca. Un fondo ha circulado de un colectivo a otro: así es como viven nuestras bibliotecas.",
    en: "Interlibrary loan {loanRef} between {lender} and {borrower} is closed. The documents have returned to their library. A collection has travelled from one collective to another: this is how our libraries live.",
    it: "Il prestito interbibliotecario {loanRef} tra {lender} e {borrower} è concluso. I documenti sono tornati alla loro biblioteca. Un fondo è circolato da un collettivo all'altro: è così che vivono le nostre biblioteche.",
    de: "Die Fernleihe {loanRef} zwischen {lender} und {borrower} ist abgeschlossen. Die Dokumente sind in ihre Bibliothek zurückgekehrt. Ein Bestand ist von einem Kollektiv zum anderen gewandert: so leben unsere Bibliotheken.",
    ca: "El préstec interbibliotecari {loanRef} entre {lender} i {borrower} està tancat. Els documents han tornat a la seva biblioteca. Un fons ha circulat d'un col·lectiu a un altre: així és com viuen les nostres biblioteques.",
    eo: "La interbiblioteka prunto {loanRef} inter {lender} kaj {borrower} estas fermita. La dokumentoj revenis al sia biblioteko. Kolekto cirkulis de unu kolektivo al alia: tiel vivas niaj bibliotekoj."
  },
  "ill.intro.cancelled": {
    "pt-BR": "O empréstimo interbibliotecas {loanRef} entre {lender} e {borrower} foi cancelado. Nenhuma troca ocorrerá no âmbito deste pedido. Para qualquer dúvida, as duas bibliotecas podem se contatar diretamente.",
    fr: "Le prêt interbibliothèques {loanRef} entre {lender} et {borrower} a été annulé. Aucun échange n'aura lieu dans le cadre de cette demande. Pour toute question, les deux bibliothèques peuvent se rapprocher directement.",
    es: "El préstamo interbibliotecario {loanRef} entre {lender} y {borrower} ha sido cancelado. No habrá ningún intercambio en el marco de esta solicitud. Para cualquier duda, las dos bibliotecas pueden contactarse directamente.",
    en: "Interlibrary loan {loanRef} between {lender} and {borrower} has been cancelled. No exchange will take place under this request. For any question, the two libraries can get in touch directly.",
    it: "Il prestito interbibliotecario {loanRef} tra {lender} e {borrower} è stato annullato. Nessuno scambio avrà luogo nell'ambito di questa richiesta. Per qualsiasi domanda, le due biblioteche possono contattarsi direttamente.",
    de: "Die Fernleihe {loanRef} zwischen {lender} und {borrower} wurde storniert. Im Rahmen dieser Anfrage findet kein Austausch statt. Bei Fragen können sich die beiden Bibliotheken direkt miteinander in Verbindung setzen.",
    ca: "El préstec interbibliotecari {loanRef} entre {lender} i {borrower} ha estat anul·lat. No hi haurà cap intercanvi en el marc d'aquesta sol·licitud. Per a qualsevol dubte, les dues biblioteques poden contactar-se directament.",
    eo: "La interbiblioteka prunto {loanRef} inter {lender} kaj {borrower} estis nuligita. Neniu interŝanĝo okazos en la kadro de ĉi tiu peto. Por iu ajn demando, la du bibliotekoj povas rekte interkontaktiĝi."
  },
  "ill.intro.overdue": {
    "pt-BR": "O empréstimo interbibliotecas {loanRef} entre {lender} e {borrower} ultrapassou a data de devolução prevista. As duas bibliotecas são convidadas a se aproximar para fazer o ponto sobre a situação dos documentos. O detalhe está abaixo.",
    fr: "Le prêt interbibliothèques {loanRef} entre {lender} et {borrower} a dépassé sa date de retour prévue. Les deux bibliothèques sont invitées à se rapprocher pour faire le point sur la situation des documents. Le détail figure ci-dessous.",
    es: "El préstamo interbibliotecario {loanRef} entre {lender} y {borrower} ha superado su fecha de devolución prevista. Se invita a las dos bibliotecas a ponerse en contacto para hacer el punto sobre la situación de los documentos. El detalle está abajo.",
    en: "Interlibrary loan {loanRef} between {lender} and {borrower} has passed its expected return date. Both libraries are invited to get in touch to take stock of where the documents stand. The details are below.",
    it: "Il prestito interbibliotecario {loanRef} tra {lender} e {borrower} ha superato la data di restituzione prevista. Le due biblioteche sono invitate a mettersi in contatto per fare il punto sulla situazione dei documenti. Il dettaglio è qui sotto.",
    de: "Die Fernleihe {loanRef} zwischen {lender} und {borrower} hat ihr vorgesehenes Rückgabedatum überschritten. Beide Bibliotheken sind eingeladen, sich abzustimmen, um den Stand der Dokumente zu klären. Die Einzelheiten stehen unten.",
    ca: "El préstec interbibliotecari {loanRef} entre {lender} i {borrower} ha superat la data de devolució prevista. Es convida les dues biblioteques a posar-se en contacte per fer el punt sobre la situació dels documents. El detall és a sota.",
    eo: "La interbiblioteka prunto {loanRef} inter {lender} kaj {borrower} preterpasis sian antaŭviditan redatan daton. La du bibliotekoj estas invitataj interkontaktiĝi por pripensi la situacion de la dokumentoj. La detalo estas sube."
  },
  "ill.intro.partially_returned": {
    "pt-BR": "O empréstimo interbibliotecas {loanRef} entre {lender} e {borrower} foi parcialmente devolvido. Uma parte dos documentos voltou à sua biblioteca; o restante ainda está em circulação. O detalhe está abaixo, documento por documento.",
    fr: "Le prêt interbibliothèques {loanRef} entre {lender} et {borrower} est partiellement rendu. Une partie des documents a regagné sa bibliothèque ; le reste est encore en circulation. Le détail figure ci-dessous, document par document.",
    es: "El préstamo interbibliotecario {loanRef} entre {lender} y {borrower} ha sido devuelto parcialmente. Una parte de los documentos ha vuelto a su biblioteca; el resto sigue en circulación. El detalle está abajo, documento por documento.",
    en: "Interlibrary loan {loanRef} between {lender} and {borrower} has been partially returned. Some of the documents have returned to their library; the rest are still in transit. The details are below, document by document.",
    it: "Il prestito interbibliotecario {loanRef} tra {lender} e {borrower} è stato restituito parzialmente. Una parte dei documenti è tornata alla propria biblioteca; il resto è ancora in circolazione. Il dettaglio è qui sotto, documento per documento.",
    de: "Die Fernleihe {loanRef} zwischen {lender} und {borrower} wurde teilweise zurückgegeben. Ein Teil der Dokumente ist in seine Bibliothek zurückgekehrt; der Rest ist noch unterwegs. Die Einzelheiten stehen unten, Dokument für Dokument.",
    ca: "El préstec interbibliotecari {loanRef} entre {lender} i {borrower} ha estat retornat parcialment. Una part dels documents ha tornat a la seva biblioteca; la resta encara està en circulació. El detall és a sota, document per document.",
    eo: "La interbiblioteka prunto {loanRef} inter {lender} kaj {borrower} estis parte redonita. Parto de la dokumentoj revenis al sia biblioteko; la cetero ankoraŭ estas en cirkulado. La detalo estas sube, dokumento post dokumento."
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
    eo: "Por daŭrigi, kontaktu: {contact}"
  },

  // --- Libellés de détails (9) ---------------------------------------------
  "ill.detail.loanRef": {
    "pt-BR": "Referência do empréstimo", fr: "Référence du prêt",
    es: "Referencia del préstamo", en: "Loan reference",
    it: "Riferimento del prestito", de: "Leih-Referenz",
    ca: "Referència del préstec", eo: "Referenco de la prunto"
  },
  "ill.detail.lender": {
    "pt-BR": "Biblioteca emprestadora", fr: "Bibliothèque prêteuse",
    es: "Biblioteca prestadora", en: "Lending library",
    it: "Biblioteca prestatrice", de: "Verleihende Bibliothek",
    ca: "Biblioteca prestadora", eo: "Pruntedonanta biblioteko"
  },
  "ill.detail.borrower": {
    "pt-BR": "Biblioteca tomadora", fr: "Bibliothèque emprunteuse",
    es: "Biblioteca prestataria", en: "Borrowing library",
    it: "Biblioteca richiedente", de: "Entleihende Bibliothek",
    ca: "Biblioteca prestatària", eo: "Prunteprenanta biblioteko"
  },
  "ill.detail.startDate": {
    "pt-BR": "Data de partida", fr: "Date de départ",
    es: "Fecha de salida", en: "Start date",
    it: "Data di partenza", de: "Startdatum",
    ca: "Data de sortida", eo: "Ekdato"
  },
  "ill.detail.dueDate": {
    "pt-BR": "Devolução prevista", fr: "Retour prévu",
    es: "Devolución prevista", en: "Expected return",
    it: "Restituzione prevista", de: "Erwartete Rückgabe",
    ca: "Devolució prevista", eo: "Antaŭvidita redono"
  },
  "ill.detail.logistics": {
    "pt-BR": "Logística", fr: "Logistique",
    es: "Logística", en: "Logistics",
    it: "Logistica", de: "Logistik",
    ca: "Logística", eo: "Loĝistiko"
  },
  "ill.detail.meetingPoint": {
    "pt-BR": "Ponto de encontro", fr: "Point de rencontre",
    es: "Punto de encuentro", en: "Meeting point",
    it: "Punto d'incontro", de: "Treffpunkt",
    ca: "Punt de trobada", eo: "Renkontiĝejo"
  },
  "ill.detail.itemCount": {
    "pt-BR": "Número de documentos", fr: "Nombre de documents",
    es: "Número de documentos", en: "Number of documents",
    it: "Numero di documenti", de: "Anzahl der Dokumente",
    ca: "Nombre de documents", eo: "Nombro de dokumentoj"
  },
  "ill.detail.itemLine": {
    "pt-BR": "Documento", fr: "Document",
    es: "Documento", en: "Document",
    it: "Documento", de: "Dokument",
    ca: "Document", eo: "Dokumento"
  },

  // --- Logistique (1) ------------------------------------------------------
  "ill.logistics.a_combinar": {
    "pt-BR": "A combinar", fr: "À convenir",
    es: "A convenir", en: "To be arranged",
    it: "Da concordare", de: "Noch festzulegen",
    ca: "A convenir", eo: "Interkonsentota"
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
    eo: "Rezervita por la foriro"
  },
  "ill.itemStatus.emprestado": {
    "pt-BR": "Ainda em circulação",
    fr: "Encore en circulation",
    es: "Aún en circulación",
    en: "Still in circulation",
    it: "Ancora in circolazione",
    de: "Noch unterwegs",
    ca: "Encara en circulació",
    eo: "Ankoraŭ en cirkulado"
  },
  "ill.itemStatus.devolvido": {
    "pt-BR": "Devolvido",
    fr: "Rendu",
    es: "Devuelto",
    en: "Returned",
    it: "Restituito",
    de: "Zurückgegeben",
    ca: "Retornat",
    eo: "Redonita"
  },
  "ill.itemStatus.perdido": {
    "pt-BR": "Perdido",
    fr: "Perdu",
    es: "Perdido",
    en: "Lost",
    it: "Perduto",
    de: "Verloren",
    ca: "Perdut",
    eo: "Perdita"
  },
  "ill.itemStatus.danificado": {
    "pt-BR": "Danificado",
    fr: "Endommagé",
    es: "Dañado",
    en: "Damaged",
    it: "Danneggiato",
    de: "Beschädigt",
    ca: "Malmès",
    eo: "Difektita"
  },
  "ill.itemStatus.cancelado": {
    "pt-BR": "Retirado do empréstimo",
    fr: "Retiré du prêt",
    es: "Retirado del préstamo",
    en: "Removed from the loan",
    it: "Rimosso dal prestito",
    de: "Aus der Leihe entfernt",
    ca: "Retirat del préstec",
    eo: "Forigita el la prunto"
  },
  "ill.detail.returnSummary": {
    "pt-BR": "Balanço da devolução",
    fr: "Bilan du retour",
    es: "Balance de la devolución",
    en: "Return summary",
    it: "Bilancio della restituzione",
    de: "Rückgabe-Übersicht",
    ca: "Balanç de la devolució",
    eo: "Bilanco de la redono"
  },
  "ill.detail.returnSummaryValue": {
    "pt-BR": "{settled} resolvido(s), {outstanding} ainda em circulação",
    fr: "{settled} réglé(s), {outstanding} encore en circulation",
    es: "{settled} resuelto(s), {outstanding} aún en circulación",
    en: "{settled} settled, {outstanding} still in circulation",
    it: "{settled} risolto(i), {outstanding} ancora in circolazione",
    de: "{settled} erledigt, {outstanding} noch unterwegs",
    ca: "{settled} resolt(s), {outstanding} encara en circulació",
    eo: "{settled} solvita(j), {outstanding} ankoraŭ en cirkulado"
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
    eo: "Poŝta sendo"
  },
  "ill.logistics.entrega_em_maos": {
    "pt-BR": "Entrega em mãos",
    fr: "Remise en main propre",
    es: "Entrega en mano",
    en: "Hand delivery",
    it: "Consegna a mano",
    de: "Persönliche Übergabe",
    ca: "Lliurament en mà",
    eo: "Enmana transdono"
  },
  "ill.logistics.transporte_militante": {
    "pt-BR": "Transporte militante",
    fr: "Portage militant",
    es: "Transporte militante",
    en: "Militant carriage",
    it: "Trasporto militante",
    de: "Militante Beförderung",
    ca: "Transport militant",
    eo: "Aktivisma transporto"
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
  return ["pt-BR", "fr", "es", "en", "it", "de", "ca", "eo"];
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

