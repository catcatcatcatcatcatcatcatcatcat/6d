/*
 Pleas leave this notice.
 DHTML tip message version 1.2 copyright Essam Gamal 2003 (http://migoicons.tripod.com, migoicons@hotmail.com)
 For the original popup script without Textmi modifications see www.dynamicdrive.com
*/

var ua = navigator.userAgent
var ps = navigator.productSub
var dom = (document.getElementById)? 1:0
var ie4 = (document.all&&!dom)? 1:0
var ie5 = (document.all&&dom)? 1:0
var ie6 = (document.all&&dom)? 1:0
var nn4 =(navigator.appName.toLowerCase() == "netscape" && parseInt(navigator.appVersion) == 4)
var nn6 = (dom&&!ie5)? 1:0
var sNav = (nn4||nn6||ie4||ie5)? 1:0
var cssFilters = ((ua.indexOf("MSIE 5.5")>=0||ua.indexOf("MSIE 6")>=0)&&ua.indexOf("Opera")<0)? 1:0
var Style=[],Text=[],Count=0,sbw=0,move=0,hs="",mx,my,scl,sct,ww,wh,obj,sl,st,ih,iw,vl,hl,sv,evlh,evlw,tbody
var HideTip = "eval(obj+sv+hl+';'+obj+sl+'=0;'+obj+st+'=-800')"
var doc_root = ((ie5&&ua.indexOf("Opera")<0||ie4)&&document.compatMode=="CSS1Compat")? "document.documentElement":"document.body"
var PX = (nn6)? "px" :""

function UrlDecode(psEncodeString)
{
  var lsRegExp = /\+/g;
  return unescape(String(psEncodeString).replace(lsRegExp," "));
}

if(sNav) {
  window.onresize = ReloadTip
  document.onmousemove = MoveTip
  if(nn4) document.captureEvents(Event.MOUSEMOVE)
}
if(nn4||nn6) {
  mx = "e.pageX"
  my = "e.pageY"
  scl = "window.pageXOffset"
  sct = "window.pageYOffset"
  if(nn4) {
    obj = "document.TipLayer."
    sl = "left"
    st = "top"
    ih = "clip.height"
    iw = "clip.width"
    vl = "'show'"
    hl = "'hide'"
    sv = "visibility="
  }
  else obj = "document.getElementById('TipLayer')."
}
if(ie4||ie5||ie6) {
  obj = "TipLayer."
  mx = "event.x"
  my = "event.y"
  scl = "eval(doc_root).scrollLeft"
  sct = "eval(doc_root).scrollTop"
  if(ie5) {
    mx = mx+"+"+scl
    my = my+"+"+sct
  }
}
if(ie4||dom){
  sl = "style.left"
  st = "style.top"
  ih = "offsetHeight"
  iw = "offsetWidth"
  vl = "'visible'"
  hl = "'hidden'"
  sv = "style.visibility="
}
if(ie4||ie5||ps>=20020823) {
  ww = "eval(doc_root).clientWidth"
  wh = "eval(doc_root).clientHeight"
}
else {
  ww = "window.innerWidth"
  wh = "window.innerHeight"
  evlh = eval(wh)
  evlw = eval(ww)
  sbw=15
}

function applyCssFilter(){
  if(cssFilters&&FiltersEnabled) {
    var dx = " progid:DXImageTransform.Microsoft."
    TipLayer.style.filter = "revealTrans()"+dx+"Fade(Overlap=1.00 enabled=0)"+dx+"Inset(enabled=0)"+dx+"Iris(irisstyle=PLUS,motion=in enabled=0)"+dx+"Iris(irisstyle=PLUS,motion=out enabled=0)"+dx+"Iris(irisstyle=DIAMOND,motion=in enabled=0)"+dx+"Iris(irisstyle=DIAMOND,motion=out enabled=0)"+dx+"Iris(irisstyle=CROSS,motion=in enabled=0)"+dx+"Iris(irisstyle=CROSS,motion=out enabled=0)"+dx+"Iris(irisstyle=STAR,motion=in enabled=0)"+dx+"Iris(irisstyle=STAR,motion=out enabled=0)"+dx+"RadialWipe(wipestyle=CLOCK enabled=0)"+dx+"RadialWipe(wipestyle=WEDGE enabled=0)"+dx+"RadialWipe(wipestyle=RADIAL enabled=0)"+dx+"Pixelate(MaxSquare=35,enabled=0)"+dx+"Slide(slidestyle=HIDE,Bands=25 enabled=0)"+dx+"Slide(slidestyle=PUSH,Bands=25 enabled=0)"+dx+"Slide(slidestyle=SWAP,Bands=25 enabled=0)"+dx+"Spiral(GridSizeX=16,GridSizeY=16 enabled=0)"+dx+"Stretch(stretchstyle=HIDE enabled=0)"+dx+"Stretch(stretchstyle=PUSH enabled=0)"+dx+"Stretch(stretchstyle=SPIN enabled=0)"+dx+"Wheel(spokes=16 enabled=0)"+dx+"GradientWipe(GradientSize=1.00,wipestyle=0,motion=forward enabled=0)"+dx+"GradientWipe(GradientSize=1.00,wipestyle=0,motion=reverse enabled=0)"+dx+"GradientWipe(GradientSize=1.00,wipestyle=1,motion=forward enabled=0)"+dx+"GradientWipe(GradientSize=1.00,wipestyle=1,motion=reverse enabled=0)"+dx+"Zigzag(GridSizeX=8,GridSizeY=8 enabled=0)"+dx+"Alpha(enabled=0)"+dx+"Dropshadow(OffX=3,OffY=3,Positive=true,enabled=0)"+dx+"Shadow(strength=3,direction=135,enabled=0)"
  }
}

function stmu_test(pic, text, forumposts, photographer, referrals, moderator, photographercount) {

  var img="";

        var txt = '<div style="line-height:1.1em;margin:0 4px;">'+text+'</div>';

  var style="";

  style=' style="border-bottom:1px solid #000;background-color:#333;"';

  img = '<img src='+pic+' width=100 height=100 style="background-color:#333;margin:10px;"><br/>';
        
  if (photographer==1)
  txt += (txt.length>0?"<br/>":"")+"<img src=\"/images/icons/tipMessage/photo.gif\"> <font style=\"clear:left;padding-left:5px;padding-bottom:5px;padding-top:5px;font-size:1.0em;\"><strong>Photographer</strong></font>";

  if (photographer==1&&photographercount>0)
  txt += (txt.length>0?"<br/>":"")+"<img src=\"/images/icons/tipMessage/bullet.gif\"><font style=\"clear:left;padding-left:5px;padding-bottom:5px;padding-top:5px;\"><strong><i>Taken "+photographercount+" pics</i></strong></font>";

  if (moderator==1)
  txt += (txt.length>0?"<br/>":"")+"<img src=\"/images/icons/tipMessage/moderator.gif\"><font style=\"clear:left;padding-left:5px;padding-bottom:5px;padding-top:5px;\"><strong>Moderator</strong></font>";

  if (forumposts)
  txt += (txt.length>0?"<br/>":"")+"<img src=\"/images/icons/tipMessage/forum.gif\"><font style=\"clear:left;padding-left:5px;padding-bottom:5px;padding-top:5px;\"><b>"+forumposts+" Forum posts</b></font>";

  if (referrals)
  txt += (txt.length>0?"<br/>":"")+"<img src=\"/images/icons/tipMessage/bullet.gif\"> <font style=\"clear:left;padding-left:5px;padding-bottom:5px;padding-top:5px;\"><b>Told "+referrals+" friends</b></font>";
 
  return stm(['',img+txt]);

}

function stmu(pic, profilename) {

  var img="";

    var txt = "";

  var style="";
 
  style=' style="border-bottom:1px solid #000;background-color:#333;"';

  img = "<img src="+pic+" width=100 height=100 style=background-color:#FFF;>";

  return stm(['',img]);

}

function stma(pic) {
  var img="<img src="+pic+" width=100 height=100>";
  return stm(['',img]);
}

function stmn() {
  return stm(['','<img src=/images/logos/logo.gif width=168 height=61>']);
}

function stt(text){
  var s1=["white","white","#FFFFFF","#FF3399","","","","","","","","","","","auto","",1,3,10,10,"","","","",""];
  return stmx(['',UrlDecode(text)],s1);
}

function stm(t1) {
  var s1=["white","white","#FFFFFF","#333","","","","","","","","","","",100,"",1,0,10,10,"","","","",""];
  return stmx(t1,s1);
}
function stmx(t,s1) {
  s=s1;
  if(sNav) {
    if(t.length<2||s.length<25) {

  }
    else {
      t[0]=UrlDecode(t[0]);
      t[1]=UrlDecode(t[1]);
    var ab = "" ;var ap = ""
    var titCol = (s[0])? "COLOR='"+s[0]+"'" : ""
    var txtCol = (s[1])? "COLOR='"+s[1]+"'" : ""
    var titBgCol = (s[2])? "BGCOLOR='"+s[2]+"'" : ""
    var txtBgCol = (s[3])? "BGCOLOR='"+s[3]+"'" : ""
    var titBgImg = (s[4])? "BACKGROUND='"+s[4]+"'" : ""
    var txtBgImg = (s[5])? "BACKGROUND='"+s[5]+"'" : ""
    var titTxtAli = (s[6] && s[6].toLowerCase()!="left")? "ALIGN='"+s[6]+"'" : "";
    var txtTxtAli = (s[7] && s[7].toLowerCase()!="left")? "ALIGN='"+s[7]+"'" : "";
    var add_height = (s[15])? "HEIGHT='"+s[15]+"'" : ""
    if(!s[8])  s[8] = "Verdana,Arial,Helvetica"
    if(!s[9])  s[9] = "Verdana,Arial,Helvetica"
    if(!s[12]) s[12] = 1
    if(!s[13]) s[13] = 1
    if(!s[14]) s[14] = 200
    if(!s[16]) s[16] = 0
    if(!s[17]) s[17] = 0
    if(!s[18]) s[18] = 10
    if(!s[19]) s[19] = 10
    hs = s[11].toLowerCase()
    if(ps==20001108){
    if(s[2]) ab="STYLE='border:"+s[16]+"px solid"+" "+s[2]+"'"
    ap="STYLE='padding:"+s[17]+"px "+s[17]+"px "+s[17]+"px "+s[17]+"px'"}
    var title=(t[0]||hs=="sticky")?"<TABLE WIDTH='100%' BORDER='0' CELLPADDING='"+s[17]+"' CELLSPACING='0'><TR><TD "+titTxtAli+"><FONT SIZE='"+s[12]+"' FACE='"+s[8]+"' "+titCol+"><B>"+t[0]+"</B></FONT></TD></TR></TABLE>" : ""
    var txt="<TABLE "+titBgImg+" "+ab+" WIDTH='"+s[14]+"' BORDER='0' CELLPADDING='"+s[16]+"' CELLSPACING='0' "+titBgCol+" ><TR><TD>"+title+"<TABLE WIDTH='100%' "+add_height+" BORDER='0' CELLPADDING='"+s[17]+"' CELLSPACING='0' "+txtBgCol+" "+txtBgImg+"><TR><TD "+txtTxtAli+" "+ap+" VALIGN='top'><FONT SIZE='"+s[13]+"' FACE='"+s[9]+"' "+txtCol +">"+t[1]+"</FONT></TD></TR></TABLE></TD></TR></TABLE>"
    if(nn4) {
      with(eval(obj+"document")) {
        open()
        write(txt)
        close()
      }
    }
    else eval(obj+"innerHTML=txt")
    tbody = {
      Pos:s[10].toLowerCase(),
      Xpos:s[18],
      Ypos:s[19],
      Transition:s[20],
      Duration:s[21],
      Alpha:s[22],
      ShadowType:s[23].toLowerCase(),
      ShadowColor:s[24],
      Width:parseInt(eval(obj+iw)+3+sbw)
    }
    if(ie4) {
      TipLayer.style.width = s[14]
      tbody.Width = s[14]
    }
    Count=0
    move=1
   }
  }
}

function MoveTip(e) {
  if(move) {
    var X,Y,MouseX = eval(mx),MouseY = eval(my); tbody.Height = parseInt(eval(obj+ih)+3)
    tbody.wiw = parseInt(eval(ww+"+"+scl)); tbody.wih = parseInt(eval(wh+"+"+sct))
    switch(tbody.Pos) {
      case "left" : X=MouseX-tbody.Width-tbody.Xpos; Y=MouseY+tbody.Ypos; break
      case "center": X=MouseX-(tbody.Width/2); Y=MouseY+tbody.Ypos; break
      case "float": X=tbody.Xpos+eval(scl); Y=tbody.Ypos+eval(sct); break
      case "fixed": X=tbody.Xpos; Y=tbody.Ypos; break
      default: X=MouseX+tbody.Xpos; Y=MouseY+tbody.Ypos
    }

    if(tbody.wiw<tbody.Width+X) X = tbody.wiw-tbody.Width
    if(tbody.wih<tbody.Height+Y+sbw) {
      if(tbody.Pos=="float"||tbody.Pos=="fixed")
        Y = tbody.wih-tbody.Height-sbw
      else Y = MouseY-tbody.Height - 10
    }
    if(X<0) X=0
    eval(obj+sl+"=X+PX;"+obj+st+"=Y+PX")
    ViewTip()
  }
}


function ViewTip() {
    Count++
  if(Count == 1) {
    eval(obj+sv+vl)
    if(hs == "sticky") move=0
    }
}

function stickyhide() {
  eval(HideTip)
}

function ReloadTip() {
   if(nn4&&(evlw!=eval(ww)||evlh!=eval(wh))) location.reload()
   else if(hs == "sticky") eval(HideTip)
}

function htm() {
  if(sNav) {
    if(hs!="keep") {
      move=0;
      if(hs!="sticky") eval(HideTip)
    }
  }
}



