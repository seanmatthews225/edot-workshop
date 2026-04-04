# Prerequisites: Setting Up Your Environment

Before you begin this EDOT observability workshop, you'll need to ensure your system has all the necessary tools installed and configured. This guide walks you through each requirement and provides installation instructions for Ubuntu 20.04 and later.

## System Requirements

This workshop is designed to run on a single Linux VM with the following minimum specifications:

- **OS**: Ubuntu 20.04 LTS or newer (or equivalent Linux distribution)
- **RAM**: 2 GB minimum (4 GB recommended for comfort)
- **Disk Space**: 10 GB free space minimum
- **Network**: Internet access to download dependencies and connect to Elastic Cloud

## 1. PostgreSQL Database

PostgreSQL is the persistent data store for our user management application. The Python backend connects to this database while the Java frontend communicates through the backend API.

### Installation

```bash
sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib
```

### Verification

After installation, verify PostgreSQL is running:

```bash
psql --version
sudo systemctl status postgresql
```

You should see PostgreSQL is active and running. If not, start it:

```bash
sudo systemctl start postgresql
```

## 2. Java 17

The Java frontend service is built on Spring Boot 3.2.4, which requires Java 17 or later. We'll use the OpenJDK distribution.

### Installation

```bash
sudo apt-get install -y openjdk-17-jdk
```

### Verification

Check your Java installation:

```bash
java -version
```

You should see output indicating Java 17.x.x. This confirms the JDK is installed and available in your PATH.

## 3. Maven 3.8+

Maven is the build tool for the Java Spring Boot application. It will download dependencies and package the application into an executable JAR file.

### Installation

```bash
sudo apt-get install -y maven
```

### Verification

```bash
mvn --version
```

You should see Maven version 3.8.0 or later, along with the Java version it will use for compilation.

## 4. Python 3.9+

Python powers our FastAPI backend service. We'll use Python's built-in virtual environment tools to isolate dependencies.

### Installation

```bash
sudo apt-get install -y python3 python3-pip python3-venv
```

### Verification

```bash
python3 --version
pip3 --version
```

Both should show Python 3.9 or later. If you're on Ubuntu 22.04 or later, you might have Python 3.10+ already installed.

## 5. Git (Optional but Recommended)

While the workshop materials are provided directly, you may want Git for version control or to explore the Elastic OpenTelemetry repositories.

### Installation

```bash
sudo apt-get install -y git
```

## 6. Elastic Stack Access

The entire point of this workshop is to send observability data to Elastic. You have two options:

### Option A: Elastic Cloud (Recommended for Workshops)

Elastic Cloud is the official managed service. It's the easiest way to get started:

1. Create a free trial account at https://www.elastic.co/cloud
2. Create a new deployment (choose any region closest to you)
3. Once running, navigate to **Observability > APM**
4. Look for your **APM Server URL** — it will look like:
   ```
   https://your-deployment-xyz.apm.region.cloud.es.io
   ```
5. Generate an **API Key** in the Kibana UI under Stack Management > API Keys
   - Give it a name like "edot-workshop"
   - Set permissions for "Editor" on APM
6. You'll also get an **Elasticsearch endpoint** and **Kibana URL** for viewing traces

### Option B: Self-Managed Elastic Stack

If you prefer to run Elasticsearch, Kibana, and APM Server locally, follow the official Elastic documentation. This requires more resources and setup time, so it's not recommended for a hands-on workshop unless you're already familiar with Elastic deployments.

## 7. Verify Your Setup

Create a simple verification script to check all prerequisites are met:

```bash
#!/bin/bash
echo "=== EDOT Workshop Prerequisites Check ==="
echo ""

echo -n "Java: "
java -version 2>&1 | head -1

echo -n "Maven: "
mvn --version | head -1

echo -n "Python: "
python3 --version

echo -n "PostgreSQL: "
psql --version

echo ""
echo "✓ All prerequisites are installed!"
echo ""
echo "Next: Follow docs/01-database-setup.md to initialize the database."
```

Save this as `verify-setup.sh`, make it executable with `chmod +x verify-setup.sh`, and run it:

```bash
./verify-setup.sh
```

## Troubleshooting

**"command not found: java"**
- Java is not in your PATH. Verify installation with `sudo apt-get install openjdk-17-jdk` and restart your terminal.

**"PostgreSQL refuses to connect"**
- Ensure PostgreSQL is running: `sudo systemctl start postgresql`
- Check status: `sudo systemctl status postgresql`

**"mvn: command not found"**
- Maven wasn't installed. Run `sudo apt-get install maven` and verify with `mvn --version`.

**"python3: command not found"**
- Python 3 is not installed. Run `sudo apt-get install python3 python3-pip`.

**"No internet connection to Elastic Cloud"**
- Verify your network connection: `ping google.com`
- Check firewall rules if behind a corporate network
- If self-hosting, ensure APM Server is running and accessible

## Next Steps

Once you've confirmed all prerequisites are installed, proceed to **docs/01-database-setup.md** to initialize the PostgreSQL database and seed it with sample data.
