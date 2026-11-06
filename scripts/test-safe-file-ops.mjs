import assert from "node:assert/strict";
import fs from "node:fs";
import fsp from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import {openRegularFileNoFollow,readFileNoFollow,writeFileNoFollow,atomicWriteFileNoFollow} from "../apps/server/safe-file-ops.mjs";
const dir=await fsp.mkdtemp(path.join(os.tmpdir(),"ps5-safe-file-"));
try{
 const regular=path.join(dir,"regular.txt"),outside=path.join(dir,"outside.txt"),link=path.join(dir,"link.txt");
 const handle=await openRegularFileNoFollow(regular,fs.constants.O_WRONLY|fs.constants.O_CREAT|fs.constants.O_TRUNC);await handle.writeFile("safe");await handle.close();
 assert.equal(await readFileNoFollow(regular,"utf8"),"safe");await writeFileNoFollow(regular,"safe-again");assert.equal(await readFileNoFollow(regular,"utf8"),"safe-again");
 await fsp.writeFile(outside,"CANARY");await fsp.symlink(outside,link);
 await assert.rejects(openRegularFileNoFollow(link,fs.constants.O_WRONLY|fs.constants.O_TRUNC),e=>e.status===403);
 await assert.rejects(openRegularFileNoFollow(link,fs.constants.O_RDONLY),e=>e.status===403);
 await assert.rejects(readFileNoFollow(link,"utf8"),e=>e.status===403);
 await assert.rejects(writeFileNoFollow(link,"tampered"),e=>e.status===403);
 await atomicWriteFileNoFollow(link,"REPLACED-LINK");assert.equal(await fsp.readFile(link,"utf8"),"REPLACED-LINK");
 assert.equal(await fsp.readFile(outside,"utf8"),"CANARY");
 console.log("Safe file ops: 7 assertions passed");
}finally{await fsp.rm(dir,{recursive:true,force:true});}
