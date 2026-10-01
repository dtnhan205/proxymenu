
Add-Type -Path 'vendor/InjectFix/ThirdParty/Mono.Cecil.dll'
 = [Mono.Cecil.AssemblyDefinition]::ReadAssembly('baseline/DummyDll/Assembly-CSharp.dll')
 = .MainModule.GetType('COW.GamePlay.PlayerNetwork')
 = .Methods | Where-Object { .Name -eq 'ComputePosition' }
if ( -ne ) { Write-Host 'Found ComputePosition:' .FullName } else { Write-Host 'Not found' }
