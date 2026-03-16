# Rapport d'audit — Pages de données (MSP1, N3PP, tide-stats, dashboard, aquaponie) au regard d'aquaponie

**Date :** 2026-03  
**Référence :** Plan d'audit « Audit des pages de données (n3pp, msp, tide-stats, dashboard) au regard d'aquaponie ».

---

## 1. Résumé

L'audit compare les pages de données (msp1_data, n3pp_data, tide_stats, dashboard, aquaponie_alt) à la page **aquaponie** (référence) pour la structure HTML, l'agencement des blocs, les patterns communs, le CSS et l'accessibilité. Les corrections suivantes ont été appliquées.

### 1.1 Corrections appliquées

| Page | Correction |
|------|------------|
| **msp1_data.twig** | Commentaire d’ordre des sections ; wrapper `filter-header` (aligné aquaponie) ; `<span>` remplacés par `<button type="button">` pour les quick-filters ; ajout de la fonction `setPeriod()` (manquante) ; formulaire avec `id="msp1FilterForm"`. |
| **n3pp_data.twig** | Commentaire d’ordre des sections ; wrapper `filter-header` ; `<span>` → `<button type="button">` pour les quick-filters ; ajout de `setPeriod()` ; formulaire avec `id="n3ppFilterForm"`. |
| **tide_stats.twig** | Commentaire d’ordre des sections ; formulaire avec `id="tideStatsFilterForm"` ; champs avec ids uniques `tide_stats_start_datetime` / `tide_stats_end_datetime` (éviter doublons) ; ajout de la fonction `setPeriod()` (unités `hours` / `days`). |
| **dashboard.twig** | Commentaire d’ordre des sections. |
| **aquaponie_alt.twig** | Commentaire d’ordre des sections. |
| **CSS** | Création de `serveur/public/assets/css/msp1-sheet-styles.css` (fichier référencé par msp1_data mais absent). |

---

## 2. Conformité par page

### 2.1 msp1_data.twig (Météo — /meteo)

| Critère | Conformité | Note |
|---------|------------|------|
| Structure HTML / nesting | Conforme | Un seul `<article>`. `filter-health-row` contient `filter-section` + embed `_system_health_panel` ; une seule fermeture `</div>` pour la row. Section « Mesures manuelles » en fratrie de la row. |
| Ordre des blocs | Conforme | Hero → 4 sections (Luminosité, Paramètres du sol, Paramètres physiques, Système) → filter-health-row → Mesures manuelles. |
| Hero | Conforme | Partial `_hero_data.twig` avec variables. |
| Section titre | Conforme | `section-header alt-section-title-full`. |
| Grilles / stat-card | Conforme | `stats-grid` + `stat-card` ; couleurs en inline (conservées). |
| Détails sous valeur | Conforme | `stat-card-secondary` (équivalent sémantique de `stat-card-details`). |
| Bloc filtrage | Conforme après correction | `filter-health-row` ; formulaire compact ; `filter-header` ajouté ; quick-filters en `<button>`. |
| Footer | Conforme | Override avec `context-badges`. |
| CSS | Conforme après correction | common-data.css + msp1-sheet-styles.css (créé). |
| Accessibilité | Conforme après correction | Quick-filters en `<button type="button">`. Labels for/id sur le formulaire. |

**Erreurs de structure HTML repérées :** Aucune.

---

### 2.2 n3pp_data.twig (Serre — /serre)

| Critère | Conformité | Note |
|---------|------------|------|
| Structure HTML / nesting | Conforme | Un seul `<article>`. `filter-health-row` → `filter-section` + embed ; une `</div>` pour la row. |
| Ordre des blocs | Conforme | Hero → 3 sections (Humidité du sol, Paramètres physiques, Système) → filter-health-row. |
| Hero | Conforme | Partial `_hero_data.twig`. |
| Section titre | Conforme | `section-header alt-section-title-full`. |
| Grilles / stat-card | Conforme | `stats-grid` + `stat-card` ; `.pump` en classe + inline pour cohérence. |
| Détails sous valeur | Conforme | `stat-card-secondary`. |
| Bloc filtrage | Conforme après correction | Idem MSP1 (filter-header, buttons, setPeriod). |
| Footer | Conforme | Override avec `context-badges`. |
| CSS | Conforme | common-data.css + bloc inline `.stat-card.pump`. |
| Accessibilité | Conforme après correction | Quick-filters en `<button type="button">`. |

**Erreurs de structure HTML repérées :** Aucune.

---

### 2.3 tide_stats.twig (Statistiques marées — /tide-stats)

| Critère | Conformité | Note |
|---------|------------|------|
| Structure HTML / nesting | Conforme | Un seul `<article>`. Pas de hero ; `header.major`, `info-banner`, sections avec `section-header` + `stats-grid` ou `chart-container`, puis `filter-section`. Toutes les div sont correctement fermées. |
| Ordre des blocs | Conforme | Header → Bannière période → Résultats principaux → Variations réserve → DiffMaree → Évolution (graphiques) → Filtrage. |
| Hero | N/A | Page sans hero ; en-tête dédié. |
| Section titre | Conforme | `section-header`. |
| Grilles / stat-card | Conforme | `stats-grid` + `stat-card` (variantes .positive, .negative, .neutral). |
| Bloc filtrage | Conforme après correction | `filter-section` seule (pas de filter-health-row) ; formulaire avec id ; `setPeriod()` ajoutée ; ids uniques pour les champs pour éviter conflits. |
| Footer | Conforme | Override `footer_content` (version + copyright). Pas de context-badges (choix de page dédiée FFP3). |
| CSS | Conforme | common-data.css uniquement. |
| Accessibilité | Conforme | Quick-filters déjà en `<button type="button">`. Labels for/id. |

**Erreurs de structure HTML repérées :** Aucune.

---

### 2.4 dashboard.twig (Dashboard capteurs)

| Critère | Conformité | Note |
|---------|------------|------|
| Structure HTML / nesting | Conforme | Un seul `<article>`. Header, info-banner, context-badges, quick-links-grid, system-health-panel, section-header + contenu, stats-grid (boucle), section-header + tableau. |
| Ordre des blocs | Conforme | Cohérent avec la nature de la page (vue agrégée, pas de courbes temporelles). |
| Hero | N/A | Header dédié. |
| Section titre | Conforme | `section-header`. |
| Grilles / stat-card | Conforme | `stats-grid` + `stat-card` avec classes sémantiques (temp, humidity, light, water) ; `stat-card-details` utilisé. |
| Footer | Conforme | Override `footer_content` via layout. |
| CSS | Conforme | common-data.css. |
| Accessibilité | Conforme | Liens et panneau état du système structurés. |

**Erreurs de structure HTML repérées :** Aucune.

---

### 2.5 aquaponie_alt.twig (Vue classique aquaponie)

| Critère | Conformité | Note |
|---------|------------|------|
| Structure HTML / nesting | Conforme | Même logique qu’aquaponie (déjà audité) ; layout « données à gauche / graphique à droite » par bloc (`alt-data-chart-row`). |
| Ordre des blocs | Conforme | Hero → Niveaux d’eau → Bilan hydrique (révélable) → Paramètres physiques → Chimie → filter-system-row. |
| Hero | Conforme | Partial `_hero_data.twig`. |
| Section titre | Conforme | `section-header alt-section-title-full`. |
| Détails sous valeur | Conforme | `stat-card-secondary` (aligné MSP/N3PP). |
| Bloc filtrage | Conforme | `filter-system-row` avec filter-section, system-health-panel, live-controls ; quick-filters en `<button>`. |
| CSS | Conforme | common-data.css + aquaponie.css. |
| Accessibilité | Conforme | Bilan hydrique avec `aria-expanded` / `aria-controls` ; boutons pour filtres. |

**Erreurs de structure HTML repérées :** Aucune.

---

## 3. Recommandations (optionnel / suite)

- **Couleurs inline (MSP1, N3PP)** : à terme, remplacer les `style="border-left-color:...; color:..."` par des classes sémantiques (ex. `.stat-card.luminosity-moy`, `.stat-card.temp-int`) et centraliser les couleurs dans common-data.css ou feuilles dédiées, pour thème et maintenance.
- **Tide stats / Dashboard** : si besoin d’alignement visuel avec les autres pages, ajouter des `context-badges` dans le footer (environnement, table, version) en s’appuyant sur les variables déjà passées par les contrôleurs.
- **setPeriod et timezone** : sur aquaponie, `setPeriod` utilise moment-timezone (Africa/Casablanca). Sur MSP1/N3PP/tide_stats, la version ajoutée utilise `Date()` natif (heure du navigateur). Pour une cohérence métier avec le serveur (Casablanca), on pourra charger moment-timezone sur ces pages et aligner la logique de `setPeriod`.

---

## 4. Références

- Plan : `audit_pages_donnees_vs_aquaponie_34c19f43.plan.md`
- Structure type : `docs/structure_type_page_donnees.md`
- Audit aquaponie (agencement) : corrections nesting dans `aquaponie.twig`, création de `aquaponie.css`.
