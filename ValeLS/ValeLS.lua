return {
    Id = "vale",
    Name = "Vale Language Server",
    Version = "1.0.3",
    CompatVersion = "1.0.3",
    VendorId = "theqtcompany",
    Vendor = "The Qt Company",
    Copyright = "(C) The Qt Company 2024",
    License = "GPL",
    Category = "Language Server",
    Description = "Provides an integration of the Vale language server",
    Url = "https://www.qt.io",
    Experimental = true,
    DisabledByDefault = false,
    Type = "Script",
    Dependencies = {
        { Id = "lualanguageclient", Version = "20.0.83" }
    },
    Tags = {"language server", "Vale", "ValeLS", "Qt"},
    Languages = {"en", "de"},
    setup = function()
        require 'init'.setup()
    end
} --[[@as QtcPlugin]]
