# Omamemo

Keep your brain live while your agents are working.

Omamemo is a tiny 4×4 memory game for the Omarchy bar. Click the bar widget to
flip 16 system-inspired glyph cards, match all eight pairs, and chase your
fastest local time. Your best score is saved on this machine, so there is no
account, leaderboard, or network traffic to slow down the fun.

## Requirements

- Omarchy 4.0 or newer

## Install

From the public repository, run:

```bash
omarchy plugin add https://github.com/sahzudin/omamemo.git --enable
```

For a local checkout, replace the URL with the checkout path.

The plugin adds an `Omamemo` ◈ widget to the bar. Click it to open the game;
right-click the widget to start a fresh board.

## Remove

Remove Omamemo through Omarchy's plugin manager:

```bash
omarchy plugin remove io.github.sahzudin.omamemo
```

The command disables the widget before removing its checkout. It keeps your
locally saved best time; delete
`$XDG_STATE_HOME/omamemo/best.json` (or
`~/.local/state/omamemo/best.json`) separately only if you want to reset it.

## Development

Validate the plugin manifest and QML entrypoints with:

```bash
omarchy plugin validate .
```

The game stores the best time at
`$XDG_STATE_HOME/omamemo/best.json` (or
`~/.local/state/omamemo/best.json` when `XDG_STATE_HOME` is unset).

## License

MIT
