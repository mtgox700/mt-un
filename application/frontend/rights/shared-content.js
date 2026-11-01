/* Read-only business presentation; all source text is escaped, never interpreted. */
window.SharedContent=(()=>{
const text=x=>typeof x==='string'||typeof x==='number'?String(x):'',esc=x=>text(x).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])),lines=x=>esc(x).replace(/\n/g,'<br>');
function block(b){if(!b||typeof b!=='object')return '';const [kind,value]=Array.isArray(b)?b:[b.type,b.text];
 if(kind==='pagebreak')return '<hr><p class="muted">Page suivante</p>';
 if(['h1','h2','h3'].includes(kind))return '<'+kind+'>'+lines(value)+'</'+kind+'>';
 if(kind==='tag')return '<span class="tag">'+esc(value)+'</span>';
 if(kind==='quote')return '<div class="info">'+lines(value)+'</div>';
 if(kind==='ul')return '<ul>'+text(value).split('\n').map(x=>'<li>'+esc(x)+'</li>').join('')+'</ul>';
 if(kind==='table')return '<div tabindex="0" role="region" aria-label="Tableau du document" style="overflow-x:auto;max-width:100%"><table style="width:100%;border-collapse:collapse">'+text(value).split('\n').map((row,i)=>'<tr>'+row.split('|').map(c=>`<${i?'td':'th'} style="text-align:left;padding:8px;border-bottom:1px solid var(--bd);overflow-wrap:normal">${esc(c.trim())}</${i?'td':'th'}>`).join('')+'</tr>').join('')+'</table></div>';
 return '<p>'+lines(value)+'</p>';
}
function render(d){const b=d.body||{};let html='';
 if(d.kind==='dossiers'){
 const status={todo:'À traiter',progress:'En cours',doing:'En cours',done:'Terminé',closed:'Clôturé'};
 html=`<div class="tags"><span class="tag">${esc(b.tag||'Dossier')}</span><span class="tag">${esc(status[b.status]||b.status||'À traiter')}</span></div><dl class="collection-preview"><dt>Responsable</dt><dd>${esc(b.owner||'Non renseigné')}</dd><dt>Échéance</dt><dd>${esc(b.due||'À planifier')}</dd></dl>`;
 for(const [key,label] of [['desc','En bref'],['long','Situation'],['ask','Demande']])if(text(b[key]))html+='<h3>'+label+'</h3><p>'+lines(b[key])+'</p>';
 html+='<h3>Chronologie</h3>'+(Array.isArray(b.timeline)&&b.timeline.length?b.timeline.map(t=>'<section class="row"><div><span class="muted">'+esc(t.date)+'</span><h3>'+esc(t.title)+'</h3><p>'+lines(t.body)+'</p></div></section>').join(''):'<p class="muted">Aucun événement dans cette version.</p>');
 }else if(d.kind==='docs')html=`<span class="tag">${esc(b.format||'Document')}</span>${b.status?'<span class="tag">'+esc(b.status)+'</span>':''}`+(Array.isArray(b.blocks)&&b.blocks.length?b.blocks.map(block).join(''):'<p class="muted">Cette version du document ne contient aucun bloc rédigé.</p>');
 else if(text(b.text))html='<p>'+lines(b.text)+'</p>';
 else html='<p class="muted">La présentation de ce type de contenu n’est pas encore disponible.</p>';
 return '<article aria-label="Contenu partagé" style="overflow-wrap:anywhere">'+html+'</article>';
}
return {render};
})();
