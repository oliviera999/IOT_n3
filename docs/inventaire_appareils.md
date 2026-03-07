# Registre des appareils IoT – Salle aérée n³

*Dernière mise à jour : mars 2026.*

Ce document recense les appareils (ESP32, ESP32-CAM, etc.) déployés ou prévus pour **[la salle aérée n³](https://n3.olution.info)**. Backend : [iot.olution.info](https://iot.olution.info).

---

## Tableau d’inventaire

À compléter selon les appareils effectivement en place. Colonnes suggérées :

| Identifiant | Type de firmware | Emplacement / pôle | Board ID ou endpoint | Dernière version firmware | Dernière donnée reçue |
|-------------|------------------|--------------------|----------------------|---------------------------|------------------------|
| *(ex. n3-n3pp-01)* | n3pp4_2 | Serre / aquaponie | board=3 | — | — |
| *(ex. n3-msp-01)* | msp2_5 | Station météo | board=2 | — | — |
| *(ex. n3-ffp5cs-01)* | ffp5cs | Aquaponie (FFP3) | — | — | — |
| *(ex. n3-cam-msp-01)* | uploadphotosserver_msp1 | — | msp1gallery | — | — |
| *(ex. n3-cam-n3pp-01)* | uploadphotosserver_n3pp_* | — | n3ppgallery | — | — |

---

## Nommage recommandé

- **Préfixe commun :** `n3-` pour tous les identifiants (hostname mDNS, noms dans les logs, registre).
- **Exemples :** `n3-n3pp-01`, `n3-msp-01`, `n3-ffp5cs-serre`, `n3-cam-msp-01`.

Cela facilite le diagnostic sur le réseau du lycée et la lecture des logs.

---

## Références

- Présentation salle n³ : [n3.olution.info](https://n3.olution.info)
- Backend IoT : [iot.olution.info](https://iot.olution.info)
- Liens firmware ↔ serveur : [README racine](../README.md), [RECOMMANDATIONS_IOT](../RECOMMANDATIONS_IOT.md)
