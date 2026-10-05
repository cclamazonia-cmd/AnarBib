# AnarBib

[Français](README.md) · **English** · [Português](README.pt-BR.md)

AnarBib is free software for running anarchist and libertarian libraries: cataloguing a collection, lending books, opening documents for reading, and linking libraries together into a federated network with no centre and no owner.

- **The application**: [app.anarbib.org](https://app.anarbib.org)
- **The project website**: [anarbib.org](https://anarbib.org)
- **The code**: [codeberg.org/anarbib/anarbib](https://codeberg.org/anarbib/anarbib)
- **Write to us**: anarbib@proton.me

---

## Why one more tool

Free library software already exists — PMB, Koha. AnarBib only makes sense if it does something else: a tool built from the practices of the libertarian movement, where **political choices come before technical ones**, and where a technique that contradicts those principles has to give way. Without purism, though: between two principles that contradict each other in practice, the project chooses what can actually be done rather than doing nothing.

In practice, this means:

- **Each library decides for itself.** How it catalogues, lends, opens up to the network and governs itself: these are settings it chooses, not rules imposed from above.
- **Shared decisions are made together.** Co-opting someone into network administration, entrusting the coordination of a library: the tool makes these collective acts, not one person's decisions.
- **A network with no centre.** Catalogues are shared through an open protocol (OAI-PMH); a library stays in control of what it publishes.
- **No tracking.** No trackers, advertising or statistical; the anti-bot check and the map tiles are served by the project's own infrastructure, with no call to an outside service.
- **A shared vocabulary, not a captured one.** Subject indexing relies on the [shared thesaurus of the FICEDL](https://thesaurus.ficedl.info), whose labels AnarBib takes up without ever rewriting them.
- **Ten languages, inclusive writing.** The interface exists in Brazilian Portuguese, French, Spanish, English, Italian, German, Catalan, Esperanto, Dutch and Greek, following an [inclusive language charter](docs/notes-audit/anarbib-charte-langage-inclusif-v2.md) specific to each language.

## Who uses it

As of 5 October 2026, three libraries have their catalogue open to the public in AnarBib:

- the **Biblioteca Terra Livre**;
- the **Biblioteca Libertária Maxwell Ferreira**, run by the Centro de Cultura Libertária da Amazônia (CCLA), in Belém do Pará, Brazil;
- the **Maloca Libertária / Biblioteca Emma Goldman**.

Two more are preparing to join: the **Bibliothèque Solidaires** (Paris) and **Anarchief.Org**.

## What the application does

- **A public catalogue** you can browse by work, author, subject or library, with a map of the network.
- **Cataloguing**: records, authority records, subjects, copies; catalogue import and export (including PMB files) so that no library is held captive by the tool.
- **Circulation**: loans, reservations, on-site consultations, interlibrary loans.
- **Digital documents**: online reading, open to the public or reserved to members depending on the rights of each work.
- **Network tools**: commons, mutual aid, a directory of collectives, assemblies, and a monthly gazette.

## Join, help

- **A library wants to join the network?** The request is made from the application ([app.anarbib.org/solicitar-biblioteca](https://app.anarbib.org/solicitar-biblioteca)), or by writing to anarbib@proton.me. No technical requirement: we talk first.
- **Help without writing code** — proofread a language, index by subject, take on a role in the network, test the installation: [`AIDER.md`](AIDER.md) says what is most useful today.
- **Support the running costs** (hosting, email, domain name): the accounts are public on [anarbib.org](https://anarbib.org).
- **Contribute to the code**: [`CONTRIBUTING.md`](CONTRIBUTING.md), then [`docs/CHANTIERS_OUVERTS.md`](docs/CHANTIERS_OUVERTS.md).

## A fragile project, and one that says so

AnarBib currently rests on very few hands: one person maintaining the code, one administering the network, and a single continuous-integration server, on a workstation. We would rather write it down than keep quiet: any help that reduces one of these dependencies matters more than one more feature.

**On the use of AI** *(as of 5 October 2026)*. AnarBib is developed with the assistance of a language model, and we say so rather than leave it to be guessed. That assistance is what allowed the tool to exist, carried by someone with no training in software development; in return it creates a dependency the project intends to reduce: by documenting how things work rather than the code, by keeping the technology as simple as possible, and by opening development to other hands. Decisions remain human and collective; they are written down in the [decision register](docs/specs/REGISTRE_decisions.md). In the application, three functions call a language model: preparing and translating the network gazette, and pre-translating the titles of works — always flagged "to be reviewed", and never overwriting a title entered by hand. Neither circulation nor readers' data depends on it.

## For developers

AnarBib is a web application (React and Vite) backed by Supabase (PostgreSQL and Deno functions).

**Install a complete copy on your own machine**, in one command (Docker required):

```bash
./install.sh
```

The installer speaks the project's ten languages; the details are in [`deploy/README.md`](deploy/README.md).

**Run the tests**:

```bash
npm test
```

**Where to find what**:

- [`CONTRIBUTING.md`](CONTRIBUTING.md) — getting started, the working rhythm, what to read before touching the code.
- [`docs/INDEX.md`](docs/INDEX.md) — the map of the documentation (specifications, guides, manuals in ten languages).
- [`docs/specs/REGISTRE_decisions.md`](docs/specs/REGISTRE_decisions.md) — the decision register, which is authoritative.
- [`docs/backlogs/`](docs/backlogs/INDEX.md) — what is in progress, what remains to be done, and the project's figures, dated.

The reference repository is on Codeberg; every push to the `main` branch triggers continuous integration there (tests, then deployment). The GitHub mirror is no longer synchronised. Most of the project documentation is written in French.

## Licences

- **The code** is under the [GNU AGPL v3](LICENSE): anyone who puts a modified version online must publish their changes under the same licence.
- **The documentation** is under [Creative Commons BY-SA 4.0](LICENSE-docs).

Libraries are encouraged to take up, adapt, translate and republish both, provided they share their adaptations under the same licences.

---

*This README deliberately carries no figures that age quickly: they live, dated, in the [backlog](docs/backlogs/INDEX.md). The former, more technical version is archived in [`docs/archive/README-2026-08-30.md`](docs/archive/README-2026-08-30.md).*
