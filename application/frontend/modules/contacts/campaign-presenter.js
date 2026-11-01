import {ADH_MSG_MODELS} from '../../generated/constants.js';
export function createCampaignPresenter(store,ports){const context={get state(){return store.read()},...ports};return Object.freeze({campaignVals(){const m=store.read().adhMsg,tg=ports.adhTargets();return (function(){return {
        readonlyNames:true,joinLabel:"Joindre le bulletin d'adhésion",joinHint:"Pièce jointe générée depuis le modèle de la bibliothèque documentaire, à la charte de l'organisation.",documentHint:"Le bulletin d'adhésion est un modèle de la bibliothèque : identité, situation professionnelle, cotisation, mandat SEPA et mention RGPD sur la donnée sensible.",documentLink:"Ouvrir le modèle de bulletin dans l'éditeur →",targetLabel: tg.label, targetCount: tg.list.length + ' destinataire' + (tg.list.length > 1 ? 's' : ''),
        names: tg.list.slice(0, 8).map((a) => ({ name: a.prenom + ' ' + a.nom, initials: a.initials })),
        more: tg.list.length > 8 ? '+ ' + (tg.list.length - 8) + ' autres' : '',
        hasMore: tg.list.length > 8,
        cibles: [{ id: 'selection', label: 'Sélection / filtres' }, { id: 'groupe', label: 'Liste de diffusion' }].map((c) => ({
          label: c.label, on: m.cible === c.id,
          bg: m.cible === c.id ? 'var(--inkSurf)' : 'transparent', fg: m.cible === c.id ? '#FFFFFF' : 'var(--ink4)',
          go: () => this.setAdhMsg({ cible: c.id })
        })),
        isGroupe: m.cible === 'groupe',
        groupeId: m.groupeId,
        groupOpts: this.state.groupes.map((g) => ({ v: g.id, label: g.name })),
        onGroupe: (e) => this.setAdhMsg({ groupeId: e.target.value }),
        canaux: [{ id: 'email', label: 'E-mail' }, { id: 'sms', label: 'SMS' }, { id: 'app', label: 'Notification app' }].map((c) => ({
          label: c.label, on: m.canal === c.id,
          bg: m.canal === c.id ? 'var(--acBg)' : 'var(--surface)', fg: m.canal === c.id ? 'var(--acTx2)' : 'var(--ink4)',
          bd: m.canal === c.id ? 'var(--acBd2)' : 'var(--bd2)',
          go: () => this.setAdhMsg({ canal: c.id })
        })),
        models: ADH_MSG_MODELS.map((x) => ({
          label: x.label, on: m.modele === x.id,
          bg: m.modele === x.id ? 'var(--acBg)' : 'var(--surf2)', fg: m.modele === x.id ? 'var(--acTx2)' : 'var(--ink4)',
          go: () => this.applyAdhModel(x.id)
        })),
        objet: m.objet, onObjet: (e) => this.setAdhMsg({ objet: e.target.value }),
        corps: m.corps, onCorps: (e) => this.setAdhMsg({ corps: e.target.value }),
        joinOn: m.joinBulletin,
        joinBg: m.joinBulletin ? 'var(--ok)' : 'var(--bd2)', joinLeft: m.joinBulletin ? '23px' : '3px',
        toggleJoin: () => this.setAdhMsg({ joinBulletin: !m.joinBulletin }),
        canalNote: m.canal === 'sms' ? 'SMS : 160 caractères par message, envoi facturé au syndicat. Le corps est tronqué à la première coupure de ligne.' : (m.canal === 'app' ? 'Notification poussée dans l\'app des adhérents — lecture tracée, aucun contenu stocké côté serveur.' : 'E-mail envoyé en copie cachée : les adhérents ne voient jamais la liste des destinataires.'),
        send: () => this.sendAdhCampagne(),
        cancel: () => this.go('adherents'),
        bulletinDoc: () => this.adhBulletin(null)
      }}).call(context)}});}
