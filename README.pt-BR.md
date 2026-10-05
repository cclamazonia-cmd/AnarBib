# AnarBib

[Français](README.md) · [English](README.en.md) · **Português**

O AnarBib é um software livre para fazer viver bibliotecas anarquistas e libertárias: catalogar um acervo, emprestar livros, abrir documentos à leitura e ligar as bibliotecas entre si numa rede federada, sem centro nem dono.

- **O aplicativo**: [app.anarbib.org](https://app.anarbib.org)
- **O site do projeto**: [anarbib.org](https://anarbib.org)
- **O código**: [codeberg.org/anarbib/anarbib](https://codeberg.org/anarbib/anarbib)
- **Escreva para nós**: anarbib@proton.me

---

## Por que mais uma ferramenta

Já existem softwares livres de biblioteca — PMB, Koha. O AnarBib só faz sentido se fizer outra coisa: uma ferramenta pensada a partir das práticas do movimento libertário, em que **as escolhas políticas vêm antes das escolhas técnicas**, e em que uma técnica que contradiga esses princípios tem de ceder. Sem purismo, porém: entre dois princípios que se contradizem na prática, o projeto escolhe o que é possível fazer em vez de não fazer nada.

Na prática, isso significa:

- **Cada biblioteca decide por si.** Como cataloga, empresta, se abre para a rede e se organiza: são configurações que ela escolhe, não regras impostas de cima.
- **As decisões comuns são tomadas em conjunto.** Cooptar alguém para a administração da rede, confiar a coordenação de uma biblioteca: a ferramenta faz disso atos coletivos, não decisões de uma só pessoa.
- **Uma rede sem centro.** Os catálogos são compartilhados por um protocolo aberto (OAI-PMH); cada biblioteca mantém o controle do que publica.
- **Sem rastreamento.** Nenhum rastreador, publicitário ou estatístico; o anti-robô e o mapa de fundo são servidos pela infraestrutura do próprio projeto, sem chamada a serviço externo.
- **Um vocabulário comum, não apropriado.** A indexação por assunto se apoia no [tesauro compartilhado da FICEDL](https://thesaurus.ficedl.info), cujos termos o AnarBib retoma sem nunca reescrevê-los.
- **Dez idiomas, escrita inclusiva.** A interface existe em português do Brasil, francês, espanhol, inglês, italiano, alemão, catalão, esperanto, holandês e grego, segundo uma [carta de linguagem inclusiva](docs/notes-audit/anarbib-charte-langage-inclusif-v2.md) própria de cada idioma.

## Quem usa

Em 5 de outubro de 2026, três bibliotecas têm seu catálogo aberto ao público no AnarBib:

- a **Biblioteca Terra Livre**;
- a **Biblioteca Libertária Maxwell Ferreira**, mantida pelo Centro de Cultura Libertária da Amazônia (CCLA), em Belém do Pará;
- a **Maloca Libertária / Biblioteca Emma Goldman**.

Outras duas preparam sua chegada: a **Bibliothèque Solidaires** (Paris) e o **Anarchief.Org**.

## O que o aplicativo faz

- **Um catálogo público** que se percorre por obra, por autor(a/e), por assunto ou por biblioteca, com um mapa da rede.
- **A catalogação**: registros, fichas de autoridade, assuntos, exemplares; importação e exportação de catálogos (inclusive arquivos do PMB) para que nenhuma biblioteca fique presa à ferramenta.
- **A circulação**: empréstimos, reservas, consultas no local, empréstimo entre bibliotecas.
- **O digital**: leitura on-line de documentos, aberta ao público ou reservada a quem é membro, conforme os direitos de cada obra.
- **As ferramentas da rede**: bens comuns, ajuda mútua, diretório de coletivos, assembleias e uma gazeta mensal.

## Participar, ajudar

- **Uma biblioteca quer entrar na rede?** O pedido é feito pelo aplicativo ([app.anarbib.org/solicitar-biblioteca](https://app.anarbib.org/solicitar-biblioteca)) ou escrevendo para anarbib@proton.me. Nenhuma exigência técnica: primeiro a gente conversa.
- **Ajudar sem escrever código** — revisar um idioma, indexar por assunto, assumir um papel na rede, testar a instalação: o [`AIDER.md`](AIDER.md) diz o que é mais útil hoje.
- **Apoiar os custos** (hospedagem, e-mail, nome de domínio): as contas são públicas em [anarbib.org](https://anarbib.org).
- **Contribuir com o código**: [`CONTRIBUTING.md`](CONTRIBUTING.md), depois [`docs/CHANTIERS_OUVERTS.md`](docs/CHANTIERS_OUVERTS.md).

## Um projeto frágil, e que diz isso

Hoje o AnarBib depende de muito poucas mãos: uma só pessoa que mantém o código, uma só que administra a rede e um único servidor de integração contínua, num computador de trabalho. Preferimos escrever isso a calar: toda ajuda que reduza uma dessas dependências vale mais do que uma funcionalidade a mais.

**Sobre o uso de IA** *(situação em 5 de outubro de 2026)*. O AnarBib é desenvolvido com a assistência de um modelo de linguagem, e dizemos isso em vez de deixar que adivinhem. Foi essa assistência que permitiu à ferramenta existir, levada por uma pessoa sem formação em desenvolvimento; em troca, ela cria uma dependência que o projeto busca reduzir: documentando o funcionamento em vez do código, mantendo a técnica o mais simples possível e abrindo o desenvolvimento a outras mãos. As decisões continuam humanas e coletivas; ficam escritas no [registro de decisões](docs/specs/REGISTRE_decisions.md). No aplicativo, três funções recorrem a um modelo de linguagem: a preparação e a tradução da gazeta da rede, e uma pré-tradução dos títulos de obras — sempre marcada como "a revisar" e que nunca sobrescreve um título digitado à mão. Nem a circulação, nem os dados de leitor(a/e)s dependem disso.

## Para desenvolver

O AnarBib é um aplicativo web (React e Vite) apoiado no Supabase (PostgreSQL e funções Deno).

**Instalar uma cópia completa em casa**, com um só comando (requer Docker):

```bash
./install.sh
```

O instalador fala os dez idiomas do projeto; os detalhes estão em [`deploy/README.md`](deploy/README.md).

**Rodar os testes**:

```bash
npm test
```

**Onde encontrar o quê**:

- [`CONTRIBUTING.md`](CONTRIBUTING.md) — como começar, o ritmo de trabalho, o que ler antes de mexer no código.
- [`docs/INDEX.md`](docs/INDEX.md) — o mapa da documentação (especificações, guias, manuais em dez idiomas).
- [`docs/specs/REGISTRE_decisions.md`](docs/specs/REGISTRE_decisions.md) — o registro de decisões, que é a referência.
- [`docs/backlogs/`](docs/backlogs/INDEX.md) — o que está em andamento, o que falta fazer e os números do projeto, datados.

O repositório de referência está no Codeberg; cada envio para a branch `main` dispara ali a integração contínua (testes, depois implantação). O espelho no GitHub não é mais sincronizado. A maior parte da documentação do projeto está escrita em francês.

## Licenças

- **O código** está sob a [GNU AGPL v3](LICENSE): quem colocar on-line uma versão modificada deve publicar as modificações sob a mesma licença.
- **A documentação** está sob a [Creative Commons BY-SA 4.0](LICENSE-docs).

As bibliotecas são incentivadas a retomar, adaptar, traduzir e republicar um e outra, desde que compartilhem suas adaptações sob as mesmas licenças.

---

*Este README não traz, de propósito, nenhum número que envelheça rápido: eles vivem, datados, no [backlog](docs/backlogs/INDEX.md). A versão anterior, mais técnica, está arquivada em [`docs/archive/README-2026-08-30.md`](docs/archive/README-2026-08-30.md).*
