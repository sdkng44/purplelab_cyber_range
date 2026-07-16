import re

try:
    from app.objects.secondclass.c_relationship import Relationship
except Exception:
    from app.objects.c_relationship import Relationship

from app.utility.base_parser import BaseParser


class Parser(BaseParser):
    pattern = re.compile(r"S13_APP_FOOTHOLD_OK host=(?P<host>\S+) paw=(?P<paw>\S+)")

    def parse(self, blob):
        relationships = []
        for line in blob.splitlines():
            match = self.pattern.search(line.strip())
            if not match:
                continue

            data = match.groupdict()

            for mp in self.mappers:
                if mp.source == 'app.compromised.host' and mp.edge == 'has_paw' and mp.target == 'app.compromised.paw':
                    source = self.set_value(mp.source, data['host'], self.used_facts)
                    target = self.set_value(mp.target, data['paw'], self.used_facts)
                    relationships.append(
                        Relationship(source=(mp.source, source), edge=mp.edge, target=(mp.target, target))
                    )
        return relationships
