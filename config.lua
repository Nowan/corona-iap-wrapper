--
-- For more information on config.lua see the Corona SDK Project Configuration Guide at:
-- https://docs.coronalabs.com/guide/basics/configSettings
--

application =
{
	content =
	{
		width = 768,
		height = 1024,
		scale = "adaptive",
		fps = 30,
		--yAlign = "top",

		--[[
		imageSuffix =
		{
			    ["@2x"] = 2,
			    ["@4x"] = 4,
		},
		--]]
	},
	license =
    {
        google =
        {
            key = "[your_application_license_key]",
        },
    },
}
