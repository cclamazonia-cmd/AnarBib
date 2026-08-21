# CADRAGE — Ne pas redéployer 47 fonctions Edge quand aucune n'a changé

> **Date** : 2026-08-21
> **Auteur** : Claude (assistant·e), sur demande de Xavier
> **Session** : Dédoublonnage & arbitrage — constat annexe
> **Statut** : proposition. **`.forgejo/workflows/ci.yml` n'a pas été modifié.**
> Le bloc ci-dessous est à appliquer — ou à refuser — par la session qui tient
> ce fichier.
> **Préséance** : ce document **propose** un changement de CI. Rien ici n'est
> doctrine ; si ça le devenait, ça s'inscrirait au
> [`REGISTRE_decisions.md`](../../specs/REGISTRE_decisions.md).

---

## 1. Le constat, mesuré

Run `backend` du 21/08 (task `8829551`), déclenché par un push contenant **trois
migrations SQL, deux suites de tests et de la documentation — aucune fonction
Edge** :

| | |
|---|---|
| Fonctions redéployées | **47**, une par une |
| Durée de la seule boucle de déploiement | ~5 min |
| Dont utile pour ce push | **0** |

Le même run portait aussi une coupure réseau côté poste — 2 min 34 de blocage
sur `audio_fingerprint_lookup`, puis deux échecs DNS
(`lookup api.supabase.com on 127.0.0.11:53: no such host`, où `127.0.0.11` est
le résolveur interne de Docker), rattrapés à la troisième tentative. **Ce n'est
pas le sujet** : la boucle `retry 8s` a fait exactement son travail. Le sujet,
ce sont les cinq minutes payées à *chaque* push, quoi qu'il contienne.

Ce coût n'est pas seulement du temps de runner. Le runner traite **un job à la
fois** : ces cinq minutes sont autant de file d'attente pour les autres
sessions, et autant de fenêtre pendant laquelle un `git push` doit patienter
pour respecter la règle de sérialisation.

## 2. Le changement proposé

Sauter **toute** l'étape quand aucun fichier sous `supabase/functions/` n'a
changé dans le push. À insérer avant la boucle `for fn_dir in
supabase/functions/*/`, dans la même étape :

```bash
# ── Le push touche-t-il seulement une fonction ? ────────────────────────────
# 47 fonctions redeployees une par une = ~5 min, payees meme quand le push ne
# contient que des migrations ou de la doc (run 8829551 du 21/08).
#
# `fetch-depth: 1` ne donne pas le parent : on va chercher explicitement le SHA
# d'avant. S'il est introuvable (branche neuve, force-push, historique
# tronque), on NE saute PAS — mieux vaut cinq minutes perdues qu'une fonction
# non deployee.
AVANT="${{ github.event.before }}"
DEPLOYER_TOUT=1
if [ -n "$AVANT" ] && [ "$AVANT" != "0000000000000000000000000000000000000000" ]; then
  git fetch --no-tags --depth=50 origin "$AVANT" >/dev/null 2>&1 || true
  if git rev-parse --verify -q "${AVANT}^{commit}" >/dev/null; then
    if [ -z "$(git diff --name-only "$AVANT" "$GITHUB_SHA" -- supabase/functions/)" ]; then
      DEPLOYER_TOUT=0
    fi
  fi
fi
if [ "$DEPLOYER_TOUT" = "0" ]; then
  echo "→ aucune fonction Edge modifiee dans ce push — etape sautee"
  echo "✓ Edge Functions inchangees"
else
  # ... la boucle `for fn_dir in ...` existante, telle quelle ...
fi
```

## 3. Pourquoi PAS « ne déployer que les fonctions modifiées »

C'est le raffinement évident, et c'est un piège. `_shared/` est importé par
presque toutes les fonctions : un changement dans
`_shared/core/env.ts` ou `_shared/i18n/mail-strings.ts` doit en redéployer un
grand nombre. Un calcul approximatif de l'ensemble affecté déploierait une
fonction avec un module partagé périmé — et ce bug-là ne se voit pas au
déploiement, il se voit des semaines plus tard, sur un envoi de courriel qui
part avec de vieilles chaînes.

Le cas « **zéro** fichier modifié sous `supabase/functions/` » ne demande aucune
finesse et couvre la majorité des push. On s'arrête là.

## 4. Ce que ça ne change pas

- **Aucun comportement en cas de doute.** Trois situations font retomber sur le
  déploiement complet : `github.event.before` absent ou nul, SHA introuvable
  après le `fetch`, `git diff` en échec. Le défaut est le comportement actuel.
- **`workflow_dispatch`** n'a pas d'`event.before` → déploie tout, ce qui est
  probablement ce qu'on attend d'un lancement manuel.
- Le retry par fonction, le `timeout 180` et les exclusions `_shared` / `main`
  restent intacts.

## 5. Ce qui n'a pas été vérifié

Que **Forgejo** Actions renseigne bien `github.event.before` sur un push. C'est
le cas sur GitHub Actions ; le repli couvre l'inverse ; seule la première
exécution le dira. Le bloc est écrit pour que se tromper coûte cinq minutes,
jamais un déploiement manquant.

## 6. Point ouvert

Le `WARNING: Docker is not running`, répété à chaque fonction, est du bruit
inoffensif — la CLI l'utiliserait pour empaqueter en local, elle téléverse à la
place. Le faire taire rendrait les logs beaucoup plus lisibles, mais c'est une
autre question que celle traitée ici.
