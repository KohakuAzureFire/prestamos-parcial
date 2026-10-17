'use client';
import { useEffect, useRef, useState } from 'react';
import Icon from './Icon';
import { cerrarSesion } from '@/lib/sesion';
type Estado = { ok: boolean; motivo?: string; vence: string; servidor: string };
export default function ControlSesion({ usuario }: { usuario: string }) {
 const [segundos, setSegundos] = useState<number | null>(null);
 const [problema, setProblema] = useState(false);
 const [continuando, setContinuando] = useState(false);
 const dialogo = useRef<HTMLDialogElement>(null);
 const renovar = useRef<() => Promise<void>>(async () => {});
 const salir = useRef(false);
 useEffect(() => {
  let activo = true, limite = 0, ultimoEnvio = 0, pendiente = false, peticion = false;
  const clave = 'sesion-actividad:' + usuario;
  const terminar = (motivo: string) => { if (!salir.current) { salir.current = true; void cerrarSesion(motivo); } };
  const consultar = async (actividad = false) => {
   if (peticion || salir.current) return;
   peticion = true;
   try {
    const r = await fetch('/api/sesion', actividad ? { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ accion: 'actividad' }), signal: AbortSignal.timeout(6000) } : { cache: 'no-store', signal: AbortSignal.timeout(6000) });
    const estado: Estado = await r.json();
    if (!activo) return;
    if (r.status === 401) { terminar(estado.motivo || 'invalida'); return; }
    if (!r.ok) throw new Error('servicio');
    limite = Date.now() + Math.max(0, Date.parse(estado.vence) - Date.parse(estado.servidor));
    setSegundos(Math.max(0, Math.ceil((limite - Date.now()) / 1000))); setProblema(false);
    if (actividad) { ultimoEnvio = Date.now(); try { localStorage.setItem(clave, String(Date.now())); } catch { /* Sin almacenamiento, se conserva el sondeo. */ } }
   } catch { if (activo) setProblema(true); }
   finally { peticion = false; }
  };
  renovar.current = async () => { await consultar(true); };
  const actividad = (e: Event) => {
   if (!e.isTrusted || salir.current) return;
   pendiente = true;
   if (Date.now() - ultimoEnvio >= 10000) { pendiente = false; void consultar(true); }
  };
  const sincronizar = (e: StorageEvent) => { if (e.key === clave) void consultar(); };
  const alVolver = () => { if (document.visibilityState === 'visible') void consultar(); };
  const eventos = ['pointerdown', 'keydown', 'pointermove', 'scroll', 'touchstart'];
  eventos.forEach(e => window.addEventListener(e, actividad, { passive: true, capture: true }));
  window.addEventListener('storage', sincronizar); document.addEventListener('visibilitychange', alVolver); window.addEventListener('focus', alVolver);
  void consultar();
  const reloj = setInterval(() => {
   if (!limite || salir.current) return;
   const restante = Math.max(0, Math.ceil((limite - Date.now()) / 1000)); setSegundos(restante);
   if (!restante && !peticion) { void consultar().then(() => { if (activo && limite <= Date.now()) terminar('inactividad'); }); }
   else if (pendiente && Date.now() - ultimoEnvio >= 10000) { pendiente = false; void consultar(true); }
  }, 1000);
  const sondeo = setInterval(() => { void consultar(); }, 15000);
  return () => { activo = false; clearInterval(reloj); clearInterval(sondeo); eventos.forEach(e => window.removeEventListener(e, actividad, true)); window.removeEventListener('storage', sincronizar); window.removeEventListener('focus', alVolver); document.removeEventListener('visibilitychange', alVolver); };
 }, [usuario]);
 const advertir = segundos !== null && segundos > 0 && segundos <= 60;
 useEffect(() => { const d = dialogo.current; if (advertir && d && !d.open) d.showModal(); else if (!advertir && d?.open) d.close(); }, [advertir]);
 const continuar = async () => { setContinuando(true); await renovar.current(); setContinuando(false); };
 const tiempo = segundos === null ? '—' : `${Math.floor(segundos / 60).toString().padStart(2, '0')}:${(segundos % 60).toString().padStart(2, '0')}`;
 return <>
  <span className={`session-chip ${segundos !== null && segundos <= 60 ? 'session-danger' : segundos !== null && segundos <= 120 ? 'session-warning' : ''}`} title={problema ? 'Sin conexión. Reintentando…' : 'Tiempo restante sin actividad. Se renueva al usar el sistema.'}><Icon name="clock"/><span>Sesión <strong>{tiempo}</strong></span>{problema && <span aria-label="Sin conexión">·</span>}</span>
  <dialog ref={dialogo} className="session-dialog" aria-labelledby="session-title" onCancel={e => e.preventDefault()}>
   <span className="session-dialog-icon"><Icon name="clock"/></span><h2 id="session-title">Tu sesión está por terminar</h2>
   <p>Se cerrará por inactividad en <strong>{tiempo}</strong>. Continúa para conservar tu sesión.</p>
   {problema && <p role="alert">No se pudo renovar la sesión. Revisa tu conexión y vuelve a intentarlo.</p>}
   <div className="session-actions"><button className="btn btn-secondary" onClick={() => void cerrarSesion()}>Cerrar sesión</button><button className="btn btn-primary" onClick={continuar} disabled={continuando} autoFocus>{continuando ? 'Renovando…' : 'Continuar sesión'}</button></div>
  </dialog>
 </>;
}
