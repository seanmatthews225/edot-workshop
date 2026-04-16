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

## Before you start

You'll need an **Elastic Cloud deployment** with an APM endpoint and API key ready. Find these in Kibana under **Observability → Add data → APM → OpenTelemetry**.

Everything else (Java, Maven, Python, PostgreSQL) is installed automatically by the bootstrap script.

---

## Step 0 — Bootstrap (run once)

Installs all dependencies, builds the app, sets up the database, and downloads the EDOT agents:

```bash
./bootstrap.sh
```

When it finishes, open `.env.otel` and fill in your Elastic credentials:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT="https://your-apm-endpoint.cloud.es.io"
OTEL_EXPORTER_OTLP_HEADERS="Authorization=ApiKey your-api-key-here"
```

---

## Step 1 — Run the app (no instrumentation)

```bash
./start.sh
```

Open **http://localhost:8080**. Add and delete users. Everything works — but nothing is being observed. No services will appear in Elastic yet.

```bash
./stop.sh
```

---

## Step 2 — Instrument Java

```bash
./start-java-edot.sh
```

Generate some traffic in the browser, then open **Elastic → Observability → Service Map**.

You'll see `java-frontend` appear. Click into a trace — you can see every HTTP request the Java service handled. But the calls it makes to Python show up as anonymous external spans. **Python is still a black box.**

```bash
./stop.sh
```

---

## Step 3 — Instrument Python (complete the picture)

```bash
./start-full-edot.sh
```

Generate traffic again and go back to the Service Map.

Now both `java-frontend` and `python-backend` appear. Click into any trace and you'll see the full chain: **Java → Python → PostgreSQL**, with SQL queries visible as child spans — all sharing the same trace ID, all with zero changes to the application code.

```bash
./stop.sh
```

---

## Watching logs

All output is written to the `logs/` directory while services run in the background:

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

**401 from the OTLP endpoint** — your API key is wrong or lacks APM permissions. Regenerate it in Kibana with Editor privileges.

**No traces appearing** — wait 30–60 seconds after generating traffic, then check `tail -f logs/java.log` for connection errors and verify your `.env.otel` values are correct.

---

## How it works

EDOT instruments your application at the process level — no source code changes required.

- **Java**: the EDOT agent attaches to the JVM via `-javaagent` and intercepts Spring Boot, HTTP clients, and more automatically.
- **Python**: `opentelemetry-instrument` wraps your process and instruments FastAPI, SQLAlchemy, and other libraries via import hooks.

When Java calls Python over HTTP, it automatically injects a `traceparent` header (W3C Trace Context standard). Once Python is instrumented, it reads that header and continues the same trace — which is why the trace ID matches across both services.
