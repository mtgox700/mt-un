// Chiffrement applicatif des colonnes bytea (notes, conversations, messages, détail de dossier).
// AES-256-GCM, une clé par organisation dérivée (HKDF) d'une clé maîtresse qui n'existe que dans les
// secrets des Edge Functions : la base ne voit jamais la clé (schema/README.md §4).
// Format : 0x01 | iv(12) | texte chiffré+tag. Rotation : incrémenter l'octet de version.

const enc = new TextEncoder();
const dec = new TextDecoder();
const cache = new Map<string, CryptoKey>();

async function cleOrganisation(orgId: string): Promise<CryptoKey> {
  const k = cache.get(orgId);
  if (k) return k;
  const b64 = Deno.env.get('COFFRE_CLE_MAITRE');
  if (!b64) throw new Error('COFFRE_CLE_MAITRE absente');
  const maitre = await crypto.subtle.importKey('raw', Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)), 'HKDF', false, ['deriveKey']);
  const cle = await crypto.subtle.deriveKey(
    { name: 'HKDF', hash: 'SHA-256', salt: enc.encode('uniion/coffre/v1'), info: enc.encode(orgId) },
    maitre, { name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
  cache.set(orgId, cle);
  return cle;
}

export async function chiffrer(orgId: string, clair: string): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv, additionalData: enc.encode(orgId) },
    await cleOrganisation(orgId), enc.encode(clair)));
  const out = new Uint8Array(1 + 12 + ct.length);
  out.set([1]); out.set(iv, 1); out.set(ct, 13);
  return '\\x' + [...out].map((b) => b.toString(16).padStart(2, '0')).join('');  // littéral bytea
}

export async function dechiffrer(orgId: string, bytea: string): Promise<string> {
  const hex = bytea.startsWith('\\x') ? bytea.slice(2) : bytea;
  const buf = Uint8Array.from(hex.match(/../g)!.map((h) => parseInt(h, 16)));
  return dec.decode(await dechiffrerOctets(orgId, buf));
}

// Fichiers (pièces de dossier) : même format, en binaire. Le contexte lie le chiffré à sa pièce :
// un fichier déplacé vers une autre pièce ou une autre organisation ne se déchiffre pas.
export async function chiffrerOctets(orgId: string, clair: Uint8Array, contexte = ''): Promise<Uint8Array> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv, additionalData: enc.encode(orgId + contexte) },
    await cleOrganisation(orgId), clair));
  const out = new Uint8Array(13 + ct.length);
  out.set([1]); out.set(iv, 1); out.set(ct, 13);
  return out;
}

export async function dechiffrerOctets(orgId: string, buf: Uint8Array, contexte = ''): Promise<Uint8Array> {
  if (buf[0] !== 1) throw new Error('version de chiffrement inconnue');
  return new Uint8Array(await crypto.subtle.decrypt({ name: 'AES-GCM', iv: buf.slice(1, 13), additionalData: enc.encode(orgId + contexte) },
    await cleOrganisation(orgId), buf.slice(13)));
}
