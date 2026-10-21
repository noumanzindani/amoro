import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/block_provider.dart';
import 'providers/deck_provider.dart';
import 'providers/session_provider.dart';
import 'router.dart';
import 'services/auth_service.dart';
import 'services/block_repository.dart';
import 'services/chat_repository.dart';
import 'services/push_service.dart';
import 'services/storage_service.dart';
import 'services/swipe_repository.dart';
import 'services/user_repository.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AmoreApp());
}

class AmoreApp extends StatefulWidget {
  const AmoreApp({super.key});

  @override
  State<AmoreApp> createState() => _AmoreAppState();
}

class _AmoreAppState extends State<AmoreApp> {
  final _auth = AuthService();
  final _users = UserRepository();
  final _swipes = SwipeRepository();
  final _blocks = BlockRepository();
  late final _session = SessionProvider(_auth, _users);
  late final GoRouter _router = buildRouter(_session);
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final _push = PushService(
    router: _router,
    session: _session,
    messenger: _messenger,
  );

  @override
  void initState() {
    super.initState();
    _session.beforeSignOut = _push.unregister;
    _push.start();
  }

  @override
  void dispose() {
    _push.dispose();
    _router.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: _auth),
        Provider.value(value: _users),
        Provider.value(value: _swipes),
        Provider(create: (_) => ChatRepository()),
        Provider(create: (_) => StorageService()),
        ChangeNotifierProvider.value(value: _session),
        Provider.value(value: _blocks),
        ChangeNotifierProvider(create: (_) => BlockProvider(_blocks, _session)),
        ChangeNotifierProvider(create: (_) => DeckProvider(_users, _swipes)),
      ],
      child: MaterialApp.router(
        scaffoldMessengerKey: _messenger,
        title: 'Amore',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        themeMode: ThemeMode.dark,
        routerConfig: _router,
      ),
    );
  }
}
