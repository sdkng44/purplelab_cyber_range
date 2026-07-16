import re

try:
    from app.objects.secondclass.c_relationship import Relationship
except Exception:
    from app.objects.c_relationship import Relationship

from app.utility.base_parser import BaseParser


class Parser(BaseParser):
    pattern = re.compile(
        r"S13_DELIVERY_OK node=(?P<node>\S+) host=(?P<host>\S+) paw=(?P<paw>\S+?)(?=S13_DELIVERY_OK|$)"
    )

    def parse(self, blob):
        relationships = []

        for match in self.pattern.finditer(blob):
            data = match.groupdict()

            for mp in self.mappers:
                if (
                    mp.source == 'pool.compromised.host'
                    and mp.edge == 'has_paw'
                    and mp.target == 'pool.compromised.paw'
                ):
                    source = self.set_value(mp.source, data['host'], self.used_facts)
                    target = self.set_value(mp.target, data['paw'], self.used_facts)
                    relationships.append(
                        Relationship(
                            source=(mp.source, source),
                            edge=mp.edge,
                            target=(mp.target, target),
                        )
                    )

                elif (
                    mp.source == 'pool.compromised.host'
                    and mp.edge == 'maps_name'
                    and mp.target == 'pool.compromised.node'
                ):
                    source = self.set_value(mp.source, data['host'], self.used_facts)
                    target = self.set_value(mp.target, data['node'], self.used_facts)
                    relationships.append(
                        Relationship(
                            source=(mp.source, source),
                            edge=mp.edge,
                            target=(mp.target, target),
                        )
                    )

        return relationships
