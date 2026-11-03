import test from 'node:test';import assert from 'node:assert/strict';
import {Component} from '../generated/controller.js';
const c=Object.create(Component.prototype);
test('esc échappe aussi les guillemets et apostrophes (R42)',()=>{
 assert.equal(c.esc(`x" onmouseover="alert(1)`),'x&quot; onmouseover=&quot;alert(1)');
 assert.equal(c.esc("a'b<c>&"),'a&#39;b&lt;c&gt;&amp;');
 assert.equal(c.esc(null),'');
});
test('safeHref ne garde que web, interne, ancre et mailto (R42, R46)',()=>{
 for(const ok of ['https://exemple.fr/a','http://exemple.fr','/intranet/page','#section','mailto:contact@exemple.fr'])assert.equal(c.safeHref(ok),ok);
 for(const bad of ['javascript:alert(1)',' JavaScript:alert(1)','data:text/html,x','//evil.example','vbscript:x',''])assert.equal(c.safeHref(bad),'#');
});
test('safeSrc ne garde que les images encodées et les chemins du site',()=>{
 assert.equal(c.safeSrc('data:image/png;base64,AAAA'),'data:image/png;base64,AAAA');
 assert.equal(c.safeSrc('/uniion-logo.png'),'/uniion-logo.png');
 for(const bad of ['data:image/svg+xml;base64,AAAA','javascript:x','https://tracker.example/p.gif','//cdn.example/x.png'])assert.equal(c.safeSrc(bad),'');
});
