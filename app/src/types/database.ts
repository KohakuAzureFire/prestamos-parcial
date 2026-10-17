// src/types/database.ts
export type CondicionCliente = 'activo' | 'restringido' | 'fallecido' | 'extrajudicial';
export type EstadoPrestamo = 'borrador' | 'confirmado';

export interface Agencia {
  id: string;
  nombre: string;
  created_at: string;
}

export interface Asesor {
  id: string;
  agencia_id: string;
  nombre_completo: string;
  activo: boolean;
  created_at: string;
  updated_at: string;
  agencias?: Agencia;
}

export interface Cliente {
  id: string;
  dni: string | null;
  ruc?: string | null;
  razon_social?: string | null;
  tipo_cliente?: 'natural' | 'juridica';
  estado_ruc?: string | null;
  condicion_ruc?: string | null;
  nombres: string;
  apellidos: string;
  condicion: CondicionCliente;
  fuente_verificacion: string | null;
  resultado_verificacion: string | null;
  fecha_verificacion: string | null;
  asesor_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface Prestamo {
  identidad_contrato?: {nombres:string;apellidos:string;dni?:string|null;ruc?:string|null;modalidad?:string}|null;
  id: string;
  cliente_id: string;
  agencia_id: string;
  asesor_id: string;
  fecha_prestamo: string;
  monto: number;
  plazo_meses: number;
  tea: number;
  estado: EstadoPrestamo;
  confirmado_at: string | null;
  created_at: string;
  clientes?: Cliente;
  agencias?: Agencia;
  asesores?: Asesor;
  cuotas?: Cuota[];
}

export interface FilaCuota {
  numero_cuota: number;
  fecha_vencimiento: Date;
  cuota_total: number;
  interes: number;
  amortizacion: number;
  saldo: number;
}

export interface Cuota {
  id: string;
  prestamo_id: string;
  numero_cuota: number;
  fecha_vencimiento: string;
  cuota_total: number;
  interes: number;
  amortizacion: number;
  saldo: number;
  created_at: string;
}
