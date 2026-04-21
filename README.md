# EDOT Workshop

Add production observability to a running application with **zero code changes**, using the Elastic Distribution of OpenTelemetry (EDOT).

---

## What you'll build

A simple three-tier app — Java frontend, Python backend, PostgreSQL — that you instrument step by step. After each step you'll see something new appear in Elastic Observability, until you have a full distributed trace spanning every service.

```
Browser → Java Frontend (8080) → Python Backend (8000) → PostgreSQL
                ↓                         ↓
              EDOT                       EDOT
                ↘                         ↙
              Elastic Observability
```

---

## Step 0 — Bootstrap (run once)

Installs all dependencies, builds the app, sets up the database, and downloads the EDOT agents:

```bash
git clone https://github.com/seanmatthews225/edot-workshop.git
cd edot-workshop
./bootstrap.sh
```

* The `bootstrap.sh` should take approximately 3 Minutes and 45 Seconds to complete (On a good day ;) ) 

When it finishes, get your APM secret token from your lab credentials file:

```bash
cat ~/env.yaml
```

You'll also need the external IP of your APM Server. Run:

```bash
kubectl get service apm-lb
```

Copy the value from the `EXTERNAL-IP` column.

Now open `.env.otel` and fill in both values:

```bash
nano .env.otel
```

```bash
OTEL_EXPORTER_OTLP_ENDPOINT="http://<EXTERNAL-IP>:8200"
OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer <your-secret-token>"
OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
```
---

## Step 1 — Run the app with no instrumentation

Start both services in the background:

```bash
./scripts/start.sh
```

Open a public tunnel to access the app from your browser:

```bash
./scripts/tunnel.sh
```

The tunnel will print a **password** (the VM's public IP) and a public URL. Open the URL and enter the password when prompted. Add and delete users — everything works, but nothing is being observed. No services appear in Elastic yet.

Press `Ctrl+C` to close the tunnel, then stop the services:

```bash
./scripts/stop.sh
```

---

## Step 2 — Instrument Java manually

Before using the scripts, let's see exactly what zero-code Java instrumentation looks like. This step runs the Java app by hand so you can see the EDOT agent command.

Export the OTEL environment variables (replace the placeholders with your values from Step 0):

```bash
export OTEL_SERVICE_NAME=java-frontend
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://<EXTERNAL-IP>:8200"
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer <your-secret-token>"
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=workshop"
```

Start Java with the EDOT agent attached — the only difference from a normal Java startup is the `-javaagent` flag:

```bash
cd java-frontend
java -javaagent:elastic-otel-javaagent.jar -jar target/java-frontend-1.0.0.jar
```

Watch the startup output. You'll see the EDOT agent initialise before the Spring Boot banner — that's the agent attaching to the JVM and setting up instrumentation automatically. No code was changed.

Check in the Kibana UI -> Service Inventory, you should see the `java-frontend` appear in the UI:
<img width="1422" height="885" alt="Screenshot 2026-04-21 at 4 05 28 PM" src="https://github.com/user-attachments/assets/4af2cdb1-0723-4f13-be7c-f48de0275e0b" />

Press `Ctrl+C` to stop Java, then return to the repo root:

```bash
cd ..
```

---

## Step 3 — Run Java instrumented via script + view in Elastic

Now run the same thing using the helper script, which starts both services in the background and reads credentials from `.env.otel`:

```bash
./scripts/start-java-edot.sh
```

Open the tunnel to generate traffic:

```bash
./scripts/tunnel.sh
```

In the application UI, go ahead and add a user that already exists, the UI shall just refresh.
- Did the user get added? Who knows?

Navigate into Kibana, then open **Elastic → Observability → Service Inventory** in Kibana.

You'll see `java-frontend` appear. Click into the `java-frontend`:
1. Take a look at the `Service Map` in the `java-frontend`, does the `python-backend` show up? If not, why is that?
3. Take a look into the `Transactions` for the `POST /users` endpoint
4. Your latest trace should show at the bottom of the UI, displaying a `failure`, why is this?
- Leverage the `Investigate` to view the `Trace Logs` to see why

Expected Output:
<img width="2245" height="401" alt="Screenshot 2026-04-21 at 4 28 55 PM" src="https://github.com/user-attachments/assets/66148d19-21ee-4723-ac6b-091d3ab102b7" />
<img width="2273" height="1003" alt="Screenshot 2026-04-21 at 4 20 49 PM" src="https://github.com/user-attachments/assets/a9f4bfbc-62da-46cd-81b7-bcaf6c32b962" />

Press `Ctrl+C` to close the tunnel, then stop all services:

```bash
./scripts/stop.sh
```

---

## Step 4 — Instrument Python manually

Now let's do the same for Python. Export the OTEL environment variables:

```bash
export OTEL_SERVICE_NAME=python-backend
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export OTEL_EXPORTER_OTLP_TRACES_PROTOCOL="http/protobuf"
export OTEL_EXPORTER_OTLP_LOGS_PROTOCOL="http/protobuf"
export OTEL_METRICS_EXPORTER=none
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=workshop"
```

Start Python with the OpenTelemetry wrapper — again, no code changes, just a different launch command:

```bash
cd python-backend
venv/bin/opentelemetry-instrument venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
```

Watch the startup output. You'll see the OpenTelemetry SDK initialise alongside Uvicorn — FastAPI, SQLAlchemy, and the database driver are all instrumented automatically via import hooks.

The `python-backend` shall now show up in the **Service Inventory** within Kibana, however, the `java-frontend` shall stop reporting telemetry as the service is stopped, we should start both service up!

Press `Ctrl+C` to stop Python, then return to the repo root:

```bash
cd ..
```

---

## Step 5 — Run everything with scripts (full instrumentation)

You've now seen how to instrument both services manually. Step 5 runs both together cleanly in the background:

```bash
./scripts/start-full-edot.sh
```

Open the tunnel:

```bash
./scripts/tunnel.sh
```

Generate traffic and go back to the Service Map. Click into any trace and you'll see the complete picture: **Java → Python → PostgreSQL**, with SQL queries visible as child spans — all sharing the same trace ID, with zero changes to application code.
<img width="2258" height="1030" alt="Screenshot 2026-04-21 at 4 28 34 PM" src="https://github.com/user-attachments/assets/82bd4144-6dcb-40fd-a944-af1d40242651" />


Lets add the same user we tried to add earlier, how different do the Trace and Service Map look now?
- Take a look into the `Transactions` for the `POST /users` endpoint
<img width="2242" height="830" alt="Screenshot 2026-04-21 at 4 28 23 PM" src="https://github.com/user-attachments/assets/95485366-6f60-4d4c-a454-3a4d7a07b9a3" />

Press `Ctrl+C` to close the tunnel, then stop all services:

```bash
./scripts/stop.sh
```

---

## Watching logs

```bash
tail -f logs/*.log       # both services
tail -f logs/java.log    # Java only
tail -f logs/python.log  # Python only
```

---

## Troubleshooting

**Port already in use**
```bash
lsof -i :8080    # or :8000
kill -9 <PID>
```

**PostgreSQL not running**
```bash
sudo systemctl start postgresql
```

**401 from the OTLP endpoint** — your secret token is wrong or missing. Double-check the value in `.env.otel` against `~/env.yaml`.

**No traces appearing** — wait 30–60 seconds after generating traffic. Check `tail -f logs/java.log` for connection errors and verify your endpoint and token are correct.

---

## How it works

EDOT instruments your application at the process level — no source code changes required.

- **Java**: the EDOT agent attaches to the JVM via `-javaagent` and intercepts Spring Boot, HTTP clients, and more automatically.
- **Python**: `opentelemetry-instrument` wraps your process and instruments FastAPI, SQLAlchemy, and other libraries via import hooks.

When Java calls Python over HTTP, it automatically injects a `traceparent` header (W3C Trace Context standard). Once Python is instrumented, it reads that header and continues the same trace — which is why the trace ID matches across both services.
