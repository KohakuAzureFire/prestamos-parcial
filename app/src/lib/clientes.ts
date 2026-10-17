import type {Cliente} from '@/types/database';
export type FiltroCliente='todos'|'personas'|'empresas';
export type IdentidadListado=Pick<Cliente,'dni'|'ruc'|'tipo_cliente'>;
export const esEmpresa=(c:IdentidadListado)=>c.tipo_cliente==='juridica'||!!c.ruc?.startsWith('20');
export const coincideTipo=(c:IdentidadListado,f:FiltroCliente)=>f==='todos'||(f==='empresas'?esEmpresa(c):!esEmpresa(c));
export const filtroCliente=(s?:string):FiltroCliente=>s==='personas'||s==='empresas'?s:'todos';
