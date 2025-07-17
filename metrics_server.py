# metrics_server.py
from prometheus_client import start_http_server, Gauge
import time

g = Gauge('analytics_metric', 'Example metric from analytics image')

if __name__ == "__main__":
    start_http_server(8000)  # Expose metrics on :8000/metrics
    while True:
        g.set(time.time() % 100)  # Simulate a metric
        time.sleep(5)
