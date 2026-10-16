export interface Situacion {capital_pendiente:number;capital_disponible:number;limite:number;deuda_pendiente:number;mora_desde:string|null;condicion_pago:string;conciliado:boolean;verificacion:string;elegible:boolean}
export interface Saldos {total_programado:number;interes_total:number;total_pagado:number;capital_pendiente:number;deuda_pendiente:number;estado_deuda:string}
export const fechaPeru=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Lima',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
export const fechaCorta=(s:string)=>s.slice(0,10).split('-').reverse().join('/');
export const codigo=(id:string)=>'PR-'+id.slice(0,8).toUpperCase();
export const etiquetas:Record<string,string>={habilitado:'Habilitado',moroso:'Moroso',extrajudicial:'Extrajudicial',por_conciliar:'Por conciliar',aprobada:'Aprobada',pendiente:'Pendiente',caducada:'Caducada',rechazada:'Rechazada',activo:'Activo',cancelado:'Cancelado'};
export const claseEstado=(s:string)=>['habilitado','aprobada','cancelado','pagada'].includes(s)?'badge-success':['pendiente','caducada','por_conciliar','activo'].includes(s)?'badge-warning':'badge-danger';
