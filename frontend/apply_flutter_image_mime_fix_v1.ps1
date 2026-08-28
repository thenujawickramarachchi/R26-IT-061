$ErrorActionPreference = 'Stop'

$projectRoot = (Get-Location).Path
$mainPath = Join-Path $projectRoot 'lib\main.dart'
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'

if (-not (Test-Path $pubspecPath) -or -not (Test-Path $mainPath)) {
    throw 'Run this script from the Flutter project root (the folder containing pubspec.yaml).'
}

$backupRoot = Join-Path $projectRoot 'frontend_patch_backups'
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = Join-Path $backupRoot "before_image_mime_fix_$timestamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item $mainPath (Join-Path $backupDir 'main.dart') -Force
Copy-Item $pubspecPath (Join-Path $backupDir 'pubspec.yaml') -Force

Write-Host 'Adding the explicit image MIME dependency...'
flutter pub add http_parser
if ($LASTEXITCODE -ne 0) {
    throw 'flutter pub add http_parser failed.'
}

$main = Get-Content $mainPath -Raw

if ($main -notmatch "package:http_parser/http_parser.dart") {
    $httpImport = "import 'package:http/http.dart' as http;"
    $mimeImport = "import 'package:http_parser/http_parser.dart';"

    if ($main.Contains($httpImport)) {
        $main = $main.Replace($httpImport, "$httpImport`r`n$mimeImport")
    } else {
        $main = "$mimeImport`r`n$main"
    }
}

$oldUpload = "    request.files.add(await http.MultipartFile.fromPath('file', image.path));"
$newUpload = @'
    final String lowerImageName = image.name.toLowerCase();
    final MediaType imageMediaType = lowerImageName.endsWith('.png')
        ? MediaType('image', 'png')
        : lowerImageName.endsWith('.webp')
        ? MediaType('image', 'webp')
        : MediaType('image', 'jpeg');

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        image.path,
        filename: image.name,
        contentType: imageMediaType,
      ),
    );
'@

if ($main.Contains($oldUpload)) {
    $main = $main.Replace($oldUpload, $newUpload.TrimEnd())
} elseif ($main -match 'lowerImageName|contentType:\s*imageMediaType') {
    Write-Host 'Image MIME fix is already present.'
} else {
    throw 'Could not find the inspection-photo MultipartFile upload line. The backup is safe and no main.dart changes were saved.'
}

Set-Content $mainPath -Value $main -Encoding UTF8

dart format $mainPath
if ($LASTEXITCODE -ne 0) {
    throw 'dart format failed.'
}

flutter analyze
if ($LASTEXITCODE -ne 0) {
    throw 'The patch was applied, but flutter analyze found an issue. Review the output above.'
}

Write-Host ''
Write-Host 'FLUTTER IMAGE MIME FIX APPLIED SUCCESSFULLY' -ForegroundColor Green
Write-Host "Project: $projectRoot"
Write-Host "Backup: $backupDir"
Write-Host 'JPEG, PNG and WebP uploads now include an explicit Content-Type.'
Write-Host 'Next: stop the running Flutter app, then run flutter run -d R5CRC0GB17W again.'
