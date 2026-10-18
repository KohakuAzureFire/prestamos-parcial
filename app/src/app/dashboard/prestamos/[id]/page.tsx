// src/app/dashboard/prestamos/[id]/page.tsx
export const dynamic = 'force-dynamic';
import {formatImporte as formatMoneda} from '@/lib/presentacion';
import { createClient } from '@/lib/supabase/server';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import DocumentosCliente from '@/components/DocumentosCliente';
import DescargaPDF from '@/components/DescargaPDF';
import {Cobranza} from '@/components/Pagos';
import Estado from '@/components/Estado';
import {fechaPeru} from '@/lib/operaciones';
import { formatFecha } from '@/lib/financiero';

interface Props { params: Promise<{ id: string }>; searchParams: Promise<{ nuevo?: string }> }

export default async function DetallePrestamo({ params, searchParams }: Props) {
  const { id } = await params;
  const { nuevo } = await searchParams;
  const supabase = await createClient();

  const { data: prestamo } = await supabase
    .from('prestamos')
    .select(`
      *,
      clientes(*),
      agencias(*),
      asesores(nombre_completo),
      cuotas(*)
    `)
    .eq('id', id)
    .single();

  if (!prestamo) notFound();

  const {data:consulta,error:ec}=await supabase.rpc('buscar_cobranza',{p_busqueda:id});
  if(ec)throw new Error('No se pudo consultar el estado de las cuotas.');
  const cobro=(consulta as Cobranza[])[0];
  const pagadas=new Set(cobro.cuotas.filter(c=>c.pagada).map(c=>c.numero_cuota));
  const totalPagado=cobro.cuotas.filter(c=>c.pagada).reduce((s,c)=>s+Number(c.cuota_total),0);
  const deudaPendiente=cobro.cuotas.filter(c=>!c.pagada).reduce((s,c)=>s+Number(c.cuota_total),0);
  const cuotas = ((prestamo.cuotas as unknown[]) ?? []) as {
    numero_cuota: number; fecha_vencimiento: string; cuota_total: number;
    interes: number; amortizacion: number; saldo: number;
  }[];
  cuotas.sort((a, b) => a.numero_cuota - b.numero_cuota);

  const cliente = prestamo.clientes as { ruc?:string|null;dni: string; nombres: string; apellidos: string };
  const agencia = prestamo.agencias as { nombre: string };
  const asesor = prestamo.asesores as { nombre_completo: string };

  const totalCuotas = cuotas.reduce((s, c) => s + Number(c.cuota_total), 0);
  const totalIntereses = cuotas.reduce((s, c) => s + Number(c.interes), 0);

  return <div className="loan-detail-page animate-fade-in">
   <Link className="breadcrumb" href="/dashboard/prestamos">← Volver a préstamos</Link>
   <div className="page-heading"><div><div className="detail-title"><h1>Detalle del préstamo PR-{prestamo.id.slice(0,8).toUpperCase()}</h1><Estado valor={deudaPendiente===0?'cancelado':'activo'}/></div><p>Condiciones confirmadas e historial de cobros</p></div><div className="action-group"><DescargaPDF prestamo={prestamo as Parameters<typeof DescargaPDF>[0]['prestamo']}/></div></div>
   {nuevo&&<div className="alert alert-success confirmation-banner"><span className="confirmation-check">✓</span>Préstamo confirmado. Cronograma guardado.</div>}
   <section className="card confirmation-summary"><h2>Datos del préstamo</h2><dl className="loan-meta detail-meta"><div className="meta-customer"><dt>Cliente</dt><dd>{cliente?.nombres} {cliente?.apellidos}<DocumentosCliente cliente={cliente} completo/></dd></div>{prestamo.identidad_contrato?.modalidad&&<div><dt>Modalidad</dt><dd>{prestamo.identidad_contrato.modalidad==='dni'?'Personal · DNI':prestamo.identidad_contrato.ruc?.startsWith('20')?'Empresa · RUC 20':'Negocio · RUC 10'}</dd></div>}<div><dt>Monto</dt><dd>{formatMoneda(Number(prestamo.monto))}</dd></div><div><dt>Plazo</dt><dd>{prestamo.plazo_meses} meses</dd></div><div><dt>TEA / TEM</dt><dd>30 %<small>TEM 2,210445 %</small></dd></div><div><dt>Fecha</dt><dd>{formatFecha(new Date(prestamo.fecha_prestamo.slice(0,10)+'T00:00:00'))}</dd></div><div><dt>Agencia</dt><dd>{agencia?.nombre}</dd></div><div><dt>Asesor</dt><dd>{asesor?.nombre_completo || 'Asesor de origen'}</dd></div></dl><p className="detail-interest">Interés total programado: <strong>{formatMoneda(totalIntereses)}</strong></p></section>
   <div className="summary-grid">{[['Total a pagar',totalCuotas],['Total pagado',totalPagado],['Saldo por pagar',deudaPendiente]].map(([l,v])=><div className="stat-card capital-card" key={l}><div><span className="stat-label">{l}</span><strong className="stat-value">{formatMoneda(Number(v))}</strong></div></div>)}</div>
   <div className="loan-actions">{deudaPendiente>0&&<Link className="btn btn-primary" href={'/dashboard/pagos?prestamo_id='+id}>Registrar pago</Link>}</div>
   <section className="card schedule-card"><div className="section-heading"><div><h2>Cronograma guardado</h2><p className="page-subtitle">Solo lectura · Sistema francés</p></div><span className="badge badge-info">TEA 30 % · Base 360 días</span></div>
    <div className="table-wrapper"><table><thead><tr><th>N.º</th><th>Vencimiento</th><th>Cuota</th><th>Interés</th><th>Capital</th><th>Saldo programado</th><th>Estado de cuota</th></tr></thead><tbody>{cuotas.map(c=><tr key={c.numero_cuota}><td>{c.numero_cuota}</td><td>{formatFecha(new Date(c.fecha_vencimiento.slice(0,10)+'T00:00:00'))}</td><td><strong>{formatMoneda(c.cuota_total)}</strong></td><td>{formatMoneda(c.interes)}</td><td>{formatMoneda(c.amortizacion)}</td><td className={c.saldo===0?'success-text':''}>{formatMoneda(c.saldo)}</td><td><span className={'badge '+(pagadas.has(c.numero_cuota)?'badge-success':c.fecha_vencimiento<fechaPeru()?'badge-danger':'badge-warning')}>{Number(c.cuota_total)===0?'Sin importe':pagadas.has(c.numero_cuota)?'Pagada':c.fecha_vencimiento<fechaPeru()?'Vencida':'Pendiente'}</span></td></tr>)}</tbody><tfoot><tr><td colSpan={2}>Total</td><td>{formatMoneda(totalCuotas)}</td><td>{formatMoneda(totalIntereses)}</td><td>{formatMoneda(cuotas.reduce((s,c)=>s+c.amortizacion,0))}</td><td>{formatMoneda(0)}</td><td></td></tr></tfoot></table></div>
    <div className="schedule-footer"><span>El cronograma se conserva tal como fue confirmado.</span><span>Los cobros no modifican las condiciones originales.</span></div>
   </section><section className="card"><h2>Historial de cobros</h2><div className="receipt-list">{cobro.pagos.map(p=><article key={p.id}><strong>{formatMoneda(p.importe)}</strong><p>{new Date(p.created_at).toLocaleString('es-PE',{timeZone:'America/Lima'})} · {p.agencia} · {p.asesor}</p><Link className="text-link" href={'/dashboard/pagos/'+p.id}>Ver constancia</Link></article>)}</div>{!cobro.pagos.length&&<p className="empty-state">Aún no se registraron cobros.</p>}</section>
  </div>;
}
