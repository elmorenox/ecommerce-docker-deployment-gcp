#!/bin/bash
mkdir -p /home/ubuntu/.ssh
cat <<'EOP' > /home/ubuntu/.ssh/id_rsa
${private_key}
EOP
chmod 600 /home/ubuntu/.ssh/id_rsa
chown -R ubuntu:ubuntu /home/ubuntu/.ssh