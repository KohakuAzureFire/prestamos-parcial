'use client';

import { useState, useEffect } from 'react';
import { createClient } from '@/lib/supabase/client';
import { useRouter } from 'next/navigation';
import Brand from '@/components/Brand';
import Icon from '@/components/Icon';
import { mensajesSesion } from '@/lib/sesion';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showPassword,setShowPassword]=useState(false);
  const router = useRouter();
  const supabase = createClient();

  useEffect(() => {
    const motivo = new URLSearchParams(window.location.search).get('sesion');
    if (motivo) queueMicrotask(() => setError(mensajesSesion[motivo] || 'Vuelve a iniciar sesión.'));
  }, []);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) {
      setError('Credenciales inválidas. Verifique su correo y contraseña.');
    } else {
      try {
        const response = await fetch('/api/sesion', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ accion: 'iniciar' }) });
        const estado = await response.json();
        if (!response.ok || !estado.ok) throw new Error(estado.mensaje || mensajesSesion[estado.motivo] || 'No se pudo iniciar la sesión.');
        router.push('/dashboard');
        router.refresh();
      } catch (err) {
        await supabase.auth.signOut({ scope: 'local' });
        setError(err instanceof Error ? err.message : 'No se pudo iniciar la sesión.');
      }
    }
    setLoading(false);
  };

  return <div className="login-shell"><div className="login-card animate-fade-in">
    <Brand tagline/><h1>Iniciar sesión</h1><p className="page-subtitle">Accede con tu cuenta de asesor.</p>
    <form onSubmit={handleLogin}>
      {error&&<div role="alert" className="alert alert-error">{error}</div>}
      <div className="form-group"><label className="form-label" htmlFor="email">Correo electrónico</label><div className="input-with-icon"><Icon name="mail"/><input id="email" type="email" className="form-input" value={email} onChange={e=>setEmail(e.target.value)} placeholder="asesor@empresa.com" required autoComplete="email"/></div></div>
      <div className="form-group"><label className="form-label" htmlFor="password">Contraseña</label><div className="password-field input-with-icon"><Icon name="lock"/><input id="password" type={showPassword?'text':'password'} className="form-input" value={password} onChange={e=>setPassword(e.target.value)} placeholder="••••••••" required autoComplete="current-password"/><button type="button" className="password-toggle" aria-label={showPassword?'Ocultar contraseña':'Mostrar contraseña'} aria-pressed={showPassword} onClick={()=>setShowPassword(!showPassword)}><Icon name="eye"/></button></div></div>
      <button type="submit" id="btn-login" className="btn btn-primary" disabled={loading}>{loading?<><span className="spinner"/> Ingresando…</>:'Ingresar'}</button>
    </form>
    <p className="page-subtitle" style={{fontSize:11,marginBottom:0,marginTop:20}}>Acceso exclusivo para asesores autorizados.</p>
  </div></div>;
}
