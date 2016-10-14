#!/usr/bin/env python

import smtplib
import cgi
import re

def message(code, message):
    print('Status: %i' % code)
    print('Content-Type: text/plain\r\n')
    print(message)

field = cgi.FieldStorage()
sender = 'someone@destination.email'
recipient = 'someone@destination.email'
email = field.getvalue('EMail')
name = field.getvalue('Name')
descr = field.getvalue('Descr')
mac = field.getvalue('MacName')

if ((email is None) or (recipient is None)
    or (name is None) or (descr is None)
    or (mac is None)):
    message(500, 'error: missing values!')
        exit(0)
else:
    msg = 'From: %s \r\n' % recipient
        msg += 'To: %s \r\n' % recipient
        if re.search('(^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$)', email):
            msg += 'Reply-To: %s \r\n' % email
        msg += 'Subject: MakeMeAdmin Log for %s \r\n' % name
        msg += '\r\n'
        msg += 'Name: %s \r\n' % name
        msg += 'Begruendung: %s \r\n' % descr
        msg += 'Rechner: %s \r\n' % mac
        msg += 'EMail: %s \r\n' % email
        
        try:
            smtplib.SMTP('localhost').sendmail(sender, recipient, msg)
                message(200, 'ok')
        except:
            message(500, 'error: sending mail')
