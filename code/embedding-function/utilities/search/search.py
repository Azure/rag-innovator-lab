from ..search.azure_search_handler import AzureSearchHandler
from ..search.search_handler_base import SearchHandlerBase
from ..common.source_document import SourceDocument
from ..helpers.env_helper import EnvHelper


class Search:
    @staticmethod
    def get_search_handler(env_helper: EnvHelper) -> SearchHandlerBase:
        return AzureSearchHandler(env_helper)

    @staticmethod
    def get_source_documents(
        search_handler: SearchHandlerBase, question: str
    ) -> list[SourceDocument]:
        return search_handler.query_search(question)
