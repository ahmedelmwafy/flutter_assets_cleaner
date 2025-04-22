import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:args/args.dart';
import 'dart:collection'; // Import for SplayTreeMap

final projectRoot = Directory.current.path;
final pubspecPath = p.join(projectRoot, 'pubspec.yaml');
final libDir = Directory(p.join(projectRoot, 'lib'));
final assetsDir = Directory(p.join(projectRoot, 'assets'));
final ignoredDirs = ['test', 'build']; // Folders to ignore during code search

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('dry-run', abbr: 'd', defaultsTo: false, help: 'Perform a dry run without deleting files.');

  ArgResults argResults = parser.parse(arguments);
  final isDryRun = argResults['dry-run'] as bool;

  print('🔍 Checking asset usage in Flutter project...');
  print('🚀 Dry Run Mode: ${isDryRun ? 'Enabled' : 'Disabled'}');

  if (!assetsDir.existsSync()) {
    print('❌ Assets directory not found at ${assetsDir.path}');
    return;
  }

  final allAssetFiles = findAllFilesInAssets(assetsDir);
  if (allAssetFiles.isEmpty) {
    print('No files found in the assets directory (excluding hidden files).');
    return;
  }
  print('\nFound ${allAssetFiles.length} files in the assets directory.');

  final allNormalizedLiterals = findAllStringLiteralsInCode(libDir, projectRoot);
  print('Found ${allNormalizedLiterals.length} string literals in the code.');

  final usedAssetPaths = <String>{};
  for (final assetPath in allAssetFiles) {
    final filename = p.basename(assetPath);
    final basenameWithoutExtension = p.basenameWithoutExtension(assetPath);

    final potentialReferences = [
      assetPath,
      filename,
      basenameWithoutExtension,
    ];

    final isUsed = allNormalizedLiterals.any((literal) {
      return potentialReferences.any((ref) => literal.contains(ref));
    });

    if (isUsed) {
      usedAssetPaths.add(assetPath);
    }
  }

  final potentialUnusedPaths = allAssetFiles.difference(usedAssetPaths).toList()..sort();
  List<String> unusedAssetsForDeletion = <String>[]; // Use List for indexing
  final localizationAssetsExcluded = <String>[];

  for (final assetPath in potentialUnusedPaths) {
      final file = File(p.join(projectRoot, assetPath));
      bool isJson = assetPath.toLowerCase().endsWith('.json');
      bool isNonEmpty = false;
      try {
          if (file.existsSync()) {
              isNonEmpty = file.lengthSync() > 0;
          }
      } catch (e) {
           print('⚠️ Could not check size of "$assetPath": $e');
           isJson = false;
      }

      if (isJson && isNonEmpty) {
          localizationAssetsExcluded.add(assetPath);
      } else {
          unusedAssetsForDeletion.add(assetPath);
      }
  }

  final unusedTree = buildTree(unusedAssetsForDeletion);
  final excludedTree = buildTree(localizationAssetsExcluded);

  displayResults(allAssetFiles, usedAssetPaths.toList(), unusedTree, excludedTree);

  // --- Modified Interactive Unselection Logic (Removing from list) ---
  List<String> filesToRemoveFromDeletion = []; // List to hold files the user wants to keep

  if (unusedAssetsForDeletion.isNotEmpty && !isDryRun) {
      print('\n--- Select Assets to Keep (Remove from Deletion List) ---');
      print('The following assets are currently marked for deletion:');

      for (var i = 0; i < unusedAssetsForDeletion.length; i++) {
          print('${i + 1}. ${unusedAssetsForDeletion[i]}');
      }

      print('\nEnter a comma-separated list of numbers you wish to REMOVE from the deletion list (e.g., 1, 5, 8)');
      print('Press Enter without typing numbers to delete ALL ${unusedAssetsForDeletion.length} listed assets.');
      stdout.write('Selection to REMOVE from deletion: ');

      String? userInput = stdin.readLineSync();
      print('');

      if (userInput != null && userInput.trim().isNotEmpty) {
          final numbersToRemove = <int>{};
          final parts = userInput.split(',');
          bool inputError = false;

          for (var part in parts) {
              final trimmedPart = part.trim();
              if (trimmedPart.isEmpty) continue;

              try {
                  final number = int.parse(trimmedPart);
                  if (number >= 1 && number <= unusedAssetsForDeletion.length) {
                      numbersToRemove.add(number);
                  } else {
                      print('⚠️ Invalid number: $number is out of range (1-${unusedAssetsForDeletion.length}).');
                      inputError = true;
                  }
              } catch (e) {
                  print('⚠️ Invalid input: "$trimmedPart" is not a valid number.');
                  inputError = true;
              }
          }

          if (!inputError) {
               // Populate filesToRemoveFromDeletion based on the numbers provided
              for (var number in numbersToRemove) {
                  filesToRemoveFromDeletion.add(unusedAssetsForDeletion[number - 1]);
              }
              print('${filesToRemoveFromDeletion.length} asset(s) will be removed from the deletion list.');

          } else {
              print('❌ Due to input errors, no changes will be made to the deletion list.');
              // If input errors, filesToRemoveFromDeletion remains empty, so original list is targeted
          }
      } else {
          print('👍 No selection entered. Proceeding to delete ALL ${unusedAssetsForDeletion.length} listed assets.');
          filesToRemoveFromDeletion = []; // Empty list means nothing is removed from deletion
      }
       print('--- End Selection ---');
  }

  // Determine the final list to delete by removing selected items from the original list
  List<String> filesToActuallyDelete = unusedAssetsForDeletion
      .where((asset) => !filesToRemoveFromDeletion.contains(asset))
      .toList();


  if (filesToActuallyDelete.isNotEmpty) {
    if (isDryRun) {
      print('\n--- Dry Run ---');
      print('The following ${filesToActuallyDelete.length} files would have been deleted after selection (see tree above for original list):');
       if (filesToActuallyDelete.length < 20) {
          for (var asset in filesToActuallyDelete) {
             print('- $asset');
          }
       } else {
           print('(List is long, referring to summary count)');
       }
      print('--- Dry Run Complete ---');
    } else {
      print('\nFINAL CONFIRMATION: You are about to delete ${filesToActuallyDelete.length} asset(s).');
      stdout.write('Proceed with deletion? (Y/N): ');
       String? finalConfirm = stdin.readLineSync();

       if (finalConfirm != null && finalConfirm.toLowerCase() == 'y') {
          print('\n🧹 Deleting ${filesToActuallyDelete.length} assets...');
          final freedSpace = await deleteUnusedAssets(filesToActuallyDelete);
          print('🎉 You have freed up ${freedSpace.toStringAsFixed(2)} MB of space.');
       } else {
           print('\n❌ Deletion cancelled by user.');
       }
    }
  } else if (unusedAssetsForDeletion.isNotEmpty && !isDryRun) {
     // This case happens if the user selected all files to be removed from deletion
     print('\n✅ No assets remain for deletion after selection.');
  } else if (allAssetFiles.isNotEmpty && potentialUnusedPaths.isEmpty) {
     // Already printed the "All files used" message
  } else if (allAssetFiles.isNotEmpty && potentialUnusedPaths.isNotEmpty && unusedAssetsForDeletion.isEmpty) {
      // Already printed the "All potentially unused excluded" message
  }


  final declaredAssetsInPubspec = extractAssetsFromPubspec();
  if (declaredAssetsInPubspec.isNotEmpty) {
     final unusedDeclaredAssets = declaredAssetsInPubspec.where(
        (assetPath) => !usedAssetPaths.contains(assetPath)
     ).toList()..sort();
     print('\n--- Pubspec.yaml Info ---');
     print('Found ${declaredAssetsInPubspec.length} assets declared in pubspec.yaml');
     if (unusedDeclaredAssets.isNotEmpty) {
        print('${unusedDeclaredAssets.length} declared assets were found in assets/ but not referenced in code (these might be in the excluded/unused trees above):');
        for (var asset in unusedDeclaredAssets) {
           print('- $asset');
        }
     } else {
        print('All declared assets in pubspec.yaml appear to be referenced.');
     }
      final undeclaredUsedAssets = usedAssetPaths.where(
          (assetPath) => !declaredAssetsInPubspec.contains(assetPath)
      ).toList()..sort();
      if (undeclaredUsedAssets.isNotEmpty) {
          print('${undeclaredUsedAssets.length} files in assets/ were used but *not* declared in pubspec.yaml:');
          for (var asset in undeclaredUsedAssets) {
              print('- $asset');
          }
          print('💡 Tip: Consider declaring used assets in pubspec.yaml under the `assets:` section.');
      }
      print('-------------------------');
  }
}

Map<String, dynamic> buildTree(List<String> paths) {
  Map<String, dynamic> root = SplayTreeMap<String, dynamic>();
  for (var path in paths) {
    final parts = p.split(path);
    Map<String, dynamic> currentNode = root;
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (i == parts.length - 1) {
        currentNode[part] = true;
      } else {
        currentNode.putIfAbsent(part, () => SplayTreeMap<String, dynamic>());
        currentNode = currentNode[part];
      }
    }
  }
  return root;
}

void printTree(Map<String, dynamic> node, String prefix, bool isLast) {
  final keys = node.keys.toList();
  for (var i = 0; i < keys.length; i++) {
    final key = keys[i];
    final isLastEntry = (i == keys.length - 1);
    final entityPrefix = isLastEntry ? '└── ' : '├── ';
    final childPrefix = prefix + (isLast ? '    ' : '│   ');
    print('$prefix$entityPrefix$key');
    if (node[key] is Map) {
      printTree(node[key], childPrefix, isLastEntry);
    }
  }
}

int countFilesInTree(Map<String, dynamic> node) {
    int count = 0;
    for (final key in node.keys) {
        if (node[key] is Map) {
            count += countFilesInTree(node[key]);
        } else {
            count++;
        }
    }
    return count;
}

Set<String> findAllFilesInAssets(Directory dir) {
  final files = <String>{};
  if (!dir.existsSync()) return files;
  try {
    for (var entity in dir.listSync(recursive: true)) {
      if (entity is File) {
        if (!p.basename(entity.path).startsWith('.')) {
           files.add(p.relative(entity.path, from: projectRoot).replaceAll('\\', '/'));
        }
      }
    }
  } catch (e) {
    print('⚠️ Error listing files in ${dir.path}: $e');
  }
  return files;
}

Set<String> findAllStringLiteralsInCode(Directory dir, String projectRoot) {
  final allNormalizedLiterals = <String>{};
  final stringLiteralRegex = RegExp(
      '\'(?:[^\\\'\\\\]|\\\\.)*\\\'|\\"(?:[^\\"\\\\]|\\\\.)*\\"|r\'[^\\\']*\\\'|r"[^\\"]*\\""',
      multiLine: true
  );
  void checkFile(File file) {
    try {
      final content = file.readAsStringSync();
      final matches = stringLiteralRegex.allMatches(content);
      for (var match in matches) {
        String literal = match.group(0)!;
        String? normalized = normalizeStringLiteral(literal);
        if (normalized != null && normalized.isNotEmpty) {
           allNormalizedLiterals.add(normalized);
        }
      }
    } catch (e) {
      print('⚠️ Error reading file ${file.path}: $e');
    }
  }
  if (dir.existsSync()) {
    try {
      for (var entity in dir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart') && !shouldIgnore(entity)) {
          checkFile(entity);
        }
      }
    } catch (e) {
       print('⚠️ Error traversing directory ${dir.path}: $e');
    }
  } else {
     print('⚠️ Lib directory not found at ${dir.path}');
  }
  return allNormalizedLiterals;
}

String? normalizeStringLiteral(String literal) {
  if (literal.isEmpty) return null;
  String? content;
  if (literal.startsWith('r')) {
    if (literal.length >= 3) {
       content = literal.substring(2, literal.length - 1);
    }
  }
  else if ((literal.startsWith("'") && literal.endsWith("'")) ||
      (literal.startsWith('"') && literal.endsWith('"'))) {
     if (literal.length >= 2) {
       content = literal.substring(1, literal.length - 1);
     }
  }
  return content?.trim();
}

bool shouldIgnore(File file) {
  final filePath = file.path.replaceAll('\\', '/');
  final rootPath = projectRoot.replaceAll('\\', '/');
  return ignoredDirs.any((dir) {
    final ignoredPath = p.join(rootPath, dir).replaceAll('\\', '/');
    return filePath.contains(ignoredPath);
  });
}

void displayResults(
    Set<String> allAssets,
    List<String> usedAssets,
    Map<String, dynamic> unusedTree,
    Map<String, dynamic> excludedTree) {

  print('\n--- Asset Usage Analysis ---');
  print('\n✅ Potentially Used assets (Found in assets/ and path/name found as substring in code strings):');
  if (usedAssets.isNotEmpty) {
    for (var asset in usedAssets) {
      print('- $asset');
    }
  } else {
    print('  None found.');
  }
  print('\n➡️ Excluded assets (Found in assets/ and appear unused, but are non-empty JSON files):');
   if (excludedTree.isNotEmpty) {
     printTree(excludedTree, '', true);
   } else {
     print('  None found.');
   }
  print('\n❌ Unused assets MARKED FOR DELETION:');
  int totalUnusedForDeletion = countFilesInTree(unusedTree);
  if (totalUnusedForDeletion > 0) {
     print('(${totalUnusedForDeletion} files listed below)');
     printTree(unusedTree, '', true);
  } else {
    print('  None found. 🎉');
  }
  final totalAssetsInDir = allAssets.length;
  final totalUsedAssets = usedAssets.length;
  int totalLocalizationExcluded = countFilesInTree(excludedTree);
  final totalUnused = totalUnusedForDeletion + totalLocalizationExcluded;
  print('\n📊 Summary:');
  print('- Total files found in assets/ directory (excluding hidden): $totalAssetsInDir');
  print('- Files in assets/ potentially referenced in code: $totalUsedAssets');
  print('- Files in assets/ appearing unused (Total): $totalUnused');
  print('  - Excluded (e.g., non-empty JSON): ${totalLocalizationExcluded}');
  print('  - Marked for deletion: ${totalUnusedForDeletion}');
  if (totalAssetsInDir > 0) {
     print('- Percentage used: ${((totalUsedAssets / totalAssetsInDir) * 100).toStringAsFixed(2)}%');
     print('- Percentage unused (for deletion): ${((totalUnusedForDeletion / totalAssetsInDir) * 100).toStringAsFixed(2)}%');
  }
   print('---------------------------');
}

Future<double> deleteUnusedAssets(List<String> unusedAssets) async {
  double totalSizeMB = 0;
  for (var assetRelativePath in unusedAssets) {
    final file = File(p.join(projectRoot, assetRelativePath));
    if (!file.existsSync()) {
       print('⚠️ File not found, skipping deletion: "$assetRelativePath"');
       continue;
    }
    try {
      final fileSize = await file.length();
      totalSizeMB += fileSize / (1024 * 1024);
      await file.delete();
      print('🗑️ Deleted: $assetRelativePath');
    } catch (e) {
      print('⚠️ Could not delete "$assetRelativePath": $e');
    }
  }
  return totalSizeMB;
}

List<String> extractAssetsFromPubspec() {
  final pubspec = File(pubspecPath);
  if (!pubspec.existsSync()) {
    return [];
  }
  final content = pubspec.readAsStringSync();
  final assetRegex = RegExp(r'assets:\s*((?:\s+-\s+.+\n)+)', multiLine: true);
  final match = assetRegex.firstMatch(content);
  if (match == null) return [];
  final assetLines = match
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
      final filesInDir = getFilesRecursivelyRelative(dir, projectRoot);
      assets.addAll(filesInDir);
    } else {
      // Could not access declared asset
    }
  }
  return assets;
}

List<String> getFilesRecursivelyRelative(Directory dir, String projectRoot) {
  final files = <String>[];
  if (!dir.existsSync()) return files;
   try {
      for (var entity in dir.listSync(recursive: true)) {
        if (entity is File) {
           files.add(p.relative(entity.path, from: projectRoot).replaceAll('\\', '/'));
        }
      }
   } catch (e) {
      print('⚠️ Error listing files in ${dir.path}: $e');
   }
  return files;
}