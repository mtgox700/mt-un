import React from 'react';
import {prepareClassicBlock,prepareClassicPage} from './classic-layout.js';
const h=React.createElement;
const families={philosopher:'Philosopher, Georgia, serif',inter:'Inter, sans-serif',montserrat:'Montserrat, Inter, sans-serif',lora:'Lora, Georgia, serif',georgia:'Georgia, serif'};
export function classicPage(d,blocks,i,count,docBlocks,logo){
 const chr={...d.charte,logo},dfmt={a4:{w:794,h:1123,pad:54,t:1},a5:{w:559,h:794,pad:38,t:.92},wide:{w:1123,h:632,pad:58,t:1.22}}[d.format],ts=dfmt.t*({compact:.92,confort:1.1}[chr.density]||1),tfont=families[chr.titleFont],bfont=families[chr.bodyFont],ac=chr.accent;
 if(!tfont||!bfont)throw Error('Unknown font');
 const self={extDocBlock:t=>docBlocks.find(b=>b.type===t),extSafe:(_id,_what,fn)=>fn(),extLines:s=>String(s||'').split('\n').map(x=>x.trim()).filter(Boolean)};
 const pg=prepareClassicPage({dfmt,dz:1,chr,ts,tfont,bfont,ac,grp:blocks,blockView:b=>prepareClassicBlock(b,{chr,ts,tfont,bfont,ac,self}),i,count});
 function block(b){
  if(b.isExt)return h('div',{key:b.id},b.el);
  if(b.isUl)return h('div',{key:b.id,style:b.st},b.items.map(it=>h('div',{key:it.key,style:b.itemSt},h('span',{style:b.bulletSt},'■'),h('span',{style:{minWidth:0}},it.text))));
  if(b.isTable)return h('div',{key:b.id,style:b.st},b.cells.map(c=>h('div',{key:c.key,style:c.st},c.text)));
  return h(b.isTag?'span':b.isH1?'h2':b.isH2?'h3':b.isH3?'h4':b.isP?'p':'div',{key:b.id,style:b.st},b.text);
 }
 return h('div',{style:{...pg.st,borderRadius:0,boxShadow:'none'}},pg.showHeader?h('div',{style:pg.headerSt},h('span',{style:{minWidth:0}},h('span',{style:pg.emetteurSt},pg.emetteur),h('span',{style:pg.sectionSt},pg.section)),pg.hasLogo?h('span',{style:pg.logoSt}):null):null,h('div',{'data-classic-body':true,style:pg.bodySt},pg.blocks.map(block)),pg.showFooter?h('div',{style:pg.footerSt},h('span',{style:{minWidth:0,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}},pg.contact),h('span',{style:pg.pageNoSt},pg.pageNo)):null);
}
