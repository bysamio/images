"""Source-verified complete classification budget and matching chat tokenizer."""
import hashlib
import json
from pathlib import Path

receipt = {}
root = Path('/usr/src/paperless/src/paperless_ai')


def apply(name, expected, replacements):
    path = root / name
    raw = path.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == expected, 'Upstream AI source changed; review the context patch'
    text = raw.decode()
    for before, after in replacements:
        assert text.count(before) == 1, 'AI context patch changed'
        text = text.replace(before, after, 1)
    compile(text, str(path), 'exec')
    path.write_text(text)
    receipt[name] = {'upstream_sha256':expected, 'patched_sha256':hashlib.sha256(text.encode()).hexdigest()}


apply('ai_classifier.py', '943c5b1e2dab0486fa9edc1221644af7a06347db210842d6edd211ea3d4a7546', [
    ('''def build_prompt_with_rag(
    document: Document,
    config: AIConfig,
    candidates: TaxonomyCandidates | None = None,
    context: str = "",
) -> str:
    base_prompt = build_prompt_without_rag(
        document,
        config,
        candidates=candidates,
    )
    truncated_context = truncate_content(
        context,
        chunk_size=config.llm_embedding_chunk_size,
        context_size=config.llm_context_size,
    )

    return render_prompt(
        RagContextPromptContext(
            base_prompt=base_prompt,
            context=truncated_context,
        ),
    )
''', '''def build_prompt_with_rag(
    document: Document,
    config: AIConfig,
    candidates: TaxonomyCandidates | None = None,
    context: str = "",
) -> str:
    from paperless_ai.token_budget import fit_classification_prompt

    taxonomy_block = format_taxonomy_for_prompt(candidates) if candidates is not None else ""
    has_candidates = candidates is not None and any(candidates.values())

    def render(content, related):
        base = render_prompt(
            ClassificationPromptContext(
                filename=document.filename or "",
                content=content,
                taxonomy_block=taxonomy_block,
                has_candidates=has_candidates,
            ),
        )
        return render_prompt(RagContextPromptContext(base_prompt=base, context=related))

    return fit_classification_prompt(render, config, document.content[:4000] or "", context)
'''),
])

apply('chat.py', 'c260d912a1af37ebfad9ba30cb66bca2627dbcff42fb21ddeafecaa1d433b364', [
    ('''                chunk_size=config.llm_embedding_chunk_size,
''', '''                # Generation packing uses available answer context, independently
                # of index chunks. Leave room for provider-specific chat framing.
                chunk_size=config.llm_context_size,
'''),
    ('''from paperless_ai.indexing import read_store
''', '''from paperless_ai.indexing import read_store
from paperless_ai.token_budget import generation_tokenizer
'''),
    ('''                context_size=config.llm_context_size,
            ),
            text_qa_template=''', '''                context_size=config.llm_context_size - 256,
                tokenizer=generation_tokenizer(config),
            ),
            text_qa_template='''),
])

apply('indexing.py', '62464ad25734396bfd4432a25ba69893d9ebe399e368d417561f8b4ccf28f233', [
    ('''def get_rag_prompt_helper(
    *,
    chunk_size: int | None = None,
    context_size: int | None = None,
):''', '''def get_rag_prompt_helper(
    *,
    chunk_size: int | None = None,
    context_size: int | None = None,
    tokenizer=None,
):'''),
    ('''        chunk_size_limit=chunk_size,
    )''', '''        chunk_size_limit=chunk_size,
        tokenizer=tokenizer,
    )'''),
])

Path('/usr/share/bysamio/ai-context-fix.json').write_text(json.dumps(receipt, sort_keys=True) + '\n')
