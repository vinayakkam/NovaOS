# Plasmoids

- `org.novaos.startmenu`: a Windows 11-style centered Start menu (skeleton). The default layout
  still uses Kickoff until this one is feature-complete.

Try it on a running Plasma 6 system:

```bash
kpackagetool6 -t Plasma/Applet -i plasmoids/org.novaos.startmenu   # first install
kpackagetool6 -t Plasma/Applet -u plasmoids/org.novaos.startmenu   # update
plasmoidviewer -a org.novaos.startmenu                             # standalone preview
```

`scripts/build-iso.sh` copies every folder here into `/usr/share/plasma/plasmoids/` in the ISO.
