#!/usr/bin/env bash
#
# setup-shortcut.sh — Lie Ctrl+Alt+Suppr à l'ouverture de mem-guard (GNOME/Zorin).
#
# Per-utilisateur (gsettings/dconf) : à lancer dans ta session graphique, PAS
# en root. Libère la déconnexion par défaut qui occupe Ctrl+Alt+Del, puis crée
# un raccourci personnalisé sans écraser les tiens.
#
set -euo pipefail

MK=org.gnome.settings-daemon.plugins.media-keys
KB=$MK.custom-keybinding
P=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/memguard/
CMD="${1:-mem-guard-summon}"      # commande à lier (défaut : mem-guard-summon dans le PATH)
BIND="${2:-<Primary><Alt>Delete}" # combinaison (défaut : Ctrl+Alt+Suppr)

if ! command -v gsettings >/dev/null 2>&1; then
    echo "gsettings introuvable — ce script cible GNOME/Zorin." >&2
    exit 1
fi

echo "Ancien binding 'logout' (sera libéré) : $(gsettings get $MK logout)"
gsettings set "$MK" logout "[]"

CUR=$(gsettings get "$MK" custom-keybindings)
case "$CUR" in
    *memguard*) NEW="$CUR" ;;
    "@as []"|"[]") NEW="['$P']" ;;
    *) NEW="${CUR%]}, '$P']" ;;
esac
gsettings set "$MK" custom-keybindings "$NEW"

gsettings set "$KB:$P" name 'mem-guard (gestionnaire de crise)'
gsettings set "$KB:$P" command "$CMD"
gsettings set "$KB:$P" binding "$BIND"

echo "OK — $BIND → $CMD"
echo "Test : presse Ctrl+Alt+Suppr, la fenêtre doit surgir au premier plan."
echo "Annuler : gsettings set $MK logout \"['<Control><Alt>Delete']\""
