# Surge assets

`LucideBridge.lua` is the runtime icon adapter. It vendors a small, local subset of the Lucide.Lua approach: SVG-like node data is rasterized to cached PNG bytes in pure Luau, written with Potassium's documented `writefile`, and exposed through `getcustomasset` for `ImageLabel`. Runtime-managed copies live under `Surge/Assets/`, while the checked-in source remains under `.Surge/assets/`. Surge falls back to its local `Frame` renderer when optional filesystem/asset APIs are unavailable or an icon is outside the vendored subset.

The bridge itself never performs network requests. `Surge:EnsureAssets()` may explicitly copy the checked-in bridge into the managed workspace tree or fetch a pinned release file through Potassium's documented `request` API when `Surge.Distribution` is configured. Failed responses are never accepted as cache files.

Included reference icons:

- `LucideBridge.lua` — local Lucide.Lua-style PNG bridge and selected node data.
- `lucide-zap.svg` — Surge logo reference.
- `lucide-panel-left.svg` — tab rail reference.
- `lucide-settings.svg` — settings reference.
- `lucide-terminal.svg` — console reference.
- `lucide-search.svg` — search/reference control.

Sources: https://github.com/xxpwnxxx420lord/Lucide.Lua, https://lucide.dev/, and https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/. See `THIRD_PARTY_NOTICES.md` for required notices. These files do not imply Lucide or Lucide.Lua endorsement of Surge.
