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
	

	settings.Add("QuestSplitting", true, "Quest Splitting");
	settings.Add("AutoStart", true, "Auto Start");
	//Parent setting
	settings.Add("Variable Information", false, "Variable Information");
	//Child settings that will sit beneath Parent setting
	settings.Add("Speed", false, "Speedometer", "Variable Information");
	settings.Add("Quest", false, "Quest Counter", "Variable Information");
	settings.Add("Cell", false, "Cell ID", "Variable Information");
	settings.Add("Last Updated Quest", false, "Last Updated Quest", "Variable Information");

	//Parent setting
	settings.Add("Extra Splits", false, "Extra Splits");
	//Child settings that will sit beneath Parent setting
	settings.Add("OSS Artifact", false, "OSS Artifact", "Extra Splits");
	settings.Add("Enter Ship", false, "Enter Ship", "Extra Splits");
	settings.Add("New Atlantis", false, "New Atlantis", "Extra Splits");
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
	
	//Quest Completed is not stored within the PlayerCharacter as it is a "MiscStat"
	vars.MiscStat = scanner.Scan(new SigScanTarget(3, "4803??????????BA????????4885") { 
	OnFound = (process, scanners, addr) => addr + 0x4 + process.ReadValue<int>(addr)
	});
	
	vars.IntroDonePtr = scanner.Scan(new SigScanTarget(3, "4887??????????418B??4887??????????418B??4887??????????488D") { 
	OnFound = (process, scanners, addr) => addr + 0x4 + process.ReadValue<int>(addr)
	});
	/*
	vars.PlayerControlsPtr = scanner.Scan(new SigScanTarget(3, "4C????????????4489??????????C5??????C5??????????????4C????????????4C????????????488B??????????4881??????????488D??????????E8????????4889??????????4C????????????75??488D??????????E8") { 
	OnFound = (process, scanners, addr) => addr + 0x4 + process.ReadValue<int>(addr)
	});
	
	
	vars.bhkCharProxyController = scanner.Scan(new SigScanTarget(4, "480F????????????488B????4C??????498B") { 
	OnFound = (process, scanners, addr) => addr + 0x4 + process.ReadValue<int>(addr)
	});
	*/
		
	//All these are pre 1.8
	vars.Loading = new MemoryWatcher<int>(vars.LoadingPtr);
	vars.IntroDone = new MemoryWatcher<bool>(vars.IntroDonePtr);
	//Uses the PlayerCharacter and goes through bhkCharProxyController
	vars.SpeedPtr = new MemoryWatcher<float>(new DeepPointer(vars.PlayerCharacterPtr,0x260,0x8,0x498));
	vars.Cell =  new MemoryWatcher<int>(new DeepPointer(vars.PlayerCharacterPtr,0xE0,0x30));
	vars.Quest = new MemoryWatcher<int>(new DeepPointer(vars.MiscStat,0x270));
	//TESQuest 0x880 : ~Info is 0x38 : Id is 0x30
	vars.lastUpdatedQuest = new StringWatcher(new DeepPointer(vars.PlayerCharacterPtr,0x880, 0x38, 0x48, 0x18),50);
	
	//Incase we need to track PlayerControls
	//vars.PlayerControls = new MemoryWatcher<int>(new DeepPointer(vars.PlayerControlsPtr,0x168));
	
	version = modules.First().FileVersionInfo.ProductVersion;
	//Should probably find a better way to do this
	if(Char.GetNumericValue(version[2]) >= 8)
	{
		vars.PlayerCharacterPtr = scanner.Scan(new SigScanTarget(3, "488B??????????4885??0F84????????83??????0F84????????488D") { 
		OnFound = (process, scanners, addr) => addr + 0x4 + process.ReadValue<int>(addr)
		});
		vars.SpeedPtr = new MemoryWatcher<float>(new DeepPointer(vars.PlayerCharacterPtr,0x240,0x8,0x498));
		vars.Cell =  new MemoryWatcher<int>(new DeepPointer(vars.PlayerCharacterPtr,0xC0,0x28));
		vars.lastUpdatedQuest = new StringWatcher(new DeepPointer(vars.PlayerCharacterPtr,0x860, 0x38, 0x40, 0x18),50);	
	}
	if (vars.LoadingPtr == IntPtr.Zero)
	{
        	throw new Exception("Game engine not initialized - retrying");
	}
	

	vars.watchers.Add(vars.Loading);
	vars.watchers.Add(vars.SpeedPtr);
	vars.watchers.Add(vars.Cell);
	vars.watchers.Add(vars.Quest);
	vars.watchers.Add(vars.IntroDone);
	vars.watchers.Add(vars.lastUpdatedQuest);
	//vars.watchers.Add(vars.PlayerControls);
	
}
update
{
	vars.split = false;
	vars.watchers.UpdateAll(game);
	if(settings["Speed"]) 
	{
		vars.SetTextComponent("Speed:",vars.SpeedPtr.Current.ToString("000.0000"));
	}
	if(settings["Quest"]) 
	{
		vars.SetTextComponent("Quests:",vars.Quest.Current.ToString()); 
	}
	if(settings["Cell"]) 
	{
		vars.SetTextComponent("Cell ID:", vars.Cell.Current.ToString("X")); 
	}
	if(settings["Last Updated Quest"])
	{
		vars.SetTextComponent("Last Updated Quest:", vars.lastUpdatedQuest.Current);
	}
	if(settings["QuestSplitting"])
	{
		vars.split = vars.Quest.Current != vars.Quest.Old && vars.Loading.Current == 1 && (vars.lastUpdatedQuest.Current != "Final Glimpses" || vars.lastUpdatedQuest.Current != "Failure to Communicate" );
	}


}
start
{
	if(settings["AutoStart"])
	{
		timer.IsGameTimePaused = true;
		return vars.Quest.Current == 0 && vars.Cell.Current.ToString("X") == "1054C";
	}
}
isLoading
{
	return vars.Loading.Current != 1 || !vars.IntroDone.Current;
}
split
{
	
	if(settings["OSS Artifact"] && vars.Cell.Old.ToString("X") == "1054C" && vars.Cell.Current.ToString("X") == "1ED6FD" && vars.Quest.Current == 0)
	{
		return true;
	}
	if(settings["Enter Ship"] && vars.Cell.Old.ToString("X") == "1ED709" && vars.Cell.Current.ToString("X") == "1100136" && vars.Quest.Current == 0)
	{
		return true;
	}
	if(settings["New Atlantis"] && vars.Cell.Old.ToString("X") == "1100136" && vars.Cell.Current.ToString("X") == "125AC" && vars.Quest.Current == 0)
	{
		return true;
	}
	return vars.split;
}
exit
{
	timer.IsGameTimePaused = true;
}
