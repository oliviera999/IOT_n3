---
name: diagnostic-connectivite-iot
description: Diagnostiquer les problemes de connectivite entre les firmwares ESP32 et le serveur PHP (WiFi, HTTP, API, timeouts, erreurs reseau). Utiliser quand un appareil n'envoie plus de donnees, quand le serveur ne recoit rien, ou quand il y a des erreurs reseau dans les logs firmware ou serveur.
---

# Diagnostic connectivite IoT

## Quand utiliser

- Un appareil ESP32 n'envoie plus de donnees au serveur
- Le serveur retourne des erreurs (400, 401, 500) aux requetes firmware
- Les logs firmware montrent des timeouts ou erreurs reseau
- Apres un changement de reseau, de serveur ou de credentials

## Couches a diagnostiquer (du bas vers le haut)

### 1. Couche physique / WiFi

**Cote firmware (Serial Monitor)** :
```bash
pio device monitor -b 115200
```

Verifier :
- [ ] Le firmware demarre sans crash (pas de Guru Meditation)
- [ ] Connexion WiFi reussie (`[WIFI] Connected`)
- [ ] Adresse IP obtenue (pas `0.0.0.0`)
- [ ] Signal suffisant (RSSI > -80 dBm si affiche)

**Causes courantes** :
- SSID/password incorrects dans `credentials.h`
- Portail captif du reseau (lycee) qui bloque
- ESP32 trop loin du point d'acces

### 2. Couche reseau / DNS

**Tests depuis l'ESP32** (si des logs DNS sont presents) :
- L'ESP32 arrive-t-il a resoudre `iot.olution.info` ?
- Probleme DNS : utiliser une IP directe temporairement pour tester

**Tests depuis un PC sur le meme reseau** :
```bash
ping iot.olution.info
curl -v https://iot.olution.info
```

### 3. Couche HTTP / TLS

Verifier dans les logs firmware :
- [ ] La requete HTTP est envoyee (log du type `[HTTP] POST /post-data`)
- [ ] Le code de reponse est logue (200, 400, 401, 500, -1)
- [ ] Pas de timeout HTTP (timeout par defaut ≤ 5s)

**Code -1 ou timeout** :
- Le serveur est injoignable (down, pare-feu, mauvais port)
- Probleme TLS/certificat (si HTTPS)
- Le firmware n'a pas de timeout configure → risque de blocage

**Code 400** :
- Champs JSON manquants ou mauvais noms
- Content-Type manquant

**Code 401** :
- Cle API incorrecte ou absente
- Signature HMAC invalide (horloge desynchronisee ?)
- Secret HMAC different entre firmware et serveur `.env`

**Code 500** :
- Erreur cote serveur (BDD, config, exception PHP)
- Verifier les logs Monolog du serveur

### 4. Couche applicative / contrat

Verifier la coherence du contrat firmware-serveur :
- [ ] L'URL de l'endpoint est correcte (attention aux slashes finaux)
- [ ] Les noms de champs JSON correspondent exactement
- [ ] La methode HTTP est correcte (POST vs GET)
- [ ] La cle API ou le secret HMAC sont identiques des deux cotes

Utiliser le skill `contrat-firmware-serveur` pour une verification complete.

## Outils de diagnostic

### Test manuel depuis un terminal

```bash
# Simuler une requete du firmware MSP
curl -X POST https://iot.olution.info/msp/post-data \
  -H "Content-Type: application/json" \
  -d '{"api_key":"xxx","temperature":22.5,"humidity":65}'

# Simuler une requete FFP3 avec signature
curl -X POST https://iot.olution.info/ffp3/post-data \
  -H "Content-Type: application/json" \
  -H "X-Signature: <hmac>" \
  -H "X-Timestamp: <ts>" \
  -d '{"field1":"value"}'
```

### Logs serveur

Verifier les fichiers de log Monolog du serveur :
- Erreurs PHP dans `error_log`
- Logs applicatifs (`cronlog.txt` ou `LOG_FILE_PATH` du .env)

### Scripts de diagnostic existants

Verifier s'il existe des scripts dans `serveur/tools/` :
- `diagnostic_serveur_distant.ps1` ou similaire
- Scripts de verification d'environnement

## Arbre de decision

```
Pas de donnees recues ?
├── WiFi connecte ?
│   ├── NON → Verifier credentials.h, signal, portail captif
│   └── OUI → Requete HTTP envoyee ?
│       ├── NON → Bug dans le code firmware (boucle, crash)
│       └── OUI → Code reponse ?
│           ├── -1/timeout → Serveur injoignable, DNS, TLS
│           ├── 400 → Champs JSON incorrects, Content-Type
│           ├── 401 → Cle API ou HMAC invalide
│           ├── 500 → Bug serveur, verifier logs Monolog
│           └── 200 → Donnees recues mais pas affichees ?
│               └── Verifier table BDD, timezone, affichage
```

## Rappel offline-first

Le diagnostic ne doit pas faire oublier que les firmwares doivent **continuer a fonctionner sans reseau**. Si un appareil est bloque a cause du reseau, c'est un bug firmware a corriger (timeout manquant, boucle de retry infinie, etc.).
