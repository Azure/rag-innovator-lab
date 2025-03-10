import logging
import os
import azure.functions as func
from file_processing import file_processing
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

logging.captureWarnings(True)
logging.basicConfig(level=os.environ.get("LOGLEVEL", "DEBUG").upper())
# Raising the azure log level to WARN as it is too verbose - https://github.com/Azure/azure-sdk-for-python/issues/9422
logging.getLogger("azure").setLevel(os.environ.get("LOGLEVEL_AZURE", "WARN").upper())

app_insights_enabled = os.getenv("APPLICATIONINSIGHTS_ENABLED", "false").lower()
if app_insights_enabled == "true":
    configure_azure_monitor(enable_live_metrics=True)
    HTTPXClientInstrumentor().instrument()
else:
    logging.warning("Application Insights is not enabled.")

app = func.FunctionApp(
    http_auth_level=func.AuthLevel.FUNCTION
)  # change to ANONYMOUS for local debugging
app.register_functions(file_processing)
