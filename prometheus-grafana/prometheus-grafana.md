# Prometheous

Dowload
```bash
cd ~
wget https://github.com/prometheus/prometheus/releases/download/v2.47.2/prometheus-2.47.2.linux-amd64.tar.gz

tar -xvfz prometheus-*.tar.gz
# cd prometheus-*
sudo mv prometheus-*.linux-amd64 /opt/prometheus
```
create user
```bash
sudo userdel prometheus

sudo useradd -M -U prometheus
```

```bash
## /usr/local/bin/prometheus-2.46.0.linux-amd64/prometheus --config.file=/usr/local/bin/prometheus-2.46.0.linux-amd64/prometheus.yml --web.listen-address=0.0.0.0:9091
vi /opt/prometheus/prometheus.yml
```

```yaml
# my global config
global:
  scrape_interval: 15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

  # Attach these extra labels to all timeseries collected by this Prometheus instance.
  external_labels:
    monitor: 'codelab-monitor'

rule_files:
  - 'prometheus.rules.yml'

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
#rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: "prometheus"

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    static_configs:
      - targets: ["192.168.1.138:9091", "192.168.1.139:9100","192.168.1.134:9100", "fedora.local:9100","192.168.1.200:9100","raspberrypi.local:9100"]
        labels:
          group: "production"

     #- targets: ['192.168.1.138:8082']
     #   labels:
     #     group: 'canary'
  # Fedora.local Server Exporter
  - job_name: "fedora-exporter"
    static_configs:
      - targets: ["192.168.1.134:9100"]


  - job_name:       'node'
    # Override the global default and scrape targets from this job every 5 seconds.
    scrape_interval: 5s

    static_configs:
      - targets: ['localhost:8080', 'localhost:8081','192.168.1.139:9100']
        labels:
          group: 'production'

      - targets: ['localhost:8082']
        labels:
          group: 'canary'
```

sudo vi /usr/lib/systemd/system/prometheus.service

```ini
[Unit]
Description=Prometheus Server
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Restart=on-failure
Type=simple
ExecStart=/opt/prometheus/prometheus \
  --config.file=/opt/prometheus/prometheus.yml \
  --web.listen-address=0.0.0.0:9091
  --storage.tsdb.path=/opt/prometheus/data \
  --storage.tsdb.retention.time=30d \
  --web.listen-address=0.0.0.0:9091

[Install]
WantedBy=multi-user.target
```

```bash
# Start systemd service of Prometheus with:
sudo systemctl daemon-reload
sudo systemctl start prometheus.service

# Enable service to start and system start-up:

sudo systemctl enable prometheus.service
# Check the status of the service with:
sudo systemctl status prometheus.service

# To view the logs of Prometheus for troubleshooting, type:
sudo journalctl -u prometheus.service -f
```