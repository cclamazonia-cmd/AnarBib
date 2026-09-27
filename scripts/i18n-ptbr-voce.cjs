/* ===========================================================================
 * i18n-ptbr-voce.cjs
 * DOC-ADDR-1 (« você en pt-BR ») — relevé le 27/09/2026 pendant B29 :
 * 102 valeurs de pt-BR.json s'adressaient au membre au « tu » EUROPÉEN —
 * « Podes ajustar », « Conecta-te com teu e-mail », « Receberás um e-mail »,
 * « Vossa decisão é decisiva », impératifs « Verifica », « Clica »,
 * « Confere »… — dans l'inscription, la lettre, l'entraide, la Fractale, le
 * formulaire « Relatar », les étapes du régime de circulation, les erreurs
 * de catalogage. Toutes réécrites au « você » brésilien (possessifs
 * seu/sua, impératifs « verifique », « clique », « confira », pronoms
 * « a você » au lieu de « te »), sens et placeholders inchangés.
 *
 * Réécriture DE → PARA : une clé n'est réécrite que si elle porte encore
 * EXACTEMENT l'ancienne valeur. Rejouable sans risque : une clé déjà au
 * « você », ou corrigée depuis par une locutrice, n'est pas touchée ; elle
 * est signalée si elle ne vaut ni l'une ni l'autre.
 *
 * Les scripts d'origine (i18n-add-*.cjs & co, tous « ajout si absent ») sont
 * corrigés dans le même commit : rejoués sur une base vierge, ils posent
 * directement la valeur au « você ». Les 102 clés n'avaient pas toutes une
 * source — 56 n'existent que dans les locales.
 *
 * Vocabulaire européen corrigé seulement dans les phrases réécrites (« ecrã »,
 * « separador », « Enviámos », « rastreio », « partilhada ») ; « ficheiro »
 * reste dans importacoes.export.attach.desc pour ne pas dépareiller l'écran
 * Exportação, qui l'emploie partout — chantier à part.
 *
 * Laissée de côté exprès : catalogacao.queue.emptyTrashConfirm (« escolhe um
 * lote »), que B29 réécrit au « você » avec son nouveau sens.
 *
 * La garde : src/tests/i18n-ecriture.test.js, chemin (4), motif TU_EUROPEU.
 * Usage : node scripts/i18n-ptbr-voce.cjs
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const FICHIER = path.join(__dirname, '..', 'src', 'i18n', 'locales', 'pt-BR.json');

// clé : [valeur au « tu » européen, valeur au « você »]
const DE_PARA = {
  'account.declared.hint': [
    'Você indicou esta biblioteca ao criar sua conta. Se ela um dia entrar no AnarBib, poderemos te propor um vínculo como leitor-a-e. O que a coordenação vê depende do que você aceitou:',
    'Você indicou esta biblioteca ao criar sua conta. Se ela um dia entrar no AnarBib, poderemos propor a você um vínculo como leitor-a-e. O que a coordenação vê depende do que você aceitou:',
  ],
  'account.notifPrefs.alwaysActive': [
    'Sempre ativas: decisões coletivas que te dizem respeito, alertas RGPD, restrições e exclusões. Estas notificações não são desativáveis porque tocam aos teus direitos.',
    'Sempre ativas: decisões coletivas que dizem respeito a você, alertas RGPD, restrições e exclusões. Estas notificações não são desativáveis porque tocam nos seus direitos.',
  ],
  'account.notifPrefs.intro': [
    'Podes ajustar as notificações que recebes neste app, dentro do que tua biblioteca transmite.',
    'Você pode ajustar as notificações que recebe neste app, dentro do que sua biblioteca transmite.',
  ],
  'auth.create.intent.newLibrary.body': [
    'Seu cadastro cria uma conta pessoal — é ela que vai carregar o pedido, receber as respostas da coordenação e, se a biblioteca entrar, o mandato de coordenação. Depois do cadastro, um botão te leva direto ao formulário de pedido — e o link também chega por e-mail. Nada ali é definitivo, e ninguém decide sozinh@: a coordenação conversa com você.',
    'Seu cadastro cria uma conta pessoal — é ela que vai carregar o pedido, receber as respostas da coordenação e, se a biblioteca entrar, o mandato de coordenação. Depois do cadastro, um botão leva você direto ao formulário de pedido — e o link também chega por e-mail. Nada ali é definitivo, e ninguém decide sozinh@: a coordenação conversa com você.',
  ],
  'auth.create.motivationHint': [
    'Algumas palavras sobre o que te traz à AnarBib. Esta mensagem é enviada à equipe.',
    'Algumas palavras sobre o que traz você à AnarBib. Esta mensagem é enviada à equipe.',
  ],
  'auth.create.wizard.confirm.card': [
    'Vais receber uma carteira de leitor(a/e).',
    'Você vai receber uma carteira de leitor(a/e).',
  ],
  'auth.create.wizard.confirm.howItWorksTitle': [
    'Como funciona tua biblioteca',
    'Como funciona sua biblioteca',
  ],
  'auth.create.wizard.confirm.identity.presential': [
    'Tua identidade de leitor(a/e) te será atribuída na tua primeira visita.',
    'Sua identidade de leitor(a/e) será atribuída a você na sua primeira visita.',
  ],
  'auth.create.wizard.confirm.identity.remote': [
    'Tua identidade de leitor(a/e) te será enviada por e-mail.',
    'Sua identidade de leitor(a/e) será enviada a você por e-mail.',
  ],
  'auth.create.wizard.confirm.login': [
    'Conecta-te com teu e-mail ou teu ID público + a senha provisória recebida por e-mail (troca-a em Conta).',
    'Conecte-se com seu e-mail ou seu ID público + a senha provisória recebida por e-mail (troque-a em Conta).',
  ],
  'auth.create.wizard.confirm.pending': [
    'Tua inscrição deve ser validada pela equipe antes de pegar emprestado.',
    'Sua inscrição deve ser validada pela equipe antes de pegar emprestado.',
  ],
  'biblioteca.readerIdentity.hint': [
    'Define como as pessoas leitoras são identificadas na tua biblioteca (número, nome…) e como a inscrição é validada. Guia não bloqueante.',
    'Defina como as pessoas leitoras são identificadas na sua biblioteca (número, nome…) e como a inscrição é validada. Guia não bloqueante.',
  ],
  'biblioteca.readerIdentity.publicSignup.hint': [
    'Quando ativado, a tua biblioteca aparece na lista de bibliotecas que qualquer pessoa da rede pode solicitar para ingressar. Quando desativado, a associação ocorre apenas por admissão manual da equipe.',
    'Quando ativado, a sua biblioteca aparece na lista de bibliotecas que qualquer pessoa da rede pode solicitar para ingressar. Quando desativado, a associação ocorre apenas por admissão manual da equipe.',
  ],
  'federacao.entraide.bodyPlaceholder': [
    'Descreve tua dificuldade. (Sem dados de catálogo aqui — só a tua pergunta.)',
    'Descreva sua dificuldade. (Sem dados de catálogo aqui — só a sua pergunta.)',
  ],
  'federacao.entraide.intro': [
    'Precisa de uma mão para catalogar (ou outra coisa)? Faça um chamado; as outras bibliotecas podem te ajudar.',
    'Precisa de uma mão para catalogar (ou outra coisa)? Faça um chamado; as outras bibliotecas podem ajudar você.',
  ],
  'federacao.entraide.mine': [
    'teu chamado',
    'seu chamado',
  ],
  'federacao.entraide.note': [
    'Um chamado pede um saber-fazer, não um compartilhamento de catálogo. A videochamada é na tua língua — o roteamento por círculo virá.',
    'Um chamado pede um saber-fazer, não um compartilhamento de catálogo. A videochamada é na sua língua — o roteamento por círculo virá.',
  ],
  'federacao.entraide.offerSent': [
    'Tua ajuda foi oferecida.',
    'Sua ajuda foi oferecida.',
  ],
  'federacao.gazeta.contribute.intro': [
    'Tua proposta é enviada à equipe da rede, que a revisa antes de qualquer publicação.',
    'Sua proposta é enviada à equipe da rede, que a revisa antes de qualquer publicação.',
  ],
  'federacao.gazeta.contribute.success': [
    'Tua proposta foi enviada à equipe da rede.',
    'Sua proposta foi enviada à equipe da rede.',
  ],
  'federacao.inicio.pending': [
    'O que te espera',
    'O que espera por você',
  ],
  'importacoes.export.attach.desc': [
    'Liga um ficheiro recebido (fundo mutualizado) a um livro do teu catálogo: torna-se um ficheiro verificado « domínio público » e a ficha fica exportável por sua vez.',
    'Ligue um ficheiro recebido (fundo mutualizado) a um livro do seu catálogo: torna-se um ficheiro verificado « domínio público » e a ficha fica exportável por sua vez.',
  ],
  'notif.consulta.agendada.body': [
    'Uma das tuas consultas locais foi agendada. Verifica o horário no separador Reservas e consultas.',
    'Uma das suas consultas locais foi agendada. Verifique o horário na aba Reservas e consultas.',
  ],
  'notif.reserva.prontaParaRetirada.body': [
    'Uma das tuas reservas está pronta. Podes ir buscá-la na biblioteca.',
    'Uma das suas reservas está pronta. Você pode ir buscá-la na biblioteca.',
  ],
  'panel.reader.foundInOtherLibrary': [
    'Cadastro vinculado a {library} (fora da tua biblioteca atual).',
    'Cadastro vinculado a {library} (fora da sua biblioteca atual).',
  ],
  'rede.cooptation.vote.discloseIdentityHint': [
    'Esta escolha é obrigatória e gravada para cada voto. As demais administradores veem sempre vossa identidade.',
    'Esta escolha é obrigatória e gravada para cada voto. As demais administradores veem sempre sua identidade.',
  ],
  'rede.cooptation.vote.errors.discloseRequired': [
    'Vossa escolha sobre a divulgação da identidade é obrigatória.',
    'Sua escolha sobre a divulgação da identidade é obrigatória.',
  ],
  'rede.cooptation.vote.modal.description': [
    'Vossa decisão é decisiva: a unanimidade é requerida. Um único voto contrário fecha o processo.',
    'Sua decisão é decisiva: a unanimidade é requerida. Um único voto contrário fecha o processo.',
  ],
  'rede.cooptation.vote.rationalePlaceholder': [
    'Expliquei os motivos políticos da vossa oposição…',
    'Explique os motivos políticos da sua oposição…',
  ],
  'rede.cooptation.propose.modal.description': [
    'A cooptação é uma decisão política coletiva. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s da rede é necessária. Verificai que est(o/a/e) camarada tem confiança coletiva da rede.',
    'A cooptação é uma decisão política coletiva. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s da rede é necessária. Verifique que est(o/a/e) camarada tem confiança coletiva da rede.',
  ],
  'rede.collectiveRemoval.propose.modal.warning': [
    'Atenção: decisão política grave. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s (exclu(o/a/e) (o/a/e) target) é requerida. Uma carência de 7 dias se aplica antes da efetivação. Verificai que esta posição é coletivamente partilhada.',
    'Atenção: decisão política grave. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s (exclu(o/a/e) (o/a/e) target) é requerida. Uma carência de 7 dias se aplica antes da efetivação. Verifique que esta posição é coletivamente compartilhada.',
  ],
  'conta.demande.analysisHint': [
    'A tua solicitação está em avaliação pela coordenação da rede. Receberás um e-mail assim que houver uma decisão.',
    'A sua solicitação está em avaliação pela coordenação da rede. Você receberá um e-mail assim que houver uma decisão.',
  ],
  'conta.demande.approvedHint': [
    'A tua solicitação foi aprovada! Vai para a oficina de constituição para configurar a tua biblioteca.',
    'A sua solicitação foi aprovada! Vá para a oficina de constituição para configurar a sua biblioteca.',
  ],
  'conta.demande.messagePlaceholder': [
    'A tua mensagem à coordenação…',
    'A sua mensagem à coordenação…',
  ],
  'conta.demande.refusedHint': [
    'A tua solicitação não foi aceita. Podes enviar uma nova solicitação corrigida.',
    'A sua solicitação não foi aceita. Você pode enviar uma nova solicitação corrigida.',
  ],
  'conta.demande.awaitingInfoHint': [
    'A coordenação precisa de informações complementares. Responde abaixo.',
    'A coordenação precisa de informações complementares. Responda abaixo.',
  ],
  'rede.eval.degradedHint': [
    'Enquanto houver menos de 3 admins de rede ativos, a tua proposta é confirmada imediatamente.',
    'Enquanto houver menos de 3 admins de rede ativos, a sua proposta é confirmada imediatamente.',
  ],
  'catalogacao.subjects.missingLabelHint': [
    'Sem rótulo no teu idioma — exibido por padrão. Podes completá-lo.',
    'Sem rótulo no seu idioma — exibido por padrão. Você pode completá-lo.',
  ],
  'account.lettre.intro': [
    'Um caderno da vida da rede, enviado por e-mail só se tu pedires.',
    'Um caderno da vida da rede, enviado por e-mail só se você pedir.',
  ],
  'account.lettre.confirmationSent': [
    'Enviámos-te um e-mail de confirmação — clica no link para validar tua inscrição.',
    'Enviamos um e-mail de confirmação para você — clique no link para validar sua inscrição.',
  ],
  'account.lettre.pending': [
    'Confirmação pendente: verifica tua caixa de entrada (e o spam).',
    'Confirmação pendente: verifique sua caixa de entrada (e o spam).',
  ],
  'account.lettre.subscribed': [
    'A tua inscrição está ativa.',
    'A sua inscrição está ativa.',
  ],
  'account.lettre.unsubscribed': [
    'A tua inscrição foi cancelada.',
    'A sua inscrição foi cancelada.',
  ],
  'account.lettre.note': [
    'Podes cancelar a qualquer momento, com um clique. Sem rastreio, sem revenda.',
    'Você pode cancelar a qualquer momento, com um clique. Sem rastreamento, sem revenda.',
  ],
  'federacao.inicio.lettre.desc': [
    'O caderno da rede na tua caixa de entrada, se pedires.',
    'O caderno da rede na sua caixa de entrada, se você pedir.',
  ],
  'notif.welcome.body': [
    'A tua conta foi criada. Para começar: explora o catálogo, faz a tua primeira reserva ou consulta, e completa o teu perfil em «Minha conta».',
    'A sua conta foi criada. Para começar: explore o catálogo, faça a sua primeira reserva ou consulta, e complete o seu perfil em «Minha conta».',
  ],
  'privacy.video.body': [
    'Alguns tutoriais em vídeo ficam hospedados no kolektiva.media, uma instância PeerTube militante. Por respeito à tua privacidade, esses vídeos não são carregados automaticamente: nada é enviado ao kolektiva.media enquanto você não clicar em «Carregar o vídeo». A partir desse clique, o kolektiva.media recebe teu endereço IP — como qualquer site que você visita — para te entregar o vídeo. Desativamos o compartilhamento P2P nesses vídeos, para que teu IP não fique exposto a outros espectadores nem a servidores de terceiros.',
    'Alguns tutoriais em vídeo ficam hospedados no kolektiva.media, uma instância PeerTube militante. Por respeito à sua privacidade, esses vídeos não são carregados automaticamente: nada é enviado ao kolektiva.media enquanto você não clicar em «Carregar o vídeo». A partir desse clique, o kolektiva.media recebe seu endereço IP — como qualquer site que você visita — para entregar o vídeo a você. Desativamos o compartilhamento P2P nesses vídeos, para que seu IP não fique exposto a outros espectadores nem a servidores de terceiros.',
  ],
  'account.tutorials.loadNotice': [
    'Carregado do kolektiva.media só depois do teu clique. Nada é enviado antes.',
    'Carregado do kolektiva.media só depois do seu clique. Nada é enviado antes.',
  ],
  'biblioteca.events.hint': [
    'Cria e publica as leituras públicas, debates, oficinas… da tua biblioteca. Os eventos públicos futuros aparecem na conta dos membros leitores.',
    'Crie e publique as leituras públicas, debates, oficinas… da sua biblioteca. Os eventos públicos futuros aparecem na conta dos membros leitores.',
  ],
  'account.tab.events.hint': [
    'As leituras públicas, debates e encontros futuros das tuas bibliotecas.',
    'As leituras públicas, debates e encontros futuros das suas bibliotecas.',
  ],
  'rede.exch.messagePlaceholder': [
    'A tua mensagem à pessoa solicitante…',
    'A sua mensagem à pessoa solicitante…',
  ],
  'federacao.gazeta.resubmit.title': [
    'Corrigir e reenviar tua nota',
    'Corrigir e reenviar sua nota',
  ],
  'federacao.gazeta.resubmit.intro': [
    'Tua nota foi lida e não foi retida tal como está. Eis o motivo; corrige o que for preciso e reenvia-a: a equipe da rede a relerá como uma nova proposta.',
    'Sua nota foi lida e não foi retida tal como está. Eis o motivo; corrija o que for preciso e reenvie-a: a equipe da rede a relerá como uma nova proposta.',
  ],
  'federacao.gazeta.resubmit.loading': [
    'Recuperando tua nota…',
    'Recuperando sua nota…',
  ],
  'federacao.gazeta.resubmit.success': [
    'Obrigado, tua nota corrigida foi transmitida à equipe da rede.',
    'Obrigado, sua nota corrigida foi transmitida à equipe da rede.',
  ],
  'federacao.gazeta.resubmit.error.invalid': [
    'Este link de retomada não é válido. Podes propor tua nota de novo pelo formulário habitual.',
    'Este link de retomada não é válido. Você pode propor sua nota de novo pelo formulário habitual.',
  ],
  'federacao.gazeta.resubmit.error.used': [
    'Este link já foi usado: tua nota corrigida já foi transmitida.',
    'Este link já foi usado: sua nota corrigida já foi transmitida.',
  ],
  'federacao.gazeta.resubmit.error.expired': [
    'Este link de retomada expirou (60 dias). Podes propor tua nota de novo pelo formulário habitual.',
    'Este link de retomada expirou (60 dias). Você pode propor sua nota de novo pelo formulário habitual.',
  ],
  'rede.gazeta.correct.hint': [
    'Corrige tu mesma o que impede a nota de sair. A pessoa será avisada de que foi retida com correções, com o texto que sairá; a tradução recomeça.',
    'Corrija você mesma o que impede a nota de sair. A pessoa será avisada de que foi retida com correções, com o texto que sairá; a tradução recomeça.',
  ],
  'relatar.intro': [
    'Algo não funcionou, ou não como esperavas? Conta aqui, sem precisar de conta nem de Codeberg. As pessoas que administram a rede recebem o teu aviso por e-mail.',
    'Algo não funcionou, ou não como você esperava? Conte aqui, sem precisar de conta nem de Codeberg. As pessoas que administram a rede recebem o seu aviso por e-mail.',
  ],
  'relatar.email': [
    'O teu e-mail (opcional)',
    'O seu e-mail (opcional)',
  ],
  'relatar.emailHint': [
    'Só para te confirmar que o relato chegou. Não haverá acompanhamento automático.',
    'Só para confirmar a você que o relato chegou. Não haverá acompanhamento automático.',
  ],
  'relatar.context': [
    'Enviado junto: a página de origem ({page}), a tua língua e, se tiveres sessão, o teu papel e a tua biblioteca.',
    'Enviado junto: a página de origem ({page}), a sua língua e, se você tiver uma sessão aberta, o seu papel e a sua biblioteca.',
  ],
  'relatar.success': [
    'Recebido, obrigada. As pessoas que administram a rede vão ler o teu relato.',
    'Recebido, obrigada. As pessoas que administram a rede vão ler o seu relato.',
  ],
  'relatar.whatHint': [
    'Pelo menos dez caracteres. O que viste no ecrã, a mensagem exata se houve uma.',
    'Pelo menos dez caracteres. O que você viu na tela, a mensagem exata se houve uma.',
  ],
  'relatar.expected': [
    'O que esperavas (opcional)',
    'O que você esperava (opcional)',
  ],
  'relatar.error': [
    'Não foi possível enviar. Tenta de novo daqui a um momento.',
    'Não foi possível enviar. Tente de novo daqui a um momento.',
  ],
  'relatar.tooShort': [
    'Conta um pouco mais: dez caracteres pelo menos.',
    'Conte um pouco mais: dez caracteres pelo menos.',
  ],
  'error.publish.other_library': [
    'Este rascunho está vinculado a uma biblioteca da qual não fazes parte. A publicação cabe a essa biblioteca ou a uma administradora da rede.',
    'Este rascunho está vinculado a uma biblioteca da qual você não faz parte. A publicação cabe a essa biblioteca ou a uma administradora da rede.',
  ],
  'catalogacao.queue.restoreDeletedConfirm': [
    'Restaurar este rascunho excluído? Ele voltará para a lixeira, de onde podes devolvê-lo a rascunho.',
    'Restaurar este rascunho excluído? Ele voltará para a lixeira, de onde você pode devolvê-lo a rascunho.',
  ],
  'error.batch.has_drafts_in_progress': [
    'Este lote ainda retém trabalho em curso. Trata-o ou manda-o para a lixeira antes de excluir o lote.',
    'Este lote ainda retém trabalho em curso. Trate-o ou mande-o para a lixeira antes de excluir o lote.',
  ],
  'biblioteca.openingHours.hint': [
    'Faixas semanais — adiciona quantas precisares (plantões, aberturas…). Visível pelos membros da biblioteca.',
    'Faixas semanais — adicione quantas precisar (plantões, aberturas…). Visível pelos membros da biblioteca.',
  ],
  'biblioteca.regime.state1.step1': [
    'Se o texto público mudar, revisa o conjunto em uso.',
    'Se o texto público mudar, revise o conjunto em uso.',
  ],
  'biblioteca.regime.state1.step2': [
    'Confere se as regras continuam batendo com o texto.',
    'Confira se as regras continuam batendo com o texto.',
  ],
  'biblioteca.regime.state1.step3': [
    'Salva os ajustes antes de trocar o conjunto em uso.',
    'Salve os ajustes antes de trocar o conjunto em uso.',
  ],
  'biblioteca.regime.state2.step1': [
    'Registra ou revisa o texto principal da biblioteca.',
    'Registre ou revise o texto principal da biblioteca.',
  ],
  'biblioteca.regime.state2.step2': [
    'Liga o conjunto em uso a esse texto.',
    'Ligue o conjunto em uso a esse texto.',
  ],
  'biblioteca.regime.state2.step3': [
    'Confere se as regras batem com o texto público.',
    'Confira se as regras batem com o texto público.',
  ],
  'biblioteca.regime.state3.step1': [
    'Cria um conjunto ligado a esse texto, se ainda não existir.',
    'Crie um conjunto ligado a esse texto, se ainda não existir.',
  ],
  'biblioteca.regime.state3.step2': [
    'Adiciona pelo menos uma regra.',
    'Adicione pelo menos uma regra.',
  ],
  'biblioteca.regime.state3.step3': [
    'Coloca o conjunto em uso.',
    'Coloque o conjunto em uso.',
  ],
  'biblioteca.regime.state4.step1': [
    'Escolhe o conjunto que deve valer agora.',
    'Escolha o conjunto que deve valer agora.',
  ],
  'biblioteca.regime.state4.step2': [
    'Confere se ele tem pelo menos uma regra.',
    'Confira se ele tem pelo menos uma regra.',
  ],
  'biblioteca.regime.state4.step3': [
    'Coloca o conjunto em uso.',
    'Coloque o conjunto em uso.',
  ],
  'biblioteca.regime.state5.step1': [
    'Registra primeiro o texto principal da biblioteca.',
    'Registre primeiro o texto principal da biblioteca.',
  ],
  'biblioteca.regime.state5.step2': [
    'Cria um conjunto de regras para empréstimo, reserva e consulta.',
    'Crie um conjunto de regras para empréstimo, reserva e consulta.',
  ],
  'biblioteca.regime.state5.step3': [
    'Adiciona pelo menos uma regra.',
    'Adicione pelo menos uma regra.',
  ],
  'biblioteca.regime.state5.step4': [
    'Coloca o conjunto em uso.',
    'Coloque o conjunto em uso.',
  ],
  'catalogacao.subjectGov.editHint': [
    'Busca um assunto, depois completa ou corrige os rótulos por língua. Sinônimos e variantes: separados por vírgulas.',
    'Busque um assunto, depois complete ou corrija os rótulos por língua. Sinônimos e variantes: separados por vírgulas.',
  ],
  'catalogacao.subjects.suggestionsHint': [
    'A partir dos outros livros da autoria. Clica para adicionar.',
    'A partir dos outros livros da autoria. Clique para adicionar.',
  ],
  'rede.lettre.bodyPlaceholder': [
    'Escreve a carta em markdown (títulos, listas, negrito, links…)',
    'Escreva a carta em markdown (títulos, listas, negrito, links…)',
  ],
  'rede.lettre.lead': [
    'Compõe e envia um número do boletim às pessoas inscritas.',
    'Componha e envie um número do boletim às pessoas inscritas.',
  ],
  'rede.gazeta.reject.notePlaceholder': [
    'Diz por quê, e o que tornaria a nota publicável.',
    'Diga por quê, e o que tornaria a nota publicável.',
  ],
  'resource.viewer.externalNotice': [
    'Este recurso abre fora d(o/a/e) AnarBib. Usa o botão <em>Abrir recurso</em> para continuar.',
    'Este recurso abre fora d(o/a/e) AnarBib. Use o botão <em>Abrir recurso</em> para continuar.',
  ],
  'resource.viewer.pdf.errorLoad': [
    'Não foi possível carregar o PDF. Tenta de novo ou contata um(a/e) bibliotecári(o/a/e).',
    'Não foi possível carregar o PDF. Tente de novo ou contate um(a/e) bibliotecári(o/a/e).',
  ],
  'resource.viewer.pdf.errorTimeout': [
    'O carregamento d(o/a/e) PDF demorou demais. Verifica a conexão e tenta de novo.',
    'O carregamento d(o/a/e) PDF demorou demais. Verifique a conexão e tente de novo.',
  ],
  'resource.viewer.pdf.passwordPrompt': [
    'Este PDF está protegido. Insere a senha para abri-lo.',
    'Este PDF está protegido. Insira a senha para abri-lo.',
  ],
  'catalogacao.batchPublishedArchiveInstead': [
    'Este lote tem {count} ficha(s) já publicada(s) no catálogo: ele guarda a memória dessa sessão de catalogação. Um lote publicado arquiva-se — usa «Arquivar».',
    'Este lote tem {count} ficha(s) já publicada(s) no catálogo: ele guarda a memória dessa sessão de catalogação. Um lote publicado arquiva-se — use «Arquivar».',
  ],
  'error.publish.item_before_record': [
    'Este exemplar importado é publicado com a sua ficha: publica a ficha.',
    'Este exemplar importado é publicado com a sua ficha: publique a ficha.',
  ],
  'error.catalog.restore_record_first': [
    'A ficha deste exemplar foi apagada: restaura primeiro a ficha (ela traz de volta os seus exemplares).',
    'A ficha deste exemplar foi apagada: restaure primeiro a ficha (ela traz de volta os seus exemplares).',
  ],
  'error.import.profile_missing': [
    'O perfil de importação deste arquivo foi apagado: escolhe um perfil e importa o arquivo de novo.',
    'O perfil de importação deste arquivo foi apagado: escolha um perfil e importe o arquivo de novo.',
  ],
  'catalogacao.queue.importedFollowRecord': [
    'Alguns itens não mudaram: um exemplar importado segue a sua ficha (restaura ou move a ficha).',
    'Alguns itens não mudaram: um exemplar importado segue a sua ficha (restaure ou mova a ficha).',
  ],
};

const j = JSON.parse(fs.readFileSync(FICHIER, 'utf8'));
let reecrites = 0;
let dejaVoce = 0;
const absentes = [];
const autres = [];
for (const [k, [de, para]] of Object.entries(DE_PARA)) {
  if (!(k in j)) absentes.push(k);
  else if (j[k] === de) { j[k] = para; reecrites++; }
  else if (j[k] === para) dejaVoce++;
  else autres.push(k);
}
fs.writeFileSync(FICHIER, JSON.stringify(j, null, 2) + '\n');
console.log(`pt-BR : ${reecrites} réécrite(s), ${dejaVoce} déjà au « você »`);
if (absentes.length) console.log(`absentes (laissées) : ${absentes.join(', ')}`);
if (autres.length) console.log(`modifiées depuis, ni « tu » ni la version de ce script (laissées) : ${autres.join(', ')}`);
