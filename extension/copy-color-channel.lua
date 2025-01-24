--[[
MIT LICENSE
Copyright © 2024 John Riggles [sudo_whoami]

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

-- stop complaining about unknown Aseprite API methods
---@diagnostic disable: undefined-global
-- ignore dialogs which are defined with local names for readablity, but may be unused
---@diagnostic disable: unused-local

local preferences = {} -- create a global table to store extension preferences

local function checkActiveElements()
  if not app.sprite then
    app.alert("No active image. Please open an image or create a new one.")
    return false
  elseif not app.layer then
    app.alert("No selected layer!")
    return false
  elseif not app.cel then
    app.alert("No selected cel!")
    return false
  elseif not app.cel.image.colorMode == ColorMode.RGB then
    app.alert("This script only works in RGB Color Mode!")
    return false
  end
  return true -- all checks passed
end

app.transaction(
  "copy color channel",
  function ()
    function CopyColor(channel, keepAlpha)
      local cel = app.cel
      local celCopy = cel.image:clone()
      app.command.duplicateLayer(cel.layer)
      local layer = cel.layer
      local layerName = layer.name
      layer.isVisible = true

      local channelColors = {
        ["Red"] =     { r = 1, g = 0, b = 0 },
        ["Green"] =   { r = 0, g = 1, b = 0 },
        ["Blue"] =    { r = 0, g = 0, b = 1 },
        ["Cyan"] =    { r = 0, g = 1, b = 1 },
        ["Magenta"] = { r = 1, g = 0, b = 1 },
        ["Yellow"] =  { r = 1, g = 1, b = 0 }
      }

      local chR = channelColors[channel].r --user selected multiplier for red channel
      local chG = channelColors[channel].g --user selected multiplier for green channel
      local chB = channelColors[channel].b --user selected multiplier for blue channel
      local chAMultiplier = 1.0 / (chR + chG + chB) --multiplier for alpha channel

      for pixel in celCopy:pixels() do
        -- map channel names to color components
        local r = app.pixelColor.rgbaR(pixel()) * chR
        local g = app.pixelColor.rgbaG(pixel()) * chG
        local b = app.pixelColor.rgbaB(pixel()) * chB

        local alpha_2 = chAMultiplier * (r + g + b)

        local chA
          if keepAlpha then
            chA = app.pixelColor.rgbaA(pixel()) -- retain existing transparency value
          else
            chA = 255 -- override transparency value
          end
        -- get each pixel's current color channel values
        celCopy:drawPixel(pixel.x, pixel.y, Color {
            r = r,
            g = g,
            b = b,
            a = alpha_2
        })
      end
      -- create a new layer with the selected color component
      app.layer.name = layerName .. ": " .. channel
      app.image:clear()
      app.image:drawImage(celCopy)
    end
  end
)

app.transaction(
  "recombine rgba",
  function ()
    function RecombineRGBA(layer_r, layer_g, layer_b, layer_a)
      local cel = app.cel
      local celRed = layer_r:cel(1) -- get the first cel of the red layer
      local celGreen = layer_g:cel(1) -- get the first cel of the green layer
      local celBlue = layer_b:cel(1) -- get the first cel of the blue layer
      local celAlpha = layer_a:cel(1) -- get the first cel of the alpha layer
      local celCopy = celRed.image:clone()
      app.command.duplicateLayer(cel.layer)

      for pixel in celCopy:pixels() do
        local r = app.pixelColor.rgbaR(celRed.image:getPixel(pixel.x, pixel.y))
        local g = app.pixelColor.rgbaG(celGreen.image:getPixel(pixel.x, pixel.y))
        local b = app.pixelColor.rgbaB(celBlue.image:getPixel(pixel.x, pixel.y))
        local a = app.pixelColor.rgbaA(celAlpha.image:getPixel(pixel.x, pixel.y))
        celCopy:drawPixel(pixel.x, pixel.y, Color {
            r = r,
            g = g,
            b = b,
            a = a
        })
      end
      app.layer.name = app.layer.name .. ": Recombined"
      app.image:clear()
      app.image:drawImage(celCopy)
    end
  end
)

app.transaction( --Image of the layer's alpha channel in black and white
  "copy alpha channel",
  function ()
    function CopyAlpha()
      local cel = app.cel
      local celCopy = app.cel.image:clone()
      app.command.duplicateLayer(cel.layer)
      local layer = app.cel.layer
      local layerName = layer.name
      layer.isVisible = true

      for pixel in celCopy:pixels() do
        local alpha = app.pixelColor.rgbaA(pixel())
        celCopy:drawPixel(pixel.x, pixel.y, Color {
            r = 0,
            g = 0,
            b = 0,
            a = alpha
        })
      end
      app.layer.name = layerName .. ": Alpha"
      app.image:drawImage(celCopy)
    end
  end
)

local channelNames = { "Red", "Green", "Blue", "Cyan", "Magenta", "Yellow" }

local function drawpixel(to_x,to_y,to_sprite,from_x,from_y,from_sprite)
  local from_cel = from_sprite.cels[1]
  local from_pixel = from_cel.image:getPixel(from_x,from_y)
  local from_color = Color(from_pixel)
  local to_cel = to_sprite.cels[1]
  to_cel.image:drawPixel(to_x,to_y,from_color)
end

local function import_sprites_dialogue()
  local tile_width = 512
  local tile_height = 512

  local dlg = Dialog("Import Terrain Color Maps")
  dlg:file { id = "file_1", label = "File", open = false, save = false, load  = true}
  dlg:file { id = "file_2", label = "File", open = false, save = false, load  = true}
  dlg:file { id = "file_3", label = "File", open = false, save = false, load  = true}
  dlg:file { id = "file_4", label = "File", open = false, save = false, load  = true}
  dlg:button { text = "Import", onclick = function ()
      local file_1 = dlg.data.file_1
      local sprite_1 = Sprite{ fromFile = file_1 }
      local file_2 = dlg.data.file_2
      local sprite_2 = Sprite{ fromFile = file_2 }
      local file_3 = dlg.data.file_3
      local sprite_3 = Sprite{ fromFile = file_3 }
      local file_4 = dlg.data.file_4
      local sprite_4 = Sprite{ fromFile = file_4 }
      local sprite = Sprite(1024,1024) --main canvas
      sprite.layers[1].name = "Terrain Color Maps"
      for x = 0,tile_width-1,1 do
        for y = 0,tile_height-1,1 do
          if sprite_1 ~= nil then drawpixel(x,y,sprite,x,y,sprite_1) end
          if sprite_2 ~= nil then drawpixel(x+tile_width,y,sprite,x,y,sprite_2) end
          if sprite_3 ~= nil then drawpixel(x,y+tile_height,sprite,x,y,sprite_3) end
          if sprite_4 ~= nil then drawpixel(x+tile_width,y+tile_height,sprite,x,y,sprite_4) end
        end
      end
      if (sprite_1 ~= nil) then sprite_1:close() end
      if (sprite_2 ~= nil) then sprite_2:close() end
      if (sprite_3 ~= nil) then sprite_3:close() end
      if (sprite_4 ~= nil) then sprite_4:close() end
      dlg:close()
    end
  }
  dlg:show()
end

local function copy_color_channel_dialog() --take an image and copy the selected color channel to a new layer
  if not checkActiveElements() then
    return -- bail
  else
    local function createChannelButtons(dialog)
      for i, channel in ipairs(channelNames) do
        dialog:button {
          text = channel,
          onclick = function()
            CopyColor(channel, dialog.data.keepAlpha)
            dialog:close()
          end
        }
        if i % 3 == 0 and i < #channelNames then -- limit the buttons to 3 per row
          dialog:separator { text = "Composite Channels" }
        end
      end
    end

    local channelDlg = Dialog("Select a color component")
      :label { text = "Copies the chosen color component(s) of" }
      :newrow()
      :label { text = "the currently selected cel to a new layer" }
      channelDlg:button { text = "Copy All Channels", onclick = function ()
          for i, channel in ipairs(channelNames) do
            local currentLayer = app.layer
            CopyColor(channel, channelDlg.data.keepAlpha)
            app.layer = currentLayer
            channelDlg:close()
          end
        end
      }
      channelDlg:button { text = "Copy RBGA Channels", onclick = function ()
          for i, channel in ipairs({ "Red", "Green", "Blue" }) do
            local currentLayer = app.layer
            CopyColor(channel, false)
            app.layer = currentLayer
          end
          CopyAlpha()
          channelDlg:close()
        end
      }
      :newrow()
      :separator { text = "Primary Channels" }
      :newrow()
      createChannelButtons(channelDlg) -- add button for each color channel
      channelDlg:newrow()
      :button { text = "Copy Alpha", onclick = function ()
          CopyAlpha()
          channelDlg:close()
        end
      }
      :newrow()
      :check { id = "keepAlpha", text = "Retain transparency", selected = true }
      :show()
  end
end


-- Aseprite plugin API stuff...
---@diagnostic disable-next-line: lowercase-global
function init(plugin) -- initialize extension
  preferences = plugin.preferences -- update preferences global with plugin.preferences values


  plugin:newCommand {
      id = "ImportTerrainColorMaps",
      title = "Import Terrain Color Maps...",
      group = "file_import",
      onclick = import_sprites_dialogue
  }

  -- add "Copy Color Channel" command to palette options menu
  plugin:newCommand {
      id = "CopyColorChannel",
      title = "Copy Color Channel...",
      group = "sprite_color",
      onclick = copy_color_channel_dialog
  }

  -- add "Recombine RGBA" command to palette options menu
  plugin:newCommand {
      id = "RecombineRGBA",
      title = "Recombine RGBA...",
      group = "sprite_color",
      onclick = function ()
        
        local function layers_to_strings()
          local layers = {}
          for i, layer in ipairs(app.sprite.layers) do
            layers[i] = layer.name
          end
          return layers
        end

        local function string_to_layer(layer_name)
          for i, layer in ipairs(app.sprite.layers) do
            if layer.name == layer_name then
              return layer
            end
          end
          --Show dialog of error
          local dlg = Dialog("Error")
          dlg:label { text = "Layer not found: " .. layer_name }
          dlg:show()
        end

        local function find_layer_containing_substring(layer_name)
          for i, layer in ipairs(app.sprite.layers) do
            if layer.name:find(layer_name) then
              return layer
            end
          end
          --Show dialog of error
          local dlg = Dialog("Error")
          dlg:label { text = "Layer not found containing substring: " .. layer_name }
        end

        local dlg = Dialog("Recombine RGBA")
        dlg:combobox {
          id = "layer_r",
          label = "Red Layer",
          options = layers_to_strings(),
          option = find_layer_containing_substring("Red").name,
        }
        dlg:combobox {
          id = "layer_g",
          label = "Green Layer",
          options = layers_to_strings(),
          option = find_layer_containing_substring("Green").name,
        }
        dlg:combobox {
          id = "layer_b",
          label = "Blue Layer",
          options = layers_to_strings(),
          option = find_layer_containing_substring("Blue").name,
        }
        dlg:combobox {
          id = "layer_a",
          label = "Alpha Layer",
          options = layers_to_strings(),
          option = find_layer_containing_substring("Alpha").name,
        }
        dlg:button {
          text = "Recombine",
          onclick = function ()
            --debug, print layer red's name
            --local dlg2 = Dialog("Debug")
            --dlg2:label { text = dlg.data.layer_r }
            --dlg2:show()
            RecombineRGBA(string_to_layer(dlg.data.layer_r), string_to_layer(dlg.data.layer_g), string_to_layer(dlg.data.layer_b), string_to_layer(dlg.data.layer_a))
            dlg:close()
          end
        }
        dlg:show()
      end
  }
end

---@diagnostic disable-next-line: lowercase-global
function exit(plugin)
  plugin.preferences = preferences -- save preferences
  return nil
end
