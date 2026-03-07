# Configuration des sous-modules n3_serveur et n3_firmwires

## État actuel

- **serveur/** est un **sous-module** pointant vers **n3_serveur** (msp1, n3pp, galeries, ffp3).
- **firmwires/** est un **sous-module** pointant vers **n3_firmwires** (tous les firmwares : n3pp4_2, msp2_5, uploadphotosserver*, ffp5cs, ratata, LVGL_Widgets). ffp5cs n’est plus un submodule à la racine ; il est un dossier normal dans n3_firmwires.

Si votre clone a encore l’ancienne structure (firmwires en dossier + ffp5cs en submodule), exécuter depuis la racine IOT_n3 :  
`.\scripts\migrate-firmwires-to-submodule.ps1 -DryRun` puis, après avoir poussé le contenu de firmwires vers n3_firmwires, `.\scripts\migrate-firmwires-to-submodule.ps1`.

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

**Firmwires (déjà en submodule sur les clones à jour) :** si vous avez encore l’ancienne structure, une fois le contenu de firmwires poussé vers n3_firmwires, à la racine de IOT_n3 :

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
