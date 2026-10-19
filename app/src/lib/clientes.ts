import type {Cliente} from '@/types/database';
export type FiltroCliente='todos'|'personas'|'empresas';
export type IdentidadListado=Pick<Cliente,'dni'|'ruc'|'tipo_cliente'>;
export const esEmpresa=(c:IdentidadListado)=>c.tipo_cliente==='juridica'||!!c.ruc?.startsWith('20');
export const coincideTipo=(c:IdentidadListado,f:FiltroCliente)=>f==='todos'||(f==='empresas'?esEmpresa(c):!esEmpresa(c));
export const coincideTipoListado=(c:IdentidadListado,f:FiltroCliente)=>f==='todos'||(f==='empresas'?!!c.ruc:!esEmpresa(c));
export const filtroCliente=(s?:string):FiltroCliente=>s==='personas'||s==='empresas'?s:'todos';

export const documentosListado=(c:IdentidadListado,f:FiltroCliente)=>f==='empresas'?['RUC '+c.ruc]:esEmpresa(c)?['RUC '+c.ruc]:['DNI '+(c.dni||'Sin registrar'),...(f==='todos'&&c.ruc?['RUC '+c.ruc]:[])];
