import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';
async function ejecutar(request: NextRequest, accion: string) {
  const responder = (data: unknown, status = 200) => NextResponse.json(data, { status, headers: { 'Cache-Control': 'no-store' } });
  const origen = request.headers.get('origin');
  const mismoOrigen = origen && (() => { try { const url = new URL(origen); return ['https:', 'http:'].includes(url.protocol) && url.host === request.headers.get('host'); } catch { return false; } })();
  if (request.method !== 'GET' && !mismoOrigen) {
    return responder({ ok: false, motivo: 'origen' }, 403);
  }
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return responder({ ok: false, motivo: 'invalida' }, 401);
  const { data, error } = await supabase.rpc('control_sesion', { p_accion: accion });
  if (error) return responder({ ok: false, motivo: 'servicio', mensaje: 'No se pudo validar la sesión. Comprueba que el control de sesiones esté activado.' }, 503);
  return responder(data, data?.ok ? 200 : 401);
}
export async function GET(request: NextRequest) { return ejecutar(request, 'estado'); }
export async function DELETE(request: NextRequest) { return ejecutar(request, 'cerrar'); }
export async function POST(request: NextRequest) {
  const body = await request.json().catch(() => null);
  if (!['iniciar', 'actividad'].includes(body?.accion)) return NextResponse.json({ ok: false }, { status: 400 });
  return ejecutar(request, body.accion);
}
