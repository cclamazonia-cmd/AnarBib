// _shared/i18n/task-mail-strings.ts
// i18n des libellés pour les mails de tâches internes (notify-internal-task).
// 9 locales (pt-BR, fr, es, en, it, de, ca, eo, nl), repli pt-BR.
// Ecriture inclusive selon la convention de chaque langue.
// Patron : table par locale + helpers (tMail-like). Aucune dependance externe.

const TASK_STRINGS = {
  "pt-BR": {
    status: {
      aberta: "Aberta",
      a_fazer: "A fazer",
      em_andamento: "Em andamento",
      bloqueada: "Bloqueada",
      concluida: "Concluída",
      cancelada: "Cancelada",
      arquivada: "Arquivada"
    },
    priority: { alta: "Alta", media: "Média", baixa: "Baixa", urgente: "Urgente" },
    label: {
      tarefa: "Tarefa",
      prioridade: "Prioridade",
      situacao: "Situação",
      prazo: "Prazo",
      marcadores: "Marcadores",
      descricao: "Descrição",
      organizacao: "Organização",
      mudancas: "Mudanças importantes"
    },
    greetingPlain: "Olá!",
    greetingNamed: "Olá, {name}!",
    untitled: "tarefa sem título",
    fallbackName: "compa",
    assigned: {
      subject: "Nova tarefa interna",
      title: "Nova tarefa interna",
      introHtml: `<p style="margin:0 0 10px;">Tu recebeste uma <b>nova tarefa interna</b>.</p><p style="margin:0;">Consulta o painel para acompanhar o andamento e registrar qualquer atualização necessária.</p>`
    },
    reminder: {
      subject: "Lembrete de tarefa interna",
      title: "Lembrete de tarefa interna",
      introHtml: `<p style="margin:0 0 10px;">Esta tarefa entrou no bloco <b>Trabalho do dia</b>.</p><p style="margin:0;">Se ela já foi resolvida, vale atualizar o status no painel.</p>`
    },
    orgCreated: {
      subject: "Nova tarefa interna sob tua responsabilidade",
      title: "Nova tarefa interna",
      introHtml: `<p style="margin:0 0 10px;">Uma <b>nova tarefa interna</b> foi registrada sob tua responsabilidade.</p><p style="margin:0;">Abre o painel da biblioteca para acompanhar o andamento e organizar os próximos passos.</p>`
    },
    orgUpdated: {
      subject: "Atualização importante em tarefa interna",
      title: "Atualização importante em tarefa interna",
      introHtml: `<p style="margin:0 0 10px;">Uma tarefa interna sob tua responsabilidade recebeu uma <b>atualização importante</b>.</p><p style="margin:0;">Confere o painel da biblioteca para validar a nova situação e ajustar o acompanhamento.</p>`
    },
    libCreated: {
      subject: "Nova tarefa interna registrada",
      title: "Nova tarefa interna registrada",
      introHtml: `<p style="margin:0 0 10px;">Uma <b>nova tarefa interna</b> foi registrada para esta biblioteca.</p><p style="margin:0;">Este aviso é informativo e fica separado dos convites individuais enviados aos compas convidades.</p>`
    },
    libUpdated: {
      subject: "Atualização importante em tarefa da biblioteca",
      title: "Atualização importante em tarefa da biblioteca",
      introHtml: `<p style="margin:0 0 10px;">Uma tarefa interna da biblioteca recebeu uma <b>atualização importante</b>.</p><p style="margin:0;">Este aviso ajuda a acompanhar mudanças centrais sem depender dos convites individuais.</p>`
    },
    invitation: {
      subject: "Convite para tarefa interna",
      title: "Convite para tarefa interna",
      introHtml: `<p style="margin:0 0 10px;">Tu recebeste um <b>convite para participar de uma tarefa interna</b> da biblioteca.</p><p style="margin:0;">Se fizer sentido para ti, abre o painel da biblioteca para acompanhar a organização desta tarefa.</p>`
    }
  },

  "fr": {
    status: {
      aberta: "Ouverte",
      a_fazer: "À faire",
      em_andamento: "En cours",
      bloqueada: "Bloquée",
      concluida: "Terminée",
      cancelada: "Annulée",
      arquivada: "Archivée"
    },
    priority: { alta: "Haute", media: "Moyenne", baixa: "Basse", urgente: "Urgente" },
    label: {
      tarefa: "Tâche",
      prioridade: "Priorité",
      situacao: "Statut",
      prazo: "Échéance",
      marcadores: "Étiquettes",
      descricao: "Description",
      organizacao: "Responsable",
      mudancas: "Changements importants"
    },
    greetingPlain: "Salut !",
    greetingNamed: "Salut {name} !",
    untitled: "tâche sans titre",
    fallbackName: "camarade",
    assigned: {
      subject: "Nouvelle tâche interne",
      title: "Nouvelle tâche interne",
      introHtml: `<p style="margin:0 0 10px;">Tu as reçu une <b>nouvelle tâche interne</b>.</p><p style="margin:0;">Consulte le panneau pour suivre son avancement et noter toute mise à jour nécessaire.</p>`
    },
    reminder: {
      subject: "Rappel de tâche interne",
      title: "Rappel de tâche interne",
      introHtml: `<p style="margin:0 0 10px;">Cette tâche est entrée dans le bloc <b>Travail du jour</b>.</p><p style="margin:0;">Si elle est déjà réglée, pense à mettre à jour son statut dans le panneau.</p>`
    },
    orgCreated: {
      subject: "Nouvelle tâche interne sous ta responsabilité",
      title: "Nouvelle tâche interne",
      introHtml: `<p style="margin:0 0 10px;">Une <b>nouvelle tâche interne</b> a été enregistrée sous ta responsabilité.</p><p style="margin:0;">Ouvre le panneau de la bibliothèque pour suivre son avancement et organiser les prochaines étapes.</p>`
    },
    orgUpdated: {
      subject: "Mise à jour importante sur une tâche interne",
      title: "Mise à jour importante sur une tâche interne",
      introHtml: `<p style="margin:0 0 10px;">Une tâche interne sous ta responsabilité a reçu une <b>mise à jour importante</b>.</p><p style="margin:0;">Vérifie le panneau de la bibliothèque pour valider la nouvelle situation et ajuster le suivi.</p>`
    },
    libCreated: {
      subject: "Nouvelle tâche interne enregistrée",
      title: "Nouvelle tâche interne enregistrée",
      introHtml: `<p style="margin:0 0 10px;">Une <b>nouvelle tâche interne</b> a été enregistrée pour cette bibliothèque.</p><p style="margin:0;">Cet avis est informatif et reste distinct des invitations individuelles envoyées aux camarades invité·es.</p>`
    },
    libUpdated: {
      subject: "Mise à jour importante sur une tâche de la bibliothèque",
      title: "Mise à jour importante sur une tâche de la bibliothèque",
      introHtml: `<p style="margin:0 0 10px;">Une tâche interne de la bibliothèque a reçu une <b>mise à jour importante</b>.</p><p style="margin:0;">Cet avis aide à suivre les changements centraux sans dépendre des invitations individuelles.</p>`
    },
    invitation: {
      subject: "Invitation à une tâche interne",
      title: "Invitation à une tâche interne",
      introHtml: `<p style="margin:0 0 10px;">Tu as reçu une <b>invitation à participer à une tâche interne</b> de la bibliothèque.</p><p style="margin:0;">Si cela te convient, ouvre le panneau de la bibliothèque pour suivre l'organisation de cette tâche.</p>`
    }
  },

  "es": {
    status: {
      aberta: "Abierta",
      a_fazer: "Por hacer",
      em_andamento: "En curso",
      bloqueada: "Bloqueada",
      concluida: "Concluida",
      cancelada: "Cancelada",
      arquivada: "Archivada"
    },
    priority: { alta: "Alta", media: "Media", baixa: "Baja", urgente: "Urgente" },
    label: {
      tarefa: "Tarea",
      prioridade: "Prioridad",
      situacao: "Estado",
      prazo: "Fecha límite",
      marcadores: "Etiquetas",
      descricao: "Descripción",
      organizacao: "Responsable",
      mudancas: "Cambios importantes"
    },
    greetingPlain: "¡Hola!",
    greetingNamed: "¡Hola, {name}!",
    untitled: "tarea sin título",
    fallbackName: "compa",
    assigned: {
      subject: "Nueva tarea interna",
      title: "Nueva tarea interna",
      introHtml: `<p style="margin:0 0 10px;">Recibiste una <b>nueva tarea interna</b>.</p><p style="margin:0;">Mirá el panel para seguir su avance y registrar cualquier actualización necesaria.</p>`
    },
    reminder: {
      subject: "Recordatorio de tarea interna",
      title: "Recordatorio de tarea interna",
      introHtml: `<p style="margin:0 0 10px;">Esta tarea entró en el bloque <b>Trabajo del día</b>.</p><p style="margin:0;">Si ya está resuelta, conviene actualizar su estado en el panel.</p>`
    },
    orgCreated: {
      subject: "Nueva tarea interna a tu cargo",
      title: "Nueva tarea interna",
      introHtml: `<p style="margin:0 0 10px;">Se registró una <b>nueva tarea interna</b> a tu cargo.</p><p style="margin:0;">Abrí el panel de la biblioteca para seguir su avance y organizar los próximos pasos.</p>`
    },
    orgUpdated: {
      subject: "Actualización importante en una tarea interna",
      title: "Actualización importante en una tarea interna",
      introHtml: `<p style="margin:0 0 10px;">Una tarea interna a tu cargo recibió una <b>actualización importante</b>.</p><p style="margin:0;">Revisá el panel de la biblioteca para validar la nueva situación y ajustar el seguimiento.</p>`
    },
    libCreated: {
      subject: "Nueva tarea interna registrada",
      title: "Nueva tarea interna registrada",
      introHtml: `<p style="margin:0 0 10px;">Se registró una <b>nueva tarea interna</b> para esta biblioteca.</p><p style="margin:0;">Este aviso es informativo y queda separado de las invitaciones individuales enviadas a les compas invitades.</p>`
    },
    libUpdated: {
      subject: "Actualización importante en una tarea de la biblioteca",
      title: "Actualización importante en una tarea de la biblioteca",
      introHtml: `<p style="margin:0 0 10px;">Una tarea interna de la biblioteca recibió una <b>actualización importante</b>.</p><p style="margin:0;">Este aviso ayuda a seguir los cambios centrales sin depender de las invitaciones individuales.</p>`
    },
    invitation: {
      subject: "Invitación a una tarea interna",
      title: "Invitación a una tarea interna",
      introHtml: `<p style="margin:0 0 10px;">Recibiste una <b>invitación para participar en una tarea interna</b> de la biblioteca.</p><p style="margin:0;">Si te hace sentido, abrí el panel de la biblioteca para seguir la organización de esta tarea.</p>`
    }
  },

  "en": {
    status: {
      aberta: "Open",
      a_fazer: "To do",
      em_andamento: "In progress",
      bloqueada: "Blocked",
      concluida: "Done",
      cancelada: "Cancelled",
      arquivada: "Archived"
    },
    priority: { alta: "High", media: "Medium", baixa: "Low", urgente: "Urgent" },
    label: {
      tarefa: "Task",
      prioridade: "Priority",
      situacao: "Status",
      prazo: "Due date",
      marcadores: "Tags",
      descricao: "Description",
      organizacao: "Responsible",
      mudancas: "Key changes"
    },
    greetingPlain: "Hi!",
    greetingNamed: "Hi {name}!",
    untitled: "untitled task",
    fallbackName: "comrade",
    assigned: {
      subject: "New internal task",
      title: "New internal task",
      introHtml: `<p style="margin:0 0 10px;">You've received a <b>new internal task</b>.</p><p style="margin:0;">Check the panel to follow its progress and log any updates needed.</p>`
    },
    reminder: {
      subject: "Internal task reminder",
      title: "Internal task reminder",
      introHtml: `<p style="margin:0 0 10px;">This task has entered the <b>Day's work</b> block.</p><p style="margin:0;">If it's already handled, it's worth updating its status in the panel.</p>`
    },
    orgCreated: {
      subject: "New internal task under your responsibility",
      title: "New internal task",
      introHtml: `<p style="margin:0 0 10px;">A <b>new internal task</b> has been registered under your responsibility.</p><p style="margin:0;">Open the library panel to follow its progress and organise the next steps.</p>`
    },
    orgUpdated: {
      subject: "Important update on an internal task",
      title: "Important update on an internal task",
      introHtml: `<p style="margin:0 0 10px;">An internal task under your responsibility has received an <b>important update</b>.</p><p style="margin:0;">Check the library panel to confirm the new situation and adjust your follow-up.</p>`
    },
    libCreated: {
      subject: "New internal task registered",
      title: "New internal task registered",
      introHtml: `<p style="margin:0 0 10px;">A <b>new internal task</b> has been registered for this library.</p><p style="margin:0;">This notice is informational and stays separate from the individual invitations sent to invited comrades.</p>`
    },
    libUpdated: {
      subject: "Important update on a library task",
      title: "Important update on a library task",
      introHtml: `<p style="margin:0 0 10px;">An internal library task has received an <b>important update</b>.</p><p style="margin:0;">This notice helps track central changes without relying on individual invitations.</p>`
    },
    invitation: {
      subject: "Invitation to an internal task",
      title: "Invitation to an internal task",
      introHtml: `<p style="margin:0 0 10px;">You've received an <b>invitation to take part in an internal task</b> of the library.</p><p style="margin:0;">If it makes sense for you, open the library panel to follow how this task is organised.</p>`
    }
  },

  "it": {
    status: {
      aberta: "Aperta",
      a_fazer: "Da fare",
      em_andamento: "In corso",
      bloqueada: "Bloccata",
      concluida: "Conclusa",
      cancelada: "Annullata",
      arquivada: "Archiviata"
    },
    priority: { alta: "Alta", media: "Media", baixa: "Bassa", urgente: "Urgente" },
    label: {
      tarefa: "Attività",
      prioridade: "Priorità",
      situacao: "Stato",
      prazo: "Scadenza",
      marcadores: "Etichette",
      descricao: "Descrizione",
      organizacao: "Responsabile",
      mudancas: "Cambiamenti importanti"
    },
    greetingPlain: "Ciao!",
    greetingNamed: "Ciao {name}!",
    untitled: "attività senza titolo",
    fallbackName: "compagnə",
    assigned: {
      subject: "Nuova attività interna",
      title: "Nuova attività interna",
      introHtml: `<p style="margin:0 0 10px;">Hai ricevuto una <b>nuova attività interna</b>.</p><p style="margin:0;">Consulta il pannello per seguirne l'andamento e registrare ogni aggiornamento necessario.</p>`
    },
    reminder: {
      subject: "Promemoria di attività interna",
      title: "Promemoria di attività interna",
      introHtml: `<p style="margin:0 0 10px;">Questa attività è entrata nel blocco <b>Lavoro del giorno</b>.</p><p style="margin:0;">Se è già stata risolta, conviene aggiornarne lo stato nel pannello.</p>`
    },
    orgCreated: {
      subject: "Nuova attività interna sotto la tua responsabilità",
      title: "Nuova attività interna",
      introHtml: `<p style="margin:0 0 10px;">È stata registrata una <b>nuova attività interna</b> sotto la tua responsabilità.</p><p style="margin:0;">Apri il pannello della biblioteca per seguirne l'andamento e organizzare i prossimi passi.</p>`
    },
    orgUpdated: {
      subject: "Aggiornamento importante su un'attività interna",
      title: "Aggiornamento importante su un'attività interna",
      introHtml: `<p style="margin:0 0 10px;">Un'attività interna sotto la tua responsabilità ha ricevuto un <b>aggiornamento importante</b>.</p><p style="margin:0;">Controlla il pannello della biblioteca per validare la nuova situazione e adattare il monitoraggio.</p>`
    },
    libCreated: {
      subject: "Nuova attività interna registrata",
      title: "Nuova attività interna registrata",
      introHtml: `<p style="margin:0 0 10px;">È stata registrata una <b>nuova attività interna</b> per questa biblioteca.</p><p style="margin:0;">Questo avviso è informativo e resta separato dagli inviti individuali mandati allə compagnə invitatə.</p>`
    },
    libUpdated: {
      subject: "Aggiornamento importante su un'attività della biblioteca",
      title: "Aggiornamento importante su un'attività della biblioteca",
      introHtml: `<p style="margin:0 0 10px;">Un'attività interna della biblioteca ha ricevuto un <b>aggiornamento importante</b>.</p><p style="margin:0;">Questo avviso aiuta a seguire i cambiamenti centrali senza dipendere dagli inviti individuali.</p>`
    },
    invitation: {
      subject: "Invito a un'attività interna",
      title: "Invito a un'attività interna",
      introHtml: `<p style="margin:0 0 10px;">Hai ricevuto un <b>invito a partecipare a un'attività interna</b> della biblioteca.</p><p style="margin:0;">Se ha senso per te, apri il pannello della biblioteca per seguire l'organizzazione di questa attività.</p>`
    }
  },

  "de": {
    status: {
      aberta: "Offen",
      a_fazer: "Zu erledigen",
      em_andamento: "In Arbeit",
      bloqueada: "Blockiert",
      concluida: "Erledigt",
      cancelada: "Abgebrochen",
      arquivada: "Archiviert"
    },
    priority: { alta: "Hoch", media: "Mittel", baixa: "Niedrig", urgente: "Dringend" },
    label: {
      tarefa: "Aufgabe",
      prioridade: "Priorität",
      situacao: "Status",
      prazo: "Frist",
      marcadores: "Schlagwörter",
      descricao: "Beschreibung",
      organizacao: "Zuständig",
      mudancas: "Wichtige Änderungen"
    },
    greetingPlain: "Hallo!",
    greetingNamed: "Hallo {name}!",
    untitled: "Aufgabe ohne Titel",
    fallbackName: "Genoss*in",
    assigned: {
      subject: "Neue interne Aufgabe",
      title: "Neue interne Aufgabe",
      introHtml: `<p style="margin:0 0 10px;">Du hast eine <b>neue interne Aufgabe</b> erhalten.</p><p style="margin:0;">Schau im Panel nach, um den Fortschritt zu verfolgen und nötige Aktualisierungen einzutragen.</p>`
    },
    reminder: {
      subject: "Erinnerung an interne Aufgabe",
      title: "Erinnerung an interne Aufgabe",
      introHtml: `<p style="margin:0 0 10px;">Diese Aufgabe ist in den Block <b>Tagesarbeit</b> gerückt.</p><p style="margin:0;">Falls sie schon erledigt ist, lohnt es sich, den Status im Panel zu aktualisieren.</p>`
    },
    orgCreated: {
      subject: "Neue interne Aufgabe in deiner Verantwortung",
      title: "Neue interne Aufgabe",
      introHtml: `<p style="margin:0 0 10px;">Eine <b>neue interne Aufgabe</b> wurde in deiner Verantwortung angelegt.</p><p style="margin:0;">Öffne das Bibliotheks-Panel, um den Fortschritt zu verfolgen und die nächsten Schritte zu organisieren.</p>`
    },
    orgUpdated: {
      subject: "Wichtige Aktualisierung einer internen Aufgabe",
      title: "Wichtige Aktualisierung einer internen Aufgabe",
      introHtml: `<p style="margin:0 0 10px;">Eine interne Aufgabe in deiner Verantwortung hat eine <b>wichtige Aktualisierung</b> erhalten.</p><p style="margin:0;">Prüfe das Bibliotheks-Panel, um die neue Situation zu bestätigen und die Nachverfolgung anzupassen.</p>`
    },
    libCreated: {
      subject: "Neue interne Aufgabe angelegt",
      title: "Neue interne Aufgabe angelegt",
      introHtml: `<p style="margin:0 0 10px;">Eine <b>neue interne Aufgabe</b> wurde für diese Bibliothek angelegt.</p><p style="margin:0;">Dieser Hinweis ist informativ und bleibt getrennt von den einzelnen Einladungen an die eingeladenen Genoss*innen.</p>`
    },
    libUpdated: {
      subject: "Wichtige Aktualisierung einer Bibliotheksaufgabe",
      title: "Wichtige Aktualisierung einer Bibliotheksaufgabe",
      introHtml: `<p style="margin:0 0 10px;">Eine interne Aufgabe der Bibliothek hat eine <b>wichtige Aktualisierung</b> erhalten.</p><p style="margin:0;">Dieser Hinweis hilft, zentrale Änderungen zu verfolgen, ohne auf einzelne Einladungen angewiesen zu sein.</p>`
    },
    invitation: {
      subject: "Einladung zu einer internen Aufgabe",
      title: "Einladung zu einer internen Aufgabe",
      introHtml: `<p style="margin:0 0 10px;">Du hast eine <b>Einladung zur Mitarbeit an einer internen Aufgabe</b> der Bibliothek erhalten.</p><p style="margin:0;">Wenn es für dich passt, öffne das Bibliotheks-Panel, um die Organisation dieser Aufgabe zu verfolgen.</p>`
    }
  },

  "ca": {
    status: {
      aberta: "Oberta",
      a_fazer: "Per fer",
      em_andamento: "En curs",
      bloqueada: "Bloquejada",
      concluida: "Conclosa",
      cancelada: "Cancel·lada",
      arquivada: "Arxivada"
    },
    priority: { alta: "Alta", media: "Mitjana", baixa: "Baixa", urgente: "Urgent" },
    label: {
      tarefa: "Tasca",
      prioridade: "Prioritat",
      situacao: "Estat",
      prazo: "Termini",
      marcadores: "Etiquetes",
      descricao: "Descripció",
      organizacao: "Responsable",
      mudancas: "Canvis importants"
    },
    greetingPlain: "Hola!",
    greetingNamed: "Hola, {name}!",
    untitled: "tasca sense títol",
    fallbackName: "companya",
    assigned: {
      subject: "Nova tasca interna",
      title: "Nova tasca interna",
      introHtml: `<p style="margin:0 0 10px;">Has rebut una <b>nova tasca interna</b>.</p><p style="margin:0;">Consulta el plafó per seguir-ne l'evolució i registrar qualsevol actualització necessària.</p>`
    },
    reminder: {
      subject: "Recordatori de tasca interna",
      title: "Recordatori de tasca interna",
      introHtml: `<p style="margin:0 0 10px;">Aquesta tasca ha entrat al bloc <b>Feina del dia</b>.</p><p style="margin:0;">Si ja s'ha resolt, val la pena actualitzar-ne l'estat al plafó.</p>`
    },
    orgCreated: {
      subject: "Nova tasca interna sota la teva responsabilitat",
      title: "Nova tasca interna",
      introHtml: `<p style="margin:0 0 10px;">S'ha registrat una <b>nova tasca interna</b> sota la teva responsabilitat.</p><p style="margin:0;">Obre el plafó de la biblioteca per seguir-ne l'evolució i organitzar els propers passos.</p>`
    },
    orgUpdated: {
      subject: "Actualització important en una tasca interna",
      title: "Actualització important en una tasca interna",
      introHtml: `<p style="margin:0 0 10px;">Una tasca interna sota la teva responsabilitat ha rebut una <b>actualització important</b>.</p><p style="margin:0;">Revisa el plafó de la biblioteca per validar la nova situació i ajustar-ne el seguiment.</p>`
    },
    libCreated: {
      subject: "Nova tasca interna registrada",
      title: "Nova tasca interna registrada",
      introHtml: `<p style="margin:0 0 10px;">S'ha registrat una <b>nova tasca interna</b> per a aquesta biblioteca.</p><p style="margin:0;">Aquest avís és informatiu i queda separat de les invitacions individuals enviades a les companyes convidades.</p>`
    },
    libUpdated: {
      subject: "Actualització important en una tasca de la biblioteca",
      title: "Actualització important en una tasca de la biblioteca",
      introHtml: `<p style="margin:0 0 10px;">Una tasca interna de la biblioteca ha rebut una <b>actualització important</b>.</p><p style="margin:0;">Aquest avís ajuda a seguir els canvis centrals sense dependre de les invitacions individuals.</p>`
    },
    invitation: {
      subject: "Invitació a una tasca interna",
      title: "Invitació a una tasca interna",
      introHtml: `<p style="margin:0 0 10px;">Has rebut una <b>invitació per participar en una tasca interna</b> de la biblioteca.</p><p style="margin:0;">Si té sentit per a tu, obre el plafó de la biblioteca per seguir l'organització d'aquesta tasca.</p>`
    }
  },

  "eo": {
    status: {
      aberta: "Malfermita",
      a_fazer: "Farenda",
      em_andamento: "En progreso",
      bloqueada: "Blokita",
      concluida: "Finita",
      cancelada: "Nuligita",
      arquivada: "Arkivita"
    },
    priority: { alta: "Alta", media: "Meza", baixa: "Malalta", urgente: "Urĝa" },
    label: {
      tarefa: "Tasko",
      prioridade: "Prioritato",
      situacao: "Stato",
      prazo: "Limdato",
      marcadores: "Etikedoj",
      descricao: "Priskribo",
      organizacao: "Respondeculo",
      mudancas: "Gravaj ŝanĝoj"
    },
    greetingPlain: "Saluton!",
    greetingNamed: "Saluton, {name}!",
    untitled: "sentitola tasko",
    fallbackName: "kamarado",
    assigned: {
      subject: "Nova interna tasko",
      title: "Nova interna tasko",
      introHtml: `<p style="margin:0 0 10px;">Vi ricevis <b>novan internan taskon</b>.</p><p style="margin:0;">Konsultu la panelon por sekvi ĝian progreson kaj registri ajnan necesan ĝisdatigon.</p>`
    },
    reminder: {
      subject: "Memorigo pri interna tasko",
      title: "Memorigo pri interna tasko",
      introHtml: `<p style="margin:0 0 10px;">Ĉi tiu tasko eniris la blokon <b>Tago-laboro</b>.</p><p style="margin:0;">Se ĝi jam estas solvita, indas ĝisdatigi ĝian staton en la panelo.</p>`
    },
    orgCreated: {
      subject: "Nova interna tasko sub via respondeco",
      title: "Nova interna tasko",
      introHtml: `<p style="margin:0 0 10px;"><b>Nova interna tasko</b> estis registrita sub via respondeco.</p><p style="margin:0;">Malfermu la panelon de la biblioteko por sekvi ĝian progreson kaj organizi la sekvajn paŝojn.</p>`
    },
    orgUpdated: {
      subject: "Grava ĝisdatigo pri interna tasko",
      title: "Grava ĝisdatigo pri interna tasko",
      introHtml: `<p style="margin:0 0 10px;">Interna tasko sub via respondeco ricevis <b>gravan ĝisdatigon</b>.</p><p style="margin:0;">Kontrolu la panelon de la biblioteko por validigi la novan situacion kaj alĝustigi la sekvadon.</p>`
    },
    libCreated: {
      subject: "Nova interna tasko registrita",
      title: "Nova interna tasko registrita",
      introHtml: `<p style="margin:0 0 10px;"><b>Nova interna tasko</b> estis registrita por ĉi tiu biblioteko.</p><p style="margin:0;">Ĉi tiu avizo estas informa kaj restas aparta de la individuaj invitoj senditaj al la invititaj kamaradoj.</p>`
    },
    libUpdated: {
      subject: "Grava ĝisdatigo pri biblioteka tasko",
      title: "Grava ĝisdatigo pri biblioteka tasko",
      introHtml: `<p style="margin:0 0 10px;">Interna tasko de la biblioteko ricevis <b>gravan ĝisdatigon</b>.</p><p style="margin:0;">Ĉi tiu avizo helpas sekvi centrajn ŝanĝojn sen dependi de la individuaj invitoj.</p>`
    },
    invitation: {
      subject: "Invito al interna tasko",
      title: "Invito al interna tasko",
      introHtml: `<p style="margin:0 0 10px;">Vi ricevis <b>inviton partopreni en interna tasko</b> de la biblioteko.</p><p style="margin:0;">Se tio havas sencon por vi, malfermu la panelon de la biblioteko por sekvi la organizadon de ĉi tiu tasko.</p>`
    }
  },

  "nl": {
    status: {
      aberta: "Open",
      a_fazer: "Te doen",
      em_andamento: "Bezig",
      bloqueada: "Geblokkeerd",
      concluida: "Voltooid",
      cancelada: "Geannuleerd",
      arquivada: "Gearchiveerd"
    },
    priority: { alta: "Hoog", media: "Gemiddeld", baixa: "Laag", urgente: "Urgent" },
    label: {
      tarefa: "Taak",
      prioridade: "Prioriteit",
      situacao: "Status",
      prazo: "Deadline",
      marcadores: "Labels",
      descricao: "Beschrijving",
      organizacao: "Verantwoordelijke",
      mudancas: "Belangrijke wijzigingen"
    },
    greetingPlain: "Hoi!",
    greetingNamed: "Hoi {name}!",
    untitled: "taak zonder titel",
    fallbackName: "kameraad",
    assigned: {
      subject: "Nieuwe interne taak",
      title: "Nieuwe interne taak",
      introHtml: `<p style="margin:0 0 10px;">Je hebt een <b>nieuwe interne taak</b> gekregen.</p><p style="margin:0;">Bekijk het paneel om de voortgang te volgen en eventuele updates te noteren.</p>`
    },
    reminder: {
      subject: "Herinnering interne taak",
      title: "Herinnering interne taak",
      introHtml: `<p style="margin:0 0 10px;">Deze taak is in het blok <b>Werk van de dag</b> terechtgekomen.</p><p style="margin:0;">Als ze al is afgehandeld, is het goed om de status in het paneel bij te werken.</p>`
    },
    orgCreated: {
      subject: "Nieuwe interne taak onder jouw verantwoordelijkheid",
      title: "Nieuwe interne taak",
      introHtml: `<p style="margin:0 0 10px;">Er is een <b>nieuwe interne taak</b> onder jouw verantwoordelijkheid aangemaakt.</p><p style="margin:0;">Open het bibliotheekpaneel om de voortgang te volgen en de volgende stappen te organiseren.</p>`
    },
    orgUpdated: {
      subject: "Belangrijke update bij een interne taak",
      title: "Belangrijke update bij een interne taak",
      introHtml: `<p style="margin:0 0 10px;">Een interne taak onder jouw verantwoordelijkheid heeft een <b>belangrijke update</b> gekregen.</p><p style="margin:0;">Bekijk het bibliotheekpaneel om de nieuwe situatie te bevestigen en de opvolging aan te passen.</p>`
    },
    libCreated: {
      subject: "Nieuwe interne taak geregistreerd",
      title: "Nieuwe interne taak geregistreerd",
      introHtml: `<p style="margin:0 0 10px;">Er is een <b>nieuwe interne taak</b> voor deze bibliotheek geregistreerd.</p><p style="margin:0;">Deze melding is informatief en staat los van de individuele uitnodigingen die naar de uitgenodigde kameraden zijn gestuurd.</p>`
    },
    libUpdated: {
      subject: "Belangrijke update bij een bibliotheektaak",
      title: "Belangrijke update bij een bibliotheektaak",
      introHtml: `<p style="margin:0 0 10px;">Een interne taak van de bibliotheek heeft een <b>belangrijke update</b> gekregen.</p><p style="margin:0;">Deze melding helpt om centrale wijzigingen te volgen zonder afhankelijk te zijn van individuele uitnodigingen.</p>`
    },
    invitation: {
      subject: "Uitnodiging voor een interne taak",
      title: "Uitnodiging voor een interne taak",
      introHtml: `<p style="margin:0 0 10px;">Je hebt een <b>uitnodiging gekregen om mee te werken aan een interne taak</b> van de bibliotheek.</p><p style="margin:0;">Als het voor jou klopt, open dan het bibliotheekpaneel om de organisatie van deze taak te volgen.</p>`
    }
  }
};

const FALLBACK_LOCALE = "pt-BR";
export const SUPPORTED_TASK_LOCALES = ["pt-BR", "fr", "es", "en", "it", "de", "ca", "eo", "nl"];

// Resout une locale arbitraire (ex. "pt", "fr-FR", "PT-br") vers une locale supportee.
// Repli pt-BR si rien ne correspond.
export function normalizeTaskLocale(input) {
  const raw = String(input || "").trim();
  if (!raw) return FALLBACK_LOCALE;
  if (TASK_STRINGS[raw]) return raw;
  const lower = raw.toLowerCase();
  const exact = SUPPORTED_TASK_LOCALES.find((l) => l.toLowerCase() === lower);
  if (exact) return exact;
  const base = lower.split(/[-_]/)[0];
  const byBase = SUPPORTED_TASK_LOCALES.find((l) => l.split("-")[0].toLowerCase() === base);
  return byBase || FALLBACK_LOCALE;
}

// Chaine simple (greetingPlain, greetingNamed, untitled, fallbackName), avec interpolation {var}.
export function tTask(locale, key, vars) {
  const loc = TASK_STRINGS[locale] ? locale : FALLBACK_LOCALE;
  let value = TASK_STRINGS[loc][key];
  if (value == null) value = TASK_STRINGS[FALLBACK_LOCALE][key];
  if (value == null) return key;
  if (vars) {
    for (const name of Object.keys(vars)) {
      const sub = vars[name] == null ? "" : String(vars[name]);
      value = value.split("{" + name + "}").join(sub);
    }
  }
  return value;
}

export function taskStatusLabel(locale, status) {
  const value = String(status || "").trim();
  const loc = TASK_STRINGS[locale] ? locale : FALLBACK_LOCALE;
  const fromLoc = TASK_STRINGS[loc].status[value];
  if (fromLoc) return fromLoc;
  const fromPt = TASK_STRINGS[FALLBACK_LOCALE].status[value];
  if (fromPt) return fromPt;
  return value || TASK_STRINGS[loc].status.aberta;
}

export function taskPriorityLabel(locale, priority) {
  const value = String(priority || "").trim();
  const loc = TASK_STRINGS[locale] ? locale : FALLBACK_LOCALE;
  const fromLoc = TASK_STRINGS[loc].priority[value];
  if (fromLoc) return fromLoc;
  const fromPt = TASK_STRINGS[FALLBACK_LOCALE].priority[value];
  if (fromPt) return fromPt;
  return value || TASK_STRINGS[loc].priority.media;
}

export function taskFieldLabel(locale, key) {
  const loc = TASK_STRINGS[locale] ? locale : FALLBACK_LOCALE;
  return TASK_STRINGS[loc].label[key] || TASK_STRINGS[FALLBACK_LOCALE].label[key] || key;
}

// Renvoie { subject, title, introHtml } pour une variante donnee, avec repli pt-BR par champ.
export function taskVariant(locale, variantKey) {
  const loc = TASK_STRINGS[locale] ? locale : FALLBACK_LOCALE;
  const fromLoc = TASK_STRINGS[loc][variantKey] || {};
  const fromPt = TASK_STRINGS[FALLBACK_LOCALE][variantKey] || {};
  return {
    subject: fromLoc.subject || fromPt.subject || "",
    title: fromLoc.title || fromPt.title || "",
    introHtml: fromLoc.introHtml || fromPt.introHtml || ""
  };
}
