begin;

alter table public.table_sessions
  add column if not exists ready_for_checkout boolean not null default false;

alter table public.order_items
  add column if not exists course text not null default 'main';

update public.order_items
set course = 'main'
where course is null or course not in ('main','starter','together');

alter table public.order_items
  drop constraint if exists order_items_course_check;

alter table public.order_items
  add constraint order_items_course_check
  check (course in ('main','starter','together'));

commit;
