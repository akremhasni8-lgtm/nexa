import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/eleveur_questionnaire_screen.dart';
import 'features/home/home_screen.dart';
import 'features/analysis/camera_screen.dart';
import 'features/analysis/analysis_screen.dart';
import 'features/map/map_screen.dart';
import 'features/map/ndvi_screen.dart';
import 'features/results/results_screen.dart';
import 'features/results/rotation_plan_screen.dart';
import 'features/history/history_screen.dart';
import 'models/models.dart';
import 'services/zone_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: NexaTheme.noir,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await Hive.initFlutter();
  Hive.registerAdapter(AnalysisResultAdapter());
  Hive.registerAdapter(EleveurProfileAdapter());
  Hive.registerAdapter(ZoneStatusAdapter());
  Hive.registerAdapter(SavedZoneAdapter());
  await Hive.openBox<AnalysisResult>('analyses');
  await Hive.openBox<EleveurProfile>('profile');
  await Hive.openBox<SavedZone>('zones');
  await Hive.openBox('settings');

  runApp(const ProviderScope(child: NexaApp()));
}

final _router = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    final loc = state.matchedLocation;
    if (loc == '/splash' || loc == '/onboarding' || loc == '/login') return null;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '/login';

    final questionnaireKey = 'questionnaire_done_$uid';
    final questionnaireDone = Hive.box('settings')
        .get(questionnaireKey, defaultValue: false) as bool;

    if (!questionnaireDone && loc != '/questionnaire') return '/questionnaire';

    return null;
  },
  routes: [
    GoRoute(path: '/splash',        builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/login',         builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/onboarding',    builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/questionnaire', builder: (_, __) => const EleveurQuestionnaireScreen()),
    GoRoute(path: '/',              builder: (_, __) => const HomeScreen()),

    GoRoute(
      path: '/camera',
      builder: (_, state) => CameraScreen(
        cameraArgs: state.extra is CameraArgs
            ? state.extra as CameraArgs
            : null,
      ),
    ),

    GoRoute(
      path: '/analysis',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is Map) {
          return AnalysisScreen(
            imagePath: extra['imagePath'] as String,
            cameraArgs: extra['cameraArgs'] as CameraArgs?,
          );
        }
        return AnalysisScreen(imagePath: extra as String);
      },
    ),

    GoRoute(
      path: '/map',
      builder: (_, state) => MapScreen(
        args: state.extra is MapScreenArgs
            ? state.extra as MapScreenArgs
            : null,
      ),
    ),

    GoRoute(
      path: '/results',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is Map) {
          return ResultsScreen(
            result:         extra['result']  as AnalysisResult,
            zoneAnalyseeId: extra['zoneId']  as String?,
            zones:          extra['zones']   as List<TerrainZone>?,
          );
        }
        return ResultsScreen(result: extra as AnalysisResult);
      },
    ),

    GoRoute(
      path: '/rotation',
      builder: (_, state) => RotationPlanScreen(
        zones: state.extra as List<TerrainZone>,
      ),
    ),

    GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
    GoRoute(path: '/ndvi',    builder: (_, __) => const NdviScreen()),
  ],
);

class NexaApp extends StatelessWidget {
  const NexaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NEXA',
      debugShowCheckedModeBanner: false,
      theme: NexaTheme.dark,
      routerConfig: _router,
    );
  }
}