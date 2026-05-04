"""DeepSeek API provider — OpenAI-compatible Chat Completions endpoint."""
import json
import logging
import time
import urllib.request
import urllib.error
from typing import Optional

from .base import LLMProvider, LLMResponse, LLMError

logger = logging.getLogger(__name__)


class DeepSeekProvider(LLMProvider):
    def __init__(
        self,
        api_key: str,
        base_url: str = "https://api.deepseek.com",
        model_summary: str = "deepseek-chat",
        model_reasoning: str = "deepseek-reasoner",
        model_drafts: str = "deepseek-chat",
        timeout: int = 60,
        retry_count: int = 3,
    ):
        if not api_key:
            raise LLMError("DEEPSEEK_API_KEY is not set")
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

    def generate(
        self,
        prompt: str,
        system_prompt: str = "",
        task: str = "summary",
    ) -> LLMResponse:
        model = self._model_for(task)
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})

        body = json.dumps({
            "model": model,
            "messages": messages,
            "max_tokens": 8192,
            "temperature": 0.3 if task in ("summary", "extract") else 0.7,
        }).encode("utf-8")

        url = f"{self.base_url}/v1/chat/completions"

        last_error = None
        for attempt in range(1, self.retry_count + 1):
            try:
                req = urllib.request.Request(url, data=body, method="POST")
                req.add_header("Content-Type", "application/json")
                req.add_header("Authorization", f"Bearer {self.api_key}")
                req.add_header("Accept", "application/json")

                with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                    data = json.loads(resp.read().decode())
                    choice = data.get("choices", [{}])[0]
                    content = choice.get("message", {}).get("content", "")
                    finish = choice.get("finish_reason", "stop")
                    return LLMResponse(
                        content=content.strip(),
                        model=data.get("model", model),
                        finish_reason=finish,
                    )

            except urllib.error.HTTPError as e:
                status = e.code
                body_text = ""
                try:
                    body_text = e.read().decode()[:500]
                except Exception:
                    pass
                logger.error(
                    "DeepSeek HTTP %s (attempt %s/%s): %s",
                    status, attempt, self.retry_count, body_text,
                )
                if status == 401:
                    raise LLMError("DeepSeek API key invalid (401)") from e
                if status == 429:
                    last_error = LLMError("DeepSeek rate limit reached (429)")
                    if attempt < self.retry_count:
                        time.sleep(2 ** attempt)
                    continue
                if 500 <= status < 600:
                    last_error = LLMError(f"DeepSeek server error ({status})")
                    if attempt < self.retry_count:
                        time.sleep(2 ** attempt)
                    continue
                last_error = LLMError(f"DeepSeek HTTP {status}")

            except (urllib.error.URLError, TimeoutError, OSError) as e:
                logger.error("DeepSeek network error (attempt %s/%s): %s",
                             attempt, self.retry_count, e)
                last_error = LLMError(f"DeepSeek network/timeout error: {e}")
                if attempt < self.retry_count:
                    time.sleep(2 ** attempt)
                continue

            except json.JSONDecodeError as e:
                logger.error("DeepSeek invalid JSON response: %s", e)
                raise LLMError("DeepSeek returned invalid JSON") from e

        if last_error:
            raise last_error
        raise LLMError("DeepSeek call failed after retries")
