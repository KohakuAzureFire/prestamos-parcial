// src/lib/pdf.ts
'use client';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { Prestamo, Cuota, Cliente, Agencia } from '@/types/database';
import { formatFecha, formatMoneda } from './financiero';

export function generarPDF(
  prestamo: Prestamo & { clientes: Cliente; agencias: Agencia; cuotas: Cuota[] }
): void {
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
  const { agencias: agencia, cuotas } = prestamo;
  const cliente=prestamo.identidad_contrato?.nombres?prestamo.identidad_contrato:prestamo.clientes;

  // Header
  doc.setFillColor(15, 23, 42);
  doc.rect(0, 0, 210, 40, 'F');
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(18);
  doc.setFont('helvetica', 'bold');
  doc.text('CRONOGRAMA DE PAGOS', 105, 18, { align: 'center' });
  doc.setFontSize(11);
  doc.setFont('helvetica', 'normal');
  doc.text('Sistema de Préstamos', 105, 28, { align: 'center' });

  // Info del préstamo
  doc.setTextColor(15, 23, 42);
  doc.setFontSize(10);
  doc.setFont('helvetica', 'bold');
  doc.text('DATOS DEL PRÉSTAMO', 14, 52);

  autoTable(doc, {
    startY: 56, theme: 'plain',
    body: [
      ['Cliente', `${cliente.nombres} ${cliente.apellidos}`],
      [cliente.ruc?'RUC':'DNI', cliente.ruc||cliente.dni||'—'],
      ['Código del préstamo', 'PR-'+prestamo.id.slice(0,8).toUpperCase()],
      ['Agencia de origen', agencia.nombre],
      ['Fecha', formatFecha(new Date(prestamo.fecha_prestamo.slice(0,10)+'T00:00:00'))],
      ['Monto y plazo', `${formatMoneda(prestamo.monto)} · ${prestamo.plazo_meses} meses`],
      ['TEA y tasa mensual', '30 % · TEM 2,210445 %'],
    ], styles: {fontSize:9,cellPadding:2}, columnStyles:{0:{cellWidth:43,fontStyle:'bold'},1:{cellWidth:139}},
  });
  const y=(doc as jsPDF & {lastAutoTable:{finalY:number}}).lastAutoTable.finalY;

  // Tabla de cuotas
  autoTable(doc, {
    startY: y + 4,
    head: [['N°', 'Vencimiento', 'Cuota', 'Interés', 'Amortización', 'Saldo']],
    body: [...cuotas]
      .sort((a, b) => a.numero_cuota - b.numero_cuota)
      .map(c => [
        c.numero_cuota,
        formatFecha(new Date(c.fecha_vencimiento + 'T00:00:00')),
        formatMoneda(c.cuota_total),
        formatMoneda(c.interes),
        formatMoneda(c.amortizacion),
        formatMoneda(c.saldo),
      ]),
    styles: { fontSize: 8, cellPadding: 2 },
    headStyles: { fillColor: [15, 23, 42], textColor: 255, fontStyle: 'bold' },
    alternateRowStyles: { fillColor: [248, 250, 252] },
    columnStyles: {
      0: { halign: 'center', cellWidth: 10 },
      1: { halign: 'center', cellWidth: 30 },
      2: { halign: 'right' },
      3: { halign: 'right' },
      4: { halign: 'right' },
      5: { halign: 'right' },
    },
    foot: [[
      '',
      'TOTAL',
      formatMoneda(cuotas.reduce((s, c) => s + Number(c.cuota_total), 0)),
      formatMoneda(cuotas.reduce((s, c) => s + Number(c.interes), 0)),
      formatMoneda(cuotas.reduce((s, c) => s + Number(c.amortizacion), 0)),
      '',
    ]],
    footStyles: { fillColor: [30, 41, 59], textColor: 255, fontStyle: 'bold', fontSize: 8 },
  });

  // Footer
  const pageCount = (doc as unknown as { internal: { getNumberOfPages: () => number } }).internal.getNumberOfPages();
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i);
    doc.setFontSize(7);
    doc.setTextColor(150);
    doc.text(
      `Generado el ${formatFecha(new Date())} | Página ${i} de ${pageCount}`,
      105, 290, { align: 'center' }
    );
  }

  const nombreArchivo = `cronograma_${cliente.ruc||cliente.dni}_${prestamo.id.slice(0, 8)}.pdf`;
  doc.save(nombreArchivo);
}
