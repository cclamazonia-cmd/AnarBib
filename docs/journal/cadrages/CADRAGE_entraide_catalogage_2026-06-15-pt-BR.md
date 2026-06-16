# Enquadramento — Ajuda mútua na catalogação (aba « Ajuda mútua » da Federação)

**Data** : 2026-06-15
**Estatuto** : **enquadramento / projeto** — reflexão exploratória que estabelece a *visão*,
a *arquitetura* e as *decisões de princípio*. **Ainda não é uma spec a
construir**: a discutir, testar e depois desdobrar em specs.
**Base ética** : [`notes-audit/anarbib-charte-relationnelle-v0.1.md`](../../../notes-audit/anarbib-charte-relationnelle-v0.1.md)
(« a mão estendida »). **Cada tela abaixo foi submetida à grade « isso estende ou
agarra? ».** Este enquadramento é, de certa forma, o primeiro teste concreto da carta.

---

## 1. A necessidade

A catalogação é o ponto de dor das bibliotecas iniciantes (cf. os canteiros de
autoridades, indexação de assunto, wizard de descoberta). Uma biblioteca sozinha diante das
autoridades, dos assuntos e da classificação fica intimidada. A aba « Ajuda mútua »
responde a essa necessidade precisa — mas a catalogação anarquista não é neutra: os
descritores de assunto convencionais patologizam, apagam, mal-nomeiam. **A ajuda mútua
transmite um *artesanato político* que nem os padrões nem uma IA codificam.**

Princípio transversal: **o pedido de ajuda é genérico** (ajuda mútua em *todo* assunto
técnico espinhoso), a **catalogação é o primeiro domínio implementado**.

## 2. Três graus de ajuda mútua — uma escala, por subsidiariedade

Não « um OU outro » mas três *intensidades*; o pedido de ajuda é o pivô, a
resposta toma uma das três formas, da mais leve à mais pesada:

1. **O comum de saber** (vademecums, casos, thesaurus) — custo zero, dependência zero,
   100 % entre pares. A base durável.
2. **Mini-wizards** — guiam a biblioteca para que ela faça *ela mesma* (autonomizante,
   não dependente).
3. **Ajuda humana direta** (chamada → resposta → eventual videoconferência) — a mais
   relacional, para quando o comum e o wizard não bastam.

**A boucle descendante**: um caso difícil resolvido no grau 3 → resumido → torna-se um caso/wizard
de grau 1-2 → da próxima vez, o wizard basta. *O saber desce os graus com
o tempo; a rede se torna mais inteligente e mais autossuficiente a cada episódio.*

## 3. O comum de saber — a camada de autonomia

Três camadas, e a mais profunda é **o próprio vocabulário**:

- **O thesaurus, cerne político.** Não uma lista de palavras: um *grafo de conceitos*. A
  política vive ali nos **termos**, nas **relações** (broader/narrower/related) e nas
  **notas de aplicação** (que são micro-vademecums). Construir sobre **SKOS** (padrão
  livre) — legar uma norma, não um improviso. Uma semente existe (thesaurus ~30 categorias).
- **Casos & vademecums** — exemplos trabalhados, editáveis, surgindo *no ponto de necessidade*.
- **Wizards em *dados*, não em *código*** — *a aposta de autonomia*: se um wizard é
  código, dependemos de dev para sempre; se ele é um **documento estruturado** (árvore de
  cartões-perguntas → cartões-fim) que um motor escrito-uma-vez desenrola, **toda biblioteca
  escreve um sem programar**. Salvaguardas para que não se torne uma linguagem de programação disfarçada:
  sem variáveis/cálculo/condição livre; único estado = o caminho percorrido; condições
  eventuais a partir de uma lista fechada; **o wizard *aconselha*, nunca *escreve*** (pior
  falha = « não foi útil », nunca « quebrou o catálogo ») ; wizards pequenos de assunto único.

**Multilíngue sem IA**: a estrutura i18n (10 locales) carrega a interface; a *substância*
(termos, casos) se escreve **por comunidade de língua** (escrita paralela cross-linked, não
tradução descendente) — lento mas durável e gratuito. **Governança**: adição/modificação de
termo via o fluxo **consentimento/objeção** dos círculos; cursores políticos « variantes
admitidas vs convergência » a definir pela rede.

## 4. O acionamento — no ponto de necessidade (carta ③)

**O gatilho é o *campo*, o *dado*, ou a *demanda* — jamais a vigilância
da pessoa.** Banir os sinais comportamentais (« 5 min no campo », hesitações):
isso é Clippy *e* vigilância do trabalho. Três gatilhos honestos:
- **intrínseco ao campo** (assuntos/autoridade são difíceis *para tod(o/a/e)s* → ajuda sempre presente);
- **derivado do dado** (sem ISBN, autor(a/e) ambígu(o/a/e) → o livro sinaliza, não a pessoa);
- **demanda explícita** (« socorro » calmo, sempre ao alcance).

A ajuda sobe **a escala um-clique-mais-longe** (inline → wizard → círculo), **discreta mas
descobrível** (posicionamento confiável, nunca modal/gamificado), com uma **presença em curva por
domínio** (um pouco mais acolhedora se campo vazio + baixo número de registros; se apaga com a
maestria; sempre recolhível manualmente).

## 5. Duas telas já submetidas à grade

### 5.1 — O « ? » sob um campo difícil (catalogação)
Presente *porque o campo é difícil para tod(o/a/e)s* (enquadramento de dignidade, não « você parece estar
com dificuldade »). Ao abri-lo: sugestões de thesaurus inline + casos do comum → « caminho
guiado » (wizard) → « pedir ao círculo » (grau 3, momento do consentimento).
**A grade eliminou duas features tentadoras**: ❌ detectar a hesitação para propor
ajuda (vigilância, faceta ③); ❌ medalhas/sequências/barra rumo a « expert(a/e) » (faceta ⑥).
**Padrões adotados**: filete « primeira vez? caminho guiado » *oferecido mas em registro
de oferta*; « ? » sempre visível, sugestões **exibidas ao clicar** (discreto + descobrível).

### 5.2 — O encerramento de episódio + captura do comum
Encerramento **iniciado pela pessoa que recebeu ajuda** (sem auto-fechamento, sem fechamento pel(o/a/e) auxiliador(a/e)). Tela
« obrigada » sóbria, **nada enganchado** (desacoplamento anti-dívida). **Barreau-plume** « manter
contato? » simétrico, ignorável, não cria nada além de duplo-sim.
**Captura do comum sem dívida**: convida-se o(a/e) **auxiliador(a/e)** (detém o saber novo), não
a pessoa auxiliada; **micro-contribuição ancorada ao objeto** (nota sobre um termo/campo), **iniciada
pela trilha** do episódio; depois a **pessoa auxiliada é convidada a reler/enriquecer** (« o que era
realmente difícil ») — *sua voz, declinável, nunca um julgamento d(o/a/e) auxiliador(a/e)*, e **não
bloqueante** (a nota vale por si só).
**A grade eliminou**: ❌ « avalie sua experiência » (classificação disfarçada); ❌ medalha de conclusão.

## 6. Confidencialidade

O dado de catálogo é *menos* sensível do que o dado d(o/a/e) leitor(a/e) (metadados sobre
*livros*, nunca exemplares/empréstimos/identidades), **mas não é nulo** (os fundos de uma biblioteca
anarquista podem ser politicamente sensíveis; cf. a distinção `visibility_level='network'` /
BTL). Portanto:
- **opt-in por item** (nunca um dump), **BTL/sensíveis excluídos por padrão**;
- **o(a/e) auxiliador(a/e) *propõe*, a proprietária *valida*** — jamais escrita direta de terceiro(a/e);
  acesso **escopado, revogável, auditado**;
- o patamar **« pedir ao círculo » É o momento do consentimento** (« você vai mostrar esses
  itens à biblioteca X — veja o que vai ser exibido »);
- **o comum captura artesanato *genérico desidentificado*, não *casos* identificadores**;
  as especificidades são removidas ou consentidas.

Resposta à pergunta « direito absoluto de delegar? »: **sim à autonomia, mas consentimento
*esclarecido e delimitado*, não carta branca** — tornar o risco pequeno e fazê-lo assumir com
conhecimento de causa.

## 7. Emparelhamento & maturação em parceria

- **Triagem suave, não filtro duro.** Em uma rede dispersa, um E (mesma língua E geo E disponibilidade E
  expert) = conjunto vazio. **Classifica-se** por afinidade (língua ↑, fuso ↑, voluntári(o/a/e) ↑) sem
  **excluir**; subsidiariedade **círculo primeiro → rede se silêncio**. O **círculo pertinente
  depende do tipo de ajuda** (catalogação → linguístico; material/repressão → geográfico).
- **Primeiro gesto sem pré-requisito**: oferecer-se para *um* ato não exige nenhum círculo
  nem perfil. **O pertencimento se acumula pelos gestos** (reconhecimento consentido, nunca rótulo).
- **Anti-hierarquia**: sem reputação individual, sem marketplace; disponibilidade
  declarada, reciprocidade visível sem pontuação, rotação.
- **Maturação em parceria (§21)** — *segunda fase que dissolve a escassez*: um bom episódio
  pode **maturar** em parceria → a ajuda futura é *pré-emparelhada* (língua, fuso, consentimento
  já dado); a rede se **adensa**. **Desacoplado** do episódio (nunca no instante = dívida);
  **após repetição** (reconhecimento, não criação); **double-opt-in simétrico**;
  **escala de profundidade** (0 → manter-contato → companheirismo → parceria formal);
  **inversão da dívida** (a parceria é um *presente* para quem recebeu ajuda: « uma camarada a
  chamar sem re-consentir », não uma dívida); sempre **rescindível**.

## 8. O plugin de videoconferência (grau 3)

Acoplar a ajuda humana a uma **videoconferência Jitsi** (síncrono = transmissão eficaz); viveiro =
**círculo linguístico**. **Async primeiro, visio como turbo opcional** (a mais precária está mal
conectada → graus 0-2 em texto/offline).
Técnica, « de graça »: **codificar a integração uma vez via a iframe API com o `domain`
em config** → nunca travado num único provedor. Apontar por padrão para uma **instância Jitsi
militante** (o mais alinhado à doutrina, gratuito, sem GAFAM); em seu defeito `meet.jit.si` (assumindo
a autenticação d(o/a/e) criador(a/e) de sala). Salas **efêmeras, nome não-adivinhável, lobby**. **Zero
servidor, zero segredo, zero custo recorrente.** O auto-hospedado permanece *parking* (VPS descartado).

## 9. Custo & autonomia

Tudo (comum, wizards, painéis, matching, link de visio) **roda na stack existente**
(Supabase + front estático): **zero custo marginal, sem IA para funcionar**. A IA permanece um
**acelerador opcional e desligável** (pré-catalogação do *neutro* apenas; o político
fica entre camaradas). **Os órgãos já existem**: semente de thesaurus, wizard de
descoberta, i18n 10 locales, fluxo consentimento/objeção dos círculos, §21 parceria. **Este
enquadramento conecta órgãos existentes — daí sua modéstia, e sua independência em relação ao custo
e a qualquer dependência externa.**

## 10. Decisões tomadas / questões abertas

**Tomadas (ao longo da reflexão):**
- Três graus em escala + boucle descendante do saber.
- Comum = thesaurus (SKOS, cerne político) + casos + **wizards em dados**.
- Acionamento por campo/dado/demanda, **jamais vigilância**; escala um-clique;
  presença em curva por domínio.
- Tela « ? »: padrões (oferta, sugestões ao clicar); recusas (detecção-hesitação, gamificação).
- Encerramento: pessoa auxiliada encerra; **auxiliador(a/e) redige → pessoa auxiliada enriquece** (zero dívida); comum = **craft
  genérico**; governança **aditivo = 2 pessoas / vocabulário = coletivo**.
- Matching **triagem suave + círculo primeiro**; círculo **segundo o tipo de ajuda**; primeiro gesto sem
  pré-requisito; **pertencimento pelo gesto**.
- Maturação §21 **desacoplada, após repetição, double-opt-in, escala de profundidade, inversão
  de dívida, rescindível**.
- Visio **Jitsi `domain` configurável**, async-first, zero infra/segredo.
- (Lembrete e-mail, já implementado fora deste enquadramento) locale da pessoa destinatária = **sua preferência pessoal**.

**Abertas (cursores políticos a definir pela rede):**
- **Nível de acolhimento inicial** (hospitalidade) e **quem o define**: rede / círculo / biblioteca /
  pessoa. Pista: *perguntar* à recém-chegada seu acolhimento (consentimento) + subsidiariedade
  (o alto só preenche o silêncio) + opção de *apadrinhamento encarnado* por um(a/e) voluntári(o/a/e) do círculo.
- Nível de **presença do barreau-plume** e do convite ao comum (oferecido vs disponível) —
  amplamente desarmado pela **semântica** (registro de oferta ≠ injunção).
- Forma concreta do **editor de wizard-em-dados** (até onde sem se tornar código).
- Cursor **variantes vs convergência** do thesaurus.

## 11. Estatuto

Enquadramento a **discutir e testar**, não uma ordem de construção. Quando um aspecto estiver maduro, ele
se desdobrará em spec, e cada tela será submetida novamente à **grade da carta relacional**.
