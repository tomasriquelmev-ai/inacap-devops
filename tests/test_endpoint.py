import os
import sys
import json
import urllib.request
import urllib.error

def test_health_endpoint():
    base_url = os.environ.get("APP_URL")
    if not base_url:
        print("ERROR: La variable de entorno APP_URL no esta definida.")
        sys.exit(1)

    health_url = f"{base_url.rstrip('/')}/health"
    print(f"=== [TEST 3] Ejecutando prueba funcional sobre {health_url} (RF-01, RT-04) ===")

    try:
        with urllib.request.urlopen(health_url, timeout=10) as response:
            status_code = response.getcode()
            body = response.read().decode("utf-8")
            data = json.loads(body)

            assert status_code == 200, f"Se esperaba HTTP 200, se obtuvo {status_code}"
            assert data.get("status") == "ok", f"Estado inesperado: {data}"
            assert data.get("service") == "PenaExpress API", f"Servicio inesperado: {data}"

            print(f"OK: Servicio operativo. HTTP {status_code} | Respuesta: {data}")
    except Exception as e:
        print(f"FALLO EN PRUEBA FUNCIONAL: {e}")
        sys.exit(1)

if __name__ == "__main__":
    test_health_endpoint()
