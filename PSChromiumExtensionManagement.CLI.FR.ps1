#requires -Version 5.1
<#
.SYNOPSIS
Gestion locale des strategies ExtensionSettings pour Microsoft Edge et Google Chrome.

.DESCRIPTION
Utilise la representation Windows par sous-cles :
HKLM/HKCU:\SOFTWARE\Policies\<Editeur>\<Navigateur>\ExtensionSettings\<ExtensionID>
Inclut une interface CLI interactive via Start-PSChromiumExtensionCLI.

IMPORTANT
- Executer en administrateur pour LocalMachine.
- Utiliser uniquement avec l'autorisation de l'organisation.
- Valider dans edge://policy ou chrome://policy.
#>

Set-StrictMode -Version Latest

$script:PSChromiumSupportedBrowsers = @{
    "Google Chrome" = @{
        LocalMachine = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionSettings"
        CurrentUser  = "HKCU:\SOFTWARE\Policies\Google\Chrome\ExtensionSettings"
    }
    "Microsoft Edge" = @{
        LocalMachine = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionSettings"
        CurrentUser  = "HKCU:\SOFTWARE\Policies\Microsoft\Edge\ExtensionSettings"
    }
}

function Get-PSChromiumExtensionSettingsRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet("Google Chrome","Microsoft Edge")][string]$BrowserName,
        [ValidateSet("LocalMachine","CurrentUser")][string]$Scope = "LocalMachine"
    )
    return $script:PSChromiumSupportedBrowsers[$BrowserName][$Scope]
}

function ConvertTo-PSChromiumRegistryValue {
    param([Parameter(Mandatory)]$Value)
    if ($Value -is [System.Array]) { return ($Value | ConvertTo-Json -Compress) }
    return $Value
}

function Get-PSChromiumExtension {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet("Google Chrome","Microsoft Edge","All")][string[]]$BrowserName,
        [Parameter(Mandatory)][string[]]$ExtensionID,
        [ValidateSet("LocalMachine","CurrentUser")][string]$Scope = "LocalMachine",
        [switch]$AsJSON
    )

    $browsers = if ($BrowserName -contains "All") { @("Google Chrome","Microsoft Edge") } else { $BrowserName }
    $output = foreach ($browser in $browsers) {
        $root = Get-PSChromiumExtensionSettingsRoot -BrowserName $browser -Scope $Scope
        if (-not (Test-Path $root)) { continue }
        $ids = if ($ExtensionID -contains "All") {
            @(Get-ChildItem -Path $root -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSChildName)
        } else { $ExtensionID }

        foreach ($id in $ids) {
            $path = Join-Path $root $id
            if (-not (Test-Path $path)) { continue }
            $item = Get-ItemProperty -Path $path
            $settings = [ordered]@{}
            foreach ($property in $item.PSObject.Properties) {
                if ($property.Name -notin @("PSPath","PSParentPath","PSChildName","PSDrive","PSProvider")) {
                    $settings[$property.Name] = $property.Value
                }
            }
            $settingsObject = [pscustomobject]$settings
            [pscustomobject]@{
                Browser = $browser
                Scope = $Scope
                ExtensionID = $id
                RegistryPath = $path
                ExtensionSettings = if ($AsJSON) { $settingsObject | ConvertTo-Json -Depth 10 -Compress } else { $settingsObject }
            }
        }
    }
    return $output
}

function Set-PSChromiumExtension {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact="Medium")]
    param(
        [Parameter(Mandatory)][ValidateSet("Google Chrome","Microsoft Edge")][string[]]$BrowserName,
        [Parameter(Mandatory)][ValidatePattern('^(\*|[a-p]{32})$')][string]$ExtensionID,
        [Parameter(Mandatory)][ValidateSet("allowed","blocked","force_installed","normal_installed","removed")][string]$InstallationMode,
        [ValidateSet("LocalMachine","CurrentUser")][string]$Scope = "LocalMachine",
        [ValidateSet("extension","hosted_app","legacy_packaged_app","platform_app","theme","user_script")][string[]]$AllowedTypes,
        [ValidateLength(0,1000)][string]$BlockedInstallMessage,
        [string[]]$BlockedPermissions,
        [Nullable[bool]]$FileURLNavigationAllowed,
        [string]$MinimumVersionRequired,
        [ValidateScript({ [string]::IsNullOrWhiteSpace($_) -or [Uri]::IsWellFormedUriString($_,[UriKind]::Absolute) })][string]$UpdateURL,
        [Nullable[bool]]$OverrideUpdateURL,
        [string[]]$RuntimeAllowedHosts,
        [string[]]$RuntimeBlockedHosts,
        [ValidateSet("force_shown","default_hidden","default_shown")][string]$ToolbarState,
        [Nullable[bool]]$SidebarAutoOpenBlocked
    )

    if ($ExtensionID -ne "*" -and $PSBoundParameters.ContainsKey("AllowedTypes")) {
        throw "AllowedTypes peut uniquement etre utilise avec ExtensionID '*'."
    }
    if ($ExtensionID -eq "*" -and $InstallationMode -in @("force_installed","normal_installed")) {
        throw "Le mode $InstallationMode n'est pas valide avec ExtensionID '*'."
    }
    if ($InstallationMode -in @("force_installed","normal_installed") -and [string]::IsNullOrWhiteSpace($UpdateURL)) {
        throw "UpdateURL est obligatoire avec le mode $InstallationMode."
    }

    $settings = [ordered]@{ installation_mode = $InstallationMode }
    $map = [ordered]@{
        AllowedTypes = "allowed_types"
        BlockedInstallMessage = "blocked_install_message"
        BlockedPermissions = "blocked_permissions"
        FileURLNavigationAllowed = "file_url_navigation_allowed"
        MinimumVersionRequired = "minimum_version_required"
        UpdateURL = "update_url"
        OverrideUpdateURL = "override_update_url"
        RuntimeAllowedHosts = "runtime_allowed_hosts"
        RuntimeBlockedHosts = "runtime_blocked_hosts"
        ToolbarState = "toolbar_state"
        SidebarAutoOpenBlocked = "sidebar_auto_open_blocked"
    }
    foreach ($parameterName in $map.Keys) {
        if ($PSBoundParameters.ContainsKey($parameterName)) {
            $settings[$map[$parameterName]] = Get-Variable -Name $parameterName -ValueOnly
        }
    }

    foreach ($browser in $BrowserName) {
        $root = Get-PSChromiumExtensionSettingsRoot -BrowserName $browser -Scope $Scope
        $path = Join-Path $root $ExtensionID
        if ($PSCmdlet.ShouldProcess($path,"Creer ou actualiser la strategie d'extension")) {
            New-Item -Path $path -Force | Out-Null
            foreach ($entry in $settings.GetEnumerator()) {
                $isBool = $entry.Value -is [bool]
                $type = if ($isBool) { "DWord" } else { "String" }
                $value = if ($isBool) { [int]$entry.Value } else { ConvertTo-PSChromiumRegistryValue -Value $entry.Value }
                New-ItemProperty -Path $path -Name $entry.Key -Value $value -PropertyType $type -Force | Out-Null
            }
            Get-PSChromiumExtension -BrowserName $browser -ExtensionID $ExtensionID -Scope $Scope
        }
    }
}

function Remove-PSChromiumExtension {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact="High")]
    param(
        [Parameter(Mandatory)][ValidateSet("Google Chrome","Microsoft Edge")][string[]]$BrowserName,
        [Parameter(Mandatory)][ValidatePattern('^(\*|[a-p]{32})$')][string[]]$ExtensionID,
        [ValidateSet("LocalMachine","CurrentUser")][string]$Scope = "LocalMachine"
    )
    foreach ($browser in $BrowserName) {
        $root = Get-PSChromiumExtensionSettingsRoot -BrowserName $browser -Scope $Scope
        foreach ($id in $ExtensionID) {
            $path = Join-Path $root $id
            if ((Test-Path $path) -and $PSCmdlet.ShouldProcess($path,"Supprimer uniquement cette strategie d'extension")) {
                Remove-Item -Path $path -Recurse -Force
            }
        }
    }
}

function Backup-PSChromiumExtensionSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet("Google Chrome","Microsoft Edge")][string]$BrowserName,
        [ValidateSet("LocalMachine","CurrentUser")][string]$Scope = "LocalMachine",
        [Parameter(Mandatory)][string]$Destination
    )
    $root = Get-PSChromiumExtensionSettingsRoot -BrowserName $BrowserName -Scope $Scope
    if (-not (Test-Path $root)) { throw "Cle absente: $root" }
    $nativePath = $root -replace '^HKLM:', 'HKEY_LOCAL_MACHINE' -replace '^HKCU:', 'HKEY_CURRENT_USER'
    & reg.exe export $nativePath $Destination /y
    if ($LASTEXITCODE -ne 0) { throw "Echec de l'export du Registre, code $LASTEXITCODE." }
}

function Read-PSChromiumChoice {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][hashtable]$Choices
    )
    while ($true) {
        Write-Host ""
        foreach ($key in ($Choices.Keys | Sort-Object)) { Write-Host "  [$key] $($Choices[$key])" }
        $answer = (Read-Host $Prompt).Trim().ToUpperInvariant()
        if ($Choices.ContainsKey($answer)) { return $answer }
        Write-Warning "Choix invalide."
    }
}

function Read-PSChromiumExtensionID {
    while ($true) {
        $id = (Read-Host "Identifiant de l'extension (32 lettres de a a p, ou * pour le defaut)").Trim().ToLowerInvariant()
        if ($id -match '^(\*|[a-p]{32})$') { return $id }
        Write-Warning "Identifiant invalide."
    }
}

function Read-PSChromiumList {
    param([Parameter(Mandatory)][string]$Prompt)
    $raw = Read-Host "$Prompt (valeurs separees par des virgules, vide pour ignorer)"
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return @($raw.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Show-PSChromiumCLIContext {
    param([string]$BrowserName,[string]$Scope)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host " PSChromium Extension Policy CLI" -ForegroundColor Cyan
    Write-Host " Navigateur : $BrowserName | Portee : $Scope" -ForegroundColor Gray
    Write-Host "============================================================" -ForegroundColor DarkCyan
}

function Start-PSChromiumExtensionCLI {
    [CmdletBinding()]
    param(
        [ValidateSet("Google Chrome","Microsoft Edge")][string]$BrowserName = "Microsoft Edge",
        [ValidateSet("LocalMachine","CurrentUser")][string]$Scope = "LocalMachine"
    )

    $quit = $false
    while (-not $quit) {
        Show-PSChromiumCLIContext -BrowserName $BrowserName -Scope $Scope
        Write-Host "  [1] Lister les strategies"
        Write-Host "  [2] Afficher une extension"
        Write-Host "  [3] Autoriser une extension"
        Write-Host "  [4] Bloquer une extension"
        Write-Host "  [5] Installer automatiquement (desactivable)"
        Write-Host "  [6] Forcer l'installation"
        Write-Host "  [7] Marquer une extension comme supprimee"
        Write-Host "  [8] Edition avancee"
        Write-Host "  [9] Supprimer une regle de strategie"
        Write-Host "  [B] Sauvegarder les strategies"
        Write-Host "  [C] Changer navigateur ou portee"
        Write-Host "  [Q] Quitter"
        Write-Host ""
        $choice = (Read-Host "Choix").Trim().ToUpperInvariant()

        try {
            switch ($choice) {
                "1" {
                    $items = @(Get-PSChromiumExtension -BrowserName $BrowserName -ExtensionID "All" -Scope $Scope)
                    if ($items.Count -eq 0) { Write-Host "Aucune regle trouvee." -ForegroundColor Yellow }
                    else {
                        $items | ForEach-Object {
                            $settings = $_.ExtensionSettings
                            $installationMode = if ($settings.PSObject.Properties["installation_mode"]) {
                                $settings.installation_mode
                            } else {
                                $null
                            }
                            $updateURL = if ($settings.PSObject.Properties["update_url"]) {
                                $settings.update_url
                            } else {
                                $null
                            }
                            [pscustomobject]@{
                                ExtensionID = $_.ExtensionID
                                InstallationMode = $installationMode
                                UpdateURL = $updateURL
                            }
                        } | Format-Table -AutoSize
                    }
                    Read-Host "Entree pour continuer" | Out-Null
                }
                "2" {
                    $id = Read-PSChromiumExtensionID
                    $item = Get-PSChromiumExtension -BrowserName $BrowserName -ExtensionID $id -Scope $Scope
                    if ($null -eq $item) { Write-Host "Regle absente." -ForegroundColor Yellow }
                    else { $item | Format-List }
                    Read-Host "Entree pour continuer" | Out-Null
                }
                { $_ -in @("3","4","5","6","7") } {
                    $id = Read-PSChromiumExtensionID
                    $mode = @{"3"="allowed";"4"="blocked";"5"="normal_installed";"6"="force_installed";"7"="removed"}[$choice]
                    $params = @{ BrowserName=$BrowserName; ExtensionID=$id; InstallationMode=$mode; Scope=$Scope }
                    if ($mode -in @("normal_installed","force_installed")) {
                        Write-Host "  [1] Microsoft Edge Add-ons"
                        Write-Host "  [2] Chrome Web Store"
                        Write-Host "  [3] URL personnalisee"
                        $sourceChoice = (Read-Host "Source").Trim()
                        switch ($sourceChoice) {
                            "1" { $params.UpdateURL = "https://edge.microsoft.com/extensionwebstorebase/v1/crx" }
                            "2" { $params.UpdateURL = "https://clients2.google.com/service/update2/crx" }
                            "3" { $params.UpdateURL = (Read-Host "URL de mise a jour").Trim() }
                            default { throw "Source invalide." }
                        }
                    }
                    Write-Host "Action preparee : $mode sur $id" -ForegroundColor Cyan
                    $confirm = (Read-Host "Appliquer ? Tapez OUI").Trim()
                    if ($confirm -ceq "OUI") {
                        Set-PSChromiumExtension @params | Format-List
                        Write-Host "Regle ecrite. Rechargez les strategies du navigateur." -ForegroundColor Green
                    } else { Write-Host "Annule." -ForegroundColor Yellow }
                    Read-Host "Entree pour continuer" | Out-Null
                }
                "8" {
                    $id = Read-PSChromiumExtensionID
                    $modes = @{"1"="allowed";"2"="blocked";"3"="normal_installed";"4"="force_installed";"5"="removed"}
                    $modeChoice = Read-PSChromiumChoice -Prompt "Mode" -Choices $modes
                    $params = @{ BrowserName=$BrowserName; ExtensionID=$id; InstallationMode=$modes[$modeChoice]; Scope=$Scope }
                    if ($params.InstallationMode -in @("normal_installed","force_installed")) {
                        $params.UpdateURL = (Read-Host "URL de mise a jour").Trim()
                    }
                    $blockedPermissions = Read-PSChromiumList -Prompt "Permissions bloquees"
                    $allowedHosts = Read-PSChromiumList -Prompt "Hotes autorises"
                    $blockedHosts = Read-PSChromiumList -Prompt "Hotes bloques"
                    $message = Read-Host "Message de blocage (vide pour ignorer)"
                    if ($blockedPermissions) { $params.BlockedPermissions = $blockedPermissions }
                    if ($allowedHosts) { $params.RuntimeAllowedHosts = $allowedHosts }
                    if ($blockedHosts) { $params.RuntimeBlockedHosts = $blockedHosts }
                    if (-not [string]::IsNullOrWhiteSpace($message)) { $params.BlockedInstallMessage = $message }
                    $toolbar = (Read-Host "Toolbar state: force_shown/default_hidden/default_shown (vide pour ignorer)").Trim()
                    if ($toolbar) { $params.ToolbarState = $toolbar }
                    Write-Host "Apercu :" -ForegroundColor Cyan
                    Set-PSChromiumExtension @params -WhatIf
                    $confirm = (Read-Host "Appliquer ? Tapez OUI").Trim()
                    if ($confirm -ceq "OUI") { Set-PSChromiumExtension @params | Format-List }
                    else { Write-Host "Annule." -ForegroundColor Yellow }
                    Read-Host "Entree pour continuer" | Out-Null
                }
                "9" {
                    $id = Read-PSChromiumExtensionID
                    $existing = Get-PSChromiumExtension -BrowserName $BrowserName -ExtensionID $id -Scope $Scope
                    if ($null -eq $existing) { Write-Host "Regle absente." -ForegroundColor Yellow }
                    else {
                        $existing | Format-List
                        $confirm = (Read-Host "Supprimer uniquement cette regle ? Tapez SUPPRIMER").Trim()
                        if ($confirm -ceq "SUPPRIMER") {
                            Remove-PSChromiumExtension -BrowserName $BrowserName -ExtensionID $id -Scope $Scope -Confirm:$false
                            Write-Host "Regle supprimee." -ForegroundColor Green
                        } else { Write-Host "Annule." -ForegroundColor Yellow }
                    }
                    Read-Host "Entree pour continuer" | Out-Null
                }
                "B" {
                    $defaultName = "PSChromium-$($BrowserName -replace ' ','-')-$Scope-$(Get-Date -Format 'yyyyMMdd-HHmmss').reg"
                    $destination = Read-Host "Fichier de sauvegarde [$env:USERPROFILE\Desktop\$defaultName]"
                    if ([string]::IsNullOrWhiteSpace($destination)) { $destination = "$env:USERPROFILE\Desktop\$defaultName" }
                    Backup-PSChromiumExtensionSettings -BrowserName $BrowserName -Scope $Scope -Destination $destination
                    Write-Host "Sauvegarde : $destination" -ForegroundColor Green
                    Read-Host "Entree pour continuer" | Out-Null
                }
                "C" {
                    $browserChoice = Read-PSChromiumChoice -Prompt "Navigateur" -Choices @{"1"="Microsoft Edge";"2"="Google Chrome"}
                    $scopeChoice = Read-PSChromiumChoice -Prompt "Portee" -Choices @{"1"="LocalMachine";"2"="CurrentUser"}
                    $BrowserName = @{"1"="Microsoft Edge";"2"="Google Chrome"}[$browserChoice]
                    $Scope = @{"1"="LocalMachine";"2"="CurrentUser"}[$scopeChoice]
                }
                "Q" { $quit = $true }
                default { Write-Warning "Choix invalide."; Start-Sleep -Milliseconds 700 }
            }
        }
        catch {
            Write-Host "Erreur : $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Entree pour continuer" | Out-Null
        }
    }
}

# Demarrage automatique uniquement lorsque le fichier est execute directement.
# Le dot-sourcing (. .\script.ps1) continue de charger les fonctions sans ouvrir le menu.
if ($MyInvocation.InvocationName -ne '.') {
    Start-PSChromiumExtensionCLI -BrowserName "Microsoft Edge" -Scope "LocalMachine"
}
