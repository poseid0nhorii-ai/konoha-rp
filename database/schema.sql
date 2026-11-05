
-- KONOHA RP — Supabase / PostgreSQL
-- À exécuter dans SQL Editor d'un NOUVEAU projet Supabase.
-- Ne jamais exposer la clé service_role dans GitHub Pages.
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 nickname text not null check (char_length(nickname) between 2 and 60),
 clan text,
 rank text,
 role text not null default 'player' check (role in ('player','editor','admin')),
 approved boolean not null default false,
 created_at timestamptz not null default now()
);
create table if not exists public.clans (
 id uuid primary key default gen_random_uuid(),
 name text unique not null,
 description text not null default '',
 created_at timestamptz not null default now()
);
create table if not exists public.section_memberships(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 section text not null check(section in ('police','academie','medicale','diplomatique','strategie','anbu')),
 position text not null default 'membre',
 created_at timestamptz not null default now(),
 unique(user_id,section)
);
create table if not exists public.missions(
 id uuid primary key default gen_random_uuid(),
 title text not null check(char_length(title) between 2 and 140),
 rank text not null check(rank in ('D','C','B','A','S')),
 description text not null default '',
 status text not null default 'ouverte' check(status in ('ouverte','en cours','terminée')),
 created_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists public.mission_reports(
 id uuid primary key default gen_random_uuid(),
 mission_id uuid not null references public.missions(id) on delete cascade,
 author_id uuid not null references auth.users(id),
 body text not null,
 status text not null default 'en attente' check(status in ('en attente','validé','refusé')),
 created_at timestamptz not null default now()
);
create table if not exists public.announcements(
 id uuid primary key default gen_random_uuid(),
 title text not null check(char_length(title) between 2 and 140),
 body text not null,
 created_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists public.events(
 id uuid primary key default gen_random_uuid(),
 title text not null,
 description text not null default '',
 event_date timestamptz not null,
 created_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists public.trainings(
 id uuid primary key default gen_random_uuid(),
 title text not null,
 description text not null default '',
 scheduled_at timestamptz not null,
 created_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists public.documents(
 id uuid primary key default gen_random_uuid(),
 title text not null,
 category text not null default 'Autre',
 body text not null,
 visibility text not null default 'public' check(visibility in ('public','staff')),
 created_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists public.tickets(
 id uuid primary key default gen_random_uuid(),
 kind text not null check(kind in ('audience','candidature','plainte','autre')),
 title text not null,
 body text not null,
 status text not null default 'en attente' check(status in ('en attente','en cours','terminée')),
 owner_id uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists public.messages(
 id uuid primary key default gen_random_uuid(),
 sender_id uuid not null references auth.users(id),
 receiver_id uuid not null references auth.users(id),
 body text not null check(char_length(body) between 1 and 4000),
 created_at timestamptz not null default now(),
 constraint no_self_message check (sender_id<>receiver_id)
);
create table if not exists public.audit_logs(
 id uuid primary key default gen_random_uuid(),
 actor_id uuid references auth.users(id),
 action text not null,
 target_id uuid,
 details jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create index if not exists idx_missions_created on public.missions(created_at desc);
create index if not exists idx_tickets_owner on public.tickets(owner_id);
create index if not exists idx_messages_receiver on public.messages(receiver_id,created_at desc);
create index if not exists idx_memberships_user on public.section_memberships(user_id);
create index if not exists idx_documents_visibility on public.documents(visibility);

-- Helpers en SECURITY DEFINER : ne pas déclencher une récursion RLS sur profiles.
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles p
 where p.id=auth.uid() and p.approved=true and p.role='admin');
$$;
create or replace function public.is_approved() returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles p where p.id=auth.uid() and p.approved=true);
$$;
create or replace function public.can_edit() returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles p
 where p.id=auth.uid() and p.approved=true and p.role in ('admin','editor'));
$$;
revoke all on function public.is_admin() from public;
revoke all on function public.is_approved() from public;
revoke all on function public.can_edit() from public;
grant execute on function public.is_admin() to anon,authenticated;
grant execute on function public.is_approved() to anon,authenticated;
grant execute on function public.can_edit() to anon,authenticated;

-- Le nom RP est alimenté à l'inscription. Aucun nouveau compte n'est approuvé automatiquement.
create or replace function public.handle_new_shinobi() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 insert into public.profiles(id,nickname,role,approved)
 values(new.id, left(coalesce(nullif(trim(new.raw_user_meta_data->>'nickname'),''),'Shinobi à nommer'),60),'player',false);
 return new;
end;$$;
drop trigger if exists on_shinobi_created on auth.users;
create trigger on_shinobi_created after insert on auth.users
for each row execute procedure public.handle_new_shinobi();

alter table public.profiles enable row level security;
alter table public.clans enable row level security;
alter table public.section_memberships enable row level security;
alter table public.missions enable row level security;
alter table public.mission_reports enable row level security;
alter table public.announcements enable row level security;
alter table public.events enable row level security;
alter table public.trainings enable row level security;
alter table public.documents enable row level security;
alter table public.tickets enable row level security;
alter table public.messages enable row level security;
alter table public.audit_logs enable row level security;

-- Des politiques explicites ; les écritures qui ne sont pas autorisées sont refusées.
create policy "profiles read approved own or admin" on public.profiles for select to anon,authenticated
using(approved=true or id=auth.uid() or public.is_admin());
create policy "profiles update admin only" on public.profiles for update to authenticated
using(public.is_admin()) with check(public.is_admin());

create policy "clans read" on public.clans for select to anon,authenticated using(true);
create policy "clans insert" on public.clans for insert to authenticated with check(public.can_edit());
create policy "clans update" on public.clans for update to authenticated using(public.can_edit()) with check(public.can_edit());
create policy "clans delete" on public.clans for delete to authenticated using(public.is_admin());

-- Ne jamais inclure les membres ANBU dans les requêtes publiques.
create policy "memberships own or admin read" on public.section_memberships for select to authenticated
using(user_id=auth.uid() or public.is_admin());
create policy "memberships admin insert" on public.section_memberships for insert to authenticated
with check(public.is_admin());
create policy "memberships admin update" on public.section_memberships for update to authenticated
using(public.is_admin()) with check(public.is_admin());
create policy "memberships admin delete" on public.section_memberships for delete to authenticated
using(public.is_admin());

create policy "missions public read" on public.missions for select to anon,authenticated using(true);
create policy "missions staff insert" on public.missions for insert to authenticated
with check(public.can_edit() and created_by=auth.uid());
create policy "missions staff update" on public.missions for update to authenticated
using(public.can_edit()) with check(public.can_edit());
create policy "missions admin delete" on public.missions for delete to authenticated using(public.is_admin());

create policy "reports own or staff read" on public.mission_reports for select to authenticated
using(author_id=auth.uid() or public.can_edit());
create policy "reports owner submit" on public.mission_reports for insert to authenticated
with check(public.is_approved() and author_id=auth.uid() and status='en attente');
create policy "reports staff validate" on public.mission_reports for update to authenticated
using(public.can_edit()) with check(public.can_edit());

create policy "announcements public read" on public.announcements for select to anon,authenticated using(true);
create policy "announcements staff insert" on public.announcements for insert to authenticated
with check(public.can_edit() and created_by=auth.uid());
create policy "announcements staff update" on public.announcements for update to authenticated
using(public.can_edit()) with check(public.can_edit());
create policy "announcements admin delete" on public.announcements for delete to authenticated using(public.is_admin());

create policy "events public read" on public.events for select to anon,authenticated using(true);
create policy "events staff insert" on public.events for insert to authenticated
with check(public.can_edit() and created_by=auth.uid());
create policy "events staff update" on public.events for update to authenticated
using(public.can_edit()) with check(public.can_edit());
create policy "events admin delete" on public.events for delete to authenticated using(public.is_admin());

create policy "trainings public read" on public.trainings for select to anon,authenticated using(true);
create policy "trainings staff insert" on public.trainings for insert to authenticated
with check(public.can_edit() and created_by=auth.uid());
create policy "trainings staff update" on public.trainings for update to authenticated
using(public.can_edit()) with check(public.can_edit());
create policy "trainings admin delete" on public.trainings for delete to authenticated using(public.is_admin());

create policy "documents visibility" on public.documents for select to anon,authenticated
using(visibility='public' or public.can_edit());
create policy "documents staff insert" on public.documents for insert to authenticated
with check(public.can_edit() and created_by=auth.uid());
create policy "documents staff update" on public.documents for update to authenticated
using(public.can_edit()) with check(public.can_edit());
create policy "documents admin delete" on public.documents for delete to authenticated using(public.is_admin());

create policy "tickets own or staff read" on public.tickets for select to authenticated
using(owner_id=auth.uid() or public.can_edit());
create policy "tickets approved submit" on public.tickets for insert to authenticated
with check(public.is_approved() and owner_id=auth.uid() and status='en attente');
create policy "tickets staff update" on public.tickets for update to authenticated
using(public.can_edit()) with check(public.can_edit());

create policy "messages participants only read" on public.messages for select to authenticated
using((sender_id=auth.uid() or receiver_id=auth.uid()) and public.is_approved());
create policy "messages sender only insert" on public.messages for insert to authenticated
with check(public.is_approved() and sender_id=auth.uid() and
 exists(select 1 from public.profiles p where p.id=receiver_id and p.approved=true));

create policy "audit admin only" on public.audit_logs for select to authenticated using(public.is_admin());

-- Mise à jour sécurisée d'un profil. Ne pas appeler cette fonction pour créer un compte.
create or replace function public.admin_update_profile(
 target_user_id uuid, new_rank text, new_clan text, new_role text, new_approved boolean
) returns void language plpgsql security definer set search_path = '' as $$
begin
 if not public.is_admin() then raise exception 'Accès administrateur requis'; end if;
 if new_role not in ('player','editor','admin') then raise exception 'Rôle invalide'; end if;
 if new_rank not in ('Hokage','Conseiller','Commandant Jônin','Jônin','Tokubetsu Jônin','Chûnin confirmé','Chûnin','Tokubetsu Chûnin','Genin confirmé','Genin')
 then raise exception 'Grade invalide'; end if;
 if target_user_id=auth.uid() and (new_role<>'admin' or new_approved=false) then
  raise exception 'Un administrateur ne peut pas se retirer ses propres droits';
 end if;
 update public.profiles
 set rank=new_rank,clan=left(new_clan,80),role=new_role,approved=new_approved
 where id=target_user_id;
 if not found then raise exception 'Compte introuvable'; end if;
 insert into public.audit_logs(actor_id,action,target_id,details)
 values(auth.uid(),'admin_update_profile',target_user_id,
 jsonb_build_object('rank',new_rank,'clan',new_clan,'role',new_role,'approved',new_approved));
end;$$;
revoke all on function public.admin_update_profile(uuid,text,text,text,boolean) from public,anon;
grant execute on function public.admin_update_profile(uuid,text,text,text,boolean) to authenticated;

-- Clans publics d'amorçage. Ne rien inventer sur les responsables.
insert into public.clans(name,description) values
 ('Hyûga','Clan du village de Konoha.'),
 ('Uchiha','Clan du village de Konoha.'),
 ('Senju','Clan du village de Konoha.'),
 ('Aburame','Clan du village de Konoha.')
on conflict (name) do nothing;

-- IMPORTANT : exécute cette commande MANUELLEMENT après avoir créé TON compte sur le site,
-- en remplaçant l'adresse exemple par l'e-mail exact de ton compte.
-- update public.profiles set role='admin', approved=true
-- where id=(select id from auth.users where email='TON_EMAIL_ICI');
