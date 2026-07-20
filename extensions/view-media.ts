/**
 * view_media tool
 *
 * Reads an image file and:
 *  - Always renders it inline in the TUI (like the built-in read tool).
 *  - If the current model supports images, returns the image attachment directly.
 *  - If the current model does NOT support images, calls the configured vision
 *    fallback (default: gemini-3-flash-agent via the OpenAI-compatible proxy)
 *    and returns its description as text alongside the inline image.
 *
 * Configure via env:
 *   HD_PROXY_KEY     (required) — proxy API key
 *   PI_VISION_MODEL  (optional, default gemini-3-flash-agent)
 *   PI_VISION_BASE   (optional, default https://proxy.tuongnguyen.work/v1)
 *   PI_VISION_KEY    (optional, overrides HD_PROXY_KEY)
 */

import { readFile } from "node:fs/promises";
import { basename } from "node:path";
import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

const DEFAULT_BASE = "https://proxy.tuongnguyen.work/v1";
const DEFAULT_MODEL = "gemini-3-flash-agent";

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

function modelSupportsImages(model: any): boolean {
  return !!model && Array.isArray(model.input) && model.input.includes("image");
}

async function describeWithVision(
  base64: string,
  mimeType: string,
  question: string,
  signal: AbortSignal | undefined,
): Promise<string> {
  const base = process.env.PI_VISION_BASE ?? DEFAULT_BASE;
  const key = process.env.PI_VISION_KEY ?? process.env.HD_PROXY_KEY;
  if (!key) throw new Error("view_media: HD_PROXY_KEY env var not set");
  const model = process.env.PI_VISION_MODEL ?? DEFAULT_MODEL;
  const prompt =
    question?.trim() ||
    "Describe this image concisely: key objects, text (OCR), colors, layout. Be factual and specific.";

  const resp = await fetch(`${base}/chat/completions`, {
    method: "POST",
    signal,
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({
      model,
      max_tokens: 1024,
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: prompt },
            { type: "image_url", image_url: { url: `data:${mimeType};base64,${base64}` } },
          ],
        },
      ],
    }),
  });

  if (!resp.ok) {
    const detail = await resp.text().catch(() => "");
    throw new Error(`vision fallback ${resp.status}: ${detail.slice(0, 300)}`);
  }

  const data: any = await resp.json();
  const content = data?.choices?.[0]?.message?.content;
  if (Array.isArray(content)) {
    return content
      .map((c: any) => (typeof c === "string" ? c : c?.text ?? ""))
      .filter(Boolean)
      .join("\n")
      .trim();
  }
  return (typeof content === "string" ? content : "").trim();
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "view_media",
    label: "view_media",
    description:
      "View an image file. Renders it inline in the terminal and returns a description. " +
      "Use this for screenshots, diagrams, photos, mockups, or any image the user references. " +
      "Works even when the current model cannot read images (a vision fallback model is used automatically).",
    promptSnippet: "View an image file",
    promptGuidelines: [
      "Prefer view_media over read for any image file (png/jpg/gif/webp/bmp).",
      "Pass a specific question in `question` when the user wants particular details (OCR, colors, layout).",
    ],
    parameters: Type.Object({
      path: Type.String({ description: "Path to the image file (relative or absolute)" }),
      question: Type.Optional(
        Type.String({
          description:
            "Optional question or focus for analysis (e.g. 'Read all text', 'Identify the error dialog'). " +
            "If omitted, a general description is produced.",
        }),
      ),
    }),
    async execute(_toolCallId, { path, question }, signal, _onUpdate, ctx) {
      const absPath = path; // Pi resolves cwd; keep as-is for display
      const mimeType = mimeFromPath(path);
      if (!mimeType) {
        return {
          content: [
            {
              type: "text",
              text: `view_media: unsupported file type for "${path}". Supported: ${Object.keys(IMAGE_EXT).join(", ")}.`,
            },
          ],
          details: { isError: true },
        };
      }

      let buffer: Buffer;
      try {
        buffer = await readFile(path);
      } catch (err: any) {
        return {
          content: [{ type: "text", text: `view_media: failed to read "${path}": ${err?.message ?? err}` }],
          details: { isError: true },
        };
      }

      const base64 = buffer.toString("base64");
      const supportsImages = modelSupportsImages(ctx?.model);

      // Inline image (always included so the TUI renders it like the read tool)
      const imageBlock = { type: "image" as const, data: base64, mimeType };

      if (supportsImages) {
        const note = question?.trim()
          ? `Viewing image "${absPath}" (question: ${question.trim()}). The image is attached.`
          : `Viewing image "${absPath}". The image is attached.`;
        return {
          content: [{ type: "text", text: note }, imageBlock],
          details: { mimeType, bytes: buffer.length, source: "direct" },
        };
      }

      // Non-vision current model: call the vision fallback.
      try {
        const description = await describeWithVision(base64, mimeType, question ?? "", signal);
        const header =
          `Viewing image "${absPath}" [${mimeType}, ${buffer.length} bytes].\n` +
          `Current model cannot read images; description via ${process.env.PI_VISION_MODEL ?? DEFAULT_MODEL}:\n\n`;
        return {
          content: [{ type: "text", text: header + description }, imageBlock],
          details: { mimeType, bytes: buffer.length, source: "vision-fallback" },
        };
      } catch (err: any) {
        return {
          content: [
            {
              type: "text",
              text: `view_media: read "${absPath}" but vision fallback failed: ${err?.message ?? err}. Image is attached for display only.`,
            },
            imageBlock,
          ],
          details: { isError: true, mimeType, bytes: buffer.length },
        };
      }
    },
    renderCall(args, theme, context) {
      const text = context.lastComponent ?? new Text("", 0, 0);
      const file = basename(String(args.path ?? "")) || String(args.path ?? "");
      const isImage = !!mimeFromPath(String(args.path ?? ""));

      if (!context.expanded) {
        const tag = theme.fg("customMessageLabel", "\x1b[1m[image]\x1b[22m ");
        const name = theme.fg("customMessageText", file);
        const hint = theme.fg("dim", ` (expand for details)`);
        text.setText(`${tag}${name}${hint}`);
      } else {
        const head = theme.fg("toolTitle", theme.bold("view_media"));
        const path = theme.fg("accent", String(args.path ?? ""));
        const tag = isImage ? "" : theme.fg("warning", " [unsupported]");
        text.setText(`${head} ${path}${tag}`);
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
      if (!options.expanded) {
        // Collapsed: hide description text (image still renders inline).
        const src = (result.details as any)?.source;
        const via = src === "vision-fallback" ? ` via ${process.env.PI_VISION_MODEL ?? DEFAULT_MODEL}` : "";
        text.setText(theme.fg("dim", `loaded${via}`));
        return text;
      }
      // Expanded: show full description text.
      const out = result.content
        .filter((c: any) => c.type === "text")
        .map((c: any) => c.text)
        .join("\n");
      text.setText(theme.fg("toolOutput", out));
      return text;
    },
  });
}
