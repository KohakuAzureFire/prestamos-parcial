export default function Brand({tagline=false}:{tagline?:boolean}) {
 return <span className="brand"><span className="brand-mark" aria-hidden="true"><i/><i/><i/></span><span className="brand-copy"><span>Préstamos</span>{tagline&&<small>Impulsamos más oportunidades</small>}</span></span>;
}
