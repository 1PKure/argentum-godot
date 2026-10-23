import {verifyPublicWebSocket} from './verify-public.mjs';
import {spawn} from 'node:child_process';
import {createGateway} from './gateway.mjs';
import {SupabaseStore} from './store.mjs';
const integer=(value,fallback)=>value?Number(value):fallback;
try{
  const gamePort=integer(process.env.AO_GAME_PORT,7777);
  const gateway=await createGateway({store:new SupabaseStore(process.env.SUPABASE_URL,process.env.AO_STORE_KEY||process.env.SUPABASE_SERVICE_ROLE_KEY,!!process.env.AO_STORE_KEY),port:integer(process.env.PORT,10000),gamePort,internalPort:integer(process.env.AO_INTERNAL_PORT,7778),pilotKey:process.env.AO_PILOT_KEY,capacity:integer(process.env.AO_CAPACITY,8),publicAccess:process.env.AO_PUBLIC_ACCESS==='true',origins:(process.env.AO_ALLOWED_ORIGINS||'').split(',').filter(Boolean)});
  const game=spawn(process.env.GODOT_BIN||'godot',['--headless','--path',process.env.AO_PROJECT_PATH||'/app','--','--server',`--port=${gamePort}`],{env:{...process.env,AO_STORE_URL:gateway.internalURL,AO_STORE_TOKEN:gateway.token},stdio:['ignore','pipe','pipe']});
  let outputBuffer='',started=false;
  game.stdout.on('data',data=>{
    process.stdout.write(data);outputBuffer=(outputBuffer+data.toString()).slice(-2048);
    if(!started && outputBuffer.includes('Argentum server ready.')){
      started=true;gateway.setReady(true);
      if(process.env.AO_VERIFY_PUBLIC_WSS==='true')verifyPublicWebSocket(process.env.RENDER_EXTERNAL_HOSTNAME,process.env.AO_PILOT_KEY);
    }
  });
  game.stderr.on('data',data=>process.stderr.write(data));
  game.on('error',async()=>{await gateway.close();process.exit(1);});
  game.on('exit',async code=>{await gateway.close();process.exit(code||1);});
  for(const signal of ['SIGTERM','SIGINT'])process.on(signal,()=>{gateway.setReady(false);game.kill(signal);setTimeout(()=>process.exit(0),9000).unref();});
}catch{console.error('Dedicated startup failed: check storage, pilot key and port configuration.');process.exit(1);}
