/**
 * painter tool
 *
 * Generate or edit images via an OpenAI-compatible Images API
 * (default model: gpt-image-2 through the proxy).
 *
 *   generate: text → image           (mockups, icons, hero images, diagrams)
 *   edit:      1-3 input images + prompt → new image
 *              (redaction, style edits, compositing, reference-guided generation)
 *
 * Saves a PNG to disk and renders it inline in the TUI.
 *
 * Configure via env:
 *   HD_PROXY_KEY     (required) — proxy API key
 *   PI_PAINTER_MODEL (optional, default gpt-image-2)
 *   PI_PAINTER_BASE  (optional, default https://proxy.tuongnguyen.work/v1)
 *   PI_PAINTER_KEY   (optional, overrides HD_PROXY_KEY)
 */

import { writeFile, readFile } from "node:fs/promises";
import { basename } from "node:path";
import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

const DEFAULT_BASE = "https://proxy.tuongnguyen.work/v1";
const DEFAULT_MODEL = "gpt-image-2";

const IMAGE_EXT: Record<string, string> = {
  png: "image/png",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  gif: "image/gif",
  webp: "image/webp",
  bmp: "image/bmp",
};

function mimeFromPath(p: string): string | undefined {
  const m = p.toLowerCase().match(/\.([a-z0-9]+)$/);
  return m ? IMAGE_EXT[m[1]] : undefined;
}

function defaultOutputPath(): string {
  const ts = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
  return `painter-${ts}.png`;
}

function errResult(text: string) {
  return {
    content: [{ type: "text" as const, text }],
    details: { isError: true },
  };
}

async function callGenerate(
  base: string,
  key: string,
  model: string,
  prompt: string,
  size: string,
  quality: string,
  signal: AbortSignal | undefined,
): Promise<any> {
  const r = await fetch(`${base}/images/generations`, {
    method: "POST",
    signal,
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({ model, prompt, n: 1, size, quality }),
  });
  if (!r.ok) {
    const detail = await r.text().catch(() => "");
    throw new Error(`generate ${r.status}: ${detail.slice(0, 400)}`);
  }
  return await r.json();
}

async function callEdit(
  base: string,
  key: string,
  model: string,
  prompt: string,
  inputs: string[],
  size: string,
  quality: string,
  signal: AbortSignal | undefined,
): Promise<any> {
  const form = new FormData();
  form.append("model", model);
  form.append("prompt", prompt);
  form.append("size", size);
  form.append("quality", quality);
  for (const p of inputs) {
    const buf = await readFile(p);
    const mime = mimeFromPath(p) ?? "image/png";
    const fieldName = inputs.length > 1 ? "image[]" : "image";
    form.append(fieldName, new Blob([buf], { type: mime }), basename(p));
  }
  const r = await fetch(`${base}/images/edits`, {
    method: "POST",
    signal,
    headers: { authorization: `Bearer ${key}` },
    body: form,
  });
  if (!r.ok) {
    const detail = await r.text().catch(() => "");
    throw new Error(`edit ${r.status}: ${detail.slice(0, 400)}`);
  }
  return await r.json();
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "painter",
    label: "painter",
    description:
      "Generate or edit images. Use mode='generate' for text→image (mockups, icons, hero images, diagrams) " +
      "and mode='edit' with 1-3 input images for edits, compositing, or redaction " +
      "(e.g. blur API keys/passwords in screenshots). Saves a PNG and renders it inline.",
    promptSnippet: "Generate or edit an image",
    promptGuidelines: [
      "Use painter when the user asks to create, generate, or edit images — icons, mockups, hero images, diagrams, or screenshot edits.",
      "For edits or redaction, pass 1-3 input image paths in `input` and set mode='edit' (or omit; it auto-derives from input).",
      "Only use painter when explicitly requested or clearly implied by the task.",
    ],
    parameters: Type.Object({
      prompt: Type.String({
        description: "Image generation/edit prompt. Be specific: subject, style, colors, composition, text to render.",
      }),
      mode: Type.Optional(
        Type.Union([Type.Literal("generate"), Type.Literal("edit")], {
          description:
            "generate = text→image; edit = input images + prompt → new image. " +
            "Defaults to 'edit' when `input` is provided, else 'generate'.",
        }),
      ),
      input: Type.Optional(
        Type.Array(Type.String(), {
          description: "1-3 input image paths for edit mode (redaction, style edit, reference-guided generation).",
        }),
      ),
      size: Type.Optional(
        Type.Union(
          [Type.Literal("1024x1024"), Type.Literal("1792x1024"), Type.Literal("1024x1792")],
          { description: "Output size. Default 1024x1024." },
        ),
      ),
      quality: Type.Optional(
        Type.Union(
          [Type.Literal("low"), Type.Literal("medium"), Type.Literal("high")],
          { description: "Output quality. Default medium." },
        ),
      ),
      output_path: Type.Optional(
        Type.String({ description: "Output PNG path. Default ./painter-<timestamp>.png" }),
      ),
    }),
    async execute(_toolCallId, args: any, signal, _onUpdate, _ctx) {
      const base = process.env.PI_PAINTER_BASE ?? DEFAULT_BASE;
      const key = process.env.PI_PAINTER_KEY ?? process.env.HD_PROXY_KEY;
      if (!key) return errResult("painter: HD_PROXY_KEY env var not set");
      const model = process.env.PI_PAINTER_MODEL ?? DEFAULT_MODEL;

      const prompt = String(args.prompt ?? "").trim();
      if (!prompt) return errResult("painter: `prompt` is required");

      const inputs: string[] = Array.isArray(args.input)
        ? args.input.filter((p: unknown) => typeof p === "string" && p.length > 0)
        : [];
      const mode = args.mode ?? (inputs.length > 0 ? "edit" : "generate");
      const size = args.size ?? "1024x1024";
      const quality = args.quality ?? "medium";

      if (mode === "edit" && inputs.length === 0) {
        return errResult("painter: edit mode requires at least one `input` image path");
      }
      for (const p of inputs) {
        try {
          await readFile(p);
        } catch {
          return errResult(`painter: input image not readable: "${p}"`);
        }
      }

      let json: any;
      try {
        json =
          mode === "edit"
            ? await callEdit(base, key, model, prompt, inputs, size, quality, signal)
            : await callGenerate(base, key, model, prompt, size, quality, signal);
      } catch (err: any) {
        return errResult(`painter: ${err?.message ?? err}`);
      }

      const item = json?.data?.[0];
      if (!item) {
        return errResult(`painter: no data in response (${JSON.stringify(json).slice(0, 200)})`);
      }

      let b64: string | undefined = item.b64_json;
      let bytes: Buffer;
      if (b64) {
        bytes = Buffer.from(b64, "base64");
      } else if (item.url) {
        const r = await fetch(item.url, { signal });
        if (!r.ok) return errResult(`painter: download generated image failed (${r.status})`);
        bytes = Buffer.from(await r.arrayBuffer());
        b64 = bytes.toString("base64");
      } else {
        return errResult("painter: response had neither b64_json nor url");
      }

      const outPath = String(args.output_path ?? "").trim() || defaultOutputPath();
      try {
        await writeFile(outPath, bytes);
      } catch (err: any) {
        return errResult(`painter: generated image but failed to write "${outPath}": ${err?.message ?? err}`);
      }

      return {
        content: [
          {
            type: "text" as const,
            text: `painter ${mode} → ${outPath}  (${size}, ${quality}, ${(bytes.length / 1024).toFixed(0)} KB)`,
          },
          { type: "image" as const, data: b64, mimeType: "image/png" },
        ],
        details: { path: outPath, mode, size, quality, bytes: bytes.length, model },
      };
    },
    renderCall(args, theme, context) {
      const text = context.lastComponent ?? new Text("", 0, 0);
      const hasInput = Array.isArray(args.input) && args.input.length > 0;
      const mode = args.mode ?? (hasInput ? "edit" : "generate");
      const preview = String(args.prompt ?? "").slice(0, 60);
      if (!context.expanded) {
        const tag = theme.fg("customMessageLabel", "\x1b[1m[image gen]\x1b[22m ");
        const name = theme.fg("customMessageText", preview);
        text.setText(`${tag}${name}`);
      } else {
        const head = theme.fg("toolTitle", theme.bold(`painter (${mode})`));
        const body = theme.fg("toolOutput", String(args.prompt ?? ""));
        text.setText(`${head}\n${body}`);
      }
      return text;
    },
    renderResult(result, options, theme, context) {
      const text = context.lastComponent ?? new Text("", 0, 0);
      if (context.isError) {
        const errText = result.content
          .map((c: any) => (c.type === "text" ? c.text : ""))
          .filter(Boolean)
          .join("\n");
        text.setText(theme.fg("error", errText || "Error"));
        return text;
      }
      const d: any = result.details ?? {};
      if (!options.expanded) {
        text.setText(theme.fg("dim", `saved ${d.path ?? ""}`));
        return text;
      }
      const out = result.content
        .filter((c: any) => c.type === "text")
        .map((c: any) => c.text)
        .join("\n");
      text.setText(theme.fg("toolOutput", out));
      return text;
    },
  });
}
