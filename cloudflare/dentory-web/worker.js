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
};

const AASA = "/.well-known/apple-app-site-association";

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

    // /privacy.html becomes /privacy, so App Store links and the pages agree.
    if (r.path.endsWith(".html")) {
      const clean = r.path.replace(/(index)?\.html$/, "");
      return Response.redirect(`${url.origin}${url.pathname.slice(0, url.pathname.length - r.path.length)}${clean}${url.search}`, 301);
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
      return new Response(request.method === "HEAD" ? null : upstream.body, { status: 200, headers });
    }
    return page(404, "Page not found", "This page does not exist.");
  },
};
