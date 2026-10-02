# Touch menus and gameplay

The first real screen touch used to enable TouchControls and turn off
`Input.emulate_mouse_from_touch`. Godot's normal Control buttons still depend on
those emulated mouse events, so New Game, character selection, HUD Menu, and menu
buttons stopped responding. Keep emulation enabled in both control modes.

Mouse scooping now has its own `scoop_mouse` action, used only while touch controls
are off. Space and the multi-touch SCOOP button keep the original `scoop` action.
This prevents an emulated click on a movement arrow from scooping, and prevents
an emulated mouse release from releasing another finger's held SCOOP action.
The first-game instructions use touch labels when touch controls are active.

Run the focused engine check with an isolated save directory:

```sh
XDG_DATA_HOME=/tmp/drain-touch-test godot --headless --path . --script res://tests/touch_input.gd
```

An actual Godot 4.6.3 web export was also exercised inside Scryproof's local
sandboxed Activities frame with Chrome touch emulation: portrait title tap,
character selection, landscape movement and SCOOP, HUD menu and Resume, rotation,
Back/return without reloading, saved character and nonzero water, and reopening.
An existing encrypted local call stayed connected. These are browser-emulation
checks, not physical iPhone, iPad or Android acceptance.

The tested Scryproof game export starts from Matt's local `b26ac6e` (the same
source as the hosted Activities game), plus these fixes. Upstream master is
currently older than that hosted source. This PR contains only the mobile fixes;
do not rebuild the hosted activity from the older upstream base and accidentally
remove the existing gameplay changes. Apply the fixes to the hosted source,
export on the workstation, then use Scryproof's existing validated game publisher
only after review. The Scryproof layout fix is a separate client PR.
