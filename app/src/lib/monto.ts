export function errorMonto(valor:string,disponible:number){
 if(!/^\d+(?:\.\d{1,2})?$/.test(valor)||!Number.isFinite(Number(valor))||Number(valor)<=0)return 'Ingresa un monto mayor que 0, con hasta 2 decimales. Ejemplo: 0.01.';
 if(Number(valor)>disponible)return 'El monto supera el capital disponible.';
 return '';
}
