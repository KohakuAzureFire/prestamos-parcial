import {etiquetas,claseEstado} from '@/lib/operaciones';
export default function Estado({valor}:{valor:string}){return <span className={'badge '+claseEstado(valor)}>{etiquetas[valor]||valor}</span>}
