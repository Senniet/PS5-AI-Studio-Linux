import path from "node:path";
import crypto from "node:crypto";
import {isAllowedDownloadExtension,buildCivitaiDownloadUrl} from "./download-validation.mjs";

const uuid=/^[a-f0-9-]{16,64}$/i;
function validRepo(value){return typeof value==="string"&&/^[\w.-]+\/[\w.-]+$/.test(value)&&!value.includes("..");}
export function normalizePersistedDownload(record,allowedDirs){
 if(!record||typeof record!=="object"||Array.isArray(record)||!uuid.test(String(record.id||"")))return null;
 const source=record.source,category=record.category,file=record.file,name=record.name;
 if(!["huggingface","civitai","civitai-red"].includes(source)||typeof category!=="string"||typeof file!=="string"||!file||file.startsWith("/")||file.split("/").some(x=>!x||x==="."||x===".."))return null;
 if(typeof name!=="string"||path.basename(file)!==name||path.basename(name)!==name||!isAllowedDownloadExtension(category,file))return null;
 const size=Number(record.size),downloaded=Number(record.downloaded||0);
 if(!Number.isSafeInteger(size)||size<0||!Number.isSafeInteger(downloaded)||downloaded<0||(size&&downloaded>size))return null;
 if(record.sha256!=null&&!/^[a-f0-9]{64}$/i.test(String(record.sha256)))return null;
 const dirs=allowedDirs[category];if(!Array.isArray(dirs)||!dirs.length)return null;
 const target=path.resolve(String(record.target||"")),part=path.resolve(String(record.part||""));
 const matching=dirs.map(x=>path.resolve(x)).find(dir=>path.join(dir,name)===target);
 if(!matching||part!==target+".part")return null;
 let url;
 if(source==="civitai"||source==="civitai-red"){if(record.repo!==source)return null;try{url=buildCivitaiDownloadUrl(source,record.versionId,record.fileType,record.format,record.fileId);}catch{return null;}}
 else{if(!validRepo(record.repo))return null;url="https://huggingface.co/"+record.repo+"/resolve/main/"+file.split("/").map(encodeURIComponent).join("/");}
 const statuses=new Set(["queued","downloading","paused","error","missing","done","cancelled"]);
 if(!statuses.has(record.status))return null;
 return {...record,source,category,file,name,size,downloaded,url,target,part};
}

export function blockedPersistedDownload(record){
 const id=uuid.test(String(record?.id||""))?record.id:crypto.randomUUID();
 return {id,source:"blocked",category:"text",repo:"",file:"",name:String(record?.name||"Ongeldige opgeslagen download").slice(0,180),size:0,sha256:null,url:"",versionId:null,fileType:"",format:"",fileId:null,target:null,part:null,status:"error",downloaded:0,speed:0,error:"Ongeldig opgeslagen downloadrecord geblokkeerd",blocked:true};
}