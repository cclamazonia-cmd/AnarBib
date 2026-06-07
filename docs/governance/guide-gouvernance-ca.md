---
title: "Guia de governança d'AnarBib"
subtitle: "Per a l'ús de les coordinador-a-es de biblio i de les administrador-a-es de la xarxa"
author: "Projet AnarBib"
date: "Versió 1.1 — 5 de juny de 2026"
lang: ca
---

# Pròleg

Aquesta guia s'adreça a les persones que, a la xarxa AnarBib, exerceixen una funció de coordinació — tant si es tracta de coordinar una biblio local com d'administrar la xarxa. Té un doble objectiu :

- **Explicar la lògica política** de les regles inscrites al SIGB AnarBib, i la seva filiació amb el projecte d'emancipació col·lectiva que va donar lloc a les biblioteques anarquistes ;
- **Dotar les pràctiques** del dia a dia, responent les preguntes concretes que les coordinacions es troben quan utilitzen el programari.

## Una convenció política

Aquesta guia no és el reglament de la xarxa, i no té cap autoritat superior a les decisions dels col·lectius que la componen. Allò que conté només té força perquè persones humanes s'han posat d'acord per fer funcionar les coses d'aquesta manera en un moment determinat. Si les pràctiques evolucionen, aquest text haurà d'evolucionar amb elles, o ser contradit, o ser esbocinat. Serà l'ús que en facin els col·lectius qui en decidirà el destí.

Les regles tècniques que el SIGB AnarBib fa respectar — els terminis de carència, els workflows de cooptació, els estats dels memberships, etc. — també són convencions. Les van escriure companys i companyes en dates precises, per resoldre problemes precisos. Estan consignades en **fitxers d'especificació** (els `spec-*.md` del repositori), datats i signats, que ells mateixos són esmenables. Quan es llegeix aquesta guia, es llegeix l'estat d'un debat en un moment donat. No és una constitució.

## Com s'organitza aquesta guia

La guia és en dues parts :

- **Part I — El perquè.** Quatre capítols que estableixen el marc polític : per a què serveix un SIGB anarquista, quins són els seus principis fundadors, com s'articulen els dos àmbits (biblio local i xarxa), i com les mateixes regles poden ser esmenades.

- **Part II — El com.** Sis capítols pràctics que tracten cadascun una gran qüestió operacional : cooptar, retirar, gestionar les situacions que es descontrolen, exercir una funció d'admin xarxa, garantir la transparència, i un últim capítol que comenta casos concrets de principi a fi.

Al final de cada capítol pràctic, una secció **«Si la regla us molesta»** recorda on discutir-ho i com proposar una esmena. Això és important perquè aquestes regles només tenen sentit si són esmenables.

Els annexos al final del volum serveixen de referència ràpida : glossari, índex de les funcions tècniques amb la seva traducció política, model de proposta d'esmena, i enllaços cap a les specs fonts.

## Com llegir aquesta guia

Es pot llegir d'una tirada, però probablement no és el millor ús. Tres maneres d'entrar al text segons les necessitats :

- **Per comprendre l'esperit del projecte** abans de prendre una funció : llegir la part I (capítols 1 a 4).
- **Davant d'una situació concreta** : saltar directament al capítol pràctic corresponent (5 a 10).
- **Per informar-se en vista d'una AG** on es plantejarà una qüestió de governança : llegir el capítol corresponent més la secció «Si la regla us molesta» corresponent, i consultar la spec font a l'annex D.

Allò que s'escriu aquí es basa en quatre documents d'especificació :

- `spec-gouvernance-roles.md` (5 de maig de 2026) — rols, estats, transicions ;
- `spec-administrateur-reseau.md` (11 de maig de 2026) — separació local/xarxa, cooptació per unanimitat ;
- `spec-validation-physique.md` (3 de maig de 2026) — modes d'acollida dels comptes lector-a-es ;
- `spec-refactor-v3-semantique.md` (9 de maig de 2026) — semàntica del workflow de reserva (esmentat al marge).

Les referències a aquestes specs es recorden al llarg del text sota la forma `(cf. spec-gouvernance, §3.4)` per permetre d'aprofundir.

## Una nota sobre la veu

El text alterna entre **hom** (el col·lectiu AnarBib, del qual l'autor-a-e i le lector-a-e també formen part), **vosaltres** (quan ens adrecem a una coord o admin concret-a-e que ha de prendre una decisió), i **nosaltres** (quan parlem de les companyes i companys que van escriure les regles, en un moment donat, i que podrien ser diferents de qui les llegeix). Això és voluntari. No hi ha cap neutralitat institucional aquí : aquest text el porten companyes i companys, i s'adreça a companyes i companys.

\newpage

# Part I — El perquè

\newpage

# 1. Un SIGB anarquista, què vol dir?

## 1.1. El SIGB no és l'AG

El primer principi a tenir present, i el més difícil, és aquest : **el SIGB registra les decisions del col·lectiu, no les pren**. Aquesta frase sembla trivial. En realitat és el pivot al voltant del qual s'organitza tot allò que en depèn.

Totes les vegades que el SIGB AnarBib pren l'aire d'una autoritat — quan refusa una promoció, quan imposa un termini de carència de set dies, quan bloqueja una transició d'estat — no fa més que **fer executable** una regla que els col·lectius s'han donat. La regla s'ha escrit en algun lloc, en una spec, després d'una discussió. Algú l'ha rellegit i criticat. Una versió s'ha fixat i desplegat. I ara, en l'instant en què cliqueu el botó, el programari es limita a aplicar allò que s'havia convingut.

Si trobeu la regla estúpida, contraproduent, o injusta, no és el SIGB el que cal combatre. És la spec el que cal esmenar. Vegeu el capítol 4.

## 1.2. La tensió assumida

Tot programari que gestiona permisos és, per construcció, un dispositiu de jerarquització. Cal que algú pugui validar una inscripció, modificar la identitat pública d'una biblio, accedir a les dades personals d'un-a lector-a-e. Aquesta necessitat tècnica es troba en tensió aparent amb l'ideal d'horitzontalitat que anima les biblioteques anarquistes.

AnarBib **assumeix aquesta tensió** en lloc d'amagar-la. El compromís polític que s'ha trobat es sosté en dos punts :

- Els **rols no són graus**. Són **funcions** temporalment delegades pel col·lectiu a algunes de les seves persones membres per executar tasques tècniques precises. Ningú no és coordinador-a-e «a vida». Ningú no és admin xarxa «per essència». Aquestes funcions es presten, i es poden recuperar.

- Els **mecanismes de retirada** compten tant com els mecanismes de nomenament. El SIGB preveu explícitament com algú surt d'una funció — per autoretrogradació, per petició col·lectiva amb termini de carència, per autoretirada de la xarxa, per retirada col·lectiva per unanimitat. Una funció que no es pot deixar no és una funció, és una captació.

## 1.3. Delegació i rotació

La idea central és la de la **delegació amb rotació**. Un col·lectiu delega a algunes de les seves persones membres l'execució de tasques tècniques (gestionar els préstecs al SIGB, modificar la visibilitat de la biblio, acollir un nou membre a l'equip). Aquesta delegació és :

- **Explícita** : s'encarna en un acte de cooptació traçat en el log d'auditoria ;
- **Reversible** : la persona delegada pot deixar la funció quan vulgui, i el col·lectiu li ho pot demanar segons modalitats enquadrades ;
- **Temporal per naturalesa** : tot i que el SIGB no imposa cap durada, la cultura política de la xarxa és que es fan rotar les funcions, i no s'hi instal·la ningú.

És aquesta rotació de les funcions la que marca la diferència entre una «delegació» (anarquista) i una «jerarquia» (estatal o capitalista). Si hom s'instal·la en una funció, es converteix en un esglaó. Si se'n surt regularment, continua sent una companya o company que ofereix un servei.

## 1.4. Els vuit principis fundadors

La spec de governança dels rols (`spec-gouvernance-roles.md`, §2) explica vuit principis fundadors. S'enumeren aquí per fer-hi referència al llarg de la guia ; cada capítol pràctic de la part II hi remetrà.

**P1 — Delegació, no jerarquia.** Cap rol no és un títol. Tots els rols són temporals per naturalesa i revocables.

**P2 — Cooptació per als rols staff.** L'entrada en un equip (convertir-se en librarian o coordenador) es fa per cooptació de les coordenadores existents. És el col·lectiu qui decideix qui és admès ; le coordinador-a-e no és més que la mà que executa la decisió al SIGB.

**P3 — Autoretrogradació voluntària sempre possible.** Tota persona amb un rol staff pot retrogradar-se ella mateixa en qualsevol moment, sense consulta. «Passo el relleu» és un dret fonamental.

**P4 — Exclusió enquadrada per un termini de carència.** L'exclusió no voluntària d'una persona librarian per part d'un-a coordinador-a-e passa per un termini de carència de set dies abans de tenir efecte. Aquest termini permet la deliberació col·lectiva i l'eventual anulació per part d'un-a altra coordinador-a-e.

**P5 — Transparència màxima.** El log d'auditoria dels canvis de rol és llegible per l'ensemble del staff actiu de la biblio, no solament per les coordenadores. Impedir les manipulacions opaques forma part de la cultura política d'horitzontalitat informacional.

**P6 — Notificacions sistemàtiques.** Tot canvi de rol desencadena un correu electrònic a la persona concernida i a tota la coordinació. Ningú no pot ser modificat-ada-e en el seu rol sense saber-ho, i la coordinació sempre és informada.

**P7 — Sobirania local de les biblios.** Els canvis de rol a la biblio A no afecten res a la biblio B, fins i tot per a la mateixa persona. Cada biblio és sobirana sobre les seves delegacions internes.

**P8 — El SIGB no modela l'AG.** El SIGB executa les decisions, no les pren. No conté cap mecanisme de votació, de quòrum, ni de deliberació. Aquestes coses es fan en col·lectiu, fora del programari.

## 1.5. Allò que el SIGB no fa

És útil fer explícites les opcions de **no-modelatge** :

- El SIGB **no defineix** allò que és una «bona» coordinació. Una biblio pot decidir en cercle, en AG plenària, per torn, per sorteig, per consens, per majoria. El SIGB no s'interessa per això.
- El SIGB **no mesura** la legitimitat política d'una cooptació. Si una coord clica «promocionar X librarian», el SIGB registra. És al col·lectiu d'assegurar-se que la decisió s'ha pres correctament, i és en la cultura política del col·lectiu on es juga aquesta garantia.
- El SIGB **no arbitra** els conflictes. Quan alguna cosa es descontrola, el SIGB proporciona eines (suspensió immediata, petició de retirada, log d'auditoria llegible) però la decisió política es manté fora del programari.

Aquesta modèstia no és un defecte, és una exigència. Un SIGB que pretengués modelar la vida política d'un col·lectiu seria, ipso facto, autoritari — imposaria la seva visió del que és una «bona» decisió. AnarBib refusa aquest pendent.

## 1.6. I el respecte de les llibertats digitals ?

Tres precisions, perquè la qüestió reapareix :

- **Dades personals** : els comptes de lector-a-es contenen allò que la persona ha volgut posar-hi. Les biblios només tenen accés a les dades estrictament necessàries per al seu funcionament. Els memberships en altres biblios són, per construcció, estancs (P7).

- **Log d'auditoria** : el log és públic **al staff actiu** de la biblio, no a les lector-a-es ni a la resta de la xarxa. Aquesta transparència interna serveix per impedir les manipulacions opaques entre coordinacions ; no és un panòptic dirigit contra les lector-a-es.

- **Logs cross-biblios** : quan una admin xarxa intervé en una biblio (cas cobert per la spec admin-reseau, §6.3.1), l'acció es traça en una taula dedicada amb nivell de criticitat. És llegible per les admins xarxa i per la coordinació de la biblio concernida. La transparència en els dos sentits.

\newpage

# 2. Els dos àmbits : biblio local i xarxa

## 2.1. Per què aquesta separació

La xarxa AnarBib no és una cadena de biblioteques amb una seu central. És una **federació de col·lectius autònoms**. Aquesta realitat política ha acabat imposant-se en l'estructura del SIGB mateix.

Inicialment, en les primeres versions, el rol d'«administrador·a AnarBib» estava vinculat a una biblio concreta a la taula `user_library_memberships`. Aquest modelatge suggeria — sense dir-ho — que una admin AnarBib *administrava una biblio*. Això no era políticament cert : una admin xarxa anima la coordinació inter-biblios, no dirigeix cap biblio en particular.

La spec `spec-administrateur-reseau.md` (11 de maig de 2026) va actar la separació. A partir d'ara el SIGB reconeix **dos àmbits distints** :

- **El staff local** d'una biblio (rols `reader`, `librarian`, `coordenador`), emmagatzemat a `user_library_memberships`. La seva autoritat política es situa **dins l'àmbit de la biblio**.

- **L'administració de la xarxa** (taula `network_administrators`), sense vinculació a cap biblio. La seva autoritat política és **transversal**, però mai no se substitueix a l'autonomia local.

## 2.2. Allò que fa cada àmbit

**El staff local** gestiona el dia a dia d'una biblio : préstecs, devolucions, reserves, validació de les inscripcions, modificació del reglament, de les polítiques de circulació, de la identitat pública de la biblio. Tot allò que concerneix el funcionament d'**una** biblio es resol a nivell del staff local.

**L'administració de la xarxa** assegura la coordinació inter-biblios : activació de les noves biblios, moderació del catàleg compartit, manteniment tècnic de la plataforma, acollida dels nous col·lectius, i intervenció excepcional quan una biblio es troba en bloqueig (sense coord actiu-iva-e, conflicte major, etc.). Tot allò que concerneix la **xarxa** es resol a nivell de l'administració xarxa.

## 2.3. La regla de la no-superposició

Una regla política simple guia tots els comptadors i totes les vistes del SIGB :

> **Cada pàgina explica la història del seu àmbit. Un comptador compta allò que s'inscriu en el seu àmbit, ni més ni menys.**

Concretament :

- La pàgina d'una biblio compta els seus memberships locals. Punt. Les admins xarxa no apareixen en aquests comptadors, fins i tot si poden tècnicament intervenir en la biblio.
- La pàgina de la xarxa compta les seves administrador-a-es xarxa. Punt.

Si una persona és alhora `coordenador` d'una biblio **i** administrador-a-e xarxa (el cas de Xavier a l'11 de maig de 2026), apareix en els dos comptadors, **una vegada en cadascun**, sense deduplicació creuada. Són **dues inscripcions polítiques distintes**, comptades cadascuna en el seu àmbit.

Per què aquesta regla és políticament sana, en quatre punts :

- **Honestedat** : el teu compromís local es compta a la biblio on actues ; el teu compromís xarxa es compta al nivell xarxa. Ningú no et compta «1,5 vegades».
- **Llegibilitat** : una militant que mira la fitxa d'una biblio veu immediatament quantes persones estan compromeses **localment**, sense haver-se de preguntar si les admins xarxa «exteriors» inflen el comptador.
- **Robustesa** : si demà s'afegeixen rols intermedis (auxiliar, aprenent, observador-a-e), la regla «pàgina = àmbit» es manté clara.
- **Coherència política** : la separació entre admin xarxa i staff local és una **decisió política**, no un detall de modelatge. Els comptadors han de reflectir-la.

## 2.4. El dret transversal de l'admin xarxa

Aquest punt mereix ser ben comprès perquè és fàcil malinterpretar-lo.

**Una admin xarxa pot tècnicament intervenir en qualsevol biblio.** Pot, per exemple, llegir el catàleg d'una biblio `private`, modificar-ne la visibilitat, o — en casos excepcionals — crear o modificar memberships. Això és el que la spec anomena el **dret d'intervenció transversal**.

Aquest dret existeix per dues raons :

- **Manteniment** : cal que algú pugui desbloquejar una biblio que s'ha posat en pana (sense coord, configuració trencada, etc.).
- **Mediació** : quan un conflicte greu travessa una biblio i impedeix al col·lectiu local de funcionar, cal un recurs.

Però aquest dret **no** fa de l'admin xarxa una persona superior jeràrquica de la coordinació local. La doctrina de la xarxa, establerta en aquesta guia :

> **Una intervenció d'admin xarxa en una biblio local ha d'anar precedida d'una informació a la coordinació local concernida**, llevat d'urgència vital (compromissió activa, assetjament en curs, atac contra la plataforma). La informació prèvia no és una petició d'autorització : l'admin xarxa té el dret d'actuar. Però és una **mostra de respecte** envers l'autonomia de la biblio, i preserva la possibilitat d'un altre acord (per exemple : «deixa'm intentar resoldre-ho primer, t'ho faré saber»).

La traçabilitat tècnica existeix d'altra banda : totes les accions cross-biblios d'una admin xarxa es traça a la taula `cross_library_actions_log` amb un nivell de criticitat, llegibles per la coordinació local a posteriori.

## 2.5. La sobirania local és inviolable

Una última precisió política, que es deriva del principi **P7 — Sobirania local de les biblios**.

Les biblios de la xarxa AnarBib **es reconeixen mútuament**. Quan BLMF valida físicament una nova lector-a-e (cf. `spec-validation-physique.md`), aquesta validació és vàlida per a totes les biblios `network` de la xarxa. Això és un **pacte de circulació implícit** entre biblios que comparteixen prou cultura política per a confiar-se mútuament.

Però aquest reconeixement mutu **no dóna cap dret d'ingerència** d'una biblio en una altra. La coordinació de la biblio A no pot modificar els memberships de la biblio B. No pot veure les dades personals de les lector-a-es de B (excepte les que també estan inscrites a la seva). No pot canviar el reglament de B.

Cada biblio continua sent **sobirana sobre les seves delegacions internes**, la seva política d'acollida, el seu mode de validació, les seves regles de cotització, el seu reglament intern. La xarxa no diu com han de funcionar. Només diu amb qui es reconeixen.

\newpage

# 3. Estatuts, rols, transicions: la gramàtica del SIGB

Aquest capítol és una mica més àrid que els altres. Aquí s'estableix el vocabulari tècnic que s'usarà al llarg de tota la guia. Si el salteu en la primera lectura, podreu tornar-hi quan calgui.

## 3.1. Els quatre rols

El SIGB AnarBib utilitza quatre rols, declarats a la base de dades mitjançant la restricció `CHECK (role = ANY (ARRAY['reader', 'librarian', 'coordenador', 'administrador']))` a la taula `user_library_memberships`.

**`reader`** — Compte lector-a-e bàsic-a-e. Sense poder d'administració. Permisos: consultar el catàleg (segons la visibilitat de la biblio), fer préstecs, fer reserves, consultar en sala, modificar les pròpies dades personals, sol·licitar la migració o supressió del compte.

**`librarian`** — Staff operacional. Gestiona el dia a dia: préstecs, reserves, devolucions, validació de les inscripcions (segons el mode de la biblio), modificació de les dades del catàleg, accés a les dades personals dels lector-a-es de la biblio. **Lectura només** de la llista de l'equip. Rep les notificacions de canvis de rol i pot llegir el registre d'auditoria de l'equip (P5).

**`coordenador`** — Staff de coordinació. Tot el que té un-a librarian, més: modificar la identitat pública de la biblio (nom, logotip, contacte, etc.), modificar la configuració (polítiques de préstec, reglament), gestionar les regles de quotes, **i totes les accions de governança d'equip**: cooptar, sol·licitar una retirada, suspendre, aixecar una suspensió, cancel·lar una sol·licitud de retirada.

**`administrador`** — Rol històric, en vies de desaparició. Existia per significar «dret d'administració trans-biblios» però vinculat a un `library_id`. Ara substituït pels **administrador-a-es de xarxa** emmagatzemat-a-es a la taula `network_administrators` (cf. capítol 2). L'especificació admin-xarxa preveu la migració progressiva i la retirada final d'aquest rol de la taula `user_library_memberships`.

## 3.2. Els cinc estatuts d'una membership

Cada fila de la taula `user_library_memberships` té un **estatut** que expressa l'estat de la delegació en un moment donat. Cinc estatuts són possibles:

**`active`** — Estat normal. La persona té el seu rol i l'exerceix.

**`pending`** — Reservat a l'especificació de validació física. La membership és creada però en espera d'una trobada física amb un-a librarian+ de la biblio d'inscripció. Sense accés a les funcions del rol mentre duri aquest estatut.

**`suspended`** — **Mesura cautelar** presa per un-a coordenador-a. Cap accés. Ús: assetjament reportat a l'espera d'investigació, compte compromès, conflicte en curs de mediació. **Durada indefinida**; l'aixecament és manual, per un-a coord (retorn a `active`) o per destitució efectiva.

**`pending_removal`** — **Període de carència de set dies** abans de l'exclusió efectiva. Cap accés durant aquest període. Evolució possible: cancel·lació per un-a altre-a coord (retorn a `active`), auto-retrogressió per la pròpia persona (curtcircuit), o pas automàtic a `inactive` a J+7.

**`inactive`** — Membership tancada. La persona ja no és a l'equip. Cap accés. Diversos orígens possibles: sortida voluntària, fi de carència, compte abandonat (automàtic als 9 mesos).

## 3.3. L'esquema de transicions

El SIGB no autoritza qualsevol transició entre estatuts. Aquí, simplificat, l'esquema autoritzat:

```
                       ┌──────────────┐
                       │   active     │ ◄──────────┐
                       └──────┬───────┘            │
                              │                    │
              ┌───────────────┼───────────────┐    │
              ▼               ▼               ▼    │
       ┌─────────────┐  ┌─────────────┐  ┌─────────┴────┐
       │  suspended  │  │ pending_    │  │  inactive    │
       │             │  │ removal     │  │              │
       └──────┬──────┘  └──────┬──────┘  └──────────────┘
              │                │
              │ aixecament     │ cancel·lació
              └────────────────┴────────────┐
                               │            │
                               ▼ (J+7)      ▼
                        ┌──────────────┐
                        │   inactive   │
                        └──────────────┘
```

Algunes regles clau:

- **No** es pot passar directament de `active` a `inactive` per a un-a librarian per decisió unilateral d'un-a altre-a coord. Cal passar per `pending_removal` i esperar la carència (o que la persona es retrogradi ella mateixa).
- Es pot **sempre** passar del propi estatut `active` a `inactive` (auto-retro, dret P3).
- `suspended` **no** té durada màxima. No és una carència abans de l'exclusió, és una mesura cautelar — dura el temps de la deliberació.
- De `inactive`, **no es torna** a `active`. Per reintegrar una persona, es crea una nova fila de membership. L'historial es preserva.

## 3.4. Les nou transicions, qui pot fer què

L'especificació de governança dels rols formalitza nou transicions, llistades aquí de manera condensada. El detall operacional és a la part II.

| # | Transició | Qui | Mecanisme |
|---|---|---|---|
| T1 | `reader` → `librarian` | Coord+ | Cooptació |
| T2 | `librarian` → `coordenador` | Coord+ | Cooptació |
| T3 | `coordenador` → `librarian` | Pròpia persona O altres coords | Auto-retro O retirada col·legiada amb carència |
| T4 | `librarian` → `reader` (voluntari) | Pròpia persona | Auto-retro |
| T5 | `librarian` → `reader` (col·lectiu) | Coord+ | `pending_removal` amb carència 7 dies |
| T6 | Suspensió immediata | Coord+ | Pas a `suspended` |
| T7 | Aixecament de suspensió | Coord+ | Retorn `suspended` → `active` |
| T8 | Cancel·lació d'una sol·licitud de retirada | Coord+ | Retorn `pending_removal` → `active` |
| T9 | Sortida automàtica (compte abandonat) | Cron | Pas a `inactive` després de 9 mesos sense login |

Tres principis estructuren aquesta taula:

- **L'entrada passa per la cooptació** (T1, T2). Ningú no es promou a si mateix.
- **La sortida voluntària és sempre possible** (T3 auto, T4). Ningú no queda atrapat en una funció que ja no vol exercir.
- **La sortida imposada és frenada per la carència** (T5). Set dies per permetre l'eventual marxa enrere col·legiada.

## 3.5. Costat admin de xarxa: un esquema bessó

L'administració de xarxa (taula `network_administrators`) té el seu propi cicle de vida, estructuralment molt proper però amb dues especificitats:

- **Cooptació per unanimitat**: per afegir un-a nou-a admin de xarxa, un-a admin actiu-iva obre una proposta, i **tots els altres admins actius-ives** han de votar `favorable`. Un sol vot `opposed` (amb raonament obligatori de 20 caràcters mínim) bloqueja la proposta. Una abstenció també bloqueja mentre no es converteixi en vot.

- **Retirada col·lectiva per unanimitat**: per retirar un-a admin de xarxa contra la seva voluntat, s'aplica el mateix flux en mirall. Amb un termini de carència de **set dies** després de l'acord unànime (camp `pending_collective_removal_until`).

L'auto-retirada, en canvi, és **unilateral i sempre possible** (excepte si s'és l'únic-a admin actiu-iva, en aquest cas la transició passa per `pending_removal` amb una carència de 30 dies, i un correu d'alerta als altres admins).

Detalls complets al capítol 8.

\newpage

# 4. Reversibilitat i esmenabilitat

Aquest capítol curt tracta d'una qüestió política crucial: **com es poden modificar aquestes regles?** Si no poguessin ser-ho, el SIGB seria una autoritat, i tota la resta d'aquesta guia seria una mentida.

## 4.1. Tres nivells d'esmenabilitat

Cal distingir tres nivells de regles, que no s'esmenen de la mateixa manera:

**Les pràctiques locals d'una biblio** — política d'acollida, mode de validació física (`open` o `manual_validation`), reglament intern, freqüència de les AG, modalitats de cooptació. Aquestes pràctiques són **internes a cada biblio**. La xarxa no s'hi fica. S'esmenen en AG de biblio, o segons el procediment que el col·lectiu s'ha donat.

**Les regles de la xarxa** — separació local/xarxa, principi de cooptació per unanimitat per als admins de xarxa, doctrina d'informació prèvia en una intervenció trans-biblios, modalitats d'activació de les noves biblios. Aquestes regles són **inter-biblios**. S'esmenen en coordinació de xarxa, després de discussió entre admins de xarxa i coordinacions locals concernides.

**Els fonaments polítics del projecte** — els vuit principis (P1 a P8 del capítol 1), la idea que el SIGB no modela l'AG, la modèstia reivindicada del programari davant la vida política dels col·lectius. Aquests fonaments es poden esmenar, però són estructurants: modificar-los és probablement modificar el que s'entén per «AnarBib» en sentit ampli. Una impugnació d'aquesta envergadura passaria per una discussió col·lectiva a tota la xarxa, probablement amb motiu d'un esdeveniment (trobada anual, etc.).

## 4.2. Com proposar una esmena

No hi ha una sola manera de fer-ho — cada nivell té la seva — però aquí teniu el patró general que la xarxa tendeix a practicar:

1. **Identificar l'especificació concernida**. Les regles del SIGB estan recollides en fitxers `spec-*.md` del repositori. Trobeu la que conté la regla que voleu esmenar (l'annex D dona les correspondències).

2. **Redactar una nota d'esmena**. Format lliure, però que respongui a: quina regla, per què planteja un problema, quina modificació es proposa, quines conseqüències tècniques i polítiques s'anticipen. L'annex C proposa un model.

3. **Fer circular la nota**. Segons el nivell:
   - **Local**: en AG de biblio, o al canal de discussió del col·lectiu.
   - **Xarxa**: al canal de coordinació inter-biblios (Matrix `#anarbib`), etiquetant els admins de xarxa i les coordinacions locals pertinents.
   - **Fonaments**: a tots els canals, i probablement a l'ordre del dia d'una trobada.

4. **Discutir, esmenar, retenir una versió**. El SIGB no diu com ha de transcórrer aquesta etapa. És la feina dels col·lectius.

5. **Si la decisió és presa**: un-a admin de xarxa o un-a dev (sovint les mateixes persones) implementa la modificació a l'especificació corresponent, i després al codi. La nova versió es desplega segons el procediment habitual (changelog, comunicació, etc.).

## 4.3. Si la decisió tècnica planteja un problema

Passa que s'arriba a un acord polític sobre una regla, però que la seva traducció tècnica és complicada, pesada, o té efectes secundaris indesitjables. Això és normal. Les especificacions existents són plenes de notes del tipus «aquesta decisió política implica tocar 22 sub-SELECT als RLS, cosa que justifica una refactorització prèvia». El diàleg polític / tècnic és permanent.

Quan proposeu una esmena, no dubteu a fer-ho fins i tot si no teniu cap idea de la dificultat tècnica. Les dev de la xarxa us diran el que costa. I si és molt car, podreu decidir col·lectivament si la qüestió política val el cost tècnic. A la inversa, de vegades un canvi polític anodí permet simplificar enormement la base de codi.

## 4.4. Aquesta guia és ella mateixa esmenable

Aquesta guia està versionada. La versió actual s'indica a la pàgina de coberta. Si trobeu que diu alguna cosa incorrecta, que ha oblidat un cas, o que pren una posició que ja no correspon a la doctrina de la xarxa, **digueu-ho**. Obriu una discussió, proposeu una modificació, o reescriviu el passatge i envieu-lo.

Una guia que no es pot modificar no és una guia, és un dogma. El projecte AnarBib no té vocació de produir dogmes.

\newpage

# Part II — El com

\newpage

# 5. Cooptar algú a l'equip

Aquest capítol cobreix les transicions T1 (`reader` → `librarian`) i T2 (`librarian` → `coordenador`), és a dir els **dos moviments d'entrada** en un equip de biblio. La validació física d'un-a nou-a `reader` (que no és una cooptació en el sentit polític sinó una operació tècnica d'acollida) és tractada separadament al §5.5.

## 5.1. El principi polític

> **P2 — Cooptació per als rols staff.** L'entrada en un equip es fa per cooptació dels coordenadores existents. És al col·lectiu polític de decidir qui és admès; le coordinador-a no és més que la mà que executa la decisió al SIGB.

Això significa que **clicar «Promocionar»** no és una decisió personal de le coord que clica. És l'**execució tècnica** d'una decisió que ha estat presa — o ha de ser-ho — pel col·lectiu polític de la biblio. La doctrina de la xarxa sobre el «quan exactament» la decisió ha de ser presa no és deliberadament resoluda per aquesta guia: cada biblio fa la seva pròpia doctrina (vegeu §5.4).

## 5.2. Per fer entrar algú com a `librarian` (T1)

### Precondicions

- La persona té un compte AnarBib (està inscrita en algun lloc de la xarxa).
- No té ja una membership `librarian` o `coordenador` activa a la mateixa biblio.
- Pot tenir, o no, ja una membership `reader` a la mateixa biblio. Si és així, aquesta membership existent continuarà activa en paral·lel (multi-membership autoritzada).

### Procediment al SIGB

1. Anar a `/biblioteca`, pestanya **Equip** (visible als `coordenador+`).
2. Si la persona ja és lectora-a-e de la biblio, clicar **«Convidar a l'equip»** a la seva fila. Si encara no és lectora-a-e, usar la cerca a la barra superior o — si encara no té compte — passar pel flux d'invitació per correu electrònic (pendent, cf. `spec-invitation-equipe.md`).
3. Triar el rol `librarian`.
4. Confirmar la modal. Un camp «Raó» és opcional — serveix per inscriure a l'audit log el context de la cooptació (per exemple «decisió AG del 04/05», o «cooptació en cercle reduït, a validar a la pròxima AG»).
5. El SIGB executa:
   - Creació d'una fila `user_library_memberships` amb `role='librarian'`, `status='active'`.
   - Correu a la persona concernida: «Has estat nomenada librarian de [biblio] per [vosaltres]».
   - Correu a tots-es les coordenadores actius-ves de la biblio.
   - Entrada a l'audit log: `action='promoted_to_librarian'`.

### Efecte immediat

La persona rep, sense demora, els permisos de `librarian`: gestió dels préstecs, validació de les inscripcions, accés a les dades personals dels lector-a-es de la biblio, etc. No rep els permisos de modificació de la identitat pública ni de la configuració — aquests estan reservats als `coordenador+`.

### Costat tècnic

RPC concernida: `fn_team_promote_to_librarian(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.3. Per promocionar un-a `librarian` a `coordenador` (T2)

### Precondicions

- La persona té una membership `librarian` `active` a la biblio.
- No té ja una membership `coordenador` activa a la mateixa biblio.

### Procediment al SIGB

1. Anar a `/biblioteca`, pestanya **Equip**.
2. A la fila de la persona, clicar **«Promocionar»** → **«coordenador»**.
3. Confirmar la modal. El camp «Raó» és opcional.
4. El SIGB executa:
   - Creació (o reactivació) d'una fila `coordenador` `active`. L'antiga fila `librarian` continua activa en paral·lel (multi-membership; vegeu §5.6).
   - Correu a la persona.
   - Correu a tots-es les coordenadores actius-ves.
   - Entrada a l'audit log: `action='promoted_to_coordenador'`.

### Efecte immediat

La persona rep, a més dels seus permisos de `librarian`, els permisos de coordinació: modificació de la identitat pública, de la configuració, de les regles de quotes, i totes les accions de governança d'equip.

### Costat tècnic

RPC concernida: `fn_team_promote_to_coordenador(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.4. La qüestió política: quan clicar?

És la pregunta que tot-a coord es fa la primera vegada. La xarxa AnarBib **deliberadament no ha resolt** aquesta qüestió a nivell de guia: cada biblio fa la seva pròpia doctrina, perquè la cultura política d'un col·lectiu anarquista no es decideix a l'escala d'una guia genèrica.

Aquí teniu les tres doctrines que es troben a la xarxa, sense judici:

**Doctrina 1 — Espera estricta.** Només es clica **després** d'una decisió formalitzada del col·lectiu (AG, cercle, consens formal, sigui quina sigui la modalitat). Le coord només executa. Avantatge: maximització de l'horitzontalitat, traçabilitat política forta. Inconvenient: pot ser lent, particularment quan la biblio comença o que el col·lectiu és dispers.

**Doctrina 2 — Anticipació delimitada.** Le coord pot anticipar una decisió que considera certa («és evident que Voltairine serà cooptada, fa sis mesos que ve totes les setmanes»), **a condició d'explicitar-ho a l'audit log**: raó = «anticipació sota la meva responsabilitat, a validar a la pròxima AG». La decisió pot ser impugnada a posteriori, i la retirada és sempre possible. Avantatge: flexibilitat pràctica. Inconvenient: desplaça una part de responsabilitat política sobre le coord que clica.

**Doctrina 3 — Cercle de coord.** La cooptació és presa per acord entre les coords actives de la biblio, sense passar per l'AG plenària. Argument: la coordinació és ella mateixa un col·lectiu deliberant, i té el mandat d'actuar. Avantatge: intermedi entre 1 i 2. Inconvenient: pot tornar-se opac si la coordinació no es renova ella mateixa.

**La nostra recomanació** (i res més): **trieu explícitament** una doctrina, escriviu-la al reglament de la vostra biblio, i indiqueu-la al camp «Raó» de l'audit log a cada cooptació («doctrina 2 — anticipació sota la meva responsabilitat», per exemple). L'opacitat rarament és bona en política.

## 5.5. Cas particular: la validació física d'un-a `reader`

L'**arribada** d'un-a `reader` a una biblio és una operació diferent d'una cooptació en el sentit polític. Està coberta per l'especificació `spec-validation-physique.md`.

Dos modes possibles, triats per cada biblio a la seva configuració:

**Mode `open`** — La validació és **automàtica** a la inscripció. Un cop creat el compte i confirmat el correu electrònic, le `reader` té accés immediat als catàlegs `public` i `network`. Adaptat a les biblios poc exposades políticament.

**Mode `manual_validation`** — El compte és creat en línia però roman **en espera** fins a una **trobada física** entre le `reader` i un-a `librarian+` de la biblio d'inscripció. Adaptat a les biblios exposades (context polític tens, fons sensibles, locals fràgils, etc.).

### Procediment de validació física (mode `manual_validation`)

1. La persona s'inscriu en línia i tria la vostra biblio com a biblio de referència.
2. El seu compte és creat amb `status='pending'`. Rep un correu explicant que ha de venir a presentar-se físicament a la biblio.
3. Quan ve, un-a `librarian+` la troba, verifica el que cal verificar (la doctrina del que «verificar» significa és local), i clica **«Validar»** a la seva fila a la pestanya **Equip** → secció **Comptes en espera**.
4. Un camp «Nota» opcional permet inscriure un context («trobada del 12/05 durant la permanència, presentada per Emma»).
5. El compte passa a `status='active'`. La persona rep un correu de benvinguda.

### Important polític

- La validació física d'una biblio **val per a tota la xarxa** de biblios `network` (P7 matisat: la sobirania local concerneix les delegacions internes, però el reconeixement mutu és un pacte explícit).
- El que es «verifica» durant una validació física **no** és un control d'identitat en el sentit administratiu. És una trobada. Cada biblio en defineix el sentit polític. Per a algunes, és «intercanviem una mica per verificar que la persona no és un-a policia o un-a feixista». Per a d'altres, és «presentem la biblio, el seu funcionament, les seves regles». Per a d'altres encara, és simplement «ens veiem en persona per tal que la relació sigui encarnada».
- Una biblio pot **canviar de mode** en qualsevol moment (`coordenador+`). El canvi no invalida les validacions existents.

## 5.6. El multi-membership, punt d'atenció

Una particularitat tècnica a comprendre: una persona pot tenir **diverses files** de membership a la mateixa biblio, amb rols diferents. Per exemple, Voltairine pot ser alhora `reader` i `librarian` de BLMF. Això és possible gràcies a la restricció UNIQUE sobre el triplet `(user_id, library_id, role)`.

**Per què aquesta possibilitat:** preserva l'historial. Si demà Voltairine es retrogradi de `librarian` a `reader`, la seva fila `librarian` passa a `inactive` però la fila `reader` continua — sense haver de recrear una nova inscripció des de zero.

**Conseqüència pràctica:** a la UI, es mostra la persona **una sola vegada**, amb el seu rol **de nivell més alt actiu** (administrador > coordenador > librarian > reader). A l'audit log, en canvi, es veu cada fila per separat.

## 5.7. Errors i salvaguardes

Alguns casos que es troben regularment:

**«El SIGB em diu que la persona ja és librarian.»** Probablement és cert. Verifiqueu la pestanya **Equip**: si la persona ja hi figura com a librarian, esteu intentant promocionar-la al mateix nivell; el SIGB retorna un èxit silenciós (`{ok: true, no_change: true}`) perquè no hi ha res a fer.

**«No veig la persona a la llista.»** Tres casos possibles: (a) encara no té compte AnarBib (usar el flux d'invitació per correu pendent); (b) té un compte però no està inscrita a cap biblio (ha d'inscriure's a la vostra biblio com a `reader` primer); (c) és a la xarxa però filtrada per la cerca — provar amb el seu correu electrònic exacte.

**«He clicat per error en Promocionar.»** Sense pànic. Usar **«Sol·licitar la retirada»** per obrir un període de carència de 7 dies (cf. capítol 6), o demanar a la persona que cliqui **«Cedo el relleu»** (auto-retrogressió immediata). Indicar «error de manipulació» com a raó.

**«La persona no rep el correu.»** Verificar primer l'ortografia del seu correu electrònic al seu perfil, i demanar-li que miri el correu brossa. Si el problema persisteix, parlar-ne amb un-a admin de xarxa: probablement és un problema de configuració de correu a investigar.

## 5.8. Si la regla us molesta

Diverses coses poden no convenir-vos en aquest capítol:

- **El principi de cooptació en si** (P2). Penseu que qualsevol persona `reader` compromesa hauria de poder passar lliurement a `librarian` sense necessitat de cooptació. És un debat polític de fons, que toca el principi P1. A portar al canal de coordinació de xarxa i probablement a discutir en trobada.

- **L'absència de doctrina resolta sobre el «quan clicar»** (§5.4). Penseu que la guia hauria de recomanar una sola doctrina. O al contrari trobeu que en suggereix massa. Proposar una esmena a aquest capítol, argumentant-la.

- **Els modes de validació física** (§5.5). Penseu que en caldria un tercer («validació diferida», «validació a distància», altre). A portar a `spec-validation-physique.md`.

- **El multi-membership** (§5.6). Penseu que és innecessàriament complex i que caldria un sol rol per persona per biblio. És una decisió de model de dades, més estructurant del que sembla. A portar amb les dev.

Vegeu el capítol 4 per al procediment general d'esmena, i l'annex C per al model de nota.

\newpage

# 6. Passar la iniciativa, retirar, suspendre

Aquest capítol cobreix les transicions T3 a T8 — és a dir, **tot allò que fa sortir una persona d'un equip**, o la posa en pausa. Políticament, és probablement el capítol més important de la guia, perquè els mecanismes de retirada es troben al cor del projecte anarquista (cf. capítol 1, §1.2).

## 6.1. Els principis polítics

Tres principis estructuren aquest capítol :

> **P3 — Retrogradació voluntària sempre possible.** Tota persona amb un rol staff pot retrogradar-se ella mateixa en qualsevol moment, sense consulta. «Paso la iniciativa» és un dret fonamental.

> **P4 — Exclusió regulada per un termini de carence.** L'exclusió no voluntària d'un-a-e librarian per part d'un-a-e coordenador-a-e passa per un termini de carence de set dies abans de fer efecte. Aquest termini permet la deliberació col·lectiva i l'eventual cancel·lació per part d'un-a-e altre-a-e coordenador-a-e.

> **P6 — Notificacions sistemàtiques.** Tot canvi de rol genera un correu a la persona concernida i a tota la coordinació.

La idea de fons és que mai no se surt ningú d'un equip «per sorpresa» o «en silenci». O bé la persona decideix ella mateixa (i és immediat), o bé el col·lectiu ho demana (i queda traçat, notificat, i deliberable fins a l'últim segon).

## 6.2. Passar la iniciativa : auto-retrogradació (T3 i T4)

És el **dret més fonamental** del sistema de governança d'AnarBib. Tota persona que exerceix una funció staff pot, en qualsevol moment, sense cap consulta, abandonar-la.

### Quan utilitzar-ho

- Ja no teniu temps d'assegurar la funció.
- Ja no us reconeixeu en les decisions de la coordinació.
- Esteu en desacord amb una decisió i voleu dessolidaritzar-vos-en.
- Simplement voleu fer rotar la funció.
- Necessiteu una pausa.
- No cal donar cap raó, de fet. El dret de marxar és incondicional.

### Procediment

1. Anar a `/biblioteca`, pestanya **Equip**.
2. A **la vostra pròpia línia**, fer clic a **«Passo la iniciativa»**.
3. Triar el nivell de retrogradació :
   - Si sou `coordenador`, podeu triar «tornar a librarian» (continueu a l'equip com a librarian) o «sortir de l'equip» (torneu a reader).
   - Si sou `librarian`, podeu triar «sortir de l'equip» (torneu a reader).
4. La finestra modal recorda les conseqüències. Confirmar.

### Efecte immediat

- La vostra membership actual (`librarian` o `coordenador`) passa a `inactive`.
- Si no teníeu ja la membership de destinació (`reader` o `librarian`), es crea a `active`.
- Correu a tota la coordinació + a vosaltres mateixos (confirmació).
- Registre d'auditoria : `action='self_demoted'`.

### Cas especial : sou l'únic-a-e coordenador-a-e actiu-iva-e

El SIGB **us deixa marxar**, però us avisa :

> ⚠️ ATENCIÓ : ets l'únic-a-e coordenador-a-e actiu-iva-e de [biblio]. La biblio es quedarà sense coordinació. Els-les-e administrador-a-e·s AnarBib seran notificat-des-es. Continuar ?

Si confirmeu :
- La vostra membership coord passa a `inactive`.
- La biblio entra en **mode degradat** : els-les-e `librarian` poden continuar gestionant els préstecs, validar les inscripcions, etc., però cap modificació de la identitat pública o de la configuració és possible fins a la cooptació d'un-a-e nou-va-e coord.
- Correu a tots-totes-tothom els-les-e admins de xarxa : «La biblio X ja no té coordenador-a-e. Aquí teniu els-les-e librarians actiu-ves-es : ...»

Políticament, és important : el SIGB **no impedeix** la vostra marxa. Però informa la xarxa, perquè un-a-e admin de xarxa pugui, si ho voleu i si el col·lectiu local en té necessitat, posar-se en contacte per ajudar a organitzar la transició. És la rotació de funcions en acció.

### Aspecte tècnic

RPC : `fn_team_self_demote(p_library_id uuid, p_target_role text DEFAULT 'librarian')`.

## 6.3. Demanar la retirada d'un-a-e librarian (T5)

Quan el col·lectiu decideix que una persona ha de sortir de l'equip, i que aquesta persona no es retrograda ella mateixa, s'obre una **sol·licitud de retirada amb carence de set dies**.

### Precondicions

- Sou `coordenador+` actiu-iva-e de la biblio.
- La persona objectiu té una membership `librarian` o `coordenador` `active`.
- No sou la persona objectiu (en cas contrari, utilitzeu §6.2).

### Procediment

1. Anar a `/biblioteca`, pestanya **Equip**.
2. A la línia de la persona, fer clic a **«Sol·licitar la retirada»**.
3. La finestra modal que s'obre és **vermella i insistent**. Recorda :
   - El termini de carence : «Aquesta sol·licitud tindrà efecte el [data J+7] tret d'anul·lació per part d'un-a-e altre-a-e coordenador-a-e.»
   - El caràcter reversible : «Anul·lable per qualsevol-la-le coord fins a la data d'efecte.»
   - El caràcter col·legial : «Tots-totes-tothom els-les-e coords actiu-ves-es seran notificat-des-es.»
4. Un camp **«Raó»** és obligatori — mínim 20 caràcters. Cap retirada silenciosa. La raó pot ser política («decisió AG del 04/05») o pràctica («sortida geogràfica anunciada»). Serà llegible per tot el staff a l'historial d'auditoria.
5. Confirmar.

### Efecte immediat

- La membership passa a `pending_removal`.
- Camp `pending_removal_until` = `now() + 7 days`.
- Camp `pending_removal_requested_by` = vosaltres.
- **Cap accés** per a la persona durant la carence (la membership es congela com a `suspended`).
- Correu a la persona concernida : «La coordinació ha sol·licitat la teva retirada de l'equip [biblio] (avís previ fins al [data]). Aquesta decisió forma part de la vida orgànica del col·lectiu [biblio] ; per a qualsevol discussió, adreça't a la coordinació.»
- Correu a tots-totes-tothom els-les-e coordenadores actiu-ves-es : amb el vostre nom i la raó.
- Registre d'auditoria : `action='removal_requested'` amb el vostre `actor_user_id` i el camp `reason`.

### Efecte a J+7 (cron automàtic)

Si la sol·licitud no ha estat ni anul·lada ni curtcircuitada :
- La membership passa a `inactive`.
- Correu final a la persona i a la coordinació : «Retirada efectiva.»
- Registre d'auditoria : `action='removal_completed'`.

### Aspecte tècnic

RPC : `fn_team_request_remove_member(p_user_id, p_library_id, p_role, p_reason)`. Cron : `cron_team_pending_removal_complete` (s'executa diàriament).

## 6.4. Cancel·lar una sol·licitud de retirada (T8)

Le **salvaguarda col·legial** del sistema. Qualsevol-la-le coord — no necessàriament qui-qui ho ha demanat — pot cancel·lar una sol·licitud de retirada durant el període de carence.

### Quan utilitzar-ho

- La discussió col·lectiva ha acabat amb una altra decisió (mediació, suspensió temporal en lloc d'això, etc.).
- La sol·licitud inicial s'ha fet en calent i la coordinació vol reprendre la iniciativa col·legialment.
- La persona objectiu finalment ha estat contactada i la situació s'ha desactivat.

### Procediment

1. Anar a `/biblioteca`, pestanya **Equip**, secció **Suspensions i avisos en curs**.
2. A la línia de la persona en `pending_removal`, fer clic a **«Cancel·lar la sol·licitud»**.
3. Finestra modal simple de confirmació. Camp «Raó» opcional.
4. Confirmar.

### Efecte immediat

- La membership torna a `active`.
- Camp `pending_removal_until` restablert a NULL.
- Correu a la persona : «La sol·licitud de retirada ha estat cancel·lada. Recuperes les teves prerrogatives.»
- Correu a tota la coordinació.
- Registre d'auditoria : `action='removal_cancelled'` amb el vostre `actor_user_id`.

### Políticament

La cancel·lació és voluntàriament molt senzilla d'activar. És un mecanisme de **reequilibri col·legial** : si un-a-e coord ha demanat una retirada en calent, qualsevol-la-le altre-a-e coord pot suspendre l'execució mentre el col·lectiu delibera. Això fa que les sol·licituds de retirada siguin menys pesants (cap drama irreversible) però també menys lleuges (qualsevol us pot contradir). Aquest és l'interès de la carence.

### Aspecte tècnic

RPC : `fn_team_cancel_remove_member(p_user_id, p_library_id, p_role)`.

## 6.5. Suspensió immediata : la mesura cautelar (T6 i T7)

La suspensió és una eina **diferent** de la sol·licitud de retirada. És **immediata**, sense carence, i **sense durada màxima**. No és una exclusió, és una **posada en pausa**.

### Quan utilitzar-ho

Casos tipus previstos per l'especificació :

- **Compte compromès** : hi ha raons per pensar que la contrasenya de la persona ha estat filtrada. Se suspèn a l'espera que canviï la contrasenya.
- **Assetjament reportat urgent** : un-a-e lector-a-e reporta un comportament abusiu d'un-a-e membre staff. Se suspèn a l'espera de la investigació col·lectiva.
- **Comportament manifestament abusiu** observat en directe : se suspèn mentre la coordinació es reuneix.
- **Conflicte en curs de mediació** : la persona es posa en pausa voluntàriament mentre la mediació arriba a terme.

### Procediment

1. Anar a `/biblioteca`, pestanya **Equip**.
2. A la línia de la persona, fer clic a **«Suspendre»**.
3. Finestra modal amb un camp **«Raó de la suspensió» obligatori** (mínim 20 caràcters). Aquesta raó serà llegible a l'historial d'auditoria per tot el staff actiu.
4. Confirmar.

### Efecte immediat

- La membership passa a `suspended`.
- **Cap accés** per a la persona. El rol nominal es conserva (continua apareixent com a «librarian suspès-sa-e») però ja no pot fer res.
- Correu a la persona concernida : urgent, amb la raó, i — en el cas d'un compte compromès — una invitació a canviar la contrasenya.
- Correu a tota la coordinació.
- Registre d'auditoria : `action='suspended'` amb el vostre `actor_user_id` i el camp `reason`.

### Aixecament de la suspensió

Quan la situació es resol (compte rebloquejat, mediació acabada, investigació conclosa, etc.) :

1. Pestanya **Equip** → secció **Suspensions i avisos en curs**.
2. A la línia suspesa, fer clic a **«Aixecar la suspensió»**.
3. Finestra modal simple. Camp raó opcional però recomanat per tancar políticament l'episodi.
4. Confirmar.

Efecte : tornada a `active`, correus, registre d'auditoria `action='unsuspended'`.

### Important : suspensió vs. retirada

La distinció és crucial :

| | Suspensió (T6) | Retirada (T5) |
|---|---|---|
| Efecte | Immediat | Diferit (J+7) |
| Durada | Indefinida | 7 dies i després `inactive` |
| Reversible per | Aixecament explícit | Cancel·lació durant la carence |
| Ús típic | Mesura cautelar | Decisió d'exclusió |
| Política subjacent | «Ens deixem temps per entendre» | «Hem decidit que aquesta persona surt» |

El SIGB **refusa** fer passar una membership de `suspended` directament a `pending_removal` (la transició no és autoritzada per la matriu). Per què : són dues temporalitats polítiques distintes. Per passar d'una a l'altra, cal explícitament **aixecar la suspensió** primer (tornada a `active`), i llavors demanar la retirada (`pending_removal`). Aquest doble pas és voluntari : força el col·lectiu a constatar explícitament la transició.

### Aspecte tècnic

RPC suspendre : `fn_team_suspend_member(p_user_id, p_library_id, p_role, p_reason)`. RPC aixecar : `fn_team_unsuspend_member(p_user_id, p_library_id, p_role)`.

## 6.6. Retrogradar un-a-e altre-a-e `coordenador` (T3 col·lectiu)

Un cas una mica particular : què fer quan la coordinació vol **retrogradar un-a-e coordenador-a-e** que no es retrograda espontàniament ?

L'especificació de governança tracta aquest cas com una **sol·licitud de retirada amb carence** dirigida a la membership `coordenador`. Concretament, s'utilitza el mateix procediment que al §6.3 («Sol·licitar la retirada»), però seleccionant el rol `coordenador`. La persona passa a `pending_removal` a la seva membership `coordenador` ; a J+7, aquesta membership passa a `inactive`. Si tenia una membership `librarian` paral·lela, aquesta continua activa (i la persona «cau de nou» a librarian). En cas contrari, torna a ser simple `reader`.

És voluntàriament el mateix mecanisme que per als-les-e `librarian`, amb les mateixes salvaguardes. **Cap altre-a-e coord no té un poder especial** sobre les seves col·legues : el procediment passa per la carence i la col·legialitat.

## 6.7. Compte abandonat : sortida automàtica (T9)

El SIGB inclou un mecanisme de **sortida automàtica** per als comptes que no han tingut cap connexió des de fa molt de temps.

### El llindar

El SIGB mira el camp `last_sign_in_at` pel costat Supabase. Si una membership staff té un usuari l'última connexió del qual és de fa més de **9 mesos**, el compte és progressivament tret :

- **J-30 dies** (8 mesos després de l'última connexió) : correu d'avís a la persona («la teva membership serà desactivada en 30 dies sense connexió»).
- **J-7 dies** : correu de recordatori.
- **J = 9 mesos** : pas automàtic a `inactive`. Correu final a la persona + a tota la coordinació.

### Per què aquesta regla

És un compromís entre dues exigències :

- No deixar **arrossegar indefinidament** memberships fantasma que inflen artificialment els equips.
- No **expulsar** brutalment una persona que hauria pres simplement una pausa i compta tornar.

Una simple connexió és suficient per reinicialitzar el comptador. No cal realitzar cap acció, simplement connectar-se.

### Cas especial : l'únic-a-e coord abandona

Si la persona retirada automàticament és l'**únic-a-e coordenador-a-e actiu-iva-e** de la biblio, el cron escala a un-a-e admin de xarxa **abans** d'executar la sortida. Le-la-e admin de xarxa és notificat-da-e per correu, pot posar-se en contacte amb la coordinació (si en queda algun fragment) o amb els-les-e `librarian` de la biblio, i coordinar la transició.

Políticament, és coherent amb el que fem quan l'únic-a-e coord es retrograda explícitament (§6.2) : no es bloqueja la sortida, però s'alerta la xarxa perquè pugui ajudar si cal.

## 6.8. Alguns casos límit a conèixer

**Una persona en `pending_removal` que demana marxar de seguida.** Pot fer-ho. Li n'hi ha prou d'utilitzar ella mateixa «Passo la iniciativa» (auto-retro T4). Efecte : pas immediat a `inactive`, curtcircuit de la carence. Políticament, és coherent : el dret P3 (auto-retrogradació) és incondicional.

**Una persona en `suspended` que es vol excloure definitivament.** Veure §6.5 «Important : suspensió vs. retirada». Cal aixecar la suspensió primer, i llavors demanar la retirada.

**Algú demana la seva pròpia retirada via «Sol·licitar la retirada».** El SIGB refusa amb un missatge explícit : «Per sortir de l'equip, utilitzeu l'opció "Passo la iniciativa" (auto-retrogradació).» És voluntari : confondre una decisió personal amb una decisió col·lectiva embolicaria la semàntica política.

**Intent de retrogradar un-a-e admin de xarxa.** Refusat sistemàticament. El rol d'admin de xarxa només pot ser modificat per mitjà dels mecanismes específics de l'especificació admin-reseau (cf. capítol 8). Cap coordinador-a-e local no pot destituir un-a-e admin de xarxa.

## 6.9. Si la regla us molesta

**El termini de carence de 7 dies us sembla massa llarg o massa curt.** A portar a `spec-gouvernance-roles.md`, §4.4 i §5.6.

**Trobeu que la suspensió sense durada màxima és una porta oberta a l'arbitrarietat.** És un tema polític seriós. Es pot considerar afegir un termini més enllà del qual una suspensió ha de convertir-se en retirada o ser aixecada. A discutir en coordinació de xarxa, i llavors portar a l'especificació.

**Trobeu que l'obligació de raó sobre la suspensió és un excés de burocràcia.** O al contrari trobeu que el mínim de 20 caràcters és massa curt. A portar a l'especificació.

**Trobeu que la sortida automàtica a 9 mesos és massa ràpida o massa lenta.** El llindar és parametritzable, però avui és el mateix per a totes les biblios de la xarxa. Cal fer-lo configurable per biblio ? A discutir.

Veure capítol 4 i annex C per al procediment d'esmena.

\newpage

# 7. Quan alguna cosa va malament

Aquest capítol tracta de les **situacions excepcionals**, allà on els mecanismes ordinaris de governança no són suficients, o bé funcionen però demanen discerniment polític. És també el capítol on es parla francament de les **biblios que no tenen (o ja no tenen) vida col·lectiva deliberant**, perquè el silenci sobre aquest tema faria més mal que la franquesa.

## 7.1. Biblio sense AG o amb pocs membres

El cas és més freqüent del que sembla. Una biblio en fase d'inici, amb dues o tres persones. Una biblio que ha vist el seu col·lectiu reduir-se amb el pas de les marxes. Una biblio de la qual l'AG ja no es reuneix des de fa un temps, per manca de gent o per desànim.

El SIGB no s'immisceix en la vida política d'un col·lectiu. Però aquesta guia ha de dir clarament el que canvia quan aquesta vida col·lectiva és feble.

### El que canvia concretament

**La paraula « cooptació » es torna ambigua.** Amb dues persones, qui copta qui? Si l'únic·a coordinador-a-e vol fer entrar Voltairine a l'equip, decideix « sol·a » en sentit polític. El SIGB ho autoritzarà (un·a coordinador-a-e+ pot cooptar), però ja no és la cooperació d'un col·lectiu polític, és una decisió personal disfressada. No és ni bo ni dolent, simplement cal reconèixer-ho.

**Les deliberacions són teòriques.** Una sol·licitud de retirada a 7 dies, en una biblio de 2 persones, no té ningú més per contradir-la que qui l'ha demanat. El « salvaguarda col·legial » es converteix en una autoreflexió.

**El risc de personalització augmenta.** Quan una decisió ja no és col·lectiva, depèn del caràcter, la disponibilitat i la lucidesa d'una o dues persones. No és catastròfic en si mateix, però és més fràgil.

### Les nostres recomanacions explícites

**1. Reconeixeu la situació.** No feu veure que sou un gran col·lectiu deliberant si sou dues persones. Políticament, és més sa escriure « decisió presa per mi sol·a, a validar quan el col·lectiu creixi » al camp « Raó » del registre d'auditoria, que no pas escriure « decisió AG » per a una AG que no existeix.

**2. Busqueu diàleg a l'exterior.** Si esteu sol·a o de dues persones, i cal prendre una decisió important (cooptació, retirada, suspensió), preneu l'hàbit de parlar-ne amb camarades d'altres biblios de la xarxa, o amb un·a administrador-a-e de xarxa. No per demanar-los una autorització — no han de validar les decisions internes de la vostra biblio — sinó per tenir un retorn crític extern. La xarxa Matrix d'AnarBib és feta per a això.

**3. Prioritzeu les transicions reversibles.** Quan el vostre col·lectiu és petit, eviteu si és possible les decisions irreversibles. Una suspensió és més reversible que una retirada. Una retirada passa per 7 dies durant els quals podeu canviar d'opinió. Una cooptació és anul·lable. Doneu-vos temps.

**4. Documenteu el que passa.** El camp « Raó » del registre d'auditoria és el vostre millor aliat. Com més context hi poseu (« cooptació de Voltairine, decidida sol·a, a validar a la propera permanència »), més la decisió serà contextualitzable més tard, per vosaltres mateixos·es com per un·a nou·nova membre del col·lectiu.

**5. Si esteu realment aïllat·ada, demaneu ajuda.** Una biblio d'una persona és en perill políticament. El SIGB ho detecta quan l'últim·a coordinador-a-e es retrograda (§6.2) o abandona (§6.7), i alerta els·les administrador-a-e de xarxa. També podeu prendre la iniciativa: envieu un correu a la coordinació de xarxa per explicar la situació. Diverses biblios de la xarxa han travessat períodes de buit i han estat ajudades a reconstituir-se.

### El que la guia no fa

No proporciona **cap** procediment especial per a les biblios petites. És voluntari. Les regles del SIGB s'apliquen uniformement — el que canvia són les condicions polítiques en què s'apliquen. Reconèixer aquest matís forma part de la maduresa política d'un·a coordinador-a-e.

## 7.2. Conflicte interpersonal en una coordinació

Esclatà un conflicte entre dos membres de l'staff. La feina ja no es fa correctament, l'ambient empitjora, els·les lector-a-e perceben la tensió.

### El que el SIGB pot fer

Gairebé res, directament. El SIGB no arbitre els conflictes. Però proporciona **eines utilitzables**:

- **Suspensió provisional (T6)** d'una o de les dues persones, mentre el conflicte és mediat. Això és el que l'especificació anomena explícitament « conflicte en curs de mediació » com a cas d'ús legítim de la suspensió.
- **Autoretrogradació (T3/T4)** — si una de les dues persones tria fer un pas enrere, és immediata.
- **Registre d'auditoria llegible per tot l'staff** — permet a tot l'staff veure qui ha fet què, i evitar les manipulacions opaques d'un·a coordinador-a-e que intentés resoldre el conflicte traient l'altre en silenci.

### El que el col·lectiu ha de fer

- **Mediació**. El SIGB no fa mediació. Cal una persona tercera de confiança, fora del conflicte. Segons les configuracions: un·a altre·a coordinador-a-e de la biblio, un·a camarada d'una altra biblio, un·a administrador-a-e de xarxa.
- **Decisió col·lectiva**. Si la mediació arriba a una decisió (una de les dues persones deixa la coordinació, o bé es defineix un marc de treball revisat), el SIGB executarà aquesta decisió via els RPCs normals.
- **Traça política**. Si la decisió és retirar algú, el camp « Raó » hauria de mencionar el procés de mediació (« retirada com a resultat de la mediació del DD/MM, decisió col·lectiva ») per no reescriure la història més endavant.

### El que cal evitar

- **Utilitzar una suspensió com a arma** en el conflicte. La suspensió és feta per posar en pausa, no per guanyar una relació de forces. Si un·a coordinador-a-e suspèn l'altre sense procés de mediació, és observable al registre d'auditoria, i és políticament problemàtic.
- **Curtcircuitar la carència** per maniobres tècniques (suspendre i llavors « accelerar » per altres mitjans). Tot queda registrat, i la xarxa se n'adonarà.
- **Fer silenci sobre el registre d'auditoria**. Tot l'staff veu el que passa (P5). Si intenteu amagar el conflicte, traïu la transparència del col·lectiu.

## 7.3. Assetjament reportat

Un·a lector-a-e reporta que un·a membre de l'staff té un comportament abusiu (assetjament sexual, abús de poder, comportament racista, etc.).

### Procediment recomanat

**1. Prendre el reportament seriosament**, immediatament, fins i tot si la persona que reporta és aïllada i fins i tot si la persona reportada és « coneguda i apreciada » per la coordinació. El reflex de descartar el reportament com a « probablement exagerat » és l'error més freqüent.

**2. Suspensió immediata (T6)** de la persona reportada, **a títol cautelar**, en espera de la investigació. El camp « Raó » hauria de dir alguna cosa com « Suspensió cautelar arran de reportament rebut el DD/MM, en espera d'investigació col·lectiva ». La suspensió **no** és una acusació, és una posada en pausa.

**3. Constituir un grup d'investigació**. Fora del programari. Com a mínim: camarades fora de la situació de poder directa, capaços d'escoltar les dues parts sense biaix. Aquest grup pot incloure camarades d'altres biblios si la biblio és petita o si tots·totes els·les coordinador-a-e estan implicat·ades en l'afer.

**4. Comunicar amb la persona que reporta**. Cal que sàpiga que s'ha pres seriosament, i que hi ha mesures en curs. No deixar-la en la incertesa.

**5. Arribar a una decisió**. Segons el que revela la investigació:
   - Aixecament de la suspensió (T7) si el reportament no es confirma.
   - Retirada definitiva (T5 amb carència) si el reportament es confirma i la decisió és treure la persona.
   - Sanció intermèdia (marc de treball revisat, formació, allunyament de certes funcions) si la situació és més matisada.

**6. Traçar políticament**. El camp « Raó » al registre d'auditoria hauria de reflectir la decisió col·lectiva. Sense detalls sobre la víctima (RGPD), però una formulació que faci la decisió llegible.

### El que no cal fer

- **Demanar una retirada directament** sense suspensió prèvia, quan la situació és urgent. Durant 7 dies la persona reportada conservaria els seus drets, la qual cosa és contradictòria amb la urgència d'un reportament d'abús.
- **Suspendre indefinidament sense decisió** al·legant que « no aconseguim decidir ». Una suspensió que dura diversos mesos sense decisió es converteix ella mateixa en una violència (envers la persona suspesa, que no pot defensar-se, i envers la persona que ha reportat, que no rep resposta).
- **Resoldre internament sense la xarxa**. Si sou una biblio petita i la situació us supera, demaneu ajuda als·les administrador-a-e de xarxa. No esteu sol·es.

## 7.4. Compte compromès

Una persona de l'staff veu el seu compte compromès (contrasenya filtrada, sospita d'accés no autoritzat).

### Procediment immediat

**1. Suspensió immediata (T6)** del compte, amb raó explícita: « Sospita de compromissió, contrasenya probablement filtrada, verificació en curs ».

**2. Comunicació amb la persona afectada**. La persona rep automàticament un correu urgent indicant la suspensió i invitant-la a canviar la seva contrasenya. Le·la coordinador-a-e que suspèn hauria de posar-se en contacte directament (telèfon, altre canal segur) per confirmar.

**3. Investigació ràpida.** Què ha passat? El compte ha fet accions inusuals al registre d'auditoria (cooptacions estranyes, modificacions de configuració, etc.)? Si és així, avisar immediatament un·a administrador-a-e de xarxa per ajudar a analitzar.

**4. Aixecament de la suspensió (T7)** un cop:
   - La contrasenya ha estat canviada.
   - El possible dany ha estat constatat i reparat (cancel·lació de les accions abusives, restauració de les dades, etc.).
   - La persona és segura digitalment.

### Políticament

Una suspensió per compte compromès **no és un retret**. És una protecció mútua: es protegeix la persona (impedint que sigui utilitzada per un·a atacant-a-e) i la biblio (impedint que es facin danys en el seu nom). El correu a la persona hauria d'insistir en aquest caràcter **no disciplinari**.

## 7.5. Biblio sense coordinador-a-e ni `librarian` actiu·ves

L'escenari catàstrofe: cap membre de l'staff actiu·va. Pot passar per sortida automàtica acumulada (tots els membres de l'staff han abandonat el seu compte simultàniament), per dimissió col·lectiva (rar però possible), o per successió de retirades.

### Conseqüències

- La biblio resta **tècnicament activa** (la seva visibilitat, el seu catàleg resten accessibles segons les RLS habituals).
- Però **cap acció de gestió** ja no es pot fer via la UI normal: cap validació d'inscripció, cap gestió de préstec, cap modificació de la configuració.
- **Correu urgent als·les administrador-a-e de xarxa** pel cron que detecta la situació.

### Procediment de reinici

Fora d'especificació, però és el que es practica:

**1. Presa de contacte** per un·a administrador-a-e de xarxa amb el col·lectiu local, per tots els canals disponibles (el o els comptes de lector-a-e que resten inscrits·es, les dades de contacte externes de la biblio si existeixen, la xarxa de coneixences local).

**2. Verificació política**: el col·lectiu encara existeix? Vol continuar existint? Si hi ha membres però que simplement han deixat les funcions tècniques, es pot recooptar nou staff per cooptació fora de workflow.

**3. Cooptació fora de workflow** per l'administrador-a-e de xarxa, via SQL directe o via la UI (un·a administrador-a-e de xarxa té dret d'actuar com a `coordinador`+ en qualsevol biblio, cf. capítol 2). La cooptació fora de workflow ha de quedar registrada al registre d'auditoria amb una raó explícita: « Represa de coordinació després de vacant, arran de contacte del col·lectiu del DD/MM, per administrador-a-e de xarxa X ». I — punt clau de doctrina — **informació prèvia a la coordinació local obligatòria**, excepte si la biblio ja no té cap membre de l'staff viu·va, en aquest cas la informació passa pels `reader` actiu·ves restants (cf. §7.6).

**4. Si el col·lectiu ja no existeix**: obertura d'una discussió sobre el **tancament net** de la biblio. Quines dades conservar, quines suprimir, com comunicar als·les lector-a-e, etc. És un workflow a formalitzar per separat.

## 7.6. La intervenció d'un·a administrador-a-e de xarxa en una biblio local

Un cas que ja es tracta al capítol 2, però que mereix un desenvolupament pràctic en aquest capítol de situacions excepcionals.

### La doctrina de la xarxa

> **Una intervenció d'administrador-a-e de xarxa en una biblio local ha d'anar precedida d'una informació a la coordinació local afectada, excepte urgència vital.**

La informació prèvia **no és una petició d'autorització**. L'administrador-a-e de xarxa té el dret d'actuar (aquest és el sentit del dret transversal). Però és una mostra de respecte envers l'autonomia local, i preserva la possibilitat d'un altre arranjament.

### El que és una « urgència vital »

És voluntàriament restrictiu. Casos-tipus:

- **Compromissió activa**: una acció en curs amenaça la integritat de la biblio o de la xarxa (compte atacant que modifica memberships en temps real, etc.).
- **Assetjament en curs**: un·a membre de l'staff abusa activament de les seves funcions, el perill per als·les lector-a-e és immediat.
- **Atac contra la plataforma**: intent d'intrusió, exfiltració de dades, etc.

Fora d'aquests casos, **es pren el temps d'informar**.

### Com informar

Abans de la intervenció (o durant, si la urgència ho justifica a posteriori):

- **Correu a la coordinació local** explicant el que es farà, per què, i amb quina traçabilitat.
- **Menció a la taula `cross_library_actions_log`** amb un nivell de criticitat indicant la naturalesa de l'acció. Tots·totes els·les coordinador-a-e actiu·ves de la biblio reben una notificació.
- **Disponibilitat al diàleg**: la coordinació local ha de poder fer preguntes, demanar precisions, fins i tot negociar un altre arranjament (« deixa'ns provar primer »).

### El que cal evitar

- **La intervenció silenciosa**: actuar sobre la biblio sense informar-ne la coordinació. Fins i tot si tècnicament queda registrat, políticament és una violació de la sobirania local.
- **L'ús del dret transversal com a poder de vigilància**: anar a veure « el que passa » en una biblio sense raó operacional. El dret transversal existeix per a casos de manteniment o de mediació, no per curiositat.
- **La imposició de decisions polítiques**: un·a administrador-a-e de xarxa no pot dir a una biblio com fer les seves cooptacions, com gestionar els seus conflictes interns, o quina política d'acollida triar. El dret transversal és tècnic, no polític.

## 7.7. Si la regla us molesta

**Trobeu que la doctrina d'informació prèvia és massa laxa** (un·a administrador-a-e de xarxa podria abusar de la « urgència vital »). A debatre: cal una definició més estricta de la urgència? Cal un·a segon·a administrador-a-e de xarxa que confirmi la urgència?

**Trobeu la doctrina massa estricta** (de vegades cal actuar ràpid sense explicar-ho tot). A debatre: cal distingir diversos nivells d'intervenció, amb regles d'informació diferents segons la criticitat?

**Trobeu que el silenci sobre el tancament net d'una biblio és problemàtic** (§7.5). Teniu raó. Probablement cal escriure una especificació dedicada. A portar a la xarxa.

**Trobeu que aquest capítol deixa massa lloc a la improvisació** en els casos d'assetjament (§7.3). Probablement és cert. Una especificació dedicada als processos de mediació i d'investigació podria ser beneficiosa. A portar a la xarxa.

Vegeu el capítol 4 i l'annex C.

\newpage

# 8. El rol d'administrador-a-e de xarxa

Aquest capítol s'adreça específicament a les persones administradores-àries-e de xarxa (presents o futures), i a les coordinacions locals que volen entendre com la xarxa s'auto-organitza al nivell superior. Complementa i aprofundeix els capítols 2 i 7.

## 8.1. Una funció política diferenciada

Abans de tot: ser **admin de xarxa** no és ni un grau, ni una consagració, ni un títol. És una **funció transversal** que el col·lectiu de les persones admins de xarxa delega a determinades persones membres, sobre la base d'un acord unànime de les persones admins ja en funcions, i que es pot abandonar en qualsevol moment.

El projecte polític de la funció és **fer viure la coordinació inter-biblioteques**: acollir les noves biblioteques que s'incorporen a la xarxa, animar els debats sobre les evolucions tècniques i polítiques del SIGB, mantenir la plataforma tècnicament, intervenir quan una biblioteca es troba en un bloqueig. No és una funció de direcció. És una funció d'animació i de servei.

### Què pot fer un-a-e admin de xarxa (políticament)

- Activar una nova biblioteca que ha fet la seva sol·licitud d'inscripció a la xarxa.
- Animar els debats inter-biblioteques (el canal Matrix `#anarbib`, les trobades, les llistes de correu internes).
- Coordinar les evolucions de la plataforma (specs, releases, comunicacions).
- Intervenir en qualsevol biblioteca en cas de bloqueig tècnic (dret transversal).
- Mediar entre dues biblioteques en cas de conflicte (si les coordinacions ho desitgen).
- Proposar o votar sobre la cooptació i el retrait col·lectiu d'altres persones admins de xarxa.

### Què no pot fer un-a-e admin de xarxa (políticament)

- Dirigir una biblioteca.
- Imposar una decisió política a una biblioteca (política d'acollida, mode de validació, cooptacions internes, etc.).
- Expulsar un-a-e coordinador-a-e local contra el parer de la seva biblioteca.
- Modificar sol-a-e les regles de la xarxa (això passa per una discussió col·lectiva de les persones admins i idealment de les coordinacions).

## 8.2. La cooptació per unanimitat: per què

La persona admin de xarxa no s'hi afegeix per majoria, sinó per **unanimitat** de les persones admins en funcions. Aquesta regla pot sorprendre — per què no una majoria simple, una majoria qualificada, o un quòrum?

La raó política és senzilla: el poder d'un-a-e admin de xarxa és **transversal**. Pot intervenir en qualsevol biblioteca. Cal, doncs, que **cada persona admin de xarxa actualment activa** estigui disposada a treballar amb la nova persona. Si hi ha un sol desacord profund, la cooperació quedarà enverinada — val més no imposar-la.

Aquesta regla té una conseqüència pràctica important: **el veto és fàcil**. Un sol vot `opposed` n'hi ha prou. Això és deliberat. Es prefereix que una cooptació no prosperi, abans que deixi un-a-e admin existent en una posició incòmoda de manera duradora.

## 8.3. Flux de treball de la cooptació, en detall

### Etapa 1 — Proposta

Un-a-e admin de xarxa actiu-va-e, des de la interfície `/rede/administradores` (a venir al paquet D), clica **«Proposar una cooptació»**.

- Introdueix la identitat de la persona proposada (cerca a la base de persones usuàries d'AnarBib).
- Introdueix una **motivació** obligatòria de **mínim 20 caràcters**. Aquesta motivació és llegible per totes les persones admins, i — en cas d'èxit — s'inclourà a la notificació a la persona cooptada.
- Confirma.

El SIGB:
- Crea una línia a `network_administrator_cooptation_proposals` amb `status='open'`, `expires_at = now() + 30 dies`.
- Registra automàticament el vot `favorable` de la persona proposant.
- Envia un correu militant a totes les altres persones admins actives invitant-les a votar.

### Etapa 2 — Vots

Cada altra persona admin activa té 30 dies per votar. Tres opcions:

- **`favorable`**: accepta la cooptació.
- **`opposed`**: posa el seu veto. **Raonament obligatori** de mínim 20 caràcters. Aquest raonament serà comunicat a la persona proposada i a la persona proposant en cas de rebuig.
- **`abstain`**: s'abstén. **L'abstenció bloqueja**: la proposta prospera únicament amb la unanimitat dels vots `favorable`. Una abstenció no retirada té el mateix efecte pràctic que un veto, llevat que es pot convertir en favorable més endavant si la persona canvia d'opinió.

### Detall v0.3 — Divulgació d'identitat

Una opció **«Revelar la meva identitat en cas de rebuig»** és marcada per defecte. Si voteu `opposed`, la vostra identitat serà comunicada a la persona proposada i a la persona proposant, a més del vostre raonament.

Podeu **desmarcar** aquesta opció per romandre anònim-a-e. En aquest cas, el raonament es transmetrà sense el vostre nom («un-a-e oponent ha plantejat: …»).

Políticament, la **transparència per defecte** correspon a la cultura militant d'assumir les pròpies posicions. Però l'anonimat continua sent possible per als casos en què una oposició exposaria la persona oponent a un cost personal desproporcionat.

### Recordatoris automàtics

El cron envia recordatoris a les persones admins que encara no han votat:
- **D+14 dies**: «Encara no has votat sobre la cooptació de X.»
- **D+25 dies**: «Aquesta proposta expira d'aquí a 5 dies, pren posició.»

### Etapa 3 — Conclusió

**Si algú vota `opposed`**: la proposta passa immediatament a `status='rejected'`. La persona proposada i la persona proposant reben un correu explicant el rebuig, amb el raonament (i la identitat de la persona oponent si ha acceptat la divulgació).

**Si totes les persones admins actives han votat `favorable`**: la proposta passa a `status='completed'`. S'insereix automàticament una línia a `network_administrators` amb `status='active'` i `coopted_by_unanimity_of = ARRAY[<llista de votants>]`. La persona rep un correu de benvinguda i s'envia un resum a totes les persones admins.

**Si 30 dies transcorren sense arribar a un consens**: la proposta passa a `status='expired'`. Sense cooptació. Cal o bé reiniciar una nova proposta, o bé considerar que la xarxa no està preparada per acollir aquesta persona de moment.

## 8.4. El retrait col·lectiu per unanimitat

El **retrait col·lectiu** és el mirall de la cooptació: per retirar un-a-e admin de xarxa contra la seva voluntat, cal la unanimitat de les altres persones admins actives.

### Flux de treball

1. **Proposta de retrait** per un-a-e admin de xarxa actiu-va-e, motivació obligatòria ≥ 20 caràcters.
2. **Vots** de les altres persones admins (favorable / opposed / abstain), amb raonaments si `opposed`.
3. **Si unanimitat `favorable`**: la membre de la persona visada passa a `pending_removal`, amb `pending_collective_removal_until = now() + 7 dies`.
4. **Durant els 7 dies de carència**: la persona visada conserva els seus drets operacionals, però rep un correu clar sobre la seva sortida programada. Pot eventualment iniciar una última discussió. **No pot cancel·lar el retrait unilateralment**: únicament la unanimitat de les altres persones admins pot fer marxa enrere (proposant una «cancel·lació de retrait», flux de treball mirall).
5. **A D+7**: pas a `status='removed'`, `removed_at=now()`.

### Políticament

El **doble bloqueig** (unanimitat + carència 7 dies) fa que el retrait col·lectiu d'un-a-e admin de xarxa sigui particularment difícil. Això és deliberat. Atès que el poder d'un-a-e admin de xarxa és transversal, no es revoca a la lleugera.

Inversament, **l'auto-retrait continua sent sempre possible i fàcil** (cf. §8.5). Aquí rau la dissimetria política: és senzill partir, és difícil ser expulsat-ada-e. Això correspon a la cultura anarquista: es respecta la decisió personal d'abandonar una funció, s'emmarca fortament la decisió col·lectiva de retirar-la.

## 8.5. Auto-retrait

Un-a-e admin de xarxa pot abandonar les seves funcions en qualsevol moment, sense l'acord de les altres. És un acte **unilateral i incondicional** (P3 aplicat al nivell de xarxa).

### Procediment

Des de `/rede/administradores`, sobre la seva pròpia línia, clicar **«Abandonar les meves funcions d'admin de xarxa»**. Modal de confirmació, raó opcional.

### Efecte

- La línia passa a `status='inactive'` (o `removed` segons el context, a aclarir al paquet D).
- Correu a totes les altres persones admins actives.
- Audit log `event_type='self_removal_requested'`.

### Cas especial: l'única persona admin activa

Si sou la única persona admin activa i voleu partir, el SIGB desencadena una **carència especial de 30 dies**. Durant aquest període:
- Continueu com a persona admin activa amb tots els vostres drets.
- S'envia un correu urgent a totes les antigues persones admins (`status='inactive'` o `removed`) indicant-los la situació.
- La xarxa té 30 dies per o bé recooptar un-a-e nou-va-e admin (flux de treball normal de cooptació, sent vosaltres la única persona votant), o bé organitzar una transició diferent.

A D+30, si no s'ha fet res, sortiu efectivament i la xarxa es troba **sense persona admin activa**. El SIGB continua funcionant tècnicament, però cap acció d'admin (activació de biblioteca, cooptació, etc.) és ja possible fins a una intervenció manual.

Aquest procediment està dissenyat per **alentir** la dissolució de la xarxa en el cas que l'última persona admin partís, sense per això **impedir** aquesta sortida. La llibertat de partir continua sent plena.

## 8.6. El dret transversal al dia a dia

El **dret transversal** és el que distingeix políticament la persona admin de xarxa del staff local: pot actuar com a `coord+` en qualsevol biblioteca, llegir el seu catàleg (fins i tot si la visibilitat és `private`), modificar les seves memberships, etc.

### Quan utilitzar-lo

- **Activació d'una nova biblioteca**: flux de treball normal, és el cas d'ús primer del dret transversal.
- **Manteniment**: una biblioteca té una configuració trencada, un paràmetre mal configurat, un error bloquejant. Podeu intervenir per corregir.
- **Bloqueig polític**: la biblioteca no té cap coordinador-a-e (cf. §7.5), cal recooptar per reiniciar.
- **Mediació a petició**: la coordinació local us demana explícitament ajuda per arbitrar un conflicte o prendre una decisió difícil.
- **Investigació arran d'un senyalament de xarxa**: un-a-e lector-a-e senyala un problema major en una biblioteca, i la coordinació local no respon o forma ella mateixa part del problema.

### Quan no utilitzar-lo

- **Per curiositat**: no anar «a veure què passa» en una biblioteca sense raó operacional. Això és vigilància, no administració.
- **Per imposar una decisió política**: si no esteu d'acord amb la política d'una biblioteca (mode de validació, reglament, etc.), podeu discutir-ho, però no imposar-ho.
- **Per curtcircuitar un debat col·lectiu**: si la xarxa debat una evolució i no esteu d'acord, no podeu utilitzar el vostre dret transversal per imposar el vostre punt de vista per fets consumats.

### Informació prèvia obligatòria

Aquesta és la doctrina de la xarxa (capítol 2, §2.4; capítol 7, §7.6): **tota intervenció d'admin de xarxa en una biblioteca local ha d'anar precedida d'una informació a la coordinació local**, llevat en cas d'urgència vital.

Concretament:
- **Correu a la coordinació local** explicant el que es farà i per què.
- **Espera d'una resposta** llevat urgència: 24 a 72 hores segons la naturalesa de l'acció.
- **Si no hi ha resposta i l'acció no és urgent**: relançar un cop, i procedir explicitant al log que la coordinació local ha estat informada però no ha respost.
- **Si urgència vital**: actuar, i enviar la informació immediatament després explicant per què l'urgència ha justificat l'acció sense espera.

Cada acció queda traçada a `cross_library_actions_log` amb nivell de criticitat, llegible per la coordinació local a posteriori.

## 8.7. El cas de la primera persona admin i de Xavier

El sistema suposa almenys un-a-e admin de xarxa actiu-va-e perquè la cooptació sigui possible. La **primera persona admin** no pot ser cooptada (no hi ha ningú per votar), de manera que s'ha previst una excepció.

L'11 de maig de 2026, **Xavier** és inscrit-a-e com a **admin de xarxa fundador-a-e** per INSERT directe a `network_administrators`, amb `coopted_by_unanimity_of = ARRAY[]::uuid[]` (taula buida) i `notes = 'Fondateur du réseau AnarBib, cooptation hors workflow'`. Aquesta manipulació queda traçada a l'audit log amb `event_type='foundational_admin_added'` i `metadata.foundational=true`.

Aquesta manipulació és **transparent políticament**: està documentada, explicada i és pública. No és una debilitat del sistema — és l'engegada indispensable. Un cop establerta aquesta base, tota cooptació posterior passa pel flux de treball normal del §8.3.

A mesura que es coopting noves persones admins, la «solitud» inicial s'esvaïrà. La xarxa té vocació de tenir **diverses persones admins actives** (l'objectiu polític és generalment un cercle de 3 a 5 persones, en nombre imparell per evitar els bloquejos en cas de votació sobre certs temes connexos fora de spec).

## 8.8. Si la regla us molesta

**Trobeu la unanimitat massa exigent** («mai no s'arriba a cooptar, un veto ho bloqueja tot»). És un debat de fons sobre la naturalesa del col·lectiu de les persones admins de xarxa. Cal suavitzar cap a una majoria qualificada? Cal un mecanisme de supervot? A plantejar en debat de xarxa, i possiblement a formalitzar en una revisió de la spec.

**Trobeu la unanimitat massa laxa** («caldria també consultar les coordinacions locals abans de cooptar un-a-e admin»). És una altra opció política: consultar les coordinacions locals abans de la cooptació d'un-a-e admin de xarxa. A discutir. Això ampliaria el cercle decididor però alleugiria el procediment.

**Trobeu la carència de 7 dies per al retrait col·lectiu massa llarga o massa curta.** A portar a la spec.

**Trobeu que la doctrina d'informació prèvia és insuficientment emmarcada**: què és exactament una «urgència vital»? Hi ha d'haver una definició canònica? A discutir.

**Trobeu que la funció d'admin de xarxa té massa poder** (dret transversal massa extens) o no prou (hauria de poder resoldre certs conflictes). És una qüestió política fonamental. A discutir en trobada anual.

Vegeu el capítol 4 i l'annex C.

\newpage

# 9. La transparència en la pràctica

Aquest capítol tracta del funcionament concret de la **transparència** a AnarBib: qui veu què, com i per què. És l'aplicació del principi P5 (transparència màxima) i de P6 (notificacions sistemàtiques).

## 9.1. El principi

> **P5 — Transparència màxima.** L'audit log dels canvis de rol és llegible per tot el staff actiu de la biblioteca.
> **P6 — Notificacions sistemàtiques.** Tot canvi de rol desencadena un email a la persona concernida i a tota la coordinació.

La idea política: **fer impossibles les manipulacions opaques**. Si tot queda traçat i és llegible, no es pot fer passar en silenci una persona d'un estatus a un altre sense que ho vegin les altres persones membres del staff.

## 9.2. Qui veu què: matriu

### Al nivell d'una biblioteca

| Informació | reader | librarian | coordenador | admin de xarxa |
|---|---|---|---|---|
| Llista de l'equip (rols actius) | parcial (els noms públics només) | completa | completa | completa |
| Estatus (`suspended`, `pending_removal`) | no | sí | sí | sí |
| Audit log complet de l'equip | no | sí | sí | sí |
| Audit log: raons de les accions | no | sí | sí | sí |
| Sol·licitud de retrait en curs: qui ho ha demanat | no | sí | sí | sí |
| Dades personals de les altres persones lectores-àries-e | no | sí (d'aquesta biblioteca) | sí | sí |

### Al nivell de la xarxa

| Informació | reader | staff biblioteca | admin de xarxa |
|---|---|---|---|
| Llista de les persones admins de xarxa actives | sí (pàgina pública `/rede`) | sí | sí |
| Comptadors de xarxa (nombre de biblioteques, etc.) | sí | sí | sí |
| Audit log de xarxa (cooptacions, retraits d'admins) | no | no | sí |
| Propostes de cooptació en curs | no | no | sí |
| Logs cross-biblioteques (accions d'admin de xarxa sobre biblioteca X) | no | sí (de la seva biblioteca) | sí |

## 9.3. L'audit log d'equip en la pràctica

És l'eina de transparència més important. Es pot consultar des de `/biblioteca` → pestanya **Equip** → secció **Historial de l'equip**.

### Què s'hi veu

Cada entrada mostra:
- Data i hora.
- Acció («promogut-da-e a librarian», «auto-retrogradat-ada-e», «retrait sol·licitat», «suspès-a-e», «reintegrat-ada-e després de suspensió», «pas automàtic a inactiu-va-e després de 9 mesos», etc.).
- Persona concernida (target).
- Persona autora de l'acció (actor) — per a les accions humanes. Buit per a les accions automàtiques (cron).
- Raó (si s'ha indicat).
- Rol i estatus abans/després.

### Per a què serveix políticament

- **Memòria col·lectiva**: es pot reconstruir la història de la coordinació, veure com s'ha constituït i ha evolucionat.
- **Guarda contra l'opacitat**: si un-a-e coordinador-a-e ha fet accions dubtoses (cooptacions estranyes, suspensions injustificades), és visible per tothom.
- **Eina de deliberació**: en cas de debat («havíem dit que faríem rotar les coordinacions!»), el log aporta elements factuals.
- **Eina de transició**: quan arriba un-a-e nou-va-e coordinador-a-e, pot llegir el log per entendre la història recent sense haver d'interrogar tothom.

### Què cal fer-ne

- **Llegir-lo regularment**. No cada dia, però un cop al mes, per exemple en una reunió de coordinació.
- **Discutir el que sembli estrany**. Si una acció us sembla incomprensible o injustificada, pregunteu a la seva persona autora.
- **No utilitzar-lo com a arma**. El log és un eina de transparència col·lectiva, no un instrument de vigilància interpersonal.

## 9.4. Els emails de notificació

Cada acció de governança desencadena **un o diversos emails** automàtics. No és correu brossa: és deliberat, perquè ningú no ha de ser afectat-ada-e per un canvi de rol sense ser-ne informat-ada-e.

### Qui rep què

| Esdeveniment | Persona concernida | Coordinadors-es-e locals actius-ves-e | Admins de xarxa |
|---|---|---|---|
| Cooptació (T1, T2) | ✅ | ✅ | — |
| Auto-retrogradació (T3, T4) | ✅ confirmació | ✅ | — |
| Sol·licitud de retrait (T5) | ✅ | ✅ | — |
| Cancel·lació de sol·licitud (T8) | ✅ | ✅ | — |
| Fi de carència (D+7) | ✅ | ✅ | — |
| Suspensió (T6) | ✅ urgent | ✅ | — |
| Aixecament de suspensió (T7) | ✅ | ✅ | — |
| Sortida automàtica als 9 mesos (T9) | ✅ recordatoris + final | ✅ (final només) | — |
| Última persona coordinadora-ària-e que marxa | ✅ | ✅ (la persona concernida) | ✅ alerta |
| Cooptació admin de xarxa (proposta) | — | — | ✅ |
| Cooptació admin de xarxa (èxit) | ✅ benvinguda | — | ✅ resum |
| Cooptació admin de xarxa (rebuig) | ✅ amb raonament | — | ✅ |
| Retrait col·lectiu admin de xarxa | ✅ | — | ✅ |
| Intervenció cross-biblioteques | — | ✅ (coordinadors-es-e de la biblioteca) | ✅ (la persona autora) |

### El to dels emails

Els emails de governança segueixen les convencions militants de la xarxa (cf. memòria interna): sobrietat, claredat, accessibilitat (llengua comuna sense argot), formulació inclusiva i escriptura desacralitzada. Sense fórmules oficials, sense signatures burocràtiques.

Exemple tipus per a una sol·licitud de retrait:
> Hola Karl,
>
> La coordinació de la BLMF ha sol·licitat el teu retrait de l'equip (rol: librarian), arran de: «decisió AG del 04/05».
>
> Aquest preavís entrarà en vigor el **12 de maig de 2026** (d'aquí a 7 dies), llevat cancel·lació per un-a-e altre-a-e coordinador-a-e d'aquí a llavors.
>
> Durant aquest període, ja no tens accés a les funcions de librarian. Per a qualsevol discussió, adreça't a la coordinació de la BLMF — aquesta decisió pertany a la vida orgànica del col·lectiu local i no es gestiona via el SIGB.
>
> AnarBib

El to busca informar factualment sense dramatitzar ni minimitzar.

### Confidencialitat dels emails — guarda contra el rastreig

Els emails de governança, com totes les notificacions del SIGB, s'expedeixen via **Resend**, el subcontractista d'enviament de la xarxa (cf. registre de tractaments i DPA). Dues garanties polítiques encadren aquest enviament:

- **Sense rastreig.** El seguiment de les obertures i dels clics — que recolliria l'adreça IP, la localització, el dispositiu i el client de correu de la persona destinatària — és una opció **desactivada** en la instància AnarBib. Rebre un email de governança no deixa cap empremta tècnica al costat de la xarxa.
- **Minimització.** Només les dades estrictament necessàries per a l'enviament transiten (adreça email, nom per a la personalització, contingut de la notificació). Cap dada sensible no es transmet.

Aquesta guarda és doctrinal: prolonga el compromís de no-rastreig de la xarxa fins a la capa email. Està documentada al registre de tractaments (art. 30 RGPD) i al DPA; tot canvi de subcontractista de correu és notificat a les biblioteques adherents (DPA art. 5.4).

## 9.5. El cas de les notificacions «cross-biblioteques»

Quan un-a-e admin de xarxa intervé en una biblioteca (cf. §8.6), es produeixen dues notificacions:

- **Notificació prèvia** (manual): la persona admin envia un correu a la coordinació local abans d'actuar. Format lliure.
- **Notificació automàtica** (pel SIGB): en l'execució de l'acció, el sistema escriu a `cross_library_actions_log` amb nivell de criticitat, i envia un correu a les coordinadores-àries-e actives de la biblioteca concernida.

Aquesta doble notificació (manual + automàtica) garanteix que la coordinació local sigui avisada **abans** políticament i **després** tècnicament. La traça tècnica és llegible a posteriori a la pestanya **Equip** → secció **Intervencions de xarxa** (a venir al paquet D).

## 9.6. Límits de la transparència

La transparència d'AnarBib té límits, que cal explicitar:

**Les persones `reader` no veuen l'audit log de l'equip.** Això és deliberat (P5 parla de «staff actiu»). Les persones `reader` no veuen qui ha cooptat qui, qui ha estat suspès-a-e, etc. La transparència juga **dins de la coordinació**, no cap a les persones usuàries.

**Una biblioteca no veu l'audit log d'una altra biblioteca.** Sobirania local (P7). Els canvis de rol a la biblioteca A són estrictament opacs per a la biblioteca B, llevat via el canal humà (discussió entre coordinadors-es-e de les dues biblioteques).

**L'audit log de xarxa (cooptacions i retraits d'admins) no és públic.** Llegible per les persones admins de xarxa únicament. Una biblioteca local pot veure la llista de les persones admins de xarxa actuals (pàgina `/rede`), però no l'historial de les cooptacions ni els raonaments dels vots oposats.

Aquests límits no són hipocresies. Corresponen a un equilibri entre **transparència** (dins del staff deliberant) i **confidencialitat** (respecte a les persones usuàries i entre perímetres). Si trobeu l'equilibri mal situat, és esmenable (capítol 4).

## 9.7. Si la regla us molesta

**Penseu que les persones `reader` haurien de veure l'audit log de l'equip** (transparència radical envers les persones usuàries). És una posició defensable, però té conseqüències (els conflictes interns es tornen públics, la vida política del col·lectiu s'exposa). A discutir en xarxa.

**Penseu a l'inrevés que l'audit log és massa visible** (un-a-e librarian discret-a-e no hauria de poder «espiar» les accions de les coordinaciones-àries-e). Això també és defensable. Però contradiu P5. A discutir.

**Trobeu els emails massa nombrosos o poc explícits.** El contingut està parametritzat a `mail-strings.ts` × 10 locales. Tota modificació d'un correu és esmenable com una modificació de codi. A portar amb les persones que desenvolopen.

**Penseu que l'audit log de xarxa hauria de ser públic almenys per a les coordinadores-àries-e locals** (perquè puguin veure qui decideix què al nivell de xarxa). És una opció interessant. A discutir.

Vegeu el capítol 4 i l'annex C.

\newpage

# 10. Casos concrets comentats

Per acabar, sis escenaris complets. Cadascun il·lustra una combinació de mecanismes i permet veure el SIGB en acció. Els noms (Voltairine, Emma, Karl, Lucy, Errico, Friedrich) són els de les companyes i companys-a-e històric-a-es del pensament llibertari; aquí serveixen com a casos tipus ficticis.

## 10.1. Voltairine és cooptada librarian

> **Context.** Emma és coordinadora-a-e a la BLMF. La Voltairine ve des de fa vuit mesos a les permanències, participa en la vida de la biblio, i té clarament el perfil per entrar a l'equip. El col·lectiu local ho ha discutit en AG el 4 de maig i ha aprovat la seva cooptació.

**Procediment.**

1. Emma es connecta el 5 de maig a les 14h30. Va a `/biblioteca`, pestanya **Equip**.
2. Cerca Voltairine a la llista de `reader` de la biblio (té un compte AnarBib des del febrer).
3. Fa clic a **« Convidar a l'equip »** → tria **librarian**.
4. Camp « Raó »: « decisió AG del 04/05 » (doctrina 1, espera estricta).
5. Confirma.

**Efecte immediat.**

- Voltairine rep un correu: « Salut Voltairine, has estat nomenada librarian de la BLMF per Emma G. arran de: "decisió AG del 04/05". Els teus nous drets estan actius. Benvinguda a l'equip. »
- Les altres coordinadore-a-es actives de la BLMF (Lucy i Piotr) reben un correu informatiu.
- Audit log: `2026-05-05 14:30 — Emma G. ha promocionat Voltairine d.C. a librarian (raó: decisió AG del 04/05)`.

**Comentari.**

El cas més senzill. El SIGB executa correctament la decisió del col·lectiu. Emma no ha decidit res políticament — ha fet clic per executar allò que s'havia decidit fora del programari.

**El que el SIGB no ha fet:** verificar que l'AG ha tingut lloc realment, que la decisió s'ha pres realment, que Voltairine hi està realment d'acord. Aquestes coses són **fora del programari**. Si Emma hagués mentit sobre l'AG, el SIGB no s'hauria adonat de res. La cultura política de la BLMF és el que impedeix aquesta mentida (i el log la fa traçable a posteriori).

## 10.2. Lucy fa el relleu

> **Context.** Lucy és coordinadora-a-e a la BLMF, però no pot assumir la càrrega aquest semestre (comença una tesi). Vol « tornar a ser librarian » per continuar a l'equip però alleujar les seves responsabilitats.

**Procediment.**

1. Lucy va a `/biblioteca`, pestanya **Equip**.
2. A la seva pròpia línia (estat `coordenador`), fa clic a **« Faig el relleu »**.
3. Opció: « tornar a ser librarian ».
4. La modal de confirmació recorda que perdrà els permisos de coordinació immediatament.
5. Lucy confirma. Raó opcional: « inici de la tesi, alleujament temporal ».

**Efecte immediat.**

- La seva membership `coordenador` passa a `inactive`.
- La seva membership `librarian` (que existia en paral·lel) resta `active`.
- Lucy rep un correu de confirmació: « Ara ets librarian de la BLMF. Conserves els teus permisos operacionals. »
- Tota la coordinació (Emma, Piotr) rep un correu: « Lucy P. ha fet el relleu, ja no és coordinadora-a-e. Continua com a librarian de l'equip. »
- Audit log: `2026-05-05 18:42 — Lucy P. s'ha auto-retrogradat de coordenador → librarian (raó: inici de la tesi, alleujament temporal)`.

**Comentari.**

És l'ús exemplar del dret P3. Lucy no ha hagut de demanar autorització a ningú. La seva auto-retrogradació és immediata. Continua contribuint a la biblio, però a una intensitat ajustada a la seva disponibilitat actual.

**Políticament**: és exactament el tipus de rotació que volem afavorir. No perdem la Lucy, simplement adopta un altre rol. D'aquí a sis mesos o un any, si vol reprendre la coordinació, el col·lectiu podrà tornar a cooptar-la (T2). Cap decisió és definitiva.

## 10.3. Karl ha de marxar

> **Context.** Karl és librarian a la BLMF. El seu comportament amb cert-a-es lector-a-es ha generat problemes (paternalisme, comentaris fora de lloc). El col·lectiu ho ha discutit en AG el 4 de maig i ha decidit que havia de deixar l'equip.

**Procediment.**

1. Piotr (coord) — triat per l'AG per executar la decisió — va a `/biblioteca`, pestanya **Equip**.
2. A la línia de Karl, fa clic a **« Sol·licitar la retirada »**.
3. Modal vermella amb el termini de 7d explícit.
4. Raó obligatòria: « Arran de l'AG del 04/05, comportament inadequat amb diversos lector-a-es reportat durant diversos mesos, decisió col·lectiva d'exclusió. »
5. Confirmació explícita: « Entenc que aquesta sol·licitud tindrà efecte el 12 de maig de 2026 excepte si és cancel·lada per un-a-e altr-e coord. »

**Efecte immediat.**

- La membership de Karl passa a `pending_removal`, `pending_removal_until = 2026-05-12`.
- **Karl perd l'accés** immediatament a totes les funcions de librarian (la membership queda congelada).
- Karl rep un correu:
  > « Salut Karl, la coordinació de la BLMF ha sol·licitat la teva retirada de l'equip (rol: librarian), arran de: "Arran de l'AG del 04/05, comportament inadequat amb diversos lector-a-es reportat durant diversos mesos, decisió col·lectiva d'exclusió." Aquest preavís tindrà efecte el 12 de maig de 2026 (d'aquí a 7 dies), excepte si és cancel·lat per un-a-e altr-e coord d'aquí a llavors. Per a qualsevol discussió, adreça't a la coordinació de la BLMF. »
- Emma i Lucy (altres coords) reben el correu informatiu.
- Audit log: `2026-05-05 — Piotr K. ha sol·licitat la retirada de Karl M. (rol: librarian, raó: ...)`.

**Evolució.**

- 6 de maig a les 9h: Lucy llegeix el correu. Està d'acord amb la decisió i no intervé.
- 7 de maig: Emma té un intercanvi amb Karl (que li escriu per explicar-se). Emma conclou que la decisió es manté. No intervé.
- 8-11 de maig: res.
- **12 de maig a les 00h00**: el cron `cron_team_pending_removal_complete` s'executa. Karl passa a `inactive`.
- Correu final a Karl + a la coordinació.
- Audit log: `2026-05-12 — pas automàtic a inactiu (raó: pending_removal expirat, cron) — actor: NULL`.

**Comentari.**

És el cas de l'exclusió col·lectiva. Tres elements polítics a destacar:

- **La caducitat ha funcionat com a possible salvaguarda**, sense que se n'hagi fet ús. Lucy i Emma haurien pogut cancel·lar; no ho han fet. El fet que ningú no hagi cancel·lat és en si mateix una **deliberació implícita**.
- **Karl ha romàs informat** sense sorpreses. Cap exclusió silenciosa.
- **L'audit log és llegible** per tot el personal i permet tornar sobre aquesta decisió si més endavant algú es pregunta per què va marxar Karl.

**Políticament delicat**: la raó escrita al camp « Raó » és llegible per tot el personal. No hauria de contenir detalls sobre les víctimes (RGPD, dignitat), però hauria de ser prou clara perquè la decisió sigui defensable políticament. Trobar el dosatge just és una competència de coordinador-a-e.

## 10.4. Compte compromès: suspensió immediata

> **Context.** El 5 de maig a les 19h30, Emma s'adona als logs d'activitat que Friedrich (librarian) ha fet 47 modificacions de fitxes de catàleg en 3 minuts, diverses de les quals són aberrants (llibres marcats com a « desapareguts » quan es troben a les prestatgeries, etc.). El patró s'assembla a un accés no autoritzat.

**Procediment.**

1. Emma va a `/biblioteca`, pestanya **Equip**.
2. A la línia de Friedrich, fa clic a **« Suspendre »**.
3. Modal amb raó **obligatòria** (≥ 20 caràcters).
4. Emma escriu: « Sospita de compte compromès, activitat anormal (47 modificacions de catàleg en 3 min), verificació en curs. »
5. Confirma.

**Efecte immediat (19h32).**

- Friedrich passa a `status='suspended'`.
- **Cap accés** per a Friedrich.
- Friedrich rep un correu urgent: « El teu compte AnarBib ha estat suspès a títol conservatori a la BLMF. Raó: sospita de compromís del teu compte. Et suggerim fermament que **canviïs la teva contrasenya immediatament**. Un cop el teu compte estigui assegurat, posa't en contacte amb la coordinació de la BLMF perquè s'aixequi la suspensió. »
- La coordinació (Lucy, Piotr) rep un correu.
- Audit log: `2026-05-05 19:32 — Emma G. ha suspès Friedrich E. (rol: librarian, raó: ...)`.

**Evolució.**

- **19h35**: Emma truca a Friedrich (canal fora del SIGB). Friedrich confirma que no ha fet aquestes accions. Havia deixat el seu ordinador obert en un espai compartit.
- **19h40**: Friedrich canvia la seva contrasenya a través del procediment de reinicialització.
- **20h00**: Emma verifica les accions dubtoses a l'audit log de la biblio (l'audit de catàleg, no l'audit d'equip). Identifica les 47 modificacions. Les cancel·la manualment o sol·licita un rollback a un-a-e admin de xarxa si cal.
- **20h15**: Emma torna a la pestanya Equip i aixeca la suspensió de Friedrich.
- Friedrich rep un correu de confirmació. Audit log: `2026-05-05 20:15 — Emma G. ha aixecat la suspensió de Friedrich E.`.

**Comentari.**

Cas típic on la suspensió s'utilitza com a **mesura conservatòria**, no com a exclusió. Friedrich no té cap culpa — és el seu compte el que ha estat compromès. La suspensió ha durat 43 minuts, el temps necessari per assegurar-lo.

**Important políticament**: Friedrich no ha estat « acusat ». El correu ho precisa clarament (« a títol conservatori »). Quan la situació es resol, la suspensió s'aixeca, i l'episodi queda traçat al log com un incident, no com una culpa.

## 10.5. Errico és l'únic-a-e coord i vol marxar

> **Context.** La BLMF ja només té un-a-e coordinador-a-e actiu-va-e, Errico. Lucy ha fet el relleu, Emma s'ha mudat i ja no és activa. Piotr s'ha retrogradat a principi d'any. Errico ha de marxar (mudança a l'estranger, ja no té temps).

**Procediment.**

1. Errico va a `/biblioteca`, pestanya **Equip**, fa clic a **« Faig el relleu »**.
2. S'obre una modal **especial**:
   > ⚠️ **ATENCIÓ**: ets l'únic-a-e coordinador-a-e actiu-va-e de la BLMF. La biblio es quedarà sense coordinació. Les admins de xarxa d'AnarBib seran notificades-a-es. La BLMF podrà continuar funcionant (les librarians es mantenen operacionals-a-es) però cap modificació de la configuració serà possible fins a la cooptació d'un-a-e nou-a-e coord. Continuar?
3. Errico confirma. Raó: « Mudança a l'estranger, ja no tinc disponibilitat per a la coordinació. »

**Efecte immediat.**

- La membership coordenador d'Errico passa a `inactive`.
- Correu a Errico (confirmació).
- Correu a tota la coordinació de la BLMF — però ja no n'hi ha, de manera que en la pràctica les `librarian` actives-a-es restants reben una notificació.
- **Correu urgent a les admins de xarxa**: « La BLMF ja no té coordinador-a-e actiu-va-e. Aquí hi ha les librarians actives-a-es restants: Voltairine d.C., Friedrich E., ... »
- Audit log: `2026-05-05 — Errico M. s'ha auto-retrogradat de coordenador → reader (raó: ..., warning: last_coordinator_leaving)`.

**Evolució fora del programari.**

- 6 de maig: Xavier (admin de xarxa) es posa en contacte amb Voltairine i Friedrich, les `librarian` actives-a-es restants. Confirmen que el col·lectiu BLMF continua existint i que volen continuar.
- 7-15 de maig: discussió interna del col·lectiu BLMF, que decideix en AG cooptar Voltairine al rol de coordinadora-a-e.
- 16 de maig: Xavier (o un-a-e altr-e coord BLMF que ja no existeix en aquest cas, de manera que és Xavier en el seu dret transvers) coopta Voltairine com a coordinadora-a-e. **Informació prèvia obligatòria**: Xavier ha escrit a Friedrich i Voltairine 2 dies abans per anunciar l'acció. Un cop feta, l'acció queda traçada a `cross_library_actions_log` amb nivell de criticitat « elevat » (modificació de la coordinació d'una biblio per un-a-e admin de xarxa).

**Comentari.**

Cas políticament delicat: la biblio passa per un període de fragilitat (entre el 5 i el 16 de maig, no té coordinació). Però el SIGB **no ha impedit** la marxa d'Errico — el seu dret P3 és incondicional. El SIGB simplement ha **alertat la xarxa** perquè aquesta pogués ajudar.

La intervenció de Xavier il·lustra l'ús **correcte** del dret transvers: ha estat sol·licitat (implícitament, per l'alerta automàtica), ha respectat la informació prèvia, ha traçat la seva acció. No ha imposat Voltairine; és el col·lectiu BLMF qui l'ha triada. Xavier simplement ha **executat tècnicament** la decisió.

## 10.6. Una cooptació d'admin de xarxa que no prospera

> **Context.** Xavier és admin de xarxa fundador-a-e. Amb el temps, Maria, Patricia i Diego han estat cooptades-a-es com a admins de xarxa a mesura que la xarxa s'ha ampliat. El 20 de maig de 2026, el col·lectiu de les admins és: Xavier, Maria, Patricia, Diego (quatre admins actives-a-es).
>
> Maria proposa la cooptació de Mohammed, que coneix en una biblio italiana que s'incorpora a la xarxa.

**Procediment.**

1. Maria, des de `/rede/administradores`, fa clic a **« Proposar una cooptació »**.
2. Introdueix la identitat de Mohammed (compte AnarBib creat dues setmanes abans).
3. Motivació: « Mohammed coordina la BLA (Bolonya), una biblio que s'incorpora a la xarxa aquest mes. Ha portat la integració política de la BLA a AnarBib i és molt implicat en la coordinació italiana. La seva cooptació com a admin de xarxa reforçarà la diversitat geogràfica del col·lectiu i facilitarà l'animació pel costat d'Itàlia. »
4. Confirma.

**Efecte immediat.**

- Proposta creada, `status='open'`, `expires_at = 19 juny 2026`.
- Vot automàtic `favorable` de Maria registrat.
- Correus a Xavier, Patricia, Diego amb la proposta.

**Evolució.**

- 22 de maig: **Diego** vota `favorable`. Sense raonament (opcional per a favorable).
- 25 de maig: **Patricia** vota `opposed`. Raonament: « Mohammed no té cap antiguitat a la xarxa. La seva cooptació va més de pressa que la de la BLA, que encara no ha tingut l'oportunitat de funcionar com a biblio AnarBib durant prou temps. Proposo esperar 6 mesos perquè la BLA s'hagi assentat, i llavors reproposar Mohammed. » Patricia marca « Revelar la meva identitat ».

**Efecte immediat del vot opposed.**

- La proposta passa a `status='rejected'`.
- Correu a Mohammed: « Bon dia Mohammed, la teva proposta de cooptació com a admin de xarxa d'AnarBib no ha prosperat. Patricia X. ha plantejat l'objecció següent: "[raonament complet]". Pots parlar amb ella o amb Maria, que t'havia proposat-a-e. La cooptació podrà ser reproposada més endavant. »
- Correu a Maria (proponent): resum amb el raonament de Patricia.
- Correu a Xavier i Diego: informació que la proposta és rebutjada, amb el raonament.
- Audit log de xarxa: `2026-05-25 — cooptació rebutjada: Mohammed (proposed_by: Maria, opposed_by: Patricia, rationale: ...)`.

**Comentari.**

Cas il·lustratiu de la unanimitat **en acció**. Patricia té un veto, l'utilitza, el seu raonament és explícit i constructiu (« esperem 6 mesos »). Ha triat revelar la seva identitat, la qual cosa permet a Mohammed i Maria parlar amb ella directament en lloc de especular sobre l'oponent-a-e anònim-a-e.

**Políticament**: la cooptació per unanimitat no és una garantia de bloqueig permanent. Patricia no diu « mai » sinó « ara no ». Si d'aquí a 6 mesos la BLA està ben integrada i Patricia canvia d'opinió, una nova proposta podrà prosperar. És aquesta **reversibilitat en el temps** la que fa la unanimitat suportable.

L'alternativa — cooptar Mohammed per majoria contra l'opinió de Patricia — hauria creat un cercle de les admins on Patricia s'hauria sentit en una posició incòmoda. Val més esperar.

\newpage

# Annexos

\newpage

# Annex A — Glossari

**AG** — Assemblea general. Reunió col·lectiva de presa de decisions d'una biblio. El SIGB no modela l'AG (P8). La seva modalitat (quòrum, freqüència, mode de deliberació) és enterament decidida per cada biblio.

**Audit log** — Diari de les accions de governança, emmagatzemat a `library_membership_audit` (a nivell d'una biblio) i `network_administrator_audit` (a nivell de xarxa). Llegible pel personal actiu (a nivell de biblio) i per les admins de xarxa (a nivell de xarxa).

**Auto-retrogradació** — Acció per la qual un-a-e membre del personal es retrograda a si mateixa-a-e a un rol inferior. Dret P3, incondicional.

**Biblio `private`** — Biblio el catàleg de la qual només és visible pels seus membres inscrits-a-es. Mode adaptat a les biblios políticament exposades.

**Biblio `network`** — Biblio el catàleg de la qual és visible per totes-a-es les `reader` validades-a-es de la xarxa AnarBib. Mode per defecte per a la majoria de les biblios.

**Biblio `public`** — Biblio el catàleg de la qual és visible per tothom, incloses les persones visitants anònimes.

**Caducitat** — Termini imposat entre una decisió i el seu efecte. Set dies per als retiraments col·lectius de personal local i d'admin de xarxa. Trenta dies per a l'auto-retirada de l'únic-a-e admin de xarxa actiu-va-e.

**Cooptació** — Mecanisme d'entrada en un equip (personal local) o en el col·lectiu de les admins de xarxa. Per al personal local: decisió d'un-a-e coord+. Per a la xarxa: unanimitat de les admins actives-a-es.

**Cross-biblios** — Qualifica una acció efectuada per un-a-e admin de xarxa sobre una biblio de la qual no és membre del personal local. Traçada a `cross_library_actions_log`.

**Cron** — Tasca automàtica executada periòdicament pel SIGB. Sense actor-a-e humà-na-e. Exemples: `cron_team_pending_removal_complete` (pas de `pending_removal` a `inactive` a J+7), `cron_team_inactive_cleanup` (sortida automàtica als 9 mesos).

**Delegació** — Acte pel qual un col·lectiu confia temporalment una funció a un-a-e dels seus membres, conservant la possibilitat de recuperar-la. Concepte central, distingit de « jerarquia ».

**Membership** — Línia de la taula `user_library_memberships` que expressa la vinculació d'una persona a una biblio en un rol determinat. Una persona pot tenir diverses memberships en una mateixa biblio (multi-membership).

**Multi-membership** — Possibilitat de tenir diverses línies de membership per a una mateixa persona en una mateixa biblio, amb rols diferents.

**Xarxa** — El col·lectiu de les biblios que es reconeixen mútuament i comparteixen la plataforma AnarBib. No és una organització central, és una federació.

**RPC** — *Remote Procedure Call*. Funció SQL cridada per la interfície de la persona usuària per executar una acció. Totes les accions de governança passen per RPCs anomenades `fn_team_*` (personal local) o `fn_network_admin_*` (xarxa).

**Sobirania local** — Principi P7 segons el qual cada biblio és sobirana sobre les seves delegacions internes. Els canvis de rol en una biblio no afecten res en cap altra.

**Spec** — Document d'especificació (`spec-*.md`) que descriu en detall el funcionament d'una funcionalitat del SIGB. Font de veritat tècnica i política. Versionada, datada, esmendable.

**Unanimitat** — Modalitat de cooptació i de retirada col·lectiva de les admins de xarxa. Tots els vots han de ser `favorable`; un sol `opposed` o una abstenció no resolda bloqueja.

**Validació física** — Procediment pel qual un-a-e librarian+ valida un compte `reader` després d'una trobada física. Val per a tota la xarxa (pacte de reconeixement mutu).

**Veto** — Vot `opposed` durant una cooptació o una retirada col·lectiva d'admin de xarxa. Efecte immediat: rebuig de la proposta. Raonament obligatori de 20 caràcters mínim.

\newpage

# Annex B — Índex de les funcions tècniques

Aquest annex dóna, per a cada RPC esmentada en el guia, la seva traducció política i la transició concernida. Serveix de referència ràpida.

## Funcions de personal local

| RPC SQL | Transició | Traducció política |
|---|---|---|
| `fn_team_promote_to_librarian` | T1 | Cooptació `reader` → `librarian` |
| `fn_team_promote_to_coordenador` | T2 | Cooptació `librarian` → `coordenador` |
| `fn_team_self_demote` | T3, T4 | Auto-retrogradació (« faig el relleu ») |
| `fn_team_request_remove_member` | T5 | Sol·licitud de retirada amb caducitat 7d |
| `fn_team_cancel_remove_member` | T8 | Cancel·lació d'una sol·licitud de retirada |
| `fn_team_suspend_member` | T6 | Suspensió immediata (mesura conservatòria) |
| `fn_team_unsuspend_member` | T7 | Aixecament de la suspensió |
| `fn_validate_physical_account` | — | Validació física d'un-a-e `reader` |
| `cron_team_pending_removal_complete` | T5 (continuació) | Cron: pas a `inactive` a J+7 |
| `cron_team_inactive_cleanup` | T9 | Cron: sortida automàtica als 9 mesos |

## Funcions d'admin de xarxa

| RPC SQL | Etapa | Traducció política |
|---|---|---|
| `fn_network_admin_propose_cooptation` | Cooptació: proposta | Un-a-e admin proposa un-a-e nou-a-e |
| `fn_network_admin_vote_cooptation` | Cooptació: vot | Vot favorable / opposed / abstain |
| `fn_network_admin_self_remove` | Auto-retirada | Deixar les funcions d'admin de xarxa |
| `fn_network_admin_request_removal` | Retirada col·lectiva | Workflow mirall de la cooptació |

## Helpers d'autorització (usats per les RLS)

| Helper SQL | Sentit polític |
|---|---|
| `user_can_act_as_staff_on_library(library_id)` | Aquesta persona pot actuar com a personal en aquesta biblio? (personal local actiu OR admin de xarxa) |
| `user_can_engage_library(library_id)` | Aquesta persona pot comprometre políticament aquesta biblio? (coord local actiu OR admin de xarxa) |
| `fn_caller_is_network_admin()` | La persona que crida és un-a-e admin de xarxa actiu-va-e? |
| `fn_library_visible_to_caller(library_id)` | El catàleg d'aquesta biblio és visible per a la persona que crida? |

## Taules principals

| Taula | Sentit polític |
|---|---|
| `user_library_memberships` | Les delegacions locals (qui és personal de quina biblio) |
| `network_administrators` | Les administradores-a-es de la xarxa |
| `library_membership_audit` | Diari de les accions de governança local |
| `network_administrator_audit` | Diari de les accions de governança de xarxa |
| `network_administrator_cooptation_proposals` | Propostes de cooptació en curs |
| `network_administrator_cooptation_votes` | Vots individuals de les admins |
| `cross_library_actions_log` | Rastre de les accions d'admin de xarxa sobre biblios |

\newpage

# Annex C — Model de nota d'esmena

Quan voleu proposar una esmena a una regla del SIGB o a aquest guia, aquí teniu un model de nota per estructurar la vostra proposta. Format lliure, podeu adaptar-lo.

---

## Proposta d'esmena a [nom de la spec o del guia]

**Autor-a-es:** [els vostres noms / pseudònims]
**Data:** [DD/MM/AAAA]
**Perímetre:** [biblio local / xarxa / fonaments]

### 1. Regla concernida

Citar textualment la regla o el paràgraf a esmenar, amb la seva referència en la spec font.

> *Exemple:* « `spec-gouvernance-roles.md`, §5.6, T5: El termini de caducitat abans de l'exclusió efectiva és de 7 dies. »

### 2. Problema identificat

Descriure en unes quantes frases què planteja problemes en la regla actual. Si és possible, amb un cas concret viscut.

> *Exemple:* « A la pràctica, 7 dies és massa curt quan la propera AG de la biblio es fa d'aquí a 15 dies. Una decisió de retirada presa en calent de vegades no té temps de ser discutida col·lectivament abans de l'efecte automàtic. »

### 3. Esmena proposada

Descriure la modificació desitjada, en la mesura possible amb una formulació llesta per integrar a la spec.

> *Exemple:* « Passar el termini de caducitat de 7 a 14 dies, O bé fer el termini configurable per biblio (entre 7 i 30 dies), amb un valor per defecte a 14 dies. »

### 4. Conseqüències tècniques anticipades

Si teniu una idea del que implica pel costat del codi, dir-ho. Si no, dir-ho també (« no ho sé, a veure amb les devs »).

> *Exemple:* « Modificar el valor fix al codi SQL de `fn_team_request_remove_member` i `cron_team_pending_removal_complete`. Si és configurable per biblio, afegir una columna a `libraries`. »

### 5. Conseqüències polítiques anticipades

Descriure el que canvia en la pràctica col·lectiva, i els possibles efectes secundaris.

> *Exemple:* « Més temps per a la deliberació, però també més temps durant el qual la persona en `pending_removal` roman suspesa (sense accés). Pot ser percebut com més pesat. »

### 6. Alternatives considerades

Esmentar les altres pistes que heu tingut en compte, i per què les descarteu (o no).

> *Exemple:* « Alternativa: deixar el termini a 7 dies però permetre una "prolongació explícita" per un-a-e altr-e coord. Més complex d'implementar i d'entendre. Preferible modificar el valor per defecte. »

### 7. Discussió desitjada

On i com voleu que la proposta sigui discutida?

> *Exemple:* « Discussió al canal Matrix `#anarbib`, i si hi ha consens, integració a la spec durant el proper paquet de governança. »

---

Un cop redactada, fer circular la nota segons el perímetre (cf. capítol 4, §4.2).

\newpage

# Annex D — Specs fonts i referències

Aquest guia es recolza sobre els documents següents, consultables al repositori del projecte:

## Specs principals

**`spec-gouvernance-roles.md`** — Spec fundadora de la governança dels rols de personal local. Versió 1.0 del 5 de maig de 2026. 1231 línies. Detalla els 4 rols, els 5 estats, les 9 transicions, l'audit log, les notificacions, la interfície, i 15 casos d'ús de referència.

**`spec-administrateur-reseau.md`** — Separació entre personal local i admin de xarxa. Versió 0.3 de l'11 de maig de 2026. 975 línies. Detalla la taula `network_administrators`, la cooptació per unanimitat, la retirada col·lectiva, el dret transvers, la semàntica dels comptadors « pàgina = perímetre ».

**`spec-validation-physique.md`** — Modes d'acollida dels comptes de lector-a-es (`open` vs `manual_validation`). Emmarcada el 3 de maig de 2026. Detalla els estats del compte, l'esquema DB, els workflows.

**`spec-refactor-v3-semantique.md`** — Refactor de la semàntica del workflow de reserva. No és central per a la governança però s'esmenta marginalment per a la coherència d'conjunt del SIGB.

## Specs germanes esmentades (per redactar o en curs)

- `spec-migration-compte.md` — Migració d'un compte d'una biblio a una altra. 940 línies, emmarcada el 3 de maig de 2026.
- `spec-invitation-equipe.md` — Workflow d'invitació per correu per a les persones sense compte AnarBib. Per redactar.
- `spec-fermeture-biblio.md` — Procediment de tancament ordenat d'una biblio. Per redactar.
- `spec-mediation-conflits.md` — Marc formalitzat de mediació i investigació arran de denúncia. Per redactar (suggerit pel present guia).

## Per saber-ne més

Les specs i el codi font es troben al repositori Codeberg del projecte, mirall GitHub. La discussió tècnica i política es desenvolupa al canal Matrix `#anarbib` de la xarxa.

Per a qualsevol proposta d'esmena a aquest guia o a les specs, vegeu el capítol 4 i l'annex C.

---

*Fi del guia. Versió 1.0, 11 de maig de 2026.*

*Aquest guia és en si mateix esmendable. Si trobeu que diu alguna cosa incorrecta, que s'ha oblidat d'un cas, o que pren una posició que ja no correspon a la doctrina de la xarxa, digueu-ho.*

