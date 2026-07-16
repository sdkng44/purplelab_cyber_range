import re

try:
    from app.objects.secondclass.c_relationship import Relationship
except Exception:
    from app.objects.c_relationship import Relationship

from app.utility.base_parser import BaseParser


class Parser(BaseParser):
    pattern = re.compile(r"S13_FINAL_OK host=(?P<host>\S+) user=(?P<user>\S+)")

    def parse(self, blob):
        relationships = []

        for line in blob.splitlines():
            match = self.pattern.search(line.strip())
            if not match:
                continue

            data = match.groupdict()

            for mp in self.mappers:
                if (
                    mp.source == 's13.compromised.host'
                    and mp.edge == 'has_user'
                    and mp.target == 'local.user.name'
                ):
                    src_val = self.set_value(mp.source, data['host'], self.used_facts)
                    tgt_val = self.set_value(mp.target, data['user'], self.used_facts)
                    relationships.append(
                        Relationship(
                            source=(mp.source, src_val),
                            edge=mp.edge,
                            target=(mp.target, tgt_val)
                        )
                    )

        return relationships
