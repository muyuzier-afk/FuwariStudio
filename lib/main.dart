import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/posts_screen.dart';
import 'screens/setup_screen.dart';
import 'services/update_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.load();
  runApp(FuwariEditorApp(appState: appState));
}

class FuwariEditorApp extends StatefulWidget {
  const FuwariEditorApp({super.key, required this.appState});

  final AppState appState;

  @override
  State<FuwariEditorApp> createState() => _FuwariEditorAppState();
}

class _FuwariEditorAppState extends State<FuwariEditorApp> {
  final UpdateService _updateService = UpdateService();
  bool _checkedUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdates());
  }

  Future<void> _checkUpdates() async {
    if (_checkedUpdate) return;
    _checkedUpdate = true;

    final info = await _updateService.fetchLatestRelease();
    if (!mounted || info == null) return;

    final package = await PackageInfo.fromPlatform();
    if (!mounted) return;

    final build = package.buildNumber.trim();
    final currentVersion =
        (build.isEmpty || build == '0') ? package.version : '${package.version}+$build';

    if (_updateService.isNewerVersion(info.version, currentVersion)) {
      await _showUpdateDialog(info, currentVersion);
    }
  }

  Future<void> _showUpdateDialog(UpdateInfo info, String current) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本：$current'),
            Text('最新版本：${info.version}'),
            const SizedBox(height: 8),
            const Text('下载地址：'),
            SelectableText(info.url),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('复制链接'),
          ),
        ],
      ),
    );

    if (!mounted || result != true) return;
    await Clipboard.setData(ClipboardData(text: info.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('下载链接已复制')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.appState,
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
