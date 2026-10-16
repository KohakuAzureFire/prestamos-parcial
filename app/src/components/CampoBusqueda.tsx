'use client';
import {TipoBusqueda,normalizarCodigo} from '@/lib/busqueda';
export default function CampoBusqueda({id,tipo,valor,onChange,disabled=false}:{id:string;tipo:TipoBusqueda;valor:string;onChange:(v:string)=>void;disabled?:boolean}) {
  return <div className={'code-input '+(tipo==='id'?'has-prefix':'')}>
    {tipo==='id'&&<span aria-hidden="true" className="code-prefix">PR-</span>}
    <input id={id} className="form-input" type="text" inputMode={tipo==='dni'?'numeric':'text'} autoComplete="off" spellCheck={false} disabled={disabled} aria-label={tipo==='dni'?'DNI exacto':'Código de préstamo, después de PR-'} value={valor} maxLength={tipo==='dni'?8:11} placeholder={tipo==='dni'?'Ingresa los 8 dígitos':'XXXXXXXX'} onChange={e=>onChange(tipo==='dni'?e.target.value.replace(/\D/g,'').slice(0,8):normalizarCodigo(e.target.value).replace(/[^A-F0-9]/g,'').slice(0,8))}/>
  </div>;
}
