-- ADDED PHYSICS ENGINE
local physics = require("physics")
physics.setDrawMode( "hybrid" )
physics.start()
 
----------------------------------------------------------------------------------------
-- Abstract: Bezier Handle Manipulation in Corona SDK
--
-- Sample code is MIT licensed, see http://developer.anscamobile.com/code/license
-- Copyright (C) 2010 ANSCA Inc. All Rights Reserved.
--
-- Demonstrates how to create bezier segment.
-- Not optmized. Just done. Feel free to modify at your hearts content.
--
----------------------------------------------------------------------------------------
 
display.setStatusBar( display.HiddenStatusBar )
 
local segMents = {};
local bezierSegment = {x,y};
local endCaps = {};
local tempCaps = {};
local tempBG = {};
local handleDot = {};
 
local FALSE = 0;
local TRUE  = 1;
local moved = FALSE;
local numPoints = 0;
local NUMPOINTS = 200;
local gSegments;
 
local bbg = nil;
----------------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------------
 
local function destroyBezierSegment()
 
        segMents = nil;
        segMents = {};
        handleDot = nil
        handleDot = {};
end
 
----------------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------------
 
local function drawBezierSegment(granularity,r,g,b)
 
        if line then
                line:removeSelf()
        end
 
        line = display.newLine(bezierSegment[1].x,bezierSegment[1].y,bezierSegment[2].x,bezierSegment[2].y);
        for i = 3, granularity, 1 do
                line:append( bezierSegment[i].x,bezierSegment[i].y);
        end
        line:setColor(r,g,b);
        line.width=2;
end
 
 
----------------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------------
 
local function setupBezierSegment(granularity)
 
        local inc = (1.0 / granularity);
 
        for i = 1, #endCaps,4 do
 
        local t = 0;
        local t1 = 0;
        local i = 1;
 
        for j = 1, granularity do
 
                        t1 = 1.0 - t;
 
                        local t1_3 = t1*t1*t1
                        local t1_3a = (3*t)*(t1*t1)
                        local t1_3b = (3*(t*t))*t1;
                        local t1_3c = (t * t * t )
 
                        local p1 = endCaps[i];
                        local p2 = endCaps[i+1];
                        local p3 = endCaps[i+2];
                        local p4 = endCaps[i+3];
 
                        local   x = t1_3  * p1.x;
                        x =     x + t1_3a * p2.x;
                        x =     x + t1_3b * p3.x;
                        x =             x + t1_3c * p4.x
 
                        local   y = t1_3  * p1.y;
                        y =     y + t1_3a * p2.y;
                        y =     y + t1_3b * p3.y;
                        y =             y + t1_3c * p4.y;
 
                        bezierSegment[j].x = x;
                        bezierSegment[j].y = y;
                        t = t + inc;
 
                end
        end
end
----------------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------------
 
local function drawBezierHandles()
 
        if ( gSegments ) then
                gSegments:removeSelf()
        end
 
        gSegments = display.newGroup()
 
        for i = 1,#endCaps,2 do
                local line = display.newLine(endCaps[i].x,endCaps[i].y,endCaps[i+1].x,endCaps[i+1].y);
                line:setColor(128,128,128);
                line.width=1;
                gSegments:insert( line )
                table.insert(segMents,line);
        end
 
end
 
----------------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------------
 
local function setupBezier(granularity,r,g,b)
 
        -- DONT DRAW HANDLES TO MAINTAIN ROPE ILLUSION
        -- 1st draw anchor points and handles
        drawBezierHandles();
 
        -- 2nd setupBezierSegment
        setupBezierSegment(granularity);
 
        -- 3rd draw the segment
        drawBezierSegment(granularity,r,g,b);
 
        -- 4th destroy the segment
        destroyBezierSegment();
 
 
end
----------------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------------
 
local function draw (event )
        -- ALLOW ROPE TO REDRAW EVERY FRAME
        --if ( moved == TRUE ) then
                setupBezier(50,128,128,128)
                return true;
        --end
end
 
----------------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------------
 
local function dragHandles(event)
 
        local t = event.target
 
        local phase = event.phase
        if "began" == phase then
                -- Make target the top-most object
                local parent = t.parent
                parent:insert( t )
                display.getCurrentStage():setFocus( t )
 
                t.isFocus = true
 
                t.x0 = event.x - t.x
                t.y0 = event.y - t.y
 
                elseif t.isFocus then
                if "moved" == phase then
                        -- Make object move (we subtract t.x0,t.y0 so that moves are
                        -- relative to initial grab point, rather than object "snapping").
                        t.x = event.x - t.x0
                        t.y = event.y - t.y0
 
                        moved = TRUE;
 
                elseif "ended" == phase or "cancelled" == phase then
                        display.getCurrentStage():setFocus( nil )
                        t.isFocus = false
                        moved = FALSE;
                        setupBezier(100,255,128,0);
                end
        end
 
        return true
 
end
 
----------------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------------
 
local function addListeners()
 
        for i  = 1 , #endCaps, 1 do
                endCaps[i]:addEventListener("touch",dragHandles);
        end
 
end
 
----------------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------------
 
local function addPoints (event )
 
        numPoints = numPoints + 1;
 
        if ( numPoints <= 4) then
 
                 local point = {}
                 point.x = event.x;
                 point.y = event.y;
 
                 local c = display.newCircle(point.x, point.y,10);
                 c:setFillColor(255,0,0);
                 table.insert (endCaps,c);
 
        end
 
        -- ONCE ALL CONTROL POINTS ARE DRAWN MAKE THEM PHYSICS OBJECTS AND JOIN WITH DISTANCE JOINTS
        if (numPoints == 4) then
                physics.addBody(endCaps[1], "static", {friction=.1, bounce=0, density=1, radius=10})
                for i=2, #endCaps do
                        physics.addBody(endCaps[i], "dynamic", {friction=.1, bounce=0, density=1, radius=10})
                        endCaps[i-1].joint = physics.newJoint("distance",endCaps[i-1],endCaps[i],endCaps[i-1].x,endCaps[i-1].y,endCaps[i].x,endCaps[i].y)
                        if (i<4) then endCaps[i].alpha=0 end
                end
 
                Runtime:removeEventListener("tap",addPoints)
                addListeners()
                setupBezier(100,255,128,0);
                Runtime:addEventListener("enterFrame",draw);
        end
end
 
----------------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------------
 
local function initBezierSegment()
 
        for j = 1, 100, 1 do
 
                local pt = {};
                pt.x = 0;
                pt.y = 0;
                table.insert(bezierSegment,pt);
 
        end
end
 
----------------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------------
 
 
local function main()
 
        initBezierSegment()
        Runtime:addEventListener("tap",addPoints);
end
 
----------------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------------
 
main()

