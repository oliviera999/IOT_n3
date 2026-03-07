# Option 1 : intégrer ffp5cs en subtree (historique conservé)

Si le submodule ffp5cs a déjà été retiré dans n3_firmwires (commit « retrait submodule ffp5cs »), il reste à intégrer le **code** ffp5cs en **subtree** pour conserver l’historique.

## Prérequis

- Clone **propre** de n3_firmwires (pas de fichiers non suivis qui bloquent `git subtree add`).
- Connexion stable vers GitHub (le fetch de ffp5cs peut être long).

## Étapes (à exécuter dans un clone propre de n3_firmwires)

```powershell
# 1. Cloner n3_firmwires dans un dossier temporaire
cd $env:TEMP
git clone https://github.com/oliviera999/n3_firmwires.git n3_firmwires_subtree
cd n3_firmwires_subtree

# 2. Si ffp5cs est encore un submodule : le retirer
git submodule deinit -f ffp5cs
git rm ffp5cs
git add .gitmodules
git commit -m "[n3_firmwires] retrait submodule ffp5cs"

# 3. Intégrer ffp5cs en subtree (branche main sur GitHub)
git subtree add --prefix=ffp5cs https://github.com/oliviera999/ffp5cs.git main

# 4. Pousser vers GitHub
git push origin master
```

En cas d’erreur réseau (RPC failed, connection reset) pendant le `git subtree add`, réessayer plus tard ou depuis un autre réseau. Vous pouvez aussi augmenter le buffer :  
`git config http.postBuffer 524288000`

## Après le push

Dans votre IOT_n3 :

```powershell
cd c:\IOT_n3\firmwires
git pull origin master
```

Puis à la racine IOT_n3 : `git add firmwires && git commit -m "[projet] ref firmwires (ffp5cs en subtree)" && git push`
