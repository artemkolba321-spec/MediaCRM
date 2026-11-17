import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:media_crm/core/config/app_config.dart';
import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/features/auth/auth_screen.dart';
import 'package:media_crm/features/shell/main_shell.dart';
import 'package:media_crm/providers/app_providers.dart';

/// Global key for the scaffold messenger, used to show snack bars from
/// deep-link handlers that don't have a [BuildContext].
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MediaCrmApp extends ConsumerStatefulWidget {
  const MediaCrmApp({super.key});

  @override
  ConsumerState<MediaCrmApp> createState() => _MediaCrmAppState();
}

class _MediaCrmAppState extends ConsumerState<MediaCrmApp> {
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _setupDeepLinkListener();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _setupDeepLinkListener() {
    if (!AppConfig.isCloudConfigured) return;

    final appLinks = AppLinks();
    _linkSubscription = appLinks.uriLinkStream.listen(
      (uri) {
        if (!mounted) return;
        _handleOAuthDeepLink(uri);
      },
      onError: (error) {
        debugPrint('Deep link error: $error');
      },
    );
  }

  void _handleOAuthDeepLink(Uri uri) {
    if (!mounted) return;
    if (uri.scheme != 'mediacrm') return;
    if (!uri.path.startsWith('/oauth-callback')) return;

    final status = uri.queryParameters['status'];
    final channelId = uri.queryParameters['channel_id'];
    final message = uri.queryParameters['message'];

    if (status == 'success' && channelId != null) {
      // Pull updated channel data from the server
      final cloud = ref.read(cloudServiceProvider);
      if (cloud.isConfigured && cloud.isSignedIn) {
        cloud.pullAll().then((_) {
          if (!mounted) return;
          ref.read(dataVersionProvider.notifier).state++;
          ref.read(syncControllerProvider.notifier).refreshPending();
          scaffoldMessengerKey.currentState?.clearSnackBars();
          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: const Text('YouTube подключён'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }).catchError((error) {
          debugPrint('Pull failed after OAuth: $error');
        });
      } else {
        // Cloud not configured or not signed in — still show success
        if (!mounted) return;
        ref.read(dataVersionProvider.notifier).state++;
        scaffoldMessengerKey.currentState?.clearSnackBars();
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: const Text('YouTube подключён'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else if (status == 'error') {
      final errorMsg = message ?? 'Ошибка подключения';
      scaffoldMessengerKey.currentState?.clearSnackBars();
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 4),
          dismissDirection: DismissDirection.down,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final themeMode = auth.isSignedIn
        ? _themeMode(ref.watch(settingsProvider).themeMode)
        : ThemeMode.dark;

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scrollBehavior: const AppScrollBehavior(),
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: _Root(),
    );
  }

  ThemeMode _themeMode(String value) => switch (value) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
}

class _Root extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    ref.listen<AppAuthState>(authProvider, (previous, next) {
      if (previous?.status != next.status ||
          previous?.userId != next.userId) {
        ref.read(dataVersionProvider.notifier).state++;
        ref.read(syncControllerProvider.notifier).refreshPending();
      }
    });

    return switch (auth.status) {
      AuthStatus.initializing => const _SplashScreen(),
      AuthStatus.unauthenticated => const AuthScreen(),
      AuthStatus.authenticated || AuthStatus.local => const MainShell(),
    };
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.accent, colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.hub_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              AppConfig.appName,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              AppConfig.tagline,
              style: TextStyle(
                color: colors.muted,
                fontSize: 10.5,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
