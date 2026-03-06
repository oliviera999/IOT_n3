# Changelog IOT_n3

Modifications notables du depot racine (regles, doc, structure).

Format : [version] - date - description.

---

## [2025.03] - 2025-03-06

### Règles projet
- **Cycle obligatoire** : chaque modification (firmware ou serveur) doit être associée à une incrémentation de version, une mise à jour des fichiers de documentation concernés, suivie d’un commit et d’un push de tout le projet (dépôt parent et submodules) vers GitHub.
- Règles détaillées dans `.cursor/rules/git-et-versionnement.mdc` et `documentation.mdc`.
- Mise à jour des règles : contexte serveur unifié, procédure de push complète (submodules puis parent).
