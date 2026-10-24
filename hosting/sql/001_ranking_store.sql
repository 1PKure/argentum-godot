-- Run once in the free Supabase project's SQL editor. No seed/player data here.
create table public.ao_ranking_state (
  id integer primary key check (id=1),
  payload jsonb not null,
  public_snapshot jsonb not null,
  previous_payload jsonb,
  operation_id text not null,
  updated_at timestamptz not null default now()
);
alter table public.ao_ranking_state enable row level security;
revoke all on public.ao_ranking_state from public,anon,authenticated;

create function public.ao_store_load() returns jsonb language sql security definer set search_path='' as $$
  select coalesce((select jsonb_build_object('status','ok','payload',payload,'public_snapshot',public_snapshot) from public.ao_ranking_state where id=1),jsonb_build_object('status','ok','payload',null,'public_snapshot',null));
$$;
create function public.ao_store_commit(p_expected bigint,p_payload jsonb,p_public jsonb,p_operation text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare current_row public.ao_ranking_state%rowtype;
begin
  if p_expected is null or p_expected<0 or jsonb_typeof(p_payload) is distinct from 'object' or (p_payload->>'schema')::integer is distinct from 1 or (p_payload->>'revision')::bigint is distinct from p_expected+1 or jsonb_typeof(p_public) is distinct from 'object' or (p_public->>'schema')::integer is distinct from 1 or (p_public->>'revision')::bigint is distinct from p_expected+1 or p_operation is null or p_operation!~'^[a-f0-9]{32}$' or octet_length(p_payload::text)>8388608 then raise exception 'Invalid commit';end if;
  perform pg_catalog.pg_advisory_xact_lock(658053246);
  select * into current_row from public.ao_ranking_state where id=1 for update;
  if found and current_row.operation_id=p_operation then return jsonb_build_object('status','ok','payload',current_row.payload,'public_snapshot',current_row.public_snapshot);end if;
  if (found and (current_row.payload->>'revision')::bigint<>p_expected) or (not found and p_expected<>0) then
    return jsonb_build_object('status','conflict','payload',current_row.payload,'public_snapshot',current_row.public_snapshot);
  end if;
  insert into public.ao_ranking_state(id,payload,public_snapshot,previous_payload,operation_id) values(1,p_payload,p_public,current_row.payload,p_operation)
  on conflict(id) do update set previous_payload=ao_ranking_state.payload,payload=excluded.payload,public_snapshot=excluded.public_snapshot,operation_id=excluded.operation_id,updated_at=now();
  return jsonb_build_object('status','ok','payload',p_payload,'public_snapshot',p_public);
end;
$$;
revoke all on function public.ao_store_load() from public,anon,authenticated;
revoke all on function public.ao_store_commit(bigint,jsonb,jsonb,text) from public,anon,authenticated;
grant execute on function public.ao_store_load() to service_role;
grant execute on function public.ao_store_commit(bigint,jsonb,jsonb,text) to service_role;
