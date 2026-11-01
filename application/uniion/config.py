import os
from dataclasses import dataclass
@dataclass(frozen=True)
class Config:
    environment: str
    supabase_url: str
    publishable_key: str
    @classmethod
    def load(cls,env=None):
        env=os.environ if env is None else env
        # No implicit local fallback; production deployment is deliberately not qualified.
        if env.get('UNIION_ENV')!='development-local':raise ValueError('Ce lot S01 autorise uniquement development-local ; recette et production restent à configurer.')
        if env.get('UNIION_SUPABASE_URL')!='http://127.0.0.1:54321':raise ValueError('Origine Supabase locale explicite requise')
        if env.get('UNIION_SUPABASE_PUBLISHABLE_KEY',''):raise ValueError('Aucune clé privilégiée ou publique nécessaire pour cette pile locale')
        return cls('development-local','http://127.0.0.1:54321','')
