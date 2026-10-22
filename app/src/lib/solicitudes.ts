export interface SolicitudPrestamo {
 id:string;ruc:string;agencia_id:string;asesor_id:string;cliente_id:string;propietario_id:string;representante_id:string;representacion_id:string;
 monto:number;plazo_meses:number;estado:'pendiente'|'observada'|'rechazada'|'aprobada';version:number;motivo:string|null;prestamo_id:string|null;created_at:string;updated_at:string;agencia_nombre?:string;asesor_nombre?:string;
 expediente:{razon_social:string;propietario:{dni:string;nombres:string;apellidos:string};representante:{dni:string;nombres:string;apellidos:string};evidencia_propiedad:string;certificado:{id:string;sha256:string;emision:string};monto:number;meses:number;fecha_simulacion:string};
}
export const etiquetaSolicitud={pendiente:'Pendiente de evaluación',observada:'Observada',rechazada:'Rechazada',aprobada:'Aprobada'};
