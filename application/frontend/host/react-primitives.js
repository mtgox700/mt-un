import React from 'react';
export const h=React.createElement;
export function interpolate(value,key){if(React.isValidElement(value)||Array.isArray(value))return h(React.Fragment,{key},value);if(value==null||typeof value==='boolean')return null;return h('span',{key,className:'sc-interp'},String(value));}
export function style(value){if(typeof value!=='string')return value;return Object.fromEntries(value.split(';').map(s=>{const i=s.indexOf(':');if(i<0)return null;const k=s.slice(0,i).trim();return [k.startsWith('--')?k:k.replace(/-([a-z])/g,(_,c)=>c.toUpperCase()),s.slice(i+1).trim()];}).filter(Boolean));}
