export async function cacheValidated(cache,key,validate,maxEntries=256){
 if(cache.has(key)){
  const hit=cache.get(key);cache.delete(key);cache.set(key,hit);return hit;
 }
 const pending=Promise.resolve().then(validate);cache.set(key,pending);
 try{
  const result=await pending;
  while(cache.size>Math.max(1,maxEntries))cache.delete(cache.keys().next().value);
  return result;
 }catch(error){
  if(cache.get(key)===pending)cache.delete(key);
  throw error;
 }
}
