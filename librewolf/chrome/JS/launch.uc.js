// ==UserScript==
// @name            fx-launch-menu
// @author          eissar
// @onlyonce
// ==/UserScript==
(function () {
    function find_and_activate(target_host) {
        let found = false;
        UC_API.Windows.forEach((_document, window) => {
            if (found) return;
            const tabs = window.gBrowser.browsers;
            for (let i = 0; i < tabs.length; i++) {
                if (tabs[i].currentURI.asciiHost === target_host) {
                    found = true;
                    const switchToUri = tabs[i].currentURI.asciiSpec;
                    switchToTabHavingURI(switchToUri, false);
                    break;
                }
            }
        });
        if (found === false) {
            switchToTabHavingURI('https://' + target_host, true); // create if doesn't exist.
        }
    }
    const buttonId = 'fx-launch_button';
    const buttonLabel = 'FX Launch Button';
    const buttonTooltiptext = 'FX Launch Button';
    CustomizableUI.createWidget({
        //must run createWidget before windowListener.register because the  register function needs the button added first
        id: buttonId,
        type: 'custom',
        defaultArea: CustomizableUI.AREA_NAVBAR,
        onBuild: function (aDocument) {
            const toolbaritem = aDocument.createElementNS(
                'http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul',
                'toolbarbutton',
            );
            const props = {
                id: buttonId,
                class: 'toolbarbutton-1 chromeclass-toolbar-additional',
                type: 'menu',
                label: buttonLabel,
                tooltiptext: buttonTooltiptext,
                style: 'list-style-image: url("chrome://browser/skin/places/bookmarksToolbar.svg");',
                removable: 'true',
            };
            for (const p in props) {
                toolbaritem.setAttribute(p, props[p]);
            }
            const menupopup = aDocument.createElementNS(
                'http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul',
                'menupopup',
            );
            menupopup.id = 'aboutMenuPopup';
            toolbaritem.appendChild(menupopup);
            // target: hostname to find_and_activate
            // accesskey optional
            function appendMenuitem(target, accessKey) {
                const menuitem = aDocument.createElementNS(
                    'http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul',
                    'menuitem',
                );
                menuitem.setAttribute('label', target);
                menuitem.addEventListener('command', () => find_and_activate(target));
                if (accessKey) {
                    menuitem.setAttribute('accesskey', accessKey);
                }
                menupopup.appendChild(menuitem);
            }
            appendMenuitem('gemini.google.com', 'g');
            appendMenuitem('music.youtube.com', 'm');
            appendMenuitem('www.youtube.com', 'y');
            appendMenuitem('keep.google.com', 'k');
            appendMenuitem('app.raindrop.io', 'r');
            appendMenuitem('github.com', 't');
            appendMenuitem('my.wgu.edu', 'w');
            return toolbaritem;
        },
    });
})();
UC_API.Hotkeys.define({
    modifiers: 'accel shift',
    key: 'l',
    id: 'key_runLaunch',
    command: () => document.querySelector('#fx-launch_button').openMenu(true),
}).autoAttach({ suppressOriginal: true });
