"""Real disposable ORM checks for 3.3.2 ownerless AI classification scope."""
import os
from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

root = tempfile.TemporaryDirectory(prefix='synthetic-ai-permissions-', dir='/tmp')
for name in ('data', 'media', 'consume', 'scratch'):
    Path(root.name, name).mkdir()
os.environ.update(DJANGO_SETTINGS_MODULE='paperless.settings', PAPERLESS_DBENGINE='sqlite',
    PAPERLESS_SECRET_KEY='synthetic-permission-regression-only', PAPERLESS_AI_ENABLED='false',
    PAPERLESS_DATA_DIR=str(Path(root.name, 'data')), PAPERLESS_MEDIA_ROOT=str(Path(root.name, 'media')),
    PAPERLESS_CONSUMPTION_DIR=str(Path(root.name, 'consume')), PAPERLESS_SCRATCH_DIR=str(Path(root.name, 'scratch')),
    PAPERLESS_CACHE_BACKEND='django.core.cache.backends.locmem.LocMemCache')
sys.path.insert(0, '/usr/src/paperless/src')
import django
django.setup()
from django.core.management import call_command
call_command('migrate', interactive=False, verbosity=0)
from django.contrib.auth.models import User
from documents.models import Document, Tag
from llama_index.core.schema import NodeWithScore, TextNode
import paperless_ai.ai_classifier as classifier


class OwnerlessClassificationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        owner = User.objects.create(username='synthetic-private-owner')
        public = Document(title='PUBLIC_SYNTHETIC_TITLE', content='PUBLIC_SYNTHETIC_CONTENT',
                          checksum='1' * 32, mime_type='application/pdf')
        private = Document(title='PRIVATE_SYNTHETIC_TITLE', content='PRIVATE_SYNTHETIC_CONTENT',
                           owner=owner, checksum='2' * 32, mime_type='application/pdf')
        Document.objects.bulk_create([public, private])  # Avoid external indexing signals.
        public_tag = Tag(name='Public synthetic tag')
        private_tag = Tag(name='Private synthetic tag', owner=owner)
        Tag.objects.bulk_create([public_tag, private_tag])
        Document.tags.through.objects.bulk_create([
            Document.tags.through(document_id=public.pk, tag_id=public_tag.pk),
            Document.tags.through(document_id=private.pk, tag_id=private_tag.pk),
        ])
        cls.public, cls.private, cls.public_tag = public, private, public_tag

    def assert_public_scope(self, candidates, context):
        self.assertIn(self.public.content, context)
        self.assertNotIn(self.private.content, context)
        self.assertNotIn(self.private.title, context)
        self.assertEqual([item['id'] for item in candidates['tags']], [self.public_tag.pk])

    def test_ownerless_vector_workflow_excludes_private_documents_and_taxonomy_even_for_stale_nodes(self):
        nodes = [NodeWithScore(node=TextNode(text='synthetic', metadata={'document_id': str(doc.pk)}), score=0.9)
                 for doc in (self.private, self.public)]
        with patch.object(classifier, 'AIConfig', return_value=SimpleNamespace(llm_embedding_backend='ollama')), \
                patch.object(classifier, 'retrieve_similar_nodes', return_value=nodes) as retrieve:
            candidates, context = classifier.get_taxonomy_context(self.public, user=None)
        self.assertEqual(set(retrieve.call_args.kwargs['document_ids']), {self.public.pk})
        self.assert_public_scope(candidates, context)

    def test_ownerless_fulltext_fallback_rechecks_private_results_from_stale_index(self):
        backend = MagicMock()
        backend.more_like_this_ids.return_value = [self.private.pk, self.public.pk]
        with patch.object(classifier, 'AIConfig', return_value=SimpleNamespace(llm_embedding_backend=None)), \
                patch('documents.search.get_backend', return_value=backend):
            candidates, context = classifier.get_taxonomy_context(self.public, user=None)
        self.assert_public_scope(candidates, context)


if __name__ == '__main__':
    unittest.main()
