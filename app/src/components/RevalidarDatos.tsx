'use client';
import Link from 'next/link';
import Icon from './Icon';

export default function RevalidarDatos({id,dni,ruc,empresa}:{id:string;dni:string|null;ruc:string|null;empresa:boolean}) {
 const identidad='/dashboard/clientes/nuevo?dni='+dni;
 const sunat='/dashboard/clientes/'+id+'/revalidar?tipo=ruc';
 if(empresa)return <Link className="btn btn-secondary" href={sunat}>Actualizar datos SUNAT</Link>;
 if(!ruc)return <Link className="btn btn-secondary" href={identidad}>Revalidar identidad</Link>;
 return <details className="document-menu revalidation-menu" onBlur={e=>{if(!e.currentTarget.contains(e.relatedTarget as Node|null))e.currentTarget.open=false;}} onKeyDown={e=>{if(e.key==='Escape'){e.currentTarget.open=false;e.currentTarget.querySelector('summary')?.focus();}}}>
  <summary className="btn btn-secondary">Revalidar datos<Icon name="chevron"/></summary>
  <div className="document-menu-options"><Link href={identidad}>Revalidar DNI</Link><Link href={sunat}>Actualizar datos SUNAT · RUC 10</Link></div>
 </details>;
}
