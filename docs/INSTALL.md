# Installation & configuration

## Prérequis

- Linux de bureau **GNOME / Zorin OS**, session **X11** (la résolution des
  titres de fenêtre et le raccourci s'appuient sur X11).
- Le support des icônes de barre des tâches (AppIndicator). Sur GNOME pur,
  l'extension `gnome-shell-extension-appindicator` est recommandée (tirée
  automatiquement par le paquet) ; sur Zorin elle est déjà présente.

## Installer le paquet `.deb`

```bash
sudo apt install ./mem-guard_0.0.1_all.deb
```

`apt` installe les dépendances (`python3-gi`, `python3-psutil`,
`gir1.2-gtk-3.0`, `gir1.2-ayatanaappindicator3-0.1`, `wmctrl`) et active le
service utilisateur. Il démarrera **à la prochaine ouverture de session**.

Démarrer immédiatement (session courante) :

```bash
systemctl --user start mem-guard
```

Vérifier :

```bash
systemctl --user status mem-guard
```

## Raccourci Ctrl+Alt+Suppr

À lancer **dans ta session graphique** (pas en root) :

```bash
/usr/share/doc/mem-guard/setup-shortcut.sh            # si fourni
# ou depuis les sources :
./scripts/setup-shortcut.sh /usr/bin/mem-guard-summon
```

Cela libère la déconnexion par défaut de GNOME (qui occupe Ctrl+Alt+Del) et lie
la combinaison à l'ouverture de mem-guard, **au-dessus de tout**.

Rétablir l'ancien comportement (Ctrl+Alt+Del = déconnexion) :

```bash
gsettings set org.gnome.settings-daemon.plugins.media-keys logout "['<Control><Alt>Delete']"
```

## Immunité OOM (priorité absolue) — optionnel mais recommandé

Pour que mem-guard ne soit **jamais** tué quand le PC sature, il abaisse son
`oom_score_adj` à `-1000` au démarrage via `sudo -n`. Cela nécessite que ton
utilisateur puisse exécuter `sudo` **sans mot de passe**. Sans ce droit, l'app
reste pleinement fonctionnelle mais sans l'immunité `-1000` (dégradation
silencieuse, aucun plantage).

Vérifier que c'est actif :

```bash
PID=$(systemctl --user show mem-guard -p MainPID --value)
cat /proc/$PID/oom_score_adj      # doit afficher -1000
```

## Mapping précis des onglets/splits kitty

Par défaut, kitty n'expose pas son contenu. Pour que mem-guard distingue
**chaque onglet/split** kitty, active le contrôle distant dans
`~/.config/kitty/kitty.conf` :

```conf
allow_remote_control socket-only
listen_on unix:/tmp/kitty-{kitty_pid}
```

Effet **immédiat pour toute nouvelle fenêtre kitty** ; les fenêtres kitty déjà
ouvertes nécessitent un redémarrage de kitty (le socket ne peut pas être ajouté
à chaud). Sans cela, les CLI d'une même fenêtre kitty partagent le titre de la
fenêtre.

## Désinstaller

```bash
sudo apt remove mem-guard       # retire l'app + désactive le service
sudo apt purge mem-guard        # idem + nettoyage
```

Les logs de la boîte noire restent dans `~/.local/state/mem-guard/`
(supprime-les manuellement si tu veux).

## Migration depuis une installation manuelle (`~/.local`)

Si tu avais une version de dev dans `~/.local`, retire-la pour éviter deux
services du même nom (double icône) :

```bash
systemctl --user disable --now mem-guard
rm -f ~/.config/systemd/user/mem-guard.service \
      ~/.config/systemd/user/graphical-session.target.wants/mem-guard.service \
      ~/.local/bin/mem-guard ~/.local/bin/mem-guard-summon \
      ~/.local/share/applications/mem-guard.desktop
systemctl --user daemon-reload
systemctl --user enable --now mem-guard
```
