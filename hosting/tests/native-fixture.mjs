// Test-only PostgreSQL API fixture. Production main.mjs always uses SupabaseStore.
import {PGlite} from '@electric-sql/pglite';
import {readFileSync,writeFileSync,existsSync,mkdirSync} from 'node:fs';
import {createGateway} from '../gateway/gateway.mjs';
import {spawn} from 'node:child_process';
const directory=process.argv[2];mkdirSync(directory,{recursive:true});
const db=new PGlite(directory+'/postgres');
if(!(await db.query("select to_regclass('public.ao_ranking_state') as name")).rows[0].name){
 await db.exec('create role anon;create role authenticated;create role service_role;');
 await db.exec(readFileSync(new URL('../sql/001_ranking_store.sql',import.meta.url),'utf8'));
}
const control=directory+'/control.txt';writeFileSync(control,'');
const store={
 load:async()=>(await db.query('select public.ao_store_load() as value')).rows[0].value,
 commit:async data=>{
  const mode=readFileSync(control,'utf8');writeFileSync(control,'');
  if(mode==='fail')throw Error('Injected storage failure');
  if(mode==='delay')await new Promise(resolve=>setTimeout(resolve,350));
  const value=(await db.query('select public.ao_store_commit($1,$2::jsonb,$3::jsonb,$4) as value',[data.expected_revision,JSON.stringify(data.payload),JSON.stringify(data.public_snapshot),data.operation_id])).rows[0].value;
  if(mode==='lost')throw Error('Injected lost acknowledgment');
  return value;
 }
};
const gamePort=Number(process.env.TEST_GAME_PORT||7777);
const gateway=await createGateway({store,port:0,internalPort:0,gamePort,pilotKey:'local-test-ticket-12345678901234567890',origins:[]});
let child;
if(process.env.TEST_GODOT){
 child=spawn(process.env.TEST_GODOT,['--headless','--path',process.cwd(),'--','--server','--port='+gamePort],{env:{...process.env,AO_STORE_URL:gateway.internalURL,AO_STORE_TOKEN:gateway.token},stdio:['ignore','pipe','pipe']});
 child.stdout.on('data',data=>{process.stdout.write(data);if(data.toString().includes('Argentum server ready.'))gateway.setReady(true);});
 child.stderr.on('data',data=>process.stderr.write(data));
}
writeFileSync(directory+'/fixture.json',JSON.stringify({url:gateway.internalURL,token:gateway.token,port:gateway.port,control}));
console.log('Fixture ready');
process.on('SIGTERM',async()=>{child?.kill();await gateway.close();await db.close();process.exit(0);});
