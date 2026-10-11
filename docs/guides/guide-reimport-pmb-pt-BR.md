# Reimportar o catálogo do PMB — a primeira reimportação

*Para a coordenação de uma biblioteca que já importou o catálogo do PMB no AnarBib e deposita uma nova exportação (H21, 11/10/2026). Testado de ponta a ponta com exportações produzidas pelo próprio PMB 8.1: `tests/sql/h21_bout_en_bout_tests.sql`.*

Uma reimportação não recria nada do que já está lá: ela **reconhece** cada registro e cada exemplar, **mostra** o que o PMB mudou desde a importação anterior e deixa a decisão com você. Nada é gravado no catálogo sem passar pela revisão do lote.

## 1. Antes de depositar

- **O mesmo PMB, a mesma fonte.** Deposite o arquivo em **Importações**, com a fonte do catálogo próprio da sua biblioteca — a da primeira importação. É por ela que o AnarBib reconhece os seus registros (o número do registro no PMB, 001) e os seus exemplares (o código de barras, 995 $f, e o identificador interno do PMB, 996 $9).
- **A exportação do PMB tal como sai.** A exportação do módulo de administração do PMB, formato **UNIMARC ISO2709**, com os exemplares. Não edite o arquivo.
- **«Este arquivo é uma exportação completa do meu catálogo».** Marque **só** se a exportação contém todos os seus exemplares, sem filtro (nem por seção, nem por status, nem por localização). Sem essa opção, nenhuma retirada é proposta. Ela não pode ser mudada depois do envio: na dúvida, não marque.

## 2. O que cada veredito mostra

**A linha** (coluna Correspondência):
- «Já importada»: o registro foi reconhecido. «Ficha que sua biblioteca não possui mais»: o registro foi reatribuído ou o seu acervo não existe mais — rejeite a linha se não quiser retomá-la.
- «Novidade»: um registro que o PMB criou depois da primeira importação.
- Um registro ausente do arquivo nunca é apagado do AnarBib.

**Os campos** («Ver o detalhe campo a campo»: o que a importação anterior tinha / o que o AnarBib tem / o que o arquivo diz):
- «Alterado só no arquivo»: «Preparar a atualização» vai retomá-lo.
- «Alterado só no AnarBib (mantido)»: a sua correção fica.
- «Conflito (sinalizado, nunca aplicado)»: alterado dos dois lados; o valor do AnarBib fica, cabe a você decidir à mão.
- «Apagado pela fonte (mostrado, nunca aplicado)»: um campo que o PMB esvaziou nunca é esvaziado no AnarBib.
- As responsabilidades alteradas são mostradas, nunca aplicadas.

**Os exemplares do arquivo**:
- «novo»: um rascunho de exemplar; «já está na biblioteca»: nada a fazer.
- «sem código de barras», «movido no PMB…», «reetiquetado no PMB…», «código retomado…»: sinalizados, **nada é alterado** — verifique e, se for preciso, corrija à mão.
- «foi para …»: o exemplar foi reatribuído a outra biblioteca da rede (lá ele mantém o código e o identificador do PMB); o AnarBib nunca o recria na sua biblioteca, não o atualiza nem o retira. Uma linha cujos exemplares já estão todos lá ou foram para outra biblioteca não traz nada: «Criar exemplar» a rejeita automaticamente.
- A cota e a nota são comparadas como os campos de um registro.

**As retiradas** («Exemplares fora do arquivo»):
- «desaparecido do arquivo»: pode ser proposto para retirada; «desaparecido mas comprometido» (emprestado, reservado, em empréstimo entre bibliotecas, em consulta): nunca é proposto; «desaparecido, um rascunho em curso»: espera o rascunho.
- Os exemplares de um registro ausente do arquivo são contados à parte, nunca propostos.
- **O limite**: mais de 10 % dos exemplares da fonte E pelo menos 20 desaparecidos — nada é proposto enquanto você não confirmar «é mesmo uma exportação completa». Assim, uma exportação truncada aparece antes de custar qualquer coisa.
- «retirado, reapareceu: suspensão»: um exemplar retirado que voltou ao PMB.

**Os registros compartilhados** com outra biblioteca nunca são reescritos por uma reimportação: cada alteração do arquivo vira uma **divergência**, que cada biblioteca que possui o registro vê na **Catalogação** («Divergências a tratar») e aplica ou descarta, campo a campo.

## 3. A ordem dos gestos

Ao abrir a importação, a comparação é calculada. Depois marque as linhas e:

1. **Criar exemplar** nas linhas «Já importada»: os exemplares «novo» viram rascunhos; uma linha que não traz nada é rejeitada automaticamente.
2. **Criar rascunhos** das «Novidade».
3. **Preparar a atualização**: um rascunho por registro que só a sua biblioteca possui, com apenas os campos alterados no arquivo; um rascunho por exemplar cuja cota ou nota mudou no arquivo.
4. **Propor as retiradas** (e as suspensões), no painel das retiradas.
5. **Rejeitar** o que você não retoma.

Todos esses rascunhos vão para **um só lote**, o da importação. Depois peça a revisão dele.

## 4. O que passa pela revisão

Tudo: os registros novos e os seus exemplares, os exemplares acrescentados, as atualizações de registros e de exemplares, as retiradas e as suspensões. A administração da rede aprova; você publica o lote. O relatório de revisão diz o que é aplicado, o que é só mostrado, os exemplares deixados de lado e por quê, os desaparecidos comprometidos e o limite.

## 5. O que nunca é automático

- Nenhum registro, nenhum exemplar é **apagado**: uma retirada («fora do catálogo de origem») é reversível e passa pela revisão.
- Nenhum **conflito** é sobrescrito; nenhum apagamento, nenhuma responsabilidade é aplicada.
- Um registro **compartilhado** nunca é reescrito.
- Um exemplar **emprestado, reservado ou em consulta** nunca é proposto para retirada; a circulação nunca é tocada.
- Um exemplar **movido, reetiquetado, sem código ou com código retomado** nunca é modificado.
- Um exemplar **que foi para outra biblioteca** nunca é recriado na sua.
- Reimportar o mesmo arquivo uma segunda vez não cria nada de novo: só voltam os sinais já vistos.

A versão em francês: [guide-reimport-pmb-fr.md](guide-reimport-pmb-fr.md).
