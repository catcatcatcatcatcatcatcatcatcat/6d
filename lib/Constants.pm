package Constants;

use strict;

use warnings qw( all );

no  warnings qw( uninitialized );


use constant STATUS_OK => '1';
use constant STATUS_ERROR => '-1';
use constant STATUS_REQUIRE_LOGIN => '-2';

use constant PROFILE_SEARCH_MAX_RESULTS => 1000;


1;