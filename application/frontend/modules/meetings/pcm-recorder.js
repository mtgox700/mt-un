// PCM recording uses the actual microphone stream, independent of container encoders.
// The processor emits at most one second of mono 16 kHz samples per message.
export const PROCESSOR = `class PCM extends AudioWorkletProcessor {
 constructor(){super();this.active=false;this.sum=0;this.weight=0;this.phase=0;this.buffer=new Float32Array(16000);this.used=0;
 this.port.onmessage=({data})=>{if(data==='start'||data==='resume')this.active=true;else {this.active=false;this.flush();if(data==='stop')this.port.postMessage({stopped:true});}};}
 flush(){if(this.used){const samples=this.buffer.slice(0,this.used);this.port.postMessage({samples},[samples.buffer]);this.used=0;}}
 process(inputs,outputs){for(const output of outputs)for(const channel of output)channel.fill(0);if(!this.active)return true;
 const channels=inputs[0];if(!channels?.length)return true;
 for(let i=0;i<channels[0].length;i++){let n=0;for(const c of channels)n+=c[i]/channels.length;this.sum+=n;this.weight++;this.phase+=16000;
 if(this.phase>=sampleRate){this.phase-=sampleRate;this.buffer[this.used++]=this.sum/this.weight;this.sum=0;this.weight=0;if(this.used===16000)this.flush();}}
 return true;}}
registerProcessor('uniion-pcm',PCM);`;
export async function createPCMRecorder(stream){
 const AC=globalThis.AudioContext||globalThis.webkitAudioContext;
 if(!AC||!globalThis.AudioWorkletNode)throw Error('Capture PCM indisponible dans ce navigateur.');
 const context=new AC(),url=URL.createObjectURL(new Blob([PROCESSOR],{type:'text/javascript'}));
 try{await context.audioWorklet.addModule(url);await context.resume();if(context.state!=='running')throw Error('Le navigateur a suspendu le moteur audio.');}
 catch(e){await context.close();throw e;}finally{URL.revokeObjectURL(url);}
 const source=context.createMediaStreamSource(stream),node=new AudioWorkletNode(context,'uniion-pcm');source.connect(node);node.connect(context.destination);
 let deadline;const recorder={state:'inactive',mimeType:'audio/wav',pcm:true,
 start(){this.state='recording';node.port.postMessage('start');},
 pause(){this.state='paused';node.port.postMessage('pause');},
 resume(){this.state='recording';node.port.postMessage('resume');},
 stop(){if(this.state==='inactive')return;this.state='inactive';node.port.postMessage('stop');deadline=setTimeout(()=>{cleanup();this.onerror?.({error:Error('Arrêt audio non confirmé ; segments reçus conservés.')});this.onstop?.();},3000);}};
 const cleanup=()=>{clearTimeout(deadline);source.disconnect();node.disconnect();node.port.close();context.close().catch(()=>{});};
 node.port.onmessage=({data})=>{if(data.samples)recorder.ondataavailable?.({samples:data.samples});if(data.stopped){cleanup();recorder.onstop?.();}};
 node.onprocessorerror=()=>{cleanup();recorder.state='inactive';recorder.onerror?.({error:Error('Processeur audio interrompu.')});recorder.onstop?.();};
 return recorder;
}
