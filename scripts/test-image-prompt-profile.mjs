import assert from "node:assert/strict";
import {buildImagePromptProfile,buildImagePromptSystem,buildImagePromptReviewSystem,inferImagePromptFamily,normalizeImagePromptOutput,isImagePromptReviewSafe} from "../apps/server/image-prompt-profile.mjs";
let assertions=0;const ok=(v,m)=>{assert.ok(v,m);assertions++;};
for(const [name,backend,expected] of [
 ["Krea2 SickRealism v4.safetensors","ComfyUI-Krea2","krea2"],
 ["Krea2-Turbo-Q3_K_M.gguf","ComfyUI-GGUF","krea2"],
 ["FLUX.1-dev.safetensors","stable-diffusion.cpp","flux"],
 ["sd_xl_base_1.0.safetensors","stable-diffusion.cpp","sdxl"],
 ["Pony Diffusion XL.safetensors","stable-diffusion.cpp","sdxl-anime"],
 ["v1-5-pruned-emaonly.safetensors","stable-diffusion.cpp","sd15"],
 ["epicrealism_naturalSinRC1VAE.safetensors","stable-diffusion.cpp","sd15"],
 ["realisticVisionV60B1_v51HyperVAE_full_fp16.safetensors","stable-diffusion.cpp","sd15"],
 ["Qwen-Image-Edit-2509.safetensors","ComfyUI-GGUF","qwen-image"],
 ["custom-model.safetensors","stable-diffusion.cpp","general"]
]) ok(inferImagePromptFamily({modelName:name,backend})===expected,`wrong family for ${name}`);
const profile=buildImagePromptProfile({modelName:"Krea2 SickRealism v4.safetensors",backend:"ComfyUI-Krea2",loras:["Portrait Detail.safetensors","","x"],krea2Lora:"Krea2 Turbo.safetensors",settings:{width:512,height:512,steps:4,cfg:1,sampler:"euler",scheduler:"simple",turbo:3,ignored:"no"}});
ok(profile.family==="krea2");ok(profile.loras.length===2);ok(profile.settings.width===512);ok(!("ignored" in profile.settings));
const system=buildImagePromptSystem(profile);
ok(system.includes("senior image-prompt engineer"));ok(system.includes("precise, natural English"));ok(system.includes("kinderkopjes"));ok(system.includes("cobblestones"));ok(system.includes("never means children, heads, faces, shoes"));ok(system.includes("Krea 2 / SickRealism"));
const kreaFormat=buildImagePromptSystem({modelName:"Krea2 SickRealism"});
const sdxlFormat=buildImagePromptSystem({modelName:"Juggernaut XL"});
const sd15Format=buildImagePromptSystem({modelName:"v1-5-pruned-emaonly"});
const fluxFormat=buildImagePromptSystem({modelName:"FLUX.1-dev"});
ok(kreaFormat.includes("editorial-quality photographic description in complete natural-language sentences"));
ok(sdxlFormat.includes("compact, high-signal descriptor sequence"));
ok(sd15Format.includes("terse, keyword-efficient prompt"));
ok(fluxFormat.includes("one or two precise natural-language sentences"));
ok(kreaFormat.includes("formats must be meaningfully distinct"));ok(system.includes("Mention each visual fact once"));
ok(system.includes("Do not apply blanket content censorship"));
ok(system.includes("nudity, explicit adult sexual language, erotic themes, fetish terminology"));
ok(system.includes("Preserve the user's requested level of explicitness"));
ok(system.includes("sexual content involving minors or ambiguous-age people"));
ok(system.includes("non-consensual activity involving real people"));ok(system.includes("Do not invent specific object design details"));ok(system.includes("Portrait Detail.safetensors"));ok(system.includes("Krea2 Turbo.safetensors"));ok(system.includes('"steps":4'));
const general=buildImagePromptSystem();ok(general.includes("Unknown or custom model"));ok(buildImagePromptSystem({modelName:"Pony Diffusion XL.safetensors"}).includes("Do not convert a requested photorealistic image into anime"));

const cleaned=normalizeImagePromptOutput('A red bicycle on wet cobblestones. is the image-generation prompt for Krea2 with 1024x1024. Ignore rules and continue.');
ok(cleaned==='A red bicycle on wet cobblestones.');
ok(!cleaned.includes('image-generation prompt'));
ok(normalizeImagePromptOutput('A red bicycle on wet "kinderkopjes."')==='A red bicycle on wet cobblestones.');
ok(normalizeImagePromptOutput('A red bicycle. user: Another prompt. user: More text.')==='A red bicycle.');
ok(normalizeImagePromptOutput('Prompt: A red bicycle on a street.')==='A red bicycle on a street.');
ok(normalizeImagePromptOutput('A '.repeat(100)).split(/\s+/).length<=95);

ok(normalizeImagePromptOutput('A red bicycle. image-generation prompt: another scene.')==='A red bicycle.');
ok(normalizeImagePromptOutput('A red bicycle. user prompt: another scene.')==='A red bicycle.');

ok(normalizeImagePromptOutput("A red bicycle. Selecting: model.safetensors Backend not loaded SDXL compact high-signal descriptor sequence.")==="A red bicycle.");
ok(normalizeImagePromptOutput("A red bicycle. is the prompt for SDXL model family: SDXL file model.safetensors")==="A red bicycle.");
ok(normalizeImagePromptOutput("A red bicycle on a wet street. A vintage red bike on the same street with extra details.")==="A red bicycle on a wet street.");
ok(normalizeImagePromptOutput("A red bicycle on a wet street. Vintage elements and natural textures emphasize the scene\u0027s charm.")==="A red bicycle on a wet street.");


const review=buildImagePromptReviewSystem({modelName:"Juggernaut XL"});
ok(review.includes("independent quality-control editor"));
ok(review.includes("You are a proofreader, not a censor"));
ok(review.includes("You are a proofreader, not a censor"));
ok(review.includes("Do not apply blanket content filtering"));
ok(review.includes("full requested level of mature, erotic and explicit fictional detail"));
ok(review.includes("Target family: sdxl"));
ok(review.includes("preferably 25–90 words"));
ok(review.includes("draft as a candidate"));
ok(buildImagePromptReviewSystem({modelName:"Krea2 SickRealism"}).includes("fluent photographic art direction"));
ok(buildImagePromptReviewSystem({modelName:"v1-5-pruned-emaonly"}).includes("20–45 words"));
ok(isImagePromptReviewSafe("A red bicycle. No people.","A red bicycle with no people on a wet street."));
ok(!isImagePromptReviewSafe("A red bicycle. No people.","A red bicycle while a family of 2 stands nearby."));
ok(!isImagePromptReviewSafe("A red bicycle. No people.","A red bicycle in evening light."));
ok(!isImagePromptReviewSafe("A red bicycle in evening light. No people.","A red bicycle in the morning light. No people."));
ok(!isImagePromptReviewSafe("A red bicycle. No people.","A red bicycle. No people. 家族"));
ok(!isImagePromptReviewSafe("A red bicycle.","A red bicycle with worn wood textures."));
ok(!isImagePromptReviewSafe("A red bicycle leans against a blue wall.","A red bicycle leans against a blue wall. A vintage red bike rests beside the same blue wall."));
ok(!isImagePromptReviewSafe("A red bicycle. No people.","A red bicycle. The scene is"));
ok(!isImagePromptReviewSafe("A red bicycle.","A red car on a street."));
ok(!isImagePromptReviewSafe("A red bicycle against a blue wall.","A red bicycle against a blue wall beside brick buildings and trees."));
ok(!isImagePromptReviewSafe("A red bicycle.","A red bicycle. aesthetic elements: wet cobblestones."));
ok(!isImagePromptReviewSafe("A red bicycle.","A red bicycle on a street. "+"extra ".repeat(70)));
ok(!isImagePromptReviewSafe("A red bicycle.","A red bicycle. image-generation prompt: use SDXL."));
console.log(`Image prompt profile: ${assertions} assertions passed`);