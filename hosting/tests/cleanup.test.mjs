import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,readFile,readdir,stat,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {prepareCleanup,cleanup} from '../gateway/clean-ranking.mjs';

function state(){return {status:'ok',payload:{schema:1,revision:19,updated_at:1,players:{keep:{nickname:'1kurep',secret_hash:'unchanged',pvp_wins:0,bot_wins:2},other:{nickname:'1kurelol',secret_hash:'private',pvp_wins:1,bot_wins:0},qa:{nickname:'QA_carga',secret_hash:'private',pvp_wins:0,bot_wins:0}},awards:{a:{identity_id:'keep',mode:'bot'},b:{identity_id:'keep',mode:'bot'},c:{identity_id:'other',mode:'pvp'}}},public_snapshot:{schema:1,revision:19,total_players:3,entries:[{nickname:'milusita',honorary:true,points:9999999999,rank:1,wins:0,pvp_wins:0,bot_wins:0},{id:'keep',nickname:'1kurep',honorary:false,points:200,rank:2,wins:2,pvp_wins:0,bot_wins:2},{id:'other',nickname:'1kurelol',points:100,rank:3,wins:1,pvp_wins:1,bot_wins:0}]}};}
test('Cleanup preserves identity, points and award history, drops other histories and is repeatable',()=>{
 const original=state(),before=structuredClone(original),next=prepareCleanup(original,'1kurep',100);
 assert.deepEqual(original,before);
 assert.deepEqual(next.payload.players,{keep:original.payload.players.keep});
 assert.deepEqual(Object.keys(next.payload.awards),['a','b']);
 assert.equal(next.payload.revision,20);
 assert.equal(next.public_snapshot.total_players,1);
 assert.deepEqual(next.public_snapshot.entries.map(v=>[v.nickname,v.points]),[['milusita',9999999999],['1kurep',200]]);
 assert.equal(prepareCleanup({status:'ok',...next},'1kurep'),null);
 const bad=state();bad.payload.players.keep.bot_wins=3;
 assert.throws(()=>prepareCleanup(bad,'1kurep'),/disagree/);
 assert.throws(()=>prepareCleanup(state(),'missing'),/exactly one/);
});
test('Durable cleanup writes an exclusive private backup before CAS and verifies storage again',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'ao-ranking-clean-'));
 const prior=state();let current=structuredClone(prior),commits=0;
 const store={load:async()=>structuredClone(current),commit:async data=>{
  const files=await readdir(dir);assert.equal(files.length,1);
  assert.deepEqual(JSON.parse(await readFile(join(dir,files[0]),'utf8')),prior);
  assert.equal((await stat(join(dir,files[0]))).mode&0o777,0o600);
  assert.equal(data.expected_revision,19);assert.match(data.operation_id,/^[a-f0-9]{32}$/);
  commits++;current={status:'ok',payload:data.payload,public_snapshot:data.public_snapshot};return current;
 }};
 try{
  await cleanup(store,{keepName:'1kurep',backupDir:dir});
  await cleanup(store,{keepName:'1kurep',backupDir:dir});
  assert.equal(commits,1);
 }finally{await rm(dir,{recursive:true,force:true});}
});

test('A storage revision conflict stops cleanup and leaves a recovery copy',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'ao-ranking-conflict-'));
 const prior=state();let commits=0;
 const store={load:async()=>structuredClone(prior),commit:async()=>{commits++;return {status:'conflict'};}};
 try{
  await assert.rejects(cleanup(store,{keepName:'1kurep',backupDir:dir}),/Concurrent change/);
  assert.equal(commits,1);
  const files=await readdir(dir);assert.equal(files.length,1);
  assert.deepEqual(JSON.parse(await readFile(join(dir,files[0]),'utf8')),prior);
 }finally{await rm(dir,{recursive:true,force:true});}
});
