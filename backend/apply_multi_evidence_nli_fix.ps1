$ErrorActionPreference = "Stop"

$target = Join-Path $PSScriptRoot "app\services\pipeline.py"
$backup = "$target.before_multi_evidence_nli_fix.bak"

if (-not (Test-Path $target)) {
    throw "Could not find app\services\pipeline.py. Place this repair file in C:\DengueProject and run it there."
}

$source = Get-Content $target -Raw -Encoding UTF8

if ($source.Contains('"nli_evidence_rank"')) {
    python -m py_compile $target
    Write-Host "Multi-evidence NLI fix is already installed." -ForegroundColor Green
    exit 0
}

if (-not (Test-Path $backup)) {
    Copy-Item $target $backup
}

$oldBlock = @'
        truth = self.nli.verify(resolved_text, str(best["text"]))
        response["truth"] = truth
        response["answer"] = str(best["text"])
        if truth["label"] == "Needs Review":
            response["status"] = "needs_review"
        return response
'@

$newBlock = @'
        selected_passage = best
        selected_truth = None
        fallback_truth = None
        selected_rank = 1

        # A relevant passage may describe the topic without explicitly proving
        # or contradicting the claim. Check the top three intent-aware passages
        # and use the first decisive NLI result; otherwise keep Needs Review.
        for rank, passage in enumerate(passages[:3], start=1):
            candidate_truth = self.nli.verify(
                resolved_text,
                str(passage["text"]),
            )
            if fallback_truth is None:
                fallback_truth = candidate_truth
            if candidate_truth["label"] != "Needs Review":
                selected_passage = passage
                selected_truth = candidate_truth
                selected_rank = rank
                break

        truth = selected_truth or fallback_truth
        assert truth is not None
        response["truth"] = truth
        response["answer"] = str(selected_passage["text"])
        response["details"] = {
            "nli_evidence_rank": selected_rank,
            "nli_evidence_passage_id": selected_passage.get("passage_id"),
            "nli_passages_checked": min(3, len(passages)),
        }

        selected_id = selected_passage.get("passage_id")
        if selected_rank > 1:
            response["evidence"] = [selected_passage] + [
                passage
                for passage in passages
                if passage.get("passage_id") != selected_id
            ]

        if truth["label"] == "Needs Review":
            response["status"] = "needs_review"
        return response
'@

if (-not $source.Contains($oldBlock)) {
    throw "Expected single-evidence NLI block was not found. No changes were applied."
}

$source = $source.Replace($oldBlock, $newBlock)
Set-Content $target -Value $source -Encoding UTF8

python -m py_compile $target
if ($LASTEXITCODE -ne 0) {
    Copy-Item $backup $target -Force
    throw "Python validation failed. The previous pipeline was restored."
}

Write-Host "MULTI-EVIDENCE NLI FIX APPLIED SUCCESSFULLY" -ForegroundColor Green
Write-Host "Claim verification now checks up to three relevant passages before returning Needs Review."
Write-Host "Restart the API server and repeat the test."
