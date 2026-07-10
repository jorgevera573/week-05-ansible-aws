# ⚙️ Ansible AWS — Aprovisionamiento de servidor con HTTPS

## 🎯 Objetivo del proyecto

Automatizar con **Ansible** la configuración completa de un servidor Ubuntu en AWS EC2 para alojar tu dominio (ej. `tu-dominio.com`): Nginx como reverse proxy, Node.js como runtime y certificado TLS de Let's Encrypt con renovación automática.

Con este proyecto el alumno aprende:

- **Configuration management**: describir el estado del servidor en YAML en vez de ejecutar comandos a mano.
- El concepto de **idempotencia**: el playbook puede ejecutarse mil veces y el resultado es el mismo.
- A organizar Ansible en **roles** con responsabilidades separadas.
- A obtener y renovar certificados **Let's Encrypt con Certbot** de forma no interactiva.

## 🏗️ Arquitectura

```
┌─────────────┐  ansible-playbook   ┌────────────────────────────────────┐
│  Mi máquina │ ──────── SSH ─────► │  EC2 Ubuntu (<IP-pública-EC2>)     │
│  (control   │                     │  tu-dominio.com                    │
│   node)     │                     │                                    │
└─────────────┘                     │  Internet ──► Nginx :443 (TLS)     │
                                    │                 │ reverse proxy    │
                                    │                 ▼                  │
                                    │           Node.js app :3000        │
                                    │                                    │
                                    │  Certbot + timer de renovación     │
                                    └────────────────────────────────────┘
```

### Estructura del proyecto

```
site.yml                 # Playbook principal: aplica los roles en orden
ansible.cfg              # Configuración (inventario, clave SSH)
inventory/hosts.yml      # El servidor EC2 (usuario ubuntu, tu clave SSH)
group_vars/all.yml       # Variables: dominio, email, versión de Node...
roles/
  common/                # apt update/upgrade del sistema
  nginx/                 # Instala Nginx + virtual host reverse proxy → :3000
  nodejs/                # Node.js LTS vía NodeSource
  certbot/               # Certificado TLS + renovación automática
```

## ⚙️ Funcionalidades (qué hace el playbook)

1. Actualiza los paquetes del sistema (`apt update && upgrade`).
2. Instala y habilita **Nginx**.
3. Instala **Node.js LTS** desde NodeSource.
4. Instala **Certbot** con el plugin de Nginx.
5. Obtiene el certificado TLS para tu dominio en modo no interactivo.
6. Configura Nginx como **reverse proxy** hacia la app Node.js (puerto 3000).
7. Programa la **renovación automática** del certificado.

## 💡 Solución

1. **Roles = responsabilidades**: cada componente (sistema, web, runtime, TLS) vive en su rol con sus tareas y handlers. `site.yml` solo los compone en orden — el mismo patrón de capas que en el código de aplicación.
2. **Idempotencia con módulos nativos**: usando `apt`, `service`, `template`... Ansible comprueba el estado antes de actuar. Ejecutar el playbook de nuevo no rompe nada ni repite trabajo.
3. **Handlers para los reinicios**: Nginx solo se recarga si su configuración cambió (notificación `notify` → handler), no en cada ejecución.
4. **Certbot necesita el DNS resuelto**: el dominio ya apunta a la IP antes de pedir el certificado, porque Let's Encrypt valida el dominio visitando el servidor (challenge HTTP).
5. **Variables en `group_vars`**: dominio, email y versiones están parametrizados — apuntar a otro servidor solo requiere cambiar el inventario.

## 🚀 Cómo ejecutar

Requisitos: Ansible instalado en local y acceso SSH a la EC2.

```bash
# Probar conectividad
ansible all -m ping

# Aplicar todo el playbook
ansible-playbook site.yml

# Verificar
curl -I https://tu-dominio.com
```
