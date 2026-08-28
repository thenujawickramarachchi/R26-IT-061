$ErrorActionPreference = "Stop"

$target = Join-Path $PSScriptRoot "app\services\pipeline.py"
$backup = "$target.before_multiturn_fix.bak"

if (-not (Test-Path $target)) {
    throw "Could not find app\services\pipeline.py. Place this file in C:\DengueProject and run it there."
}

$source = Get-Content $target -Raw -Encoding UTF8

if ($source.Contains("language = self.detect_language(resolved_text, language)")) {
    python -m py_compile $target
    Write-Host "Multi-turn context fix is already installed." -ForegroundColor Green
    exit 0
}

if (-not (Test-Path $backup)) {
    Copy-Item $target $backup
}

$initialPattern = '(?m)^        request_id = str\(uuid\.uuid4\(\)\)\r?\n        language = self\.detect_language\(text, language\)'
$initialReplacement = @'
        request_id = str(uuid.uuid4())
        resolved_text = (
            f"{previous_context.strip()} {text.strip()}"
            if previous_context and previous_context.strip()
            else text
        )
        language = self.detect_language(resolved_text, language)
'@

if ([regex]::Matches($source, $initialPattern).Count -ne 1) {
    throw "The expected pipeline version was not found. No changes were applied."
}

$source = [regex]::Replace($source, $initialPattern, $initialReplacement)

$replacements = [ordered]@{
    'self._looks_numeric(text)' = 'self._looks_numeric(resolved_text)'
    'self.numeric.check(text)' = 'self.numeric.check(resolved_text)'
    'self._looks_severity_report(text)' = 'self._looks_severity_report(resolved_text)'
    'self.severity_classifier.predict(text)' = 'self.severity_classifier.predict(resolved_text)'
    'self.rag.retrieve(text, top_k)' = 'self.rag.retrieve(resolved_text, top_k)'
    'is_question = self._looks_question(text)' = 'is_question = self._looks_question(resolved_text)'
    'truth = self.nli.verify(text, str(best["text"]))' = 'truth = self.nli.verify(resolved_text, str(best["text"]))'
}

foreach ($old in $replacements.Keys) {
    $count = ([regex]::Matches($source, [regex]::Escape($old))).Count
    if ($count -ne 1) {
        throw "Expected one occurrence of: $old. Found: $count. Backup remains at $backup"
    }
    $source = $source.Replace($old, $replacements[$old])
}

Set-Content $target -Value $source -Encoding UTF8

python -m py_compile $target
if ($LASTEXITCODE -ne 0) {
    Copy-Item $backup $target -Force
    throw "Python validation failed. The original pipeline was restored."
}

Write-Host "MULTI-TURN CONTEXT FIX APPLIED SUCCESSFULLY" -ForegroundColor Green
Write-Host "Backup: $backup"
Write-Host "Restart the API server, then repeat the previous-context test."
