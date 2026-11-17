# Informe Técnico: Implementación de Infraestructura como Código (IaC) y Gestión de Configuración en AWS — PeñaExpress SpA

**Institución:** INACAP  
**Asignatura:** Cloud Computing / DevOps  
**Integrantes del Equipo:**
* Tomas Riquelme

**Fecha:** Noviembre de 2026  
**Repositorio de Código:** https://github.com/tomasriquelmev-ai/inacap-devops  

---

## 1. Selección y Descripción del Caso

### 1.1 Contexto de la Organización
**PeñaExpress SpA** es una empresa logística dedicada a la distribución y despacho de paquetería urbana en la Región Metropolitana. Su operación diaria depende de una plataforma interna (backend API y portal operativo) utilizada por el personal de bodega y repartidores para registrar estados de envío, consultar disponibilidad de stock y coordinar rutas de entrega.

### 1.2 Necesidad Tecnológica y Problema a Resolver
El incremento en el volumen de pedidos evidenció que su infraestructura tradicional —aprovisionada de forma manual en servidores aislados— carecía de estandarización, trazabilidad y observabilidad. Ante picos de demanda o fallos operativos, el diagnóstico tomaba horas debido a la ausencia de registros centralizados y alertas tempranas.

Para resolver esta problemática, se implementó un **sistema de gestión de la configuración e Infraestructura como Código (IaC)** en **Amazon Web Services (AWS)** mediante **Terraform** y prácticas **DevOps**, asegurando:
1. Aprovisionamiento declarativo, versionado y reproducible.
2. Monitoreo proactivo y detección temprana de incidentes.
3. Validación automatizada de sintaxis, seguridad y configuración antes del despliegue.
4. Controles estrictos de identidad, acceso y auditoría.

---

## 2. Requerimientos del Proyecto y Estándares de Seguridad

### 2.1 Requerimientos Funcionales (RF)
* **RF-01 (Disponibilidad del servicio):** Exponer un punto de acceso HTTP operativo con un endpoint de verificación de salud (`/health`) para monitorear la disponibilidad de la API de pedidos.
* **RF-02 (Persistencia de datos):** Contar con almacenamiento estructurado gestionado (`Amazon DynamoDB`) con cifrado en reposo para el registro de pedidos e inventario.
* **RF-03 (Notificación ante incidentes):** Emitir alertas automáticas vía correo electrónico (`Amazon SNS`) al equipo de operaciones ante degradación de rendimiento o caída de servicios.

### 2.2 Requerimientos Técnicos (RT)
* **RT-01 (Aprovisionamiento 100% como código):** Declarar todos los recursos de red, cómputo, seguridad y monitoreo en archivos Terraform versionados en Git, prohibiendo cambios manuales en consola.
* **RT-02 (Observabilidad centralizada):** Recopilar métricas de rendimiento de infraestructura y registros de aplicación en `Amazon CloudWatch`.
* **RT-03 (Detección temprana):** Configurar alarmas con umbrales críticos (`CPUUtilization > 80%` y `StatusCheckFailed >= 1`).
* **RT-04 (Pruebas automatizadas en pipeline):** Integrar pruebas estáticas de sintaxis IaC, escaneo de seguridad y validación funcional en un flujo automatizado con `AWS CodeBuild`.

### 2.3 Estándares de Seguridad DevOps (ES)
* **ES-01 (Principio de Mínimo Privilegio):** Ningún servicio utilizará permisos administrativos globales; cada componente operará con roles IAM granulares limitados exclusivamente a sus recursos requeridos.
* **ES-02 (Cero credenciales expuestas):** Prohibición de almacenar contraseñas o llaves (`Access Keys`) en el código fuente, gestionando secretos de forma cifrada mediante `AWS Systems Manager Parameter Store` (KMS).
* **ES-03 (Restricción de acceso y perímetro):** Exponer únicamente el puerto HTTP (`80`) hacia Internet y bloquear el acceso directo por SSH (`puerto 22`), delegando la administración remota a `AWS SSM Session Manager`.
* **ES-04 (Trazabilidad y auditoría):** Registrar llamadas a la API de AWS mediante `AWS CloudTrail` hacia un bucket `Amazon S3` cifrado con bloqueo público total.

---

## 3. Diseño General de la Solución

La arquitectura fue diseñada de forma modular en la región `us-east-1`, separando las capas de red, cómputo, persistencia, seguridad, observabilidad y automatización:

```mermaid
flowchart TB
    subgraph DevOps["Flujo DevOps & Automatización (RT-04)"]
        DEV["Equipo PeñaExpress<br/>(Git / GitHub)"] --> CB["AWS CodeBuild<br/>(Pruebas IaC, Seguridad y Healthcheck)"]
        CB -- "Valida / Planifica" --> VPC
    end

    subgraph AWS["AWS Cloud (us-east-1) - Infraestructura como Código (RT-01)"]
        subgraph VPC["Amazon VPC (penaexpress-vpc) - ES-03"]
            subgraph PUB["Subred Pública"]
                SG_WEB["Security Group<br/>(Solo Puerto 80 HTTP)"] --> EC2["Amazon EC2<br/>(App Pedidos + CloudWatch Agent)"]
            end
        end

        EC2 -- "IAM Role Mínimo Privilegio (ES-01)" --> DDB[("Amazon DynamoDB<br/>(penaexpress-pedidos)")]
        EC2 -- "Lee Secretos Cifrados (ES-02)" --> SSM["SSM Parameter Store<br/>(KMS Encrypted)"]

        subgraph OBS["Observabilidad y Auditoría (RT-02, RT-03, ES-04)"]
            EC2 -- "Métricas y Logs" --> CW["Amazon CloudWatch<br/>(Logs + Alarma CPU > 80%)"]
            CW -- "Notificación Incidente (RF-03)" --> SNS["Amazon SNS<br/>(Alerta Email Operaciones)"]
            CT["AWS CloudTrail<br/>(Trazabilidad API)"] --> S3[("Amazon S3<br/>(Logs Auditoría Cifrados)")]
        end
    end

    USER["Operadores / Repartidores<br/>PeñaExpress"] -- "HTTP :80" --> SG_WEB


