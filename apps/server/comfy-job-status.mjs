export function taskStateVisible(state){return ["queued","running","error"].includes(state);}
export function comfyQueueHasWork(queue){if(!queue||typeof queue!=="object"||!Array.isArray(queue.queue_running)||!Array.isArray(queue.queue_pending))return true;return queue.queue_running.length>0||queue.queue_pending.length>0;}
export function terminalComfyJobError(entry,hasOutput){
 const status=entry?.status;
 if(status?.status_str==="error"||status?.completed===false)return JSON.stringify(status).slice(0,1800);
 if(status?.completed===true&&!hasOutput)return "ComfyUI heeft de Krea 2-workflow voltooid zonder een afbeelding terug te geven.";
 return null;
}

export function workflowCancellationFailure(queueOk,actionOk){
 if(!queueOk)return{status:503,error:"ComfyUI-wachtrij niet bereikbaar; annulering is niet bevestigd."};
 if(!actionOk)return{status:502,error:"ComfyUI heeft het annuleerverzoek niet bevestigd."};
 return null;
}

export function kreaJobTask(job){
 if(!job||!taskStateVisible(job.state))return null;
 const id=String(job.id||""),name=String(job.modelName||"Krea 2-generatie");
 const detail=job.state==="error"?String(job.error||"Krea 2-generatie mislukt").slice(0,500):[job.width&&job.height?job.width+" × "+job.height:null,job.steps?job.steps+" stappen":null,String(job.prompt||"").slice(0,100)].filter(Boolean).join(" · ");
 return{id:"krea2:"+id,type:"generation",name:"Krea 2 · "+name,state:job.state,progress:null,detail:detail||"Krea 2-generatie",target:"images"};
}

export function activeComfyVideoJob(jobs){
 return [...jobs].find(job=>job&&job.engine!=="native"&&["queued","running"].includes(job.state))||null;
}