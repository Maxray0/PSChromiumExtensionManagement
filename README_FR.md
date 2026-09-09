# PSChromium Extension Policy CLI

**Français** | [English](README.md)

Interface PowerShell interactive pour lire et gérer les stratégies `ExtensionSettings` de Microsoft Edge et Google Chrome sous Windows.

Ce projet est basé sur [PSChromiumExtensionManagement](https://github.com/KopterBuzz/PSChromiumExtensionManagement) de Gabor Nemeth. Il adapte le script d’origine à une représentation du Registre Windows utilisant une sous-clé par extension.

> [!WARNING]
> Ce script modifie les stratégies de navigateur dans le Registre Windows. Utilisez-le uniquement sur un appareil que vous êtes autorisé à administrer. Une règle locale peut entrer en conflit avec une GPO, Intune, MDM ou une stratégie cloud.

## Fonctionnalités

- Interface CLI interactive avec démarrage automatique lors de l’exécution directe du fichier `.ps1`.
- Prise en charge de Microsoft Edge et Google Chrome.
- Portées `LocalMachine` (`HKLM`) et `CurrentUser` (`HKCU`).
- Lecture de toutes les règles `ExtensionSettings` existantes.
- Affichage détaillé d’une extension par identifiant.
- Ajout ou mise à jour d’une règle individuelle.
- Modes `allowed`, `blocked`, `normal_installed`, `force_installed` et `removed`.
- Sources prédéfinies pour Microsoft Edge Add-ons et Chrome Web Store.
- URL de mise à jour personnalisée.
- Édition avancée des permissions, hôtes autorisés ou bloqués, message de blocage et état de la barre d’outils.
- Suppression ciblée d’une règle sans toucher aux autres extensions.
- Sauvegarde du Registre dans un fichier `.reg`.
- Prise en charge de `-WhatIf` et confirmations explicites.
- Dot-sourcing pour charger les fonctions sans ouvrir la CLI.

## Changements par rapport au script d’origine

Le script d’origine lit et écrit une valeur JSON globale nommée `ExtensionSettings` :

```text
HKLM:\SOFTWARE\Policies\Microsoft\Edge
└── ExtensionSettings = "{ ... JSON ... }"
```

Cette version utilise une sous-clé par extension :

```text
HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionSettings
├── <ExtensionID-1>
│   ├── installation_mode
│   ├── update_url
│   └── ...
└── <ExtensionID-2>
    └── installation_mode
```

| Domaine | Script d’origine | Cette version |
|---|---|---|
| Stockage | Une valeur JSON globale | Une sous-clé par identifiant |
| Interface | Fonctions PowerShell | Fonctions et CLI interactive |
| Démarrage | Appel manuel | Démarrage automatique en exécution directe |
| Lecture | État JSON en mémoire | Énumération directe des sous-clés |
| Écriture | Réécriture du JSON partagé | Mise à jour de la seule extension ciblée |
| Suppression | Suppression d’une propriété JSON | Suppression de la seule sous-clé ciblée |
| Sécurité | Pas de prévisualisation intégrée | `-WhatIf`, confirmations et sauvegarde `.reg` |
| Propriétés facultatives | Accès direct potentiellement en erreur | Vérification avant affichage |
| Portée | Chemins statiques | Bascule CLI entre machine et utilisateur |
| Langues | Anglais | Fichiers anglais et français séparés |

Autres corrections et améliorations :

- correction de la faute `Get-Iitem` observée dans le script d’origine ;
- utilisation de `toolbar_state` à la place de `toolbar_pin` ;
- validation des identifiants Chromium de 32 caractères composés des lettres `a` à `p` ;
- obligation d’une `update_url` pour `normal_installed` et `force_installed` ;
- refus des modes d’installation automatique sur la portée globale `*` ;
- conservation des propriétés non modifiées d’une règle existante ;
- gestion sûre des propriétés facultatives telles que `update_url` sous `Set-StrictMode`.

## Prérequis

- Windows.
- Windows PowerShell 5.1 ou PowerShell 7.
- Microsoft Edge ou Google Chrome.
- Une console élevée pour les changements `LocalMachine`.
- Une autorisation pour modifier les stratégies du poste.

## Installation et démarrage

Exécutez directement la version française :

```powershell
.\PSChromiumExtensionManagement.CLI.AutoStart.FR.ps1
```

Pour charger les fonctions sans ouvrir le menu :

```powershell
. "$PWD\PSChromiumExtensionManagement.CLI.AutoStart.FR.ps1"
```

Pour démarrer ensuite la CLI manuellement :

```powershell
Start-PSChromiumExtensionCLI -BrowserName "Microsoft Edge" -Scope LocalMachine
```

## Menu CLI

```text
[1] Lister les stratégies
[2] Afficher une extension
[3] Autoriser une extension
[4] Bloquer une extension
[5] Installer automatiquement (désactivable)
[6] Forcer l’installation
[7] Marquer une extension comme supprimée
[8] Édition avancée
[9] Supprimer une règle de stratégie
[B] Sauvegarder les stratégies
[C] Changer de navigateur ou de portée
[Q] Quitter
```

## Modes d’installation

| Mode | Effet |
|---|---|
| `allowed` | L’utilisateur peut installer manuellement l’extension. |
| `blocked` | L’extension ne peut pas être installée. |
| `normal_installed` | Le navigateur installe automatiquement l’extension. L’utilisateur peut la désactiver, mais elle reste gérée par stratégie. |
| `force_installed` | Le navigateur installe automatiquement l’extension. L’utilisateur ne peut ni la désactiver ni la supprimer. |
| `removed` | Le navigateur retire l’extension et bloque son installation tant que la règle reste active. |

> [!NOTE]
> Lors des tests sur Microsoft Edge, la suppression d’une règle `normal_installed`, suivie d’un redémarrage complet, a automatiquement désinstallé l’extension gérée.

## Exemples PowerShell

### Lister les règles

```powershell
Get-PSChromiumExtension -BrowserName "Microsoft Edge" -ExtensionID "All" -Scope LocalMachine
```

### Autoriser une extension

```powershell
Set-PSChromiumExtension -BrowserName "Microsoft Edge" -ExtensionID "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" -InstallationMode allowed -Scope LocalMachine
```

### Installer depuis Chrome Web Store

```powershell
Set-PSChromiumExtension `
    -BrowserName "Microsoft Edge" `
    -ExtensionID "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" `
    -InstallationMode normal_installed `
    -UpdateURL "https://clients2.google.com/service/update2/crx" `
    -Scope LocalMachine
```

### Prévisualiser un changement

```powershell
Set-PSChromiumExtension -BrowserName "Microsoft Edge" -ExtensionID "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" -InstallationMode allowed -Scope LocalMachine -WhatIf
```

### Supprimer une règle

```powershell
Remove-PSChromiumExtension -BrowserName "Microsoft Edge" -ExtensionID "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" -Scope LocalMachine -Confirm
```

## Sauvegarde et restauration

Créez une sauvegarde depuis l’option **B**, ou exécutez :

```powershell
Backup-PSChromiumExtensionSettings `
    -BrowserName "Microsoft Edge" `
    -Scope LocalMachine `
    -Destination "$env:USERPROFILE\Desktop\Edge-ExtensionSettings-backup.reg"
```

Vérifiez le contenu avant restauration. Fermez le navigateur, puis importez la sauvegarde uniquement si vous êtes autorisé à restaurer ces règles :

```powershell
reg.exe import "$env:USERPROFILE\Desktop\Edge-ExtensionSettings-backup.reg"
```

## Validation

Pour Microsoft Edge :

1. Ouvrez `edge://policy`.
2. Rechargez les stratégies ou redémarrez complètement Edge.
3. Vérifiez l’entrée `ExtensionSettings` et son état.
4. Ouvrez `edge://extensions` pour vérifier l’état réel de l’extension.
5. Confirmez que les règles non ciblées sont toujours présentes.

Pour Google Chrome, utilisez `chrome://policy` et `chrome://extensions`.

## Comportements testés

Validés sur Microsoft Edge avec la portée `LocalMachine` :

- démarrage automatique de la CLI ;
- lecture et affichage des règles existantes ;
- affichage sûr des règles sans `update_url` ;
- ajout d’une règle `allowed` ;
- suppression ciblée d’une règle ;
- conservation des règles non ciblées ;
- déploiement `normal_installed` depuis Chrome Web Store ;
- installation après redémarrage d’Edge ;
- désinstallation automatique après retrait de la règle `normal_installed` et redémarrage d’Edge.

Implémentés mais non déclarés comme validés par ces tests :

- cible Google Chrome ;
- portée `CurrentUser` ;
- modes `force_installed`, `blocked` et `removed` ;
- réglages avancés de permissions et d’hôtes ;
- restauration d’une sauvegarde ;
- URL de mise à jour personnalisées ;
- portée globale `*` ;
- exécution sous PowerShell 7.

## Limites et précautions

- Les extensions installées avec `normal_installed` ou `force_installed` apparaissent comme gérées par l’organisation.
- Une règle locale peut être écrasée par une GPO, Intune, MDM ou une stratégie cloud.
- `ExtensionSettings` peut prévaloir sur d’autres stratégies d’extensions.
- Le script n’évalue pas la réputation, les permissions ou la sécurité d’une extension.
- Le script ne télécharge pas directement les extensions. Le navigateur utilise l’`update_url` configurée.
- Une règle globale `*` incorrecte peut affecter toutes les extensions. Préférez les identifiants individuels.
- Sauvegardez les stratégies et vérifiez les chemins du Registre avant modification.

## Licence et attribution

Ce projet dérive de [PSChromiumExtensionManagement](https://github.com/KopterBuzz/PSChromiumExtensionManagement), créé par Gabor Nemeth en 2025 et publié sous licence GPL-3.0.

Conservez dans le dépôt :

- le fichier `LICENSE` GPL-3.0 ;
- l’attribution à l’auteur d’origine ;
- une description claire des modifications ;
- le code source des versions distribuées, conformément aux obligations applicables de la licence.

## Références

- [Guide Microsoft Edge ExtensionSettings](https://learn.microsoft.com/deployedge/microsoft-edge-manage-extensions-ref-guide)
- [Projet d’origine PSChromiumExtensionManagement](https://github.com/KopterBuzz/PSChromiumExtensionManagement)
