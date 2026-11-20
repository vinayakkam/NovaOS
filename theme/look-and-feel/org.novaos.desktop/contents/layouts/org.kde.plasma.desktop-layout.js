// NovaOS "Twilight" layout for Plasma (runs once, on a user's first Plasma start).
//
//  Top bar (floating, three islands):
//            (app · window title)  ·····  (◔ ddd d MMM  HH:mm ◔)  ·····  [tray] [power]
//  Dock:     floating, centered, sized to its icons, moves out of the way of windows:
//            [NovaOS Start] [pinned / running apps]
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
top.height = 2 * Math.ceil(gridUnit * 2.0 / 2);
top.floating = true;
top.hiding = "none";

top.addWidget("org.novaos.activewindow");
top.addWidget("org.kde.plasma.panelspacer");
top.addWidget("org.novaos.topclock");
top.addWidget("org.kde.plasma.panelspacer");

// System tray with only the essentials. Each tray item is a full applet inside
// plasmashell (and some start daemons, e.g. KDE Connect), so the list is explicit.
var tray = top.addWidget("org.kde.plasma.systemtray");
var trayContainment = desktopById(tray.readConfig("SystrayContainmentId"));
if (trayContainment) {
    var items = [
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
    trayContainment.currentConfigGroup = ["General"];
    trayContainment.writeConfig("extraItems", items);
    trayContainment.writeConfig("knownItems", items);
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

dock.addWidget("org.novaos.startmenu");

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.kde.dolphin.desktop",
    "applications:firefox.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:org.kde.discover.desktop",
    "applications:org.novaos.settings.desktop"
]);
tasks.writeConfig("iconSpacing", 2);
tasks.writeConfig("indicateAudioStreams", false);
