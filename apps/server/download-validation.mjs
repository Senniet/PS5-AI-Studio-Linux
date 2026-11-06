import path from "node:path";
const modelExtensions=new Set([".safetensors",".ckpt",".gguf",".sft",".bin",".onnx",".pt",".pth"]);
export function isAllowedDownloadExtension(category,file){
 const extension=path.extname(String(file||"")).toLowerCase();
 return category==="text"?extension===".gguf":modelExtensions.has(extension);
}
export function buildCivitaiDownloadUrl(source,versionId,fileType="",format="",fileId=null){
 if(!["civitai","civitai-red"].includes(source)||!Number.isSafeInteger(Number(versionId))||Number(versionId)<=0)throw Error("Ongeldige Civitai-downloadbestemming");
 const params=new URLSearchParams(),type=String(fileType||"").slice(0,30),fmt=String(format||"").slice(0,30),id=Number(fileId);
 if(type)params.set("type",type);
 if(fmt)params.set("format",fmt);
 if(Number.isSafeInteger(id)&&id>0)params.set("fileId",String(id));
 const host=source==="civitai-red"?"https://civitai.red":"https://civitai.com";
 return host+"/api/download/models/"+Number(versionId)+(params.size?"?"+params.toString():"");
}

export function describeDownloadHTTPError(status,resumeOffset=0){
 const action=resumeOffset>0?"hervatten":"downloaden";
 const authHint=status===401||status===403?" (controleer API-key en toegangsrechten)":"";
 return `Downloadserver HTTP ${Number(status)} bij ${action}${authHint}`;
}

export function nextDownloadByteCount(current,chunkBytes,maxBytes){
 if(!Number.isSafeInteger(current)||current<0||!Number.isSafeInteger(chunkBytes)||chunkBytes<0||!Number.isSafeInteger(maxBytes)||maxBytes<0)throw new TypeError("Ongeldige downloadbyte-teller");
 const next=current+chunkBytes;
 if(!Number.isSafeInteger(next)||next>maxBytes)throw Object.assign(Error("Download overschrijdt de verwachte bestandsgrootte of beschikbare limiet"),{code:"ERR_DOWNLOAD_SIZE_LIMIT"});
 return next;
}