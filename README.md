# 6d
Personals website with profiles, messaging etc.  Perl, mod_perl, MySQL, Template Toolkit
Loosely follows an MVC approach (with more control in the model (htdocs/*.pl) than normal
Controllers (lib/*.pm) are more the database and data-munging monkeys.
Views are the templates (ttml/*.ttml) and they try to be as lightweight as possible, with most crunk sitting in the models.

Originally built in 2006, before all that MVC crap was really popular.

For now, it is here to as a resume-booster.  In time, it may become more.  Have fun.

If you really wanna play with it, you'll need apache2, mod_perl2 & perl5 installed.  It was built and tested on ubuntu/debian.  Talk to me and I'll send you the complicated mod_per apache config, you crazy bastard.  It's meant to work behind Squid, hence the X-Forwarded-For header first client IP being actually trusted (even if it's another proxy the client is using).
Also, the lib/conf/db_conf.pm file is missing.  I'm looking at a better way to hide this - I'll look to having the password set in another manner via an install script.
To check for requirements, run 'lib/check_modules.pl' - this will ensure you have everything correctly installed.  Any module that is reported as missing, you can install simply with sudo cpan -i <MODULE::NAME>
Et voila.
Ish.
