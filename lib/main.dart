import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/l10n.dart';
import 'services/services.dart';
import 'ui/achievement_toast.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';
import 'ui/transitions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bgBottom,
    ),
  );
  final device = WidgetsBinding.instance.platformDispatcher.locale;
  final services = await Services.create(
    deviceLang: AppLang.fromDevice(device),
  );
  runApp(HexaApp(services: services));
}

class HexaApp extends StatefulWidget {
  final Services services;
  const HexaApp({super.key, required this.services});

  @override
  State<HexaApp> createState() => _HexaAppState();
}

class _HexaAppState extends State<HexaApp> with WidgetsBindingObserver {
  DateTime _lastRecheck = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appLang.addListener(_onLanguage);
  }

  @override
  void dispose() {
    appLang.removeListener(_onLanguage);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Every screen reads text through tr(), so a language switch simply
  /// rebuilds every widget currently on screen, including routes underneath.
  void _onLanguage() {
    setState(() {});
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final s = widget.services;
    // Music pauses whenever the game isn't on screen.
    s.sfx.setAppVisible(state == AppLifecycleState.resumed);
    // Re-check the subscription now and then, so a cancelled or expired
    // plan brings ads back and a renewed one keeps them away.
    if (state == AppLifecycleState.resumed &&
        DateTime.now().difference(_lastRecheck) > const Duration(minutes: 10)) {
      _lastRecheck = DateTime.now();
      s.billing.recheck(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: tr('app_title'),
      debugShowCheckedModeBanner: false,
      locale: appLang.value.locale,
      supportedLocales: [for (final l in AppLang.values) l.locale],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: AppColors.accent,
        scaffoldBackgroundColor: AppColors.bgBottom,
        useMaterial3: true,
        // Hexagon reveal for every screen change (see transitions.dart).
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: HexPageTransitionsBuilder(),
            TargetPlatform.iOS: HexPageTransitionsBuilder(),
          },
        ),
      ),
      // Achievement unlocks pop up over every screen.
      builder: (context, child) => AchievementToaster(
        progress: widget.services.progress,
        sfx: widget.services.sfx,
        child: child!,
      ),
      home: HomeScreen(services: widget.services),
    );
  }
}
