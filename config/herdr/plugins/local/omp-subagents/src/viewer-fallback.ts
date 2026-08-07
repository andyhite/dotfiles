#!/usr/bin/env bun
/**
 * FALLBACK renderer — used only when src/viewer.ts cannot mount omp's own
 * `AgentTranscriptViewer` (see that file's header for the native path and
 * exactly which failures route here). This file is the hand-rolled renderer
 * that used to be the only renderer this plugin had; it is kept verbatim
 * (module-load-order and autoclose behaviour unchanged) so that an omp
 * upgrade which breaks the pinned internal API this plugin depends on
 * degrades the pane's *looks* — back to this ANSI-art approximation of
 * omp's palette — rather than losing the pane, or the subagent's live
 * transcript, entirely. It has no dependency on @oh-my-pi/pi-coding-agent or
 * @oh-my-pi/pi-tui, and never will: that independence is the whole point.
 *
 * Also runnable directly (`bun run src/viewer-fallback.ts`), same env
 * contract as viewer.ts, for anyone who wants this renderer specifically.
 */

/**
 * Read-only live viewer for one omp subagent, run as a herdr pane entrypoint.
 *
 * Two families of env vars feed this script, and they come from different
 * places — worth spelling out since nothing about the names makes that
 * obvious to the next reader:
 *
 *   - HERDR_* (HERDR_PLUGIN_ENTRYPOINT_ID, HERDR_PANE_ID, HERDR_SOCKET_PATH,
 *     HERDR_CELL_WIDTH_PX/HEIGHT_PX, HERDR_BIN_PATH, HERDR_PLUGIN_STATE_DIR,
 *     ...) are injected by herdr itself into every plugin pane process.
 *     HERDR_PLUGIN_ENTRYPOINT_ID gates the interactivity below; HERDR_PANE_ID
 *     (and, optionally, HERDR_BIN_PATH) feeds the autoclose focus probe (see
 *     "autoclose" below); the rest exist for other plugins' use cases
 *     (sizing output in cells, persisting plugin state) that this viewer has
 *     no need for.
 *   - OMP_SUBAGENT_* are *not* a herdr concept at all. They are self-injected
 *     by the omp extension (herdr-subagent-panes.ts) via `--env KEY=VALUE`
 *     flags on its own `herdr plugin pane open` call, which is also the only
 *     thing that ever opens this pane. Change that extension's contract and
 *     this list changes with it; herdr itself doesn't know these exist.
 *
 * The OMP_SUBAGENT_* values this script actually reads: OMP_SUBAGENT_FILE
 * (the subagent's own session JSONL, appended to live by omp),
 * OMP_SUBAGENT_STATE (a small JSON file the extension rewrites atomically on
 * every lifecycle/progress event — see herdr-subagent-panes.ts for the writer
 * side of that contract), and OMP_SUBAGENT_AUTOCLOSE (whether *this* pane
 * should close itself once the subagent settles — see "autoclose" below).
 *
 * Read-only with one narrow, deliberate exception: no code path here opens
 * either file for writing or sends stdin to the subagent, and the only herdr
 * call this script ever makes is a read-only `herdr pane get` used to probe
 * this pane's own focus state for autoclose — never `herdr plugin pane
 * close`, `pane rename`, or any other command that mutates herdr state (see
 * "autoclose" below for why the process exiting, not a herdr call, is what
 * actually closes the pane).
 *
 * Polling vs fswatch: fswatch is on PATH and would push change events instead
 * of this polling loop, but it means spawning and parsing a second process for
 * a file we already know is monotonically growing (omp appends, never
 * rewrites, the JSONL) at a rate no faster than model output — 200ms is
 * imperceptible to a human reading a transcript and avoids a subprocess, a
 * parser for fswatch's own output format, and a second failure mode (fswatch
 * missing, or its event coalescing dropping a write) for no real gain here.
 * The state file, being tiny, is just re-read wholesale every tick rather than
 * watched separately.
 *
 * This is a scrolling log, not a full-screen TUI — no alternate screen buffer
 * and no SIGWINCH re-render, unlike e.g. official.browser's viewer. That is
 * deliberate: the acceptance requirement is that the operator can scroll back
 * through everything the subagent did, which an alternate-screen app would
 * throw away the moment it exits. The only "interactive terminal setup" this
 * script does at all is raw mode for the final single-keypress quit prompt,
 * gated below on HERDR_PLUGIN_ENTRYPOINT_ID so it never activates outside a
 * real herdr pane.
 *
 * Rendering is styled to match omp's own TUI (see local://omp-palette.md for
 * the extracted palette and reference structures this was built against) —
 * the same 24-bit One Dark colours, the same rounded-corner tool-call boxes
 * with an "Output" divider and a dimmed, tail-clipped body, and the same
 * bright-lime-while-running / dim-once-settled accent behaviour. Because this
 * is a scrolling log rather than a redrawing TUI, "evolving" a block in place
 * only happens when nothing else has been printed since — see the comment
 * above `openToolCalls` for how a call is still rendered exactly once even
 * when that in-place update isn't possible.
 */

import { existsSync, readFileSync, statSync } from "node:fs";

// ---------------------------------------------------------------------------
// env contract
// ---------------------------------------------------------------------------

const subagentId = process.env.OMP_SUBAGENT_ID ?? "subagent";
const subagentType = process.env.OMP_SUBAGENT_TYPE ?? "agent";
const subagentDesc = process.env.OMP_SUBAGENT_DESC ?? "";
const subagentFile = process.env.OMP_SUBAGENT_FILE;
const subagentState = process.env.OMP_SUBAGENT_STATE;

// "0" is the only value that turns autoclose off, matching the extension's
// contract (it always sets this explicitly, "1" or "0"). Anything else,
// including unset, is on — so a viewer launched by hand (this plugin's own
// acceptance check included) behaves like the shipped default instead of
// silently needing an env var nobody told it to set. See "autoclose" below
// for the close path itself.
const subagentAutoclose = process.env.OMP_SUBAGENT_AUTOCLOSE !== "0";

if (!subagentFile) {
  console.error(
    "omp-subagents viewer: OMP_SUBAGENT_FILE is not set. This pane is meant to be " +
      "opened by the herdr-subagent-panes omp extension, which sets it to the " +
      "subagent's session JSONL path; it is not meant to be launched by hand " +
      "without that variable.",
  );
  process.exit(1);
}

// True only when herdr itself launched this process as the "viewer" pane
// entrypoint from this plugin's manifest — see herdr-plugin.toml. A bare
// `bun run src/viewer.ts` from a normal shell (including this plugin's own
// acceptance check) never sets this, and that is exactly the case that must
// stay safe to pipe/diff: no raw mode, no keypress wait, just sequential
// stdout that ends on its own.
const isLivePane = process.env.HERDR_PLUGIN_ENTRYPOINT_ID === "viewer";

// ---------------------------------------------------------------------------
// colour — omp's own One Dark 24-bit palette, raw ANSI, no dependency, off
// for NO_COLOR or a non-TTY stdout. See local://omp-palette.md for how this
// table was extracted from a live omp pane; kept as a Record since it is
// genuinely just a static role -> RGB lookup, not a runtime collection.
// ---------------------------------------------------------------------------

const colorEnabled = !process.env.NO_COLOR && Boolean(process.stdout.isTTY);

const PALETTE: Record<string, readonly [number, number, number]> = {
  fg: [171, 178, 191], // default assistant prose
  dim: [92, 99, 112], // borders, hints, truncation notes, settled tool accent
  body: [130, 137, 151], // tool output body, thinking text
  active: [196, 248, 119], // bright lime — the tool currently running
  recent: [229, 192, 123], // yellow — header identity / status accents
  code: [198, 120, 221], // inline `code` spans in prose and thinking
  green: [152, 195, 121], // completed status
  red: [224, 108, 117], // failed tool / failed status; also flag-name syntax
  blue: [97, 175, 239], // shell command-name syntax
  orange: [209, 154, 102], // shell numeric-literal syntax
};

function rgb(triple: readonly [number, number, number]): string {
  return `38;2;${triple[0]};${triple[1]};${triple[2]}`;
}

function paint(code: string, text: string): string {
  return colorEnabled ? `\u001b[${code}m${text}\u001b[0m` : text;
}

const dim = (s: string): string => paint(rgb(PALETTE.dim), s);
const body = (s: string): string => paint(rgb(PALETTE.body), s);
const fgDefault = (s: string): string => paint(rgb(PALETTE.fg), s);
const fgDefaultBold = (s: string): string => paint(`1;${rgb(PALETTE.fg)}`, s);
const activeColor = (s: string): string => paint(rgb(PALETTE.active), s);
const activeBold = (s: string): string => paint(`1;${rgb(PALETTE.active)}`, s);
const recentBold = (s: string): string => paint(`1;${rgb(PALETTE.recent)}`, s);
const greenColor = (s: string): string => paint(rgb(PALETTE.green), s);
const redColor = (s: string): string => paint(rgb(PALETTE.red), s);

// ---------------------------------------------------------------------------
// small json/type-narrowing helpers — no `any` anywhere in this file, so every
// value pulled out of a parsed JSONL line goes through one of these guards
// before it is trusted to be a string/record/array.
// ---------------------------------------------------------------------------

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function asString(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}

function asArray(value: unknown): unknown[] | undefined {
  return Array.isArray(value) ? value : undefined;
}

function asNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Collapses one string to a single display line and hard-caps its length.
// Used for tool-arg summaries (the "most identifying argument" shown next to
// a tool name) — never for prose/thinking/body text below, which keep their
// own line structure and are clipped by line count instead.
function truncate(text: string, maxChars: number): string {
  const flat = text.replace(/\s+/g, " ").trim();
  return flat.length > maxChars ? `${flat.slice(0, Math.max(0, maxChars - 1))}…` : flat;
}

// Clips one already-rendered plain-text line to a hard character width
// without collapsing internal whitespace — unlike `truncate`, this preserves
// the indentation of file contents and command output, which `truncate`'s
// whitespace-collapsing would destroy. Must run on plain text, before any
// ANSI colour is applied — clipping a coloured string by character count
// would slice through escape sequences.
function clipLineWidth(line: string, maxChars: number): string {
  return line.length > maxChars ? `${line.slice(0, Math.max(0, maxChars - 1))}…` : line;
}

// Clips a multi-line block to the first `maxLines` lines, noting how much was
// cut. Used for the initial assignment/user text, which is not restyled with
// inline-code recolouring (see `printStyledBlock` for the prose/thinking
// path, which needs the note kept separate from the styled body so the two
// styling passes don't nest).
function clipLines(text: string, maxLines: number): string {
  const lines = text.split("\n");
  if (lines.length <= maxLines) return text;
  return `${lines.slice(0, maxLines).join("\n")}\n${dim(`… (${lines.length - maxLines} more lines)`)}`;
}

// Same head-clip as `clipLines`, but returns the overflow count instead of a
// pre-styled note line. `printStyledBlock` runs `styleProse` over `shown`
// (which recolours inline `code` spans) and then appends the note with its
// own, separate dim styling — running `styleProse` over an already-ANSI-coded
// note would misinterpret its escape bytes as literal text to recolour.
function clipLinesForStyling(text: string, maxLines: number): { shown: string; hiddenLines: number } {
  const lines = text.split("\n");
  if (lines.length <= maxLines) return { shown: text, hiddenLines: 0 };
  return { shown: lines.slice(0, maxLines).join("\n"), hiddenLines: lines.length - maxLines };
}

// Tail-clips a tool result body to the last `maxLines` lines and reports
// whether it did, matching the "… (N earlier lines, showing X of Y)" note
// observed in a live omp pane (see local://omp-palette.md) — a tail clip
// rather than a head clip because the end of a command's output (the actual
// result, an error, the last few matches) is almost always more useful than
// its start. Wholly-blank lines at the very start/end are trimmed before
// counting so they don't waste the line budget; blank lines in the interior
// (e.g. between README sections) are real structure and are kept.
function clipToTail(text: string, maxLines: number): { lines: string[]; truncated: boolean; totalLines: number } {
  const allLines = text.split("\n");
  let start = 0;
  let end = allLines.length;
  while (start < end && allLines[start]?.trim() === "") start++;
  while (end > start && allLines[end - 1]?.trim() === "") end--;
  const lines = allLines.slice(start, end);
  if (lines.length <= maxLines) return { lines, truncated: false, totalLines: lines.length };
  return { lines: lines.slice(lines.length - maxLines), truncated: true, totalLines: lines.length };
}

function extractText(content: unknown[]): string {
  const parts: string[] = [];
  for (const item of content) {
    if (!isRecord(item)) continue;
    if (asString(item.type) === "text") {
      const text = asString(item.text);
      if (text) parts.push(text);
    }
  }
  return parts.join("\n\n");
}

// Recolours inline `code` spans to omp's inline-code purple and drops the
// backticks (omp renders markdown, not literal backtick characters); every
// other span is painted with `baseCode` — an SGR code string, so thinking can
// pass "3;<dim>" (italic dim) while prose passes just its plain fg code. A
// live capture (local://omp-palette.md) shows a code span inside an italic
// thinking block dropping the italic for its own extent and resuming it
// immediately after; painting each split segment independently, rather than
// nesting SGR codes, reproduces exactly that rather than bleeding one span's
// reset into the next.
function styleProse(text: string, baseCode: string): string {
  if (!colorEnabled) return text.replace(/`([^`\n]+)`/g, "$1");
  return text
    .split(/(`[^`\n]+`)/g)
    .map((part) => {
      if (part.length > 1 && part.startsWith("`") && part.endsWith("`")) {
        return paint(rgb(PALETTE.code), part.slice(1, -1));
      }
      return part ? paint(baseCode, part) : part;
    })
    .join("");
}

// Light shell syntax highlighter for a bash tool call's command line, cross
// checked against the syntax roles in local://omp-palette.md: quoted strings
// green, `||`/`&&`/`>>`/`>&`/`|`/`;`/`&`/`<`/`>` operators purple (the same
// hue as inline code — omp reuses it for both), `-`/`--` flags red with the
// dash(es) themselves left in the default fg colour, bare numbers orange, and
// a run of plain leading words — a command can be a multi-word invocation
// like `herdr plugin pane close`, and a live capture shows the whole run
// coloured blue, not just the first token — blue until the first token that
// isn't a plain word. This is a regex tokenizer, not a real shell parser: it
// does not track quoting/escaping context, so e.g. a flag-shaped token inside
// a double-quoted string still gets flagged as a flag. That is an accepted
// approximation, not a bug to chase — the only consumer is a read-only
// display and a slightly-off token colour inside a rare edge case is far
// cheaper than embedding a real shell lexer here.
function highlightShellCommand(command: string): string {
  if (!colorEnabled) return command;
  const tokens = command.split(/(\s+|"[^"]*"|'[^']*'|\|\||&&|>>|>&|[|;&<>])/);
  let leadingCommandRun = true;
  return tokens
    .map((token) => {
      if (token === "" || /^\s+$/.test(token)) return token;
      if (/^".*"$|^'.*'$/.test(token)) {
        leadingCommandRun = false;
        return paint(rgb(PALETTE.green), token);
      }
      if (/^(\|\||&&|>>|>&|[|;&<>])$/.test(token)) {
        leadingCommandRun = false;
        return paint(rgb(PALETTE.code), token);
      }
      if (/^-{1,2}[A-Za-z]/.test(token)) {
        leadingCommandRun = false;
        const dashes = token.match(/^-{1,2}/)?.[0] ?? "";
        return paint(rgb(PALETTE.fg), dashes) + paint(rgb(PALETTE.red), token.slice(dashes.length));
      }
      if (/^\d+(\.\d+)?$/.test(token)) {
        leadingCommandRun = false;
        return paint(rgb(PALETTE.orange), token);
      }
      if (leadingCommandRun) return paint(rgb(PALETTE.blue), token);
      return paint(rgb(PALETTE.fg), token);
    })
    .join("");
}

// Terminal width to draw boxes and rules at. Recomputed per box rather than
// cached: a real herdr pane can resize under the operator, and re-reading
// `columns` is cheap. Falls back to a fixed width when `columns` is
// unavailable — true for a non-TTY stdout (piped output, or this plugin's
// own acceptance check) — so output stays deterministic instead of
// defaulting to whatever width happened to be inherited.
function boxWidth(): number {
  const cols = process.stdout.columns;
  return cols && cols >= 40 ? Math.min(cols, 200) : 78;
}

// Tool boxes are indented by this many columns, matching omp's own transcript
// gutter. Kept as a named constant used for BOTH the emitted prefix and the
// box-width arithmetic, so the two can never drift — the earlier overflow was
// exactly this pair disagreeing, with the gutter printed but not subtracted.
const BOX_INDENT = 2;
const BOX_GUTTER = " ".repeat(BOX_INDENT);

// Word-wraps plain text to `maxChars`, preserving existing line structure and
// blank lines. Every prose path below used to clip only by *line count*
// (`clipLines`), which bounded height but not width, so a long paragraph or a
// numbered list item printed at its natural length and let the terminal wrap
// it. In a narrow pane that overflowed badly — measured 15 rows over on a
// 91-column pane, the widest 184 columns — and a terminal-wrapped row also
// desynced the tool boxes drawn around it, since their borders are sized to
// `boxWidth()` while the wrapped prose was not.
//
// Runs on plain text only, before any ANSI styling, for the same reason
// `clipLineWidth` does: slicing a coloured string by character count can cut
// through an escape sequence. A word longer than the budget is hard-split
// rather than allowed to overflow, so a long unbroken path or URL still cannot
// break the frame.
function wrapPlainText(text: string, maxChars: number): string {
  const budget = Math.max(8, maxChars);
  const out: string[] = [];

  for (const rawLine of text.split("\n")) {
    if (!rawLine.trim()) {
      out.push("");
      continue;
    }
    let current = "";
    for (const word of rawLine.split(/\s+/)) {
      let piece = word;
      while (piece.length > budget) {
        if (current) {
          out.push(current);
          current = "";
        }
        out.push(piece.slice(0, budget));
        piece = piece.slice(budget);
      }
      if (!current) {
        current = piece;
      } else if (current.length + 1 + piece.length <= budget) {
        current = `${current} ${piece}`;
      } else {
        out.push(current);
        current = piece;
      }
    }
    if (current) out.push(current);
  }

  return out.join("\n");
}

// ---------------------------------------------------------------------------
// prose / thinking rendering — single leading space, default fg for prose,
// italic dim for thinking, inline `code` recoloured purple in both (see
// styleProse above)
// ---------------------------------------------------------------------------

function printStyledBlock(text: string, baseCode: string, maxLines: number): void {
  const trimmed = text.trim();
  if (!trimmed) return;
  // Wrap to width *before* clipping to `maxLines`, so the line budget counts
  // rows the operator will actually see. Clipping first would let one very long
  // logical line wrap into many displayed rows and blow past the budget.
  // `- 1` accounts for the single leading space every row below is printed with.
  const wrapped = wrapPlainText(trimmed, boxWidth() - 1);
  const { shown, hiddenLines } = clipLinesForStyling(wrapped, maxLines);
  const styled = styleProse(shown, baseCode);
  for (const line of styled.split("\n")) console.log(` ${line}`);
  if (hiddenLines > 0) console.log(dim(` … (${hiddenLines} more lines)`));
}

// ---------------------------------------------------------------------------
// tool-call boxes
//
// omp appends a `tool_execution_start` custom entry live, the instant a call
// begins, then appends the whole finalized assistant message (text +
// toolCall + toolResult blocks) as a single entry once the turn completes —
// so the same call is described twice in the file, at two different times,
// under two different shapes. `openCalls` is how this viewer correlates
// those two descriptions back into one call by `toolCallId`: whichever of
// (start event, toolCall item) is seen first records the call's identity;
// the toolResult that eventually lands under the same id is rendered as one
// settled box using that identity, not as a second, unrelated line.
//
// This is a scrolling log, not a redrawing TUI (see the file header), so a
// call is still printed twice on the page — an immediate one-line "active"
// indicator when it starts, and the full bordered box once its result lands
// — rather than one block mutated in place. The two are linked by carrying
// the same tool name/argument through both, and by the accent colour itself
// carrying the state transition: lime while nothing is known but that it
// started, dim (or red on error) once the full picture — including output —
// is in.
// ---------------------------------------------------------------------------

interface CallInfo {
  toolName: string;
  argSummary: string | undefined;
  startedAtMs: number | undefined;
}

const openCalls = new Map<string, CallInfo>();

function registerCallInfo(
  toolCallId: string | undefined,
  toolName: string,
  argSummary: string | undefined,
  startedAtMs: number | undefined,
): void {
  if (!toolCallId) return;
  const existing = openCalls.get(toolCallId);
  if (existing) {
    // The two sources describe the same call; keep whichever startedAt was
    // captured first (only `tool_execution_start` carries one at all) rather
    // than letting the second, timestamp-less sighting blank it out.
    if (existing.startedAtMs === undefined && startedAtMs !== undefined) existing.startedAtMs = startedAtMs;
    return;
  }
  openCalls.set(toolCallId, { toolName, argSummary, startedAtMs });
}

function renderActiveLine(toolName: string, argSummary: string | undefined): void {
  // `BOX_GUTTER` + the marker glyph + its trailing space is the fixed prefix, so
  // that is what the label budget subtracts. This used to truncate at a
  // hardcoded 90 characters, which silently overflowed any pane narrower than
  // ~94 columns — the marker line is not inside a box, so nothing else clipped
  // it.
  const budget = Math.max(8, boxWidth() - BOX_INDENT - 2);
  const label =
    toolName === "bash" && argSummary
      ? `$ ${truncate(argSummary, budget - 2)}`
      : argSummary
        ? `${toolName} ${truncate(argSummary, Math.max(4, budget - toolName.length - 1))}`
        : truncate(toolName, budget);
  console.log(`${BOX_GUTTER}${activeColor("◍")} ${activeBold(label)}`);
}

// Renders the invocation (first) line of a settled box's content, inside the
// left border. Bash gets the full syntax-highlighted command (see
// `highlightShellCommand`); every other tool gets `toolName argSummary` with
// the tool name bold. Both are clipped to the box's interior width in plain
// text first, then coloured — coloured text must never be sliced by
// character count, or the cut can land inside an escape sequence.
function renderInvocationLine(toolName: string, argSummary: string | undefined, innerWidth: number): string {
  if (toolName === "bash" && argSummary) {
    return highlightShellCommand(clipLineWidth(argSummary.replace(/\s+/g, " ").trim(), innerWidth));
  }
  if (!argSummary) return fgDefaultBold(clipLineWidth(toolName, innerWidth));
  const budget = Math.max(0, innerWidth - toolName.length - 1);
  const arg = clipLineWidth(argSummary.replace(/\s+/g, " ").trim(), budget);
  return `${fgDefaultBold(toolName)} ${fgDefault(arg)}`;
}

const MAX_TOOL_BODY_LINES = 10;

function printToolResultBox(
  toolName: string,
  argSummary: string | undefined,
  resultText: string,
  isError: boolean,
  wallMs: number | undefined,
): void {
  // Every row below is printed with a 2-column indent, so the box itself only
  // gets `boxWidth() - BOX_INDENT` columns. Sizing the borders to the full
  // terminal width instead is what made the closers (`╮`, `┤`, `╯`) wrap onto
  // their own row and desync the frame — the box came out exactly BOX_INDENT
  // too wide at every terminal size. `span` is the box's outer width including
  // both border glyphs; the dash runs are `span - 2`.
  const span = Math.max(12, boxWidth() - BOX_INDENT);
  const innerWidth = Math.max(10, span - 4);
  const accent = isError ? redColor : dim;
  console.log(`${BOX_GUTTER}${accent(`╭${"─".repeat(span - 2)}╮`)}`);
  console.log(`${BOX_GUTTER}${accent("│")} ${renderInvocationLine(toolName, argSummary, innerWidth)}`);

  const trimmedResult = resultText.trim();
  if (trimmedResult) {
    const dividerLabel = " Output ";
    // The divider row is `├` + three dashes + label + rightLen dashes + `┤`,
    // so it spans 5 fixed glyphs plus the label. Solving for the same `span` the
    // top and bottom borders use keeps all three the identical width — an
    // earlier extra `- 1` here left a one-column notch on the right edge.
    const rightLen = Math.max(1, span - 5 - dividerLabel.length);
    console.log(`${BOX_GUTTER}${accent(`├───${dividerLabel}${"─".repeat(rightLen)}┤`)}`);
    const clip = clipToTail(trimmedResult, MAX_TOOL_BODY_LINES);
    if (clip.truncated) {
      const note = `… (${clip.totalLines - MAX_TOOL_BODY_LINES} earlier lines, showing ${MAX_TOOL_BODY_LINES} of ${clip.totalLines})`;
      console.log(`${BOX_GUTTER}${accent("│")} ${dim(note)}`);
    }
    for (const line of clip.lines) {
      console.log(`${BOX_GUTTER}${accent("│")} ${body(clipLineWidth(line, innerWidth))}`);
    }
  }

  if (wallMs !== undefined) {
    console.log(`${BOX_GUTTER}${accent("│")} ${dim(`⟨Wall: ${(Math.max(0, wallMs) / 1000).toFixed(2)}s⟩`)}`);
  }
  console.log(`${BOX_GUTTER}${accent(`╰${"─".repeat(span - 2)}╯`)}`);
}

// ---------------------------------------------------------------------------
// header
// ---------------------------------------------------------------------------

function printHeader(): void {
  console.log(`${recentBold(subagentId)} ${dim(`[${subagentType}]`)}`);
  // Wrapped, not just line-clipped: a description is one long logical line
  // often enough that leaving it to the terminal was the widest overflow of all.
  if (subagentDesc) console.log(dim(clipLines(wrapPlainText(subagentDesc, boxWidth()), 4)));
  console.log(dim("─".repeat(boxWidth())));
}

// ---------------------------------------------------------------------------
// transcript line rendering
// ---------------------------------------------------------------------------

let sawFirstUserMessage = false;
const MAX_ASSIGNMENT_LINES = 6;
const MAX_PROSE_LINES = 20;
const MAX_THINKING_LINES = 8;

function renderUserMessage(content: unknown[]): void {
  const text = extractText(content);
  if (!text) return;
  const label = sawFirstUserMessage ? "user" : "assignment";
  sawFirstUserMessage = true;
  console.log(dim(`\n[${label}]`));
  console.log(dim(clipLines(wrapPlainText(text, boxWidth()), MAX_ASSIGNMENT_LINES)));
}

function renderAssistantMessage(content: unknown[]): void {
  for (const item of content) {
    if (!isRecord(item)) continue;
    const itemType = asString(item.type);
    if (itemType === "text") {
      const text = asString(item.text);
      if (text) printStyledBlock(text, rgb(PALETTE.fg), MAX_PROSE_LINES);
    } else if (itemType === "thinking") {
      const thinking = asString(item.thinking);
      if (thinking) printStyledBlock(thinking, `3;${rgb(PALETTE.body)}`, MAX_THINKING_LINES);
    } else if (itemType === "toolCall") {
      // Not rendered here — only captured, as a fallback identity source for
      // a call whose `tool_execution_start` was never seen (e.g. a call that
      // was rejected before it ever started executing; see the toolCallId
      // correlation comment above `openCalls`). Rendering it too would print
      // every normally-started call a third time.
      const toolCallId = asString(item.id);
      const toolName = asString(item.name) ?? "tool";
      const args = isRecord(item.arguments) ? item.arguments : undefined;
      registerCallInfo(toolCallId, toolName, args ? summaryArg(toolName, args) : undefined, undefined);
    }
  }
}

function renderToolResult(message: Record<string, unknown>): void {
  const toolCallId = asString(message.toolCallId);
  const info = toolCallId ? openCalls.get(toolCallId) : undefined;
  const toolName = info?.toolName ?? asString(message.toolName) ?? "tool";
  const isError = message.isError === true;
  const content = asArray(message.content);
  const text = content ? extractText(content) : "";
  const resultTsMs = asNumber(message.timestamp);
  const wallMs =
    info?.startedAtMs !== undefined && resultTsMs !== undefined ? resultTsMs - info.startedAtMs : undefined;
  printToolResultBox(toolName, info?.argSummary, text, isError, wallMs);
  // Drop the entry once resolved — a long-running subagent can make hundreds
  // of calls, and nothing after this point ever looks the id up again.
  if (toolCallId) openCalls.delete(toolCallId);
}

function renderMessage(messageValue: unknown): void {
  if (!isRecord(messageValue)) return;
  const role = asString(messageValue.role);
  if (role === "user") {
    renderUserMessage(asArray(messageValue.content) ?? []);
  } else if (role === "assistant") {
    renderAssistantMessage(asArray(messageValue.content) ?? []);
  } else if (role === "toolResult") {
    renderToolResult(messageValue);
  }
}

// Per-tool key to pull out of `args` as "the most identifying argument" —
// deliberately a flat Record over a switch, since it is genuinely just a
// static lookup table and every entry is a plain string constant.
const ARG_KEY_BY_TOOL: Record<string, string> = {
  read: "path",
  write: "path",
  edit: "path",
  glob: "path",
  bash: "command",
  grep: "pattern",
  task: "i",
  browser: "url",
  webSearch: "query",
  web_search: "query",
};

function firstStringValue(args: Record<string, unknown>): string | undefined {
  for (const value of Object.values(args)) {
    if (typeof value === "string" && value.trim()) return value;
  }
  return undefined;
}

// args is absent for some tool invocations (e.g. a no-argument call) — the
// caller falls back to just the tool name per the acceptance criteria rather
// than printing "undefined".
function summaryArg(toolName: string, args: Record<string, unknown>): string | undefined {
  const preferredKey = ARG_KEY_BY_TOOL[toolName];
  const preferred = preferredKey ? asString(args[preferredKey]) : undefined;
  const intent = asString(args.i);
  return preferred ?? intent ?? firstStringValue(args);
}

function renderToolStart(data: unknown): void {
  if (!isRecord(data)) return;
  const toolCallId = asString(data.toolCallId);
  const toolName = asString(data.toolName) ?? "tool";
  const args = isRecord(data.args) ? data.args : undefined;
  const argSummary = args ? summaryArg(toolName, args) : undefined;
  const startedAtMs = Date.parse(asString(data.startedAt) ?? "");
  registerCallInfo(toolCallId, toolName, argSummary, Number.isFinite(startedAtMs) ? startedAtMs : undefined);
  renderActiveLine(toolName, argSummary);
}

let sawSessionExit = false;

function renderCustom(customType: string | undefined, data: unknown): void {
  if (customType === "tool_execution_start") {
    renderToolStart(data);
  } else if (customType === "session_exit") {
    // Used only as a settle fallback (see the main loop) when no state file
    // was provided at all — real panes always get OMP_SUBAGENT_STATE from the
    // extension, so this rarely does anything.
    sawSessionExit = true;
  }
  // Other custom types observed in real transcripts (user_todo_edit, etc.)
  // are the subagent's own planning/bookkeeping, not requested by the
  // acceptance criteria, and are skipped to keep the pane focused on
  // assignment / response / tool activity.
}

function handleLine(raw: string): void {
  const trimmed = raw.trim();
  if (!trimmed) return;
  let entry: unknown;
  try {
    entry = JSON.parse(trimmed);
  } catch {
    // A malformed or (should not happen — see consume()) partial line.
    // Transcripts are append-only and each complete line is independently
    // valid JSON, so this only fires on genuine corruption; skipping it beats
    // crashing the whole pane over one bad line.
    return;
  }
  if (!isRecord(entry)) return;
  const kind = asString(entry.type);
  if (kind === "message") {
    renderMessage(entry.message);
  } else if (kind === "custom") {
    renderCustom(asString(entry.customType), entry.data);
  }
  // session / session_init / title / model_change / thinking_level_change
  // carry no operator-visible transcript content — the header above already
  // gets id/type/description from the env the extension set, not from these.
}

// Feeds newly-read bytes through handleLine one full line at a time, holding
// back a trailing partial line (no newline yet) across calls so a read that
// lands mid-line never gets parsed as JSON and silently dropped.
function consume(chunk: string, pending: string): string {
  const combined = pending + chunk;
  const lines = combined.split("\n");
  const leftover = lines.pop() ?? "";
  for (const line of lines) handleLine(line);
  return leftover;
}

// ---------------------------------------------------------------------------
// state file
// ---------------------------------------------------------------------------

interface AgentState {
  status: string;
  startedAt?: number;
  endedAt?: number;
}

function readState(path: string): AgentState | undefined {
  let raw: string;
  try {
    raw = readFileSync(path, "utf8");
  } catch {
    return undefined; // not written yet, or briefly absent mid atomic-rewrite
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return undefined; // caught the file mid-write; the next poll retries
  }
  if (!isRecord(parsed)) return undefined;
  const status = asString(parsed.status);
  if (!status) return undefined;
  return { status, startedAt: asNumber(parsed.startedAt), endedAt: asNumber(parsed.endedAt) };
}

function formatElapsed(ms: number): string {
  const totalSeconds = Math.max(0, Math.round(ms / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return minutes > 0 ? `${minutes}m${String(seconds).padStart(2, "0")}s` : `${seconds}s`;
}

function statusColor(status: string): (s: string) => string {
  if (status === "completed") return greenColor;
  if (status === "failed" || status === "aborted") return redColor;
  return recentBold;
}

// ---------------------------------------------------------------------------
// quit handling — 'q' or ctrl+c, both while streaming and while parked
// ---------------------------------------------------------------------------

process.on("SIGINT", () => process.exit(0));

function waitForQuitKey(): Promise<void> {
  return new Promise((resolve) => {
    const stdin = process.stdin;
    const canRaw = typeof stdin.setRawMode === "function";
    if (canRaw) stdin.setRawMode(true);
    stdin.resume();
    stdin.setEncoding("utf8");
    const onData = (key: string): void => {
      if (key === "q" || key === "\u0003") {
        if (canRaw) stdin.setRawMode(false);
        stdin.pause();
        stdin.off("data", onData);
        resolve();
      }
    };
    stdin.on("data", onData);
  });
}

// ---------------------------------------------------------------------------
// autoclose — see the header comment above for why the pane's own process,
// not the omp extension that opened it, is what closes it
// ---------------------------------------------------------------------------

// Poll cadence and cap for waiting out operator focus once the subagent has
// settled. 2s is frequent enough that closing reads as prompt without
// hammering herdr every tick; the 10-minute cap is long enough that a
// genuinely brief glance at a finished pane never gets closed out from under
// the operator (they are only ever protected from an *unfocus* event, this
// cap doesn't change that), but short enough that a pane the operator has
// actually parked in falls back to a manual quit rather than polling
// silently in the background forever.
const FOCUS_POLL_INTERVAL_MS = 2000;
const FOCUS_POLL_TIMEOUT_MS = 10 * 60 * 1000;

// Reads this pane's own focus state via a read-only `herdr pane get` —
// never `pane close`, `pane rename`, or anything else that mutates herdr
// state (see the header comment and `autocloseAfterSettle` below). Every
// failure mode here — herdr missing from PATH, the pane already gone, a
// malformed or unexpected response shape — collapses to "not focused"
// rather than throwing or retrying: the documented default is that a
// settled pane closes, so a broken focus probe should fail toward closing
// it, never toward orphaning it forever.
function isPaneFocused(paneId: string): boolean {
  let exitCode: number;
  let stdout: string;
  try {
    const probe = Bun.spawnSync([process.env.HERDR_BIN_PATH ?? "herdr", "pane", "get", paneId], {
      stdout: "pipe",
      stderr: "ignore",
    });
    exitCode = probe.exitCode;
    stdout = probe.stdout.toString("utf8");
  } catch {
    return false; // herdr not on PATH, or not spawnable at all
  }
  if (exitCode !== 0) return false; // most often pane_not_found — nothing left to close
  let parsed: unknown;
  try {
    parsed = JSON.parse(stdout);
  } catch {
    return false;
  }
  if (!isRecord(parsed)) return false;
  const result = parsed.result;
  if (!isRecord(result)) return false;
  const pane = result.pane;
  if (!isRecord(pane)) return false;
  return pane.focused === true;
}

// Closes this pane once it is safe to: exits the process, status 0, the
// instant the pane is not focused. That exit *is* the close — Herdr reaps a
// plugin pane the moment its entrypoint process ends (verified live: sending
// `q` to an orphaned viewer made `herdr pane get` immediately report the
// pane gone) — so nothing here ever calls `herdr plugin pane close` or any
// other state-mutating command; the only herdr call anywhere in this
// function is the read-only focus probe above.
//
// This lives in the viewer, not in the omp extension that opens the pane,
// because only the viewer's own process lifetime tracks the pane's
// lifetime. The extension used to run this exact "wait for unfocus, then
// close" loop itself, on its own poll timer — but that timer lives inside
// the omp process, and an omp session that exits before the operator
// unfocuses (any `omp -p` run, in particular) tears the whole extension
// host down mid-wait. Verified live: pane `w8:p1K` settled while focused,
// the owning omp process exited, and the pane was still open 12s after
// focus moved away — orphaned for good, because nothing was left running to
// finish the wait and issue the close. The viewer has no such gap: it *is*
// the pane's command, so its process lives exactly as long as the pane does
// either way.
async function autocloseAfterSettle(): Promise<void> {
  const paneId = process.env.HERDR_PANE_ID;

  // No pane id at all (a hand-run viewer outside herdr, or herdr failing to
  // inject it) or already unfocused: nothing to wait out, close now. No
  // delay here matters for an unattended fan-out — dozens of subagent panes
  // settling at once should clean themselves up immediately, not stagger
  // through even one avoidable poll tick apiece.
  if (!paneId || !isPaneFocused(paneId)) {
    process.exit(0);
  }

  console.log(dim("pane focused — will close automatically once focus moves away"));
  const deadline = Date.now() + FOCUS_POLL_TIMEOUT_MS;
  while (Date.now() < deadline) {
    await sleep(FOCUS_POLL_INTERVAL_MS);
    if (!isPaneFocused(paneId)) process.exit(0);
  }

  // Focused for the entire cap: the operator has made their intent clear by
  // parking here rather than just glancing over. Stop polling and fall back
  // to the ordinary manual-quit path so the pane is still closeable by hand
  // instead of a background poll that never gives up.
  console.log(dim("still focused after 10m — press q or ctrl+c to close"));
  if (isLivePane && process.stdin.isTTY) await waitForQuitKey();
  process.exit(0);
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

const POLL_INTERVAL_MS = 200;
// No-growth ticks to wait before treating a transcript as settled when no
// state file was given at all. This only matters for the no-state case (a
// manual `bun run` against an already-finished transcript, as in this
// plugin's own acceptance check) — a pane opened by the extension always has
// OMP_SUBAGENT_STATE and settles from a real terminal status instead.
const FALLBACK_IDLE_TICKS = 5;

async function waitForFile(path: string): Promise<void> {
  let announced = false;
  while (!existsSync(path)) {
    if (!announced) {
      console.log(dim(`waiting for transcript at ${path} …`));
      announced = true;
    }
    await sleep(POLL_INTERVAL_MS);
  }
}

function fileSize(path: string, fallback: number): number {
  try {
    return statSync(path).size;
  } catch {
    return fallback; // file briefly missing mid-rotation — treat as "no new bytes"
  }
}

async function main(): Promise<void> {
  const filePath = subagentFile as string;
  await waitForFile(filePath);
  printHeader();

  let offset = 0;
  let pending = "";
  let idleTicks = 0;
  let sawGrowthEver = false;
  let lastStatus: string | undefined;
  let stateStartedAt: number | undefined;

  const viewerStartedAt = Date.now();
  let settled = false;
  let settledStatus = "unknown";
  let settledEndedAt: number | undefined;

  while (!settled) {
    const size = fileSize(filePath, offset);
    if (size < offset) {
      // File was truncated or replaced under us — restart from the top
      // rather than reading negative-length garbage.
      offset = 0;
      pending = "";
    }
    if (size > offset) {
      const chunk = await Bun.file(filePath).slice(offset, size).text();
      offset = size;
      pending = consume(chunk, pending);
      sawGrowthEver = true;
      idleTicks = 0;
    } else {
      idleTicks += 1;
    }

    const state = subagentState ? readState(subagentState) : undefined;
    if (state) {
      if (state.startedAt !== undefined) stateStartedAt = state.startedAt;
      if (state.status !== lastStatus) {
        lastStatus = state.status;
        console.log(dim(`\n[status] ${state.status}`));
      }
      if (state.status !== "started") {
        settled = true;
        settledStatus = state.status;
        settledEndedAt = state.endedAt;
      }
    } else if (!subagentState && sawGrowthEver && idleTicks >= FALLBACK_IDLE_TICKS) {
      settled = true;
      settledStatus = sawSessionExit ? "exited" : "unknown";
    }

    if (!settled) await sleep(POLL_INTERVAL_MS);
  }

  const elapsedMs =
    stateStartedAt !== undefined && settledEndedAt !== undefined
      ? settledEndedAt - stateStartedAt
      : Date.now() - viewerStartedAt;

  console.log(dim("─".repeat(boxWidth())));
  const color = statusColor(settledStatus);
  console.log(`${color(`[${settledStatus}]`)} ${recentBold(subagentId)} settled after ${formatElapsed(elapsedMs)}`);

  if (subagentAutoclose) {
    await autocloseAfterSettle();
    // Every path through autocloseAfterSettle calls process.exit; async
    // functions can't be typed `never`, so this is unreachable in practice
    // rather than by the type system. Kept explicit so nothing below it
    // could ever be mistaken for still-live code.
    return;
  }

  // Gated on isLivePane (see its definition above), not just stdin.isTTY:
  // a real herdr pane's stdin is a TTY too, but so is a developer's own shell
  // running this file directly, and the latter — this plugin's own
  // acceptance check included — must exit on its own rather than block
  // forever on a keypress nobody is going to send it.
  if (isLivePane && process.stdin.isTTY) {
    console.log(dim("press q or ctrl+c to close"));
    await waitForQuitKey();
  }
  process.exit(0);
}

await main();
