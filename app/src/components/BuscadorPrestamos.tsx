'use client';
import {useState} from 'react';
import {useRouter} from 'next/navigation';
import CampoBusqueda from './CampoBusqueda';
import {TipoBusqueda,normalizarCodigo,errorBusqueda,valorBusqueda} from '@/lib/busqueda';
export default function BuscadorPrestamos({dni='',id='',estado='activo'}:{dni?:string;id?:string;estado?:string}){
 const router=useRouter();const [q,setQ]=useState(dni||normalizarCodigo(id));const [tipo,setTipo]=useState<TipoBusqueda>(id?'id':'dni');const [error,setError]=useState('');
 return <><form className="loan-search" noValidate onSubmit={e=>{e.preventDefault();const err=errorBusqueda(tipo,q);setError(err);if(!err)router.push(`/dashboard/prestamos?${tipo}=${encodeURIComponent(valorBusqueda(tipo,q))}&estado=${estado}`);}}>
  <div className="search-field search-with-prefix"><CampoBusqueda id="input-busqueda" tipo={tipo} valor={q} onChange={v=>{setQ(v);setError('');}}/></div>
  <label className="sr-only" htmlFor="search-type">Tipo de búsqueda</label><select id="search-type" className="form-input" value={tipo} onChange={e=>{setTipo(e.target.value as TipoBusqueda);setQ('');setError('');}}><option value="dni">DNI exacto</option><option value="id">Código de préstamo</option></select>
  <button id="btn-buscar" type="submit" className="btn btn-primary">Buscar</button>{q&&<button type="button" className="btn btn-secondary" onClick={()=>{setQ('');setError('');router.push('/dashboard/prestamos?estado='+estado);}}>Limpiar</button>}
 </form>{error&&<p className="form-error" role="alert">{error}</p>}</>;
}
