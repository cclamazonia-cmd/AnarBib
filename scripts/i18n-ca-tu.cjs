/* ===========================================================================
 * i18n-ca-tu.cjs
 * DOC-ADDR-1 (« tu » en ca, sans exception) — relevé le 27/09/2026 : la passe
 * du 07/09 n'avait relu que fr et es. ca.json s'adressait au membre au « vós »
 * dans 312 valeurs — « Voleu suprimir…? » (41 fois), « Indiqueu », « Seleccioneu »,
 * « Comproveu la vostra connexió i torneu a provar », « Introduïu el vostre
 * correu », « Se us redirigirà », toute la politique de confidentialité
 * (« les vostres dades ») — jusque sur l'écran de connexion.
 *
 * Réécriture générée puis RELUE clé par clé contre fr.json :
 *   — verbes : table forme du vós → [impératif, indicatif, subjonctif] du tu
 *     (« Voleu » → « Vols », « Repreneu » → « Reprèn », « feu » → « fes / fas /
 *     facis »), le mode choisi selon la place dans la phrase, puis tranché à la
 *     relecture (« mentre no facis clic », « El que has vist », « No escriguis
 *     mai ») ;
 *   — possessifs : genre pris à l'article (« els vostres » → « els teus »,
 *     « les vostres » → « les teves ») ;
 *   — clitiques : « us » → « et » / « t' », « se us » → « se't » / « se t' »,
 *     « -vos » → « -te » / « 't », « Elimineu-los » → « Elimina'ls ».
 * Vingt-trois valeurs ont demandé une correction à la main après la génération
 * (mode du verbe, « vós » → « tu », « Vegeu també » → « Veure també » comme le
 * « Voir aussi » français, « decidiu-ho juntes » → « cal decidir-ho juntes »).
 * Sept valeurs sans accents corrigées dans la même phrase (« coordinacio »,
 * « referencia bibliografica », « en us » → « en ús »), et une coquille
 * (« prefereixu » → « prefereix »).
 *
 * Restent au pluriel, parce qu'elles s'adressent à un collectif :
 * atelier.doctrine.text, banner.profile.body, rotativityHint, et
 * biblioteca.exchanges.suggestedMessage (lettre d'une bibliothèque à une autre :
 * « Hola, companyes i companys de {partner}. Us escrivim… »).
 *
 * Réécriture DE → PARA, rejouable. Les scripts d'origine (« ajout si absent »)
 * qui portaient ces valeurs sont corrigés dans le même commit — 46 sources,
 * dont deux écrites en NFD dans add-i18n-keys.cjs.
 * La garde : src/tests/i18n-ecriture.test.js, chemin (4), VOUVOIEMENT_CA.
 * Usage : node scripts/i18n-ca-tu.cjs
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const DOSSIER = path.join(__dirname, '..', 'src', 'i18n', 'locales');

// locale : { clé : [ancienne valeur, valeur au registre de la langue] }
const DE_PARA = {
  'ca': {
    'subject.related': [
      'Vegeu també',
      'Veure també',
    ],
    'address.country.placeholder': [
      '— Trieu un país —',
      '— Tria un país —',
    ],
    'address.phone.hint': [
      'El prefix del país es detecta automàticament. El podeu canviar si cal.',
      'El prefix del país es detecta automàticament. El pots canviar si cal.',
    ],
    'address.state.selectCountryFirst': [
      'Trieu primer un país',
      'Tria primer un país',
    ],
    'auth.captchaRequired': [
      'Espereu que finalitzi la verificació anti-bot abans de tornar a provar.',
      'Espera que finalitzi la verificació anti-bot abans de tornar a provar.',
    ],
    'auth.create.errorCreateFailed': [
      'Error en crear el compte. Si us plau, torneu-ho a provar.',
      'Error en crear el compte. Si et plau, torna-ho a provar.',
    ],
    'auth.create.errorGeneric': [
      'Error en el registre. Comuniqueu el codi seguent a la coordinacio',
      'Error en el registre. Comunica el codi següent a la coordinació',
    ],
    'auth.create.errorLibraryNotReady': [
      'La biblioteca seleccionada encara no esta completament configurada a la xarxa. Contacteu amb la coordinacio.',
      'La biblioteca seleccionada encara no està completament configurada a la xarxa. Contacta amb la coordinació.',
    ],
    'auth.create.errorProfileFailed': [
      'El compte s\'ha creat, pero hi ha hagut un error en configurar el vostre perfil. Contacteu amb la coordinacio.',
      'El compte s\'ha creat, però hi ha hagut un error en configurar el teu perfil. Contacta amb la coordinació.',
    ],
    'auth.create.errorServerConfig': [
      'Error de configuracio del servidor. Contacteu amb la coordinacio.',
      'Error de configuració del servidor. Contacta amb la coordinació.',
    ],
    'auth.create.fillRequired': [
      'Empleneu tots els camps obligatoris.',
      'Emplena tots els camps obligatoris.',
    ],
    'auth.create.privacyNotice': [
      'En crear el vostre compte, confieu les vostres dades personals a AnarBib i a la biblioteca adherida. Recollim només l\'estrictament necessari per a la circulació dels llibres i respectem els principis de minimització (RGPD/LGPD). Podeu exportar o suprimir les vostres dades en qualsevol moment.',
      'En crear el teu compte, confies les teves dades personals a AnarBib i a la biblioteca adherida. Recollim només l\'estrictament necessari per a la circulació dels llibres i respectem els principis de minimització (RGPD/LGPD). Pots exportar o suprimir les teves dades en qualsevol moment.',
    ],
    'auth.create.selectPh': [
      '— Trieu una biblioteca —',
      '— Tria una biblioteca —',
    ],
    'auth.forgotEmailRequired': [
      'Indiqueu el vostre correu electrònic.',
      'Indica el teu correu electrònic.',
    ],
    'auth.forgotHint': [
      'Indiqueu el correu electrònic registrat per rebre un enllaç de recuperació.',
      'Indica el correu electrònic registrat per rebre un enllaç de recuperació.',
    ],
    'auth.forgotSent': [
      'Si el correu electrònic està registrat, rebreu un enllaç ben aviat.',
      'Si el correu electrònic està registrat, rebràs un enllaç ben aviat.',
    ],
    'auth.forgotTitle': [
      'Heu oblidat la contrasenya?',
      'Has oblidat la contrasenya?',
    ],
    'auth.login.subtitle': [
      'Accediu al vostre compte amb el vostre correu electrònic o ID públic.',
      'Accedeix al teu compte amb el teu correu electrònic o ID públic.',
    ],
    'auth.networkError': [
      'Error de connexió. Comproveu la vostra connexió a internet i torneu a provar.',
      'Error de connexió. Comprova la teva connexió a internet i torna a provar.',
    ],
    'auth.notConfirmed': [
      'Confirmeu el vostre correu electrònic abans d\'iniciar la sessió.',
      'Confirma el teu correu electrònic abans d\'iniciar la sessió.',
    ],
    'auth.publicIdPh': [
      'Introduïu el vostre correu electrònic o ID públic',
      'Introdueix el teu correu electrònic o ID públic',
    ],
    'auth.resetExpired': [
      'Enllaç expirat. Demaneu un nou correu electrònic de recuperació.',
      'Enllaç expirat. Demana un nou correu electrònic de recuperació.',
    ],
    'auth.resetHint': [
      'Introduïu la vostra nova contrasenya dues vegades per confirmar-la.',
      'Introdueix la teva nova contrasenya dues vegades per confirmar-la.',
    ],
    'auth.resetSuccess': [
      'Contrasenya modificada correctament. Se us redirigirà cap a l\'inici de sessió.',
      'Contrasenya modificada correctament. Se\'t redirigirà cap a l\'inici de sessió.',
    ],
    'auth.wrongCredentials': [
      'Credencials no vàlides. Comproveu el vostre identificador (correu electrònic o ID públic) i la vostra contrasenya.',
      'Credencials no vàlides. Comprova el teu identificador (correu electrònic o ID públic) i la teva contrasenya.',
    ],
    'banner.profile.title': [
      'La vostra biblioteca funciona en {template}',
      'La teva biblioteca funciona en {template}',
    ],
    'biblioteca.exchanges.selectPartner': [
      'Seleccioneu una biblioteca',
      'Selecciona una biblioteca',
    ],
    'biblioteca.extPartner.dupHint': [
      'Socis similars ja registrats — verifiqueu abans de crear un duplicat:',
      'Socis similars ja registrats — verifica abans de crear un duplicat:',
    ],
    'biblioteca.extPartner.hint': [
      'Registreu un col·lectiu extern (que ha lliurat el seu catàleg en fitxer, p. ex. exportació Zotero). Es crearà com a entitat sòcia i estarà disponible com a font a la importació.',
      'Registra un col·lectiu extern (que ha lliurat el seu catàleg en fitxer, p. ex. exportació Zotero). Es crearà com a entitat sòcia i estarà disponible com a font a la importació.',
    ],
    'biblioteca.ill.discardConfirm': [
      'Voleu suprimir el préstec interbibliotecari núm. {id}? Aquesta acció és irreversible.',
      'Vols suprimir el préstec interbibliotecari núm. {id}? Aquesta acció és irreversible.',
    ],
    'biblioteca.ill.emptyItems': [
      'Cap exemplar afegit. Cerqueu un document a dalt i feu-hi clic per afegir-lo.',
      'Cap exemplar afegit. Cerca un document a dalt i fes-hi clic per afegir-lo.',
    ],
    'biblioteca.ill.select': [
      'Seleccioneu',
      'Selecciona',
    ],
    'biblioteca.ill.selectBoth': [
      'Seleccioneu la biblioteca prestadora i la manllevadora.',
      'Selecciona la biblioteca prestadora i la manllevadora.',
    ],
    'biblioteca.leitores.promoteConfirm': [
      'Voleu confirmar la promoció de {name} com a bibliotecari-ària-e? Aquesta persona rebrà un correu electrònic i accedirà al tauler de la biblioteca.',
      'Vols confirmar la promoció de {name} com a bibliotecari-ària-e? Aquesta persona rebrà un correu electrònic i accedirà al tauler de la biblioteca.',
    ],
    'biblioteca.leitores.proposeCoordConfirm': [
      'Voleu proposar {name} per a la coordinació? La coordinació no es dona en solitari: la proposta necessitarà l\'aval d\'una altra persona de l\'equip i després l\'acceptació de la persona afectada. Fins llavors, no canvia res.',
      'Vols proposar {name} per a la coordinació? La coordinació no es dona en solitari: la proposta necessitarà l\'aval d\'una altra persona de l\'equip i després l\'acceptació de la persona afectada. Fins llavors, no canvia res.',
    ],
    'biblioteca.leitores.proposeLibrarianConfirm': [
      'Voleu proposar {name} per a l\'equip com a bibliotecari-ària-e? L\'acollida és col·legiada: la proposta necessitarà l\'aval de l\'equip i després l\'acceptació de la persona afectada. Fins llavors, no canvia res.',
      'Vols proposar {name} per a l\'equip com a bibliotecari-ària-e? L\'acollida és col·legiada: la proposta necessitarà l\'aval de l\'equip i després l\'acceptació de la persona afectada. Fins llavors, no canvia res.',
    ],
    'biblioteca.msg.selectPdf': [
      'Seleccioneu un fitxer PDF.',
      'Selecciona un fitxer PDF.',
    ],
    'biblioteca.privacy.editHint': [
      'Deixeu un camp buit per fer servir el valor per defecte d\'AnarBib. Introduïu 0 per a una retenció il·limitada (no recomanada).',
      'Deixa un camp buit per fer servir el valor per defecte d\'AnarBib. Introdueix 0 per a una retenció il·limitada (no recomanada).',
    ],
    'biblioteca.privacy.readonlyHint': [
      'Esteu en mode de només lectura. Només els-les-les coordinadors-es-es i administradors-es-es poden modificar la política de retenció.',
      'Estàs en mode de només lectura. Només els-les-les coordinadors-es-es i administradors-es-es poden modificar la política de retenció.',
    ],
    'biblioteca.privacy.resetHint': [
      'Els camps s\'han buidat. Feu clic a Desar per confirmar la restauració dels valors per defecte.',
      'Els camps s\'han buidat. Fes clic a Desar per confirmar la restauració dels valors per defecte.',
    ],
    'biblioteca.privacy.subtitle': [
      'Configureu el temps durant el qual la biblioteca conserva les dades personals abans de suprimir-les automàticament. Aquesta política aplica el principi de minimització (RGPD article 5(1)(e) / LGPD article 6).',
      'Configura el temps durant el qual la biblioteca conserva les dades personals abans de suprimir-les automàticament. Aquesta política aplica el principi de minimització (RGPD article 5(1)(e) / LGPD article 6).',
    ],
    'biblioteca.reservation.allowCounterProposal.hint': [
      'Quan està activat, els-les-les lectors-es-es poden proposar una altra franja que la suggerida per la vostra biblioteca. Si la vostra biblioteca funciona amb franges fixes, podeu desactivar aquesta opció.',
      'Quan està activat, els-les-les lectors-es-es poden proposar una altra franja que la suggerida per la teva biblioteca. Si la teva biblioteca funciona amb franges fixes, pots desactivar aquesta opció.',
    ],
    'biblioteca.reservation.subtitle': [
      'Com negocia la vostra biblioteca les franges de recollida amb els-les-les lectors-es-es.',
      'Com negocia la teva biblioteca les franges de recollida amb els-les-les lectors-es-es.',
    ],
    'biblioteca.rules.deleteWarning': [
      '⚠ Voleu suprimir definitivament «{name}»?\n\nLes regles «Base legada» són el comportament per defecte de la biblioteca mentre no es configurin regles pròpies. Suprimir-les pot deixar la biblioteca sense cap regla de circulació.\n\nAquesta acció és irreversible.',
      '⚠ Vols suprimir definitivament «{name}»?\n\nLes regles «Base legada» són el comportament per defecte de la biblioteca mentre no es configurin regles pròpies. Suprimir-les pot deixar la biblioteca sense cap regla de circulació.\n\nAquesta acció és irreversible.',
    ],
    'biblioteca.tasks.discardConfirm': [
      'Voleu suprimir aquesta tasca?',
      'Vols suprimir aquesta tasca?',
    ],
    'biblioteca.tasks.titleRequired': [
      'Indiqueu el títol de la tasca.',
      'Indica el títol de la tasca.',
    ],
    'biblioteca.templates.deleteConfirm': [
      'Voleu suprimir la plantilla « {title} »? Les tasques ja creades a partir d’ella no es veuen afectades.',
      'Vols suprimir la plantilla « {title} »? Les tasques ja creades a partir d’ella no es veuen afectades.',
    ],
    'biblioteca.visualAssets.confirm.remove': [
      'Voleu suprimir el fitxer {name}? Aquesta acció és irreversible.',
      'Vols suprimir el fitxer {name}? Aquesta acció és irreversible.',
    ],
    'biblioteca.visualAssets.helper': [
      'Logotip, favicon, fons i fitxer JSON de manifest aplicats al tema de la biblioteca. Pengeu els fitxers amb els noms canònics de més avall. Es fan públics i l\'aplicació els llegeix directament.',
      'Logotip, favicon, fons i fitxer JSON de manifest aplicats al tema de la biblioteca. Penja els fitxers amb els noms canònics de més avall. Es fan públics i l\'aplicació els llegeix directament.',
    ],
    'biblioteca.visualAssets.manifestHelp': [
      'No sabeu per on començar amb manifest.json? Baixeu un model preemplenat amb el slug i el nom de la biblioteca, ajusteu colors i tipografies segons la identitat del col·lectiu, i pengeu el resultat.',
      'No saps per on començar amb manifest.json? Baixa un model preemplenat amb el slug i el nom de la biblioteca, ajusta colors i tipografies segons la identitat del col·lectiu, i penja el resultat.',
    ],
    'biblioteca.visualAssets.noSlug': [
      'Aquesta biblioteca encara no té cap slug. Definiu el slug abans de configurar la identitat visual.',
      'Aquesta biblioteca encara no té cap slug. Defineix el slug abans de configurar la identitat visual.',
    ],
    'book.alreadyInWishlist': [
      'Aquest document ja és a la vostra llista de desitjos.',
      'Aquest document ja és a la teva llista de desitjos.',
    ],
    'book.attachLibraryHint': [
      'Vinculeu-vos a una biblioteca per sol·licitar una consulta',
      'Vincula\'t a una biblioteca per sol·licitar una consulta',
    ],
    'book.savedToWishlist': [
      'Document afegit a la vostra llista de desitjos.',
      'Document afegit a la teva llista de desitjos.',
    ],
    'catalog.avail.unavailUser': [
      'No disponible per a vós',
      'No disponible per a tu',
    ],
    'catalog.filters.authorPlaceholder': [
      'Escriviu una part del nom per filtrar per autor-a-e',
      'Escriu una part del nom per filtrar per autor-a-e',
    ],
    'catalog.filters.publisherPlaceholder': [
      'Escriviu una part del nom de l\'editorial per filtrar',
      'Escriu una part del nom de l\'editorial per filtrar',
    ],
    'catalog.quickConsulta.doneHint': [
      'Consulta ja sol·licitada. Vegeu-ho a El meu compte > Consultes.',
      'Consulta ja sol·licitada. Mira-ho a El meu compte > Consultes.',
    ],
    'catalog.quickReserve.doneHint': [
      'Heu reservat aquest llibre. Vegeu-ho a El meu compte › Reserves.',
      'Has reservat aquest llibre. Mira-ho a El meu compte › Reserves.',
    ],
    'catalog.quickReserve.hint': [
      'Reservar aquest llibre a la vostra biblioteca amb un clic',
      'Reservar aquest llibre a la teva biblioteca amb un clic',
    ],
    'catalog.quickReserve.notInMyLibrary': [
      'Aquest llibre no està disponible a la vostra biblioteca.',
      'Aquest llibre no està disponible a la teva biblioteca.',
    ],
    'catalog.session.connected': [
      'Sessió iniciada — veieu el catàleg de la xarxa; disponibilitats i reserves mostrades per a la vostra biblioteca',
      'Sessió iniciada — veus el catàleg de la xarxa; disponibilitats i reserves mostrades per a la teva biblioteca',
    ],
    'catalog.table.sortHint': [
      'Feu clic a una capçalera per ordenar',
      'Fes clic a una capçalera per ordenar',
    ],
    'catalogacao.author.nameAssistDesc': [
      'Useu quan el nom ve en brut de la BN, un llibre o una altra font.',
      'Usa quan el nom ve en brut de la BN, un llibre o una altra font.',
    ],
    'catalogacao.author.nameRequired': [
      'Indiqueu el nom preferit.',
      'Indica el nom preferit.',
    ],
    'catalogacao.nameEntry.pickSurname': [
      'Feu clic a la paraula on comença el cognom',
      'Fes clic a la paraula on comença el cognom',
    ],
    'catalogacao.nameEntry.caseHint': [
      'Un ús propi del nom (De Amicis, bell hooks)? Feu clic a la paraula per tornar-li o treure-li la majúscula.',
      'Un ús propi del nom (De Amicis, bell hooks)? Fes clic a la paraula per tornar-li o treure-li la majúscula.',
    ],
    'catalogacao.author.sourceKind.select': [
      'Seleccioneu…',
      'Selecciona…',
    ],
    'catalogacao.batchHasDrafts': [
      'Aquest lot encara té {count} esborrany(s). Elimineu-los abans d\'eliminar el lot.',
      'Aquest lot encara té {count} esborrany(s). Elimina\'ls abans d\'eliminar el lot.',
    ],
    'catalogacao.batchNameRequired': [
      'Indiqueu el nom del lot.',
      'Indica el nom del lot.',
    ],
    'catalogacao.catalog.description': [
      'Consulteu documents, autoritats i exemplars publicats. Repreneu per editar o descarteu del catàleg.',
      'Consulta documents, autoritats i exemplars publicats. Reprèn per editar o descarta del catàleg.',
    ],
    'catalogacao.catalog.refreshBusy': [
      'Actualització ja en curs — torneu a provar en un moment.',
      'Actualització ja en curs — torna a provar en un moment.',
    ],
    'catalogacao.catalog.retakeCreatedNoEdit': [
      'Esborrany de represa creat (ID {id}). Obriu la pestanya corresponent per editar.',
      'Esborrany de represa creat (ID {id}). Obre la pestanya corresponent per editar.',
    ],
    'catalogacao.closeBatchConfirm': [
      'Voleu tancar aquest lot? Els esborranys continuaran sent accessibles.',
      'Vols tancar aquest lot? Els esborranys continuaran sent accessibles.',
    ],
    'catalogacao.exemplar.autoExemplarInfo': [
      'En publicar un document nou, es crea automàticament un exemplar amb la referència bibliogràfica (bib_ref) com a número de registre. Feu servir aquest formulari només per afegir exemplars addicionals o ajustar les dades d\'un exemplar existent.',
      'En publicar un document nou, es crea automàticament un exemplar amb la referència bibliogràfica (bib_ref) com a número de registre. Fes servir aquest formulari només per afegir exemplars addicionals o ajustar les dades d\'un exemplar existent.',
    ],
    'catalogacao.exemplar.bibRefHint': [
      'Introduiu i sortiu del camp per cercar automàticament.',
      'Introdueix i surt del camp per cercar automàticament.',
    ],
    'catalogacao.exemplar.labelMarked': [
      'Etiqueta marcada com a punt. Deseu l\'esborrany per confirmar.',
      'Etiqueta marcada com a punt. Desa l\'esborrany per confirmar.',
    ],
    'catalogacao.exemplar.labelNeedFields': [
      'Empleneu almenys autor-a-e, títol o CDD a l\'etiqueta.',
      'Emplena almenys autor-a-e, títol o CDD a l\'etiqueta.',
    ],
    'catalogacao.exemplar.labelStepDesc': [
      'L\'etiqueta es calcula des del document d\'origen. Sobreescriviu només si cal.',
      'L\'etiqueta es calcula des del document d\'origen. Sobreescriu només si cal.',
    ],
    'catalogacao.exemplar.materialStepDesc': [
      'Identifiqueu l\'objecte físic: registre, biblioteca i ubicació.',
      'Identifica l\'objecte físic: registre, biblioteca i ubicació.',
    ],
    'catalogacao.exemplar.originHint': [
      'Cerqueu per títol o ref. per vincular l\'exemplar.',
      'Cerca per títol o ref. per vincular l\'exemplar.',
    ],
    'catalogacao.exemplar.originStepDesc': [
      'Localitzeu la fitxa comuna publicada.',
      'Localitza la fitxa comuna publicada.',
    ],
    'catalogacao.exemplar.refOrTomboRequired': [
      'Indiqueu almenys la referència o el registre.',
      'Indica almenys la referència o el registre.',
    ],
    'catalogacao.field.discardConfirm': [
      'Voleu suprimir aquest esborrany?',
      'Vols suprimir aquest esborrany?',
    ],
    'catalogacao.titleCase.properHint': [
      'Un nom propi? Feu clic a la paraula per tornar-li (o treure-li) la majúscula.',
      'Un nom propi? Fes clic a la paraula per tornar-li (o treure-li) la majúscula.',
    ],
    'catalogacao.field.searchMetaHint': [
      'Indiqueu almenys un ISBN, ISSN o títol abans de cercar.',
      'Indica almenys un ISBN, ISSN o títol abans de cercar.',
    ],
    'catalogacao.guide.livro.hint': [
      'Feu servir el nucli de la fitxa. Passeu al mode complet per a més detalls.',
      'Fes servir el nucli de la fitxa. Passa al mode complet per a més detalls.',
    ],
    'catalogacao.infocard.exemplarUnsaved': [
      'Deseu la fitxa per gestionar exemplars',
      'Desa la fitxa per gestionar exemplars',
    ],
    'catalogacao.isbd.notGenerated': [
      'ISBD: encara no generat per a aquest esborrany. Feu clic a "Preparar ISBD" a dalt.',
      'ISBD: encara no generat per a aquest esborrany. Fes clic a "Preparar ISBD" a dalt.',
    ],
    'catalogacao.msg.bibRefDuplicate': [
      'La referencia bibliografica {bibRef} ja esta en us (fitxa {bookId}). Canvieu-la abans de publicar.',
      'La referència bibliogràfica {bibRef} ja està en ús (fitxa {bookId}). Canvia-la abans de publicar.',
    ],
    'catalogacao.msg.enterTitle': [
      'Indiqueu el títol del document.',
      'Indica el títol del document.',
    ],
    'catalogacao.msg.needBasicFields': [
      'Indiqueu almenys un ISBN, ISSN, títol o autor-a-e.',
      'Indica almenys un ISBN, ISSN, títol o autor-a-e.',
    ],
    'catalogacao.msg.needIsbnOrTitle': [
      'Indiqueu almenys un ISBN, ISSN o títol abans de cercar.',
      'Indica almenys un ISBN, ISSN o títol abans de cercar.',
    ],
    'catalogacao.msg.publishConfirm': [
      'Voleu publicar aquest esborrany? Un cop publicat, apareixerà al catàleg.',
      'Vols publicar aquest esborrany? Un cop publicat, apareixerà al catàleg.',
    ],
    'catalogacao.noBatches': [
      'Cap lot trobat. Creeu el primer lot a dalt.',
      'Cap lot trobat. Crea el primer lot a dalt.',
    ],
    'catalogacao.ph.bioHint': [
      'Es pot editar per llengua. Feu servir el selector per a altres traduccions.',
      'Es pot editar per llengua. Fes servir el selector per a altres traduccions.',
    ],
    'catalogacao.presave.isbnExists': [
      'ISBN ja existent al catàleg: {detail}.\n\nVoleu continuar desant de totes maneres?',
      'ISBN ja existent al catàleg: {detail}.\n\nVols continuar desant de totes maneres?',
    ],
    'catalogacao.presave.titleAuthorExists': [
      'Títol + autoria ja existents al catàleg: {detail}.\n\nVoleu continuar desant de totes maneres?',
      'Títol + autoria ja existents al catàleg: {detail}.\n\nVols continuar desant de totes maneres?',
    ],
    'catalogacao.publishBatchConfirm': [
      'Voleu publicar tots els esborranys a punt d\'aquest lot? Aquesta acció és irreversible.',
      'Vols publicar tots els esborranys a punt d\'aquest lot? Aquesta acció és irreversible.',
    ],
    'catalogacao.publishConfirm': [
      'Voleu publicar aquesta fitxa?',
      'Vols publicar aquesta fitxa?',
    ],
    'catalogacao.queue.description': [
      'Esborranys actius de documents, autoritats i exemplars. Gestioneu el cicle de vida: editeu, marqueu com a preparat, publiqueu o descarteu.',
      'Esborranys actius de documents, autoritats i exemplars. Gestiona el cicle de vida: edita, marca com a preparat, publica o descarta.',
    ],
    'catalogacao.queue.selectAtLeast': [
      'Seleccioneu almenys un element.',
      'Selecciona almenys un element.',
    ],
    'catalogacao.queue.trashDescription': [
      'Esborranys descartats. Podeu restaurar o eliminar definitivament.',
      'Esborranys descartats. Pots restaurar o eliminar definitivament.',
    ],
    'catalogacao.reassign.multiHint': [
      'Aquest registre té exemplars en diverses biblioteques; trieu de quina moure.',
      'Aquest registre té exemplars en diverses biblioteques; tria de quina moure.',
    ],
    'catalogacao.reassign.sourcePick': [
      'Trieu la biblioteca d\'origen…',
      'Tria la biblioteca d\'origen…',
    ],
    'catalogacao.subjects.saveFirst': [
      'Deseu l\'esborrany per indexar per matèries.',
      'Desa l\'esborrany per indexar per matèries.',
    ],
    'catalogacao.ui.labelFillHint': [
      'Empleneu autor-a-e, títol o CDD per generar la simulació.',
      'Emplena autor-a-e, títol o CDD per generar la simulació.',
    ],
    'catalogacao.ui.reviewHint': [
      'Feu servir aquest plafó per rellegir la fitxa, veure la sortida pública mínima o verificar el paquet ISBD.',
      'Fes servir aquest plafó per rellegir la fitxa, veure la sortida pública mínima o verificar el paquet ISBD.',
    ],
    'catalogacao.wizard.step.autoria.body': [
      'Gestioneu les autories (persones i organitzacions) vinculades als documents. Cada autoria creada aquí es pot associar a diversos llibres i viceversa.',
      'Gestiona les autories (persones i organitzacions) vinculades als documents. Cada autoria creada aquí es pot associar a diversos llibres i viceversa.',
    ],
    'catalogacao.wizard.step.autoria.tip': [
      'L\'autocompleció suggereix autories existents en escriure el nom — eviteu duplicats!',
      'L\'autocompleció suggereix autories existents en escriure el nom — evita duplicats!',
    ],
    'catalogacao.wizard.step.dicas.body': [
      '• El tombo (número d\'inventari) s\'emplena automàticament segons la convenció de la vostra biblioteca.\n• En publicar un document, es crea automàticament un exemplar.\n• Els missatges d\'error apareixen al costat del camp afectat.\n• Alterneu entre els modes Simple / Avançat / Complet a la barra superior per mostrar més o menys camps.',
      '• El tombo (número d\'inventari) s\'emplena automàticament segons la convenció de la teva biblioteca.\n• En publicar un document, es crea automàticament un exemplar.\n• Els missatges d\'error apareixen al costat del camp afectat.\n• Alterna entre els modes Simple / Avançat / Complet a la barra superior per mostrar més o menys camps.',
    ],
    'catalogacao.wizard.step.documento.body': [
      'Creeu i editeu fitxes bibliogràfiques (llibres, fullets, periòdics…). Empleneu el títol, autoria, ISBN, tipus de material i referència bibliogràfica. Feu servir el mode Simple per a l\'essencial o Complet per a tots els camps.',
      'Crea i edita fitxes bibliogràfiques (llibres, fullets, periòdics…). Emplena el títol, autoria, ISBN, tipus de material i referència bibliogràfica. Fes servir el mode Simple per a l\'essencial o Complet per a tots els camps.',
    ],
    'catalogacao.wizard.step.etiquetas.body': [
      'Imprimiu etiquetes de signatura per als exemplars de la vostra biblioteca. Seleccioneu els exemplars de la llista, trieu quins camps incloure (autoria, títol, tombo, nota) i genereu un full A4 llest per imprimir, amb codi QR opcional.',
      'Imprimeix etiquetes de signatura per als exemplars de la teva biblioteca. Selecciona els exemplars de la llista, tria quins camps incloure (autoria, títol, tombo, nota) i genera un full A4 llest per imprimir, amb codi QR opcional.',
    ],
    'catalogacao.wizard.step.etiquetas.tip': [
      'Les vostres preferències de camps es desen automàticament — no cal reconfigurar cada cop.',
      'Les teves preferències de camps es desen automàticament — no cal reconfigurar cada cop.',
    ],
    'catalogacao.wizard.step.indexacao.body': [
      'Registreu exemplars (còpies físiques) vinculats a un document. Cada exemplar té un tombo (número d\'inventari), una política de circulació i un rètol per a l\'etiqueta de signatura.',
      'Registra exemplars (còpies físiques) vinculats a un document. Cada exemplar té un tombo (número d\'inventari), una política de circulació i un rètol per a l\'etiqueta de signatura.',
    ],
    'catalogacao.wizard.step.indexacao.tip': [
      'El camp Tombo s\'emplena automàticament amb la propera referència segons la convenció de la vostra biblioteca.',
      'El camp Tombo s\'emplena automàticament amb la propera referència segons la convenció de la teva biblioteca.',
    ],
    'catalogacao.wizard.step.welcome.body': [
      'Aquesta guia presenta les principals funcionalitats del mòdul de catalogació. Navegueu pels passos per descobrir cada pestanya i les seves eines.',
      'Aquesta guia presenta les principals funcionalitats del mòdul de catalogació. Navega pels passos per descobrir cada pestanya i les seves eines.',
    ],
    'error.library.circulation_disabled': [
      'La circulació està desactivada per a aquesta biblioteca. No es poden crear préstecs, reserves ni sol·licituds de consulta. Contacteu amb la coordinació per a més informació.',
      'La circulació està desactivada per a aquesta biblioteca. No es poden crear préstecs, reserves ni sol·licituds de consulta. Contacta amb la coordinació per a més informació.',
    ],
    'federacao.circulos.dormancy.adormecer.done': [
      'Cercle adormit. Es pot despertar quan vulgueu.',
      'Cercle adormit. Es pot despertar quan vulguis.',
    ],
    'idle.warning.message': [
      'Per seguretat, se us desconnectarà d\'aquí a {seconds} segons.',
      'Per seguretat, se\'t desconnectarà d\'aquí a {seconds} segons.',
    ],
    'importacoes.adapter.profileDeleteConfirm': [
      'Voleu suprimir aquest perfil?',
      'Vols suprimir aquest perfil?',
    ],
    'importacoes.bulkDraftsConfirm': [
      'Voleu generar esborranys a partir del processament núm. {id}?',
      'Vols generar esborranys a partir del processament núm. {id}?',
    ],
    'importacoes.deleteRunConfirm': [
      'Voleu suprimir el tractament #{id} i el seu fitxer? Els esborranys ja creats es conserven.',
      'Vols suprimir el tractament #{id} i el seu fitxer? Els esborranys ja creats es conserven.',
    ],
    'importacoes.enterRssUrl': [
      'Indiqueu l\'URL del canal RSS/Atom.',
      'Indica l\'URL del canal RSS/Atom.',
    ],
    'importacoes.enterUrl': [
      'Indiqueu una URL.',
      'Indica una URL.',
    ],
    'importacoes.fila.failed.desc': [
      'Aquest lot no s’ha pogut processar. El podeu arxivar o eliminar a la llista de lots.',
      'Aquest lot no s’ha pogut processar. El pots arxivar o eliminar a la llista de lots.',
    ],
    'importacoes.fila.processing.desc': [
      'Les línies encara s’analitzen i es comparen amb el catàleg. Espereu i actualitzeu d’aquí a poc.',
      'Les línies encara s’analitzen i es comparen amb el catàleg. Espera i actualitza d’aquí a poc.',
    ],
    'importacoes.fila.selectRun': [
      'Seleccioneu un tractament a dalt per veure les línies en revisió.',
      'Selecciona un tractament a dalt per veure les línies en revisió.',
    ],
    'importacoes.file.selectSource': [
      'Seleccioneu una font',
      'Selecciona una font',
    ],
    'importacoes.fontes.noCompanheiras': [
      'Cap biblioteca companya registrada. Creeu una relació d’associació per activar la importació recíproca.',
      'Cap biblioteca companya registrada. Crea una relació d’associació per activar la importació recíproca.',
    ],
    'importacoes.oai.noSources': [
      'Cap font OAI-PMH configurada. Contacteu le administrador-a-e de xarxa.',
      'Cap font OAI-PMH configurada. Contacta le administrador-a-e de xarxa.',
    ],
    'importacoes.selectFile': [
      'Seleccioneu un fitxer.',
      'Selecciona un fitxer.',
    ],
    'importacoes.selectSource': [
      'Seleccioneu una font sòcia.',
      'Selecciona una font sòcia.',
    ],
    'importacoes.wizard.preview.dupBody': [
      'En un catàleg mutualitzat, crear un duplicat genera incoherències greus. Aquestes línies NO es promouran automàticament — verifiqueu-les i prefereixu vincular a la fitxa existent.',
      'En un catàleg mutualitzat, crear un duplicat genera incoherències greus. Aquestes línies NO es promouran automàticament — verifica-les i prefereix vincular a la fitxa existent.',
    ],
    'importacoes.wizard.promote.heldBack': [
      '{n} línia/es retinguda/es, no promogudes (duplicats potencials o a revisar) — tracteu-les manualment per evitar incoherències.',
      '{n} línia/es retinguda/es, no promogudes (duplicats potencials o a revisar) — tracta-les manualment per evitar incoherències.',
    ],
    'importacoes.wizard.source.ingested': [
      'Fitxa importada. Aneu a la vista prèvia.',
      'Fitxa importada. Vés a la vista prèvia.',
    ],
    'importacoes.wizard.source.noSources': [
      'Cap font associada. Creeu-ne una des de la pàgina Importações.',
      'Cap font associada. Crea\'n una des de la pàgina Importações.',
    ],
    'importacoes.wizard.source.ready': [
      'Lot importat (run #{id}). Aneu a la vista prèvia.',
      'Lot importat (run #{id}). Vés a la vista prèvia.',
    ],
    'labels.deleteConfirm': [
      'Voleu eliminar {count} exemplar(s)? Acció irreversible. Els exemplars amb historial de circulació estan protegits.',
      'Vols eliminar {count} exemplar(s)? Acció irreversible. Els exemplars amb historial de circulació estan protegits.',
    ],
    'labels.fieldsConfigHint': [
      'Marqueu els camps opcionals a incloure a les etiquetes impreses.',
      'Marca els camps opcionals a incloure a les etiquetes impreses.',
    ],
    'labels.format.sectionHint': [
      'Trieu un format de full comercial, o personalitzeu les mides manualment.',
      'Tria un format de full comercial, o personalitza les mides manualment.',
    ],
    'labels.format.unverifiedHint': [
      'Mides estimades (no confirmades a la fitxa tècnica del fabricant) — ajusteu a «Personalitzat» si cal.',
      'Mides estimades (no confirmades a la fitxa tècnica del fabricant) — ajusta a «Personalitzat» si cal.',
    ],
    'labels.hint': [
      'Seleccioneu els exemplars per generar un plec d\'etiquetes imprimible. Feu clic a les files per seleccionar.',
      'Selecciona els exemplars per generar un plec d\'etiquetes imprimible. Fes clic a les files per seleccionar.',
    ],
    'login.reason.idle': [
      'Se us ha desconnectat després de 60 minuts d\'inactivitat. Torneu a iniciar la sessió per continuar.',
      'Se t\'ha desconnectat després de 60 minuts d\'inactivitat. Torna a iniciar la sessió per continuar.',
    ],
    'login.reason.sessionEnded': [
      'La vostra sessió ha acabat: les sessions de l\'equip de la biblioteca no es conserven en tancar el navegador. Torneu a iniciar la sessió per continuar.',
      'La teva sessió ha acabat: les sessions de l\'equip de la biblioteca no es conserven en tancar el navegador. Torna a iniciar la sessió per continuar.',
    ],
    'notif.rgpd.purgeWarning.consultations.body': [
      'Algunes consultes in situ finalitzades del vostre historial se suprimiran automàticament durant els 30 dies vinents. Podeu exportar les vostres dades des de la pàgina El meu compte abans de la supressió.',
      'Algunes consultes in situ finalitzades del teu historial se suprimiran automàticament durant els 30 dies vinents. Pots exportar les teves dades des de la pàgina El meu compte abans de la supressió.',
    ],
    'notif.rgpd.purgeWarning.loans.body': [
      'D\'acord amb la política de retenció de la biblioteca, alguns préstecs del vostre historial se suprimiran automàticament durant els 30 dies vinents. Si els voleu conservar, exporteu les vostres dades des de la pàgina El meu compte abans de la supressió.',
      'D\'acord amb la política de retenció de la biblioteca, alguns préstecs del teu historial se suprimiran automàticament durant els 30 dies vinents. Si els vols conservar, exporta les teves dades des de la pàgina El meu compte abans de la supressió.',
    ],
    'notif.rgpd.purgeWarning.reservations.body': [
      'Algunes reserves finalitzades del vostre historial se suprimiran automàticament durant els 30 dies vinents. Podeu exportar les vostres dades des de la pàgina El meu compte abans de la supressió.',
      'Algunes reserves finalitzades del teu historial se suprimiran automàticament durant els 30 dies vinents. Pots exportar les teves dades des de la pàgina El meu compte abans de la supressió.',
    ],
    'panel.action.selectAtLeastOne': [
      'Seleccioneu almenys una reserva.',
      'Selecciona almenys una reserva.',
    ],
    'panel.action.selectStep': [
      'Seleccioneu una etapa.',
      'Selecciona una etapa.',
    ],
    'panel.apiError.bib_ref_duplicado': [
      'Aquesta referencia bibliografica ja esta en us per una altra fitxa. Canvieu-la abans de publicar.',
      'Aquesta referència bibliogràfica ja està en ús per una altra fitxa. Canvia-la abans de publicar.',
    ],
    'panel.apiError.isbn_duplicado': [
      'Ja existeix una fitxa publicada amb el mateix ISBN a la xarxa. Reviseu l\'ISBN o afegiu un exemplar a la fitxa existent.',
      'Ja existeix una fitxa publicada amb el mateix ISBN a la xarxa. Revisa l\'ISBN o afegeix un exemplar a la fitxa existent.',
    ],
    'panel.consultation.noShowConfirm': [
      'Voleu confirmar que la persona lectora no ha vingut?',
      'Vols confirmar que la persona lectora no ha vingut?',
    ],
    'panel.consultation.schedule.notePlaceholder': [
      'Ex.: ens trobem a la recepció. Pregunteu per la Marie.',
      'Ex.: ens trobem a la recepció. Pregunta per la Marie.',
    ],
    'panel.loan.enterLoanId': [
      'Indiqueu l\'ID del préstec.',
      'Indica l\'ID del préstec.',
    ],
    'panel.loan.enterSubIds': [
      'Indiqueu els IDs dels articles (ex.: 154.1, 154.2).',
      'Indica els IDs dels articles (ex.: 154.1, 154.2).',
    ],
    'panel.loan.errorMissing': [
      'Indiqueu l\'ID/correu electrònic del-de la-de le lector-a-e i les referències.',
      'Indica l\'ID/correu electrònic del-de la-de le lector-a-e i les referències.',
    ],
    'panel.loan.preview.confirm': [
      'Previsualització: {count, plural, one {# document} other {# documents}} per a {name}, devolució prevista el {dueDate} (regla: {rule}). Feu clic a Confirmar per validar.',
      'Previsualització: {count, plural, one {# document} other {# documents}} per a {name}, devolució prevista el {dueDate} (regla: {rule}). Fes clic a Confirmar per validar.',
    ],
    'panel.memberships.hint': [
      'Visió de conjunt dels-de les-de les lectors-es-es i dels seus pagaments. Feu servir el botó «+» per registrar una quota.',
      'Visió de conjunt dels-de les-de les lectors-es-es i dels seus pagaments. Fes servir el botó «+» per registrar una quota.',
    ],
    'panel.memberships.noRulesWarning.body': [
      'Heu activat el sistema de quotes, però no hi ha cap regla registrada. Creeu-ne almenys una per poder registrar pagaments.',
      'Has activat el sistema de quotes, però no hi ha cap regla registrada. Crea\'n almenys una per poder registrar pagaments.',
    ],
    'panel.reader.restrictConfirm': [
      'Voleu restringir l\'accés d\'aquest-a-e lector-a-e?',
      'Vols restringir l\'accés d\'aquest-a-e lector-a-e?',
    ],
    'panel.reader.unrestrictConfirm': [
      'Voleu aixecar la restricció d\'aquest-a-e lector-a-e?',
      'Vols aixecar la restricció d\'aquest-a-e lector-a-e?',
    ],
    'panel.reservations.menuHelp': [
      'Recollida efectiva: feu servir el botó dedicat «Confirmar recollida» quan la reserva estigui a punt. Alliberament en circulació: automàtic després d\'una no presentació o d\'una cancel·lació per part de la biblioteca.',
      'Recollida efectiva: fes servir el botó dedicat «Confirmar recollida» quan la reserva estigui a punt. Alliberament en circulació: automàtic després d\'una no presentació o d\'una cancel·lació per part de la biblioteca.',
    ],
    'panel.return.partial.preview.confirm': [
      'Devolució parcial de {count, plural, one {# ítem} other {# ítems}} : {ids}. Cliqueu de nou per confirmar.',
      'Devolució parcial de {count, plural, one {# ítem} other {# ítems}} : {ids}. Clica de nou per confirmar.',
    ],
    'panel.return.total.preview.confirm': [
      'Devolució total : préstec #{id} de {borrower}, {count, plural, one {# ítem} other {# ítems}}. Cliqueu de nou per confirmar.',
      'Devolució total : préstec #{id} de {borrower}, {count, plural, one {# ítem} other {# ítems}}. Clica de nou per confirmar.',
    ],
    'panel.tasks.createAt': [
      'Creeu tasques a la pàgina Biblioteca, pestanya «Tasques internes».',
      'Crea tasques a la pàgina Biblioteca, pestanya «Tasques internes».',
    ],
    'panel.tasks.emptyHint': [
      'Creeu tasques a la pàgina <link>Biblioteca</link>, pestanya «Tasques internes».',
      'Crea tasques a la pàgina <link>Biblioteca</link>, pestanya «Tasques internes».',
    ],
    'privacy.declared.body1': [
      'Si, en crear el vostre compte, ens vau indicar el nom d\'una biblioteca que encara no és a AnarBib, aquesta informació es conserva perquè, si aquesta biblioteca s\'adhereix algun dia a la nostra xarxa, us puguem proposar un vincle com a lectore.',
      'Si, en crear el teu compte, ens vas indicar el nom d\'una biblioteca que encara no és a AnarBib, aquesta informació es conserva perquè, si aquesta biblioteca s\'adhereix algun dia a la nostra xarxa, et puguem proposar un vincle com a lectore.',
    ],
    'privacy.declared.body2': [
      'Aquesta informació no es comparteix amb tercers. Només és llegible per l\'equip que administra la xarxa AnarBib. Podeu consultar, modificar o esborrar aquesta informació en qualsevol moment des del vostre compte (secció Les meves dades).',
      'Aquesta informació no es comparteix amb tercers. Només és llegible per l\'equip que administra la xarxa AnarBib. Pots consultar, modificar o esborrar aquesta informació en qualsevol moment des del teu compte (secció Les meves dades).',
    ],
    'privacy.intro': [
      'Aquesta política explica quines dades personals recull AnarBib, per què es recullen, amb qui es comparteixen i quins drets hi teniu. El text s\'aplica a totes les biblioteques que fan servir el sistema AnarBib.',
      'Aquesta política explica quines dades personals recull AnarBib, per què es recullen, amb qui es comparteixen i quins drets hi tens. El text s\'aplica a totes les biblioteques que fan servir el sistema AnarBib.',
    ],
    'privacy.lib.fallback': [
      'Aquesta secció encara no s\'ha traduït a la vostra llengua. El text de més avall és en portuguès.',
      'Aquesta secció encara no s\'ha traduït a la teva llengua. El text de més avall és en portuguès.',
    ],
    'privacy.retention.override': [
      'Cada biblioteca pot adoptar terminis més curts (o més llargs, per decisió col·lectiva justificada). Els terminis vigents a la vostra biblioteca poden estar indicats a la secció específica de més avall, si n\'ha publicat una.',
      'Cada biblioteca pot adoptar terminis més curts (o més llargs, per decisió col·lectiva justificada). Els terminis vigents a la teva biblioteca poden estar indicats a la secció específica de més avall, si n\'ha publicat una.',
    ],
    'privacy.retention.profile': [
      'Perfil i dades de registre: conservats mentre el vostre compte existeixi',
      'Perfil i dades de registre: conservats mentre el teu compte existeixi',
    ],
    'privacy.retention.title': [
      'Quant de temps conservem les vostres dades',
      'Quant de temps conservem les teves dades',
    ],
    'privacy.s1.body': [
      'Cada biblioteca de la xarxa AnarBib és responsable del tractament de les dades dels-de les-de les seus-seves-seves lectors-es-es en el sentit del RGPD (article 4.7) i de la LGPD brasilera (article 5, VI). AnarBib, com a sistema tècnic operat pel Centro de Cultura Libertária da Amazônia (CCLA), és encarregat del tractament de les biblioteques — proporciona l\'eina però no decideix l\'ús de les dades. Els contactes de cada biblioteca adherida estan disponibles a la pàgina de la biblioteca corresponent. Per a les qüestions tècniques sobre el sistema AnarBib mateix, podeu escriure a anarbib@proton.me.',
      'Cada biblioteca de la xarxa AnarBib és responsable del tractament de les dades dels-de les-de les seus-seves-seves lectors-es-es en el sentit del RGPD (article 4.7) i de la LGPD brasilera (article 5, VI). AnarBib, com a sistema tècnic operat pel Centro de Cultura Libertária da Amazônia (CCLA), és encarregat del tractament de les biblioteques — proporciona l\'eina però no decideix l\'ús de les dades. Els contactes de cada biblioteca adherida estan disponibles a la pàgina de la biblioteca corresponent. Per a les qüestions tècniques sobre el sistema AnarBib mateix, pots escriure a anarbib@proton.me.',
    ],
    'privacy.s1.title': [
      'Qui és responsable de les vostres dades',
      'Qui és responsable de les teves dades',
    ],
    'privacy.s10.authority': [
      'També podeu contactar amb l\'autoritat de control del vostre país (a França, la CNIL — cnil.fr; al Brasil, l\'ANPD — gov.br/anpd; a Itàlia, el Garante — garanteprivacy.it).',
      'També pots contactar amb l\'autoritat de control del teu país (a França, la CNIL — cnil.fr; al Brasil, l\'ANPD — gov.br/anpd; a Itàlia, el Garante — garanteprivacy.it).',
    ],
    'privacy.s10.body': [
      'Per a qualsevol qüestió relativa a aquesta política o al tractament de les vostres dades:',
      'Per a qualsevol qüestió relativa a aquesta política o al tractament de les teves dades:',
    ],
    'privacy.s2.item.email': [
      'La vostra adreça de correu electrònic (per a les comunicacions relatives als préstecs i reserves)',
      'La teva adreça de correu electrònic (per a les comunicacions relatives als préstecs i reserves)',
    ],
    'privacy.s2.item.lang': [
      'La vostra llengua d\'interfície preferida',
      'La teva llengua d\'interfície preferida',
    ],
    'privacy.s2.item.libraries': [
      'La llista de les biblioteques de la xarxa de les quals sou membre',
      'La llista de les biblioteques de la xarxa de les quals ets membre',
    ],
    'privacy.s2.item.loans': [
      'L\'historial dels vostres préstecs i reserves a la biblioteca',
      'L\'historial dels teus préstecs i reserves a la biblioteca',
    ],
    'privacy.s2.item.name': [
      'El vostre nom o pseudònim, opcionals',
      'El teu nom o pseudònim, opcionals',
    ],
    'privacy.s2.item.password': [
      'La vostra contrasenya, desada únicament en forma xifrada (hash bcrypt) — mai en clar, ni tan sols els-les-les bibliotecaris-àries-es la poden veure',
      'La teva contrasenya, desada únicament en forma xifrada (hash bcrypt) — mai en clar, ni tan sols els-les-les bibliotecaris-àries-es la poden veure',
    ],
    'privacy.s2.item.username': [
      'El vostre identificador públic (nom d\'usuari que trieu)',
      'El teu identificador públic (nom d\'usuari que tries)',
    ],
    'privacy.s3.body': [
      'Les dades es recullen únicament per permetre el funcionament de la biblioteca: gestionar el vostre compte, registrar els préstecs i reserves, i comunicar-se amb vós sobre aquestes operacions (disponibilitat d\'un llibre reservat, recordatori de devolució, etc.). No se\'n fa cap altre ús. En particular: cap màrqueting, cap anàlisi del comportament, cap perfilatge.',
      'Les dades es recullen únicament per permetre el funcionament de la biblioteca: gestionar el teu compte, registrar els préstecs i reserves, i comunicar-se amb tu sobre aquestes operacions (disponibilitat d\'un llibre reservat, recordatori de devolució, etc.). No se\'n fa cap altre ús. En particular: cap màrqueting, cap anàlisi del comportament, cap perfilatge.',
    ],
    'privacy.s5.body': [
      'Teniu drets legals sobre les vostres dades personals, garantits pel RGPD europeu i la LGPD brasilera:',
      'Tens drets legals sobre les teves dades personals, garantits pel RGPD europeu i la LGPD brasilera:',
    ],
    'privacy.s5.exercise': [
      'La majoria d\'aquests drets es poden exercir directament a l\'aplicació. Per consultar, modificar o suprimir les vostres dades, aneu a',
      'La majoria d\'aquests drets es poden exercir directament a l\'aplicació. Per consultar, modificar o suprimir les teves dades, vés a',
    ],
    'privacy.s5.linkAccount': [
      'la vostra pàgina «El meu compte»',
      'la teva pàgina «El meu compte»',
    ],
    'privacy.s5.right.access': [
      'Dret d\'accés: veure quines dades té la biblioteca sobre vós',
      'Dret d\'accés: veure quines dades té la biblioteca sobre tu',
    ],
    'privacy.s5.right.delete': [
      'Dret a la supressió («dret a l\'oblit»): suprimir el vostre compte i les vostres dades',
      'Dret a la supressió («dret a l\'oblit»): suprimir el teu compte i les teves dades',
    ],
    'privacy.s5.right.limit': [
      'Dret de limitació: sol·licitar la suspensió temporal del tractament de les vostres dades',
      'Dret de limitació: sol·licitar la suspensió temporal del tractament de les teves dades',
    ],
    'privacy.s5.right.portable': [
      'Dret a la portabilitat: descarregar les vostres dades en un format reutilitzable (exportació .csv disponible des del vostre compte)',
      'Dret a la portabilitat: descarregar les teves dades en un format reutilitzable (exportació .csv disponible des del teu compte)',
    ],
    'privacy.s5.title': [
      'Els vostres drets sobre les vostres dades',
      'Els teus drets sobre les teves dades',
    ],
    'privacy.s6.noResale': [
      'AnarBib no ven, no lloga ni comparteix mai les vostres dades amb finalitats comercials. Mai.',
      'AnarBib no ven, no lloga ni comparteix mai les teves dades amb finalitats comercials. Mai.',
    ],
    'privacy.s6.title': [
      'Amb qui es comparteixen les vostres dades',
      'Amb qui es comparteixen les teves dades',
    ],
    'privacy.s7.body': [
      'Les mesures tècniques implementades per AnarBib per protegir les vostres dades:',
      'Les mesures tècniques implementades per AnarBib per protegir les teves dades:',
    ],
    'privacy.s7.honest': [
      'Amb tota honestedat: cap sistema no és perfectament segur. En cas de violació de dades que afecti els vostres drets, se us informarà per correu electrònic en el termini previst pel RGPD (72 hores després de la constatació) i també es notificarà a l\'autoritat de control competent.',
      'Amb tota honestedat: cap sistema no és perfectament segur. En cas de violació de dades que afecti els teus drets, se t\'informarà per correu electrònic en el termini previst pel RGPD (72 hores després de la constatació) i també es notificarà a l\'autoritat de control competent.',
    ],
    'privacy.s7.measure.antibot': [
      'La verificació anti-robots la calcula el vostre navegador i la comproven els nostres servidors: cap servei extern no hi participa i la vostra adreça IP no es transmet a ningú',
      'La verificació anti-robots la calcula el teu navegador i la comproven els nostres servidors: cap servei extern no hi participa i la teva adreça IP no es transmet a ningú',
    ],
    'privacy.s7.title': [
      'Com es protegeixen les vostres dades',
      'Com es protegeixen les teves dades',
    ],
    'privacy.s8.body': [
      'En cas de sol·licitud de comunicació de dades per part d\'una autoritat judicial o policial, AnarBib respondrà únicament al que exigeixi estrictament la llei aplicable, i res més. Les persones afectades seran informades tan bon punt el secret de la investigació ho permeti. La primera protecció de les vostres dades continua sent el fet que no es recullin si no són necessàries — per això la minimització (secció 2) és central en el nostre disseny. El procediment detallat es descriu al document INCIDENT_RESPONSE.md publicat al nostre dipòsit.',
      'En cas de sol·licitud de comunicació de dades per part d\'una autoritat judicial o policial, AnarBib respondrà únicament al que exigeixi estrictament la llei aplicable, i res més. Les persones afectades seran informades tan bon punt el secret de la investigació ho permeti. La primera protecció de les teves dades continua sent el fet que no es recullin si no són necessàries — per això la minimització (secció 2) és central en el nostre disseny. El procediment detallat es descriu al document INCIDENT_RESPONSE.md publicat al nostre dipòsit.',
    ],
    'privacy.subtitle': [
      'Com protegeix AnarBib les vostres dades personals',
      'Com protegeix AnarBib les teves dades personals',
    ],
    'reader.external.notice': [
      'Aquest document està allotjat fora de la xarxa AnarBib. Se us redirigirà al lloc d\'origen per consultar-lo.',
      'Aquest document està allotjat fora de la xarxa AnarBib. Se\'t redirigirà al lloc d\'origen per consultar-lo.',
    ],
    'reader.generic.notice': [
      'Aquest format encara no té cap lector integrat a la plataforma. El podeu baixar o obrir en una pestanya nova.',
      'Aquest format encara no té cap lector integrat a la plataforma. El pots baixar o obrir en una pestanya nova.',
    ],
    'recolement.error.generic': [
      'S’ha produït un error, torneu-ho a provar.',
      'S’ha produït un error, torna-ho a provar.',
    ],
    'recolement.error.not_authenticated': [
      'Heu d’haver iniciat la sessió.',
      'Has d’haver iniciat la sessió.',
    ],
    'recolement.intro': [
      'Inicieu una sessió i escanegeu les etiquetes QR dels exemplars per verificar el fons. En acabar, obtindreu l’informe de presents, faltants i intrusos.',
      'Inicia una sessió i escaneja les etiquetes QR dels exemplars per verificar el fons. En acabar, obtindràs l’informe de presents, faltants i intrusos.',
    ],
    'recolement.scan.prompt': [
      'Apunteu al QR de l’etiqueta de l’exemplar',
      'Apunta al QR de l’etiqueta de l’exemplar',
    ],
    'rede.collectiveRemoval.propose.modal.motivationPlaceholder': [
      'Exposeu detalladament les raons polítiques d\'aquesta proposta de retirada…',
      'Exposa detalladament les raons polítiques d\'aquesta proposta de retirada…',
    ],
    'rede.collectiveRemoval.propose.modal.targetPlaceholder': [
      'Seleccioneu un-a-e administrador-a-e activ-a-e…',
      'Selecciona un-a-e administrador-a-e activ-a-e…',
    ],
    'rede.collectiveRemoval.propose.modal.warning': [
      'Atenció: decisió política greu. Es requereix la unanimitat dels-de les-de les administradors-es-es actius-actives-actives (a excepció de la persona afectada). S\'aplica una carència de 7 dies abans de l\'execució. Comproveu que aquesta posició es comparteix col·lectivament.',
      'Atenció: decisió política greu. Es requereix la unanimitat dels-de les-de les administradors-es-es actius-actives-actives (a excepció de la persona afectada). S\'aplica una carència de 7 dies abans de l\'execució. Comprova que aquesta posició es comparteix col·lectivament.',
    ],
    'rede.cooptation.propose.modal.description': [
      'La cooptació és una decisió política col·lectiva. Es requereix la unanimitat dels-de les-de les administradors-es-es actius-actives-actives de la xarxa. Comproveu que aquest-a-e camarada té la confiança col·lectiva de la xarxa.',
      'La cooptació és una decisió política col·lectiva. Es requereix la unanimitat dels-de les-de les administradors-es-es actius-actives-actives de la xarxa. Comprova que aquest-a-e camarada té la confiança col·lectiva de la xarxa.',
    ],
    'rede.cooptation.propose.modal.motivationPlaceholder': [
      'Exposeu la trajectòria militant del-de la-de le camarada i el perquè d\'aquesta proposta…',
      'Exposa la trajectòria militant del-de la-de le camarada i el perquè d\'aquesta proposta…',
    ],
    'rede.cooptation.vote.discloseIdentityHint': [
      'Aquesta tria és obligatòria i es registra a cada vot. Els-les-les altres administradors-es-es sempre veuen la vostra identitat.',
      'Aquesta tria és obligatòria i es registra a cada vot. Els-les-les altres administradors-es-es sempre veuen la teva identitat.',
    ],
    'rede.cooptation.vote.errors.discloseRequired': [
      'La vostra tria sobre la divulgació d\'identitat és obligatòria.',
      'La teva tria sobre la divulgació d\'identitat és obligatòria.',
    ],
    'rede.cooptation.vote.modal.description': [
      'La vostra decisió és decisiva: es requereix la unanimitat. Un sol vot en contra tanca el procés.',
      'La teva decisió és decisiva: es requereix la unanimitat. Un sol vot en contra tanca el procés.',
    ],
    'rede.cooptation.vote.rationalePlaceholder': [
      'Expliqueu els motius polítics de la vostra oposició…',
      'Explica els motius polítics de la teva oposició…',
    ],
    'rede.deactivateConfirm': [
      'Voleu desactivar aquesta biblioteca? Ja no serà visible al catàleg públic.',
      'Vols desactivar aquesta biblioteca? Ja no serà visible al catàleg públic.',
    ],
    'rede.reactivateConfirm': [
      'Voleu reactivar aquesta biblioteca?',
      'Vols reactivar aquesta biblioteca?',
    ],
    'rede.transfer.confirm': [
      'Voleu confirmar la transferència del mandat? La persona coordinadora anterior perdrà l\'accés a aquesta constitució.',
      'Vols confirmar la transferència del mandat? La persona coordinadora anterior perdrà l\'accés a aquesta constitució.',
    ],
    'reservation.nextStep.pronta_para_retirada': [
      'El document està a punt. Recolliu-lo a la biblioteca abans del termini.',
      'El document està a punt. Recull-lo a la biblioteca abans del termini.',
    ],
    'reservation.nextStep.retirada_agendada': [
      'Confirmeu o rebutgeu l\'horari proposat.',
      'Confirma o rebutja l\'horari proposat.',
    ],
    'reservation.nextStep.solicitada': [
      'L\'equip de la biblioteca examinarà la vostra sol·licitud properament.',
      'L\'equip de la biblioteca examinarà la teva sol·licitud properament.',
    ],
    'reservation.pickup.confirmed': [
      'Heu confirmat aquest horari',
      'Has confirmat aquest horari',
    ],
    'reservation.pickup.refused': [
      'Heu assenyalat una indisponibilitat',
      'Has assenyalat una indisponibilitat',
    ],
    'resource.viewer.externalNotice': [
      'Aquest recurs s\'obre fora d\'AnarBib. Feu servir el botó <em>Obrir el recurs</em> per continuar.',
      'Aquest recurs s\'obre fora d\'AnarBib. Fes servir el botó <em>Obrir el recurs</em> per continuar.',
    ],
    'resource.viewer.pdf.errorLoad': [
      'No s\'ha pogut carregar el PDF. Torneu a provar o contacteu amb un-a-e bibliotecari-ària-e.',
      'No s\'ha pogut carregar el PDF. Torna a provar o contacta amb un-a-e bibliotecari-ària-e.',
    ],
    'resource.viewer.pdf.errorTimeout': [
      'La càrrega del PDF ha expirat. Comproveu la connexió i torneu a provar.',
      'La càrrega del PDF ha expirat. Comprova la connexió i torna a provar.',
    ],
    'resource.viewer.pdf.passwordPrompt': [
      'Aquest PDF està protegit. Introduïu la contrasenya per obrir-lo.',
      'Aquest PDF està protegit. Introdueix la contrasenya per obrir-lo.',
    ],
    'solicitar.beforeSending.body': [
      'inicieu primer la sessió al vostre compte a <loginLink>Inici de sessió</loginLink>. L\'enviament registrarà una sol·licitud institucional real, en estat pendent, perquè la coordinació l\'analitzi.',
      'inicia primer la sessió al teu compte a <loginLink>Inici de sessió</loginLink>. L\'enviament registrarà una sol·licitud institucional real, en estat pendent, perquè la coordinació l\'analitzi.',
    ],
    'solicitar.error.notLoggedIn': [
      'Inicieu la sessió abans d\'enviar la sol·licitud. Creeu primer un compte si no en teniu cap.',
      'Inicia la sessió abans d\'enviar la sol·licitud. Crea primer un compte si no en tens cap.',
    ],
    'solicitar.error.requiredConfirms': [
      'Marqueu les dues confirmacions obligatòries.',
      'Marca les dues confirmacions obligatòries.',
    ],
    'solicitar.error.requiredContact': [
      'Indiqueu el nom i el correu electrònic de la persona responsable.',
      'Indica el nom i el correu electrònic de la persona responsable.',
    ],
    'solicitar.error.requiredLibraryEmail': [
      'Indiqueu el correu electrònic principal de la biblioteca.',
      'Indica el correu electrònic principal de la biblioteca.',
    ],
    'solicitar.error.requiredNameCityCountry': [
      'Empleneu el nom de la biblioteca, la ciutat i el país.',
      'Emplena el nom de la biblioteca, la ciutat i el país.',
    ],
    'solicitar.error.requiredProfileAxes': [
      'Trieu els 4 modes de funcionament de la vostra biblioteca (catàleg, circulació, xarxa, governança).',
      'Tria els 4 modes de funcionament de la teva biblioteca (catàleg, circulació, xarxa, governança).',
    ],
    'solicitar.error.requiredProjectStage': [
      'Seleccioneu l\'estat actual de la iniciativa.',
      'Selecciona l\'estat actual de la iniciativa.',
    ],
    'solicitar.error.requiredSummary': [
      'Redacteu una breu presentació de la biblioteca o del col·lectiu.',
      'Redacta una breu presentació de la biblioteca o del col·lectiu.',
    ],
    'solicitar.notLoggedIn.notice': [
      'Heu d\'haver iniciat la sessió per enviar aquesta sol·licitud. <loginLink>Iniciar la sessió</loginLink> o <createLink>Crear un compte</createLink>.',
      'Has d\'haver iniciat la sessió per enviar aquesta sol·licitud. <loginLink>Iniciar la sessió</loginLink> o <createLink>Crear un compte</createLink>.',
    ],
    'solicitar.success.helper': [
      'La sol·licitud institucional s\'ha registrat. Conserveu la informació de més avall.',
      'La sol·licitud institucional s\'ha registrat. Conserva la informació de més avall.',
    ],
    'team.modal.description.proposeCoordenador': [
      'La coordinació no es dona en solitari: aquesta proposta necessita l\'aval d\'una altra persona de l\'equip i després l\'acceptació de la persona afectada. Fins llavors, no canvia res. Voleu confirmar la proposta?',
      'La coordinació no es dona en solitari: aquesta proposta necessita l\'aval d\'una altra persona de l\'equip i després l\'acceptació de la persona afectada. Fins llavors, no canvia res. Vols confirmar la proposta?',
    ],
    'team.governance.directCoord.confirmOn': [
      'Voleu activar el salt col·legiat? Una proposta de coordinació podrà adreçar-se a un·a lector·a actiu·va, sense etapa de bibliotecari-ària-e. El circuit col·legiat (aval, acceptació) s\'aplica íntegrament — però la persona rebrà d\'un sol gest l\'accés a les dades personals, a la configuració i a la gestió de l\'equip. Activeu-ho només per decisió del col·lectiu.',
      'Vols activar el salt col·legiat? Una proposta de coordinació podrà adreçar-se a un·a lector·a actiu·va, sense etapa de bibliotecari-ària-e. El circuit col·legiat (aval, acceptació) s\'aplica íntegrament — però la persona rebrà d\'un sol gest l\'accés a les dades personals, a la configuració i a la gestió de l\'equip. Activa-ho només per decisió del col·lectiu.',
    ],
    'team.governance.directCoord.confirmOff': [
      'Voleu desactivar el salt col·legiat? L\'escala torna a ser l\'única via, i les propostes de salt obertes fallaran a l\'acceptació.',
      'Vols desactivar el salt col·legiat? L\'escala torna a ser l\'única via, i les propostes de salt obertes fallaran a l\'acceptació.',
    ],
    'team.modal.error.missingPublicId': [
      'Falta l\'identificador públic en aquesta fila. Recarregueu la pàgina i torneu-ho a provar.',
      'Falta l\'identificador públic en aquesta fila. Recarrega la pàgina i torna-ho a provar.',
    ],
    'team.modal.description.cancelRemove': [
      'Voleu confirmar la cancel·lació de la retirada en curs? Aquesta persona recupera el seu rol actiu immediatament. La sol·licitud inicial i el seu motiu es mantenen consignats a l\'historial militant.',
      'Vols confirmar la cancel·lació de la retirada en curs? Aquesta persona recupera el seu rol actiu immediatament. La sol·licitud inicial i el seu motiu es mantenen consignats a l\'historial militant.',
    ],
    'team.modal.description.promoteToLibrarian': [
      'Voleu confirmar la promoció al rol de bibliotecari-ària-e? Aquesta persona podrà fer préstecs, devolucions, inscriure lectors-es-es i assegurar el dia a dia de la biblioteca.',
      'Vols confirmar la promoció al rol de bibliotecari-ària-e? Aquesta persona podrà fer préstecs, devolucions, inscriure lectors-es-es i assegurar el dia a dia de la biblioteca.',
    ],
    'team.modal.description.quitAdmin': [
      'Voleu confirmar la retirada de les funcions d\'administrador-a-e d\'AnarBib? Conservareu un rol de bibliotecari-ària-e a la biblioteca d\'ancoratge. Altres administradors-es-es continuen en funcions.',
      'Vols confirmar la retirada de les funcions d\'administrador-a-e d\'AnarBib? Conservaràs un rol de bibliotecari-ària-e a la biblioteca d\'ancoratge. Altres administradors-es-es continuen en funcions.',
    ],
    'team.modal.description.quitAdminLast': [
      'Actualment sou l\'ÚNIC-A-E administrador-a-e activ-a-e de la xarxa AnarBib. Marxar sense haver promogut un-a-e altre-a-e administrador-a-e significa tancar la governança de la xarxa fins que el desenvolupament tècnic restableixi manualment un rol d\'administrador-a-e. Aquesta acció es consigna a l\'historial militant i notifica tot l\'equip de la xarxa.',
      'Actualment ets l\'ÚNIC-A-E administrador-a-e activ-a-e de la xarxa AnarBib. Marxar sense haver promogut un-a-e altre-a-e administrador-a-e significa tancar la governança de la xarxa fins que el desenvolupament tècnic restableixi manualment un rol d\'administrador-a-e. Aquesta acció es consigna a l\'historial militant i notifica tot l\'equip de la xarxa.',
    ],
    'team.modal.description.selfDemote': [
      'Deixeu la coordinació per iniciativa pròpia. Tornareu al rol de bibliotecari-ària-e. Aquesta acció es registra a l\'historial militant.',
      'Deixa la coordinació per iniciativa pròpia. Tornaràs al rol de bibliotecari-ària-e. Aquesta acció es registra a l\'historial militant.',
    ],
    'team.modal.description.suspend': [
      'La suspensió impedeix temporalment que aquesta persona exerceixi les seves funcions. El motiu serà visible al tauler de governança i s\'enviarà per correu electrònic. Useu-la amb discerniment — és una decisió col·lectiva.',
      'La suspensió impedeix temporalment que aquesta persona exerceixi les seves funcions. El motiu serà visible al tauler de governança i s\'enviarà per correu electrònic. Usa-la amb discerniment — és una decisió col·lectiva.',
    ],
    'team.modal.description.unsuspend': [
      'Voleu confirmar l\'aixecament de la suspensió? Aquesta persona recuperarà totes les funcions vinculades al seu rol.',
      'Vols confirmar l\'aixecament de la suspensió? Aquesta persona recuperarà totes les funcions vinculades al seu rol.',
    ],
    'team.modal.error.generic': [
      'Error inesperat. Torneu a provar o aviseu un-a-e administrador-a-e.',
      'Error inesperat. Torna a provar o avisa un-a-e administrador-a-e.',
    ],
    'team.modal.quitAdmin.confirmLabel': [
      'Per confirmar, escriviu exactament: {phrase}',
      'Per confirmar, escriu exactament: {phrase}',
    ],
    'team.modal.quitAdmin.hint': [
      'La frase distingeix majúscules i minúscules. No es recomana copiar i enganxar — llegiu-la i escriviu-la manualment.',
      'La frase distingeix majúscules i minúscules. No es recomana copiar i enganxar — llegeix-la i escriu-la manualment.',
    ],
    'team.modal.quitAdmin.invalidPhrase': [
      'La frase introduïda no coincideix exactament. Comproveu les majúscules i minúscules i torneu a provar.',
      'La frase introduïda no coincideix exactament. Comprova les majúscules i minúscules i torna a provar.',
    ],
    'team.modal.quitAdmin.lastAdminWarning': [
      '⚠ Atenció màxima: sou l\'últim-a-e administrador-a-e de la xarxa. Sense cap altre-a-e administrador-a-e en funcions, ningú no podrà promoure nous-noves-noves coordinadors-es-es ni gestionar la xarxa AnarBib mitjançant la interfície fins que hi hagi una intervenció tècnica directa a la base de dades.',
      '⚠ Atenció màxima: ets l\'últim-a-e administrador-a-e de la xarxa. Sense cap altre-a-e administrador-a-e en funcions, ningú no podrà promoure nous-noves-noves coordinadors-es-es ni gestionar la xarxa AnarBib mitjançant la interfície fins que hi hagi una intervenció tècnica directa a la base de dades.',
    ],
    'team.modal.reason.placeholder': [
      'Expliqueu el motiu col·lectiu de la suspensió. Es comunicarà a la persona implicada i a l\'equip.',
      'Explica el motiu col·lectiu de la suspensió. Es comunicarà a la persona implicada i a l\'equip.',
    ],
    'team.modal.removeReason.placeholder': [
      'Expliqueu el motiu col·lectiu de la retirada. Es comunicarà a la persona implicada i a l\'equip. La sol·licitud es consigna a l\'historial militant.',
      'Explica el motiu col·lectiu de la retirada. Es comunicarà a la persona implicada i a l\'equip. La sol·licitud es consigna a l\'historial militant.',
    ],
    'team.modal.warningSelfDemote': [
      'Atenció: després de deixar la coordinació, ja no podreu gestionar l\'equip ni modificar els paràmetres de la biblioteca. Un-a-e altre-a-e coordinador-a-e o administrador-a-e us haurà de tornar a promoure, si escau.',
      'Atenció: després de deixar la coordinació, ja no podràs gestionar l\'equip ni modificar els paràmetres de la biblioteca. Un-a-e altre-a-e coordinador-a-e o administrador-a-e t\'haurà de tornar a promoure, si escau.',
    ],
    'team.selfTag': [
      'vós',
      'tu',
    ],
    'wizard.profile.axis.catalog_mode.subtitle': [
      'Com serà visible el catàleg de la vostra biblioteca?',
      'Com serà visible el catàleg de la teva biblioteca?',
    ],
    'wizard.profile.axis.circulation_mode.subtitle': [
      'Com gestiona la vostra biblioteca els préstecs, reserves i consultes?',
      'Com gestiona la teva biblioteca els préstecs, reserves i consultes?',
    ],
    'wizard.profile.axis.network_mode.subtitle': [
      'Com es vincula la vostra biblioteca a la xarxa AnarBib?',
      'Com es vincula la teva biblioteca a la xarxa AnarBib?',
    ],
    'wizard.profile.intro.subtitle': [
      'Trieu un perfil tipus o personalitzeu els 4 eixos. Després ho podreu ajustar, per vot col·lectiu.',
      'Tria un perfil tipus o personalitza els 4 eixos. Després ho podràs ajustar, per vot col·lectiu.',
    ],
    'wizard.profile.intro.title': [
      'Com vol participar la vostra biblioteca a la xarxa AnarBib?',
      'Com vol participar la teva biblioteca a la xarxa AnarBib?',
    ],
    'wizard.profile.option.catalog_mode.local_only.desc': [
      'El catàleg només és visible per la vostra biblioteca. Útil per a col·lectius autònoms o en fase inicial.',
      'El catàleg només és visible per la teva biblioteca. Útil per a col·lectius autònoms o en fase inicial.',
    ],
    'wizard.profile.option.network_mode.federated.desc': [
      'La vostra biblioteca participa plenament a la xarxa: catàleg federat, préstec interbibliotecari, intercanvi de pràctiques. Solidaritat efectiva.',
      'La teva biblioteca participa plenament a la xarxa: catàleg federat, préstec interbibliotecari, intercanvi de pràctiques. Solidaritat efectiva.',
    ],
    'wizard.profile.option.network_mode.isolated.desc': [
      'La vostra biblioteca no comparteix dades amb la xarxa AnarBib. Autonomia completa.',
      'La teva biblioteca no comparteix dades amb la xarxa AnarBib. Autonomia completa.',
    ],
    'wizard.profile.option.network_mode.observer.desc': [
      'La vostra biblioteca pot consultar la xarxa i compartir el seu catàleg, però no participa en el préstec interbibliotecari.',
      'La teva biblioteca pot consultar la xarxa i compartir el seu catàleg, però no participa en el préstec interbibliotecari.',
    ],
    'wizard.profile.recap.confirmed': [
      'Perfil complet. Podeu passar a les confirmacions finals.',
      'Perfil complet. Pots passar a les confirmacions finals.',
    ],
    'wizard.profile.recap.subtitle': [
      'Verifiqueu els vostres 4 eixos abans de continuar. Podeu modificar cada eix individualment.',
      'Verifica els teus 4 eixos abans de continuar. Pots modificar cada eix individualment.',
    ],
    'wizard.profile.statusHint.incomplete': [
      'Acabeu els 4 eixos per continuar.',
      'Acaba els 4 eixos per continuar.',
    ],
    'catalog.related.subjects': [
      'Vegeu també',
      'Veure també',
    ],
    'catalogacao.subjectGov.relTitle': [
      'Vegeu també (matèries relacionades)',
      'Veure també (matèries relacionades)',
    ],
    'biblioteca.publicFiche.collective': [
      'Fer pública informació compromet el col·lectiu: decidiu-ho juntes.',
      'Fer pública informació compromet el col·lectiu: cal decidir-ho juntes.',
    ],
    'catalogacao.audio.seg.deleteConfirm': [
      'Voleu eliminar aquest segment?',
      'Vols eliminar aquest segment?',
    ],
    'catalogacao.catalog.discardBookCascadeConfirm': [
      'Descartar «{label}» també eliminarà els exemplars associats a la teva biblioteca. Voleu continuar?',
      'Descartar «{label}» també eliminarà els exemplars associats a la teva biblioteca. Vols continuar?',
    ],
    'deposit.config.action.deactivateConfirm': [
      'Voleu desactivar aquesta regla de dipòsit?',
      'Vols desactivar aquesta regla de dipòsit?',
    ],
    'deposit.config.action.deleteConfirm': [
      'Voleu suprimir definitivament la regla « {name} »?',
      'Vols suprimir definitivament la regla « {name} »?',
    ],
    'biblioteca.regulation.removeConfirmArchive': [
      'Voleu arxivar «{label}»? Es retirarà de la llista però es conservarà (reversible).',
      'Vols arxivar «{label}»? Es retirarà de la llista però es conservarà (reversible).',
    ],
    'biblioteca.regulation.removeConfirmDelete': [
      'Voleu suprimir definitivament l\'esborrany «{label}»? Aquesta acció és irreversible.',
      'Vols suprimir definitivament l\'esborrany «{label}»? Aquesta acció és irreversible.',
    ],
    'privacy.video.body': [
      'Alguns tutorials en vídeo estan allotjats a kolektiva.media, una instància PeerTube militant. Per respecte a la vostra privadesa, aquests vídeos no es carreguen automàticament: mentre no feu clic a «Carrega el vídeo», no s\'envia res a kolektiva.media. A partir d\'aquest clic, kolektiva.media rep la vostra adreça IP —com qualsevol lloc que visiteu— per lliurar-vos el vídeo. Hem desactivat la compartició P2P en aquests vídeos, perquè la vostra IP no quedi exposada a altres espectadores ni a servidors de tercers.',
      'Alguns tutorials en vídeo estan allotjats a kolektiva.media, una instància PeerTube militant. Per respecte a la teva privadesa, aquests vídeos no es carreguen automàticament: mentre no facis clic a «Carrega el vídeo», no s\'envia res a kolektiva.media. A partir d\'aquest clic, kolektiva.media rep la teva adreça IP —com qualsevol lloc que visites— per lliurar-te el vídeo. Hem desactivat la compartició P2P en aquests vídeos, perquè la teva IP no quedi exposada a altres espectadores ni a servidors de tercers.',
    ],
    'privacy.s2.item.phone': [
      'El vostre número de telèfon, només si decidiu indicar-lo (opcional)',
      'El teu número de telèfon, només si decideixes indicar-lo (opcional)',
    ],
    'privacy.s2.item.address': [
      'La vostra adreça postal, només si decidiu indicar-la (opcional)',
      'La teva adreça postal, només si decideixes indicar-la (opcional)',
    ],
    'biblioteca.events.deleteConfirm': [
      'Voleu suprimir definitivament « {title} »?',
      'Vols suprimir definitivament « {title} »?',
    ],
    'catalogacao.postPublish.body': [
      'Voleu afegir un exemplar d’aquest document al catàleg?',
      'Vols afegir un exemplar d’aquest document al catàleg?',
    ],
    'catalogacao.digital.rights.hint': [
      'Aquest camp descriu els drets, no allò que es difon. «Sota drets» = només la coberta, tret que la biblioteca posseeixi l’exemplar físic: aleshores la íntegra és possible, reservada als seus membres. Justifiqueu aquest cas a sota.',
      'Aquest camp descriu els drets, no allò que es difon. «Sota drets» = només la coberta, tret que la biblioteca posseeixi l’exemplar físic: aleshores la íntegra és possible, reservada als seus membres. Justifica aquest cas a sota.',
    ],
    'atelier.revue.retained': [
      'La vostra correcció',
      'La teva correcció',
    ],
    'panel.apiError.split_target_changed': [
      'El registre ha canviat des de la proposta: no s’ha escrit res, per no esborrar la feina d’altri. Refeu la proposta sobre l’estat actual.',
      'El registre ha canviat des de la proposta: no s’ha escrit res, per no esborrar la feina d’altri. Refés la proposta sobre l’estat actual.',
    ],
    'panel.apiError.too_soon': [
      'Massa aviat: la mateixa operació s\'acaba d\'executar. Torneu-ho a provar d\'aquí a un minut.',
      'Massa aviat: la mateixa operació s\'acaba d\'executar. Torna-ho a provar d\'aquí a un minut.',
    ],
    'catalogacao.batchTrashedWillBeDeleted': [
      'Aquest lot només reté {count} esborrany(s) a la paperera. S’eliminaran definitivament juntament amb el lot. Voleu continuar?',
      'Aquest lot només reté {count} esborrany(s) a la paperera. S’eliminaran definitivament juntament amb el lot. Vols continuar?',
    ],
    'conta.demande.intro': [
      'La sol·licitud d’adhesió de la vostra biblioteca a la xarxa, i els vostres intercanvis amb l’administració de la xarxa durant l’examen.',
      'La sol·licitud d’adhesió de la teva biblioteca a la xarxa, i els teus intercanvis amb l’administració de la xarxa durant l’examen.',
    ],
    'rede.reviews.intro': [
      'Un lot nascut d’una importació només es publica després de la vostra aprovació. Llegiu l’informe, decidiu, motiveu els retocs.',
      'Un lot nascut d’una importació només es publica després de la teva aprovació. Llegeix l’informe, decideix, motiva els retocs.',
    ],
    'rede.reviews.notes': [
      'Les vostres notes',
      'Les teves notes',
    ],
    'notif.review.approved.body': [
      'L’administració ha aprovat la revisió del vostre lot: la publicació és oberta.',
      'L’administració ha aprovat la revisió del teu lot: la publicació és oberta.',
    ],
    'notif.review.changes.body': [
      'L’administració sol·licita retocs abans de publicar. Llegiu les notes a Catalogació › Lots.',
      'L’administració sol·licita retocs abans de publicar. Llegeix les notes a Catalogació › Lots.',
    ],
    'error.review.notes_required': [
      'Els retocs es motiven: afegiu una nota.',
      'Els retocs es motiven: afegeix una nota.',
    ],
    'relatar.intro': [
      'Alguna cosa no ha funcionat, o no com esperàveu? Expliqueu-ho aquí, sense compte ni Codeberg. Les persones que administren la xarxa reben el vostre avís per correu.',
      'Alguna cosa no ha funcionat, o no com esperaves? Explica-ho aquí, sense compte ni Codeberg. Les persones que administren la xarxa reben el teu avís per correu.',
    ],
    'relatar.whatHint': [
      'Deu caràcters com a mínim. El que heu vist a la pantalla, el missatge exacte si n\'hi ha hagut.',
      'Deu caràcters com a mínim. El que has vist a la pantalla, el missatge exacte si n\'hi ha hagut.',
    ],
    'relatar.expected': [
      'Què esperàveu (opcional)',
      'Què esperaves (opcional)',
    ],
    'relatar.email': [
      'El vostre correu (opcional)',
      'El teu correu (opcional)',
    ],
    'relatar.emailHint': [
      'Només per confirmar-vos que l\'avís ha arribat. No hi haurà seguiment automàtic.',
      'Només per confirmar-te que l\'avís ha arribat. No hi haurà seguiment automàtic.',
    ],
    'relatar.context': [
      'S\'envia també: la pàgina d\'origen ({page}), la vostra llengua i, si teniu sessió, el vostre rol i la vostra biblioteca.',
      'S\'envia també: la pàgina d\'origen ({page}), la teva llengua i, si tens sessió, el teu rol i la teva biblioteca.',
    ],
    'relatar.consent': [
      'No escriviu mai una contrasenya aquí. El que escriviu ho llegeixen persones, no es publica.',
      'No escriguis mai una contrasenya aquí. El que escrius ho llegeixen persones, no es publica.',
    ],
    'relatar.success': [
      'Rebut, gràcies. Les persones que administren la xarxa llegiran el vostre avís.',
      'Rebut, gràcies. Les persones que administren la xarxa llegiran el teu avís.',
    ],
    'relatar.error': [
      'No s\'ha pogut enviar. Torneu-ho a provar d\'aquí a un moment.',
      'No s\'ha pogut enviar. Torna-ho a provar d\'aquí a un moment.',
    ],
    'relatar.tooShort': [
      'Expliqueu una mica més: deu caràcters com a mínim.',
      'Explica una mica més: deu caràcters com a mínim.',
    ],
    'importacoes.run.encoding.fallback': [
      'Llegit en {enc}, per suposició: el fitxer no és UTF-8 vàlid. Reviseu els accents de les primeres fitxes; si són incorrectes, reprocesseu imposant la codificació.',
      'Llegit en {enc}, per suposició: el fitxer no és UTF-8 vàlid. Revisa els accents de les primeres fitxes; si són incorrectes, reprocessa imposant la codificació.',
    ],
    'importacoes.run.encoding.declaredUnsupported': [
      'El fitxer declara un joc de caràcters no admès ({codes}): alguns caràcters poden ser incorrectes. Torneu a exportar en UTF-8.',
      'El fitxer declara un joc de caràcters no admès ({codes}): alguns caràcters poden ser incorrectes. Torna a exportar en UTF-8.',
    ],
    'importacoes.run.reprocess.locked': [
      'Aquesta importació ja ha generat esborranys: ja no es pot reprocessar. Per tornar-la a llegir, importeu de nou el fitxer.',
      'Aquesta importació ja ha generat esborranys: ja no es pot reprocessar. Per tornar-la a llegir, importa de nou el fitxer.',
    ],
    'error.import.reparse_after_promotion': [
      'Aquesta importació ja ha generat esborranys: ja no es pot reprocessar (els esborranys perdrien el vincle amb la importació). Importeu de nou el fitxer.',
      'Aquesta importació ja ha generat esborranys: ja no es pot reprocessar (els esborranys perdrien el vincle amb la importació). Importa de nou el fitxer.',
    ],
    'catalogacao.ui.coverIsbnEcart': [
      'Aquest ISBN correspon a l\'edició {trouvee}; la fitxa indica {notice}. Reimpressió, una altra edició o ISBN erroni: verifiqueu-ho abans de triar aquesta coberta.',
      'Aquest ISBN correspon a l\'edició {trouvee}; la fitxa indica {notice}. Reimpressió, una altra edició o ISBN erroni: verifica-ho abans de triar aquesta coberta.',
    ],
  },
};

for (const [loc, cles] of Object.entries(DE_PARA)) {
  const fichier = path.join(DOSSIER, `${loc}.json`);
  const j = JSON.parse(fs.readFileSync(fichier, 'utf8'));
  let reecrites = 0;
  let deja = 0;
  const absentes = [];
  const autres = [];
  for (const [k, [de, para]] of Object.entries(cles)) {
    if (!(k in j)) absentes.push(k);
    else if (j[k] === de) { j[k] = para; reecrites++; }
    else if (j[k] === para) deja++;
    else autres.push(k);
  }
  fs.writeFileSync(fichier, JSON.stringify(j, null, 2) + '\n');
  console.log(`${loc} : ${reecrites} réécrite(s), ${deja} déjà faite(s)`);
  if (absentes.length) console.log(`  absentes (laissées) : ${absentes.join(', ')}`);
  if (autres.length) console.log(`  modifiées depuis, ni l'ancienne ni la nouvelle valeur (laissées) : ${autres.join(', ')}`);
}
