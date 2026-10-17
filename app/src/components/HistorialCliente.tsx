'use client';
import Link from 'next/link';import Icon from './Icon';
export default function HistorialCliente({id,empresa,tieneRuc}:{id:string;empresa:boolean;tieneRuc:boolean}){
 const base='/dashboard/clientes/'+id+'/historial?tipo=';
 if(empresa||!tieneRuc)return <Link className="btn btn-secondary" href={base+(empresa?'ruc':'dni')}>Ver historial</Link>;
 return <details className="document-menu profile-history-menu" onBlur={e=>{if(!e.currentTarget.contains(e.relatedTarget as Node|null))e.currentTarget.open=false;}} onKeyDown={e=>{if(e.key==='Escape'){e.currentTarget.open=false;e.currentTarget.querySelector('summary')?.focus();}}}><summary className="btn btn-secondary">Ver historial<Icon name="chevron"/></summary><div className="document-menu-options"><Link href={base+'dni'}>Verificaciones de DNI</Link><Link href={base+'ruc'}>Consultas de RUC</Link></div></details>;
}
