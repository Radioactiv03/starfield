state("starfield"){}


startup
{
	vars.watchers = new MemoryWatcherList();
	
    	//creates text components for quest counter and speedometer
	vars.SetTextComponent = (Action<string, string>)((id, text) =>
		{
	        var textSettings = timer.Layout.Components.Where(x => x.GetType().Name == "TextComponent").Select(x => x.GetType().GetProperty("Settings").GetValue(x, null));
	        var textSetting = textSettings.FirstOrDefault(x => (x.GetType().GetProperty("Text1").GetValue(x, null) as string) == id);
	        if (textSetting == null)
	        {
	        var textComponentAssembly = Assembly.LoadFrom("Components\\LiveSplit.Text.dll");
	        var textComponent = Activator.CreateInstance(textComponentAssembly.GetType("LiveSplit.UI.Components.TextComponent"), timer);
	        timer.Layout.LayoutComponents.Add(new LiveSplit.UI.Components.LayoutComponent("LiveSplit.Text.dll", textComponent as LiveSplit.UI.Components.IComponent));
	
	        textSetting = textComponent.GetType().GetProperty("Settings", BindingFlags.Instance | BindingFlags.Public).GetValue(textComponent, null);
	        textSetting.GetType().GetProperty("Text1").SetValue(textSetting, id);
	        }
	
	        if (textSetting != null)
	        textSetting.GetType().GetProperty("Text2").SetValue(textSetting, text);
    	});
	
	
	settings.Add("Speed", false, "Speedometer");
	settings.Add("Quest", false, "Quest Counter");
	settings.Add("Cell", false, "Cell ID");
	settings.Add("QuestSplitting", false, "Quest Splitting");
	
}

init
{
	var module = modules.First();
	var scanner = new SignatureScanner(game, module.BaseAddress, module.ModuleMemorySize);
	vars.LoadingPtr = scanner.Scan(new SigScanTarget(2, "89 ?? ????????33??C5??????????????4883????5B") { 
	OnFound = (process, scanners, addr) => addr + 0x4 + process.ReadValue<int>(addr)
	});
	vars.PlayerCharacterPtr = scanner.Scan(new SigScanTarget(3, "4889??????????488B??????????488B??????????4885??74??0FB6") { 
	OnFound = (process, scanners, addr) => addr + 0x4 + process.ReadValue<int>(addr)
	});
	vars.Playerptr = scanner.Scan(new SigScanTarget(4, "480F????????????488B????4C??????498B") { 
	OnFound = (process, scanners, addr) => addr + 0x4 + process.ReadValue<int>(addr)
	});
	
	//Quest Completed is not stored within the PlayerCharacter as it is a "MiscStat"
	vars.QuestPtr = scanner.Scan(new SigScanTarget(3, "4803??????????BA????????4885") { 
	OnFound = (process, scanners, addr) => addr + 0x4 + process.ReadValue<int>(addr)
	});
	
	vars.IntroDonePtr = scanner.Scan(new SigScanTarget(3, "4889??????????89??????????488D??????????4889??????????E8????????488D??????????E8????????488D??????????4883????C34889??????5553") { 
	OnFound = (process, scanners, addr) => addr + 0x4 + process.ReadValue<int>(addr)
	});
	
	
	if (vars.LoadingPtr == IntPtr.Zero || vars.Playerptr == IntPtr.Zero)
	{
        	throw new Exception("Game engine not initialized - retrying");
	}
	
	
	
	vars.Loading = new MemoryWatcher<int>(vars.LoadingPtr);
	vars.IntroDone = new MemoryWatcher<bool>(vars.IntroDonePtr);
	//These will probably change but until I find the ProcessHigh/PlayerCharacter it'll do	
	vars.SpeedPtr = new MemoryWatcher<IntPtr>(new DeepPointer(vars.Playerptr,0x4F0));
	vars.Cell =  new MemoryWatcher<int>(new DeepPointer(vars.PlayerCharacterPtr,0xE0,0x30));
	vars.Quest = new MemoryWatcher<int>(new DeepPointer(vars.QuestPtr,0x2D0));
	
	vars.watchers.Add(vars.Loading);
	vars.watchers.Add(vars.SpeedPtr);
	vars.watchers.Add(vars.Cell);
	vars.watchers.Add(vars.Quest);
	vars.watchers.Add(vars.IntroDone);
}

update
{
	vars.split = false;
	vars.watchers.UpdateAll(game);
	var xVel = game.ReadValue<float>((IntPtr)vars.SpeedPtr.Current+0xB0);
	var yVel = game.ReadValue<float>((IntPtr)vars.SpeedPtr.Current+0xB4);
	var zVel = game.ReadValue<float>((IntPtr)vars.SpeedPtr.Current+0xB8);
	current.speed = Math.Sqrt(xVel * xVel + yVel * yVel);
	if(settings["Speed"]) 
	{
		if(vars.Loading.Current == 1)//Avoid value flickering during load
		{
			vars.SetTextComponent("Speed:",current.speed.ToString("000.0000"));
		}
	}
	if(settings["Quest"]) 
	{
		vars.SetTextComponent("Quests:",vars.Quest.Current.ToString()); 
	}
	if(settings["Cell"]) 
	{
		vars.SetTextComponent("Cell ID:", vars.Cell.Current.ToString("X")); 
	}
	if(settings["QuestSplitting"])
	{
		vars.split = vars.Quest.Current != vars.Quest.Old && vars.Quest.Current != 0 || vars.Quest.Old = 0;
	}
}

isLoading
{
	return vars.Loading.Current != 1 || !vars.IntroDone.Current;
}
split
{
	return vars.split;	
}
exit
{
	timer.IsGameTimePaused = true;
}


