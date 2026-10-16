import type { Metadata } from 'next';
import './globals.css';
import localFont from 'next/font/local';
const inter=localFont({src:'./fonts/inter-latin.woff2',variable:'--font-inter',display:'swap',weight:'100 900'});



export const metadata: Metadata = {
  title: 'Sistema de Préstamos',
  description: 'Gestión de préstamos con amortización francesa, TEA 30%',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <body className={inter.variable}>{children}</body>
    </html>
  );
}
