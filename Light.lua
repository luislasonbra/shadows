module("shadows.Light", package.seeall)

Shadows = require("shadows")
Transform = require("shadows.Transform")

Light = {}
Light.__index = Light

Light.Arc = 360
Light.Radius = 0
Light.SizeRadius = 10
Light.Blur = true

Light.R, Light.G, Light.B, Light.A = 255, 255, 255, 255

halfPi = math.pi * 0.5

function Light:new(World, Radius)
	-- Class constructor
	if World and Radius then
		
		local self = setmetatable({}, Light)
		
		self.Transform = Transform:new()
		self.Transform:SetLocalPosition(0, 0, 1)
		self.Transform.Object = self
		
		self.Radius = Radius
		self.Canvas = love.graphics.newCanvas( Radius * 2, Radius * 2 )
		self.ShadowCanvas = love.graphics.newCanvas( Radius * 2, Radius * 2 )
		
		World:AddLight(self)
		
		return self
		
	end
	
end

function Light:GenerateShadows(x, y, z, Layer)
	
	local Shapes = {}
	local newZ
	
	for Index = self.World.Bodies:GetLength(), 1, -1 do
		
		local Body = self.World.Bodies:Get(Index)
		local Physics = Body:GetPhysics()
		-- If a body has been removed from the local reference, the light has moved, or the body has moved
		
		if Physics then
			-- Get the physics shapes of the physics body
			local FixtureList = Physics:getFixtureList()
			
			for i = 1, #FixtureList do
				
				local Shape = FixtureList[i]:getShape()
				-- It must be a type of shape that is supported by the engine
				if Shape.GenerateShadows then
					
					local SqrRadius = self.Radius * self.Radius + Shape:GetSqrRadius(Body)
					local ShapeX, ShapeY, ShapeZ = Shape:GetPosition(Body)
					local dx, dy, dz = ShapeX - x, ShapeY - y, Layer
					
					if ShapeZ <= Layer then
						-- All the remaining bodies on the iteration will have a ShapeZ lower than 'Layer' so just return the shapes and the new z
						return Shapes, newZ
						
					end
					
					-- Is the light in the draw range?
					if dx * dx + dy * dy + dz * dz < SqrRadius then
						
						Shape:GenerateShadows(Shapes, Body, 0, 0, dz, self)
						
						if not newZ or ShapeZ < newZ then
							
							newZ = ShapeZ
							
						end
						
					end
					
				end
				
			end
			
		else
			
			local ShapesList = Body:GetShapes()
			
			for i = ShapesList:GetLength(), 1, -1 do
				
				local Shape = ShapesList:Get(i)
				local SqrRadius = self.Radius * self.Radius + Shape:GetSqrRadius()
				local ShapeX, ShapeY, ShapeZ = Shape:GetPosition()
				local dx, dy, dz = ShapeX - x, ShapeY - y, Layer
				
				if ShapeZ <= Layer then
					-- All the remaining bodies on the iteration will have a ShapeZ lower than 'Layer' so just return the shapes and the new z
					return Shapes, newZ
					
				end
				
				-- Is the light in the draw range?
				if dx * dx + dy * dy + dz * dz < SqrRadius then
					
					Shape:GenerateShadows(Shapes, Body, 0, 0, dz, self)
					
					if not newZ or ShapeZ < newZ then
						
						newZ = ShapeZ
						
					end
					
				end
				
			end
			
		end
		
	end
	
	return Shapes, newZ
	
end

function Light:GetCanvasCenter()
	
	local x, y, z = self.Transform:GetPosition()
	
	return self.Radius, self.Radius, z
	
end

function Light:GenerateDarkness(x, y, z)
	
	local MinAltitude = 0
	local MinAltitudeLast
	
	while MinAltitude ~= MinAltitudeLast and MinAltitude and MinAltitude < z do
		
		local Layer = MinAltitude
		
		-- Shadow shapes should subtract white color, so that you see black
		love.graphics.setBlendMode("subtract", "alphamultiply")
		love.graphics.setColor(255, 255, 255, 255)
		
		-- Produce the shadow shapes
		MinAltitudeLast = MinAltitude
		Shapes, MinAltitude = self:GenerateShadows(x, y, z, Layer)
		
		-- Draw the shadow shapes
		for Index = 1, #Shapes do
			
			Shapes[Index]:Draw(MinAltitude)
			
		end
		
		-- Draw the shapes over the shadow shapes, so that the shadow of a object doesn't cover another object
		love.graphics.setBlendMode("add", "alphamultiply")
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.setShader()
		
		for Index = self.World.Bodies:GetLength(), 1, -1 do
			
			local Body = self.World.Bodies:Get(Index)
			local Bx, By, Bz = Body:GetPosition()
			
			if Bz <= Layer then
				
				break
				
			end
			
			-- As long as this body is on top of the layer
			Body:DrawRadius(x, y, self.Radius)
			
		end
		
	end
	
end

function Light:Update()
	
	if self.Changed or self.World.Changed or self.Transform.HasChanged then
		
		local x, y, z = self.Transform:GetPosition()
		
		-- Generate new content for the shadow canvas
		love.graphics.setCanvas(self.ShadowCanvas)
		love.graphics.setShader()
		love.graphics.clear(255, 255, 255, 255)
		
		-- Move all the objects so that their position local to the light are corrected
		love.graphics.translate(self.Radius - x, self.Radius - y)
		
		self:GenerateDarkness(x, y, z)
		
		self.Moved = nil
		
		-- This needs to be put right after self:GenerateShadows, because it uses the self.Transform.HasChanged field
		if self.Transform.HasChanged then
			-- If the light has moved, mark it as it hasn't so that it doesn't update until self.Transform.HasChanged is set to true
			self.Transform.HasChanged = false
			
		end
		
		-- Draw custom shadows
		love.graphics.setBlendMode("subtract", "alphamultiply")
		love.graphics.setColor(255, 255, 255, 255)
		self.World:DrawShadows(self)
		
		-- Draw the sprites so that shadows don't cover them
		love.graphics.setShader(Shadows.ShapeShader)
		love.graphics.setBlendMode("add", "alphamultiply")
		love.graphics.setColor(255, 255, 255, 255)
		self.World:DrawSprites(self)
		
		-- Now stop using the shadow canvas and generate the light
		love.graphics.setCanvas(self.Canvas)
		love.graphics.setShader()
		love.graphics.clear()
		love.graphics.origin()
		
		if self.Image then
			-- If there's a image to be used as light texture, use it
			love.graphics.setBlendMode("lighten", "premultiplied")
			love.graphics.setColor(self.R, self.G, self.B, self.A)
			love.graphics.draw(self.Image, self.Radius, self.Radius)
			
		else
			-- Use a shader to generate the light
			Shadows.LightShader:send("Radius", self.Radius)
			Shadows.LightShader:send("Center", {self.Radius, self.Radius, z})
			
			-- Calculate the rotation of the light
			local Arc = math.rad(self.Arc * 0.5)
			local Angle = self.Transform:GetRadians(-halfPi)
			
			-- Set the light shader
			love.graphics.setShader(Shadows.LightShader)
			love.graphics.setBlendMode("alpha", "premultiplied")
			
			-- Filling it with a arc is more efficient than with a rectangle for this case
			love.graphics.setColor(self.R, self.G, self.B, self.A)
			love.graphics.arc("fill", self.Radius, self.Radius, self.Radius, Angle - Arc, Angle + Arc)
			
			-- Unset the shader
			love.graphics.setShader()
			
		end
		
		if self.Blur then
			
			-- Generate a radial blur (to make the light softer)
			love.graphics.setShader(Shadows.RadialBlurShader)
			Shadows.RadialBlurShader:send("Size", {self.Canvas:getDimensions()})
			Shadows.RadialBlurShader:send("Position", {self.Radius, self.Radius})
			Shadows.RadialBlurShader:send("Radius", self.Radius)
			
		end
		
		-- Now apply the blur along with the shadow shapes over the light canvas
		love.graphics.setBlendMode("multiply", "alphamultiply")
		love.graphics.draw(self.ShadowCanvas, 0, 0)
		
		-- Reset the blending mode
		love.graphics.setBlendMode("alpha", "alphamultiply")
		
		-- Tell the world it needs to update it's canvas
		self.Changed = nil
		self.World.UpdateCanvas = true
		
	end
	
end

function Light:SetAngle(Angle)
	
	self.Transform:SetLocalRotation(Angle)
	
	return self
	
end

function Light:GetAngle()
	
	return self.Transform:GetRotation()
	
end

function Light:SetPosition(x, y, z)
	
	self.Transform:SetLocalPosition(x, y, z)
	
	return self
	
end

function Light:GetPosition()
	
	return self.Transform:GetPosition()
	
end

function Light:SetColor(R, G, B, A)
	
	if R ~= self.R then
		
		self.R = R
		self.Changed = true
		
	end
	
	if G ~= self.G then
		
		self.G = G
		self.Changed = true
		
	end
	
	if B ~= self.B then
		
		self.B = B
		self.Changed = true
		
	end
	
	if A ~= self.A then
		
		self.A = A
		self.Changed = true
		
	end
	
	return self
	
end

function Light:GetColor()
	
	return self.R, self.G, self.B, self.A
	
end

function Light:SetImage(Image)
	
	if Image ~= self.Image then
		
		local Width, Height = Image:getDimensions()
		
		self.Image = Image
		self.Radius = math.sqrt( Width * Width + Height * Height ) * 0.5
		self.Changed = true
		
	end
	
end

function Light:GetImage()
	
	return self.Image
	
end

function Light:SetRadius(Radius)
	
	if Radius ~= self.Radius then
		
		self.Radius = Radius
		self.Changed = true
		
	end
	
end

function Light:GetRadius()
	
	return self.Radius
	
end

function Light:Remove()
	
	if self.World then
		
		self.World.Lights[self.ID] = nil
		self.World.Changed = true
		self.World = nil
		self.ID = nil
		
		self.Transform:SetParent(nil)
		
	end
	
end

function Light:GetTransform()
	
	return self.Transform
	
end

return Light