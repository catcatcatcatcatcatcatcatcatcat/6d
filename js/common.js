

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
      if (/\b_blank\b/.exec(link.className)) {
        // Create an em element containing the new window warning text and insert it after the link text
        //objWarningText = document.createElement("em");
        //strWarningText = document.createTextNode(strNewWindowAlert);
        //objWarningText.appendChild(strWarningText);
        //link.appendChild(objWarningText);
        link.title = link.title + strNewWindowAlert;
        link.onclick = openInNewWindow;
      }
    }
    objWarningText = null;
  }
}

/* ########################################### */