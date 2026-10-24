// Administrative maintenance only. Never imported by the game or web client.
import {writeFile} from 'node:fs/promises';
import {randomBytes} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {isDeepStrictEqual} from 'node:util';
import {SupabaseStore,publicSnapshot} from './store.mjs';

export function prepareCleanup(state,keepName,now=Math.floor(Date.now()/1000)){
 const p=state?.payload,s=state?.public_snapshot;
 if(state?.status!=='ok' || p?.schema!==1 || s?.schema!==1 || !Number.isSafeInteger(p.revision) || p.revision!==s.revision || !p.players || !p.awards || !Array.isArray(s.entries))throw Error('Invalid ranking state; nothing changed');
 const matches=Object.entries(p.players).filter(([,v])=>v.nickname===keepName);
 if(matches.length!==1)throw Error('Expected exactly one matching keeper; nothing changed');
 const [id,player]=matches[0];
 const honor=s.entries.filter(v=>v.honorary===true && v.nickname==='milusita');
 const row=s.entries.filter(v=>v.id===id && v.nickname===keepName);
 if(honor.length!==1 || honor[0].points!==9999999999 || row.length!==1)throw Error('Could not verify honorary and keeper rows; nothing changed');
 const awards=Object.fromEntries(Object.entries(p.awards).filter(([,v])=>v.identity_id===id));
 const pvp=Object.values(awards).filter(v=>v.mode==='pvp').length;
 const bot=Object.values(awards).filter(v=>v.mode==='bot').length;
 if(pvp!==player.pvp_wins || bot!==player.bot_wins || row[0].points!==(pvp+bot)*100 || row[0].wins!==pvp+bot || row[0].pvp_wins!==pvp || row[0].bot_wins!==bot)throw Error('Keeper history and counters disagree; nothing changed');
 const removed=Object.entries(p.players).filter(([key])=>key!==id).map(([,v])=>v.nickname);
 if(!removed.length && s.entries.length===2)return null;
 const revision=p.revision+1;
 const payload={...p,revision,updated_at:now,players:{[id]:structuredClone(player)},awards:structuredClone(awards)};
 const public_snapshot={...s,revision,updated_at:now,total_players:1,entries:[{...honor[0],rank:1},{...row[0],rank:2}]};
 publicSnapshot(public_snapshot);
 return {payload,public_snapshot,removed};
}

export async function cleanup(store,{keepName,backupDir}){
 const state=await store.load();
 const next=prepareCleanup(state,keepName);
 if(!next){console.log('Ranking already clean; no changes needed.');return;}
 const operation_id=randomBytes(16).toString('hex');
 const backup=`${backupDir}/before-cleanup-${Date.now()}-${operation_id}.json`;
 await writeFile(backup,JSON.stringify(state),{flag:'wx',mode:0o600});
 console.log('Private backup saved before any change.');
 const result=await store.commit({expected_revision:state.payload.revision,payload:next.payload,public_snapshot:next.public_snapshot,operation_id});
 if(result.status!=='ok')throw Error('Concurrent change detected; cleanup was not confirmed');
 const verified=await store.load();
 if(!isDeepStrictEqual(verified.payload,next.payload) || !isDeepStrictEqual(verified.public_snapshot,next.public_snapshot))throw Error('Cleanup verification failed; inspect the private backup');
 const keeper=verified.public_snapshot.entries.find(v=>v.nickname===keepName);
 console.log(`Ranking verified: milusita + ${keepName}; ${keeper.points} points; ${next.removed.length} other profiles removed.`);
}

if(process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href){
 const name=process.argv.find(v=>v.startsWith('--keep-name='))?.slice(12);
 const backup=process.argv.find(v=>v.startsWith('--backup-dir='))?.slice(13);
 try{
  if(name!=='1kurep' || backup!=='/backup')throw Error('Use the reviewed keeper and private backup mount');
  const store=new SupabaseStore(process.env.SUPABASE_URL,process.env.AO_STORE_KEY,true);
  await cleanup(store,{keepName:name,backupDir:backup});
 }catch(error){console.error('Ranking maintenance stopped:',error.message);process.exitCode=1;}
}
