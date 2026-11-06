export function isValidGGUFHeader(buffer){
 if(!Buffer.isBuffer(buffer)||buffer.length<24||buffer.toString("ascii",0,4)!=="GGUF")return false;
 const version=buffer.readUInt32LE(4),tensors=Number(buffer.readBigUInt64LE(8)),metadata=Number(buffer.readBigUInt64LE(16));
 return version>=1&&version<=3&&Number.isSafeInteger(tensors)&&tensors>0&&Number.isSafeInteger(metadata)&&metadata>0;
}
export function readGGUFTensorCount(buffer){
 if(!isValidGGUFHeader(buffer))return null;
 const count=Number(buffer.readBigUInt64LE(8));
 return Number.isSafeInteger(count)&&count>=0?count:null;
}
export function classifyGGUFLoadability(tensorCount,blockCount){
 const tensors=Number(tensorCount),blocks=Number(blockCount);
 if(Number.isSafeInteger(tensors)&&tensors>0&&Number.isSafeInteger(blocks)&&blocks>0&&tensors<blocks*2){
  return{loadable:false,reason:`GGUF lijkt onvolledig: ${tensors} tensors voor ${blocks} modelblokken; dit ligt onder de conservatieve ondergrens van 2 tensors per blok en kan een draft/MTP-fragment zijn.`};
 }
 return{loadable:true,reason:null};
}
