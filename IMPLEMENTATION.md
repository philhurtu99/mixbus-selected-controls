# Native selected-channel controls for Mixbus 12.1

Upstream repository: `git://git.ardour.org/harrison/mixbus`
Base tag: `mixbus+12.1`
Base commit: `3c365afcc0b029b29ea57e111e6845a509d04fef`
Local branch: `native-selected-channel-controls`

This is a custom source build, not an official Harrison update. The change is compiled directly into Mixbus. No preload library, OSC bridge, timer, or separately enabled EQ Link application is involved. The usual `mixbus12.desktop` entry is overridden per user to launch this build. The vendor installation in `/opt/Mixbus-12.1.0` is retained as the original installation and supplies the licensed DSP and bundled content.

## Behavior

With two or more selected compatible tracks/channels, editing a channelstrip parameter applies the same parameter value to the others. EQ, filters, dynamics, de-esser, denoiser, pan, trim, bus sends, and compatible plugin parameters are matched by meaning. Existing multi-control groups, notably relative fader moves, retain their normal behavior. Shift/group override edits the original strip alone. Master/monitor, unselected tracks, and automation-controlled parameters are excluded. Selection by itself never copies settings. The existing quick-group preference disables this feature.

The source identifies channelstrip controls from their well-known role, matches built-in sends by bus slot, auxiliary sends by receiving bus, and user plugins by format/unique ID and occurrence. Plugins are never matched merely by chain index. Native plugin GUI parameter notifications are forwarded to compatible selected peers without writing back to the originating callback. Non-numeric plugin properties, application-wide actions and non-parameter routing menus are not generic channelstrip controls.

The processor-list on/off LEDs also apply the clicked state to corresponding processors on selected channels. Built-in processors match by channelstrip role and occurrence; user inserts match by format, unique ID and occurrence. Automated/locked bypass controls are skipped. Shift-click changes the clicked processor alone. The existing Ctrl+Shift whole-chain command retains its original behavior.

## Build and installation

Private build-only Boost headers: `~/.cache/mixbus-build-deps/usr/include`. No system packages were installed.

```
./waf configure --optimize --cxx17 --program-name=Mixbus --with-backends=alsa,jack,pulseaudio,dummy --prefix=/home/phil/.local/opt/mixbus-native --boost-include=/home/phil/.cache/mixbus-build-deps/usr/include --noconfirm
./waf -j12
./waf i18n_mo
./waf install
```

The unchanged licensed Harrison LADSPA DSP was copied from the vendor installation to the native build's `lib/ardour12/ladspa`. The Harrison VAMP module was also copied unchanged. The launcher retains access to the vendor LV2 plugins, sound content and video helper.

## Verification

The full application compiled with GCC 16 and C++17. `tests/selected-controls/integration.lua` passed 75 controls / 375 synchronous updates, unrelated-track isolation, different plugin positions, repeated plugin occurrences, quick-group preference, NoGroup override, target automation, deselection and clean teardown. Tests used a separate configuration and Dummy backend.

The actual GUI was then run on a private Xvfb display with a temporary session. A mouse drag changed Lo Gain from 0.5 to 0.5999999046325684 on both selected tracks while leaving the third unchanged; EQ enable followed on the same pair. A compressor ratio drag and gate-enable click also followed on the selected pair only. The GUI exited cleanly with code 0. `tests/selected-controls/gui-result.json` records the EQ drag state comparison.

## Installed entry points

- Standard launcher: `~/.local/bin/mixbus12`
- Standard desktop entry: `~/.local/share/applications/mixbus12.desktop`
- Native application: `~/.local/opt/mixbus-native/lib/ardour12/ardour-12.1.0`

The former EQ Link launcher, preload module and prototype project were removed after the integrated build passed verification. To revert to the vendor app, remove the per-user desktop override and launcher; the original `/usr/share/applications/mixbus12.desktop` and `/opt/Mixbus-12.1.0` remain available.

Processor-list LED verification: actual GUI clicks switched Gate, 32C EQ and Comp off and on on the selected pair only. Shift-click changed only the clicked track. Saved session parameter states were checked after each step; `tests/selected-controls/gui-led-result.json` records these results.

The Fader processor LED also links selected routes by their exact main Amp, independently of plugin matching. GUI verification passed off/on on both selected tracks, unselected-track isolation, unchanged trim and Shift-click override. States are recorded in `tests/selected-controls/gui-fader-result.json`.

## Scope and macOS transfer

This branch contains functional selected-channel control changes and tests only. No custom theme, colors, fonts, user configuration, licenses, proprietary DSP binaries or compiled application binaries are included.

A format-patch export of the feature commit can be applied to the exact Mixbus source base with `git am /path/to/mixbus-selected-controls.patch`. Start from tag `mixbus+12.1` / commit `3c365afcc0b029b29ea57e111e6845a509d04fef`. Other upstream revisions may require conflict resolution and retesting.

The modified code has only been built and tested on Linux. It is not a ready-to-install macOS app. macOS requires its own build and packaging, the matching Apple Silicon or Intel architecture, CoreAudio, platform build dependencies and the appropriate licensed Harrison macOS DSP. The source tree includes `tools/osx_packaging/osx_build`; Linux build flags, paths and DSP binaries above must not be reused as a Mac installer. Native plugin windows, keyboard modifiers and selected-control behavior still require verification on macOS.

For Harrison review, submit the patch and explain the requested behavior, matching rules, quick-group/Shift overrides and Linux test results. Harrison must review and decide whether to include it; no upstream submission or acceptance is implied by this local branch.

Custom LV2 UI fix: `LV2PluginUI::write_from_ui` previously forced NoGroup for scalar port edits. Mixbus now uses UseGroup unless Shift is held. Verified with an actual XT-GV GVerb+ custom UI drag: mix changed from 0.5 to 0.60500001907348633 on both selected tracks and remained 0.5 on the unselected track. ACE Reverb parameter tests were added. VST/VST3 custom UIs are not covered by this LV2-specific verification.

## Selected-channel plugin insertion and deletion

Plugin insertion through the chooser and plugin/favorite drag-and-drop creates an independent instance on every selected compatible peer route. Each copy gets fresh processor, automation and control IDs and configures its own IO. Matching insertion anchors use the main fader or processor identity/occurrence; if no counterpart anchor exists, the plugin is appended. Sidechain port names and custom pin maps are not cloned. Incompatible peers are reported in a dialog rather than silently ignored. This does not turn arbitrary Lua/API insertion or moving existing processors between channels into a multi-route operation.

Hover a plugin entry in the processor list and press Delete or Backspace to remove it and the matching occurrence on selected peer routes. Built-in channelstrip processors, faders and sends are protected from hover deletion. Window-level key dispatch handles this before normal accelerators; plugin windows and text controls outside the processor list retain their normal keyboard handling. Shift overrides linking; the quick-group preference still applies. All matching deletion targets are captured before removing any instance so occurrence indices cannot shift during a multi-plugin removal.

Actual GUI verification passed chooser insertion of ACE Delay on the selected pair with distinct processor IDs, hover deletion of ACE Reverb on the pair while preserving the third track's instance, Shift+Delete isolation, and deletion of the second reverb occurrence across different chain positions while preserving all first occurrences. See `tests/selected-controls/gui-plugin-chain-result.json`.

Drum Character custom-UI verification also passed graph-point dragging and a Tom Control preset click on selected identical mono instances, preserving the unselected instance; see `gui-drum-character-result.json`. The reported failure in the user's own setup has not been reproduced by these tests. Different plugin formats or mono/stereo identities are not treated as identical plugins.

## Selection retention, batch windows and localization

Mixer strip release handling now recognizes events originating inside the processor list. Clicking/opening processors on an already-selected strip preserves an existing multi-route selection; clicking strip names and adding previously unselected strips retains the existing selection rules. This prevents the first click of an add-plugin double-click from collapsing the selection.

Plugin chooser batches are inserted completely before their editors open. When automatic opening is enabled, every newly inserted instance, including selected peer copies, opens with its native editor when available and a generic fallback otherwise. Windows receive a small cascading offset. The existing `one-plugin-window-only` preference limits a batch to the first editable instance. It is exposed as a standard checkbox immediately after New Plugin in the processor context menu, sharing the same setting as Preferences > Plugins > GUI. No separate preference or conflicting translation was introduced. The menu action reuses the already-translated string `Show only one plugin window at a time` (the existing French translation was verified). The choice applies to subsequent openings and persists in the normal UI configuration.

Compile translation catalogs with `./waf i18n_mo` before install; NLS-enabled compilation alone does not generate the `.mo` files. The installed native build now includes those catalogs. GUI verification ran with `LANGUAGE=fr` in a private profile and confirmed that the checkbox fits the existing menu styling and is localized.

`tests/selected-controls/gui-plugin-window-result.json` records retained selection, two plugins inserted on two selected routes only, one visible instance window in single-window mode, four visible new windows in all-window mode, and preference persistence after a clean exit. Documentation screenshots in the companion GitHub patch repository illustrate the actual private GUI test session. Plugin windows were manually arranged for screenshot readability; their runtime default is a small cascade.
