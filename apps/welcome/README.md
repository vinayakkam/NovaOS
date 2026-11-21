# TwilightOS Welcome (Tauri 2 stub)

First-run setup app. Not built into the ISO yet.

```bash
cd apps/welcome
npm install
cp ../../theme/branding/twilightos-logo.svg src/logo.svg
npx tauri icon ../../theme/branding/twilightos-logo.svg   # generates src-tauri/icons/*
npm run dev
```

On Linux, Tauri needs `webkit2gtk-4.1` (`pacman -S webkit2gtk-4.1`).
