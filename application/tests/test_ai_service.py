import unittest
from uniion.core.ai import AIService, AISource
from uniion.core.contracts import Principal, Denied, Unavailable


class Access:
    def __init__(self):
        self.allowed = True
        self.source = AISource('document', '1', 'Contenu fictif')

    def authorize(self, principal, provider_id):
        if not self.allowed or principal.organization_id != 'org-a' or provider_id != 'fake':
            raise Denied('denied')

    def read(self, principal, resource_id):
        self.authorize(principal, 'fake')
        if resource_id != self.source.resource_id:
            raise Denied('denied')
        return self.source


class Provider:
    def __init__(self):
        self.calls = 0
        self.effect = lambda: None
        self.answer = 'Réponse fictive'

    def complete(self, question, sources):
        self.calls += 1
        self.effect()
        return self.answer


class AIServiceTests(unittest.TestCase):
    def setUp(self):
        self.access = Access()
        self.provider = Provider()
        self.service = AIService(self.access, self.provider, 'fake')
        self.principal = Principal('user-a', 'org-a')

    def run_request(self, **kwargs):
        return self.service.generate(self.principal, 'Résumer', ('document',), **kwargs)

    def test_result_retains_source_dependencies(self):
        result = self.run_request()
        self.assertEqual(result.sources, (('document', '1'),))
        self.assertEqual(result.text, 'Réponse fictive')

    def test_other_organization_never_calls_provider(self):
        self.principal = Principal('user-b', 'org-b')
        with self.assertRaises(Denied): self.run_request()
        self.assertEqual(self.provider.calls, 0)

    def test_unapproved_provider_is_denied(self):
        self.service.provider_id = 'unapproved'
        with self.assertRaises(Denied): self.run_request()
        self.assertEqual(self.provider.calls, 0)

    def test_unknown_source_never_calls_provider(self):
        with self.assertRaises(Denied):
            self.service.generate(self.principal, 'Résumer', ('unknown',))
        self.assertEqual(self.provider.calls, 0)

    def test_revocation_during_generation_discards_output(self):
        self.provider.effect = lambda: setattr(self.access, 'allowed', False)
        with self.assertRaises(Denied): self.run_request()

    def test_changed_source_discards_output(self):
        self.provider.effect = lambda: setattr(self.access, 'source', AISource('document', '2', 'Modifié'))
        with self.assertRaises(Denied): self.run_request()

    def test_cancel_before_send(self):
        with self.assertRaises(Denied): self.run_request(cancelled=lambda: True)
        self.assertEqual(self.provider.calls, 0)

    def test_cancel_during_generation(self):
        cancelled = [False]
        self.provider.effect = lambda: cancelled.__setitem__(0, True)
        with self.assertRaises(Denied): self.run_request(cancelled=lambda: cancelled[0])

    def test_provider_error_is_sanitized(self):
        def fail(): raise RuntimeError('secret fictif')
        self.provider.effect = fail
        with self.assertRaisesRegex(Unavailable, '^ai_provider_failed$'): self.run_request()
        self.assertEqual(self.provider.calls, 1)

    def test_empty_output_is_failure(self):
        self.provider.answer = ' '
        with self.assertRaises(Unavailable): self.run_request()

    def test_context_bound(self):
        self.access.source = AISource('document', '1', 'x' * 60001)
        with self.assertRaises(ValueError): self.run_request()
        self.assertEqual(self.provider.calls, 0)

    def test_duplicate_sources(self):
        with self.assertRaises(ValueError):
            self.service.generate(self.principal, 'Résumer', ('document', 'document'))
        self.assertEqual(self.provider.calls, 0)
