# Aider AnarBib sans écrire une ligne de code

*Português abaixo · English below*

Les trois chantiers les plus utiles à AnarBib aujourd'hui ne demandent aucune compétence technique. Si vous êtes arrivé·e ici par [`CONTRIBUTING.md`](CONTRIBUTING.md), vous y avez lu du `git clone` et du `npm ci` : cette page-ci est pour tout le reste.

**Ce que le projet est vraiment.** Un seul mainteneur. Un seul administrateur de réseau. Un seul serveur d'intégration continue, sur son poste de travail. Nous préférons l'écrire que le taire : la contribution qui réduit une de ces trois dépendances vaut plus qu'une fonctionnalité de plus.

Les chiffres ci-dessous ont été vérifiés en base et au dépôt le **29 août 2026**. Ils bougent — le détail à jour vit dans [`docs/backlogs/`](docs/backlogs/), sous les identifiants indiqués.

---

## Tenir un rôle d'administration du réseau — `A1`

Le réseau n'a **qu'une seule personne administratrice**. Des décisions fédérales sont volontairement différées faute de pouvoir être prises à plusieurs : l'admission d'une bibliothèque, un arbitrage entre deux fonds, l'ouverture d'un catalogue au moissonnage.

**Ce que ça demande** : de la disponibilité et de la confiance. Aucune compétence technique.
**Ce que ça apporte** : que le réseau cesse d'être suspendu à quelqu'un qui peut tomber malade. C'est le point le plus important de cette page, et le seul qu'aucun code ne réglera.

## Relire une langue — `E2`, `E4`

L'interface existe en dix langues, à parité stricte : 6 177 chaînes dans chacune, vérifiée à chaque intégration. Mais la parité compte les clés, pas leur justesse. **Le néerlandais est à l'état de brouillon, le grec reste à définir**, et l'italien ne suit pas encore sa propre convention d'écriture inclusive.

**Ce que ça demande** : être locutrice ou locuteur natif. Rien d'autre. Si git vous fait peur, on vous envoie un fichier par courriel et vous le renvoyez modifié.
**Ce que ça apporte** : deux langues qui cessent d'être des traductions approximatives.

## Indexer par matière — `C7`

**1 549 notices sur 2 676 n'ont aucun sujet.** Un catalogue à 42 % d'indexation ne se parcourt pas : il se cherche par titre, ce qui suppose de savoir déjà ce qu'on cherche. Le sujet est le seul chemin d'entrée pour qui vient voir ce qu'il y a sur une question.

**Ce que ça demande** : de la lecture attentive, depuis l'application, avec le vocabulaire commun déjà chargé.
**Ce que ça apporte** : le thésaurus étant traduit en dix langues, chaque affectation vaut simultanément pour les dix.

## Travailler les fiches d'autorité — `C3`, `C4`

Sur 1 305 autorités, **722 n'ont pas de pays renseigné** et près de la moitié n'ont pas de date. Trois listes de vérification attendent une relecture humaine, fiche par fiche — et elles attendent une relecture *humaine* : sur les doubles patronymes hispaniques repérés automatiquement, 14 % sont de faux positifs. Un script qui « finirait » ce travail introduirait des fautes dans un catalogue qui n'en a pas.

**Ce que ça demande** : de la patience documentaire et le sens du collectif. C'est l'Atelier autorités, ouvert depuis juin 2026.

## Parcourir l'application au lecteur d'écran — `E1`

Des fonctionnalités d'accessibilité sont implémentées. **Aucun audit indépendant n'a jamais été mené.** Les deux mots ne sont pas synonymes, et nous tenons à dire les deux.

**Ce que ça demande** : parcourir les chemins principaux — chercher, ouvrir une notice, réserver, s'inscrire — au lecteur d'écran ou au clavier seul, et écrire ce qui bloque.

## Éprouver la reconstruction sur une autre machine — `A2`

Cloner le dépôt sur une machine qui n'est pas celle du mainteneur, monter la pile complète en suivant [`deploy/README.md`](deploy/README.md), et écrire ce qui casse. Aucun secret, aucun accès, aucune coordination : la pile se rebâtit depuis le dépôt seul.

**Ce que ça demande** : Docker, une machine, une soirée. Aucune connaissance du projet.
**Ce que ça apporte** : la réponse à la seule question qui décide de tout le reste — *ce projet est-il reprenable par quelqu'un d'autre que celui qui l'a écrit ?* Personne ne l'a jamais vérifié. **Un rapport d'échec détaillé vaut ici plus qu'un correctif** : c'est la liste de ce qui ne marche que sur une seule machine.

## Ranger la documentation — `J5`

Le corpus est vaste et sa dérive est mesurée. Le registre qui fait foi porte deux sections numérotées `§17`, deux sections `MAP` aux verdicts opposés, et sept spécifications que plus aucun index ne référence.

**Ce que ça demande** : de la patience et le goût de l'ordre. Aucune compétence technique.
**Ce que ça apporte** : que le document censé trancher cesse de se contredire — c'est le premier que lira la personne suivante.

---

## Et si vous ne pouvez donner que de l'argent

Les frais de fonctionnement — hébergement, courriel, nom de domaine — représentent environ **36 € par mois**, sortis de la poche d'une seule personne. Soit vingt personnes à 2 €. Les comptes sont publics : [anarbib.org/fr/comptes](https://anarbib.org/fr/comptes/).

## Écrire

**contato@anarbib.org** — dites ce que vous savez faire et ce dont vous avez le temps, on vous oriente. Il n'y a pas de formulaire, pas de test d'entrée, et pas de niveau requis.

La page [anarbib.org/fr/contribuer](https://anarbib.org/fr/contribuer/) dit la même chose en plus large et sans les chiffres du jour. Pour les chantiers qui demandent du code, [`docs/CHANTIERS_OUVERTS.md`](docs/CHANTIERS_OUVERTS.md) puis [`CONTRIBUTING.md`](CONTRIBUTING.md).

---
---

# Ajudar o AnarBib sem escrever uma linha de código

Os três canteiros mais úteis ao AnarBib hoje não exigem nenhuma competência técnica. Se você chegou aqui pelo [`CONTRIBUTING.md`](CONTRIBUTING.md), leu lá `git clone` e `npm ci`: esta página é para todo o resto.

**O que o projeto realmente é.** Um único mantenedor. Um·a único·a administrador·a de rede. Um único servidor de integração contínua, na estação de trabalho dele. Preferimos escrevê-lo a calá-lo: a contribuição que reduz uma dessas três dependências vale mais que mais uma funcionalidade.

Os números abaixo foram verificados no banco e no repositório em **29 de agosto de 2026**. Eles mudam — o detalhe atualizado vive em [`docs/backlogs/`](docs/backlogs/), sob os identificadores indicados.

---

## Exercer um papel de administração da rede — `A1`

A rede tem **uma única pessoa administradora**. Decisões federais são deliberadamente adiadas por não poderem ser tomadas em conjunto: a admissão de uma biblioteca, uma arbitragem entre dois acervos, a abertura de um catálogo à coleta.

**O que exige**: disponibilidade e confiança. Nenhuma competência técnica.
**O que traz**: que a rede deixe de estar suspensa a alguém que pode adoecer. É o ponto mais importante desta página, e o único que nenhum código vai resolver.

## Revisar uma língua — `E2`, `E4`

A interface existe em dez línguas, em paridade estrita: 6 177 cadeias em cada uma, verificada a cada integração. Mas a paridade conta as chaves, não a justeza delas. **O neerlandês está em estado de rascunho, o grego resta a definir**, e o italiano ainda não segue a própria convenção de escrita inclusiva.

**O que exige**: ser falante nativo·a. Nada mais. Se o git lhe assusta, enviamos um arquivo por e-mail e você o devolve modificado.
**O que traz**: duas línguas que deixam de ser traduções aproximativas.

## Indexar por assunto — `C7`

**1 549 registros de 2 676 não têm nenhum assunto.** Um catálogo com 42 % de indexação não se percorre: busca-se por título, o que pressupõe já saber o que se procura. O assunto é o único caminho de entrada para quem vem ver o que há sobre uma questão.

**O que exige**: leitura atenta, a partir do aplicativo, com o vocabulário comum já carregado.
**O que traz**: como o tesauro está traduzido em dez línguas, cada atribuição vale simultaneamente para as dez.

## Trabalhar as fichas de autoridade — `C3`, `C4`

De 1 305 autoridades, **722 não têm país preenchido** e quase metade não tem data. Três listas de verificação esperam uma revisão humana, ficha por ficha — e esperam uma revisão *humana*: dos duplos sobrenomes hispânicos apontados automaticamente, 14 % são falsos positivos. Um script que «terminasse» esse trabalho introduziria erros num catálogo que não os tem.

**O que exige**: paciência documental e senso de coletivo. É a Oficina de autoridades, aberta desde junho de 2026.

## Percorrer o aplicativo com leitor de tela — `E1`

Funcionalidades de acessibilidade estão implementadas. **Nenhuma auditoria independente foi jamais conduzida.** As duas palavras não são sinônimas, e fazemos questão de dizer as duas.

**O que exige**: percorrer os caminhos principais — buscar, abrir um registro, reservar, cadastrar-se — com leitor de tela ou só com teclado, e escrever o que trava.

## Testar a reconstrução em outra máquina — `A2`

Clonar o repositório numa máquina que não seja a do mantenedor, subir a pilha completa seguindo [`deploy/README.md`](deploy/README.md), e escrever o que quebra. Nenhum segredo, nenhum acesso, nenhuma coordenação: a pilha se reconstrói a partir do repositório sozinho.

**O que exige**: Docker, uma máquina, uma noite. Nenhum conhecimento do projeto.
**O que traz**: a resposta à única pergunta que decide todo o resto — *este projeto é retomável por outra pessoa além de quem o escreveu?* Ninguém jamais verificou. **Um relatório de falha detalhado vale aqui mais que uma correção**: é a lista do que só funciona numa única máquina.

## Arrumar a documentação — `J5`

O corpus é vasto e sua deriva é medida. O registro que faz fé traz duas seções numeradas `§17`, duas seções `MAP` com vereditos opostos, e sete especificações que nenhum índice referencia mais.

**O que exige**: paciência e gosto pela ordem. Nenhuma competência técnica.
**O que traz**: que o documento que deveria decidir deixe de se contradizer — é o primeiro que a próxima pessoa vai ler.

---

## E se você só puder dar dinheiro

As despesas de funcionamento — hospedagem, e-mail, nome de domínio — representam cerca de **36 € por mês**, saídos do bolso de uma só pessoa. Ou seja vinte pessoas a 2 €. As contas são públicas: [anarbib.org/pt/contas](https://anarbib.org/pt/contas/).

## Escrever

**contato@anarbib.org** — diga o que você sabe fazer e de quanto tempo dispõe, a gente orienta. Não há formulário, nem teste de entrada, nem nível exigido.

A página [anarbib.org/pt/colaborar](https://anarbib.org/pt/colaborar/) diz o mesmo de forma mais ampla e sem os números do dia.

---
---

# Helping AnarBib without writing a line of code

The three most useful pieces of work on AnarBib today need no technical skill at all. If you got here from [`CONTRIBUTING.md`](CONTRIBUTING.md), you read `git clone` and `npm ci` there — this page is for everything else.

**What the project actually is.** One maintainer. One network administrator. One continuous-integration runner, on that maintainer's own workstation. We would rather write it down than hide it: a contribution that removes one of those three dependencies is worth more than one more feature.

The figures below were checked against the database and the repository on **29 August 2026**. They move — the current detail lives in [`docs/backlogs/`](docs/backlogs/), under the identifiers shown.

---

## Take on a network administrator role — `A1`

The network has **exactly one administrator**. Federation-level decisions are deliberately deferred because they cannot be taken collectively: admitting a library, arbitrating between two collections, opening a catalogue to harvesting.

**What it takes**: availability and trust. No technical skill.
**What it gives**: that the network stops hanging on one person who might fall ill. It is the most important item on this page, and the only one no code will ever fix.

## Review a language — `E2`, `E4`

The interface exists in ten languages at strict parity: 6,177 strings in each, checked on every integration. But parity counts keys, not whether they are right. **Dutch is still a draft, Greek is undecided**, and Italian does not yet follow its own inclusive-writing convention.

**What it takes**: being a native speaker. Nothing else. If git frightens you, we email you a file and you send it back edited.

## Index by subject — `C7`

**1,549 of 2,676 records have no subject at all.** A catalogue indexed at 42 % cannot be browsed: it can only be searched by title, which assumes you already know what you are looking for. Subject headings are the only way in for someone who comes to see what exists on a question.

**What it gives**: the thesaurus is translated into ten languages, so every assignment counts for all ten at once.

## Work on authority records — `C3`, `C4`

Of 1,305 authorities, **722 have no country recorded** and nearly half have no dates. Three checking lists await human review, record by record — and *human* is the word: among the Spanish double surnames flagged automatically, 14 % are false positives. A script that "finished" this work would introduce errors into a catalogue that has none.

**What it takes**: documentary patience and a sense of the collective. This is the authorities workshop, open since June 2026.

## Walk through the application with a screen reader — `E1`

Accessibility features are implemented. **No independent audit has ever been carried out.** The two are not the same word, and we make a point of saying both.

## Test a rebuild on another machine — `A2`

Clone the repository onto a machine that is not the maintainer's, bring the full stack up following [`deploy/README.md`](deploy/README.md), and write down what breaks. No secrets, no access, no coordination needed: the stack rebuilds from the repository alone.

**What it takes**: Docker, a machine, an evening. No knowledge of the project.
**What it gives**: the answer to the one question that decides everything else — *can this project be picked up by someone other than the person who wrote it?* Nobody has ever checked. **A detailed failure report is worth more here than a fix**: it is the list of what only works on one machine.

## Tidy the documentation — `J5`

The corpus is large and its drift is measured. The register that arbitrates carries two sections numbered `§17`, two `MAP` sections with opposite verdicts, and seven specifications no index references any more.

**What it takes**: patience and a taste for order. No technical skill.

---

## And if all you can give is money

Running costs — hosting, email, domain name — come to about **€36 a month**, out of one person's pocket. That is twenty people at €2. The accounts are public: [anarbib.org/en/accounts](https://anarbib.org/en/accounts/).

## Get in touch

**contato@anarbib.org** — tell us what you can do and how much time you have, and we will point you somewhere. There is no form, no entrance test and no required level.
