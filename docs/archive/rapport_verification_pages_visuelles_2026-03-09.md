# Rapport de vérification visuelle des pages IoT - 9 mars 2026

## Méthodologie

Vérification par récupération HTTP du contenu HTML des pages principales de `iot.olution.info` et analyse de leur structure, contenu et liens de navigation.

---

## 1. Page d'accueil - https://iot.olution.info/

### ✅ Statut : Page chargée avec succès (HTTP 200)

### Titre de la page
`n3 iot datas - olution`

### En-tête principal
```
N3 IoT Datas
Toutes les données de suivi des objets connectés de la salle aérée n³.
```

### Menu de navigation
- **Accueil** → `/`
- **Aquaponie** → `/aquaponie`
- **Contrôle** → `/aquaponie-control`
- **Statistiques marées** → `/tide-stats`
- **Potager (MSP1)** → `/msp1/msp1datas/msp1-data.php`
- **Élevage (N3PP)** → `/n3pp/n3ppdatas/n3pp-data.php`

### ⚠️ PROBLÈME IDENTIFIÉ : Liens de navigation obsolètes

Les liens dans le menu de navigation pointent toujours vers les **anciennes URLs** :
- ❌ `/msp1/msp1datas/msp1-data.php` (ancien chemin MSP1)
- ❌ `/n3pp/n3ppdatas/n3pp-data.php` (ancien chemin N3PP)

**Liens attendus (nouvelles URLs)** :
- ✅ `/meteo` (pour MSP1)
- ✅ `/serre` (pour N3PP)

### Cartes de projets affichées

#### 1. Carte Aquaponie
- **Icône** : 🐟 (fas fa-fish)
- **Titre** : Aquaponie
- **Description** : Système d'aquaponie automatisé avec surveillance en temps réel des niveaux d'eau, températures, humidité et luminosité. Contrôle à distance des pompes, chauffage et alimentation.
- **Statistiques affichées** :
  - 3 Niveaux (eau)
  - 2 Températures
  - 2 Pompes
- **Liens** :
  - ✅ "Voir les données" → `/aquaponie`
  - ✅ "Galerie photo" → `/gallery/ffp3`

#### 2. Carte Le potager (MSP1)
- **Icône** : 🌱 (fas fa-seedling)
- **Titre** : Le potager
- **Description** : Potager connecté avec surveillance des conditions de croissance optimales. Mesure de l'humidité du sol, température ambiante et ensoleillement.
- **Statistiques affichées** :
  - Humidité sol
  - Température
  - Luminosité
- **Lien** :
  - ❌ "Voir les données" → `/msp1/msp1datas/msp1-data.php` (ancien chemin)
  - **Devrait pointer vers** : `/meteo`

#### 3. Carte L'élevage d'insectes (N3PP)
- **Icône** : 🦗 (fas fa-bug)
- **Titre** : L'élevage d'insectes
- **Description** : Élevage connecté avec surveillance des conditions d'élevage. Mesure de la température, humidité et contrôle de l'environnement.
- **Statistiques affichées** :
  - Température
  - Humidité
  - Luminosité
- **Lien** :
  - ❌ "Voir les données" → `/n3pp/n3ppdatas/n3pp-data.php` (ancien chemin)
  - **Devrait pointer vers** : `/serre`

### Sections supplémentaires visibles

- **Section "L'internet des objets à n³"** : Texte d'introduction au projet pédagogique
- **Bannière "Projet pédagogique olution"** : Mise en avant du contexte éducatif
- **Liens externes** :
  - Site officiel Lycée Lyautey
  - Espace pédagogique olution
  - Contacts : oarnould@lyceelyautey.org, abesteiro@lyceelyautey.org

### Assets chargés
- ✅ `/assets/css/main.css`
- ✅ `/assets/css/realtime-styles.css`
- ✅ `/assets/logo.png`
- ✅ Font Awesome 6.5.1 (CDN)
- ✅ `/manifest.json` (PWA)

### Éléments de design
- Design moderne avec cartes (grid responsive)
- Dégradés de couleur (#008B74 → #00B794)
- Animations au survol (transform, box-shadow)
- Icônes Font Awesome
- Layout responsive (mobile-first)

---

## 2. Page Aquaponie - https://iot.olution.info/aquaponie

### ✅ Statut : Page chargée avec succès (HTTP 200)

### Titre de la page
`n3 iot datas`

### En-tête de page
- Header moderne avec dégradé vert
- Icône flottante (animation CSS)
- Titre et description du projet aquaponie

### Graphiques détectés
- ✅ `chart-stock-area-eau-D` (graphique des niveaux d'eau)
- ✅ `chart-stock-area-temp-D` (graphique des températures)

### Scripts chargés
- ✅ jQuery 3.4.1
- ✅ Moment.js 2.29.4
- ✅ Moment Timezone 0.5.43
- ✅ Highcharts Stock (pour les graphiques)
- ✅ Modules Highcharts : exporting, export-data, accessibility

### Background personnalisé
- Image de fond : `/assets/bg-aquaponie.png`
- Animation de fondu (fade-in 1.2s)
- Couleur de base : `#e8f4f2`

### Navigation
- Menu identique à la page d'accueil
- Lien actif : "Aquaponie"

### Conclusion
✅ La page aquaponie se charge correctement avec tous les éléments nécessaires pour afficher les graphiques de données en temps réel.

---

## 3. Page Galerie FFP3 - https://iot.olution.info/gallery/ffp3

### ✅ Statut : Page chargée avec succès (HTTP 200)

### Titre de la page
`Photos du potager aquaponie - n3 iot datas`

### En-tête de galerie
- Hero section avec dégradé vert
- Titre H1 (non extrait dans le snippet)
- Métadonnées de galerie (nombre de photos, date, etc.)

### Structure de la galerie
- Grid responsive : `grid-template-columns: repeat(auto-fill, minmax(260px, 1fr))`
- Gap de 16px entre les images
- Cartes avec ombre et effet hover (translateY, box-shadow)
- Images : 220px de hauteur, object-fit: cover

### ⚠️ État actuel : Galerie vide
- ✅ La page se charge correctement
- ✅ Le layout est en place
- ❌ **Aucune image détectée** (0 images trouvées)
- ✅ Message "galerie vide" présent dans le HTML

### Éléments de navigation
- Bouton retour vers `/aquaponie` (classe `gallery-back`)
- Pagination prête (si des images sont ajoutées)

### Styles de galerie
- Design moderne avec cartes arrondies (border-radius: 12px)
- Hover effects
- Caption pour chaque image
- Responsive design

### Conclusion
✅ La page galerie FFP3 se charge correctement avec un layout fonctionnel, mais **aucune photo n'est actuellement disponible**. Le système est prêt à afficher des images dès qu'elles seront uploadées par l'ESP32-CAM.

---

## Résumé des problèmes identifiés

### 🔴 Critique : Liens de navigation obsolètes

**Emplacement** : Page d'accueil (`/`) - Menu de navigation ET cartes de projets

**Problème** :
- Les liens vers MSP1 et N3PP utilisent les anciens chemins longs
- Navigation : `/msp1/msp1datas/msp1-data.php` et `/n3pp/n3ppdatas/n3pp-data.php`
- Cartes projets : mêmes liens obsolètes

**Solution requise** :
- Remplacer `/msp1/msp1datas/msp1-data.php` par `/meteo`
- Remplacer `/n3pp/n3ppdatas/n3pp-data.php` par `/serre`
- Mettre à jour dans le template de la page d'accueil (probablement `serveur/src/views/home.php` ou équivalent)

### 🟡 Mineur : Galerie FFP3 vide

**Emplacement** : `/gallery/ffp3`

**Statut** : Fonctionnel mais sans contenu
- La page se charge correctement
- Le layout est opérationnel
- Aucune photo uploadée pour le moment

**Action** : Vérifier que l'ESP32-CAM du projet FFP3 est opérationnel et envoie des photos.

---

## Recommandations

1. **Priorité haute** : Corriger les liens de navigation obsolètes dans la page d'accueil
   - Fichier probable : `serveur/src/views/home.php` ou template équivalent
   - Rechercher toutes les occurrences de `/msp1/msp1datas/msp1-data.php` et `/n3pp/n3ppdatas/n3pp-data.php`

2. **Vérification** : Tester les nouvelles URLs `/meteo` et `/serre` pour s'assurer qu'elles fonctionnent correctement

3. **Galerie** : Vérifier l'état de l'ESP32-CAM FFP3 et son upload de photos

4. **Documentation** : Mettre à jour la documentation serveur pour refléter les nouvelles URLs canoniques

---

## Conclusion générale

✅ **Pages fonctionnelles** : Les trois pages se chargent correctement avec leurs assets et leur design moderne.

⚠️ **Navigation incohérente** : Les liens de navigation utilisent toujours les anciens chemins longs au lieu des nouvelles URLs courtes (`/meteo`, `/serre`).

📸 **Galerie vide** : La galerie FFP3 est opérationnelle mais ne contient aucune photo pour le moment.

**Action immédiate recommandée** : Corriger les liens de navigation dans la page d'accueil pour utiliser les nouvelles URLs.
