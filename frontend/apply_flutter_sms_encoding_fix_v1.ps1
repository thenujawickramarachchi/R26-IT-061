$ErrorActionPreference = 'Stop'

$projectRoot = (Get-Location).Path
$mainPath = Join-Path $projectRoot 'lib\main.dart'

if (-not (Test-Path (Join-Path $projectRoot 'pubspec.yaml')) -or -not (Test-Path $mainPath)) {
    throw 'Run this script from the Flutter project root (the folder containing pubspec.yaml).'
}

$backupRoot = Join-Path $projectRoot 'frontend_patch_backups'
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = Join-Path $backupRoot "before_sms_encoding_fix_$timestamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item $mainPath (Join-Path $backupDir 'main.dart') -Force

$main = Get-Content $mainPath -Raw

$oldBlockPattern = @'
(?ms)    final Uri smsUri = Uri\(\s*
      scheme: 'sms',\s*
      path: widget\.phoneNumber\.trim\(\),\s*
      queryParameters: <String, String>\{'body': message\},\s*
    \);
'@

$newBlock = @'
    final String safePhoneNumber = widget.phoneNumber.trim().replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );
    final String encodedMessage = Uri.encodeComponent(message);
    final Uri smsUri = Uri.parse(
      'sms:$safePhoneNumber?body=$encodedMessage',
    );
'@

if ([regex]::IsMatch($main, $oldBlockPattern)) {
    $smsBlockRegex = [regex]::new($oldBlockPattern)
    $main = $smsBlockRegex.Replace($main, $newBlock.TrimEnd(), 1)
} elseif ($main -match 'final String encodedMessage = Uri\.encodeComponent\(message\)') {
    Write-Host 'SMS encoding fix is already present.'
} else {
    throw 'Could not find the expected SMS URI block. The backup is safe and main.dart was not changed.'
}

Set-Content $mainPath -Value $main -Encoding UTF8

dart format $mainPath
if ($LASTEXITCODE -ne 0) {
    throw 'dart format failed.'
}

flutter analyze
if ($LASTEXITCODE -ne 0) {
    throw 'The SMS patch was applied, but flutter analyze found an issue. Review the output above.'
}

Write-Host ''
Write-Host 'FLUTTER SMS ENCODING FIX APPLIED SUCCESSFULLY' -ForegroundColor Green
Write-Host "Project: $projectRoot"
Write-Host "Backup: $backupDir"
Write-Host 'SMS spaces will now be encoded as %20 instead of appearing as + characters.'
Write-Host 'Next: run the app again and compose a new warning SMS.'
