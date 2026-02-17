# FuwariStudio

> A GitHub-native Markdown editor built for static blog workflows.

FuwariStudio is a cross-platform desktop & Android client designed specifically for managing GitHub-based blog repositories.

It’s not just a Markdown editor — it’s a streamlined workflow tool for static blog authors.
<p align="left">
  <a href="./README.zh-CN.md">简体中文</a>
</p>


## ✨ Why FuwariStudio?

If you manage your blog via GitHub (Hexo / Hugo / Jekyll / custom static blog), your workflow probably looks like this:

- Clone repository
- Create or edit post
- Insert & compress images
- Commit changes
- Push to GitHub
- Wait for deployment

FuwariStudio turns that into:

> Open → Edit → One-click Sync 🚀

No terminal. No repetitive Git commands. Just writing.

---

## 🚀 Features

### 🔄 GitHub-Native Workflow
- Automatically download your blog repository (ZIP)
- Edit posts directly inside `src/content/posts/`
- One-click commit & push to GitHub
- Supports Fine-grained Personal Access Token (PAT)

### 📝 Markdown Editing
- Clean, modern writing interface
- Split preview mode
- Focused writing experience

### 🖼 Image Handling
- Insert images directly into Markdown
- Automatic image resize & compression
- Save images into project directory automatically

### 🌍 Cross-Platform
- Windows
- Android
- Built with Flutter

---

## 🎯 Who Is This For?

- Developers hosting blogs on GitHub
- Static site users (Hexo / Hugo / Jekyll / custom setups)
- Writers who want Git-based blogging without CLI
- People who prefer a native client instead of browser editing

If GitHub is your content source — this tool is built for you.

---

## 📦 Installation

### Windows

Download the latest `.exe` or `.msi` from the **Releases** page.

### Android

Download the latest `.apk` from **Releases**.

---

## 🛠 Development

### Requirements

- Flutter (stable channel recommended)

### Run locally

```bash
flutter pub get
flutter run
```

---

## 🔐 GitHub Token Permissions

Recommended: Fine-grained Personal Access Token

Required permissions:

- Metadata: Read
- Contents: Read and Write

Classic PAT also supported:

- `public_repo` (for public repositories)
- `repo` (for private repositories)

---

## 🏗 Build

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

## 🌱 Roadmap

- Better post management UI
- Git diff preview
- Draft autosave
- Multi-repository support
- macOS support

---

## 🤝 Contributing

Issues and pull requests are welcome.

If you find this project useful, consider giving it a ⭐

---

## 📄 License

MIT License © 2026 muyuzier

This project is licensed under the MIT License.  
You are free to use, modify, distribute, and even use it commercially — as long as the original license notice is included.

See the [LICENSE](LICENSE) file for details.
