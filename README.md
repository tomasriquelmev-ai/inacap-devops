# inacap-devops
flowchart TB
    subgraph DevOps["Flujo DevOps & Automatización (RT-04)"]
        DEV["Equipo PeñaExpress<br/>(Git / GitHub)"] --> CB["AWS CodeBuild<br/>(Pruebas IaC, Seguridad y Healthcheck)"]
        CB -- "Despliega / Valida" --> VPC
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
