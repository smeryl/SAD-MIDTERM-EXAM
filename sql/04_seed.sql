-- Create 3 users first in Authentication > Users, then paste their UUIDs below.
insert into profiles(student_id,full_name,role) values
('A01','Scholar A01','scholar'),('A02','Scholar A02','scholar'),('A03','Scholar A03','scholar'),
('A04','Scholar A04','scholar'),('A05','Scholar A05','scholar'),('A06','Scholar A06','scholar'),
(null,'Staff Tester','staff');
insert into scholar_assignments(scholar_id,program_id)
select id,case when student_id in('A01','A02','A05') then 1 else 2 end from profiles where student_id like 'A0%';
insert into submissions(scholar_id,academic_year,semester,gwa,units,failed_count,incomplete_count,dropped_count,evidence_ref,submitted_at,verification_status)
select p.id,'2026-2027',1,v.gwa,v.units,v.f,v.i,v.d,'DOC-'||v.sid,v.ts::timestamptz,v.vs from (values
('A01',1.75,18,0,0,0,'2026-10-30 17:00:00+08','Verified'),
('A02',1.76,18,0,0,0,'2026-10-29 17:00:00+08','Verified'),
('A03',2.25,15,0,0,1,'2026-10-29 17:00:00+08','Verified'),
('A04',2.25,14,0,1,0,'2026-10-29 17:00:00+08','Verified'),
('A05',1.50,18,1,0,0,'2026-10-30 17:01:00+08','Verified'),
('A06',2.00,15,0,0,0,'2026-10-29 17:00:00+08','Pending')
) as v(sid,gwa,units,f,i,d,ts,vs) join profiles p on p.student_id=v.sid;
update profiles set auth_user_id='<STAFF-UUID>' where full_name='Staff Tester';
update profiles set auth_user_id='<SCHOLAR1-UUID>' where student_id='A01';
update profiles set auth_user_id='<SCHOLAR2-UUID>' where student_id='A02';
