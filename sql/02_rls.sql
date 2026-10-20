create function my_profile_id() returns uuid language sql stable security definer set search_path=public as $$ select id from profiles where auth_user_id=auth.uid() $$;
create function is_staff() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from profiles where auth_user_id=auth.uid() and role='staff') $$;
alter table programs enable row level security;
alter table profiles enable row level security;
alter table scholar_assignments enable row level security;
alter table submissions enable row level security;
alter table audit_log enable row level security;
create policy prog_read on programs for select to authenticated using (true);
create policy prof_read on profiles for select to authenticated using (is_staff() or auth_user_id=auth.uid());
create policy prof_ins on profiles for insert to authenticated with check (is_staff());
create policy asg_read on scholar_assignments for select to authenticated using (is_staff() or scholar_id=my_profile_id());
create policy asg_write on scholar_assignments for all to authenticated using (is_staff()) with check (is_staff());
create policy sub_read on submissions for select to authenticated using (is_staff() or scholar_id=my_profile_id());
create policy sub_ins on submissions for insert to authenticated with check (scholar_id=my_profile_id());
create policy sub_fix on submissions for update to authenticated using (scholar_id=my_profile_id() and verification_status='Returned') with check (scholar_id=my_profile_id());
create policy audit_read on audit_log for select to authenticated using (is_staff() or exists(select 1 from submissions s where s.id=submission_id and s.scholar_id=my_profile_id()));
create function guard_submission() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is not null and not is_staff() then
  if tg_op='INSERT' then new.submitted_at:=now();
  else
   new.scholar_id:=old.scholar_id; new.academic_year:=old.academic_year; new.semester:=old.semester; new.submitted_at:=old.submitted_at;
   insert into audit_log(submission_id,actor_id,action,old_value,new_value,note) values(old.id,my_profile_id(),'RESUBMITTED',old.verification_status,'Pending','Scholar corrected submission');
  end if;
  new.verification_status:='Pending'; new.verification_reason:=null; new.compliance_result:='Not Evaluated';
  new.deficiency_reasons:='{}'; new.renewal_decision:='None'; new.decision_note:=null;
 end if;
 return new;
end $$;
create trigger trg_guard before insert or update on submissions for each row execute function guard_submission();
