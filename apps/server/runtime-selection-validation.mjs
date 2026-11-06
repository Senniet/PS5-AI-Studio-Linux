function bad(message){throw Object.assign(Error(message),{status:400});}
export function validateTextRuntimeOptions(body,settings){
 if(!body||typeof body!=="object"||Array.isArray(body))bad("Ongeldige tekst-runtimeopties");
 const context=Math.max(512,Math.min(65536,Number(body.context)||settings.context));
 const threads=Number(body.threads??settings.threads);
 if(!Number.isInteger(threads)||threads<1||threads>16)bad("Threads moet een geheel getal van 1 tot en met 16 zijn");
 const gpuLayers=String(body.gpuLayers??settings.gpuLayers);
 if(!/^(all|auto|0|[1-9]\d{0,2})$/.test(gpuLayers))bad("Ongeldig aantal GPU-layers");
 const cacheK=String(body.cacheK??settings.cacheK),cacheV=String(body.cacheV??settings.cacheV);
 if(!["q4_0","q8_0","f16"].includes(cacheK)||!["q4_0","q8_0","f16"].includes(cacheV))bad("Ongeldig cachetype");
 let mmproj=null;if(body.mmproj==="none")mmproj=null;else if(body.mmproj==null||body.mmproj==="")mmproj="auto";else if(typeof body.mmproj==="string")mmproj=body.mmproj;else bad("Ongeldige mmproj-keuze");
 return{context,threads,gpuLayers,cacheK,cacheV,mmproj};
}

export function validateImageRuntimeSelections(body,assets){
 if(!body||typeof body!=="object"||Array.isArray(body))bad("Ongeldige beeld-runtimeopties");
 const options=[
  ["controlnet","controlnet","Geselecteerd ControlNet-bestand is niet gevonden","cn"],
  ["ipadapter","ipadapter","Geselecteerd IP-Adapter-bestand is niet gevonden","ip"],
  ["clipvision","clipvision","Geselecteerd CLIP Vision-bestand is niet gevonden","cv"],
  ["vae","vae","Geselecteerd VAE-bestand is niet gevonden","vae"]
 ];
 const selected={};
 for(const [key,category,message,resultKey] of options){
  const found=body[key]?assets[category].find(x=>x.path===body[key]):null;
  if(body[key]&&!found)throw Object.assign(Error(message),{status:404});
  selected[resultKey]=found;
 }
 if((selected.ip&&!selected.cv)||(!selected.ip&&selected.cv))throw Object.assign(Error("IP-Adapter vereist zowel een IP-Adapter-model als een CLIP Vision-encoder"),{status:400});
 return selected;
}

export function validateKrea2Dimensions(body){
 if(!body||typeof body!=="object"||Array.isArray(body))bad("Ongeldige Krea 2-opties");
 const dimension=value=>{
  const requested=value==null||value===""?384:Number(value);
  const normalized=Math.max(256,Math.min(1280,Math.round(requested/64)*64));
  if(!Number.isFinite(requested)||requested!==normalized)bad("Resolutie moet tussen 256 en 1280 liggen en deelbaar zijn door 64.");
  return normalized;
 };
 const width=dimension(body.width),height=dimension(body.height);
 if(width!==height)bad("Krea 2 PS5-profiel gebruikt op dit moment vierkante uitvoer.");
 return{width,height};
}

export function resolveKVCacheTypes(meta,requestedK="q8_0",requestedV=requestedK){
 const keyLength=meta?.keyLength||(meta?.embedding&&meta?.heads?Math.floor(meta.embedding/meta.heads):null);
 const valueLength=meta?.valueLength||keyLength;
 const cacheK=keyLength&&keyLength%32!==0?"f16":requestedK;
 const cacheV=valueLength&&valueLength%32!==0?"f16":requestedV;
 const fallback=[];
 if(cacheK!==requestedK)fallback.push("K-cache: head-dimensie "+keyLength+" is niet deelbaar door 32; F16 vereist");
 if(cacheV!==requestedV)fallback.push("V-cache: head-dimensie "+valueLength+" is niet deelbaar door 32; F16 vereist");
 return{cacheK,cacheV,fallback,keyLength,valueLength};
}