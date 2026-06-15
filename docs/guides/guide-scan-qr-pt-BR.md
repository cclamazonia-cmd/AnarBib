# Guia — Scan e QR Code no AnarBib

> **Para quem é este guia.** Para qualquer camarada de biblioteca que queira usar
> a câmera do celular (ou do computador) para ganhar tempo: identificar uma
> pessoa leitora pela carteirinha, puxar os dados de um livro pelo código de
> barras, ou conferir o acervo. Escrito a pedido — e para o **comum** da rede.
>
> **Espírito.** Nada aqui te vigia nem te avalia. A leitura dos códigos acontece
> **100 % no teu aparelho**: nenhuma imagem da câmera sai para lugar nenhum. As
> ferramentas estão aí para te dar autonomia, não para te prender. Se algo não
> funcionar, **nunca quebra o catálogo** — no pior caso, é só digitar à mão.
>
> Parte do **comum de saber** da entraide (ver o cadrage « Entraide ao
> catalogação »). Escreve-se por comunidade de língua: se quiser uma versão noutra
> língua, ela se faz em paralelo, não por tradução de cima para baixo.

---

## O que dá para escanear

O AnarBib tem **um só leitor de câmera**, reaproveitado em três lugares:

| Onde | O que se escaneia | Para quê |
|---|---|---|
| **Painel › Leitor·a** | QR da **carteirinha** | Identificar a pessoa leitora num instante |
| **Catalogação** (ficha do livro) | **código de barras ISBN** | Puxar título/autoria automaticamente |
| **Painel › Inventário** | QR das **etiquetas de exemplar** | Conferir o acervo (recolhimento) |

Em todos os casos: a câmera abre dentro do AnarBib, lê o código, e pronto. Não é
preciso instalar nenhum aplicativo. Se quiser, dá para **adicionar o AnarBib à
tela inicial** do celular (menu do navegador › « Adicionar à tela de início »):
ele abre em tela cheia como um app, mas continua sendo o site.

---

## 1. Carteirinha de leitor·a

**Quem cria a carteirinha:** a própria pessoa leitora, na sua conta
(`/conta`), quando a biblioteca ativou o recurso. Ela gera um QR Code e pode
baixar em PNG ou PDF. O QR carrega apenas um **código opaco** — nenhum nome,
nenhum dado pessoal dentro dele.

**Como tu, no balcão, usas:**

1. Vai em **Painel › Gerir leitor·a**.
2. Clica em **« Escanear »** e aponta a câmera para o QR da carteirinha.
3. O AnarBib resolve o código e mostra **quem é** a pessoa (e se há alguma
   restrição ativa). Pronto para emprestar, devolver, etc.

> **« Carteirinha não reconhecida »?** Quase sempre é uma **carteirinha antiga**.
> Quando a pessoa gera uma carteirinha nova, a anterior é **revogada** (medida de
> segurança). Peça para ela gerar/baixar a carteirinha atual. Desde 15/06, o
> próprio sistema avisa « carteirinha substituída, gere uma nova » nesse caso.

---

## 2. Escanear o ISBN ao catalogar

Ao cadastrar um livro que tem código de barras (ISBN), dá para evitar digitar
tudo à mão:

1. Na ficha do livro (catalogação), abre o painel de **busca de metadados**.
2. Clica em **« Escanear ISBN »** e aponta para o **código de barras** na
   contracapa do livro.
3. O número entra sozinho no campo ISBN e o AnarBib **busca os dados** (título,
   autoria…) nas fontes públicas. Tu revisas e ajustas — o catálogo é teu.

> **Dica de aparelho.** Código de barras é mais « exigente » que QR. **O celular
> costuma ler muito melhor** que a webcam de um computador de mesa (foco e
> resolução da câmera). Se a webcam não pegar, não insista: digita o ISBN à mão —
> dá no mesmo.

---

## 3. Inventário do acervo (recolhimento)

Conferir, exemplar por exemplar, o que está de fato na estante — comparando com
o que o sistema acha que a biblioteca tem.

**Antes:** as etiquetas dos exemplares precisam ter **QR Code**. Imprime as
etiquetas com QR em **Catalogação › Etiquetas** (há uma opção « Incluir QR
codes »). Cada QR aponta para o exemplar.

**Fazendo o inventário:**

1. Vai em **Painel › Inventário** (visível para *librarian* e *coordenador*).
2. **« Iniciar inventário »** — abre uma sessão e mostra quantos exemplares a
   biblioteca tem.
3. A câmera fica aberta: **vai passando os exemplares**, um QR atrás do outro. A
   cada leitura há um **bip** e o contador sobe. Não precisa fechar e reabrir a
   câmera entre um livro e outro.
   - ✓ verde = exemplar do acervo, contado.
   - « Já lido » = tu já tinhas passado esse (sem problema, não conta duas vezes).
   - ⚠ « Fora do acervo » = um exemplar que **não é** desta biblioteca (intruso).
4. Se algum QR estiver danificado, dá para **digitar à mão** (URL da etiqueta ou
   o número do exemplar).
5. **« Encerrar e ver relatório »** — fecha a sessão e mostra:
   - **Presentes** (escaneados e do acervo),
   - **Faltantes** (do acervo, mas não escaneados → procurar / dar baixa),
   - **Intrusos** (escaneados, mas de outra biblioteca / desconhecidos).
6. Exporta o resultado em **CSV** (para planilha) ou **PDF** (para imprimir a
   lista de faltantes e sair caçando nas estantes).

> **Pausar e retomar.** Inventário grande? Pode encerrar depois. Se sair no meio,
> a sessão fica **em andamento** e aparece em « Sessões em andamento » para
> **retomar** de onde parou.

---

## Perguntas práticas

**Preciso instalar algo?** Não. É o próprio site. Opcionalmente, « Adicionar à
tela inicial » para abrir como app.

**Funciona no meu navegador?** Sim. No Chrome/Android usa o leitor nativo (mais
rápido). No **Brave**, **iOS/Safari** e **Firefox** o AnarBib carrega
automaticamente um leitor alternativo — então **também funciona** nesses. Se
aparecer « leitura não compatível » ao escanear ISBN num desses, atualiza a
página: o leitor alternativo entra sozinho.

**A câmera não abre.** Verifica se deste **permissão de câmera** ao site (cadeado
na barra de endereço). O navegador só libera a câmera em **HTTPS** — o
`app.anarbib.org` já é.

**Privacidade.** A decodificação é **local**. A imagem da câmera **não é enviada**
a servidor nenhum. O QR da carteirinha guarda só um código opaco; o QR da
etiqueta guarda só o endereço do exemplar. Fundos sensíveis (BTL e afins) seguem
protegidos pelas mesmas regras de sempre.

---

## Em uma frase

A câmera é uma **mão estendida** para te poupar digitação e conferência — não uma
obrigação. Usa quando ajudar; ignora quando não. E se travar, o teclado está
sempre ali.

---

*Documento do comum AnarBib. Melhorias e versões em outras línguas são
bem-vindas, escritas em paralelo pela comunidade de cada língua.*
