package conf::mail_conf;

use Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
        $SMTP
        $FROM
);

## Mailing configuration ##
our $SMTP = 'mailhost.zen.co.uk';
our $FROM = 'Mailing script <zen46691@zen.co.uk>';