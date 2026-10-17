import {esEmpresa,type IdentidadListado} from '@/lib/clientes';
export default function DocumentosCliente({cliente,completo=false}:{cliente:IdentidadListado;completo?:boolean}){
 return <div className="document-lines">{esEmpresa(cliente)?<span>RUC {cliente.ruc}</span>:<><span>DNI {cliente.dni||'Sin registrar'}</span>{completo&&cliente.ruc&&<span>RUC {cliente.ruc}</span>}</>}</div>;
}
