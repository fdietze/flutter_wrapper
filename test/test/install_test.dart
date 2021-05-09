import 'dart:async';
import 'dart:io' as io;

import 'package:file/local.dart';
import 'package:test/test.dart';
import 'package:cli_script/cli_script.dart';
import 'package:file/file.dart';

final repoRoot = const LocalFileSystem().currentDirectory.parent;

Future<void> runInstallScript({String? workingDirectory}) async {
  // Get path from line
  //     • Flutter version 2.2.0-10.1.pre at /usr/local/Caskroom/flutter/latest/flutter
  final doctor = Script.capture((_) async => await run('flutter doctor -v'));
  final lines = await doctor.stdout.lines.toList();
  final flutterRepoPath = lines.firstWhere((line) => line.contains("Flutter version")).split(" ").last;
  print("doctor exit code ${await doctor.exitCode}");

  await run(
    "${repoRoot.childFile('install.sh').path}",
    name: 'install.sh',
    workingDirectory: workingDirectory,
    environment: {
      // set a custom path making the tests much faster by cloning from local repo
      'TEST_FLUTTER_PATH': "$flutterRepoPath",
    },
  );
}

void main() {
  wrapMain(() async {
    group('install', () {
      test('report missing git', () async {
        final dir = io.Directory.systemTemp.createTempSync('root');
        addTearDown(() {
          dir.deleteSync(recursive: true);
        });

        final script = Script.capture((_) async {
          await runInstallScript(workingDirectory: dir.absolute.path);
        });
        final err = await script.stdout.text;
        expect(err, contains("Not a git repository, to fix this run: git init"));
        final code = await script.exitCode;
        expect(code, 1);
      });

      group("install in git root", () {
        late Directory gitRootDir;
        late Directory appDir;

        setUpAll(() async {
          final dir = const LocalFileSystem().systemTempDirectory.createTempSync('root');
          addTearDown(() {
            // TODO enable before commit, only for debugging
            // dir.deleteSync(recursive: true);
          });
          gitRootDir = appDir = dir.childDirectory('myApp');
          assert(gitRootDir == appDir);

          // create git in appDir
          appDir.createSync();
          await run("git init -b master", workingDirectory: appDir.absolute.path);

          await runInstallScript(workingDirectory: appDir.absolute.path);
          print('init done');
        });

        test('flutterw was downloaded', () async {
          expect(appDir.childFile('flutterw').existsSync(), isTrue);
        });

        test('flutterw is executable', () async {
          final flutterw = appDir.childFile('flutterw');
          final script = Script.capture((_) async => await run("stat ${flutterw.absolute.path}"));
          expect(await script.stdout.text, contains("-rwxr-xr-x"));
        });

        test('created .flutter submodule in appDir', () async {
          final flutterw = appDir.childFile('flutterw');
          print("Checking dir ${flutterw.path}");
          expect(flutterw.existsSync(), isTrue);
        });

        test('downloaded dart tools', () async {
          expect(gitRootDir.childFile(".flutter/bin/cache/dart-sdk/bin/dart").existsSync(), isTrue);
          expect(gitRootDir.childFile(".flutter/bin/cache/dart-sdk/bin/dartanalyzer").existsSync(), isTrue);
          expect(gitRootDir.childFile(".flutter/bin/cache/dart-sdk/bin/dartfmt").existsSync(), isTrue);
          expect(gitRootDir.childFile(".flutter/bin/cache/dart-sdk/bin/pub").existsSync(), isTrue);
        });

        test('flutterw contains version', () async {
          final flutterw = appDir.childFile('flutterw');
          final text = flutterw.readAsStringSync();
          expect(text, isNot(contains("VERSION_PLACEHOLDER")));
          expect(text, isNot(contains("DATE_PLACEHOLDER")));
        });
      });

      group("install in subdir", () {
        late Directory gitRootDir;
        late Directory appDir;

        setUpAll(() async {
          gitRootDir = const LocalFileSystem().systemTempDirectory.createTempSync('root');
          addTearDown(() {
            // TODO enable before commit, only for debugging
            //gitRootDir.deleteSync(recursive: true);
          });
          // git repo in root, flutterw in appDir
          appDir = gitRootDir.childDirectory('myApp')..createSync();

          await run("git init -b master", workingDirectory: gitRootDir.absolute.path);
          await runInstallScript(workingDirectory: appDir.absolute.path);
        });

        test('subdir flutterw was downloaded', () async {
          final flutterw = appDir.childFile('flutterw');
          expect(flutterw.existsSync(), isTrue);
        });

        test('subdir flutterw is executable', () async {
          final flutterw = appDir.childFile('flutterw');
          final script = Script.capture((_) async => await run("stat ${flutterw.absolute.path}"));
          expect(await script.stdout.text, contains("-rwxr-xr-x"));
        });

        test('subdir created .flutter submodule', () async {
          final flutterDir = gitRootDir.childDirectory('.flutter');
          expect(flutterDir.existsSync(), isTrue);
        });

        test('subdir downloaded dart tools', () async {
          expect(gitRootDir.childFile(".flutter/bin/cache/dart-sdk/bin/dart").existsSync(), isTrue);
          expect(gitRootDir.childFile(".flutter/bin/cache/dart-sdk/bin/dartanalyzer").existsSync(), isTrue);
          expect(gitRootDir.childFile(".flutter/bin/cache/dart-sdk/bin/dartfmt").existsSync(), isTrue);
          expect(gitRootDir.childFile(".flutter/bin/cache/dart-sdk/bin/pub").existsSync(), isTrue);
        });

        test('subdir flutterw contains version', () async {
          final flutterw = appDir.childFile('flutterw');
          final text = flutterw.readAsStringSync();
          expect(text, isNot(contains("VERSION_PLACEHOLDER")));
          expect(text, isNot(contains("DATE_PLACEHOLDER")));
        });
      });
    });
  });
}