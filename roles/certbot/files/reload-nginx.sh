#!/bin/sh
# Gestionado por Ansible (rol certbot). No editar a mano.
#
# Hook de despliegue de Certbot: se ejecuta unicamente cuando una renovacion
# ha instalado material nuevo, de modo que Nginx solo se recarga cuando de
# verdad hace falta.
set -eu

nginx -t
systemctl reload nginx
