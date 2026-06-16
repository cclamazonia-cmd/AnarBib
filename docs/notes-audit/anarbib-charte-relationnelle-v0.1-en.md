# AnarBib Relational Charter — "the open hand"

**Version**: 0.1 (first draft)
**Date**: 2026-06-15
**Status**: **draft** — to be discussed, amended, and **adopted by consent**. Once
adopted, intended to become a **project reference** (on the same footing as the
inclusive language charter) and to be **translated into the ten locales**.
**Sister document**: `anarbib-charte-langage-inclusif-v2.md` — same status as a
doctrine artefact, complementary function: one governs **the words**, the other **the
gestures**.

This charter establishes the **relational ethics** of AnarBib: the way it
*behaves* towards the people who use it — when it offers, when it waits,
when it acts, when it protects. It addresses everyone who
**designs, codes, or decides** on a feature: it is the checklist against which
every screen, every notification, every automated action is measured before it ships.

> It does not invent a new ethic: it **makes conscious** a direction the project
> is already following, often without naming it. Writing it down makes it *verifiable*,
> *transmissible*, and *sustainable end-to-end* — including by comrades who
> join the project after those who started it.

---

## Table of contents

1. [Why this document](#why-this-document)
2. [The heading](#the-heading)
3. [The facets](#the-facets)
4. [The exception: care and the wall](#the-exception-that-makes-the-heading-robust-care-and-the-wall)
5. [Tensions to hold](#tensions-to-hold-not-to-dissolve)
6. [The practical checklist: "does it offer or does it grab?"](#the-practical-checklist-does-it-offer-or-does-it-grab)
7. [Case law: the heading already at work](#case-law-the-heading-already-at-work)
8. [Status, adoption, and revision](#status-adoption-and-revision)

---

## Why this document

A militant library does not merely archive documents: it weaves relationships —
between readers, between collectives, between libraries. A tool in the service of
such a library cannot be *neutral* in the way it stands before people. An interface
that monitors in order to "help", that decides "for your own good", that flags
delays and shortcomings, that demands before giving, reproduces exactly the
relationships of control, guardianship, and debt that a mutual aid movement seeks
to undo. Conversely, a tool that *offers without grabbing*, that *waits to be asked*,
that *recognises rather than grades*, signals from the very first moment which world
it belongs to.

Inclusive language says *which movement* AnarBib belongs to. The relational charter
says *how* it holds its place within it. The two are the same politics, at two levels.

Three concrete objectives:

1. **End-to-end consistency.** Maintaining an ethic case by case, inside a single
   person's head, is exhausting and fallible. A named heading makes consistency
   *tractable*: the same posture shows up everywhere, and users *feel* it even
   without naming it — that is where trust is born.
2. **Fast, shared decisions.** When faced with a new feature, a single question:
   *does it offer, or does it grab?* (see the checklist). Any comrade can decide
   without rederiving the values from scratch.
3. **Autonomy and handoff.** Code ages, people move on, resources run thin. An
   ethic *written down* is the constitutional layer that allows the network to
   **govern itself without depending on those who started it**.

---

## The heading

> **AnarBib holds out its hand; it never seizes the wrist.**

*Holding out*, is offering — visibly, calmly, patiently, leaving it to the person
to take or not. *Seizing* is constraining, capturing, or deciding on their behalf.
Everything else in this charter is simply the unfolding of that image.

---

## The facets

These are not six separate rules: they are **six faces of a single posture.**

**1. Offer, never impose.** Propose, never force. Every aid, every suggestion, every
link is *opt-in* and **reversible**. No irreversible or outgoing action (publishing,
sending, sharing, deleting) is triggered without a conscious gesture from the person.
*Automation prepares; the human decides.*

**2. The closest voice decides; the higher level fills only the silence.** (Subsidiarity.)
The voice closest to the person always prevails: their explicit choice > their library's
or circle's setting > the network default. A higher level only kicks in **to fill an
absence of response**, never to *override* a closer voice.

**3. Trigger on declared need or data — never on surveillance of the person.** Help
appears because a *field* is intrinsically difficult, because a *piece of data* signals
a hard case, or because the person *asked* for it. Never because the system *observed
them hesitating*. We do not measure work to judge the worker. *The work signals its
own difficulty; the person declares their need.*

**4. Recognise, never flag a deficit or a debt.** The framing is hospitality, not
remediation: "this field is tricky for everyone" not "you seem to be struggling"; a
partnership is "a comrade you can call on again", not a debt to repay. Warmth and
respect are two *separate* dials: one can be very present without ever being
condescending.

**5. Designed for the most vulnerable; revisable together.** Defaults are calibrated
for the most precarious person (new, poorly connected, in a risky context), not for
the comfortable median — the essentials work in plain text, offline, without AI; the
rest is an optional, disconnectable *accelerator*. And the heading itself is not set
in stone: it is **retuned by consent**.

**6. Joy offers; the hook grabs.** Pleasure, beauty, care for the moment are
welcome — they *give* a moment, without capturing anything. Gamification
(guilt-inducing streaks, scores, badges, completion bars, re-engagement notifications)
is their counterfeit: it *snares* behaviour and turns motivation into a lever the
system pulls — "grabbing" disguised as play. We cultivate one; we ban the other.

---

## The exception that makes the heading robust: care and the wall

This heading governs relationships **of care**. In the face of **harm done to
others**, it shifts to **protection**: one does not "hold out a hand" to those who
cause harm. Rate-limiting a contribution inbox, deploying a honeypot against a bot,
blocking an abusive actor, locking sensitive data against exfiltration — these are
not exceptions to the heading, they are its **other face**: *hold out a hand to
comrades, put up a wall against predation.* Naming the exception is what prevents
the charter from being naive.

**The test of the exception**: does the constraint protect a *third party* who is
vulnerable? If so, the wall is legitimate. If it merely constrains the person
*themselves* "for their own good", it is **grabbing in disguise**.

---

## Tensions to hold (not to dissolve)

A living heading *inhabits* its tensions rather than pretending to have resolved them:

- **Designing-for-the-vulnerable** brushes against paternalism → the vulnerable person
  *always* retains the override (individual override takes precedence over any default
  set "for them").
- **Living-and-revisable** brushes against exhausting instability → stable enough to
  remain a reliable reference; we do not reopen the heading for every screen.
- **Discretion** brushes against invisibility ("the shy never find it") → answered by
  **reliable placement**, not by pushing: discreet *and* discoverable.

---

## The practical checklist: "does it offer or does it grab?"

To be applied to every feature before it ships. **A single "no" = it grabs.**

- [ ] **Trigger** — does the action arise from a *declared need* or a *piece of data*,
  never from *surveillance* of behaviour?
- [ ] **Decision** — can the person (or the level closest to them) decide and
  **override**? Does the higher level fill only the silence?
- [ ] **Discoverability** — is it *findable* without being *intrusive* (calm, well
  placed, never modal or gamified)?
- [ ] **Framing** — does it speak the language of *recognition / hospitality*, never
  of *deficit / debt*?
- [ ] **Joy, not hook** — if it is playful or pleasant, is it a *gift of a moment*
  (an offer), not a *behavioural hook* (streaks, scores, badges, re-engagement)?
- [ ] **Reversibility** — can one say no, undo, leave, without hidden cost or
  consequence?
- [ ] **Vulnerability** — does the essential work for the most precarious person
  (text, offline, without AI)?
- [ ] **Exit / wall** — if it is a constraint, does it protect a *third party* who
  is vulnerable (and not "the person for their own good")?

---

## Case law: the heading already at work

To show that this is not abstract — a few existing choices that *are* already the
charter before it was written:

- **Catalogue data** locked down: private bucket for the network map, sensitive items
  (`visibility_level='network'`) not leaked to the public, RLS, minimised payloads →
  facets 1, 3, and 5.
- **Federalist circles** and their **consent / objection** flows (the reasoned
  objection that prevents blackballing) → facet 2.
- **Gazette**: no auto-publishing, draft reviewed, *manual* publication, "Broadcast"
  button *live but inert until clicked*, contributions *proposed* then curated →
  facet 1, at every screen.
- **Per-library mail kill-switch**, hardened password-recovery flow →
  facets 2 and 4, and the exception (the wall).
- **Progressive onboarding for new libraries** — refusal of the "mega-machine" that
  would overwhelm a newcomer with all its functions at once: pre-activation,
  constitution workshops, cataloguing discovery wizard, progressive unveiling of
  sections. The library that doesn't know where to start is *introduced*, never
  *crushed* → facets 1, 4, and 5.

---

## Status, adoption, and revision

This text is a **draft (v0.1)**. It is intended to be **discussed and amended** by
the network, then **adopted by consent** (following the model of the circles'
objection flows), and then **translated into the ten locales** — not as a
top-down translation, but allowing each language community to formulate the heading
in its own words. Once adopted, it **serves as reference** for every relational
decision in AnarBib, and is revised by the same consent that brought it into being.
