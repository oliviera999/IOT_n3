# Diagnostic serveur iot.olution.info – 2026-03-09

## Contexte

Vérification des pages après déploiement de l'harmonisation (v5.0.73) et correctif (v5.0.74).

---

## 1. Correctif appliqué

**Erreur fatale en production** : double import `TideStatsController` dans `public/index.php` (ligne 29-30) provoquant :

```
Fatal error: Cannot use App\Controller\TideStatsController as TideStatsController because the name is already in use
```

**Correction** : suppression de l'import obsolète `use App\Controller\TideStatsController` (l'import correct est `use App\Controller\Ffp3\TideStatsController`).

**Déploiement** : v5.0.74 – 2026-03-09.

---

## 2. Vérifications manuelles (après correctif)

| URL | Statut |
|-----|--------|
| `https://iot.olution.info/` | 200 OK – page d'accueil affichée |
| `https://iot.olution.info/api/realtime/sensors/latest` | 200 OK – JSON valide retourné |

---

## 3. Résumé de l'audit précédent (19:36 – avant correctif)

### OK
- **Toutes les pages web** (/, aquaponie, meteo, serre, galeries, dashboards, contrôles) : 200 OK
- **Ressources statiques** : CSS, logo, manifest, robots, favicon, service-worker, OTA
- **SSL** : certificat valide (expiration 2026-05-09)
- **Fichiers sensibles** : /.env, /.git, /vendor, /config : non exposés

### Erreurs / avertissements

| Catégorie | Détail |
|-----------|--------|
| **APIs JSON** | Le script `ConvertFrom-Json` PowerShell échouait (caractères UTF-8, format) – contenu JSON réel valide |
| **Endpoints firmware** | GET sur POST-only retourne 200 au lieu de 405 – comportement Slim/route à vérifier |
| **Redirections legacy** | /ffp3/*, /msp1/msp1control/*, etc. : 200 au lieu de 301 – config nginx/Apache à vérifier |
| **Logs cronlog** | 1091 [ERROR] – erreurs Ffp3RealtimeDataProvider, AbstractSensorRepository (liées au cache DI obsolète avant correctif) |
| **Headers** | Strict-Transport-Security et Content-Security-Policy absents |

---

## 4. Recommandations

1. **Cache DI** : en cas de mise à jour majeure, vider le cache via `/admin/clear-cache` pour recompiler le container.
2. **Endpoints POST-only** : renvoyer 405 sur GET (Slim MethodNotAllowedMiddleware ou routes dédiées).
3. **Redirections legacy** : aligner la config serveur (nginx/Apache) pour que /ffp3/*, etc. redirigent en 301.
4. **Headers sécurité** : ajouter HSTS et éventuellement CSP si pertinent.

---

*Rapport généré le 2026-03-09 après vérification post-déploiement.*
