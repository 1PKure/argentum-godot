import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PGlite} from '@electric-sql/pglite';
const payload=(revision,players={})=>({schema:1,revision,updated_at:1,players,awards:{}});
const pub=revision=>({schema:1,revision,updated_at:1,total_players:0,entries:[]});
test('Real PostgreSQL functions enforce durable revisions, idempotence, previous state and grants',async()=>{
 const db=new PGlite();
 try{
  await db.exec('create role anon;create role authenticated;create role service_role;');
  await db.exec(readFileSync(new URL('../sql/001_ranking_store.sql',import.meta.url),'utf8'));
  const load=async()=>(await db.query('select public.ao_store_load() as value')).rows[0].value;
  const commit=async(expected,value,operation)=>(await db.query('select public.ao_store_commit($1,$2::jsonb,$3::jsonb,$4) as value',[expected,JSON.stringify(value),JSON.stringify(pub(value.revision)),operation])).rows[0].value;
  assert.equal((await load()).payload,null);
  const first=await commit(0,payload(1),'a'.repeat(32));assert.equal(first.status,'ok');
  assert.equal((await commit(0,payload(1),'a'.repeat(32))).status,'ok');
  assert.equal((await commit(0,payload(1),'b'.repeat(32))).status,'conflict');
  assert.equal((await commit(1,payload(2),'b'.repeat(32))).status,'ok');
  assert.equal((await load()).payload.revision,2);
  assert.equal((await db.query('select previous_payload from public.ao_ranking_state')).rows[0].previous_payload.revision,1);
  await assert.rejects(commit(2,{schema:1},'c'.repeat(32)));
  await assert.rejects(db.query('select public.ao_store_commit(null,null,null,null)'));
  await db.exec('set role anon');await assert.rejects(load());await assert.rejects(db.query('select payload from public.ao_ranking_state'));await db.exec('reset role');
  await db.exec('set role authenticated');await assert.rejects(load());await db.exec('reset role');
  await db.exec('set role service_role');assert.equal((await load()).payload.revision,2);await db.exec('reset role');
 }finally{await db.close();}
});
