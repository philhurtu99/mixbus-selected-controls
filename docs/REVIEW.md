# Developer review notes

## Proposed behavior

Native selected-route edits for Mixbus 12.1 (`mixbus+12.1`, base `3c365afcc0b029b29ea57e111e6845a509d04fef`). Exported feature commit: `3574b119353396af85da3af0ae2da158aee39491`.

The patch links compatible manual mixer controls and matching processor bypass states across selected routes. It also adds independent plugin instances across selected routes from chooser/plugin-favorite drops, matching-occurrence deletion from a hovered processor entry, selection retention during processor interactions, and configurable opening of inserted editor batches.

## Main code paths

| File | Responsibility |
| --- | --- |
| `libs/ardour/route.cc` / `ardour/route.h` | Semantic counterpart lookup for channelstrip roles, sends and user plugin controls. |
| `libs/ardour/automation_control.cc` | Selection propagation, automation/RT/loading guards and recursion guard. Existing multi-control groups remain authoritative. |
| `libs/ardour/plug_insert_base.cc` | Forward external plugin parameter notifications without writing back to the source callback. |
| `gtk2_ardour/automation_controller.cc`, `generic_pluginui.cc` | Generic UI edits use grouping disposition and Shift override. |
| `gtk2_ardour/lv2_plugin_ui.cc` | Custom LV2 scalar port edits use the selection-aware path instead of forcing NoGroup. |
| `gtk2_ardour/mixbus_widgets.mb.cc` | Mixbus knob/toggle grouping behavior. |
| `gtk2_ardour/processor_box.cc` / `.h` | Processor enable matching, independent insert copies, captured deletion targets, batch editor opening and the existing single-window preference action. |
| `gtk2_ardour/ardour_ui_keys.cc` | Hover Delete before window accelerators; scoped to the processor list in the event window. |
| `gtk2_ardour/mixer_ui.cc` | Processor-origin mouse releases preserve an existing multi-route selection. |
| `gtk2_ardour/ardour.menus.in` | Standard checkbox beside New Plugin, reusing an existing translated preference label. |

## Matching and boundaries

Channelstrip parameters use well-known roles. Built-in sends use their stable destination slots; auxiliary send levels use target IDs. User plugins match by format, exact unique ID and occurrence rather than chain position. Mono/stereo identities remain distinct. Main Fader bypass maps to the exact route Amp, not trim.

The propagation path excludes Master/Monitor and unselected routes, loading/deletion and audio process threads; source and target parameters must have automation state Off and compatible ranges/toggle semantics. NoGroup/ForGroup avoid recursive expansion. Native plugin UI callback behavior remains format-dependent; only the listed LV2 custom UIs have actual GUI coverage.

Insertion copies receive regenerated IDs and route-specific IO configuration; sidechain names and custom pin maps are removed from the cloned insert state. The original insertion succeeds independently of peer compatibility; failed peer routes are reported. Deletion targets are resolved before any removal so repeated occurrence indices do not shift mid-operation. Hover deletion protects built-in strip processors, faders and sends. Shift and the quick-group preference govern selected peer operations.

The chooser inserts the complete batch before opening editors. The existing `one-plugin-window-only` preference means only the first editable newly added instance is opened. With it off, every added instance editor opens with a native UI where available and a generic fallback. The general automatic-open preference is also respected. The context menu and Preferences share one stored setting. Normal single-click strip-name selection remains unchanged.

## Validation

- Linux native build and install, GCC 16/C++17; installed binary hash matches the build.
- Integration fixture: 75 controls, 375 synchronous edits, different chain positions, repeated plugin instances, quick-group off, NoGroup, target automation and deselection.
- Actual private GUI tests: EQ/Comp/Gate/Fader enable across selected pair; unselected track isolation and Shift-click.
- Custom LV2: XT-GV Dry/Wet from 0.5 to 0.605 on the selected pair only; XT-DC graph and preset changes on matching mono instances.
- Plugin chain GUI: selected pair insertion with distinct IDs, hover Delete without selecting a processor first, Shift+Delete, second-instance removal across different chain positions, first instances and unselected route preserved.
- French GUI: selection retained while opening the chooser; two plugins added to two selected routes; one visible editor in single-window mode versus four new visible editors in all-window mode. Preference saved after clean exit. Existing French catalog label rendered normally without clipping.
- Machine-readable observations live in `tests/selected-controls/*.json`. Screenshots in `docs/screenshots/` are actual private test captures; windows were repositioned for documentation readability.

Generate catalogs with `./waf i18n_mo` before install. The menu reuses the existing translated msgid `Show only one plugin window at a time`; no parallel custom translation or preference was introduced.

## Review still required

This is an experimental AI-assisted contribution, not an upstream release. VST/VST3/AudioUnit custom UI compatibility, macOS builds, mixed-format/mono-stereo mapping, third-party proprietary properties and audio performance under large selections remain unverified. Tests of identical XT-DC mono instances did not reproduce the user's reported setup-specific failure. The repository includes no proprietary DSP or executable application. Existing source license/copyright notices are retained.

Please review matching scope, UI policy, duplication/IO behavior, real-time boundaries and interaction with upstream grouping/automation before considering integration.
