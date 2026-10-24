import test from 'node:test';
import assert from 'node:assert/strict';
import net from 'node:net';
import {createGateway} from '../gateway/gateway.mjs';
import {publicSnapshot,SupabaseStore} from '../gateway/store.mjs';
const ticket='t'.repeat(32);
const snapshot=revision=>({schema:1,revision,updated_at:1,total_players:0,entries:[{rank:1,nickname:'milusita',points:9999999999,wins:0,pvp_wins:0,bot_wins:0,honorary:true,secret_hash:'never-leave'}]});
const read=async(url,options)=>{const r=await fetch(url,options);return [r.status,await r.json()];};
test('Gateway isolates private state, gates pilot access, waits for persistence and exposes only public fields',async()=>{
 let saved={payload:null,public_snapshot:null};let release;
 const store={load:async()=>saved,commit:data=>new Promise(resolve=>{release=()=>{saved={status:'ok',payload:data.payload,public_snapshot:data.public_snapshot};resolve(saved);};})};
 const gateway=await createGateway({store,port:0,internalPort:0,pilotKey:ticket,origins:['https://private.example']});
 const base=`http://127.0.0.1:${gateway.port}`;
 try{
  assert.equal((await read(base+'/healthz'))[0],503);gateway.setReady(true);assert.equal((await read(base+'/healthz'))[0],200);
  assert.equal((await read(base+'/api/ranking'))[0],403);
  assert.equal((await read(base+'/internal/state'))[0],404);
  assert.equal((await read(gateway.internalURL+'/state'))[0],403);
  const headers={Authorization:'Bearer '+gateway.token,'Content-Type':'application/json'};
  const pending=read(gateway.internalURL+'/commit',{method:'POST',headers,body:JSON.stringify({expected_revision:0,payload:{revision:1},public_snapshot:snapshot(1),operation_id:'a'.repeat(32)})});
  while(!release)await new Promise(r=>setTimeout(r,5));
  assert.equal((await read(base+'/api/ranking?ticket='+ticket))[0],503);
  release();assert.equal((await pending)[0],200);
  const [code,value]=await read(base+'/api/ranking?ticket='+ticket);assert.equal(code,200);assert.equal(value.entries[0].nickname,'milusita');assert.equal(JSON.stringify(value).includes('secret_hash'),false);
  assert.equal((await read(gateway.internalURL+'/state',{headers}))[1].payload.revision,1);
  assert.equal((await read(gateway.internalURL+'/commit',{method:'POST',headers,body:'{}'}))[0],503);
 }finally{await gateway.close();}
});
test('Actual upgrade preserves protocol traffic, strips pilot ticket and rejects wrong origin',async()=>{
 const received=[];
 const upstream=net.createServer(socket=>{socket.once('data',data=>{received.push(data.toString());socket.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n');});});
 await new Promise(resolve=>upstream.listen(0,'127.0.0.1',resolve));
 const gateway=await createGateway({store:{load:async()=>({payload:null,public_snapshot:null})},port:0,internalPort:0,gamePort:upstream.address().port,pilotKey:ticket,origins:['https://private.example']});gateway.setReady(true);
 async function upgrade(key,origin){return new Promise((resolve,reject)=>{const socket=net.connect(gateway.port,'127.0.0.1',()=>socket.write(`GET /game?ticket=${key} HTTP/1.1\r\nHost: local\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nOrigin: ${origin}\r\n\r\n`));socket.once('data',data=>{socket.destroy();resolve(data.toString());});socket.once('error',reject);});}
 try{
  assert.match(await upgrade('bad','https://private.example'),/403/);
  assert.match(await upgrade(ticket,'https://evil.example'),/403/);
  assert.match(await upgrade(ticket,'https://private.example'),/101/);
  assert.match(received[0],/^GET \/ HTTP/);assert.equal(received[0].includes(ticket),false);
 }finally{await gateway.close();await new Promise(resolve=>upstream.close(resolve));}
});
test('Storage setup rejects insecure endpoints and never admits invalid public counters',()=>{
 assert.throws(()=>new SupabaseStore('http://unsafe.example','a'.repeat(40)));
 assert.throws(()=>publicSnapshot({...snapshot(1),entries:[{...snapshot(1).entries[0],points:Infinity}]}));
});

test('Public beta needs no invitation and only grants browser CORS to its exact origin',async()=>{
 const origin='https://ao-mini.pulidomatias.workers.dev';
 const gateway=await createGateway({store:{load:async()=>({public_snapshot:snapshot(12)})},port:0,internalPort:0,publicAccess:true,origins:[origin]});
 const base=`http://127.0.0.1:${gateway.port}`;
 try{
  const response=await fetch(base+'/api/ranking',{headers:{Origin:origin}});
  assert.equal(response.status,200);
  assert.equal(response.headers.get('access-control-allow-origin'),origin);
  const value=await response.json();
  assert.equal(value.entries[0].nickname,'milusita');
  assert.equal(JSON.stringify(value).includes('secret_hash'),false);
  const foreign=await fetch(base+'/api/ranking',{headers:{Origin:origin+'.invalid.example'}});
  assert.equal(foreign.headers.get('access-control-allow-origin'),null);
  assert.equal((await read(base+'/internal/state'))[0],404);
  assert.equal((await read(gateway.internalURL+'/state'))[0],403);
  gateway.setReady(true);
  const denied=await new Promise((resolve,reject)=>{
   const socket=net.connect(gateway.port,'127.0.0.1',()=>socket.write('GET /game HTTP/1.1\r\nHost: local\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nOrigin: https://invalid.example\r\n\r\n'));
   socket.once('data',data=>{socket.destroy();resolve(data.toString());});socket.once('error',reject);
  });
  assert.match(denied,/403 Forbidden/);
 }finally{await gateway.close();}
});
