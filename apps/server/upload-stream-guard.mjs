import {Transform} from "node:stream";

export function createUploadByteLimit(maxBytes,onBytes=()=>{}){
 if(!Number.isSafeInteger(maxBytes)||maxBytes<0)throw new TypeError("maxBytes moet een niet-negatief veilig geheel getal zijn");
 let received=0;
 const stream=new Transform({transform(chunk,encoding,callback){
  received+=chunk.length;
  if(received>maxBytes){callback(Object.assign(Error("Upload overschrijdt de toegestane grootte"),{status:413}));return;}
  onBytes(received);callback(null,chunk);
 }});
 Object.defineProperty(stream,"receivedBytes",{get:()=>received});
 return stream;
}
