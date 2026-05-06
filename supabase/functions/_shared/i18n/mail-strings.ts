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

export type SupportedMailLocale = "pt-BR" | "fr" | "es" | "en" | "it" | "de";

const V = new Set<string>(["pt-BR", "fr", "es", "en", "it", "de"]);

const S: Record<string, Record<SupportedMailLocale, string>> = {

  // ===== Greetings ==========================================================
  "greeting.named": {
    "pt-BR": "Olá, {name}!",
    fr: "Bonjour, {name} !",
    es: "¡Hola, {name}!",
    en: "Hello, {name}!",
    it: "Ciao, {name}!",
    de: "Hallo, {name}!"
  },
  "greeting.anonymous": {
    "pt-BR": "Olá!",
    fr: "Bonjour !",
    es: "¡Hola!",
    en: "Hello!",
    it: "Ciao!",
    de: "Hallo!"
  },

  // ===== Layout =============================================================
  "layout.autoNotice": {
    "pt-BR": "Notificação automática",
    fr: "Notification automatique",
    es: "Notificación automática",
    en: "Automatic notification",
    it: "Notifica automatica",
    de: "Automatische Benachrichtigung"
  },
  "layout.footerContact": {
    "pt-BR": "Em caso de dúvida, entre em contato com a biblioteca.",
    fr: "En cas de question, contacte la bibliothèque.",
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
  "l.ref": {
    "pt-BR": "Referência",
    fr: "Référence",
    es: "Referencia",
    en: "Reference",
    it: "Riferimento",
    de: "Referenz"
  },
  "l.refs": {
    "pt-BR": "Referências",
    fr: "Références",
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
    "pt-BR": "Devolução prevista",
    fr: "Retour prévu",
    es: "Devolución prevista",
    en: "Due date",
    it: "Restituzione prevista",
    de: "Fälligkeitsdatum"
  },
  "l.newDueDate": {
    "pt-BR": "Nova devolução",
    fr: "Nouveau retour",
    es: "Nueva devolución",
    en: "New due date",
    it: "Nuova restituzione",
    de: "Neues Fälligkeitsdatum"
  },
  "l.deadline": {
    "pt-BR": "Prazo",
    fr: "Échéance",
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
    "pt-BR": "Renovação em",
    fr: "Renouvelé le",
    es: "Renovación el",
    en: "Renewed on",
    it: "Rinnovo il",
    de: "Verlängert am"
  },
  "l.return": {
    "pt-BR": "Devolução",
    fr: "Retour",
    es: "Devolución",
    en: "Return",
    it: "Restituzione",
    de: "Rückgabe"
  },
  "l.reader": {
    "pt-BR": "Leitor(a/e)",
    fr: "Lecteur·rice",
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
    "pt-BR": "Situação",
    fr: "Situation",
    es: "Situación",
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
    "pt-BR": "Observação",
    fr: "Observation",
    es: "Observación",
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
    fr: "Tâche",
    es: "Tarea",
    en: "Task",
    it: "Compito",
    de: "Aufgabe"
  },
  "l.priority": {
    "pt-BR": "Prioridade",
    fr: "Priorité",
    es: "Prioridad",
    en: "Priority",
    it: "Priorità",
    de: "Priorität"
  },
  "l.tags": {
    "pt-BR": "Marcadores",
    fr: "Étiquettes",
    es: "Etiquetas",
    en: "Tags",
    it: "Etichette",
    de: "Schlagwörter"
  },
  "l.firstDate": {
    "pt-BR": "Próximo vencimento",
    fr: "Prochaine échéance",
    es: "Próximo vencimiento",
    en: "Next due date",
    it: "Prossima scadenza",
    de: "Nächste Fälligkeit"
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
    "pt-BR": "Observação d(o/a/e) leitor(a/e)",
    fr: "Note du·de la lecteur·rice",
    es: "Nota de le lector(a/e)",
    en: "Reader note",
    it: "Nota del/la lettore/trice",
    de: "Anmerkung der*des Leser*in"
  },
  "l.reply": {
    "pt-BR": "Resposta",
    fr: "Réponse",
    es: "Respuesta",
    en: "Reply",
    it: "Risposta",
    de: "Antwort"
  },
  "l.restrictedSince": {
    "pt-BR": "Restrição desde",
    fr: "Restriction depuis",
    es: "Restricción desde",
    en: "Restricted since",
    it: "Restrizione da",
    de: "Eingeschränkt seit"
  },

  // ===== Reservation events (res.*) =========================================
  "res.created.sub": {
    "pt-BR": "Reserva registrada",
    fr: "Réservation enregistrée",
    es: "Reserva registrada",
    en: "Reservation registered",
    it: "Prenotazione registrata",
    de: "Vormerkung registriert"
  },
  "res.created.pre": {
    "pt-BR": "Sua reserva foi registrada com sucesso.",
    fr: "Ta réservation a bien été enregistrée.",
    es: "Tu reserva fue registrada con éxito.",
    en: "Your reservation has been registered.",
    it: "La tua prenotazione è stata registrata.",
    de: "Deine Vormerkung wurde registriert."
  },
  "res.created.intro": {
    "pt-BR": "Recebemos sua reserva. A biblioteca confirmará a disponibilidade em breve.",
    fr: "Nous avons reçu ta réservation. La bibliothèque confirmera bientôt la disponibilité.",
    es: "Recibimos tu reserva. La biblioteca confirmará pronto la disponibilidad.",
    en: "We received your reservation. The library will confirm availability soon.",
    it: "Abbiamo ricevuto la tua prenotazione. La biblioteca confermerà presto la disponibilità.",
    de: "Wir haben deine Vormerkung erhalten. Die Bibliothek bestätigt bald die Verfügbarkeit."
  },
  "res.created.hint": {
    "pt-BR": "Você pode acompanhar o estado d(o/a/e) seu pedido na sua conta.",
    fr: "Tu peux suivre l'état de ta demande dans ton compte.",
    es: "Puedes seguir le estade de tu pedido en tu cuenta.",
    en: "You can track your request status in your account.",
    it: "Puoi seguire lo stato della tua richiesta nel tuo account.",
    de: "Du kannst den Status deiner Anfrage in deinem Konto verfolgen."
  },
  "res.created.admin": {
    "pt-BR": "Nova reserva registrada",
    fr: "Nouvelle réservation enregistrée",
    es: "Nueva reserva registrada",
    en: "New reservation registered",
    it: "Nuova prenotazione registrata",
    de: "Neue Vormerkung registriert"
  },
  "res.refused": {
    "pt-BR": "Reserva recusada pela biblioteca",
    fr: "Réservation refusée par la bibliothèque",
    es: "Reserva rechazada por la biblioteca",
    en: "Reservation declined by the library",
    it: "Prenotazione rifiutata dalla biblioteca",
    de: "Vormerkung von der Bibliothek abgelehnt"
  },
  "res.cancelStaff": {
    "pt-BR": "Reserva cancelada pela biblioteca",
    fr: "Réservation annulée par la bibliothèque",
    es: "Reserva cancelada por la biblioteca",
    en: "Reservation cancelled by the library",
    it: "Prenotazione annullata dalla biblioteca",
    de: "Vormerkung von der Bibliothek storniert"
  },
  "res.cancelReader": {
    "pt-BR": "Reserva cancelada por você",
    fr: "Réservation annulée par toi",
    es: "Reserva cancelada por ti",
    en: "Reservation cancelled by you",
    it: "Prenotazione annullata da te",
    de: "Vormerkung von dir storniert"
  },
  "res.expired": {
    "pt-BR": "Reserva expirada",
    fr: "Réservation expirée",
    es: "Reserva expirada",
    en: "Reservation expired",
    it: "Prenotazione scaduta",
    de: "Vormerkung abgelaufen"
  },
  "res.converted": {
    "pt-BR": "Reserva convertida em empréstimo",
    fr: "Réservation convertie en emprunt",
    es: "Reserva convertide en préstamo",
    en: "Reservation converted into a loan",
    it: "Prenotazione convertita in prestito",
    de: "Vormerkung in Ausleihe umgewandelt"
  },

  // ===== Workflow events (wf.*) =============================================
  "wf.pickupScheduled": {
    "pt-BR": "Retirada agendada",
    fr: "Retrait programmé",
    es: "Retiro programado",
    en: "Pickup scheduled",
    it: "Ritiro programmato",
    de: "Abholung geplant"
  },
  "wf.pickupRescheduled": {
    "pt-BR": "Retirada reagendada",
    fr: "Retrait reprogrammé",
    es: "Retiro reprogramado",
    en: "Pickup rescheduled",
    it: "Ritiro riprogrammato",
    de: "Abholung neu geplant"
  },
  "wf.ready": {
    "pt-BR": "Sua reserva está pronta para retirada",
    fr: "Ta réservation est prête à être retirée",
    es: "Tu reserva está lista para retirar",
    en: "Your reservation is ready for pickup",
    it: "La tua prenotazione è pronta per il ritiro",
    de: "Deine Vormerkung liegt zur Abholung bereit"
  },
  "wf.readyShort": {
    "pt-BR": "Reserva pronta",
    fr: "Réservation prête",
    es: "Reserva lista",
    en: "Reservation ready",
    it: "Prenotazione pronta",
    de: "Vormerkung bereit"
  },
  "wf.noShow": {
    "pt-BR": "Retirada não realizada",
    fr: "Retrait non effectué",
    es: "Retiro no realizado",
    en: "Pickup missed",
    it: "Ritiro non effettuato",
    de: "Abholung nicht erfolgt"
  },
  "wf.closed": {
    "pt-BR": "Reserva encerrada",
    fr: "Réservation clôturée",
    es: "Reserva cerrada",
    en: "Reservation closed",
    it: "Prenotazione chiusa",
    de: "Vormerkung abgeschlossen"
  },
  "wf.checkAccount": {
    "pt-BR": "Confira sua conta para mais detalhes.",
    fr: "Consulte ton compte pour plus de détails.",
    es: "Consulte tu cuenta para más detalles.",
    en: "Check your account for more details.",
    it: "Controlla il tuo account per maggiori dettagli.",
    de: "Sieh in deinem Konto für weitere Details nach."
  },

  // ===== Loan events (loan.*) ===============================================
  "loan.created.sub": {
    "pt-BR": "Empréstimo registrado",
    fr: "Emprunt enregistré",
    es: "Préstamo registrado",
    en: "Loan registered",
    it: "Prestito registrato",
    de: "Ausleihe registriert"
  },
  "loan.created.intro": {
    "pt-BR": "Seu empréstimo foi registrado.",
    fr: "Ton emprunt a bien été enregistré.",
    es: "Tu préstamo fue registrado.",
    en: "Your loan has been registered.",
    it: "Il tuo prestito è stato registrato.",
    de: "Deine Ausleihe wurde registriert."
  },
  "loan.dueIn": {
    "pt-BR": "Devolução prevista para {date}.",
    fr: "Retour prévu pour le {date}.",
    es: "Devolución prevista para el {date}.",
    en: "Due date: {date}.",
    it: "Restituzione prevista per il {date}.",
    de: "Rückgabe vorgesehen für den {date}."
  },
  "loan.renewed.sub": {
    "pt-BR": "Renovação confirmada",
    fr: "Renouvellement confirmé",
    es: "Renovación confirmada",
    en: "Renewal confirmed",
    it: "Rinnovo confermato",
    de: "Verlängerung bestätigt"
  },
  "loan.renewed.intro": {
    "pt-BR": "Sua prorrogação foi confirmada.",
    fr: "Ta prolongation a bien été confirmée.",
    es: "Tu renovación fue confirmada.",
    en: "Your renewal has been confirmed.",
    it: "Il tuo rinnovo è stato confermato.",
    de: "Deine Verlängerung wurde bestätigt."
  },
  "loan.newDue": {
    "pt-BR": "Nova data de devolução: {date}.",
    fr: "Nouvelle date de retour : {date}.",
    es: "Nueva fecha de devolución: {date}.",
    en: "New due date: {date}.",
    it: "Nuova data di restituzione: {date}.",
    de: "Neues Rückgabedatum: {date}."
  },
  "loan.renewed.once": {
    "pt-BR": "Lembre-se: cada empréstimo pode ser prorrogado apenas uma vez.",
    fr: "Pour rappel : chaque emprunt ne peut être prolongé qu'une seule fois.",
    es: "Recuerda: cada préstamo puede renovarse solo une vez.",
    en: "Reminder: each loan can be renewed only once.",
    it: "Ricorda: ogni prestito può essere rinnovato solo una volta.",
    de: "Zur Erinnerung: jede Ausleihe kann nur einmal verlängert werden."
  },
  "loan.returned.sub": {
    "pt-BR": "Devolução registrada",
    fr: "Retour enregistré",
    es: "Devolución registrada",
    en: "Return registered",
    it: "Restituzione registrata",
    de: "Rückgabe registriert"
  },
  "loan.returned.intro": {
    "pt-BR": "Registramos a devolução. Obrigad(o/a/e)!",
    fr: "Nous avons enregistré le retour. Merci !",
    es: "Registramos la devolución. ¡Gracias!",
    en: "We've recorded the return. Thank you!",
    it: "Abbiamo registrato la restituzione. Grazie!",
    de: "Wir haben die Rückgabe registriert. Danke!"
  },
  "loan.returned.browse": {
    "pt-BR": "Continue navegando no acervo para suas próximas leituras.",
    fr: "Continue à explorer le fonds pour tes prochaines lectures.",
    es: "Sigue navegando el acervo para tus próximas lecturas.",
    en: "Keep browsing the collection for your next reads.",
    it: "Continua a esplorare il fondo per le tue prossime letture.",
    de: "Stöbere weiter im Bestand für deine nächste Lektüre."
  },
  "loan.returnScheduled": {
    "pt-BR": "Devolução agendada",
    fr: "Retour programmé",
    es: "Devolución programada",
    en: "Return scheduled",
    it: "Restituzione programmata",
    de: "Rückgabe geplant"
  },
  "loan.returnCancelled": {
    "pt-BR": "Devolução cancelada",
    fr: "Retour annulé",
    es: "Devolución cancelada",
    en: "Return cancelled",
    it: "Restituzione annullata",
    de: "Rückgabe storniert"
  },
  "loan.returnMissed": {
    "pt-BR": "Devolução não realizada",
    fr: "Retour non effectué",
    es: "Devolución no realizada",
    en: "Return missed",
    it: "Restituzione non effettuata",
    de: "Rückgabe nicht erfolgt"
  },

  // ===== Reminders (rem.*) ==================================================
  "rem.title": {
    "pt-BR": "Lembrete de devolução",
    fr: "Rappel de retour",
    es: "Recordatorio de devolución",
    en: "Return reminder",
    it: "Promemoria di restituzione",
    de: "Rückgabeerinnerung"
  },
  "rem.5d": {
    "pt-BR": "Devolução em 5 dias",
    fr: "Retour dans 5 jours",
    es: "Devolución en 5 días",
    en: "Due in 5 days",
    it: "Restituzione tra 5 giorni",
    de: "Rückgabe in 5 Tagen"
  },
  "rem.5d.body": {
    "pt-BR": "Seu empréstimo vence em 5 dias",
    fr: "Ton emprunt arrive à échéance dans 5 jours",
    es: "Tu préstamo vence en 5 días",
    en: "Your loan is due in 5 days",
    it: "Il tuo prestito scade tra 5 giorni",
    de: "Deine Ausleihe läuft in 5 Tagen ab"
  },
  "rem.3d": {
    "pt-BR": "Devolução em 3 dias",
    fr: "Retour dans 3 jours",
    es: "Devolución en 3 días",
    en: "Due in 3 days",
    it: "Restituzione tra 3 giorni",
    de: "Rückgabe in 3 Tagen"
  },
  "rem.3d.body": {
    "pt-BR": "Faltam 3 dias para a devolução do seu empréstimo.",
    fr: "Plus que 3 jours avant la date de retour de ton emprunt.",
    es: "Quedan 3 días para la devolución de tu préstamo.",
    en: "Only 3 days left until the return date of your loan.",
    it: "Mancano 3 giorni alla data di restituzione del tuo prestito.",
    de: "Nur noch 3 Tage bis zum Rückgabedatum deiner Ausleihe."
  },
  "rem.today": {
    "pt-BR": "Devolução hoje",
    fr: "Retour aujourd'hui",
    es: "Devolución hoy",
    en: "Due today",
    it: "Restituzione oggi",
    de: "Rückgabe heute"
  },
  "rem.today.body": {
    "pt-BR": "Sua devolução é hoje",
    fr: "Ton retour est prévu aujourd'hui",
    es: "Tu devolución es hoy",
    en: "Your return is due today",
    it: "La tua restituzione è oggi",
    de: "Deine Rückgabe ist heute fällig"
  },

  // ===== Overdue (ov.*) =====================================================
  "ov.title": {
    "pt-BR": "Aviso de atraso",
    fr: "Avis de retard",
    es: "Aviso de retraso",
    en: "Overdue notice",
    it: "Avviso di ritardo",
    de: "Überfälligkeitshinweis"
  },
  "ov.1d": {
    "pt-BR": "Empréstimo em atraso",
    fr: "Emprunt en retard",
    es: "Préstamo en retraso",
    en: "Loan overdue",
    it: "Prestito in ritardo",
    de: "Ausleihe überfällig"
  },
  "ov.1d.body": {
    "pt-BR": "Seu empréstimo está em atraso desde {date}. Por favor, providencie a devolução.",
    fr: "Ton emprunt est en retard depuis le {date}. Merci de prévoir le retour ou la prolongation.",
    es: "Tu préstamo está en retraso desde el {date}. Por favor, organiza la devolución o la renovación.",
    en: "Your loan has been overdue since {date}. Please arrange the return or a renewal.",
    it: "Il tuo prestito è in ritardo dal {date}. Per favore, organizza la restituzione o il rinnovo.",
    de: "Deine Ausleihe ist seit dem {date} überfällig. Bitte sorge für die Rückgabe oder eine Verlängerung."
  },
  "ov.7d": {
    "pt-BR": "Empréstimo com {days} dias de atraso",
    fr: "Emprunt en retard de {days} jours",
    es: "Préstamo con {days} días de retraso",
    en: "Loan {days} days overdue",
    it: "Prestito in ritardo di {days} giorni",
    de: "Ausleihe seit {days} Tagen überfällig"
  },
  "ov.7d.body": {
    "pt-BR": "Seu empréstimo está com {days} dias de atraso. Entre em contato com a biblioteca.",
    fr: "Ton emprunt est en retard de {days} jours. Contacte la bibliothèque pour trouver une solution.",
    es: "Tu préstamo está con {days} días de retraso. Contacta la biblioteca para encontrar una solución.",
    en: "Your loan is {days} days overdue. Contact the library to find a solution.",
    it: "Il tuo prestito è in ritardo di {days} giorni. Contatta la biblioteca per trovare una soluzione.",
    de: "Deine Ausleihe ist seit {days} Tagen überfällig. Kontaktiere die Bibliothek, um eine Lösung zu finden."
  },
  "ov.30d": {
    "pt-BR": "Empréstimo com {days} dias de atraso — situação grave",
    fr: "Emprunt en retard de {days} jours — situation à régulariser",
    es: "Préstamo con {days} días de retraso — situación a regularizar",
    en: "Loan {days} days overdue — situation to resolve",
    it: "Prestito in ritardo di {days} giorni — situazione da regolarizzare",
    de: "Ausleihe seit {days} Tagen überfällig — Situation zu klären"
  },
  "ov.30d.body": {
    "pt-BR": "Seu empréstimo está com {days} dias de atraso. Esta situação compromete o funcionamento da biblioteca.",
    fr: "Ton emprunt est en retard de {days} jours. Cette situation pèse sur le fonctionnement collectif de la bibliothèque. Prends contact avec la biblio pour qu'on trouve ensemble comment régulariser.",
    es: "Tu préstamo está con {days} días de retraso. Esta situación afecta el funcionamiento colectivo de la biblioteca. Toma contacto con la biblio para que encontremos juntes cómo regularizar.",
    en: "Your loan is {days} days overdue. This situation affects the collective functioning of the library. Get in touch so we can find a way forward together.",
    it: "Il tuo prestito è in ritardo di {days} giorni. Questa situazione pesa sul funzionamento collettivo della biblioteca. Mettiti in contatto con la biblio per trovare insieme una soluzione.",
    de: "Deine Ausleihe ist seit {days} Tagen überfällig. Diese Situation belastet den kollektiven Betrieb der Bibliothek. Nimm Kontakt auf, damit wir gemeinsam eine Lösung finden."
  },
  "ov.30d.admin": {
    "pt-BR": "Empréstimo com mais de 30 dias de atraso",
    fr: "Emprunt avec plus de 30 jours de retard",
    es: "Préstamo con más de 30 días de retraso",
    en: "Loan over 30 days overdue",
    it: "Prestito con oltre 30 giorni di ritardo",
    de: "Ausleihe seit über 30 Tagen überfällig"
  },

  // ===== Profile notices (prof.*) ===========================================
  "prof.restricted": {
    "pt-BR": "Cadastro com restrições",
    fr: "Compte avec restrictions",
    es: "Cuenta con restricciones",
    en: "Account with restrictions",
    it: "Account con restrizioni",
    de: "Konto mit Einschränkungen"
  },
  "prof.restricted.intro": {
    "pt-BR": "Seu cadastro foi marcado com restrições.",
    fr: "Ton compte a été marqué avec des restrictions.",
    es: "Tu cuenta fue marcada con restricciones.",
    en: "Your account has been marked with restrictions.",
    it: "Il tuo account è stato segnato con restrizioni.",
    de: "Dein Konto wurde mit Einschränkungen markiert."
  },
  "prof.contactLibrary": {
    "pt-BR": "Entre em contato com a biblioteca para regularizar sua situação.",
    fr: "Contacte la bibliothèque pour régulariser ta situation.",
    es: "Contacta la biblioteca para regularizar tu situación.",
    en: "Contact the library to resolve your situation.",
    it: "Contatta la biblioteca per regolarizzare la tua situazione.",
    de: "Kontaktiere die Bibliothek, um deine Situation zu klären."
  },
  "prof.formalNotice": {
    "pt-BR": "Aviso formal de restrição",
    fr: "Avis formel concernant la restriction",
    es: "Aviso formal sobre la restricción",
    en: "Formal notice regarding the restriction",
    it: "Avviso formale relativo alla restrizione",
    de: "Formelle Mitteilung zur Einschränkung"
  },
  "prof.formalNotice.intro": {
    "pt-BR": "Esta mensagem é um aviso formal sobre a restrição d(o/a/e) seu cadastro.",
    fr: "Ce message est un avis formel concernant la restriction de ton compte.",
    es: "Este mensaje es un aviso formal sobre la restricción de tu cuenta.",
    en: "This message is a formal notice regarding the restriction on your account.",
    it: "Questo messaggio è un avviso formale relativo alla restrizione del tuo account.",
    de: "Diese Nachricht ist eine formelle Mitteilung zur Einschränkung deines Kontos."
  },

  // ===== Pickup reply (pr.*) — admin-only mais traduit pour cohérence ======
  "pr.readerReply": {
    "pt-BR": "Resposta d(o/a/e) leitor(a/e) sobre a retirada",
    fr: "Réponse du·de la lecteur·rice sur le retrait",
    es: "Respuesta de le lector(a/e) sobre el retiro",
    en: "Reader reply about pickup",
    it: "Risposta del/la lettore/trice sul ritiro",
    de: "Antwort der*des Leser*in zur Abholung"
  },
  "pr.confirmed": {
    "pt-BR": "Leitor(a/e) confirmou o horário de retirada",
    fr: "Le·la lecteur·rice a confirmé l'horaire de retrait",
    es: "Le lector(a/e) confirmó el horario de retiro",
    en: "Reader confirmed the pickup time",
    it: "Il/la lettore/trice ha confermato l'orario di ritiro",
    de: "Leser*in hat den Abholzeitpunkt bestätigt"
  },
  "pr.declined": {
    "pt-BR": "Leitor(a/e) não pode no horário proposto",
    fr: "Le·la lecteur·rice ne peut pas à l'horaire proposé",
    es: "Le lector(a/e) no puede en el horario propuesto",
    en: "Reader can't make the proposed time",
    it: "Il/la lettore/trice non può all'orario proposto",
    de: "Leser*in kann zum vorgeschlagenen Zeitpunkt nicht"
  },

  // ===== Admin subjects (admin.*) ===========================================
  "admin.newLoan": {
    "pt-BR": "Novo empréstimo registrado",
    fr: "Nouvel emprunt enregistré",
    es: "Nuevo préstamo registrado",
    en: "New loan registered",
    it: "Nuovo prestito registrato",
    de: "Neue Ausleihe registriert"
  },
  "admin.renewalDone": {
    "pt-BR": "Prorrogação registrada",
    fr: "Prolongation enregistrée",
    es: "Renovación registrada",
    en: "Renewal recorded",
    it: "Rinnovo registrato",
    de: "Verlängerung registriert"
  },
  "admin.returnDone": {
    "pt-BR": "Devolução registrada",
    fr: "Retour enregistré",
    es: "Devolución registrada",
    en: "Return recorded",
    it: "Restituzione registrata",
    de: "Rückgabe registriert"
  },
  "admin.returnUpdate": {
    "pt-BR": "Atualização sobre devolução",
    fr: "Mise à jour sur un retour",
    es: "Actualización sobre devolución",
    en: "Return update",
    it: "Aggiornamento su una restituzione",
    de: "Aktualisierung zu einer Rückgabe"
  },
  "admin.loanUpdate": {
    "pt-BR": "Atualização d(o/a/e) empréstimo",
    fr: "Mise à jour de l'emprunt",
    es: "Actualización del préstamo",
    en: "Loan update",
    it: "Aggiornamento del prestito",
    de: "Aktualisierung der Ausleihe"
  },
  "admin.resUpdate": {
    "pt-BR": "Atualização da reserva",
    fr: "Mise à jour de la réservation",
    es: "Actualización de la reserva",
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

  // ===== Task statuses (ts.*) — usage Painel internal tasks =================
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
    fr: "À faire",
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
    "pt-BR": "Concluída",
    fr: "Terminée",
    es: "Completada",
    en: "Completed",
    it: "Completata",
    de: "Abgeschlossen"
  },
  "ts.cancelada": {
    "pt-BR": "Cancelada",
    fr: "Annulée",
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
    "pt-BR": "Média",
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

  // ===== Team — Rôles dynamiques (team.role.*) ==============================
  "team.role.librarian": {
    "pt-BR": "bibliotecári(o/a/e)",
    fr: "bibliothécaire",
    es: "bibliotecarie",
    en: "librarian",
    it: "bibliotecario/a/e",
    de: "Bibliothekar*in"
  },
  "team.role.coordenador": {
    "pt-BR": "coordenador(o/a/e)",
    fr: "coordinateur·rice",
    es: "coordinadore",
    en: "coordinator",
    it: "coordinatore/trice/e",
    de: "Koordinator*in"
  },

  // ===== Team — Admissions concertées (team.promoted_*) =====================
  "team.promoted_to_librarian.sub": {
    "pt-BR": "Você foi admitid(o/a/e) bibliotecári(o/a/e)",
    fr: "Tu as été admis·e bibliothécaire",
    es: "Fuiste admitide bibliotecarie",
    en: "You have been admitted as a librarian",
    it: "Sei stato/a/e ammesso/a/e come bibliotecario/a/e",
    de: "Du wurdest als Bibliothekar*in aufgenommen"
  },
  "team.promoted_to_librarian.intro": {
    "pt-BR": "Você acaba de ser admitid(o/a/e) bibliotecári(o/a/e) na {libraryName} de maneira concertada pela equipe de animação da biblioteca. Seja bem-vind(o/a/e)!",
    fr: "Tu viens d'être admis·e bibliothécaire à la {libraryName} de manière concertée par l'équipe d'animation de la bibliothèque. Bienvenue !",
    es: "Acabás de ser admitide bibliotecarie en le {libraryName} de manera concertada por le equipo de animación de la biblioteca. ¡Bienvenide!",
    en: "You have just been admitted as a librarian at {libraryName} through a concerted decision by the library's animation team. Welcome!",
    it: "Sei appena stato/a/e ammesso/a/e come bibliotecario/a/e a {libraryName} in modo concertato dall'equipe di animazione della biblioteca. Benvenuto/a/e!",
    de: "Du bist soeben als Bibliothekar*in bei {libraryName} in Abstimmung mit dem Animationsteam der Bibliothek aufgenommen worden. Willkommen!"
  },
  "team.promoted_to_coordenador.sub": {
    "pt-BR": "Você foi admitid(o/a/e) coordenador(o/a/e)",
    fr: "Tu as été admis·e coordinateur·rice",
    es: "Fuiste admitide coordinadore",
    en: "You have been admitted as a coordinator",
    it: "Sei stato/a/e ammesso/a/e come coordinatore/trice/e",
    de: "Du wurdest als Koordinator*in aufgenommen"
  },
  "team.promoted_to_coordenador.intro": {
    "pt-BR": "Você acaba de ser admitid(o/a/e) coordenador(o/a/e) na {libraryName} de maneira concertada. Você junta-se ao círculo de coordenação. Suas responsabilidades se ampliam: governança da equipe, validações sensíveis. O regimento interno está aqui: {regimentoUrl}",
    fr: "Tu viens d'être admis·e coordinateur·rice à la {libraryName} de manière concertée. Tu rejoins le cercle de coordination. Tes responsabilités s'élargissent : gouvernance de l'équipe, validations sensibles. Le règlement intérieur est ici : {regimentoUrl}",
    es: "Acabás de ser admitide coordinadore en le {libraryName} de manera concertada. Te sumás al círculo de coordinación. Tus responsabilidades se amplían: gobernanza de le equipo, validaciones sensibles. El reglamento interno está acá: {regimentoUrl}",
    en: "You have just been admitted as a coordinator at {libraryName} through a concerted decision. You join the coordination circle. Your responsibilities expand: team governance, sensitive validations. The internal rules are here: {regimentoUrl}",
    it: "Sei appena stato/a/e ammesso/a/e come coordinatore/trice/e a {libraryName} in modo concertato. Entri nel cerchio di coordinamento. Le tue responsabilità si ampliano: governance dell'equipe, validazioni sensibili. Il regolamento interno è qui: {regimentoUrl}",
    de: "Du bist soeben als Koordinator*in bei {libraryName} in Abstimmung aufgenommen worden. Du trittst dem Koordinationskreis bei. Deine Verantwortungen erweitern sich: Governance des Teams, sensible Validierungen. Die interne Geschäftsordnung findest du hier: {regimentoUrl}"
  },

  // ===== Team — Retour volontaire à un autre rôle (team.self_demoted) =======
  "team.self_demoted.sub": {
    "pt-BR": "{actorName} retornou ao papel de {toRole}",
    fr: "{actorName} est revenu·e au rôle de {toRole}",
    es: "{actorName} volvió al rol de {toRole}",
    en: "{actorName} has returned to the {toRole} role",
    it: "{actorName} è tornato/a/e al ruolo di {toRole}",
    de: "{actorName} ist zur Rolle {toRole} zurückgekehrt"
  },
  "team.self_demoted.intro": {
    "pt-BR": "{actorName} retornou do papel de {fromRole} ao papel de {toRole} na {libraryName}. Esta decisão é voluntária e imediata.",
    fr: "{actorName} est revenu·e du rôle de {fromRole} au rôle de {toRole} à la {libraryName}. Cette décision est volontaire et immédiate.",
    es: "{actorName} volvió de le rol de {fromRole} al rol de {toRole} en le {libraryName}. Esta decisión es voluntaria e inmediata.",
    en: "{actorName} has returned from the {fromRole} role to the {toRole} role at {libraryName}. This decision is voluntary and effective immediately.",
    it: "{actorName} è tornato/a/e dal ruolo di {fromRole} al ruolo di {toRole} a {libraryName}. Questa decisione è volontaria e immediata.",
    de: "{actorName} ist von der Rolle {fromRole} zur Rolle {toRole} bei {libraryName} zurückgekehrt. Diese Entscheidung ist freiwillig und sofort wirksam."
  },

  // ===== Team — Demande de retrait avec carence 7j (team.removal_*) =========
  "team.removal_requested.sub": {
    "pt-BR": "Pedido de retirada concernente a você",
    fr: "Demande de retrait te concernant",
    es: "Solicitud de retiro que te concierne",
    en: "Removal request concerning you",
    it: "Richiesta di rimozione che ti riguarda",
    de: "Antrag auf Entzug, der dich betrifft"
  },
  "team.removal_requested.intro": {
    "pt-BR": "Um pedido de retirada do papel de {role} concernente a você foi depositado na {libraryName}. Este pedido está submetido a um prazo de 7 dias durante o qual você pode trocar com outr(o/a/e)s coordenador(o/a/e)s para compreender ou contestar esta decisão. Sem anulação da parte del(e/a/e)s antes de {pendingUntilDate}, seu papel de {role} será retirado.",
    fr: "Une demande de retrait du rôle de {role} te concernant a été déposée à la {libraryName}. Cette demande est soumise à un délai de 7 jours pendant lequel tu peux échanger avec les autres coordinateur·rices pour comprendre ou contester cette décision. Sans annulation de leur part avant le {pendingUntilDate}, ton rôle de {role} sera retiré.",
    es: "Une solicitud de retiro de le rol de {role} que te concierne fue depositada en le {libraryName}. Esta solicitud está sometida a un plazo de 7 días durante el cual podés intercambiar con les otres coordinadores para comprender o contestar esta decisión. Sin anulación de su parte antes de le {pendingUntilDate}, tu rol de {role} será retirado.",
    en: "A request to remove your {role} role at {libraryName} has been filed. This request is subject to a 7-day waiting period during which you may discuss with the other coordinators to understand or contest this decision. Without cancellation on their part before {pendingUntilDate}, your {role} role will be removed.",
    it: "Una richiesta di rimozione dal ruolo di {role} che ti riguarda è stata depositata a {libraryName}. Questa richiesta è soggetta a un termine di 7 giorni durante il quale puoi confrontarti con le altre coordinatrici e gli altri coordinatori per comprendere o contestare questa decisione. Senza annullamento da parte loro entro il {pendingUntilDate}, il tuo ruolo di {role} sarà rimosso.",
    de: "Ein Antrag auf Entzug der Rolle {role}, der dich betrifft, wurde bei {libraryName} eingereicht. Dieser Antrag unterliegt einer Frist von 7 Tagen, während der du dich mit den anderen Koordinator*innen austauschen kannst, um diese Entscheidung zu verstehen oder anzufechten. Ohne Annullierung ihrerseits vor dem {pendingUntilDate} wird deine Rolle als {role} entzogen."
  },
  "team.removal_cancelled.sub": {
    "pt-BR": "O pedido de retirada concernente a você foi anulado",
    fr: "La demande de retrait te concernant a été annulée",
    es: "La solicitud de retiro que te concierne fue anulada",
    en: "The removal request concerning you has been cancelled",
    it: "La richiesta di rimozione che ti riguarda è stata annullata",
    de: "Der Antrag auf Entzug, der dich betraf, wurde annulliert"
  },
  "team.removal_cancelled.intro": {
    "pt-BR": "O pedido de retirada concernente a você na {libraryName} foi anulado por {cancellerName}. Você recupera todos os seus direitos de {role} imediatamente.",
    fr: "La demande de retrait te concernant à la {libraryName} a été annulée par {cancellerName}. Tu retrouves tous tes droits de {role} immédiatement.",
    es: "La solicitud de retiro que te concierne en le {libraryName} fue anulada por {cancellerName}. Recuperás todos tus derechos de {role} inmediatamente.",
    en: "The removal request concerning you at {libraryName} has been cancelled by {cancellerName}. You immediately regain all your {role} rights.",
    it: "La richiesta di rimozione che ti riguarda a {libraryName} è stata annullata da {cancellerName}. Recuperi immediatamente tutti i tuoi diritti di {role}.",
    de: "Der Antrag auf Entzug, der dich bei {libraryName} betraf, wurde von {cancellerName} annulliert. Du erhältst sofort alle deine Rechte als {role} zurück."
  },
  "team.removal_completed.sub": {
    "pt-BR": "Sua retirada do papel de {role} foi finalizada",
    fr: "Ton retrait du rôle de {role} a été finalisé",
    es: "Tu retiro de le rol de {role} fue finalizado",
    en: "Your removal from the {role} role has been finalised",
    it: "La tua rimozione dal ruolo di {role} è stata finalizzata",
    de: "Dein Entzug der Rolle {role} wurde abgeschlossen"
  },
  "team.removal_completed.intro": {
    "pt-BR": "O prazo de 7 dias decorreu sem anulação. Seu papel de {role} na {libraryName} foi retirado. Se você deseja compreender esta decisão ou discuti-la, entre em contato com (o/a/e)s coordenador(o/a/e)s.",
    fr: "Le délai de 7 jours s'est écoulé sans annulation. Ton rôle de {role} à la {libraryName} a été retiré. Si tu souhaites comprendre cette décision ou en discuter, contacte les coordinateur·rices.",
    es: "El plazo de 7 días transcurrió sin anulación. Tu rol de {role} en le {libraryName} fue retirado. Si querés comprender esta decisión o discutirla, contactá a les coordinadores.",
    en: "The 7-day period has elapsed without cancellation. Your {role} role at {libraryName} has been removed. If you wish to understand this decision or discuss it, contact the coordinators.",
    it: "Il termine di 7 giorni è trascorso senza annullamento. Il tuo ruolo di {role} a {libraryName} è stato rimosso. Se desideri comprendere questa decisione o discuterne, contatta le coordinatrici e i coordinatori.",
    de: "Die Frist von 7 Tagen ist ohne Annullierung verstrichen. Deine Rolle als {role} bei {libraryName} wurde entzogen. Wenn du diese Entscheidung verstehen oder besprechen möchtest, wende dich an die Koordinator*innen."
  },

  // ===== Team — Suspension immédiate (team.suspended_*) =====================
  "team.suspended.sub": {
    "pt-BR": "Suspensão imediata dos seus direitos de {role}",
    fr: "Suspension immédiate de tes droits de {role}",
    es: "Suspensión inmediata de tus derechos de {role}",
    en: "Immediate suspension of your {role} rights",
    it: "Sospensione immediata dei tuoi diritti di {role}",
    de: "Sofortige Aussetzung deiner {role}-Rechte"
  },
  "team.suspended.intro": {
    "pt-BR": "Seus direitos de {role} na {libraryName} foram suspensos por medida cautelar. Motivo comunicado: {reason}. Para compreender ou contestar esta decisão, entre em contato com (o/a/e)s coordenador(o/a/e)s o mais rápido possível.",
    fr: "Tes droits de {role} à la {libraryName} ont été suspendus par mesure conservatoire. Motif communiqué : {reason}. Pour comprendre ou contester cette décision, contacte les coordinateur·rices au plus vite.",
    es: "Tus derechos de {role} en le {libraryName} fueron suspendidos por medida cautelar. Motivo comunicado: {reason}. Para comprender o contestar esta decisión, contactá a les coordinadores lo antes posible.",
    en: "Your {role} rights at {libraryName} have been suspended as a precautionary measure. Communicated reason: {reason}. To understand or contest this decision, contact the coordinators as soon as possible.",
    it: "I tuoi diritti di {role} a {libraryName} sono stati sospesi come misura cautelare. Motivo comunicato: {reason}. Per comprendere o contestare questa decisione, contatta le coordinatrici e i coordinatori il prima possibile.",
    de: "Deine {role}-Rechte bei {libraryName} wurden als vorsorgliche Maßnahme ausgesetzt. Mitgeteilter Grund: {reason}. Um diese Entscheidung zu verstehen oder anzufechten, wende dich so schnell wie möglich an die Koordinator*innen."
  },
  "team.unsuspended.sub": {
    "pt-BR": "Levantamento da sua suspensão",
    fr: "Levée de ta suspension",
    es: "Levantamiento de tu suspensión",
    en: "Lifting of your suspension",
    it: "Revoca della tua sospensione",
    de: "Aufhebung deiner Aussetzung"
  },
  "team.unsuspended.intro": {
    "pt-BR": "A suspensão dos seus direitos de {role} na {libraryName} foi levantada por {actorName}. Você recupera imediatamente seus acessos.",
    fr: "La suspension de tes droits de {role} à la {libraryName} a été levée par {actorName}. Tu retrouves immédiatement tes accès.",
    es: "La suspensión de tus derechos de {role} en le {libraryName} fue levantada por {actorName}. Recuperás inmediatamente tus accesos.",
    en: "The suspension of your {role} rights at {libraryName} has been lifted by {actorName}. You immediately regain your access.",
    it: "La sospensione dei tuoi diritti di {role} a {libraryName} è stata revocata da {actorName}. Recuperi immediatamente i tuoi accessi.",
    de: "Die Aussetzung deiner {role}-Rechte bei {libraryName} wurde von {actorName} aufgehoben. Du erhältst sofort deinen Zugang zurück."
  },

  // ===== Team — Escalades aux administrateur·rices AnarBib (team.last_*) ====
  "team.last_coordinator_left.sub": {
    "pt-BR": "{libraryName} não tem mais coordenador(o/a/e)",
    fr: "{libraryName} n'a plus de coordinateur·rice",
    es: "{libraryName} ya no tiene coordinadore",
    en: "{libraryName} no longer has a coordinator",
    it: "{libraryName} non ha più coordinatori/trici/e",
    de: "{libraryName} hat keine Koordinator*in mehr"
  },
  "team.last_coordinator_left.intro": {
    "pt-BR": "A biblioteca {libraryName} encontra-se sem coordenador(o/a/e) ativ(o/a/e). {actorName} acaba de retornar a um papel não-coordenador, e ninguém mais ocupa o papel. A biblioteca permanece funcional tecnicamente (os bibliotecári(o/a/e)s podem continuar a operar) mas não tem mais instância de coordenação interna. Uma intervenção política da rede AnarBib é provavelmente necessária.",
    fr: "La bibliothèque {libraryName} se retrouve sans coordinateur·rice actif·ve. {actorName} vient de revenir à un rôle non-coordinateur, et personne d'autre n'occupe le rôle. La bibliothèque reste fonctionnelle techniquement (les bibliothécaires peuvent toujours opérer) mais n'a plus d'instance de coordination interne. Une intervention politique du réseau AnarBib est probablement nécessaire.",
    es: "La biblioteca {libraryName} se encuentra sin coordinadore active. {actorName} acaba de volver a un rol no-coordinadore, y nadie más ocupa el rol. La biblioteca permanece funcional técnicamente (les bibliotecaries pueden seguir operando) pero ya no tiene instancia de coordinación interna. Una intervención política de le red AnarBib es probablemente necesaria.",
    en: "The {libraryName} library finds itself without an active coordinator. {actorName} has just returned to a non-coordinator role, and no one else holds the position. The library remains technically functional (librarians can still operate) but no longer has an internal coordination body. A political intervention from the AnarBib network is likely necessary.",
    it: "La biblioteca {libraryName} si ritrova senza coordinatori/trici/e attivi/e. {actorName} è appena tornato/a/e a un ruolo non-coordinatore, e nessun'altra persona occupa il ruolo. La biblioteca rimane funzionale tecnicamente (le bibliotecarie e i bibliotecari possono continuare a operare) ma non ha più un'istanza di coordinamento interna. Un intervento politico della rete AnarBib è probabilmente necessario.",
    de: "Die Bibliothek {libraryName} steht ohne aktive Koordinator*in da. {actorName} ist soeben zu einer Nicht-Koordinator*innen-Rolle zurückgekehrt, und niemand sonst nimmt die Rolle wahr. Die Bibliothek bleibt technisch funktionsfähig (die Bibliothekar*innen können weiter arbeiten), hat aber keine interne Koordinationsinstanz mehr. Eine politische Intervention des AnarBib-Netzwerks ist wahrscheinlich notwendig."
  },
  "team.last_coordinator_pending_removal.sub": {
    "pt-BR": "{libraryName} corre risco de ficar sem coordenador(o/a/e)",
    fr: "{libraryName} risque de se retrouver sans coordinateur·rice",
    es: "{libraryName} corre el riesgo de quedarse sin coordinadore",
    en: "{libraryName} risks finding itself without a coordinator",
    it: "{libraryName} rischia di ritrovarsi senza coordinatori/trici/e",
    de: "{libraryName} läuft Gefahr, ohne Koordinator*in dazustehen"
  },
  "team.last_coordinator_pending_removal.intro": {
    "pt-BR": "A biblioteca {libraryName} não terá mais coordenador(o/a/e) ativ(o/a/e) a partir de {pendingUntilDate} se o pedido de retirada em curso não for anulado. {actorName} pediu a retirada d(o/a/e) últim(o/a/e) coordenador(o/a/e) ativ(o/a/e) da biblioteca. Você pode observar a situação, ou intervir politicamente se necessário.",
    fr: "La bibliothèque {libraryName} aura plus de coordinateur·rice actif·ve à partir du {pendingUntilDate} si la demande de retrait en cours n'est pas annulée. {actorName} a demandé le retrait de la dernière coordinateur·rice actif·ve de la bibliothèque. Tu peux observer la situation, ou intervenir politiquement si nécessaire.",
    es: "La biblioteca {libraryName} ya no tendrá coordinadore active a partir de le {pendingUntilDate} si la solicitud de retiro en curso no es anulada. {actorName} solicitó el retiro de le última coordinadore active de la biblioteca. Podés observar la situación, o intervenir políticamente si es necesario.",
    en: "The {libraryName} library will have no active coordinator from {pendingUntilDate} onwards if the pending removal request is not cancelled. {actorName} requested the removal of the last active coordinator at the library. You may observe the situation, or intervene politically if necessary.",
    it: "La biblioteca {libraryName} non avrà più coordinatori/trici/e attivi/e a partire dal {pendingUntilDate} se la richiesta di rimozione in corso non viene annullata. {actorName} ha richiesto la rimozione dell'ultim(o/a/e) coordinator(e/trice/e) attiv(o/a/e) della biblioteca. Puoi osservare la situazione, o intervenire politicamente se necessario.",
    de: "Die Bibliothek {libraryName} wird ab dem {pendingUntilDate} keine aktive Koordinator*in mehr haben, falls der laufende Antrag auf Entzug nicht annulliert wird. {actorName} hat den Entzug der letzten aktiven Koordinator*in der Bibliothek beantragt. Du kannst die Situation beobachten oder politisch intervenieren, falls notwendig."
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
    de: "Dein Konto wird in 30 Tagen inaktiv"
  },
  "team.inactive_warning_30d.intro": {
    "pt-BR": "Você não se conectou em AnarBib há 8 meses. Sem conexão da sua parte nos próximos 30 dias, seu status de {role} na {libraryName} passará automaticamente a inativo. Para conservar seus acessos, conecte-se simplesmente a AnarBib antes de {deadlineDate}.",
    fr: "Tu ne t'es pas connecté·e sur AnarBib depuis 8 mois. Sans connexion de ta part dans les 30 prochains jours, ton statut de {role} à la {libraryName} passera automatiquement en inactif. Pour conserver tes accès, connecte-toi simplement à AnarBib avant le {deadlineDate}.",
    es: "No te conectaste a AnarBib desde hace 8 meses. Sin conexión de tu parte en los próximos 30 días, tu estatus de {role} en le {libraryName} pasará automáticamente a inactivo. Para conservar tus accesos, conectate simplemente a AnarBib antes de le {deadlineDate}.",
    en: "You have not signed in to AnarBib for 8 months. Without a connection on your part within the next 30 days, your {role} status at {libraryName} will automatically become inactive. To keep your access, simply log in to AnarBib before {deadlineDate}.",
    it: "Non ti sei connesso/a/e ad AnarBib da 8 mesi. Senza una connessione da parte tua nei prossimi 30 giorni, il tuo status di {role} a {libraryName} passerà automaticamente a inattivo. Per conservare i tuoi accessi, connettiti semplicemente ad AnarBib prima del {deadlineDate}.",
    de: "Du hast dich seit 8 Monaten nicht mehr bei AnarBib angemeldet. Ohne Anmeldung deinerseits in den nächsten 30 Tagen wird dein Status als {role} bei {libraryName} automatisch auf inaktiv gesetzt. Um deinen Zugang zu behalten, melde dich einfach bei AnarBib vor dem {deadlineDate} an."
  },
  "team.inactive_warning_7d.sub": {
    "pt-BR": "Último lembrete: sua conta passa a inativa em 7 dias",
    fr: "Dernier rappel : ton compte passe en inactif dans 7 jours",
    es: "Último recordatorio: tu cuenta pasa a inactiva en 7 días",
    en: "Last reminder: your account becomes inactive in 7 days",
    it: "Ultimo promemoria: il tuo account passa a inattivo tra 7 giorni",
    de: "Letzte Erinnerung: Dein Konto wird in 7 Tagen inaktiv"
  },
  "team.inactive_warning_7d.intro": {
    "pt-BR": "Sem conexão da sua parte nos próximos 7 dias, seu status de {role} na {libraryName} passará automaticamente a inativo em {deadlineDate}.",
    fr: "Sans connexion de ta part dans les 7 prochains jours, ton statut de {role} à la {libraryName} passera automatiquement en inactif le {deadlineDate}.",
    es: "Sin conexión de tu parte en los próximos 7 días, tu estatus de {role} en le {libraryName} pasará automáticamente a inactivo el {deadlineDate}.",
    en: "Without a connection on your part within the next 7 days, your {role} status at {libraryName} will automatically become inactive on {deadlineDate}.",
    it: "Senza una connessione da parte tua nei prossimi 7 giorni, il tuo status di {role} a {libraryName} passerà automaticamente a inattivo il {deadlineDate}.",
    de: "Ohne Anmeldung deinerseits in den nächsten 7 Tagen wird dein Status als {role} bei {libraryName} am {deadlineDate} automatisch auf inaktiv gesetzt."
  },
  "team.inactive_completed.sub": {
    "pt-BR": "Sua conta passou a inativa",
    fr: "Ton compte est passé en inactif",
    es: "Tu cuenta pasó a inactiva",
    en: "Your account has become inactive",
    it: "Il tuo account è passato a inattivo",
    de: "Dein Konto ist inaktiv geworden"
  },
  "team.inactive_completed.intro": {
    "pt-BR": "Após 9 meses sem conexão, seu status de {role} na {libraryName} passou a inativo. Seus acessos estão fechados. Se você desejar recuperá-los, entre em contato com (o/a/e)s coordenador(o/a/e)s da biblioteca para uma reativação.",
    fr: "Après 9 mois sans connexion, ton statut de {role} à la {libraryName} est passé en inactif. Tes accès sont fermés. Si tu souhaites les retrouver, contacte les coordinateur·rices de la bibliothèque pour une réactivation.",
    es: "Después de 9 meses sin conexión, tu estatus de {role} en le {libraryName} pasó a inactivo. Tus accesos están cerrados. Si querés recuperarlos, contactá a les coordinadores de la biblioteca para una reactivación.",
    en: "After 9 months without a connection, your {role} status at {libraryName} has become inactive. Your access is closed. If you wish to regain it, contact the library coordinators for a reactivation.",
    it: "Dopo 9 mesi senza connessione, il tuo status di {role} a {libraryName} è passato a inattivo. I tuoi accessi sono chiusi. Se desideri recuperarli, contatta le coordinatrici e i coordinatori della biblioteca per una riattivazione.",
    de: "Nach 9 Monaten ohne Anmeldung ist dein Status als {role} bei {libraryName} auf inaktiv gesetzt worden. Dein Zugang ist geschlossen. Wenn du ihn zurückerhalten möchtest, wende dich an die Koordinator*innen der Bibliothek für eine Reaktivierung."
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
  return ["pt-BR", "fr", "es", "en", "it", "de"];
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
