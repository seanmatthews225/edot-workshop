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
export OTEL_EXPORTER_OTLP_ENDPOINT="http://<EXTERNAL-IP>:8200"
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer <your-secret-token>"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=workshop"
```

Start Java with the EDOT agent attached — the only difference from a normal Java startup is the `-javaagent` flag:

```bash
cd java-frontend
java -javaagent:elastic-otel-javaagent.jar -jar target/java-frontend-1.0.0.jar
```

Watch the startup output. You'll see the EDOT agent initialise before the Spring Boot banner — that's the agent attaching to the JVM and setting up instrumentation automatically. No code was changed.

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

Click around in the app, then open **Elastic → Observability → Service Map** in Kibana.

You'll see `java-frontend` appear. Click into a trace — every HTTP request the Java service handled is visible. But the calls it makes to Python show up as anonymous external spans. **Python is still a black box.**

Press `Ctrl+C` to close the tunnel, then stop all services:

```bash
./scripts/stop.sh
```

---

## Step 4 — Instrument Python manually

Now let's do the same for Python. Export the OTEL environment variables:

```bash
export OTEL_SERVICE_NAME=python-backend
export OTEL_EXPORTER_OTLP_ENDPOINT="http://<EXTERNAL-IP>:8200"
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer <your-secret-token>"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export OTEL_EXPORTER_OTLP_TRACES_PROTOCOL="http/protobuf"
export OTEL_EXPORTER_OTLP_LOGS_PROTOCOL="http/protobuf"
export OTEL_METRICS_EXPORTER=none
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=workshop"
```

Start Python with the OpenTelemetry wrapper — again, no code changes, just a different launch command:

```bash
cd python-backend
opentelemetry-instrument venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
```

Watch the startup output. You'll see the OpenTelemetry SDK initialise alongside Uvicorn — FastAPI, SQLAlchemy, and the database driver are all instrumented automatically via import hooks.

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
