import 'server-only';
import {normalizarRepresentantes} from './representantesApi';
export async function consultarRepresentantes(ruc:string){
 const token=process.env.API_PERU_TOKEN;if(!token)throw new Error('Configura API_PERU_TOKEN en el servidor para consultar representantes. Puedes continuar con la revisión documental.');
 let response:Response;
 try{response=await fetch('https://api.apiperu.pe/ruc/representantes',{method:'POST',headers:{Authorization:'Bearer '+token,Accept:'application/json','Content-Type':'application/json'},body:JSON.stringify({ruc}),cache:'no-store',signal:AbortSignal.timeout(10000)});}catch{throw new Error('API Perú no está disponible temporalmente. Reintenta o continúa con la revisión documental.');}
 if(!response.ok)throw new Error(response.status===429?'API Perú alcanzó el límite de consultas. Reintenta después o continúa con la revisión documental.':response.status===401||response.status===403?'Revisa la autorización de API Perú en la configuración del servidor.':'No se pudo consultar API Perú. Un resultado no disponible no demuestra que la persona no sea representante.');
 return normalizarRepresentantes(await response.json());
}
