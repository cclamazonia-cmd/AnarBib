// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — L'écriture des locales est celle de la langue (doctrine DOC-PS-1)
//
// CE QUE CE TEST EMPÊCHE DE REVENIR.
//
// `DOC-PS-1` dit depuis des mois : « i18n : scripts via Node .cjs ou UTF-8
// PowerShell explicite ; vérifier toute mojibake avant correction ». La règle
// était écrite au registre et nulle part ailleurs. L'audit du 07/09/2026
// (`docs/journal/audits/AUDIT_i18n_diacritiques_anglais_residuel_2026-09-07.md`)
// a mesuré ce qu'elle avait laissé passer :
//
//   — 71 valeurs aux diacritiques mangés dans sept locales : « ISBN deja au
//     catalogue », « La bibliotheque selectionnee n'est pas encore entierement
//     configuree sur le reseau », l'allemand en `fuer`/`muessen`, l'espéranto
//     en `Chu dauri` ;
//   — six valeurs laissées en anglais dans `el.json` ;
//   — cinq valeurs de `el.json` écrites en GREC TRANSLITTÉRÉ en caractères
//     latins — « Sfalma kata ti dimiourgia tou logariasmo » — qu'aucune
//     lectrice grecque ne lit comme du grec. Ces onze-là portent depuis le
//     07/09 au soir une traduction provisoire, listée dans `GREC_PROVISOIRE`.
//
// Les commits d'origine s'étalent de mai à août 2026. Ce n'est pas un accident,
// c'est un mode de défaillance récurrent : une règle écrite là où elle n'oblige
// pas est un vœu (`DOC-GLB-1`). Ce fichier la rend mécanique.
//
// ─────────────────────────────────────────────────────────────────────────────
// D'OÙ VIENNENT LES LISTES, ET CE QU'ELLES NE VOIENT PAS
//
// Exigence de `DOC-RECENS-1` : un recensement porte sa méthode et son angle
// mort, sinon sa complétude est une croyance. Trois chemins indépendants :
//
//   (1) ÉGALITÉ À L'ANGLAIS — valeur identique à celle de `en.json`, en
//       écartant les clés identiques dans au moins sept locales (sigles, noms
//       propres, termes techniques légitimement non traduits).
//       ANGLE MORT : ne voit pas l'anglais retapé ou légèrement modifié, ni
//       aucune faute qui n'implique pas `en.json`.
//
//   (2) CRITÈRE D'ÉCRITURE — valeur de `el.json` ne contenant aucune lettre
//       grecque. Indépendant de (1) : c'est lui, et lui seul, qui a trouvé le
//       grec translittéré.
//       ANGLE MORT : ne vaut que pour le grec, seule locale à changer
//       d'alphabet. Les neuf autres partagent l'alphabet latin, aucun critère
//       structurel ne les sépare.
//
//   (4) REGISTRE D'ADRESSE — `DOC-ADDR-1`, amendé le 07/09/2026 : l'app tutoie
//       SANS EXCEPTION, politique de confidentialité et messages système
//       compris. 163 chaînes françaises et 52 espagnoles vouvoyaient ce jour-là,
//       alors que la doctrine était actée depuis le 04/06 — troisième doctrine
//       du §0 trouvée écrite et non tenue en deux jours. Le motif cherche le
//       pronom ou le possessif de politesse et, depuis le 27/09/2026 (186
//       impératifs en « -ez » passés au travers), l'impératif du vouvoiement
//       (`VOUVOIEMENT_FR`, plus bas, avec ses angles morts) ; « rendez-vous »
//       est exclu par construction, et les adresses au PLURIEL (à une
//       assemblée, à un collectif) sont nommées une par une dans
//       `PLURIEL_LEGITIME`.
//       ANGLE MORT : ne couvre que fr et es, seules locales relues ce jour ;
//       it, de, ca, nl, el ont aussi un vouvoiement et attendent leur passe.
//       ca relu le 27/09/2026 (312 valeurs au « vós », `VOUVOIEMENT_CA`) ;
//       it, de, nl, el relus le même jour (402 valeurs) : toute locale qui
//       connaît un registre de politesse a désormais son motif (en et eo n'en
//       ont pas ; pt-BR a le sien, dans l'autre sens : « você »).
//       pt-BR s'y ajoute le 27/09/2026, dans l'autre sens : son registre est
//       « você », la faute y est le « tu » EUROPÉEN (`TU_EUROPEU`, plus bas,
//       avec son propre angle mort, mesuré).
//
//   (3) FORMES FAUTIVES CERTAINES — motifs dont l'absence de diacritique n'est
//       jamais un homographe.
//       ANGLE MORT, et c'est le plus important : ce chemin ne trouve QUE ce
//       qui est dans `FORMES_FAUTIVES`. Son chiffre est un PLANCHER, jamais un
//       total. Élargir la liste est un travail légitime et attendu.
//
//   (5) VOCABULAIRE DU PORTUGAL — pt-BR.json seulement : « ficheiro »,
//       « registo », « partilha », « A carregar… »… Ajouté le 27/09/2026
//       (`PT_EUROPEU`, plus bas, avec son angle mort mesuré) : même logique
//       que (3), un mot n'y entre que s'il n'a AUCUN homographe brésilien.
//
// DEUX MESURES FAUSSES ONT PRÉCÉDÉ CELLES-CI, et le dire fait partie du relevé.
// Un premier essai comparait chaque valeur ASCII au lexique accentué de son
// propre fichier : 570 « fautes » en néerlandais, parce que *een*/*één* et
// *que*/*què* sont des homographes légitimes. Un second mettait `catalogo`
// dans les motifs italiens — mot qui, en italien, NE PORTE PAS d'accent : 123
// faux positifs. Les deux mesuraient ce qu'elles regardaient, pas ce qui était
// vrai. D'où la règle appliquée ici : un motif n'entre dans
// `FORMES_FAUTIVES` que si sa forme sans diacritique n'existe pas comme mot
// autonome dans la langue.
// ─────────────────────────────────────────────────────────────────────────────

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { TU_EUROPEU } from './helpers/ptbr-tu-europeu.js';
import { PT_EUROPEU } from './helpers/ptbr-pt-europeu.js';
import { FRANCES_EM_PT } from './helpers/ptbr-frances.js';

const ici = dirname(fileURLToPath(import.meta.url));
const DOSSIER = resolve(ici, '../i18n/locales');

const LOCALES = ['pt-BR', 'fr', 'en', 'de', 'it', 'es', 'ca', 'eo', 'nl', 'el'];

const brut = (l) => readFileSync(resolve(DOSSIER, `${l}.json`), 'utf8');
const charge = (l) => JSON.parse(brut(l));

const TOUT = Object.fromEntries(LOCALES.map((l) => [l, charge(l)]));
const EN = TOUT.en;

// ─────────────────────────────────────────────────────────────────────────────
// GREC PROVISOIRE — onze clés traduites le 07/09/2026 par Claude, PAS par une
// personne hellénophone.
//
// Elles étaient fautives (six en anglais, cinq en grec translittéré en lettres
// latines) et l'ont été en production du 07/06 au 07/09. Le choix a été de
// mettre une traduction provisoire plutôt que de laisser du charabia à l'écran
// en attendant la relecture — Xavier, 07/09 : « on la laisse moisir comme ça ? »
// Registre au singulier comme les voisines (`DOC-ADDR-1`) ; vocabulaire pris
// dans `el.json` même (« καθιερωμένη εγγραφή », « Οργάνωση ή συλλογικότητα »,
// « Αποθήκευση ούτως ή άλλως; »).
//
// CE QUE LA LISTE GARANTIT : que ces clés sont EN GREC (les chemins 1, 2 et 3
// les contrôlent comme n'importe quelle autre — plus aucune exemption). Elle
// ne garantit PAS que le grec est bon : ça, seule une relecture humaine le
// dit, et c'est en la faisant qu'on retire la clé d'ici.
//
// ANGLE MORT ASSUMÉ : rien de mécanique ne force cette liste à rétrécir — une
// relecture est un acte humain, pas un état du code. Si elle est encore là
// dans six mois, c'est que personne n'a relu, et c'est l'information utile.
// ─────────────────────────────────────────────────────────────────────────────
const GREC_PROVISOIRE = [
  // ex-anglais — commit 7300502e, 07/06/2026
  'catalogacao.isbnDup.badge',
  'catalogacao.presave.isbnExists',
  'catalogacao.presave.titleAuthorExists',
  'catalogacao.authlink.autoLinked',
  'account.profile.org',
  'panel.reader.org',
  // ex-translittéré — commit a1ce13ae, 07/06/2026
  'auth.create.errorCreateFailed',
  'auth.create.errorGeneric',
  'auth.create.errorLibraryNotReady',
  'auth.create.errorProfileFailed',
  'auth.create.errorServerConfig',
];

// Clés dont la valeur est légitimement sans lettre grecque dans `el.json` :
// sigles, identifiants techniques, noms de langue dans leur propre langue,
// exemples d'URL ou d'adresse. Chacune est nommée, aucune n'est un motif.
const EL_SANS_GREC_LEGITIME = [
  'account.constitution.guidePath',   // chemin de page de la vitrine (« /el/ypodochi/ »), pas un texte
  'atelier.volet4.classif.cdd',
  'catalogacao.author.sourceKind.viaf',
  'catalogacao.author.sourceKind.wikidata',
  'catalogacao.field.marcJson',
  'catalogacao.guide.zine.title',
  'catalogacao.material.zine',
  'catalogacao.ph.audioFormatTech',
  'catalogacao.ocr.badgeOcr',
  'importacoes.adapter.encodingLatin1',   // « Latin-1 / Windows-1252 » : noms d'encodage (H15)
  'importacoes.adapter.encodingUtf8',     // « UTF-8 » : nom d'encodage (H15)
  'importacoes.fila.table',
  'importacoes.rss.exampleUrl',
  'importacoes.reception.libSlugPlaceholder',
  'rede.cooptation.propose.modal.targetPlaceholder',
  'rede.reports.col.authoritiesA',
  'language.fr', 'language.id', 'language.nb', 'language.sk',
];

// Clés légitimement identiques à l'anglais dans toutes les locales latines.
// Volontairement courte : toute entrée ici est une traduction qu'on renonce à
// faire, et doit pouvoir se défendre.
const IDENTIQUE_A_EN_LEGITIME = [
  'app.name',
  'book.isbn', 'book.meta.isbn', 'book.meta.issn', 'book.meta.cdd',
  'catalogacao.form.isbn', 'catalogacao.form.issn', 'catalogacao.form.cdd',
  'catalogacao.field.marcJson',
  'atelier.volet4.classif.cdd',
  'importacoes.fila.table',
  'importacoes.rss.exampleUrl',
  'rede.reports.col.authoritiesA',
  // Vérifiées une par une le 07/09/2026 : ces chaînes s'écrivent à l'identique
  // en anglais et dans la langue cible. Ce n'est pas une traduction oubliée.
  'biblioteca.leitores.exportCsv',            // « Export CSV » — fr
  'biblioteca.leitores.exportPdf',            // « Export PDF » — fr
  'book.isbd.zone4',                          // « Zone 4 — Publication » — fr
  'book.isbd.zone7',                          // « Zone 7 — Notes » — fr
  'catalogacao.isbd.zone4',                   // fr
  'catalogacao.exemplar.acquisitionStep',     // fr
  'catalogacao.exemplar.provenanceNote',      // « Provenance / note » — fr
  'catalogacao.exemplar.labelCdd',            // « CDD (label) » — nl
  'resource.meta.sourceAttribution',          // « Source / attribution » — fr
  'catalogacao.ocr.stage.ocrPage',            // « OCR page … » — fr
  'importacoes.oai.lotsPerCycle',             // « {n} lots/cycle » — fr
  'address.state.GB',                         // « Nation / Region » — de
  'catalogacao.subjectGov.editNotation',      // « Notation (DDC) » — de
  'rede.gazeta.sources.feed',                 // « Feed (URL) » — de, nl
  'catalogacao.batch.openBatchesCount',       // « Open batches » — nl
  'catalogacao.queue.selectedAllFilter',      // « ✓ {count} in filter » — nl
  'transitions.type.1',                       // « Type 1 — direct » — nl
  'importacoes.reception.libTerritoryPlaceholder', // « Bologna, IT » — exemple
  'importacoes.wizard.source.fileLabel',      // « File (CSV, RIS, MARCXML…) » — it
  'panel.history.itemsCount',                 // « {count} document(s) » — es
  'ficedl.count',                             // « # descriptor(s) » — ca
  'importacoes.coverage.occurrences',         // « # occurrence(s) » — fr (H16, 26/09/2026)
];

// ─────────────────────────────────────────────────────────────────────────────
// Chemin (3) — formes dont l'absence de diacritique est une faute certaine.
// Critère d'admission : la forme sans diacritique NE DOIT PAS exister comme
// mot autonome de la langue. `catalogo` entre en espagnol et en portugais
// (« catálogo »), et reste dehors en italien, où le mot s'écrit sans accent.
// ─────────────────────────────────────────────────────────────────────────────
const FORMES_FAUTIVES = {
  fr: ['deja', 'autorite', 'autorites', 'reseau', 'donnees', 'depot',
       'bibliotheque', 'selectionnee', 'entierement', 'configuree', 'configuree',
       'ete', 'cree', 'creee', 'moderation', 'signalees', 'masquees',
       'publiees', 'reservee', 'exposes', 'activee', 'validee', 'adhesion',
       'reference', 'utilisee', 'partagees'],
       // NB : « partages » est SORTI de cette liste — c'est le verbe conjugué
       // (« ce que tu partages »), donc un homographe légitime.
  'pt-BR': ['catalogo', 'codigo', 'coordenacao', 'configuracao', 'nao', 'ja',
            'titulo', 'referencia', 'bibliografica', 'voce', 'vinculo'],
  es: ['catalogo', 'codigo', 'pagina', 'coordinacion', 'configuracion',
       'accion', 'titulo', 'autoria', 'boton', 'publico', 'publicas',
       'tecnico', 'indice', 'aun'],
  it: ['gia', 'perche', 'piu', 'puo', 'citta', 'autorita', 'quantita'],
  de: ['fuer', 'muessen', 'gewaehlten', 'uebergabe', 'waehlen', 'erfuellen',
       'verfuegbarkeit', 'persoenliche'],
  ca: ['cataleg', 'titol', 'pagina'],
  eo: ['chu', 'dauri', 'gxi', 'cxu', 'auxtoro'],
  nl: [],
  en: [],
  el: [],
};

// Clés dont la valeur DOIT rester sans diacritique : slugs, identifiants
// techniques, exemples d'URL. Corriger l'orthographe y casserait la valeur.
const ASCII_VOULU = [
  'importacoes.reception.libSlugPlaceholder', // « bibliotheque-partenaire » : slug
];

// Chemin (4) — vouvoiement. Une entrée par locale relue ; le motif de chaque
// langue est le sien, pas une traduction du motif français.
//
// fr, élargi le 27/09/2026. Le motif du 07/09 ne cherchait que le pronom et le
// possessif (vous, votre, vos). Un impératif n'a pas de pronom : 186 valeurs
// de fr.json s'adressaient encore au membre par un impératif au vouvoiement
// — « Réessayez ou contactez un·e bibliothécaire », « Saisissez
// le mot de passe », « Glissez un PDF ici, ou cliquez », « Veuillez
// reessayer » — et la garde était verte. Réécrites par
// `scripts/i18n-fr-tu-imperatifs.cjs`.
//
// CE QUE LE MOTIF VOIT, en plus du pronom et du possessif : tout mot terminé
// en « -ez », N'IMPORTE OÙ dans la phrase, et les deux impératifs irréguliers
// « faites » / « dites » quand ils portent un pronom (« Dites-le ») ou ouvrent
// une phrase. Le français le permet là où le portugais ne le permet pas : la
// 2e personne du pluriel sans « vous » ne peut être qu'un impératif, et tout
// impératif du vouvoiement finit en « -ez » (soyez, ayez, sachez, veuillez
// compris) sauf « faites » et « dites ». Pas de borne de position : une
// variante qui ne cherchait qu'en tête de phrase ou après « : », « , »,
// « ou », « et » ne retrouvait que 173 des 186 valeurs sur le fichier d'avant
// correction — elle manquait « — réessayez », « N'utilisez », « Double-
// cliquez », « Ré-exportez ». Le motif retenu les retrouve toutes (186/186),
// et ne signale rien d'autre dans ce fichier-là.
//
// Ce 186/186 n'est pas un rappel mesuré contre une vérité indépendante : les
// 186 ont été recensées par ce même critère morphologique. Ce qui fonde la
// complétude, c'est la conjugaison, pas le chiffre. D'où les ANGLES MORTS,
// qui sont ceux de la conjugaison :
//   — « rendez-vous » est exclu comme nom ; l'impératif « Rendez-vous à
//     l'accueil » passe ;
//   — « faites » / « dites » sans pronom au milieu d'une phrase passent :
//     ce sont aussi des participes (« modifications faites en assemblée ») ;
//   — les mots en « -ez » qui ne sont pas des verbes sont nommés dans
//     `MOTS_EN_EZ_NON_VERBES` — un nom propre en « -ez » (« Suez »,
//     « Sánchez ») y entre, avec sa raison.
// Bornes `\p{L}` et drapeau `u` : `\b` est ASCII en JavaScript, il coupe un
// mot au premier « é ».
const MOTS_EN_EZ_NON_VERBES = ['chez', 'assez', 'nez', 'rez'];
const VOUVOIEMENT_FR = new RegExp(
  '(?<![\\p{L}])(?<!rendez-)(vous|votre|vos)(?![\\p{L}])' +
    `|(?<![\\p{L}])(?!(?:${MOTS_EN_EZ_NON_VERBES.join('|')}|rendez-vous)(?![\\p{L}]))(\\p{L}+ez)(?![\\p{L}])` +
    '|(?<![\\p{L}])((?:fai|di)tes-(?:le|la|les|lui|leur|nous|moi|en|y))(?![\\p{L}])' +
    '|(?:^|[.!?…:;—–(]\\s*)((?:fai|di)tes)(?![\\p{L}])',
  'iu',
);
// es, élargi le 27/09/2026. Le motif du 07/09 cherchait « usted » EN
// MINUSCULE, sans drapeau `i` : les trois « Usted » en tête de phrase
// (« Usted está en modo de solo lectura », « Usted confirmó ese horario »)
// passaient. Et il ne connaissait pas le « vosotros » : les fenêtres de
// cooptation et de retrait collectif disaient « Verificad », « Exponed »,
// « Seleccionad », « Explicad », « Vuestra decisión es decisiva » à la
// personne qui propose ou qui vote. Douze valeurs, réécrites par
// `scripts/i18n-es-ptbr-registre.cjs`.
//
// CE QUE LE MOTIF VOIT : « usted/ustedes » dans les deux casses, les
// impératifs de politesse de la liste d'origine, les pronoms et possessifs du
// « vosotros » (vosotros, vuestro…, « os »), le présent en « -áis/-éis » et
// « sois », et l'impératif du « vosotros » (« -ad/-ed/-id ») en TÊTE DE
// PHRASE seulement. Sur le fichier d'avant correction : 12/12, rien d'autre ;
// l'ancien motif : 0/12.
// ANGLES MORTS : ailleurs qu'en tête de phrase, « -ad/-ed/-id » est trop
// souvent un nom (« red », « ciudad », « identidad » : 432 clés) ; en tête,
// les noms en « -dad/-tad » sont écartés, donc les impératifs en « -dad/-tad »
// passent (« Votad », « Editad », « Ayudad ») ; l'enclise « -os » (« Poneos »)
// passe, homographe des pluriels (« deseos », « correos »). Le voseo
// (« escribís », « Venís ») est un tutoiement, il n'est pas visé.
const NOMS_EN_AD_ED_ID = ['Red', 'Sed', 'Pared', 'Huésped', 'Césped', 'Madrid', 'David', 'Feed', 'Download', 'Id', 'Lid', 'Vid'];
const VOUVOIEMENT_ES = new RegExp(
  '(?<![\\p{L}])([Uu]sted|[Uu]stedes|[Vv]osotr[oa]s|[Vv]uestr[oa]s?|os|Desea|Consulte|Retome|Ponga|Haga|Indique|Seleccione|Verifique|Contacte)(?![\\p{L}])' +
    '|(?<![\\p{L}])(\\p{L}+(?:áis|éis)|[Ss]ois)(?![\\p{L}])' +
    `|(?:^|[.!?…:;—–(¡¿]\\s*)(?!(?:\\p{L}*[dt]ad|${NOMS_EN_AD_ED_ID.join('|')})(?![\\p{L}]))(\\p{Lu}\\p{Ll}*(?:ad|ed|id))(?![\\p{L}])`,
  'u',
);
// ca, relu le 27/09/2026 — la passe du 07/09 n'avait lu que fr et es. ca.json
// parlait au « vós » dans 312 valeurs : « Voleu suprimir…? » (41 fois),
// « Indiqueu », « Comproveu la vostra connexió i torneu a provar »,
// « Se us redirigirà », toute la politique de confidentialité — jusque sur
// l'écran de connexion. Réécrites par `scripts/i18n-ca-tu.cjs`.
//
// CE QUE LE MOTIF VOIT : les possessifs (vostre, vostra, vostres), vós,
// vosaltres, vostè, le clitique « us » et l'enclise « -vos », « sou » et
// « vau », et TOUT mot en « -eu / -iu / -ïu » n'importe où — même raison
// qu'en français : la 2e personne du pluriel catalane finit toujours en
// « -u » (« Voleu », « podeu », « Introduïu », « escriviu », « sou »).
// Sont écartés, nommés : les mots en « -eu/-iu » qui ne sont pas des verbes
// (`MOTS_EN_EU_IU_NON_VERBES` : ce qui restait dans le fichier une fois
// réécrit, vérifié mot par mot), et les adjectifs en « -tiu/-siu » (actiu,
// col·lectiu, definitiu…), sauf les verbes de `VERBES_EN_TIU` (« sortiu »,
// qui était dans le fichier). Sur le fichier d'avant correction : 312/312 et
// rien d'autre. Comme en français, le chiffre vient du même critère que le
// recensement : c'est la conjugaison qui fonde la complétude.
// ANGLES MORTS : « correu » est écarté comme nom (courriel) — c'est aussi le
// « vós » de córrer ; un verbe en « -tiu/-siu » absent de `VERBES_EN_TIU`
// passe ; le registre « vostè » (3e personne) ne se voit que par son pronom,
// ses verbes sont ceux d'une phrase descriptive.
const MOTS_EN_EU_IU_NON_VERBES = ['arreu', 'arxiu', 'ateneu', 'breu', 'correu', 'descriu', 'deu', 'diu', 'escriu',
  'eu' /* « EU-U.S. Data Privacy Framework » */, 'europeu', 'greu', 'meu', 'nadiu', 'preu', 'relleu', 'seu',
  'sobreescriu', 'teu', 'treu', 'veu'];
const VERBES_EN_TIU = ['sortiu', 'sentiu', 'partiu', 'repartiu', 'consentiu', 'assentiu', 'mentiu', 'convertiu',
  'invertiu', 'advertiu', 'divertiu', 'pervertiu', 'revertiu'];
const LETTRE_CA = '[\\p{L}·]'; // « col·lectiu » est un seul mot
const VOUVOIEMENT_CA = new RegExp(
  `(?<!${LETTRE_CA})([Vv]ostr(?:e|a|es)|[Vv]ós|[Vv]osaltres|[Vv]ostès?|[Uu]s|\\p{L}+-vos|[Ss]ou|[Vv]au)(?!${LETTRE_CA})` +
    `|(?<!${LETTRE_CA})(?!(?:${MOTS_EN_EU_IU_NON_VERBES.join('|')})(?!${LETTRE_CA}))` +
    `((?:${VERBES_EN_TIU.join('|')})|\\p{L}*(?:[^ts\\P{L}]iu|eu|ïu)|\\p{L}*(?<![ts])iu)(?:-\\p{L}+)?(?!${LETTRE_CA})`,
  'iu',
);
// it, de, nl, el — relus le 27/09/2026, après ca. Tous tutoyaient déjà pour
// l'essentiel ; le formel restait par îlots : la politique de confidentialité
// (it au « Lei », de au « Sie »), les fenêtres de cooptation et de retrait
// (it au « voi »), les assistants de catalogage et les messages d'erreur
// (de « Klicken Sie », el « Επιλέξτε »). it 65, de 147, nl 18, el 172 valeurs,
// réécrites par `scripts/i18n-it-de-nl-el-tu.cjs`. Chaque motif suit la
// structure de sa langue ; les chiffres sont mesurés sur les fichiers d'avant.
const TETE_DE_PHRASE = '(?:^|[.!?…:;•\\n„"“«(]\\s*)';
//
// nl — « u », « uw », « uzelf » : aucun homographe, sauf l'heure (« 1u32min »)
// et « U.S. », écartés par les bornes. 16/18 : les deux autres disaient
// « jullie » (pluriel familier) à une seule personne — pas un vouvoiement, pas
// visé ; un « jullie » adressé à une personne passe.
const VOUVOIEMENT_NL = /(?<![\p{L}\d])(u|U|uw|Uw|uzelf|Uzelf)(?![\p{L}\d]|\.\p{L})/u;
//
// de — la majuscule EST la marque : « Sie », « Ihr… », « Ihnen » au milieu
// d'une phrase ne peuvent être que la politesse (« sie », « ihr » = elle, ils,
// leur, s'écrivent en minuscule). En tête de phrase, « Sie » est aussi
// « elle / ils » (« Sie verlässt die aktive Liste » : la Fernleihe) ; seul le
// DÉBUT DE LA VALEUR est tranché — une valeur qui commence par « Sie » n'a pas
// d'antécédent. 139/147 ; ANGLE MORT : « Sie können… » en tête d'une phrase
// qui n'ouvre pas la valeur (6), et le « ihr / euer » familier pluriel (2).
const VOUVOIEMENT_DE = new RegExp(
  `(?<!${TETE_DE_PHRASE})(?<![\\p{L}-])(Sie|Ihr|Ihre|Ihren|Ihrem|Ihres|Ihrer|Ihnen)(?![\\p{L}])` +
    '|^\\s*(Sie|Ihr|Ihre|Ihren|Ihrem|Ihres|Ihrer|Ihnen)(?![\\p{L}])',
  'u',
);
//
// it — le « voi » (vostro, voi, présent en -ete : « potete »), « Lei » en
// majuscule, les majuscules de courtoisie « Sua / Suo » au milieu d'une
// phrase, les impératifs du « Lei » et du « voi » en tête de phrase. L'impératif
// en « -ate / -ite » est l'homographe du participe féminin (« Inviate »,
// « Scartate » sont des étiquettes) : il n'entre que listé ET suivi d'un mot.
// 25/65 seulement : le « Lei » en MINUSCULE (« il suo account », « Può
// esportare ») est l'homographe exact de la 3e personne. La politique de
// confidentialité entière y était — 40 valeurs — et c'est le test croisé
// plus bas (possessifs fr ↔ it) qui les voit : 62/65 à eux deux.
const IMPERATIVI_LEI = ['Verifichi', 'Inserisca', 'Selezioni', 'Clicchi', 'Scelga', 'Compili', 'Indichi', 'Scriva', 'Legga',
  'Apra', 'Prema', 'Utilizzi', 'Aggiunga', 'Carichi', 'Confermi', 'Chieda', 'Attenda', 'Riprovi', 'Vada', 'Esporti'];
const IMPERATIVI_VOI_ATE_ITE = ['Verificate', 'Spiegate', 'Controllate', 'Riesportate', 'Selezionate', 'Rifate', 'Importate',
  'Cliccate', 'Inserite', 'Contattate', 'Salvate', 'Compilate', 'Indicate', 'Usate', 'Utilizzate', 'Provate', 'Riprovate',
  'Caricate', 'Aprite', 'Seguite', 'Riempite', 'Definite'];
const NOMI_IN_ETE = ['Rete', 'Interprete', 'Sete', 'Prete', 'Parete', 'Abete'];
const VOUVOIEMENT_IT = new RegExp(
  '(?<![\\p{L}])(vostr[oaie]|Vostr[oaie]|voi|Voi|Lei|potete|dovete|volete|avete|siete|sapete|Potete|Dovete|Volete|Avete|Siete)(?![\\p{L}])' +
    `|(?<!${TETE_DE_PHRASE})(?<![\\p{L}])(Sua|Suo|Sue|Suoi)(?![\\p{L}])` +
    `|${TETE_DE_PHRASE}(${IMPERATIVI_LEI.join('|')})(?=\\s+\\p{L})` +
    `|${TETE_DE_PHRASE}(${IMPERATIVI_VOI_ATE_ITE.join('|')})(?=\\s+\\p{L})` +
    `|${TETE_DE_PHRASE}(?!(?:${NOMI_IN_ETE.join('|')})(?![\\p{L}]))(\\p{Lu}\\p{Ll}+ete)(?![\\p{L}])`,
  'u',
);
//
// el — la 2e personne du pluriel grecque finit TOUJOURS en « -τε » (présent,
// aoriste, impératif, médiopassif : « Επιλέξτε », « μπορείτε », « ήρθατε »,
// « Διαχειριστείτε »), plus « σας » / « εσείς ». Écartés : les mots en « -τε »
// qui ne sont pas des verbes (`EL_NON_VERBES`), les indéfinis en « -δήποτε »
// et la 1re personne en « -μαστε » (« είμαστε »). 172/172 sur le fichier
// d'avant, rien d'autre. ANGLE MORT : un nom ou adverbe en « -τε » absent de
// la liste ferait rougir à tort — on l'y ajoute, avec sa raison.
const EL_NON_VERBES = ['τότε', 'Τότε', 'ούτε', 'Ούτε', 'ώστε', 'Ώστε', 'μήτε', 'πέντε', 'εκάστοτε', 'πότε', 'Πότε', 'όποτε',
  'κάποτε', 'οπότε'];
const VOUVOIEMENT_EL = new RegExp(
  '(?<![\\p{L}])(σας|Σας|σάς|εσείς|Εσείς|εσάς|Εσάς)(?![\\p{L}])' +
    `|(?<![\\p{L}])(?!(?:${EL_NON_VERBES.join('|')})(?![\\p{L}]))(?!\\p{L}*(?:δήποτε|μαστε)(?![\\p{L}]))(\\p{L}+τε)(?![\\p{L}])`,
  'u',
);
const VOUVOIEMENT = {
  fr: VOUVOIEMENT_FR,
  es: VOUVOIEMENT_ES,
  ca: VOUVOIEMENT_CA,
  it: VOUVOIEMENT_IT,
  de: VOUVOIEMENT_DE,
  nl: VOUVOIEMENT_NL,
  el: VOUVOIEMENT_EL,
};

// Adresses au PLURIEL, à un collectif — ce n'est pas du vouvoiement — et
// MENTIONS du registre lui-même : la phrase liminaire de la politique de
// confidentialité nomme le vouvoiement pour dire qu'elle s'en passe.
const PLURIEL_LEGITIME = [
  'atelier.doctrine.text',   // « Asseyez-vous à plusieurs devant l'écran »
  'banner.profile.body',     // « discutez-en en assemblée »
  'privacy.register',        // « …comme le ferait un texte rédigé au vouvoiement » / « …de usted »
  'federacao.assembleias.fac.rotativityHint', // « Fonctions tournantes : alternez d'une AG à l'autre » — pluriel en pt-BR (« alternem ») et en es (« alternen »)
  'biblioteca.exchanges.suggestedMessage', // lettre d'une bibliothèque à une autre — ca « Hola, companyes i companys de {partner}. Us escrivim… »
];

// Chemin (4), pt-BR — le registre y est « você », la faute le « tu » EUROPÉEN.
// Le motif `TU_EUROPEU` (ce qu'il voit, son angle mort mesuré, ses bornes
// `\p{L}`) vit dans `helpers/ptbr-tu-europeu.js` depuis le 27/09/2026 : la
// garde des courriels pt-BR (`mail-ptbr-voce.test.js`) le partage tel quel.

// Valeurs où l'une de ces formes serait légitime (citation, nom propre,
// phrase descriptive à la 3e personne). Vide au 27/09/2026 : chaque entrée
// se défend en citant le passage.
const TU_LEGITIME = [];

// Chemin (5), pt-BR — le VOCABULAIRE du Portugal. Le motif `PT_EUROPEU` (son
// critère d'admission, ses motifs de structure, son angle mort mesuré) vit
// dans `helpers/ptbr-pt-europeu.js` depuis le 27/09/2026 : la garde des
// courriels pt-BR (`mail-ptbr-voce.test.js`) le partage tel quel. Même
// chemin, même partage pour les mots FRANÇAIS restés dans la traduction
// (`FRANCES_EM_PT`, `helpers/ptbr-frances.js`, 27/09 au soir).

// Valeurs où l'une de ces formes serait légitime (citation d'un texte
// portugais ou français, nom d'une institution). Vides au 27/09/2026.
const PT_EUROPEU_LEGITIME = [];
const FRANCES_LEGITIME = [];

const GREC = /[Ͱ-Ͽἀ-῿]/;

// Retire ce qui n'est pas de la prose : balises, URL, mails, et l'ARMATURE des
// messages ICU — mots-clés (`plural`, `select`, `offset`), noms de variables et
// sélecteurs (`one`, `other`, `=0`). Le TEXTE des branches, lui, est conservé :
// c'est de la prose traduisible, et c'est là que vivent les fautes.
//
// Un `replace(/\{[^{}]*\}/g)` ne suffit PAS : l'ICU est imbriqué, et un motif
// non imbriqué mange les accolades intérieures en laissant l'extérieur. C'est
// exactement l'erreur qui a fait sonner ce test sur `catalogacao.authlink.
// autoLinked` alors que la valeur était juste.
const ICU_ARMATURE = /\{\s*[A-Za-z_][\w]*\s*,\s*(?:plural|select|selectordinal)\s*,|\boffset:\s*\d+|\{\s*[A-Za-z_][\w]*\s*\}|(?:^|[{\s])(?:=\d+|one|other|few|many|zero|two)\s*(?=\{)/g;

function prose(v) {
  return v
    .replace(/<[^>]*>/g, ' ')
    .replace(/https?:\/\/\S+/g, ' ')
    .replace(/\S+@\S+/g, ' ')
    .replace(ICU_ARMATURE, ' ')
    .replace(/[{}]/g, ' ');
}

describe('i18n — écriture des locales (DOC-PS-1)', () => {
  // ── 0. Le support lui-même ────────────────────────────────────────────────
  describe('encodage des fichiers', () => {
    for (const l of LOCALES) {
      it(`${l}.json — UTF-8 sans BOM, sauts de ligne LF`, () => {
        const texte = brut(l);
        expect(texte.charCodeAt(0), `${l}.json commence par un BOM`).not.toBe(0xfeff);
        expect(texte.includes('\r\n'), `${l}.json contient des CRLF`).toBe(false);
      });

      // Découvert le 07/09/2026 en faisant tourner ce test pour la première
      // fois : 111 valeurs étaient en Unicode DÉCOMPOSÉ (fr 56, ca 25, de 19,
      // pt-BR 11). « Créer » y était stocké `C r e ◌́ e r` — un « e » suivi
      // d'un accent combinant. À l'écran c'est identique ; en mémoire ce sont
      // deux chaînes différentes. La recherche ne trouve pas, le tri se
      // trompe, `===` échoue contre la même chaîne venue du code, et un
      // `\b` d'expression régulière coupe au milieu du mot.
      it(`${l}.json — toutes les valeurs en forme NFC (composée)`, () => {
        const decomposees = Object.entries(TOUT[l])
          .filter(([, v]) => typeof v === 'string' && v.normalize('NFC') !== v)
          .map(([k]) => k);
        expect(
          decomposees,
          `${l} : ${decomposees.length} valeur(s) en NFD — ${decomposees.slice(0, 8).join(', ')}`,
        ).toEqual([]);
      });
    }
  });

  // ── 1. Diacritiques mangés ────────────────────────────────────────────────
  describe('chemin (3) — diacritiques mangés', () => {
    for (const l of LOCALES) {
      const motifs = FORMES_FAUTIVES[l];
      if (!motifs.length) continue;

      it(`${l}.json — aucune forme sans diacritique`, () => {
        const rx = new RegExp(`\\b(${motifs.join('|')})\\b`, 'i');
        const fautes = [];
        for (const [k, v] of Object.entries(TOUT[l])) {
          if (ASCII_VOULU.includes(k)) continue;
          const m = prose(v).match(rx);
          if (m) fautes.push(`${k} → « ${m[1]} » dans « ${v.slice(0, 70)} »`);
        }
        expect(
          fautes,
          `${l} : ${fautes.length} valeur(s) aux diacritiques mangés\n  ${fautes.slice(0, 10).join('\n  ')}`,
        ).toEqual([]);
      });
    }
  });

  // ── 2. Le grec s'écrit en grec ────────────────────────────────────────────
  describe('chemin (2) — el.json s\'écrit en alphabet grec', () => {
    it('aucune valeur de prose sans une seule lettre grecque, hors liste nommée', () => {
      const fautes = [];
      for (const [k, v] of Object.entries(TOUT.el)) {
        if (EL_SANS_GREC_LEGITIME.includes(k)) continue;
        const p = prose(v);
        const motsLatins = p.match(/[A-Za-z]{3,}/g) || [];
        if (motsLatins.length >= 2 && !GREC.test(p)) {
          fautes.push(`${k} → « ${v.slice(0, 70)} »`);
        }
      }
      expect(
        fautes,
        `el.json : ${fautes.length} valeur(s) sans grec\n  ${fautes.slice(0, 10).join('\n  ')}\n` +
          'Si la valeur est légitimement latine (sigle, URL), ajoute la clé à ' +
          'EL_SANS_GREC_LEGITIME en disant pourquoi.',
      ).toEqual([]);
    });
  });

  // ── 3. Anglais laissé tel quel ────────────────────────────────────────────
  describe('chemin (1) — pas d\'anglais laissé tel quel', () => {
    const cles = Object.keys(EN);
    // Une valeur identique dans ≥ 7 locales est un terme technique partagé
    // (ISBN, MARC JSON, une URL d'exemple)… À CONDITION qu'elle en ait l'air.
    //
    // Payé le 07/09/2026 au soir : « Organization or collective » était en
    // anglais dans SIX locales (de, it, ca, eo, nl — et el jusqu'à sa
    // correction). Sept locales identiques, donc « terme partagé », donc
    // exemptée : le seuil validait la faute d'autant mieux qu'elle était
    // répandue. C'est le grec corrigé qui l'a démasquée, en faisant tomber le
    // compte à six. D'où la seconde condition : pas un seul mot en minuscules
    // hors placeholders — un sigle n'en a pas, une phrase oubliée en a.
    const ressembleAUnJeton = (v) =>
      !(v.replace(/\{[^{}]*\}/g, ' ').match(/\b[a-z][a-z]{2,}\b/) || []).length;
    const partout = new Set(
      cles.filter(
        (k) =>
          LOCALES.filter((l) => TOUT[l][k] === EN[k]).length >= 7 &&
          ressembleAUnJeton(EN[k]),
      ),
    );

    for (const l of LOCALES) {
      if (l === 'en') continue;
      it(`${l}.json — aucune valeur identique à en.json hors liste nommée`, () => {
        const fautes = [];
        for (const k of cles) {
          if (partout.has(k)) continue;
          if (IDENTIQUE_A_EN_LEGITIME.includes(k)) continue;
          if (TOUT[l][k] !== EN[k]) continue;
          if (TOUT[l][k] === TOUT['pt-BR'][k]) continue; // identique à la source aussi
          const mots = (prose(EN[k]).match(/[A-Za-z]{2,}/g) || []).length;
          if (mots >= 2) fautes.push(`${k} → « ${EN[k].slice(0, 70)} »`);
        }
        expect(
          fautes,
          `${l} : ${fautes.length} valeur(s) restée(s) en anglais\n  ${fautes.slice(0, 10).join('\n  ')}\n` +
            'Si la chaîne est identique par nature dans cette langue, ajoute la ' +
            'clé à IDENTIQUE_A_EN_LEGITIME en disant pourquoi.',
        ).toEqual([]);
      });
    }
  });

  // ── 4. Registre d'adresse ─────────────────────────────────────────────────
  describe('chemin (4) — tutoiement (DOC-ADDR-1)', () => {
    for (const [l, rx] of Object.entries(VOUVOIEMENT)) {
      it(`${l}.json — aucune valeur au vouvoiement hors adresse plurielle nommée`, () => {
        const fautes = [];
        for (const [k, v] of Object.entries(TOUT[l])) {
          if (PLURIEL_LEGITIME.includes(k)) continue;
          const m = prose(v).match(rx);
          if (m) fautes.push(`${k} → « ${m.slice(1).find(Boolean)} » dans « ${v.slice(0, 70)} »`);
        }
        expect(
          fautes,
          `${l} : ${fautes.length} valeur(s) au vouvoiement\n  ${fautes.slice(0, 10).join('\n  ')}\n` +
            'Réécris au tu (« Réessaie », « Choisis », « Reprends »). Si la phrase ' +
            's\'adresse à un collectif au pluriel, ajoute la clé à PLURIEL_LEGITIME en ' +
            'citant le passage ; si le mot en -ez n\'est pas un verbe, ajoute-le à ' +
            'MOTS_EN_EZ_NON_VERBES.',
        ).toEqual([]);
      });
    }

    it('pt-BR.json — aucune valeur au « tu » européen (le registre est « você »)', () => {
      const fautes = [];
      for (const [k, v] of Object.entries(TOUT['pt-BR'])) {
        if (TU_LEGITIME.includes(k)) continue;
        const m = prose(v).match(TU_EUROPEU);
        if (m) fautes.push(`${k} → « ${m.slice(1).find(Boolean)} » dans « ${v.slice(0, 70)} »`);
      }
      expect(
        fautes,
        `pt-BR : ${fautes.length} valeur(s) au « tu » européen\n  ${fautes.slice(0, 10).join('\n  ')}\n` +
          'Réécris au « você » (seu/sua, « verifique », « clique », « a você »). Si la ' +
          'forme est légitime (citation, phrase descriptive à la 3e personne), ajoute ' +
          'la clé à TU_LEGITIME en citant le passage.',
      ).toEqual([]);
    });

    // Chemin (4) CROISÉ, it — le « Lei » en minuscule est invisible au motif
    // (homographe de la 3e personne), mais pas au français, qui est gardé :
    // là où fr dit « ton / ta / tes », l'italien doit dire « tuo / tua / tuoi /
    // tue » ; « suo / sua / suoi / sue » sans aucun possessif du tu, c'est le
    // « Lei ». 40/40 des valeurs de la politique de confidentialité sur le
    // fichier d'avant, aucune autre. ANGLE MORT : une phrase au « Lei » sans
    // possessif (« quali diritti ha », « può scrivere », « su di lei ») — trois
    // valeurs le 27/09, vues à la relecture seulement.
    it('it.json — pas de possessif du « Lei » là où fr tutoie', () => {
      const FR_POSS = /(?<![\p{L}])(ton|ta|tes)(?![\p{L}])/iu;
      const LEI = /(?<![\p{L}])(suo|sua|suoi|sue)(?![\p{L}])/iu;
      const TU = /(?<![\p{L}])(tuo|tua|tuoi|tue)(?![\p{L}])/iu;
      const fautes = Object.keys(TOUT.it).filter((k) => typeof TOUT.it[k] === 'string'
        && typeof TOUT.fr[k] === 'string' && !PLURIEL_LEGITIME.includes(k)
        && FR_POSS.test(prose(TOUT.fr[k])) && LEI.test(prose(TOUT.it[k])) && !TU.test(prose(TOUT.it[k])))
        .map((k) => `${k} → « ${TOUT.it[k].slice(0, 70)} »`);
      expect(
        fautes,
        `it : ${fautes.length} valeur(s) au « Lei » (fr tutoie)\n  ${fautes.slice(0, 10).join('\n  ')}\n` +
          'Réécris au tu (tuo/tua, « puoi », « hai », « te »). Si le possessif désigne un ' +
          'tiers (« la biblioteca e i suoi lettori »), c\'est que fr dit « ses » : relis fr.',
      ).toEqual([]);
    });
  });

  // ── 4 bis. Vocabulaire brésilien ──────────────────────────────────────────
  describe('chemin (5) — pt-BR parle brésilien, ni portugais ni français', () => {
    it('pt-BR.json — aucun mot ni tournure propre au Portugal', () => {
      const fautes = [];
      for (const [k, v] of Object.entries(TOUT['pt-BR'])) {
        if (PT_EUROPEU_LEGITIME.includes(k)) continue;
        const m = prose(v).match(PT_EUROPEU);
        if (m) fautes.push(`${k} → « ${m.slice(1).find(Boolean)} » dans « ${v.slice(0, 70)} »`);
      }
      expect(
        fautes,
        `pt-BR : ${fautes.length} valeur(s) au vocabulaire du Portugal\n  ${fautes.slice(0, 10).join('\n  ')}\n` +
          'Écris en brésilien (arquivo, registro, compartilhamento, contato, seção, ' +
          '« Carregando… »). Si la forme est légitime (citation d\'un texte portugais), ' +
          'ajoute la clé à PT_EUROPEU_LEGITIME en citant le passage.',
      ).toEqual([]);
    });

    it('pt-BR.json — aucun mot français laissé dans la traduction', () => {
      const fautes = [];
      for (const [k, v] of Object.entries(TOUT['pt-BR'])) {
        if (FRANCES_LEGITIME.includes(k)) continue;
        const m = prose(v).match(FRANCES_EM_PT);
        if (m) fautes.push(`${k} → « ${m[1]} » dans « ${v.slice(0, 70)} »`);
      }
      expect(
        fautes,
        `pt-BR : ${fautes.length} valeur(s) avec un mot français\n  ${fautes.slice(0, 10).join('\n  ')}\n` +
          'Traduis (feed, etiqueta de lombada, número de chamada, EEB, importar, e-mail). ' +
          'Si le mot est légitime (citation, nom propre), ajoute la clé à FRANCES_LEGITIME en citant le passage.',
      ).toEqual([]);
    });
  });

  // ── 5. Le grec provisoire ─────────────────────────────────────────────────
  describe('grec provisoire', () => {
    it('toutes les clés de GREC_PROVISOIRE existent', () => {
      const fantomes = GREC_PROVISOIRE.filter((k) => !(k in TOUT.el));
      expect(fantomes, `clés inexistantes dans el.json : ${fantomes.join(', ')}`).toEqual([]);
    });

    // Si quelqu'un remet de l'anglais ou du latin sur l'une de ces clés, les
    // chemins 1 et 2 le verront ; ce test-ci dit en plus D'OÙ vient la clé.
    it('chaque clé provisoire est bien en grec', () => {
      const regressees = GREC_PROVISOIRE.filter((k) => !GREC.test(prose(TOUT.el[k] || '')));
      expect(
        regressees,
        `${regressees.length} clé(s) provisoire(s) plus en grec : ${regressees.join(', ')}`,
      ).toEqual([]);
    });
  });
});
