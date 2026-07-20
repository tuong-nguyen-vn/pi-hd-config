# pi-hd-config

Bootstrap config for [Pi](https://www.npmjs.com/package/@earendil-works/pi-coding-agent)
against the HD proxy at `https://proxy.tuongnguyen.work`.

Sets up:
- **3 providers** (`hd-claude` / `hd-openai` / `hd-gemini`) on their native
  API standards (Anthropic Messages / OpenAI Chat Completions / Google
  Generative AI) with current per-token pricing.
- **Extensions**: `painter` (text→image generate/edit), `view-media` (vision),
  `subagent` (delegate to `search`/`oracle`).
- **Agents**: `oracle` (deep reasoning), `search` (parallel code search).
- `AGENTS.md` wiring subagent delegation into the system prompt.

## One-line install

```bash
curl -sSL https://raw.githubusercontent.com/tuong-nguyen-vn/pi-hd-config/main/install.sh | bash
```

The script:
1. Installs `@earendil-works/pi-coding-agent` via npm if `pi` isn't on PATH.
2. Prompts for the HD proxy API key (or reads `HD_PROXY_KEY` env var).
3. Copies `models.json`, `settings.json`, `agents/`, `extensions/`, `AGENTS.md`
   into `~/.pi/agent/`.
4. Persists `export HD_PROXY_KEY="..."` to `~/.zshrc` and `~/.bashrc`.
5. Verifies with a live call to `glm-5.2`.

Non-interactive:
```bash
HD_PROXY_KEY=... curl -sSL https://raw.githubusercontent.com/tuong-nguyen-vn/pi-hd-config/main/install.sh | bash
```

Or from a clone:
```bash
git clone https://github.com/tuong-nguyen-vn/pi-hd-config.git
cd REPO
./install.sh
```

## Models available after install

| Provider | Model | API |
|---|---|---|
| hd-claude | claude-opus-4-8, claude-sonnet-5, glm-5.2 | anthropic-messages |
| hd-openai | gpt-5.5, gpt-5.6-sol, grok-4.5, grok-composer-2.5-fast | openai-completions |
| hd-gemini | gemini-3-flash-agent | google-generative-ai |

Default: `hd-claude` / `claude-sonnet-5` (override in `settings.json`).

## Tools

| Tool | Source | Purpose |
|---|---|---|
| `painter` | extensions/painter.ts | Generate/edit images via gpt-image-2 |
| `view_media` | extensions/view-media.ts | Read image files; vision fallback |
| `subagent` | extensions/subagent/ | Delegate to `search`/`oracle` |

## Environment variables

| Var | Required | Purpose |
|---|---|---|
| `HD_PROXY_KEY` | yes | Proxy API key (set by install.sh) |
| `PI_PAINTER_MODEL` | no | Override `gpt-image-2` |
| `PI_PAINTER_BASE` | no | Override image API base URL |
| `PI_VISION_MODEL` | no | Override `gemini-3-flash-agent` fallback |
| `PI_VISION_BASE` | no | Override vision API base URL |

## Uninstall

```bash
./uninstall.sh
```

Removes copied resources + the env block from shell rc files. Keeps
`auth.json`, `sessions/`, `models-store.json`, `bin/`, `trust.json`.

## Repo contents

```
.
├── install.sh           # one-command installer
├── uninstall.sh
├── models.json          # providers w/ ${HD_PROXY_KEY} interpolation
├── settings.json        # defaults: hd-claude / claude-sonnet-5
├── AGENTS.md            # subagent delegation wiring
├── agents/
│   ├── oracle.md        # deep-reasoning subagent (gpt-5.6-sol)
│   └── search.md        # parallel code-search subagent (grok-composer-2.5-fast)
├── extensions/
│   ├── painter.ts
│   ├── view-media.ts
│   └── subagent/
└── prompts/             # empty — add your own
```

## Security

No API keys are committed. `models.json` uses `${HD_PROXY_KEY}` env
interpolation (Pi's native mechanism), and extensions read
`process.env.HD_PROXY_KEY`. The installer writes the key to `~/.zshrc` /
`~/.bashrc` only (file mode kept as your shell default — consider
`chmod 600 ~/.zshrc`).
