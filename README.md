# back-SGRA

## Docker Desktop

El `Dockerfile` compila el JAR con Maven y Java 21. La imagen final incluye
Java 21, fuentes para reportes y los clientes `pg_dump`, `pg_restore` y
`psql`. Compose usa PostgreSQL cliente 18 por defecto. Si tu entorno
requiere otra versión, define `SGRA_PG_MAJOR` al construir con Compose.
La zona horaria del contenedor es `America/Guayaquil` por defecto y se puede
ajustar con `TZ` para recordatorios y respaldos programados.

Para iniciar el backend, prepara la configuración de ejecución:

```powershell
Copy-Item .env.docker.example .env.docker
```

Completa `.env.docker` con valores del entorno autorizado. El perfil
`docker-local` carga estos valores en lugar de consultar Azure Key Vault.
Usa la misma clave maestra del entorno de destino si la base contiene datos
cifrados. Si PostgreSQL corre en Windows, usa `host.docker.internal` en la URL
JDBC. Si está en Azure o en otra máquina, usa su host y los parámetros TLS
del entorno.

Se requiere una base PostgreSQL ya inicializada con los esquemas, funciones,
tablas y roles de SGRA. Los adjuntos y respaldos en la nube requieren acceso
a Azure Blob Storage. Las funciones de IA requieren Groq y las
notificaciones usan el correo configurado en SGRA.

Para usar Key Vault directamente, omite `SPRING_PROFILES_ACTIVE=docker-local`
y configura `AZURE_TENANT_ID`, `AZURE_CLIENT_ID` y `AZURE_CLIENT_SECRET` para
una identidad de aplicación autorizada a leer el almacén. La sesión
interactiva de Azure CLI en Windows queda fuera del contenedor.

El `compose.yml` de esta raíz permite iniciar solo el backend:

```powershell
docker compose up --build -d
docker compose ps
```

La API queda disponible en `http://localhost:8080`. Usa
`SGRA_BACKEND_PORT` para cambiar el puerto local.

Para iniciar ambos servicios juntos, ejecuta el mismo comando desde
`SEG-INF-front-SGRA-Docker`. Usa una sola de las dos configuraciones para
evitar dos instancias del backend ejecutando tareas programadas sobre la
misma base de datos.

Para guardar una copia local de los respaldos desde el módulo de
administración, usa la ruta `/var/lib/sgra/backups`. Compose la monta en un
volumen persistente del proyecto en ejecución.

Backend del Sistema de Gestión de Refuerzos Académicos (SGRA), desarrollado con **Spring Boot 4** y **Java 21**.

---

## ⚙️ Requisitos previos

Antes de ejecutar el proyecto asegúrate de tener instalado:

| Herramienta | Versión mínima | Descarga |
|---|---|---|
| Java JDK | 21 | https://learn.microsoft.com/es-es/java/openjdk/download |
| Maven | 3.9+ | (incluido via `mvnw`) |
| Azure CLI | Última | https://aka.ms/installazurecliwindows |

---

## 🔑 Configuración de Azure CLI (obligatorio en desarrollo local)

Los secretos del proyecto (contraseña de BD, API keys, etc.) están almacenados en **Azure Key Vault** (`kv-sgra`). El proyecto usa `DefaultAzureCredential` que se autentica automáticamente según el entorno:

| Entorno | Autenticación | Requiere |
|---|---|---|
| **Desarrollo local** | Azure CLI | `az login` con tu cuenta |
| **Producción (Azure)** | Managed Identity | Activarla en el recurso de Azure — sin contraseñas ni CLI |

> En producción no se necesita ningún cambio en el código ni en `application.properties`. Azure se autentica solo a través de la Managed Identity del recurso donde corre la app.

**1. Instalar Azure CLI** (si no lo tienes):
```
winget install Microsoft.AzureCLI
```

**2. Iniciar sesión con tu cuenta institucional:**
```
az login
```
Se abrirá el navegador. Usa tu cuenta `@msuteq.edu.ec`.

**3. Verificar que tienes acceso al Key Vault:**
```
az keyvault secret list --vault-name kv-sgra --query "[].name" -o tsv
```
Debes ver listados los secretos (`sgra-master-key`, `spring-datasource-password`, etc.). Si ves un error de permisos, pide al administrador que te agregue al Key Vault.

---

## 🚀 Configuración del proyecto

**1. Clonar el repositorio y entrar al directorio:**
```
cd back-SGRA
```

**2. Ejecutar el proyecto:**
```
mvnw spring-boot:run
```
O directamente desde IntelliJ IDEA con el botón ▶️.

> El archivo `application.properties` ya viene en el repo. No necesitas configurar nada adicional — los secretos se cargan automáticamente desde Azure Key Vault usando tu sesión de Azure CLI.

---

## 🔐 Secretos en Azure Key Vault

El proyecto usa `spring-cloud-azure-starter-keyvault-secrets` para cargar los secretos automáticamente al arrancar. No necesitas copiar ningún valor manualmente.

| Nombre del secreto en Key Vault | Para qué se usa |
|---|---|
| `spring-datasource-password` | Contraseña de PostgreSQL |
| `sgra-master-key` | Llave maestra de encriptación interna |
| `groq-api-key` | API Key de Groq AI |
| `spring-cloud-azure-storage-blob-connection-string` | Connection string de Azure Blob Storage |

---

## 🛠️ Estructura principal

```
src/main/java/com/CLMTZ/Backend/
├── config/          # Configuraciones (CORS, Azure Storage, Groq, etc.)
├── controller/      # Endpoints REST
├── service/         # Lógica de negocio
├── repository/      # Acceso a datos (JPA + queries nativas)
├── model/           # Entidades JPA
└── dto/             # Objetos de transferencia de datos
```

---

## ❓ Problemas comunes

**WARNING: "A restricted method in java.lang.System has been called" (Netty)**
→ Es un warning inofensivo de Java 25 con Netty. Se suprime automáticamente con la Run Configuration incluida en el repo (`--enable-native-access=ALL-UNNAMED`). Si persiste, ve a IntelliJ → Run → Edit Configurations → VM options y agrega `--enable-native-access=ALL-UNNAMED`.

**"Could not resolve placeholder 'sgra-master-key'"**
→ No estás autenticado en Azure CLI. Ejecuta `az login`.

**"No qualifying bean of type BlobServiceClient"**
→ El secreto `spring-cloud-azure-storage-blob-connection-string` no se cargó del Key Vault. Verifica tu acceso con `az keyvault secret list --vault-name kv-sgra`.

**"Access denied" al Key Vault**
→ Tu cuenta no tiene permisos. Pide al administrador del proyecto que te asigne el rol `Key Vault Secrets User` en el recurso `kv-sgra`.
