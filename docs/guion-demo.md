# Guion para el video demo — 6 minutos

Práctica **1.4.30 — Ansible AWS**.

Cada paso indica qué mostrar, qué decir y qué comandos ejecutar.
Los seis minutos corresponden al video editado, acelerando la espera
durante la ejecución del playbook.

## Antes de grabar

- [ ] Abrir VS Code en la raíz del repositorio.
- [ ] Abrir una terminal PowerShell y otra WSL.
- [ ] Preparar el acceso SSH en WSL antes de iniciar la grabación:

```bash
ssh-add -l
```

Si el agente no está disponible:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/master-semana05
```

Si existe el agente, pero no tiene la clave cargada:

```bash
ssh-add ~/.ssh/master-semana05
```

- [ ] Situarse en el repositorio y seleccionar la configuración de Ansible:

```bash
cd /mnt/c/MASTER-ING-SOFTWARE/semana-05/1.4.30-ansible-aws
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
```

- [ ] Abrir en el navegador:
  - https://aws.jorgeveraoficial.com
  - https://gitlab.codecrypto.academy/jverav573/1.4.30-ansible-aws/-/pipelines/3079
- [ ] Preparar las evidencias anteriores de renovación y reinicio.
- [ ] Usar una fuente de terminal suficientemente grande.
- [ ] Ocultar notificaciones y cerrar pestañas ajenas a la práctica.

**Evitar mostrar:** claves privadas, contraseñas, passphrases, archivos de
credenciales, variables de entorno con secretos, `infra/terraform.tfvars`
e `infra/terraform.tfstate`.

Para explicar las variables, utilizar `infra/terraform.tfvars.example`.

No es necesario mostrar la identidad de la cuenta AWS durante la demo.
El identificador de cuenta no es una contraseña, pero tampoco aporta
información necesaria para esta explicación.

---

## 1. Objetivo y función de las herramientas — 30 segundos

**Mostrar:** el diagrama de arquitectura del README.

**Decir:**

> En esta práctica automatizo un servidor web en AWS.
> Terraform declara y crea la infraestructura: la red, la instancia EC2,
> las reglas de acceso y la IP pública.
> Ansible configura el servidor: instala los paquetes, despliega una
> aplicación Node.js de demostración y configura Nginx y HTTPS.
> En este proyecto, Terraform se comunica con la API de AWS y Ansible
> administra la máquina mediante SSH.

**Ejecutar:** ningún comando.

---

## 2. Infraestructura declarada con Terraform — 40 segundos

**Mostrar:** los recursos principales de `infra/main.tf`:
VPC, subred, Internet Gateway, security group, EC2 y Elastic IP.

**Decir:**

> La infraestructura está descrita en archivos que podemos versionar.
> Tenemos una VPC propia y una subred pública con salida a Internet.
> El acceso SSH está restringido a mi IP pública mediante una regla /32.
> Los puertos 80 y 443 permiten las peticiones web.
> El puerto 3000 no tiene una regla de entrada pública.
> La Elastic IP proporciona una dirección estable para el registro DNS
> de aws.jorgeveraoficial.com.

**Ejecutar en PowerShell:**

```powershell
Set-Location "C:\MASTER-ING-SOFTWARE\semana-05\1.4.30-ansible-aws\infra"
terraform output public_ip
```

**Resultado obtenido en el despliegue:**

```text
"54.160.157.177"
```

Esta consulta muestra una salida del estado local de Terraform.
Por sí sola no comprueba que el servidor esté disponible.

---

## 3. Organización de Ansible y handlers — 50 segundos

**Mostrar:** `site.yml`, el árbol de `roles/` y
`roles/nginx/handlers/main.yml`.

**Decir:**

> El archivo site.yml organiza los cuatro roles y las comprobaciones
> generales.
> Common prepara y actualiza el sistema.
> Nodejs instala Node.js desde NodeSource y despliega la aplicación
> como un servicio systemd con un usuario sin privilegios.
> Nginx configura el reverse proxy y Certbot gestiona el certificado.
> La aplicación escucha en 127.0.0.1:3000 y recibe las peticiones
> que le reenvía Nginx.
> Los handlers permiten reaccionar a los cambios. En nuestra configuración,
> cuando corresponde recargar Nginx, primero se valida con nginx -t.
> Durante el despliegue, esa validación detectó una directiva incompatible
> y detuvo la ejecución antes de recargar.

**Ejecutar en WSL si se necesita mostrar la estructura:**

```bash
cat site.yml
find roles -maxdepth 2 -type d | sort
```

Se pueden mostrar estos archivos directamente en VS Code para ahorrar tiempo.

---

## 4. Servicio funcionando por HTTPS — 45 segundos

**Mostrar:** las respuestas en WSL y la aplicación en el navegador.

**Ejecutar:**

```bash
curl -I http://aws.jorgeveraoficial.com
curl -i https://aws.jorgeveraoficial.com
```

**Decir:**

> La petición a la raíz por HTTP devuelve un 301 y redirige a HTTPS.
> Por HTTPS obtenemos un 200 y el JSON de la aplicación.
> Curl valida el certificado sin utilizar opciones para omitir
> esa comprobación.
> Esto demuestra el recorrido de la petición: llega a Nginx mediante TLS
> y Nginx la reenvía al proceso Node.js que escucha en loopback.

**Mostrar después:**

```bash
curl --connect-timeout 5 --max-time 5 http://54.160.157.177:3000
```

**Decir si la conexión no se establece:**

> Desde este equipo no conseguimos acceder directamente al puerto 3000.
> Esta comprobación complementa la configuración mostrada:
> no hay una regla pública para ese puerto y la aplicación escucha
> únicamente en loopback.

El timeout es un resultado esperado en esta comprobación.
Por sí solo no identifica qué componente bloquea la conexión.

---

## 5. Idempotencia del playbook — 65 segundos

**Mostrar:** una nueva ejecución completa del playbook y su `PLAY RECAP`.

**Ejecutar en WSL:**

```bash
ansible-playbook site.yml
```

**Decir mientras se ejecuta:**

> El servidor ya está configurado. Ahora vuelvo a ejecutar el mismo playbook.
> Ansible evalúa las tareas y, en los módulos utilizados, comprueba
> si el estado deseado ya se cumple.
> Si se cumple, no necesita volver a modificar ese recurso.
> Esta propiedad permite repetir la automatización de forma controlada.

**Evidencia obtenida anteriormente:**

```text
ok=41   changed=0   unreachable=0   failed=0   skipped=8
```

**Decir si la nueva ejecución termina con `changed=0`:**

> Esta ejecución termina con cero cambios y sin errores.
> El servidor ya cumple el estado declarado por el playbook.

**Explicar las tareas omitidas:**

> Algunas tareas se omiten por sus condiciones, como solicitar
> un certificado que ya existe.
> Otras comprobaciones de Certbot y Nginx siguen ejecutándose:
> no se omite toda la configuración TLS.

### Nota para la grabación

Los contadores anteriores son evidencia de una ejecución concreta.
No tienen por qué repetirse exactamente.

Si aparecen cambios, revisar qué tareas los produjeron.
Por ejemplo, la publicación de nuevas actualizaciones de Ubuntu puede hacer
que el rol common actualice paquetes legítimamente.

No afirmar `changed=0` si la salida actual muestra otro resultado.

Acelerar en la edición los periodos de espera y detener la imagen en el
resumen final. Mantener la ejecución completa del playbook para demostrar
su comportamiento conjunto.

---

## 6. Renovación y persistencia tras reinicio — 45 segundos

**Mostrar:** las evidencias ya obtenidas del simulacro de renovación,
del reinicio y de los servicios después de arrancar.

No ejecutar otro reinicio durante la grabación.

**Decir:**

> El certificado tiene una vigencia limitada, por eso configuramos
> su renovación automática con certbot.timer.
> El simulacro de renovación terminó correctamente usando el entorno
> de pruebas de Let's Encrypt, sin sustituir el certificado de producción.
> También configuramos un hook para recargar Nginx después de una renovación.
> Además, reinicié la instancia con Ansible.
> Al volver, Nginx, la aplicación y el timer estaban activos y habilitados,
> y HTTPS seguía respondiendo 200 sin volver a aplicar el playbook.

**Evidencias obtenidas:**

```text
certbot renew --dry-run:
todas las renovaciones simuladas correctas

Reinicio mediante Ansible:
rebooted=true
elapsed=20

Tras el reinicio:
nginx         active / enabled
demoapp       active / enabled
certbot.timer active / enabled

HTTPS:
200 OK sin reaplicar el playbook
```

### Precisión sobre el simulacro

`--dry-run` puede solicitar certificados de prueba.
No significa que no haya comunicación ni emisión en el entorno de pruebas.

Los deploy hooks no se ejecutan por defecto durante el simulacro.
Por tanto, el resultado mostrado acredita la prueba de renovación,
pero no demuestra por sí solo que se haya ejecutado el hook de recarga.

La prueba de persistencia realizada fue un reinicio controlado.

---

## 7. Validaciones automáticas en GitLab — 50 segundos

**Mostrar:** el pipeline
[#3079](https://gitlab.codecrypto.academy/jverav573/1.4.30-ansible-aws/-/pipelines/3079)
y después `.gitlab-ci.yml`.

**Decir:**

> Además de las comprobaciones sobre el servidor, tenemos un pipeline
> de validación estática.
> El pipeline 3079 pasó para el commit 380b2404:
> el job de Ansible tardó 27 segundos y el de Terraform, 18.
> Comprueba YAML, sintaxis del playbook, reglas de ansible-lint,
> formato de Terraform y validez de su configuración.
> Utiliza el runner cloudrun con ejecutor shell.
> Por eso prepara un entorno virtual para Python y descarga una versión
> fijada de Terraform, comprobando su SHA-256.
> Este pipeline no necesita credenciales AWS para estas validaciones.
> No despliega recursos ni ejecuta el playbook contra la instancia.
> El resultado verde demuestra que pasaron las comprobaciones configuradas.
> La disponibilidad del servicio la hemos comprobado por separado.

**Resultados documentados:**

| Job | Estado | Duración |
|---|---|---|
| ansible:lint | Passed | 27 s |
| terraform:validate | Passed | 18 s |

Terraform se inicializa con:

```bash
terraform init -backend=false -input=false
```

Esto permite preparar los proveedores y módulos necesarios para validar
sin inicializar el backend del estado.

Si se muestra un pipeline posterior, identificar su propio número y commit.
Las cifras anteriores corresponden específicamente al pipeline #3079.

---

## 8. Incidencias y cierre — 35 segundos

**Mostrar:** la sección de incidencias del README.

**Decir:**

> Documenté los problemas encontrados y sus soluciones.
> Por ejemplo, Nginx rechazó la directiva http2 on porque la versión
> instalada no la admitía.
> La validación detuvo la recarga y permitió corregir la plantilla.
> En CI también tuvimos que adaptar la instalación de herramientas
> al ejecutor shell del runner.
> El resultado es una infraestructura declarada con Terraform,
> un servidor configurado con Ansible y evidencias de funcionamiento,
> idempotencia y validación automática.

**Ejecutar:** ningún comando.

---

## Reparto del tiempo

| Paso | Contenido | Duración |
|---|---|---|
| 1 | Objetivo y herramientas | 30 s |
| 2 | Infraestructura declarada | 40 s |
| 3 | Roles y handlers | 50 s |
| 4 | HTTP y HTTPS | 45 s |
| 5 | Idempotencia | 65 s |
| 6 | Renovación y reinicio | 45 s |
| 7 | Pipeline y alcance | 50 s |
| 8 | Incidencias y cierre | 35 s |
| | **Total del video editado** | **6 min** |

## Comprobación final antes de entregar

- [ ] Las letras y los comandos se leen claramente.
- [ ] No aparecen credenciales ni claves privadas.
- [ ] Se identifica la aplicación como una demo Node.js.
- [ ] Se distinguen las funciones de Terraform y Ansible en este proyecto.
- [ ] Se muestran el 301, la redirección y el 200 con el JSON.
- [ ] El comentario sobre idempotencia coincide con la salida mostrada.
- [ ] Las capturas anteriores se presentan como evidencias ya obtenidas.
- [ ] Se explica el alcance estático del CI.
- [ ] El número de pipeline y el commit coinciden con la pantalla.
- [ ] La duración final ronda los seis minutos.