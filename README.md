# Flutter Asset Cleaner

A command-line tool to identify and remove unused asset files in your Flutter project. It helps you optimize your application size by detecting assets that are no longer referenced in your codebase.

[![pub package](https://img.shields.io/pub/v/flutter_assets_cleaner.svg)](https://pub.dev/packages/flutter_assets_cleaner)

---

## ✨ Features

- **Code Reference Detection:** Analyzes `.dart` files in your `lib` directory to match asset paths, filenames, or extensionless basenames against string literals in your code.
- **Localization Protection:** Excludes non-empty `.json` files by default (commonly used for `easy_localization` or `flutter_localizations`), preventing accidental deletion of localization files.
- **Hierarchical Tree Output:** Visualizes unused assets and protected/excluded files in a clean tree structure.
- **Interactive Filtering:** Choose which assets to keep before confirming deletion via an interactive prompt.
- **Dry-Run Mode:** Preview exactly which assets would be deleted without making any changes (`--dry-run`).
- **Disk Space Recovered:** Calculates and reports total disk space saved after cleanup.

---

## 🚀 Installation

### Global Installation (Recommended for CLI use)

Activate the package globally to run `flutter_assets_cleaner` from anywhere:

```bash
dart pub global activate flutter_assets_cleaner
```

### Local Dev Dependency

Alternatively, add `flutter_assets_cleaner` to your `pubspec.yaml` under `dev_dependencies`:

```yaml
dev_dependencies:
  flutter_assets_cleaner: ^0.0.11
```

Then install dependencies:

```bash
flutter pub get
```

---

## 💡 Usage

Navigate to your Flutter project root directory and run:

### Global Command
```bash
flutter_assets_cleaner
```

### Or using Dart Run
```bash
dart run flutter_assets_cleaner
```

---

## 🛠️ CLI Options & Flags

| Flag | Short | Description |
| --- | --- | --- |
| `--dry-run` | `-d` | Perform a dry run without deleting any files. Highly recommended for initial checks. |
| `--skip-interactive` | `-y` | Automatically delete unused assets, skipping interactive prompts. |
| `--include-json` | `-j` | Include non-empty `.json` files in the scan (by default, JSON files are excluded). |
| `--help` | `-h` | Display usage instructions and flag information. |

### Examples

**Run a non-destructive dry-run check:**
```bash
dart run flutter_assets_cleaner --dry-run
```

**Include JSON files in scan:**
```bash
dart run flutter_assets_cleaner --include-json
```

**Automatically clean unused assets (for CI/CD or fast cleanup):**
```bash
dart run flutter_assets_cleaner --skip-interactive
```

---

## 📖 How It Works

1. **Scans Assets Directory:** Finds all asset files inside your project's `assets/` directory (excluding hidden files).
2. **Scans Dart Codebase:** Searches `.dart` files within `lib/` for string references matching asset filenames or paths.
3. **Applies Safety Rules:** Automatically filters out JSON localization files unless `--include-json` is specified.
4. **Interactive Review:** Presents unused assets in a tree view and allows you to uncheck/keep any assets.
5. **Clean & Summary:** Removes selected assets upon confirmation and prints the total disk space freed.
