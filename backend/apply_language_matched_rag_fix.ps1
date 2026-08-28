$ErrorActionPreference = "Stop"

$ragTarget = Join-Path $PSScriptRoot "app\services\rag.py"
$pipelineTarget = Join-Path $PSScriptRoot "app\services\pipeline.py"
$ragBackup = "$ragTarget.before_language_fix.bak"
$pipelineBackup = "$pipelineTarget.before_language_fix.bak"

foreach ($target in @($ragTarget, $pipelineTarget)) {
    if (-not (Test-Path $target)) {
        throw "Could not find $target. Place this repair file in C:\DengueProject and run it there."
    }
}

$ragSource = Get-Content $ragTarget -Raw -Encoding UTF8
$pipelineSource = Get-Content $pipelineTarget -Raw -Encoding UTF8

if (
    $ragSource.Contains("preferred_language: str | None = None") -and
    $pipelineSource.Contains("self.rag.retrieve(resolved_text, top_k, language)")
) {
    python -m py_compile $ragTarget $pipelineTarget
    Write-Host "Language-matched RAG fix is already installed." -ForegroundColor Green
    exit 0
}

if (-not (Test-Path $ragBackup)) {
    Copy-Item $ragTarget $ragBackup
}
if (-not (Test-Path $pipelineBackup)) {
    Copy-Item $pipelineTarget $pipelineBackup
}

$oldSignature = '    def retrieve(self, query: str, top_k: int) -> list[dict[str, object]]:'
$newSignature = @'
    def retrieve(
        self,
        query: str,
        top_k: int,
        preferred_language: str | None = None,
    ) -> list[dict[str, object]]:
'@

$oldRanking = @'
        scores = self._embeddings @ query_vector
        indices = self._np.argsort(-scores)[:top_k]
'@
$newRanking = @'
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

$oldPipelineCall = 'passages = self.rag.retrieve(resolved_text, top_k)'
$newPipelineCall = 'passages = self.rag.retrieve(resolved_text, top_k, language)'

if (-not $ragSource.Contains($oldSignature)) {
    throw "Expected RAG method signature was not found. No changes were applied."
}
if (-not $ragSource.Contains($oldRanking)) {
    throw "Expected RAG ranking block was not found. No changes were applied."
}
if (-not $pipelineSource.Contains($oldPipelineCall)) {
    throw "Expected pipeline RAG call was not found. Apply the multi-turn fix first."
}

$ragSource = $ragSource.Replace($oldSignature, $newSignature)
$ragSource = $ragSource.Replace($oldRanking, $newRanking)
$pipelineSource = $pipelineSource.Replace($oldPipelineCall, $newPipelineCall)

Set-Content $ragTarget -Value $ragSource -Encoding UTF8
Set-Content $pipelineTarget -Value $pipelineSource -Encoding UTF8

python -m py_compile $ragTarget $pipelineTarget
if ($LASTEXITCODE -ne 0) {
    Copy-Item $ragBackup $ragTarget -Force
    Copy-Item $pipelineBackup $pipelineTarget -Force
    throw "Python validation failed. The original files were restored."
}

Write-Host "LANGUAGE-MATCHED RAG FIX APPLIED SUCCESSFULLY" -ForegroundColor Green
Write-Host "Sinhala requests now prefer Sinhala corpus passages."
Write-Host "Singlish requests now prefer Singlish corpus passages."
Write-Host "English requests now prefer English corpus passages."
Write-Host "Restart the API server and repeat the test."
