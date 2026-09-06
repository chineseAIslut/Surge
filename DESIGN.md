# Surge design system

<!-- impeccable:design-schema 2 -->

## Thesis

Surge is a compact monochrome instrument panel for scripts executed through Potassium. It refuses the typical neon executor aesthetic, remote model dependencies, and ambiguous teardown.

## Material and palette

- `Window`: near-black graphite with low transparency.
- `Surface`: deep graphite panel layer.
- `SurfaceRaised`: lighter graphite for controls and tags.
- `SurfaceInput`: almost-black input fields.
- `Text`, `TextMuted`, `TextFaint`: white-to-gray hierarchy.
- `Accent`: white; `AccentContrast`: near-black for active controls.
- `Border` and `BorderStrong`: cool-neutral grays without hue.
- Transparency and one-pixel strokes create a restrained glass-like depth without blur or remote assets.

## Composition

The first viewport is a centred rounded window. A Zap mark anchors the top bar, a narrow tab rail holds navigation, and the right content panel uses evenly spaced rounded rows. The collapsed pill and toast/notification layers reuse the same tokens.

## Typography

Gotham Semibold carries titles and control labels; Gotham carries descriptions and status copy; Code is reserved for console output. Text remains visible beside icons so controls are not color- or icon-only.

## Components

The stable public model is `Surge -> Window -> Tab/Group -> Element`. Elements expose handles, setters, visible states, row reordering, and explicit lock/unlock behavior where input is operable. Sidebar sections, tags, labeled dividers, localized tracked copy, notifications, boxes-style popups, and workspace-relative persistence are part of the runtime surface. Window lifecycle methods (`Show`, `Hide`, `ToggleMinimise`, `Unload`) are explicit and tracked connections are disconnected on unload.

## Motion

Motion is short, monochrome, and interruptible. `Surge.Animation` centralizes fast feedback (`100ms`), standard transitions (`160ms`), tab slides (`140ms`), message transitions (`160ms`), and menu morphing (`220ms`). Quad ease-out handles entry and direct response; ease-in handles exits. Active tweens are cancelled before replacement, stale completions are ignored, and state tokens make rapid tab and menu reversals settle on the latest request.

Tabs snapshot descendant visual properties, fade the outgoing page before sliding and revealing the incoming page, and keep a transition shield active until exactly one page is visible and interactive. Slider dragging remains immediate. Notifications and toasts wrap within viewport-derived bounds and collapse measured heights on close. Hide/Show converts absolute endpoints into the owning `ScreenGui`'s local coordinate space before morphing; no fixed inset offset is part of the design.

Exact endpoint alignment, pointer dragging, and pixel-level overlap checks are runtime-only assertions and require Potassium verification; source-level animation contracts do not promise frame-perfect timing.
## Icon language

Runtime icons first use the local Lucide.Lua-style PNG bridge for the bounded, vendored subset, then fall back to code-drawn line primitives for unknown names or runtimes without filesystem/getcustomasset support. Source SVG references remain under `assets/` with notices in `THIRD_PARTY_NOTICES.md`; Roblox SVG rendering is not assumed.

## Constraints

Only black, white, and grayscale colors are used, including caller-provided tag colors normalized by the library. No network loader, Roblox model, marketplace asset ID, Studio ModuleScript, secure-mode promise, or generic anti-detection claim is part of the system.
