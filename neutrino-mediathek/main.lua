
function getVersionInfo()
	local s = getJsonData2(url_new .. actionCmd_versionInfo, nil, nil, queryMode_Info);
--	H.printf("\nretData:\n%s\n", tostring(s))
	local j_table = decodeJson(s);
	if checkJsonError(j_table) == false then return false end

	local vdate  = os.date("%d.%m.%Y / %H:%M:%S", j_table.entry[1].vdate);
	local mvdate = os.date("%d.%m.%Y / %H:%M", j_table.entry[1].mvdate);
	local msg = string.format("Plugin v%s\n \n" ..
			"Datenbank\n" ..
			"Version: %s (Update %s)\n \n" ..
			"Datenbank MediathekView => Neutrino Mediathek\n" ..
			"%s (%s)\n \n" ..
			"Server API\n" ..
			"%s (%s)\n \n" ..
			"Datenbank MediathekView:\n" ..
			"%s\n" ..
			"%d Einträge (Stand vom %s)", 
			pluginVersion,
			j_table.entry[1].version, vdate,
			j_table.entry[1].progname, j_table.entry[1].progversion,
			j_table.entry[1].api, j_table.entry[1].apiversion,
			j_table.entry[1].mvversion,
			j_table.entry[1].mventrys, mvdate);

	messagebox.exec{title="Versionsinfo " .. pluginName, text=msg, buttons={ "ok" } };
end

function paintMainMenu(space, frameColor, textColor, info, count)
	local fontText = fontMainMenu
	local i
	local w1 = 0
	local w2 = 0
	local w = 0
	for i = 1, count do
		local wText1 = N:getRenderWidth(useDynFont, fontText, info[i][1])
		if wText1 > w1 then w1 = wText1 end
		local wText2 = N:getRenderWidth(useDynFont, fontText, info[i][2])
		if wText2 > w2 then w2 = wText2 end
	end
	local h = N:FontHeight(useDynFont, fontText) + 2*OFFSET.INNER_SMALL
	w = w1 + 2*OFFSET.INNER_MID + w2 + 2*OFFSET.INNER_MID

	local x = (SCREEN.OFF_X + SCREEN.END_X - w) / 2
	local h_tmp = (h + space)
	local h_ges = count * h_tmp
	local y_start = (SCREEN.END_Y - h_ges) / 2
	if (bgTransp == true) then
		y_start = (SCREEN.END_Y - h_ges) / 6
	end
	x = math.floor(x)
	x1 = x + OFFSET.INNER_MID
	x2 = x + OFFSET.INNER_MID + w1 + 2*OFFSET.INNER_MID
	h_tmp = math.floor(h_tmp)
	y_start = math.floor(y_start)

	for i = 1, count do
		local y = y_start + (i-1)*h_tmp
		local bg = 0
		txtC=textColor
		if ((i == 2) and (conf.enableLivestreams == "off")) then
			-- livestreams
			txtC = COL.MENUCONTENTINACTIVE_TEXT
			bg   = COL.MENUCONTENTINACTIVE
		end

		if info[i][1] == "" and info[i][2] == "" then
			goto continue
		end

		G.paintSimpleFrame(x, y, w, h, frameColor, bg)
		N:paintVLine(x + w1 + 2*OFFSET.INNER_MID, y, h, frameColor)
		N:RenderString(useDynFont, fontText, info[i][1], x1, y + h, txtC, w1, h, 1)
		N:RenderString(useDynFont, fontText, info[i][2], x2, y + h, txtC, w2, h, 0)

		::continue::
	end
end

function paintMainWindow(menuOnly, win)
	if (not win) then win = h_mainWindow end
	if (menuOnly == false) then
		win:paint{do_save_bg=true}
	end
	paintMainMenu(OFFSET.INNER_SMALL, COL.FRAME, COL.MENUCONTENT_TEXT, mainMenuEntry, #mainMenuEntry)
end

function hideMainWindow()
	h_mainWindow:hide()
	N:PaintBox(0, 0, SCREEN.X_RES, SCREEN.Y_RES, COL.BACKGROUND)

end

function newMainWindow()
	local x = SCREEN.OFF_X
	local y = SCREEN.OFF_Y
	local w = SCREEN.END_X - x
	local h = SCREEN.END_Y - y

	bgTransp = true
	local showHeader = true
	local bgCol = COL.MENUCONTENT_PLUS_0
	if (bgTransp == true) then
		showHeader = false
--		bgCol = bit32.band(0x00FFFFFF, bgCol)
--		bgCol = bit32.bor(0x60000000, bgCol)
		bgCol = (0x60000000)
	end

	local ret = cwindow.new{x=x, y=y, dx=w, dy=h, color_body=bgCol, show_header=showHeader, show_footer=false, name=pluginName .. " - v" .. pluginVersion, icon=pluginIcon};
	G.hideInfoBox(startBox)
	paintMainWindow(false, ret)
	mainScreen = saveFullScreen()
	return ret
end

function mainWindow()

	h_mainWindow = newMainWindow()

	repeat
		local msg, data = N:GetInput(500)
		-- start
		if (msg == RC.ok) then
			startMediathek()
			restoreFullScreen(mainScreen, false)
		end
		-- livestreams
		if ((msg == RC.sat) or (msg == RC.red)) then
			if (conf.enableLivestreams == "on") then
				livestreamMenu()
			end
		end
		-- settings
		if (msg == RC.setup) then
			configMenu()
		end
		-- info
		if (msg == RC.info) then
			getVersionInfo()
		end
		-- for testing
		if (msg == RC.rewind) then
		end
		if (msg == RC.www) then
			testFunc()
--			if timerThread ~= nil then
--				timerThread:cancel()
--			end
		end
		-- exit plugin
		checkKillKey(msg)
	until msg == RC.home or msg == RC.stop or forcePluginExit == true;

end

-- ###########################################################################################

muteStatusNeutrino	= false
muteStatusPlugin	= false
volumeNeutrino		= 0

function beforeStart()
	V:zapitStopPlayBack()
	V:ShowPicture(backgroundImage)

	muteStatusNeutrino = M:isMuted()
	volumeNeutrino = M:getVolume()
	M:enableMuteIcon(false)
	M:AudioMute(true, false)

--	timerThread = threads.new(_timerThread)
--	timerThread:start()
end

function afterStop()
	hideMainWindow()
	if (moviePlayed == false) then
		V:channelRezap()
	end
	local rev, box = M:GetRevision()
	if rev == 1 and box == "Spark" then V:StopPicture() end

	M:enableMuteIcon(true)
	M:AudioMute(muteStatusNeutrino, true)
	M:setVolume(volumeNeutrino)

	if timerThread ~= nil then
		local ok = timerThread:cancel()
		H.printf("timerThread cancel ok: %s", tostring(ok))
		ok = thread:join()
		H.printf("timerThread join ok: %s", tostring(ok))
	end
end

--local _timerThread = [[
--	while (true) do
--	end
--	return 1
--]]

function main()
	initLocale();
	initVars();
	beforeStart()
	loadConfig();
	setFonts();
	startBox = paintMiniInfoBox("Starte Plugin");
	createImages();
	mainWindow();
	_saveConfig(true);
	afterStop()
end

main()

-- ###########################################################################################
