export interface ConsultaIdentidad {
  dni: string;
  nombres: string;
  apellidos: string;
  payload: string;
  firma: string;
}
export interface BorradorCliente {
  consulta: ConsultaIdentidad;
  evidencia: {
    caducidad: string;
    original: boolean;
    no_fallecido: boolean;
    vigencia: string;
    supervivencia: string;
  };
}
