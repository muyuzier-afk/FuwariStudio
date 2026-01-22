# FuwariStudio

跨平台 Markdown 文章编辑器，专为基于 GitHub 的 Fuwari 博客仓库写作/管理/推送而做。

## 功能
- 首次启动下载仓库源码（ZIP），自动进入文章目录管理
- 编辑/预览分栏（支持关闭“实时预览”提升流畅度）
- 图片导入、缩放、保存到原目录并插入 Markdown
- 保存自动提交，也支持手动提交并推送到 GitHub

## 开发运行
1. 安装 Flutter（建议 stable）。
2. 在项目根目录执行：
   - `flutter pub get`
   - `flutter run`

## GitHub Token 权限
推荐 Fine-grained PAT：
- `Metadata: Read`
- `Contents: Read and write`

Classic PAT 也可用：
- 公共仓库：`public_repo`
- 私有仓库：`repo`

## 构建打包
- Windows exe：`flutter build windows --release`
- Windows MSI：`scripts/build_msi.ps1`（自动下载 WiX 3.11）
- Android APK：`flutter build apk --release`
