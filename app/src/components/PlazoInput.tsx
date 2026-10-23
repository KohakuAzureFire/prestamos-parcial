'use client';
import {useState} from 'react';
export default function PlazoInput({valor,onChange}:{valor:string;onChange:(v:string)=>void}){
 const [aviso,setAviso]=useState('');
 return <><input id="plazo" className="form-input" type="text" inputMode="numeric" autoComplete="off" maxLength={2} value={valor||'0'} aria-describedby="ayuda-plazo" onFocus={e=>e.target.select()} onChange={e=>{if(!/^\d*$/.test(e.target.value)){setAviso('Solo se permiten meses enteros, sin signos ni decimales.');return;}const n=Number(e.target.value||0);if(n>60){setAviso('El plazo máximo es de 60 meses.');return;}setAviso('');onChange(String(n));}} onKeyDown={e=>{if(e.key.length===1&&!/\d/.test(e.key)&&!e.ctrlKey&&!e.metaKey&&!e.altKey){e.preventDefault();setAviso('Solo se permiten meses enteros, sin signos ni decimales.');}}}/><small id="ayuda-plazo" className={aviso?'form-error':undefined} role={aviso?'status':undefined}>{aviso||'De 1 a 60 períodos de 30 días. Selecciona el 0 para reemplazarlo.'}</small></>;
}
