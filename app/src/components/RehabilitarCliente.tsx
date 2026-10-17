'use client';
import {useState} from 'react';
import {useRouter} from 'next/navigation';
import {createClient} from '@/lib/supabase/client';
export default function RehabilitarCliente({cliente}:{cliente:string}){
 const [motivo,setMotivo]=useState(''),[busy,setBusy]=useState(false),[error,setError]=useState('');const router=useRouter();
 async function autorizar(){if(!confirm('¿Autorizar nuevos préstamos después de revisar el antecedente y la regularización? El motivo quedará registrado.'))return;setBusy(true);setError('');try{const {error}=await createClient().rpc('rehabilitar_cliente',{p_cliente:cliente,p_motivo:motivo});if(error)throw error;router.refresh();}catch(e){setError((e as {message?:string}).message||'No se pudo autorizar.');}finally{setBusy(false);}}
 return <section className="card"><h2>Autorizar nuevos préstamos</h2><p>El cliente regularizó sus obligaciones vencidas. La autorización conserva el antecedente y no omite las validaciones de identidad, RUC ni capital disponible.</p><label className="form-label" htmlFor="motivo-autorizacion">Motivo de la evaluación</label><textarea id="motivo-autorizacion" className="form-input" value={motivo} maxLength={1000} onChange={e=>setMotivo(e.target.value)}/>{error&&<p className="form-error" role="alert">{error}</p>}<div className="loan-actions"><button className="btn btn-primary" disabled={busy||motivo.trim().length<10} onClick={autorizar}>{busy?'Guardando…':'Autorizar nuevos préstamos'}</button></div></section>;
}
