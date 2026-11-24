import 'dart:convert';
import 'dart:io';

// The foundation probe loads the public entry point before it has domain APIs.
// ignore: unused_import
import 'package:kronikas_core/kronikas_core.dart' deferred as core;

Future<void> main(List<String> args) async {
  await core.loadLibrary();
  File(args.single).writeAsStringSync(
    jsonEncode({'total': 1, 'passed': 1, 'failed': 0, 'skipped': 0}),
  );
}
