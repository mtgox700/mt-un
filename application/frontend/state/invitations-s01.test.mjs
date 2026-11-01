import assert from 'node:assert/strict';import {createS01Invitations} from '../services/invitations-s01.js';
const org='11111111-1111-1111-1111-111111111111';let requests=[],allowed=true,status=200;const fake=async(path,options)=>{requests.push({path,options});return path==='/auth/session'?{ok:true,json:async()=>({authenticated:allowed,business_allowed:allowed,aal:'aal2',csrf:'test-csrf'})}:{ok:status===200,status}};
const submit=createS01Invitations(fake,org);let n=0;async function test(name,f){await f();n++;console.log('PASS '+name)}
await test('bad organization rejected',async()=>assert.throws(()=>createS01Invitations(fake,'bad')));
await test('invalid addresses fail before network',async()=>{await assert.rejects(submit({text:'a@'}));assert.equal(requests.length,0)});
await test('anonymous session refused',async()=>{allowed=false;await assert.rejects(submit({text:'a@example.invalid'}));assert.equal(requests.length,1)});
await test('same origin csrf exact payload and deduplication',async()=>{allowed=true;requests=[];assert.deepEqual(await submit({text:'A@example.invalid,a@example.invalid',requestedRole:2}),{created:1,delivered:true});assert.equal(requests.length,2);const q=requests[1];assert.equal(q.options.credentials,'same-origin');assert.equal(q.options.headers['X-Uniion-CSRF'],'test-csrf');assert.deepEqual(JSON.parse(q.options.body),{organization_id:org,email:'a@example.invalid'});assert.equal(q.options.headers.Authorization,undefined)});
await test('denial surfaced without false success',async()=>{status=403;await assert.rejects(submit({text:'a@example.invalid'}),/Accès refusé/)});
console.log(n+' S01 transport checks passed');
