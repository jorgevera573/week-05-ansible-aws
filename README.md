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

<!-- BEGIN cc:que-se-valora -->
¡Hola! Aquí te explico qué es lo que miraremos con lupa cuando corrijamos tu proyecto de Ansible AWS. La idea es que sepas dónde poner el foco para que tu trabajo brille.

## 📋 Qué se valora

Lo que más pesa es que tu proyecto funcione tal y como se pide en el enunciado, es decir, que haga exactamente lo que se espera de él. También es muy importante que tu código esté bien escrito y que la forma en que has organizado todo tenga sentido y sea robusta. Le daremos un peso importante a tu vídeo demo, porque nos ayuda a ver cómo funciona todo en la práctica y cómo lo explicas. Por último, aunque con un peso menor, nos fijaremos en cómo has documentado tus decisiones y tu proyecto en general.

Recuerda que el enunciado es la guía principal y que no te penalizaremos por cosas que no se pidan explícitamente en él.
<!-- END cc:que-se-valora -->

---

# 📘 Documentación de la implementación

> Todo lo anterior es el enunciado original del proyecto. Lo que sigue documenta
> cómo se ha implementado.

## Arquitectura real desplegada

```
Windows (PowerShell)            WSL Ubuntu (Ansible)
   terraform  ──────────┐          ansible-playbook
                        │                 │
                        ▼                 │ SSH (clave con passphrase
              AWS us-east-1               │       vía ssh-agent)
   ┌────────────────────────────────────┐ │
   │ VPC 10.20.0.0/16                   │◄┘
   │  └ subred pública 10.20.1.0/24     │
   │     └ EC2 Ubuntu 24.04 (t3.micro)  │
   │        Elastic IP 54.160.157.177   │
   └────────────────────────────────────┘
              ▲            ▲
        :80 / :443    aws.jorgeveraoficial.com (registro A en GoDaddy)
              │
        Nginx ─ reverse proxy ─► Node.js 22 LTS en 127.0.0.1:3000 (systemd)
```

El puerto **3000 no está publicado** en el security group: la aplicación escucha
solo en loopback y únicamente Nginx puede alcanzarla.

## Estructura del repositorio

```
infra/                      # Fase 1 — Terraform (VPC, subred, IGW, SG, EC2, EIP)
ansible.cfg                 # Configuración de Ansible
site.yml                    # Playbook principal: compone los cuatro roles
inventory/hosts.yml         # La EC2 (grupo web), usuario ubuntu, clave SSH
group_vars/all.yml          # Dominio, correo TLS, rama de Node, datos de la app
roles/
  common/                   # apt update + upgrade, paquetes base, política de reinicio
  nodejs/                   # NodeSource (keyring + repo deb822) + app demo + systemd
  nginx/                    # Reverse proxy; plantilla única del vhost
  certbot/                  # Comprobación DNS, emisión TLS y renovación automática
docs/guion-demo.md          # Guion de rodaje del vídeo demo
.gitlab-ci.yml              # CI de validación (lint + syntax-check + terraform validate)
.yamllint / .ansible-lint   # Configuración de los linters
requirements-dev.txt        # Versiones fijadas de las herramientas de validación
```

## Decisiones de diseño

### Una sola fuente de verdad para la configuración de Nginx

El riesgo clásico de esta práctica es que `certbot --nginx` reescriba el virtual
host y que, en la siguiente ejecución, la plantilla de Ansible deshaga esos
cambios. El resultado sería un playbook que nunca converge.

La solución adoptada es invocar **`certbot certonly --nginx`**: el plugin de
Nginx se usa *solo como autenticador* del challenge HTTP-01 y **no modifica** la
configuración del servidor. Toda la configuración TLS (bloque `listen 443`,
protocolos, cabeceras, redirección 301) vive en `roles/nginx/templates/site.conf.j2`.

La plantilla se renderiza en dos estados según exista o no el `fullchain.pem`:

| Estado | Resultado |
|---|---|
| Sin certificado | Solo `server { listen 80; }` con `proxy_pass` → la validación de Let's Encrypt puede completarse y el sitio ya responde |
| Con certificado | `listen 80` redirige con 301 a HTTPS + `server { listen 443 ssl; }` con el reverse proxy |

Por eso el rol `certbot` vuelve a aplicar `roles/nginx/tasks/vhost.yml` mediante
`include_role` una vez emitido el certificado: en la **primera** ejecución el
vhost pasa de HTTP a HTTPS dentro del mismo playbook, y en la **segunda** ya se
renderiza directamente con TLS, sin cambios.

Nunca se referencia un certificado inexistente, de modo que `nginx -t` nunca
falla por esa causa.

### Idempotencia

- `certbot certonly` se ejecuta con `creates:` apuntando al `fullchain.pem`: en
  ejecuciones posteriores la tarea se omite, sin consumir cuota de Let's Encrypt.
  De la renovación se encarga el timer, no el playbook.
- El bloque de comprobaciones DNS/HTTP solo corre cuando aún no hay certificado.
- Módulos nativos con nombre completo (`ansible.builtin.*`) en lugar de `shell`.
  Los únicos `command` son `dig`, `node --version` y `nginx -t`, todos con
  `changed_when: false`, más `certbot` protegido con `creates:`.
- **Cambio legítimo esperado en la segunda ejecución**: la tarea *Actualizar los
  paquetes del sistema* reporta `changed` siempre que Ubuntu haya publicado
  paquetes nuevos desde la ejecución anterior. Es un cambio de origen externo, no
  un fallo de idempotencia. Se puede desactivar con `-e common_apt_upgrade=false`.

### Handlers y validación antes de recargar

`roles/nginx/handlers/main.yml` define dos handlers en este orden:

1. **Validar la configuracion de Nginx** — ejecuta `nginx -t`.
2. **Recargar Nginx** — `systemctl reload nginx`.

Ansible ejecuta los handlers en su orden de *definición*, no de notificación, así
que la validación corre siempre antes de la recarga. Si `nginx -t` falla, el play
aborta, la recarga no llega a ejecutarse y Nginx sigue sirviendo la configuración
que ya tenía cargada en memoria.

### NodeSource sin `curl | bash`

El rol `nodejs` descarga el keyring con `ansible.builtin.get_url` a
`/etc/apt/keyrings/nodesource.asc` y declara el repositorio con
`ansible.builtin.deb822_repository` (`signed_by` apuntando a ese keyring). Un pin
de APT en `/etc/apt/preferences.d/nodesource.pref` garantiza que `nodejs` venga
siempre de NodeSource y no del repositorio de Ubuntu. Tras instalar, una
aserción comprueba que `node --version` pertenece a la rama esperada.

### Política de reinicio

El playbook **nunca reinicia** el servidor por su cuenta. Si una actualización
deja `/var/run/reboot-required`, se informa por pantalla y el reinicio queda como
decisión manual. Para autorizarlo explícitamente: `-e common_allow_reboot=true`.

## Variables principales (`group_vars/all.yml`)

| Variable | Valor | Descripción |
|---|---|---|
| `app_domain` | `aws.jorgeveraoficial.com` | Dominio del certificado y del `server_name` |
| `app_public_ip` | `54.160.157.177` | Elastic IP; se compara contra el registro A |
| `letsencrypt_email` | `jverav573@gmail.com` | Contacto de Let's Encrypt |
| `nodejs_major_version` | `22` | Rama LTS de Node.js |
| `app_listen_host` / `app_listen_port` | `127.0.0.1` / `3000` | Destino del reverse proxy |
| `app_user` / `app_dir` | `demoapp` / `/opt/demoapp` | Usuario sin privilegios y directorio del servicio |
| `certbot_enabled` | `true` | `false` ejecuta todo menos la emisión de TLS |

Interruptores útiles en `roles/certbot/defaults/main.yml`: `certbot_staging`
(entorno de pruebas de Let's Encrypt), `certbot_enforce_dns_check` y
`certbot_http_precheck`.

## Requisitos de DNS

Antes de emitir el certificado deben cumplirse dos condiciones, que el rol
`certbot` **verifica y exige** antes de llamar a Let's Encrypt:

1. El registro **A** de `aws.jorgeveraoficial.com` resuelve a la Elastic IP
   `54.160.157.177` (se consulta con `dig @1.1.1.1`).
2. **No** existen registros **AAAA**. Let's Encrypt prefiere IPv6 para el
   challenge y esta EC2 no tiene IPv6 pública, así que un AAAA haría fallar la
   validación.

Si alguna falla, el playbook se detiene con un mensaje explicando qué corregir en
GoDaddy, en lugar de gastar intentos contra la API de Let's Encrypt, que tiene
límites de emisión por dominio y semana.

## Cómo ejecutar

### Terraform — desde **PowerShell** (Windows)

```powershell
cd C:\MASTER-ING-SOFTWARE\semana-05\1.4.30-ansible-aws\infra
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform output
```

### Ansible — desde **WSL Ubuntu**, en la terminal con `ssh-agent`

La clave privada tiene passphrase, así que el playbook debe lanzarse desde la
misma terminal donde está cargado el agente:

```bash
# 1. Cargar la clave en el agente (una vez por sesión de terminal)
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/master-semana05          # pedirá la passphrase
ssh-add -l                              # comprobar que aparece la clave

# 2. Situarse en el repositorio y fijar ANSIBLE_CONFIG de forma explícita
cd /mnt/c/MASTER-ING-SOFTWARE/semana-05/1.4.30-ansible-aws
export ANSIBLE_CONFIG=/mnt/c/MASTER-ING-SOFTWARE/semana-05/1.4.30-ansible-aws/ansible.cfg

# 3. Conectividad
ansible all -m ping

# 4. Ejecutar el playbook
ansible-playbook site.yml

# 5. Segunda ejecución: comprobar idempotencia
ansible-playbook site.yml
```

> **`ANSIBLE_CONFIG` es obligatorio.** El repositorio vive en `/mnt/c`, un montaje
> DrvFs que expone los ficheros como *world-writable*. Ansible ignora por
> seguridad un `ansible.cfg` en esas condiciones, y sin la variable no cargaría
> el inventario ni la configuración SSH.

### Ejecuciones parciales útiles

```bash
ansible-playbook site.yml --tags nginx                # solo el reverse proxy
ansible-playbook site.yml -e certbot_enabled=false    # todo menos TLS
ansible-playbook site.yml --check --diff              # simulación
```

## Verificación

Desde WSL, con el mismo `ANSIBLE_CONFIG` exportado:

```bash
# Servicios activos y persistentes
ansible all -b -m ansible.builtin.command -a "systemctl is-enabled nginx demoapp"
ansible all -b -m ansible.builtin.command -a "systemctl is-active nginx demoapp"

# La app solo escucha en loopback
ansible all -b -m ansible.builtin.shell -a "ss -lntp | grep :3000"

# Timer de renovación
ansible all -b -m ansible.builtin.command -a "systemctl list-timers certbot.timer --no-pager"

# Simulacro de renovación: no emite nada real
ansible all -b -m ansible.builtin.command -a "certbot renew --dry-run"
```

Desde cualquier máquina:

```bash
curl -I http://aws.jorgeveraoficial.com          # 301 hacia https
curl -s https://aws.jorgeveraoficial.com         # JSON de la app de demo
curl -sI https://aws.jorgeveraoficial.com | head -1

# Certificado: emisor y fechas de validez
echo | openssl s_client -connect aws.jorgeveraoficial.com:443 -servername aws.jorgeveraoficial.com 2>/dev/null | openssl x509 -noout -issuer -dates

# El 3000 NO debe ser accesible desde fuera: debe agotar el tiempo
curl --max-time 5 http://54.160.157.177:3000
```

## Evidencias de la ejecución

Resultados obtenidos por el alumno al ejecutar el playbook contra la EC2 desde
su terminal WSL con `ssh-agent`. El entorno quedó operativo en
`https://aws.jorgeveraoficial.com`.

### Respuesta del servicio

| Comprobación | Resultado |
|---|---|
| `curl -I http://aws.jorgeveraoficial.com` | **301** hacia HTTPS |
| `curl https://aws.jorgeveraoficial.com` | **200** con el JSON de la aplicación |

La redirección y el certificado funcionan de extremo a extremo: Internet →
Nginx :443 → reverse proxy → Node.js en `127.0.0.1:3000`.

### Idempotencia

Segunda ejecución de `ansible-playbook site.yml`, sin cambios previos:

```
ok=41   changed=0   unreachable=0   failed=0   skipped=8
```

**`changed=0`**: el playbook converge. Los 8 `skipped` corresponden a las tareas
que ya no aplican una vez emitido el certificado (el bloque de comprobación de
DNS y de emisión TLS se salta por completo gracias a `creates:`) y a las que
dependen de condiciones no cumplidas, como el reinicio pendiente.

### Renovación automática del certificado

```
certbot renew --dry-run
```

Todas las renovaciones simuladas se completaron **correctamente**. El simulacro
recorre el mismo camino que una renovación real sin emitir ni instalar nada.

### Persistencia tras reinicio

Reinicio ordenado del servidor mediante Ansible:

```
rebooted=true   elapsed=20
```

Tras volver a arrancar, sin reaplicar el playbook:

| Unidad | Estado |
|---|---|
| `nginx` | `active` y `enabled` |
| `demoapp` | `active` y `enabled` |
| `certbot.timer` | `active` y `enabled`, con próxima ejecución programada |

Y el servicio siguió respondiendo:

```
https://aws.jorgeveraoficial.com -> 200
```

Esto confirma que la configuración es **persistente**, no un estado conseguido
solo durante la ejecución del playbook: las unidades systemd están habilitadas,
el temporizador de renovación queda programado y el sitio vuelve por sí solo.

## Validación estática (linters)

Herramientas y versiones fijadas en `requirements-dev.txt`:
`ansible-core 2.21.4`, `ansible-lint 26.8.0`, `yamllint 1.38.0`.

```bash
cd /mnt/c/MASTER-ING-SOFTWARE/semana-05/1.4.30-ansible-aws
export ANSIBLE_CONFIG=/mnt/c/MASTER-ING-SOFTWARE/semana-05/1.4.30-ansible-aws/ansible.cfg
yamllint .
ansible-playbook site.yml --syntax-check
ansible-lint
```

`.ansible-lint` usa el perfil **`production`**, el más estricto de ansible-lint.

## CI en GitLab

`.gitlab-ci.yml` sustituye a Auto DevOps con un pipeline propio de una sola
etapa (`lint`) y dos jobs:

- **`ansible:lint`** — `yamllint`, `ansible-playbook --syntax-check` y `ansible-lint`.
- **`terraform:validate`** — `terraform fmt -check` y `terraform validate` con
  `terraform init -backend=false`.

### Resultado del pipeline remoto

Evidencias aportadas por el alumno desde GitLab:

| Dato | Valor |
|---|---|
| Pipeline | **#3079** — **passed** |
| Commit validado | `380b2404` |
| `ansible:lint` | **Passed**, 27 segundos |
| `terraform:validate` | **Passed**, 18 segundos |

Enlace: <https://gitlab.codecrypto.academy/jverav573/1.4.30-ansible-aws/-/pipelines/3079>

### Cómo está construido

El proyecto usa un runner con la etiqueta **`cloudrun`** y **ejecutor `shell`**.
Eso condiciona todo el diseño del fichero: un ejecutor `shell` corre los comandos
directamente sobre la máquina del runner y **no admite `image:`**, así que cada
job tiene que procurarse sus propias herramientas.

- **`default.tags: [cloudrun]`** selecciona el runner. Sin esta etiqueta los jobs
  se quedan en estado *pending* sin que ningún runner los recoja.
- **`ansible:lint`** instala `python3-venv` y `git`, crea un **entorno virtual de
  Python en un directorio temporal** (`mktemp -d`) e instala ahí
  `requirements-dev.txt`. Un `trap ... EXIT` borra el temporal al terminar el
  job, de modo que no queda estado entre ejecuciones en un runner persistente.
  `git` es necesario porque `ansible-lint` lo usa para descubrir los ficheros del
  repositorio.
- **`terraform:validate`** descarga **Terraform 1.16.3** —la misma versión que se
  usa en local— en otro directorio temporal, se baja el fichero `SHA256SUMS`
  publicado por HashiCorp y **verifica el archivo con `sha256sum -c`** antes de
  descomprimirlo. Solo entonces añade el binario al `PATH`. La arquitectura se
  detecta con `uname -m` (`amd64` / `arm64`).
- **Ninguna colección de Galaxy**: el playbook usa solo módulos `ansible.builtin`
  y, tras corregir el callback, `ansible.cfg` tampoco depende de
  `community.general`. Basta con `ansible-core`.
- Las versiones vienen de `requirements-dev.txt`, las mismas que se usan en local.

El pipeline **no recibe credenciales de AWS**, no accede al estado de Terraform,
no ejecuta `apply` ni `destroy` y no se conecta por SSH a la EC2. El único
`terraform init` se lanza con `-backend=false`.

> **Alcance**: el pipeline valida **código estático**. Que esté en verde
> significa que el formato, la sintaxis y las buenas prácticas son correctas —
> no que la infraestructura esté desplegada ni que el servicio responda. Eso lo
> acreditan las evidencias de la sección anterior.

## Incidencias encontradas

### Durante el despliegue real

Estas tres incidencias aparecieron al aplicar la infraestructura y ejecutar el
playbook contra la EC2. Las tres están ya corregidas en el repositorio.

#### 1. Descripciones de reglas AWS con caracteres no admitidos

Al aplicar Terraform, la creación de dos reglas del security group fue rechazada
por AWS: el campo `description` de una regla solo admite un juego limitado de
caracteres, y las descripciones escritas en castellano contenían un apóstrofo
(`Let's Encrypt`), que no está permitido.

**Solución**: se reescribieron esas dos descripciones con caracteres admitidos.
Las reglas afectadas quedaron como:

| Recurso | Descripción actual |
|---|---|
| `aws_vpc_security_group_ingress_rule.http` | `Allow HTTP on port 80` |
| `aws_vpc_security_group_egress_rule.all` | `Allow all outbound traffic` |

Se aplicó un plan nuevo que contenía **únicamente las dos reglas pendientes**;
el resto de la infraestructura ya creada no se tocó.

#### 2. Callback `community.general.yaml` eliminado

`ansible.cfg` fijaba `stdout_callback = yaml`, que resolvía al callback
`community.general.yaml`. Ese plugin fue **retirado de la colección**, de modo
que la ejecución fallaba al cargar la configuración.

**Solución**: se sustituyó por el equivalente actual, que vive en el propio
`ansible-core`:

```ini
stdout_callback        = ansible.builtin.default
callback_result_format = yaml
```

Se obtiene la misma salida legible en YAML y, como efecto secundario deseable,
el proyecto deja de depender de ninguna colección de Galaxy: el CI solo necesita
instalar `ansible-core`.

#### 3. Nginx 1.24 no admite la directiva independiente `http2 on`

La plantilla del virtual host declaraba `http2 on;` como directiva propia. Esa
forma se introdujo en Nginx 1.25; **Ubuntu 24.04 distribuye Nginx 1.24**, que
solo admite HTTP/2 como parámetro de `listen`. `nginx -t` rechazaba la
configuración y el handler de validación detenía el play — exactamente el
comportamiento buscado: la recarga no llegó a ejecutarse y Nginx siguió
sirviendo la configuración anterior.

**Solución**: se eliminó la directiva de la plantilla y se conservó
`listen 443 ssl;`. El sitio sirve HTTPS correctamente sobre HTTP/1.1.

### En el CI de GitLab

Hasta llegar al pipeline #3079 en verde hubo tres tropiezos, todos ya resueltos
en `.gitlab-ci.yml`:

| Incidencia | Causa | Solución |
|---|---|---|
| Los jobs se quedaban en *pending*, sin ejecutarse | Ningún runner recogía los jobs porque no coincidía la selección por etiquetas | Se declaró `default.tags: [cloudrun]`, la etiqueta del runner disponible en el proyecto |
| Faltaban herramientas dentro del job (`python`, `terraform`) | El runner usa el **ejecutor `shell`**, que ejecuta los comandos sobre la propia máquina y **no interpreta `image:`**; la imagen de contenedor que se había declarado simplemente se ignoraba | Cada job se procura sus herramientas: `ansible:lint` crea un entorno virtual de Python en un temporal, y `terraform:validate` descarga Terraform 1.16.3 verificando su SHA-256 |
| El fichero no era YAML válido | Indentación incorrecta y falta del salto de línea final | Se corrigió la indentación y se añadió el salto de línea al final del fichero |

La segunda es la que explica el diseño del pipeline: con un ejecutor `shell` no
hay contenedor que traiga las herramientas, así que instalarlas —y limpiarlas
con `trap ... EXIT`— forma parte del propio job.

### Durante la generación del código

| Incidencia | Causa | Solución |
|---|---|---|
| `terraform fmt` fallaba con *«The symbol "." is not a valid escape sequence selector»* | La validación de `ssh_allowed_cidr` usaba `regex()` con escapes `\.`, que HCL no admite | Se sustituyó por una condición sin escapes: CIDR válido, distinto de `0.0.0.0/0` y con prefijo ≥ /24 |
| `yamllint` marcaba *«wrong new line character»* | Ficheros editados desde Windows quedaron con CRLF | Se normalizaron a LF y se añadió `.gitattributes` con `* text=auto eol=lf` |
| `tfplan-reparacion` aparecía como fichero sin seguimiento | `.gitignore` solo cubría `tfplan` y `*.tfplan` | Se añadió el comodín `tfplan*` |
| `ansible.cfg` ignorado al ejecutar desde `/mnt/c` | El montaje DrvFs marca los ficheros como *world-writable* | Se exporta siempre `ANSIBLE_CONFIG` con la ruta absoluta |
| La clave SSH tiene passphrase | Un proceso no interactivo no puede desbloquearla | El playbook se lanza desde la terminal WSL con `ssh-agent` cargado |

## Costes y limpieza del laboratorio

Esto **no es gratuito**. Con precios on-demand de `us-east-1`, a verificar
siempre en la calculadora de AWS:

| Recurso | Coste aproximado |
|---|---|
| EC2 `t3.micro` en ejecución | ~0,01 USD/h ≈ **7–8 USD/mes** |
| Volumen gp3 de 12 GiB | ~**1 USD/mes**, también con la instancia parada |
| IPv4 pública / Elastic IP | ~0,005 USD/h ≈ **3,6 USD/mes**, también con la instancia parada o la IP sin asociar |
| Tráfico de salida | Según consumo, más allá de la franja gratuita |

Limpieza cuando la práctica termine:

```powershell
cd C:\MASTER-ING-SOFTWARE\semana-05\1.4.30-ansible-aws\infra
terraform plan -destroy -out=tfplan-destroy
terraform apply tfplan-destroy
```

Antes de destruir:

- Revisar el plan de destrucción **línea por línea**: debe afectar solo a los
  recursos con `Project=master-semana05` y a ninguno de ALINA.
- El `terraform destroy` solo actúa sobre el estado local de `infra/`; no toca
  nada que Terraform no haya creado.
- **DNS**: el registro A de `aws.jorgeveraoficial.com` en GoDaddy no lo gestiona
  Terraform. Hay que borrarlo o reapuntarlo a mano, o quedará apuntando a una IP
  que AWS reasignará a otra cuenta.
- Conservar `infra/terraform.tfstate`: sin él Terraform pierde el control de los
  recursos y habría que borrarlos a mano desde la consola.

## Guion para la demo

Guion de rodaje completo, con qué mostrar, qué decir y qué comando ejecutar en
cada paso: **[`docs/guion-demo.md`](docs/guion-demo.md)**.

Resumen de los puntos a cubrir:

1. **Terraform** — `infra/main.tf` y `terraform output`: VPC, subred, security
   group (22 restringido, 80/443 públicos, 3000 cerrado), EC2 y Elastic IP.
2. **Inventario y variables** — `inventory/hosts.yml` y `group_vars/all.yml`:
   apuntar a otro servidor solo requiere cambiar el inventario.
3. **Roles** — `site.yml` compone `common → nodejs → nginx → certbot`; cada rol
   tiene una responsabilidad.
4. **Handlers** — `roles/nginx/handlers/main.yml`: `nginx -t` antes de recargar,
   y la recarga solo si la plantilla cambió.
5. **Idempotencia** — segunda ejecución del playbook:
   `ok=41 changed=0 unreachable=0 failed=0 skipped=8`.
6. **HTTPS** — `curl -I http://...` devuelve 301; `curl https://...` devuelve 200
   con el JSON de la app; `openssl s_client` muestra el emisor Let's Encrypt.
7. **Renovación** — `systemctl list-timers certbot.timer` y
   `certbot renew --dry-run`, que completa todas las renovaciones simuladas.
8. **Persistencia** — reinicio con Ansible (`rebooted=true`, `elapsed=20`) y,
   sin reaplicar nada, `nginx`, `demoapp` y `certbot.timer` vuelven `active` y
   `enabled`, y el sitio sigue respondiendo 200 por HTTPS.
9. **CI** — pipeline [#3079](https://gitlab.codecrypto.academy/jverav573/1.4.30-ansible-aws/-/pipelines/3079)
   en verde, dejando claro que valida código estático, no el despliegue.


## Dominio de desarrollo del campus (consolidacion)

El campus registra `*.jverav573.alumnos.codecrypto.dev` hacia `54.160.157.177`.
Se publica `https://web.jverav573.alumnos.codecrypto.dev` como segundo acceso
al mismo backend `127.0.0.1:3000`. El certificado cubre ese nombre concreto,
no todos los nombres del comodin DNS.

`campus_domain` define el nuevo dominio. El segundo play de `site.yml` reutiliza
los roles nginx y certbot con variables locales: conserva el vhost original
`demoapp.conf` y gestiona `campus-web.conf`. No modifica la aplicacion Node.js;
por eso el campo `dominio` de su JSON sigue mostrando el dominio original.

La plantilla normaliza los identificadores internos de Nginx para admitir el
nombre de archivo `campus-web`. Si no existe certificado, publica primero HTTP;
el rol certbot lo emite y vuelve a renderizar HTTPS. Un certificado ya existente
no se reemite: se mantiene su configuracion de renovacion, incluido el metodo
webroot utilizado en la configuracion manual del campus. Para servidores nuevos,
se mantiene la estrategia `certonly --nginx` del rol original.

Ambos certificados usan el timer existente y un unico hook `reload-nginx.sh`,
que valida con `nginx -t` antes de recargar. Ansible retira el hook manual
`reload-nginx-campus` para evitar recargas duplicadas.

### Aplicacion desde WSL

En la terminal WSL local, con la clave cargada en ssh-agent:

```bash
cd /mnt/c/MASTER-ING-SOFTWARE/semana-05/1.4.30-ansible-aws
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
yamllint .
ansible-playbook site.yml --syntax-check
ansible-lint
ansible-playbook site.yml --tags campus
ansible-playbook site.yml --tags campus
```

La segunda ejecucion debe converger sin cambios. El despliegue completo de
`site.yml` configura ambos dominios; `--tags campus` actualiza solo los roles
web/TLS del campus sobre el servidor existente.

```bash
curl -I http://web.jverav573.alumnos.codecrypto.dev
curl -I https://web.jverav573.alumnos.codecrypto.dev
curl -I https://aws.jorgeveraoficial.com
ansible all -b -m ansible.builtin.command -a "certbot renew --cert-name web.jverav573.alumnos.codecrypto.dev --dry-run"
```

Evidencia previa a esta integracion: el 2 de octubre de 2026 el alumno comprobo
HTTPS 200 en ambos dominios y la respuesta JSON en el navegador del campus.
La aplicacion de este cambio con Ansible y su idempotencia deben verificarse
con los comandos anteriores; esas pruebas remotas no se han ejecutado aqui.

El acceso SSH se habilito desde la IP publica actual del alumno mediante una
regla /32. Antes de un futuro `terraform apply`, actualizar `ssh_allowed_cidr`
en el `infra/terraform.tfvars` local y revisar el plan para reconciliar la regla
manual. No versionar el estado ni las claves privadas.
