import {spawn} from 'node:child_process';

export async function probeVideo(ffprobe, file, timeoutMs=30000) {
  return await new Promise((resolve,reject)=>{
    const child=spawn(ffprobe,['-v','error','-show_format','-show_streams','-of','json',file],{stdio:['ignore','pipe','pipe']});
    let stdout='',stderr='',settled=false;
    const timer=setTimeout(()=>{child.kill('SIGKILL');finish(new Error('Videoanalyse duurde te lang.'));},timeoutMs);
    const finish=(error,value)=>{if(settled)return;settled=true;clearTimeout(timer);error?reject(error):resolve(value);};
    child.stdout.on('data',x=>{stdout=(stdout+x).slice(-2_000_000);});
    child.stderr.on('data',x=>{stderr=(stderr+x).slice(-12_000);});
    child.on('error',finish);
    child.on('close',code=>{if(code!==0)return finish(new Error((stderr||'ffprobe kon dit videobestand niet lezen.').slice(-1800)));try{const data=JSON.parse(stdout),streams=data.streams||[],video=streams.find(x=>x.codec_type==='video');if(!video)throw new Error('Dit bestand bevat geen videostream.');const duration=Number(data.format?.duration||video.duration||0),fps=parseRate(video.avg_frame_rate||video.r_frame_rate);finish(null,{name:data.format?.filename?.split('/').pop()||null,format:data.format?.format_name||'unknown',duration:Number.isFinite(duration)?duration:0,size:Number(data.format?.size)||0,bitrate:Number(data.format?.bit_rate)||0,width:Number(video.width)||0,height:Number(video.height)||0,codec:video.codec_name||'unknown',pixelFormat:video.pix_fmt||'unknown',fps,frameRate:video.avg_frame_rate||video.r_frame_rate||'0/1',hasAudio:streams.some(x=>x.codec_type==='audio'),audioCodec:streams.find(x=>x.codec_type==='audio')?.codec_name||null,streams:streams.map(x=>({type:x.codec_type,codec:x.codec_name,width:x.width||null,height:x.height||null,channels:x.channels||null,sampleRate:x.sample_rate||null}))});}catch(e){finish(e);}});
  });
}
function parseRate(value){const [a,b]=String(value||'0/1').split('/').map(Number);return b? a/b : Number(value)||0;}

export function buildVideoEnhanceArgs(input,output,meta,settings={}) {
  const filters=[];
  const trimStart=Math.max(0,Math.min(Math.max(0,meta.duration-0.1),Number(settings.trimStart)||0));
  const requestedEnd=Number(settings.trimEnd)||0;
  const trimEnd=requestedEnd>trimStart?Math.min(meta.duration,requestedEnd):meta.duration;
  const clipDuration=Math.max(0.1,trimEnd-trimStart);
  const speed=Math.max(0.5,Math.min(2,Number(settings.speed)||1));
  const outputDuration=clipDuration/speed;
  const rotation=[0,90,180,270].includes(Number(settings.rotation))?Number(settings.rotation):0;
  const denoise=Math.max(0,Math.min(100,Number(settings.denoise)||0));
  const sharpen=Math.max(0,Math.min(100,Number(settings.sharpen)||0));
  const brightness=Math.max(-100,Math.min(100,Number(settings.brightness)||0));
  const contrast=Math.max(50,Math.min(150,Number(settings.contrast)||100));
  const saturation=Math.max(0,Math.min(200,Number(settings.saturation)||100));
  const gamma=Math.max(50,Math.min(200,Number(settings.gamma)||100));
  if(rotation===90)filters.push('transpose=clock');else if(rotation===270)filters.push('transpose=cclock');else if(rotation===180)filters.push('hflip','vflip');
  if(speed!==1)filters.push(`setpts=PTS/${speed.toFixed(2)}`);
  if(settings.deinterlace===true)filters.push('yadif=mode=send_frame:parity=auto:deint=interlaced');
  if(settings.stabilize===true)filters.push('deshake=rx=16:ry=16:edge=mirror');
  if(denoise>0){const s=denoise/100;filters.push(`hqdn3d=${(0.6+s*3.4).toFixed(2)}:${(0.45+s*2.55).toFixed(2)}:${(1+s*5).toFixed(2)}:${(0.75+s*3.75).toFixed(2)}`);}
  if(brightness!==0||contrast!==100||saturation!==100||gamma!==100){filters.push(`eq=brightness=${(brightness/500).toFixed(3)}:contrast=${(contrast/100).toFixed(3)}:saturation=${(saturation/100).toFixed(3)}:gamma=${(gamma/100).toFixed(3)}`);}
  if(sharpen>0){const amount=(sharpen/100*1.15).toFixed(2);filters.push(`unsharp=5:5:${amount}:5:5:0.0`);}
  const resolution=String(settings.resolution||'original');
  const sizes={'720p':[1280,720],'1080p':[1920,1080],'1440p':[2560,1440],'2160p':[3840,2160]};
  if(resolution==='2x')filters.push('scale=w=min(3840\\,iw*2):h=min(2160\\,ih*2):force_divisible_by=2:flags=lanczos');
  else if(sizes[resolution]){const [w,h]=sizes[resolution];filters.push(`scale=${w}:${h}:force_original_aspect_ratio=decrease:force_divisible_by=2:flags=lanczos`);}
  const targetFps=Math.max(0,Math.min(60,Number(settings.targetFps)||0));
  if(settings.interpolate===true&&settings.interpolationEngine!=="rife"&&targetFps>meta.fps+0.5){filters.push(`minterpolate=fps=${targetFps}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1`);}
  const args=['-hide_banner','-y','-loglevel','warning'];
  if(trimStart>0)args.push('-ss',trimStart.toFixed(3));
  args.push('-i',input,'-t',outputDuration.toFixed(3),'-map','0:v:0');
  if(settings.preserveAudio!==false)args.push('-map','0:a?');
  if(filters.length)args.push('-vf',filters.join(','));
  const volume=Math.max(0,Math.min(200,(settings.volume==null?100:Number(settings.volume))))/100;
  args.push('-c:v','libx264','-preset',settings.preset==='slow'?'slow':'veryfast','-crf',String(Math.max(16,Math.min(30,Number(settings.quality)||20))),'-pix_fmt','yuv420p','-threads','4');
  if(settings.preserveAudio!==false){args.push('-c:a','aac','-b:a','160k');const audioFilters=[];if(speed!==1)audioFilters.push(`atempo=${speed.toFixed(2)}`);if(volume!==1)audioFilters.push(`volume=${volume.toFixed(2)}`);if(audioFilters.length)args.push('-af',audioFilters.join(','));}
  args.push('-movflags','+faststart','-metadata','comment=Processed with PS5 AI Studio Video Studio','-progress','pipe:2','-nostats',output);
  return {args,filters,clipDuration,outputDuration,trimStart,speed,rotation,estimatedOutputFps:settings.interpolate===true&&targetFps>meta.fps+0.5?targetFps:meta.fps};
}

export function startVideoEnhancement({ffmpeg,input,output,meta,settings,onProgress=()=>{},onClose=()=>{}}) {
  const built=buildVideoEnhanceArgs(input,output,meta,settings);
  const child=spawn(ffmpeg,built.args,{stdio:['ignore','ignore','pipe']});
  let buffer='',stderr='',settled=false;
  child.stderr.on('data',chunk=>{
    const value=chunk.toString();stderr=(stderr+value).slice(-12000);buffer+=value;
    const lines=buffer.split(/\r?\n/);buffer=lines.pop()||'';
    for(const line of lines){const i=line.indexOf('=');if(i<1)continue;const key=line.slice(0,i),v=line.slice(i+1);if(key==='out_time_us'||key==='out_time_ms'){const micros=Number(v);if(Number.isFinite(micros)&&meta.duration>0){const percent=Math.max(0,Math.min(99,Math.round(micros/(meta.duration*1_000_000)*100)));onProgress({percent,elapsedUs:micros,stage:'Video verwerken',filters:built.filters});}}else if(key==='progress'&&v==='end')onProgress({percent:100,stage:'Video afronden',filters:built.filters});}
  });
  child.once('error',error=>{if(settled)return;settled=true;onClose(error,null,stderr);});
  child.once('close',(code,signal)=>{if(settled)return;settled=true;onClose(code===0?null:new Error((stderr||`FFmpeg stopte met code ${code} (${signal||'unknown'}).`).slice(-2400)),{code,signal,filters:built.filters,estimatedOutputFps:built.estimatedOutputFps},stderr);});
  return child;
}

export function startRifeVideoEnhancement({ffmpeg,rife,model,input,output,meta,settings,workDir,onProgress=()=>{},onClose=()=>{}}){
  let activeChild=null,cancelled=false,settled=false;
  const controller={kill(){cancelled=true;try{activeChild?.kill('SIGTERM');}catch{}}};
  const finish=(error,result)=>{if(settled)return;settled=true;onClose(error,result);};
  const run=(command,args,stage,base,span,duration=meta.duration)=>new Promise((resolve,reject)=>{
    if(cancelled)return reject(new Error('RIFE-videobewerking geannuleerd.'));
    const child=spawn(command,args,{stdio:['ignore','pipe','pipe']});activeChild=child;
    let stdout='',stderr='',buffer='',settledStage=false,rifeDone=0,lastRifeLine='';
    const done=(error,value)=>{if(settledStage)return;settledStage=true;activeChild=null;error?reject(error):resolve(value);};
    const parse=chunk=>{const value=chunk.toString();stderr=(stderr+value).slice(-10000);buffer+=value;const lines=buffer.split(/\r?\n/);buffer=lines.pop()||'';for(const line of lines){const t=line.trim();if(stage==='RIFE AI · Vulkan'&&/ done$/.test(t)&&t!==lastRifeLine){lastRifeLine=t;rifeDone++;onProgress({percent:Math.min(base+span,base+Math.round(rifeDone/Math.max(1,Number(settings.targetFrames)||1)*span)),stage,detail:t.slice(0,180)});}else{const i=t.indexOf('=');if(i<1)continue;const key=t.slice(0,i),v=t.slice(i+1);if(key==='out_time_us'||key==='out_time_ms'){const micros=Number(v);if(Number.isFinite(micros)&&duration>0){const percent=Math.max(0,Math.min(span,Math.round(micros/(duration*1_000_000)*span)));onProgress({percent:base+percent,stage,elapsedUs:micros});}}}}
    };
    child.stdout.on('data',chunk=>{stdout=(stdout+chunk.toString()).slice(-10000);if(stage==='RIFE AI · Vulkan')parse(chunk);});
    child.stderr.on('data',parse);
    child.on('error',done);
    child.on('close',(code,signal)=>{if(cancelled)return done(new Error('RIFE-videobewerking geannuleerd.'));if(code!==0)return done(new Error((stderr||stdout||`${stage} stopte met code ${code} (${signal||'unknown'}).`).slice(-2200)));done(null,{code,stdout,stderr});});
  });
  (async()=>{
    try{
      const inputFrames=pathJoin(workDir,'input'),outputFrames=pathJoin(workDir,'output'),intermediate=pathJoin(workDir,'preprocessed.mp4');
      const {mkdir,rm}=await import('node:fs/promises');await mkdir(inputFrames,{recursive:true});await mkdir(outputFrames,{recursive:true});
      const pre=buildVideoEnhanceArgs(input,intermediate,meta,{...settings,interpolate:false});
      onProgress({percent:0,stage:'Video voorbereiden'});
      await run(ffmpeg,pre.args,'Video voorbereiden',0,12,meta.duration);
      if(cancelled)throw new Error('RIFE-videobewerking geannuleerd.');
      const processedMeta=await probeVideo(settings.ffprobe||pathReplace(ffmpeg,'ffprobe'),intermediate);
      const fps=Math.max(1,Number(settings.targetFps)||Math.round(processedMeta.fps*2));
      if(fps<=processedMeta.fps+0.5)throw new Error(`RIFE-doelframerate (${fps} fps) moet hoger zijn dan de bron (${processedMeta.fps.toFixed(2)} fps).`);
      const framePattern=pathJoin(inputFrames,'%08d.jpg');
      await run(ffmpeg,['-hide_banner','-y','-loglevel','warning','-i',intermediate,'-fps_mode','passthrough','-q:v','2','-start_number','1',framePattern],'Frames extraheren',12,8,processedMeta.duration);
      if(cancelled)throw new Error('RIFE-videobewerking geannuleerd.');
      const targetFrames=Math.max(2,Math.round(processedMeta.duration*fps));settings.targetFrames=targetFrames;
      onProgress({percent:20,stage:'RIFE AI · Vulkan',detail:`${targetFrames} uitvoerframes · ${fps} fps`});
      await run(rife,['-i',inputFrames,'-o',outputFrames,'-m',model,'-g','0','-j','1:1:1','-n',String(targetFrames),'-f','%08d.jpg','-v'],'RIFE AI · Vulkan',20,65,processedMeta.duration);
      if(cancelled)throw new Error('RIFE-videobewerking geannuleerd.');
      const files=(await (await import('node:fs/promises')).readdir(outputFrames)).filter(x=>/^\d{8}\.jpg$/i.test(x));
      if(files.length<2)throw new Error(`RIFE leverde slechts ${files.length} frames op; minimaal 2 verwacht.`);
      onProgress({percent:86,stage:'Video en audio samenvoegen',detail:`${files.length} AI-frames`});
      const mux=['-hide_banner','-y','-loglevel','warning','-framerate',String(fps),'-start_number','1','-i',pathJoin(outputFrames,'%08d.jpg'),'-i',intermediate,'-map','0:v:0'];
      if(settings.preserveAudio!==false)mux.push('-map','1:a?');
      mux.push('-c:v','libx264','-preset','veryfast','-crf',String(Math.max(16,Math.min(30,Number(settings.quality)||20))),'-pix_fmt','yuv420p','-threads','4');
      if(settings.preserveAudio!==false)mux.push('-c:a','copy');
      mux.push('-movflags','+faststart','-metadata','comment=PS5 AI Studio · RIFE NCNN Vulkan','-progress','pipe:2','-nostats',output);
      await run(ffmpeg,mux,'Video en audio samenvoegen',86,14,processedMeta.duration);
      if(cancelled)throw new Error('RIFE-videobewerking geannuleerd.');
      finish(null,{filters:pre.filters,interpolation:'RIFE NCNN Vulkan · rife-v4.6',outputFps:fps,frames:files.length,backend:'AMD Oberon · Vulkan'});
    }catch(error){finish(error,null);}finally{activeChild=null;const {rm}=await import('node:fs/promises');await rm(workDir,{recursive:true,force:true}).catch(()=>{});}
  })();
  return controller;
}
export function startSeedVR2VideoEnhancement({ffmpeg,ffprobe,input,output,meta,settings,workDir,comfyBase,comfyInputDir,comfyOutputDir,modelName,vaeModelName,targetResolution,tileSize=192,onProgress=()=>{},onClose=()=>{}}){
  let activeChild=null,cancelled=false,settled=false,promptId=null,socket=null,progressValue=0;
  const id=String(settings.jobId||Date.now()).replace(/[^A-Za-z0-9_-]/g,'');
  const prefix='ps5seedvr2_'+id;
  const inputName=prefix+'.mp4';
  const inputCopy=pathJoin(comfyInputDir,inputName);
  const updateProgress=value=>{if(Number.isFinite(value?.percent))progressValue=Math.max(progressValue,Math.max(0,Math.min(100,value.percent)));onProgress({...value,percent:progressValue});};
  const controller={kill(){cancelled=true;if(activeChild){try{activeChild.kill('SIGTERM');}catch{}}if(promptId)void cancelComfy();}};
  const finish=(error,result)=>{if(settled)return;settled=true;try{socket?.close();}catch{}onClose(error,result);};
  const cancelComfy=async()=>{if(!promptId)return;try{const q=await fetch(comfyBase+'/queue',{signal:AbortSignal.timeout(5000)}),queue=q.ok?await q.json():{},running=(queue.queue_running||[]).some(x=>x[1]===promptId);if(running)await fetch(comfyBase+'/interrupt',{method:'POST',signal:AbortSignal.timeout(5000)});else await fetch(comfyBase+'/queue',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({delete:[promptId]}),signal:AbortSignal.timeout(5000)});}catch{}};
  const run=(command,args,stage,base,span,duration=meta.duration)=>new Promise((resolve,reject)=>{
    if(cancelled)return reject(new Error('SeedVR2-videobewerking geannuleerd.'));
    const child=spawn(command,args,{stdio:['ignore','ignore','pipe']});activeChild=child;let stderr='',buffer='',doneOnce=false;
    const done=(error,value)=>{if(doneOnce)return;doneOnce=true;activeChild=null;error?reject(error):resolve(value);};
    child.stderr.on('data',chunk=>{const value=chunk.toString();stderr=(stderr+value).slice(-12000);buffer+=value;const lines=buffer.split(/\r?\n/);buffer=lines.pop()||'';for(const line of lines){const i=line.indexOf('=');if(i<1)continue;const key=line.slice(0,i),v=line.slice(i+1);if(key==='out_time_us'||key==='out_time_ms'){const micros=Number(v);if(Number.isFinite(micros)&&duration>0){const pct=Math.max(0,Math.min(span,Math.round(micros/(duration*1_000_000)*span)));updateProgress({percent:base+pct,stage,elapsedUs:micros});}}}});
    child.on('error',done);
    child.on('close',(code,signal)=>{if(cancelled)return done(new Error('SeedVR2-videobewerking geannuleerd.'));if(code!==0)return done(new Error((stderr||`${stage} stopte met code ${code} (${signal||'unknown'}).`).slice(-2400)));done(null,{code,stderr});});
  });
  (async()=>{
    const {mkdir,rm,readdir,copyFile}=await import('node:fs/promises');
    try{
      const intermediate=pathJoin(workDir,'preprocessed.mp4'),outputFrames=pathJoin(workDir,'frames');
      await mkdir(workDir,{recursive:true});await mkdir(outputFrames,{recursive:true});
      const pre=buildVideoEnhanceArgs(input,intermediate,meta,{...settings,resolution:'original',interpolate:settings.interpolationEngine==='ffmpeg',interpolationEngine:'ffmpeg'});
      updateProgress({percent:0,stage:'Video voorbereiden'});
      await run(ffmpeg,pre.args,'Video voorbereiden',0,10,meta.duration);
      if(cancelled)throw new Error('SeedVR2-videobewerking geannuleerd.');
      const processedMeta=await probeVideo(ffprobe,intermediate),fps=Math.max(1,processedMeta.fps||meta.fps||24),inputFrames=Math.max(1,Math.round(processedMeta.duration*fps)),batchSize=inputFrames>=5?5:1;
      await copyFile(intermediate,inputCopy);
      const workflow={
        '1':{class_type:'LoadVideo',inputs:{file:inputName}},
        '2':{class_type:'GetVideoComponents',inputs:{video:['1',0]}},
        '3':{class_type:'SeedVR2LoadDiTModel',inputs:{model:modelName,device:'cuda:0',blocks_to_swap:32,swap_io_components:true,offload_device:'cpu',cache_model:false,attention_mode:'sdpa'}},
        '4':{class_type:'SeedVR2LoadVAEModel',inputs:{model:vaeModelName,device:'cuda:0',encode_tiled:true,encode_tile_size:tileSize,encode_tile_overlap:32,decode_tiled:true,decode_tile_size:tileSize,decode_tile_overlap:32,offload_device:'cpu',cache_model:false}},
        '5':{class_type:'SeedVR2VideoUpscaler',inputs:{image:['2',0],dit:['3',0],vae:['4',0],seed:Number(settings.seed)||42,resolution:Math.max(64,Math.round(Number(targetResolution)||1080)),max_resolution:1920,batch_size:batchSize,uniform_batch_size:batchSize===5,color_correction:'lab',temporal_overlap:batchSize===5?1:0,prepend_frames:0,input_noise_scale:0,latent_noise_scale:0,offload_device:'cpu',enable_debug:true}},
        '6':{class_type:'SaveImage',inputs:{images:['5',0],filename_prefix:prefix}}
      };
      updateProgress({percent:12,stage:'SeedVR2 · ComfyUI-wachtrij',detail:'3B Q4 · BlockSwap 32 · VAE tiles '+tileSize+'px'});
      const queuedResponse=await fetch(comfyBase+'/prompt',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({prompt:workflow,client_id:id}),signal:AbortSignal.timeout(30000)});
      const queued=await queuedResponse.json().catch(()=>({}));if(!queuedResponse.ok||!queued.prompt_id)throw new Error(queued.error?.message||queued.error||'ComfyUI kon de SeedVR2-workflow niet starten.');
      promptId=queued.prompt_id;
      try{socket=new WebSocket(comfyBase.replace(/^http/i,'ws')+'/ws?clientId='+encodeURIComponent(id));socket.addEventListener('message',event=>{try{const message=JSON.parse(String(event.data)),data=message.data||{};if(data.prompt_id&&data.prompt_id!==promptId)return;if(message.type==='progress'&&Number(data.max)>0){const value=Math.max(0,Math.min(1,Number(data.value)/Number(data.max)));updateProgress({percent:38+Math.round(value*40),stage:'SeedVR2 AI · AMD ROCm/GPU',detail:'Stap '+data.value+' van '+data.max});}else if(message.type==='executing'&&data.node){const labels={'1':'Video laden','2':'Videoframes uitlezen','3':'SeedVR2 3B Q4 laden','4':'SeedVR2 VAE laden','5':'SeedVR2 AI · AMD ROCm/GPU','6':'AI-frames opslaan'};updateProgress({percent:Math.max(18,progressValue),stage:labels[String(data.node)]||'SeedVR2 AI · AMD ROCm/GPU'});}else if(message.type==='execution_success')updateProgress({percent:80,stage:'SeedVR2 · frames verzamelen'});}catch{}});socket.addEventListener('error',()=>{});}catch{socket=null;}
      const started=Date.now();let images=null,lastRunning=false;
      while(Date.now()-started<6*60*60*1000){
        if(cancelled)throw new Error('SeedVR2-videobewerking geannuleerd.');
        const [queueResponse,historyResponse]=await Promise.all([fetch(comfyBase+'/queue',{signal:AbortSignal.timeout(10000)}),fetch(comfyBase+'/history/'+encodeURIComponent(promptId),{signal:AbortSignal.timeout(10000)})]);
        if(!queueResponse.ok||!historyResponse.ok)throw new Error('ComfyUI-status voor SeedVR2 is niet bereikbaar.');
        const queue=await queueResponse.json(),history=await historyResponse.json(),entry=history?.[promptId],status=entry?.status||{};
        if(status.status_str==='error'||status.completed===false){const failure=(status.messages||[]).find(x=>x?.[0]==='execution_error')?.[1];throw new Error(failure?.exception_message||'SeedVR2-workflow is mislukt.');}
        if(status.completed){images=entry?.outputs?.['6']?.images||[];break;}
        const running=(queue.queue_running||[]).some(x=>x[1]===promptId);if(running!==lastRunning){lastRunning=running;updateProgress({percent:running?38:16,stage:running?'SeedVR2 AI · AMD ROCm/GPU':'SeedVR2 · wachten op ComfyUI',detail:running?'De 3B Q4-transformer en VAE verwerken de videoframes.':'De workflow staat in de ComfyUI-wachtrij.'});}
        await new Promise(resolve=>setTimeout(resolve,1800));
      }
      if(!images)throw new Error('SeedVR2 heeft de verwerking niet binnen zes uur afgerond.');
      const frames=images.filter(x=>x&&typeof x.filename==='string'&&x.filename.startsWith(prefix+'_')&&/^[A-Za-z0-9._-]+\.png$/i.test(x.filename)).sort((a,b)=>a.filename.localeCompare(b.filename,undefined,{numeric:true}));
      if(!frames.length)throw new Error('SeedVR2 heeft geen uitvoerframes opgeslagen.');
      updateProgress({percent:82,stage:'SeedVR2 · frames verzamelen',detail:frames.length+' AI-frames · '+fps.toFixed(2)+' fps'});
      for(let i=0;i<frames.length;i++){
        const frame=frames[i],subfolder=String(frame.subfolder||''),source=pathJoin(comfyOutputDir,subfolder?subfolder+'/'+frame.filename:frame.filename),resolved=await import('node:path').then(m=>m.resolve(source)),root=await import('node:path').then(m=>m.resolve(comfyOutputDir));
        if(!resolved.startsWith(root+'/'))throw new Error('ComfyUI leverde een ongeldig uitvoerpad.');
        await copyFile(source,pathJoin(outputFrames,String(i+1).padStart(8,'0')+'.png'));
        await rm(source,{force:true});
      }
      if(cancelled)throw new Error('SeedVR2-videobewerking geannuleerd.');
      updateProgress({percent:88,stage:'Video en audio samenvoegen',detail:frames.length+' frames · '+fps.toFixed(2)+' fps'});
      const mux=['-hide_banner','-y','-loglevel','warning','-framerate',String(fps),'-start_number','1','-i',pathJoin(outputFrames,'%08d.png'),'-i',intermediate,'-map','0:v:0'];
      if(settings.preserveAudio!==false)mux.push('-map','1:a?');
      mux.push('-c:v','libx264','-preset','veryfast','-crf',String(Math.max(16,Math.min(30,Number(settings.quality)||20))),'-pix_fmt','yuv420p','-threads','4');
      if(settings.preserveAudio!==false)mux.push('-c:a','copy');
      mux.push('-movflags','+faststart','-metadata','comment=PS5 AI Studio · SeedVR2 3B Q4 · AMD ROCm','-progress','pipe:2','-nostats',output);
      await run(ffmpeg,mux,'Video en audio samenvoegen',88,12,processedMeta.duration);
      if(cancelled)throw new Error('SeedVR2-videobewerking geannuleerd.');
      finish(null,{filters:pre.filters,upscaling:'SeedVR2 3B Q4 · AMD ROCm/HIP · BlockSwap 32',outputFps:fps,frames:frames.length,backend:'AMD Oberon · PyTorch ROCm/HIP',tileSize});
    }catch(error){finish(error,null);}finally{
      activeChild=null;await rm(inputCopy,{force:true}).catch(()=>{});
      try{for(const name of await readdir(comfyOutputDir)){if(name.startsWith(prefix+'_')&&name.toLowerCase().endsWith('.png'))await rm(pathJoin(comfyOutputDir,name),{force:true}).catch(()=>{});}}catch{}
      await rm(workDir,{recursive:true,force:true}).catch(()=>{});
    }
  })();
  return controller;
}

function pathJoin(a,b){return a.replace(/\/$/,'')+'/'+b;}
function pathReplace(value,search){return value.replace(/[^/]+$/,search);}
