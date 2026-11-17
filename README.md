# Sistema de Gestión de Configuración e Infraestructura como Código (IaC) — PeñaExpress SpA

**Institución:** INACAP  
**Asignatura:** Cloud Computing / DevOps  
**Integrantes del Equipo:** Tomas Riquelme
**Región AWS:** `us-east-1` (N. Virginia)  

---

## 1. Descripción del Caso
**PeñaExpress SpA** es una empresa dedicada a la distribución y despacho de paquetería urbana en la Región Metropolitana[cite: 4]. Ante el aumento sostenido de pedidos diarios, su infraestructura tradicional —configurada manualmente en servidores aislados— presentaba fallas de reproducibilidad, falta de visibilidad ante incidentes y demoras críticas en la recuperación ante caídas[cite: 4].

Para resolver esta problemática, se diseñó e implementó un sistema de gestión de la configuración en **Amazon Web Services (AWS)** mediante **Terraform** y prácticas **DevOps**, garantizando despliegues automatizados, monitoreo proactivo, validación continua y controles de seguridad alineados con estándares de la industria.

---

## 2. Requerimientos del Proyecto y Estándares de Seguridad

### Requerimientos Funcionales (RF)
* **RF-01 (Disponibilidad del servicio):** Exponer un servicio web/API operativo con un endpoint de salud (`/health`) para verificar la disponibilidad de la plataforma de pedidos[cite: 4].
* **RF-02 (Persistencia operacional):** Proveer una base de datos gestionada (`Amazon DynamoDB`) con cifrado en reposo para el registro de pedidos e inventario[cite: 4].
* **RF-03 (Notificación ante incidentes):** Alertar automáticamente al equipo de operaciones vía correo electrónico (`Amazon SNS`) ante fallos críticos o degradación del servidor[cite: 4, 5].

### Requerimientos Técnicos (RT)
* **RT-01 (Infraestructura como Código):** Declarar el 100% de los recursos de red, cómputo, seguridad y monitoreo en Terraform, eliminando cambios manuales en consola[cite: 4].
* **RT-02 (Observabilidad):** Recopilar métricas de rendimiento (CPU, estado de instancia) y centralizar registros de aplicación en `Amazon CloudWatch`[cite: 2, 3, 5].
* **RT-03 (Detección temprana):** Configurar alarmas con umbrales definidos (`CPUUtilization > 80%` y `StatusCheckFailed >= 1`).
* **RT-04 (Validación automatizada):** Integrar pruebas estáticas, de seguridad y funcionales en un flujo automatizado mediante `AWS CodeBuild`[cite: 2, 3, 5].

### Estándares de Seguridad DevOps (ES)
* **ES-01 (Mínimo Privilegio):** Uso de roles IAM granulares limitados exclusivamente a los recursos requeridos (sin `AdministratorAccess`)[cite: 3, 5, 9].
* **ES-02 (Protección de Credenciales):** Prohibición de secretos en código; gestión cifrada con KMS en `AWS Systems Manager Parameter Store`[cite: 3, 5, 9].
* **ES-03 (Restricción de Red):** Exposición exclusiva del puerto HTTP (80) y bloqueo total de SSH externo (`0.0.0.0/0:22`), utilizando `AWS SSM Session Manager` para administración remota.
* **ES-04 (Trazabilidad):** Registro inmutable de acciones API mediante `AWS CloudTrail` almacenado en un bucket `Amazon S3` privado y cifrado[cite: 2, 3, 5, 9].

---

## 3. Arquitectura de la Solución

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
