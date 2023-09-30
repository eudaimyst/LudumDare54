-----------------------------------------------------------------------------------------
--
-- main.lua
--
-- thanks to @pixelprophecy.bsky.social for informing me this was on
--
-----------------------------------------------------------------------------------------

local json = require("json")

local sLen = string.len
local sSub = string.sub
---@diagnostic disable-next-line: undefined-field --this is defined by solar2d math library not recognised
local mRound = math.round
local mRand = math.random
local pi = math.pi
print(pi)

local sceneGroup = display.newGroup()
local keyGroup = display.newGroup()
local boundaryPointGroup = display.newGroup()
keyGroup.x, keyGroup.y = display.contentCenterX, display.contentCenterY - display.contentCenterY / 5
local uiGroup = display.newGroup()
sceneGroup:insert(keyGroup)
sceneGroup:insert(uiGroup)
sceneGroup:insert(boundaryPointGroup)

local roundedEdgeSize = 12
local letters = "abcdefghijklmnopqrstuvwxyz"

--tables
local letterTable = {} --holds each defined letter
local randomLetterTable = {} --holds letters from letterTable in random order
local words = {} --loaded in loadWords(), check external/wordlist for attribution
local layoutData = {} --stores data used for the layout of the keys
local keyButtons = {} --stores the key display objects
local keyEventTable = {} --stores a table of key events with the keyboard key name as the key and the key display object as the value
local boundaryPointBoundKeys = { [1] = {"xMin", "yMin"}, [2] = {"xMax", "yMin"}, [3] = {"xMin", "yMax"}, [4] = {"xMax", "yMax"} } --used for getting each corner as boundary points of the keys from its contentBounds
local boundaryPointObjects = {} --stores the display objects for the boundary points

--constants used for display
local drawBoundaryPoints = false --draws circles at the boundary points of the key objects (for testing)
local layoutMaxRadius, layoutRings = 200, 3
local keySizeX, keySizeY = 50, 50
local uiButtonHeight = 40
local buttonOffset = 20
local wordDisplayWidth = 300
local submitButtonWidth = 130
local wordDisplayBox --the display object for the displayBox
local wordString = "" --the string of the current word

local systemPlatform = system.getInfo( "platform" )
local html5fix_offset
local function html5fix(object)
	if systemPlatform == "html5" then
		html5fix_offset = object.height - object.size
		-- realign textObject vertically
		object.y = object.y + html5fix_offset
	end
end

local function generateLetterTable(str)
	local t = {}
	for i = 1, sLen(str) do
		t[i] = sSub(str, i, i)
	end
	--print("generated letter table: "..json.prettify(t))
	return t
end
letterTable = generateLetterTable(letters)

local function cleanTable(table) --removes nil values from a table
	local t = {}
	local count = 1
	--print("cleaning table with length: "..#table)
	for i = 1, #table do
		if table[i] == "" then
			--print("nil value in table at pos: "..i..", ignoring value")
		else
			--print("value: "..table[i].." at pos: "..i..", adding to new table")
			t[count] = table[i]
			count = count + 1
		end
	end
	return t
end

local function makeRandomLetterTable(str)
	local tempLetterTable = generateLetterTable(str)
	local randomLetters = {}
	for i = 1, sLen(str) do
		--print(i)
		if #tempLetterTable == 0 then
			--print("tempLetterTable is empty, breaking")
			break
		end
		local randomPos = mRand(1, #tempLetterTable)
		--print("setting random letter table pos: "..i.." to: "..tempLetterTable[randomPos])
		randomLetters[i] = tempLetterTable[randomPos]
		tempLetterTable[randomPos] = ""
		tempLetterTable = cleanTable(tempLetterTable)
	end
	return randomLetters
end
randomLetterTable = makeRandomLetterTable(letters)
--print("random letter len: "..#randomLetterTable, json.prettify(randomLetterTable))


local function layoutCalc() --calculates the layoutData table
	local totalCircum = 0
	for i = layoutRings, 1, -1 do --calculate data for the circles
		local ring = {}
		layoutData[#layoutData+1] = ring
		ring.radius = layoutMaxRadius / layoutRings * i
		ring.circum = 2 * pi * ring.radius
		totalCircum = totalCircum + ring.circum
	end
	for i = 1, #layoutData do --calculate letter count and angle for each ring
		local ring = layoutData[i]
		local percent = ring.circum / totalCircum
		ring.letterCount = mRound(percent * #letterTable)
		ring.letterAngle = 360 / ring.letterCount
		print("ring "..i.." percent: "..percent..", letterCount: "..ring.letterCount.. ", letterAngle: "..ring.letterAngle)
	end
	for i = 1, #layoutData do --calculate letter positions
		local ringData = layoutData[i]
		ringData.letters = {}
		local angleOffset = mRand(0, ringData.letterAngle)
		for i2 = 1, ringData.letterCount do
			local letter = {}
			ringData.letters[i2] = letter
			local angle = ringData.letterAngle * i2 + angleOffset
			letter.x = ringData.radius * math.cos(math.rad(angle))
			letter.y = ringData.radius * math.sin(math.rad(angle))
		end
	end
end

local function debugDraw() --for testing layout sizes and positions
	local baseColor = { [1]= .2,[2]= .2,[3]= .2,[4]= .2 }
	local debugGroup = display.newGroup()
	local function drawCircles()
		sceneGroup:insert(debugGroup)
		for i = 1, #layoutData do
			local ringData = layoutData[i]
			local circle = display.newCircle(debugGroup,0,0,ringData.radius);
			local c = baseColor
			c[2] = i * .3
			circle:setFillColor( 0, 0, 0, 0);
			circle.strokeWidth = 3
			circle:setStrokeColor( c[1], c[2], c[3], c[4]);
		end
		debugGroup.x, debugGroup.y = display.contentCenterX, display.contentCenterY
	end

	local function drawDotsForKeys()
		for i = 1, #layoutData do
			local ringData = layoutData[i]
			for i2 = 1, #ringData.letters do
				local letter = ringData.letters[i2]
				local dot = display.newCircle(debugGroup, letter.x, letter.y, 5)
				dot:setFillColor(1,0,0)
			end
		end
	end
	drawDotsForKeys()
	drawCircles()
end

local _point --recycled point references
local function updateBoundaryPointDisplay() --visualises boundary points
	print("drawing boundary points")
	for i = 1, #boundaryPointObjects do
		_point = boundaryPointObjects[i]
		if _point.displayObject then
			_point.displayObject:removeSelf()
			_point.displayObject = nil
		end
	end
	for i = 1, #keyButtons do
		local button = keyButtons[i]
		if button.toggled == true then
			for i2 = 1, 4 do
				print(#button.boundaryPoints)
				print("drawing boundary point: "..i2.." for key: "..button.letter)
				local point = { x = button.boundaryPoints[i2].x, y = button.boundaryPoints[i2].y}
				if drawBoundaryPoints == true then
					local displayObject = display.newCircle(boundaryPointGroup, point.x, point.y, 1)
					displayObject:setFillColor(1,0,0)
					point.displayObject = displayObject
				end
				boundaryPointObjects[#boundaryPointObjects+1] = point
			end
		end
	end
end

local function drawKeys(randomLetters) --draw display objects representing keys
	local function drawKey(x, y, letter)
		local button = display.newRoundedRect(keyGroup, 0, 0, keySizeX, keySizeY, roundedEdgeSize)
		keyButtons[#keyButtons+1] = button
		button.toggled = false
		button:setFillColor(.3);
		button.letter = letter
		button.x = x
		button.y = y
		button.textRect = display.newText({ x = button.x, y = button.y, text = letter,	width = 50,	font = native.systemFont, fontSize = 18, align = "center" })
		html5fix(button.textRect)

		button.boundaryPoints = {}
		print(json.prettify(button.contentBounds))
		for i = 1, 4 do
			print(boundaryPointBoundKeys[i][1], boundaryPointBoundKeys[i][2])
			local _x, _y = sceneGroup:localToContent( button.contentBounds[boundaryPointBoundKeys[i][1]], button.contentBounds[boundaryPointBoundKeys[i][2]] )
			print("adding boundary point "..i.." for key: "..button.letter.." at pos: ".._x, _y)
			button.boundaryPoints[i] = { x = _x, y = _y }
		end

		keyGroup:insert(button.textRect)
		
		function button:added()
			button:setFillColor(.8)
			button.textRect:setFillColor(0)
			button.toggled = true
			updateBoundaryPointDisplay()
		end

		function button:removed()
			local letterInWord = false
			for i = 1, sLen(wordString) do
				if sSub(wordString, i, i) == button.letter then
					letterInWord = true
				end
			end
			if not letterInWord then
				button:setFillColor(.3)
				button.textRect:setFillColor(1)
				button.toggled = false
			end
			updateBoundaryPointDisplay()
		end
		return button
	end
	
	local count = 1
	for i = 1, #layoutData do
		local ringData = layoutData[i]
		for i2 = 1, #ringData.letters do
			local letter
			if randomLetters then
				letter = randomLetterTable[count]
			else
				letter = letterTable[count]
			end
			keyEventTable[letter] = drawKey(ringData.letters[i2].x, ringData.letters[i2].y, letter)
			count = count + 1
		end
	end
end


local function drawUI()
	wordDisplayBox = display.newRoundedRect(uiGroup,0,0,wordDisplayWidth,uiButtonHeight,roundedEdgeSize)
	wordDisplayBox:setFillColor(.1)
	wordDisplayBox.strokeWidth = 3
	wordDisplayBox:setStrokeColor(.9)
	wordDisplayBox.textRect = display.newText({ x = wordDisplayBox.x, y = wordDisplayBox.y, text = "", font = native.systemFont, fontSize = 18, align = "center" })
	html5fix(wordDisplayBox.textRect)
	uiGroup:insert(wordDisplayBox.textRect)
	function wordDisplayBox:updateText()
		print("updating text: "..wordString)
		self.textRect.text = wordString
	end

	local submitButton = display.newRoundedRect(uiGroup,wordDisplayWidth/2 + submitButtonWidth/2 + buttonOffset,0,submitButtonWidth,uiButtonHeight,12)
	submitButton:setFillColor(.9)
	local submitButtonText = display.newText({ x = submitButton.x, y = submitButton.y, text = "submit", font = native.systemFont, fontSize = 18, align = "center" })
	html5fix(submitButtonText)
	uiGroup:insert(submitButtonText)
	submitButtonText:setFillColor(0)
	uiGroup.x = display.contentCenterX
	uiGroup.y = keyGroup.y + keyGroup.height/2 + buttonOffset * 3
end

local function loadWords()
	local path = system.pathForFile( "external/wordlist.txt", system.ResourceDirectory )
	local file = io.open( path, "r" )
	local count = 1
	if file then
		for line in file:lines() do
			if count >= 310 then --ignore first 309 lines for attribution
				words[#words+1] = line
			end
			count = count + 1
		end
		io.close( file )
	else
		print("no file")
	end
end

layoutCalc()
--debugDraw()
drawKeys(true) --true for random letters, otherwise loads from letterTable in order
drawUI()

--load word list, we do this after drawing the sceen so not looking at nothing waiting to load

loadWords()
print("word count: "..#words)

local function onKeyEvent(event)

	local function checkLetterTable(letter)
		for i = 1, #letterTable do
			if letterTable[i] == letter then
				return true
			end
		end
		return false
	end
	
	if event.phase == "down" then
    	--print(event.keyName)
		if checkLetterTable(event.keyName) then
			keyEventTable[event.keyName]:added() --call function to update key display
			wordString = wordString..event.keyName
			wordDisplayBox:updateText()
		elseif event.keyName == "deleteBack" then
			local deletedLetter = sSub(wordString, sLen(wordString), sLen(wordString))
			if sLen (wordString) > 0 then
				wordString = sSub(wordString, 1, sLen(wordString) - 1)
				keyEventTable[deletedLetter]:removed() --call function to update key display, called after wordString updated for checking
				wordDisplayBox:updateText()
			end
		end
	end
end

Runtime:addEventListener("key", onKeyEvent )