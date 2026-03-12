# Scénarios asymétriques — diagnostic firmware ↔ serveur

**Date** : 2026-03-12  
**Périmètre** : FFP5CS (ffp5cs), échanges POST/GET avec iot.olution.info

---

## Objectif

Ce document décrit les scénarios où **un flux fonctionne et l’autre échoue** (GET OK / POST KO et inversement), et comment les diagnostiquer.

---

## Scénario 1 : GET fonctionne, POST échoue

### Symptômes
- L’ESP32 reçoit bien les états GPIO (commande web visible)
- Les données capteurs ne sont pas enregistrées en BDD (graphiques aquaponie incomplets)
- Le nourrissage automatique n’apparaît pas dans les données

### Causes possibles
| Cause | Diagnostic |
|-------|------------|
| **WiFi instable** | Timeout POST (5 s) plus court que GET (8 s) ou succès aléatoire |
| **Payload POST trop gros** | Heap faible (< 20 KB) → POST différé ; vérifier logs `[Sync] ⏸️ POST différé` |
| **Pool netRPC plein** | Trop de requêtes concurrentes ; logs `[Sync] POST différé (pool netRPC plein)` |
| **Erreur 401/500 POST** | Clé API incorrecte, HMAC invalide, erreur PHP serveur |
| **Timeout HTTP** | Réseau lent ; POST mis en file NVS pour replay ultérieur |

### Actions
- Vérifier `cronlog.txt` et `error_log` sur le serveur pour les erreurs POST
- Consulter les logs ESP32 : `[Sync] POST échoué` avec raison (timeout, HTTP, pool)
- Tester manuellement : `curl -X POST "http://iot.olution.info/ffp3/post-data" -d "api_key=XXX&sensor=TEST&..."`

---

## Scénario 2 : POST fonctionne, GET échoue

### Symptômes
- Les données capteurs arrivent (graphiques à jour)
- Les commandes web (nourrissage, chauffage, etc.) ne sont pas appliquées par l’ESP32
- L’interface embarquée affiche des valeurs par défaut

### Causes possibles
| Cause | Diagnostic |
|-------|------------|
| **Timeout GET** | Réseau lent ; ESP utilise cache NVS ou valeurs par défaut |
| **JSON vide ou parse error** | Table outputs vide, réponse corrompue ; `[DBG] copyLastFetchedTo docSize=0` |
| **Environnement incohérent** | ESP en POST test mais GET prod (tables différentes) |
| **Table outputs vide** | Aucune ligne pour les GPIO attendus ; le serveur retourne des valeurs par défaut |

### Actions
- Vérifier que l’ESP32 utilise le même endpoint GET que la page contrôle (prod/test/test3)
- Tester : `curl "http://iot.olution.info/ffp3/api/outputs/state"` (ou `-test` selon env)
- Vérifier la table BDD : `SELECT gpio, state FROM ffp3Outputs2 WHERE gpio IN (108, 109);`

---

## Scénario 3 : Les deux échouent

### Comportement attendu (offline-first)
- L’ESP32 continue avec la config NVS et les horaires locaux
- Pas de blocage ; nourrissage automatique fonctionne en local
- `configSynced` reste à 0 ; au prochain POST réussi, le serveur n’applique pas les GPIO 100–116 depuis le POST (évite écrasement par défauts)

---

## Tests manuels rapides

```bash
# Test POST (remplacer API_KEY)
curl -X POST "http://iot.olution.info/ffp3/post-data-test" \
  -d "api_key=VOTRE_CLE&sensor=TEST&version=12.42&TempAir=20&Humidite=50&TempEau=22&..."

# Test GET outputs
curl "http://iot.olution.info/ffp3/api/outputs-test/state"
```

---

## Références

- [audit_echanges_serveur_esp.md](audit_echanges_serveur_esp.md)
- [SYNCHRONISATION_BIDIRECTIONNELLE.md](serveur/ffp3/docs/SYNCHRONISATION_BIDIRECTIONNELLE.md)
- [ENDPOINTS_ESP32_SERVEUR.md](serveur/docs/ENDPOINTS_ESP32_SERVEUR.md)
