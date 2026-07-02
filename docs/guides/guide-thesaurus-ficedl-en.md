# The FICEDL thesaurus in AnarBib — consulting a shared vocabulary

> **Who is this for?** For any comrade who catalogues and wants to link their books
> to the movement's **shared subject vocabulary** — the one maintained by the
> FICEDL. This guide explains what this thesaurus is, on what terms AnarBib
> connects to it, what it is for, and how to use it day to day.
>
> **Spirit.** AnarBib **consults** the thesaurus; it does not appropriate it. The
> vocabulary remains the FICEDL's, which is its **authoritative** source. Nothing
> here creates a competing version: our copy is only a faithful *reflection*.

---

## What is the FICEDL thesaurus?

The **FICEDL** — Fédération internationale des centres d'études et de documentation
libertaires — has, since 1979, federated CIRAs, social centres, CCLs and anarchist
libraries from around the world. It maintains a **thesaurus**: a *controlled
vocabulary* for libertarian documentation — a structured list of **subject terms**,
organised and translated, to describe what documents *are about*. It covers the
same **ten languages** as AnarBib (exactly those offered by the CIRA in Lausanne)
and brings together several hundred terms (on the order of six hundred). It can be
browsed publicly at `thesaurus.ficedl.info`.

A thesaurus is not a simple dictionary: it is a **graph of concepts**. Terms are
linked to one another (broader · narrower · related) and carry **scope notes**
that explain how to use them. AnarBib relies on **SKOS**, the free semantic-web
standard for this kind of vocabulary.

## On what terms it entered AnarBib

Adopting a shared vocabulary is, first and foremost, a **political decision** —
one made by collectives choosing to speak the same documentary language — and the
technical side follows suit. Concretely, AnarBib imported the thesaurus **from the
FICEDL's site** (`thesaurus.ficedl.info`) **around 24 June 2026**, bringing in its
**terms** and its **places** (geographic entries) — while leaving aside the
**dates** (chronological entries). This connection follows a few **clear
principles**, which are the *basis of the agreement*:

1. **A single canonical source.** The thesaurus that is *authoritative* is the
   FICEDL's. AnarBib does not hold *the* thesaurus: it holds a working copy of it.
2. **No forking.** Our copy is a **reflection** of the FICEDL version, never a
   rival version. The interoperability the FICEDL calls for is thereby guaranteed
   *by construction*.
3. **Consult, don't modify.** AnarBib **does not touch** the words chosen by the
   FICEDL. There is exactly one freedom, and only on our side: **putting a
   misfiled language label back in its place** (a translation filed under the
   wrong language code), solely so as not to *lose* a translation that already
   exists — never changing the term itself.
4. **Flag it, don't fix it.** Any other anomaly — a missing language, a typo in a
   term — is **not** corrected on our end: it is **flagged** to the FICEDL, which
   corrects *its* reference version.
5. **Re-synchronisation.** After the FICEDL makes corrections, AnarBib
   **re-synchronises** its copy. The reflection updates; it never diverges.
6. **A free, shared vocabulary.** The thesaurus is **freely shareable** (no
   proprietary right locks it down). It evolves **collectively**, precisely to
   *limit forks* and preserve interoperability between libraries.
7. **Evolution driven by the collective.** Some areas of the vocabulary need
   updating (for example, categories related to LGBTQI+ themes). These changes
   are not decreed from above: they are discussed **within the federation**.

In short: the thesaurus remains **100% the FICEDL's**; AnarBib is a faithful
mirror of it, and a **relay** that reports back what it notices.

## What it is for

- **Describing by subject.** During cataloguing, the **"Subjects" (subject
  authority)** field links a document to one or more thesaurus terms. This is
  what makes it possible to find a book by **what it is about**, not just by its
  title or author.
- **Browsing by theme.** These terms power the catalogue's **facets** and
  thematic browsing on the public catalogue.
- **Speaking ten languages at once.** The same concept carries its label in each
  of the ten languages: a Spanish-speaking reader and a Greek-speaking reader
  land on *the same subject*, each in their own language.
- **Connecting libraries.** Because everyone relies on the **same** vocabulary,
  catalogues become comparable and exchangeable — the foundation for mutualised
  work (duplicate detection, inter-library loans, the meta-catalogue).

## How to use it in practice

1. **Search for a term in "Subjects".** During cataloguing, start typing in the
   **Subjects** field: AnarBib suggests thesaurus terms, along with their
   hierarchy. Reuse what already exists rather than inventing something new.
2. **Choose the right level of granularity.** Neither too broad nor too narrow:
   the term *someone would use to search* for this book. Two to four subjects are
   usually enough.
3. **Read the scope note**, if the term has one: it explains how to use it.
4. **Missing label in your language (⚐).** If a subject does not yet have a
   label **in your language**, it is displayed as a **fallback** (often in
   another language) with a ⚐. This is not a bug: it is a **gap in the reference
   version**. We don't patch it on our end — see below.
5. **Found an error or a gap? Flag it, don't fix it.** A faulty term, a missing
   translation: **report it to the coordination team**, who will pass it on to
   the FICEDL. The correction is made on the canonical source, then comes back
   to us through re-synchronisation. *(The one exception, already mentioned: a
   language label that is simply misfiled can be put back in place on our side,
   without touching the word itself.)*
6. **Need a term that doesn't exist?** The thesaurus is not extended *locally*.
   For now, **free-text keywords** (free text specific to a record) are the
   release valve — see the guide "Indexing by subject". In the medium term, a
   proposal to add a term **goes up to the FICEDL's collective**.

## The spirit: consult, don't capture

This connection is **an outstretched hand**, not a grab: AnarBib *borrows* a
shared vocabulary without hoarding it, *reflects* it without *freezing* it, and
*gives back* to the FICEDL what it observes. The thesaurus stays alive where it
belongs — within the federation that carries it — and our catalogue benefits from
it without ever competing with it. At the level of words, this is the same ethic
found everywhere in AnarBib: **to offer and connect, never to capture**.

> See also: the guide **"Indexing by subject"** (the concrete gesture at
> cataloguing time) and the framing document **"Mutual aid in cataloguing"** (the
> shared body of knowledge this vocabulary sits at the heart of). The reference
> thesaurus can be browsed at `thesaurus.ficedl.info` — the authoritative
> canonical source.

*A document of the AnarBib commons. The thesaurus itself is the FICEDL's work;
this guide only explains its use within AnarBib.*
