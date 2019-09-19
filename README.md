# spf_checker

Check SPF validity of received email message.

spf_checker.sh is a KornShell script for Linux systems.

## Pre-requisites
 - ksh
 - msgconv
 - dnsutils

## Notes
ASCII text email messages will be checked automatically.
Outlook emails (MSG) needs to be converted with a script found here:
https://www.matijs.net/software/msgconv/
Pre-requisites:
  cpan -i Email::Outlook::Message
