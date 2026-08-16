local M = {
    VERSION = "0.1.3",
    PRODUCT = "KOReader-Metadata-Scraper",
}

function M.user_agent()
    return M.PRODUCT .. "/" .. M.VERSION
end

return M
