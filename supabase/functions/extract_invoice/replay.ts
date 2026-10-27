// The reader on the local stack, which has no ANTHROPIC_API_KEY (MS-136): the five fixture invoices (fixtures/README.md)
// get their recorded answers, the ones reading_test.ts replays, so a fixture PDF uploaded from the app is read end to
// end without the Claude API, as the end-to-end flows (DentoryE2ETests) receive one. The request is the one the API
// would get; only its answer comes from the recording, chosen by the pages it carries. Any other pages fail as every
// reading did without a key. A hosted project never replays: its SUPABASE_URL is not the local stack's gateway
// (isLocalStack in _shared/environment.ts, which the email fallback asks too), and modelCallFor, which index.ts asks,
// decides it from the function's own environment alone.
import harbourview from "./fixtures/harbourview-hv-2207.json" with { type: "json" };
import lakeshore from "./fixtures/lakeshore-ls-58113.json" with { type: "json" };
import northbridge from "./fixtures/northbridge-inv-10092.json" with { type: "json" };
import prairie from "./fixtures/prairie-pdw-90412.json" with { type: "json" };
import riveSud from "./fixtures/rive-sud-f-3381.json" with { type: "json" };
import { isLocalStack } from "../_shared/environment.ts";
import { type ModelCall, ReadingFailure, type ReadingRequest } from "./reading.ts";

/** Each fixture invoice's recorded answer, under the SHA-256 of its page files in order (`shasum -a 256`). The app
 * uploads a PDF as it is and turns every image into a new JPEG, so only the PDFs are read this way from the app. */
export const recordings: Record<string, unknown> = {
  "edcdc61d216ef5dc504037502a7b5a243fcbd5d6327b8ffb04ded1ba84d532fb": northbridge,
  "7aa6c35c0e68a57f6a291a8e5a91e87d801377e150726768dd1d70435d4bcd57": lakeshore,
  "169a90e7ab95ba7c5adfbcb3efdb2b89ec310f05c43ff0139d03694e398336b5": harbourview,
  "293e0b3aaa70f5afbcca6d00b108506915fdb9c701cedba5e5452a3077ea42ab,6a5e4a2d9b8e068f1137c25160c6cd4f64f9806821cf2b4bd07dcc348c1b10de":
    prairie,
  "5913e72cd2645b7e59092d91727a6e48e923254815727bacf6c5d98c67ab7225": riveSud,
};

/** Who reads an invoice, from the function's environment: the Claude API whenever a key is set; without one, the
 * recordings, on the local stack only; anywhere else nobody, and the reading fails with the reason error, as it did
 * before MS-136. `claude` makes the API's call for a key (claude.ts's claudeCall). */
export function modelCallFor(
  apiKey: string | undefined,
  supabaseURL: string | undefined,
  claude: (apiKey: string) => ModelCall,
): ModelCall {
  if (apiKey) return claude(apiKey);
  if (isLocalStack(supabaseURL ?? "")) return replayCall;
  throw new ReadingFailure("error", "ANTHROPIC_API_KEY is not set");
}

export const replayCall: ModelCall = async (request) => {
  const pages = await Promise.all(pagesOf(request).map(sha256));
  const answer = recordings[pages.join(",")];
  if (!answer) throw new ReadingFailure("error", "ANTHROPIC_API_KEY is not set and the pages are no fixture invoice");
  return { stopReason: "end_turn", text: JSON.stringify(answer) };
};

/** The pages, base64 encoded, in the order the request carries them. */
function pagesOf(request: ReadingRequest): string[] {
  const content = request.messages[0]?.content;
  return (Array.isArray(content) ? content : []).flatMap((block) =>
    (block.type === "document" || block.type === "image") && block.source.type === "base64" ? [block.source.data] : []
  );
}

/** The SHA-256 of a page's file, as `shasum -a 256` prints it. */
async function sha256(base64: string): Promise<string> {
  const data = Uint8Array.from(atob(base64), (character) => character.charCodeAt(0));
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", data));
  return [...digest].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
