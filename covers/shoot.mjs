// Shoots one page at 1440×900, 2x, dark mode after a real-time wait, over the Chrome DevTools Protocol.
// Usage: node covers/shoot.mjs <chrome> <url> <out.jpg>   (Node 22+, no dependencies)
//
// Why not `chrome --headless --screenshot --virtual-time-budget`? Virtual time skips ahead whenever
// the page is idle, so timers and fetches settle instantly, but requestAnimationFrame only advances
// with real frames. rAF-driven intros (Five's count-up loading clock) were caught half-way.
// Here the page runs on the wall clock: wait for load, then COVER_WAIT_MS (default 8000) more.
import { spawn } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const [chrome, url, out] = process.argv.slice(2);
if (!out) {
  console.error("usage: node covers/shoot.mjs <chrome> <url> <out.jpg>");
  process.exit(2);
}
const waitMs = Number(process.env.COVER_WAIT_MS ?? 8000);
const extraFlags = (process.env.CHROME_FLAGS ?? "").split(/\s+/).filter(Boolean);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const profile = mkdtempSync(join(tmpdir(), "covers-chrome-"));
const proc = spawn(chrome, [
  "--headless", ...extraFlags, "--remote-debugging-port=0", `--user-data-dir=${profile}`,
  "--hide-scrollbars", "--force-dark-mode", "--blink-settings=preferredColorScheme=0",
  "--no-first-run", "--no-default-browser-check", "about:blank",
], { stdio: "ignore" });

let ws;
const cleanup = () => {
  try { ws?.close(); } catch {}
  proc.kill();
  // Chrome may still hold the profile for a moment after the kill.
  setTimeout(() => rmSync(profile, { recursive: true, force: true }), 500);
};

try {
  // Port 0 lets Chrome pick a free port; it writes it to DevToolsActivePort in the profile.
  let port;
  for (let i = 0; i < 100 && !port; i++) {
    try { port = readFileSync(join(profile, "DevToolsActivePort"), "utf8").split("\n")[0]; } catch { await sleep(100); }
  }
  if (!port) throw new Error("Chrome did not start (no DevToolsActivePort)");

  const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
  const page = targets.find((t) => t.type === "page");
  ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });

  let nextId = 0;
  const pending = new Map();
  const listeners = new Map();
  ws.onmessage = (e) => {
    const msg = JSON.parse(e.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      msg.error ? reject(new Error(`${msg.error.message}`)) : resolve(msg.result);
    } else if (msg.method && listeners.has(msg.method)) {
      listeners.get(msg.method)(msg.params);
    }
  };
  // Every command gets a deadline, so a page that wedges Chrome fails the capture instead of hanging it.
  const send = (method, params = {}, timeoutMs = 30000) => new Promise((resolve, reject) => {
    const id = ++nextId;
    const t = setTimeout(() => { pending.delete(id); reject(new Error(`${method} timed out`)); }, timeoutMs);
    pending.set(id, {
      resolve: (v) => { clearTimeout(t); resolve(v); },
      reject: (e) => { clearTimeout(t); reject(e); },
    });
    if (process.env.COVER_DEBUG) console.error(`-> ${method}`);
    ws.send(JSON.stringify({ id, method, params }));
  });
  const once = (method, timeoutMs) => new Promise((resolve) => {
    const t = setTimeout(resolve, timeoutMs); // a slow third-party asset shouldn't block the shot
    listeners.set(method, () => { clearTimeout(t); resolve(); });
  });

  await send("Page.enable");
  await send("Emulation.setDeviceMetricsOverride", { width: 1440, height: 900, deviceScaleFactor: 2, mobile: false });
  await send("Emulation.setEmulatedMedia", { features: [{ name: "prefers-color-scheme", value: "dark" }] });
  const loaded = once("Page.loadEventFired", 30000);
  const nav = await send("Page.navigate", { url });
  if (nav.errorText) throw new Error(`navigation failed: ${nav.errorText}`);
  await loaded;
  await sleep(waitMs);

  // JPEG at full quality: PNG encoding hangs on some pages (zero), and capture.sh re-encodes anyway.
  const { data } = await send("Page.captureScreenshot", { format: "jpeg", quality: 100 });
  writeFileSync(out, Buffer.from(data, "base64"));
  cleanup();
} catch (err) {
  console.error(`shoot failed: ${url}: ${err.message}`);
  cleanup();
  process.exit(1);
}
