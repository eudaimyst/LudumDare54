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

local letters = { "qwertyuiop", "asdfghjkl", "zxcvbnm" }
local rowOffsets = {0, .4, 1.2}
local keySizeX, keySizeY = 50, 50
local keySpacingX, keySpacingY = 20, 20
local keys = {}

local _letterRow, _letter --recycled
local function drawKeys() --draw display objects representing keys
	for i = 1, #letters do
		_letterRow = letters[i]
		keys.row = {}
		for i2 = 1, sLen(_letterRow) do
			_letter = sSub(_letterRow, i2, i2)
			local button = display.newRect(keyGroup, 0, 0, keySizeX, keySizeY)
			button:setFillColor(.3);
			button.x = (keySizeX + keySpacingX) * (i2-1)  + button.width * rowOffsets[i]
			button.y = (keySizeY + keySpacingY) * (i-1)
			button.textRect = display.newText({ x = button.x, y = button.y, text = _letter,	width = 50,	font = native.systemFont, fontSize = 18, align = "center" })
			keyGroup:insert(button.textRect)
		end
	end
	keyGroup.anchorChildren = true
	keyGroup.x, keyGroup.y = display.contentCenterX, display.contentCenterY
end

drawKeys()