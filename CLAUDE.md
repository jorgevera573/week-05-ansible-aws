# Semana 05 — Ansible AWS

## Objetivo y fuente de requisitos

Lee el README.md original antes de implementar. La entrega consiste en automatizar con Ansible la configuración de una EC2 Ubuntu: actualización de paquetes, Nginx como reverse proxy hacia Node.js en el puerto 3000, Node.js LTS mediante NodeSource, Certbot con plugin Nginx y renovación automática de TLS de Let's Encrypt. Conserva el enunciado original del README y añade después la documentación de la implementación.

Terraform prepara la infraestructura. Ansible configura el sistema operativo y los servicios. Claude Code ayuda a implementar; no reemplaza las verificaciones reales.

## Entorno confirmado

- Repositorio: https://gitlab.codecrypto.academy/jverav573/1.4.30-ansible-aws.git
- Carpeta Windows: C:/MASTER-ING-SOFTWARE/semana-05/1.4.30-ansible-aws
- Carpeta WSL: /mnt/c/MASTER-ING-SOFTWARE/semana-05/1.4.30-ansible-aws
- Terraform 1.16.3 instalado en Windows; ejecutar Terraform desde PowerShell.
- AWS CLI instalado y autenticado en Windows con el perfil master-semana05.
- Región: us-east-1. Verificar identidad mediante STS antes de planificar.
- No copiar el número de cuenta de una conversación: obtenerlo mediante STS y usar allowed_account_ids en el provider.
- Ubuntu WSL 2, usuario atsperu, Ansible core 2.21.4 con Python 3.14.4 mediante pipx.
- Ejecutable Ansible: /home/atsperu/.local/bin/ansible.
- Clave pública accesible desde Windows: //wsl.localhost/Ubuntu/home/atsperu/.ssh/master-semana05.pub
- Clave privada SSH únicamente en WSL: /home/atsperu/.ssh/master-semana05.
- Subdominio confirmado: aws.jorgeveraoficial.com.
- DNS administrado en GoDaddy. Registro A creado y verificado: aws.jorgeveraoficial.com resuelve a 54.160.157.177 mediante el resolutor 1.1.1.1. No existen registros AAAA, lo que es correcto porque la EC2 no tiene IPv6 pública.
- Correo confirmado para Let's Encrypt: jverav573@gmail.com.

## Infraestructura ya desplegada (fase 1 completada)

- Terraform aplicado desde `infra/` con estado local. Recursos en la cuenta 336846061737, región us-east-1, etiquetados Project=master-semana05 y ManagedBy=Terraform.
- EC2 Ubuntu Server 24.04 LTS x86_64, tipo t3.micro, disco raíz gp3 de 12 GiB cifrado, IMDSv2 obligatorio.
- Elastic IP asociada: 54.160.157.177. Es la IPv4 estable a la que apunta el registro A.
- Usuario SSH remoto: ubuntu.
- Clave privada SSH únicamente en WSL: /home/atsperu/.ssh/master-semana05. La clave tiene passphrase.
- El alumno mantiene la clave cargada en un ssh-agent dentro de una terminal WSL abierta. Los procesos lanzados por herramientas externas no heredan ese agente: el playbook lo ejecuta el alumno desde su propia terminal.
- Conectividad ya comprobada: `ansible all -m ping` responde SUCCESS con pong.
- Security group: SSH 22 solo desde la IPv4 pública del alumno /32; HTTP 80 y HTTPS 443 públicos; el puerto 3000 no está expuesto.

## Estado de la entrega

- Fase 2 completada: playbook aplicado contra la EC2. Servicio operativo en https://aws.jorgeveraoficial.com con HTTP 301 hacia HTTPS y HTTPS 200.
- Idempotencia verificada por el alumno en la segunda ejecución: ok=41, changed=0, unreachable=0, failed=0, skipped=8.
- Renovación automática comprobada con certbot renew --dry-run y persistencia comprobada tras reinicio mediante Ansible.
- CI de GitLab operativo. Pipeline #3079 en verde sobre el commit 380b2404: ansible:lint 27 s y terraform:validate 18 s. URL: https://gitlab.codecrypto.academy/jverav573/1.4.30-ansible-aws/-/pipelines/3079
- El runner del proyecto tiene la etiqueta cloudrun y ejecutor shell. El ejecutor shell no interpreta image:, de modo que cada job instala sus propias herramientas: ansible:lint crea un entorno virtual de Python en un directorio temporal y terraform:validate descarga Terraform 1.16.3 en otro temporal verificando el SHA-256 publicado. No usar image: en este pipeline.
- El pipeline valida solo código estático: no recibe credenciales AWS, no accede al estado de Terraform, no ejecuta apply ni destroy y no se conecta por SSH a la EC2.
- Guion del vídeo demo en docs/guion-demo.md.

## Alcance y protección del entorno existente

- La cuenta AWS también aloja ALINA. Crear recursos nuevos de esta práctica, identificados con Project=master-semana05 y ManagedBy=Terraform.
- No importar, modificar ni eliminar recursos existentes de ALINA, usuarios IAM, políticas, claves o perfiles default/wasabi.
- El permiso AmazonEC2FullAccess no aísla recursos por proyecto. El alcance del código y del plan debe limitarse a esta práctica.
- No usar credenciales incrustadas ni leer/imprimir claves privadas o secretos AWS. Usar el perfil configurado.
- No cambiar la web principal, sus registros DNS ni los servidores de nombres del dominio.
- No publicar, hacer push ni ejecutar terraform destroy como parte de la generación inicial.
- Las operaciones que creen recursos se realizarán en una fase posterior a la revisión del plan. La primera fase termina en plan; no ejecutar apply en ella.

## Primera fase: infraestructura Terraform

Implementar en infra/:
- versions.tf, providers.tf, main.tf, variables.tf, outputs.tf y terraform.tfvars.example.
- Terraform state local independiente en infra/, excluido de Git, con instrucciones para conservarlo.
- Fijar una versión estable compatible del provider AWS y conservar .terraform.lock.hcl en Git.
- Crear una VPC propia, una subred pública, Internet Gateway, tabla de rutas y asociación.
- Crear una EC2 Ubuntu Server 24.04 LTS x86_64 con AMI oficial de Canonical, obtenida mediante consulta EC2 filtrada por propietario y nombre. Registrar la AMI elegida para reproducibilidad; no inventar identificadores ni depender de SSM sin permisos.
- Tipo de instancia parametrizado, inicialmente t3.micro, disco raíz gp3 de 12 GiB cifrado, IMDSv2 obligatorio. No afirmar que sea gratuito.
- Usar volumen raíz eliminado al terminar la instancia. No crear NAT Gateway, balanceadores ni recursos ajenos al ejercicio.
- Importar solo la clave pública existente como un nuevo EC2 key pair. No generar una clave privada con Terraform.
- Crear security group: SSH TCP 22 solo desde la IPv4 pública actual del alumno /32; HTTP 80 y HTTPS 443 públicos. No publicar 3000.
- Obtener la IP pública con un servicio HTTPS de consulta de IP y validar IPv4; si no se puede obtener, pedirla. No usar 0.0.0.0/0 como fallback para SSH.
- Usar una Elastic IP asociada a la EC2 para mantener estable el DNS; informar que instancia, disco e IPv4 pública pueden generar cargos, incluso la IP retenida con la instancia parada.
- Outputs: instance_id, public_ip, public_dns si está disponible, usuario ubuntu y comando SSH para WSL.
- Parametrizar perfil, región, cuenta permitida, ruta pública SSH, CIDR SSH, AMI/tipo y etiquetas. Los valores específicos del equipo van en terraform.tfvars local ignorado por Git.

Ejecutar en Windows desde infra/: terraform fmt -check, terraform init, terraform validate y terraform plan -out=tfplan. Ejecutar terraform fmt primero si hace falta formatear. El plan debe mostrar solamente recursos nuevos propios y cero modificaciones o destrucciones existentes.

Entregar el listado de archivos, recursos previstos, AMI, instancia, acceso SSH, exposición de puertos, costes posibles y resultados reales de los comandos. Si hay un error, reportarlo; no declarar validación exitosa sin evidencia. No ejecutar apply en esta fase.

## Segunda fase: Ansible (EC2 creada y SSH comprobado)

Respetar la estructura del README en la raíz:
- site.yml
- ansible.cfg
- inventory/hosts.yml
- group_vars/all.yml
- roles/common, roles/nginx, roles/nodejs y roles/certbot con tareas, plantillas y handlers según corresponda.

Ejecutar Ansible en Ubuntu WSL. No asumir que AWS CLI, Terraform o el perfil de Windows existen también en Linux. Ansible accederá a EC2 por SSH y no necesita credenciales AWS.

Usar explícitamente ANSIBLE_CONFIG con la ruta absoluta del proyecto cuando se ejecute desde /mnt/c, pues los permisos de ese montaje pueden impedir la carga automática de ansible.cfg. Mantener las claves en el filesystem Linux con permisos restrictivos. No desactivar globalmente la verificación de host SSH; comprobar la huella por un canal AWS autenticado en la primera conexión.

- Usuario remoto ubuntu, become para las tareas administrativas.
- Preferir módulos nativos con nombres completos, templates y handlers; evitar shell para acciones con módulo disponible.
- common: actualizar caché y paquetes con política de reinicio documentada, sin reinicio inesperado.
- nodejs: fijar una rama LTS soportada y configurar NodeSource con repositorio y keyring. No ejecutar scripts remotos mediante curl | bash.
- Añadir una aplicación Node.js mínima de demostración, documentada como apoyo a la verificación; escuchar únicamente en 127.0.0.1:3000, usuario sin privilegios y servicio systemd persistente.
- nginx: validar configuración antes de recargar. Arranque HTTP válido antes de emitir el certificado; no referenciar certificados inexistentes.
- certbot: emitir certificado no interactivamente cuando DNS A resuelva a la Elastic IP y HTTP sea accesible. Revisar también registros AAAA incompatibles. Parametrizar dominio y correo; no inventarlos.
- Estrategia TLS adoptada: `certbot certonly --nginx`. El plugin de Nginx actúa solo como autenticador del challenge y no modifica la configuración del servidor web. La plantilla del rol nginx es la única fuente de verdad del vhost y renderiza el bloque HTTPS en cuanto existe el fullchain del dominio.
- Mantener una única estrategia coherente de configuración TLS: evitar que una plantilla de Ansible borre los cambios de Certbot en la siguiente ejecución.
- Configurar HTTPS, redirección HTTP y renovación automática mediante timer, con recarga de Nginx cuando corresponda. Evitar timers/cron duplicados y reemisiones innecesarias.
- No se exige Next.js ni despliegue automático de aplicación con GitHub Actions en este README.

## Calidad y entrega

- .gitignore: excluir .terraform/, estados y backups, planes guardados, terraform.tfvars local, secretos, claves privadas, archivos .env y caches. Mantener .terraform.lock.hcl y ejemplos sin secretos.
- Terraform: fmt y validate; Ansible: syntax-check, ansible-lint y yamllint con versiones compatibles fijadas.
- Añadir CI de validación en GitLab, sin credenciales cloud ni apply automático; reemplazar la dependencia de Auto DevOps con un pipeline específico.
- Verificar ansible all -m ping, primera ejecución y segunda ejecución. La segunda no debe producir cambios injustificados; explicar cambios legítimos externos, como actualizaciones disponibles.
- Verificar respuesta de la app a través de HTTPS, redirección HTTP, certificado, servicios activos y persistentes, timer y certbot renew --dry-run.
- Documentar comandos diferenciados PowerShell/WSL, requisitos DNS, variables, pruebas, incidencias y costes/limpieza del laboratorio.
- Preparar evidencia para una demo que explique Terraform, Ansible, roles, handlers, idempotencia y HTTPS.
- Documentar terraform destroy como limpieza futura únicamente del estado de esta práctica, incluyendo revisión previa y tratamiento del DNS. No ejecutarlo automáticamente.

## Forma de trabajar

Explica cada etapa brevemente en español. Avanza con lecturas, edición y validación local; pregunta solo por datos imprescindibles faltantes. La falta del proveedor DNS o del correo TLS no bloquea la fase Terraform. Distingue siempre archivos generados, validaciones ejecutadas y recursos realmente desplegados.
