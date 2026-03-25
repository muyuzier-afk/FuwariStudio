# FuwariStudio

<p align="left">
  <a href="./README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <strong>A GitHub-native Markdown editor for static blog publishing.</strong><br>
  Built for a cleaner writing workflow on Windows and Android.
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-Windows%20%7C%20Android-2ea44f">
  <img alt="Framework" src="https://img.shields.io/badge/built%20with-Flutter-02569B">
  <img alt="Workflow" src="https://img.shields.io/badge/workflow-GitHub--native-181717">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-blue">
</p>

> [!IMPORTANT]
> **Statement**
> This system is designed for general static blog workflows and is especially suitable for Astro-based themes or blog systems such as **Fuwari**, **Mizuki**, and **Charlotte**.

---

## Overview

FuwariStudio is a cross-platform desktop and mobile client designed for writers and developers who publish content from a GitHub repository.

It combines Markdown editing, image handling, and GitHub synchronization into a single native application, so you can focus on writing instead of switching between editors, terminals, and repository tools.

---

## Why FuwariStudio?

A typical static blog workflow usually involves several repetitive steps:

- clone or update a repository
- create or edit a post
- insert and compress images
- commit changes
- push to GitHub
- wait for deployment

FuwariStudio turns that process into a simpler flow:

> **Open → Write → Sync**

No terminal-first workflow. No repeated Git commands. Just a focused publishing client for Markdown-based blogs.

---

## Highlights

### GitHub-native workflow

- Download your blog repository as a ZIP package
- Edit posts directly inside `src/content/posts/`
- Commit and push changes back to GitHub in one place
- Support for Fine-grained Personal Access Tokens (PAT)

### Markdown writing experience

- Clean native editor interface
- Split preview mode
- Focused writing environment for long-form posts

### Built-in image handling

- Insert local images directly into Markdown
- Automatically resize and compress images
- Save images into the project directory automatically

### Cross-platform delivery

- Windows client
- Android client
- Built with Flutter for a consistent experience

---

## Use Cases

FuwariStudio is a good fit for:

- GitHub-hosted personal blogs
- Astro-based blog themes such as Fuwari, Mizuki, and Charlotte
- Markdown-driven publishing workflows
- authors who want Git-based publishing without a command-line-heavy process

If your content lives in a repository, FuwariStudio is designed to make that workflow feel like a real publishing app instead of a development task.

---

## Installation

### Windows

Download the latest `.exe` or `.msi` package from the **Releases** page.

### Android

Download the latest `.apk` package from the **Releases** page.

---

## Quick Start

1. Launch FuwariStudio
2. Connect your GitHub repository
3. Open or create a post under `src/content/posts/`
4. Write in Markdown and manage images inside the app
5. Commit and push your changes to GitHub

---

## Development

### Requirements

- Flutter (stable channel recommended)

### Run locally

```bash
flutter pub get
flutter run
```

---

## GitHub Token Permissions

**Recommended:** Fine-grained Personal Access Token

Required permissions:

- **Metadata:** Read
- **Contents:** Read and Write

Classic PAT is also supported:

- `public_repo` for public repositories
- `repo` for private repositories

---

## Build

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

## Roadmap

- Better post management UI
- Git diff preview
- Draft autosave
- Multi-repository support
- macOS support

---

## Contributing

Issues and pull requests are welcome.

If this project is useful to you, consider giving it a star.

---

## License

MIT License © 2026 muyuzier

This project is licensed under the MIT License. You are free to use, modify, distribute, and use it commercially, as long as the original license notice is included.

See the [LICENSE](LICENSE) file for details.
