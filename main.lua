-----------------------------------------------------------------------------------------
--
-- main.lua
--
-- thanks to @pixelprophecy.bsky.social for informing me this was on
--
-----------------------------------------------------------------------------------------

local sLen = string.len
local sSub = string.sub
---@diagnostic disable-next-line: undefined-field --this is defined by solar2d math library not recognised
local mRound = math.round
local mRand = math.random
local pi = math.pi
print(pi)

local sceneGroup = display.newGroup()
local keyGroup = display.newGroup()
keyGroup.anchorChildren = true
local uiGroup = display.newGroup()
uiGroup.anchorChildren = true
sceneGroup:insert(keyGroup)
sceneGroup:insert(uiGroup)

local letters = "abcdefghijklmnopqrstuvwxyz"
local letterTable = {}
for i = 1, sLen(letters) do
	letterTable[i] = sSub(letters, i, i)
end
local letterCount = #letterTable

local layoutData = {}
local layoutMaxRadius, layoutRings = 200, 3
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
		ring.letterCount = mRound(percent * letterCount)
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

local keys = {}
local keySizeX, keySizeY = 50, 50

local function drawKeys() --draw display objects representing keys
	local function drawKey(x, y, letter)
		local button = display.newRect(keyGroup, 0, 0, keySizeX, keySizeY)
		button:setFillColor(.3);
		button.x = x
		button.y = y
		button.textRect = display.newText({ x = button.x, y = button.y, text = letter,	width = 50,	font = native.systemFont, fontSize = 18, align = "center" })
		keyGroup:insert(button.textRect)
		return button
	end
	
	local count = 1
	for i = 1, #layoutData do
		local ringData = layoutData[i]
		for i2 = 1, #ringData.letters do
			keys[count] = drawKey(ringData.letters[i2].x, ringData.letters[i2].y, letterTable[count])
			count = count + 1
		end
	end
	keyGroup.x, keyGroup.y = display.contentCenterX, display.contentCenterY - display.contentCenterY / 5
end

local function drawUI()
	local displayButtonHeight = 40
	local buttonOffset = 20
	local wordDisplayWidth = 300
	local submitButtonWidth = 130
	local wordDisplay = display.newRoundedRect(uiGroup,0,0,wordDisplayWidth,displayButtonHeight,12)
	wordDisplay:setFillColor(.2)
	wordDisplay.strokeWidth = 3
	wordDisplay:setStrokeColor(1)
	local submitButton = display.newRoundedRect(uiGroup,wordDisplayWidth/2 + submitButtonWidth/2 + buttonOffset,0,submitButtonWidth,displayButtonHeight,12)
	local submitButtonText = display.newText({ x = submitButton.x, y = submitButton.y, text = "submit", font = native.systemFont, fontSize = 18, align = "center" })
	uiGroup:insert(submitButtonText)
	submitButtonText:setFillColor(0)
	uiGroup.x = display.contentCenterX
	uiGroup.y = keyGroup.y + keyGroup.height/2 + buttonOffset * 3
end

layoutCalc()
--debugDraw()
drawKeys()
drawUI()