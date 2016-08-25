#!/usr/bin/env python

import smtplib
import cgi
# import cgitb; cgitb.enable(format='text')

def message(code, message):
	print('Content-Type: text/plain')
	print('Status: %i') % code
	print('\n')
	print(message)

field = cgi.FieldStorage()

sender = field.getvalue('EMail')
recipient = 'someone@destination.email'
name = field.getvalue('Name')
descr = field.getvalue('Descr')
mac = field.getvalue('MacName')

if ((sender is None) or (recipient is None) 
		or (name is None) or (descr is None) 
		or (mac is None)):
	message(500, 'request missing some values')

msg = 'From: %s \r\n' % sender
msg += 'To: %s \r\n' % recipient
msg += 'Subject: MakeMeAdmin Log for %s \r\n' % name
msg += '\r\n'
msg += 'Name: %s \r\n' % name
msg += 'Description: %s \r\n' % descr
msg += 'Mac: %s \r\n' % mac

try:
	smtplib.SMTP('localhost').sendmail(sender, recipient, msg)
	message(200, 'ok')
except:
	message(500, 'error sending mail')
