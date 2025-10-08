# Livermorium System Description (English Translation)

Japanese
[README_ja.md](README_ja.md)

## Livermorium

Livermorium is a **custom distribution creation system** executable via both **GUI and CLI**. We aim to support various distribution bases, but currently, it **only supports Ubuntu-based systems**.

## Execution Instructions

### 1\. Environment Setup

```bash
./install.py
```

### 2\. GUI Execution

The application can be launched directly as an **ICON** has been added to your environment.

### 3\. CLI Execution

Refer to the usage section described below for command-line instructions.


## Implemented Specifications

This system is a **build environment that generates custom ISOs** for various distribution bases.

The execution order strictly follows a **numerical rule (00 to 99) in ascending order**: `prelude` (always run first) → **main content** → `finalizers` (always run last).

To support GUI execution, we separate the execution plan into **Category/Group Definitions** and **Execution Control**.

  * **Execution Plan (Logical):** `profiles/<profile>/categories.json`
      * Defines `nodes` (categories/groups), `prelude`, and `finalizers`.
  * **Execution Method (Physical):** `profiles/<profile>/execution.json`
      * Only defines the chroot execution range (`min`/`max`) (default is 50..79).

-----

## 1\. Key Directories

```
Livermorium/
├─ cl_main.py                # Command-Line Orchestration Entry Point
├─ builder/
│  ├─ executor.py            # Executes prelude→main→finalizers in numerical order (respecting chroot range)
│  ├─ categories.py          # Loading/Normalization/Node Resolution for categories.json
│  ├─ logger.py              # Sequential Log Writer
│  ├─ config_loader.py       # Config, package/flatpak list Loader
│  └─ … (existing)
├─ profiles/
│  └─ ubuntu/
│     ├─ scripts/            # Actual Scripts (00 to 99)
│     │  ├─ Scripts to be executed should be prepared with numerical prefixes
│     ├─ categories.json     # Execution Logic (including prelude/finalizers)
│     └─ execution.json      # Chroot Execution Range (min/max only)
└─ work_build/               # Generated during execution (logs, scripts, <basename>/tmp, etc.)
```

-----

## 2\. `categories.json` (Example Definition)

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

## 3\. `execution.json` (Example Definition)

```json
{
  "chroot": {
    "min": 50,
    "max": 79
  }
}
```

-----

## 4\. Usage Examples

### 4.1 Plan Check

```bash
sudo ./cl_main.py ubuntu --print-plan --dry-run
```

### 4.2 Full Configuration

```bash
sudo ./cl_main.py ubuntu -r full-desktop
```

### 4.3 Up to Package Installation

```bash
sudo ./cl_main.py ubuntu -r with-packages
```

### 4.4 Only Boot Processing (Pattern Specification)

```bash
sudo ./cl_main.py ubuntu -r "85-*.sh"
```

-----

## 5\. Command-Line Options List

| Option | Meaning | Example |
|---|---|---|
| `profile` | Profile name (required) | `ubuntu` |
| `-r, --run` | Node name/pattern (comma-separated) | `full-desktop,85-*.sh` |
| `--allow-deprecated` | Allow deprecated nodes from dependencies (globally) | |
| `--allow-deprecated-nodes` | Allow only specific nodes (CSV) | `old-desktop,legacy` |
| `--chroot-min` | Chroot minimum script number | `60` |
| `--chroot-max` | Chroot maximum script number | `89` |
| `--print-plan` | Display the execution plan | |
| `--validate` | Exit after only validating the plan | |
| `--list-only` | Exit after only listing execution targets | |
| `--dry-run` | Log commands without execution | |
| `--continue-on-error`| Continue execution even on error | |
| `--package-list` | Additional APT packages (CSV) | `vim,htop` |
| `--flatpak-list` | Additional Flatpak applications (CSV) | `org.mozilla.firefox,org.gimp.GIMP` |

-----

## 6\. Execution Rules

  * **Ascending numerical order** is the absolute rule.
  * `prelude` is always at the start, and `finalizers` are always at the end.
  * `finalizers.on_failure` runs only upon failure; `finalizers.on_success` runs only upon success.
  * All multiple specifications must be **comma-separated**.