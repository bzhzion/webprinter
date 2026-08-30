# Changelog

Toutes les évolutions notables de WebPrinter sont documentées ici.

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), versionnage
[SemVer](https://semver.org/lang/fr/). La section `[Unreleased]` accumule au fil de l'eau et
est renommée en numéro de version au moment de poser le tag.

## [Unreleased]

## [0.1.0] - 2026-08-30

### Ajouté

- `health.php` expose la version déployée sur présentation de l'en-tête `X-Health-Token`
  correspondant à `HEALTH_TOKEN` (comparaison en temps constant via `hash_equals`). Sans jeton,
  la réponse reste `{"status": "ok"}` pour la supervision. Un mauvais jeton rend exactement la
  même réponse qu'aucun jeton.
- `APP_VERSION` injectée au build par la CI depuis le tag git.
- Cache-busting du CSS, inexistant jusqu'ici : `style.css` pouvait rester en cache après un
  déploiement. Réécrit au build (site PHP servi par Apache), avec une empreinte opaque de la
  version plutôt que le numéro en clair, qui serait lisible par n'importe quel visiteur.
- Première version numérotée du projet.

### Modifié

- Le build ne part plus à chaque push sur `main` : uniquement sur tag `vX.Y.Z` ou déclenchement
  manuel.
