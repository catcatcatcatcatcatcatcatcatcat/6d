/*
 * To hook up a text field and button to have a popup calendar, have this html:
 * 
 *   <input type="text" id="date" name="date"/>
 *   <a href="#" id="date_trigger"><img src="images/calendar-21x18.gif" width="21" height="18" alt="Popup Calendar"/></a>
 *
 * and then have an init function for your form:
 *
 *   function my_page_init() {
 *      YAHOO.ybz.popup_calendar.setup_calendar("date","date_trigger");
 *   }
 *
 *   YAHOO.util.Event.addListener(window,"load",my_page_init);
 *
 * you can have as many popup calendars on the page as you need.  Just
 * add the html and a new call to setup_calendar in your init function
 * for each popup calendar you need.
 * 
 * setup_calendar takes a 3rd, optional parameter: the title for the
 * calendar.  If omitted, the title will be set to "Select A Date".
 */

YAHOO.namespace("YAHOO.ybz.popup_calendar");

YAHOO.ybz.popup_calendar._zero_pad = function(n, total_digits) { 
	n = n.toString(); 
	var pd = ''; 
	if (total_digits > n.length) { 
		for (i=0; i < (total_digits-n.length); i++) { 
			pd += '0'; 
		} 
	} 
	return pd + n.toString(); 
}

YAHOO.ybz.popup_calendar.format_date = function(year,month,day) {
	year  = YAHOO.ybz.popup_calendar._zero_pad(year,4); 
	month = YAHOO.ybz.popup_calendar._zero_pad(month,2); 
	day   = YAHOO.ybz.popup_calendar._zero_pad(day,2);
	return year + "-" + month + "-" + day;
}

YAHOO.ybz.popup_calendar._on_calendar_select = function(type,args,obj) {
	var dates = args[0]; 
	var date  = dates[0];
	var calendar_container = document.getElementById('calendar_container');
	if(calendar_container.style.display!='none') {
		obj.date_field.value = YAHOO.ybz.popup_calendar.format_date(date[0],date[1],date[2]);
		YAHOO.ybz.popup_calendar.calendar.hide();
		obj.date_field.focus();
	}
	else {
		if (YAHOO.ybz.popup_calendar._parse_date(obj.date_field.value)!=undefined) {
			obj.date_field.value = YAHOO.ybz.popup_calendar.format_date(date[0],date[1],date[2]);
		}
	}
};

YAHOO.ybz.popup_calendar._parse_date = function(date_str) {
	var parsed_date = date_str.split ("-");
	if (parsed_date.length != 3) return undefined;
	var day, month, year;
	year = parseInt(parsed_date[0],10);
	month = parseInt(parsed_date[1],10);
	day = parseInt(parsed_date[2],10);
	if (isNaN(year) || isNaN(month) || isNaN(day)) return undefined;
	var date = new Date(year,month-1,day);
	if (month-1 != date.getMonth()) return undefined;
	if (day != date.getDate()) return undefined;
	if (year != date.getFullYear()) return undefined;

	return date;
};

YAHOO.ybz.popup_calendar._popup_calendar = function(e) {

	YAHOO.util.Event.stopPropagation(e);
	
	var calendar_container = document.getElementById('calendar_container');

	// If you are clicking to bring up a different calendar
	// when one is already displayed, hide the displayed one
	// and then render the new one.
	
	if (calendar_container.style.display!='none' && this.date_field.id!=YAHOO.ybz.popup_calendar.calendar.date_field.id) {
		YAHOO.ybz.popup_calendar.calendar.hide();
	}

	if (calendar_container.style.display=='none') {
		YAHOO.ybz.popup_calendar.calendar.date_field=this.date_field;

		var date = YAHOO.ybz.popup_calendar._parse_date(this.date_field.value);
        if (date==undefined) {
        	date = new Date();
        }

		YAHOO.ybz.popup_calendar.calendar.select(date);
		YAHOO.ybz.popup_calendar.calendar.cfg.setProperty("pagedate", (date.getMonth()+1) + "/" + date.getFullYear());
		YAHOO.ybz.popup_calendar.calendar.cfg.setProperty("title", this.calendar_title);
		
		YAHOO.ybz.popup_calendar.calendar.render();

		var button_position = YAHOO.util.Dom.getXY(this);
		var button_height = YAHOO.util.Dom.get(this).offsetHeight;
		calendar_container.style.top  = "" + (button_position[1]+button_height+2) + "px";
		calendar_container.style.left = "" + (button_position[0]+2) + "px";

		YAHOO.ybz.popup_calendar.calendar.show();
	}
	else {
		YAHOO.ybz.popup_calendar.calendar.hide();
		this.focus();
	}
};

YAHOO.ybz.popup_calendar._on_mouseover_trigger = function(e) {
	document.body.style.cursor = 'pointer';
};

YAHOO.ybz.popup_calendar._on_mouseout_trigger = function(e) {
	document.body.style.cursor = 'default';
};

YAHOO.ybz.popup_calendar._calendar_init = function() {
	var calendar_container = document.getElementById("calendar_container");
	if (calendar_container==null) {
		calendar_container = document.createElement("div");
		calendar_container.setAttribute('id','calendar_container');
		calendar_container.style.display = "none";
		calendar_container.style.position = "absolute";
		calendar_container.style.zIndex = "1000";
		document.body.appendChild(calendar_container);
	}
	
	YAHOO.ybz.popup_calendar.calendar = new YAHOO.widget.Calendar("calendar","calendar_container",{ close: true });
	YAHOO.ybz.popup_calendar.calendar.selectEvent.subscribe(YAHOO.ybz.popup_calendar._on_calendar_select,YAHOO.ybz.popup_calendar.calendar);
};

YAHOO.ybz.popup_calendar.on_button_click = function(e) {
	return false;
}

YAHOO.ybz.popup_calendar.setup_calendar = function(date_field,button,title) {
	if (typeof date_field == 'string') {
		date_field = document.getElementById(date_field);
	}
	if (typeof button == 'string') {
		button = document.getElementById(button);
	}
	
	YAHOO.util.Event.addListener(button,"mouseover",YAHOO.ybz.popup_calendar._on_mouseover_trigger);
	YAHOO.util.Event.addListener(button,"mouseout",YAHOO.ybz.popup_calendar._on_mouseout_trigger);

	button.href = "#";
	button.onclick = YAHOO.ybz.popup_calendar.on_button_click;
	button.date_field = date_field;
	
	if (title!=undefined) {
		button.calendar_title = title;
	}
	else {
		button.calendar_title = "Select A Date";
	}
	YAHOO.util.Event.addListener(button, "click", YAHOO.ybz.popup_calendar._popup_calendar);
};

YAHOO.ybz.popup_calendar._on_document_body_click = function(e) {

	// Hide the calendar if something else was clicked.
	
	var calendar_container = document.getElementById('calendar_container');
	if (calendar_container.style.display!='none') {
		var target = YAHOO.util.Event.getTarget(e);
		if (!YAHOO.util.Dom.isAncestor(calendar_container,target)) {
			YAHOO.ybz.popup_calendar.calendar.hide();
		}
	}
};

YAHOO.util.Event.addListener(window, "load", YAHOO.ybz.popup_calendar._calendar_init);
YAHOO.util.Event.addListener(document.body, "click", YAHOO.ybz.popup_calendar._on_document_body_click);

