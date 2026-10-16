'use client';
import {useEffect} from 'react';
export function useBorradorGuard(pendiente:boolean){
 useEffect(()=>{
  let permitido=false;document.body.dataset.borrador=String(pendiente);
  const salir=(e:BeforeUnloadEvent)=>{if(pendiente&&!permitido){e.preventDefault();e.returnValue='';}};
  const navegar=(e:MouseEvent)=>{
   if(!pendiente||permitido||e.defaultPrevented||e.button!==0)return;
   const enlace=(e.target as Element)?.closest?.('a[href]');if(!enlace)return;
   const destino=new URL(enlace.getAttribute('href')!,location.href);
   if(destino.href===location.href||destino.protocol==='javascript:')return;
   if(!confirm('¿Salir de este proceso? Los datos sin confirmar se perderán.')){e.preventDefault();e.stopImmediatePropagation();return;}
   permitido=true;document.body.dataset.borrador='false';
  };
  window.addEventListener('beforeunload',salir);document.addEventListener('click',navegar,true);
  return()=>{document.body.dataset.borrador='false';window.removeEventListener('beforeunload',salir);document.removeEventListener('click',navegar,true);};
 },[pendiente]);
}
