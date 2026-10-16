// src/app/dashboard/layout.tsx
export const dynamic = 'force-dynamic';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import Sidebar from '@/components/Sidebar';
import Icon from '@/components/Icon';

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) redirect('/login');

  const { data: asesor } = await supabase
    .from('asesores')
    .select('*, agencias(*)')
    .eq('id', user.id)
    .single();

  if (!asesor?.activo) redirect('/login?error=cuenta');

  const agencia=asesor?.agencias?.nombre || 'Agencia asignada';
  const agenciaLabel=/^agencia\b/i.test(agencia)?agencia:`Agencia ${agencia}`;
  return (
    <div className="app-shell">
      <Sidebar asesor={asesor} />
      <div className="app-workspace">
        <header className="app-topbar">

          <div className="topbar-user"><span className="user-symbol"><Icon name="user"/></span><span>{asesor?.nombre_completo || 'Asesor'} <span className="topbar-role">· Asesor</span></span></div>
          <div className="topbar-agency"><Icon name="building"/><span>{agenciaLabel}</span></div>
          <time><Icon name="calendar"/>{new Intl.DateTimeFormat('es-PE',{day:'numeric',month:'short',year:'numeric',timeZone:'America/Lima'}).format(new Date())}</time>
        </header>
        <main id="contenido" className="app-main">{children}</main>
      </div>
    </div>
  );
}
