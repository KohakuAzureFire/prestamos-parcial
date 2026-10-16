export const dynamic='force-dynamic';import Pagos from '@/components/Pagos';
export default async function Pagina({searchParams}:{searchParams:Promise<{buscar?:string}>}){return <Pagos busquedaInicial={(await searchParams).buscar}/>}
