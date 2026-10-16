"""Real retrieval/synthesis on synthetic RAM state; no model or production data."""
import contextlib
import json
import os
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

sys.path.insert(0, '/usr/src/paperless/src')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'paperless.settings')
os.environ.setdefault('PAPERLESS_SECRET_KEY', 'synthetic-offline-chat-regression')
import django
django.setup()
from llama_index.core import VectorStoreIndex
from llama_index.core.embeddings import MockEmbedding
from llama_index.core.llms import MockLLM
from llama_index.core.schema import TextNode
import paperless_ai.chat as chat
from paperless_ai.vector_store import PaperlessSqliteVecVectorStore


class CountingEmbedding(MockEmbedding):
    query_calls: int = 0

    def _get_query_embedding(self, query):
        self.query_calls += 1
        return super()._get_query_embedding(query)


class CountingLLM(MockLLM):
    generation_calls: int = 0

    def stream_complete(self, prompt, formatted=False, **kwargs):
        self.generation_calls += 1
        return super().stream_complete(prompt, formatted=formatted, **kwargs)


class ChatRegressionTests(unittest.TestCase):
    def test_one_query_embedding_preserves_permitted_context_stream_and_citations(self):
        for unrestricted in (False, True):
            with self.subTest(unrestricted=unrestricted), tempfile.TemporaryDirectory(dir='/tmp') as folder, \
                    PaperlessSqliteVecVectorStore(uri=folder, embed_model_name='synthetic') as store:
                embedding = CountingEmbedding(embed_dim=1024)
                nodes = [
                    TextNode(text='PERMITTED_SYNTHETIC_FACT ' + 'Synthetic invoice item. ' * 180, metadata={'document_id':'1', 'title':'Synthetic allowed'}),
                    TextNode(text='SECOND_PERMITTED_FACT ' + 'Synthetic statement item. ' * 180, metadata={'document_id':'1', 'title':'Synthetic allowed'}),
                    TextNode(text='FORBIDDEN_SYNTHETIC_FACT', metadata={'document_id':'2', 'title':'Synthetic excluded'}),
                ]
                for node in nodes:
                    node.metadata['modified'] = '2026-10-16T12:00:00+00:00'
                    node.embedding = embedding.get_text_embedding(node.text)
                store.add(nodes)
                index = VectorStoreIndex.from_vector_store(vector_store=store, embed_model=embedding)
                doc = SimpleNamespace(pk=1, title='Synthetic allowed', filename='synthetic.pdf')
                documents = MagicMock(); documents.exists.return_value = True
                documents.values_list.return_value = [1]; documents.filter.return_value = [doc]
                llm = CountingLLM()
                config = SimpleNamespace(llm_embedding_chunk_size=1024, llm_context_size=4096,
                                         llm_backend='ollama', llm_model='qwen3:4b-instruct-2507-q4_K_M')
                with patch.object(chat, 'read_store', return_value=contextlib.nullcontext(store)), \
                        patch.object(chat, 'load_or_build_index', return_value=index), \
                        patch.object(chat, 'AIConfig', return_value=config), \
                        patch.object(chat, 'AIClient', return_value=SimpleNamespace(llm=llm)), \
                        patch.object(chat, 'db_connection_released', side_effect=lambda: contextlib.nullcontext()), \
                        patch.object(chat.Document.deleted_objects, 'values_list', return_value=[2]):
                    result = ''.join(chat.stream_chat_with_documents('Return the permitted fact.', documents, unrestricted=unrestricted))
                self.assertNotEqual(result, chat.CHAT_ERROR_MESSAGE)
                self.assertIn('PERMITTED_SYNTHETIC_FACT', result)
                self.assertIn('SECOND_PERMITTED_FACT', result)
                self.assertNotIn('FORBIDDEN_SYNTHETIC_FACT', result)
                answer, metadata = result.split(chat.CHAT_METADATA_DELIMITER)
                self.assertTrue(answer)
                self.assertEqual(json.loads(metadata), {'references':[{'id':1,'title':'Synthetic allowed'}]})
                self.assertEqual((embedding.query_calls, llm.generation_calls), (1, 1),
                                 'One retrieval and one generation should serve evidence fitting the answer context')


if __name__ == '__main__':
    unittest.main()
