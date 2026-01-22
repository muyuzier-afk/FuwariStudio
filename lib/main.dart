import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/posts_screen.dart';
import 'screens/setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.load();
  runApp(FuwariEditorApp(appState: appState));
}

class FuwariEditorApp extends StatelessWidget {
  const FuwariEditorApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFEC4899),
      brightness: Brightness.dark,
    );

    return ChangeNotifierProvider.value(
      value: appState,
      child: MaterialApp(
        title: 'FuwariStudio',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: colorScheme,
          fontFamily: 'MiSans',
          fontFamilyFallback: const [
            'MiSans',
            'Noto Sans SC',
            'PingFang SC',
            'Microsoft YaHei',
            'Segoe UI',
            'Roboto',
          ],
          scaffoldBackgroundColor: const Color(0xFF0F1116),
          cardColor: const Color(0xFF151922),
        ),
        home: Consumer<AppState>(
          builder: (context, state, _) {
            if (state.hasRepo) {
              return const PostsScreen();
            }
            return const SetupScreen();
          },
        ),
      ),
    );
  }
}
