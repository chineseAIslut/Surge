# Third-party sources and notices

## Lucide

Surge distributes a small source-level subset of Lucide SVG references and embeds a bounded set of Lucide-compatible path/node definitions in `assets/LucideBridge.lua`:

- https://lucide.dev/
- https://github.com/lucide-icons/lucide
- https://raw.githubusercontent.com/lucide-icons/lucide/main/LICENSE
- Individual source files are linked from `assets/README.md`.

Lucide's official repository currently states the ISC License for Lucide Icons and Contributors. The following notice is retained because Lucide-derived SVG/path material is distributed with Surge:

```text
ISC License

Copyright (c) 2026 Lucide Icons and Contributors

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER
RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE
USE OR PERFORMANCE OF THIS SOFTWARE.
```

The official license also marks a Feather-derived subset as MIT. The distributed `terminal` and `search` references are in that named subset, so this notice is retained as well:

```text
The MIT License (MIT)

Copyright (c) 2013-present Cole Bemis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

The runtime first uses the local PNG bridge for the bounded embedded subset and falls back to independently authored line primitives. It does not load remote icon packages or imply Lucide endorsement of Surge.
## Lucide.Lua renderer reference

`assets/LucideBridge.lua` adapts the local PNG-rasterization approach from:

- Repository: https://github.com/xxpwnxxx420lord/Lucide.Lua
- Reviewed source commit: `11f7e707ee012c374e15808309f6ef9694c87c2d`
- Entry source: https://raw.githubusercontent.com/xxpwnxxx420lord/Lucide.Lua/main/lucide.lua
- Converter source: https://raw.githubusercontent.com/xxpwnxxx420lord/Lucide.Lua/main/Converter.lua
- README/license claim: https://raw.githubusercontent.com/xxpwnxxx420lord/Lucide.Lua/main/Readme.md

The repository has no root `LICENSE` file at the reviewed commit. Its README claims an MIT license and credits Syntaxical. Surge therefore retains the claim as attribution but does not treat it as an independently verified license file:

```text
MIT License

Copyright (c) Syntaxical

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Surge vendors a bounded local subset and removes Lucide.Lua's remote `HttpGet` loader. The bridge requires the optional Potassium filesystem and `getcustomasset` APIs; otherwise Surge falls back to its local frame renderer. The PNG format/size behavior is implementation-dependent in Potassium and is verified only for the small representative sizes used by Surge.


## Rayfield and Rayfield Gen2

Rayfield (2022) and Rayfield Gen2 were used as documented API and interaction references, not as copied source. Relevant primary sources:

- Rayfield documentation: https://docs.sirius.menu/rayfield
- Rayfield Gen2 documentation: https://docs.sirius.menu/rayfield-gen2
- Rayfield source repository and license: https://github.com/SiriusSoftwareLtd/Rayfield and https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/LICENSE

The Rayfield repository identifies Apache License 2.0. Surge does not include Rayfield source, Roblox models, remote loaders, asset IDs, or claims of Rayfield compatibility/endorsement. The documented component model informed the independent handles and lifecycle API; differences and limitations are documented in `README.md`.

## Potassium

Potassium API facts are sourced from the official documentation:

- https://docs.potassium.pro/api-reference/introduction
- https://docs.potassium.pro/llms.txt

Surge only assumes the documented workspace-relative `readfile`/`writefile`/`isfile`/`isfolder`/`makefolder`/`listfiles` family when those functions exist at runtime. It does not claim that arbitrary absolute paths, Studio ModuleScripts, or anti-cheat evasion are supported.

## Surge distribution manager

The optional distribution manager does not add a new third-party library. It uses Potassium's documented `request` API only for explicitly configured GitHub release files and keeps the existing Lucide/Lucide.Lua attribution above. The repository owner must provide the canonical repository and immutable ref; this source tree intentionally provides neither.
