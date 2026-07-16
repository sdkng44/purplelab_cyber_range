import re

try:
    from app.objects.secondclass.c_relationship import Relationship
except Exception:
    from app.objects.c_relationship import Relationship

from app.utility.base_parser import BaseParser


class Parser(BaseParser):
    pattern = re.compile(
        r"S13_PIVOT_OK target=(?P<target>\S+) host=(?P<host>\S+) port=(?P<port>\d+) user=(?P<user>\S+) password=(?P<password>\S+)"
    )

    def parse(self, blob):
        relationships = []

        for line in blob.splitlines():
            match = self.pattern.search(line.strip())
            if not match:
                continue

            data = match.groupdict()

            for mp in self.mappers:
                if (
                    mp.source == 'host.pivot.target.host'
                    and mp.edge == 'has_port'
                    and mp.target == 'host.pivot.target.port'
                ):
                    src_val = self.set_value(mp.source, data['host'], self.used_facts)
                    tgt_val = self.set_value(mp.target, data['port'], self.used_facts)
                    relationships.append(
                        Relationship(
                            source=(mp.source, src_val),
                            edge=mp.edge,
                            target=(mp.target, tgt_val),
                        )
                    )

                elif (
                    mp.source == 'host.pivot.target.host'
                    and mp.edge == 'has_user'
                    and mp.target == 'host.pivot.target.user'
                ):
                    src_val = self.set_value(mp.source, data['host'], self.used_facts)
                    tgt_val = self.set_value(mp.target, data['user'], self.used_facts)
                    relationships.append(
                        Relationship(
                            source=(mp.source, src_val),
                            edge=mp.edge,
                            target=(mp.target, tgt_val),
                        )
                    )

                elif (
                    mp.source == 'host.pivot.target.user'
                    and mp.edge == 'has_password'
                    and mp.target == 'host.pivot.target.password'
                ):
                    src_val = self.set_value(mp.source, data['user'], self.used_facts)
                    tgt_val = self.set_value(mp.target, data['password'], self.used_facts)
                    relationships.append(
                        Relationship(
                            source=(mp.source, src_val),
                            edge=mp.edge,
                            target=(mp.target, tgt_val),
                        )
                    )

                elif (
                    mp.source == 'host.pivot.target.host'
                    and mp.edge == 'maps_name'
                    and mp.target == 'host.pivot.target.name'
                ):
                    src_val = self.set_value(mp.source, data['host'], self.used_facts)
                    tgt_val = self.set_value(mp.target, data['target'], self.used_facts)
                    relationships.append(
                        Relationship(
                            source=(mp.source, src_val),
                            edge=mp.edge,
                            target=(mp.target, tgt_val),
                        )
                    )

        return relationships
