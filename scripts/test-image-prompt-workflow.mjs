import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
const [html,app,server]=await Promise.all([
  readFile(new URL("../apps/web/index.html",import.meta.url),"utf8"),
  readFile(new URL("../apps/web/app.js",import.meta.url),"utf8"),
  readFile(new URL("../apps/server/server.mjs",import.meta.url),"utf8")
]);
let assertions=0;
const ok=(condition,message)=>{assert.ok(condition,message);assertions++;};
for(const [value,label] of [["automatic","Automatisch verbeteren en genereren"],["approve","Eerst bekijken en goedkeuren"],["manual","Handmatig aanpassen"]]){
  ok(html.includes(`<option value="${value}">${label}</option>`),`missing mode ${value}`);
}
for(const id of ["image-prompt-mode","image-prompt-status","image-prompt-review","image-prompt-original-preview","image-prompt-review-text","image-prompt-review-cancel","image-prompt-review-generate"]){
  ok(html.includes(`id="${id}"`),`missing Image Studio control ${id}`);
}
const imagePromptSection=html.slice(html.indexOf('id="image-prompt-mode"'),html.indexOf('id="image-negative"'));
ok(imagePromptSection.includes("Lokaal Huihui Qwen3-4B Abliterated-model"));
ok(!/OpenRouter|provider/i.test(imagePromptSection),"Image Studio prompt controls must not expose a provider choice");
ok(app.includes('post("/api/image/prompt-optimize",promptContext)'));
ok(html.includes('id="image-prompt-optimize"'));
const editorFieldset=html.match(/<fieldset id="image-editor-fields"[^>]*>/)?.[0]||"";
ok(!/\bdisabled\b/.test(editorFieldset),"Image Studio editor must remain usable without a loaded image model");
ok(app.includes("if(fields)fields.disabled=false"),"image runtime state must not disable prompt input");
ok(app.includes("generate.disabled=!ready"),"generation must remain gated on a ready image model");
ok(app.includes('$("image-prompt-optimize").addEventListener("click"'));
ok(app.includes('Huihui Qwen3-4B Abliterated wordt alleen gestart wanneer je op Prompt verbeteren drukt.'));
ok(app.includes('const generationPrompt=(imageGenerationPromptOverride??$("image-prompt").value).trim()'));
ok(app.includes("imageGenerationPromptOverride=null"));
ok(!app.slice(app.indexOf('$("generate-image").addEventListener("click"'),app.indexOf('$("image-cancel").addEventListener("click"')).includes('/api/image/prompt-optimize'),"generation must not start Qwen automatically");
ok(app.includes('imagePromptModeKey="ps5-ai-studio-image-prompt-mode"'));
ok(html.includes('id="image-prompt-fallback"'));
ok(app.includes('$("image-prompt-review-text").readOnly=mode!=="manual"'));

ok(app.includes('const b={prompt:generationPrompt,negative_prompt:$("image-negative").value'));
ok(server.includes('if(req.method==="POST"&&p==="/api/image/prompt-optimize")'));
ok(server.includes('optimizeWithLocalQwen(prompt,{signal:controller.signal,systemPrompt,reviewSystemPrompt,maxTokens:192,threads:4,contextSize:3072,timeoutMs:180000})'));
ok(server.includes("buildImagePromptProfile({modelName:selectedModel.name,backend,loras:selectedLoras,krea2Lora:kreaLoraName"));
ok(server.includes("const sameAsActive=selectedModel.path===runtimes.image.model"));
ok(app.includes("const promptContext={prompt:originalPrompt,model:selectedModel,backend:activeImageRuntime?.backend||\"\""));
ok(app.includes("optimized.profile?.family||\"algemeen\""));
ok(server.includes('const IMAGE_PROMPT_SYSTEM ='));
ok(server.includes('async function prepareGpuForQwen()'));
ok(server.includes('unload_models:true,free_memory:true'));
ok(server.includes('minimumFree=6.0*1024**3'));
ok(server.includes('await prepareGpuForQwen();'));
ok(server.includes("await stop(runtimes.text);\n   await stop(runtimes.image);"),"unload active GPU models before Qwen");
ok(server.includes("restore=await loadImage(restoreSpec)"),"restore selected image model after Qwen exits");
ok(server.includes("restored:true,restoredModel:selectedModel.path"),"confirm restored checkpoint to UI");
ok(server.includes("imagePromptSessionBusy=true")&&server.includes("imagePromptSessionBusy=false"),"serialize the complete model handoff");
ok(server.includes("if(imagePromptSessionBusy)return send(res,409"),"block conflicting GPU operations during the swap");
ok(server.includes("if(comfyQueueHasWork(await queueResponse.json()))return send(res,409"),"do not unload existing models while ComfyUI is busy");
ok(server.includes("/api/krea2/generate")&&server.includes("/api/video/generate"),"guard Krea and video generation routes during the swap");
ok(server.includes("rt.backend=null;rt.vae=null"),"clear stale image backend after unload");
ok(app.includes("autoGenerateAfterPrompt=true"),"automatic mode generates after restoring the image runtime");
ok(app.includes("setImagePromptControlsLocked(true)")&&app.includes("setImagePromptControlsLocked(false)"),"freeze and restore model/settings controls during the Qwen handoff");
ok(app.includes("setImagePromptControlsLocked(false);updateKrea2EditorMode(activeImageRuntime)"),"reapply checkpoint-specific editor constraints after unlocking controls");
ok(app.includes("generate.disabled=!ready||imagePromptPreparing"),"do not expose generation while the prompt handoff is still running");
ok(app.includes('if(autoGenerateAfterPrompt){autoGenerateAfterPrompt=false;$("generate-image").click();}'),"trigger automatic generation only after prompt preparation completes");
ok(server.includes('Keep the selected ComfyUI model/runtime metadata intact.'));
ok(!server.includes('runtimes.image.model=null;runtimes.image.vae=null;runtimes.image.backend=null;runtimes.image.controlnet=null;runtimes.image.ipadapter=null;runtimes.image.clipvision=null;runtimes.image.jobId=null;runtimes.image.jobStatus=null;runtimes.image.state="stopped";'));
ok(server.includes('await waitForQwenGpuRelease();'));
ok(server.includes('Qwen gebruikt momenteel de GPU'));
console.log(`Image Studio prompt workflow: ${assertions} assertions passed`);