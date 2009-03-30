var xcol_cur_menu = null;
var xcol_cur_submenu = null;

function show(id) {
  if (!isDOMcompliant()) { return; }
  var menu = document.getElementById("Menu" + id);
  if (!menu) { return; }
  var menus = document.getElementById("NavMenuList");
  if (!menus) { return; }
  var submenu = menus.getElementsByTagName("ul").item(id-1);
  if (!submenu) { return; }
  if (xcol_cur_submenu == null) {
    var menu_array = document.getElementById("Menu"); // getElementsByClassName
    // Looping UP TO 10 (lord help us if we have more than 10 first level menu items)..
    for (i = 1; i <= 10; ++i) {
      var looped_menu_href = document.getElementById("Menu"+i)
      if (looped_menu_href != null) {
        var looped_menu = looped_menu_href.parentNode
        // Hide submenu that might be open for non-js users (emi/esmi)
        if (looped_menu.className.match(/Selected/)) {
          var looped_submenu_items = looped_menu.getElementsByTagName("li");
          for (j = 0; j < looped_submenu_items.length; ++j) {
            if (looped_submenu_items[j].className.match(/Selected/)) {
              looped_submenu_items[j].className = null;
              break;
            }
          }
            looped_menu.className =
            looped_menu.className.replace(/ ?Selected/,'');
            looped_menu.getElementsByTagName("ul").item(0).className =
            looped_menu.getElementsByTagName("ul").item(0).className.replace(/ ?Selected/,'');
          break;
        }
      } else {
        break;
      }
    }
    submenu.style.visibility = "visible";
  } else {
    xcol_cur_submenu.style.visibility = "hidden";
    submenu.style.visibility = "visible";
  }
  if (xcol_cur_menu != null) {
    xcol_cur_menu.className =
      xcol_cur_menu.className.replace(/ ?Selected/,'');
  }
  menu.className = menu.className + ' Selected';
  xcol_cur_menu = menu;
  xcol_cur_submenu = submenu;
  
}

function unshow() {
  if (!isDOMcompliant()) { return; }
  if (xcol_cur_submenu != null) {
    xcol_cur_submenu.style.visibility = "hidden";
  }
  if (xcol_cur_menu != null) {
    xcol_cur_menu.className =
      xcol_cur_menu.className.replace(/ ?Selected/,'');
  }
  xcol_cur_submenu = null;
  xcol_cur_menu = null;
}

function isDOMcompliant() {
  return document.getElementById && document.getElementsByTagName;
}

function ShowLoginBox () {
  if (!document.getElementById) return true;
  var notloge = document.getElementById("NotLoggedInDiv");
  var logboxe = document.getElementById("LoginBox");
  var xcusere = document.getElementById("login_profile_name");
  if (!notloge || !logboxe || !xcusere) return true;
  notloge.style.display = 'none';
  logboxe.style.display = 'block';
  xcusere.focus();
  return false;
}

