# FuwariStudio

<p align="right">
  🌐 <a href="./README.md">English</a>
</p>

<p align="center">
  <strong>一个面向静态博客发布流程的 Git 原生 Markdown 编辑器。</strong><br>
  为 Windows 与 Android 提供更轻量、更专注的写作与同步体验。
</p>

<p align="center">
  <img alt="平台" src="https://img.shields.io/badge/platform-Windows%20%7C%20Android-2ea44f">
  <img alt="框架" src="https://img.shields.io/badge/built%20with-Flutter-02569B">
  <img alt="工作流" src="https://img.shields.io/badge/workflow-GitHub--native-181717">
  <img alt="许可证" src="https://img.shields.io/badge/license-MIT-blue">
</p>

> [!IMPORTANT]
> **声明**
> 本系统适用于通用的静态博客工作流，并特别适配基于 **Astro** 的主题或博客系统，例如 **Fuwari**、**Mizuki**、**Charlotte**。

---

## 项目简介

FuwariStudio 是一个面向 GitHub 博客仓库的跨平台客户端，支持桌面端与移动端使用。

它将 Markdown 编辑、图片处理和 GitHub 同步整合到同一个原生应用中，让你无需在编辑器、终端和仓库工具之间频繁切换，把注意力真正放回写作本身。

---

## 为什么选择 FuwariStudio？

一个典型的静态博客工作流，通常会包含这些重复步骤：

- 克隆或更新仓库
- 创建或编辑文章
- 插入并压缩图片
- 提交 Commit
- Push 到 GitHub
- 等待自动部署

FuwariStudio 将这一流程收敛为：

> **打开 → 写作 → 同步**

不再依赖终端优先的工作方式，也不需要重复输入 Git 命令。它更像一个真正的内容发布客户端，而不是一套零散工具的拼接。

---

## 核心特性

### GitHub 原生工作流

- 以 ZIP 方式下载博客仓库
- 直接编辑 `src/content/posts/` 目录下的文章
- 在应用内完成 Commit 与 Push
- 支持 Fine-grained Personal Access Token（PAT）

### Markdown 写作体验

- 简洁的原生编辑界面
- 分屏预览模式
- 更适合长文创作的专注式体验

### 内置图片处理

- 直接将本地图片插入 Markdown
- 自动压缩图片并调整尺寸
- 自动保存到项目目录中

### 跨平台支持

- Windows 客户端
- Android 客户端
- 基于 Flutter 构建，体验统一

---

## 适用场景

FuwariStudio 特别适合以下场景：

- 基于 GitHub 托管的个人博客
- 基于 Astro 的博客主题，例如 Fuwari、Mizuki、Charlotte
- 以 Markdown 为核心的内容发布流程
- 想使用 Git 工作流，但不想频繁操作命令行的作者或开发者

如果你的内容存放在仓库中，那么 FuwariStudio 的目标，就是让这套流程更像“发布内容”，而不是“维护代码”。

---

## 安装方式

### Windows

在 **Releases** 页面下载最新的 `.exe` 或 `.msi` 安装包。

### Android

在 **Releases** 页面下载最新的 `.apk` 安装包。

---

## 快速开始

1. 启动 FuwariStudio
2. 连接你的 GitHub 仓库
3. 打开或创建 `src/content/posts/` 下的文章
4. 在应用内完成 Markdown 写作与图片管理
5. 提交并推送变更到 GitHub

---

## 本地开发

### 环境要求

- Flutter（建议使用 stable 版本）

### 本地运行

```bash
flutter pub get
flutter run
```

---

## GitHub Token 权限说明

**推荐使用：** Fine-grained Personal Access Token

所需权限：

- **Metadata：** Read
- **Contents：** Read and Write

也支持 Classic PAT：

- `public_repo`：公共仓库
- `repo`：私有仓库

---

## 构建方式

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

## 参与贡献

欢迎提交 Issue 和 Pull Request。

如果这个项目对你有帮助，欢迎点一个 Star 支持。

---

## 许可证

MIT License © 2026 muyuzier

本项目基于 MIT License 开源。你可以自由使用、修改、分发，甚至用于商业用途，但需保留原始许可证声明。

详见 [LICENSE](LICENSE) 文件。
