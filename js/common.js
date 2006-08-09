
function openWindow(url, name, w, h, scrollbars) {
  var options = "width=" + w + ",height=" + h + ",";
  options += "resizable=yes,scrollbars=" + scrollbars + ",status=yes,";
  options += "menubar=no,toolbar=no,location=no,directories=no";
  var newWin = window.open(url, name, options);
  newWin.focus();
}