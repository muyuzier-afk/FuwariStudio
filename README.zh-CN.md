<p align="right">
  🌐 <a href="./README.md">English</a>
</p>

# FuwariStudio

> 一个为 GitHub 静态博客工作流打造的原生 Markdown 编辑客户端。

FuwariStudio 是一个跨平台（Windows & Android）的桌面/移动端客户端，专为管理基于 GitHub 的博客仓库而设计。

它不仅仅是一个 Markdown 编辑器，而是一个为静态博客作者优化的完整写作与同步工具。

---

## ✨ 为什么选择 FuwariStudio？

如果你通过 GitHub 管理博客（Hexo / Hugo / Jekyll / 自定义静态博客），你的日常流程可能是：

- 克隆仓库
- 创建或编辑文章
- 插入并压缩图片
- 提交 Commit
- Push 到 GitHub
- 等待自动部署

FuwariStudio 将这一切简化为：

> 打开 → 写作 → 一键同步 🚀

无需终端。无需反复输入 Git 命令。专注写作本身。

---

## 🚀 功能特性

### 🔄 原生 GitHub 工作流支持
- 自动下载博客仓库（ZIP）
- 直接编辑 `src/content/posts/` 目录文章
- 一键 Commit & Push
- 支持 Fine-grained Personal Access Token（PAT）

### 📝 Markdown 编辑体验
- 简洁现代的写作界面
- 分屏实时预览
- 专注模式写作体验

### 🖼 图片处理
- 直接插入本地图片到 Markdown
- 自动压缩 / 调整图片尺寸
- 自动保存到项目目录

### 🌍 跨平台支持
- Windows
- Android
- 基于 Flutter 构建

---

## 🎯 适合哪些用户？

- 在 GitHub 上托管博客的开发者
- 使用 Hexo / Hugo / Jekyll 等静态站点生成器的用户
- 想使用 Git 工作流但不想频繁使用命令行的人
- 更喜欢原生客户端而非浏览器编辑的人

如果 GitHub 是你的内容源，这个工具就是为你设计的。

---

## 📦 安装方式

### Windows

在 **Releases** 页面下载最新的 `.exe` 或 `.msi` 安装包。

### Android

在 **Releases** 页面下载最新的 `.apk` 文件。

---

## 🛠 本地开发

### 环境要求

- Flutter（建议使用 stable 版本）

### 本地运行

```bash
flutter pub get
flutter run
```

---

## 🔐 GitHub Token 权限说明

推荐使用：Fine-grained Personal Access Token

所需权限：

- Metadata：Read
- Contents：Read and Write

也支持 Classic PAT：

- `public_repo`（公共仓库）
- `repo`（私有仓库）

---

## 🏗 构建方式

### Windows EXE

```bash
flutter build windows --release
```

### Windows MSI

```bash
scripts/build_msi.ps1
```

### Android APK

```bash
flutter build apk --release
```

---

## 🌱 开发路线图（Roadmap）

- 更完善的文章管理界面
- Git diff 预览功能
- 草稿自动保存
- 多仓库支持
- macOS 支持

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request。

如果这个项目对你有帮助，欢迎点一个 ⭐ 支持。

---

## 📄 许可证

MIT License © 2026 muyuzier

本项目基于 MIT License 开源。  
你可以自由使用、修改、分发，甚至用于商业用途，但需保留原始许可证声明。

详见 [LICENSE](LICENSE) 文件。
