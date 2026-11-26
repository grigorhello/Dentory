// Dentory web: serves dentory.ca from site/ and app.dentory.ca from applinks/,
// straight from this repository on GitHub, so a merge to the default branch is a
// deploy. See cloudflare/dentory-web/README.md.

const REPO_RAW = "https://raw.githubusercontent.com/grigorhello/dentory";

const TYPES = {
  html: "text/html; charset=utf-8",
  css: "text/css; charset=utf-8",
  js: "text/javascript; charset=utf-8",
  png: "image/png",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  webp: "image/webp",
  svg: "image/svg+xml",
  ico: "image/x-icon",
  txt: "text/plain; charset=utf-8",
  pdf: "application/pdf",
  mp4: "video/mp4",
};

const AASA = "/.well-known/apple-app-site-association";

// Short addresses the app or the listing use. Account's Help opens /help (MS-137).
const ALIASES = { site: { "/help": "/support" } };

// Which folder of the repository a host serves. Any other host (the workers.dev
// preview) serves site/, and applinks/ under /_app/.
function route(host, path) {
  if (host === "www.dentory.ca") return { redirect: `https://dentory.ca${path}` };
  if (host === "app.dentory.ca") return { folder: "applinks", path };
  if (host === "dentory.ca") return { folder: "site", path };
  if (path === "/_app" || path.startsWith("/_app/")) return { folder: "applinks", path: path.slice(5) || "/" };
  return { folder: "site", path };
}

// The repository files a clean path may be, in order. null means not served.
export function candidates(folder, path) {
  if (path.includes("..") || path.includes("//") || /\/[._]/.test(path.replace(AASA, ""))) return null;
  if (folder === "applinks" && path === AASA) return [{ file: AASA, type: "application/json" }];
  const ext = (path.match(/\.([a-z0-9]+)$/i) || [])[1];
  if (ext) {
    const type = TYPES[ext.toLowerCase()];
    return type ? [{ file: path, type }] : null;
  }
  const base = path.replace(/\/+$/, "");
  const html = TYPES.html;
  return base === "" ? [{ file: "/index.html", type: html }] : [{ file: `${base}.html`, type: html }, { file: `${base}/index.html`, type: html }];
}

// A byte range of a file of `size` bytes: { start, end } (inclusive), null to send
// the whole file (no header, or a form we do not serve such as several ranges), or
// "invalid" for 416. Safari plays a video only when this works (it asks bytes=0-1 first).
export function byteRange(header, size) {
  const m = /^bytes=(\d*)-(\d*)$/.exec((header || "").trim());
  if (!m || (m[1] === "" && m[2] === "")) return null;
  let start;
  let end;
  if (m[1] === "") {
    const suffix = Number(m[2]);
    if (suffix === 0) return "invalid";
    start = Math.max(0, size - suffix);
    end = size - 1;
  } else {
    start = Number(m[1]);
    end = m[2] === "" ? size - 1 : Math.min(Number(m[2]), size - 1);
  }
  if (start > end || start >= size) return "invalid";
  return { start, end };
}

// Video goes out whole or as the requested byte range.
async function video(request, upstream, headers) {
  const body = await upstream.arrayBuffer();
  const size = body.byteLength;
  headers.set("accept-ranges", "bytes");
  const range = byteRange(request.headers.get("range"), size);
  if (range === "invalid") return new Response(null, { status: 416, headers: { "content-range": `bytes */${size}`, "accept-ranges": "bytes" } });
  const head = request.method === "HEAD";
  if (!range) {
    headers.set("content-length", String(size));
    return new Response(head ? null : body, { status: 200, headers });
  }
  headers.set("content-range", `bytes ${range.start}-${range.end}/${size}`);
  headers.set("content-length", String(range.end - range.start + 1));
  return new Response(head ? null : body.slice(range.start, range.end + 1), { status: 206, headers });
}

function page(status, title, text) {
  const body = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Dentory · ${title}</title><style>body{font-family:Inter,system-ui,sans-serif;color:#1c1b1a;background:#fffefb;max-width:720px;margin:0 auto;padding:24px;line-height:1.5}a{color:#2457f5}</style></head><body><p><a href="https://dentory.ca/">Dentory</a></p><h1>${title}</h1><p>${text}</p></body></html>`;
  return new Response(body, { status, headers: { "content-type": TYPES.html, "cache-control": "no-store" } });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method !== "GET" && request.method !== "HEAD") return new Response(null, { status: 405, headers: { allow: "GET, HEAD" } });

    const r = route(url.hostname, url.pathname);
    if (r.redirect) return Response.redirect(r.redirect + url.search, 301);

    const prefix = url.pathname.slice(0, url.pathname.length - r.path.length);
    const alias = ALIASES[r.folder]?.[r.path.replace(/\/+$/, "")];
    if (alias) return Response.redirect(`${url.origin}${prefix}${alias}${url.search}`, 302);

    // /privacy.html becomes /privacy, so App Store links and the pages agree.
    if (r.path.endsWith(".html")) {
      const clean = r.path.replace(/(index)?\.html$/, "");
      return Response.redirect(`${url.origin}${prefix}${clean}${url.search}`, 301);
    }

    const list = candidates(r.folder, r.path);
    if (!list) return page(404, "Page not found", "This page does not exist.");

    const ref = env.REF || "HEAD";
    const ttl = Number(env.CACHE_SECONDS || 300);
    for (const c of list) {
      const upstream = await fetch(`${REPO_RAW}/${ref}/${r.folder}${c.file}`, { cf: { cacheTtl: ttl, cacheEverything: true } });
      if (upstream.status === 404) continue;
      if (!upstream.ok) return page(502, "Try again in a minute", "The page could not be loaded just now.");
      // A fresh set of headers: GitHub's own (text/plain, nosniff, a sandbox CSP) must not reach the browser.
      const headers = new Headers({ "content-type": c.type, "cache-control": `public, max-age=${ttl}`, "x-content-type-options": "nosniff" });
      if (c.type.startsWith("video/")) return video(request, upstream, headers);
      return new Response(request.method === "HEAD" ? null : upstream.body, { status: 200, headers });
    }
    return page(404, "Page not found", "This page does not exist.");
  },
};
