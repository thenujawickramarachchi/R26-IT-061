$ErrorActionPreference = "Stop"

$target = Join-Path $PSScriptRoot "app\services\rag.py"
$backup = "$target.before_intent_aware_fix.bak"

if (-not (Test-Path $target)) {
    throw "Could not find app\services\rag.py. Place this repair file in C:\DengueProject and run it there."
}

$source = Get-Content $target -Raw -Encoding UTF8

if ($source.Contains("intent_labels =")) {
    python -m py_compile $target
    Write-Host "Intent-aware multilingual RAG fix is already installed." -ForegroundColor Green
    exit 0
}

if (-not (Test-Path $backup)) {
    Copy-Item $target $backup
}

$oldBlock = @'
        scores = self._embeddings @ query_vector
        candidate_indices = self._np.arange(len(self._corpus))
        if preferred_language and "language" in self._corpus.columns:
            corpus_languages = (
                self._corpus["language"].astype(str).str.casefold().to_numpy()
            )
            matching_indices = self._np.flatnonzero(
                corpus_languages == preferred_language.casefold()
            )
            if len(matching_indices):
                candidate_indices = matching_indices

        ordered_positions = self._np.argsort(-scores[candidate_indices])[:top_k]
        indices = candidate_indices[ordered_positions]
'@

$newBlock = @'
        scores = self._embeddings @ query_vector
        ordered_indices = self._np.argsort(-scores)
        indices = ordered_indices[:top_k]

        if (
            preferred_language
            and "language" in self._corpus.columns
            and "intent_label" in self._corpus.columns
        ):
            corpus_languages = (
                self._corpus["language"].astype(str).str.casefold().to_numpy()
            )
            intent_labels = (
                self._corpus["intent_label"].astype(str).str.casefold().to_numpy()
            )
            preferred_key = preferred_language.casefold()
            selected_indices: list[int] = []

            # Use cross-language semantic ranking to identify the intent, then
            # select the strongest passage for that intent in the requested language.
            for global_index in ordered_indices:
                global_index = int(global_index)
                intent_key = intent_labels[global_index]
                matching_indices = self._np.flatnonzero(
                    (corpus_languages == preferred_key)
                    & (intent_labels == intent_key)
                )
                if not len(matching_indices):
                    continue
                best_match = int(
                    matching_indices[self._np.argmax(scores[matching_indices])]
                )
                if best_match not in selected_indices:
                    selected_indices.append(best_match)
                if len(selected_indices) >= top_k:
                    break

            # Fill any remaining evidence slots with the best passages in the
            # requested language, while keeping the intent-matched result first.
            if len(selected_indices) < top_k:
                for global_index in ordered_indices:
                    global_index = int(global_index)
                    if (
                        corpus_languages[global_index] == preferred_key
                        and global_index not in selected_indices
                    ):
                        selected_indices.append(global_index)
                    if len(selected_indices) >= top_k:
                        break

            if selected_indices:
                indices = self._np.asarray(selected_indices[:top_k], dtype=int)
'@

if (-not $source.Contains($oldBlock)) {
    throw "Expected strict-language RAG block was not found. Apply the language-matched RAG fix first."
}

$source = $source.Replace($oldBlock, $newBlock)
Set-Content $target -Value $source -Encoding UTF8

python -m py_compile $target
if ($LASTEXITCODE -ne 0) {
    Copy-Item $backup $target -Force
    throw "Python validation failed. The previous RAG implementation was restored."
}

Write-Host "INTENT-AWARE MULTILINGUAL RAG FIX APPLIED SUCCESSFULLY" -ForegroundColor Green
Write-Host "Semantic relevance is detected across languages, then mapped to the requested answer language."
Write-Host "Restart the API server and repeat the test."
