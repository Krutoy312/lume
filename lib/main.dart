import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // ignore: avoid_print
    if (kIsWeb) print('[FlutterError] ${details.exceptionAsString()}\n${details.stack}');
  };

  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const ProviderScope(child: _App()));
  }, (error, stack) {
    // ignore: avoid_print
    print('[ZoneError] $error\n$stack');
  });
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SkinCare',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}
