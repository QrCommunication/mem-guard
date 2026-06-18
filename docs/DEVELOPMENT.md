# Développement & packaging

Guide du mainteneur : lancer depuis les sources, reconstruire le `.deb`, bumper
la version et publier une release.

## Structure du dépôt

```
src/mem-guard             Application Python/GTK3 (moniteur + tray + fenêtre)
src/mem-guard-summon      Réveil léger de l'instance (D-Bus → SIGUSR1 → cold start)
systemd/mem-guard.service Service utilisateur (autostart + priorités OOM/CPU)
data/mem-guard.desktop    Entrée du menu d'applications
scripts/setup-shortcut.sh Raccourci Ctrl+Alt+Suppr (GNOME, par utilisateur)
packaging/build-deb.sh    Construction du paquet .deb
docs/                     Documentation + capture d'écran
build/  dist/             Artefacts de build (gitignorés)
```

## Lancer depuis les sources (sans installer)

```bash
python3 src/mem-guard --open      # ouvre directement la fenêtre
python3 src/mem-guard             # mode service (tray + monitor, sans fenêtre)
```

Dépendances de dev : `python3-gi`, `python3-psutil`, `gir1.2-gtk-3.0`,
`gir1.2-ayatanaappindicator3-0.1`, `wmctrl`. Vérif syntaxe rapide :

```bash
python3 -m py_compile src/mem-guard
```

## Reconstruire le `.deb` après une modif des sources

```bash
./packaging/build-deb.sh        # → dist/mem-guard_<version>_all.deb
```

Le script assemble l'arborescence Debian à partir de `src/`, `systemd/`,
`data/`, `README.md`, `LICENSE`, `CHANGELOG.md`, génère `DEBIAN/control` +
les scripts `postinst`/`prerm`/`postrm`, puis appelle
`dpkg-deb --root-owner-group --build`.

### Tester le paquet localement

```bash
sudo apt install ./dist/mem-guard_0.0.1_all.deb   # installe + dépendances
systemctl --user start mem-guard                  # démarrage immédiat
# ... tester ...
sudo apt remove mem-guard                          # désinstaller
```

> ⚠️ Si une **installation manuelle** existe dans `~/.local` (ancienne version
> de dev), retire-la avant pour éviter deux services du même nom :
> ```bash
> systemctl --user disable --now mem-guard
> rm -f ~/.config/systemd/user/mem-guard.service \
>       ~/.config/systemd/user/graphical-session.target.wants/mem-guard.service \
>       ~/.local/bin/mem-guard ~/.local/bin/mem-guard-summon \
>       ~/.local/share/applications/mem-guard.desktop
> systemctl --user daemon-reload
> ```

## Bumper la version

La version est centralisée dans **`packaging/build-deb.sh`** (`VERSION="x.y.z"`).
Checklist (SemVer) :

1. Mettre à jour `VERSION` dans `packaging/build-deb.sh`.
2. Ajouter une section en haut de `CHANGELOG.md` (`## [x.y.z] - AAAA-MM-JJ`).
3. Commiter : `git commit -am "release: x.y.z"`.
4. Taguer : `git tag -a vx.y.z -m "mem-guard x.y.z" && git push origin main vx.y.z`.
5. Construire et publier la release (ci-dessous).

## Publier une release GitHub

```bash
VERSION=0.0.1

# 1. (Re)construire le .deb
./packaging/build-deb.sh

# 2. Archive des sources (fichiers suivis uniquement, pas de build/dist)
git archive --format=zip --prefix=mem-guard-$VERSION/ \
  -o dist/mem-guard-$VERSION-src.zip v$VERSION

# 3. Créer la release avec les deux assets
gh release create v$VERSION \
  --repo QrCommunication/mem-guard \
  --title "mem-guard $VERSION" \
  --notes-file <(sed -n "/## \[$VERSION\]/,/## \[/p" CHANGELOG.md | sed '$d') \
  dist/mem-guard_${VERSION}_all.deb \
  dist/mem-guard-$VERSION-src.zip
```

## Notes de packaging

- **Architecture `all`** : l'app est du Python + shell pur (aucun binaire
  compilé) → un seul `.deb` fonctionne partout. `dpkg-deb --root-owner-group`
  force `root:root` sur les fichiers même build en tant qu'utilisateur.
- **Service `--user` global** : l'unité est installée dans
  `/usr/lib/systemd/user/` et le `postinst` fait `systemctl --global enable
  mem-guard.service`. C'est le pattern propre pour qu'un `.deb` (installé par
  root) active une appli de session pour chaque utilisateur à son prochain
  login, sans toucher au home.
- **Dépendances** : `Depends:` liste les modules GI/psutil/wmctrl ; `apt`
  (et non `dpkg -i` seul) résout et installe ces dépendances automatiquement.
