import 'dart:async';
import 'dart:developer' show log;

import 'package:flutter/material.dart';

import 'my_app.dart';

void main() {
  // Catch unhandled errors in the app and log them
  runZonedGuarded(() {
    runApp(const MyApp());
  }, (e, st) => log('Unhandled error: ', error: e, stackTrace: st));
}
