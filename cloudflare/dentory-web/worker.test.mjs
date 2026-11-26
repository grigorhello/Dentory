// node --test cloudflare/dentory-web/worker.test.mjs   (node 22; no network: GitHub is stubbed)
import { test } from "node:test";
import assert from "node:assert/strict";
import worker, { byteRange, candidates } from "./worker.js";

test("byteRange", () => {
  assert.deepEqual(byteRange("bytes=0-1", 100), { start: 0, end: 1 });
  assert.deepEqual(byteRange("bytes=10-", 100), { start: 10, end: 99 });
  assert.deepEqual(byteRange("bytes=-10", 100), { start: 90, end: 99 });
  assert.deepEqual(byteRange("bytes=-500", 100), { start: 0, end: 99 });
  assert.deepEqual(byteRange("bytes=50-500", 100), { start: 50, end: 99 });
  assert.equal(byteRange("bytes=100-", 100), "invalid");
  assert.equal(byteRange("bytes=5-2", 100), "invalid");
  assert.equal(byteRange("bytes=-0", 100), "invalid");
  assert.equal(byteRange("bytes=0-1,5-6", 100), null);
  assert.equal(byteRange(null, 100), null);
});

test("candidates", () => {
  assert.deepEqual(candidates("site", "/media/demo.mp4"), [{ file: "/media/demo.mp4", type: "video/mp4" }]);
  assert.equal(candidates("site", "/media/demo.mov"), null);
});

test("video is served whole or by range", async () => {
  const bytes = new Uint8Array(1000).map((_, i) => i % 256);
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (u) => (String(u).endsWith("/site/media/demo.mp4") ? new Response(bytes) : new Response("", { status: 404 }));
  try {
    const get = (range) => worker.fetch(new Request("https://dentory.ca/media/demo.mp4", range ? { headers: { range } } : {}), {});
    let r = await get("bytes=0-1");
    assert.equal(r.status, 206);
    assert.equal(r.headers.get("content-range"), "bytes 0-1/1000");
    assert.equal(r.headers.get("content-type"), "video/mp4");
    assert.deepEqual([...new Uint8Array(await r.arrayBuffer())], [0, 1]);
    r = await get();
    assert.equal(r.status, 200);
    assert.equal(r.headers.get("accept-ranges"), "bytes");
    assert.equal((await r.arrayBuffer()).byteLength, 1000);
    r = await get("bytes=1000-");
    assert.equal(r.status, 416);
    assert.equal(r.headers.get("content-range"), "bytes */1000");
  } finally {
    globalThis.fetch = realFetch;
  }
});
