"""S08 local orchestration contract; adapters must enforce current server rights.

No provider is configured here. Source text comes exclusively from the access
adapter, never from a client supplied corpus. This service is not yet an HTTP API.
"""
from dataclasses import dataclass
from typing import Protocol

from uniion.core.contracts import Principal, Denied, Unavailable


@dataclass(frozen=True)
class AISource:
    resource_id: str
    version: str
    text: str


class AIAccess(Protocol):
    def authorize(self, principal: Principal, provider_id: str) -> None:
        """Check session, membership, module, permission, D09 approval and activation."""
        ...

    def read(self, principal: Principal, resource_id: str) -> AISource: ...


class AIProvider(Protocol):
    def complete(self, question: str, sources: tuple[AISource, ...]) -> str:
        """Treat sources as untrusted data; no tools or side effects are allowed."""
        ...


@dataclass(frozen=True)
class AIResult:
    text: str
    # Dependencies, not model-generated citations. All are required by D12.
    sources: tuple[tuple[str, str], ...]


class AIService:
    def __init__(self, access: AIAccess, provider: AIProvider, provider_id: str):
        self.access = access
        self.provider = provider
        self.provider_id = provider_id

    def generate(self, principal: Principal, question: str,
                 resource_ids: tuple[str, ...], cancelled=lambda: False) -> AIResult:
        if not isinstance(question, str) or not question.strip() or len(question) > 8000:
            raise ValueError('invalid_question')
        if (not isinstance(resource_ids, tuple) or len(resource_ids) > 20
                or any(not isinstance(r, str) or not r for r in resource_ids)
                or len(set(resource_ids)) != len(resource_ids)):
            raise ValueError('invalid_sources')

        def check():
            if cancelled():
                raise Denied('ai_cancelled')
            self.access.authorize(principal, self.provider_id)

        def read():
            items = tuple(self.access.read(principal, r) for r in resource_ids)
            if any(s.resource_id != r for s, r in zip(items, resource_ids)):
                raise Denied('ai_source_mismatch')
            return items

        check()
        sources = read()
        if sum(len(s.text) for s in sources) > 60000:
            raise ValueError('context_too_large')
        # Revalidate after retrieval, immediately before handing data to a provider.
        check()
        if read() != sources:
            raise Denied('ai_source_changed')
        try:
            text = self.provider.complete(question.strip(), sources)
        except Exception:
            # Provider messages may contain request content or credentials.
            raise Unavailable('ai_provider_failed') from None
        check()
        if read() != sources:
            raise Denied('ai_source_changed')
        if not isinstance(text, str) or not text.strip():
            raise Unavailable('ai_empty_response')
        return AIResult(text.strip(), tuple((s.resource_id, s.version) for s in sources))
