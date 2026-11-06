import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import {
  extractOpenRouterText, normalizeOptimizedPrompt, optimizeWithOpenRouter,
  getOpenRouterPresetConfiguration, runPromptOptimization, KREA_PROMPT_SYSTEM,
  OpenRouterError, listFreeOpenRouterModels, checkOpenRouterKey
} from "../apps/server/krea-prompt-optimizer.mjs";
import {publicSettings} from "../apps/server/settings-secrets.mjs";

let assertions=0;
function ok(value,message){assert.ok(value,message);assertions++;}
function equal(a,b,message){assert.equal(a,b,message);assertions++;}
function rejects(fn,pattern){assert.rejects(fn,pattern);assertions++;}
const response=(status,data)=>({ok:status>=200&&status<300,status,json:async()=>data});
const input="A red bicycle at sunset";

// Output normalization and malformed model responses.
equal(normalizeOptimizedPrompt("  Optimized prompt: A cinematic portrait  "),"A cinematic portrait");
equal(normalizeOptimizedPrompt("```text\nA detailed scene\n```"),"A detailed scene");
equal(extractOpenRouterText({choices:[{message:{content:"A prompt"}}]}),"A prompt");
equal(extractOpenRouterText({choices:[{message:{content:[{type:"text",text:"A"},{type:"text",text:"B"}]}}]}),"A\nB");
assert.throws(()=>normalizeOptimizedPrompt(""),/geen verbeterde prompt/);assertions++;
assert.throws(()=>normalizeOptimizedPrompt("x".repeat(6001)),/te lang/);assertions++;
assert.throws(()=>extractOpenRouterText({choices:[]}),/geen tekstuele/);assertions++;
assert.throws(()=>normalizeOptimizedPrompt({text:"no"}),/geen verbeterde prompt/);assertions++;
ok(/Preserve the exact subject/.test(KREA_PROMPT_SYSTEM));
ok(/Do not invent extra subjects/.test(KREA_PROMPT_SYSTEM));
ok(/Do not apply blanket content censorship/.test(KREA_PROMPT_SYSTEM));
ok(/Preserve mature, erotic and explicit fictional details/.test(KREA_PROMPT_SYSTEM));
ok(/sexual content involving minors or ambiguous-age people/.test(KREA_PROMPT_SYSTEM));

// Valid default Free Models Router request, hard privacy controls, bounded output.
let request;
const result=await optimizeWithOpenRouter(input,"test-secret",{
  timeoutMs:5000,
  fetchImpl:async(url,init)=>{request={url,init};return response(200,{model:"provider/test-free",provider:"provider-a",choices:[{message:{content:"A red bicycle at sunset, warm directional light."}}],usage:{prompt_tokens:12,completion_tokens:18}});}
});
equal(request.url,"https://openrouter.ai/api/v1/chat/completions");equal(request.init.method,"POST");equal(request.init.headers.Authorization,"Bearer test-secret");equal(request.init.headers["X-OpenRouter-Title"],"PS5 AI Studio · Krea 2");
const body=JSON.parse(request.init.body);equal(body.model,"openrouter/free");equal(body.stream,false);equal(body.max_tokens,1200);equal(body.temperature,.35);equal(body.provider.zdr,undefined);equal(body.provider.data_collection,"deny");equal(body.messages[1].content.includes(input),true);equal(result.model,"provider/test-free");equal(result.provider,"provider-a");equal(result.usage.completionTokens,18);ok(result.prompt.includes("directional light"));


// Key check reports quota metadata only and never returns a credential.
let keyCheckUrl;const keyCheck=await checkOpenRouterKey("test-secret",{fetchImpl:async(url,init)=>{keyCheckUrl=url;return response(200,{data:{limit:50,usage:2,limit_remaining:48,key:"must-not-return"}});}});equal(keyCheckUrl,"https://openrouter.ai/api/v1/key");equal(keyCheck.valid,true);equal(keyCheck.remaining,48);equal(keyCheck.freeTier,null);equal(keyCheck.key,undefined);

// Catalog accepts only $0 text-input/text-output models with free IDs.
let catalogUrl;
const catalog=await listFreeOpenRouterModels("test-secret",{fetchImpl:async(url,init)=>{catalogUrl=url;return response(200,{data:[
 {id:"provider/good:free",name:"Good",context_length:32000,architecture:{input_modalities:["text"],output_modalities:["text"]},supported_parameters:["max_tokens"],pricing:{prompt:"0",completion:"0"}},
 {id:"provider/paid:free",name:"Paid",architecture:{input_modalities:["text"],output_modalities:["text"]},supported_parameters:["max_tokens"],pricing:{prompt:"0.1",completion:"0.2"}},
 {id:"provider/no-text:free",name:"No text",architecture:{input_modalities:["image"],output_modalities:["text"]},supported_parameters:["max_tokens"],pricing:{prompt:"0",completion:"0"}},
 {id:"provider/no-chat:free",name:"No chat",architecture:{input_modalities:["text"],output_modalities:["audio"]},supported_parameters:["max_tokens"],pricing:{prompt:"0",completion:"0"}},
 {id:"provider/good:free",name:"Good duplicate",context_length:32000,architecture:{input_modalities:["text"],output_modalities:["text"]},supported_parameters:["max_tokens"],pricing:{prompt:"0",completion:"0"}}
]});}});
ok(catalogUrl.endsWith("/models"));equal(catalog.length,1);equal(catalog[0].id,"provider/good:free");equal(catalog[0].context,32000);

// Preset lookup retains its model/provider settings, then enforces privacy and token bound.
let presetRequest;
const preset=await getOpenRouterPresetConfiguration("krea-prompt", "test-secret", {
  fetchImpl:async(url,init)=>{presetRequest={url,init};return response(200,{data:{slug:"krea-prompt",designated_version:{system_prompt:"Keep the requested image style.",config:{provider:{order:["preferred-host"],data_collection:"allow",zdr:true},temperature:.8}}}});}
});
equal(presetRequest.url,"https://openrouter.ai/api/v1/presets/krea-prompt");equal(preset.provider.order[0],"preferred-host");equal(preset.systemPrompt,"Keep the requested image style.");
let presetBody;
await optimizeWithOpenRouter(input,"test-secret",{
  model:"@preset/krea-prompt",providerPreferences:preset.provider,systemPrompt:KREA_PROMPT_SYSTEM+"\n\n"+preset.systemPrompt,
  fetchImpl:async(url,init)=>{presetBody=JSON.parse(init.body);return response(200,{model:"provider/preset-model",choices:[{message:{content:"A red bicycle at sunset."}}]});}
});
equal(presetBody.model,"@preset/krea-prompt");equal(presetBody.messages[0].content.includes("Keep the requested image style."),true);equal(presetBody.provider.order[0],"preferred-host");equal(presetBody.provider.zdr,undefined);equal(presetBody.provider.data_collection,"deny");equal(presetBody.temperature,undefined);equal(presetBody.max_tokens,1200);
await rejects(()=>getOpenRouterPresetConfiguration("bad slug","test-secret",{}),/preset-slug/);
await rejects(()=>getOpenRouterPresetConfiguration("unsafe","test-secret",{fetchImpl:async()=>response(200,{data:{designated_version:{config:{tools:[{type:"function"}]}}}})}),/tools\/plugins/);

// 401, 429 and 500 handling; retry only transient 5xx, with one short backoff.
let count=0;await assert.rejects(()=>optimizeWithOpenRouter(input,"test-secret",{fetchImpl:async()=>{count++;return response(401,{error:{message:"test-secret and prompt must not leak"}});}}),e=>e instanceof OpenRouterError&&e.status===401);assertions++;equal(count,1);
count=0;await assert.rejects(()=>optimizeWithOpenRouter(input,"test-secret",{fetchImpl:async()=>{count++;return response(429,{error:{message:"Provider returned error",metadata:{provider_name:"Phala"}}});}}),e=>e instanceof OpenRouterError&&e.status===429&&e.code==="provider_rate_limited"&&e.provider==="Phala");assertions++;equal(count,1);
count=0;let backoffs=[];await assert.rejects(()=>optimizeWithOpenRouter(input,"test-secret",{fetchImpl:async()=>{count++;return response(500,{error:{message:"internal"}});},sleepImpl:async ms=>backoffs.push(ms)}),e=>e.status===500&&e.retryable);assertions++;equal(count,2);equal(backoffs[0],150);
count=0;const recovered=await optimizeWithOpenRouter(input,"test-secret",{fetchImpl:async()=>{count++;return count===1?response(503,{error:{message:"busy"}}):response(200,{choices:[{message:{content:"A red bicycle at dusk."}}]});},sleepImpl:async()=>{}});equal(count,2);ok(recovered.prompt.includes("bicycle"));

// Timeouts, invalid JSON, empty and unusable answers do not get retried or accepted.
count=0;await assert.rejects(()=>optimizeWithOpenRouter(input,"test-secret",{fetchImpl:async()=>{count++;const e=Error("timeout");e.name="TimeoutError";throw e;}}),e=>e.code==="timeout");assertions++;equal(count,1);
await assert.rejects(()=>optimizeWithOpenRouter(input,"test-secret",{fetchImpl:async()=>({ok:true,status:200,json:async()=>{throw Error("bad json")}})}),/ongeldige JSON/);assertions++;
await assert.rejects(()=>optimizeWithOpenRouter(input,"test-secret",{fetchImpl:async()=>response(200,{choices:[{message:{content:""}}]})}),/geen verbeterde prompt/);assertions++;
await assert.rejects(()=>optimizeWithOpenRouter(input,"test-secret",{fetchImpl:async()=>response(200,{choices:[{message:{content:{unexpected:true}}}]})}),/geen tekstuele/);assertions++;
await assert.rejects(()=>optimizeWithOpenRouter(input,"test-secret",{fetchImpl:async()=>response(200,{choices:[{message:{content:"x".repeat(6001)}}]})}),/te lang/);assertions++;
await assert.rejects(()=>optimizeWithOpenRouter("", "test-secret",{}),/prompt in/);assertions++;
await assert.rejects(()=>optimizeWithOpenRouter(input,"",{}),/API-key ontbreekt/);assertions++;

// OpenRouter -> Qwen -> original fallback order and immutable original input.
let qwenCalls=0;const openFailure=await runPromptOptimization(input,"openrouter",{openRouter:async()=>{throw new OpenRouterError("OpenRouter gaf HTTP 429.",{status:429,code:"rate_limited"});},localQwen:async()=>{qwenCalls++;return{prompt:"A red bicycle at dusk",model:"local-qwen"};}});
equal(openFailure.provider,"qwen");equal(openFailure.fallback,true);equal(qwenCalls,1);equal(input,"A red bicycle at sunset");ok(openFailure.warning.includes("429"));ok(openFailure.warning.includes("Qwen3-promptservice is gebruikt"));
const authFallback=await runPromptOptimization(input,"openrouter",{openRouter:async()=>{throw new OpenRouterError("OpenRouter gaf HTTP 401.",{status:401,code:"unauthorized"});},localQwen:async()=>({prompt:"Local prompt",model:"Qwen local"})});equal(authFallback.provider,"qwen");ok(authFallback.warning.includes("Controleer de key in Instellingen"));
const qwenFailure=await runPromptOptimization(input,"openrouter",{openRouter:async()=>{throw Error("privacy route unavailable");},localQwen:async()=>{throw Error("RAM guard");}});equal(qwenFailure.prompt,input);equal(qwenFailure.provider,"original");equal(qwenFailure.fallback,true);ok(qwenFailure.warning.includes("oorspronkelijke prompt"));ok(qwenFailure.warning.includes("privacy route unavailable"));
const explicitQwen=await runPromptOptimization(input,"qwen",{openRouter:async()=>{throw Error("must not be called");},localQwen:async()=>({prompt:"Local prompt",model:"Qwen local"})});equal(explicitQwen.provider,"qwen");equal(explicitQwen.fallback,false);
const explicitQwenFail=await runPromptOptimization(input,"qwen",{localQwen:async()=>{throw Error("RAM reserve");}});equal(explicitQwenFail.prompt,input);equal(explicitQwenFail.provider,"original");

// Settings responses never contain either API key, whether configured in a file or environment.
const publicConfig=publicSettings({openrouterApiKey:"secret-openrouter",civitaiApiKey:"secret-civitai",kreaPromptMode:"manual"},{OPENROUTER_API_KEY:"",CIVITAI_API_KEY:""});
equal(publicConfig.openrouterApiKeyConfigured,true);equal(publicConfig.civitaiApiKeyConfigured,true);equal(publicConfig.openrouterApiKey,undefined);equal(publicConfig.civitaiApiKey,undefined);equal(publicConfig.kreaPromptMode,"manual");
const environmentConfig=publicSettings({}, {OPENROUTER_API_KEY:"env-secret",CIVITAI_API_KEY:""});equal(environmentConfig.openrouterApiKeyConfigured,true);equal(environmentConfig.openrouterApiKey,undefined);

// Security and generation integration guardrails are checked without starting a GPU job.
const server=await readFile(new URL("../apps/server/server.mjs",import.meta.url),"utf8");
const web=await readFile(new URL("../apps/web/app.js",import.meta.url),"utf8");
const optimizer=await readFile(new URL("../apps/server/krea-prompt-optimizer.mjs",import.meta.url),"utf8");
const html=await readFile(new URL("../apps/web/index.html",import.meta.url),"utf8");
ok(server.includes('nodes["4"]={class_type:"CLIPTextEncode",inputs:{text:prompt,clip:["2",0]}}'));
ok(server.includes('COMFY_BASE+"/prompt"'));
ok(optimizer.includes('provider.data_collection = "deny"'));
ok(optimizer.includes("delete provider.zdr"));
ok(server.includes('".mjs":"text/javascript; charset=utf-8"'));
ok(html.includes('<script type="module" src="/app.js"></script>'));
ok(html.includes('id="setting-openrouter-model"'));ok(html.includes('id="setting-openrouter-test"'));ok(web.includes("/api/krea2/openrouter-check"));
ok(html.includes('id="setting-openrouter-models-refresh"'));ok(html.includes('id="setting-openrouter-model-status"'));
ok(web.includes("/api/krea2/openrouter-models"));
ok(server.includes("Kies alleen een gratis OpenRouter-model met :free suffix"));ok(server.includes('v!=="openrouter/free"'));ok(server.includes("listFreeOpenRouterModels(key"));
ok(server.includes("atomicWriteFileNoFollow(SETTINGS_FILE"));
ok(!/log\([^\n]*(?:openrouterApiKey|\+\s*prompt\b|JSON\.stringify\([^)]*prompt)/i.test(server), "prompt contents and API keys must never be written to logs");
ok(!web.includes("OPENROUTER_API_KEY"));
ok(web.includes("promptMode:mode"));

console.log(`Krea prompt optimizer: ${assertions} assertions passed`);
