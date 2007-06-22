var ass;
var intervalId;
var intervalId2;
var count;
var orig_height;

function OpenAssistant() {
  
  if (!Get_Cookie('session')) {
    return false;
  }
  
  var lpx=10;
  
  if (window.screen){
    lpx = screen.width;
    lpx = lpx - 180;
  }
  
  // Open popup named 'ass' and put it in variable 'ass'
  ass = window.open('/assistant.pl?firstopen=1',
                    'ass',
                    'location=no,toolbar=no,' +
                    'directories=no,menubar=no,' +
                    'scrollbars=no,' +
                    'status=no,resizable=yes,' +
                    'width=150,height=250,' +
                    ',top=10,left=' + lpx);
  
  // If focus is supported, bring focus to our popup
  //if (window.focus) { ass.focus() }
  // That seems not to work so now doing it from the popup itself
  // via a self.focus event tied to fire after a 50ms delay..
  
  // If that didn't work (we have no popup handle),
  // show the 'oops, popup blocked' message
  if (!ass) {
    //p = document.getElementById('popups_blocked_alert');
    p = document.getElementById('notification');
    p_href = document.getElementById('notification_href');
    if (p) {
      //p.style.zIndex = 0;
      p.style.overflow = 'hidden';
      //bg_col_above = document.getElementById("NavMenuList").getElementsByTagName("ul").item(0).getElementsByTagName("li").item(0).getElementsByTagName("a").item(0);
      orig_bg_col = p_href.style.backgroundColor;
      orig_col = p_href.style.color;
      p_href.style.backgroundColor = '#333'; //bg_col_above.style.backgroundColor;
      p_href.style.color = '#333';
      orig_height = 0;
      p.style.marginTop = -20 + 'px';
      cur_height = -20;
      intervalId = window.setInterval('cur_height = cur_height + 1; if (cur_height > orig_height) { p_href.style.backgroundColor = orig_bg_col; p_href.style.color = orig_col; window.clearInterval(intervalId) }; p.style.marginTop = cur_height + \'px\'; ', 50)
      count = 0;
      intervalId2 = window.setInterval('count = count + 1; if (count > 12) { p_href.className = \'\'; window.clearInterval(intervalId2) } else if (count > 2) { if ((count % 2) == 1) { p_href.className = \'hover\' } else { p_href.className = \'\' } }; ', 500)
      //p_href.style.backgroundColor = orig_bg_col;
      //orig_height = 20;
      //p.style.height = 0;// + 'px';
      //cur_height = 0;
      //intervalId = window.setInterval('cur_height = cur_height + 1; alert(cur_height); if (cur_height > orig_height) { window.clearInterval(intervalId) }; p.style.height = cur_height + \'px\'; ',50)
    }
  }
  return false;
}

function CloseAssistant() {
  
  // If this window didn't open the popup to have a handle,
  // (which is most likely), then create a new one to overwrite it
  // or create a new one if it's already been closed! :)
  // NB. Seems at the moment we never have a handle so are always
  // writing this popup over the existing one.. In IE & FF!
  if (!ass) {
    //alert('i have no ass! it seems i will never have an ass..');
    ass = window.open('',
                      'ass',
                      'width=1,height=1,' +
                      ',top=0,left=' + screen.width);
  }
  
  // And then close it now we have a handle on it - people who already
  // had the window closed will see a flicker as a window opens and closes,
  // people who had it open should have it changed and closed instantly..
  if (ass)
    ass.close();
  
  return false;
}


function setMainFrameHref(url){
  
  // This should be called from the popup and will set the calling frame
  // up with a nice new URL if it can find which one opened it - if it
  // doesn't find it, it will make a brand new one!
  if (self.opener && !self.opener.closed){
    self.opener.top.location.href=url;
  } else {
    window.open(url, 'main');
  }
  
  return false;
}
