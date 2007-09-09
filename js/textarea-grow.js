
var max_cols = 80; /* DEFAULT */
var max_rows = 45; /* DEFAULT */

/* Make textareas grow automagically as the user types */
fixup_textarea_size = function(ta, max_cols, max_rows) {
  
  /* On first call to this fcn, setup the starting values */
  /* for the min rows and cols as the initial values */
  
  if (ta.min_cols == undefined) {
    ta.min_cols = ta.cols;
  }
  min_cols = ta.min_cols;
  if (ta.min_rows == undefined) {
    ta.min_rows = ta.rows;
  }
  min_rows = ta.min_rows;
  
  /* Use the default max values if they're not defined in this call.. */
  if (max_cols == undefined)
    max_cols = MAX_COLS;
  if (max_rows == undefined)
    max_rows = MAX_ROWS;
  
  
  var text_length = ta.value.length;
  var num_rows = 0;
  /* Split the textarea value at each linebreak. */
  var lines = ta.value.split("\n");
  
  for (var ii=0; ii <= lines.length-1; ii++) {
    /* Iterate through the array for each element in the
     * array we add 1 row to the TEXTAREA..
     */
    num_rows++;
    if (lines[ii].length > max_cols-5) {
      /* Within each element in our array, determine whether
       * the length of text is greater that our max_cols value.
       * If so, then we need another row for each time that the
       *  length is greater than the max_cols value.
       */
      num_rows += Math.floor(lines[ii].length/max_cols)
    }
  }
  
  if (text_length == 0) {
    /* If there is no text in the TEXTAREA we default to our
     * minimum values.
     */
    ta.cols = min_cols;
    ta.rows = min_rows;
  } else {
    /* If there is only 1 row, then all we need to determine is
     * how many COLS we need.  It will be somewhere between our
     * min_cols & max_cols values.
     */
    if (num_rows <= 1) {
      ta.rows = min_rows;
      ta.cols = (text_length % max_cols) + 1 >= min_cols 
             ? ((text_length % max_cols) + 1) 
             : min_cols ;
    } else {
      /* If there is more than 1 row then we immediately
       * default to our max_cols value, and then determine
       * how many ROWS we need.
       */
      num_rows++; /* Up the number of rows so we have one spare always */
      ta.cols = max_cols;
      ta.rows = (num_rows > max_rows ? max_rows :
                  (num_rows < min_rows-1 ? min_rows :
                    num_rows));
    }
  }
}
