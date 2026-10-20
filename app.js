const sb=supabase.createClient(SUPABASE_URL,SUPABASE_ANON_KEY);
const $=i=>document.getElementById(i);let me=null;
const msg=(t,ok)=>{$('msg').className=ok?'good':'err';$('msg').textContent=t};
const esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const pill=t=>{const k={Pending:'warn',Verified:'ok',Returned:'bad','Not Evaluated':'mute',Compliant:'ok','With Deficiency':'bad',None:'mute',Approved:'ok',Held:'warn'}[t]||'mute';return `<span class="pill ${k}">${esc(t)}</span>`};
const fmt=d=>new Date(d).toLocaleString('en-PH',{timeZone:'Asia/Manila'});
const msgMap=e=>e.code==='23505'?'You already submitted this semester.':e.code==='23514'?'Invalid value: GWA must be 1.00-5.00 and counts must be 0 or higher.':e.message;

$('in').onclick=async()=>{const{error}=await sb.auth.signInWithPassword({email:$('em').value,password:$('pw').value});error?msg(error.message):boot()};
$('out').onclick=async()=>{await sb.auth.signOut();location.reload()};

async function boot(){
 const{data:{session}}=await sb.auth.getSession();if(!session)return;
 const{data,error}=await sb.from('profiles').select('*').eq('auth_user_id',session.user.id).maybeSingle();
 if(error||!data)return msg('No profile linked to this account.');
 me=data;msg('');$('login').classList.add('hide');$('out').classList.remove('hide');
 $('who').textContent=`${me.full_name} (${me.role})`;
 if(me.role==='staff'){$('staff').classList.remove('hide');await loadPrograms();loadStaff()}
 else{$('scholar').classList.remove('hide');loadMine()}
}

// ---- Scholar ----
function num(id,label,int){const v=$(id).value.trim();if(v===''||isNaN(v))throw Error(label+' is required.');const n=Number(v);if(int&&(!Number.isInteger(n)||n<0))throw Error(label+' must be a whole number, 0 or higher.');return n}
$('sub').onclick=async()=>{
 try{
  const gwa=num('gwa','GWA');if(gwa<1||gwa>5)throw Error('GWA must be between 1.00 and 5.00.');
  const ev=$('ev').value.trim();if(!ev)throw Error('Grade document reference is required.');
  const row={academic_year:$('ay').value.trim(),semester:+$('sem').value,gwa,units:num('units','Units',1),failed_count:num('failed','Failed',1),incomplete_count:num('inc','INC',1),dropped_count:num('drop','Dropped',1),evidence_ref:ev};
  const{data:ex}=await sb.from('submissions').select('id,verification_status').eq('academic_year',row.academic_year).eq('semester',row.semester).maybeSingle();
  let r;
  if(ex&&ex.verification_status==='Returned')r=await sb.from('submissions').update(row).eq('id',ex.id);
  else if(ex)throw Error('You already submitted this semester.');
  else r=await sb.from('submissions').insert({...row,scholar_id:me.id});
  if(r.error)throw Error(msgMap(r.error));
  msg(ex?'Resubmitted. Status is Pending verification.':'Submitted. Status is Pending verification.',1);loadMine();
 }catch(e){msg(e.message)}
};
async function loadMine(){
 const{data}=await sb.from('v_submissions').select('*').order('submitted_at',{ascending:false});
 $('mine').innerHTML='<tr><th>Term</th><th>GWA</th><th>Submitted</th><th>Verification</th><th>Compliance</th><th>Renewal</th></tr>'+(data||[]).map(s=>`<tr><td>${s.academic_year} S${s.semester}</td><td>${s.gwa}</td><td>${fmt(s.submitted_at)}</td><td>${pill(s.verification_status)}${s.verification_reason?'<br><small>'+esc(s.verification_reason)+'</small>':''}</td><td>${pill(s.compliance_result)}</td><td>${pill(s.renewal_decision)}</td></tr>`).join('')||'<tr><td>No submissions yet.</td></tr>';
}

// ---- Staff ----
async function loadPrograms(){
 const{data}=await sb.from('programs').select('*').order('id');
 $('rprog').innerHTML=(data||[]).map(p=>`<option value="${p.id}">${esc(p.name)}</option>`).join('');
 $('fp').innerHTML='<option value="">All programs</option>'+(data||[]).map(p=>`<option>${esc(p.name)}</option>`).join('');
}
$('reg').onclick=async()=>{const{error}=await sb.rpc('register_scholar',{p_student_id:$('rsid').value.trim(),p_name:$('rname').value.trim(),p_auth:$('ruid').value.trim()||null,p_program:+$('rprog').value});error?msg(error.message):(msg('Scholar registered and assigned.',1),loadStaff())};
$('go').onclick=loadStaff;$('fay').onchange=$('fsem').onchange=loadStaff;
async function loadStaff(){
 const ay=$('fay').value,sem=+$('fsem').value;
 const{data:all}=await sb.from('v_submissions').select('*').eq('academic_year',ay).eq('semester',sem);
 const a=all||[],c=f=>a.filter(f).length;
 const{count}=await sb.from('scholar_assignments').select('*',{count:'exact',head:true});
 $('stats').innerHTML=[['Assigned scholars',count??0],['Pending verification',c(s=>s.verification_status==='Pending')],['Compliant',c(s=>s.compliance_result==='Compliant')],['With deficiency',c(s=>s.compliance_result==='With Deficiency')]].map(([l,v])=>`<div class="stat"><b>${v}</b><span>${l}</span></div>`).join('');
 let q=sb.from('v_submissions').select('*').eq('academic_year',ay).eq('semester',sem).order('student_id');
 if($('fp').value)q=q.eq('program_name',$('fp').value);if($('fc').value)q=q.eq('compliance_result',$('fc').value);
 const t=$('q').value.trim().replace(/[,()%]/g,'');if(t)q=q.or(`student_id.ilike.%${t}%,full_name.ilike.%${t}%`);
 const{data}=await q;
 $('all').innerHTML='<tr><th>ID</th><th>Name</th><th>Program</th><th>Academic summary</th><th>Evidence</th><th>Verification</th><th>Compliance</th><th>Renewal</th><th>Actions</th></tr>'+(data||[]).map(s=>`<tr><td>${esc(s.student_id)}</td><td>${esc(s.full_name)}</td><td>${esc(s.program_name)}</td><td><b>GWA ${s.gwa}</b><br><small>${s.units} units, ${s.failed_count} failed, ${s.incomplete_count} INC, ${s.dropped_count} dropped</small></td><td>${esc(s.evidence_ref)}<br><small>${fmt(s.submitted_at)}</small></td><td>${pill(s.verification_status)}${s.verification_reason?'<br><small>'+esc(s.verification_reason)+'</small>':''}</td><td>${pill(s.compliance_result)}${(s.deficiency_reasons||[]).map(r=>'<br><small class="err">'+esc(r)+'</small>').join('')}</td><td>${pill(s.renewal_decision)}${s.decision_note?'<br><small>'+esc(s.decision_note)+'</small>':''}</td><td>
<div class="acts"><span class="grp"><button class="sm" data-a="ver" data-id="${s.id}">Verify</button><button class="sm ghost" data-a="ret" data-id="${s.id}">Return</button></span><span class="grp"><button class="sm" data-a="eval" data-id="${s.id}">Evaluate</button></span><span class="grp"><button class="sm ok" data-a="app" data-id="${s.id}">Approve</button><button class="sm ghost" data-a="hold" data-id="${s.id}">Hold</button></span><button class="link" data-a="hist" data-id="${s.id}">History</button></div></td></tr>`).join('')||'<tr><td>No records match.</td></tr>';
}
$('all').onclick=async e=>{
 const b=e.target.closest('button');if(!b)return;const id=b.dataset.id,a=b.dataset.a;let r;
 if(a==='ver')r=await sb.rpc('verify_submission',{p_id:id,p_status:'Verified',p_reason:null});
 if(a==='ret'){const why=prompt('Reason for returning evidence:');if(why===null)return;r=await sb.rpc('verify_submission',{p_id:id,p_status:'Returned',p_reason:why})}
 if(a==='eval')r=await sb.rpc('evaluate_submission',{p_id:id});
 if(a==='app'||a==='hold'){const n=prompt('Decision note:');if(n===null)return;r=await sb.rpc('decide_renewal',{p_id:id,p_decision:a==='app'?'Approved':'Held',p_note:n})}
 if(a==='hist')return showHist(id);
 if(r.error)return msg(r.error.message);
 msg('Done.'+(a==='eval'?' Result: '+r.data:''),1);loadStaff();showHist(id);
};
async function showHist(id){
 const{data}=await sb.from('audit_log').select('*').eq('submission_id',id).order('created_at');
 $('hist').innerHTML=(data||[]).map(h=>`<div>${fmt(h.created_at)} - <b>${h.action}</b>: ${esc(h.old_value)} to ${esc(h.new_value)} <small>${esc(h.note)}</small></div>`).join('')||'<small>No history.</small>';
}
boot();
