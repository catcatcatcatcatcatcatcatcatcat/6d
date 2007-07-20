package rusty::Sprint;

use strict;

use lib "..";



use warnings qw( all );

no warnings qw( uninitialized );

#use CarpeDiem;

#use rusty;

#our @ISA = qw(rusty);

use HTML::Entities qw( encode_entities );




sub new() {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  return bless $self, $class;
}




sub tr($@) {
  my $self = shift;
  my $content = join "\n", @_;
  $content =~ s/\n/\n  /g;
  return "<tr>"
       . "\n  " . $content
       . "\n</tr>";
}




sub td($@) {
  my $self = shift;
  my $params = { @_ };
  $params->{content} =~ s/\n/\n  /g;
  return "<td"
       . ($params->{class}   ? " class=\"$params->{class}\""     : "")
       . ($params->{colspan} ? " colspan=\"$params->{colspan}\"" : "")
       . ($params->{rowspan} ? " rowspan=\"$params->{rowspan}\"" : "")
       . ">\n  " . $params->{content}
       . "\n</td>";
}




sub input_text($@) {
  my $self = shift;
  my $params = { @_ };

  # Look! We have defaults..
  # TODO: These should be in a better place really..

  $params->{size} ||= 30;
  $params->{maxlength} ||= 100;

  return '<input type="text" onfocus="pinkify(this)" onblur="greyify(this)"'
       . ($params->{class}     ? " class=\"$params->{class}\""         : "")
       . ($params->{name}      ? " name=\"$params->{name}\""           : "")
       . ($params->{id}        ? " id=\"$params->{id}\""               : "")
       . ($params->{size}      ? " size=\"$params->{size}\""           : "")
       . ($params->{maxlength} ? " maxlength=\"$params->{maxlength}\"" : "")
       . ($params->{value}     ? " value=\""
       . ($params->{value}     ? encode_entities($params->{value})     : "")
       . "\""         : "")
       . " />"
}




sub textarea($@) {
  my $self = shift;
  my $params = { @_ };

  # Look! We have defaults..
  # TODO: These should be in a better place really..

  $params->{cols} ||= 25;
  $params->{rows} ||= 4;
  $params->{maxlength} ||= 255;

  return '<textarea onfocus="pinkify(this)" onblur="greyify(this)"'
       . ($params->{class}     ? " class=\"$params->{class}\""         : "")
       . ($params->{name}      ? " name=\"$params->{name}\""           : "")
       . ($params->{id}        ? " id=\"$params->{id}\""               : "")
       . ($params->{cols}      ? " cols=\"$params->{cols}\""           : "")
       . ($params->{rows}      ? " rows=\"$params->{rows}\""           : "")
       . ($params->{maxlength} ? " maxlength=\"$params->{maxlength}\"" : "")
       . ">"
       . ($params->{value}     ? encode_entities($params->{value})     : "")
       . "</textarea>";
}




sub select($@) {
  my $self = shift;
  my $params = { @_ };
  my $html = "";
  
  $html .= "<select"
         . ($params->{class}     ? " class=\"$params->{class}\""         : "")
         . ($params->{name}      ? " name=\"$params->{name}\""           : "")
         . ($params->{id}        ? " id=\"$params->{id}\""               : "")
         . ($params->{onchange}  ? " onchange=\"$params->{onchange}\""   : "")
         . ">";
  
  foreach my $option ( @{$params->{options}} ) {
    $html  .= "\n  <option value=\""
            . ($option->{id} ? encode_entities($option->{id}) : "")
            . "\""
            . ($option->{id} eq $params->{selected} ? " selected=\"selected\"" : "")
            . ">"
            . ($option->{data}  ? encode_entities($option->{data})  : "")
            . "</option>";
  }
  
  $html .= "\n</select>";
  
  return $html

}




sub label($$@) {
  my $self = shift;
  my $label = shift;
  return "<label for=\"$label\">"
       . join("", @_)
       ."</label>"
}




sub prettyList($@) {
  
  my $self = shift;
  my $params = { @_ };
  my $html = "";
  
  $html .= "<ul class=\"opt\""
         . ($params->{style}     ? " style=\"$params->{style}\""         : "")
         . ">";
  
  for (my $c=0; $c < @{$params->{items}}; $c++) {
    my $item = $params->{items}[$c];
    $html  .= "\n  <li class=\""
            . ($c < (@{$params->{items}} - 1) ? "opt" : "opt2")
            . ">";
    if ($item->{link}) {
      $html .= "<a href=\"$item->{link}\""
            . ($item->{title} ? " title=\"$item->{title}\"" : "")
            . ">";
    }
    $html .= $item->{text}
           . ($item->{link} ? "</a>" : "")
                       . "</li>";
  }
  
  $html .= "\n</ul>";
  
  return $html;
}





sub login_box($@) {
  
  my $self = shift;
  use CGI;
  my $q = CGI->new;
  my $params = { @_ };
  my $html = "";
  
  # Why are we specifying the server name in this form action?
  # I know i put it in but i have no idea why..
  
  my $server = $q->server_name;
  
  $html .= join("<br />\n",
           $q->start_form( "post", "http://$server/login.pl" ),
           "profile_name", $q->textfield( -name => "profile_name",
                                          -value => $params->{profile_name} || ''),
           "password", $q->password_field( -name => "password",
                                           -value => $params->{password} || ''),
           $q->submit(),
           $q->end_form());
  
  $html .= $q->p( $q->a( { -href => "/forgotten-password.pl" },
                         "Forgotten your password?" ) );
  
  $html .= $q->p( $q->a( { -href => "/signup.pl" },
                         "Not a member? Signup here!" ) );
  
  return $html;
}




1;


