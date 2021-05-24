pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- PICO EC - 
-- A small scene/entity/component
-- library built for the fantasy
-- console, PICO-8.
-- @script PICO-EC
-- @author Joeb Rogers
-- @license MIT
-- @copyright Joeb Rogers 2018

sin1 = sin function sin(angle) return sin1(-angle/(3.1415*2)) end 
cos1 = cos function cos(angle) return cos1(angle/(3.1415*2)) end

function txtM(t)
    return 64 - (#t*2)
end
--- A table storing various utility
-- functions used by the ECS.

--- Assigns the contents of a table to another.
-- Copy over the keys and values from source 
-- tables to a target. Assign only shallow copies
-- to the target table. For a deep copy, use
-- deepAssign instead.
-- @param target The table to be copied to.
-- @param source Either a table to copy from,
-- or an array storing multiple source tables.
-- @param multiple Specifies whether source contains
-- more than one table.
-- @return The target table with overwritten and 
-- appended values.
function assign(target, source, multiple)
  multiple = multiple or false
  if multiple == true then
    for count = 1, #source do
      target = assign(target, source[count])
    end
    return target
  else
    for k, v in pairs(source) do
      target[k] = v;
    end
  end
  return target;
end

--- Deep assigns the contents of a table to another.
-- Copy over the keys and values from source 
-- tables to a target. Will recurse through child
-- tables to copy over their keys/values as well.
-- @param target The table to be copied to.
-- @param source Either a table to copy from,
-- or an array storing multiple source tables.
-- @param multipleSource Specifies whether source
-- contains more than one table.
-- @param exclude Either a string or an array of
-- string containing keys to exclude from copying.
-- @param multipleExclude Specifies whether exclude
-- contains more than one string.
-- @return The target table with overwritten and 
-- appended values.
function deepAssign(target, source, multipleSource, exclude, multipleExclude)
    multipleSource = multipleSource or false
    exclude = exclude or nil
    multipleExclude = multipleExclude or false

    if multipleSource then
        for count = 1, #source do
            target = deepAssign(target, source[count], false, exclude, multipleExclude)
        end
        return target
    else
        for k, v in pairs(source) do
            local match = false
            if multipleExclude then
                for count = 1, #exclude do
                    if (k == exclude[count]) match = true
                end
            elseif exclude then
                if (k == exclude) match = true
            end
            if not match then
                if type(v) == "table" then
                    target[k] = deepAssign({}, v, false, exclude, multipleExclude)
                else
                    target[k] = v;
                end
            end
        end
    end
    return target;
end

--- Removes a string key from a table.
-- @param t The table to modify.
-- @param k The key to remove.
function tableRemoveKey(t, k)
    t[k] = nil
end

--- Unloads a scene, and loads in the specified new one.
-- @param currentScene The currently running scene.
-- @param newScene The new scene to load in.
-- @return The newly loaded in scene.
function changeScene(currentScene, newScene)
    currentScene:unload()
    currentScene = newScene
    currentScene:onLoad()
    return currentScene
end

textFx = { 
    colors = {0,1,5,6,11,11,11,11,6,5,1,0,},
    counter = 3,
    index = 1
}

function textFx:drawBlinkingText(text, x, y, customColors)
    local colors = customColors or self.colors
    if (self.index > #colors) self.index = 1
    print(text,x,y,colors[self.index])
    self.counter -= 1
    if self.counter < 0 then
        self.index +=1
        self.counter = 3
    end
end

--- A table used as the base for a 
-- reusable GameObject.
-- @field active Whether the current object 
-- should be processed. If disabled, this 
-- object won't be updated or drawn.
-- @field flagRemoval Whether the current
-- object should be flagged for removal.
-- If set to true, the object will be 
-- cleaned up once it's parent has finished
-- processing.
_baseObject = {    
    active      = true,
    flagRemoval = false,
}

--- Sets an object's 'flagRemoval' field.
-- @param state A bool representing what
-- the field be set to.
function _baseObject:setRemoval(state)
    self.flagRemoval = state
end

--- The number of entities currently 
-- created within the application 
-- lifetime.
ENTITY_COUNT = 0

--- A table used as a base for entities.
-- This table is also assigned the 
-- properties of _baseObject.
-- This table can be combined with a 
-- custom entity object with overwritten
-- fields and functions when the
-- createEntity() function is called.
-- @field _components A table containing 
-- the entity's added components.
-- @field _componentsIndexed A table 
-- containing the entity's added 
-- components, indexed in the order
-- they were added to the entity.
-- @field type A string containing the 
-- object's "type".
-- @field name A string containing the 
-- entity's name. Used for indexing within
-- the scene. 
-- @field ind The index of this entity's
-- position within the scene's ordererd
-- array.
_entity = {
    _components        = {},
    _componentsIndexed = {},
    type               = "entity",
    name               = "entity_"..ENTITY_COUNT,
    ind                = 0,
    layer              = 2
}

-- Append the properties of _baseObject to _entity.
deepAssign(_entity, _baseObject)

--- Add a component to the entity's list of components.
-- The added component has it's parent assiged to the 
-- entity.
-- @param component The component to add.
-- @return Returns early if the component
-- isn't valid.
function _entity:addComponent(component)
    if not component or not component.type or component.type != "component" then return end

    self._components[component.name] = component
    add(self._componentsIndexed, component)
    component.ind = #self._componentsIndexed
    component.parent = self
end

--- Removes a component from the entity's list of components.
-- The specified component is flagged for removal and 
-- will be removed once the other component's have 
-- finished processing.
-- @param name The string index of the component
-- to remove.
function _entity:removeComponent(name)
    self._components[name]:setRemoval(true)
end

--- Returns a component specified by name.
-- @param name The string index of the component
-- to retrieve.
-- @return The retrieved component.
function _entity:getComponent(name)
    return self._components[name]
end

--- Called when the entity is added to a
-- scene with the addEntity() function.
-- Has no default behaviour, should be 
-- overwritten by a custom entity.
function _entity:onAddedToScene()
    self:init() 
end

--- Calls init() on all of an entity's components.
function _entity:init()
    for v in all(self._componentsIndexed) do
        v:init()
    end
end

--- Calls update() on all of an entity's components.
-- Loops back around once all components have been 
-- updated to remove any components that have been
-- flagged.
-- @return Will return early if the entity isn't
-- active.
-- @return Will return before resetting indexes
-- if no objects have been removed.
function _entity:update()
    if not self.active then return end

    local reIndex = false

    for v in all(self._componentsIndexed) do
        if v.active then
            v:update()
        end
    end

    for v in all(self._componentsIndexed) do
        if v.flagRemoval then
            tableRemoveKey(self._components, v.name)
            del(self._componentsIndexed, v)
        end
    end

    if (not reIndex) return

    local i = 1
    for v in all(self._componentsIndexed) do
        v.ind = i
        i += 1
    end
end

--- Calls draw() on all of an entity's components.
-- @return Will return early if the entity isn't
-- active.
function _entity:draw()
    if not self.active then return end
    for v in all(self._componentsIndexed) do
        if v.active then
            v:draw()
        end
    end
end

--- The number of components currently 
-- created within the application 
-- lifetime.
COMPONENT_COUNT = 0

--- A table used as a base for components.
-- This table is also assigned the 
-- properties of _baseObject.
-- This table can be combined with a 
-- custom component object with overwritten
-- fields and functions when the
-- createComponent() function is called.
-- This is the intended method for creating
-- custom behaviours.
-- @field parent A reference to the entity
-- that contains this component.
-- @field type A string containing the 
-- object's "type".
-- @field name A string containing the 
-- component's name. Used for indexing 
-- within the parent entity. 
-- @field ind The index of this component's
-- position within the entity's ordererd
-- array.
_component = {
    parent = nil,
    type   = "component",
    name   = "component_"..COMPONENT_COUNT,
    ind    = 0
}

-- Append the properties of _baseObject to _component.
deepAssign(_component, _baseObject)

--- A function to initialise the component. 
-- init is a placeholder that can be overwritten
-- upon creation of a component. Will be called
-- once when the application calls _init() and
-- when a new scene's onLoad() function is
-- called.
function _component:init() end

--- A function to update the component.
-- update is a placeholder that can be overwritten
-- upon creation of a component. Will be called
-- every frame when the application calls _update().
function _component:update() end

--- A function to draw the component.
-- draw is a placeholder that can be overwritten
-- upon creation of a component. Will be called
-- every frame when the application calls _draw().
function _component:draw() end

--- A table used as a base for scenes.
-- This table can be combined with a 
-- custom scene object with overwritten
-- fields and functions when the
-- createScene() function is called.
-- @field _entities A list of all the
-- entities currently added to this
-- scene.
-- @field _entitiesIndexed A table 
-- containing the scenes's added 
-- entities, indexed in the order
-- they were added to the scene.
-- @field type A string containing the 
-- object's "type".
_scene = {
    _entities        = {},
    _entitiesIndexed = {},
    _entitiesSorted = {},
    type             ="scene"
}

--- Adds an entity to this scene's entity list.
-- @param entity The entity to add.
-- @return Will return early if the entity is
-- invalid.
function _scene:addEntity(entity)
    if not entity or not entity.type or entity.type != "entity" then return end

    self._entities[entity.name] = entity
    add(self._entitiesIndexed, entity)
    entity.ind = #self._entitiesIndexed
    self._entitiesSorted[entity.layer] = self._entitiesSorted[entity.layer] or {}
    add(self._entitiesSorted[entity.layer], entity)
    self._entities[entity.name]:onAddedToScene()
end

--- Flags an entity for removal from the scene.
-- @param name The name the entity is indexed
-- by within the scene.
function _scene:removeEntity(name)
    self._entities[name]:setRemoval(true)
end

--- Returns the entity within the scene with
-- the passed in name.
-- @param name The name the entity is indexed
-- by within the scene.
-- @return The retrieved entity.
function _scene:getEntity(name)
    return self._entities[name]
end

--- Calls update() on all of an scene's entities.
-- Entity is skipped if not active.
-- Loops back around once all entities have been 
-- updated to remove any entities that have been
-- flagged.
-- @return Will return before resetting indexes
-- if no objects have been removed.
function _scene:update()
    local reIndex = false

    for v in all(self._entitiesIndexed) do
        if v.active then
            v:update()
        end
    end

    for v in all(self._entitiesIndexed) do
        if v.flagRemoval then
            tableRemoveKey(self._entities, v.name)
            del(self._entitiesIndexed, v)
            del(self._entitiesSorted[v.layer], v)
            reIndex = true
        end
    end

    self:lateUpdate()

    if (not reIndex) return

    local i = 1
    for v in all(self._entitiesIndexed) do
        v.ind = i
        i += 1
    end
end

-- custom update for functionality after entites have been updated
function _scene:lateUpdate() end

--- Calls draw() on all of an scene's entities.
-- Entity is skipped if not active.
function _scene:draw()
    -- for v in all(self._entitiesIndexed) do
    --     if v.active then
    --         v:draw()
    --     end
    -- end

    for i=0,8 do
        setPal() --reset palette for every layer
        for e in all(self._entitiesSorted[i]) do 
            if e.active then
                e:draw()
            end
        end
    end
end

--- Function called when the scene is loaded
-- in as the active scene.
-- By default calls init() on all of it's 
-- stored entities. If planning to overwrite
-- the onLoad() function with a custom scene,
-- this behvaiour should be copied over to
-- the new scene, else no entities or 
-- components will be initialised unless the
-- scene is the loaded in the application 
-- _init().
function _scene:onLoad()
    for v in all(self._entitiesIndexed) do
        v:init()
    end
    self:start()
end

function _scene:start() end

--- Function called during the change to a
-- new scene. To be overwritten if any 
-- custom behaviours need special 
-- attention before being removed.
function _scene:unload() end

--- Creates and returns a new scene object.
-- Will either return a new default scene or
-- one combined with a passed in custom scene.
-- @param scene A custom scene to combine with
-- the default scene.
-- @return The created scene object.
function createScene(scene)
    local sc = scene or {}
    sc = deepAssign({}, {_scene, sc}, true)
    return sc
end

--- Creates and returns a new entity object.
-- Will either return a new default entity or
-- one combined with a passed in custom entity.
-- Also increments the global entity count.
-- @param entity A custom entity to combine with
-- the default entity.
-- @return The created entity object.
function createEntity(entity)
    local ent = entity or {}
    ent = deepAssign({}, {_entity, ent}, true)
    ent.name = "entity_"..ENTITY_COUNT
    ENTITY_COUNT += 1
    return ent
end

--- Creates and returns a new component object.
-- Will either return a new default component or
-- one combined with a passed in custom component.
-- Also increments the global component count.
-- @param component A custom component to combine 
-- with the default component.
-- @return The created component object.
function createComponent(component)
    local c = component or {}
    c = deepAssign({}, {_component, c}, true)
    COMPONENT_COUNT += 1
    return c
end

function createPlayer(id)
    local playerEnt = createEntity()
    playerEnt:addComponent(createComponent(_playerComponent))
    playerEnt:addComponent(createComponent(_transformComponent))
    playerEnt:addComponent(createComponent(_spriteComponent))
    playerEnt:addComponent(createComponent(_animatorComponent))
    playerEnt.layer = 4
    local playerComp = playerEnt:getComponent("Player")
    playerComp.id = id
    return playerEnt
end

function createBomb()
    local bombEnt = createEntity()
    bombEnt:addComponent(createComponent(_bombComponent))
    bombEnt:addComponent(createComponent(_transformComponent))
    bombEnt:addComponent(createComponent(_spriteComponent))
    bombEnt:addComponent(createComponent(_animatorComponent))
    bombEnt.layer = 3
    return bombEnt
end

function createExplosion(cellx,celly)
    local pos, expl = to_screen(cellx, celly), createEntity()
    expl:addComponent(createComponent(_transformComponent))
    expl:addComponent(createComponent(_spriteComponent))
    expl:addComponent(createComponent(_animatorComponent))
    expl:getComponent("Transform"):setPosition(pos.x, pos.y)
    expl:init()
    return expl
end

-->8
--Particle System

_particleSystem = {
    particles = {},
}

particleIntensity = 4

function _particleSystem:update()
    for p in all(self.particles) do
        p:update()
    end
end

function _particleSystem:draw()
    for p in all(self.particles) do 
        p:draw()
    end
end

function _particleSystem:addParticles(xPos, yPos, xSpeed, ySpeed, lifetime, size, gravity, spriteIndex)
    local ps = self
    add(ps.particles, {
        x=xPos,
        y=yPos,
        xSp=xSpeed,
        ySp=ySpeed,
        life=lifetime,
        s=size,
        g=gravity,
        xIndex=(spriteIndex % 16) * 8,
        yIndex=(spriteIndex \ 16) * 8,
        parent=ps,
        draw=function(self)
            sspr(self.xIndex, self.yIndex, 8, 8, self.x, self.y, (rnd(4)+4)-self.s, (rnd(4)+4)-self.s)
        end,
        update=function(self)
            self.x += self.xSp 
            self.y += self.ySp
            self.ySp+=self.g
            self.s*=0.8
            self.life-=1
            if (self.life<0) del(self.parent.particles, self)
        end
    })
end

-->8
--Spark and Fire System

_fire = {
    embers = {},
    nextEmber = 0
}

function _fire:update()
    self.nextEmber -= dt
    if(self.nextEmber <= 0) then
        self.nextEmber = 0.1 + rnd(0.2)
        add(self.embers, _ember:create())
    end

    for ember in all(self.embers) do
        if(ember.y < 0) then 
            del(self.embers, ember)
        else
            ember.y -= ember.speed
            local y = ember.y + ember.offset
            local g = ember.trajectory
            ember.x = 16 * sin(y * g + cos(y * g + 2)) + ember.xOffset
        end
    end
end

function _fire:draw()
    for ember in all(self.embers) do
        ember:draw()
    end
end

_ember = {
    offset,
    sprite,
    xOffset,
    trajectory,
    x,
    y,
    speed
}

function _ember:create()
    local emb = assign({}, _ember)
    local sprites = {236,223,239,255,143,159}
    emb.offset = rnd(1.5)
    emb.sprite = sprites[flr(1 + rnd(6))]
    emb.xOffset = flr(10 + rnd(108))
    emb.trajectory = flr(1 + rnd(4)) * 0.01 
    emb.y = 130
    emb.speed = 1 + rnd(2)
    return emb
end

function _ember:draw()
    spr(self.sprite, self.x, self.y)
end

-->8
--Player Component
maxSpeed, maxBombs, maxRange = 1.6, 6, 6
spawns = {{x=3,y=4},{x=13,y=14},{x=3,y=14},{x=13,y=4}}
idles = {"SideIdle", "SideIdle", "UpIdle", "DownIdle"} 
--change pallete based on id

_playerComponent = {
    id,
    name = "Player",
    transform = nil,
    dx = 0,
    dy = 0,
    sprite = nil,
    animator = nil,
    speed = 0.8,
    bombs = 1,
    bombRange = 1,
    alive = true,
    wins = 0,
    direction = 3,
    canPush = false,
    thread
}

function _playerComponent:init()
    --Set up Transform
    self.alive = true
    self.transform = self.parent:getComponent("Transform")
    local spawn = spawns[self.id + 1]
    local spawnPos = to_screen(spawn.x, spawn.y)
    self.transform:setPosition(spawnPos.x + 4, spawnPos.y + 4)
    --Set up Sprite
    self.sprite = self.parent:getComponent("Sprite")
    self.sprite:setSprite(68)
    self.sprite:setSize(1,2)
    self.sprite:setDrawingOffset(4, 12)
    --Set up Animation
    self.animator = self.parent:getComponent("Animator")
    local sideWalk = animation.createAnimation({77, 78, 77, 79, 96, 97, 96, 79}, 3)
    self.animator:addAnimation("SideWalk", sideWalk)
    local upWalk = animation.createAnimation({70, 71, 70, 72}, 2, true)
    self.animator:addAnimation("UpWalk", upWalk)
    local downWalk = animation.createAnimation({64, 64, 65, 66}, 2, true)
    self.animator:addAnimation("DownWalk", downWalk)
    local die = animation.createAnimation({64,102,103,104,105,105,105,105,105,105,105}, 4, false, false)
    self.animator:addAnimation("Die", die)
    local victory = animation.createAnimation({64,106,107,108,108,107}, 4)
    self.animator:addAnimation("Victory", victory)
    local sideIdle = animation.createAnimation({79,98,99,100,100,100,99}, 4)
    self.animator:addAnimation("SideIdle", sideIdle)
    local upIdle = animation.createAnimation({73,74,75,76,76,76,75}, 4)
    self.animator:addAnimation("UpIdle", upIdle)
    local downIdle = animation.createAnimation({64,64,67,68,69,69,68}, 4)
    self.animator:addAnimation("DownIdle", downIdle)
end

function _playerComponent:draw()
    setPal()
    setPlayerPal(self.id)
end

function _playerComponent:update()
    if self.alive then
        self:handleInput()
        self:handleCollision()
        if self.thread then
            coresume(self.thread, self) 
            if (costatus(self.thread) == 'dead') self.thread = nil
        end
    end
end

function _playerComponent:handleInput()
    local id,dir = self.id, self.direction
    local accel = self.speed
    local animation = idles[self.direction + 1]
    if (btn(0, id)) then
         self.dx -= accel 
         animation = "SideWalk"
         self.sprite.flipped_x = true
         dir = 0
    elseif (btn(1, id)) then
        self.dx += accel
        animation = "SideWalk"
        self.sprite.flipped_x = false
        dir = 1
    elseif (btn(2, id)) then 
        self.dy -= accel
        animation = "UpWalk"
        dir = 2
    elseif (btn(3, id)) then
        self.dy += accel
        animation = "DownWalk"
        dir = 3
    end
    if (btnp(5, id)) self:tryDropBomb()
    if not (self.animator.currentAnim == animation) then 
        self.animator:setAnimation(animation)
    end
    self.direction = dir
end

function _playerComponent:tryDropBomb()
    if self.bombs > 0 and not currentScene:getBombAtCell(to_map(self.transform.x, self.transform.y)) then
        local bombEnt = createBomb()
        bombEnt:init()
        local bombComp = bombEnt:getComponent("Bomb")
        bombComp.range = self.bombRange
        bombComp:place(self.transform.x, self.transform.y, self)
        currentScene:addEntity(bombEnt)
        self.bombs-=1
        return true
    end
    return false
end

function _playerComponent:handleCollision()
    local x,y,dx,dy = self.transform.x, self.transform.y, self.dx, self.dy
    local oldCell = to_map(x,y)
    local s = mget(oldCell.x, oldCell.y)
    --check for explosions or stage hazards
    if (currentScene:getExplosion(oldCell) ~= nil) or (fget(s,0) and not fget(s,1)) then
        self:die()
        return
    end
    local isOnBomb = self:isOnOwnBomb()
    if dx != 0 then
        local xdir
        if (dx > 0) xdir = "right" else xdir = "left"
        local result, isOnSameCell = collides_tile(x + dx, y, 3, 3, xdir), isOnSameCell(x + dx, y, 3, 3, xdir)
        if result > 0 or (isOnBomb and isOnSameCell) then
            local x,y = dx,0
            if not (isOnBomb and isOnSameCell) then
                x = result == 3 and dx or dx / 3
                if result == 1 then y = -dx elseif result == 2 then y = dx end
            end
            self.transform.x += x
            self.transform.y += y
        elseif self.canPush then
            oldCell.x += sgn(dx)
            local b = currentScene:getBombAtCell(oldCell)
            if (b) b:push(xdir)
        end
    elseif dy != 0 then
        x = self.transform.x
        local ydir
        if (dy > 0) ydir = "down" else ydir = "up"
        local result, isOnSameCell = collides_tile(x, y + dy, 3, 3, ydir), isOnSameCell(x, y + dy, 3, 3, ydir)
        if result > 0  or (isOnBomb and isOnSameCell) then 
            local x,y = 0,dy
            if not (isOnBomb and isOnSameCell) then
                y = result == 3 and dy or dy/3
                if result == 1 then x = -dy elseif result == 2 then x = dy end
            end
            self.transform.x += x
            self.transform.y += y
        elseif self.canPush then
            oldCell.y += sgn(dy)
            local b = currentScene:getBombAtCell(oldCell)
            if (b) b:push(ydir)
        end
    end
    self:checkForItems()
    self.dx, self.dy = 0,0
end

function _playerComponent:checkForItems()
    local cellPos = to_map(self.transform.x, self.transform.y)
    local spriteIndex = mget(cellPos.x, cellPos.y)
    local cellBitField = fget(spriteIndex)
    
    if cellBitField == 0x6 and self.speed < maxSpeed and not self.thread then
        self.speed += 0.2
    elseif cellBitField == 0xA and self.bombRange < maxRange then
        self.bombRange += 1
    elseif cellBitField == 0x12 and self.bombs < maxBombs then
        self.bombs += 1
    elseif cellBitField == 0x22  then
        self.canPush = true
    elseif cellBitField == 0x42  and not self.thread then
        self.speed -= 0.4
        if (self.speed < 0.6) self.speed = 0.6
    elseif cellBitField == 0xE then
        self.thread = cocreate(function()
            local _draw,_s = self.draw, self.speed
            self.draw = function(self) dimPal() end
            local t,d = 6, 0.03
            self.speed = 0.4
            while t > 0 do
                t -= dt
                local rand = flr(rnd(100)) / 100
                printh(rand)
                if (rand < d) self:tryDropBomb()
                yield()
            end
            self.speed, self.draw = _s, _draw
        end)
    else
        isItem = false
    end 

    if cellBitField & itemBitfield != 0 then --if its an item
        setGround(cellPos.x, cellPos.y)
        sfx(41, 3)
    end
end

function _playerComponent:isOnOwnBomb()
    local bomb = currentScene:getBombAtCell(to_map(self.transform.x, self.transform.y))
    return bomb and bomb.parentPlayer == self
end

function _playerComponent:onRoundWin()
    self.animator:setAnimation("Victory")
    self.alive = false --disable controls
end

function _playerComponent:die()
    self.animator:setAnimation("Die")
    self.alive = false
    self.draw = function(self) dimPal() end
    currentScene:onPlayerDied(self.parent.name)
end

-->8
--Bombs
_bombComponent = {
    name = "Bomb",
    transform = nil,
    sprite = nil,
    animator = nil,
    parentPlayer = nil,
    range = 1,
    lifetime = 2,
    moving = false,
    xS,yS,
}

function _bombComponent:init()
    self.transform = self.parent:getComponent("Transform")
    self.sprite = self.parent:getComponent("Sprite")
    self.sprite:setSprite(20)
    self.sprite:setSize(1, 1)
    self.animator = self.parent:getComponent("Animator")
    local bombAnim = animation.createAnimation({20, 21}, 12)
    self.animator:addAnimation("Bomb", bombAnim)

end

function _bombComponent:place(x, y, parentPlayer)
    local cellPos = to_map(x,y)
    local bombPos = to_screen(cellPos.x, cellPos.y)
    self.transform:setPosition(bombPos.x, bombPos.y)
    self.parentPlayer = parentPlayer
    self.animator:setAnimation("Bomb")
    currentScene:addBomb(self, cellPos)
    sfx(0, 3)
end

function _bombComponent:update()
    self.lifetime -= dt
    if self.lifetime <= 0 then
        self:explode()
        return
    end
    if self.move then
        local x,y = self.transform.x + self.xS, self.transform.y + self.yS
        local oX,oY = self.xS > 0 and 7 or 0, self.yS > 0 and 7 or 0
        local cell = to_map(x + oX,y + oY)
        local bAtCell = currentScene:getBombAtCell(cell)
        if fget(mget(cell.x,cell.y),0) or collidesPlayer(cell) or (bAtCell != nil and bAtCell != self) then 
            self.move = false
        else
            self.transform.x, self.transform.y = x,y
        end
    end
end

function _bombComponent:explode()
    local cellPos = to_map(self.transform.x, self.transform.y)
    currentScene:removeBomb(cellPos)
    local expl = createEntity()
    expl:addComponent(createComponent(_explosionComponent))
    expl:getComponent("Explosion"):explode(self.transform, self.range);
    currentScene:removeEntity(self.parent.name)
    currentScene:addEntity(expl)
    self.parentPlayer.bombs += 1
    sfx(1, 3)
end

function _bombComponent:push(dir)
    self.xS, self.yS = 0,0
    if dir == "right" then self.xS = 2 elseif dir == "left" then self.xS = -2
    elseif dir == "down" then self.yS = 2 elseif dir == "up" then self.yS = -2 end
    self.move = true 
end

_explosionComponent = {
    name = "Explosion",
    particles = {},
    lifetime = 0.9,
    fades = false
}

function _explosionComponent:explode(transform, range)
    local cellpos = to_map(transform.x,transform.y)
    local lc,uc,rc,dc = true,true,true,true --continue flags
    local type = 0
    self:addCenter(cellpos.x, cellpos.y)
    if (fget(mget(cellpos.x, cellpos.y), 1)) setGround(cellpos.x, cellpos.y)
    for i=1,range do
        --left
        if (lc == true) then
            type = self:explode_at(cellpos.x - i, cellpos.y)
            if (type > 0) then
                type = (i == range) and 1 or type
                self:addExplosionAt(cellpos.x - i, cellpos.y, type, "horizontal", true) 
            end
            lc = type > 1
        end
        --up
        if (uc == true) then
            type = self:explode_at(cellpos.x, cellpos.y - i)
            if (type > 0) then
                type = (i == range) and 1 or type
                self:addExplosionAt(cellpos.x, cellpos.y - i, type, "vertical", false)
            end
            uc = type > 1
        end
        --right
        if (rc == true) then
            type = self:explode_at(cellpos.x + i, cellpos.y)
            if (type > 0) then
                type = (i == range) and 1 or type
                self:addExplosionAt(cellpos.x + i, cellpos.y, type, "horizontal", false)
            end
            rc = type > 1
        end
        --down
        if (dc == true) then
            type = self:explode_at(cellpos.x, cellpos.y + i)
            if (type > 0) then
                type = (i == range) and 1 or type
                self:addExplosionAt(cellpos.x, cellpos.y + i, type, "vertical", true)
            end
            dc = type > 1
        end
    end

    cam:getComponent("Camera"):shake(self.lifetime / 2, 1.5)
end

function _explosionComponent:explode_at(cellx, celly)
    local cell = mget(cellx, celly)
    local bomb = currentScene:getBombAtCell({x = cellx, y = celly})
    if (bomb) then
        bomb:explode()
        return 0
    end
    if fget(cell, 1) then
        if fget(cell) & itemBitfield == 0 then --if it isn't an item
            self.breakBlock(cellx, celly)
        else
            setGround(cellx, celly)
        end
        return 1 -- one means we hit something which can be broken
    elseif fget(cell, 0) then
        return 0  -- zero means we hit something which cannot be broken
    end
    return 2 --two means we have not hit anything
end

function _explosionComponent:addExplosionAt(cellx, celly, type, orientation, flipped)
    local expl, sprites = createExplosion(cellx, celly), {}
    local animator = expl:getComponent("Animator")
    if (orientation == "horizontal") then
        if(type == 1) sprites = {160, 161, 162, 163}
        if(type == 2) sprites = {144, 145, 146, 147}
        animator.sprite.flipped_x = flipped
    elseif (orientation == "vertical") then
        if(type == 1) sprites = {176, 177, 178, 176}
        if(type == 2) sprites = {135, 134, 133, 132}
        animator.sprite.flipped_y = flipped
    end
    animator:addAnimation("burn",animation.createAnimation(sprites, 1.5))
    animator:addAnimation("fade",animation.createAnimation({sprites[4], sprites[3], sprites[2], sprites[1],58}, 1.5, false, false))
    animator:setAnimation("burn")
    add(self.particles, expl)
    currentScene:setExplosion({x=cellx, y=celly}, 1)
end

function _explosionComponent:addCenter(cellx, celly)
    local expl = createExplosion(cellx, celly)
    local animator = expl:getComponent("Animator")
    animator:addAnimation("burn",animation.createAnimation({128, 129, 130, 131}, 1.5))
    animator:addAnimation("fade",animation.createAnimation({131, 130, 129, 128, 58}, 2, false, false))
    animator:setAnimation("burn")
    add(self.particles, expl)
    currentScene:setExplosion({x=cellx, y=celly}, 1)
end

function _explosionComponent:update()
    self.lifetime -= dt
    if self.lifetime <= 0.3 and not self.fades then
        for p in all(self.particles) do 
            p:getComponent("Animator"):setAnimation("fade")
            local trans = p:getComponent("Transform")
            local cellPos = to_map(trans.x, trans.y)
            currentScene:setExplosion(cellPos, nil)
        end
        self.fades = true
    end
    if self.lifetime <= 0 then
        currentScene:removeEntity(self.parent.name)
        return
    end

    for p in all (self.particles) do
        p:update()
    end
end

function _explosionComponent:draw()
    for p in all (self.particles) do 
        p:draw()
    end
end

function _explosionComponent.breakBlock(cellx, celly)
    local screenPos = to_screen(cellx, celly)
    for i=0,particleIntensity do
        particleSystem:addParticles(screenPos.x + 4, screenPos.y + 4, rnd(4)-2, rnd(4)-2, 8, 1, 0, blockSprite)
    end
    setGround(cellx, celly) -- setGround first to also set correct collision
    if flr(rnd(100)) < 50 then
        local value,high,low,chances = flr(rnd(100)),0,0,{25,25,20,9,10,11}
        for i,c in pairs(chances) do 
            high += c
            if value >= low and value <= high then
                mset(cellx, celly, 47 + i)
                return
            end
            low += c
        end
    end
end

-->8
--Generic Components
_transformComponent = {
    name = "Transform",
    x = 0,
    y = 0
}

function _transformComponent:setPosition(x, y)
    self.x = x
    self.y = y
end

_spriteComponent = {
    name = "Sprite",
    sprite = 0,
    transform = nil,
    flipped_x = false,
    flipped_y = false,
    width = 1,
    height = 1,
    offsetX = 0,
    offsetY = 0
}

function _spriteComponent:init()
    self.transform = self.parent:getComponent("Transform")
end

function _spriteComponent:draw()
    local x, y = self.transform.x - self.offsetX -3, self.transform.y - self.offsetY
    spr(self.sprite,x,y,self.width,self.height,self.flipped_x, self.flipped_y)
end

function _spriteComponent:setSprite(index)
    self.sprite = index
end

function _spriteComponent:setSize(w, h)
    self.width, self.height = w, h
end

function _spriteComponent:setDrawingOffset(x, y)
    self.offsetX ,self.offsetY = x, y
end

_animatorComponent = {
    name = "Animator",
    sprite = nil,
    animations = {},
    currentAnim = '',
    frameCounter = 0,
    play = false
}

function _animatorComponent:init()
    self.sprite = self.parent:getComponent("Sprite")
end

function _animatorComponent:addAnimation(name, animation)
    animation.parent = self
    self.animations[name] = animation
end

function _animatorComponent:setAnimation(name)
    if (name == self.currentAnim) return
    if (name ~= '') then
        self.sprite:setSprite(self.animations[name]:getNext())
        self.play = true
    else
        self.sprite:setSprite(self.animations[self.currentAnim]:getNext())
        self.play = false
    end
    self.currentAnim = name
    self.frameCounter = 0
end

function _animatorComponent:update()
    if (self.play) then
        self.frameCounter += 1
        if self.frameCounter >= self.animations[self.currentAnim].animDelay then
            self.sprite:setSprite(self.animations[self.currentAnim]:getNext())
            self.frameCounter = 0
        end
    end
end

animation = {
    parent = nil,             --parent animator Component
    frames = {},
    index = 0,
    animDelay = 0,
    mirrored = false,
    loop = true
}

function animation.createAnimation(frames, delay, mirrored, loop)
    local a = assign({}, {animation}, true)
    a.frames = frames
    a.animDelay = delay
    a.mirrored = mirrored or false
    if (loop == nil) a.loop = true else a.loop = loop
    return a
end

function animation:getNext()
    self.index += 1
    if (self.index > #self.frames) then 
        if (self.mirrored) self.parent.sprite.flipped_x = not self.parent.sprite.flipped_x
        if self.loop then
            self:reset() 
        else 
            self.parent.play = false
            return self.frames[self.index - 1]
        end
    end
    return self.frames[self.index] 
end

function animation:reset()
    self.index = 1
end

_mapComponent = {
    x,y,
    dark = false
}

groundTiles, blockSprite = {},0 

function _mapComponent:load()
    reload(0x2000, 0x2000, 0x1000) -- reload map data
    local x,y = self.x, self.y
    for i=x, x+15 do
        for j=y, y+15 do
            mset(i-x, j-y, mget(i,j))
        end
    end
end

function _mapComponent:draw() 
    map(0,0,-3,0) 
    if (self.dark) then
        darkMapPal()
        map(0,0,-3,0,16,16,0x80)
    end
end

function _mapComponent:generateMap()
    local freeCells = {}
    for x = 3, 13 do
        for y = 4, 14 do
            local cell = {x = x, y = y}
            if not fget(mget(x,y), 0) then
                if mget(x,y) != 53 then
                    add(freeCells, cell)
                else
                    setGround(x,y)
                end
            end
        end
    end
    local blockAmount = 60 + flr(rnd(5))
    for i = 1, blockAmount do
        local index = 1 + flr(rnd(#freeCells - 1))
        local cellPos = deli(freeCells, index)
        mset(cellPos.x, cellPos.y, blockSprite)
    end
end

-->8
--UI
_PlayerUI = {
    wins = {0,0,0,0},
    xPositions = {28,86,4,110},
}

function _PlayerUI:reset()
    self.wins = {0,0,0,0}
end

function _PlayerUI:draw()
    rectfill(0,0,129,24,0)
    for i=1,mainScene.playerCount do
        setPlayerPal(i-1)
        local x = self.xPositions[i]
        local right = i % 2 == 0
        --draw avatar
        spr(164,x,1,2,2, right)
        --draw wins background
        local x2 = right and 2 or 0
        spr(137,x - x2,16,2.25,1)
        --draw wins
        print(self.wins[i], x+8 - x2,18,11)
    end
    --reset palette
    setPal()
end

_Timer = {
    isRunning = true,
    time = 180
}

function _Timer:update()
    if (not self.isRunning) return 

    self.time -= dt
    if self.time <= 0 then
        self.time = 0 
        self.isRunning = false
    end
end

function _Timer:draw()
    --draw watch
    spr(136,61,3)
    --draw background
    spr(166,55,10,2.5,1)
    local rtime = flr(self.time)
    local min, sec = rtime \ 60, rtime % 60
    if (sec < 10) sec = "0"..sec
    print(min..":"..sec, 58,12,0)
end

_VictoryUI = {
    isFinal = false,
    winnerId,
    w = 0,
    h = 0,
    y = 60,
    fullrect = false,
    colors = {2,3,4,5,6,7,8,9,10,11,12,13,14,15},
    content
}

function _VictoryUI:setMode(mode)
    if mode == "victory" then
        self.content = self.victory
    elseif mode == "tie" then
        self.content = self.tie
    elseif mode == "champ" then
        self.content = self.champ
    end
end

function _VictoryUI:update()
    if not self.fullrect then
        if (self.w < 64) self.w +=6
        if (self.w > 56) self.h +=2
        if (self.h >= 18) self.fullrect = true
    else
        if btnp(❎) then
            self:onBtnPress()
        end
    end
end

function _VictoryUI:draw()
    rectfill(64 - self.w, self.y - self.h, 64 + self.w, self.y + self.h, 0)

    if self.fullrect then
        rect(1, self.y - self.h + 1, 127, self.y + self.h - 1, 11)
        self:content()
    end
end

function _VictoryUI:victory()
    textFx:drawBlinkingText("player "..(self.winnerId + 1).." wins!",48, self.y - 2, self.colors)
    print("❎", 114, self.y + 8, 11)
    --draw winner player
    setPlayerPal(self.winnerId)
    spr(164,23,self.y - 9,2,2)
    setPal()
end

function _VictoryUI:tie()
    local txt = "tie!"
    textFx:drawBlinkingText(txt,txtM(txt), self.y - 2, self.colors)
    print("❎", 114, self.y + 8, 11)
end

function _VictoryUI:onBtnPress()
    if self.isFinal then
        victoryScene = createScene(_victoryScene)
        victoryScene.champId = self.winnerId
        music(-1, -800)
        currentScene = changeScene(mainScene, victoryScene)
    else
        music(-1, -800)
        roundIndicationScene.round += 1
        currentScene = changeScene(mainScene, roundIndicationScene)
    end
end

function _VictoryUI:champ()
    textFx:drawBlinkingText("player "..(self.winnerId + 1).." is the champion!!", 13, self.y - 2, self.colors)
    print("❎", 114, self.y + 8, 11)
end

-->8
--Screen Conversion
function to_screen(x,y)
    local screenPos={}
    screenPos.x = x*tilesize
    screenPos.y = y*tilesize
    return screenPos
end

function to_map(x,y)
    local mapPos={}
    mapPos.x = x \ tilesize
    mapPos.y = y \ tilesize
    return mapPos
end

function mapIndex(cellPos)
    return cellPos.y * mapsize + cellPos.x
end

function IndexToCell(i)
    return { x = i % mapsize, y = i \ mapsize}
end

function compareCells(cell1, cell2)
    return cell1.x == cell2.x and cell1.y == cell2.y
end

function setGround(x, y)
    local s = flr(rnd(#groundTiles - 1)) + 1
    mset(x, y, groundTiles[s])
    mset(x + mapsize, y + mapsize, 0) -- set ground for collision map
end
-->8
--Collision
function initCollisionMap()
    for x=0,15 do
        for y=0,15 do
            local snum = mget(x,y)
            if fget(snum, 0) then
                mset(x + mapsize, y + mapsize, snum)
            end
        end
      end
end

function collides(x,y)
    local mapPos = to_map(x,y)
    local tile = mget(mapPos.x + mapsize, mapPos.y + mapsize)
    return fget(tile, 0)
end

function collides_tile(x,y,w,h,dir)
    assert(dir == "up" or dir == "down" or dir == "left" or dir == "right", 'wrong direction entered!')
    local result = 3
    if dir == "up" then
        if (collides(x-w, y-h)) result -= 2 
        if (collides(x+w, y-h)) result -= 1
    elseif dir == "down" then
        if (collides(x-w, y+h)) result -= 1 
        if (collides(x+w, y+h)) result -= 2
    elseif dir == "left" then
        if (collides(x-w, y-h)) result -= 2
        if (collides(x-w, y+h)) result -= 1
    elseif dir == "right" then
        if (collides(x+w, y-h)) result -= 1
        if (collides(x+w, y+h)) result -= 2
    end
    return result
end

function isOnSameCell(x,y,w,h,dir)
    assert(dir == "up" or dir == "down" or dir == "left" or dir == "right", 'wrong direction entered!')
    local currentCell = to_map(x, y)
    if dir == "up" then
        return
        compareCells(currentCell, to_map(x-w, y-h)) and
        compareCells(currentCell, to_map(x+w, y-h))
    elseif dir == "down" then
        return 
        compareCells(currentCell, to_map(x-w, y+h)) and
        compareCells(currentCell, to_map(x+w, y+h))
    elseif dir == "left" then
        return 
        compareCells(currentCell, to_map(x-w, y-h)) and
        compareCells(currentCell, to_map(x-w, y+h))
    elseif dir == "right" then
        return 
        compareCells(currentCell, to_map(x+w, y-h)) and
        compareCells(currentCell, to_map(x+w, y+h))
    end
end

function collidesPlayer(cellPos)
    for p in all(gPlayers) do
        if (compareCells(to_map(p.transform.x, p.transform.y), cellPos)) return true
    end
    return false
end

-->8
-- Camera

_camComponent = {
    name = "Camera",
    offset = {
        x = 0,
        y = 0
    },
    isShaking = false,
    shakeDur = 0,
    shakeInt = 0
}

function _camComponent:shake(duration, intensity)
    self.shakeDur = duration
    if (intensity > self.shakeInt) self.shakeInt = intensity
    self.isShaking = true
end

function _camComponent:update()
    if self.isShaking then
        if self.shakeDur <= 0 then 
            self.isShaking = false
            self.shakeInt, self.shakeDur = 0,0
        else
            self.offset = {x = rnd(self.shakeInt), y = rnd(self.shakeInt)}
            self.shakeDur -= dt
        end
    end
end

function _camComponent:draw()
    if (self.isShaking) camera(self.offset.x, self.offset.y) else camera(0,0)
end

-->8
--Scenes
_credits = {
    c = 0,
    t = {"a game by:", "max pellegrino","and","dominik leiser"},
    fx = {},
    start = function(self) 
        for i=1,4 do
            self.fx[i] = deepAssign({}, textFx)
        end
    end
}

function _credits:draw()
    self.c += 1
    if (self.c == 18) sfx(3)
    if self.c > 76 then
        currentScene = changeScene(self, titleScene)
    else
        for i,t in pairs(self.t) do
            local x, y = txtM(t), i == 1 and 0 or 15 + (i-1) * 10
            if (self.c > 18 and self.c < 48) print(t, x, 35 + y) else self.fx[i]:drawBlinkingText(t, x, 35 + y)
        end
    end
end

_titleScene = {
    title = nil,
    fire
}

function _titleScene:start()
    music(00)
    self.title = createEntity(_titleTextEnt)
    self.title.startText:init()
    --set up animated bomb
    local bomb = createBomb():getComponent("Bomb")
    bomb.parent:init()
    bomb.sprite.draw = function(self)
        local sx = (self.sprite % 16) * 8
        sspr(sx,8,8,8,56,49,16,16)
    end
    bomb.animator:setAnimation("Bomb")  
    self.title.bomb = bomb.parent
    self.title.bomb:removeComponent("Bomb") --remove bomb logic
    self.fire = createEntity(_fire)
end

function _titleScene:unload()
    music(-1, -800)
end

function _titleScene:update()
    if (btnp(❎)) then
        self.title.anim = true
        sfx(3, 3)
    end
    self.title:update()
    self.fire:update()
end

function _titleScene:draw()
    palt(0, false)
    palt(4,true)
    self.fire:draw()
    map(32,0,0,0)
    palt()
    self.title:draw()
end

_titleTextEnt = {
    bomb = nil,
    yPos = 50,
    anim = false,
    startText = {
        text = "press ❎!",
        x,
        init = function(self)
            self.x = txtM(self.text)
        end,
        draw = function(self)
            textFx:drawBlinkingText(self.text, self.x, 80)
        end
    }
}

function _titleTextEnt:update()
    self.bomb:update()
    if (self.anim) self.yPos -= 5
    if self.yPos < -10 then
        selectionScene.fire = titleScene.fire
        currentScene = changeScene(titleScene, selectionScene)
        cam:getComponent("Camera"):shake(0.4, 3)
        sfx(1, 3)
    end
end

function _titleTextEnt:draw()
    sspr(56,16,64,8,2,self.yPos,128,16)
    if (self.yPos == 50) then
        self.bomb:draw()
        self.startText:draw()
    end
end

_selectionScene = {
    selectText = "select mode",
    rectOffset = 35,
    colors = {2,13,1,10,7,8},
    numberP = 148,
    cursorPos = 0,
    fire
}

function _selectionScene:start()
    music(19, 800)
end

function _selectionScene:update()
    if btnp(⬆️) and self.cursorPos > 0 then 
		sfx(04)
		self.cursorPos -= 1
	end
	if btnp(⬇️) and self.cursorPos < 2 then 
		sfx(04)
		self.cursorPos += 1
    end
    if btnp(❎) then 
        sfx(03)
        mainScene.playerCount = self.cursorPos + 2
        playerUI:reset()
        _stageSelectionScene.fire = self.fire
        currentScene = changeScene(self, _stageSelectionScene)
        palt()
    end
    self.fire:update()
end

function _selectionScene:draw()
    palt(0, false)
    self.fire:draw()
    local txt = self.selectText
    print(txt,txtM(txt),10,11)
    --draw the player rects
    for i=0,2 do
        self:drawPlayerRect(i, i == self.cursorPos)
    end
end

--zero based rect number
function _selectionScene:drawPlayerRect(rectNo, selected)
    local x1, y1 = 18, 30 + (rectNo * self.rectOffset)
    local x2, y2 = x1 + 92, y1 + 24
    local colorOffset = 1
    local rectFraction = 92 / (rectNo + 2)
    local playerX, playerY = rectFraction / 2 + x1, y1 + 5
    rectfill(x1,y1,x2,y2,0)

    if (not selected) dimPal()
    for i=0, rectNo + 1 do
        if (selected) setPlayerPal(i)
        spr(164,playerX-8, playerY, 2,2)
        playerX += rectFraction
    end
    setPal()

    if selected then
        colorOffset = 4 
        local textX, textY = 46, y1 - 8
        spr(self.numberP + rectNo, textX, textY)
        print("players", textX + 9, textY + 2, self.colors[rectNo + colorOffset])
        x1,y1,x2,y2 = x1 - 1, y1 - 1, x2 + 1, y2 + 1
    end

    rect(x1, y1, x2, y2, self.colors[rectNo + colorOffset])
end

_stageSelectionScene = {
    fire,
    rightArrowX = 94,
    leftArrowX = 25,
    st = {{t="bombom plains",x=90}, {t="frosty fields",x=82}, {t="spooky cemetery",x=96}},
    i = 1
}

function _stageSelectionScene:update()
    self.rightArrowX, self.leftArrowX = 94, 25
    local i = self.i
     if btnp(0) then
        i = i == 1 and 3 or i - 1
        self.leftArrowX -= 1
     elseif btnp(1) then
        i = i == 3 and 1 or i + 1
        self.rightArrowX += 1
     elseif btnp(❎) then
        if i == 1 then
            mapEnt.x, mapEnt.y, mapEnt.dark = 0,0,false
            groundTiles = {4,5,6,8,9}
            blockSprite = 2
        elseif i == 2 then
            mapEnt.x, mapEnt.y, mapEnt.dark = 32,16, false
            groundTiles = {23,24,25,184}
            blockSprite = 3
        else
            mapEnt.x, mapEnt.y, mapEnt.dark = 16,16,true
            groundTiles = {4,5,6,8,9}
            blockSprite = 22
        end
        winSelectionScene.fire = self.fire
        currentScene = changeScene(self, winSelectionScene)
        sfx(3)
     end
     self.fire:update()
     self.i = i
end

function _stageSelectionScene:draw()
    self.fire:draw()
    local txt = "select a stage!"
    print(txt,txtM(txt), 20,11)
    local st = self.st[self.i]
    setPal()
    map(st.x, 1, 44, 44, 5, 5)
    if self.i == 3 then
        darkMapPal()
        map(st.x,1,44,44,5,5,0x80)
    end
    setPal()
    print(st.t, txtM(st.t), 100, 11)
    spr(37, self.leftArrowX, 60, 1, 1, true)
    spr(37, self.rightArrowX, 60)
end

_winSelectionScene = {
    scrollOffset = -64,
    winNumber = 1,
    selected = false,
    upArrowY = 50,
    downArrowY = 67,
    fire
}

function _winSelectionScene:onLoad()
    self.scrollOffset = -64
    self.selected = false
end

function _winSelectionScene:update()
    self.upArrowY, self.downArrowY = 50, 67

    local sO = self.scrollOffset
    sO = sO < 0 and sO + 5 or 0
    self.scrollOffset = sO

    if not self.selected then
        if btnp(⬆️) and self.winNumber < 9 then
            sfx(4)
            self.upArrowY += 1
            self.winNumber += 1
        end
        if btnp(⬇️) and self.winNumber > 1 then
            sfx(4)
            self.downArrowY -=1
            self.winNumber -= 1
        end
        if btnp(❎) then
            sfx(3)
            self.selected = true
        end
    else 
        if (btnp(🅾️)) then
            self.selected = false
        end

        if btnp(❎) then
            sfx(1)
            mainScene.neededWins, roundIndicationScene.round = self.winNumber, 1
            currentScene = changeScene(self, roundIndicationScene)
            music(-1, 800)
            sfx(2)
            cam:getComponent("Camera"):shake(0.4, 3)
        end
    end
    self.fire:update()
end

function _winSelectionScene:draw()
    self.fire:draw()
    local sO = self.scrollOffset
    rectfill(90-sO, 54, 100-sO, 70, 1)
    rect(89-sO, 53, 101-sO, 71, 11)
    spr(36, 91-sO, self.upArrowY)
    spr(36, 91-sO, self.downArrowY,1,1,false, true)
    print(self.winNumber, 94-sO, 60)
    print("how many wins?", 28-sO, 60)

    if self.selected then
        print(self.winNumber,94,60,7)
        textFx:drawBlinkingText("❎",51,85)
        spr(109,60,84,2,1)
    end
end

_mainScene = {  
    bombs = {},
    explosions = {},
    playerCount,
    livingPlayers = {},
    neededWins,
    timer
}

function _mainScene:start()
    mapEnt.layer = 1
    self:addEntity(mapEnt)
    mapEnt:load()
    mapEnt:generateMap()
    particleSystem.layer = 5
    self:addEntity(particleSystem)
    self:addEntity(playerUI)
    self.timer = createEntity(_Timer)
    self:addEntity(self.timer)
    local stageHazard = createEntity(_stageHazard)
    stageHazard.timer = self.timer
    self:addEntity(stageHazard)
    initCollisionMap()
    self:setUpPlayers()
    music(05, 700)
end

function _mainScene:lateUpdate()
    if #self.livingPlayers <= 1 and self.timer.isRunning then
        self:endRound()
    end
    self:reindex()
end

function _mainScene:unload()
    self._entities = {}
    self._entitiesIndexed = {}
    self._entitiesSorted = {}
    self.livingPlayers = {}
    self.bombs = {}
    self.explosions = {}
    gPlayers = {}
end

function _mainScene:setUpPlayers()
    for i=0,self.playerCount-1 do
        local player = createPlayer(i)
        self:addEntity(player)
        add(self.livingPlayers, player.name)
        add(gPlayers, player:getComponent("Player"))
    end
end

function _mainScene:onPlayerDied(entityName)
    del(self.livingPlayers, entityName)
end

function _mainScene:endRound()
    local victoryEnt = createEntity(_VictoryUI)
    local mode
    local remaining = #self.livingPlayers
    if remaining == 0 then
        mode = "tie"
        music(25)
    else 
        mode = "victory"
        music(24)
        local winner = self:getEntity(self.livingPlayers[1]):getComponent("Player")
        winner:onRoundWin()
        playerUI.wins[winner.id + 1] += 1
        local playerWins = playerUI.wins[winner.id + 1]
        victoryEnt.winnerId = winner.id
        if (playerWins == self.neededWins) victoryEnt.isFinal = true 
        victoryEnt.layer = 8
    end
    victoryEnt:setMode(mode)
    self:addEntity(victoryEnt)
    self.timer.isRunning = false
end

function _mainScene:reindex()
    local nBombs = {}
    for i,b in pairs(self.bombs) do
        local newCell = to_map(b.transform.x, b.transform.y)
        local newIndex = mapIndex(newCell)
        if newIndex != i then
            self:removeBomb(IndexToCell(i))
            nBombs[newIndex] = b
            mset(newCell.x + mapsize, newCell.y + mapsize, b.sprite.sprite)
        end
    end
    self.bombs = assign(self.bombs, nBombs)
end

function _mainScene:setExplosion(cellPos,value)
    self.explosions[mapIndex(cellPos)] = value
end

function _mainScene:getExplosion(cellPos)
    return self.explosions[mapIndex(cellPos)]
end

function _mainScene:addBomb(bomb, cellPos)
    self.bombs[mapIndex(cellPos)] = bomb
    mset(cellPos.x + mapsize, cellPos.y + mapsize, bomb.sprite.sprite)
end

function _mainScene:removeBomb(cellPos)
    local index = mapIndex(cellPos)
    if self.bombs[index] then
        mset(cellPos.x + mapsize, cellPos.y + mapsize, 0)
        self.bombs[index] = nil
    end
end

function _mainScene:getBombAtCell(cellPos)
    return self.bombs[mapIndex(cellPos)]
end

_stageHazard = {
    top = 0,
    bottom = 10,
    left = 0,
    right = 10,
    dir = 1,
    index = 0,
    delay = 0,
    cellX,
    cellY,
    timer
}

function _stageHazard:update()
    if ((not self.timer.isRunning) or self.timer.time > 40) return 
    self.delay -= dt
    if self.delay <= 0 then
        local cellPos = self:getNext() --get Next and mset and collision set
        mset(cellPos.x, cellPos.y, 175)
        mset(cellPos.x + mapsize, cellPos.y + mapsize, 1)
        local nextCell = self:peak()
        mset(nextCell.x, nextCell.y, 38)
        sfx(42, 3)
        --cam:getComponent("Camera"):shake(0.2, 1.5)
        self.delay = 0.3
    end
end

function _stageHazard:getNext()
    local dir, index = self.dir, self.index
    local cellX, cellY = self.cellX, self.cellY
    if dir == 1 then
        cellY = self.top
        cellX = index
        index += 1
        if index > self.right then
            self.top +=1
            dir = 2
            index = self.top
        end
    elseif dir == 2 then
        cellY = index
        cellX = self.right
        index += 1
        if index > self.bottom then
            self.right -= 1
            dir = 3
            index = self.right
        end
    elseif dir == 3 then
        cellY = self.bottom
        cellX = index
        index -= 1
        if index < self.left then
            self.bottom -= 1
            dir = 4
            index = self.bottom
        end
    elseif dir == 4 then
        cellY = index
        cellX = self.left
        index -= 1
        if index < self.top then
            self.left += 1
            dir = 1
            index = self.left
        end
    end
    self.dir, self.index = dir, index
    self.cellX, self.cellY = cellX, cellY

    local s = mget(cellX + 3, cellY + 4)
    if fget(s,0) and not fget(s,1) then
        return self:getNext()
    else 
        return {x=self.cellX + 3, y=self.cellY + 4}
    end
end

function _stageHazard:peak()
    local dir, index, x, y = self.dir, self.index, self.cellX, self.cellY
    local l,r,b,t = self.left, self.right, self.bottom, self.top
    local result = self:getNext()
    self.dir, self.index, self.cellX, self.cellY = dir, index, x, y
    self.left, self.right, self.bottom, self.top = l,r,b,t
    return result
end

_roundIndicationScene = {
    round = 1,
    dur = 1.5,
    x = 0,
    y = 64,
    txt
}

function _roundIndicationScene:start()
    self.dur, self.y = 1.5, 64
    self.txt = "round " ..self.round .."!" 
    self.x = txtM(self.txt)
end

function _roundIndicationScene:update()
    if (self.dur > 0) self.dur -= dt else self.y -= 5
    if self.y < -10 then
        currentScene = changeScene(self, mainScene)
        cam:getComponent("Camera"):shake(0.4, 3)
        sfx(1, 3)
    end
end

function _roundIndicationScene:draw()
    print(self.txt, self.x, self.y, 11) 
end

_victoryScene = {
    champId,
    champ,
    spr = 108,
    state = "fall",
    tran,
    tCount = 35,
    victoryUI
}

function _victoryScene:onLoad()
    local ent = createPlayer(self.champId)
    ent:init()
    ent:getComponent("Player").active = false
    ent:removeComponent("Player")
    local anim = ent:getComponent("Animator")
    local landing = animation.createAnimation({69,106,106,69,69,69,69}, 5)
    anim:addAnimation("Landing", landing)
    self.trans = ent:getComponent("Transform")
    self.trans:setPosition(63, 0)
    ent:getComponent("Sprite"):setDrawingOffset(0,0)
    self.champ = ent

    local victoryEnt = createEntity(_VictoryUI)
    victoryEnt.winnerId = self.champId
    victoryEnt.y = 35
    victoryEnt.onBtnPress = function(self) 
        currentScene = changeScene(victoryScene, titleScene)
    end
    victoryEnt:setMode("champ")
    self.victoryUI = victoryEnt
    music(21)
end

function _victoryScene:update()
    local y = self.trans.y
    local state = self.state
    if state == "fall" then
        if (y <= 20) y+=3
        if (y > 20 and y < 80) y+=7
        if y >= 80 then
            self.champ:getComponent("Animator"):setAnimation("Landing")
            self.state = "landing"
            cam:getComponent("Camera"):shake(0.4, 3)
        end
    elseif state == "landing" then
        self.tCount -= 1
        if self.tCount <= 0 then
            self.champ:getComponent("Animator"):setAnimation("Victory")
            self.state = "jumping"
            self.tCount = 1
        end
    elseif state == "jumping" then
        local c = self.tCount % 24
        if (c >= 8 and c < 16) y-=1
        if (c >= 16 and c < 24) y+=1
        self.tCount += 1
    end

    self.trans.y = y
    self.champ:update()
    if (state != "fall") self.victoryUI:update()
end

function _victoryScene:draw()
    map(64,0,0,0)

    setPlayerPal(self.champId)
    self.champ:draw()
    setPal()
    spr(47,60,106)
    if (self.state != "fall") self.victoryUI:draw()
end

-->8
--Main
mapsize, tilesize= 16, 8
itemBitfield = 0x7C

gPlayers = {}

--set up Cam
cam = createEntity()
cam:addComponent(createComponent(_camComponent))
mapEnt = createEntity(_mapComponent)
particleSystem = createEntity(_particleSystem)
playerUI = createEntity(_PlayerUI)

mainScene = createScene(_mainScene)
titleScene = createScene(_titleScene)
selectionScene = createScene(_selectionScene)
winSelectionScene = createScene(_winSelectionScene)
roundIndicationScene = createScene(_roundIndicationScene) 
_stageSelectionScene = createScene(_stageSelectionScene)
credits = createScene(_credits)

currentScene = credits
--currentScene = titleScene

--showFps = false

function _init()
    --menuitem(1, "show fps", function() showFps = not showFps end)
    setPal()
    poke(0x5f2e,1) --keep Pallete
    currentScene:onLoad()
end

function _update()
    cam:update()
    currentScene:update()  
end

dt = 0.03333

function _draw()
    -- delta time
    dt = 1 / stat(7)
    cls()
    cam:draw()
    currentScene:draw()

    --perf_after = stat(1)
    --if(showFps) print("fps: " .. stat(7),0,0,6)
end

function setPal()
    --custom palette
    pal()
    local _pal={0,129,130,138,139,5,6,10,13,140,8,7,9,132,136,12}
    for i,c in pairs(_pal) do
        pal(i-1,c,1)
    end
end

function setPlayerPal(id)
    if id == 0 then 
        setPal()
        return
    end
    local _pal={{15,9},{3,4},{7,12}}
    local playerPal = _pal[id]
    pal(10,playerPal[1])
    pal(14,playerPal[2])
end

function dimPal()
	pal(1,0)
	pal(10,1)
	pal(14,2)
	pal(5,1)
	pal(2,1)
	pal(7,2)
	pal(11,2)
	pal(13,2)
	pal(12,1)
	pal(8,1)
end

function darkMapPal()
    pal(3,4)
    pal(4,5)
    pal(7,8)    
    pal(5,13)
end

__gfx__
00000000111111122cccd7b2eaac7aaa888888888888888888888888377342528888888888888888ffffffff3333333333333333333333332444433333442000
000000001b6b66622dddddd2e33c73aa888528888888888883888828344422d28828885888288888ffffffff3733374734377333333773432437344333774200
0070070016b666622ccdc7b2cc344377888888688888888888388888377774228888588888888838ffffffff4733374734373333333373434433733333337420
000770001b6666622dddddd2eaa33aaa888888288888888882488b88333334422888888888888488ffffffff47333743437333733733373474733773333334d0
000770001bbbbbb22cdccdb2eaac7aaa88888888888888888888bcb8333334d08888828883888428ffffffff2473372447337743347733747347337333333442
007007001111111222222222eaac7aaa885688888888888885884b88333374208868888884888888ffffffff2244442243374433334473347347333337777422
000000001558bb822aaa2ac2eeecceee882288288888888888882428337742008888882882488858ffffffff552d42d5444433733733444447347333344422d2
000000002222222222222222222cc222888888888888888888888888334420008288888888888888ffffffff2222222222477743347774223333333337734252
99999999bbbbbbbbbbbbbbbbbbbbbbbb00c0000001a111008d7cc7d8bbbbbbbbbbbbbbbbbbbbbbbb881111883344225222222222252244333334444200024433
9bbfbff9bbbb66bbbb56bbbbbbbbbbbb0c7c11001a7a1110dce43e7dbbbbbbbbbbb66bbbbbbbbb6b81555618337742525d24d255252477333443734200247733
9bbfbff9bbbb56bbbbbbbbbbbbbbbbbb0eced1101eced12127e44ec7bbbbbbbbbb666bbbbbbbbbbb151111613333742222444422224733333337334402473333
1bbfbff9bbbbbbbbbbbbbbbb66bbbb6601edb11011edb121edcee7ccbbbbbbbbbb66bbbbbbbbbbbb11556611333334d2427337422d433333377337470d433333
1bbbbbb9b6bbbb6666bbb56b886666810111121011111221ddcccd7cbbbbbbbbbbbb66bbb6bb6bbb1552d6613333344234733374244333333733743724433333
11111999b5bbb611116bb66b1111111101112110111222112eeccd7cbbbbbbbbbbb666bbbbbbbbbb1522dd613777742274733374224777733333743722477773
1fbbfbf9bbbb61181116bbbb8188818802111120211111122eeecd72bbbbbbbbbbb66bbbbbbbbbbb1552d661344422d2747333332d224443333743742d224443
11111111bbbb61111816bbbb11111111002222000222222082222d28bbbbbbbbbbbbbbbbbbbbbb6b222222223773425233333333252437733333333325243773
bbbb61111116bbbbbb681181bbb6118100000000000110008888888600000000000000000000000000000c0000000000000000000000000000000000000ccc00
bbbb61188116bbbbbbb6bb81bbb68181000010000001610086b6bbb6cc007b00777b00c7007b0c777b00c7c1100cc007b0c777b0007777b0c777b00000c7bc00
b5bbb611116bbb5bbbbb6111bbbb61110001b10000016b108b6bbbb6c7777b0c7cc7b0c7707b0c7ccb00eced110c7777b0c7ccb00c7cccc0c7cc7b000c77bc00
b6bbbb6666bbbb6bbbbb6181bbbb61810016bb1000016bb186bbbbb6c777770c777770c7c7770c7777701edb110c777770c777770c777770c77777000cd77c00
bbbbbbbbbbbbbbbbbbbb6bb1bbbb6181016666610001661086666666c7cc770c7cc770c7dc770c7cc7701111d10c7cc770c7cc770c7cccc0c7c7700000c77c00
bbbb56bbbb65bbbbbbbb6181bbbb6181011111110001610088888886ccddcc0ccddcc0cc0dcc0cccccc0111d110ccddcc0cccccc0c777770cc0ccc000c7777c0
bbbb66bbbb66bbbbbbb68111bbb6811100000000000110008bb6bb66dd00dd0dd00dd0dd00dd0dddddd00111100dd00dd0dddddd00ddddd0dd0ddd000cddddc0
bbbbbbbbbbbbbbbbbbb6b181bbb6818100000000000000006666666600000000000000000000000000000000000000000000000000000000000000000cccccc0
f7fffff93333333477c7777c333a7134fffffff92bbbb625bbbbbbbb18186bbb181b6bbb11111111000000009999999999999999ffffffff2524377311111111
777bfbf9333a33347c7c117c33b1cb14aaaffff9b6bb6665bbbbbbbb11186bbb11186bbb11111111000000009999999999999999ffffffff2d22444311111111
f7f6f6f933a33a347eced11c3b311214fffff5f9b1161165bbbbbbb61816bbbb1816bbbb10101010000000009999999999999999ffff9fff2247777311111111
fffbbbf933caac3471edb11c3aa311b4ffddfcf9baebea6566bbbb681816bbbb1bb6bbbb01010101000000009999999999999999fff999ff2443333311111111
bb61b1f93ac77a347111121ceaaeb334fd77dc29616b6165b86666b11816bbbb1816bbbb10101010000000009999999999999999ff99999f0d43333311111111
fbbbbb693c7b7a347111211ceee53334fd7d7cc966bbb665111b11b11116bbbb1116bbbb01010101000000009999999999999999f99999990247333311111111
f66f6ff933cba3347711117cee533334ccccccf92b0b0625818b818818186bbb18bb6bbb10101010000000009919991999999999999999990024773311111111
9999999944444444cccccccc4444444499999999555555551111111118116bbb181186bb01010101000000009111911199999999999999990002443311111111
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000c000000000000000000000c0000000000000000000000000000000000000000000000000000000000000
000000c000000000000000000000c000000000c00000cc000000000000000000000cc000000c000000000c000000000000000c00000000000000000000c00000
0000cc0000000d7c00000d7c0000cc000000cc0000007c000c7d00000c7d0000000c70000000cc000000cc00000c00000000cc000c7d000000000000000cc000
00007c000000d00c0000d0cc00007c0000007c000000d0000c00d0000cc0d0000000d00000007c0000007c000000cc0000007c000cc0d000000d0000000c7000
0000d0000000d0000000d00c0000d0000000d0000155d1100000d0000c00d0000000d0000000d0000000d00000007c000115d1100c00d0000c70d0000000d000
0155d110055551100aaaaaaa0155d1100155d110eaaaaaae0111d1100111d1100115d1100115d1100115d1100115d110a555db5a011155b00aaaaaa00111d110
a5552b5aaaaaaaaeeeeeeee1a5552b5aeaaaaaae1eeeeee1a1555b5111225b51a55a5b5aa55a5b5aa55a5b5aa555db5aa555555aeaaaaaaaeeeeeeeee11155ba
eaaaaaaeeeeeeee122222211eaaaaaae1eeeeee115155151eaaaaaaaaa255555eaaeaaaeeaaeaaaeeaaeaaaea555555aeaaeaaae1eeeeeee11122222eaaaaaaa
1eeeeee121221221515515211eeeeee112122121151551511eeeeeeeeeaaaaaa1eeaaee11eeaaee11eeaaee1eaaeaaae1eeeaee111222221111255551eeeeeee
121221215155152151551521121221211515515112555521122aa5521eeeeeee1222222112222221122222211eeeaee1122a2221112555511112555511222212
1515515105555210055552ea1515515115555551ae1111ea11a22221a1aa2221125555511255555112555551122a2221a211112a01125550011125ea11255515
01555510021111eaea1111ee0155551001111110eedd7deea1111120e5a111ae02111120021111200211112002111120e5dddd5e002112ea0e0112ee01125550
aedd7deaeadd7dee0aad7d00aedd7deaaedd7dea00111100e2ddddae00ddddeea5dddd5aa5dddd5aa5dddd5aa5dddd5a0a1111a00e0dddee000ddda000eadd00
ee1111ee0aa111000aa11100ee1111eeee1111ee00a00a00001111ee001111a0ee1111eeee1111eeee1111eeee1111ee0ee00ee000a111a000a111a000ee1100
2aa22aa22ee22aa222222aa22aa22aa22aa22aa20aa22aa02aa22aa22aa222222aa22aa22aa22aa22aa22aa22aa22aa22ee22ee202aa2a2002a22220022aa220
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c00000c0007777bb07777bb0bb55555555
00000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000cc0000007c0077cccc077cc770775bbbbbbb
0000000000000000000c000000c00000000cc00000000c00000007c000000c0000000000000000000000c00000007c000000d00077dddd077dd770775bbbbbbb
00007c0000000000000cc000000cc000000c70000000cc000000d0c00000700000000000000000000000cc000000d0000155d11077077707700770cc5bbbbbbb
0000dc00000007c0000c7000000c70000000d00000007c000000d0000000d000000070000000000000007c000155d110a5552b5a770d7707700770dd55555555
0000d0000000dcc00000d0000000d0000111d1100000d000055551100aaaaaa00000d000000070000000d000a5552b5aeaaaaaae777777077777707756666666
011155b00aaaaaa00111d1100111d110a11aaaaa0155d110aaaaaaae1e1ee1e10aaaaaa00000d0000155d110eaaaaaae1eeeeee1cccccc0cccccc0cc56bbbbbb
eaaaaaaaeeeeeeeee11155baa11aaaaaaaaeeeeea5552b5a1e1ee1e121555512121221210aaaaaa01555db511eeeeee151555515dddddd0dddddd0dd56bbbbbb
1eeeeeee11222222eaaaaaaaaaaeeeeeeee55515eaaaaaae21555512ae1551ea2155551212122121a555525a21222212151551515555555556bbbbbbbbbbbb65
11222122112515511eeeeeeeeee22212112555151eeeeee112155121ee1111eeae1551ea21555512eaaaaaae15155151ae5555eabbbbbbb556bbbbbbbbbbbb65
112551551125155111222212112555151112555111555511ae2222ea0aad7aa0ee1111ee151551511eeeeee102555520eedd7deebbbbbbb556bbbbbbbbbbbb65
011255500ea255521125551511125551011ea11015555551ee1111ee0ee11ee02aad7aa22555555212122121aedd7dea00111100bbbbbbb556bbbbbbbbbbbb65
0ea511e00ee2112e0112555001111110000eed000155551000dd7d000ee00ee00ee11ee0e211112eae1551eaee1111ee00a00a005555555556bbbbbbbbbbbb65
0eedd700000d7da000eadd0000eadd0000011100aedd7dea0aa11aa0000000000ee11ee0aadd7daaeedd7dee00a00a0000a00a006666666556bbbbbbbbbbbb65
000111a000a111a000ee110000ee1100000a0000ee1111ee0ee00ee00000000000000000ee1111ee0011110000a00a0000000000bbbbbb6556bbbbbbbbbbbb65
02aa2a2002a22220022aa220022aa220002ee2002aa22aa2022222200022220002222220ee2222ee0aa00aa00022220000022000bbbbbb6556bbbbbbbbbbbb65
007bb7000c7bb7c0ac7bb7caac7bb7caac7bb7caac7bb700007bb700000bb70000cc700000000000000000000000000000000000000a00000000000000000000
07bbb700c7bbb700cbbbbbbbc7bbbb7cac7bb7caa77bb7c0007bb700000bb7000c6067000cccccccccccccccc00000000000000000000000000a000000000000
7bbbbbb77bbbbb777bbbbbb77bbbbbb7ac7bb7ca0c7bb7ca007bb700007bb700c6b0b670cccccccccccccccccc000000000000aa00000aaaac00a00000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbac7bb7ca0c7bb7ca0c7bb700007bb700cbb50070cccccccccccccccccc0000000000000aa0000000c77ac00000c00000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbac7bb7ca0c7bb77a0c7bb700007bb700cbbbbbc0cccccccccccccccccc00000000000000000000000bbb700000000000
7bbbbbb77bbbbb777bbbbbbc7bbbbbb7ac7bb7caac7bb7c00c7bb7c0000bb7000cbbbc00cccccccccccccccccc0000000000000000002d2d2bbcc00000000000
007bbb70cb7bb700cbbbbbbbc7bbbb7cac7bb7ca077bb7c0077bb7c0007bb70000ccc000cccccccccccccccccc00000000000000000d2d2d2cbc000000000000
007bb7000c7bb7c0ac7bb7caac7bb7caac7bb7ca0c7bb7ca077bb7c0007bb700000000000cccccccccccccccc000000000000000002200000000000000000000
000000000000000000aaa00aaaaaaaaa00aab0000077b0000000b00056bbbbbbbbbbbb6500000e00000000000022222222d25555555000000000000000000000
0000000000000ccc0ccc7ccccccccccc0aeeeb0007cccb000008b00056bbbbbbbbbbbb650000ee00000ee00022222221112d2222222550000000000000000000
777777777777777777777777777777770a222a000c2227000082800056bbbbbbbbbbbb650000e00000eeee022222221100226122222265000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0e2aae0002277c000822800056bbbbbbbbbbbb650000e0000eeeee222222211111666615566666500000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb02aee200022cc7000888880056bbbbbbbbbbbb650000ee00eeee0e222222221111666155566666650000000000000000
007770777777777777777777777777770ae22200072227000222820056bbbbbbbbbbbb6500000eeee000eee2222222211111155555666226500000000000c000
00000000000ccc77c7cccc7ccccccccc0aaaaa000c777c000000800056bbbbbbbbbbbb65000000000000eeeee22222255555555555552222500000000000a000
0000000000000000aa000a00aaaaaaaa0eeeee0000ccc000000000005555555555555555000000000000eeeeeee2222255555555555200026500000000000000
0000000000000000aa00a000aaaaa0000000c0c77000000000000000000000000000000000000000000eeeeeeeeeeeee2222222222222eeee500000022222221
000000000cccc0007cccc000ccccca0000000cc7b00000000bbbbbbbbbbbbbbbbbb0000000eeee00000eeeeeeaaa1111eeeeeeeeeeee1111e500000028585551
7770000077777c0077777ca077777ca000000000d0000000bbbbbbbbbbbbbbbbbbbb00000eeeeee000e222eeeaaa11111aaaaaaaaaa11111e500000025855551
bbbbb700bbbbb7c0bbbbb7cabbbbb7ca00002222d2220000bbbbbbbbbbbbbbbbbbbb0000ee0eeeeeee02222eeeaaa11111aaaaaaaa11111ae500000028555551
bbbbb000bbbbb000bbbbb000bbbbb7c000022b65d2582e00bbbbbbbbbbbbbbbbbbbb0000e000eeeee00222222eeeeea111aaaaaaaa111aaae500000028888881
0077000077777c00b7777caa77777caa00ea26552555aa00bbbbbbbbbbbbbbbbbbbb0000000000000002222222222eeeeeeeeeeeeeeeeeee2500000022222221
00000000c000c000c7ccca00ccccca000e1eeaaaaaaaae00bbbbbbbbbbbbbbbbbbbb000000000000000222222222222200022222220022222500000025586681
0000000000000000aaaaa000aaaaa000aa12ee1eeeee12000bbbbbbbbbbbbbbbbbb0000000000000000222222222222000002222200002222500000011111111
0000000000000000000a0a00000a0a0000122211122112001111111111111111bbbbbbbb00000000000222222222255000605555500602222500000000000000
00000000000c000000ac0a0000acca000e122850555082008818b81888188818bbbbb66b00000000000222222222555000005555500002222522200000000000
0007000000c70c0000c70ca00ac77ca0ee122850555052a01b11b11111111111bbbbb56b0000000aeeaaaa2228825550000055555000028225eaa20000000000
000bb0000c7bb7c0ac7bb7caac7bb7caa001228555552aba1b66668b18666688bbbbbbbb000000aeeeeaaaa288885555000555555500288825eaa20002220000
000bb7000c7bb7000c7bb7caac7bb7ca00ea12222222eaab86bbbb6666bbbb66bbbbbbbb000000aeeeeeaaa228825555555555555555228225eaa2002aaa2000
007bb7000c7bb7000c7bb7caac7bb7ca0eeaa1111111eeaa6bbbbbbbbbbbbbbbb66bbbbb000000aeeee22222222255555555055505522222522220022aaa2000
007bb0000c7bb700ac7bb77aac7bb7ca0eeea1ddd7d00ee0bbbbbbbbbbbbbbbbb5bbbbbb000000aeeeeeeaaaa2222555555550005552222252eea22e2aaa2000
007bb000007bb7c0a77bbbcaac7bb7ca0111111111111111bbbbbbbbbbbbbbbbbbbbbbbb000000aeeeeeeaaaa2222555555555555522222502eea2ee22220000
000000099ff222222222222225166611111122222f000000000000000000000000000000000000aeeeeeeaaaa2552255555555555222225002eeaeeeaa200000
0000000999ff22222222222222216661111262222f000000000000000000000000000000000000aeeeee22222110555555555555555222222eeeaeeaa2000000
0000000999fff2222222222222221111112666222f000000000000000000000000000000000000aaeeeeeeaaa110011112dddd211002eea2eeeeeeea22022200
00000009999fff222222222222222222226666222f000000000000010000000000000000000000222222eeaaa1101111112222111102eea2eeeeeeeeee2aaa20
000000099999fff2222222222222225555666622f90000000000001100011000000000000000aaaaaaaa2aaa11111111111111111102eea2eeeeeeeeee2aaa20
00000000999999fff2222222222222555556622ff9000000555555550011111055555555000a1111111aa22111111111117771111d00222eeeeeeeeeaa2aaa20
000000009999999ffff2222222222225555522ff990000005555555a001111552555555500a111111222aa21222ddddd2ccc772ddd0000222eeeeeaaa2022200
00000000599999999ffff2222222222222222ff91100000055555550000115222555555500e1111222222aa2222ddddd2ccc772ddd0002eee2aaaaaa20000000
0000000052999999999ffffff11111211111ff919999000000000000000ff2222555555500e1112222222aa22222dddd2cc7772ddd112eeeee22222200000000
000000005222999999999fff1fffff1fffff1919999990000000000009ff22222255555500e1112222222aa21111111111777111111122eeeeeeeeee00000000
000000000522299999999991fffff11ffffff19111999900000000000ff222222255555500e1112222222aa211111111111111111112aa2eaaeeeeee00000e00
000000000522229999999991fffff191ffffff1220099990000000009ff222222225555500e1112222222aa211110011111111101112aa2aaaaeeee000002e00
000000000052222299999919ffff19991111111220909990000000009ff222222222555500e1112222222aa200011001111111001112aa2aaaaaaee000002000
009990111005222222299919ffff19999999222209909999000000099ff222222222255500e1112222222aea25001100111111001112aa2aaaaaae0000000000
0999900111005222222222999fff12222222222099109999000000099ff222222222225500e1111222000aeaa250100000000000000022eaaaaaae0000000000
999999001110055522222299999922222222220091109999000000099ff222222222222200e1111000000aeaa25010000000000000000eeaaaaaa00000000000
999991111110000000111199999900000111000201109999000000099ff2222222222222000e000000222aeaa22000000000000000000eeaaaaa000000000000
9991111111022200011111999999000000099922011099990000000999ff222222222222000e000111222aaaa200000000000000000000eeaaa0000000000000
9911111110222220111110999999000000999922011099990000000999fff22222222222000e111111222aaa2000000000e000000000000eee00000000000000
99111111102222201111000999990000009919920111099900000009999fff2222222222000e111111122ae2000000000ee00000000000000000000000200000
911111111022222011110000999990000990112201111000000000099999fff2222222220000e11111111e20000000000ee00000000000000000000000200000
91111111110222001110000009999999990011000111100000000009999999fff222222200000e111111ee20000000000eee0000000000000000000000000000
9111111111100000d11000000009999990001d0000111000000000009999999ffff22222000000eeeeeee2000000000000ee0000000000000000000000000000
0111111111100000ddd00000000000000000d2000000000000000000599999999ffff22200000000000000000000000000000000000000000000000000000000
0011111111000000dddddddddddddddddddd220025166611111122222f00000055555552e7bb700000000000000a000000000000000000000a00000000000000
00000000000000001ddd2222222222222222210022216661111262222f0000005555555c20bb2f000000000000a0000000000000000000000a00000000000000
000000000000000011dd2222222222222222110022221111112666222f0000005555111dcc0055f0000000000a00000a0000000000000000a000000000000a00
000000000000000011100000000000000000110022222222226666222f0000005551661220c2555f000000001aa000a000000000000000000000000000000000
00000000000000001110000000000000000011002222225555666622f90000005516661dd2115555f00000001ac000a00000000000000000000a000000000000
0000000000000000011000000000000000011000222222555556622ff900000055166122dd115552f0000000acca0aa000000000000000000000000000000000
000000000000000000110000000000000001000022222225555522ff99000000551661dd211155522f000000ac7aac000000000a000000000000000000000000
00000000000000000000000000000000000000002222222222222ff91100000055166111111155222f000000c7bb7a000000000a000a00000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000888890080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000800000009aa890000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000777a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000ikiki77990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000kikiki97900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000ii0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000o000000000000iiiiiiiiki5555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000oo00000oo000iiiiiiihhhikiiiiiii550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000o00000oooo0iiiiiiihh00ii6hiiiiii65000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000o0000oooooiiiiiiihhhhh6666h5566666500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000oo00oooo0oiiiiiiiihhhh666h55566666650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000oooo000oooiiiiiiiihhhhhh55555666ii65000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000oooooiiiiii5555555555555iiii5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000oooooooiiiii55555555555i000i6500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000oooooooooooooiiiiiiiiiiiiioooo500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00oooo00000oooooo888hhhhoooooooooooohhhho500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0oooooo000oiiiooo888hhhhh8888888888hhhhho500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
oo0ooooooo0iiiiooo888hhhhh88888888hhhhh8o500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
o000ooooo00iiiiiiooooo8hhh88888888hhh888o500000000000000000000000000000000000000000000000000090000000000000000000000000000000000
00000000000iiiiiiiiiioooooooooooooooooooi500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000iiiiiiiiiiiii000iiiiiii00iiiii500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000iiiiiiiiiiii00000iiiii0000iiii500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000iiiiiiiiii5500000555550000iiii500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000iiiiiiiii55500000555550000iiii5iii00000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000008oo8888iiiddi55500000555550000idii5o88i0000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000008oooo8888idddd5555000555555500idddi5o88i000iii0000000000000000000000000000000000000000000000000000000000000000000000000000
0000008ooooo888iiddi5555555555555555iidii5o88i00i888i000000000000000000000000000000000000000000000000000000000000000000000000000
0000008ooooiiiiiiiii555555550555055iiiii5iiii00ii888i000000000000000000000000000000000000000000000000000000000000000000000000000
0000008oooooo8888iiii55555550555055iiiii5ioo8iioi888i000000000000000000000000000000000000000000000000000000000000000000000000000
0000008oooooo8888iiii5555555500055iiiii50ioo8iooiiii0000000000000000000000000000000000000000000000000000000000000000000000000000
0000008oooooo8888i55ii55555555555iiiii500ioo8ooo88i00000000000000000000000000000000000000000000000000000000000000000000000000000
0000008oooooiiiiihh0555555555555555iiiiiiooo8oo88i000000000000000000000000000000000000000000000000000000000000000000000000000000
00000088oooooo888hh00hhhhikkkkihh00ioo8iooooooo8ii0iii00000000000000000000000000000000000000000000000000000000000000000000000000
000000iiiiiioo888hh0hhhhhhiiiihhhh0ioo8iooooooooooi888i0000000000000000000000000000000000000000000000000000000000000000000000000
000088888888i888hhhhhhhhhhhhhhhhhh0ioo8iooooooooooi888i0000000000000000000000000000000000000000000000000000000000000000000000000
0008hhhhhhh88iihhhhhhhhhhhaaahhhhk00iiiooooooooo88i888i0000000000000000000000000000000000000000000000000000000000000000000000000
008hhhhhhiii88ihiiikkkkki999aaikkk0000iiiooooo888i0iii00000000000000000000000000000000000000000000000000000000000000000000000000
00ohhhhiiiiii88iiiikkkkki999aaikkk000ioooi888888i0000000000000000000000000000000000000000000000000000000000000000000000000000000
00ohhhiiiiiii88iiiiikkkki99aaaikkkhhioooooiiiiii00000000000000000000000000000000000000000000000000000000000000000000000000000000
00ohhhiiiiiii88ihhhhhhhhhhaaahhhhhhhiioooooooooo0000000000hh88hhhhhh000000000000000000000000000000000000000000000000000000000000
00ohhhiiiiiii88ihhhhhhhhhhhhhhhhhhhi88io88oooooo0000000000hh88hhhhhh000000000000000000000000000000000000000000000000000000000000
00ohhhiiiiiii88ihhhh00hhhhhhhhh0hhhi88i8888oooo000000000hh88aa88hhhhhh0000000000000000000000000000000000000000000000000000000000
009999iiiiaa778i00aaaaaa77hhhh99aahi88aa778899aaaaaa7700hh88aa88hhhhhh0099990000aa770099aaaaaa77000000aaaaaaaa770099aaaaaa770000
009999iiiiaa77o8i5aaaaaa77hhhh99aahi88aa778899aaaaaa7700hhoo99ookkhhiihh99990000aa770099aaaaaa77000000aaaaaaaa770099aaaaaa770000
0099aaaaaaaa77o899aa9999aa770099aaaaiiaa778899aa99997700hhoo99ookkhhiihh99aaaaaaaa770099aa999977000099aa999999990099aa9999aa7700
0099aaaaaaaa77o899aa9999aa770099aaaa0oaa778899aa99997700hhhhookk77hhiihh99aaaaaaaa770099aa999977000099aa999999990099aa9999aa7700
0099aaaaaaaaaao899aaaaaaaaaa0099aa99aaaaaa8899aaaaaaaaaahhhhookk77hhiihh99aaaaaaaaaa0099aaaaaaaaaa0099aaaaaaaaaa0099aaaaaaaaaa00
0099aaaaaaaaaa8899aaaaaaaaaa0099aa99aaaaaa8099aaaaaaaaaahhhhhhhhhhiiiihh99aaaaaaaaaa0099aaaaaaaaaa0099aaaaaaaaaa0099aaaaaaaaaa00
0099aa9999aaaa8899aa9999aaaa0099aakk99aaaa0099aa9999aaaahhhhhhhhhhiiiihh99aa9999aaaa0099aa9999aaaa0099aa999999990099aa99aaaa0000
0099aa9999aaaaoi99aa9999aaaa0099aakk99aaaa0099aa9999aaaahhhhhhiiiiiihhhh99aa9999aaaa0099aa9999aaaa0099aa999999990099aa99aaaa0000
009999kkkk9999i09999kkkk999900999900kk999900999999999999hhhhhhiiiiiihhhh9999kkkk9999009999999999990099aaaaaaaaaa0099990099999900
009999kkkk9999i09999kkkk999900999900kk999900999999999999iihhhhhhhhhhhhii9999kkkk9999009999999999990099aaaaaaaaaa0099990099999900
00kkkkooookkkk00kkkk0000kkkk00kkkk0000kkkk00kkkkkkkkkkkkiihhhhhhhhhhhhiikkkk0000kkkk00kkkkkkkkkkkk0000kkkkkkkkkk00kkkk00kkkkkk00
00kkkk0000kkkk00kkkk0000kkkk00kkkk0000kkkk00kkkkkkkkkkkk00iiiiiiiiiiii00kkkk0000kkkk00kkkkkkkkkkkk0000kkkkkkkkkk00kkkk00kkkkkk00
0000000000000000000000000000000000000000000000000000000000iiiiiiiiiiii0000000000000000000000000000000000000000000008000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000800000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000hh880008000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000hh00000000000000000hhh890008000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000hhhhh055555555555555558998088000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000hhhh55i55555555555555889a8890000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000hh5iii5555555555555509a77a80000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cciiii55555555555555ioa77a00000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000scciiiiii55555555555559i077ic0000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cciiiiiii5555555555hhhk990055c000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000scciiiiiiii55555555h66hii09i555c00000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000scciiiiiiiii555555h666hkkihh5555c0000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000scciiiiiiiiii55555h66hiikkhh555ic0000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000scciiiiiiiiiii5555h66hkkihhh555iic000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000scciiiiiiiiiiiii55h66hhhhhhh55iiic000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000sscciiiiiiiiiiiiii5h666hhhhhhiiiiic000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ssscciiiiiiiiiiiiiiih666hhhhi6iiiic000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000sssccciiiiiiiiiiiiiiihhhhhhi666iiic000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ssssccciiiiiiiiiiiiiiiiiiii6666iiic000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000sssssccciiiiiiiiiiiiiii55556666iics000000
000000000000000000000000000000o000000000000000000000000000000000000000000000000000000000ssssssccciiiiiiiiiiiii5555566iiccs000000
00000000000000000000000000000io000000000000000000000000000000000000000000000000000000000ssssssscccciiiiiiiiiiii55555iiccss000000
00000000000000000000000000000i00000000000000000000000000000000000000000000000000000000005sssssssscccciiiiiiiiiiiiiiiiccshh000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000005issssssssscccccchhhhhihhhhhccshssss0000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000005iiisssssssssccchccccchccccchshssssss000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005iiisssssssssshccccchhcccccchshhhssss00
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005iiiissssssssshccccchshcccccchii00ssss0
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005iiiiisssssshscccchssshhhhhhhii0s0sss0
0000000000000000000000000000000000000000000000000000000000000000000000000000000000sss0hhh005iiiiiiissshscccchsssssssiiii0ss0ssss
000000000000000000000000000000000000000000000000000000000000000000000000000000000ssss00hhh005iiiiiiiiisssccchiiiiiiiiii0ssh0ssss
00000000000000000000000000000000000000000000000000000000000000000000000000000000ssssss00hhh00555iiiiiissssssiiiiiiiiii00shh0ssss
00000000000000000000000000000000000000000000000000000000000000000000000000000000ssssshhhhhh0000000hhhhssssss00000hhh000i0hh0ssss
00000000000000000000000000000000000000000000000000000000000000000000000000000000ssshhhhhhh0iii000hhhhhssssss0000000sssii0hh0ssss
00000000000000000000000000000000000000000000000000000000000000000000000000000000sshhhhhhh0iiiii0hhhhh0ssssss000000ssssii0hh0ssss
00000000000000000000000000000000000000000o00000000000000000000000000000000000000sshhhhhhh0iiiii0hhhh000sssss000000sshssi0hhh0sss
0000000000000000000000000000000000000000oo00000000000000000000000000000000000000shhhhhhhh0iiiii0hhhh0000sssss0000ss0hhii0hhhh000
0000000000000000000000000000000000000000oo00000000000000000000000000000000000000shhhhhhhhh0iii00hhh000000sssssssss00hh000hhhh000
0000000000000000000000000000000000000000ooo0000000000000000000000000000000000000shhhhhhhhhh00000khh00000000ssssss000hk0000hhh000
00000000000000000000000000000000000000000oo00000000000000000000000000000000000000hhhhhhhhhh00000kkk00000000000000000ki0000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000hhhhhhhh000000kkkkkkkkkkkkkkkkkkkkii0000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000hkkkiiiiiiiiiiiiiiiiih0000000000
000000000000000000000i00000000000000000000000000000000000000000000000000000000000000000000000000hhkkiiiiiiiiiiiiiiiihh0000000000
000000000000000000000i0000000000000000000000000000i000000000000000000000000000000000000000000000hhh00000000000000000hh0000000000
00000000000000000000000000000000000000000000000000i000000000000000000000000000000000000000000000hhh00000000000000000hh0000000000
0i00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000hh0000000000000000hh00000000000
0i000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000hh000000000000000h000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
000103030000008100000081818181810101010101010300000001818181818101010101000000000000000000000000060a1222420e0101010000000000810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000008d8e0000000000000000000000000000000000000000000000000000000a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a000011361313120000000d0b0b0b0c000d0b0b0b0c000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000999a9b9c9d9e00000000000000000000000000000000000000000000000000000a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a000023b81719380000001b0405091d001b0508061d000000000000000000000000000000000000000000000000000000
001f0d0b0b0b0b0b0b0b0b0b0b0b0c0f00000000000000000000000000000000a9aaabacadae00000000000000000000000000000000000000000000000000000a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a000022170317370000001b0502081d001b0916051d000000000000000000000000000000000000000000000000000000
001d1b35350505040504050535351d1b00000000000000000000000000000000b9babbbcbdbebf000000000000000000000000000000000000000000000000000a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a000023171817370000001b0605051d001b0505041d000000000000000000000000000000000000000000000000000000
001d1b35010801050105010801351d1b00000000000000000000000000000000c9cacbcccdcecf000000000000000000000000000000000000000000000000000a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a000020b7b7b6210000001e1c1c1c0e001e1c1c1c0e000000000000000000000000000000000000000000000000000000
001d1b05050505060504050505051d1b00000000000000000000000000000000d9dadbdcddde00000000000000000000000000000000000000000000000000000a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001d1b05010501050105010501051d1b00000000000000000000000000000000e9eaeb00edee000000000000fc0000fe000000000000000000000000000000000a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001d1b08050505050506050505061d1b000000000000000000000000000000000000000000000000000000c7c8c6fb00000000000000000000000000000000003d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001d1b05010501040105010801051d1b000000000000000000000000000000000000000000000000000000d7d8f8f9fa000000000000000000000000000000003c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001d1b06090505050508050505061d1b0000000000000000000000000000000000000000000000000000c0c1c2c3c4c5000000000000000000000000000000003c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001d1b09010501050105010401051d1b0000000000000000000000000000000000000000000000000000d0d1d2d3d4d5000000000000000000000000000000003b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001d1b05090504050508050505051d1b0000000000000000000000000000000000000000000000000000e0e1e2e3e4e5000000000000000000000000000000003f3f3f3f3f3f3f6f7d3f3f3f3f3f3f3f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001d1b35010501060105010401351d1b0000000000000000000000000000000000000000000000000000f0f1f2f3f40000000000000000000000000000000000393939393939397e7f39393939393939000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001d1b35350505050405050535351d1b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a3a3a3a3a3a3a97983a3a3a3a3a3a3a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
003e1e1c1c1c1c1c1c1c1c1c1c1c0e070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000001f0d0b0b0b0b0b0b0b0b0b0b0b0c0f003711133613363613361313361312220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000001d1b35350504050408050535351d1b0038233535181717b8171917353538220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000001d1b351a051a091a051a081a351d1b003823351017101710181017103537220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000001d1b05050408050506040505091d1b0037221917b819191717b817171737230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000001d1b051a051a051a051a081a051d1b003823191017101710171019101738230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000001d1b04090505090804050506081d1b003823b8171817b8171917b8171837230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000001d1b051a081a041a051a091a051d1b00372217101710171017101710b838220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000001d1b06050504050508050505041d1b003823191717191717171819171737220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000001d1b041a091a051a051a091a051d1b003823171017101710171017101937220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000001d1b05050405080509050605081d1b00372219b817171817b81717b81937230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000001d1b351a051a051a041a051a351d1b003822351017101910171017103538230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000001d1b35350506040505050535351d1b0037233535191717b8171719353537220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000003e1e1c1c1c1c1c1c1c1c1c1c1c0e07003720b6b6b7b6b7b7b6b6b7b7b721230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010100002375021750177501875012750057500a7500975006750067500275000750067500b350143500732004310043000230002300013000170001700007000070000700087000770007700077000770007700
000300001962018610186701867018660176601e6501f6501d6500f6500e6400d6400c64015630176301563007630066300563004630036201162011620116200162001610016100061000620006100061000600
0109000023555275552f5552a5502a5202a5102a5002a50000000177041c6001e700277001c7001e70017700177001c7001e70027700177001c7001e70027700177001c7001e70027700177001c7001e70027700
010900002a55527555235552f5502f5302f5100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01030000000000000026520285402b520063000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01100000201422010021142231420000028142281001c14200000000001c12200000000001c1121c1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01100000041600ce75041600ce75041600ce750416510164001000015310124001530e1650e1000e165101650016508e7508e0008e750c16508e75001650c1640c100001630c124001630b165001630b16509165
010f00000000000000000001e4421e442000001e4401b440174402544225444234400000021440000002344023444234442342423413234002340000000000000000000000000000000000000000000000000000
01100010156530e6250000000000326351a635006350966309635046350063500600356351a6350063509635156630e6350000000000326351a635006350963309655046350063500635296451a6450063509624
01100000281242312521125201252112523125281242312521125201252112523125281242312521125201252812423125211251f125211252312528124241252312521127231252412528124241252312521125
0108002009631026352b40029400286241c400346250000011633345002b635286352663334500286422863028625000002b645286451a64500000286353450030625306133b6101a40030625306133b61032500
011000001441214412144121441214412144121441214412144121441215412154121541217412174121741218412184121841218412184121841218412184121841218412174121741217412154121541215412
010f000000000000000000000453000000000017240192401b2401c240034001b2400040019250152001b2421b2321b2221b21300000000000000000000000000000000000000000000000000000000000000000
010f00000000000000000000b05000655246350b0550b0550b0553062230612246120905007050090500b0500b0500b0320b0320b0220b0130000000000000000000000000000000000000000000000000000000
010f0000000000000000000200500000021055230510000028055000001c0501c0530000000000000001b0511a051190511805118050180501805018052180521805218052180530000000000000000000000000
010f00000000000000000001f0300000020030220300000027030000001b030000000000000000000001a03019030180301703017030170301703017030160301502014020130560000000000000000000000000
010f0000281242312521125201252112523125281242312521125201252112523125281242312521125201252812423125211251f1252112523125281242a1252b1252d12532125341252f5342d5452c5552a565
010f0000041400414004140041400414004140041400414004140041400414404140041400214402140021400014500145001000014500140001400014000140021400414006144091400e140151441e14026140
010f00001a6651a6651c0551a6651a0551c055326751e0552d7331c0551c0001c0551a055000001c055277331a6651a665180551a6651a0551c0551a67515055000002f65513055170552f655150452f6552f655
011000000414004140041400414004140041400414004140041400414004144041400414002144021400214000144001400014000140001400014000140001400014000140001440014000140021440214002143
010f0010156530e6250000000000326351a635006350966309635046350063500600356351a6350063509635156630e6350000000000326351a635006350963309655046350063500635296451a6450063509624
010f0000281242312521125201252112523125281242312521125201252112523125281242312521125201252812423125211251f125211252312528124241252312521125231252412528124241252312521125
010f00000414004140041400414004140041400414004140041400414004144041400414002144021400214000145001450010000145001400014000140001400014000140001440014000140021440214002143
01100000070551d615070551d615070551d6153562035615070551d615070551d615070551d6150705535615070551d6153562035615070551d615070551d615080501d6150805035615080501d6153562035615
011000002a04000000260300000023020000001f01000000230200000026030000002a04000000260300000023020000001f0100000023020000002d030000002a04000000270300000023020000002001000000
0108000023020230200000000000270302703000000000002a0402a040000000000027030270300000000000230202302000000000002d0102d010000000000000000000002b0202b0202b000000000000000000
011000001a6351a6352b733007352d635277331a6352d635007352f635000001a6352f635000001a635007351a6351a6352d733007372d635277331a6352d635000002f635007351a6352f6352b7332873324733
0110000000165001650c16500165001650c16500165001650c16500165001650c16500165001650c1650116502165021650e16502165021650e16502165021650e16502165021650e16502665026650e6651b665
010f00000443021600104300f655286550e4302f65510430256000e4300165510430326550e43032645326350943021675154300265530655134301765515430326550e430104303265500000174303265532655
010f00003275034751347503475034750347503475034750347403474034730347333472334713237131b72300000000001b75300000000001b7730000000000346550c6550c6553465518655186553465528655
010f000000165001650c16500165001650c16500165001650c16500165001650c16500165001650c1650116502165021650e16502165021650e16502165021650e16502165021650e16502665026650e6651b665
010f000013763000001c6551a65513763000001c6551a65513763000001065534640137633461017655156551376328655106551065513763286551c6551a6551376334655346001d65513763246551f6551a655
010f000000000000002f550000002d5502f550000002855000000265502855000000000002b5502f5503455032550325503255032550325503255032550325502d5502d5502d5502d55032550325503255032550
010f00002f5502f5522f5522f5522f5522f5522f5522f5522f5522f5522f5522f5550564505645376150564505645056453761505645056453761535645356453564535645376153564535645376153564535645
010f000004165041651016504165041650e16504165041651016504165041650e1650416504165101650416504165041651016504165041650e16504165041651016504165041650e16504165041650b16509165
010f00000265502655200300e6551e030200302963521030000002003000000200301e03000000200301c6550e6550e655200300c6551e030200303d645210303d600200303d625200301e0303d6151c0303a600
010f00000414004140041400414004140041400414004140041400414004144041400414002144021400214000140001400014000140001400014000140001400014000140001440014000140001440214002140
010f0000000000000020030000001e030200300000021030000002003000000200301e03000000200300000000000000001f030000001e0301f0300000021030000001f030000001f0301e030000001c03000000
0110000000000041600ce75041600ce75041600cf75041651016400100000001012400000000001012400000000000016008e750016008e750016008e75001650c16400000000000c12400000000000c12400000
01100000231302313023130231302313023130231302313023130231302313423130231302113421130211301f1341f1301f1301f1301f1301f1301f1301f1301f1301f1301f1341f1301f130211342113021133
01100000080551d615080551d615080551d6150805535615080551d6153562035615080551d615080551d615080001d6000800035600080001d60035600356000000000000000000000000000000000000000000
000100000a2500a2500c2500e250112501425016250192501c2502025024250282502d250342503d250232502a250312503f250190001b0001d0001f0002200025000270002a0002d00031000310000000000000
00010000216501f6501f6501f6501e6501d6501c6501a6501965017650126500f6500f6500d6500b6500a65008650076500665006650056500560004600036000260002600016000260001600016000060000600
01110000201422010021142231420000028102231221c10200000231221c10200000231121c102000001c1521f152000001f1001f1221f102000001f12200000211021f1121e100150001f1521e152000001e114
01110020156430e6150000000000326251a625006250965309625046250062500600356251a6250062509625156430e6150000000000326251a625006250965309625046250062500600356251a6250062509625
011100002014220100211422314200000281322810028100281240000228100281120000028100281120000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01110000041600ce75041600ce75041600cf750416510164001000015310124001530e1650e1000e165101650016508e7508e0008e750c16508e75001650c1640c100001630c124001630b165001630b16509165
01110000041600ce75041600ce75041600ce75041651016400100000001012400000000001012400000000000016008e750016008e750016008e75001650c16400000000000c12400000000000c1240000000000
010e002a211402114023140211403c0001e1403c00020140201422013200000000003c0001c14023140281402a1402b1412b1402b1402b1402b1302b1322b1322b1322b1222b1222b1222b1122b1102b1102b110
010e00000415004150041500415204152041520415204152041500415004150041500415002150021500215002150001500015000150001520015200152001520015200152001420014200132001220011200112
010a003128642286222862228612286122861234133341000000013773137731377313773000000000000000000002860017773000000e773286550e773286553465234622346123461234612346120000000000
010a000018053000001c0001c0551c0551c0551c0501c0521c0502505023050210502305223052230522305223052230523805036050340502f0502c0502805023050180401c036180261c020180101c01018010
010f00002c5502d5002d5502f55000000345500000028550285502855500000000000000023550285502a5502b550000002d5502a5502a5502a55000000000002a550000002b5502a55000000265502155000000
010f00001a6351a6352b733007352d635277331a6352d635007352f635000001a6352f635000001a635007351a6351a6352d733007372d635277331a6352d635000002f635007351a6352f6352b7332873324733
010f00000417504175101750417504175101750417504175101750417504175101750417504175101750417500175001750c17500175001750c175001750117502175021750e17502175021750e1750c1750b175
010f000021532215322353021532000001e5300000020530205322053220522000001c530000001a53000000155301553215532155250000017530185301c5301a5401a5421a5321a5251e50021540285402a540
010f000004175041751417504175041751417504175041751417504175041751517504175041751717502175001750017518175001750017518175001750b17518175091750917517175001750e175151750b175
010f00001865504175101750265504175101753464234615101753b133001351017504175041750d6750367518655001750c17502655001750c17534642346153c64528645286453c64526635266353c63524635
010f00002c5402d5002d5402f54000000345400000028540285402854500000000000000023540285402a5402b540000002d5402a5422a5422a54200000000002a540000002b5402d540000002f5403254032540
010f0000285402d5002a5402c540101002f540000002354023542235420000000000000002654023540225402154021545235402454000000285402f550000001a540000001c5401e54000000215402654000000
010f0000346453461310050041502d6551377304155041551376304554137630455432645137630415504155137630015513763001502d665137631a6652d665021630216513763021602f665137631c7630c743
010f00003652636520365203652236522365203452034522345223452234522345223452234522345223451300000000000000000000000000000000000000000000000000000000000000000000000000000000
010f000004165041651016504165041650e16504165041651016504165041650e1650416504165101650416504165041651016504165041650e16504165041651016504165041650e16504165041650b16509165
010f000013773000001c665000001377302665000001c6651377302665000001c66513773000001c6652b76313773000001c665000001377302665000001c6651377302665000001c665137732b7631c66510773
__music__
01 05064340
00 064e4b44
01 05060809
02 09060b08
00 0a060b09
01 34353644
00 37383944
00 3a3b3c44
00 3d3e3f44
00 1e1f2044
00 21222355
00 1c201e44
00 1d221f44
00 24256665
00 14151653
00 24251265
02 14111053
00 2324250b
02 26272565
01 2b2f2c44
02 2d2f2c44
00 32313330
01 17184344
02 19285a44
04 070c0d44
04 0f0e4344

