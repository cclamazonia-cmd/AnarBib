# Acordo de Tratamento de Dados (DPA)

**Entre AnarBib (operador) e a biblioteca aderente (controlador)**

---

## Preâmbulo

Este acordo é assinado entre o projeto **AnarBib** e a biblioteca
adherente designada na seção 12. Ele se inscreve em um quadro
político e jurídico específico que importa explicitar antes de
detalhar os artigos.

**Conformidade ao RGPD/LGPD como ferramenta de proteção.** Bibliotecas
militantes anarquistas atuam em contextos onde a vigilância estatal,
a repressão policial e judicial, ou a curiosidade hostil de atores
econômicos podem visar diretamente as leitor(a/e)s. A conformidade
ao Regulamento Geral de Proteção de Dados europeu (RGPD) e à Lei
Geral de Proteção de Dados brasileira (LGPD) não é, neste contexto,
um alinhamento neoliberal: é um uso tático do direito para proteger
quem confia em nós seus dados pessoais. As obrigações descritas
neste acordo (minimização, segurança, recusa de transferência sem
fundamento) constituem um arsenal jurídico mobilizável em caso de
solicitação abusiva de uma autoridade.

**Coerência com a ética anarquista.** O princípio de minimização dos
dados (RGPD artigo 5(1)(c)) coincide com o cuidado anarquista de não
acumular informações sobre as pessoas. Não coletamos nem
conservamos nada além do estritamente necessário para o
funcionamento da biblioteca. As durações de retenção curtas, a
recusa de venda ou comunicação a terceiros, a transparência sobre
nossos sub-operadores: tudo isso é ao mesmo tempo conforme ao
direito e fiel a nossa cultura política.

**Engajamento mútuo em um quadro federativo.** AnarBib não é uma
empresa que vende um serviço a clientes. É uma rede federativa de
bibliotecas autônomas que partilham uma infraestrutura técnica.
Este DPA não é um contrato comercial: é um ato de engajamento mútuo
entre o coletivo AnarBib (que assume a responsabilidade técnica e a
proteção dos dados) e cada biblioteca aderente (que mantém o
controle político de seus dados e de sua governança). Cada parte
permanece autônoma. Este acordo formaliza as responsabilidades
respectivas no quadro do tratamento técnico que AnarBib opera por
conta da biblioteca.

---

## Artigo 1 — Objeto

A biblioteca aderente confia ao AnarBib o tratamento técnico de
certos dados pessoais necessários ao funcionamento de seu sistema
integrado de gestão bibliotecária (SIGB), conforme as condições
descritas no presente acordo.

AnarBib age como **operador** na acepção do artigo 28 do RGPD e do
artigo 39 da LGPD. A biblioteca aderente é o **controlador** e
permanece soberana quanto às decisões sobre seus dados.

## Artigo 2 — Duração

O presente acordo entra em vigor na data de assinatura e permanece
válido enquanto a biblioteca aderente utilizar a infraestrutura
AnarBib.

A biblioteca aderente pode rescindir este acordo a qualquer momento
sem penalidade, mediante notificação por e-mail ao endereço
contato@anarbib.org. AnarBib pode rescindir mediante aviso prévio
de 90 dias e procederá conforme o artigo 10 do presente acordo
quanto ao destino dos dados.

## Artigo 3 — Definições

Para os fins do presente acordo, aplicam-se as definições do RGPD
(artigo 4) e da LGPD (artigo 5). Em particular:

- **Dados pessoais**: qualquer informação relativa a uma pessoa
  física identificada ou identificável.
- **Tratamento**: qualquer operação efetuada sobre dados pessoais
  (coleta, registro, conservação, modificação, consulta, comunicação,
  exclusão, etc.).
- **Controlador**: a pessoa ou entidade que determina as finalidades
  e os meios do tratamento — neste acordo, a biblioteca aderente.
- **Operador**: a pessoa ou entidade que trata os dados pessoais por
  conta do controlador — neste acordo, AnarBib.
- **Titular**: a pessoa física a quem os dados pessoais se referem
  (na biblioteca: leitor(a/e)s, bibliotecári(o/a/e)s,
  coordenador(a/e)s).

## Artigo 4 — Descrição do tratamento

### 4.1 Categorias de dados tratados

- Identidade: nome, sobrenome, e-mail, telefone (opcional), gênero
  (opcional), endereço (opcional)
- Identificadores técnicos: ID interno, ID público, idioma preferido
- Dados de circulação: empréstimos, reservas, consultas locais
  (com seu histórico)
- Adesão: status de cotização, datas, valores pagos
- Notificações: mensagens recebidas no aplicativo
- Lista de desejos: livros marcados pelo(a/e) leitor(a/e)

### 4.2 Categorias de titulares

- Leitor(a/e)s aderentes da biblioteca
- Bibliotecári(o/a/e)s e coordenador(a/e)s da biblioteca
- Pessoas que fazem solicitação de adesão sem ser ainda aderentes

### 4.3 Finalidades

- Gestão da circulação dos documentos (empréstimos, reservas,
  devoluções)
- Comunicação operacional com as leitor(a/e)s (lembretes, avisos)
- Gestão associativa (cotizações, adesões)
- Estatísticas internas anônimas para o funcionamento da biblioteca

### 4.4 Durações de conservação

Conforme o princípio de minimização, as durações padrão da rede
AnarBib são:

- Histórico de empréstimos finalizados: 24 meses
- Histórico de reservas finalizadas: 12 meses
- Histórico de consultas locais finalizadas: 12 meses
- Notificações lidas: 90 dias
- Perfil e dados de cadastro: enquanto a conta da pessoa existir

A biblioteca aderente pode adotar durações mais curtas (ou mais
longas, mediante decisão coletiva justificada) por meio da página
de configuração de sua bibliothèque. As durações em vigor são
publicadas na política de privacidade pública.

## Artigo 5 — Obrigações de AnarBib (operador)

AnarBib se compromete a:

### 5.1 Tratar os dados unicamente sob instrução documentada

AnarBib trata os dados pessoais somente para as finalidades descritas
no artigo 4 e segundo as configurações que a biblioteca define em
sua interface de gestão. AnarBib não usa esses dados para finalidades
próprias.

### 5.2 Garantir a confidencialidade do pessoal envolvido

As pessoas que acessam os dados pessoais por conta de AnarBib (em
particular o desenvolvedor principal, Xavier Van Welden) se
comprometem por princípio a respeitar a confidencialidade. Nenhum
acesso a dados de uma biblioteca específica é efetuado sem
necessidade técnica documentada.

### 5.3 Implementar medidas de segurança apropriadas

AnarBib implementa as seguintes medidas técnicas e organizacionais:

- Criptografia em trânsito (TLS) para todas as comunicações
- Hashing das senhas (bcrypt via Supabase Auth)
- Controle de acesso por linhas (Row Level Security PostgreSQL)
- Princípio de minimização aplicado por design
- Auditoria periódica das políticas de segurança

### 5.4 Comunicar os sub-operadores

AnarBib utiliza os seguintes sub-operadores, listados no artigo 7.
Qualquer adição de sub-operador será notificada à biblioteca por
e-mail com 30 dias de antecedência. A biblioteca pode se opor à
adição manifestando-se por escrito; em caso de oposição persistente,
o presente acordo poderá ser rescindido por iniciativa da biblioteca.

### 5.5 Assistir a biblioteca

AnarBib assiste a biblioteca aderente para:

- Responder às solicitações de exercício de direitos das pessoas
  concernidas (acesso, retificação, exclusão, portabilidade)
- Cumprir as obrigações de segurança (artigo 32 RGPD)
- Notificar uma eventual violação de dados (artigos 33 e 34 RGPD)

A biblioteca pode contar com as ferramentas integradas (página
"Minha conta" das leitor(a/e)s, exportação RGPD em formato JSON+CSV,
exclusão de conta direta) que AnarBib mantém à disposição.

### 5.6 Notificar as violações de dados

Em caso de violação de dados pessoais, AnarBib notificará a
biblioteca aderente sem demora indevida e no máximo no prazo de 72
horas após constatação. A notificação descreverá a natureza da
violação, as categorias e o número aproximado de pessoas e dados
concernidos, as medidas tomadas ou propostas, e os pontos de contato.

O documento INCIDENT_RESPONSE.md publicado no repositório AnarBib
detalha o procedimento operacional.

### 5.7 Restituir ou excluir os dados em fim de contrato

Conforme o artigo 10 do presente acordo.

## Artigo 6 — Obrigações da biblioteca (controlador)

A biblioteca aderente se compromete a:

### 6.1 Garantir a legalidade dos tratamentos

A biblioteca verifica que cada tratamento que confia ao AnarBib
repousa sobre uma base legal válida (consentimento, execução
contratual, interesse legítimo, etc.).

### 6.2 Informar as pessoas concernidas

A biblioteca se assegura de que as leitor(a/e)s sejam informadas
sobre o tratamento de seus dados pessoais. A política de
confidencialidade comum AnarBib (acessível em /privacidade) e a
seção específica eventualmente publicada pela biblioteca constituem
o suporte de informação. A biblioteca pode completar livremente
essa informação por meios próprios.

### 6.3 Dar instruções legítimas

A biblioteca não dará a AnarBib instruções que contradigam a
regulamentação aplicável. AnarBib pode legitimamente recusar-se a
executar uma instrução manifestamente ilegal e o sinalizará por
escrito.

## Artigo 7 — Sub-operadores

A biblioteca aderente autoriza AnarBib a recorrer aos seguintes
sub-operadores:

| Sub-operador | Função | Localização | Status |
|---|---|---|---|
| **Supabase Inc.** | Banco de dados, autenticação, armazenamento, edge functions | AWS São Paulo (sa-east-1) | DPA específico assinado (ref TFXNN-HUMKJ-3WKP8-MZMYW, CCT 2021/914 módulo 2) |
| **Sendinblue (Brevo)** | Envio de e-mails transacionais | UE (França) | DPA padrão Brevo |
| **Codeberg e.V.** | Hospedagem do frontend (Codeberg Pages) | UE (Alemanha) | Não trata dados pessoais (frontend estático) |

Qualquer modificação dessa lista será notificada conforme o artigo 5.4.

## Artigo 8 — Transferências para fora da UE/Brasil

A localização principal dos dados é AWS São Paulo (Brasil), o que
não constitui uma transferência para fora do Brasil sob a LGPD.

Para as bibliotecas estabelecidas na UE, a localização brasileira
constitui uma transferência fora UE. Esta transferência é
enquadrada pelas Cláusulas Contratuais Tipo (CCT 2021/914 módulo 2)
assinadas com Supabase, que constituem garantia adequada nos termos
do artigo 46(2)(c) do RGPD.

Brevo e Codeberg estão estabelecidos na UE.

## Artigo 9 — Auditoria

A biblioteca aderente pode solicitar uma vez por ano uma auditoria
ou inspeção das medidas tomadas por AnarBib em aplicação do presente
acordo. As modalidades são definidas em comum acordo com pelo menos
30 dias de antecedência.

AnarBib põe à disposição da biblioteca:

- O presente acordo
- O documento REGISTRE_TRAITEMENTS.md (registro de tratamentos)
- O documento INCIDENT_RESPONSE.md (procedimento de incidente)
- O código fonte (auditoria por design, projeto de código aberto)

## Artigo 10 — Destino dos dados em fim de contrato

No final do presente acordo (rescisão por uma ou outra parte, ou
parada de utilização do serviço pela biblioteca), AnarBib procederá,
conforme a escolha da biblioteca expressa por escrito:

**Opção A — Restituição**: AnarBib fornece à biblioteca uma
exportação completa dos dados em formato estruturado (JSON+CSV) em
um prazo máximo de 30 dias.

**Opção B — Exclusão**: AnarBib procede à exclusão de todos os dados
da biblioteca em um prazo máximo de 30 dias, e fornece um
certificado de exclusão.

Em caso de ausência de manifestação da biblioteca dentro de 30 dias
após o fim do contrato, a opção B (exclusão) se aplica por padrão.

Os backups técnicos contendo eventualmente esses dados são
substituídos por rotação no prazo máximo de 90 dias após a
exclusão principal.

## Artigo 11 — Resolução de litígios

Em caso de divergência de interpretação ou de aplicação do presente
acordo, as partes se engajam a buscar prioritariamente uma solução
amigável por mediação. Se a mediação fracassar, cada parte mantém
sua liberdade de recorrer aos meios legais aplicáveis em sua
jurisdição.

Nenhuma cláusula de arbitragem comercial é prevista. O presente
acordo não constitui uma renúncia aos direitos da biblioteca ou das
pessoas concernidas previstos pelo direito aplicável.

## Artigo 12 — Assinatura

**Biblioteca aderente (controlador):**

- Nome: ____________________________________________
- Slug AnarBib: ____________________________________
- Endereço: ________________________________________
- E-mail de contato: _______________________________
- Pessoa(s) signatária(s) (coordenador(a/e)s):

  - ______________________________________ (nome, função)
  - ______________________________________ (nome, função)

- Local e data: ____________________________________
- Assinatura(s):

**AnarBib (operador):**

- Representado por: Xavier Van Welden, desenvolvedor principal e
  administrador
- E-mail: contato@anarbib.org
- Local e data: ____________________________________
- Assinatura:

---

*Este documento constitui o Acordo de Tratamento de Dados nos
termos do artigo 28 do RGPD e do artigo 39 da LGPD. Versão 1.0 —
4 de maio de 2026. Documento elaborado coletivamente, distribuído
sob licença CC-BY-SA-4.0.*
