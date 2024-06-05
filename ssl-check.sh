#!/bin/bash
HOST=${1}
PORT=${2:-443}

now=$(date +%s)
notAfterString=$(echo q | openssl s_client -servername "${HOST}" "${HOST}:${PORT}" 2>/dev/null | openssl x509 -noout -enddate | awk -F"=" '{ print $2; }')
if [[ "$(uname)" == "Darwin" ]] ; then
  notAfter=$(date -j -f "%b %d %H:%M:%S %Y %Z" "${notAfterString}" +%s)
else
  notAfter=$(date -d "${notAfterString}" +%s)
fi

secondsLeft=$(($notAfter-$now))

metric_name="tls_server_not_after_time_left"
metric_value="$secondsLeft"
metric_timestamp="$now"

# Use HTTP POST to send data to the OpenTelemetry Collector
curl -X POST http://localhost:4318/v1/metrics -H "Content-Type: application/json" -d "{
  \"resource\": {
    \"attributes\": [
      {
        \"key\": \"service.name\",
        \"value\": {
          \"stringValue\": \"$HOST\"
        }
      }
    ]
  },
  \"scopeMetrics\": [
    {
      \"metrics\": [
        {
          \"name\": \"$metric_name\",
          \"unit\": \"s\",
          \"description\": \"Remaining time until SSL certificate expiration\",
          \"gauge\": {
            \"dataPoints\": [
              {
                \"asInt\": $metric_value,
                \"timeUnixNano\": $metric_timestamp * 1000000000  # Convert to nanoseconds
              }
            ]
          }
        }
      ]
    }
  ]
}"
