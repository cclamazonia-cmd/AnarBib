<!--
  Estatuto da instância BTL na base AnarBib (parceria de teste)
  Copyright (c) 2026 Xavier VAN WELDEN and AnarBib contributors.

  This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
  International License (CC-BY-SA-4.0). To view a copy of this license, visit
  https://creativecommons.org/licenses/by-sa/4.0/ or see the LICENSE-docs file
  at the root of this repository.
-->

# Estatuto da instância BTL na base AnarBib — 2026-05-06

> Documento d(o/a/e) responsável técnic(o/a/e) d(o/a/e) AnarBib sobre a presença da Biblioteca Terra Livre na base de dados em modo de **parceria de teste**.

---

## A Biblioteca Terra Livre

A **Biblioteca Terra Livre** é um centro de documentação anarquista situado em São Paulo, Brasil, ativo desde **31 de maio de 2010**. Ela é o prolongamento documental do **Coletivo Anarquista Terra Livre**, fundado em 2004. A Biblioteca conta atualmente com mais de 3500 livros, centenas de revistas, jornais, cartazes, panfletos, fanzines, filmes e materiais audiovisuais. Ela organiza a Feira Anarquista de São Paulo desde 2006, mantém um trabalho editorial desde 2011, publica uma revista semestral, produz o podcast Antinomia desde 2019, e mantém uma livraria virtual.

A Biblioteca Terra Livre é autofinanciada e autogestionária, sem subsídio nem apoio institucional do Estado ou de empresas privadas. Seu modo de funcionamento — solidário, militante, libertário — é exatamente aquele para o qual o(a/e) AnarBib foi concebid(o/a/e).

Para mais informações sobre o coletivo: contato pel(o/a/e) e-mail `bibliotecaterralivre@gmail.com`.

---

## Estatuto atual da instância na base AnarBib

A entidade `Biblioteca Terra Livre` (slug `btl`) presente na tabela `public.libraries` d(o/a/e) AnarBib **não constitui ainda uma adesão formal da Biblioteca Terra Livre à rede AnarBib**. Ela representa uma fase de **parceria de teste** entre Xavier VAN WELDEN (responsável técnic(o/a/e) d(o/a/e) AnarBib) e a Biblioteca Terra Livre, com os seguintes objetivos:

- Validar o comportamento d(o/a/e) AnarBib quando opera com **mais de uma biblioteca ativa** (cenário multi-tenant), antes de qualquer abertura de rede a outras biblios
- Permitir à Biblioteca Terra Livre **avaliar concretamente** se o(a/e) AnarBib responde às necessidades de um centro de documentação militante de seu porte
- Detectar bugs ou incoerências que só apareceriam em condições reais de uso por um coletivo realmente ativo
- Fornecer um terreno comum de discussão para que a Biblioteca Terra Livre, se ela o desejar, decida em assembleia se ela adere à rede ou não

Esta fase de parceria de teste se desenrola **antes** que o processo formal de adesão à rede AnarBib seja estabilizado. Trata-se portanto de uma fase precoce, exploratória e mutuamente consentida.

---

## Consequências do estatuto

### Quanto aos parâmetros aplicados pel(o/a/e) AnarBib

- **Retenção RGPD/LGPD** — a BTL não tem linha em `library_retention_policies`. Ela se beneficia dos valores padrão d(o/a/e) AnarBib codificados em `fn_get_retention_policy` (730/365/365/90 dias). Esta escolha é deliberada: enquanto a Biblioteca Terra Livre não tiver formalmente decidido em assembleia interna sua própria política de retenção, nenhum valor específico deve ser inscrito em base no nome dela.
- **Cron #6 (notificações J-30)** — quando ativado em 2026-05-06, o cron iterará sobre todas as bibliotecas ativas, incluindo a BTL. Devido à juventude da instância (uso recente), nenhuma notificação é esperada nos próximos meses (nenhum dado é antigo o suficiente para se aproximar do limite de retenção).
- **Cron #7 (purga efetiva)** — desativado conforme o plano em escada d(o/a/e) AnarBib. **Antes da ativação eventual do cron #7, a situação da BTL deverá ser reavaliada explicitamente**: ou bem a Biblioteca Terra Livre terá decidido em assembleia aderir à rede (e seu próprio coordenador(a/e) inscreverá então a política de retenção da biblioteca), ou bem a fase de parceria de teste estará encerrada e a instância terá sido tratada conforme uma das trajetórias abaixo.

### Quanto à governança

- A BTL **não tem coordenador(a/e) atribuíd(o/a/e)** na base AnarBib durante esta fase de teste. As decisões técnicas que afetam a instância BTL são tomadas pel(o/a/e) responsável técnic(o/a/e) d(o/a/e) AnarBib, em diálogo com a Biblioteca Terra Livre quando isso for relevante para o teste.
- Este documento **não pretende em momento algum representar a posição política da Biblioteca Terra Livre**. As decisões políticas internas à Biblioteca Terra Livre lhe pertencem integralmente. Este documento descreve o estatuto **da instância na base AnarBib**, não o estatuto do coletivo.

---

## Trajetórias de saída do estatuto transitório

A fase de parceria de teste é **temporária por definição**. Sua saída pode tomar duas formas, cuja escolha pertence à Biblioteca Terra Livre:

### Trajetória 1 — Adesão à rede AnarBib

Se, ao término da fase de teste, a Biblioteca Terra Livre decide em assembleia interna aderir à rede AnarBib, a adesão se fará pelo **processo de adesão padrão** (a definir definitivamente d(o/a/e) AnarBib): designação de coordenador(a/e)s pela assembleia da Biblioteca, validação do regimento interno, etc.

A passagem da fase de teste à adesão formal implicará, **a critério da Biblioteca Terra Livre**, uma das seguintes opções:

- **Opção A** — Manutenção dos dados gerados durante o teste se a Biblioteca Terra Livre os considera como representativos de seu acervo real e desejar conservá-los
- **Opção B** — Reset completo dos dados de teste e início de uma instância limpa para a adesão formal

A escolha entre A e B pertence integralmente à Biblioteca Terra Livre.

### Trajetória 2 — Não-adesão

Se, ao término da fase de teste, a Biblioteca Terra Livre decide não aderir à rede AnarBib (qualquer que seja a razão: incompatibilidade técnica detectada, escolhas políticas divergentes, projeto evolutivo no qual o(a/e) AnarBib não se inscreve, etc.), a instância BTL será retirada da base AnarBib após acordo com a Biblioteca. Os eventuais dados que a Biblioteca queira conservar lhe serão entregues sob forma exportável antes da supressão. Nenhuma transferência de dados de teste para uma biblioteca terceira é prevista nem autorizada.

Esta trajetória **não constitui um fracasso**: o teste em parceria terá produzido conhecimento útil para todas as partes, e a Biblioteca Terra Livre permanecerá em sua existência autônoma fora d(o/a/e) AnarBib, exatamente como antes do teste.

---

## Traços técnicos

A presença e o estatuto da BTL são tracejados em dois lugares:

1. **Documental** — este documento (`docs/journal/arbitrages/DECISOES_COORDENACAO_BTL_2026-05-06.md`)
2. **Técnico** — coluna `admin_notes` da tabela `public.libraries`, onde uma anotação foi inscrita em 2026-05-06 referenciando este documento

---

## Histórico de revisão

| Data | Autor(a/e) | Modificação |
|---|---|---|
| 2026-05-06 | Xavier VAN WELDEN | Criação inicial do documento. Acta o estatuto de parceria de teste entre o(a/e) AnarBib e a Biblioteca Terra Livre, paralelamente à ativação do cron #6 que itera sobre todas as bibliotecas ativas, incluindo a BTL. |

---

*Este documento é disponibilizado sob licença **Creative Commons Attribution-ShareAlike 4.0 International** (CC-BY-SA-4.0). Ver o arquivo [`LICENSE-docs`](../../LICENSE-docs) na raiz do repositório.*
