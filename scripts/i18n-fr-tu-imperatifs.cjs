/* ===========================================================================
 * i18n-fr-tu-imperatifs.cjs
 * DOC-ADDR-1 (« zéro vous », sans exception depuis le 07/09/2026) — relevé le
 * 27/09/2026 : 186 valeurs de fr.json s'adressaient encore au membre par des
 * IMPÉRATIFS au vouvoiement — « Réessayez ou contactez un·e bibliothécaire »,
 * « Saisissez le mot de passe », « Glissez un PDF ici, ou cliquez »,
 * « Démarrez une session… obtenez le rapport », « Veuillez reessayer ».
 * La garde du 07/09 ne cherchait que vous/votre/vos : un impératif n'a pas de
 * pronom, il passait.
 *
 * Réécriture MOT À MOT, par une table verbe → impératif du tu (Indiquez →
 * Indique, Choisissez → Choisis, Reprenez → Reprends, Obtenez → Obtiens,
 * Créez-en → Crées-en…) appliquée à la valeur d'origine : sens, placeholders,
 * apostrophes et ponctuation inchangés. Quatre valeurs corrigent en plus leur
 * orthographe dans la même phrase : auth.create.errorCreateFailed (« creation »,
 * « reessayer »), auth.create.errorGeneric (« a la coordination »),
 * readingNotes.empty (« a en ecrire »), catalogacao.exemplar.labelMarked
 * (« Étiquette »).
 *
 * Restent au pluriel, parce qu'elles s'adressent à une assemblée et non au
 * membre (PLURIEL_LEGITIME de la garde) : atelier.doctrine.text,
 * banner.profile.body, federacao.assembleias.fac.rotativityHint
 * (« Fonctions tournantes : alternez d'une AG à l'autre » — au pluriel aussi
 * en pt-BR, « alternem », et en es, « alternen »).
 *
 * Réécriture DE → PARA : une clé n'est réécrite que si elle porte encore
 * EXACTEMENT l'ancienne valeur. Rejouable sans risque : une clé déjà au tu, ou
 * corrigée depuis, n'est pas touchée ; elle est signalée si elle ne vaut ni
 * l'une ni l'autre.
 *
 * Les scripts d'origine (tous « ajout si absent ») sont corrigés dans le même
 * commit : rejoués sur une base vierge, ils posent directement le tu. Seules
 * 45 des 186 clés avaient une source dans scripts/ ; les autres n'existent que
 * dans les locales. Cinq de ces sources, dans add-i18n-keys.cjs, sont écrites
 * en Unicode DÉCOMPOSÉ (NFD) : une recherche de la valeur exacte ne les
 * trouve pas, elles ont été reprises une à une et réécrites en NFC.
 *
 * Le même commit aligne aussi sur fr.json onze valeurs au « vous » que la
 * passe du 07/09 avait corrigées dans fr.json et jamais à leur source
 * (« Vous pouvez restaurer », « Votre collectif n'est pas encore sur la
 * carte ? Proposez-le ici »…). Laissé tel quel : merge-imp-deposit-keys.cjs,
 * dont les clés importacoes.deposit.* n'existent plus dans les locales.
 *
 * La garde : src/tests/i18n-ecriture.test.js, chemin (4), VOUVOIEMENT.fr.
 * Usage : node scripts/i18n-fr-tu-imperatifs.cjs
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const FICHIER = path.join(__dirname, '..', 'src', 'i18n', 'locales', 'fr.json');

// clé : [valeur à l'impératif du vouvoiement, valeur au tu]
const DE_PARA = {
  'address.country.placeholder': [
    '— Choisissez un pays —',
    '— Choisis un pays —',
  ],
  'atelier.form.error.authorId': [
    'Indiquez l\'ID de l\'autorité (personne).',
    'Indique l\'ID de l\'autorité (personne).',
  ],
  'atelier.form.error.bio': [
    'Saisissez la biographie traduite.',
    'Saisis la biographie traduite.',
  ],
  'atelier.form.error.ids': [
    'Indiquez les deux identifiants (duplicata et canonique).',
    'Indique les deux identifiants (duplicata et canonique).',
  ],
  'atelier.form.error.names': [
    'Indiquez le nom de l\'autorité.',
    'Indique le nom de l\'autorité.',
  ],
  'atelier.form.error.rationale': [
    'Expliquez brièvement le motif de la proposition.',
    'Explique brièvement le motif de la proposition.',
  ],
  'atelier.obj.error.lib': [
    'Choisissez la bibliothèque qui objecte.',
    'Choisis la bibliothèque qui objecte.',
  ],
  'auth.captchaRequired': [
    'Attendez la fin de la vérification anti-bot avant de réessayer.',
    'Attends la fin de la vérification anti-bot avant de réessayer.',
  ],
  'auth.create.errorCreateFailed': [
    'Erreur lors de la creation du compte. Veuillez reessayer.',
    'Erreur lors de la création du compte. Réessaie.',
  ],
  'auth.create.errorGeneric': [
    'Erreur lors de l\'inscription. Communiquez le code ci-dessous a la coordination',
    'Erreur lors de l\'inscription. Communique le code ci-dessous à la coordination',
  ],
  'auth.create.errorLibraryNotReady': [
    'La bibliothèque sélectionnée n\'est pas encore entièrement configurée sur le réseau. Contactez la coordination.',
    'La bibliothèque sélectionnée n\'est pas encore entièrement configurée sur le réseau. Contacte la coordination.',
  ],
  'auth.create.errorServerConfig': [
    'Erreur de configuration du serveur. Contactez la coordination.',
    'Erreur de configuration du serveur. Contacte la coordination.',
  ],
  'auth.create.fillRequired': [
    'Remplissez tous les champs obligatoires.',
    'Remplis tous les champs obligatoires.',
  ],
  'auth.create.selectPh': [
    '— Choisissez une bibliothèque —',
    '— Choisis une bibliothèque —',
  ],
  'auth.forgotHint': [
    'Indiquez l\'e-mail enregistré pour recevoir un lien de récupération.',
    'Indique l\'e-mail enregistré pour recevoir un lien de récupération.',
  ],
  'auth.resetExpired': [
    'Lien expiré. Demandez un nouvel e-mail de récupération.',
    'Lien expiré. Demande un nouvel e-mail de récupération.',
  ],
  'biblioteca.exchanges.selectPartner': [
    'Sélectionnez une bibliothèque',
    'Sélectionne une bibliothèque',
  ],
  'biblioteca.extPartner.dupHint': [
    'Partenaires similaires déjà enregistrés — vérifiez avant de créer un doublon :',
    'Partenaires similaires déjà enregistrés — vérifie avant de créer un doublon :',
  ],
  'biblioteca.extPartner.hint': [
    'Enregistrez un collectif externe (qui a fourni son catalogue en fichier, ex. export Zotero). Il sera créé comme entité partenaire et deviendra une source disponible à l’import.',
    'Enregistre un collectif externe (qui a fourni son catalogue en fichier, ex. export Zotero). Il sera créé comme entité partenaire et deviendra une source disponible à l’import.',
  ],
  'biblioteca.ill.contactEmailInvalid': [
    'Indiquez une adresse e-mail de coordination valide.',
    'Indique une adresse e-mail de coordination valide.',
  ],
  'biblioteca.ill.contactRequired': [
    'Indiquez le nom du contact de coordination.',
    'Indique le nom du contact de coordination.',
  ],
  'biblioteca.ill.emptyItems': [
    'Aucun exemplaire ajouté. Cherchez un document ci-dessus et cliquez pour l\'ajouter.',
    'Aucun exemplaire ajouté. Cherche un document ci-dessus et clique pour l\'ajouter.',
  ],
  'biblioteca.ill.itemsRequired': [
    'Ajoutez au moins un exemplaire au prêt.',
    'Ajoute au moins un exemplaire au prêt.',
  ],
  'biblioteca.ill.logisticsModeRequired': [
    'Choisissez un mode de transmission des documents.',
    'Choisis un mode de transmission des documents.',
  ],
  'biblioteca.ill.pickLenderFirst': [
    'Choisissez d\'abord la bibliothèque prêteuse pour rechercher des documents.',
    'Choisis d\'abord la bibliothèque prêteuse pour rechercher des documents.',
  ],
  'biblioteca.ill.select': [
    'Sélectionnez',
    'Sélectionne',
  ],
  'biblioteca.ill.selectBoth': [
    'Sélectionnez la bibliothèque prêteuse et l\'emprunteuse.',
    'Sélectionne la bibliothèque prêteuse et l\'emprunteuse.',
  ],
  'biblioteca.msg.selectPdf': [
    'Sélectionnez un fichier PDF.',
    'Sélectionne un fichier PDF.',
  ],
  'biblioteca.privacy.editHint': [
    'Laissez un champ vide pour utiliser le défaut AnarBib. Saisissez 0 pour une rétention illimitée (non recommandée).',
    'Laisse un champ vide pour utiliser le défaut AnarBib. Saisis 0 pour une rétention illimitée (non recommandée).',
  ],
  'biblioteca.privacy.resetHint': [
    'Les champs ont été vidés. Cliquez sur Enregistrer pour confirmer la restauration des défauts.',
    'Les champs ont été vidés. Clique sur Enregistrer pour confirmer la restauration des défauts.',
  ],
  'biblioteca.privacy.subtitle': [
    'Configurez la durée pendant laquelle la bibliothèque conserve les données personnelles avant de les supprimer automatiquement. Cette politique met en œuvre le principe de minimisation (RGPD article 5(1)(e) / LGPD article 6).',
    'Configure la durée pendant laquelle la bibliothèque conserve les données personnelles avant de les supprimer automatiquement. Cette politique met en œuvre le principe de minimisation (RGPD article 5(1)(e) / LGPD article 6).',
  ],
  'biblioteca.tasks.empty': [
    'Aucune tâche en cours. Créez-en une ci-dessus.',
    'Aucune tâche en cours. Crées-en une ci-dessus.',
  ],
  'biblioteca.tasks.titleRequired': [
    'Indiquez le titre de la tâche.',
    'Indique le titre de la tâche.',
  ],
  'biblioteca.templates.empty': [
    'Aucun modèle pour le moment. Créez-en un ci-dessus.',
    'Aucun modèle pour le moment. Crées-en un ci-dessus.',
  ],
  'biblioteca.templates.titleRequired': [
    'Indiquez le titre du modèle.',
    'Indique le titre du modèle.',
  ],
  'biblioteca.visualAssets.helper': [
    'Logo, favicon, arrière-plan et fichier JSON de manifeste appliqués au thème de la bibliothèque. Téléversez les fichiers sous les noms canoniques ci-dessous. Ils deviennent publics et sont lus directement par l\'application.',
    'Logo, favicon, arrière-plan et fichier JSON de manifeste appliqués au thème de la bibliothèque. Téléverse les fichiers sous les noms canoniques ci-dessous. Ils deviennent publics et sont lus directement par l\'application.',
  ],
  'biblioteca.visualAssets.noSlug': [
    'Cette bibliothèque n\'a pas encore de slug. Définissez le slug avant de configurer l\'identité visuelle.',
    'Cette bibliothèque n\'a pas encore de slug. Définis le slug avant de configurer l\'identité visuelle.',
  ],
  'card.resolve.error.card_revoked': [
    'Cette carte a été remplacée par une plus récente. Demandez une carte à jour.',
    'Cette carte a été remplacée par une plus récente. Demande une carte à jour.',
  ],
  'card.resolve.error.generic': [
    'Erreur réseau — réessayez.',
    'Erreur réseau — réessaie.',
  ],
  'card.resolve.scan.error.generic': [
    'Impossible d\'ouvrir la caméra. Saisissez le code à la main.',
    'Impossible d\'ouvrir la caméra. Saisis le code à la main.',
  ],
  'card.resolve.scan.error.nocamera': [
    'Aucune caméra détectée. Saisissez le code à la main.',
    'Aucune caméra détectée. Saisis le code à la main.',
  ],
  'card.resolve.scan.error.permission': [
    'Accès à la caméra refusé. Autorisez-le pour scanner, ou saisissez le code.',
    'Accès à la caméra refusé. Autorise-le pour scanner, ou saisis le code.',
  ],
  'card.resolve.scan.error.unsupported': [
    'Le scan n\'est pas pris en charge par ce navigateur. Saisissez le code à la main.',
    'Le scan n\'est pas pris en charge par ce navigateur. Saisis le code à la main.',
  ],
  'card.resolve.scan.prompt': [
    'Visez le QR de la carte',
    'Vise le QR de la carte',
  ],
  'catalog.filters.authorPlaceholder': [
    'Tapez une partie du nom pour filtrer par auteur·rice',
    'Tape une partie du nom pour filtrer par auteur·rice',
  ],
  'catalog.filters.publisherPlaceholder': [
    'Tapez une partie du nom de l\'éditeur pour filtrer',
    'Tape une partie du nom de l\'éditeur pour filtrer',
  ],
  'catalog.table.sortHint': [
    'Cliquez sur un en-tête pour trier',
    'Clique sur un en-tête pour trier',
  ],
  'catalogacao.author.cropHint': [
    'Glissez pour positionner le visage, zoomez avec le curseur. Format 3×4.',
    'Glisse pour positionner le visage, zoome avec le curseur. Format 3×4.',
  ],
  'catalogacao.author.nameAssistDesc': [
    'Utilisez quand le nom vient brut de la BN, d\'un livre ou d\'une autre source.',
    'Utilise quand le nom vient brut de la BN, d\'un livre ou d\'une autre source.',
  ],
  'catalogacao.author.nameRequired': [
    'Indiquez le nom préféré.',
    'Indique le nom préféré.',
  ],
  'catalogacao.author.sourceKind.select': [
    'Sélectionnez…',
    'Sélectionne…',
  ],
  'catalogacao.batchHasDrafts': [
    'Ce lot contient encore {count} brouillon(s). Supprimez-les avant de supprimer le lot.',
    'Ce lot contient encore {count} brouillon(s). Supprime-les avant de supprimer le lot.',
  ],
  'catalogacao.batchNameRequired': [
    'Indiquez le nom du lot.',
    'Indique le nom du lot.',
  ],
  'catalogacao.catalog.description': [
    'Consultez les documents, autorités et exemplaires publiés. Reprenez pour modifier ou mettre au rebut.',
    'Consulte les documents, autorités et exemplaires publiés. Reprends pour modifier ou mettre au rebut.',
  ],
  'catalogacao.catalog.refreshBusy': [
    'Actualisation déjà en cours — réessayez dans un instant.',
    'Actualisation déjà en cours — réessaie dans un instant.',
  ],
  'catalogacao.catalog.retakeCreatedNoEdit': [
    'Brouillon de reprise créé (ID {id}). Ouvrez l’onglet correspondant pour modifier.',
    'Brouillon de reprise créé (ID {id}). Ouvre l’onglet correspondant pour modifier.',
  ],
  'catalogacao.exemplar.autoExemplarInfo': [
    'Lors de la publication d\'un nouveau document, un exemplaire est créé automatiquement avec la référence bibliographique (bib_ref) comme numéro d\'inventaire. N\'utilisez ce formulaire que pour ajouter des exemplaires supplémentaires ou modifier un exemplaire existant.',
    'Lors de la publication d\'un nouveau document, un exemplaire est créé automatiquement avec la référence bibliographique (bib_ref) comme numéro d\'inventaire. N\'utilise ce formulaire que pour ajouter des exemplaires supplémentaires ou modifier un exemplaire existant.',
  ],
  'catalogacao.exemplar.bibRefHint': [
    'Entrez et quittez le champ pour chercher automatiquement.',
    'Entre et quitte le champ pour chercher automatiquement.',
  ],
  'catalogacao.exemplar.labelMarked': [
    'Etiquette marquée comme prête. Enregistrez pour confirmer.',
    'Étiquette marquée comme prête. Enregistre pour confirmer.',
  ],
  'catalogacao.exemplar.labelNeedFields': [
    'Remplissez au moins auteur, titre ou CDD avant de marquer comme prêt.',
    'Remplis au moins auteur, titre ou CDD avant de marquer comme prêt.',
  ],
  'catalogacao.exemplar.labelStepDesc': [
    'L\'étiquette est calculée depuis le document d\'origine. Écrasez les champs seulement si nécessaire.',
    'L\'étiquette est calculée depuis le document d\'origine. Écrase les champs seulement si nécessaire.',
  ],
  'catalogacao.exemplar.materialStepDesc': [
    'Identifiez l\'objet physique : inventaire, bibliothèque et emplacement.',
    'Identifie l\'objet physique : inventaire, bibliothèque et emplacement.',
  ],
  'catalogacao.exemplar.originHint': [
    'Recherchez par titre ou réf. pour lier l\'exemplaire.',
    'Recherche par titre ou réf. pour lier l\'exemplaire.',
  ],
  'catalogacao.exemplar.originStepDesc': [
    'Localisez la fiche commune publiée à laquelle cet exemplaire appartient.',
    'Localise la fiche commune publiée à laquelle cet exemplaire appartient.',
  ],
  'catalogacao.exemplar.refOrTomboRequired': [
    'Indiquez au moins la référence ou le numéro d\'inventaire.',
    'Indique au moins la référence ou le numéro d\'inventaire.',
  ],
  'catalogacao.field.searchMetaHint': [
    'Indiquez au moins un ISBN, ISSN ou titre avant de rechercher.',
    'Indique au moins un ISBN, ISSN ou titre avant de rechercher.',
  ],
  'catalogacao.guide.livro.hint': [
    'Utilisez le noyau de la fiche. Passez en mode complet pour plus de détails.',
    'Utilise le noyau de la fiche. Passe en mode complet pour plus de détails.',
  ],
  'catalogacao.infocard.exemplarUnsaved': [
    'Enregistrez la fiche pour gérer les exemplaires',
    'Enregistre la fiche pour gérer les exemplaires',
  ],
  'catalogacao.isbd.notGenerated': [
    'ISBD : pas encore généré pour ce brouillon. Cliquez sur « Préparer ISBD » ci-dessus.',
    'ISBD : pas encore généré pour ce brouillon. Clique sur « Préparer ISBD » ci-dessus.',
  ],
  'catalogacao.isbn.scan.prompt': [
    'Visez le code-barres ISBN du livre',
    'Vise le code-barres ISBN du livre',
  ],
  'catalogacao.msg.bibRefDuplicate': [
    'La référence bibliographique {bibRef} est déjà utilisée (fiche {bookId}). Modifiez-la avant de publier.',
    'La référence bibliographique {bibRef} est déjà utilisée (fiche {bookId}). Modifie-la avant de publier.',
  ],
  'catalogacao.msg.enterTitle': [
    'Indiquez le titre du document.',
    'Indique le titre du document.',
  ],
  'catalogacao.msg.needBasicFields': [
    'Indiquez au moins un ISBN, ISSN, titre ou auteur.',
    'Indique au moins un ISBN, ISSN, titre ou auteur.',
  ],
  'catalogacao.msg.needIsbnOrTitle': [
    'Indiquez au moins un ISBN, ISSN ou titre avant de rechercher.',
    'Indique au moins un ISBN, ISSN ou titre avant de rechercher.',
  ],
  'catalogacao.noBatches': [
    'Aucun lot trouvé. Créez le premier lot ci-dessus.',
    'Aucun lot trouvé. Crée le premier lot ci-dessus.',
  ],
  'catalogacao.queue.description': [
    'Brouillons actifs de documents, autorités et exemplaires. Gérez le cycle de vie : éditez, marquez comme prêt, publiez ou mettez au rebut.',
    'Brouillons actifs de documents, autorités et exemplaires. Gère le cycle de vie : édite, marque comme prêt, publie ou mets au rebut.',
  ],
  'catalogacao.queue.selectAtLeast': [
    'Sélectionnez au moins un élément.',
    'Sélectionne au moins un élément.',
  ],
  'catalogacao.reassign.multiHint': [
    'Cette notice a des exemplaires dans plusieurs bibliothèques ; choisissez laquelle déplacer.',
    'Cette notice a des exemplaires dans plusieurs bibliothèques ; choisis laquelle déplacer.',
  ],
  'catalogacao.reassign.sourcePick': [
    'Choisissez la bibliothèque d\'origine…',
    'Choisis la bibliothèque d\'origine…',
  ],
  'catalogacao.subjects.saveFirst': [
    'Enregistrez le brouillon pour indexer par sujets.',
    'Enregistre le brouillon pour indexer par sujets.',
  ],
  'catalogacao.ui.labelFillHint': [
    'Renseignez auteur, titre ou CDD pour générer la simulation.',
    'Renseigne auteur, titre ou CDD pour générer la simulation.',
  ],
  'catalogacao.ui.reviewHint': [
    'Utilisez ce panneau pour relire la fiche, voir la sortie publique minimale ou vérifier le paquet ISBD.',
    'Utilise ce panneau pour relire la fiche, voir la sortie publique minimale ou vérifier le paquet ISBD.',
  ],
  'catalogacao.wizard.step.autoria.body': [
    'Gérez les auteur·rices (personnes et organisations) lié·es aux documents. Chaque auteur·rice créé·e ici peut être associé·e à plusieurs livres et inversement.',
    'Gère les auteur·rices (personnes et organisations) lié·es aux documents. Chaque auteur·rice créé·e ici peut être associé·e à plusieurs livres et inversement.',
  ],
  'catalogacao.wizard.step.autoria.tip': [
    'L\'autocomplétion suggère les auteur·rices existant·es en tapant le nom — évitez les doublons !',
    'L\'autocomplétion suggère les auteur·rices existant·es en tapant le nom — évite les doublons !',
  ],
  'catalogacao.wizard.step.documento.body': [
    'Créez et éditez des fiches bibliographiques (livres, brochures, périodiques…). Renseignez le titre, l\'auteur·rice, l\'ISBN, le type de matériel et la référence bibliographique. Utilisez le mode Simple pour l\'essentiel ou Complet pour tous les champs.',
    'Crée et édite des fiches bibliographiques (livres, brochures, périodiques…). Renseigne le titre, l\'auteur·rice, l\'ISBN, le type de matériel et la référence bibliographique. Utilise le mode Simple pour l\'essentiel ou Complet pour tous les champs.',
  ],
  'catalogacao.wizard.step.indexacao.body': [
    'Enregistrez des exemplaires (copies physiques) rattachés à un document. Chaque exemplaire a un numéro d\'inventaire, une politique de circulation et une étiquette de cote.',
    'Enregistre des exemplaires (copies physiques) rattachés à un document. Chaque exemplaire a un numéro d\'inventaire, une politique de circulation et une étiquette de cote.',
  ],
  'catalogacao.wizard.step.welcome.body': [
    'Ce guide présente les principales fonctionnalités du module de catalogage. Naviguez entre les étapes pour découvrir chaque onglet et ses outils.',
    'Ce guide présente les principales fonctionnalités du module de catalogage. Navigue entre les étapes pour découvrir chaque onglet et ses outils.',
  ],
  'common.error.system': [
    'Une erreur technique est survenue. Réessayez ; si le problème persiste, prévenez l\'équipe.',
    'Une erreur technique est survenue. Réessaie ; si le problème persiste, préviens l\'équipe.',
  ],
  'error.consulta.all_engaged': [
    'Pour le moment, tous les exemplaires consultables de ce document sont utilisés. Réessayez plus tard.',
    'Pour le moment, tous les exemplaires consultables de ce document sont utilisés. Réessaie plus tard.',
  ],
  'error.library.circulation_disabled': [
    'La circulation est désactivée pour cette bibliothèque. Impossible de créer des prêts, des réservations ou des demandes de consultation. Contactez la coordination pour plus d\'informations.',
    'La circulation est désactivée pour cette bibliothèque. Impossible de créer des prêts, des réservations ou des demandes de consultation. Contacte la coordination pour plus d\'informations.',
  ],
  'error.publish.tombo_duplicate': [
    'Ce numéro de registre (tombo) est déjà utilisé par un autre exemplaire. Choisissez-en un autre.',
    'Ce numéro de registre (tombo) est déjà utilisé par un autre exemplaire. Choisis-en un autre.',
  ],
  'importacoes.enterRssUrl': [
    'Indiquez l\'URL du flux RSS/Atom.',
    'Indique l\'URL du flux RSS/Atom.',
  ],
  'importacoes.enterUrl': [
    'Indiquez une URL.',
    'Indique une URL.',
  ],
  'importacoes.fila.processing.desc': [
    'Les lignes sont encore analysées et comparées au catalogue. Patientez et actualisez dans un instant.',
    'Les lignes sont encore analysées et comparées au catalogue. Patiente et actualise dans un instant.',
  ],
  'importacoes.fila.selectRun': [
    'Sélectionnez un traitement ci-dessus pour voir les lignes en révision.',
    'Sélectionne un traitement ci-dessus pour voir les lignes en révision.',
  ],
  'importacoes.file.selectSource': [
    'Sélectionnez une source',
    'Sélectionne une source',
  ],
  'importacoes.fontes.noCompanheiras': [
    'Aucune bibliothèque compagne enregistrée. Créez une relation de partenariat pour activer l’importation réciproque.',
    'Aucune bibliothèque compagne enregistrée. Crée une relation de partenariat pour activer l’importation réciproque.',
  ],
  'importacoes.oai.noSources': [
    'Aucune source OAI-PMH configurée. Contactez l\'admin réseau.',
    'Aucune source OAI-PMH configurée. Contacte l\'admin réseau.',
  ],
  'importacoes.selectFile': [
    'Sélectionnez un fichier.',
    'Sélectionne un fichier.',
  ],
  'importacoes.selectSource': [
    'Sélectionnez une source partenaire.',
    'Sélectionne une source partenaire.',
  ],
  'importacoes.wizard.preview.dupBody': [
    'Sur un catalogue mutualisé, créer un doublon génère des incohérences graves. Ces lignes ne seront PAS promues automatiquement — vérifiez-les et privilégiez le rattachement à la notice existante.',
    'Sur un catalogue mutualisé, créer un doublon génère des incohérences graves. Ces lignes ne seront PAS promues automatiquement — vérifie-les et privilégie le rattachement à la notice existante.',
  ],
  'importacoes.wizard.promote.heldBack': [
    '{n} ligne(s) retenue(s), non promues (doublons potentiels ou à revoir) — traitez-les manuellement pour éviter les incohérences.',
    '{n} ligne(s) retenue(s), non promues (doublons potentiels ou à revoir) — traite-les manuellement pour éviter les incohérences.',
  ],
  'importacoes.wizard.source.ingested': [
    'Notice importée. Passez à l\'aperçu.',
    'Notice importée. Passe à l\'aperçu.',
  ],
  'importacoes.wizard.source.noSources': [
    'Aucune source partenaire. Créez-en une depuis la page Importações.',
    'Aucune source partenaire. Crées-en une depuis la page Importações.',
  ],
  'importacoes.wizard.source.ready': [
    'Lot importé (run #{id}). Passez à l\'aperçu.',
    'Lot importé (run #{id}). Passe à l\'aperçu.',
  ],
  'labels.editHint': [
    'Double-cliquez pour modifier',
    'Double-clique pour modifier',
  ],
  'labels.fieldsConfigHint': [
    'Cochez les champs optionnels à inclure sur les étiquettes imprimées.',
    'Coche les champs optionnels à inclure sur les étiquettes imprimées.',
  ],
  'labels.format.sectionHint': [
    'Choisissez un format de planche commercial, ou personnalisez les mesures manuellement.',
    'Choisis un format de planche commercial, ou personnalise les mesures manuellement.',
  ],
  'labels.format.unverifiedHint': [
    'Mesures estimées (non confirmées sur la fiche technique du fabricant) — ajustez via « Personnalisé » si besoin.',
    'Mesures estimées (non confirmées sur la fiche technique du fabricant) — ajuste via « Personnalisé » si besoin.',
  ],
  'labels.hint': [
    'Sélectionnez les exemplaires pour générer une planche d\'étiquettes imprimable. Cliquez sur les lignes pour sélectionner.',
    'Sélectionne les exemplaires pour générer une planche d\'étiquettes imprimable. Clique sur les lignes pour sélectionner.',
  ],
  'panel.action.selectAtLeastOne': [
    'Sélectionnez au moins une réservation.',
    'Sélectionne au moins une réservation.',
  ],
  'panel.action.selectStep': [
    'Sélectionnez une étape.',
    'Sélectionne une étape.',
  ],
  'panel.apiError.bib_ref_duplicado': [
    'Cette référence bibliographique est déjà utilisée par une autre fiche. Modifiez-la avant de publier.',
    'Cette référence bibliographique est déjà utilisée par une autre fiche. Modifie-la avant de publier.',
  ],
  'panel.apiError.cancel_note_required': [
    'Saisissez une note d\'au moins 5 caractères expliquant le motif.',
    'Saisis une note d\'au moins 5 caractères expliquant le motif.',
  ],
  'panel.apiError.generic': [
    'Cette action n\'a pas pu aboutir. Réessayez.',
    'Cette action n\'a pas pu aboutir. Réessaie.',
  ],
  'panel.apiError.isbn_duplicado': [
    'Une fiche portant le même ISBN est déjà publiée dans le réseau. Corrigez l\'ISBN ou ajoutez un exemplaire à la fiche existante.',
    'Une fiche portant le même ISBN est déjà publiée dans le réseau. Corrige l\'ISBN ou ajoute un exemplaire à la fiche existante.',
  ],
  'panel.apiError.line_required': [
    'Indiquez au moins une ligne pour continuer.',
    'Indique au moins une ligne pour continuer.',
  ],
  'panel.apiError.pickup_scheduled_for_required': [
    'Indiquez une date et une heure de retrait.',
    'Indique une date et une heure de retrait.',
  ],
  'panel.apiError.reason_required_min_5_chars': [
    'Indiquez un motif d\'au moins 5 caractères.',
    'Indique un motif d\'au moins 5 caractères.',
  ],
  'panel.apiError.schedule_missing': [
    'Indiquez les dates nécessaires à la planification.',
    'Indique les dates nécessaires à la planification.',
  ],
  'panel.consultation.schedule.notePlaceholder': [
    'Ex. : on se retrouve à l’accueil. Demandez Marie.',
    'Ex. : on se retrouve à l’accueil. Demande Marie.',
  ],
  'panel.loan.enterLoanId': [
    'Indiquez l\'ID de l\'emprunt.',
    'Indique l\'ID de l\'emprunt.',
  ],
  'panel.loan.enterSubIds': [
    'Indiquez les IDs des articles (ex. : 154.1, 154.2).',
    'Indique les IDs des articles (ex. : 154.1, 154.2).',
  ],
  'panel.loan.errorMissing': [
    'Indiquez l\'ID/e-mail du·de la lecteur·rice et les références.',
    'Indique l\'ID/e-mail du·de la lecteur·rice et les références.',
  ],
  'panel.memberships.hint': [
    'Vue d\'ensemble des lecteur·rices et de leurs paiements. Utilisez le bouton « + » pour enregistrer une cotisation.',
    'Vue d\'ensemble des lecteur·rices et de leurs paiements. Utilise le bouton « + » pour enregistrer une cotisation.',
  ],
  'panel.reader.write.errorEmpty': [
    'Écrivez un message.',
    'Écris un message.',
  ],
  'panel.reader.write.errorGeneric': [
    'Envoi impossible. Réessayez.',
    'Envoi impossible. Réessaie.',
  ],
  'panel.tasks.createAt': [
    'Créez des tâches dans la page Bibliothèque, onglet «Tâches internes».',
    'Crée des tâches dans la page Bibliothèque, onglet «Tâches internes».',
  ],
  'panel.tasks.emptyHint': [
    'Créez des tâches sur la page <link>Bibliothèque</link>, onglet « Tâches internes ».',
    'Crée des tâches sur la page <link>Bibliothèque</link>, onglet « Tâches internes ».',
  ],
  'recolement.error.generic': [
    'Une erreur est survenue, réessayez.',
    'Une erreur est survenue, réessaie.',
  ],
  'recolement.intro': [
    'Démarrez une session et scannez les étiquettes QR des exemplaires pour vérifier le fonds. À la fin, obtenez le rapport des présents, manquants et intrus.',
    'Démarre une session et scanne les étiquettes QR des exemplaires pour vérifier le fonds. À la fin, obtiens le rapport des présents, manquants et intrus.',
  ],
  'recolement.scan.prompt': [
    'Visez le QR de l’étiquette de l’exemplaire',
    'Vise le QR de l’étiquette de l’exemplaire',
  ],
  'rede.collectiveRemoval.propose.modal.motivationPlaceholder': [
    'Exposez en détail les raisons politiques de cette proposition de retrait…',
    'Expose en détail les raisons politiques de cette proposition de retrait…',
  ],
  'rede.collectiveRemoval.propose.modal.targetPlaceholder': [
    'Sélectionnez un·e administrateur·rice actif·ve…',
    'Sélectionne un·e administrateur·rice actif·ve…',
  ],
  'rede.collectiveRemoval.propose.modal.warning': [
    'Attention : décision politique grave. L\'unanimité des administrateur·rices actif·ves (à l\'exclusion de la personne ciblée) est requise. Une carence de 7 jours s\'applique avant exécution. Vérifiez que cette position est collectivement partagée.',
    'Attention : décision politique grave. L\'unanimité des administrateur·rices actif·ves (à l\'exclusion de la personne ciblée) est requise. Une carence de 7 jours s\'applique avant exécution. Vérifie que cette position est collectivement partagée.',
  ],
  'rede.cooptation.propose.modal.description': [
    'La cooptation est une décision politique collective. L\'unanimité des administrateur·rices actif·ves du réseau est requise. Vérifiez que cette·ce camarade a la confiance collective du réseau.',
    'La cooptation est une décision politique collective. L\'unanimité des administrateur·rices actif·ves du réseau est requise. Vérifie que cette·ce camarade a la confiance collective du réseau.',
  ],
  'rede.cooptation.propose.modal.motivationPlaceholder': [
    'Exposez le parcours militant de la·du camarade et le pourquoi de cette proposition…',
    'Expose le parcours militant de la·du camarade et le pourquoi de cette proposition…',
  ],
  'conta.demande.awaitingInfoHint': [
    'La coordination a besoin d\'informations complémentaires. Répondez ci-dessous.',
    'La coordination a besoin d\'informations complémentaires. Réponds ci-dessous.',
  ],
  'reservation.nextStep.pronta_para_retirada': [
    'Le document est prêt. Retirez-le à la bibliothèque avant l\'échéance.',
    'Le document est prêt. Retire-le à la bibliothèque avant l\'échéance.',
  ],
  'reservation.nextStep.retirada_agendada': [
    'Confirmez ou refusez l\'horaire proposé.',
    'Confirme ou refuse l\'horaire proposé.',
  ],
  'resource.viewer.pdf.errorLoad': [
    'Impossible de charger le PDF. Réessayez ou contactez un·e bibliothécaire.',
    'Impossible de charger le PDF. Réessaie ou contacte un·e bibliothécaire.',
  ],
  'resource.viewer.pdf.errorTimeout': [
    'Le chargement du PDF a expiré. Vérifiez la connexion et réessayez.',
    'Le chargement du PDF a expiré. Vérifie la connexion et réessaie.',
  ],
  'resource.viewer.pdf.passwordPrompt': [
    'Ce PDF est protégé. Saisissez le mot de passe pour l\'ouvrir.',
    'Ce PDF est protégé. Saisis le mot de passe pour l\'ouvrir.',
  ],
  'solicitar.error.requiredConfirms': [
    'Cochez les deux confirmations obligatoires.',
    'Coche les deux confirmations obligatoires.',
  ],
  'solicitar.error.requiredContact': [
    'Indiquez le nom et l\'e-mail de la personne responsable.',
    'Indique le nom et l\'e-mail de la personne responsable.',
  ],
  'solicitar.error.requiredLibraryEmail': [
    'Indiquez l\'e-mail principal de la bibliothèque.',
    'Indique l\'e-mail principal de la bibliothèque.',
  ],
  'solicitar.error.requiredNameCityCountry': [
    'Remplissez le nom de la bibliothèque, la ville et le pays.',
    'Remplis le nom de la bibliothèque, la ville et le pays.',
  ],
  'solicitar.error.requiredProjectStage': [
    'Sélectionnez l\'état actuel de l\'initiative.',
    'Sélectionne l\'état actuel de l\'initiative.',
  ],
  'solicitar.error.requiredSummary': [
    'Rédigez une brève présentation de la bibliothèque ou du collectif.',
    'Rédige une brève présentation de la bibliothèque ou du collectif.',
  ],
  'solicitar.success.helper': [
    'La demande institutionnelle a été enregistrée. Conservez les informations ci-dessous.',
    'La demande institutionnelle a été enregistrée. Conserve les informations ci-dessous.',
  ],
  'team.modal.error.missingPublicId': [
    'Identifiant public absent sur cette ligne. Rechargez la page et réessayez.',
    'Identifiant public absent sur cette ligne. Recharge la page et réessaie.',
  ],
  'team.modal.error.generic': [
    'Erreur inattendue. Réessayez ou prévenez un·e administrateur·rice.',
    'Erreur inattendue. Réessaie ou préviens un·e administrateur·rice.',
  ],
  'team.modal.quitAdmin.confirmLabel': [
    'Pour confirmer, saisissez exactement : {phrase}',
    'Pour confirmer, saisis exactement : {phrase}',
  ],
  'team.modal.quitAdmin.hint': [
    'La phrase est sensible à la casse. Le copier-coller est déconseillé — lisez et saisissez manuellement.',
    'La phrase est sensible à la casse. Le copier-coller est déconseillé — lis et saisis manuellement.',
  ],
  'team.modal.quitAdmin.invalidPhrase': [
    'La phrase saisie ne correspond pas exactement. Vérifiez la casse et réessayez.',
    'La phrase saisie ne correspond pas exactement. Vérifie la casse et réessaie.',
  ],
  'team.modal.reason.placeholder': [
    'Expliquez le motif collectif de la suspension. Il sera communiqué à la personne concernée et à l\'équipe.',
    'Explique le motif collectif de la suspension. Il sera communiqué à la personne concernée et à l\'équipe.',
  ],
  'team.modal.removeReason.placeholder': [
    'Expliquez le motif collectif du retrait. Il sera communiqué à la personne concernée et à l\'équipe. La demande est consignée dans l\'historique militant.',
    'Explique le motif collectif du retrait. Il sera communiqué à la personne concernée et à l\'équipe. La demande est consignée dans l\'historique militant.',
  ],
  'wizard.profile.statusHint.incomplete': [
    'Terminez les 4 axes pour continuer.',
    'Termine les 4 axes pour continuer.',
  ],
  'catalogacao.ocr.intro': [
    'Déposez un PDF scanné. S\'il a déjà une couche texte, elle est utilisée telle quelle ; sinon les pages clés sont reconnues par OCR — tout dans le navigateur, rien n\'est envoyé. Les champs sont pré-remplis par heuristique (sans IA) et éditables.',
    'Dépose un PDF scanné. S\'il a déjà une couche texte, elle est utilisée telle quelle ; sinon les pages clés sont reconnues par OCR — tout dans le navigateur, rien n\'est envoyé. Les champs sont pré-remplis par heuristique (sans IA) et éditables.',
  ],
  'catalogacao.ocr.dropHint': [
    'Glissez un PDF ici, ou cliquez pour choisir un fichier',
    'Glisse un PDF ici, ou clique pour choisir un fichier',
  ],
  'catalogacao.ocr.lowConfidenceWarn': [
    'Confiance OCR faible — vérifiez les champs avec attention avant d\'enregistrer.',
    'Confiance OCR faible — vérifie les champs avec attention avant d\'enregistrer.',
  ],
  'catalogacao.ocr.handoffIntro': [
    'Vérifiez et complétez le brouillon pré-rempli, puis enregistrez. Le PDF sera joint automatiquement.',
    'Vérifie et complète le brouillon pré-rempli, puis enregistre. Le PDF sera joint automatiquement.',
  ],
  'federacao.carte.edit.position': [
    'Position (cliquez ou glissez le repère)',
    'Position (clique ou glisse le repère)',
  ],
  'cartografia.add.error': [
    'Échec de l\'envoi. Réessayez.',
    'Échec de l\'envoi. Réessaie.',
  ],
  'federacao.carte.edit.geocodeFail': [
    'Adresse introuvable — placez le point manuellement.',
    'Adresse introuvable — place le point manuellement.',
  ],
  'team.invite.publicId.hint': [
    'Demandez son identifiant public à la personne (visible sur sa fiche / carte).',
    'Demande son identifiant public à la personne (visible sur sa fiche / carte).',
  ],
  'team.invite.error.emptyPublicId': [
    'Indiquez un identifiant public.',
    'Indique un identifiant public.',
  ],
  'error.catalog.discard.bookHasHoldings': [
    'Ce document possède des exemplaires dans une ou plusieurs bibliothèques. Mettez-les d\'abord au rebut.',
    'Ce document possède des exemplaires dans une ou plusieurs bibliothèques. Mets-les d\'abord au rebut.',
  ],
  'error.catalog.discard.authorLinked': [
    'Cette autorité est encore liée à un ou plusieurs documents. Détachez-la d\'abord.',
    'Cette autorité est encore liée à un ou plusieurs documents. Détache-la d\'abord.',
  ],
  'catalogacao.catalog.mergeHelp': [
    'Choisissez l\'autorité à conserver : « {name} » y sera rattachée (œuvres, contributions, alias) puis supprimée. Action irréversible.',
    'Choisis l\'autorité à conserver : « {name} » y sera rattachée (œuvres, contributions, alias) puis supprimée. Action irréversible.',
  ],
  'error.catalog.work.needTwo': [
    'Sélectionnez au moins deux documents.',
    'Sélectionne au moins deux documents.',
  ],
  'catalogacao.audio.seg.intro': [
    'Découpez cet enregistrement en segments (interventions, chants…), chacun rattaché à une œuvre et à ses crédits.',
    'Découpe cet enregistrement en segments (interventions, chants…), chacun rattaché à une œuvre et à ses crédits.',
  ],
  'deposit.panel.noActiveRule': [
    'Activez une règle de dépôt pour percevoir une caution.',
    'Active une règle de dépôt pour percevoir une caution.',
  ],
  'readingNotes.empty': [
    'Aucune note de lecture pour l\'instant. Soyez le·la premier·e a en ecrire une.',
    'Aucune note de lecture pour l\'instant. Sois le·la premier·e à en écrire une.',
  ],
  'catalogacao.dedup.scanHelpCross': [
    'La même œuvre cataloguée séparément par des bibliothèques différentes. Les fusionner reviendrait à mutualiser la notice, ce qui engage une autre bibliothèque : préférez « Même œuvre ».',
    'La même œuvre cataloguée séparément par des bibliothèques différentes. Les fusionner reviendrait à mutualiser la notice, ce qui engage une autre bibliothèque : préfère « Même œuvre ».',
  ],
  'catalogacao.digital.rights.hint': [
    'Ce champ décrit les droits, pas ce qui est diffusé. « Sous droits » = couverture seule, sauf si la bibliothèque détient l’exemplaire physique : l’intégrale est alors possible, réservée à ses membres. Motivez ce cas ci-dessous.',
    'Ce champ décrit les droits, pas ce qui est diffusé. « Sous droits » = couverture seule, sauf si la bibliothèque détient l’exemplaire physique : l’intégrale est alors possible, réservée à ses membres. Motive ce cas ci-dessous.',
  ],
  'catalogacao.dedupAssist.confirmPrompt': [
    'Pour confirmer, saisissez la référence de la fiche supprimée ({ref}) :',
    'Pour confirmer, saisis la référence de la fiche supprimée ({ref}) :',
  ],
  'panel.apiError.split_target_changed': [
    'La fiche a changé depuis la proposition : rien n’a été écrit, pour ne pas effacer le travail de quelqu’un d’autre. Reprenez la proposition sur l’état actuel.',
    'La fiche a changé depuis la proposition : rien n’a été écrit, pour ne pas effacer le travail de quelqu’un d’autre. Reprends la proposition sur l’état actuel.',
  ],
  'panel.apiError.too_soon': [
    'Trop tôt : la même opération vient de tourner. Réessayez dans une minute.',
    'Trop tôt : la même opération vient de tourner. Réessaie dans une minute.',
  ],
  'notif.review.changes.body': [
    'L’administration demande des retouches avant publication. Lisez ses notes dans Catalogage › Lots.',
    'L’administration demande des retouches avant publication. Lis ses notes dans Catalogage › Lots.',
  ],
  'error.review.notes_required': [
    'Des retouches se motivent : ajoutez une note.',
    'Des retouches se motivent : ajoute une note.',
  ],
  'error.batch.reassign.review_approved': [
    'Ce lot a une révision approuvée pour une autre bibliothèque : demandez un nouveau tour de révision avant de le réattribuer.',
    'Ce lot a une révision approuvée pour une autre bibliothèque : demande un nouveau tour de révision avant de le réattribuer.',
  ],
  'importacoes.run.encoding.fallback': [
    'Lu en {enc}, par supposition : le fichier n’est pas de l’UTF-8 valide. Vérifiez les accents des premières notices ; s’ils sont faux, retraitez en imposant l’encodage.',
    'Lu en {enc}, par supposition : le fichier n’est pas de l’UTF-8 valide. Vérifie les accents des premières notices ; s’ils sont faux, retraite en imposant l’encodage.',
  ],
  'importacoes.run.encoding.declaredUnsupported': [
    'Le fichier déclare un jeu de caractères non pris en charge ({codes}) : des caractères peuvent être faux. Ré-exportez en UTF-8.',
    'Le fichier déclare un jeu de caractères non pris en charge ({codes}) : des caractères peuvent être faux. Ré-exporte en UTF-8.',
  ],
  'importacoes.run.reprocess.locked': [
    'Cet import a déjà produit des brouillons : il ne peut plus être retraité. Pour le relire, importez de nouveau le fichier.',
    'Cet import a déjà produit des brouillons : il ne peut plus être retraité. Pour le relire, importe de nouveau le fichier.',
  ],
  'error.import.reparse_after_promotion': [
    'Cet import a déjà produit des brouillons : il ne peut plus être retraité (les brouillons perdraient le lien vers leur import). Importez de nouveau le fichier.',
    'Cet import a déjà produit des brouillons : il ne peut plus être retraité (les brouillons perdraient le lien vers leur import). Importe de nouveau le fichier.',
  ],
};

const j = JSON.parse(fs.readFileSync(FICHIER, 'utf8'));
let reecrites = 0;
let dejaTu = 0;
const absentes = [];
const autres = [];
for (const [k, [de, para]] of Object.entries(DE_PARA)) {
  if (!(k in j)) absentes.push(k);
  else if (j[k] === de) { j[k] = para; reecrites++; }
  else if (j[k] === para) dejaTu++;
  else autres.push(k);
}
fs.writeFileSync(FICHIER, JSON.stringify(j, null, 2) + '\n');
console.log(`fr : ${reecrites} réécrite(s), ${dejaTu} déjà au tu`);
if (absentes.length) console.log(`absentes (laissées) : ${absentes.join(', ')}`);
if (autres.length) console.log(`modifiées depuis, ni vouvoiement ni la version de ce script (laissées) : ${autres.join(', ')}`);
