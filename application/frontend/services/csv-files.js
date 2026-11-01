import {ADH_CSV_MODEL} from '../generated/constants.js';
export function createCsvFiles(store,{flash}){const context={setState:p=>store.update(p),flash};Object.assign(context,{downloadCsvModel() {
    if (typeof document === 'undefined') return;
    const blob = new Blob(['\ufeff' + ADH_CSV_MODEL], { type: 'text/csv;charset=utf-8' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'modele-import-adherents.csv';
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 2000);
    this.flash('Modèle CSV téléchargé — 12 colonnes, séparateur point-virgule');
  },
pickCsvFile() {
    if (typeof document === 'undefined') return;
    const inp = document.createElement('input');
    inp.type = 'file';
    inp.accept = '.csv,text/csv';
    inp.onchange = () => {
      const f = inp.files && inp.files[0];
      if (!f) return;
      const rd = new FileReader();
      rd.onload = () => this.setState((s) => ({ adhImp: Object.assign({}, s.adhImp, { text: String(rd.result || ''), touched: true, fileName: f.name }) }));
      rd.readAsText(f, 'utf-8');
    };
    inp.click();
  }});return Object.freeze({downloadCsvModel:context.downloadCsvModel.bind(context),pickCsvFile:context.pickCsvFile.bind(context)});}
