# Audit UX approfondi — Portail IoT (iot.olution.info)

**Date** : 20 mars 2026  
**Périmètre** : toutes les pages du portail IoT (accueil, données, contrôle, galeries, supervision, login)  
**Méthode** : heuristiques de Nielsen + WCAG 2.2 AA + revue responsive + revue orientée tâches  

---

## Table des matières

1. [Cartographie des parcours](#1-cartographie-des-parcours)
2. [Audit heuristique par parcours](#2-audit-heuristique-par-parcours)
3. [Audit accessibilité (WCAG 2.2 AA)](#3-audit-accessibilité-wcag-22-aa)
4. [Audit responsive et interactions](#4-audit-responsive-et-interactions)
5. [Audit du système visuel](#5-audit-du-système-visuel)
6. [Backlog priorisé P0 / P1 / P2](#6-backlog-priorisé)
7. [Quick wins](#7-quick-wins)
8. [Refontes ciblées](#8-refontes-ciblées)
9. [Checklist de validation post-correction](#9-checklist-de-validation)

---

## 1. Cartographie des parcours

### 1.1 Parcours « Consultation » (public)

```
Accueil (/)
├── Aquaponie → /aquaponie (ou /aquaponie-alt)
│   ├── Filtrage période (7 boutons + formulaire personnalisé)
│   ├── Mode live (toggle, intervalle, auto-scroll)
│   ├── Graphiques Highcharts (niveaux, température, chimie)
│   └── Export CSV
├── Potager → /meteo
│   ├── Mêmes filtres et mode live
│   ├── Graphiques (luminosité, sol, températures, cycles)
│   └── Iframe mesures manuelles (Google Sheets)
├── Élevage → /serre
│   ├── Mêmes filtres et mode live
│   └── Graphiques (humidité sol, physique, système)
├── Galeries → /gallery
│   ├── /gallery/ffp3 (timelapse aquaponie)
│   ├── /gallery/msp1 (timelapse potager)
│   └── /gallery/n3pp (timelapse élevage)
└── Descriptions → /aquaponie-description, /meteo-description, /serre-description
```

**Points de rupture identifiés** :
- Pas de lien vers la Supervision depuis le menu principal ni l'accueil
- Pas de lien vers la vue alternative (`/aquaponie-alt`) depuis `/aquaponie`
- Filtrage en bas des pages de données → l'utilisateur doit scroller pour ajuster la période
- Le parcours Galeries envoie directement vers les timelapses, pas vers l'index galeries

### 1.2 Parcours « Contrôle » (authentifié)

```
Accès route protégée (/aquaponie-control, /meteo-control, /serre-control)
├── [non authentifié] → Redirection /login?redirect=<url>
│   └── Formulaire (username, password, CSRF, redirect)
│       └── [succès] → Retour à l'URL demandée
└── [authentifié] → Page de contrôle
    ├── Badge synchronisation (CONNEXION → SYNC → ERREUR)
    ├── Switches (toggles GPIO) → requête API → toast succès/erreur
    ├── Paramètres numériques → auto-save (debounce 450ms) → indicateur
    └── Actions système (Reset ESP, OTA) → exécution immédiate
```

**Points de rupture identifiés** :
- Reset ESP et Forçage réveil sans aucune confirmation
- Login sans indicateur de chargement pendant la soumission
- Pas d'indicateur de dernier état physique sur MSP1/N3PP (présent sur FFP3)

### 1.3 Parcours « Galerie admin » (authentifié)

```
/admin/gallery/{slug}
├── Grille photos paginée + lightbox
├── Liens vers corbeille et autres galeries
└── /admin/gallery/{slug}/trash
    ├── Sélection (checkboxes) + actions bulk
    ├── Restaurer / Supprimer sélection / Vider corbeille
    └── confirm() natif → API → toast → rechargement
```

**Points de rupture identifiés** :
- Bouton « Vider la corbeille » toujours actif, sans sélection préalable
- `confirm()` natif peu accessible (non stylisable, pas de focus trap)
- Double-clic possible sur les actions (pas de désactivation pendant l'appel API)

### 1.4 Parcours « Supervision » (authentifié)

```
/supervision
├── Grille live (8 modules : prod + test × 4 projets)
├── Toggles « Afficher dans le menu »
├── Liens directs vers toutes les pages
└── Actions admin (vider caches, logs cron)
```

**Points de rupture identifiés** :
- Page très longue avec des dizaines de liens, duplication prod/test
- Accessible uniquement via le footer → invisible pour la majorité des utilisateurs

---

## 2. Audit heuristique par parcours

### H1 — Visibilité de l'état du système

| Page | Constat | Sévérité |
|------|---------|----------|
| Accueil | Badges live (LIVE/HORS LIGNE) avec polling 15s — bon feedback | OK |
| Données | Mode live avec badge, mais caché en bas de page | Moyenne |
| Contrôle | Badge sync en haut à droite (SYNC/ERREUR) — bien visible | OK |
| Dashboard | Panneau santé système avec countdown — bon feedback | OK |
| Galerie trash | Compteur sélection mis à jour — OK | OK |

### H2 — Correspondance système / monde réel

| Page | Constat | Sévérité |
|------|---------|----------|
| Données MSP1 | Libellés capteurs « A », « B », « C », « D » → non explicites | Moyenne |
| Données N3PP | Unité « UA » pour l'humidité du sol → non expliquée | Moyenne |
| Dashboard | Noms de colonnes techniques (`EauAquarium`, `TempEau`) → compréhensibles mais pas localisés | Faible |

### H3 — Contrôle et liberté de l'utilisateur

| Page | Constat | Sévérité |
|------|---------|----------|
| Contrôle FFP3 | Reset ESP = action immédiate sans annulation possible | Haute |
| Galerie trash | « Vider la corbeille » = action destructive irréversible, `confirm()` seule protection | Haute |
| Login | Pas de lien retour vers l'accueil depuis le formulaire | Faible |

### H4 — Cohérence et standards

| Page | Constat | Sévérité |
|------|---------|----------|
| Aquaponie | État « aucune donnée » absent (MSP1/N3PP l'ont) | Moyenne |
| Contrôle MSP1/N3PP | Pas d'indicateur de dernier état (FFP3 l'a via `data-indicator`) | Moyenne |
| Galerie | Typo « precedente » au lieu de « précédente » (aria-label) | Faible |
| Pagination | « Precedent » sans accent (gallery.twig L55) | Faible |
| Copyright | « 2025 » hardcodé dans le footer → sera obsolète | Faible |

### H5 — Prévention des erreurs

| Page | Constat | Sévérité |
|------|---------|----------|
| Contrôle | Reset ESP et Forçage réveil sans confirmation modale | Haute |
| Galerie trash | Purge via `confirm()` natif, pas de modal explicite | Moyenne |
| Auto-save | Debounce 450ms, mais pas de confirmation avant envoi | Faible |

### H6 — Reconnaissance plutôt que mémorisation

| Page | Constat | Sévérité |
|------|---------|----------|
| Données | Filtrage en bas de page → l'utilisateur doit mémoriser qu'il faut scroller | Moyenne |
| Navigation | Supervision absente du menu principal → il faut la connaître | Moyenne |
| Timelapse | Panneau paramètres masqué par défaut → premier usage non guidé | Faible |

### H7 — Flexibilité et efficacité

| Page | Constat | Sévérité |
|------|---------|----------|
| Données | 7 filtres rapides + formulaire personnalisé — bon | OK |
| Timelapse | Vitesses ½× à 8× + scrubber — bon | OK |
| Galerie | Pas de recherche par date ou nom de fichier | Faible |

### H8 — Design esthétique et minimaliste

| Page | Constat | Sévérité |
|------|---------|----------|
| Accueil | Beaucoup de badges par carte projet (7 pour l'aquaponie) | Faible |
| Données | 5+ sections de graphiques + filtrage → charge cognitive élevée | Moyenne |
| Supervision | Dizaines de liens, duplication prod/test | Moyenne |

### H9 — Aide à la récupération des erreurs

| Page | Constat | Sévérité |
|------|---------|----------|
| Login | Messages d'erreur clairs avec icône — bon | OK |
| Contrôle | Toasts succès/erreur — bon. Mais erreur réseau auto-save peu visible | Moyenne |
| Galerie trash | Toast erreur 3.5s → peut disparaître avant lecture sur mobile | Faible |

### H10 — Aide et documentation

| Page | Constat | Sévérité |
|------|---------|----------|
| Données | Pas de légende ou aide contextuelle pour les graphiques | Faible |
| Login | Pas de lien « mot de passe oublié » | Faible |
| Contrôle | Avertissement texte en haut (« Les commandes agissent... ») — OK | OK |

---

## 3. Audit accessibilité (WCAG 2.2 AA)

### 3.1 Navigation et structure

| Critère | Constat | Fichier | Sévérité |
|---------|---------|---------|----------|
| **Lien « Aller au contenu »** | Absent | `layout.twig` | P0 |
| **`<nav>` sans aria-label** | `<nav id="nav">` sans label | `_nav.twig` L3 | P0 |
| **Bouton nav mobile** | `<a href="#navPanel" id="navPanelToggle">Menu</a>` — pas de `role="button"`, pas d'`aria-expanded`, pas d'`aria-controls` | `main.js` L129-131 | P0 |
| **Fermeture nav panel** | `<a href="#navPanel" class="close"></a>` — pas de texte ni d'`aria-label` | `main.js` L150 | P0 |
| **Focus trap nav mobile** | Pas de gestion de focus dans le panneau mobile | `main.js` | P1 |
| **Ordre de focus** | Pas de retour du focus au bouton après fermeture du panneau | `main.js` | P1 |
| **`lang` HTML** | `<html lang="fr">` — correct | `layout.twig` L2 | OK |
| **Liens footer** | `aria-label` absent mais texte visible — acceptable | `_footer.twig` | OK |

### 3.2 Formulaires et inputs

| Critère | Constat | Fichier | Sévérité |
|---------|---------|---------|----------|
| **Labels login** | `for`/`id` correctement liés, `autocomplete` présent | `login.twig` | OK |
| **CSRF token** | Hidden input — OK | `login.twig` L36 | OK |
| **Checkboxes corbeille** | `<input type="checkbox" ... title="Sélectionner" />` — pas de `<label>` ni `aria-label` | `gallery_trash.twig` L183 | P0 |
| **Labels paramètres contrôle** | Certains via `<label class="parameter-item">` sans `for` explicite | `msp1_control.twig`, `n3pp_control.twig` | P1 |
| **Inputs numériques** | Pas d'`aria-describedby` pour les hints/erreurs | `control-auto-save.js` | P1 |

### 3.3 Tableaux

| Critère | Constat | Fichier | Sévérité |
|---------|---------|---------|----------|
| **`<caption>`** | Absent sur tous les tableaux du dashboard | `dashboard.twig` L138, L208 | P0 |
| **`scope="col"`** | Absent sur les `<th>` | `dashboard.twig` L141, L211 | P0 |
| **En-têtes dynamiques** | Noms techniques (`EauAquarium`) comme en-têtes | `dashboard.twig` L141 | P1 |

### 3.4 Images et alternatives

| Critère | Constat | Fichier | Sévérité |
|---------|---------|---------|----------|
| **Alt galerie** | `alt="Photo {{ loop.index }}"` — générique, pas informatif | `gallery.twig` L38 | P1 |
| **Alt corbeille** | `alt="{{ item.filename }}"` — meilleur (nom de fichier) | `gallery_trash.twig` L185 | OK |
| **Alt lightbox** | `alt=""` initial, mis à jour en JS — OK si JS actif | `gallery.twig` L47 | OK |
| **Icônes décoratives** | `aria-hidden="true"` sur les icônes Font Awesome — correct | Partout | OK |

### 3.5 Feedback et contenu dynamique

| Critère | Constat | Fichier | Sévérité |
|---------|---------|---------|----------|
| **Toasts sans `role`** | Pas de `role="status"` ni `role="alert"` sur le conteneur | `toast-notifications.js` L17 | P0 |
| **Bouton fermer toast** | `<button class="toast-close" onclick="...">` sans `aria-label` | `toast-notifications.js` L38 | P0 |
| **`aria-live` accueil** | `aria-live="polite"` sur les statuts live — correct | `home.twig` L60 | OK |
| **Timelapse feedback** | `aria-live="polite"` — correct | `gallery_timelapse.twig` | OK |
| **Lightbox `aria-hidden`** | Géré en JS (true/false) — correct | `gallery.twig` L44 | OK |

### 3.6 Contrastes (à vérifier manuellement)

| Élément | Couleur / Fond | Ratio estimé | Verdict |
|---------|----------------|--------------|---------|
| `--text-secondary` (#6b7280) sur blanc | ~5.0:1 | Limite AA |
| Login `.alert-error` (#c33 sur #fee) | ~4.2:1 | Limite AA |
| Login `.alert-success` (#3c3 sur #efe) | ~3.3:1 | **Échoue AA** |
| `#18bfef` (liens main.css legacy) sur blanc | ~2.8:1 | **Échoue AA** |
| `--status-warning-text` (#856404) sur #fff3cd | ~4.6:1 | Passe AA |
| Footer `#6b7280` sur fond clair | ~5.0:1 | Limite AA |

---

## 4. Audit responsive et interactions

### 4.1 Breakpoints

Le projet utilise des breakpoints **non uniformes** entre les fichiers CSS :

| Source | Breakpoints |
|--------|-------------|
| main.css (Massively) | 1680, 1280, 980, 736, 480, 360 px |
| common-data.css | 768, 520 px |
| control-styles.css | 1024, 768, 480, 400 px |
| login-styles.css | 480 px |
| home-styles.css | 768 px |

**Recommandation** : centraliser les breakpoints en variables CSS custom ou au minimum harmoniser vers un jeu commun (ex. 1280, 980, 768, 480 px).

### 4.2 Navigation mobile (<=980px)

- Le contenu du `<nav>` est déplacé dans `#navPanel` via jQuery breakpoints
- Le panneau glisse depuis la droite avec `hideOnClick`, `hideOnSwipe`
- Le live badge (`#live-badge`) est repositionné à `right: 100px` pour éviter le bouton Menu → bien pensé
- **Manque** : pas de focus trap, pas de gestion `aria-expanded`, pas de retour du focus

### 4.3 Tableaux sur mobile

- Les tableaux du dashboard (`dashboard.twig`) n'ont pas de `overflow-x: auto` explicite sur un wrapper → risque de débordement horizontal sur petit écran
- Les tableaux de statistiques `common-data.css` sont dans `.modern-table` qui peut avoir un scroll horizontal, mais à vérifier

### 4.4 Interactions clavier

| Composant | Escape | Tab | Enter | Flèches | Verdict |
|-----------|--------|-----|-------|---------|---------|
| Lightbox | Ferme | Non piégé | N/A | Prev/Next | P1 (focus trap manquant) |
| Nav panel mobile | Non géré | Non piégé | N/A | N/A | P0 (ARIA + focus) |
| Toasts | N/A | Non focusable | N/A | N/A | P1 (bouton fermer) |
| Switches contrôle | N/A | OK (input natif) | OK | N/A | OK |
| Filtres rapides | N/A | OK (boutons) | OK | N/A | OK |

### 4.5 Interactions tactiles

- `hideOnSwipe` sur le nav panel → bon pour mobile
- Lightbox : pas de gestion swipe (uniquement boutons) → P2
- Back-to-top : visible, cliquable → OK
- Timelapse scrubber : input range natif → OK

### 4.6 `user-scalable`

```html
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no" />
```

`user-scalable=no` **bloque le zoom sur mobile** — c'est un échec WCAG 2.2 AA (critère 1.4.4 Resize text). Les utilisateurs malvoyants ne peuvent pas agrandir le texte.

**Sévérité** : P0

---

## 5. Audit du système visuel

### 5.1 Points forts

- Design system structuré via `theme-variables.css` avec variables sémantiques
- Support dark mode complet avec fallback `prefers-color-scheme`
- Bonne gestion de `prefers-reduced-motion` dans les transitions thème
- Typographies lisibles (Cabin pour le corps, Raleway pour les titres)
- Icônes Font Awesome cohérentes avec `aria-hidden="true"`
- Cards, badges et stat-cards visuellement modernes et bien espacés

### 5.2 Incohérences identifiées

| Problème | Détail |
|----------|--------|
| Couleurs hardcodées vs variables | `#008B74` utilisé directement alors que `--accent-primary` existe. `#18bfef` (bleu legacy Massively) en conflit avec la palette verte IoT |
| Breakpoints non centralisés | 3 jeux de breakpoints différents selon les fichiers |
| Styles inline | `style="margin-top: 10px;"` et `style="color: #dc3545;"` dans les templates (`home.twig`, `gallery.twig`) |
| Couleurs alertes login | `#c33`/`#3c3` non liées aux variables `--status-*` |
| Border hardcodées | `#eeeeee` dans le nav panel toggle, alors que `--border-color` existe |
| Animations sans `prefers-reduced-motion` | `pulse` sur `badge-success`, `pulse-status` sur `.status-indicator.is-animated`, `value-updated` glow |

### 5.3 Duplication CSS

- `.live-toggle-switch` défini dans `realtime-styles.css` ET `control-styles.css`
- Dégradé `linear-gradient(135deg, #008B74, #00B794)` copié dans login, home, control, info-banner au lieu d'une classe partagée
- `border-left: 4px solid #008B74` répété dans section-header, chemistry-info, callout

---

## 6. Backlog priorisé

### P0 — Critique (impact accessibilité / usabilité majeure)

| # | Constat | Fichier(s) | Effort | Correction |
|---|---------|------------|--------|------------|
| 1 | **`user-scalable=no`** bloque le zoom mobile (WCAG 1.4.4) | `layout.twig` L6 | Faible | Retirer `user-scalable=no` |
| 2 | **Pas de lien « Aller au contenu »** (skip link) | `layout.twig` | Faible | Ajouter `<a href="#main" class="sr-only sr-only-focusable">Aller au contenu</a>` avant `#wrapper` |
| 3 | **`<nav>` sans `aria-label`** | `_nav.twig` L3 | Faible | `<nav id="nav" aria-label="Navigation principale">` |
| 4 | **Bouton nav mobile sans ARIA** | `main.js` L129-131 | Faible | Ajouter `role="button"`, `aria-expanded="false"`, `aria-controls="navPanel"`, `aria-label="Ouvrir le menu"` |
| 5 | **Fermeture nav panel sans label** | `main.js` L150 | Faible | Ajouter `aria-label="Fermer le menu"` sur le lien `.close` |
| 6 | **Toasts sans rôle ARIA** | `toast-notifications.js` L17 | Faible | `this.container.setAttribute('role', 'status')` ; `aria-live="polite"` |
| 7 | **Bouton fermer toast sans `aria-label`** | `toast-notifications.js` L38 | Faible | `aria-label="Fermer la notification"` |
| 8 | **Checkboxes corbeille sans label** | `gallery_trash.twig` L183 | Faible | Ajouter `aria-label="Sélectionner {{ item.filename }}"` |
| 9 | **Tableaux dashboard sans `<caption>` ni `scope`** | `dashboard.twig` L138, L208 | Faible | Ajouter `<caption>` et `scope="col"` sur les `<th>` |
| 10 | **Reset ESP sans confirmation** | `control.twig`, `control-actions.js` | Moyen | Modal de confirmation pour GPIO 110 et 115 |
| 11 | **Contrastes insuffisants** login alert-success `#3c3` sur `#efe` et liens legacy `#18bfef` | `login-styles.css`, `main.css` | Faible | Passer à `--status-success-text` et remplacer `#18bfef` par `--accent-primary` |

### P1 — Important (cohérence, feedback, accessibilité secondaire)

| # | Constat | Fichier(s) | Effort | Correction |
|---|---------|------------|--------|------------|
| 12 | **Focus trap absent** dans la lightbox galerie | `gallery.twig`, `gallery_trash.twig` (JS) | Moyen | Implémenter un focus trap entre les boutons prev/next/close |
| 13 | **Focus trap absent** dans le nav panel mobile | `main.js` | Moyen | Piéger le focus dans `#navPanel` quand il est ouvert |
| 14 | **Retour focus** après fermeture lightbox et nav panel | `main.js`, `gallery.twig` | Moyen | Mémoriser l'élément déclencheur, y redonner le focus à la fermeture |
| 15 | **Supervision absente du menu principal** | `_nav.twig` | Faible | Ajouter un lien conditionnel (si authentifié) ou dans un sous-menu |
| 16 | **Filtrage en bas des pages de données** | `aquaponie.twig`, `msp1_data.twig`, `n3pp_data.twig` | Moyen | Déplacer ou dupliquer la barre de filtrage en haut de page (sticky ou en-tête) |
| 17 | **`confirm()` natif** pour actions destructives corbeille | `gallery_trash.twig` | Moyen | Remplacer par un modal accessible (focus trap, boutons Annuler/Confirmer) |
| 18 | **Login sans indicateur de chargement** | `login.twig` | Faible | Désactiver le bouton et afficher un spinner pendant la soumission |
| 19 | **Alt images galerie** générique `"Photo X"` | `gallery.twig` L38 | Faible | Utiliser le nom de fichier ou la date : `alt="Photo {{ filename }}"` |
| 20 | **Labels paramètres contrôle** sans `for` explicite | `msp1_control.twig`, `n3pp_control.twig` | Faible | Ajouter `for` et `id` sur chaque paire label/input |
| 21 | **Indicateur dernier état** absent MSP1/N3PP | `_control_base.twig` | Moyen | Harmoniser avec le pattern `data-indicator` de FFP3 |
| 22 | **Désactivation boutons** pendant les appels API (corbeille) | `gallery_trash.twig` (JS) | Faible | `btn.disabled = true` avant fetch, ré-activer après |
| 23 | **Libellés capteurs MSP1** (A, B, C, D) non explicites | `msp1_data.twig` | Faible | Renommer en noms lisibles (ex. « Lumière haute », « Lumière basse ») |
| 24 | **Unité « UA »** non expliquée pour l'humidité du sol N3PP | `n3pp_data.twig` | Faible | Ajouter une infobulle ou légende (« UA = Unité Arbitraire ») |

### P2 — Amélioration (polish, cohérence fine, bonnes pratiques)

| # | Constat | Fichier(s) | Effort | Correction |
|---|---------|------------|--------|------------|
| 25 | **Typo** « precedente » → « précédente » dans aria-label | `gallery.twig` L46 | Faible | Corriger l'accent |
| 26 | **Typo** « Precedent » → « Précédent » dans la pagination | `gallery.twig` L55 | Faible | Corriger l'accent |
| 27 | **Copyright 2025** hardcodé dans le footer | `_footer.twig` L33 | Faible | Utiliser `{{ "now"|date("Y") }}` |
| 28 | **Couleurs hardcodées** vs variables CSS | `main.css`, `common-data.css`, `control-styles.css` | Élevé | Migration progressive vers les variables de `theme-variables.css` |
| 29 | **Breakpoints non centralisés** | Tous les CSS | Élevé | Définir des custom properties ou un jeu commun documenté |
| 30 | **Styles inline** dans les templates | `home.twig`, `gallery.twig` | Faible | Extraire dans les CSS correspondants |
| 31 | **Animations sans `prefers-reduced-motion`** | `realtime-styles.css` (pulse badges), `common-data.css` | Faible | Ajouter `@media (prefers-reduced-motion: reduce) { animation: none }` |
| 32 | **Duplication CSS** `.live-toggle-switch` | `realtime-styles.css`, `control-styles.css` | Faible | Factoriser dans un fichier partagé |
| 33 | **Swipe lightbox** non géré sur mobile | `gallery.twig`, `gallery_trash.twig` | Moyen | Ajouter des événements touch pour navigation gauche/droite |
| 34 | **Pas de message « aucune donnée »** sur aquaponie | `aquaponie.twig` | Faible | Harmoniser avec MSP1/N3PP qui affichent le message |
| 35 | **État vide** galeries landing si `galleries` est vide | `gallery_landing.twig` | Faible | Ajouter un message « Aucune galerie configurée » |
| 36 | **Pas de lien retour** depuis la page login | `login.twig` | Faible | Ajouter un lien « Retour à l'accueil » |
| 37 | **Iframe Google Sheets** (page météo) dépend d'un service externe | `msp1_data.twig` | Faible | Ajouter un message de fallback si l'iframe ne charge pas |
| 38 | **Référence `demoMode`** dans le JS timelapse sans UI correspondante | `gallery_timelapse.twig` | Faible | Nettoyer ou exposer la fonctionnalité |

---

## 7. Quick wins

Corrections réalisables en moins de 30 minutes chacune, avec un impact immédiat :

1. **Retirer `user-scalable=no`** de `layout.twig` (P0, 2 min)
2. **Ajouter un skip link** `<a href="#main">Aller au contenu</a>` dans `layout.twig` (P0, 5 min)
3. **`aria-label` sur `<nav>`** dans `_nav.twig` (P0, 1 min)
4. **`aria-label` sur le bouton fermer toast** dans `toast-notifications.js` (P0, 2 min)
5. **`role="status"` + `aria-live`** sur le conteneur toast (P0, 2 min)
6. **`aria-label` sur les checkboxes** corbeille dans `gallery_trash.twig` (P0, 5 min)
7. **`<caption>` et `scope="col"`** sur les tableaux du dashboard (P0, 10 min)
8. **Corriger les typos** « precedente » et « Precedent » dans `gallery.twig` (P2, 2 min)
9. **Copyright dynamique** dans `_footer.twig` (P2, 1 min)
10. **Corriger le contraste** alert-success login → utiliser `#1e7e34` sur `#d4edda` (P0, 5 min)
11. **ARIA sur navPanelToggle** : `role="button"`, `aria-expanded`, `aria-controls`, `aria-label` (P0, 15 min)
12. **`aria-label="Fermer le menu"`** sur le bouton close du nav panel (P0, 2 min)
13. **Désactiver les boutons** de la corbeille pendant les appels API (P1, 10 min)
14. **Login : indicateur de chargement** (spinner + disabled sur submit) (P1, 10 min)

---

## 8. Refontes ciblées

Interventions structurantes nécessitant une conception préalable :

### 8.1 Barre de filtrage en haut de page

**Pages** : aquaponie, msp1_data, n3pp_data  
**Effort** : moyen (HTML + CSS + JS)  
**Impact** : réduit la charge cognitive, accès immédiat aux filtres  
**Approche** : sticky bar en haut de la zone de contenu, ou duplication filtres rapides en haut + formulaire complet en bas  

### 8.2 Modale de confirmation accessible

**Pages** : contrôle (Reset ESP), galerie trash (purge)  
**Effort** : moyen (composant JS réutilisable)  
**Impact** : prévention d'erreurs critiques, accessibilité  
**Approche** : composant `ConfirmModal` avec focus trap, Escape pour fermer, boutons Annuler/Confirmer, `role="dialog"`, `aria-modal="true"`  

### 8.3 Focus trap pour overlays

**Pages** : lightbox galerie, nav panel mobile  
**Effort** : moyen (utilitaire JS partagé)  
**Impact** : accessibilité clavier complète  
**Approche** : utilitaire `trapFocus(container)` / `releaseFocus()` appelé à l'ouverture/fermeture des overlays  

### 8.4 Migration couleurs vers variables CSS

**Fichiers** : `main.css`, `common-data.css`, `control-styles.css`  
**Effort** : élevé (audit exhaustif + remplacement progressif)  
**Impact** : cohérence thème, facilité de maintenance, dark mode complet  
**Approche** : par fichier, en commençant par `main.css` (legacy Massively) qui contient le plus de couleurs hardcodées  

### 8.5 Ajout Supervision au menu principal

**Fichiers** : `_nav.twig`, possiblement `AuthGuardMiddleware`  
**Effort** : faible à moyen  
**Impact** : découvrabilité de l'interface admin  
**Approche** : lien conditionnel dans la nav (visible si authentifié), ou icône engrenage dans le header  

---

## 9. Checklist de validation

Après chaque correction, vérifier :

### Accessibilité

- [ ] Parcours clavier complet : Tab → Enter → Escape sur toutes les pages modifiées
- [ ] Focus visible sur tous les éléments interactifs
- [ ] Lecteur d'écran (NVDA/VoiceOver) : vérifier les annonces des toasts, lightbox, nav panel
- [ ] Zoom 200% : contenu lisible sans scroll horizontal (après suppression `user-scalable=no`)
- [ ] axe DevTools : 0 violation critique sur chaque page modifiée

### Responsive

- [ ] Test aux breakpoints : 1280px, 980px, 768px, 480px, 360px
- [ ] Navigation mobile : ouverture/fermeture fluide, contenu accessible
- [ ] Tableaux : pas de débordement horizontal sans scroll
- [ ] Lightbox : navigation tactile et boutons visibles

### Feedback

- [ ] Toast succès/erreur : visible et annoncé
- [ ] Actions destructives : confirmation modale visible et focusable
- [ ] États de chargement : spinner visible pendant les requêtes API
- [ ] Erreurs réseau : message explicite (pas silencieux)

### Visuel

- [ ] Dark mode : toutes les pages modifiées testées en light ET dark
- [ ] Contrastes : vérifiés avec l'outil axe/Contrast Checker sur les éléments modifiés
- [ ] Pas de régression sur les animations (si `prefers-reduced-motion` ajouté)

### Non-régression

- [ ] Parcours consultation : accueil → données → filtrage → graphiques → export CSV
- [ ] Parcours contrôle : login → contrôle → toggle switch → auto-save paramètre
- [ ] Parcours galerie : index → galerie admin → lightbox → corbeille → restaurer/supprimer
- [ ] Parcours supervision : supervision → carte live → page de données
