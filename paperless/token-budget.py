"""Local generation token budgeting; no model calls, downloads or prompt logs."""
from functools import lru_cache
import hashlib
import json
from pathlib import Path

from paperless_ai.exceptions import LLMProviderError

QWEN_MODEL = 'qwen3:4b-instruct-2507-q4_K_M'
QWEN_SHA256 = 'aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4'


@lru_cache(maxsize=1)
def _qwen_tokenizer():
    from tokenizers import Tokenizer
    raw = Path('/usr/share/bysamio/qwen3-4b-tokenizer.json').read_bytes()
    if len(raw) != 11422654 or hashlib.sha256(raw).hexdigest() != QWEN_SHA256:
        raise LLMProviderError('Verified local generation tokenizer unavailable')
    return Tokenizer.from_str(raw.decode())


def generation_tokenizer(config):
    if getattr(config, 'llm_backend', None) == 'ollama' and getattr(config, 'llm_model', None) == QWEN_MODEL:
        tokenizer = _qwen_tokenizer()
        return lambda text: tokenizer.encode(text, add_special_tokens=False).ids
    from llama_index.core.utils import get_tokenizer
    return get_tokenizer()


def fit_classification_prompt(render, config, content, context):
    from paperless_ai.base_model import DocumentClassifierSchema
    from paperless_ai.client import LLM_SYSTEM_PROMPT
    tokenize = generation_tokenizer(config)
    schema = json.dumps(DocumentClassifierSchema.model_json_schema(), ensure_ascii=False, separators=(',', ':'))
    # Count every rendered prompt component. Reserve 512 output tokens and 256
    # for chat framing/provider formatting beyond the explicit system/schema.
    overhead = len(tokenize(LLM_SYSTEM_PROMPT)) + len(tokenize(schema)) + 768
    budget = config.llm_context_size - overhead
    if budget <= 0 or len(tokenize(render('', ''))) > budget:
        raise LLMProviderError('AI context cannot fit fixed classification instructions')

    def fits(prompt):
        return len(tokenize(prompt)) <= budget

    def bounded_prefix(value, render_prefix):
        low, high, best = 0, len(value), ''
        while low <= high:
            middle = (low + high) // 2
            prefix = value[:middle]  # Never split a Unicode character.
            if fits(render_prefix(prefix)):
                best, low = prefix, middle + 1
            else:
                high = middle - 1
        return render_prefix(best)

    full = render(content, context)
    if fits(full):
        return full
    if fits(render(content, '')):
        return bounded_prefix(context, lambda value: render(content, value))
    # Prefer the document being classified to related-document enrichment.
    return bounded_prefix(content, lambda value: render(value, ''))
