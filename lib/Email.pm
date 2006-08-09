package Email;

use strict;

use lib '../lib';

use warnings qw( all );

no warnings qw( uninitialized );

use CarpeDiem;

use Exporter;

our @EXPORT = qw( send_email validate_email create_html_from_text );




sub send_email(@) {
  
  require Mail::Sendmail; # qw( sendmail %mailcfg ); # time_to_date ); # $address_rx );
  require MIME::QuotedPrint; # qw( encode_qp );
  use vars qw( $SMTP $FROM );
  use conf::mail_conf qw( $SMTP $FROM );
  
  #$mailcfg{smtp} = [qw(mailhost.zen.co.uk smtp.myrealbox.com localhost)];
  #$mailcfg{from} = 'Mailing script <zen46691@zen.co.uk>';
  #$mailcfg{Sender} = 'Mailing scripty <zen46691@zen.co.uk>';
  my %mail;
  $mail{smtp} = $SMTP;
  $mail{from} = $FROM;
  #$mail{Date} = Mail::Sendmail::time_to_date( time() - 86400 );
  #$mail{'X-Mailer'} = "Mail::Sendmail version $Mail::Sendmail::VERSION";
  #$mail{'X-custom'} = 'My custom additionnal header';
  
  
  my $config = { @_ };
  
  if ((defined $config->{HtmlMessage}) and (defined $config->{TextMessage})) {
    
    # Set multipart html & text message body
    
    
    
    my $boundary = "====" . time() . "====";
    
    $mail{'Content-Type'} = "multipart/alternative; boundary=\"$boundary\"";
    
    my $plain = MIME::QuotedPrint::encode_qp $config->{TextMessage};
    
    my $html = MIME::QuotedPrint::encode_qp $config->{HtmlMessage};
    
    $boundary = '--'.$boundary;
    
    $mail{Message} = <<END_OF_BODY;
$boundary
Content-Type: text/plain; charset="iso-8859-1"
Content-Transfer-Encoding: quoted-printable

$plain

$boundary
Content-Type: text/html; charset="iso-8859-1"
Content-Transfer-Encoding: quoted-printable

$html

$boundary--
END_OF_BODY
    
  } elsif (defined $config->{HtmlMessage}) {
    
    # Set html message but warn about lack of text component
    
    warn "Sending HTML ONLY, which will only be displayed correctly "
       . "by HTML-capable Mail clients.. Not a great option!";
    
    $mail{'Content-Type'} = 'text/html; charset="iso-8859-1"',
    $mail{Message} = $config->{HtmlMessage};
    
  } else {
    
    # Set simple text message body
    
    $mail{'Content-Type'} = 'text/plain; charset="iso-8859-1"';
    $mail{Message} = $config->{TextMessage};
  
  }
  
  delete $config->{TextMessage};
  delete $config->{HtmlMessage};
  
  # only addresses are extracted from Bcc, real names disregarded
  # Cc will appear in the header. (Bcc will not)
  foreach (keys %$config) {
    #print STDERR "key: $_\n";
    if (/To|Cc|Bcc/i) {
      if (ref($config->{$_}) ne 'ARRAY') {
        croak "You must pass send_email() an array reference "
            . "for the '$_' field! Please thank you very much.";
      }
      $mail{$_} = join ', ', @{$config->{$_}};
    } else {
      $mail{$_} = $config->{$_};
    }
  }
  
  foreach (@{$config->{To}}) {
    my $email = $_;
    $email =~ s/^.+<(\S+)>$/$1/;
    if (!&validate_email($email)) {
      carp "Email '$email' looks unhealthy but i'll send '"
         . $config->{Subject} . "' email to it reagrdless..";
    } # else { carp "Sending to $email"; }
  }
  
  #return 1; #LET'S NOT SEND EMAILS IN DEVELOPMENT
  
  if (Mail::Sendmail::sendmail(%mail)) { return $Mail::Sendmail::log; }
  else { carp "Error sending mail: $Mail::Sendmail::log $Mail::Sendmail::error"; return -1; }

}


sub validate_email($) {
  
  # BUSTY NO LIKE THIS REGEXP - IT LETS ANYTHING PAST!! EVEN pa@paaaa
  #my $word_rx = '[\x21\x23-\x27\x2A-\x2B\x2D\x2F\w\x3D\x3F]+';
  #my $user_rx = $word_rx         # valid chars
  #             .'(?:\.' . $word_rx . ')*' # possibly more words preceded by a dot
  #             ;
  #my $dom_rx = '\w[-\w]*(?:\.\w[-\w]*)*'; # less valid chars in domain names
  #my $ip_rx = '\[\d{1,3}(?:\.\d{1,3}){3}\]';
  #my $address_rx = '((' . $user_rx . ')\@(' . $dom_rx . '|' . $ip_rx . '))';
  #my $address_rx = $user_rx . '\@(?:' . $dom_rx . '|' . $ip_rx . ')';
  
  # THIS ONE IS BETTER!
  #my $address_rx = '(([a-z0-9_\.-]+)\@((?:[a-z0-9]+(?:[\.\-][a-z0-9]+)*\.)+[a-z]{2,7}))';
  # We don't need to capture anything..
  #my $address_rx = '[a-z0-9_\.-]+\@(?:[a-z0-9]+(?:[\.\-][a-z0-9]+)*\.)+[a-z]{2,7}';
  require Data::Validate::Email; # qw( is_email );
  return Data::Validate::Email::is_email($_[0]);
  
}


sub create_html_from_text($) {
  
  my $textmessage = shift;
  # Simple HTML Conversion
  #use HTML::Entities 'encode_entities';
  #my $htmlmessage = HTML::Entities::encode_entities($textmessage);
  #$htmlmessage =~ s!\n\n!\n\n<p>!og;
  #$htmlmessage =~ s!\n!<br />\n!og;
  #$htmlmessage = "<html><p><strong>" . $htmlmessage . "</strong></p></html>";
  require HTML::FromText; # qw( text2html );
  return HTML::FromText::text2html(
    $textmessage,
    metachars => 1, # All characters that are unsafe for HTML display
                    # will be encoded using HTML::Entities::encode_entities().
    urls      => 1, # Replaces URLs with links.
    email     => 1, # Replaces email addresses with mailto: links.
    bold      => 1, # Replaces text surrounded by asterisks (*)
                    # with the same text surrounded by strong tags.
    lines     => 1, # Preserves line breaks by inserting br tags at the end of each line.
    paras     => 1, # Preserves paragraphs by wrapping them in p tags.
    blockcode => 1, # Convert indented paragraphs block quotes using the blockquote tag
                    # and also preserve line breaks and spaces using br and pre tags.
    bullets   => 1, # Convert bulleted lists into unordered lists (ul).
                    # Bullets can be either an asterisk (*) or a hyphen (-).
    numbers   => 1, # Convert numbered lists into ordered lists (ol).
                    # Numbered lists are identified by numerals.
    underline => 0, # Replaces text surrownded by underscores (_) with the
                    # same text surrounded by span tags with an underline style.
    );
  
}


1;
