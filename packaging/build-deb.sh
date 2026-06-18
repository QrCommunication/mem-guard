#!/usr/bin/env bash
#
# build-deb.sh — Construit le paquet mem-guard_<version>_all.deb
#
# Assemble l'arborescence Debian à partir des sources du dépôt et produit le
# .deb dans dist/. Architecture : all (python + shell, indépendant du CPU).
#
set -euo pipefail

VERSION="0.0.1"
PKG="mem-guard"
ARCH="all"
MAINTAINER="Rony <ronylicha@gmail.com>"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build/${PKG}_${VERSION}_${ARCH}"
DIST="$ROOT/dist"

rm -rf "$BUILD"
mkdir -p "$BUILD/DEBIAN" \
         "$BUILD/usr/bin" \
         "$BUILD/usr/lib/systemd/user" \
         "$BUILD/usr/share/applications" \
         "$BUILD/usr/share/doc/$PKG"
mkdir -p "$DIST"

# --- Binaires + unités ------------------------------------------------------
install -m 0755 "$ROOT/src/mem-guard"          "$BUILD/usr/bin/mem-guard"
install -m 0755 "$ROOT/src/mem-guard-summon"   "$BUILD/usr/bin/mem-guard-summon"
install -m 0644 "$ROOT/systemd/mem-guard.service" "$BUILD/usr/lib/systemd/user/mem-guard.service"
install -m 0644 "$ROOT/data/mem-guard.desktop" "$BUILD/usr/share/applications/mem-guard.desktop"

# --- Documentation ----------------------------------------------------------
install -m 0644 "$ROOT/README.md"   "$BUILD/usr/share/doc/$PKG/README.md"
install -m 0644 "$ROOT/LICENSE"     "$BUILD/usr/share/doc/$PKG/copyright"
install -m 0755 "$ROOT/scripts/setup-shortcut.sh" "$BUILD/usr/share/doc/$PKG/setup-shortcut.sh"
mkdir -p "$BUILD/usr/share/doc/$PKG/docs"
install -m 0644 "$ROOT"/docs/*.md   "$BUILD/usr/share/doc/$PKG/docs/" 2>/dev/null || true
gzip -9 -n -c "$ROOT/CHANGELOG.md" > "$BUILD/usr/share/doc/$PKG/changelog.gz"

# --- control ----------------------------------------------------------------
SIZE_KB=$(du -sk "$BUILD/usr" | cut -f1)
cat > "$BUILD/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: python3, python3-gi, python3-psutil, gir1.2-gtk-3.0, gir1.2-ayatanaappindicator3-0.1 | gir1.2-appindicator3-0.1, wmctrl
Recommends: gnome-shell-extension-appindicator
Installed-Size: $SIZE_KB
Maintainer: $MAINTAINER
Homepage: https://github.com/QrCommunication/mem-guard
Description: moniteur mémoire + gestionnaire de crise RAM/CPU
 mem-guard surveille la RAM/le swap/la charge en continu (boîte noire CSV +
 alertes anti-freeze) et fournit un gestionnaire de processus sur mesure :
 liste de chaque process avec son titre de fenêtre (kitty, tmux, VS Code,
 gnome-terminal résolus précisément), CPU %, RAM, et des boutons pour
 terminer / forcer / redémarrer un process.
 .
 L'application a la priorité CPU/I/O et l'immunité OOM pour rester réactive
 quand le PC sature, et peut surgir au premier plan via un raccourci clavier
 (Ctrl+Alt+Suppr).
EOF

# --- postinst : autostart au login (service --user global) ------------------
cat > "$BUILD/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
systemctl daemon-reload 2>/dev/null || true
# Active le service utilisateur pour TOUS les utilisateurs à leur prochaine session
systemctl --global enable mem-guard.service 2>/dev/null || true
update-desktop-database -q /usr/share/applications 2>/dev/null || true
echo "mem-guard installé. Il démarrera à la prochaine ouverture de session."
echo "Démarrage immédiat : systemctl --user start mem-guard"
echo "Raccourci Ctrl+Alt+Suppr : /usr/share/doc/mem-guard puis scripts/setup-shortcut.sh"
exit 0
EOF
chmod 0755 "$BUILD/DEBIAN/postinst"

# --- prerm : désactive le service avant suppression ------------------------
cat > "$BUILD/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e
systemctl --global disable mem-guard.service 2>/dev/null || true
exit 0
EOF
chmod 0755 "$BUILD/DEBIAN/prerm"

# --- postrm : nettoyage -----------------------------------------------------
cat > "$BUILD/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
systemctl daemon-reload 2>/dev/null || true
update-desktop-database -q /usr/share/applications 2>/dev/null || true
exit 0
EOF
chmod 0755 "$BUILD/DEBIAN/postrm"

# --- Build ------------------------------------------------------------------
OUT="$DIST/${PKG}_${VERSION}_${ARCH}.deb"
dpkg-deb --root-owner-group --build "$BUILD" "$OUT"
echo
echo "✅ Paquet construit : $OUT"
dpkg-deb --info "$OUT" | sed 's/^/   /'
