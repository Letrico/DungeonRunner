local utils = require "core.utils"
local explorer = require "core.explorer"
local dungeon_objectives = require "data.dungeons"
local tracker = require "core.tracker"

local start_nmd = true
local objective_index = 1
local current_objective = nil
local prisoner_actor = nil
local kill_count = 0
local boss_room_position = nil
local boss_room_entrance = nil

local ignored_objectives = {}
local interacted_objects_blacklist = {}

local dungeon_state = {
    INIT = "INIT",
    EXPLORE = "EXPLORE",
    COLLECT_MOTE = "COLLECT_MOTE",
    COLLECT_KEY = "COLLECT_KEY",
    UNLOCK_DOOR = "UNLOCK_DOOR",
    KILL_ELITE = "KILL_ELITE",
    KILL_TARGET = "KILL_TARGET",
    DEPOSIT_MOTE = "DEPOSITE_MOTE",
    SAVE_PRISONER = "SAVE_PRISONER",
    WAIT_PRISONER_VFX = "WAIT_PRISONER_VFX",
    MOVE_TO_BOSS_SPHERE = "MOVE_TO_BOSS_SPHERE",
    MOVE_TO_BOSS_ROOM_ENTRANCE = "MOVE_TO_BOSS_ROOM_ENTRANCE",
    MOVE_TO_BOSS_ROOM = "MOVE_TO_BOSS_ROOM",
    KILL_BOSS = "KILL_BOSS",
    FINISHED = "FINISHED",
}

function player_on_quest(quest_id)
    local quests = get_quests()
    for _, quest in pairs(quests) do
        if quest:get_id() == quest_id then
            return true
        end
    end 

    return false
end

function bomb_to(pos)
    explorer:set_custom_target(pos)
    explorer:move_to_target()
end

function is_motejar_door_unlocked()
    local actors = actors_manager:get_ally_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        -- add more door types that needs to deposit animus to unlock
        if name:match("barrierWall_blood") then
            return false
        end
    end
    return true
end

function get_object(name)
    local actors = actors_manager:get_ally_actors()
    for _, actor in pairs(actors) do
        local skin = actor:get_skin_name()
        local actor_id = actor:get_id()
        if skin:match(name) and not interacted_objects_blacklist[actor_id] then
            return actor
        end
    end
    return nil
end

function get_enemy(name)
    local actors = actors_manager:get_enemy_actors()
    for _, actor in pairs(actors) do
        local skin = actor:get_skin_name()
        local health = actor:get_current_health()
        if skin:match(name) and health > 1 then
            return actor
        end
    end
    return nil
end

function get_mote_actor()
    local actors = actors_manager:get_ally_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name:match("DGN_Standard_Mote_") then
            return actor
        end
    end
    return nil
end

function get_motejar_actor()
    local actors = actors_manager:get_ally_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name:match("DGN_Standard_MoteJar_") then
            return actor
        end
    end
    return nil
end

function get_prisoner_actor()
    local actors = actors_manager:get_ally_actors()
    local player_pos = get_player_position()
    local closest_prisoner = nil
    local closest_distance = math.huge

    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if (name:match("DGN_Standard_Global_Human_Stake") or name:match("DGN_Standard_Sitting_Skeleton"))
            and not interacted_objects_blacklist[actor_id] then
            local distance = utils.distance_to(actor:get_position(), player_pos)
            if distance < closest_distance then
                closest_prisoner = actor
                closest_distance = distance
            end
        end
    end

    return closest_prisoner
end

function check_prisoner_vfx(name)
    if name:match("DGN_Standard_Sitting_Skeleton") then
        return true
    end
    return false
end

function get_elite_actor()
    local actors = actors_manager:get_enemy_actors()
    for _, actor in pairs(actors) do
        if actor:is_boss() or actor:is_champion() or actor:is_elite() then
            return actor
        end
    end
    return nil
end

function get_boss_sphere()
    local actors = actors_manager:get_ally_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name:match("DRLG_Generic_Boss_Trigger_Sphere") then
            return actor
        end
    end
    return nil
end

function get_boss_room_entrance()
    local actors = actors_manager:get_ally_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name:match("Trigger_BossRoom_Entrance") then
            console.print(actor:get_skin_name())
            return actor
        end
    end
    return nil
end

local task  = {
    name = "Explore",
    current_state = dungeon_state.INIT,
    zone = nil,
    waiting_vfx = 0,
    failed_attempts = 0,
    max_attempts = 20,
    shouldExecute = function()
        return true
    end,
    Execute = function(self)
        console.print("Current state: " .. tostring(self.current_state))
        console.print("current_objective: " .. tostring(current_objective))

        self.zone = get_current_world():get_current_zone_name()

        if self.current_state == dungeon_state.INIT then
            self:init_dungeon()
        elseif self.current_state == dungeon_state.EXPLORE then
            self:explore_dungeon()
        elseif self.current_state == dungeon_state.COLLECT_MOTE then
            self:collect_mote()
        elseif self.current_state == dungeon_state.COLLECT_KEY then
            self:collect_key()
        elseif self.current_state == dungeon_state.UNLOCK_DOOR then
            self:unlock_door()
        elseif self.current_state == dungeon_state.KILL_ELITE then
            self:kill_elite()
        elseif self.current_state == dungeon_state.KILL_TARGET then
            self:kill_target()
        elseif self.current_state == dungeon_state.DEPOSIT_MOTE then
            self:deposit_mote()
        elseif self.current_state == dungeon_state.SAVE_PRISONER then
            self:save_prisoner()
        elseif self.current_state == dungeon_state.WAIT_PRISONER_VFX then
            self:wait_prisoner_vfx()
        elseif self.current_state == dungeon_state.MOVE_TO_BOSS_SPHERE then
            self:move_to_boss_sphere()
        elseif self.current_state == dungeon_state.MOVE_TO_BOSS_ROOM_ENTRANCE then
            self:move_to_boss_room_entrance()
        elseif self.current_state == dungeon_state.MOVE_TO_BOSS_ROOM then
            self:move_to_boss_room()
        elseif self.current_state == dungeon_state.KILL_BOSS then
            self:kill_boss()
        elseif self.current_state == dungeon_state.FINISHED then
            self:finished()
        end
    end,
    
    init_dungeon = function(self)
        current_objective = dungeon_objectives[self.zone].objectives[objective_index]
        tracker.blocker[dungeon_objectives[self.zone].blocker.name] = true
        console.print("current_objective: " .. tostring(current_objective))
        if dungeon_objectives[self.zone].explorer and dungeon_objectives[self.zone].explorer.max_target_distance then
            local max_target_distance = dungeon_objectives[self.zone].explorer.max_target_distance
            local target_distance_states = dungeon_objectives[self.zone].explorer.target_distance_states
            local check_radius = dungeon_objectives[self.zone].explorer.check_radius
            local exploration_radius = dungeon_objectives[self.zone].explorer.exploration_radius
            if max_target_distance and target_distance_states and check_radius and exploration_radius then 
                explorer:set_target_distance(max_target_distance, target_distance_states, check_radius, exploration_radius)
            end
        end
        
        self.current_state = dungeon_state.EXPLORE
    end,

    explore_dungeon = function(self)
        if not player_on_quest(dungeon_objectives[self.zone].quest_id) then
            self.current_state = dungeon_state.FINISHED
            return
        end

        if current_objective == "animus" then
            if get_mote_actor() then
                explorer:clear_path_and_target()
                self.current_state = dungeon_state.COLLECT_MOTE
                return
            elseif get_motejar_actor() and utils.distance_to(get_motejar_actor()) < 15 then
                explorer:clear_path_and_target()
                self.current_state = dungeon_state.DEPOSIT_MOTE
                return
            elseif get_elite_actor() and utils.distance_to(get_elite_actor()) < 10 then
                explorer:clear_path_and_target()
                self.current_state = dungeon_state.KILL_ELITE
                return
            end
        elseif current_objective:match("prisoners") then
            if current_objective:match("key") then
                local key = get_object(dungeon_objectives[self.zone][current_objective].name)
                if key then
                    explorer:clear_path_and_target()
                    self.current_state = dungeon_state.COLLECT_KEY
                    return
                end
            end
            local prisoner = get_prisoner_actor()
            prisoner_actor = prisoner
            if prisoner then
                local prisoner_id = prisoner:get_id()
                if not ignored_objectives[prisoner_id] then
                    explorer:clear_path_and_target()
                    self.current_state = dungeon_state.SAVE_PRISONER
                    return
                end
            end
        elseif current_objective:match("key") then
            key = get_object(dungeon_objectives[self.zone][current_objective].name)
            console.print(dungeon_objectives[self.zone][current_objective].name)
            if get_object(key) then
                explorer:clear_path_and_target()
                self.current_state = dungeon_state.COLLECT_KEY
                return
            end
        elseif current_objective == "unlock_door" then
            local door = get_object(dungeon_objectives[self.zone][current_objective].name)
            if door then
                explorer:clear_path_and_target()
                self.current_state = dungeon_state.UNLOCK_DOOR
                return
            end
        elseif current_objective:match("kill") then
            target_name = dungeon_objectives[self.zone][current_objective].name
            local count = dungeon_objectives[self.zone][current_objective].count
            console.print("count: " .. tostring(count))
            console.print("kill_count: " .. tostring(kill_count))
            if kill_count == count then
                objective_index = objective_index + 1
                kill_count = 0
                current_objective = dungeon_objectives[self.zone].objectives[objective_index]
                return
            end
            if get_enemy(target_name) then
                explorer:clear_path_and_target()
                self.current_state = dungeon_state.KILL_TARGET
                return
            end
        elseif current_objective == "boss_sphere" then
            target_name = dungeon_objectives[self.zone][current_objective].name
            if get_boss_sphere() then
                explorer:clear_path_and_target()
                self.current_state = dungeon_state.MOVE_TO_BOSS_SPHERE
                return
            end
        elseif current_objective == "boss_room" then
            target_name = dungeon_objectives[self.zone].boss.name
            if get_boss_room_entrance() then
                explorer:clear_path_and_target()
                self.current_state = dungeon_state.MOVE_TO_BOSS_ROOM_ENTRANCE
                return
            end
        end
        -- open_doors()
        explorer:move_to_target()
    end,

    collect_mote = function(self)
        local mote = get_mote_actor()
        if mote then
            if utils.distance_to(mote) > 2 then
                console.print("Found mote! Going to mote")
                bomb_to(mote:get_position())
                return
            end
        else
            self.current_state = dungeon_state.EXPLORE
        end
    end,

    collect_key = function(self)
        local actor = get_object(dungeon_objectives[self.zone][current_objective].name)
        if actor then
            if utils.distance_to(actor) > 2 then
                console.print("Found key! Going to key")
                bomb_to(actor:get_position())
                return
            else
                local success = loot_manager.loot_item(actor, true, true)
                if success then
                    key = nil
                    return
                end
            end
        else
            objective_index = objective_index + 1
            current_objective = dungeon_objectives[self.zone].objectives[objective_index]
            self.current_state = dungeon_state.EXPLORE
        end
    end,

    unlock_door = function(self)
        local actor = get_object(dungeon_objectives[self.zone][current_objective].name)
        if actor then
            local actor_id = actor:get_id()
            if utils.distance_to(actor) > 2 then
                console.print("Found door! Going to door")
                bomb_to(actor:get_position())
                return
            else
                interact_object(actor)
                tracker.blocker[dungeon_objectives[self.zone].blocker.name] = false
                interacted_objects_blacklist[actor_id] = true
            end
        else
            objective_index = objective_index + 1
            current_objective = dungeon_objectives[self.zone].objectives[objective_index]
            self.current_state = dungeon_state.EXPLORE
        end
    end,

    kill_elite = function(self)
        local elite = get_elite_actor()
        if elite then
            if utils.distance_to(elite) > 2 then
                console.print("Found elite monster! Going to monster")
                bomb_to(elite:get_position())
                return
            end
        else
            self.current_state = dungeon_state.EXPLORE
        end
    end,

    kill_target = function(self)
        local target = get_enemy(target_name)
        if target then
            if utils.distance_to(target) > 2 then
                console.print("Found target monster! Going to target!")
                bomb_to(target:get_position())
                return
            end
        else
            kill_count = kill_count + 1
            self.current_state = dungeon_state.EXPLORE
        end
    end,

    deposit_mote = function(self)
        local motejar = get_motejar_actor()
        if motejar and not is_motejar_door_unlocked() then
            if utils.distance_to(motejar) > 2 then
                console.print("Found morejar! Going to motejar")
                bomb_to(motejar:get_position())
                return
            else
                interact_object(motejar)
            end
        else
            -- check start point actor maybe?
            objective_index = objective_index + 1
            current_objective = dungeon_objectives[self.zone].objectives[objective_index]
            self.current_state = dungeon_state.EXPLORE
        end 
    end,

    save_prisoner = function(self)
        local prisoner = prisoner_actor
        if prisoner then
            if utils.distance_to(prisoner) > 2 then
                console.print("Found prisoner! Going to prisoner")
                bomb_to(prisoner:get_position())
                return
            else
                local name = prisoner:get_skin_name()
                local position = prisoner:get_position()
                interact_object(prisoner)
                if check_prisoner_vfx(name) then
                    self.current_state = dungeon_state.WAIT_PRISONER_VFX
                else 
                    prisoner_actor = nil
                end
                return
            end
        else
            self.current_state = dungeon_state.EXPLORE
        end
    end,

    wait_prisoner_vfx = function(self)
        local prisoner = prisoner_actor
        local prisoner_name = prisoner:get_skin_name()
        local prisoner_position = prisoner:get_position()
        local prisoner_id = prisoner:get_id()
        local actors = actors_manager:get_all_particles()
        for _, actor in pairs(actors) do
            local name = actor:get_skin_name()
            if name == "fxkit_harmless_burstAttractor_spirits_parent" then
                ignored_objectives[prisoner_id] = true
                self.failed_attempts = 0
                prisoner_actor = nil
                self.current_state = dungeon_state.EXPLORE
            end
        end

        console.print("No visual effects found, save prisoner may failed")
        self.failed_attempts = self.failed_attempts + 1
        console.print("failed_attempts: " .. tostring(self.failed_attempts))
        if self.failed_attempts >= self.max_attempts then
            ignored_objectives[prisoner_id] = true
            self.failed_attempts = 0
            prisoner_actor = nil
            self.current_state = dungeon_state.EXPLORE
            return
        else
            interact_object(prisoner)
        end
    end,

    move_to_boss_sphere = function(self)
        local boss_sphere = get_boss_sphere()
        if boss_sphere then
            if utils.distance_to(boss_sphere) > 2 then
                bomb_to(boss_sphere:get_position())
                return
            end
        else
            self.current_state = dungeon_state.KILL_BOSS
        end
    end,

    move_to_boss_room_entrance = function(self)
        boss_room_entrance = get_boss_room_entrance()
        if boss_room_entrance then
            if utils.distance_to(boss_room_entrance) > 2 then
                bomb_to(boss_room_entrance:get_position())
                return
            else
                self.current_state = dungeon_state.MOVE_TO_BOSS_ROOM
            end
        end
    end,

    move_to_boss_room = function(self)
        if boss_room_entrance then
            local move_position = dungeon_objectives[self.zone].boss_room_direction
            local new_vector = vec3:new(move_position.x, move_position.y, move_position.z)
            local boss_room_position = boss_room_entrance:get_position() + new_vector
            if utils.distance_to(boss_room_position) > 2 then
                bomb_to(boss_room_position)
                return
            else
                self.current_state = dungeon_state.KILL_BOSS
            end
        end
    end,

    kill_boss = function(self)
        console.print("kill boss")
        local target = get_enemy(target_name)
        if target then
            if utils.distance_to(target) > 2 then
                console.print("Found boss! Going to boss!")
                bomb_to(target:get_position())
                return
            end
        else
            if boss_room_entrance then
                boss_room_entrance = nil
            end
            self.current_state = dungeon_state.FINISHED
        end
    end,

    finished = function(self)
        console.print("Dungeon finished")
        -- Do something? Not sure yet
    end
}

return task      