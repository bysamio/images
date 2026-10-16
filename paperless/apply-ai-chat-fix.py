"""Apply a narrow, source-verified Paperless 3.3.0 chat correction at build time."""
import hashlib
import json
from pathlib import Path
import stat

path = Path('/usr/src/paperless/src/paperless_ai/chat.py')
assert stat.S_ISREG(path.lstat().st_mode)
raw = path.read_bytes()
expected = 'b65bd0547ef722a308ae3c9b575a5c20a13bf4c1ae0ce720f6a53e322125ec5d'
assert hashlib.sha256(raw).hexdigest() == expected, 'Upstream chat source changed; review the patch'
text = raw.decode()
replacements = [
    ('    from llama_index.core.query_engine import RetrieverQueryEngine\n', ''),
    ('''    # Hold the shared read lock for the whole operation: the query engine
    # retrieves from the vector store again during synthesis, so the connection
    # must stay open (and the swap must not run) until the stream finishes.
''', '''    # Keep the existing shared-lock lifetime through streaming. References
    # and synthesis use the same permission-filtered retrieved nodes.
'''),
    ('''        query_engine = RetrieverQueryEngine.from_args(
            retriever=retriever,
            llm=client.llm,
            response_synthesizer=response_synthesizer,
            streaming=True,
        )

''', ''),
    ('            response_stream = query_engine.query(query_str)\n',
     '            response_stream = response_synthesizer.synthesize(query=query_str, nodes=top_nodes)\n'),
]
for before, after in replacements:
    assert text.count(before) == 1, 'Chat patch context changed'
    text = text.replace(before, after, 1)
compile(text, str(path), 'exec')
path.write_text(text)
receipt = {'fix':'reuse_permission_filtered_chat_nodes_for_synthesis', 'upstream_sha256':expected,
           'patched_sha256':hashlib.sha256(text.encode()).hexdigest()}
Path('/usr/share/bysamio/ai-chat-fix.json').write_text(json.dumps(receipt, sort_keys=True) + '\n')
