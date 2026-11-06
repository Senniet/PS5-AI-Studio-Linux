import assert from "node:assert/strict";
import {Readable,Writable} from "node:stream";
import {pipeline} from "node:stream/promises";
import {createUploadByteLimit} from "../apps/server/upload-stream-guard.mjs";

let observed=0,output=Buffer.alloc(0);
const exact=createUploadByteLimit(5,n=>observed=n);
await pipeline(Readable.from([Buffer.from("ab"),Buffer.from("cde")]),exact,new Writable({write(chunk,encoding,callback){output=Buffer.concat([output,chunk]);callback();}}));
assert.equal(exact.receivedBytes,5);assert.equal(observed,5);assert.equal(output.toString(),"abcde");
await assert.rejects(pipeline(Readable.from([Buffer.from("abc"),Buffer.from("def")]),createUploadByteLimit(5),new Writable({write(chunk,encoding,callback){callback();}})),e=>e.status===413);
assert.throws(()=>createUploadByteLimit(Number.MAX_SAFE_INTEGER+1),TypeError);
console.log("Upload stream guard: 3 assertions passed");