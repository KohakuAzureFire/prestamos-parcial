'use client';

import { useState } from 'react';
import Icon from '@/components/Icon';
import { generarPDF } from '@/lib/pdf';
import { Prestamo, Cliente, Agencia, Cuota } from '@/types/database';

export interface DescargaPDFProps {
  prestamo: Prestamo & { clientes: Cliente; agencias: Agencia; cuotas: Cuota[] };
}

export default function DescargaPDF({ prestamo }: DescargaPDFProps) {
  const [descargando, setDescargando] = useState(false);
  const [error, setError] = useState('');

  const handleDescargar = async () => {
    setDescargando(true);
    setError('');
    try {
      generarPDF(prestamo);
    } catch (e) {
      setError('Error al generar PDF. Intente nuevamente.');
      console.error(e);
    }
    setDescargando(false);
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 6 }}>
      <button
        id="btn-descargar-pdf"
        className="btn btn-primary"
        onClick={handleDescargar}
        disabled={descargando}
      >
        {descargando ? <><span className="spinner" /> Generando...</> : <><Icon name="download"/> Descargar PDF</>}
      </button>
      {error && <div className="alert alert-error" style={{ fontSize: 12 }}>{error}</div>}
    </div>
  );
}

export { DescargaPDF };
