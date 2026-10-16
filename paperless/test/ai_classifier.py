"""Full rendered classification budget with the pinned generation tokenizer."""
import hashlib
import json
import os
from pathlib import Path
import sys
import unittest
from types import SimpleNamespace

sys.path.insert(0, '/usr/src/paperless/src')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'paperless.settings')
os.environ.setdefault('PAPERLESS_SECRET_KEY', 'synthetic-offline-classification-budget')
import django
django.setup()
from tokenizers import Tokenizer
from paperless_ai.ai_classifier import build_prompt_with_rag
from paperless_ai.base_model import DocumentClassifierSchema
from paperless_ai.client import LLM_SYSTEM_PROMPT
from paperless_ai.exceptions import LLMProviderError
from paperless_ai.taxonomy import empty_taxonomy_candidates, format_taxonomy_for_prompt

path = Path(os.getenv('BYSAM_TEST_TOKENIZER_PATH', '/usr/share/bysamio/qwen3-4b-tokenizer.json'))
assert hashlib.sha256(path.read_bytes()).hexdigest() == 'aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4'
tokenizer = Tokenizer.from_file(str(path))
schema = json.dumps(DocumentClassifierSchema.model_json_schema(), ensure_ascii=False, separators=(',', ':'))


def config(size):
    return SimpleNamespace(llm_backend='ollama', llm_model='qwen3:4b-instruct-2507-q4_K_M',
                           llm_context_size=size, llm_embedding_chunk_size=1024)


def total_tokens(prompt):
    return sum(len(tokenizer.encode(text, add_special_tokens=False).ids) for text in (prompt, LLM_SYSTEM_PROMPT, schema)) + 768


class ClassificationBudgetTests(unittest.TestCase):
    def test_full_prompt_including_schema_system_and_output_fits_4096_and_8192(self):
        candidates = empty_taxonomy_candidates()
        candidates['tags'] = [{'id':101, 'name':'Synthetic invoice', 'weight':1.0}]
        candidates['document_types'] = [{'id':201, 'name':'Synthetic statement', 'weight':1.0}]
        for size in (4096, 8192):
            for language in ('Invoice amount 125 EUR. ', 'Rechnung über Gebühren und Beiträge. ', '发票金额 125 欧元。 '):
                with self.subTest(size=size, language=language):
                    doc = SimpleNamespace(filename='synthetic.pdf', content='PRIMARY_FACT_8675309 ' + language * 100)
                    prompt = build_prompt_with_rag(doc, config(size), candidates=candidates, context=language * 1500)
                    self.assertLessEqual(total_tokens(prompt), size)
                    self.assertIn('PRIMARY_FACT_8675309', prompt)
                    self.assertIn(format_taxonomy_for_prompt(candidates), prompt)
                    self.assertNotIn('\ufffd', prompt)

    def test_short_input_keeps_all_primary_and_related_evidence(self):
        doc = SimpleNamespace(filename='synthetic.pdf', content='PRIMARY_SHORT_FACT')
        prompt = build_prompt_with_rag(doc, config(4096), context='RELATED_SHORT_FACT')
        self.assertIn(doc.content, prompt); self.assertIn('RELATED_SHORT_FACT', prompt)
        self.assertLessEqual(total_tokens(prompt), 4096)

    def test_impossible_fixed_overhead_fails_before_model_request_without_private_text(self):
        doc = SimpleNamespace(filename='PRIVATE_SYNTHETIC_NAME.pdf', content='PRIVATE_SYNTHETIC_BODY')
        with self.assertRaises(LLMProviderError) as captured:
            build_prompt_with_rag(doc, config(512), context='PRIVATE_SYNTHETIC_CONTEXT')
        self.assertNotIn('PRIVATE', str(captured.exception))


if __name__ == '__main__':
    unittest.main()
