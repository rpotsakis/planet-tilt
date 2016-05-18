-----------------------------------------------------------------------------------------
--
-- level1.lua
--
-----------------------------------------------------------------------------------------
local widget = require( "widget" )
local storyboard = require( "storyboard" )
local scene = storyboard.newScene()

-- include Corona's "physics" library
local physics = require "physics"
physics.start(); physics.pause()

math.randomseed( os.time() )

--------------------------------------------

-- forward declarations and other locals
local screenW, screenH, halfW = display.contentWidth, display.contentHeight, display.contentWidth*0.5
local shieldGroup

-----------------------------------------------------------------------------------------
-- BEGINNING OF YOUR IMPLEMENTATION
-- 
-- NOTE: Code outside of listener functions (below) will only be executed once,
--		 unless storyboard.removeScene() is called.
-- 
-----------------------------------------------------------------------------------------

-- Called when the scene's view does not exist:
function scene:createScene( event )
local group = self.view

end -- end createscene

-- Called immediately after scene has moved onscreen:
function scene:enterScene( event )
	local group = self.view
	
	physics.start()
  
  	local group = self.view
  
  --set up some references and other variables
  local ox, oy = math.abs(display.screenOriginX), math.abs(display.screenOriginY)
  local cw, ch = display.contentWidth, display.contentHeight

  --set up collision filters
  local screenFilter = { categoryBits=2, maskBits=1 }
  local objFilter = { categoryBits=1, maskBits=14 }
  local fieldFilter = { categoryBits=4, maskBits=1 }
  local magnetFilter = { categoryBits=8, maskBits=1 }

  --set initial magnet pull
  local magnetPull = 0.25

  --set up world and background
  local back = display.newImageRect( "images/pt-background.png", 768, 1024 ) ; back.x = cw/2 ; back.y = ch/2 ; back:scale( 1.4,1.4 )
  group:insert(back)
  
  local screenBounds = display.newRect( -ox, -oy, display.contentWidth+ox+ox, display.contentHeight+oy+oy )
  screenBounds.name = "screenBounds"
  screenBounds.isVisible = false ; physics.addBody( screenBounds, "static", { isSensor=true, filter=screenFilter } )
  local magnet
  

  -- score display
  local score = 0
  local scoreNumber = display.newText(score, 10, 0, nil, 50)
  scoreNumber.xScale = .8
  scoreNumber.yScale = .8
  group:insert(scoreNumber)

  -- pulse functions
  local pulseOn, pulseOff

  function pulseOn(e)
    transition.to(magnet,{time=500,alpha=1})
  end

  function pulseOff(e)
    transition.to(magnet,{time=500,alpha=0, onComplete=pulseOn})
  end


  local function newPositionVelocity( object )

    local math_random = math.random
    local side = math_random( 1,4 ) ; local posX ; local posY ; local velX ; local velY

    if ( side == 1 or side == 3 ) then
      posX = math_random(0,display.pixelHeight)
      velX = math_random( -10,10 ) * 5
      if ( side == 1 ) then posY = -oy-40 ; velY = math_random( 8,18 ) * 16
      else posY = display.contentHeight+oy+40 ; velY = math_random( 8,16 ) * -16
      end
    else
      posY = math_random(0,display.pixelWidth)
      velY = math_random( -10,10 ) * 5
      if ( side == 4 ) then posX = -ox-40 ; velX = math_random( 8,16 ) * 16
      else posX = display.contentWidth+ox+40 ; velX = math_random( 8,16 ) * -16
      end
    end
    object.x = posX ; object.y = posY
    object:setLinearVelocity( velX, velY )
    object.angularVelocity = math_random( -3,3 ) * 40
    object.alpha = 1

  end



  local function objectCollide( self, event )

    local otherName = event.other.name
    --print(event.other.name)
    
    local function onDelay( event )
      local action = ""
      if ( event.source ) then action = event.source.action ; timer.cancel( event.source ) end
      
      if ( action == "makeJoint" ) then
        self.hasJoint = true
        self.touchJoint = physics.newJoint( "touch", self, self.x, self.y )
        self.touchJoint.frequency = magnetPull
        self.touchJoint.dampingRatio = 0.0
        self.touchJoint:setTarget( display.contentCenterX, display.contentCenterY )
      elseif ( action == "leftField" ) then
        self.hasJoint = false ; self.touchJoint:removeSelf() ; self.touchJoint = nil
      else
        if ( self.hasJoint == true ) then self.hasJoint = false ; self.touchJoint:removeSelf() ; self.touchJoint = nil end
        newPositionVelocity( self )
      end
    end

    if ( event.phase == "ended" and otherName == "screenBounds" ) then
      local tr = timer.performWithDelay( 10, onDelay ) ; tr.action = "leftScreen"
    elseif ( event.phase == "began" and otherName == "magnet" ) then
      -- collided with magnet
      transition.to( self, { time=400, alpha=0, onComplete=onDelay } )
      score = score + 1
      scoreNumber.text = score
      
      transition.to(magnet,{time=500,alpha=0, onComplete = pulseOn})
      
  elseif ( event.phase == "began" and otherName == "seg" ) then
      -- collided with shield
      --transition.to( self, { time=400, alpha=0, onComplete=onDelay } )
      --self.removeObject()
      event.other:removeSelf()
      event.other = nil
      
      transition.to( self, { time=100, alpha=0 } )
      self:removeSelf() -- TODO: confirm this is OK
      
    elseif ( event.phase == "began" and otherName == "field" and self.hasJoint == false ) then
      local tr = timer.performWithDelay( 10, onDelay ) ; tr.action = "makeJoint"
    elseif ( event.phase == "ended" and otherName == "field" and self.hasJoint == true ) then
      local tr = timer.performWithDelay( 10, onDelay ) ; tr.action = "leftField"
    end

  end


  local function fireProj( event )
    if(event.phase == "ended") then
       local proj = display.newImageRect( "images/object.png", 64, 64 )
       physics.addBody( proj, { bounce=0.2, density=1.0, radius=14 } )
       proj.x, proj.y = event.xStart, event.yStart
       local vx, vy = event.x-event.xStart, event.y-event.yStart
       proj:setLinearVelocity( vx,vy )
       proj.hasJoint = false
       proj.collision = objectCollide ; proj:addEventListener( "collision", proj )
    end
  end
  --Runtime:addEventListener( "touch", fireProj )


  local function setupShield()
     --build shield
    local circleLength = 0
    local circleRadius = 128
    local circleCircum = 2 * math.pi * circleRadius
    local a = 0 -- radiens
    local deg = 0
    local ax, ay, bx, by = 0
    local segCount = 0
    local prevBody = nil
    
    if(shieldGroup ~= nil) then
      shieldGroup:removeSelf()
     end
    shieldGroup = display.newGroup()
    
  --  shieldGroup.x = display.contentCenterX
  --  shieldGroup.y = display.contentCenterY
  --  shieldGroup:setReferencePoint(display.CenterReferencePoint)
  --  print(shieldGroup.xReference)
  --  print(shieldGroup.yReference)
  --  print(shieldGroup.x)
  --  print(shieldGroup.y)
    
    -- first segment of sheild
    bx = display.contentCenterX + circleRadius * math.cos(a)
    by = display.contentCenterY + circleRadius * math.sin(a)
     
  --  local seg = display.newLine( display.contentCenterX + circleRadius, display.contentCenterY + circleRadius, bx, by)
  --  seg:setColor( 255, 102, 102, 255 )
  --  seg.width = 3
  --  seg.x = 25
  --  seg.y = 250
    
  --  shieldGroup:insert( seg )
    
    -- 2 pi rads = 360
    while deg < 360 do
      --ax = display.contentCenterX + circleRadius * math.cos(a)
      --ay = display.contentCenterY + circleRadius * math.sin(a)
      ax = bx
      ay = by
      deg = deg + 6
      a = (deg/360) * (2 * math.pi)
      
      
      bx = display.contentCenterX + circleRadius * math.cos(a)
      by = display.contentCenterY + circleRadius * math.sin(a)
      
      
      --seg = display.newLine( ax, ay, bx, by)
  --    seg.width = 5
      seg = display.newImage("images/crate.png")
      seg.x = bx
      seg.y = by
      seg.xScale = 0.1
      seg.yScale = 0.1
      seg.name = "seg"
      
      if(segCount <=20) then
        seg:setFillColor( 255, 0, 0, 255 )
      elseif(segCount <= 40) then
        seg:setFillColor( 0, 255, 0, 255 )
      else
        seg:setFillColor( 0, 0, 255, 255 )
      end
      --if(segCount <=3) then
  --      seg:setColor( 255, 0, 0, 255 )
  --    elseif(segCount <= 6) then
  --      seg:setColor( 0, 255, 0, 255 )
  --    else
  --      seg:setColor( 0, 0, 255, 255 )
  --    end
      
      
      shieldGroup:insert( seg )
      segCount = segCount + 1
      physics.addBody( seg, "dynamic", { bounce=1, radius=16 } )
      local segPivotJoint = physics.newJoint("weld", seg, magnet, magnet.x, magnet.y);
      
  --  if(prevBody ~= nil) then
  --      local joint = physics.newJoint( "pivot", prevBody, seg, bx, by )
  --  end
       
      prevBody = seg
      
    end
  end


  local function setupWorld()

    for i=1, 3 do
      local obj = display.newImageRect( "images/pt-rock" .. i .. ".png", 48, 48 )
      physics.addBody( obj, { bounce=0, radius=12 } ) -- NOTE add "filter=objFilter" in order to prevent obj-obj collisions
      newPositionVelocity( obj )
      
      -- hasJoint makes obj react to field
      obj.hasJoint = false
      obj.collision = objectCollide ; obj:addEventListener( "collision", obj )
      group:insert(obj)
    end

    local field = display.newImageRect( "images/field.png", 660, 660 ) ; field.alpha = 0.3
    field.name = "field"
    field.x = display.contentCenterX ; field.y = display.contentCenterY
    physics.addBody( field, "static", { isSensor=true, radius=320, filter=fieldFilter } )
    group:insert(field)
    
    -- physics object for planet
    magnet = display.newImageRect( "images/magnet.png", 128, 128 )
    magnet.name = "magnet"
    magnet.x = display.contentCenterX ; magnet.y = display.contentCenterY
    physics.addBody( magnet, "static", { bounce=0, radius=40, filter=magnetFilter } )
    group:insert(magnet)
    
    -- visual skin for planet
    planet = display.newImageRect( "images/pt-planet.png", 128, 128 )
    planet.name = "magnet"
    planet.x = display.contentCenterX ; planet.y = display.contentCenterY
    group:insert(planet)
    
    setupShield()
    
    
    
    --physics.addBody( shieldGroup, "static", { bounce=0, radius=40 } )
    
    

    -- rotate
    local xstart = 0
    local function rotateMagnet( event )
      
      if event.phase == "began" then
        
        xstart = event.xStart
        
      elseif (event.phase == "moved") then
        
        local xdist = (xstart - event.x) / display.contentWidth
        local deg = xdist * 360 *.5
        
        
         
         --transition.to( magnet, { rotation = deg, time=500 } )
         --print(deg)
         magnet.rotation = deg
         
         for i=1,shieldGroup.numChildren do
          local child = shieldGroup[i]
          --child.x = child.x + 25 * deg
          --transition.to( child, { rotation = deg, time=500 } )
          child.rotation = deg
         end
        
      elseif (event.phase == "ended") then
        
        
      end
    end
    Runtime:addEventListener( "touch", rotateMagnet )
    
  end

  setupWorld()



  local function onButtonEvent( event )
     local phase = event.phase
     local target = event.target
        if ( "began" == phase ) then
        print( target.id .. " pressed" )
        -- target:setLabel( "Pressed" )  --set a new label
        -- setupShield()
        storyboard.gotoScene( "menu", "fade", 500 )
     elseif ( "ended" == phase ) then
        print( target.id .. " released" )
        --target:setLabel( target.baseLabel )  --reset the label
     end
     return true
  end

  local myButton = widget.newButton
  {
     left = 320,
     top = 0,
     label = "Reset",
     labelAlign = "center",
     font = "Arial",
     fontSize = 26,
     labelColor = { default = {0,0,0}, over = {255,255,255} },
     onEvent = onButtonEvent
  }
  myButton.baseLabel = "Reset"
  group:insert(myButton)
  
	
end

-- Called when scene is about to move offscreen:
function scene:exitScene( event )
	local group = self.view
  
	physics.stop()
	
  shieldGroup:removeSelf()
  
end

-- If scene's view is removed, scene:destroyScene() will be called just prior to:
function scene:destroyScene( event )
	local group = self.view
	
	package.loaded[physics] = nil
	physics = nil
  
  shieldGroup = nil
end

-----------------------------------------------------------------------------------------
-- END OF YOUR IMPLEMENTATION
-----------------------------------------------------------------------------------------

-- "createScene" event is dispatched if scene's view does not exist
scene:addEventListener( "createScene", scene )

-- "enterScene" event is dispatched whenever scene transition has finished
scene:addEventListener( "enterScene", scene )

-- "exitScene" event is dispatched whenever before next scene's transition begins
scene:addEventListener( "exitScene", scene )

-- "destroyScene" event is dispatched before view is unloaded, which can be
-- automatically unloaded in low memory situations, or explicitly via a call to
-- storyboard.purgeScene() or storyboard.removeScene().
scene:addEventListener( "destroyScene", scene )

-----------------------------------------------------------------------------------------

return scene