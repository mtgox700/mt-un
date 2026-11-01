// Analyse antivirus par clamd (conteneur ClamAV, réseau interne Docker), protocole INSTREAM :
// blocs préfixés par leur longueur (32 bits big-endian), terminés par un bloc vide.
export type Verdict = 'ok' | 'infecte' | 'indisponible';

export async function analyser(octets: Uint8Array): Promise<Verdict> {
  try {
    const conn = await Deno.connect({ hostname: Deno.env.get('CLAMAV_HOST') ?? 'clamav', port: 3310 });
    const w = conn.writable.getWriter();
    await w.write(new TextEncoder().encode('zINSTREAM\0'));
    for (let i = 0; i < octets.length; i += 65536) {
      const bloc = octets.subarray(i, i + 65536);
      const lg = new Uint8Array(4);
      new DataView(lg.buffer).setUint32(0, bloc.length);
      await w.write(lg);
      await w.write(bloc);
    }
    await w.write(new Uint8Array(4));
    const r = conn.readable.getReader();
    let rep = '';
    for (;;) {
      const { value, done } = await r.read();
      if (done) break;
      rep += new TextDecoder().decode(value);
      if (rep.includes('\0')) break;
    }
    conn.close();
    if (/: OK\0?$/.test(rep.trim())) return 'ok';
    if (/FOUND/.test(rep)) return 'infecte';
    return 'indisponible';
  } catch {
    return 'indisponible';
  }
}
