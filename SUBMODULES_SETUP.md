# Configuration des sous-modules n3_serveur et n3_firmwires

## État actuel (mis à jour après fusion ffp3)

- **serveur/** est désormais un **sous-module** pointant vers **n3_serveur** dans IOT_n3. Le dépôt n3_serveur contient msp1, n3pp, les galeries et **ffp3** en dossier intégré (fusionné avec historique via `git subtree add` ; le dépôt ffp3 n’est plus un submodule).
- **firmwires/** : la procédure ci-dessous pour remplacer firmwires par le sous-module n3_firmwires reste à faire si souhaité.

## Étapes à faire

### 1. Créer les deux dépôts sur GitHub

Créez deux dépôts **vides** (sans README, sans .gitignore) :

- https://github.com/new?name=n3_serveur  
- https://github.com/new?name=n3_firmwires  

### 2. Pousser le code vers GitHub

Dans un terminal, exécutez :

```powershell
cd c:\IOT_n3\serveur
git push -u origin master
```

Puis :

```powershell
cd c:\IOT_n3\firmwires
git push -u origin master
```

### 3. Remplacer les dossiers par les sous-modules dans IOT_n3

**Serveur :** déjà fait. Le dossier **serveur** est le sous-module **n3_serveur** (ffp3 a été fusionné dans n3_serveur ; il n’y a plus de sous-module `serveur/ffp3`).

**Firmwires (si vous souhaitez aussi utiliser n3_firmwires) :** une fois le push firmwires réussi, à la racine de IOT_n3 :

```powershell
cd c:\IOT_n3

# Désenregistrer l’ancien sous-module firmwires/ffp5cs si besoin
git submodule deinit -f firmwires/ffp5cs

# Supprimer firmwires du suivi Git
git rm -r firmwires

# Ajouter le sous-module n3_firmwires
git submodule add https://github.com/oliviera999/n3_firmwires.git firmwires

# Commit et push
git add .gitmodules
git commit -m "Remplacer firmwires par sous-module n3_firmwires"
git push origin master
```

## Après la mise en place

- Les changements dans **serveur** se poussent depuis `c:\IOT_n3\serveur` vers le dépôt **n3_serveur**.
- Les changements dans **firmwires** se poussent depuis `c:\IOT_n3\firmwires` vers le dépôt **n3_firmwires**.
- Le dépôt **IOT_n3** ne contient plus que des références (sous-modules) vers ces deux dépôts.
