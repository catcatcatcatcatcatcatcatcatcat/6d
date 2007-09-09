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
    p = document.getElementById('popups_blocked_alert');
    p.style.display = 'block';
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
