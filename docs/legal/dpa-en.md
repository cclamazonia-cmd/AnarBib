# Data Processing Agreement (DPA)

**Between AnarBib (processor) and the adhering library (controller)**

---

## Preamble

This agreement is signed between the **AnarBib** project and the
adhering library designated in Article 12. It is part of a specific
political and legal framework that needs to be made explicit before
detailing the articles.

**GDPR/LGPD compliance as a tool of protection.** Anarchist militant
libraries operate in contexts where state surveillance, police and
judicial repression, or hostile curiosity from economic actors may
directly target readers. Compliance with the European General Data
Protection Regulation (GDPR) and the Brazilian General Data
Protection Law (LGPD) is not, in this context, a neoliberal
alignment: it is a tactical use of law to protect those who entrust
us with their personal data. The obligations described in this
agreement (minimization, security, refusal of transfer without
basis) constitute a legal arsenal that can be mobilized in the
event of an abusive request from an authority.

**Coherence with anarchist ethics.** The principle of data
minimization (GDPR Article 5(1)(c)) coincides with the anarchist
concern not to accumulate information about people. We do not
collect or retain anything beyond what is strictly necessary for
the operation of the library. Short retention durations, refusal
to sell or communicate to third parties, transparency about our
sub-processors: all of this is both compliant with the law and
faithful to our political culture.

**Mutual commitment in a federative framework.** AnarBib is not a
company that sells a service to clients. It is a federative network
of autonomous libraries that share a technical infrastructure. This
DPA is not a commercial contract: it is an act of mutual commitment
between the AnarBib collective (which assumes technical
responsibility and data protection) and each adhering library
(which retains political control over its data and governance).
Each party remains autonomous. This agreement formalizes the
respective responsibilities within the framework of the technical
processing that AnarBib operates on behalf of the library.

---

## Article 1 — Subject

The adhering library entrusts AnarBib with the technical processing
of certain personal data necessary for the operation of its
integrated library management system (ILS), under the conditions
described in this agreement.

AnarBib acts as a **processor** within the meaning of Article 28 of
the GDPR and Article 39 of the LGPD. The adhering library is the
**controller** and remains sovereign with regard to decisions
concerning its data.

## Article 2 — Duration

This agreement enters into force on the date of signature and
remains valid as long as the adhering library uses the AnarBib
infrastructure.

The adhering library may terminate this agreement at any time
without penalty, by email notification to contato@anarbib.org.
AnarBib may terminate with 90 days' notice and will proceed
according to Article 10 of this agreement regarding the fate of
the data.

## Article 3 — Definitions

For the purposes of this agreement, the definitions of the GDPR
(Article 4) and the LGPD (Article 5) apply. In particular:

- **Personal data**: any information relating to an identified or
  identifiable natural person.
- **Processing**: any operation performed on personal data
  (collection, recording, retention, modification, consultation,
  communication, deletion, etc.).
- **Controller**: the person or entity that determines the purposes
  and means of processing — in this agreement, the adhering library.
- **Processor**: the person or entity that processes personal data
  on behalf of the controller — in this agreement, AnarBib.
- **Data subject**: the natural person to whom the personal data
  relates (in the library: readers, librarians, coordinators).

## Article 4 — Description of the processing

### 4.1 Categories of data processed

- Identity: first name, last name, email, phone (optional), gender
  (optional), address (optional)
- Technical identifiers: internal ID, public ID, preferred language
- Circulation data: loans, reservations, on-site consultations
  (with their history)
- Membership: dues status, dates, amounts paid
- Notifications: messages received in the application
- Wishlist: books marked by the reader

### 4.2 Categories of data subjects

- Readers who are members of the library
- Librarians and coordinators of the library
- People making a membership request without yet being members

### 4.3 Purposes

- Management of document circulation (loans, reservations, returns)
- Operational communication with readers (reminders, notices)
- Membership management (dues, memberships)
- Anonymous internal statistics for the operation of the library

### 4.4 Retention durations

In accordance with the minimization principle, the default durations
of the AnarBib network are:

- History of completed loans: 24 months
- History of completed reservations: 12 months
- History of completed on-site consultations: 12 months
- Read notifications: 90 days
- Profile and registration data: as long as the person's account
  exists

The adhering library may adopt shorter durations (or longer ones,
by justified collective decision) via the configuration page of
its library. The durations in force are published in the public
privacy policy.

## Article 5 — AnarBib's obligations (processor)

AnarBib commits to:

### 5.1 Process data only on documented instructions

AnarBib processes personal data only for the purposes described in
Article 4 and according to the configurations defined by the
library in its management interface. AnarBib does not use this data
for its own purposes.

### 5.2 Ensure the confidentiality of staff involved

People who access personal data on behalf of AnarBib (in particular
the main developer, Xavier Van Welden) commit on principle to
respect confidentiality. No access to data of a specific library is
made without documented technical necessity.

### 5.3 Implement appropriate security measures

AnarBib implements the following technical and organizational
measures:

- Encryption in transit (TLS) for all communications
- Password hashing (bcrypt via Supabase Auth)
- Row-level access control (Row Level Security PostgreSQL)
- Minimization principle applied by design
- Periodic audit of security policies

### 5.4 Communicate sub-processors

AnarBib uses the sub-processors listed in Article 7. Any addition
will be notified to the library by email with 30 days' notice. The
library may object to the addition in writing; in case of persistent
objection, this agreement may be terminated by the library.

### 5.5 Assist the library

AnarBib assists the adhering library to:

- Respond to data subject rights requests (access, rectification,
  deletion, portability)
- Comply with security obligations (Article 32 GDPR)
- Notify any data breach (Articles 33 and 34 GDPR)

The library can rely on the integrated tools (readers' "My account"
page, GDPR export in JSON+CSV format, direct account deletion)
that AnarBib maintains available.

### 5.6 Notify data breaches

In case of a personal data breach, AnarBib notifies the adhering
library without undue delay and at the latest within 72 hours after
becoming aware of it. The notification describes the nature of the
breach, the categories and approximate number of people and data
concerned, the measures taken or proposed, and the contact points.

The INCIDENT_RESPONSE.md document published in the AnarBib
repository details the operational procedure.

### 5.7 Return or delete data at the end of the contract

In accordance with Article 10 of this agreement.

## Article 6 — Library's obligations (controller)

The adhering library commits to:

### 6.1 Ensure the legality of processing

The library verifies that each processing it entrusts to AnarBib is
based on a valid legal basis (consent, contractual performance,
legitimate interest, etc.).

### 6.2 Inform data subjects

The library ensures that readers are informed about the processing
of their personal data. The AnarBib common privacy policy
(accessible at /privacidade) and the specific section possibly
published by the library constitute the information support. The
library may freely supplement this information by its own means.

### 6.3 Give legitimate instructions

The library will not give AnarBib instructions that contravene
applicable regulations. AnarBib may legitimately refuse to execute
a manifestly illegal instruction and will signal it in writing.

## Article 7 — Sub-processors

The adhering library authorizes AnarBib to use the following
sub-processors:

| Sub-processor | Function | Location | Status |
|---|---|---|---|
| **Supabase Inc.** | Database, authentication, storage, edge functions | AWS São Paulo (sa-east-1) | Specific DPA signed (ref TFXNN-HUMKJ-3WKP8-MZMYW, SCC 2021/914 module 2) |
| **Sendinblue (Brevo)** | Sending of transactional emails | EU (France) | Standard Brevo DPA |
| **Codeberg e.V.** | Frontend hosting (Codeberg Pages) | EU (Germany) | Does not process personal data (static frontend) |

Any modification of this list will be notified according to
Article 5.4.

## Article 8 — Transfers outside the EU/Brazil

The main location of the data is AWS São Paulo (Brazil), which does
not constitute a transfer outside Brazil under the LGPD.

For libraries established in the EU, the Brazilian location
constitutes a transfer outside the EU. This transfer is framed by
the Standard Contractual Clauses (SCC 2021/914 module 2) signed
with Supabase, which constitute an adequate safeguard within the
meaning of Article 46(2)(c) of the GDPR.

Brevo and Codeberg are established in the EU.

## Article 9 — Audit

The adhering library may request once a year an audit or inspection
of the measures taken by AnarBib in application of this agreement.
The modalities are defined by mutual agreement with at least 30
days' notice.

AnarBib makes available to the library:

- This agreement
- The REGISTRE_TRAITEMENTS.md document (records of processing)
- The INCIDENT_RESPONSE.md document (incident procedure)
- The source code (audit by design, open-source project)

## Article 10 — Fate of data at the end of the contract

At the end of this agreement (termination by either party, or
discontinuation of service use by the library), AnarBib will
proceed, according to the library's choice expressed in writing:

**Option A — Restitution**: AnarBib provides the library with a
complete export of the data in structured format (JSON+CSV) within
a maximum of 30 days.

**Option B — Deletion**: AnarBib proceeds with the deletion of all
of the library's data within a maximum of 30 days, and provides a
deletion certificate.

In the absence of any expression by the library within 30 days
after the end of the contract, option B (deletion) applies by
default.

Technical backups possibly containing this data are replaced by
rotation within a maximum of 90 days after the main deletion.

## Article 11 — Dispute resolution

In case of divergence of interpretation or application of this
agreement, the parties commit to seek primarily an amicable solution
through mediation. If mediation fails, each party retains its
freedom to resort to the legal channels applicable in its
jurisdiction.

No commercial arbitration clause is provided. This agreement does
not constitute a waiver of the rights of the library or of the
data subjects provided by applicable law.

## Article 12 — Signature

**Adhering library (controller):**

- Name: ____________________________________________
- AnarBib slug: ____________________________________
- Address: _________________________________________
- Contact email: ___________________________________
- Signatory person(s) (coordinators):

  - ______________________________________ (name, function)
  - ______________________________________ (name, function)

- Place and date: ___________________________________
- Signature(s):

**AnarBib (processor):**

- Represented by: Xavier Van Welden, main developer and
  administrator
- Email: contato@anarbib.org
- Place and date: ___________________________________
- Signature:

---

*This document constitutes the Data Processing Agreement under
Article 28 of the GDPR and Article 39 of the LGPD. Version 1.0 —
May 4, 2026. Document collectively elaborated, distributed under
CC-BY-SA-4.0 license.*
