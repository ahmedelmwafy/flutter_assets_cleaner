// bin/flutter_asset_cleaner.dart

import 'dart:developer';
import 'dart:io';
import 'package:path/path.dart' as p;

final projectRoot = Directory.current.path;
final pubspecPath = p.join(projectRoot, 'pubspec.yaml');
final libDir = Directory(p.join(projectRoot, 'lib'));

Future<void> main() async {
  print('🔍 Checking asset usage in Flutter project...');

  final assets = extractAssetsFromPubspec();
  if (assets.isEmpty) {
    print('No assets found in pubspec.yaml');
    return;
  }

  print('\nFound ${assets.length} asset files declared in pubspec.yaml');
  final results = findAssetReferencesInCode(assets);
  displayResults(results);

  if (results['unused']!.isNotEmpty) {
    print('\n💡 Tip: Consider removing unused assets to reduce app size.');
    print('\n🧹 Deleting unused assets...');
    deleteUnusedAssets(results['unused']!);
  } else {
    print('\n🎉 All assets are used. Nothing to delete!');
  }
}

List<String> extractAssetsFromPubspec() {
  final pubspec = File(pubspecPath);
  if (!pubspec.existsSync()) {
    print('❌ pubspec.yaml not found');
    return [];
  }

  final content = pubspec.readAsStringSync();
  final assetRegex = RegExp(r'assets:\s*((?:\s+-\s+.+\n)+)', multiLine: true);
  final match = assetRegex.firstMatch(content);
  if (match == null) return [];

  final assetLines =
      match
          .group(1)!
          .split('\n')
          .where((line) => line.trim().startsWith('-'))
          .map(
            (line) => line
                .trim()
                .substring(1)
                .trim()
                .replaceAll("'", '')
                .replaceAll('"', ''),
          )
          .toList();

  final assets = <String>[];

  for (var declaration in assetLines) {
    final fullPath = p.join(projectRoot, declaration);
    final file = File(fullPath);
    final dir = Directory(fullPath);

    if (file.existsSync()) {
      assets.add(
        p.relative(file.path, from: projectRoot).replaceAll('\\', '/'),
      );
    } else if (dir.existsSync()) {
      final files = getFilesRecursively(dir);
      for (var f in files) {
        assets.add(p.relative(f.path, from: projectRoot).replaceAll('\\', '/'));
      }
    } else {
      print('⚠️ Could not access asset "$declaration"');
    }
  }

  return assets;
}

List<File> getFilesRecursively(Directory dir) {
  final files = <File>[];
  for (var entity in dir.listSync(recursive: true)) {
    if (entity is File) files.add(entity);
  }
  return files;
}

Map<String, dynamic> findAssetReferencesInCode(List<String> assetPaths) {
  final usedAssets = <String>{};
  final unusedAssets = Set<String>.from(assetPaths);
  final references = <String, List<Map<String, dynamic>>>{};

  void checkFile(File file) {
    final content = file.readAsLinesSync();
    final relativePath = p.relative(file.path, from: projectRoot);

    for (var asset in assetPaths) {
      if (usedAssets.contains(asset)) continue;

      final normalizedAsset = asset.replaceFirst('assets/', '');
      final base = p.basename(asset);
      final baseNoExt = p.basenameWithoutExtension(asset);

      final patterns = [
        "'${normalizedAsset}'",
        '"${normalizedAsset}"',
        "'${base}'",
        '"${base}"',
        baseNoExt,
      ];

      for (var i = 0; i < content.length; i++) {
        for (var pattern in patterns) {
          if (content[i].contains(pattern)) {
            usedAssets.add(asset);
            unusedAssets.remove(asset);

            references.putIfAbsent(asset, () => []);
            references[asset]!.add({
              'file': relativePath,
              'line': i + 1,
              'code': content[i].trim(),
            });
            break;
          }
        }
      }
    }
  }

  void traverse(Directory dir) {
    for (var entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        checkFile(entity);
      }
    }
  }

  traverse(libDir);

  return {
    'used': usedAssets.toList()..sort(),
    'unused': unusedAssets.toList()..sort(),
    'references': references,
  };
}

void displayResults(Map<String, dynamic> results) {
  final used = results['used'] as List<String>;
  final unused = results['unused'] as List<String>;
  final references =
      results['references'] as Map<String, List<Map<String, dynamic>>>;

  print('\n✅ Used assets:');
  for (var asset in used) {
    print('- $asset');
    if (references[asset] != null) {
      for (var ref in references[asset]!) {
        print('  ↳ Used in ${ref['file']}:${ref['line']}');
        print('    ${ref['code']}');
      }
    }
  }

  print('\n❌ Unused assets:');
  for (var asset in unused) {
    print('- $asset');
  }

  final total = used.length + unused.length;
  print('\n📊 Summary:');
  print('- Total assets: $total');
  print('- Used: ${used.length} (${(used.length / total * 100).round()}%)');
  print(
    '- Unused: ${unused.length} (${(unused.length / total * 100).round()}%)',
  );
}

void deleteUnusedAssets(List<String> unusedAssets) {
  for (var asset in unusedAssets) {
    final file = File(p.join(projectRoot, asset));
    try {
      file.deleteSync();
      print('🗑️ Deleted: $asset');
    } catch (e) {
      print('⚠️ Could not delete "$asset": $e');
    }
  }
}
