# Welcome to the AnarBib network

**Welcome guide for coordinations — the first thirty days**

*Version 1.0 — 16 September 2026 · AGPLv3 licence · `anarbib@proton.me` · [Matrix](https://matrix.to/#/!RfxYttorZNdTIZXIRJ:matrix.org?via=matrix.org)*

---

## Before anything else: what has been accepted, and what has not yet

Your library's application has been accepted by the network coordination. That means two
things, and two things only:

1. The network recognises your library as part of the anarchist and libertarian family it
   welcomes, and it has opened the path of constitution to you.
2. Your account is no longer an applicant account: it is a **coordination in
   constitution** account.

What has **not** yet happened: your library is not active. It does not appear in the
shared catalogue, it does not take in readers, it exchanges nothing with the other
libraries. It is **pre-active**, and you are the one who will bring it out of that state —
not alone, and not in a single day.

> **The promise of this guide.** You do not need to be a librarian. You do not need to
> know anything about computing. You need to know what your collective wants, and to have
> someone to ask when you do not know. The rest is clicking.
>
> **And the golden rule: click, it will not break anything.** The software does not
> display impossible transitions, it disables with an explanation the buttons a rule would
> block, and it refuses impossible combinations in the database. The few gestures that
> really do not come back are listed in chapter 9.

**The person to talk to.** At any moment of this journey, before deciding and not after:
`anarbib@proton.me`. The network holds it as a principle that a constitution decision is
discussed with a comrade before it becomes a form. Writing is not an admission of weakness
— it is how things normally work.

---

## 1. Day 1 — Log in, and understand where you are

### 1.1 Logging in

The login page is `/login` (button **Sign in**). The address `/cadastro` only redirects to it: if an
old document sends you there, it is not your mistake.

If you are still using the temporary password received by email, **change it before
anything else**. As long as it has not been changed, several actions stay blocked — it is
passive proof that the account has really been taken in hand by a person.

### 1.2 The two houses

This is the most important thing in the whole guide, and it is worth learning by heart.

| If the question is… | You go to… |
|---|---|
| “what did we decide?” | **`/biblioteca`** — the collective house |
| “what do I do with this person in front of me?” | **`/painel`** — the counter |

In `/biblioteca` live the public identity, the bylaws, the team, the adoption profile, the
transitions and privacy: everything the collective has deliberated. In `/painel` lives the
everyday work: loans, returns, consultations, reservations, accounts awaiting validation.

This is not an arbitrary tidying-up. Many library systems mix the two, and the result is
that political configuration ends up hidden in an administrator's back office. Here,
deliberation is on one side and operation on the other.

### 1.3 The routes you will use

| Route | What it is | For whom |
|---|---|---|
| `/criar-conta` | registration — **the only way in, for everyone** | anyone |
| `/conta` | each reader's personal space — nine tabs | each person, their own |
| `/atelier` | the workshops: constitution and authorities | coordination in constitution |
| `/painel` | the counter, the work of the day | team (librarian, coordination) |
| `/biblioteca` | the collective house, the decisions | team, with powers by role |
| `/catalogacao` | cataloguing and importing | team |
| `/rede` | network administration | network admins only |

The **Federação** page and the public pages — catalogue, Work, Periodical, Subject,
Libraries, Cartography, FICEDL Thesaurus — complete the set. The routes are not
translated: they are the same in the ten languages.

> **You never enter someone else's account.** Everything the team has to do for a reader
> is in the painel. If you have caught yourself wanting to “log in as” someone, what you
> are looking for is in the painel, tab **Reader** (`leitor`).

---

## 2. Days 1 to 3 — The constitution workshop

The constitution is a journey inside `/atelier`. You can save at any moment and come back
later: nothing is lost between two sessions. **You have 60 days**, and an email reminder
arrives on the 45th.

### 2.1 Step 0 — the adoption profile, the founding act

Before all the other sections, the software asks where your library places itself on
**four independent axes**. None of them is a level of quality: they are ways of existing,
and a small library that chooses the simple mode everywhere is not an unfinished library.

**Axis 1 — `catalog_mode`, the catalogue**

- `local_only` — the collection stays at home, not exposed to the network. Useful during a
  running-in period, or when part of the collection is not ready to be published.
- `network_published` — the collection enters the shared AnarBib catalogue.

**Axis 2 — `circulation_mode`, circulation**

- `off` — no circulation managed in the software: catalogue only. This is the case of a
  heritage collection for consultation.
- `informal` — simple circulation, without membership fees or strict rules. The typical
  case of a small militant library where everyone knows each other.
- `full_sigb` — full circulation: rules, reservations, membership fees, suspensions.

**Axis 3 — `network_mode`, federation**

- `isolated` — the library exists inside AnarBib but exchanges nothing.
- `observer` — it receives the network's flows, it does not contribute yet.
- `federated` — it takes part fully.

**Axis 4 — `governance_mode`, governance**

- `informal` — no distinct team role: everyone is a reader. No co-option, no waiting
  period, no audit log.
- `staff_roles` — the `librarian` and `coordinator` roles exist, simplified co-option.
- `full_governance` — the whole set: co-option, waiting period, audit log, crons.

### 2.2 What each choice lights up in the painel

This table is the reason why step 0 comes before everything else. The counter's tabs
appear or not according to the circulation axis:

| Painel tab | Appears if |
|---|---|
| **Work of the day** (`trabalho-do-dia`) | always |
| **Actions** (`acoes`) | always |
| **Reader** (`leitor`) | always |
| **History** (`historico`) | always |
| **Local consultations** (`consultas-locais`) | circulation `informal` or `full_sigb` |
| **Loans** (`emprestimos-livro`) | circulation `informal` or `full_sigb` |
| **Reservations** (`reservas`) | circulation `full_sigb` |
| **Batch loans** (`emprestimos-lote`) | circulation `full_sigb` |
| **Contributions** (`contribuicoes`) | membership fee enabled **and** circulation other than `off` |

If a tab does not appear for you, it is not a breakdown: it is the profile your collective
chose. And if the profile changes during a session, the painel goes back on its own to the
**Work of the day**.

> **Choices are not prisons.** Each axis has its own transition doctrine — some fast, some
> slow, some irreversible. The **Transitions** tab is in `/biblioteca`, and not in the
> painel: changing profile is a collective decision, not a counter gesture. Certain
> transitions that cross several axes go through validation by the network admins.

### 2.3 The ten sections

After step 0, the workshop only displays the sections your profile makes relevant. A
library in `circulation_mode = off` will not see the circulation section: nothing is
missing, it is that this question does not arise for you.

| Section | What is decided | Condition |
|---|---|---|
| 1 | Identity — name, short name, address, contact | always |
| 2 | Opening hours and staffed times | always |
| 3 | People in charge | according to governance |
| 4 | Cataloguing policy | always |
| 5 | Circulation policy | if circulation is not `off` |
| 6 | Reader membership policy | according to governance and circulation |
| 7 | Email policy | always |
| 8 | Visibility and participation in the network | if the network is not `isolated` |
| 9 | Data and privacy | always |
| 10 | Generation of the bylaws | always |

**None of these sections is a computing question.** They are ten assembly questions,
presented in the order in which they are well answered. Fill them in with what the
collective has already decided; where it has not decided, stop and take the question to
the next meeting. The workshop waits.

### 2.4 Section 10 — the bylaws skeleton

At the end, the software produces a PDF pre-filled with all your choices. **This PDF is
not a certificate.** It is a skeleton to be discussed: raw material for deliberation. The
sections that deserve debate are marked as such.

The expected journey is: download, take to the assembly, amend freely, and re-upload the
amended document as the library's official bylaws. As long as it has not been re-uploaded,
the library stays pre-active.

> **A point of honesty.** “Concluding the constitution” does not amount, today, to
> automatic activation of the library. It is a known gap in the software, not a mistake on
> your part. When you reach the end of the sections, write to `anarbib@proton.me` so
> that activation is done — and insist if nobody answers within a few days.

---

## 3. Days 3 to 7 — The Biblioteca page, the collective house

Once the constitution is finished, `/biblioteca` becomes the place where what was decided
stays written down and holds. It is where you look when someone asks “but what did we
agree on?”.

- **Public identity** — what the network and the public see of your library.
- **Bylaws** — the document you adopted, and its versions.
- **Team** — who is what, and through which circuit (chapter 4).
- **Profile** — the four axes, as they stand today.
- **Transitions** — profile change proposals and their vote.
- **Privacy** — data retention, automatic purge, GDPR/LGPD.

**The decisions to settle this week**, all in `/biblioteca`:

1. **The visibility of the collection** — public catalogue or not, appearance in the
   library gallery of `anarbib.org`, presence on the network's cartography. On the
   cartography, a collective that chooses not to appear has its reasons: the software
   respects them, and so do you.
2. **The email policy** — which events trigger a message to the reader (loan cycle,
   reminders before the due date, overdue notices) and whether the team receives a copy.
   All of this is switched on and off library by library.
3. **Data retention** — how long a person's loan history is kept after the return. It is a
   political question as much as a legal one: in a militant library, a history is a
   reading list of identified people. Keeping little is a form of protection.
4. **The membership fee**, if it exists in your house — and with it the **Contributions**
   tab of the painel.
5. **The reader card** — if you enable it. It carries no name: only the library's short
   name and an opaque QR code, and it is the reader who generates and regenerates it. It
   was designed that way on purpose, so that a lost card tells nothing about whoever
   carried it.

> **About the Privacy tab.** It can display two messages that contradict each other about
> the automatic purge. It is a known display defect. Before concluding that the purge is
> active or inactive, ask the network.

---

## 4. Days 5 to 10 — Building the team

### 4.1 Three roles, and three only

`reader` · `librarian` · `coordinator` (coordination).

The local “administrator” role was withdrawn in May 2026. If you find it quoted somewhere,
the document is out of date. “AnarBib network administrator” exists, but it is a
**transversal status** — it is not the next rung on the ladder, and you do not get there by
coordinating for long enough. It is another political mechanism, with its own co-option.

### 4.2 The trap that costs dearly

**Nobody registers twice.** Everyone comes in a single time through `/criar-conta`, as a
reader — including those who will be part of the team.

Becoming team is not a new registration: it is a co-option, and it takes place on the
account that already exists. Whoever registers again thinking they will thereby “come in
as team” only creates a second account and a problem the coordination will have to undo.

**So the only thing to ask of whoever is joining the team is: “send me your public ID”.**

### 4.3 The three-step circuit

No promotion is unilateral. Three distinct people, three gestures:

1. **Propose** — the coordination proposes someone by their public ID, for the `librarian`
   or `coordinator` role.
2. **Endorse** — another person of the team ratifies. The person concerned is excluded
   from the quorum: as soon as the team counts two other active people, two ratifications
   are required.
3. **Accept** — the proposed person accepts. Without that consent, nothing happens.

The proposal **expires at 30 days**. A reader line closes, the librarian line opens: a
single active role per library, and the history stays.

> **The collegial leap.** By default, to enter the circle of the coordination you must
> have passed through librarian. For a horizontal collective, that intermediate step
> corresponds to nothing: a single assembly decision required two circuits in the
> software. Hence the leap — proposing someone directly from reader to the coordination —
> which exists as a **library option**, disabled by default, that your collective enables
> if it wants to. It shortens the ladder, never the consents.

### 4.4 Leaving the team

- **7-day waiting period** — leaving the team is not immediate; the person passes through
  an intermediate state, and that leaves time to talk to each other.
- **Inactivity** — a team account that has not logged in for a long time leaves
  automatically, with a notice to the person 30 days before and 7 days before. The 7-day
  notice also goes to the coordination, and it is escalated to the network admins if the
  inactive person is the last coordination of the house.
- **Handing over** — passing the coordination to someone else is done through the same
  three-step circuit, before leaving. Do not leave it to the last day.

---

## 5. Days 7 to 20 — The collection

### 5.1 The three words you need

- **Work** (*obra*) — the shared record: the book as a work, the same for the whole
  network.
- **Holding** — the fact that your library has that work.
- **Copy** — the physical object on the shelf, with its label, its condition, its history.

Three collectives can have the same book: one work, three holdings, several copies. That
is why correcting a record benefits the whole network, and why a record is corrected with
care.

### 5.2 Three record levels, and none is the wrong one

| Level | Spirit |
|---|---|
| **Simples** | militant library, with no academic pretension: type, title, authorship, year, publisher, language, shelfmark, default circulation, cover, ISBN |
| **Avançado** | librarian's work without MARC: subtitle, edition, series, place, pages, typed contributions, subjects, notes |
| **Completo** | exhaustive: ISBD zones, MARC, authority identifiers, full provenance |

**Changing level loses nothing.** A field hidden by a lower level keeps its value. Do the
test once, with your own eyes: that is what convinces.

**Start in Simples.** Five records a week in Simples are worth more than one perfect record
a month. The collection only exists once catalogued.

### 5.3 The only requirement the network really makes

**No new copy without an acquisition mode.** Where it came from, when, given by whom,
after which event.

It is not a scholarly detail. In a militant library, provenance is the history of the
collective. Without it, the collection becomes an anonymous pile in one generation. The
network does not ask you to do the retroactive catching-up — it asks that the debt stop
growing from now on.

### 5.4 The rest of `/catalogacao`, when you need it

Bulk imports, a three-step deduplication assistant, cover search, external metadata
sources, deposit with OCR in the browser, inventory by reading QR labels, periodicals and
their holdings statements. None of this is necessary in the first week. It is there when
the time comes.

### 5.5 Subjects and the FICEDL thesaurus

AnarBib carries the **FICEDL thesaurus** with it: 462 terms, translated into the ten
languages, delivered with the software. It is a common good of the federation, and it
arrives already filled in — it is not a task for you.

**Local subjects**, on the contrary, belong to each house: it is your collection, your
vocabulary, your editorial choices. And **aligning** your subjects to the FICEDL terms is
an act of the collective, not a technical operation: saying that your “penal abolitionism”
corresponds to the shared term “prison” is a documentary position. That is why the
alignment does not arrive ready-made.

---

## 6. Days 10 to 25 — The counter

Four flows, and the painel organises them:

- **Loan** — checkout, return (including partial), renewal. The renewal can be done item
  by item: if the person has finished two of the three books, only the third is renewed.
- **Return** — full or line by line. A bulk action never fails silently: what did not go
  through is listed with its reason.
- **Local consultation** — the person wants to see something on site, a slot is
  negotiated. **The negotiation stops at three back-and-forths**: beyond that, the
  software sends you to the telephone. It is deliberate — a negotiation that goes past
  that is not a software problem.
- **Reservation** — until the effective pickup, which turns the reservation into a loan.

Alongside that, in the painel: the **validations** of reader registrations (this is where
you decide who comes in), the **deposit** if your house practises it, the
**contributions**, the **reading notes**, the **events**.

> **A known defect.** The “Open loans” button of certain Work of the day tasks leads to an
> empty tab. It is not you. Go directly through the **Loans** tab (`emprestimos-livro`).

---

## 7. Days 20 to 30 — The federation

The **Federação** page has eight tabs: **Início**, **Círculos**, **Diretório**,
**Assembleias**, the gazette **Rizoma**, **Carta/Boletim**, **Apoio mútuo** and **Comuns**.

This is the part of the software that is not an ILS. It exists because the project does not
want to be a “SaaS for libraries”: entering AnarBib means entering a shared political
project, and a network that only exchanges bibliographic records is not a network.

What there is to do this last week, without haste:

1. **Moving from `observer` to `federated`**, if that is what you decided — and only if.
   Entering the network in observer mode for a few months is a respectable choice.
2. **Filling in your record in the Diretório**, so that the other houses know who you are
   and how to talk to you.
3. **Deciding about the cartography** — appearing with a precise address, only with the
   city, or not appearing. None of the three answers has to be justified.
4. **Looking at the Círculos and the Assembleias**, to know where the network's decisions
   are taken.
5. **If you publish the catalogue**, seeing with the network what the OAI-PMH endpoint
   means for you — it is through it that other catalogues can harvest yours.

The `/rede` page is network administration proper, reserved for the network admins.
Coordinating a library does not give access to it, and that is intended.

---

## 8. The ten decisions that are not technical

Cut out this list and take it to the assembly. None of these answers is in the software:
the software only records what you will answer.

1. Where do we place ourselves on the four axes of the profile?
2. Is our catalogue public?
3. Do we lend, and on what conditions?
4. Who can register as a reader, and who validates?
5. Do we have a membership fee? A deposit?
6. How long do we keep people's reading history?
7. Who is on the team, and do we enable the collegial leap?
8. Do we appear on the cartography, and with what precision?
9. Do we take part in the network's assemblies, and who represents us there?
10. How do we align our subjects to the shared thesaurus — and what do we refuse to
    align?

---

## 9. What breaks nothing, and what calls for a second reading

**Breaks nothing:** clicking everywhere, opening every tab, changing the record level to
see, saving a section half done, proposing a person and letting the proposal expire,
enabling and disabling the collegial leap, moving from `observer` to `federated`,
correcting a record.

**Calls for a second reading, because it does not come back or costs dearly:**

- **Deleting** an account — and beware: in Portuguese the software distinguishes **APAGAR**
  (emptying the history) from **EXCLUIR** (removing the account), with two different
  confirmation words. In the nine other languages the two fall on the same word — in
  English, **DELETE**. Read the whole sentence before typing, not just the word asked for.
- Erasing a history — the data does not come back.
- The profile transitions marked irreversible in the Transitions tab.
- Publishing to the network a collection the collective has not decided to publish.
- Removing someone from the team — the 7-day waiting period exists precisely for that.

---

## 10. Where to ask for help, and how to give back

**Asking for help:** `anarbib@proton.me`. Say which screen you are on and what you
expected to see. There is no stupid question: the software was written by one person, and
every “I could not find it” that comes back is an identified defect.

**A ritual that works.** Half an hour a week, with the team, three fixed questions:

> what did I not find on the screen? · what did I do without understanding? · what was
> missing in the software?

The answers feed a sheet of gaps that becomes the next agenda — and material for
contributing to the project. It is the only device that carries use up to the code.

**Giving back, without programming.** The `AIDER.md` file, at the root of the repository,
lists the open tasks that do not require code: translation, proofreading of inclusive
writing, documentation, subject alignment, screen testing. AnarBib is under AGPLv3 and has
today only one maintainer — that is its main fragility, and it is said out loud instead of
kept quiet.

---

## 11. The thirty days on one page

| When | What | Where |
|---|---|---|
| Day 1 | Log in, change the password, wander around without changing anything | `/login`, `/conta` |
| Days 1–3 | Step 0: the four axes, decided collectively | `/atelier` |
| Days 3–5 | Sections 1 to 9 | `/atelier` |
| Day 5 | Section 10: download the bylaws skeleton | `/atelier` |
| Days 5–10 | Take the bylaws to the assembly, amend, re-upload | assembly, then `/atelier` |
| Days 5–10 | Collect the public IDs, open the co-option circuits | `/biblioteca`, Team tab |
| Days 7–20 | First records in Simples mode, all with provenance | `/catalogacao` |
| Days 10–25 | First day at the counter on your own | `/painel` |
| Days 20–30 | Record in the Diretório, cartography, network mode | Federação, `/biblioteca` |
| Day 30 | Write to the network: what was missing, what misled | `anarbib@proton.me` |

---

*This guide exists in ten languages: pt-BR, fr, es, en, it, de, ca, eo, nl, el. It
describes the state of the software in September 2026 and will be corrected when the
software changes — if a screen does not match what is written here, it is the guide that
is wrong, and saying so is a contribution.*

**Welcome.**
