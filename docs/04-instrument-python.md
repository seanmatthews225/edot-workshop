# Instrumenting Python with EDOT: Completing the Picture

This is the final step — the "aha moment" when distributed tracing comes alive. You're about to add instrumentation to the Python backend, and suddenly, the entire request flow from Java through Python to the database becomes visible as a single distributed trace.

## The Complete Story

In the previous step, you saw Java traces with a gap: calls to the Python backend showed up as external requests with no detail. Now we'll fill that gap.

After this step, a single user interaction will produce a trace like:

```
Java Frontend: GET /
├── Service call to Python Backend: POST /api/users
│   ├── Python receives request (with same trace ID as Java)
│   ├── Database Query: INSERT INTO users ...
│   │   └── 45ms in PostgreSQL
│   ├── Python processes response
│   └── 120ms total in Python
├── Render response
└── 250ms total end-to-end
```

The key difference: the Python spans have the **same trace ID** as the Java spans because the Java agent sends a W3C traceparent header, and the EDOT Python instrumentation receives it and continues the trace.

## Prerequisites

Before starting:
1. Java frontend should still be running with EDOT (`./scripts/run-with-edot.sh`)
2. PostgreSQL should be running
3. You need the **same Elastic Cloud credentials** from the previous step
   - OTLP endpoint
   - API key

## Step 1: Prepare Python Environment

Stop the Python backend if it's currently running (Ctrl+C in its terminal).

Navigate to the python-backend directory:

```bash
cd python-backend
```

Make sure your Python virtual environment is activated (you should see `(venv)` in your prompt):

```bash
source venv/bin/activate
```

## Step 2: Install EDOT Python

The EDOT Python distribution is installed via pip from PyPI:

```bash
pip install elastic-opentelemetry
```

This installs the EDOT distribution along with its dependencies:
- opentelemetry-api
- opentelemetry-sdk
- opentelemetry-instrumentation
- Various instrumentations for FastAPI, SQLAlchemy, PostgreSQL, etc.

Verify installation:

```bash
python -c "import elastic_opentelemetry; print('EDOT Python installed')"
```

You should see: "EDOT Python installed"

## Step 3: Run the EDOT Bootstrap

EDOT provides a bootstrap utility that prepares your Python environment for zero-code instrumentation:

```bash
edot-bootstrap --action=install
```

This command:
- Scans your virtual environment
- Identifies installed libraries (FastAPI, SQLAlchemy, requests, etc.)
- Installs OpenTelemetry instrumentation for each detected library
- Configures auto-instrumentation hooks

You'll see output like:

```
Installing instrumentation for: fastapi
Installing instrumentation for: sqlalchemy
Installing instrumentation for: psycopg2
...
Bootstrap complete. Ready to run with opentelemetry-instrument.
```

Verify the bootstrap succeeded:

```bash
python -m pip list | grep opentelemetry
```

You should see many opentelemetry packages now installed.

## Step 4: Set Environment Variables (Same as Java)

Use the **exact same** environment variables you set for Java:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="https://your-apm-endpoint-here.cloud.es.io"
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=ApiKey your-api-key-here"
```

These should be identical to what you used in step 03-instrument-java.md.

Verify they're set:

```bash
echo $OTEL_EXPORTER_OTLP_ENDPOINT
echo $OTEL_EXPORTER_OTLP_HEADERS
```

## Step 5: Run Python Backend with EDOT

From the python-backend directory, run:

```bash
./scripts/run-with-edot.sh
```

The output will show:

```
=== Starting Python Backend WITH EDOT Instrumentation ===
  Service Name : python-backend
  OTLP Endpoint: https://your-apm-endpoint.cloud.es.io
  URL          : http://localhost:8000
  API Doc      : http://localhost:8000/docs
  Press Ctrl+C to stop

INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     Instrumenting FastAPI with OpenTelemetry...
INFO:     Instrumenting SQLAlchemy with OpenTelemetry...
```

Your Python backend is now running with EDOT instrumentation enabled. The `opentelemetry-instrument` wrapper has injected instrumentation before your application started.

## Step 6: Generate Traffic and Watch the Magic

Open your browser to http://localhost:8080 (the Java frontend) and interact with the application:

1. **Add a new user** with the form
2. **Delete a user** from the table
3. **Refresh the page** several times
4. **Check the health endpoints**:
   - http://localhost:8080/health (Java)
   - http://localhost:8000/health (Python)

Each action now produces traces in both Java and Python with the **same trace ID**.

Watch the terminals:

**Java Frontend terminal** shows:
```
GET / HTTP/1.1 200
POST /users HTTP/1.1 303
```

**Python Backend terminal** shows:
```
GET /api/users HTTP/1.1 200 OK
POST /api/users HTTP/1.1 201 Created
```

Both are instrumented now. Both send traces to Elastic with the same trace IDs.

## Step 7: View the Complete Distributed Trace in Elastic

Go to Kibana and navigate to **Observability > Applications > Traces**.

### Looking at the Service Map

Visit **Service Map** to see the complete dependency graph:

```
Browser
  ↓
java-frontend (with trace metrics)
  ↓
python-backend (with trace metrics)
  ↓
PostgreSQL (inferred from database spans)
```

All three services are now visible! The arrows show request flow and timing.

### Viewing a Complete Trace

Click on any trace to open the trace detail view. Now you'll see:

```
Browser Request (1000ms total)
├── Java Request (950ms)
│   ├── HTTP GET / (100ms)
│   ├── Python Backend Call (800ms)
│   │   ├── HTTP GET /api/users (750ms)
│   │   │   ├── Database Query: SELECT * FROM users (300ms)
│   │   │   │   └── PostgreSQL execution
│   │   │   ├── Python response building (450ms)
│   │   │   └── Database Query: [if creating user]
│   │   └── Response processing (50ms)
│   └── Response rendering (100ms)
└── Browser rendering (50ms)
```

The crucial detail: **all these spans have the same Trace ID** because:

1. Java frontend generates a trace ID and sends it in the HTTP request as a `traceparent` header
2. Python backend receives the header and EDOT instrumentation extracts it
3. All Python spans use the same trace ID
4. SQL queries have the Python trace ID in the parent span
5. Elastic aggregates all spans with the same trace ID into one distributed trace

### Key Observations

1. **Trace ID Correlation**: Open any trace and note the trace ID at the top. If you filter by that trace ID in Elastic, you'll see it appears in both java-frontend and python-backend services.

2. **Span Hierarchy**: You can see the exact parent-child relationship of spans:
   - Java HTTP request is the parent
   - Python route handler is a child (inherits the trace ID)
   - Database query is a child of the Python handler
   - Response processing is a sibling of the database query under the Python handler

3. **Timing Breakdown**: Each span shows:
   - Duration (how long this operation took)
   - Time in children (how long all child operations took)
   - Self time (duration minus children — useful for finding where work is done)

4. **Database Visibility**: Look for spans named "db.statement" or "SELECT":
   - These are SQL queries captured by SQLAlchemy instrumentation
   - You'll see the exact SQL executed
   - You can see PostgreSQL connection time, query execution time, etc.

## Advanced: Trace Analysis Example

Here's a scenario to try:

1. **Open one terminal** to monitor Java traces:
   - Go to Kibana Observability > Traces
   - Filter by service "java-frontend"

2. **Open another view** for Python traces:
   - Open a second Kibana tab
   - Filter by service "python-backend"

3. **In the browser**, perform an action (e.g., create a new user)

4. **Watch both terminals**:
   - You'll see nearly identical timing
   - The Python trace ID matches the Java trace ID
   - The database query appears in the Python trace

5. **Click into the unified trace**:
   - See the complete call chain
   - Notice the W3C traceparent header propagation in the HTTP request details
   - Observe database connection pooling behavior if queries are frequent

## Common Issues

**"python-backend service doesn't appear in Elastic after 30 seconds"**
- Verify OTEL_EXPORTER_OTLP_ENDPOINT is set: `echo $OTEL_EXPORTER_OTLP_ENDPOINT`
- Verify API key permissions (must be "Editor" for APM, not just "read")
- Wait 60 seconds — sometimes there's a longer ingestion delay on first contact
- Check Elasticsearch cluster is healthy in Kibana

**"Python backend crashes on startup with OpenTelemetry error"**
- Ensure `edot-bootstrap --action=install` was run: `python -m pip list | grep opentelemetry`
- Try reinstalling: `pip uninstall -y opentelemetry-* elastic-opentelemetry && pip install elastic-opentelemetry`
- Check your Python version is 3.9+: `python --version`

**"Traces from Java don't link to Python traces"**
- Verify both use the same OTEL_EXPORTER_OTLP_ENDPOINT
- Check the API key hasn't changed
- Ensure Java frontend is still running with `./scripts/run-with-edot.sh`
- Wait 30-60 seconds for Elastic to ingest and correlate traces

**"Database queries don't appear in traces"**
- Verify PostgreSQL is running and responding: `psql -U workshopuser -d workshopdb -h localhost -c "SELECT COUNT(*) FROM users;"`
- Ensure sqlalchemy instrumentation was installed: `python -m pip list | grep sqlalchemy`
- Check your queries actually execute (try the UI to create/delete a user)
- Look in Python terminal for any connection errors

## Summary: What You've Accomplished

You now have:

1. **Complete visibility** from browser to database
2. **Automatic instrumentation** of:
   - HTTP requests (Java and Python)
   - Database queries (PostgreSQL via SQLAlchemy)
   - Inter-service calls (Java to Python)
3. **Distributed trace correlation** across three separate systems
4. **Zero code changes** in either Java or Python application code
5. **W3C standard trace context** propagation (traceparent headers)

This is what EDOT delivers: production-grade observability with a javaagent and a bootstrap command, no invasive code changes.

## Next Steps

You've completed the workshop! Here are some exercises to deepen your understanding:

1. **Introduce an error**: Modify one query in Python to cause a database error. Watch the trace show the error span.

2. **Add load**: Open multiple browser tabs and hammer the application with requests. Watch latency increase in the traces.

3. **Check metrics**: Beyond traces, EDOT also collects metrics. Look in **Observability > Infrastructure** for CPU, memory, JVM metrics, etc.

4. **Explore Elastic integration**: Set up custom dashboards in Kibana based on the trace data:
   - Average response time by service
   - Error rate by endpoint
   - Database query performance

5. **Document your findings**: Capture screenshots of the service map and distributed traces showing the full observability picture.

Congratulations — you've successfully demonstrated EDOT observability across a modern distributed application!
