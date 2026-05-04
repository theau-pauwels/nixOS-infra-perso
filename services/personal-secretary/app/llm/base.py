"""Base LLM provider interface."""
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional


class LLMError(Exception):
    """Generic LLM error — safe to log, never contains API keys."""
    pass


@dataclass
class LLMResponse:
    content: str
    model: str
    finish_reason: Optional[str] = None


class LLMProvider(ABC):
    @abstractmethod
    def generate(
        self,
        prompt: str,
        system_prompt: str = "",
        task: str = "summary",
    ) -> LLMResponse:
        """Generate a completion. `task` picks the model variant."""
        ...
