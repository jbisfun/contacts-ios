# contacts-ios

[Fossify Contacts](https://github.com/FossifyOrg/Contacts) re-created for iOS in SwiftUI, on top of the system contact store (`Contacts.framework`).

    idl build -c release     # -> build/release/FossifyContacts.ipa (ad-hoc signed; re-sign to install)
    idl install "<device>" FossifyContacts

Ported: contacts/favorites/groups tabs with search, letter fast scroller, multi-select actions, sorting and source filter; view/edit contact with all Fossify fields and labels; groups; favorites with custom order and grid view; dialpad; vCard import/export/share; automatic backups (Files › On My iPhone › Contacts › Backups); colors, font size and every applicable setting.

Differences forced by iOS: favorites and default numbers are stored by the app (iOS keeps its own private); notes and ringtones are not shown (restricted entitlement / no API); automatic backups run when the app is opened after 6 AM instead of from an alarm; launcher shortcuts, private contacts and "open with" don't exist.

GPL-3.0, like the original.
