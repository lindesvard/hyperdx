#!/bin/bash

# Simple ping and test script for OpenTelemetry Collector
echo "🔗 Quick OpenTelemetry Collector Tests"
echo "====================================="

# Test basic connectivity
echo "1. Testing port connectivity:"
for port in 13133 4317 4318 24225 8888; do
    echo -n "  Port $port: "
    if nc -z localhost $port 2>/dev/null; then
        echo "✅ Open"
    else
        echo "❌ Closed"
    fi
done

# Test basic HTTP endpoints
echo -e "\n2. Testing HTTP endpoints:"

# Test metrics endpoint
echo -n "  Metrics endpoint (8888): "
if curl -s -f http://localhost:8888/metrics >/dev/null 2>&1; then
    echo "✅ Responding"
else
    echo "❌ Not responding"
fi

# Send a simple test trace
echo -e "\n3. Sending test telemetry data:"
echo -n "  Test trace: "
response=$(curl -s -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d '{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"test"}}]},"instrumentationLibrarySpans":[{"spans":[{"traceId":"12345678901234567890123456789012","spanId":"1234567890123456","name":"test","startTimeUnixNano":"1609459200000000000","endTimeUnixNano":"1609459260000000000"}]}]}]}' \
    "http://localhost:4318/v1/traces" 2>/dev/null)

status_code=$(echo "$response" | tail -n1)
if [ "$status_code" = "200" ] || [ "$status_code" = "202" ]; then
    echo "✅ Accepted (HTTP $status_code)"
else
    echo "❌ Rejected (HTTP $status_code)"
fi

# Check service status
echo -e "\n4. Service status:"
docker-compose ps otel-collector | grep -E "(NAME|otel-collector)"

echo -e "\n🔍 To see real-time logs: docker-compose logs -f otel-collector"
echo "📊 To see metrics: curl http://localhost:8888/metrics"
echo "🧪 Test script location: ./test-otel-collector.sh (comprehensive tests)"
