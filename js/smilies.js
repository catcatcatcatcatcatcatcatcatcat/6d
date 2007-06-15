//
// *** Smiley Script V 3.0 ***
// Original author: EasterEgg (http://www.xanga.com/easteregg)
// 
// You can use this code freely, as long as the entire script remains 
// intact, including the copyright notice. 
//
// Many thanks to Alice Woodrome (http://www.xanga.com/Alice), who handpicked 
// the emoticons that are currently present in this version of the script.
//
// VERSION HISTORY
//
// 1.0 (February 11, 2003)
// - initial release
//
// 2.0 (May 12, 2003)
// - cross browser: it runs in IE, Netscape, Mozilla and Opera
// - ready for the upcoming (beta tested) changes at Xanga
// - clickable smileys, even for non-IE users, displayed in buttons
// - customizable number of smileys displayed in one row
// - customizable smiley button size
// - easily adjustable: only two arrays to maintain
//
// 2.1 (May 12, 2003)
// - preloading images for faster performance
// - XP Bugfix
//
// 2.2 (May 17, 2003)
// - made suitable for Mac users!
// - runs only at the comment page for increased performance 
//
// 3.0 (Nov 5, 2005)
// - script overall revised, some obsolete code removed.
//
// HOW TO USE:
// The script contains two arrays: "textSmileys" and "realSmileys". The items 
// present in the array "textSmileys" will be automatically replaced with the 
// corresponding images in the array "realSmileys". You can modify the arrays
// as you see fit, as long as both arrays keep the exact same number of items. 
//
// For example, suppose you want to add some smiley to the script... that would mean
// in "textSmileys" you would add a shorthand like ":some_smiley:" or {somesmiley}, 
// and in "realSmileys" you would add it's url: "http://www.dude.com/some_smiley.gif".
//
// SETTINGS:
// - "maxNumberOfSmileysPerRow": number of smileys that will be displayed in one row.
// Smileys above that number will automatically be added to a new line. 10 by default. 
// - "buttonSize": size of the smiley buttons in pixels. 30 px by default.
//
// AVAILABILITY: 
// The script has been tested in the latest versions of IE, Netscape,
// Mozilla and Opera (Windows 98).
// 
function typeSmiley(sSmiley) {
  if (document.getElementsByTagName('textarea')[0].getAttribute('name') == 'body') {
    var editor = document.getElementsByTagName('textarea')[0];
  } else {
    var allTextAreas = document.getElementsByTagName('textarea');
    for (i = 0; i < allTextAreas.length; ++i) {
      if (allTextAreas[i].getAttribute('name') == 'body') {
        var editor = allTextAreas[i];
        break;
      }
    }
  }
  editor.value = editor.value + sSmiley;
}

function replaceTextSmileys() {
  // ***add textual emoticons to the array below
  var textSmileys = new Array(
    ":)",
    ":(",
    //":wink:",
    ":p",
    ":lol:",
    ":mad:",
    //":heartbeat:",
    ":love:",
    ":wave:",
    ":sunny:",
    ":wha:",
    //":yes:",
    ":sleepy:",
    ":rolleyes:",
    ":lookaround:",
    ":eek:",
    ":confused:",
    ":nono:",
    ":fun:",
    ":goodjob:",
    ":giggle:",
    ":cry:",
    ":shysmile:",
    ":jealous:",
    ":whocares:",
    ":spinning:",
    //":coolman:",
    ":littlekiss:",
    ":laugh:",
    ":clap:",
    ":angry:",
    ":cheers:",
    ":grin:",
    ":frown:",
    ":laughing:",
    ":shocked:",
    ":jump:",
    ":xmas:"
  );
  // *** add the url's from the corresponding images below
  var realSmileys = new Array(
    "/images/smilies/smile.gif",
    "/images/smilies/sad.gif",
    //"/images/smilies/wink.gif",
    "/images/smilies/tongue.gif",
    "/images/smilies/lol.gif",
    "/images/smilies/mad.gif",
    //"/images/smilies/heartbeat.gif",
    "/images/smilies/love.gif",
    "/images/smilies/wave.gif",
    "/images/smilies/sunny.gif",
    "/images/smilies/wha.gif",
    //"/images/smilies/yes.gif",
    "/images/smilies/sleepy.gif",
    "/images/smilies/rolleyes.gif",
    "/images/smilies/lookaround.gif",
    "/images/smilies/eek.gif",
    "/images/smilies/confused.gif",
    "/images/smilies/nono.gif",
    "/images/smilies/fun.gif",
    "/images/smilies/goodjob.gif",
    "/images/smilies/giggle.gif",
    "/images/smilies/cry.gif",
    "/images/smilies/shysmile.gif",
    "/images/smilies/jealous.gif",
    "/images/smilies/whocares.gif",
    "/images/smilies/spinning.gif",
    //"/images/smilies/coolman.gif",
    "/images/smilies/littlekiss.gif",
    "/images/smilies/laugh.gif",
    "/images/smilies/clap.gif",
    "/images/smilies/angry.gif",
    "/images/smilies/cheers.gif",
    "/images/smilies/grin.gif",
    "/images/smilies/frown.gif",
    "/images/smilies/laughing.gif",
    "/images/smilies/shocked.gif",
    "/images/smilies/jump.gif",
    "/images/smilies/xmas.gif"
  );
  // *** number of smileys that will be displayed per row
  var maxNumberOfSmileysPerRow = 5;
  // *** button size in pixels
  //var buttonSize = 50;
  // preloading images
  var preloadedImages = new Array(realSmileys.length);
  //var smileyHeights = new Array(realSmileys.length);
  //var smileyWidths = new Array(realSmileys.length);
  for (i = 0; i < preloadedImages.length; ++i) {
    preloadedImages[i] = new Image();
    preloadedImages[i].src = realSmileys[i];
    //smileyHeights[i] = preloadedImages[i].height;
    //smileyWidths[i] = preloadedImages[i].width;
  }
  
  var messagebody = document.getElementById('messagebody');
  // Store HTML as string rather than editing the element inplace..
  if (messagebody != null) {
    var replacementHTML = messagebody.innerHTML;
    //alert('text to search: ' + replacementHTML);
    for (var n=0; n < textSmileys.length; ++n) {
      var indx = replacementHTML.indexOf(textSmileys[n]);
      var offset = 0;
      while (indx != -1) {
        //alert('found smiley: "' + textSmileys[n] + '" at index ' + indx + ':\n' +
        //      replacementHTML.substring(indx-5, indx+textSmileys[n].length+10));
        var smileyHTML = '<img src="' + realSmileys[n] + '" alt="' + textSmileys[n] + '" />';
        var textSmileyRegex = eval('/'+textSmileys[n].replace(/([\:\(\)])/g,"\\$1")+'/');
        //alert('regex created: ' + textSmileyRegex);
        replacementHTML = replacementHTML.substring(0, offset)
                          + replacementHTML.substring(offset).replace(textSmileyRegex, smileyHTML);
        offset = indx + smileyHTML.length;
        indx = replacementHTML.indexOf(textSmileys[n], offset);
        //alert('new offset to search from: ' + offset);
        //alert('new html:\n' + replacementHTML);
        //alert('so searching from:\n' + replacementHTML.substring(offset));
      }
    }
    messagebody.innerHTML = replacementHTML;
  }
  
  if (document.getElementById('idSmileyBar')) {
    var smileyCollection = new Array(realSmileys.length);
    var smileyBar = '';
    
    for (var i = 0; i < smileyCollection.length; ++i) {
      smileyCollection[i] = '<button type="button" value="" ' +
        'style="padding:2px; ' +
        //'width: ' + smileyWidths[i] + 'px; ' +
        //'height: ' + smileyHeights[i] + 'px;' +
        '" onclick="javascript:typeSmiley(\' ' + 
        textSmileys[i] + '\'); return false;">' +
        '<img src=\"' + realSmileys[i] +
        '" alt="' + textSmileys[i] + '"></button>';
    }
    
    for (var i = 0; i < smileyCollection.length; ++i) {
      if (i != 0)
        if ( (i/maxNumberOfSmileysPerRow).toString().indexOf('.') == -1) 
          smileyBar = smileyBar + '<br />';
      smileyBar = smileyBar + smileyCollection[i];
    }
    // add SmileyBar
    smileyBarHtml = '<br /><b>Add Emoticons</b><br /><font style="font-size: xx-small">' + 
      'Add emoticons by clicking them!</font><br />' + 
      smileyBar + '<br /><br />';
    obj2 = document.getElementById('idSmileyBar');
    obj2.innerHTML = smileyBarHtml;
  }
}

if (document.getElementById('idSmileyBar') ||
    document.getElementById('messagebody'))
  replaceTextSmileys();
