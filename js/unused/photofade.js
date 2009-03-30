// Fade effect only in IE; degrades gracefully
// Set slideShowSpeed (milliseconds)
var slideShowSpeed = 3000
// Duration of crossfade (seconds)
var crossFadeDuration = 2
var t1
var t2
var j1 = 0
var j2 = 0
var preLoad1 = new Array()
var preLoad2 = new Array()

function loadImages1(){
  
  for (i1 = 0; i1<loadImages1.arguments.length; i1++){
      preLoad1[i1] = new Image()
      preLoad1[i1].src = loadImages1.arguments[i1]
  }
}

function loadImages2(){
  
  for (i2 = 0; i2<loadImages2.arguments.length; i2++){
      preLoad2[i2] = new Image()
      preLoad2[i2].src = loadImages2.arguments[i2]
  }
}

function runSlideShow1(){
  var num_pics1 = preLoad1.length
    
  if (document.all){
      document.images.SlideShow1.style.filter="blendTrans(duration=crossFadeDuration)"
      document.images.SlideShow1.filters.blendTrans.Apply()
  }
  
  document.images.SlideShow1.src = preLoad1[j1].src
  if (document.all){
      document.images.SlideShow1.filters.blendTrans.Play()
  }
  j1 = j1 + 1
  if (j1 > (num_pics1-1)) j1=0
  t1 = setTimeout('runSlideShow1()', slideShowSpeed)
}

function runSlideShow2(){
  var num_pics2 = preLoad2.length
    
  if (document.all){
      document.images.SlideShow2.style.filter="progid:DXImageTransform.Microsoft.AlphaImageLoader"
                + "(src='" + preLoad2[j2].src + "', sizingMethod='scale')\n";
      /*document.images.SlideShow2.style.filter += " blendTrans(duration=crossFadeDuration)"
      document.images.SlideShow2.filters.blendTrans.Apply()*/
  }
  
  
  if (document.all){
      //document.images.SlideShow2.filters.blendTrans.Play()
  }
  else {
          document.images.SlideShow2.src = preLoad2[j2].src
  }
  j2 = j2 + 1
  if (j2 > (num_pics2-1)) j2=0
  t2 = setTimeout('runSlideShow2()', slideShowSpeed)
}
