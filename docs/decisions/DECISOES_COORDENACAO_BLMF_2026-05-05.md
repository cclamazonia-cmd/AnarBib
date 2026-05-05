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

Este documento registra as **decisões políticas de coordenação** tomadas pel(o/a/e)s coordenador(a/e)s da BLMF na operação dest(e/a) instância d(o/a/e) AnarBib. Distingue-se d(o/a/e) [registro de tratamentos](./REGISTRE_TRAITEMENTS.md), que documenta o estado dos tratamentos num momento dado: aqui se consignam **as decisões e sua história**, com data, alcance e reversibilidade.

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

Configuração das durações de conservação dos dados pessoais na tabela `library_retention_policies` para a BLMF, conforme prevista pela fase 4a do canteiro RGPD/LGPD d(o/a/e) AnarBib (cf. [`REGISTRE_TRAITEMENTS.md`](./REGISTRE_TRAITEMENTS.md), §2).

### Detalhe

Validação das **durações de retenção por padrão** propostas pel(o/a/e) AnarBib:

| Categoria de dados | Duração validada | Referência ao registro |
|---|---|---|
| Empréstimos finalizados | **730 dias** (≈ 2 anos) | Registro §2.2 — `[À COMPLÉTER]` agora preenchido para a BLMF como 730 dias |
| Reservas finalizadas | **365 dias** (≈ 1 ano) | Registro §2.3 |
| Cadastros de leitor(a/e)s inativos | **365 dias** | Registro §2.1 — sem conexão durante esse período |
| Logs técnicos | **90 dias** (≈ 3 meses) | Registro §4.1 — logs Supabase, registros de auditoria não-pessoais |

### Leitura política

- **Empréstimos com 730 dias** — permite a resolução de conflitos diferidos (livro não devolvido reclamado tardiamente pela coordenação ou pel(o/a/e) própri(o/a/e) leitor(a/e)) sem constituir um arquivo perene de histórico de leitura. Dois anos correspondem ao ciclo militante típico de um coletivo.
- **Reservas com 365 dias** — ciclo anual coerente com o ritmo dos coletivos militantes, e amplamente suficiente para um dado menos sensível que o empréstimo.
- **Cadastros inativos com 365 dias** — duração coerente com o cron de saída automática das memberships staff (9 meses sem login, previsto pela especificação de governança dos papéis §4.5). Um(a/e) leitor(a/e) sempre pode se reinscrever após a remoção — o histórico de empréstimos é perdido, mas o cadastro pode ser recriado.
- **Logs com 90 dias** — suficiente para a depuração e para a auditoria de curto prazo, minimiza a exposição de dados técnicos que podem indiretamente identificar pessoas (timestamps de conexão, endereços IP parciais quando aplicável).

Estas durações estão **na mediana das recomendações d(o/a/e) ANPD** (Autoridade Nacional de Proteção de Dados) e da CNIL francesa para serviços análogos (gestão de adherent(e/a)s associativ(o/a/e)s, serviços de empréstimo). Não são nem permissivas (não há conservação indefinida) nem excessivamente curtas (não há apagamento imediato que impediria a gestão de litígios).

### Reversibilidade

- **Modificação** — qualquer coordenador(a/e) da BLMF pode propor uma modificação destas durações em assembleia ou por decisão individual fundamentada. A modificação é aplicada por atualização de `library_retention_policies` (RPC `fn_set_retention_policy`).
- **Efeito de uma modificação** — as novas durações se aplicam **a partir da data de modificação** e não retroativamente. Um dado já apagado por purga não pode ser restaurado.
- **Efeito para as outras bibliotecas da rede** — nenhum. Estas durações são **próprias à BLMF**. Cada biblioteca aderente escolhe suas próprias durações, conforme o princípio de soberania local (cf. especificação de governança dos papéis, P7).

### Consequências técnicas

Esta decisão política desbloqueia as etapas técnicas seguintes, a executar em sequência:

1. **Verificação** — `SELECT * FROM library_retention_policies WHERE library_id = '<uuid_blmf>';` para confirmar que os valores em base correspondem à decisão.
2. **Atualização se necessário** — caso os valores divirjam, aplicação via RPC `fn_set_retention_policy`.
3. **Ativação do cron #6** (`fn_notify_users_before_purge`, notificações J-30) — `SELECT cron.alter_job(jobid := 6, active := true);` após confirmação de que os valores em base estão conformes.
4. **Manutenção desativada do cron #7** (`fn_purge_expired_data`, purga efetiva) — conforme o plano em escada previsto, a ativação efetiva da purga só ocorrerá após um ciclo completo de observação das notificações J-30 em condições reais.

---

## Anexo — Referências aos documentos relacionados

- [`REGISTRE_TRAITEMENTS.md`](./REGISTRE_TRAITEMENTS.md) — Registro das atividades de tratamento (art. 30 RGPD + art. 37 LGPD)
- [`PROCEDURE_INCIDENT.md`](./PROCEDURE_INCIDENT.md) — Procedimento de incidente de segurança (art. 33–34 RGPD)
- DPA × 6 locais (`dpa-pt-BR.md`, `dpa-fr.md`, `dpa-es.md`, `dpa-en.md`, `dpa-it.md`, `dpa-de.md`) — Políticas de confidencialidade difundidas a(o/a/e)s leitor(a/e)s
- Especificação de governança dos papéis (`docs/spec-gouvernance-roles.md`) — Cadrage político das delegações nas bibliotecas

---

## Histórico de revisão

| Data | Autor(a/e) | Modificação |
|---|---|---|
| 2026-05-05 | Xavier VAN WELDEN | Criação inicial do documento. Primeira decisão registrada: validação das durações de retenção RGPD/LGPD por padrão para a BLMF (730/365/365/90 dias). |

---

*Este documento é disponibilizado sob licença **Creative Commons Attribution-ShareAlike 4.0 International** (CC-BY-SA-4.0). Ver o arquivo [`LICENSE-docs`](../../LICENSE-docs) na raiz do repositório. As bibliotecas aderentes são explicitamente encorajadas a copiar, adaptar e republicar este documento para sua própria coordenação, desde que redistribuam suas adaptações sob a mesma licença.*
