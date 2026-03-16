# Inventaire des credentials, secrets et fichiers WiFi / mail

Document de référence : emplacements des fichiers contenant identifiants WiFi, API, SMTP et variables d'environnement. **Ne pas y mettre de valeurs réelles** — ce document liste seulement les fichiers et leur usage.

---

## 1. Fichiers **pertinents** (à conserver et utiliser)

### 1.1 Firmwares — templates (versionnés)

| Fichier | Rôle | Utilisé par |
|--------|------|-------------|
| `firmwires/credentials.h.example` | Template WiFi (3 réseaux), SMTP, API_KEY. Copier en `credentials.h` à la **racine de firmwires/** | n3pp, msp (build_flags `-I../`) |
| `firmwires/n3pp/credentials.h.example` | Même schéma + commentaire API_KEY attendue (`fdGTMoptd5CD2ert3`). Copier en `credentials.h` **à la racine firmwires/** pour n3pp/msp | n3pp (inclus via `-I../`) |
| `firmwires/ffp5cs/include/secrets.h.example` | Template WiFi (WIFI_LIST), email (AUTHOR_EMAIL / AUTHOR_PASSWORD). Copier en `include/secrets.h` | ffp5cs (app, wifi_manager, mailer) |
| `firmwires/uploadphotosserver/include/credentials.h.example` | Template WiFi (WIFI_LIST) pour caméras. Copier en `include/credentials.h` | uploadphotosserver (envs msp1, n3pp, ffp3) |

### 1.2 Firmwares — fichiers réels (non versionnés, .gitignore)

À créer à partir des `.example` et à **ne jamais commiter** :

| Fichier | Contient |
|--------|----------|
| `firmwires/credentials.h` | WiFi (WIFI_SSID1–3, WIFI_PASS1–3), SMTP, API_KEY — pour n3pp et msp |
| `firmwires/ffp5cs/include/secrets.h` | WIFI_LIST[], AUTHOR_EMAIL, AUTHOR_PASSWORD — pour ffp5cs |
| `firmwires/uploadphotosserver/include/credentials.h` | WIFI_LIST[] — pour le firmware caméra unifié |

### 1.3 Serveur — templates (versionnés)

| Fichier | Rôle |
|--------|------|
| `serveur/.env.example` | Template BDD, API_KEY, emails, GPIO, galeries, tokens — **fichier chargé** = `serveur/.env` (racine du dépôt serveur) |
| `serveur/ffp3/.env.example` | Variante FFP3 (même structure, sans GALLERY_* si déjà en racine) |
| `serveur/env.test.example` | Template environnement TEST (ENV=test, API_KEY, BDD) |
| `serveur/ffp3/env.test.example` | Idem, pour le sous-dossier ffp3 |

### 1.4 Serveur — fichier réel chargé par l’application

L’application Slim charge **un seul** `.env` :

| Fichier | Rôle |
|--------|------|
| `serveur/.env` | **Racine du dépôt serveur** : c’est ce fichier qui est chargé par `App\Config\Env::load()` (depuis `public/index.php`). À créer à partir de `serveur/.env.example`. |

Le fichier `serveur/ffp3/.env` existe aussi dans le dépôt (parfois versionné selon le README FFP3) : il peut servir de **référence ou déploiement** mais **n’est pas** celui lu par le front controller Slim (qui lit uniquement la racine `serveur/`).

---

## 2. Fichiers **inutiles** ou à ne plus utiliser

### 2.1 Doublons / anciens emplacements

| Fichier / emplacement | Raison |
|------------------------|--------|
| `firmwires/archive/uploadphotosserver_*/credentials.h` | Firmwares caméra legacy (référence). Utiliser le firmware **unifié** `uploadphotosserver/` avec `include/credentials.h` ou `firmwires/credentials.h`. |
| Autres `uploadphotosserver_*` (ffp3, etc.) | Même logique : un seul firmware unifié dans `uploadphotosserver/`. |

### 2.2 Secrets en clair dans le dépôt (à corriger)

| Fichier | Problème |
|--------|----------|
| `firmwires/ffp5cs/include/config.h` | `ApiConfig::API_KEY = "fdGTMoptd5CD2ert3"` est **versionné**. Règles projet : externaliser dans `secrets.h` (non versionné). |
| `serveur/ffp3/.env` | Contient des **valeurs réelles** (DB, API_KEY, emails, API_SIG_SECRET, etc.). Si ce fichier est versionné, ne pas y mettre de secrets réels en production ; préférer un `.env` à la racine `serveur/` non versionné. |

---

## 3. Récapitulatif par composant

| Composant | Fichier credentials / secrets | Template |
|-----------|-------------------------------|----------|
| n3pp | `firmwires/credentials.h` | `firmwires/credentials.h.example` ou `n3pp/credentials.h.example` |
| msp | `firmwires/credentials.h` | `firmwires/credentials.h.example` |
| ffp5cs | `firmwires/ffp5cs/include/secrets.h` | `firmwires/ffp5cs/include/secrets.h.example` |
| uploadphotosserver (msp1, n3pp, ffp3) | `firmwires/uploadphotosserver/include/credentials.h` | `uploadphotosserver/include/credentials.h.example` |
| Serveur Slim (iot.olution.info) | `serveur/.env` | `serveur/.env.example` |

---

## 4. Cohérence à maintenir

- **API_KEY** : même valeur dans `firmwires/credentials.h` (n3pp, msp) et dans `serveur/.env` (documentation projet : `fdGTMoptd5CD2ert3`).
- **FFP5CS ↔ FFP3** : secret HMAC dans `secrets.h` (firmware) et dans `serveur/.env` (`API_SIG_SECRET`) — doivent être identiques.
- **WiFi / SMTP** : uniquement dans les fichiers non versionnés (`credentials.h`, `secrets.h`, `.env`).

---

*Dernière mise à jour : inventaire initial.*
