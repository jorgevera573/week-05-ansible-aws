# 🎬 Guion para el vídeo demo (~6 minutos)

Guion de rodaje para la demo de la práctica **1.4.30 — Ansible AWS**.
Cada paso indica **qué mostrar** en pantalla, **qué decir** y **qué comando
ejecutar**.

## Antes de grabar

- [ ] Terminal WSL abierta, con la clave cargada en el agente:
      `eval "$(ssh-agent -s)"` y `ssh-add ~/.ssh/master-semana05`.
- [ ] `export ANSIBLE_CONFIG=/mnt/c/MASTER-ING-SOFTWARE/semana-05/1.4.30-ansible-aws/ansible.cfg`
- [ ] Editor abierto en la raíz del repositorio.
- [ ] Navegador con dos pestañas: `https://aws.jorgeveraoficial.com` y el
      pipeline #3079.
- [ ] Fuente de terminal grande y legible en vídeo.

> **No mostrar en pantalla**: `infra/terraform.tfvars`, `infra/terraform.tfstate`,
> el contenido de `~/.ssh/`, la salida de `aws sts get-caller-identity`, ni
> ninguna variable de entorno con credenciales. Si hace falta enseñar variables,
> usar `infra/terraform.tfvars.example`, que no contiene secretos.

---

## 1 · Qué resuelve cada herramienta — 45 s

**Mostrar**: el diagrama de arquitectura del README (sección *Arquitectura real
desplegada*).

**Decir**:

> «El proyecto tiene dos mitades que no se solapan. **Terraform** crea la
> infraestructura: la red, la máquina y su IP pública. Es la capa de *dónde*.
> **Ansible** configura el sistema operativo dentro de esa máquina: paquetes,
> Nginx, Node.js y el certificado. Es la capa de *cómo*.
> Terraform habla con la API de AWS; Ansible entra por SSH. Terraform no instala
> software y Ansible no crea máquinas.»

**Ejecutar**: nada, es una lámina.

---

## 2 · La infraestructura declarada — 50 s

**Mostrar**: `infra/main.tf`, bajando por VPC → subred → security group → EC2 →
Elastic IP. Después, la salida de `terraform output`.

**Decir**:

> «Toda la infraestructura está declarada en código: una VPC propia, una subred
> pública con su Internet Gateway, el security group y la instancia.
> Fijaos en el security group: **SSH solo desde mi IP en /32**, HTTP y HTTPS
> abiertos porque son públicos, y **el 3000 no aparece**: la aplicación Node
> nunca se expone a Internet.
> La Elastic IP es lo que hace que el registro DNS pueda apuntar a algo estable.»

**Ejecutar**:

```powershell
cd C:\MASTER-ING-SOFTWARE\semana-05\1.4.30-ansible-aws\infra
terraform output
```

> Si prefieres no lanzar Terraform durante la grabación, enseña el fichero y una
> captura previa de `terraform output`. El resultado relevante es
> `public_ip = 54.160.157.177`.

---

## 3 · Organización en roles — 60 s

**Mostrar**: `site.yml` y el árbol `roles/`.

**Decir**:

> «`site.yml` no contiene tareas: solo compone cuatro roles en orden.
> **common** actualiza el sistema. **nodejs** instala Node LTS desde el
> repositorio de NodeSource —con keyring y repositorio declarados, nunca un
> `curl | bash`— y despliega una aplicación Node mínima de demostración, que
> escucha solo en `127.0.0.1:3000` bajo un usuario sin privilegios y con una
> unidad systemd. **nginx** monta el reverse proxy. **certbot** emite el
> certificado.
> Cada rol tiene sus tareas, sus plantillas y sus handlers: es el mismo patrón
> de capas que usamos en el código de aplicación.»

**Ejecutar**:

```bash
cd /mnt/c/MASTER-ING-SOFTWARE/semana-05/1.4.30-ansible-aws
cat site.yml
find roles -maxdepth 2 -type d | sort
```

**Rematar con los handlers** (abrir `roles/nginx/handlers/main.yml`):

> «Aquí está la pieza que más me gusta: antes de recargar Nginx se ejecuta
> `nginx -t`. Ansible lanza los handlers en orden de definición, así que la
> validación va siempre delante. Si la configuración estuviera mal, el play
> aborta y Nginx sigue sirviendo la versión anterior. De hecho esto me saltó de
> verdad: lo cuento en el minuto final.»

---

## 4 · El servicio funcionando: 301 y 200 — 60 s

**Mostrar**: la terminal con los `curl`, y luego el navegador en
`https://aws.jorgeveraoficial.com`.

**Decir**:

> «Primero en claro: la petición HTTP no sirve contenido, **responde 301** y
> manda al usuario a HTTPS. Y ahora por HTTPS: **200**, y el JSON que devuelve
> la aplicación Node.
> Ese JSON sale del proceso Node que escucha en loopback. O sea que la cadena
> completa funciona: Internet, Nginx en el 443 con TLS, reverse proxy, y Node en
> el 3000.»

**Ejecutar**:

```bash
curl -I http://aws.jorgeveraoficial.com
curl -s https://aws.jorgeveraoficial.com
```

**Cerrar el argumento** enseñando que el puerto no está abierto:

```bash
curl --max-time 5 http://54.160.157.177:3000    # agota el tiempo: no está expuesto
```

---

## 5 · Idempotencia en directo — 70 s

**Mostrar**: la ejecución completa del playbook por segunda vez, y el `PLAY
RECAP` final.

**Decir** (mientras corre):

> «Esta es la propiedad que da sentido a todo. El servidor ya está configurado,
> así que voy a lanzar el playbook **otra vez** sobre la misma máquina.
> Ansible no repite el trabajo: comprueba el estado de cada recurso y solo actúa
> si hay diferencia.»

**Decir** (al aparecer el recap):

> «**changed=0**. Cero cambios. El playbook ha convergido: describe un estado, y
> si el estado ya se cumple no toca nada.
> Los ocho `skipped` son el bloque de TLS, que se salta entero porque el
> certificado ya existe — no se reemite en cada ejecución.»

**Ejecutar**:

```bash
ansible-playbook site.yml
```

Recap esperado:

```
ok=41   changed=0   unreachable=0   failed=0   skipped=8
```

> Dura un par de minutos. Si el vídeo va justo, grábalo aparte y **acelera la
> ejecución**, parando en el recap. O usa `--tags nginx`, que es mucho más
> rápido y también da `changed=0`.

---

## 6 · Renovación y persistencia — 50 s

**Mostrar**: las capturas o la salida ya obtenidas del simulacro de renovación y
del reinicio. **No relances el reinicio durante la grabación.**

**Decir**:

> «Un certificado de Let's Encrypt dura 90 días, así que la renovación tiene que
> ser automática. El `certbot.timer` de systemd queda activo y con próxima
> ejecución programada, y el simulacro `certbot renew --dry-run` completa
> correctamente todas las renovaciones: recorre el mismo camino que una
> renovación real sin emitir nada.
> Además hay un hook de despliegue que recarga Nginx solo cuando una renovación
> instala material nuevo.
> Y para comprobar que esto sobrevive a un apagón, reinicié la máquina con
> Ansible: `rebooted=true`. Al volver, **sin reaplicar nada**, Nginx, la
> aplicación y el timer estaban `active` y `enabled`, y el sitio seguía
> respondiendo 200. No es un estado que exista solo mientras corre el playbook.»

**Evidencias a enseñar**:

```
certbot renew --dry-run        -> todas las renovaciones simuladas correctas
reinicio vía Ansible           -> rebooted=true, elapsed=20
tras el reinicio               -> nginx, demoapp y certbot.timer: active + enabled
                                  certbot.timer con próxima ejecución programada
                                  https://aws.jorgeveraoficial.com -> 200
```

---

## 7 · El pipeline de validación — 45 s

**Mostrar**: el navegador en el pipeline
[#3079](https://gitlab.codecrypto.academy/jverav573/1.4.30-ansible-aws/-/pipelines/3079),
con los dos jobs en verde. Después, un vistazo rápido a `.gitlab-ci.yml`.

**Decir**:

> «Sustituí Auto DevOps por un pipeline propio. El **#3079** está en verde sobre
> el commit `380b2404`: `ansible:lint` en 27 segundos y `terraform:validate` en
> 18.
> Y quiero ser preciso con **qué valida**: es validación **estática**.
> `yamllint`, `ansible-lint` con perfil *production*, `--syntax-check`, y del
> lado de Terraform `fmt -check` y `validate`.
> Lo que **no** hace es tan importante como lo que hace: **no recibe credenciales
> de AWS**, no toca el estado de Terraform, no ejecuta `apply` ni `destroy` y no
> se conecta por SSH a la máquina. El único `init` va con `-backend=false`.
> Que esté verde significa que el código está bien escrito, no que el servidor
> esté levantado. Eso lo demuestran las pruebas que acabáis de ver.»

**Ejecutar**: nada, es navegación.

---

## 8 · Cierre: lo que me encontré por el camino — 40 s

**Mostrar**: la sección *Incidencias encontradas* del README.

**Decir**:

> «Tres cosas que me pasaron y que documenté:
> AWS rechazó la creación de dos reglas del security group porque la descripción
> llevaba un apóstrofo, en "Let's Encrypt": el campo solo admite ciertos
> caracteres.
> El callback `yaml` de Ansible había desaparecido de `community.general`, así
> que pasé al callback de `ansible-core` con `callback_result_format`.
> Y la plantilla de Nginx declaraba `http2 on`, que es de Nginx 1.25: Ubuntu
> 24.04 trae la 1.24. Aquí el handler de validación hizo exactamente su trabajo:
> `nginx -t` falló, la recarga no llegó a ejecutarse y el sitio siguió sirviendo
> la configuración anterior.
> Gracias.»

---

## Reparto del tiempo

| Paso | Contenido | Duración |
|---|---|---|
| 1 | Terraform vs. Ansible | 45 s |
| 2 | Infraestructura declarada | 50 s |
| 3 | Roles y handlers | 60 s |
| 4 | 301 y 200 con la app Node | 60 s |
| 5 | Idempotencia (`changed=0`) | 70 s |
| 6 | Renovación y persistencia | 50 s |
| 7 | Pipeline #3079 y su alcance | 45 s |
| 8 | Incidencias y cierre | 40 s |
| | **Total** | **≈ 6 min 20 s** |

Si hay que recortar, el paso 2 admite bajar a 30 segundos y el 8 puede quedarse
en una sola incidencia, la de `http2`, que es la que mejor ilustra el valor de
los handlers.
