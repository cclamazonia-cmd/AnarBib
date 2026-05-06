<!--
  Decisões de coordenação — Biblioteca Libertária Maxwell Ferreira (BLMF)
  Copyright (c) 2026 Xavier VAN WELDEN and AnarBib contributors.

  This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
  International License (CC-BY-SA-4.0). To view a copy of this license, visit
  https://creativecommons.org/licenses/by-sa/4.0/ or see the LICENSE-docs file
  at the root of this repository.
-->

# Decisões de coordenação — BLMF — 2026-05-05

> Biblioteca Libertária Maxwell Ferreira, vinculada ao Centro de Cultura Libertária da Amazônia — CCLA, Belém do Pará.

Este documento registra as **decisões políticas de coordenação** tomadas pel(o/a/e)s coordenador(a/e)s da BLMF na operação dest(e/a) instância d(o/a/e) AnarBib. Distingue-se d(o/a/e) [registro de tratamentos](../legal/REGISTRE_TRAITEMENTS.md), que documenta o estado dos tratamentos num momento dado: aqui se consignam **as decisões e sua história**, com data, alcance e reversibilidade.

Este documento serve também como **modelo reutilizável** para as outras bibliotecas da rede RebAL: cada biblioteca aderente pode adotar o mesmo formato para registrar suas próprias decisões de coordenação, conforme o princípio de soberania local.

---

## Como ler este documento

Cada decisão é registrada como uma **seção datada** contendo:

- **Data** — quando a decisão foi tomada
- **Decisor(a/e)s** — quem validou e em qual papel d(o/a/e) coletivo
- **Modo de validação** — decisão individual, coletiva em assembleia, etc.
- **Alcance** — sobre o que recai a decisão
- **Detalhe** — o conteúdo exato da decisão
- **Reversibilidade** — condições de revisão
- **Leitura política** — justificativa breve da escolha feita

As decisões são listadas **em ordem antecronológica** (a mais recente no topo).

---

## 2026-05-05 — Validação das durações de retenção RGPD/LGPD por padrão

### Decisor

Xavier VAN WELDEN, na qualidade de coordenador da BLMF.

### Modo de validação

Decisão individual tomada no contexto da entrada em serviço inicial d(o/a/e) AnarBib, **a confirmar na próxima assembleia da BLMF** caso seja questionada. A decisão é integralmente reversível (cf. seção dedicada abaixo).

### Alcance

Configuração das durações de conservação dos dados pessoais na tabela `library_retention_policies` para a BLMF, conforme prevista pela fase 4a do canteiro RGPD/LGPD d(o/a/e) AnarBib (cf. [`REGISTRE_TRAITEMENTS.md`](../legal/REGISTRE_TRAITEMENTS.md), §2).

A tabela `library_retention_policies` cobre as **categorias de dados de uso por biblioteca** (empréstimos, reservas, consultas locais, notificações). Os dados de outro tipo (cadastros inativos, logs técnicos sistêmicos) são geridos por outros mecanismos centralizados d(o/a/e) AnarBib e não fazem parte desta decisão de coordenação local.

### Detalhe

Validação das **durações de retenção por padrão** propostas pel(o/a/e) AnarBib:

| Categoria de dados | Duração validada | Coluna em base |
|---|---|---|
| Empréstimos finalizados | **730 dias** (≈ 2 anos) | `retention_loans_days` |
| Reservas finalizadas | **365 dias** (≈ 1 ano) | `retention_reservations_days` |
| Consultas locais finalizadas | **365 dias** (≈ 1 ano) | `retention_consultations_days` |
| Notificações | **90 dias** (≈ 3 meses) | `retention_notifications_days` |

### Leitura política

- **Empréstimos com 730 dias** — permite a resolução de conflitos diferidos (livro não devolvido reclamado tardiamente pela coordenação ou pel(o/a/e) própri(o/a/e) leitor(a/e)) sem constituir um arquivo perene de histórico de leitura. Dois anos correspondem ao ciclo militante típico de um coletivo.
- **Reservas com 365 dias** — ciclo anual coerente com o ritmo dos coletivos militantes, e amplamente suficiente para um dado menos sensível que o empréstimo.
- **Consultas locais com 365 dias** — uma consulta local (leitura no espaço da biblioteca, sem empréstimo a domicílio) é menos rastreante que um empréstimo. Um ano de retenção permite à biblioteca uma visão anual dos usos dos espaços, útil para escolhas de organização militante (necessidade de mais mesas de leitura? mais espaço para crianças?). 365 dias é mais curto que os 730 dos empréstimos, coerente com a menor sensibilidade do dado.
- **Notificações com 90 dias** — três meses são amplamente suficientes para que uma notificação seja lida e tratada pela pessoa destinatária. Além desse período, conservar mensagens em base não tem utilidade operacional — apenas constitui superfície de exposição RGPD/LGPD desnecessária. 90 dias é coerente com as boas práticas no setor.

Estas durações estão **na mediana das recomendações d(o/a/e) ANPD** (Autoridade Nacional de Proteção de Dados) e da CNIL francesa para serviços análogos (gestão de adherent(e/a)s associativ(o/a/e)s, serviços de empréstimo). Não são nem permissivas (não há conservação indefinida) nem excessivamente curtas (não há apagamento imediato que impediria a gestão de litígios).

### Reversibilidade

- **Modificação** — qualquer coordenador(a/e) da BLMF pode propor uma modificação destas durações em assembleia ou por decisão individual fundamentada. A modificação é aplicada por atualização de `library_retention_policies` (UPDATE direto ou via RPC quando disponível).
- **Efeito de uma modificação** — as novas durações se aplicam **a partir da data de modificação** e não retroativamente. Um dado já apagado por purga não pode ser restaurado.
- **Efeito para as outras bibliotecas da rede** — nenhum. Estas durações são **próprias à BLMF**. Cada biblioteca aderente escolhe suas próprias durações, conforme o princípio de soberania local (cf. especificação de governança dos papéis, P7).

### Consequências técnicas

Esta decisão política desbloqueia as etapas técnicas seguintes, a executar em sequência:

1. **Inserção em base** — uma linha em `library_retention_policies` para a BLMF com os 4 valores validados (anteriormente, a BLMF se beneficiava dos valores padrão d(o/a/e) AnarBib via `fn_get_retention_policy`; a inserção explícita ancora a decisão política em base e a torna imune a eventuais mudanças dos valores padrão).
2. **Verificação** — `SELECT * FROM library_retention_policies WHERE library_id = '<uuid_blmf>';` para confirmar que os valores em base correspondem à decisão.
3. **Ativação do cron #6** (`anarbib-rgpd-notify-weekly`, notificações J-30) — `SELECT cron.alter_job(jobid := 6, active := true);` após confirmação de que os valores em base estão conformes.
4. **Manutenção desativada do cron #7** (`anarbib-rgpd-purge-weekly`, purga efetiva) — conforme o plano em escada previsto, a ativação efetiva da purga só ocorrerá após um ciclo completo de observação das notificações J-30 em condições reais.

---

## Anexo — Referências aos documentos relacionados

- [`REGISTRE_TRAITEMENTS.md`](../legal/REGISTRE_TRAITEMENTS.md) — Registro das atividades de tratamento (art. 30 RGPD + art. 37 LGPD)
- [`PROCEDURE_INCIDENT.md`](../legal/PROCEDURE_INCIDENT.md) — Procedimento de incidente de segurança (art. 33–34 RGPD)
- DPA × 6 locais (`dpa-pt-BR.md`, `dpa-fr.md`, `dpa-es.md`, `dpa-en.md`, `dpa-it.md`, `dpa-de.md`) — Políticas de confidencialidade difundidas a(o/a/e)s leitor(a/e)s
- Especificação de governança dos papéis (`docs/spec-gouvernance-roles.md`) — Cadrage político das delegações nas bibliotecas

---

## Histórico de revisão

| Data | Autor(a/e) | Modificação |
|---|---|---|
| 2026-05-05 | Xavier VAN WELDEN | Criação inicial do documento. Primeira decisão registrada: validação das durações de retenção RGPD/LGPD por padrão para a BLMF. |
| 2026-05-06 | Xavier VAN WELDEN | Retificação das categorias retidas: a decisão inicial mencionava "empréstimos / reservas / cadastros inativos / logs", mas a leitura do código de `fn_get_retention_policy` e `fn_notify_users_before_purge` mostrou que a tabela `library_retention_policies` cobre na realidade **empréstimos / reservas / consultas locais / notificações**. As 4 categorias agora alinhadas com o esquema técnico real. Os parâmetros de cadastros inativos e logs técnicos são geridos por outros mecanismos sistêmicos d(o/a/e) AnarBib, não cobertos por esta decisão de coordenação local. Os valores numéricos validados originalmente foram mantidos para empréstimos (730d) e reservas (365d); foram adicionados consultas locais (365d) e notificações (90d), validados após análise política do propósito de cada categoria. |

---

*Este documento é disponibilizado sob licença **Creative Commons Attribution-ShareAlike 4.0 International** (CC-BY-SA-4.0). Ver o arquivo [`LICENSE-docs`](../../LICENSE-docs) na raiz do repositório. As bibliotecas aderentes são explicitamente encorajadas a copiar, adaptar e republicar este documento para sua própria coordenação, desde que redistribuam suas adaptações sob a mesma licença.*
