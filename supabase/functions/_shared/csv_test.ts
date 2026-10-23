// deno test supabase/functions (make functions-check): CSV cells and files as Excel and Numbers read them.
import { assertEquals } from "jsr:@std/assert@1";
import { csv, numberCell, textCell } from "./csv.ts";

Deno.test("a text cell is quoted when it holds a comma, a quote or a line break", () => {
  assertEquals(textCell("Patterson"), "Patterson");
  assertEquals(textCell("Gauze, 2x2"), '"Gauze, 2x2"');
  assertEquals(textCell('Septocaine 4% "épi"'), '"Septocaine 4% ""épi"""');
  assertEquals(textCell("Dropped\ncracked"), '"Dropped\ncracked"');
  assertEquals(textCell(null), "");
  assertEquals(textCell(undefined), "");
});

Deno.test("a text cell that starts like a formula stays text", () => {
  assertEquals(textCell("=1+1"), "'=1+1");
  assertEquals(textCell("+1 555"), "'+1 555");
  assertEquals(textCell("-5 left"), "'-5 left");
  assertEquals(textCell("@supplier"), "'@supplier");
  assertEquals(textCell("\tTabbed"), "'\tTabbed");
  assertEquals(textCell('=HYPERLINK("x")'), `"'=HYPERLINK(""x"")"`);
});

Deno.test("a number cell has a point, no thousands separator and no trailing zeros", () => {
  assertEquals(numberCell(1.8), "1.8");
  assertEquals(numberCell(-10), "-10");
  assertEquals(numberCell(1234567.25), "1234567.25");
  assertEquals(numberCell("30.00"), "30");
  assertEquals(numberCell(null), "");
  assertEquals(numberCell(Number.NaN), "");
});

Deno.test("a file starts with the byte order mark, ends lines with CRLF and keeps accents in UTF-8", () => {
  const bytes = csv([{ header: "Name", cell: (row: { name: string }) => textCell(row.name) }], [{ name: "Évangéline" }]);
  assertEquals(Array.from(bytes.slice(0, 3)), [0xef, 0xbb, 0xbf]);
  assertEquals(new TextDecoder().decode(bytes.slice(3)), "Name\r\nÉvangéline\r\n");
});
