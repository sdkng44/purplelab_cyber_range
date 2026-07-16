import re

try:
    from app.objects.secondclass.c_fact import Fact
    from app.objects.secondclass.c_relationship import Relationship
except Exception:
    from app.objects.c_fact import Fact
    from app.objects.c_relationship import Relationship

from app.utility.base_parser import BaseParser


class Parser(BaseParser):
    pattern = re.compile(r"S13_PORT_OPEN host=(?P<host>\S+) port=(?P<port>\d+)")

    def parse(self, blob):
        relationships = []
        for line in blob.splitlines():
            match = self.pattern.search(line.strip())
            if not match:
                continue
            data = match.groupdict()

            for mp in self.mappers:
                if mp.source == 'pool.target.host' and mp.edge == 'has_open_port' and mp.target == 'pool.target.port':
                    src_val = self.set_value(mp.source, data['host'], self.used_facts)
                    tgt_val = self.set_value(mp.target, data['port'], self.used_facts)
                    relationships.append(
                        Relationship(
                            source=Fact(mp.source, src_val),
                            edge=mp.edge,
                            target=Fact(mp.target, tgt_val)
                        )
                    )
        return relationships
