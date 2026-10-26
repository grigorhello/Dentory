// The live `ModelCall` (MS-129): one request through the Anthropic SDK with the project's ANTHROPIC_API_KEY, which only
// `supabase secrets set` puts on a hosted project. The tests replay recorded answers instead (reading_test.ts), and the
// opt-in live check uses this one (live_check.ts).
import Anthropic from "npm:@anthropic-ai/sdk@1.3.0";
import type { ModelAnswer, ModelCall } from "./reading.ts";

/** One retry for a dropped connection or an overloaded API, still within the reading's 60 seconds. */
export function claudeCall(apiKey: string): ModelCall {
  const client = new Anthropic({ apiKey, maxRetries: 1, timeout: 60_000 });
  return async (request, signal): Promise<ModelAnswer> => {
    const message = await client.beta.messages.create(request, { signal });
    return {
      stopReason: message.stop_reason,
      text: message.content.flatMap((block) => block.type === "text" ? [block.text] : []).join(""),
      inputTokens: message.usage.input_tokens,
      outputTokens: message.usage.output_tokens,
    };
  };
}
