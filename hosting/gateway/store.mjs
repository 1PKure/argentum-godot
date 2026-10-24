// This module runs only on the dedicated host. Never bundle it with the web client.
export class SupabaseStore {
  constructor(url,key,edge=false){
    const parsed=new URL(url);
    if(parsed.protocol!=='https:' || parsed.username || parsed.password || parsed.search || parsed.hash)throw Error('SUPABASE_URL must be an HTTPS project origin');
    if(!key || key.length<32)throw Error('A server-side Supabase secret is required');
    this.url=parsed.origin;this.key=key;this.edge=edge;
  }
  async rpc(name,args={}){
    const headers={'Content-Type':'application/json',apikey:this.key};
    if(this.edge)headers.Authorization='Bearer '+this.key;
    else if(this.key.startsWith('eyJ'))headers.Authorization='Bearer '+this.key;
    const response=await fetch(this.url+(this.edge?'/functions/v1/ao-ranking-store':'/rest/v1/rpc/'+name),{method:'POST',headers,body:JSON.stringify(this.edge?{operation:name,args}:args),signal:AbortSignal.timeout(7000),redirect:'error'});
    if(!response.ok)throw Error('Persistent storage HTTP '+response.status);
    return response.json();
  }
  load(){return this.rpc('ao_store_load');}
  commit(data){return this.rpc('ao_store_commit',{p_expected:data.expected_revision,p_payload:data.payload,p_public:data.public_snapshot,p_operation:data.operation_id});}
}
export function publicSnapshot(value){
  if(!value || value.schema!==1 || !Array.isArray(value.entries) || value.entries.length>51)throw Error('Invalid public ranking');
  const entries=value.entries.map(row=>{
    if(typeof row.nickname!=='string' || row.nickname.length>40)throw Error('Invalid nickname');
    const out={nickname:row.nickname,honorary:row.honorary===true};
    for(const key of ['rank','points','wins','pvp_wins','bot_wins']){
      if(!Number.isSafeInteger(row[key]) || row[key]<0)throw Error('Invalid ranking counter');
      out[key]=row[key];
    }
    // Deliberate whitelist: neither identities nor private fields leave the host.
    return out;
  });
  return {schema:1,revision:value.revision,updated_at:value.updated_at,refresh_after_seconds:30,total_players:value.total_players,entries};
}
