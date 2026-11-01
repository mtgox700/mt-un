// Product PDF renderer: only the bundled official extension executes, never supplied code.
import fs from 'node:fs';
import {planDocumentPages,continuationBlocks} from './document-pages.js';
import {verifyPDFLayout} from './pdf-overflow.js';
import React from 'react';
import {classicPage} from './classic-pdf.js';
import {renderToStaticMarkup} from 'react-dom/server';
globalThis.window={uniion:{queue:[]}};
await import('./uniion-studio.js');
const {docStyles,docBlocks}=window.uniion.queue[0].contributes;
if(process.argv.includes('--samples')){console.log(JSON.stringify(docBlocks.map(x=>({id:x.type,type:x.type,text:x.sample||''}))));process.exit(0);}
if(process.argv.includes('--catalog')){console.log(JSON.stringify({styles:docStyles.map(x=>({id:x.id,palettes:x.palettes.length,fonts:x.fonts.length})),blocks:docBlocks.map(x=>x.type)}));process.exit(0);}
const {document:d,fonts,logo}=JSON.parse(fs.readFileSync(0,'utf8'));
const sty=docStyles.find(x=>x.id===d.style);if(d.style&&!sty)throw Error('Unknown style');
const [w,h]={a4:[794,1123],a5:[559,794],wide:[1123,632]}[d.format]||[];if(!w)throw Error('Unknown format');
const opts=d.styleOpts||{},pal=sty?.palettes[opts.palette||0],font=sty?.fonts[opts.font||0];if(sty&&(!pal||!font))throw Error('Unknown options');
const lines=s=>String(s||'').split('\n').map(x=>x.trim()).filter(Boolean);
const pages=[[]];for(const b of d.blocks){if(b.type==='pagebreak')pages.push([]);else pages.at(-1).push(b);}if(pages.length>1&&!pages.at(-1).length)pages.pop();
const styled=(blocks,i,count)=>{const ctx={h:React.createElement,blocks,first:t=>blocks.find(b=>b.type===t)||null,all:t=>blocks.filter(b=>b.type===t),block:(b,k)=>{const def=docBlocks.find(x=>x.type===b.type);return def?def.render(b,{h:React.createElement,lines,...k}):null;},lines,cells:l=>String(l).split('|').map(x=>x.trim()),colors:{...pal.colors},fonts:{...font},format:{id:d.format,w,h},u:w/420,page:{index:i,count},org:{emetteur:d.charte.emetteur||'',section:d.charte.section||'',contact:[d.charte.email,d.charte.phone].filter(Boolean).join(' — '),logo}};return sty.render(ctx);};
const planned=planDocumentPages(pages,sty?styled:null,d.format);
const expected=Buffer.from(JSON.stringify(continuationBlocks(d.blocks,d.format).filter(b=>['tag','h1','h2','h3','p','quote','ul'].includes(b.type)).map(b=>b.text||''))).toString('base64');
const html=planned.map((page,i)=>'<section>'+renderToStaticMarkup(page.styled?styled(page.blocks,i,planned.length):classicPage(d,page.blocks,i,planned.length,docBlocks,logo))+'</section>').join('');
// CSP blocks remote resources and supplied code; only the fixed overflow guard may execute.
console.log('<!doctype html><html><head><meta charset="utf-8"><meta name="uniion-text-parts" content="'+expected+'"><meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\'; font-src data:; img-src data:; script-src \'nonce-uniion-pdf-guard\'; base-uri \'none\'"><style>'+fonts+`\n*{box-sizing:border-box}:root{--ink4:#6b7280;--bd2:#e5e7eb;--surf2:#f9fafb}html,body{margin:0;padding:0}section{position:relative;width:${w}px;height:${h}px;overflow:hidden;break-after:page;background:white}section:last-child{break-after:auto}*{-webkit-print-color-adjust:exact;print-color-adjust:exact}@page{size:${w}px ${h}px;margin:0}</style></head><body>`+html+(`<div id="pdf-guard" style="position:fixed;top:0;left:0">UNIION_PDF_OVERFLOW_BLOCKED</div><script nonce="uniion-pdf-guard">document.fonts.ready.then(()=>{const ok=(${verifyPDFLayout.toString()})();if(ok)document.getElementById('pdf-guard').remove();});</script>`)+ '</body></html>');
