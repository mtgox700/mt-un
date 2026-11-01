import { EnTete } from '../ui/Coque';
import { Conversation } from './Conversation';
import { s } from '../ui/kit';

export function Assistant() {
  return (
    <>
      <EnTete titre="Assistant" sous="Questions de droit du travail, procédures, rédaction. Pour une question liée à un salarié, ouvrez plutôt son dossier : l'échange y sera conservé." />
      <section style={{ ...s.carte, padding: 0, overflow: 'hidden', maxWidth: 860 }}>
        <Conversation surface="assistant" hauteur={560} suggestions={[
          'Délai de consultation du CSE sur un projet de réorganisation ?',
          'Quelles protections pour un élu en cas de licenciement ?',
          'Comment déclencher une enquête CSSCT ?',
        ]} />
      </section>
    </>
  );
}
