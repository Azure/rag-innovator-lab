from ..env_helper import EnvHelper
from ..azure_blob_storage_client import AzureBlobStorageClient
from .push_embedder import PushEmbedder


class EmbedderFactory:
    @staticmethod
    def create(env_helper: EnvHelper):
        return PushEmbedder(AzureBlobStorageClient(), env_helper)
