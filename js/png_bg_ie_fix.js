/* Downloaded from article: http://www.allinthehead.com/retro/69 */
/* Adapted to only look for and fix alpha for background png images of DIV elements */

/* THIS INCLUDE IS NO LONGER BEING USED ACROSS THE SITE */

if (navigator.platform == "Win32" && navigator.appName == "Microsoft Internet Explorer" && window.attachEvent) {
  window.attachEvent("onload", fnLoadPngs);
}
//hookEvent(window, "load", addShadows, false, "Apply Shadow Images");

function fnLoadPngs() {
  var rslt = navigator.appVersion.match(/MSIE (\d+\.\d+)/, '');
  var itsAllGood = (rslt != null && Number(rslt[1]) >= 5.5);
  for (var i = document.getElementsByTagName('div').length - 1, obj = null;
             (obj = document.getElementsByTagName('div')[i]); i--) {
    if (itsAllGood && obj.currentStyle.backgroundImage.match(/\.png/i) != null) {
      this.fnFixPng(obj);
      obj.attachEvent("onpropertychange", this.fnPropertyChanged);
    }
  }
}


function fnPropertyChanged() {
  if (window.event.propertyName == "style.backgroundImage") {
    var el = window.event.srcElement;
    if (!el.currentStyle.backgroundImage.match(/\/images\/thumbnail-shadow\/x\.gif/i)) {
      var bg  = el.currentStyle.backgroundImage;
      var src = bg.substring(5,bg.length-2);
      el.filters.item(0).src = src;
      el.style.backgroundImage = "url(/images/thumbnail-shadow/x.gif)";
    }
  }
}


function fnFixPng(obj) {
	var bg	= obj.currentStyle.backgroundImage;
	var src = bg.substring(5,bg.length-2);
	obj.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='" +
                           src + "', sizingMethod='scale')";
	obj.style.backgroundImage = "url(/images/thumbnail-shadow/x.gif)";
}



/* everything down here is stolen from devianArt and i'm only putting it in to
   see if we can re-use any of it for when we decide to have rotating images
   and need to adjust the background pngs and their transparency (fcn above) */



/* Let's set up some browser info! *//*
var browser = { isKHTML: false, isGecko: false,
                isIE: false, isIE5: false, isIE55: false,
                isOpera: false, isOpera75: false,
                isMac: false, isWin: false,
                isSafe: null, hasXMLHttp: false };
with (browser) {
  isKHTML = navigator.userAgent.indexOf("KHTML")>=0;
  isGecko = (!isKHTML) && navigator.product == "Gecko";
  isIE = (!isGecko) && navigator.cpuClass != undefined &&
         navigator.appName == "Microsoft Internet Explorer";
  isIE5 = isIE && (!Function.apply);
  isIE55 = isIE && (document.onmousewheel == undefined);
  isOpera = (!(isIE || isGecko || isKHTML)) && document.attachEvent != undefined;
  isMac = (navigator.appVersion.indexOf("Mac") >= 0);
  if (isOpera) {
    isOpera75 = (!/Opera[^0-9]*(?:[1-6]|[7\.[1-4]])/.test(navigator.userAgent));
  }
  if (isOpera) {
    var r = new XMLHttpRequest;
    hasXMLHttp = r.setRequestHeader ? true : false;
    delete r;
  } else {
    hasXMLHttp = browser.isIE || window.XMLHttpRequest;
  }
  isWin = (navigator.appVersion.indexOf("Windows") != -1) ? true : false;
  if (isWin) {
    browser.isWin2k = (navigator.userAgent.indexOf("Windows NT 5.0") > 0) ? true : false;
  }
  isSafe = document.getElementById != undefined && (!isIE5) &&
           (document.addEventListener != undefined || document.attachEvent != undefined);
}
*/
/* Helper fcns *//*
function forEachItem(items, call, nonLinear) {
  if (nonLinear == true) {
    for (var i in items)
      if (call(items[i], i) == -1) return;
  } else if ((items.length != undefined) && (typeof items) != 'string') {
    for (var i=0; items[i]; i++)
      if (call(items[i], i) == -1) return;
  } else {
    call(items, 0);
  }
}

function forEachStyleRule(x, call)
  {
  if (x.styleSheets){
    x = x.styleSheets;
    for (var i=0; i!=x.length; i++){
    if (forEachStyleRule(x[i].cssRules, call) == -1) return -1;
    }
  } else {
    if (x.cssRules) {
      x = x.cssRules;
    }
    for (var i=0; i!=x.length; i++) {
      if (x[i].styleSheet) {
        if (forEachStyleRule(x[i].styleSheet, call) == -1) return -1;
      } else {
        if (call(x[i]) == -1) return -1;
      }
    }
  }
}

function getNextSibling(node) {
  while (node && (node = node.nextSibling)) {
    if (node.nodeValue == null) return node;
  }
  return null;
}

function getPreviousSibling(node) {
  while (node = node.previousSibling)
    if (node.nodeValue == null) return node;
  return null;
}

function getFirstChild(node) {
  node = node.firstChild;
  if ((!node) || node.nodeValue == null) return node;
  return getNextSibling(node);
}

function getLastChild(node) {
  node = node.lastChild;
  if (node.nodeValue == null) return node;
  return getPreviousSibling(node);
}

function getElement(node, sSelector) {
  if (typeof(node) == 'string' ) {
    sSelector = node;
    node = document;
  }
  if (sSelector.charAt(0) == '#' ) {
    return node.getElementById(sSelector.substr(1));
  } else {
    return getElements(node, sSelector, 1)[0] || null;
  }
}

function getAncestor(node, sSelector) {
  var t, c, nodes, top = (node.ownerDocument || node.document).documentElement;
  t = sSelector.split('.');
  if (t[1]) {
    c = ' '+ t[1] + ' ';
  }
  t = t[0] != '' ? t[0] : null;
  do {
    if (t && getTag(node) != t) continue;
    if (c && (' '+node.className+' ').indexOf(c)<0) continue;
    return node;
  } while ((node = node.parentNode) && node != top);
  return null;
}

function hasClass(check, className) {
  if (!check) return false
  if (typeof(check) != 'string'){
    check = check.className;
  }
  return ((' '+check+' ').indexOf(' '+className+' ') >= 0);
}

function getElements(node, sSelector, max) {
  var t, c, nodes;
  if (typeof(node) == 'string' ){
    max = sSelector;
    sSelector = node;
    node = document;
  }
  if (!max){
    max = 10000;  
  }
  t = sSelector.split('.');
  c = t[1];  
  t = t[0] == '' ? '*' : t[0];
  if (browser.isIE55 && t == '*'){
    nodes = node.all;
  }else{
    nodes = node.getElementsByTagName(t);
  }
  if (!c){  
    return nodes || array();
  }else{
    c = ' '+c+' ';
  }
  var returns = Array();
  forEachItem(nodes,
    function(n, i) {
      if ((' '+n.className+' ').indexOf(c)<0)
      return;
      returns.push(n);
      if (returns.length == max) return -1;
    }
  );
  return returns;
}
*/



/* Now to set the background to the one we want - correct size etc. *//*
var _cachedShadowPath;
function addShadow(n, forceTransparency) {
  var sBg, sImg, Size;
  if (n.type == 'load') {
    n = (n.srcElement || n.target);
  }
  if (String(n.tagName).toLowerCase() == 'img') {
    Size = { w: n.width, h: n.height };
    n = getAncestor(n, '.shadow');
  } else {
    var t;
    if (!(t = getFirstChild(n))) return;
    Size = { w: t.offsetWidth, h: t.offsetHeight }
  }
  if (Size.w<90 || Size.h<60) {
    if (Size.w >= 60 && Size.h >= 40) {
      sImg = "small.png";
    } else {
      sImg = "null.png";
    }
  } else  {
    sImg = "logo.png";
  }
  if (browser.isIE && forceTransparency==true) {
  } else {
    if (!(sBg = _cachedShadowPath)) {
      if (browser.isIE) {
        sBg = n.currentStyle.getAttribute("shadow-image");
      } else {
        if (browser.isKHTML ) {
          forEachStyleRule(document,
            function(r){
              if (r.selectorText.indexOf('.shadow:') == 0) {
                sBg = r.style.getPropertyValue("background-image");
                return -1;
              }
            }
          );
        } else {
          sBg = String(getComputedStyle(n, browser.isGecko ? ":before" :
                                        "before").getPropertyValue("background-image"));
        }
      }
      _cachedShadowPath = sBg;
    }
    if (browser.isIE) {
      sBg = sBg.replace(/alpha/, _getShadowColorString(n));
    }
    sBg = sBg.replace(/\/?("?)\)/, "/" + Size.w + "/" + Size.h + "/" + sImg + "$1)");
    if (n.style.backgroundImage != sBg){
      n.style.backgroundImage = sBg;
    }
  }
}

function addFloaterShadow(node) {
  var img, src;
  src = String(
  getComputedStyle(n, browser.isGecko ? ":before" :
                   "before").getPropertyValue("background-image"));
  src = src.match('url\((.*?)\)');
  if (!src) return false;
  src = src[1];
  img = createNode();
}

function addShadows(root) {
  if (!(root && root.tagName)) {
    root = document;
  }
  forEachItem(getElements(root, "span.shadow"),
    function(n) {
      var i=getFirstChild(n);
      if (i) switch (String(i.tagName).toLowerCase()) {
        case 'a':
        case 'img':
          i = getElement(n,'img');
          break;
        default:
          i = null;
      }
      if (i) {
        if ((i.width>0 && i.height>0) || (i.complete == true)) {
          addShadow(i);
        } else {
          hookEvent(i, "load", addShadow);
        }
      } else {
        addShadow(n);
      }
    }
  );
}

function _getShadowColorString(node) {
  if (!node) return null;
  if (hasClass(node.parentNode, "devctrl")) {
    node = getAncestor(node, "p") || node;
  }
  if (node.currentStyle) {
    var sBg = node.currentStyle.backgroundColor;
    if (sBg != "transparent") {
      return sBg.substr(1, 6).toUpperCase();
    }
  }
  return _getShadowColorString(node.parentNode);
}

function hookEvent(node, sEvent, call, capture, sDebug) {
  if (!call) return alert ("Event handler function not found.");
  if (node.addEventListener) {
    node.addEventListener(sEvent, call, capture || false);
  } else if (node.attachEvent) {
    node.attachEvent("on"+sEvent, call);
  }
}
*/

