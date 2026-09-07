# AUDIT — anglais résiduel et diacritiques mangés dans les dix locales

**Date :** 07/09/2026 · **Périmètre :** `src/i18n/locales/*.json` (10 locales, 6 570 clés chacune)
**Origine :** un fichier orphelin `pt2de.json` à la racine du dépôt, remarqué par Xavier.

---

## 0. Comment ce relevé a été fait, et ce qu'il ne peut pas voir

*(exigence de `DOC-RECENS-1` : un recensement porte sa méthode et son angle mort)*

Trois chemins, délibérément indépendants :

1. **Égalité à l'anglais** — clés dont la valeur est identique à celle de `en.json`, en écartant
   celles identiques dans ≥ 7 locales (noms propres, sigles). **Angle mort** : ne voit pas
   l'anglais retapé ou légèrement modifié, ni aucune faute qui n'implique pas `en.json`.
2. **Critère d'écriture** — valeurs de `el.json` ne contenant aucune lettre grecque.
   Indépendant du chemin 1 ; c'est lui qui a trouvé le grec translittéré.
   **Angle mort** : ne vaut que pour le grec, seule locale à changer d'alphabet.
3. **Formes fautives certaines** — motifs dont l'absence de diacritique n'est jamais un
   homographe (`deja`, `gia`, `catalogo` en es/pt, `cataleg`, `Chu`, `fuer`…).
   **Angle mort** : ne trouve que ce qui est dans la liste des motifs. Le chiffre du §3
   est donc un **plancher**, jamais un total.

**Deux mesures fausses ont précédé celles-ci, et le dire fait partie du relevé.** Un premier
essai comparait chaque valeur ASCII au lexique accentué de son propre fichier : il rendait
570 « fautes » en néerlandais parce que *een* et *één*, *que* et *què* sont des homographes
légitimes. Un second incluait `catalogo` dans les motifs italiens — mot qui, en italien,
**ne porte pas d'accent**, d'où 123 faux positifs. Les deux mesuraient ce qu'elles
regardaient, pas ce qui était vrai.

---

## 1. Anglais laissé tel quel — six valeurs, toutes en grec

Chemin 1. Après retrait des faux positifs (`Export CSV` en français, `Open batches` en
néerlandais, `Feed (URL)` en allemand, `DDC (Dewey)` partout — toutes correctes dans leur
langue), il ne reste **que `el.json`** :

| Clé | Valeur en grec |
|---|---|
| `catalogacao.isbnDup.badge` | `ISBN already in catalog:` |
| `catalogacao.presave.isbnExists` | `ISBN already exists in catalog: {detail}.\n\nContinue saving anyway?` |
| `catalogacao.presave.titleAuthorExists` | `Title + authorship already exist in catalog: {detail}.\n\nContinue saving anyway?` |
| `catalogacao.authlink.autoLinked` | `{count, plural, one {1 contributor automatically linked…}}` |
| `account.profile.org` | `Organization or collective` |
| `panel.reader.org` | `Organization or collective` |

Les neuf autres locales traduisent ces clés correctement. Origine des quatre premières :
commit `7300502e` du **07/06/2026**.

## 2. Grec translittéré en caractères latins — cinq valeurs

Chemin 2, et **le chemin 1 ne pouvait pas les voir** : elles diffèrent de `en.json`, donc
aucune comparaison à l'anglais ne les atteint. Ce ne sont pas des chaînes anglaises : c'est
du grec écrit en alphabet latin, ce qu'aucune lectrice grecque ne lira comme du grec.

| Clé | Valeur |
|---|---|
| `auth.create.errorCreateFailed` | `Sfalma kata ti dimiourgia tou logariasmo. Parakalo dokimaste xana.` |
| `auth.create.errorGeneric` | `Sfalma kata tin eggafi. Parakalo koinopoiiste ton parakato kodiko…` |
| `auth.create.errorLibraryNotReady` | `I epilegmeni vivliothiki den einai akoma pliros diametrismeni…` |
| `auth.create.errorProfileFailed` | `O logariasmos dimiourgithike, alla yparxe sfalma…` |
| `auth.create.errorServerConfig` | `Sfalma diametrisis tou diakomisti. Epikoinoniste me tin syntonistiki omada.` |

Origine : commit `a1ce13ae`, **07/06/2026** — le même jour que le §1.

## 3. Diacritiques mangés — 71 valeurs dans sept locales

Chemin 3. Plancher mesuré : **fr 19 · pt-BR 15 · es 14 · it 10 · de 8 · ca 3 · eo 2**.

Ce n'est **pas une passe unique** : les commits d'origine s'étalent de mai à août 2026
(`a477b90e` 07/05, `f5aab3c4` 23/05, `7300502e` et `a1ce13ae` 07/06, `eac3020e` 22/06,
`fd73a8cb` 20/08). C'est un mode de défaillance récurrent, pas un accident.

**Et il a une doctrine qui l'interdit déjà** : `DOC-PS-1` — *« i18n : scripts via Node `.cjs`
ou UTF-8 PowerShell explicite ; vérifier toute mojibake avant correction »*. La règle existe,
elle n'a jamais été rendue **mécanique** : le hook `pre-commit` porte sept règles bloquantes,
**aucune sur l'i18n**. Même forme que `DOC-GLB-1` — une règle écrite là où elle n'oblige pas
est un vœu.

L'allemand est un cas à part : `fuer`, `muessen`, `gewaehlten`, `Uebergabe` sont la
translittération ASCII **reconnue** de l'allemand. Elle n'est pas fautive en soi ; elle est
incohérente avec le reste de `de.json`, qui écrit partout ailleurs les tréma.

---

## 4. `pt2de.json` — l'objet qui a déclenché l'audit

452 ko, 5 194 paires, racine du dépôt, non suivi, jamais référencé nulle part (ni code, ni
script, ni historique complet). Cache d'une passe de traduction pt→de du **01/09/2026**,
postérieur aux défauts ci-dessus : il n'en est **pas la cause**.

Il est faux de deux façons :

- **255 de ses valeurs sont la chaîne anglaise de `en.json`** (« Apply », « Close »,
  « Propose a merge », « Object »). Sur les 379 entrées où il diverge de `de.json`, **118
  divergent parce qu'il porte de l'anglais là où l'allemand est juste.**
- **Sa clé est la chaîne source**, donc il ne peut pas distinguer deux emplois d'un même mot.
  `de.json` rend correctement `address.postalCode.MX` « mexikanische Postleitzahl » et `.UY`
  « uruguayische » ; `pt2de.json`, avec une seule entrée pour « CP (código postal) », rend
  « argentinische » pour les trois. **169 chaînes portugaises** reçoivent légitimement
  plusieurs rendus allemands selon leur place : le format les aplatit toutes.

C'est `DOC-CONV-1` par l'autre bout — une même vérité, plusieurs rendus, et un artefact qui
les met en concurrence dans une seule colonne. Employé pour regarnir `de.json`, il y
injecterait 118 chaînes anglaises et détruirait 169 distinctions délibérées.

**À supprimer.** `de.json` est complet (6 570 clés) et n'a besoin de rien.

---

## 5. Ce que ça appelle

1. **Corriger** les 6 + 5 + 71 valeurs. Le grec du §2 demande une vraie traductrice, pas une
   retranslittération.
2. **Rendre `DOC-PS-1` mécanique** — un test i18n, pas un hook, parce que le critère est une
   propriété des fichiers et non du diff : (a) valeur identique à `en.json` hors liste
   blanche nommée ; (b) valeur de `el.json` sans lettre grecque ; (c) motifs de diacritiques
   mangés, par locale. Le test porte en en-tête sa requête et son angle mort.
3. **Refuser les brouillons à la racine** plutôt que les ignorer. Un `.gitignore` les rend
   *invisibles* — or le danger de `pt2de.json` était précisément d'avoir l'air réutilisable.
   Une huitième règle du `pre-commit`, refusant tout `.json` nouveau à la racine hors liste
   blanche (`package.json`, `package-lock.json`…), le dit au bon moment et laisse
   `git status` continuer à le montrer.

---

## Annexe — liste complète du §3

### `fr.json` — 19 valeurs

- **`account.readingNotes.hint`**  
  `Les notes de lecture que vous avez partagees, toutes oeuvres confondues.`  
  → attendu : *œuvres*
- **`auth.create.errorLibraryNotReady`**  
  `La bibliotheque selectionnee n'est pas encore entierement configuree sur le reseau. Contactez la coordination.`  
  → attendu : *bibliothèque*, *configurée*, *entièrement*, *réseau*, *sélectionnée*
- **`auth.create.errorProfileFailed`**  
  `Le compte a ete cree, mais une erreur est survenue lors de la configuration de votre profil. Contactez la coordination.`  
  → attendu : *créé*, *été*
- **`biblioteca.identity.readingNotes.hint`**  
  `Permet aux lecteur·rices valide·es de votre biblioteque de publier des notes de lecture sur les oeuvres, visibles dans le reseau. Vous en assurez la moderation.`  
  → attendu : *modération*, *réseau*, *validé*, *œuvres*
- **`biblioteca.readingNotes.hiddenNotes`**  
  `Notes masquees`  
  → attendu : *masquées*
- **`biblioteca.readingNotes.modIntro`**  
  `Notes signalees et notes masquees de votre bibliotheque. La moderation est a posteriori : les notes sont publiees directement, vous pouvez les masquer.`  
  → attendu : *bibliothèque*, *masquées*, *modération*, *publiées*, *signalées*
- **`catalogacao.authlink.autoLinked`**  
  `{count, plural, one {1 contributeur·rice lie·e automatiquement a une autorite existante} other {{count} contributeur·rice·s lie·e·s automatiquement a des autorites existantes}}`  
  → attendu : *autorité*
- **`catalogacao.catalog.description`**  
  `Consultez les documents, autorités et exemplaires publiés. Reprenez pour modifier ou mettre au rebut.`  
  → attendu : *autorité*
- **`catalogacao.isbnDup.badge`**  
  `ISBN deja au catalogue :`  
  → attendu : *déjà*
- **`catalogacao.msg.bibRefDuplicate`**  
  `La reference bibliographique {bibRef} est deja utilisee (fiche {bookId}). Modifiez-la avant de publier.`  
  → attendu : *déjà*
- **`catalogacao.presave.isbnExists`**  
  `ISBN deja present au catalogue : {detail}.\n\nContinuer la sauvegarde ?`  
  → attendu : *déjà*
- **`catalogacao.presave.titleAuthorExists`**  
  `Titre + auteur·rice deja presents au catalogue : {detail}.\n\nContinuer la sauvegarde ?`  
  → attendu : *déjà*, *présents*
- **`importacoes.deposit.alreadyExists`**  
  `Source « {name} » existait deja.`  
  → attendu : *déjà*
- **`importacoes.oai.desc`**  
  `Moissonnage automatique hebdomadaire de catalogues exposes via le protocole OAI-PMH. La configuration des sources est reservee a l'admin reseau.`  
  → attendu : *réseau*
- **`importacoes.oai.noSources`**  
  `Aucune source OAI-PMH configuree. Contactez l'admin reseau.`  
  → attendu : *configurée*, *réseau*
- **`importacoes.reception.libSlugPlaceholder`**  
  `bibliotheque-partenaire`  
  → attendu : *bibliothèque*
- **`panel.apiError.bib_ref_duplicado`**  
  `Cette reference bibliographique est deja utilisee par une autre fiche. Modifiez-la avant de publier.`  
  → attendu : *déjà*
- **`readingNotes.intro`**  
  `Des retours de lecture partages par les lecteur·rices du reseau.`  
  → attendu : *réseau*
- **`readingNotes.notEligibleHint`**  
  `Votre bibliotheque n'a pas (encore) active les notes de lecture, ou votre adhesion n'est pas validee.`  
  → attendu : *bibliothèque*

### `pt-BR.json` — 15 valeurs

- **`account.readingNotes.empty`**  
  `Voce ainda nao escreveu nenhuma nota de leitura.`  
  → attendu : *não*
- **`auth.create.errorGeneric`**  
  `Erro no cadastro. Informe o codigo abaixo a coordenacao`  
  → attendu : *coordenação*, *código*
- **`auth.create.errorLibraryNotReady`**  
  `A biblioteca selecionada ainda nao esta totalmente configurada na rede. Entre em contato com a coordenacao.`  
  → attendu : *coordenação*, *não*
- **`auth.create.errorProfileFailed`**  
  `A conta foi criada, mas houve um erro ao configurar seu perfil. Entre em contato com a coordenacao.`  
  → attendu : *coordenação*
- **`auth.create.errorServerConfig`**  
  `Erro de configuracao do servidor. Entre em contato com a coordenacao.`  
  → attendu : *coordenação*
- **`catalogacao.catalog.description`**  
  `Consulte documentos, autoridades e exemplares já publicados. Retome para editar ou descarte do catálogo.`  
  → attendu : *já*
- **`catalogacao.catalog.refreshBusy`**  
  `Atualização já em curso — tente de novo em instantes.`  
  → attendu : *já*
- **`catalogacao.catalog.title`**  
  `Catálogo(s) já publicado(s)`  
  → attendu : *já*
- **`catalogacao.isbnDup.badge`**  
  `ISBN ja no catalogo:`  
  → attendu : *catálogo*, *já*
- **`catalogacao.msg.bibRefDuplicate`**  
  `A referencia bibliografica {bibRef} ja esta em uso (ficha {bookId}). Altere a referencia antes de publicar.`  
  → attendu : *já*
- **`catalogacao.presave.isbnExists`**  
  `ISBN ja existente no catalogo: {detail}.\n\nDeseja continuar salvando mesmo assim?`  
  → attendu : *catálogo*, *já*
- **`catalogacao.presave.titleAuthorExists`**  
  `Titulo + autoria ja existentes no catalogo: {detail}.\n\nDeseja continuar salvando mesmo assim?`  
  → attendu : *catálogo*, *já*
- **`importacoes.deposit.alreadyExists`**  
  `Fonte « {name} » ja existia.`  
  → attendu : *já*
- **`panel.apiError.bib_ref_duplicado`**  
  `A referencia bibliografica ja esta em uso por outra ficha. Altere-a antes de publicar.`  
  → attendu : *já*
- **`readingNotes.notEligibleHint`**  
  `Sua biblioteca ainda nao ativou as notas de leitura, ou seu vinculo nao esta validado.`  
  → attendu : *não*

### `es.json` — 14 valeurs

- **`auth.create.errorGeneric`**  
  `Error en el registro. Comunica el codigo siguiente a la coordinacion`  
  → attendu : *coordinación*, *código*
- **`auth.create.errorLibraryNotReady`**  
  `La biblioteca seleccionada aun no esta completamente configurada en la red. Ponte en contacto con la coordinacion.`  
  → attendu : *coordinación*
- **`auth.create.errorProfileFailed`**  
  `La cuenta fue creada, pero hubo un error al configurar tu perfil. Ponte en contacto con la coordinacion.`  
  → attendu : *coordinación*
- **`auth.create.errorServerConfig`**  
  `Error de configuracion del servidor. Ponte en contacto con la coordinacion.`  
  → attendu : *coordinación*
- **`catalogacao.catalog.description`**  
  `Consulte documentos, autoridades y ejemplares publicados. Retome para editar o descarte del catalogo.`  
  → attendu : *catálogo*
- **`catalogacao.catalog.discardConfirm`**  
  `Descartar "{label}" del catalogo publicado?\n\nEsta accion es irreversible.`  
  → attendu : *acción*, *catálogo*
- **`catalogacao.catalog.discardDone`**  
  `"{label}" descartado del catalogo.`  
  → attendu : *catálogo*
- **`catalogacao.catalog.refresh`**  
  `↻ Actualizar catalogo publico`  
  → attendu : *catálogo*
- **`catalogacao.catalog.refreshTooltip`**  
  `Recompila las listas publicas del catalogo a partir de las tablas publicadas.`  
  → attendu : *catálogo*
- **`catalogacao.isbd.hint`**  
  `El boton "Preparar ISBD" relee la ficha en el orden de las zonas ISBD y graba en marc_json un paquete tecnico para uso futuro en la pagina de indice.`  
  → attendu : *página*
- **`catalogacao.isbnDup.badge`**  
  `ISBN ya en el catalogo:`  
  → attendu : *catálogo*
- **`catalogacao.presave.isbnExists`**  
  `ISBN ya existente en el catalogo: {detail}.\n\nDesea continuar guardando de todos modos?`  
  → attendu : *catálogo*
- **`catalogacao.presave.titleAuthorExists`**  
  `Titulo + autoria ya existentes en el catalogo: {detail}.\n\nDesea continuar guardando de todos modos?`  
  → attendu : *catálogo*
- **`catalogacao.queue.paginationInfo`**  
  `{total} borrador(es) en el filtro — mostrando {showing} — pagina {page} de {pages}`  
  → attendu : *página*

### `it.json` — 10 valeurs

- **`biblioteca.exchanges.followup.intro`**  
  `Segui l’esecuzione delle proposte di scambio gia accettate: fase, logistica, quantita e coordinamento tra le biblioteche.`  
  → attendu : *già*
- **`catalogacao.authlink.autoLinked`**  
  `{count, plural, one {1 contribut* collegat* automaticamente a un'autorita esistente} other {{count} contribut* collegat* automaticamente ad autorita esistenti}}`  
  → attendu : *autorità*
- **`catalogacao.isbnDup.badge`**  
  `ISBN gia nel catalogo:`  
  → attendu : *già*
- **`catalogacao.msg.bibRefDuplicate`**  
  `Il riferimento bibliografico {bibRef} e gia in uso (scheda {bookId}). Modificarlo prima di pubblicare.`  
  → attendu : *già*
- **`catalogacao.presave.isbnExists`**  
  `ISBN gia presente nel catalogo: {detail}.\n\nContinuare a salvare comunque?`  
  → attendu : *già*
- **`catalogacao.presave.titleAuthorExists`**  
  `Titolo + autore/trice gia presenti nel catalogo: {detail}.\n\nContinuare a salvare comunque?`  
  → attendu : *già*
- **`importacoes.deposit.alreadyExists`**  
  `Fonte « {name} » gia esistente.`  
  → attendu : *già*
- **`panel.apiError.bib_ref_duplicado`**  
  `Questo riferimento bibliografico e gia in uso da un altra scheda. Modificarlo prima di pubblicare.`  
  → attendu : *già*
- **`wizard.profile.option.governance_mode.full_governance.desc`**  
  `I cambi di profilo richiedono votazione formale secondo regole chiare. Struttura completa per biblioteche federate con piu persone coinvolte.`  
  → attendu : *più*
- **`wizard.profile.option.network_mode.observer.desc`**  
  `La tua biblioteca puo vedere la rete e condividere il suo catalogo, ma non partecipa al prestito interbibliotecario.`  
  → attendu : *può*

### `de.json` — 8 valeurs

- **`biblioteca.contactProfile.intro`**  
  `Kontaktdaten der Bibliothek, den anderen Bibliotheken des Netzwerks fuer die Fernleihe und die Tausche gezeigt. Es ist der menschliche Kontakt — wen erreichen, wie, wo —, getrennt von der technischen Versand-E-Mail.`  
  → attendu : *für*
- **`biblioteca.contactProfile.postal_address.placeholder`**  
  `Anschrift fuer den Versand oder die Abholung von Dokumenten.`  
  → attendu : *für*
- **`biblioteca.exchanges.disabledByPolicy`**  
  `Die lokale Richtlinie gibt an, dass Tausche fuer diese Bibliothek noch nicht aktiviert sind.`  
  → attendu : *für*
- **`biblioteca.exchanges.docNotEligible`**  
  `Die gewaehlten Dokumente muessen die Tauschkriterien erfuellen.`  
  → attendu : *gewählten*, *müssen*
- **`biblioteca.exchanges.elig.criteriaNoAvailable`**  
  `ohne Filter fuer sofortige Verfuegbarkeit`  
  → attendu : *für*
- **`biblioteca.exchanges.followup.logistics.in_person`**  
  `Persoenliche Uebergabe`  
  → attendu : *Übergabe*
- **`biblioteca.exchanges.followup.meetingPointPlaceholder`**  
  `Referenz fuer Abholung, Versand oder Uebergabe.`  
  → attendu : *für*, *Übergabe*
- **`biblioteca.ill.coordinationHelp`**  
  `Gib die Kontaktperson deiner Bibliothek an, die die andere Seite fuer die Abstimmung dieser Leihe erreichen kann.`  
  → attendu : *für*

### `ca.json` — 3 valeurs

- **`catalogacao.isbnDup.badge`**  
  `ISBN ja al cataleg:`  
  → attendu : *catàleg*
- **`catalogacao.presave.isbnExists`**  
  `ISBN ja existent al cataleg: {detail}.\n\nVoleu continuar desant de totes maneres?`  
  → attendu : *catàleg*
- **`catalogacao.presave.titleAuthorExists`**  
  `Titol + autoria ja existents al cataleg: {detail}.\n\nVoleu continuar desant de totes maneres?`  
  → attendu : *catàleg*

### `eo.json` — 2 valeurs

- **`catalogacao.presave.isbnExists`**  
  `ISBN jam ekzistas en la katalogo: {detail}.\n\nChu dauri konservi?`  
  → attendu : *daŭri*, *Ĉu*
- **`catalogacao.presave.titleAuthorExists`**  
  `Titolo + aŭtoreco jam ekzistas en la katalogo: {detail}.\n\nChu dauri konservi?`  
  → attendu : *daŭri*, *Ĉu*
