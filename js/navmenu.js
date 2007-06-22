var xcol_cur_menu = null;
var xcol_cur_submenu = null;

var original_bgcolor = "transparent"; //null;
var original_color = "#FFF"; //null;
if (col = getStyle(document.getElementById("Menu1"),'backgroundColor')) {
  original_bgcolor = col;
  //alert('starting out with original bgcolor:' + col);
}
if (col = getStyle(document.getElementById("Menu1"),'backgroundColor')) {
  original_color = col;
  //alert('starting out with original color:' + col);
}

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
      //alert('oooh:' + looped_menu_href);
      if (looped_menu_href != null) {
        //alert('whee:' + looped_menu_href.getAttribute('id'));
        var looped_menu = looped_menu_href.parentNode
        // Hide submenu that might be open for non-js users (emi/esmi)
        if (looped_menu.className.match(/Selected/)) {
	  //alert('selected menu: ' + looped_menu.innerHTML);
	  var looped_submenu_items = looped_menu.getElementsByTagName("li");
          for (j = 0; j < looped_submenu_items.length; ++j) {
            //alert('found submenu item: ' + looped_submenu_items[j].innerHTML);
            if (looped_submenu_items[j].className.match(/Selected/)) {
              looped_submenu_items[j].className = null;
              //alert('selected submenu item unclassed: ' + looped_submenu_items[j].innerHTML);
              break;
            }
          }
  	  looped_menu.className =
	    looped_menu.className.replace(/Selected/,'');
	  //alert('removed selected class tag from menu li');
  	  looped_menu.getElementsByTagName("ul").item(0).className =
	    looped_menu.getElementsByTagName("ul").item(0).className.replace(/Selected/,'');
	  //alert('removed selected class tag from submenu ul');
	  break;
        }
      } else {
        break;
      }
    }
    //alert('show shows new submenu of:' + submenu.parentNode.firstChild.getAttribute('id'));
    submenu.style.visibility = "visible";
  } else {
    //alert('show hides submenu of:' + xcol_cur_submenu.parentNode.firstChild.getAttribute('id')
    //      + ' and shows new submenu of:' + submenu.parentNode.firstChild.getAttribute('id'));
    xcol_cur_submenu.style.visibility = "hidden";
    submenu.style.visibility = "visible";
  }
  if (xcol_cur_menu == null) {
    //alert('original colors get on first show:' + original_color + ' and ' + original_bgcolor
    //      + ' for menu:' + menu.getAttribute('id'));
    menu.style.backgroundColor = "#FFF";
    menu.style.color = "#000";
  } else {
    xcol_cur_menu.style.backgroundColor = original_bgcolor;
    xcol_cur_menu.style.color = original_color;
    //alert('original colors reset on show:' + original_color + ' and ' + original_bgcolor
    //      + ' of menu:' + xcol_cur_menu.getAttribute('id'));
    menu.style.backgroundColor = "#FFF";
    menu.style.color = "#000";
  }
  xcol_cur_menu = menu;
  xcol_cur_submenu = submenu;
}

function subselect(id) {
  if (!isDOMcompliant()) { return; }
  if (!xcol_cur_submenu) { return; }
  var submenulink = xcol_cur_submenu.getElementsByTagName("li").item(id-1).childNodes[0];
  if (!submenulink) { return; }
  submenulink.style.backgroundColor = "#FFF";
  submenulink.style.color = "#000";
}

function unshow() {
  if (!isDOMcompliant()) { return; }
  if (xcol_cur_submenu != null) {
    xcol_cur_submenu.style.visibility = "hidden";
    //alert('unshow hides submenu of:' + xcol_cur_submenu.parentNode.firstChild.getAttribute('id'));
  }
  if (xcol_cur_menu != null) {
    xcol_cur_menu.style.backgroundColor = original_bgcolor;
    xcol_cur_menu.style.color = original_color;
    //alert('original colors reset on unshow:' + original_color
    //      + ' and ' + original_bgcolor + ' of menu:' + xcol_cur_menu.getAttribute('id'));
  }
  xcol_cur_submenu = null;
  xcol_cur_menu = null;
}

function isDOMcompliant() {
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


function getStyle(elem,styleProp) {
  if (!elem) { return false; }
  //var x = document.getElementById(elem);
  var elem_style = null;
  if (elem.currentStyle)
    elem_style = elem.currentStyle[styleProp];
  else if (window.getComputedStyle)
    //elem_style = document.defaultView.getComputedStyle(elem,null).getPropertyValue(styleProp);
    elem_style = document.defaultView.getComputedStyle(elem,'').getPropertyValue(styleProp);
  return elem_style;
}
