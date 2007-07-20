/*
Sweet Titles (c) Creative Commons 2005
http://creativecommons.org/licenses/by-sa/2.5/
Author: Dustin Diaz | http://www.dustindiaz.com
*/
/*
 RPP - Added function : clearChildImgAlts - to remove any alt tags from 'img' 
                                            tags occuring within an 'a' tag.
       Searching only the 'Content' div to save looping over all the navigation.
*/
var sweetTitles = { 
  xCord : 0,                // @Number: x pixel value of current cursor position
  yCord : 0,                // @Number: y pixel value of current cursor position
  tipElements : ['a','abbr','acronym'],  // @Array: Allowable elements that can have the toolTip
  obj : Object,              // @Element: That of which you're hovering over
  tip : Object,              // @Element: The actual toolTip itself
  active : 0,                // @Number: 0: Not Active || 1: Active
  init : function() {
    if ( !document.getElementById ||
      !document.createElement ||
      !document.getElementsByTagName ) {
      return;
    }
    var i,j;
    this.tip = document.createElement('div');
    this.tip.id = 'toolTip';
    document.getElementsByTagName('body')[0].appendChild(this.tip);
    this.tip.style.top = '0';
    this.tip.style.visibility = 'hidden';
    var content = document.getElementById('Content'); // Only search within our content.
    if (content == null) content = document; // If the Content div exists!
    var tipLen = this.tipElements.length;
    for ( i=0; i<tipLen; i++ ) {
      var current = content.getElementsByTagName(this.tipElements[i]);
      var curLen = current.length;
      for ( j=0; j<curLen; j++ ) {
        if (current[j].title.length>0) {
          addEvent(current[j],'mouseover',this.tipOver);
          addEvent(current[j],'mouseout',this.tipOut);
          current[j].setAttribute('tip',current[j].title);
          current[j].removeAttribute('title');
          sweetTitles.clearChildImgAlts(current[j]); // Remove alts from images within.
        }
      }
    }
  },
  clearChildImgAlts : function(e) {
    if (e.hasChildNodes()) {
      var imgs = e.getElementsByTagName('img');
      if (imgs.length > 0) {
        var imgsLen = imgs.length;
        for ( k=0; k<imgsLen; k++ ) {
          imgs[k].setAttribute('alt','');
        }
      }
    }
  },
  updateXY : function(e) {
    if ( document.captureEvents ) {
      sweetTitles.xCord = e.pageX;
      sweetTitles.yCord = e.pageY;
    } else if ( window.event.clientX ) {
      sweetTitles.xCord = window.event.clientX+document.documentElement.scrollLeft;
      sweetTitles.yCord = window.event.clientY+document.documentElement.scrollTop;
    }
  },
  tipOut: function() {
    if ( window.tID ) {
      clearTimeout(tID);
    }
    if ( window.opacityID ) {
      clearTimeout(opacityID);
    }
    sweetTitles.tip.style.visibility = 'hidden';
  },
  checkNode : function() {
    var trueObj = this.obj;
    if ( this.tipElements.inArray(trueObj.nodeName.toLowerCase()) ) {
      return trueObj;
    } else {
      return trueObj.parentNode;
    }
  },
  tipOver : function(e) {
    sweetTitles.obj = this;
    tID = window.setTimeout("sweetTitles.tipShow()",500);
    sweetTitles.updateXY(e);
  },
  tipShow : function() {    
    var scrX = Number(this.xCord);
    var scrY = Number(this.yCord);
    var tp = parseInt(scrY+15);
    var lt = parseInt(scrX+10);
    var anch = this.checkNode();
    var addy = '';
    var access = '';
    var tip = anch.getAttribute('tip');
    if ( anch.nodeName.toLowerCase() == 'a' ) {
        // Split up any extra info in tip..
      idx = tip.toString().search(/ :: /);
      if (idx != -1) {
        addy = tip.substring(idx+4);
        tip = tip.substring(0,idx);
        // Look for more to split it up by (extra info type)..
        idx = addy.toString().search(/:/);
        if (idx != -1) {
          access = '<span>'+addy.substring(0,idx+1)+'</span> ';
          addy = addy.substring(idx+1);
        }
      }
      //addy = (anch.href.length > 25 ? anch.href.toString().substring(0,25)+"..." : anch.href);
      //access = ( anch.accessKey ? ' <span>['+anch.accessKey+']</span> ' : '' );
    } else {
      addy = anch.firstChild.nodeValue;
    }
    this.tip.innerHTML = "<p>"+tip+"<em>"+access+addy+"</em></p>";
    if ( parseInt(document.documentElement.clientWidth+document.documentElement.scrollLeft) < parseInt(this.tip.offsetWidth+lt) ) {
      this.tip.style.left = parseInt(lt-(this.tip.offsetWidth+10))+'px';
    } else {
      this.tip.style.left = lt+'px';
    }
    if ( parseInt(document.documentElement.clientHeight+document.documentElement.scrollTop) < parseInt(this.tip.offsetHeight+tp) ) {
      this.tip.style.top = parseInt(tp-(this.tip.offsetHeight+10))+'px';
    } else {
      this.tip.style.top = tp+'px';
    }
    this.tip.style.visibility = 'visible';
    this.tip.style.opacity = '.1';
    this.tipFade(10);
  },
  tipFade: function(opac) {
    var passed = parseInt(opac);
    var newOpac = parseInt(passed+10);
    if ( newOpac < 80 ) {
      this.tip.style.opacity = '.'+newOpac;
      this.tip.style.filter = "alpha(opacity:"+newOpac+")";
      opacityID = window.setTimeout("sweetTitles.tipFade('"+newOpac+"')",20);
    }
    else { 
      this.tip.style.opacity = '.80';
      this.tip.style.filter = "alpha(opacity:80)";
    }
  }
};
function pageLoader() {
  sweetTitles.init();
}
addEvent(window,'load',pageLoader);