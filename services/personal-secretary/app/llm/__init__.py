"""LLM abstraction layer — provider-agnostic interface."""
from .base import LLMProvider, LLMError
from .deepseek import DeepSeekProvider

_provider: LLMProvider | None = None


def get_provider() -> LLMProvider:
    """Get or create the configured LLM provider."""
    global _provider
    if _provider is not None:
        return _provider
    from .. import config
    if config.LLM_PROVIDER == "deepseek":
        _provider = DeepSeekProvider(
            api_key=config.DEEPSEEK_API_KEY,
            base_url=config.DEEPSEEK_BASE_URL,
            model_summary=config.DEEPSEEK_MODEL_SUMMARY,
            model_reasoning=config.DEEPSEEK_MODEL_REASONING,
            model_drafts=config.DEEPSEEK_MODEL_DRAFTS,
        )
    elif config.LLM_PROVIDER == "openai":
        from .openai_compat import OpenAICompatProvider
        _provider = OpenAICompatProvider(
            api_key=config.OPENAI_API_KEY,
            model_summary=config.OPENAI_MODEL_SUMMARY,
            model_reasoning=config.OPENAI_MODEL_REASONING,
            model_drafts=config.OPENAI_MODEL_DRAFTS,
        )
    else:
        raise LLMError(f"Unknown LLM_PROVIDER: {config.LLM_PROVIDER}")
    return _provider
