// Optional bounded deployment check from the host itself. No URLs or tickets in logs.
export function verifyPublicWebSocket(host,ticket){
  if(!/^[a-z0-9-]+\.onrender\.com$/.test(host||''))return;
  let attempts=0;
  const attempt=()=>{
    attempts++;
    const socket=new WebSocket(`wss://${host}/game?ticket=${encodeURIComponent(ticket||'')}`);
    let opened=false;
    const timer=setTimeout(()=>socket.close(),12000);timer.unref();
    socket.addEventListener('open',()=>{opened=true;console.log('Public WSS deployment check passed.');socket.close();});
    socket.addEventListener('error',event=>{console.log('Public WSS check error:',String(event.message||'network error').replaceAll(ticket||'__none__','[redacted]').replace(/wss?:\/\/\S+/g,'[url]').slice(0,160));});
    socket.addEventListener('close',()=>{
      clearTimeout(timer);
      if(!opened && attempts<6)setTimeout(attempt,10000).unref();
      else if(!opened)console.error('Public WSS deployment check failed.');
    });
  };
  setTimeout(attempt,15000).unref();
}
