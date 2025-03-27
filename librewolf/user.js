// userchrome.css usercontent.css activate
user_pref('toolkit.legacyUserProfileCustomizations.stylesheets', true);
// Trim  URL
user_pref('browser.urlbar.trimHttps', true);
// PREF: improve font rendering by using DirectWrite everywhere like Chrome [WINDOWS]
user_pref('gfx.font_rendering.cleartype_params.rendering_mode', 5);
user_pref('gfx.font_rendering.cleartype_params.cleartype_level', 100);
user_pref('gfx.font_rendering.directwrite.use_gdi_table_loading', false);
//user_pref("gfx.font_rendering.cleartype_params.enhanced_contrast", 50); // 50-100 [OPTIONAL]
// PREF: restore search engine suggestions
user_pref('browser.search.suggest.enabled', true);
// enable lazy loading of tabs
user_pref('browser.sessionstore.restore_on_demand', true);

// Enable remote debugging
user_pref("devtools.debugger.remote-enabled", true);
// Enable browser chrome and add-on debugging toolboxes
user_pref("devtools.chrome.enabled", true);

// user_pref("extensions.quarantinedDomains.enabled", false);

user_pref("browser.startup.page", 3);
