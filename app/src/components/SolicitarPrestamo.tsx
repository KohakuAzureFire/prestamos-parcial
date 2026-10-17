'use client';
import Link from 'next/link';import Icon from './Icon';
export default function SolicitarPrestamo({id,opciones,habilitado,sinCupo}:{id:string;opciones:boolean;habilitado:boolean;sinCupo:boolean}){
 const base='/dashboard/prestamos/nuevo?cliente_id='+id;
 if(!habilitado)return <button className="btn btn-secondary" disabled>{sinCupo?'Límite global alcanzado':'Nuevo préstamo bloqueado'}</button>;
 if(!opciones)return <Link className="btn btn-primary" href={base}>Solicitar préstamo</Link>;
 return <details className="document-menu loan-request-menu" onBlur={e=>{if(!e.currentTarget.contains(e.relatedTarget as Node|null))e.currentTarget.open=false;}} onKeyDown={e=>{if(e.key==='Escape'){e.currentTarget.open=false;e.currentTarget.querySelector('summary')?.focus();}}}><summary className="btn btn-primary">Solicitar préstamo<Icon name="chevron"/></summary><div className="document-menu-options"><Link href={base+'&modalidad=dni'}>Personal · DNI</Link><Link href={base+'&modalidad=ruc'}>Negocio · RUC 10</Link></div></details>;
}
