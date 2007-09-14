package conf::mail_conf;

use Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
        $SMTP
        $FROM
);

## Mailing configuration ##
our $SMTP = 'localhost'; #'mailhost.zen.co.uk';
our $FROM = 'Mailing script <noreply@backpackingbuddies.com>';
