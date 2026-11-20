// NovaOS icon theme generator.
//
//   node theme/icons/generate.mjs        -> writes theme/icons/NovaOS/
//
// One design language for every icon:
//   apps     navy rounded tile, soft top highlight, glyph in a Twilight gradient
//   places   amber folder with a navy emblem
//   actions  2px-stroke symbolic glyphs that follow the colour scheme (currentColor)
// Unlisted icons fall back to Breeze Dark (see index.theme).

import { mkdirSync, writeFileSync, rmSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const OUT = join(dirname(fileURLToPath(import.meta.url)), "NovaOS");

const C = {
  navyTop: "#1d2a4d", navyBottom: "#0d1428",
  amber: "#f3b651", orange: "#f2683a", ember: "#cd4126",
  teal: "#5eb7d0", blue: "#4f8cff", violet: "#a46bff", green: "#5fd39b", pink: "#ff8fb1",
  text: "#f1eee6",
};

// glyph gradients per app (from -> to)
const G = {
  warm:   [C.amber, C.orange],
  ember:  [C.orange, C.ember],
  sky:    [C.teal, C.blue],
  dusk:   [C.blue, C.violet],
  meadow: [C.green, C.teal],
  rose:   [C.pink, C.orange],
};

const files = new Map();
const put = (rel, svg) => files.set(rel, svg.trim() + "\n");

// ---------------------------------------------------------------- app tiles
function tile(id, grad, glyph) {
  const [a, b] = G[grad];
  return `
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${C.navyTop}"/><stop offset="1" stop-color="${C.navyBottom}"/>
    </linearGradient>
    <linearGradient id="fg" gradientUnits="userSpaceOnUse" x1="12" y1="12" x2="36" y2="36">
      <stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/>
    </linearGradient>
    <linearGradient id="hl" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#fff" stop-opacity=".14"/><stop offset=".5" stop-color="#fff" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <rect x="3" y="4" width="42" height="42" rx="11" fill="#000" opacity=".25"/>
  <rect x="3" y="3" width="42" height="42" rx="11" fill="url(#bg)"/>
  <rect x="3" y="3" width="42" height="42" rx="11" fill="url(#hl)"/>
  <rect x="3.5" y="3.5" width="41" height="41" rx="10.5" fill="none" stroke="#fff" stroke-opacity=".10"/>
  <g fill="url(#fg)" stroke="url(#fg)">${glyph}</g>
</svg>`;
}

// glyphs are drawn in a 48x48 box, roughly inside 13..35
const S = `stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"`;
const glyphs = {
  // The NovaOS / Twilight start mark: three rounded tiles and an orbit dot.
  mark: `<rect stroke="none" x="13" y="13" width="10" height="10" rx="3.2" fill="#f58a5c"/>
         <circle stroke="none" cx="30" cy="18" r="4" fill="#f7c86a"/>
         <rect stroke="none" x="13" y="25" width="10" height="10" rx="3.2" fill="${C.orange}"/>
         <rect stroke="none" x="25" y="25" width="10" height="10" rx="3.2" fill="${C.amber}"/>`,
  star: `<path stroke="none" d="M24 11c1.3 7.6 3.9 10.4 13 13-9.1 2.6-11.7 5.4-13 13-1.3-7.6-3.9-10.4-13-13 9.1-2.6 11.7-5.4 13-13z"/>
         <circle stroke="none" cx="35" cy="14" r="2.2" opacity=".85"/>`,
  folder: `<path stroke="none" d="M12 16a3 3 0 0 1 3-3h6l3 3h9a3 3 0 0 1 3 3v12a3 3 0 0 1-3 3H15a3 3 0 0 1-3-3z"/>
           <path stroke="none" fill="${C.navyBottom}" opacity=".35" d="M12 20h24v2H12z"/>`,
  terminal: `<path fill="none" ${S} d="M15 18l6 6-6 6"/><path fill="none" ${S} d="M24 31h9"/>`,
  bag: `<path stroke="none" d="M14 19h20l-1.6 14.2A3 3 0 0 1 29.4 36H18.6a3 3 0 0 1-3-2.8z"/>
        <path fill="none" ${S} d="M19.5 19v-2a4.5 4.5 0 0 1 9 0v2"/>`,
  gear: (() => {
    let teeth = "";
    for (let i = 0; i < 8; i++) teeth += `<rect stroke="none" x="22" y="11" width="4" height="6" rx="1.2" transform="rotate(${i * 45} 24 24)"/>`;
    return `${teeth}<circle stroke="none" cx="24" cy="24" r="9"/><circle stroke="none" fill="${C.navyBottom}" cx="24" cy="24" r="3.6"/>`;
  })(),
  editor: `<path stroke="none" opacity=".45" d="M14 13h13l7 7v15H14z"/>
           <path fill="none" ${S} d="M18 22h9M18 27h12M18 32h6"/>
           <path stroke="none" d="M30.5 25.5l5-5 2.8 2.8-5 5-3.6.8z"/>`,
  picture: `<rect fill="none" ${S} x="12.5" y="14.5" width="23" height="19" rx="3"/>
            <path stroke="none" d="M14 31l6.5-7 4.5 4.5 3-3 6 5.5v1.5H14z"/><circle stroke="none" cx="29.5" cy="20.5" r="2.4"/>`,
  document: `<path fill="none" ${S} d="M16 12.5h11l6 6v17H16z"/><path fill="none" ${S} d="M27 12.5v6h6"/>
             <path fill="none" ${S} d="M20 25h9M20 30h7"/>`,
  capture: `<path fill="none" ${S} d="M13 19v-4a2 2 0 0 1 2-2h4M29 13h4a2 2 0 0 1 2 2v4M35 29v4a2 2 0 0 1-2 2h-4M19 35h-4a2 2 0 0 1-2-2v-4"/>
            <circle stroke="none" cx="24" cy="24" r="4.5"/>`,
  archive: `<rect stroke="none" x="12" y="13" width="24" height="7" rx="2"/>
            <path stroke="none" opacity=".75" d="M14 21h20v11a3 3 0 0 1-3 3H17a3 3 0 0 1-3-3z"/>
            <path fill="none" stroke="${C.navyBottom}" stroke-width="2.4" stroke-linecap="round" d="M21 26h6"/>`,
  disk: `<circle fill="none" ${S} cx="24" cy="24" r="11"/><path stroke="none" d="M24 13a11 11 0 0 1 11 11H24z"/>
         <circle stroke="none" cx="24" cy="24" r="2.2"/>`,
  pulse: `<path fill="none" ${S} d="M11 25h6l3-8 5 15 3.5-10 2 3H37"/>`,
  phone: `<rect fill="none" ${S} x="17" y="11.5" width="14" height="25" rx="3"/><path fill="none" ${S} d="M22 32.5h4"/>`,
  calc: `<rect fill="none" ${S} x="15" y="11.5" width="18" height="25" rx="3"/><rect stroke="none" x="18.5" y="15" width="11" height="5" rx="1"/>
         <g stroke="none"><circle cx="20" cy="25" r="1.6"/><circle cx="24" cy="25" r="1.6"/><circle cx="28" cy="25" r="1.6"/>
         <circle cx="20" cy="30" r="1.6"/><circle cx="24" cy="30" r="1.6"/><circle cx="28" cy="30" r="1.6"/></g>`,
  wine: `<path fill="none" ${S} d="M18 12h12l-1 7a5 5 0 0 1-10 0z"/><path fill="none" ${S} d="M24 24v10M19.5 35h9"/>`,
  help: `<circle fill="none" ${S} cx="24" cy="24" r="11"/><path fill="none" ${S} d="M20.5 21a3.5 3.5 0 1 1 5 3.2c-1 .5-1.5 1.2-1.5 2.3"/><circle stroke="none" cx="24" cy="30.5" r="1.5"/>`,
};

const apps = [
  // [names...], gradient, glyph
  [["novaos-start", "start-here", "start-here-kde", "start-here-kde-plasma", "distributor-logo"], "warm", "mark"],
  [["org.novaos.settings", "novaos-settings"], "warm", "gear"],
  [["system-file-manager", "org.kde.dolphin"], "warm", "folder"],
  [["utilities-terminal", "org.kde.konsole", "konsole"], "sky", "terminal"],
  [["org.kde.discover", "plasmadiscover", "system-software-install"], "ember", "bag"],
  [["systemsettings", "preferences-system", "org.kde.systemsettings"], "dusk", "gear"],
  [["accessories-text-editor", "org.kde.kate", "kate"], "meadow", "editor"],
  [["org.kde.gwenview", "gwenview", "image-viewer"], "rose", "picture"],
  [["org.kde.okular", "okular", "document-viewer"], "ember", "document"],
  [["org.kde.spectacle", "spectacle", "applets-screenshooter"], "sky", "capture"],
  [["org.kde.ark", "ark", "utilities-file-archiver"], "warm", "archive"],
  [["org.kde.partitionmanager", "partitionmanager", "drive-harddisk"], "dusk", "disk"],
  [["org.kde.plasma-systemmonitor", "utilities-system-monitor", "ksysguard"], "meadow", "pulse"],
  [["org.kde.kdeconnect.app", "kdeconnect", "smartphone"], "sky", "phone"],
  [["accessories-calculator", "org.kde.kcalc"], "dusk", "calc"],
  [["wine", "wine-winecfg"], "ember", "wine"],
  [["help-browser", "help-about"], "sky", "help"],
];
for (const [names, grad, glyph] of apps) {
  const svg = tile(names[0], grad, glyphs[glyph]);
  for (const n of names) put(`scalable/apps/${n}.svg`, svg);
}

// ---------------------------------------------------------------- places
function folder(emblem) {
  return `
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="back" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${C.orange}"/><stop offset="1" stop-color="${C.ember}"/>
    </linearGradient>
    <linearGradient id="front" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#f7c86a"/><stop offset="1" stop-color="${C.amber}"/>
    </linearGradient>
  </defs>
  <path fill="url(#back)" d="M4 11a3 3 0 0 1 3-3h11l4 4h19a3 3 0 0 1 3 3v24a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3z"/>
  <path fill="#fff" opacity=".9" d="M7 15h34v6H7z"/>
  <path fill="url(#front)" d="M4 19a3 3 0 0 1 3-3h34a3 3 0 0 1 3 3v20a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3z"/>
  <path fill="#fff" opacity=".25" d="M4 19a3 3 0 0 1 3-3h34a3 3 0 0 1 3 3v1H4z"/>
  <g fill="none" stroke="${C.navyBottom}" stroke-opacity=".72" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">${emblem}</g>
</svg>`;
}
const emblems = {
  plain: ``,
  documents: `<path d="M19 25h10M19 29.5h10M19 34h6"/>`,
  download: `<path d="M24 23v11M19.5 29.5L24 34l4.5-4.5"/>`,
  pictures: `<path d="M18 35l4.5-5 3 3 2-2 3.5 4"/><circle cx="28" cy="25.5" r="1.6"/>`,
  music: `<path d="M22 33.5V24l7-1.5v9"/><circle cx="20.5" cy="33.5" r="1.8"/><circle cx="27.5" cy="31.5" r="1.8"/>`,
  videos: `<path d="M21.5 24.5v9l7.5-4.5z" fill="${C.navyBottom}" fill-opacity=".72"/>`,
  home: `<path d="M18 30l6-5.5 6 5.5M20 28.5V35h8v-6.5"/>`,
  desktop: `<rect x="17.5" y="23.5" width="13" height="9" rx="1.5"/><path d="M22 36h4"/>`,
  remote: `<circle cx="24" cy="29" r="5.5"/><path d="M18.5 29h11M24 23.5c2 2 2 9 0 11M24 23.5c-2 2-2 9 0 11"/>`,
  templates: `<path d="M19 24.5h10v10H19zM19 29.5h10"/>`,
  public: `<circle cx="24" cy="27" r="2.5"/><path d="M19 35a5 5 0 0 1 10 0"/>`,
};
const places = {
  plain: ["folder", "inode-directory", "folder-open"],
  documents: ["folder-documents", "folder-text"],
  download: ["folder-download", "folder-downloads"],
  pictures: ["folder-pictures", "folder-images"],
  music: ["folder-music", "folder-sound"],
  videos: ["folder-videos", "folder-video"],
  home: ["user-home", "folder-home"],
  desktop: ["user-desktop", "folder-desktop"],
  remote: ["folder-remote", "folder-network", "network-workgroup"],
  templates: ["folder-templates"],
  public: ["folder-publicshare", "folder-public"],
};
for (const [emblem, names] of Object.entries(places)) {
  const svg = folder(emblems[emblem]);
  for (const n of names) put(`scalable/places/${n}.svg`, svg);
}
put("scalable/places/user-trash.svg", `
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs><linearGradient id="t" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="${C.navyTop}"/><stop offset="1" stop-color="${C.navyBottom}"/></linearGradient></defs>
  <path fill="url(#t)" stroke="#fff" stroke-opacity=".12" d="M11 14h26l-2.4 26.2A3 3 0 0 1 31.6 43H16.4a3 3 0 0 1-3-2.8z"/>
  <rect x="8" y="9" width="32" height="6" rx="3" fill="${C.orange}"/>
  <path fill="none" stroke="${C.amber}" stroke-width="2.4" stroke-linecap="round" d="M20 21v15M28 21v15"/>
  <rect x="19" y="5.5" width="10" height="4" rx="2" fill="${C.orange}"/>
</svg>`);
for (const n of ["user-trash-full", "trash-empty"]) files.set(`scalable/places/${n}.svg`, files.get("scalable/places/user-trash.svg"));

// ---------------------------------------------------------------- symbolic actions
// 2px strokes in currentColor; Plasma recolours them via the ColorScheme-Text class.
function symbolic(body) {
  return `
<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 22 22">
  <style id="current-color-scheme">.ColorScheme-Text{color:${C.text};}</style>
  <g class="ColorScheme-Text" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${body}</g>
</svg>`;
}
const actions = {
  "system-shutdown": `<path d="M11 3.5v7"/><path d="M6.8 6.2a6.5 6.5 0 1 0 8.4 0"/>`,
  "system-reboot": `<path d="M17.5 11a6.5 6.5 0 1 1-2-4.7"/><path d="M16.5 3.5v3.6h-3.6"/>`,
  "system-suspend": `<path d="M16.5 13.5A6.5 6.5 0 0 1 8.5 5.5a6.5 6.5 0 1 0 8 8z"/>`,
  "system-suspend-hibernate": `<path d="M6 5h10l-10 12h10"/>`,
  "system-log-out": `<path d="M9 4H5.5A1.5 1.5 0 0 0 4 5.5v11A1.5 1.5 0 0 0 5.5 18H9"/><path d="M13 7l4 4-4 4M17 11H8.5"/>`,
  "system-lock-screen": `<rect x="5" y="10" width="12" height="8.5" rx="2"/><path d="M7.5 10V7.5a3.5 3.5 0 0 1 7 0V10"/>`,
  "system-switch-user": `<circle cx="9" cy="8" r="3"/><path d="M3.5 18a5.5 5.5 0 0 1 11 0"/><path d="M16 6v6M13 9h6"/>`,
  "dialog-cancel": `<path d="M6 6l10 10M16 6L6 16"/>`,
  "edit-find": `<circle cx="9.5" cy="9.5" r="5.5"/><path d="M13.5 13.5L18 18"/>`,
  "go-next": `<path d="M8.5 5l6 6-6 6"/>`,
  "go-previous": `<path d="M13.5 5l-6 6 6 6"/>`,
  "view-app-grid": `<rect x="4" y="4" width="5" height="5" rx="1.2"/><rect x="13" y="4" width="5" height="5" rx="1.2"/><rect x="4" y="13" width="5" height="5" rx="1.2"/><rect x="13" y="13" width="5" height="5" rx="1.2"/>`,
};
for (const [n, body] of Object.entries(actions)) put(`symbolic/actions/${n}.svg`, symbolic(body));

// ---------------------------------------------------------------- index.theme
put("index.theme", `
[Icon Theme]
Name=NovaOS
Comment=NovaOS Twilight icons (original artwork). Everything else comes from Breeze Dark.
Inherits=breeze-dark,breeze,hicolor
Example=folder
DisplayDepth=32
FollowsColorScheme=true
Directories=scalable/apps,scalable/places,symbolic/actions

[scalable/apps]
Size=48
MinSize=16
MaxSize=512
Context=Applications
Type=Scalable

[scalable/places]
Size=48
MinSize=16
MaxSize=512
Context=Places
Type=Scalable

[symbolic/actions]
Size=22
MinSize=16
MaxSize=128
Context=Actions
Type=Scalable
`);

rmSync(OUT, { recursive: true, force: true });
for (const [rel, svg] of files) {
  const p = join(OUT, rel);
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, svg);
}
console.log(`NovaOS icons: ${files.size} files -> ${OUT}`);
