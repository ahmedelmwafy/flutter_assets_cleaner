# Flutter Asset Cleaner

A simple command-line tool to identify and remove unused asset files in your Flutter project. It helps you optimize your project by keeping only the necessary assets and reducing your app size.

## Features

- Scans your Flutter project for assets declared in `pubspec.yaml`.
- Identifies assets that are unused by searching through your project files.
- Provides an option to delete unused assets to save space.

## Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_assets_cleaner: ^0.0.8


## Usage

Run the following command to use the package:

```bash
dart run flutter_assets_cleaner
```