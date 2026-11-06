import fs from "node:fs";
import fsp from "node:fs/promises";
import crypto from "node:crypto";

export async function openRegularFileNoFollow(filePath,flags,mode=0o600){
 const noFollow=fs.constants.O_NOFOLLOW;
 if(!Number.isInteger(noFollow))throw Error("O_NOFOLLOW wordt niet ondersteund op dit platform");
 let handle;
 try{handle=await fsp.open(filePath,flags|noFollow,mode);}catch(error){
  if(error.code==="ELOOP"||error.code==="EMLINK")throw Object.assign(Error("Symlink-pad niet toegestaan"),{status:403,code:error.code});
  throw error;
 }
 const stat=await handle.stat();
 if(!stat.isFile()){await handle.close();throw Object.assign(Error("Alleen reguliere bestanden zijn toegestaan"),{status:403});}
 return handle;
}

export async function readFileNoFollow(filePath,encoding){
 const handle=await openRegularFileNoFollow(filePath,fs.constants.O_RDONLY);
 try{return await handle.readFile(encoding);}finally{await handle.close();}
}

export async function writeFileNoFollow(filePath,data,mode=0o600){
 const handle=await openRegularFileNoFollow(filePath,fs.constants.O_WRONLY|fs.constants.O_CREAT|fs.constants.O_TRUNC,mode);
 try{await handle.writeFile(data);}finally{await handle.close();}
}

export async function atomicWriteFileNoFollow(filePath,data,mode=0o600){
 const temp=filePath+"."+crypto.randomUUID()+".tmp";let handle=null;
 try{
  handle=await openRegularFileNoFollow(temp,fs.constants.O_WRONLY|fs.constants.O_CREAT|fs.constants.O_EXCL,mode);
  await handle.writeFile(data);await handle.sync();await handle.close();handle=null;
  await fsp.rename(temp,filePath);
 }catch(error){
  if(handle)await handle.close().catch(()=>{});
  await fsp.rm(temp,{force:true}).catch(()=>{});
  throw error;
 }
}