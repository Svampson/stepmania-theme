MusicWheelEntry = {}
MusicWheelEntry_mt = { __index = MusicWheelEntry }

function MusicWheelEntry:create()
  local self = {}
  setmetatable( self, MusicWheelEntry_mt )

  self.data = nil

  return self
end

function MusicWheelEntry:create_actors(params)
  local container = Def.ActorFrame {
    InitCommand = function(subself)
      self.container = subself
    end
  }

  local get_x = function()
    if self.data.type == "Song" then
      return self.is_focused and 0 or 50
    else
      return self.is_focused and -50 or 0
    end
  end

  local t = Def.ActorFrame {
    UpdateCommand = function(subself)
      subself:linear(0.1)
             :x(get_x())
             :queuecommand("AfterUpdate")
      self.last_type = self.data.type
    end,

    OpenGroupCommand = function(subself)
      if self.data.type == "Group" then
        subself:finishtweening()
               :queuecommand("AfterUpdate")
      else
        subself:finishtweening()
               :tween(0.2, "TweenType_Accelerate")
               :x(SCREEN_WIDTH/2 + 128)
               :queuecommand("AfterUpdate")
               :tween(0.2, "TweenType_Decelerate")
               :x(get_x())
      end
    end,

    CloseGroupCommand = function(subself)
      if self.last_type == "Group" then
        subself:finishtweening()
               :queuecommand("AfterUpdate")
      else
        subself:finishtweening()
               :tween(0.2, "TweenType_Accelerate")
               :x(SCREEN_WIDTH/2 + 128)
               :queuecommand("AfterUpdate")
               :tween(0.2, "TweenType_Decelerate")
               :x(self.is_focused and -50 or 0)
      end
    end,
  }

  container[#container+1] = t

  -- Background
  t[#t+1] = Def.Quad {
    InitCommand = function(subself)
      subself:diffuse(Alpha(ThemeColor.Black, 0.2))
             :diffuseleftedge(Alpha(ThemeColor.Black, 0.8))
             :zoomto(SCREEN_WIDTH/2 + 128, 62)
             :y(1)
             :halign(0)
    end
  }


  -- Background focus background
  t[#t+1] = Def.Quad {
    InitCommand = function(subself)
      subself:zoomto(0, 62)
             :y(1)
             :halign(0)
             :diffuse(ThemeColor.Red)
    end,

    UpdateCommand = function(subself)
      if (self.is_focused) then
      subself:stoptweening()
             :linear(0.2)
             :zoomtowidth(SCREEN_WIDTH/2 + 128)
      else
        subself:stoptweening()
               :linear(0.15)
               :zoomtowidth(0)
      end
    end,

    OpenGroupCommand = function(subself)
      if self.is_focused == false then return end
      subself:finishtweening()
    end
  }

  -- Title
  t[#t+1] = Def.BitmapText {
    Font = "Common Normal",
    InitCommand = function(subself)
      subself:diffuse(ThemeColor.White)
             :halign(0)
    end,

    AfterUpdateCommand = function(subself)
      subself:settext(self.data.title)
             :x(self.data.type == "Song" and 64+16 or 16)
    end,

    OpenGroupCommand = function(subself)
      if self.data.type ~= "Song" then return end
    end,
  }

  -- Difficulty level
  t[#t+1] = Def.BitmapText {
    Name = "Difficulty Level",
    Font = "Common Normal",
    InitCommand = function(subself)
      subself:diffuse(ThemeColor.White)
      :x(40)
      :visible(false)
      :shadowcolor(ThemeColor.Black)
      :shadowlength(1)
      :horizalign("HorizAlign_Center")
    end,

    AfterUpdateCommand = function(subself)
      if (self.data.type == "Song") then
        subself:settext(self.data.level)
        :diffuse(DifficultyColors[self.data.difficulty])
        :visible(true)
      else
        subself:visible(false)
      end
    end
  }

  -- Clear lamp
  t[#t+1] = Def.Quad {
    Name = "Clear Lamp",
    InitCommand = function(subself)
      subself:zoomto(8, 62)
      :y(1)
      :visible(false)
      :halign(0)
    end,

    AfterUpdateCommand = function(subself)
      -- TODO: Fix flashing lights being stuck during scrolling
      -- and make them all sync with a global timer or something
      subself:stoptweening()
      if (self.data.type == "Song") then
        subself:visible(true)
        :diffuse(ThemeColor.Black)

        if (self.data.score == nil) then
          -- No play
          return
        end

        if (self.data.score.grade == "Grade_Failed") then
          -- Failed
          subself.flash_speed = 0.2
          subself.flash_colors = { ThemeColor.Red, ThemeColor.Black }
          subself:queuecommand("Flash")
        elseif table.find_index(self.data.score.award, { "StageAward_FullComboW3", "StageAward_SingleDigitW3", "StageAward_OneW3" }) ~= -1 then
          -- Full Combo Clear
          subself.flash_speed = 0.1
          subself.flash_colors = { ThemeColor.Blue, ThemeColor.Yellow, ThemeColor.White }
          subself:queuecommand("Flash")
        elseif table.find_index(self.data.score.award, { "StageAward_FullComboW2", "StageAward_SingleDigitW2", "StageAward_OneW2" }) ~= -1 then
          -- Perfect Full Combo Clear
          subself.flash_speed = 0.06
          subself.flash_colors = { ThemeColor.Red, ThemeColor.Yellow, ThemeColor.White, ThemeColor.Green }
          subself:queuecommand("Flash")
        elseif self.data.score.award == "StageAward_FullComboW1" then
          -- Marevelous Full Combo Clear
          subself.flash_speed = 0.04
          subself.flash_colors = { ThemeColor.Red, ThemeColor.Yellow, ThemeColor.White, ThemeColor.Green }
          subself:queuecommand("Flash")
        else
          -- Regular Clear
          subself:diffuse(ThemeColor.Yellow)
        end
      else
        subself:visible(false)
      end
    end,

    FlashCommand = function(subself)
      subself:stoptweening()
      for i, color in ipairs(subself.flash_colors) do
        subself:diffuse(color)
        :sleep(subself.flash_speed)
      end

      subself:queuecommand("Flash")
    end
  }
  return container
end

function MusicWheelEntry:transform(item_index, num_items, is_focus)
  if self.index_last_update == nil then
    -- Keep track what this entries index is, if it jumps more then one (because of scrolling multiple or it wrapping around) we should not tween it.
    self.index_last_update = item_index
  end

  self.is_focused = is_focus

  if item_index == self.index_last_update+1 or item_index == self.index_last_update-1 then
    self.container:stoptweening()
                  :linear(0.1)
                  :y(item_index * 64)
  else
    self.container:stoptweening()
                  :y(item_index * 64)
  end

  self.index_last_update = item_index
end

function MusicWheelEntry:set(data)
  self.data = data
  self.container:queuecommand("Update")
end