import test from 'node:test';
import assert from 'node:assert/strict';
import {retentionView} from '../modules/meetings/retention.js';
test('an overdue recording is retained, never described as deleted',()=>{const v=retentionView({due:'2026-01-01',batches:[]},Date.parse('2026-02-01'));assert.equal(v.retentionBadge,'Échéance dépassée');assert.match(v.retentionText,/conservé/);});
test('approval and execution are not deletion confirmations',()=>{for(const state of ['approved','executing'])assert.notEqual(retentionView({batches:[{state}]}).retentionBadge,'Audio supprimé');});
test('completed batch does not hide newer retained audio',()=>{assert.equal(retentionView({due:'2099-01-01',batches:[{state:'done'}]}).retentionBadge,'Audio conservé');});
test('no successful status is invented when RPC fails',()=>{assert.equal(retentionView(null).retentionBadge,'Conservation à vérifier');});
test('completed deletion distinguishes server from unavailable devices',()=>{const v=retentionView({remaining:0,batches:[{state:'done'}]});assert.equal(v.retentionBadge,'Audio supprimé');assert.match(v.retentionText,/hors ligne/);});

import {confirmedLocalCopy} from '../modules/meetings/audio-vault.js';
test('cleanup requires saved flag and exact receipts for every segment',()=>{const v={saved:true,meeting:'m',segments:[{request:'r1',audio:'a1'},{request:'r2',audio:'a2'}]},receipts=[{meeting:'m',request:'r1',audio:'a1'},{meeting:'m',request:'r2',audio:'a2'}];assert.equal(confirmedLocalCopy(v,receipts),true);assert.equal(confirmedLocalCopy({...v,saved:false},receipts),false);assert.equal(confirmedLocalCopy(v,receipts.slice(1)),false);assert.equal(confirmedLocalCopy({...v,meeting:'other'},receipts),false);assert.equal(confirmedLocalCopy({...v,segments:[]},receipts),false);});

test('a new unvalidated audio prevents a meeting-wide deleted claim',()=>{assert.equal(retentionView({remaining:1,batches:[{state:'done'}]}).retentionBadge,'Audio conservé');});
