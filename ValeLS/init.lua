local LSP = require('LSP')
local S = require('Settings')
local Gui = require('Gui')
local a = require('async')
local fetch = require('Fetch').fetch
local Utils = require('Utils')
local mm = require('MessageManager')
local Install = require('Install')

Settings = {}

local function filter(tbl, callback)
  for i = #tbl, 1, -1 do
    if not callback(tbl[i]) then
      table.remove(tbl, i)
    end
  end
end

local function installOrUpdateServer()
  local data = a.wait(fetch({
    url = "https://qtccache.qt.io/ValeLanguageServer/LatestRelease",
    convertToTable = true
  }))

  if type(data) == "table" and #data > 0 then
    local r = data[1]
    local lspPkgInfo = Install.packageInfo("vale-language-server")
    if not lspPkgInfo or lspPkgInfo.version ~= r.tag_name then
      local osTr = { mac = "apple-darwin", windows = "pc-windows", linux = "unknown-linux" }
      local archTr = {
        unknown = "",
        x86 = "",
        x86_64 = "x86_64",
        itanium = "",
        arm = "",
        arm64 =
        "aarch64"
      }
      local os = osTr[Utils.HostOsInfo.os]
      local arch = archTr[Utils.HostOsInfo.architecture]

      local expectedFileName = "vale-ls-" .. arch .. "-" .. os

      filter(r.assets, function(asset)
        return string.find(asset.name, expectedFileName, 1, true) == 1
      end)

      if #r.assets == 0 then
        print("No assets found for this platform")
        return
      end
      local res, err = a.wait(Install.install(
        tr("Do you want to install the Vale Language Server?"), {
          name = "vale-language-server",
          url = r.assets[1].browser_download_url,
          version = r.tag_name
        }))

      if not res then
        mm.writeFlashing(tr("Failed to install Vale Language Server: ") .. err)
        return
      end

      lspPkgInfo = Install.packageInfo("vale-language-server")
      print(string.format(tr("Installed: %s, version: %s, at: %s"), lspPkgInfo.name, lspPkgInfo.version, lspPkgInfo.path))
    end

    local binary = "vale-ls"
    if Utils.HostOsInfo.isWindowsHost() then
      binary = "vale-ls.exe"
    end

    Settings.binary:setValue(lspPkgInfo.path:resolvePath(binary))
    Settings:apply()
    return
  end

  if type(data) == "string" then
    print(tr("Failed to fetch:"), data)
  else
    print(tr("No Vale Language Server release found."))
  end
end

local function using(tbl)
  local result = _G
  for k, v in pairs(tbl) do result[k] = v end
  return result
end
local function layoutSettings()
  --- "using namespace Gui"
  local _ENV = using(Gui)

  local layout = Form {
    Settings.binary, br,
    Settings.configPath, br,
    Settings.autoInstallVale, br,
    Settings.syncOnStartup, br,
    Settings.valeBinary, br,
    Settings.root, br,
    Settings.noGlobal, br,
    Settings.filter, br,
    Settings.showMetrics, br,
    Settings.lintOnChange, br,
    Settings.debounceMs, br,
    Settings.roots, br,
    Row {
      PushButton {
        text = tr("Install Vale Language Server"),
        onClicked = function() a.sync(installOrUpdateServer)() end,
      },
      st
    }
  }
  return layout
end

local function binaryFromPkg()
  local lspPkgInfo = Install.packageInfo("vale-language-server")
  if lspPkgInfo then
    local binary = "vale-ls"
    if Utils.HostOsInfo.isWindowsHost() then
      binary = "vale-ls.exe"
    end
    local binaryPath = lspPkgInfo.path:resolvePath(binary)
    if binaryPath:isExecutableFile() == true then
      return binaryPath
    end
  end

  return nil
end

local function findBinary()
  local binary = binaryFromPkg()
  if binary then
    return binary
  end

  -- Search for the binary in the PATH
  local serverPath = Utils.FilePath.fromUserInput("vale-ls")
  local absolute = a.wait(serverPath:searchInPath()):resolveSymlinks()
  if absolute:isExecutableFile() == true then
    return absolute
  end
  return serverPath
end

local function setupAspect()
  ---@class Settings: AspectContainer
  Settings = S.AspectContainer.create({
    autoApply = false,
    layouter = layoutSettings,
    settingsGroup = "ValeLS",
  });

  Settings.binary = S.FilePathAspect.create({
    settingsKey = "Binary",
    displayName = tr("Binary"),
    labelText = tr("Binary:"),
    toolTip = tr("The path to the Vale Language Server binary."),
    expectedKind = S.Kind.ExistingCommand,
    defaultPath = findBinary(),
  })

  Settings.autoInstallVale = S.BoolAspect.create({
    settingsKey = "AutoInstall",
    displayName = tr("Automatically Install Vale CLI"),
    labelText = tr("Auto Install Vale:"),
    toolTip = tr("Automatically install the necessary vale cli?"),
    defaultValue = true,
    labelPlacement = S.LabelPlacement.InExtraLabel,
  })

  Settings.configPath = S.FilePathAspect.create({
    settingsKey = "ConfigPath",
    displayName = tr("Config Path"),
    labelText = tr("Config Path:"),
    toolTip = tr("An absolute path to a .vale.ini file to be used as the default configuration."),
    expectedKind = S.Kind.File,
  })

  Settings.syncOnStartup = S.BoolAspect.create({
    settingsKey = "syncOnStartup",
    displayName = ("Sync On Startup"),
    labelText = ("Sync On Startup:"),
    toolTip = ("Runs `vale sync` upon starting the server."),
    defaultValue = false,
    labelPlacement = S.LabelPlacement.InExtraLabel,
  })

  Settings.valeBinary = S.FilePathAspect.create({
    settingsKey = "ValeBinary",
    displayName = tr("Vale Binary"),
    labelText = tr("Vale Binary:"),
    toolTip = tr("The path to the Vale CLI. Empty uses the one on PATH."),
    expectedKind = S.Kind.ExistingCommand,
  })

  Settings.root = S.FilePathAspect.create({
    settingsKey = "Root",
    displayName = tr("Root"),
    labelText = tr("Root:"),
    toolTip = tr("The directory Vale runs from when no document is open. Empty uses the workspace root."),
    expectedKind = S.Kind.ExistingDirectory,
  })

  Settings.noGlobal = S.BoolAspect.create({
    settingsKey = "NoGlobal",
    displayName = tr("No Global Vale Config"),
    labelText = tr("No Global Config:"),
    toolTip = tr("Pass --no-global to every Vale call."),
    defaultValue = false,
    labelPlacement = S.LabelPlacement.InExtraLabel,
  })

  Settings.filter = S.StringAspect.create({
    settingsKey = "Filter",
    displayName = tr("Filter"),
    labelText = tr("Filter:"),
    toolTip = tr("A config filter passed to Vale."),
    defaultValue = "",
  })

  Settings.showMetrics = S.BoolAspect.create({
    settingsKey = "ShowMetrics",
    displayName = tr("Show Metrics"),
    labelText = tr("Show Metrics:"),
    toolTip = tr("Show the metrics code lens."),
    defaultValue = true,
    labelPlacement = S.LabelPlacement.InExtraLabel,
  })

  Settings.lintOnChange = S.BoolAspect.create({
    settingsKey = "LintOnChange",
    displayName = tr("Lint On Change"),
    labelText = tr("Lint On Change:"),
    toolTip = tr("Lint while typing. When off, linting happens on save only."),
    defaultValue = true,
    labelPlacement = S.LabelPlacement.InExtraLabel,
  })

  Settings.debounceMs = S.IntegerAspect.create({
    settingsKey = "DebounceMs",
    displayName = tr("Debounce (ms)"),
    labelText = tr("Debounce (ms):"),
    toolTip = tr("How long typing must settle before linting, in milliseconds."),
    defaultValue = 300,
  })

  Settings.roots = S.StringListAspect.create({
    settingsKey = "Roots",
    displayName = tr("Roots"),
    labelText = tr("Roots:"),
    toolTip = tr("Workspace roots used to pick the .vale.ini for each file. Empty uses the opened folders."),
  })

  Settings:readSettings()

  Options = S.OptionsPage.create({
    aspectContainer = Settings,
    categoryId = "Vale.OptionsPage",
    displayName = tr("Language Server"),
    id = "Vale.Settings",
    displayCategory = "Vale",
    categoryIconPath = PluginSpec.pluginDirectory:resolvePath("icon.png"),
  })
end

local function createCommand()
  local cmd = { Settings.binary.expandedValue:nativePath() }
  return cmd
end

local function createInitOptions()
  local result = {
    installVale = Settings.autoInstallVale.value,
    syncOnStartup = Settings.syncOnStartup.value,
    noGlobal = Settings.noGlobal.value,
    filter = Settings.filter.value,
    showMetrics = Settings.showMetrics.value,
    lintOnChange = Settings.lintOnChange.value,
    debounceMs = Settings.debounceMs.value,
    roots = Settings.roots.value,
  }
  if Settings.configPath.expandedValue:exists() then
    result.configPath = Settings.configPath.expandedValue:toUserOutput()
  end
  if Settings.valeBinary.expandedValue:exists() then
    result.valeBinaryPath = Settings.valeBinary.expandedValue:toUserOutput()
  end
  if Settings.root.expandedValue:exists() then
    result.root = Settings.root.expandedValue:toUserOutput()
  end
  return result
end

local function setupClient()
  Client = LSP.Client.create({
    name = 'Vale Language Server',
    cmd = createCommand,
    transport = 'stdio',
    showInSettings = false,
    languageFilter = {
      patterns = { '*' },
    },
    initializationOptions = createInitOptions,
    settings = Settings,
    startBehavior = "RequiresProject",
    onStartFailed = function()
      a.sync(function()
        if IsTryingToInstall == true then
          mm.writeFlashing("RECURSION!");
          return
        end
        IsTryingToInstall = true
        installOrUpdateServer()
        IsTryingToInstall = false
      end)()
    end
  })
end


local function setup()
  setupAspect()
  setupClient()
end

return {
  setup = function() a.sync(setup)() end,
}
