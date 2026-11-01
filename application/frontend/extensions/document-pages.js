// Shared preview/PDF page plan. The styled page is retained verbatim.
const normalize=s=>String(s||'').normalize('NFKC').toLocaleLowerCase('fr').replace(/[^\p{L}\p{N}]/gu,'');
function contents(node,out={text:'',images:[]}){
 if(node==null||typeof node==='boolean')return out;
 if(typeof node==='string'||typeof node==='number'){out.text+=node;return out;}
 if(Array.isArray(node)){node.forEach(n=>contents(n,out));return out;}
 const p=node.props||{};
 if(p.src)out.images.push(p.src);
 for(const v of Object.values(p.style||{}))if(typeof v==='string'&&v.includes('data:image/'))out.images.push(v);
 contents(p.children,out);return out;
}
export function missingBlocks(blocks,tree){
 const found=contents(tree);let text=normalize(found.text);const images=[...found.images];
 return blocks.filter(b=>{
  const lines=String(b.text||'').split('\n').map(normalize).filter(Boolean);
  const image=b.img;
  let missing=false;
  for(const line of lines){const at=text.indexOf(line);if(at<0)missing=true;else text=text.slice(0,at)+' '.repeat(line.length)+text.slice(at+line.length);}
  if(image){const at=images.findIndex(src=>src.includes(image));if(at<0)missing=true;else images.splice(at,1);}
  return missing;
 });
}
// Continuation text is split only at semantic separators or whitespace; never clipped.
// Atomic extension blocks remain atomic: the existing geometric guard refuses oversize blocks.
export function continuationBlocks(blocks,format){
 const max=format==='a5'?500:format==='wide'?650:1200,result=[];
 for(const b of blocks){
  if(!['p','quote','ul'].includes(b.type)||String(b.text||'').length<=max){result.push(b);continue;}
  let rest=String(b.text),part=0;
  while(rest.length){let end=Math.min(max,rest.length);if(end<rest.length){const space=rest.lastIndexOf(' ',end),line=rest.lastIndexOf('\n',end);end=Math.max(space,line)>0?Math.max(space,line):end;}
   result.push({...b,id:(b.id||'continuation')+'-part-'+part++,text:rest.slice(0,end)});rest=rest.slice(end).replace(/^\s+/,'');}
 }
 return result;
}
export function planDocumentPages(groups,renderStyled,format){
 const pages=[];
 groups.forEach((blocks,index)=>{
  pages.push({blocks,styled:!!renderStyled});
  if(renderStyled){const missing=missingBlocks(blocks,renderStyled(blocks,index,groups.length));
   const capacity={a4:760,a5:480,wide:360}[format]||480,cpl={a4:65,a5:45,wide:85}[format]||45;
   let group=[],height=0;
   const flush=()=>{if(group.length)pages.push({blocks:group,styled:false,continuation:true});group=[];height=0;};
   for(const block of continuationBlocks(missing,format)){
    if(block.type.startsWith('studio.')||block.type==='table'){flush();pages.push({blocks:[block],styled:false,continuation:true});continue;}
    const lines=String(block.text||'').split('\n').reduce((n,l)=>n+Math.max(1,Math.ceil(l.length/cpl)),0);
    const size=block.type==='h1'?50+lines*42:block.type==='h2'||block.type==='h3'?30+lines*32:30+lines*26;
    if(height+size>capacity)flush();group.push(block);height+=size;
   }
   flush();}
 });
 return pages;
}
