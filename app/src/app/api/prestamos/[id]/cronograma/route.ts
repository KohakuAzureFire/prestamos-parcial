import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { htmlCronograma, type CronogramaImprimible } from '@/lib/cronogramaImprimible';
export const dynamic = 'force-dynamic';

export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!/^[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}$/i.test(id)) return NextResponse.json({ mensaje: 'Préstamo no encontrado.' }, { status: 404 });
  const s = await createClient();
  const { data: { user } } = await s.auth.getUser();
  if (!user) return NextResponse.json({ mensaje: 'Inicia sesión nuevamente.' }, { status: 401 });
  const { data, error } = await s.from('prestamos').select('*,clientes(*),agencias(nombre),cuotas(*)').eq('id', id).eq('estado', 'confirmado').maybeSingle();
  if (error || !data) return NextResponse.json({ mensaje: 'Préstamo no disponible para tu agencia.' }, { status: 404 });
  return new Response(htmlCronograma(data as CronogramaImprimible), { headers: {
    'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'private, no-store',
    'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'self'",
  }});
}
