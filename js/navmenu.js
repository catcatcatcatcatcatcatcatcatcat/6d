var xcol_cur_menu = null;
var xcol_cur_submenu = null;

function show(id)
{
    if (!isDOMcompliant()) { return; }
    var menu = document.getElementById("Menu" + id);
    if (!menu) { return; }
    var menus = document.getElementById("NavMenuList");
    if (!menus) { return; }
    var submenu = menus.getElementsByTagName("ul").item(id-1);
    if (!submenu) { return; }
    if (xcol_cur_submenu == null) {
        submenu.style.visibility = "visible";
    } else {
        xcol_cur_submenu.style.visibility = "hidden";
        submenu.style.visibility = "visible";
    }
    if (xcol_cur_menu == null) {
        menu.style.backgroundColor = "#FFF";
        menu.style.color = "#000";
    } else {
        xcol_cur_menu.style.backgroundColor = "#036";
        xcol_cur_menu.style.color = "#FFF";
        menu.style.backgroundColor = "#FFF";
        menu.style.color = "#000";
    }
    xcol_cur_menu = menu;
    xcol_cur_submenu = submenu;
}

function subselect(id)
{
    if (!isDOMcompliant()) { return; }
    if (!xcol_cur_submenu) { return; }
    var submenulink = xcol_cur_submenu.getElementsByTagName("li").item(id-1).childNodes[0];
    if (!submenulink) { return; }
    submenulink.style.backgroundColor = "#FFF";
    submenulink.style.color = "#000";
}

function unshow()
{
    if (!isDOMcompliant()) { return; }
    if (xcol_cur_submenu != null) {
        xcol_cur_submenu.style.visibility = "hidden";
    }
    if (xcol_cur_menu != null) {
        xcol_cur_menu.style.backgroundColor = "#036";
        xcol_cur_menu.style.color = "#FFF";
    }
    xcol_cur_submenu = null;
    xcol_cur_menu = null;
}

function isDOMcompliant()
{
    return document.getElementById && document.getElementsByTagName;
}

function xcShowLoginDiv () {
    if (!document.getElementById) return true;
    var notloge = document.getElementById("NotLoggedInDiv");
    var logboxe = document.getElementById("LoginBox");
    var xcusere = document.getElementById("xc_user");
    if (!notloge || !logboxe || !xcusere) return true;
    notloge.style.display = 'none';
    logboxe.style.display = 'block';
    xcusere.focus();
    return false;
}