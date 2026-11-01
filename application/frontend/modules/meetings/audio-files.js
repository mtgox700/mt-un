export const LIMIT=5*1024*1024,PART=262144;
export function base64(bytes){let s='';for(let i=0;i<bytes.length;i+=8192)s+=String.fromCharCode(...bytes.subarray(i,i+8192));return btoa(s);}
export function unbase64(text){return Uint8Array.from(atob(text),x=>x.charCodeAt(0));}
export function pcmWav(samples,rate=16000){
 const bytes=new Uint8Array(44+samples.length*2),v=new DataView(bytes.buffer);
 const str=(off,s)=>{for(let i=0;i<s.length;i++)v.setUint8(off+i,s.charCodeAt(i));};
 str(0,'RIFF');v.setUint32(4,bytes.length-8,true);str(8,'WAVE');str(12,'fmt ');v.setUint32(16,16,true);v.setUint16(20,1,true);v.setUint16(22,1,true);v.setUint32(24,rate,true);v.setUint32(28,rate*2,true);v.setUint16(32,2,true);v.setUint16(34,16,true);str(36,'data');v.setUint32(40,samples.length*2,true);
 for(let i=0;i<samples.length;i++){const n=Math.max(-1,Math.min(1,samples[i]));v.setInt16(44+i*2,Math.round(n*(n<0?32768:32767)),true);}return bytes;
}
export async function normalizeAudio(blob){
 if(!blob.size||blob.size>20*1024*1024)throw Error('Fichier vide ou supérieur à 20 Mio.');
 const original=new Uint8Array(await blob.arrayBuffer());
 // Preserve a valid PCM WAV unchanged: the server remains the final validator.
 if(original.length>=44&&new TextDecoder().decode(original.subarray(0,4))==='RIFF'&&new TextDecoder().decode(original.subarray(8,12))==='WAVE'){
  if(original.length>LIMIT)throw Error('WAV supérieur à la limite serveur de 5 Mio.');return {bytes:original,original};
 }
 const AC=globalThis.AudioContext||globalThis.webkitAudioContext;if(!AC)throw Error('Décodage audio indisponible dans ce navigateur.');
 const ctx=new AC();let decoded;try{decoded=await ctx.decodeAudioData(original.buffer.slice(0));}finally{await ctx.close();}
 const count=Math.floor(decoded.duration*16000);if(!count||44+count*2>LIMIT)throw Error('Durée trop longue pour ce profil local (environ 163 secondes).');
 const offline=new OfflineAudioContext(1,count,16000),source=offline.createBufferSource();source.buffer=decoded;source.connect(offline.destination);source.start();const rendered=await offline.startRendering();return {bytes:pcmWav(rendered.getChannelData(0)),original};
}
export async function digest(bytes){return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),b=>b.toString(16).padStart(2,'0')).join('');}
export async function transferAudio(rpc,draft,onProgress=()=>{},alive=()=>true,original=null){
 const bytes=unbase64(draft.content),check=()=>{if(!alive())throw Error('Transfert suspendu ; brouillon conservé.');};
 check();const begin=await rpc('audio_begin',{id:draft.meeting,request_id:draft.request,consentVersion:draft.consentVersion,filename:draft.filename,size:bytes.length,sha256:await digest(bytes)});check();
 if(original)await transferOriginal(rpc,draft.meeting,begin.audio,original.filename,original.bytes,alive);check();
 const progress=await rpc('audio_progress',{id:draft.meeting,audio:begin.audio});check();const done=new Set(progress.parts);
 for(let part=0;part<Math.ceil(bytes.length/PART);part++){
  check();if(!done.has(part))await rpc('audio_part',{id:draft.meeting,audio:begin.audio,part,content:base64(bytes.subarray(part*PART,(part+1)*PART))});
  check();onProgress(Math.min(bytes.length,(part+1)*PART),bytes.length);
 }
 const result=await rpc('audio_complete',{id:draft.meeting,audio:begin.audio});check();return result;
}

// Join individually durable PCM parts into one bounded, immutable server segment.
export function joinPCM(parts){const count=parts.reduce((n,p)=>n+p.length,0);if(44+count*2>LIMIT)throw Error('Segment PCM hors limite.');const samples=new Float32Array(count);let at=0;for(const part of parts){samples.set(part,at);at+=part.length;}return pcmWav(samples);}
export function pcmSamples(bytes){const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);if(bytes.length%4)throw Error('Bloc PCM tronqué.');const result=new Float32Array(bytes.length/4);for(let i=0;i<result.length;i++)result[i]=view.getFloat32(i*4,true);return result;}

export async function normalizeSegments(blob){
 if(!blob.size||blob.size>20*1024*1024)throw Error('Import limité à 20 Mio.');
 const raw=new Uint8Array(await blob.arrayBuffer()),view=new DataView(raw.buffer);
 if(raw.length>=44&&new TextDecoder().decode(raw.subarray(0,4))==='RIFF'&&new TextDecoder().decode(raw.subarray(8,12))==='WAVE'){
  if(view.getUint32(4,true)!==raw.length-8||new TextDecoder().decode(raw.subarray(12,16))!=='fmt '||view.getUint32(16,true)!==16||view.getUint16(20,true)!==1||new TextDecoder().decode(raw.subarray(36,40))!=='data'||view.getUint32(40,true)!==raw.length-44)throw Error('Import WAV PCM sans métadonnées requis.');
  const align=view.getUint16(32,true),rate=view.getUint32(28,true);if(!align||!rate||(raw.length-44)%align)throw Error('WAV invalide.');
  const size=Math.floor(Math.min(LIMIT-44,120*rate)/align)*align;if(!size)throw Error('WAV invalide.');const result=[];
  for(let at=44;at<raw.length;at+=size){const count=Math.min(size,raw.length-at),bytes=new Uint8Array(44+count);bytes.set(raw.subarray(0,44));bytes.set(raw.subarray(at,at+count),44);const v=new DataView(bytes.buffer);v.setUint32(4,bytes.length-8,true);v.setUint32(40,count,true);result.push({bytes,durationMs:count*1000/rate});}return result;
 }
 if(raw.length>=12&&new TextDecoder().decode(raw.subarray(0,4))==='FORM')return decodeAIFF(raw);
 const AC=globalThis.AudioContext||globalThis.webkitAudioContext;if(!AC)throw Error('Décodage indisponible ; importez un WAV PCM.');const ctx=new AC();let decoded;
 try{decoded=await ctx.decodeAudioData(raw.buffer);}catch{throw Error('Format non décodable dans ce navigateur ; original conservé, importez un WAV PCM.');}finally{await ctx.close();}
 if(decoded.duration>28800||decoded.length*decoded.numberOfChannels*4>256*1024*1024)throw Error('Import décodé hors limite ; utilisez des segments WAV.');
 const result=[];for(let offset=0;offset<decoded.duration;offset+=120){const count=Math.floor(Math.min(120,decoded.duration-offset)*16000);if(!count)continue;const offline=new OfflineAudioContext(1,count,16000),source=offline.createBufferSource();source.buffer=decoded;source.connect(offline.destination);source.start(0,offset);const rendered=await offline.startRendering();result.push({bytes:pcmWav(rendered.getChannelData(0)),durationMs:count/16});}return result;
}
export async function transferOriginal(rpc,id,audio,filename,bytes,alive=()=>true){
 const check=()=>{if(!alive())throw Error('Transfert suspendu ; original conservé.');};check();
 await rpc('audio_source_begin',{id,audio,filename:filename.replace(/[\x00-\x1f\x7f/\\]/g,'_').slice(0,180)||'original',size:bytes.length,sha256:await digest(bytes)});check();
 const progress=await rpc('audio_source_progress',{id,audio});const done=new Set(progress.parts);
 for(let part=0;part<Math.ceil(bytes.length/PART);part++){check();if(!done.has(part))await rpc('audio_source_part',{id,audio,part,content:base64(bytes.subarray(part*PART,(part+1)*PART))});}
 check();return rpc('audio_source_complete',{id,audio});
}

// AIFF PCM16 is decoded directly, without depending on an optional OS codec.
export function decodeAIFF(raw){
 const v=new DataView(raw.buffer,raw.byteOffset,raw.byteLength),text=(a,b)=>new TextDecoder().decode(raw.subarray(a,b));
 if(raw.length<12||text(0,4)!=='FORM'||text(8,12)!=='AIFF'||v.getUint32(4)!==raw.length-8)throw Error('AIFF PCM 16 bits invalide.');
 let comm=null,sound=null;for(let at=12;at<raw.length;){if(at+8>raw.length)throw Error('AIFF tronqué.');const kind=text(at,at+4),size=v.getUint32(at+4),start=at+8,end=start+size;if(end>raw.length)throw Error('AIFF tronqué.');
  if(kind==='COMM'){if(comm||size!==18)throw Error('Profil AIFF non accepté.');const exponent=v.getUint16(start+8),mantissa=v.getUint32(start+10)*4294967296+v.getUint32(start+14);comm={channels:v.getUint16(start),frames:v.getUint32(start+2),bits:v.getUint16(start+6),rate:mantissa*Math.pow(2,exponent-16383-63)};}
  if(kind==='SSND'){if(sound||size<8)throw Error('AIFF invalide.');const offset=v.getUint32(start);if(v.getUint32(start+4)!==0||offset>size-8)throw Error('Profil AIFF non accepté.');sound={start:start+8+offset,end};}at=end+(size%2);
 }
 if(!comm||!sound||![1,2].includes(comm.channels)||comm.bits!==16||![8000,16000,22050,24000,44100,48000].includes(comm.rate)||!comm.frames||sound.start+comm.frames*comm.channels*2!==sound.end)throw Error('AIFF PCM mono/stéréo 16 bits requis.');
 const count=Math.floor(comm.frames*16000/comm.rate),result=[];const sample=index=>{let value=0;for(let channel=0;channel<comm.channels;channel++)value+=v.getInt16(sound.start+(Math.min(index,comm.frames-1)*comm.channels+channel)*2)/32768/comm.channels;return value;};
 for(let at=0;at<count;at+=1920000){const n=Math.min(1920000,count-at),samples=new Float32Array(n);for(let i=0;i<n;i++){const position=(at+i)*comm.rate/16000,index=Math.floor(position),fraction=position-index;samples[i]=sample(index)*(1-fraction)+sample(index+1)*fraction;}result.push({bytes:pcmWav(samples),durationMs:n/16});}return result;
}
