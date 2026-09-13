# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Stack

delegated: standalone Luau source loaded through Potassium's documented executor APIs; not a Roblox Studio project and not a ModuleScript

## Users

Roblox script authors who execute independent Luau scripts through Potassium and need a reusable in-game control surface.

## Product Purpose

Surge provides a compact, reusable UI layer for executor-run scripts. Success means a script can load one self-contained library, build a window with consistent controls, receive callbacks, update values programmatically, and unload cleanly without leaving GUI instances or connections behind.

## Positioning

A self-contained, monochrome, code-drawn UI library designed around Potassium's documented runtime primitives rather than Studio packaging or remote model assets.

## Operating Context

Scripts are loaded from Potassium's workspace-relative filesystem using documented `loadfile`/`readfile` behavior, then execute in a Roblox client. The preview is a standalone script outside the library folder that loads the library from the Potassium workspace and exercises the public API.

## Capabilities and Constraints

- The library must use only documented or standard Roblox Luau APIs that are available to an executor-run script.
- File paths exposed in documentation are relative to Potassium's `workspace` directory; the requested local project directory is `.Surge`.
- UI is parented to Potassium's documented `gethui()` container when available.
- No Studio-only packaging, ModuleScript requirement, remote model dependency, or invented anti-detection guarantee.
- Palette is limited to black, white, and grayscale values. Callbacks remain outside component logic.
- The optional bootstrap intentionally refreshes the current `main`-branch library and bridge on every invocation; local loading remains available offline and does not claim release reproducibility.
- Repeated loading with the same window id must tear down the prior instance before creating the new one.
- All implemented components need handles with predictable setters/getters where a value exists.

## Brand Commitments

The product name is Surge. The logo is a simple lightning/zap mark. The visual language is compact, rounded, monochrome, translucent, and recognizably distinct from Rayfield while informed by its documented window/tab/component model and Rayfield Gen2's documented lifecycle and element handles.

## Evidence on Hand

The original implementation brief, the Potassium API reference, Rayfield and Rayfield Gen2 documentation, and Lucide's official guide/license. No existing Surge code, assets, customer proof, or production screenshots were supplied; preview content is illustrative.

## Product Principles

1. Keep the public API boring, explicit, and composable.
2. Keep UI state and script behavior separate through callbacks and handles.
3. Prefer local code-drawn visuals over undocumented assets or remote dependencies.
4. Make lifecycle and cleanup first-class so repeated loads are safe.
5. Document executor assumptions instead of implying guarantees the runtime does not provide.

## Accessibility & Inclusion

Controls retain visible text labels and descriptions; icon-only controls use tooltips/visible title metadata where Roblox permits. Interactive targets are kept comfortably sized for touch and mouse use, and state is not communicated by color alone.
