local _ = require("gettext")
return {
    version = "0.1.2",
    fullname = _("Metadata Scraper"),
    description = _([[Fetch book metadata and covers from Hardcover, Amazon Creators API, Google Books, and Open Library. Writes KOReader-native custom metadata sidecars without modifying EPUB files.]]),
}
