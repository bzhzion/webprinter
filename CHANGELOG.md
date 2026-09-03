# Changelog

Toutes les évolutions notables de WebPrinter sont documentées ici.

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), versionnage
[SemVer](https://semver.org/lang/fr/). La section `[Unreleased]` accumule au fil de l'eau et
est renommée en numéro de version au moment de poser le tag.

## [Unreleased]

### Ajouté

- **Contrôle de syntaxe PHP à chaque push** (`.github/workflows/php-lint.yml`). Une erreur de
  syntaxe dans un fichier PHP de WordPress ne dégrade pas une page, elle met **tout le site en
  erreur fatale** : le coût d'une faute de frappe est le site entier. `php -l` parse sans
  exécuter, c'est le contrôle le moins cher qui existe pour ce risque, et ce dépôt n'en avait
  aucun.
- Vérification pure, donc **sur push de branche** conformément à la convention de parc : seuls les
  workflows qui déploient sont limités aux tags.
- `runs-on: ubuntu-latest` parce que ce dépôt est **public**, les minutes y étant gratuites et
  l'image Ubuntu embarquant déjà PHP (8.3.6). Sur un dépôt privé il faut un runner self-hosted.
- `vendor/` est exclu : ce sont des dépendances tierces, et une bibliothèque livrée pour une autre
  version de PHP ferait échouer le lint sans rien dire de ce dépôt.

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
