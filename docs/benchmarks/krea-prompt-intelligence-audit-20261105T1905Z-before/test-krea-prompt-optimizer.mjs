import assert from "node:assert/strict";
import {extractOpenRouterText,normalizeOptimizedPrompt,optimizeWithOpenRouter,KREA_PROMPT_SYSTEM} from "../apps/server/krea-prompt-optimizer.mjs";

assert.equal(normalizeOptimizedPrompt("  Optimized prompt: A cinematic portrait  "), "A cinematic portrait");
assert.equal(normalizeOptimizedPrompt("```text\nA detailed scene\n```"), "A detailed scene");
assert.equal(extractOpenRouterText({choices:[{message:{content:"A prompt"}}]}), "A prompt");
assert.equal(extractOpenRouterText({choices:[{message:{content:[{type:"text",text:"A"},{type:"text",text:"B"}]}}]}), "A\nB");
assert.throws(()=>normalizeOptimizedPrompt(""), /geen verbeterde prompt/);
assert.throws(()=>normalizeOptimizedPrompt("x".repeat(6001)), /te lang/);
assert.throws(()=>extractOpenRouterText({choices:[]}), /geen tekstuele/);
assert.match(KREA_PROMPT_SYSTEM,/Preserve the exact subject/);
assert.match(KREA_PROMPT_SYSTEM,/Do not invent extra subjects/);

let request;
const ok = await optimizeWithOpenRouter("A cat on a chair", "test-secret", {
  fetchImpl: async (url, init) => {
    request={url,init};
    return {ok:true,status:200,json:async()=>({model:"provider/test-free",choices:[{message:{content:"A realistic cat sitting on a wooden chair, soft window light."}}],usage:{prompt_tokens:12,completion_tokens:18}})};
  }
});
assert.equal(request.url,"https://openrouter.ai/api/v1/chat/completions");
assert.equal(request.init.method,"POST");
assert.equal(request.init.headers.Authorization,"Bearer test-secret");
const body=JSON.parse(request.init.body);
assert.equal(body.model,"openrouter/free");
assert.equal(body.stream,false);
assert.equal(body.messages[1].content.includes("A cat on a chair"),true);
assert.equal(ok.model,"provider/test-free");
assert.equal(ok.usage.completionTokens,18);
assert.match(ok.prompt,/wooden chair/);


let presetRequest;
const presetResult = await optimizeWithOpenRouter("A red bicycle at sunset", "test-secret", {
  model: "@preset/krea-prompt-optimizer",
  fetchImpl: async (url, init) => {
    presetRequest={url,init};
    return {ok:true,status:200,json:async()=>({model:"provider/preset-selected-model",choices:[{message:{content:"A red bicycle at sunset, warm cinematic light."}}]})};
  }
});
const presetBody=JSON.parse(presetRequest.init.body);
assert.equal(presetBody.model,"@preset/krea-prompt-optimizer");
assert.equal(presetBody.messages.length,1);
assert.equal(presetBody.messages[0].role,"user");
assert.equal(presetBody.messages[0].content,"A red bicycle at sunset");
assert.equal(Object.hasOwn(presetBody,"temperature"),false);
assert.equal(Object.hasOwn(presetBody,"max_tokens"),false);
assert.equal(presetResult.model,"provider/preset-selected-model");

await assert.rejects(()=>optimizeWithOpenRouter("x","",{}),/API-key ontbreekt/);
await assert.rejects(()=>optimizeWithOpenRouter("x","test-secret",{fetchImpl:async()=>({ok:false,status:429,json:async()=>({error:{message:"rate limited"}})})}),/OpenRouter niet beschikbaar/);
await assert.rejects(()=>optimizeWithOpenRouter("x","test-secret",{fetchImpl:async()=>({ok:true,status:200,json:async()=>({choices:[]})})}),/geen tekstuele/);

console.log("Krea prompt optimizer: 21 assertions passed");