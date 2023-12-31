-----------------------------------------------------------------------------------------
--
-- game.lua
--
-- scene for the game
--
-----------------------------------------------------------------------------------------
local composer = require("composer")
local json = require("json")

local levelData = require("level_data")

local gameParams --passed from main lua file to scene upon creation
local onKeyEvent

--local math/string functions
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

local letters = "abcdefghijklmnopqrstuvwxyz" --letters used to build keys

--scene related
local debugGroup = {}
local keyGroup = {}
local boundaryPointGroup = {}
local uiGroup = {}
local backgroundGroup = {}

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
local gameFont = "content/font/rockmaker.regular.ttf"
local roundedEdgeSize = 12
local drawBoundaryPoints = false --draws circles at the boundary points of the key objects (for testing)
local layoutMaxRadius, layoutRings = 200, 3
local keySizeX, keySizeY = 50, 50
local uiButtonHeight = 40
local buttonOffset = 20
local wordDisplayWidth = 300
local submitButtonWidth = 130

local submittedWordCount = 0

--vars
local targetWordCount = 0
submittedWordCount = 0
local wordsRemainingDisplay = {} --shows how many words remaining to get to next level
local wordDisplayBox = {}--the display object for the displayBox
local wordString = "" --the string of the current word
local lastSubmittedword = "" --when a word is submitted we store it to prevent duplicate words
local avatar = {}--a character that runs around

local game = {} --solely used for submit word / delete letter functions because I got lazy at the end and need to get to it from a tap on their buttons

local function runGame(sceneGroup)

	local function initVars() --after scene is loaded we need to initialise variables to defaults
		debugGroup = display.newGroup()
		keyGroup = display.newGroup()
		boundaryPointGroup = display.newGroup()
		keyGroup.x, keyGroup.y = display.contentCenterX, display.contentCenterY - display.contentHeight/20
		uiGroup = display.newGroup()
		backgroundGroup = display.newGroup()
		sceneGroup:insert(backgroundGroup)
		sceneGroup:insert(debugGroup)
		sceneGroup:insert(keyGroup)
		sceneGroup:insert(uiGroup)
		sceneGroup:insert(boundaryPointGroup)

		targetWordCount = 1+gameParams.level
		submittedWordCount = 0
		wordsRemainingDisplay = {} --shows how many words remaining to get to next level
		wordDisplayBox = {} --the display object for the displayBox
		wordString = "" --the string of the current word
		lastSubmittedword = "" --when a word is submitted we store it to prevent duplicate words
		avatar = {} --a character that runs around
		
	end
	initVars()

	local systemPlatform = system.getInfo( "platform" )
	local html5fix_offset
	local function html5fix(object)
		if systemPlatform == "html5" then
			html5fix_offset = object.height - object.size
			-- realign textObject vertically
			object.y = object.y + html5fix_offset/2 --this stopped working so we will brute force instead
		end
	end

	local function drawNewBackground()
		local background = display.newImageRect(backgroundGroup, "content/background.png", 950, 950)
		background.x, background.y = display.contentCenterX + 18, display.contentCenterY - 5
		backgroundGroup:insert(background)
 
		local filename = system.pathForFile( "content/particles/lava.spurts.json", system.ResourceDirectory )
		local emitterParams = json.decodeFile( filename )
		local lavaEmitter = display.newEmitter(emitterParams)
		lavaEmitter:start()
		lavaEmitter.x, lavaEmitter.y = display.contentCenterX, display.contentCenterY - 50
		backgroundGroup:insert(lavaEmitter)
	end
	drawNewBackground()

	local function drawBackground()
		
		backgroundGroup.images = {}
		for i = 1, 8 do
			backgroundGroup.images[i] = display.newImageRect(backgroundGroup, "content/lava_frames/lava"..i..".png", display.contentWidth, display.contentHeight)
			--backgroundGroup.images[i].anchorX, backgroundGroup.images[i].anchorY = 0, 0
			backgroundGroup:insert(backgroundGroup.images[i])
			backgroundGroup.images[i].isVisible = false
		end
		backgroundGroup.overlay = display.newRect(backgroundGroup, 0, 0, display.contentWidth, display.contentHeight)
		backgroundGroup.overlay:setFillColor(0,0,0,.2)
		local foreGroundImage = display.newImageRect(backgroundGroup, "content/foreground.png", display.contentWidth, display.contentHeight)
		backgroundGroup.timer = 0
		backgroundGroup.oldTime = 0
		backgroundGroup.deltaTime = 0
		backgroundGroup.currentFrame = 1
		backgroundGroup.x, backgroundGroup.y = display.contentCenterX, display.contentCenterY
		local function animateBackground(event)
			print("animateBackground: "..backgroundGroup.currentFrame)
			backgroundGroup.deltaTime = event.time - backgroundGroup.oldTime
			backgroundGroup.timer = backgroundGroup.timer + backgroundGroup.deltaTime
			backgroundGroup.oldTime = event.time
			if backgroundGroup.timer > 600 then
				backgroundGroup.images[backgroundGroup.currentFrame].isVisible = false
				backgroundGroup.timer = 0
				backgroundGroup.currentFrame = backgroundGroup.currentFrame + 1
				if backgroundGroup.currentFrame > 8 then
					backgroundGroup.currentFrame = 1
				end
				backgroundGroup.images[backgroundGroup.currentFrame].isVisible = true
			end
		end
		
		Runtime:addEventListener("enterFrame", animateBackground)
	end
	--drawBackground()

	local function makeAvatar()
		local function avatarOnFrame()
			keyGroup:insert(avatar)
			if avatar.currentKeyButton == nil then
				if #keyButtons > 0 then
					if avatar.nextKeyToJumpTo == nil then
						--pick a random key button to move to
						avatar.currentKeyButton = keyButtons[mRand(1, #keyButtons)]
						avatar:moveToKey(avatar.currentKeyButton)
					end
				end
			elseif avatar.isJumping == false then
				if avatar.hasIdleTarget == false then
					avatar:idleOnPlatform()
				end
			end
		end

		local sheetOptions = { frames = {}}
		local baseFrame = {y = 0, height = 94, width = 10}
		local xPositions = {1, 51, 104, 177, 252, 326}
		for i = 1, 5 do
			sheetOptions.frames[i] = {x = xPositions[i], width = xPositions[i+1]-xPositions[i],y = baseFrame.y, height = baseFrame.height}
		end
		local sheet = graphics.newImageSheet( "content/avatar.png", sheetOptions )
		local sequences = {
			{ name = "idle", start = 1, count = 2, time = 2000, loopCount = 0 },
			{ name = "move", start = 3, count = 2, time = 400, loopCount = 0 },
			{ name = "jump", start = 5, count = 1, time = 10000, loopCount = 0 },
		}
		avatar = display.newGroup()
		avatar.sprite = display.newSprite( avatar, sheet, sequences )
		avatar.sprite.xScale, avatar.sprite.yScale = .12, .12
		avatar.sprite:play()
		avatar.currentKeyButton = nil
		avatar.nextKeyToJumpTo = nil
		avatar.isJumping = false
		avatar.hasIdleTarget = false

		local platformOffsetY = -32
		local halfPlatformWidth, halfPlatformHeight = 20, 10

		local function triggerGameOver()
			gameParams:resetGame()
		end

		function avatar:fallToDeath()
			transition.cancel( "avatar" )
			avatar.sprite:setSequence("jump")
			transition.moveTo(avatar, {x = avatar.x, y = avatar.y +10, time = 1000, tag="avatar", onComplete = triggerGameOver})
			transition.scaleTo(avatar.sprite, {xScale = 0, yScale = 0, time = 1000, tag="avatar"})
		end

		function avatar:idleOnPlatform()
			avatar.hasIdleTarget = true
			transition.cancel( "avatar" )
			avatar.sprite:setSequence("move")
			avatar.sprite:play()
			local platform = avatar.currentKeyButton
			local xPos = math.random(platform.x - halfPlatformWidth, platform.x + halfPlatformWidth)
			if xPos > avatar.x then avatar.sprite.xScale = .15 else avatar.sprite.xScale = -.15 end
			local yPos = math.random(platform.y - halfPlatformHeight, platform.y + halfPlatformHeight) + platformOffsetY
			transition.moveTo(avatar, {x = xPos, y = yPos, time = 1000, tag="avatar", onComplete = function() avatar.hasIdleTarget = false end})
		end

		function avatar:moveToKey(keyButton)
			avatar.currentKeyButton = keyButton
			avatar.isJumping = true
			transition.cancel( "avatar" )
			avatar.sprite:setSequence("jump")
			if keyButton.x > avatar.x then avatar.sprite.xScale = .15 else avatar.sprite.xScale = -.15 end
			local function transBack() transition.to(avatar.sprite, { transition= easing.inCirc, time=500, y=(20) } ) end
			transition.to(avatar.sprite, { transition= easing.outCirc, time=500, y=(-20), tag="avatar",onComplete=transBack } )
			transition.moveTo(avatar, {x = keyButton.x, y = keyButton.y + platformOffsetY, time = 1000, tag="avatar", onComplete = function() avatar.isJumping = false; avatar.hasIdleTarget = false end})
		end
		
		function avatar:removeEventListener()
			Runtime:removeEventListener("enterFrame", avatarOnFrame)
		end
		Runtime:addEventListener("enterFrame", avatarOnFrame)
	end
	makeAvatar()

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


	local function layoutCalc() --calculates the layoutData table, instead we are loading the data from level_data.lua
		local totalCircum = 0
		for i = layoutRings, 1, -1 do --calculate data for the circles
			local ring = {}
			layoutData[#layoutData+1] = ring
			ring.radius = levelData.ringLayouts[i].radius
			ring.circum = 2 * pi * ring.radius
			totalCircum = totalCircum + ring.circum
		end
		for i = 1, #layoutData do --calculate letter count and angle for each ring
			local ring = layoutData[i]
			local percent = ring.circum / totalCircum
			ring.letterCount = levelData.ringLayouts[4-i].count --mRound(percent * #letterTable)
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
				letter.y = ringData.radius * math.sin(math.rad(angle)) * .9
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

	local screenBoundaryPoints = {[1] = {x = 0, y = 0}, [2] = {x = display.contentWidth, y = 0}, [3] = {x = display.contentWidth, y = display.contentHeight}, [4] = {x = 0, y = display.contentHeight}}
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
		--boundaryShape:setFillColor(.2,.5,.2,.2)
		boundaryShape:setFillColor(0,0,0,0)
		boundaryShape.strokeWidth = 4
		boundaryShape:setStrokeColor(1, 0, 0)
	end

	local function drawKeys(randomLetters) --draw display objects representing keys
		local function drawKey(x, y, letter)
			--local button = display.newRoundedRect(keyGroup, 0, 0, keySizeX, keySizeY, roundedEdgeSize)
			local randPlat = mRand(1,4) 
			local button = display.newImageRect(keyGroup, "content/platforms/"..randPlat..".png", keySizeX, keySizeY)
			keyButtons[#keyButtons+1] = button
			button.toggled = false
			button.canBeToggled = true
			--button:setFillColor(.3);
			button.letter = letter
			button.x = x
			button.y = y
			button.textRect = display.newText({ x = button.x, y = button.y - button.height*.3, text = letter,	width = 50,	font = gameFont, fontSize = 24, align = "center" })
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
				--print(button.letter.." is INSIDE boundary")
				if button.canBeToggled then --only set as visible if it hasn't already been outside a previous boundary
					button.isVisible = true
					button.textRect.isVisible = true
				end
			end
			
			function button:outsideBoundary()
				--print(button.letter.." is OUTSIDE boundary")
				button.isVisible = false
				button.textRect.isVisible = false
				button.canBeToggled = false
			end

			function button:addedToWord() --called from key event or when button is pressed
				if button.canBeToggled == false then
					return
				end
				if avatar then
					if avatar.isJumping == false then
						avatar:moveToKey(self)
					else
						avatar.nextKeyToJumpTo = self
					end
				end
				wordString = wordString..self.letter
				wordDisplayBox:updateText()
				button:setFillColor(.8)
				button.textRect:setFillColor(.8, 0, 0)
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
					button:setFillColor(1)
					button.textRect:setFillColor(1)
					button.toggled = false
				end
				updateBoundaryPointDisplay()
			end
			local function tapListener( event )
				event.target:addedToWord()
			end
			button:addEventListener( "tap", tapListener )  -- Add a "tap" listener to the object
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

		local levelDisplay = display.newText({text = "level: "..gameParams.level, font = native.systemFont, fontSize = 18, align = "left" })
		levelDisplay.anchorX, levelDisplay.anchorY = 0, 0
		levelDisplay.x = -display.contentCenterX + levelDisplay.width/2

		wordsRemainingDisplay = display.newText({x = levelDisplay.x, text = "words remaining: "..targetWordCount-submittedWordCount, font = native.systemFont, fontSize = 18, align = "left" })
		wordsRemainingDisplay.anchorX, wordsRemainingDisplay.anchorY = 0, 0
		wordsRemainingDisplay.y = levelDisplay.y + levelDisplay.height
		function wordsRemainingDisplay:update()
			wordsRemainingDisplay.text = "words remaining: "..targetWordCount-submittedWordCount
		end
		uiGroup:insert(levelDisplay)
		uiGroup:insert(wordsRemainingDisplay)
		wordDisplayBox = display.newRoundedRect(uiGroup,0,0,wordDisplayWidth,uiButtonHeight,roundedEdgeSize)
		wordDisplayBox.x = -90
		wordDisplayBox:setFillColor(.1)
		wordDisplayBox.strokeWidth = 3
		wordDisplayBox:setStrokeColor(.9)
		wordDisplayBox.textRect = display.newText({ x = wordDisplayBox.x, y = wordDisplayBox.y, text = "", font = gameFont, fontSize = 18, align = "center" })
		html5fix(wordDisplayBox.textRect)
		uiGroup:insert(wordDisplayBox.textRect)
		function wordDisplayBox:updateText()
			print("updating text: "..wordString)
			self.textRect.text = wordString
		end

		local backButton = display.newRoundedRect(uiGroup,wordDisplayBox.x + wordDisplayBox.width/2 + buttonOffset*1.5,0,uiButtonHeight,uiButtonHeight,12)
		backButton:setFillColor(.9)
		local backButtonText = display.newText({ x = backButton.x, y = backButton.y, text = "<", font = gameFont, fontSize = 18, align = "center" })
		html5fix(backButtonText)
		uiGroup:insert(backButtonText)
		backButtonText:setFillColor(0)

		local submitButton = display.newRoundedRect(uiGroup,backButton.x + backButton.width + backButton.width + buttonOffset,0,submitButtonWidth,uiButtonHeight,12)
		submitButton:setFillColor(.9)
		local submitButtonText = display.newText({ x = submitButton.x, y = submitButton.y, text = "submit", font = gameFont, fontSize = 18, align = "center" })
		html5fix(submitButtonText)
		uiGroup:insert(submitButtonText)
		submitButtonText:setFillColor(0)

		uiGroup.x = display.contentCenterX
		uiGroup.y = keyGroup.y + keyGroup.height/2 + buttonOffset * 3
		
		local function backListener( event )
			game.removeLetter()
		end
		backButton:addEventListener( "tap", backListener )  -- Add a "tap" listener to the object

		local function submitListener( event )
			game.submitWord()
		end
		submitButton:addEventListener( "tap", submitListener )  -- Add a "tap" listener to the object
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

	local function showError(errorString)
		
		local errorText = display.newText({ x = 0, y = wordDisplayBox.y - wordDisplayBox.height, text = errorString, font = native.systemFont, fontSize = 18, align = "center" })
		uiGroup:insert(errorText)
		errorText:setFillColor(1,0,0,1)

		transition.fadeOut(errorText, { time = 2000, onComplete = function() errorText:removeSelf() end });
		transition.moveTo(errorText, { time = 2000, y = errorText.y - 200, onComplete = function() errorText:removeSelf() end });

	end

	--for testing to get the enter keycode on html5
	local keyCodeDisplay = display.newText({ x = display.contentCenterX, y = display.contentCenterY, text = "", font = native.systemFont, fontSize = 18, align = "center" })
	keyCodeDisplay:setFillColor(1,0,0,1)

	local samplerFactory = {}
	local samplers = {}

	function samplers.checkForResults()
		--print("checking for results on "..#samplers.." samplers")
		local allResultsReceived = true
		for i = 1, #samplers do
			if samplers[i].receivedResult == false then
				allResultsReceived = false
			end
		end
		if allResultsReceived then
			--print("received all color samplerResults, samplers: "..#samplers)
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
		if avatar then
			local remainingKeys = {}
			for i = 1, #keyButtons do 
				if keyButtons[i].isVisible == true then
					remainingKeys[#remainingKeys+1] = keyButtons[i] --add to table of remaining keys for avatar to
				end
			end
			if #remainingKeys == 0 then
				--print("no remaining keys, idling on current platform")
				showError("no platforms left")
				avatar:fallToDeath()
			else
				local randomPlatform = remainingKeys[mRand(1, #remainingKeys)]
				avatar:moveToKey(randomPlatform)
			end
		end
	end

	function samplerFactory:new()
		local sampler = {}
		sampler.receivedResult, sampler.result = false, false
		samplers[#samplers+1] = sampler

		function sampler.resultListener(event) --function to be called by the colorSample event listener
			--keyCodeDisplay.text = "receiving samples"
			sampler.receivedResult = true
			--print("color sample result: "..event.r..", "..event.g..", "..event.b..", "..event.a)
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
			--print("sampling letter "..button.letter, buttonContentX, buttonContentY)
			--keyCodeDisplay.text = "setting sample listener"
			display.colorSample( buttonContentX, buttonContentY, sampler.resultListener )
			
			--also remove the selected keys
			if button.toggled == true then
				button:outsideBoundary()
			end
		end
		Runtime:addEventListener("enterFrame", samplers.checkForResults)
	end

	function game.submitWord()
		if wordString == lastSubmittedword then
			print("duplicate word")
			showError("'"..wordString.."' already submitted")
			return
		end

		local function checkWordList(inputWord)
			for i = 1, #words do
				if words[i] == inputWord then
					return true
				end
			end
		end
		print("submitting word: "..wordString)
		--keyCodeDisplay.text = "submitting word: "..wordString..", "..#words
		----keyCodeDisplay.text = words[500]
		if checkWordList(wordString) then
			print("word found")
			submittedWordCount = submittedWordCount + 1
			showError(submittedWordCount.."/"..targetWordCount.." words found")
			if submittedWordCount >= targetWordCount then
				print("level complete: "..submittedWordCount.."/"..targetWordCount.." words found")
				gameParams:nextLevel()
				return
			end
			wordsRemainingDisplay:update()
			lastSubmittedword = wordString
			--keyCodeDisplay.text = "word found"
			wordString = ""
			wordDisplayBox:updateText()
			removeWordsOutsideBoundary() --anything that happens after this needs to happen after the samplers.checkForResults() function is is completed
		else
			showError("'"..wordString.."' invalid")
			print("word not found")
		end
	end

	function game.removeLetter()
		local deletedLetter = sSub(wordString, sLen(wordString), sLen(wordString))
		if sLen (wordString) > 0 then
			wordString = sSub(wordString, 1, sLen(wordString) - 1)
			keyEventTable[deletedLetter]:removedFromWord() --call function to update key display, called after wordString updated for checking
			wordDisplayBox:updateText()
		end
	end

	function onKeyEvent(event)

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
				game.removeLetter()
			elseif event.keyName == "enter" then
				print("enter pressed")
				game.submitWord()
				return true
			end
		end
	end

end
	
 
-- -----------------------------------------------------------------------------------
-- Code outside of the scene event functions below will only be executed ONCE unless
-- the scene is removed entirely (not recycled) via "composer.removeScene()"
-- -----------------------------------------------------------------------------------
 
 
 
 
-- -----------------------------------------------------------------------------------
-- Scene event functions
-- -----------------------------------------------------------------------------------
 
-- create()
local scene = composer.newScene()

function scene:create( event )
	gameParams = event.params
 
    local sceneGroup = self.view
    -- Code here runs when the scene is first created but has not yet appeared on screen
 
end
 
 
-- show()
function scene:show( event )
 
    local sceneGroup = self.view
    local phase = event.phase
 
    if ( phase == "will" ) then
        -- Code here runs when the scene is still off screen (but is about to come on screen)
	runGame(sceneGroup)
	Runtime:addEventListener("key", onKeyEvent )
 
    elseif ( phase == "did" ) then

        -- Code here runs when the scene is entirely on screen
 
    end
end
 
 
-- hide()
function scene:hide( event )
 
    local sceneGroup = self.view
    local phase = event.phase
 
    if ( phase == "will" ) then

		Runtime:removeEventListener("key", onKeyEvent )
		avatar:removeEventListener()
		transition.cancelAll()
        -- Code here runs when the scene is on screen (but is about to go off screen)
 
    elseif ( phase == "did" ) then
        -- Code here runs immediately after the scene goes entirely off screen
 
    end
end
 
 
-- destroy()
function scene:destroy( event )
 
    local sceneGroup = self.view
    -- Code here runs prior to the removal of scene's view
 
end
 
 
-- -----------------------------------------------------------------------------------
-- Scene event function listeners
-- -----------------------------------------------------------------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )
-- -----------------------------------------------------------------------------------
 
return scene