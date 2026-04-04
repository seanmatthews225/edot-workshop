# EDOT Workshop: Observing a Multi-Service Application

Welcome to the Elastic Distribution of OpenTelemetry (EDOT) workshop! This hands-on lab demonstrates how to add production-grade observability to a distributed application with **zero code changes** using EDOT's auto-instrumentation capabilities.

## What You'll Learn

This workshop walks you through three stages of observability:

1. **Uninstrumented Application** — A working three-tier app with no observability
2. **Single-Service Instrumentation** — Add EDOT Java agent, see Java traces in Elastic
3. **Full Distributed Tracing** — Add EDOT Python instrumentation, watch traces flow end-to-end

By the end, you'll understand:
- How EDOT auto-instruments code without invasive changes
- How distributed trace context (W3C traceparent) propagates across services
- How to correlate logs, metrics, and traces in Elastic Observability
- How to debug multi-service request flows using observability data

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Elastic Observability                    │
│                  (APM, Metrics, Logs)                       │
└────────────────┬──────────────────────┬──────────────────────┘
                 │                      │
        ╔════════▼════════╗    ╔════════▼════════╗
        ║  EDOT Java      ║    ║  EDOT Python    ║
        ║  Agent          ║    ║  Bootstrap      ║
        ╚════════▲════════╝    ╚════════▲════════╝
                 │                      │
        ╔════════▼══════════════════════▼════════╗
        │                                        │
    ┌───▼────┐         ┌──────────┐       ┌──────▼────┐
    │ Browser│────────▶│  Java    │──────▶│  Python   │
    │        │         │Frontend  │       │ Backend   │
    │        │◀────────│(8080)    │◀──────│ (8000)    │
    └────────┘         └──────────┘       └──────┬────┘
                                                  │
                                          ┌───────▼────────┐
                                          │  PostgreSQL    │
                                          │  Database      │
                                          └────────────────┘
```

## Tech Stack

| Component | Technology | Version | Role |
|-----------|-----------|---------|------|
| Frontend | Spring Boot | 3.2.4 | HTTP server, REST client |
| Backend | FastAPI | 0.115.0 | REST API, database access |
| Database | PostgreSQL | 12+ | Persistent data store |
| Observability | EDOT | Java 1.10.0, Python 1.11.0 | Distributed tracing |

All components run on a single Linux VM with no Docker or Kubernetes required.

## Quick Start

### 1. Prerequisites (5 minutes)

Ensure all required tools are installed:

```bash
java -version          # Java 17+
mvn --version          # Maven 3.8+
python3 --version      # Python 3.9+
psql --version         # PostgreSQL 12+
```

For detailed setup instructions, see [docs/00-prerequisites.md](docs/00-prerequisites.md).

### 2. Database Setup (5 minutes)

Initialize PostgreSQL with the workshop schema:

```bash
cd edot-workshop
sudo systemctl start postgresql
psql -U workshopuser -d workshopdb -h localhost -f database/init.sql
```

See [docs/01-database-setup.md](docs/01-database-setup.md) for step-by-step guidance.

### 3. Run Uninstrumented (10 minutes)

Start both services without any observability:

**Terminal 1 — Python Backend:**
```bash
cd python-backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
./scripts/run.sh
```

**Terminal 2 — Java Frontend:**
```bash
cd java-frontend
./scripts/build.sh
./scripts/run.sh
```

Open http://localhost:8080 in your browser. Add and delete users. Everything works, but no traces are sent to Elastic.

See [docs/02-run-the-app.md](docs/02-run-the-app.md) for troubleshooting.

### 4. Instrument Java (15 minutes)

Set up Elastic Cloud credentials and run the Java frontend with EDOT:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="https://your-apm-endpoint.cloud.es.io"
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=ApiKey your-api-key"

cd java-frontend
./scripts/run-with-edot.sh
```

Generate traffic, then view traces in Elastic Observability → Applications → Traces.

See [docs/03-instrument-java.md](docs/03-instrument-java.md) for detailed steps.

### 5. Instrument Python (15 minutes)

Add EDOT to the Python backend to complete distributed tracing:

```bash
cd python-backend
pip install elastic-opentelemetry
edot-bootstrap --action=install

# Use the same credentials as Java
export OTEL_EXPORTER_OTLP_ENDPOINT="https://your-apm-endpoint.cloud.es.io"
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=ApiKey your-api-key"

./scripts/run-with-edot.sh
```

Generate traffic. Now view complete distributed traces spanning Java → Python → PostgreSQL.

See [docs/04-instrument-python.md](docs/04-instrument-python.md) for full details and troubleshooting.

## Workshop Steps

### Stage 1: Baseline (No Observability)
- Application runs and works correctly
- No traces sent to Elastic
- No visibility into request flow
- **Duration**: 10 minutes

### Stage 2: Java Instrumentation
- EDOT Java agent auto-instruments Spring Boot
- HTTP requests and response times visible in Elastic
- Calls to Python backend show as external requests (no detail yet)
- **Duration**: 15 minutes
- **Key insight**: You can see Java traces, but the Python backend remains a black box

### Stage 3: Distributed Tracing (Complete)
- EDOT Python instrumentation captures backend operations
- Traces automatically correlate across Java and Python (same trace ID)
- Database queries visible as child spans under Python handlers
- Full end-to-end visibility in Service Map
- **Duration**: 15 minutes
- **Key insight**: The trace context propagates via W3C traceparent headers — no code changes needed

## File Structure

```
edot-workshop/
├── README.md                      # This file
├── database/
│   └── init.sql                   # PostgreSQL schema and seed data
├── java-frontend/
│   ├── pom.xml                    # Maven build configuration
│   ├── src/main/java/com/elastic/workshop/
│   │   ├── Application.java       # Spring Boot entry point
│   │   ├── controller/
│   │   │   └── UserController.java
│   │   ├── model/
│   │   │   └── User.java
│   │   └── service/
│   │       └── UserService.java
│   ├── src/main/resources/
│   │   ├── application.properties
│   │   └── templates/
│   │       └── index.html         # UI template
│   └── scripts/
│       ├── build.sh
│       ├── run.sh
│       └── run-with-edot.sh       # EDOT launcher
├── python-backend/
│   ├── main.py                    # FastAPI application
│   ├── models.py                  # SQLAlchemy ORM models
│   ├── database.py                # Database connection
│   ├── requirements.txt
│   └── scripts/
│       ├── run.sh
│       └── run-with-edot.sh       # EDOT launcher
└── docs/
    ├── 00-prerequisites.md        # System setup
    ├── 01-database-setup.md       # PostgreSQL initialization
    ├── 02-run-the-app.md          # Running uninstrumented
    ├── 03-instrument-java.md      # Adding Java EDOT
    └── 04-instrument-python.md    # Adding Python EDOT + complete tracing
```

## Key Concepts

### Zero-Code Instrumentation

EDOT instruments applications without modifying source code:

- **Java**: EDOT Java agent (javaagent) is attached at JVM startup via `-javaagent:path/to/agent.jar`
- **Python**: EDOT is bootstrapped as an import hook that intercepts library calls

No changes to `Application.java`, `main.py`, or any business logic are required.

### Distributed Trace Context

When Java calls Python, it includes a W3C `traceparent` header:

```
traceparent: 00-4bf92f3577b7813f0ad8030b37c518d1-d7d17eb23427f294-01
                  └─────────────────────────────┬─────────────────────┘
                                          trace ID
```

The Python EDOT instrumentation receives this header and continues the trace with the same ID, creating a unified trace across services.

### Service Map Visualization

Elastic automatically builds a service map showing:
- Nodes: Java Frontend, Python Backend, PostgreSQL
- Edges: Request flow and latency
- Metrics: Request rate, error rate, latency percentiles

## Elastic Cloud Setup

For this workshop, use Elastic Cloud (easiest) rather than self-managed:

1. **Sign up**: https://www.elastic.co/cloud (free trial available)
2. **Create deployment**: Default settings work fine
3. **Find APM endpoint**: Kibana → Observability → APM (copy endpoint)
4. **Generate API key**: Kibana → Stack Management → API Keys
5. **Export credentials**:
   ```bash
   export OTEL_EXPORTER_OTLP_ENDPOINT="https://..."
   export OTEL_EXPORTER_OTLP_HEADERS="Authorization=ApiKey ..."
   ```

See [docs/03-instrument-java.md#step-1](docs/03-instrument-java.md#step-1-get-your-elastic-cloud-credentials) for detailed screenshots.

## Troubleshooting

### "Port 8080 already in use"
```bash
lsof -i :8080
kill -9 <PID>
```

### "psycopg2 connection refused"
```bash
sudo systemctl status postgresql
sudo systemctl start postgresql
```

### "OTLP endpoint rejected (401)"
API key is invalid or missing APM permissions. Regenerate it in Kibana with "Editor" privilege.

### "No traces appearing in Elastic"
- Wait 30-60 seconds (first trace might take time)
- Verify API key has APM permissions
- Check environment variables are set: `echo $OTEL_EXPORTER_OTLP_ENDPOINT`
- Look for errors in service terminal output

## Advanced Topics (Beyond Workshop Scope)

Once you complete the workshop, explore:

- **Custom instrumentation**: Add your own spans and metrics
- **Sampling**: Configure trace sampling for high-volume applications
- **Log correlation**: Inject trace IDs into application logs
- **Alerting**: Set up alerts on error rates and latency
- **Service topology**: Infer database types, client libraries, etc. from traces
- **Security**: Redact sensitive data from traces

## Additional Resources

- **EDOT Documentation**: https://github.com/elastic/elastic-otel-java
- **OpenTelemetry Spec**: https://opentelemetry.io/docs/specs/otel/
- **W3C Trace Context**: https://w3c.github.io/trace-context/
- **Elastic Observability Docs**: https://www.elastic.co/guide/en/observability/current/

## Workshop Completion

You've successfully completed the EDOT workshop when:

1. Java frontend runs and serves the UI at http://localhost:8080
2. Python backend serves the API at http://localhost:8000
3. PostgreSQL has user data stored and queryable
4. Java service appears in Elastic Observability with traces
5. Python service appears in Elastic Observability with traces
6. A single user interaction produces a distributed trace visible in Kibana spanning both services
7. The Service Map shows all three components and their relationships

**Congratulations!** You now understand how EDOT delivers production observability with zero code changes.

---

**Duration**: 60 minutes total (5+5+10+15+15+15)
**Difficulty**: Intermediate (basic command line, no coding required)
**Prerequisites**: Linux VM, 2GB RAM, internet access

For questions or issues, refer to the documentation in the `docs/` directory or consult the Elastic support documentation.
