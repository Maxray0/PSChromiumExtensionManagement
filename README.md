# PSChromium Extension Policy CLI

[Français](README_FR.md) | **English**

Interactive PowerShell CLI for reading and managing Microsoft Edge and Google Chrome `ExtensionSettings` policies on Windows.

This project is based on [PSChromiumExtensionManagement](https://github.com/KopterBuzz/PSChromiumExtensionManagement) by Gabor Nemeth. It adapts the original implementation to a Windows Registry layout that uses one subkey per extension.

> [!WARNING]
> This script modifies browser policies in the Windows Registry. Use it only on devices you are authorized to administer. Local settings can conflict with GPO, Intune, MDM, or cloud-managed policies.

## Features

- Interactive command-line interface with automatic startup when the `.ps1` file is executed directly.
- Microsoft Edge and Google Chrome targets.
- `LocalMachine` (`HKLM`) and `CurrentUser` (`HKCU`) scopes.
- Lists all existing `ExtensionSettings` rules.
- Shows a single extension policy by ID.
- Adds or updates individual extension rules.
- Supports `allowed`, `blocked`, `normal_installed`, `force_installed`, and `removed`.
- Preset update sources for Microsoft Edge Add-ons and Chrome Web Store.
- Custom update URL support.
- Advanced settings for permissions, allowed and blocked hosts, blocked-install messages, and toolbar state.
- Targeted policy-rule removal without deleting unrelated extension rules.
- Registry backup to `.reg` files.
- `-WhatIf` support and explicit confirmation prompts.
- Dot-sourcing support to load functions without opening the CLI.

## Changes from the original script

The original script reads and writes one JSON value named `ExtensionSettings` under the browser policy key:

```text
HKLM:\SOFTWARE\Policies\Microsoft\Edge
└── ExtensionSettings = "{ ... JSON ... }"
```

This version uses one Registry subkey per extension:

```text
HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionSettings
├── <ExtensionID-1>
│   ├── installation_mode
│   ├── update_url
│   └── ...
└── <ExtensionID-2>
    └── installation_mode
```

| Area | Original script | This version |
|---|---|---|
| Storage | One global JSON value | One Registry subkey per extension ID |
| Interface | PowerShell functions | Functions plus an interactive CLI |
| Startup | Manual invocation | Automatic CLI startup when executed directly |
| Reading | In-memory JSON state | Direct Registry-subkey enumeration |
| Writing | Rewrites the shared JSON | Updates only the selected extension subkey |
| Removal | Removes a JSON property | Removes only the selected extension subkey |
| Safety | No integrated preview | `-WhatIf`, confirmations, and `.reg` backup |
| Optional properties | Direct access could fail | Checks existence before display |
| Scope | Static browser paths | CLI switching between machine and user scope |
| Language | English | Separate English and French versions |

Additional fixes and improvements:

- fixes the observed `Get-Iitem` typo;
- uses `toolbar_state` instead of `toolbar_pin`;
- validates 32-character Chromium extension IDs with letters `a` through `p`;
- requires `update_url` for `normal_installed` and `force_installed`;
- rejects automatic installation modes at the global `*` scope;
- preserves properties that are not changed on an existing rule;
- safely handles optional properties such as `update_url` under `Set-StrictMode`.

## Requirements

- Windows.
- Windows PowerShell 5.1 or PowerShell 7.
- Microsoft Edge or Google Chrome.
- An elevated terminal for `LocalMachine` changes.
- Authorization to modify browser policies on the device.

## Installation and startup

Run the English script directly to load the functions and open the CLI:

```powershell
.\PSChromiumExtensionManagement.CLI.AutoStart.EN.ps1
```

Dot-source it to load the functions without opening the menu:

```powershell
. "$PWD\PSChromiumExtensionManagement.CLI.AutoStart.EN.ps1"
```

Start the CLI manually when the functions are already loaded:

```powershell
Start-PSChromiumExtensionCLI -BrowserName "Microsoft Edge" -Scope LocalMachine
```

## CLI menu

```text
[1] List policies
[2] Show one extension
[3] Allow an extension
[4] Block an extension
[5] Install automatically (user can disable)
[6] Force installation
[7] Mark an extension as removed
[8] Advanced editing
[9] Remove a policy rule
[B] Back up policies
[C] Change browser or scope
[Q] Quit
```

## Installation modes

| Mode | Effect |
|---|---|
| `allowed` | The user can install the extension manually. |
| `blocked` | The extension cannot be installed. |
| `normal_installed` | The browser installs the extension automatically. The user can disable it, but it remains policy-managed. |
| `force_installed` | The browser installs the extension automatically. The user cannot disable or remove it. |
| `removed` | The browser removes the extension and prevents installation while the rule remains active. |

> [!NOTE]
> In Microsoft Edge testing, removing a `normal_installed` rule and fully restarting the browser automatically uninstalled the managed extension.

## PowerShell examples

### List policies

```powershell
Get-PSChromiumExtension -BrowserName "Microsoft Edge" -ExtensionID "All" -Scope LocalMachine
```

### Allow an extension

```powershell
Set-PSChromiumExtension -BrowserName "Microsoft Edge" -ExtensionID "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" -InstallationMode allowed -Scope LocalMachine
```

### Install from Chrome Web Store

```powershell
Set-PSChromiumExtension `
    -BrowserName "Microsoft Edge" `
    -ExtensionID "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" `
    -InstallationMode normal_installed `
    -UpdateURL "https://clients2.google.com/service/update2/crx" `
    -Scope LocalMachine
```

### Preview a change

```powershell
Set-PSChromiumExtension -BrowserName "Microsoft Edge" -ExtensionID "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" -InstallationMode allowed -Scope LocalMachine -WhatIf
```

### Remove one policy rule

```powershell
Remove-PSChromiumExtension -BrowserName "Microsoft Edge" -ExtensionID "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" -Scope LocalMachine -Confirm
```

## Backup and restore

Create a backup from option **B**, or run:

```powershell
Backup-PSChromiumExtensionSettings `
    -BrowserName "Microsoft Edge" `
    -Scope LocalMachine `
    -Destination "$env:USERPROFILE\Desktop\Edge-ExtensionSettings-backup.reg"
```

Review the file before restoring it. Close the browser, then import the backup only if you are authorized to restore these policies:

```powershell
reg.exe import "$env:USERPROFILE\Desktop\Edge-ExtensionSettings-backup.reg"
```

## Validation

For Microsoft Edge:

1. Open `edge://policy`.
2. Reload policies or fully restart Edge.
3. Verify the `ExtensionSettings` entry and its status.
4. Open `edge://extensions` to verify the actual extension state.
5. Confirm that unrelated rules are still present.

For Google Chrome, use `chrome://policy` and `chrome://extensions`.

## Tested behavior

Validated on Microsoft Edge with `LocalMachine` scope:

- automatic CLI startup;
- listing existing policy rules;
- safe display of rules without `update_url`;
- adding an `allowed` rule;
- targeted policy-rule removal;
- preservation of unrelated rules;
- `normal_installed` deployment from Chrome Web Store;
- extension installation after restarting Edge;
- automatic extension uninstall after removing its `normal_installed` rule and restarting Edge.

Implemented but not yet claimed as validated by these tests:

- Google Chrome target;
- `CurrentUser` scope;
- `force_installed`, `blocked`, and `removed` enforcement;
- advanced permission and host settings;
- backup restoration;
- custom update URLs;
- global `*` scope;
- PowerShell 7 execution.

## Limitations and precautions

- Extensions installed with `normal_installed` or `force_installed` appear as organization-managed.
- A local rule can be overwritten by or conflict with GPO, Intune, MDM, or cloud policy.
- `ExtensionSettings` can override other extension policies.
- The script does not assess extension reputation, permissions, or security.
- The script does not download extensions itself. The browser uses the configured `update_url`.
- An incorrect global `*` rule can affect all extensions. Prefer individual extension IDs.
- Back up policies and verify Registry paths before making changes.

## License and attribution

This project is derived from [PSChromiumExtensionManagement](https://github.com/KopterBuzz/PSChromiumExtensionManagement), created by Gabor Nemeth in 2025 and released under the GPL-3.0 license.

Keep the following in your repository:

- the GPL-3.0 `LICENSE` file;
- attribution to the original author;
- a clear description of your changes;
- source code for distributed versions, in accordance with applicable license obligations.

## References

- [Microsoft Edge ExtensionSettings guide](https://learn.microsoft.com/deployedge/microsoft-edge-manage-extensions-ref-guide)
- [Original PSChromiumExtensionManagement project](https://github.com/KopterBuzz/PSChromiumExtensionManagement)
