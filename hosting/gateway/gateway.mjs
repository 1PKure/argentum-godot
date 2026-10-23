import http from 'node:http';
import net from 'node:net';
import {randomBytes,timingSafeEqual} from 'node:crypto';
import {publicSnapshot} from './store.mjs';
const equal=(a,b)=>typeof a==='string' && Buffer.byteLength(a)===Buffer.byteLength(b) && timingSafeEqual(Buffer.from(a),Buffer.from(b));
async function jsonBody(req){
  let size=0;const chunks=[];
  for await(const chunk of req){size+=chunk.length;if(size>8*1024*1024)throw Error('Body too large');chunks.push(chunk);}
  return JSON.parse(Buffer.concat(chunks).toString());
}
function reply(res,code,data,headers={}){res.writeHead(code,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store',...headers});res.end(JSON.stringify(data));}
export async function createGateway({store,port=10000,gamePort=7777,internalPort=7778,pilotKey,origins=[],capacity=8,publicAccess=false}){
  if(!publicAccess && (!pilotKey || pilotKey.length<24))throw Error('AO_PILOT_KEY must be configured before the pilot opens');
  if(!Number.isInteger(capacity) || capacity<2 || capacity>8)throw Error('Pilot capacity must be2–8');
  let persisted=await store.load();
  let ready=false,busy=false;
  const token=randomBytes(32).toString('hex');
  const sockets=new Set();
  const originHeaders=req=>origins.includes(req.headers.origin)?{'Access-Control-Allow-Origin':req.headers.origin,Vary:'Origin'}:{};
  const server=http.createServer((req,res)=>{
    let url;try{url=new URL(req.url,'http://localhost');}catch{return reply(res,400,{error:'Invalid URL'});}
    const path=url.pathname;
    if(req.method==='GET' && path==='/healthz')return reply(res,ready?200:503,{ready,capacity});
    if(req.method==='GET' && path==='/api/ranking'){
      if(!publicAccess && !equal(url.searchParams.get('ticket'),pilotKey))return reply(res,403,{error:'Forbidden'});
      if(!persisted.public_snapshot)return reply(res,503,{error:'Ranking not initialized'},originHeaders(req));
      return reply(res,200,publicSnapshot(persisted.public_snapshot),originHeaders(req));
    }
    reply(res,404,{error:'Not found'});
  });
  server.requestTimeout=10000;server.headersTimeout=10000;
  server.on('upgrade',(req,socket,head)=>{
    let url;try{url=new URL(req.url,'http://localhost');}catch{socket.destroy();return;}
    const reject=(code,message)=>{if(process.env.AO_DIAGNOSTICS==='true')console.log('Gateway upgrade rejected:',code,message);socket.end(`HTTP/1.1 ${code} ${message}\r\nConnection: close\r\n\r\n`);};
    if(req.method!=='GET' || url.pathname!=='/game' || (!publicAccess && !equal(url.searchParams.get('ticket'),pilotKey)))return reject(403,'Forbidden');
    if(req.headers.origin && !origins.includes(req.headers.origin))return reject(403,'Forbidden');
    if(!ready)return reject(503,'Unavailable');
    if(sockets.size>=capacity)return reject(503,'Full');
    const upstream=net.connect({host:'127.0.0.1',port:gamePort});
    sockets.add(socket);
    const cleanup=()=>{sockets.delete(socket);socket.destroy();upstream.destroy();};
    socket.on('error',cleanup);upstream.on('error',cleanup);socket.on('close',cleanup);upstream.on('close',()=>socket.end());
    upstream.on('connect',()=>{
      if(process.env.AO_DIAGNOSTICS==='true')console.log('Gateway upgrade accepted; header names:',Object.keys(req.headers).join(','));
      // The pilot ticket stops here; it is not forwarded or logged by Godot.
      const headers=Object.entries(req.headers).filter(([name])=>!['host','authorization','cookie'].includes(name.toLowerCase())).map(([name,value])=>`${name}: ${value}`).join('\r\n');
      upstream.write(`GET / HTTP/1.1\r\nHost: 127.0.0.1:${gamePort}\r\n${headers}\r\n\r\n`);
      if(head.length)upstream.write(head);
      socket.pipe(upstream).pipe(socket);
    });
  });
  const internal=http.createServer(async(req,res)=>{
    if(!equal(req.headers.authorization,'Bearer '+token))return reply(res,403,{error:'Forbidden'});
    try{
      if(req.method==='GET' && req.url==='/state')return reply(res,200,persisted);
      if(req.method!=='POST' || req.url!=='/commit')return reply(res,404,{error:'Not found'});
      if(busy)return reply(res,503,{error:'Commit busy'});
      busy=true;
      try{
        const data=await jsonBody(req);
        if(!Number.isSafeInteger(data.expected_revision) || !data.payload || data.payload.revision!==data.expected_revision+1 || typeof data.operation_id!=='string' || !/^[a-f0-9]{32}$/.test(data.operation_id))throw Error('Invalid commit');
        publicSnapshot(data.public_snapshot);
        const result=await store.commit(data);
        if(result.status==='conflict'){persisted=result;return reply(res,409,result);}
        if(result.status!=='ok' || !result.payload)throw Error('Storage rejected commit');
        persisted=result;
        reply(res,200,result);
      }finally{busy=false;}
    }catch{reply(res,503,{error:'Persistent storage unavailable'});}
  });
  internal.requestTimeout=10000;internal.headersTimeout=10000;
  await new Promise((resolve,reject)=>{internal.once('error',reject);internal.listen(internalPort,'127.0.0.1',resolve);});
  await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(port,'0.0.0.0',resolve);});
  return {token,internalURL:`http://127.0.0.1:${internal.address().port}`,port:server.address().port,
    setReady(value){ready=!!value;},
    async close(){ready=false;for(const socket of sockets)socket.destroy();await Promise.all([new Promise(resolve=>server.close(resolve)),new Promise(resolve=>internal.close(resolve))]);}};
}
