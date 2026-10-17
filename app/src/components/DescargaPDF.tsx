'use client';

import { useState, type SyntheticEvent } from 'react';
import Icon from '@/components/Icon';
import type { Prestamo, Cliente, Agencia, Cuota } from '@/types/database';

export interface DescargaPDFProps {
  prestamo: Prestamo & { clientes: Cliente; agencias: Agencia; cuotas: Cuota[] };
}

export default function DescargaPDF({ prestamo }: DescargaPDFProps) {
  const [descargando, setDescargando] = useState(false);
  const [error, setError] = useState('');
  const base = '/api/prestamos/' + prestamo.id;

  function cerrar(event: SyntheticEvent<HTMLElement>) {
    event.currentTarget.closest('details')?.removeAttribute('open');
  }
  function abrir(event: SyntheticEvent<HTMLDetailsElement>) {
    const actual = event.currentTarget;
    if (actual.open) actual.parentElement?.querySelectorAll('details').forEach(d => {
      if (d !== actual) d.open = false;
    });
  }
  async function descargar(event: SyntheticEvent<HTMLButtonElement>) {
    cerrar(event);
    setDescargando(true);
    setError('');
    try {
      const { generarPDF } = await import('@/lib/pdf');
      generarPDF(prestamo);
    } catch {
      setError('No se pudo generar el PDF. Intenta nuevamente.');
    } finally {
      setDescargando(false);
    }
  }

  return <div className="document-actions-wrapper">
    <div className="document-actions" aria-label="Documentos del préstamo">
      {(['cronograma', 'contrato'] as const).map(tipo => <details
        key={tipo} className="document-menu" onToggle={abrir}
        onBlur={e => { if (!e.currentTarget.contains(e.relatedTarget as Node | null)) e.currentTarget.open = false; }}
        onKeyDown={e => { if (e.key === 'Escape') { e.currentTarget.open = false; e.currentTarget.querySelector('summary')?.focus(); } }}>
        <summary className={'btn ' + (tipo === 'cronograma' ? 'btn-primary' : 'btn-document-contract')}>
          <Icon name={tipo === 'cronograma' ? 'calendar' : 'loans'}/>
          {tipo === 'cronograma' ? 'Cronograma' : 'Contrato'}<Icon name="chevron"/>
        </summary>
        <div className="document-menu-options">
          {tipo === 'cronograma'
            ? <button id="btn-descargar-pdf" type="button" disabled={descargando} onClick={descargar}><Icon name="download"/>{descargando ? 'Generando…' : 'Descargar PDF'}</button>
            : <a href={base + '/contrato'} onClick={cerrar}><Icon name="download"/>Descargar Word</a>}
          <a href={base + (tipo === 'cronograma' ? '/cronograma' : '/contrato?formato=imprimir')} target="_blank" rel="noopener noreferrer" onClick={cerrar}><Icon name="print"/>Imprimir</a>
        </div>
      </details>)}
    </div>
    {error && <p className="alert alert-error" role="alert">{error}</p>}
  </div>;
}

export { DescargaPDF };
