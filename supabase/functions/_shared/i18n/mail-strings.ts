// ============================================================================
// mail-strings.ts Ã¢â‚¬â€ i18n des notifications mail (Edge Function notify-event)
// ============================================================================
// 6 locales : pt-BR (rÃƒÂ©fÃƒÂ©rence), fr, es, en, it, de
//
// Conventions militantes par locale :
//   pt-BR : triple forme o/a/e, dÃƒÂ©monstratifs binÃƒÂ´me dest(e/a),
//           contractions article-prÃƒÂ©position triples d(o/a/e)
//   fr    : point mÃƒÂ©dian (lecteurÃ‚Â·rice, leÃ‚Â·la)
//   es    : neutre argentin e (le, les, une, conectade), participes accordÃƒÂ©s
//   en    : neutre standard (ÃƒÂ©picÃƒÂ¨ne)
//   it    : compagno/a/e ou variantes, JAMAIS camerata
//   de    : Genderstern (Leser*in, Genoss*in), JAMAIS "Compas"
//
// Date du fix : 2026-05-02 (chasse au bug wf.ready / wf.readyShort affichÃƒÂ©s
//               en clÃƒÂ©s brutes dans les mails Ã¢â‚¬â€ clÃƒÂ©s manquantes du dictionnaire)
// ============================================================================

export type SupportedMailLocale = "pt-BR" | "fr" | "es" | "en" | "it" | "de";

const V = new Set<string>(["pt-BR", "fr", "es", "en", "it", "de"]);

const S: Record<string, Record<SupportedMailLocale, string>> = {

  // ===== Greetings ==========================================================
  "greeting.named": {
    "pt-BR": "OlÃƒÂ¡, {name}!",
    fr: "Bonjour, {name} !",
    es: "Ã‚Â¡Hola, {name}!",
    en: "Hello, {name}!",
    it: "Ciao, {name}!",
    de: "Hallo, {name}!"
  },
  "greeting.anonymous": {
    "pt-BR": "OlÃƒÂ¡!",
    fr: "Bonjour !",
    es: "Ã‚Â¡Hola!",
    en: "Hello!",
    it: "Ciao!",
    de: "Hallo!"
  },

  // ===== Layout =============================================================
  "layout.autoNotice": {
    "pt-BR": "NotificaÃƒÂ§ÃƒÂ£o automÃƒÂ¡tica",
    fr: "Notification automatique",
    es: "NotificaciÃƒÂ³n automÃƒÂ¡tica",
    en: "Automatic notification",
    it: "Notifica automatica",
    de: "Automatische Benachrichtigung"
  },
  "layout.footerContact": {
    "pt-BR": "Em caso de dÃƒÂºvida, entre em contato com a biblioteca.",
    fr: "En cas de question, contacte la bibliothÃƒÂ¨que.",
    es: "En caso de duda, contacta la biblioteca.",
    en: "If in doubt, contact the library.",
    it: "In caso di dubbi, contatta la biblioteca.",
    de: "Bei Fragen wende dich an die Bibliothek."
  },
  "layout.keepMsg": {
    "pt-BR": "Guarde esta mensagem.",
    fr: "Conserve ce message.",
    es: "Guarda este mensaje.",
    en: "Keep this message.",
    it: "Conserva questo messaggio.",
    de: "Bewahre diese Nachricht auf."
  },

  // ===== Labels (l.*) =======================================================
  "l.book": {
    "pt-BR": "Livro",
    fr: "Document",
    es: "Libro",
    en: "Book",
    it: "Libro",
    de: "Buch"
  },
  "l.items": {
    "pt-BR": "Itens",
    fr: "Documents",
    es: "Documentos",
    en: "Items",
    it: "Documenti",
    de: "Dokumente"
  },
  "l.itemsReturned": {
    "pt-BR": "Documentos devolvidos",
    fr: "Documents rendus",
    es: "Documentos devueltos",
    en: "Documents returned",
    it: "Documenti restituiti",
    de: "ZurÃƒÂ¼ckgegebene Dokumente"
  },
  "l.itemsRemaining": {
    "pt-BR": "Documentos ainda em mÃƒÂ£os",
    fr: "Documents encore ÃƒÂ  rendre",
    es: "Documentos todavÃƒÂ­a pendientes",
    en: "Documents still to return",
    it: "Documenti ancora da restituire",
    de: "Noch zurÃƒÂ¼ckzugebende Dokumente"
  },
  "l.ref": {
    "pt-BR": "ReferÃƒÂªncia",
    fr: "RÃƒÂ©fÃƒÂ©rence",
    es: "Referencia",
    en: "Reference",
    it: "Riferimento",
    de: "Referenz"
  },
  "l.refs": {
    "pt-BR": "ReferÃƒÂªncias",
    fr: "RÃƒÂ©fÃƒÂ©rences",
    es: "Referencias",
    en: "References",
    it: "Riferimenti",
    de: "Referenzen"
  },
  "l.ids": {
    "pt-BR": "IDs",
    fr: "IDs",
    es: "IDs",
    en: "IDs",
    it: "IDs",
    de: "IDs"
  },
  "l.date": {
    "pt-BR": "Data",
    fr: "Date",
    es: "Fecha",
    en: "Date",
    it: "Data",
    de: "Datum"
  },
  "l.dueDate": {
    "pt-BR": "DevoluÃƒÂ§ÃƒÂ£o prevista",
    fr: "Retour prÃƒÂ©vu",
    es: "DevoluciÃƒÂ³n prevista",
    en: "Due date",
    it: "Restituzione prevista",
    de: "FÃƒÂ¤lligkeitsdatum"
  },
  "l.newDueDate": {
    "pt-BR": "Nova devoluÃƒÂ§ÃƒÂ£o",
    fr: "Nouveau retour",
    es: "Nueva devoluciÃƒÂ³n",
    en: "New due date",
    it: "Nuova restituzione",
    de: "Neues FÃƒÂ¤lligkeitsdatum"
  },
  "l.deadline": {
    "pt-BR": "Prazo",
    fr: "Ãƒâ€°chÃƒÂ©ance",
    es: "Plazo",
    en: "Deadline",
    it: "Scadenza",
    de: "Frist"
  },
  "l.registration": {
    "pt-BR": "Registro",
    fr: "Enregistrement",
    es: "Registro",
    en: "Registration",
    it: "Registrazione",
    de: "Registrierung"
  },
  "l.renewal": {
    "pt-BR": "RenovaÃƒÂ§ÃƒÂ£o em",
    fr: "RenouvelÃƒÂ© le",
    es: "RenovaciÃƒÂ³n el",
    en: "Renewed on",
    it: "Rinnovo il",
    de: "VerlÃƒÂ¤ngert am"
  },
  "l.return": {
    "pt-BR": "DevoluÃƒÂ§ÃƒÂ£o",
    fr: "Retour",
    es: "DevoluciÃƒÂ³n",
    en: "Return",
    it: "Restituzione",
    de: "RÃƒÂ¼ckgabe"
  },
  "l.reader": {
    "pt-BR": "Leitor(a/e)",
    fr: "LecteurÃ‚Â·rice",
    es: "Lector(a/e)",
    en: "Reader",
    it: "Lettore/trice",
    de: "Leser*in"
  },
  "l.pickup": {
    "pt-BR": "Retirada",
    fr: "Retrait",
    es: "Retiro",
    en: "Pickup",
    it: "Ritiro",
    de: "Abholung"
  },
  "l.status": {
    "pt-BR": "SituaÃƒÂ§ÃƒÂ£o",
    fr: "Situation",
    es: "SituaciÃƒÂ³n",
    en: "Status",
    it: "Situazione",
    de: "Status"
  },
  "l.reason": {
    "pt-BR": "Motivo",
    fr: "Motif",
    es: "Motivo",
    en: "Reason",
    it: "Motivo",
    de: "Grund"
  },
  "l.note": {
    "pt-BR": "ObservaÃƒÂ§ÃƒÂ£o",
    fr: "Observation",
    es: "ObservaciÃƒÂ³n",
    en: "Note",
    it: "Osservazione",
    de: "Anmerkung"
  },
  "l.contact": {
    "pt-BR": "Contato",
    fr: "Contact",
    es: "Contacto",
    en: "Contact",
    it: "Contatto",
    de: "Kontakt"
  },
  "l.task": {
    "pt-BR": "Tarefa",
    fr: "TÃƒÂ¢che",
    es: "Tarea",
    en: "Task",
    it: "Compito",
    de: "Aufgabe"
  },
  "l.priority": {
    "pt-BR": "Prioridade",
    fr: "PrioritÃƒÂ©",
    es: "Prioridad",
    en: "Priority",
    it: "PrioritÃƒÂ ",
    de: "PrioritÃƒÂ¤t"
  },
  "l.tags": {
    "pt-BR": "Marcadores",
    fr: "Ãƒâ€°tiquettes",
    es: "Etiquetas",
    en: "Tags",
    it: "Etichette",
    de: "SchlagwÃƒÂ¶rter"
  },
  "l.firstDate": {
    "pt-BR": "PrÃƒÂ³ximo vencimento",
    fr: "Prochaine ÃƒÂ©chÃƒÂ©ance",
    es: "PrÃƒÂ³ximo vencimiento",
    en: "Next due date",
    it: "Prossima scadenza",
    de: "NÃƒÂ¤chste FÃƒÂ¤lligkeit"
  },
  "l.pendingItems": {
    "pt-BR": "Itens pendentes",
    fr: "Documents en cours",
    es: "Documentos pendientes",
    en: "Pending items",
    it: "Documenti in corso",
    de: "Offene Dokumente"
  },
  "l.readerNote": {
    "pt-BR": "ObservaÃƒÂ§ÃƒÂ£o d(o/a/e) leitor(a/e)",
    fr: "Note duÃ‚Â·de la lecteurÃ‚Â·rice",
    es: "Nota de le lector(a/e)",
    en: "Reader note",
    it: "Nota del/la lettore/trice",
    de: "Anmerkung der*des Leser*in"
  },
  "l.reply": {
    "pt-BR": "Resposta",
    fr: "RÃƒÂ©ponse",
    es: "Respuesta",
    en: "Reply",
    it: "Risposta",
    de: "Antwort"
  },
  "l.restrictedSince": {
    "pt-BR": "RestriÃƒÂ§ÃƒÂ£o desde",
    fr: "Restriction depuis",
    es: "RestricciÃƒÂ³n desde",
    en: "Restricted since",
    it: "Restrizione da",
    de: "EingeschrÃƒÂ¤nkt seit"
  },

  // ===== Reservation events (res.*) =========================================
  "res.created.sub": {
    "pt-BR": "Reserva registrada",
    fr: "RÃƒÂ©servation enregistrÃƒÂ©e",
    es: "Reserva registrada",
    en: "Reservation registered",
    it: "Prenotazione registrata",
    de: "Vormerkung registriert"
  },
  "res.created.pre": {
    "pt-BR": "Sua reserva foi registrada com sucesso.",
    fr: "Ta rÃƒÂ©servation a bien ÃƒÂ©tÃƒÂ© enregistrÃƒÂ©e.",
    es: "Tu reserva fue registrada con ÃƒÂ©xito.",
    en: "Your reservation has been registered.",
    it: "La tua prenotazione ÃƒÂ¨ stata registrata.",
    de: "Deine Vormerkung wurde registriert."
  },
  "res.created.intro": {
    "pt-BR": "Recebemos sua reserva. A biblioteca confirmarÃƒÂ¡ a disponibilidade em breve.",
    fr: "Nous avons reÃƒÂ§u ta rÃƒÂ©servation. La bibliothÃƒÂ¨que confirmera bientÃƒÂ´t la disponibilitÃƒÂ©.",
    es: "Recibimos tu reserva. La biblioteca confirmarÃƒÂ¡ pronto la disponibilidad.",
    en: "We received your reservation. The library will confirm availability soon.",
    it: "Abbiamo ricevuto la tua prenotazione. La biblioteca confermerÃƒÂ  presto la disponibilitÃƒÂ .",
    de: "Wir haben deine Vormerkung erhalten. Die Bibliothek bestÃƒÂ¤tigt bald die VerfÃƒÂ¼gbarkeit."
  },
  "res.created.hint": {
    "pt-BR": "VocÃƒÂª pode acompanhar o estado d(o/a/e) seu pedido na sua conta.",
    fr: "Tu peux suivre l'ÃƒÂ©tat de ta demande dans ton compte.",
    es: "Puedes seguir le estade de tu pedido en tu cuenta.",
    en: "You can track your request status in your account.",
    it: "Puoi seguire lo stato della tua richiesta nel tuo account.",
    de: "Du kannst den Status deiner Anfrage in deinem Konto verfolgen."
  },
  "res.created.admin": {
    "pt-BR": "Nova reserva registrada",
    fr: "Nouvelle rÃƒÂ©servation enregistrÃƒÂ©e",
    es: "Nueva reserva registrada",
    en: "New reservation registered",
    it: "Nuova prenotazione registrata",
    de: "Neue Vormerkung registriert"
  },
  "res.refused": {
    "pt-BR": "Reserva recusada pela biblioteca",
    fr: "RÃƒÂ©servation refusÃƒÂ©e par la bibliothÃƒÂ¨que",
    es: "Reserva rechazada por la biblioteca",
    en: "Reservation declined by the library",
    it: "Prenotazione rifiutata dalla biblioteca",
    de: "Vormerkung von der Bibliothek abgelehnt"
  },
  "res.cancelStaff": {
    "pt-BR": "Reserva cancelada pela biblioteca",
    fr: "RÃƒÂ©servation annulÃƒÂ©e par la bibliothÃƒÂ¨que",
    es: "Reserva cancelada por la biblioteca",
    en: "Reservation cancelled by the library",
    it: "Prenotazione annullata dalla biblioteca",
    de: "Vormerkung von der Bibliothek storniert"
  },
  "res.cancelReader": {
    "pt-BR": "Reserva cancelada por vocÃƒÂª",
    fr: "RÃƒÂ©servation annulÃƒÂ©e par toi",
    es: "Reserva cancelada por ti",
    en: "Reservation cancelled by you",
    it: "Prenotazione annullata da te",
    de: "Vormerkung von dir storniert"
  },
  "res.expired": {
    "pt-BR": "Reserva expirada",
    fr: "RÃƒÂ©servation expirÃƒÂ©e",
    es: "Reserva expirada",
    en: "Reservation expired",
    it: "Prenotazione scaduta",
    de: "Vormerkung abgelaufen"
  },
  "res.converted": {
    "pt-BR": "Reserva convertida em emprÃƒÂ©stimo",
    fr: "RÃƒÂ©servation convertie en emprunt",
    es: "Reserva convertide en prÃƒÂ©stamo",
    en: "Reservation converted into a loan",
    it: "Prenotazione convertita in prestito",
    de: "Vormerkung in Ausleihe umgewandelt"
  },

  // ===== Workflow events (wf.*) =============================================
  "wf.pickupScheduled": {
    "pt-BR": "Retirada agendada",
    fr: "Retrait programmÃƒÂ©",
    es: "Retiro programado",
    en: "Pickup scheduled",
    it: "Ritiro programmato",
    de: "Abholung geplant"
  },
  "wf.pickupRescheduled": {
    "pt-BR": "Retirada reagendada",
    fr: "Retrait reprogrammÃƒÂ©",
    es: "Retiro reprogramado",
    en: "Pickup rescheduled",
    it: "Ritiro riprogrammato",
    de: "Abholung neu geplant"
  },
  "wf.ready": {
    "pt-BR": "Sua reserva estÃƒÂ¡ pronta para retirada",
    fr: "Ta rÃƒÂ©servation est prÃƒÂªte ÃƒÂ  ÃƒÂªtre retirÃƒÂ©e",
    es: "Tu reserva estÃƒÂ¡ lista para retirar",
    en: "Your reservation is ready for pickup",
    it: "La tua prenotazione ÃƒÂ¨ pronta per il ritiro",
    de: "Deine Vormerkung liegt zur Abholung bereit"
  },
  "wf.readyShort": {
    "pt-BR": "Reserva pronta",
    fr: "RÃƒÂ©servation prÃƒÂªte",
    es: "Reserva lista",
    en: "Reservation ready",
    it: "Prenotazione pronta",
    de: "Vormerkung bereit"
  },
  "wf.noShow": {
    "pt-BR": "Retirada nÃƒÂ£o realizada",
    fr: "Retrait non effectuÃƒÂ©",
    es: "Retiro no realizado",
    en: "Pickup missed",
    it: "Ritiro non effettuato",
    de: "Abholung nicht erfolgt"
  },
  "wf.closed": {
    "pt-BR": "Reserva encerrada",
    fr: "RÃƒÂ©servation clÃƒÂ´turÃƒÂ©e",
    es: "Reserva cerrada",
    en: "Reservation closed",
    it: "Prenotazione chiusa",
    de: "Vormerkung abgeschlossen"
  },
  "wf.preparing": {
    "pt-BR": "Sua reserva estÃƒÂ¡ em preparaÃƒÂ§ÃƒÂ£o",
    fr: "Ta rÃƒÂ©servation est en prÃƒÂ©paration",
    es: "Tu reserva estÃƒÂ¡ en preparaciÃƒÂ³n",
    en: "Your reservation is being prepared",
    it: "La tua prenotazione ÃƒÂ¨ in preparazione",
    de: "Deine Vormerkung wird vorbereitet"
  },
  "wf.preparingShort": {
    "pt-BR": "Em preparaÃƒÂ§ÃƒÂ£o",
    fr: "En prÃƒÂ©paration",
    es: "En preparaciÃƒÂ³n",
    en: "Being prepared",
    it: "In preparazione",
    de: "In Vorbereitung"
  },
  "wf.toCoordinate": {
    "pt-BR": "Retirada a combinar com a biblioteca",
    fr: "Retrait ÃƒÂ  organiser avec la bibliothÃƒÂ¨que",
    es: "Retiro a coordinar con la biblioteca",
    en: "Pickup to be arranged with the library",
    it: "Ritiro da concordare con la biblioteca",
    de: "Abholung mit der Bibliothek abzustimmen"
  },
  "wf.toCoordinateShort": {
    "pt-BR": "A combinar",
    fr: "Ãƒâ‚¬ convenir",
    es: "A coordinar",
    en: "To arrange",
    it: "Da concordare",
    de: "Abzustimmen"
  },
    "wf.checkAccount": {
    "pt-BR": "Confira sua conta para mais detalhes.",
    fr: "Consulte ton compte pour plus de dÃƒÂ©tails.",
    es: "Consulte tu cuenta para mÃƒÂ¡s detalles.",
    en: "Check your account for more details.",
    it: "Controlla il tuo account per maggiori dettagli.",
    de: "Sieh in deinem Konto fÃƒÂ¼r weitere Details nach."
  },

  // ===== Workflow v3 Ã¢â‚¬â€ lecteur (wf.reader.*) ================================
  "wf.reader.libraryProposed.subject": {
    "pt-BR": "HorÃƒÂ¡rio de retirada proposto pela biblioteca",
    fr: "CrÃƒÂ©neau de retrait proposÃƒÂ© par la biblio",
    es: "Horario de retiro propuesto por la biblioteca",
    en: "Pickup slot proposed by the library",
    it: "Orario di ritiro proposto dalla biblioteca",
    de: "Abholtermin von der Bibliothek vorgeschlagen"
  },
  "wf.reader.libraryProposed.body": {
    "pt-BR": "A biblioteca propÃƒÂµe um horÃƒÂ¡rio para vocÃƒÂª vir retirar seu livro. VocÃƒÂª pode aceitar este horÃƒÂ¡rio, propor outro, ou cancelar a reserva pela sua conta.",
    fr: "La biblio te propose un crÃƒÂ©neau pour venir retirer ton livre. Tu peux accepter ce crÃƒÂ©neau, en proposer un autre, ou annuler ta rÃƒÂ©servation depuis ton compte.",
    es: "La biblioteca te propone un horario para venir a retirar tu libro. PodÃƒÂ©s aceptar este horario, proponer otro, o cancelar tu reserva desde tu cuenta.",
    en: "The library is proposing a time slot for you to come pick up your book. You can accept this slot, propose another one, or cancel your reservation from your account.",
    it: "La biblioteca ti propone un orario per venire a ritirare il tuo libro. Puoi accettare questo orario, proporne un altro, o annullare la tua prenotazione dal tuo account.",
    de: "Die Bibliothek schlÃƒÂ¤gt dir einen Termin vor, um dein Buch abzuholen. Du kannst diesen Termin annehmen, einen anderen vorschlagen oder deine Vormerkung ÃƒÂ¼ber dein Konto stornieren."
  },
  "wf.reader.youCounterProposed.subject": {
    "pt-BR": "Contra-proposta enviada (tentativa {iter}/{max})",
    fr: "Contre-proposition transmise (essai {iter}/{max})",
    es: "Contrapropuesta enviada (intento {iter}/{max})",
    en: "Counter-proposal sent (attempt {iter}/{max})",
    it: "Controproposta inviata (tentativo {iter}/{max})",
    de: "Gegenvorschlag gesendet (Versuch {iter}/{max})"
  },
  "wf.reader.youCounterProposed.body": {
    "pt-BR": "Sua contra-proposta foi enviada ÃƒÂ  biblioteca (tentativa {iter}/{max}). VocÃƒÂª serÃƒÂ¡ avisado(a/e) assim que ela responder.",
    fr: "Ta contre-proposition est bien transmise ÃƒÂ  la biblio (essai {iter}/{max}). Tu seras prÃƒÂ©venuÃ‚Â·e dÃƒÂ¨s que celle-ci rÃƒÂ©pond.",
    es: "Tu contrapropuesta fue enviada a la biblioteca (intento {iter}/{max}). SerÃƒÂ¡s avisade en cuanto te respondan.",
    en: "Your counter-proposal has been sent to the library (attempt {iter}/{max}). You will be notified as soon as they reply.",
    it: "La tua controproposta ÃƒÂ¨ stata inviata alla biblioteca (tentativo {iter}/{max}). Sarai avvisatÃ‰â„¢ non appena rispondano.",
    de: "Dein Gegenvorschlag wurde an die Bibliothek gesendet (Versuch {iter}/{max}). Du wirst benachrichtigt, sobald geantwortet wird."
  },
  "wf.reader.slotLocked.subject": {
    "pt-BR": "HorÃƒÂ¡rio de retirada confirmado",
    fr: "CrÃƒÂ©neau de retrait confirmÃƒÂ©",
    es: "Horario de retiro confirmado",
    en: "Pickup slot confirmed",
    it: "Orario di ritiro confermato",
    de: "Abholtermin bestÃƒÂ¤tigt"
  },
  "wf.reader.slotLocked.body": {
    "pt-BR": "O horÃƒÂ¡rio estÃƒÂ¡ confirmado e bloqueado. O livro estarÃƒÂ¡ em breve pronto para retirada Ã¢â‚¬â€ vocÃƒÂª receberÃƒÂ¡ uma notificaÃƒÂ§ÃƒÂ£o assim que isso acontecer.",
    fr: "Le crÃƒÂ©neau est confirmÃƒÂ© et verrouillÃƒÂ©. Le livre sera bientÃƒÂ´t prÃƒÂªt ÃƒÂ  retirer Ã¢â‚¬â€ tu recevras une notification dÃƒÂ¨s que ce sera le cas.",
    es: "El horario estÃƒÂ¡ confirmado y bloqueado. El libro estarÃƒÂ¡ pronto listo para retirar Ã¢â‚¬â€ recibirÃƒÂ¡s una notificaciÃƒÂ³n apenas eso suceda.",
    en: "The slot is confirmed and locked. The book will soon be ready for pickup Ã¢â‚¬â€ you will receive a notification as soon as that happens.",
    it: "L'orario ÃƒÂ¨ confermato e bloccato. Il libro sarÃƒÂ  presto pronto per il ritiro Ã¢â‚¬â€ riceverai una notifica appena ciÃƒÂ² accada.",
    de: "Der Termin ist bestÃƒÂ¤tigt und festgelegt. Das Buch wird bald zur Abholung bereit sein Ã¢â‚¬â€ du erhÃƒÂ¤ltst eine Benachrichtigung, sobald dies der Fall ist."
  },
  "wf.reader.maxIterations.subject": {
    "pt-BR": "NegociaÃƒÂ§ÃƒÂ£o sem acordo Ã¢â‚¬â€ contato direto recomendado",
    fr: "NÃƒÂ©gociation sans accord Ã¢â‚¬â€ contact direct conseillÃƒÂ©",
    es: "NegociaciÃƒÂ³n sin acuerdo Ã¢â‚¬â€ contacto directo recomendado",
    en: "Negotiation without agreement Ã¢â‚¬â€ direct contact advised",
    it: "Negoziazione senza accordo Ã¢â‚¬â€ contatto diretto consigliato",
    de: "Verhandlung ohne Einigung Ã¢â‚¬â€ direkter Kontakt empfohlen"
  },
  "wf.reader.maxIterations.body": {
    "pt-BR": "VÃƒÂ¡rias trocas sem encontrar um horÃƒÂ¡rio que funcione para todo mundo. Para continuar, o melhor ÃƒÂ© entrar em contato diretamente com a biblioteca para conversar.",
    fr: "Plusieurs allers-retours sans qu'on trouve un crÃƒÂ©neau qui convient ÃƒÂ  tout le monde. Pour continuer, le mieux est de contacter directement la biblio pour en discuter.",
    es: "Varios intercambios sin encontrar un horario que convenga a todes. Para continuar, lo mejor es contactar directamente a la biblioteca para conversar.",
    en: "Several exchanges without finding a time slot that works for everyone. To continue, the best is to contact the library directly to discuss.",
    it: "Diversi scambi senza trovare un orario che vada bene a tuttÃ‰â„¢. Per continuare, la cosa migliore ÃƒÂ¨ contattare direttamente la biblioteca per parlarne.",
    de: "Mehrere Versuche, ohne einen fÃƒÂ¼r alle passenden Termin zu finden. Um weiterzukommen, ist es am besten, sich direkt an die Bibliothek zu wenden, um darÃƒÂ¼ber zu sprechen."
  },
  "wf.reader.negotiationTimeout.subject": {
    "pt-BR": "Reserva liberada Ã¢â‚¬â€ prazo de negociaÃƒÂ§ÃƒÂ£o expirado",
    fr: "RÃƒÂ©servation libÃƒÂ©rÃƒÂ©e Ã¢â‚¬â€ dÃƒÂ©lai de nÃƒÂ©gociation dÃƒÂ©passÃƒÂ©",
    es: "Reserva liberada Ã¢â‚¬â€ plazo de negociaciÃƒÂ³n vencido",
    en: "Reservation released Ã¢â‚¬â€ negotiation deadline exceeded",
    it: "Prenotazione liberata Ã¢â‚¬â€ termine di negoziazione scaduto",
    de: "Vormerkung freigegeben Ã¢â‚¬â€ Verhandlungsfrist abgelaufen"
  },
  "wf.reader.negotiationTimeout.body": {
    "pt-BR": "A negociaÃƒÂ§ÃƒÂ£o do seu horÃƒÂ¡rio ultrapassou o prazo sem acordo. A reserva foi liberada e o livro voltou ÃƒÂ  circulaÃƒÂ§ÃƒÂ£o. VocÃƒÂª pode reservÃƒÂ¡-lo novamente quando quiser.",
    fr: "La nÃƒÂ©gociation pour ton crÃƒÂ©neau a dÃƒÂ©passÃƒÂ© le dÃƒÂ©lai sans accord. La rÃƒÂ©servation a ÃƒÂ©tÃƒÂ© libÃƒÂ©rÃƒÂ©e, le livre repart en circulation. Tu peux le rÃƒÂ©server ÃƒÂ  nouveau quand tu veux.",
    es: "La negociaciÃƒÂ³n de tu horario superÃƒÂ³ el plazo sin acuerdo. La reserva fue liberada, el libro vuelve a la circulaciÃƒÂ³n. PodÃƒÂ©s reservarlo nuevamente cuando quieras.",
    en: "The negotiation for your slot has exceeded the deadline without agreement. The reservation has been released, the book returns to circulation. You can reserve it again whenever you want.",
    it: "La negoziazione del tuo orario ha superato il termine senza accordo. La prenotazione ÃƒÂ¨ stata liberata, il libro torna in circolazione. Puoi prenotarlo di nuovo quando vuoi.",
    de: "Die Verhandlung ÃƒÂ¼ber deinen Termin hat die Frist ohne Einigung ÃƒÂ¼berschritten. Die Vormerkung wurde freigegeben, das Buch geht zurÃƒÂ¼ck in den Umlauf. Du kannst es jederzeit erneut vormerken."
  },

  // ===== Workflow v3 Ã¢â‚¬â€ biblio (wf.staff.*) ==================================
  "wf.staff.negotiationOpened.subject": {
    "pt-BR": "NegociaÃƒÂ§ÃƒÂ£o de horÃƒÂ¡rio aberta com o(a/e) leitor(a/e)",
    fr: "NÃƒÂ©gociation de crÃƒÂ©neau ouverte avec leÃ‚Â·la lecteurÃ‚Â·rice",
    es: "NegociaciÃƒÂ³n de horario abierta con le lectore",
    en: "Slot negotiation opened with the reader",
    it: "Negoziazione di orario aperta con lÃ‰â„¢ lettorÃ‰â„¢",
    de: "Terminverhandlung mit der*dem Leser*in erÃƒÂ¶ffnet"
  },
  "wf.staff.negotiationOpened.body": {
    "pt-BR": "A negociaÃƒÂ§ÃƒÂ£o de um horÃƒÂ¡rio de retirada foi aberta com o(a/e) leitor(a/e). O(a/e) leitor(a/e) foi avisado(a/e) por e-mail e pode aceitar, contra-propor ou cancelar pela prÃƒÂ³pria conta.",
    fr: "La nÃƒÂ©gociation d'un crÃƒÂ©neau de retrait a ÃƒÂ©tÃƒÂ© ouverte avec leÃ‚Â·la lecteurÃ‚Â·rice. LeÃ‚Â·la lecteurÃ‚Â·rice a ÃƒÂ©tÃƒÂ© prÃƒÂ©venuÃ‚Â·e par mail et peut accepter, contre-proposer ou annuler depuis son compte.",
    es: "Se abriÃƒÂ³ la negociaciÃƒÂ³n de un horario de retiro con le lectore. Le lectore fue avisade por correo y puede aceptar, contraproponer o cancelar desde su cuenta.",
    en: "A negotiation has been opened with the reader for a pickup slot. The reader has been notified by email and can accept, counter-propose, or cancel from their account.",
    it: "ÃƒË† stata aperta la negoziazione di un orario di ritiro con lÃ‰â„¢ lettorÃ‰â„¢. LÃ‰â„¢ lettorÃ‰â„¢ ÃƒÂ¨ statÃ‰â„¢ avvisatÃ‰â„¢ via email e puÃƒÂ² accettare, controproporre o annullare dal proprio account.",
    de: "Eine Verhandlung ÃƒÂ¼ber einen Abholtermin wurde mit der*dem Leser*in erÃƒÂ¶ffnet. Die*Der Leser*in wurde per E-Mail benachrichtigt und kann annehmen, gegenvorschlagen oder ÃƒÂ¼ber das eigene Konto stornieren."
  },
  "wf.staff.readerCounterProposed.subject": {
    "pt-BR": "Contra-proposta do(a/e) leitor(a/e) Ã¢â‚¬â€ aÃƒÂ§ÃƒÂ£o esperada",
    fr: "Contre-proposition duÃ‚Â·de la lecteurÃ‚Â·rice Ã¢â‚¬â€ action attendue",
    es: "Contrapropuesta de le lectore Ã¢â‚¬â€ acciÃƒÂ³n esperada",
    en: "Counter-proposal from the reader Ã¢â‚¬â€ action expected",
    it: "Controproposta di lÃ‰â„¢ lettorÃ‰â„¢ Ã¢â‚¬â€ azione attesa",
    de: "Gegenvorschlag der*des Leser*in Ã¢â‚¬â€ Aktion erwartet"
  },
  "wf.staff.readerCounterProposed.body": {
    "pt-BR": "O(a/e) leitor(a/e) contra-propÃƒÂ´s outro horÃƒÂ¡rio para a retirada. <b>Resposta esperada</b> : abrir o painel para aceitar, contra-propor por sua vez, ou cancelar.",
    fr: "LeÃ‚Â·la lecteurÃ‚Â·rice a contre-proposÃƒÂ© un autre crÃƒÂ©neau pour le retrait. <b>RÃƒÂ©ponse attendue</b> : ouvrir le tableau de bord pour accepter, contre-proposer ÃƒÂ  votre tour, ou annuler.",
    es: "Le lectore contrapropuso otro horario para el retiro. <b>Respuesta esperada</b> : abrir el panel para aceptar, contraproponer a su vez, o cancelar.",
    en: "The reader has counter-proposed another slot for the pickup. <b>Response expected</b> : open the dashboard to accept, counter-propose in turn, or cancel.",
    it: "LÃ‰â„¢ lettorÃ‰â„¢ ha controproposto un altro orario per il ritiro. <b>Risposta attesa</b> : aprire il pannello per accettare, controproporre a vostra volta, o annullare.",
    de: "Die*Der Leser*in hat einen anderen Termin fÃƒÂ¼r die Abholung vorgeschlagen. <b>Antwort erwartet</b> : Ãƒâ€“ffnet das Dashboard, um anzunehmen, einen Gegenvorschlag zu machen oder zu stornieren."
  },
  "wf.staff.readerAccepted.subject": {
    "pt-BR": "HorÃƒÂ¡rio aceito pelo(a/e) leitor(a/e)",
    fr: "CrÃƒÂ©neau acceptÃƒÂ© par leÃ‚Â·la lecteurÃ‚Â·rice",
    es: "Horario aceptado por le lectore",
    en: "Slot accepted by the reader",
    it: "Orario accettato da lÃ‰â„¢ lettorÃ‰â„¢",
    de: "Termin von der*dem Leser*in angenommen"
  },
  "wf.staff.readerAccepted.body": {
    "pt-BR": "O(a/e) leitor(a/e) aceitou o horÃƒÂ¡rio proposto. O horÃƒÂ¡rio estÃƒÂ¡ bloqueado Ã¢â‚¬â€ o livro pode ser preparado para a retirada.",
    fr: "LeÃ‚Â·la lecteurÃ‚Â·rice a acceptÃƒÂ© le crÃƒÂ©neau proposÃƒÂ©. Le crÃƒÂ©neau est verrouillÃƒÂ© Ã¢â‚¬â€ le livre peut ÃƒÂªtre prÃƒÂ©parÃƒÂ© pour le retrait.",
    es: "Le lectore aceptÃƒÂ³ el horario propuesto. El horario estÃƒÂ¡ bloqueado Ã¢â‚¬â€ el libro puede ser preparado para el retiro.",
    en: "The reader has accepted the proposed slot. The slot is locked Ã¢â‚¬â€ the book can be prepared for pickup.",
    it: "LÃ‰â„¢ lettorÃ‰â„¢ ha accettato l'orario proposto. L'orario ÃƒÂ¨ bloccato Ã¢â‚¬â€ il libro puÃƒÂ² essere preparato per il ritiro.",
    de: "Die*Der Leser*in hat den vorgeschlagenen Termin angenommen. Der Termin ist festgelegt Ã¢â‚¬â€ das Buch kann fÃƒÂ¼r die Abholung vorbereitet werden."
  },
  "wf.staff.staffConfirmed.subject": {
    "pt-BR": "HorÃƒÂ¡rio do(a/e) leitor(a/e) confirmado",
    fr: "CrÃƒÂ©neau duÃ‚Â·de la lecteurÃ‚Â·rice confirmÃƒÂ©",
    es: "Horario de le lectore confirmado",
    en: "Reader's slot confirmed",
    it: "Orario di lÃ‰â„¢ lettorÃ‰â„¢ confermato",
    de: "Termin der*des Leser*in bestÃƒÂ¤tigt"
  },
  "wf.staff.staffConfirmed.body": {
    "pt-BR": "VocÃƒÂª confirmou o horÃƒÂ¡rio proposto pelo(a/e) leitor(a/e). O horÃƒÂ¡rio estÃƒÂ¡ bloqueado Ã¢â‚¬â€ o livro pode ser preparado para a retirada.",
    fr: "Tu as confirmÃƒÂ© le crÃƒÂ©neau proposÃƒÂ© par leÃ‚Â·la lecteurÃ‚Â·rice. Le crÃƒÂ©neau est verrouillÃƒÂ© Ã¢â‚¬â€ le livre peut ÃƒÂªtre prÃƒÂ©parÃƒÂ© pour le retrait.",
    es: "Confirmaste el horario propuesto por le lectore. El horario estÃƒÂ¡ bloqueado Ã¢â‚¬â€ el libro puede ser preparado para el retiro.",
    en: "You have confirmed the slot proposed by the reader. The slot is locked Ã¢â‚¬â€ the book can be prepared for pickup.",
    it: "Avete confermato l'orario proposto da lÃ‰â„¢ lettorÃ‰â„¢. L'orario ÃƒÂ¨ bloccato Ã¢â‚¬â€ il libro puÃƒÂ² essere preparato per il ritiro.",
    de: "Ihr habt den von der*dem Leser*in vorgeschlagenen Termin bestÃƒÂ¤tigt. Der Termin ist festgelegt Ã¢â‚¬â€ das Buch kann fÃƒÂ¼r die Abholung vorbereitet werden."
  },
  "wf.staff.ready.subject": {
    "pt-BR": "Livro pronto para retirada Ã¢â‚¬â€ leitor(a/e) avisado(a/e)",
    fr: "Livre prÃƒÂªt Ã¢â‚¬â€ lecteurÃ‚Â·rice prÃƒÂ©venuÃ‚Â·e",
    es: "Libro listo Ã¢â‚¬â€ lectore avisade",
    en: "Book ready Ã¢â‚¬â€ reader notified",
    it: "Libro pronto Ã¢â‚¬â€ lettorÃ‰â„¢ avvisatÃ‰â„¢",
    de: "Buch bereit Ã¢â‚¬â€ Leser*in benachrichtigt"
  },
  "wf.staff.ready.body": {
    "pt-BR": "VocÃƒÂª sinalizou que o livro estÃƒÂ¡ pronto para a retirada. O(a/e) leitor(a/e) foi avisado(a/e).",
    fr: "Tu as signalÃƒÂ© que le livre est prÃƒÂªt ÃƒÂ  ÃƒÂªtre retirÃƒÂ©. LeÃ‚Â·la lecteurÃ‚Â·rice a ÃƒÂ©tÃƒÂ© prÃƒÂ©venuÃ‚Â·e.",
    es: "Indicaste que el libro estÃƒÂ¡ listo para ser retirado. Le lectore fue avisade.",
    en: "You have signaled that the book is ready for pickup. The reader has been notified.",
    it: "Avete segnalato che il libro ÃƒÂ¨ pronto per il ritiro. LÃ‰â„¢ lettorÃ‰â„¢ ÃƒÂ¨ statÃ‰â„¢ avvisatÃ‰â„¢.",
    de: "Ihr habt gemeldet, dass das Buch zur Abholung bereit ist. Die*Der Leser*in wurde benachrichtigt."
  },
  "wf.staff.noShow.subject": {
    "pt-BR": "Retirada nÃƒÂ£o realizada",
    fr: "Retrait non effectuÃƒÂ©",
    es: "Retiro no realizado",
    en: "Pickup missed",
    it: "Ritiro non effettuato",
    de: "Abholung nicht erfolgt"
  },
  "wf.staff.noShow.body": {
    "pt-BR": "O livro nÃƒÂ£o foi retirado no horÃƒÂ¡rio previsto. A reserva foi marcada como nÃƒÂ£o-retirada Ã¢â‚¬â€ o livro voltarÃƒÂ¡ em breve ÃƒÂ  circulaÃƒÂ§ÃƒÂ£o livre.",
    fr: "Le livre n'a pas ÃƒÂ©tÃƒÂ© retirÃƒÂ© au crÃƒÂ©neau prÃƒÂ©vu. La rÃƒÂ©servation est marquÃƒÂ©e en non-retrait Ã¢â‚¬â€ le livre repassera bientÃƒÂ´t en circulation libre.",
    es: "El libro no fue retirado en el horario previsto. La reserva fue marcada como no-retiro Ã¢â‚¬â€ el libro volverÃƒÂ¡ pronto a la circulaciÃƒÂ³n libre.",
    en: "The book was not picked up at the scheduled time. The reservation is marked as no-show Ã¢â‚¬â€ the book will soon return to free circulation.",
    it: "Il libro non ÃƒÂ¨ stato ritirato nell'orario previsto. La prenotazione ÃƒÂ¨ stata segnata come non-ritiro Ã¢â‚¬â€ il libro tornerÃƒÂ  presto in circolazione libera.",
    de: "Das Buch wurde zum vereinbarten Termin nicht abgeholt. Die Vormerkung ist als Nicht-Abholung markiert Ã¢â‚¬â€ das Buch geht bald zurÃƒÂ¼ck in den freien Umlauf."
  },
  "wf.staff.closed.subject": {
    "pt-BR": "Reserva encerrada",
    fr: "RÃƒÂ©servation close",
    es: "Reserva cerrada",
    en: "Reservation closed",
    it: "Prenotazione chiusa",
    de: "Vormerkung abgeschlossen"
  },
  "wf.staff.closed.body": {
    "pt-BR": "A reserva estÃƒÂ¡ encerrada, o livro voltou ÃƒÂ  circulaÃƒÂ§ÃƒÂ£o livre. Nenhuma aÃƒÂ§ÃƒÂ£o adicional ÃƒÂ© esperada de sua parte.",
    fr: "La rÃƒÂ©servation est close, le livre repasse en circulation libre. Aucune action supplÃƒÂ©mentaire n'est attendue de votre part.",
    es: "La reserva estÃƒÂ¡ cerrada, el libro vuelve a la circulaciÃƒÂ³n libre. No se espera ninguna acciÃƒÂ³n adicional de su parte.",
    en: "The reservation is closed, the book returns to free circulation. No additional action is expected from you.",
    it: "La prenotazione ÃƒÂ¨ chiusa, il libro torna in circolazione libera. Nessuna azione aggiuntiva ÃƒÂ¨ attesa da parte vostra.",
    de: "Die Vormerkung ist abgeschlossen, das Buch geht zurÃƒÂ¼ck in den freien Umlauf. Keine zusÃƒÂ¤tzliche Aktion eurerseits ist erforderlich."
  },
  "wf.staff.maxIterations.subject": {
    "pt-BR": "NegociaÃƒÂ§ÃƒÂ£o sem acordo Ã¢â‚¬â€ leitor(a/e) convidado(a/e) ao contato direto",
    fr: "NÃƒÂ©gociation sans accord Ã¢â‚¬â€ lecteurÃ‚Â·rice invitÃƒÂ©Ã‚Â·e au contact direct",
    es: "NegociaciÃƒÂ³n sin acuerdo Ã¢â‚¬â€ lectore invitade al contacto directo",
    en: "Negotiation without agreement Ã¢â‚¬â€ reader invited to direct contact",
    it: "Negoziazione senza accordo Ã¢â‚¬â€ lettorÃ‰â„¢ invitatÃ‰â„¢ al contatto diretto",
    de: "Verhandlung ohne Einigung Ã¢â‚¬â€ Leser*in zum direkten Kontakt eingeladen"
  },
  "wf.staff.maxIterations.body": {
    "pt-BR": "VÃƒÂ¡rias trocas sem acordo com o(a/e) leitor(a/e). O(a/e) leitor(a/e) foi convidado(a/e) a entrar em contato diretamente para encontrar uma soluÃƒÂ§ÃƒÂ£o.",
    fr: "Plusieurs allers-retours sans accord avec leÃ‚Â·la lecteurÃ‚Â·rice. LeÃ‚Â·la lecteurÃ‚Â·rice a ÃƒÂ©tÃƒÂ© invitÃƒÂ©Ã‚Â·e ÃƒÂ  vous contacter directement pour trouver une solution.",
    es: "Varios intercambios sin acuerdo con le lectore. Le lectore fue invitade a contactarles directamente para encontrar una soluciÃƒÂ³n.",
    en: "Several exchanges without agreement with the reader. The reader has been invited to contact you directly to find a solution.",
    it: "Diversi scambi senza accordo con lÃ‰â„¢ lettorÃ‰â„¢. LÃ‰â„¢ lettorÃ‰â„¢ ÃƒÂ¨ statÃ‰â„¢ invitatÃ‰â„¢ a contattarvi direttamente per trovare una soluzione.",
    de: "Mehrere Versuche ohne Einigung mit der*dem Leser*in. Die*Der Leser*in wurde gebeten, sich direkt an euch zu wenden, um eine LÃƒÂ¶sung zu finden."
  },

  // ===== Workflow v3 Ã¢â‚¬â€ re-proposition staff aprÃƒÂ¨s contre-prop lecteur =======
  // Couvre le cas spÃƒÂ©cifique oÃƒÂ¹ la coordo, aprÃƒÂ¨s avoir reÃƒÂ§u une contre-prop
  // du lecteur (negotiation_iteration_count > 0, pickup_proposed_by='leitor'),
  // dÃƒÂ©cide de NE PAS accepter et de re-proposer un autre crÃƒÂ©neau. DÃƒÂ©cision
  // technique paquet 6 commit comportement (option ÃŽÂ²) : on distingue cette
  // re-proposition de la premiÃƒÂ¨re ouverture de nÃƒÂ©go (wf.staff.negotiationOpened),
  // pour que la coordo voie clairement dans son trace mail "j'ai re-proposÃƒÂ©"
  // vs "j'ai ouvert la nÃƒÂ©go".
  "wf.reader.libraryCounterProposed.subject": {
    "pt-BR": "Nova proposta da biblioteca",
    fr: "Nouvelle proposition de la biblio",
    es: "Nueva propuesta de la biblioteca",
    en: "New proposal from the library",
    it: "Nuova proposta della biblioteca",
    de: "Neuer Vorschlag der Bibliothek"
  },
  "wf.reader.libraryCounterProposed.body": {
    "pt-BR": "A biblioteca respondeu ÃƒÂ  sua contra-proposta com um novo horÃƒÂ¡rio. VocÃƒÂª pode aceitar este horÃƒÂ¡rio, propor outro, ou cancelar a reserva pela sua conta.",
    fr: "La biblio a rÃƒÂ©pondu ÃƒÂ  ta contre-proposition avec un nouveau crÃƒÂ©neau. Tu peux accepter ce crÃƒÂ©neau, en proposer un autre, ou annuler ta rÃƒÂ©servation depuis ton compte.",
    es: "La biblioteca respondiÃƒÂ³ a tu contrapropuesta con un nuevo horario. PodÃƒÂ©s aceptar este horario, proponer otro, o cancelar tu reserva desde tu cuenta.",
    en: "The library has responded to your counter-proposal with a new time slot. You can accept this slot, propose another one, or cancel your reservation from your account.",
    it: "La biblioteca ha risposto alla tua controproposta con un nuovo orario. Puoi accettare questo orario, proporne un altro, o annullare la tua prenotazione dal tuo account.",
    de: "Die Bibliothek hat auf deinen Gegenvorschlag mit einem neuen Termin geantwortet. Du kannst diesen Termin annehmen, einen anderen vorschlagen oder deine Vormerkung ÃƒÂ¼ber dein Konto stornieren."
  },
  "wf.staff.staffCounterProposed.subject": {
    "pt-BR": "Contra-proposta enviada ao(a/e) leitor(a/e)",
    fr: "Contre-proposition envoyÃƒÂ©e auÃ‚Â·ÃƒÂ  la lecteurÃ‚Â·rice",
    es: "Contrapropuesta enviada a le lectore",
    en: "Counter-proposal sent to the reader",
    it: "Controproposta inviata a lÃ‰â„¢ lettorÃ‰â„¢",
    de: "Gegenvorschlag an die*den Leser*in gesendet"
  },
  "wf.staff.staffCounterProposed.body": {
    "pt-BR": "VocÃƒÂª enviou uma nova contra-proposta de horÃƒÂ¡rio ao(a/e) leitor(a/e) em resposta ÃƒÂ  proposta recebida. Aguarde a resposta.",
    fr: "Tu as envoyÃƒÂ© une nouvelle contre-proposition de crÃƒÂ©neau auÃ‚Â·ÃƒÂ  la lecteurÃ‚Â·rice en rÃƒÂ©ponse ÃƒÂ  sa proposition. En attente de sa rÃƒÂ©ponse.",
    es: "Enviaste una nueva contrapropuesta de horario a le lectore en respuesta a su propuesta. Esperando su respuesta.",
    en: "You have sent a new counter-proposal to the reader in response to their proposal. Awaiting their reply.",
    it: "Avete inviato una nuova controproposta di orario a lÃ‰â„¢ lettorÃ‰â„¢ in risposta alla sua proposta. In attesa della sua risposta.",
    de: "Ihr habt einen neuen Gegenvorschlag an die*den Leser*in als Antwort auf deren Vorschlag gesendet. Wartet auf Antwort."
  },

  // ===== Workflow v3 Ã¢â‚¬â€ cron timeout (wf.staff.negotiationTimedOut) ==========
  "wf.staff.negotiationTimedOut.subject": {
    "pt-BR": "NegociaÃƒÂ§ÃƒÂ£o expirada Ã¢â‚¬â€ reserva liberada",
    fr: "NÃƒÂ©gociation expirÃƒÂ©e Ã¢â‚¬â€ rÃƒÂ©servation libÃƒÂ©rÃƒÂ©e",
    es: "NegociaciÃƒÂ³n vencida Ã¢â‚¬â€ reserva liberada",
    en: "Negotiation expired Ã¢â‚¬â€ reservation released",
    it: "Negoziazione scaduta Ã¢â‚¬â€ prenotazione liberata",
    de: "Verhandlung abgelaufen Ã¢â‚¬â€ Vormerkung freigegeben"
  },
  "wf.staff.negotiationTimedOut.body": {
    "pt-BR": "A negociaÃƒÂ§ÃƒÂ£o para a retirada expirou sem acordo ({days} dias sem resposta). A reserva foi liberada automaticamente e o livro voltou ÃƒÂ  circulaÃƒÂ§ÃƒÂ£o livre.",
    fr: "La nÃƒÂ©gociation pour le retrait a expirÃƒÂ© sans accord ({days} jours sans rÃƒÂ©ponse). La rÃƒÂ©servation a ÃƒÂ©tÃƒÂ© libÃƒÂ©rÃƒÂ©e automatiquement, le livre repasse en circulation libre.",
    es: "La negociaciÃƒÂ³n para el retiro expirÃƒÂ³ sin acuerdo ({days} dÃƒÂ­as sin respuesta). La reserva fue liberada automÃƒÂ¡ticamente, el libro vuelve a la circulaciÃƒÂ³n libre.",
    en: "The negotiation for the pickup has expired without agreement ({days} days without reply). The reservation has been released automatically, the book returns to free circulation.",
    it: "La negoziazione per il ritiro ÃƒÂ¨ scaduta senza accordo ({days} giorni senza risposta). La prenotazione ÃƒÂ¨ stata liberata automaticamente, il libro torna in circolazione libera.",
    de: "Die Verhandlung ÃƒÂ¼ber die Abholung ist ohne Einigung abgelaufen ({days} Tage ohne Antwort). Die Vormerkung wurde automatisch freigegeben, das Buch geht zurÃƒÂ¼ck in den freien Umlauf."
  },

  // ===== Action/info boxes (wf.staff.*Box.*) ================================
  // EncadrÃƒÂ©s visuels insÃƒÂ©rÃƒÂ©s dans le HTML du mail biblio :
  //   - actionBox : encadrÃƒÂ© orange/rouge quand action attendue
  //   - infoBox : encadrÃƒÂ© gris quand juste informatif
  "wf.staff.actionBox.title": {
    "pt-BR": "AÃƒÂ§ÃƒÂ£o esperada",
    fr: "Action attendue",
    es: "AcciÃƒÂ³n esperada",
    en: "Action expected",
    it: "Azione attesa",
    de: "Aktion erwartet"
  },
  "wf.staff.actionBox.openPanel": {
    "pt-BR": "Abrir o painel",
    fr: "Ouvrir le tableau de bord",
    es: "Abrir el panel",
    en: "Open the dashboard",
    it: "Aprire il pannello",
    de: "Dashboard ÃƒÂ¶ffnen"
  },
  "wf.staff.infoBox.title": {
    "pt-BR": "Para sua informaÃƒÂ§ÃƒÂ£o",
    fr: "Pour information",
    es: "Para su informaciÃƒÂ³n",
    en: "For your information",
    it: "Per vostra informazione",
    de: "Zu Ihrer Information"
  },

  // ===== Subject prefixes (subj.*) ==========================================
  // PrÃƒÂ©fixes textuels pour le sujet du mail biblio, permettant aux coordo
  // de filtrer leur boÃƒÂ®te (ex: dossier auto pour les actions requises).
  "subj.staff.action": {
    "pt-BR": "[AÃƒÂ§ÃƒÂ£o requerida]",
    fr: "[Action requise]",
    es: "[AcciÃƒÂ³n requerida]",
    en: "[Action required]",
    it: "[Azione richiesta]",
    de: "[Aktion erforderlich]"
  },
  "subj.staff.info": {
    "pt-BR": "[Info]",
    fr: "[Info]",
    es: "[Info]",
    en: "[Info]",
    it: "[Info]",
    de: "[Info]"
  },
  // ===== Footer libre diffusion (paquet 6 commit fix-up) ====================
  // Remplace l'ancien symbole Ã‚Â© (idÃƒÂ©ologiquement incompatible avec un projet
  // anarchiste). La chaÃƒÂ®ne s'affiche dans la derniÃƒÂ¨re ligne de chaque mail :
  //   "{subjectTag} Ã¢â‚¬â€ {libre diffusion} Ã¢â‚¬â€ {footerText}"
  // LocalisÃƒÂ©e dans la langue du destinataire (cohÃƒÂ©rence avec le reste du
  // paquet 6 : chaque destinataire reÃƒÂ§oit dans sa propre langue).
  "subj.libreDiffusion": {
    "pt-BR": "livre difusÃƒÂ£o",
    fr: "libre diffusion",
    es: "libre difusiÃƒÂ³n",
    en: "free distribution",
    it: "libera diffusione",
    de: "freie Verbreitung"
  },


  // ===== Loan events (loan.*) ===============================================
  "loan.created.sub": {
    "pt-BR": "EmprÃƒÂ©stimo registrado",
    fr: "Emprunt enregistrÃƒÂ©",
    es: "PrÃƒÂ©stamo registrado",
    en: "Loan registered",
    it: "Prestito registrato",
    de: "Ausleihe registriert"
  },
  "loan.created.intro": {
    "pt-BR": "Seu emprÃƒÂ©stimo foi registrado.",
    fr: "Ton emprunt a bien ÃƒÂ©tÃƒÂ© enregistrÃƒÂ©.",
    es: "Tu prÃƒÂ©stamo fue registrado.",
    en: "Your loan has been registered.",
    it: "Il tuo prestito ÃƒÂ¨ stato registrato.",
    de: "Deine Ausleihe wurde registriert."
  },
  "loan.dueIn": {
    "pt-BR": "DevoluÃƒÂ§ÃƒÂ£o prevista para {date}.",
    fr: "Retour prÃƒÂ©vu pour le {date}.",
    es: "DevoluciÃƒÂ³n prevista para el {date}.",
    en: "Due date: {date}.",
    it: "Restituzione prevista per il {date}.",
    de: "RÃƒÂ¼ckgabe vorgesehen fÃƒÂ¼r den {date}."
  },
  "loan.renewed.sub": {
    "pt-BR": "RenovaÃƒÂ§ÃƒÂ£o confirmada",
    fr: "Renouvellement confirmÃƒÂ©",
    es: "RenovaciÃƒÂ³n confirmada",
    en: "Renewal confirmed",
    it: "Rinnovo confermato",
    de: "VerlÃƒÂ¤ngerung bestÃƒÂ¤tigt"
  },
  "loan.renewed.intro": {
    "pt-BR": "Sua prorrogaÃƒÂ§ÃƒÂ£o foi confirmada.",
    fr: "Ta prolongation a bien ÃƒÂ©tÃƒÂ© confirmÃƒÂ©e.",
    es: "Tu renovaciÃƒÂ³n fue confirmada.",
    en: "Your renewal has been confirmed.",
    it: "Il tuo rinnovo ÃƒÂ¨ stato confermato.",
    de: "Deine VerlÃƒÂ¤ngerung wurde bestÃƒÂ¤tigt."
  },
  "loan.newDue": {
    "pt-BR": "Nova data de devoluÃƒÂ§ÃƒÂ£o: {date}.",
    fr: "Nouvelle date de retour : {date}.",
    es: "Nueva fecha de devoluciÃƒÂ³n: {date}.",
    en: "New due date: {date}.",
    it: "Nuova data di restituzione: {date}.",
    de: "Neues RÃƒÂ¼ckgabedatum: {date}."
  },
  "loan.renewed.once": {
    "pt-BR": "Lembre-se: cada emprÃƒÂ©stimo pode ser prorrogado apenas uma vez.",
    fr: "Pour rappel : chaque emprunt ne peut ÃƒÂªtre prolongÃƒÂ© qu'une seule fois.",
    es: "Recuerda: cada prÃƒÂ©stamo puede renovarse solo une vez.",
    en: "Reminder: each loan can be renewed only once.",
    it: "Ricorda: ogni prestito puÃƒÂ² essere rinnovato solo una volta.",
    de: "Zur Erinnerung: jede Ausleihe kann nur einmal verlÃƒÂ¤ngert werden."
  },
  "loan.returned.sub": {
    "pt-BR": "DevoluÃƒÂ§ÃƒÂ£o registrada",
    fr: "Retour enregistrÃƒÂ©",
    es: "DevoluciÃƒÂ³n registrada",
    en: "Return registered",
    it: "Restituzione registrata",
    de: "RÃƒÂ¼ckgabe registriert"
  },
  "loan.returned.intro": {
    "pt-BR": "Registramos a devoluÃƒÂ§ÃƒÂ£o. Obrigad(o/a/e)!",
    fr: "Nous avons enregistrÃƒÂ© le retour. Merci !",
    es: "Registramos la devoluciÃƒÂ³n. Ã‚Â¡Gracias!",
    en: "We've recorded the return. Thank you!",
    it: "Abbiamo registrato la restituzione. Grazie!",
    de: "Wir haben die RÃƒÂ¼ckgabe registriert. Danke!"
  },
  "loan.returned.browse": {
    "pt-BR": "Continue navegando no acervo para suas prÃƒÂ³ximas leituras.",
    fr: "Continue ÃƒÂ  explorer le fonds pour tes prochaines lectures.",
    es: "Sigue navegando el acervo para tus prÃƒÂ³ximas lecturas.",
    en: "Keep browsing the collection for your next reads.",
    it: "Continua a esplorare il fondo per le tue prossime letture.",
    de: "StÃƒÂ¶bere weiter im Bestand fÃƒÂ¼r deine nÃƒÂ¤chste LektÃƒÂ¼re."
  },
  "loan.returnScheduled": {
    "pt-BR": "DevoluÃƒÂ§ÃƒÂ£o agendada",
    fr: "Retour programmÃƒÂ©",
    es: "DevoluciÃƒÂ³n programada",
    en: "Return scheduled",
    it: "Restituzione programmata",
    de: "RÃƒÂ¼ckgabe geplant"
  },
  "loan.returnCancelled": {
    "pt-BR": "DevoluÃƒÂ§ÃƒÂ£o cancelada",
    fr: "Retour annulÃƒÂ©",
    es: "DevoluciÃƒÂ³n cancelada",
    en: "Return cancelled",
    it: "Restituzione annullata",
    de: "RÃƒÂ¼ckgabe storniert"
  },
  "loan.returnMissed": {
    "pt-BR": "DevoluÃƒÂ§ÃƒÂ£o nÃƒÂ£o realizada",
    fr: "Retour non effectuÃƒÂ©",
    es: "DevoluciÃƒÂ³n no realizada",
    en: "Return missed",
    it: "Restituzione non effettuata",
    de: "RÃƒÂ¼ckgabe nicht erfolgt"
  },
  "loan.partialReturn.sub": {
    "pt-BR": "DevoluÃƒÂ§ÃƒÂ£o parcial registrada",
    fr: "Retour partiel enregistrÃƒÂ©",
    es: "DevoluciÃƒÂ³n parcial registrada",
    en: "Partial return recorded",
    it: "Restituzione parziale registrata",
    de: "TeilrÃƒÂ¼ckgabe registriert"
  },
  "loan.partialReturn.intro": {
    "pt-BR": "Registramos a devoluÃƒÂ§ÃƒÂ£o parcial do seu emprÃƒÂ©stimo. Obrigad(o/a/e) por trazer alguns documentos!",
    fr: "Nous avons enregistrÃƒÂ© le retour partiel de ton emprunt. Merci d'avoir rapportÃƒÂ© une partie des documents !",
    es: "Registramos la devoluciÃƒÂ³n parcial de tu prÃƒÂ©stamo. Ã‚Â¡Gracias por traer une parte de los documentos!",
    en: "We've recorded the partial return of your loan. Thank you for bringing back some of the documents!",
    it: "Abbiamo registrato la restituzione parziale del tuo prestito. Grazie per aver riportato alcuni documenti!",
    de: "Wir haben die TeilrÃƒÂ¼ckgabe deiner Ausleihe registriert. Danke, dass du einige Dokumente zurÃƒÂ¼ckgebracht hast!"
  },
  "loan.partialReturn.dueReminder": {
    "pt-BR": "Lembrete: a data de devoluÃƒÂ§ÃƒÂ£o dos documentos restantes ÃƒÂ© {date}.",
    fr: "Rappel : la date de retour des documents restants est le {date}.",
    es: "Recordatorio: la fecha de devoluciÃƒÂ³n de los documentos restantes es el {date}.",
    en: "Reminder: the due date for the remaining documents is {date}.",
    it: "Promemoria: la data di restituzione dei documenti rimanenti ÃƒÂ¨ il {date}.",
    de: "Erinnerung: das RÃƒÂ¼ckgabedatum fÃƒÂ¼r die verbleibenden Dokumente ist der {date}."
  },
  "loan.partialReturn.outro": {
    "pt-BR": "NÃƒÂ£o esqueÃƒÂ§a de passar pela biblioteca para devolver os documentos restantes.",
    fr: "N'oublie pas de passer ÃƒÂ  la bibliothÃƒÂ¨que pour rendre les documents restants.",
    es: "No olvides pasar por la biblioteca para devolver los documentos restantes.",
    en: "Don't forget to drop by the library to return the remaining documents.",
    it: "Non dimenticare di passare in biblioteca per restituire i documenti rimanenti.",
    de: "Vergiss nicht, in der Bibliothek vorbeizuschauen, um die verbleibenden Dokumente zurÃƒÂ¼ckzugeben."
  },
  "loan.fullyReturnedAfterPartial.sub": {
    "pt-BR": "EmprÃƒÂ©stimo concluÃƒÂ­do",
    fr: "Emprunt clÃƒÂ´turÃƒÂ©",
    es: "PrÃƒÂ©stamo concluido",
    en: "Loan completed",
    it: "Prestito concluso",
    de: "Ausleihe abgeschlossen"
  },
  "loan.fullyReturnedAfterPartial.intro": {
    "pt-BR": "VocÃƒÂª devolveu o ÃƒÂºltimo documento do seu emprÃƒÂ©stimo. Tudo voltou! Obrigad(o/a/e) por cuidar bem dos livros da biblioteca.",
    fr: "Tu viens de rendre le dernier document de ton emprunt. Tout est revenu ! Merci d'avoir pris soin des documents de la bibliothÃƒÂ¨que.",
    es: "Devolviste el ÃƒÂºltimo documento de tu prÃƒÂ©stamo. Ã‚Â¡Todo volviÃƒÂ³! Gracias por cuidar de los documentos de la biblioteca.",
    en: "You've returned the last document of your loan. Everything is back! Thank you for taking good care of the library's documents.",
    it: "Hai restituito l'ultimo documento del tuo prestito. ÃƒË† tutto rientrato! Grazie per esserti preso/a/* cura dei documenti della biblioteca.",
    de: "Du hast das letzte Dokument deiner Ausleihe zurÃƒÂ¼ckgebracht. Alles ist wieder da! Danke, dass du gut auf die Dokumente der Bibliothek aufgepasst hast."
  },
  "loan.fullyReturnedAfterPartial.browse": {
    "pt-BR": "Continue navegando no acervo para suas prÃƒÂ³ximas leituras.",
    fr: "Continue ÃƒÂ  explorer le fonds pour tes prochaines lectures.",
    es: "Sigue navegando el acervo para tus prÃƒÂ³ximas lecturas.",
    en: "Keep browsing the collection for your next reads.",
    it: "Continua a esplorare il fondo per le tue prossime letture.",
    de: "StÃƒÂ¶bere weiter im Bestand fÃƒÂ¼r deine nÃƒÂ¤chste LektÃƒÂ¼re."
  },

  // ===== Reminders (rem.*) ==================================================
  "rem.title": {
    "pt-BR": "Lembrete de devoluÃƒÂ§ÃƒÂ£o",
    fr: "Rappel de retour",
    es: "Recordatorio de devoluciÃƒÂ³n",
    en: "Return reminder",
    it: "Promemoria di restituzione",
    de: "RÃƒÂ¼ckgabeerinnerung"
  },
  "rem.5d": {
    "pt-BR": "DevoluÃƒÂ§ÃƒÂ£o em 5 dias",
    fr: "Retour dans 5 jours",
    es: "DevoluciÃƒÂ³n en 5 dÃƒÂ­as",
    en: "Due in 5 days",
    it: "Restituzione tra 5 giorni",
    de: "RÃƒÂ¼ckgabe in 5 Tagen"
  },
  "rem.5d.body": {
    "pt-BR": "Seu emprÃƒÂ©stimo vence em 5 dias",
    fr: "Ton emprunt arrive ÃƒÂ  ÃƒÂ©chÃƒÂ©ance dans 5 jours",
    es: "Tu prÃƒÂ©stamo vence en 5 dÃƒÂ­as",
    en: "Your loan is due in 5 days",
    it: "Il tuo prestito scade tra 5 giorni",
    de: "Deine Ausleihe lÃƒÂ¤uft in 5 Tagen ab"
  },
  "rem.3d": {
    "pt-BR": "DevoluÃƒÂ§ÃƒÂ£o em 3 dias",
    fr: "Retour dans 3 jours",
    es: "DevoluciÃƒÂ³n en 3 dÃƒÂ­as",
    en: "Due in 3 days",
    it: "Restituzione tra 3 giorni",
    de: "RÃƒÂ¼ckgabe in 3 Tagen"
  },
  "rem.3d.body": {
    "pt-BR": "Faltam 3 dias para a devoluÃƒÂ§ÃƒÂ£o do seu emprÃƒÂ©stimo.",
    fr: "Plus que 3 jours avant la date de retour de ton emprunt.",
    es: "Quedan 3 dÃƒÂ­as para la devoluciÃƒÂ³n de tu prÃƒÂ©stamo.",
    en: "Only 3 days left until the return date of your loan.",
    it: "Mancano 3 giorni alla data di restituzione del tuo prestito.",
    de: "Nur noch 3 Tage bis zum RÃƒÂ¼ckgabedatum deiner Ausleihe."
  },
  "rem.today": {
    "pt-BR": "DevoluÃƒÂ§ÃƒÂ£o hoje",
    fr: "Retour aujourd'hui",
    es: "DevoluciÃƒÂ³n hoy",
    en: "Due today",
    it: "Restituzione oggi",
    de: "RÃƒÂ¼ckgabe heute"
  },
  "rem.today.body": {
    "pt-BR": "Sua devoluÃƒÂ§ÃƒÂ£o ÃƒÂ© hoje",
    fr: "Ton retour est prÃƒÂ©vu aujourd'hui",
    es: "Tu devoluciÃƒÂ³n es hoy",
    en: "Your return is due today",
    it: "La tua restituzione ÃƒÂ¨ oggi",
    de: "Deine RÃƒÂ¼ckgabe ist heute fÃƒÂ¤llig"
  },

  // ===== Overdue (ov.*) =====================================================
  "ov.title": {
    "pt-BR": "Aviso de atraso",
    fr: "Avis de retard",
    es: "Aviso de retraso",
    en: "Overdue notice",
    it: "Avviso di ritardo",
    de: "ÃƒÅ“berfÃƒÂ¤lligkeitshinweis"
  },
  "ov.1d": {
    "pt-BR": "EmprÃƒÂ©stimo em atraso",
    fr: "Emprunt en retard",
    es: "PrÃƒÂ©stamo en retraso",
    en: "Loan overdue",
    it: "Prestito in ritardo",
    de: "Ausleihe ÃƒÂ¼berfÃƒÂ¤llig"
  },
  "ov.1d.body": {
    "pt-BR": "Seu emprÃƒÂ©stimo estÃƒÂ¡ em atraso desde {date}. Por favor, providencie a devoluÃƒÂ§ÃƒÂ£o.",
    fr: "Ton emprunt est en retard depuis le {date}. Merci de prÃƒÂ©voir le retour ou la prolongation.",
    es: "Tu prÃƒÂ©stamo estÃƒÂ¡ en retraso desde el {date}. Por favor, organiza la devoluciÃƒÂ³n o la renovaciÃƒÂ³n.",
    en: "Your loan has been overdue since {date}. Please arrange the return or a renewal.",
    it: "Il tuo prestito ÃƒÂ¨ in ritardo dal {date}. Per favore, organizza la restituzione o il rinnovo.",
    de: "Deine Ausleihe ist seit dem {date} ÃƒÂ¼berfÃƒÂ¤llig. Bitte sorge fÃƒÂ¼r die RÃƒÂ¼ckgabe oder eine VerlÃƒÂ¤ngerung."
  },
  "ov.7d": {
    "pt-BR": "EmprÃƒÂ©stimo com {days} dias de atraso",
    fr: "Emprunt en retard de {days} jours",
    es: "PrÃƒÂ©stamo con {days} dÃƒÂ­as de retraso",
    en: "Loan {days} days overdue",
    it: "Prestito in ritardo di {days} giorni",
    de: "Ausleihe seit {days} Tagen ÃƒÂ¼berfÃƒÂ¤llig"
  },
  "ov.7d.body": {
    "pt-BR": "Seu emprÃƒÂ©stimo estÃƒÂ¡ com {days} dias de atraso. Entre em contato com a biblioteca.",
    fr: "Ton emprunt est en retard de {days} jours. Contacte la bibliothÃƒÂ¨que pour trouver une solution.",
    es: "Tu prÃƒÂ©stamo estÃƒÂ¡ con {days} dÃƒÂ­as de retraso. Contacta la biblioteca para encontrar una soluciÃƒÂ³n.",
    en: "Your loan is {days} days overdue. Contact the library to find a solution.",
    it: "Il tuo prestito ÃƒÂ¨ in ritardo di {days} giorni. Contatta la biblioteca per trovare una soluzione.",
    de: "Deine Ausleihe ist seit {days} Tagen ÃƒÂ¼berfÃƒÂ¤llig. Kontaktiere die Bibliothek, um eine LÃƒÂ¶sung zu finden."
  },
  "ov.30d": {
    "pt-BR": "EmprÃƒÂ©stimo com {days} dias de atraso Ã¢â‚¬â€ situaÃƒÂ§ÃƒÂ£o grave",
    fr: "Emprunt en retard de {days} jours Ã¢â‚¬â€ situation ÃƒÂ  rÃƒÂ©gulariser",
    es: "PrÃƒÂ©stamo con {days} dÃƒÂ­as de retraso Ã¢â‚¬â€ situaciÃƒÂ³n a regularizar",
    en: "Loan {days} days overdue Ã¢â‚¬â€ situation to resolve",
    it: "Prestito in ritardo di {days} giorni Ã¢â‚¬â€ situazione da regolarizzare",
    de: "Ausleihe seit {days} Tagen ÃƒÂ¼berfÃƒÂ¤llig Ã¢â‚¬â€ Situation zu klÃƒÂ¤ren"
  },
  "ov.30d.body": {
    "pt-BR": "Seu emprÃƒÂ©stimo estÃƒÂ¡ com {days} dias de atraso. Esta situaÃƒÂ§ÃƒÂ£o compromete o funcionamento da biblioteca.",
    fr: "Ton emprunt est en retard de {days} jours. Cette situation pÃƒÂ¨se sur le fonctionnement collectif de la bibliothÃƒÂ¨que. Prends contact avec la biblio pour qu'on trouve ensemble comment rÃƒÂ©gulariser.",
    es: "Tu prÃƒÂ©stamo estÃƒÂ¡ con {days} dÃƒÂ­as de retraso. Esta situaciÃƒÂ³n afecta el funcionamiento colectivo de la biblioteca. Toma contacto con la biblio para que encontremos juntes cÃƒÂ³mo regularizar.",
    en: "Your loan is {days} days overdue. This situation affects the collective functioning of the library. Get in touch so we can find a way forward together.",
    it: "Il tuo prestito ÃƒÂ¨ in ritardo di {days} giorni. Questa situazione pesa sul funzionamento collettivo della biblioteca. Mettiti in contatto con la biblio per trovare insieme una soluzione.",
    de: "Deine Ausleihe ist seit {days} Tagen ÃƒÂ¼berfÃƒÂ¤llig. Diese Situation belastet den kollektiven Betrieb der Bibliothek. Nimm Kontakt auf, damit wir gemeinsam eine LÃƒÂ¶sung finden."
  },
  "ov.30d.admin": {
    "pt-BR": "EmprÃƒÂ©stimo com mais de 30 dias de atraso",
    fr: "Emprunt avec plus de 30 jours de retard",
    es: "PrÃƒÂ©stamo con mÃƒÂ¡s de 30 dÃƒÂ­as de retraso",
    en: "Loan over 30 days overdue",
    it: "Prestito con oltre 30 giorni di ritardo",
    de: "Ausleihe seit ÃƒÂ¼ber 30 Tagen ÃƒÂ¼berfÃƒÂ¤llig"
  },

  // ===== Profile notices (prof.*) ===========================================
  "prof.restricted": {
    "pt-BR": "Cadastro com restriÃƒÂ§ÃƒÂµes",
    fr: "Compte avec restrictions",
    es: "Cuenta con restricciones",
    en: "Account with restrictions",
    it: "Account con restrizioni",
    de: "Konto mit EinschrÃƒÂ¤nkungen"
  },
  "prof.restricted.intro": {
    "pt-BR": "Seu cadastro foi marcado com restriÃƒÂ§ÃƒÂµes.",
    fr: "Ton compte a ÃƒÂ©tÃƒÂ© marquÃƒÂ© avec des restrictions.",
    es: "Tu cuenta fue marcada con restricciones.",
    en: "Your account has been marked with restrictions.",
    it: "Il tuo account ÃƒÂ¨ stato segnato con restrizioni.",
    de: "Dein Konto wurde mit EinschrÃƒÂ¤nkungen markiert."
  },
  "prof.contactLibrary": {
    "pt-BR": "Entre em contato com a biblioteca para regularizar sua situaÃƒÂ§ÃƒÂ£o.",
    fr: "Contacte la bibliothÃƒÂ¨que pour rÃƒÂ©gulariser ta situation.",
    es: "Contacta la biblioteca para regularizar tu situaciÃƒÂ³n.",
    en: "Contact the library to resolve your situation.",
    it: "Contatta la biblioteca per regolarizzare la tua situazione.",
    de: "Kontaktiere die Bibliothek, um deine Situation zu klÃƒÂ¤ren."
  },
  "prof.formalNotice": {
    "pt-BR": "Aviso formal de restriÃƒÂ§ÃƒÂ£o",
    fr: "Avis formel concernant la restriction",
    es: "Aviso formal sobre la restricciÃƒÂ³n",
    en: "Formal notice regarding the restriction",
    it: "Avviso formale relativo alla restrizione",
    de: "Formelle Mitteilung zur EinschrÃƒÂ¤nkung"
  },
  "prof.formalNotice.intro": {
    "pt-BR": "Esta mensagem ÃƒÂ© um aviso formal sobre a restriÃƒÂ§ÃƒÂ£o d(o/a/e) seu cadastro.",
    fr: "Ce message est un avis formel concernant la restriction de ton compte.",
    es: "Este mensaje es un aviso formal sobre la restricciÃƒÂ³n de tu cuenta.",
    en: "This message is a formal notice regarding the restriction on your account.",
    it: "Questo messaggio ÃƒÂ¨ un avviso formale relativo alla restrizione del tuo account.",
    de: "Diese Nachricht ist eine formelle Mitteilung zur EinschrÃƒÂ¤nkung deines Kontos."
  },

  // ===== Pickup reply (pr.*) Ã¢â‚¬â€ admin-only mais traduit pour cohÃƒÂ©rence ======
  "pr.readerReply": {
    "pt-BR": "Resposta d(o/a/e) leitor(a/e) sobre a retirada",
    fr: "RÃƒÂ©ponse duÃ‚Â·de la lecteurÃ‚Â·rice sur le retrait",
    es: "Respuesta de le lector(a/e) sobre el retiro",
    en: "Reader reply about pickup",
    it: "Risposta del/la lettore/trice sul ritiro",
    de: "Antwort der*des Leser*in zur Abholung"
  },
  "pr.confirmed": {
    "pt-BR": "Leitor(a/e) confirmou o horÃƒÂ¡rio de retirada",
    fr: "LeÃ‚Â·la lecteurÃ‚Â·rice a confirmÃƒÂ© l'horaire de retrait",
    es: "Le lector(a/e) confirmÃƒÂ³ el horario de retiro",
    en: "Reader confirmed the pickup time",
    it: "Il/la lettore/trice ha confermato l'orario di ritiro",
    de: "Leser*in hat den Abholzeitpunkt bestÃƒÂ¤tigt"
  },
  "pr.declined": {
    "pt-BR": "Leitor(a/e) nÃƒÂ£o pode no horÃƒÂ¡rio proposto",
    fr: "LeÃ‚Â·la lecteurÃ‚Â·rice ne peut pas ÃƒÂ  l'horaire proposÃƒÂ©",
    es: "Le lector(a/e) no puede en el horario propuesto",
    en: "Reader can't make the proposed time",
    it: "Il/la lettore/trice non puÃƒÂ² all'orario proposto",
    de: "Leser*in kann zum vorgeschlagenen Zeitpunkt nicht"
  },

  // ===== Admin subjects (admin.*) ===========================================
  "admin.newLoan": {
    "pt-BR": "Novo emprÃƒÂ©stimo registrado",
    fr: "Nouvel emprunt enregistrÃƒÂ©",
    es: "Nuevo prÃƒÂ©stamo registrado",
    en: "New loan registered",
    it: "Nuovo prestito registrato",
    de: "Neue Ausleihe registriert"
  },
  "admin.renewalDone": {
    "pt-BR": "ProrrogaÃƒÂ§ÃƒÂ£o registrada",
    fr: "Prolongation enregistrÃƒÂ©e",
    es: "RenovaciÃƒÂ³n registrada",
    en: "Renewal recorded",
    it: "Rinnovo registrato",
    de: "VerlÃƒÂ¤ngerung registriert"
  },
  "admin.returnDone": {
    "pt-BR": "DevoluÃƒÂ§ÃƒÂ£o registrada",
    fr: "Retour enregistrÃƒÂ©",
    es: "DevoluciÃƒÂ³n registrada",
    en: "Return recorded",
    it: "Restituzione registrata",
    de: "RÃƒÂ¼ckgabe registriert"
  },
  "admin.partialReturnDone": {
    "pt-BR": "DevoluÃƒÂ§ÃƒÂ£o parcial registrada",
    fr: "Retour partiel enregistrÃƒÂ©",
    es: "DevoluciÃƒÂ³n parcial registrada",
    en: "Partial return recorded",
    it: "Restituzione parziale registrata",
    de: "TeilrÃƒÂ¼ckgabe registriert"
  },
  "admin.fullyReturnedAfterPartialDone": {
    "pt-BR": "EmprÃƒÂ©stimo concluÃƒÂ­do (apÃƒÂ³s devoluÃƒÂ§ÃƒÂ£o parcial)",
    fr: "Emprunt clÃƒÂ´turÃƒÂ© (aprÃƒÂ¨s retour partiel)",
    es: "PrÃƒÂ©stamo concluido (tras devoluciÃƒÂ³n parcial)",
    en: "Loan completed (after partial return)",
    it: "Prestito concluso (dopo restituzione parziale)",
    de: "Ausleihe abgeschlossen (nach TeilrÃƒÂ¼ckgabe)"
  },
  "admin.returnUpdate": {
    "pt-BR": "AtualizaÃƒÂ§ÃƒÂ£o sobre devoluÃƒÂ§ÃƒÂ£o",
    fr: "Mise ÃƒÂ  jour sur un retour",
    es: "ActualizaciÃƒÂ³n sobre devoluciÃƒÂ³n",
    en: "Return update",
    it: "Aggiornamento su una restituzione",
    de: "Aktualisierung zu einer RÃƒÂ¼ckgabe"
  },
  "admin.loanUpdate": {
    "pt-BR": "AtualizaÃƒÂ§ÃƒÂ£o d(o/a/e) emprÃƒÂ©stimo",
    fr: "Mise ÃƒÂ  jour de l'emprunt",
    es: "ActualizaciÃƒÂ³n del prÃƒÂ©stamo",
    en: "Loan update",
    it: "Aggiornamento del prestito",
    de: "Aktualisierung der Ausleihe"
  },
  "admin.resUpdate": {
    "pt-BR": "AtualizaÃƒÂ§ÃƒÂ£o da reserva",
    fr: "Mise ÃƒÂ  jour de la rÃƒÂ©servation",
    es: "ActualizaciÃƒÂ³n de la reserva",
    en: "Reservation update",
    it: "Aggiornamento della prenotazione",
    de: "Aktualisierung der Vormerkung"
  },
  "admin.profileNotice": {
    "pt-BR": "Aviso sobre cadastro",
    fr: "Avis sur un compte",
    es: "Aviso sobre cuenta",
    en: "Account notice",
    it: "Avviso su un account",
    de: "Mitteilung zu einem Konto"
  },

  // ===== Task statuses (ts.*) Ã¢â‚¬â€ usage Painel internal tasks =================
  "ts.aberta": {
    "pt-BR": "Aberta",
    fr: "Ouverte",
    es: "Abierta",
    en: "Open",
    it: "Aperta",
    de: "Offen"
  },
  "ts.a_fazer": {
    "pt-BR": "A fazer",
    fr: "Ãƒâ‚¬ faire",
    es: "Por hacer",
    en: "To do",
    it: "Da fare",
    de: "Zu erledigen"
  },
  "ts.em_andamento": {
    "pt-BR": "Em andamento",
    fr: "En cours",
    es: "En progreso",
    en: "In progress",
    it: "In corso",
    de: "In Bearbeitung"
  },
  "ts.concluida": {
    "pt-BR": "ConcluÃƒÂ­da",
    fr: "TerminÃƒÂ©e",
    es: "Completada",
    en: "Completed",
    it: "Completata",
    de: "Abgeschlossen"
  },
  "ts.cancelada": {
    "pt-BR": "Cancelada",
    fr: "AnnulÃƒÂ©e",
    es: "Cancelada",
    en: "Cancelled",
    it: "Annullata",
    de: "Storniert"
  },

  // ===== Task priorities (tp.*) =============================================
  "tp.alta": {
    "pt-BR": "Alta",
    fr: "Haute",
    es: "Alta",
    en: "High",
    it: "Alta",
    de: "Hoch"
  },
  "tp.media": {
    "pt-BR": "MÃƒÂ©dia",
    fr: "Moyenne",
    es: "Media",
    en: "Medium",
    it: "Media",
    de: "Mittel"
  },
  "tp.baixa": {
    "pt-BR": "Baixa",
    fr: "Basse",
    es: "Baja",
    en: "Low",
    it: "Bassa",
    de: "Niedrig"
  },
  "tp.urgente": {
    "pt-BR": "Urgente",
    fr: "Urgente",
    es: "Urgente",
    en: "Urgent",
    it: "Urgente",
    de: "Dringend"
  },

  // ===== Team Ã¢â‚¬â€ RÃƒÂ´les dynamiques (team.role.*) ==============================
  "team.role.librarian": {
    "pt-BR": "bibliotecÃƒÂ¡ri(o/a/e)",
    fr: "bibliothÃƒÂ©caire",
    es: "bibliotecarie",
    en: "librarian",
    it: "bibliotecario/a/e",
    de: "Bibliothekar*in"
  },
  "team.role.coordenador": {
    "pt-BR": "coordenador(o/a/e)",
    fr: "coordinateurÃ‚Â·rice",
    es: "coordinadore",
    en: "coordinator",
    it: "coordinatore/trice/e",
    de: "Koordinator*in"
  },

  // ===== Team Ã¢â‚¬â€ Admissions concertÃƒÂ©es (team.promoted_*) =====================
  "team.promoted_to_librarian.sub": {
    "pt-BR": "VocÃƒÂª foi admitid(o/a/e) bibliotecÃƒÂ¡ri(o/a/e)",
    fr: "Tu as ÃƒÂ©tÃƒÂ© admisÃ‚Â·e bibliothÃƒÂ©caire",
    es: "Fuiste admitide bibliotecarie",
    en: "You have been admitted as a librarian",
    it: "Sei stato/a/e ammesso/a/e come bibliotecario/a/e",
    de: "Du wurdest als Bibliothekar*in aufgenommen"
  },
  "team.promoted_to_librarian.intro": {
    "pt-BR": "VocÃƒÂª acaba de ser admitid(o/a/e) bibliotecÃƒÂ¡ri(o/a/e) na {libraryName} de maneira concertada pela equipe de animaÃƒÂ§ÃƒÂ£o da biblioteca. Seja bem-vind(o/a/e)!",
    fr: "Tu viens d'ÃƒÂªtre admisÃ‚Â·e bibliothÃƒÂ©caire ÃƒÂ  la {libraryName} de maniÃƒÂ¨re concertÃƒÂ©e par l'ÃƒÂ©quipe d'animation de la bibliothÃƒÂ¨que. Bienvenue !",
    es: "AcabÃƒÂ¡s de ser admitide bibliotecarie en le {libraryName} de manera concertada por le equipo de animaciÃƒÂ³n de la biblioteca. Ã‚Â¡Bienvenide!",
    en: "You have just been admitted as a librarian at {libraryName} through a concerted decision by the library's animation team. Welcome!",
    it: "Sei appena stato/a/e ammesso/a/e come bibliotecario/a/e a {libraryName} in modo concertato dall'equipe di animazione della biblioteca. Benvenuto/a/e!",
    de: "Du bist soeben als Bibliothekar*in bei {libraryName} in Abstimmung mit dem Animationsteam der Bibliothek aufgenommen worden. Willkommen!"
  },
  "team.promoted_to_coordenador.sub": {
    "pt-BR": "VocÃƒÂª foi admitid(o/a/e) coordenador(o/a/e)",
    fr: "Tu as ÃƒÂ©tÃƒÂ© admisÃ‚Â·e coordinateurÃ‚Â·rice",
    es: "Fuiste admitide coordinadore",
    en: "You have been admitted as a coordinator",
    it: "Sei stato/a/e ammesso/a/e come coordinatore/trice/e",
    de: "Du wurdest als Koordinator*in aufgenommen"
  },
  "team.promoted_to_coordenador.intro": {
    "pt-BR": "VocÃƒÂª acaba de ser admitid(o/a/e) coordenador(o/a/e) na {libraryName} de maneira concertada. VocÃƒÂª junta-se ao cÃƒÂ­rculo de coordenaÃƒÂ§ÃƒÂ£o. Suas responsabilidades se ampliam: governanÃƒÂ§a da equipe, validaÃƒÂ§ÃƒÂµes sensÃƒÂ­veis. O regimento interno estÃƒÂ¡ aqui: {regimentoUrl}",
    fr: "Tu viens d'ÃƒÂªtre admisÃ‚Â·e coordinateurÃ‚Â·rice ÃƒÂ  la {libraryName} de maniÃƒÂ¨re concertÃƒÂ©e. Tu rejoins le cercle de coordination. Tes responsabilitÃƒÂ©s s'ÃƒÂ©largissent : gouvernance de l'ÃƒÂ©quipe, validations sensibles. Le rÃƒÂ¨glement intÃƒÂ©rieur est ici : {regimentoUrl}",
    es: "AcabÃƒÂ¡s de ser admitide coordinadore en le {libraryName} de manera concertada. Te sumÃƒÂ¡s al cÃƒÂ­rculo de coordinaciÃƒÂ³n. Tus responsabilidades se amplÃƒÂ­an: gobernanza de le equipo, validaciones sensibles. El reglamento interno estÃƒÂ¡ acÃƒÂ¡: {regimentoUrl}",
    en: "You have just been admitted as a coordinator at {libraryName} through a concerted decision. You join the coordination circle. Your responsibilities expand: team governance, sensitive validations. The internal rules are here: {regimentoUrl}",
    it: "Sei appena stato/a/e ammesso/a/e come coordinatore/trice/e a {libraryName} in modo concertato. Entri nel cerchio di coordinamento. Le tue responsabilitÃƒÂ  si ampliano: governance dell'equipe, validazioni sensibili. Il regolamento interno ÃƒÂ¨ qui: {regimentoUrl}",
    de: "Du bist soeben als Koordinator*in bei {libraryName} in Abstimmung aufgenommen worden. Du trittst dem Koordinationskreis bei. Deine Verantwortungen erweitern sich: Governance des Teams, sensible Validierungen. Die interne GeschÃƒÂ¤ftsordnung findest du hier: {regimentoUrl}"
  },

  // ===== Team Ã¢â‚¬â€ Retour volontaire ÃƒÂ  un autre rÃƒÂ´le (team.self_demoted) =======
  "team.self_demoted.sub": {
    "pt-BR": "{actorName} retornou ao papel de {toRole}",
    fr: "{actorName} est revenuÃ‚Â·e au rÃƒÂ´le de {toRole}",
    es: "{actorName} volviÃƒÂ³ al rol de {toRole}",
    en: "{actorName} has returned to the {toRole} role",
    it: "{actorName} ÃƒÂ¨ tornato/a/e al ruolo di {toRole}",
    de: "{actorName} ist zur Rolle {toRole} zurÃƒÂ¼ckgekehrt"
  },
  "team.self_demoted.intro": {
    "pt-BR": "{actorName} retornou do papel de {fromRole} ao papel de {toRole} na {libraryName}. Esta decisÃƒÂ£o ÃƒÂ© voluntÃƒÂ¡ria e imediata.",
    fr: "{actorName} est revenuÃ‚Â·e du rÃƒÂ´le de {fromRole} au rÃƒÂ´le de {toRole} ÃƒÂ  la {libraryName}. Cette dÃƒÂ©cision est volontaire et immÃƒÂ©diate.",
    es: "{actorName} volviÃƒÂ³ de le rol de {fromRole} al rol de {toRole} en le {libraryName}. Esta decisiÃƒÂ³n es voluntaria e inmediata.",
    en: "{actorName} has returned from the {fromRole} role to the {toRole} role at {libraryName}. This decision is voluntary and effective immediately.",
    it: "{actorName} ÃƒÂ¨ tornato/a/e dal ruolo di {fromRole} al ruolo di {toRole} a {libraryName}. Questa decisione ÃƒÂ¨ volontaria e immediata.",
    de: "{actorName} ist von der Rolle {fromRole} zur Rolle {toRole} bei {libraryName} zurÃƒÂ¼ckgekehrt. Diese Entscheidung ist freiwillig und sofort wirksam."
  },

  // ===== Team Ã¢â‚¬â€ Demande de retrait avec carence 7j (team.removal_*) =========
  "team.removal_requested.sub": {
    "pt-BR": "Pedido de retirada concernente a vocÃƒÂª",
    fr: "Demande de retrait te concernant",
    es: "Solicitud de retiro que te concierne",
    en: "Removal request concerning you",
    it: "Richiesta di rimozione che ti riguarda",
    de: "Antrag auf Entzug, der dich betrifft"
  },
  "team.removal_requested.intro": {
    "pt-BR": "Um pedido de retirada do papel de {role} concernente a vocÃƒÂª foi depositado na {libraryName}. Este pedido estÃƒÂ¡ submetido a um prazo de 7 dias durante o qual vocÃƒÂª pode trocar com outr(o/a/e)s coordenador(o/a/e)s para compreender ou contestar esta decisÃƒÂ£o. Sem anulaÃƒÂ§ÃƒÂ£o da parte del(e/a/e)s antes de {pendingUntilDate}, seu papel de {role} serÃƒÂ¡ retirado.",
    fr: "Une demande de retrait du rÃƒÂ´le de {role} te concernant a ÃƒÂ©tÃƒÂ© dÃƒÂ©posÃƒÂ©e ÃƒÂ  la {libraryName}. Cette demande est soumise ÃƒÂ  un dÃƒÂ©lai de 7 jours pendant lequel tu peux ÃƒÂ©changer avec les autres coordinateurÃ‚Â·rices pour comprendre ou contester cette dÃƒÂ©cision. Sans annulation de leur part avant le {pendingUntilDate}, ton rÃƒÂ´le de {role} sera retirÃƒÂ©.",
    es: "Une solicitud de retiro de le rol de {role} que te concierne fue depositada en le {libraryName}. Esta solicitud estÃƒÂ¡ sometida a un plazo de 7 dÃƒÂ­as durante el cual podÃƒÂ©s intercambiar con les otres coordinadores para comprender o contestar esta decisiÃƒÂ³n. Sin anulaciÃƒÂ³n de su parte antes de le {pendingUntilDate}, tu rol de {role} serÃƒÂ¡ retirado.",
    en: "A request to remove your {role} role at {libraryName} has been filed. This request is subject to a 7-day waiting period during which you may discuss with the other coordinators to understand or contest this decision. Without cancellation on their part before {pendingUntilDate}, your {role} role will be removed.",
    it: "Una richiesta di rimozione dal ruolo di {role} che ti riguarda ÃƒÂ¨ stata depositata a {libraryName}. Questa richiesta ÃƒÂ¨ soggetta a un termine di 7 giorni durante il quale puoi confrontarti con le altre coordinatrici e gli altri coordinatori per comprendere o contestare questa decisione. Senza annullamento da parte loro entro il {pendingUntilDate}, il tuo ruolo di {role} sarÃƒÂ  rimosso.",
    de: "Ein Antrag auf Entzug der Rolle {role}, der dich betrifft, wurde bei {libraryName} eingereicht. Dieser Antrag unterliegt einer Frist von 7 Tagen, wÃƒÂ¤hrend der du dich mit den anderen Koordinator*innen austauschen kannst, um diese Entscheidung zu verstehen oder anzufechten. Ohne Annullierung ihrerseits vor dem {pendingUntilDate} wird deine Rolle als {role} entzogen."
  },
  "team.removal_cancelled.sub": {
    "pt-BR": "O pedido de retirada concernente a vocÃƒÂª foi anulado",
    fr: "La demande de retrait te concernant a ÃƒÂ©tÃƒÂ© annulÃƒÂ©e",
    es: "La solicitud de retiro que te concierne fue anulada",
    en: "The removal request concerning you has been cancelled",
    it: "La richiesta di rimozione che ti riguarda ÃƒÂ¨ stata annullata",
    de: "Der Antrag auf Entzug, der dich betraf, wurde annulliert"
  },
  "team.removal_cancelled.intro": {
    "pt-BR": "O pedido de retirada concernente a vocÃƒÂª na {libraryName} foi anulado por {cancellerName}. VocÃƒÂª recupera todos os seus direitos de {role} imediatamente.",
    fr: "La demande de retrait te concernant ÃƒÂ  la {libraryName} a ÃƒÂ©tÃƒÂ© annulÃƒÂ©e par {cancellerName}. Tu retrouves tous tes droits de {role} immÃƒÂ©diatement.",
    es: "La solicitud de retiro que te concierne en le {libraryName} fue anulada por {cancellerName}. RecuperÃƒÂ¡s todos tus derechos de {role} inmediatamente.",
    en: "The removal request concerning you at {libraryName} has been cancelled by {cancellerName}. You immediately regain all your {role} rights.",
    it: "La richiesta di rimozione che ti riguarda a {libraryName} ÃƒÂ¨ stata annullata da {cancellerName}. Recuperi immediatamente tutti i tuoi diritti di {role}.",
    de: "Der Antrag auf Entzug, der dich bei {libraryName} betraf, wurde von {cancellerName} annulliert. Du erhÃƒÂ¤ltst sofort alle deine Rechte als {role} zurÃƒÂ¼ck."
  },
  "team.removal_completed.sub": {
    "pt-BR": "Sua retirada do papel de {role} foi finalizada",
    fr: "Ton retrait du rÃƒÂ´le de {role} a ÃƒÂ©tÃƒÂ© finalisÃƒÂ©",
    es: "Tu retiro de le rol de {role} fue finalizado",
    en: "Your removal from the {role} role has been finalised",
    it: "La tua rimozione dal ruolo di {role} ÃƒÂ¨ stata finalizzata",
    de: "Dein Entzug der Rolle {role} wurde abgeschlossen"
  },
  "team.removal_completed.intro": {
    "pt-BR": "O prazo de 7 dias decorreu sem anulaÃƒÂ§ÃƒÂ£o. Seu papel de {role} na {libraryName} foi retirado. Se vocÃƒÂª deseja compreender esta decisÃƒÂ£o ou discuti-la, entre em contato com (o/a/e)s coordenador(o/a/e)s.",
    fr: "Le dÃƒÂ©lai de 7 jours s'est ÃƒÂ©coulÃƒÂ© sans annulation. Ton rÃƒÂ´le de {role} ÃƒÂ  la {libraryName} a ÃƒÂ©tÃƒÂ© retirÃƒÂ©. Si tu souhaites comprendre cette dÃƒÂ©cision ou en discuter, contacte les coordinateurÃ‚Â·rices.",
    es: "El plazo de 7 dÃƒÂ­as transcurriÃƒÂ³ sin anulaciÃƒÂ³n. Tu rol de {role} en le {libraryName} fue retirado. Si querÃƒÂ©s comprender esta decisiÃƒÂ³n o discutirla, contactÃƒÂ¡ a les coordinadores.",
    en: "The 7-day period has elapsed without cancellation. Your {role} role at {libraryName} has been removed. If you wish to understand this decision or discuss it, contact the coordinators.",
    it: "Il termine di 7 giorni ÃƒÂ¨ trascorso senza annullamento. Il tuo ruolo di {role} a {libraryName} ÃƒÂ¨ stato rimosso. Se desideri comprendere questa decisione o discuterne, contatta le coordinatrici e i coordinatori.",
    de: "Die Frist von 7 Tagen ist ohne Annullierung verstrichen. Deine Rolle als {role} bei {libraryName} wurde entzogen. Wenn du diese Entscheidung verstehen oder besprechen mÃƒÂ¶chtest, wende dich an die Koordinator*innen."
  },

  // ===== Team Ã¢â‚¬â€ Suspension immÃƒÂ©diate (team.suspended_*) =====================
  "team.suspended.sub": {
    "pt-BR": "SuspensÃƒÂ£o imediata dos seus direitos de {role}",
    fr: "Suspension immÃƒÂ©diate de tes droits de {role}",
    es: "SuspensiÃƒÂ³n inmediata de tus derechos de {role}",
    en: "Immediate suspension of your {role} rights",
    it: "Sospensione immediata dei tuoi diritti di {role}",
    de: "Sofortige Aussetzung deiner {role}-Rechte"
  },
  "team.suspended.intro": {
    "pt-BR": "Seus direitos de {role} na {libraryName} foram suspensos por medida cautelar. Motivo comunicado: {reason}. Para compreender ou contestar esta decisÃƒÂ£o, entre em contato com (o/a/e)s coordenador(o/a/e)s o mais rÃƒÂ¡pido possÃƒÂ­vel.",
    fr: "Tes droits de {role} ÃƒÂ  la {libraryName} ont ÃƒÂ©tÃƒÂ© suspendus par mesure conservatoire. Motif communiquÃƒÂ© : {reason}. Pour comprendre ou contester cette dÃƒÂ©cision, contacte les coordinateurÃ‚Â·rices au plus vite.",
    es: "Tus derechos de {role} en le {libraryName} fueron suspendidos por medida cautelar. Motivo comunicado: {reason}. Para comprender o contestar esta decisiÃƒÂ³n, contactÃƒÂ¡ a les coordinadores lo antes posible.",
    en: "Your {role} rights at {libraryName} have been suspended as a precautionary measure. Communicated reason: {reason}. To understand or contest this decision, contact the coordinators as soon as possible.",
    it: "I tuoi diritti di {role} a {libraryName} sono stati sospesi come misura cautelare. Motivo comunicato: {reason}. Per comprendere o contestare questa decisione, contatta le coordinatrici e i coordinatori il prima possibile.",
    de: "Deine {role}-Rechte bei {libraryName} wurden als vorsorgliche MaÃƒÅ¸nahme ausgesetzt. Mitgeteilter Grund: {reason}. Um diese Entscheidung zu verstehen oder anzufechten, wende dich so schnell wie mÃƒÂ¶glich an die Koordinator*innen."
  },
  "team.unsuspended.sub": {
    "pt-BR": "Levantamento da sua suspensÃƒÂ£o",
    fr: "LevÃƒÂ©e de ta suspension",
    es: "Levantamiento de tu suspensiÃƒÂ³n",
    en: "Lifting of your suspension",
    it: "Revoca della tua sospensione",
    de: "Aufhebung deiner Aussetzung"
  },
  "team.unsuspended.intro": {
    "pt-BR": "A suspensÃƒÂ£o dos seus direitos de {role} na {libraryName} foi levantada por {actorName}. VocÃƒÂª recupera imediatamente seus acessos.",
    fr: "La suspension de tes droits de {role} ÃƒÂ  la {libraryName} a ÃƒÂ©tÃƒÂ© levÃƒÂ©e par {actorName}. Tu retrouves immÃƒÂ©diatement tes accÃƒÂ¨s.",
    es: "La suspensiÃƒÂ³n de tus derechos de {role} en le {libraryName} fue levantada por {actorName}. RecuperÃƒÂ¡s inmediatamente tus accesos.",
    en: "The suspension of your {role} rights at {libraryName} has been lifted by {actorName}. You immediately regain your access.",
    it: "La sospensione dei tuoi diritti di {role} a {libraryName} ÃƒÂ¨ stata revocata da {actorName}. Recuperi immediatamente i tuoi accessi.",
    de: "Die Aussetzung deiner {role}-Rechte bei {libraryName} wurde von {actorName} aufgehoben. Du erhÃƒÂ¤ltst sofort deinen Zugang zurÃƒÂ¼ck."
  },

  // ===== Team Ã¢â‚¬â€ Escalades aux administrateurÃ‚Â·rices AnarBib (team.last_*) ====
  "team.last_coordinator_left.sub": {
    "pt-BR": "{libraryName} nÃƒÂ£o tem mais coordenador(o/a/e)",
    fr: "{libraryName} n'a plus de coordinateurÃ‚Â·rice",
    es: "{libraryName} ya no tiene coordinadore",
    en: "{libraryName} no longer has a coordinator",
    it: "{libraryName} non ha piÃƒÂ¹ coordinatori/trici/e",
    de: "{libraryName} hat keine Koordinator*in mehr"
  },
  "team.last_coordinator_left.intro": {
    "pt-BR": "A biblioteca {libraryName} encontra-se sem coordenador(o/a/e) ativ(o/a/e). {actorName} acaba de retornar a um papel nÃƒÂ£o-coordenador, e ninguÃƒÂ©m mais ocupa o papel. A biblioteca permanece funcional tecnicamente (os bibliotecÃƒÂ¡ri(o/a/e)s podem continuar a operar) mas nÃƒÂ£o tem mais instÃƒÂ¢ncia de coordenaÃƒÂ§ÃƒÂ£o interna. Uma intervenÃƒÂ§ÃƒÂ£o polÃƒÂ­tica da rede AnarBib ÃƒÂ© provavelmente necessÃƒÂ¡ria.",
    fr: "La bibliothÃƒÂ¨que {libraryName} se retrouve sans coordinateurÃ‚Â·rice actifÃ‚Â·ve. {actorName} vient de revenir ÃƒÂ  un rÃƒÂ´le non-coordinateur, et personne d'autre n'occupe le rÃƒÂ´le. La bibliothÃƒÂ¨que reste fonctionnelle techniquement (les bibliothÃƒÂ©caires peuvent toujours opÃƒÂ©rer) mais n'a plus d'instance de coordination interne. Une intervention politique du rÃƒÂ©seau AnarBib est probablement nÃƒÂ©cessaire.",
    es: "La biblioteca {libraryName} se encuentra sin coordinadore active. {actorName} acaba de volver a un rol no-coordinadore, y nadie mÃƒÂ¡s ocupa el rol. La biblioteca permanece funcional tÃƒÂ©cnicamente (les bibliotecaries pueden seguir operando) pero ya no tiene instancia de coordinaciÃƒÂ³n interna. Una intervenciÃƒÂ³n polÃƒÂ­tica de le red AnarBib es probablemente necesaria.",
    en: "The {libraryName} library finds itself without an active coordinator. {actorName} has just returned to a non-coordinator role, and no one else holds the position. The library remains technically functional (librarians can still operate) but no longer has an internal coordination body. A political intervention from the AnarBib network is likely necessary.",
    it: "La biblioteca {libraryName} si ritrova senza coordinatori/trici/e attivi/e. {actorName} ÃƒÂ¨ appena tornato/a/e a un ruolo non-coordinatore, e nessun'altra persona occupa il ruolo. La biblioteca rimane funzionale tecnicamente (le bibliotecarie e i bibliotecari possono continuare a operare) ma non ha piÃƒÂ¹ un'istanza di coordinamento interna. Un intervento politico della rete AnarBib ÃƒÂ¨ probabilmente necessario.",
    de: "Die Bibliothek {libraryName} steht ohne aktive Koordinator*in da. {actorName} ist soeben zu einer Nicht-Koordinator*innen-Rolle zurÃƒÂ¼ckgekehrt, und niemand sonst nimmt die Rolle wahr. Die Bibliothek bleibt technisch funktionsfÃƒÂ¤hig (die Bibliothekar*innen kÃƒÂ¶nnen weiter arbeiten), hat aber keine interne Koordinationsinstanz mehr. Eine politische Intervention des AnarBib-Netzwerks ist wahrscheinlich notwendig."
  },
  "team.last_coordinator_pending_removal.sub": {
    "pt-BR": "{libraryName} corre risco de ficar sem coordenador(o/a/e)",
    fr: "{libraryName} risque de se retrouver sans coordinateurÃ‚Â·rice",
    es: "{libraryName} corre el riesgo de quedarse sin coordinadore",
    en: "{libraryName} risks finding itself without a coordinator",
    it: "{libraryName} rischia di ritrovarsi senza coordinatori/trici/e",
    de: "{libraryName} lÃƒÂ¤uft Gefahr, ohne Koordinator*in dazustehen"
  },
  "team.last_coordinator_pending_removal.intro": {
    "pt-BR": "A biblioteca {libraryName} nÃƒÂ£o terÃƒÂ¡ mais coordenador(o/a/e) ativ(o/a/e) a partir de {pendingUntilDate} se o pedido de retirada em curso nÃƒÂ£o for anulado. {actorName} pediu a retirada d(o/a/e) ÃƒÂºltim(o/a/e) coordenador(o/a/e) ativ(o/a/e) da biblioteca. VocÃƒÂª pode observar a situaÃƒÂ§ÃƒÂ£o, ou intervir politicamente se necessÃƒÂ¡rio.",
    fr: "La bibliothÃƒÂ¨que {libraryName} aura plus de coordinateurÃ‚Â·rice actifÃ‚Â·ve ÃƒÂ  partir du {pendingUntilDate} si la demande de retrait en cours n'est pas annulÃƒÂ©e. {actorName} a demandÃƒÂ© le retrait de la derniÃƒÂ¨re coordinateurÃ‚Â·rice actifÃ‚Â·ve de la bibliothÃƒÂ¨que. Tu peux observer la situation, ou intervenir politiquement si nÃƒÂ©cessaire.",
    es: "La biblioteca {libraryName} ya no tendrÃƒÂ¡ coordinadore active a partir de le {pendingUntilDate} si la solicitud de retiro en curso no es anulada. {actorName} solicitÃƒÂ³ el retiro de le ÃƒÂºltima coordinadore active de la biblioteca. PodÃƒÂ©s observar la situaciÃƒÂ³n, o intervenir polÃƒÂ­ticamente si es necesario.",
    en: "The {libraryName} library will have no active coordinator from {pendingUntilDate} onwards if the pending removal request is not cancelled. {actorName} requested the removal of the last active coordinator at the library. You may observe the situation, or intervene politically if necessary.",
    it: "La biblioteca {libraryName} non avrÃƒÂ  piÃƒÂ¹ coordinatori/trici/e attivi/e a partire dal {pendingUntilDate} se la richiesta di rimozione in corso non viene annullata. {actorName} ha richiesto la rimozione dell'ultim(o/a/e) coordinator(e/trice/e) attiv(o/a/e) della biblioteca. Puoi osservare la situazione, o intervenire politicamente se necessario.",
    de: "Die Bibliothek {libraryName} wird ab dem {pendingUntilDate} keine aktive Koordinator*in mehr haben, falls der laufende Antrag auf Entzug nicht annulliert wird. {actorName} hat den Entzug der letzten aktiven Koordinator*in der Bibliothek beantragt. Du kannst die Situation beobachten oder politisch intervenieren, falls notwendig."
  },

  // ===== Team Ã¢â‚¬â€ Avertissements et passage en inactif (team.inactive_*) ======
  // Ãƒâ€°cole 1 stricte : "inactif" qualifie "compte" / "statut" (concepts), donc
  // accord grammatical standard, pas de marquage militant.
  "team.inactive_warning_30d.sub": {
    "pt-BR": "Sua conta vai passar a inativa em 30 dias",
    fr: "Ton compte va passer en inactif dans 30 jours",
    es: "Tu cuenta va a pasar a inactiva en 30 dÃƒÂ­as",
    en: "Your account will become inactive in 30 days",
    it: "Il tuo account passerÃƒÂ  a inattivo tra 30 giorni",
    de: "Dein Konto wird in 30 Tagen inaktiv"
  },
  "team.inactive_warning_30d.intro": {
    "pt-BR": "VocÃƒÂª nÃƒÂ£o se conectou em AnarBib hÃƒÂ¡ 8 meses. Sem conexÃƒÂ£o da sua parte nos prÃƒÂ³ximos 30 dias, seu status de {role} na {libraryName} passarÃƒÂ¡ automaticamente a inativo. Para conservar seus acessos, conecte-se simplesmente a AnarBib antes de {deadlineDate}.",
    fr: "Tu ne t'es pas connectÃƒÂ©Ã‚Â·e sur AnarBib depuis 8 mois. Sans connexion de ta part dans les 30 prochains jours, ton statut de {role} ÃƒÂ  la {libraryName} passera automatiquement en inactif. Pour conserver tes accÃƒÂ¨s, connecte-toi simplement ÃƒÂ  AnarBib avant le {deadlineDate}.",
    es: "No te conectaste a AnarBib desde hace 8 meses. Sin conexiÃƒÂ³n de tu parte en los prÃƒÂ³ximos 30 dÃƒÂ­as, tu estatus de {role} en le {libraryName} pasarÃƒÂ¡ automÃƒÂ¡ticamente a inactivo. Para conservar tus accesos, conectate simplemente a AnarBib antes de le {deadlineDate}.",
    en: "You have not signed in to AnarBib for 8 months. Without a connection on your part within the next 30 days, your {role} status at {libraryName} will automatically become inactive. To keep your access, simply log in to AnarBib before {deadlineDate}.",
    it: "Non ti sei connesso/a/e ad AnarBib da 8 mesi. Senza una connessione da parte tua nei prossimi 30 giorni, il tuo status di {role} a {libraryName} passerÃƒÂ  automaticamente a inattivo. Per conservare i tuoi accessi, connettiti semplicemente ad AnarBib prima del {deadlineDate}.",
    de: "Du hast dich seit 8 Monaten nicht mehr bei AnarBib angemeldet. Ohne Anmeldung deinerseits in den nÃƒÂ¤chsten 30 Tagen wird dein Status als {role} bei {libraryName} automatisch auf inaktiv gesetzt. Um deinen Zugang zu behalten, melde dich einfach bei AnarBib vor dem {deadlineDate} an."
  },
  "team.inactive_warning_7d.sub": {
    "pt-BR": "ÃƒÅ¡ltimo lembrete: sua conta passa a inativa em 7 dias",
    fr: "Dernier rappel : ton compte passe en inactif dans 7 jours",
    es: "ÃƒÅ¡ltimo recordatorio: tu cuenta pasa a inactiva en 7 dÃƒÂ­as",
    en: "Last reminder: your account becomes inactive in 7 days",
    it: "Ultimo promemoria: il tuo account passa a inattivo tra 7 giorni",
    de: "Letzte Erinnerung: Dein Konto wird in 7 Tagen inaktiv"
  },
  "team.inactive_warning_7d.intro": {
    "pt-BR": "Sem conexÃƒÂ£o da sua parte nos prÃƒÂ³ximos 7 dias, seu status de {role} na {libraryName} passarÃƒÂ¡ automaticamente a inativo em {deadlineDate}.",
    fr: "Sans connexion de ta part dans les 7 prochains jours, ton statut de {role} ÃƒÂ  la {libraryName} passera automatiquement en inactif le {deadlineDate}.",
    es: "Sin conexiÃƒÂ³n de tu parte en los prÃƒÂ³ximos 7 dÃƒÂ­as, tu estatus de {role} en le {libraryName} pasarÃƒÂ¡ automÃƒÂ¡ticamente a inactivo el {deadlineDate}.",
    en: "Without a connection on your part within the next 7 days, your {role} status at {libraryName} will automatically become inactive on {deadlineDate}.",
    it: "Senza una connessione da parte tua nei prossimi 7 giorni, il tuo status di {role} a {libraryName} passerÃƒÂ  automaticamente a inattivo il {deadlineDate}.",
    de: "Ohne Anmeldung deinerseits in den nÃƒÂ¤chsten 7 Tagen wird dein Status als {role} bei {libraryName} am {deadlineDate} automatisch auf inaktiv gesetzt."
  },
  "team.inactive_completed.sub": {
    "pt-BR": "Sua conta passou a inativa",
    fr: "Ton compte est passÃƒÂ© en inactif",
    es: "Tu cuenta pasÃƒÂ³ a inactiva",
    en: "Your account has become inactive",
    it: "Il tuo account ÃƒÂ¨ passato a inattivo",
    de: "Dein Konto ist inaktiv geworden"
  },
  "team.inactive_completed.intro": {
    "pt-BR": "ApÃƒÂ³s 9 meses sem conexÃƒÂ£o, seu status de {role} na {libraryName} passou a inativo. Seus acessos estÃƒÂ£o fechados. Se vocÃƒÂª desejar recuperÃƒÂ¡-los, entre em contato com (o/a/e)s coordenador(o/a/e)s da biblioteca para uma reativaÃƒÂ§ÃƒÂ£o.",
    fr: "AprÃƒÂ¨s 9 mois sans connexion, ton statut de {role} ÃƒÂ  la {libraryName} est passÃƒÂ© en inactif. Tes accÃƒÂ¨s sont fermÃƒÂ©s. Si tu souhaites les retrouver, contacte les coordinateurÃ‚Â·rices de la bibliothÃƒÂ¨que pour une rÃƒÂ©activation.",
    es: "DespuÃƒÂ©s de 9 meses sin conexiÃƒÂ³n, tu estatus de {role} en le {libraryName} pasÃƒÂ³ a inactivo. Tus accesos estÃƒÂ¡n cerrados. Si querÃƒÂ©s recuperarlos, contactÃƒÂ¡ a les coordinadores de la biblioteca para una reactivaciÃƒÂ³n.",
    en: "After 9 months without a connection, your {role} status at {libraryName} has become inactive. Your access is closed. If you wish to regain it, contact the library coordinators for a reactivation.",
    it: "Dopo 9 mesi senza connessione, il tuo status di {role} a {libraryName} ÃƒÂ¨ passato a inattivo. I tuoi accessi sono chiusi. Se desideri recuperarli, contatta le coordinatrici e i coordinatori della biblioteca per una riattivazione.",
    de: "Nach 9 Monaten ohne Anmeldung ist dein Status als {role} bei {libraryName} auf inaktiv gesetzt worden. Dein Zugang ist geschlossen. Wenn du ihn zurÃƒÂ¼ckerhalten mÃƒÂ¶chtest, wende dich an die Koordinator*innen der Bibliothek fÃƒÂ¼r eine Reaktivierung."
  },

  // ===== Welcome Ã¢â‚¬â€ mail de bienvenue post-inscription (welcome.*) ============
  // Section utilisÃƒÂ©e par register/index.ts > buildUserMail()
  // Cas standard : inscription rattachÃƒÂ©e ÃƒÂ  une biblio existante
  // Cas "initial" : inscription orpheline (signup_without_library=true)
  //   Ã¢â€ â€™ contient le CTA vers /solicitar-biblioteca avec claim token (TTL 14j)
  "welcome.subject": {
    "pt-BR": "Cadastro criado Ã¢â‚¬â€ {displayName}",
    fr: "Inscription crÃƒÂ©ÃƒÂ©e Ã¢â‚¬â€ {displayName}",
    es: "InscripciÃƒÂ³n creada Ã¢â‚¬â€ {displayName}",
    en: "Registration created Ã¢â‚¬â€ {displayName}",
    it: "Iscrizione creata Ã¢â‚¬â€ {displayName}",
    de: "Anmeldung erstellt Ã¢â‚¬â€ {displayName}"
  },
  "welcome.subject.initial": {
    "pt-BR": "Cadastro inicial criado Ã¢â‚¬â€ {displayName}",
    fr: "Inscription initiale crÃƒÂ©ÃƒÂ©e Ã¢â‚¬â€ {displayName}",
    es: "InscripciÃƒÂ³n inicial creada Ã¢â‚¬â€ {displayName}",
    en: "Initial registration created Ã¢â‚¬â€ {displayName}",
    it: "Iscrizione iniziale creata Ã¢â‚¬â€ {displayName}",
    de: "Anmeldung initialisiert Ã¢â‚¬â€ {displayName}"
  },
  "welcome.pretitle": {
    "pt-BR": "Cadastro criado",
    fr: "Inscription crÃƒÂ©ÃƒÂ©e",
    es: "InscripciÃƒÂ³n creada",
    en: "Registration created",
    it: "Iscrizione creata",
    de: "Anmeldung erstellt"
  },
  "welcome.pretitle.initial": {
    "pt-BR": "Cadastro inicial criado",
    fr: "Inscription initiale crÃƒÂ©ÃƒÂ©e",
    es: "InscripciÃƒÂ³n inicial creada",
    en: "Initial registration created",
    it: "Iscrizione iniziale creata",
    de: "Anmeldung initialisiert"
  },
  "welcome.title.initial": {
    "pt-BR": "Bem-vindo/a/e ÃƒÂ  rede AnarBib",
    fr: "Bienvenue dans le rÃƒÂ©seau AnarBib",
    es: "Bienvenide a la red AnarBib",
    en: "Welcome to the AnarBib network",
    it: "BenvenutÃ‰â„¢ nella rete AnarBib",
    de: "Willkommen im AnarBib-Netzwerk"
  },
   "welcome.title": {
    "pt-BR": "Bem-vindo/a/e ÃƒÂ  {libraryName}",
    fr: "Bienvenue ÃƒÂ  la {libraryName}",
    es: "Bienvenide a le {libraryName}",
    en: "Welcome to {libraryName}",
    it: "BenvenutÃ‰â„¢ alla {libraryName}",
    de: "Willkommen bei {libraryName}"
  },
  "welcome.subtitle": {
    "pt-BR": "Seu acesso inicial ao AnarBib jÃƒÂ¡ estÃƒÂ¡ pronto.",
    fr: "Ton accÃƒÂ¨s initial ÃƒÂ  AnarBib est prÃƒÂªt.",
    es: "Tu acceso inicial a AnarBib ya estÃƒÂ¡ listo.",
    en: "Your initial access to AnarBib is ready.",
    it: "Il tuo accesso iniziale ad AnarBib ÃƒÂ¨ pronto.",
    de: "Dein erster Zugang zu AnarBib ist bereit."
  },
  "welcome.greeting": {
    "pt-BR": "OlÃƒÂ¡, <b>{firstName}</b>.",
    fr: "Bonjour, <b>{firstName}</b>.",
    es: "Hola, <b>{firstName}</b>.",
    en: "Hello, <b>{firstName}</b>.",
    it: "Ciao, <b>{firstName}</b>.",
    de: "Hallo, <b>{firstName}</b>."
  },
  "welcome.context.standard": {
    "pt-BR": "Seu cadastro de leitor/a/e na <b>{libraryName}</b> foi criado com sucesso.",
    fr: "Ton inscription en tant que lecteurÃ‚Â·rice ÃƒÂ  la <b>{libraryName}</b> a ÃƒÂ©tÃƒÂ© crÃƒÂ©ÃƒÂ©e avec succÃƒÂ¨s.",
    es: "Tu inscripciÃƒÂ³n como lector(a/e) en le <b>{libraryName}</b> fue creada con ÃƒÂ©xito.",
    en: "Your reader registration at <b>{libraryName}</b> has been created successfully.",
    it: "La tua iscrizione come lettore/lettrice presso <b>{libraryName}</b> ÃƒÂ¨ stata creata con successo.",
    de: "Deine Leser*innen-Anmeldung bei <b>{libraryName}</b> wurde erfolgreich erstellt."
  },
  "welcome.context.initial": {
    "pt-BR": "Sua conta inicial no <b>AnarBib</b> foi criada com sucesso. A prÃƒÂ³xima etapa ÃƒÂ© enviar a solicitaÃƒÂ§ÃƒÂ£o institucional da sua biblioteca para anÃƒÂ¡lise da coordenaÃƒÂ§ÃƒÂ£o da rede.",
    fr: "Ton compte initial sur <b>AnarBib</b> a ÃƒÂ©tÃƒÂ© crÃƒÂ©ÃƒÂ© avec succÃƒÂ¨s. La prochaine ÃƒÂ©tape est d'envoyer la demande institutionnelle de ta bibliothÃƒÂ¨que pour analyse de la coordination du rÃƒÂ©seau.",
    es: "Tu cuenta inicial en <b>AnarBib</b> fue creada con ÃƒÂ©xito. El prÃƒÂ³ximo paso es enviar la solicitud institucional de tu biblioteca para anÃƒÂ¡lisis de la coordinaciÃƒÂ³n de la red.",
    en: "Your initial account on <b>AnarBib</b> has been created successfully. The next step is to submit the institutional request for your library to the network coordination for review.",
    it: "Il tuo account iniziale su <b>AnarBib</b> ÃƒÂ¨ stato creato con successo. Il prossimo passo ÃƒÂ¨ inviare la richiesta istituzionale della tua biblioteca per l'analisi del coordinamento della rete.",
    de: "Dein erstes Konto auf <b>AnarBib</b> wurde erfolgreich erstellt. Der nÃƒÂ¤chste Schritt ist, den institutionellen Antrag deiner Bibliothek zur PrÃƒÂ¼fung durch die Netzwerkkoordination einzureichen."
  },
  "welcome.publicIdLabel": {
    "pt-BR": "Seu ID pÃƒÂºblico",
    fr: "Ton identifiant public",
    es: "Tu identificador pÃƒÂºblico",
    en: "Your public ID",
    it: "Il tuo ID pubblico",
    de: "Deine ÃƒÂ¶ffentliche Kennung"
  },
  "welcome.tempPasswordLabel": {
    "pt-BR": "Senha provisÃƒÂ³ria",
    fr: "Mot de passe provisoire",
    es: "ContraseÃƒÂ±a provisional",
    en: "Temporary password",
    it: "Password provvisoria",
    de: "VorlÃƒÂ¤ufiges Passwort"
  },
  "welcome.nextAccess": {
    "pt-BR": "Nos prÃƒÂ³ximos acessos ao AnarBib, entre com seu <b>ID pÃƒÂºblico</b> e sua senha.",
    fr: "Pour tes prochains accÃƒÂ¨s ÃƒÂ  AnarBib, connecte-toi avec ton <b>identifiant public</b> et ton mot de passe.",
    es: "En tus prÃƒÂ³ximos accesos a AnarBib, ingresÃƒÂ¡ con tu <b>identificador pÃƒÂºblico</b> y tu contraseÃƒÂ±a.",
    en: "For your next visits to AnarBib, log in with your <b>public ID</b> and your password.",
    it: "Per i tuoi prossimi accessi ad AnarBib, accedi con il tuo <b>ID pubblico</b> e la tua password.",
    de: "Bei deinen nÃƒÂ¤chsten Anmeldungen bei AnarBib verwende deine <b>ÃƒÂ¶ffentliche Kennung</b> und dein Passwort."
  },
  "welcome.important": {
    "pt-BR": "<b>Importante:</b> a senha enviada aqui ÃƒÂ© provisÃƒÂ³ria. Depois do primeiro acesso, altere-a na pÃƒÂ¡gina <b>Conta</b>.",
    fr: "<b>Important :</b> le mot de passe envoyÃƒÂ© ici est provisoire. DÃƒÂ¨s ton premier accÃƒÂ¨s, tu seras invitÃƒÂ©Ã‚Â·e ÃƒÂ  le changer.",
    es: "<b>Importante:</b> la contraseÃƒÂ±a enviada aquÃƒÂ­ es provisional. En tu primer acceso, se te invitarÃƒÂ¡ a cambiarla.",
    en: "<b>Important:</b> the password sent here is temporary. On your first login, you will be prompted to change it.",
    it: "<b>Importante:</b> la password inviata qui ÃƒÂ¨ provvisoria. Al primo accesso, ti verrÃƒÂ  chiesto di cambiarla.",
    de: "<b>Wichtig:</b> Das hier gesendete Passwort ist vorlÃƒÂ¤ufig. Bei deiner ersten Anmeldung wirst du aufgefordert, es zu ÃƒÂ¤ndern."
  },
  "welcome.forgotHint": {
    "pt-BR": "Se vocÃƒÂª perder o acesso, use o botÃƒÂ£o <b>Ã¢â‚¬Å“Esqueci minha senhaÃ¢â‚¬Â</b> na pÃƒÂ¡gina de login.",
    fr: "Si tu perds l'accÃƒÂ¨s, utilise le bouton <b>Ã‚Â« Mot de passe oubliÃƒÂ© Ã‚Â»</b> sur la page de connexion.",
    es: "Si perdÃƒÂ©s el acceso, usÃƒÂ¡ el botÃƒÂ³n <b>Ã‚Â«OlvidÃƒÂ© mi contraseÃƒÂ±aÃ‚Â»</b> en la pÃƒÂ¡gina de inicio de sesiÃƒÂ³n.",
    en: "If you lose access, use the <b>Ã¢â‚¬Å“Forgot my passwordÃ¢â‚¬Â</b> button on the login page.",
    it: "Se perdi l'accesso, usa il pulsante <b>Ã‚Â«Ho dimenticato la passwordÃ‚Â»</b> nella pagina di accesso.",
    de: "Wenn du den Zugang verlierst, verwende die SchaltflÃƒÂ¤che <b>Ã¢â‚¬Å¾Passwort vergessenÃ¢â‚¬Å“</b> auf der Anmeldeseite."
  },
  "welcome.libraryRequest.intro": {
    "pt-BR": "Use o botÃƒÂ£o abaixo para iniciar a solicitaÃƒÂ§ÃƒÂ£o institucional da sua biblioteca. Este link jÃƒÂ¡ estÃƒÂ¡ ligado ÃƒÂ  sua conta inicial, nÃƒÂ£o precisa entrar manualmente de novo para comeÃƒÂ§ar.",
    fr: "Utilise le bouton ci-dessous pour initier la demande institutionnelle de ta bibliothÃƒÂ¨que. Ce lien est dÃƒÂ©jÃƒÂ  liÃƒÂ© ÃƒÂ  ton compte initial, tu n'as pas besoin de te reconnecter manuellement pour commencer.",
    es: "UsÃƒÂ¡ el botÃƒÂ³n de abajo para iniciar la solicitud institucional de tu biblioteca. Este enlace ya estÃƒÂ¡ vinculado a tu cuenta inicial, no necesitÃƒÂ¡s iniciar sesiÃƒÂ³n manualmente otra vez para comenzar.",
    en: "Use the button below to start the institutional request for your library. This link is already tied to your initial account Ã¢â‚¬â€ no need to log in manually again to begin.",
    it: "Usa il pulsante qui sotto per avviare la richiesta istituzionale della tua biblioteca. Questo link ÃƒÂ¨ giÃƒÂ  collegato al tuo account iniziale, non hai bisogno di accedere manualmente di nuovo per iniziare.",
    de: "Verwende die SchaltflÃƒÂ¤che unten, um den institutionellen Antrag deiner Bibliothek zu starten. Dieser Link ist bereits mit deinem ersten Konto verknÃƒÂ¼pft Ã¢â‚¬â€ du musst dich nicht erneut manuell anmelden, um zu beginnen."
  },
  "welcome.libraryRequest.cta": {
    "pt-BR": "Iniciar solicitaÃƒÂ§ÃƒÂ£o da biblioteca",
    fr: "DÃƒÂ©marrer la demande de bibliothÃƒÂ¨que",
    es: "Iniciar solicitud de la biblioteca",
    en: "Start the library request",
    it: "Avviare la richiesta della biblioteca",
    de: "Antrag der Bibliothek starten"
  },
  "welcome.libraryRequest.fallback": {
    "pt-BR": "Se o link expirar, entre em contato com a coordenaÃƒÂ§ÃƒÂ£o do AnarBib para receber um novo acesso.",
    fr: "Si le lien expire, contacte la coordination d'AnarBib pour recevoir un nouvel accÃƒÂ¨s.",
    es: "Si el enlace expira, contactÃƒÂ¡ a la coordinaciÃƒÂ³n de AnarBib para recibir un nuevo acceso.",
    en: "If the link expires, contact the AnarBib coordination to receive a new access.",
    it: "Se il link scade, contatta il coordinamento di AnarBib per ricevere un nuovo accesso.",
    de: "Wenn der Link ablÃƒÂ¤uft, wende dich an die AnarBib-Koordination, um einen neuen Zugang zu erhalten."
  },
  "welcome.libraryAddressLabel": {
    "pt-BR": "EndereÃƒÂ§o da biblioteca:",
    fr: "Adresse de la bibliothÃƒÂ¨que :",
    es: "DirecciÃƒÂ³n de la biblioteca:",
    en: "Library address:",
    it: "Indirizzo della biblioteca:",
    de: "Adresse der Bibliothek:"
  },
  "welcome.libraryContactLabel": {
    "pt-BR": "Contato da biblioteca:",
    fr: "Contact de la bibliothÃƒÂ¨que :",
    es: "Contacto de la biblioteca:",
    en: "Library contact:",
    it: "Contatto della biblioteca:",
    de: "Kontakt der Bibliothek:"
  },
  "welcome.autoMessage": {
    "pt-BR": "Mensagem automÃƒÂ¡tica do cadastro AnarBib. As respostas a este e-mail serÃƒÂ£o encaminhadas para a gestÃƒÂ£o do projeto.",
    fr: "Message automatique de l'inscription AnarBib. Les rÃƒÂ©ponses ÃƒÂ  cet e-mail sont transmises ÃƒÂ  la gestion du projet.",
    es: "Mensaje automÃƒÂ¡tico del registro AnarBib. Las respuestas a este correo serÃƒÂ¡n reenviadas a la gestiÃƒÂ³n del proyecto.",
    en: "Automatic message from the AnarBib registration. Replies to this email are forwarded to the project management.",
    it: "Messaggio automatico dell'iscrizione AnarBib. Le risposte a questa e-mail vengono inoltrate alla gestione del progetto.",
    de: "Automatische Nachricht der AnarBib-Anmeldung. Antworten auf diese E-Mail werden an die Projektleitung weitergeleitet."
  },

// ============================================================================
// Paquet E.1 Ã¢â‚¬â€ Bloc i18n ÃƒÂ  insÃƒÂ©rer dans mail-strings.ts
// ============================================================================
// 6 events Ãƒâ€” 6 locales (pt-BR, fr, es, en, it, de)
// Conventions militantes strictes par locale (cf. en-tÃƒÂªte mail-strings.ts) :
//   pt-BR : triple o/a/e, d(o/a/e), dest(e/a)
//   fr    : point mÃƒÂ©dian (lecteurÃ‚Â·rice, leÃ‚Â·la)
//   es    : neutre argentin (le, les, une, conectade)
//   en    : neutre standard ÃƒÂ©picÃƒÂ¨ne
//   it    : compagno/a/e
//   de    : Genderstern (Leser*in, Genoss*in)
// Adresse : vouvoiement neutre (vos / votre / your / ihrÃ‚Â·e / usted / vostro / Sie)
//
// GranularitÃƒÂ© par event :
//   - network.cooptation_reminder       : .sub .intro .cta .deadline_label
//   - network.collective_removal_proposed : .sub .intro .cta .motivation_label
//   - network.collective_removal_vote_cast : .sub .intro .rationale_label
//   - network.collective_removal_unanimous : .sub .intro .carence_label .target_intro
//   - network.collective_removal_cancelled : .sub .intro
//   - network.collective_removal_executed  : .sub .intro .target_intro
//
// Placeholders standard utilisÃƒÂ©s :
//   {proposedName}    nom de la personne proposÃƒÂ©e (cooptation) ou ciblÃƒÂ©e (retrait)
//   {proposerName}    nom de la personne qui propose
//   {voterName}       nom du votant (peut ÃƒÂªtre "Pessoa anÃƒÂ´nima" si non-disclose)
//   {voteKind}        favor / against (dÃƒÂ©jÃƒÂ  traduit cÃƒÂ´tÃƒÂ© EF avant insertion)
//   {pendingDeadline} date lisible pour fin de carence ou fin de fenÃƒÂªtre
// ============================================================================

  // ===== network.cooptation_reminder ========================================
  // Rappel J+14 ou J+25 envoyÃƒÂ© aux admins n'ayant pas votÃƒÂ©.
  // Edge Function : choisira le bon variant via payload.reminder_kind ('j14'|'j25')
  // et prÃƒÂ©fixera le sujet par "[J+14]" ou "[J+25]" si pertinent.
  "network.cooptation_reminder.sub": {
    "pt-BR": "Lembrete : votaÃƒÂ§ÃƒÂ£o pendente sobre a cooptaÃƒÂ§ÃƒÂ£o de {proposedName}",
    fr: "Rappel Ã‚Â· vote en attente sur la cooptation de {proposedName}",
    es: "Recordatorio Ã‚Â· votaciÃƒÂ³n pendiente sobre la cooptaciÃƒÂ³n de {proposedName}",
    en: "Reminder Ã‚Â· pending vote on the cooptation of {proposedName}",
    it: "Promemoria Ã‚Â· voto in sospeso sulla cooptazione di {proposedName}",
    de: "Erinnerung Ã‚Â· ausstehende Abstimmung zur Kooptation von {proposedName}"
  },
  "network.cooptation_reminder.intro": {
    "pt-BR": "Uma proposta de cooptaÃƒÂ§ÃƒÂ£o foi aberta hÃƒÂ¡ vÃƒÂ¡rios dias e ainda aguarda vossa decisÃƒÂ£o. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s ÃƒÂ© necessÃƒÂ¡ria para concluir o processo.",
    fr: "Une proposition de cooptation a ÃƒÂ©tÃƒÂ© ouverte il y a plusieurs jours et attend encore votre dÃƒÂ©cision. L'unanimitÃƒÂ© des administrateurÃ‚Â·rices actifÃ‚Â·ves est nÃƒÂ©cessaire pour conclure le processus.",
    es: "Una propuesta de cooptaciÃƒÂ³n fue abierta hace varios dÃƒÂ­as y aÃƒÂºn espera vuestra decisiÃƒÂ³n. La unanimidad de les administradores activos es necesaria para cerrar el proceso.",
    en: "A cooptation proposal was opened several days ago and is still awaiting your decision. Unanimity among active network administrators is required to complete the process.",
    it: "Una proposta di cooptazione ÃƒÂ¨ stata aperta diversi giorni fa e attende ancora la vostra decisione. L'unanimitÃƒÂ  dei compagni/e amministratori/e attivi/e ÃƒÂ¨ necessaria per concludere il processo.",
    de: "Ein Kooptationsvorschlag wurde vor mehreren Tagen erÃƒÂ¶ffnet und wartet noch auf Ihre Entscheidung. Einstimmigkeit der aktiven Netzwerk-Administrator*innen ist erforderlich, um den Prozess abzuschlieÃƒÅ¸en."
  },
  "network.cooptation_reminder.cta": {
    "pt-BR": "Acessar a proposta e votar",
    fr: "AccÃƒÂ©der ÃƒÂ  la proposition et voter",
    es: "Acceder a la propuesta y votar",
    en: "Open the proposal and vote",
    it: "Accedere alla proposta e votare",
    de: "Vorschlag ÃƒÂ¶ffnen und abstimmen"
  },
  "network.cooptation_reminder.deadline_label": {
    "pt-BR": "A proposta expira em {pendingDeadline}.",
    fr: "La proposition expire le {pendingDeadline}.",
    es: "La propuesta expira el {pendingDeadline}.",
    en: "The proposal expires on {pendingDeadline}.",
    it: "La proposta scade il {pendingDeadline}.",
    de: "Der Vorschlag lÃƒÂ¤uft am {pendingDeadline} ab."
  },

  // ===== network.collective_removal_proposed ================================
  // EnvoyÃƒÂ© aux autres admins actifs (hors proposeur, hors target).
  // Le target n'est pas notifiÃƒÂ© ÃƒÂ  cette ÃƒÂ©tape (doctrine v0.3 Ã‚Â§Q5).
  "network.collective_removal_proposed.sub": {
    "pt-BR": "Proposta de retirada coletiva : {proposedName}",
    fr: "Proposition de retrait collectif Ã‚Â· {proposedName}",
    es: "Propuesta de retiro colectivo Ã‚Â· {proposedName}",
    en: "Collective removal proposal Ã‚Â· {proposedName}",
    it: "Proposta di ritiro collettivo Ã‚Â· {proposedName}",
    de: "Vorschlag eines kollektiven RÃƒÂ¼ckzugs Ã‚Â· {proposedName}"
  },
  "network.collective_removal_proposed.intro": {
    "pt-BR": "{proposerName} abriu uma proposta de retirada coletiva d(o/a/e) administrador(a/e) {proposedName}. Esta ÃƒÂ© uma decisÃƒÂ£o polÃƒÂ­tica grave que exige unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s (excluÃƒÂ­d(o/a/e) (o/a/e) prÃƒÂ³prio(a/e) target). Vosso voto ÃƒÂ© necessÃƒÂ¡rio.",
    fr: "{proposerName} a ouvert une proposition de retrait collectif de l'administrateurÃ‚Â·rice {proposedName}. Il s'agit d'une dÃƒÂ©cision politique grave qui requiert l'unanimitÃƒÂ© des administrateurÃ‚Â·rices actifÃ‚Â·ves (ÃƒÂ  l'exclusion de la personne ciblÃƒÂ©e). Votre vote est nÃƒÂ©cessaire.",
    es: "{proposerName} abriÃƒÂ³ una propuesta de retiro colectivo de le administrade {proposedName}. Es una decisiÃƒÂ³n polÃƒÂ­tica grave que exige la unanimidad de les administradores activos (excluide le propie target). Vuestro voto es necesario.",
    en: "{proposerName} has opened a proposal for the collective removal of network administrator {proposedName}. This is a serious political decision requiring unanimity among active administrators (excluding the target). Your vote is needed.",
    it: "{proposerName} ha aperto una proposta di ritiro collettivo dell'amministratore/trice/e {proposedName}. ÃƒË† una decisione politica grave che richiede l'unanimitÃƒÂ  dei compagni/e amministratori/e attivi/e (escluso/a/e (il/la/le) compagno/a/e oggetto). Il vostro voto ÃƒÂ¨ necessario.",
    de: "{proposerName} hat einen Vorschlag zum kollektiven RÃƒÂ¼ckzug von Netzwerk-Administrator*in {proposedName} erÃƒÂ¶ffnet. Dies ist eine schwerwiegende politische Entscheidung, die die Einstimmigkeit der aktiven Administrator*innen erfordert (ausgenommen die betroffene Person). Ihre Stimme ist erforderlich."
  },
  "network.collective_removal_proposed.cta": {
    "pt-BR": "Acessar a proposta e votar",
    fr: "AccÃƒÂ©der ÃƒÂ  la proposition et voter",
    es: "Acceder a la propuesta y votar",
    en: "Open the proposal and vote",
    it: "Accedere alla proposta e votare",
    de: "Vorschlag ÃƒÂ¶ffnen und abstimmen"
  },
  "network.collective_removal_proposed.motivation_label": {
    "pt-BR": "MotivaÃƒÂ§ÃƒÂ£o invocada :",
    fr: "Motivation invoquÃƒÂ©e :",
    es: "MotivaciÃƒÂ³n invocada :",
    en: "Stated motivation:",
    it: "Motivazione invocata :",
    de: "Angegebene BegrÃƒÂ¼ndung:"
  },

  // ===== network.collective_removal_vote_cast ===============================
  // EnvoyÃƒÂ© aux autres admins actifs aprÃƒÂ¨s chaque vote intermÃƒÂ©diaire
  // (hors votant, hors target).
  // payload.voter_user_id peut ÃƒÂªtre NULL si disclose_identity=false cÃƒÂ´tÃƒÂ© DB :
  // dans ce cas, l'Edge Function substituera {voterName} par une chaÃƒÂ®ne neutre.
  "network.collective_removal_vote_cast.sub": {
    "pt-BR": "Voto registrado sobre a retirada coletiva : {proposedName}",
    fr: "Vote enregistrÃƒÂ© sur le retrait collectif de {proposedName}",
    es: "Voto registrado sobre el retiro colectivo de {proposedName}",
    en: "Vote recorded on the collective removal of {proposedName}",
    it: "Voto registrato sul ritiro collettivo di {proposedName}",
    de: "Stimme zum kollektiven RÃƒÂ¼ckzug von {proposedName} registriert"
  },
  "network.collective_removal_vote_cast.intro": {
    "pt-BR": "Un(a/e) administrador(a/e) registrou seu voto sobre a proposta de retirada coletiva d(o/a/e) {proposedName}. O processo continua aberto atÃƒÂ© que tod(o/a/e)s tenham se pronunciado.",
    fr: "UnÃ‚Â·e administrateurÃ‚Â·rice a enregistrÃƒÂ© son vote sur la proposition de retrait collectif de {proposedName}. Le processus reste ouvert tant que toutes les voix ne se sont pas exprimÃƒÂ©es.",
    es: "Une administrade ha registrado su voto sobre la propuesta de retiro colectivo de {proposedName}. El proceso sigue abierto hasta que todes se hayan pronunciado.",
    en: "A network administrator has recorded their vote on the collective removal proposal for {proposedName}. The process remains open until all voices have been heard.",
    it: "Un(o/a/e) amministratore/trice/e ha registrato il proprio voto sulla proposta di ritiro collettivo di {proposedName}. Il processo resta aperto fino a quando tutt(i/e/u) si saranno pronunciat(i/e/u).",
    de: "Ein*e Netzwerk-Administrator*in hat seineÃ‚Â·ihre Stimme zum Vorschlag des kollektiven RÃƒÂ¼ckzugs von {proposedName} abgegeben. Der Prozess bleibt offen, bis alle Stimmen abgegeben wurden."
  },
  "network.collective_removal_vote_cast.rationale_label": {
    "pt-BR": "Justificativa (obrigatÃƒÂ³ria se voto contrÃƒÂ¡rio) :",
    fr: "Justification (obligatoire si vote contre) :",
    es: "JustificaciÃƒÂ³n (obligatoria si voto en contra) :",
    en: "Rationale (mandatory if voting against):",
    it: "Motivazione (obbligatoria in caso di voto contrario) :",
    de: "BegrÃƒÂ¼ndung (verpflichtend bei Gegenstimme):"
  },

  // ===== network.collective_removal_unanimous ===============================
  // EnvoyÃƒÂ© ÃƒÂ  TOUS les admins actifs (target inclus) au moment oÃƒÂ¹ l'unanimitÃƒÂ©
  // est atteinte. DÃƒÂ©clenche les 7 jours de carence avant exÃƒÂ©cution.
  // L'Edge Function adaptera l'intro selon que le destinataire est le target
  // ou un autre admin (variante .target_intro).
  "network.collective_removal_unanimous.sub": {
    "pt-BR": "Retirada coletiva confirmada por unanimidade : {proposedName} Ã¢â‚¬â€ carÃƒÂªncia de 7 dias",
    fr: "Retrait collectif confirmÃƒÂ© ÃƒÂ  l'unanimitÃƒÂ© Ã‚Â· {proposedName} Ã¢â‚¬â€ carence de 7 jours",
    es: "Retiro colectivo confirmado por unanimidad Ã‚Â· {proposedName} Ã¢â‚¬â€ perÃƒÂ­odo de gracia de 7 dÃƒÂ­as",
    en: "Collective removal confirmed by unanimity Ã‚Â· {proposedName} Ã¢â‚¬â€ 7-day grace period",
    it: "Ritiro collettivo confermato all'unanimitÃƒÂ  Ã‚Â· {proposedName} Ã¢â‚¬â€ periodo di grazia di 7 giorni",
    de: "Kollektiver RÃƒÂ¼ckzug einstimmig bestÃƒÂ¤tigt Ã‚Â· {proposedName} Ã¢â‚¬â€ 7-tÃƒÂ¤gige Karenzfrist"
  },
  "network.collective_removal_unanimous.intro": {
    "pt-BR": "A unanimidade d(o/a/e)s administrador(a/e)s foi alcanÃƒÂ§ada sobre a retirada coletiva d(o/a/e) {proposedName}. Uma carÃƒÂªncia de 7 dias se aplica antes da efetivaÃƒÂ§ÃƒÂ£o. Durante este perÃƒÂ­odo, qualquer votante pode anular a decisÃƒÂ£o se houver mudanÃƒÂ§a de posiÃƒÂ§ÃƒÂ£o coletiva.",
    fr: "L'unanimitÃƒÂ© des administrateurÃ‚Â·rices a ÃƒÂ©tÃƒÂ© atteinte sur le retrait collectif de {proposedName}. Une carence de 7 jours s'applique avant exÃƒÂ©cution. Pendant cette pÃƒÂ©riode, toutÃ‚Â·e votantÃ‚Â·e peut annuler la dÃƒÂ©cision en cas de changement de position collective.",
    es: "Se alcanzÃƒÂ³ la unanimidad de les administradores sobre el retiro colectivo de {proposedName}. Se aplica un perÃƒÂ­odo de gracia de 7 dÃƒÂ­as antes de la ejecuciÃƒÂ³n. Durante este perÃƒÂ­odo, cualquier votante puede anular la decisiÃƒÂ³n si hay un cambio de posiciÃƒÂ³n colectiva.",
    en: "Unanimity among network administrators has been reached on the collective removal of {proposedName}. A 7-day grace period applies before execution. During this period, any voter may cancel the decision if the collective position changes.",
    it: "L'unanimitÃƒÂ  dei compagni/e amministratori/e ÃƒÂ¨ stata raggiunta sul ritiro collettivo di {proposedName}. Si applica un periodo di grazia di 7 giorni prima dell'esecuzione. Durante questo periodo, qualsiasi votante puÃƒÂ² annullare la decisione in caso di cambiamento di posizione collettiva.",
    de: "Einstimmigkeit der Netzwerk-Administrator*innen ÃƒÂ¼ber den kollektiven RÃƒÂ¼ckzug von {proposedName} wurde erreicht. Eine 7-tÃƒÂ¤gige Karenzfrist gilt vor der Vollziehung. WÃƒÂ¤hrend dieser Frist kann jede*r Abstimmende die Entscheidung aufheben, falls sich die kollektive Position ÃƒÂ¤ndert."
  },
  "network.collective_removal_unanimous.target_intro": {
    "pt-BR": "Esta mensagem informa que a unanimidade d(o/a/e)s outr(o/a/e)s administrador(a/e)s ativ(o/a/e)s foi alcanÃƒÂ§ada sobre a vossa retirada coletiva. Uma carÃƒÂªncia de 7 dias se aplica antes da efetivaÃƒÂ§ÃƒÂ£o. Vossa palavra ÃƒÂ© livre durante esta janela.",
    fr: "Ce message vous informe que l'unanimitÃƒÂ© des autres administrateurÃ‚Â·rices actifÃ‚Â·ves a ÃƒÂ©tÃƒÂ© atteinte sur votre retrait collectif. Une carence de 7 jours s'applique avant exÃƒÂ©cution. Votre parole est libre durant cette fenÃƒÂªtre.",
    es: "Este mensaje le informa que se alcanzÃƒÂ³ la unanimidad de les otres administradores activos sobre vuestro retiro colectivo. Se aplica un perÃƒÂ­odo de gracia de 7 dÃƒÂ­as antes de la ejecuciÃƒÂ³n. Vuestra palabra es libre durante esta ventana.",
    en: "This message informs you that unanimity among the other active network administrators has been reached regarding your collective removal. A 7-day grace period applies before execution. Your voice remains free during this window.",
    it: "Questo messaggio vi informa che l'unanimitÃƒÂ  degli/delle altr(i/e/u) compagn(i/e/u) amministratori/e attivi/e ÃƒÂ¨ stata raggiunta sul vostro ritiro collettivo. Si applica un periodo di grazia di 7 giorni prima dell'esecuzione. La vostra parola resta libera durante questa finestra.",
    de: "Diese Nachricht informiert Sie darÃƒÂ¼ber, dass die Einstimmigkeit der anderen aktiven Netzwerk-Administrator*innen ÃƒÂ¼ber Ihren kollektiven RÃƒÂ¼ckzug erreicht wurde. Eine 7-tÃƒÂ¤gige Karenzfrist gilt vor der Vollziehung. Ihr Wort bleibt frei wÃƒÂ¤hrend dieses Zeitraums."
  },
  "network.collective_removal_unanimous.carence_label": {
    "pt-BR": "EfetivaÃƒÂ§ÃƒÂ£o prevista para {pendingDeadline}.",
    fr: "ExÃƒÂ©cution prÃƒÂ©vue pour le {pendingDeadline}.",
    es: "EjecuciÃƒÂ³n prevista para el {pendingDeadline}.",
    en: "Execution scheduled for {pendingDeadline}.",
    it: "Esecuzione prevista per il {pendingDeadline}.",
    de: "Vollziehung vorgesehen fÃƒÂ¼r {pendingDeadline}."
  },

  // ===== network.collective_removal_cancelled ===============================
  // EnvoyÃƒÂ© aux autres admins (et au target si la proposition ÃƒÂ©tait unanimous).
  // Purement informatif.
  "network.collective_removal_cancelled.sub": {
    "pt-BR": "Retirada coletiva cancelada : {proposedName}",
    fr: "Retrait collectif annulÃƒÂ© Ã‚Â· {proposedName}",
    es: "Retiro colectivo cancelado Ã‚Â· {proposedName}",
    en: "Collective removal cancelled Ã‚Â· {proposedName}",
    it: "Ritiro collettivo annullato Ã‚Â· {proposedName}",
    de: "Kollektiver RÃƒÂ¼ckzug abgebrochen Ã‚Â· {proposedName}"
  },
  "network.collective_removal_cancelled.intro": {
    "pt-BR": "A proposta de retirada coletiva d(o/a/e) {proposedName} foi anulada. Nenhuma efetivaÃƒÂ§ÃƒÂ£o serÃƒÂ¡ realizada. Esta decisÃƒÂ£o ÃƒÂ© registrada no histÃƒÂ³rico militante da rede.",
    fr: "La proposition de retrait collectif de {proposedName} a ÃƒÂ©tÃƒÂ© annulÃƒÂ©e. Aucune exÃƒÂ©cution ne sera rÃƒÂ©alisÃƒÂ©e. Cette dÃƒÂ©cision est consignÃƒÂ©e dans l'historique militant du rÃƒÂ©seau.",
    es: "La propuesta de retiro colectivo de {proposedName} fue cancelada. No se realizarÃƒÂ¡ ninguna ejecuciÃƒÂ³n. Esta decisiÃƒÂ³n queda registrada en el historial militante de la red.",
    en: "The collective removal proposal for {proposedName} has been cancelled. No execution will occur. This decision is recorded in the militant history of the network.",
    it: "La proposta di ritiro collettivo di {proposedName} ÃƒÂ¨ stata annullata. Nessuna esecuzione avrÃƒÂ  luogo. Questa decisione ÃƒÂ¨ registrata nella storia militante della rete.",
    de: "Der Vorschlag zum kollektiven RÃƒÂ¼ckzug von {proposedName} wurde abgebrochen. Es erfolgt keine Vollziehung. Diese Entscheidung wird in der militanten Geschichte des Netzwerks festgehalten."
  },

  // ===== network.collective_removal_executed ================================
  // EnvoyÃƒÂ© aprÃƒÂ¨s la carence de 7j, par le cron. Au target + autres admins.
  // L'Edge Function adaptera selon destinataire (target vs autres) via
  // variante .target_intro.
  "network.collective_removal_executed.sub": {
    "pt-BR": "Retirada coletiva efetivada : {proposedName}",
    fr: "Retrait collectif effectif Ã‚Â· {proposedName}",
    es: "Retiro colectivo efectivo Ã‚Â· {proposedName}",
    en: "Collective removal effective Ã‚Â· {proposedName}",
    it: "Ritiro collettivo effettivo Ã‚Â· {proposedName}",
    de: "Kollektiver RÃƒÂ¼ckzug wirksam Ã‚Â· {proposedName}"
  },
  "network.collective_removal_executed.intro": {
    "pt-BR": "ApÃƒÂ³s o tÃƒÂ©rmino da carÃƒÂªncia de 7 dias, a retirada coletiva d(o/a/e) {proposedName} foi efetivada. Esta pessoa nÃƒÂ£o tem mais o papel d(o/a/e) administrador(a/e) de rede. A decisÃƒÂ£o ÃƒÂ© registrada no histÃƒÂ³rico militante d(o/a/e) AnarBib.",
    fr: "Ãƒâ‚¬ l'issue de la carence de 7 jours, le retrait collectif de {proposedName} a ÃƒÂ©tÃƒÂ© effectuÃƒÂ©. Cette personne n'occupe plus la fonction d'administrateurÃ‚Â·rice de rÃƒÂ©seau. La dÃƒÂ©cision est consignÃƒÂ©e dans l'historique militant d'AnarBib.",
    es: "Tras el fin del perÃƒÂ­odo de gracia de 7 dÃƒÂ­as, el retiro colectivo de {proposedName} se hizo efectivo. Esta persona ya no ocupa la funciÃƒÂ³n de administrade de red. La decisiÃƒÂ³n queda registrada en el historial militante de AnarBib.",
    en: "After the 7-day grace period, the collective removal of {proposedName} has been carried out. This person no longer holds the network administrator role. The decision is recorded in the militant history of AnarBib.",
    it: "Al termine del periodo di grazia di 7 giorni, il ritiro collettivo di {proposedName} ÃƒÂ¨ stato attuato. Questa persona non ricopre piÃƒÂ¹ il ruolo di amministratore/trice/e di rete. La decisione ÃƒÂ¨ registrata nella storia militante di AnarBib.",
    de: "Nach Ablauf der 7-tÃƒÂ¤gigen Karenzfrist wurde der kollektive RÃƒÂ¼ckzug von {proposedName} vollzogen. Diese Person ist nicht mehr Netzwerk-Administrator*in. Die Entscheidung wird in der militanten Geschichte von AnarBib festgehalten."
  },
  "network.collective_removal_executed.target_intro": {
    "pt-BR": "A carÃƒÂªncia de 7 dias terminou e a retirada coletiva votada por unanimidade estÃƒÂ¡ agora efetiva. Vossa funÃƒÂ§ÃƒÂ£o d(o/a/e) administrador(a/e) de rede no AnarBib foi removida. Esta decisÃƒÂ£o ÃƒÂ© registrada no histÃƒÂ³rico militante.",
    fr: "La carence de 7 jours est arrivÃƒÂ©e ÃƒÂ  terme et le retrait collectif votÃƒÂ© ÃƒÂ  l'unanimitÃƒÂ© prend effet. Votre fonction d'administrateurÃ‚Â·rice de rÃƒÂ©seau dans AnarBib a ÃƒÂ©tÃƒÂ© retirÃƒÂ©e. Cette dÃƒÂ©cision est consignÃƒÂ©e dans l'historique militant.",
    es: "TerminÃƒÂ³ el perÃƒÂ­odo de gracia de 7 dÃƒÂ­as y el retiro colectivo votado por unanimidad entra en vigor. Vuestra funciÃƒÂ³n de administrade de red en AnarBib fue retirada. Esta decisiÃƒÂ³n queda registrada en el historial militante.",
    en: "The 7-day grace period has ended and the unanimously-voted collective removal now takes effect. Your network administrator role in AnarBib has been removed. This decision is recorded in the militant history.",
    it: "Il periodo di grazia di 7 giorni ÃƒÂ¨ terminato e il ritiro collettivo votato all'unanimitÃƒÂ  entra in vigore. La vostra funzione di amministratore/trice/e di rete in AnarBib ÃƒÂ¨ stata rimossa. Questa decisione ÃƒÂ¨ registrata nella storia militante.",
    de: "Die 7-tÃƒÂ¤gige Karenzfrist ist abgelaufen, und der einstimmig beschlossene kollektive RÃƒÂ¼ckzug wird wirksam. Ihre Funktion als Netzwerk-Administrator*in in AnarBib wurde entzogen. Diese Entscheidung wird in der militanten Geschichte festgehalten."
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
    "pt-BR": "Proposta de cooptacao : {proposedName}",
    fr: "Proposition de cooptation : {proposedName}",
    es: "Propuesta de cooptacion : {proposedName}",
    en: "Cooptation proposal: {proposedName}",
    it: "Proposta di cooptazione : {proposedName}",
    de: "Kooptationsvorschlag: {proposedName}"
  },
  "network.cooptation_proposed.intro": {
    "pt-BR": "{proposerName} propos cooptar {proposedName} como administrador(a/e) de rede. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s e necessaria para concluir o processo. Vosso voto e esperado.",
    fr: "{proposerName} propose de coopter {proposedName} comme administrateurÂ·rice du reseau. L'unanimite des administrateurÂ·rices actifÂ·ves est necessaire pour conclure le processus. Votre vote est attendu.",
    es: "{proposerName} propone cooptar a {proposedName} como administrade de red. La unanimidad de les administradores activos es necesaria para cerrar el proceso. Vuestro voto es esperado.",
    en: "{proposerName} proposes to coopt {proposedName} as a network administrator. Unanimity among active network administrators is required to complete the process. Your vote is expected.",
    it: "{proposerName} propone di cooptare {proposedName} come amministratore/trice/e di rete. L'unanimita dei compagni/e amministratori/e attivi/e e necessaria per concludere il processo. Il vostro voto e atteso.",
    de: "{proposerName} schlagt vor, {proposedName} als Netzwerk-Administrator*in zu kooptieren. Die Einstimmigkeit der aktiven Netzwerk-Administrator*innen ist erforderlich, um den Prozess abzuschliessen. Ihre Stimme wird erwartet."
  },
  "network.cooptation_proposed.cta": {
    "pt-BR": "Acessar a proposta e votar",
    fr: "Acceder a la proposition et voter",
    es: "Acceder a la propuesta y votar",
    en: "Open the proposal and vote",
    it: "Accedere alla proposta e votare",
    de: "Vorschlag offnen und abstimmen"
  },
  "network.cooptation_proposed.motivation_label": {
    "pt-BR": "Motivacao invocada :",
    fr: "Motivation invoquee :",
    es: "Motivacion invocada :",
    en: "Stated motivation:",
    it: "Motivazione invocata :",
    de: "Angegebene Begrundung:"
  },

  // ===== network.cooptation_voted ===========================================
  // Envoye aux autres admins (hors votant, hors target) apres chaque vote
  // intermediaire (Q1 transparence). payload.voter_user_id peut etre NULL
  // si disclose_identity=false : cote EF, substitution par chaine neutre.
  "network.cooptation_voted.sub": {
    "pt-BR": "Voto registrado sobre a cooptacao de {proposedName}",
    fr: "Vote enregistre sur la cooptation de {proposedName}",
    es: "Voto registrado sobre la cooptacion de {proposedName}",
    en: "Vote recorded on the cooptation of {proposedName}",
    it: "Voto registrato sulla cooptazione di {proposedName}",
    de: "Stimme zur Kooptation von {proposedName} registriert"
  },
  "network.cooptation_voted.intro": {
    "pt-BR": "Un(a/e) administrador(a/e) registrou seu voto sobre a proposta de cooptacao de {proposedName}. O processo continua aberto ate que tod(o/a/e)s tenham se pronunciado, ou ate que um voto contrario encerre o processo.",
    fr: "UnÂ·e administrateurÂ·rice a enregistre son vote sur la proposition de cooptation de {proposedName}. Le processus reste ouvert tant que toutes les voix ne se sont pas exprimees, ou jusqu'a ce qu'un vote contre ne le cloture.",
    es: "Une administrade ha registrado su voto sobre la propuesta de cooptacion de {proposedName}. El proceso sigue abierto hasta que todes se hayan pronunciado, o hasta que un voto en contra lo cierre.",
    en: "A network administrator has recorded their vote on the cooptation proposal for {proposedName}. The process remains open until all voices have been heard, or until an opposing vote closes it.",
    it: "Un(o/a/e) amministratore/trice/e ha registrato il proprio voto sulla proposta di cooptazione di {proposedName}. Il processo resta aperto fino a quando tutt(i/e/u) si saranno pronunciat(i/e/u), o fino a quando un voto contrario non lo chiudera.",
    de: "Ein*e Netzwerk-Administrator*in hat seineÂ·ihre Stimme zum Kooptationsvorschlag fur {proposedName} abgegeben. Der Prozess bleibt offen, bis alle Stimmen abgegeben wurden, oder bis eine Gegenstimme ihn beendet."
  },
  "network.cooptation_voted.rationale_label": {
    "pt-BR": "Justificativa (obrigatoria se voto contrario) :",
    fr: "Justification (obligatoire si vote contre) :",
    es: "Justificacion (obligatoria si voto en contra) :",
    en: "Rationale (mandatory if voting against):",
    it: "Motivazione (obbligatoria in caso di voto contrario) :",
    de: "Begrundung (verpflichtend bei Gegenstimme):"
  },

  // ===== network.cooptation_rejected ========================================
  // Un seul vote opposed = veto immediat (doctrine v0.3 unanimite).
  // Q3 : target + proposeur + autres admins.
  // Variante target_intro pour le target ("votre cooptation a ete refusee").
  "network.cooptation_rejected.sub": {
    "pt-BR": "Cooptacao recusada : {proposedName}",
    fr: "Cooptation refusee : {proposedName}",
    es: "Cooptacion rechazada : {proposedName}",
    en: "Cooptation rejected: {proposedName}",
    it: "Cooptazione rifiutata : {proposedName}",
    de: "Kooptation abgelehnt: {proposedName}"
  },
  "network.cooptation_rejected.intro": {
    "pt-BR": "A proposta de cooptacao de {proposedName} foi recusada apos um voto contrario. A doutrina de unanimidade torna esta decisao imediata. Esta informacao e registrada no historico militante d(o/a/e) AnarBib.",
    fr: "La proposition de cooptation de {proposedName} a ete refusee suite a un vote contre. La doctrine d'unanimite rend cette decision immediate. Cette information est consignee dans l'historique militant d'AnarBib.",
    es: "La propuesta de cooptacion de {proposedName} fue rechazada tras un voto en contra. La doctrina de unanimidad hace que esta decision sea inmediata. Esta informacion queda registrada en el historial militante de AnarBib.",
    en: "The cooptation proposal for {proposedName} has been rejected following an opposing vote. The unanimity doctrine makes this decision immediate. This information is recorded in the militant history of AnarBib.",
    it: "La proposta di cooptazione di {proposedName} e stata rifiutata in seguito a un voto contrario. La dottrina dell'unanimita rende questa decisione immediata. Questa informazione e registrata nella storia militante di AnarBib.",
    de: "Der Kooptationsvorschlag fur {proposedName} wurde nach einer Gegenstimme abgelehnt. Die Einstimmigkeitsdoktrin macht diese Entscheidung sofortig. Diese Information wird in der militanten Geschichte von AnarBib festgehalten."
  },
  "network.cooptation_rejected.target_intro": {
    "pt-BR": "A proposta de cooptacao que vos dizia respeito foi recusada apos um voto contrario. Em AnarBib, a unanimidade d(o/a/e)s administrador(a/e)s e necessaria para uma cooptacao : um unico voto contra encerra o processo. Esta decisao nao impede de futuras propostas se a posicao coletiva evoluir.",
    fr: "La proposition de cooptation qui vous concernait a ete refusee suite a un vote contre. Dans AnarBib, l'unanimite des administrateurÂ·rices est requise pour une cooptation : un seul vote contre cloture le processus. Cette decision n'empeche pas de futures propositions si la position collective evolue.",
    es: "La propuesta de cooptacion que le concernia fue rechazada tras un voto en contra. En AnarBib, la unanimidad de les administradores es necesaria para una cooptacion : un solo voto en contra cierra el proceso. Esta decision no impide propuestas futuras si la posicion colectiva evoluciona.",
    en: "The cooptation proposal concerning you has been rejected following an opposing vote. In AnarBib, unanimity among administrators is required for a cooptation: a single opposing vote closes the process. This decision does not preclude future proposals if the collective position evolves.",
    it: "La proposta di cooptazione che vi riguardava e stata rifiutata in seguito a un voto contrario. In AnarBib, l'unanimita dei compagni/e amministratori/e e necessaria per una cooptazione : un solo voto contrario chiude il processo. Questa decisione non impedisce proposte future se la posizione collettiva evolve.",
    de: "Der Kooptationsvorschlag, der Sie betraf, wurde nach einer Gegenstimme abgelehnt. In AnarBib ist Einstimmigkeit der Administrator*innen fur eine Kooptation erforderlich: eine einzige Gegenstimme beendet den Prozess. Diese Entscheidung schliesst zukunftige Vorschlage nicht aus, falls sich die kollektive Position weiterentwickelt."
  },

  // ===== network.cooptation_completed =======================================
  // Unanimite atteinte. Q4 : target + proposeur + autres admins.
  // Variante target_intro : ton particulier "bienvenue dans la coordination".
  "network.cooptation_completed.sub": {
    "pt-BR": "Cooptacao confirmada por unanimidade : {proposedName}",
    fr: "Cooptation confirmee a l'unanimite : {proposedName}",
    es: "Cooptacion confirmada por unanimidad : {proposedName}",
    en: "Cooptation confirmed by unanimity: {proposedName}",
    it: "Cooptazione confermata all'unanimita : {proposedName}",
    de: "Kooptation einstimmig bestatigt: {proposedName}"
  },
  "network.cooptation_completed.intro": {
    "pt-BR": "A unanimidade d(o/a/e)s administrador(a/e)s foi alcancada sobre a cooptacao de {proposedName}. Esta pessoa entra a partir de agora na coordenacao da rede AnarBib. A decisao e registrada no historico militante.",
    fr: "L'unanimite des administrateurÂ·rices a ete atteinte sur la cooptation de {proposedName}. Cette personne rejoint la coordination du reseau AnarBib des maintenant. La decision est consignee dans l'historique militant.",
    es: "Se alcanzo la unanimidad de les administradores sobre la cooptacion de {proposedName}. Esta persona se integra a la coordinacion de la red AnarBib desde ahora. La decision queda registrada en el historial militante.",
    en: "Unanimity among administrators has been reached on the cooptation of {proposedName}. This person joins the AnarBib network coordination from now on. The decision is recorded in the militant history.",
    it: "L'unanimita dei compagni/e amministratori/e e stata raggiunta sulla cooptazione di {proposedName}. Questa persona entra a far parte della coordinazione della rete AnarBib da ora. La decisione e registrata nella storia militante.",
    de: "Einstimmigkeit der Administrator*innen wurde fur die Kooptation von {proposedName} erreicht. Diese Person tritt ab sofort der Koordination des AnarBib-Netzwerks bei. Die Entscheidung wird in der militanten Geschichte festgehalten."
  },
  "network.cooptation_completed.target_intro": {
    "pt-BR": "Bem-vind(o/a/e) a coordenacao da rede AnarBib. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s foi alcancada sobre vossa cooptacao, e a partir de agora vos sois administrador(a/e) ativ(o/a/e) da rede. Esta responsabilidade vos da acesso a propostas de cooptacao, votos de retirada coletiva, e governanca transversal d(o/a/e) AnarBib.",
    fr: "Bienvenue dans la coordination du reseau AnarBib. L'unanimite des administrateurÂ·rices actifÂ·ves a ete atteinte sur votre cooptation, et vous etes desormais administrateurÂ·rice actifÂ·ve du reseau. Cette responsabilite vous donne acces aux propositions de cooptation, aux votes de retrait collectif et a la gouvernance transversale d'AnarBib.",
    es: "Bienvenide a la coordinacion de la red AnarBib. Se alcanzo la unanimidad de les administradores activos sobre vuestra cooptacion, y desde ahora vos sois administrade activo de la red. Esta responsabilidad le da acceso a propuestas de cooptacion, votos de retiro colectivo y gobernanza transversal de AnarBib.",
    en: "Welcome to the AnarBib network coordination. Unanimity among active administrators has been reached on your cooptation, and you are now an active network administrator. This responsibility gives you access to cooptation proposals, collective removal votes, and the transversal governance of AnarBib.",
    it: "Benvenut(o/a/e) nella coordinazione della rete AnarBib. L'unanimita dei compagni/e amministratori/e attivi/e e stata raggiunta sulla vostra cooptazione, e da ora siete amministratore/trice/e attivo/a/e della rete. Questa responsabilita vi da accesso alle proposte di cooptazione, ai voti di ritiro collettivo e alla governance trasversale di AnarBib.",
    de: "Willkommen in der Koordination des AnarBib-Netzwerks. Die Einstimmigkeit der aktiven Administrator*innen wurde fur Ihre Kooptation erreicht, und Sie sind nun aktive*r Netzwerk-Administrator*in. Diese Verantwortung gibt Ihnen Zugang zu Kooptationsvorschlagen, kollektiven Ruckzugsabstimmungen und der ubergreifenden Governance von AnarBib."
  },
  "network.cooptation_completed.cta": {
    "pt-BR": "Acessar o painel de rede",
    fr: "Acceder au tableau de bord du reseau",
    es: "Acceder al panel de red",
    en: "Open the network dashboard",
    it: "Accedere al pannello di rete",
    de: "Netzwerk-Dashboard offnen"
  },
};

const D: SupportedMailLocale = "pt-BR";

// ============================================================================
// API publique du module
// ============================================================================

/**
 * RÃƒÂ©cupÃƒÂ¨re la traduction d'une clÃƒÂ© pour une locale donnÃƒÂ©e.
 * Si la clÃƒÂ© n'existe pas, retourne la clÃƒÂ© brute (pour faciliter le debug).
 * Si la locale n'est pas supportÃƒÂ©e ou est null, fallback vers pt-BR (D).
 *
 * @param locale Code locale (ex: 'pt-BR', 'fr', 'es', etc.) ou null
 * @param key ClÃƒÂ© du dictionnaire (ex: 'wf.ready', 'l.items')
 * @param params ParamÃƒÂ¨tres ÃƒÂ  interpoler (ex: {date: '05/05/2026'})
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

/** Salutation localisÃƒÂ©e, avec ou sans nom. */
export function greeting(locale: string | null | undefined, name?: string | null): string {
  return name ? tMail(locale, "greeting.named", { name }) : tMail(locale, "greeting.anonymous");
}

/** Label localisÃƒÂ© pour les dÃƒÂ©tails de mail (passe par le prÃƒÂ©fixe `l.`). */
export function label(locale: string | null | undefined, key: string): string {
  return tMail(locale, `l.${key}`);
}

/** Statut de tÃƒÂ¢che localisÃƒÂ© (prÃƒÂ©fixe `ts.`). */
export function taskStatusLabel(locale: string | null | undefined, status: string): string {
  return tMail(locale, `ts.${status}`);
}

/** PrioritÃƒÂ© de tÃƒÂ¢che localisÃƒÂ©e (prÃƒÂ©fixe `tp.`). */
export function taskPriorityLabel(locale: string | null | undefined, priority: string): string {
  return tMail(locale, `tp.${priority}`);
}

/** Formate une date selon la locale (DD/MM/YYYY en pt-BR par dÃƒÂ©faut). */
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
// Helpers exportÃƒÂ©s pour les tests anti-rÃƒÂ©gression
// ============================================================================

/** Liste toutes les clÃƒÂ©s dÃƒÂ©finies (utile pour les tests). */
export function _allKeys(): string[] {
  return Object.keys(S);
}

/** Retourne l'ensemble des locales supportÃƒÂ©es (utile pour les tests). */
export function _supportedLocales(): SupportedMailLocale[] {
  return ["pt-BR", "fr", "es", "en", "it", "de"];
}

/** VÃƒÂ©rifie qu'une clÃƒÂ© donnÃƒÂ©e a une traduction non vide pour toutes les locales. */
export function _isComplete(key: string): boolean {
  const d = S[key];
  if (!d) return false;
  for (const loc of _supportedLocales()) {
    if (!d[loc] || !String(d[loc]).trim()) return false;
  }
  return true;
}
