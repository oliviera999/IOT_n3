# Comparaison des champs modifiables – Pages de contrôle n3pp (serre / élevage)

Comparaison entre la page de contrôle du **site initial** (`serveur/site initial/n3pp/n3ppcontrol/`) et celle du **site actuel** (Slim 4, `N3ppOutputController` + template `n3pp_control.twig`).

---

## 1. Site initial (securecontrol/n3pp-outputs.php + n3pp-outputs-action.php)

### 1.1 Sorties (actionneurs)

| Élément | Détail |
|--------|--------|
| **Champs modifiables** | Toggle on/off par **id** (pas par GPIO). |
| **Périmètre affiché** | **3 premières sorties uniquement** (`getPartOutputs()` : `ORDER BY id LIMIT 3`). |
| **Action** | `GET ?action=output_update&id=...&state=0|1` |
| **Suppression** | Possible : `GET ?action=output_delete&id=...` |

### 1.2 Formulaire « Changer les paramètres » (GPIO 100–107)

Envoi groupé via `POST action=output_create` vers `n3pp-outputs-action.php`. Tous les champs sont stockés dans `n3ppOutputs.state` pour le GPIO correspondant.

| GPIO | Libellé interface | Type de champ | Remarque |
|------|-------------------|---------------|----------|
| 100 | Mail | **Texte** (`<input type="text">`) | Valeur libre. |
| 101 | Notification par mail | **Select** (oui / non → `checked` / `false`) | Stocké en state. |
| 102 | Limite de sécheresse (SeuilSec) | **Nombre** (`<input type="number" min="0">`) | |
| 103 | Limite du pont diviseur (SeuilPontDiv) | **Nombre** (`<input type="number" min="0">`) | |
| 104 | Heure arrosage | **Nombre** (`<input type="number" min="0">`) | |
| 105 | Temps arrosage (en ms) | **Nombre** (`<input type="number" min="0">`) | |
| 106 | Éco d’énergie (WakeUp) | **Nombre** (`<input type="number" min="0">`) | |
| 107 | Fréquence d’éveil (FreqWakeUp) | **Nombre** (`<input type="number" min="0">`) | |

- **Pas de GPIO 110** (Reset ESP) exposé dans le formulaire du site initial.

---

## 2. Site actuel (n3pp_control.twig + N3ppOutputController)

### 2.1 Sorties (GPIO &lt; 100)

| Élément | Détail |
|--------|--------|
| **Champs modifiables** | Toggle on/off par **GPIO** (et board). |
| **Périmètre** | **Toutes** les sorties du board avec `gpio < 100`. |
| **Action** | `POST n3pp-outputs-action.php` avec `action=set`, `gpio`, `state` (0|1), `board`. |
| **Suppression** | **Aucune** : pas d’action delete côté interface ni contrôleur. |

### 2.2 Arrosage & paramètres (GPIO ≥ 100)

Tous sont affichés comme **interrupteurs** (toggle 0/1) uniquement. Pas de champs texte ni nombre dédiés.

| GPIO | Libellé interface | Type de champ | Remarque |
|------|-------------------|---------------|----------|
| 100 | Mail | **Toggle** (0/1) | Plus de champ texte. |
| 101 | Notification mail | **Toggle** (0/1) | |
| 102 | Seuil sécheresse | **Toggle** (0/1) | Plus de champ nombre. |
| 103 | Seuil pont diviseur | **Toggle** (0/1) | |
| 104 | Heure arrosage | **Toggle** (0/1) | |
| 105 | Temps arrosage (ms) | **Toggle** (0/1) | |
| 106 | Éco énergie (WakeUp) | **Toggle** (0/1) | |
| 107 | Fréquence réveil | **Toggle** (0/1) | |
| **110** | **Reset ESP** | **Toggle** (0/1) | **Présent uniquement sur le site actuel** (avec style « warning »). |

Contrainte côté serveur : `N3ppOutputController::setOutput` ne garde que `state` égal à `'0'` ou `'1'` (et `'1.00'` normalisé en `'1'`). Aucune valeur numérique ou texte arbitraire n’est acceptée pour ces GPIO.

---

## 3. Synthèse des écarts

| Aspect | Site initial | Site actuel |
|--------|-------------|-------------|
| **Nombre de sorties actionneurs modifiables** | 3 (par id) | Toutes (GPIO &lt; 100, par gpio) |
| **Identification** | Par **id** | Par **gpio** + **board** |
| **GPIO 100 (Mail)** | Champ **texte** libre | Toggle **0/1** uniquement |
| **GPIO 101 (Notification mail)** | Select oui/non | Toggle 0/1 |
| **GPIO 102–107 (paramètres numériques)** | Champs **nombre** dédiés (SeuilSec, SeuilPontDiv, HeureArrosage, tempsArrosage, WakeUp, FreqWakeUp) | Toggle **0/1** uniquement |
| **GPIO 110 (Reset ESP)** | Non exposé | Exposé (toggle + avertissement) |
| **Suppression d’une sortie** | Oui (`output_delete` par id) | Non |

En résumé : le site actuel offre plus de sorties actionneurs (toutes, pas seulement 3) et ajoute le contrôle du Reset ESP (110), mais il a **perdu** la possibilité de saisir des valeurs numériques ou du texte pour les paramètres (mail, seuils, heures, temps, WakeUp, FreqWakeUp) ; tout est réduit à un état binaire 0/1. La suppression d’output n’existe plus côté actuel.

---

## 4. Fichiers de référence

- **Site initial**  
  - Page : `serveur/site initial/n3pp/n3ppcontrol/securecontrol/n3pp-outputs.php`  
  - API : `serveur/site initial/n3pp/n3ppcontrol/n3pp-outputs-action.php`  
  - BDD : `serveur/site initial/n3pp/n3ppcontrol/n3pp-database.php`  

- **Site actuel**  
  - Template : `serveur/templates/n3pp_control.twig`  
  - Contrôleur : `serveur/src/Controller/N3pp/N3ppOutputController.php`  
  - Repository : `serveur/src/Repository/N3ppOutputRepository.php`  
