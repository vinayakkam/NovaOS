// NovaOS default Plasma layout (runs once, the first time a user's Plasma starts).
//
// One floating, full-width bottom panel. Flexible spacers on both sides keep the
// launcher + pinned apps centered; tray and clock sit at the right edge.

var WALLPAPER = "/usr/share/wallpapers/NovaOS/";

// Desktop wallpaper
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file://" + WALLPAPER);
}

// Taskbar
var panel = new Panel;
panel.location = "bottom";
panel.height = 2 * Math.ceil(gridUnit * 2.4 / 2);
panel.floating = true;
panel.hiding = "none";

panel.addWidget("org.kde.plasma.panelspacer");   // flexible: pushes the center group

var launcher = panel.addWidget("org.kde.plasma.kickoff");
launcher.currentConfigGroup = ["General"];
launcher.writeConfig("icon", "novaos-start");
launcher.writeConfig("favoritesDisplay", 0);       // grid of pinned apps
launcher.writeConfig("applicationsDisplay", 1);    // list of all apps
launcher.writeConfig("primaryActions", 0);

var tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.kde.dolphin.desktop",
    "applications:firefox.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:systemsettings.desktop"
]);
tasks.writeConfig("iconSpacing", 2);

panel.addWidget("org.kde.plasma.panelspacer");   // flexible

panel.addWidget("org.kde.plasma.systemtray");

var clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", "BelowTime");

panel.addWidget("org.kde.plasma.showdesktop");
