import os
import logging
import json
from urllib.parse import urlparse
import azure.functions as func

from utilities.helpers.azure_blob_storage_client import AzureBlobStorageClient
from utilities.helpers.env_helper import EnvHelper
from utilities.helpers.embedders.embedder_factory import EmbedderFactory
from utilities.search.search import Search

file_processing = func.Blueprint()
logger = logging.getLogger(__name__)
logger.setLevel(level=os.environ.get("LOGLEVEL", "DEBUG").upper())

def _get_file_name_from_message(message_body) -> str:
    return message_body.get(
        "fullpath",
        "/".join(
            urlparse(message_body.get("data", {}).get("url", "")).path.split("/")[2:]
        ),
    )


@file_processing.queue_trigger(
    arg_name="msg", queue_name="sharepointragqueue", connection="AzureWebJobsStorage"
)
def dequeue_file(msg: func.QueueMessage) -> None:
    message_body = json.loads(msg.get_body().decode("utf-8"))
    logger.info("Process Document Event queue function triggered: %s", message_body)

    event_type = message_body.get("eventType", "")
    if event_type in ("", "CreatedOrUpdated"):
        logger.info("Handling 'Blob Created' event with message body: %s", message_body)
        _process_document_created_event(message_body)

    elif event_type == "Deleted":
        logger.info("Handling 'Blob Deleted' event with message body: %s", message_body)
        _process_document_deleted_event(message_body)

    else:
        logger.exception("Received an unrecognized event type: %s", event_type)
        raise NotImplementedError(f"Unknown event type received: {event_type}")


def _process_document_created_event(message_body) -> None:
    env_helper: EnvHelper = EnvHelper()

    blob_client = AzureBlobStorageClient()
    file_name = _get_file_name_from_message(message_body)
    file_sas = blob_client.get_blob_sas(file_name)
    sharepoint_file_id = str(message_body.get("sharepointFileId"))

    logger.info("_process_document_created_event : %s - %s - %s", file_name, file_sas, sharepoint_file_id)
    embedder = EmbedderFactory.create(env_helper)
    embedder.embed_file(file_sas, file_name, sharepoint_file_id)


def _process_document_deleted_event(message_body) -> None:
    env_helper: EnvHelper = EnvHelper()
    search_handler = Search.get_search_handler(env_helper)

    # blob_url = message_body.get("data", {}).get("filename", "")
    sharepoint_file_id = str(message_body.get("sharepointFileId"))
    search_handler.delete_from_index(sharepoint_file_id)
