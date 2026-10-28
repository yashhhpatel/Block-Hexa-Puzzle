import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/services.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bgBottom,
  ));
  final services = await Services.create();
  runApp(HexaApp(services: services));
}

class HexaApp extends StatelessWidget {
  final Services services;
  const HexaApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hexa Fill Puzzle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: AppColors.accent,
        scaffoldBackgroundColor: AppColors.bgBottom,
        useMaterial3: true,
      ),
      home: HomeScreen(services: services),
    );
  }
}
