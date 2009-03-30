

function openWindow(url, name, w, h, scrollbars) {
  var options = "width=" + w + ",height=" + h + ",";
  options += "resizable=yes,scrollbars=" + scrollbars + ",status=yes,";
  options += "menubar=no,toolbar=no,location=no,directories=no";
  var newWin = window.open(url, name, options);
  newWin.focus();
}

/*
Create the new window
*/
function openInNewWindow() {
  // Change "_blank" to something like "newWindow" to load all links in the same new window
  var newWindow = window.open(this.getAttribute('href'), '_blank');
  newWindow.focus();
  return false;
}

/*
Add the openInNewWindow function to the onclick event of links with a class name of "new-window"
*/
function getNewWindowLinks() {
  // Check that the browser is DOM compliant
  if (document.getElementById && document.createElement && document.appendChild) {
    // Change this to the text you want to use to alert the user that a new window will be opened
    var strNewWindowAlert = " (opens in a new window)";
    // Find all links
    var links = document.getElementsByTagName('a');
    //var objWarningText;
    //var strWarningText;
    var link;
    for (var i = 0; i < links.length; i++) {
      link = links[i];
      // Find all links with a class name of "_blank"
      //if (/\b_blank\b/.exec(link.className)) {
      // Find all links which actually link somewhere and
      // have the rel="external" attribute set.
      if (anchor.getAttribute("href") &&
          anchor.getAttribute("rel") == "external") {
        // Create an em element containing the new window warning text and insert it after the link text
        //objWarningText = document.createElement("em");
        //strWarningText = document.createTextNode(strNewWindowAlert);
        //objWarningText.appendChild(strWarningText);
        //link.appendChild(objWarningText);
        link.title = link.title + strNewWindowAlert;
        //link.onclick = openInNewWindow;
        link.target = "_blank";
      }

    }
    objWarningText = null;
  }
}

function change_theme() {
  /* Get the current chosen theme (if none, assume it is at zero index) */
  var current_theme_index = Get_Cookie('theme');
  if (current_theme_index == undefined)
    current_theme_index = 0;
  
  /* choose random theme that isn't the currently chosen one */
  var chosen_theme_index = current_theme_index;
  while (chosen_theme_index == current_theme_index) {
    chosen_theme_index = Math.floor(Math.random()*themes.length);
  }
  
  /* Set this theme in the cookie */
  Set_Cookie( 'theme',
              chosen_theme_index,
              (365 * 5),
              '/' );
  /* Set this theme in the css itself! */
  document.getElementById('theme').href = '/css/navmenu-' + themes[chosen_theme_index] + '.css';
  document.getElementById('theme-logo').src = '/images/navigation/' + themes[chosen_theme_index] + '/logo.gif';
}

/* Not working properly on FF atm so commenting out for the time being! */
/*
function slide_down_notification(p,p_href) {
  
  var p = document.getElementById('notification');
  var p_href = document.getElementById('notification_href');
  
  if (p && p_href) {
    //p.style.zIndex = 0;
    p.style.overflow = 'hidden';
    //bg_col_above = document.getElementById("NavMenuList").getElementsByTagName("ul").item(0).getElementsByTagName("li").item(0).getElementsByTagName("a").item(0);
    orig_bg_col = p_href.style.backgroundColor;
    orig_col = p_href.style.color;
    p_href.style.backgroundColor = '#333'; //bg_col_above.style.backgroundColor;
    p_href.style.color = '#333';
    orig_height = 0;
    cur_height = -20;
    //p.style.marginTop = cur_height + 'px';
    intervalId = window.setInterval('cur_height = cur_height + 1; if (cur_height > orig_height) { p_href.style.backgroundColor = orig_bg_col; p_href.style.color = orig_col; window.clearInterval(intervalId) }; p.style.marginTop = cur_height + \'px\'; ', 50);
    count = 0;
    intervalId2 = window.setInterval('count = count + 1; if (count > 12) { p_href.className = \'\'; window.clearInterval(intervalId2) } else if (count > 2) { if ((count % 2) == 1) { p_href.className = \'hover\' } else { p_href.className = \'\' } }; ', 500)
    //p_href.style.backgroundColor = orig_bg_col;
    //orig_height = 20;
    //p.style.height = 0;// + 'px';
    //cur_height = 0;
    //intervalId = window.setInterval('cur_height = cur_height + 1; alert(cur_height); if (cur_height > orig_height) { window.clearInterval(intervalId) }; p.style.height = cur_height + \'px\'; ',50)
  }
}
*/

/* This function is currently unused! */
/*
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
*/