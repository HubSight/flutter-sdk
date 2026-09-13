// ignore_for_file: avoid_print, unnecessary_brace_in_string_interps
import 'dart:io';

const green = '\x1B[32m';
const red = '\x1B[31m';
const yellow = '\x1B[33m';
const blue = '\x1B[34m';
const cyan = '\x1B[36m';
const reset = '\x1B[0m';
const bold = '\x1B[1m';

void main(List<String> rawArgs) async {
  final args = <String>[];
  bool isDryRun = false;
  bool noPush = false;
  bool autoPush = false;

  for (final arg in rawArgs) {
    if (arg == '--dry-run') {
      isDryRun = true;
    } else if (arg == '--no-push') {
      noPush = true;
    } else if (arg == '--push') {
      autoPush = true;
    } else if (arg == '-h' || arg == '--help') {
      printUsage();
      exit(0);
    } else {
      args.add(arg);
    }
  }

  print('$blue======================================================$reset');
  print('$blue   HubSight SDK - Automated Release & Version Bumper  $reset');
  print('$blue======================================================$reset\n');

  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('${red}❌ Error: pubspec.yaml not found in current directory!$reset');
    exit(1);
  }

  final changelogFile = File('CHANGELOG.md');
  if (!changelogFile.existsSync()) {
    print('${red}❌ Error: CHANGELOG.md not found in current directory!$reset');
    exit(1);
  }

  // 1. Read current version from pubspec.yaml
  final pubspecContent = pubspecFile.readAsStringSync();
  final versionMatch =
      RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+.*)$', multiLine: true)
          .firstMatch(pubspecContent);

  if (versionMatch == null) {
    print('${red}❌ Error: Could not parse version from pubspec.yaml!$reset');
    exit(1);
  }

  final currentVersion = versionMatch.group(1)!.trim();
  print('Current package version: $bold$cyan$currentVersion$reset');

  // 2. Determine target version
  String bumpType = 'patch';
  String? customNote;

  if (args.isNotEmpty) {
    bumpType = args[0].toLowerCase();
    if (args.length > 1) {
      customNote = args.sublist(1).join(' ').trim();
    }
  } else if (stdin.hasTerminal) {
    print('\nSelect version bump type:');
    print(
        '  1) patch (${_calcNextVersion(currentVersion, 'patch')}) [default]');
    print('  2) minor (${_calcNextVersion(currentVersion, 'minor')})');
    print('  3) major (${_calcNextVersion(currentVersion, 'major')})');
    print('  4) custom version');
    stdout.write('Choice [1-4, enter for patch]: ');
    final input = stdin.readLineSync()?.trim() ?? '';
    if (input == '2' || input.toLowerCase() == 'minor') {
      bumpType = 'minor';
    } else if (input == '3' || input.toLowerCase() == 'major') {
      bumpType = 'major';
    } else if (input == '4') {
      stdout.write('Enter custom SemVer version: ');
      final custom = stdin.readLineSync()?.trim() ?? '';
      if (custom.isEmpty || !RegExp(r'^\d+\.\d+\.\d+').hasMatch(custom)) {
        print('${red}❌ Invalid version format: $custom$reset');
        exit(1);
      }
      bumpType = custom;
    } else {
      bumpType = 'patch';
    }
  }

  final newVersion = _isSemVer(bumpType)
      ? bumpType
      : _calcNextVersion(currentVersion, bumpType);

  print('\nTarget version to release: $bold$green$newVersion$reset');

  if (newVersion == currentVersion) {
    print(
        '${yellow}⚠️ Target version is identical to current version ($currentVersion). Aborting.$reset');
    exit(1);
  }

  // 3. Resolve Changelog entries from git commits or custom note
  final lastTag = _runGit(['describe', '--tags', '--abbrev=0']).stdout.trim();
  final changelogEntries = <String>[];

  if (customNote != null && customNote.isNotEmpty) {
    changelogEntries.add(customNote);
  } else {
    // Read git commits since last tag
    final commitLogRange = lastTag.isNotEmpty ? '$lastTag..HEAD' : 'HEAD';
    final gitLog = _runGit([
      'log',
      commitLogRange,
      '--pretty=format:%s',
    ]).stdout.trim();

    if (gitLog.isNotEmpty) {
      final lines = gitLog
          .split('\n')
          .map((s) => s.trim())
          .where((s) =>
              s.isNotEmpty &&
              !s.startsWith('Merge ') &&
              !s.startsWith('chore(release)'))
          .toList();

      for (final line in lines) {
        changelogEntries.add(line);
      }
    }
  }

  if (changelogEntries.isEmpty) {
    if (stdin.hasTerminal) {
      stdout.write(
          '\nNo recent commits found since last tag. Enter release description: ');
      final entered = stdin.readLineSync()?.trim() ?? '';
      if (entered.isNotEmpty) {
        changelogEntries.add(entered);
      } else {
        changelogEntries.add('Maintenance release and stability improvements.');
      }
    } else {
      changelogEntries.add('Maintenance release and stability improvements.');
    }
  }

  // Group changelog entries into categories (Added, Fixed, Changed)
  final categorized = _categorizeChangelogEntries(changelogEntries);

  print('\n${yellow}Generated Changelog for v$newVersion:$reset');
  print(categorized.trim());

  // 4. Update pubspec.yaml
  final updatedPubspec = pubspecContent.replaceFirst(
    'version: $currentVersion',
    'version: $newVersion',
  );
  pubspecFile.writeAsStringSync(updatedPubspec);
  print('\n${green}✓ Updated pubspec.yaml version to $newVersion$reset');

  // 5. Update CHANGELOG.md
  final changelogContent = changelogFile.readAsStringSync();
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final newChangelogSection = '## $newVersion - $today\n\n$categorized\n';

  final changelogHeaderIndex = changelogContent.indexOf('## ');
  String updatedChangelog;
  if (changelogHeaderIndex != -1) {
    updatedChangelog = changelogContent.substring(0, changelogHeaderIndex) +
        newChangelogSection +
        changelogContent.substring(changelogHeaderIndex);
  } else {
    updatedChangelog = '$changelogContent\n\n$newChangelogSection';
  }
  changelogFile.writeAsStringSync(updatedChangelog);
  print('${green}✓ Updated CHANGELOG.md with entry for v$newVersion$reset');

  // 6. Run Quality Gate (dart format, dart analyze, flutter test)
  print('\n${yellow}[1/4] Running code formatting (dart format)...$reset');
  final formatRes = Process.runSync('dart', ['format', '.']);
  if (formatRes.exitCode != 0) {
    print('${red}❌ Formatting failed:$reset\n${formatRes.stderr}');
    _rollback(pubspecFile, pubspecContent, changelogFile, changelogContent);
    exit(1);
  }
  print('${green}✓ Code formatting clean.$reset');

  print(
      '\n${yellow}[2/4] Running static analysis (dart analyze --fatal-infos)...$reset');
  final analyzeRes = Process.runSync('dart', ['analyze', '--fatal-infos']);
  if (analyzeRes.exitCode != 0) {
    print(
        '${red}❌ Static analysis failed:$reset\n${analyzeRes.stdout}\n${analyzeRes.stderr}');
    _rollback(pubspecFile, pubspecContent, changelogFile, changelogContent);
    exit(1);
  }
  print('${green}✓ Static analysis clean (0 issues).$reset');

  print('\n${yellow}[3/4] Running unit test suite (flutter test)...$reset');
  final testRes = Process.runSync('flutter', ['test']);
  if (testRes.exitCode != 0) {
    print(
        '${red}❌ Unit tests failed:$reset\n${testRes.stdout}\n${testRes.stderr}');
    _rollback(pubspecFile, pubspecContent, changelogFile, changelogContent);
    exit(1);
  }
  print('${green}✓ All unit tests passed.$reset');

  // 7. Git commit release files
  print('\n${yellow}[4/4] Creating git commit and tag...$reset');
  if (isDryRun) {
    print(
        '${yellow}⚠️ --dry-run specified. Rolling back version & changelog changes.$reset');
    _rollback(pubspecFile, pubspecContent, changelogFile, changelogContent);
    print('${green}✓ Dry run completed successfully!$reset');
    exit(0);
  }

  _runGit(['add', '-A']);
  final commitRes = _runGit(['commit', '-m', 'chore(release): v$newVersion']);
  if (commitRes.exitCode != 0) {
    print('${red}❌ Git commit failed:$reset\n${commitRes.stderr}');
    _rollback(pubspecFile, pubspecContent, changelogFile, changelogContent);
    exit(1);
  }
  print('${green}✓ Committed release: chore(release): v$newVersion$reset');

  // Validate pub.dev dry-run with clean git state
  print(
      '\n${yellow}Validating package for pub.dev (flutter pub publish --dry-run)...$reset');
  final dryRunRes = Process.runSync('flutter', ['pub', 'publish', '--dry-run']);
  if (dryRunRes.exitCode != 0) {
    print(
        '${red}❌ pub.dev dry-run validation failed:$reset\n${dryRunRes.stdout}\n${dryRunRes.stderr}');
    print('${yellow}You can fix warnings and re-run.$reset');
  } else {
    print('${green}✓ pub.dev dry-run passed with zero warnings!$reset');
  }

  // Create git tag
  final tagRes =
      _runGit(['tag', '-a', 'v$newVersion', '-m', 'Release v$newVersion']);
  if (tagRes.exitCode != 0) {
    _runGit(['tag', 'v$newVersion']);
  }
  print('${green}✓ Created git tag: v$newVersion$reset');

  print('\n$green======================================================$reset');
  print('$green   SUCCESS: Version v$newVersion successfully prepared! $reset');
  print('$green======================================================$reset');

  final pushCommand = 'git push origin main && git push origin v$newVersion';

  if (!noPush) {
    bool shouldPush = autoPush;
    if (!shouldPush && stdin.hasTerminal) {
      stdout.write(
          '\nDo you want to push commit and tag v$newVersion to GitHub now? [Y/n]: ');
      final ans = stdin.readLineSync()?.trim().toLowerCase() ?? '';
      shouldPush = (ans.isEmpty || ans == 'y' || ans == 'yes');
    }

    if (shouldPush) {
      print(
          '\n${yellow}Pushing to GitHub (origin main & v$newVersion)...$reset');
      final pushMainRes = Process.runSync('git', ['push', 'origin', 'main']);
      final pushTagRes =
          Process.runSync('git', ['push', 'origin', 'v$newVersion']);

      if (pushMainRes.exitCode == 0 && pushTagRes.exitCode == 0) {
        print(
            '${green}✓ Pushed commit and tag v$newVersion to GitHub successfully!$reset');
        print(
            '${cyan}The GitHub Actions OIDC workflow is now deploying v$newVersion to pub.dev!$reset\n');
        exit(0);
      } else {
        print('${yellow}⚠️ Push failed or was partially rejected:$reset');
        print(pushMainRes.stderr);
        print(pushTagRes.stderr);
      }
    }
  }

  print('\nTo publish to pub.dev via GitHub Actions CI, run:');
  print('  $bold$blue$pushCommand$reset\n');
}

bool _isSemVer(String s) => RegExp(r'^\d+\.\d+\.\d+').hasMatch(s);

String _calcNextVersion(String current, String type) {
  final clean = current.split('+').first.split('-').first;
  final parts = clean.split('.').map(int.tryParse).toList();
  if (parts.length != 3 || parts.any((p) => p == null)) {
    return '$current.1';
  }

  int major = parts[0]!;
  int minor = parts[1]!;
  int patch = parts[2]!;

  switch (type.toLowerCase()) {
    case 'major':
      return '${major + 1}.0.0';
    case 'minor':
      return '$major.${minor + 1}.0';
    case 'patch':
    default:
      return '$major.$minor.${patch + 1}';
  }
}

String _categorizeChangelogEntries(List<String> entries) {
  final added = <String>[];
  final fixed = <String>[];
  final changed = <String>[];

  for (final raw in entries) {
    final entry = raw.trim();
    if (entry.isEmpty) continue;

    final lower = entry.toLowerCase();
    if (lower.startsWith('feat:') ||
        lower.startsWith('feat(') ||
        lower.startsWith('added')) {
      added.add(_cleanEntry(entry, 'feat'));
    } else if (lower.startsWith('fix:') ||
        lower.startsWith('fix(') ||
        lower.startsWith('fixed')) {
      fixed.add(_cleanEntry(entry, 'fix'));
    } else {
      changed.add(_cleanEntry(entry, 'chore'));
    }
  }

  final sb = StringBuffer();
  if (added.isNotEmpty) {
    sb.writeln('### Added');
    for (final item in added) {
      sb.writeln('- $item');
    }
    sb.writeln();
  }

  if (fixed.isNotEmpty) {
    sb.writeln('### Fixed');
    for (final item in fixed) {
      sb.writeln('- $item');
    }
    sb.writeln();
  }

  if (changed.isNotEmpty) {
    sb.writeln('### Changed');
    for (final item in changed) {
      sb.writeln('- $item');
    }
    sb.writeln();
  }

  return sb.toString();
}

String _cleanEntry(String entry, String prefix) {
  final m = RegExp(r'^[a-zA-Z]+(?:\([^)]+\))?:\s*(.*)$').firstMatch(entry);
  if (m != null) {
    final body = m.group(1)!.trim();
    if (body.isNotEmpty) {
      return body[0].toUpperCase() + body.substring(1);
    }
  }
  return entry.startsWith('- ') ? entry.substring(2) : entry;
}

ProcessResult _runGit(List<String> args) {
  return Process.runSync('git', args);
}

void _rollback(
    File pubspec, String oldPubspec, File changelog, String oldChangelog) {
  try {
    pubspec.writeAsStringSync(oldPubspec);
    changelog.writeAsStringSync(oldChangelog);
    print(
        '${yellow}Reverted pubspec.yaml and CHANGELOG.md back to previous state.$reset');
  } catch (_) {}
}

void printUsage() {
  print('''
Usage: ./tool/release.sh [patch|minor|major|<version>] ["Release notes..."] [options]

Arguments:
  bump_type       Type of version bump: 'patch' (default), 'minor', 'major', or specific '1.2.0'.
  notes           Optional release description string for CHANGELOG.md.
                  If omitted, commits since the last git tag will be auto-categorized.

Options:
  --dry-run       Simulate version calculation, changelog generation, and tests without committing.
  --push          Automatically push to GitHub without interactive prompt.
  --no-push       Skip pushing to GitHub.
  -h, --help      Show this help message.

Examples:
  ./tool/release.sh
  ./tool/release.sh patch
  ./tool/release.sh patch "Fix base URL path in ApiClient"
  ./tool/release.sh minor "Add support for camera homography calibration"
  ./tool/release.sh 1.2.0 "Revamped media streaming engine"
  ./tool/release.sh --dry-run
''');
}
