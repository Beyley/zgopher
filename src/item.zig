pub const Type = enum(u8) {
    // === RFC defined. ===
    ///Item is a file
    file = '0',
    ///Item is a directory
    directory = '1',
    ///Item is a CSO phone-book server
    cso_phone_book_server = '2',
    ///Error
    @"error" = '3',
    ///Item is a BinHexed Macintosh file.
    binhexed_macintosh_file = '4',
    /// Item is DOS binary archive of some sort.
    /// Client must read until the TCP connection closes.  Beware.
    dos_binary_archive = '5',
    ///Item is a UNIX uuencoded file.
    unix_uuencoded_file = '6',
    ///Item is an Index-Search server.
    index_search = '7',
    ///Item points to a text-based telnet session.
    text_based_telnet_session = '8',
    /// Item is a binary file!
    /// Client must read until the TCP connection closes.  Beware.
    binary_file = '9',
    ///Item is a redundant server
    redundant_server = '+',
    ///Item points to a text-based tn3270 session.
    text_based_tn3270_session = 'T',
    ///Item is a GIF format graphics file.
    gif = 'g',
    ///Item is some kind of image file.  Client decides how to display.
    image_file = 'I',
    // === Gopher+ types ===
    bitmap_image = ':',
    movie_file = ';',
    sound_file = '<',
    // === Non-RFC (but well supported) ===
    /// Doc. Seen used alongside PDF's and .DOC's
    doc_file = 'd',
    html_file = 'h',
    information_message = 'i',
    /// image file "(especially the png format)"
    image_file_hinted_png = 'p',
    ///document rtf file "rich text Format")
    rtf_file = 'r',
    ///Sound file (especially the WAV format)
    sound_file_hinted_wav = 's',
    //document pdf file "Portable Document Format")
    pdf_file = 'P',
    ///document xml file "eXtensive Markup Language")
    xml_file = 'X',
    _,
    pub fn isValid(self: Type) bool {
        return switch (self) {
            .file => true,
            .directory => true,
            .cso_phone_book_server => true,
            .@"error" => true,
            .binhexed_macintosh_file => true,
            .dos_binary_archive => true,
            .unix_uuencoded_file => true,
            .index_search => true,
            .text_based_telnet_session => true,
            .binary_file => true,
            .redundant_server => true,
            .text_based_tn3270_session => true,
            .gif => true,
            .image_file => true,
            .bitmap_image => true,
            .movie_file => true,
            .sound_file => true,
            .doc_file => true,
            .html_file => true,
            .information_message => true,
            .image_file_hinted_png => true,
            .rtf_file => true,
            .sound_file_hinted_wav => true,
            .pdf_file => true,
            .xml_file => true,
            _ => false,
        };
    }
};
