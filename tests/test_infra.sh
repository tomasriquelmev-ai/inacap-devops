#!/bin/bash
set -e

echo "=== [TEST 1] Verificando formato y sintaxis de Terraform (RT-01, RT-04) ==="
cd infra
terraform fmt -check -recursive || { echo "Error: El codigo Terraform no cumple el formato estandar"; exit 1; }
terraform init -backend=false
terraform validate
echo "OK: Sintaxis y configuracion IaC validadas correctamente."

echo "=== [TEST 2] Verificando politicas de seguridad en el codigo (ES-02, ES-03) ==="
# 1. Verificar que no exista apertura del puerto 22 (SSH) en security.tf
if grep -q "from_port *= *22" security.tf; then
  echo "FALLO DE SEGURIDAD (ES-03): Se detecto puerto 22 (SSH) abierto en security.tf"
  exit 1
fi

# 2. Verificar que no existan claves AWS (AKIA...) expuestas en el codigo
if grep -rnE "AKIA[0-9A-Z]{16}" .; then
  echo "FALLO DE SEGURIDAD (ES-02): Se detecto una AWS Access Key hardcodeada"
  exit 1
fi

# 3. Verificar que el cifrado de DynamoDB y disco raiz EC2 este habilitado
grep -q "encrypted = true" main.tf || { echo "FALLO DE SEGURIDAD: Cifrado EBS no detectado"; exit 1; }
grep -q "http_tokens *= *\"required\"" main.tf || { echo "FALLO DE SEGURIDAD: IMDSv2 obligatorio no detectado"; exit 1; }

echo "OK: Todas las validaciones de seguridad estatica pasaron exitosamente."
