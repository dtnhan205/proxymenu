$ErrorActionPreference = 'Stop'
& py -3 -m unittest discover -s (Join-Path $PSScriptRoot 'tools') -p 'test_*.py' -v
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
