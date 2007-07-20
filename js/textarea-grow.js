
var MIN_COLS;
var MIN_ROWS;
var MAX_COLS = 80; /* DEFAULT */
var MAX_ROWS = 45; /* DEFAULT */

/* Make textareas grow automagically as the user types */
fixup_textarea_size = function(ta, max_cols, max_rows) {
  
  /* On first call to this fcn, setup the starting values */
  
  /* TODO: We should restrict each of these to every element.. not
   * to global vars for min which will be shared by all textareas */
  
  if (MIN_COLS == undefined) {
    if (ta.cols != undefined)
      MIN_COLS = ta.cols;
    else
      MIN_COLS = 15; /* DEFAULT */
  }
  if (MIN_ROWS == undefined) {
    if (ta.rows != undefined)
      MIN_ROWS = ta.rows;
    else
      MIN_ROWS = 3; /* DEFAULT */
  }
  
  /* Override the max values if they're defined in this call.. */
  if (max_cols != undefined)
    MAX_COLS = max_cols;
  if (max_rows != undefined)
    MAX_ROWS = max_rows;
  
  
  var text_length = ta.value.length;
  var num_rows = 0;
  /* Split the textarea value at each linebreak. */
  var lines = ta.value.split("\n");
  
  for (var ii=0; ii <= lines.length-1; ii++) {
    /* Iterate through the array for each element in the
     * array we add 1 row to the TEXTAREA..
     */
    num_rows++;
    if (lines[ii].length > MAX_COLS-5) {
      /* Within each element in our array, determine whether
       * the length of text is greater that our MAX_COLS value.
       * If so, then we need another row for each time that the
       *  length is greater than the MAX_COLS value.
       */
      num_rows += Math.floor(lines[ii].length/MAX_COLS)
    }
  }
  
  if (text_length == 0) {
    /* If there is no text in the TEXTAREA we default to our
     * minimum values.
     */
    ta.cols = MIN_COLS;
    ta.rows = MIN_ROWS;
  } else {
    /* If there is only 1 row, then all we need to determine is
     * how many COLS we need.  It will be somewhere between our
     * MIN_COLS & MAX_COLS values.
     */
    if (num_rows <= 1) {
      ta.rows = MIN_ROWS;
      ta.cols = (text_length % MAX_COLS) + 1 >= MIN_COLS 
             ? ((text_length % MAX_COLS) + 1) 
             : MIN_COLS ;
    } else {
      /* If there is more than 1 row then we immediately
       * default to our MAX_COLS value, and then determine
       * how many ROWS we need.
       */
      num_rows++; /* Up the number of rows so we have one spare always */
      ta.cols = MAX_COLS;
      ta.rows = (num_rows > MAX_ROWS ? MAX_ROWS :
                  (num_rows < MIN_ROWS-1 ? MIN_ROWS :
                    num_rows));
    }
  }
}
