-- Stubs minimaux des schémas Supabase, pour appliquer les migrations sur un Postgres vierge en CI.
-- Ne remplace pas une pile Supabase : aucune API Auth/Storage, seulement les objets référencés par le SQL.
do $$begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin;end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin;end if;
 if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin bypassrls;end if;
end$$;
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists auth;
create table if not exists auth.users(id uuid primary key default gen_random_uuid(),email text,encrypted_password text,banned_until timestamptz,deleted_at timestamptz,created_at timestamptz default now(),raw_app_meta_data jsonb default '{}',raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz);
create table if not exists auth.sessions(id uuid primary key default gen_random_uuid(),user_id uuid references auth.users,factor_id uuid,aal text,not_after timestamptz,created_at timestamptz default now());
create table if not exists auth.mfa_factors(id uuid primary key default gen_random_uuid(),user_id uuid references auth.users,friendly_name text,factor_type text,status text,secret text,created_at timestamptz default now(),updated_at timestamptz default now());
create or replace function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
create or replace function auth.uid() returns uuid language sql stable as $$select nullif(auth.jwt()->>'sub','')::uuid$$;
create or replace function auth.role() returns text language sql stable as $$select auth.jwt()->>'role'$$;
grant usage on schema auth,extensions to anon,authenticated,service_role;
create schema if not exists storage;
create table if not exists storage.buckets(id text primary key,name text,public boolean default false,file_size_limit bigint,allowed_mime_types text[],owner uuid,created_at timestamptz default now());
create table if not exists storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets,name text,owner uuid,metadata jsonb,version text,created_at timestamptz default now(),updated_at timestamptz default now(),last_accessed_at timestamptz);
alter table storage.objects enable row level security;
create or replace function storage.allow_only_operation(op text) returns boolean language sql stable as $$select true$$;
grant usage on schema storage to anon,authenticated,service_role;
