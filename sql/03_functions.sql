create function verify_submission(p_id uuid,p_status text,p_reason text) returns void language plpgsql security definer set search_path=public as $$
declare o text;
begin
 if not is_staff() then raise exception 'Staff only'; end if;
 if p_status not in ('Verified','Returned') then raise exception 'Invalid status'; end if;
 if p_status='Returned' and coalesce(trim(p_reason),'')='' then raise exception 'A reason is required when returning evidence'; end if;
 select verification_status into o from submissions where id=p_id;
 update submissions set verification_status=p_status,verification_reason=p_reason,compliance_result='Not Evaluated',deficiency_reasons='{}',renewal_decision='None' where id=p_id;
 insert into audit_log(submission_id,actor_id,action,old_value,new_value,note) values(p_id,my_profile_id(),'VERIFICATION',o,p_status,p_reason);
end $$;
create function evaluate_submission(p_id uuid) returns text language plpgsql security definer set search_path=public as $$
declare s submissions; p programs; r text[]:='{}'; res text;
begin
 if not is_staff() then raise exception 'Staff only'; end if;
 select * into s from submissions where id=p_id;
 if s.verification_status<>'Verified' then raise exception 'Evidence must be Verified before evaluation'; end if;
 select pr.* into p from programs pr join scholar_assignments a on a.program_id=pr.id where a.scholar_id=s.scholar_id;
 if not found then raise exception 'Scholar has no program assigned'; end if;
 if s.gwa>p.max_gwa then r:=r||format('GWA %s exceeds maximum %s',s.gwa,p.max_gwa); end if;
 if s.units<p.min_units then r:=r||format('Enrolled units %s below minimum %s',s.units,p.min_units); end if;
 if s.failed_count>p.max_failed then r:=r||format('Failed subjects %s exceed allowed %s',s.failed_count,p.max_failed); end if;
 if s.incomplete_count>p.max_incomplete then r:=r||format('Incomplete grades %s exceed allowed %s',s.incomplete_count,p.max_incomplete); end if;
 if s.dropped_count>p.max_dropped then r:=r||format('Dropped subjects %s exceed allowed %s',s.dropped_count,p.max_dropped); end if;
 if s.submitted_at>p.deadline then r:=r||'Submitted after the deadline'; end if;
 res:=case when cardinality(r)=0 then 'Compliant' else 'With Deficiency' end;
 update submissions set compliance_result=res,deficiency_reasons=r where id=p_id;
 insert into audit_log(submission_id,actor_id,action,old_value,new_value,note) values(p_id,my_profile_id(),'EVALUATION',s.compliance_result,res,array_to_string(r,'; '));
 return res;
end $$;
create function decide_renewal(p_id uuid,p_decision text,p_note text) returns void language plpgsql security definer set search_path=public as $$
declare s submissions;
begin
 if not is_staff() then raise exception 'Staff only'; end if;
 if p_decision not in ('Approved','Held') then raise exception 'Invalid decision'; end if;
 select * into s from submissions where id=p_id;
 if s.verification_status<>'Verified' or s.compliance_result='Not Evaluated' then raise exception 'Record must be Verified and Evaluated first'; end if;
 if p_decision='Approved' and s.compliance_result<>'Compliant' then raise exception 'Cannot approve a record With Deficiency'; end if;
 update submissions set renewal_decision=p_decision,decision_note=p_note where id=p_id;
 insert into audit_log(submission_id,actor_id,action,old_value,new_value,note) values(p_id,my_profile_id(),'RENEWAL',s.renewal_decision,p_decision,p_note);
end $$;
create function register_scholar(p_student_id text,p_name text,p_auth uuid,p_program int) returns void language plpgsql security definer set search_path=public as $$
declare pid uuid;
begin
 if not is_staff() then raise exception 'Staff only'; end if;
 insert into profiles(student_id,full_name,role,auth_user_id) values(p_student_id,p_name,'scholar',p_auth) returning id into pid;
 insert into scholar_assignments(scholar_id,program_id) values(pid,p_program);
end $$;
create view v_submissions with (security_invoker=true) as
select s.*,pr.student_id,pr.full_name,p.name as program_name
from submissions s join profiles pr on pr.id=s.scholar_id
left join scholar_assignments a on a.scholar_id=s.scholar_id left join programs p on p.id=a.program_id;
