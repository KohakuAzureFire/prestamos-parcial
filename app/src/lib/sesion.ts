'use client';
import { createClient } from './supabase/client';
export const mensajesSesion: Record<string, string> = {
 inactividad: 'La sesión se cerró tras 15 minutos sin actividad. Vuelve a ingresar.',
 reemplazada: 'Tu cuenta inició sesión en otro lugar. Vuelve a ingresar si deseas continuar aquí.',
 cerrada: 'La sesión ha finalizado.',
 invalida: 'Vuelve a iniciar sesión para continuar.',
 cuenta: 'Esta cuenta no tiene acceso como asesor.',
};
export async function cerrarSesion(motivo = 'cerrada') {
 document.body.dataset.borrador = 'false';
 try {
  await fetch('/api/sesion', { method: 'DELETE', signal: AbortSignal.timeout(4000) });
  await createClient().auth.signOut({ scope: 'local' });
 } finally { window.location.replace('/login?sesion=' + encodeURIComponent(motivo)); }
}
