import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import {
  getKreaPromptFlow, createKreaPromptReview, restoreKreaPromptReview,
  chooseKreaPrompt, chooseOriginalKreaPrompt
} from "../apps/web/krea-prompt-flow.mjs";

let assertions=0;
function ok(value,message){assert.ok(value,message);assertions++;}
function equal(actual,expected,message){assert.equal(actual,expected,message);assertions++;}
const original="A red bicycle at sunset";
const optimized={prompt:"A red bicycle at sunset, warm directional light.",provider:"openrouter",model:"router/model",fallback:false,warning:null};

equal(getKreaPromptFlow("automatic",true).kind,"optimize-and-generate");
equal(getKreaPromptFlow("approve",true).kind,"optimize-and-review");
equal(getKreaPromptFlow("manual",true).kind,"optimize-and-review");
equal(getKreaPromptFlow("automatic",false).kind,"generate-original");
equal(getKreaPromptFlow("approve",false).kind,"review-original");
equal(getKreaPromptFlow("manual",false).kind,"review-original");
equal(getKreaPromptFlow("manual",true,true).kind,"generate-original");
equal(getKreaPromptFlow("bad-mode",true).mode,"automatic");

let review=createKreaPromptReview(original,optimized,"approve");
equal(review.originalPrompt,original);
equal(review.prompt,optimized.prompt);
equal(review.meta.provider,"openrouter");
equal(review.mode,"approve");
equal(review.edited,false);
const approved=chooseKreaPrompt(review);
equal(approved.prompt,optimized.prompt);
equal(approved.originalPrompt,original);
equal(approved.provider,"openrouter");
equal(approved.promptSource,"optimized");
equal(approved.edited,false);

review=createKreaPromptReview(original,optimized,"manual");
const edited=chooseKreaPrompt(review,"A red bicycle at sunset, golden hour and shallow depth of field.");
equal(edited.edited,true);
equal(edited.provider,"openrouter");
equal(edited.promptSource,"optimized");
const same=chooseKreaPrompt(review,optimized.prompt);
equal(same.edited,false);
const restored=restoreKreaPromptReview(review);
equal(restored.prompt,original);
equal(restored.meta.provider,"original");
equal(restored.restoredOriginal,true);
equal(chooseKreaPrompt(restored).prompt,original);
equal(chooseKreaPrompt(restored).provider,"original");
equal(chooseKreaPrompt(restored).promptSource,"original");
equal(chooseOriginalKreaPrompt(original,"automatic").prompt,original);
equal(chooseOriginalKreaPrompt(original,"manual").mode,"manual");
assert.throws(()=>chooseKreaPrompt(review,""),/1 tot 6000/);assertions++;
assert.throws(()=>chooseKreaPrompt(review,"x".repeat(6001)),/1 tot 6000/);assertions++;
assert.throws(()=>chooseKreaPrompt(null),/geen prompt/);assertions++;
assert.throws(()=>chooseOriginalKreaPrompt(""),/1 tot 6000/);assertions++;
assert.throws(()=>chooseOriginalKreaPrompt("x".repeat(6001)),/1 tot 6000/);assertions++;
const badMetadata=createKreaPromptReview(original,{prompt:"",provider:"untrusted",model:"m".repeat(200),fallback:true,warning:"w".repeat(400)},"manual");
equal(badMetadata.prompt,original);
equal(badMetadata.meta.provider,"original");
equal(badMetadata.meta.model.length,160);
equal(badMetadata.meta.warning.length,360);

const app=await readFile(new URL("../apps/web/app.js",import.meta.url),"utf8");
const html=await readFile(new URL("../apps/web/index.html",import.meta.url),"utf8");
const server=await readFile(new URL("../apps/server/server.mjs",import.meta.url),"utf8");
ok(app.includes('getKreaPromptFlow(mode,enabled)'));
ok(app.includes("showKreaPromptReview(originalPrompt,optimized,flow.mode,true)"));
ok(app.includes("keepPromptVisible"));
ok(app.includes("Deze verbeterde prompt wordt automatisch gebruikt."));
ok(app.includes("restoreKreaPromptReview(krea2PromptReview)"));
ok(app.includes("chooseKreaPrompt(krea2PromptReview"));
ok(app.includes('"krea2-prompt-skip-once").addEventListener("click"'));
ok(app.includes('"krea2-prompt-use-original").addEventListener("click"'));
ok(app.includes('"krea2-prompt-review-accept").addEventListener("click"'));
ok(html.includes('<script type="module" src="/app.js"></script>'));
for(const id of ["krea2-prompt-optimize","krea2-prompt-mode","krea2-prompt-skip-once","krea2-prompt-original-preview","krea2-prompt-review-text","krea2-prompt-restore","krea2-prompt-use-original","krea2-prompt-review-accept","krea2-prompt-attribution"])ok(html.includes('id="'+id+'"'),"missing UI control "+id);
ok(!html.includes('id="krea2-prompt-provider"'),"Krea prompt flow must remain local-only");
ok(server.includes('".mjs":"text/javascript; charset=utf-8"'));
console.log(`Krea prompt flow: ${assertions} assertions passed`);
