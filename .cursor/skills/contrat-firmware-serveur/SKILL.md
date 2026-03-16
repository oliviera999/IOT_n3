---
name: contrat-firmware-serveur
description: Workflow pour maintenir la coherence du contrat d'interface entre firmwares ESP32 et serveur PHP (endpoints, champs JSON, cles API, codes de statut). Utiliser quand on modifie un endpoint, un champ JSON, une cle de config, un code de statut, ou quand on ajoute un nouveau flux firmware-serveur.
---

# Contrat firmware-serveur — Workflow de coherence

## Principe

Les firmwares et le serveur partagent un **contrat d'interface** : endpoints, champs JSON, cles de config, codes de statut. Ce contrat doit rester synchronise des deux cotes.

**Unification** : firmwares et fichiers serveur doivent etre les plus unifies possibles (factorisation, templates de base, constantes partagees) sans nuire aux fonctionnalites ni aux specificites des pages ou des firmwares.

## Liens firmware ↔ serveur du projet

| Firmware | Dossier firmware | Serveur | Auth |
|----------|-----------------|---------|------|
| n3pp | `firmwires/n3pp/` | `serveur/` (routes N3pp) | Cle API simple |
| msp | `firmwires/msp/` | `serveur/` (routes Msp) | Cle API simple |
| ffp5cs | `firmwires/ffp5cs/` | `serveur/ffp3/` | api_key (actuel) ; HMAC-SHA256 (cible) |
| ESP32-CAM (x3) | `firmwires/uploadphotosserver_*/` | `serveur/` (GalleryUpload) | Cle API |

## Workflow : modification d'un contrat existant

### Etape 1 — Identifier les deux cotes

Avant toute modification, localiser :
- **Cote firmware** : le fichier qui envoie/recoit la donnee (souvent `main.cpp` ou un module reseau)
- **Cote serveur** : le Controller + Repository qui traite la requete

### Etape 2 — Modifier simultanement

Appliquer la modification des **deux cotes dans le meme commit** quand possible :
- Firmware : constantes, noms de champs, URL d'endpoint
- Serveur : route, validation, noms de colonnes, reponse JSON

### Etape 3 — Verifier la coherence

Check-list :
- [ ] Les noms de champs JSON sont identiques des deux cotes
- [ ] L'URL de l'endpoint est identique (attention aux slashes finaux)
- [ ] La methode HTTP est coherente (POST/GET)
- [ ] Les codes de reponse sont geres cote firmware (200, 400, 401, 500)
- [ ] La cle API ou signature est configuree identiquement
- [ ] Les types de donnees sont compatibles (int/float/string)

### Etape 4 — Documenter

- Pour FFP3 : mettre a jour la doc dans `serveur/ffp3/docs/`
- Pour MSP/N3PP : ajouter un commentaire dans le Controller si le contrat evolue
- Si une constante est partagee, la documenter dans les deux fichiers source

## Workflow : ajout d'un nouveau flux

1. **Definir le contrat** : endpoint URL, methode, champs JSON, auth
2. **Cote serveur** : creer le Controller + Route + Repository + validation
3. **Cote firmware** : implementer l'appel HTTP avec les memes noms de champs
4. **Tester** : envoyer une requete manuelle (curl/Postman) avant de flasher
5. **Documenter** : ajouter le lien dans le README racine (tableau firmware-serveur)

## Modele de reference : FFP5CS ↔ FFP3

Le contrat le plus mature du projet. A utiliser comme inspiration :
- **Auth actuelle** : cle API en POST (`api_key`) — alignee avec msp/n3pp.
- **Auth cible** : HMAC-SHA256 (serveur deja pret via `timestamp` + `signature` ; firmware a migrer).
- JSON structure avec champs types.
- Heartbeat / supervision.
- Constantes harmonisees (voir `firmwires/ffp5cs/.cursor/rules/FFP5CS-constantes-harmonisees-firmware-serveur.mdc`)

## Anti-patterns a eviter

- Modifier un endpoint cote serveur sans mettre a jour le firmware (ou inversement)
- Ajouter un champ JSON cote firmware sans le valider cote serveur
- Coder en dur une URL de serveur sans constante (utiliser `credentials.h` ou NVS)
- Ignorer les codes de reponse HTTP cote firmware
