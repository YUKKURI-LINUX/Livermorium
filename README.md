Japanese version: [README_ja.md](README_ja.md)

# Livermorium

Livermorium is the custom Linux distribution creation system. We're planning to support various distribution bases (e.g. Debian, Fedora, Arch), but currently, it **only supports Ubuntu-based systems**.

## Installation (for GUI)

```bash
./install.py
```

After executing this script, you can launch Livermorium from the application menu.

## Specifications

This system is designed for create customized Linux distributions based on various basis.

The script execution order strictly follows this order below, and a **numerical rule (00 to 99) in ascending order**: `prelude` (always run first) → **main content** → `finalizers` (always run last).

To control scripts execution order in the GUI, these configurations are defined. :

  * `profiles/<profile>/categories.json`
      * Defines `nodes` (categories/groups), `prelude`, and `finalizers`.
  * `profiles/<profile>/execution.json`
      * Only defines the script execution range running in the chroot directory (`min`/`max`) (default is 50..79) now.

-----

## Directory Structures

```
Livermorium (project root)/
├─ cl_main.py                # Executable script for the CLI version
├─ builder/
│  ├─ executor.py 
│  ├─ categories.py          
│  ├─ logger.py
│  ├─ config_loader.py
│  └─ (etc.)
├─ profiles/
│  └─ ubuntu/
│     ├─ scripts/            # Real scripts (numbered from 00 to 99)
│     │  ├─ (Scripts are executed following numbers ascendingly, so you have to name these script with numbers in the right order.)
│     ├─ categories.json
│     └─ execution.json
└─ work_build/               # Working directory that created automatically in the process. It contains logs, temporary copied scripts, temporary directories, etc.
```

-----

## Example of `categories.json`

```json
{
  "nodes": {
    "base": {
      "desc": "Initial preparation",
      "patterns": ["05-*.sh", "10-*.sh", "30-*.sh", "40-*.sh"]
    },
    "locale": {
      "desc": "Locale / Keyboard settings",
      "deps": ["base"],
      "patterns": ["50-locale.sh", "52-keyboard.sh"]
    },
    "user": {
      "desc": "User and Group setup",
      "deps": ["locale"],
      "patterns": ["60-user.sh"]
    },
    "packages": {
      "desc": "APT/Flatpak installation",
      "deps": ["user"],
      "patterns": ["65-packages.sh"]
    },
    "desktop": {
      "desc": "Desktop settings / Calamares / Services",
      "deps": ["packages"],
      "patterns": ["70-dconf-settings.sh", "71-calamares-install.sh", "75-enable-services.sh", "76-systemd-initramfs.sh"]
    },
    "finalize": {
      "desc": "Post-rootfs copy / Cleanup",
      "deps": ["desktop"],
      "patterns": ["80-copy-rootfs-after.sh", "81-chown-home.sh", "82-purge-hostside.sh"]
    },
    "boot": {
      "desc": "GRUB and EFI/El Torito generation",
      "deps": ["finalize"],
      "patterns": ["84-create-grubcfg.sh", "85-generate-eltorito.sh", "86-generate-efi.sh"]
    },
    "iso": {
      "desc": "Final ISO generation",
      "deps": ["boot"],
      "patterns": ["90-build-iso.sh"]
    },

    "minimal": {
      "desc": "Minimal setup (base + locale)",
      "includes": ["base", "locale"]
    },
    "with-packages": {
      "desc": "Up to package installation",
      "includes": ["minimal", "user", "packages"]
    },
    "full-desktop": {
      "desc": "Full configuration (up to ISO)",
      "includes": ["with-packages", "desktop", "finalize", "boot", "iso"]
    }
  },

  "prelude": {
    "always_first": ["00-*.sh", "00-*.py"]
  },

  "finalizers": {
    "always": ["99-*.sh"],
    "on_failure": [],
    "on_success": []
  }
}
```

-----

## Example of `execution.json`

```json
{
  "chroot": {
    "min": 50,
    "max": 79
  }
}
```

-----

## Usage Examples

### 1. Check Plans

```bash
sudo ./cl_main.py ubuntu --print-plan --dry-run
```

### 2. Run (Full)

```bash
sudo ./cl_main.py ubuntu -r full-desktop
```

### 3. Run (Package Installation)

```bash
sudo ./cl_main.py ubuntu -r with-packages
```

### 4. Run with the Pattern Specifications (Bootloader Configuration)

```bash
sudo ./cl_main.py ubuntu -r "85-*.sh"
```

-----

## Command-Line Options

| Option | Meaning | Example |
|---|---|---|
| `profile` | Profile name (required) | `ubuntu` |
| `-r, --run` | Node name/pattern (comma-separated) | `full-desktop,85-*.sh` |
| `--allow-deprecated` | Allow deprecated nodes from dependencies (globally) | `(no additional options)` |
| `--allow-deprecated-nodes` | Allow only specific nodes (CSV) | `old-desktop,legacy` |
| `--chroot-min` | Chroot minimum script number | `60` |
| `--chroot-max` | Chroot maximum script number | `89` |
| `--print-plan` | Display the execution plan | `(no additional options)` |
| `--validate` | Exit after only validating the plan | `(no additional options)` |
| `--list-only` | Exit after only listing execution targets | `(no additional options)` |
| `--dry-run` | Log commands without execution | `(no additional options)` |
| `--continue-on-error`| Continue execution even on error | `(no additional options)` |
| `--package-list` | Additional APT packages (CSV) | `vim,htop` |
| `--flatpak-list` | Additional Flatpak applications (CSV) | `org.mozilla.firefox,org.gimp.GIMP` |

-----

## Script Execution Rules

  * All scripts are executed sequentially in ascending order by number.
  * `prelude` is always executed in the initial process, and `finalizers` are always executed in the final.
  * `finalizers.on_failure` only runs upon failure; `finalizers.on_success` only runs upon success.
  * All multiple pattern specifications must be **comma-separated**.