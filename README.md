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
2. Prompts for **HD_PROXY_KEY** (used by `painter` + `view_media`) — or reads
   the env var.
3. Prompts for **HD_PROXY_URL** (default `https://proxy.tuongnguyen.work`) —
   or reads the env var.
4. Copies extensions, agents, and `AGENTS.md` into `~/.pi/agent/`.
5. `pi install git:github.com/jwu/pi-default-tools` (skipped if present).
6. Persists `HD_PROXY_KEY` + `HD_PROXY_URL` to `~/.zshrc` / `~/.bashrc`.

That's the entire input set — no theme/thinking/model prompts. Those are
personal prefs you set via `/settings` and `/model` inside Pi.

Non-interactive:
```bash
HD_PROXY_KEY=... HD_PROXY_URL=https://my.proxy \
  curl -sSL https://raw.githubusercontent.com/tuong-nguyen-vn/pi-hd-config/main/install.sh | bash
```

Or from a clone:
```bash
git clone https://github.com/tuong-nguyen-vn/pi-hd-config.git
cd pi-hd-config && ./install.sh
```

## Environment variables

| Var | Required | Purpose |
|---|---|---|
| `HD_PROXY_KEY` | yes (for painter/view_media) | Proxy API key — set by install.sh |
| `HD_PROXY_URL` | no | Proxy base URL (default `https://proxy.tuongnguyen.work`) — set by install.sh |
| `PI_PAINTER_MODEL` | no | Override `gpt-image-2` |
| `PI_PAINTER_BASE` | no | Override painter API base URL |
| `PI_VISION_MODEL` | no | Override `gemini-3-flash-agent` fallback |
| `PI_VISION_BASE` | no | Override vision API base URL |

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

No API keys committed. Extensions read `process.env.HD_PROXY_KEY`; the
installer writes the key only to `~/.zshrc` / `~/.bashrc` (consider
`chmod 600 ~/.zshrc`).
