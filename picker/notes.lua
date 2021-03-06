-------------------------------------------------------------------------------
--[[StickyNotes
---------------------------------------------------------------------------------
MIT License

Copyright (c) 2017 NiftyManiac

# factorio-stickynotes
StickyNotes mod for Factorio, originally by BinbinHfr before I took over.
See [the forums](https://forums.factorio.com/viewtopic.php?f=92&t=30980&p=195631) for more details.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. ]]

local Player = require("stdlib.event.player")

local text_color_default = {r=1,g=1,b=0}
local color_array = {}
for _, v in pairs(defines.color) do
    table.insert(color_array,v)
end

local max_chars = 4*(settings.startup["picker-notes-slot-count"].value-1)-1 -- max length of storable string
local color_picker_interface = "color-picker"
local open_color_picker_button_name = "open_color_picker_stknt"
local color_picker_name = "color_picker_stknt"

local function num(var)
    return var and 1 or 0
end

local function bool(numb)
    return (numb ~= 0 and true) or false
end

--------------------------------------------------------------------------------------
local function menu_note( player, pdata, open_or_close )
    if open_or_close == nil then
        open_or_close = (player.gui.left.flow_stknt == nil)
    end

    if player.gui.left.flow_stknt then
        player.gui.left.flow_stknt.destroy()
    end

    if open_or_close then
        local flow, frame, color_button
        local note = pdata.note_sel

        if note then
            flow = player.gui.left.add{type = "flow", name = "flow_stknt", style = "achievements_flow_style", direction = "horizontal"}
            frame = flow.add{type = "frame", name = "frm_stknt", caption = {"notes-gui.title", note.n}, style = "frame_stknt_style", direction = "vertical"}

            local table_main = frame.add{type = "table", name = "tab_stknt_main", colspan = 1, style = "picker_table"}
            table_main.add{type = "text-box", name = "txt_stknt", text = note.text, style = "textbox_stknt_style", word_wrap = true}

            if not settings.global["picker-notes-use-color-picker"].value then
                local table_colors = table_main.add{type = "table", name = "tab_stknt_colors", style = "picker_table", colspan = 10}
                for name, color in pairs(defines.color) do
                    color_button = table_colors.add{type = "button", name = "but_stknt_col_" .. name, caption = "@", style = "button_stknt_style"}
                    color_button.style.font_color = color
                end
            end

            local table_checks = table_main.add{type = "table", name = "tab_stknt_check", colspan = 2, style = "picker_table"}
            table_checks.add{
                type = "checkbox",
                name = "chk_stknt_autoshow",
                caption = {"notes-gui.autoshow"},
                state = note.autoshow,
                tooltip = {"notes-gui-tt.autoshow"},
                style = "checkbox_stknt_style"
            }
            table_checks.add{
                type = "checkbox",
                name = "chk_stknt_mapmark",
                caption = {"notes-gui.mapmark"},
                state = (note.mapmark ~= nil),
                tooltip = {"notes-gui-tt.mapmark"},
                style = "checkbox_stknt_style"
            }
            table_checks.add{
                type = "checkbox",
                name = "chk_stknt_locked_force",
                caption = {"notes-gui.locked-force"},
                state = note.locked_force,
                tooltip = {"notes-gui-tt.locked-force"},
                style = "checkbox_stknt_style"}
            if player.admin then
                table_checks.add{
                    type = "checkbox",
                    name = "chk_stknt_locked_admin",
                    caption = {"notes-gui.locked-admin"},
                    state = note.locked_admin,
                    tooltip = {"notes-gui-tt.locked-admin"},
                    style = "checkbox_stknt_style"
                }
            end

            local table_but = table_main.add{type = "table", name = "tab_stknt_but", colspan = 6, style = "picker_table"}
            table_but.add{
                type = "button",
                name = "but_stknt_delete",
                caption = {"notes-gui.delete"},
                tooltip = {"notes-gui-tt.delete"},
                style = "button_stknt_style"
            }
            table_but.add{
                type = "button",
                name = "but_stknt_close",
                caption = {"notes-gui.close"},
                tooltip = {"notes-gui-tt.close"},
                style = "button_stknt_style"
            }
            if settings.global["picker-notes-use-color-picker"].value and remote.interfaces[color_picker_interface] then
                -- use Color Picker mod if possible.
                table_but.add{
                    type = "button",
                    name = open_color_picker_button_name,
                    caption = {"gui-train.color"},
                    style = "button_stknt_style"
                }
            end
        end
    end
end

--------------------------------------------------------------------------------------
local function display_mapmark( note, on_or_off )
    if note then
        if note.mapmark and note.mapmark.valid then
            note.mapmark.destroy()
        end
        note.mapmark = nil

        if on_or_off and note.invis_note and note.invis_note.valid then
            local tag = {
                icon = {type = "item", name = "sticky-note"},
                position = note.invis_note.position,
                text = note.text,
                last_user = note.last_user,
                target = note.invis_note
            }
            note.mapmark = note.invis_note.force.add_chart_tag(note.invis_note.surface, tag)
        end
    end
end

local function create_invis_note( entity )
    local surf = entity.surface
    local invis_note = surf.create_entity(
        {
            name = "invis-note",
            position = entity.position,
            direction = entity.direction,
            force = entity.force
        })
    invis_note.destructible = false
    invis_note.operable = false
    return invis_note
end

--------------------------------------------------------------------------------------
-- store the note data into an existing invis-note
local function encode_note( note )
    local encoding_version = 1
    local invis_note = note.invis_note

    if invis_note then
        -- metadata bytes (big endian): <encoding version>, <reserved>, <flags>, <color index>
        local metadata = 0
        metadata = bit32.replace(metadata, encoding_version, 24, 8)

        metadata = bit32.replace(metadata, num(note.autoshow), 8)
        metadata = bit32.replace(metadata, num(note.mapmark ~= nil), 9)
        metadata = bit32.replace(metadata, num(note.locked_force), 10)
        metadata = bit32.replace(metadata, num(note.locked_admin), 11)

        local color = note.color
        local color_index
        for i, v in pairs(color_array) do
            if color.r == v.r and color.g == v.g and color.b == v.b then
                color_index = i
                break
            end
        end
        if color_index == nil or color_index>255 then
            return
        end
        metadata = bit32.replace(metadata, color_index, 0, 8)

        -- array of encoded values to store in the invis-note
        local signal_vals = {}
        for i = 1, settings.startup["picker-notes-slot-count"].value do
            signal_vals[i] = -2 ^ 31
        end

        signal_vals[1] = signal_vals[1] + metadata

        for i = 1,#note.text+1 do
            local signal_i = math.floor((i-1)/4)
            local shift = (i-1)%4 * 8
            local val
            if i == #note.text+1 then
                val = 0 -- string termination
            else
                val = string.byte(note.text,i)
            end
            signal_vals[signal_i+2] = signal_vals[signal_i+2] + val * 2 ^ shift
        end
        if #signal_vals > settings.startup["picker-notes-slot-count"].value then
            return
        end

        local params = {}
        for i, v in pairs(signal_vals) do
            table.insert(params,
                {
                    signal =
                    {
                        type = "virtual",
                        name = "signal-0"
                    },
                    count = v,
                    index = i
                }
            )
        end

        -- assign encoded values to invis_note
        invis_note.get_or_create_control_behavior().parameters = {parameters = params};
    end
end

--------------------------------------------------------------------------------------
-- decode an invis_note and return a note object. Also, create a mapmark if needed.
-- returns nil if decode failed
-- encoding versions changes:
-- 2.0.0: 0
-- 2.0.1: 1
local function decode_note( invis_note, target )
    local note = {}
    note.invis_note = invis_note
    note.target = target
    note.target_unit_number = target.unit_number -- needed in case target becomes invalid

    local params = invis_note.get_or_create_control_behavior().parameters.parameters
    local metadata = params[1].count + 2^31

    local version = bit32.extract(metadata, 24, 8)

    local terminator = 0
    if version==0 then
        terminator = 3
    end

    if version==0 or version==1 then
        note.autoshow = bool(bit32.extract(metadata, 8))
        local show_mapmark = bool(bit32.extract(metadata, 9))
        note.locked_force = bool(bit32.extract(metadata, 10))
        note.locked_admin = bool(bit32.extract(metadata, 11))

        local color_i = bit32.extract(metadata, 0, 8)
        note.color = color_array[color_i]

        note.text = ""
        for i = 1, (settings.startup["picker-notes-slot-count"].value-1)*4 do
            local signal_i = math.floor((i-1)/4)
            local shift = (i-1)%4 * 8

            local byte = bit32.extract(params[signal_i+2].count+2^31, shift, 8)
            if byte == terminator then
                break
            end
            note.text = note.text .. string.char(byte)
        end

        display_mapmark(note, show_mapmark)

    else
        game.print("StickyNotes failed to decode a note, as it was made with a newer version of the mod. Please install the newest version of StickyNotes and try again.")
        return
    end
    return note
end

--------------------------------------------------------------------------------------
local function show_note( note )
    if note then
        if note.fly and note.fly.valid then
            note.fly.active = note.autoshow or false
            return
        end

        if note.invis_note and note.invis_note.valid then
            local pos = note.invis_note.position
            local surf = note.invis_note.surface
            local x = pos.x-1
            local y = pos.y

            local fly = surf.create_entity({name="sticky-text", text=note.text, color=note.color, position={x=x,y=y}})
            if fly then
                note.fly = fly
                note.fly.active = note.autoshow or false
            end
        end
    end
end

--------------------------------------------------------------------------------------
local function hide_note( note )
    if note then
        if note.fly and note.fly.valid then
            note.fly.destroy()
        end
        note.fly = nil
    end
end

--------------------------------------------------------------------------------------
local function destroy_note( note )
    for _, player in pairs(game.connected_players) do
        local pdata = global.players[player.index]

        if pdata.note_sel == note then
            menu_note(player, pdata, false)
            pdata.note_sel = nil
        end
    end

    hide_note(note)

    if note.mapmark and note.mapmark.valid then
        note.mapmark.destroy()
    end
    note.mapmark = nil

    global.notes_by_invis[note.invis_note.unit_number] = nil
    global.notes_by_target[note.target_unit_number] = nil

    if note.invis_note and note.invis_note.valid then
        note.invis_note.destroy()
    end
end

--------------------------------------------------------------------------------------
-- lookup the note of an invis-note or a target entity
local function get_note( ent )
    if ent.name == "invis-note" then
        return global.notes_by_invis[ent.unit_number]
    end
    return global.notes_by_target[ent.unit_number]
end

local function on_selected_entity_changed(event)
    local player = game.players[event.player_index]
    if player.selected then
        return show_note(get_note(player.selected))
    end
end
Event.register(defines.events.on_selected_entity_changed, on_selected_entity_changed)

--------------------------------------------------------------------------------------
local function register_note( note )
    global.n_note = global.n_note + 1
    note.n = global.n_note;
    global.notes_by_target[note.target.unit_number] = note
    global.notes_by_invis[note.invis_note.unit_number] = note
end
--------------------------------------------------------------------------------------

local function update_note_target(note, new_target)
    if note.target then
        global.notes_by_target[note.target_unit_number] = nil
    end
    note.target = new_target
    note.target_unit_number = new_target.unit_number
    global.notes_by_target[new_target.unit_number] = note
end

--------------------------------------------------------------------------------------
local function add_note( entity )

    local note =
    {
        text = "text " .. global.n_note+1, -- text
        color = text_color_default, -- color
        n = nil, -- number of the note
        fly = nil, -- text entity
        autoshow = settings.global["picker-notes-default-autoshow"].value, -- if true, then note autoshows/hides
        mapmark = nil, -- mark on the map
        locked_force = true, -- only modifiable by the same force
        locked_admin = false, -- only modifiable by admins
        editer = nil, -- player currently editing
        is_sign = (entity.name == "sticky-note" or entity.name == "sticky-sign"), -- is connected to a real note/sign object
        invis_note = create_invis_note(entity),
        target = entity,
        target_unit_number = entity.unit_number -- needed in case target becomes invalid
    }

    note.text = #settings.global["picker-notes-default-message"].value > 1 and settings.global["picker-notes-default-message"].value or note.text
    show_note(note)
    register_note(note)
    display_mapmark(note, settings.global["picker-notes-default-mapmark"].value)
    encode_note(note)

    return(note)
end

local function entity_moved(event)
    local ent = event.moved_entity and event.moved_entity.valid and event.moved_entity
    if ent then
        local note = get_note(ent)
        if note then
            note.invis_note.teleport(ent.position)
            if note.fly then
                hide_note(note)
                show_note(note)
            end
        end
    end
end
Event.register(Event.dolly_moved, entity_moved)

-- !!fix sign behaviors
local function on_creation( event )
    local ent = event.created_entity

    if not ent.valid then return end

    -- revive note ghosts immediately
    if ent.name == "entity-ghost" and ent.ghost_name == "invis-note" then
        local revived, rev_ent = ent.revive()
        if revived then
            --debug_print("Revived invis-note")
            ent = rev_ent
        end
    end

    if ent.name == "invis-note" then
        ent.destructible = false;
        ent.operable = false;

        -- only place an invis-note on a ghost, if that ghost doesn't already have a note
        local note_target

        -- With instant blueprint, the entity revive order is different between different entities. It is known that oil-refinery > invis-note > chest.
        -- In case the target has not been revived yet, e.g. no instant blueprint, or chest with instant blueprint.
        local note_targets = ent.surface.find_entities_filtered{name = "entity-ghost", position = ent.position, force = ent.force, limit = 1}
        if #note_targets > 0 then
            local target = note_targets[1]
            if target.valid and get_note(target) == nil then
                note_target = target
            end
        end
        -- In case the target has already been revived, e.g. oil-refinery with instant blueprint.
        if not note_target then
            note_targets = ent.surface.find_entities_filtered{position = ent.position, force = ent.force}
            for _, target in pairs(note_targets) do
                --debug_print("target"..target.name)
                if target.prototype.has_flag("player-creation") then
                    if target.valid and get_note(target) == nil then
                        note_target = target
                    end
                    break
                end
            end
        end

        if note_target then
            local note = decode_note(ent, note_target)
            if note then
                note.invis_note.teleport(note.target.position) -- align the note to avoid adding up error
                register_note(note)
                show_note(note)
                display_mapmark(note, note.mapmark)
            else
                -- we could keep around the invis-note in case they install a newer version that makes it readable
                -- but then we'd have to keep track of the invis-notes on the map, instead of just decoding on creation
                ent.destroy()
            end
        else
            ent.destroy()
        end

    elseif ent.name ~= "entity-ghost" then -- when a normal item is placed figure out what ghosts are destroyed
        if (ent.name == "sticky-note" or ent.name == "sticky-sign") then
            ent.destructible = false
            ent.operable = false
        end

        local x = ent.position.x
        local y = ent.position.y
        local invis_notes = ent.surface.find_entities_filtered{name="invis-note",area={{x-10,y-10},{x+10, y+10}}}
        for _,invis_note in pairs(invis_notes) do
            local note = get_note(invis_note)
            if not note.target.valid then -- if we deleted a ghost with this placement
                if math.abs(invis_note.position.x-x)<0.01 and math.abs(invis_note.position.y-y)<0.01 then -- if we replaced a correct ghost, reassign
                    update_note_target(note, ent)
                else -- we destroyed an unrelated ghost
                    destroy_note(note)
                end
            end
        end
    end
end
Event.register({defines.events.on_built_entity, defines.events.on_robot_built_entity}, on_creation )

--------------------------------------------------------------------------------------
local function on_destruction( event )
    local ent = event.entity
    local note = get_note(ent)
    if note then
        destroy_note(note)
    end
end
Event.register({defines.events.on_entity_died, defines.events.on_robot_pre_mined, defines.events.on_preplayer_mined_item}, on_destruction)

--------------------------------------------------------------------------------------
local function on_marked_for_deconstruction( event )
    local ent = event.entity
    if ent.name == "invis-note" then
        local note = get_note(ent)
        if not note.target.valid or note.target.name == "entity-ghost" then
            destroy_note(note)
        else -- if target is still valid, just cancel deconstruction
            local force = (event.player_index and game.players[event.player_index].force) or (ent.last_user and ent.last_user.force) or ent.force
            ent.cancel_deconstruction(force)
        end
    end
end
Event.register(defines.events.on_marked_for_deconstruction, on_marked_for_deconstruction)

-------------------------------------------------------------------------------
--[[GUI]]--
-------------------------------------------------------------------------------
local function on_gui_text_changed(event)
    local player, pdata = Player.get(event.player_index)
        local note = pdata.note_sel

        if note then
            if #event.element.text > max_chars then
                event.element.text = string.sub(event.element.text, 1, max_chars)
                player.print("StickyNotes: Notes are limited to "..max_chars.." in length. To raise this limit, change the setting")
            end

            note.text = event.element.text
            encode_note(note)

            hide_note(note)
            show_note(note)
            if note.mapmark then
                display_mapmark(note, true)
            end
        end
end
Gui.on_text_changed("^txt_stknt$", on_gui_text_changed)

Gui.on_click("but_stknt_close",
    function(event)
        local player, pdata = Player.get(event.player_index)
        local note = pdata.note_sel
        if note then
            note.editer = nil
        end
        menu_note(player, pdata, false)
        pdata.note_sel = nil
    end
)

Gui.on_click("but_stknt_delete",
    function(event)
        local player, pdata = Player.get(event.player_index)
        local note = pdata.note_sel

        if note then
            destroy_note(note)
            menu_note(player, pdata, false)
            pdata.note_sel = nil
        end
    end
)
Gui.on_click("but_stknt_col_(.*)",
    function(event)
        local _, pdata = Player.get(event.player_index)

        local note = pdata.note_sel
        local color = defines.color[event.match]

        if color and note then
            note.color = color
            encode_note(note)
            hide_note(note)
            show_note(note)
        end
    end
)

Gui.on_click("chk_stknt_autoshow",
    function(event)
        local _, pdata = Player.get(event.player_index)
        local note = pdata.note_sel
        if note then
            note.autoshow = event.element.state
            encode_note(note)
            if note.autoshow then
                hide_note(note)
            else
                show_note(note)
            end
        end
    end
)

Gui.on_click("chk_stknt_mapmark",
    function(event)
        local _, pdata = Player.get(event.player_index)
        local note = pdata.note_sel
        if note then
            if event.element.state then
                display_mapmark(note,true)
            else
                display_mapmark(note,false)
            end
        end
        encode_note(note)
    end
)

Gui.on_click("chk_stknt_locked_force",
    function(event)
        local _, pdata = Player.get(event.player_index)
        local note = pdata.note_sel
        note.locked_force = event.element.state
        encode_note(note)
    end
)

Gui.on_click("chk_stknt_locked_admin",
    function(event)
        local player, pdata = Player.get(event.player_index)
        if player.admin then
            local note = pdata.note_sel
            note.locked_admin = event.element.state
            encode_note(note)
            if note.is_sign then
                if note.locked_admin then
                    note.target.minable = false
                else
                    note.target.minable = true
                end
            end
        end
    end
)

Gui.on_click(open_color_picker_button_name,
    function(event)
        local player, pdata = Player.get(event.player_index)
        -- open color picker.
        local flow = player.gui.left.flow_stknt
        if flow then
            if flow[color_picker_name] then
                flow[color_picker_name].destroy()
            else
                remote.call(color_picker_interface, "add_instance",
                    {
                        parent = flow,
                        container_name = color_picker_name,
                        color = pdata.note_sel and pdata.note_sel.color,
                        show_ok_button = true,
                    }
                )
            end
        end
    end
)

-------------------------------------------------------------------------------
--[[Hotkey]]--
-------------------------------------------------------------------------------
local types = {
    ["car"] = true,
    ["tank"] = true,
    ["player"] = true,
    ["unit"] = true,
    ["unit-spawner"] = true,
    ["straight-rail"] = true,
    ["curved-rail"] = true,
    ["locomotive"] = true,
    ["cargo-wagon"] = true,
    ["fluid-wagon"] = true,
    ["logistic-robot"] = true,
    ["construction-robot"] = true,
    ["combat-robot"] = true,
}
local function on_hotkey_write(event)
    local player, pdata = Player.get(event.player_index)
    local selected = player.selected
    local note = nil

    if selected and player.force.technologies["sticky-notes"].researched then
        note = get_note(selected)

        if note == nil and player.force == selected.force then
            -- add a new note
            local type = selected.type

            -- do not add a text on movable objects or rails.
            if not types[type] then
                note = add_note(selected)
            end
        end
    end

    local previous = pdata.note_sel

    if previous ~= note then
        -- hide the previous menu
        if previous then
            previous.editer = nil
            menu_note(player, pdata, false)
            pdata.note_sel = nil
        end

        -- show the new menu
        if note and (note.editer == nil or not note.editer.connected) and (note.invis_note.force == player.force or not note.locked_force) and (player.admin or not note.locked_admin) then
            pdata.note_sel = note
            note.editer = player
            menu_note(player, pdata, true)
        end
    end
end
Event.register("picker-notes", on_hotkey_write)

-------------------------------------------------------------------------------
--[[Init]]--
-------------------------------------------------------------------------------
local function register_conditionals()
    if remote.interfaces[color_picker_interface] then
        -- color picker events.
        Event.register(remote.call(color_picker_interface, "on_color_updated"),
            function(event)
                if event.container.name == color_picker_name then
                    local _, pdata = Player.get(event.player_index)
                    local note = pdata.note_sel
                    local color = event.color

                    if color and note then
                        note.color = color
                        hide_note(note)
                        show_note(note)
                    end
                end
            end
        )

        Event.register(remote.call(color_picker_interface, "on_ok_button_clicked"),
            function(event)
                if event.container.name == color_picker_name then
                    event.container.destroy()
                end
            end
        )
    end
end

local function on_load()
    register_conditionals()
end
Event.register(Event.core_events.load, on_load)

local function on_init()
    global.notes_by_invis = {}
    global.notes_by_target = {}
    global.n_note = 0
    register_conditionals()
end
Event.register(Event.core_events.init, on_init)

local function on_configuration_changed(event)
    if event.mod_changes and event.mod_changes["PickerExtended"] then
        global.notes_by_invis = global.notes_by_invis or {}
        global.notes_by_invis = global.notes_by_invis or {}
        global.notes_by_target = global.notes_by_target or {}
        global.n_note = global.n_note or 0
    end
end
Event.register(Event.core_events.configuration_changed, on_configuration_changed)

-------------------------------------------------------------------------------
--[[Interface]]--
-------------------------------------------------------------------------------
local interfaces = {}
function interfaces.delete_all()
    table.each(global.notes_by_invis, destroy_note)
    table.each(global.notes_by_target, destroy_note)
end

function interfaces.count(silent)
    local invis = table.count_keys(global.notes_by_invis)
    local target = table.count_keys(global.notes_by_target)
    if not silent then
        game.print("Total Notes: "..invis+target .." Notes by invis-notes: "..invis.." Notes by targets: "..target)
    end
    return invis+target, invis, target
end

-- destroy any remaining notes without targets or invis-notes
-- also, make sure notes are aligned with their targets
function interfaces.clean()
    local destroy_count = 0
    local align_count = 0

    local function fix_note(note)
        if not note.invis_note.valid or not note.target.valid then
            destroy_note(note)
            destroy_count = destroy_count+1
        elseif note.invis_note.position.x ~= note.target.position.x or note.invis_note.position.y ~= note.target.position.y then
            note.invis_note.teleport(note.target.position)
            hide_note(note)
            show_note(note)
            align_count = align_count+1;
        end
    end

    table.each(global.notes_by_invis, fix_note)
    table.each(global.notes_by_target, fix_note)

    game.print("Cleaned out "..destroy_count.." notes")
    game.print("Aligned "..align_count.." notes")
end

function interfaces.add_note(entity,parameters)
    add_note(entity)
    interfaces.modify_note( entity, parameters)
end

function interfaces.remove_note(entity)
    local note = get_note(entity)
    if note then destroy_note(note) end
end

local isset = function(val)
    return val and true or val==false
end
local writable_fields={--[fieldname]=function(value,note), functions should perform check of the passed values and transformations as needed
    text = function(note,t)
        note.text=t and tostring(t):sub(1, max_chars)
    end, -- text

    color = function(note,color_name)
        note.color = defines.color[color_name] or note.color
    end, -- color

    autoshow = function(note, boolean)
        note.autoshow = boolean
    end, -- if true, then note autoshows/hides

    mapmark = function(note, boolean)
        display_mapmark(note,boolean)
    end, -- mark on the map

    locked_force = function(note, boolean)
        note.locked_force = boolean
    end, -- only modifiable by the same force

    locked_admin = function(note, boolean)
        if note.is_sign then
            if boolean then
                note.target.minable = false
            else
                note.target.minable = true
            end
        end
    end, -- only modifiable by admins
}

function interfaces.modify_note(entity,par)
    local note = get_note(entity)
    if not note then return end
    for k,v in pairs(writable_fields) do
        if isset(par[k]) then v(note,par[k]) end
    end

    encode_note(note)
    hide_note(note)
    show_note(note)
    if note.mapmark then
        display_mapmark(note,true)
    end
end

--Add to picker and StickyNotes interface
for name, func in pairs(interfaces) do
    MOD.interfaces[name] = func
end
if not remote.interfaces["StickyNotes"] then remote.add_interface("StickyNotes", interfaces) end
