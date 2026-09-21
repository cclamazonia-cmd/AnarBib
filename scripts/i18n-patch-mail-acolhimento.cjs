#!/usr/bin/env node
/*
 * i18n-patch-mail-acolhimento.cjs — ajoute au mail d'acceptation d'une demande
 * d'adhésion les chaînes qui mènent au guide d'accueil des coordinations.
 *
 *   node scripts/i18n-patch-mail-acolhimento.cjs           # aperçu (dry-run)
 *   node scripts/i18n-patch-mail-acolhimento.cjs --write   # applique
 *
 * CIBLE RÉELLE (vérifiée le 16/09/2026) : supabase/functions/notify-library-request/
 * strings.ts — l'Edge Function qui envoie DÉJÀ le mail de library_request_approved,
 * avec son propre dictionnaire STRINGS (un bloc par locale, clés "approved.subject" /
 * "approved.intro"). Pas _shared/i18n/mail-strings.ts, que la version livrée dans
 * l'archive visait à l'aveugle (le dépôt n'était pas joignable) ; pas les locales
 * React non plus.
 *
 * Cinq clés par locale, sous le préfixe existant `approved.` :
 *   approved.notYet    la bibliothèque n'est pas encore active, 60 jours, pas seul·e
 *   approved.path      trois gestes : mot de passe, /atelier, étape 0 en réunion
 *   approved.human     écrire AVANT de décider — canal humain de l'app (anarbib@proton.me)
 *   approved.ctaLabel  libellé du bouton
 *   approved.guidePath chemin de la page de la vitrine dans la langue de la personne
 *                      (la base vient de _shared/core/site-url.ts, réglable par SITE_BASE_URL)
 * Sujet et intro existants conservés (« Demande approuvée » — {library} interpolé).
 *
 * Doctrine : insertion textuelle, additive et idempotente, juste après la ligne
 * "approved.intro" de chaque bloc de locale ; jamais de resérialisation.
 * Garde : src/tests/mail-acolhimento-i18n.test.js.
 */
'use strict';

const fs = require('fs');
const path = require('path');

const DATA = {
  "pt-BR": {
    "approved.notYet": "A sua biblioteca ainda não está ativa: ela está em estado pré-ativo, e continua assim até que o regimento seja discutido em assembleia e recarregado. Você tem 60 dias, e ninguém espera que você faça isso soz(inho/inha/inhe).",
    "approved.path": "Comece por três gestos: troque a senha provisória, abra a oficina de constituição em /atelier, e leve a etapa 0 — os quatro eixos do perfil — para a próxima reunião do coletivo. O guia de acolhimento explica cada um deles.",
    "approved.human": "Antes de decidir, e não depois: escreva para anarbib@proton.me. A rede tem por princípio que uma decisão de constituição se conversa com um(a/e) camarada antes de virar um formulário.",
    "approved.ctaLabel": "Ler o guia de acolhimento",
    "approved.guidePath": "/pt/acolhimento/"
  },
  "fr": {
    "approved.notYet": "Ta bibliothèque n'est pas encore active : elle est pré-active, et elle le reste jusqu'à ce que le règlement soit discuté en assemblée et re-téléversé. Tu as 60 jours, et personne n'attend que tu fasses cela seul·e.",
    "approved.path": "Commence par trois gestes : change le mot de passe provisoire, ouvre l'atelier de constitution dans /atelier, et porte l'étape 0 — les quatre axes du profil — à la prochaine réunion du collectif. Le guide d'accueil explique chacun d'eux.",
    "approved.human": "Avant de décider, et non après : écris à anarbib@proton.me. Le réseau tient pour principe qu'une décision de constitution se discute avec un·e camarade avant de devenir un formulaire.",
    "approved.ctaLabel": "Lire le guide d'accueil",
    "approved.guidePath": "/fr/accueil/"
  },
  "es": {
    "approved.notYet": "Tu biblioteca todavía no está activa: está preactiva, y sigue así hasta que el reglamento se discuta en asamblea y se vuelva a subir. Tenés 60 días, y nadie espera que hagas esto sole.",
    "approved.path": "Empezá por tres gestos: cambiá la contraseña provisoria, abrí el taller de constitución en /atelier, y llevá la etapa 0 — los cuatro ejes del perfil — a la próxima reunión del colectivo. La guía de acogida explica cada uno de ellos.",
    "approved.human": "Antes de decidir, y no después: escribí a anarbib@proton.me. La red tiene por principio que una decisión de constitución se conversa con une compañere antes de volverse un formulario.",
    "approved.ctaLabel": "Leer la guía de acogida",
    "approved.guidePath": "/es/acogida/"
  },
  "en": {
    "approved.notYet": "Your library is not active yet: it is pre-active, and it stays that way until the bylaws have been discussed in assembly and re-uploaded. You have 60 days, and nobody expects you to do this alone.",
    "approved.path": "Start with three gestures: change the temporary password, open the constitution workshop in /atelier, and take step 0 — the four axes of the profile — to the collective's next meeting. The welcome guide explains each of them.",
    "approved.human": "Before deciding, and not after: write to anarbib@proton.me. The network holds it as a principle that a constitution decision is discussed with a comrade before it becomes a form.",
    "approved.ctaLabel": "Read the welcome guide",
    "approved.guidePath": "/en/welcome/"
  },
  "it": {
    "approved.notYet": "La tua biblioteca non è ancora attiva: è pre-attiva, e lo resta finché il regolamento non viene discusso in assemblea e ricaricato. Hai 60 giorni, e nessun* si aspetta che tu lo faccia da sol*.",
    "approved.path": "Comincia da tre gesti: cambia la password provvisoria, apri il laboratorio di costituzione in /atelier, e porta la tappa 0 — i quattro assi del profilo — alla prossima riunione del collettivo. La guida di accoglienza spiega ciascuno di essi.",
    "approved.human": "Prima di decidere, e non dopo: scrivi a anarbib@proton.me. La rete tiene per principio che una decisione di costituzione si discute con un* compagn* prima di diventare un modulo.",
    "approved.ctaLabel": "Leggi la guida di accoglienza",
    "approved.guidePath": "/it/accoglienza/"
  },
  "de": {
    "approved.notYet": "Deine Bibliothek ist noch nicht aktiv: sie ist vor-aktiv, und sie bleibt es, bis die Geschäftsordnung in der Versammlung besprochen und neu hochgeladen ist. Du hast 60 Tage, und niemand erwartet, dass du das allein machst.",
    "approved.path": "Fang mit drei Handgriffen an: ändere das vorläufige Passwort, öffne die Gründungswerkstatt in /atelier, und bring Etappe 0 — die vier Achsen des Adoptionsprofils — in die nächste Sitzung des Kollektivs. Der Willkommensleitfaden erklärt dir jeden davon.",
    "approved.human": "Vor dem Entscheiden und nicht danach: schreib an anarbib@proton.me. Das Netz hält es für einen Grundsatz, dass eine Gründungsentscheidung mit einer Genoss*in besprochen wird, bevor sie zu einem Formular wird.",
    "approved.ctaLabel": "Willkommensleitfaden lesen",
    "approved.guidePath": "/de/willkommen/"
  },
  "ca": {
    "approved.notYet": "La teva biblioteca encara no és activa: és preactiva, i ho continua sent fins que el reglament es discuteixi en assemblea i es torni a pujar. Tens 60 dies, i ningú no espera que ho facis sol-a-e.",
    "approved.path": "Comença per tres gestos: canvia la contrasenya provisional, obre el taller de constitució a /atelier, i porta l'etapa 0 — els quatre eixos del perfil d'adopció — a la propera reunió del col·lectiu. La guia d'acollida t'explica cadascun d'ells.",
    "approved.human": "Abans de decidir, i no després: escriu a anarbib@proton.me. La xarxa té per principi que una decisió de constitució es parla amb un-a-e camarada abans de convertir-se en un formulari.",
    "approved.ctaLabel": "Llegir la guia d'acollida",
    "approved.guidePath": "/ca/acollida/"
  },
  "eo": {
    "approved.notYet": "Via biblioteko ankoraŭ ne estas aktiva: ĝi estas antaŭaktiva, kaj ĝi restas tia ĝis kiam la regularo estos diskutita en asembleo kaj realŝutita. Vi havas 60 tagojn, kaj neniu atendas ke vi faru tion sola.",
    "approved.path": "Komencu per tri gestoj: ŝanĝu la provizoran pasvorton, malfermu la metiejon de konstituiĝo en /atelier, kaj portu la etapon 0 — la kvar aksojn de la adopta profilo — al la venonta kunveno de la kolektivo. La akcepta gvidilo klarigas al vi ĉiun el ili.",
    "approved.human": "Antaŭ ol decidi, kaj ne poste: skribu al anarbib@proton.me. La reto havas kiel principon ke decido pri konstituiĝo diskutiĝas kun kamarado antaŭ ol fariĝi formularo.",
    "approved.ctaLabel": "Legi la akceptan gvidilon",
    "approved.guidePath": "/eo/akcepto/"
  },
  "nl": {
    "approved.notYet": "Jouw bibliotheek is nog niet actief: ze is pre-actief, en dat blijft ze tot het reglement in de assemblee besproken en opnieuw geüpload is. Je hebt 60 dagen, en niemand verwacht dat je dat alleen doet.",
    "approved.path": "Begin met drie handelingen: verander het voorlopige wachtwoord, open het oprichtingsatelier in /atelier, en breng stap 0 — de vier assen van het profiel — naar de volgende vergadering van het collectief. De welkomstgids legt elk van die drie uit.",
    "approved.human": "Schrijf vóór je beslist en niet erna, naar anarbib@proton.me. Het netwerk houdt het als principe dat een beslissing over de oprichting eerst met een kameraad besproken wordt voor ze een formulier wordt.",
    "approved.ctaLabel": "De welkomstgids lezen",
    "approved.guidePath": "/nl/onthaal/"
  },
  "el": {
    "approved.notYet": "Η βιβλιοθήκη σου δεν είναι ακόμη ενεργή: είναι προ-ενεργή, και παραμένει έτσι ώσπου ο κανονισμός να συζητηθεί στη συνέλευση και να ανέβει ξανά. Έχεις 60 ημέρες, και κανένα άτομο δεν περιμένει να τα κάνεις όλα αυτά χωρίς βοήθεια.",
    "approved.path": "Ξεκίνα με τρεις κινήσεις: άλλαξε τον προσωρινό κωδικό, άνοιξε το εργαστήρι σύστασης στο /atelier, και πήγαινε το βήμα 0 — τους τέσσερις άξονες του προφίλ — στην επόμενη συνάντηση της συλλογικότητας. Ο οδηγός υποδοχής εξηγεί το καθένα από αυτά.",
    "approved.human": "Γράψε πριν αποφασίσεις και όχι μετά, στο anarbib@proton.me. Το δίκτυο έχει ως αρχή ότι μια απόφαση σύστασης συζητιέται με σύντροφο πριν γίνει φόρμα.",
    "approved.ctaLabel": "Διάβασε τον οδηγό υποδοχής",
    "approved.guidePath": "/el/ypodochi/"
  }
};

const TARGET = path.join(process.cwd(), 'supabase', 'functions', 'notify-library-request', 'strings.ts');
const WRITE = process.argv.includes('--write');

if (!fs.existsSync(TARGET)) {
  console.error(`Fichier introuvable : ${TARGET}\nLance le script depuis la racine du dépôt de l'application.`);
  process.exit(2);
}

const src = fs.readFileSync(TARGET, 'utf8');
if (src.includes('\r')) { console.error('CRLF dans strings.ts : à normaliser avant de patcher.'); process.exit(2); }

const KEYS = Object.keys(DATA['pt-BR']);
function q(s) { return JSON.stringify(s); }

// Un bloc de locale commence par `  "pt-BR": {` ou `  fr: {` et finit avant le suivant.
const heads = [...src.matchAll(/^  (?:"([a-zA-Z-]+)"|([a-z]{2})): \{$/gm)].map((m) => ({ loc: m[1] || m[2], at: m.index }));
const firstOf = {};
for (const h of heads) if (!(h.loc in firstOf)) firstOf[h.loc] = h.at;

let out = src;
let added = 0;
const report = [];
// Du dernier bloc au premier, pour que les index restent valables.
for (const loc of Object.keys(DATA).sort((a, b) => firstOf[b] - firstOf[a])) {
  if (!(loc in firstOf)) { console.error(`Locale absente de strings.ts : ${loc}`); process.exit(2); }
  const start = firstOf[loc];
  const next = heads.find((h) => h.at > start);
  const end = next ? next.at : out.indexOf('\n};', start);
  const bloc = out.slice(start, end);
  const missing = KEYS.filter((k) => !new RegExp(`^\\s*"${k.replace(/\./g, '\\.')}":`, 'm').test(bloc));
  if (missing.length === 0) { report.push(`  ${loc.padEnd(6)} déjà à jour`); continue; }
  const anchor = bloc.match(/^(\s*)"approved\.intro": .*$/m);
  if (!anchor) { console.error(`${loc} : ligne "approved.intro" introuvable, fichier laissé intact.`); process.exit(2); }
  const indent = anchor[1];
  const insert = missing.map((k) => `\n${indent}${q(k)}: ${q(DATA[loc][k])},`).join('');
  const pos = start + anchor.index + anchor[0].length;
  out = out.slice(0, pos) + insert + out.slice(pos);
  added += missing.length;
  report.push(`  ${loc.padEnd(6)} +${missing.length} : ${missing.join(', ')}`);
}

console.log(report.join('\n'));
if (added === 0) { console.log('Rien à faire.'); process.exit(0); }
if (!WRITE) {
  console.log(`\nDry-run : ${added} ligne(s) seraient insérées. Aperçu du bloc fr :`);
  console.log(KEYS.map((k) => `    ${q(k)}: ${q(DATA.fr[k])},`).join('\n'));
  console.log('\nRelance avec --write quand l\'aperçu convient.');
  process.exit(0);
}
fs.writeFileSync(TARGET, out, 'utf8');
console.log(`\n${added} ligne(s) écrites dans ${path.relative(process.cwd(), TARGET)}. Ensuite : npm test.`);
