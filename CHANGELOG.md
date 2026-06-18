# Changelog

Toutes les modifications notables de ce projet sont documentées ici.
Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/),
versionnage [SemVer](https://semver.org/lang/fr/).

## [0.0.1] - 2026-06-19

### Ajouté
- Boîte noire mémoire : journalisation CSV continue (RAM/swap/charge/top
  process) pour post-mortem de freeze, avec rotation des logs.
- Alertes anti-freeze (notifications) aux seuils RAM élevée / RAM critique /
  swap élevé, avec throttle.
- Icône permanente dans la barre des tâches (AppIndicator), couleur selon la
  sévérité, démarrage automatique à l'ouverture de session.
- Gestionnaire de processus GTK : liste de chaque process (PID, nom, titre de
  fenêtre, CPU %, RAM %, RAM Mo, utilisateur), tri par colonne, filtre.
- Résolution précise du titre de fenêtre par remontée de l'arbre des process :
  - `gnome-terminal`, Chrome, Electron (VS Code / Cursor) via `_NET_WM_PID` ;
  - `kitty` (multi-fenêtres / onglets / splits) via le contrôle distant
    `kitty @ ls` (process avant-plan → onglet › split) ;
  - `tmux` (sessions détachées) via `tmux list-panes` (session:fenêtre).
- Actions sur la sélection : **Terminer** (SIGTERM), **Forcer** (SIGKILL),
  **Redémarrer** (best-effort : capture cmdline/cwd/env avant de tuer puis
  relance détachée).
- Instance unique (Gtk.Application) — pas de double icône.
- Priorité système : immunité OOM (`oom_score_adj=-1000`), priorité CPU
  (`nice=-5`), `CPUWeight`/`IOWeight` max, marge mémoire.
- Réveil au premier plan via raccourci clavier (Ctrl+Alt+Suppr) — sans
  relancer d'interpréteur (D-Bus / SIGUSR1).
- Paquet `.deb` : installe l'app + dépendances + service d'autostart.
