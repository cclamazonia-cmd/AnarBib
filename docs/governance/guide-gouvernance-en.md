---
title: "AnarBib Governance Guide"
subtitle: "For library coordinators and network administrators"
author: "Projet AnarBib"
date: "Version 1.1 — 5 June 2026"
lang: en
---

# Foreword

This guide is addressed to the people who, within the AnarBib network, hold a coordination role — whether they coordinate a local library or administer the network. It has a twofold purpose:

- **Explain the political logic** behind the rules encoded in the AnarBib ILS, and their connection to the project of collective emancipation that gave rise to anarchist libraries;
- **Support everyday practice**, by answering the concrete questions that coordinators encounter when using the software.

## A political convention

This guide is not the network's rulebook, and it holds no authority superior to the decisions of the collectives that make up the network. What it contains only has force because human beings agreed to make things work this way at a given moment. If practices evolve, this text will need to evolve with them, or be contradicted, or be torn up. The collectives' use of it will decide its fate.

The technical rules that the AnarBib ILS enforces — the waiting periods, the co-optation workflows, the membership statuses, etc. — are also conventions. They were written by comrades at specific dates, to solve specific problems. They are recorded in **specification files** (the `spec-*.md` files in the repository), dated and signed, which are themselves amendable. When one reads this guide, one reads the state of a debate at a given moment. It is not a constitution.

## How this guide is organised

The guide is in two parts:

- **Part I — The why.** Four chapters setting out the political framework: what an anarchist ILS is for, what its founding principles are, how the two scopes (local library and network) relate to each other, and how the rules themselves can be amended.

- **Part II — The how.** Six practical chapters, each addressing a major operational question: co-opting, removing, handling situations that go wrong, exercising a network admin role, ensuring transparency, and a final chapter that walks through concrete cases end to end.

At the end of each practical chapter, a section called **"If the rule is a problem for you"** recalls where to discuss it and how to propose an amendment. This matters because these rules only make sense if they are amendable.

The annexes at the end of the volume serve as quick reference: glossary, index of technical functions with their political translation, amendment proposal template, and links to the source specs.

## How to read this guide

It can be read straight through, but that is probably not the best use. Three ways into the text depending on your needs:

- **To understand the spirit of the project** before taking on a role: read Part I (chapters 1 to 4).
- **Faced with a concrete situation**: jump directly to the relevant practical chapter (5 to 10).
- **To prepare for a general assembly** where a governance question will be raised: read the relevant chapter plus the corresponding "If the rule is a problem for you" section, and consult the source spec in annex D.

What is written here draws on four specification documents:

- `spec-gouvernance-roles.md` (5 May 2026) — roles, statuses, transitions;
- `spec-administrateur-reseau.md` (11 May 2026) — local/network separation, unanimous co-optation;
- `spec-validation-physique.md` (3 May 2026) — methods for onboarding reader accounts;
- `spec-refactor-v3-semantique.md` (9 May 2026) — reservation workflow semantics (mentioned in passing).

References to these specs are given throughout the text in the form `(cf. spec-gouvernance, §3.4)` to allow further reading.

## A note on voice

The text alternates between **one** (the AnarBib collective, of which both the author and the reader are part), **you** (when addressing a specific coordinator or admin who has a choice to make), and **we** (when speaking of the comrades who wrote the rules at a given moment, who may differ from those reading them). This is intentional. There is no institutional neutrality here: this text is carried by comrades, and it is addressed to comrades.

\newpage

# Part I — The why

\newpage

# 1. What does an anarchist ILS actually mean?

## 1.1. The ILS is not the general assembly

The first principle to hold onto, and the hardest, is this: **the ILS records the collective's decisions, it does not make them**. This sentence sounds innocuous. It is in reality the pivot around which everything else is organised.

Every time the AnarBib ILS appears to act as an authority — when it refuses a promotion, when it imposes a seven-day waiting period, when it blocks a status transition — it is merely **making executable** a rule that the collectives gave themselves. The rule was written somewhere, in a spec, after discussion. Someone read it and criticised it. A version was frozen and deployed. And now, in the moment when you click the button, the software simply applies what was agreed.

If you find the rule stupid, counterproductive, or unjust, it is not the ILS you should fight. It is the spec you should amend. See chapter 4.

## 1.2. The assumed tension

Any software that manages permissions is, by construction, a device for creating hierarchy. Someone has to be able to validate a registration, modify a library's public identity, access a reader's personal data. This technical necessity is in apparent tension with the ideal of horizontality that animates anarchist libraries.

AnarBib **assumes this tension** rather than hiding it. The political compromise that was found rests on two points:

- **Roles are not ranks.** They are **functions** temporarily delegated by the collective to some of its members in order to carry out specific technical tasks. Nobody is a coordinator "for life". Nobody is a network admin "by nature". These functions are on loan, and they can be taken back.

- **Withdrawal mechanisms** matter as much as nomination mechanisms. The ILS explicitly provides for how someone leaves a function — through voluntary self-demotion, through a collective request with a waiting period, through self-withdrawal from the network, through unanimous collective withdrawal. A function that cannot be left is not a function, it is a capture.

## 1.3. Delegation and rotation

The central idea is **delegation with rotation**. A collective delegates to some of its members the execution of technical tasks (managing loans in the ILS, changing the library's visibility, welcoming a new member into the team). This delegation is:

- **Explicit**: it takes the form of a co-optation act traced in the audit log;
- **Reversible**: the delegated person can leave the function whenever they wish, and the collective can ask them to do so according to established procedures;
- **Temporary by nature**: even if no duration is imposed by the ILS, the network's political culture is that functions rotate, and people do not settle into them.

It is this rotation of functions that makes the difference between a "delegation" (anarchist) and a "hierarchy" (statist or capitalist). If you settle into a function, you become a rung. If you step out of it regularly, you remain a comrade rendering a service.

## 1.4. The eight founding principles

The roles governance spec (`spec-gouvernance-roles.md`, §2) sets out eight founding principles. They are listed here for reference throughout the rest of the guide; each practical chapter in Part II will refer back to them.

**P1 — Delegation, not hierarchy.** No role is a title. All roles are temporary by nature and revocable.

**P2 — Co-optation for staff roles.** Entry into a team (becoming `librarian` or `coordenador`) happens through co-optation by existing `coordenadores`. It is the collective's place to decide who is admitted; the coordinator is merely the hand that executes the decision in the ILS.

**P3 — Voluntary demotion always possible.** Anyone with a staff role can demote themselves at any time, without consultation. "I'm stepping back" is a fundamental right.

**P4 — Exclusion governed by a waiting period.** Non-voluntary exclusion of a `librarian` by a `coordenador` passes through a seven-day waiting period before taking effect. This period allows collective deliberation and possible cancellation by another coordinator.

**P5 — Maximum transparency.** The audit log of role changes is readable by the entire active staff of the library, not only by `coordenadores`. Preventing opaque manipulation is part of the political culture of informational horizontality.

**P6 — Systematic notifications.** Every role change triggers an email to the person concerned and to the entire coordination. Nobody can have their role changed without knowing it, and the coordination is always informed.

**P7 — Local sovereignty of libraries.** Role changes in library A affect nothing in library B, even for the same person. Each library is sovereign over its internal delegations.

**P8 — The ILS does not model the general assembly.** The ILS executes decisions, it does not make them. It contains no mechanism for voting, quorum, or deliberation. Those things happen collectively, outside the software.

## 1.5. What the ILS does not do

It is useful to make explicit the choices of **non-modelling**:

- The ILS **does not define** what "good" coordination looks like. A library can decide by circle, by plenary assembly, by rotation, by lottery, by consensus, by majority. The ILS does not care.
- The ILS **does not measure** the political legitimacy of a co-optation. If a coordinator clicks "promote X to `librarian`", the ILS records it. It is the collective's responsibility to ensure the decision was made correctly, and that assurance lives in the collective's political culture.
- The ILS **does not arbitrate** conflicts. When something goes wrong, the ILS provides tools (immediate suspension, withdrawal request, readable audit log) but the political decision remains outside the software.

This modesty is not a defect, it is a requirement. An ILS that claimed to model the political life of a collective would, ipso facto, be authoritarian — it would impose its vision of what a "good" decision looks like. AnarBib refuses that slope.

## 1.6. And what about digital freedoms?

Three clarifications, because the question recurs:

- **Personal data**: reader accounts contain what the person has chosen to put there. Libraries have access only to data strictly necessary for their operation. Memberships in other libraries are, by construction, compartmentalised (P7).

- **Audit log**: the log is public **to the active staff** of the library, not to readers or to the rest of the network. This internal transparency serves to prevent opaque manipulation between coordination teams; it is not a panopticon directed against readers.

- **Cross-library logs**: when a network admin intervenes on a library (case covered by spec-administrateur-reseau, §6.3.1), the action is traced in a dedicated table with a criticality level. This is readable by network admins and by the coordination of the library concerned. Transparency in both directions.

\newpage

# 2. The two scopes: local library and network

## 2.1. Why this separation

The AnarBib network is not a chain of libraries with a central headquarters. It is a **federation of autonomous collectives**. This political reality eventually imposed itself on the structure of the ILS itself.

Initially, in early versions, the role of "AnarBib administrator" was attached to a specific library in the `user_library_memberships` table. This modelling implied — without saying so — that an AnarBib admin *administered a library*. That was not politically true: a network admin coordinates inter-library work, they do not lead any particular library.

The `spec-administrateur-reseau.md` spec (11 May 2026) formalised the separation. The ILS now recognises **two distinct scopes**:

- **The local staff** of a library (roles `reader`, `librarian`, `coordenador`), stored in `user_library_memberships`. Their political authority sits **within the library's scope**.

- **Network administration** (table `network_administrators`), with no attachment to any library. Their political authority is **transversal**, but it never substitutes for local autonomy.

## 2.2. What each scope does

**Local staff** manages a library's day-to-day work: loans, returns, reservations, validating registrations, modifying the rules, circulation policies, and the library's public identity. Everything concerning the operation of **one** library is handled at the level of local staff.

**Network administration** ensures inter-library coordination: activating new libraries, moderating the shared catalogue, maintaining the platform technically, onboarding new collectives, and intervening exceptionally when a library finds itself blocked (no active coordinator, major conflict, etc.). Everything concerning the **network** is handled at the level of network administration.

## 2.3. The non-overlap rule

A simple political rule guides all the counters and views in the ILS:

> **Each page tells the story of its scope. A counter counts what is registered within its scope, nothing more, nothing less.**

Concretely:

- A library's page counts its local memberships. Full stop. Network admins do not appear in these counters, even if they can technically intervene on the library.
- The network page counts its network administrators. Full stop.

If a person is both a `coordenador` of a library **and** a network administrator (Xavier's situation as of 11 May 2026), they appear in both counters, **once in each**, without cross-deduplication. These are **two distinct political registrations**, each counted within their own scope.

Why this rule is politically sound, in four points:

- **Honesty**: your local engagement is counted in the library where you are active; your network engagement is counted at the network level. Nobody counts you "1.5 times".
- **Legibility**: an activist looking at a library's page immediately sees how many people are engaged **locally**, without having to wonder whether "external" network admins are inflating the count.
- **Robustness**: if tomorrow intermediate roles are added (auxiliary, trainee, observer), the rule "page = scope" remains clear.
- **Political coherence**: the separation between network admin and local staff is a **political decision**, not a modelling detail. Counters must reflect it.

## 2.4. The network admin's transversal right

This point deserves to be well understood because it is easy to misinterpret.

**A network admin can technically intervene on any library.** They can, for example, read the catalogue of a `private` library, modify its visibility, or — in exceptional cases — create or modify memberships. This is what the spec calls the **transversal right of intervention**.

This right exists for two reasons:

- **Maintenance**: someone has to be able to unblock a library that has broken down (no coordinator, broken configuration, etc.).
- **Mediation**: when a serious conflict runs through a library and prevents the local collective from functioning, there must be a recourse.

But this right does **not** make the network admin a hierarchical superior of the local coordination. The network's doctrine, as set out in this guide:

> **A network admin's intervention on a local library must be preceded by informing the local coordination concerned**, except in vital emergencies (active compromise, ongoing harassment, attack against the platform). Prior notification is not a request for authorisation: the network admin has the right to act. But it is a **mark of respect** for the library's autonomy, and it preserves the possibility of another arrangement (for example: "let me try to sort this out first, I'll keep you posted").

Technical traceability exists in any case: all cross-library actions by a network admin are traced in the `cross_library_actions_log` table with a criticality level, readable by the local coordination after the fact.

## 2.5. Local sovereignty is inviolable

A final political clarification, which follows from principle **P7 — Local sovereignty of libraries**.

The libraries in the AnarBib network **mutually recognise one another**. When BLMF physically validates a new reader (cf. `spec-validation-physique.md`), this validation is valid for all `network` libraries in the network. It is an **implicit circulation pact** between libraries that share enough political culture to trust one another.

But this mutual recognition **gives no right of interference** of one library in another. Library A's coordination cannot modify library B's memberships. It cannot see the personal data of B's readers (except those who are also registered with them). It cannot change B's rules.

Each library remains **sovereign over its internal delegations**, its onboarding policy, its validation method, its membership rules, its internal regulations. The network does not tell them how to operate. It only says with whom they recognise each other.

\newpage

# 3. Statuses, roles, transitions: the grammar of the ILS

This chapter is a little more arid than the others. It establishes the technical vocabulary that will be used throughout the guide. If you skip it on a first read, you can come back to it as needed.

## 3.1. The four roles

The AnarBib ILS uses four roles, declared in the database by the constraint `CHECK (role = ANY (ARRAY['reader', 'librarian', 'coordenador', 'administrador']))` on the `user_library_memberships` table.

**`reader`** — Basic reader account. No administrative power. Permissions: browse the catalogue (according to the library's visibility settings), borrow, reserve, consult in-house, modify their own personal data, request account migration or deletion.

**`librarian`** — Operational staff. Handles day-to-day operations: loans, reservations, returns, registration validation (depending on the library's mode), catalogue data editing, access to the personal data of the library's readers. **Read-only** access to the team list. Receives notifications of role changes and can read the team audit log (P5).

**`coordenador`** — Coordination staff. Everything a `librarian` has, plus: modifying the library's public identity (name, logo, contact, etc.), modifying configuration (lending policies, regulations), managing membership rules, **and all team governance actions**: co-opting, requesting removal, suspending, lifting a suspension, cancelling a removal request.

**`administrador`** — Historical role, being phased out. It existed to denote "cross-library administration rights" but was tied to a `library_id`. Now replaced by **network administrators** stored in the `network_administrators` table (see chapter 2). The network-admin spec provides for a gradual migration and the eventual removal of this role from the `user_library_memberships` table.

## 3.2. The five statuses of a membership

Each row in the `user_library_memberships` table has a **status** expressing the state of the delegation at a given point in time. Five statuses are possible:

**`active`** — Normal state. The person has their role and exercises it.

**`pending`** — Reserved for the physical validation spec. The membership is created but awaiting a physical meeting with a `librarian`+ from the registration library. No access to role functions while in this status.

**`suspended`** — **Precautionary measure** taken by a coordinator. No access. Use cases: reported harassment pending investigation, compromised account, conflict under mediation. **Indefinite duration**; lifting is manual, by a coordinator (back to `active`) or by effective removal.

**`pending_removal`** — **Seven-day grace period** before effective exclusion. No access during this period. Possible outcomes: cancellation by another coordinator (back to `active`), self-downgrade by the person themselves (short-circuit), or automatic transition to `inactive` at D+7.

**`inactive`** — Closed membership. The person is no longer on the team. No access. Several possible origins: voluntary exit, end of grace period, abandoned account (automatic after 9 months).

## 3.3. The transition diagram

The ILS does not allow arbitrary transitions between statuses. Here, simplified, is the permitted diagram:

```
                       ┌──────────────┐
                       │   active     │ ◄──────────┐
                       └──────┬───────┘            │
                              │                    │
              ┌───────────────┼───────────────┐    │
              ▼               ▼               ▼    │
       ┌─────────────┐  ┌─────────────┐  ┌─────────┴────┐
       │  suspended  │  │ pending_    │  │  inactive    │
       │             │  │ removal     │  │              │
       └──────┬──────┘  └──────┬──────┘  └──────────────┘
              │                │
              │ lifted         │ cancelled
              └────────────────┴────────────┐
                               │            │
                               ▼ (D+7)      ▼
                        ┌──────────────┐
                        │   inactive   │
                        └──────────────┘
```

A few key rules:

- It is **not** possible to go directly from `active` to `inactive` for a `librarian` by unilateral decision of another coordinator. The process must go through `pending_removal` and wait out the grace period (or for the person to self-downgrade).
- It is **always** possible to transition from one's own `active` status to `inactive` (self-downgrade, right P3).
- `suspended` has **no** maximum duration. It is not a grace period before exclusion — it is a precautionary measure that lasts as long as deliberation takes.
- From `inactive`, one **cannot** return to `active`. To reintegrate someone, a new membership row is created. History is preserved.

## 3.4. The nine transitions — who can do what

The roles governance spec formalises nine transitions, listed here in condensed form. Operational detail is in Part II.

| # | Transition | Who | Mechanism |
|---|---|---|---|
| T1 | `reader` → `librarian` | Coordinator+ | Co-optation |
| T2 | `librarian` → `coordenador` | Coordinator+ | Co-optation |
| T3 | `coordenador` → `librarian` | Self OR other coordinators | Self-downgrade OR collegial removal with grace period |
| T4 | `librarian` → `reader` (voluntary) | Self | Self-downgrade |
| T5 | `librarian` → `reader` (collective) | Coordinator+ | `pending_removal` with 7-day grace period |
| T6 | Immediate suspension | Coordinator+ | Transition to `suspended` |
| T7 | Lifting of suspension | Coordinator+ | Return `suspended` → `active` |
| T8 | Cancellation of a removal request | Coordinator+ | Return `pending_removal` → `active` |
| T9 | Automatic exit (abandoned account) | Cron | Transition to `inactive` after 9 months without login |

Three principles structure this table:

- **Entry goes through co-optation** (T1, T2). No one promotes themselves.
- **Voluntary exit is always possible** (T3 self, T4). No one is trapped in a role they no longer wish to fulfil.
- **Imposed exit is slowed by the grace period** (T5). Seven days to allow for possible collegial reconsideration.

## 3.5. On the network admin side: a twin diagram

Network administration (table `network_administrators`) has its own lifecycle, structurally very close but with two specificities:

- **Unanimous co-optation**: to add a new network admin, a proposal is opened by an active admin, and **all other active admins** must vote `favorable`. A single `opposed` vote (with a mandatory rationale of at least 20 characters) blocks the proposal. An abstention also blocks as long as it has not been converted into a vote.

- **Unanimous collective removal**: to remove a network admin against their will, the same workflow applies in mirror form. With a grace period of **seven days** after unanimous agreement (field `pending_collective_removal_until`).

Self-removal, by contrast, is **unilateral and always possible** (except when one is the sole active admin, in which case the transition goes through `pending_removal` with a 30-day grace period and an alert email to the other admins).

Full details in chapter 8.

\newpage

# 4. Reversibility and amendability

This short chapter addresses a crucial political question: **how can these rules be modified?** If they could not be, the ILS would be an authority, and the rest of this guide would be a lie.

## 4.1. Three levels of amendability

Three levels of rules must be distinguished, which are not amended in the same way:

**The local practices of a library** — welcome policy, physical validation mode (`open` or `manual_validation`), internal regulations, frequency of general assemblies, co-optation procedures. These practices are **internal to each library**. The network does not interfere. They are amended at the library's general assembly, or according to whatever procedure the collective has established.

**Network rules** — local/network separation, the principle of unanimous co-optation for network admins, the doctrine of prior information during cross-library interventions, the conditions for activating new libraries. These rules are **inter-library**. They are amended in network coordination, after discussion between network admins and the relevant local coordinations.

**The political foundations of the project** — the eight principles (P1 to P8 from chapter 1), the idea that the ILS does not model the general assembly, the avowed modesty of the software in the face of the political life of collectives. These foundations can be amended, but they are structural: modifying them is probably modifying what we call "AnarBib" in the broad sense. A challenge of this magnitude would require collective discussion across the whole network, probably at an event (annual gathering, etc.).

## 4.2. How to propose an amendment

There is no single way to do it — each level has its own — but here is the general pattern the network tends to follow:

1. **Identify the relevant spec**. The ILS rules are recorded in `spec-*.md` files in the repository. Find the one that contains the rule you want to amend (Appendix D provides the correspondences).

2. **Draft an amendment note**. Free format, but addressing: which rule, why it is problematic, what modification is proposed, what technical and political consequences are anticipated. Appendix C offers a template.

3. **Circulate the note**. Depending on the level:
   - **Local**: at the library's general assembly, or on the collective's discussion channel.
   - **Network**: on the inter-library coordination channel (Matrix `#anarbib`), tagging the relevant network admins and local coordinations.
   - **Foundations**: on all channels, and probably on the agenda of a gathering.

4. **Discuss, amend, agree on a version**. The ILS does not prescribe how this step should unfold. That is the business of the collectives.

5. **If the decision is made**: a network admin or a developer (often the same person or people) implements the modification in the corresponding spec, then in the code. The new version is deployed according to the usual procedure (changelog, communication, etc.).

## 4.3. If the technical decision is problematic

It sometimes happens that there is political agreement on a rule, but that its technical translation is complicated, burdensome, or has undesirable side effects. This is normal. The existing specs are full of notes like "this political decision requires touching 22 sub-SELECTs in the RLS, which justifies a prior refactoring". The political/technical dialogue is constant.

When you propose an amendment, do not hesitate to do so even if you have no idea of the technical difficulty. The network's developers will tell you what it costs. And if it is very costly, you can collectively decide whether the political stakes justify the technical cost. Conversely, sometimes a trivial political change makes it possible to greatly simplify the codebase.

## 4.4. This guide is itself amendable

This guide is versioned. The current version is indicated on the cover page. If you find that it says something wrong, that it has missed a case, or that it takes a position that no longer corresponds to the network's doctrine, **say so**. Open a discussion, propose a modification, or rewrite the passage and submit it.

A guide that cannot be modified is not a guide — it is dogma. The AnarBib project has no vocation to produce dogma.

\newpage

# Part II — The how

\newpage

# 5. Co-opting someone into your team

This chapter covers transitions T1 (`reader` → `librarian`) and T2 (`librarian` → `coordenador`), that is, the **two entry movements** into a library team. The physical validation of a new `reader` (which is not a co-optation in the political sense but a technical onboarding operation) is addressed separately in §5.5.

## 5.1. The political principle

> **P2 — Co-optation for staff roles.** Entry into a team happens by co-optation from the existing coordinators. It is for the political collective to decide who is admitted; the coordinator is merely the hand that executes the decision in the ILS.

This means that **clicking "Promote"** is not a personal decision by the coordinator who clicks. It is the **technical execution** of a decision that has been made — or must be made — by the library's political collective. The network's doctrine on "exactly when" the decision must be made is deliberately left unresolved by this guide: each library establishes its own doctrine (see §5.4).

## 5.2. To bring someone in as a `librarian` (T1)

### Preconditions

- The person has an AnarBib account (they are registered somewhere in the network).
- They do not already have an active `librarian` or `coordenador` membership in the same library.
- They may or may not already have a `reader` membership in the same library. If so, that existing membership will remain active in parallel (multi-membership is permitted).

### Procedure in the ILS

1. Go to `/biblioteca`, **Team** tab (visible to `coordenador+`).
2. If the person is already a reader of the library, click **"Invite to team"** on their row. If they are not yet a reader, use the search in the top bar — or, if they do not yet have an account, use the email invitation workflow (coming soon, see `spec-invitation-equipe.md`).
3. Choose the `librarian` role.
4. Confirm the modal. A "Reason" field is optional — it serves to record in the audit log the context of the co-optation (for example "GA decision of 04/05" or "co-optation in restricted circle, to be ratified at the next GA").
5. The ILS executes:
   - Creation of a `user_library_memberships` row with `role='librarian'`, `status='active'`.
   - Email to the person: "You have been appointed librarian of [library] by [you]".
   - Email to all active coordinators of the library.
   - Audit log entry: `action='promoted_to_librarian'`.

### Immediate effect

The person receives, without delay, the `librarian` permissions: loan management, registration validation, access to the personal data of the library's readers, etc. They do not receive permissions to modify the public identity or configuration — those are reserved for `coordenador+`.

### Technical side

RPC involved: `fn_team_promote_to_librarian(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.3. To promote a `librarian` to `coordenador` (T2)

### Preconditions

- The person has an `active` `librarian` membership in the library.
- They do not already have an active `coordenador` membership in the same library.

### Procedure in the ILS

1. Go to `/biblioteca`, **Team** tab.
2. On the person's row, click **"Promote"** → **"coordenador"**.
3. Confirm the modal. The "Reason" field is optional.
4. The ILS executes:
   - Creation (or reactivation) of an `active` `coordenador` row. The former `librarian` row remains active in parallel (multi-membership; see §5.6).
   - Email to the person.
   - Email to all active coordinators.
   - Audit log entry: `action='promoted_to_coordenador'`.

### Immediate effect

The person receives, in addition to their `librarian` permissions, the coordination permissions: modification of public identity, configuration, membership rules, and all team governance actions.

### Technical side

RPC involved: `fn_team_promote_to_coordenador(p_user_id uuid, p_library_id uuid, p_reason text DEFAULT NULL)`.

## 5.4. The political question: when to click?

This is the question every coordinator asks themselves the first time. The AnarBib network **has deliberately left this question unresolved** at the guide level: each library establishes its own doctrine, because the political culture of an anarchist collective cannot be decided at the level of a generic guide.

Here are the three doctrines found in the network, without judgement:

**Doctrine 1 — Strict waiting.** One only clicks **after** a formally recorded collective decision (GA, circle, formal consensus, whatever the modality). The coordinator merely executes. Advantage: maximises horizontality, strong political traceability. Disadvantage: can be slow, particularly when the library is just getting started or when the collective is dispersed.

**Doctrine 2 — Bounded anticipation.** The coordinator may anticipate a decision they consider certain ("it's obvious that Voltairine is going to be co-opted, they've been coming every week for six months"), **provided they make this explicit in the audit log**: reason = "anticipation under my responsibility, to be ratified at the next GA". The decision may be challenged after the fact, and removal is always possible. Advantage: practical flexibility. Disadvantage: shifts a share of political responsibility onto the coordinator who clicks.

**Doctrine 3 — Coordinator circle.** Co-optation is decided by agreement among the library's active coordinators, without going through the plenary GA. Argument: the coordination is itself a deliberating collective, and it has the mandate to act. Advantage: intermediate between 1 and 2. Disadvantage: can become opaque if the coordination is not itself renewed.

**Our recommendation** (and nothing more): **explicitly choose** a doctrine, write it into your library's regulations, and indicate it in the "Reason" field of the audit log at each co-optation (e.g. "doctrine 2 — anticipation under my responsibility"). Opacity is rarely good in politics.

## 5.5. Special case: physical validation of a `reader`

The **arrival** of a `reader` into a library is an operation different from co-optation in the political sense. It is covered by the spec `spec-validation-physique.md`.

Two modes are possible, chosen by each library in its configuration:

**Mode `open`** — Validation is **automatic** at registration. Once the account is created and the email confirmed, the `reader` immediately has access to `public` and `network` catalogues. Suited to libraries with low political exposure.

**Mode `manual_validation`** — The account is created online but remains **pending** until a **physical meeting** between the `reader` and a `librarian+` from the registration library. Suited to exposed libraries (tense political context, sensitive collections, fragile premises, etc.).

### Physical validation procedure (mode `manual_validation`)

1. The person registers online and chooses your library as their home library.
2. Their account is created with `status='pending'`. They receive an email explaining that they must come in person to the library.
3. When they come, a `librarian+` meets them, checks whatever needs to be checked (the doctrine of what "checking" means is local), and clicks **"Validate"** on their row in the **Team** tab → **Pending accounts** section.
4. An optional "Note" field allows a context to be recorded ("meeting of 12/05 during the open session, introduced by Emma").
5. The account moves to `status='active'`. The person receives a welcome email.

### Political note

- Physical validation at one library **applies to the whole network** of `network` libraries (P7 nuanced: local sovereignty concerns internal delegations, but mutual recognition is an explicit pact).
- What is "checked" during a physical validation is **not** an identity check in the administrative sense. It is a meeting. Each library defines its political meaning. For some, it means "we chat a bit to check the person is not a cop or a fascist". For others, it means "we present the library, how it works, its rules". For still others, it simply means "we meet in person so that the relationship is embodied".
- A library can **change mode** at any time (`coordenador+`). The change does not invalidate existing validations.

## 5.6. Multi-membership: a point to be aware of

A technical particularity to understand: a person can have **several** membership rows in the same library, with different roles. For example, Voltairine can be both a `reader` and a `librarian` at BLMF. This is made possible by the UNIQUE constraint on the triplet `(user_id, library_id, role)`.

**Why this possibility:** it preserves history. If Voltairine downgrades from `librarian` to `reader` tomorrow, their `librarian` row moves to `inactive` but the `reader` row remains — without having to recreate a new registration from scratch.

**Practical consequence:** in the UI, the person is displayed **only once**, with their **highest active role** (administrador > coordenador > librarian > reader). In the audit log, however, each row is visible separately.

## 5.7. Errors and safeguards

A few cases that come up regularly:

**"The ILS tells me the person is already a librarian."** This is probably true. Check the **Team** tab: if the person already appears there as a librarian, you are trying to promote them to the same level; the ILS returns a silent success (`{ok: true, no_change: true}`) because there is nothing to do.

**"I can't see the person in the list."** Three possible cases: (a) they do not yet have an AnarBib account (use the email invitation workflow, coming soon); (b) they have an account but are not registered in any library (they must register at your library as a `reader` first); (c) they are in the network but filtered out by the search — try their exact email address.

**"I accidentally clicked Promote."** Do not panic. Use **"Request removal"** to open a 7-day grace period (see chapter 6), or ask the person to click **"Step down"** (immediate self-downgrade). Indicate "accidental click" as the reason.

**"The person is not receiving the email."** First check the spelling of their email in their profile, and ask them to check their spam folder. If the problem persists, speak to a network admin: it is likely a mail configuration issue to investigate.

## 5.8. If this chapter's rules bother you

Several things in this chapter may not suit you:

- **The principle of co-optation itself** (P2). You believe that any engaged `reader` should be able to freely switch to `librarian` without needing co-optation. This is a fundamental political debate, touching on principle P1. Bring it to the network coordination channel and probably discuss it at a gathering.

- **The absence of a definitive doctrine on "when to click"** (§5.4). You think the guide should recommend a single doctrine. Or conversely, you feel it suggests too many. Propose an amendment to this chapter, with arguments.

- **The physical validation modes** (§5.5). You think a third mode is needed ("deferred validation", "remote validation", other). Bring it to `spec-validation-physique.md`.

- **Multi-membership** (§5.6). You think it is unnecessarily complex and that a single role per person per library would be better. This is a data model decision, more structural than it appears. Bring it to the developers.

See chapter 4 for the general amendment procedure, and Appendix C for the note template.

\newpage

# 6. Stepping down, withdrawing, suspending

This chapter covers transitions T3 through T8 — that is, **everything that removes a person from a team**, or puts them on pause. Politically, this is probably the most important chapter in the guide, because withdrawal mechanisms are at the heart of the anarchist project (cf. chapter 1, §1.2).

## 6.1. The political principles

Three principles structure this chapter:

> **P3 — Voluntary demotion always possible.** Any person with a staff role can demote themselves at any time, without consultation. "I'm stepping down" is a fundamental right.

> **P4 — Exclusion governed by a waiting period.** The involuntary exclusion of a `librarian` by a `coordenador` goes through a seven-day waiting period before taking effect. This period allows collective deliberation and possible cancellation by another `coordenador`.

> **P6 — Systematic notifications.** Any role change triggers an email to the person concerned and to the entire coordination team.

The underlying idea is that no one is ever removed from a team "by surprise" or "in silence". Either the person decides for themselves (and it is immediate), or the collective requests it (and it is tracked, notified, and open to deliberation until the last second).

## 6.2. Stepping down: self-demotion (T3 and T4)

This is the **most fundamental right** in AnarBib's governance system. Any person who holds a staff function can, at any time, without any consultation, leave it.

### When to use it

- You no longer have time to carry out the function.
- You no longer identify with the coordination's decisions.
- You disagree with a decision and want to dissociate yourself from it.
- You simply want to rotate the function.
- You need a break.
- No reason required, in fact. The right to leave is unconditional.

### Procedure

1. Go to `/biblioteca`, **Team** tab.
2. On **your own row**, click **"I'm stepping down"**.
3. Choose the level of demotion:
   - If you are `coordenador`, you can choose "return to librarian" (you remain on the team as `librarian`) or "leave the team" (you return to `reader`).
   - If you are `librarian`, you can choose "leave the team" (you return to `reader`).
4. The modal recalls the consequences. Confirm.

### Immediate effect

- Your current membership (`librarian` or `coordenador`) changes to `inactive`.
- If you did not already have the target membership (`reader` or `librarian`), it is created at `active`.
- Email to the entire coordination team + to yourself (confirmation).
- Audit log: `action='self_demoted'`.

### Special case: you are the sole active coordinator

The SIGB **lets you leave**, but it warns you:

> ⚠️ WARNING: you are the sole active `coordenador` of [library]. The library will be left without coordination. AnarBib network administrators will be notified. Continue?

If you confirm:
- Your coord membership changes to `inactive`.
- The library enters **degraded mode**: `librarian` members can continue to manage loans, validate registrations, etc., but no modification of the public identity or configuration is possible until a new coordinator is co-opted.
- Email to all network administrators: "Library X no longer has a `coordenador`. Current active librarians are: ..."

Politically, this is important: the SIGB **does not prevent** your departure. But it informs the network, so that a network administrator can, if you wish and if the local collective needs it, get in touch to help organise the transition. This is the rotation of functions in action.

### Technical side

RPC: `fn_team_self_demote(p_library_id uuid, p_target_role text DEFAULT 'librarian')`.

## 6.3. Requesting the withdrawal of a `librarian` (T5)

When the collective decides that a person must leave the team, and that person does not demote themselves, a **withdrawal request with a seven-day waiting period** is opened.

### Preconditions

- You are an active `coordenador+` of the library.
- The target person has an `active` `librarian` or `coordenador` membership.
- You are not the target person (otherwise use §6.2).

### Procedure

1. Go to `/biblioteca`, **Team** tab.
2. On the person's row, click **"Request withdrawal"**.
3. The modal that opens is **red and emphatic**. It recalls:
   - The waiting period: "This request will take effect on [date D+7] unless cancelled by another `coordenador`."
   - The reversible nature: "Cancellable by any coordinator until the effective date."
   - The collegial nature: "All active coordinators will be notified."
4. A **"Reason"** field is mandatory — minimum 20 characters. No silent withdrawal. The reason can be political ("GA decision of 04/05") or practical ("announced geographical departure"). It will be readable by all staff in the audit log.
5. Confirm.

### Immediate effect

- The membership changes to `pending_removal`.
- Field `pending_removal_until` = `now() + 7 days`.
- Field `pending_removal_requested_by` = you.
- **No access** for the person during the waiting period (the membership is frozen as `suspended`).
- Email to the person concerned: "The coordination has requested your withdrawal from the [library] team (notice until [date]). This decision falls within the organic life of the [library] collective; for any discussion, address the coordination."
- Email to all active coordinators: with your name and the reason.
- Audit log: `action='removal_requested'` with your `actor_user_id` and the `reason` field.

### Effect at D+7 (automatic cron)

If the request has been neither cancelled nor short-circuited:
- The membership changes to `inactive`.
- Final email to the person and the coordination: "Withdrawal effective."
- Audit log: `action='removal_completed'`.

### Technical side

RPC: `fn_team_request_remove_member(p_user_id, p_library_id, p_role, p_reason)`. Cron: `cron_team_pending_removal_complete` (runs daily).

## 6.4. Cancelling a withdrawal request (T8)

The **collegial safeguard** of the system. Any coordinator — not necessarily the one who made the request — can cancel a withdrawal request during the waiting period.

### When to use it

- The collective discussion led to a different decision (mediation, temporary suspension instead, etc.).
- The initial request was made in the heat of the moment and the coordination wants to take a collegial step back.
- The target person has finally been reached and the situation has been defused.

### Procedure

1. Go to `/biblioteca`, **Team** tab, **Suspensions and notices in progress** section.
2. On the row of the person in `pending_removal`, click **"Cancel the request"**.
3. Simple confirmation modal. Optional "Reason" field.
4. Confirm.

### Immediate effect

- The membership returns to `active`.
- Field `pending_removal_until` reset to NULL.
- Email to the person: "The withdrawal request has been cancelled. Your prerogatives are restored."
- Email to the entire coordination team.
- Audit log: `action='removal_cancelled'` with your `actor_user_id`.

### Politically

Cancellation is deliberately very easy to activate. It is a **collegial rebalancing mechanism**: if a coordinator requested a withdrawal in the heat of the moment, any other coordinator can pause execution while the collective deliberates. This makes withdrawal requests less weighty (no irreversible drama) but also less casual (anyone can contradict you). That is the point of the waiting period.

### Technical side

RPC: `fn_team_cancel_remove_member(p_user_id, p_library_id, p_role)`.

## 6.5. Immediate suspension: the precautionary measure (T6 and T7)

Suspension is a **different** tool from a withdrawal request. It is **immediate**, with no waiting period, and **with no maximum duration**. It is not an exclusion, it is a **pause**.

### When to use it

Typical cases provided for in the spec:

- **Compromised account**: there is reason to believe the person's password has leaked. Suspend while waiting for them to change their password.
- **Urgent reported harassment**: a reader reports abusive behaviour by a staff member. Suspend pending collective investigation.
- **Manifestly abusive behaviour** observed in real time: suspend while the coordination convenes.
- **Conflict under mediation**: the person is voluntarily paused while the mediation concludes.

### Procedure

1. Go to `/biblioteca`, **Team** tab.
2. On the person's row, click **"Suspend"**.
3. Modal with a mandatory **"Reason for suspension"** field (minimum 20 characters). This reason will be readable in the audit log by all active staff.
4. Confirm.

### Immediate effect

- The membership changes to `suspended`.
- **No access** for the person. The nominal role is retained (they remain listed as "suspended `librarian`") but they can no longer do anything.
- Email to the person concerned: urgent, with the reason, and — in the case of a compromised account — an invitation to change their password.
- Email to the entire coordination team.
- Audit log: `action='suspended'` with your `actor_user_id` and the `reason` field.

### Lifting the suspension

When the situation is resolved (account re-secured, mediation concluded, investigation complete, etc.):

1. **Team** tab → **Suspensions and notices in progress** section.
2. On the suspended row, click **"Lift suspension"**.
3. Simple modal. Reason field optional but recommended to close the episode politically.
4. Confirm.

Effect: return to `active`, emails, audit log `action='unsuspended'`.

### Important: suspension vs. withdrawal

The distinction is crucial:

| | Suspension (T6) | Withdrawal (T5) |
|---|---|---|
| Effect | Immediate | Deferred (D+7) |
| Duration | Indefinite | 7 days then `inactive` |
| Reversible by | Explicit lifting | Cancellation during the waiting period |
| Typical use | Precautionary measure | Exclusion decision |
| Underlying politics | "We give ourselves time to understand" | "We have decided this person leaves" |

The SIGB **refuses** to move a membership directly from `suspended` to `pending_removal` (the transition is not authorised by the matrix). Why: these are two politically distinct temporalities. To move from one to the other, the suspension must explicitly be **lifted** first (return to `active`), then a withdrawal requested (`pending_removal`). This two-step process is intentional: it forces the collective to explicitly acknowledge the transition.

### Technical side

RPC to suspend: `fn_team_suspend_member(p_user_id, p_library_id, p_role, p_reason)`. RPC to lift: `fn_team_unsuspend_member(p_user_id, p_library_id, p_role)`.

## 6.6. Demoting another `coordenador` (collective T3)

A somewhat particular case: what to do when the coordination wants to **demote a coordinator** who does not demote themselves spontaneously?

The governance spec treats this case as a **withdrawal request with a waiting period** targeting the `coordenador` membership. Concretely, you use the same procedure as in §6.3 ("Request withdrawal"), but by selecting the `coordenador` role. The person moves to `pending_removal` on their `coordenador` membership; at D+7, that membership changes to `inactive`. If they had a parallel `librarian` membership, that remains active (and the person "falls back" to `librarian`). Otherwise, they simply return to `reader`.

This is deliberately the same mechanism as for `librarian` members, with the same safeguards. **No other coordinator has special power** over their colleagues: the procedure goes through the waiting period and collegiality.

## 6.7. Abandoned account: automatic exit (T9)

The SIGB includes an **automatic exit** mechanism for accounts that have not logged in for a long time.

### The threshold

The SIGB looks at the `last_sign_in_at` field on the Supabase side. If a staff membership has a user whose last login was more than **9 months** ago, the account is progressively exited:

- **D-30 days** (8 months after last login): warning email to the person ("your membership will be deactivated in 30 days without a login").
- **D-7 days**: reminder email.
- **D = 9 months**: automatic change to `inactive`. Final email to the person + to the entire coordination team.

### Why this rule

It is a compromise between two requirements:

- Not leaving **ghost memberships drifting indefinitely**, artificially inflating team rosters.
- Not **brutally expelling** a person who has simply taken a break and intends to return.

A simple login is sufficient to reset the counter. No action required, just log in.

### Special case: the sole coordinator abandons

If the person automatically exited is the **sole active coordinator** of the library, the cron escalates to a network administrator **before** executing the exit. The network administrator is notified by email, can contact the coordination (if any fragment remains) or the library's `librarian` members, and coordinate the transition.

Politically, this is consistent with what happens when the sole coordinator explicitly demotes themselves (§6.2): the exit is not blocked, but the network is alerted so it can help if needed.

## 6.8. Some edge cases to know

**A person in `pending_removal` who wants to leave immediately.** They can. They simply use "I'm stepping down" (self-demotion T4) themselves. Effect: immediate change to `inactive`, short-circuiting the waiting period. Politically, this is consistent: right P3 (self-demotion) is unconditional.

**A person in `suspended` whom one wants to exclude permanently.** See §6.5 "Important: suspension vs. withdrawal". The suspension must be lifted first, then the withdrawal requested.

**Someone requests their own withdrawal via "Request withdrawal".** The SIGB refuses with an explicit message: "To leave the team, use the 'I'm stepping down' option (self-demotion)." This is intentional: conflating a personal decision with a collective decision would muddy the political semantics.

**Attempt to demote a network administrator.** Refused systematically. The network administrator role can only be modified via the specific mechanisms of the network-admin spec (cf. chapter 8). No local coordinator can remove a network administrator.

## 6.9. If the rule bothers you

**The 7-day waiting period seems too long or too short.** Raise it on `spec-gouvernance-roles.md`, §4.4 and §5.6.

**You think that suspension without a maximum duration is a door open to arbitrariness.** This is a serious political issue. One could consider adding a deadline beyond which a suspension must be converted into a withdrawal or lifted. To be discussed in network coordination, then raised on the spec.

**You think that the mandatory reason on suspensions is excessive bureaucracy.** Or conversely, you find that the 20-character minimum is too short. Raise it on the spec.

**You think that automatic exit at 9 months is too fast or too slow.** The threshold is configurable, but today it is the same for all libraries in the network. Should it be made configurable per library? To be discussed.

See chapter 4 and annex C for the amendment procedure.

\newpage

# 7. When Things Go Wrong

This chapter addresses **exceptional situations** — where ordinary governance mechanisms are insufficient, or where they work but require political discernment. It is also the chapter where we speak plainly about **libraries that have no (or no longer have) a deliberating collective life**, because silence on this subject would do more harm than frankness.

## 7.1. Library with no AGM or very few members

The case is more common than it appears. A library just starting out, with two or three people. A library whose collective has shrunk as members have left. A library whose general assembly has not met for a while, for lack of people or out of discouragement.

The SIGB does not interfere in the political life of a collective. But this guide must say plainly what changes when that collective life is weak.

### What changes in practice

**The word "co-optation" becomes ambiguous.** With two people, who co-opts whom? If the sole coordinator wants to bring Voltairine onto the team, they decide "alone" in the political sense. The SIGB will allow it (a coordinator+ can co-opt), but it is no longer the cooperation of a political collective — it is a personal decision in disguise. That is neither good nor bad; it simply needs to be acknowledged.

**Deliberations are theoretical.** A withdrawal request with 7 days' notice, in a library with 2 people, has no one else to challenge it except the person who requested it. The "collegial safeguard" becomes self-reflection.

**The risk of personalisation increases.** When a decision is no longer collective, it depends on the character, availability, and clarity of one or two people. That is not catastrophic in itself, but it is more fragile.

### Our explicit recommendations

**1. Acknowledge the situation.** Do not pretend you are a large deliberating collective if there are only two of you. Politically, it is healthier to write "decision made by me alone, to be ratified when the collective grows" in the "Reason" field of the audit log, than to write "AGM decision" for an AGM that does not exist.

**2. Seek dialogue outside.** If you are alone or a pair, and an important decision must be made (co-optation, withdrawal, suspension), make a habit of discussing it with comrades from other libraries in the network, or with a network administrator. Not to ask for their authorisation — they have no business validating the internal decisions of your library — but to get an external critical perspective. The AnarBib Matrix network is there for exactly this.

**3. Favour reversible transitions.** When your collective is small, avoid irreversible decisions where possible. A suspension is more reversible than a withdrawal. A withdrawal involves 7 days during which you can change your mind. A co-optation can be undone. Give yourself time.

**4. Document what happens.** The "Reason" field in the audit log is your best friend. The more context you put there ("co-optation of Voltairine, decided alone, to be ratified at the next session"), the more interpretable the decision will be later — by yourself as much as by a new member of the collective.

**5. If you are truly isolated, ask for help.** A one-person library is politically at risk. The SIGB detects this when the last coordinator downgrades (§6.2) or abandons (§6.7), and alerts network administrators. You can also take the initiative: send a message to the network coordination explaining the situation. Several libraries in the network have gone through fallow periods and been helped to reconstitute themselves.

### What this guide does not do

It does **not** provide a special procedure for small libraries. This is intentional. The SIGB rules apply uniformly — what changes are the political conditions under which they apply. Recognising this nuance is part of the political maturity of a coordinator.

## 7.2. Interpersonal conflict within a coordination

A conflict breaks out between two staff members. Work is no longer being done properly, the atmosphere deteriorates, readers sense the tension.

### What the SIGB can do

Not much, directly. The SIGB does not arbitrate conflicts. But it provides **usable tools**:

- **Provisional suspension (T6)** of one or both people, while the conflict is being mediated. This is what the spec explicitly cites as a legitimate use case for suspension: "conflict in the course of mediation."
- **Self-downgrade (T3/T4)** — if one of the two people chooses to step back, it is immediate.
- **Audit log readable by all staff** — allows the entire staff to see who did what, and prevents the opaque manoeuvring of a coordinator who might try to resolve the conflict by quietly pushing the other person out.

### What the collective must do

- **Mediation.** The SIGB does not mediate. A trusted third party outside the conflict is needed. Depending on the configuration: another coordinator from the library, a comrade from another library, a network administrator.
- **Collective decision.** If mediation leads to a decision (one of the two people leaves the coordination, or a revised working framework is established), the SIGB will carry out that decision via the normal RPCs.
- **Political trace.** If the decision is to withdraw someone, the "Reason" field should mention the mediation process ("withdrawal following mediation on DD/MM, collective decision") so as not to rewrite history later.

### What to avoid

- **Using a suspension as a weapon** in the conflict. Suspension is meant to pause, not to win a power struggle. If a coordinator suspends the other without a mediation process, it is visible in the audit log, and it is politically problematic.
- **Short-circuiting the deadlock** through technical manoeuvres (suspending then "accelerating" through other means). Everything is traced, and the network will notice.
- **Keeping the audit log silent.** All staff can see what is happening (P5). If you try to conceal the conflict, you betray the transparency of the collective.

## 7.3. Reported harassment

A reader reports that a staff member has engaged in abusive behaviour (sexual harassment, abuse of power, racist behaviour, etc.).

### Recommended approach

**1. Take the report seriously**, immediately, even if the person reporting is isolated and even if the person reported is "well-known and well-liked" within the coordination. The reflex of dismissing the report as "probably exaggerated" is the most common mistake.

**2. Immediate suspension (T6)** of the reported person, **as a precautionary measure**, pending investigation. The "Reason" field should say something like "Precautionary suspension following report received on DD/MM, pending collective investigation." The suspension is **not** an accusation; it is a pause.

**3. Constitute an investigation group.** Outside the software. At minimum: comrades outside the immediate power relationship, capable of hearing both sides without bias. This group may include comrades from other libraries if the library is small or if all coordinators are implicated in the matter.

**4. Communicate with the person who reported.** They need to know that the matter is being taken seriously and that steps are underway. Do not leave them in uncertainty.

**5. Reach a decision.** Depending on what the investigation reveals:
   - Lifting the suspension (T7) if the report is not confirmed.
   - Definitive withdrawal (T5 with deadlock) if the report is confirmed and the decision is to remove the person.
   - Intermediate sanction (revised working framework, training, removal from certain functions) if the situation is more nuanced.

**6. Create a political trace.** The "Reason" field in the audit log should reflect the collective decision. No details about the victim (GDPR), but a formulation that makes the decision legible.

### What must not be done

- **Requesting a withdrawal directly** without prior suspension, when the situation is urgent. For 7 days the reported person would retain their rights, which contradicts the urgency of an abuse report.
- **Suspending indefinitely without a decision** on the grounds that "we cannot decide." A suspension that lasts several months without a decision becomes a form of harm in itself (to the suspended person, who cannot defend themselves, and to the reporting person, who receives no response).
- **Resolving it internally without the network.** If you are a small library and the situation is beyond you, ask network administrators for help. You are not alone.

## 7.4. Compromised account

A staff member finds their account compromised (password leaked, suspicion of unauthorised access).

### Immediate procedure

**1. Immediate suspension (T6)** of the account, with an explicit reason: "Suspected compromise, password probably leaked, verification in progress."

**2. Communication with the person concerned.** The person automatically receives an urgent email indicating the suspension and inviting them to change their password. The coordinator who suspends should also make direct contact (phone, other secure channel) to confirm.

**3. Rapid investigation.** What happened? Has the account taken unusual actions in the audit log (odd co-optations, configuration changes, etc.)? If so, immediately inform a network administrator to help with analysis.

**4. Lifting the suspension (T7)** once:
   - The password has been changed.
   - Any damage has been assessed and repaired (cancellation of abusive actions, data restoration, etc.).
   - The person is digitally secure.

### Politically

A suspension for a compromised account **is not a reprimand**. It is mutual protection: protecting the person (by preventing them from being used by an attacker) and the library (by preventing damage from being done in their name). The email to the person should emphasise this **non-disciplinary** character.

## 7.5. Library with no active coordinators or `librarian`s

The worst-case scenario: no active staff at all. This can happen through cumulative auto-exit (all staff members abandoned their accounts simultaneously), through collective resignation (rare but possible), or through successive withdrawals.

### Consequences

- The library remains **technically active** (its visibility and catalogue remain accessible according to the usual RLS).
- But **no management action** can be taken through the normal UI: no validation of registrations, no loan management, no configuration changes.
- **Urgent email to network administrators** from the cron job that detects the situation.

### Restart procedure

Off-spec, but here is what is practised:

**1. Contact** by a network administrator with the local collective, through all available channels (the reader account(s) that remain registered, the library's external contact details if they exist, the local network of acquaintances).

**2. Political verification**: does the collective still exist? Does it want to continue existing? If there are members but they have simply let go of the technical functions, new staff can be co-opted through an off-workflow co-optation.

**3. Off-workflow co-optation** by the network administrator, via direct SQL or via the UI (a network administrator has the right to act as coordinator+ on any library, cf. chapter 2). The off-workflow co-optation must be traced in the audit log with an explicit reason: "Resumption of coordination after vacancy, following contact with the collective on DD/MM, by network administrator X." And — a key point of doctrine — **prior notification to the local coordination is mandatory**, except when the library has no living staff members at all, in which case notification goes through the remaining active `reader`s (cf. §7.6).

**4. If the collective no longer exists**: open a discussion about the **orderly closure** of the library. What data to keep, what to delete, how to communicate to readers, etc. This is a workflow to be formalised separately.

## 7.6. Intervention by a network administrator in a local library

A case already touched on in chapter 2, but which deserves practical elaboration in this chapter on exceptional situations.

### The network doctrine

> **An intervention by a network administrator in a local library must be preceded by notification to the local coordination concerned, except in a vital emergency.**

Prior notification **is not a request for authorisation**. The network administrator has the right to act (that is the meaning of the transverse right). But it is a mark of respect for local autonomy, and it preserves the possibility of another arrangement.

### What constitutes a "vital emergency"

This is intentionally restrictive. Typical cases:

- **Active compromise**: an ongoing action threatens the integrity of the library or the network (an attacking account modifying memberships in real time, etc.).
- **Ongoing harassment**: a staff member is actively abusing their functions, and the danger to readers is immediate.
- **Attack against the platform**: attempted intrusion, data exfiltration, etc.

Outside these cases, **take the time to notify**.

### How to notify

Before the intervention (or during it, if urgency subsequently justifies it retroactively):

- **Email to the local coordination** explaining what is about to be done, why, and with what traceability.
- **Entry in the `cross_library_actions_log` table** with a criticality level indicating the nature of the action. All active coordinators of the library receive a notification.
- **Openness to dialogue**: the local coordination must be able to ask questions, request clarifications, or even negotiate another arrangement ("let us try first").

### What to avoid

- **Silent intervention**: acting on the library without notifying the coordination. Even if it is technically traced, politically it is a violation of local sovereignty.
- **Using the transverse right as a surveillance power**: going to see "what is happening" in a library without an operational reason. The transverse right exists for maintenance or mediation cases, not for curiosity.
- **Imposing political decisions**: a network administrator cannot tell a library how to manage its co-optations, how to handle its internal conflicts, or what access policy to adopt. The transverse right is technical, not political.

## 7.7. If the rule troubles you

**You think the prior-notification doctrine is too loose** (a network administrator could abuse the "vital emergency"). Worth discussing: should the definition of emergency be tighter? Should a second network administrator confirm the emergency?

**You think the doctrine is too strict** (sometimes one needs to act quickly without explaining everything). Worth discussing: should several levels of intervention be distinguished, with different notification rules depending on criticality?

**You think the silence on the orderly closure of a library is problematic** (§7.5). You are right. A dedicated spec probably needs to be written. Bring it to the network.

**You think this chapter leaves too much room for improvisation** in harassment cases (§7.3). That is probably true. A dedicated spec on mediation and investigation processes could be beneficial. Bring it to the network.

See chapter 4 and annex C.

\newpage

# 8. The role of network administrator

This chapter is addressed specifically to network administrators (present or future), and to local coordinations who want to understand how the network self-organizes at a higher level. It complements and deepens chapters 2 and 7.

## 8.1. A distinct political function

First and foremost: being a **network admin** is neither a rank, nor an accolade, nor a title. It is a **transverse function** that the collective of network admins delegates to certain of its members, on the basis of unanimous agreement among the admins already in place, and which can be left at any time.

The political project of the function is to **keep inter-library coordination alive**: welcoming new libraries joining the network, facilitating discussions on technical and political developments of the SIGB, maintaining the platform technically, and stepping in when a library finds itself stuck. This is not a leadership function. It is a facilitation and service function.

### What a network admin can do (politically)

- Activate a new library that has submitted its registration request to the network.
- Facilitate inter-library discussions (the `#anarbib` Matrix channel, meetings, internal mailing lists).
- Coordinate platform developments (specs, releases, communications).
- Intervene in any library in the event of a technical blockage (transverse right).
- Mediate between two libraries in the event of a conflict (if the coordinations wish so).
- Propose or vote on the co-optation and collective removal of other network admins.

### What a network admin cannot do (politically)

- Lead a library.
- Impose a political decision on a library (admission policy, validation mode, internal co-optations, etc.).
- Remove a local coordinator against their library's wishes.
- Unilaterally modify the network's rules (this goes through a collective discussion among the admins and ideally the coordinations).

## 8.2. Co-optation by unanimity: why

A network admin is not added by a majority vote, but by the **unanimity** of the admins in place. This rule may seem surprising — why not a simple majority, a qualified majority, or a quorum?

The political reason is simple: the power of a network admin is **transverse**. They can intervene in any library. It is therefore necessary that **every currently active network admin** be willing to work with the new person. If there is even one deep disagreement, cooperation will be poisoned — it is better not to force it.

This rule has an important practical consequence: **the veto is easy**. A single `opposed` vote is enough. This is intentional. One would rather a co-optation not go through than leave an existing admin in a lasting difficult position.

## 8.3. Co-optation workflow, in detail

### Step 1 — Proposal

An active network admin, from the `/rede/administradores` interface (coming in package D), clicks **"Propose a co-optation"**.

- Enters the identity of the proposed person (searches the AnarBib user database).
- Enters a mandatory **rationale** of **at least 20 characters**. This rationale is readable by all admins, and — if successful — will be included in the notification sent to the co-opted person.
- Confirms.

The SIGB:
- Creates a row in `network_administrator_cooptation_proposals` with `status='open'`, `expires_at = now() + 30 days`.
- Automatically records the proposer's `favorable` vote.
- Sends a militant email to all other active admins inviting them to vote.

### Step 2 — Votes

Each other active admin has 30 days to vote. Three options:

- **`favorable`**: they accept the co-optation.
- **`opposed`**: they veto. **Mandatory rationale** of at least 20 characters. This rationale will be communicated to the proposed person and the proposer in the event of rejection.
- **`abstain`**: they abstain. **Abstention blocks**: the proposal only succeeds with unanimous `favorable` votes. An unlifted abstention has the same practical effect as a veto, except that it can be converted to favorable later if the person changes their mind.

### Detail v0.3 — Identity disclosure

An option **"Reveal my identity in case of rejection"** is checked by default. If you vote `opposed`, your identity will be communicated to the proposed person and the proposer, in addition to your rationale.

You can **uncheck** this option to remain anonymous. In that case, the rationale will be transmitted without your name ("an opponent raised: ...").

Politically, **transparency by default** aligns with the militant culture of owning one's positions. But anonymity remains possible for cases where opposition would expose the person opposing to a disproportionate personal cost.

### Automatic reminders

The cron sends reminders to admins who have not yet voted:
- **Day +14**: "You haven't voted yet on the co-optation of X."
- **Day +25**: "This proposal expires in 5 days, take a position."

### Step 3 — Conclusion

**If someone votes `opposed`**: the proposal immediately moves to `status='rejected'`. The proposed person and the proposer receive an email explaining the rejection, with the rationale (and the identity of the person opposing if they agreed to disclosure).

**If all active admins have voted `favorable`**: the proposal moves to `status='completed'`. A row is automatically inserted into `network_administrators` with `status='active'` and `coopted_by_unanimity_of = ARRAY[<list of voters>]`. The person receives a welcome email and a summary is sent to all admins.

**If 30 days pass without reaching consensus**: the proposal moves to `status='expired'`. No co-optation. One must either start a new proposal, or consider that the network is not ready to welcome this person at this time.

## 8.4. Collective removal by unanimity

**Collective removal** is the mirror of co-optation: to remove a network admin against their will, it requires the unanimity of the other active admins.

### Workflow

1. **Removal proposal** by an active network admin, mandatory rationale ≥ 20 characters.
2. **Votes** from other admins (favorable / opposed / abstain), with rationales if `opposed`.
3. **If unanimous `favorable`**: the targeted person's membership moves to `pending_removal`, with `pending_collective_removal_until = now() + 7 days`.
4. **During the 7-day waiting period**: the targeted person retains their operational rights, but receives a clear email about their scheduled exit. They may possibly engage in a final discussion. **They cannot unilaterally cancel the removal**: only the unanimity of the other admins can reverse the decision (by proposing a "removal cancellation", mirror workflow).
5. **At day +7**: transition to `status='removed'`, `removed_at=now()`.

### Politically

The **double lock** (unanimity + 7-day waiting period) makes the collective removal of a network admin particularly difficult. This is intentional. Given that a network admin's power is transverse, one does not revoke it lightly.

Conversely, **self-removal always remains possible and easy** (cf. §8.5). This is the political asymmetry: it is simple to leave, it is difficult to be forced out. This aligns with anarchist culture: one respects the personal decision to leave a function, one strongly frames the collective decision to remove someone from it.

## 8.5. Self-removal

A network admin can leave their functions at any time, without the agreement of others. This is a **unilateral and unconditional** act (P3 applied at the network level).

### Procedure

From `/rede/administradores`, on their own row, click **"Leave my network admin functions"**. Confirmation modal, optional reason.

### Effect

- The row moves to `status='inactive'` (or `removed` depending on context, to be clarified in package D).
- Email to all other active admins.
- Audit log `event_type='self_removal_requested'`.

### Special case: the sole active admin

If you are the only active admin and want to leave, the SIGB triggers a **special 30-day waiting period**. During this period:
- You remain an active admin with all your rights.
- An urgent email is sent to all former admins (`status='inactive'` or `removed`) informing them of the situation.
- The network has 30 days to either re-co-opt a new admin (normal co-optation workflow, with you as the sole voter), or organize a different transition.

At day +30, if nothing has been done, you effectively exit and the network finds itself **without an active admin**. The SIGB continues to function technically, but no admin action (library activation, co-optation, etc.) is possible until manual intervention.

This procedure is designed to **slow down** the dissolution of the network in the event that a last admin were to leave, without however **preventing** that departure. The freedom to leave remains intact.

## 8.6. The transverse right in daily practice

The **transverse right** is what politically distinguishes the network admin from local staff: they can act as `coord+` on any library, read its catalogue (even if visibility is `private`), modify its memberships, etc.

### When to use it

- **Activation of a new library**: normal workflow, this is the primary use case for the transverse right.
- **Maintenance**: a library has a broken configuration, a misconfigured parameter, a blocking bug. You can intervene to fix it.
- **Political blockage**: the library no longer has a coordinator (cf. §7.5), a re-co-optation is needed to restart.
- **Mediation upon request**: the local coordination explicitly asks you to help arbitrate a conflict or make a difficult decision.
- **Investigation following a network report**: a reader reports a major problem in a library, and the local coordination does not respond or is itself part of the problem.

### When not to use it

- **Out of curiosity**: do not go "see what is happening" in a library without an operational reason. That is surveillance, not administration.
- **To impose a political decision**: if you disagree with a library's policy (validation mode, rules, etc.), you can discuss it, but not impose it.
- **To short-circuit a collective debate**: if the network is discussing a development and you disagree, you cannot use your transverse right to impose your view as a fait accompli.

### Mandatory prior notification

This is network doctrine (chapter 2, §2.4; chapter 7, §7.6): **any network admin intervention on a local library must be preceded by notification to the local coordination**, except in cases of vital emergency.

Concretely:
- **Email to the local coordination** explaining what will be done and why.
- **Waiting for a response** unless urgent: 24 to 72 hours depending on the nature of the action.
- **If no response and action is non-urgent**: follow up once, and proceed by explicitly noting in the log that the local coordination was informed but did not respond.
- **If vital emergency**: act, and send the information immediately afterward explaining why the urgency justified acting without waiting.

Each action is traced in `cross_library_actions_log` with a criticality level, readable by the local coordination after the fact.

## 8.7. The case of the first admin and Xavier

The system assumes at least one active network admin for co-optation to be possible. The **first admin** cannot be co-opted (there is no one to vote), so an exception is provided.

As of 11 May 2026, **Xavier** is registered as **founding network admin** by direct INSERT into `network_administrators`, with `coopted_by_unanimity_of = ARRAY[]::uuid[]` (empty array) and `notes = 'Fondateur du réseau AnarBib, cooptation hors workflow'`. This operation is traced in the audit log with `event_type='foundational_admin_added'` and `metadata.foundational=true`.

This operation is **politically transparent**: it is documented, explained, and public. It is not a weakness of the system — it is the indispensable bootstrapping. Once this foundation is set, all subsequent co-optations go through the normal workflow of §8.3.

As new admins are co-opted over time, the initial "solitude" will fade. The network is intended to have **several active admins** (the political objective is generally a circle of 3 to 5 people, odd in number to avoid deadlocks in votes on certain related out-of-spec matters).

## 8.8. If the rule bothers you

**You find unanimity too demanding** ("we never manage to co-opt anyone, one veto blocks everything"). This is a fundamental debate about the nature of the network admins collective. Should it be relaxed toward a qualified majority? Should there be a super-vote mechanism? To be brought up in a network discussion, and possibly formalized in a spec revision.

**You find unanimity too lax** ("we should also consult local coordinations before co-opting an admin"). This is another political option: consulting local coordinations before co-opting a network admin. To be discussed. This would broaden the decision-making circle but would make the procedure more cumbersome.

**You find the 7-day waiting period for collective removal too long or too short.** To be brought to the spec.

**You find the prior notification doctrine insufficiently framed**: what exactly is a "vital emergency"? Should there be a canonical definition? To be discussed.

**You find the network admin function has too much power** (transverse right too extensive) or not enough (should be able to settle certain conflicts). This is a fundamental political question. To be discussed at the annual meeting.

See chapter 4 and annex C.

\newpage

# 9. Transparency in practice

This chapter deals with the concrete functioning of **transparency** in AnarBib: who sees what, how, and why. This is the application of principle P5 (maximum transparency) and P6 (systematic notifications).

## 9.1. The principle

> **P5 — Maximum transparency.** The audit log of role changes is readable by all active staff of the library.
> **P6 — Systematic notifications.** Any role change triggers an email to the person concerned and to the entire coordination.

The political idea: **making opaque manipulation impossible**. If everything is traced and readable, one cannot silently move a person from one status to another without it being seen by other staff members.

## 9.2. Who sees what: matrix

### At the library level

| Information | reader | librarian | coordenador | network admin |
|---|---|---|---|---|
| Team list (active roles) | partial (public names only) | complete | complete | complete |
| Statuses (`suspended`, `pending_removal`) | no | yes | yes | yes |
| Full team audit log | no | yes | yes | yes |
| Audit log: reasons for actions | no | yes | yes | yes |
| Ongoing removal request: who requested it | no | yes | yes | yes |
| Personal data of other readers | no | yes (of this library) | yes | yes |

### At the network level

| Information | reader | library staff | network admin |
|---|---|---|---|
| List of active network admins | yes (public page `/rede`) | yes | yes |
| Network counters (number of libraries, etc.) | yes | yes | yes |
| Network audit log (co-optations, admin removals) | no | no | yes |
| Ongoing co-optation proposals | no | no | yes |
| Cross-library logs (network admin actions on library X) | no | yes (of their library) | yes |

## 9.3. The team audit log in practice

This is the most important transparency tool. It is accessible from `/biblioteca` → **Team** tab → **Team history** section.

### What you see there

Each entry displays:
- Date and time.
- Action ("promoted to librarian", "self-downgraded", "removal requested", "suspended", "reinstated after suspension", "automatic transition to inactive after 9 months", etc.).
- Person concerned (target).
- Author of the action (actor) — for human actions. Empty for automatic actions (cron).
- Reason (if provided).
- Role and statuses before/after.

### What it is politically useful for

- **Collective memory**: one can reconstruct the history of the coordination, see how it was formed and how it evolved.
- **Guard against opacity**: if a coordinator took questionable actions (unusual co-optations, unjustified suspensions), these are visible to everyone.
- **Deliberation tool**: in the event of a debate ("we said we would rotate the coordinators!"), the log provides factual elements.
- **Transition tool**: when a new coordinator arrives, they can read the log to understand recent history without having to question everyone.

### What to do with it

- **Read it regularly**. Not every day, but once a month, during a coordination meeting for example.
- **Discuss what seems strange**. If an action seems incomprehensible or unjustified to you, ask its author.
- **Do not use it as a weapon**. The log is a tool for collective transparency, not an instrument of interpersonal surveillance.

## 9.4. Notification emails

Each governance action triggers **one or more** automatic emails. This is not spam: it is intentional, because no one should be affected by a role change without being informed.

### Who receives what

| Event | Person concerned | Active local coordinators | Network admins |
|---|---|---|---|
| Co-optation (T1, T2) | ✅ | ✅ | — |
| Self-downgrade (T3, T4) | ✅ confirmation | ✅ | — |
| Removal request (T5) | ✅ | ✅ | — |
| Cancellation of request (T8) | ✅ | ✅ | — |
| End of waiting period (day +7) | ✅ | ✅ | — |
| Suspension (T6) | ✅ urgent | ✅ | — |
| Suspension lifted (T7) | ✅ | ✅ | — |
| Auto-exit at 9 months (T9) | ✅ reminders + final | ✅ (final only) | — |
| Last coordinator leaves | ✅ | ✅ (the person concerned) | ✅ alert |
| Network admin co-optation (proposal) | — | — | ✅ |
| Network admin co-optation (success) | ✅ welcome | — | ✅ recap |
| Network admin co-optation (rejection) | ✅ with rationale | — | ✅ |
| Collective removal of network admin | ✅ | — | ✅ |
| Cross-library intervention | — | ✅ (coords of the library) | ✅ (the author) |

### The tone of the emails

Governance emails follow the network's militant conventions (cf. internal memory): sobriety, clarity, accessibility (common language without jargon), inclusive phrasing and desacralized writing. No official formulas, no bureaucratic signatures.

Typical example for a removal request:
> Hi Karl,
>
> The coordination of the BLMF has requested your removal from the team (role: librarian), following: "GA decision of 04/05".
>
> This notice will take effect on **12 May 2026** (in 7 days), unless cancelled by another coordinator before then.
>
> During this period, you no longer have access to librarian functions. For any discussion, address yourself to the BLMF coordination — this decision is part of the organic life of the local collective and is not managed through the SIGB.
>
> AnarBib

The tone aims to inform factually without dramatizing or minimizing.

### Email confidentiality — anti-tracking safeguard

Governance emails, like all SIGB notifications, are sent via **Resend**, the network's email delivery subcontractor (cf. records of processing activities and DPA). Two political guarantees frame this sending:

- **No tracking.** The monitoring of email opens and clicks — which would collect the recipient's IP address, location, device, and email client — is an option **disabled** on the AnarBib instance. Receiving a governance email leaves no technical trace on the network side.
- **Minimization.** Only data strictly necessary for sending passes through (email address, first name for personalization, notification content). No sensitive data is transmitted.

This safeguard is doctrinal: it extends the network's commitment to non-tracking into the email layer. It is documented in the records of processing activities (GDPR art. 30) and in the DPA; any change of email subcontractor is notified to member libraries (DPA art. 5.4).

## 9.5. The case of "cross-library" notifications

When a network admin intervenes on a library (cf. §8.6), two notifications are produced:

- **Prior notification** (manual): the admin sends an email to the local coordination before acting. Free format.
- **Automatic notification** (by the SIGB): upon execution of the action, the system writes to `cross_library_actions_log` with a criticality level, and sends an email to the active coordinators of the library concerned.

This double notification (manual + automatic) ensures that the local coordination is informed **before** politically and **after** technically. The technical trace is readable after the fact in the **Team** tab → **Network interventions** section (coming in package D).

## 9.6. Limits of transparency

AnarBib's transparency has limits, which must be made explicit:

**`reader`s do not see the team audit log.** This is intentional (P5 speaks of "active staff"). `reader`s do not see who co-opted whom, who was suspended, etc. Transparency operates **within the coordination**, not toward users.

**One library does not see another library's audit log.** Local sovereignty (P7). Role changes in library A are strictly opaque to library B, except via the human channel (discussion between coordinators of the two libraries).

**The network audit log (co-optations and admin removals) is not public.** Readable by network admins alone. A local library can see the list of current network admins (page `/rede`), but not the history of co-optations nor the rationales of opposed votes.

These limits are not hypocrisies. They correspond to a balance between **transparency** (within the deliberating staff) and **confidentiality** (with respect to users and between perimeters). If you find the balance misplaced, it is amendable (chapter 4).

## 9.7. If the rule bothers you

**You think `reader`s should see the team audit log** (radical transparency toward users). This is a defensible position, but it has consequences (internal conflicts become public, the political life of the collective is exposed). To be discussed in the network.

**You think on the contrary that the audit log is too visible** (a discreet librarian should not be able to "spy" on the coordinators' actions). This is also defensible. But it contradicts P5. To be discussed.

**You find the emails too numerous or not explicit enough.** The content is configured in `mail-strings.ts` × 10 locales. Any modification of an email is amendable like a code modification. To be raised with the developers.

**You think the network audit log should be public at least to local coordinators** (so they can see who decides what at the network level). This is an interesting option. To be discussed.

See chapter 4 and annex C.

\newpage

# 10. Annotated concrete scenarios

To close, six complete scenarios. Each illustrates a combination of mechanisms and lets you see the ILS in action. The names (Voltairine, Emma, Karl, Lucy, Errico, Friedrich) are those of historical comrades of libertarian thought; they serve here as fictional archetypes.

## 10.1. Voltairine is co-opted as librarian

> **Context.** Emma is a coordinator at BLMF. Voltairine has been coming to open hours for eight months, participates in the life of the library, and clearly has the profile to join the team. The local collective discussed it at a general assembly on 4 May and confirmed their co-optation.

**Procedure.**

1. Emma logs in on 5 May at 14:30. Goes to `/biblioteca`, tab **Team**.
2. Searches for Voltairine in the list of `reader` members of the library (they have had an AnarBib account since February).
3. Clicks **"Invite to team"** → selects **librarian**.
4. "Reason" field: "GA decision of 04/05" (doctrine 1, strict requirement).
5. Confirms.

**Immediate effect.**

- Voltairine receives an email: "Hi Voltairine, you have been appointed librarian at BLMF by Emma G. following: "GA decision of 04/05". Your new permissions are active. Welcome to the team."
- The other active coordinators at BLMF (Lucy and Piotr) receive an informational email.
- Audit log: `2026-05-05 14:30 — Emma G. promoted Voltairine d.C. to librarian (reason: GA decision of 04/05)`.

**Commentary.**

The simplest case. The ILS cleanly executes the collective's decision. Emma made no political decision — they clicked to execute what was decided outside the software.

**What the ILS did not do:** verify that the GA actually took place, that the decision was actually made, that Voltairine actually agreed. These things are **outside the software**. If Emma had lied about the GA, the ILS would have noticed nothing. The political culture of BLMF is what prevents that lie (and the log makes it traceable after the fact).

## 10.2. Lucy steps down

> **Context.** Lucy is a coordinator at BLMF, but they can no longer handle the workload this semester (they are starting a thesis). They want to "step back down to librarian" to stay on the team but lighten their responsibilities.

**Procedure.**

1. Lucy goes to `/biblioteca`, tab **Team**.
2. On their own line (status `coordenador`), clicks **"Step down"**.
3. Choice: "revert to librarian".
4. Confirmation modal reminds them that they will immediately lose coordination permissions.
5. Lucy confirms. Optional reason: "starting thesis, temporary lightening of duties".

**Immediate effect.**

- Their `coordenador` membership switches to `inactive`.
- Their `librarian` membership (which existed in parallel) remains `active`.
- Lucy receives a confirmation email: "You are now librarian at BLMF. You keep your operational permissions."
- The entire coordination team (Emma, Piotr) receives an email: "Lucy P. has stepped down, is no longer a coordinator. They remain librarian on the team."
- Audit log: `2026-05-05 18:42 — Lucy P. self-demoted coordenador → librarian (reason: starting thesis, temporary lightening of duties)`.

**Commentary.**

This is the exemplary use of right P3. Lucy did not need to ask anyone's permission. Their self-demotion is immediate. They continue to contribute to the library, but at an intensity adjusted to their current availability.

**Politically**: this is exactly the kind of rotation we aim to encourage. We do not lose Lucy; they simply take on a different role. In six months or a year, if they want to resume coordination, the collective can co-opt them again (T2). No decision is permanent.

## 10.3. Karl must go

> **Context.** Karl is a librarian at BLMF. Their behaviour toward certain readers has been problematic (paternalism, inappropriate remarks). The collective discussed it at a GA on 4 May and decided they must leave the team.

**Procedure.**

1. Piotr (coordinator) — chosen by the GA to carry out the decision — goes to `/biblioteca`, tab **Team**.
2. On Karl's line, clicks **"Request removal"**.
3. Red modal with explicit 7-day delay.
4. Mandatory reason: "Following GA of 04/05, inappropriate behaviour toward several readers reported over several months, collective decision to exclude."
5. Explicit confirmation: "I understand that this request will take effect on 12 May 2026 unless cancelled by another coordinator."

**Immediate effect.**

- Karl's membership switches to `pending_removal`, `pending_removal_until = 2026-05-12`.
- **Karl immediately loses access** to all librarian functions (the membership is frozen).
- Karl receives an email:
  > "Hi Karl, the BLMF coordination has requested your removal from the team (role: librarian), following: "Following GA of 04/05, inappropriate behaviour toward several readers reported over several months, collective decision to exclude." This notice will take effect on 12 May 2026 (in 7 days), unless cancelled by another coordinator before then. For any discussion, contact the BLMF coordination."
- Emma and Lucy (other coordinators) receive the informational email.
- Audit log: `2026-05-05 — Piotr K. requested the removal of Karl M. (role: librarian, reason: ...)`.

**Evolution.**

- 6 May at 9:00: Lucy reads the email. They agree with the decision and do not intervene.
- 7 May: Emma has an exchange with Karl (who writes to explain themselves). Emma concludes the decision stands. Does not intervene.
- 8–11 May: nothing.
- **12 May at 00:00**: the cron `cron_team_pending_removal_complete` runs. Karl switches to `inactive`.
- Final email to Karl and to the coordination.
- Audit log: `2026-05-12 — automatic switch to inactive (reason: pending_removal expired, cron) — actor: NULL`.

**Commentary.**

This is the case of collective exclusion. Three political points to note:

- **The lapse period functioned as a possible safeguard**, without being used. Lucy and Emma could have cancelled; they did not. The fact that no one cancelled is itself an **implicit deliberation**.
- **Karl remained informed** without any surprise. No silent exclusion.
- **The audit log is readable** by the entire staff and allows the decision to be revisited later if anyone wonders why Karl left.

**Politically sensitive**: the reason written in the "Reason" field is readable by all staff. It should not contain details about the victims (GDPR, dignity), but should be clear enough that the decision is politically defensible. Finding the right balance is a coordination skill.

## 10.4. Compromised account: immediate suspension

> **Context.** On 5 May at 19:30, Emma notices in the activity logs that Friedrich (librarian) has made 47 catalogue record modifications in 3 minutes, several of them aberrant (books marked as "missing" when they are on the shelf, etc.). The pattern looks like unauthorised access.

**Procedure.**

1. Emma goes to `/biblioteca`, tab **Team**.
2. On Friedrich's line, clicks **"Suspend"**.
3. Modal with **mandatory** reason (≥ 20 characters).
4. Emma types: "Suspected compromised account, abnormal activity (47 catalogue edits in 3 min), investigation in progress."
5. Confirms.

**Immediate effect (19:32).**

- Friedrich switches to `status='suspended'`.
- **No access** for Friedrich.
- Friedrich receives an urgent email: "Your AnarBib account has been suspended as a precautionary measure at BLMF. Reason: suspected account compromise. We strongly recommend you **change your password immediately**. Once your account is secured, contact the BLMF coordination to have the suspension lifted."
- The coordination team (Lucy, Piotr) receives an email.
- Audit log: `2026-05-05 19:32 — Emma G. suspended Friedrich E. (role: librarian, reason: ...)`.

**Evolution.**

- **19:35**: Emma calls Friedrich (out-of-ILS channel). Friedrich confirms they did not perform those actions. They had left their computer open in a shared space.
- **19:40**: Friedrich changes their password via the reset procedure.
- **20:00**: Emma reviews the suspicious actions in the library audit log (the catalogue audit, not the team audit). Identifies the 47 modifications. Reverts them manually or asks a network administrator for a rollback if needed.
- **20:15**: Emma returns to the Team tab and lifts Friedrich's suspension.
- Friedrich receives a confirmation email. Audit log: `2026-05-05 20:15 — Emma G. lifted the suspension of Friedrich E.`.

**Commentary.**

A typical case where suspension is used as a **precautionary measure**, not as an exclusion. Friedrich is not at fault — it is their account that was compromised. The suspension lasted 43 minutes, just long enough to secure the situation.

**Politically important**: Friedrich was not "accused". The email states this clearly ("as a precautionary measure"). Once the situation is resolved, the suspension is lifted, and the episode is recorded in the log as an incident, not a reprimand.

## 10.5. Errico is the last coordinator and wants to leave

> **Context.** BLMF now has only one active coordinator, Errico. Lucy stepped down, Emma moved away and is no longer active. Piotr self-demoted at the start of the year. Errico must leave (moving abroad, no longer has time).

**Procedure.**

1. Errico goes to `/biblioteca`, tab **Team**, clicks **"Step down"**.
2. A **special** modal opens:
   > ⚠️ **WARNING**: you are the only active coordinator at BLMF. The library will be left without coordination. AnarBib network administrators will be notified. BLMF can continue to operate (librarians remain operational) but no configuration changes will be possible until a new coordinator is co-opted. Continue?
3. Errico confirms. Reason: "Moving abroad, no longer available for coordination."

**Immediate effect.**

- Errico's `coordenador` membership switches to `inactive`.
- Email to Errico (confirmation).
- Email to all BLMF coordination members — but there are none left, so in practice the remaining active `librarian` members receive a notification.
- **Urgent email to network administrators**: "BLMF no longer has an active coordinator. The remaining active librarians are: Voltairine d.C., Friedrich E., …"
- Audit log: `2026-05-05 — Errico M. self-demoted coordenador → reader (reason: …, warning: last_coordinator_leaving)`.

**Out-of-software evolution.**

- 6 May: Xavier (network administrator) contacts Voltairine and Friedrich, the remaining active `librarian` members. They confirm that the BLMF collective still exists and that they want to continue.
- 7–15 May: internal discussion within the BLMF collective, which decides at a GA to co-opt Voltairine as coordinator.
- 16 May: Xavier (or another BLMF coordinator, of whom there are none left, so Xavier exercising their transversal right) co-opts Voltairine as coordinator. **Mandatory prior notice**: Xavier wrote to Friedrich and Voltairine 2 days earlier to announce the action. Once done, the action is recorded in `cross_library_actions_log` with a criticality level of "high" (modification of a library's coordination by a network administrator).

**Commentary.**

A politically sensitive case: the library goes through a period of fragility (between 5 and 16 May, it has no coordination). But the ILS **did not prevent** Errico from leaving — their right P3 is unconditional. The ILS simply **alerted the network** so it could offer support.

Xavier's intervention illustrates the **proper** use of the transversal right: they were solicited (implicitly, by the automatic alert), they respected the prior notice requirement, and they recorded their action. They did not impose Voltairine; it was the BLMF collective that chose them. Xavier simply **technically executed** the decision.

## 10.6. A network administrator co-optation that falls through

> **Context.** Xavier is a founding network administrator. Over time, Maria, Patricia and Diego were co-opted as network administrators as the network expanded. As of 20 May 2026, the administrator collective is: Xavier, Maria, Patricia, Diego (four active administrators).
>
> Maria proposes the co-optation of Mohammed, whom she knows from an Italian library that is joining the network.

**Procedure.**

1. Maria, from `/rede/administradores`, clicks **"Propose a co-optation"**.
2. Enters Mohammed's identity (an AnarBib account created two weeks earlier).
3. Motivation: "Mohammed coordinates BLA (Bologna), a library joining the network this month. They led BLA's political integration into AnarBib and are very involved in Italian coordination. Their co-optation as network administrator will strengthen the geographic diversity of the collective and facilitate outreach on the Italian side."
4. Confirms.

**Immediate effect.**

- Proposal created, `status='open'`, `expires_at = 19 June 2026`.
- Maria's automatic `favorable` vote is recorded.
- Emails to Xavier, Patricia, Diego with the proposal.

**Evolution.**

- 22 May: **Diego** votes `favorable`. No rationale (optional for favorable).
- 25 May: **Patricia** votes `opposed`. Rationale: "Mohammed has no seniority in the network. Their co-optation is moving faster than BLA itself, which has not yet had the opportunity to operate as an AnarBib library for long enough. I propose waiting 6 months for BLA to find its footing, then re-proposing Mohammed at that point." Patricia checks "Reveal my identity".

**Immediate effect of the opposed vote.**

- Proposal switches to `status='rejected'`.
- Email to Mohammed: "Hello Mohammed, your proposal for co-optation as a network administrator of AnarBib did not succeed. Patricia X. raised the following objection: "[full rationale]". You can discuss it with them or with Maria, who proposed you. The co-optation can be re-proposed at a later date."
- Email to Maria (proposer): summary with Patricia's rationale.
- Email to Xavier and Diego: information that the proposal is rejected, with the rationale.
- Network audit log: `2026-05-25 — co-optation rejected: Mohammed (proposed_by: Maria, opposed_by: Patricia, rationale: ...)`.

**Commentary.**

An illustrative case of unanimity **in action**. Patricia has a veto, they use it, and their rationale is explicit and constructive ("let's wait 6 months"). They chose to reveal their identity, which allows Mohammed and Maria to discuss the matter with them directly rather than speculating about an anonymous opponent.

**Politically**: co-optation by unanimity is not a guarantee of permanent blockage. Patricia is not saying "never" but "not now". If in 6 months BLA is well integrated and Patricia changes their mind, a new proposal can succeed. It is this **reversibility over time** that makes unanimity workable.

The alternative — co-opting Mohammed by majority vote against Patricia's objection — would have created an administrator circle in which Patricia felt at odds. Better to wait.

\newpage

# Annexes

\newpage

# Annex A — Glossary

**GA** — General assembly. Collective decision-making meeting of a library. The ILS does not model the GA (P8). Its modalities (quorum, frequency, mode of deliberation) are entirely decided by each library.

**Audit log** — Record of governance actions, stored in `library_membership_audit` (at library level) and `network_administrator_audit` (at network level). Readable by active staff (at library level) and by network administrators (at network level).

**Self-demotion** — Action by which a staff member demotes themselves to a lower role. Right P3, unconditional.

**`private` library** — Library whose catalogue is visible only to its registered members. Mode suited to politically exposed libraries.

**`network` library** — Library whose catalogue is visible to all validated `reader` members of the AnarBib network. Default mode for the majority of libraries.

**`public` library** — Library whose catalogue is visible to everyone, including anonymous visitors.

**Lapse period** — Delay imposed between a decision and its effect. Seven days for collective removals of local staff and network administrators. Thirty days for the self-removal of the only active network administrator.

**Co-optation** — Mechanism for joining a team (local staff) or the network administrator collective. For local staff: decision by a coordinator or above. For the network: unanimity of active administrators.

**Cross-library** — Describes an action performed by a network administrator on a library of which they are not a local staff member. Recorded in `cross_library_actions_log`.

**Cron** — Automated task executed periodically by the ILS. With no human actor. Examples: `cron_team_pending_removal_complete` (transition from `pending_removal` to `inactive` at D+7), `cron_team_inactive_cleanup` (automatic exit at 9 months).

**Delegation** — Act by which a collective temporarily entrusts a function to one of its members, retaining the ability to reclaim it. Central concept, distinguished from "hierarchy".

**Membership** — Row of the `user_library_memberships` table that expresses a person's attachment to a library in a given role. A person can have multiple memberships in a library (multi-membership).

**Multi-membership** — Ability to have multiple membership rows for the same person in the same library, with different roles.

**Network** — The collective of libraries that mutually recognise each other and share the AnarBib platform. Not a central organisation; a federation.

**RPC** — *Remote Procedure Call*. SQL function called by the user interface to execute an action. All governance actions go through RPCs named `fn_team_*` (local staff) or `fn_network_admin_*` (network).

**Local sovereignty** — Principle P7 whereby each library is sovereign over its internal delegations. Role changes within one library do not affect anything in another.

**Spec** — Specification document (`spec-*.md`) describing in detail how a feature of the ILS works. Technical and political source of truth. Versioned, dated, amendable.

**Unanimity** — Modality for co-optation and collective removal of network administrators. All votes must be `favorable`; a single `opposed` vote or an unresolved abstention blocks the process.

**Physical validation** — Procedure by which a librarian or above validates a `reader` account following an in-person meeting. Valid across the entire network (mutual recognition pact).

**Veto** — `opposed` vote during a co-optation or collective removal of a network administrator. Immediate effect: rejection of the proposal. Mandatory rationale of at least 20 characters.

\newpage

# Annex B — Index of technical functions

This annex gives, for each RPC mentioned in the guide, its political translation and the relevant transition. It serves as a quick reference.

## Local staff functions

| SQL RPC | Transition | Political translation |
|---|---|---|
| `fn_team_promote_to_librarian` | T1 | Co-optation `reader` → `librarian` |
| `fn_team_promote_to_coordenador` | T2 | Co-optation `librarian` → `coordenador` |
| `fn_team_self_demote` | T3, T4 | Self-demotion ("stepping down") |
| `fn_team_request_remove_member` | T5 | Removal request with 7-day lapse period |
| `fn_team_cancel_remove_member` | T8 | Cancellation of a removal request |
| `fn_team_suspend_member` | T6 | Immediate suspension (precautionary measure) |
| `fn_team_unsuspend_member` | T7 | Lifting of suspension |
| `fn_validate_physical_account` | — | Physical validation of a `reader` account |
| `cron_team_pending_removal_complete` | T5 (follow-up) | Cron: transition to `inactive` at D+7 |
| `cron_team_inactive_cleanup` | T9 | Cron: automatic exit at 9 months |

## Network administrator functions

| SQL RPC | Step | Political translation |
|---|---|---|
| `fn_network_admin_propose_cooptation` | Co-optation: proposal | An administrator proposes a new one |
| `fn_network_admin_vote_cooptation` | Co-optation: vote | Vote favorable / opposed / abstain |
| `fn_network_admin_self_remove` | Self-removal | Stepping down from network administrator duties |
| `fn_network_admin_request_removal` | Collective removal | Mirror workflow of co-optation |

## Authorisation helpers (used by RLS)

| SQL helper | Political meaning |
|---|---|
| `user_can_act_as_staff_on_library(library_id)` | Can this person act as staff on this library? (active local staff OR network administrator) |
| `user_can_engage_library(library_id)` | Can this person politically commit this library? (active local coordinator OR network administrator) |
| `fn_caller_is_network_admin()` | Is the caller an active network administrator? |
| `fn_library_visible_to_caller(library_id)` | Is this library's catalogue visible to the caller? |

## Main tables

| Table | Political meaning |
|---|---|
| `user_library_memberships` | Local delegations (who is staff at which library) |
| `network_administrators` | Network administrators |
| `library_membership_audit` | Local governance action log |
| `network_administrator_audit` | Network governance action log |
| `network_administrator_cooptation_proposals` | Ongoing co-optation proposals |
| `network_administrator_cooptation_votes` | Individual votes from administrators |
| `cross_library_actions_log` | Record of network administrator actions on libraries |

\newpage

# Annex C — Amendment note template

When you want to propose an amendment to an ILS rule or to this guide, here is a template note to structure your proposal. Free format; feel free to adapt it.

---

## Proposed amendment to [name of spec or guide]

**Author(s):** [your first names / pseudonyms]
**Date:** [DD/MM/YYYY]
**Scope:** [local library / network / foundations]

### 1. Rule concerned

Quote verbatim the rule or paragraph to be amended, with its reference in the source spec.

> *Example:* "`spec-gouvernance-roles.md`, §5.6, T5: The lapse period before effective exclusion is 7 days."

### 2. Problem identified

Describe in a few sentences what is problematic about the current rule. If possible, include a concrete case encountered.

> *Example:* "In practice, 7 days is too short when the library's next GA is in 15 days. A removal decision made in the heat of the moment sometimes does not have time to be discussed collectively before the automatic effect."

### 3. Proposed amendment

Describe the desired modification, ideally with wording ready to be integrated into the spec.

> *Example:* "Extend the lapse period from 7 to 14 days, OR make the period configurable per library (between 7 and 30 days), with a default value of 14 days."

### 4. Anticipated technical consequences

If you have an idea of what this implies on the code side, say so. If not, say that too ("I don't know, to be discussed with the developers").

> *Example:* "Modify the hard-coded value in the SQL code of `fn_team_request_remove_member` and `cron_team_pending_removal_complete`. If configurable per library, add a column to `libraries`."

### 5. Anticipated political consequences

Describe what changes in collective practice and any potential side effects.

> *Example:* "More time for deliberation, but also more time during which the person in `pending_removal` remains suspended (without access). May be perceived as more burdensome."

### 6. Alternatives considered

Mention the other approaches you considered and why you are setting them aside (or not).

> *Example:* "Alternative: keep the 7-day period but allow an "explicit extension" by another coordinator. More complex to implement and to understand. Preferable to change the default."

### 7. Discussion requested

Where and how do you want the proposal to be discussed?

> *Example:* "Discussion on the Matrix channel `#anarbib`, then if consensus, integration into the spec during the next governance patch."

---

Once written, circulate the note according to the scope (see chapter 4, §4.2).

\newpage

# Annex D — Source specs and references

This guide draws on the following documents, available in the project repository:

## Main specs

**`spec-gouvernance-roles.md`** — Founding spec for local staff role governance. Version 1.0 of 5 May 2026. 1231 lines. Details the 4 roles, 5 statuses, 9 transitions, audit log, notifications, UI, and 15 reference use cases.

**`spec-administrateur-reseau.md`** — Separation between local staff and network administrator. Version 0.3 of 11 May 2026. 975 lines. Details the `network_administrators` table, unanimity-based co-optation, collective removal, transversal right, and the semantics of "page = scope" counters.

**`spec-validation-physique.md`** — Modes for onboarding reader accounts (`open` vs `manual_validation`). Framed on 3 May 2026. Details account states, DB schema, and workflows.

**`spec-refactor-v3-semantique.md`** — Refactor of the reservation workflow semantics. Not central to governance but cited in passing for the overall coherence of the ILS.

## Related specs mentioned (to be written or in progress)

- `spec-migration-compte.md` — Migration of an account from one library to another. 940 lines, framed on 3 May 2026.
- `spec-invitation-equipe.md` — Email-based invitation workflow for people without an AnarBib account. To be written.
- `spec-fermeture-biblio.md` — Proper closure procedure for a library. To be written.
- `spec-mediation-conflits.md` — Formalised mediation and investigation framework following a report. To be written (suggested by this guide).

## Further reading

The specs and source code are on the project's Codeberg repository, with a GitHub mirror. Technical and political discussion takes place on the Matrix channel `#anarbib` of the network.

For any proposed amendment to this guide or to the specs, see chapter 4 and Annex C.

---

*End of guide. Version 1.0, 11 May 2026.*

*This guide is itself amendable. If you find that it says something wrong, that it missed a case, or that it takes a position that no longer reflects the network's doctrine, say so.*

