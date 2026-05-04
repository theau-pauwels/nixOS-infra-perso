"""OpenAI-compatible provider (kept for fallback)."""
import json
import logging
import time
import urllib.request
import urllib.error
from typing import Optional

from .base import LLMProvider, LLMResponse, LLMError

logger = logging.getLogger(__name__)

DEFAULT_OPENAI_BASE = "https://api.openai.com"


class OpenAICompatProvider(LLMProvider):
    def __init__(
        self,
        api_key: str,
        base_url: str = DEFAULT_OPENAI_BASE,
        model_summary: str = "gpt-4.1-mini",
        model_reasoning: str = "gpt-4.1",
        model_drafts: str = "gpt-4.1-mini",
        timeout: int = 60,
        retry_count: int = 3,
    ):
        if not api_key:
            raise LLMError("OPENAI_API_KEY is not set")
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.model_summary = model_summary
        self.model_reasoning = model_reasoning
        self.model_drafts = model_drafts
        self.timeout = timeout
        self.retry_count = retry_count

    def _model_for(self, task: str) -> str:
        if task == "reasoning":
            return self.model_reasoning
        if task in ("draft", "drafts"):
            return self.model_drafts
        return self.model_summary

    def generate(self, prompt: str, system_prompt: str = "", task: str = "summary") -> LLMResponse:
        model = self._model_for(task)
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})

        body = json.dumps({
            "model": model,
            "messages": messages,
            "max_tokens": 16384,
            "temperature": 0.3 if task in ("summary", "extract") else 0.7,
        }).encode("utf-8")

        url = f"{self.base_url}/v1/chat/completions"
        last_error = None
        for attempt in range(1, self.retry_count + 1):
            try:
                req = urllib.request.Request(url, data=body, method="POST")
                req.add_header("Content-Type", "application/json")
                req.add_header("Authorization", f"Bearer {self.api_key}")
                with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                    data = json.loads(resp.read().decode())
                    choice = data.get("choices", [{}])[0]
                    content = choice.get("message", {}).get("content", "")
                    return LLMResponse(content=content.strip(), model=data.get("model", model))

            except urllib.error.HTTPError as e:
                status = e.code
                logger.error("OpenAI HTTP %s (attempt %s/%s)", status, attempt, self.retry_count)
                if status == 401:
                    raise LLMError("OpenAI API key invalid (401)") from e
                if status == 429:
                    last_error = LLMError("OpenAI rate limit reached")
                    if attempt < self.retry_count:
                        time.sleep(2 ** attempt)
                    continue
                last_error = LLMError(f"OpenAI HTTP {status}")

            except (urllib.error.URLError, TimeoutError, OSError) as e:
                logger.error("OpenAI network error: %s", e)
                last_error = LLMError(f"OpenAI network/timeout: {e}")
                if attempt < self.retry_count:
                    time.sleep(2 ** attempt)
                continue

        if last_error:
            raise last_error
        raise LLMError("OpenAI call failed after retries")
