// ==UserScript==
// @name            fx-launch-menu
// @author          eissar
// @onlyonce
// ==/UserScript==
(function () {
    function find_and_activate(target_host) {
        console.log('finding...');
        let found = false;
        UC_API.Windows.forEach((_document, window) => {
            if (found) return;
            const tabs = window.gBrowser.browsers;
            for (let i = 0; i < tabs.length; i++) {
                if (tabs[i].currentURI.asciiHost === target_host) {
                    found = true;
                    // console.log(window.gBrowser,i, tabs[i]);
                    // console.log(tabs[i].currentURI.asciiSpec);
                    const switchToUri = tabs[i].currentURI.asciiSpec;
                    //switchToTabHavingURI(switchToUri, false, { adoptIntoActiveWindow: true });
                    switchToTabHavingURI(switchToUri, false);
                    break;
                }
            }
        });
    }
    const buttonId = 'fx-launch_button';
    const buttonLabel = 'FX Launch Button';
    const buttonTooltiptext = 'FX Launch Button';
    const buttonIcon =
        'url(\'data:image/svg+xml;charset=utf-8,<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path fill="context-fill" fill-opacity="context-fill-opacity" fill-rule="evenodd" d="M13.5 5A2.5 2.5 0 1 1 16 2.5 2.5 2.5 0 0 1 13.5 5zM8 6a1 1 0 1 1 1-1 1 1 0 0 1-1 1zm1 5a1 1 0 0 1-2 0V8a1 1 0 0 1 2 0v3zM8 2a6.08 6.08 0 1 0 5.629 3.987 3.452 3.452 0 0 0 .984-.185A6.9 6.9 0 0 1 15 8a7 7 0 1 1-7-7 6.9 6.9 0 0 1 2.2.387 3.452 3.452 0 0 0-.185.984A5.951 5.951 0 0 0 8 2z"/></svg>\')';
    CustomizableUI.createWidget({
        //must run createWidget before windowListener.register because the  register function needs the button added first
        id: buttonId,
        type: 'custom',
        defaultArea: CustomizableUI.AREA_NAVBAR,
        onBuild: function (aDocument) {
            var toolbaritem = aDocument.createElementNS(
                'http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul',
                'toolbarbutton',
            );
            var props = {
                id: buttonId,
                class: 'toolbarbutton-1 chromeclass-toolbar-additional',
                type: 'menu',
                label: buttonLabel,
                tooltiptext: buttonTooltiptext,
                style: 'list-style-image:' + buttonIcon,
                removable: 'true',
            };
            for (var p in props) {
                toolbaritem.setAttribute(p, props[p]);
            }
            var menupopup = aDocument.createElementNS(
                'http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul',
                'menupopup',
            );
            menupopup.id = 'aboutMenuPopup';
            toolbaritem.appendChild(menupopup);
            // target: hostname to find_and_activate
            // accesskey optional
            function appendMenuitem(target, accessKey) {
                var menuitem = aDocument.createElementNS(
                    'http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul',
                    'menuitem',
                );
                menuitem.setAttribute('label', target);
                // menuitem.setAttribute('onclick', 'openTrustedLinkIn("' + aboutUrl + '", "tab")');
                //menuitem.addEventListener('command', function() { find_and_activate(target) }, false)
                menuitem.addEventListener('command', function () {
                    find_and_activate(target);
                }, false);
                if (accessKey) {
                    menuitem.setAttribute('accesskey', accessKey);
                }
                menupopup.appendChild(menuitem);
            }
            appendMenuitem('gemini.google.com', 'g');
            appendMenuitem('music.youtube.com', 'm');
            appendMenuitem('youtube.com', 'y');
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
