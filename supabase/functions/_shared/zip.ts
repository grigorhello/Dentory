// A small ZIP writer (MS-143): deflated entries with UTF-8 names, through the runtime's CompressionStream, so the export
// needs no library. Enough for a handful of files of a few megabytes.

export interface ZipEntry {
  name: string;
  data: Uint8Array;
}

export async function zip(entries: ZipEntry[], date = new Date()): Promise<Uint8Array> {
  const { time, day } = dosDateTime(date);
  const locals: Uint8Array[] = [];
  const centrals: Uint8Array[] = [];
  let offset = 0;
  for (const entry of entries) {
    const name = new TextEncoder().encode(entry.name);
    const compressed = await deflateRaw(entry.data);
    const crc = crc32(entry.data);
    const local = header(30 + name.length, (view) => {
      view.setUint32(0, 0x04034b50, true);
      view.setUint16(4, 20, true);
      view.setUint16(6, 0x0800, true);
      view.setUint16(8, 8, true);
      view.setUint16(10, time, true);
      view.setUint16(12, day, true);
      view.setUint32(14, crc, true);
      view.setUint32(18, compressed.length, true);
      view.setUint32(22, entry.data.length, true);
      view.setUint16(26, name.length, true);
    }, name, 30);
    const central = header(46 + name.length, (view) => {
      view.setUint32(0, 0x02014b50, true);
      view.setUint16(4, 20, true);
      view.setUint16(6, 20, true);
      view.setUint16(8, 0x0800, true);
      view.setUint16(10, 8, true);
      view.setUint16(12, time, true);
      view.setUint16(14, day, true);
      view.setUint32(16, crc, true);
      view.setUint32(20, compressed.length, true);
      view.setUint32(24, entry.data.length, true);
      view.setUint16(28, name.length, true);
      view.setUint32(42, offset, true);
    }, name, 46);
    locals.push(local, compressed);
    centrals.push(central);
    offset += local.length + compressed.length;
  }
  const centralSize = centrals.reduce((sum, part) => sum + part.length, 0);
  const end = header(22, (view) => {
    view.setUint32(0, 0x06054b50, true);
    view.setUint16(8, entries.length, true);
    view.setUint16(10, entries.length, true);
    view.setUint32(12, centralSize, true);
    view.setUint32(16, offset, true);
  });
  return concat([...locals, ...centrals, end]);
}

function header(length: number, write: (view: DataView) => void, name?: Uint8Array, nameAt = 0): Uint8Array {
  const bytes = new Uint8Array(length);
  write(new DataView(bytes.buffer));
  if (name) bytes.set(name, nameAt);
  return bytes;
}

async function deflateRaw(data: Uint8Array): Promise<Uint8Array> {
  // slice(): a copy on its own ArrayBuffer, which Blob's type asks for.
  const stream = new Blob([data.slice()]).stream().pipeThrough(new CompressionStream("deflate-raw"));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

function concat(parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((sum, part) => sum + part.length, 0));
  let at = 0;
  for (const part of parts) {
    out.set(part, at);
    at += part.length;
  }
  return out;
}

/** MS-DOS time and date, as ZIP keeps them; in UTC, which the files' readers show as is. */
function dosDateTime(date: Date): { time: number; day: number } {
  const time = (date.getUTCHours() << 11) | (date.getUTCMinutes() << 5) | Math.floor(date.getUTCSeconds() / 2);
  const day = ((date.getUTCFullYear() - 1980) << 9) | ((date.getUTCMonth() + 1) << 5) | date.getUTCDate();
  return { time, day };
}

const crcTable = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();

export function crc32(data: Uint8Array): number {
  let crc = 0xffffffff;
  for (const byte of data) crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}
