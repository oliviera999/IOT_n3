# Analyse marées côté firmware (FFP5CS) — juin 2026

Analyse de la chaîne de traitement « marée » dans le firmware, en regard de la refonte
serveur récente (n3_serveur v5.1.1 → v5.1.14, commits `63093f8` et `57b4d5f`) considérée
comme référence correcte.

Périmètre : seul le firmware **ffp5cs** manipule la marée. `n3pp`, `msp`,
`poissonglouton` et `uploadphotosserver` n'ont aucune logique marée.

---

## 1. Rappel de la sémantique (désormais clarifiée côté serveur)

- `EauAquarium` / `wlAqua` = **distance ultrason capteur → surface, en mm**.
- Distance qui **diminue** = eau qui **monte** ; distance qui **augmente** = eau qui **descend**.
- Conséquence : un **pic de distance = basse mer**, un **creux de distance = pleine mer**.
  C'est exactement le libellé adopté par le serveur dans
  `public/assets/js/aquaponie-tide-markers.js` (« Basse mer (distance max) » /
  « Pleine mer (distance min) »).

Le firmware travaille **entièrement en distance brute** et n'inverse jamais le signe :
c'est cohérent avec le nouveau contrat serveur.

## 2. Chaîne de traitement firmware

### 2.1 Acquisition (`src/system_sensors.cpp`)

- `wlAqua` lu via `_usAqua.readReactiveFiltered()` (mm), cadence de la tâche capteurs :
  **10 s** (`SENSOR_TASK_INTERVAL_MS`, `include/config.h:211`).
- Validation (`SensorValidation::isWaterLevelKnown`), 2e passe filtrée puis fallback en cas
  d'échec (`system_sensors.cpp:100-139`).
- **Seules les mesures valides** alimentent l'historique marée
  (`pushAquaHist`, `system_sensors.cpp:149-155`) : ring buffer de
  **16 échantillons horodatés** (`AQUA_HIST_SIZE`, `include/system_sensors.h:59-62`),
  soit ~160 s d'historique à cadence nominale — largement suffisant pour la fenêtre de 15 s.

### 2.2 `diffMaree` — la dérivée court-terme (`system_sensors.cpp:328-365`)

```
diffMaree = (échantillon le plus proche de t-15s) − (valeur actuelle)   [mm]
```

- Fenêtre `_tideWindowMs` = **15 000 ms** (fixe, voir anomalie E).
- Recherche de l'échantillon le plus proche de `now − 15 s` dans le ring buffer
  (early-break si < 1 s d'écart), arithmétique non signée correcte vis-à-vis du
  rollover `millis()`.
- Signe : `passé − actuel` en distance → **positif = distance qui baisse = eau qui monte**.
  C'est la définition que le serveur a entérinée en v5.1.14
  (« diffMaree : variation de distance aquarium (mm, brut firmware) sur fenêtre temporelle »).

### 2.3 Détection d'inflexion embarquée (`src/automatism/automatism_sync.cpp:571-619`)

Machine à états minimaliste mais correcte (même famille d'algo que
`TideCycleDetector::detectExtremaSeries()` côté serveur) :

- `_trendDir ∈ {−1, 0, +1}` sur la **distance** ; hystérésis
  `INFLECTION_NOISE_MM = 20 mm` (`automatism_sync.h:155`) pour absorber le bruit ultrason.
- En tendance montante (distance ↑), l'extrême est suivi ; un repli ≥ 20 mm confirme un
  **Peak** (= basse mer). Symétriquement, un **Trough** (= pleine mer).
- Anti-rebond : `MIN_INFLECTION_INTERVAL_MS = 10 s` entre deux POSTs d'événement.
- À chaque événement confirmé : **POST immédiat hors cadence** (catégorie `EventAck`,
  `automatism_sync.cpp:127-134`) → le serveur reçoit un point de mesure **exactement à
  l'extrême**, ce qui améliore la résolution des extrema recalculés côté serveur.

Aligné sur le serveur : le seuil serveur `VARIATION_THRESHOLD_CM = 2.0 cm` = 20 mm =
`INFLECTION_NOISE_MM`. Les deux détecteurs sont paramétriquement cohérents.

### 2.4 Contrat POST firmware → serveur

À chaque `sendFullUpdate` (`automatism_sync.cpp:303-350`) :

| Champ | Contenu | Consommation serveur |
|---|---|---|
| `EauAquarium` | distance mm (brut) | **Source de vérité** : tout est recalculé dessus (cycles, extrema, tendance, marnage) |
| `diffMaree` | dérivée 15 s, mm | Stats `TideAnalysisService` |
| `tideEvent` | `none\|peak\|trough` | Persisté (validé en ingestion, `PostDataController.php:301-305`) |
| `tideTrend` | `_trendDir` (−1/0/1, sens distance) | Persisté, non affiché (le serveur calcule sa propre tendance) |
| `tideNoiseMm`, `tideWindowMs`, `tideExtremeMm` | métadonnées algo | Persistés (traçabilité/diagnostic) |

Les clés `tide*` sont incluses dans la reconstruction HMAC des deux côtés
(`ffp3_post_body.cpp:193` ↔ `Ffp3HmacPostBody.php:31`) : contrat champ à champ propre.

### 2.5 Usages locaux de la marée

1. **Décision de sommeil** (`automatism_sleep.cpp:136-188`) : sleep précoce si
   `diffMaree15s > tideTriggerCm×10` (seuil `TIDE_TRIGGER_THRESHOLD_CM = 10 cm`,
   `config.h:919`). Une montée d'eau > 10 cm/15 s signe le remplissage par la pompe
   marée → plus rien à surveiller, l'ESP économise sa batterie. Sémantique correcte.
2. **OLED** (`automatism.cpp:1168-1176`, `display_view.cpp:1254-1259`) : flèche `^`
   (montée) si `diffMaree > 1`, `v` si `< −1`. Correct dans le chemin nominal
   (voir anomalie A pour le fallback).
3. **Footer mail diagnostic** (`mailer.cpp:544-553`).

## 3. Répartition des responsabilités (post-refonte serveur)

Depuis v5.1.14, le serveur est la **source de vérité analytique** : il recalcule cycles,
amplitudes, marnage, fréquence, tendance et extrema depuis la série brute `EauAquarium`
(convertie en cm), avec timestamps Europe/Paris unifiés. Le firmware n'a **pas** besoin
d'être « intelligent » sur la marée ; ses trois vraies responsabilités sont :

1. fournir une série `EauAquarium` brute, valide et régulière (✅ fait, sans sur-lissage —
   exigence explicite du serveur v5.1.1) ;
2. densifier la série aux moments critiques via les POSTs d'inflexion (✅ fait) ;
3. prendre ses décisions locales (sommeil) sur une dérivée robuste (✅ fait).

L'architecture est donc **saine et bien découpée**. Les anomalies ci-dessous sont des
défauts d'exécution, pas de conception.

## 4. Anomalies relevées

### A. Inversion de signe dans le fallback d'affichage — `automatism.cpp:1156-1166` (le seul vrai bug)

```cpp
int diffMaree = _lastDiffMaree;            // init {-1} (automatism.h:329)
if (diffMaree == -1 && _lastReadings.wlAqua > 0) {
    diffMaree = (int)readings.wlAqua - (int)_lastReadings.wlAqua;  // actuel − passé !
```

Deux problèmes combinés :
- **Sentinelle ambiguë** : `−1` est une valeur parfaitement légitime de `diffMaree`
  (eau qui descend de 1 mm — du bruit courant). Chaque fois que le vrai calcul vaut −1,
  le fallback se déclenche à tort.
- **Signe inversé** : le fallback calcule `actuel − passé` alors que la convention
  partout ailleurs est `passé − actuel`. Dans ce chemin, la flèche OLED peut indiquer
  « montée » pendant que l'eau descend.

Correctif suggéré : sentinelle dédiée (`INT_MIN` ou un `bool _diffMareeValid`) et
fallback en `passé − actuel`.

### B. Événement d'inflexion perdu (pas différé) — `automatism_sync.cpp:597-601, 610-614`

Si une inflexion est confirmée moins de 10 s après la précédente, le trend bascule et
l'extrême est consommé, mais l'événement retourne `None` et **n'est jamais posté**.
Impact faible (le serveur recalcule), mais un vrai extrême peut manquer en BDD comme
point événementiel.

### C. Machine à états alimentée par intermittence — `automatism_sync.cpp:122-135`

`checkInflectionPoint()` n'est appelé que dans la branche `else` de `intervalReached`,
et pas du tout si heap faible, pool netRPC plein ou WiFi down. La machine à états rate
donc des échantillons autour de chaque POST périodique. L'hystérésis la rend tolérante,
mais déplacer l'appel **en amont** des gardes d'envoi (toujours nourrir l'état, ne
conditionner que le POST) serait plus rigoureux.

### D. Nomenclature 10 s / 15 s incohérente

`diffMaree10s`, logs « ~10s » (`automatism_sleep.cpp:179`), « Calcul15s »
(`system_sensors.cpp:334`)… la fenêtre réelle est **15 s**. Déjà signalé dans
VERSION.md, jamais purgé. À renommer `diffMareeWindow`/`diffMaree15s`.

### E. `setTideWindowMs()` jamais appelé — `system_sensors.h:30`

La fenêtre est non configurable en pratique (toujours 15 000) ; le champ `tideWindowMs`
posté est donc constant. Soit brancher le setter sur la config distante, soit supprimer
le setter et figer la constante.

### F. Code mort `_aquaMax` — `system_sensors.cpp:308-313`

Le suivi du max de distance (`getAquaMax`/`resetAquaMax`) n'a aucun consommateur.
À supprimer, ou à recycler comme borne de plausibilité.

### G. Sentinelles écrasées par des valeurs légitimes dans les stats serveur

`diffMaree = 0` quand le niveau est inconnu (`automatism_sync.cpp:305-307`) : `0` est
aussi la valeur « stable ». Le serveur fait des stats sur `diffMaree` ; les inconnues
gonflent artificiellement la classe « stable ». Idéalement : omettre la clé du POST
(le serveur gère déjà les colonnes optionnelles).

### H. Cosmétique : unité mm affichée « cm » — `mailer.cpp:548`

`"Aqua lvl: %d cm"` alors que `rs.wlAqua` est en mm.

## 5. Synthèse

| Aspect | Verdict |
|---|---|
| Sémantique distance (signe, peak=basse mer) | ✅ Alignée avec le serveur corrigé |
| Algo diffMaree (fenêtre 15 s, ring buffer) | ✅ Correct et robuste (rollover ok) |
| Détection d'inflexion + POST événementiel | ✅ Bonne idée, seuil aligné serveur (20 mm) |
| Contrat POST `tide*` + HMAC | ✅ Cohérent champ à champ |
| Décision sommeil sur marée montante | ✅ Correcte |
| Affichage OLED | ⚠️ Bug de signe dans le fallback (A) |
| Hygiène (naming 10s/15s, code mort, sentinelles) | ⚠️ À nettoyer (D, E, F, G, H) |

Aucune correction n'est nécessaire côté serveur. Côté firmware, seul **A** mérite un
correctif fonctionnel ; **B/C** sont des raffinements de la détection d'inflexion ;
**D–H** relèvent du nettoyage. Aucun de ces points ne remet en cause les données que le
serveur recalcule : la chaîne actuelle produit déjà des résultats corrects de bout en bout.
