import type {BorradorCliente} from './borradorPrestamo';
import type {Situacion} from './operaciones';
export function validarRuc(ruc: string): boolean {
  if (!/^(10|20)\d{9}$/.test(ruc)) return false;
  const pesos = [5,4,3,2,7,6,5,4,3,2];
  const resto = ruc.slice(0,10).split('').reduce((s,n,i)=>s+Number(n)*pesos[i],0)%11;
  const digito = 11-resto;
  return Number(ruc[10]) === (digito===10?0:digito===11?1:digito);
}
export interface ConsultaRuc {ruc:string;razon_social:string;estado:string;condicion:string;direccion:string;payload:string;firma:string}
export interface PersonaPrestamo {identidad_pendiente?:boolean;dni:string;nombres:string;apellidos:string;id?:string;borrador?:BorradorCliente;situacion:Situacion}
export interface BorradorRuc {consulta_representantes?:import('./representantesApi').SeleccionRepresentante;representacion_id?:string;maximo_representacion?:number;representacion_hasta?:string;consulta:ConsultaRuc;propietario:PersonaPrestamo;representante:PersonaPrestamo;evidencia_propiedad:string;evidencia_poder:string;propiedad_confirmada:boolean}
