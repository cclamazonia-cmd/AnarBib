# CADRAGE — Import de fonds scannés par OCR navigateur (« dépose ton tas de PDF »)

> **Date** : 2026-06-17 · **Statut** : cadrage (à valider, puis implémenter **depuis WSL**).
> **Origine** : chantier FICEDL/CCLA — le lot pilote BLMF a montré qu'un fonds « brut, sans
> métadonnée » (scans image) se catalogue très bien dès qu'on en extrait le texte. Piste B =
> rendre cette capacité **réutilisable directement dans AnarBib** pour tout collectif.

## 0. En une phrase

Un·e catalogueur·euse **dépose un tas de PDF scannés** dans AnarBib → l'app les **OCRise dans le
navigateur** (libre, local, zéro serveur, zéro LLM), **pré-remplit des brouillons** par
heuristique, et les verse au **pipeline d'import existant** pour révision humaine.

## 1. Besoin

Beaucoup de petites bibliothèques militantes ont des **fonds numérisés en PDF-image sans aucune
métadonnée** (cf. les 30 pièces du CCLA). Aujourd'hui, ces piles sont inexploitables sans un
travail manuel décourageant. Cible : le « catalogueur du dimanche », non technique.

## 2. Posture & garde-fous doctrine

- **Zéro serveur OCR, zéro coût** : pas de worker hébergé, pas de VPS (doctrine « pas de dépense
  d'infra »). L'OCR tourne **chez l'utilisateur·rice**, dans le navigateur.
- **OCR libre + local + zéro fuite** : `tesseract.js` (WASM) — aucune donnée ne quitte le
  navigateur, **aucun LLM, aucun service tiers**. C'est précisément le « modèle libre /
  auto-hébergeable » annoncé dans l'*Argumentaire IA de poche* → piste B **conforte** la position
  IA d'AnarBib au lieu de l'exposer. Le pré-remplissage des champs est **heuristique** (regex),
  pas génératif → fidèle au « zéro IA en prod ».
- **Souveraineté des assets OCR** : héberger nous-mêmes le worker/wasm + les `.traineddata`
  (bucket public `anarbib-media-public/ocr/`) plutôt que dépendre d'un CDN tiers à l'exécution.
- **Réutilise l'existant** : `book_drafts`, bucket `anarbib-pdf-public`, `book_draft_subjects`,
  le wizard d'import — **pas de réinvention**.
- **Jamais d'auto-publication** : tout finit en **brouillon** (`status='draft'`), révisé par un
  humain. L'OCR propose, l'humain dispose.

## 3. Architecture

Stack 100 % navigateur :

1. **`pdf.js`** (déjà dépendance — `pdfjs-dist`) :
   - `getTextContent()` d'abord → **détecter un PDF born-digital** (texte natif présent) :
     dans ce cas **pas d'OCR**, on prend le texte tel quel. *(Leçon du Caderno-CAB : un PDF tagué
     a déjà son texte ; l'OCRiser de force = régression ×24.)*
   - sinon, rasteriser les **pages clés** (couverture + colophon/ours, pas tout le doc par
     défaut) en canvas.
2. **`tesseract.js`** (WASM, lazy-load) : OCR du/des canvas → **texte + score de confiance**.
   Langue par défaut selon la biblio (`por` pour la BLMF) ; les **10 langues FICEDL/AnarBib**
   sont toutes des `.traineddata` tesseract.
3. **Heuristiques** (cf. §5) → champs pré-remplis (éditables).
4. **Versement** : upload du **PDF original** au bucket public + création du **brouillon** via
   le pipeline existant.

> Le PDF **cherchable (PDF/A)** n'est *pas* produit côté navigateur (trop lourd). On conserve le
> PDF original comme asset + on **stocke le texte OCR** (recherche + suggestion). La production de
> PDF/A cherchable reste la voie **power-user / offline** via `ocr-fonds.sh` (déjà livré).

## 4. Intégration au wizard d'import

Nouveau **circuit** dans le wizard (à côté de *migração de sistema* / *arquivo* / *fontes
externas*) : **« Fonds scanné (OCR navigateur) »**.

- Réutilise les champs déjà mappés de `book_drafts` (titulo, tipo_material, ano/data_edicao,
  emitter_org, paginas, idioma, subjects, provenance…).
- Asset : `digital_native_url` → bucket `anarbib-pdf-public`, chemin `books/<lib-slug>/<fonds>/`.
- Sujets : `book_draft_subjects` (vocabulaire contrôlé) + champ libre.
- Rattachement : `owner_library_id` = la biblio du catalogueur.
- **À vérifier/ajouter** : une **policy Storage** autorisant l'upload au bucket public par un
  catalogueur **authentifié** habilité (rôle catalogação), chemin contraint à sa biblio.

## 5. Heuristiques de pré-remplissage (zéro LLM)

| Champ | Heuristique |
|---|---|
| `ano` / `data_edicao` | regex années `\b(18|19|20)\d{2}\b`, mois pt, « 1º de maio », « março de 1996 » |
| `numero` / volume | « nº NN », « ano N », « edição N » |
| `issn` / `isbn` | regex ISSN/ISBN |
| `tipo_material` | mots-clés : *manifesto*→`tract` ; *convida/cartaz/palestra*→`cartaz` ; *boletim/informativo*→`periodico` ; *caderno de teses/congresso*→`tese` ; *projeto/relatório*→`relatorio` ; *zine/fanzine*→`zine` |
| `emitter_org` | dictionnaire de sigles connus (CCL, OSL, CAB, CBB, COB…), extensible |
| `titulo` | 1ʳᵉˢ lignes saillantes du texte de couverture (fallback) |
| confiance | si `caractères` faible → drapeau « à vérifier » sur le brouillon |

Tout est **pré-rempli + éditable**. Aucune valeur n'est imposée.

## 6. Limites & garde-fous

- **Born-digital** : détecté via `getTextContent()` → on évite l'OCR inutile (et le gonflement).
- **Performance** : OCR navigateur ≈ quelques s/page → UI à **progression**, traitement par lot,
  et **OCR limité aux pages clés** par défaut (couverture + ours), option « tout le document ».
- **Poids** : worker WASM + `.traineddata` (qq Mo/langue) → **lazy-load** à la 1ʳᵉ utilisation,
  servis depuis notre bucket.
- **Qualité variable** (scans dégradés) → score de confiance + **révision humaine obligatoire**.
- **Droits** : `rights_status` par pièce, défaut « à vérifier » ; rappel : ne publier que ce qui
  est diffusable (fonds propre du collectif, Copyleft, domaine public…).

## 7. Phasage (lots)

- **P1 — POC** : composant React « déposer un PDF → (born-digital ? texte natif : rasteriser
  pages clés via pdf.js → OCR tesseract.js `por`) → afficher texte + confiance ». Aucune écriture
  DB. Testable isolément (`npm run dev`).
- **P2 — Pré-remplissage** : heuristiques §5 → un formulaire brouillon pré-rempli, éditable.
- **P3 — Versement** : upload du PDF au bucket + création `book_drafts` (+ `book_draft_subjects`)
  via le pipeline existant ; multi-fichiers (file de lot, progression, reprise).
- **P4 — Options** : suggestion de **sujets** par appariement texte ↔ libellés du thésaurus
  (simple, sans LLM) ; bouton « générer un PDF/A cherchable » délégué à la voie offline.

## 8. Dépendances & impacts

- **Ajouter** `tesseract.js` ; **héberger** worker/wasm + `.traineddata` dans
  `anarbib-media-public/ocr/` (souveraineté, offline).
- **`pdf.js`** déjà présent (`pdfjs-dist`, exclu d'`optimizeDeps` dans `vite.config` — en tenir
  compte au câblage du worker pdf.js).
- **Policy Storage** d'upload catalogueur (cf. §4) — migration RLS/policy à écrire (doctrine SQL).
- **i18n** : nouvelles clés UI dans les **10 locales** (charte + parité gardée en CI).

## 9. Risques

- Compat navigateurs : `tesseract.js` (WASM) marche partout ; ne dépend **pas** de
  `BarcodeDetector` (≠ piège Brave du scanner).
- Tentation d'un LLM pour « mieux » extraire → **refusée** (doctrine). Heuristique + humain.
- Sur-OCR (born-digital, tout le doc) → garde-fous §6.

## 10. Articulation

- **Wizard d'import** (IMP-8) : ce circuit s'y ajoute.
- **`ocr-fonds.sh`** : voie **bulk / power-user / offline** (PDF/A cherchable, passage à
  l'échelle FICEDL) — complémentaire, pas concurrente.
- **Thésaurus** : la suggestion de sujets (P4) tournera d'autant mieux quand le **vrai thésaurus
  FICEDL** sera ingéré (après accord Lausanne).

## 11. Exécution

Implémentation **depuis WSL** (`cd ~/anarbib && claude`) : code frontend, `npm run dev`
(localhost:5173) pour tester, build + déploiement via le pipeline Forgejo. Ce cadrage est à
**committer dans le dépôt depuis WSL** (règle d'or).
