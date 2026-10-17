// src/lib/supabase/middleware.ts
import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          );
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const { data: { user } } = await supabase.auth.getUser();

  const { pathname } = request.nextUrl;
  const copiarCookies = (response: NextResponse) => {
    supabaseResponse.cookies.getAll().forEach(cookie => response.cookies.set(cookie));
    return response;
  };
  if (pathname === '/api/sesion') return supabaseResponse;
  const isAuthPage = pathname === '/login';
  const api = pathname.startsWith('/api/');
  let valida = false;
  let motivo = 'invalida';
  if (user) {
    const { data, error } = await supabase.rpc('control_sesion', { p_accion: 'estado' });
    valida = !error && data?.ok === true;
    motivo = data?.motivo || 'invalida';
    if (error && !isAuthPage) {
      return copiarCookies(NextResponse.json({ error: 'Control de sesiones no disponible. Comprueba su activación.' }, { status: 503, headers: { 'Cache-Control': 'no-store' } }));
    }
  }
  if (!valida && !isAuthPage) {
    if (api) return copiarCookies(NextResponse.json({ error: 'Vuelve a iniciar sesión.', motivo }, { status: 401 }));
    const url = request.nextUrl.clone();
    url.pathname = '/login'; url.search = ''; url.searchParams.set('sesion', motivo);
    return copiarCookies(NextResponse.redirect(url));
  }
  if (valida && isAuthPage) {
    const url = request.nextUrl.clone(); url.pathname = '/dashboard'; url.search = '';
    return copiarCookies(NextResponse.redirect(url));
  }
  return supabaseResponse;
}
