/* Files belong to this browser/origin. No server upload or application encryption. */
(() => {
  let database;
  function open() {
    if (!database) database = new Promise((resolve,reject) => {
      const req = indexedDB.open('uniion-local-files',1);
      req.onupgradeneeded = () => req.result.createObjectStore('files');
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => { database = null; reject(req.error); };
      req.onblocked = () => { database = null; reject(new Error('Fermez les autres onglets du prototype et réessayez')); };
    });
    return database;
  }
  async function operation(mode,fn) {
    const db = await open();
    return new Promise((resolve,reject) => {
      const tx = db.transaction('files',mode);
      const req = fn(tx.objectStore('files'));
      tx.oncomplete = () => resolve(req.result);
      tx.onerror = tx.onabort = () => reject(tx.error || req.error || new Error('Stockage local indisponible'));
    });
  }
  window.uniionFiles = {
    put:(key,blob) => operation('readwrite',s => s.put(blob,key)),
    get:key => operation('readonly',s => s.get(key)),
    remove:key => operation('readwrite',s => s.delete(key)),
    download(blob,name) {
      const a = document.createElement('a'),url = URL.createObjectURL(blob);
      a.href=url; a.download=name; a.click(); setTimeout(() => URL.revokeObjectURL(url),30000);
    }
  };
})();
