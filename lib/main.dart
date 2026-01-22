import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/posts_screen.dart';
import 'screens/setup_screen.dart';
import 'theme/app_theme.dart';

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
    return ChangeNotifierProvider.value(
      value: appState,
      child: Consumer<AppState>(
        builder: (context, state, _) {
          final seed = state.themeSeedColor;
          return MaterialApp(
            title: 'FuwariStudio',
            theme: buildAppTheme(
              brightness: Brightness.light,
              seedColor: seed,
            ),
            darkTheme: buildAppTheme(
              brightness: Brightness.dark,
              seedColor: seed,
            ),
            themeMode: state.themeMode,
            home: state.hasRepo ? const PostsScreen() : const SetupScreen(),
          );
        },
      ),
    );
  }
}
