from .contracts import Module,Denied

class Registry:
    def __init__(self, modules: tuple[Module,...]):
        self._commands={};self._modules={}
        for module in modules:
            m=module.manifest
            if m.module_id in self._modules or m.version!='1.0.0':raise ValueError('Module/version incompatible')
            self._modules[m.module_id]=module
            for command in m.commands:
                if command in self._commands:raise ValueError('Commande ambiguë')
                self._commands[command]=module
        for module in modules:
            if any(d not in self._modules for d in module.manifest.dependencies):raise ValueError('Dépendance absente')
        visiting=set();done=set()
        def visit(name):
            if name in visiting:raise ValueError('Dépendance circulaire')
            if name in done:return
            visiting.add(name)
            for dep in self._modules[name].manifest.dependencies:visit(dep)
            visiting.remove(name);done.add(name)
        for name in self._modules:visit(name)
    def execute(self,command,principal,payload,resources):
        module=self._commands.get(command)
        if module is None:raise Denied()
        # Manifest is not authorization; the resource port rechecks Auth and RLS.
        return module.execute(command,principal,payload,resources)
