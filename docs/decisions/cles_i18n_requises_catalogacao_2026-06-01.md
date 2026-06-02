# Clés i18n requises par CatalogaçãoPage (composants React actuels)

Extraction déterministe du 01/06/2026 — **258 clés distinctes** référencées par : CatalogacaoPage, BookDraftForm, AuthorDraftForm, ExemplarDraftForm, QueuePanel, CatalogPanel, LabelSheetPrinter.

> Plancher des besoins (composants actuels, incomplets vs legacy). Les nouveaux modules (capas, circulation par exemplaire, 3 paliers, non-livres) introduiront de nouvelles clés, à livrer dans les 8 locales (pt-BR, fr, es, it, de, en, ca, eo) en une passe par spec.

À diffé contre `pt-BR.json` (source) : présentes = OK ; absentes = à créer ×8.

## catalogacao.* (222)

```
catalogacao.areaSubtitle
catalogacao.areaTitle
catalogacao.author.bio
catalogacao.author.notes
catalogacao.batchName
catalogacao.batchNamePlaceholder
catalogacao.batchNameRequired
catalogacao.batchNotesPlaceholder
catalogacao.bio.placeholder
catalogacao.bio.save
catalogacao.bio.translations
catalogacao.catalog.authorities
catalogacao.catalog.documents
catalogacao.catalog.exemplars
catalogacao.closeBatch
catalogacao.closeBatchConfirm
catalogacao.createBatch
catalogacao.digital.attribution
catalogacao.digital.audio
catalogacao.digital.online
catalogacao.digital.pdf
catalogacao.digital.public
catalogacao.digital.video
catalogacao.field.accessCondition
catalogacao.field.accessNote
catalogacao.field.acquisitionDate
catalogacao.field.acquisitionMode
catalogacao.field.approxDate
catalogacao.field.audioFormat
catalogacao.field.audioLang
catalogacao.field.bibRef
catalogacao.field.campaign
catalogacao.field.cdd
catalogacao.field.collection
catalogacao.field.context
catalogacao.field.coverUpload
catalogacao.field.diffusionPlace
catalogacao.field.director
catalogacao.field.duration
catalogacao.field.edition
catalogacao.field.emitterOrg
catalogacao.field.fascicule
catalogacao.field.fileNote
catalogacao.field.focusNow
catalogacao.field.frequency
catalogacao.field.holderLibrary
catalogacao.field.importFormat
catalogacao.field.importMethod
catalogacao.field.isbn
catalogacao.field.issn
catalogacao.field.issue
catalogacao.field.language
catalogacao.field.marcJson
catalogacao.field.mutualizationStatus
catalogacao.field.notes
catalogacao.field.organizations
catalogacao.field.ownerLibrary
catalogacao.field.pages
catalogacao.field.participants
catalogacao.field.partnerSource
catalogacao.field.period
catalogacao.field.periodTitle
catalogacao.field.physicalFormat
catalogacao.field.physicalState
catalogacao.field.place
catalogacao.field.printTechnique
catalogacao.field.provenanceNote
catalogacao.field.pubDate
catalogacao.field.publisher
catalogacao.field.recordingType
catalogacao.field.restriction
catalogacao.field.scope
catalogacao.field.sourceLabel
catalogacao.field.sourceRecordId
catalogacao.field.sourceRecordUrl
catalogacao.field.subjects
catalogacao.field.subtitle
catalogacao.field.subtitles
catalogacao.field.support
catalogacao.field.title
catalogacao.field.url
catalogacao.field.usage
catalogacao.field.volume
catalogacao.field.year
catalogacao.form.language
catalogacao.interfaceComplete
catalogacao.interfaceSimple
catalogacao.isbd.audio
catalogacao.isbd.dossier
catalogacao.isbd.prepared
catalogacao.isbd.video
catalogacao.isbd.zone0
catalogacao.isbd.zone1
catalogacao.isbd.zone2
catalogacao.isbd.zone3
catalogacao.isbd.zone4
catalogacao.isbd.zone5
catalogacao.isbd.zone6
catalogacao.isbd.zone8
catalogacao.material.dossie
catalogacao.modeComplete
catalogacao.modeLabel
catalogacao.modeSimple
catalogacao.msg.alreadyPublished
catalogacao.msg.bnOpened
catalogacao.msg.connectionFailed
catalogacao.msg.enterTitle
catalogacao.msg.needBasicFields
catalogacao.msg.needIsbnOrTitle
catalogacao.msg.noCandidates
catalogacao.msg.publishConfirm
catalogacao.msg.readyToPublish
catalogacao.msg.searchingSources
catalogacao.msg.unsavedChanges
catalogacao.msg.worldcatOpened
catalogacao.ph.accessNote
catalogacao.ph.acquisitionMode
catalogacao.ph.approxDate
catalogacao.ph.audioDuration
catalogacao.ph.audioFormatTech
catalogacao.ph.audioParticipants
catalogacao.ph.audioSupport
catalogacao.ph.avDirector
catalogacao.ph.avDuration
catalogacao.ph.avParticipants
catalogacao.ph.avSubtitles
catalogacao.ph.avSupport
catalogacao.ph.bioHint
catalogacao.ph.bioPlaceholder
catalogacao.ph.city
catalogacao.ph.context
catalogacao.ph.diffusion
catalogacao.ph.digitalAccess
catalogacao.ph.digitalRestriction
catalogacao.ph.digitalUsage
catalogacao.ph.dossierOrgs
catalogacao.ph.dossierPeriod
catalogacao.ph.dossierScope
catalogacao.ph.emitterOrg
catalogacao.ph.fileNote
catalogacao.ph.language
catalogacao.ph.notes
catalogacao.ph.notesHint
catalogacao.ph.notesPlaceholder
catalogacao.ph.periodTitle
catalogacao.ph.physicalFormat
catalogacao.ph.physicalState
catalogacao.ph.printTechnique
catalogacao.ph.recordingType
catalogacao.ph.rectoVerso.both
catalogacao.ph.rectoVerso.none
catalogacao.ph.rectoVerso.recto
catalogacao.ph.refCompat
catalogacao.ph.subjects
catalogacao.ph.tractCampaign
catalogacao.public.catalogLine
catalogacao.publish
catalogacao.publishBatch
catalogacao.publishBatchConfirm
catalogacao.published
catalogacao.queue.title
catalogacao.section.audio
catalogacao.section.audiovisual
catalogacao.section.digital
catalogacao.section.tract
catalogacao.tab.autoria
catalogacao.tab.catalogo
catalogacao.tab.documento
catalogacao.tab.fila
catalogacao.tab.indexacao
catalogacao.tab.lotes
catalogacao.ui.acquisitionTitle
catalogacao.ui.addAuthor
catalogacao.ui.addCoauthor
catalogacao.ui.addCollective
catalogacao.ui.addTranslator
catalogacao.ui.archTitle
catalogacao.ui.bnIsbn
catalogacao.ui.bnLoading
catalogacao.ui.bnManual
catalogacao.ui.chooseCover
catalogacao.ui.circulation
catalogacao.ui.circulationLabel
catalogacao.ui.clear
catalogacao.ui.clearForm
catalogacao.ui.commonRecord
catalogacao.ui.consultOnly
catalogacao.ui.contributors
catalogacao.ui.coverAlt
catalogacao.ui.isbdNotReady
catalogacao.ui.isbdPrepare
catalogacao.ui.isbdReady
catalogacao.ui.isbdUpdate
catalogacao.ui.labelFillHint
catalogacao.ui.labelPreview
catalogacao.ui.labelPreviewHint
catalogacao.ui.layer1
catalogacao.ui.layer1desc
catalogacao.ui.layer1editing
catalogacao.ui.layer1empty
catalogacao.ui.layer2
catalogacao.ui.layer2desc
catalogacao.ui.layer2pending
catalogacao.ui.layer3
catalogacao.ui.layer3desc
catalogacao.ui.layer4
catalogacao.ui.layer4desc
catalogacao.ui.loanable
catalogacao.ui.newDraft
catalogacao.ui.noCover
catalogacao.ui.noLot
catalogacao.ui.rectoVerso
catalogacao.ui.reviewHint
catalogacao.ui.reviewTitle
catalogacao.ui.saveDraft
catalogacao.ui.searchMeta
catalogacao.ui.searching
catalogacao.ui.tabIsbd
catalogacao.ui.tabPublic
catalogacao.ui.tabSummary
catalogacao.ui.titleMissing
catalogacao.ui.worldcat
```

## labels.* (17)

```
labels.col.author
labels.col.note
labels.col.title
labels.deselectAll
labels.filterAll
labels.filterWithContent
labels.filtered
labels.hint
labels.labels
labels.pages
labels.print
labels.printTitle
labels.searchPlaceholder
labels.selectAll
labels.selected
labels.title
labels.total
```

## common.* (5)

```
common.dataSaved
common.errorPrefix
common.loading
common.saving
common.update
```

## book.* (2)

```
book
book.isbd.zone7
```

## author.* (1)

```
author
```

## authorsPanel.* (1)

```
authorsPanel
```

## batchesPanel.* (1)

```
batchesPanel
```

## booksPanel.* (1)

```
booksPanel
```

## catalogPanel.* (1)

```
catalogPanel
```

## exemplar.* (1)

```
exemplar
```

## indexPanel.* (1)

```
indexPanel
```

## isbd.* (1)

```
isbd
```

## pageTitle.* (1)

```
pageTitle.cataloging
```

## public.* (1)

```
public
```

## queuePanel.* (1)

```
queuePanel
```

## summary.* (1)

```
summary
```
