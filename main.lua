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
local mFloor = math.floor
local mMin = math.min
local mMax = math.max
local pi = math.pi
print(pi)

local debugGroup = display.newGroup()
local sceneGroup = display.newGroup()
local keyGroup = display.newGroup()
local boundaryPointGroup = display.newGroup()
keyGroup.x, keyGroup.y = display.contentCenterX, display.contentCenterY - display.contentCenterY / 5
local uiGroup = display.newGroup()
sceneGroup:insert(debugGroup)
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

local debugLines = {}
local function iterateCircleForShape()
	local circleStepAngle = 12

	local function getDistance(x1, y1, x2, y2)
		local xDist = x2 - x1
		local yDist = y2 - y1
		local distance = math.sqrt((xDist * xDist) + (yDist * yDist))
		return distance
	end

	local nearestPoints = {} -- stores points that are nearest to the circles edge

	local function isAlreadyANearestPoint(point)
		--print("checking if point is already a nearest point --- nearestPoints: "..#nearestPoints)
		if #nearestPoints > 0 then
			for i = 1, #nearestPoints do
				local checkPoint = nearestPoints[i]
				local xa, xb, ya, yb = mFloor(checkPoint.x), mFloor(point.x), mFloor(checkPoint.y), mFloor(point.y)
				--print("comparing point: "..xa, ya.." to checkPoint: "..xb, yb)
				if xa == xb and ya == yb then
					--print("return true")
					return true
				end
			end
		end
		--print("returning false")
		return nil
	end
	print("boundary points: "..#boundaryPointObjects)
	for i = 1, math.floor(360/circleStepAngle) do
		--iterate around the circle in steps of circleStepAngle
		local radius = layoutMaxRadius + 50
		local angle = circleStepAngle * i
		local x = radius * math.cos(math.rad(angle)) + keyGroup.x
		local y = radius * math.sin(math.rad(angle)) + keyGroup.y
		--get distance from x, y to each key boundary point
		local _nearestDistance = 1000000
		--display.newCircle(sceneGroup, x, y, 5), for testing the position of the boundary point circle
		local nearestPoint = nil
		local nearestPointDebugLine
		--print("211: "..#boundaryPointObjects)
		for i2 = 1, #boundaryPointObjects do
			_point = {x = boundaryPointObjects[i2].x, y = boundaryPointObjects[i2].y}
			--print("checking circle iteration point: "..x, y.." against key boundary point: ".._point.x, _point.y)
			local _distance = getDistance(x, y, _point.x, _point.y)
			--print("distance: ".._distance)
			local line = display.newLine(debugGroup, x, y, _point.x, _point.y)
			line.alpha = .1
			line.isVisible = false
			debugLines[#debugLines+1] = line
			if _distance < _nearestDistance then
				--print("found nearest distance")
				_nearestDistance = _distance
				nearestPoint = _point
				nearestPointDebugLine = line
			else
				--print("no nearest point found for circle point: "..i) , not sure why this still triggers but it does
			end
		end
		if nearestPointDebugLine then
			nearestPointDebugLine:setStrokeColor(1,0,0)
			nearestPointDebugLine.isVisible = false
			nearestPointDebugLine.alpha = .3
		end
		if nearestPoint ~= nil then
			if not isAlreadyANearestPoint(nearestPoint) then
				nearestPointDebugLine:setStrokeColor(0,1,0)
				--print("adding point: ".. _point.x, _point.y, "to nearest points")
				nearestPoints[#nearestPoints+1] = nearestPoint --add the nearest point to the nearestPoints table
				--print("found "..#nearestPoints.." nearest points")
				--print(json.prettify(nearestPoints))
			end
		end
	end
	local shapeMinX, shapeMaxX, shapeMinY, shapeMaxy, shapeWidth, shapeHeight = 10000, 0, 10000, 0, 0, 0
	for i = 1, #nearestPoints do
		local point = nearestPoints[i]
		if point.x < shapeMinX then
			shapeMinX = point.x
		end
		if point.x > shapeMaxX then
			shapeMaxX = point.x
		end
		if point.y < shapeMinY then
			shapeMinY = point.y
		end
		if point.y > shapeMaxy then
			shapeMaxy = point.y
		end
	end
	shapeWidth = shapeMaxX - shapeMinX
	shapeHeight = shapeMaxy - shapeMinY
	local midPointX, midPointY = shapeMinX + shapeWidth/2, shapeMinY + shapeHeight/2
	return nearestPoints, midPointX, midPointY
end

local boundaryShape

local function clearBoundaryPointDisplay() --clears boundary points, called when word is submitted
	for i = 1, #debugLines do
		debugLines[i]:removeSelf()
		debugLines[i] = nil
	end
	for i = 1, #boundaryPointObjects do
		_point = boundaryPointObjects[i]
		if _point.displayObject then
			_point.displayObject:removeSelf()
			_point.displayObject = nil
		end
		boundaryPointObjects[i] = nil
	end
	if boundaryShape then
		boundaryShape:removeSelf()
		boundaryShape = nil
	end
end

local function updateBoundaryPointDisplay() --visualises boundary points
	print("-----------updating boundary point display-----------")
	print("debugLines: "..#debugLines)
	for i = 1, #debugLines do
		debugLines[i]:removeSelf()
		debugLines[i] = nil
	end
	--print("drawing boundary points")
	for i = 1, #boundaryPointObjects do
		_point = boundaryPointObjects[i]
		if _point.displayObject then
			_point.displayObject:removeSelf()
			_point.displayObject = nil
		end
		boundaryPointObjects[i] = nil
	end
	for i = 1, #keyButtons do
		local button = keyButtons[i]
		if button.toggled == true then
			for i2 = 1, 4 do
				--print(#button.boundaryPoints)
				--print("drawing boundary point: "..i2.." for key: "..button.letter)
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
	local shapePoints, midPointX, midPointY = iterateCircleForShape()
	local shapeVertices = {}
	for i = 1, #shapePoints do
		shapeVertices[#shapeVertices+1] = shapePoints[i].x
		shapeVertices[#shapeVertices+1] = shapePoints[i].y
	end
	--print("midPointX, midPointY: "..midPointX, midPointY, "shape points: ")
	--print(json.prettify(shapePoints))
	if boundaryShape then
		boundaryShape:removeSelf()
		boundaryShape = nil
	end
	boundaryShape = display.newPolygon(boundaryPointGroup, midPointX, midPointY, shapeVertices)
	boundaryShape:setFillColor(.2,.5,.2,.2)
end

local function drawKeys(randomLetters) --draw display objects representing keys
	local function drawKey(x, y, letter)
		local button = display.newRoundedRect(keyGroup, 0, 0, keySizeX, keySizeY, roundedEdgeSize)
		keyButtons[#keyButtons+1] = button
		button.toggled = false
		button.canBeToggled = true
		button:setFillColor(.3);
		button.letter = letter
		button.x = x
		button.y = y
		button.textRect = display.newText({ x = button.x, y = button.y, text = letter,	width = 50,	font = native.systemFont, fontSize = 18, align = "center" })
		html5fix(button.textRect)

		button.boundaryPoints = {}
		--print(json.prettify(button.contentBounds))
		for i = 1, 4 do
			--print(boundaryPointBoundKeys[i][1], boundaryPointBoundKeys[i][2])
			local _x, _y = sceneGroup:localToContent( button.contentBounds[boundaryPointBoundKeys[i][1]], button.contentBounds[boundaryPointBoundKeys[i][2]] )
			--print("adding boundary point "..i.." for key: "..button.letter.." at pos: ".._x, _y)
			button.boundaryPoints[i] = { x = _x, y = _y }
		end

		keyGroup:insert(button.textRect)

		function button:insideBoundary()
			print(button.letter.." is INSIDE boundary")
			if button.canBeToggled then --only set as visible if it hasn't already been outside a previous boundary
				button.isVisible = true
				button.textRect.isVisible = true
			end
		end
		
		function button:outsideBoundary()
			print(button.letter.." is OUTSIDE boundary")
			button.isVisible = false
			button.textRect.isVisible = false
			button.canBeToggled = false
		end

		function button:addedToWord() --called from key event or when button is pressed
			if button.canBeToggled == false then
				return
			end
			wordString = wordString..self.letter
			wordDisplayBox:updateText()
			button:setFillColor(.8)
			button.textRect:setFillColor(0)
			button.toggled = true
			updateBoundaryPointDisplay()
		end

		function button:removedFromWord()
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

local _firstLetter, _onlyOneLetter --recycled
local function loadWords()
	local path = system.pathForFile( "external/wordlist.txt", system.ResourceDirectory )
	local file = io.open( path, "r" )
	local count = 1
	if file then
		for line in file:lines() do
			if count > 309 then --ignore first 309 lines for attribution
				if systemPlatform == "html5" then
					line = sSub(line, 1, sLen(line)-1)
				end
				if sLen(line) >= 1 then
					_firstLetter = sSub(line, 1, 1)
					_onlyOneLetter = true
					for i = 1, sLen(line) do
						if sSub(line, i, i) ~= _firstLetter then
							_onlyOneLetter = false
						end
					end
					if _onlyOneLetter == false then
						words[#words+1] = line
					else
						print("ignoring word that only contains one letter: "..line)
					end
				end
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

--for testing to get the enter keycode on html5
local keyCodeDisplay = display.newText({ x = display.contentCenterX, y = display.contentCenterY, text = "", font = native.systemFont, fontSize = 18, align = "center" })
keyCodeDisplay:setFillColor(1,0,0,1)

local samplerFactory = {}
local samplers = {}

function samplers.checkForResults()
	print("checking for results on "..#samplers.." samplers")
	local allResultsReceived = true
	for i = 1, #samplers do
		if samplers[i].receivedResult == false then
			allResultsReceived = false
		end
	end
	if allResultsReceived then
		print("received all color samplerResults, samplers: "..#samplers)
		for i = 1, #samplers do
			local sampler = samplers[i]
			if sampler.result == true then
				sampler.keyButton:insideBoundary()
			else
				sampler.keyButton:outsideBoundary()
			end
		end
		for i = 1, #keyButtons do
			local button = keyButtons[i]
			if button.toggled == true then
				button:removedFromWord()
			end
		end
		Runtime:removeEventListener("enterFrame", samplers.checkForResults)
	end
end

function samplerFactory:new()
	local sampler = {}
	sampler.receivedResult, sampler.result = false, false
	samplers[#samplers+1] = sampler

	function sampler.resultListener(event) --function to be called by the colorSample event listener
		--keyCodeDisplay.text = "receiving samples"
		sampler.receivedResult = true
		print("color sample result: "..event.r..", "..event.g..", "..event.b..", "..event.a)
		if event.g == 1 and event.r == 0 and event.b == 0 then sampler.result = true end
	end
	return sampler
end

local function removeWordsOutsideBoundary() --called when word is submitted
	boundaryShape:setFillColor(0,1,0,1)
	for i = 1, #keyButtons do
		local button = keyButtons[i]
		local sampler = samplerFactory:new()
		sampler.keyButton = button
		sampler.keyButton.textRect.isVisible = false --hide the letter while checking colors
		local buttonContentX, buttonContentY = button:localToContent(0, 0)
		print("sampling letter "..button.letter, buttonContentX, buttonContentY)
		--keyCodeDisplay.text = "setting sample listener"
		display.colorSample( buttonContentX, buttonContentY, sampler.resultListener )
	end
	Runtime:addEventListener("enterFrame", samplers.checkForResults)
end


local _count, _len1, _len2, _let1, _let2, _compareWord, _sameWords, _sameLetters --recycled
local function submitWord()

	local function checkWordList(inputWord)
		keyCodeDisplay.text = words[1].."\n"..words[2].."\n"..words[3].."\n"..words[4]
		_len1 = sLen(inputWord)
		for i = 1, #words do --for each word in the word list
			_compareWord = words[i]
			--print("comparing word: "..inputWord.." to word: ".._compareWord)
			_len2 = sLen(_compareWord)
			_count = 1
			if _len1 == _len2 then --lengths are the same, check each letter
				--print("comparing word: "..inputWord.." to word: ".._compareWord)
				_sameLetters = true
				while _count <= _len1 and _sameLetters == true do --use a while loop to exit out of loop if letters are not the same
					_let1 = sSub(inputWord, _count, _count)
					_let2 = sSub(_compareWord, _count, _count)
					--print("comparing letter: ".._let1.." to letter: ".._let2)
					if _let1 ~= _let2 then
						_sameLetters = false
					elseif (_count == _len1) then
						--print("words are same: "..inputWord.." == "..words[i])
						return true
					end
					_count = _count + 1
				end
			else
				--print("word lengths are not the same, ignoring word")
			end
		end
	end
	print("submitting word: "..wordString)
	--keyCodeDisplay.text = "submitting word: "..wordString..", "..#words
	local wordFound = checkWordList(wordString)
	----keyCodeDisplay.text = words[500]
	if wordFound then
		print("word found")
		--keyCodeDisplay.text = "word found"
		wordString = ""
		wordDisplayBox:updateText()
		removeWordsOutsideBoundary() --anything that happens after this needs to happen after the samplers.checkForResults() function is is completed
	else
		print("word not found")
	end
end

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
		--keyCodeDisplay.text = event.keyName
    	--print(event.keyName)
		if checkLetterTable(event.keyName) then
			keyEventTable[event.keyName]:addedToWord() --call function to update key display
		elseif event.keyName == "deleteBack" then
			local deletedLetter = sSub(wordString, sLen(wordString), sLen(wordString))
			if sLen (wordString) > 0 then
				wordString = sSub(wordString, 1, sLen(wordString) - 1)
				keyEventTable[deletedLetter]:removedFromWord() --call function to update key display, called after wordString updated for checking
				wordDisplayBox:updateText()
			end
		elseif event.keyName == "enter" then
			print("enter pressed")
			submitWord()
			return true
		end
	end
end

Runtime:addEventListener("key", onKeyEvent )