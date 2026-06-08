---
Genre : référence
Statut : 🟡 cadrée
Décisions : incarne ILL-1..ILL-9 (REGISTRE §22) ; cite PARTNER-D7 (coordenador), PARTNER-D9 (droit `digital_share`), PARTNER-D5 (révocation), CAT-B3 (visibility), DOC-I18N-1 (8 locales)
Supersédé par : —
---

# spec-flux-partage-numerique

| | |
|---|---|
| **Version** | v0.2 — charpente **figée côté conception** (`ILL-1..ILL-9` incarnés ; reste le remplissage : DDL, rôles, i18n) |
| **Date** | 2 juin 2026 |
| **Emplacement cible** | `docs/specs/` |
| **Statut** | Charpente **figée côté conception** (`ILL-1..ILL-9`, mandat BLMF 02/06) ; aucun arbitrage doctrinal ouvert. Reste le remplissage (§12 : rôles, DDL, i18n). |
| **Réfère à** | `#ILL-digital` (cadrage `CADRAGE_ILL-digital_2026-05-25`, 🔵 trace) ; `#PARTNERS` (table `library_partnerships`). |
| **Dépendances** | `spec-partenariat-biblios` (le partage est un **droit du partenariat**, `PARTNER-D9`) · recursos digitais / `ResourcePage` (`ProtectedMediaViewer`) · catalogação (`visibility`, `CAT-B3`) · `spec-cycle-vie-peb` (**circuit distinct** du PEB) · Supabase Storage. |

> **Convention.** **[A]** = acté (`ILL-*`, arbitrages 25/05 + 02/06). Conception figée : aucun arbitrage doctrinal ouvert ; le §12 ne liste plus que du **remplissage** (rôles, DDL, i18n).
> **Réserve liminaire.** Prudence *by-design* : ce flux réduit le risque de propriété intellectuelle par construction. Ce **n'est pas un avis juridique** ; l'exposition réelle relève d'un conseil compétent.

---

## 1. Préambule & objet
- Le partage numérique organise la **circulation de documents numérisés entre deux biblios AnarBib** — **circuit distinct du PEB physique** **[A — ILL-1, acté au cadrage §3]**.
- Il n'existe que comme **droit d'un partenariat stabilisé** **[A — ILL-8]** : pas de partenariat actif portant le droit `digital_share` → pas de partage.
- **Principe directeur (juridique) : la circulation ne blanchit jamais un document.** Un document ne gagne jamais en diffusion en changeant de main (**ILL-3**) ; seul ce qui est *libre de tous droits* entre au catalogue (**ILL-5**).

## 2. Périmètre — ce qui circule, ce qui ne circule pas (ILL-1, ILL-2)
- **Cible** : le **matériel gris non commercialisé** — affiches de campagne, tracts, brochures militantes — qui circule mal autrement (souvent d'un pays à l'autre) **[A — ILL-1]**.
- **Hors cible** : les ouvrages à **ISBN/ISSN**. Logique : s'ils sont en ligne, B les trouve aussi ; s'ils ne le sont pas, les droits sont actionnés (circulation dangereuse) ; et le papier s'échange en PEB.
- **Demi-verrou ISBN/ISSN [A — ILL-2]** : à la détection d'un ISBN/ISSN, le circuit **signale et oriente** (préférer le PEB / vérifier la disponibilité en ligne) ; **et** vérifie les **catalogues du réseau** — **si le document y figure, l'export est bloqué** et renvoyé vers l'échange inter-biblios (PEB physique si exemplaire papier). Sinon, signalement seul (responsabilité humaine).

## 3. Le plafond de diffusion (ILL-3)
- Tout document partagé porte un **plafond de diffusion** qui **voyage avec lui**.
- **À l'export** : le plafond fixé par la source **ne peut excéder le niveau qu'elle applique elle-même** au document (on n'exporte jamais plus ouvert que ce qu'on assume).
- **À la réception** : la biblio réceptrice **hérite du plafond** ; elle peut **durcir**, jamais **assouplir**.
- **Figé à la transmission** : un changement d'avis ultérieur de la source ne desserre pas le plafond déjà transmis (cohérent `PARTNER-D5`).
- Effet net : **aucun chemin ne rend un document plus public en circulant** — le réseau est protégé par construction.
- **Mécanique [A — ILL-9]** : crans **binaires** `public` / `staff_only` (aligné `CAT-B3` — un seul vocabulaire de visibilité dans AnarBib) ; **verrou en base** (une contrainte empêche `visibility = public` pour un document reçu sous plafond `staff_only` ; ce qui protège juridiquement ne dépend pas de la discipline humaine) ; **trace double horodatée** (déclaration à l'export + acceptation à la réception ; audit immuable, pour que chacun assume sa part).

## 4. Cycle du fichier — deux modes (ILL-4)
- **Ponctuel (défaut)** : **aucune copie chez le récepteur**. Le scan reste dans le **bucket privé de la source** ; B consulte via une **URL signée à TTL court** (régénérée à chaque ouverture par une RPC qui revérifie partenariat + droit + consentement + non-expiration), affichée dans le **`ProtectedMediaViewer`** (pas de téléchargement). À expiration, la RPC cesse de signer ; tout fichier de transit est purgé.
  - *Honnêteté* : anti-conservation « maximal mais imparfait » (une capture d'écran reste possible). Mais le **système** ne crée aucune copie persistante — c'est ce qui engage la responsabilité du réseau.
- **Versement durable** : copie dans un **bucket privé** (Supabase puis VPS), rattachée à la notice — **réservé aux documents libres de droits** (cf. §5).

## 5. Catalogage & libre de droits (ILL-5)
- **Cataloguer un document = affirmer irrévocablement qu'il est libre de tous droits.**
- Conséquence : un document sous **plafond restreint** n'est **jamais catalogué** (accès interne ponctuel, §4) ; seuls les **libres de droits** entrent au catalogue comme **ressource numérique sur la notice**.
- Le catalogage est donc techniquement **inatteignable** pour un document dont le plafond reçu interdit le `public` — le verrou §3 et l'interdit de catalogage se renforcent l'un l'autre.

## 6. Conservation patrimoniale de la source (ILL-6)
- La biblio qui numérise **conserve son scan** : acte de **préservation** (seule trace possible en cas d'incendie / inondation), indépendant du partage. Le circuit n'y touche pas.
- L'**audit** garde la trace de la **demande satisfaite** (qui, quoi, quand), **pas** une copie systématique du fichier.

## 7. Le flux (ILL-7)
- États : `demandé → accepté | refusé | indisponible → numérisation → transmis → clôturé`.
- **Initiation staff**, **biblio↔biblio** : un·e bibliothécaire sollicite une biblio partenaire ; côté source, acceptation / refus / indisponibilité.
- **Transmission via l'app** (Supabase Storage, puis VPS auto-hébergé).
- **Comptes-rendus** : une **section dédiée** dans les comptes-rendus hebdomadaires recense les partages **[A — ILL-7]**.

## 8. Lien avec le partenariat (ILL-8)
- Le partage numérique est le **droit `digital_share`** d'un partenariat stabilisé (`partnership_rights`, `PARTNER-D9`).
- Conditions cumulées pour un export : **partenariat actif** (`PARTNER-D7`) **∧** droit `digital_share` activé **∧** plafond compatible (§3).
- Réservé aux **biblios fédérées** ; l'envoi vers un **collectif** (`catalog_partners`) sort du circuit AnarBib (`PARTNER-D6`).

## 9. Implications techniques
- **Storage** : bucket **privé** côté source ; option bucket de **transit** purgé par EF planifiée.
- **Accès** : RPC régénérant une `createSignedUrl` à TTL court ; aucune URL durable côté client.
- **Viewer** : `ProtectedMediaViewer` réutilisé de recursos digitais (pas de download, clic droit / impression bloqués).
- **Modèle** : objet de partage `(source_lib, target_lib, partnership_id, document_ref, mode {ponctuel|durable}, plafond, statut, timestamps)` ; droit `digital_share` dans `partnership_rights`.
- **Verrou catalogage** : contrainte empêchant `visibility = public` pour un document reçu sous plafond restreint (§3, §5).
- **Audit** : journal des demandes satisfaites (immuable).

## 10. Articulation avec le corpus
- `spec-partenariat-biblios` (droit `digital_share`, `PARTNER-D9` ; cycle `PARTNER-D7`) · recursos digitais / `ResourcePage` (`ProtectedMediaViewer`) · catalogação (`visibility`, `CAT-B3` ; verrou libre-de-droits) · `spec-cycle-vie-peb` (**circuit distinct** ; renvoi ISBN/ISSN vers le PEB) · `#PARTNERS` (`library_partnerships`) · comptes-rendus hebdo.

## 11. Réserve juridique
- Le dispositif (périmètre gris, plafond non-élargissable, ponctuel sans copie, catalogage = libre de droits) est une **prudence *by-design***. Il **n'établit pas** la licéité d'un partage donné. La responsabilité réelle (CCLA / BLMF) relève d'un **conseil compétent**.

## 12. Points à trancher au remplissage
*(Plafond résolu : crans / verrou / trace → `ILL-9`, intégrés au §3.)*
1. **Rôles** (§7) : qui initie / accepte un partage une fois le partenariat actif — reco : **tout staff actif** (`librarian` ou `coordenador`), le cadre politique étant déjà posé par les coordinations (`PARTNER-D7`) ; à confirmer (lien `spec-gouvernance-roles`). Relances et gestion de l'« indisponible ».
2. **Modèle de données** (§9) : DDL `partnership_rights` (`digital_share`), objet de partage, emplacement du `document_ref`, mécanique de purge (pg_cron + EF).
3. **i18n** : nouvelles clés en 8 locales (`DOC-I18N-1`).

---

*Fin de la charpente — v0.2 **figée** (conception). Le remplissage suit en session dédiée (CHARTE_corpus : en-tête, foyer unique, citer plutôt que recopier). Décisions au registre `ILL-1..ILL-9`.*
