local _ = require("gettext")
local Version = require("lib/version")

return {
    version = Version.VERSION,
    fullname = _("Metadata Scraper"),
    description = _([[Fetch book metadata and covers from Hardcover, Amazon Creators API, Google Books, and Open Library. Writes KOReader-native custom metadata sidecars without modifying EPUB files.]]),
}
