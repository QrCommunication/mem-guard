# Architecture interne

Comment mem-guard fonctionne, et **pourquoi** ces choix — utile pour reprendre
le code sans contexte.

## Vue d'ensemble

```
┌──────────────────────────────────────────────────────────────┐
│ mem-guard (1 process Python, Gtk.Application, instance unique) │
│                                                                │
│  ┌──────────────┐   ┌──────────────┐   ┌────────────────────┐  │
│  │ Monitor 20 s │   │ AppIndicator │   │ Fenêtre (à la       │  │
│  │ boîte noire  │   │ (barre tâches)│  │ demande)            │  │
│  │ + alertes    │   │ couleur état │   │ liste process +     │  │
│  └──────────────┘   └──────────────┘   │ actions             │  │
│                                         └────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
        ▲ SIGUSR1 / D-Bus Activate
        │
  mem-guard-summon  ←──  raccourci Ctrl+Alt+Suppr
```

## Composants

| Fichier | Rôle |
|---|---|
| `src/mem-guard` | tout l'applicatif (monitor, tray, fenêtre, durcissement) |
| `src/mem-guard-summon` | réveille l'instance vivante sans relancer python |
| `systemd/mem-guard.service` | autostart + priorités (OOM/CPU/IO/mémoire) |
| `data/mem-guard.desktop` | entrée du menu d'applications |

## Instance unique

`MemGuardApp(Gtk.Application)` avec `application_id="org.rony.memguard"` et
`HANDLES_COMMAND_LINE`. Une 2ᵉ invocation (`mem-guard --open`) ne démarre pas
un second process : elle transmet la ligne de commande à l'instance primaire
(`do_command_line` → `--open` → `show_window`). Indispensable pour éviter deux
icônes de barre des tâches.

## Boucle de monitoring (boîte noire)

`monitor_tick()` toutes les 20 s :
- lit `/proc/meminfo` (RAM/swap), `loadavg`, top process RAM ;
- écrit une ligne CSV par mesure dans `~/.local/state/mem-guard/AAAA-MM-JJ.log`
  (post-mortem de freeze), avec rotation (14 j par défaut) ;
- met à jour la couleur de l'icône (ok / ⚠ / ❌) et le libellé RAM/Swap ;
- aux seuils : notification (throttlée) ; en critique, dump d'un fichier
  `incident-*.log` avec le top RAM. La notification est **cliquable** → ouvre
  le gestionnaire.

Tous les seuils sont surchargeables par variables d'environnement
(`MEMGUARD_WARN`, `MEMGUARD_CRIT`, `MEMGUARD_SWAP_WARN`, `MEMGUARD_INTERVAL`…).

## Fenêtre : rafraîchissement adaptatif

Le `TreeView` se rafraîchit toutes les **2 s uniquement quand la fenêtre est
visible** ; le timer est arrêté à la fermeture (qui masque au lieu de détruire).
En idle, mem-guard ne fait qu'une mesure légère toutes les 20 s — **un moniteur
ne doit jamais aggraver la pression mémoire** qu'il surveille.

## Continuité du CPU %

`psutil.Process.cpu_percent()` mesure le delta **depuis le dernier appel sur le
même objet**. Les objets `Process` sont donc **mis en cache** entre
rafraîchissements (`self._cache`), purgés des PID disparus. Sans ce cache, le
CPU afficherait toujours 0.

## Résolution du titre de fenêtre (le cœur)

Un CLI (claude, vim…) n'a pas de fenêtre X : c'est son **terminal** qui en a
une. On **remonte l'arbre des parents** du process jusqu'au premier ancêtre
présent dans l'un de trois annuaires, testés dans cet ordre (le plus profond,
donc le plus précis, gagne naturellement) :

| Annuaire | Source | Couvre |
|---|---|---|
| `kitty_map` | `kitty @ ls` (contrôle distant) → process avant-plan → `onglet › split` | kitty multi-fenêtres/onglets/splits |
| `panes` | `tmux list-panes -a` → `pane_pid → session:fenêtre` | tmux (serveurs détachés, sans fenêtre X) |
| `wins` | `wmctrl -lp` → `_NET_WM_PID → titre` | gnome-terminal, Chrome, Electron (VS Code/Cursor)… |

- **Pourquoi `kitty @ ls`** : kitty gère N onglets/splits dans **un** process →
  X ne voit qu'un seul `_NET_WM_PID`. Sans le contrôle distant, tous les CLI
  d'une même fenêtre kitty afficheraient le même titre. Nécessite
  `allow_remote_control` + `listen_on` côté kitty (cf. INSTALL.md).
- **Pourquoi tmux à part** : le serveur tmux est détaché de X (aucune fenêtre) ;
  seul tmux sait quel pane contient quoi.

## Priorité « au-dessus de tout »

Objectif : rester **vivant et réactif** quand le PC OOM/thrashe.

- **Service** (`mem-guard.service`) : `CPUWeight=10000`, `IOWeight=10000`
  (cgroup v2, sans privilège), `MemoryHigh/Max` avec marge, `OOMScoreAdjust`
  + `Nice` déclarés.
- **Durcissement réel** (`_harden_priority` au démarrage) : un service `--user`
  ne PEUT PAS abaisser son propre `oom_score_adj` ni passer en nice négatif
  sans privilège. mem-guard le fait via **`sudo -n`** (sans mot de passe) :
  `echo -1000 > /proc/self/oom_score_adj` + `renice -5`. Best-effort : sans le
  droit sudo, l'app reste fonctionnelle mais sans l'immunité `-1000`.

## Réveil instantané

Le raccourci exécute `mem-guard-summon`, qui **ne relance jamais python**
(trop lourd quand ça swappe) :
1. `gdbus … org.freedesktop.Application.Activate` (D-Bus, ≈0 coût) ;
2. sinon `pkill -USR1` → handler `SIGUSR1` → `show_window` ;
3. sinon, en dernier recours, démarrage à froid `mem-guard --open`.

`show_window` force `keep_above` + `stick` + `present` → la fenêtre surgit
au-dessus de tout, sur tous les bureaux, avec le focus.
