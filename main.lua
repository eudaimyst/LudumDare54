-----------------------------------------------------------------------------------------
--
-- main.lua
--
-- thanks to @pixelprophecy.bsky.social for informing me this was on
--
-----------------------------------------------------------------------------------------

local sLen = string.len
local sSub = string.sub

local sceneGroup = display.newGroup()
local keyGroup = display.newGroup()
sceneGroup:insert(keyGroup)

local letters = "abcdefghijklmnopqrstuvwxyz"
local letterTable = {}
for i = 1, sLen(letters) do
	letterTable[i] = sSub(letters, i, i)
end
local letterCount = #letterTable


local keySizeX, keySizeY = 50, 50
local layoutData = {}
local layoutMaxRadius, layoutRings = 200, 3
local keys = {}

local _letterRow, _letter --recycled

local function layoutCalc() --calculates the layoutData table
	for i = layoutRings, 1, -1 do
		local ring = {}
		layoutData[#layoutData+1] = ring
		ring.radius = layoutMaxRadius / layoutRings * i
	end
end

local function debugDraw()
	local baseColor = { [1]= .2,[2]= .2,[3]= .2,[4]= .2 }
	local debugGroup = display.newGroup()
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

local function drawKeys() --draw display objects representing keys
end

layoutCalc()
debugDraw()
drawKeys()