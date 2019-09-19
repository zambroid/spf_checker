#!/bin/ksh
#set -x
#
typeset -a
##############################################################################
#
#	Author: 	Fabio Zambrino <fabio@zambroid.ch>
#	Creation date:	Fri Apr 12 2019
#	Description:	This script will check sender SPF record from received
#			email messages. 
#			Outlook exported mails will be converted in text.
#			The following headers will be extracted:
#					- Return-Path
#					- Received: from
#					- From
#
#
#
#	Version:	1.0.0	zambroid  Initial version
#	
##############################################################################

#############
# VARIABLES #
#############
ZZ_TIME_STAMP=$(date '+%Y-%m-%d_%H:%M:%S')
ZZ_SPFCHECKER_DIR=$HOME/spf_checker
ZZ_WORKING_DIR=$ZZ_SPFCHECKER_DIR/${ZZ_TIME_STAMP}
ZZ_SPFCHECKER_LOG=$ZZ_WORKING_DIR/spf_checker_${ZZ_TIME_STAMP}.log
ZZ_CLOUDFLARE_DNS="1.1.1.1"

#COMMANDS
ZZ_ECHO=/bin/echo
ZZ_FILE=/usr/bin/file

#############
# FUNCTIONS #
#############

##############################################################################
# print message to stdout
##############################################################################
 
function print_msg {
  print "$(date '+[%d.%m.%Y %H:%M:%S]') $1 : $2"
}
 
##############################################################################
# print message to stderr
##############################################################################
 
function print_msg_stderr {
  print -u2 "$(date '+[%d.%m.%Y %H:%M:%S]') $1 : $2"
}
 
##############################################################################
# print message box
##############################################################################
 
function print_msg_box {
  print "##############################################################################"
  print "$(date '+[%d.%m.%Y %H:%M:%S]') $1"
  print "##############################################################################"
}
 
##############################################################################
# log command
##############################################################################
 
 function log_script {
  print_msg "INFO" "Script started"
  exec 3>&1 4>&2 1>> $1 2>&1
  print_msg "INFO" "Script started"
 }

##############################################################################
# log command verbose
##############################################################################
 
 function log_script_verbose {
  print_msg "INFO" "Script started"
  exec 3>&1 4>&2 1>> $1 2>&1
  print_msg "INFO" "Script started"
  set -v
 }

##############################################################################
# stop logging
##############################################################################
 
 function stop_log {
  set +v
  print_msg "INFO" "Script ended"
  exec 1>&3 2>&4 3>&- 4>&-
  print_msg "INFO" "Logging stopped"
 }

##############################################################################
# function get command line arguments
##############################################################################
 
function get_args {
  while [[ $# -gt 0 ]]; do
    case $1 in
      # EMAIL FILE
      -f)
        shift
        if [[ -n $1 ]]; then
          ZZ_EMAIL_FILE=$1
          shift
        fi
        ;;
      # DISPLAY FROM
      -from)
        shift
        if [[ -n $1 ]]; then
          ZZ_EMAIL_FROM=$1
          shift
        fi
        ;;
      # RETURN-PATH
      -rpath)
        shift
        if [[ -n $1 ]]; then
          ZZ_EMAIL_RPATH=$1
          shift
        fi
        ;;
      # RECEIVED: FROM
      -rfrom)
        shift
        if [[ -n $1 ]]; then
          ZZ_EMAIL_RFROM=$1
          shift
        fi
        ;;
      # LOG TO FILE
      -log)
        shift
        ZZ_ACTIVE_LOGGING=1
        ;;
      -h)
        usage_message
        ;;
       *)
        usage_message "Invalid argument found"
        ;;
    esac
  done
 
  if [[ -z $ZZ_EMAIL_FILE ]]; then
    if [[ -z $ZZ_EMAIL_FROM ||  -z $ZZ_EMAIL_RPATH || -z $ZZ_EMAIL_RFROM ]]; then
      usage_message "Incorrect parameters"
    fi
  else
    if [[ ! -r $ZZ_EMAIL_FILE ]]; then
      usage_message "File $ZZ_EMAIL_FILE is unreadable"
    fi
  fi
 
}
 
##############################################################################
# USAGE MESSAGE
##############################################################################
 
function usage_message {
 
  # error message is passed as argument
 
  if [[ -n "$1" ]]; then
    print
    print "Command : spf_checker.sh $ZZ_ARGS"
    print
    print "Error   : $1"
  fi
 
  # display usage
 
  print
  print "Purpose : Check SPF validity of receive email message"
  print
  print "Usage   : spf_checker.sh -f <EMAIL_FILE> "
  print "          -f absolute path of the import file"
  print "          -from displayed email address"
  print "          -rpath return-path contained in email"
  print "          -rfrom received from header contained in email (server name)"
  print "          -log activate file logging - all output saved to a log file"
  print "          -h display usage help"
  print
  print "Example : spf_checker.sh -f /home/username/Downloads/email_message.msg"
  print "          spf_checker.sh -from \"user@example.com\" -rpath \"user2@example.com\" -rfrom \"mailserver.example.com\" "
  print "          spf_checker.sh -f /home/username/Downloads/email_message.msg -log"
  print
  print
 
  exit 1
 
}

##############################################################################
# function to check file type
##############################################################################

function zz_file_type {
ZZ_FILE_TYPE=$($ZZ_FILE -b $ZZ_EMAIL_FILE)
  if [[ $ZZ_FILE_TYPE == *"ASCII text"* ]]; then
    print_msg "INFO" "File type: $ZZ_FILE_TYPE"
    ZZ_EXTRACT_OPTS="-ascii"
  elif [[ $ZZ_FILE_TYPE == *"Outlook"* ]]; then
    print_msg "INFO" "File type: $ZZ_FILE_TYPE"
    zz_convert_outlook
    ZZ_EXTRACT_OPTS="-outlook"
  else
	  print_msg "ERROR" "Unknown file type"
    exit 1
  fi
}

##############################################################################
# function extract Return-Path from email
##############################################################################
function zz_extract_return_path {
  case $1 in
    -outlook)
      ZZ_EMAIL_RPATH=$(grep -i "return-path" $ZZ_WORKING_DIR/$ZZ_EMAIL_FILE_CONVERTED | tail -1 | perl -ne "print $a /Return-Path:\s*\S+@(\S+\.\w+)/")
      ;;
    -ascii)
      ZZ_EMAIL_RPATH=$(grep -i "return-path" $ZZ_EMAIL_FILE | tail -1 | perl -ne "print $a /Return-Path:\s*\<\S+@(\S+\.\w+)\>/")
    ;;
  esac
	print_msg "INFO" "Return-Path: $ZZ_EMAIL_RPATH"
}

##############################################################################
# function extract "Received: from" from email
##############################################################################
function zz_extract_received_from {
  case $1 in
    -outlook)
    ZZ_EMAIL_RFROM=$(grep -P "Received: from\s+\S+\.\w+\s+\(" $ZZ_WORKING_DIR/$ZZ_EMAIL_FILE_CONVERTED | grep -vP "(127\.)|(10\.)|(172\.1[6-9]\.)|(172\.2[0-9]\.)|(172\.3[0-1]\.)|(192\.168\.)" | tail -1 | perl -ne "print $a /Received: from\s+(\S+\.\w+)\s+\S+/")
    ZZ_EMAIL_RFROM_IP=$(grep -P "Received: from\s+\S+\.\w+\s+\(" $ZZ_WORKING_DIR/$ZZ_EMAIL_FILE_CONVERTED | grep -vP "(127\.)|(10\.)|(172\.1[6-9]\.)|(172\.2[0-9]\.)|(172\.3[0-1]\.)|(192\.168\.)" | tail -1 | perl -ne "print $a /Received: from.*\s+\S(\d+\.\d+\.\d+\.\d+)\S+/")
    ;;
    -ascii)
    ZZ_EMAIL_RFROM=$(grep -P "Received: from\s+\S+\.\w+\s+\(" $ZZ_EMAIL_FILE | grep -vP "(127\.)|(10\.)|(172\.1[6-9]\.)|(172\.2[0-9]\.)|(172\.3[0-1]\.)|(192\.168\.)" | tail -1 | perl -ne "print $a /Received: from\s+\S+\.\w+\s+\((\D*\S*\.\D+)\s+\S+/")
    ZZ_EMAIL_RFROM_IP=$(grep -P "Received: from\s+\S+\.\w+\s+\(" $ZZ_EMAIL_FILE | grep -vP "(127\.)|(10\.)|(172\.1[6-9]\.)|(172\.2[0-9]\.)|(172\.3[0-1]\.)|(192\.168\.)" | tail -1 | perl -ne "print $a /Received: from.*\s+\S(\d+\.\d+\.\d+\.\d+)\S+/")
    ;;
  esac
  if [[ -z $ZZ_EMAIL_RFROM_IP ]]; then
    zz_find_rfrom_ip
  else
    print_msg "INFO" "Declared server IP is $ZZ_EMAIL_RFROM_IP"
  fi
  print_msg "INFO" "Declared mail from: $ZZ_EMAIL_RFROM"
}

##############################################################################
# function find "Received: from" IP address from public DNS
##############################################################################
function zz_find_rfrom_ip {
  ZZ_EMAIL_RFROM_IP=$(host $ZZ_EMAIL_RFROM | grep "has address" | perl -ne "print $a /.*\s+\S(\d+\.\d+\.\d+\.\d+)\S+/")
  print_msg "WARN" "Server IP was not provided; Found server IP is $ZZ_EMAIL_RFROM_IP"
}

##############################################################################
# function extract "From: " from email
##############################################################################
function zz_extract_from {
  case $1 in
    -outlook)
    ZZ_EMAIL_FROM=$(grep -m1 "From: " $ZZ_WORKING_DIR/$ZZ_EMAIL_FILE_CONVERTED | perl -ne "print $a /From:.*\<(\.*\S*\@\S+\.\w+)\>/")
    ;;
    -ascii)
    ZZ_EMAIL_FROM=$(grep -m1 "From: " $ZZ_EMAIL_FILE | perl -ne "print $a /From:.*\<(\.*\S*\@\S+\.\w+)\>/")
    ;;
  esac
  print_msg "INFO" "Declared From: $ZZ_EMAIL_FROM"
}

##############################################################################
# function to convert Outlook messages in text
##############################################################################
function zz_convert_outlook {
  which msgconvert > /dev/null
	if [[ $? == 0 ]]; then
    ZZ_EMAIL_FILE_CONVERTED=$(echo $ZZ_EMAIL_FILE | perl -ne "print $a /\S+\/(\S+)/").spfchecker
    print_msg "INFO" "Converting Outlook email to text..."
    msgconvert --outfile $ZZ_WORKING_DIR/$ZZ_EMAIL_FILE_CONVERTED $ZZ_EMAIL_FILE
  fi
}

##############################################################################
# function find SPF record
##############################################################################
function zz_spf_find {
  ZZ_SPF_RECORD_NUMBER=$(host -t TXT $1 $ZZ_CLOUDFLARE_DNS | grep "v=spf1" | wc -l)
  ZZ_SPF_RECORD=$(host -t TXT $1 $ZZ_CLOUDFLARE_DNS | grep -m1 "v=spf1" | perl -ne "print $a /descriptive text \"(v=spf1.*)\"/")
  if [[ $ZZ_SPF_RECORD_NUMBER -gt 1 ]]; then
    print ""
    print_msg "ERROR" "$ZZ_SPF_RECORD_NUMBER found instead of 1 (as expected). Exiting...\n"
    exit 1
  elif [[ $ZZ_SPF_RECORD_NUMBER -lt 1 ]]; then
    print ""
    print_msg "ERROR" "The domains $1 doesn't have a published SPF record\n"
  else 
    print ""
    print_msg "INFO" "Found SPF Record for $1:"
    print $ZZ_SPF_RECORD
    print ""
    zz_check_all_mechanism
    ######################
    # IMPROVEMENTS
    ######################
    # check how many includes are present(if present needs to be resolved recursively and count. If >=10 ERROR)
    # if "ip4" is present check if ZZ_EMAIL_RFROM_IP is in the list - if not ERROR
  fi
}

##############################################################################
# function DNS Checks
##############################################################################
function zz_dns_check {
  ZZ_EMAIL_FROM_DOMAIN=$(echo $ZZ_EMAIL_FROM | perl -ne "print $a /^\S+\@(\S+\.\w+)/")
  zz_spf_find $ZZ_EMAIL_FROM_DOMAIN
  if [[ $ZZ_EMAIL_FROM_DOMAIN != $ZZ_EMAIL_RFROM ]]; then
    print_msg "WARN" "Displayed from differs from \"mail from\" header"
    zz_spf_find $ZZ_EMAIL_RFROM
  fi

  if [[ $ZZ_EMAIL_FROM_DOMAIN != $ZZ_EMAIL_RPATH ]]; then
    print_msg "WARN" "Displayed from differs from \"helo\" header"
  fi
}

##############################################################################
# function check "all" mechanisms in SPF record
##############################################################################
function zz_check_all_mechanism {
  ZZ_ALL_MECHANISM=$(echo $ZZ_SPF_RECORD | perl -ne "print $a /v=spf1.*(.all)/")
  if [[ ! -z $ZZ_ALL_MECHANISM ]]; then
    if [[ $ZZ_ALL_MECHANISM == '-all' ]]; then
      print_msg "INFO" "Good, the SPF record is strict"
    elif [[ $ZZ_ALL_MECHANISM == '~all' ]]; then
      print_msg "WARN" "The SPF record is not strict"
    elif [[ $ZZ_ALL_MECHANISM == '?all' ]]; then
      print_msg "ERROR" "The SPF record is neutral"
    elif [[ $ZZ_ALL_MECHANISM == '+all' ]]; then
      print_msg "ERROR" "The SPF record is not secure"
    fi
  else
    print_msg "ERROR" "\"all\" mechanism not defined"
  fi
}

##############################################################################
# main
##############################################################################
get_args "$@"

if [[ ! -d $ZZ_SPFCHECKER_DIR ]]; then
  mkdir -p $ZZ_SPFCHECKER_DIR
fi
mkdir -p $ZZ_WORKING_DIR

if [[ $ZZ_ACTIVE_LOGGING == 1 ]]; then
  print_msg "INFO" "Log will be saved in ${ZZ_SPFCHECKER_LOG}"
  # start logging
  log_script_verbose $ZZ_SPFCHECKER_LOG
else
    print_msg "INFO" "Script started"
fi


if [[ ! -z $ZZ_EMAIL_FILE ]]; then
  zz_file_type
  zz_extract_return_path $ZZ_EXTRACT_OPTS
  zz_extract_received_from $ZZ_EXTRACT_OPTS
  zz_extract_from $ZZ_EXTRACT_OPTS
else
  zz_find_rfrom_ip
	print_msg "INFO" "Return-Path: $ZZ_EMAIL_RPATH"
  print_msg "INFO" "Declared mail from: $ZZ_EMAIL_RFROM"
  print_msg "INFO" "Declared server IP is $ZZ_EMAIL_RFROM_IP"
  print_msg "INFO" "Declared From: $ZZ_EMAIL_FROM"
fi

zz_dns_check

if [[ $ZZ_ACTIVE_LOGGING == 1 ]]; then
  # stop logging
  stop_log
fi

print_msg "INFO" "Script ended"



exit 0
