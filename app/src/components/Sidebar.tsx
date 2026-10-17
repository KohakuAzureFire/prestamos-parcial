'use client';
import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cerrarSesion } from '@/lib/sesion';
import { Asesor } from '@/types/database';
import Brand from './Brand';
import Icon from './Icon';
interface Props { configuraMora?:boolean;asesor: (Asesor & { agencias?: { nombre: string } }) | null; }
const navItems = [
 {href:'/dashboard/prestamos',label:'Préstamos',icon:'loans'},
 {href:'/dashboard/clientes',label:'Clientes',icon:'clients'},
 {href:'/dashboard/prestamos/nuevo',label:'Nuevo préstamo',icon:'plus'},
 {href:'/dashboard/pagos',label:'Pagos',icon:'wallet'},
];
export default function Sidebar({configuraMora=false}: Props) {
 const pathname=usePathname();
 const [open,setOpen]=useState(false); const [error,setError]=useState(''); const [leaving,setLeaving]=useState(false);
 const salirDelBorrador=(e:React.MouseEvent)=>{if(document.body.dataset.borrador==='true'){if(!confirm('¿Salir de este proceso? Los datos sin confirmar se perderán.')){e.preventDefault();return;}document.body.dataset.borrador='false';}setOpen(false);};
 const handleLogout=async()=>{
  if((document.body.dataset.borrador==='true')&&!confirm('¿Cerrar sesión? Los datos sin confirmar se perderán.'))return;
  setLeaving(true);setError('');
  try {await cerrarSesion();}
  catch {setError('No se pudo cerrar sesión. Inténtalo otra vez.');setLeaving(false);}
 };
 return <>
  <button className="mobile-menu btn btn-secondary" onClick={()=>setOpen(!open)} aria-expanded={open} aria-controls="app-navigation" aria-label={open?'Cerrar menú':'Abrir menú'}><Icon name="menu"/></button>
  {open&&<button className="nav-backdrop" aria-label="Cerrar menú" onClick={()=>setOpen(false)}/>}
  <aside id="app-navigation" className={`app-sidebar ${open?'is-open':''}`}>
   <Link href="/dashboard/prestamos" className="sidebar-brand" onClick={salirDelBorrador}><Brand/></Link>
   <nav aria-label="Navegación principal">{(configuraMora?[...navItems,{href:'/dashboard/configuracion',label:'Configuración',icon:'shield'}]:navItems).map(item=>{
    const active=item.icon==='loans'?pathname.startsWith(item.href)&&!pathname.includes('/nuevo'):pathname.startsWith(item.href);
    return <Link key={item.href} href={item.href} className={`nav-link ${active?'active':''}`} aria-current={active?'page':undefined} onClick={salirDelBorrador}><Icon name={item.icon}/>{item.label}</Link>;
   })}</nav>
   <div className="sidebar-footer">
    {error&&<p role="alert">{error}</p>}
    <button id="btn-logout" className="nav-link logout" disabled={leaving} onClick={handleLogout}><Icon name="logout"/>{leaving?'Cerrando sesión…':'Cerrar sesión'}</button>
   </div>
  </aside>
 </>;
}
