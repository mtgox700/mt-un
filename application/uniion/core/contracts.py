"""Only core contracts may be imported by independent business modules."""
from dataclasses import dataclass
from typing import Protocol

class Denied(Exception): pass
class Unavailable(Exception): pass
class PDFOverflow(Denied): pass
class PDFContentMissing(Denied): pass
@dataclass(frozen=True)
class Principal:
    user_id: str
    organization_id: str
@dataclass(frozen=True)
class Manifest:
    module_id: str
    version: str
    commands: tuple[str,...]
    dependencies: tuple[str,...] = ()
class Resources(Protocol):
    def read(self, principal: Principal, resource_id: str) -> dict: ...
class Module(Protocol):
    manifest: Manifest
    def execute(self, command: str, principal: Principal, payload: dict, resources: Resources) -> dict: ...
