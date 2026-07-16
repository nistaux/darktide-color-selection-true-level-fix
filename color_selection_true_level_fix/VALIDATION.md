# Validated Version Combinations

This ledger records environment-specific in-game validation of Color Selection – True Level Compatibility Fix. A passing entry applies only to the exact three-mod tuple and runtime environment recorded below. An unlisted combination may work, but is not represented as validated.

## 2026-07-16 — Passed

### Validated Version Combination

| Mod | Version | Installation |
| --- | --- | --- |
| Color Selection – True Level Compatibility Fix | `1.0.0` | Package from repository commit `a6b9b737666bcfc395003c75d9b646f6daf8a3cb` |
| Color Selection | `2.15.0.0` | Unmodified archive |
| True Level | `1.10.1.0` | Installed dependency mod |

### Exact environment

| Component | Version or revision |
| --- | --- |
| Darktide | `1.12.0-b753204` |
| Steam build | `24006134` |
| Content revision | `133319` |
| DML | `26.6.24.0` |
| DMF | `26.6.24.0` |
| LuaJIT | `2.1.1779665312-1` |

The validation was performed on 2026-07-16 UTC in Austin's Windows Darktide/DMF environment. The implementation was introduced by `0491d53` and corrected after review by `a6b9b73`. Before live validation, all eight deployed MO2 package files were copied from the repository package and independently SHA-256 matched at the deployment boundary.

### Static and offline evidence

- Installed game, DMF, Color Selection, and True Level seam review: [`docs/research/v1-runtime-seam.md`](../docs/research/v1-runtime-seam.md).
- `luajit color_selection_true_level_fix/tests/run.lua` — passed: 15 passed, 0 failed.
- `luajit -b <file> NUL` over all Lua files under `color_selection_true_level_fix/` — passed: all 6 files compiled.
- The issue #7 two-axis review findings were corrected before deployment. Offline checks support, but do not replace, the live results below.

### Live checklist

| Check | Result | Evidence |
| --- | --- | --- |
| Mourningstar remote nameplates | Passed | An unhyphenated remote name and a hyphenated remote name both retained Color Selection's class-icon and exact full-name color. That color ended immediately after the complete name. True Level's character-level color, Havoc-rank color, title/newline, and later inline formatting remained intact. |
| Mission remote nameplates | Passed | All observed remote overhead player nameplates retained the same ownership and full-name boundary behavior. No malformed formatting was observed. |
| Local world-nameplate candidate | Not applicable | Normal first-person play exposed remote overhead player nameplates but never an overhead nameplate for the local character on either Supported Surface. No private instrumentation or fabricated marker was used. |
| Continuous surface transition | Passed | One launched game completed `Mourningstar -> mission -> Mourningstar`. Each `StateGameplay` entry began a new World Visit, processing resumed on every entry, and the constructor watcher and late update hook remained registered exactly once. |
| True Level `enable_nameplate` toggle | Passed | With a manually Color Selection-colored Mourningstar remote name present, `true -> false` removed True Level formatting cleanly while the exact Color Selection name color remained; `false -> true` restored the rich True Level formatting and correct color boundary without restart, stale formatting, flicker, or hook re-registration. Marker recreation and fresh Rich Suffix Snapshot capture are inferred from the restored correct rich output and the reviewed True Level lifecycle because those internal events are not logged directly. |
| Qualitative performance smoke | Passed | Populated missions and the Mourningstar showed no visible flicker, repeated-rewrite symptoms, obvious stutter, or malformed nameplates. No numeric frame-time threshold was used. |
| Hook registration and order | Passed | On every clean launch, Color Selection and True Level's delayed safe update hooks registered before the compatibility mod's late safe update hook. No duplicate compatibility hook registration occurred across World Visits. |
| Diagnostics and errors | Passed | No `hook_target_unavailable`, `hook_registration_failed`, relevant stack trace, compatibility-attributable stall, or compatibility log spam occurred. Naturally encountered Safe No-Change diagnostics were isolated and suppressed per World Visit. |
| Natural crash and reconnect | Passed as additional evidence | A mission crash was directly attributed to Auspex Helper, not the nameplate seam. After restart, Darktide explicitly reconnected to the strike team; mission and nameplate processing resumed, the mission completed, and the Mourningstar toggle check then passed. |

### Console-log evidence

Console logs are external runtime artifacts under Austin's Darktide `console_logs` directory; filenames and line references are recorded here without copying player-identifying content into the repository.

- `console-2026-07-16-01.28.54-e0ac6d00-bed1-48c5-b368-50c193cdd696.log`: corrected focused Mourningstar retest. Class readiness and constructor registration appear at lines 1994–1996; Color Selection, True Level, and compatibility update hooks register in order at 1998–2000. The log also contains hub, mission, and return entries at 1549, 2632, and 3772 without duplicate registration.
- `console-2026-07-16-01.52.19-4000da07-0556-4c39-8af5-75897ef99c07.log`: visually checked mission run and continuous return. Required hook order appears at 1998–2004; gameplay entries appear at 1552, 3265, and 5029; processing diagnostics reappear per World Visit at 2120, 3566/4295, and 5374 without hook re-registration.
- `console-2026-07-16-02.26.09-bff32223-c937-41a9-8eaf-90817ea5b5d2.log`: preliminary Mourningstar toggle observation. Hook order appears at 1991–1997 and one bounded diagnostic at 2091. This run had no Color Selection-owned remote candidate and is not the decisive toggle-recovery evidence.
- `console-2026-07-16-02.36.39-7d12a72b-addd-4c7d-ac47-93553fe4ff4f.log`: extended 65-minute performance and lifecycle smoke across five Mourningstar and four mission World Visits. Hook order appears once at 1970–1976. Ten diagnostics are isolated across the nine visits at lines 2068, 3059, 4026, 6004, 6729, 7800, 8673, 9597, 10996, and 12096, with no per-frame spam or relevant stack trace.
- `console-2026-07-16-03.42.22-2fd2ba68-6208-4873-9ed0-77da257da509.log`: the compatibility hook order is correct at 2015–2021. The terminal Lua crash at 109208/109403–109405 is directly in `AuspexHelper/ui/auspex_practice_view.lua:655`, where `inside_frustum` received stale userdata; the compatibility mod, Color Selection, True Level, and nameplate code are absent from the crash chain.
- `console-2026-07-16-04.02.46-ecd63bca-bb2f-4802-92cc-a8024a9a70a5.log`: explicit strike-team reconnect at 1225–1226, required hook order at 1880–1886, mission score end at 25990, transition to end-of-round at 26086, non-error session exit at 26205, Mourningstar return at 26475, resumed processing at 26814, and clean user shutdown at 27038. This session contains the decisive manually colored remote-name toggle observation; setting transitions themselves are not logged.

Across these corrected sessions, 22 naturally occurring Compatibility Diagnostics were recorded: 12 `leading_color_tag_unusable (tag_stage=missing)`, 8 `owned_span_formatting_interrupted`, and 2 `nameplate_structure_unusable (structure_stage=world_marker_map)`. They were bounded to at most one occurrence of each reason per World Visit, produced no identifying payload, and did not correlate with a visible defect in the observed nameplates. Their presence is fail-closed evidence, not a claim that every runtime candidate was splice-compatible.

### Remaining limitations

- This validation claim does not extend to any different Darktide, DML, DMF, or three-mod version tuple.
- Team HUD panels and views other than mission and Mourningstar player world nameplates remain outside version-one scope.
- No local-character overhead nameplate was exposed, so local coverage is not applicable to this entry rather than positively exercised.
- Whole Dependency Mod disable/enable cycles within one World Visit remain outside the validated contract. Restart Darktide after toggling an entire Dependency Mod.
- True Level setting-transition timestamps, internal marker recreation, and Rich Suffix Snapshot capture are not directly instrumented; the toggle result is based on rendered behavior plus reviewed lifecycle code.
- The crash/reconnect path occurred naturally and passed after reconnect, but deliberate disconnect and other error-recovery paths were not exhaustively exercised.
- Performance evidence is qualitative; no repeatable numeric frame-time benchmark currently exists.
