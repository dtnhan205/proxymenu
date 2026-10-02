[CmdletBinding()]
param(
    [string]$DumpPath,
    [switch]$NoUpdate,
    [switch]$KeepBuildArtifacts
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProjectRoot = [IO.Path]::GetFullPath($PSScriptRoot)

function Get-ProjectPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    return [IO.Path]::GetFullPath((Join-Path $ProjectRoot $RelativePath))
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Program,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program exited with code $LASTEXITCODE"
    }
}

$Generated = Get-ProjectPath 'generated'
$Build = Get-ProjectPath 'build'
$Dist = Get-ProjectPath 'dist'
$DummyDirectory = Get-ProjectPath 'baseline\DummyDll'
$BaseAssemblyCSharp = Join-Path $DummyDirectory 'Assembly-CSharp.dll'
$IFixCore = Join-Path $DummyDirectory 'IFix.Core.dll'
$NeutralPatch = Get-ProjectPath 'baseline\Assembly-CSharp-patch-neutral.bytes'
$BindingsTsv = Join-Path $Generated 'bindings.tsv'
$BindingsJson = Join-Path $Generated 'bindings.json'
$GeneratedLogic = Join-Path $Generated 'ESPLogic.cs'
$Vendor = Get-ProjectPath 'vendor\InjectFix'
$ThirdParty = Join-Path $Vendor 'ThirdParty'
$CompilerSource = Join-Path $Build 'compiler-src'
$ReferenceDirectory = Join-Path $Build 'ref'
$RetargetedAssembly = Join-Path $Build 'Assembly-CSharp-retargeted.dll'
$PatchSourceAssembly = Join-Path $Build 'Assembly-CSharp-source.dll'
$StagePatch = Join-Path $Build 'Assembly-CSharp-patch.bytes'
$StageReport = Join-Path $Build 'Assembly-CSharp-patch.report.json'
$StageVerify = Join-Path $Build 'Assembly-CSharp-patch.verify.json'
$FinalPatch = Join-Path $Dist 'Assembly-CSharp-patch.bytes'
$FinalReport = Join-Path $Dist 'Assembly-CSharp-patch.report.json'
$FinalVerify = Join-Path $Dist 'Assembly-CSharp-patch.verify.json'
$FinalManifest = Join-Path $Dist 'Assembly-CSharp-patch.manifest.json'
$Csc = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe'

[IO.Directory]::CreateDirectory($Generated) | Out-Null
[IO.Directory]::CreateDirectory($Build) | Out-Null
[IO.Directory]::CreateDirectory($Dist) | Out-Null
[IO.Directory]::CreateDirectory($CompilerSource) | Out-Null
[IO.Directory]::CreateDirectory($ReferenceDirectory) | Out-Null

if (-not $NoUpdate) {
    $updateArguments = @(
        '-3', (Get-ProjectPath 'tools\update_from_dump.py'),
        '--dumps-dir', (Get-ProjectPath 'dumps'),
        '--template', (Get-ProjectPath 'src\ESPLogic.template.cs'),
        '--generated', $Generated,
        '--readme', (Get-ProjectPath 'README.md'),
        '--readme-en', (Get-ProjectPath 'README_EN.md')
    )
    if ($DumpPath) {
        $resolvedDump = if ([IO.Path]::IsPathRooted($DumpPath)) {
            [IO.Path]::GetFullPath($DumpPath)
        } else {
            [IO.Path]::GetFullPath((Join-Path $ProjectRoot $DumpPath))
        }
        $updateArguments += @('--dump', $resolvedDump)
    }
    Invoke-Checked 'py' $updateArguments
}

foreach ($required in @(
    $BindingsTsv, $BindingsJson, $GeneratedLogic, $BaseAssemblyCSharp,
    $IFixCore, $NeutralPatch, $Csc,
    (Get-ProjectPath 'src\WeaveEsp.cs'),
    (Get-ProjectPath 'tools\prepare_compiler.py'),
    (Get-ProjectPath 'tools\parse_ifix_patch.py'),
    (Get-ProjectPath 'tools\verify_ifix_patch.py'),
    (Join-Path $ThirdParty 'Mono.Cecil.dll'),
    (Join-Path $ThirdParty 'Mono.Cecil.Mdb.dll'),
    (Join-Path $ThirdParty 'Mono.Cecil.Pdb.dll')
)) {
    if (-not [IO.File]::Exists($required)) {
        throw "Required build input is missing: $required"
    }
}

$bindingInfo = Get-Content -LiteralPath $BindingsJson -Raw | ConvertFrom-Json
$Dump = [IO.Path]::GetFullPath([string]$bindingInfo.dump)
if (-not [IO.File]::Exists($Dump)) {
    throw "Active dump is missing: $Dump"
}

$Cecil = Join-Path $ThirdParty 'Mono.Cecil.dll'
$Weaver = Join-Path $Build 'WeaveEsp.exe'
Invoke-Checked $Csc @(
    '/nologo', '/target:exe', '/optimize+', "/out:$Weaver",
    "/reference:$Cecil", (Get-ProjectPath 'src\WeaveEsp.cs')
)
Copy-Item -LiteralPath $Cecil -Destination (Join-Path $Build 'Mono.Cecil.dll') -Force

foreach ($path in @($RetargetedAssembly, $PatchSourceAssembly, $StagePatch)) {
    if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) }
}
Invoke-Checked $Weaver @(
    '--adapt-target', $BaseAssemblyCSharp, $RetargetedAssembly, $BindingsTsv
)

$PublicReference = Join-Path $ReferenceDirectory 'Assembly-CSharp.dll'
Invoke-Checked $Weaver @(
    '--public-reference', $RetargetedAssembly, $PublicReference,
    $DummyDirectory, $BindingsTsv
)

$EspLogic = Join-Path $Build 'ESPLogic.dll'
Invoke-Checked $Csc @(
    '/nologo', '/target:library', '/optimize+', "/out:$EspLogic",
    "/lib:$ReferenceDirectory,$DummyDirectory",
    '/reference:Assembly-CSharp.dll',
    '/reference:UnityEngine.CoreModule.dll',
    '/reference:UnityEngine.IMGUIModule.dll',
    '/reference:UnityEngine.InputLegacyModule.dll',
    '/reference:UnityEngine.PhysicsModule.dll',
    '/reference:UnityEngine.TextRenderingModule.dll',
    $GeneratedLogic
)

Invoke-Checked $Weaver @(
    $RetargetedAssembly, $EspLogic, $PatchSourceAssembly, $DummyDirectory
)

Invoke-Checked 'py' @(
    '-3', (Get-ProjectPath 'tools\prepare_compiler.py'),
    '--dump', $Dump,
    '--neutral-patch', $NeutralPatch,
    '--instruction-source', (Join-Path $Vendor 'Src\Core\Instruction.cs'),
    '--translator-source', (Join-Path $Vendor 'Src\Tools\CodeTranslator.cs'),
    '--output', $CompilerSource
)

$IFixCompiler = Join-Path $Build 'IFix.exe'
Invoke-Checked $Csc @(
    '/nologo', '/unsafe', '/target:exe', '/optimize+', "/out:$IFixCompiler",
    "/reference:$Cecil",
    "/reference:$(Join-Path $ThirdParty 'Mono.Cecil.Mdb.dll')",
    "/reference:$(Join-Path $ThirdParty 'Mono.Cecil.Pdb.dll')",
    (Join-Path $CompilerSource 'Instruction.cs'),
    (Join-Path $CompilerSource 'CodeTranslator.cs'),
    (Join-Path $Vendor 'Src\Tools\CSFix.cs'),
    (Join-Path $Vendor 'Src\Tools\CecilExtensions.cs'),
    (Join-Path $Vendor 'Src\Tools\GenerateConfigure.cs'),
    (Join-Path $Vendor 'Src\Version.cs')
)
foreach ($name in @('Mono.Cecil.dll', 'Mono.Cecil.Mdb.dll', 'Mono.Cecil.Pdb.dll')) {
    Copy-Item -LiteralPath (Join-Path $ThirdParty $name) -Destination $Build -Force
}

$PatchConfig = Join-Path $Build 'patch-config.bin'
$configStream = [IO.File]::Create($PatchConfig)
$configWriter = New-Object IO.BinaryWriter($configStream)
try {
    $configWriter.Write([int]3)

    $configWriter.Write('COW.GamePlay.Player')
    $configWriter.Write([int]3)
    $configWriter.Write('IsReallyInStealth')
    $configWriter.Write('System.Boolean')
    $configWriter.Write([int]0)
    $configWriter.Write('get_LastAimingInfoFromWeapon')
    $configWriter.Write('COW.GamePlay.' + [string]$bindingInfo.placeholders.AIM_INFO_TYPE)
    $configWriter.Write([int]0)
    $configWriter.Write('get_IsMovableEntity')
    $configWriter.Write('System.Boolean')
    $configWriter.Write([int]0)

    $configWriter.Write('COW.GamePlay.SceneEditBoxSelectTool')
    $configWriter.Write([int]1)
    $configWriter.Write('OnGUI')
    $configWriter.Write('System.Void')
    $configWriter.Write([int]0)

    $configWriter.Write('COW.GamePlay.PlayerAttributes')
    $configWriter.Write([int]1)
    $configWriter.Write('GetScatterRate')
    $configWriter.Write('System.Single')
    $configWriter.Write([int]0)

    for ($index = 0; $index -lt 4; $index++) {
        $configWriter.Write([int]0)
    }
} finally {
    $configWriter.Dispose()
}

Invoke-Checked $IFixCompiler @(
    '-patch', $IFixCore, $PatchSourceAssembly, $RetargetedAssembly,
    $PatchConfig, $StagePatch, $DummyDirectory
)
if (-not [IO.File]::Exists($StagePatch)) {
    throw 'IFix did not create the staged patch.'
}

$Parser = Get-ProjectPath 'tools\parse_ifix_patch.py'
$Verifier = Get-ProjectPath 'tools\verify_ifix_patch.py'
Invoke-Checked 'py' @('-3', $Parser, $StagePatch, '-o', $StageReport)
Invoke-Checked 'py' @(
    '-3', $Verifier, $StagePatch, '--dump', $Dump, '--json', $StageVerify
)
$report = Get-Content -LiteralPath $StageReport -Raw | ConvertFrom-Json
$verification = Get-Content -LiteralPath $StageVerify -Raw | ConvertFrom-Json
$redirects = @($report.redirects)
$methods = @($report.patched_code)
if (-not $verification.valid -or @($verification.errors).Count -ne 0 `
    -or @($verification.warnings).Count -ne 0) {
    throw 'Generated patch did not pass strict VM verification.'
}
if ($report.magic -ne '0x66A319B20DB4A2CB' -or $report.remaining_bytes -ne 0 `
    -or ($methods.Count -ne 5 -and $methods.Count -ne 6) -or $redirects.Count -ne 5) {
    throw 'Generated patch failed structural assertions.'
}

$expectedRedirects = @(
    'COW.GamePlay.Player|IsReallyInStealth',
    'COW.GamePlay.SceneEditBoxSelectTool|OnGUI',
    'COW.GamePlay.Player|get_LastAimingInfoFromWeapon',
    'COW.GamePlay.Player|get_IsMovableEntity',
    'COW.GamePlay.PlayerAttributes|GetScatterRate'
)
$actualRedirects = @($redirects | ForEach-Object {
    (($_.declaring_type -split ',')[0]) + '|' + $_.name
})
$missingRedirects = @($expectedRedirects | Where-Object {
    $actualRedirects -notcontains $_
})
if ($missingRedirects.Count -ne 0) {
    throw "Generated patch is missing redirects: $($missingRedirects -join ', ')"
}

$forbiddenMethods = @(
    'GetSyncStatePos', 'OnWeaponReloadStarted',
    'OnWeaponReloadImmediateStarted', 'OnWeaponReloadSpeedChanged',
    'SendStartReload'
)
$methodNames = @($report.external_methods | ForEach-Object { $_.name })
$foundForbiddenMethods = @($forbiddenMethods | Where-Object {
    $methodNames -contains $_
})
if ($foundForbiddenMethods.Count -ne 0) {
    throw "Removed feature methods remain: $($foundForbiddenMethods -join ', ')"
}

$requiredMethods = @(
    'IsInStealth', 'IsLocalPlayer', 'IsLocalTeammate', 'IsVisible',
    'get_RootTransform', 'GetHeadTF', 'get_CurHP', 'get_MaxHP',
    'get_NickName', 'get_IsDieing', 'CurrentMatch', 'CurrentLocalPlayer',
    [string]$bindingInfo.placeholders.MATCH_PLAYERS_METHOD,
    'WorldToScreenPoint', 'Distance', 'DrawTexture', 'Label',
    'get_whiteTexture', 'get_current', 'get_type', 'get_matrix', 'set_matrix',
    'get_color', 'set_color', 'TRS', 'Euler', 'Clamp', 'Contains', 'Use',
    'get_mousePosition', 'get_delta', 'get_touchCount', 'get_unscaledTime',
    'get_AimStartPostion', 'get_HeadCollider', 'Normalize', 'op_Subtraction',
    'Range', 'get_SkillScatterRate',
    '<>iFixBaseProxy_get_IsMovableEntity',
    'get_Attributes', 'get_IsSkyDiving',
    'get_IsSkySurfing', 'get_IsParachuting', 'RequestSkyDiving',
    'get_CharacterController', 'get_enabled', 'get_transform', 'get_position',
    'Raycast', 'get_distance', 'get_isGrounded', 'get_skinWidth', 'Move',
    'StopParachuting', 'OnLandFinsish',
    'SetSpecialRunSpeedScaleByKeyAndValue', 'RemoveSpecialRunSpeedScaleByKey'
)
$missingMethods = @($requiredMethods | Where-Object { $methodNames -notcontains $_ })
if ($missingMethods.Count -ne 0) {
    throw "Generated patch is missing required methods: $($missingMethods -join ', ')"
}

$strings = @($report.strings)
$forbiddenStrings = @('Fast reload x3', 'Fake lag (fire)')
$foundForbiddenStrings = @($forbiddenStrings | Where-Object { $strings -contains $_ })
if ($foundForbiddenStrings.Count -ne 0) {
    throw "Removed menu strings remain: $($foundForbiddenStrings -join ', ')"
}
$requiredStrings = @('__esp_driver')
$missingStrings = @($requiredStrings | Where-Object { $strings -notcontains $_ })
if ($missingStrings.Count -ne 0) {
    throw "Generated patch is missing core strings: $($missingStrings -join ', ')"
}

$requiredFields = @(
    [string]$bindingInfo.placeholders.PLAYER_AIM_INFO_FIELD,
    [string]$bindingInfo.placeholders.SCENE_MENU_FIELD,
    [string]$bindingInfo.placeholders.SCENE_POSITION_FIELD,
    [string]$bindingInfo.placeholders.SCENE_STATE_FIELD,
    [string]$bindingInfo.placeholders.AIM_GAME_OBJECT_FIELD,
    [string]$bindingInfo.placeholders.AIM_COLLIDER_FIELD,
    [string]$bindingInfo.placeholders.AIM_HIT_POSITION_FIELD,
    [string]$bindingInfo.placeholders.AIM_TRACE_POSITION_FIELD,
    [string]$bindingInfo.placeholders.AIM_DIRECTION_FIELD,
    [string]$bindingInfo.placeholders.AIM_ORIGIN_FIELD,
    [string]$bindingInfo.placeholders.AIM_SECONDARY_ORIGIN_FIELD,
    [string]$bindingInfo.placeholders.AIM_HIT_TYPE_FIELD,
    [string]$bindingInfo.placeholders.AIM_FLAG_A_FIELD,
    [string]$bindingInfo.placeholders.AIM_FLAG_B_FIELD,
    [string]$bindingInfo.placeholders.AIM_SHORT_FIELD
)
$fieldNames = @($report.fields | ForEach-Object { $_.name })
$missingFields = @($requiredFields | Where-Object { $fieldNames -notcontains $_ })
if ($missingFields.Count -ne 0) {
    throw "Generated patch is missing target fields: $($missingFields -join ', ')"
}

Copy-Item -LiteralPath $StagePatch -Destination $FinalPatch -Force
Invoke-Checked 'py' @('-3', $Parser, $FinalPatch, '-o', $FinalReport)
Invoke-Checked 'py' @(
    '-3', $Verifier, $FinalPatch, '--dump', $Dump, '--json', $FinalVerify
)
$finalVerification = Get-Content -LiteralPath $FinalVerify -Raw | ConvertFrom-Json
if (-not $finalVerification.valid -or @($finalVerification.errors).Count -ne 0 `
    -or @($finalVerification.warnings).Count -ne 0) {
    throw 'Installed patch verification failed.'
}

$hash = (Get-FileHash -LiteralPath $FinalPatch -Algorithm SHA256).Hash
$assemblyIdentity = [string]$report.wrapper_manager
$assemblyIdentity = $assemblyIdentity.Substring($assemblyIdentity.IndexOf(',') + 2)
$manifest = [ordered]@{
    file = 'dist\Assembly-CSharp-patch.bytes'
    game_version = [string]$bindingInfo.version
    size = [int64](Get-Item -LiteralPath $FinalPatch).Length
    sha256 = $hash
    magic = $report.magic
    assembly = $assemblyIdentity
    dump = [IO.Path]::GetFileName($Dump)
    dump_sha256 = [string]$bindingInfo.dump_sha256
    bindings = $bindingInfo.details
    source_dummy_sha256 = (Get-FileHash $BaseAssemblyCSharp -Algorithm SHA256).Hash
    ifix_core_sha256 = (Get-FileHash $IFixCore -Algorithm SHA256).Hash
    neutral_patch_sha256 = (Get-FileHash $NeutralPatch -Algorithm SHA256).Hash
    redirects = @(
        'Player.IsReallyInStealth -> bootstrap',
        'SceneEditBoxSelectTool.OnGUI -> ESP/menu',
        'Player.get_LastAimingInfoFromWeapon -> silent aim',
        'Player.get_IsMovableEntity -> native aim system',
        'PlayerAttributes.GetScatterRate -> no recoil'
    )
    features = @(
        'ESP box/tracer/health/name/distance/visibility filters',
        'three-finger five-tap draggable ESP/AIM/SETTINGS menu',
        'silent aim BODY/HEAD/MIXED with headshot rate and FOV',
        'native aim system HEAD/NECK',
        'fast parachute',
        'speed running x3',
        'no recoil'
    )
    excluded = @('fast reload', 'fake lag')
    vm_instructions = [int](($methods | Measure-Object instructions -Sum).Sum)
    vm_exception_handlers = [int](($methods | Measure-Object exceptions -Sum).Sum)
}
[IO.File]::WriteAllText(
    $FinalManifest,
    (($manifest | ConvertTo-Json -Depth 8) + "`n"),
    [Text.Encoding]::ASCII
)

if (-not $KeepBuildArtifacts) {
    foreach ($temporaryFile in @(
        $RetargetedAssembly, $PublicReference, $PatchSourceAssembly, $EspLogic,
        $Weaver, $IFixCompiler, $PatchConfig,
        (Join-Path $Build 'Mono.Cecil.dll'),
        (Join-Path $Build 'Mono.Cecil.Mdb.dll'),
        (Join-Path $Build 'Mono.Cecil.Pdb.dll')
    )) {
        if ([IO.File]::Exists($temporaryFile)) { [IO.File]::Delete($temporaryFile) }
    }
}

Write-Output "BUILT: $FinalPatch"
$RootPatch = Join-Path $PSScriptRoot '..\Assembly-CSharp-patch.bytes'
Copy-Item -LiteralPath $FinalPatch -Destination $RootPatch -Force
Write-Output "SYNCED TO ROOT: $RootPatch"
Write-Output "version=$($bindingInfo.version) size=$($manifest.size) sha256=$hash"
Write-Output "redirects=$($redirects.Count) instructions=$($manifest.vm_instructions)"
