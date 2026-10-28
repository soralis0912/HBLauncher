# Seedsow port

A Lua port of the HBLauncher menu that runs inside **Seedsow Lullaby**, through
the [Seedsow Lua editor](https://github.com/soralis0912/seedsow-lua-editor).
Where the [`smilebasic/`](../smilebasic) bridge runs GPU apps through SmileBASIC
on Switch 2, this port runs as an ordinary Lua program in a game save slot: no
PC, Pico or network is required.

`launcher.lua` is the whole port. It lists the programs installed in the game's
save slots and launches the selected one. Entries are save slots, so a slot can
hold a Lua program or any other content its slot launcher opens — the menu is
not limited to Lua.

## How it is used

The Seedsow Lua editor embeds this folder as a submodule and its build places
`launcher.lua` in a user slot:

- **Fresh install:** a freshly built editor save ships the launcher in **slot 4**.
- **Existing install:** install it from the running editor into the opposite
  A/B side, the same way the editor updates itself.

See the editor's build and the A/B editor sides documentation for the install
details.

## Controls

| Input | Action |
| --- | --- |
| Up / Down | Move the selection |
| A | Launch the selected slot in the running session |
| B | Stop the running program and return to the editor |
| Y (in the editor) | Re-run the launcher to reopen the menu |

The editor reserves **B** to stop any running program and return to the editor,
so a launched program — and the menu itself — exits with B. From the editor,
**Y / RUN buffer** re-runs the launcher.

## Program interface

`launcher.lua` follows the editor's Lua program interface. The editor runs the
chunk with `(engine, editor)` and uses its returned function as the per-frame
update. It uses the editor-provided API: `screen`, `label`, `rect`, `read`,
`slot`, and the calibrated input helpers `held(name)` / `pressed(name)` for
`A B X Y L R Up Down Left Right`.
