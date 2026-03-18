# Corrections des liens de navigation - 9 mars 2026

## Problème identifié

Les liens de navigation vers MSP1 (Potager) et N3PP (Élevage) utilisent toujours les **anciens chemins longs** au lieu des **nouvelles URLs courtes**.

### Liens obsolètes actuels
- ❌ `/msp1/msp1datas/msp1-data.php` (MSP1 - Potager)
- ❌ `/n3pp/n3ppdatas/n3pp-data.php` (N3PP - Élevage)

### Nouveaux liens attendus
- ✅ `/meteo` (MSP1 - Potager)
- ✅ `/serre` (N3PP - Élevage)

---

## Fichiers à corriger

### 1. Menu de navigation principal
**Fichier** : `serveur/templates/partials/_nav.twig`

**Lignes à modifier** :
- **Ligne 9** : Lien MSP1 (Potager)
- **Ligne 10** : Lien N3PP (Élevage)

#### Correction ligne 9 (MSP1)
```twig
<!-- AVANT -->
<li class="{{ nav_active == 'potager' or nav_active == 'potager_control' ? 'active' }}"><a href="{{ bp }}/msp1/msp1datas/msp1-data.php">Potager (MSP1)</a></li>

<!-- APRÈS -->
<li class="{{ nav_active == 'potager' or nav_active == 'potager_control' ? 'active' }}"><a href="{{ bp }}/meteo">Potager (MSP1)</a></li>
```

#### Correction ligne 10 (N3PP)
```twig
<!-- AVANT -->
<li class="{{ nav_active == 'elevage' or nav_active == 'elevage_control' ? 'active' }}"><a href="{{ bp }}/n3pp/n3ppdatas/n3pp-data.php">Élevage (N3PP)</a></li>

<!-- APRÈS -->
<li class="{{ nav_active == 'elevage' or nav_active == 'elevage_control' ? 'active' }}"><a href="{{ bp }}/serre">Élevage (N3PP)</a></li>
```

---

### 2. Page d'accueil - Cartes de projets
**Fichier** : `serveur/templates/home.twig`

**Lignes à modifier** :
- **Ligne 284** : Lien carte MSP1 (Potager)
- **Ligne 314** : Lien carte N3PP (Élevage)

#### Correction ligne 284 (Carte MSP1)
```twig
<!-- AVANT -->
<a href="/msp1/msp1datas/msp1-data.php" class="project-link">
    <i class="fas fa-chart-line"></i> Voir les données
</a>

<!-- APRÈS -->
<a href="/meteo" class="project-link">
    <i class="fas fa-chart-line"></i> Voir les données
</a>
```

#### Correction ligne 314 (Carte N3PP)
```twig
<!-- AVANT -->
<a href="/n3pp/n3ppdatas/n3pp-data.php" class="project-link">
    <i class="fas fa-chart-line"></i> Voir les données
</a>

<!-- APRÈS -->
<a href="/serre" class="project-link">
    <i class="fas fa-chart-line"></i> Voir les données
</a>
```

---

### 3. Templates FFP3 (optionnel)
**Fichier** : `serveur/archives/ffp3/templates/home.twig`

**Lignes à modifier** :
- **Ligne 206** : Menu navigation MSP1
- **Ligne 207** : Menu navigation N3PP
- **Ligne 303** : Carte projet MSP1
- **Ligne 321** (estimation) : Carte projet N3PP

**Note** : Ces templates FFP3 sont pour l'ancien système. Si le nouveau système unifié est utilisé, ces fichiers peuvent être ignorés ou mis à jour pour cohérence.

---

## Procédure de correction

### Étape 1 : Modifier les fichiers
1. Ouvrir `serveur/templates/partials/_nav.twig`
   - Remplacer ligne 9 : `/msp1/msp1datas/msp1-data.php` → `/meteo`
   - Remplacer ligne 10 : `/n3pp/n3ppdatas/n3pp-data.php` → `/serre`

2. Ouvrir `serveur/templates/home.twig`
   - Remplacer ligne 284 : `/msp1/msp1datas/msp1-data.php` → `/meteo`
   - Remplacer ligne 314 : `/n3pp/n3ppdatas/n3pp-data.php` → `/serre`

### Étape 2 : Tester localement
```powershell
# Démarrer le serveur local PHP
cd C:\IOT_n3\serveur
php -S localhost:8000 -t public

# Tester les pages dans le navigateur
# http://localhost:8000/
# http://localhost:8000/meteo
# http://localhost:8000/serre
```

### Étape 3 : Vérifier les liens
- [ ] Page d'accueil : menu de navigation pointe vers `/meteo` et `/serre`
- [ ] Page d'accueil : cartes projets pointent vers `/meteo` et `/serre`
- [ ] Les pages `/meteo` et `/serre` se chargent correctement
- [ ] Pas d'erreur 404 ou de redirection cassée

### Étape 4 : Commiter et déployer
```powershell
# Depuis la racine IOT_n3
cd C:\IOT_n3
.\scripts\publish-cycle.ps1 -Component serveur -Message "Correction liens navigation MSP1/N3PP vers URLs courtes /meteo et /serre"
```

---

## Impact et bénéfices

### Avant (problème)
- Navigation confuse avec chemins longs et techniques
- URLs non mémorables : `/msp1/msp1datas/msp1-data.php`
- Incohérence entre anciennes et nouvelles URLs

### Après (solution)
- ✅ URLs courtes et mémorables : `/meteo`, `/serre`
- ✅ Cohérence dans toute l'interface
- ✅ Meilleure expérience utilisateur
- ✅ URLs plus faciles à partager et à retenir

---

## Vérification post-déploiement

Après déploiement sur `iot.olution.info`, vérifier :

1. **Page d'accueil** (https://iot.olution.info/)
   - Menu : "Potager (MSP1)" → `/meteo`
   - Menu : "Élevage (N3PP)" → `/serre`
   - Carte "Le potager" → `/meteo`
   - Carte "L'élevage d'insectes" → `/serre`

2. **Pages de destination**
   - https://iot.olution.info/meteo → se charge correctement
   - https://iot.olution.info/serre → se charge correctement

3. **Anciennes URLs** (optionnel : vérifier si redirections en place)
   - https://iot.olution.info/msp1/msp1datas/msp1-data.php
   - https://iot.olution.info/n3pp/n3ppdatas/n3pp-data.php

---

## Fichiers modifiés (résumé)

| Fichier | Lignes | Type de modification |
|---------|--------|---------------------|
| `serveur/templates/partials/_nav.twig` | 9, 10 | Liens menu navigation |
| `serveur/templates/home.twig` | 284, 314 | Liens cartes projets |

**Total** : 2 fichiers, 4 lignes à modifier

---

## Commandes rapides

```powershell
# Éditer les fichiers
code C:\IOT_n3\serveur\templates\partials\_nav.twig
code C:\IOT_n3\serveur\templates\home.twig

# Tester localement
cd C:\IOT_n3\serveur
php -S localhost:8000 -t public

# Publier
cd C:\IOT_n3
.\scripts\publish-cycle.ps1 -Component serveur -Message "Correction liens navigation vers /meteo et /serre"
```
