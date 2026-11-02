# Flash Interact

Apply consistent ProximityPrompt distance, hold-duration and line-of-sight settings. Preview the changes first, then apply the batch with Studio undo.

## Install

1. Download/extract the repository. No runtime packages are required.
2. In a separate Studio test place, use Explorer's **Insert from File** to insert `FlashInteract.rbxmx`.
3. Select its root Script (five child ModuleScripts) and choose **Save as Local Plugin**.
4. Remove the imported root from the place. Open **Flash Interact → Prompts** on the Plugins toolbar.

The plugin refuses its work during play tests. The dock panel follows Studio's theme.

## Use it

Select prompts directly, or select a Model/folder and choose **Include descendants**. Enter activation distance (0–100 studs), hold duration (0–60 seconds) and the line-of-sight option. Preview and apply after checking the old/new values. The limits are this tool's policy.

ActionText, ObjectText, Enabled, key bindings and other prompt properties are left alone. A no-op preview adds no undo recording. Changing selection/options clears the preview; changing a target's parent or any of the three edited values makes Apply refuse it.

Scopes are bounded to 500 roots, 5000 discovered objects and 1000 prompts. Overlapping roots are deduplicated. Services themselves are refused. New descendants and previously unchanged targets are not added to an existing plan. At most 100 preview rows are shown; Apply covers every change in the plan.

**Prompt settings are not server authorization or anti-cheat.** Clients can manipulate interaction behavior. Your gameplay handler must validate permission, state and distance on the server. This plugin does not inspect or change those handlers. See Roblox's [client/server boundary guidance](https://create.roblox.com/docs/scripting/security/client-server-boundary) and [ProximityPrompt API](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt).

`Rules.plan(rows, options)` takes captured values and `{distance, hold, lineOfSight}`. `Adapter` reads and writes the three prompt properties. `Scope` collects targets; `Transaction` uses Studio recording commit/cancel calls. Failed writes ask Studio to cancel the batch, rather than implementing a separate undo stack.

## Development and checks

Source is in `src`. Rebuild with Python 3.11+; run logic checks with Lune 0.11.1:

```sh
python build.py
python -m unittest discover -s tests -v
lune run tests/run
```

CI compiles every source file, tests rules/adapters with fake Studio objects, checks the packaged source and rebuilds it for comparison. Lune is installed on GitHub's runner, not your PC. Common UI/scope/recording helpers are copied into individual Flash repos so they install independently.

**Local-plugin installation, dock behavior and native Studio undo have not been verified live.** The path generator has no undo recording. See [Studio checks](docs/STUDIO-CHECKS.md). Automated checks do not establish live game integration.

MIT licensed. See [LICENSE](LICENSE).
