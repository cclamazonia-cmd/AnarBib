# RUNBOOK — Le front n'est pas publié alors que la CI est verte

**20/10/2026 (I34).** Les pas « Deploy Pages (git-pages) » de `ci.yml` sont **non bloquants**, à
dessein : un échec de Codeberg ne doit pas priver `backend` du déploiement des migrations et des
fonctions. Contrepartie, constatée le 12/10 (run 1693) : les trois pas ont échoué en deux secondes
sur un 503 de l'API de Codeberg, le run est resté vert, et le site a servi l'ancien build une
vingtaine de minutes — base et écran désaccordés sans que rien ne le dise.

## Ce que la CI fait désormais

1. **Second essai.** Un pas de publication qui échoue est rejoué une fois, après 60 s.
2. **Contrôle.** Le job `front-en-ligne` (à côté de `backend`, il ne retient aucune migration)
   compare l'empreinte du `index.html` servi par `app.anarbib.org`, `app.anarbib.is` et
   `app.anarbib.org.br` (requête sans cache) à celle du `index.html` que `app` vient de
   construire, pendant au plus six minutes.
3. **Alerte.** Si un domaine sert encore autre chose, le ticket **« [Front non publié] ci »** est
   ouvert (ou rouvert) sur Codeberg, avec les domaines en retard. Il se referme seul au premier
   run dont les trois domaines servent le build. Le job ne fait jamais rougir le run.

## La parade

Republier sans rien changer au code, par un commit vide sur `main` :

```bash
git commit --allow-empty -m "ci: republier le front"
git push origin HEAD:main
```

Le bouton « Re-run » n'est pas offert sur Codeberg pour ces runs ; le commit vide est la voie.
Il rejoue aussi `backend`, sans effet quand il n'y a rien de neuf (`db push` ne trouve aucune
migration, les fonctions ne sont redéployées que si elles ont changé depuis le marqueur).

Si la CI elle-même est en panne (runner hors ligne), le chemin de secours hors forge est
`scripts/ci/publier-front.sh` (I27, éprouvé le 22/09/2026), avec le jeton
`~/anarbib-ops/git-pages.token` ; `--site` pour un seul domaine.

## Vérifier à la main

```bash
for d in app.anarbib.org app.anarbib.is app.anarbib.org.br; do
  printf '%s ' "$d"
  curl -sS -H 'Cache-Control: no-cache' "https://$d/index.html?v=$RANDOM" | sha256sum | cut -c1-16
done
```

Les trois empreintes doivent être égales, et le nom `assets/index-….js` de la page doit être
celui du dernier build. L'en-tête `Last-Modified` de `index.html` donne l'heure de la
publication servie.
