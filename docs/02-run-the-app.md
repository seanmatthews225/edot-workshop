# Running the Application Without Instrumentation

This stage gets both the Java frontend and Python backend running in their uninstrumented state. This is the baseline — when you interact with the application, no observability data is sent to Elastic. In the next steps, we'll add EDOT instrumentation layer by layer and watch the observability data appear.

## Architecture Overview

```
Browser (localhost:8080)
    ↓ HTTP request
Java Frontend (Spring Boot)
    ↓ REST call
Python Backend (FastAPI)
    ↓ SQL query
PostgreSQL Database
```

No arrows go to Elastic yet — that comes in the next steps.

## Prerequisites

Before starting, ensure you've completed:
1. docs/00-prerequisites.md — all tools installed
2. docs/01-database-setup.md — PostgreSQL running with sample data

## Step 1: Set Up Python Virtual Environment

We'll create an isolated Python environment for the backend to avoid dependency conflicts with your system Python.

Navigate to the python-backend directory:

```bash
cd python-backend
```

Create a virtual environment:

```bash
python3 -m venv venv
```

This creates a `venv/` folder containing Python and pip isolated from system packages.

Activate the virtual environment:

```bash
source venv/bin/activate
```

Your shell prompt should now show `(venv)` at the beginning, indicating the virtual environment is active.

Upgrade pip to the latest version:

```bash
pip install --upgrade pip
```

Install the backend dependencies:

```bash
pip install -r requirements.txt
```

This installs FastAPI, Uvicorn, SQLAlchemy, psycopg2, and Pydantic — everything the backend needs.

Verify the installation:

```bash
python -m pip list
```

You should see fastapi, uvicorn, sqlalchemy, and psycopg2-binary in the list.

## Step 2: Start the Python Backend

While still in the `python-backend` directory with your virtual environment activated:

```bash
./scripts/run.sh
```

The output should show:

```
=== Starting Python Backend (uninstrumented) ===
  URL    : http://localhost:8000
  API Doc: http://localhost:8000/docs
  Press Ctrl+C to stop

INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

The Python backend is now listening on port 8000. Leave this terminal running.

To test it's working, open a new terminal and run:

```bash
curl http://localhost:8000/health
```

You should get a response:

```json
{"status":"UP","service":"python-backend"}
```

You can also visit http://localhost:8000/docs in your browser to see the interactive API documentation (Swagger UI).

## Step 3: Build the Java Frontend

Open a new terminal window (keep the Python backend running in the first one).

Navigate to the java-frontend directory:

```bash
cd java-frontend
```

Build the application with Maven:

```bash
./scripts/build.sh
```

This will download dependencies (might take 1-2 minutes on first run) and compile the Spring Boot application. You should see output ending with:

```
BUILD SUCCESS

✓ Build successful!
  JAR: target/java-frontend-1.0.0.jar
```

## Step 4: Start the Java Frontend

Still in the java-frontend directory, run the frontend:

```bash
./scripts/run.sh
```

The output should show:

```
=== Starting Java Frontend (uninstrumented) ===
  URL: http://localhost:8080
  Press Ctrl+C to stop

  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '''' |_.__'_|\___|_|_|_\__,_|_//_/_/_/
 2024-01-16 10:45:32.123  INFO 12345 --- [main] c.e.w.Application : Starting Application
...
 2024-01-16 10:45:35.456  INFO 12345 --- [main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat started on port(s): 8080 (http)
```

The Java frontend is now running on port 8080. Leave this terminal running as well.

## Step 5: Test the Application

Open your browser and navigate to http://localhost:8080

You should see the EDOT Workshop User Management interface with:
- A blue banner at the top
- "Total Users: 3" badge showing the three seed records from the database
- A table listing Alice Johnson, Bob Smith, and Carol White
- A form to add new users

Try the following interactions to test the full flow:

1. **Add a user**: Fill in the "Add New User" form with:
   - Name: "Diana Prince"
   - Email: "diana@example.com"
   - Click "Create User"

   The page reloads and you should see Diana added to the list.

2. **Delete a user**: Find any user in the table and click the "Delete" button.
   Confirm the deletion dialog, and the user is removed.

As you perform these actions:
- The Java frontend receives your HTTP request
- It makes a REST call to the Python backend (port 8000)
- The Python backend queries PostgreSQL
- The data is returned back through both layers to your browser

All of this is happening with zero observability data being collected. That's the point — watch what changes when we add instrumentation.

## Observing the Application Behavior

Watch the terminal outputs:

**Java Frontend terminal** should show requests like:
```
2024-01-16 10:45:50.123  INFO 12345 --- [nio-8080-exec-1] c.e.w.c.UserController : Fetching users
```

**Python Backend terminal** should show:
```
INFO:     127.0.0.1:54321 "GET /api/users HTTP/1.1" 200 OK
INFO:root:Fetching all users
```

These are standard application logs. In the next steps, when we add EDOT instrumentation, these log messages will be enriched with trace IDs, span IDs, and sent to Elastic for aggregation and visualization.

## Common Issues

**"Connection refused: http://localhost:8000"**
- The Python backend isn't running. Ensure the first terminal still has `./scripts/run.sh` executing.

**"Tomcat started on port(s): 8080" but page shows "Failed to connect"**
- Wait 5-10 seconds for Spring Boot to fully initialize.
- Check if another service is using port 8080: `lsof -i :8080`

**"ERROR: Failed to fetch users from Python backend"**
- Ensure PostgreSQL is running: `sudo systemctl status postgresql`
- Ensure the Python backend is running and accessible: `curl http://localhost:8000/health`

**"psycopg2.OperationalError: connection failed"**
- Python can't connect to PostgreSQL. Check:
  - PostgreSQL is running: `sudo systemctl start postgresql`
  - Database user/password are correct in `database.py`
  - Database exists: `sudo -u postgres psql -l`

## Next Steps

You now have a working three-tier application with no observability. The data flows correctly: Browser → Java → Python → PostgreSQL.

Proceed to **docs/03-instrument-java.md** to add EDOT instrumentation to the Java frontend and start seeing traces in Elastic Observability.
