import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/confetti_overlay.dart';
import 'posts_screen.dart';

enum _SetupStep {
  welcome,
  token,
  repo,
  success,
}

class GuidedSetupScreen extends StatefulWidget {
  const GuidedSetupScreen({super.key});

  @override
  State<GuidedSetupScreen> createState() => _GuidedSetupScreenState();
}

class _GuidedSetupScreenState extends State<GuidedSetupScreen> {
  _SetupStep _currentStep = _SetupStep.welcome;
  final _repoController = TextEditingController();
  final _tokenController = TextEditingController();
  String? _errorMessage;
  bool _showConfetti = false;

  @override
  void dispose() {
    _repoController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() {
      _errorMessage = null;
      if (_currentStep == _SetupStep.welcome) {
        _currentStep = _SetupStep.token;
      } else if (_currentStep == _SetupStep.token) {
        _currentStep = _SetupStep.repo;
      }
    });
  }

  void _prevStep() {
    setState(() {
      _errorMessage = null;
      if (_currentStep == _SetupStep.token) {
        _currentStep = _SetupStep.welcome;
      } else if (_currentStep == _SetupStep.repo) {
        _currentStep = _SetupStep.token;
      }
    });
  }

  Future<void> _finishSetup(AppState appState) async {
    final repoUrl = _repoController.text.trim();
    final token = _tokenController.text.trim();

    if (repoUrl.isEmpty) {
      setState(() => _errorMessage = '请输入仓库地址');
      return;
    }
    if (token.isEmpty) {
      setState(() => _errorMessage = '请先创建并输入 Token');
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      await appState.bootstrapRepo(repoUrl, token);
      setState(() {
        _currentStep = _SetupStep.success;
        _showConfetti = true;
      });

      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PostsScreen()),
      );
    } catch (error) {
      setState(() {
        _errorMessage = _formatError(error);
      });
    }
  }

  String _formatError(Object error) {
    final text = error.toString();
    if (text.contains('Failed host lookup') ||
        text.contains('No address associated with hostname') ||
        text.contains('Network error while calling GitHub API')) {
      return '无法连接到 GitHub，请检查网络连接';
    }
    if (text.contains('401') || text.contains('Bad credentials')) {
      return 'Token 无效或已过期，请检查是否正确复制';
    }
    if (text.contains('404') || text.contains('Not Found')) {
      return '仓库不存在或无访问权限，请检查地址和 Token 权限';
    }
    return '初始化失败：$text';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return ConfettiOverlay(
          emit: _showConfetti,
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  _buildStepper(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildCurrentStep(appState),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepper() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _buildStepIndicator(1, '开始', _currentStep.index >= 0),
          _buildStepLine(_currentStep.index >= 1),
          _buildStepIndicator(2, '创建密钥', _currentStep.index >= 1),
          _buildStepLine(_currentStep.index >= 2),
          _buildStepIndicator(3, '配置仓库', _currentStep.index >= 2),
          _buildStepLine(_currentStep.index >= 3),
          _buildStepIndicator(4, '完成', _currentStep.index >= 3),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int number, String label, bool isActive) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? cs.primary : cs.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isActive
                ? Icon(Icons.check, color: cs.onPrimary, size: 20)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? cs.primary : cs.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isActive) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 24),
        color: isActive ? cs.primary : cs.surfaceContainerHighest,
      ),
    );
  }

  Widget _buildCurrentStep(AppState appState) {
    switch (_currentStep) {
      case _SetupStep.welcome:
        return _buildWelcomeStep();
      case _SetupStep.token:
        return _buildTokenStep();
      case _SetupStep.repo:
        return _buildRepoStep(appState);
      case _SetupStep.success:
        return _buildSuccessStep();
    }
  }

  Widget _buildWelcomeStep() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      key: const ValueKey('welcome'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.edit_note_rounded,
              size: 48,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '欢迎使用 FuwariStudio',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            '这是一个专为静态博客设计的 Markdown 编辑器。\n接下来将引导你完成初始化配置。',
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _nextStep,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('开始配置'),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenStep() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      key: const ValueKey('token'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _prevStep,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Text(
                '创建 GitHub Token',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withAlpha(77),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withAlpha(77)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '推荐使用 Fine-grained Token',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Fine-grained Token 更安全，可精确控制权限范围。\n'
                  'Classic Token 权限较大，但配置简单。',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildExpandableSection(
            title: 'Fine-grained Token 创建步骤',
            children: [
              _buildStepItem(1, '访问 GitHub Settings'),
              _buildStepItem(2, '左侧菜单选择 "Developer settings"'),
              _buildStepItem(3, '选择 "Personal access tokens" → "Fine-grained tokens"'),
              _buildStepItem(4, '点击 "Generate new token"'),
              _buildStepItem(5, '填写 Token 名称，选择过期时间'),
              _buildStepItem(6, 'Repository access 选择 "Only select repositories"，选择你的博客仓库'),
              _buildStepItem(7, 'Permissions → Repository permissions → Contents: Read and write'),
              _buildStepItem(8, '点击 "Generate token" 并复制'),
            ],
          ),
          const SizedBox(height: 16),
          _buildExpandableSection(
            title: 'Classic Token 创建步骤',
            children: [
              _buildStepItem(1, '访问 GitHub Settings → Developer settings'),
              _buildStepItem(2, '选择 "Personal access tokens" → "Tokens (classic)"'),
              _buildStepItem(3, '点击 "Generate new token (classic)"'),
              _buildStepItem(4, '填写 Note，选择过期时间'),
              _buildStepItem(5, '勾选 "repo" 权限（私有仓库）或 "public_repo"（公开仓库）'),
              _buildStepItem(6, '点击 "Generate token" 并复制'),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _tokenController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: '粘贴你的 Token',
              hintText: 'github_pat_... 或 ghp_...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    _tokenController.text = data!.text!;
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevStep,
                  child: const Text('上一步'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _nextStep,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('下一步'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildRepoStep(AppState appState) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      key: const ValueKey('repo'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _prevStep,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Text(
                '配置博客仓库',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_outlined, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      '仓库地址格式',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const SelectableText(
                  'https://github.com/用户名/仓库名\n'
                  '例如：https://github.com/muyuzier-afk/my-blog',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _repoController,
            decoration: const InputDecoration(
              labelText: '博客仓库地址',
              hintText: 'https://github.com/username/repo',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: cs.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevStep,
                  child: const Text('上一步'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: appState.isBusy
                      ? null
                      : () => _finishSetup(appState),
                  icon: appState.isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('完成配置'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              onPressed: () => _showSkipDialog(appState),
              icon: const Icon(Icons.skip_next, size: 18),
              label: const Text('跳过引导，手动配置'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSkipDialog(AppState appState) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('跳过引导'),
        content: const Text('跳过后将使用原有的配置页面。你可以稍后在设置中重新配置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('跳过'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, false);
    }
  }

  Widget _buildSuccessStep() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(38),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 56,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '配置成功',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.green,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            '仓库已成功连接，即将进入文章管理页面...',
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}
