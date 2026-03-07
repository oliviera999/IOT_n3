# Vérification envoi données BDD n3pp (serre)

## Contrat firmware / serveur

| Élément | Firmware (n3pp4_2) | Serveur |
|--------|---------------------|---------|
| **URL POST (test)** | `http://iot.olution.info/n3pp-test/n3ppdatas/post-n3pp-data.php` | `POST /n3pp-test/n3ppdatas/post-n3pp-data.php` → `N3ppPostDataController` |
| **Clé API** | `API_KEY` dans `credentials.h` | `API_KEY` dans `.env` (racine serveur) |
| **Valeur attendue** | `fdGTMoptd5CD2ert3` (règle projet) | Idem dans `.env` |
| **Content-Type** | `application/x-www-form-urlencoded` | Parsé par Slim |
| **Table (test)** | - | `n3ppDataTest` (env `n3pp_test` via middleware) |

## Résultat des vérifications

1. **Firmware**  
   - Utilise `#include "credentials.h"` et `API_KEY` (pas de clé en dur dans `main.cpp`).  
   - `credentials.h` n’est pas versionné ; le projet partagé a un `firmwires/credentials.h.example` avec `#define API_KEY "VOTRE_CLE_API"`.  
   - **À faire** : dans `firmwires/n3pp4_2`, s’assurer que `credentials.h` (copie locale ou lien vers le partagé) contient `#define API_KEY "fdGTMoptd5CD2ert3"` pour correspondre au serveur.

2. **Serveur**  
   - `N3ppPostDataController` exige `$_ENV['API_KEY']` ; si absent → 500, si différent du POST → 401.  
   - Chargement du `.env` : `Env::load()` lit le fichier à la **racine du dépôt serveur** (`serveur/.env`), pas `serveur/ffp3/.env`.  
   - Un `.env` présent dans le repo a été vu dans `serveur/ffp3/.env` avec `API_KEY=fdGTMoptd5CD2ert3`. En production, le front unique utilise en général un `.env` à la racine de `serveur/` (souvent non versionné).  
   - **À faire** : sur iot.olution.info, vérifier que le `.env` effectivement chargé par l’app (racine `serveur/`) contient `API_KEY=fdGTMoptd5CD2ert3`.

3. **Log moniteur (terminals/69858.txt)**  
   - On voit de nombreuses fois « recup info bdd » et les variables (GET outputs OK).  
   - **Aucune** occurrence de `DATATOBDD!!!` ni du code HTTP d’envoi POST.  
   - Donc soit `datatobdd()` n’a jamais été appelée pendant la capture, soit le firmware n’avait pas encore les logs « Envoi BDD ».  
   - Causes possibles : `WakeUp != 0` donc pas d’appel dans `sommeil()`, et le timer 2 min n’a pas encore déclenché (redémarrages / crash visibles dans le log).

## Actions recommandées

1. **Clé API**  
   - Vérifier que `credentials.h` du n3pp (local ou partagé) définit bien `API_KEY` à `fdGTMoptd5CD2ert3`.  
   - Vérifier que le `.env` chargé en production sur iot.olution.info contient `API_KEY=fdGTMoptd5CD2ert3`.

2. **Diagnostic rapide**  
   - Un envoi POST de diagnostic au **premier tour de loop()** (après `lectureCapteurs()` et `batterie()`) a été ajouté : au prochain flash tu verras dès le premier cycle « DATATOBDD!!! », le code HTTP et « Envoi BDD: OK » ou « Envoi BDD: erreur HTTP xxx ».  
   - Si **401** → clé API différente entre firmware et serveur.  
   - Si **500** → consulter les logs PHP (API_KEY manquante ou erreur SQL / table `n3ppDataTest`).

3. **Table**  
   - Pour l’env test, la table utilisée est `n3ppDataTest`. S’assurer qu’elle existe sur la BDD du serveur déployé.
