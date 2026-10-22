import type { CSSProperties } from 'react';
const paths: Record<string, string> = {
  edit: 'M12 20H4v-8 M15 4l5 5 M10 19l-5 1 1-5L17 4a2 2 0 0 1 3 3z',
  chevron: 'M6 9l6 6 6-6',
  print: 'M6 9V3h12v6 M6 18H3V9h18v9h-3 M6 14h12v7H6z M17 12h1',
  mail: 'M3 5h18v14H3z M3 5l9 7 9-7',
  lock: 'M5 10h14v11H5z M8 10V6a4 4 0 0 1 8 0v4 M12 14v3',
  user: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8 M4 21v-2a7 7 0 0 1 14 0v2z',
  clock: 'M12 8v5l3 2 M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20',
  coins: 'M4 5c0-4 16-4 16 0s-16 4-16 0 M4 5v14c0 4 16 4 16 0V5 M4 12c0 4 16 4 16 0',
  available: 'M12 3a9 9 0 1 1-9 9 M3 3v6h6 M12 7v5l3 2',
  download: 'M12 3v12 M7 10l5 5 5-5 M4 15v6h16v-6',
  calendar: 'M8 2v4 M16 2v4 M3 9h18 M3 4h18v18H3z',
  building: 'M3 21h18 M5 21V8 M19 21V8 M2 7l10-5 10 5z M9 10v8 M15 10v8',
  wallet: 'M3 6h16v15H3z M3 6V3h14v3 M15 12h6v5h-6z',
  shield: 'M12 2l8 4v6c0 5-8 10-8 10S4 17 4 12V6z M8 12l3 3 5-6',
  check: 'M5 12l4 4L19 6',
  loans: 'M6 3h9l3 3v15H6z M9 10h6 M9 14h6 M9 18h4',
  clients: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2 M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8 M18 8a3 3 0 0 1 0 6 M22 21v-2a4 4 0 0 0-3-3.87',
  plus: 'M12 5v14 M5 12h14', logout: 'M14 8V3H3v18h11v-5 M8 12h13 M17 8l4 4-4 4',
  menu: 'M4 6h16 M4 12h16 M4 18h16', search: 'M21 21l-5-5 M10.5 17a6.5 6.5 0 1 0 0-13 6.5 6.5 0 0 0 0 13',
  eye: 'M2 12s3-7 10-7 10 7 10 7-3 7-10 7S2 12 2 12 M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6',
};
export default function Icon({name, style}: {name: string; style?: CSSProperties}) {
 return <svg style={style} width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={paths[name] || paths.loans}/></svg>;
}
