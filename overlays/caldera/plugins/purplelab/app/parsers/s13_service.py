import re

try:
    from app.objects.secondclass.c_fact import Fact
    from app.objects.secondclass.c_relationship import Relationship
except Exception:
    from app.objects.c_fact import Fact
    from app.objects.c_relationship import Relationship

from app.utility.base_parser import BaseParser


class Parser(BaseParser):
    pattern = re.compile(
        r"S13_SERVICE_OK host=(?P<host>\S+) port=(?P<port>\d+) service=(?P<service>\S+) node=(?P<node>\S+) hint=(?P<hint>\S+)"
    )

    def parse(self, blob):
        relationships = []
        for line in blob.splitlines():
            match = self.pattern.search(line.strip())
            if not match:
                continue
            data = match.groupdict()

            for mp in self.mappers:
                if mp.source == 'pool.target.host' and mp.edge == 'has_service' and mp.target == 'pool.service.name':
                    src_val = self.set_value(mp.source, data['host'], self.used_facts)
                    tgt_val = self.set_value(mp.target, data['service'], self.used_facts)
                    relationships.append(
                        Relationship(
                            source=Fact(mp.source, src_val),
                            edge=mp.edge,
                            target=Fact(mp.target, tgt_val)
                        )
                    )

                elif mp.source == 'pool.target.host' and mp.edge == 'has_hint' and mp.target == 'pool.bootstrap.path':
                    src_val = self.set_value(mp.source, data['host'], self.used_facts)
                    tgt_val = self.set_value(mp.target, data['hint'], self.used_facts)
                    relationships.append(
                        Relationship(
                            source=Fact(mp.source, src_val),
                            edge=mp.edge,
                            target=Fact(mp.target, tgt_val)
                        )
                    )

                elif mp.source == 'pool.target.host' and mp.edge == 'maps_node' and mp.target == 'pool.target.node':
                    src_val = self.set_value(mp.source, data['host'], self.used_facts)
                    tgt_val = self.set_value(mp.target, data['node'], self.used_facts)
                    relationships.append(
                        Relationship(
                            source=Fact(mp.source, src_val),
                            edge=mp.edge,
                            target=Fact(mp.target, tgt_val)
                        )
                    )

                elif mp.source == 'pool.target.host' and mp.edge == 'has_open_port' and mp.target == 'pool.target.port':
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
