import logging
from openai import AzureOpenAI
from typing import List, Union
from langchain_openai import AzureChatOpenAI, AzureOpenAIEmbeddings
from langchain.callbacks.streaming_stdout import StreamingStdOutCallbackHandler
from azure.ai.ml import MLClient
from azure.identity import DefaultAzureCredential
from .env_helper import EnvHelper

logger = logging.getLogger(__name__)


class LLMHelper:
    def __init__(self):
        logger.info("Initializing LLMHelper")
        self.env_helper: EnvHelper = EnvHelper()
        self.auth_type_keys = self.env_helper.is_auth_type_keys()
        self.token_provider = self.env_helper.AZURE_TOKEN_PROVIDER
        logger.info(self.auth_type_keys)
        logger.info(self.env_helper.OPENAI_API_KEY)

        if self.auth_type_keys:
            self.openai_client = AzureOpenAI(
                azure_endpoint=self.env_helper.AZURE_OPENAI_ENDPOINT,
                api_version=self.env_helper.AZURE_OPENAI_API_VERSION,
                api_key=self.env_helper.OPENAI_API_KEY,
            )
        else:
            self.openai_client = AzureOpenAI(
                azure_endpoint=self.env_helper.AZURE_OPENAI_ENDPOINT,
                api_version=self.env_helper.AZURE_OPENAI_API_VERSION,
                azure_ad_token_provider=self.token_provider,
            )

        self.llm_model = self.env_helper.AZURE_OPENAI_MODEL
        self.llm_max_tokens = (
            int(self.env_helper.AZURE_OPENAI_MAX_TOKENS)
            if self.env_helper.AZURE_OPENAI_MAX_TOKENS != ""
            else None
        )
        self.embedding_model = self.env_helper.AZURE_OPENAI_EMBEDDING_MODEL
        logger.info(self.openai_client)
        logger.info(self.embedding_model)
        logger.info("Initializing LLMHelper completed")

    def get_llm(self):
        if self.auth_type_keys:
            return AzureChatOpenAI(
                deployment_name=self.llm_model,
                temperature=0,
                max_tokens=self.llm_max_tokens,
                openai_api_version=self.openai_client._api_version,
                azure_endpoint=self.env_helper.AZURE_OPENAI_ENDPOINT,
                api_key=self.env_helper.OPENAI_API_KEY,
            )
        else:
            return AzureChatOpenAI(
                deployment_name=self.llm_model,
                temperature=0,
                max_tokens=self.llm_max_tokens,
                openai_api_version=self.openai_client._api_version,
                azure_endpoint=self.env_helper.AZURE_OPENAI_ENDPOINT,
                azure_ad_token_provider=self.token_provider,
            )

    # TODO: This needs to have a custom callback to stream back to the UI
    def get_streaming_llm(self):
        if self.auth_type_keys:
            return AzureChatOpenAI(
                azure_endpoint=self.env_helper.AZURE_OPENAI_ENDPOINT,
                api_key=self.env_helper.OPENAI_API_KEY,
                streaming=True,
                callbacks=[StreamingStdOutCallbackHandler],
                deployment_name=self.llm_model,
                temperature=0,
                max_tokens=self.llm_max_tokens,
                openai_api_version=self.openai_client._api_version,
            )
        else:
            return AzureChatOpenAI(
                azure_endpoint=self.env_helper.AZURE_OPENAI_ENDPOINT,
                api_key=self.env_helper.OPENAI_API_KEY,
                streaming=True,
                callbacks=[StreamingStdOutCallbackHandler],
                deployment_name=self.llm_model,
                temperature=0,
                max_tokens=self.llm_max_tokens,
                openai_api_version=self.openai_client._api_version,
                azure_ad_token_provider=self.token_provider,
            )

    def get_embedding_model(self):
        if self.auth_type_keys:
            return AzureOpenAIEmbeddings(
                azure_endpoint=self.env_helper.AZURE_OPENAI_ENDPOINT,
                api_key=self.env_helper.OPENAI_API_KEY,
                azure_deployment=self.embedding_model,
                chunk_size=1,
            )
        else:
            return AzureOpenAIEmbeddings(
                azure_endpoint=self.env_helper.AZURE_OPENAI_ENDPOINT,
                azure_deployment=self.embedding_model,
                chunk_size=1,
                azure_ad_token_provider=self.token_provider,
            )

    def generate_embeddings(self, input: Union[str, list[int]]) -> List[float]:
        return (
            self.openai_client.embeddings.create(
                input=[input], model=self.embedding_model
            )
            .data[0]
            .embedding
        )

    def get_chat_completion_with_functions(
        self, messages: list[dict], functions: list[dict], function_call: str = "auto"
    ):
        return self.openai_client.chat.completions.create(
            model=self.llm_model,
            messages=messages,
            functions=functions,
            function_call=function_call,
        )

    def get_chat_completion(
        self, messages: list[dict], model: str | None = None, **kwargs
    ):
        return self.openai_client.chat.completions.create(
            model=model or self.llm_model,
            messages=messages,
            max_tokens=self.llm_max_tokens,
            **kwargs
        )


    def get_ml_client(self):
        if not hasattr(self, "_ml_client"):
            self._ml_client = MLClient(
                DefaultAzureCredential(),
                self.env_helper.AZURE_SUBSCRIPTION_ID,
                self.env_helper.AZURE_RESOURCE_GROUP,
                self.env_helper.AZURE_ML_WORKSPACE_NAME,
            )
        return self._ml_client
