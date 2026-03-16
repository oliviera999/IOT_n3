# Structure type d'une page de données

Document de référence pour les évolutions des pages affichant des données capteurs (aquaponie, météo, serre, tide-stats, dashboard). À utiliser comme canevas pour de nouvelles pages ou pour garder la cohérence entre les templates existants.

---

## 1. Ordre des blocs (recommandé)

```text
1. Hero (optionnel)
   → partial partials/_hero_data.twig (titre, sous-titre, synthèse, lien « En savoir plus »)

2. Contenu principal (dans un seul <article class="post featured">)
   - Sections « Données / Synthèses » : pour chaque thème (ex. Niveaux d'eau, Paramètres physiques)
     - Titre de section : <div class="section-header"> ou section-header alt-section-title-full
     - Contenu : soit stats-grid (cartes), soit alt-data-chart-row (stats à gauche + graphique à droite)
   - Graphiques (si séparés des blocs stats) : titres + conteneurs (chart-stock-wrapper, chart-container)
   - Sections annexes (optionnel) : ex. Chimie, Mesures manuelles (iframe Google, etc.)
   - Bloc Filtrage + État du système
     - Soit filter-system-row (aquaponie) : filter-section + system-health-panel + live-controls-integrated
     - Soit filter-health-row (MSP1, N3PP) : filter-section + embed partials/_system_health_panel.twig
     - Soit filter-section seule (tide_stats) : quick-filters + formulaire période

3. Footer (override du block footer)
   → context-badges (environnement, table, version, firmware) + copyright
```

---

## 2. Patterns HTML à réutiliser

- **Titre de section** : `<div class="section-header" data-aos="fade-up">` avec `<i class="fas fa-...">` + `<h3>Titre</h3>`.
- **Grille de cartes** : `<div class="stats-grid">` contenant des `<div class="stat-card [variante]">` (ex. `.aquarium`, `.reserve`, `.temp`, `.humidity`). Sous la valeur : `stat-card-details` (aquaponie, dashboard) ou `stat-card-secondary` (MSP1, N3PP).
- **Bloc filtrage** : `<div class="filter-header">` avec icône + `<h3>Filtrage des données</h3>` ; formulaire avec `id` unique si appelé par JS (ex. setPeriod) ; champs `start_datetime` / `end_datetime` avec labels `for`/`id`.
- **Quick-filters** : `<button type="button" class="quick-filter-btn" onclick="setPeriod(...)">` (éviter `<span>` pour l’accessibilité).
- **Révélation de contenu** : wrapper avec `balance-reveal-wrapper` ; bouton avec `aria-expanded`, `aria-controls` ; contenu avec `role="region"` et classe `.is-visible` gérée par JS.

---

## 3. CSS

- **Commun** : `common-data.css` (section-header, stats-grid, stat-card, filter-section, filter-health-row, period-info, quick-filters, etc.).
- **Spécifique page** : aquaponie.css (aquaponie, aquaponie_alt), msp1-sheet-styles.css (msp1_data). Éviter les liens vers des fichiers CSS absents.

---

## 4. Scripts

- **setPeriod** : si la page a des quick-filters qui changent la période, définir une fonction `setPeriod(value, unit)` qui remplit les champs datetime du formulaire et soumet ce formulaire (ou envoie une requête). Prévoir un `id` sur le formulaire et des ids uniques sur les champs si plusieurs formulaires sur la même page (ex. tide_stats).

---

## 5. Fichiers concernés

| Élément | Fichier(s) |
|--------|------------|
| Hero partagé | templates/partials/_hero_data.twig |
| Panneau état (MSP/N3PP) | templates/partials/_system_health_panel.twig |
| Styles communs | public/assets/css/common-data.css |
| Styles aquaponie | public/assets/css/aquaponie.css |
| Révélation bilan hydrique | public/assets/js/balance-reveal.js |

Ce document peut être mis à jour lorsque de nouveaux patterns ou pages sont ajoutés.
