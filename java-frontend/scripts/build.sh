#!/bin/bash
# Build the Java frontend service

set -e

echo "=== Building Java Frontend ==="

cd "$(dirname "$0")/.."

# Check Java version
java_version=$(java -version 2>&1 | head -1)
echo "Java version: $java_version"

# Check Maven
if command -v mvn &> /dev/null; then
    echo "Building with Maven..."
    mvn clean package -DskipTests
    echo ""
    echo "✓ Build successful!"
    echo "  JAR: target/java-frontend-1.0.0.jar"
else
    echo "ERROR: Maven (mvn) not found. Please install Maven first."
    echo "  sudo apt-get install maven"
    exit 1
fi
