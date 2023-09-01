state("starfield"){}

init
{
	var module = modules.First();
	var scanner = new SignatureScanner(game, module.BaseAddress, module.ModuleMemorySize);
	vars.ptr = scanner.Scan(new SigScanTarget(2, "86??????????E8????????488D??????????4889????488D") { 
      OnFound = (process, scanners, addr) => addr + 0x4 + process.ReadValue<int>(addr)
    });  
	if (vars.ptr == IntPtr.Zero)
    {
        throw new Exception("Game engine not initialized - retrying");
    }
	

	vars.loading = new MemoryWatcher<int>(vars.ptr);	
}

update
{
	vars.loading.Update(game);
}

isLoading
{
	return vars.loading.Current != 1;
}

exit
{
    timer.IsGameTimePaused = true;
}


