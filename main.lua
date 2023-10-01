-----------------------------------------------------------------------------------------
--
-- main.lua
--
-- thanks to @pixelprophecy.bsky.social for informing me this was on
--
-----------------------------------------------------------------------------------------
local composer = require("composer")

display.setDefault( "magTextureFilter", "nearest" )
display.setDefault( "minTextureFilter", "nearest" )

local gameParams = {}
gameParams.level = 1

local blankSceneParams = {} --used to pass function to know when it's loaded
function blankSceneParams.isDisplayed()
	composer.gotoScene("game", {effect = "fade", time = 400, params = gameParams})
end


function gameParams:nextLevel()
	self.level = self.level + 1
	composer.removeScene("game")
	composer.gotoScene("blank_scene", {effect = "fade", time = 400, params = blankSceneParams})
end

composer.gotoScene("blank_scene", {params = blankSceneParams})