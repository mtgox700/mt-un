"""Temporary bridge to the tested resource model; no direct database imports."""
from uniion.core.contracts import Manifest,Denied
class ResourceModule:
    manifest=Manifest('core.resources','1.0.0',('resource.read.v1',))
    def execute(self,command,principal,payload,resources):
        if command!='resource.read.v1' or set(payload)!={'resource_id'}:raise Denied()
        return resources.read(principal,payload['resource_id'])
