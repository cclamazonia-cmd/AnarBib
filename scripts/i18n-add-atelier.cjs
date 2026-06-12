/* ===========================================================================
 * i18n-add-atelier.cjs
 * Ajoute les clés du wizard « Oficina de constituição » (atelier) aux 10 locales.
 * pt-BR embarqué ; ca/de/el/en/eo/es/fr/it/nl lus de /tmp/atelier_9loc.json
 * (production de l'agent de traduction). Méthode sûre : insertion textuelle
 * avant le `}` final, idempotente. Sentinelle = atelier.title.
 * Auteur  : Xavier (AnarBib) — Session : Wizards onboarding & federation
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'atelier.title';

const PT = {
  "atelier.title": "Oficina de constituição",
  "atelier.pageTitle": "Oficina de constituição",
  "atelier.subtitle": "constituição em curso",
  "atelier.empty": "Nenhuma constituição em curso para a sua conta.",
  "atelier.empty.sub": "nada a constituir no momento",
  "atelier.applicCount": "{count, plural, one {# volet aplicável ao seu perfil} other {# volets aplicáveis ao seu perfil}}",
  "atelier.voletLabel": "VOLET {n}",
  "atelier.stageTitle": "Volets de constituição",
  "atelier.locked": "Comece pelo Volet 0 (perfil de adoção): ele decide quais volets se aplicam.",
  "atelier.card.moot": "Não se aplica ao perfil escolhido — nada a preencher.",
  "atelier.status.todo": "a discutir",
  "atelier.status.done": "discutido ✓",
  "atelier.status.moot": "sem objeto",
  "atelier.completeBtn": "Concluir a constituição ✓",
  "atelier.completed": "Constituição concluída.",
  "atelier.deadline": "Prazo de constituição: restam {days, plural, one {# dia} other {# dias}} — você pode salvar e voltar quando quiser.",
  "atelier.deadline.frozen": "Prazo de constituição ultrapassado. Fale com a coordenação da rede para retomar.",
  "atelier.progress.title": "Avanço coletivo",
  "atelier.progress.sub": "volets discutidos em conjunto",
  "atelier.doctrine.tag": "Decisão coletiva",
  "atelier.doctrine.title": "Aqui, ninguém decide sozinho.",
  "atelier.doctrine.text": "Esta constituição é um ato político, não um formulário administrativo. Sentem-se em vários·as diante da tela e pesem os prós e os contras juntos·as. Uma escolha tomada sozinha será revista na primeira objeção — então é melhor decidir em conjunto desde já.",
  "atelier.human.tag": "Canal humano · antes de clicar",
  "atelier.human.mailSubject": "[AnarBib] Oficina de constituição",
  "atelier.human.requestExchange": "Pedir uma conversa com um·a camarada da rede",
  "atelier.human.volet0": "Este volet é o ato fundador da sua biblioteca no AnarBib. Os 4 eixos que você vai escolher determinam como sua biblio funcionará — podem mudar depois, mas por um processo coletivo. Antes de clicar, conversemos: a gente ajuda a traduzir o funcionamento real do seu coletivo em eixos.",
  "atelier.human.volet1": "Identidade da biblio. Tudo aqui é modificável depois. Mas se você quer conversar sobre como apresentar sua biblio publicamente (nome, descrição…), escreva pra gente.",
  "atelier.human.volet2": "Horários e plantões. Sua biblio pode ter funcionamentos atípicos (reuniões semanais, presença sob demanda…). Se não tem certeza de como representar isso aqui, conversemos.",
  "atelier.human.volet3": "As pessoas que se engajam. Se sua biblio é informal, você não precisa nomear papéis. Mas se está em dúvida sobre como representar o coletivo, conversemos.",
  "atelier.human.volet4": "A política de catalogação é uma decisão política. Que sistema de classificação? Que normas? Como nomear autores·as autônomos·as? Isso engaja o coletivo por muito tempo. Antes de clicar, conversemos.",
  "atelier.human.volet5": "Aqui você define como os livros circulam. Empréstimo? Consulta no local? Cotização? Reservas? Essas decisões mudam profundamente a relação entre sua biblio e os·as leitor·as. Antes de clicar, conversemos com um·a camarada da rede.",
  "atelier.human.volet6": "Como alguém se torna leitor·a da sua biblio. Inscrição livre ou encontro obrigatório? Cotização? Essas escolhas dizem muito sobre o vínculo que você propõe. Em dúvida, conversemos.",
  "atelier.human.volet7": "Política de e-mails. Identidade de envio, assinatura, idioma das notificações. Pouco configurante, mas se quiser afinar, escreva pra gente.",
  "atelier.human.volet8": "Visibilidade na rede. O que você partilha com as outras bibliotecas anars. Se tiver dúvida sobre o que expor, conversemos.",
  "atelier.human.volet9": "Dados pessoais é um terreno político. Que dados você vai conservar sobre seus·suas leitor·as? Por quanto tempo? Conhece a regulação aplicável (LGPD no Brasil, RGPD na Europa)? A rede tem um quadro mínimo, mas você pode (e deve) reforçá-lo. Antes de clicar, conversemos.",
  "atelier.human.volet10": "O regulamento que você vai gerar aqui é um esqueleto — tem que ser discutido em assembleia. Não é um certificado de conclusão técnica: é um documento político que sua biblio se dá. Quer que a gente releia antes da assembleia? Escreva.",
  "atelier.volet0.vnum": "VOLET 0",
  "atelier.volet0.title": "Perfil de adoção",
  "atelier.volet0.sub": "O ato fundador. Os quatro eixos abaixo decidem quais volets seguintes se aplicam à sua biblioteca.",
  "atelier.volet0.confirm": "Confirmar o perfil de adoção",
  "atelier.volet0.update": "Atualizar o perfil",
  "atelier.volet0.saved": "Perfil confirmado",
  "atelier.volet0.incomplete": "Escolha uma opção em cada um dos 4 eixos antes de confirmar.",
  "atelier.volet_1_identite.title": "Identidade",
  "atelier.volet_1_identite.sub": "Nome, descrição, idioma, identidade visual da biblioteca.",
  "atelier.volet_2_horaires.title": "Horários e plantões",
  "atelier.volet_2_horaires.sub": "Quando a biblioteca abre, quem está de plantão.",
  "atelier.volet_3_pessoas.title": "Pessoas responsáveis",
  "atelier.volet_3_pessoas.sub": "Quem compõe a equipe e com quais papéis.",
  "atelier.volet_4_catalogacao.title": "Política de catalogação",
  "atelier.volet_4_catalogacao.sub": "Sistema de classificação, campos obrigatórios.",
  "atelier.volet_5_circulacao.title": "Política de circulação",
  "atelier.volet_5_circulacao.sub": "Regras de empréstimo, durações, suspensões.",
  "atelier.volet_6_adhesion.title": "Adesão de leitores·as",
  "atelier.volet_6_adhesion.sub": "Como uma pessoa se torna leitora da biblioteca.",
  "atelier.volet_7_emails.title": "Política de e-mails",
  "atelier.volet_7_emails.sub": "Identidade de envio, assinatura, idioma das notificações.",
  "atelier.volet_8_visibilidade.title": "Visibilidade na rede",
  "atelier.volet_8_visibilidade.sub": "O que você partilha com as outras bibliotecas anars.",
  "atelier.volet_9_dados.title": "Dados e confidencialidade",
  "atelier.volet_9_dados.sub": "Retenção dos dados, conforme LGPD/RGPD.",
  "atelier.volet_10_regimento.title": "Regimento",
  "atelier.volet_10_regimento.sub": "O documento a discutir em assembleia — não um certificado.",
  "atelier.panel.reuseLabel": "Reutiliza o componente de produção",
  "atelier.panel.reuseHint": "Em produção, este volet abrirá o componente real. Por enquanto, ele serve para registrar a discussão coletiva.",
  "atelier.panel.markDone": "Marcar como discutido em coletivo ✓",
  "atelier.panel.markDoneHint": "« Discutido em coletivo » confirma que a escolha foi pesada em conjunto, não decidida sozinho·a.",
  "atelier.panel.saveLater": "Salvar e continuar depois",
  "atelier.regimento.banner": "O regimento abaixo é um esqueleto para discutir — não um certificado. Baixe, discuta em assembleia, emende livremente, e só então faça o upload.",
  "atelier.regimento.download": "Baixar o esqueleto de regimento (PDF)",
  "atelier.regimento.uploadLabel": "Link do regimento validado em assembleia",
  "atelier.regimento.uploadHint": "Cole o link do regimento final (após validação coletiva). O upload de arquivo chega em breve.",
  "atelier.regimento.save": "Registrar o regimento",
  "atelier.toast.profileSaved": "Perfil de adoção salvo.",
  "atelier.toast.markedDone": "Volet marcado como discutido em coletivo ✓",
  "atelier.toast.saved": "Salvo — você pode voltar quando quiser.",
  "atelier.toast.regimentoSaved": "Regimento registrado.",
  "atelier.toast.completed": "Constituição concluída. 🎉",
  "atelier.axis.catalog": "Catálogo",
  "atelier.axis.circulation": "Circulação",
  "atelier.axis.network": "Rede",
  "atelier.axis.governance": "Governança",
  "atelier.axisValue.local_only": "Local",
  "atelier.axisValue.network_published": "Publicado na rede",
  "atelier.axisValue.off": "Nenhuma",
  "atelier.axisValue.informal": "Informal",
  "atelier.axisValue.full_sigb": "SIGB completo",
  "atelier.axisValue.isolated": "Isolada",
  "atelier.axisValue.observer": "Observadora",
  "atelier.axisValue.federated": "Federada",
  "atelier.axisValue.staff_roles": "Com papéis",
  "atelier.axisValue.full_governance": "Completa",
  "atelier.pdf.title": "Esqueleto de regimento da biblioteca {name}",
  "atelier.pdf.subtitle": "documento a discutir em assembleia — não é um regulamento final",
  "atelier.pdf.preamble": "Este documento é gerado pelo AnarBib como ajuda à constituição da sua biblioteca. Não é um regulamento final: toda emenda coletiva é legítima e esperada. Leve-o à assembleia, discuta-o, emende-o livremente, e só então faça o upload da versão final.",
  "atelier.pdf.profileHeading": "Perfil de adoção (Volet 0)",
  "atelier.pdf.toDiscuss": "[A DISCUTIR]",
  "atelier.pdf.annexHeading": "Modificações coletivas feitas em assembleia",
  "atelier.pdf.annexBody": "Espaço a preencher pelo·a coordenador·a após a assembleia: o que o coletivo emendou, acrescentou ou retirou.",
  "atelier.pdf.footer": "AnarBib · esqueleto de regimento — documento a discutir em assembleia",
};

const nine = JSON.parse(fs.readFileSync('/tmp/atelier_9loc.json', 'utf8'));
const BYLOCALE = { ...nine, 'pt-BR': PT };

// Parité stricte : chaque locale doit avoir exactement les clés de pt-BR.
const refKeys = Object.keys(PT).sort();
for (const loc of LOCALES) {
  const k = Object.keys(BYLOCALE[loc] || {}).sort();
  if (JSON.stringify(k) !== JSON.stringify(refKeys)) {
    const miss = refKeys.filter(x => !(BYLOCALE[loc] || {})[x]);
    const extra = k.filter(x => !PT[x]);
    throw new Error(`Parité KO sur ${loc} — manquantes: ${miss} | en trop: ${extra}`);
  }
}

let total = 0;
for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (content.includes('"' + SENTINEL + '"')) { console.log(`${loc}: déjà présent, sauté.`); continue; }
  const map = BYLOCALE[loc];
  const entries = refKeys.map(k => '  ' + JSON.stringify(k) + ': ' + JSON.stringify(map[k]));
  const marker = content.lastIndexOf('}');
  const head = content.slice(0, marker).replace(/\s*$/, '');
  const tail = content.slice(marker);
  content = head + ',\n' + entries.join(',\n') + '\n' + tail;
  if (!content.endsWith('\n')) content += '\n';
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  total += entries.length;
  console.log(`${loc}: +${entries.length} clés, JSON valide.`);
}
console.log(`\nTerminé. ${total} insertions (${refKeys.length} clés × locales).`);
