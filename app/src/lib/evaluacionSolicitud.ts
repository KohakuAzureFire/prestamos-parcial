// Límite operativo del formulario; no presupone una longitud registral universal.
export const CODIGO_CERTIFICADO_MAX=80;
export function errorCodigoCertificado(codigo:string){
 if(!codigo)return 'Copia el código de verificación que figura en el certificado.';
 if(codigo.length>CODIGO_CERTIFICADO_MAX)return 'El código admite hasta 80 caracteres.';
 if(!/^[A-Za-z0-9][A-Za-z0-9/-]*$/.test(codigo))return 'Usa letras, números, guion o barra, tal como aparecen en el certificado.';
 return '';
}
export function errorEvaluacion(estado:unknown,motivo:unknown,codigo:unknown,facultades:unknown,individual:unknown){
 if(!['aprobada','observada','rechazada'].includes(String(estado)))return 'Selecciona un resultado válido.';
 if(typeof motivo!=='string'||motivo.length>1000)return 'Las observaciones admiten hasta 1000 caracteres.';
 if(estado!=='aprobada'&&motivo.trim().length<10)return 'Explica el motivo de la observación o rechazo (mínimo 10 caracteres).';
 if(estado==='aprobada'){
  const error=errorCodigoCertificado(typeof codigo==='string'?codigo.trim():'');if(error)return error;
  if(facultades!==true||individual!==true)return 'Confirma la revisión del certificado, las facultades y la firma individual.';
 }
 return '';
}
