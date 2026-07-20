# pi-hd-config

Tooling pack for [Pi](https://www.npmjs.com/package/@earendil-works/pi-coding-agent):
extensions, subagents, and a tools package. **Provider/model config is yours
to manage** — this installer only handles the tooling layer.

## What gets installed

| Layer | What | Where |
|---|---|---|
| Extensions | `painter` (image gen/edit), `view_media` (vision), `subagent` | `~/.pi/agent/extensions/` |
| Agents | `oracle` (deep reasoning, `gpt-5.6-sol`), `search` (parallel code search, `gemini-3-flash-agent`) | `~/.pi/agent/agents/` |
| System prompt | `AGENTS.md` wiring subagent delegation | `~/.pi/agent/AGENTS.md` |
| Theme | `amp` — minimal Amp-like palette (grayscale + coral accent, no tool-bg fills) | `~/.pi/agent/themes/` |
| Package | `pi-default-tools` (via `pi install`) | settings.json `packages` + `~/.pi/agent/git/` |

**Not touched** by the installer (you manage these):
- `models.json` (providers, API keys, model definitions)
- `settings.json` (default model, theme, thinking level, …)
- Shell rc files (`~/.zshrc`, `~/.bashrc`)

A sample `models.json` + `settings.json` live in this repo for reference —
copy them manually if you want a starting point:
```bash
cp models.json settings.json ~/.pi/agent/
```

## One-line install

```bash
curl -sSL https://raw.githubusercontent.com/tuong-nguyen-vn/pi-hd-config/main/install.sh | bash
```

The script:
1. Installs `@earendil-works/pi-coding-agent` via npm if `pi` isn't on PATH.
2. Asks for **painter base URL + API key** (defaults: `https://proxy.tuongnguyen.work/v1`
   + your input).
3. Asks for **view-media base URL + API key** — Enter accepts the painter
   values, or paste different ones if you use a separate provider for vision.
4. Copies extensions, agents, `AGENTS.md`, and `themes/` into `~/.pi/agent/`.
5. `pi install git:github.com/jwu/pi-default-tools` (skipped if present).
6. Writes `~/.pi/agent/extensions.json` (chmod 600) with painter/view-media
   base URLs + API keys. **Does not touch your shell rc.**

To enable the `amp` theme, set `"theme": "amp"` in `~/.pi/agent/settings.json`
(the sample `settings.json` in this repo already does). Pi hot-reloads theme
edits — tweak `~/.pi/agent/themes/amp.json` and see changes immediately.

Extensions read `~/.pi/agent/extensions.json` first, then fall back to env
vars (`PI_PAINTER_*` / `PI_VISION_*`) for back-compat.

Painter and view_media are fully independent — they can hit two different
proxies/providers if you want.

Non-interactive (use same proxy for both):
```bash
PI_PAINTER_KEY=... curl -sSL https://raw.githubusercontent.com/tuong-nguyen-vn/pi-hd-config/main/install.sh | bash
```

Non-interactive (separate providers per tool):
```bash
PI_PAINTER_BASE=https://img-proxy.example.com/v1 PI_PAINTER_KEY=... \
PI_VISION_BASE=https://vision-proxy.example.com/v1  PI_VISION_KEY=... \
  bash install.sh
```

Or from a clone:
```bash
git clone https://github.com/tuong-nguyen-vn/pi-hd-config.git
cd pi-hd-config && ./install.sh
```

## Configuration

Painter and view-media keys live in `~/.pi/agent/extensions.json` (written by
`install.sh`, chmod 600). The installer never touches your shell rc.

```json
{
  "painter":   { "baseUrl": "https://proxy.tuongnguyen.work/v1", "apiKey": "..." },
  "viewMedia": { "baseUrl": "https://proxy.tuongnguyen.work/v1", "apiKey": "..." }
}
```

Optional model overrides: add `"model": "..."` to either section.

| Env var (fallback) | Purpose |
|---|---|
| `PI_PAINTER_KEY` | Painter API key (if extensions.json absent) |
| `PI_PAINTER_BASE` | Painter base URL |
| `PI_PAINTER_MODEL` | Override `gpt-image-2` |
| `PI_VISION_KEY` | View-media API key |
| `PI_VISION_BASE` | View-media base URL |
| `PI_VISION_MODEL` | Override `gemini-3-flash-agent` |

> Legacy `HD_PROXY_KEY` / `HD_PROXY_URL` still work as a last-resort fallback.

## Uninstall

```bash
./uninstall.sh
```

Removes extensions + agents + AGENTS.md + the env block from shell rc files.
Keeps `models.json`, `settings.json`, `auth.json`, `sessions/`, `bin/`,
`trust.json`, `models-store.json`. To also drop the tools package:
```bash
pi remove git:github.com/jwu/pi-default-tools
```

## Repo contents

```
.
├── install.sh           # tooling installer (NO provider/model setup)
├── uninstall.sh
├── models.json          # SAMPLE providers config (copy manually if wanted)
├── settings.json        # SAMPLE settings (copy manually if wanted)
├── AGENTS.md            # subagent delegation wiring
├── agents/
│   ├── oracle.md        # deep-reasoning subagent (gpt-5.6-sol)
│   └── search.md        # parallel code-search subagent (gemini-3-flash-agent)
├── extensions/
│   ├── painter.ts
│   ├── view-media.ts
│   └── subagent/
├── themes/
│   └── amp.json         # minimal Amp-like palette (grayscale + coral accent)
└── prompts/             # empty — add your own
```

## Security

No API keys committed. The installer writes painter/view-media keys only to
`~/.pi/agent/extensions.json` with `chmod 600`. Extensions read that file
first, then fall back to `PI_PAINTER_*` / `PI_VISION_*` env vars (legacy
`HD_PROXY_*` as last resort). The installer never touches your shell rc.
