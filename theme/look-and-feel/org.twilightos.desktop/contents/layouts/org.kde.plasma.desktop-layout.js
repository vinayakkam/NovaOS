// TwilightOS "Twilight" layout for Plasma (runs once, on a user's first Plasma start).
//
//  Top bar (slim, solid):
//      [mark  App  window title]  ·····  [ddd d MMM  HH:mm]  ·····  [CPU ▬ 5%  RAM ▬ 23%] [tray] [power]
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

// System tray with only the essentials. Each tray item is a full applet inside
// plasmashell, and some start daemons (KDE Connect), so the list is explicit.
// "knownItems" must also name the ones we hide: the tray auto-adds any item it
// has never seen before.
var tray = top.addWidget("org.kde.plasma.systemtray");
var trayContainment = desktopById(tray.readConfig("SystrayContainmentId"));
if (trayContainment) {
    var shown = [
        "org.kde.plasma.notifications",
        "org.kde.plasma.volume",
        "org.kde.plasma.networkmanagement",
        "org.kde.plasma.bluetooth",
        "org.kde.plasma.battery",
        "org.kde.plasma.brightness",
        "org.kde.plasma.devicenotifier",
        "org.kde.plasma.clipboard",
        "org.kde.plasma.keyboardlayout",
        "org.kde.plasma.mediacontroller"
    ];
    var hidden = [
        "org.kde.kdeconnect",
        "org.kde.plasma.printmanager",
        "org.kde.plasma.vault",
        "org.kde.plasma.cameraindicator",
        "org.kde.plasma.keyboardindicator",
        "org.kde.plasma.manage-inputmethod",
        "org.kde.plasma.nightlight",
        "org.kde.plasma.weather",
        "org.kde.kscreen",
        "org.kde.plasma.addons.katesessions",
        "org.kde.plasma.vault"
    ];
    trayContainment.currentConfigGroup = ["General"];
    trayContainment.writeConfig("extraItems", shown);
    trayContainment.writeConfig("knownItems", shown.concat(hidden));
}
top.addWidget("org.kde.plasma.lock_logout");

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
