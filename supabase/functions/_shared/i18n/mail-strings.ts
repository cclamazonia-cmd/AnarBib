// ============================================================================
// mail-strings.ts â€” i18n des notifications mail (Edge Function notify-event)
// ============================================================================
// 6 locales : pt-BR (rÃ©fÃ©rence), fr, es, en, it, de
//
// Conventions militantes par locale :
//   pt-BR : triple forme o/a/e, dÃ©monstratifs binÃ´me dest(e/a),
//           contractions article-prÃ©position triples d(o/a/e)
//   fr    : point mÃ©dian (lecteurÂ·rice, leÂ·la)
//   es    : neutre argentin e (le, les, une, conectade), participes accordÃ©s
//   en    : neutre standard (Ã©picÃ¨ne)
//   it    : compagno/a/e ou variantes, JAMAIS camerata
//   de    : Genderstern (Leser*in, Genoss*in), JAMAIS "Compas"
//
// Date du fix : 2026-05-02 (chasse au bug wf.ready / wf.readyShort affichÃ©s
//               en clÃ©s brutes dans les mails â€” clÃ©s manquantes du dictionnaire)
// ============================================================================

export type SupportedMailLocale = "pt-BR" | "fr" | "es" | "en" | "it" | "de";

const V = new Set<string>(["pt-BR", "fr", "es", "en", "it", "de"]);

const S: Record<string, Record<SupportedMailLocale, string>> = {

  // ===== Greetings ==========================================================
  "greeting.named": {
    "pt-BR": "OlÃ¡, {name}!",
    fr: "Bonjour, {name} !",
    es: "Â¡Hola, {name}!",
    en: "Hello, {name}!",
    it: "Ciao, {name}!",
    de: "Hallo, {name}!"
  },
  "greeting.anonymous": {
    "pt-BR": "OlÃ¡!",
    fr: "Bonjour !",
    es: "Â¡Hola!",
    en: "Hello!",
    it: "Ciao!",
    de: "Hallo!"
  },

  // ===== Layout =============================================================
  "layout.autoNotice": {
    "pt-BR": "NotificaÃ§Ã£o automÃ¡tica",
    fr: "Notification automatique",
    es: "NotificaciÃ³n automÃ¡tica",
    en: "Automatic notification",
    it: "Notifica automatica",
    de: "Automatische Benachrichtigung"
  },
  "layout.footerContact": {
    "pt-BR": "Em caso de dÃºvida, entre em contato com a biblioteca.",
    fr: "En cas de question, contacte la bibliothÃ¨que.",
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
    de: "ZurÃ¼ckgegebene Dokumente"
  },
  "l.itemsRemaining": {
    "pt-BR": "Documentos ainda em mÃ£os",
    fr: "Documents encore Ã  rendre",
    es: "Documentos todavÃ­a pendientes",
    en: "Documents still to return",
    it: "Documenti ancora da restituire",
    de: "Noch zurÃ¼ckzugebende Dokumente"
  },
  "l.ref": {
    "pt-BR": "ReferÃªncia",
    fr: "RÃ©fÃ©rence",
    es: "Referencia",
    en: "Reference",
    it: "Riferimento",
    de: "Referenz"
  },
  "l.refs": {
    "pt-BR": "ReferÃªncias",
    fr: "RÃ©fÃ©rences",
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
    "pt-BR": "DevoluÃ§Ã£o prevista",
    fr: "Retour prÃ©vu",
    es: "DevoluciÃ³n prevista",
    en: "Due date",
    it: "Restituzione prevista",
    de: "FÃ¤lligkeitsdatum"
  },
  "l.newDueDate": {
    "pt-BR": "Nova devoluÃ§Ã£o",
    fr: "Nouveau retour",
    es: "Nueva devoluciÃ³n",
    en: "New due date",
    it: "Nuova restituzione",
    de: "Neues FÃ¤lligkeitsdatum"
  },
  "l.deadline": {
    "pt-BR": "Prazo",
    fr: "Ã‰chÃ©ance",
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
    "pt-BR": "RenovaÃ§Ã£o em",
    fr: "RenouvelÃ© le",
    es: "RenovaciÃ³n el",
    en: "Renewed on",
    it: "Rinnovo il",
    de: "VerlÃ¤ngert am"
  },
  "l.return": {
    "pt-BR": "DevoluÃ§Ã£o",
    fr: "Retour",
    es: "DevoluciÃ³n",
    en: "Return",
    it: "Restituzione",
    de: "RÃ¼ckgabe"
  },
  "l.reader": {
    "pt-BR": "Leitor(a/e)",
    fr: "LecteurÂ·rice",
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
    "pt-BR": "SituaÃ§Ã£o",
    fr: "Situation",
    es: "SituaciÃ³n",
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
    "pt-BR": "ObservaÃ§Ã£o",
    fr: "Observation",
    es: "ObservaciÃ³n",
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
    fr: "TÃ¢che",
    es: "Tarea",
    en: "Task",
    it: "Compito",
    de: "Aufgabe"
  },
  "l.priority": {
    "pt-BR": "Prioridade",
    fr: "PrioritÃ©",
    es: "Prioridad",
    en: "Priority",
    it: "PrioritÃ ",
    de: "PrioritÃ¤t"
  },
  "l.tags": {
    "pt-BR": "Marcadores",
    fr: "Ã‰tiquettes",
    es: "Etiquetas",
    en: "Tags",
    it: "Etichette",
    de: "SchlagwÃ¶rter"
  },
  "l.firstDate": {
    "pt-BR": "PrÃ³ximo vencimento",
    fr: "Prochaine Ã©chÃ©ance",
    es: "PrÃ³ximo vencimiento",
    en: "Next due date",
    it: "Prossima scadenza",
    de: "NÃ¤chste FÃ¤lligkeit"
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
    "pt-BR": "ObservaÃ§Ã£o d(o/a/e) leitor(a/e)",
    fr: "Note duÂ·de la lecteurÂ·rice",
    es: "Nota de le lector(a/e)",
    en: "Reader note",
    it: "Nota del/la lettore/trice",
    de: "Anmerkung der*des Leser*in"
  },
  "l.reply": {
    "pt-BR": "Resposta",
    fr: "RÃ©ponse",
    es: "Respuesta",
    en: "Reply",
    it: "Risposta",
    de: "Antwort"
  },
  "l.restrictedSince": {
    "pt-BR": "RestriÃ§Ã£o desde",
    fr: "Restriction depuis",
    es: "RestricciÃ³n desde",
    en: "Restricted since",
    it: "Restrizione da",
    de: "EingeschrÃ¤nkt seit"
  },

  // ===== Reservation events (res.*) =========================================
  "res.created.sub": {
    "pt-BR": "Reserva registrada",
    fr: "RÃ©servation enregistrÃ©e",
    es: "Reserva registrada",
    en: "Reservation registered",
    it: "Prenotazione registrata",
    de: "Vormerkung registriert"
  },
  "res.created.pre": {
    "pt-BR": "Sua reserva foi registrada com sucesso.",
    fr: "Ta rÃ©servation a bien Ã©tÃ© enregistrÃ©e.",
    es: "Tu reserva fue registrada con Ã©xito.",
    en: "Your reservation has been registered.",
    it: "La tua prenotazione Ã¨ stata registrata.",
    de: "Deine Vormerkung wurde registriert."
  },
  "res.created.intro": {
    "pt-BR": "Recebemos sua reserva. A biblioteca confirmarÃ¡ a disponibilidade em breve.",
    fr: "Nous avons reÃ§u ta rÃ©servation. La bibliothÃ¨que confirmera bientÃ´t la disponibilitÃ©.",
    es: "Recibimos tu reserva. La biblioteca confirmarÃ¡ pronto la disponibilidad.",
    en: "We received your reservation. The library will confirm availability soon.",
    it: "Abbiamo ricevuto la tua prenotazione. La biblioteca confermerÃ  presto la disponibilitÃ .",
    de: "Wir haben deine Vormerkung erhalten. Die Bibliothek bestÃ¤tigt bald die VerfÃ¼gbarkeit."
  },
  "res.created.hint": {
    "pt-BR": "VocÃª pode acompanhar o estado d(o/a/e) seu pedido na sua conta.",
    fr: "Tu peux suivre l'Ã©tat de ta demande dans ton compte.",
    es: "Puedes seguir le estade de tu pedido en tu cuenta.",
    en: "You can track your request status in your account.",
    it: "Puoi seguire lo stato della tua richiesta nel tuo account.",
    de: "Du kannst den Status deiner Anfrage in deinem Konto verfolgen."
  },
  "res.created.admin": {
    "pt-BR": "Nova reserva registrada",
    fr: "Nouvelle rÃ©servation enregistrÃ©e",
    es: "Nueva reserva registrada",
    en: "New reservation registered",
    it: "Nuova prenotazione registrata",
    de: "Neue Vormerkung registriert"
  },
  "res.refused": {
    "pt-BR": "Reserva recusada pela biblioteca",
    fr: "RÃ©servation refusÃ©e par la bibliothÃ¨que",
    es: "Reserva rechazada por la biblioteca",
    en: "Reservation declined by the library",
    it: "Prenotazione rifiutata dalla biblioteca",
    de: "Vormerkung von der Bibliothek abgelehnt"
  },
  "res.cancelStaff": {
    "pt-BR": "Reserva cancelada pela biblioteca",
    fr: "RÃ©servation annulÃ©e par la bibliothÃ¨que",
    es: "Reserva cancelada por la biblioteca",
    en: "Reservation cancelled by the library",
    it: "Prenotazione annullata dalla biblioteca",
    de: "Vormerkung von der Bibliothek storniert"
  },
  "res.cancelReader": {
    "pt-BR": "Reserva cancelada por vocÃª",
    fr: "RÃ©servation annulÃ©e par toi",
    es: "Reserva cancelada por ti",
    en: "Reservation cancelled by you",
    it: "Prenotazione annullata da te",
    de: "Vormerkung von dir storniert"
  },
  "res.expired": {
    "pt-BR": "Reserva expirada",
    fr: "RÃ©servation expirÃ©e",
    es: "Reserva expirada",
    en: "Reservation expired",
    it: "Prenotazione scaduta",
    de: "Vormerkung abgelaufen"
  },
  "res.converted": {
    "pt-BR": "Reserva convertida em emprÃ©stimo",
    fr: "RÃ©servation convertie en emprunt",
    es: "Reserva convertide en prÃ©stamo",
    en: "Reservation converted into a loan",
    it: "Prenotazione convertita in prestito",
    de: "Vormerkung in Ausleihe umgewandelt"
  },

  // ===== Workflow events (wf.*) =============================================
  "wf.pickupScheduled": {
    "pt-BR": "Retirada agendada",
    fr: "Retrait programmÃ©",
    es: "Retiro programado",
    en: "Pickup scheduled",
    it: "Ritiro programmato",
    de: "Abholung geplant"
  },
  "wf.pickupRescheduled": {
    "pt-BR": "Retirada reagendada",
    fr: "Retrait reprogrammÃ©",
    es: "Retiro reprogramado",
    en: "Pickup rescheduled",
    it: "Ritiro riprogrammato",
    de: "Abholung neu geplant"
  },
  "wf.ready": {
    "pt-BR": "Sua reserva estÃ¡ pronta para retirada",
    fr: "Ta rÃ©servation est prÃªte Ã  Ãªtre retirÃ©e",
    es: "Tu reserva estÃ¡ lista para retirar",
    en: "Your reservation is ready for pickup",
    it: "La tua prenotazione Ã¨ pronta per il ritiro",
    de: "Deine Vormerkung liegt zur Abholung bereit"
  },
  "wf.readyShort": {
    "pt-BR": "Reserva pronta",
    fr: "RÃ©servation prÃªte",
    es: "Reserva lista",
    en: "Reservation ready",
    it: "Prenotazione pronta",
    de: "Vormerkung bereit"
  },
  "wf.noShow": {
    "pt-BR": "Retirada nÃ£o realizada",
    fr: "Retrait non effectuÃ©",
    es: "Retiro no realizado",
    en: "Pickup missed",
    it: "Ritiro non effettuato",
    de: "Abholung nicht erfolgt"
  },
  "wf.closed": {
    "pt-BR": "Reserva encerrada",
    fr: "RÃ©servation clÃ´turÃ©e",
    es: "Reserva cerrada",
    en: "Reservation closed",
    it: "Prenotazione chiusa",
    de: "Vormerkung abgeschlossen"
  },
  "wf.preparing": {
    "pt-BR": "Sua reserva estÃ¡ em preparaÃ§Ã£o",
    fr: "Ta rÃ©servation est en prÃ©paration",
    es: "Tu reserva estÃ¡ en preparaciÃ³n",
    en: "Your reservation is being prepared",
    it: "La tua prenotazione Ã¨ in preparazione",
    de: "Deine Vormerkung wird vorbereitet"
  },
  "wf.preparingShort": {
    "pt-BR": "Em preparaÃ§Ã£o",
    fr: "En prÃ©paration",
    es: "En preparaciÃ³n",
    en: "Being prepared",
    it: "In preparazione",
    de: "In Vorbereitung"
  },
  "wf.toCoordinate": {
    "pt-BR": "Retirada a combinar com a biblioteca",
    fr: "Retrait Ã  organiser avec la bibliothÃ¨que",
    es: "Retiro a coordinar con la biblioteca",
    en: "Pickup to be arranged with the library",
    it: "Ritiro da concordare con la biblioteca",
    de: "Abholung mit der Bibliothek abzustimmen"
  },
  "wf.toCoordinateShort": {
    "pt-BR": "A combinar",
    fr: "Ã€ convenir",
    es: "A coordinar",
    en: "To arrange",
    it: "Da concordare",
    de: "Abzustimmen"
  },
    "wf.checkAccount": {
    "pt-BR": "Confira sua conta para mais detalhes.",
    fr: "Consulte ton compte pour plus de dÃ©tails.",
    es: "Consulte tu cuenta para mÃ¡s detalles.",
    en: "Check your account for more details.",
    it: "Controlla il tuo account per maggiori dettagli.",
    de: "Sieh in deinem Konto fÃ¼r weitere Details nach."
  },

  // ===== Workflow v3 â€” lecteur (wf.reader.*) ================================
  "wf.reader.libraryProposed.subject": {
    "pt-BR": "HorÃ¡rio de retirada proposto pela biblioteca",
    fr: "CrÃ©neau de retrait proposÃ© par la biblio",
    es: "Horario de retiro propuesto por la biblioteca",
    en: "Pickup slot proposed by the library",
    it: "Orario di ritiro proposto dalla biblioteca",
    de: "Abholtermin von der Bibliothek vorgeschlagen"
  },
  "wf.reader.libraryProposed.body": {
    "pt-BR": "A biblioteca propÃµe um horÃ¡rio para vocÃª vir retirar seu livro. VocÃª pode aceitar este horÃ¡rio, propor outro, ou cancelar a reserva pela sua conta.",
    fr: "La biblio te propose un crÃ©neau pour venir retirer ton livre. Tu peux accepter ce crÃ©neau, en proposer un autre, ou annuler ta rÃ©servation depuis ton compte.",
    es: "La biblioteca te propone un horario para venir a retirar tu libro. PodÃ©s aceptar este horario, proponer otro, o cancelar tu reserva desde tu cuenta.",
    en: "The library is proposing a time slot for you to come pick up your book. You can accept this slot, propose another one, or cancel your reservation from your account.",
    it: "La biblioteca ti propone un orario per venire a ritirare il tuo libro. Puoi accettare questo orario, proporne un altro, o annullare la tua prenotazione dal tuo account.",
    de: "Die Bibliothek schlÃ¤gt dir einen Termin vor, um dein Buch abzuholen. Du kannst diesen Termin annehmen, einen anderen vorschlagen oder deine Vormerkung Ã¼ber dein Konto stornieren."
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
    "pt-BR": "Sua contra-proposta foi enviada Ã  biblioteca (tentativa {iter}/{max}). VocÃª serÃ¡ avisado(a/e) assim que ela responder.",
    fr: "Ta contre-proposition est bien transmise Ã  la biblio (essai {iter}/{max}). Tu seras prÃ©venuÂ·e dÃ¨s que celle-ci rÃ©pond.",
    es: "Tu contrapropuesta fue enviada a la biblioteca (intento {iter}/{max}). SerÃ¡s avisade en cuanto te respondan.",
    en: "Your counter-proposal has been sent to the library (attempt {iter}/{max}). You will be notified as soon as they reply.",
    it: "La tua controproposta Ã¨ stata inviata alla biblioteca (tentativo {iter}/{max}). Sarai avvisatÉ™ non appena rispondano.",
    de: "Dein Gegenvorschlag wurde an die Bibliothek gesendet (Versuch {iter}/{max}). Du wirst benachrichtigt, sobald geantwortet wird."
  },
  "wf.reader.slotLocked.subject": {
    "pt-BR": "HorÃ¡rio de retirada confirmado",
    fr: "CrÃ©neau de retrait confirmÃ©",
    es: "Horario de retiro confirmado",
    en: "Pickup slot confirmed",
    it: "Orario di ritiro confermato",
    de: "Abholtermin bestÃ¤tigt"
  },
  "wf.reader.slotLocked.body": {
    "pt-BR": "O horÃ¡rio estÃ¡ confirmado e bloqueado. O livro estarÃ¡ em breve pronto para retirada â€” vocÃª receberÃ¡ uma notificaÃ§Ã£o assim que isso acontecer.",
    fr: "Le crÃ©neau est confirmÃ© et verrouillÃ©. Le livre sera bientÃ´t prÃªt Ã  retirer â€” tu recevras une notification dÃ¨s que ce sera le cas.",
    es: "El horario estÃ¡ confirmado y bloqueado. El libro estarÃ¡ pronto listo para retirar â€” recibirÃ¡s una notificaciÃ³n apenas eso suceda.",
    en: "The slot is confirmed and locked. The book will soon be ready for pickup â€” you will receive a notification as soon as that happens.",
    it: "L'orario Ã¨ confermato e bloccato. Il libro sarÃ  presto pronto per il ritiro â€” riceverai una notifica appena ciÃ² accada.",
    de: "Der Termin ist bestÃ¤tigt und festgelegt. Das Buch wird bald zur Abholung bereit sein â€” du erhÃ¤ltst eine Benachrichtigung, sobald dies der Fall ist."
  },
  "wf.reader.maxIterations.subject": {
    "pt-BR": "NegociaÃ§Ã£o sem acordo â€” contato direto recomendado",
    fr: "NÃ©gociation sans accord â€” contact direct conseillÃ©",
    es: "NegociaciÃ³n sin acuerdo â€” contacto directo recomendado",
    en: "Negotiation without agreement â€” direct contact advised",
    it: "Negoziazione senza accordo â€” contatto diretto consigliato",
    de: "Verhandlung ohne Einigung â€” direkter Kontakt empfohlen"
  },
  "wf.reader.maxIterations.body": {
    "pt-BR": "VÃ¡rias trocas sem encontrar um horÃ¡rio que funcione para todo mundo. Para continuar, o melhor Ã© entrar em contato diretamente com a biblioteca para conversar.",
    fr: "Plusieurs allers-retours sans qu'on trouve un crÃ©neau qui convient Ã  tout le monde. Pour continuer, le mieux est de contacter directement la biblio pour en discuter.",
    es: "Varios intercambios sin encontrar un horario que convenga a todes. Para continuar, lo mejor es contactar directamente a la biblioteca para conversar.",
    en: "Several exchanges without finding a time slot that works for everyone. To continue, the best is to contact the library directly to discuss.",
    it: "Diversi scambi senza trovare un orario che vada bene a tuttÉ™. Per continuare, la cosa migliore Ã¨ contattare direttamente la biblioteca per parlarne.",
    de: "Mehrere Versuche, ohne einen fÃ¼r alle passenden Termin zu finden. Um weiterzukommen, ist es am besten, sich direkt an die Bibliothek zu wenden, um darÃ¼ber zu sprechen."
  },
  "wf.reader.negotiationTimeout.subject": {
    "pt-BR": "Reserva liberada â€” prazo de negociaÃ§Ã£o expirado",
    fr: "RÃ©servation libÃ©rÃ©e â€” dÃ©lai de nÃ©gociation dÃ©passÃ©",
    es: "Reserva liberada â€” plazo de negociaciÃ³n vencido",
    en: "Reservation released â€” negotiation deadline exceeded",
    it: "Prenotazione liberata â€” termine di negoziazione scaduto",
    de: "Vormerkung freigegeben â€” Verhandlungsfrist abgelaufen"
  },
  "wf.reader.negotiationTimeout.body": {
    "pt-BR": "A negociaÃ§Ã£o do seu horÃ¡rio ultrapassou o prazo sem acordo. A reserva foi liberada e o livro voltou Ã  circulaÃ§Ã£o. VocÃª pode reservÃ¡-lo novamente quando quiser.",
    fr: "La nÃ©gociation pour ton crÃ©neau a dÃ©passÃ© le dÃ©lai sans accord. La rÃ©servation a Ã©tÃ© libÃ©rÃ©e, le livre repart en circulation. Tu peux le rÃ©server Ã  nouveau quand tu veux.",
    es: "La negociaciÃ³n de tu horario superÃ³ el plazo sin acuerdo. La reserva fue liberada, el libro vuelve a la circulaciÃ³n. PodÃ©s reservarlo nuevamente cuando quieras.",
    en: "The negotiation for your slot has exceeded the deadline without agreement. The reservation has been released, the book returns to circulation. You can reserve it again whenever you want.",
    it: "La negoziazione del tuo orario ha superato il termine senza accordo. La prenotazione Ã¨ stata liberata, il libro torna in circolazione. Puoi prenotarlo di nuovo quando vuoi.",
    de: "Die Verhandlung Ã¼ber deinen Termin hat die Frist ohne Einigung Ã¼berschritten. Die Vormerkung wurde freigegeben, das Buch geht zurÃ¼ck in den Umlauf. Du kannst es jederzeit erneut vormerken."
  },

  // ===== Workflow v3 â€” biblio (wf.staff.*) ==================================
  "wf.staff.negotiationOpened.subject": {
    "pt-BR": "NegociaÃ§Ã£o de horÃ¡rio aberta com o(a/e) leitor(a/e)",
    fr: "NÃ©gociation de crÃ©neau ouverte avec leÂ·la lecteurÂ·rice",
    es: "NegociaciÃ³n de horario abierta con le lectore",
    en: "Slot negotiation opened with the reader",
    it: "Negoziazione di orario aperta con lÉ™ lettorÉ™",
    de: "Terminverhandlung mit der*dem Leser*in erÃ¶ffnet"
  },
  "wf.staff.negotiationOpened.body": {
    "pt-BR": "A negociaÃ§Ã£o de um horÃ¡rio de retirada foi aberta com o(a/e) leitor(a/e). O(a/e) leitor(a/e) foi avisado(a/e) por e-mail e pode aceitar, contra-propor ou cancelar pela prÃ³pria conta.",
    fr: "La nÃ©gociation d'un crÃ©neau de retrait a Ã©tÃ© ouverte avec leÂ·la lecteurÂ·rice. LeÂ·la lecteurÂ·rice a Ã©tÃ© prÃ©venuÂ·e par mail et peut accepter, contre-proposer ou annuler depuis son compte.",
    es: "Se abriÃ³ la negociaciÃ³n de un horario de retiro con le lectore. Le lectore fue avisade por correo y puede aceptar, contraproponer o cancelar desde su cuenta.",
    en: "A negotiation has been opened with the reader for a pickup slot. The reader has been notified by email and can accept, counter-propose, or cancel from their account.",
    it: "Ãˆ stata aperta la negoziazione di un orario di ritiro con lÉ™ lettorÉ™. LÉ™ lettorÉ™ Ã¨ statÉ™ avvisatÉ™ via email e puÃ² accettare, controproporre o annullare dal proprio account.",
    de: "Eine Verhandlung Ã¼ber einen Abholtermin wurde mit der*dem Leser*in erÃ¶ffnet. Die*Der Leser*in wurde per E-Mail benachrichtigt und kann annehmen, gegenvorschlagen oder Ã¼ber das eigene Konto stornieren."
  },
  "wf.staff.readerCounterProposed.subject": {
    "pt-BR": "Contra-proposta do(a/e) leitor(a/e) â€” aÃ§Ã£o esperada",
    fr: "Contre-proposition duÂ·de la lecteurÂ·rice â€” action attendue",
    es: "Contrapropuesta de le lectore â€” acciÃ³n esperada",
    en: "Counter-proposal from the reader â€” action expected",
    it: "Controproposta di lÉ™ lettorÉ™ â€” azione attesa",
    de: "Gegenvorschlag der*des Leser*in â€” Aktion erwartet"
  },
  "wf.staff.readerCounterProposed.body": {
    "pt-BR": "O(a/e) leitor(a/e) contra-propÃ´s outro horÃ¡rio para a retirada. <b>Resposta esperada</b> : abrir o painel para aceitar, contra-propor por sua vez, ou cancelar.",
    fr: "LeÂ·la lecteurÂ·rice a contre-proposÃ© un autre crÃ©neau pour le retrait. <b>RÃ©ponse attendue</b> : ouvrir le tableau de bord pour accepter, contre-proposer Ã  votre tour, ou annuler.",
    es: "Le lectore contrapropuso otro horario para el retiro. <b>Respuesta esperada</b> : abrir el panel para aceptar, contraproponer a su vez, o cancelar.",
    en: "The reader has counter-proposed another slot for the pickup. <b>Response expected</b> : open the dashboard to accept, counter-propose in turn, or cancel.",
    it: "LÉ™ lettorÉ™ ha controproposto un altro orario per il ritiro. <b>Risposta attesa</b> : aprire il pannello per accettare, controproporre a vostra volta, o annullare.",
    de: "Die*Der Leser*in hat einen anderen Termin fÃ¼r die Abholung vorgeschlagen. <b>Antwort erwartet</b> : Ã–ffnet das Dashboard, um anzunehmen, einen Gegenvorschlag zu machen oder zu stornieren."
  },
  "wf.staff.readerAccepted.subject": {
    "pt-BR": "HorÃ¡rio aceito pelo(a/e) leitor(a/e)",
    fr: "CrÃ©neau acceptÃ© par leÂ·la lecteurÂ·rice",
    es: "Horario aceptado por le lectore",
    en: "Slot accepted by the reader",
    it: "Orario accettato da lÉ™ lettorÉ™",
    de: "Termin von der*dem Leser*in angenommen"
  },
  "wf.staff.readerAccepted.body": {
    "pt-BR": "O(a/e) leitor(a/e) aceitou o horÃ¡rio proposto. O horÃ¡rio estÃ¡ bloqueado â€” o livro pode ser preparado para a retirada.",
    fr: "LeÂ·la lecteurÂ·rice a acceptÃ© le crÃ©neau proposÃ©. Le crÃ©neau est verrouillÃ© â€” le livre peut Ãªtre prÃ©parÃ© pour le retrait.",
    es: "Le lectore aceptÃ³ el horario propuesto. El horario estÃ¡ bloqueado â€” el libro puede ser preparado para el retiro.",
    en: "The reader has accepted the proposed slot. The slot is locked â€” the book can be prepared for pickup.",
    it: "LÉ™ lettorÉ™ ha accettato l'orario proposto. L'orario Ã¨ bloccato â€” il libro puÃ² essere preparato per il ritiro.",
    de: "Die*Der Leser*in hat den vorgeschlagenen Termin angenommen. Der Termin ist festgelegt â€” das Buch kann fÃ¼r die Abholung vorbereitet werden."
  },
  "wf.staff.staffConfirmed.subject": {
    "pt-BR": "HorÃ¡rio do(a/e) leitor(a/e) confirmado",
    fr: "CrÃ©neau duÂ·de la lecteurÂ·rice confirmÃ©",
    es: "Horario de le lectore confirmado",
    en: "Reader's slot confirmed",
    it: "Orario di lÉ™ lettorÉ™ confermato",
    de: "Termin der*des Leser*in bestÃ¤tigt"
  },
  "wf.staff.staffConfirmed.body": {
    "pt-BR": "VocÃª confirmou o horÃ¡rio proposto pelo(a/e) leitor(a/e). O horÃ¡rio estÃ¡ bloqueado â€” o livro pode ser preparado para a retirada.",
    fr: "Tu as confirmÃ© le crÃ©neau proposÃ© par leÂ·la lecteurÂ·rice. Le crÃ©neau est verrouillÃ© â€” le livre peut Ãªtre prÃ©parÃ© pour le retrait.",
    es: "Confirmaste el horario propuesto por le lectore. El horario estÃ¡ bloqueado â€” el libro puede ser preparado para el retiro.",
    en: "You have confirmed the slot proposed by the reader. The slot is locked â€” the book can be prepared for pickup.",
    it: "Avete confermato l'orario proposto da lÉ™ lettorÉ™. L'orario Ã¨ bloccato â€” il libro puÃ² essere preparato per il ritiro.",
    de: "Ihr habt den von der*dem Leser*in vorgeschlagenen Termin bestÃ¤tigt. Der Termin ist festgelegt â€” das Buch kann fÃ¼r die Abholung vorbereitet werden."
  },
  "wf.staff.ready.subject": {
    "pt-BR": "Livro pronto para retirada â€” leitor(a/e) avisado(a/e)",
    fr: "Livre prÃªt â€” lecteurÂ·rice prÃ©venuÂ·e",
    es: "Libro listo â€” lectore avisade",
    en: "Book ready â€” reader notified",
    it: "Libro pronto â€” lettorÉ™ avvisatÉ™",
    de: "Buch bereit â€” Leser*in benachrichtigt"
  },
  "wf.staff.ready.body": {
    "pt-BR": "VocÃª sinalizou que o livro estÃ¡ pronto para a retirada. O(a/e) leitor(a/e) foi avisado(a/e).",
    fr: "Tu as signalÃ© que le livre est prÃªt Ã  Ãªtre retirÃ©. LeÂ·la lecteurÂ·rice a Ã©tÃ© prÃ©venuÂ·e.",
    es: "Indicaste que el libro estÃ¡ listo para ser retirado. Le lectore fue avisade.",
    en: "You have signaled that the book is ready for pickup. The reader has been notified.",
    it: "Avete segnalato che il libro Ã¨ pronto per il ritiro. LÉ™ lettorÉ™ Ã¨ statÉ™ avvisatÉ™.",
    de: "Ihr habt gemeldet, dass das Buch zur Abholung bereit ist. Die*Der Leser*in wurde benachrichtigt."
  },
  "wf.staff.noShow.subject": {
    "pt-BR": "Retirada nÃ£o realizada",
    fr: "Retrait non effectuÃ©",
    es: "Retiro no realizado",
    en: "Pickup missed",
    it: "Ritiro non effettuato",
    de: "Abholung nicht erfolgt"
  },
  "wf.staff.noShow.body": {
    "pt-BR": "O livro nÃ£o foi retirado no horÃ¡rio previsto. A reserva foi marcada como nÃ£o-retirada â€” o livro voltarÃ¡ em breve Ã  circulaÃ§Ã£o livre.",
    fr: "Le livre n'a pas Ã©tÃ© retirÃ© au crÃ©neau prÃ©vu. La rÃ©servation est marquÃ©e en non-retrait â€” le livre repassera bientÃ´t en circulation libre.",
    es: "El libro no fue retirado en el horario previsto. La reserva fue marcada como no-retiro â€” el libro volverÃ¡ pronto a la circulaciÃ³n libre.",
    en: "The book was not picked up at the scheduled time. The reservation is marked as no-show â€” the book will soon return to free circulation.",
    it: "Il libro non Ã¨ stato ritirato nell'orario previsto. La prenotazione Ã¨ stata segnata come non-ritiro â€” il libro tornerÃ  presto in circolazione libera.",
    de: "Das Buch wurde zum vereinbarten Termin nicht abgeholt. Die Vormerkung ist als Nicht-Abholung markiert â€” das Buch geht bald zurÃ¼ck in den freien Umlauf."
  },
  "wf.staff.closed.subject": {
    "pt-BR": "Reserva encerrada",
    fr: "RÃ©servation close",
    es: "Reserva cerrada",
    en: "Reservation closed",
    it: "Prenotazione chiusa",
    de: "Vormerkung abgeschlossen"
  },
  "wf.staff.closed.body": {
    "pt-BR": "A reserva estÃ¡ encerrada, o livro voltou Ã  circulaÃ§Ã£o livre. Nenhuma aÃ§Ã£o adicional Ã© esperada de sua parte.",
    fr: "La rÃ©servation est close, le livre repasse en circulation libre. Aucune action supplÃ©mentaire n'est attendue de votre part.",
    es: "La reserva estÃ¡ cerrada, el libro vuelve a la circulaciÃ³n libre. No se espera ninguna acciÃ³n adicional de su parte.",
    en: "The reservation is closed, the book returns to free circulation. No additional action is expected from you.",
    it: "La prenotazione Ã¨ chiusa, il libro torna in circolazione libera. Nessuna azione aggiuntiva Ã¨ attesa da parte vostra.",
    de: "Die Vormerkung ist abgeschlossen, das Buch geht zurÃ¼ck in den freien Umlauf. Keine zusÃ¤tzliche Aktion eurerseits ist erforderlich."
  },
  "wf.staff.maxIterations.subject": {
    "pt-BR": "NegociaÃ§Ã£o sem acordo â€” leitor(a/e) convidado(a/e) ao contato direto",
    fr: "NÃ©gociation sans accord â€” lecteurÂ·rice invitÃ©Â·e au contact direct",
    es: "NegociaciÃ³n sin acuerdo â€” lectore invitade al contacto directo",
    en: "Negotiation without agreement â€” reader invited to direct contact",
    it: "Negoziazione senza accordo â€” lettorÉ™ invitatÉ™ al contatto diretto",
    de: "Verhandlung ohne Einigung â€” Leser*in zum direkten Kontakt eingeladen"
  },
  "wf.staff.maxIterations.body": {
    "pt-BR": "VÃ¡rias trocas sem acordo com o(a/e) leitor(a/e). O(a/e) leitor(a/e) foi convidado(a/e) a entrar em contato diretamente para encontrar uma soluÃ§Ã£o.",
    fr: "Plusieurs allers-retours sans accord avec leÂ·la lecteurÂ·rice. LeÂ·la lecteurÂ·rice a Ã©tÃ© invitÃ©Â·e Ã  vous contacter directement pour trouver une solution.",
    es: "Varios intercambios sin acuerdo con le lectore. Le lectore fue invitade a contactarles directamente para encontrar una soluciÃ³n.",
    en: "Several exchanges without agreement with the reader. The reader has been invited to contact you directly to find a solution.",
    it: "Diversi scambi senza accordo con lÉ™ lettorÉ™. LÉ™ lettorÉ™ Ã¨ statÉ™ invitatÉ™ a contattarvi direttamente per trovare una soluzione.",
    de: "Mehrere Versuche ohne Einigung mit der*dem Leser*in. Die*Der Leser*in wurde gebeten, sich direkt an euch zu wenden, um eine LÃ¶sung zu finden."
  },

  // ===== Workflow v3 â€” re-proposition staff aprÃ¨s contre-prop lecteur =======
  // Couvre le cas spÃ©cifique oÃ¹ la coordo, aprÃ¨s avoir reÃ§u une contre-prop
  // du lecteur (negotiation_iteration_count > 0, pickup_proposed_by='leitor'),
  // dÃ©cide de NE PAS accepter et de re-proposer un autre crÃ©neau. DÃ©cision
  // technique paquet 6 commit comportement (option Î²) : on distingue cette
  // re-proposition de la premiÃ¨re ouverture de nÃ©go (wf.staff.negotiationOpened),
  // pour que la coordo voie clairement dans son trace mail "j'ai re-proposÃ©"
  // vs "j'ai ouvert la nÃ©go".
  "wf.reader.libraryCounterProposed.subject": {
    "pt-BR": "Nova proposta da biblioteca",
    fr: "Nouvelle proposition de la biblio",
    es: "Nueva propuesta de la biblioteca",
    en: "New proposal from the library",
    it: "Nuova proposta della biblioteca",
    de: "Neuer Vorschlag der Bibliothek"
  },
  "wf.reader.libraryCounterProposed.body": {
    "pt-BR": "A biblioteca respondeu Ã  sua contra-proposta com um novo horÃ¡rio. VocÃª pode aceitar este horÃ¡rio, propor outro, ou cancelar a reserva pela sua conta.",
    fr: "La biblio a rÃ©pondu Ã  ta contre-proposition avec un nouveau crÃ©neau. Tu peux accepter ce crÃ©neau, en proposer un autre, ou annuler ta rÃ©servation depuis ton compte.",
    es: "La biblioteca respondiÃ³ a tu contrapropuesta con un nuevo horario. PodÃ©s aceptar este horario, proponer otro, o cancelar tu reserva desde tu cuenta.",
    en: "The library has responded to your counter-proposal with a new time slot. You can accept this slot, propose another one, or cancel your reservation from your account.",
    it: "La biblioteca ha risposto alla tua controproposta con un nuovo orario. Puoi accettare questo orario, proporne un altro, o annullare la tua prenotazione dal tuo account.",
    de: "Die Bibliothek hat auf deinen Gegenvorschlag mit einem neuen Termin geantwortet. Du kannst diesen Termin annehmen, einen anderen vorschlagen oder deine Vormerkung Ã¼ber dein Konto stornieren."
  },
  "wf.staff.staffCounterProposed.subject": {
    "pt-BR": "Contra-proposta enviada ao(a/e) leitor(a/e)",
    fr: "Contre-proposition envoyÃ©e auÂ·Ã  la lecteurÂ·rice",
    es: "Contrapropuesta enviada a le lectore",
    en: "Counter-proposal sent to the reader",
    it: "Controproposta inviata a lÉ™ lettorÉ™",
    de: "Gegenvorschlag an die*den Leser*in gesendet"
  },
  "wf.staff.staffCounterProposed.body": {
    "pt-BR": "VocÃª enviou uma nova contra-proposta de horÃ¡rio ao(a/e) leitor(a/e) em resposta Ã  proposta recebida. Aguarde a resposta.",
    fr: "Tu as envoyÃ© une nouvelle contre-proposition de crÃ©neau auÂ·Ã  la lecteurÂ·rice en rÃ©ponse Ã  sa proposition. En attente de sa rÃ©ponse.",
    es: "Enviaste una nueva contrapropuesta de horario a le lectore en respuesta a su propuesta. Esperando su respuesta.",
    en: "You have sent a new counter-proposal to the reader in response to their proposal. Awaiting their reply.",
    it: "Avete inviato una nuova controproposta di orario a lÉ™ lettorÉ™ in risposta alla sua proposta. In attesa della sua risposta.",
    de: "Ihr habt einen neuen Gegenvorschlag an die*den Leser*in als Antwort auf deren Vorschlag gesendet. Wartet auf Antwort."
  },

  // ===== Workflow v3 â€” cron timeout (wf.staff.negotiationTimedOut) ==========
  "wf.staff.negotiationTimedOut.subject": {
    "pt-BR": "NegociaÃ§Ã£o expirada â€” reserva liberada",
    fr: "NÃ©gociation expirÃ©e â€” rÃ©servation libÃ©rÃ©e",
    es: "NegociaciÃ³n vencida â€” reserva liberada",
    en: "Negotiation expired â€” reservation released",
    it: "Negoziazione scaduta â€” prenotazione liberata",
    de: "Verhandlung abgelaufen â€” Vormerkung freigegeben"
  },
  "wf.staff.negotiationTimedOut.body": {
    "pt-BR": "A negociaÃ§Ã£o para a retirada expirou sem acordo ({days} dias sem resposta). A reserva foi liberada automaticamente e o livro voltou Ã  circulaÃ§Ã£o livre.",
    fr: "La nÃ©gociation pour le retrait a expirÃ© sans accord ({days} jours sans rÃ©ponse). La rÃ©servation a Ã©tÃ© libÃ©rÃ©e automatiquement, le livre repasse en circulation libre.",
    es: "La negociaciÃ³n para el retiro expirÃ³ sin acuerdo ({days} dÃ­as sin respuesta). La reserva fue liberada automÃ¡ticamente, el libro vuelve a la circulaciÃ³n libre.",
    en: "The negotiation for the pickup has expired without agreement ({days} days without reply). The reservation has been released automatically, the book returns to free circulation.",
    it: "La negoziazione per il ritiro Ã¨ scaduta senza accordo ({days} giorni senza risposta). La prenotazione Ã¨ stata liberata automaticamente, il libro torna in circolazione libera.",
    de: "Die Verhandlung Ã¼ber die Abholung ist ohne Einigung abgelaufen ({days} Tage ohne Antwort). Die Vormerkung wurde automatisch freigegeben, das Buch geht zurÃ¼ck in den freien Umlauf."
  },

  // ===== Action/info boxes (wf.staff.*Box.*) ================================
  // EncadrÃ©s visuels insÃ©rÃ©s dans le HTML du mail biblio :
  //   - actionBox : encadrÃ© orange/rouge quand action attendue
  //   - infoBox : encadrÃ© gris quand juste informatif
  "wf.staff.actionBox.title": {
    "pt-BR": "AÃ§Ã£o esperada",
    fr: "Action attendue",
    es: "AcciÃ³n esperada",
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
    de: "Dashboard Ã¶ffnen"
  },
  "wf.staff.infoBox.title": {
    "pt-BR": "Para sua informaÃ§Ã£o",
    fr: "Pour information",
    es: "Para su informaciÃ³n",
    en: "For your information",
    it: "Per vostra informazione",
    de: "Zu Ihrer Information"
  },

  // ===== Subject prefixes (subj.*) ==========================================
  // PrÃ©fixes textuels pour le sujet du mail biblio, permettant aux coordo
  // de filtrer leur boÃ®te (ex: dossier auto pour les actions requises).
  "subj.staff.action": {
    "pt-BR": "[AÃ§Ã£o requerida]",
    fr: "[Action requise]",
    es: "[AcciÃ³n requerida]",
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
  // Remplace l'ancien symbole Â© (idÃ©ologiquement incompatible avec un projet
  // anarchiste). La chaÃ®ne s'affiche dans la derniÃ¨re ligne de chaque mail :
  //   "{subjectTag} â€” {libre diffusion} â€” {footerText}"
  // LocalisÃ©e dans la langue du destinataire (cohÃ©rence avec le reste du
  // paquet 6 : chaque destinataire reÃ§oit dans sa propre langue).
  "subj.libreDiffusion": {
    "pt-BR": "livre difusÃ£o",
    fr: "libre diffusion",
    es: "libre difusiÃ³n",
    en: "free distribution",
    it: "libera diffusione",
    de: "freie Verbreitung"
  },


  // ===== Loan events (loan.*) ===============================================
  "loan.created.sub": {
    "pt-BR": "EmprÃ©stimo registrado",
    fr: "Emprunt enregistrÃ©",
    es: "PrÃ©stamo registrado",
    en: "Loan registered",
    it: "Prestito registrato",
    de: "Ausleihe registriert"
  },
  "loan.created.intro": {
    "pt-BR": "Seu emprÃ©stimo foi registrado.",
    fr: "Ton emprunt a bien Ã©tÃ© enregistrÃ©.",
    es: "Tu prÃ©stamo fue registrado.",
    en: "Your loan has been registered.",
    it: "Il tuo prestito Ã¨ stato registrato.",
    de: "Deine Ausleihe wurde registriert."
  },
  "loan.dueIn": {
    "pt-BR": "DevoluÃ§Ã£o prevista para {date}.",
    fr: "Retour prÃ©vu pour le {date}.",
    es: "DevoluciÃ³n prevista para el {date}.",
    en: "Due date: {date}.",
    it: "Restituzione prevista per il {date}.",
    de: "RÃ¼ckgabe vorgesehen fÃ¼r den {date}."
  },
  "loan.renewed.sub": {
    "pt-BR": "RenovaÃ§Ã£o confirmada",
    fr: "Renouvellement confirmÃ©",
    es: "RenovaciÃ³n confirmada",
    en: "Renewal confirmed",
    it: "Rinnovo confermato",
    de: "VerlÃ¤ngerung bestÃ¤tigt"
  },
  "loan.renewed.intro": {
    "pt-BR": "Sua prorrogaÃ§Ã£o foi confirmada.",
    fr: "Ta prolongation a bien Ã©tÃ© confirmÃ©e.",
    es: "Tu renovaciÃ³n fue confirmada.",
    en: "Your renewal has been confirmed.",
    it: "Il tuo rinnovo Ã¨ stato confermato.",
    de: "Deine VerlÃ¤ngerung wurde bestÃ¤tigt."
  },
  "loan.newDue": {
    "pt-BR": "Nova data de devoluÃ§Ã£o: {date}.",
    fr: "Nouvelle date de retour : {date}.",
    es: "Nueva fecha de devoluciÃ³n: {date}.",
    en: "New due date: {date}.",
    it: "Nuova data di restituzione: {date}.",
    de: "Neues RÃ¼ckgabedatum: {date}."
  },
  "loan.renewed.once": {
    "pt-BR": "Lembre-se: cada emprÃ©stimo pode ser prorrogado apenas uma vez.",
    fr: "Pour rappel : chaque emprunt ne peut Ãªtre prolongÃ© qu'une seule fois.",
    es: "Recuerda: cada prÃ©stamo puede renovarse solo une vez.",
    en: "Reminder: each loan can be renewed only once.",
    it: "Ricorda: ogni prestito puÃ² essere rinnovato solo una volta.",
    de: "Zur Erinnerung: jede Ausleihe kann nur einmal verlÃ¤ngert werden."
  },
  "loan.returned.sub": {
    "pt-BR": "DevoluÃ§Ã£o registrada",
    fr: "Retour enregistrÃ©",
    es: "DevoluciÃ³n registrada",
    en: "Return registered",
    it: "Restituzione registrata",
    de: "RÃ¼ckgabe registriert"
  },
  "loan.returned.intro": {
    "pt-BR": "Registramos a devoluÃ§Ã£o. Obrigad(o/a/e)!",
    fr: "Nous avons enregistrÃ© le retour. Merci !",
    es: "Registramos la devoluciÃ³n. Â¡Gracias!",
    en: "We've recorded the return. Thank you!",
    it: "Abbiamo registrato la restituzione. Grazie!",
    de: "Wir haben die RÃ¼ckgabe registriert. Danke!"
  },
  "loan.returned.browse": {
    "pt-BR": "Continue navegando no acervo para suas prÃ³ximas leituras.",
    fr: "Continue Ã  explorer le fonds pour tes prochaines lectures.",
    es: "Sigue navegando el acervo para tus prÃ³ximas lecturas.",
    en: "Keep browsing the collection for your next reads.",
    it: "Continua a esplorare il fondo per le tue prossime letture.",
    de: "StÃ¶bere weiter im Bestand fÃ¼r deine nÃ¤chste LektÃ¼re."
  },
  "loan.returnScheduled": {
    "pt-BR": "DevoluÃ§Ã£o agendada",
    fr: "Retour programmÃ©",
    es: "DevoluciÃ³n programada",
    en: "Return scheduled",
    it: "Restituzione programmata",
    de: "RÃ¼ckgabe geplant"
  },
  "loan.returnCancelled": {
    "pt-BR": "DevoluÃ§Ã£o cancelada",
    fr: "Retour annulÃ©",
    es: "DevoluciÃ³n cancelada",
    en: "Return cancelled",
    it: "Restituzione annullata",
    de: "RÃ¼ckgabe storniert"
  },
  "loan.returnMissed": {
    "pt-BR": "DevoluÃ§Ã£o nÃ£o realizada",
    fr: "Retour non effectuÃ©",
    es: "DevoluciÃ³n no realizada",
    en: "Return missed",
    it: "Restituzione non effettuata",
    de: "RÃ¼ckgabe nicht erfolgt"
  },
  "loan.partialReturn.sub": {
    "pt-BR": "DevoluÃ§Ã£o parcial registrada",
    fr: "Retour partiel enregistrÃ©",
    es: "DevoluciÃ³n parcial registrada",
    en: "Partial return recorded",
    it: "Restituzione parziale registrata",
    de: "TeilrÃ¼ckgabe registriert"
  },
  "loan.partialReturn.intro": {
    "pt-BR": "Registramos a devoluÃ§Ã£o parcial do seu emprÃ©stimo. Obrigad(o/a/e) por trazer alguns documentos!",
    fr: "Nous avons enregistrÃ© le retour partiel de ton emprunt. Merci d'avoir rapportÃ© une partie des documents !",
    es: "Registramos la devoluciÃ³n parcial de tu prÃ©stamo. Â¡Gracias por traer une parte de los documentos!",
    en: "We've recorded the partial return of your loan. Thank you for bringing back some of the documents!",
    it: "Abbiamo registrato la restituzione parziale del tuo prestito. Grazie per aver riportato alcuni documenti!",
    de: "Wir haben die TeilrÃ¼ckgabe deiner Ausleihe registriert. Danke, dass du einige Dokumente zurÃ¼ckgebracht hast!"
  },
  "loan.partialReturn.dueReminder": {
    "pt-BR": "Lembrete: a data de devoluÃ§Ã£o dos documentos restantes Ã© {date}.",
    fr: "Rappel : la date de retour des documents restants est le {date}.",
    es: "Recordatorio: la fecha de devoluciÃ³n de los documentos restantes es el {date}.",
    en: "Reminder: the due date for the remaining documents is {date}.",
    it: "Promemoria: la data di restituzione dei documenti rimanenti Ã¨ il {date}.",
    de: "Erinnerung: das RÃ¼ckgabedatum fÃ¼r die verbleibenden Dokumente ist der {date}."
  },
  "loan.partialReturn.outro": {
    "pt-BR": "NÃ£o esqueÃ§a de passar pela biblioteca para devolver os documentos restantes.",
    fr: "N'oublie pas de passer Ã  la bibliothÃ¨que pour rendre les documents restants.",
    es: "No olvides pasar por la biblioteca para devolver los documentos restantes.",
    en: "Don't forget to drop by the library to return the remaining documents.",
    it: "Non dimenticare di passare in biblioteca per restituire i documenti rimanenti.",
    de: "Vergiss nicht, in der Bibliothek vorbeizuschauen, um die verbleibenden Dokumente zurÃ¼ckzugeben."
  },
  "loan.fullyReturnedAfterPartial.sub": {
    "pt-BR": "EmprÃ©stimo concluÃ­do",
    fr: "Emprunt clÃ´turÃ©",
    es: "PrÃ©stamo concluido",
    en: "Loan completed",
    it: "Prestito concluso",
    de: "Ausleihe abgeschlossen"
  },
  "loan.fullyReturnedAfterPartial.intro": {
    "pt-BR": "VocÃª devolveu o Ãºltimo documento do seu emprÃ©stimo. Tudo voltou! Obrigad(o/a/e) por cuidar bem dos livros da biblioteca.",
    fr: "Tu viens de rendre le dernier document de ton emprunt. Tout est revenu ! Merci d'avoir pris soin des documents de la bibliothÃ¨que.",
    es: "Devolviste el Ãºltimo documento de tu prÃ©stamo. Â¡Todo volviÃ³! Gracias por cuidar de los documentos de la biblioteca.",
    en: "You've returned the last document of your loan. Everything is back! Thank you for taking good care of the library's documents.",
    it: "Hai restituito l'ultimo documento del tuo prestito. Ãˆ tutto rientrato! Grazie per esserti preso/a/* cura dei documenti della biblioteca.",
    de: "Du hast das letzte Dokument deiner Ausleihe zurÃ¼ckgebracht. Alles ist wieder da! Danke, dass du gut auf die Dokumente der Bibliothek aufgepasst hast."
  },
  "loan.fullyReturnedAfterPartial.browse": {
    "pt-BR": "Continue navegando no acervo para suas prÃ³ximas leituras.",
    fr: "Continue Ã  explorer le fonds pour tes prochaines lectures.",
    es: "Sigue navegando el acervo para tus prÃ³ximas lecturas.",
    en: "Keep browsing the collection for your next reads.",
    it: "Continua a esplorare il fondo per le tue prossime letture.",
    de: "StÃ¶bere weiter im Bestand fÃ¼r deine nÃ¤chste LektÃ¼re."
  },

  // ===== Reminders (rem.*) ==================================================
  "rem.title": {
    "pt-BR": "Lembrete de devoluÃ§Ã£o",
    fr: "Rappel de retour",
    es: "Recordatorio de devoluciÃ³n",
    en: "Return reminder",
    it: "Promemoria di restituzione",
    de: "RÃ¼ckgabeerinnerung"
  },
  "rem.5d": {
    "pt-BR": "DevoluÃ§Ã£o em 5 dias",
    fr: "Retour dans 5 jours",
    es: "DevoluciÃ³n en 5 dÃ­as",
    en: "Due in 5 days",
    it: "Restituzione tra 5 giorni",
    de: "RÃ¼ckgabe in 5 Tagen"
  },
  "rem.5d.body": {
    "pt-BR": "Seu emprÃ©stimo vence em 5 dias",
    fr: "Ton emprunt arrive Ã  Ã©chÃ©ance dans 5 jours",
    es: "Tu prÃ©stamo vence en 5 dÃ­as",
    en: "Your loan is due in 5 days",
    it: "Il tuo prestito scade tra 5 giorni",
    de: "Deine Ausleihe lÃ¤uft in 5 Tagen ab"
  },
  "rem.3d": {
    "pt-BR": "DevoluÃ§Ã£o em 3 dias",
    fr: "Retour dans 3 jours",
    es: "DevoluciÃ³n en 3 dÃ­as",
    en: "Due in 3 days",
    it: "Restituzione tra 3 giorni",
    de: "RÃ¼ckgabe in 3 Tagen"
  },
  "rem.3d.body": {
    "pt-BR": "Faltam 3 dias para a devoluÃ§Ã£o do seu emprÃ©stimo.",
    fr: "Plus que 3 jours avant la date de retour de ton emprunt.",
    es: "Quedan 3 dÃ­as para la devoluciÃ³n de tu prÃ©stamo.",
    en: "Only 3 days left until the return date of your loan.",
    it: "Mancano 3 giorni alla data di restituzione del tuo prestito.",
    de: "Nur noch 3 Tage bis zum RÃ¼ckgabedatum deiner Ausleihe."
  },
  "rem.today": {
    "pt-BR": "DevoluÃ§Ã£o hoje",
    fr: "Retour aujourd'hui",
    es: "DevoluciÃ³n hoy",
    en: "Due today",
    it: "Restituzione oggi",
    de: "RÃ¼ckgabe heute"
  },
  "rem.today.body": {
    "pt-BR": "Sua devoluÃ§Ã£o Ã© hoje",
    fr: "Ton retour est prÃ©vu aujourd'hui",
    es: "Tu devoluciÃ³n es hoy",
    en: "Your return is due today",
    it: "La tua restituzione Ã¨ oggi",
    de: "Deine RÃ¼ckgabe ist heute fÃ¤llig"
  },

  // ===== Overdue (ov.*) =====================================================
  "ov.title": {
    "pt-BR": "Aviso de atraso",
    fr: "Avis de retard",
    es: "Aviso de retraso",
    en: "Overdue notice",
    it: "Avviso di ritardo",
    de: "ÃœberfÃ¤lligkeitshinweis"
  },
  "ov.1d": {
    "pt-BR": "EmprÃ©stimo em atraso",
    fr: "Emprunt en retard",
    es: "PrÃ©stamo en retraso",
    en: "Loan overdue",
    it: "Prestito in ritardo",
    de: "Ausleihe Ã¼berfÃ¤llig"
  },
  "ov.1d.body": {
    "pt-BR": "Seu emprÃ©stimo estÃ¡ em atraso desde {date}. Por favor, providencie a devoluÃ§Ã£o.",
    fr: "Ton emprunt est en retard depuis le {date}. Merci de prÃ©voir le retour ou la prolongation.",
    es: "Tu prÃ©stamo estÃ¡ en retraso desde el {date}. Por favor, organiza la devoluciÃ³n o la renovaciÃ³n.",
    en: "Your loan has been overdue since {date}. Please arrange the return or a renewal.",
    it: "Il tuo prestito Ã¨ in ritardo dal {date}. Per favore, organizza la restituzione o il rinnovo.",
    de: "Deine Ausleihe ist seit dem {date} Ã¼berfÃ¤llig. Bitte sorge fÃ¼r die RÃ¼ckgabe oder eine VerlÃ¤ngerung."
  },
  "ov.7d": {
    "pt-BR": "EmprÃ©stimo com {days} dias de atraso",
    fr: "Emprunt en retard de {days} jours",
    es: "PrÃ©stamo con {days} dÃ­as de retraso",
    en: "Loan {days} days overdue",
    it: "Prestito in ritardo di {days} giorni",
    de: "Ausleihe seit {days} Tagen Ã¼berfÃ¤llig"
  },
  "ov.7d.body": {
    "pt-BR": "Seu emprÃ©stimo estÃ¡ com {days} dias de atraso. Entre em contato com a biblioteca.",
    fr: "Ton emprunt est en retard de {days} jours. Contacte la bibliothÃ¨que pour trouver une solution.",
    es: "Tu prÃ©stamo estÃ¡ con {days} dÃ­as de retraso. Contacta la biblioteca para encontrar una soluciÃ³n.",
    en: "Your loan is {days} days overdue. Contact the library to find a solution.",
    it: "Il tuo prestito Ã¨ in ritardo di {days} giorni. Contatta la biblioteca per trovare una soluzione.",
    de: "Deine Ausleihe ist seit {days} Tagen Ã¼berfÃ¤llig. Kontaktiere die Bibliothek, um eine LÃ¶sung zu finden."
  },
  "ov.30d": {
    "pt-BR": "EmprÃ©stimo com {days} dias de atraso â€” situaÃ§Ã£o grave",
    fr: "Emprunt en retard de {days} jours â€” situation Ã  rÃ©gulariser",
    es: "PrÃ©stamo con {days} dÃ­as de retraso â€” situaciÃ³n a regularizar",
    en: "Loan {days} days overdue â€” situation to resolve",
    it: "Prestito in ritardo di {days} giorni â€” situazione da regolarizzare",
    de: "Ausleihe seit {days} Tagen Ã¼berfÃ¤llig â€” Situation zu klÃ¤ren"
  },
  "ov.30d.body": {
    "pt-BR": "Seu emprÃ©stimo estÃ¡ com {days} dias de atraso. Esta situaÃ§Ã£o compromete o funcionamento da biblioteca.",
    fr: "Ton emprunt est en retard de {days} jours. Cette situation pÃ¨se sur le fonctionnement collectif de la bibliothÃ¨que. Prends contact avec la biblio pour qu'on trouve ensemble comment rÃ©gulariser.",
    es: "Tu prÃ©stamo estÃ¡ con {days} dÃ­as de retraso. Esta situaciÃ³n afecta el funcionamiento colectivo de la biblioteca. Toma contacto con la biblio para que encontremos juntes cÃ³mo regularizar.",
    en: "Your loan is {days} days overdue. This situation affects the collective functioning of the library. Get in touch so we can find a way forward together.",
    it: "Il tuo prestito Ã¨ in ritardo di {days} giorni. Questa situazione pesa sul funzionamento collettivo della biblioteca. Mettiti in contatto con la biblio per trovare insieme una soluzione.",
    de: "Deine Ausleihe ist seit {days} Tagen Ã¼berfÃ¤llig. Diese Situation belastet den kollektiven Betrieb der Bibliothek. Nimm Kontakt auf, damit wir gemeinsam eine LÃ¶sung finden."
  },
  "ov.30d.admin": {
    "pt-BR": "EmprÃ©stimo com mais de 30 dias de atraso",
    fr: "Emprunt avec plus de 30 jours de retard",
    es: "PrÃ©stamo con mÃ¡s de 30 dÃ­as de retraso",
    en: "Loan over 30 days overdue",
    it: "Prestito con oltre 30 giorni di ritardo",
    de: "Ausleihe seit Ã¼ber 30 Tagen Ã¼berfÃ¤llig"
  },

  // ===== Profile notices (prof.*) ===========================================
  "prof.restricted": {
    "pt-BR": "Cadastro com restriÃ§Ãµes",
    fr: "Compte avec restrictions",
    es: "Cuenta con restricciones",
    en: "Account with restrictions",
    it: "Account con restrizioni",
    de: "Konto mit EinschrÃ¤nkungen"
  },
  "prof.restricted.intro": {
    "pt-BR": "Seu cadastro foi marcado com restriÃ§Ãµes.",
    fr: "Ton compte a Ã©tÃ© marquÃ© avec des restrictions.",
    es: "Tu cuenta fue marcada con restricciones.",
    en: "Your account has been marked with restrictions.",
    it: "Il tuo account Ã¨ stato segnato con restrizioni.",
    de: "Dein Konto wurde mit EinschrÃ¤nkungen markiert."
  },
  "prof.contactLibrary": {
    "pt-BR": "Entre em contato com a biblioteca para regularizar sua situaÃ§Ã£o.",
    fr: "Contacte la bibliothÃ¨que pour rÃ©gulariser ta situation.",
    es: "Contacta la biblioteca para regularizar tu situaciÃ³n.",
    en: "Contact the library to resolve your situation.",
    it: "Contatta la biblioteca per regolarizzare la tua situazione.",
    de: "Kontaktiere die Bibliothek, um deine Situation zu klÃ¤ren."
  },
  "prof.formalNotice": {
    "pt-BR": "Aviso formal de restriÃ§Ã£o",
    fr: "Avis formel concernant la restriction",
    es: "Aviso formal sobre la restricciÃ³n",
    en: "Formal notice regarding the restriction",
    it: "Avviso formale relativo alla restrizione",
    de: "Formelle Mitteilung zur EinschrÃ¤nkung"
  },
  "prof.formalNotice.intro": {
    "pt-BR": "Esta mensagem Ã© um aviso formal sobre a restriÃ§Ã£o d(o/a/e) seu cadastro.",
    fr: "Ce message est un avis formel concernant la restriction de ton compte.",
    es: "Este mensaje es un aviso formal sobre la restricciÃ³n de tu cuenta.",
    en: "This message is a formal notice regarding the restriction on your account.",
    it: "Questo messaggio Ã¨ un avviso formale relativo alla restrizione del tuo account.",
    de: "Diese Nachricht ist eine formelle Mitteilung zur EinschrÃ¤nkung deines Kontos."
  },

  // ===== Pickup reply (pr.*) â€” admin-only mais traduit pour cohÃ©rence ======
  "pr.readerReply": {
    "pt-BR": "Resposta d(o/a/e) leitor(a/e) sobre a retirada",
    fr: "RÃ©ponse duÂ·de la lecteurÂ·rice sur le retrait",
    es: "Respuesta de le lector(a/e) sobre el retiro",
    en: "Reader reply about pickup",
    it: "Risposta del/la lettore/trice sul ritiro",
    de: "Antwort der*des Leser*in zur Abholung"
  },
  "pr.confirmed": {
    "pt-BR": "Leitor(a/e) confirmou o horÃ¡rio de retirada",
    fr: "LeÂ·la lecteurÂ·rice a confirmÃ© l'horaire de retrait",
    es: "Le lector(a/e) confirmÃ³ el horario de retiro",
    en: "Reader confirmed the pickup time",
    it: "Il/la lettore/trice ha confermato l'orario di ritiro",
    de: "Leser*in hat den Abholzeitpunkt bestÃ¤tigt"
  },
  "pr.declined": {
    "pt-BR": "Leitor(a/e) nÃ£o pode no horÃ¡rio proposto",
    fr: "LeÂ·la lecteurÂ·rice ne peut pas Ã  l'horaire proposÃ©",
    es: "Le lector(a/e) no puede en el horario propuesto",
    en: "Reader can't make the proposed time",
    it: "Il/la lettore/trice non puÃ² all'orario proposto",
    de: "Leser*in kann zum vorgeschlagenen Zeitpunkt nicht"
  },

  // ===== Admin subjects (admin.*) ===========================================
  "admin.newLoan": {
    "pt-BR": "Novo emprÃ©stimo registrado",
    fr: "Nouvel emprunt enregistrÃ©",
    es: "Nuevo prÃ©stamo registrado",
    en: "New loan registered",
    it: "Nuovo prestito registrato",
    de: "Neue Ausleihe registriert"
  },
  "admin.renewalDone": {
    "pt-BR": "ProrrogaÃ§Ã£o registrada",
    fr: "Prolongation enregistrÃ©e",
    es: "RenovaciÃ³n registrada",
    en: "Renewal recorded",
    it: "Rinnovo registrato",
    de: "VerlÃ¤ngerung registriert"
  },
  "admin.returnDone": {
    "pt-BR": "DevoluÃ§Ã£o registrada",
    fr: "Retour enregistrÃ©",
    es: "DevoluciÃ³n registrada",
    en: "Return recorded",
    it: "Restituzione registrata",
    de: "RÃ¼ckgabe registriert"
  },
  "admin.partialReturnDone": {
    "pt-BR": "DevoluÃ§Ã£o parcial registrada",
    fr: "Retour partiel enregistrÃ©",
    es: "DevoluciÃ³n parcial registrada",
    en: "Partial return recorded",
    it: "Restituzione parziale registrata",
    de: "TeilrÃ¼ckgabe registriert"
  },
  "admin.fullyReturnedAfterPartialDone": {
    "pt-BR": "EmprÃ©stimo concluÃ­do (apÃ³s devoluÃ§Ã£o parcial)",
    fr: "Emprunt clÃ´turÃ© (aprÃ¨s retour partiel)",
    es: "PrÃ©stamo concluido (tras devoluciÃ³n parcial)",
    en: "Loan completed (after partial return)",
    it: "Prestito concluso (dopo restituzione parziale)",
    de: "Ausleihe abgeschlossen (nach TeilrÃ¼ckgabe)"
  },
  "admin.returnUpdate": {
    "pt-BR": "AtualizaÃ§Ã£o sobre devoluÃ§Ã£o",
    fr: "Mise Ã  jour sur un retour",
    es: "ActualizaciÃ³n sobre devoluciÃ³n",
    en: "Return update",
    it: "Aggiornamento su una restituzione",
    de: "Aktualisierung zu einer RÃ¼ckgabe"
  },
  "admin.loanUpdate": {
    "pt-BR": "AtualizaÃ§Ã£o d(o/a/e) emprÃ©stimo",
    fr: "Mise Ã  jour de l'emprunt",
    es: "ActualizaciÃ³n del prÃ©stamo",
    en: "Loan update",
    it: "Aggiornamento del prestito",
    de: "Aktualisierung der Ausleihe"
  },
  "admin.resUpdate": {
    "pt-BR": "AtualizaÃ§Ã£o da reserva",
    fr: "Mise Ã  jour de la rÃ©servation",
    es: "ActualizaciÃ³n de la reserva",
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

  // ===== Task statuses (ts.*) â€” usage Painel internal tasks =================
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
    fr: "Ã€ faire",
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
    "pt-BR": "ConcluÃ­da",
    fr: "TerminÃ©e",
    es: "Completada",
    en: "Completed",
    it: "Completata",
    de: "Abgeschlossen"
  },
  "ts.cancelada": {
    "pt-BR": "Cancelada",
    fr: "AnnulÃ©e",
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
    "pt-BR": "MÃ©dia",
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

  // ===== Team â€” RÃ´les dynamiques (team.role.*) ==============================
  "team.role.librarian": {
    "pt-BR": "bibliotecÃ¡ri(o/a/e)",
    fr: "bibliothÃ©caire",
    es: "bibliotecarie",
    en: "librarian",
    it: "bibliotecario/a/e",
    de: "Bibliothekar*in"
  },
  "team.role.coordenador": {
    "pt-BR": "coordenador(o/a/e)",
    fr: "coordinateurÂ·rice",
    es: "coordinadore",
    en: "coordinator",
    it: "coordinatore/trice/e",
    de: "Koordinator*in"
  },

  // ===== Team â€” Admissions concertÃ©es (team.promoted_*) =====================
  "team.promoted_to_librarian.sub": {
    "pt-BR": "VocÃª foi admitid(o/a/e) bibliotecÃ¡ri(o/a/e)",
    fr: "Tu as Ã©tÃ© admisÂ·e bibliothÃ©caire",
    es: "Fuiste admitide bibliotecarie",
    en: "You have been admitted as a librarian",
    it: "Sei stato/a/e ammesso/a/e come bibliotecario/a/e",
    de: "Du wurdest als Bibliothekar*in aufgenommen"
  },
  "team.promoted_to_librarian.intro": {
    "pt-BR": "VocÃª acaba de ser admitid(o/a/e) bibliotecÃ¡ri(o/a/e) na {libraryName} de maneira concertada pela equipe de animaÃ§Ã£o da biblioteca. Seja bem-vind(o/a/e)!",
    fr: "Tu viens d'Ãªtre admisÂ·e bibliothÃ©caire Ã  la {libraryName} de maniÃ¨re concertÃ©e par l'Ã©quipe d'animation de la bibliothÃ¨que. Bienvenue !",
    es: "AcabÃ¡s de ser admitide bibliotecarie en le {libraryName} de manera concertada por le equipo de animaciÃ³n de la biblioteca. Â¡Bienvenide!",
    en: "You have just been admitted as a librarian at {libraryName} through a concerted decision by the library's animation team. Welcome!",
    it: "Sei appena stato/a/e ammesso/a/e come bibliotecario/a/e a {libraryName} in modo concertato dall'equipe di animazione della biblioteca. Benvenuto/a/e!",
    de: "Du bist soeben als Bibliothekar*in bei {libraryName} in Abstimmung mit dem Animationsteam der Bibliothek aufgenommen worden. Willkommen!"
  },
  "team.promoted_to_coordenador.sub": {
    "pt-BR": "VocÃª foi admitid(o/a/e) coordenador(o/a/e)",
    fr: "Tu as Ã©tÃ© admisÂ·e coordinateurÂ·rice",
    es: "Fuiste admitide coordinadore",
    en: "You have been admitted as a coordinator",
    it: "Sei stato/a/e ammesso/a/e come coordinatore/trice/e",
    de: "Du wurdest als Koordinator*in aufgenommen"
  },
  "team.promoted_to_coordenador.intro": {
    "pt-BR": "VocÃª acaba de ser admitid(o/a/e) coordenador(o/a/e) na {libraryName} de maneira concertada. VocÃª junta-se ao cÃ­rculo de coordenaÃ§Ã£o. Suas responsabilidades se ampliam: governanÃ§a da equipe, validaÃ§Ãµes sensÃ­veis. O regimento interno estÃ¡ aqui: {regimentoUrl}",
    fr: "Tu viens d'Ãªtre admisÂ·e coordinateurÂ·rice Ã  la {libraryName} de maniÃ¨re concertÃ©e. Tu rejoins le cercle de coordination. Tes responsabilitÃ©s s'Ã©largissent : gouvernance de l'Ã©quipe, validations sensibles. Le rÃ¨glement intÃ©rieur est ici : {regimentoUrl}",
    es: "AcabÃ¡s de ser admitide coordinadore en le {libraryName} de manera concertada. Te sumÃ¡s al cÃ­rculo de coordinaciÃ³n. Tus responsabilidades se amplÃ­an: gobernanza de le equipo, validaciones sensibles. El reglamento interno estÃ¡ acÃ¡: {regimentoUrl}",
    en: "You have just been admitted as a coordinator at {libraryName} through a concerted decision. You join the coordination circle. Your responsibilities expand: team governance, sensitive validations. The internal rules are here: {regimentoUrl}",
    it: "Sei appena stato/a/e ammesso/a/e come coordinatore/trice/e a {libraryName} in modo concertato. Entri nel cerchio di coordinamento. Le tue responsabilitÃ  si ampliano: governance dell'equipe, validazioni sensibili. Il regolamento interno Ã¨ qui: {regimentoUrl}",
    de: "Du bist soeben als Koordinator*in bei {libraryName} in Abstimmung aufgenommen worden. Du trittst dem Koordinationskreis bei. Deine Verantwortungen erweitern sich: Governance des Teams, sensible Validierungen. Die interne GeschÃ¤ftsordnung findest du hier: {regimentoUrl}"
  },

  // ===== Team â€” Retour volontaire Ã  un autre rÃ´le (team.self_demoted) =======
  "team.self_demoted.sub": {
    "pt-BR": "{actorName} retornou ao papel de {toRole}",
    fr: "{actorName} est revenuÂ·e au rÃ´le de {toRole}",
    es: "{actorName} volviÃ³ al rol de {toRole}",
    en: "{actorName} has returned to the {toRole} role",
    it: "{actorName} Ã¨ tornato/a/e al ruolo di {toRole}",
    de: "{actorName} ist zur Rolle {toRole} zurÃ¼ckgekehrt"
  },
  "team.self_demoted.intro": {
    "pt-BR": "{actorName} retornou do papel de {fromRole} ao papel de {toRole} na {libraryName}. Esta decisÃ£o Ã© voluntÃ¡ria e imediata.",
    fr: "{actorName} est revenuÂ·e du rÃ´le de {fromRole} au rÃ´le de {toRole} Ã  la {libraryName}. Cette dÃ©cision est volontaire et immÃ©diate.",
    es: "{actorName} volviÃ³ de le rol de {fromRole} al rol de {toRole} en le {libraryName}. Esta decisiÃ³n es voluntaria e inmediata.",
    en: "{actorName} has returned from the {fromRole} role to the {toRole} role at {libraryName}. This decision is voluntary and effective immediately.",
    it: "{actorName} Ã¨ tornato/a/e dal ruolo di {fromRole} al ruolo di {toRole} a {libraryName}. Questa decisione Ã¨ volontaria e immediata.",
    de: "{actorName} ist von der Rolle {fromRole} zur Rolle {toRole} bei {libraryName} zurÃ¼ckgekehrt. Diese Entscheidung ist freiwillig und sofort wirksam."
  },

  // ===== Team â€” Demande de retrait avec carence 7j (team.removal_*) =========
  "team.removal_requested.sub": {
    "pt-BR": "Pedido de retirada concernente a vocÃª",
    fr: "Demande de retrait te concernant",
    es: "Solicitud de retiro que te concierne",
    en: "Removal request concerning you",
    it: "Richiesta di rimozione che ti riguarda",
    de: "Antrag auf Entzug, der dich betrifft"
  },
  "team.removal_requested.intro": {
    "pt-BR": "Um pedido de retirada do papel de {role} concernente a vocÃª foi depositado na {libraryName}. Este pedido estÃ¡ submetido a um prazo de 7 dias durante o qual vocÃª pode trocar com outr(o/a/e)s coordenador(o/a/e)s para compreender ou contestar esta decisÃ£o. Sem anulaÃ§Ã£o da parte del(e/a/e)s antes de {pendingUntilDate}, seu papel de {role} serÃ¡ retirado.",
    fr: "Une demande de retrait du rÃ´le de {role} te concernant a Ã©tÃ© dÃ©posÃ©e Ã  la {libraryName}. Cette demande est soumise Ã  un dÃ©lai de 7 jours pendant lequel tu peux Ã©changer avec les autres coordinateurÂ·rices pour comprendre ou contester cette dÃ©cision. Sans annulation de leur part avant le {pendingUntilDate}, ton rÃ´le de {role} sera retirÃ©.",
    es: "Une solicitud de retiro de le rol de {role} que te concierne fue depositada en le {libraryName}. Esta solicitud estÃ¡ sometida a un plazo de 7 dÃ­as durante el cual podÃ©s intercambiar con les otres coordinadores para comprender o contestar esta decisiÃ³n. Sin anulaciÃ³n de su parte antes de le {pendingUntilDate}, tu rol de {role} serÃ¡ retirado.",
    en: "A request to remove your {role} role at {libraryName} has been filed. This request is subject to a 7-day waiting period during which you may discuss with the other coordinators to understand or contest this decision. Without cancellation on their part before {pendingUntilDate}, your {role} role will be removed.",
    it: "Una richiesta di rimozione dal ruolo di {role} che ti riguarda Ã¨ stata depositata a {libraryName}. Questa richiesta Ã¨ soggetta a un termine di 7 giorni durante il quale puoi confrontarti con le altre coordinatrici e gli altri coordinatori per comprendere o contestare questa decisione. Senza annullamento da parte loro entro il {pendingUntilDate}, il tuo ruolo di {role} sarÃ  rimosso.",
    de: "Ein Antrag auf Entzug der Rolle {role}, der dich betrifft, wurde bei {libraryName} eingereicht. Dieser Antrag unterliegt einer Frist von 7 Tagen, wÃ¤hrend der du dich mit den anderen Koordinator*innen austauschen kannst, um diese Entscheidung zu verstehen oder anzufechten. Ohne Annullierung ihrerseits vor dem {pendingUntilDate} wird deine Rolle als {role} entzogen."
  },
  "team.removal_cancelled.sub": {
    "pt-BR": "O pedido de retirada concernente a vocÃª foi anulado",
    fr: "La demande de retrait te concernant a Ã©tÃ© annulÃ©e",
    es: "La solicitud de retiro que te concierne fue anulada",
    en: "The removal request concerning you has been cancelled",
    it: "La richiesta di rimozione che ti riguarda Ã¨ stata annullata",
    de: "Der Antrag auf Entzug, der dich betraf, wurde annulliert"
  },
  "team.removal_cancelled.intro": {
    "pt-BR": "O pedido de retirada concernente a vocÃª na {libraryName} foi anulado por {cancellerName}. VocÃª recupera todos os seus direitos de {role} imediatamente.",
    fr: "La demande de retrait te concernant Ã  la {libraryName} a Ã©tÃ© annulÃ©e par {cancellerName}. Tu retrouves tous tes droits de {role} immÃ©diatement.",
    es: "La solicitud de retiro que te concierne en le {libraryName} fue anulada por {cancellerName}. RecuperÃ¡s todos tus derechos de {role} inmediatamente.",
    en: "The removal request concerning you at {libraryName} has been cancelled by {cancellerName}. You immediately regain all your {role} rights.",
    it: "La richiesta di rimozione che ti riguarda a {libraryName} Ã¨ stata annullata da {cancellerName}. Recuperi immediatamente tutti i tuoi diritti di {role}.",
    de: "Der Antrag auf Entzug, der dich bei {libraryName} betraf, wurde von {cancellerName} annulliert. Du erhÃ¤ltst sofort alle deine Rechte als {role} zurÃ¼ck."
  },
  "team.removal_completed.sub": {
    "pt-BR": "Sua retirada do papel de {role} foi finalizada",
    fr: "Ton retrait du rÃ´le de {role} a Ã©tÃ© finalisÃ©",
    es: "Tu retiro de le rol de {role} fue finalizado",
    en: "Your removal from the {role} role has been finalised",
    it: "La tua rimozione dal ruolo di {role} Ã¨ stata finalizzata",
    de: "Dein Entzug der Rolle {role} wurde abgeschlossen"
  },
  "team.removal_completed.intro": {
    "pt-BR": "O prazo de 7 dias decorreu sem anulaÃ§Ã£o. Seu papel de {role} na {libraryName} foi retirado. Se vocÃª deseja compreender esta decisÃ£o ou discuti-la, entre em contato com (o/a/e)s coordenador(o/a/e)s.",
    fr: "Le dÃ©lai de 7 jours s'est Ã©coulÃ© sans annulation. Ton rÃ´le de {role} Ã  la {libraryName} a Ã©tÃ© retirÃ©. Si tu souhaites comprendre cette dÃ©cision ou en discuter, contacte les coordinateurÂ·rices.",
    es: "El plazo de 7 dÃ­as transcurriÃ³ sin anulaciÃ³n. Tu rol de {role} en le {libraryName} fue retirado. Si querÃ©s comprender esta decisiÃ³n o discutirla, contactÃ¡ a les coordinadores.",
    en: "The 7-day period has elapsed without cancellation. Your {role} role at {libraryName} has been removed. If you wish to understand this decision or discuss it, contact the coordinators.",
    it: "Il termine di 7 giorni Ã¨ trascorso senza annullamento. Il tuo ruolo di {role} a {libraryName} Ã¨ stato rimosso. Se desideri comprendere questa decisione o discuterne, contatta le coordinatrici e i coordinatori.",
    de: "Die Frist von 7 Tagen ist ohne Annullierung verstrichen. Deine Rolle als {role} bei {libraryName} wurde entzogen. Wenn du diese Entscheidung verstehen oder besprechen mÃ¶chtest, wende dich an die Koordinator*innen."
  },

  // ===== Team â€” Suspension immÃ©diate (team.suspended_*) =====================
  "team.suspended.sub": {
    "pt-BR": "SuspensÃ£o imediata dos seus direitos de {role}",
    fr: "Suspension immÃ©diate de tes droits de {role}",
    es: "SuspensiÃ³n inmediata de tus derechos de {role}",
    en: "Immediate suspension of your {role} rights",
    it: "Sospensione immediata dei tuoi diritti di {role}",
    de: "Sofortige Aussetzung deiner {role}-Rechte"
  },
  "team.suspended.intro": {
    "pt-BR": "Seus direitos de {role} na {libraryName} foram suspensos por medida cautelar. Motivo comunicado: {reason}. Para compreender ou contestar esta decisÃ£o, entre em contato com (o/a/e)s coordenador(o/a/e)s o mais rÃ¡pido possÃ­vel.",
    fr: "Tes droits de {role} Ã  la {libraryName} ont Ã©tÃ© suspendus par mesure conservatoire. Motif communiquÃ© : {reason}. Pour comprendre ou contester cette dÃ©cision, contacte les coordinateurÂ·rices au plus vite.",
    es: "Tus derechos de {role} en le {libraryName} fueron suspendidos por medida cautelar. Motivo comunicado: {reason}. Para comprender o contestar esta decisiÃ³n, contactÃ¡ a les coordinadores lo antes posible.",
    en: "Your {role} rights at {libraryName} have been suspended as a precautionary measure. Communicated reason: {reason}. To understand or contest this decision, contact the coordinators as soon as possible.",
    it: "I tuoi diritti di {role} a {libraryName} sono stati sospesi come misura cautelare. Motivo comunicato: {reason}. Per comprendere o contestare questa decisione, contatta le coordinatrici e i coordinatori il prima possibile.",
    de: "Deine {role}-Rechte bei {libraryName} wurden als vorsorgliche MaÃŸnahme ausgesetzt. Mitgeteilter Grund: {reason}. Um diese Entscheidung zu verstehen oder anzufechten, wende dich so schnell wie mÃ¶glich an die Koordinator*innen."
  },
  "team.unsuspended.sub": {
    "pt-BR": "Levantamento da sua suspensÃ£o",
    fr: "LevÃ©e de ta suspension",
    es: "Levantamiento de tu suspensiÃ³n",
    en: "Lifting of your suspension",
    it: "Revoca della tua sospensione",
    de: "Aufhebung deiner Aussetzung"
  },
  "team.unsuspended.intro": {
    "pt-BR": "A suspensÃ£o dos seus direitos de {role} na {libraryName} foi levantada por {actorName}. VocÃª recupera imediatamente seus acessos.",
    fr: "La suspension de tes droits de {role} Ã  la {libraryName} a Ã©tÃ© levÃ©e par {actorName}. Tu retrouves immÃ©diatement tes accÃ¨s.",
    es: "La suspensiÃ³n de tus derechos de {role} en le {libraryName} fue levantada por {actorName}. RecuperÃ¡s inmediatamente tus accesos.",
    en: "The suspension of your {role} rights at {libraryName} has been lifted by {actorName}. You immediately regain your access.",
    it: "La sospensione dei tuoi diritti di {role} a {libraryName} Ã¨ stata revocata da {actorName}. Recuperi immediatamente i tuoi accessi.",
    de: "Die Aussetzung deiner {role}-Rechte bei {libraryName} wurde von {actorName} aufgehoben. Du erhÃ¤ltst sofort deinen Zugang zurÃ¼ck."
  },

  // ===== Team â€” Escalades aux administrateurÂ·rices AnarBib (team.last_*) ====
  "team.last_coordinator_left.sub": {
    "pt-BR": "{libraryName} nÃ£o tem mais coordenador(o/a/e)",
    fr: "{libraryName} n'a plus de coordinateurÂ·rice",
    es: "{libraryName} ya no tiene coordinadore",
    en: "{libraryName} no longer has a coordinator",
    it: "{libraryName} non ha piÃ¹ coordinatori/trici/e",
    de: "{libraryName} hat keine Koordinator*in mehr"
  },
  "team.last_coordinator_left.intro": {
    "pt-BR": "A biblioteca {libraryName} encontra-se sem coordenador(o/a/e) ativ(o/a/e). {actorName} acaba de retornar a um papel nÃ£o-coordenador, e ninguÃ©m mais ocupa o papel. A biblioteca permanece funcional tecnicamente (os bibliotecÃ¡ri(o/a/e)s podem continuar a operar) mas nÃ£o tem mais instÃ¢ncia de coordenaÃ§Ã£o interna. Uma intervenÃ§Ã£o polÃ­tica da rede AnarBib Ã© provavelmente necessÃ¡ria.",
    fr: "La bibliothÃ¨que {libraryName} se retrouve sans coordinateurÂ·rice actifÂ·ve. {actorName} vient de revenir Ã  un rÃ´le non-coordinateur, et personne d'autre n'occupe le rÃ´le. La bibliothÃ¨que reste fonctionnelle techniquement (les bibliothÃ©caires peuvent toujours opÃ©rer) mais n'a plus d'instance de coordination interne. Une intervention politique du rÃ©seau AnarBib est probablement nÃ©cessaire.",
    es: "La biblioteca {libraryName} se encuentra sin coordinadore active. {actorName} acaba de volver a un rol no-coordinadore, y nadie mÃ¡s ocupa el rol. La biblioteca permanece funcional tÃ©cnicamente (les bibliotecaries pueden seguir operando) pero ya no tiene instancia de coordinaciÃ³n interna. Una intervenciÃ³n polÃ­tica de le red AnarBib es probablemente necesaria.",
    en: "The {libraryName} library finds itself without an active coordinator. {actorName} has just returned to a non-coordinator role, and no one else holds the position. The library remains technically functional (librarians can still operate) but no longer has an internal coordination body. A political intervention from the AnarBib network is likely necessary.",
    it: "La biblioteca {libraryName} si ritrova senza coordinatori/trici/e attivi/e. {actorName} Ã¨ appena tornato/a/e a un ruolo non-coordinatore, e nessun'altra persona occupa il ruolo. La biblioteca rimane funzionale tecnicamente (le bibliotecarie e i bibliotecari possono continuare a operare) ma non ha piÃ¹ un'istanza di coordinamento interna. Un intervento politico della rete AnarBib Ã¨ probabilmente necessario.",
    de: "Die Bibliothek {libraryName} steht ohne aktive Koordinator*in da. {actorName} ist soeben zu einer Nicht-Koordinator*innen-Rolle zurÃ¼ckgekehrt, und niemand sonst nimmt die Rolle wahr. Die Bibliothek bleibt technisch funktionsfÃ¤hig (die Bibliothekar*innen kÃ¶nnen weiter arbeiten), hat aber keine interne Koordinationsinstanz mehr. Eine politische Intervention des AnarBib-Netzwerks ist wahrscheinlich notwendig."
  },
  "team.last_coordinator_pending_removal.sub": {
    "pt-BR": "{libraryName} corre risco de ficar sem coordenador(o/a/e)",
    fr: "{libraryName} risque de se retrouver sans coordinateurÂ·rice",
    es: "{libraryName} corre el riesgo de quedarse sin coordinadore",
    en: "{libraryName} risks finding itself without a coordinator",
    it: "{libraryName} rischia di ritrovarsi senza coordinatori/trici/e",
    de: "{libraryName} lÃ¤uft Gefahr, ohne Koordinator*in dazustehen"
  },
  "team.last_coordinator_pending_removal.intro": {
    "pt-BR": "A biblioteca {libraryName} nÃ£o terÃ¡ mais coordenador(o/a/e) ativ(o/a/e) a partir de {pendingUntilDate} se o pedido de retirada em curso nÃ£o for anulado. {actorName} pediu a retirada d(o/a/e) Ãºltim(o/a/e) coordenador(o/a/e) ativ(o/a/e) da biblioteca. VocÃª pode observar a situaÃ§Ã£o, ou intervir politicamente se necessÃ¡rio.",
    fr: "La bibliothÃ¨que {libraryName} aura plus de coordinateurÂ·rice actifÂ·ve Ã  partir du {pendingUntilDate} si la demande de retrait en cours n'est pas annulÃ©e. {actorName} a demandÃ© le retrait de la derniÃ¨re coordinateurÂ·rice actifÂ·ve de la bibliothÃ¨que. Tu peux observer la situation, ou intervenir politiquement si nÃ©cessaire.",
    es: "La biblioteca {libraryName} ya no tendrÃ¡ coordinadore active a partir de le {pendingUntilDate} si la solicitud de retiro en curso no es anulada. {actorName} solicitÃ³ el retiro de le Ãºltima coordinadore active de la biblioteca. PodÃ©s observar la situaciÃ³n, o intervenir polÃ­ticamente si es necesario.",
    en: "The {libraryName} library will have no active coordinator from {pendingUntilDate} onwards if the pending removal request is not cancelled. {actorName} requested the removal of the last active coordinator at the library. You may observe the situation, or intervene politically if necessary.",
    it: "La biblioteca {libraryName} non avrÃ  piÃ¹ coordinatori/trici/e attivi/e a partire dal {pendingUntilDate} se la richiesta di rimozione in corso non viene annullata. {actorName} ha richiesto la rimozione dell'ultim(o/a/e) coordinator(e/trice/e) attiv(o/a/e) della biblioteca. Puoi osservare la situazione, o intervenire politicamente se necessario.",
    de: "Die Bibliothek {libraryName} wird ab dem {pendingUntilDate} keine aktive Koordinator*in mehr haben, falls der laufende Antrag auf Entzug nicht annulliert wird. {actorName} hat den Entzug der letzten aktiven Koordinator*in der Bibliothek beantragt. Du kannst die Situation beobachten oder politisch intervenieren, falls notwendig."
  },

  // ===== Team â€” Avertissements et passage en inactif (team.inactive_*) ======
  // Ã‰cole 1 stricte : "inactif" qualifie "compte" / "statut" (concepts), donc
  // accord grammatical standard, pas de marquage militant.
  "team.inactive_warning_30d.sub": {
    "pt-BR": "Sua conta vai passar a inativa em 30 dias",
    fr: "Ton compte va passer en inactif dans 30 jours",
    es: "Tu cuenta va a pasar a inactiva en 30 dÃ­as",
    en: "Your account will become inactive in 30 days",
    it: "Il tuo account passerÃ  a inattivo tra 30 giorni",
    de: "Dein Konto wird in 30 Tagen inaktiv"
  },
  "team.inactive_warning_30d.intro": {
    "pt-BR": "VocÃª nÃ£o se conectou em AnarBib hÃ¡ 8 meses. Sem conexÃ£o da sua parte nos prÃ³ximos 30 dias, seu status de {role} na {libraryName} passarÃ¡ automaticamente a inativo. Para conservar seus acessos, conecte-se simplesmente a AnarBib antes de {deadlineDate}.",
    fr: "Tu ne t'es pas connectÃ©Â·e sur AnarBib depuis 8 mois. Sans connexion de ta part dans les 30 prochains jours, ton statut de {role} Ã  la {libraryName} passera automatiquement en inactif. Pour conserver tes accÃ¨s, connecte-toi simplement Ã  AnarBib avant le {deadlineDate}.",
    es: "No te conectaste a AnarBib desde hace 8 meses. Sin conexiÃ³n de tu parte en los prÃ³ximos 30 dÃ­as, tu estatus de {role} en le {libraryName} pasarÃ¡ automÃ¡ticamente a inactivo. Para conservar tus accesos, conectate simplemente a AnarBib antes de le {deadlineDate}.",
    en: "You have not signed in to AnarBib for 8 months. Without a connection on your part within the next 30 days, your {role} status at {libraryName} will automatically become inactive. To keep your access, simply log in to AnarBib before {deadlineDate}.",
    it: "Non ti sei connesso/a/e ad AnarBib da 8 mesi. Senza una connessione da parte tua nei prossimi 30 giorni, il tuo status di {role} a {libraryName} passerÃ  automaticamente a inattivo. Per conservare i tuoi accessi, connettiti semplicemente ad AnarBib prima del {deadlineDate}.",
    de: "Du hast dich seit 8 Monaten nicht mehr bei AnarBib angemeldet. Ohne Anmeldung deinerseits in den nÃ¤chsten 30 Tagen wird dein Status als {role} bei {libraryName} automatisch auf inaktiv gesetzt. Um deinen Zugang zu behalten, melde dich einfach bei AnarBib vor dem {deadlineDate} an."
  },
  "team.inactive_warning_7d.sub": {
    "pt-BR": "Ãšltimo lembrete: sua conta passa a inativa em 7 dias",
    fr: "Dernier rappel : ton compte passe en inactif dans 7 jours",
    es: "Ãšltimo recordatorio: tu cuenta pasa a inactiva en 7 dÃ­as",
    en: "Last reminder: your account becomes inactive in 7 days",
    it: "Ultimo promemoria: il tuo account passa a inattivo tra 7 giorni",
    de: "Letzte Erinnerung: Dein Konto wird in 7 Tagen inaktiv"
  },
  "team.inactive_warning_7d.intro": {
    "pt-BR": "Sem conexÃ£o da sua parte nos prÃ³ximos 7 dias, seu status de {role} na {libraryName} passarÃ¡ automaticamente a inativo em {deadlineDate}.",
    fr: "Sans connexion de ta part dans les 7 prochains jours, ton statut de {role} Ã  la {libraryName} passera automatiquement en inactif le {deadlineDate}.",
    es: "Sin conexiÃ³n de tu parte en los prÃ³ximos 7 dÃ­as, tu estatus de {role} en le {libraryName} pasarÃ¡ automÃ¡ticamente a inactivo el {deadlineDate}.",
    en: "Without a connection on your part within the next 7 days, your {role} status at {libraryName} will automatically become inactive on {deadlineDate}.",
    it: "Senza una connessione da parte tua nei prossimi 7 giorni, il tuo status di {role} a {libraryName} passerÃ  automaticamente a inattivo il {deadlineDate}.",
    de: "Ohne Anmeldung deinerseits in den nÃ¤chsten 7 Tagen wird dein Status als {role} bei {libraryName} am {deadlineDate} automatisch auf inaktiv gesetzt."
  },
  "team.inactive_completed.sub": {
    "pt-BR": "Sua conta passou a inativa",
    fr: "Ton compte est passÃ© en inactif",
    es: "Tu cuenta pasÃ³ a inactiva",
    en: "Your account has become inactive",
    it: "Il tuo account Ã¨ passato a inattivo",
    de: "Dein Konto ist inaktiv geworden"
  },
  "team.inactive_completed.intro": {
    "pt-BR": "ApÃ³s 9 meses sem conexÃ£o, seu status de {role} na {libraryName} passou a inativo. Seus acessos estÃ£o fechados. Se vocÃª desejar recuperÃ¡-los, entre em contato com (o/a/e)s coordenador(o/a/e)s da biblioteca para uma reativaÃ§Ã£o.",
    fr: "AprÃ¨s 9 mois sans connexion, ton statut de {role} Ã  la {libraryName} est passÃ© en inactif. Tes accÃ¨s sont fermÃ©s. Si tu souhaites les retrouver, contacte les coordinateurÂ·rices de la bibliothÃ¨que pour une rÃ©activation.",
    es: "DespuÃ©s de 9 meses sin conexiÃ³n, tu estatus de {role} en le {libraryName} pasÃ³ a inactivo. Tus accesos estÃ¡n cerrados. Si querÃ©s recuperarlos, contactÃ¡ a les coordinadores de la biblioteca para una reactivaciÃ³n.",
    en: "After 9 months without a connection, your {role} status at {libraryName} has become inactive. Your access is closed. If you wish to regain it, contact the library coordinators for a reactivation.",
    it: "Dopo 9 mesi senza connessione, il tuo status di {role} a {libraryName} Ã¨ passato a inattivo. I tuoi accessi sono chiusi. Se desideri recuperarli, contatta le coordinatrici e i coordinatori della biblioteca per una riattivazione.",
    de: "Nach 9 Monaten ohne Anmeldung ist dein Status als {role} bei {libraryName} auf inaktiv gesetzt worden. Dein Zugang ist geschlossen. Wenn du ihn zurÃ¼ckerhalten mÃ¶chtest, wende dich an die Koordinator*innen der Bibliothek fÃ¼r eine Reaktivierung."
  },

  // ===== Welcome â€” mail de bienvenue post-inscription (welcome.*) ============
  // Section utilisÃ©e par register/index.ts > buildUserMail()
  // Cas standard : inscription rattachÃ©e Ã  une biblio existante
  // Cas "initial" : inscription orpheline (signup_without_library=true)
  //   â†’ contient le CTA vers /solicitar-biblioteca avec claim token (TTL 14j)
  "welcome.subject": {
    "pt-BR": "Cadastro criado â€” {displayName}",
    fr: "Inscription crÃ©Ã©e â€” {displayName}",
    es: "InscripciÃ³n creada â€” {displayName}",
    en: "Registration created â€” {displayName}",
    it: "Iscrizione creata â€” {displayName}",
    de: "Anmeldung erstellt â€” {displayName}"
  },
  "welcome.subject.initial": {
    "pt-BR": "Cadastro inicial criado â€” {displayName}",
    fr: "Inscription initiale crÃ©Ã©e â€” {displayName}",
    es: "InscripciÃ³n inicial creada â€” {displayName}",
    en: "Initial registration created â€” {displayName}",
    it: "Iscrizione iniziale creata â€” {displayName}",
    de: "Anmeldung initialisiert â€” {displayName}"
  },
  "welcome.pretitle": {
    "pt-BR": "Cadastro criado",
    fr: "Inscription crÃ©Ã©e",
    es: "InscripciÃ³n creada",
    en: "Registration created",
    it: "Iscrizione creata",
    de: "Anmeldung erstellt"
  },
  "welcome.pretitle.initial": {
    "pt-BR": "Cadastro inicial criado",
    fr: "Inscription initiale crÃ©Ã©e",
    es: "InscripciÃ³n inicial creada",
    en: "Initial registration created",
    it: "Iscrizione iniziale creata",
    de: "Anmeldung initialisiert"
  },
  "welcome.title.initial": {
    "pt-BR": "Bem-vindo/a/e Ã  rede AnarBib",
    fr: "Bienvenue dans le rÃ©seau AnarBib",
    es: "Bienvenide a la red AnarBib",
    en: "Welcome to the AnarBib network",
    it: "BenvenutÉ™ nella rete AnarBib",
    de: "Willkommen im AnarBib-Netzwerk"
  },
   "welcome.title": {
    "pt-BR": "Bem-vindo/a/e Ã  {libraryName}",
    fr: "Bienvenue Ã  la {libraryName}",
    es: "Bienvenide a le {libraryName}",
    en: "Welcome to {libraryName}",
    it: "BenvenutÉ™ alla {libraryName}",
    de: "Willkommen bei {libraryName}"
  },
  "welcome.subtitle": {
    "pt-BR": "Seu acesso inicial ao AnarBib jÃ¡ estÃ¡ pronto.",
    fr: "Ton accÃ¨s initial Ã  AnarBib est prÃªt.",
    es: "Tu acceso inicial a AnarBib ya estÃ¡ listo.",
    en: "Your initial access to AnarBib is ready.",
    it: "Il tuo accesso iniziale ad AnarBib Ã¨ pronto.",
    de: "Dein erster Zugang zu AnarBib ist bereit."
  },
  "welcome.greeting": {
    "pt-BR": "OlÃ¡, <b>{firstName}</b>.",
    fr: "Bonjour, <b>{firstName}</b>.",
    es: "Hola, <b>{firstName}</b>.",
    en: "Hello, <b>{firstName}</b>.",
    it: "Ciao, <b>{firstName}</b>.",
    de: "Hallo, <b>{firstName}</b>."
  },
  "welcome.context.standard": {
    "pt-BR": "Seu cadastro de leitor/a/e na <b>{libraryName}</b> foi criado com sucesso.",
    fr: "Ton inscription en tant que lecteurÂ·rice Ã  la <b>{libraryName}</b> a Ã©tÃ© crÃ©Ã©e avec succÃ¨s.",
    es: "Tu inscripciÃ³n como lector(a/e) en le <b>{libraryName}</b> fue creada con Ã©xito.",
    en: "Your reader registration at <b>{libraryName}</b> has been created successfully.",
    it: "La tua iscrizione come lettore/lettrice presso <b>{libraryName}</b> Ã¨ stata creata con successo.",
    de: "Deine Leser*innen-Anmeldung bei <b>{libraryName}</b> wurde erfolgreich erstellt."
  },
  "welcome.context.initial": {
    "pt-BR": "Sua conta inicial no <b>AnarBib</b> foi criada com sucesso. A prÃ³xima etapa Ã© enviar a solicitaÃ§Ã£o institucional da sua biblioteca para anÃ¡lise da coordenaÃ§Ã£o da rede.",
    fr: "Ton compte initial sur <b>AnarBib</b> a Ã©tÃ© crÃ©Ã© avec succÃ¨s. La prochaine Ã©tape est d'envoyer la demande institutionnelle de ta bibliothÃ¨que pour analyse de la coordination du rÃ©seau.",
    es: "Tu cuenta inicial en <b>AnarBib</b> fue creada con Ã©xito. El prÃ³ximo paso es enviar la solicitud institucional de tu biblioteca para anÃ¡lisis de la coordinaciÃ³n de la red.",
    en: "Your initial account on <b>AnarBib</b> has been created successfully. The next step is to submit the institutional request for your library to the network coordination for review.",
    it: "Il tuo account iniziale su <b>AnarBib</b> Ã¨ stato creato con successo. Il prossimo passo Ã¨ inviare la richiesta istituzionale della tua biblioteca per l'analisi del coordinamento della rete.",
    de: "Dein erstes Konto auf <b>AnarBib</b> wurde erfolgreich erstellt. Der nÃ¤chste Schritt ist, den institutionellen Antrag deiner Bibliothek zur PrÃ¼fung durch die Netzwerkkoordination einzureichen."
  },
  "welcome.publicIdLabel": {
    "pt-BR": "Seu ID pÃºblico",
    fr: "Ton identifiant public",
    es: "Tu identificador pÃºblico",
    en: "Your public ID",
    it: "Il tuo ID pubblico",
    de: "Deine Ã¶ffentliche Kennung"
  },
  "welcome.tempPasswordLabel": {
    "pt-BR": "Senha provisÃ³ria",
    fr: "Mot de passe provisoire",
    es: "ContraseÃ±a provisional",
    en: "Temporary password",
    it: "Password provvisoria",
    de: "VorlÃ¤ufiges Passwort"
  },
  "welcome.nextAccess": {
    "pt-BR": "Nos prÃ³ximos acessos ao AnarBib, entre com seu <b>ID pÃºblico</b> e sua senha.",
    fr: "Pour tes prochains accÃ¨s Ã  AnarBib, connecte-toi avec ton <b>identifiant public</b> et ton mot de passe.",
    es: "En tus prÃ³ximos accesos a AnarBib, ingresÃ¡ con tu <b>identificador pÃºblico</b> y tu contraseÃ±a.",
    en: "For your next visits to AnarBib, log in with your <b>public ID</b> and your password.",
    it: "Per i tuoi prossimi accessi ad AnarBib, accedi con il tuo <b>ID pubblico</b> e la tua password.",
    de: "Bei deinen nÃ¤chsten Anmeldungen bei AnarBib verwende deine <b>Ã¶ffentliche Kennung</b> und dein Passwort."
  },
  "welcome.important": {
    "pt-BR": "<b>Importante:</b> a senha enviada aqui Ã© provisÃ³ria. Depois do primeiro acesso, altere-a na pÃ¡gina <b>Conta</b>.",
    fr: "<b>Important :</b> le mot de passe envoyÃ© ici est provisoire. DÃ¨s ton premier accÃ¨s, tu seras invitÃ©Â·e Ã  le changer.",
    es: "<b>Importante:</b> la contraseÃ±a enviada aquÃ­ es provisional. En tu primer acceso, se te invitarÃ¡ a cambiarla.",
    en: "<b>Important:</b> the password sent here is temporary. On your first login, you will be prompted to change it.",
    it: "<b>Importante:</b> la password inviata qui Ã¨ provvisoria. Al primo accesso, ti verrÃ  chiesto di cambiarla.",
    de: "<b>Wichtig:</b> Das hier gesendete Passwort ist vorlÃ¤ufig. Bei deiner ersten Anmeldung wirst du aufgefordert, es zu Ã¤ndern."
  },
  "welcome.forgotHint": {
    "pt-BR": "Se vocÃª perder o acesso, use o botÃ£o <b>â€œEsqueci minha senhaâ€</b> na pÃ¡gina de login.",
    fr: "Si tu perds l'accÃ¨s, utilise le bouton <b>Â« Mot de passe oubliÃ© Â»</b> sur la page de connexion.",
    es: "Si perdÃ©s el acceso, usÃ¡ el botÃ³n <b>Â«OlvidÃ© mi contraseÃ±aÂ»</b> en la pÃ¡gina de inicio de sesiÃ³n.",
    en: "If you lose access, use the <b>â€œForgot my passwordâ€</b> button on the login page.",
    it: "Se perdi l'accesso, usa il pulsante <b>Â«Ho dimenticato la passwordÂ»</b> nella pagina di accesso.",
    de: "Wenn du den Zugang verlierst, verwende die SchaltflÃ¤che <b>â€žPasswort vergessenâ€œ</b> auf der Anmeldeseite."
  },
  "welcome.libraryRequest.intro": {
    "pt-BR": "Use o botÃ£o abaixo para iniciar a solicitaÃ§Ã£o institucional da sua biblioteca. Este link jÃ¡ estÃ¡ ligado Ã  sua conta inicial, nÃ£o precisa entrar manualmente de novo para comeÃ§ar.",
    fr: "Utilise le bouton ci-dessous pour initier la demande institutionnelle de ta bibliothÃ¨que. Ce lien est dÃ©jÃ  liÃ© Ã  ton compte initial, tu n'as pas besoin de te reconnecter manuellement pour commencer.",
    es: "UsÃ¡ el botÃ³n de abajo para iniciar la solicitud institucional de tu biblioteca. Este enlace ya estÃ¡ vinculado a tu cuenta inicial, no necesitÃ¡s iniciar sesiÃ³n manualmente otra vez para comenzar.",
    en: "Use the button below to start the institutional request for your library. This link is already tied to your initial account â€” no need to log in manually again to begin.",
    it: "Usa il pulsante qui sotto per avviare la richiesta istituzionale della tua biblioteca. Questo link Ã¨ giÃ  collegato al tuo account iniziale, non hai bisogno di accedere manualmente di nuovo per iniziare.",
    de: "Verwende die SchaltflÃ¤che unten, um den institutionellen Antrag deiner Bibliothek zu starten. Dieser Link ist bereits mit deinem ersten Konto verknÃ¼pft â€” du musst dich nicht erneut manuell anmelden, um zu beginnen."
  },
  "welcome.libraryRequest.cta": {
    "pt-BR": "Iniciar solicitaÃ§Ã£o da biblioteca",
    fr: "DÃ©marrer la demande de bibliothÃ¨que",
    es: "Iniciar solicitud de la biblioteca",
    en: "Start the library request",
    it: "Avviare la richiesta della biblioteca",
    de: "Antrag der Bibliothek starten"
  },
  "welcome.libraryRequest.fallback": {
    "pt-BR": "Se o link expirar, entre em contato com a coordenaÃ§Ã£o do AnarBib para receber um novo acesso.",
    fr: "Si le lien expire, contacte la coordination d'AnarBib pour recevoir un nouvel accÃ¨s.",
    es: "Si el enlace expira, contactÃ¡ a la coordinaciÃ³n de AnarBib para recibir un nuevo acceso.",
    en: "If the link expires, contact the AnarBib coordination to receive a new access.",
    it: "Se il link scade, contatta il coordinamento di AnarBib per ricevere un nuovo accesso.",
    de: "Wenn der Link ablÃ¤uft, wende dich an die AnarBib-Koordination, um einen neuen Zugang zu erhalten."
  },
  "welcome.libraryAddressLabel": {
    "pt-BR": "EndereÃ§o da biblioteca:",
    fr: "Adresse de la bibliothÃ¨que :",
    es: "DirecciÃ³n de la biblioteca:",
    en: "Library address:",
    it: "Indirizzo della biblioteca:",
    de: "Adresse der Bibliothek:"
  },
  "welcome.libraryContactLabel": {
    "pt-BR": "Contato da biblioteca:",
    fr: "Contact de la bibliothÃ¨que :",
    es: "Contacto de la biblioteca:",
    en: "Library contact:",
    it: "Contatto della biblioteca:",
    de: "Kontakt der Bibliothek:"
  },
  "welcome.autoMessage": {
    "pt-BR": "Mensagem automÃ¡tica do cadastro AnarBib. As respostas a este e-mail serÃ£o encaminhadas para a gestÃ£o do projeto.",
    fr: "Message automatique de l'inscription AnarBib. Les rÃ©ponses Ã  cet e-mail sont transmises Ã  la gestion du projet.",
    es: "Mensaje automÃ¡tico del registro AnarBib. Las respuestas a este correo serÃ¡n reenviadas a la gestiÃ³n del proyecto.",
    en: "Automatic message from the AnarBib registration. Replies to this email are forwarded to the project management.",
    it: "Messaggio automatico dell'iscrizione AnarBib. Le risposte a questa e-mail vengono inoltrate alla gestione del progetto.",
    de: "Automatische Nachricht der AnarBib-Anmeldung. Antworten auf diese E-Mail werden an die Projektleitung weitergeleitet."
  },

// ============================================================================
// Paquet E.1 â€” Bloc i18n Ã  insÃ©rer dans mail-strings.ts
// ============================================================================
// 6 events Ã— 6 locales (pt-BR, fr, es, en, it, de)
// Conventions militantes strictes par locale (cf. en-tÃªte mail-strings.ts) :
//   pt-BR : triple o/a/e, d(o/a/e), dest(e/a)
//   fr    : point mÃ©dian (lecteurÂ·rice, leÂ·la)
//   es    : neutre argentin (le, les, une, conectade)
//   en    : neutre standard Ã©picÃ¨ne
//   it    : compagno/a/e
//   de    : Genderstern (Leser*in, Genoss*in)
// Adresse : vouvoiement neutre (vos / votre / your / ihrÂ·e / usted / vostro / Sie)
//
// GranularitÃ© par event :
//   - network.cooptation_reminder       : .sub .intro .cta .deadline_label
//   - network.collective_removal_proposed : .sub .intro .cta .motivation_label
//   - network.collective_removal_vote_cast : .sub .intro .rationale_label
//   - network.collective_removal_unanimous : .sub .intro .carence_label .target_intro
//   - network.collective_removal_cancelled : .sub .intro
//   - network.collective_removal_executed  : .sub .intro .target_intro
//
// Placeholders standard utilisÃ©s :
//   {proposedName}    nom de la personne proposÃ©e (cooptation) ou ciblÃ©e (retrait)
//   {proposerName}    nom de la personne qui propose
//   {voterName}       nom du votant (peut Ãªtre "Pessoa anÃ´nima" si non-disclose)
//   {voteKind}        favor / against (dÃ©jÃ  traduit cÃ´tÃ© EF avant insertion)
//   {pendingDeadline} date lisible pour fin de carence ou fin de fenÃªtre
// ============================================================================

  // ===== network.cooptation_reminder ========================================
  // Rappel J+14 ou J+25 envoyÃ© aux admins n'ayant pas votÃ©.
  // Edge Function : choisira le bon variant via payload.reminder_kind ('j14'|'j25')
  // et prÃ©fixera le sujet par "[J+14]" ou "[J+25]" si pertinent.
  "network.cooptation_reminder.sub": {
    "pt-BR": "Lembrete : votaÃ§Ã£o pendente sobre a cooptaÃ§Ã£o de {proposedName}",
    fr: "Rappel Â· vote en attente sur la cooptation de {proposedName}",
    es: "Recordatorio Â· votaciÃ³n pendiente sobre la cooptaciÃ³n de {proposedName}",
    en: "Reminder Â· pending vote on the cooptation of {proposedName}",
    it: "Promemoria Â· voto in sospeso sulla cooptazione di {proposedName}",
    de: "Erinnerung Â· ausstehende Abstimmung zur Kooptation von {proposedName}"
  },
  "network.cooptation_reminder.intro": {
    "pt-BR": "Uma proposta de cooptaÃ§Ã£o foi aberta hÃ¡ vÃ¡rios dias e ainda aguarda vossa decisÃ£o. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s Ã© necessÃ¡ria para concluir o processo.",
    fr: "Une proposition de cooptation a Ã©tÃ© ouverte il y a plusieurs jours et attend encore votre dÃ©cision. L'unanimitÃ© des administrateurÂ·rices actifÂ·ves est nÃ©cessaire pour conclure le processus.",
    es: "Una propuesta de cooptaciÃ³n fue abierta hace varios dÃ­as y aÃºn espera vuestra decisiÃ³n. La unanimidad de les administradores activos es necesaria para cerrar el proceso.",
    en: "A cooptation proposal was opened several days ago and is still awaiting your decision. Unanimity among active network administrators is required to complete the process.",
    it: "Una proposta di cooptazione Ã¨ stata aperta diversi giorni fa e attende ancora la vostra decisione. L'unanimitÃ  dei compagni/e amministratori/e attivi/e Ã¨ necessaria per concludere il processo.",
    de: "Ein Kooptationsvorschlag wurde vor mehreren Tagen erÃ¶ffnet und wartet noch auf Ihre Entscheidung. Einstimmigkeit der aktiven Netzwerk-Administrator*innen ist erforderlich, um den Prozess abzuschlieÃŸen."
  },
  "network.cooptation_reminder.cta": {
    "pt-BR": "Acessar a proposta e votar",
    fr: "AccÃ©der Ã  la proposition et voter",
    es: "Acceder a la propuesta y votar",
    en: "Open the proposal and vote",
    it: "Accedere alla proposta e votare",
    de: "Vorschlag Ã¶ffnen und abstimmen"
  },
  "network.cooptation_reminder.deadline_label": {
    "pt-BR": "A proposta expira em {pendingDeadline}.",
    fr: "La proposition expire le {pendingDeadline}.",
    es: "La propuesta expira el {pendingDeadline}.",
    en: "The proposal expires on {pendingDeadline}.",
    it: "La proposta scade il {pendingDeadline}.",
    de: "Der Vorschlag lÃ¤uft am {pendingDeadline} ab."
  },

  // ===== network.collective_removal_proposed ================================
  // EnvoyÃ© aux autres admins actifs (hors proposeur, hors target).
  // Le target n'est pas notifiÃ© Ã  cette Ã©tape (doctrine v0.3 Â§Q5).
  "network.collective_removal_proposed.sub": {
    "pt-BR": "Proposta de retirada coletiva : {proposedName}",
    fr: "Proposition de retrait collectif Â· {proposedName}",
    es: "Propuesta de retiro colectivo Â· {proposedName}",
    en: "Collective removal proposal Â· {proposedName}",
    it: "Proposta di ritiro collettivo Â· {proposedName}",
    de: "Vorschlag eines kollektiven RÃ¼ckzugs Â· {proposedName}"
  },
  "network.collective_removal_proposed.intro": {
    "pt-BR": "{proposerName} abriu uma proposta de retirada coletiva d(o/a/e) administrador(a/e) {proposedName}. Esta Ã© uma decisÃ£o polÃ­tica grave que exige unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s (excluÃ­d(o/a/e) (o/a/e) prÃ³prio(a/e) target). Vosso voto Ã© necessÃ¡rio.",
    fr: "{proposerName} a ouvert une proposition de retrait collectif de l'administrateurÂ·rice {proposedName}. Il s'agit d'une dÃ©cision politique grave qui requiert l'unanimitÃ© des administrateurÂ·rices actifÂ·ves (Ã  l'exclusion de la personne ciblÃ©e). Votre vote est nÃ©cessaire.",
    es: "{proposerName} abriÃ³ una propuesta de retiro colectivo de le administrade {proposedName}. Es una decisiÃ³n polÃ­tica grave que exige la unanimidad de les administradores activos (excluide le propie target). Vuestro voto es necesario.",
    en: "{proposerName} has opened a proposal for the collective removal of network administrator {proposedName}. This is a serious political decision requiring unanimity among active administrators (excluding the target). Your vote is needed.",
    it: "{proposerName} ha aperto una proposta di ritiro collettivo dell'amministratore/trice/e {proposedName}. Ãˆ una decisione politica grave che richiede l'unanimitÃ  dei compagni/e amministratori/e attivi/e (escluso/a/e (il/la/le) compagno/a/e oggetto). Il vostro voto Ã¨ necessario.",
    de: "{proposerName} hat einen Vorschlag zum kollektiven RÃ¼ckzug von Netzwerk-Administrator*in {proposedName} erÃ¶ffnet. Dies ist eine schwerwiegende politische Entscheidung, die die Einstimmigkeit der aktiven Administrator*innen erfordert (ausgenommen die betroffene Person). Ihre Stimme ist erforderlich."
  },
  "network.collective_removal_proposed.cta": {
    "pt-BR": "Acessar a proposta e votar",
    fr: "AccÃ©der Ã  la proposition et voter",
    es: "Acceder a la propuesta y votar",
    en: "Open the proposal and vote",
    it: "Accedere alla proposta e votare",
    de: "Vorschlag Ã¶ffnen und abstimmen"
  },
  "network.collective_removal_proposed.motivation_label": {
    "pt-BR": "MotivaÃ§Ã£o invocada :",
    fr: "Motivation invoquÃ©e :",
    es: "MotivaciÃ³n invocada :",
    en: "Stated motivation:",
    it: "Motivazione invocata :",
    de: "Angegebene BegrÃ¼ndung:"
  },

  // ===== network.collective_removal_vote_cast ===============================
  // EnvoyÃ© aux autres admins actifs aprÃ¨s chaque vote intermÃ©diaire
  // (hors votant, hors target).
  // payload.voter_user_id peut Ãªtre NULL si disclose_identity=false cÃ´tÃ© DB :
  // dans ce cas, l'Edge Function substituera {voterName} par une chaÃ®ne neutre.
  "network.collective_removal_vote_cast.sub": {
    "pt-BR": "Voto registrado sobre a retirada coletiva : {proposedName}",
    fr: "Vote enregistrÃ© sur le retrait collectif de {proposedName}",
    es: "Voto registrado sobre el retiro colectivo de {proposedName}",
    en: "Vote recorded on the collective removal of {proposedName}",
    it: "Voto registrato sul ritiro collettivo di {proposedName}",
    de: "Stimme zum kollektiven RÃ¼ckzug von {proposedName} registriert"
  },
  "network.collective_removal_vote_cast.intro": {
    "pt-BR": "Un(a/e) administrador(a/e) registrou seu voto sobre a proposta de retirada coletiva d(o/a/e) {proposedName}. O processo continua aberto atÃ© que tod(o/a/e)s tenham se pronunciado.",
    fr: "UnÂ·e administrateurÂ·rice a enregistrÃ© son vote sur la proposition de retrait collectif de {proposedName}. Le processus reste ouvert tant que toutes les voix ne se sont pas exprimÃ©es.",
    es: "Une administrade ha registrado su voto sobre la propuesta de retiro colectivo de {proposedName}. El proceso sigue abierto hasta que todes se hayan pronunciado.",
    en: "A network administrator has recorded their vote on the collective removal proposal for {proposedName}. The process remains open until all voices have been heard.",
    it: "Un(o/a/e) amministratore/trice/e ha registrato il proprio voto sulla proposta di ritiro collettivo di {proposedName}. Il processo resta aperto fino a quando tutt(i/e/u) si saranno pronunciat(i/e/u).",
    de: "Ein*e Netzwerk-Administrator*in hat seineÂ·ihre Stimme zum Vorschlag des kollektiven RÃ¼ckzugs von {proposedName} abgegeben. Der Prozess bleibt offen, bis alle Stimmen abgegeben wurden."
  },
  "network.collective_removal_vote_cast.rationale_label": {
    "pt-BR": "Justificativa (obrigatÃ³ria se voto contrÃ¡rio) :",
    fr: "Justification (obligatoire si vote contre) :",
    es: "JustificaciÃ³n (obligatoria si voto en contra) :",
    en: "Rationale (mandatory if voting against):",
    it: "Motivazione (obbligatoria in caso di voto contrario) :",
    de: "BegrÃ¼ndung (verpflichtend bei Gegenstimme):"
  },

  // ===== network.collective_removal_unanimous ===============================
  // EnvoyÃ© Ã  TOUS les admins actifs (target inclus) au moment oÃ¹ l'unanimitÃ©
  // est atteinte. DÃ©clenche les 7 jours de carence avant exÃ©cution.
  // L'Edge Function adaptera l'intro selon que le destinataire est le target
  // ou un autre admin (variante .target_intro).
  "network.collective_removal_unanimous.sub": {
    "pt-BR": "Retirada coletiva confirmada por unanimidade : {proposedName} â€” carÃªncia de 7 dias",
    fr: "Retrait collectif confirmÃ© Ã  l'unanimitÃ© Â· {proposedName} â€” carence de 7 jours",
    es: "Retiro colectivo confirmado por unanimidad Â· {proposedName} â€” perÃ­odo de gracia de 7 dÃ­as",
    en: "Collective removal confirmed by unanimity Â· {proposedName} â€” 7-day grace period",
    it: "Ritiro collettivo confermato all'unanimitÃ  Â· {proposedName} â€” periodo di grazia di 7 giorni",
    de: "Kollektiver RÃ¼ckzug einstimmig bestÃ¤tigt Â· {proposedName} â€” 7-tÃ¤gige Karenzfrist"
  },
  "network.collective_removal_unanimous.intro": {
    "pt-BR": "A unanimidade d(o/a/e)s administrador(a/e)s foi alcanÃ§ada sobre a retirada coletiva d(o/a/e) {proposedName}. Uma carÃªncia de 7 dias se aplica antes da efetivaÃ§Ã£o. Durante este perÃ­odo, qualquer votante pode anular a decisÃ£o se houver mudanÃ§a de posiÃ§Ã£o coletiva.",
    fr: "L'unanimitÃ© des administrateurÂ·rices a Ã©tÃ© atteinte sur le retrait collectif de {proposedName}. Une carence de 7 jours s'applique avant exÃ©cution. Pendant cette pÃ©riode, toutÂ·e votantÂ·e peut annuler la dÃ©cision en cas de changement de position collective.",
    es: "Se alcanzÃ³ la unanimidad de les administradores sobre el retiro colectivo de {proposedName}. Se aplica un perÃ­odo de gracia de 7 dÃ­as antes de la ejecuciÃ³n. Durante este perÃ­odo, cualquier votante puede anular la decisiÃ³n si hay un cambio de posiciÃ³n colectiva.",
    en: "Unanimity among network administrators has been reached on the collective removal of {proposedName}. A 7-day grace period applies before execution. During this period, any voter may cancel the decision if the collective position changes.",
    it: "L'unanimitÃ  dei compagni/e amministratori/e Ã¨ stata raggiunta sul ritiro collettivo di {proposedName}. Si applica un periodo di grazia di 7 giorni prima dell'esecuzione. Durante questo periodo, qualsiasi votante puÃ² annullare la decisione in caso di cambiamento di posizione collettiva.",
    de: "Einstimmigkeit der Netzwerk-Administrator*innen Ã¼ber den kollektiven RÃ¼ckzug von {proposedName} wurde erreicht. Eine 7-tÃ¤gige Karenzfrist gilt vor der Vollziehung. WÃ¤hrend dieser Frist kann jede*r Abstimmende die Entscheidung aufheben, falls sich die kollektive Position Ã¤ndert."
  },
  "network.collective_removal_unanimous.target_intro": {
    "pt-BR": "Esta mensagem informa que a unanimidade d(o/a/e)s outr(o/a/e)s administrador(a/e)s ativ(o/a/e)s foi alcanÃ§ada sobre a vossa retirada coletiva. Uma carÃªncia de 7 dias se aplica antes da efetivaÃ§Ã£o. Vossa palavra Ã© livre durante esta janela.",
    fr: "Ce message vous informe que l'unanimitÃ© des autres administrateurÂ·rices actifÂ·ves a Ã©tÃ© atteinte sur votre retrait collectif. Une carence de 7 jours s'applique avant exÃ©cution. Votre parole est libre durant cette fenÃªtre.",
    es: "Este mensaje le informa que se alcanzÃ³ la unanimidad de les otres administradores activos sobre vuestro retiro colectivo. Se aplica un perÃ­odo de gracia de 7 dÃ­as antes de la ejecuciÃ³n. Vuestra palabra es libre durante esta ventana.",
    en: "This message informs you that unanimity among the other active network administrators has been reached regarding your collective removal. A 7-day grace period applies before execution. Your voice remains free during this window.",
    it: "Questo messaggio vi informa che l'unanimitÃ  degli/delle altr(i/e/u) compagn(i/e/u) amministratori/e attivi/e Ã¨ stata raggiunta sul vostro ritiro collettivo. Si applica un periodo di grazia di 7 giorni prima dell'esecuzione. La vostra parola resta libera durante questa finestra.",
    de: "Diese Nachricht informiert Sie darÃ¼ber, dass die Einstimmigkeit der anderen aktiven Netzwerk-Administrator*innen Ã¼ber Ihren kollektiven RÃ¼ckzug erreicht wurde. Eine 7-tÃ¤gige Karenzfrist gilt vor der Vollziehung. Ihr Wort bleibt frei wÃ¤hrend dieses Zeitraums."
  },
  "network.collective_removal_unanimous.carence_label": {
    "pt-BR": "EfetivaÃ§Ã£o prevista para {pendingDeadline}.",
    fr: "ExÃ©cution prÃ©vue pour le {pendingDeadline}.",
    es: "EjecuciÃ³n prevista para el {pendingDeadline}.",
    en: "Execution scheduled for {pendingDeadline}.",
    it: "Esecuzione prevista per il {pendingDeadline}.",
    de: "Vollziehung vorgesehen fÃ¼r {pendingDeadline}."
  },

  // ===== network.collective_removal_cancelled ===============================
  // EnvoyÃ© aux autres admins (et au target si la proposition Ã©tait unanimous).
  // Purement informatif.
  "network.collective_removal_cancelled.sub": {
    "pt-BR": "Retirada coletiva cancelada : {proposedName}",
    fr: "Retrait collectif annulÃ© Â· {proposedName}",
    es: "Retiro colectivo cancelado Â· {proposedName}",
    en: "Collective removal cancelled Â· {proposedName}",
    it: "Ritiro collettivo annullato Â· {proposedName}",
    de: "Kollektiver RÃ¼ckzug abgebrochen Â· {proposedName}"
  },
  "network.collective_removal_cancelled.intro": {
    "pt-BR": "A proposta de retirada coletiva d(o/a/e) {proposedName} foi anulada. Nenhuma efetivaÃ§Ã£o serÃ¡ realizada. Esta decisÃ£o Ã© registrada no histÃ³rico militante da rede.",
    fr: "La proposition de retrait collectif de {proposedName} a Ã©tÃ© annulÃ©e. Aucune exÃ©cution ne sera rÃ©alisÃ©e. Cette dÃ©cision est consignÃ©e dans l'historique militant du rÃ©seau.",
    es: "La propuesta de retiro colectivo de {proposedName} fue cancelada. No se realizarÃ¡ ninguna ejecuciÃ³n. Esta decisiÃ³n queda registrada en el historial militante de la red.",
    en: "The collective removal proposal for {proposedName} has been cancelled. No execution will occur. This decision is recorded in the militant history of the network.",
    it: "La proposta di ritiro collettivo di {proposedName} Ã¨ stata annullata. Nessuna esecuzione avrÃ  luogo. Questa decisione Ã¨ registrata nella storia militante della rete.",
    de: "Der Vorschlag zum kollektiven RÃ¼ckzug von {proposedName} wurde abgebrochen. Es erfolgt keine Vollziehung. Diese Entscheidung wird in der militanten Geschichte des Netzwerks festgehalten."
  },

  // ===== network.collective_removal_executed ================================
  // EnvoyÃ© aprÃ¨s la carence de 7j, par le cron. Au target + autres admins.
  // L'Edge Function adaptera selon destinataire (target vs autres) via
  // variante .target_intro.
  "network.collective_removal_executed.sub": {
    "pt-BR": "Retirada coletiva efetivada : {proposedName}",
    fr: "Retrait collectif effectif Â· {proposedName}",
    es: "Retiro colectivo efectivo Â· {proposedName}",
    en: "Collective removal effective Â· {proposedName}",
    it: "Ritiro collettivo effettivo Â· {proposedName}",
    de: "Kollektiver RÃ¼ckzug wirksam Â· {proposedName}"
  },
  "network.collective_removal_executed.intro": {
    "pt-BR": "ApÃ³s o tÃ©rmino da carÃªncia de 7 dias, a retirada coletiva d(o/a/e) {proposedName} foi efetivada. Esta pessoa nÃ£o tem mais o papel d(o/a/e) administrador(a/e) de rede. A decisÃ£o Ã© registrada no histÃ³rico militante d(o/a/e) AnarBib.",
    fr: "Ã€ l'issue de la carence de 7 jours, le retrait collectif de {proposedName} a Ã©tÃ© effectuÃ©. Cette personne n'occupe plus la fonction d'administrateurÂ·rice de rÃ©seau. La dÃ©cision est consignÃ©e dans l'historique militant d'AnarBib.",
    es: "Tras el fin del perÃ­odo de gracia de 7 dÃ­as, el retiro colectivo de {proposedName} se hizo efectivo. Esta persona ya no ocupa la funciÃ³n de administrade de red. La decisiÃ³n queda registrada en el historial militante de AnarBib.",
    en: "After the 7-day grace period, the collective removal of {proposedName} has been carried out. This person no longer holds the network administrator role. The decision is recorded in the militant history of AnarBib.",
    it: "Al termine del periodo di grazia di 7 giorni, il ritiro collettivo di {proposedName} Ã¨ stato attuato. Questa persona non ricopre piÃ¹ il ruolo di amministratore/trice/e di rete. La decisione Ã¨ registrata nella storia militante di AnarBib.",
    de: "Nach Ablauf der 7-tÃ¤gigen Karenzfrist wurde der kollektive RÃ¼ckzug von {proposedName} vollzogen. Diese Person ist nicht mehr Netzwerk-Administrator*in. Die Entscheidung wird in der militanten Geschichte von AnarBib festgehalten."
  },
  "network.collective_removal_executed.target_intro": {
    "pt-BR": "A carÃªncia de 7 dias terminou e a retirada coletiva votada por unanimidade estÃ¡ agora efetiva. Vossa funÃ§Ã£o d(o/a/e) administrador(a/e) de rede no AnarBib foi removida. Esta decisÃ£o Ã© registrada no histÃ³rico militante.",
    fr: "La carence de 7 jours est arrivÃ©e Ã  terme et le retrait collectif votÃ© Ã  l'unanimitÃ© prend effet. Votre fonction d'administrateurÂ·rice de rÃ©seau dans AnarBib a Ã©tÃ© retirÃ©e. Cette dÃ©cision est consignÃ©e dans l'historique militant.",
    es: "TerminÃ³ el perÃ­odo de gracia de 7 dÃ­as y el retiro colectivo votado por unanimidad entra en vigor. Vuestra funciÃ³n de administrade de red en AnarBib fue retirada. Esta decisiÃ³n queda registrada en el historial militante.",
    en: "The 7-day grace period has ended and the unanimously-voted collective removal now takes effect. Your network administrator role in AnarBib has been removed. This decision is recorded in the militant history.",
    it: "Il periodo di grazia di 7 giorni Ã¨ terminato e il ritiro collettivo votato all'unanimitÃ  entra in vigore. La vostra funzione di amministratore/trice/e di rete in AnarBib Ã¨ stata rimossa. Questa decisione Ã¨ registrata nella storia militante.",
    de: "Die 7-tÃ¤gige Karenzfrist ist abgelaufen, und der einstimmig beschlossene kollektive RÃ¼ckzug wird wirksam. Ihre Funktion als Netzwerk-Administrator*in in AnarBib wurde entzogen. Diese Entscheidung wird in der militanten Geschichte festgehalten."
  },
};

const D: SupportedMailLocale = "pt-BR";

// ============================================================================
// API publique du module
// ============================================================================

/**
 * RÃ©cupÃ¨re la traduction d'une clÃ© pour une locale donnÃ©e.
 * Si la clÃ© n'existe pas, retourne la clÃ© brute (pour faciliter le debug).
 * Si la locale n'est pas supportÃ©e ou est null, fallback vers pt-BR (D).
 *
 * @param locale Code locale (ex: 'pt-BR', 'fr', 'es', etc.) ou null
 * @param key ClÃ© du dictionnaire (ex: 'wf.ready', 'l.items')
 * @param params ParamÃ¨tres Ã  interpoler (ex: {date: '05/05/2026'})
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

/** Salutation localisÃ©e, avec ou sans nom. */
export function greeting(locale: string | null | undefined, name?: string | null): string {
  return name ? tMail(locale, "greeting.named", { name }) : tMail(locale, "greeting.anonymous");
}

/** Label localisÃ© pour les dÃ©tails de mail (passe par le prÃ©fixe `l.`). */
export function label(locale: string | null | undefined, key: string): string {
  return tMail(locale, `l.${key}`);
}

/** Statut de tÃ¢che localisÃ© (prÃ©fixe `ts.`). */
export function taskStatusLabel(locale: string | null | undefined, status: string): string {
  return tMail(locale, `ts.${status}`);
}

/** PrioritÃ© de tÃ¢che localisÃ©e (prÃ©fixe `tp.`). */
export function taskPriorityLabel(locale: string | null | undefined, priority: string): string {
  return tMail(locale, `tp.${priority}`);
}

/** Formate une date selon la locale (DD/MM/YYYY en pt-BR par dÃ©faut). */
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
// Helpers exportÃ©s pour les tests anti-rÃ©gression
// ============================================================================

/** Liste toutes les clÃ©s dÃ©finies (utile pour les tests). */
export function _allKeys(): string[] {
  return Object.keys(S);
}

/** Retourne l'ensemble des locales supportÃ©es (utile pour les tests). */
export function _supportedLocales(): SupportedMailLocale[] {
  return ["pt-BR", "fr", "es", "en", "it", "de"];
}

/** VÃ©rifie qu'une clÃ© donnÃ©e a une traduction non vide pour toutes les locales. */
export function _isComplete(key: string): boolean {
  const d = S[key];
  if (!d) return false;
  for (const loc of _supportedLocales()) {
    if (!d[loc] || !String(d[loc]).trim()) return false;
  }
  return true;
}
