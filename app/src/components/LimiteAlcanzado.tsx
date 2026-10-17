import Link from 'next/link';
export default function LimiteAlcanzado({clienteId}:{clienteId?:string}){
 return <div className="animate-fade-in"><div className="page-heading"><h1>Nuevo préstamo bloqueado</h1></div><section className="card"><h2>Límite global alcanzado</h2><p role="alert">El cliente no tiene capital disponible para un nuevo préstamo. El límite considera sus préstamos personales y las empresas vinculadas entre todas las agencias.</p><Link className="btn btn-secondary" href={clienteId?'/dashboard/clientes/'+clienteId:'/dashboard/clientes'}>{clienteId?'Volver a la ficha':'Volver a clientes'}</Link></section></div>;
}
