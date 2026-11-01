// Isolated PDF preflight: read geometry only, never resize or rearrange the document.
export function verifyPDFLayout() {
 const epsilon=2,canvas=document.createElement('canvas'),ctx=canvas.getContext('2d');
 if(!ctx)return false;
 const outside=(r,b,x=true,y=true)=>(x&&(r.left<b.left-epsilon||r.right>b.right+epsilon))||(y&&(r.top<b.top-epsilon||r.bottom>b.bottom+epsilon));
 function inkRect(rect,node,page) {
  const css=getComputedStyle(node.parentElement);
  ctx.font=[css.fontStyle,css.fontWeight,css.fontSize,css.fontFamily].join(' ');
  const text=css.textTransform==='uppercase'?node.textContent.toUpperCase():css.textTransform==='lowercase'?node.textContent.toLowerCase():node.textContent;
  const m=ctx.measureText(text);
  if(!Number.isFinite(m.fontBoundingBoxAscent)||!Number.isFinite(m.fontBoundingBoxDescent))return rect;
  let angle=0;
  for(let p=node.parentElement;p&&p!==page;p=p.parentElement) {
   const t=getComputedStyle(p).transform;
   if(t!=='none') {
    const a=new DOMMatrix(t);
    // Only rigid rotations are reconstructed; other transforms stay conservative.
    if(!a.is2D||Math.abs(Math.hypot(a.a,a.b)-1)>.001||Math.abs(a.a-a.d)>.001||Math.abs(a.b+a.c)>.001)return rect;
    angle+=Math.atan2(a.b,a.a);
   }
  }
  const c=Math.cos(angle),s=Math.sin(angle),ac=Math.abs(c),as=Math.abs(s),den=ac*ac-as*as;
  if(Math.abs(den)<.01)return rect;
  const w=(rect.width*ac-rect.height*as)/den,h=(rect.height*ac-rect.width*as)/den;
  const top=Math.max(0,m.fontBoundingBoxAscent-m.actualBoundingBoxAscent),bottom=Math.max(0,m.fontBoundingBoxDescent-m.actualBoundingBoxDescent);
  const cx=(rect.left+rect.right)/2,cy=(rect.top+rect.bottom)/2;
  const corners=[[-w/2,-h/2+top],[w/2,-h/2+top],[-w/2,h/2-bottom],[w/2,h/2-bottom]].map(([x,y])=>[cx+x*c-y*s,cy+x*s+y*c]);
  return {left:Math.min(...corners.map(p=>p[0])),right:Math.max(...corners.map(p=>p[0])),top:Math.min(...corners.map(p=>p[1])),bottom:Math.max(...corners.map(p=>p[1]))};
 }
 for(const page of document.querySelectorAll('section')) {
  const bounds=page.getBoundingClientRect(),walker=document.createTreeWalker(page,NodeFilter.SHOW_TEXT);
  while(walker.nextNode()) {
   const node=walker.currentNode,el=node.parentElement;
   if(!node.textContent.trim()||el.closest('[data-pdf-decoration]'))continue;
   const range=document.createRange();range.selectNodeContents(node);
   for(const raw of range.getClientRects()) {
    if(!raw.width||!raw.height)continue;
    const r=inkRect(raw,node,page);
    if(outside(r,bounds))return false;
    for(let p=el;p&&p!==page;p=p.parentElement) {
     const css=getComputedStyle(p),x=/hidden|clip|scroll|auto/.test(css.overflowX),y=/hidden|clip|scroll|auto/.test(css.overflowY);
     if((x||y)&&outside(r,p.getBoundingClientRect(),x,y))return false;
    }
   }
  }
 }
 return [...document.querySelectorAll('[data-classic-body]')].every(e=>e.scrollHeight<=e.clientHeight+1&&e.scrollWidth<=e.clientWidth+1);
}
