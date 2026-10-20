// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — les motifs du vouvoiement, une entrée par locale (`DOC-ADDR-1`).
//
// Sortis de src/tests/i18n-ecriture.test.js (chemin 4) le 20/10/2026, sans
// changer leur texte, pour être PARTAGÉS avec src/tests/mail-tutoiement.test.js,
// qui garde les courriels des Edge Functions — même raison que
// helpers/ptbr-tu-europeu.js : un motif, deux gardes ; une copie aurait dérivé
// de l'original à la première retouche de l'un des deux.
// ─────────────────────────────────────────────────────────────────────────────

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
export const MOTS_EN_EZ_NON_VERBES = ['chez', 'assez', 'nez', 'rez'];
export const VOUVOIEMENT_FR = new RegExp(
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
export const VOUVOIEMENT_ES = new RegExp(
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
export const VOUVOIEMENT_CA = new RegExp(
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
export const VOUVOIEMENT_NL = /(?<![\p{L}\d])(u|U|uw|Uw|uzelf|Uzelf)(?![\p{L}\d]|\.\p{L})/u;
//
// de — la majuscule EST la marque : « Sie », « Ihr… », « Ihnen » au milieu
// d'une phrase ne peuvent être que la politesse (« sie », « ihr » = elle, ils,
// leur, s'écrivent en minuscule). En tête de phrase, « Sie » est aussi
// « elle / ils » (« Sie verlässt die aktive Liste » : la Fernleihe) ; seul le
// DÉBUT DE LA VALEUR est tranché — une valeur qui commence par « Sie » n'a pas
// d'antécédent. 139/147 ; ANGLE MORT : « Sie können… » en tête d'une phrase
// qui n'ouvre pas la valeur (6), et le « ihr / euer » familier pluriel (2).
export const VOUVOIEMENT_DE = new RegExp(
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
  'Apra', 'Prema', 'Utilizzi', 'Aggiunga', 'Carichi', 'Confermi', 'Chieda', 'Attenda', 'Riprovi', 'Vada', 'Esporti',
  // 30/09 (E3) : deux formes qui avaient échappé à la liste — quatre valeurs y étaient restées.
  'Faccia', 'Ricarichi'];
const IMPERATIVI_VOI_ATE_ITE = ['Verificate', 'Spiegate', 'Controllate', 'Riesportate', 'Selezionate', 'Rifate', 'Importate',
  'Cliccate', 'Inserite', 'Contattate', 'Salvate', 'Compilate', 'Indicate', 'Usate', 'Utilizzate', 'Provate', 'Riprovate',
  'Caricate', 'Aprite', 'Seguite', 'Riempite', 'Definite'];
const NOMI_IN_ETE = ['Rete', 'Interprete', 'Sete', 'Prete', 'Parete', 'Abete'];
export const VOUVOIEMENT_IT = new RegExp(
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
export const VOUVOIEMENT_EL = new RegExp(
  '(?<![\\p{L}])(σας|Σας|σάς|εσείς|Εσείς|εσάς|Εσάς)(?![\\p{L}])' +
    `|(?<![\\p{L}])(?!(?:${EL_NON_VERBES.join('|')})(?![\\p{L}]))(?!\\p{L}*(?:δήποτε|μαστε)(?![\\p{L}]))(\\p{L}+τε)(?![\\p{L}])`,
  'u',
);
export const VOUVOIEMENT = {
  fr: VOUVOIEMENT_FR,
  es: VOUVOIEMENT_ES,
  ca: VOUVOIEMENT_CA,
  it: VOUVOIEMENT_IT,
  de: VOUVOIEMENT_DE,
  nl: VOUVOIEMENT_NL,
  el: VOUVOIEMENT_EL,
};
