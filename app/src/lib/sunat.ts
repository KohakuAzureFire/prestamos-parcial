import 'server-only';
import {validarRuc} from './ruc';
export async function consultarRuc(ruc:string) {
  if(!validarRuc(ruc)) throw new Error('El RUC debe tener 11 números, prefijo 10 o 20 y dígito verificador válido.');
  const token=process.env.DECOLECTA_API_TOKEN;
  if(!token)throw new Error('La consulta de RUC necesita configuración del servidor.');
  let response:Response;
  try{response=await fetch('https://api.decolecta.com/v1/sunat/ruc?numero='+encodeURIComponent(ruc),{headers:{Authorization:'Bearer '+token,Accept:'application/json'},cache:'no-store',signal:AbortSignal.timeout(8000)});}
  catch{throw new Error('Consulta SUNAT no disponible temporalmente. Reintenta; este fallo no cambia la verificación del cliente.');}
  if(!response.ok){
    console.error('Consulta SUNAT: respuesta del proveedor HTTP',response.status);
    throw new Error(response.status===404?'No se encontró el RUC en la consulta SUNAT. Revisa el número.':response.status===401||response.status===403?'La consulta SUNAT requiere revisar la autorización del servicio. Comunica el problema al administrador.':response.status===429?'El servicio SUNAT alcanzó su límite de consultas. Espera e intenta nuevamente.':'Consulta SUNAT no disponible temporalmente. Reintenta; este fallo no cambia la verificación del cliente.');
  }
  const d=await response.json();
  const text=(x:unknown)=>typeof x==='string'?x.trim():'';
  if(text(d.numero_documento)!==ruc||!text(d.razon_social)||!text(d.estado)||!text(d.condicion))throw new Error('El servicio devolvió datos incompletos o un RUC diferente.');
  return {ruc,razon_social:text(d.razon_social),estado:text(d.estado).toUpperCase(),condicion:text(d.condicion).toUpperCase(),direccion:text(d.direccion)||text(d['dirección'])};
}
