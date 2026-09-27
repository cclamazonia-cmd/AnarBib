/* ===========================================================================
 * mail-ptbr-voce.cjs
 * DOC-ADDR-1 (« você en pt-BR ») — suite de a805951b, qui avait réécrit les
 * 102 valeurs de pt-BR.json au « tu » européen et laissé les COURRIELS de
 * côté. Relevé le 27/09/2026 sur les modules de chaînes des Edge Functions :
 * 61 valeurs pt-BR parlaient encore « tu » ou « vós » — « Recebemos o teu
 * relato », « Lembra-te de renová-la », « Confirma tua inscrição… clica no
 * botão », « Se não foste tu… ignora esta mensagem », « Recebes este boletim
 * porque te inscreveste », « aguarda vossa decisão », « integrar-te como
 * administrador(a/e) », « A ti aceitar, recusar », « Em caso de dúvida,
 * responde a este e-mail »… — plus le pied de page par défaut de
 * _shared/core/env.ts (« Responde apenas se… »). Toutes réécrites au
 * « você » (seu/sua, impératifs « confirme », « clique », « renove »,
 * « a você » au lieu de « te »), sens et placeholders {…} inchangés.
 *
 * Relevé fait EN LISANT les 862 valeurs pt-BR des quatre modules (tMail,
 * tTask, cross-library, notify-library-request), pas par la seule regex :
 * le motif TU_EUROPEU n'en trouve que 50 sur 61. Il ne voit ni « Não
 * respondas », ni « Deixaste de receber », ni « Acessai a app », ni « vem
 * ler », ni « quem vos representará », ni « Consulta o painel » (homographe
 * du nom, exclu à dessein), ni l'impératif « responde » après une virgule ;
 * « Se preferires » et « por teres escrito » ne sont tombées que parce que
 * leur phrase portait aussi un « teu ».
 *
 * Les quatre textes « Como funciona sua biblioteca » du courriel de
 * bienvenue (welcome.howItWorks.*) redeviennent identiques aux clés
 * auth.create.wizard.confirm.* de pt-BR.json, comme ils le sont dans les
 * neuf autres locales. welcome.pending reste un texte à part (il l'est
 * partout).
 *
 * Vocabulaire européen corrigé seulement dans les phrases réécrites
 * (« a app » → « o aplicativo », « na equipa » → « à equipe ») ; plus
 * « Motivacao » → « Motivação » (diacritique mangé, dans
 * network.cooptation_proposed.motivation_label).
 *
 * Réécriture DE → PARA sur le TEXTE SOURCE : un littéral n'est remplacé que
 * s'il apparaît EXACTEMENT une fois sous sa forme d'avant (entre "…" ou
 * `…`). Rejouable sans risque : une valeur déjà au « você » est comptée,
 * une valeur retouchée depuis est signalée et laissée.
 *
 * La garde : src/tests/mail-ptbr-voce.test.js (motif TU_EUROPEU partagé avec
 * src/tests/i18n-ecriture.test.js, chemin (4)).
 * Usage : node scripts/mail-ptbr-voce.cjs
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const RACINE = path.join(__dirname, '..');

// fichier → { clé : [valeur au « tu » européen, valeur au « você »] }
const DE_PARA = {
  'supabase/functions/_shared/i18n/mail-strings.ts': {
    'bugreport.ack.sub': [
      'Recebemos o teu relato — {ref}',
      'Recebemos o seu relato — {ref}',
    ],
    'bugreport.ack.intro': [
      'Obrigada por relatar. As pessoas que administram a rede vão ler o teu relato; não haverá acompanhamento automático.',
      'Obrigada por relatar. As pessoas que administram a rede vão ler o seu relato; não haverá acompanhamento automático.',
    ],
    'bugreport.ack.noreply': [
      'Não respondas a esta mensagem. Para falar com uma pessoa: {email}.',
      'Não responda a esta mensagem. Para falar com uma pessoa: {email}.',
    ],
    'cotisation.expiring.subject': [
      'A tua contribuição está perto do vencimento',
      'A sua contribuição está perto do vencimento',
    ],
    'cotisation.expiring.intro': [
      'A tua contribuição à {library} vence em {date}. Lembra-te de renová-la junto à biblioteca para continuar a pegar emprestado.',
      'A sua contribuição à {library} vence em {date}. Lembre-se de renová-la junto à biblioteca para continuar a pegar emprestado.',
    ],
    'cotisation.expiring_today.subject': [
      'A tua contribuição vence hoje',
      'A sua contribuição vence hoje',
    ],
    'cotisation.expiring_today.intro': [
      'A tua contribuição à {library} vence hoje ({date}). Renova-a junto à biblioteca para continuar a pegar emprestado.',
      'A sua contribuição à {library} vence hoje ({date}). Renove-a junto à biblioteca para continuar a pegar emprestado.',
    ],
    'entraide.request_circle.sub': [
      'Novo chamado de apoio mútuo no teu círculo {circle}',
      'Novo chamado de apoio mútuo no seu círculo {circle}',
    ],
    'entraide.request_circle.intro': [
      'Uma biblioteca do teu círculo « {circle} » publicou um chamado de apoio mútuo: {subject}. Podes responder na aba Apoio mútuo.',
      'Uma biblioteca do seu círculo « {circle} » publicou um chamado de apoio mútuo: {subject}. Você pode responder na aba Apoio mútuo.',
    ],
    'gazette.contribution.rejected.sub': [
      'Tua nota « {title} » não foi retida — eis por quê',
      'Sua nota « {title} » não foi retida — eis por quê',
    ],
    'gazette.contribution.rejected.intro': [
      'A equipe da rede leu tua proposta para a rubrica « {rubric} » e decidiu não a publicar tal como está. O motivo, escrito por quem a leu:',
      'A equipe da rede leu sua proposta para a rubrica « {rubric} » e decidiu não a publicar tal como está. O motivo, escrito por quem a leu:',
    ],
    'gazette.contribution.rejected.resubmit.title': [
      'Podes corrigir tua nota e reenviá-la',
      'Você pode corrigir sua nota e reenviá-la',
    ],
    'gazette.contribution.rejected.resubmit.expires': [
      'O link abre o formulário já preenchido com teu texto e o motivo. Serve uma única vez e vale até {date}. Se preferires não retomar, não há nada a fazer.',
      'O link abre o formulário já preenchido com seu texto e o motivo. Serve uma única vez e vale até {date}. Se preferir não retomar, não há nada a fazer.',
    ],
    'gazette.contribution.accepted.sub': [
      'Tua nota « {title} » foi aceita para a Gazeta',
      'Sua nota « {title} » foi aceita para a Gazeta',
    ],
    'gazette.contribution.accepted.intro': [
      'A equipe da rede leu tua proposta « {title} » e a reteve. Ela entrará na página « Vida da rede » do próximo número, traduzida nas dez línguas da rede. Obrigado por teres escrito: é dessas notas que a página é feita.',
      'A equipe da rede leu sua proposta « {title} » e a reteve. Ela entrará na página « Vida da rede » do próximo número, traduzida nas dez línguas da rede. Obrigado por ter escrito: é dessas notas que a página é feita.',
    ],
    'lettre.optin.confirm.sub': [
      'Confirma tua inscrição no Boletim da rede',
      'Confirme sua inscrição no Boletim da rede',
    ],
    'lettre.optin.confirm.intro': [
      'Tu pediste para receber o Boletim da rede. Para confirmar tua inscrição, clica no botão abaixo.',
      'Você pediu para receber o Boletim da rede. Para confirmar sua inscrição, clique no botão abaixo.',
    ],
    'lettre.optin.confirm.note': [
      'Se não foste tu quem fez este pedido, ignora esta mensagem: nada será enviado sem tua confirmação.',
      'Se não foi você quem fez este pedido, ignore esta mensagem: nada será enviado sem sua confirmação.',
    ],
    'lettre.landing.confirmed': [
      'Inscrição confirmada! Vais receber o Boletim da rede.',
      'Inscrição confirmada! Você vai receber o Boletim da rede.',
    ],
    'lettre.landing.already': [
      'Tua inscrição já estava confirmada.',
      'Sua inscrição já estava confirmada.',
    ],
    'lettre.landing.expired': [
      'Este link de confirmação expirou. Podes pedir um novo a partir da tua conta.',
      'Este link de confirmação expirou. Você pode pedir um novo a partir da sua conta.',
    ],
    'lettre.landing.error': [
      'Ocorreu um erro. Tenta de novo mais tarde.',
      'Ocorreu um erro. Tente de novo mais tarde.',
    ],
    'lettre.landing.unsubscribed': [
      'Pronto! Deixaste de receber o Boletim da rede.',
      'Pronto! Você deixou de receber o Boletim da rede.',
    ],
    'lettre.issue.gazetteLink': [
      'Saiu o n.º {number} da Fractale — vem ler',
      'Saiu o n.º {number} da Fractale — venha ler',
    ],
    'lettre.issue.unsubscribePrefix': [
      'Recebes este boletim porque te inscreveste nele.',
      'Você recebe este boletim porque se inscreveu nele.',
    ],
    'reader_identity_assigned.subject': [
      'Tua identidade de leitor(a/e)',
      'Sua identidade de leitor(a/e)',
    ],
    'reader_identity_assigned.intro': [
      'A equipe te atribuiu uma identidade nesta biblioteca. Podes apresentá-la nas tuas visitas.',
      'A equipe atribuiu a você uma identidade nesta biblioteca. Você pode apresentá-la nas suas visitas.',
    ],
    'welcome.howItWorks.title': [
      'Como funciona tua biblioteca',
      'Como funciona sua biblioteca',
    ],
    'welcome.howItWorks.card': [
      'Vais receber uma carteira de leitor(a/e).',
      'Você vai receber uma carteira de leitor(a/e).',
    ],
    'welcome.howItWorks.identity.remote': [
      'Tua identidade de leitor(a/e) te será enviada por e-mail.',
      'Sua identidade de leitor(a/e) será enviada a você por e-mail.',
    ],
    'welcome.howItWorks.identity.presential': [
      'Tua identidade de leitor(a/e) te será atribuída na tua primeira visita.',
      'Sua identidade de leitor(a/e) será atribuída a você na sua primeira visita.',
    ],
    'welcome.pending': [
      'Tua inscrição precisa ser validada pela equipe: poderás pegar emprestado e reservar assim que for validada.',
      'Sua inscrição precisa ser validada pela equipe: você poderá pegar emprestado e reservar assim que for validada.',
    ],
    'network.cooptation_reminder.intro': [
      'Uma proposta de cooptação foi aberta há vários dias e ainda aguarda vossa decisão. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s é necessária para concluir o processo.',
      'Uma proposta de cooptação foi aberta há vários dias e ainda aguarda sua decisão. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s é necessária para concluir o processo.',
    ],
    'network.request_eval_digest.intro_proposal': [
      'Uma proposta de decisão sobre uma solicitação de adesão aguarda vosso voto. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s da rede é necessária.',
      'Uma proposta de decisão sobre uma solicitação de adesão aguarda seu voto. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s da rede é necessária.',
    ],
    'network.collective_removal_proposed.intro': [
      '{proposerName} abriu uma proposta de retirada coletiva d(o/a/e) administrador(a/e) {proposedName}. Esta é uma decisão política grave que exige unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s (excluíd(o/a/e) (o/a/e) próprio(a/e) target). Vosso voto é necessário.',
      '{proposerName} abriu uma proposta de retirada coletiva d(o/a/e) administrador(a/e) {proposedName}. Esta é uma decisão política grave que exige unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s (excluíd(o/a/e) (o/a/e) próprio(a/e) target). Seu voto é necessário.',
    ],
    'network.collective_removal_vote_cast.intro': [
      'Um(a/e) administrador(a/e) de rede acaba de votar sobre a proposta de retirada coletiva d(o/a/e) administrador(a/e) {proposedName}, aberta por {proposerName}. Acessai a app para ver o estado atual da deliberação e votar.',
      'Um(a/e) administrador(a/e) de rede acaba de votar sobre a proposta de retirada coletiva d(o/a/e) administrador(a/e) {proposedName}, aberta por {proposerName}. Acesse o aplicativo para ver o estado atual da deliberação e votar.',
    ],
    'network.collective_removal_unanimous.target_intro': [
      'Esta mensagem informa que a unanimidade d(o/a/e)s outr(o/a/e)s administrador(a/e)s ativ(o/a/e)s foi alcançada sobre a vossa retirada coletiva. Uma carência de 7 dias se aplica antes da efetivação. Vossa palavra é livre durante esta janela.',
      'Esta mensagem informa que a unanimidade d(o/a/e)s outr(o/a/e)s administrador(a/e)s ativ(o/a/e)s foi alcançada sobre a sua retirada coletiva. Uma carência de 7 dias se aplica antes da efetivação. Sua palavra é livre durante esta janela.',
    ],
    'network.collective_removal_executed.target_intro': [
      'A carência de 7 dias terminou e a retirada coletiva votada por unanimidade está agora efetiva. Vossa função d(o/a/e) administrador(a/e) de rede no AnarBib foi removida. Esta decisão é registrada no histórico militante.',
      'A carência de 7 dias terminou e a retirada coletiva votada por unanimidade está agora efetiva. Sua função d(o/a/e) administrador(a/e) de rede no AnarBib foi removida. Esta decisão é registrada no histórico militante.',
    ],
    'network.assembleia.convocada.intro': [
      'Uma assembleia da rede foi convocada: « {title} ». A ordem do dia está se constituindo — é hora de avisar sua biblioteca e preparar o mandato de quem vos representará.',
      'Uma assembleia da rede foi convocada: « {title} ». A ordem do dia está se constituindo — é hora de avisar sua biblioteca e preparar o mandato de quem a representará.',
    ],
    'network.assembleia.agenda_published.intro': [
      'A ordem do dia de « {title} » está fixada e traduzida. Tomem conhecimento e mandatem quem vos representará ponto a ponto antes da realização.',
      'A ordem do dia de « {title} » está fixada e traduzida. Tomem conhecimento e mandatem quem representará vocês ponto a ponto antes da realização.',
    ],
    'network.cooptation_proposed.intro': [
      '{proposerName} propôs cooptar {proposedName} como administrador(a/e) de rede. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s é necessária para concluir o processo. Vosso voto é esperado.',
      '{proposerName} propôs cooptar {proposedName} como administrador(a/e) de rede. A unanimidade d(o/a/e)s administrador(a/e)s ativ(o/a/e)s é necessária para concluir o processo. Seu voto é esperado.',
    ],
    'network.cooptation_proposed.motivation_label': [
      'Motivacao invocada :',
      'Motivação invocada :',
    ],
    'network.cooptation_voted.intro': [
      'Um(a/e) administrador(a/e) de rede acaba de votar sobre a proposta de cooptação de {proposedName}, aberta por {proposerName}. Acessai a app para ver o estado atual da deliberação e votar se ainda não o fizeste.',
      'Um(a/e) administrador(a/e) de rede acaba de votar sobre a proposta de cooptação de {proposedName}, aberta por {proposerName}. Acesse o aplicativo para ver o estado atual da deliberação e votar se ainda não o fez.',
    ],
    'network.cooptation_rejected.target_intro': [
      'Olá {targetName}. Uma proposta de cooptação para integrar-te como administrador(a/e) de rede AnarBib foi aberta e discutida pel(o/a/e)s administrador(a/e)s ativ(o/a/e)s. Esta proposta não foi acolhida à unanimidade : recebeu pelo menos um voto contrário e o processo é encerrado. Esta decisão é coletiva e política, não pessoal.',
      'Olá {targetName}. Uma proposta de cooptação para integrar você como administrador(a/e) de rede AnarBib foi aberta e discutida pel(o/a/e)s administrador(a/e)s ativ(o/a/e)s. Esta proposta não foi acolhida à unanimidade : recebeu pelo menos um voto contrário e o processo é encerrado. Esta decisão é coletiva e política, não pessoal.',
    ],
    'network.cooptation_completed.target_intro': [
      'Olá {targetName}. A proposta de cooptação para integrar-te como administrador(a/e) de rede AnarBib foi concluída à unanimidade. Sejas bem-vind(o/a/e) na equipa de administração de rede.',
      'Olá {targetName}. A proposta de cooptação para integrar você como administrador(a/e) de rede AnarBib foi concluída à unanimidade. Seja bem-vind(o/a/e) à equipe de administração de rede.',
    ],
    'cwf.reader.nao_compareceu': [
      'Você foi marcado(a/e) como ausente na consulta local agendada para {date}, das {time_start} às {time_end}. A biblioteca tinha se preparado para te receber. Caso queira marcar um novo horário, entre em contato com a biblioteca.',
      'Você foi marcado(a/e) como ausente na consulta local agendada para {date}, das {time_start} às {time_end}. A biblioteca tinha se preparado para receber você. Caso queira marcar um novo horário, entre em contato com a biblioteca.',
    ],
    'rgpd.purge.loans.intro': [
      'Conforme nossa política de retenção de dados, teu histórico de empréstimos antigos será excluído em 30 dias.',
      'Conforme nossa política de retenção de dados, seu histórico de empréstimos antigos será excluído em 30 dias.',
    ],
    'rgpd.purge.reservations.intro': [
      'Conforme nossa política de retenção de dados, teu histórico de reservas antigas será excluído em 30 dias.',
      'Conforme nossa política de retenção de dados, seu histórico de reservas antigas será excluído em 30 dias.',
    ],
    'rgpd.purge.consultations.intro': [
      'Conforme nossa política de retenção de dados, teu histórico de consultas locais antigas será excluído em 30 dias.',
      'Conforme nossa política de retenção de dados, seu histórico de consultas locais antigas será excluído em 30 dias.',
    ],
    'rgpd.purge.howToCancel': [
      'Se quiseres exportar teus dados antes da exclusão, entra em contato com a biblioteca pelos canais habituais.',
      'Se quiser exportar seus dados antes da exclusão, entre em contato com a biblioteca pelos canais habituais.',
    ],
    'ill.requested.intro': [
      '{requester} solicita a partilha digital do documento « {book} ». A ti aceitar, recusar ou sinalizar a indisponibilidade.',
      '{requester} solicita a partilha digital do documento « {book} ». Cabe a você aceitar, recusar ou sinalizar a indisponibilidade.',
    ],
  },
  'supabase/functions/_shared/i18n/task-mail-strings.ts': {
    'assigned.introHtml': [
      '<p style="margin:0 0 10px;">Tu recebeste uma <b>nova tarefa interna</b>.</p><p style="margin:0;">Consulta o painel para acompanhar o andamento e registrar qualquer atualização necessária.</p>',
      '<p style="margin:0 0 10px;">Você recebeu uma <b>nova tarefa interna</b>.</p><p style="margin:0;">Consulte o painel para acompanhar o andamento e registrar qualquer atualização necessária.</p>',
    ],
    'orgCreated.subject': [
      'Nova tarefa interna sob tua responsabilidade',
      'Nova tarefa interna sob sua responsabilidade',
    ],
    'orgCreated.introHtml': [
      '<p style="margin:0 0 10px;">Uma <b>nova tarefa interna</b> foi registrada sob tua responsabilidade.</p><p style="margin:0;">Abre o painel da biblioteca para acompanhar o andamento e organizar os próximos passos.</p>',
      '<p style="margin:0 0 10px;">Uma <b>nova tarefa interna</b> foi registrada sob sua responsabilidade.</p><p style="margin:0;">Abra o painel da biblioteca para acompanhar o andamento e organizar os próximos passos.</p>',
    ],
    'orgUpdated.introHtml': [
      '<p style="margin:0 0 10px;">Uma tarefa interna sob tua responsabilidade recebeu uma <b>atualização importante</b>.</p><p style="margin:0;">Confere o painel da biblioteca para validar a nova situação e ajustar o acompanhamento.</p>',
      '<p style="margin:0 0 10px;">Uma tarefa interna sob sua responsabilidade recebeu uma <b>atualização importante</b>.</p><p style="margin:0;">Confira o painel da biblioteca para validar a nova situação e ajustar o acompanhamento.</p>',
    ],
    'invitation.introHtml': [
      '<p style="margin:0 0 10px;">Tu recebeste um <b>convite para participar de uma tarefa interna</b> da biblioteca.</p><p style="margin:0;">Se fizer sentido para ti, abre o painel da biblioteca para acompanhar a organização desta tarefa.</p>',
      '<p style="margin:0 0 10px;">Você recebeu um <b>convite para participar de uma tarefa interna</b> da biblioteca.</p><p style="margin:0;">Se fizer sentido para você, abra o painel da biblioteca para acompanhar a organização desta tarefa.</p>',
    ],
  },
  'supabase/functions/_shared/i18n/cross-library-strings.ts': {
    'footer': [
      'Este resumo é enviado toda semana para que nenhuma ação da rede passe despercebida. Em caso de dúvida, responde a este e-mail.',
      'Este resumo é enviado toda semana para que nenhuma ação da rede passe despercebida. Em caso de dúvida, responda a este e-mail.',
    ],
  },
  'supabase/functions/notify-library-request/strings.ts': {
    'footer': [
      'Em caso de dúvida, responde a este e-mail.',
      'Em caso de dúvida, responda a este e-mail.',
    ],
    'more_info.intro': [
      'A coordenação precisa de informações complementares sobre a solicitação da biblioteca {library}. Responde a este e-mail.',
      'A coordenação precisa de informações complementares sobre a solicitação da biblioteca {library}. Responda a este e-mail.',
    ],
    'invitation_response.subject': [
      'Resposta ao teu convite',
      'Resposta ao seu convite',
    ],
    'admin_created.intro': [
      'Uma nova solicitação institucional foi registrada: {library}. Consulta o painel de rede.',
      'Uma nova solicitação institucional foi registrada: {library}. Consulte o painel de rede.',
    ],
    'admin_message.intro': [
      'A biblioteca {library} respondeu na sua solicitação. Consulta o painel de rede.',
      'A biblioteca {library} respondeu na sua solicitação. Consulte o painel de rede.',
    ],
  },
  'supabase/functions/_shared/core/env.ts': {
    'FOOTER_TEXT (repli)': [
      'Mensagem automática da biblioteca. Responde apenas se o campo de resposta indicar um contato local.',
      'Mensagem automática da biblioteca. Responda apenas se o campo de resposta indicar um contato local.',
    ],
  },
};

const compte = (texte, motif) => texte.split(motif).length - 1;
// Un littéral TypeScript de ces fichiers s'écrit "…" (échappements JSON) ou
// `…` (les introHtml de task-mail-strings.ts, qui contiennent des guillemets).
const formes = (v) => [JSON.stringify(v), `\`${v}\``];

let reecrites = 0;
let dejaVoce = 0;
const autres = [];
const ambigues = [];
for (const [rel, entrees] of Object.entries(DE_PARA)) {
  const fichier = path.join(RACINE, rel);
  const avant = fs.readFileSync(fichier, 'utf8');
  let src = avant;
  for (const [cle, [de, para]] of Object.entries(entrees)) {
    const fDe = formes(de);
    const fPara = formes(para);
    const i = fDe.findIndex((f) => compte(src, f) > 0);
    if (i >= 0 && compte(src, fDe[i]) === 1) {
      src = src.replace(fDe[i], () => fPara[i]);
      reecrites++;
    } else if (i >= 0) {
      ambigues.push(`${rel} → ${cle}`);
    } else if (fPara.some((f) => compte(src, f) > 0)) {
      dejaVoce++;
    } else {
      autres.push(`${rel} → ${cle}`);
    }
  }
  if (src !== avant) fs.writeFileSync(fichier, src);
}
console.log(`courriels pt-BR : ${reecrites} réécrite(s), ${dejaVoce} déjà au « você »`);
if (autres.length) console.log(`modifiées depuis, ni « tu » ni la version de ce script (laissées) :\n  ${autres.join('\n  ')}`);
if (ambigues.length) {
  console.error(`littéral d'avant présent plusieurs fois (rien touché pour ces clés) :\n  ${ambigues.join('\n  ')}`);
  process.exit(1);
}
