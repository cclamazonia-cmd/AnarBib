// strings.ts — chaînes localisées du récapitulatif hebdomadaire des actions
// inter-bibliothèques.
//
// Ce n'est pas une notification de service : c'est un instrument de
// TRANSPARENCE. Les administrateur·rices réseau disposent de droits élevés sur
// toutes les bibliothèques ; ce récapitulatif fait que ce pouvoir ne s'exerce
// pas en silence. Le ton doit donc être factuel et sans dramatisation — on
// rend compte, on n'accuse pas.
//
// Deux destinataires, deux cadrages :
//   * coordination d'une bibliothèque → « voici ce qui a été fait chez vous » ;
//   * administration réseau → « voici ce que le réseau a fait cette semaine ».
//
// Placeholders : {library}, {start}, {end}, {count}. Repli : pt-BR.

export const FALLBACK_LOCALE = "pt-BR";

export const STRINGS: Record<string, Record<string, string>> = {
  "pt-BR": {
    subtitle: "Transparência da rede · resumo automático",
    greeting: "Olá!",
    footer: "Este resumo é enviado toda semana para que nenhuma ação da rede passe despercebida. Em caso de dúvida, responde a este e-mail.",
    "library.subject": "Ações da rede na biblioteca {library} ({start} a {end})",
    "library.title": "O que a rede fez na sua biblioteca",
    "library.intro": "Entre {start} e {end}, {count} ação(ões) foram realizadas na biblioteca {library} por pessoas da administração da rede. Segue o detalhe, para conhecimento.",
    "network.subject": "Ações inter-bibliotecas da semana ({start} a {end})",
    "network.title": "Ações inter-bibliotecas da semana",
    "network.intro": "Entre {start} e {end}, {count} ação(ões) foram realizadas por pessoas da administração da rede em bibliotecas das quais elas não fazem parte.",
    "col.when": "Quando",
    "col.who": "Quem",
    "col.what": "Ação",
    "col.where": "Biblioteca",
    "col.target": "Objeto",
    critical: "crítica",
  },
  fr: {
    subtitle: "Transparence du réseau · récapitulatif automatique",
    greeting: "Salut !",
    footer: "Ce récapitulatif est envoyé chaque semaine pour qu'aucune action du réseau ne passe inaperçue. Une question ? Réponds à ce message.",
    "library.subject": "Actions du réseau dans la bibliothèque {library} (du {start} au {end})",
    "library.title": "Ce que le réseau a fait dans votre bibliothèque",
    "library.intro": "Entre le {start} et le {end}, {count} action(s) ont été menées dans la bibliothèque {library} par des personnes de l'administration du réseau. Voici le détail, pour information.",
    "network.subject": "Actions inter-bibliothèques de la semaine (du {start} au {end})",
    "network.title": "Actions inter-bibliothèques de la semaine",
    "network.intro": "Entre le {start} et le {end}, {count} action(s) ont été menées par des personnes de l'administration du réseau dans des bibliothèques dont elles ne font pas partie.",
    "col.when": "Quand",
    "col.who": "Qui",
    "col.what": "Action",
    "col.where": "Bibliothèque",
    "col.target": "Objet",
    critical: "critique",
  },
  es: {
    subtitle: "Transparencia de la red · resumen automático",
    greeting: "¡Hola!",
    footer: "Este resumen se envía cada semana para que ninguna acción de la red pase desapercibida. ¿Alguna duda? Responde a este mensaje.",
    "library.subject": "Acciones de la red en la biblioteca {library} (del {start} al {end})",
    "library.title": "Lo que la red hizo en tu biblioteca",
    "library.intro": "Entre el {start} y el {end}, se realizaron {count} acción(es) en la biblioteca {library} por parte de personas de la administración de la red. Aquí está el detalle, para tu información.",
    "network.subject": "Acciones entre bibliotecas de la semana (del {start} al {end})",
    "network.title": "Acciones entre bibliotecas de la semana",
    "network.intro": "Entre el {start} y el {end}, se realizaron {count} acción(es) por parte de personas de la administración de la red en bibliotecas de las que no forman parte.",
    "col.when": "Cuándo",
    "col.who": "Quién",
    "col.what": "Acción",
    "col.where": "Biblioteca",
    "col.target": "Objeto",
    critical: "crítica",
  },
  en: {
    subtitle: "Network transparency · automatic summary",
    greeting: "Hello!",
    footer: "This summary is sent every week so that no network action goes unnoticed. Any questions? Just reply to this message.",
    "library.subject": "Network actions in the {library} library ({start} to {end})",
    "library.title": "What the network did in your library",
    "library.intro": "Between {start} and {end}, {count} action(s) were carried out in the {library} library by people from the network administration. Here is the detail, for your information.",
    "network.subject": "Cross-library actions this week ({start} to {end})",
    "network.title": "Cross-library actions this week",
    "network.intro": "Between {start} and {end}, {count} action(s) were carried out by people from the network administration in libraries they are not part of.",
    "col.when": "When",
    "col.who": "Who",
    "col.what": "Action",
    "col.where": "Library",
    "col.target": "Object",
    critical: "critical",
  },
};

export function tr(locale: string, key: string, vars: Record<string, string> = {}): string {
  const table = STRINGS[locale] || STRINGS[FALLBACK_LOCALE];
  let s = table[key] ?? STRINGS[FALLBACK_LOCALE][key] ?? key;
  for (const [k, v] of Object.entries(vars)) s = s.replaceAll(`{${k}}`, v);
  return s;
}

export function normalizeLocale(lang: string | null | undefined): string {
  const l = String(lang || "").trim();
  if (!l) return FALLBACK_LOCALE;
  if (STRINGS[l]) return l;
  const base = l.split("-")[0];
  if (STRINGS[base]) return base;
  return FALLBACK_LOCALE;
}
