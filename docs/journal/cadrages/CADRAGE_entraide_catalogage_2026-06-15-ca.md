# Cadratge — Entraide al catalogatge (pestanya «Entraide» de la Federació)

**Data** : 2026-06-15
**Estat** : **cadratge / projecte** — reflexió exploratòria que posa la *visió*,
l'*arquitectura* i les *decisions de principi*. **No és encara una especificació a
construir**: a discutir, provar, i després desglossar en specs.
**Base ètica** : [`notes-audit/anarbib-charte-relationnelle-v0.1.md`](../../../notes-audit/anarbib-charte-relationnelle-v0.1.md)
(«la mà estesa»). **Cada pantalla de sota ha estat passada per la graella «¿tendeix o
agafa?».** Aquest cadratge és, en certa mesura, la primera prova concreta de la carta.

---

## 1. La necessitat

El catalogatge és el punt de dolor de les biblioteques debutants (cf. els chantiers
d'autoritats, indexació matèria, wizard de descoberta). Una biblioteca sola davant les
autoritats, els temes, la classificació, s'intimidà. La pestanya «Entraide»
respon a aquesta necessitat precisa — però el catalogatge anarquista no és neutral: els
encapçalaments de matèria mainstream patologitzen, esborren, mal-anomenen. **L'entraide
transmet un *artisanat polític* que ni els estàndards ni una IA codifiquen.**

Principi transversal: **la crida d'ajuda és genèrica** (entraide sobre *qualsevol* tema
tècnic espinós), el **catalogatge és el primer domini cablejat**.

## 2. Tres graus d'entraide — una escala, per subsidiarietat

No «l'un O l'altre» sinó tres *intensitats*; la crida d'ajuda és el pivot, la
resposta pren una de les tres formes, de la més lleugera a la més feixuga:

1. **El comú de saber** (vademècums, casos, tesaurus) — zero cost, zero dependència,
   100 % entre iguals. La base durable.
2. **Mini-wizards** — guien la biblioteca perquè ho faci *ella mateixa* (autonomitzant,
   no dependent).
3. **Ajuda humana directa** (crida → resposta → possible visioconferència) — la més
   relacional, per quan el comú i el wizard no basten.

**La bucla descendent**: un cas dur resolt al grau 3 → resum → es converteix en un cas/wizard
de grau 1-2 → la propera vegada, el wizard és suficient. *El saber baixa els graus amb
el temps; la xarxa es torna més intel·ligent i autosuficient a cada episodi.*

## 3. El comú de saber — la capa d'autonomia

Tres capes, i la més profunda és **el vocabulari en si**:

- **El tesaurus, cor polític.** No una llista de paraules: un *graf de conceptes*. La
  política hi viu en els **termes**, les **relacions** (broader/narrower/related) i les
  **notes d'aplicació** (que són micro-vademècums). Construir sobre **SKOS** (estàndard
  lliure) — llegar una norma, no un bricolatge. Existeix una llavor (tesaurus ~30 categories).
- **Casos & vademècums** — exemples treballats, editables, que sorgeixen *al punt de necessitat*.
- **Wizards en *dades*, no en *codi*** — *l'aposta d'autonomia*: si un wizard és
  codi, depenem de dev per sempre; si és un **document estructurat** (arbre de
  cartes-preguntes → cartes-fi) que un motor escrit-una-vegada desplega, **qualsevol biblioteca en
  escriu un sense codificar**. Guàrdies perquè no es converteixi en un llenguatge de prog disfressat:
  sense variables/càlcul/condició lliure; únic estat = el camí recorregut; condicions
  eventuals des d'una llista tancada; **el wizard *aconsella*, no *escriu* mai** (pitjor
  fracàs = «no és útil», mai «ha trencat el catàleg»); wizards petits mono-tema.

**Multilingüe sense IA**: la carcassa i18n (10 localitzacions) porta la interfície; la *substància*
(termes, casos) s'escriu **per comunitat de llengua** (escriptura paral·lela cross-lligada, no
traducció descendent) — lent però durable i gratuït. **Governança**: addició/modificació de
terme via el flux **consentiment/objecció** dels cercles; cursor polític «variants
admeses vs convergència» a col·locar per la xarxa.

## 4. El desencadenament — al punt de necessitat (carta ③)

**El desencadenador és el *camp*, les *dades*, o la *demanda* — mai la vigilància
de la persona.** Proscriure els senyals comportamentals («5 min sobre el camp», hesitacions):
és Clippy *i* vigilància del treball. Tres desencadenadors honestos:
- **intrínsec al camp** (temes/autoritat són durs *per a tothom* → ajuda sempre present);
- **derivat de les dades** (sense ISBN, autor-a-e ambigu → el llibre assenyala, no la persona);
- **demanda explícita** («a l'ajuda» tranquil, sempre a l'abast).

L'ajuda puja **l'escala un-clic-més-lluny** (inline → wizard → cercle), **discreta però
descobrible** (posicionament fiable, mai modal/gamificada), amb una **presència en corba per
domini** (una mica més accessible si camp buit + baix nombre de registres; s'esvaeix amb la
mestria; sempre plegable a mà).

## 5. Dues pantalles ja passades per la graella

### 5.1 — El «?» sota un camp dur (catalogatge)
Present *perquè el camp és feixuc per a tothom* (cadratge dignitat, no «sembla que tens
dificultat»). En obrir-lo: suggeriments de tesaurus inline + casos del comú → «camí
guiat» (wizard) → «demanar al cercle» (grau 3, moment del consentiment).
**La graella ha eliminat dues funcionalitats temptadores**: ❌ detectar l'hesitació per proposar
l'ajuda (vigilància, faceta ③); ❌ medalles/sèries/barra cap a «expert-a-e» (faceta ⑥).
**Defectes retinguts**: filet «primera vegada? camí guiat» *oferit però en registre
d'oferta*; «?» sempre visible, suggeriments **desplegats al clic** (discret + descobrible).

### 5.2 — El tancament d'episodi + captura del comú
Tancament **iniciat per l'ajudada** (sense auto-close, sense tancament per le ajudant-a-e). Pantalla
«gràcies» sobria, **res enganxat** (desacoblament anti-deute). **Graó-ploma** «mantenir el
contacte?» simètric, ignorable, no crea res excepte doble-sí.
**Captura del comú sense deute**: s'invita le **ajudant-a-e** (deté el saber nou), no
l'ajudada; **micro-contribució enganxada a l'objecte** (nota sobre un terme/camp), **amorçada
per la traça** de l'episodi; després **l'ajudada és invitada a rellegir/enriquir** («el que era
realment difícil») — *la seva veu, declinable, mai un judici de le ajudant-a-e*, i **no
bloquejant** (la nota es manté sola).
**La graella ha eliminat**: ❌ «valora la teva experiència» (classificació dissimulada); ❌ medalla de compleció.

## 6. Confidencialitat

Les dades de catàleg són *menys* sensibles que les dades de lector-a-e (metadades sobre
*llibres*, mai d'exemplars/préstecs/identitats), **però no zero** (els fons d'una biblioteca
anar poden ser políticament sensibles; cf. la distinció `visibility_level='network'` /
BTL). Per tant:
- **opt-in per ítem** (mai un dump), **BTL/sensibles exclosos per defecte**;
- **le ajudant-a-e *proposa*, la propietària *valida*** — mai escriptura directa d'un tercer;
  accés **scopejat, revocable, auditat**;
- el graó **«demanar al cercle» ÉS el moment del consentiment** («mostraràs aquests
  ítems a la biblioteca X — aquí el que surt»);
- **el comú capta artisanat *genèric de-identificat*, no *casos* identificadors**;
  les especificitats s'eliminen o es consenten.

Resposta a la pregunta «dret absolut de delegar?»: **sí a l'autonomia, però consentiment
*informat i emmarcat*, no en blanc** — fer el risc petit i fer-lo prendre en coneixement de causa.

## 7. Aparellament & maduració en partenariat

- **Triatge suau, no filtre dur.** En una xarxa dispersa, un I (mateixa llengua I geo I disponibilitat I
  expert) = conjunt buit. Es **classifica** per afinitat (llengua ↑, fus horari ↑, voluntari ↑) sense
  **excloure**; subsidiarietat **cercle primer → xarxa si silenci**. El **cercle pertinent
  depèn del tipus d'ajuda** (catalogatge → lingüístic; material/repressió → geogràfic).
- **Primer gest sense prerequisit**: oferir-se voluntari per a *un* acte no exigeix cap cercle
  ni perfil. **La pertinença s'acreta dels gestos** (reconeixement consentit, mai etiqueta).
- **Anti-jerarquia**: sense reputació individual, sense marketplace; disponibilitat
  declarada, reciprocitat visible sense puntuació, rotació.
- **Maduració en partenariat (§21)** — *segona fase que dissol la raresa*: un bon episodi
  pot **madurar** en partenariat → l'ajuda futura és *pre-aparellada* (llengua, fus horari, consentiment
  ja donat); la xarxa es **densifica**. **Desacoblada** de l'episodi (mai en l'instant =
  deute); **après repetició** (reconeixement, no creació); **doble-opt-in simètric**;
  **escala de profunditat** (0 → mantenir-contacte → companyonia → partenariat formal);
  **inversió del deute** (el partenariat és un *regal* a l'ajudada: «una camarada a
  trucar sense re-consentir», no un deute); sempre **separable**.

## 8. El connectable de visioconferència (grau 3)

Acoblar l'ajuda humana a una **visio Jitsi** (síncrona = transmissió eficaç); vivier =
**cercle lingüístic**. **Async primer, visio en turbo opcional** (la més precària és mal
connectada → graus 0-2 en text/fora de línia).
Tècnicament, «gratuïtament»: **codificar la integració una vegada via l'iframe API amb el `domain`
en config** → mai blocat a un proveïdor. Apuntar per defecte cap a una **instància Jitsi
militant** (el més en la doctrina, gratuït, sense GAFAM); a falta `meet.jit.si` (assumint
l'auth del creador de sala). Sales **efímeres, nom no-endevinable, lobby**. **Zero
servidor, zero secret, zero cost recurrent.** L'auto-allotjat resta *pàrquing* (VPS descartat).

## 9. Cost & autonomia

Tot (comú, wizards, panells, matching, visio link-out) **funciona sobre la stack existent**
(Supabase + front estàtic): **zero cost marginal, sense IA per funcionar**. La IA resta un
**accelerador opcional i desconnectable** (pre-catalogatge del *neutre* únicament; el polític
resta entre camarades). **Els òrgans ja existeixen**: llavor de tesaurus, wizard de
descoberta, i18n 10 localitzacions, flux consentiment/objecció dels cercles, §21 partenariat. **Aquest
cadratge enllaça òrgans existents — d'aquí la seva modèstia, i la seva independència respecte al cost
i a qualsevol dependència externa.**

## 10. Decisions actades / qüestions obertes

**Actades (al llarg de la reflexió):**
- Tres graus en escala + bucla descendent del saber.
- Comú = tesaurus (SKOS, cor polític) + casos + **wizards en dades**.
- Desencadenament per camp/dada/demanda, **mai vigilància**; escala un-clic;
  presència en corba per domini.
- Pantalla «?»: defectes (oferta, suggeriments al clic); refús (detecció-hesitació, gamificació).
- Tancament: ajudada tanca; **ajudant-a-e redacta → ajudada enriqueix** (zero deute); comú = **craft
  genèric**; governança **additiu = 2 persones / vocabulari = col·lectiu**.
- Matching **triatge suau + cercle primer**; cercle **segons el tipus d'ajuda**; primer gest sense
  prerequisit; **pertinença pel gest**.
- Maduració §21 **desacoblada, après repetició, doble-opt-in, escala de profunditat, inversió
  de deute, separable**.
- Visio **Jitsi `domain` configurable**, async-first, zero infra/secret.
- (Recordatori mail, ja cablejat fora d'aquest cadratge) localització del destinatari = **la seva preferència personal**.

**Obertes (cursors polítics a col·locar per la xarxa):**
- **Nivell d'acollida inicial** (hospitalitat) i **qui el posa**: xarxa / cercle / biblioteca /
  persona. Pista: *demanar* a la nouvinguda el seu acolliment (consentiment) + subsidiarietat
  (el superior només omple el silenci) + opció *parranatge encarnat* per un-a-e voluntari del cercle.
- Nivell de **presència del graó-ploma** i de la invitació al comú (ofert vs disponible) —
  àmpliament desactivat per la **semàntica** (registre d'oferta ≠ injonció).
- Forma concreta de **l'editor de wizard-en-dades** (fins on sense convertir-se en codi).
- Cursor **variants vs convergència** del tesaurus.

## 11. Estat

Cadratge a **discutir i provar**, no una ordre de construcció. Quan un panell sigui madur,
es desglossarà en spec, i cada pantalla tornarà a la **graella de la carta relacional**.
