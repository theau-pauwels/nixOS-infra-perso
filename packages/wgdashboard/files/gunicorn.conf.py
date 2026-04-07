import os
from datetime import datetime

import dashboard

app_host, app_port = dashboard.gunicornConfig()
configuration_path = os.getenv("CONFIGURATION_PATH", ".")
log_dir = os.path.join(configuration_path, "log")
os.makedirs(log_dir, exist_ok=True)
date = datetime.today().strftime("%Y_%m_%d_%H_%M_%S")


def post_worker_init(worker):
    dashboard.startThreads()
    dashboard.DashboardPlugins.startThreads()


worker_class = "gthread"
workers = 1
threads = 2
bind = f"{app_host}:{app_port}"
daemon = False
pidfile = os.path.join(configuration_path, "gunicorn.pid")
wsgi_app = "dashboard:app"
accesslog = os.path.join(log_dir, f"access_{date}.log")
loglevel = "info"
capture_output = True
errorlog = os.path.join(log_dir, f"error_{date}.log")
pythonpath = "., ./modules"

print(f"[Gunicorn] WGDashboard w/ Gunicorn will be running on {bind}", flush=True)
print(f"[Gunicorn] Access log file is at {accesslog}", flush=True)
print(f"[Gunicorn] Error log file is at {errorlog}", flush=True)
