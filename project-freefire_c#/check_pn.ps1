Add-Type -Path 'vendor\InjectFix\ThirdParty\Mono.Cecil.dll'
$assembly = [Mono.Cecil.AssemblyDefinition]::ReadAssembly('baseline\DummyDll\Assembly-CSharp.dll')
$pn = $assembly.MainModule.GetType('COW.GamePlay.PlayerNetwork')
$pn.Methods | Where-Object { $_.Name -like '*OnUpdate*' } | ForEach-Object { Write-Host $_.FullName }
