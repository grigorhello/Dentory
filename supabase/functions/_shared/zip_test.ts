// deno test supabase/functions (make functions-check): the zip writer, read back entry by entry.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { crc32, zip } from "./zip.ts";

Deno.test("crc32 matches the standard check value", () => {
  assertEquals(crc32(new TextEncoder().encode("123456789")), 0xcbf43926);
});

Deno.test("an archive lists every entry with its UTF-8 name and gives back the same bytes", async () => {
  const entries = [
    { name: "products.csv", data: new TextEncoder().encode("﻿Name\r\nÉvangéline\r\n".repeat(200)) },
    { name: "empty.csv", data: new Uint8Array() },
    { name: "notes-é.csv", data: new TextEncoder().encode("a,b\r\n") },
  ];
  const archive = await zip(entries, new Date(Date.UTC(2026, 9, 20, 13, 45, 30)));
  const view = new DataView(archive.buffer, archive.byteOffset, archive.byteLength);

  const end = archive.length - 22;
  assertEquals(view.getUint32(end, true), 0x06054b50);
  assertEquals(view.getUint16(end + 10, true), entries.length);
  let central = view.getUint32(end + 16, true);
  assertEquals(central + view.getUint32(end + 12, true), end);

  for (const entry of entries) {
    assertEquals(view.getUint32(central, true), 0x02014b50);
    assertEquals(view.getUint16(central + 8, true), 0x0800, "UTF-8 names");
    assertEquals(view.getUint16(central + 10, true), 8, "deflated");
    assertEquals(view.getUint16(central + 12, true), (13 << 11) | (45 << 5) | 15, "time");
    assertEquals(view.getUint16(central + 14, true), (46 << 9) | (10 << 5) | 20, "date");
    const nameLength = view.getUint16(central + 28, true);
    assertEquals(new TextDecoder().decode(archive.slice(central + 46, central + 46 + nameLength)), entry.name);
    const compressedSize = view.getUint32(central + 20, true);
    assertEquals(view.getUint32(central + 24, true), entry.data.length);
    assertEquals(view.getUint32(central + 16, true), crc32(entry.data));

    const local = view.getUint32(central + 42, true);
    assertEquals(view.getUint32(local, true), 0x04034b50);
    const start = local + 30 + view.getUint16(local + 26, true) + view.getUint16(local + 28, true);
    const compressed = archive.slice(start, start + compressedSize);
    const inflated = new Uint8Array(
      await new Response(new Blob([compressed]).stream().pipeThrough(new DecompressionStream("deflate-raw")))
        .arrayBuffer(),
    );
    assertEquals(inflated, entry.data);
    central += 46 + nameLength;
  }
  assert(archive.length < 2000, "the repeated rows compress");
});
