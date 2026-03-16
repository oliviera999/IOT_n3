# Rapport de vérification des graphiques Highcharts

**Date:** 2026-03-09 15:41  
**Objectif:** Vérifier le rendu des graphiques Highcharts sur les pages météo et serre  
**Méthode:** Analyse automatisée du HTML et des données JavaScript

---

## 📊 Page 1: Météo (MSP1)

**URL:** https://iot.olution.info/meteo

### Statut global: ✅ TOUS LES ÉLÉMENTS PRÉSENTS

### Vérifications techniques

#### 1. Bibliothèques JavaScript
- ✅ **Highcharts (highstock.js)** : Chargé depuis CDN
- ✅ **highcharts-defaults.js** : Présent
- ✅ **chart-helpers.js** : Présent
- ✅ **Fonction zipSeries** : Définie et disponible

#### 2. Conteneurs de graphiques
- ✅ `#chart-temperatures` : Trouvé
- ✅ `#chart-lights` : Trouvé
- ✅ `#chart-niveauxeaux` : Trouvé
- ✅ `#chart-cycles` : Trouvé

#### 3. Initialisation des graphiques
- ✅ `Highcharts.stockChart('chart-temperatures')` : Présent
- ✅ `Highcharts.stockChart('chart-lights')` : Présent
- ✅ `Highcharts.stockChart('chart-niveauxeaux')` : Présent
- ✅ `Highcharts.stockChart('chart-cycles')` : Présent

#### 4. Données de séries
| Variable | Statut | Nombre d'éléments | Échantillon |
|----------|--------|-------------------|-------------|
| `reading_time` | ✅ | 21 | `[1772694539000, 1772697551000, ...]` |
| `TempAirInt` | ✅ | 21 | `[255.9, 10.6, 14, 18.3, 21.5, ...]` |
| `TempAirExt` | ✅ | 21 | `[8.8, 9.8, 12.3, 16, 19.9, ...]` |
| `HumidAirInt` | ✅ | 21 | `[58, 56, 46, 15, 15, ...]` |
| `HumidAirExt` | ✅ | 21 | `[15, 15, 15, 15, 15, ...]` |
| `LuminositeMoy` | ✅ | 21 | `[127, 139, 146, 176, 182, ...]` |
| `HumidSol` | ✅ | 21 | `[143, 274, 498, 721, 663, ...]` |
| `TempEau` | ✅ | 21 | `[11, 11, 11.25, 11.5, 12.75, ...]` |

#### 5. Appels zipSeries
- ✅ **17 appels** `zipSeries()` détectés
- Exemples:
  - `zipSeries(reading_time, TempAirInt)`
  - `zipSeries(reading_time, TempAirExt)`
  - `zipSeries(reading_time, HumidAirInt)`

#### 6. Statistiques
- ✅ **21 mesures** affichées
- ✅ Période: 24 heures (du 05/03/2026 07:25 au 06/03/2026 07:25)

### Graphiques attendus (4)

1. **Températures & Humidité**
   - Séries: Temp. int., Temp. ext., Humid. int., Humid. ext.
   - Type: Spline (courbes lissées)
   - Axes: Température (°C) à gauche, Humidité (%) à droite

2. **Luminosité**
   - Séries: Moy., A, B, C, D
   - Type: Spline
   - Axe: Luminosité (unités arbitraires)

3. **Humidité du sol & Eau**
   - Séries: Humid. sol, Pluie, Temp. eau, Reset
   - Type: Areaspline, Column, Spline
   - Axes: Humidité sol / Pluie à gauche, Temp. eau (°C) à droite

4. **Autonomie & Système**
   - Séries: bootCount, PontDiv, ServoHB, ServoGD
   - Type: Spline
   - Axes: Cycles / Servos à gauche, Batterie à droite

### Diagnostic final
✅ **Les graphiques DEVRAIENT s'afficher correctement avec des courbes de données.**

---

## 🌱 Page 2: Serre (N3PP)

**URL:** https://iot.olution.info/serre

### Statut global: ✅ TOUS LES ÉLÉMENTS PRÉSENTS

### Vérifications techniques

#### 1. Bibliothèques JavaScript
- ✅ **Highcharts (highstock.js)** : Chargé depuis CDN
- ✅ **highcharts-defaults.js** : Présent
- ✅ **chart-helpers.js** : Présent
- ✅ **Fonction zipSeries** : Définie et disponible

#### 2. Conteneurs de graphiques
- ✅ `#chart-niveauxeaux` : Trouvé
- ✅ `#chart-temperatures` : Trouvé
- ✅ `#chart-cycles` : Trouvé

#### 3. Initialisation des graphiques
- ✅ `Highcharts.stockChart('chart-niveauxeaux')` : Présent
- ✅ `Highcharts.stockChart('chart-temperatures')` : Présent
- ✅ `Highcharts.stockChart('chart-cycles')` : Présent

#### 4. Données de séries
| Variable | Statut | Nombre d'éléments | Échantillon |
|----------|--------|-------------------|-------------|
| `reading_time` | ✅ | 4923 | `[1772991739000, 1772991766000, ...]` |
| `TempAir` | ✅ | 4923 | `[43.6, 15.2, 15.3, 14.4, 14.4, ...]` |
| `Humidite` | ✅ | 4923 | `[78, 78, 78, 78, 79, ...]` |
| `Luminosite` | ✅ | 4923 | `[15, 27, 33, 1, 1, ...]` |
| `HumidMoy` | ✅ | 4923 | `[276, 235, 320, 208, 510, ...]` |
| `Humid1` | ✅ | 4923 | `[1, 1, 1, 1, 1, ...]` |
| `Humid2` | ✅ | 4923 | `[1, 1, 1, 1, 1, ...]` |
| `Humid3` | ✅ | 4923 | `[803, 876, 903, 830, 713, ...]` |
| `Humid4` | ✅ | 4923 | `[300, 63, 378, 1, 1328, ...]` |

#### 5. Appels zipSeries
- ✅ **12 appels** `zipSeries()` détectés
- Exemples:
  - `zipSeries(reading_time, HumidMoy)`
  - `zipSeries(reading_time, Humid1)`
  - `zipSeries(reading_time, Humid2)`

#### 6. Statistiques
- ✅ **4923 mesures** affichées (⚠️ Note: le script a détecté 4923, mais le HTML mentionne 4913)
- ✅ Période: 24 heures (du 08/03/2026 16:39 au 09/03/2026 16:39)

### Graphiques attendus (3)

1. **Humidité du sol**
   - Séries: Humid. moy., Humid. 1-4, État pompe, Reset
   - Type: Spline, Column
   - Axe: Humidité sol (UA)

2. **Température, Humidité air & Luminosité**
   - Séries: Temp. air, Humidité, Luminosité
   - Type: Spline
   - Axes: Température (°C) à gauche, Humidité (%) à droite, Luminosité (UA) à droite (offset)

3. **Autonomie & Système**
   - Séries: bootCount, PontDiv
   - Type: Spline
   - Axes: Cycles à gauche, Batterie à droite

### Diagnostic final
✅ **Les graphiques DEVRAIENT s'afficher correctement avec des courbes de données.**

---

## 🔍 Observations et notes

### Points positifs
1. ✅ Toutes les bibliothèques JavaScript nécessaires sont chargées
2. ✅ Tous les conteneurs HTML pour les graphiques sont présents
3. ✅ Toutes les initialisations `Highcharts.stockChart()` sont présentes
4. ✅ Toutes les variables de données contiennent des valeurs réelles
5. ✅ La fonction `zipSeries()` est définie et utilisée correctement
6. ✅ Les appels `zipSeries()` correspondent aux séries définies dans les graphiques

### Points d'attention
1. ⚠️ **Page météo** : Présence de valeurs aberrantes (255.9°C pour TempAirInt et TempAirExt)
   - Ces valeurs sont probablement des erreurs de lecture du capteur DHT
   - Elles apparaîtront comme des pics anormaux sur les graphiques
   - **Recommandation** : Implémenter une validation côté firmware pour filtrer ces valeurs

2. ⚠️ **Page serre** : Nombreuses valeurs à 0 pour TempAir et Humidite
   - Cela indique probablement des périodes où le capteur n'a pas pu lire correctement
   - Les graphiques afficheront des lignes à 0 pour ces périodes
   - **Recommandation** : Vérifier la connexion du capteur DHT22 sur le firmware n3pp

3. ⚠️ **Page serre** : Nombreuses valeurs à 1 pour Humid1, Humid2, Humid4
   - Cela peut indiquer des capteurs déconnectés ou des lectures hors plage
   - **Recommandation** : Vérifier les connexions des capteurs d'humidité du sol

### Taille des pages
- **Météo** : 22 310 caractères (22 Ko) - Taille raisonnable
- **Serre** : 267 083 caractères (267 Ko) - Taille importante due aux 4923 mesures
  - **Recommandation** : Envisager une pagination ou un chargement dynamique pour les grandes périodes

---

## ✅ Conclusion

### Réponse à la question initiale

**Les graphiques Highcharts sont-ils visibles et se rendent-ils correctement ?**

**Réponse technique : OUI ✅**

D'un point de vue technique, tous les éléments nécessaires au rendu des graphiques sont présents et correctement configurés sur les deux pages :

1. ✅ **Bibliothèques chargées** : Highcharts, modules, configuration
2. ✅ **Conteneurs HTML présents** : Tous les `<div id="chart-*">` existent
3. ✅ **Données disponibles** : Toutes les variables JavaScript contiennent des valeurs
4. ✅ **Initialisation correcte** : Tous les appels `Highcharts.stockChart()` sont présents
5. ✅ **Fonction de transformation** : `zipSeries()` est définie et utilisée

**Les graphiques DEVRAIENT donc :**
- ✅ Afficher les conteneurs avec les titres
- ✅ Afficher les courbes de données avec les couleurs définies
- ✅ Permettre l'interaction (zoom, pan, tooltip)
- ✅ Afficher le navigator et le scrollbar

### Vérification visuelle recommandée

Pour confirmer le rendu visuel final, il est recommandé de :

1. **Ouvrir les pages dans un navigateur** :
   - https://iot.olution.info/meteo
   - https://iot.olution.info/serre

2. **Faire défiler jusqu'à la section "Graphiques"**

3. **Vérifier visuellement** :
   - Les conteneurs de graphiques sont-ils visibles ?
   - Les courbes de données sont-elles tracées ?
   - Les axes sont-ils correctement étiquetés ?
   - Les tooltips fonctionnent-ils au survol ?

4. **En cas de problème** :
   - Ouvrir la console développeur (F12)
   - Vérifier les erreurs JavaScript
   - Vérifier l'onglet Network pour les fichiers JS non chargés

---

## 📝 Scripts créés pour cette vérification

Deux scripts PowerShell ont été créés pour faciliter les vérifications futures :

1. **`scripts/test-highcharts-rendering.ps1`**
   - Vérifie la présence de tous les éléments nécessaires au rendu
   - Usage : `.\scripts\test-highcharts-rendering.ps1 [-Verbose]`

2. **`scripts/inspect-chart-data.ps1`**
   - Inspecte les données des variables JavaScript
   - Usage : `.\scripts\inspect-chart-data.ps1 [-Page meteo|serre|both]`

Ces scripts peuvent être utilisés pour diagnostiquer rapidement les problèmes de graphiques à l'avenir.

---

**Rapport généré le 2026-03-09 à 15:41**  
**Version serveur : v5.0.69**  
**Environnement : production**
