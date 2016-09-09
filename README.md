# MakeMeAdmin

A Cocoa utility that gives a user administrative rights on a mac and revokes them after 30 minutes. It must be run with root privileges (e.g. from Casper Suite Self Service) or via SUID-bit.

## use case

Your users should be able to install software or administer their Mac on their own (e.g. when they are on a business trip). But for security reasons doing this should be a planned and "active" task to prevent accidently giving some malware administrative privileges.

## building and installation
I decided that the server URL should be hardcoded so it cannot be overwritten by a `defaults` command. I know, security by obscurity, ... . Because of this, there is no binary release you can use. Copy the `config.swift.sample` file to `config.swift` and adopt to your needs. The URL you provide will be used for an HTTP-PUT request with some URL-encoded values:

* Name
	* the Full Name of a user, read from `RealName` Attribute on the local directory service.
* EMail
	* the E-Mail of an user, read from the `EMailAdress` Attribute on the local directory service
* MacNmae
	* the `ComputerName` of the mac.
* Descr
	* a field for some description, why a user needs admin rights.

The user may change all of them.

There is a sample `putAdminRequest.py` CGI Script that simply allows everyone to use this utility and sends a notification mail. MakeMeAdmin will only continue if the HTTP returncode is 200. You may provide your own logic if you want. An optional HTTP authentication is on my todo list - any PR is appreciated :-)

## Todo
- [ ] HTTP Authentication
- [ ] Certificate Pinning