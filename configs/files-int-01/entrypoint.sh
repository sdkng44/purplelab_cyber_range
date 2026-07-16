#!/usr/bin/env bash
set -e

mkdir -p /var/run/sshd
mkdir -p /srv/shares/corp
mkdir -p /var/log/samba
ssh-keygen -A

cat > /srv/shares/corp/HR_Policy_2026.txt <<'EOF'
Purple Lab internal document
HR policy summary for internal testing
EOF

cat > /srv/shares/corp/Finance_Q3_2026.csv <<'EOF'
employee_id,name,amount
1001,Alice,4200
1002,Bob,3900
EOF

cat > /srv/shares/corp/IT_Operations_Notes.txt <<'EOF'
Internal IT notes for Purple Lab only
EOF

chown -R analyst:analyst /srv/shares/corp

exec "$@"
