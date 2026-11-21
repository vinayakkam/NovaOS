// TwilightOS "Twilight" layout for Plasma (runs once, on a user's first Plasma start).
//
//  Top bar (slim, solid):
//      [mark  App  window title]  ·····  [ddd d MMM  HH:mm]  ·····  [CPU ▬  RAM ▬] [bell] [Quick Settings]
//  Dock:   floating, centered, sized to its icons, moves out of the way of windows:
//      [TwilightOS Start] [pinned / running apps]
//
// Kept deliberately small: every applet costs memory in plasmashell.

var WALLPAPER = "/usr/share/wallpapers/Twilight/";

var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file://" + WALLPAPER);
}

// ---------------- Top bar ----------------
var top = new Panel;
top.location = "top";
top.height = 2 * Math.ceil(gridUnit * 1.55 / 2);
// Dynamic: floats as a slim translucent strip over the desktop; when a window is
// maximised it snaps to the edge and turns solid (Plasma's adaptive opacity).
top.floating = true;
top.hiding = "none";

top.addWidget("org.twilightos.activewindow");
top.addWidget("org.kde.plasma.panelspacer");
top.addWidget("org.twilightos.topclock");
top.addWidget("org.kde.plasma.panelspacer");
top.addWidget("org.twilightos.meters");

// No Plasma system tray: network, volume, battery, Bluetooth and brightness all live
// in TwilightOS Quick Settings, and notifications get their own bell. (The tray loads
// every default item the moment it is created, before a layout script can trim it,
// which also woke KDE Connect and kept ~10 hidden applets in memory.)

// Bell: opens Plasma's notification history. Everything to its right is Quick Settings.
var bell = top.addWidget("org.kde.plasma.notifications");
var qs = top.addWidget("org.twilightos.quicksettings");
// Meta+N / Meta+A like Windows. Guarded: a failure here must not stop the layout.
try { bell.globalShortcut = "Meta+N"; } catch (e) { print("bell shortcut: " + e); }
try { qs.globalShortcut = "Meta+A"; } catch (e) { print("quick settings shortcut: " + e); }

// ---------------- Dock ----------------
var dock = new Panel;
dock.location = "bottom";
dock.height = 2 * Math.ceil(gridUnit * 2.7 / 2);
dock.floating = true;
dock.alignment = "center";
dock.lengthMode = "fit";
dock.hiding = "dodgewindows";

dock.addWidget("org.twilightos.startmenu");

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.kde.dolphin.desktop",
    "applications:firefox.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:onlyoffice-desktopeditors.desktop",
    "applications:org.twilightos.settings.desktop"
]);
tasks.writeConfig("iconSpacing", 2);
tasks.writeConfig("indicateAudioStreams", false);
