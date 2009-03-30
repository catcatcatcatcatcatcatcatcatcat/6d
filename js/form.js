/* designed for form text input fields so they go a nice colour
   when users have them focussed.. */
function focusify(what) {
        if (!what.className) {
                what.className = 'focus';
                /* little idea to try to sort out the option elements - IE will not
                   apply a style to them in time to be displayed when you open the
       select list..  This was trying to fix that by looping over each
       option element and changing it, but that didn't work either! :(
       so given up now and not changing the selects! */
                /*for (var i=0, option; option = what.options[i]; i++) {*/
                /*        option.className = 'focus';*/
                /*}*/
        } else {
                what.className = what.className + '-focus';
        }
        //alert(what.className)
}
function blurify(what) {
        if (what.className == 'focus') {
                what.className = '';
        } else {
                what.className = what.className.replace(/-focus$/,'');
        }
        //alert(what.className)
}
/* trying to change checkbox styles - this was a basic
   toggle and after realising that changing textbox style
   was a bitch, i've laid this idea to rest.. */
function checkify(what) {
        if (!what.className) {
                what.className = 'checked';
        } else if (what.className == 'checked') {
                what.className = '';
        } else if (what.className.match(/-checked$/)) {
                what.className = what.className.replace(/-checked$/,'');
        } else {
                what.className = what.className + '-checked';
        }
}

/* function written for divs that surroundform input fields
   and have posible class names 'input' and 'input-active' in
   the CSS which add a nice little arrow by the last selected..
   NB. all input fields to have this work on them must have ids
   'input1', 'input2' etc. - this baby will stop when it doesn't
   find one in that sequence!  simple, but that makes it faster! */
function choose(chosen) {
        var div;
        var i = 1;
        for (i=1; ;i++) {
                div = document.getElementById("input" + i);
                if (div != null) {
                        //alert('whooo for ' + i);
                        div.className = 'input';
                } else {
                        break;
                }
        }
        if (chosen != null) {
                div = document.getElementById("input" + chosen);
                if (div != null) {
                        div.className = 'input-active';
                }
        }
}
