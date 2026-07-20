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
| Package | `pi-default-tools` (via `pi install`) | settings.json `packages` + `~/.pi/agent/git/` |

**Not touched** by the installer (you manage these):
- `models.json` (providers, API keys, model definitions)
- `settings.json` (default model, theme, thinking level, …)

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
4. Copies extensions, agents, and `AGENTS.md` into `~/.pi/agent/`.
5. `pi install git:github.com/jwu/pi-default-tools` (skipped if present).
6. Persists `PI_PAINTER_BASE` / `PI_PAINTER_KEY` / `PI_VISION_BASE` /
   `PI_VISION_KEY` to `~/.zshrc` / `~/.bashrc`.

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

## Environment variables

| Var | Required | Purpose |
|---|---|---|
| `PI_PAINTER_KEY` | yes (painter) | Painter proxy API key — set by install.sh |
| `PI_PAINTER_BASE` | no | Painter base URL (default `https://proxy.tuongnguyen.work/v1`) |
| `PI_VISION_KEY` | yes (view_media) | View-media proxy API key — defaults to `PI_PAINTER_KEY` |
| `PI_VISION_BASE` | no | View-media base URL — defaults to `PI_PAINTER_BASE` |
| `PI_PAINTER_MODEL` | no | Override `gpt-image-2` |
| `PI_VISION_MODEL` | no | Override `gemini-3-flash-agent` fallback |

> Legacy `HD_PROXY_KEY` / `HD_PROXY_URL` still work as a fallback in the
> extensions (back-compat with older installs) but the installer no longer
> sets them.

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
└── prompts/             # empty — add your own
```

## Security

No API keys committed. Extensions read `process.env.PI_PAINTER_KEY` /
`process.env.PI_VISION_KEY` (and base URLs from `PI_PAINTER_BASE` /
`PI_VISION_BASE`). The installer writes these only to `~/.zshrc` /
`~/.bashrc` (consider `chmod 600 ~/.zshrc`).
