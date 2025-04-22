# Flutter Asset Cleaner

A simple command-line tool to identify and remove unused asset files in your Flutter project. It helps you optimize your project by keeping only the necessary assets and reducing your app size.

## Features
* **Full Assets Scan:** Scans your entire `assets` directory recursively to find all asset files (excluding hidden files like `.DS_Store`).
* **Code Reference Check:** Analyzes `.dart` files in your `lib` directory to find string literals. It marks an asset as potentially used if its full path, filename, or basename without extension appears as a substring within any string literal in your code.
* **Localization Exclusion:** Automatically excludes non-empty `.json` files (commonly used for localization) from the list of assets recommended for deletion, as they are often used indirectly.
* **Tree View Output:** Displays the assets marked for deletion and those excluded in a clear, hierarchical tree format.
* **Interactive Filtering:** Allows you to interactively specify which files you want to *keep* (remove from the deletion list) by selecting from a numbered list before confirming deletion.
* **Dry Run Mode:** Lets you see exactly which files would be deleted without actually deleting them (`--dry-run`). Highly recommended for testing!
* **Deletion Option:** Provides a confirmed option to delete the assets that remain on the deletion list after filtering.
* **Space Freed Calculation:** Reports the estimated disk space recovered after deletion.
* **Pubspec Info (Optional):** Includes an informational section comparing assets declared in `pubspec.yaml` with those found and used.

## Getting Started

To get started with the Flutter Asset Cleaner, follow these steps:

1. Add the `flutter_assets_cleaner` package to your `pubspec.yaml` file as shown above.
2. Run the command to start the asset cleaning process, and follow the on-screen instructions.
3. Follow the prompts to review the assets found, choose which ones to keep,
and confirm the deletion of unused assets.
4. Review the generated report to understand which assets are unused and make informed decisions before deletion.
5. confirm to delete by press y then enter

## Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_assets_cleaner: ^0.0.9


## Usage

Run the following command to use the package:
dart run flutter_assets_cleaner

```