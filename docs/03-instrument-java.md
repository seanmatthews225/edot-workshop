# Instrumenting Java with EDOT

This is where the magic begins. We're about to add observability to the Java frontend with zero code changes. The EDOT Java agent will automatically instrument Spring Boot, HTTP clients, and JVM internals, capturing traces of every request.

## The "Missing Piece" Story

Right now, your Python backend is a black box to the Java frontend. When Java makes an HTTP call to Python and something goes wrong, you have logs but no insight into:
- How long the request took
- Which database queries were slow
- Where in the stack the time was spent

After instrumenting Java in this step, you'll see Java traces in Elastic, but the calls to Python will still show up as "external" — the missing piece. That's intentional. In the next step, when we instrument Python, the pieces snap together and you see the complete distributed trace.

## Prerequisites

Before starting:
1. Java frontend should be built: `java-frontend/target/java-frontend-1.0.0.jar` should exist
2. You need Elastic Cloud credentials:
   - OTLP endpoint (APM Server URL)
   - API key with APM permissions

## Step 1: Get Your Elastic Cloud Credentials

If you haven't already, sign up for Elastic Cloud at https://www.elastic.co/cloud and create a deployment. Once your deployment is running:

### Find Your APM Endpoint

1. Log into Kibana
2. Navigate to **Observability > APM** from the left menu
3. Look for a message showing your APM Server URL, or go to **Stack Management > Endpoints**
4. You'll see something like: `https://abc123xyz.apm.us-east-1.cloud.es.io`

Copy this full URL.

### Create or Get Your API Key

1. In Kibana, go to **Stack Management > API Keys**
2. Click **Create API Key**
3. Name: "edot-workshop"
4. Privilege: Select **Editor** under APM
5. Click **Create API Key**
6. Copy the API key value (you'll only see it once)

Store these two values somewhere safe — you'll use them in the next step.

## Step 2: Set Environment Variables

Before running the Java frontend with EDOT, export your Elastic credentials:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="https://your-apm-endpoint-here.cloud.es.io"
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=ApiKey your-api-key-here"
```

Replace `your-apm-endpoint-here` and `your-api-key-here` with your actual values.

Verify the variables are set:

```bash
echo $OTEL_EXPORTER_OTLP_ENDPOINT
echo $OTEL_EXPORTER_OTLP_HEADERS
```

You should see your endpoint and API key (the key will be masked in output).

**Important**: These environment variables only apply to your current shell session. If you open a new terminal, you'll need to set them again. Many teams store these in a `.env` file (never commit to git) or in a secrets manager.

## Step 3: Run Java Frontend with EDOT

In the java-frontend directory, run:

```bash
./scripts/run-with-edot.sh
```

The first time you run this, it will download the EDOT Java agent (a large JAR file). You'll see:

```
EDOT Java agent not found. Downloading...
  Source: https://github.com/elastic/elastic-otel-java/releases/latest
  Downloaded elastic-otel-javaagent.jar
```

Then the Java frontend starts with EDOT attached:

```
=== Starting Java Frontend WITH EDOT Instrumentation ===
  Service Name : java-frontend
  OTLP Endpoint: https://your-apm-endpoint.cloud.es.io
  URL          : http://localhost:8080
  Press Ctrl+C to stop

  .   ____          _            __ _ _
...
 Tomcat started on port(s): 8080 (http)
```

Your instrumented Java frontend is now running and ready to send traces to Elastic.

## Step 4: Generate Traffic

Open your browser to http://localhost:8080 and interact with the application:

1. **Refresh the page** a few times to load the user list
2. **Add a new user** using the form
3. **Delete a user** from the table
4. **Refresh again** to reload the list

Each action sends HTTP requests through your instrumented Java service to the Python backend. The EDOT agent captures traces of all these requests.

Watch the terminal running the Java frontend. You should see verbose logging from the OpenTelemetry instrumentation:

```
[OpenTelemetry] Initializing...
[OpenTelemetry] Exporting span: GET /api/users
[OpenTelemetry] Exporting span: POST /api/users
...
```

This confirms traces are being captured and sent to Elastic.

## Step 5: View Traces in Elastic Observability

Now comes the payoff. Go to your Kibana instance and navigate to **Observability > Applications**.

You should see:

1. **Service Inventory**: Shows `java-frontend` service listed
2. **Click on java-frontend** to view its details
3. **Traces tab**: Shows all the HTTP requests you just made

Click on any trace to see the full waterfall:

- **GET /api/users** appears as a span under the parent request
- Timing shows exactly how long the request took
- The Java agent has captured:
  - HTTP request details (method, URL, status code)
  - Timing breakdown of each operation
  - JVM metrics (thread names, garbage collection if it occurred)

## The Missing Piece: External Calls

Here's the key insight: Look at a GET /api/users trace. You'll see:

```
GET / (main request)
├── POST /users (user creation form submission)
├── HTTP GET http://localhost:8000/api/users (external call)
│   └── [No visibility — backend is uninstrumented]
└── Render response
```

The Python backend call shows up as an "externalRequest" but there's no service-level detail — no database query timing, no Python span hierarchy. The Java agent sees the outgoing HTTP request (because it intercepts HTTP clients), but since Python isn't instrumented yet, the distributed trace context (the traceparent header) is propagated but not received by any instrumentation on the other end.

This is intentional for learning. The W3C traceparent header IS being sent by the Java agent:

```
traceparent: 00-4bf92f3577b7813f0ad8030b37c518d1-d7d17eb23427f294-01
```

But nobody's listening for it in Python yet.

## Checking Trace Context Propagation

If you want to verify the trace context is being sent, you can enable request logging on the Java service. Add to your request logging, you'll see the outgoing requests include the traceparent header in their HTTP calls.

The Python backend will receive these headers but ignore them (until we instrument it in the next step).

## Useful Queries in Elastic

Once you have traces, try these queries in the Observability UI:

1. **Filter by service name**: Select `java-frontend` to see only Java traces
2. **Filter by transaction type**: "http" to see only HTTP requests
3. **Time range filter**: Shows the specific timeframe you generated traffic
4. **Search for slow transactions**: Sort by duration to find the slowest requests

## Common Issues

**"No traces appearing in Elastic"**
- Wait 30 seconds — there's a small ingestion delay
- Verify the OTLP endpoint is correct: `curl -v $OTEL_EXPORTER_OTLP_ENDPOINT`
- Check the API key has APM permissions (not just "read")
- Look for errors in the Java terminal output starting with "[OpenTelemetry]"

**"Traces showing but no HTTP spans"**
- The Java agent is initialized but might not have instrumentation for your version of Spring Boot
- Verify you're using Spring Boot 3.x (check java-frontend/pom.xml)

**"OTLP Endpoint rejected with 401"**
- API key is invalid or missing the "Editor" permission for APM
- Generate a new API key and update OTEL_EXPORTER_OTLP_HEADERS

**"Java frontend won't start with EDOT"**
- Verify elastic-otel-javaagent.jar exists in java-frontend/: `ls -la java-frontend/elastic-otel-javaagent.jar`
- Check environment variables are set: `echo $OTEL_EXPORTER_OTLP_ENDPOINT`

## Next Steps

You now have visibility into the Java frontend layer. The traces show HTTP requests, response times, and error rates.

Proceed to **docs/04-instrument-python.md** to instrument the Python backend and complete the picture with full end-to-end distributed tracing from Java through Python to PostgreSQL.
