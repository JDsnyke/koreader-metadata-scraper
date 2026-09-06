local M = {
    VERSION = "0.1.4",
    PRODUCT = "KOReader-Metadata-Scraper",
}

function M.user_agent()
    return M.PRODUCT .. "/" .. M.VERSION
end

return M
