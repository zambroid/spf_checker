# spf_checker

Check SPF validity of received email message.

spf_checker.sh is a KornShell script for Linux systems.

## Pre-requisites
 - ksh
 - msgconv
 - dnsutils

## Usage
````
Purpose : Check SPF validity of receive email message

Usage   : spf_checker.ksh -f <EMAIL_FILE>
          -f absolute path of the import file
          -from displayed email address
          -rpath return-path contained in email
          -rfrom received from header contained in email (server name)
          -log activate file logging - all output saved to a log file
          -h display usage help

Example : spf_checker.ksh -f /home/username/Downloads/email_message.msg
          spf_checker.ksh -from "user@example.com" -rpath "user2@example.com" -rfrom "mailserver.example.com"
          spf_checker.ksh -f /home/username/Downloads/email_message.msg -log
````

## Notes
ASCII text email messages will be checked automatically.

Outlook emails (MSG) needs to be converted with a script found here:

- https://www.matijs.net/software/msgconv/


Pre-requisites:
- cpan -i Email::Outlook::Message
