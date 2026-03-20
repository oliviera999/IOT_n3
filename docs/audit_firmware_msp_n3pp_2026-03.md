# Audit firmware MSP + N3PP

**Date** : 20 mars 2026  
**Perimetre** : `firmwires/msp`, `firmwires/n3pp`, bibliotheques partagees (`shared/n3_data`, `shared/n3_wifi`, `shared/n3_common`), contrat serveur `serveur/` (POST data + outputs legacy)  
**Type** : Audit technique (securite, fiabilite, contrat firmware-serveur, stabilite runtime)

---

## 1. Resume executif

- Les deux firmwares compilent en `esp32dev` et `esp32dev_test` (MSP et N3PP).
- Les endpoints firmware restent en `http://` (POST, GET outputs, OTA metadata), ce qui expose les donnees en clair.
- Le parsing des sorties serveur (`outputs_state`) est fragile car il depend de l'ordre des cles JSON (`keys[i]`) au lieu de lire par GPIO explicite (`"100"`, `"101"`, etc.).
- Les timeouts HTTP ne sont pas definis dans `n3_data`, risque de blocage long en reseau degrade.
- Les conventions fallback DHT ne sont pas respectees de facon uniforme (MSP sans fallback explicite ; N3PP fallback a `0/0` au lieu de `20/50`).
- Les versions firmware dans le code ne sont pas alignees avec `VERSION.md` et `docs/inventaire_appareils.md`.

---

## 2. Matrice contrat firmware-serveur

| Aspect | MSP | N3PP |
|--------|-----|------|
| POST endpoint firmware | `/msp1/msp1datas/post-msp1-data.php` | `/n3pp/n3ppdatas/post-n3pp-data.php` |
| GET outputs firmware | `/msp1/msp1control/msp1-outputs-action.php?action=outputs_state&board=2` | `/n3pp/n3ppcontrol/n3pp-outputs-action.php?action=outputs_state&board=3` |
| Transport | HTTP | HTTP |
| Auth POST serveur | `api_key` obligatoire (401 sinon) | `api_key` obligatoire (401 sinon) |
| Format POST firmware | `application/x-www-form-urlencoded` | `application/x-www-form-urlencoded` |
| Mapping outputs serveur | JSON `{gpio: state}` | JSON `{gpio: state}` |
| Parsing outputs firmware | Index `keys[2..10]` | Index `keys[0..10]` |
| Risque principal | Dependance a l'ordre JSON | Dependance a l'ordre JSON |

### Champs POST verifies

- MSP : les champs envoyes dans `msp_network.cpp` sont globalement alignes avec `MspPostDataController`.
- N3PP : les champs envoyes dans `n3pp_network.cpp` sont globalement alignes avec `N3ppPostDataController`.

### Ecart de contrat critique

Le serveur renvoie un objet associe par GPIO (`AbstractOutputRepository::getStateForFirmware`), alors que les firmwares lisent par position dans le tableau des cles JSON. L'ordre n'est pas contractuel : un changement d'ordre peut mapper de mauvaises valeurs (mail, seuils, wakeup, etc.) sans erreur explicite.

---

## 3. Constatations priorisees

### Critique

1. **HTTP non chiffre (MSP/N3PP/OTA)**  
   Endpoints en clair dans `main.cpp` (POST + outputs + metadata OTA).  
   Impact : interception/modification de trafic possible en reseau local.

2. **Parsing outputs_state fragile**  
   `msp_network.cpp` et `n3pp_network.cpp` utilisent `myObject.keys()[i]` puis `atoi(...)`.  
   Impact : incoherences de pilotage et de parametres si ordre JSON change.

3. **Timeouts HTTP absents dans `shared/n3_data`**  
   `n3DataPost()` et `n3DataGet()` ne definissent pas `http.setTimeout()`.  
   Impact : blocages non maitrises et cycles allonges en cas de reseau lent.

### Majeur

4. **Fallback DHT non harmonise**  
   - MSP : detection `isnan()` sans affectation fallback explicite.  
   - N3PP : fallback a `0.0f/0.0f` au lieu de `20.0f/50.0f`.

5. **Bug logique mail batterie N3PP**  
   Comparaison `enableEmailChecked == "true"` alors que la valeur normalisee projet est `"checked"`.  
   Impact : alertes batterie potentiellement non envoyees.

6. **Delais bloquants importants**  
   - MSP : 32 appels `delay(...)` (dont sequences longues dans tracker/affichage).  
   - N3PP : 18 appels `delay(...)` (dont `delay(4000)` en affichage).  
   Impact : latence de boucle, sensibilite watchdog/perte de reactivite.

7. **Usage intensif de `String` dans chemins chauds**  
   - MSP : ~43 occurrences  
   - N3PP : ~50 occurrences  
   Impact : fragmentation heap potentielle a long terme.

### Mineur

8. **Versions desynchronisees (code vs doc)**  
   - MSP : code `2.17`, docs `2.15`  
   - N3PP : code `4.17`, docs `4.15`

9. **Template credentials N3PP a risque de fuite**  
   `n3pp/credentials.h.example` contient une mention de valeur API reelle dans un commentaire.  
   Impact : mauvaise pratique securite et confusion operateur.

10. **Template credentials MSP incomplet localement**  
    `msp/credentials.h.example` ne declare pas les macros SMTP, contrairement au template partage.

---

## 4. Verification terrain (executee)

### Builds lances

- `firmwires/msp`  
  - `pio run -e esp32dev` : **OK**  
  - `pio run -e esp32dev_test` : **OK**

- `firmwires/n3pp`  
  - `pio run -e esp32dev` : **OK**  
  - `pio run -e esp32dev_test` : **OK**

### Indicateurs memoire releves

- MSP (`esp32dev`) : RAM ~17.3%, Flash ~86.6%
- N3PP (`esp32dev`) : RAM ~16.5%, Flash ~85.0%

---

## 5. Backlog de corrections (priorise)

## Lot A - Securite reseau / contrat (priorite immediate)

1. Lire les sorties par GPIO explicite (`"100"`, `"101"`, ...) au lieu de `keys[i]` dans `msp_network.cpp` et `n3pp_network.cpp`.
2. Ajouter des timeouts explicites dans `shared/n3_data/src/n3_data.cpp` (POST + GET).
3. Migrer progressivement les URLs critiques vers HTTPS (au minimum OTA puis POST donnees).
4. Documenter le mode dev si la validation certificat est temporairement desactivee.

## Lot B - Robustesse capteurs / logique metier

1. Harmoniser fallback DHT a `20.0f / 50.0f` pour MSP et N3PP.
2. Corriger `enableEmailChecked` dans `n3pp_automation.cpp` (`"checked"` au lieu de `"true"`).
3. Ajouter des bornes de validite explicites sur temperature/humidite avant envoi POST.

## Lot C - Stabilite runtime

1. Reduire les `delay` > 500ms dans loop et sous-modules (affichage, reseau, automatisme).
2. Prioriser une logique non bloquante pour affichage OLED et cycles reseau.
3. Diminuer l'usage de `String` dans les chemins frequents (buffers fixes / `snprintf`).

## Lot D - Documentation / versioning / secrets

1. Aligner versions firmware (`FIRMWARE_VERSION`) avec `VERSION.md` et `docs/inventaire_appareils.md`.
2. Nettoyer les templates `credentials.h.example` (pas de valeur projet reelle, macros SMTP coherentes).
3. Ajouter une section "Contrat outputs_state" dans les docs firmware MSP/N3PP (GPIO -> parametre).

---

## 6. Protocole de validation post-correction

1. **Build**  
   - `cd firmwires/msp && pio run -e esp32dev && pio run -e esp32dev_test`  
   - `cd firmwires/n3pp && pio run -e esp32dev && pio run -e esp32dev_test`

2. **Monitoring 5 min minimum**  
   - Depuis `firmwires/` :  
     - `.\monitor_Nmin.ps1 -Project msp -DurationSeconds 300 -Port COMx`  
     - `.\monitor_Nmin.ps1 -Project n3pp -DurationSeconds 300 -Port COMx`

3. **Workflow complet (si changement reseau/sommeil/watchdog)**  
   - `.\erase_flash_monitor.ps1 -Project msp -DurationMinutes 5 -Port COMx`  
   - `.\erase_flash_monitor.ps1 -Project n3pp -DurationMinutes 5 -Port COMx`

4. **Analyse des logs**  
   - `.\scripts\analyze_log_generic.ps1` (ou `-LogFile ...`)  
   Verifier absence de crash, WDT, reboot anormal, erreurs HTTP recurrentes.

5. **Checks fonctionnels a valider**
   - POST renvoie 200 regulierement.
   - GET outputs met a jour les bons parametres (mail, seuils, wakeup) avec mapping GPIO stable.
   - Fallback DHT applique quand lecture invalide.
   - Entrée/sortie deep sleep sans blocage.

---

## 7. Fichiers audites (principaux)

- `firmwires/msp/src/main.cpp`
- `firmwires/msp/src/msp_network.cpp`
- `firmwires/msp/src/msp_sensors.cpp`
- `firmwires/msp/src/msp_automation.cpp`
- `firmwires/msp/include/msp_config.h`
- `firmwires/msp/credentials.h.example`
- `firmwires/msp/VERSION.md`
- `firmwires/n3pp/src/main.cpp`
- `firmwires/n3pp/src/n3pp_network.cpp`
- `firmwires/n3pp/src/n3pp_sensors.cpp`
- `firmwires/n3pp/src/n3pp_automation.cpp`
- `firmwires/n3pp/include/n3pp_config.h`
- `firmwires/n3pp/credentials.h.example`
- `firmwires/n3pp/VERSION.md`
- `firmwires/shared/n3_data/src/n3_data.cpp`
- `firmwires/shared/n3_wifi/src/n3_wifi.cpp`
- `firmwires/shared/n3_common/src/n3_ota.cpp`
- `serveur/src/Controller/AbstractPostDataController.php`
- `serveur/src/Controller/AbstractOutputController.php`
- `serveur/src/Controller/Msp/MspPostDataController.php`
- `serveur/src/Controller/N3pp/N3ppPostDataController.php`
- `serveur/src/Repository/AbstractOutputRepository.php`
- `serveur/src/Repository/MspOutputRepository.php`
- `serveur/src/Repository/N3ppOutputRepository.php`
- `serveur/docs/API_REALTIME_OUTPUTS_CONTRAT.md`
- `docs/inventaire_appareils.md`
